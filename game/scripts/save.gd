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
var season := "auto"   # Season.PREFS
var daily_day := 0     # unix day of the last claimed gift
var daily_streak := 0
var free_ready_at := 0 # unix seconds when "free coins" can be watched again
var player_name := ""
var missions := {}     # {"day": int, "list": [ {id, target, progress, reward, claimed} ], "bonus": bool}
var chest_ready_at := 0      # free chest timer (unix seconds)
var star_chests := 0         # star chests already opened
var races := 0
var race_wins := 0
var xp := 0
var best_endless := 0
var pending_ranks: Array = []   # ranks reached but not yet shown
var upgrades := {}              # Upgrades id -> level
var bosses := 0                 # bosses defeated
var fevers := 0                 # FEVERs triggered (all time)
var fail_level := 0             # level the player keeps losing on
var fail_count := 0             # game overs in a row on fail_level
var best_progress := {}         # "level" -> best % reached


signal loaded
var is_loaded := false
const CLOUD_KEY := "moonpull_save"


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		_read(cfg)
	_fix()
	if OS.has_feature("web"):
		_web_load()
	else:
		is_loaded = true


## Browser on CrazyGames: progress lives in their Data Module.
func _web_load() -> void:
	var waited := 0.0
	while not CrazySDK.settled() and waited < 5.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var text := CrazySDK.load_text(CLOUD_KEY)
	if text != "":
		var cfg := ConfigFile.new()
		if cfg.parse(text) == OK:
			_read(cfg)
			_fix()
	is_loaded = true
	loaded.emit()


func _read(cfg: ConfigFile) -> void:
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
	xp = int(cfg.get_value("p", "xp", 0))
	best_endless = int(cfg.get_value("p", "best_endless", 0))
	pending_ranks = cfg.get_value("p", "pending_ranks", [])
	upgrades = cfg.get_value("p", "upgrades", {})
	bosses = int(cfg.get_value("p", "bosses", 0))
	fevers = int(cfg.get_value("p", "fevers", 0))
	fail_level = int(cfg.get_value("p", "fail_level", 0))
	fail_count = int(cfg.get_value("p", "fail_count", 0))
	best_progress = cfg.get_value("p", "best_progress", {})
	sound = bool(cfg.get_value("s", "sound", true))
	music = bool(cfg.get_value("s", "music", true))
	vibe = bool(cfg.get_value("s", "vibe", true))
	season = String(cfg.get_value("s", "season", "auto"))


func _fix() -> void:
	if player_name.strip_edges() == "":
		player_name = random_name()
	for cat in Custom.CATS:
		var list: Array = owned_items.get(cat, [])
		for i in Custom.count(cat):
			if int(Custom.item(cat, i).price) == 0 and not list.has(i):
				list.append(i)   # free starter items
		owned_items[cat] = list
	for slot in Custom.SLOTS:
		var cat: String = Custom.SLOTS[slot]
		var def := int(Custom.DEFAULTS.get(slot, 0))
		var eq := int(custom.get(slot, def))
		if eq < 0 or eq >= Custom.count(cat) or not (owned_items[cat] as Array).has(eq):
			eq = def
		custom[slot] = eq


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
	cfg.set_value("p", "xp", xp)
	cfg.set_value("p", "best_endless", best_endless)
	cfg.set_value("p", "pending_ranks", pending_ranks)
	cfg.set_value("p", "upgrades", upgrades)
	cfg.set_value("p", "bosses", bosses)
	cfg.set_value("p", "fevers", fevers)
	cfg.set_value("p", "fail_level", fail_level)
	cfg.set_value("p", "fail_count", fail_count)
	cfg.set_value("p", "best_progress", best_progress)
	cfg.set_value("s", "sound", sound)
	cfg.set_value("s", "music", music)
	cfg.set_value("s", "vibe", vibe)
	cfg.set_value("s", "season", season)
	cfg.save(PATH)
	CrazySDK.save_text(CLOUD_KEY, cfg.encode_to_text())


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


## slot = a key of Custom.SLOTS ("hull", ..., "wall_l", "wall_r")
func equipped(slot: String) -> int:
	return int(custom.get(slot, int(Custom.DEFAULTS.get(slot, 0))))


func boat_cfg() -> Dictionary:
	return custom.duplicate()


## Buys item i of category `cat` and equips it into `slot`.
func buy(cat: String, i: int, slot := "") -> bool:
	var cost := int(Custom.item(cat, i).price)
	if cost < 0 or owns(cat, i) or coins < cost:
		return false
	coins -= cost
	(owned_items[cat] as Array).append(i)
	custom[slot if slot != "" else cat] = i
	save()
	return true


func equip(slot: String, i: int) -> void:
	if owns(Custom.SLOTS[slot], i):
		custom[slot] = i
		save()


func grant(cat: String, i: int) -> bool:
	if owns(cat, i):
		return false
	(owned_items[cat] as Array).append(i)
	save()
	return true


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


## Returns the coins given. On day 7 the streak-exclusive item is granted too
## (check `last_daily_item`).
var last_daily_item: Array = []


func claim_daily(multiplier: int) -> int:
	var amount := daily_amount() * multiplier
	last_daily_item = []
	if daily_next_streak() == DAILY_MAX_STREAK:
		var ex := Custom.streak_unlock()
		if not ex.is_empty() and grant(ex[0], ex[1]):
			last_daily_item = ex
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
	var rich := kind != "free"
	if kind == "free":
		chest_ready_at = int(Time.get_unix_time_from_system()) + CHEST_COOLDOWN
	elif kind == "star":
		star_chests += 1
	var reward := {}
	if randf() < (0.45 if rich else 0.3):
		var cats := ["hat", "trail", "flag", "sail", "wall"] if rich else ["paint", "sail", "flag"]
		var options := []
		for cat in cats:
			for i in Custom.count(cat):
				var price := int(Custom.item(cat, i).price)
				if not owns(cat, i) and price > 0 and price <= (20000 if rich else 2500):
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


# ------------------------------------------------------------------ rank / XP

func rank() -> int:
	return int(Ranks.from_xp(xp)[0])


## Adds XP; ranks reached are rewarded right away and queued for the rank-up screen.
func add_xp(n: int) -> void:
	if n <= 0:
		return
	var before := rank()
	xp += n
	var after := rank()
	for r in range(before + 1, after + 1):
		var rw := Ranks.reward(r)
		coins += int(rw.coins)
		for pair in rw.items:
			grant(pair[0], pair[1])
		pending_ranks.append(r)
	save()


# ------------------------------------------------------------------ mystery box

const MYSTERY_PRICE := 9000


## Unowned items a mystery box can give (no exclusives, nothing too pricey).
func mystery_pool() -> Array:
	var out := []
	for cat in Custom.CATS:
		for i in Custom.count(cat):
			var price := int(Custom.item(cat, i).price)
			if price > 0 and price <= 40000 and not owns(cat, i):
				out.append([cat, i, price])
	return out


## Spends MYSTERY_PRICE for a guaranteed NEW item (cheaper ones are more likely,
## but a big one can drop -> the thrill). Returns {"cat", "index"} or {}.
func open_mystery() -> Dictionary:
	var pool := mystery_pool()
	if pool.is_empty() or coins < MYSTERY_PRICE:
		return {}
	var total := 0.0
	for p in pool:
		total += 1.0 / sqrt(float(p[2]))
	var r := randf() * total
	var pick: Array = pool[0]
	for p in pool:
		r -= 1.0 / sqrt(float(p[2]))
		if r <= 0.0:
			pick = p
			break
	coins -= MYSTERY_PRICE
	(owned_items[pick[0]] as Array).append(pick[1])
	save()
	return {"cat": pick[0], "index": pick[1]}
