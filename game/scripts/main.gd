extends Node3D
## MOONPULL — you don't steer the boat, you steer the sea.
## Hold anywhere: the moon rises and pulls the tide up. Release: the tide drains.
## Reefs need high water, bridges need low water, gates need the exact window.

enum State { MENU, PLAYING, COUNTDOWN, DEAD, WON }

const RIVER_W := 8.0
const FLOOR_Y := -0.3
const WATER_MIN := 0.4
const WATER_MAX := 5.6
const WATER_REST := 1.2
const HIT_GRACE := 0.15    # invisible forgiveness in collisions (tuned by simulation)
const ACCEL := 16.0        # how fast the tide changes direction
const DRAFT := 0.3         # hull depth below the waterline
const BOAT_TOP := 1.5      # mast-top height above the waterline
const BOAT_HALF_LEN := 0.9
const CLOSE_CALL := 0.28   # clearance that counts as a near miss
const NONE_LOW := -99.0
const NONE_HIGH := 99.0

var state: State = State.MENU
var level := 1
var speed := 7.0
var rise := 2.6            # tide speed up (units/s) — grows with level
var fall := 2.2            # tide speed down
var water_y := WATER_REST
var water_vel := 0.0
var holding := false
var boat_z := 0.0
var finish_z := 100.0
var obstacles: Array[Dictionary] = []
var pearls: Array[Dictionary] = []
var run_pearls := 0
var continue_used := false
var crash_index := -1
var countdown_left := 0.0
var shake := 0.0
var t := 0.0
var pending_reward := ""

var rng := RandomNumberGenerator.new()
var level_root: Node3D
var water: MeshInstance3D
var boat: Node3D
var boat_pivot: Node3D
var hull_mat: StandardMaterial3D
var camera: Camera3D
var moon: MeshInstance3D
var moon_mat: StandardMaterial3D
var splash: CPUParticles3D
var ui: GameUI
var _mats := {}


func _ready() -> void:
	_setup_environment()
	_build_water()
	_build_boat()
	_build_moon()
	_build_splash()
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 74.0
	camera.far = 280.0
	add_child(camera)
	camera.make_current()
	level_root = Node3D.new()
	add_child(level_root)

	ui = GameUI.new()
	add_child(ui)
	ui.retry_pressed.connect(_on_retry)
	ui.continue_pressed.connect(_on_continue)
	ui.next_pressed.connect(_on_next)
	ui.triple_pressed.connect(_on_triple)
	ui.color_pressed.connect(_on_color)
	ui.buy_pressed.connect(_on_buy)
	Ads.rewarded_finished.connect(_on_rewarded_finished)

	level = Save.level
	_apply_skin()
	_load_level()
	Ads.show_banner()


# =============================================================== input

func _unhandled_input(event: InputEvent) -> void:
	var is_press := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
	elif event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		is_press = event.pressed
	else:
		return
	holding = is_press
	if is_press and state == State.MENU:
		_start_run()


func _start_run() -> void:
	state = State.PLAYING
	ui.show_hud(level)
	ui.set_progress(0.0)


# =============================================================== loop

func _process(delta: float) -> void:
	t += delta
	if holding and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)):
		holding = false

	match state:
		State.MENU:
			var idle := WATER_REST + sin(t * 1.3) * 0.15
			water_y = lerpf(water_y, idle, 1.0 - exp(-3.0 * delta))
		State.PLAYING:
			_update_water(delta)
			boat_z += speed * delta
			_check_obstacles()
			_check_pearls()
			ui.set_progress(clampf(boat_z / finish_z, 0.0, 1.0))
			if boat_z >= finish_z:
				_win()
		State.COUNTDOWN:
			countdown_left -= delta
			ui.set_countdown(ceili(countdown_left))
			if countdown_left <= 0.0:
				ui.set_countdown(0)
				state = State.PLAYING
		State.WON:
			boat_z += speed * 0.45 * delta
			water_vel = 0.0
			water_y = lerpf(water_y, WATER_REST + 0.6, 1.0 - exp(-2.0 * delta))
	_update_scene(delta)


func _update_water(delta: float) -> void:
	var target := rise if holding else -fall
	water_vel = move_toward(water_vel, target, ACCEL * delta)
	water_y += water_vel * delta
	if water_y <= WATER_MIN:
		water_y = WATER_MIN
		water_vel = maxf(water_vel, 0.0)
	elif water_y >= WATER_MAX:
		water_y = WATER_MAX
		water_vel = minf(water_vel, 0.0)


func _update_scene(delta: float) -> void:
	water.position = Vector3(0.0, water_y, boat_z + 70.0)
	boat.position = Vector3(0.0, water_y + sin(t * 3.0) * 0.04, boat_z)
	if state != State.DEAD:
		boat_pivot.rotation.z = sin(t * 2.1) * 0.05
		boat_pivot.rotation.x = clampf(-water_vel * 0.05, -0.18, 0.18)

	var cam_goal := Vector3(1.4, water_y * 0.6 + 4.7, boat_z - 8.4)
	camera.position = camera.position.lerp(cam_goal, 1.0 - exp(-7.0 * delta))
	if camera.position.distance_to(cam_goal) > 12.0:
		camera.position = cam_goal
	if shake > 0.0:
		camera.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake
		shake = maxf(shake - delta * 1.6, 0.0)
	camera.look_at(Vector3(0.0, water_y * 0.6 + 1.1, boat_z + 9.0), Vector3.UP)

	# The moon is your hand: it rises with the tide and glows while you pull.
	moon.position = Vector3(-8.0, 15.0 + (water_y - WATER_MIN) * 2.8, boat_z + 78.0)
	var glow := 2.6 if holding else 1.3
	moon_mat.emission_energy_multiplier = lerpf(moon_mat.emission_energy_multiplier, glow, 1.0 - exp(-6.0 * delta))

	for p in pearls:
		if p.taken:
			continue
		var n: Node3D = p.node
		n.rotation.y += delta * 2.0
		n.position.y = p.y + sin(t * 3.0 + p.z) * 0.12


# =============================================================== rules

func _check_obstacles() -> void:
	var front := boat_z + BOAT_HALF_LEN
	var back := boat_z - BOAT_HALF_LEN
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		if o.passed:
			continue
		var o_start: float = o.z - o.depth * 0.5
		var o_end: float = o.z + o.depth * 0.5
		if front < o_start:
			break  # obstacles are sorted by z
		if back > o_end:
			o.passed = true
			if o.min_clear < CLOSE_CALL:
				_close_call()
			continue
		var clear := NONE_HIGH
		if o.h > NONE_LOW:
			clear = minf(clear, (water_y - DRAFT) - o.h)
		if o.b < NONE_HIGH:
			clear = minf(clear, (o.b - BOAT_TOP) - water_y)
		if clear + HIT_GRACE < 0.0:
			_crash(i)
			return
		o.min_clear = minf(o.min_clear, clear)


func _check_pearls() -> void:
	for p in pearls:
		if p.taken:
			continue
		if absf(p.z - boat_z) < 1.0 and absf((water_y + 0.7) - p.y) < 0.95:
			p.taken = true
			run_pearls += 1
			ui.set_pearls(Save.pearls + run_pearls)
			Sfx.play("pearl")
			var n: Node3D = p.node
			var tw := create_tween()
			tw.tween_property(n, "scale", Vector3.ZERO, 0.18)
			tw.tween_callback(n.hide)


func _close_call() -> void:
	run_pearls += 2
	ui.set_pearls(Save.pearls + run_pearls)
	ui.popup("CLOSE CALL!  +2")
	Sfx.play("close")
	Input.vibrate_handheld(25)


func _crash(i: int) -> void:
	state = State.DEAD
	crash_index = i
	holding = false
	water_vel = 0.0
	shake = 0.45
	Sfx.play("crash")
	Input.vibrate_handheld(140)
	splash.global_position = boat.global_position + Vector3(0.0, 0.4, 0.9)
	splash.restart()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(boat_pivot, "rotation", Vector3(-0.45, 0.3, 1.25), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(boat_pivot, "position", Vector3(0.0, -0.7, -0.6), 0.7)
	await get_tree().create_timer(0.75).timeout
	if state == State.DEAD:
		ui.show_lose(not continue_used, run_pearls)


func _win() -> void:
	state = State.WON
	holding = false
	Sfx.play("win")
	Input.vibrate_handheld(40)
	Save.add_pearls(run_pearls)
	Save.set_level(level + 1)
	ui.set_pearls(Save.pearls)
	ui.show_win(level, run_pearls)


func _revive() -> void:
	continue_used = true
	var o: Dictionary = obstacles[crash_index]
	o.passed = false
	o.min_clear = NONE_HIGH
	var lo := WATER_MIN
	var hi := WATER_MAX
	if o.h > NONE_LOW:
		lo = o.h + DRAFT + 0.1
	if o.b < NONE_HIGH:
		hi = o.b - BOAT_TOP - 0.1
	water_y = (lo + hi) * 0.5 if hi < WATER_MAX else minf(lo + 0.6, WATER_MAX)
	water_vel = 0.0
	var back_to: float = o.z - o.depth * 0.5 - BOAT_HALF_LEN - speed * 1.3
	if crash_index > 0:
		var prev: Dictionary = obstacles[crash_index - 1]
		back_to = maxf(back_to, prev.z + prev.depth * 0.5 + BOAT_HALF_LEN + 0.4)
	boat_z = back_to
	boat_pivot.rotation = Vector3.ZERO
	boat_pivot.position = Vector3.ZERO
	state = State.COUNTDOWN
	countdown_left = 2.0
	ui.show_hud(level)
	ui.set_countdown(2)


# =============================================================== buttons

func _on_retry() -> void:
	await _maybe_interstitial()
	_load_level()


func _on_next() -> void:
	level = Save.level
	await _maybe_interstitial()
	_load_level()


func _on_continue() -> void:
	if not Ads.is_rewarded_ready():
		ui.popup("Ad not ready yet", Color("ff9b8b"))
		return
	pending_reward = "continue"
	ui.block(true)
	Ads.show_rewarded()


func _on_triple() -> void:
	if not Ads.is_rewarded_ready():
		ui.popup("Ad not ready yet", Color("ff9b8b"))
		return
	pending_reward = "triple"
	ui.block(true)
	Ads.show_rewarded()


func _on_rewarded_finished(earned: bool) -> void:
	ui.block(false)
	var what := pending_reward
	pending_reward = ""
	match what:
		"continue":
			if earned and state == State.DEAD:
				_revive()
		"triple":
			if earned and state == State.WON:
				Save.add_pearls(run_pearls * 2)
				ui.set_pearls(Save.pearls)
				ui.set_win_pearls(run_pearls * 3)
				Sfx.play("win")


func _maybe_interstitial() -> void:
	if Ads.round_ended_should_show(level):
		ui.block(true)
		Ads.show_interstitial()
		await Ads.interstitial_closed
		ui.block(false)


func _on_color() -> void:
	Save.cycle_skin()
	_apply_skin()
	ui.refresh_shop()


func _on_buy() -> void:
	if Save.buy_next_skin():
		_apply_skin()
		Sfx.play("win")
		ui.set_pearls(Save.pearls)
	ui.refresh_shop()


func _apply_skin() -> void:
	hull_mat.albedo_color = Save.skin_color()


# =============================================================== level

func _load_level() -> void:
	for c in level_root.get_children():
		c.queue_free()
	obstacles.clear()
	pearls.clear()
	run_pearls = 0
	continue_used = false
	crash_index = -1
	boat_z = 0.0
	water_y = WATER_REST
	water_vel = 0.0
	holding = false
	boat_pivot.rotation = Vector3.ZERO
	boat_pivot.position = Vector3.ZERO
	_generate(level)
	state = State.MENU
	ui.set_countdown(0)
	ui.show_menu(level, Save.pearls)


func _generate(lv: int) -> void:
	rng.seed = lv * 7919 + 1234
	speed = minf(7.0 + (lv - 1) * 0.35, 13.0)
	var ramp := minf((lv - 1) / 12.0, 1.0)
	rise = 2.6 + 0.8 * ramp
	fall = 2.2 + 0.6 * ramp
	var count := mini(6 + lv * 2, 30)
	var window := maxf(1.8 - (lv - 1) * 0.07, 0.8)       # gate opening for the waterline
	var reaction := maxf(0.95 - (lv - 1) * 0.03, 0.5)    # seconds of slack between obstacles
	var gate_chance := clampf(0.05 + (lv - 1) * 0.04, 0.05, 0.45)
	var z := 32.0
	var prev_level := WATER_REST

	for i in count:
		var kind := "rock"
		var roll := rng.randf()
		if lv == 1 and i == 1:
			kind = "bridge"
		elif lv == 1 and i == 0:
			kind = "rock"
		elif roll < gate_chance:
			kind = "gate"
		elif roll < gate_chance + (1.0 - gate_chance) * 0.5:
			kind = "rock"
		else:
			kind = "bridge"

		var o := {"kind": kind, "z": 0.0, "depth": 1.4, "h": NONE_LOW, "b": NONE_HIGH,
			"passed": false, "min_clear": NONE_HIGH}
		var natural := WATER_REST
		match kind:
			"rock":
				o.h = rng.randf_range(0.7, 3.4)
				natural = o.h + DRAFT + 0.5
			"bridge":
				o.b = rng.randf_range(2.7, 6.3)
				natural = o.b - BOAT_TOP - 0.5
			"gate":
				var center := rng.randf_range(1.6, 4.3)
				o.h = center - window * 0.5 - DRAFT
				o.b = center + window * 0.5 + BOAT_TOP
				natural = center
		natural = clampf(natural, WATER_MIN, WATER_MAX)

		var dist := absf(natural - prev_level)
		var move_time := dist / (rise if natural > prev_level else fall)
		var spacing := speed * (reaction + move_time * 1.3) + 3.0 + rng.randf_range(0.0, speed * 0.5)

		if rng.randf() < 0.75:
			var py := lerpf(prev_level, natural, rng.randf_range(0.3, 0.7)) + 0.7 + rng.randf_range(-0.3, 0.5)
			_spawn_pearl(Vector3(0.0, clampf(py, WATER_MIN + 0.7, WATER_MAX + 0.6), z + spacing * 0.5))

		z += spacing
		o.z = z
		obstacles.append(o)
		_spawn_obstacle(o)
		prev_level = natural

	finish_z = z + speed * 2.5 + 8.0
	_spawn_finish(finish_z)
	_spawn_canyon(finish_z + 90.0)


# =============================================================== builders

func _mat(key: String, color: Color, rough := 0.9, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _cone(parent: Node3D, bottom_r: float, top_r: float, height: float, pos: Vector3, mat: Material, sides := 6) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.bottom_radius = bottom_r
	cm.top_radius = top_r
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("1b1d4a")
	sky_mat.sky_horizon_color = Color("f2a07b")
	sky_mat.ground_horizon_color = Color("f2a07b")
	sky_mat.ground_bottom_color = Color("2a1f3d")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("e89a86")
	env.fog_density = 0.006
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	sun.light_color = Color("ffd9b8")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(RIVER_W + 8.0, 230.0)
	pm.subdivide_width = 12
	pm.subdivide_depth = 115
	water = MeshInstance3D.new()
	water.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/water.gdshader")
	water.material_override = sm
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_boat() -> void:
	boat = Node3D.new()
	add_child(boat)
	boat_pivot = Node3D.new()
	boat.add_child(boat_pivot)
	hull_mat = StandardMaterial3D.new()
	hull_mat.roughness = 0.55
	var white := _mat("boat_white", Color("f4f1ea"), 0.7)
	var wood := _mat("boat_wood", Color("6e4b33"), 0.8)

	_box(boat_pivot, Vector3(1.2, 0.5, 2.0), Vector3(0.0, 0.05, -0.1), hull_mat)
	var bow := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.2, 0.8, 0.5)  # apex (y) is rotated to point forward (+z)
	bow.mesh = prism
	bow.material_override = hull_mat
	bow.rotation.x = PI * 0.5
	bow.position = Vector3(0.0, 0.05, 1.3)
	boat_pivot.add_child(bow)
	_box(boat_pivot, Vector3(1.26, 0.08, 2.04), Vector3(0.0, 0.31, -0.1), white)
	_box(boat_pivot, Vector3(0.8, 0.45, 0.7), Vector3(0.0, 0.55, -0.6), white)
	_box(boat_pivot, Vector3(0.82, 0.08, 0.72), Vector3(0.0, 0.8, -0.6), hull_mat)
	_cone(boat_pivot, 0.05, 0.05, 1.1, Vector3(0.0, 0.85, 0.15), wood)
	var sail := MeshInstance3D.new()
	var sp := PrismMesh.new()
	sp.left_to_right = 0.0
	sp.size = Vector3(0.9, 0.95, 0.04)
	sail.mesh = sp
	sail.material_override = white
	sail.rotation.y = PI * 0.5
	sail.position = Vector3(0.0, 0.9, -0.3)
	boat_pivot.add_child(sail)
	_box(boat_pivot, Vector3(0.03, 0.18, 0.32), Vector3(0.0, 1.41, -0.02), hull_mat)


func _build_moon() -> void:
	moon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 4.0
	sm.height = 8.0
	moon.mesh = sm
	moon_mat = StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color("fff3d6")
	moon_mat.emission_enabled = true
	moon_mat.emission = Color("fff0c9")
	moon_mat.emission_energy_multiplier = 1.3
	moon_mat.set("disable_fog", true)
	moon.material_override = moon_mat
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)


func _build_splash() -> void:
	splash = CPUParticles3D.new()
	splash.emitting = false
	splash.one_shot = true
	splash.amount = 48
	splash.lifetime = 0.9
	splash.explosiveness = 0.95
	splash.direction = Vector3(0.0, 1.0, 0.0)
	splash.spread = 65.0
	splash.initial_velocity_min = 3.0
	splash.initial_velocity_max = 7.5
	splash.gravity = Vector3(0.0, -14.0, 0.0)
	var drop := SphereMesh.new()
	drop.radius = 0.12
	drop.height = 0.24
	drop.radial_segments = 6
	drop.rings = 3
	splash.mesh = drop
	splash.material_override = _mat("foam", Color("e8fbff"), 0.3)
	add_child(splash)


func _spawn_obstacle(o: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, o.z)
	level_root.add_child(root)
	if o.h > NONE_LOW:
		_build_reef(root, o.h)
	if o.b < NONE_HIGH:
		_build_bridge(root, o.b)


func _build_reef(root: Node3D, h: float) -> void:
	var rock := _mat("rock", Color("4b4256"), 0.95)
	var tip := _mat("rock_tip", Color("7a5f73"), 0.9)
	var base_h := maxf(h * 0.55, 0.25) - FLOOR_Y
	_box(root, Vector3(RIVER_W + 0.4, base_h, 1.2), Vector3(0.0, FLOOR_Y + base_h * 0.5, 0.0), rock)
	var spikes := 6
	for i in spikes:
		var x := lerpf(-RIVER_W * 0.5 + 0.6, RIVER_W * 0.5 - 0.6, float(i) / (spikes - 1))
		var top := h if i % 2 == 0 else h * rng.randf_range(0.8, 0.96)  # the tallest spikes are exactly h
		var height := top - FLOOR_Y
		var spike := _cone(root, rng.randf_range(0.6, 0.85), 0.08, height,
			Vector3(x, FLOOR_Y + height * 0.5, rng.randf_range(-0.2, 0.2)),
			tip if i % 2 == 0 else rock)
		spike.rotation.y = rng.randf() * TAU


func _build_bridge(root: Node3D, b: float) -> void:
	var wood := _mat("wood", Color("9a6340"), 0.85)
	var dark := _mat("wood_dark", Color("5b3a28"), 0.9)
	var lamp := _mat("lantern", Color("ffcf6b"), 0.5, Color("ffb347"), 2.2)
	var span := RIVER_W + 2.6
	_box(root, Vector3(span, 0.5, 1.4), Vector3(0.0, b + 0.25, 0.0), wood)
	_box(root, Vector3(span, 0.1, 1.5), Vector3(0.0, b + 0.05, 0.0), dark)
	for s in [-1.0, 1.0]:
		var ph := b - FLOOR_Y
		_box(root, Vector3(0.8, ph, 0.9), Vector3(s * (RIVER_W * 0.5 + 0.5), FLOOR_Y + ph * 0.5, 0.0), dark)
		_box(root, Vector3(0.25, 0.35, 0.25), Vector3(s * (RIVER_W * 0.5 - 0.3), b + 0.75, 0.0), lamp)
	for rz in [-0.62, 0.62]:
		_box(root, Vector3(span, 0.1, 0.1), Vector3(0.0, b + 0.95, rz), wood)
		for k in 7:
			var px := lerpf(-span * 0.5 + 0.3, span * 0.5 - 0.3, k / 6.0)
			_box(root, Vector3(0.1, 0.45, 0.1), Vector3(px, b + 0.72, rz), dark)


func _spawn_pearl(pos: Vector3) -> void:
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	sm.radial_segments = 12
	sm.rings = 6
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = _mat("pearl", Color("fff4e6"), 0.2, Color("ffe4bd"), 1.3)
	mi.position = pos
	level_root.add_child(mi)
	pearls.append({"node": mi, "y": pos.y, "z": pos.z, "taken": false})


func _spawn_finish(z: float) -> void:
	var root := Node3D.new()
	root.position = Vector3(0.0, 0.0, z)
	level_root.add_child(root)
	var red := _mat("lh_red", Color("e2463f"), 0.7)
	var white := _mat("lh_white", Color("f6f2ea"), 0.7)
	var light := _mat("lh_light", Color("fff1b0"), 0.3, Color("ffe08a"), 4.0)
	for s in [-1.0, 1.0]:
		var x: float = s * (RIVER_W * 0.5 + 0.2)
		for k in 7:
			_cone(root, 0.75 - k * 0.04, 0.71 - k * 0.04, 1.4, Vector3(x, FLOOR_Y + 0.7 + k * 1.4, 0.0), red if k % 2 == 0 else white, 10)
		_cone(root, 0.5, 0.5, 0.8, Vector3(x, FLOOR_Y + 10.2, 0.0), light, 10)
		_cone(root, 0.6, 0.0, 0.7, Vector3(x, FLOOR_Y + 10.95, 0.0), red, 10)
	for k in 10:  # checkered finish banner, high enough to never block
		var bx := lerpf(-RIVER_W * 0.5 + 0.9, RIVER_W * 0.5 - 0.9, k / 9.0)
		_box(root, Vector3(0.62, 0.6, 0.1), Vector3(bx, 8.2, 0.0), white if k % 2 == 0 else _mat("ink", Color("1e1b2e"), 0.8))


func _spawn_canyon(length: float) -> void:
	var cols: Array[Color] = [Color("c98a5e"), Color("b9764f"), Color("d79a6a"), Color("a86a48")]
	var z := -40.0
	while z < length:
		var seg := rng.randf_range(6.0, 11.0)
		for s in [-1.0, 1.0]:
			var top := rng.randf_range(7.2, 9.4)
			var hgt := top - FLOOR_Y + 1.0
			var col: Color = cols[rng.randi() % cols.size()]
			var inset := rng.randf_range(0.0, 0.6)
			_box(level_root, Vector3(30.0, hgt, seg + 0.02),
				Vector3(s * (RIVER_W * 0.5 + 1.0 + inset + 15.0), FLOOR_Y - 1.0 + hgt * 0.5, z + seg * 0.5),
				_mat("wall_" + col.to_html(), col, 0.95))
			if rng.randf() < 0.5:
				_tree(Vector3(s * rng.randf_range(RIVER_W * 0.5 + 2.6, RIVER_W * 0.5 + 10.0), top, z + rng.randf_range(0.0, seg)))
		z += seg
	_box(level_root, Vector3(RIVER_W + 4.0, 1.0, length + 60.0),
		Vector3(0.0, FLOOR_Y - 0.5, (length - 40.0) * 0.5 - 10.0), _mat("sand", Color("d9c08f"), 1.0))


func _tree(base: Vector3) -> void:
	var trunk := _mat("trunk", Color("5b3d2b"), 0.9)
	var leaves := _mat("leaves", Color("2f6b5a"), 0.9)
	var scale_f := rng.randf_range(0.8, 1.4)
	_cone(level_root, 0.18 * scale_f, 0.12 * scale_f, 0.8 * scale_f, base + Vector3(0.0, 0.4 * scale_f, 0.0), trunk)
	_cone(level_root, 0.95 * scale_f, 0.0, 2.1 * scale_f, base + Vector3(0.0, 1.85 * scale_f, 0.0), leaves, 7)
