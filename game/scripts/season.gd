class_name Season
extends RefCounted
## Seasonal editions: HALLOWEEN (10 Oct - 10 Nov) and CHRISTMAS (1 Dec - 10 Jan).
## "auto" follows the calendar; the player can also force one in Settings.
## A season re-skins every world, swaps coins for candy / presents, changes
## the music and unlocks event-only boat items (one per level won).

const PREFS := ["auto", "off", "halloween", "christmas"]
const NAMES := {"off": "OFF", "auto": "AUTO", "halloween": "HALLOWEEN", "christmas": "CHRISTMAS"}


static func by_date() -> String:
	var d := Time.get_date_dict_from_system()
	var m := int(d.month)
	var day := int(d.day)
	if (m == 10 and day >= 10) or (m == 11 and day <= 10):
		return "halloween"
	if m == 12 or (m == 1 and day <= 10):
		return "christmas"
	return ""


## "" when no season is active.
static func current() -> String:
	match Save.season:
		"off": return ""
		"halloween", "christmas": return Save.season
	return by_date()


static func title() -> String:
	match current():
		"halloween": return "HALLOWEEN EVENT"
		"christmas": return "CHRISTMAS EVENT"
	return ""


static func color() -> Color:
	return Color("ff8a1a") if current() == "halloween" else Color("ff4d4d")


## Returns a re-skinned copy of a world theme.
static func decorate(th: Dictionary) -> Dictionary:
	var s := current()
	if s == "":
		return th
	var t := th.duplicate()
	t["season"] = s
	if s == "halloween":
		t.name = "Spooky " + String(th.name)
		t.sky_top = Color("12041f")
		t.sky_horizon = Color("ff6a00")
		t.ground = Color("1a0612")
		t.fog = Color("3a1030")
		t.fog_density = 0.008
		t.water_deep = Color("120414")
		t.water_shallow = Color("3a0f2a")
		t.grid = Color("ff7a1a")
		t.edge = Color("9b3dff")
		t.neon = Color("ff7a1a")
		t.neon2 = Color("b14dff")
		t.rock_tip = Color("ff7a1a")
		t.lamp = Color("ffb347")
		t.deco = "pumpkin"
		t.deco_a = Color("ff7a1a")
		t.particles = "bats"
		t.moon = Color("ffcf8a")
		t.fall = Color("9b3dff")
	else:
		t.name = "Frosty " + String(th.name)
		t.sky_top = Color("0a1838")
		t.sky_horizon = Color("9fd8ff")
		t.ground = Color("cfe6ff")
		t.fog = Color("b8d4ee")
		t.fog_density = 0.008
		t.water_deep = Color("0a2040")
		t.water_shallow = Color("1f5f9a")
		t.grid = Color("ffffff")
		t.edge = Color("ff3d3d")
		t.neon = Color("ff3d3d")
		t.neon2 = Color("3dff7a")
		t.rock_tip = Color("ff3d3d")
		t.lamp = Color("ffe680")
		t.deco = "xmas_tree"
		t.deco_a = Color("2e9e4f")
		t.particles = "snow"
		t.moon = Color("ffffff")
		t.fall = Color("bff3ff")
	return t


## Event items still locked for the current season: [[cat, index], ...]
static func locked_items() -> Array:
	var s := current()
	var out := []
	if s == "":
		return out
	for cat in Custom.CATS:
		var list := Custom.items(cat)
		for i in list.size():
			if String(list[i].get("unlock", "")) == "season:" + s and not Save.owns(cat, i):
				out.append([cat, i])
	return out
