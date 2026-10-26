class_name GameUI
extends CanvasLayer
## All 2D UI, built in code. Base canvas is 720 x 1280 (portrait).

signal retry_pressed
signal continue_pressed
signal next_pressed
signal triple_pressed
signal color_pressed
signal buy_pressed

const INK := Color(0.07, 0.05, 0.16, 0.9)
const GOLD := Color("ffd166")
const BOTTOM_SAFE := 230.0  # keep buttons above the banner ad

var root: Control
var hud: Control
var menu: Control
var lose_panel: Control
var win_panel: Control
var blocker: ColorRect

var level_label: Label
var pearl_label: Label
var progress: ProgressBar
var popup_label: Label
var countdown_label: Label

var menu_level: Label
var color_btn: Button
var buy_btn: Button

var lose_info: Label
var continue_btn: Button
var win_title: Label
var win_info: Label
var triple_btn: Button


func _ready() -> void:
	layer = 10
	root = _full(Control.new())
	add_child(root)
	_build_hud()
	_build_menu()
	_build_lose()
	_build_win()
	popup_label = _label("", 64, GOLD, 14)
	_place(popup_label, Control.PRESET_CENTER_TOP, -300, 330, 300, 420)
	popup_label.pivot_offset = Vector2(300, 45)
	popup_label.modulate.a = 0.0
	root.add_child(popup_label)
	countdown_label = _label("", 200, Color.WHITE, 22)
	_full(countdown_label)
	countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown_label.visible = false
	root.add_child(countdown_label)
	blocker = ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.35)
	_full(blocker)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.visible = false
	root.add_child(blocker)


# ---------------------------------------------------------------- builders

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
	ls.font_size = font_size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(480, 112)
	b.add_theme_font_size_override("font_size", 40)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		match state:
			"pressed":
				sb.bg_color = color.darkened(0.2)
			"disabled":
				sb.bg_color = color.darkened(0.55)
			_:
				sb.bg_color = color
		sb.set_corner_radius_all(32)
		sb.border_width_bottom = 8
		sb.border_color = color.darkened(0.35)
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		b.add_theme_stylebox_override(state, sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_outline_color", INK)
	b.add_theme_constant_override("outline_size", 8)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _panel_box() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -BOTTOM_SAFE * 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.2, 0.82)
	sb.set_corner_radius_all(40)
	sb.set_content_margin_all(44)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(600, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 26)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	center.add_child(panel)
	box.set_meta("holder", center)
	return box


func _build_hud() -> void:
	hud = _full(Control.new())
	root.add_child(hud)
	level_label = _label("LEVEL 1", 44)
	level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	level_label.offset_top = 70
	level_label.offset_bottom = 130
	hud.add_child(level_label)
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.min_value = 0.0
	progress.max_value = 1.0
	progress.step = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.2, 0.55)
	bg.set_corner_radius_all(14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("8fe3ff")
	fill.set_corner_radius_all(14)
	progress.add_theme_stylebox_override("background", bg)
	progress.add_theme_stylebox_override("fill", fill)
	_place(progress, Control.PRESET_CENTER_TOP, -220, 140, 220, 166)
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(progress)
	pearl_label = _label("0", 44, GOLD)
	pearl_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_place(pearl_label, Control.PRESET_TOP_RIGHT, -330, 186, -92, 246)
	hud.add_child(pearl_label)
	var dot := Panel.new()
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color("fff4e6")
	dsb.set_corner_radius_all(20)
	dsb.border_width_bottom = 4
	dsb.border_color = Color("e3c9a8")
	dot.add_theme_stylebox_override("panel", dsb)
	_place(dot, Control.PRESET_TOP_RIGHT, -80, 196, -40, 236)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(dot)


func _build_menu() -> void:
	menu = _full(Control.new())
	root.add_child(menu)
	var title := _label("MOONPULL", 104, Color("fff3d6"), 18)
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 250
	title.offset_bottom = 380
	menu.add_child(title)
	var tag := _label("You don't steer the boat.\nYou steer the sea.", 38, Color("cfe9ff"), 8)
	tag.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tag.offset_top = 390
	tag.offset_bottom = 500
	menu.add_child(tag)
	menu_level = _label("LEVEL 1", 46, GOLD)
	menu_level.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	menu_level.offset_top = 530
	menu_level.offset_bottom = 590
	menu.add_child(menu_level)
	var hint := _label("HOLD ANYWHERE\nto pull the tide", 50, Color.WHITE, 12)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -BOTTOM_SAFE - 400
	hint.offset_bottom = -BOTTOM_SAFE - 260
	menu.add_child(hint)
	var tw := hint.create_tween().set_loops()
	tw.tween_property(hint, "modulate:a", 0.35, 0.7)
	tw.tween_property(hint, "modulate:a", 1.0, 0.7)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	row.offset_top = -BOTTOM_SAFE - 120
	row.offset_bottom = -BOTTOM_SAFE
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(row)
	color_btn = _button("COLOR", Color("4e7cff"))
	color_btn.custom_minimum_size = Vector2(250, 104)
	color_btn.pressed.connect(func(): color_pressed.emit())
	row.add_child(color_btn)
	buy_btn = _button("NEW", Color("e0902f"))
	buy_btn.custom_minimum_size = Vector2(330, 104)
	buy_btn.pressed.connect(func(): buy_pressed.emit())
	row.add_child(buy_btn)


func _build_lose() -> void:
	var box := _panel_box()
	lose_panel = box.get_meta("holder")
	root.add_child(lose_panel)
	box.add_child(_label("WRECKED!", 84, Color("ff7b6b"), 14))
	lose_info = _label("", 38, Color("cfe9ff"), 6)
	box.add_child(lose_info)
	continue_btn = _button("CONTINUE  (AD)", Color("2fbf71"))
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	box.add_child(continue_btn)
	var retry := _button("RETRY", Color("4e7cff"))
	retry.pressed.connect(func(): retry_pressed.emit())
	box.add_child(retry)


func _build_win() -> void:
	var box := _panel_box()
	win_panel = box.get_meta("holder")
	root.add_child(win_panel)
	win_title = _label("HARBOR!", 84, GOLD, 14)
	box.add_child(win_title)
	win_info = _label("", 42, Color.WHITE, 8)
	box.add_child(win_info)
	triple_btn = _button("x3 PEARLS  (AD)", Color("2fbf71"))
	triple_btn.pressed.connect(func(): triple_pressed.emit())
	box.add_child(triple_btn)
	var next := _button("NEXT LEVEL", Color("4e7cff"))
	next.pressed.connect(func(): next_pressed.emit())
	box.add_child(next)


# ---------------------------------------------------------------- API

func _only(c: Control) -> void:
	for x in [hud, menu, lose_panel, win_panel]:
		x.visible = x == c
	if c != menu:
		hud.visible = true


func show_menu(level: int, pearls: int) -> void:
	_only(menu)
	hud.visible = true
	progress.visible = false
	level_label.visible = false
	menu_level.text = "LEVEL %d" % level
	set_pearls(pearls)
	refresh_shop()


func refresh_shop() -> void:
	color_btn.visible = Save.unlocked > 1
	var cost := Save.next_skin_cost()
	if cost < 0:
		buy_btn.visible = false
	else:
		buy_btn.visible = true
		buy_btn.text = "NEW COLOR  %d" % cost
		buy_btn.disabled = Save.pearls < cost


func show_hud(level: int) -> void:
	_only(hud)
	progress.visible = true
	level_label.visible = true
	level_label.text = "LEVEL %d" % level


func show_lose(can_continue: bool, run_pearls: int) -> void:
	_only(lose_panel)
	lose_info.text = "Pearls this run: %d" % run_pearls
	continue_btn.visible = can_continue


func show_win(level: int, run_pearls: int) -> void:
	_only(win_panel)
	win_title.text = "LEVEL %d CLEAR!" % level
	win_info.text = "+%d pearls" % run_pearls
	triple_btn.visible = run_pearls > 0


func set_win_pearls(total: int) -> void:
	win_info.text = "+%d pearls" % total
	triple_btn.visible = false


func set_progress(p: float) -> void:
	progress.value = p


func set_pearls(n: int) -> void:
	pearl_label.text = str(n)


func set_countdown(n: int) -> void:
	countdown_label.visible = n > 0
	countdown_label.text = str(n)


func block(on: bool) -> void:
	blocker.visible = on


func popup(text: String, color := GOLD) -> void:
	popup_label.text = text
	popup_label.label_settings.font_color = color
	popup_label.modulate.a = 1.0
	popup_label.scale = Vector2(0.6, 0.6)
	var tw := popup_label.create_tween()
	tw.tween_property(popup_label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(popup_label, "modulate:a", 0.0, 0.35)
