extends SceneTree
## Sloppy "young player" bot: slow, noisy decisions. Counts crashes per level.
const ACCEL := 16.0
const DT := 1.0 / 60.0

func _init() -> void:
	for interval in [0.2, 0.3, 0.4]:
		var line := "interval %.2f avg crashes:" % interval
		var lost := 0
		for lv in range(1, 21):
			var tot := 0
			for sd in 5:
				var data := LevelGen.generate(lv, -1 if sd == 0 else lv * 100 + sd)
				var c := _run(data, interval, 0.26 if lv <= 8 else 0.15, sd)
				tot += c
				if c >= 3:
					lost += 1
			line += " %d:%.1f" % [lv, tot / 5.0]
		print(line, "  | runs lost (3+ crashes): ", lost, "/100")
	quit()

func _run(data: Dictionary, interval: float, grace: float, sd: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 77 + 3
	var items: Array = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	var speed: float = data.speed
	var water := LevelGen.WATER_REST
	var vel := 0.0
	var z := 0.0
	var t := 0.0
	var holding := false
	var next_dec := 0.0
	var crashes := 0
	while z < float(data.finish) and crashes < 10:
		if t >= next_dec:
			next_dec = t + interval * rng.randf_range(0.7, 1.3)
			var tgt := _kid_target(items, z, t, speed, water) + rng.randf_range(-0.25, 0.25)
			holding = water + vel * absf(vel) / (2.0 * ACCEL) + vel * interval < tgt
		vel = move_toward(vel, data.rise if holding else -data.fall, ACCEL * DT)
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
			if not LevelGen.is_obstacle(e.kind) or e.get("done", false) or e.get("air", false):
				continue
			var z0 := float(e.z) - float(e.depth) * 0.5
			var z1 := float(e.z) + float(e.depth) * 0.5
			if z1 < z - LevelGen.BOAT_HALF_LEN or z0 > z + LevelGen.BOAT_HALF_LEN:
				continue
			if LevelGen.clearance(e, t, water) + grace < 0.0:
				crashes += 1
				e["done"] = true
				z = z0 - LevelGen.BOAT_HALF_LEN - speed * 1.3
				var r := LevelGen.safe_range(e, t + 1.3, water)
				water = clampf((r.x + r.y) * 0.5, LevelGen.WATER_MIN, LevelGen.WATER_MAX)
				vel = 0.0
				t += 2.0
				break
	return crashes


## Kids don't skim the edge: they aim for the middle of the open space.
func _kid_target(items: Array, z: float, t: float, speed: float, water: float) -> float:
	for e in items:
		if not LevelGen.is_obstacle(e.kind) or e.get("done", false) or e.get("air", false):
			continue
		if float(e.z) + float(e.depth) * 0.5 < z - LevelGen.BOAT_HALF_LEN:
			continue
		var p := LevelGen.pilot_target(items, z, t, speed, water)
		if e.kind in ["reef", "bridge", "gate", "mine"]:
			var r := LevelGen.safe_range(e, t, water)
			return clampf((r.x + r.y) * 0.5, r.x + 0.45, r.y - 0.45) if r.y - r.x > 0.9 else (r.x + r.y) * 0.5
		return p
	return LevelGen.WATER_REST
