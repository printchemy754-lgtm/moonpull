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
var level_root: Node3D
var splash: CPUParticles3D
var confetti: CPUParticles3D
var ambient: CPUParticles3D
var raft: Node3D
var chest_lid: Node3D

var items: Array[Dictionary] = []
var pearls: Array[Dictionary] = []
var finish_z := 100.0

var rng := RandomNumberGenerator.new()
var _mats := {}
var _pearl_mesh: SphereMesh
var _fall_shader: Shader


func _ready() -> void:
	_setup_environment()
	_build_water()
	_build_moon()
	splash = _burst_particles(48, 0.9, Vector3(0.0, -14.0, 0.0), 3.0, 7.5, 0.12, false)
	confetti = _burst_particles(90, 2.2, Vector3(0.0, -5.0, 0.0), 5.0, 10.0, 0.09, true)
	level_root = Node3D.new()
	add_child(level_root)
	_pearl_mesh = SphereMesh.new()
	_pearl_mesh.radius = 0.3
	_pearl_mesh.height = 0.6
	_pearl_mesh.radial_segments = 14
	_pearl_mesh.rings = 7
	_fall_shader = load("res://shaders/fall.gdshader")


# ================================================================== building

func build_level(data: Dictionary, level: int) -> void:
	for c in level_root.get_children():
		c.queue_free()
	ambient = null
	raft = null
	chest_lid = null
	_mats.clear()
	theme = Themes.for_level(level)
	_apply_theme()
	rng.seed = level * 31 + 7
	items = []
	for it in data.items:
		var e: Dictionary = it.duplicate()
		items.append(e)
		_spawn_item(e)
	pearls = []
	for pos in data.pearls:
		_spawn_pearl(pos)
	finish_z = data.finish
	_spawn_finish(finish_z)
	_spawn_canyon(finish_z + 90.0)
	_spawn_ambient()


func _mat(key: String, color: Color, rough := 0.9, glow := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
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
	moon_mat.albedo_color = theme.moon
	moon_mat.emission = theme.moon


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
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)
	# a few craters
	var crater := StandardMaterial3D.new()
	crater.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crater.albedo_color = Color(0.85, 0.82, 0.75)
	crater.set("disable_fog", true)
	for c in [Vector3(-1.2, 1.0, -3.6), Vector3(1.4, -0.6, -3.65), Vector3(0.2, -1.8, -3.5), Vector3(-1.8, -1.2, -3.3)]:
		var cr := _ball(moon, 0.55, c, crater, Vector3(1.0, 1.0, 0.3))
		cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
		"reef":
			_build_reef(root, e.h)
			e["foam"] = _foam(root)
		"bridge":
			_build_bridge(root, e.b)
		"gate":
			_build_reef(root, e.h)
			_build_bridge(root, e.b)
			e["foam"] = _foam(root)
		"breather":
			var mover := Node3D.new()
			root.add_child(mover)
			_build_reef(mover, e.h + e.amp, 3.6)
			e["mover"] = mover
			e["foam"] = _foam(root)
		"drawbridge":
			_build_drawbridge(root, e)
		"boost", "slow":
			_build_ring(root, e)
		"shield", "magnet":
			_build_orb(root, e)


func _foam(root: Node3D) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(LevelGen.RIVER_W + 0.6, 2.2)
	var mi := _mi(root, pm, _fx_mat("foam", Color(1.0, 1.0, 1.0, 0.55)), Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


func _build_reef(root: Node3D, h: float, extra_depth := 0.0) -> void:
	var rock := _mat("rock", theme.rock, 0.95)
	var tip := _mat("rock_tip", theme.rock_tip, 0.9, theme.tip_glow)
	var bottom := LevelGen.FLOOR_Y - extra_depth
	var base_top := maxf(h * 0.55, 0.25)
	var base_h := base_top - bottom
	_box(root, Vector3(LevelGen.RIVER_W + 0.4, base_h, 1.2), Vector3(0.0, bottom + base_h * 0.5, 0.0), rock)
	var spikes := 6
	var icy: bool = theme.deco == "ice"
	for i in spikes:
		var x := lerpf(-LevelGen.RIVER_W * 0.5 + 0.6, LevelGen.RIVER_W * 0.5 - 0.6, float(i) / (spikes - 1))
		var top := h if i % 2 == 0 else h * rng.randf_range(0.8, 0.96)  # tallest spikes are exactly h
		var height := top - bottom
		var spike := _cone(root, rng.randf_range(0.6, 0.85), 0.04 if icy else 0.09, height,
			Vector3(x, bottom + height * 0.5, rng.randf_range(-0.2, 0.2)),
			tip if i % 2 == 0 else rock, 4 if icy else 6)
		spike.rotation.y = rng.randf() * TAU
	# small rubble for detail
	for i in 3:
		_ball(root, rng.randf_range(0.25, 0.45), Vector3(rng.randf_range(-3.5, 3.5), base_top, rng.randf_range(-0.6, 0.6)), rock, Vector3(1.0, 0.6, 1.0))


func _build_bridge(root: Node3D, b: float) -> void:
	var wood := _mat("wood", theme.wood, 0.85)
	var dark := _mat("wood_dark", theme.wood_dark, 0.9)
	var lamp := _mat("lamp", theme.lamp, 0.5, 2.4)
	var span := LevelGen.RIVER_W + 2.6
	for s in [-1.0, 1.0]:
		var ph := b - LevelGen.FLOOR_Y
		_box(root, Vector3(0.8, ph, 0.9), Vector3(s * (LevelGen.RIVER_W * 0.5 + 0.5), LevelGen.FLOOR_Y + ph * 0.5, 0.0), dark)
	_deck(root, b, span, wood, dark, lamp)
	if theme.deco == "palm":
		var vine := _mat("vine", Color("3f8f3f"), 0.9)
		for k in 4:
			var vx := rng.randf_range(-3.2, 3.2)
			var vl := rng.randf_range(0.2, 0.45)
			_box(root, Vector3(0.06, vl, 0.06), Vector3(vx, b - vl * 0.5, rng.randf_range(-0.5, 0.5)), vine)


## A bridge deck whose underside sits at local height `y`.
func _deck(root: Node3D, y: float, span: float, wood: Material, dark: Material, lamp: Material) -> void:
	_box(root, Vector3(span, 0.5, 1.4), Vector3(0.0, y + 0.25, 0.0), wood)
	_box(root, Vector3(span, 0.1, 1.5), Vector3(0.0, y + 0.05, 0.0), dark)
	for rz in [-0.62, 0.62]:
		_box(root, Vector3(span, 0.1, 0.1), Vector3(0.0, y + 0.95, rz), wood)
		for k in 7:
			_box(root, Vector3(0.1, 0.45, 0.1), Vector3(lerpf(-span * 0.5 + 0.3, span * 0.5 - 0.3, k / 6.0), y + 0.72, rz), dark)
	for s in [-1.0, 1.0]:
		_box(root, Vector3(0.25, 0.35, 0.25), Vector3(s * (LevelGen.RIVER_W * 0.5 - 0.3), y + 0.75, 0.0), lamp)


func _build_drawbridge(root: Node3D, e: Dictionary) -> void:
	var wood := _mat("wood", theme.wood, 0.85)
	var dark := _mat("wood_dark", theme.wood_dark, 0.9)
	var lamp := _mat("lamp", theme.lamp, 0.5, 2.4)
	var stone := _mat("tower", theme.rock.lightened(0.25), 0.9)
	var top: float = e.b + 2.2
	for s in [-1.0, 1.0]:
		var th := top - LevelGen.FLOOR_Y
		_box(root, Vector3(1.2, th, 1.6), Vector3(s * (LevelGen.RIVER_W * 0.5 + 0.8), LevelGen.FLOOR_Y + th * 0.5, 0.0), stone)
		_cone(root, 0.95, 0.0, 1.2, Vector3(s * (LevelGen.RIVER_W * 0.5 + 0.8), top + 0.6, 0.0), _mat("roof", Color("c0392b"), 0.8), 4)
		_box(root, Vector3(0.3, 0.3, 0.3), Vector3(s * (LevelGen.RIVER_W * 0.5 + 0.2), top - 0.4, 0.0), lamp)
	var mover := Node3D.new()
	root.add_child(mover)
	_deck(mover, 0.0, LevelGen.RIVER_W - 0.2, wood, dark, lamp)
	# warning stripes under the deck
	for k in 8:
		var col := Color("ffd23f") if k % 2 == 0 else Color("1e1b2e")
		_box(mover, Vector3(0.95, 0.06, 1.42), Vector3(lerpf(-3.4, 3.4, k / 7.0), -0.01, 0.0), _mat("stripe%d" % (k % 2), col, 0.7))
	e["mover"] = mover
	var chains: Array[MeshInstance3D] = []
	for s in [-1.0, 1.0]:
		var c := _box(root, Vector3(0.08, 1.0, 0.08), Vector3(s * (LevelGen.RIVER_W * 0.5 - 0.4), 0.0, 0.0), _mat("chain", Color("2a2a33"), 0.4))
		chains.append(c)
	e["chains"] = chains
	e["chain_top"] = top - 0.3


func _build_ring(root: Node3D, e: Dictionary) -> void:
	var boost: bool = e.kind == "boost"
	var col := Color("ffc531") if boost else Color("8fd8ff")
	var spinner := Node3D.new()
	spinner.position = Vector3(0.0, e.y, 0.0)
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
	spinner.position = Vector3(0.0, e.y, 0.0)
	root.add_child(spinner)
	_ball(spinner, 0.45, Vector3.ZERO, _mat("orb_" + e.kind, col, 0.2, 1.8))
	_torus(spinner, 0.62, 0.7, Vector3.ZERO, _mat("orbring_" + e.kind, Color.WHITE, 0.3, 1.5), Vector3(0.4, 0.0, 0.0))
	if not shield:
		# horseshoe hint: two little bars
		for s in [-1.0, 1.0]:
			_box(spinner, Vector3(0.12, 0.4, 0.12), Vector3(s * 0.2, -0.05, 0.42), _mat("magtip", Color("e8e8f0"), 0.3, 0.8))
	e["spinner"] = spinner


func _spawn_pearl(pos: Vector3) -> void:
	var mi := _mi(level_root, _pearl_mesh, _mat("pearl", Color("fff4e6"), 0.15, 1.2), pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pearls.append({"node": mi, "y": pos.y, "z": pos.z, "taken": false})


func _spawn_finish(z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, z)
	level_root.add_child(root)
	var red := _mat("lh_red", Color("e2463f"), 0.7)
	var white := _mat("lh_white", Color("f6f2ea"), 0.7)
	var light := _mat("lh_light", Color("fff1b0"), 0.3, 4.0)
	for s in [-1.0, 1.0]:
		var x: float = s * (LevelGen.RIVER_W * 0.5 + 0.2)
		for k in 7:
			_cone(root, 0.75 - k * 0.04, 0.71 - k * 0.04, 1.4, Vector3(x, LevelGen.FLOOR_Y + 0.7 + k * 1.4, 0.0), red if k % 2 == 0 else white, 10)
		_cone(root, 0.5, 0.5, 0.8, Vector3(x, LevelGen.FLOOR_Y + 10.2, 0.0), light, 10)
		_cone(root, 0.6, 0.0, 0.7, Vector3(x, LevelGen.FLOOR_Y + 10.95, 0.0), red, 10)
	for k in 10:
		var bx := lerpf(-LevelGen.RIVER_W * 0.5 + 0.9, LevelGen.RIVER_W * 0.5 - 0.9, k / 9.0)
		_box(root, Vector3(0.62, 0.6, 0.1), Vector3(bx, 8.2, 0.0), white if k % 2 == 0 else _mat("ink", Color("1e1b2e"), 0.8))
	# treasure raft (floats on the tide, opens when you win)
	raft = Node3D.new()
	raft.position = Vector3(-2.4, 0.0, z + 9.0)
	level_root.add_child(raft)
	var wood := _mat("raftwood", Color("8b5a3c"), 0.9)
	for k in 4:
		_cone(raft, 0.22, 0.22, 2.2, Vector3(-0.66 + k * 0.44, 0.05, 0.0), wood, 8, Vector3(PI * 0.5, 0.0, 0.0))
	var gold := _mat("gold", Color("ffc531"), 0.3, 0.6)
	_box(raft, Vector3(0.9, 0.5, 0.65), Vector3(0.0, 0.5, 0.0), _mat("chest", Color("8b4a25"), 0.8))
	_box(raft, Vector3(0.95, 0.08, 0.7), Vector3(0.0, 0.5, 0.0), gold)
	chest_lid = Node3D.new()
	chest_lid.position = Vector3(0.0, 0.75, -0.32)
	raft.add_child(chest_lid)
	_box(chest_lid, Vector3(0.9, 0.22, 0.65), Vector3(0.0, 0.11, 0.32), _mat("chest", Color("8b4a25"), 0.8))
	_box(chest_lid, Vector3(0.95, 0.06, 0.7), Vector3(0.0, 0.2, 0.32), gold)


# ------------------------------------------------------------------ canyon & decoration

func _spawn_canyon(length: float) -> void:
	var cols: Array = theme.walls
	var z := -40.0
	while z < length:
		var seg := rng.randf_range(6.0, 11.0)
		for s in [-1.0, 1.0]:
			var top := rng.randf_range(7.2, 9.4)
			var hgt := top - LevelGen.FLOOR_Y + 1.0
			var col: Color = cols[rng.randi() % cols.size()]
			var inset := rng.randf_range(0.0, 0.6)
			var inner: float = s * (LevelGen.RIVER_W * 0.5 + 1.0 + inset)
			var m := _mat("wall_" + col.to_html(), col, 0.95)
			_box(level_root, Vector3(30.0, hgt, seg + 0.02), Vector3(inner + s * 15.0, LevelGen.FLOOR_Y - 1.0 + hgt * 0.5, z + seg * 0.5), m)
			# ledge detail
			var ledge_y := rng.randf_range(1.5, top - 1.5)
			_box(level_root, Vector3(0.5, 0.35, seg * rng.randf_range(0.4, 0.9)), Vector3(inner - s * 0.15, ledge_y, z + seg * 0.5), _mat("wall_" + col.darkened(0.15).to_html(), col.darkened(0.15), 0.95))
			if rng.randf() < 0.5:
				_deco(Vector3(s * rng.randf_range(LevelGen.RIVER_W * 0.5 + 2.6, LevelGen.RIVER_W * 0.5 + 10.0), top, z + rng.randf_range(0.0, seg)))
			if theme.deco == "ice":
				_box(level_root, Vector3(30.0, 0.25, seg + 0.02), Vector3(inner + s * 15.0, top + 0.1, z + seg * 0.5), _mat("snow", Color("ffffff"), 0.8))
			if rng.randf() < 0.1 and z > 10.0:
				_waterfall(inner - s * 0.06, top, z + seg * 0.5, s)
		z += seg
	_box(level_root, Vector3(LevelGen.RIVER_W + 4.0, 1.0, length + 60.0),
		Vector3(0.0, LevelGen.FLOOR_Y - 0.5, (length - 40.0) * 0.5 - 10.0), _mat("floor", theme.floor, 1.0))


func _waterfall(x: float, top: float, z: float, side: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(1.5, top - LevelGen.FLOOR_Y)
	var sm := ShaderMaterial.new()
	sm.shader = _fall_shader
	sm.set_shader_parameter("color", theme.fall)
	sm.set_shader_parameter("glow", theme.fall_glow)
	var mi := _mi(level_root, q, sm, Vector3(x, LevelGen.FLOOR_Y + (top - LevelGen.FLOOR_Y) * 0.5, z), Vector3(0.0, -side * PI * 0.5, 0.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _deco(base: Vector3) -> void:
	var a: Color = theme.deco_a
	var b: Color = theme.deco_b
	var sc := rng.randf_range(0.8, 1.4)
	match theme.deco:
		"pine":
			_cone(level_root, 0.18 * sc, 0.12 * sc, 0.8 * sc, base + Vector3(0.0, 0.4 * sc, 0.0), _mat("trunk", b))
			_cone(level_root, 0.95 * sc, 0.0, 1.6 * sc, base + Vector3(0.0, 1.4 * sc, 0.0), _mat("leaf", a), 7)
			_cone(level_root, 0.7 * sc, 0.0, 1.3 * sc, base + Vector3(0.0, 2.2 * sc, 0.0), _mat("leaf", a), 7)
		"mushroom":
			_cone(level_root, 0.12 * sc, 0.1 * sc, 0.9 * sc, base + Vector3(0.0, 0.45 * sc, 0.0), _mat("stem", Color("d8d0f0"), 0.8), 8)
			_ball(level_root, 0.55 * sc, base + Vector3(0.0, 0.95 * sc, 0.0), _mat("cap", a, 0.4, 1.8), Vector3(1.0, 0.45, 1.0))
		"palm":
			var lean := rng.randf_range(-0.3, 0.3)
			for k in 3:
				_cone(level_root, 0.15 * sc, 0.13 * sc, 0.8 * sc, base + Vector3(lean * k * 0.4, (0.4 + k * 0.75) * sc, 0.0), _mat("trunk", b), 7, Vector3(0.0, 0.0, -lean))
			var crown := base + Vector3(lean * 1.2, 2.4 * sc, 0.0)
			for k in 6:
				var ang := TAU * k / 6.0
				_box(level_root, Vector3(1.4 * sc, 0.06, 0.35 * sc), crown + Vector3(cos(ang), -0.15, sin(ang)) * 0.6 * sc, _mat("leaf", a), Vector3(0.0, -ang, -0.35))
		"ice":
			for k in 3:
				var hh := rng.randf_range(1.0, 2.6) * sc
				_cone(level_root, 0.35 * sc, 0.0, hh, base + Vector3(rng.randf_range(-0.6, 0.6), hh * 0.5, rng.randf_range(-0.6, 0.6)), _mat("icespike", b, 0.2, 0.3), 4)
		"crystal":
			for k in 3:
				var hc := rng.randf_range(0.8, 2.0) * sc
				_cone(level_root, 0.3 * sc, 0.05, hc, base + Vector3(rng.randf_range(-0.5, 0.5), hc * 0.5, rng.randf_range(-0.5, 0.5)), _mat("crystal", a, 0.3, 2.2), 5, Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)))


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

	var near := boat_z - 25.0
	var far := boat_z + 110.0
	for e in items:
		var z: float = e.z
		if z < near or z > far:
			continue
		match e.kind:
			"breather":
				var mv: Node3D = e.mover
				mv.position.y = LevelGen.h_at(e, run_t) - (float(e.h) + float(e.amp))
			"drawbridge":
				var dk: Node3D = e.mover
				var by := LevelGen.b_at(e, run_t)
				dk.position.y = by
				var top: float = e.chain_top
				for c in e.chains:
					var ch: MeshInstance3D = c
					var length := maxf(top - (by + 0.5), 0.05)
					ch.position.y = by + 0.5 + length * 0.5
					ch.scale = Vector3(1.0, length, 1.0)
			"boost", "slow", "shield", "magnet":
				if not e.taken:
					var sp: Node3D = e.spinner
					sp.rotation.z += delta * (3.0 if e.kind == "boost" else 1.2)
					if e.kind == "shield" or e.kind == "magnet":
						sp.rotation.y += delta * 2.0
						sp.position.y = float(e.y) + sin(t * 2.5 + z) * 0.1
		if e.has("foam") and not e.get("smashed", false):
			var foam: MeshInstance3D = e.foam
			var h := LevelGen.h_at(e, run_t)
			foam.visible = h > water_y - 0.15
			foam.position.y = water_y + 0.03

	for p in pearls:
		if p.taken:
			continue
		var pz: float = p.z
		if pz < near or pz > far:
			continue
		var n: Node3D = p.node
		n.rotation.y += delta * 2.0
		n.position.y = float(p.y) + sin(t * 3.0 + pz) * 0.12


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
	var n: Node3D = e.node
	burst_splash(n.global_position + Vector3(0.0, 1.0, 0.0))
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3(1.2, 0.01, 1.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.hide)


func take_pickup(e: Dictionary) -> void:
	e.taken = true
	var sp: Node3D = e.spinner
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sp, "scale", Vector3(2.0, 2.0, 2.0), 0.25)
	tw.chain().tween_property(sp, "scale", Vector3.ZERO, 0.15)
	tw.chain().tween_callback(sp.hide)


func take_pearl(p: Dictionary, to: Vector3) -> void:
	p.taken = true
	var n: Node3D = p.node
	var tw := create_tween().set_parallel(true)
	tw.tween_property(n, "position", to, 0.18)
	tw.tween_property(n, "scale", Vector3(0.2, 0.2, 0.2), 0.18)
	tw.chain().tween_callback(n.hide)
