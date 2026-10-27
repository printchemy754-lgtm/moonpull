class_name Missions
extends RefCounted
## Three daily tasks (same for everyone on the same day), stored in Save.missions.

const POOL := [
	{"id": "coins", "text": "Collect %s coins", "targets": [300, 600, 1000], "reward": [150, 250, 400]},
	{"id": "levels", "text": "Complete %s levels", "targets": [2, 3, 5], "reward": [200, 300, 500]},
	{"id": "close", "text": "Make %s close calls", "targets": [3, 5, 8], "reward": [200, 300, 450]},
	{"id": "rings", "text": "Fly through %s rings", "targets": [2, 4, 6], "reward": [150, 250, 400]},
	{"id": "stars3", "text": "Get 3 stars on %s levels", "targets": [1, 2, 3], "reward": [250, 400, 600]},
	{"id": "races", "text": "Finish %s races", "targets": [1, 2, 3], "reward": [200, 300, 450]},
	{"id": "race_win", "text": "Win %s race", "targets": [1, 1, 2], "reward": [400, 400, 700]},
	{"id": "endless", "text": "Score %s total in Endless", "targets": [300, 600, 1000], "reward": [200, 350, 600]},
	{"id": "fever", "text": "Trigger FEVER %s times", "targets": [2, 4, 6], "reward": [250, 400, 600]},
	{"id": "smash", "text": "Smash %s obstacles in FEVER", "targets": [5, 10, 20], "reward": [200, 350, 550]},
]
const ALL_DONE_BONUS := 500


static func ensure_today() -> void:
	var day := Save.today()
	if int(Save.missions.get("day", -1)) == day:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 1013 + 7
	var ids := range(POOL.size())
	var list := []
	for k in 3:
		var pick: int = ids[rng.randi() % ids.size()]
		ids.erase(pick)
		var m: Dictionary = POOL[pick]
		var tier := rng.randi() % 3
		list.append({"id": m.id, "target": m.targets[tier], "reward": m.reward[tier], "progress": 0, "claimed": false})
	Save.missions = {"day": day, "list": list, "bonus": false}
	Save.save()


static func list() -> Array:
	ensure_today()
	return Save.missions.list


static func text(m: Dictionary) -> String:
	for p in POOL:
		if p.id == m.id:
			return String(p.text) % str(m.target)
	return ""


## Report progress, e.g. Missions.track("coins", 10). Returns true if a task just completed.
static func track(id: String, amount := 1) -> bool:
	ensure_today()
	var completed := false
	for m in Save.missions.list:
		if m.id == id and not m.claimed and int(m.progress) < int(m.target):
			m.progress = mini(int(m.progress) + amount, int(m.target))
			if int(m.progress) >= int(m.target):
				completed = true
	Save.save()
	return completed


static func claimable() -> int:
	var n := 0
	for m in list():
		if not m.claimed and int(m.progress) >= int(m.target):
			n += 1
	if bonus_ready():
		n += 1
	return n


static func claim(i: int) -> int:
	var m: Dictionary = list()[i]
	if m.claimed or int(m.progress) < int(m.target):
		return 0
	m.claimed = true
	Save.add_coins(int(m.reward))
	return int(m.reward)


static func bonus_ready() -> bool:
	if Save.missions.get("bonus", false):
		return false
	for m in Save.missions.get("list", []):
		if not m.claimed:
			return false
	return not Save.missions.get("list", []).is_empty()


static func claim_bonus() -> int:
	if not bonus_ready():
		return 0
	Save.missions.bonus = true
	Save.add_coins(ALL_DONE_BONUS)
	return ALL_DONE_BONUS
