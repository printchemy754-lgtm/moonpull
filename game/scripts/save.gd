extends Node
## Persistent progress and settings.

const PATH := "user://save.cfg"
const DAILY_MAX_STREAK := 7
const DAILY_STEP := 100          # day 1 = 100, day 7 = 700 coins

var level := 1
var coins := 0
var custom := {}       # equipped item per workshop category
var owned_items := {}  # category -> Array of owned indices
var stars := {}        # "level" -> 0..3
var seen: Array = []   # element kinds already introduced
var sound := true
var music := true
var vibe := true
var daily_day := 0     # unix day of the last claimed gift
var daily_streak := 0
var free_ready_at := 0 # unix seconds when "free coins" can be watched again
var player_name := ""
var missions := {}     # {"day": int, "list": [ {id, target, progress, reward, claimed} ], "bonus": bool}
var chest_ready_at := 0      # free chest timer (unix seconds)
var star_chests := 0         # star chests already opened
var races := 0
var race_wins := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_fix()
		return
	level = maxi(int(cfg.get_value("p", "level", 1)), 1)
	if cfg.has_section_key("p", "coins"):
		coins = maxi(int(cfg.get_value("p", "coins", 0)), 0)
	else:
		coins = maxi(int(cfg.get_value("p", "pearls", 0)), 0) * 10  # v1/v2 pearls -> coins
	custom = cfg.get_value("p", "custom", {})
	owned_items = cfg.get_value("p", "owned_items", {})
	if not cfg.has_section_key("p", "owned_items"):
		# v2/v3 saves: whole boats were bought -> they become owned hulls
		var old: Array = cfg.get_value("p", "owned", [true])
		var hulls: Array = []
		for i in old.size():
			if bool(old[i]):
				hulls.append(i)
		owned_items["hull"] = hulls
		custom["hull"] = int(cfg.get_value("p", "boat", 0))
	stars = cfg.get_value("p", "stars", {})
	seen = cfg.get_value("p", "seen", [])
	daily_day = int(cfg.get_value("p", "daily_day", 0))
	daily_streak = int(cfg.get_value("p", "daily_streak", 0))
	free_ready_at = int(cfg.get_value("p", "free_ready_at", 0))
	player_name = String(cfg.get_value("p", "name", ""))
	missions = cfg.get_value("p", "missions", {})
	chest_ready_at = int(cfg.get_value("p", "chest_ready_at", 0))
	star_chests = int(cfg.get_value("p", "star_chests", 0))
	races = int(cfg.get_value("p", "races", 0))
	race_wins = int(cfg.get_value("p", "race_wins", 0))
	sound = bool(cfg.get_value("s", "sound", true))
	music = bool(cfg.get_value("s", "music", true))
	vibe = bool(cfg.get_value("s", "vibe", true))
	_fix()


func _fix() -> void:
	if player_name.strip_edges() == "":
		player_name = random_name()
	for cat in Custom.CATS:
		var list: Array = owned_items.get(cat, [])
		if not list.has(0):
			list.append(0)
		owned_items[cat] = list
		var eq := int(custom.get(cat, 0))
		if eq < 0 or eq >= Custom.count(cat) or not list.has(eq):
			eq = 0
		custom[cat] = eq


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "level", level)
	cfg.set_value("p", "coins", coins)
	cfg.set_value("p", "custom", custom)
	cfg.set_value("p", "owned_items", owned_items)
	cfg.set_value("p", "stars", stars)
	cfg.set_value("p", "seen", seen)
	cfg.set_value("p", "daily_day", daily_day)
	cfg.set_value("p", "daily_streak", daily_streak)
	cfg.set_value("p", "free_ready_at", free_ready_at)
	cfg.set_value("p", "name", player_name)
	cfg.set_value("p", "missions", missions)
	cfg.set_value("p", "chest_ready_at", chest_ready_at)
	cfg.set_value("p", "star_chests", star_chests)
	cfg.set_value("p", "races", races)
	cfg.set_value("p", "race_wins", race_wins)
	cfg.set_value("s", "sound", sound)
	cfg.set_value("s", "music", music)
	cfg.set_value("s", "vibe", vibe)
	cfg.save(PATH)


func add_coins(n: int) -> void:
	coins += n
	save()


func set_level(l: int) -> void:
	level = l
	save()


func set_stars(l: int, s: int) -> void:
	var key := str(l)
	stars[key] = maxi(int(stars.get(key, 0)), s)
	save()


func total_stars() -> int:
	var total := 0
	for k in stars:
		total += int(stars[k])
	return total


func owns(cat: String, i: int) -> bool:
	return (owned_items.get(cat, []) as Array).has(i)


func equipped(cat: String) -> int:
	return int(custom.get(cat, 0))


func boat_cfg() -> Dictionary:
	return custom.duplicate()


func buy(cat: String, i: int) -> bool:
	var cost := int(Custom.item(cat, i).price)
	if owns(cat, i) or coins < cost:
		return false
	coins -= cost
	(owned_items[cat] as Array).append(i)
	custom[cat] = i
	save()
	return true


func equip(cat: String, i: int) -> void:
	if owns(cat, i):
		custom[cat] = i
		save()


func owned_count() -> int:
	var n := 0
	for cat in owned_items:
		n += (owned_items[cat] as Array).size()
	return n


func mark_seen(kind: String) -> void:
	if not seen.has(kind):
		seen.append(kind)
		save()


# ------------------------------------------------------------------ daily gift

static func today() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)


func daily_available() -> bool:
	return today() > daily_day


## The streak day the next gift will count as (1..7).
func daily_next_streak() -> int:
	if today() == daily_day + 1:
		return mini(daily_streak + 1, DAILY_MAX_STREAK)
	return 1


func daily_amount() -> int:
	return daily_next_streak() * DAILY_STEP


func claim_daily(multiplier: int) -> int:
	var amount := daily_amount() * multiplier
	daily_streak = daily_next_streak()
	daily_day = today()
	coins += amount
	save()
	return amount


# ------------------------------------------------------------------ free coins (rewarded ad)

func free_seconds_left() -> int:
	return maxi(free_ready_at - int(Time.get_unix_time_from_system()), 0)


func start_free_cooldown(seconds: int) -> void:
	free_ready_at = int(Time.get_unix_time_from_system()) + seconds
	save()


# ------------------------------------------------------------------ profile

const NAME_A := ["Salty", "Brave", "Lucky", "Sleepy", "Mighty", "Tiny", "Jolly", "Swift", "Moony", "Foggy", "Sunny", "Wavy"]
const NAME_B := ["Captain", "Sailor", "Otter", "Pelican", "Barnacle", "Squid", "Puffin", "Walrus", "Seal", "Crab", "Gull", "Dolphin"]


static func random_name() -> String:
	return "%s%s%d" % [NAME_A[randi() % NAME_A.size()], NAME_B[randi() % NAME_B.size()], randi_range(1, 99)]


func set_player_name(n: String) -> void:
	var clean := ""
	for ch in n.strip_edges():
		if ch.is_valid_identifier() or ch.is_valid_int() or ch == " " or ch == "-":
			clean += ch
	clean = clean.substr(0, 14).strip_edges()
	if clean != "":
		player_name = clean
		save()


# ------------------------------------------------------------------ chests

const CHEST_COOLDOWN := 4 * 3600
const STARS_PER_CHEST := 10


func chest_seconds_left() -> int:
	return maxi(chest_ready_at - int(Time.get_unix_time_from_system()), 0)


func star_chest_progress() -> int:
	return total_stars() - star_chests * STARS_PER_CHEST


func star_chest_ready() -> bool:
	return star_chest_progress() >= STARS_PER_CHEST


## Opens a chest. kind = "free" or "star". Returns {"coins": n} or {"cat": c, "index": i}.
func open_chest(kind: String) -> Dictionary:
	var rich := kind == "star"
	if kind == "free":
		chest_ready_at = int(Time.get_unix_time_from_system()) + CHEST_COOLDOWN
	else:
		star_chests += 1
	var reward := {}
	if randf() < (0.45 if rich else 0.3):
		var cats := ["hat", "trail", "flag", "sail"] if rich else ["paint", "sail", "flag"]
		var options := []
		for cat in cats:
			for i in Custom.count(cat):
				if not owns(cat, i):
					options.append([cat, i])
		if not options.is_empty():
			var pick: Array = options[randi() % options.size()]
			(owned_items[pick[0]] as Array).append(pick[1])
			reward = {"cat": pick[0], "index": pick[1]}
	if reward.is_empty():
		var amount := randi_range(10, 30) * (50 if rich else 15)
		coins += amount
		reward = {"coins": amount}
	save()
	return reward
