extends Node3D
## MOONPULL — you don't steer the boat, you steer the sea.
## Hold anywhere: the moon rises and pulls the tide up. Release: the tide drains.
## Game flow, rules, camera and the CI autotest live here.

enum State { MENU, SHOP, PLAYING, PAUSED, COUNTDOWN, DEAD, WON }

const ACCEL := 16.0          # how fast the tide changes direction
const CLOSE_CALL := 0.28     # clearance that counts as a near miss
const COIN_VALUE := 10        # every coin you pick up is worth 10
const CLOSE_CALL_BONUS := 20
const FREE_REWARD := 500       # "free coins" rewarded ad
const FREE_COOLDOWN := 120     # seconds between free-coin ads

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
var run_coins := 0          # coins earned this run (already x10)
var banked := 0             # part of run_coins already saved
var pearls_got := 0         # coin pickups (for stars)
var pearls_total := 0
var claim_base := 0
var claim_mult := 1
var claim_on_win := false
var daily_mult := 1
var free_tick := 0.0
var first_menu := true
var streak := 0
var streak_timer := 0.0
var continue_used := false
var crash_index := -1
var countdown_left := 0.0
var shake := 0.0
var pending_reward := ""
var shop_index := 0
var shop_cat := "hull"
var shop_slot := "hull"
var run_xp := 0
var cam_mode := "menu"
var cam_pos := Vector3.ZERO
var cam_look := Vector3.ZERO
var cam_ready := false

var world: GameWorld
var boat: Boat
var camera: Camera3D
var ui: GameUI

# race
const RACE_REWARDS := [600, 300, 150, 60]
const LANES := [-2.7, 2.7, -1.45]
var mode := "levels"          # "levels" | "race_ai" | "race_lan"
var race_level := 3
var rivals: Array[Rival] = []
var rivals_by_id := {}
var finish_order: Array = []  # [{"name", "me", "time"}]
var race_reward := 0
var race_doubled := false
var race_done_shown := false
var net_tick := 0.0
var menu_tick := 0.0
var mission_coins := 0
var lobby_status := ""

# autotest (CI): `godot --headless --fixed-fps 60 -- --autotest`
var autotest := false
var at_frames := 0
var at_wait := 0.0
var at_crashes := 0
var at_level_crashes := 0
var at_paused := false
var at_raced := false
var at_endless := false
var endless_level := 2
const AT_LEVELS := 14


func _ready() -> void:
	world = GameWorld.new()
	add_child(world)
	boat = Boat.new()
	add_child(boat)
	boat.apply(Save.boat_cfg())
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
	ui.shop_tab.connect(_on_shop_tab)
	ui.shop_pick.connect(_on_shop_pick)
	ui.shop_side.connect(func(slot: String):
		shop_slot = slot
		shop_index = Save.equipped(slot)
		_refresh_shop())
	ui.rank_closed.connect(_next_rank_up)
	ui.endless_pressed.connect(_start_endless)
	ui.share_pressed.connect(_on_share)
	ui.mystery_open.connect(_on_mystery)
	ui.shop_action.connect(_on_shop_action)
	ui.free_pressed.connect(_on_free)
	ui.daily_claim.connect(_on_daily_claim)
	ui.privacy_pressed.connect(func(): Ads.show_privacy_options())
	ui.pause_pressed.connect(_on_pause)
	ui.resume_pressed.connect(_on_resume)
	ui.restart_pressed.connect(_on_retry)
	ui.home_pressed.connect(_on_home)
	ui.retry_pressed.connect(_on_retry)
	ui.continue_pressed.connect(_on_continue)
	ui.next_pressed.connect(_on_next)
	ui.claim_pressed.connect(_on_claim)
	ui.name_changed.connect(func(n: String):
		Save.set_player_name(n)
		_refresh_menu_buttons())
	ui.tasks_pressed.connect(_show_tasks)
	ui.task_claim.connect(_on_task_claim)
	ui.task_bonus.connect(_on_task_bonus)
	ui.chest_pressed.connect(_show_chests)
	ui.chest_open.connect(_on_chest_open)
	ui.race_pressed.connect(_show_lobby)
	ui.race_ai.connect(_start_ai_race)
	ui.race_host.connect(_on_race_host)
	ui.race_join.connect(_on_race_join)
	ui.race_start.connect(_on_race_start)
	ui.race_leave.connect(_on_race_leave)
	ui.race_double.connect(_on_race_double)
	ui.race_done.connect(_on_race_done)
	Net.lobby_changed.connect(func():
		if ui.race_panel.visible:
			_show_lobby())
	Net.race_started.connect(_begin_lan_race)
	Net.state_received.connect(_on_net_state)
	Net.player_finished.connect(_on_net_finished)
	Net.connection_failed.connect(func(reason: String):
		lobby_status = reason
		if ui.race_panel.visible:
			_show_lobby())
	Net.disconnected.connect(func():
		lobby_status = "Room closed."
		if mode == "race_lan" and state != State.MENU:
			ui.popup("Connection lost", Color("ff9b8b"))
		elif ui.race_panel.visible:
			_show_lobby())
	Ads.rewarded_finished.connect(_on_rewarded_finished)

	autotest = "--autotest" in OS.get_cmdline_user_args()
	if autotest:
		print("AUTOTEST start")
		Save.level = 1
		Save.coins = 50000
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
	if is_press and ui.modal_open():
		return
	holding = is_press
	if is_press and state == State.MENU:
		_start_run()


func _start_run() -> void:
	state = State.PLAYING
	cam_mode = "chase"
	ui.show_hud(level)
	Analytics.event("level_start", {"level_name": "level_%d" % level, "level": level})


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
			free_tick -= delta
			if free_tick <= 0.0:
				free_tick = 0.5
				_update_free_button()
				_refresh_menu_buttons()
				if ui.chest_panel.visible:
					_show_chests()
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
				if mode == "levels":
					_win()
				elif mode == "endless":
					continue_used = true
					_crash(0)
				else:
					_race_finish()
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

	if mode == "race_ai" or mode == "race_lan":
		_race_tick(delta)
	elif mode == "endless" and (state == State.PLAYING or state == State.COUNTDOWN):
		var lv := LevelGen.ramp_level(data, boat_z)
		if lv != endless_level:
			endless_level = lv
			speed = LevelGen.speed_for(lv)
			rise = LevelGen.rise_for(lv)
			fall = LevelGen.fall_for(lv)
		ui.set_score(_endless_score())
	boat.position = Vector3(0.0, water_y, boat_z)
	boat.tick(delta, t, water_vel, factor, state != State.DEAD, holding and (state == State.PLAYING or state == State.COUNTDOWN))
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
			pos = bp + Vector3(sin(a2) * 3.6, 1.5, cos(a2) * 3.6)
			look = bp + Vector3(0.0, -0.75, 0.0)
			fov = 58.0
			rate = 4.0
		"shop_walls":
			pos = bp + Vector3(0.0, 4.2, -6.5)
			look = bp + Vector3(0.0, 1.8, 9.0)
			fov = 70.0
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
	var value := COIN_VALUE * (2 if boost_left > 0.0 else 1)
	run_coins += value
	mission_coins += value
	run_xp += Ranks.XP_PICKUP
	pearls_got += 1
	streak = mini(streak + 1, 10)
	streak_timer = 1.4
	Sfx.play("pearl", 1.0 + streak * 0.06)
	ui.set_coins(Save.coins + run_coins - banked)
	ui.bump_coins()


func _take_pickup(e: Dictionary) -> void:
	world.take_pickup(e)
	Sfx.vibrate(30)
	match e.kind:
		"boost":
			_mission("rings")
			boost_left = LevelGen.BOOST_TIME
			Sfx.play("boost")
			ui.popup("SPEED!  x2 PEARLS", Color("ffc531"))
		"slow":
			_mission("rings")
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
	run_coins += CLOSE_CALL_BONUS
	ui.set_coins(Save.coins + run_coins - banked)
	ui.popup("CLOSE CALL!  +%d" % CLOSE_CALL_BONUS)
	_mission("close")
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
	if mode == "race_ai" or mode == "race_lan":
		await get_tree().create_timer(1.1).timeout
		if state == State.DEAD and (mode == "race_ai" or mode == "race_lan"):
			_race_respawn()
		return
	await get_tree().create_timer(0.75).timeout
	if state == State.DEAD:
		_bank()
		if mode == "endless":
			_endless_over()
			return
		ui.set_coins(Save.coins)
		Analytics.event("level_end", {"level_name": "level_%d" % level, "success": 0, "level": level,
			"progress": int(clampf(boat_z / world.finish_z, 0.0, 1.0) * 100.0), "obstacle": String(world.items[crash_index].kind)})
		ui.show_lose(not continue_used, clampf(boat_z / world.finish_z, 0.0, 1.0), run_coins)


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
	_bank()
	Analytics.event("level_end", {"level_name": "level_%d" % level, "success": 1, "level": level, "stars": stars, "coins": run_coins, "seconds": int(run_t)})
	if level == 2:
		Analytics.event("tutorial_complete")
	Save.set_stars(level, stars)
	Save.set_level(level + 1)
	Save.add_xp(Ranks.XP_WIN + stars * Ranks.XP_STAR)
	_mission("levels")
	if stars == 3:
		_mission("stars3")
	ui.set_coins(Save.coins)
	world.open_chest()
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.5, 3.0))
	boost_left = 0.0
	slow_left = 0.0
	ui.set_effects({})
	await get_tree().create_timer(0.9).timeout
	if state == State.WON:
		ui.show_win(level, stars, run_coins)


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
	_show_run_hud()
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
	if level > 2 or mode != "levels":
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
	_clear_race()
	mode = "levels"
	_setup_run(LevelGen.generate(level), level)
	state = State.MENU
	cam_mode = "menu"
	_show_menu()


func _setup_run(new_data: Dictionary, theme_level: int) -> void:
	data = new_data
	speed = data.speed
	rise = data.rise
	fall = data.fall
	var ws := _wall_styles(Save.equipped("wall_l"), Save.equipped("wall_r"))
	world.build_level(data, theme_level, ws[0], ws[1])
	pearls_total = world.pearls.size()
	run_coins = 0
	banked = 0
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
	boat.apply(Save.boat_cfg())
	boat.show_shield(false)
	boat.show_magnet(false)
	mission_coins = 0
	ui.set_countdown(0)
	ui.hide_hint()
	ui.set_effects({})


func _show_menu() -> void:
	var th := Themes.for_level(level)
	ui.show_menu(level, Save.coins, th.name, Themes.world_index(level) + 1, Themes.step_in_world(level), Save.total_stars())
	_update_free_button()
	_refresh_menu_buttons()
	_check_rank_ups()
	ui.set_endless_best(Save.best_endless)
	if first_menu:
		first_menu = false
		if Save.daily_available() and not autotest:
			ui.show_daily(Save.daily_next_streak(), Save.daily_amount())


func _transition_to_level() -> void:
	await ui.fade_out(0.25).finished
	_load_level()
	ui.fade_in()


func _maybe_interstitial() -> void:
	if Ads.round_ended_should_show(level):
		Analytics.event("ad_interstitial", {"level": level})
		ui.block(true)
		Ads.show_interstitial()
		await Ads.interstitial_closed
		ui.block(false)


func _on_retry() -> void:
	if state == State.PAUSED or state == State.DEAD or state == State.PLAYING:
		state = State.DEAD
	await _maybe_interstitial()
	if mode == "endless":
		await _restart_endless()
		return
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
	_show_run_hud()
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


func _bank() -> void:
	if run_coins > banked:
		Save.add_coins(run_coins - banked)
		banked = run_coins
	if mission_coins > 0:
		_mission("coins", mission_coins)
		mission_coins = 0
	if run_xp > 0:
		Save.add_xp(run_xp)
		run_xp = 0


func _mission(id: String, amount := 1) -> void:
	if Missions.track(id, amount):
		ui.popup("TASK COMPLETE!", Color("7dffb0"))
		Sfx.play("star")


## Multiplier spin: the player stopped the needle on x`mult`; watch an ad to get it.
func _on_claim(mult: int) -> void:
	claim_on_win = state == State.WON
	if not Ads.is_rewarded_ready():
		ui.popup("Ad not ready yet", Color("ff9b8b"))
		ui.resume_spin(claim_on_win)
		return
	claim_base = run_coins
	claim_mult = mult
	pending_reward = "claim"
	ui.block(true)
	Ads.show_rewarded()


func _on_free() -> void:
	if Save.free_seconds_left() > 0:
		return
	if not Ads.is_rewarded_ready():
		ui.popup("Ad not ready yet", Color("ff9b8b"))
		return
	pending_reward = "free"
	ui.block(true)
	Ads.show_rewarded()


func _on_daily_claim(mult: int) -> void:
	if mult > 1 and Ads.is_rewarded_ready():
		daily_mult = mult
		pending_reward = "daily"
		ui.block(true)
		Ads.show_rewarded()
		return
	_give_daily(1)


func _give_daily(mult: int) -> void:
	var amount := Save.claim_daily(mult)
	Analytics.event("daily_gift", {"day": Save.daily_streak, "doubled": 1 if mult > 1 else 0})
	ui.hide_daily()
	ui.set_coins(Save.coins)
	ui.bump_coins()
	ui.popup("+%s COINS" % GameUI.fmt(amount))
	if not Save.last_daily_item.is_empty():
		ui.show_reveal({"cat": Save.last_daily_item[0], "index": Save.last_daily_item[1]})
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.0, 0.0))
	Sfx.play("buy")


func _update_free_button() -> void:
	var left := Save.free_seconds_left()
	if left == 0 and not Ads.is_rewarded_ready():
		left = -1
	ui.set_free_state(left, FREE_REWARD)


func _on_rewarded_finished(earned: bool) -> void:
	ui.block(false)
	var what := pending_reward
	pending_reward = ""
	Analytics.event("ad_rewarded", {"placement": what, "earned": 1 if earned else 0})
	match what:
		"continue":
			if earned and state == State.DEAD:
				_revive()
		"claim":
			if earned:
				var bonus := claim_base * (claim_mult - 1)
				Save.add_coins(bonus)
				ui.set_coins(Save.coins)
				ui.bump_coins()
				ui.show_claimed(claim_base * claim_mult, claim_on_win)
				Sfx.play("buy")
				Sfx.vibrate(40)
			else:
				ui.resume_spin(claim_on_win)
		"free":
			if earned:
				Save.add_coins(FREE_REWARD)
				Save.start_free_cooldown(FREE_COOLDOWN)
				ui.set_coins(Save.coins)
				ui.bump_coins()
				ui.popup("+%s COINS" % GameUI.fmt(FREE_REWARD))
				Sfx.play("buy")
				if state == State.SHOP:
					_refresh_shop()
			_update_free_button()
		"daily":
			_give_daily(daily_mult if earned else 1)
		"race":
			if earned and not race_doubled:
				race_doubled = true
				Save.add_coins(race_reward)
				ui.set_coins(Save.coins)
				ui.results_doubled(race_reward * 2)
				Sfx.play("buy")


# =============================================================== menu extras

func _refresh_menu_buttons() -> void:
	ui.refresh_menu_buttons(Save.player_name, Missions.claimable(), Save.chest_seconds_left(), Save.star_chest_ready())
	var r := Ranks.from_xp(Save.xp)
	ui.set_rank(r[0], r[1], r[2], Ranks.title(r[0]))


func _show_tasks() -> void:
	ui.show_tasks(Missions.list(), Missions.bonus_ready(), bool(Save.missions.get("bonus", false)), Missions.ALL_DONE_BONUS)


func _on_task_claim(i: int) -> void:
	var amount := Missions.claim(i)
	if amount > 0:
		Save.add_xp(Ranks.XP_TASK)
		_reward_fx(amount)
	_show_tasks()
	_refresh_menu_buttons()
	_check_rank_ups()


func _on_task_bonus() -> void:
	var amount := Missions.claim_bonus()
	if amount > 0:
		_reward_fx(amount)
	_show_tasks()
	_refresh_menu_buttons()


func _reward_fx(amount: int) -> void:
	ui.set_coins(Save.coins)
	ui.bump_coins()
	ui.popup("+%s COINS" % GameUI.fmt(amount))
	Sfx.play("buy")
	Sfx.vibrate(30)


func _show_chests() -> void:
	ui.show_chests(Save.chest_seconds_left(), Save.star_chest_progress(), Save.star_chest_ready())


func _on_chest_open(kind: String) -> void:
	if kind == "free" and Save.chest_seconds_left() > 0:
		return
	if kind == "star" and not Save.star_chest_ready():
		return
	var reward := Save.open_chest(kind)
	Analytics.event("chest_open", {"kind": kind})
	Save.add_xp(Ranks.XP_CHEST)
	ui.set_coins(Save.coins)
	ui.show_reveal(reward)
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.0, 0.0))
	Sfx.play("win")
	Sfx.vibrate(50)
	_refresh_menu_buttons()


# =============================================================== endless

func _endless_score() -> int:
	return int(boat_z / 2.0)


func _show_run_hud() -> void:
	if mode == "endless":
		ui.show_endless_hud(Save.best_endless)
		ui.set_score(_endless_score())
	else:
		ui.show_hud(level)


func _start_endless() -> void:
	if state != State.MENU:
		return
	await ui.fade_out(0.25).finished
	_begin_endless()
	ui.fade_in()


func _restart_endless() -> void:
	await ui.fade_out(0.25).finished
	_begin_endless()
	ui.fade_in()


func _begin_endless() -> void:
	_clear_race()
	mode = "endless"
	Analytics.event("endless_start")
	_setup_run(LevelGen.generate_endless(randi()), Save.level)
	endless_level = 2
	cam_mode = "chase"
	state = State.COUNTDOWN
	countdown_left = 2.0
	ui.show_endless_hud(Save.best_endless)
	ui.set_countdown(2)


func _endless_over() -> void:
	var score := _endless_score()
	var prev := Save.best_endless
	var new_best := score > prev
	if new_best:
		Save.best_endless = score
		world.burst_confetti(boat.global_position + Vector3(0.0, 2.5, 2.0))
		Sfx.play("win")
	Save.add_xp(score / 4)
	Missions.track("endless", score)
	Analytics.event("endless_end", {"score": score, "best": Save.best_endless, "new_best": 1 if new_best else 0, "seconds": int(run_t)})
	Save.save()
	ui.set_coins(Save.coins)
	ui.show_lose_endless(score, prev if new_best else Save.best_endless, new_best, not continue_used, run_coins)


func _on_share() -> void:
	var text := ""
	if mode == "endless":
		text = "I scored %d in Moonpull Endless! Can you beat me? %s" % [_endless_score(), Ads.STORE_URL]
	else:
		text = "I'm a Rank %d captain on level %d in Moonpull! %s" % [Save.rank(), level, Ads.STORE_URL]
	Analytics.event("share", {"content_type": mode, "method": "share_sheet"})
	if not Ads.share_text(text):
		ui.popup("Copied! Paste it to a friend", Color("8fe3ff"))


func _on_mystery() -> void:
	var got := Save.open_mystery()
	if got.is_empty():
		ui.popup("Not enough coins", Color("ff9b8b"))
		return
	Analytics.event("spend_virtual_currency", {"item_name": "mystery_box", "virtual_currency_name": "coins", "value": Save.MYSTERY_PRICE})
	Save.add_xp(Ranks.XP_CHEST)
	ui.set_coins(Save.coins)
	ui.show_reveal(got)
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.0, 0.0))
	Sfx.play("win")
	Sfx.vibrate(50)


# =============================================================== race

func _show_lobby() -> void:
	var names: Array = []
	for id in Net.players:
		names.append(Net.players[id].name)
	ui.show_race_lobby(Net.supported(), Net.in_room, Net.is_host, Net.room_code, names, lobby_status)


func _on_race_host() -> void:
	lobby_status = ""
	var code := Net.host(Save.player_name, Save.boat_cfg())
	if code != "":
		lobby_status = "Friends on the same Wi-Fi type this code."
	_show_lobby()


func _on_race_join(code: String) -> void:
	lobby_status = "Joining..."
	Net.join(code, Save.player_name, Save.boat_cfg())
	_show_lobby()


func _on_race_start() -> void:
	if Net.is_host and Net.players.size() >= 2:
		Net.start(maxi(3, Save.level), randi())


func _on_race_leave() -> void:
	Net.leave()
	lobby_status = ""
	ui.race_panel.visible = false


func _clear_race() -> void:
	for r in rivals:
		r.queue_free()
	rivals.clear()
	rivals_by_id.clear()
	finish_order.clear()
	race_done_shown = false
	race_doubled = false
	race_reward = 0
	ui.set_race_hud(false, 1, 1, [])


func _start_ai_race() -> void:
	ui.race_panel.visible = false
	Net.leave()
	await ui.fade_out(0.25).finished
	_clear_race()
	mode = "race_ai"
	race_level = clampi(Save.level, 3, 30)
	_setup_run(LevelGen.generate(race_level, randi()), race_level)
	var skills := [0.16, 0.11, 0.075] if race_level < 10 else [0.12, 0.08, 0.06]
	for i in 3:
		var r := Rival.new()
		add_child(r)
		var cfg := {"hull": randi() % Custom.count("hull"), "paint": randi() % Custom.count("paint"),
			"sail": randi() % Custom.count("sail"), "flag": randi() % Custom.count("flag"),
			"hat": randi() % Custom.count("hat"), "trail": randi() % Custom.count("trail")}
		r.setup(Save.random_name(), cfg, LANES[i])
		r.skill = skills[i]
		rivals.append(r)
	_race_countdown()
	ui.fade_in()


func _begin_lan_race(lvl: int, race_seed: int) -> void:
	ui.race_panel.visible = false
	await ui.fade_out(0.25).finished
	_clear_race()
	mode = "race_lan"
	race_level = lvl
	_setup_run(LevelGen.generate(lvl, race_seed), lvl)
	var lane := 0
	for id in Net.players:
		if int(id) == Net.my_id():
			continue
		var p: Dictionary = Net.players[id]
		var r := Rival.new()
		add_child(r)
		r.setup(String(p.name), p.cfg, LANES[lane % LANES.size()], true)
		rivals.append(r)
		rivals_by_id[int(id)] = r
		lane += 1
	_race_countdown()
	ui.fade_in()


func _race_countdown() -> void:
	state = State.COUNTDOWN
	countdown_left = 3.0
	cam_mode = "chase"
	ui.show_hud(race_level)
	ui.level_label.text = "RACE"
	ui.set_countdown(3)
	_update_race_hud()


func _race_tick(delta: float) -> void:
	var racing := state == State.PLAYING or state == State.DEAD or state == State.WON
	for r in rivals:
		if mode == "race_ai" and racing and not r.is_remote:
			if r.simulate(delta, world.items, run_t, speed, rise, fall, world.finish_z):
				finish_order.append({"name": r.display_name, "me": false, "time": run_t})
		r.update_visual(delta, t)
	if mode == "race_lan" and (state == State.PLAYING or state == State.DEAD):
		net_tick -= delta
		if net_tick <= 0.0:
			net_tick = 0.1
			Net.send_state(boat_z, water_y, holding, state != State.DEAD)
	if state == State.PLAYING or state == State.DEAD:
		_update_race_hud()


func _standings() -> Array:
	var rows: Array = []
	for f in finish_order:
		rows.append([f.name, f.me, "%.1fs" % float(f.time), 1e9])
	var racing: Array = []
	var me_done := false
	for f in finish_order:
		if f.me:
			me_done = true
	if not me_done:
		racing.append([Save.player_name, true, "—", boat_z])
	for r in rivals:
		var done := false
		for f in finish_order:
			if f.name == r.display_name and not f.me:
				done = true
		if not done:
			racing.append([r.display_name, false, "—", r.z])
	racing.sort_custom(func(a, b): return float(a[3]) > float(b[3]))
	rows.append_array(racing)
	return rows


func _my_place(rows: Array) -> int:
	for i in rows.size():
		if bool(rows[i][1]):
			return i + 1
	return rows.size()


func _update_race_hud() -> void:
	var rows := _standings()
	ui.set_race_hud(true, _my_place(rows), rows.size(), rows)


func _race_respawn() -> void:
	boat_z = LevelGen.respawn_z(world.items, boat_z, speed)
	for e in world.items:
		if float(e.z) + float(e.depth) * 0.5 > boat_z - LevelGen.BOAT_HALF_LEN:
			e.passed = false
			e.min_clear = LevelGen.NONE_HIGH
	water_y = LevelGen.WATER_REST + 0.6
	water_vel = 0.0
	boat.reset_pose()
	state = State.COUNTDOWN
	countdown_left = 0.8
	ui.popup("RESPAWN", Color("8fe3ff"))


func _race_finish() -> void:
	state = State.WON
	holding = false
	cam_mode = "win"
	finish_order.append({"name": Save.player_name, "me": true, "time": run_t})
	if mode == "race_lan":
		Net.send_finished(run_t)
	var rows := _standings()
	var place := _my_place(rows)
	race_reward = RACE_REWARDS[mini(place - 1, RACE_REWARDS.size() - 1)]
	_bank()
	Save.add_coins(race_reward)
	Save.races += 1
	Analytics.event("race_end", {"mode": mode, "place": place, "players": rows.size()})
	Save.add_xp(Ranks.XP_RACE + (Ranks.XP_RACE_WIN if place == 1 else 0))
	_mission("races")
	if place == 1:
		Save.race_wins += 1
		_mission("race_win")
		world.burst_confetti(boat.global_position + Vector3(0.0, 2.5, 3.0))
		Sfx.play("win")
	else:
		Sfx.play("star")
	Save.save()
	ui.set_coins(Save.coins)
	ui.set_race_hud(false, 1, 1, [])
	await get_tree().create_timer(1.0).timeout
	if state == State.WON and mode != "levels":
		race_done_shown = true
		ui.show_results(place, _standings(), race_reward)


func _on_net_state(id: int, z: float, w: float, h: bool, a: bool) -> void:
	if rivals_by_id.has(id):
		(rivals_by_id[id] as Rival).net_state(z, w, h, a)


func _on_net_finished(id: int, time: float) -> void:
	if rivals_by_id.has(id):
		var r: Rival = rivals_by_id[id]
		r.finished = true
		finish_order.append({"name": r.display_name, "me": false, "time": time})


func _on_race_double() -> void:
	if race_doubled or not Ads.is_rewarded_ready():
		return
	pending_reward = "race"
	ui.block(true)
	Ads.show_rewarded()


func _on_race_done() -> void:
	var back_to_lobby := mode == "race_lan" and Net.in_room
	await _maybe_interstitial()
	await _transition_to_level()
	if back_to_lobby:
		_show_lobby()


# =============================================================== rank ups

var _showing_rank := false


func _check_rank_ups() -> void:
	if _showing_rank or Save.pending_ranks.is_empty() or state != State.MENU or autotest:
		if autotest:
			Save.pending_ranks.clear()
		return
	_next_rank_up()


func _next_rank_up() -> void:
	_showing_rank = false
	_refresh_menu_buttons()
	if Save.pending_ranks.is_empty() or state != State.MENU:
		return
	var r := int(Save.pending_ranks.pop_front())
	Save.save()
	Analytics.event("level_up", {"level": r, "character": "captain"})
	Analytics.user_property("rank", str(r))
	_showing_rank = true
	var rw := Ranks.reward(r)
	var rows: Array = [["coin", Color.WHITE, "+%s COINS" % GameUI.fmt(int(rw.coins))]]
	for pair in rw.items:
		var it := Custom.item(pair[0], pair[1])
		rows.append(["star", Color("ff4f7a"), "%s %s" % [String(it.name), Custom.CAT_NAMES[pair[0]]]])
	if rw.chest:
		var got := Save.open_chest("rank")
		if got.has("coins"):
			rows.append(["chest", Color("ffd166"), "CHEST: +%s" % GameUI.fmt(int(got.coins))])
		else:
			rows.append(["chest", Color("ffd166"), "CHEST: %s" % String(Custom.item(got.cat, int(got.index)).name)])
	var nx := Ranks.next_exclusive_rank(r)
	var next_text := ""
	if nx > 0:
		var it2: Dictionary = Custom.item(Custom.rank_unlocks(nx)[0][0], Custom.rank_unlocks(nx)[0][1])
		next_text = "Next exclusive at RANK %d: %s" % [nx, String(it2.name)]
	ui.show_rank_up(r, Ranks.title(r), rows, next_text)
	ui.set_coins(Save.coins)
	world.burst_confetti(boat.global_position + Vector3(0.0, 2.5, 0.0))
	Sfx.play("win")
	Sfx.vibrate(60)


func _wall_styles(l: int, r: int) -> Array:
	return [String(Custom.item("wall", l).style), String(Custom.item("wall", r).style)]


# =============================================================== shop & settings

func _on_boats() -> void:
	if state != State.MENU:
		return
	state = State.SHOP
	cam_mode = "shop"
	_on_shop_tab("hull")


func _on_shop_tab(cat: String) -> void:
	shop_cat = cat
	shop_slot = cat if cat != "wall" else (shop_slot if shop_slot.begins_with("wall") else "wall_l")
	shop_index = Save.equipped(shop_slot)
	_refresh_shop()


func _on_shop_pick(i: int) -> void:
	shop_index = i
	_refresh_shop()


## Preview = what you own/equip, with the selected item tried on.
func _refresh_shop() -> void:
	var preview := Save.boat_cfg()
	preview[shop_slot] = shop_index
	boat.apply(preview)
	boat.reset_pose()
	if shop_cat == "wall":
		var ws := _wall_styles(int(preview.wall_l), int(preview.wall_r))
		world.set_walls(ws[0], ws[1])
		cam_mode = "shop_walls"
	else:
		_restore_walls()
		cam_mode = "shop"
	ui.show_shop(shop_cat, shop_index, Save.coins, shop_slot)
	_update_free_button()


var _walls_shown := ""


func _restore_walls() -> void:
	var key := "%d/%d" % [Save.equipped("wall_l"), Save.equipped("wall_r")]
	if key == _walls_shown:
		return
	_walls_shown = key
	var ws := _wall_styles(Save.equipped("wall_l"), Save.equipped("wall_r"))
	world.set_walls(ws[0], ws[1])


func _on_shop_action() -> void:
	if Save.owns(shop_cat, shop_index):
		Save.equip(shop_slot, shop_index)
		Sfx.play("click")
	elif Save.buy(shop_cat, shop_index, shop_slot):
		Analytics.event("spend_virtual_currency", {"item_name": "%s:%s" % [shop_cat, String(Custom.item(shop_cat, shop_index).name)],
			"virtual_currency_name": "coins", "value": int(Custom.item(shop_cat, shop_index).price)})
		Sfx.play("buy")
		Sfx.vibrate(40)
		world.burst_confetti(boat.global_position + Vector3(0.0, 2.0, 0.0))
	_walls_shown = ""
	_refresh_shop()


func _on_shop_back() -> void:
	boat.apply(Save.boat_cfg())
	_walls_shown = ""
	_restore_walls()
	state = State.MENU
	cam_mode = "menu"
	_show_menu()


func _on_settings() -> void:
	ui.show_settings(Save.sound, Save.music, Save.vibe, Ads.privacy_required())


func _on_toggle(key: String, value: bool) -> void:
	Save.set(key, value)
	Save.save()
	if key == "music":
		Sfx.set_music(value)


# =============================================================== autotest

func _autotest_menus() -> void:
	_on_boats()
	for cat in Custom.CATS:
		_on_shop_tab(cat)
		for i in Custom.count(cat):
			_on_shop_pick(i)
			_on_shop_action()
	ui.shop_side.emit("wall_r")
	_on_shop_pick(3)
	_on_shop_action()
	Save.add_xp(5000)
	print("AUTOTEST rank after 5000 xp: %d (%s)" % [Save.rank(), Ranks.title(Save.rank())])
	_on_shop_back()
	_on_settings()
	_on_toggle("music", false)
	_on_toggle("music", true)
	_on_free()
	_on_daily_claim(1)
	_show_tasks()
	_on_task_claim(0)
	_on_task_bonus()
	ui.tasks_panel.visible = false
	_show_chests()
	_on_chest_open("free")
	_on_mystery()
	ui.reveal_panel.visible = false
	ui.chest_panel.visible = false
	Save.set_player_name("Auto Tester")
	_refresh_menu_buttons()
	_show_lobby()
	_on_race_host()
	print("AUTOTEST lobby: in_room=%s code=%s status=%s" % [str(Net.in_room), Net.room_code, lobby_status])
	_on_race_leave()
	ui.settings_panel.visible = false
	print("AUTOTEST menus ok (workshop items owned: %d, boat %s)" % [Save.owned_count(), str(Save.boat_cfg())])
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
					if not at_raced:
						at_raced = true
						print("AUTOTEST race vs AI")
						_start_ai_race()
						at_wait = 2.0
						return
					if not at_endless:
						at_endless = true
						print("AUTOTEST endless")
						_start_endless()
						at_wait = 2.0
						return
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
			if mode == "endless":
				if ui.lose_panel.visible and at_wait <= 0.0:
					print("AUTOTEST endless over: score=%d best=%d" % [_endless_score(), Save.best_endless])
					_on_share()
					at_wait = 1.0
					_on_home()
				return
			if mode != "levels":
				return
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
			if mode != "levels":
				if ui.results_panel.visible and at_wait <= 0.0:
					print("AUTOTEST race finished: %s" % str(_standings()))
					_on_race_double()
					at_wait = 1.5
					_on_race_done()
				return
			if ui.win_panel.visible and at_wait <= 0.0:
				print("AUTOTEST level %d won, stars=%d pearls=%d/%d" % [level, _stars(), pearls_got, pearls_total])
				at_wait = 1.0
				if level % 2 == 0:
					_on_claim(ui.win_mult.stop())
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
