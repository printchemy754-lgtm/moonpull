class_name Boat
extends Node3D
## The player's boat: modular (hull + paint + sails + flag + captain's hat + wake),
## crewed by the Captain, who raises both arms to pull the moon while you hold.
## Every hull fits the same hitbox (keel 0.3 below, top 1.5 above the waterline).

const SKIN := Color("fcd2b0")
const NAVY := Color("23285c")

var pivot: Node3D
var model: Node3D
var captain: Node3D
var arm_l: Node3D
var arm_r: Node3D
var flag: Node3D
var spin_parts: Array[Node3D] = []
var thrusters: Array[CPUParticles3D] = []
var wake: CPUParticles3D
var spray: CPUParticles3D
var smoke: CPUParticles3D
var bubble: MeshInstance3D
var magnet_fx: MeshInstance3D
var fever_fx: Node3D
var fever_fire: CPUParticles3D
var cfg: Dictionary = {}
var _mats := {}
var _pull := 0.0


func _ready() -> void:
	pivot = Node3D.new()
	add_child(pivot)
	_build_wake()
	_build_spray()
	_build_bubble()
	_build_magnet()
	_build_fever()


## cfg: {"hull": i, "paint": i, "sail": i, "flag": i, "hat": i, "trail": i}
func apply(new_cfg: Dictionary) -> void:
	if new_cfg == cfg and model != null:
		return
	cfg = new_cfg.duplicate()
	if model:
		model.queue_free()
	flag = null
	captain = null
	smoke = null
	spin_parts.clear()
	thrusters.clear()
	model = Node3D.new()
	pivot.add_child(model)
	var paint: Color = Custom.item("paint", cfg.get("paint", 0)).color
	var sail: Color = Custom.item("sail", cfg.get("sail", 0)).color
	var hat: String = Custom.item("hat", cfg.get("hat", 0)).kind
	match int(cfg.get("hull", 0)):
		1: _tug(paint, sail, hat)
		2: _speedster(paint, sail, hat)
		3: _junk(paint, sail, hat)
		4: _duck(paint, sail, hat)
		5: _skiff(paint, sail, hat)
		_: _dinghy(paint, sail, hat)
	_tech_kit(sail, int(cfg.get("hull", 0)) == 4)
	_set_trail(Custom.item("trail", cfg.get("trail", 0)))


## Called every frame. speed_factor ~ 1 normal, >1 boosted, 0 = stopped.
func tick(delta: float, t: float, water_vel: float, speed_factor: float, alive: bool, pulling: bool) -> void:
	if alive:
		pivot.rotation.z = sin(t * 2.1) * 0.05
		pivot.rotation.x = lerpf(pivot.rotation.x, clampf(-water_vel * 0.05, -0.18, 0.18) - 0.03 * (speed_factor - 1.0), 1.0 - exp(-8.0 * delta))
		pivot.position.y = sin(t * 3.0) * 0.04
	_pull = lerpf(_pull, 1.0 if (pulling and alive) else 0.0, 1.0 - exp(-12.0 * delta))
	if arm_l:
		var wave := sin(t * 14.0) * 0.12 * _pull
		arm_l.rotation.z = lerpf(0.35, 2.75, _pull) + wave
		arm_r.rotation.z = -lerpf(0.35, 2.75, _pull) - wave
	if captain:
		captain.rotation.z = sin(t * 2.6) * 0.06 * (1.0 - _pull)
		captain.position.y = float(captain.get_meta("base_y")) + _pull * 0.04
	if flag:
		flag.rotation.y = sin(t * 9.0) * 0.35
	for p in spin_parts:
		p.rotation.y += delta * 2.0
	var moving := alive and speed_factor > 0.05
	for th in thrusters:
		th.emitting = moving
		th.speed_scale = clampf(speed_factor, 0.6, 1.8)
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
	if fever_fx.visible:
		fever_fx.rotation.z += delta * 6.0
		var fs := 1.0 + sin(t * 18.0) * 0.08
		fever_fx.scale = Vector3(fs, fs, fs)


## Futuristic kit on every hull: twin plasma thrusters, a neon trim line and a
## hover glow under the keel. `glow` is the GLOW colour picked in the workshop.
func _tech_kit(glow: Color, round_hull: bool) -> void:
	var neon := _m(glow, 2.6, 0.0)
	var dark := _m(Color("1c1f3a"))
	var zs := -1.05 if not round_hull else -1.15
	for sx in [-0.32, 0.32]:
		var pod := _cyl(0.13, 0.11, 0.42, dark, Vector3(sx, 0.32, zs), Vector3(PI * 0.5, 0.0, 0.0), 10)
		pod.name = "pod"
		_cyl(0.1, 0.1, 0.04, neon, Vector3(sx, 0.32, zs - 0.22), Vector3(PI * 0.5, 0.0, 0.0), 10)
		var fire := CPUParticles3D.new()
		fire.position = Vector3(sx, 0.32, zs - 0.26)
		fire.amount = 16
		fire.lifetime = 0.28
		fire.local_coords = false
		fire.direction = Vector3(0.0, 0.0, -1.0)
		fire.spread = 6.0
		fire.initial_velocity_min = 2.0
		fire.initial_velocity_max = 3.0
		fire.gravity = Vector3.ZERO
		fire.scale_amount_curve = _curve(1.0, 0.1)
		var sp := SphereMesh.new()
		sp.radius = 0.08
		sp.height = 0.16
		sp.radial_segments = 6
		sp.rings = 3
		fire.mesh = sp
		var fm := StandardMaterial3D.new()
		fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		fm.vertex_color_use_as_albedo = true
		fire.material_override = fm
		fire.color_ramp = _fade(Color(glow.lightened(0.5), 1.0), Color(glow, 0.0))
		model.add_child(fire)
		thrusters.append(fire)
	# hover glow
	var disc := CylinderMesh.new()
	disc.top_radius = 0.75
	disc.bottom_radius = 0.75
	disc.height = 0.01
	disc.radial_segments = 20
	disc.rings = 1
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.albedo_color = Color(glow, 0.35)
	var hg := MeshInstance3D.new()
	hg.mesh = disc
	hg.material_override = gm
	hg.scale = Vector3(1.0, 1.0, 1.6)
	hg.position = Vector3(0.0, 0.03, 0.0)
	hg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(hg)


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


## FEVER: an energy ram on the bow and a plasma tail.
func show_fever(on: bool) -> void:
	if on and not fever_fx.visible:
		fever_fx.scale = Vector3(0.1, 0.1, 0.1)
	fever_fx.visible = on
	fever_fire.emitting = on


func _build_fever() -> void:
	fever_fx = Node3D.new()
	fever_fx.position = Vector3(0.0, 0.7, 1.35)
	add_child(fever_fx)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(1.0, 0.3, 0.85, 0.75)
	glow.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.95
	cone.height = 1.3
	cone.radial_segments = 6
	cone.rings = 1
	var ram := MeshInstance3D.new()
	ram.mesh = cone
	ram.material_override = glow
	ram.rotation.x = PI * 0.5
	ram.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fever_fx.add_child(ram)
	var ring := TorusMesh.new()
	ring.inner_radius = 1.05
	ring.outer_radius = 1.2
	ring.rings = 6
	ring.ring_segments = 4
	var halo := MeshInstance3D.new()
	halo.mesh = ring
	var hm := glow.duplicate() as StandardMaterial3D
	hm.albedo_color = Color(0.3, 0.95, 1.0, 0.8)
	halo.material_override = hm
	halo.rotation.x = PI * 0.5
	halo.position.z = -0.4
	fever_fx.add_child(halo)
	fever_fx.visible = false
	fever_fire = CPUParticles3D.new()
	fever_fire.amount = 40
	fever_fire.lifetime = 0.3
	fever_fire.local_coords = true
	fever_fire.emitting = false
	fever_fire.position = Vector3(0.0, 0.5, -1.1)
	fever_fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fever_fire.emission_sphere_radius = 0.45
	fever_fire.direction = Vector3(0.0, 0.4, -1.0)
	fever_fire.spread = 18.0
	fever_fire.initial_velocity_min = 1.0
	fever_fire.initial_velocity_max = 2.5
	fever_fire.gravity = Vector3(0.0, 2.0, 0.0)
	fever_fire.scale_amount_min = 0.5
	fever_fire.scale_amount_max = 1.0
	var sp := SphereMesh.new()
	sp.radius = 0.11
	sp.height = 0.22
	sp.radial_segments = 6
	sp.rings = 3
	fever_fire.mesh = sp
	var fm := glow.duplicate() as StandardMaterial3D
	fm.albedo_color = Color.WHITE
	fm.vertex_color_use_as_albedo = true
	fever_fire.material_override = fm
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	g.set_color(1, Color(1.0, 0.1, 0.8, 0.0))
	g.add_point(0.4, Color(1.0, 0.45, 0.2, 0.9))
	fever_fire.color_ramp = g
	add_child(fever_fire)


# ------------------------------------------------------------------ helpers

func _m(color: Color, glow := 0.0, outline := 0.022) -> Material:
	var key := "%s_%.2f_%.3f" % [color.to_html(), glow, outline]
	if _mats.has(key):
		return _mats[key]
	var m := Toon.mat(color, glow, outline)
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


func _cyl(r_bottom: float, r_top: float, h: float, mat: Material, pos: Vector3, rot := Vector3.ZERO, sides := 14, parent: Node3D = null) -> MeshInstance3D:
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
	m.radial_segments = 18
	m.rings = 9
	var mi := _add(m, mat, pos, Vector3.ZERO, parent)
	mi.scale = scale_v
	return mi


func _capsule(r: float, h: float, mat: Material, pos: Vector3, parent: Node3D) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 4
	return _add(m, mat, pos, Vector3.ZERO, parent)


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
	mesh.surface_set_material(0, _m(hull_col, 0.0, 0.03))
	mesh.surface_set_material(1, _m(deck_col, 0.0, 0.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	model.add_child(mi)
	_box(Vector3(width * 0.98, 0.07, length * 0.6), _m(stripe_col, 0.0, 0.0), Vector3(0.0, 0.1, -length * 0.08))
	# rail along the deck edge
	_box(Vector3(width * 1.02, 0.06, length * 0.7), _m(Color("f4ead8"), 0.0, 0.015), Vector3(0.0, 0.3, -length * 0.1))


## Lofted, chubby V-hull with a raised bow. Surface 0 = hull, surface 1 = deck.
static func make_hull(length: float, width: float, depth: float, bow_rise: float) -> ArrayMesh:
	var n := 12
	var sections: Array = []
	for i in n + 1:
		var u := float(i) / n
		var z := lerpf(-length * 0.45, length * 0.55, u)
		var bowf := clampf((u - 0.5) / 0.5, 0.0, 1.0)
		var sternf := clampf((0.12 - u) / 0.12, 0.0, 1.0)
		var w := maxf(width * 0.5 * (1.0 - pow(bowf, 1.7)) * (1.0 - 0.12 * sternf), 0.015)
		var top := 0.28 + bow_rise * bowf * bowf
		var d := depth * (1.0 - 0.55 * bowf)
		sections.append([
			Vector3(-w, top, z), Vector3(-w * 1.04, 0.05, z), Vector3(-w * 0.8, -d * 0.55, z),
			Vector3(0.0, -d, z), Vector3(w * 0.8, -d * 0.55, z), Vector3(w * 1.04, 0.05, z), Vector3(w, top, z),
		])
	var hull := SurfaceTool.new()
	hull.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var last := 6
	for i in n:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		for k in last:
			var c: Vector3 = (a[k] + a[k + 1] + b[k] + b[k + 1]) * 0.25
			_quad(hull, a[k], a[k + 1], b[k + 1], b[k], Vector3(c.x, c.y - 0.05, 0.0))
		_quad(deck, a[last], a[0], b[0], b[last], Vector3.UP)
	var s: Array = sections[0]
	var center := Vector3(0.0, 0.0, s[0].z)
	for k in last + 1:
		var p1: Vector3 = s[k]
		var p2: Vector3 = s[(k + 1) % (last + 1)]
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


# ------------------------------------------------------------------ captain

func _captain(pos: Vector3, hat: String, shirt: Color, seated := false) -> void:
	captain = Node3D.new()
	captain.position = pos
	captain.set_meta("base_y", pos.y)
	model.add_child(captain)
	var white := _m(Color("f7f7f2"))
	var navy := _m(NAVY)
	var skin := _m(SKIN)
	var black := _m(Color("15122b"), 0.0, 0.0)
	if not seated:
		_cyl(0.09, 0.09, 0.14, navy, Vector3(-0.07, 0.07, 0.0), Vector3.ZERO, 8, captain)
		_cyl(0.09, 0.09, 0.14, navy, Vector3(0.07, 0.07, 0.0), Vector3.ZERO, 8, captain)
	var by := 0.06 if seated else 0.14
	_cyl(0.17, 0.19, 0.34, white, Vector3(0.0, by + 0.17, 0.0), Vector3.ZERO, 14, captain)
	for k in 2:
		_cyl(0.192, 0.192, 0.045, _m(shirt, 0.0, 0.0), Vector3(0.0, by + 0.1 + k * 0.12, 0.0), Vector3.ZERO, 14, captain)
	var head_y := by + 0.5
	_sphere(0.2, skin, Vector3(0.0, head_y, 0.0), Vector3.ONE, captain)
	for sx in [-1.0, 1.0]:
		_sphere(0.032, black, Vector3(sx * 0.075, head_y + 0.03, 0.175), Vector3(1.0, 1.25, 1.0), captain)
		_sphere(0.034, _m(Color("ff9aa8"), 0.0, 0.0), Vector3(sx * 0.12, head_y - 0.045, 0.15), Vector3(1.2, 0.8, 0.6), captain)
	_sphere(0.035, _m(Color("f2b28c"), 0.0, 0.0), Vector3(0.0, head_y - 0.01, 0.2), Vector3.ONE, captain)
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.19, by + 0.3, 0.0)
	captain.add_child(arm_l)
	_capsule(0.055, 0.32, white, Vector3(0.0, -0.13, 0.0), arm_l)
	_sphere(0.06, skin, Vector3(0.0, -0.3, 0.0), Vector3.ONE, arm_l)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.19, by + 0.3, 0.0)
	captain.add_child(arm_r)
	_capsule(0.055, 0.32, white, Vector3(0.0, -0.13, 0.0), arm_r)
	_sphere(0.06, skin, Vector3(0.0, -0.3, 0.0), Vector3.ONE, arm_r)
	_hat(hat, head_y + 0.14, shirt)


func _hat(kind: String, y: float, accent: Color) -> void:
	var p := captain
	match kind:
		"beanie":
			_sphere(0.215, _m(Color("e8433a")), Vector3(0.0, y - 0.05, 0.0), Vector3(1.0, 0.72, 1.0), p)
			_cyl(0.22, 0.22, 0.06, _m(Color("f7f7f2")), Vector3(0.0, y - 0.07, 0.0), Vector3.ZERO, 14, p)
			_sphere(0.065, _m(Color("f7f7f2")), Vector3(0.0, y + 0.12, 0.0), Vector3.ONE, p)
		"straw":
			_cyl(0.36, 0.34, 0.03, _m(Color("f0c96b")), Vector3(0.0, y - 0.03, 0.0), Vector3.ZERO, 18, p)
			_cyl(0.19, 0.17, 0.15, _m(Color("f0c96b")), Vector3(0.0, y + 0.05, 0.0), Vector3.ZERO, 14, p)
			_cyl(0.195, 0.195, 0.045, _m(accent), Vector3(0.0, y + 0.0, 0.0), Vector3.ZERO, 14, p)
		"party":
			_cyl(0.14, 0.0, 0.34, _m(Color("ff4fd8")), Vector3(0.0, y + 0.13, 0.0), Vector3.ZERO, 12, p)
			_cyl(0.105, 0.075, 0.07, _m(Color("ffd23f"), 0.0, 0.0), Vector3(0.0, y + 0.06, 0.0), Vector3.ZERO, 12, p)
			_sphere(0.055, _m(Color("ffd23f")), Vector3(0.0, y + 0.31, 0.0), Vector3.ONE, p)
		"top":
			_cyl(0.28, 0.28, 0.03, _m(Color("1e1b2e")), Vector3(0.0, y - 0.03, 0.0), Vector3.ZERO, 18, p)
			_cyl(0.17, 0.18, 0.3, _m(Color("1e1b2e")), Vector3(0.0, y + 0.13, 0.0), Vector3.ZERO, 14, p)
			_cyl(0.185, 0.185, 0.05, _m(Color("e8433a"), 0.0, 0.0), Vector3(0.0, y + 0.02, 0.0), Vector3.ZERO, 14, p)
		"crown":
			var gold := _m(Color("ffc531"), 0.3)
			_cyl(0.18, 0.19, 0.12, gold, Vector3(0.0, y + 0.01, 0.0), Vector3.ZERO, 14, p)
			for k in 5:
				var a := TAU * k / 5.0
				_cyl(0.05, 0.0, 0.12, gold, Vector3(cos(a) * 0.15, y + 0.12, sin(a) * 0.15), Vector3.ZERO, 6, p)
			_sphere(0.04, _m(Color("ff3d5a"), 0.8, 0.0), Vector3(0.0, y + 0.02, 0.19), Vector3.ONE, p)
		"pirate":
			var black := _m(Color("1e1b2e"))
			_cyl(0.33, 0.33, 0.035, black, Vector3(0.0, y - 0.04, 0.0), Vector3.ZERO, 3, p)
			_cyl(0.2, 0.18, 0.16, black, Vector3(0.0, y + 0.04, 0.0), Vector3.ZERO, 14, p)
			_cyl(0.205, 0.205, 0.04, _m(Color("e8433a"), 0.0, 0.0), Vector3(0.0, y - 0.0, 0.0), Vector3.ZERO, 14, p)
			_sphere(0.05, _m(Color("f7f7f2"), 0.0, 0.0), Vector3(0.0, y + 0.06, 0.19), Vector3(1.0, 1.0, 0.5), p)
		_:  # captain's cap
			_cyl(0.205, 0.215, 0.11, _m(Color("f7f7f2")), Vector3(0.0, y + 0.0, 0.0), Vector3.ZERO, 14, p)
			_cyl(0.23, 0.22, 0.04, _m(NAVY), Vector3(0.0, y - 0.05, 0.0), Vector3.ZERO, 14, p)
			_box(Vector3(0.26, 0.03, 0.14), _m(Color("15122b")), Vector3(0.0, y - 0.06, 0.2), Vector3(0.25, 0.0, 0.0), p)
			_sphere(0.035, _m(Color("ffc531"), 0.5, 0.0), Vector3(0.0, y + 0.0, 0.205), Vector3.ONE, p)


func _flag_at(pos: Vector3) -> void:
	var f := Custom.item("flag", cfg.get("flag", 0))
	flag = Node3D.new()
	flag.position = pos
	model.add_child(flag)
	var a: Color = f.a
	var b: Color = f.b
	_box(Vector3(0.03, 0.2, 0.34), _m(a, 0.0, 0.012), Vector3(0.0, 0.0, -0.17), Vector3.ZERO, flag)
	match String(f.pattern):
		"stripes":
			for k in 2:
				_box(Vector3(0.035, 0.04, 0.34), _m(b, 0.0, 0.0), Vector3(0.0, -0.05 + k * 0.1, -0.17), Vector3.ZERO, flag)
		"cross":
			_box(Vector3(0.035, 0.2, 0.05), _m(b, 0.0, 0.0), Vector3(0.0, 0.0, -0.11), Vector3.ZERO, flag)
			_box(Vector3(0.035, 0.05, 0.34), _m(b, 0.0, 0.0), Vector3(0.0, 0.0, -0.17), Vector3.ZERO, flag)
		"dot":
			_cyl(0.06, 0.06, 0.04, _m(b, 0.0, 0.0), Vector3(0.0, 0.0, -0.17), Vector3(0.0, 0.0, PI * 0.5), 12, flag)


func _mast(z: float, height: float) -> void:
	_cyl(0.05, 0.04, height, _m(Color("7a5236")), Vector3(0.0, 0.3 + height * 0.5, z))
	_flag_at(Vector3(0.0, 0.3 + height - 0.08, z))


# ------------------------------------------------------------------ hulls

func _dinghy(paint: Color, sail: Color, hat: String) -> void:
	_hull(2.4, 1.3, 0.4, 0.24, paint, Color("e9d3a8"), paint.darkened(0.3))
	_box(Vector3(0.9, 0.12, 0.3), _m(Color("b07a4a")), Vector3(0.0, 0.34, -0.7))
	_mast(0.45, 1.05)
	_prism(Vector3(0.75, 0.9, 0.04), _m(sail, 0.0, 0.015), Vector3(0.0, 0.88, 0.07), Vector3(0.0, PI * 0.5, 0.0), 0.0)
	_box(Vector3(0.03, 0.03, 0.8), _m(Color("7a5236")), Vector3(0.0, 0.43, 0.05))
	_captain(Vector3(0.0, 0.3, -0.62), hat, sail)


func _tug(paint: Color, sail: Color, hat: String) -> void:
	_hull(2.3, 1.4, 0.45, 0.18, paint, Color("4b4f5c"), Color("1e1b2e"))
	var glass := _m(Color("9fe3ff"), 0.5, 0.0)
	_box(Vector3(0.85, 0.55, 0.7), _m(Color("f7f7f2")), Vector3(0.0, 0.58, -0.35))
	_box(Vector3(0.98, 0.09, 0.84), _m(sail), Vector3(0.0, 0.9, -0.35))
	for sx in [-1.0, 1.0]:
		_cyl(0.08, 0.08, 0.02, glass, Vector3(sx * 0.43, 0.65, -0.35), Vector3(0.0, 0.0, PI * 0.5), 12)
	_box(Vector3(0.6, 0.18, 0.02), glass, Vector3(0.0, 0.68, 0.01))
	var chim := _cyl(0.13, 0.15, 0.45, _m(Color("2a2a33")), Vector3(0.0, 1.15, -0.62))
	_cyl(0.155, 0.155, 0.1, _m(sail, 0.0, 0.0), Vector3(0.0, 0.12, 0.0), Vector3.ZERO, 12, chim)
	for sx in [-1.0, 1.0]:
		for zz in [-0.5, 0.25]:
			_torus(0.07, 0.15, _m(Color("1e1b2e")), Vector3(sx * 0.7, 0.16, zz), Vector3(0.0, 0.0, PI * 0.5))
	_cyl(0.025, 0.025, 0.5, _m(Color("7a5236")), Vector3(0.0, 0.55, -0.98))
	_flag_at(Vector3(0.0, 0.72, -0.98))
	_captain(Vector3(0.0, 0.3, 0.52), hat, sail)
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0.0, 1.4, -0.62)
	smoke.amount = 14
	smoke.lifetime = 1.6
	smoke.local_coords = false
	smoke.direction = Vector3(0.0, 1.0, -0.4)
	smoke.spread = 15.0
	smoke.initial_velocity_min = 0.6
	smoke.initial_velocity_max = 1.0
	smoke.gravity = Vector3(0.0, 0.3, 0.0)
	smoke.scale_amount_curve = _curve(0.4, 1.8)
	smoke.color_ramp = _fade(Color(0.9, 0.9, 0.95, 0.75), Color(0.9, 0.9, 0.95, 0.0))
	var puff := SphereMesh.new()
	puff.radius = 0.15
	puff.height = 0.3
	puff.radial_segments = 8
	puff.rings = 4
	smoke.mesh = puff
	smoke.material_override = _fx_mat(Color.WHITE)
	model.add_child(smoke)


func _speedster(paint: Color, sail: Color, hat: String) -> void:
	_hull(2.6, 1.1, 0.32, 0.12, paint, Color("2b2f5a"), Color("f7f7f2"))
	_prism(Vector3(0.85, 0.32, 0.45), _m(Color("1b2a4a"), 0.0, 0.015), Vector3(0.0, 0.42, 0.3), Vector3(-PI * 0.5, 0.0, 0.0))
	_box(Vector3(0.7, 0.14, 0.6), _m(Color("f7f7f2")), Vector3(0.0, 0.36, -0.5))
	_box(Vector3(0.95, 0.05, 0.24), _m(sail), Vector3(0.0, 0.62, -1.02))
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.05, 0.3, 0.22), _m(sail), Vector3(sx * 0.44, 0.48, -1.02))
		_box(Vector3(0.05, 0.06, 1.7), _m(sail, 0.0, 0.0), Vector3(sx * 0.56, 0.2, -0.1))
	_cyl(0.02, 0.02, 0.36, _m(Color("cccccc")), Vector3(0.0, 0.8, -1.02))
	_flag_at(Vector3(0.0, 0.92, -1.02))
	_captain(Vector3(0.0, 0.26, -0.18), hat, sail, true)


func _junk(paint: Color, sail: Color, hat: String) -> void:
	_hull(2.4, 1.32, 0.42, 0.4, paint, Color("e3c48f"), paint.darkened(0.35))
	_mast(0.25, 1.1)
	var batten := _m(Color("3a1a10"), 0.0, 0.0)
	for k in 5:
		var y := 0.52 + k * 0.17
		var w := 0.72 - k * 0.07
		_box(Vector3(0.04, 0.15, w), _m(sail, 0.0, 0.012), Vector3(0.0, y, 0.25 - w * 0.5 + 0.04))
		_box(Vector3(0.05, 0.022, w + 0.04), batten, Vector3(0.0, y + 0.085, 0.25 - w * 0.5 + 0.04))
	for sx in [-1.0, 1.0]:
		_sphere(0.1, _m(Color("ff6a3a"), 2.5, 0.015), Vector3(sx * 0.48, 0.62, -0.95), Vector3(1.0, 1.3, 1.0))
		_cyl(0.015, 0.015, 0.22, _m(Color("3a1a10")), Vector3(sx * 0.48, 0.47, -0.95))
	_captain(Vector3(0.0, 0.3, -0.72), hat, sail)


func _duck(paint: Color, sail: Color, hat: String) -> void:
	var body := _m(paint)
	_sphere(0.64, body, Vector3(0.0, 0.18, -0.1), Vector3(1.0, 0.72, 1.45))
	_sphere(0.3, body, Vector3(0.0, 0.4, -0.95), Vector3(1.0, 0.8, 0.8))
	_sphere(0.4, body, Vector3(0.0, 0.85, 0.62))
	_prism(Vector3(0.38, 0.28, 0.15), _m(Color("ff8a1f")), Vector3(0.0, 0.79, 1.08), Vector3(PI * 0.5, 0.0, 0.0))
	for sx in [-1.0, 1.0]:
		_sphere(0.1, _m(Color("ffffff")), Vector3(sx * 0.19, 0.98, 0.93))
		_sphere(0.055, _m(Color("15122b"), 0.0, 0.0), Vector3(sx * 0.2, 0.99, 1.01))
		_sphere(0.24, _m(paint.darkened(0.12)), Vector3(sx * 0.5, 0.36, -0.15), Vector3(0.4, 0.7, 1.1))
	_cyl(0.6, 0.6, 0.05, _m(sail, 0.0, 0.0), Vector3(0.0, 0.05, -0.1), Vector3.ZERO, 24)
	_cyl(0.02, 0.02, 0.45, _m(Color("7a5236")), Vector3(0.0, 0.62, -1.05))
	_flag_at(Vector3(0.0, 0.78, -1.05))
	_captain(Vector3(0.0, 0.52, -0.32), hat, sail, true)


func _skiff(paint: Color, sail: Color, hat: String) -> void:
	_hull(2.5, 1.12, 0.36, 0.32, paint, Color("2d336b"), sail)
	for sx in [-1.0, 1.0]:
		_box(Vector3(0.04, 0.04, 2.0), _m(sail, 2.2, 0.0), Vector3(sx * 0.58, 0.31, 0.0))
	_cyl(0.04, 0.03, 0.7, _m(Color("c0c8ff")), Vector3(0.0, 0.65, 0.3))
	var halo := Node3D.new()
	halo.position = Vector3(0.0, 1.08, 0.3)
	model.add_child(halo)
	_torus(0.28, 0.38, _m(sail, 2.4, 0.012), Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), halo)
	_sphere(0.15, _m(Color("fff3d6"), 2.5, 0.012), Vector3.ZERO, Vector3.ONE, halo)
	spin_parts.append(halo)
	_cyl(0.02, 0.02, 0.4, _m(Color("c0c8ff")), Vector3(0.0, 0.5, -1.05))
	_flag_at(Vector3(0.0, 0.66, -1.05))
	_captain(Vector3(0.0, 0.3, -0.55), hat, sail)


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


func _fade(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	return g


func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(maxf(a, b), 1.0)
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


func _set_trail(item: Dictionary) -> void:
	var a: Color = item.a
	var b: Color = item.b
	var g := Gradient.new()
	g.set_color(0, Color(a.r, a.g, a.b, 0.85))
	g.set_color(1, Color(b.r, b.g, b.b, 0.0))
	if item.name == "RAINBOW":
		g.add_point(0.25, Color(1.0, 0.85, 0.2, 0.75))
		g.add_point(0.5, Color(0.25, 0.85, 0.5, 0.6))
		g.add_point(0.75, Color(0.6, 0.4, 1.0, 0.4))
	wake.color_ramp = g


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
	wake.color_ramp = _fade(Color(1, 1, 1, 0.8), Color(1, 1, 1, 0))
	var disc := CylinderMesh.new()
	disc.top_radius = 0.17
	disc.bottom_radius = 0.17
	disc.height = 0.02
	disc.radial_segments = 10
	disc.rings = 1
	wake.mesh = disc
	wake.material_override = _fx_mat(Color.WHITE, true)
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
	spray.color_ramp = _fade(Color(0.9, 0.98, 1.0, 0.9), Color(0.9, 0.98, 1.0, 0.0))
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
