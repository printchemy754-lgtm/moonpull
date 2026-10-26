class_name Toon
extends RefCounted
## Material factory for the game's "inked cartoon" style.

const INK := Color(0.09, 0.07, 0.23)

static var _toon: Shader
static var _outline: Shader
static var _outlines := {}


static func mat(color: Color, glow := 0.0, outline := 0.03, rim := 0.3) -> ShaderMaterial:
	if _toon == null:
		_toon = load("res://shaders/toon.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("emission", color)
	m.set_shader_parameter("emission_energy", glow)
	m.set_shader_parameter("rim_strength", rim)
	if outline > 0.0:
		m.next_pass = outline_mat(outline)
	return m


static func outline_mat(width: float) -> ShaderMaterial:
	var key := snappedf(width, 0.001)
	if _outlines.has(key):
		return _outlines[key]
	if _outline == null:
		_outline = load("res://shaders/outline.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _outline
	m.set_shader_parameter("color", INK)
	m.set_shader_parameter("width", width)
	_outlines[key] = m
	return m


static func set_color(m: Material, color: Color) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter("albedo", color)
		(m as ShaderMaterial).set_shader_parameter("emission", color)
	elif m is StandardMaterial3D:
		(m as StandardMaterial3D).albedo_color = color
