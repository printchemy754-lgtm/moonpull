class_name Custom
extends RefCounted
## Workshop catalogue. Every category has free starter items.
## price -1 + "unlock" = exclusive (rank reward or 7-day streak), can't be bought.

const CATS := ["hull", "paint", "sail", "flag", "hat", "trail", "wall"]
const CAT_NAMES := {
	"hull": "BOAT", "paint": "PAINT", "sail": "SAILS", "flag": "FLAG", "hat": "HAT", "trail": "WAKE", "wall": "WALLS",
}
## Equip slots -> the category whose items they use. Walls: one purchase, two slots.
const SLOTS := {
	"hull": "hull", "paint": "paint", "sail": "sail", "flag": "flag", "hat": "hat", "trail": "trail",
	"wall_l": "wall", "wall_r": "wall",
}
const DEFAULTS := {"wall_l": 0, "wall_r": 1}
const RARITY_COLORS := {
	"common": Color("9aa3c7"), "rare": Color("4ea8ff"), "epic": Color("b57bff"),
	"legendary": Color("ffb020"), "exclusive": Color("ff4f7a"),
}

static var _items := {}


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
	if p >= 15000:
		return "legendary"
	if p >= 5000:
		return "epic"
	if p >= 1000:
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
	for cat in CATS:
		var list := items(cat)
		for i in list.size():
			if String(list[i].get("unlock", "")) == "rank:%d" % rank:
				out.append([cat, i])
	return out


static func streak_unlock() -> Array:
	for cat in CATS:
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
	_items["hull"] = [
		{"name": "SKIMMER", "price": 0},
		{"name": "HAULER", "price": 2000},
		{"name": "INTERCEPTOR", "price": 5000},
		{"name": "SOLAR JUNK", "price": 10000},
		{"name": "ROBO DUCK", "price": 18000},
		{"name": "MOON SKIFF", "price": 30000},
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
		{"name": "FIRE", "a": Color("ff4d1f"), "b": Color("ffd23f"), "price": -1, "unlock": "streak"},
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
