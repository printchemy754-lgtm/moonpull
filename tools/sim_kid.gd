extends SceneTree
## Steering playtest bots using the real generator (scripts/level_gen.gd).
## "kid" = slow, noisy decisions and a slow finger. Counts crashes per level
## (the game gives 3 free lives per level).
## Run: copy into game/ and  godot --headless --path game --script res://sim_kid.gd

const DT := 1.0 / 60.0


func _init() -> void:
	# a player who never steers must crash at almost everything
	var straight := 0
	var obstacles := 0
	for lv in range(1, 21):
		var d := LevelGen.generate(lv)
		for e in d.items:
			if LevelGen.is_obstacle(e.kind) and not e.get("air", false):
				obstacles += 1
				var hit := false
				for k in 12:
					if LevelGen.clearance(e, k * 0.37, 0.0) + LevelGen.HIT_GRACE < 0.0:
						hit = true
				if hit:
					straight += 1
	print("going straight hits %d of %d obstacles" % [straight, obstacles])
	for cfg in [[0.2, 0.2, 8.0], [0.3, 0.35, 6.0], [0.45, 0.5, 4.5]]:
		var line := "decide %.2fs noise %.2f finger %.1fm/s:" % cfg
		var lost := 0
		for lv in range(1, 21):
			var tot := 0
			for sd in 5:
				var data := LevelGen.generate(lv, -1 if sd == 0 else lv * 100 + sd)
				var c := _run(data, cfg[0], cfg[1], cfg[2], sd)
				tot += c
				if c >= 3:
					lost += 1
			line += " %d:%.1f" % [lv, tot / 5.0]
		print(line, "  | runs lost (3+ crashes): ", lost, "/100")
	quit()


func _run(data: Dictionary, interval: float, noise: float, finger: float, sd: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 77 + 3
	var items: Array = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	var speed: float = data.speed
	var x := 0.0
	var target := 0.0
	var z := 0.0
	var t := 0.0
	var next_dec := 0.0
	var crashes := 0
	var air := -1.0
	while z < float(data.finish) and crashes < 10:
		if t >= next_dec:
			next_dec = t + interval * rng.randf_range(0.7, 1.3)
			target = LevelGen.pilot_target(items, z, t, speed, x) + rng.randf_range(-noise, noise)
		x = move_toward(x, clampf(target, -LevelGen.X_MAX, LevelGen.X_MAX), finger * DT)
		z += speed * DT
		t += DT
		if air >= 0.0:
			air += DT
			if air >= LevelGen.JUMP_TIME:
				air = -1.0
			continue
		for e in items:
			if float(e.z) > z + 3.0:
				break
			if e.kind == "ramp" and not e.get("taken", false) and z + LevelGen.BOAT_HALF_LEN >= float(e.z) - 1.0:
				e["taken"] = true
				air = 0.0
		for e in items:
			if not LevelGen.is_obstacle(e.kind) or e.get("done", false) or e.get("air", false):
				continue
			var z0 := float(e.z) - float(e.depth) * 0.5
			var z1 := float(e.z) + float(e.depth) * 0.5
			if z1 < z - LevelGen.BOAT_HALF_LEN or z0 > z + LevelGen.BOAT_HALF_LEN:
				continue
			if LevelGen.clearance(e, t, x) + LevelGen.HIT_GRACE < 0.0:
				crashes += 1
				e["done"] = true
				z = z0 - LevelGen.BOAT_HALF_LEN - speed * 1.3
				x = LevelGen.safe_x(e, t + 2.0, x)
				target = x
				t += 2.0
				break
	return crashes
