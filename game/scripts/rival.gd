class_name Rival
extends Node3D
## A race opponent: AI captain (offline) or a remote Wi-Fi player.
## Floats on its own little patch of tide in a side lane.

var display_name := "Rival"
var is_remote := false
var skill := 0.12          # AI decision interval in seconds (lower = better)
var z := 0.0
var water := 0.0
var vel := 0.0
var holding := false
var alive := true
var finished := false
var finish_time := 0.0
var respawn_left := 0.0
var lane_x := 2.6
var x := 0.0               # sideways position (steering)
var _target_x := 0.0
var boat: Boat
var _decide := 0.0
var _tag: Label3D
var _ring: MeshInstance3D
var _target_z := 0.0
var _target_water := 0.0
var _boost := 0.0
var pace := 1.0             # each AI rolls at its own pace
var air_t := -1.0


func setup(rname: String, cfg: Dictionary, x: float, remote := false) -> void:
	display_name = rname
	lane_x = x
	self.x = x
	is_remote = remote
	pace = randf_range(1.0, 1.12)
	boat = Boat.new()
	add_child(boat)
	boat.apply(cfg)
	_ring = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.25
	disc.bottom_radius = 1.25
	disc.height = 0.03
	disc.radial_segments = 24
	_ring.mesh = disc
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.85, 0.97, 1.0, 0.55)
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_tag = Label3D.new()
	_tag.text = rname
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.font = load("res://fonts/Montserrat-ExtraBold.ttf")
	_tag.font_size = 64
	_tag.outline_size = 16
	_tag.modulate = Color("ffe9a8")
	_tag.outline_modulate = Toon.INK
	_tag.pixel_size = 0.006
	_tag.position = Vector3(0.0, 2.3, 0.0)
	_tag.no_depth_test = true
	add_child(_tag)


## AI step. Returns true the moment it crosses the finish line.
func simulate(delta: float, items: Array, run_t: float, speed: float, rise: float, fall: float, finish_z: float) -> bool:
	if finished:
		z += speed * 0.4 * delta
		return false
	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left <= 0.0:
			alive = true
			boat.reset_pose()
		return false
	_decide -= delta
	if _decide <= 0.0:
		_decide = skill * randf_range(0.8, 1.3)
		_target_x = LevelGen.pilot_target(items, z, run_t, speed, x) + randf_range(-0.25, 0.25)
		# AI players make mistakes too (the slower ones more often)
		if randf() < skill * 0.12:
			_target_x += randf_range(-2.2, 2.2)
		holding = absf(_target_x - x) > 0.2
	var nx := move_toward(x, _target_x, 7.0 * delta)
	vel = (nx - x) / maxf(delta, 0.001)
	x = nx
	_boost = maxf(_boost - delta, 0.0)
	var slope := clampf(1.0 - LevelGen.track.slope(z) * 1.2, 0.8, 1.35) if LevelGen.track else 1.0
	var dz := speed * pace * slope * delta * (LevelGen.BOOST_MULT if _boost > 0.0 else 1.0)
	z += dz
	boat.roll(dz, vel * delta)
	if air_t >= 0.0:
		air_t += delta
		boat.trick_progress(air_t / LevelGen.JUMP_TIME)
		if air_t >= LevelGen.JUMP_TIME:
			air_t = -1.0
	else:
		for e in items:
			if float(e.z) > z + 2.0:
				break
			if e.kind == "speedpad" and float(e.z) <= z and not e.has("rival_%d" % get_instance_id()):
				e["rival_%d" % get_instance_id()] = true
				_boost = LevelGen.BOOST_TIME
			if e.kind == "ramp" and float(e.z) <= z and not e.has("rival_%d" % get_instance_id()):
				e["rival_%d" % get_instance_id()] = true
				air_t = 0.0
				boat.start_trick(randi() % 3)
	if air_t < 0.0 and LevelGen.hits(items, z, x, run_t):
		crash(items, speed)
		return false
	if z >= finish_z:
		finished = true
		return true
	return false


func crash(items: Array, speed: float) -> void:
	alive = false
	holding = false
	vel = 0.0
	respawn_left = 1.3
	boat.crash()
	z = LevelGen.respawn_z(items, z, speed)
	x = 0.0
	_target_x = 0.0


## Remote player: smoothly follow the last received state.
func net_state(nz: float, nw: float, h: bool, a: bool) -> void:
	_target_z = nz
	_target_water = nw
	holding = h
	if a != alive:
		alive = a
		if not a:
			boat.crash()
		else:
			boat.reset_pose()


func update_visual(delta: float, t: float) -> void:
	if is_remote:
		z = lerpf(z, _target_z, 1.0 - exp(-10.0 * delta))
		x = lerpf(x, _target_water, 1.0 - exp(-10.0 * delta))
	var lift := LevelGen.jump_height(air_t / LevelGen.JUMP_TIME) if air_t >= 0.0 else 0.0
	var tr := LevelGen.track
	if tr:
		var dz := clampf(z, 0.0, tr.length)
		transform = Transform3D(tr.frame(dz).basis, tr.point(dz, x, lift))
	boat.tick(delta, t, 0.0, 1.0, alive, holding)
	_ring.position.y = 0.02
