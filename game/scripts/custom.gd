class_name Custom
extends RefCounted
## Boat workshop catalogue. Every category has a free first item.

const CATS := ["hull", "paint", "sail", "flag", "hat", "trail"]
const CAT_NAMES := {
	"hull": "BOAT", "paint": "PAINT", "sail": "SAILS", "flag": "FLAG", "hat": "HAT", "trail": "WAKE",
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
		{"name": "DINGHY", "price": 0},
		{"name": "TUGBOAT", "price": 1500},
		{"name": "SPEEDSTER", "price": 3000},
		{"name": "LANTERN JUNK", "price": 5000},
		{"name": "RUBBER DUCK", "price": 8000},
		{"name": "MOON SKIFF", "price": 12000},
	]
	_items["paint"] = _palette([0, 400, 400, 400, 600, 600, 800, 800, 1000, 1000])
	var sails := _palette([400, 400, 400, 400, 600, 600, 0, 800, 1000, 1000])
	# white sails first (free)
	var white: Dictionary = sails[6]
	sails.remove_at(6)
	sails.insert(0, white)
	_items["sail"] = sails
	_items["flag"] = [
		{"name": "SUNNY", "a": Color("ffd23f"), "b": Color("ffd23f"), "pattern": "solid", "price": 0},
		{"name": "RACER", "a": Color("ffffff"), "b": Color("1e1b2e"), "pattern": "stripes", "price": 300},
		{"name": "MOON", "a": Color("2b2f5a"), "b": Color("ffe9a8"), "pattern": "dot", "price": 500},
		{"name": "WAVES", "a": Color("4ea8ff"), "b": Color("ffffff"), "pattern": "stripes", "price": 500},
		{"name": "HEART", "a": Color("ff5a7a"), "b": Color("ffd1dc"), "pattern": "dot", "price": 700},
		{"name": "NORDIC", "a": Color("3a6fd8"), "b": Color("ffd23f"), "pattern": "cross", "price": 900},
		{"name": "JOLLY", "a": Color("1e1b2e"), "b": Color("f4f4f4"), "pattern": "dot", "price": 1200},
	]
	_items["hat"] = [
		{"name": "CAPTAIN", "kind": "cap", "price": 0},
		{"name": "BEANIE", "kind": "beanie", "price": 600},
		{"name": "STRAW HAT", "kind": "straw", "price": 900},
		{"name": "PARTY", "kind": "party", "price": 1200},
		{"name": "TOP HAT", "kind": "top", "price": 2000},
		{"name": "CROWN", "kind": "crown", "price": 5000},
	]
	_items["trail"] = [
		{"name": "FOAM", "a": Color(1, 1, 1), "b": Color(1, 1, 1), "price": 0},
		{"name": "GOLD", "a": Color("ffd23f"), "b": Color("ff9a1f"), "price": 1500},
		{"name": "CANDY", "a": Color("ff7ac8"), "b": Color("ffffff"), "price": 1500},
		{"name": "ICE", "a": Color("8fe3ff"), "b": Color("ffffff"), "price": 2000},
		{"name": "MOONLIGHT", "a": Color("b9a7ff"), "b": Color("6be3ff"), "price": 3000},
		{"name": "RAINBOW", "a": Color("ff5a4e"), "b": Color("4ea8ff"), "price": 6000},
	]
