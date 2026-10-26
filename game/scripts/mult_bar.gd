class_name MultiplierBar
extends Control
## "Spin" bar: a needle sweeps over x2 x3 x5 x3 x2. Tap CLAIM to stop it,
## watch an ad, get the coins multiplied.

const SEGMENTS := [2, 3, 5, 3, 2]
var COLORS: Array = [Color("4e7cff"), Color("2fbf71"), Color("ff5a4e"), Color("2fbf71"), Color("4e7cff")]

signal changed(multiplier: int)

var pos := 0.0
var dir := 1.0
var speed := 1.15
var running := true
var font: Font
var _last := 0


func _init() -> void:
	custom_minimum_size = Vector2(520, 116)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func restart() -> void:
	pos = randf()
	dir = 1.0 if randf() < 0.5 else -1.0
	running = true
	queue_redraw()


func current() -> int:
	return SEGMENTS[clampi(int(pos * SEGMENTS.size()), 0, SEGMENTS.size() - 1)]


func stop() -> int:
	running = false
	queue_redraw()
	return current()


func _process(delta: float) -> void:
	if not running or not is_visible_in_tree():
		return
	pos += dir * speed * delta
	if pos >= 1.0:
		pos = 1.0
		dir = -1.0
	elif pos <= 0.0:
		pos = 0.0
		dir = 1.0
	var m := current()
	if m != _last:
		_last = m
		changed.emit(m)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var bar_h := h * 0.62
	var y0 := h - bar_h
	var n := SEGMENTS.size()
	var sw := w / n
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.05, 0.16, 0.95)
	bg.set_corner_radius_all(22)
	draw_style_box(bg, Rect2(0, y0, w, bar_h))
	var cur := clampi(int(pos * n), 0, n - 1)
	for i in n:
		var sb := StyleBoxFlat.new()
		var col: Color = COLORS[i]
		if i == cur:
			col = col.lightened(0.25)
		sb.bg_color = col
		sb.set_corner_radius_all(16)
		sb.border_width_bottom = 5
		sb.border_color = col.darkened(0.35)
		draw_style_box(sb, Rect2(i * sw + 5, y0 + 5, sw - 10, bar_h - 10))
		if font:
			var fs := 40 if i == cur else 34
			var tp := Vector2(i * sw, y0 + bar_h * 0.5 + fs * 0.36)
			draw_string_outline(font, tp, "x%d" % SEGMENTS[i], HORIZONTAL_ALIGNMENT_CENTER, sw, fs, 8, Color(0.07, 0.05, 0.16))
			draw_string(font, tp, "x%d" % SEGMENTS[i], HORIZONTAL_ALIGNMENT_CENTER, sw, fs, Color.WHITE)
	var x := clampf(pos * w, 14.0, w - 14.0)
	var needle := PackedVector2Array([Vector2(x - 20, 0), Vector2(x + 20, 0), Vector2(x, y0 + 14)])
	draw_colored_polygon(needle, Color(0.07, 0.05, 0.16))
	var inner := PackedVector2Array([Vector2(x - 13, 4), Vector2(x + 13, 4), Vector2(x, y0 + 4)])
	draw_colored_polygon(inner, Color("ffd166"))
