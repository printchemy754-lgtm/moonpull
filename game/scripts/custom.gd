class_name Custom
extends RefCounted
## Workshop catalogue. Every category has free starter items.
## price -1 + "unlock" = exclusive (rank reward or 7-day streak), can't be bought.

const CATS := ["hull", "sky", "paint", "sail", "flag", "hat", "trail", "wall"]
## Categories shown in the shop (the others keep their defaults).
const SHOP_CATS := ["hull", "sky"]
const CAT_NAMES := {
	"hull": "BALL", "sky": "WALLPAPER", "paint": "PAINT", "sail": "GLOW", "flag": "FLAG", "hat": "HAT", "trail": "TRAIL", "wall": "CITY",
}
## Equip slots -> the category whose items they use. Walls: one purchase, two slots.
const SLOTS := {
	"hull": "hull", "sky": "sky", "paint": "paint", "sail": "sail", "flag": "flag", "hat": "hat", "trail": "trail",
	"wall_l": "wall", "wall_r": "wall",
}
const DEFAULTS := {"wall_l": 0, "wall_r": 1}
const RARITY_COLORS := {
	"common": Color("9aa3c7"), "rare": Color("4ea8ff"), "epic": Color("b57bff"),
	"legendary": Color("ffb020"), "exclusive": Color("ff4f7a"),
}

static var _items := {}
static var _ball_order: Array = []


## Ball indices in shop order (cheap -> legendary, exclusives last).
static func ball_order() -> Array:
	items("hull")
	return _ball_order


## Rounds to two significant digits (1,234 -> 1,200; 1,987,654 -> 2,000,000).
static func _nice(v: float) -> int:
	var mag := pow(10.0, floor(log(v) / log(10.0)) - 1.0)
	return int(round(v / mag) * mag)


static func items(cat: String) -> Array:
	if _items.is_empty():
		_build()
	return _items[cat]


static func item(cat: String, i: int) -> Dictionary:
	var list := items(cat)
	return list[clampi(i, 0, list.size() - 1)]


static func count(cat: String) -> int:
	return items(cat).size()


static func total_items() -> int:
	var n := 0
	for cat in CATS:
		n += count(cat)
	return n


static func is_exclusive(it: Dictionary) -> bool:
	return int(it.price) < 0


static func rarity(it: Dictionary) -> String:
	var p := int(it.price)
	if p < 0:
		return "exclusive"
	if p >= 1000000:
		return "legendary"
	if p >= 150000:
		return "epic"
	if p >= 20000:
		return "rare"
	return "common"


## "RANK 20" / "7-DAY STREAK" for exclusives, "" otherwise.
static func unlock_text(it: Dictionary) -> String:
	var u := String(it.get("unlock", ""))
	if u.begins_with("rank:"):
		return "RANK %s" % u.substr(5)
	if u == "streak":
		return "7-DAY STREAK"
	if u == "season:halloween":
		return "HALLOWEEN EVENT"
	if u == "season:christmas":
		return "CHRISTMAS EVENT"
	return ""


## Exclusive items that unlock at a given rank: [[cat, index], ...]
static func rank_unlocks(rank: int) -> Array:
	var out := []
	for cat in SHOP_CATS:
		var list := items(cat)
		for i in list.size():
			if String(list[i].get("unlock", "")) == "rank:%d" % rank:
				out.append([cat, i])
	return out


static func streak_unlock() -> Array:
	for cat in SHOP_CATS:
		var list := items(cat)
		for i in list.size():
			if String(list[i].get("unlock", "")) == "streak":
				return [cat, i]
	return []


static func _palette(prices: Array) -> Array:
	var cols := [
		["CHERRY", Color("ff5a4e")], ["SUNNY", Color("ffc531")], ["MINT", Color("3ddc97")],
		["SKY", Color("4ea8ff")], ["GRAPE", Color("9b6bff")], ["BUBBLEGUM", Color("ff7ac8")],
		["SNOW", Color("f4f4f4")], ["MIDNIGHT", Color("2b2f5a")], ["LIME", Color("a8e04a")],
		["CORAL", Color("ff8a5b")],
	]
	var out := []
	for i in cols.size():
		out.append({"name": cols[i][0], "color": cols[i][1], "price": prices[i]})
	return out


static func _build() -> void:
	# pattern > 0 = solid patterned ball (the captain rides on top of it).
	# Indices never change (saves keep them); the shop shows them in BALL_ORDER.
	_items["hull"] = [
		{"name": "BUBBLE"},                                                    # 0
		{"name": "TECH"},
		{"name": "GYRO"},
		{"name": "PLANET"},
		{"name": "DUCKY"},
		{"name": "MOON"},                                                      # 5
		{"name": "BEACH BALL", "pattern": 1},
		{"name": "SOCCER", "pattern": 2},
		{"name": "BASKETBALL", "pattern": 3},
		{"name": "WATERMELON", "pattern": 4},
		{"name": "TENNIS", "pattern": 12},                                     # 10
		{"name": "CANDY SWIRL", "pattern": 11},
		{"name": "EYEBALL", "pattern": 7, "a": Color("2f8cff")},
		{"name": "EARTH", "pattern": 6},
		{"name": "BLACK BALL", "pattern": 13},
		{"name": "DISCO", "pattern": 5},                                       # 15
		{"name": "LAVA ROCK", "pattern": 8},
		{"name": "GALAXY ORB", "pattern": 10},
		{"name": "GOLDEN", "pattern": 9, "price": -1, "unlock": "rank:25"},
		{"name": "RED STRIPES", "pattern": 20, "a": Color("ff3b3b"), "b": Color("ffffff")},
		{"name": "BLUE DOTS", "pattern": 22, "a": Color("2f7bff"), "b": Color("ffffff")},   # 20
		{"name": "LIME CHECKER", "pattern": 21, "a": Color("a6f03c"), "b": Color("2f8a3a")},
		{"name": "HALF & HALF", "pattern": 24, "a": Color("ff6fb5"), "b": Color("3fd6ff"), "c": Color("ffffff")},
		{"name": "ZIGZAG", "pattern": 25, "a": Color("7a3cff"), "b": Color("ffd23f"), "c": Color("ffffff")},
		{"name": "BULLSEYE", "pattern": 27, "a": Color("ff3b3b"), "b": Color("ffffff"), "c": Color("2f6bff")},
		{"name": "STARRY", "pattern": 28, "a": Color("1d2a6b"), "b": Color("ffd23f")},     # 25
		{"name": "RAINBOW SWIRL", "pattern": 23, "a": Color("ff4545"), "b": Color("ffd23f"), "c": Color("2f9bff")},
		{"name": "MINT CHECKER", "pattern": 21, "a": Color("7ff0c8"), "b": Color("ffffff")},
		{"name": "GOLD STRIPES", "pattern": 20, "a": Color("ffc531"), "b": Color("1d1b2e")},
		{"name": "COTTON CANDY", "pattern": 23, "a": Color("ff9ad5"), "b": Color("9ad8ff"), "c": Color("ffffff")},
		{"name": "SUNSET GLOW", "pattern": 26, "a": Color("6b2fb5"), "b": Color("ff9a3d"), "c": Color("ffffff")},  # 30
		{"name": "NIGHT SKY", "pattern": 28, "a": Color("0d0d22"), "b": Color("ffffff")},
		{"name": "OCEAN DOTS", "pattern": 22, "a": Color("0f2a6b"), "b": Color("3fe0ff")},
		{"name": "FROZEN", "pattern": 26, "a": Color("3fb8ff"), "b": Color("ffffff"), "c": Color("bff3ff")},
		{"name": "AURORA", "pattern": 26, "a": Color("2a1a6b"), "b": Color("3fffa8"), "c": Color("ffffff")},
		{"name": "NEON ZIGZAG", "pattern": 25, "a": Color("15121f"), "b": Color("ff3fd0"), "c": Color("3fe8ff")},  # 35
		{"name": "DIAMOND", "pattern": 26, "a": Color("dff6ff"), "b": Color("ffffff"), "c": Color("9fe4ff")},
		{"name": "FIRE", "pattern": 29, "price": -1, "unlock": "streak"},
		{"name": "PUMPKIN", "pattern": 30, "price": -1, "unlock": "season:halloween"},
		{"name": "ORNAMENT", "pattern": 31, "a": Color("d81f2e"), "price": -1, "unlock": "season:christmas"},
	]
	# cheapest -> most legendary; prices grow from free to 5,000,000
	var order := [0, 19, 20, 6, 21, 10, 7, 8, 22, 23, 9, 11, 1, 24, 14, 25, 26, 2, 12, 27,
		13, 3, 4, 28, 29, 5, 30, 31, 15, 32, 33, 16, 34, 35, 17, 36]
	for k in order.size():
		var it: Dictionary = _items["hull"][order[k]]
		it["price"] = 0 if k == 0 else _nice(1000.0 * pow(5000.0, float(k - 1) / float(order.size() - 2)))
	for it in _items["hull"]:
		if not it.has("price"):
			it["price"] = -1
	_ball_order = order.duplicate()
	for i in _items["hull"].size():
		if not _ball_order.has(i):
			_ball_order.append(i)    # exclusives at the end
	# wallpapers: the sky behind everything
	_items["sky"] = [
		{"name": "WORLD SKY", "price": 0},
		{"name": "SUNNY DAY", "top": Color("2f8cff"), "horizon": Color("bfe8ff"), "fog": Color("a8d8ff"), "price": 5000},
		{"name": "GOLDEN HOUR", "top": Color("ff8a3d"), "horizon": Color("ffe0a0"), "fog": Color("ffc890"), "price": 15000},
		{"name": "CANDY SKY", "top": Color("ff7ac6"), "horizon": Color("ffe8f6"), "fog": Color("ffc0e4"), "price": 40000},
		{"name": "MINT DREAM", "top": Color("29c4a8"), "horizon": Color("e0fff4"), "fog": Color("a8f0dc"), "price": 90000},
		{"name": "SUNSET", "top": Color("3a1a6b"), "horizon": Color("ff7a4a"), "fog": Color("c0507a"), "price": 200000},
		{"name": "STORM", "top": Color("2a3040"), "horizon": Color("8a9ab0"), "fog": Color("5a6a80"), "price": 400000},
		{"name": "NIGHT STARS", "top": Color("050818"), "horizon": Color("2a3a8a"), "fog": Color("141a4a"), "price": 800000},
		{"name": "AURORA", "top": Color("061a2a"), "horizon": Color("3fffa8"), "fog": Color("1a5a6a"), "price": 1500000},
		{"name": "DEEP SPACE", "top": Color("000000"), "horizon": Color("6a2fd0"), "fog": Color("1a0a3a"), "price": 3000000},
		{"name": "RAINBOW SKY", "top": Color("7a5cff"), "horizon": Color("ffd0f0"), "fog": Color("c8b0ff"), "price": -1, "unlock": "rank:10"},
		{"name": "CHAMPION GOLD", "top": Color("a8701a"), "horizon": Color("ffe9a0"), "fog": Color("e0b860"), "price": -1, "unlock": "rank:50"},
	]
	var paints := _palette([0, 300, 300, 500, 800, 800, 1200, 1500, 2000, 2500])
	paints.append({"name": "GOLDEN", "color": Color("ffcf40"), "price": -1, "unlock": "rank:20"})
	paints.append({"name": "PUMPKIN", "color": Color("ff7a1a"), "price": -1, "unlock": "season:halloween"})
	paints.append({"name": "CANDY CANE", "color": Color("e8202e"), "price": -1, "unlock": "season:christmas"})
	_items["paint"] = paints
	var sails := _palette([500, 500, 500, 500, 800, 800, 0, 1200, 1500, 2000])
	var white: Dictionary = sails[6]
	sails.remove_at(6)
	sails.insert(0, white)
	sails.append({"name": "GALAXY", "color": Color("6a3dff"), "price": -1, "unlock": "rank:30"})
	_items["sail"] = sails
	_items["flag"] = [
		{"name": "SUNNY", "a": Color("ffd23f"), "b": Color("ffd23f"), "pattern": "solid", "price": 0},
		{"name": "RACER", "a": Color("ffffff"), "b": Color("1e1b2e"), "pattern": "stripes", "price": 400},
		{"name": "MOON", "a": Color("2b2f5a"), "b": Color("ffe9a8"), "pattern": "dot", "price": 700},
		{"name": "WAVES", "a": Color("4ea8ff"), "b": Color("ffffff"), "pattern": "stripes", "price": 900},
		{"name": "HEART", "a": Color("ff5a7a"), "b": Color("ffd1dc"), "pattern": "dot", "price": 1200},
		{"name": "NORDIC", "a": Color("3a6fd8"), "b": Color("ffd23f"), "pattern": "cross", "price": 1800},
		{"name": "JOLLY", "a": Color("1e1b2e"), "b": Color("f4f4f4"), "pattern": "dot", "price": 2500},
		{"name": "CHAMPION", "a": Color("ffc531"), "b": Color("e8433a"), "pattern": "cross", "price": -1, "unlock": "rank:15"},
	]
	_items["hat"] = [
		{"name": "CAPTAIN", "kind": "cap", "price": 0},
		{"name": "BEANIE", "kind": "beanie", "price": 800},
		{"name": "STRAW HAT", "kind": "straw", "price": 1500},
		{"name": "PARTY", "kind": "party", "price": 2500},
		{"name": "TOP HAT", "kind": "top", "price": 4000},
		{"name": "CROWN", "kind": "crown", "price": 9000},
		{"name": "PIRATE", "kind": "pirate", "price": -1, "unlock": "rank:10"},
		{"name": "WITCH HAT", "kind": "witch", "price": -1, "unlock": "season:halloween"},
		{"name": "SANTA HAT", "kind": "santa", "price": -1, "unlock": "season:christmas"},
	]
	_items["trail"] = [
		{"name": "FOAM", "a": Color(1, 1, 1), "b": Color(1, 1, 1), "price": 0},
		{"name": "GOLD", "a": Color("ffd23f"), "b": Color("ff9a1f"), "price": 2000},
		{"name": "CANDY", "a": Color("ff7ac8"), "b": Color("ffffff"), "price": 2000},
		{"name": "ICE", "a": Color("8fe3ff"), "b": Color("ffffff"), "price": 3000},
		{"name": "MOONLIGHT", "a": Color("b9a7ff"), "b": Color("6be3ff"), "price": 5000},
		{"name": "RAINBOW", "a": Color("ff5a4e"), "b": Color("4ea8ff"), "price": 10000},
		{"name": "FIRE", "a": Color("ff4d1f"), "b": Color("ffd23f"), "price": 12000},
		{"name": "GHOST", "a": Color("b14dff"), "b": Color("ff7a1a"), "price": -1, "unlock": "season:halloween"},
		{"name": "SNOWFALL", "a": Color("ffffff"), "b": Color("8fe3ff"), "price": -1, "unlock": "season:christmas"},
	]
	_items["wall"] = [
		{"name": "TECH WALL", "style": "canyon", "price": 0},
		{"name": "SPACEPORT", "style": "harbor", "price": 0},
		{"name": "MAGLEV DOCK", "style": "pier", "price": 3000},
		{"name": "HAB DOMES", "style": "village", "price": 6000},
		{"name": "CRYSTAL CAVE", "style": "crystal", "price": 12000},
		{"name": "SYNTHWAVE", "style": "candy", "price": 20000},
		{"name": "GOLDEN CORE", "style": "temple", "price": -1, "unlock": "rank:40"},
		{"name": "NEON CITY", "style": "neon", "price": -1, "unlock": "rank:50"},
	]
	# coins come in fast, so everything except the balls (priced above) costs 8x
	for cat in CATS:
		if cat == "hull" or cat == "sky":
			continue
		for it in _items[cat]:
			if int(it.price) > 0:
				it.price = int(it.price) * 8
