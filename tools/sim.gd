extends SceneTree
## Passability check that uses the REAL level generator (scripts/level_gen.gd).
## A "human" bot that only re-decides every 0.05 / 0.15 / 0.2 seconds.
## Run:  godot --headless --path game --script res://../tools/sim.gd
## (or copy into game/ and run with --script res://sim.gd)

const ACCEL := 16.0
const DT := 1.0 / 60.0


func _init() -> void:
	for interval in [0.05, 0.15, 0.2]:
		var fails := {}
		var causes := {}
		for lv in range(1, 31):
			for sd in 4:
				var data := LevelGen.generate(lv, -1 if sd == 0 else lv * 100 + sd)
				var why := _run(data, interval)
				if why != "":
					fails[lv] = int(fails.get(lv, 0)) + 1
					causes[why] = int(causes.get(why, 0)) + 1
		print("interval %.2f: failing levels %s causes %s" % [interval, str(fails), str(causes)])
	for seed_i in 4:
		var d := LevelGen.generate_endless(1000 + seed_i)
		var r := _endless(d, 0.15)
		print("endless seed %d (0.15s): score %d" % [seed_i, int(r / 2.0)])
	print("SIM DONE")
	quit()


## Plays one level like tools/sim.py: decides every `interval` seconds.
## Returns "" if it reached the finish, else the kind that wrecked it.
func _run(data: Dictionary, interval: float) -> String:
	var items: Array = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	var speed: float = data.speed
	var rise: float = data.rise
	var fall: float = data.fall
	var water := LevelGen.WATER_REST
	var vel := 0.0
	var z := 0.0
	var t := 0.0
	var holding := false
	var next_dec := 0.0
	while z < float(data.finish):
		if t >= next_dec:
			next_dec = t + interval
			var tgt := LevelGen.pilot_target(items, z, t, speed, water)
			holding = water + vel * absf(vel) / (2.0 * ACCEL) + vel * interval < tgt
		vel = move_toward(vel, rise if holding else -fall, ACCEL * DT)
		water = clampf(water + vel * DT, LevelGen.WATER_MIN, LevelGen.WATER_MAX)
		z += speed * DT
		t += DT
		for e in items:
			if float(e.z) > z + 5.0:
				break
			if LevelGen.is_current(e.kind) and not e.get("taken", false) and z + LevelGen.BOAT_HALF_LEN >= float(e.z) - float(e.depth) * 0.5:
				e["taken"] = true
				vel = LevelGen.CURRENT_V * (1.0 if e.kind == "geyser" else -1.0)
		for e in items:
			if not LevelGen.is_obstacle(e.kind):
				continue
			var z0 := float(e.z) - float(e.depth) * 0.5
			var z1 := float(e.z) + float(e.depth) * 0.5
			if z1 < z - LevelGen.BOAT_HALF_LEN or z0 > z + LevelGen.BOAT_HALF_LEN:
				continue
			if LevelGen.clearance(e, t, water) + LevelGen.HIT_GRACE < 0.0:
				return String(e.kind)
	return ""


func _endless(data: Dictionary, reaction: float) -> float:
	var items: Array = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	var water := LevelGen.WATER_REST
	var vel := 0.0
	var z := 0.0
	var t := 0.0
	var holding := false
	var decide := 0.0
	while z < float(data.finish):
		var lv := LevelGen.ramp_level(data, z)
		var speed := LevelGen.speed_for(lv)
		var rise := LevelGen.rise_for(lv)
		var fall := LevelGen.fall_for(lv)
		t += DT
		decide -= DT
		if decide <= 0.0:
			decide = reaction
			var tgt := LevelGen.pilot_target(items, z, t, speed, water)
			holding = water + vel * absf(vel) / (2.0 * ACCEL) + vel * reaction < tgt
		vel = move_toward(vel, rise if holding else -fall, ACCEL * DT)
		water = clampf(water + vel * DT, LevelGen.WATER_MIN, LevelGen.WATER_MAX)
		z += speed * DT
		for e in items:
			if float(e.z) > z + 5.0:
				break
			if LevelGen.is_current(e.kind) and not e.get("taken", false) and z + LevelGen.BOAT_HALF_LEN >= float(e.z) - float(e.depth) * 0.5:
				e["taken"] = true
				vel = LevelGen.CURRENT_V * (1.0 if e.kind == "geyser" else -1.0)
		if LevelGen.hits(items, z, water, t):
			return z
	return z
