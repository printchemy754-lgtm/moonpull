extends Node3D
## MOONPULL — you don't steer the boat, you steer the sea.
## Hold anywhere: the moon rises and pulls the tide up. Release: the tide drains.
## Game flow, rules, camera and the CI autotest live here.

enum State { MENU, SHOP, PLAYING, PAUSED, COUNTDOWN, DEAD, WON }

const ACCEL := 16.0          # how fast the tide changes direction
const CLOSE_CALL := 0.28     # clearance that counts as a near miss
const SHOP_AD_REWARD := 60

var state: State = State.MENU
var level := 1
var data: Dictionary = {}
var speed := 7.0
var rise := 2.6
var fall := 2.2
var water_y := LevelGen.WATER_REST
var water_vel := 0.0
var holding := false
var boat_z := 0.0
var run_t := 0.0
var t := 0.0

var boost_left := 0.0
var slow_left := 0.0
var magnet_left := 0.0
var shield := false
var run_pearls := 0
var pearls_got := 0
var pearls_total := 0
var streak := 0
var streak_timer := 0.0
var continue_used := false
var crash_index := -1
var countdown_left := 0.0
var shake := 0.0
var pending_reward := ""
var shop_index := 0
var cam_mode := "menu"
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var cam_ready := false

var world: GameWorld
var boat: Boat
var camera: Camera3D
var ui: GameUI

# autotest (CI): `godot --headless --fixed-fps 60 -- --autotest`
var autotest := false
var at_frames := 0
var at_wait := 0.0
var at_crashes := 0
var at_level_crashes := 0
var at_paused := false
const AT_LEVELS := 14


func _ready() -> void:
	world = GameWorld.new()
	add_child(world)
	boat = Boat.new()
	add_child(boat)
	boat.set_model(Save.boat)
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 60.0
	camera.far = 300.0
	add_child(camera)
	camera.make_current()

	ui = GameUI.new()
	add_child(ui)
	ui.settings_pressed.connect(_on_settings)
	ui.toggle_changed.connect(_on_toggle)
	ui.boats_pressed.connect(_on_boats)
	ui.shop_back.connect(_on_shop_back)
	ui.shop_prev.connect(func(): _shop_step(-1))
	ui.shop_next.connect(func(): _shop_step(1))
	ui.shop_action.connect(_on_shop_action)
	ui.shop_ad.connect(_on_shop_ad)
	ui.pause_pressed.connect(_on_pause)
	ui.resume_pressed.connect(_on_resume)
	ui.restart_pressed.connect(_on_retry)
	ui.home_pressed.connect(_on_home)
	ui.retry_pressed.connect(_on_retry)
	ui.continue_pressed.connect(_on_continue)
	ui.next_pressed.connect(_on_next)
	ui.triple_pressed.connect(_on_triple)
	Ads.rewarded_finished.connect(_on_rewarded_finished)

	autotest = "--autotest" in OS.get_cmdline_user_args()
	if autotest:
		print("AUTOTEST start")
		Save.level = 1
		Save.pearls = 5000
		Save.seen = []
		at_wait = 1.0
	level = Save.level
	_load_level()
	ui.fade_in()
	Ads.show_banner()
	if autotest:
		call_deferred("_autotest_menus")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and (state == State.PLAYING or state == State.COUNTDOWN):
		_on_pause()


# =============================================================== input

func _unhandled_input(event: InputEvent) -> void:
	if autotest:
		return
	var is_press := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = event.pressed
	elif event is InputEventKey and event.keycode == KEY_SPACE and not event.echo:
		is_press = event.pressed
	elif event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if state == State.PLAYING:
			_on_pause()
		return
	else:
		return
	holding = is_press
	if is_press and state == State.MENU:
		_start_run()


func _start_run() -> void:
	state = State.PLAYING
	cam_mode = "chase"
	ui.show_hud(level)


# =============================================================== loop

func _process(delta: float) -> void:
	t += delta
	if autotest:
		_autotest_tick(delta)
	elif holding and not (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE)):
		holding = false
	if state != State.PAUSED:
		run_t += delta

	var factor := 0.0
	match state:
		State.MENU, State.SHOP:
			var idle := LevelGen.WATER_REST + sin(t * 1.3) * 0.15
			water_y = lerpf(water_y, idle, 1.0 - exp(-3.0 * delta))
			water_vel = 0.0
		State.PLAYING:
			_update_water(delta)
			factor = _speed_factor()
			boat_z += speed * factor * delta
			_tick_effects(delta)
			_check_items()
			_check_pearls()
			_intros()
			_tutorial()
			ui.set_progress(clampf(boat_z / world.finish_z, 0.0, 1.0))
			if boat_z >= world.finish_z and state == State.PLAYING:
				_win()
		State.COUNTDOWN:
			countdown_left -= delta
			ui.set_countdown(ceili(countdown_left))
			if countdown_left <= 0.0:
				ui.set_countdown(0)
				state = State.PLAYING
		State.WON:
			factor = 0.5
			boat_z += speed * 0.45 * delta
			water_vel = 0.0
			water_y = lerpf(water_y, LevelGen.WATER_REST + 0.6, 1.0 - exp(-2.0 * delta))

	boat.position = Vector3(0.0, water_y, boat_z)
	boat.tick(delta, t, water_vel, factor, state != State.DEAD)
	world.update(delta, run_t, t, water_y, boat_z, holding and state == State.PLAYING)
	_update_camera(delta)


func _speed_factor() -> float:
	var f := 1.0
	if boost_left > 0.0:
		f *= LevelGen.BOOST_MULT
	if slow_left > 0.0:
		f *= LevelGen.SLOW_MULT
	return f


func _update_water(delta: float) -> void:
	var target := rise if holding else -fall
	water_vel = move_toward(water_vel, target, ACCEL * delta)
	water_y += water_vel * delta
	if water_y <= LevelGen.WATER_MIN:
		water_y = LevelGen.WATER_MIN
		water_vel = maxf(water_vel, 0.0)
	elif water_y >= LevelGen.WATER_MAX:
		water_y = LevelGen.WATER_MAX
		water_vel = minf(water_vel, 0.0)


func _tick_effects(delta: float) -> void:
	boost_left = maxf(boost_left - delta, 0.0)
	slow_left = maxf(slow_left - delta, 0.0)
	if magnet_left > 0.0:
		magnet_left = maxf(magnet_left - delta, 0.0)
		if magnet_left == 0.0:
			boat.show_magnet(false)
	streak_timer = maxf(streak_timer - delta, 0.0)
	if streak_timer == 0.0:
		streak = 0
	ui.set_effects({"boost": boost_left, "slow": slow_left, "shield": -1.0 if shield else 0.0, "magnet": magnet_left})


func _update_camera(delta: float) -> void:
	var bp := Vector3(0.0, water_y, boat_z)
	var pos: Vector3
	var look: Vector3
	var fov := 74.0
	var rate := 7.0
	match cam_mode:
		"menu":
			var a := t * 0.15
			pos = bp + Vector3(4.4 + sin(a) * 0.5, 2.4, 5.0 + cos(a) * 0.5)
			look = bp + Vector3(0.0, 0.9, 0.4)
			fov = 62.0
			rate = 3.0
		"shop":
			var a2 := t * 0.45
			pos = bp + Vector3(sin(a2) * 3.9, 1.8, cos(a2) * 3.9)
			look = bp + Vector3(0.0, 0.55, 0.0)
			fov = 58.0
			rate = 4.0
		"win":
			pos = bp + Vector3(5.2, 2.8, 2.5)
			look = bp + Vector3(0.0, 1.0, 1.5)
			fov = 64.0
			rate = 2.5
		_:
			pos = Vector3(1.4, water_y * 0.6 + 4.7, boat_z - 8.4)
			look = Vector3(0.0, water_y * 0.6 + 1.1, boat_z + 9.0)
			fov = 74.0 + (9.0 if boost_left > 0.0 else 0.0) - (4.0 if slow_left > 0.0 else 0.0)
	var k := 1.0 - exp(-rate * delta)
	if not cam_ready:
		cam_pos = pos
		cam_look = look
		cam_ready = true
	cam_pos = cam_pos.lerp(pos, k)
	cam_look = cam_look.lerp(look, k)
	camera.position = cam_pos
	if shake > 0.0:
		camera.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake
		shake = maxf(shake - delta * 1.6, 0.0)
	camera.look_at(cam_look, Vector3.UP)
	camera.fov = lerpf(camera.fov, fov, k)


# =============================================================== rules

func _check_items() -> void:
	var front := boat_z + LevelGen.BOAT_HALF_LEN
	var back := boat_z - LevelGen.BOAT_HALF_LEN
	for i in world.items.size():
		var e: Dictionary = world.items[i]
		if e.passed:
			continue
		var z0: float = e.z - e.depth * 0.5
		var z1: float = e.z + e.depth * 0.5
		if front < z0:
			break  # items are sorted by z
		var obstacle := LevelGen.is_obstacle(e.kind)
		if back > z1:
			e.passed = true
			if obstacle and e.min_clear < CLOSE_CALL and not e.get("smashed", false):
				_close_call()
			continue
		if obstacle:
			if e.get("smashed", false):
				continue
			var clear := LevelGen.NONE_HIGH
			var h := LevelGen.h_at(e, run_t)
			var b := LevelGen.b_at(e, run_t)
			if h > LevelGen.NONE_LOW:
				clear = minf(clear, water_y - LevelGen.DRAFT - h)
			if b < LevelGen.NONE_HIGH:
				clear = minf(clear, b - LevelGen.BOAT_TOP - water_y)
			if clear + LevelGen.HIT_GRACE < 0.0:
				if shield:
					_use_shield(e)
					continue
				_crash(i)
				return
			e.min_clear = minf(e.min_clear, clear)
		elif not e.taken and absf(water_y + LevelGen.PICK_OFFSET - float(e.y)) < LevelGen.PICK_RANGE * 1.2:
			_take_pickup(e)


func _check_pearls() -> void:
	for p in world.pearls:
		if p.taken:
			continue
		var dz: float = p.z - boat_z
		if dz < -2.0 or dz > 10.0:
			continue
		var hit := absf(dz) < 1.0 and absf(water_y + LevelGen.PICK_OFFSET - float(p.y)) < LevelGen.PICK_RANGE
		var pulled := magnet_left > 0.0 and dz > -1.0 and dz < 9.0
		if hit or pulled:
			_collect(p)


func _collect(p: Dictionary) -> void:
	world.take_pearl(p, boat.global_position + Vector3(0.0, 1.0, 0.0))
	var value := 2 if boost_left > 0.0 else 1
	run_pearls += value
	pearls_got += 1
	streak = mini(streak + 1, 10)
	streak_timer = 1.4
	Sfx.play("pearl", 1.0 + streak * 0.06)
	ui.set_pearls(Save.pearls + run_pearls)
	ui.bump_pearls()


func _take_pickup(e: Dictionary) -> void:
	world.take_pickup(e)
	Sfx.vibrate(30)
	match e.kind:
		"boost":
			boost_left = LevelGen.BOOST_TIME
			Sfx.play("boost")
			ui.popup("SPEED!  x2 PEARLS", Color("ffc531"))
		"slow":
			slow_left = LevelGen.SLOW_TIME
			Sfx.play("slow")
			ui.popup("SLOW-MO", Color("8fd8ff"))
		"shield":
			shield = true
			boat.show_shield(true)
			Sfx.play("power")
			ui.popup("SHIELD!", Color("54e0ff"))
		"magnet":
			magnet_left = LevelGen.MAGNET_TIME
			boat.show_magnet(true)
			Sfx.play("power")
			ui.popup("MAGNET!", Color("ff4fd8"))


func _use_shield(e: Dictionary) -> void:
	shield = false
	boat.show_shield(false)
	world.smash(e)
	shake = 0.25
	Sfx.play("shield_pop")
	Sfx.vibrate(60)
	ui.popup("SAVED BY SHIELD!", Color("54e0ff"))


func _close_call() -> void:
	run_pearls += 2
	ui.set_pearls(Save.pearls + run_pearls)
	ui.popup("CLOSE CALL!  +2")
	Sfx.play("close")
	Sfx.vibrate(25)


func _crash(i: int) -> void:
	state = State.DEAD
	crash_index = i
	holding = false
	water_vel = 0.0
	shake = 0.45
	Sfx.play("crash")
	Sfx.vibrate(140)
	world.burst_splash(boat.global_position + Vector3(0.0, 0.4, 0.9))
	boat.crash()
	ui.hide_hint()
	await get_tree().create_timer(0.75).timeout
	if state == State.DEAD:
		ui.show_lose(not continue_used, clampf(boat_z / world.finish_z, 0.0, 1.0), run_pearls)


func _stars() -> int:
	var ratio := float(pearls_got) / maxf(float(pearls_total), 1.0)
	if ratio >= 0.85:
		return 3
	if ratio >= 0.5:
		return 2
	return 1


func _win() -> void:
	state = State.WON
	holding = false
	cam_mode = "win"
	ui.hide_hint()
	var stars := _stars()
	Sfx.play("win")
	Sfx.vibrate(40)
	Save.add_pearls(run_pearls)
	Save.set_stars(level, stars)
	Save.set_level(level + 1)
	ui.set_pearls(Save.pearls)
	world.open_chest()
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.5, 3.0))
	boost_left = 0.0
	slow_left = 0.0
	ui.set_effects({})
	await get_tree().create_timer(0.9).timeout
	if state == State.WON:
		ui.show_win(level, stars, run_pearls)


func _revive() -> void:
	continue_used = true
	var e: Dictionary = world.items[crash_index]
	e.passed = false
	e.min_clear = LevelGen.NONE_HIGH
	var lo := LevelGen.WATER_MIN
	var hi := LevelGen.WATER_MAX
	match e.kind:
		"drawbridge":
			hi = float(e.b) - float(e.amp) - LevelGen.BOAT_TOP - 0.15
		"breather":
			lo = float(e.h) + float(e.amp) + LevelGen.DRAFT + 0.15
		_:
			if e.h > LevelGen.NONE_LOW:
				lo = float(e.h) + LevelGen.DRAFT + 0.1
			if e.b < LevelGen.NONE_HIGH:
				hi = float(e.b) - LevelGen.BOAT_TOP - 0.1
	water_y = (lo + hi) * 0.5 if hi < LevelGen.WATER_MAX else minf(lo + 0.6, LevelGen.WATER_MAX)
	water_vel = 0.0
	var back_to: float = e.z - e.depth * 0.5 - LevelGen.BOAT_HALF_LEN - speed * 1.3
	for j in range(crash_index - 1, -1, -1):
		var prev: Dictionary = world.items[j]
		if LevelGen.is_obstacle(prev.kind):
			back_to = maxf(back_to, prev.z + prev.depth * 0.5 + LevelGen.BOAT_HALF_LEN + 0.4)
			break
	boat_z = back_to
	boat.reset_pose()
	state = State.COUNTDOWN
	countdown_left = 2.0
	ui.show_hud(level)
	ui.set_countdown(2)


# =============================================================== intro & tutorial

func _next_obstacle() -> Dictionary:
	for e in world.items:
		if not e.passed and LevelGen.is_obstacle(e.kind) and not e.get("smashed", false):
			return e
	return {}


func _intros() -> void:
	for e in world.items:
		if e.passed:
			continue
		var dz: float = e.z - boat_z
		if dz > 32.0:
			return
		var kind: String = e.kind
		if LevelGen.INTROS.has(kind) and not Save.seen.has(kind):
			Save.mark_seen(kind)
			var info: Array = LevelGen.INTROS[kind]
			ui.intro(info[0], info[1])
			return


func _tutorial() -> void:
	if level > 2:
		return
	var e := _next_obstacle()
	if e.is_empty() or float(e.z) - boat_z > 24.0:
		ui.hide_hint()
		return
	var r := LevelGen.safe_range(e, run_t)
	if water_y < r.x + 0.1:
		ui.hint("HOLD TO RAISE THE TIDE", true)
	elif water_y > r.y - 0.1:
		ui.hint("LET GO TO LOWER IT", false)
	else:
		ui.hide_hint()


# =============================================================== level flow

func _load_level() -> void:
	data = LevelGen.generate(level)
	speed = data.speed
	rise = data.rise
	fall = data.fall
	world.build_level(data, level)
	pearls_total = world.pearls.size()
	run_pearls = 0
	pearls_got = 0
	continue_used = false
	crash_index = -1
	boat_z = 0.0
	run_t = 0.0
	water_y = LevelGen.WATER_REST
	water_vel = 0.0
	holding = false
	boost_left = 0.0
	slow_left = 0.0
	magnet_left = 0.0
	shield = false
	streak = 0
	boat.reset_pose()
	boat.set_model(Save.boat)
	boat.show_shield(false)
	boat.show_magnet(false)
	state = State.MENU
	cam_mode = "menu"
	ui.set_countdown(0)
	ui.hide_hint()
	ui.set_effects({})
	_show_menu()


func _show_menu() -> void:
	var th := Themes.for_level(level)
	ui.show_menu(level, Save.pearls, th.name, Themes.world_index(level) + 1, Themes.step_in_world(level), Save.total_stars())


func _transition_to_level() -> void:
	await ui.fade_out(0.25).finished
	_load_level()
	ui.fade_in()


func _maybe_interstitial() -> void:
	if Ads.round_ended_should_show(level):
		ui.block(true)
		Ads.show_interstitial()
		await Ads.interstitial_closed
		ui.block(false)


func _on_retry() -> void:
	if state == State.PAUSED or state == State.DEAD or state == State.PLAYING:
		state = State.DEAD
	await _maybe_interstitial()
	await _transition_to_level()


func _on_next() -> void:
	level = Save.level
	await _maybe_interstitial()
	await _transition_to_level()


func _on_home() -> void:
	state = State.DEAD
	await _transition_to_level()


func _on_pause() -> void:
	if state != State.PLAYING and state != State.COUNTDOWN:
		return
	state = State.PAUSED
	holding = false
	ui.show_pause()


func _on_resume() -> void:
	if state != State.PAUSED:
		return
	ui.show_hud(level)
	ui.set_progress(clampf(boat_z / world.finish_z, 0.0, 1.0))
	state = State.COUNTDOWN
	countdown_left = 1.5
	ui.set_countdown(2)


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
	if not earned:
		return
	match what:
		"continue":
			if state == State.DEAD:
				_revive()
		"triple":
			if state == State.WON:
				Save.add_pearls(run_pearls * 2)
				ui.set_pearls(Save.pearls)
				ui.set_win_pearls(run_pearls * 3)
				Sfx.play("buy")
		"shop":
			Save.add_pearls(SHOP_AD_REWARD)
			Sfx.play("buy")
			_refresh_shop()


# =============================================================== shop & settings

func _on_boats() -> void:
	if state != State.MENU:
		return
	state = State.SHOP
	cam_mode = "shop"
	shop_index = Save.boat
	_refresh_shop()


func _refresh_shop() -> void:
	boat.set_model(shop_index)
	boat.reset_pose()
	ui.show_shop(Boat.model_name(shop_index), Boat.price(shop_index), Save.owns(shop_index),
		Save.boat == shop_index, Save.pearls, Ads.is_rewarded_ready())


func _shop_step(dir: int) -> void:
	shop_index = wrapi(shop_index + dir, 0, Boat.count())
	_refresh_shop()


func _on_shop_action() -> void:
	if Save.owns(shop_index):
		Save.select(shop_index)
	elif Save.buy(shop_index):
		Sfx.play("buy")
		Sfx.vibrate(40)
		world.burst_confetti(boat.global_position + Vector3(0.0, 2.0, 0.0))
	_refresh_shop()


func _on_shop_ad() -> void:
	if not Ads.is_rewarded_ready():
		ui.popup("Ad not ready yet", Color("ff9b8b"))
		return
	pending_reward = "shop"
	ui.block(true)
	Ads.show_rewarded()


func _on_shop_back() -> void:
	boat.set_model(Save.boat)
	state = State.MENU
	cam_mode = "menu"
	_show_menu()


func _on_settings() -> void:
	ui.show_settings(Save.sound, Save.music, Save.vibe)


func _on_toggle(key: String, value: bool) -> void:
	Save.set(key, value)
	Save.save()
	if key == "music":
		Sfx.set_music(value)


# =============================================================== autotest

func _autotest_menus() -> void:
	_on_boats()
	for i in Boat.count():
		_shop_step(1)
		_on_shop_action()
	_on_shop_back()
	_on_settings()
	_on_toggle("music", false)
	_on_toggle("music", true)
	ui.settings_panel.visible = false
	print("AUTOTEST menus ok (boats owned: %d)" % Save.owned.count(true))
	at_wait = 0.3


func _autotest_tick(delta: float) -> void:
	at_frames += 1
	if at_frames > 60 * 60 * 30:
		print("AUTOTEST FAILED: timeout at level %d" % level)
		get_tree().quit(1)
		return
	at_wait -= delta
	match state:
		State.MENU:
			if at_wait <= 0.0:
				if level > AT_LEVELS:
					print("AUTOTEST PASSED levels=%d crashes=%d frames=%d" % [AT_LEVELS, at_crashes, at_frames])
					get_tree().quit(0)
					return
				print("AUTOTEST level %d (%s): %d items, %d pearls" % [level, Themes.for_level(level).name, world.items.size(), world.pearls.size()])
				at_level_crashes = 0
				_start_run()
		State.PLAYING, State.COUNTDOWN:
			holding = _autopilot_hold()
			if level == 2 and not at_paused and boat_z > 30.0:
				at_paused = true
				_on_pause()
				_on_resume()
				print("AUTOTEST pause/resume ok")
		State.DEAD:
			if ui.lose_panel.visible and at_wait <= 0.0:
				at_crashes += 1
				at_level_crashes += 1
				print("AUTOTEST crash at level %d, z=%.1f (%s)" % [level, boat_z, world.items[crash_index].kind])
				at_wait = 0.5
				if not continue_used:
					_on_continue()
				elif at_level_crashes > 4:
					print("AUTOTEST skipping level %d" % level)
					Save.set_level(level + 1)
					level += 1
					_load_level()
					at_wait = 0.3
				else:
					_on_retry()
					at_wait = 1.0
		State.WON:
			if ui.win_panel.visible and at_wait <= 0.0:
				print("AUTOTEST level %d won, stars=%d pearls=%d/%d" % [level, _stars(), pearls_got, pearls_total])
				at_wait = 1.0
				if level % 3 == 0:
					_on_triple()
				_on_next()


func _autopilot_hold() -> bool:
	var tgt := LevelGen.WATER_REST
	for e in world.items:
		if e.passed or e.get("smashed", false):
			continue
		if float(e.z) + float(e.depth) * 0.5 < boat_z - LevelGen.BOAT_HALF_LEN:
			continue
		if LevelGen.is_obstacle(e.kind):
			var eta := maxf(0.0, (float(e.z) - boat_z) / maxf(speed * _speed_factor(), 0.1))
			var lo := -INF
			var hi := INF
			for k in range(-3, 4):
				var r := LevelGen.safe_range(e, run_t + eta + k * 0.1)
				lo = maxf(lo, r.x + 0.12)
				hi = minf(hi, r.y - 0.12)
			if hi < lo:
				if e.kind == "drawbridge":
					lo = LevelGen.WATER_MIN
					hi = float(e.b) - float(e.amp) - LevelGen.BOAT_TOP - 0.12
				else:
					lo = float(e.h) + float(e.amp) + LevelGen.DRAFT + 0.12
					hi = LevelGen.WATER_MAX
			tgt = (lo + hi) * 0.5 if hi < LevelGen.WATER_MAX else minf(lo + 0.35, LevelGen.WATER_MAX)
			if e.h <= LevelGen.NONE_LOW:
				tgt = maxf(LevelGen.WATER_MIN, hi - 0.35)
		elif not e.taken and e.kind != "slow":
			tgt = float(e.y) - LevelGen.PICK_OFFSET
		else:
			continue
		break
	return water_y + water_vel * absf(water_vel) / (2.0 * ACCEL) + water_vel * 0.05 < tgt
