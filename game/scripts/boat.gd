class_name Boat
extends Node3D
## The player's moon-ball: a glowing shell (style + paint + glow colour) that
## rolls, with the little Captain standing upright inside (hat, flag), and a
## light trail behind. The node sits on the floor; the ball's centre is at BALL_R.

const SKIN := Color("fcd2b0")
const NAVY := Color("23285c")
const BALL_R := 0.62        # visual radius (collisions use LevelGen.R)

var pivot: Node3D
var model: Node3D
var captain: Node3D
var arm_l: Node3D
var arm_r: Node3D
var flag: Node3D
var spin_parts: Array[Node3D] = []
var thrusters: Array[CPUParticles3D] = []
var trick_kind := 0
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
var shell: Node3D          # rolls
var still: Node3D          # rings that don't roll (planet style)
var _lean := 0.0
var riding := false        # solid ball: the captain runs on top of it
static var _ball_shader: Shader


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
	var glow: Color = Custom.item("sail", cfg.get("sail", 0)).color
	var hat: String = Custom.item("hat", cfg.get("hat", 0)).kind
	shell = Node3D.new()
	shell.position = Vector3(0.0, BALL_R, 0.0)
	model.add_child(shell)
	still = Node3D.new()
	still.position = Vector3(0.0, BALL_R, 0.0)
	model.add_child(still)
	var hull := Custom.item("hull", cfg.get("hull", 0))
	riding = int(hull.get("pattern", 0)) > 0
	if riding:
		_patterned(int(hull.pattern), hull.get("a", Color.WHITE))
		# the captain balances on top of the rolling ball, circus style
		_captain(Vector3(0.0, BALL_R * 2.0 - 0.02, 0.0), hat, glow)
		captain.scale = Vector3(0.6, 0.6, 0.6)
	else:
		_shell(int(cfg.get("hull", 0)), paint, glow)
		# the captain stands inside, always upright
		_captain(Vector3(0.0, 0.08, 0.0), hat, glow)
		captain.scale = Vector3(0.62, 0.62, 0.62)
		_cyl(0.32, 0.36, 0.06, _m(Color("1c1f3a")), Vector3(0.0, 0.07, 0.0), Vector3.ZERO, 16)
		_cyl(0.36, 0.36, 0.02, _m(glow, 2.5, 0.0), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, 16)
	var pole := Node3D.new()
	pole.position = Vector3(0.0, 0.0, -0.12)
	captain.add_child(pole)
	_cyl(0.025, 0.025, 0.7, _m(Color("c8d2ff")), Vector3(0.0, 0.75, 0.0), Vector3.ZERO, 6, pole)
	flag = Node3D.new()
	flag.position = Vector3(0.0, 1.0, 0.0)
	pole.add_child(flag)
	var f := Custom.item("flag", cfg.get("flag", 0))
	_box(Vector3(0.03, 0.2, 0.34), _m(f.a, 0.0, 0.012), Vector3(0.0, 0.0, -0.17), Vector3.ZERO, flag)
	if String(f.pattern) != "solid":
		_box(Vector3(0.035, 0.06, 0.34), _m(f.b, 0.0, 0.0), Vector3(0.0, 0.0, -0.17), Vector3.ZERO, flag)
	_set_trail(Custom.item("trail", cfg.get("trail", 0)))


## Solid patterned ball (beach ball, soccer, lava rock...): one sphere + shader.
func _patterned(pattern: int, a: Color) -> void:
	if _ball_shader == null:
		_ball_shader = load("res://shaders/ball.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _ball_shader
	m.set_shader_parameter("pattern", pattern)
	m.set_shader_parameter("col_a", a)
	m.next_pass = Toon.outline_mat(0.022)
	var sp := SphereMesh.new()
	sp.radius = BALL_R
	sp.height = BALL_R * 2.0
	sp.radial_segments = 32
	sp.rings = 16
	_add(sp, m, Vector3.ZERO, Vector3.ZERO, shell)


## Shell styles (the six "hulls" in the Workshop).
func _shell(style: int, paint: Color, glow: Color) -> void:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(paint.r, paint.g, paint.b, 0.28)
	glass.roughness = 0.05
	glass.metallic = 0.3
	glass.rim_enabled = true
	glass.rim = 1.0
	glass.rim_tint = 0.2
	glass.emission_enabled = true
	glass.emission = paint * 0.25
	glass.cull_mode = BaseMaterial3D.CULL_BACK
	var band := _m(glow, 2.6, 0.0)
	var solid := _m(paint)
	match style:
		1:   # TECH: glass + three glowing bands
			_sphere(BALL_R, glass, Vector3.ZERO, Vector3.ONE, shell)
			_torus(BALL_R - 0.03, BALL_R + 0.03, band, Vector3.ZERO, Vector3.ZERO, shell)
			_torus(BALL_R - 0.03, BALL_R + 0.03, band, Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), shell)
			_torus(BALL_R - 0.03, BALL_R + 0.03, _m(paint.lightened(0.3), 1.2, 0.0), Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), shell)
		2:   # GYRO: open cage of rings, no glass
			for k in 4:
				_torus(BALL_R - 0.04, BALL_R + 0.03, solid if k % 2 == 0 else band, Vector3.ZERO, Vector3(0.0, TAU * k / 8.0, PI * 0.5), shell)
			_torus(BALL_R - 0.04, BALL_R + 0.03, band, Vector3.ZERO, Vector3.ZERO, shell)
		3:   # PLANET: glass + big tilted ring that stays level
			_sphere(BALL_R, glass, Vector3.ZERO, Vector3.ONE, shell)
			_torus(BALL_R + 0.12, BALL_R + 0.24, band, Vector3.ZERO, Vector3(0.35, 0.0, 0.2), still)
			for k in 6:
				var a := TAU * k / 6.0
				_sphere(0.05, _m(Color.WHITE, 2.0, 0.0), Vector3(cos(a), 0.4, sin(a)) * (BALL_R - 0.02), Vector3.ONE, shell)
		4:   # DUCKY: rubber-duck shell with beak and eyes
			var duck := glass.duplicate() as StandardMaterial3D
			duck.albedo_color = Color(paint.r, paint.g, paint.b, 0.45)
			_sphere(BALL_R, duck, Vector3.ZERO, Vector3.ONE, shell)
			_sphere(0.16, _m(Color("ff8a1a")), Vector3(0.0, 0.05, BALL_R), Vector3(1.2, 0.6, 1.0), shell)
			for sx in [-0.2, 0.2]:
				_sphere(0.07, _m(Color.WHITE), Vector3(sx, 0.25, BALL_R - 0.08), Vector3.ONE, shell)
				_sphere(0.035, _m(Color("15122b"), 0.0, 0.0), Vector3(sx, 0.25, BALL_R - 0.02), Vector3.ONE, shell)
		5:   # MOON: crater shell, half open window
			_sphere(BALL_R, glass, Vector3.ZERO, Vector3.ONE, shell)
			var rock := _m(Color("d8d4e8"))
			for k in 9:
				var a2 := TAU * k / 9.0
				var dir := Vector3(cos(a2) * 0.8, sin(a2 * 2.0) * 0.6, sin(a2)).normalized()
				if dir.z > 0.5:
					continue
				_sphere(0.17, rock, dir * (BALL_R - 0.06), Vector3(1.0, 1.0, 0.45), shell).look_at_from_position(dir * (BALL_R - 0.06), Vector3.ZERO, Vector3.UP if absf(dir.y) < 0.9 else Vector3.RIGHT)
			_torus(BALL_R - 0.02, BALL_R + 0.04, band, Vector3.ZERO, Vector3.ZERO, shell)
		_:   # BUBBLE: simple glass ball with one glowing equator
			_sphere(BALL_R, glass, Vector3.ZERO, Vector3.ONE, shell)
			_torus(BALL_R - 0.02, BALL_R + 0.04, band, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), shell)
			_sphere(0.09, _m(Color.WHITE, 1.0, 0.0), Vector3(-0.25, 0.3, 0.35), Vector3.ONE, shell)


## Rolls the shell: dd = distance moved forward, ds = sideways (+s = local +X).
func roll(dd: float, ds: float) -> void:
	if shell == null:
		return
	shell.rotate(Vector3.RIGHT, dd / BALL_R)
	shell.rotate(Vector3.BACK, ds / BALL_R)
	_lean = lerpf(_lean, clampf(ds * 6.0, -0.25, 0.25), 0.2)


## Called every frame. speed_factor ~ 1 normal, >1 boosted, 0 = stopped.
func tick(delta: float, t: float, _water_vel: float, speed_factor: float, alive: bool, pulling: bool) -> void:
	_pull = lerpf(_pull, 1.0 if (pulling and alive) else 0.0, 1.0 - exp(-12.0 * delta))
	if arm_l:
		var wave := sin(t * 14.0) * 0.12 * _pull
		arm_l.rotation.z = lerpf(0.35, 2.75, _pull) + wave
		arm_r.rotation.z = -lerpf(0.35, 2.75, _pull) - wave
	if captain:
		if riding:
			# running on top: quick bob and arms out for balance
			captain.rotation.z = -_lean * 1.6 + sin(t * 3.1) * 0.08
			captain.position.y = BALL_R * 2.0 - 0.02 + absf(sin(t * 12.0)) * 0.05 * minf(speed_factor, 1.5)
			if arm_l and _pull < 0.5:
				arm_l.rotation.z = 1.2 + sin(t * 12.0) * 0.3
				arm_r.rotation.z = -1.2 + sin(t * 12.0) * 0.3
		else:
			captain.rotation.z = -_lean + sin(t * 2.6) * 0.04 * (1.0 - _pull)
			captain.position.y = 0.08 + absf(sin(t * 7.0)) * 0.02 * speed_factor
	if flag:
		flag.rotation.y = sin(t * 9.0) * 0.35
	if still:
		still.rotation.y += delta * 0.8
	var moving := alive and speed_factor > 0.05
	wake.emitting = moving
	spray.emitting = false
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


func start_trick(kind: int) -> void:
	trick_kind = kind


func trick_progress(u: float) -> void:
	if model == null:
		return
	var e := smoothstep(0.08, 0.85, u) * TAU
	if u >= 1.0:
		e = 0.0
	if captain:
		match trick_kind:
			0: captain.rotation.x = -e
			1: captain.rotation.y = e
			_: captain.rotation.x = e


func reset_pose() -> void:
	pivot.rotation = Vector3.ZERO
	pivot.position = Vector3.ZERO
	if model:
		model.rotation = Vector3.ZERO
		model.position = Vector3.ZERO
		model.scale = Vector3.ONE
	if captain:
		captain.rotation = Vector3.ZERO
	visible = true


func crash() -> void:
	if model == null:
		return
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.35, 0.6, 1.35), 0.08)
	tw.tween_property(model, "scale", Vector3(0.05, 0.05, 0.05), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)


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
	fever_fx.position = Vector3(0.0, 0.62, 0.75)
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
	fever_fire.position = Vector3(0.0, 0.62, -0.6)
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
		"witch":
			var black := _m(Color("1e1b2e"))
			_cyl(0.36, 0.36, 0.03, black, Vector3(0.0, y - 0.03, 0.0), Vector3.ZERO, 18, p)
			_cyl(0.19, 0.02, 0.5, black, Vector3(0.0, y + 0.24, -0.04), Vector3(-0.25, 0.0, 0.0), 12, p)
			_cyl(0.195, 0.18, 0.06, _m(Color("b14dff"), 0.6, 0.0), Vector3(0.0, y + 0.03, 0.0), Vector3.ZERO, 14, p)
			_sphere(0.04, _m(Color("ff7a1a"), 1.2, 0.0), Vector3(0.0, y + 0.03, 0.19), Vector3.ONE, p)
		"santa":
			_cyl(0.2, 0.03, 0.42, _m(Color("e8202e")), Vector3(0.0, y + 0.18, -0.05), Vector3(-0.35, 0.0, 0.0), 12, p)
			_cyl(0.215, 0.215, 0.08, _m(Color("f7f7f2")), Vector3(0.0, y - 0.01, 0.0), Vector3.ZERO, 14, p)
			_sphere(0.07, _m(Color("f7f7f2")), Vector3(0.0, y + 0.33, -0.2), Vector3.ONE, p)
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
	wake.position = Vector3(0.0, 0.04, -0.45)
	wake.amount = 40
	wake.lifetime = 0.9
	wake.local_coords = false
	wake.direction = Vector3(1.0, 0.0, 0.0)
	wake.spread = 180.0
	wake.flatness = 1.0
	wake.initial_velocity_min = 0.3
	wake.initial_velocity_max = 0.9
	wake.gravity = Vector3.ZERO
	wake.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	wake.emission_box_extents = Vector3(0.25, 0.0, 0.1)
	wake.scale_amount_curve = _curve(1.0, 0.2)
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
	s.radius = 0.95
	s.height = 1.9
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
	magnet_fx.position = Vector3(0.0, 1.5, 0.0)
	magnet_fx.scale = Vector3(0.7, 0.7, 0.7)
	magnet_fx.visible = false
	add_child(magnet_fx)
