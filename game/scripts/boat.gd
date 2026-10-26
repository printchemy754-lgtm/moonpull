class_name Boat
extends Node3D
## The player's boat: six procedural models + wake, spray, smoke, shield and magnet effects.
## All models fit inside the same hitbox (keel 0.3 below, mast-top 1.5 above the waterline).

const MODELS := [
	{"name": "DINGHY", "price": 0},
	{"name": "TUGBOAT", "price": 150},
	{"name": "SPEEDSTER", "price": 300},
	{"name": "LANTERN JUNK", "price": 500},
	{"name": "RUBBER DUCK", "price": 800},
	{"name": "MOON SKIFF", "price": 1200},
]

var pivot: Node3D
var model: Node3D
var flag: Node3D
var spin_parts: Array[Node3D] = []
var wake: CPUParticles3D
var spray: CPUParticles3D
var smoke: CPUParticles3D
var bubble: MeshInstance3D
var magnet_fx: MeshInstance3D
var index := -1
var _mats := {}


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	_build_wake()
	_build_spray()
	_build_bubble()
	_build_magnet()


static func count() -> int:
	return MODELS.size()


static func model_name(i: int) -> String:
	return MODELS[i].name


static func price(i: int) -> int:
	return MODELS[i].price


func set_model(i: int) -> void:
	if i == index and model != null:
		return
	index = i
	if model:
		model.queue_free()
	flag = null
	spin_parts.clear()
	smoke = null
	model = Node3D.new()
	pivot.add_child(model)
	match i:
		0: _dinghy()
		1: _tug()
		2: _speedster()
		3: _junk()
		4: _duck()
		5: _skiff()
		_: _dinghy()


## Called every frame. speed_factor ~ 1 normal, >1 boosted, 0 = stopped.
func tick(delta: float, t: float, water_vel: float, speed_factor: float, alive: bool) -> void:
	if alive:
		pivot.rotation.z = sin(t * 2.1) * 0.05
		pivot.rotation.x = lerpf(pivot.rotation.x, clampf(-water_vel * 0.05, -0.18, 0.18) - 0.03 * (speed_factor - 1.0), 1.0 - exp(-8.0 * delta))
		pivot.position.y = sin(t * 3.0) * 0.04
	if flag:
		flag.rotation.y = sin(t * 9.0) * 0.35
	for p in spin_parts:
		p.rotation.y += delta * 2.0
	var moving := alive and speed_factor > 0.05
	wake.emitting = moving
	spray.emitting = moving and speed_factor > 1.2
	if smoke:
		smoke.emitting = alive
	if bubble.visible:
		bubble.rotation.y += delta
		var s := 1.0 + sin(t * 4.0) * 0.03
		bubble.scale = Vector3(s, s, s)
	if magnet_fx.visible:
		magnet_fx.rotation.y += delta * 5.0


func reset_pose() -> void:
	pivot.rotation = Vector3.ZERO
	pivot.position = Vector3.ZERO
	visible = true


func crash() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pivot, "rotation", Vector3(-0.45, 0.3, 1.25), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "position", Vector3(0.0, -0.7, -0.6), 0.7)


func show_shield(on: bool) -> void:
	if on and not bubble.visible:
		bubble.scale = Vector3(0.1, 0.1, 0.1)
		bubble.visible = true
		create_tween().tween_property(bubble, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not on:
		bubble.visible = false


func show_magnet(on: bool) -> void:
	magnet_fx.visible = on


# ------------------------------------------------------------------ materials & helpers

func _m(color: Color, rough := 0.6, glow := 0.0, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [color.to_html(), rough, glow, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	_mats[key] = m
	return m


func _add(mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else model).add_child(mi)
	return mi


func _box(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(m, mat, pos, rot, parent)


func _cyl(r_bottom: float, r_top: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, sides := 12, parent: Node3D = null) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.bottom_radius = r_bottom
	m.top_radius = r_top
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	return _add(m, mat, pos, rot, parent)


func _sphere(r: float, mat: Material, pos: Vector3, scale_v := Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	var mi := _add(m, mat, pos, Vector3.ZERO, parent)
	mi.scale = scale_v
	return mi


func _prism(size: Vector3, mat: Material, pos: Vector3, rot := Vector3.ZERO, ltr := 0.5) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = size
	m.left_to_right = ltr
	return _add(m, mat, pos, rot)


func _torus(inner: float, outer: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 8
	return _add(m, mat, pos, rot, parent)


func _hull(length: float, width: float, depth: float, bow_rise: float, hull_col: Color, deck_col: Color, stripe_col: Color) -> void:
	var mesh := make_hull(length, width, depth, bow_rise)
	var hull_m := _m(hull_col, 0.45)
	hull_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var deck_m := _m(deck_col, 0.75)
	deck_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, hull_m)
	mesh.surface_set_material(1, deck_m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	model.add_child(mi)
	# a stripe along the waterline
	_box(Vector3(width * 0.98, 0.06, length * 0.62), _m(stripe_col, 0.5), Vector3(0.0, 0.08, -length * 0.08))


## Lofted V-hull with a raised bow. Surface 0 = hull, surface 1 = deck.
static func make_hull(length: float, width: float, depth: float, bow_rise: float) -> ArrayMesh:
	var n := 12
	var sections: Array = []
	for i in n + 1:
		var u := float(i) / n
		var z := lerpf(-length * 0.45, length * 0.55, u)
		var bowf := clampf((u - 0.5) / 0.5, 0.0, 1.0)
		var w := maxf(width * 0.5 * (1.0 - pow(bowf, 1.7)), 0.015)
		var top := 0.28 + bow_rise * bowf * bowf
		var d := depth * (1.0 - 0.55 * bowf)
		sections.append([
			Vector3(-w, top, z), Vector3(-w * 0.86, -d * 0.35, z), Vector3(0.0, -d, z),
			Vector3(w * 0.86, -d * 0.35, z), Vector3(w, top, z),
		])
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for k in 4:
			var c: Vector3 = (a[k] + a[k + 1] + b[k] + b[k + 1]) * 0.25
			_quad(hull, a[k], a[k + 1], b[k + 1], b[k], Vector3(c.x, c.y - 0.05, 0.0))
		_quad(deck, a[4], a[0], b[0], b[4], Vector3.UP)
	# transom (flat stern)
	var s: Array = sections[0]
	var center := Vector3(0.0, 0.0, s[0].z)
	for k in 5:
		var p1: Vector3 = s[k]
		var p2: Vector3 = s[(k + 1) % 5]
		_tri(hull, center, p1, p2, Vector3.FORWARD)
	var mesh := hull.commit()
	deck.commit(mesh)
	return mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.length() < 0.000001:
		return
	nrm = nrm.normalized()
	if nrm.dot(outward) < 0.0:
		nrm = -nrm
	for v in [a, b, c]:
		st.set_normal(nrm)
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	_tri(st, a, b, c, outward)
	_tri(st, a, c, d, outward)


# ------------------------------------------------------------------ models

func _flag_at(pos: Vector3, col: Color) -> void:
	flag = Node3D.new()
	flag.position = pos
	model.add_child(flag)
	_box(Vector3(0.03, 0.18, 0.3), _m(col, 0.6), Vector3(0.0, 0.0, -0.15), Vector3.ZERO, flag)


func _dinghy() -> void:
	_hull(2.4, 1.2, 0.38, 0.22, Color("ff5a4e"), Color("f4ead8"), Color("ffffff"))
	_box(Vector3(0.7, 0.22, 0.5), _m(Color("ffffff"), 0.7), Vector3(0.0, 0.4, -0.75))
	_cyl(0.05, 0.04, 1.1, _m(Color("6e4b33"), 0.8), Vector3(0.0, 0.85, 0.2))
	_prism(Vector3(0.95, 0.95, 0.04), _m(Color("ffffff"), 0.8), Vector3(0.0, 0.92, -0.27), Vector3(0.0, PI * 0.5, 0.0), 0.0)
	_box(Vector3(0.03, 0.03, 0.9), _m(Color("6e4b33"), 0.8), Vector3(0.0, 0.43, -0.25))
	_flag_at(Vector3(0.0, 1.42, 0.2), Color("ffd23f"))


func _tug() -> void:
	_hull(2.3, 1.3, 0.42, 0.18, Color("ffc531"), Color("4b4f5c"), Color("1e1b2e"))
	var red := _m(Color("e2463f"), 0.6)
	var glass := _m(Color("9fe3ff"), 0.15, 0.6)
	_box(Vector3(0.85, 0.55, 0.75), red, Vector3(0.0, 0.58, -0.25))
	_box(Vector3(0.95, 0.08, 0.85), _m(Color("ffffff"), 0.6), Vector3(0.0, 0.9, -0.25))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.02, 0.18, 0.5), glass, Vector3(sx * 0.43, 0.68, -0.25))
	_box(Vector3(0.6, 0.18, 0.02), glass, Vector3(0.0, 0.68, 0.13))
	var chim := _cyl(0.14, 0.14, 0.5, _m(Color("2a2a33"), 0.5), Vector3(0.0, 1.15, -0.45))
	_cyl(0.15, 0.15, 0.1, red, Vector3(0.0, 0.22, 0.0), Vector3.ZERO, 12, chim)
	for sx in [-1.0, 1.0]:
		for zz in [-0.5, 0.2]:
			_torus(0.08, 0.16, _m(Color("1e1b2e"), 0.9), Vector3(sx * 0.66, 0.15, zz), Vector3(0.0, 0.0, PI * 0.5))
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0.0, 1.42, -0.45)
	smoke.amount = 14
	smoke.lifetime = 1.6
	smoke.local_coords = false
	smoke.direction = Vector3(0.0, 1.0, -0.4)
	smoke.spread = 15.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.0, 0.3, 0.0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.0
	smoke.scale_amount_curve = _curve(0.4, 1.8)
	smoke.color_ramp = _fade(Color(0.85, 0.85, 0.9, 0.7))
	var puff := SphereMesh.new()
	puff.radius = 0.15
	puff.height = 0.3
	puff.radial_segments = 8
	puff.rings = 4
	smoke.mesh = puff
	smoke.material_override = _fx_mat(Color.WHITE)
	model.add_child(smoke)


func _speedster() -> void:
	_hull(2.6, 1.05, 0.32, 0.12, Color("f6f7fb"), Color("2b6cff"), Color("2b6cff"))
	var glass := _m(Color("1b2a4a"), 0.1, 0.0, 0.4)
	_prism(Vector3(0.85, 0.35, 0.5), glass, Vector3(0.0, 0.42, 0.25), Vector3(-PI * 0.5, 0.0, 0.0))
	_box(Vector3(0.75, 0.18, 0.9), _m(Color("f6f7fb"), 0.4), Vector3(0.0, 0.38, -0.45))
	_box(Vector3(0.9, 0.04, 0.22), _m(Color("ff3d5a"), 0.4), Vector3(0.0, 0.62, -1.0))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.04, 0.3, 0.2), _m(Color("ff3d5a"), 0.4), Vector3(sx * 0.42, 0.48, -1.0))
		_box(Vector3(0.05, 0.06, 1.6), _m(Color("ff3d5a"), 0.4), Vector3(sx * 0.53, 0.2, -0.1))
	_flag_at(Vector3(0.0, 0.9, -1.0), Color("ff3d5a"))
	_cyl(0.02, 0.02, 0.3, _m(Color("cccccc"), 0.3, 0.0, 0.8), Vector3(0.0, 0.75, -1.0))


func _junk() -> void:
	_hull(2.4, 1.25, 0.4, 0.35, Color("b5652d"), Color("e3c48f"), Color("6e3412"))
	_box(Vector3(0.8, 0.35, 0.55), _m(Color("7a3a1c"), 0.7), Vector3(0.0, 0.48, -0.8))
	_box(Vector3(0.95, 0.06, 0.7), _m(Color("2a1a12"), 0.7), Vector3(0.0, 0.69, -0.8))
	_cyl(0.05, 0.04, 1.15, _m(Color("4a2a16"), 0.8), Vector3(0.0, 0.85, 0.15))
	var sail := _m(Color("d83a2e"), 0.8)
	var batten := _m(Color("3a1a10"), 0.8)
	for k in 5:
		var y := 0.5 + k * 0.18
		var w := 0.85 - k * 0.07
		_box(Vector3(0.04, 0.16, w), sail, Vector3(0.0, y, 0.15 - w * 0.5 + 0.05))
		_box(Vector3(0.05, 0.025, w + 0.04), batten, Vector3(0.0, y + 0.09, 0.15 - w * 0.5 + 0.05))
	for sx in [-1.0, 1.0]:
		_sphere(0.1, _m(Color("ff7a3a"), 0.4, 2.5), Vector3(sx * 0.4, 0.95, -0.95), Vector3(1.0, 1.3, 1.0))
	_flag_at(Vector3(0.0, 1.42, 0.15), Color("ffd23f"))


func _duck() -> void:
	var yellow := _m(Color("ffd23f"), 0.35)
	var orange := _m(Color("ff8a1f"), 0.4)
	var black := _m(Color("111111"), 0.3)
	var white := _m(Color("ffffff"), 0.3)
	_sphere(0.62, yellow, Vector3(0.0, 0.2, -0.1), Vector3(1.0, 0.75, 1.45))
	_sphere(0.3, yellow, Vector3(0.0, 0.42, -0.95), Vector3(1.0, 0.8, 0.8))  # tail
	var head := _sphere(0.42, yellow, Vector3(0.0, 0.95, 0.45))
	head.scale = Vector3(1.0, 1.0, 1.0)
	_prism(Vector3(0.42, 0.3, 0.16), orange, Vector3(0.0, 0.88, 0.95), Vector3(PI * 0.5, 0.0, 0.0))
	for sx in [-1.0, 1.0]:
		_sphere(0.11, white, Vector3(sx * 0.2, 1.08, 0.78))
		_sphere(0.06, black, Vector3(sx * 0.21, 1.09, 0.86))
		_sphere(0.24, _m(Color("f2b822"), 0.4), Vector3(sx * 0.48, 0.38, -0.15), Vector3(0.4, 0.7, 1.1))  # wings
	_flag_at(Vector3(0.0, 1.4, 0.4), Color("ff8a1f"))
	flag.visible = false


func _skiff() -> void:
	_hull(2.5, 1.1, 0.36, 0.3, Color("1b1f4a"), Color("2d336b"), Color("9ff0ff"))
	var glow := _m(Color("9ff0ff"), 0.3, 2.2)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.04, 0.04, 2.0), glow, Vector3(sx * 0.56, 0.3, 0.0))
	_cyl(0.04, 0.03, 0.75, _m(Color("c0c8ff"), 0.3, 0.0, 0.7), Vector3(0.0, 0.66, -0.1))
	var halo := Node3D.new()
	halo.position = Vector3(0.0, 1.08, -0.1)
	model.add_child(halo)
	_torus(0.3, 0.4, _m(Color("fff3d6"), 0.3, 2.5), Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), halo)
	_sphere(0.17, _m(Color("fff3d6"), 0.3, 3.0), Vector3.ZERO, Vector3.ONE, halo)
	spin_parts.append(halo)
	var sparkles := CPUParticles3D.new()
	sparkles.position = Vector3(0.0, 1.08, -0.1)
	sparkles.amount = 10
	sparkles.lifetime = 1.2
	sparkles.local_coords = false
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.35
	sparkles.gravity = Vector3(0.0, -0.4, 0.0)
	sparkles.initial_velocity_max = 0.2
	sparkles.color_ramp = _fade(Color(0.85, 1.0, 1.0, 1.0))
	var dot := SphereMesh.new()
	dot.radius = 0.035
	dot.height = 0.07
	dot.radial_segments = 6
	dot.rings = 3
	sparkles.mesh = dot
	sparkles.material_override = _fx_mat(Color.WHITE, true)
	model.add_child(sparkles)


# ------------------------------------------------------------------ effects

func _fx_mat(col: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	if glow:
		m.emission_enabled = true
		m.emission = col
	return m


func _fade(col: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	return g


func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(maxf(a, b), 1.0)
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


func _build_wake() -> void:
	wake = CPUParticles3D.new()
	wake.position = Vector3(0.0, 0.02, -1.0)
	wake.amount = 46
	wake.lifetime = 1.5
	wake.local_coords = false
	wake.direction = Vector3(1.0, 0.0, 0.0)
	wake.spread = 180.0
	wake.flatness = 1.0
	wake.initial_velocity_min = 0.3
	wake.initial_velocity_max = 0.9
	wake.gravity = Vector3.ZERO
	wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wake.emission_box_extents = Vector3(0.45, 0.0, 0.3)
	wake.scale_amount_curve = _curve(0.5, 1.8)
	wake.color_ramp = _fade(Color(1.0, 1.0, 1.0, 0.75))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.28
	disc.bottom_radius = 0.28
	disc.height = 0.02
	disc.radial_segments = 10
	disc.rings = 1
	wake.mesh = disc
	wake.material_override = _fx_mat(Color.WHITE)
	add_child(wake)


func _build_spray() -> void:
	spray = CPUParticles3D.new()
	spray.position = Vector3(0.0, 0.15, 1.2)
	spray.amount = 24
	spray.lifetime = 0.5
	spray.local_coords = false
	spray.direction = Vector3(0.0, 1.0, 0.3)
	spray.spread = 55.0
	spray.initial_velocity_min = 2.0
	spray.initial_velocity_max = 3.5
	spray.gravity = Vector3(0.0, -12.0, 0.0)
	spray.color_ramp = _fade(Color(0.9, 0.98, 1.0, 0.9))
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 6
	drop.rings = 3
	spray.mesh = drop
	spray.material_override = _fx_mat(Color.WHITE)
	spray.emitting = false
	add_child(spray)


func _build_bubble() -> void:
	bubble = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.45
	s.height = 2.9
	s.radial_segments = 24
	s.rings = 12
	bubble.mesh = s
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.45, 0.9, 1.0, 0.22)
	m.emission_enabled = true
	m.emission = Color(0.3, 0.8, 1.0)
	m.emission_energy_multiplier = 0.6
	m.rim_enabled = true
	m.rim = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	bubble.material_override = m
	bubble.position = Vector3(0.0, 0.6, 0.0)
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.visible = false
	add_child(bubble)


func _build_magnet() -> void:
	magnet_fx = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 1.0
	t.outer_radius = 1.12
	t.rings = 32
	t.ring_segments = 6
	magnet_fx.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("ff4fd8")
	magnet_fx.material_override = m
	magnet_fx.position = Vector3(0.0, 1.9, 0.0)
	magnet_fx.visible = false
	add_child(magnet_fx)
