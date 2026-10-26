extends Node
## Persistent progress and settings.

const PATH := "user://save.cfg"

var level := 1
var pearls := 0
var boat := 0
var owned: Array = [true]
var stars := {}        # "level" -> 0..3
var seen: Array = []   # element kinds already introduced
var sound := true
var music := true
var vibe := true


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		_fix()
		return
	level = maxi(int(cfg.get_value("p", "level", 1)), 1)
	pearls = maxi(int(cfg.get_value("p", "pearls", 0)), 0)
	boat = int(cfg.get_value("p", "boat", 0))
	owned = cfg.get_value("p", "owned", [true])
	stars = cfg.get_value("p", "stars", {})
	seen = cfg.get_value("p", "seen", [])
	sound = bool(cfg.get_value("s", "sound", true))
	music = bool(cfg.get_value("s", "music", true))
	vibe = bool(cfg.get_value("s", "vibe", true))
	_fix()


func _fix() -> void:
	var n := Boat.count()
	while owned.size() < n:
		owned.append(false)
	owned[0] = true
	if boat < 0 or boat >= n or not owned[boat]:
		boat = 0


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "level", level)
	cfg.set_value("p", "pearls", pearls)
	cfg.set_value("p", "boat", boat)
	cfg.set_value("p", "owned", owned)
	cfg.set_value("p", "stars", stars)
	cfg.set_value("p", "seen", seen)
	cfg.set_value("s", "sound", sound)
	cfg.set_value("s", "music", music)
	cfg.set_value("s", "vibe", vibe)
	cfg.save(PATH)


func add_pearls(n: int) -> void:
	pearls += n
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


func owns(i: int) -> bool:
	return i >= 0 and i < owned.size() and bool(owned[i])


func buy(i: int) -> bool:
	var cost := Boat.price(i)
	if owns(i) or pearls < cost:
		return false
	pearls -= cost
	owned[i] = true
	boat = i
	save()
	return true


func select(i: int) -> void:
	if owns(i):
		boat = i
		save()


func mark_seen(kind: String) -> void:
	if not seen.has(kind):
		seen.append(kind)
		save()
