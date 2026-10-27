class_name GameWorld
extends Node3D
## Everything you see except the boat and the UI: sky, water, moon, canyon,
## obstacles, pickups, pearls, decorations and effects. Visual only — the
## rules live in main.gd / level_gen.gd.


var theme: Dictionary = {}
var env: Environment
var sky_mat: ProceduralSkyMaterial
var sun: DirectionalLight3D
var water: MeshInstance3D
var water_mat: ShaderMaterial
var moon: MeshInstance3D
var moon_mat: StandardMaterial3D
var moon_ring_mat: StandardMaterial3D
var level_root: Node3D
var splash: CPUParticles3D
var confetti: CPUParticles3D
var ambient: CPUParticles3D
var raft: Node3D
var chest_lid: Node3D
var boss: Node3D
var boss_eye_mat: StandardMaterial3D
var boss_beam: MeshInstance3D
var boss_beam_t := 0.0
var boss_fire_t := 2.0
var boss_alive := false

var items: Array[Dictionary] = []
var pearls: Array[Dictionary] = []
var finish_z := 100.0

var rng := RandomNumberGenerator.new()
var _mats := {}
var _coin_mesh: ArrayMesh
var _coin_mat: StandardMaterial3D
var _coin_gold: ArrayMesh
var _coin_mat_cur: Material
var _garlands: Array[Node3D] = []
var _next_garland := 40.0
var sparkle: CPUParticles3D
var _fall_shader: Shader


func _ready() -> void:
	_setup_environment()
	_build_water()
	_build_moon()
	splash = _burst_particles(48, 0.9, Vector3(0.0, -14.0, 0.0), 3.0, 7.5, 0.12, false)
	confetti = _burst_particles(90, 2.2, Vector3(0.0, -5.0, 0.0), 5.0, 10.0, 0.09, true)
	level_root = Node3D.new()
	add_child(level_root)
	_coin_gold = _make_coin_mesh()
	_coin_mesh = _coin_gold
	_coin_mat = StandardMaterial3D.new()
	_coin_mat.albedo_color = Color("ffc531")
	_coin_mat.metallic = 0.85
	_coin_mat.roughness = 0.28
	_coin_mat.emission_enabled = true
	_coin_mat.emission = Color("ffae00")
	_coin_mat.emission_energy_multiplier = 0.45
	_coin_mat.next_pass = Toon.outline_mat(0.025)
	sparkle = _burst_particles(14, 0.45, Vector3.ZERO, 2.0, 4.0, 0.07, false)
	sparkle.spread = 180.0
	var sp_mat := _fx_mat("coin_sparkle", Color(1.0, 0.85, 0.3, 1.0), 3.0)
	sparkle.material_override = sp_mat
	var sp_ramp := Gradient.new()
	sp_ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	sp_ramp.set_color(1, Color(1.0, 0.7, 0.1, 0.0))
	sparkle.color_ramp = sp_ramp
	_fall_shader = load("res://shaders/fall.gdshader")


# ================================================================== building

var walls: Walls
var _wall_len := 100.0
var _wall_seed := 1


func build_level(data: Dictionary, level: int, wall_left := "canyon", wall_right := "harbor") -> void:
	for c in level_root.get_children():
		c.queue_free()
	ambient = null
	raft = null
	chest_lid = null
	boss = null
	boss_beam = null
	boss_alive = false
	_mats.clear()
	theme = Themes.for_level(level)
	_apply_theme()
	_garlands.clear()
	_next_garland = 40.0
	match String(theme.get("season", "")):
		"halloween":
			_coin_mesh = _make_pumpkin_mesh()
			_coin_mat_cur = null
		"christmas":
			_coin_mesh = _make_gift_mesh()
			_coin_mat_cur = null
		_:
			_coin_mesh = _coin_gold
			_coin_mat_cur = _coin_mat
	rng.seed = level * 31 + 7
	# Items and coins are only data here; their 3D nodes stream in as the boat
	# approaches (see _stream), so even the endless river stays light on phones.
	items = []
	for it in data.items:
		items.append((it as Dictionary).duplicate())
	pearls = []
	var ps: Array = data.pearls.duplicate()
	ps.sort_custom(func(a: Vector3, b: Vector3): return a.z < b.z)
	for pos in ps:
		var v: Vector3 = pos
		pearls.append({"x": v.x, "y": v.y, "z": v.z, "taken": false})
	_next_item = 0
	_next_pearl = 0
	finish_z = data.finish
	endless = bool(data.get("endless", false))
	if not endless:
		_spawn_finish(finish_z)
	_wall_len = finish_z + 90.0
	_wall_seed = level
	_spawn_floor(_wall_len)
	set_walls(wall_left, wall_right)
	_spawn_ambient()
	if String(data.get("special", "")) == "boss":
		_spawn_boss()


func set_walls(left: String, right: String) -> void:
	if walls == null:
		walls = Walls.new()
		add_child(walls)
	walls.build(left, right, _wall_len, theme, _wall_seed)
	walls.ensure(_last_boat_z + SPAWN_AHEAD + 100.0)


const SPAWN_AHEAD := 170.0
const DESPAWN_BEHIND := 45.0
var endless := false
var _next_item := 0
var _next_pearl := 0
var _last_boat_z := 0.0


## Creates nodes for things coming into view and frees things far behind.
func _stream(boat_z: float) -> void:
	_last_boat_z = boat_z
	var ahead := boat_z + SPAWN_AHEAD
	while _next_item < items.size() and float(items[_next_item].z) < ahead:
		_spawn_item(items[_next_item])
		_next_item += 1
	while _next_pearl < pearls.size() and float(pearls[_next_pearl].z) < ahead:
		var p: Dictionary = pearls[_next_pearl]
		if not p.taken:
			var mi := _mi(level_root, _coin_mesh, _coin_mat_cur, Vector3(p.x, p.y, p.z))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p["node"] = mi
		_next_pearl += 1
	var behind := boat_z - DESPAWN_BEHIND
	for i in mini(_next_item, items.size()):
		var e: Dictionary = items[i]
		if float(e.z) > behind:
			break
		if e.has("node") and not e.get("gone", false):
			(e.node as Node3D).queue_free()
			e["gone"] = true
	for i in mini(_next_pearl, pearls.size()):
		var p2: Dictionary = pearls[i]
		if float(p2.z) > behind:
			break
		if p2.has("node") and not p2.get("gone", false):
			(p2.node as Node3D).queue_free()
			p2["gone"] = true
	if theme.has("season"):
		while _next_garland < ahead and (endless or _next_garland < finish_z - 10.0):
			_garlands.append(_spawn_garland(_next_garland))
			_next_garland += 38.0
		while not _garlands.is_empty() and _garlands[0].position.z < behind:
			_garlands.pop_front().queue_free()
	if walls:
		walls.ensure(boat_z + SPAWN_AHEAD + 100.0)
		walls.cull(boat_z - 80.0)


func _spawn_floor(length: float) -> void:
	_box(level_root, Vector3(LevelGen.RIVER_W + 4.0, 1.0, length + 60.0),
		Vector3(0.0, LevelGen.FLOOR_Y - 0.5, (length - 40.0) * 0.5 - 10.0), _mat("floor", theme.floor, 1.0, 0.0, 0.0))


## Toon material with an ink outline (outline 0 for huge surfaces like walls).
func _mat(key: String, color: Color, _rough := 0.9, glow := 0.0, outline := 0.035) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := Toon.mat(color, glow, outline)
	_mats[key] = m
	return m


func _fx_mat(key: String, color: Color, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(color.r, color.g, color.b)
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _mi(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return _mi(parent, bm, mat, pos, rot)


func _cone(parent: Node3D, bottom_r: float, top_r: float, height: float, pos: Vector3, mat: Material, sides := 6, rot := Vector3.ZERO) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_r
	cm.top_radius = top_r
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	return _mi(parent, cm, mat, pos, rot)


func _ball(parent: Node3D, r: float, pos: Vector3, mat: Material, squash := Vector3.ONE) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	var mi := _mi(parent, sm, mat, pos)
	mi.scale = squash
	return mi


func _torus(parent: Node3D, inner: float, outer: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 32
	tm.ring_segments = 10
	return _mi(parent, tm, mat, pos, rot)


# ------------------------------------------------------------------ environment

func _setup_environment() -> void:
	sky_mat = ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)


func _apply_theme() -> void:
	sky_mat.sky_top_color = theme.sky_top
	sky_mat.sky_horizon_color = theme.sky_horizon
	sky_mat.ground_horizon_color = theme.sky_horizon
	sky_mat.ground_bottom_color = theme.ground
	env.ambient_light_energy = theme.ambient
	env.fog_light_color = theme.fog
	env.fog_density = theme.fog_density
	sun.light_color = theme.sun
	sun.light_energy = theme.sun_energy
	sun.rotation_degrees = theme.sun_rot
	water_mat.set_shader_parameter("deep_color", theme.water_deep)
	water_mat.set_shader_parameter("shallow_color", theme.water_shallow)
	water_mat.set_shader_parameter("grid_color", theme.get("grid", Color("ff2fd0")))
	water_mat.set_shader_parameter("edge_color", theme.get("edge", Color("00e5ff")))
	moon_mat.albedo_color = theme.moon
	moon_mat.emission = theme.moon
	moon_ring_mat.albedo_color = theme.get("neon2", Color("00e5ff"))


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(LevelGen.RIVER_W + 8.0, 230.0)
	pm.subdivide_width = 14
	pm.subdivide_depth = 120
	water = MeshInstance3D.new()
	water.mesh = pm
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water.material_override = water_mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_moon() -> void:
	moon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.0
	sm.height = 8.0
	moon.mesh = sm
	moon_mat = StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.emission_enabled = true
	moon_mat.emission_energy_multiplier = 1.3
	moon_mat.set("disable_fog", true)
	moon_mat.next_pass = Toon.outline_mat(0.18)
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	# synthwave bands across the planet
	var band := StandardMaterial3D.new()
	band.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	band.albedo_color = Color(0.23, 0.06, 0.35)
	band.set("disable_fog", true)
	for k in 3:
		var by := -0.6 - k * 0.95
		var r := sqrt(maxf(16.0 - by * by, 0.1))
		var bm := CylinderMesh.new()
		bm.top_radius = r + 0.02
		bm.bottom_radius = r + 0.02
		bm.height = 0.18 + k * 0.1
		bm.radial_segments = 32
		bm.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = band
		mi.position.y = by
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		moon.add_child(mi)
	# neon planetary ring
	moon_ring_mat = StandardMaterial3D.new()
	moon_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_ring_mat.albedo_color = Color("00e5ff")
	moon_ring_mat.set("disable_fog", true)
	var ring := TorusMesh.new()
	ring.inner_radius = 6.0
	ring.outer_radius = 6.5
	ring.rings = 48
	ring.ring_segments = 6
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.material_override = moon_ring_mat
	rmi.scale = Vector3(1.0, 0.25, 1.0)
	rmi.rotation = Vector3(0.25, 0.0, -0.25)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.add_child(rmi)


func _burst_particles(amount: int, life: float, gravity: Vector3, v_min: float, v_max: float,
		size: float, colorful: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 60.0
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = gravity
	p.local_coords = false
	if colorful:
		var g := Gradient.new()
		g.set_color(0, Color("ff5a4e"))
		g.set_color(1, Color("4ea8ff"))
		g.add_point(0.25, Color("ffd23f"))
		g.add_point(0.5, Color("3ddc97"))
		g.add_point(0.75, Color("b57bff"))
		p.color_initial_ramp = g
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.damping_min = 1.5
		p.damping_max = 2.5
		var q := BoxMesh.new()
		q.size = Vector3(size * 2.0, size * 1.2, 0.02)
		p.mesh = q
		p.material_override = _fx_mat("confetti", Color.WHITE)
	else:
		var d := SphereMesh.new()
		d.radius = size
		d.height = size * 2.0
		d.radial_segments = 6
		d.rings = 3
		p.mesh = d
		var fade := Gradient.new()
		fade.set_color(0, Color(0.95, 1.0, 1.0, 1.0))
		fade.set_color(1, Color(0.95, 1.0, 1.0, 0.0))
		p.color_ramp = fade
		p.material_override = _fx_mat("splash", Color.WHITE)
	add_child(p)
	return p


# ------------------------------------------------------------------ obstacles

func _spawn_item(e: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, e.z)
	level_root.add_child(root)
	e["node"] = root
	match e.kind:
		"wall", "gate2":
			for b in e.blocks:
				_barrier(root, (b as Vector2).x, (b as Vector2).y, bool(e.get("air", false)))
			if not e.get("air", false):
				for r in LevelGen.free_ranges(e, 0.0):
					_door_marks(root, (r as Vector2).x - LevelGen.BOAT_HALF_W, (r as Vector2).y + LevelGen.BOAT_HALF_W)
		"block":
			for b in e.blocks:
				_cargo(root, (b as Vector2).x, (b as Vector2).y)
		"mines":
			_build_mines(root, e)
		"slider":
			var mover := Node3D.new()
			root.add_child(mover)
			var hw := float(e.gw) * 0.5
			var far := LevelGen.RIVER_W + float(e.amp) + 1.0
			_barrier(mover, -far, -hw, false)
			_barrier(mover, hw, far, false)
			_door_marks(mover, -hw, hw)
			e["mover"] = mover
		"sweeper":
			var mv := Node3D.new()
			root.add_child(mv)
			_cargo(mv, -float(e.hw), float(e.hw))
			e["mover"] = mv
		"ramp":
			_build_ramp(root, e)
		"boost", "slow":
			_build_ring(root, e)
		"shield", "magnet":
			_build_orb(root, e)


## Energy barrier between x0 and x1 (clipped to the river), WALL_H above the water.
func _barrier(root: Node3D, x0: float, x1: float, tall: bool) -> void:
	var half := LevelGen.RIVER_W * 0.5 + 0.4
	x0 = maxf(x0, -half - 6.0)
	x1 = minf(x1, half + 6.0)
	if x1 - x0 < 0.05:
		return
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var top := LevelGen.WATER_REST + LevelGen.WALL_H
	var bottom := LevelGen.FLOOR_Y
	var metal := _mat("pylon", theme.rock, 0.6)
	var glow := _mat("pylon_tip", theme.rock_tip, 0.3, theme.tip_glow, 0.025)
	var panel := _fx_mat("barrier_panel", Color(theme.rock_tip, 0.32), 1.2)
	# translucent energy panel
	var pm := _box(root, Vector3(w, top - LevelGen.WATER_REST + 0.3, 0.12), Vector3(cx, (top + LevelGen.WATER_REST - 0.3) * 0.5, 0.0), panel)
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# solid base under the waterline and a glowing top rail
	_box(root, Vector3(w, LevelGen.WATER_REST + 0.25 - bottom, 0.7), Vector3(cx, (LevelGen.WATER_REST + 0.25 + bottom) * 0.5, 0.0), metal)
	_box(root, Vector3(w, 0.18, 0.3), Vector3(cx, top, 0.0), glow)
	_box(root, Vector3(w, 0.06, 0.32), Vector3(cx, LevelGen.WATER_REST + 0.9, 0.0), glow)
	# posts
	var n := maxi(int(w / 1.6), 1)
	for k in n + 1:
		var px := lerpf(x0, x1, float(k) / n)
		if absf(px) > half + 0.5:
			continue
		_box(root, Vector3(0.22, top - bottom, 0.42), Vector3(px, (top + bottom) * 0.5, 0.0), metal)
	if tall:
		# jump wall: warning stripes on the panel
		for k in 6:
			var sx := lerpf(-LevelGen.RIVER_W * 0.5 + 0.6, LevelGen.RIVER_W * 0.5 - 0.6, k / 5.0)
			_box(root, Vector3(0.5, 0.5, 0.14), Vector3(sx, top - 0.6, 0.0), _mat("jump_mark", Color("ffd23f"), 0.3, 2.0, 0.0), Vector3(0.0, 0.0, PI * 0.25))


## Green glowing door posts + arrow on the water: "go through here".
func _door_marks(root: Node3D, x0: float, x1: float) -> void:
	var half := LevelGen.RIVER_W * 0.5
	var go := _mat("door_go", Color("39ff9f"), 0.2, 3.5, 0.0)
	var top := LevelGen.WATER_REST + LevelGen.WALL_H
	for px in [x0, x1]:
		if absf(px) < half + 0.2:
			_box(root, Vector3(0.12, top - LevelGen.WATER_REST + 0.2, 0.5), Vector3(px, (top + LevelGen.WATER_REST) * 0.5, 0.0), go)
	var cx := clampf((x0 + x1) * 0.5, -half + 0.8, half - 0.8)
	var pr := PrismMesh.new()
	pr.size = Vector3(0.9, 0.7, 0.04)
	var arrow := _mi(root, pr, _fx_mat("door_arrow", Color(0.2, 1.0, 0.6, 0.75), 2.5), Vector3(cx, LevelGen.WATER_REST + 0.06, -2.2), Vector3(-PI * 0.5, 0.0, 0.0))
	arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Stack of neon cargo crates between x0 and x1.
func _cargo(root: Node3D, x0: float, x1: float) -> void:
	var w := x1 - x0
	var cx := (x0 + x1) * 0.5
	var crate := _mat("crate_body", theme.get("metal", Color("3a3f6a")), 0.5)
	var edge := _mat("crate_edge", theme.get("neon", Color("ff2fd0")), 0.2, 3.0, 0.0)
	var n := maxi(int(round(w / 1.25)), 1)
	var cw := w / n
	for k in n:
		var bx := x0 + cw * (k + 0.5)
		var hgt := 1.9 if k % 2 == 0 else 2.4
		var base := LevelGen.WATER_REST - 0.4
		_box(root, Vector3(cw - 0.08, hgt, 1.5), Vector3(bx, base + hgt * 0.5, 0.0), crate)
		_box(root, Vector3(cw - 0.02, 0.08, 1.54), Vector3(bx, base + hgt, 0.0), edge)
		_box(root, Vector3(0.08, hgt, 1.54), Vector3(bx - cw * 0.5 + 0.06, base + hgt * 0.5, 0.0), edge)
	_box(root, Vector3(w, LevelGen.WATER_REST - 0.4 - LevelGen.FLOOR_Y, 1.4), Vector3(cx, (LevelGen.WATER_REST - 0.4 + LevelGen.FLOOR_Y) * 0.5, 0.0), crate)


## Floating plasma orbs.
func _build_mines(root: Node3D, e: Dictionary) -> void:
	var core := _mat("mine_core", Color("ff3d5a"), 0.3, 3.5, 0.03)
	var shell := _mat("mine_shell", Color("2a2140"), 0.4)
	var spike := _mat("mine_spike", Color("ffd166"), 0.3, 1.5, 0.02)
	var spin := Node3D.new()
	root.add_child(spin)
	for b in e.blocks:
		var v: Vector2 = b
		var r := (v.y - v.x) * 0.5
		var orb := Node3D.new()
		orb.position = Vector3((v.x + v.y) * 0.5, LevelGen.WATER_REST + 0.7, 0.0)
		spin.add_child(orb)
		_ball(orb, r * 0.9, Vector3.ZERO, shell)
		_ball(orb, r * 0.5, Vector3(0.0, 0.0, -r * 0.6), core)
		for k in 8:
			var a := TAU * k / 8.0
			var dir := Vector3(cos(a), sin(a), 0.0)
			_cone(orb, 0.1, 0.0, r * 0.6, dir * r * 1.05, spike, 4, Vector3(0.0, 0.0, a - PI * 0.5))
		var tether := _box(spin, Vector3(0.05, 1.2, 0.05), Vector3((v.x + v.y) * 0.5, LevelGen.WATER_REST - 0.1, 0.0), _mat("mine_tether", Color("1e1b2e"), 0.5, 0.0, 0.0))
		tether.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e["spinner"] = spin


func _foam(root: Node3D) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(LevelGen.RIVER_W + 0.6, 2.2)
	var mi := _mi(root, pm, _fx_mat("foam", Color(1.0, 1.0, 1.0, 0.55)), Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


## Energy fence: hex pylons whose tops (and the laser between them) sit exactly at h.
func _build_reef(root: Node3D, h: float, extra_depth := 0.0) -> void:
	var metal := _mat("pylon", theme.rock, 0.6)
	var glow := _mat("pylon_tip", theme.rock_tip, 0.3, theme.tip_glow, 0.025)
	var bottom := LevelGen.FLOOR_Y - extra_depth
	var base_top := maxf(h * 0.4, 0.25)
	var base_h := base_top - bottom
	_box(root, Vector3(LevelGen.RIVER_W + 0.4, base_h, 1.0), Vector3(0.0, bottom + base_h * 0.5, 0.0), metal)
	_box(root, Vector3(LevelGen.RIVER_W + 0.4, 0.08, 1.04), Vector3(0.0, base_top - 0.06, 0.0), glow)
	var n := 5
	for i in n:
		var x := lerpf(-LevelGen.RIVER_W * 0.5 + 0.5, LevelGen.RIVER_W * 0.5 - 0.5, float(i) / (n - 1))
		var top := h - 0.24   # glowing cap ends exactly at h
		var height := top - bottom
		_cone(root, 0.36, 0.3, height, Vector3(x, bottom + height * 0.5, 0.0), metal, 6)
		_cone(root, 0.32, 0.12, 0.24, Vector3(x, top + 0.12, 0.0), glow, 6)
		_box(root, Vector3(0.05, height * 0.6, 0.05), Vector3(x, bottom + height * 0.6, 0.31), glow)
	# the laser: exact danger height
	var beam := _box(root, Vector3(LevelGen.RIVER_W - 0.6, 0.07, 0.07), Vector3(0.0, h - 0.035, 0.0), _mat("laser", theme.rock_tip, 0.2, 4.0, 0.0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hard-light gantry. The glowing strip on its underside marks the clearance.
func _build_bridge(root: Node3D, b: float) -> void:
	var metal := _mat("gantry", theme.wood, 0.5)
	var dark := _mat("gantry_dark", theme.wood_dark, 0.6)
	var lamp := _mat("lamp", theme.lamp, 0.3, 2.6, 0.02)
	var span := LevelGen.RIVER_W + 2.6
	for s in [-1.0, 1.0]:
		var ph := b - LevelGen.FLOOR_Y
		var px: float = s * (LevelGen.RIVER_W * 0.5 + 0.5)
		_box(root, Vector3(0.8, ph, 0.9), Vector3(px, LevelGen.FLOOR_Y + ph * 0.5, 0.0), dark)
		_box(root, Vector3(0.06, ph * 0.9, 0.06), Vector3(px - s * 0.42, LevelGen.FLOOR_Y + ph * 0.5, 0.46), lamp)
	_deck(root, b, span, metal, dark, lamp)


## A bridge deck whose underside sits at local height `y`.
func _deck(root: Node3D, y: float, span: float, metal: Material, dark: Material, lamp: Material) -> void:
	_box(root, Vector3(span, 0.45, 1.4), Vector3(0.0, y + 0.22, 0.0), metal)
	_box(root, Vector3(span - 0.4, 0.18, 1.0), Vector3(0.0, y + 0.53, 0.0), dark)
	var under := _box(root, Vector3(span - 0.2, 0.06, 1.2), Vector3(0.0, y + 0.03, 0.0), _mat("under_glow", theme.get("neon", theme.lamp), 0.2, 3.0, 0.0))
	under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for rz in [-0.66, 0.66]:
		_box(root, Vector3(span, 0.06, 0.06), Vector3(0.0, y + 0.5, rz), lamp)
	for k in 5:
		var x := lerpf(-span * 0.5 + 0.8, span * 0.5 - 0.8, k / 4.0)
		_box(root, Vector3(0.5, 0.12, 0.08), Vector3(x, y + 0.25, 0.72), _mat("chevron", theme.get("neon2", Color.WHITE), 0.2, 2.0, 0.0), Vector3(0.0, 0.0, 0.5))


func _build_drawbridge(root: Node3D, e: Dictionary) -> void:
	var metal := _mat("gantry", theme.wood, 0.5)
	var dark := _mat("gantry_dark", theme.wood_dark, 0.6)
	var lamp := _mat("lamp", theme.lamp, 0.3, 2.6, 0.02)
	var tower := _mat("tower", theme.get("metal", theme.rock), 0.5)
	var neon := _mat("neon_strip", theme.get("neon", theme.lamp), 0.2, 3.0, 0.0)
	var top: float = e.b + 2.2
	for s in [-1.0, 1.0]:
		var th := top - LevelGen.FLOOR_Y
		var tx: float = s * (LevelGen.RIVER_W * 0.5 + 0.8)
		_box(root, Vector3(1.2, th, 1.6), Vector3(tx, LevelGen.FLOOR_Y + th * 0.5, 0.0), tower)
		for zz in [-0.82, 0.82]:
			_box(root, Vector3(0.08, th * 0.92, 0.04), Vector3(tx - s * 0.5, LevelGen.FLOOR_Y + th * 0.5, zz), neon)
		_cone(root, 0.5, 0.25, 0.5, Vector3(tx, top + 0.25, 0.0), dark, 8)
		_ball(root, 0.22, Vector3(tx, top + 0.65, 0.0), lamp)
	var mover := Node3D.new()
	root.add_child(mover)
	_deck(mover, 0.0, LevelGen.RIVER_W - 0.2, metal, dark, lamp)
	for k in 8:
		var col: Color = theme.get("neon2", Color("ffd23f")) if k % 2 == 0 else Color("10101c")
		_box(mover, Vector3(0.95, 0.04, 1.3), Vector3(lerpf(-3.4, 3.4, k / 7.0), -0.01, 0.0), _mat("stripe%d" % (k % 2), col, 0.5, 1.5 if k % 2 == 0 else 0.0, 0.0))
	e["mover"] = mover
	var chains: Array[MeshInstance3D] = []
	for s in [-1.0, 1.0]:
		var c := _box(root, Vector3(0.07, 1.0, 0.07), Vector3(s * (LevelGen.RIVER_W * 0.5 - 0.4), 0.0, 0.0), neon)
		chains.append(c)
	e["chains"] = chains
	e["chain_top"] = top - 0.3


## Moving gate: energy fence + deck ride up and down together.
func _build_slider(root: Node3D, e: Dictionary) -> void:
	var metal := _mat("gantry", theme.wood, 0.5)
	var dark := _mat("gantry_dark", theme.wood_dark, 0.6)
	var lamp := _mat("lamp", theme.lamp, 0.3, 2.6, 0.02)
	var tower := _mat("tower", theme.metal if theme.has("metal") else theme.rock, 0.5)
	var neon := _mat("neon_strip", theme.get("neon", theme.lamp), 0.2, 3.0, 0.0)
	var amp: float = e.amp
	var top: float = float(e.b) + amp + 1.6
	for sx in [-1.0, 1.0]:
		var th := top - LevelGen.FLOOR_Y
		var tx: float = sx * (LevelGen.RIVER_W * 0.5 + 0.7)
		_box(root, Vector3(1.0, th, 1.5), Vector3(tx, LevelGen.FLOOR_Y + th * 0.5, 0.0), tower)
		# rail the gate rides on
		_box(root, Vector3(0.12, th * 0.95, 0.12), Vector3(tx - sx * 0.56, LevelGen.FLOOR_Y + th * 0.5, 0.0), neon)
		_ball(root, 0.24, Vector3(tx, top + 0.2, 0.0), lamp)
	var mover := Node3D.new()
	root.add_child(mover)
	_build_reef(mover, e.h, amp + 0.6)
	_deck(mover, e.b, LevelGen.RIVER_W - 0.2, metal, dark, lamp)
	for sx2 in [-1.0, 1.0]:
		# glowing arrows that show it moves
		var pr := PrismMesh.new()
		pr.size = Vector3(0.5, 0.45, 0.1)
		var m1 := _mi(mover, pr, _mat("slider_arrow", theme.get("neon2", Color.WHITE), 0.2, 3.0, 0.0), Vector3(sx2 * 3.0, (float(e.h) + float(e.b)) * 0.5 + 0.35, -0.75))
		m1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m2 := _mi(mover, pr, _mat("slider_arrow", theme.get("neon2", Color.WHITE), 0.2, 3.0, 0.0), Vector3(sx2 * 3.0, (float(e.h) + float(e.b)) * 0.5 - 0.35, -0.75), Vector3(0.0, 0.0, PI))
		m2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e["mover"] = mover


## Plasma mines: a glowing band across the river. Pass above OR below it.
func _build_mine(root: Node3D, e: Dictionary) -> void:
	var c := (float(e.m0) + float(e.m1)) * 0.5
	var r := (float(e.m1) - float(e.m0)) * 0.5
	var core := _mat("mine_core", Color("ff3d5a"), 0.3, 3.5, 0.03)
	var shell := _mat("mine_shell", Color("2a2140"), 0.4)
	var spike := _mat("mine_spike", Color("ffd166"), 0.3, 1.5, 0.02)
	var spin := Node3D.new()
	spin.position = Vector3(0.0, c, 0.0)
	root.add_child(spin)
	var count := 4
	for i in count:
		var x := lerpf(-LevelGen.RIVER_W * 0.5 + 1.0, LevelGen.RIVER_W * 0.5 - 1.0, float(i) / (count - 1))
		var orb := Node3D.new()
		orb.position = Vector3(x, 0.0, 0.0)
		spin.add_child(orb)
		_ball(orb, r * 0.95, Vector3.ZERO, shell)
		_ball(orb, r * 0.55, Vector3(0.0, 0.0, -r * 0.6), core)
		for k in 6:
			var a := TAU * k / 6.0
			var dir := Vector3(cos(a), sin(a), 0.0)
			_cone(orb, 0.11, 0.0, r * 0.7, dir * r * 1.1, spike, 4, Vector3(0.0, 0.0, a - PI * 0.5))
	# the plasma link between orbs = the danger band
	var beam := CylinderMesh.new()
	beam.top_radius = r * 0.42
	beam.bottom_radius = r * 0.42
	beam.height = LevelGen.RIVER_W + 0.6
	beam.radial_segments = 8
	beam.rings = 1
	var link := _mi(spin, beam, _fx_mat("mine_link", Color(1.0, 0.25, 0.45, 0.55), 2.5), Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5))
	link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-1.0, 1.0]:
		_box(root, Vector3(0.5, 0.9, 0.9), Vector3(sx * (LevelGen.RIVER_W * 0.5 + 0.2), c, 0.0), _mat("mine_emitter", theme.get("metal", Color("3a3f6a")), 0.5))
	e["spinner"] = spin


## Geyser (up) / vortex (down): a glowing pad on the water surface.
func _build_current(root: Node3D, e: Dictionary) -> void:
	var up: bool = e.kind == "geyser"
	var col := Color("54e0ff") if up else Color("ff4fd8")
	var pad := Node3D.new()
	root.add_child(pad)
	for k in 3:
		var rad := 1.0 + k * 1.1
		_torus(pad, rad, rad + 0.16, Vector3(0.0, 0.04, 0.0), _fx_mat("cur_ring_" + e.kind, Color(col, 0.85), 3.0))
	var disc := CylinderMesh.new()
	disc.top_radius = 3.4
	disc.bottom_radius = 3.4
	disc.height = 0.02
	disc.radial_segments = 24
	disc.rings = 1
	_mi(pad, disc, _fx_mat("cur_disc_" + e.kind, Color(col, 0.22), 1.0), Vector3(0.0, 0.02, 0.0))
	for k in 3:
		var pr := PrismMesh.new()
		pr.size = Vector3(0.9, 0.7, 0.18)
		var arrow := _mi(pad, pr, _fx_mat("cur_arrow_" + e.kind, Color(col, 0.95), 3.0), Vector3(0.0, 0.8 + k * 0.85, 0.0), Vector3(0.0, 0.0, 0.0 if up else PI))
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var jet := CPUParticles3D.new()
	jet.amount = 26
	jet.lifetime = 0.9
	jet.local_coords = true
	jet.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	jet.emission_ring_axis = Vector3.UP
	jet.emission_ring_radius = 2.4
	jet.emission_ring_inner_radius = 0.5
	jet.emission_ring_height = 0.1
	jet.direction = Vector3.UP if up else Vector3.DOWN
	jet.spread = 8.0
	jet.initial_velocity_min = 3.0 if up else 0.5
	jet.initial_velocity_max = 5.0 if up else 1.0
	jet.gravity = Vector3(0.0, -3.0, 0.0)
	if not up:
		jet.position.y = 2.5
		jet.tangential_accel_min = 6.0
		jet.tangential_accel_max = 8.0
		jet.radial_accel_min = -4.0
		jet.radial_accel_max = -3.0
	var sp := SphereMesh.new()
	sp.radius = 0.12
	sp.height = 0.24
	sp.radial_segments = 6
	sp.rings = 3
	jet.mesh = sp
	jet.material_override = _fx_mat("cur_jet_" + e.kind, Color(col, 0.9), 3.0)
	pad.add_child(jet)
	e["pad"] = pad
	e["jet"] = jet


## Jump ramp floating on the tide: neon deck with chevrons.
func _build_ramp(root: Node3D, e: Dictionary) -> void:
	var pad := Node3D.new()
	root.add_child(pad)
	var neon := _mat("ramp_neon", theme.get("neon2", Color("00e5ff")), 0.2, 3.0, 0.0)
	var deck := _mat("ramp_deck", theme.get("metal", Color("3a3f6a")), 0.5)
	var slope := atan2(1.1, 3.0)
	_box(pad, Vector3(LevelGen.RIVER_W - 0.4, 0.2, 3.2), Vector3(0.0, 0.45, 0.0), deck, Vector3(-slope, 0.0, 0.0))
	for sx in [-LevelGen.RIVER_W * 0.5 + 0.2, LevelGen.RIVER_W * 0.5 - 0.2]:
		_box(pad, Vector3(0.12, 0.3, 3.2), Vector3(sx, 0.55, 0.0), neon, Vector3(-slope, 0.0, 0.0))
	for k in 3:
		for cx in [-2.4, 0.0, 2.4]:
			var pr := PrismMesh.new()
			pr.size = Vector3(1.2, 0.5, 0.06)
			var ch := _mi(pad, pr, _mat("ramp_chev", theme.get("neon", Color("ff2fd0")), 0.2, 3.0, 0.0), Vector3(cx, 0.25 + k * 0.33, -1.0 + k * 0.9), Vector3(-PI * 0.5 - slope, 0.0, 0.0))
			ch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	e["pad"] = pad


## The boat hit a geyser / vortex.
func trigger_current(e: Dictionary) -> void:
	if not e.has("pad") or e.get("gone", false):
		return
	var pad: Node3D = e.pad
	burst_splash(pad.global_position + Vector3(0.0, 0.5, 0.0))
	var tw := create_tween()
	tw.tween_property(pad, "scale", Vector3(1.6, 2.5 if e.kind == "geyser" else 0.3, 1.6), 0.15)
	tw.tween_property(pad, "scale", Vector3.ONE, 0.4)


func _build_ring(root: Node3D, e: Dictionary) -> void:
	var boost: bool = e.kind == "boost"
	var col := Color("ffc531") if boost else Color("8fd8ff")
	var spinner := Node3D.new()
	spinner.position = Vector3(e.x, e.y, 0.0)
	root.add_child(spinner)
	_torus(spinner, 1.15, 1.42, Vector3.ZERO, _mat("ring_" + e.kind, col, 0.3, 2.2), Vector3(PI * 0.5, 0.0, 0.0))
	if boost:
		for k in 2:
			var pr := PrismMesh.new()
			pr.size = Vector3(0.7, 0.45, 0.12)
			_mi(spinner, pr, _mat("chev", Color("fff3b0"), 0.3, 2.5), Vector3(0.0, 0.0, -0.25 + k * 0.4), Vector3(PI * 0.5, 0.0, 0.0))
	else:
		var disc := CylinderMesh.new()
		disc.top_radius = 1.1
		disc.bottom_radius = 1.1
		disc.height = 0.04
		disc.radial_segments = 24
		_mi(spinner, disc, _fx_mat("slowdisc", Color(0.6, 0.85, 1.0, 0.25), 0.8), Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0))
		_ball(spinner, 0.3, Vector3.ZERO, _mat("slowmoon", Color("f4f7ff"), 0.3, 2.0))
	e["spinner"] = spinner


func _build_orb(root: Node3D, e: Dictionary) -> void:
	var shield: bool = e.kind == "shield"
	var col := Color("54e0ff") if shield else Color("ff4fd8")
	var spinner := Node3D.new()
	spinner.position = Vector3(e.x, e.y, 0.0)
	root.add_child(spinner)
	_ball(spinner, 0.45, Vector3.ZERO, _mat("orb_" + e.kind, col, 0.2, 1.8))
	_torus(spinner, 0.62, 0.7, Vector3.ZERO, _mat("orbring_" + e.kind, Color.WHITE, 0.3, 1.5), Vector3(0.4, 0.0, 0.0))
	if not shield:
		# horseshoe hint: two little bars
		for s in [-1.0, 1.0]:
			_box(spinner, Vector3(0.12, 0.4, 0.12), Vector3(s * 0.2, -0.05, 0.42), _mat("magtip", Color("e8e8f0"), 0.3, 0.8))
	e["spinner"] = spinner


## Halloween coin: a glowing mini pumpkin (2 surfaces: body + stem).
func _make_pumpkin_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var lobe := SphereMesh.new()
		lobe.radius = 0.24
		lobe.height = 0.44
		lobe.radial_segments = 10
		lobe.rings = 6
		var a := TAU * k / 5.0
		st.append_from(lobe, 0, Transform3D(Basis.IDENTITY.scaled(Vector3(0.75, 1.0, 0.75)), Vector3(cos(a) * 0.14, 0.0, sin(a) * 0.14)))
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.03
	stem.bottom_radius = 0.05
	stem.height = 0.16
	stem.radial_segments = 6
	stem.rings = 1
	st2.append_from(stem, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.26, 0.0)))
	st2.commit(mesh)
	var body := StandardMaterial3D.new()
	body.albedo_color = Color("ff7a1a")
	body.emission_enabled = true
	body.emission = Color("ff6a00")
	body.emission_energy_multiplier = 0.8
	body.next_pass = Toon.outline_mat(0.025)
	mesh.surface_set_material(0, body)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color("3d8f3a")
	mesh.surface_set_material(1, green)
	return mesh


## Christmas coin: a little present (box + golden ribbon).
func _make_gift_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.38, 0.42)
	st.append_from(box, 0, Transform3D.IDENTITY)
	st.commit(mesh)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sz in [Vector3(0.45, 0.4, 0.09), Vector3(0.09, 0.4, 0.45)]:
		var r := BoxMesh.new()
		r.size = sz
		st2.append_from(r, 0, Transform3D.IDENTITY)
	var bow := TorusMesh.new()
	bow.inner_radius = 0.05
	bow.outer_radius = 0.11
	bow.rings = 10
	bow.ring_segments = 6
	st2.append_from(bow, 0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, 0.24, 0.0)))
	st2.commit(mesh)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("e8202e")
	red.emission_enabled = true
	red.emission = Color("ff2030")
	red.emission_energy_multiplier = 0.5
	red.next_pass = Toon.outline_mat(0.025)
	mesh.surface_set_material(0, red)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffd23f")
	gold.emission_enabled = true
	gold.emission = Color("ffb000")
	gold.emission_energy_multiplier = 0.8
	mesh.surface_set_material(1, gold)
	return mesh


## Festive string of lights hanging across the river.
func _spawn_garland(z: float) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(0.0, 0.0, z)
	level_root.add_child(g)
	var halloween: bool = theme.season == "halloween"
	var cable := _mat("garland_cable", Color("1e1b2e"), 0.5, 0.0, 0.0)
	var n := 9
	var prev := Vector3(-LevelGen.RIVER_W * 0.5 - 0.5, 8.6, 0.0)
	for k in n:
		var u := float(k) / (n - 1)
		var x := lerpf(-LevelGen.RIVER_W * 0.5 - 0.5, LevelGen.RIVER_W * 0.5 + 0.5, u)
		var y := 8.6 - sin(u * PI) * 1.3
		var p := Vector3(x, y, 0.0)
		if k > 0:
			var mid := (prev + p) * 0.5
			_box(g, Vector3(prev.distance_to(p), 0.04, 0.04), mid, cable, Vector3(0.0, 0.0, atan2(p.y - prev.y, p.x - prev.x)))
		prev = p
		if k == 0 or k == n - 1:
			continue
		if halloween:
			if k % 2 == 0:
				_ball(g, 0.32, p + Vector3(0.0, -0.45, 0.0), _mat("g_pumpkin", Color("ff7a1a"), 0.5, 1.6, 0.03), Vector3(1.2, 0.9, 1.2))
				_box(g, Vector3(0.14, 0.08, 0.05), p + Vector3(0.0, -0.45, -0.38), _mat("g_face", Color("fff1a0"), 0.3, 4.0, 0.0))
			else:
				_box(g, Vector3(0.7, 0.05, 0.25), p + Vector3(0.0, -0.3, 0.0), _mat("g_bat", Color("2a1040"), 0.5, 0.0, 0.02), Vector3(0.0, 0.0, 0.25 if k % 4 == 1 else -0.25))
		else:
			var cols := [Color("ff3d3d"), Color("3dff7a"), Color("ffd23f"), Color("4ea8ff")]
			_ball(g, 0.16, p + Vector3(0.0, -0.18, 0.0), _mat("g_bulb%d" % (k % 4), cols[k % 4], 0.3, 3.0, 0.0))
			if k == 4:
				var star := PrismMesh.new()
				star.size = Vector3(0.6, 0.6, 0.1)
				_mi(g, star, _mat("g_star", Color("ffd23f"), 0.3, 3.0, 0.02), p + Vector3(0.0, 0.4, 0.0))
	return g


## One merged mesh per coin (1 draw call): disc + raised rim + embossed centre.
func _make_coin_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var upright := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var body := CylinderMesh.new()
	body.top_radius = 0.36
	body.bottom_radius = 0.36
	body.height = 0.08
	body.radial_segments = 28
	body.rings = 1
	st.append_from(body, 0, upright)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.31
	rim.outer_radius = 0.41
	rim.rings = 28
	rim.ring_segments = 8
	st.append_from(rim, 0, upright)
	var face := CylinderMesh.new()
	face.top_radius = 0.19
	face.bottom_radius = 0.21
	face.height = 0.13
	face.radial_segments = 20
	face.rings = 1
	st.append_from(face, 0, upright)
	return st.commit()


## Finish: a neon warp arch, and a holo-crate that opens when you win.
func _spawn_finish(z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, z)
	level_root.add_child(root)
	var neon := _mat("gate_neon", theme.get("neon", Color("ff2fd0")), 0.2, 3.2, 0.03)
	var neon2 := _mat("gate_neon2", theme.get("neon2", Color("00e5ff")), 0.2, 3.2, 0.03)
	var metal := _mat("gate_metal", theme.get("metal", Color("3a3f6a")), 0.5)
	var r := LevelGen.RIVER_W * 0.5 + 0.9
	var base_y := 0.2
	var segs := 14
	for k in segs:
		var a0 := PI * k / segs
		var a1 := PI * (k + 1) / segs
		var p0 := Vector3(cos(a0) * r, base_y + sin(a0) * r * 1.25, 0.0)
		var p1 := Vector3(cos(a1) * r, base_y + sin(a1) * r * 1.25, 0.0)
		var mid := (p0 + p1) * 0.5
		var length := p0.distance_to(p1) + 0.05
		var ang := atan2(p1.y - p0.y, p1.x - p0.x)
		_box(root, Vector3(length, 0.7, 1.0), mid, metal, Vector3(0.0, 0.0, ang))
		_box(root, Vector3(length, 0.14, 1.06), mid + Vector3(0.0, 0.0, 0.0), neon if k % 2 == 0 else neon2, Vector3(0.0, 0.0, ang))
	for s in [-1.0, 1.0]:
		var x: float = s * r
		_box(root, Vector3(1.0, 1.4 - LevelGen.FLOOR_Y, 1.4), Vector3(x, (LevelGen.FLOOR_Y + 1.2) * 0.5, 0.0), metal)
		_box(root, Vector3(0.1, 1.0, 1.45), Vector3(x - s * 0.5, 0.7, 0.0), neon2)
	# FINISH holo strip
	for k in 10:
		var bx := lerpf(-LevelGen.RIVER_W * 0.5 + 0.9, LevelGen.RIVER_W * 0.5 - 0.9, k / 9.0)
		var sq := _box(root, Vector3(0.62, 0.6, 0.05), Vector3(bx, r * 1.25 - 0.6, 0.0), _fx_mat("chk_a", Color(1, 1, 1, 0.85), 2.0) if k % 2 == 0 else _fx_mat("chk_b", Color(0.05, 0.05, 0.15, 0.7)))
		sq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# holo crate on a hover pad (floats on the tide, opens when you win)
	raft = Node3D.new()
	raft.position = Vector3(-2.4, 0.0, z + 9.0)
	level_root.add_child(raft)
	_cone(raft, 1.1, 1.1, 0.16, Vector3(0.0, 0.08, 0.0), metal, 8)
	_torus(raft, 1.0, 1.15, Vector3(0.0, 0.1, 0.0), neon2)
	var crate := _mat("crate", Color("20223a"), 0.5)
	var gold := _mat("gold", Color("ffc531"), 0.3, 1.5)
	_box(raft, Vector3(0.9, 0.5, 0.65), Vector3(0.0, 0.45, 0.0), crate)
	_box(raft, Vector3(0.95, 0.06, 0.7), Vector3(0.0, 0.45, 0.0), gold)
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0.0, 0.7, -0.32)
	raft.add_child(chest_lid)
	_box(chest_lid, Vector3(0.9, 0.2, 0.65), Vector3(0.0, 0.1, 0.32), crate)
	_box(chest_lid, Vector3(0.95, 0.05, 0.7), Vector3(0.0, 0.19, 0.32), neon)


# ------------------------------------------------------------------ canyon & decoration

func _spawn_ambient() -> void:
	var kind: String = theme.particles
	if kind == "":
		return
	ambient = CPUParticles3D.new()
	ambient.local_coords = false
	ambient.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ambient.emission_box_extents = Vector3(7.0, 4.0, 30.0)
	ambient.amount = 70
	ambient.lifetime = 4.0
	var dot := SphereMesh.new()
	dot.radius = 0.06
	dot.height = 0.12
	dot.radial_segments = 6
	dot.rings = 3
	ambient.mesh = dot
	var g := Gradient.new()
	match kind:
		"fireflies":
			g.set_color(0, Color(0.8, 1.0, 0.5, 0.0))
			g.set_color(1, Color(0.8, 1.0, 0.5, 0.0))
			g.add_point(0.5, Color(0.85, 1.0, 0.55, 1.0))
			ambient.gravity = Vector3.ZERO
			ambient.initial_velocity_max = 0.4
			ambient.spread = 180.0
			ambient.material_override = _fx_mat("amb_ff", Color.WHITE, 3.0)
		"motes":
			var mc: Color = theme.get("neon2", Color("00e5ff"))
			g.set_color(0, Color(mc, 0.0))
			g.set_color(1, Color(mc, 0.0))
			g.add_point(0.5, Color(mc, 1.0))
			ambient.gravity = Vector3(0.0, 0.3, 0.0)
			ambient.initial_velocity_max = 0.3
			ambient.spread = 180.0
			ambient.material_override = _fx_mat("amb_mote", Color.WHITE, 3.0)
		"bats":
			g.set_color(0, Color(0.15, 0.05, 0.25, 0.0))
			g.set_color(1, Color(0.15, 0.05, 0.25, 0.0))
			g.add_point(0.5, Color(0.15, 0.05, 0.25, 1.0))
			var bat := BoxMesh.new()
			bat.size = Vector3(0.45, 0.04, 0.16)
			ambient.mesh = bat
			ambient.amount = 30
			ambient.gravity = Vector3.ZERO
			ambient.initial_velocity_min = 1.0
			ambient.initial_velocity_max = 2.5
			ambient.spread = 180.0
			ambient.angular_velocity_min = -200.0
			ambient.angular_velocity_max = 200.0
			ambient.material_override = _fx_mat("amb_bat", Color.WHITE)
		"stars":
			g.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
			g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
			g.add_point(0.5, Color(0.8, 0.9, 1.0, 1.0))
			ambient.gravity = Vector3.ZERO
			ambient.material_override = _fx_mat("amb_star", Color.WHITE, 3.0)
		"snow":
			g.set_color(0, Color(1.0, 1.0, 1.0, 0.9))
			g.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
			ambient.gravity = Vector3(0.3, -1.2, 0.0)
			ambient.material_override = _fx_mat("amb_snow", Color.WHITE)
		"embers":
			g.set_color(0, Color(1.0, 0.6, 0.2, 1.0))
			g.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
			ambient.gravity = Vector3(0.0, 1.0, 0.0)
			ambient.material_override = _fx_mat("amb_emb", Color.WHITE, 3.0)
	ambient.color_ramp = g
	level_root.add_child(ambient)


# ================================================================== per frame

func update(delta: float, run_t: float, t: float, water_y: float, boat_z: float, holding: bool) -> void:
	water.position = Vector3(0.0, water_y, boat_z + 70.0)
	moon.position = Vector3(-8.0, 15.0 + (water_y - LevelGen.WATER_MIN) * 2.8, boat_z + 78.0)
	moon.rotation.y = t * 0.05
	var glow := 2.6 if holding else 1.3
	moon_mat.emission_energy_multiplier = lerpf(moon_mat.emission_energy_multiplier, glow, 1.0 - exp(-6.0 * delta))
	if ambient:
		ambient.position = Vector3(0.0, water_y + 3.0, boat_z + 22.0)
	if raft:
		raft.position.y = water_y + sin(t * 1.7) * 0.05
		raft.rotation.z = sin(t * 1.3) * 0.04

	_stream(boat_z)
	if boss:
		_update_boss(delta, t, water_y, boat_z)
	var near := boat_z - 25.0
	var far := boat_z + 110.0
	for i in range(maxi(_next_item - 60, 0), _next_item):
		var e: Dictionary = items[i]
		var z: float = e.z
		if z < near or z > far or not e.has("node") or e.get("gone", false):
			continue
		match e.kind:
			"slider", "sweeper":
				var mvr: Node3D = e.mover
				if e.kind == "slider":
					mvr.position.x = float(e.gx) + float(e.amp) * LevelGen.wave(e, run_t)
				else:
					mvr.position.x = float(e.amp) * LevelGen.wave(e, run_t)
			"mines":
				if not e.get("smashed", false):
					var ms: Node3D = e.spinner
					for orb in ms.get_children():
						if not (orb is MeshInstance3D):
							(orb as Node3D).rotation.z += delta * 2.5
							(orb as Node3D).position.y = LevelGen.WATER_REST + 0.7 + sin(t * 3.0 + z + (orb as Node3D).position.x) * 0.12
			"ramp":
				(e.pad as Node3D).position.y = water_y
			"geyser", "vortex":
				var pd: Node3D = e.pad
				pd.position.y = water_y
				pd.rotation.y += delta * (1.5 if e.kind == "geyser" else -3.0)
			"boost", "slow", "shield", "magnet":
				if not e.taken:
					var sp: Node3D = e.spinner
					sp.rotation.z += delta * (3.0 if e.kind == "boost" else 1.2)
					if e.kind == "shield" or e.kind == "magnet":
						sp.rotation.y += delta * 2.0
						sp.position.y = float(e.y) + sin(t * 2.5 + z) * 0.1


	for i in range(maxi(_next_pearl - 120, 0), _next_pearl):
		var p: Dictionary = pearls[i]
		if p.taken or not p.has("node") or p.get("gone", false):
			continue
		var pz: float = p.z
		if pz < near or pz > far:
			continue
		var n: Node3D = p.node
		n.rotation.y += delta * 3.2
		n.position.y = float(p.y) + sin(t * 3.0 + pz) * 0.12


# ================================================================== boss

## The world's boss: a neon mothership that flies ahead of you. Every obstacle
## you pass fires your boat's laser at it.
func _spawn_boss() -> void:
	boss = Node3D.new()
	level_root.add_child(boss)
	boss_alive = true
	var hull := _mat("boss_hull", Color("1b1530"), 0.5, 0.0, 0.05)
	var plate := _mat("boss_plate", theme.get("metal", Color("3a3f6a")), 0.5, 0.0, 0.04)
	var neon := _mat("boss_neon", theme.get("neon", Color("ff2fd0")), 0.2, 3.5, 0.0)
	var neon2 := _mat("boss_neon2", theme.get("neon2", Color("00e5ff")), 0.2, 3.5, 0.0)
	_ball(boss, 2.6, Vector3.ZERO, hull, Vector3(1.6, 0.45, 1.25))
	_ball(boss, 1.5, Vector3(0.0, 0.75, 0.2), plate, Vector3(1.2, 0.6, 1.0))
	_torus(boss, 3.9, 4.25, Vector3(0.0, -0.05, 0.0), neon)
	_torus(boss, 2.0, 2.2, Vector3(0.0, -0.9, 0.0), neon2)
	for sx in [-1.0, 1.0]:
		_box(boss, Vector3(2.4, 0.25, 1.2), Vector3(sx * 4.6, 0.0, 0.3), plate, Vector3(0.0, 0.0, sx * -0.25))
		_cone(boss, 0.35, 0.25, 1.8, Vector3(sx * 2.6, -0.6, -1.6), plate, 8, Vector3(PI * 0.5, 0.0, 0.0))
		_ball(boss, 0.3, Vector3(sx * 2.6, -0.6, -2.55), neon)
	boss_eye_mat = StandardMaterial3D.new()
	boss_eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	boss_eye_mat.albedo_color = Color("ff3d5a")
	_ball(boss, 0.85, Vector3(0.0, -0.15, -3.1), boss_eye_mat, Vector3(1.3, 0.7, 0.6))
	var lights := CPUParticles3D.new()
	lights.amount = 30
	lights.lifetime = 0.8
	lights.position = Vector3(0.0, -1.1, 0.0)
	lights.direction = Vector3.DOWN
	lights.spread = 25.0
	lights.initial_velocity_min = 3.0
	lights.initial_velocity_max = 5.0
	var lm := SphereMesh.new()
	lm.radius = 0.1
	lm.height = 0.2
	lm.radial_segments = 4
	lm.rings = 2
	lights.mesh = lm
	lights.material_override = _fx_mat("boss_exhaust", Color(theme.get("neon2", Color("00e5ff")), 0.8), 3.0)
	boss.add_child(lights)
	var bm := CylinderMesh.new()
	bm.top_radius = 0.09
	bm.bottom_radius = 0.09
	bm.height = 1.0
	bm.radial_segments = 6
	bm.rings = 1
	boss_beam = MeshInstance3D.new()
	boss_beam.mesh = bm
	boss_beam.material_override = _fx_mat("boss_beam", Color(0.4, 1.0, 1.0, 0.9), 4.0)
	boss_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boss_beam.visible = false
	level_root.add_child(boss_beam)


func _update_boss(delta: float, t: float, water_y: float, boat_z: float) -> void:
	if boss_alive:
		boss.position = Vector3(sin(t * 0.7) * 1.6, 9.5 + water_y * 0.3 + sin(t * 1.3) * 0.5, boat_z + 26.0)
		boss.rotation = Vector3(0.08, sin(t * 0.5) * 0.15, sin(t * 0.7) * -0.08)
		boss_eye_mat.albedo_color = boss_eye_mat.albedo_color.lerp(Color("ff3d5a"), 1.0 - exp(-6.0 * delta))
		boss_fire_t -= delta
		if boss_fire_t <= 0.0:
			# warning shot into the river ahead (just for show)
			boss_fire_t = randf_range(1.8, 3.2)
			var hit := Vector3(randf_range(-3.0, 3.0), water_y, boat_z + randf_range(10.0, 18.0))
			_show_beam(boss.global_position + Vector3(0.0, -0.3, -3.0), hit, Color("ff3d5a"))
			burst_splash(hit)
	if boss_beam and boss_beam.visible:
		boss_beam_t -= delta
		if boss_beam_t <= 0.0:
			boss_beam.visible = false


func _show_beam(from: Vector3, to: Vector3, col: Color) -> void:
	if boss_beam == null:
		return
	var mat := boss_beam.material_override as StandardMaterial3D
	mat.albedo_color = Color(col, 0.9)
	mat.emission = col
	var mid := (from + to) * 0.5
	var length := from.distance_to(to)
	boss_beam.global_position = mid
	var dir := (to - from).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.99 else Vector3.RIGHT).normalized()
	var fwd := side.cross(dir).normalized()
	boss_beam.global_basis = Basis(side, dir * length, fwd)
	boss_beam.visible = true
	boss_beam_t = 0.14


## Your laser hits the boss.
func boss_hit(from: Vector3, final_hit: bool) -> void:
	if not boss_alive or boss == null:
		return
	_show_beam(from, boss.global_position, Color("54e0ff"))
	boss_eye_mat.albedo_color = Color.WHITE
	sparkle.global_position = boss.global_position + Vector3(0.0, -0.4, -2.5)
	sparkle.restart()
	var tw := create_tween()
	tw.tween_property(boss, "scale", Vector3(1.12, 0.9, 1.12), 0.06)
	tw.tween_property(boss, "scale", Vector3.ONE, 0.18)
	if final_hit:
		boss_eye_mat.albedo_color = Color("ffd166")


func boss_explode() -> void:
	if boss == null or not boss_alive:
		return
	boss_alive = false
	burst_confetti(boss.global_position)
	burst_splash(boss.global_position)
	var tw := create_tween()
	tw.tween_property(boss, "scale", Vector3(1.6, 1.6, 1.6), 0.12)
	tw.tween_property(boss, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(boss.hide)


# ================================================================== events

func burst_splash(pos: Vector3) -> void:
	splash.global_position = pos
	splash.restart()


func burst_confetti(pos: Vector3) -> void:
	confetti.global_position = pos
	confetti.restart()


func open_chest() -> void:
	if chest_lid:
		create_tween().tween_property(chest_lid, "rotation:x", -1.9, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shield hit: the obstacle shatters out of the way.
func smash(e: Dictionary) -> void:
	e["smashed"] = true
	if not e.has("node") or e.get("gone", false):
		return
	var n: Node3D = e.node
	burst_splash(n.global_position + Vector3(0.0, 1.0, 0.0))
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(1.2, 0.01, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.hide)


func take_pickup(e: Dictionary) -> void:
	e.taken = true
	if not e.has("spinner") or e.get("gone", false):
		return
	var sp: Node3D = e.spinner
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sp, "scale", Vector3(2.0, 2.0, 2.0), 0.25)
	tw.chain().tween_property(sp, "scale", Vector3.ZERO, 0.15)
	tw.chain().tween_callback(sp.hide)


func take_pearl(p: Dictionary, to: Vector3) -> void:
	p.taken = true
	if not p.has("node") or p.get("gone", false):
		return
	sparkle.global_position = (p.node as Node3D).global_position
	sparkle.restart()
	var n: Node3D = p.node
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", to, 0.18)
	tw.tween_property(n, "scale", Vector3(0.2, 0.2, 0.2), 0.18)
	tw.chain().tween_callback(n.hide)
