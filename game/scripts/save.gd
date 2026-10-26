extends Node
## Persistent progress: level, pearls, boat colors.

const PATH := "user://save.cfg"
const SKIN_COLORS := [
	Color("ff5a4e"), Color("ffd23f"), Color("3ddc97"),
	Color("4ea8ff"), Color("b57bff"), Color("f5f5f5"),
]
const SKIN_COSTS := [0, 60, 120, 200, 320, 500]

var level := 1
var pearls := 0
var skin := 0
var unlocked := 1


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		level = int(cfg.get_value("p", "level", 1))
		pearls = int(cfg.get_value("p", "pearls", 0))
		skin = int(cfg.get_value("p", "skin", 0))
		unlocked = clampi(int(cfg.get_value("p", "unlocked", 1)), 1, SKIN_COLORS.size())
		skin = clampi(skin, 0, unlocked - 1)


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("p", "level", level)
	cfg.set_value("p", "pearls", pearls)
	cfg.set_value("p", "skin", skin)
	cfg.set_value("p", "unlocked", unlocked)
	cfg.save(PATH)


func add_pearls(n: int) -> void:
	pearls += n
	save()


func set_level(l: int) -> void:
	level = l
	save()


func skin_color() -> Color:
	return SKIN_COLORS[skin]


func next_skin_cost() -> int:
	if unlocked >= SKIN_COLORS.size():
		return -1
	return SKIN_COSTS[unlocked]


## Buys the next color if affordable. Returns true on success.
func buy_next_skin() -> bool:
	var cost := next_skin_cost()
	if cost < 0 or pearls < cost:
		return false
	pearls -= cost
	unlocked += 1
	skin = unlocked - 1
	save()
	return true


func cycle_skin() -> void:
	skin = (skin + 1) % unlocked
	save()
