class_name IconDraw
extends Control
## Vector icons drawn in code (no image assets, no font glyphs needed).

var kind := "star"
var color := Color.WHITE
var color2 := Color.WHITE
const INK := Color(0.09, 0.07, 0.23)


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
		"coin":
			draw_circle(c + Vector2(0, r * 0.08), r * 0.9, Color("b8650a"))
			draw_circle(c, r * 0.9, Color("ffc531"))
			draw_circle(c, r * 0.68, Color("f2a516"))
			draw_circle(c - Vector2(r * 0.04, r * 0.04), r * 0.62, Color("ffd65c"))
			var mo := _arc_points(c, r * 0.4, PI * 0.4, PI * 1.6, 16)
			mo.append_array(_arc_points(c + Vector2(r * 0.18, -r * 0.02), r * 0.3, PI * 1.5, PI * 0.5, 16))
			draw_colored_polygon(mo, Color("c97a10"))
			draw_arc(c, r * 0.8, PI * 1.1, PI * 1.45, 10, Color(1, 1, 1, 0.75), r * 0.12, true)
		"swatch":
			draw_circle(c, r * 0.92, INK)
			draw_circle(c, r * 0.78, color)
			draw_circle(c - Vector2(r * 0.28, r * 0.28), r * 0.18, Color(1, 1, 1, 0.45))
		"flag2":
			draw_rect(Rect2(c - Vector2(r * 0.12, r * 0.9), Vector2(r * 0.14, r * 1.8)), INK)
			draw_rect(Rect2(c + Vector2(0.0, -r * 0.85), Vector2(r * 0.9, r * 0.75)), INK)
			draw_rect(Rect2(c + Vector2(r * 0.07, -r * 0.78), Vector2(r * 0.76, r * 0.61)), color)
			draw_circle(c + Vector2(r * 0.45, -r * 0.47), r * 0.17, color2)
		"hat":
			draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.25), Vector2(r * 1.7, r * 0.3)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.6), Vector2(r * 1.0, r * 0.95)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.75, r * 0.32), Vector2(r * 1.5, r * 0.16)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.4, -r * 0.5), Vector2(r * 0.8, r * 0.8)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.4, r * 0.05), Vector2(r * 0.8, r * 0.15)), color2)
		"wake":
			for k in 3:
				var y := c.y - r * 0.5 + k * r * 0.5
				var pts := PackedVector2Array()
				for i in 13:
					var x := c.x - r * 0.85 + i * r * 1.7 / 12.0
					pts.append(Vector2(x, y + sin(i * 1.1 + k) * r * 0.12))
				draw_polyline(pts, INK, r * 0.3, true)
				draw_polyline(pts, color if k != 1 else color2, r * 0.18, true)
		"chest":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.2), Vector2(r * 1.8, r * 1.0)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.1), Vector2(r * 1.6, r * 0.8)), Color("b8642b"))
			var lid := _arc_points(c + Vector2(0, -r * 0.2), r * 0.9, PI, TAU, 16)
			draw_colored_polygon(lid, INK)
			var lid2 := _arc_points(c + Vector2(0, -r * 0.24), r * 0.8, PI, TAU, 16)
			draw_colored_polygon(lid2, Color("d9803a"))
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.28), Vector2(r * 1.8, r * 0.16)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.16, -r * 0.34), Vector2(r * 0.32, r * 0.4)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.08, -r * 0.24), Vector2(r * 0.16, r * 0.18)), INK)
		"task":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.85), Vector2(r * 1.4, r * 1.7)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.75), Vector2(r * 1.2, r * 1.5)), Color("fff3d6"))
			for k in 3:
				var y := c.y - r * 0.4 + k * r * 0.42
				draw_line(Vector2(c.x - r * 0.42, y), Vector2(c.x - r * 0.28, y + r * 0.12), color, r * 0.12, true)
				draw_line(Vector2(c.x - r * 0.28, y + r * 0.12), Vector2(c.x - r * 0.08, y - r * 0.12), color, r * 0.12, true)
				draw_line(Vector2(c.x + r * 0.02, y), Vector2(c.x + r * 0.45, y), Color(0.3, 0.3, 0.45), r * 0.1, true)
		"trophy":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.62, -r * 0.8), c + Vector2(r * 0.62, -r * 0.8), c + Vector2(r * 0.45, r * 0.05), c + Vector2(0, r * 0.25), c + Vector2(-r * 0.45, r * 0.05)]), color)
			draw_arc(c + Vector2(-r * 0.6, -r * 0.45), r * 0.28, PI * 0.5, PI * 1.5, 10, color, r * 0.13, true)
			draw_arc(c + Vector2(r * 0.6, -r * 0.45), r * 0.28, -PI * 0.5, PI * 0.5, 10, color, r * 0.13, true)
			draw_rect(Rect2(c + Vector2(-r * 0.1, r * 0.2), Vector2(r * 0.2, r * 0.35)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.45, r * 0.55), Vector2(r * 0.9, r * 0.25)), color)
		"user":
			draw_circle(c + Vector2(0, -r * 0.3), r * 0.38, color)
			draw_colored_polygon(_arc_points(c + Vector2(0, r * 0.75), r * 0.72, PI, TAU, 16), color)
		"wifi":
			for k in 3:
				draw_arc(c + Vector2(0, r * 0.55), r * (0.35 + k * 0.32), PI * 1.2, PI * 1.8, 12, color, r * 0.15, true)
			draw_circle(c + Vector2(0, r * 0.55), r * 0.13, color)
		"pencil":
			draw_line(c + Vector2(-r * 0.6, r * 0.6), c + Vector2(r * 0.55, -r * 0.55), color, r * 0.3, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.75, r * 0.75), c + Vector2(-r * 0.68, r * 0.38), c + Vector2(-r * 0.38, r * 0.68)]), color)
		"dice":
			draw_rect(Rect2(c - Vector2(r * 0.8, r * 0.8), Vector2(r * 1.6, r * 1.6)), color)
			for d in [Vector2(-0.4, -0.4), Vector2(0.4, 0.4), Vector2(0, 0), Vector2(0.4, -0.4), Vector2(-0.4, 0.4)]:
				draw_circle(c + d * r, r * 0.14, INK)
		"wall":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.6), Vector2(r * 1.8, r * 1.5)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.5), Vector2(r * 1.6, r * 1.3)), color)
			draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.85), Vector2(r * 1.9, r * 0.35)), INK)
			draw_rect(Rect2(c + Vector2(-r * 0.87, -r * 0.78), Vector2(r * 1.74, r * 0.22)), color2)
			var dark := color.darkened(0.3)
			for k in 3:
				var y := c.y - r * 0.15 + k * r * 0.35
				draw_line(Vector2(c.x - r * 0.8, y), Vector2(c.x + r * 0.8, y), dark, r * 0.06)
				var off := r * (0.0 if k % 2 == 0 else 0.4)
				for x in [-0.4, 0.4]:
					draw_line(Vector2(c.x + r * x + off - r * 0.2, y - r * 0.35), Vector2(c.x + r * x + off - r * 0.2, y), dark, r * 0.06)
		"wave":
			for k in 2:
				var y := c.y - r * 0.2 + k * r * 0.5
				var pts := PackedVector2Array()
				for i in 17:
					var x := c.x - r * 0.85 + i * r * 1.7 / 16.0
					pts.append(Vector2(x, y + sin(i * 0.8) * r * 0.18))
				draw_polyline(pts, color, r * 0.2, true)
		"share":
			var p1 := c + Vector2(-r * 0.5, 0)
			var p2 := c + Vector2(r * 0.45, -r * 0.5)
			var p3 := c + Vector2(r * 0.45, r * 0.5)
			draw_line(p1, p2, color, r * 0.14, true)
			draw_line(p1, p3, color, r * 0.14, true)
			for pt in [p1, p2, p3]:
				draw_circle(pt, r * 0.24, color)
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
