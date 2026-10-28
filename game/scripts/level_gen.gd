class_name LevelGen
extends RefCounted
## Moonpull — roll the moon-ball along a neon track floating in space.
## The ball rolls forward by itself; you slide your finger to steer.
## Fall off the edge (narrow bridges, holes, split lanes, gaps) or hit a
## barrier and you respawn at the last checkpoint.
## Levels are deterministic (seeded by their number) and are checked by
## simulated players (tools/sim_kid.gd).

const R := 0.5                 # ball radius
const FLOOR_Y := -0.3          # (scenery helper)
const RIVER_W := 7.0
const HALF_W := 3.5            # normal floor half width
const S_MAX := 6.0             # how far you can steer (beyond the edge = fall)
const BOAT_HALF_LEN := 0.5     # (kept name) half the ball's length along the track
const BOAT_HALF_W := 0.45      # half the ball's width for collisions
const HIT_GRACE := 0.1
const WALL_H := 2.4
const GRAVITY := 22.0
const JUMP_V := 8.0            # ramp launch speed (up)
const DRIFT := 0.035           # how much curves push the ball outward
const PICK_OFFSET := 0.6
const PICK_RANGE := 0.9
const BOOST_MULT := 1.45
const BOOST_TIME := 2.6
const SLOW_MULT := 0.62
const SLOW_TIME := 3.0
const MAGNET_TIME := 6.0
const STEER_V := 5.0           # sideways speed used to space obstacles fairly
const JUMP_TIME := 0.73        # = 2 * JUMP_V / GRAVITY (air time of a ramp jump)
const EDGE := 30.0

const OBSTACLES := ["wall", "gate2", "block", "mines", "slider", "sweeper", "hammer", "tetro"]
const VOIDS := ["void", "pvoid"]
const PICKUPS := ["boost", "slow", "shield", "magnet", "box", "chest"]
const TWIN_GAP := 0.8          # half width of the hole between the twin lanes
## Worlds you visit through a portal (each one looks completely different).
const ZONES := ["SUNSET BAY", "DEEP GALAXY", "CANDY LAND", "FROST PEAK", "LAVA CORE", "PIXEL WORLD", "WILD DESERT"]

## Every level has its own character (its "course").
const COURSES := {
	"CLASSIC RUN": {},
	"HAMMER ALLEY": {"hammer": 4.0, "wall": 1.5},
	"JUMP PARK": {"jump": 4.0, "holes": 2.0, "speedpad": 2.0},
	"SNAKE BRIDGES": {"narrow": 3.0, "zigzag": 3.0, "split": 2.0},
	"TWIN TROUBLE": {"twin": 5.0},
	"PORTAL STORM": {"portal": 3.0, "box": 2.0},
	"ROLLER COASTER": {"drop": 3.0, "run": 3.0, "speedpad": 2.0},
	"MINE FIELD": {"mines": 3.0, "block": 2.0, "sweeper": 2.0},
	"BLOCK DROP": {"tetro": 5.0, "box": 1.5},
	"THREE LANES": {"lanes3": 5.0, "chest": 2.0},
	"SKY OBBY": {"platform": 3.0, "jump": 2.5, "narrow": 2.0},
}
const COURSE_ORDER := ["CLASSIC RUN", "JUMP PARK", "BLOCK DROP", "SNAKE BRIDGES", "HAMMER ALLEY", "PORTAL STORM",
	"THREE LANES", "TWIN TROUBLE", "ROLLER COASTER", "SKY OBBY", "MINE FIELD"]
const CURRENTS: Array = []

## The track currently being played (rivals and the autopilot read it).
static var track: Track

## New things arrive regularly so the game keeps surprising you.
const UNLOCKS := {2: "holes", 3: "jump", 4: "tetro", 5: "hammer", 6: "zigzag", 7: "twin", 8: "lanes3", 9: "platform", 10: "mines", 11: "block", 12: "slider", 13: "narrow", 14: "sweeper", 15: "gate2"}

## Shown the first time a new thing appears.
const INTROS := {
	"holes": ["HOLES", "Roll around the holes in the floor!"],
	"jump": ["JUMP RAMP", "Fly over the gap - grab coins in the air!"],
	"narrow": ["NARROW BRIDGE", "Stay in the middle!"],
	"block": ["CARGO BLOCK", "Steer around it!"],
	"zigzag": ["SNAKE BRIDGE", "Follow the curves!"],
	"split": ["TWO LANES", "Pick a side!"],
	"gate2": ["TWO DOORS", "Any open door works!"],
	"platform": ["MOVING PLATFORM", "Roll on when it comes to you!"],
	"mines": ["PLASMA MINES", "Weave between the orbs!"],
	"slider": ["MOVING DOOR", "The door slides. Follow it!"],
	"sweeper": ["SWEEPER", "A block slides across. Dodge it!"],
	"hammer": ["GIANT HAMMERS", "Wait for the swing, then roll past!"],
	"twin": ["TWIN BALLS", "Your ball splits in two! Both must get through."],
	"portal": ["PORTAL", "Roll through to jump into another world!"],
	"box": ["MYSTERY BOX", "Grab it for a random power!"],
	"speedpad": ["SPEED PAD", "Zoom!"],
	"tetro": ["FALLING BLOCKS", "Blocks drop from the sky. Find the gap!"],
	"lanes3": ["THREE LANES", "Left, middle or right. Pick one!"],
	"chest": ["SECRET CHEST", "Hidden treasure on the edge!"],
	"boost": ["SPEED RING", "Faster ball, double coins!"],
	"slow": ["MOON RING", "Slows time for a moment."],
	"shield": ["SHIELD", "Survive one crash."],
	"magnet": ["MAGNET", "Pulls in every coin nearby."],
}


## "normal", "rush" (coin rush bonus) or "boss" (end of every world).
static func special_for(level: int) -> String:
	if level >= 4 and level % 4 == 0:
		return "boss"
	if level >= 6 and level % 4 == 2:
		return "rush"
	return "normal"


## The level's course (its character). Levels 1-2 and boss / rush levels are classic.
static func course_for(level: int) -> String:
	if level <= 2 or special_for(level) == "rush":
		return "CLASSIC RUN"
	# only courses whose main elements are already unlocked
	var have := _patterns_for(level)
	var n := COURSE_ORDER.size() - 1      # (CLASSIC RUN is index 0)
	var start := (level - 3) % n
	for k in n:
		var c: String = COURSE_ORDER[1 + (start + k) % n]
		var main_key: String = ""
		var best := 0.0
		for key in COURSES[c]:
			if float(COURSES[c][key]) > best:
				best = float(COURSES[c][key])
				main_key = key
		if main_key == "" or have.has(main_key):
			return c
	return "CLASSIC RUN"


static func speed_for(level: int) -> float:
	return minf(7.0 + (level - 1) * 0.28, 13.0)


static func rise_for(_level: int) -> float:
	return 2.6


static func fall_for(_level: int) -> float:
	return 2.2


static func door_for(level: int) -> float:
	return clampf(3.4 - (level - 1) * 0.09, 1.8, 3.4)


static func is_obstacle(kind: String) -> bool:
	return kind in OBSTACLES


static func is_void(kind: String) -> bool:
	return kind in VOIDS


static func is_current(kind: String) -> bool:
	return kind in CURRENTS


static func wave(e: Dictionary, t: float) -> float:
	return sin(TAU * t / float(e.period) + float(e.phase))


## Blocked s-intervals of an obstacle / void at time t.
static func blocks_at(e: Dictionary, t: float) -> Array:
	match String(e.kind):
		"slider", "pvoid":
			var g := float(e.gx) + float(e.amp) * wave(e, t)
			var hw := float(e.gw) * 0.5
			return [Vector2(-EDGE, g - hw), Vector2(g + hw, EDGE)]
		"sweeper", "hammer":
			var c := float(e.amp) * wave(e, t)
			var hb := float(e.hw)
			return [Vector2(c - hb, c + hb)]
	return e.blocks


static func clearance(e: Dictionary, t: float, x: float) -> float:
	var best := EDGE
	var hw := BOAT_HALF_W if is_obstacle(e.kind) else 0.0
	for b in blocks_at(e, t):
		var v: Vector2 = b
		best = minf(best, maxf(v.x - (x + hw), (x - hw) - v.y))
	return best


static func free_ranges(e: Dictionary, t: float) -> Array:
	var bl: Array = blocks_at(e, t).duplicate()
	bl.sort_custom(func(a: Vector2, b: Vector2): return a.x < b.x)
	var hw := BOAT_HALF_W if is_obstacle(e.kind) else 0.15
	var lim := _bounds_at(float(e.z))
	var out := []
	var cur := lim.x
	for b in bl:
		var v: Vector2 = b
		var hi := v.x - hw
		if hi > cur:
			out.append(Vector2(cur, minf(hi, lim.y)))
		cur = maxf(cur, v.y + hw)
	if cur < lim.y:
		out.append(Vector2(cur, lim.y))
	return out.filter(func(r: Vector2): return r.y - r.x > 0.3)


static func _bounds_at(d: float) -> Vector2:
	if track == null:
		return Vector2(-HALF_W + 0.4, HALF_W - 0.4)
	var b := track.bounds(d)
	return Vector2(b.x + 0.35, b.y - 0.35)


static func safe_x(e: Dictionary, t: float, x: float) -> float:
	var best := x
	var dist := INF
	for r in free_ranges(e, t):
		var v: Vector2 = r
		var margin := minf(0.35, (v.y - v.x) * 0.5)
		var tx := clampf(x, v.x + margin, v.y - margin)
		if v.y - v.x < 3.4:
			tx = (v.x + v.y) * 0.5   # narrow spots: aim for the middle
		var d := absf(tx - x)
		if d < dist:
			dist = d
			best = tx
	return best


static func jump_height(u: float, _w := 0.0) -> float:
	return JUMP_V * JUMP_TIME * 0.25 * 4.0 * u * (1.0 - u)


# ------------------------------------------------------------------ generation

const ENDLESS_SEGMENTS := 300


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
	var p := {"run": 2.0, "wall": 3.0}
	if level >= 2:
		p["holes"] = 1.6
		p["zig"] = 0.8
	if level >= 3:
		p["jump"] = 1.3
		p["boost"] = 0.6
	if level >= 4:
		p["narrow"] = 1.2
		p["drop"] = 0.6
	if level >= 5:
		p["block"] = 1.4
		p["slow_wall"] = 0.4
	if level >= 6:
		p["zigzag"] = 1.2
		p["shield"] = 0.4
		p["magnet"] = 0.5
	if level >= 7:
		p["split"] = 1.2
	if level >= 8:
		p["gate2"] = 1.2
	if level >= 9:
		p["platform"] = 1.0
	if level >= 10:
		p["mines"] = 1.3
	if level >= 12:
		p["slider"] = 1.2
	if level >= 14:
		p["sweeper"] = 1.2
	if level >= 3:
		p["portal"] = 0.5
		p["box"] = 0.6
		p["speedpad"] = 0.6
		p["chest"] = 0.3
	if level >= 4:
		p["tetro"] = 1.0
	if level >= 5:
		p["hammer"] = 1.2
	if level >= 7:
		p["twin"] = 0.8
	if level >= 8:
		p["lanes3"] = 0.9
	return p


static func generate(level: int, seed_override := -1, endless := false) -> Dictionary:
	var special := "normal" if endless else special_for(level)
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 1234 if seed_override < 0 else seed_override
	var g := {
		"level": level, "speed": speed_for(level), "reaction": maxf(1.2 - (level - 1) * 0.04, 0.5),
		"door": door_for(level), "rails": clampf(1.1 - (level - 1) * 0.1, 0.25, 1.0),
		"turn": clampf(0.5 + level * 0.06, 0.5, 1.2),
		"items": [] as Array[Dictionary], "pearls": [] as Array[Vector3], "before": [0.0] as Array[float],
		"rng": rng, "boost_end": -1.0, "special": special,
	}
	var tr := Track.new()
	tr.add(24.0, 0.0, 0.0, HALF_W, true)
	var weights := _patterns_for(level)
	var course := "CLASSIC RUN" if endless else course_for(level)
	_apply_course(weights, course)
	var segments := mini(6 + level, 18) if not endless else ENDLESS_SEGMENTS
	if special == "rush":
		weights = {"run": 2.0, "wall": 1.5, "jump": 1.5, "boost": 1.6, "magnet": 1.0}
		segments = 12
	elif special == "boss":
		segments = mini(segments + (1 if level <= 4 else 3), 21)
	var ramp: Array = []
	var queue: Array[String] = []
	if level == 1:
		queue = ["wall_l", "run", "wall_r", "wall_l"]
	elif UNLOCKS.has(level) and not endless:
		var fresh: String = UNLOCKS[level]
		queue = ["run", fresh, "wall", fresh]
	# portals come in the middle / near the end of a level (2 in PORTAL STORM)
	var portal_at: Array[int] = []
	if level >= 3 and not endless and special != "rush":
		portal_at.append(int(segments * rng.randf_range(0.45, 0.7)))
		if course == "PORTAL STORM":
			portal_at[0] = int(segments * 0.35)
			portal_at.append(int(segments * 0.75))
	if endless:
		for k in range(14, segments, 28):
			portal_at.append(k)
	var recent: Array[String] = []
	var zone := ""
	var since_cp := 0
	var s := 0
	while s < segments:
		if endless:
			var lv := endless_level(s)
			if ramp.is_empty() or int(ramp[-1][1]) != lv:
				ramp.append([tr.length, lv])
				g.speed = speed_for(lv)
				g.reaction = maxf(1.2 - (lv - 1) * 0.04, 0.5)
				g.door = door_for(lv)
				g.rails = clampf(1.1 - (lv - 1) * 0.1, 0.25, 1.0)
				g.turn = clampf(0.5 + lv * 0.06, 0.5, 1.2)
				weights = _patterns_for(lv)
				_apply_course(weights, COURSE_ORDER[(s / 25) % COURSE_ORDER.size()])
		var pat: String
		if s in portal_at and queue.is_empty():
			pat = "portal"
		elif not queue.is_empty():
			pat = queue.pop_front()
		else:
			pat = _pick(_mixed(weights, recent, zone, float(s) / maxf(segments, 1)), rng)
		var n0: int = (g.items as Array).size()
		_pattern(pat, tr, g)
		if pat == "portal":
			zone = String(g.items[-1].zone)
		recent.push_front(pat)
		if recent.size() > 4:
			recent.pop_back()
		s += 1
		if INTROS.has(pat):
			for k in range(n0, (g.items as Array).size()):
				if String(g.items[k].kind) != "checkpoint":
					g.items[k]["intro"] = pat
					break
		since_cp += 1
		if since_cp >= 3:
			since_cp = 0
			_checkpoint(tr, g)
	var finish := tr.length + 6.0
	tr.add(40.0, 0.0, 0.0, HALF_W, true)
	var first_portal := -1.0
	for it in g.items:
		if it.kind == "portal":
			first_portal = float(it.z)
			break
	var out := {
		"items": g.items, "pearls": g.pearls, "finish": finish, "track": tr, "first_portal": first_portal,
		"speed": speed_for(level) if not endless else speed_for(2), "rise": 2.6, "fall": 2.2,
	}
	out["course"] = course
	out["pins"] = finish + 14.0     # bowling pins after the finish line
	if endless:
		out["endless"] = true
		out["ramp"] = ramp
	else:
		out["special"] = special
	return out


const HARD := ["zigzag", "narrow", "split", "lanes3", "twin", "platform", "mines", "slider", "sweeper", "hammer", "tetro", "gate2", "zig", "block"]
## What each portal world is full of.
const ZONE_PATTERNS := {
	"SUNSET BAY": {"jump": 3.0, "speedpad": 3.0, "run": 2.0},
	"DEEP GALAXY": {"platform": 4.0, "mines": 3.0, "holes": 2.0},
	"CANDY LAND": {"zigzag": 3.0, "box": 3.0, "chest": 3.0},
	"FROST PEAK": {"run": 3.0, "narrow": 2.0, "drop": 3.0},
	"LAVA CORE": {"holes": 3.0, "lanes3": 3.0, "split": 3.0},
	"PIXEL WORLD": {"tetro": 5.0, "block": 2.0},
	"WILD DESERT": {"hammer": 4.0, "sweeper": 3.0},
}
## Gameplay twist inside a world.
const ZONE_RULES := {
	"FROST PEAK": ["SLIPPERY ICE!", "Curves push you twice as hard"],
	"WILD DESERT": ["WINDY!", "Gusts push you sideways"],
}


## Mixes the obstacles: never the same thing twice in a row, harder things
## later in the level, and the current portal world's favourites.
static func _mixed(weights: Dictionary, recent: Array[String], zone: String, u: float) -> Dictionary:
	var w := weights.duplicate()
	var zp: Dictionary = ZONE_PATTERNS.get(zone, {})
	for k in w:
		var f := 1.0
		if not recent.is_empty() and recent[0] == k:
			f = 0.0
		elif k in recent:
			f = 0.3
		if k in HARD:
			f *= 0.45 + u * 1.1
		if zp.has(k):
			f *= float(zp[k])
		if k == "wall":
			f *= 0.6
		if k == "portal":
			f = 0.0
		w[k] = float(w[k]) * f
	return w


static func _apply_course(weights: Dictionary, course: String) -> void:
	var boost: Dictionary = COURSES.get(course, {})
	for k in boost:
		if weights.has(k):
			weights[k] = float(weights[k]) * float(boost[k])


static func _checkpoint(tr: Track, g: Dictionary) -> void:
	tr.add(3.0, 0.0, 0.0, HALF_W, true)
	var cp := _item("checkpoint")
	cp.z = tr.length - 1.5
	cp.depth = 1.0
	g.items.append(cp)
	g.before = [0.0] as Array[float]
	tr.add(5.0, 0.0, 0.0, HALF_W, true)


static func _rails(g: Dictionary) -> bool:
	return (g.rng as RandomNumberGenerator).randf() < float(g.rails)


## Approach run before something that needs steering: long enough to move there.
static func _approach(tr: Track, g: Dictionary, target_s: Array, turn_ok := true) -> void:
	var rng: RandomNumberGenerator = g.rng
	var speed: float = g.speed * (BOOST_MULT if tr.length < float(g.boost_end) else 1.0)
	var move := 0.0
	for x in g.before:
		var best := INF
		for t in target_s:
			best = minf(best, absf(float(t) - float(x)))
		move = maxf(move, best / STEER_V)
	var gap: float = speed * (float(g.reaction) + move * 1.2) + 3.0 + rng.randf_range(0.0, speed * 0.3)
	var turn := 0.0
	if turn_ok and rng.randf() < 0.4:
		turn = rng.randf_range(-0.25, 0.25) * float(g.turn)
	var d0 := tr.length
	tr.add(gap, turn, 0.0, HALF_W, _rails(g))
	_coin_line(g, d0 + 2.0, tr.length - 1.0, float(g.before[0]), float(target_s[0]))


static func _coin_line(g: Dictionary, d0: float, d1: float, s0: float, s1: float, h := PICK_OFFSET) -> void:
	var rng: RandomNumberGenerator = g.rng
	var length := d1 - d0
	var doubled: bool = g.special == "rush" or d0 < float(g.boost_end)
	if length < 6.0 or (not doubled and rng.randf() > 0.85):
		return
	var spacing := 1.6 if doubled else 2.0
	var count := clampi(int((length - 2.0) / spacing), 2, 10 if doubled else 7)
	var start := d0 + (length - spacing * (count - 1)) * 0.5
	for i in count:
		var u := float(i) / maxf(count - 1, 1)
		var s := lerpf(s0, s1, smoothstep(0.15, 0.85, u))
		(g.pearls as Array[Vector3]).append(Vector3(s, h, start + spacing * i))


static func _door_x(width: float, rng: RandomNumberGenerator, from := 0.0) -> float:
	var lim := HALF_W - 0.25 - width * 0.5
	var side_s := -signf(from) if absf(from) > 0.4 else (1.0 if rng.randf() < 0.5 else -1.0)
	var min_off := minf(width * 0.5 - BOAT_HALF_W + 0.35, lim)
	return side_s * rng.randf_range(min_off, lim)


static func _place(tr: Track, g: Dictionary, e: Dictionary, after: Array) -> void:
	tr.add(e.depth * 0.5, 0.0, 0.0, HALF_W, _rails(g))
	e.z = tr.length
	tr.add(e.depth * 0.5 + 1.0, 0.0, 0.0, HALF_W, _rails(g))
	g.items.append(e)
	var b: Array[float] = []
	for a in after:
		b.append(float(a))
	g.before = b


static func _pattern(pat: String, tr: Track, g: Dictionary) -> void:
	var rng: RandomNumberGenerator = g.rng
	var door: float = g.door
	var lim := HALF_W - 0.25 - door * 0.5
	match pat:
		"run":
			# a curvy stretch with coins: turns push the ball outward
			var len := rng.randf_range(16.0, 26.0)
			var turn := rng.randf_range(0.35, 1.0) * float(g.turn) * (1.0 if rng.randf() < 0.5 else -1.0)
			var rise := rng.randf_range(-2.5, 1.5)
			var d0 := tr.length
			var s_in := float(g.before[0])
			tr.add(len, turn, rise, HALF_W, _rails(g))
			var inner := clampf(signf(turn) * 1.6, -2.0, 2.0)
			_coin_line(g, d0 + 2.0, tr.length - 2.0, s_in, inner)
			g.before = [inner] as Array[float]
		"wall", "wall_l", "wall_r":
			var dx := _door_x(door, rng, float(g.before[0]))
			if pat == "wall_l":
				dx = lim * 0.8
			elif pat == "wall_r":
				dx = -lim * 0.8
			_approach(tr, g, [dx])
			_place(tr, g, _wall([dx], door), [dx])
			if pat == "wall" and rng.randf() < 0.3:
				var dx2 := _door_x(door, rng, dx)
				_approach(tr, g, [dx2], false)
				_place(tr, g, _wall([dx2], door), [dx2])
		"zig":
			var sd := 1.0 if rng.randf() < 0.5 else -1.0
			for k in 3:
				var zx := sd * lim * 0.85
				_approach(tr, g, [zx], false)
				_place(tr, g, _wall([zx], door * 1.05), [zx])
				sd = -sd
		"gate2":
			var d2 := door * 0.85
			var l2 := HALF_W - 0.25 - d2 * 0.5
			var a := -l2 * rng.randf_range(0.75, 1.0)
			var b := l2 * rng.randf_range(0.75, 1.0)
			_approach(tr, g, [a, b])
			_place(tr, g, _wall([a, b], d2), [a, b])
		"slow_wall":
			var p2 := _item("slow")
			p2.x = clampf(float(g.before[0]), -2.0, 2.0)
			_pickup(tr, g, p2)
			var dx3 := _door_x(door * 0.85, rng, float(g.before[0]))
			_approach(tr, g, [dx3])
			_place(tr, g, _wall([dx3], door * 0.85), [dx3])
		"block":
			var bw := rng.randf_range(2.4, 3.4)
			var bc := clampf(float(g.before[0]) + rng.randf_range(-0.6, 0.6), -1.6, 1.6)
			var e := _item("block")
			e.blocks = [Vector2(bc - bw * 0.5, bc + bw * 0.5)]
			e.depth = 1.6
			var left := (bc + bw * 0.5 + HALF_W) * 0.5
			var right := (bc - bw * 0.5 - HALF_W) * 0.5
			_approach(tr, g, [left, right])
			_place(tr, g, e, [left, right])
		"mines":
			var m := _item("mines")
			var shift := clampf(float(g.before[0]), -0.5, 0.5) + rng.randf_range(-0.3, 0.3)
			for k in [-1, 0, 1]:
				var mx: float = k * 2.6 + shift
				m.blocks.append(Vector2(mx - 0.42, mx + 0.42))
			m.depth = 1.0
			_approach(tr, g, [shift + 1.3, shift - 1.3])
			_place(tr, g, m, [shift + 1.3, shift - 1.3])
		"slider":
			var sl := _item("slider")
			sl.gw = door * 1.15
			sl.amp = rng.randf_range(1.0, 1.6)
			sl.gx = rng.randf_range(-0.4, 0.4)
			sl.period = rng.randf_range(3.2, 4.2)
			sl.phase = rng.randf_range(0.0, TAU)
			_approach(tr, g, [sl.gx])
			_place(tr, g, sl, [sl.gx - sl.amp, sl.gx, sl.gx + sl.amp])
		"sweeper":
			var sw := _item("sweeper")
			sw.hw = 1.2
			sw.amp = 2.2
			sw.period = rng.randf_range(2.8, 3.8)
			sw.phase = rng.randf_range(0.0, TAU)
			sw.depth = 1.6
			_approach(tr, g, [-2.8, 2.8])
			_place(tr, g, sw, [-2.8, 0.0, 2.8])
		"holes":
			# 1-2 holes, the first one right where the ball is
			var d0h := tr.length
			_approach(tr, g, [float(g.before[0]) + 2.0])
			var len := rng.randf_range(12.0, 16.0)
			var hd := tr.length + 2.0
			tr.add(len, 0.0, 0.0, HALF_W, false)
			var hs := clampf(float(g.before[0]), -1.8, 1.8)
			var hw := rng.randf_range(1.2, 1.5)
			_void_hole(g, tr, hd, hd + 4.0, hs - hw, hs + hw)
			var pass_s := hs + hw + 0.9 if hs < 0.0 else hs - hw - 0.9
			_coin_line(g, d0h + 2.0, hd + 4.0, float(g.before[0]), pass_s)
			if int(g.level) >= 6 and rng.randf() < 0.5:
				var hs2 := clampf(pass_s, -1.8, 1.8)
				tr.add(4.0, 0.0, 0.0, HALF_W, false)
				_void_hole(g, tr, hd + 10.0, hd + 14.0, hs2 - hw, hs2 + hw)
				pass_s = hs2 + hw + 0.9 if hs2 < 0.0 else hs2 - hw - 0.9
			g.before = [pass_s] as Array[float]
		"narrow":
			var c := 0.0 if int(g.level) < 8 else rng.randf_range(-1.4, 1.4)
			_approach(tr, g, [c])
			var len2 := rng.randf_range(12.0, 18.0)
			var hw2 := clampf(1.8 - int(g.level) * 0.025, 1.4, 1.8)
			var dn := tr.length
			tr.add(len2, 0.0, rng.randf_range(-1.0, 1.0), hw2, false, func(_u: float): return Vector2(c, hw2))
			var v := _item("void")
			v.z = dn + len2 * 0.5
			v.depth = len2
			v.blocks = [Vector2(-EDGE, c - hw2), Vector2(c + hw2, EDGE)]
			g.items.append(v)
			_coin_line(g, dn + 1.0, dn + len2 - 1.0, c, c)
			tr.add(2.0, 0.0, 0.0, HALF_W, _rails(g))
			g.before = [c] as Array[float]
		"zigzag":
			_approach(tr, g, [0.0])
			var len3 := 28.0
			var amp := clampf(0.9 + int(g.level) * 0.04, 1.1, 1.6)
			var hw3 := clampf(1.9 - int(g.level) * 0.025, 1.5, 1.9)
			var dz := tr.length
			tr.add(len3, 0.0, 0.0, hw3, false, func(u: float): return Vector2(amp * sin(TAU * u), hw3))
			var k := 0.0
			while k < len3:
				var cz := amp * sin(TAU * (k + 1.0) / len3)
				var vz := _item("void")
				vz.z = dz + k + 1.0
				vz.depth = 2.0
				vz.blocks = [Vector2(-EDGE, cz - hw3), Vector2(cz + hw3, EDGE)]
				g.items.append(vz)
				(g.pearls as Array[Vector3]).append(Vector3(cz, PICK_OFFSET, dz + k + 1.0))
				k += 2.0
			tr.add(2.0, 0.0, 0.0, HALF_W, _rails(g))
			g.before = [0.0] as Array[float]
		"split":
			_approach(tr, g, [2.3, -2.3])
			var len4 := rng.randf_range(12.0, 16.0)
			var ds := tr.length
			tr.add(len4, 0.0, 0.0, HALF_W, false)
			_void_hole(g, tr, ds, ds + len4, -1.15, 1.15)
			_coin_line(g, ds + 1.0, ds + len4 - 1.0, 2.3 if float(g.before[0]) >= 0.0 else -2.3, 2.3 if float(g.before[0]) >= 0.0 else -2.3)
			g.before = [2.3, -2.3] as Array[float]
		"jump":
			_approach(tr, g, [0.0])
			var rp := _item("ramp")
			rp.depth = 2.0
			tr.add(1.0, 0.0, 0.0, HALF_W, true)
			rp.z = tr.length
			g.items.append(rp)
			var speed: float = g.speed
			var flight := speed * JUMP_TIME
			var gap_len := clampf(flight * 0.55, 2.5, 6.0)
			tr.add(1.0, 0.0, 0.0, HALF_W, true)
			var dg := tr.length
			tr.add(gap_len, 0.0, 0.0, HALF_W, false)
			var vg := _item("void")
			vg.z = dg + gap_len * 0.5
			vg.depth = gap_len
			vg.blocks = [Vector2(-EDGE, EDGE)]
			vg["air"] = true
			g.items.append(vg)
			tr.voids.append({"d0": dg, "d1": dg + gap_len, "kind": "gap"})
			for c2 in 5:
				var u := (c2 + 0.5) / 5.0
				(g.pearls as Array[Vector3]).append(Vector3(float(g.before[0]) * 0.3, PICK_OFFSET + jump_height(u), rp.z + flight * u))
			tr.add(maxf(flight - gap_len, 2.0) + 3.0, 0.0, 0.0, HALF_W, true)
		"platform":
			_approach(tr, g, [0.0])
			var plen := 6.0
			var dp := tr.length
			tr.add(plen, 0.0, 0.0, HALF_W, false)
			var pv := _item("pvoid")
			pv.z = dp + plen * 0.5
			pv.depth = plen
			pv.gw = 2.8
			pv.gx = 0.0
			pv.amp = 2.0
			pv.period = rng.randf_range(3.4, 4.2)
			pv.phase = rng.randf_range(0.0, TAU)
			g.items.append(pv)
			tr.voids.append({"d0": dp, "d1": dp + plen, "kind": "platform", "pw": pv.gw, "amp": pv.amp, "period": pv.period, "phase": pv.phase})
			tr.add(2.0, 0.0, 0.0, HALF_W, true)
			g.before = [-2.0, 0.0, 2.0] as Array[float]
		"drop":
			var d0d := tr.length
			tr.add(18.0, rng.randf_range(-0.3, 0.3), -6.0, HALF_W, true)
			_coin_line(g, d0d + 2.0, tr.length - 1.0, float(g.before[0]), 0.0)
			g.before = [0.0] as Array[float]
		"hammer":
			var hm := _item("hammer")
			hm.hw = 0.85
			hm.amp = 2.5
			hm.period = rng.randf_range(2.4, 3.2)
			hm.phase = rng.randf_range(0.0, TAU)
			hm.depth = 1.2
			_approach(tr, g, [-2.6, 2.6])
			_place(tr, g, hm, [-2.6, 0.0, 2.6])
			if rng.randf() < 0.5:
				var hm2 := hm.duplicate()
				hm2.phase = float(hm.phase) + PI * rng.randf_range(0.6, 1.0)
				hm2.blocks = []
				tr.add(rng.randf_range(4.0, 6.0), 0.0, 0.0, HALF_W, _rails(g))
				_place(tr, g, hm2, [-2.6, 0.0, 2.6])
		"tetro":
			# falling block pieces: one gap, on the other side from where you are
			var tw2 := clampf(door * 1.1, 2.0, 3.4)
			var gx := _door_x(tw2, rng, float(g.before[0]))
			var te := _item("tetro")
			te.blocks = [Vector2(-HALF_W - 0.5, gx - tw2 * 0.5), Vector2(gx + tw2 * 0.5, HALF_W + 0.5)]
			te.depth = 1.8
			te.gx = gx
			te.gw = tw2
			te["seed"] = rng.randi()
			_approach(tr, g, [gx])
			_place(tr, g, te, [gx])
		"lanes3":
			# three lanes split by two holes: left, middle or right
			_approach(tr, g, [0.0, 2.6, -2.6])
			var l3 := rng.randf_range(14.0, 18.0)
			var dl := tr.length
			tr.add(l3, 0.0, 0.0, HALF_W, false)
			tr.voids.append({"d0": dl, "d1": dl + l3, "kind": "hole", "s0": -1.95, "s1": -1.15})
			tr.voids.append({"d0": dl, "d1": dl + l3, "kind": "hole", "s0": 1.15, "s1": 1.95})
			var lv3 := _item("void")
			lv3.z = dl + l3 * 0.5
			lv3.depth = l3
			lv3.blocks = [Vector2(-1.95, -1.15), Vector2(1.15, 1.95)]
			g.items.append(lv3)
			var lane: float = [0.0, 2.7, -2.7][rng.randi() % 3]
			_coin_line(g, dl + 1.0, dl + l3 - 1.0, lane, lane)
			g.before = [0.0, 2.7, -2.7] as Array[float]
		"portal":
			_approach(tr, g, [0.0])
			var po := _item("portal")
			po.depth = 1.0
			tr.add(2.0, 0.0, 0.0, HALF_W, true)
			po.z = tr.length
			po["zone"] = ZONES[rng.randi() % ZONES.size()]
			g.items.append(po)
			tr.add(4.0, 0.0, 0.0, HALF_W, true)
		"twin":
			# the ball splits in two mirrored balls on two lanes
			_approach(tr, g, [1.8, -1.8])
			var tin := _item("twin_in")
			tr.add(1.0, 0.0, 0.0, HALF_W, true)
			tin.z = tr.length
			g.items.append(tin)
			tr.add(2.0, 0.0, 0.0, HALF_W, true)
			var d0t := tr.length
			var walls := rng.randi_range(2, 4)
			var tw := clampf(door * 0.7, 1.5, 2.0)
			var a := 1.8
			for k in walls:
				tr.add(rng.randf_range(8.0, 11.0), 0.0, 0.0, HALF_W, false)
				var lo := TWIN_GAP + tw * 0.5 + 0.1
				var hi := HALF_W - tw * 0.5 - 0.1
				var nd := rng.randf_range(lo, hi)
				if absf(nd - a) < 0.8:
					nd = hi if a < (lo + hi) * 0.5 else lo
				var w2 := _wall([-nd, nd], tw)
				w2.depth = 1.0
				w2["intro"] = ""
				tr.add(0.5, 0.0, 0.0, HALF_W, false)
				w2.z = tr.length
				g.items.append(w2)
				(g.pearls as Array[Vector3]).append(Vector3(nd, PICK_OFFSET, w2.z - 3.0))
				(g.pearls as Array[Vector3]).append(Vector3(-nd, PICK_OFFSET, w2.z - 3.0))
				tr.add(0.5, 0.0, 0.0, HALF_W, false)
				a = nd
			tr.add(6.0, 0.0, 0.0, HALF_W, false)
			_void_hole(g, tr, d0t, tr.length, -TWIN_GAP, TWIN_GAP)
			var tout := _item("twin_out")
			tout.z = tr.length + 0.5
			g.items.append(tout)
			tr.add(3.0, 0.0, 0.0, HALF_W, true)
			g.before = [a] as Array[float]
		"speedpad":
			var sp := _item("speedpad")
			tr.add(4.0, 0.0, -0.5, HALF_W, _rails(g))
			sp.z = tr.length
			sp.depth = 2.0
			g.items.append(sp)
			g.boost_end = tr.length + float(g.speed) * BOOST_MULT * BOOST_TIME
			var d0s := tr.length
			tr.add(14.0, rng.randf_range(-0.3, 0.3), -1.5, HALF_W, true)
			_coin_line(g, d0s + 1.0, tr.length - 1.0, float(g.before[0]), float(g.before[0]))
		"box":
			var bx := _item("box")
			bx.x = clampf(float(g.before[0]) + rng.randf_range(-1.5, 1.5), -2.4, 2.4)
			_pickup(tr, g, bx)
		"chest":
			# a secret chest hidden on the very edge
			var ch := _item("chest")
			ch.x = 2.75 if rng.randf() < 0.5 else -2.75
			_pickup(tr, g, ch)
		"boost", "shield", "magnet":
			var p3 := _item(pat)
			p3.x = clampf(float(g.before[0]) + rng.randf_range(-1.2, 1.2), -2.4, 2.4)
			_pickup(tr, g, p3)
			if pat == "boost":
				g.boost_end = tr.length + float(g.speed) * BOOST_MULT * BOOST_TIME


static func _pickup(tr: Track, g: Dictionary, e: Dictionary) -> void:
	var speed: float = g.speed
	var d0 := tr.length
	tr.add(speed * 0.6 + 6.0, 0.0, 0.0, HALF_W, _rails(g))
	e.z = tr.length - 2.0
	e.depth = 1.0
	_coin_line(g, d0 + 1.0, e.z - 1.0, float(g.before[0]), float(e.x))
	g.items.append(e)
	g.before = [float(e.x)] as Array[float]


static func _void_hole(g: Dictionary, tr: Track, d0: float, d1: float, s0: float, s1: float) -> void:
	tr.voids.append({"d0": d0, "d1": d1, "kind": "hole", "s0": s0, "s1": s1})
	var v := _item("void")
	v.z = (d0 + d1) * 0.5
	v.depth = d1 - d0
	v.blocks = [Vector2(s0, s1)]
	g.items.append(v)


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
		"x": 0.0, "y": PICK_OFFSET + 0.3, "gx": 0.0, "gw": 0.0, "hw": 0.0,
		"passed": false, "min_clear": EDGE, "taken": false,
	}


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


# ------------------------------------------------------------------ AI pilot (rivals + autotest)

## The thing at/after z the pilot has to deal with (obstacle or floor void).
static func _steer_item(e: Dictionary) -> bool:
	return (is_obstacle(e.kind) or is_void(e.kind)) and not e.get("smashed", false) and not e.get("air", false)


static func pilot_target(items: Array, z: float, run_t: float, speed: float, x := 0.0) -> float:
	for e in items:
		if not _steer_item(e):
			continue
		if float(e.z) + float(e.depth) * 0.5 < z - BOAT_HALF_LEN:
			continue
		if float(e.z) - z > speed * 2.5 + 6.0:
			break
		var eta := maxf(0.0, (float(e.z) - z) / maxf(speed, 0.1))
		return pilot_x(e, run_t + eta, x)
	var b := _bounds_at(z + speed * 0.5)
	return clampf(x, b.x + 0.6, b.y - 0.6)


static func pilot_x(e: Dictionary, at: float, x: float) -> float:
	var target := safe_x(e, at, x)
	if e.kind in ["sweeper", "hammer", "slider", "pvoid"]:
		var ok := true
		for k in [-2, -1, 1, 2]:
			if clearance(e, at + k * 0.12, target) < 0.05:
				ok = false
		if not ok:
			var best := target
			var best_c := -INF
			var b := _bounds_at(float(e.z))
			for i in 15:
				var cx := lerpf(b.x, b.y, i / 14.0)
				var c := INF
				for k in range(-3, 4):
					c = minf(c, clearance(e, at + k * 0.1, cx))
				c -= absf(cx - x) * 0.05
				if c > best_c:
					best_c = c
					best = cx
			target = best
	return target


## Rivals: is the ball at (z, x) hitting something / off the floor?
static func hits(items: Array, z: float, x: float, run_t: float) -> bool:
	if track != null and not track.floor_ok(z, x, run_t) and not track.rails_at(z):
		return true
	for e in items:
		if not is_obstacle(e.kind) or e.get("smashed", false):
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


## Last checkpoint before z (respawn point).
static func respawn_z(items: Array, z: float, _speed: float) -> float:
	var back := 2.0
	for e in items:
		if e.kind == "checkpoint" and float(e.z) < z - 1.0:
			back = float(e.z)
	return back
