class_name Upgrades
extends RefCounted
## Permanent power-ups bought with coins (Save.upgrades: id -> level 0..MAX).
## Every level is a real, felt difference — the long-term coin sink.

const MAX := 5
const COSTS := [5000, 12000, 27000, 54000, 96000]
const LIST := [
	{"id": "fever", "name": "FEVER TIME", "icon": "bolt", "color": Color("ff4fd8"), "desc": "FEVER lasts %.0fs"},
	{"id": "charge", "name": "FEVER CHARGE", "icon": "wave", "color": Color("ff8a3d"), "desc": "FEVER after %d clean passes"},
	{"id": "coin", "name": "COIN VALUE", "icon": "coin", "color": Color("ffd166"), "desc": "Every coin is worth %d"},
	{"id": "magnet", "name": "MAGNET", "icon": "magnet", "color": Color("54e0ff"), "desc": "Magnet lasts %.0fs"},
	{"id": "shield", "name": "START SHIELD", "icon": "shield", "color": Color("7dffb0"), "desc": "%d%% chance to start with a shield"},
]


static func level(id: String) -> int:
	return int(Save.upgrades.get(id, 0))


static func cost(id: String) -> int:
	var lv := level(id)
	return -1 if lv >= MAX else int(COSTS[lv])


static func fever_time(lv := -1) -> float:
	return 5.0 + 1.0 * float(level("fever") if lv < 0 else lv)


static func fever_need(lv := -1) -> int:
	return 8 - (level("charge") if lv < 0 else lv)


static func coin_value(lv := -1) -> int:
	return 10 + 2 * (level("coin") if lv < 0 else lv)


static func magnet_time(lv := -1) -> float:
	return 6.0 + 1.5 * float(level("magnet") if lv < 0 else lv)


static func shield_chance(lv := -1) -> int:
	return 20 * (level("shield") if lv < 0 else lv)


## Text of the effect at level `lv`.
static func describe(id: String, lv: int) -> String:
	for u in LIST:
		if u.id != id:
			continue
		match id:
			"fever": return String(u.desc) % fever_time(lv)
			"charge": return String(u.desc) % fever_need(lv)
			"coin": return String(u.desc) % coin_value(lv)
			"magnet": return String(u.desc) % magnet_time(lv)
			"shield": return String(u.desc) % shield_chance(lv)
	return ""


## Something the player can afford right now (for the menu badge).
static func any_affordable() -> bool:
	for u in LIST:
		var c := cost(u.id)
		if c > 0 and Save.coins >= c:
			return true
	return false


static func buy(id: String) -> bool:
	var c := cost(id)
	if c < 0 or Save.coins < c:
		return false
	Save.coins -= c
	Save.upgrades[id] = level(id) + 1
	Save.save()
	return true
