extends SceneTree
## Renders a preview picture of every ball for the Workshop tiles.
## Run (needs a display, e.g. xvfb-run):
##   godot --path game --rendering-driver opengl3 --script res://make_thumbs.gd
var vp: SubViewport
var boat: Node3D
var idx := 0
var frame := 0
var n := 0


func _process(_d: float) -> bool:
	frame += 1
	if frame == 1:
		n = Custom.count("hull")
		vp = SubViewport.new()
		vp.size = Vector2i(192, 192)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var w := Node3D.new()
		vp.add_child(w)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_CLEAR_COLOR
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color(0.75, 0.75, 0.9)
		env.environment.ambient_light_energy = 0.9
		w.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -30, 0)
		sun.light_energy = 1.2
		w.add_child(sun)
		var cam := Camera3D.new()
		cam.position = Vector3(1.9, 1.6, 2.9)
		cam.fov = 40
		w.add_child(cam)
		cam.look_at(Vector3(0, 0.95, 0))
		boat = Boat.new()
		w.add_child(boat)
		_show(0)
		return false
	if frame % 6 == 0:
		var img := vp.get_texture().get_image()
		img.save_png("res://thumbs/hull_%d.png" % idx)
		idx += 1
		if idx >= n:
			quit()
			return false
		_show(idx)
	return false


func _show(i: int) -> void:
	boat.call("apply", {"hull": i, "paint": 0, "sail": 0, "flag": 0, "hat": 0, "trail": 0})
	boat.rotation.y = -0.5
	(boat.get("wake") as CPUParticles3D).emitting = false
	(boat.get("wake") as CPUParticles3D).restart()
	(boat.get("wake") as CPUParticles3D).emitting = false
