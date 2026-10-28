extends SceneTree
## Playtest bots for the moon-ball game, using the real generator and the same
## rules as main.gd (steering, curve drift, rails, holes, ramps, obstacles).
## "kid" = slow, noisy decisions and a slow finger. Counts falls/crashes per
## level (the game gives 3 free lives per level + checkpoints).
## Run: copy into game/ and  godot --headless --path game --script res://sim_kid.gd
##      (add  -- debug  to print where the perfect bot fails)

const DT := 1.0 / 60.0
var debug := false
var causes := {}


func _init() -> void:
	debug = "debug" in OS.get_cmdline_user_args()
	if "endless" in OS.get_cmdline_user_args():
		debug = true
		for sd in 3:
			var d := LevelGen.generate_endless(500 + sd)
			print("endless seed %d crashes=%d" % [sd, _run(d, 0.06, 0.0, 30.0, sd, 99)])
		quit()
		return
	var cfgs := [[0.06, 0.0, 30.0, "perfect"], [0.2, 0.2, 9.0, "good"], [0.3, 0.35, 7.0, "kid"], [0.45, 0.5, 5.5, "slow kid"]]
	if debug:
		cfgs = [cfgs[0]]
	for cfg in cfgs:
		var line := "%-8s:" % cfg[3]
		var lost := 0
		for lv in range(1, 21):
			var tot := 0
			for sd in 4:
				var data := LevelGen.generate(lv, -1 if sd == 0 else lv * 100 + sd)
				var c := _run(data, cfg[0], cfg[1], cfg[2], sd, lv)
				tot += c
				if c >= 3:
					lost += 1
			line += " %d:%.1f" % [lv, tot / 4.0]
		print(line, "  | runs lost (3+): ", lost, "/80")
		print("   causes: ", causes)
		causes = {}
	quit()


func _run(data: Dictionary, interval: float, noise: float, finger: float, sd: int, lv: int) -> int:
	var tr: Track = data.track
	LevelGen.track = tr
	var rng := RandomNumberGenerator.new()
	rng.seed = sd * 77 + 3
	var items: Array = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	var speed: float = data.speed
	var endless: bool = data.get("endless", false)
	var x := 0.0
	var target := 0.0
	var z := 2.0
	var t := 0.0
	var y := 0.0
	var vy := 0.0
	var grounded := true
	var doomed := false
	var next_dec := 0.0
	var crashes := 0
	var last_cp := 2.0
	while z < minf(float(data.finish), 6000.0) and crashes < 10:
		t += DT
		if endless:
			speed = LevelGen.speed_for(LevelGen.ramp_level(data, z))
		var f := clampf(1.0 - tr.slope(z) * 1.2, 0.8, 1.35)
		var v := speed * f
		if not doomed:
			z += v * DT
		if grounded and t >= next_dec:
			next_dec = t + interval * rng.randf_range(0.7, 1.3)
			target = LevelGen.pilot_target(items, z, t, v, x) + rng.randf_range(-noise, noise)
		var zone := ""
		for e in items:
			if e.kind == "portal" and float(e.z) <= z:
				zone = String(e.zone)
		if grounded:
			target -= tr.curvature(z) * v * v * LevelGen.DRIFT * DT * (2.0 if zone == "FROST PEAK" else 1.0)
			if zone == "WILD DESERT":
				target += sin(t * 0.8) * 1.3 * DT
		x = move_toward(x, target, finger * DT)
		if tr.rails_at(z) and grounded:
			var b := tr.bounds(z)
			x = clampf(x, b.x + LevelGen.R, b.y - LevelGen.R)
		# physics
		if grounded:
			y = 0.0
			if not tr.floor_ok(z, x, t) and not tr.rails_at(z):
				grounded = false
				vy = 0.0
		else:
			vy -= LevelGen.GRAVITY * DT
			y += vy * DT
			if y <= 0.0:
				if not doomed and y > -0.35 and tr.floor_ok(z, x, t):
					grounded = true
					y = 0.0
					vy = 0.0
				elif y < -0.35:
					doomed = true
		var fail := ""
		if doomed and y < -6.0:
			fail = "fall"
		for e in items:
			if float(e.z) > z + 2.0:
				break
			if e.kind == "checkpoint" and float(e.z) <= z:
				last_cp = maxf(last_cp, float(e.z))
			if e.kind == "ramp" and not e.get("taken", false) and float(e.z) <= z:
				e["taken"] = true
				if grounded:
					grounded = false
					vy = LevelGen.JUMP_V
			if LevelGen.is_obstacle(e.kind) and y < 1.6 and not doomed:
				var z0 := float(e.z) - float(e.depth) * 0.5
				var z1 := float(e.z) + float(e.depth) * 0.5
				if z1 >= z - LevelGen.BOAT_HALF_LEN and z0 <= z + LevelGen.BOAT_HALF_LEN:
					if LevelGen.clearance(e, t, x) + LevelGen.HIT_GRACE < 0.0:
						fail = String(e.kind)
		if fail != "":
			crashes += 1
			var why := fail
			if fail == "fall":
				why = "fall:edge"
				for e in items:
					if LevelGen.is_void(e.kind) and absf(float(e.z) - z) < float(e.depth) * 0.5 + 3.0:
						why = "fall:" + ("zig/narrow" if (e.blocks as Array).size() == 2 and e.kind == "void" else ("platform" if e.kind == "pvoid" else "hole/split"))
						break
				if why == "fall:edge" and absf(tr.curvature(z)) > 0.01:
					why = "fall:curve"
			causes[why] = int(causes.get(why, 0)) + 1
			if debug:
				var near := []
				for e in items:
					if absf(float(e.z) - z) < 14.0:
						near.append("%s@%.0f" % [e.kind, float(e.z)])
				var vv := []
				for vd in tr.voids:
					if absf(float(vd.d0) - z) < 14.0:
						vv.append("%s %.0f-%.0f" % [vd.kind, float(vd.d0), float(vd.d1)])
				print("  lv%d seed%d %s at z=%.1f x=%.2f bounds=%s rails=%s near=%s voids=%s" % [lv, sd, fail, z, x, str(tr.bounds(z)), str(tr.rails_at(z)), str(near), str(vv)])
			z = last_cp
			var b2 := tr.bounds(z)
			x = (b2.x + b2.y) * 0.5
			target = x
			y = 0.0
			vy = 0.0
			grounded = true
			doomed = false
			t += 1.5
	return crashes
