class_name LevelGen
extends RefCounted
## Rules + procedural levels. The boat sails forward by itself; you steer it
## left / right with your finger and slip through the gaps in the barriers.
## Every level is deterministic (seeded by its number) and is checked by
## simulated players (tools/sim.gd, tools/sim_kid.gd).

const RIVER_W := 8.0
const FLOOR_Y := -0.3
const WATER_MIN := 0.4
const WATER_MAX := 5.6
const WATER_REST := 1.2        # the river level (fixed now)
const DRAFT := 0.3
const BOAT_TOP := 1.5
const BOAT_HALF_LEN := 0.9
const BOAT_HALF_W := 0.5       # half the boat's width
const X_MAX := 3.4             # how far the boat can steer from the centre
const HIT_GRACE := 0.12        # invisible forgiveness at block edges
const WALL_H := 2.6            # barriers reach this high above the water
const PICK_OFFSET := 0.6
const PICK_RANGE := 0.95       # sideways tolerance for coins / power-ups
const BOOST_MULT := 1.45
const BOOST_TIME := 2.6
const SLOW_MULT := 0.62
const SLOW_TIME := 3.0
const MAGNET_TIME := 6.0
const STEER_V := 5.0           # sideways speed used to space obstacles fairly
const JUMP_TIME := 1.5
const JUMP_APEX := 3.6         # height of a ramp jump above the water
const EDGE := 20.0             # "outside the river"

const OBSTACLES := ["wall", "gate2", "block", "mines", "slider", "sweeper"]
const PICKUPS := ["boost", "slow", "shield", "magnet"]
const CURRENTS: Array = []

## New things arrive regularly so the game keeps surprising you.
const UNLOCKS := {2: "block", 3: "ramp", 4: "gate2", 5: "mines", 7: "slider", 10: "sweeper"}

## Shown the first time a new thing appears.
const INTROS := {
	"block": ["CARGO BLOCK", "Steer around it - left or right!"],
	"gate2": ["TWO DOORS", "Pick any open door!"],
	"mines": ["PLASMA MINES", "Weave between the glowing orbs!"],
	"boost": ["SPEED RING", "Faster boat, double coins!"],
	"slow": ["MOON RING", "Slows time for a moment."],
	"shield": ["SHIELD", "Survive one crash."],
	"magnet": ["MAGNET", "Pulls in every coin nearby."],
	"ramp": ["JUMP RAMP", "Fly over the wall and grab the coins in the air!"],
	"slider": ["MOVING DOOR", "The door slides. Follow it!"],
	"sweeper": ["SWEEPER", "A block slides across. Dodge it!"],
}


## "normal", "rush" (coin rush bonus) or "boss" (end of every world).
static func special_for(level: int) -> String:
	if level >= 4 and level % 4 == 0:
		return "boss"
	if level >= 6 and level % 4 == 2:
		return "rush"
	return "normal"


## Gentle start (kids and first-time players), then a steady climb.
static func speed_for(level: int) -> float:
	return minf(6.2 + (level - 1) * 0.32, 13.0)


## Kept for compatibility (the old tide controls).
static func rise_for(_level: int) -> float:
	return 2.6


static func fall_for(_level: int) -> float:
	return 2.2


## Width of the doors in barriers: wide at first, tighter later.
static func door_for(level: int) -> float:
	return clampf(4.2 - (level - 1) * 0.13, 1.75, 4.2)


static func is_obstacle(kind: String) -> bool:
	return kind in OBSTACLES


static func is_current(kind: String) -> bool:
	return kind in CURRENTS


static func wave(e: Dictionary, t: float) -> float:
	return sin(TAU * t / float(e.period) + float(e.phase))


## Blocked x-intervals of an obstacle at time t (x = from, y = to).
static func blocks_at(e: Dictionary, t: float) -> Array:
	match String(e.kind):
		"slider":
			var g := float(e.gx) + float(e.amp) * wave(e, t)
			var hw := float(e.gw) * 0.5
			return [Vector2(-EDGE, g - hw), Vector2(g + hw, EDGE)]
		"sweeper":
			var c := float(e.amp) * wave(e, t)
			var hb := float(e.hw)
			return [Vector2(c - hb, c + hb)]
	return e.blocks


## Room between the boat at x and the nearest block (negative = touching).
static func clearance(e: Dictionary, t: float, x: float) -> float:
	var best := EDGE
	for b in blocks_at(e, t):
		var v: Vector2 = b
		best = minf(best, maxf(v.x - (x + BOAT_HALF_W), (x - BOAT_HALF_W) - v.y))
	return best


## Open stretches of river (where the boat's centre may be) at time t.
static func free_ranges(e: Dictionary, t: float) -> Array:
	var bl: Array = blocks_at(e, t).duplicate()
	bl.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	var out := []
	var cur := -X_MAX
	for b in bl:
		var v: Vector2 = b
		var hi := v.x - BOAT_HALF_W
		if hi > cur:
			out.append(Vector2(cur, minf(hi, X_MAX)))
		cur = maxf(cur, v.y + BOAT_HALF_W)
	if cur < X_MAX:
		out.append(Vector2(cur, X_MAX))
	return out.filter(func(r: Vector2): return r.y - r.x > 0.02)


## Best x to steer to for obstacle e at time t, starting from x.
static func safe_x(e: Dictionary, t: float, x: float) -> float:
	var best := x
	var dist := INF
	for r in free_ranges(e, t):
		var v: Vector2 = r
		var margin := minf(0.35, (v.y - v.x) * 0.5)
		var tx := clampf(x, v.x + margin, v.y - margin)
		var d := absf(tx - x)
		if d < dist:
			dist = d
			best = tx
	return best


## Height of a ramp jump above the water, u = 0..1 through the flight.
static func jump_height(u: float, _water := 0.0) -> float:
	return JUMP_APEX * sin(PI * clampf(u, 0.0, 1.0))


# ------------------------------------------------------------------ generation

const ENDLESS_SEGMENTS := 400


static func endless_level(segment: int) -> int:
	return clampi(2 + int(segment * 0.35), 2, 30)


static func generate_endless(seed_value: int) -> Dictionary:
	return generate(2, seed_value, true)


static func ramp_level(data: Dictionary, z: float) -> int:
	var lv := 2
	for r in data.get("ramp", []):
		if float(r[0]) > z:
			break
		lv = int(r[1])
	return lv


static func _patterns_for(level: int) -> Dictionary:
	var p := {"wall": 3.0}
	if level >= 2:
		p["block"] = 2.0
		p["zig"] = 1.0
	if level >= 3:
		p["ramp"] = 1.0
		p["boost"] = 0.8
	if level >= 4:
		p["gate2"] = 1.6
	if level >= 5:
		p["mines"] = 1.6
		p["slow_wall"] = 0.5
	if level >= 6:
		p["shield"] = 0.5
		p["magnet"] = 0.6
	if level >= 7:
		p["slider"] = 1.5
	if level >= 10:
		p["sweeper"] = 1.5
		p["zig"] = 1.6
	return p


static func generate(level: int, seed_override := -1, endless := false) -> Dictionary:
	var special := "normal" if endless else special_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 1234 if seed_override < 0 else seed_override
	var speed := speed_for(level)
	var reaction := maxf(1.2 - (level - 1) * 0.04, 0.5)
	var door := door_for(level)
	var weights := _patterns_for(level)
	var segments := mini(6 + level, 18) if not endless else ENDLESS_SEGMENTS
	if special == "rush":
		weights = {"wall": 2.0, "block": 2.0, "boost": 1.6, "magnet": 1.0, "ramp": 1.0}
		segments = 12
	elif special == "boss":
		segments = mini(segments + (1 if level <= 4 else 3), 21)
	var ramp: Array = []
	var items: Array[Dictionary] = []
	var pearls: Array[Vector3] = []
	var z := 34.0
	var before: Array[float] = [0.0]   # where the boat may be
	var boost_end := -1.0
	var land_extra := 0.0
	var queue: Array[String] = []
	if level == 1:
		queue = ["wall_l", "wall_r", "wall_l"]
	elif level == 3:
		queue = ["wall", "ramp", "boost", "ramp"]
	elif UNLOCKS.has(level):
		var fresh: String = UNLOCKS[level]
		queue = ["wall", fresh, "wall", fresh]

	for s in segments:
		if endless:
			var lv := endless_level(s)
			if ramp.is_empty() or int(ramp[-1][1]) != lv:
				ramp.append([z, lv])
				speed = speed_for(lv)
				reaction = maxf(1.2 - (lv - 1) * 0.04, 0.5)
				door = door_for(lv)
				weights = _patterns_for(lv)
		var pat: String = queue.pop_front() if not queue.is_empty() else _pick(weights, rng)
		for spec in _make_pattern(pat, door, rng, before):
			var eff := speed * BOOST_MULT if z < boost_end else speed
			var flight := eff * JUMP_TIME
			var move := 0.0
			var tgt := _target_of(spec, before)
			for x in before:
				move = maxf(move, absf(_nearest_free(spec, x) - x) / STEER_V)
			var tight: bool = spec.get("tight", false)
			var extra := rng.randf_range(0.0, eff * (0.15 if tight else 0.4))
			var gap := eff * (reaction + move * 1.2) + 4.0 + extra
			if spec.kind == "ramp" or PICKUPS.has(String(spec.kind)):
				gap = eff * 0.6 + 6.0 + extra * 0.3
			if spec.get("air", false):
				gap = flight * 0.5
			elif land_extra > 0.0:
				gap += land_extra
				land_extra = 0.0
			var doubled := z < boost_end or special == "rush"
			if spec.get("air", false):
				for k in 7:
					var u := (k + 0.5) / 7.0
					pearls.append(Vector3(before[0], WATER_REST + jump_height(u) + PICK_OFFSET, z + flight * u))
				land_extra = flight * 0.5 + 2.0
			else:
				_pearl_trail(pearls, z, z + gap, before[0], tgt, rng, doubled)
			z += gap
			spec.z = z
			items.append(spec)
			if spec.kind == "boost":
				boost_end = z + speed * BOOST_MULT * BOOST_TIME
			if is_obstacle(spec.kind) and not spec.get("air", false):
				before = _after(spec)
			elif PICKUPS.has(String(spec.kind)):
				before = [float(spec.x)]

	var finish := z + speed * 3.0 + 10.0
	if endless:
		return {
			"items": items, "pearls": pearls, "finish": finish, "endless": true, "ramp": ramp,
			"speed": speed_for(2), "rise": 2.6, "fall": 2.2,
		}
	return {
		"items": items, "pearls": pearls, "finish": finish, "special": special,
		"speed": speed, "rise": 2.6, "fall": 2.2,
	}


## Where a player can be right after passing spec.
static func _after(spec: Dictionary) -> Array[float]:
	var out: Array[float] = []
	match String(spec.kind):
		"slider":
			out = [float(spec.gx) - float(spec.amp), float(spec.gx), float(spec.gx) + float(spec.amp)]
		"sweeper":
			out = [-X_MAX, 0.0, X_MAX]
		_:
			for r in free_ranges(spec, 0.0):
				var v: Vector2 = r
				out.append((v.x + v.y) * 0.5)
	if out.is_empty():
		out = [0.0]
	return out


## Sideways spot that passes spec, closest to x (moving obstacles: worst case).
static func _nearest_free(spec: Dictionary, x: float) -> float:
	match String(spec.kind):
		"slider":
			return float(spec.gx)
		"sweeper":
			return -X_MAX if x < 0.0 else X_MAX
	if not is_obstacle(spec.kind):
		return float(spec.get("x", x))
	return safe_x(spec, 0.0, x)


## Point the coin trail leads to.
static func _target_of(spec: Dictionary, before: Array[float]) -> float:
	if not is_obstacle(spec.kind):
		return float(spec.get("x", before[0]))
	if spec.kind == "slider":
		return float(spec.gx)
	return _nearest_free(spec, before[0])


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "wall"


static func _item(kind: String) -> Dictionary:
	return {
		"kind": kind, "z": 0.0, "depth": 1.2, "blocks": [], "amp": 0.0, "period": 1.0, "phase": 0.0,
		"x": 0.0, "y": WATER_REST + PICK_OFFSET, "gx": 0.0, "gw": 0.0, "hw": 0.0,
		"passed": false, "min_clear": EDGE, "taken": false,
	}


## A barrier across the river with doors at the given centres.
static func _wall(doors: Array, width: float) -> Dictionary:
	var e := _item("wall" if doors.size() == 1 else "gate2")
	var cur := -EDGE
	var ds := doors.duplicate()
	ds.sort()
	for d in ds:
		var c := float(d)
		e.blocks.append(Vector2(cur, c - width * 0.5))
		cur = c + width * 0.5
	e.blocks.append(Vector2(cur, EDGE))
	e.gx = float(ds[0])
	e.gw = width
	return e


static func _door_x(width: float, rng: RandomNumberGenerator, avoid := 99.0) -> float:
	var lim := X_MAX + BOAT_HALF_W - width * 0.5 - 0.1
	for k in 6:
		var x := rng.randf_range(-lim, lim)
		if absf(x - avoid) > 1.8:
			return x
	return rng.randf_range(-lim, lim)


static func _make_pattern(pat: String, door: float, rng: RandomNumberGenerator, before: Array[float]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var lim := X_MAX + BOAT_HALF_W - door * 0.5 - 0.1
	match pat:
		"wall":
			out.append(_wall([_door_x(door, rng, before[0])], door))
		"wall_l":
			out.append(_wall([-lim * 0.7], door))
		"wall_r":
			out.append(_wall([lim * 0.7], door))
		"zig":
			var side := 1.0 if rng.randf() < 0.5 else -1.0
			for k in 3:
				var w := _wall([side * lim * 0.85], door * 1.05)
				w["tight"] = k > 0
				out.append(w)
				side = -side
		"gate2":
			var d2 := door * 0.85
			var l2 := X_MAX + BOAT_HALF_W - d2 * 0.5 - 0.1
			out.append(_wall([-l2 * rng.randf_range(0.7, 1.0), l2 * rng.randf_range(0.7, 1.0)], d2))
		"block":
			var bw := rng.randf_range(2.6, 3.8)
			var bc := rng.randf_range(-1.8, 1.8)
			var b := _item("block")
			b.blocks = [Vector2(bc - bw * 0.5, bc + bw * 0.5)]
			b.depth = 1.6
			out.append(b)
		"mines":
			var m := _item("mines")
			var n := rng.randi_range(2, 3)
			var spacing := (RIVER_W - 1.0) / n
			var shift := rng.randf_range(-0.6, 0.6)
			for k in n:
				var mx := -RIVER_W * 0.5 + 0.5 + spacing * (k + 0.5) + shift
				m.blocks.append(Vector2(mx - 0.55, mx + 0.55))
			m.depth = 1.0
			out.append(m)
		"slider":
			var sl := _item("slider")
			sl.gw = door * 1.1
			sl.amp = rng.randf_range(1.2, 1.9)
			sl.gx = rng.randf_range(-0.6, 0.6)
			sl.period = rng.randf_range(3.2, 4.2)
			sl.phase = rng.randf_range(0.0, TAU)
			out.append(sl)
		"sweeper":
			var sw := _item("sweeper")
			sw.hw = 1.3
			sw.amp = 2.4
			sw.period = rng.randf_range(2.8, 3.8)
			sw.phase = rng.randf_range(0.0, TAU)
			sw.depth = 1.6
			out.append(sw)
		"ramp":
			var rp := _item("ramp")
			rp.depth = 2.0
			out.append(rp)
			var wall := _item("wall")
			wall.blocks = [Vector2(-EDGE, EDGE)]
			wall["air"] = true
			out.append(wall)
		"boost":
			var p1 := _item("boost")
			p1.x = rng.randf_range(-2.4, 2.4)
			out.append(p1)
		"slow_wall":
			var p2 := _item("slow")
			p2.x = rng.randf_range(-2.0, 2.0)
			out.append(p2)
			out.append(_wall([_door_x(door * 0.85, rng)], door * 0.85))
		"shield", "magnet":
			var p3 := _item(pat)
			p3.x = rng.randf_range(-2.4, 2.4)
			out.append(p3)
	for e in out:
		if PICKUPS.has(String(e.kind)):
			e.depth = 1.0
	return out


static func _pearl_trail(pearls: Array[Vector3], z0: float, z1: float, a: float, b: float,
		rng: RandomNumberGenerator, doubled: bool) -> void:
	var length := z1 - z0
	if length < 9.0 or (not doubled and rng.randf() > 0.85):
		return
	var spacing := 1.6 if doubled else 2.0
	var count := clampi(int((length - 6.0) / spacing), 2, 9 if doubled else 7)
	var start := z0 + (length - spacing * (count - 1)) * 0.5
	for i in count:
		var u := float(i) / maxf(count - 1, 1)
		var x := lerpf(a, b, smoothstep(0.1, 0.8, u))
		pearls.append(Vector3(clampf(x, -X_MAX, X_MAX), WATER_REST + PICK_OFFSET, start + spacing * i))


# ------------------------------------------------------------------ AI pilot (rivals + autotest)

## Sideways position an AI captain at (z, x) wants right now.
static func pilot_target(items: Array, z: float, run_t: float, speed: float, x := 0.0) -> float:
	for e in items:
		if not is_obstacle(e.kind) or e.get("smashed", false) or e.get("air", false):
			continue
		if float(e.z) + float(e.depth) * 0.5 < z - BOAT_HALF_LEN:
			continue
		var eta := maxf(0.0, (float(e.z) - z) / maxf(speed, 0.1))
		return pilot_x(e, run_t + eta, x)
	return x


## Where to be to pass e around time at (moving ones: stay safe the whole pass).
static func pilot_x(e: Dictionary, at: float, x: float) -> float:
	var target := safe_x(e, at, x)
	if e.kind == "sweeper" or e.kind == "slider":
		var ok := true
		for k in [-2, -1, 1, 2]:
			if clearance(e, at + k * 0.12, target) < 0.05:
				ok = false
		if not ok:
			# pick the spot that stays clear longest around the arrival
			var best := target
			var best_c := -INF
			for i in 15:
				var cx := lerpf(-X_MAX, X_MAX, i / 14.0)
				var c := INF
				for k in range(-3, 4):
					c = minf(c, clearance(e, at + k * 0.1, cx))
				c -= absf(cx - x) * 0.05
				if c > best_c:
					best_c = c
					best = cx
			target = best
	return target


static func hits(items: Array, z: float, x: float, run_t: float) -> bool:
	for e in items:
		if not is_obstacle(e.kind) or e.get("smashed", false) or e.get("air", false):
			continue
		var z0 := float(e.z) - float(e.depth) * 0.5
		var z1 := float(e.z) + float(e.depth) * 0.5
		if z1 < z - BOAT_HALF_LEN:
			continue
		if z0 > z + BOAT_HALF_LEN:
			return false
		if clearance(e, run_t, x) + HIT_GRACE < 0.0:
			return true
	return false


## Last safe z before the obstacle at/after z (respawn point).
static func respawn_z(items: Array, z: float, speed: float) -> float:
	var back := z - speed * 1.2
	for e in items:
		if not is_obstacle(e.kind):
			continue
		var z1 := float(e.z) + float(e.depth) * 0.5
		if z1 + BOAT_HALF_LEN + 0.4 < z - BOAT_HALF_LEN:
			back = maxf(back, z1 + BOAT_HALF_LEN + 0.4)
	return maxf(back, 0.0)
