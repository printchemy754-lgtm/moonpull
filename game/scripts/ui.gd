class_name GameUI
extends CanvasLayer
## All 2D UI, built in code. Canvas width is 720 (portrait); height grows on tall phones.

signal settings_pressed
signal boats_pressed
signal shop_back
signal shop_prev
signal shop_next
signal shop_action
signal shop_ad
signal toggle_changed(setting: String, value: bool)
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal home_pressed
signal retry_pressed
signal continue_pressed
signal next_pressed
signal triple_pressed

const INK := Color(0.07, 0.05, 0.16, 0.92)
const GOLD := Color("ffd166")
const PANEL := Color(0.08, 0.07, 0.2, 0.86)
const BLUE := Color("4e7cff")
const GREEN := Color("2fbf71")
const ORANGE := Color("f2994a")
const BOTTOM_SAFE := 220.0  # keep buttons above the banner ad

var font: FontVariation
var top := 40.0
var root: Control

var hud: Control
var menu: Control
var shop: Control
var settings_panel: Control
var pause_panel: Control
var lose_panel: Control
var win_panel: Control
var blocker: ColorRect
var fader: ColorRect

var pearl_pill: Control
var pearl_label: Label
var level_label: Label
var progress: ProgressBar
var progress_boat: IconDraw
var effects_row: HBoxContainer
var effect_chips := {}
var popup_label: Label
var intro_panel: PanelContainer
var intro_title: Label
var intro_desc: Label
var hint_box: Control
var hint_label: Label
var hint_icon: IconDraw
var countdown_label: Label
var _hint_tw: Tween

var title_label: Label
var world_label: Label
var level_nodes: Array[PanelContainer] = []
var stars_label: Label
var menu_hint: Label

var shop_name: Label
var shop_status: Label
var shop_action_btn: Button
var shop_ad_btn: Button

var toggles := {}

var lose_info: Label
var lose_bar: ProgressBar
var continue_btn: Button
var win_title: Label
var win_info: Label
var win_stars: Array[IconDraw] = []
var triple_btn: Button


func _ready() -> void:
	layer = 10
	font = FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = 0.9
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 38
	root = Control.new()
	root.theme = th
	_full(root)
	add_child(root)
	top = 34.0 + _top_inset()

	_build_hud()
	_build_menu()
	_build_shop()
	_build_settings()
	_build_pause()
	_build_lose()
	_build_win()
	_build_overlays()


func _top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	var vp_h := get_viewport().get_visible_rect().size.y
	return clampf(float(safe.position.y) * vp_h / float(win.y), 0.0, 120.0)


# ================================================================== widgets

func _full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _place(c: Control, preset: Control.LayoutPreset, l: float, t: float, r: float, b: float) -> void:
	c.set_anchors_preset(preset)
	c.offset_left = l
	c.offset_top = t
	c.offset_right = r
	c.offset_bottom = b


func _label(text: String, font_size: int, color := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	ls.shadow_size = 0 if outline == 0 else 4
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 4)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style(color: Color, radius := 32, border := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_width_bottom = border
	sb.border_color = color.darkened(0.35)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.anti_aliasing = true
	return sb


func _button(text: String, color: Color, icon := "", min_size := Vector2(480, 110), font_size := 40) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_stylebox_override("normal", _style(color))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), 32, 3))
	b.add_theme_stylebox_override("disabled", _style(color.darkened(0.5)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	if icon != "":
		var ic := IconDraw.new(icon, Color.WHITE)
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		var s := minf(min_size.y * 0.5, 56.0)
		ic.offset_left = 26
		ic.offset_right = 26 + s
		ic.offset_top = -s * 0.5 - 3
		ic.offset_bottom = s * 0.5 - 3
		b.add_child(ic)
		if text != "":
			b.add_theme_constant_override("h_separation", 0)
			b.text = "    " + text
	_juice(b)
	return b


func _round_button(icon: String, color: Color, size := 100.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.add_theme_stylebox_override("normal", _style(color, int(size * 0.5), 6))
	b.add_theme_stylebox_override("hover", _style(color.lightened(0.06), int(size * 0.5), 6))
	b.add_theme_stylebox_override("pressed", _style(color.darkened(0.15), int(size * 0.5), 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
	var ic := IconDraw.new(icon, Color.WHITE)
	ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.offset_left = size * 0.24
	ic.offset_top = size * 0.2
	ic.offset_right = -size * 0.24
	ic.offset_bottom = -size * 0.28
	b.add_child(ic)
	b.set_meta("icon", ic)
	_juice(b)
	return b


func _juice(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func():
		Sfx.play("click")
		b.create_tween().tween_property(b, "scale", Vector2(0.92, 0.92), 0.06))
	b.button_up.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func _pill(icon: String, color: Color) -> Array:
	var p := PanelContainer.new()
	var sb := _style(Color(0.08, 0.07, 0.2, 0.7), 30, 0)
	sb.content_margin_left = 64
	sb.content_margin_right = 26
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label("0", 40, color, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(80, 56)
	p.add_child(l)
	var ic := IconDraw.new(icon, color)
	ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	ic.offset_left = 12
	ic.offset_right = 56
	ic.offset_top = -22
	ic.offset_bottom = 22
	p.add_child(ic)
	return [p, l]


func _panel_box(width := 600.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -BOTTOM_SAFE * 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := _style(PANEL, 44, 0)
	sb.set_content_margin_all(44)
	sb.border_width_top = 3
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(1, 1, 1, 0.12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	center.add_child(panel)
	box.set_meta("holder", center)
	box.set_meta("panel", panel)
	return box


func _pop(c: Control) -> void:
	c.visible = true
	var target: Control = c
	if c.has_meta("panel"):
		target = c.get_meta("panel")
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2(0.8, 0.8)
	target.modulate.a = 0.0
	var tw := target.create_tween().set_parallel(true)
	tw.tween_property(target, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "modulate:a", 1.0, 0.18)


# ================================================================== builders

func _build_hud() -> void:
	hud = _full(Control.new())
	root.add_child(hud)
	var pause_btn := _round_button("pause", Color(0.08, 0.07, 0.2, 0.7), 92.0)
	_place(pause_btn, Control.PRESET_TOP_LEFT, 24, top, 116, top + 92)
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	hud.add_child(pause_btn)
	level_label = _label("LEVEL 1", 40)
	_place(level_label, Control.PRESET_CENTER_TOP, -200, top - 4, 200, top + 50)
	hud.add_child(level_label)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.step = 0.0
	var bg := _style(Color(0.08, 0.07, 0.2, 0.6), 14, 0)
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	var fill := _style(Color("8fe3ff"), 14, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	progress.add_theme_stylebox_override("background", bg)
	progress.add_theme_stylebox_override("fill", fill)
	_place(progress, Control.PRESET_CENTER_TOP, -180, top + 58, 180, top + 82)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(progress)
	progress_boat = IconDraw.new("boat", Color.WHITE)
	progress_boat.size = Vector2(44, 44)
	hud.add_child(progress_boat)
	effects_row = HBoxContainer.new()
	effects_row.alignment = BoxContainer.ALIGNMENT_CENTER
	effects_row.add_theme_constant_override("separation", 14)
	_place(effects_row, Control.PRESET_CENTER_TOP, -300, top + 100, 300, top + 160)
	effects_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(effects_row)
	for k in [["boost", "bolt", Color("ffc531")], ["slow", "moon", Color("8fd8ff")], ["shield", "shield", Color("54e0ff")], ["magnet", "magnet", Color("ff4fd8")]]:
		var chip := PanelContainer.new()
		var sb := _style(Color(0.08, 0.07, 0.2, 0.7), 26, 0)
		sb.content_margin_left = 58
		sb.content_margin_right = 18
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label("", 30, k[2], 6)
		l.custom_minimum_size = Vector2(40, 50)
		chip.add_child(l)
		var ic := IconDraw.new(k[1], k[2])
		ic.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		ic.offset_left = 10
		ic.offset_right = 50
		ic.offset_top = -20
		ic.offset_bottom = 20
		chip.add_child(ic)
		chip.visible = false
		effects_row.add_child(chip)
		effect_chips[k[0]] = [chip, l]

	var pill := _pill("pearl", GOLD)
	pearl_pill = pill[0]
	pearl_label = pill[1]
	_place(pearl_pill, Control.PRESET_TOP_RIGHT, -250, top + 10, -24, top + 76)
	pearl_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(pearl_pill)


func _build_menu() -> void:
	menu = _full(Control.new())
	root.add_child(menu)
	var gear := _round_button("gear", Color(0.08, 0.07, 0.2, 0.7), 92.0)
	_place(gear, Control.PRESET_TOP_LEFT, 24, top, 116, top + 92)
	gear.pressed.connect(func(): settings_pressed.emit())
	menu.add_child(gear)
	var stars := _pill("star", GOLD)
	var stars_pill: Control = stars[0]
	stars_label = stars[1]
	_place(stars_pill, Control.PRESET_TOP_RIGHT, -250, top + 88, -24, top + 154)
	stars_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.add_child(stars_pill)

	title_label = _label("MOONPULL", 108, Color("fff3d6"), 20)
	_place(title_label, Control.PRESET_TOP_WIDE, 0, top + 170, 0, top + 300)
	menu.add_child(title_label)
	var tag := _label("You don't steer the boat.\nYou steer the sea.", 34, Color("cfe9ff"), 8)
	_place(tag, Control.PRESET_TOP_WIDE, 0, top + 300, 0, top + 390)
	menu.add_child(tag)

	world_label = _label("WORLD 1 · SUNSET CANYON", 32, GOLD, 8)
	_place(world_label, Control.PRESET_TOP_WIDE, 0, top + 420, 0, top + 470)
	menu.add_child(world_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	_place(row, Control.PRESET_TOP_WIDE, 0, top + 480, 0, top + 560)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(row)
	for i in Themes.LEVELS_PER_WORLD:
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(72, 72)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(str(i + 1), 34, Color.WHITE, 6)
		node.add_child(l)
		row.add_child(node)
		level_nodes.append(node)

	menu_hint = _label("HOLD ANYWHERE TO SAIL", 46, Color.WHITE, 12)
	_place(menu_hint, Control.PRESET_BOTTOM_WIDE, 0, -BOTTOM_SAFE - 330, 0, -BOTTOM_SAFE - 250)
	menu.add_child(menu_hint)
	var tw := menu_hint.create_tween().set_loops()
	tw.tween_property(menu_hint, "modulate:a", 0.35, 0.7)
	tw.tween_property(menu_hint, "modulate:a", 1.0, 0.7)

	var boats := _button("BOATS", ORANGE, "boat", Vector2(380, 110))
	_place(boats, Control.PRESET_CENTER_BOTTOM, -190, -BOTTOM_SAFE - 130, 190, -BOTTOM_SAFE - 20)
	boats.pressed.connect(func(): boats_pressed.emit())
	menu.add_child(boats)

	var bob := title_label.create_tween().set_loops()
	bob.tween_property(title_label, "position:y", -10.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)
	bob.tween_property(title_label, "position:y", 10.0, 1.2).as_relative().set_trans(Tween.TRANS_SINE)


func _build_shop() -> void:
	shop = _full(Control.new())
	root.add_child(shop)
	var back := _round_button("left", Color(0.08, 0.07, 0.2, 0.7), 92.0)
	_place(back, Control.PRESET_TOP_LEFT, 24, top, 116, top + 92)
	back.pressed.connect(func(): shop_back.emit())
	shop.add_child(back)
	var title := _label("BOATS", 64, Color("fff3d6"), 14)
	_place(title, Control.PRESET_TOP_WIDE, 0, top + 110, 0, top + 200)
	shop.add_child(title)

	shop_name = _label("DINGHY", 56, Color.WHITE, 12)
	_place(shop_name, Control.PRESET_BOTTOM_WIDE, 0, -BOTTOM_SAFE - 470, 0, -BOTTOM_SAFE - 400)
	shop.add_child(shop_name)
	shop_status = _label("", 34, GOLD, 8)
	_place(shop_status, Control.PRESET_BOTTOM_WIDE, 0, -BOTTOM_SAFE - 400, 0, -BOTTOM_SAFE - 350)
	shop.add_child(shop_status)
	var prev := _round_button("left", BLUE, 104.0)
	_place(prev, Control.PRESET_CENTER_BOTTOM, -330, -BOTTOM_SAFE - 470, -226, -BOTTOM_SAFE - 366)
	prev.pressed.connect(func(): shop_prev.emit())
	shop.add_child(prev)
	var next := _round_button("right", BLUE, 104.0)
	_place(next, Control.PRESET_CENTER_BOTTOM, 226, -BOTTOM_SAFE - 470, 330, -BOTTOM_SAFE - 366)
	next.pressed.connect(func(): shop_next.emit())
	shop.add_child(next)
	shop_action_btn = _button("SELECT", GREEN, "", Vector2(440, 110))
	_place(shop_action_btn, Control.PRESET_CENTER_BOTTOM, -220, -BOTTOM_SAFE - 330, 220, -BOTTOM_SAFE - 220)
	shop_action_btn.pressed.connect(func(): shop_action.emit())
	shop.add_child(shop_action_btn)
	shop_ad_btn = _button("+60", Color("7b5cff"), "ad", Vector2(300, 96), 36)
	_place(shop_ad_btn, Control.PRESET_CENTER_BOTTOM, -150, -BOTTOM_SAFE - 190, 150, -BOTTOM_SAFE - 94)
	shop_ad_btn.pressed.connect(func(): shop_ad.emit())
	shop.add_child(shop_ad_btn)
	var pearl_icon := IconDraw.new("pearl")
	pearl_icon.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	pearl_icon.offset_left = -70
	pearl_icon.offset_right = -30
	pearl_icon.offset_top = -23
	pearl_icon.offset_bottom = 17
	shop_ad_btn.add_child(pearl_icon)


func _build_settings() -> void:
	var box := _panel_box(560.0)
	settings_panel = box.get_meta("holder")
	root.add_child(settings_panel)
	box.add_child(_label("SETTINGS", 60, Color("fff3d6"), 12))
	for s in [["sound", "SOUND"], ["music", "MUSIC"], ["vibe", "VIBRATION"]]:
		var b := _button(s[1], BLUE, s[0], Vector2(460, 104))
		b.toggle_mode = true
		var key: String = s[0]
		b.toggled.connect(func(on: bool):
			_style_toggle(b, key, on)
			toggle_changed.emit(key, on))
		box.add_child(b)
		toggles[key] = b
	var close := _button("DONE", GREEN, "check", Vector2(460, 104))
	close.pressed.connect(func(): settings_panel.visible = false)
	box.add_child(close)
	settings_panel.visible = false


func _style_toggle(b: Button, key: String, on: bool) -> void:
	var col := GREEN if on else Color("6b6f86")
	b.add_theme_stylebox_override("normal", _style(col))
	b.add_theme_stylebox_override("hover", _style(col.lightened(0.06)))
	b.add_theme_stylebox_override("pressed", _style(col.darkened(0.1)))
	var label: String = {"sound": "SOUND", "music": "MUSIC", "vibe": "VIBRATION"}[key]
	b.text = "    %s: %s" % [label, "ON" if on else "OFF"]
	for c in b.get_children():
		if c is IconDraw:
			(c as IconDraw).set_kind(key if on else key + "_off")


func _build_pause() -> void:
	var box := _panel_box()
	pause_panel = box.get_meta("holder")
	root.add_child(pause_panel)
	box.add_child(_label("PAUSED", 72, Color("fff3d6"), 14))
	var resume := _button("RESUME", GREEN, "play")
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	var restart := _button("RESTART", BLUE, "retry")
	restart.pressed.connect(func(): restart_pressed.emit())
	box.add_child(restart)
	var home := _button("HOME", Color("6b6f86"), "home")
	home.pressed.connect(func(): home_pressed.emit())
	box.add_child(home)
	pause_panel.visible = false


func _build_lose() -> void:
	var box := _panel_box()
	lose_panel = box.get_meta("holder")
	root.add_child(lose_panel)
	box.add_child(_label("WRECKED!", 84, Color("ff7b6b"), 14))
	lose_info = _label("", 36, Color("cfe9ff"), 6)
	box.add_child(lose_info)
	lose_bar = ProgressBar.new()
	lose_bar.show_percentage = false
	lose_bar.max_value = 1.0
	lose_bar.step = 0.0
	lose_bar.custom_minimum_size = Vector2(0, 26)
	lose_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 13, 0))
	lose_bar.add_theme_stylebox_override("fill", _style(Color("ff9b6b"), 13, 0))
	box.add_child(lose_bar)
	continue_btn = _button("CONTINUE", GREEN, "ad")
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	box.add_child(continue_btn)
	var retry := _button("RETRY", BLUE, "retry")
	retry.pressed.connect(func(): retry_pressed.emit())
	box.add_child(retry)
	lose_panel.visible = false


func _build_win() -> void:
	var box := _panel_box()
	win_panel = box.get_meta("holder")
	root.add_child(win_panel)
	win_title = _label("LEVEL 1 CLEAR!", 64, GOLD, 14)
	box.add_child(win_title)
	var stars_row := HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 18)
	stars_row.custom_minimum_size = Vector2(0, 130)
	box.add_child(stars_row)
	for i in 3:
		var s := IconDraw.new("star_empty", GOLD)
		s.custom_minimum_size = Vector2(120, 120) if i == 1 else Vector2(96, 96)
		s.size_flags_vertical = Control.SIZE_SHRINK_END if i != 1 else Control.SIZE_SHRINK_BEGIN
		stars_row.add_child(s)
		win_stars.append(s)
	win_info = _label("", 44, Color.WHITE, 8)
	box.add_child(win_info)
	triple_btn = _button("x3 PEARLS", GREEN, "ad")
	triple_btn.pressed.connect(func(): triple_pressed.emit())
	box.add_child(triple_btn)
	var next := _button("NEXT", BLUE, "play")
	next.pressed.connect(func(): next_pressed.emit())
	box.add_child(next)
	win_panel.visible = false


func _build_overlays() -> void:
	popup_label = _label("", 60, GOLD, 14)
	_place(popup_label, Control.PRESET_CENTER_TOP, -340, top + 260, 340, top + 350)
	popup_label.pivot_offset = Vector2(340, 45)
	popup_label.modulate.a = 0.0
	root.add_child(popup_label)

	intro_panel = PanelContainer.new()
	var sb := _style(Color(0.08, 0.07, 0.2, 0.88), 30, 0)
	sb.set_content_margin_all(22)
	intro_panel.add_theme_stylebox_override("panel", sb)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(intro_panel, Control.PRESET_CENTER_TOP, -310, top + 170, 310, top + 300)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 4)
	intro_panel.add_child(iv)
	intro_title = _label("NEW!", 42, GOLD, 8)
	iv.add_child(intro_title)
	intro_desc = _label("", 30, Color.WHITE, 6)
	intro_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	iv.add_child(intro_desc)
	intro_panel.visible = false
	root.add_child(intro_panel)

	hint_box = Control.new()
	_place(hint_box, Control.PRESET_BOTTOM_WIDE, 0, -BOTTOM_SAFE - 330, 0, -BOTTOM_SAFE - 170)
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_icon = IconDraw.new("up", Color.WHITE)
	_place(hint_icon, Control.PRESET_CENTER_TOP, -40, 0, 40, 80)
	hint_box.add_child(hint_icon)
	hint_label = _label("", 44, Color.WHITE, 12)
	_place(hint_label, Control.PRESET_TOP_WIDE, 0, 84, 0, 150)
	hint_box.add_child(hint_label)
	hint_box.visible = false
	root.add_child(hint_box)

	countdown_label = _label("", 200, Color.WHITE, 22)
	_full(countdown_label)
	countdown_label.visible = false
	root.add_child(countdown_label)

	blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.35)
	_full(blocker)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	root.add_child(blocker)

	fader = ColorRect.new()
	fader.color = Color(0.03, 0.03, 0.1, 1.0)
	_full(fader)
	fader.modulate.a = 1.0
	root.add_child(fader)


# ================================================================== API

func _only(c: Control) -> void:
	for x in [hud, menu, shop, lose_panel, win_panel, pause_panel]:
		x.visible = x == c
	settings_panel.visible = false
	hud.visible = c == hud or c == lose_panel or c == win_panel or c == pause_panel
	pearl_pill.visible = true


func show_menu(level: int, pearls: int, world_name: String, world_no: int, step: int, star_total: int) -> void:
	_only(menu)
	set_pearls(pearls)
	stars_label.text = str(star_total)
	world_label.text = "WORLD %d · %s" % [world_no, world_name.to_upper()]
	var first := level - step + 1
	for i in level_nodes.size():
		var node := level_nodes[i]
		var n := first + i
		var col := Color(0.08, 0.07, 0.2, 0.6)
		var border := Color(1, 1, 1, 0.25)
		if n < level:
			col = Color("e0a83a")
			border = GOLD
		elif n == level:
			col = Color("4e7cff")
			border = Color.WHITE
		var sb := _style(col, 36, 0)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		sb.border_width_top = 4
		sb.border_width_bottom = 4
		sb.border_width_left = 4
		sb.border_width_right = 4
		sb.border_color = border
		node.add_theme_stylebox_override("panel", sb)
		(node.get_child(0) as Label).text = str(n)
		node.pivot_offset = Vector2(36, 36)
		node.scale = Vector2.ONE
		if n == level:
			var tw := node.create_tween().set_loops(4)
			tw.tween_property(node, "scale", Vector2(1.15, 1.15), 0.35)
			tw.tween_property(node, "scale", Vector2.ONE, 0.35)


func show_shop(name_text: String, price: int, owned: bool, selected: bool, pearls: int, ad_ready: bool) -> void:
	_only(shop)
	shop_name.text = name_text
	set_pearls(pearls)
	shop_action_btn.disabled = false
	if selected:
		shop_status.text = "SAILING"
		shop_action_btn.text = "SELECTED"
		shop_action_btn.disabled = true
	elif owned:
		shop_status.text = "OWNED"
		shop_action_btn.text = "SELECT"
	else:
		shop_status.text = "%d PEARLS" % price
		shop_action_btn.text = "BUY  %d" % price
		shop_action_btn.disabled = pearls < price
	shop_ad_btn.disabled = not ad_ready
	var tw := shop_name.create_tween()
	shop_name.pivot_offset = Vector2(360, 35)
	shop_name.scale = Vector2(0.8, 0.8)
	tw.tween_property(shop_name, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_settings(sound: bool, music: bool, vibe: bool) -> void:
	for pair in [["sound", sound], ["music", music], ["vibe", vibe]]:
		var b: Button = toggles[pair[0]]
		b.set_pressed_no_signal(pair[1])
		_style_toggle(b, pair[0], pair[1])
	_pop(settings_panel)


func show_hud(level: int) -> void:
	_only(hud)
	level_label.text = "LEVEL %d" % level
	set_progress(0.0)


func show_pause() -> void:
	_only(pause_panel)
	_pop(pause_panel)


func show_lose(can_continue: bool, progress_done: float, run_pearls: int) -> void:
	_only(lose_panel)
	lose_info.text = "%d%% of the way  ·  %d pearls" % [int(progress_done * 100.0), run_pearls]
	lose_bar.value = progress_done
	continue_btn.visible = can_continue
	_pop(lose_panel)


func show_win(level: int, stars: int, run_pearls: int) -> void:
	_only(win_panel)
	win_title.text = "LEVEL %d CLEAR!" % level
	win_info.text = "+0"
	triple_btn.visible = run_pearls > 0
	for s in win_stars:
		s.set_kind("star_empty")
		s.scale = Vector2.ONE
	_pop(win_panel)
	var tw := create_tween()
	tw.tween_interval(0.35)
	for i in stars:
		var s: IconDraw = win_stars[i]
		tw.tween_callback(func():
			s.set_kind("star")
			s.pivot_offset = s.size * 0.5
			s.scale = Vector2(1.8, 1.8)
			Sfx.play("star", 1.0 + i * 0.15)
			s.create_tween().tween_property(s, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
		tw.tween_interval(0.28)
	tw.tween_method(func(v: float): win_info.text = "+%d" % int(v), 0.0, float(run_pearls), 0.6)


func set_win_pearls(total: int) -> void:
	win_info.text = "+%d" % total
	triple_btn.visible = false
	win_info.pivot_offset = win_info.size * 0.5
	win_info.scale = Vector2(1.6, 1.6)
	win_info.create_tween().tween_property(win_info, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func set_progress(p: float) -> void:
	progress.value = p
	var r := progress.get_global_rect()
	progress_boat.position = Vector2(r.position.x + r.size.x * p - 22.0, r.position.y - 40.0)


func set_pearls(n: int) -> void:
	pearl_label.text = str(n)


func bump_pearls() -> void:
	pearl_pill.pivot_offset = pearl_pill.size * 0.5
	pearl_pill.scale = Vector2(1.15, 1.15)
	pearl_pill.create_tween().tween_property(pearl_pill, "scale", Vector2.ONE, 0.15)


## effects: kind -> seconds left (or -1 for "active, no timer").
func set_effects(effects: Dictionary) -> void:
	for k in effect_chips:
		var chip: PanelContainer = effect_chips[k][0]
		var l: Label = effect_chips[k][1]
		var v: float = effects.get(k, 0.0)
		chip.visible = v != 0.0
		l.text = "" if v < 0.0 else "%.0f" % ceilf(v)


func set_countdown(n: int) -> void:
	countdown_label.visible = n > 0
	countdown_label.text = str(n)
	if n > 0:
		countdown_label.pivot_offset = countdown_label.size * 0.5
		countdown_label.scale = Vector2(1.5, 1.5)
		countdown_label.create_tween().tween_property(countdown_label, "scale", Vector2.ONE, 0.25)


func block(on: bool) -> void:
	blocker.visible = on


func fade_in() -> void:
	fader.visible = true
	fader.modulate.a = 1.0
	var tw := fader.create_tween()
	tw.tween_property(fader, "modulate:a", 0.0, 0.45)
	tw.tween_callback(func(): fader.visible = false)


func fade_out(duration := 0.3) -> Tween:
	fader.visible = true
	fader.modulate.a = 0.0
	var tw := fader.create_tween()
	tw.tween_property(fader, "modulate:a", 1.0, duration)
	return tw


func popup(text: String, color := GOLD) -> void:
	popup_label.text = text
	popup_label.label_settings.font_color = color
	popup_label.modulate.a = 1.0
	popup_label.scale = Vector2(0.6, 0.6)
	var tw := popup_label.create_tween()
	tw.tween_property(popup_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.55)
	tw.tween_property(popup_label, "modulate:a", 0.0, 0.35)


func intro(title: String, desc: String) -> void:
	intro_title.text = "NEW: " + title
	intro_desc.text = desc
	intro_panel.visible = true
	intro_panel.modulate.a = 0.0
	var tw := intro_panel.create_tween()
	tw.tween_property(intro_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(intro_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): intro_panel.visible = false)


func hint(text: String, up: bool) -> void:
	if hint_box.visible and hint_label.text == text:
		return
	hint_label.text = text
	hint_icon.set_kind("up" if up else "down")
	hint_box.visible = true
	hint_box.modulate.a = 1.0
	if _hint_tw:
		_hint_tw.kill()
	hint_icon.offset_top = 0
	hint_icon.offset_bottom = 80
	_hint_tw = hint_icon.create_tween().set_loops(6)
	_hint_tw.tween_property(hint_icon, "position:y", -14.0 if up else 14.0, 0.3).as_relative()
	_hint_tw.tween_property(hint_icon, "position:y", 14.0 if up else -14.0, 0.3).as_relative()


func hide_hint() -> void:
	hint_box.visible = false
