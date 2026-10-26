class_name IconDraw
extends Control
## Vector icons drawn in code (no image assets, no font glyphs needed).

var kind := "star"
var color := Color.WHITE


func _init(k := "star", c := Color.WHITE) -> void:
	kind = k
	color = c
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_kind(k: String, c := Color(-1, -1, -1)) -> void:
	kind = k
	if c.r >= 0.0:
		color = c
	queue_redraw()


func _star_points(c: Vector2, r_out: float, r_in: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var r := r_out if i % 2 == 0 else r_in
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _arc_points(c: Vector2, r: float, a0: float, a1: float, n := 20) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


func _slash(c: Vector2, r: float) -> void:
	draw_line(c + Vector2(-r, -r), c + Vector2(r, r), Color("ff5a4e"), r * 0.22, true)


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var w := maxf(r * 0.16, 2.0)
	match kind:
		"star":
			draw_colored_polygon(_star_points(c, r, r * 0.45), color)
		"star_empty":
			var pts := _star_points(c, r * 0.95, r * 0.43)
			pts.append(pts[0])
			draw_colored_polygon(_star_points(c, r, r * 0.45), Color(0, 0, 0, 0.35))
			draw_polyline(pts, Color(1, 1, 1, 0.45), w * 0.6, true)
		"pearl":
			draw_circle(c, r * 0.85, Color("e3c9a8"))
			draw_circle(c - Vector2(r * 0.05, r * 0.05), r * 0.75, Color("fff4e6"))
			draw_circle(c - Vector2(r * 0.3, r * 0.3), r * 0.2, Color.WHITE)
		"pause":
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.6), Vector2(r * 0.4, r * 1.2)), color)
			draw_rect(Rect2(c + Vector2(r * 0.15, -r * 0.6), Vector2(r * 0.4, r * 1.2)), color)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.45, -r * 0.6), c + Vector2(r * 0.65, 0), c + Vector2(-r * 0.45, r * 0.6)]), color)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				var d := Vector2(cos(a), sin(a))
				var p := Vector2(-d.y, d.x)
				draw_colored_polygon(PackedVector2Array([
					c + d * r * 0.55 + p * r * 0.17, c + d * r * 0.95 + p * r * 0.13,
					c + d * r * 0.95 - p * r * 0.13, c + d * r * 0.55 - p * r * 0.17]), color)
			draw_circle(c, r * 0.65, color)
			draw_circle(c, r * 0.28, Color(0.12, 0.12, 0.25))
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.85, -r * 0.05), c + Vector2(-r * 0.85, -r * 0.05)]), color)
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.85)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.15, r * 0.25), Vector2(r * 0.3, r * 0.5)), Color(0.12, 0.12, 0.25))
		"retry":
			draw_polyline(_arc_points(c, r * 0.6, -PI * 0.15, PI * 1.45), color, w * 1.3, true)
			var tip := c + Vector2(cos(-PI * 0.15), sin(-PI * 0.15)) * r * 0.6
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.35, -r * 0.1), tip + Vector2(r * 0.25, -r * 0.05), tip + Vector2(0, r * 0.4)]), color)
		"left", "right":
			var s := -1.0 if kind == "left" else 1.0
			draw_polyline(PackedVector2Array([c + Vector2(-s * r * 0.3, -r * 0.6), c + Vector2(s * r * 0.35, 0), c + Vector2(-s * r * 0.3, r * 0.6)]), color, w * 1.5, true)
		"close":
			draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), color, w * 1.4, true)
			draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), color, w * 1.4, true)
		"sound", "sound_off":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, -r * 0.25), c + Vector2(-r * 0.4, -r * 0.25), c + Vector2(0, -r * 0.65), c + Vector2(0, r * 0.65), c + Vector2(-r * 0.4, r * 0.25), c + Vector2(-r * 0.75, r * 0.25)]), color)
			if kind == "sound":
				draw_polyline(_arc_points(c + Vector2(r * 0.05, 0), r * 0.4, -0.8, 0.8, 10), color, w, true)
				draw_polyline(_arc_points(c + Vector2(r * 0.05, 0), r * 0.7, -0.8, 0.8, 12), color, w, true)
			else:
				_slash(c, r * 0.8)
		"music", "music_off":
			draw_circle(c + Vector2(-r * 0.3, r * 0.45), r * 0.25, color)
			draw_line(c + Vector2(-r * 0.08, r * 0.45), c + Vector2(-r * 0.08, -r * 0.7), color, w, true)
			draw_line(c + Vector2(-r * 0.08, -r * 0.7), c + Vector2(r * 0.5, -r * 0.4), color, w * 1.4, true)
			if kind == "music_off":
				_slash(c, r * 0.8)
		"vibe", "vibe_off":
			draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.65), Vector2(r * 0.6, r * 1.3)), color, false, w)
			for sx in [-1.0, 1.0]:
				draw_line(c + Vector2(sx * r * 0.55, -r * 0.3), c + Vector2(sx * r * 0.55, r * 0.3), color, w, true)
				draw_line(c + Vector2(sx * r * 0.78, -r * 0.18), c + Vector2(sx * r * 0.78, r * 0.18), color, w, true)
			if kind == "vibe_off":
				_slash(c, r * 0.8)
		"ad":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.55), Vector2(r * 1.6, r * 1.1)), color, false, w)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.3), c + Vector2(r * 0.35, 0), c + Vector2(-r * 0.2, r * 0.3)]), color)
		"boat":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, r * 0.2), c + Vector2(r * 0.9, r * 0.2), c + Vector2(r * 0.55, r * 0.65), c + Vector2(-r * 0.6, r * 0.65)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.05, -r * 0.85), c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.65, r * 0.1)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.05, -r * 0.6), c + Vector2(r * 0.05, r * 0.1), c + Vector2(r * 0.5, r * 0.1)]), color)
		"bolt":
			draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.15, -r * 0.9), c + Vector2(-r * 0.5, r * 0.1), c + Vector2(-r * 0.05, r * 0.1), c + Vector2(-r * 0.2, r * 0.9), c + Vector2(r * 0.5, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15)]), color)
		"moon":
			var outer := _arc_points(c, r * 0.8, PI * 0.35, PI * 1.65, 24)
			var inner := _arc_points(c + Vector2(r * 0.35, -r * 0.05), r * 0.6, PI * 1.55, PI * 0.45, 24)
			outer.append_array(inner)
			draw_colored_polygon(outer, color)
		"shield":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r * 0.85), c + Vector2(r * 0.75, -r * 0.55), c + Vector2(r * 0.6, r * 0.3), c + Vector2(0, r * 0.9), c + Vector2(-r * 0.6, r * 0.3), c + Vector2(-r * 0.75, -r * 0.55)]), color)
		"magnet":
			draw_polyline(_arc_points(c + Vector2(0, -r * 0.05), r * 0.5, 0.0, PI, 16), color, r * 0.35)
			for sx in [-1.0, 1.0]:
				draw_rect(Rect2(c + Vector2(sx * r * 0.5 - r * 0.175, -r * 0.75), Vector2(r * 0.35, r * 0.7)), color)
				draw_rect(Rect2(c + Vector2(sx * r * 0.5 - r * 0.175, -r * 0.85), Vector2(r * 0.35, r * 0.25)), Color.WHITE)
		"lock":
			draw_polyline(_arc_points(c + Vector2(0, -r * 0.15), r * 0.35, PI, TAU, 12), color, w * 1.2, true)
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.15), Vector2(r * 1.1, r * 0.85)), color)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * 0.55, 0), c + Vector2(-r * 0.15, r * 0.4), c + Vector2(r * 0.6, -r * 0.45)]), color, w * 1.6, true)
		"up", "down":
			var dy := -1.0 if kind == "up" else 1.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, dy * r * 0.85), c + Vector2(r * 0.7, 0), c + Vector2(-r * 0.7, 0)]), color)
			draw_rect(Rect2(c + Vector2(-r * 0.25, minf(0.0, -dy * r * 0.75)), Vector2(r * 0.5, r * 0.75)), color)
