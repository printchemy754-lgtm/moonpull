class_name LevelGen
extends RefCounted
## Rules of the tide + procedural level generation.
## Every level is deterministic (seeded by its number) and was checked by a
## simulated player (see tools/sim.py) to be passable.

const RIVER_W := 8.0
const FLOOR_Y := -0.3
const WATER_MIN := 0.4
const WATER_MAX := 5.6
const WATER_REST := 1.2
const DRAFT := 0.3            # hull depth below the waterline
const BOAT_TOP := 1.5         # mast-top height above the waterline
const BOAT_HALF_LEN := 0.9
const HIT_GRACE := 0.15       # invisible forgiveness in collisions
const NONE_LOW := -99.0
const NONE_HIGH := 99.0
const PICK_OFFSET := 0.6      # pickups float this much above the waterline
const PICK_RANGE := 0.95      # vertical tolerance for pearls / rings / power-ups
const BOOST_MULT := 1.45
const BOOST_TIME := 2.6
const SLOW_MULT := 0.62
const SLOW_TIME := 3.0
const MAGNET_TIME := 6.0

const OBSTACLES := ["reef", "bridge", "gate", "drawbridge", "breather"]
const PICKUPS := ["boost", "slow", "shield", "magnet"]

## Shown the first time a new thing appears.
const INTROS := {
	"gate": ["GATE", "Rocks below, bridge above. Find the gap!"],
	"drawbridge": ["DRAWBRIDGE", "It moves! Stay low, or time it."],
	"breather": ["BREATHING REEF", "It rises and sinks. Stay high!"],
	"boost": ["SPEED RING", "Faster boat, double pearls!"],
	"slow": ["MOON RING", "Slows time for a moment."],
	"shield": ["SHIELD", "Survive one crash."],
	"magnet": ["MAGNET", "Pulls in every pearl nearby."],
}


static func speed_for(level: int) -> float:
	return minf(7.0 + (level - 1) * 0.3, 12.5)


static func rise_for(level: int) -> float:
	return 2.6 + 0.8 * minf((level - 1) / 12.0, 1.0)


static func fall_for(level: int) -> float:
	return 2.2 + 0.6 * minf((level - 1) / 12.0, 1.0)


static func is_obstacle(kind: String) -> bool:
	return kind in OBSTACLES


static func wave(e: Dictionary, t: float) -> float:
	return 0.5 + 0.5 * sin(TAU * t / float(e.period) + float(e.phase))


static func h_at(e: Dictionary, t: float) -> float:
	if e.kind == "breather":
		return float(e.h) + float(e.amp) * wave(e, t)
	return e.h


static func b_at(e: Dictionary, t: float) -> float:
	if e.kind == "drawbridge":
		return float(e.b) - float(e.amp) * wave(e, t)
	return e.b


## Water levels that pass this obstacle at time t: x = lowest, y = highest.
static func safe_range(e: Dictionary, t: float) -> Vector2:
	var lo := WATER_MIN
	var hi := WATER_MAX
	var h := h_at(e, t)
	var b := b_at(e, t)
	if h > NONE_LOW:
		lo = h + DRAFT
	if b < NONE_HIGH:
		hi = b - BOAT_TOP
	return Vector2(lo, hi)


# ------------------------------------------------------------------ generation

static func generate(level: int, seed_override := -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 1234 if seed_override < 0 else seed_override
	var speed := speed_for(level)
	var rise := rise_for(level)
	var fall := fall_for(level)
	var reaction := maxf(0.95 - (level - 1) * 0.025, 0.5)
	var window := maxf(1.8 - (level - 1) * 0.06, 0.85)
	var weights := _patterns_for(level)
	var segments := mini(5 + level, 18)

	var items: Array[Dictionary] = []
	var pearls: Array[Vector3] = []
	var z := 34.0
	var before: Array[float] = [WATER_REST]   # water levels the player may be at
	var boost_end := -1.0
	var queue: Array[String] = []
	if level == 1:
		queue = ["reef", "bridge", "reef"]
	elif level == 3:
		queue = ["boost"]

	for s in segments:
		var pat: String = queue.pop_front() if not queue.is_empty() else _pick(weights, rng)
		for spec in _make_pattern(pat, window, rng):
			var nat: float = spec.nat
			var move := 0.0
			for lv in before:
				var d := nat - lv
				move = maxf(move, d / rise if d > 0.0 else -d / fall)
			var eff := speed * BOOST_MULT if z < boost_end else speed
			var tight: bool = spec.get("tight", false)
			var extra := rng.randf_range(0.0, eff * (0.15 if tight else 0.45))
			var gap := eff * (reaction + move * 1.3) + 3.2 + extra
			var doubled := z < boost_end
			_pearl_trail(pearls, z, z + gap, before[0], nat, rng, doubled)
			z += gap
			spec.z = z
			items.append(spec)
			if spec.has("bonus_y"):
				pearls.append(Vector3(0.0, spec.bonus_y, z))
			if spec.kind == "boost":
				boost_end = z + speed * BOOST_MULT * BOOST_TIME
			if is_obstacle(spec.kind):
				before = [nat]
			else:
				before.append(nat)

	var finish := z + speed * 3.0 + 10.0
	return {
		"items": items, "pearls": pearls, "finish": finish,
		"speed": speed, "rise": rise, "fall": fall,
	}


static func _patterns_for(level: int) -> Dictionary:
	var p := {"reef": 3.0, "bridge": 3.0}
	if level >= 2:
		p["gate"] = 2.0
	if level >= 3:
		p["stairs_up"] = 1.2
		p["stairs_down"] = 1.2
		p["boost"] = 1.0
	if level >= 4:
		p["drawbridge"] = 1.4
		p["zigzag"] = 1.2
	if level >= 5:
		p["breather"] = 1.4
		p["slow_gate"] = 0.8
	if level >= 6:
		p["shield"] = 0.5
		p["magnet"] = 0.6
	return p


static func _pick(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "reef"


static func _item(kind: String) -> Dictionary:
	return {
		"kind": kind, "z": 0.0, "depth": 1.4, "h": NONE_LOW, "b": NONE_HIGH,
		"amp": 0.0, "period": 1.0, "phase": 0.0, "y": 0.0, "nat": WATER_REST,
		"passed": false, "min_clear": NONE_HIGH, "taken": false,
	}


static func _reef(h: float) -> Dictionary:
	var e := _item("reef")
	e.h = h
	e.nat = minf(h + DRAFT + 0.45, WATER_MAX - 0.1)
	return e


static func _bridge(b: float) -> Dictionary:
	var e := _item("bridge")
	e.b = b
	e.nat = maxf(b - BOAT_TOP - 0.45, WATER_MIN + 0.1)
	return e


static func _gate(center: float, window: float) -> Dictionary:
	var e := _item("gate")
	e.h = center - window * 0.5 - DRAFT
	e.b = center + window * 0.5 + BOAT_TOP
	e.nat = center
	return e


static func _pickup(kind: String, y: float) -> Dictionary:
	var e := _item(kind)
	e.y = y
	e.depth = 1.0
	e.nat = clampf(y - PICK_OFFSET, WATER_MIN + 0.1, WATER_MAX - 0.1)
	return e


static func _make_pattern(pat: String, window: float, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	match pat:
		"reef":
			out.append(_reef(rng.randf_range(0.7, 3.4)))
		"bridge":
			out.append(_bridge(rng.randf_range(2.7, 6.3)))
		"gate":
			out.append(_gate(rng.randf_range(1.6, 4.3), window))
		"stairs_up":
			var h0 := rng.randf_range(0.6, 1.1)
			var step := rng.randf_range(0.75, 0.95)
			for i in 3:
				var r := _reef(minf(h0 + step * i, 3.5))
				r["tight"] = i > 0
				out.append(r)
		"stairs_down":
			var b0 := rng.randf_range(5.8, 6.4)
			var step2 := rng.randf_range(0.8, 0.95)
			for i in 3:
				var br := _bridge(maxf(b0 - step2 * i, 2.6))
				br["tight"] = i > 0
				out.append(br)
		"zigzag":
			out.append(_reef(rng.randf_range(2.4, 3.2)))
			var mid := _bridge(rng.randf_range(3.0, 3.8))
			mid["tight"] = true
			out.append(mid)
			var last := _reef(rng.randf_range(2.2, 3.0))
			last["tight"] = true
			out.append(last)
		"drawbridge":
			var d := _item("drawbridge")
			d.b = rng.randf_range(5.8, 6.6)
			d.amp = d.b - rng.randf_range(2.5, 2.9)
			d.period = rng.randf_range(2.4, 3.4)
			d.phase = rng.randf_range(0.0, TAU)
			d.depth = 1.6
			d.nat = maxf(d.b - d.amp - BOAT_TOP - 0.45, WATER_MIN + 0.1)
			d["bonus_y"] = d.b - BOAT_TOP - 0.7 + PICK_OFFSET   # high pearl: only when the bridge is up
			out.append(d)
		"breather":
			var br2 := _item("breather")
			br2.h = rng.randf_range(0.2, 0.6)
			br2.amp = rng.randf_range(1.8, 2.8)
			br2.period = rng.randf_range(2.2, 3.2)
			br2.phase = rng.randf_range(0.0, TAU)
			br2.nat = minf(br2.h + br2.amp + DRAFT + 0.45, WATER_MAX - 0.1)
			br2["bonus_y"] = br2.h + DRAFT + 0.35 + PICK_OFFSET  # low pearl: only when the reef is down
			out.append(br2)
		"boost":
			out.append(_pickup("boost", rng.randf_range(1.8, 4.4)))
		"slow_gate":
			out.append(_pickup("slow", rng.randf_range(1.6, 4.0)))
			out.append(_gate(rng.randf_range(1.6, 4.3), window * 0.85))
		"shield":
			out.append(_pickup("shield", rng.randf_range(1.8, 4.4)))
		"magnet":
			out.append(_pickup("magnet", rng.randf_range(1.8, 4.4)))
	return out


static func _pearl_trail(pearls: Array[Vector3], z0: float, z1: float, a: float, b: float,
		rng: RandomNumberGenerator, doubled: bool) -> void:
	var length := z1 - z0
	if length < 9.0 or (not doubled and rng.randf() > 0.8):
		return
	var spacing := 1.6 if doubled else 2.2
	var count := clampi(int((length - 6.0) / spacing), 2, 9 if doubled else 6)
	var start := z0 + (length - spacing * (count - 1)) * 0.5
	for i in count:
		var u := float(i) / maxf(count - 1, 1)
		var y := lerpf(a, b, smoothstep(0.15, 0.85, u)) + PICK_OFFSET
		y = clampf(y, WATER_MIN + PICK_OFFSET, WATER_MAX + PICK_OFFSET - 0.1)
		pearls.append(Vector3(0.0, y, start + spacing * i))


# ------------------------------------------------------------------ AI pilot (rivals + autotest)

## Water level an AI captain at `z` wants right now (ignores pickups).
static func pilot_target(items: Array, z: float, run_t: float, speed: float) -> float:
	for e in items:
		if not is_obstacle(e.kind) or e.get("smashed", false):
			continue
		if float(e.z) + float(e.depth) * 0.5 < z - BOAT_HALF_LEN:
			continue
		var eta := maxf(0.0, (float(e.z) - z) / maxf(speed, 0.1))
		var lo := -INF
		var hi := INF
		for k in range(-3, 4):
			var r := safe_range(e, run_t + eta + k * 0.1)
			lo = maxf(lo, r.x + 0.12)
			hi = minf(hi, r.y - 0.12)
		if hi < lo:
			if e.kind == "drawbridge":
				lo = WATER_MIN
				hi = float(e.b) - float(e.amp) - BOAT_TOP - 0.12
			else:
				lo = float(e.h) + float(e.amp) + DRAFT + 0.12
				hi = WATER_MAX
		if e.h <= NONE_LOW:
			return maxf(WATER_MIN, hi - 0.35)
		return (lo + hi) * 0.5 if hi < WATER_MAX else minf(lo + 0.35, WATER_MAX)
	return WATER_REST


## Is something at (z, water) hitting an obstacle right now?
static func hits(items: Array, z: float, water: float, run_t: float) -> bool:
	for e in items:
		if not is_obstacle(e.kind) or e.get("smashed", false):
			continue
		var z0 := float(e.z) - float(e.depth) * 0.5
		var z1 := float(e.z) + float(e.depth) * 0.5
		if z1 < z - BOAT_HALF_LEN:
			continue
		if z0 > z + BOAT_HALF_LEN:
			return false
		var h := h_at(e, run_t)
		var b := b_at(e, run_t)
		if h > NONE_LOW and water - DRAFT - h + HIT_GRACE < 0.0:
			return true
		if b < NONE_HIGH and b - BOAT_TOP - water + HIT_GRACE < 0.0:
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
