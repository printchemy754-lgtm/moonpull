class_name GameUI
extends CanvasLayer
## All 2D UI, built in code. Canvas width is 720 (portrait); height grows on tall phones.

signal settings_pressed
signal privacy_pressed
signal boats_pressed
signal free_pressed
signal daily_claim(multiplier: int)
signal shop_back
signal shop_tab(cat: String)
signal shop_pick(index: int)
signal shop_action
signal shop_side(slot: String)
signal rank_closed
signal endless_pressed
signal share_pressed
signal mystery_open
signal toggle_changed(setting: String, value: bool)
signal pause_pressed
signal resume_pressed
signal restart_pressed
signal home_pressed
signal retry_pressed       # "No thanks" on the wrecked screen
signal continue_pressed
signal next_pressed        # "No thanks" on the win screen
signal claim_pressed(multiplier: int)
signal name_changed(new_name: String)
signal tasks_pressed
signal task_claim(index: int)
signal task_bonus
signal chest_pressed
signal chest_open(kind: String)
signal race_pressed
signal race_ai
signal race_host
signal race_join(code: String)
signal race_start
signal race_leave
signal race_double
signal race_done
signal upgrades_pressed
signal season_pressed
signal upgrade_buy(id: String)
signal star_drop_done(prize: int)

const INK := Color(0.07, 0.05, 0.16, 0.92)
const GOLD := Color("ffd166")
const PANEL := Color(0.08, 0.07, 0.2, 0.88)
const BLUE := Color("4e7cff")
const GREEN := Color("2fbf71")
const ORANGE := Color("f2994a")
const PURPLE := Color("7b5cff")
const BOTTOM_SAFE := 220.0  # keep buttons above the banner ad

var font: Font
var title_font: Font
var top := 40.0
var root: Control

var hud: Control
var menu: Control
var shop: Control
var settings_panel: Control
var daily_panel: Control
var pause_panel: Control
var lose_panel: Control
var win_panel: Control
var star_drop: StarDrop
var blocker: ColorRect
var fader: ColorRect

var coin_pill: Control
var coin_label: Label
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

var logo: TextureRect
var world_label: Label
var level_nodes: Array[PanelContainer] = []
var stars_label: Label
var menu_hint: Label
var free_btn: Button
var profile_btn: Button
var tasks_btn: Button
var chest_btn: Button
var race_btn: Button
var power_btn: Button
var season_btn: Button
var upgrades_panel: Control
var upgrades_box: VBoxContainer
var fever_box: Control
var fever_bar: ProgressBar
var fever_fill: StyleBoxFlat
var fever_label: Label
var boss_box: Control
var boss_bar: ProgressBar
var fever_flash: ColorRect
var lives_row: HBoxContainer
var _fever_tw: Tween
var profile_panel: Control
var name_edit: LineEdit
var tasks_panel: Control
var tasks_box: VBoxContainer
var chest_panel: Control
var chest_free_btn: Button
var chest_star_btn: Button
var chest_star_bar: ProgressBar
var reveal_panel: Control
var reveal_icon: IconDraw
var reveal_text: Label
var race_panel: Control
var race_status: Label
var race_code_label: Label
var race_code_edit: LineEdit
var race_players: VBoxContainer
var race_start_btn: Button
var race_lan_box: VBoxContainer
var race_hud: VBoxContainer
var race_place: Label
var race_list: VBoxContainer
var results_panel: Control
var results_title: Label
var results_list: VBoxContainer
var results_reward: Label
var results_double: Button
var _modals: Array[Control] = []

var shop_name: Label
var shop_status: Label
var shop_action_btn: Button
var shop_free_btn: Button
var shop_tabs := {}
var shop_tiles: HBoxContainer
var shop_scroll: ScrollContainer
var shop_title: Label
var shop_side_row: HBoxContainer
var shop_side_btns := {}
var rank_label: Label
var rank_bar: ProgressBar
var rankup_panel: Control
var rankup_title: Label
var rankup_rows: VBoxContainer
var rankup_next: Label
var daily_track: HBoxContainer
var endless_btn: Button
var endless_best: Label
var best_label: Label
var lose_share: Button
var lose_title: Label
var chest_mystery_btn: Button
var daily_tomorrow: Label

var toggles := {}
var privacy_btn: Button

var daily_day_label: Label
var daily_amount_label: Label

var lose_info: Label
var lose_bar: ProgressBar
var lose_coins: Label
var continue_btn: Button
var lose_mult: MultiplierBar
var lose_claim: Button
var lose_skip: Button

var win_title: Label
var win_coins: Label
var win_stars: Array[IconDraw] = []
var win_mult: MultiplierBar
var win_claim: Button
var win_skip: Button


func _ready() -> void:
	layer = 10
	font = load("res://fonts/Montserrat-ExtraBold.ttf")
	title_font = load("res://fonts/Montserrat-Black.ttf")
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
	_build_daily()
	_build_pause()
	_build_lose()
	_build_win()
	_build_profile()
	_build_tasks()
	_build_upgrades()
	_build_chests()
	_build_race()
	_build_results()
	_build_rankup()
	_build_overlays()
	_build_star_drop()


func _top_inset() -> float:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0 or safe.size.y <= 0:
		return 0.0
	var vp_h := get_viewport().get_visible_rect().size.y
	return clampf(float(safe.position.y) * vp_h / float(win.y), 0.0, 120.0)


static func fmt(n: int) -> String:
	## 12500 -> "12,500"
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


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
	ls.font = title_font if font_size >= 56 else font
	ls.font_size = int(font_size * 0.88) if font_size >= 56 else font_size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	ls.shadow_size = 0 if outline == 0 else 2
	ls.shadow_color = Color(0.07, 0.05, 0.16, 0.6)
	ls.shadow_offset = Vector2(0, 5)
	l.label_settings = ls
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _style(color: Color, radius := 32, border := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		# neon rim: a bright edge of the button's own colour plus a soft glow
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3 + border / 2
		sb.border_color = color.lightened(0.45)
		sb.shadow_color = Color(color.r, color.g, color.b, 0.45)
		sb.shadow_size = 10
	else:
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
		b.set_meta("icon", ic)
		if text != "":
			b.text = "    " + text
	_juice(b)
	return b


func _link_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.custom_minimum_size = Vector2(300, 70)
	b.add_theme_font_size_override("font_size", 32)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(0.85, 0.88, 1.0, 0.75))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.focus_mode = Control.FOCUS_NONE
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


## Rounded counter: [icon][number]. Icon and number sit side by side in a row
## (a PanelContainer stretches every direct child over its whole area).
func _pill(icon: String, color: Color) -> Array:
	var p := PanelContainer.new()
	var sb := _style(Color(0.08, 0.07, 0.2, 0.75), 30, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 22
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Color(color, 0.6)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	var ic := IconDraw.new(icon, color)
	ic.custom_minimum_size = Vector2(48, 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l := _label("0", 40, color, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.custom_minimum_size = Vector2(60, 56)
	row.add_child(l)
	return [p, l]


func _panel_box(width := 600.0) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -BOTTOM_SAFE * 0.5
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := PanelContainer.new()
	var sb := _style(PANEL, 36, 0)
	sb.set_content_margin_all(40)
	sb.border_width_top = 3
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = Color("00e5ff")
	sb.shadow_color = Color(0.0, 0.9, 1.0, 0.3)
	sb.shadow_size = 18
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	center.add_child(panel)
	box.set_meta("holder", center)
	box.set_meta("panel", panel)
	center.set_meta("panel", panel)
	return box


func _center(c: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(c)
	return cc


func _coin_row(font_size: int) -> Array:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := IconDraw.new("coin")
	ic.custom_minimum_size = Vector2(font_size * 1.1, font_size * 1.1)
	row.add_child(ic)
	var l := _label("0", font_size, GOLD, 10)
	row.add_child(l)
	return [row, l]


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


func _set_btn_text(b: Button, text: String) -> void:
	b.text = ("    " + text) if b.has_meta("icon") else text


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
	best_label = _label("", 26, GOLD, 6)
	_place(best_label, Control.PRESET_CENTER_TOP, -200, top + 52, 200, top + 84)
	best_label.visible = false
	hud.add_child(best_label)
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
		sb.content_margin_left = 10
		sb.content_margin_right = 16
		chip.add_theme_stylebox_override("panel", sb)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var crow := HBoxContainer.new()
		crow.add_theme_constant_override("separation", 6)
		crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(crow)
		var ic := IconDraw.new(k[1], k[2])
		ic.custom_minimum_size = Vector2(40, 40)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		crow.add_child(ic)
		var l := _label("", 30, k[2], 6)
		l.custom_minimum_size = Vector2(30, 50)
		crow.add_child(l)
		chip.visible = false
		effects_row.add_child(chip)
		effect_chips[k[0]] = [chip, l]

	lives_row = HBoxContainer.new()
	lives_row.add_theme_constant_override("separation", 4)
	lives_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(lives_row, Control.PRESET_TOP_LEFT, 24, top + 100, 200, top + 140)
	hud.add_child(lives_row)
	fever_flash = ColorRect.new()
	fever_flash.color = Color(1.0, 0.2, 0.85, 0.0)
	_full(fever_flash)
	hud.add_child(fever_flash)
	fever_box = Control.new()
	fever_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(fever_box, Control.PRESET_CENTER_TOP, -230, top + 168, 230, top + 206)
	hud.add_child(fever_box)
	fever_label = _label("FEVER", 26, Color("ff8be6"), 6)
	_place(fever_label, Control.PRESET_LEFT_WIDE, 0, 0, 110, 0)
	fever_box.add_child(fever_label)
	fever_bar = _thin_bar(Color("ff4fd8"))
	fever_fill = fever_bar.get_theme_stylebox("fill") as StyleBoxFlat
	_place(fever_bar, Control.PRESET_FULL_RECT, 118, 8, 0, -8)
	fever_box.add_child(fever_bar)
	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(boss_box, Control.PRESET_CENTER_TOP, -230, top + 212, 230, top + 252)
	hud.add_child(boss_box)
	var bl := _label("BOSS", 26, Color("ff6b6b"), 6)
	_place(bl, Control.PRESET_LEFT_WIDE, 0, 0, 110, 0)
	boss_box.add_child(bl)
	boss_bar = _thin_bar(Color("ff3d5a"))
	_place(boss_bar, Control.PRESET_FULL_RECT, 118, 6, 0, -6)
	boss_box.add_child(boss_bar)
	boss_box.visible = false

	var pill := _pill("coin", GOLD)
	coin_pill = pill[0]
	coin_label = pill[1]
	_place(coin_pill, Control.PRESET_TOP_RIGHT, -260, top + 10, -24, top + 76)
	coin_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	root.add_child(coin_pill)


func _thin_bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := _style(Color(0.05, 0.04, 0.15, 0.75), 12, 0)
	bg.content_margin_left = 0
	bg.content_margin_right = 0
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.border_color = Color(color, 0.7)
	var fill := _style(color, 12, 0)
	fill.content_margin_left = 0
	fill.content_margin_right = 0
	fill.shadow_color = Color(color, 0.6)
	fill.shadow_size = 8
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _side_button(icon: String, text: String, color: Color, size := 118.0) -> Button:
	var b := _round_button(icon, color, size)
	var ic: IconDraw = b.get_meta("icon")
	ic.offset_bottom = -size * 0.34
	ic.offset_top = size * 0.14
	var l := _label(text, 22, Color.WHITE, 6)
	l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	l.offset_top = -40
	l.offset_bottom = -8
	b.add_child(l)
	b.set_meta("label", l)
	var badge := PanelContainer.new()
	var sb := _style(Color("ff3d5a"), 20, 0)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.border_width_left = 3
	sb.border_width_right = 3
	sb.border_width_top = 3
	sb.border_width_bottom = 3
	sb.border_color = Toon.INK
	badge.add_theme_stylebox_override("panel", sb)
	badge.position = Vector2(size - 36, -8)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bl := _label("!", 24, Color.WHITE, 4)
	badge.add_child(bl)
	badge.visible = false
	b.add_child(badge)
	b.set_meta("badge", badge)
	b.set_meta("badge_label", bl)
	return b


func set_badge(b: Button, text: String) -> void:
	var badge: Control = b.get_meta("badge")
	badge.visible = text != ""
	(b.get_meta("badge_label") as Label).text = text


func set_side_text(b: Button, text: String) -> void:
	(b.get_meta("label") as Label).text = text


func _build_menu() -> void:
	menu = _full(Control.new())
	root.add_child(menu)
	# top-left: profile + settings
	profile_btn = _button("Captain", Color(0.08, 0.07, 0.2, 0.75), "user", Vector2(300, 76), 28)
	_place(profile_btn, Control.PRESET_TOP_LEFT, 24, top + 6, 324, top + 82)
	profile_btn.pressed.connect(func():
		name_edit.text = Save.player_name
		_pop(profile_panel))
	menu.add_child(profile_btn)
	rank_label = _label("RANK 1", 22, GOLD, 6)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_place(rank_label, Control.PRESET_TOP_LEFT, 30, top + 84, 330, top + 110)
	menu.add_child(rank_label)
	rank_bar = ProgressBar.new()
	rank_bar.show_percentage = false
	rank_bar.max_value = 1.0
	rank_bar.step = 0.0
	rank_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rbg := _style(Color(0.08, 0.07, 0.2, 0.75), 10, 0)
	rbg.content_margin_left = 0
	rbg.content_margin_right = 0
	rbg.border_width_left = 3
	rbg.border_width_right = 3
	rbg.border_width_top = 3
	rbg.border_width_bottom = 3
	rbg.border_color = Toon.INK
	var rfill := _style(GOLD, 8, 0)
	rfill.content_margin_left = 0
	rfill.content_margin_right = 0
	rank_bar.add_theme_stylebox_override("background", rbg)
	rank_bar.add_theme_stylebox_override("fill", rfill)
	_place(rank_bar, Control.PRESET_TOP_LEFT, 28, top + 112, 324, top + 132)
	menu.add_child(rank_bar)
	var gear := _round_button("gear", Color(0.08, 0.07, 0.2, 0.7), 76.0)
	_place(gear, Control.PRESET_TOP_LEFT, 24, top + 142, 100, top + 218)
	gear.pressed.connect(func(): settings_pressed.emit())
	menu.add_child(gear)
	var stars := _pill("star", GOLD)
	var stars_pill: Control = stars[0]
	stars_label = stars[1]
	_place(stars_pill, Control.PRESET_TOP_RIGHT, -260, top + 88, -24, top + 154)
	stars_pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	menu.add_child(stars_pill)

	logo = TextureRect.new()
	logo.texture = load("res://logo.svg")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(logo, Control.PRESET_CENTER_TOP, -300, top + 170, 300, top + 550)
	logo.pivot_offset = Vector2(300, 190)
	menu.add_child(logo)
	var breathe := logo.create_tween().set_loops()
	breathe.tween_property(logo, "scale", Vector2(1.03, 1.03), 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(logo, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)

	world_label = _label("WORLD 1 · SUNSET CANYON", 30, GOLD, 8)
	_place(world_label, Control.PRESET_TOP_WIDE, 0, top + 560, 0, top + 606)
	menu.add_child(world_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_place(row, Control.PRESET_TOP_WIDE, 0, top + 614, 0, top + 690)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(row)
	for i in Themes.LEVELS_PER_WORLD:
		var node := PanelContainer.new()
		node.custom_minimum_size = Vector2(66, 66)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(str(i + 1), 32, Color.WHITE, 6)
		node.add_child(l)
		row.add_child(node)
		level_nodes.append(node)

	# side buttons, Going-Balls style
	tasks_btn = _side_button("task", "TASKS", Color("2fbf71"), 110.0)
	_place(tasks_btn, Control.PRESET_TOP_LEFT, 22, top + 700, 132, top + 810)
	tasks_btn.pressed.connect(func(): tasks_pressed.emit())
	menu.add_child(tasks_btn)
	chest_btn = _side_button("chest", "CHEST", Color("e0902f"), 110.0)
	chest_btn.get_meta("icon").color = GOLD
	_place(chest_btn, Control.PRESET_TOP_LEFT, 22, top + 822, 132, top + 932)
	chest_btn.pressed.connect(func(): chest_pressed.emit())
	menu.add_child(chest_btn)
	race_btn = _side_button("trophy", "RACE", Color("ff5a4e"), 110.0)
	race_btn.get_meta("icon").color = GOLD
	_place(race_btn, Control.PRESET_TOP_RIGHT, -132, top + 700, -22, top + 810)
	race_btn.pressed.connect(func(): race_pressed.emit())
	menu.add_child(race_btn)
	var pulse := race_btn.create_tween().set_loops()
	pulse.tween_property(race_btn, "scale", Vector2(1.07, 1.07), 0.6).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(race_btn, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
	var boats := _side_button("ball", "BALL", ORANGE, 110.0)
	_place(boats, Control.PRESET_TOP_RIGHT, -132, top + 822, -22, top + 932)
	boats.pressed.connect(func(): boats_pressed.emit())
	menu.add_child(boats)
	power_btn = _side_button("bolt", "POWER", PURPLE, 110.0)
	power_btn.get_meta("icon").color = GOLD
	_place(power_btn, Control.PRESET_TOP_LEFT, 22, top + 944, 132, top + 1054)
	power_btn.pressed.connect(func(): upgrades_pressed.emit())
	menu.add_child(power_btn)

	menu_hint = _label("TAP TO ROLL\nSLIDE TO STEER", 36, Color.WHITE, 12)
	_place(menu_hint, Control.PRESET_TOP_WIDE, 150, top + 704, -150, top + 800)
	menu.add_child(menu_hint)
	var tw := menu_hint.create_tween().set_loops()
	tw.tween_property(menu_hint, "modulate:a", 0.35, 0.7)
	tw.tween_property(menu_hint, "modulate:a", 1.0, 0.7)

	endless_btn = _button("ENDLESS", Color("ff7a2f"), "wave", Vector2(300, 84), 34)
	_place(endless_btn, Control.PRESET_CENTER_TOP, -150, top + 800, 150, top + 884)
	endless_btn.pressed.connect(func(): endless_pressed.emit())
	menu.add_child(endless_btn)
	var glow := endless_btn.create_tween().set_loops()
	glow.tween_property(endless_btn, "modulate", Color(1.15, 1.1, 1.0), 0.7).set_trans(Tween.TRANS_SINE)
	glow.tween_property(endless_btn, "modulate", Color.WHITE, 0.7).set_trans(Tween.TRANS_SINE)
	endless_best = _label("BEST 0", 24, GOLD, 6)
	_place(endless_best, Control.PRESET_CENTER_TOP, -150, top + 884, 150, top + 912)
	menu.add_child(endless_best)

	free_btn = _button("+500", PURPLE, "ad", Vector2(300, 100))
	_place(free_btn, Control.PRESET_CENTER_BOTTOM, -150, -BOTTOM_SAFE - 110, 150, -BOTTOM_SAFE - 10)
	free_btn.pressed.connect(func(): free_pressed.emit())
	menu.add_child(free_btn)


# ---------------------------------------------------------------- profile

func _build_profile() -> void:
	var box := _panel_box(600.0)
	profile_panel = box.get_meta("holder")
	root.add_child(profile_panel)
	_modals.append(profile_panel)
	box.add_child(_label("YOUR NAME", 64, GOLD, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	name_edit = LineEdit.new()
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(390, 96)
	name_edit.add_theme_font_size_override("font_size", 40)
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var es := _style(Color("f7f2e6"), 26, 6)
	name_edit.add_theme_stylebox_override("normal", es)
	name_edit.add_theme_stylebox_override("focus", es)
	name_edit.add_theme_color_override("font_color", Toon.INK)
	name_edit.add_theme_color_override("caret_color", Toon.INK)
	row.add_child(name_edit)
	var dice := _round_button("dice", BLUE, 96.0)
	dice.pressed.connect(func(): name_edit.text = Save.random_name())
	row.add_child(dice)
	box.add_child(_label("Shown above your ball in races", 26, Color("cfe9ff"), 4))
	var ok := _button("SAVE", GREEN, "check", Vector2(480, 104))
	ok.pressed.connect(func():
		name_changed.emit(name_edit.text)
		profile_panel.visible = false)
	box.add_child(ok)
	profile_panel.visible = false


# ---------------------------------------------------------------- tasks

func _build_tasks() -> void:
	var box := _panel_box(640.0)
	tasks_panel = box.get_meta("holder")
	root.add_child(tasks_panel)
	_modals.append(tasks_panel)
	box.add_child(_label("DAILY TASKS", 64, GOLD, 12))
	box.add_child(_label("New tasks every day", 26, Color("cfe9ff"), 4))
	tasks_box = VBoxContainer.new()
	tasks_box.add_theme_constant_override("separation", 14)
	box.add_child(tasks_box)
	var close := _button("CLOSE", BLUE, "close", Vector2(480, 96))
	close.pressed.connect(func(): tasks_panel.visible = false)
	box.add_child(close)
	tasks_panel.visible = false


func show_tasks(list: Array, bonus_ready: bool, bonus_done: bool, bonus: int) -> void:
	for ch in tasks_box.get_children():
		ch.queue_free()
	for i in list.size():
		var m: Dictionary = list[i]
		var row := PanelContainer.new()
		var sb := _style(Color(0.15, 0.13, 0.32), 24, 4)
		sb.set_content_margin_all(16)
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var tl := _label(Missions.text(m), 28, Color.WHITE, 4)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(tl)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.max_value = float(m.target)
		bar.value = float(m.progress)
		bar.custom_minimum_size = Vector2(0, 20)
		bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 10, 0))
		bar.add_theme_stylebox_override("fill", _style(GREEN, 10, 0))
		v.add_child(bar)
		var pl := _label("%d / %d" % [int(m.progress), int(m.target)], 22, Color("cfe9ff"), 4)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(pl)
		var done := int(m.progress) >= int(m.target)
		var b := _button(("DONE" if m.claimed else "+%s" % fmt(int(m.reward))), GREEN if done and not m.claimed else Color("6b6f86"), "", Vector2(150, 84), 28)
		b.disabled = m.claimed or not done
		var idx := i
		b.pressed.connect(func(): task_claim.emit(idx))
		h.add_child(b)
		tasks_box.add_child(row)
	var bonus_btn := _button("ALL DONE  +%s" % fmt(bonus) if not bonus_done else "BONUS CLAIMED", ORANGE if bonus_ready else Color("6b6f86"), "chest", Vector2(520, 90), 30)
	bonus_btn.disabled = not bonus_ready
	bonus_btn.pressed.connect(func(): task_bonus.emit())
	tasks_box.add_child(_center(bonus_btn))
	if not tasks_panel.visible:
		_pop(tasks_panel)


# ---------------------------------------------------------------- upgrades

func _build_upgrades() -> void:
	var box := _panel_box(660.0)
	upgrades_panel = box.get_meta("holder")
	root.add_child(upgrades_panel)
	_modals.append(upgrades_panel)
	box.add_child(_label("POWER-UPS", 64, GOLD, 12))
	box.add_child(_label("Upgrades last forever", 26, Color("cfe9ff"), 4))
	upgrades_box = VBoxContainer.new()
	upgrades_box.add_theme_constant_override("separation", 12)
	box.add_child(upgrades_box)
	var close := _button("CLOSE", BLUE, "close", Vector2(480, 96))
	close.pressed.connect(func(): upgrades_panel.visible = false)
	box.add_child(close)
	upgrades_panel.visible = false


func show_upgrades(coins: int) -> void:
	for ch in upgrades_box.get_children():
		ch.queue_free()
	for u in Upgrades.LIST:
		var id: String = u.id
		var lv := Upgrades.level(id)
		var row := PanelContainer.new()
		var sb := _style(Color(0.1, 0.08, 0.26), 24, 3)
		sb.border_color = Color(u.color, 0.7)
		sb.set_content_margin_all(12)
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var ic := IconDraw.new(u.icon, u.color)
		ic.custom_minimum_size = Vector2(64, 64)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 2)
		h.add_child(v)
		var tl := _label(String(u.name), 28, Color.WHITE, 4)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(tl)
		var pips := HBoxContainer.new()
		pips.add_theme_constant_override("separation", 6)
		for k in Upgrades.MAX:
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(40, 14)
			pip.add_theme_stylebox_override("panel", _style(u.color if k < lv else Color(1, 1, 1, 0.15), 7, 0))
			pips.add_child(pip)
		v.add_child(pips)
		var txt := Upgrades.describe(id, lv)
		if lv < Upgrades.MAX:
			txt += "\nNext: " + Upgrades.describe(id, lv + 1)
		var dl := _label(txt, 20, Color("cfe9ff"), 3)
		dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(dl)
		var c := Upgrades.cost(id)
		var can := c > 0 and coins >= c
		var b := _button("MAX" if c < 0 else fmt(c), GREEN if can else Color("6b6f86"), "" if c < 0 else "coin", Vector2(170, 84), 26)
		b.disabled = not can
		b.pressed.connect(func(): upgrade_buy.emit(id))
		h.add_child(b)
		upgrades_box.add_child(row)
	if not upgrades_panel.visible:
		_pop(upgrades_panel)


# ---------------------------------------------------------------- chests

func _build_chests() -> void:
	var box := _panel_box(620.0)
	chest_panel = box.get_meta("holder")
	root.add_child(chest_panel)
	_modals.append(chest_panel)
	box.add_child(_label("CHESTS", 66, GOLD, 12))
	var free_ic := IconDraw.new("chest", Color("cfd6e6"))
	free_ic.custom_minimum_size = Vector2(130, 110)
	box.add_child(_center(free_ic))
	chest_free_btn = _button("OPEN", GREEN, "", Vector2(460, 96))
	chest_free_btn.pressed.connect(func(): chest_open.emit("free"))
	box.add_child(_center(chest_free_btn))
	box.add_child(_label("Free chest every 4 hours", 24, Color("cfe9ff"), 4))
	var star_ic := IconDraw.new("chest", GOLD)
	star_ic.custom_minimum_size = Vector2(150, 126)
	box.add_child(_center(star_ic))
	chest_star_bar = ProgressBar.new()
	chest_star_bar.show_percentage = false
	chest_star_bar.max_value = float(Save.STARS_PER_CHEST)
	chest_star_bar.custom_minimum_size = Vector2(0, 22)
	chest_star_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 11, 0))
	chest_star_bar.add_theme_stylebox_override("fill", _style(GOLD, 11, 0))
	box.add_child(chest_star_bar)
	chest_star_btn = _button("STAR CHEST", ORANGE, "star", Vector2(460, 96))
	chest_star_btn.pressed.connect(func(): chest_open.emit("star"))
	box.add_child(_center(chest_star_btn))
	chest_mystery_btn = _button("MYSTERY BOX  %s" % fmt(Save.MYSTERY_PRICE), PURPLE, "dice", Vector2(500, 96), 32)
	chest_mystery_btn.pressed.connect(func(): mystery_open.emit())
	box.add_child(_center(chest_mystery_btn))
	box.add_child(_label("A guaranteed NEW item - could be a rare one!", 22, Color("cfe9ff"), 4))
	var close := _link_button("Close")
	close.pressed.connect(func(): chest_panel.visible = false)
	box.add_child(_center(close))
	chest_panel.visible = false

	var rbox := _panel_box(560.0)
	reveal_panel = rbox.get_meta("holder")
	root.add_child(reveal_panel)
	_modals.append(reveal_panel)
	rbox.add_child(_label("YOU GOT", 56, Color("cfe9ff"), 10))
	reveal_icon = IconDraw.new("coin")
	reveal_icon.custom_minimum_size = Vector2(170, 170)
	rbox.add_child(_center(reveal_icon))
	reveal_text = _label("", 52, GOLD, 12)
	reveal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rbox.add_child(reveal_text)
	var ok := _button("AWESOME!", GREEN, "check", Vector2(440, 100))
	ok.pressed.connect(func(): reveal_panel.visible = false)
	rbox.add_child(_center(ok))
	reveal_panel.visible = false


func show_chests(free_left: int, star_progress: int, star_ready: bool) -> void:
	chest_free_btn.disabled = free_left > 0
	if free_left > 0:
		chest_free_btn.text = "%d:%02d:%02d" % [free_left / 3600, (free_left / 60) % 60, free_left % 60]
	else:
		chest_free_btn.text = "OPEN"
	chest_star_bar.value = clampi(star_progress, 0, Save.STARS_PER_CHEST)
	chest_star_btn.disabled = not star_ready
	var pool_left := Save.mystery_pool().size()
	chest_mystery_btn.disabled = pool_left == 0 or Save.coins < Save.MYSTERY_PRICE
	_set_btn_text(chest_mystery_btn, "MYSTERY BOX  %s" % fmt(Save.MYSTERY_PRICE) if pool_left > 0 else "COLLECTION COMPLETE")
	_set_btn_text(chest_star_btn, "OPEN STAR CHEST" if star_ready else "STARS %d / %d" % [clampi(star_progress, 0, Save.STARS_PER_CHEST), Save.STARS_PER_CHEST])
	if not chest_panel.visible:
		_pop(chest_panel)


func show_reveal(reward: Dictionary) -> void:
	chest_panel.visible = false
	if reward.has("coins"):
		reveal_icon.set_kind("coin")
		reveal_text.text = "+%s COINS" % fmt(int(reward.coins))
	else:
		var cat: String = reward.cat
		var it := Custom.item(cat, int(reward.index))
		var ic := _tile_icon(cat, it)
		reveal_icon.color2 = ic.color2
		reveal_icon.set_kind(ic.kind, ic.color)
		ic.free()
		reveal_text.text = "NEW %s:\n%s" % [Custom.CAT_NAMES[cat], String(it.name)]
	_pop(reveal_panel)
	reveal_icon.pivot_offset = reveal_icon.custom_minimum_size * 0.5
	reveal_icon.rotation = -0.4
	reveal_icon.create_tween().tween_property(reveal_icon, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- race

func _build_race() -> void:
	var box := _panel_box(640.0)
	race_panel = box.get_meta("holder")
	root.add_child(race_panel)
	_modals.append(race_panel)
	box.add_child(_label("RACE", 76, GOLD, 14))
	var ai := _button("VS 3 RIVALS", Color("ff5a4e"), "trophy", Vector2(540, 110))
	ai.pressed.connect(func(): race_ai.emit())
	box.add_child(_center(ai))
	box.add_child(_label("Beat AI captains · win up to 600 coins", 24, Color("cfe9ff"), 4))
	var sep := _label("WI-FI RACE · SAME NETWORK", 30, Color("8fe3ff"), 6)
	box.add_child(sep)
	sep.visible = not OS.has_feature("web")   # browsers can't host LAN games
	race_lan_box = VBoxContainer.new()
	race_lan_box.add_theme_constant_override("separation", 12)
	box.add_child(race_lan_box)
	var host := _button("CREATE ROOM", BLUE, "wifi", Vector2(540, 96), 34)
	host.pressed.connect(func(): race_host.emit())
	race_lan_box.add_child(_center(host))
	var jr := HBoxContainer.new()
	jr.alignment = BoxContainer.ALIGNMENT_CENTER
	jr.add_theme_constant_override("separation", 10)
	race_lan_box.add_child(jr)
	race_code_edit = LineEdit.new()
	race_code_edit.placeholder_text = "code e.g. 1.37"
	race_code_edit.max_length = 7
	race_code_edit.custom_minimum_size = Vector2(300, 90)
	race_code_edit.add_theme_font_size_override("font_size", 34)
	race_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	race_code_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER_DECIMAL
	var es := _style(Color("f7f2e6"), 24, 6)
	race_code_edit.add_theme_stylebox_override("normal", es)
	race_code_edit.add_theme_stylebox_override("focus", es)
	race_code_edit.add_theme_color_override("font_color", Toon.INK)
	race_code_edit.add_theme_color_override("font_placeholder_color", Color(0.3, 0.3, 0.45))
	jr.add_child(race_code_edit)
	var join := _button("JOIN", GREEN, "", Vector2(200, 90), 34)
	join.pressed.connect(func(): race_join.emit(race_code_edit.text))
	jr.add_child(join)
	race_code_label = _label("", 40, GOLD, 8)
	race_lan_box.add_child(race_code_label)
	race_players = VBoxContainer.new()
	race_lan_box.add_child(race_players)
	race_start_btn = _button("START RACE", GREEN, "play", Vector2(480, 100))
	race_start_btn.pressed.connect(func(): race_start.emit())
	race_lan_box.add_child(_center(race_start_btn))
	race_status = _label("", 26, Color("ffb3a8"), 4)
	race_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(race_status)
	var close := _link_button("Close")
	close.pressed.connect(func(): race_leave.emit())
	box.add_child(_center(close))
	race_panel.visible = false

	race_hud = VBoxContainer.new()
	race_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(race_hud, Control.PRESET_TOP_RIGHT, -250, top + 90, -20, top + 400)
	race_hud.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	race_place = _label("1st", 72, GOLD, 14)
	race_place.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	race_hud.add_child(race_place)
	race_list = VBoxContainer.new()
	race_list.add_theme_constant_override("separation", 2)
	race_hud.add_child(race_list)
	race_hud.visible = false
	hud.add_child(race_hud)


func show_race_lobby(lan_supported: bool, in_room: bool, is_host: bool, code: String, names: Array, status: String) -> void:
	race_lan_box.visible = not OS.has_feature("web")
	race_code_edit.get_parent().visible = lan_supported and not in_room
	race_code_label.visible = in_room
	race_code_label.text = ("ROOM CODE:  %s" % code) if is_host else ("IN ROOM %s" % code)
	for ch in race_players.get_children():
		ch.queue_free()
	for n in names:
		var l := _label("• " + String(n), 30, Color.WHITE, 4)
		race_players.add_child(l)
	race_start_btn.visible = in_room and is_host
	race_start_btn.disabled = names.size() < 2
	_set_btn_text(race_start_btn, "START RACE" if names.size() >= 2 else "WAITING FOR PLAYERS...")
	var host_btn: Control = race_lan_box.get_child(0)
	host_btn.visible = lan_supported and not in_room
	race_status.text = status if lan_supported else "Wi-Fi race works in the Android app."
	if not race_panel.visible:
		_pop(race_panel)


func set_race_hud(on: bool, place: int, total: int, rows: Array) -> void:
	race_hud.visible = on
	if not on:
		return
	race_place.text = "%s/%d" % [ordinal(place), total]
	var kids := race_list.get_children()
	while kids.size() < rows.size():
		var l := _label("", 24, Color.WHITE, 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		race_list.add_child(l)
		kids = race_list.get_children()
	for i in kids.size():
		var l: Label = kids[i]
		l.visible = i < rows.size()
		if i < rows.size():
			var r: Array = rows[i]
			l.text = "%d. %s" % [i + 1, String(r[0])]
			l.label_settings.font_color = GOLD if bool(r[1]) else Color.WHITE


static func ordinal(n: int) -> String:
	match n:
		1: return "1st"
		2: return "2nd"
		3: return "3rd"
	return "%dth" % n


func _build_results() -> void:
	var box := _panel_box(620.0)
	results_panel = box.get_meta("holder")
	root.add_child(results_panel)
	_modals.append(results_panel)
	results_title = _label("1st PLACE!", 80, GOLD, 14)
	box.add_child(results_title)
	results_list = VBoxContainer.new()
	results_list.add_theme_constant_override("separation", 8)
	box.add_child(results_list)
	var cr := _coin_row(56)
	box.add_child(cr[0])
	results_reward = cr[1]
	results_double = _button("x2 COINS", GREEN, "ad", Vector2(500, 106))
	results_double.pressed.connect(func(): race_double.emit())
	box.add_child(_center(results_double))
	var done := _button("CONTINUE", BLUE, "play", Vector2(500, 100))
	done.pressed.connect(func(): race_done.emit())
	box.add_child(_center(done))
	results_panel.visible = false


func show_results(place: int, rows: Array, reward: int) -> void:
	_only(results_panel)
	results_title.text = "%s PLACE!" % ordinal(place)
	results_title.label_settings.font_color = GOLD if place == 1 else (Color("cfe9ff") if place == 2 else Color("ffb38a"))
	for ch in results_list.get_children():
		ch.queue_free()
	for i in rows.size():
		var r: Array = rows[i]
		var row := PanelContainer.new()
		var col := Color(0.25, 0.2, 0.05) if bool(r[1]) else Color(0.15, 0.13, 0.32)
		var sb := _style(col, 20, 4)
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		row.add_child(h)
		var a := _label("%s  %s" % [ordinal(i + 1), String(r[0])], 30, GOLD if bool(r[1]) else Color.WHITE, 4)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(_label(String(r[2]), 28, Color("cfe9ff"), 4))
		results_list.add_child(row)
	results_reward.text = fmt(reward)
	results_double.visible = reward > 0
	results_double.disabled = false
	_pop(results_panel)


func results_doubled(total: int) -> void:
	results_reward.text = fmt(total)
	results_double.disabled = true
	results_reward.pivot_offset = results_reward.size * 0.5
	results_reward.scale = Vector2(1.6, 1.6)
	results_reward.create_tween().tween_property(results_reward, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)


func set_rank(rank: int, into: int, need: int, title: String) -> void:
	rank_label.text = "RANK %d · %s   %d/%d XP" % [rank, title, into, need]
	rank_bar.value = float(into) / maxf(float(need), 1.0)


func _build_rankup() -> void:
	var box := _panel_box(600.0)
	rankup_panel = box.get_meta("holder")
	root.add_child(rankup_panel)
	_modals.append(rankup_panel)
	box.add_child(_label("RANK UP!", 86, GOLD, 16))
	rankup_title = _label("RANK 2 · DECKHAND", 40, Color.WHITE, 10)
	box.add_child(rankup_title)
	rankup_rows = VBoxContainer.new()
	rankup_rows.add_theme_constant_override("separation", 10)
	box.add_child(rankup_rows)
	rankup_next = _label("", 26, Color("cfe9ff"), 4)
	rankup_next.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(rankup_next)
	var ok := _button("COLLECT", GREEN, "check", Vector2(460, 104))
	ok.pressed.connect(func():
		rankup_panel.visible = false
		rank_closed.emit())
	box.add_child(_center(ok))
	rankup_panel.visible = false


## rows: [[icon_kind, color, text], ...]
func show_rank_up(rank: int, title: String, rows: Array, next_text: String) -> void:
	rankup_title.text = "RANK %d · %s" % [rank, title]
	for ch in rankup_rows.get_children():
		ch.queue_free()
	for r in rows:
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 12)
		var ic := IconDraw.new(String(r[0]), r[1])
		if r.size() > 3:
			ic.color2 = r[3]
		ic.custom_minimum_size = Vector2(60, 60)
		h.add_child(ic)
		h.add_child(_label(String(r[2]), 38, GOLD, 8))
		rankup_rows.add_child(h)
	rankup_next.text = next_text
	_pop(rankup_panel)


func modal_open() -> bool:
	for m in _modals:
		if m.visible:
			return true
	return settings_panel.visible or daily_panel.visible


## Updates name, badges and timers on the menu's side buttons.
func refresh_menu_buttons(pname: String, tasks_ready: int, chest_left: int, star_ready: bool) -> void:
	_set_btn_text(profile_btn, pname)
	set_badge(power_btn, "!" if Upgrades.any_affordable() else "")
	set_badge(tasks_btn, str(tasks_ready) if tasks_ready > 0 else "")
	if chest_left <= 0 or star_ready:
		set_badge(chest_btn, "!")
		set_side_text(chest_btn, "OPEN!")
	else:
		set_badge(chest_btn, "")
		set_side_text(chest_btn, "%d:%02d" % [chest_left / 3600, (chest_left / 60) % 60])


func _build_shop() -> void:
	shop = _full(Control.new())
	root.add_child(shop)
	var back := _round_button("left", Color(0.08, 0.07, 0.2, 0.7), 92.0)
	_place(back, Control.PRESET_TOP_LEFT, 24, top, 116, top + 92)
	back.pressed.connect(func(): shop_back.emit())
	shop.add_child(back)
	var title := _label("WORKSHOP", 70, Color("fff3d6"), 14)
	_place(title, Control.PRESET_TOP_WIDE, 0, top + 92, 0, top + 172)
	shop.add_child(title)
	shop_title = _label("", 26, Color("cfe9ff"), 6)
	_place(shop_title, Control.PRESET_TOP_WIDE, 0, top + 166, 0, top + 196)
	shop.add_child(shop_title)
	shop_free_btn = _button("+500 COINS", PURPLE, "ad", Vector2(340, 84), 30)
	_place(shop_free_btn, Control.PRESET_CENTER_TOP, -170, top + 204, 170, top + 288)
	shop_free_btn.pressed.connect(func(): free_pressed.emit())
	shop.add_child(shop_free_btn)

	var sheet := PanelContainer.new()
	var sb := _style(Color(0.08, 0.07, 0.2, 0.9), 40, 0)
	sb.set_content_margin_all(22)
	sb.border_width_top = 4
	sb.border_width_left = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Toon.INK
	sheet.add_theme_stylebox_override("panel", sb)
	_place(sheet, Control.PRESET_BOTTOM_WIDE, 14, -BOTTOM_SAFE - 560, -14, -BOTTOM_SAFE + 20)
	shop.add_child(sheet)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	sheet.add_child(box)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 5)
	box.add_child(tabs)
	for cat in Custom.CATS:
		var t := _button(Custom.CAT_NAMES[cat], BLUE, "", Vector2(86, 62), 19)
		_tab_style(t, BLUE)
		var c: String = cat
		t.pressed.connect(func(): shop_tab.emit(c))
		tabs.add_child(t)
		shop_tabs[cat] = t
	shop_side_row = HBoxContainer.new()
	shop_side_row.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_side_row.add_theme_constant_override("separation", 10)
	box.add_child(shop_side_row)
	for pair in [["wall_l", "LEFT WALL"], ["wall_r", "RIGHT WALL"]]:
		var b := _button(pair[1], BLUE, "", Vector2(240, 58), 24)
		var slot: String = pair[0]
		b.pressed.connect(func(): shop_side.emit(slot))
		shop_side_row.add_child(b)
		shop_side_btns[slot] = b
	shop_side_row.visible = false
	shop_name = _label("DINGHY", 46, Color.WHITE, 10)
	box.add_child(shop_name)
	shop_status = _label("", 28, GOLD, 6)
	box.add_child(shop_status)
	shop_scroll = ScrollContainer.new()
	shop_scroll.custom_minimum_size = Vector2(0, 176)
	shop_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(shop_scroll)
	shop_tiles = HBoxContainer.new()
	shop_tiles.add_theme_constant_override("separation", 12)
	shop_scroll.add_child(shop_tiles)
	shop_action_btn = _button("EQUIP", GREEN, "", Vector2(440, 100))
	shop_action_btn.pressed.connect(func(): shop_action.emit())
	box.add_child(_center(shop_action_btn))


func _tab_style(t: Button, col: Color) -> void:
	for state in ["normal", "hover", "pressed"]:
		var st := _style(col if state != "pressed" else col.darkened(0.15), 20, 5)
		st.content_margin_left = 4
		st.content_margin_right = 4
		t.add_theme_stylebox_override(state, st)


func _tile_icon(cat: String, it: Dictionary) -> IconDraw:
	var ic := IconDraw.new()
	match cat:
		"hull":
			ic.set_kind("boat", Color.WHITE)
		"paint", "sail":
			ic.set_kind("swatch", it.color)
		"flag":
			ic.color2 = it.b
			ic.set_kind("flag2", it.a)
		"hat":
			ic.color2 = Color("e8433a")
			ic.set_kind("hat", Color("f7f7f2") if it.kind == "cap" else (Color("ffc531") if it.kind == "crown" else Color("ff8fd8") if it.kind == "party" else Color("f0c96b") if it.kind == "straw" else Color("2b2f5a")))
		"trail":
			ic.color2 = it.b
			ic.set_kind("wake", it.a)
		"wall":
			var wc := {"canyon": [Color("c98a5e"), Color("2f6b5a")], "harbor": [Color("b5523b"), Color("c9c3b8")],
				"pier": [Color("9a6340"), Color("6fae4f")], "village": [Color("ff9f80"), Color("d65a4a")],
				"crystal": [Color("2a2346"), Color("6be3ff")], "candy": [Color("ff8fc8"), Color("fff4fa")],
				"temple": [Color("e2c27a"), Color("ffc531")], "neon": [Color("1c1f3a"), Color("ff2fd0")]}
			var pair: Array = wc.get(String(it.style), [Color.GRAY, Color.WHITE])
			ic.color2 = pair[1]
			ic.set_kind("wall", pair[0])
	return ic


func _build_settings() -> void:
	var box := _panel_box(560.0)
	settings_panel = box.get_meta("holder")
	root.add_child(settings_panel)
	box.add_child(_label("SETTINGS", 64, Color("fff3d6"), 12))
	for s in [["sound", "SOUND"], ["music", "MUSIC"], ["vibe", "VIBRATION"]]:
		var b := _button(s[1], BLUE, s[0], Vector2(460, 100))
		b.toggle_mode = true
		var key: String = s[0]
		b.toggled.connect(func(on: bool):
			_style_toggle(b, key, on)
			toggle_changed.emit(key, on))
		box.add_child(b)
		toggles[key] = b
	season_btn = _button("SEASON: AUTO", Color("ff7a1a"), "star", Vector2(460, 100), 34)
	season_btn.pressed.connect(func(): season_pressed.emit())
	box.add_child(season_btn)
	privacy_btn = _button("PRIVACY", Color("6b6f86"), "shield", Vector2(460, 100))
	privacy_btn.pressed.connect(func(): privacy_pressed.emit())
	box.add_child(privacy_btn)
	var close := _button("DONE", GREEN, "check", Vector2(460, 100))
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
	var ic: IconDraw = b.get_meta("icon")
	ic.set_kind(key if on else key + "_off")


func _build_daily() -> void:
	var box := _panel_box(580.0)
	daily_panel = box.get_meta("holder")
	root.add_child(daily_panel)
	box.add_child(_label("DAILY GIFT", 68, GOLD, 14))
	daily_day_label = _label("DAY 1", 36, Color("cfe9ff"), 6)
	box.add_child(daily_day_label)
	var gift := IconDraw.new("coin")
	gift.custom_minimum_size = Vector2(150, 150)
	box.add_child(_center(gift))
	var tw := gift.create_tween().set_loops()
	tw.tween_property(gift, "rotation", 0.12, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gift, "rotation", -0.12, 0.5).set_trans(Tween.TRANS_SINE)
	gift.resized.connect(func(): gift.pivot_offset = gift.size * 0.5)
	daily_amount_label = _label("+100", 64, GOLD, 12)
	box.add_child(daily_amount_label)
	daily_track = HBoxContainer.new()
	daily_track.alignment = BoxContainer.ALIGNMENT_CENTER
	daily_track.add_theme_constant_override("separation", 6)
	box.add_child(daily_track)
	daily_tomorrow = _label("", 26, Color("cfe9ff"), 4)
	daily_tomorrow.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(daily_tomorrow)
	var x2 := _button("CLAIM x2", GREEN, "ad")
	x2.pressed.connect(func(): daily_claim.emit(2))
	box.add_child(x2)
	var normal := _link_button("Just claim")
	normal.pressed.connect(func(): daily_claim.emit(1))
	box.add_child(normal)
	daily_panel.visible = false


func _build_pause() -> void:
	var box := _panel_box()
	pause_panel = box.get_meta("holder")
	root.add_child(pause_panel)
	box.add_child(_label("PAUSED", 76, Color("fff3d6"), 14))
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
	var box := _panel_box(620.0)
	lose_panel = box.get_meta("holder")
	root.add_child(lose_panel)
	lose_title = _label("WRECKED!", 84, Color("ff7b6b"), 14)
	box.add_child(lose_title)
	lose_info = _label("", 32, Color("cfe9ff"), 6)
	box.add_child(lose_info)
	lose_bar = ProgressBar.new()
	lose_bar.show_percentage = false
	lose_bar.max_value = 1.0
	lose_bar.step = 0.0
	lose_bar.custom_minimum_size = Vector2(0, 24)
	lose_bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.12), 12, 0))
	lose_bar.add_theme_stylebox_override("fill", _style(Color("ff9b6b"), 12, 0))
	box.add_child(lose_bar)
	continue_btn = _button("CONTINUE", ORANGE, "ad", Vector2(520, 104))
	continue_btn.pressed.connect(func(): continue_pressed.emit())
	box.add_child(continue_btn)
	var cr := _coin_row(54)
	box.add_child(cr[0])
	lose_coins = cr[1]
	lose_mult = MultiplierBar.new()
	lose_mult.font = font
	lose_mult.changed.connect(func(m: int): _set_btn_text(lose_claim, "CLAIM x%d" % m))
	box.add_child(lose_mult)
	lose_claim = _button("CLAIM x2", GREEN, "ad", Vector2(520, 110))
	lose_claim.pressed.connect(func(): claim_pressed.emit(lose_mult.stop()))
	box.add_child(lose_claim)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 20)
	box.add_child(bottom)
	lose_share = _button("SHARE", BLUE, "share", Vector2(200, 72), 28)
	lose_share.pressed.connect(func(): share_pressed.emit())
	bottom.add_child(lose_share)
	lose_skip = _link_button("No thanks")
	lose_skip.pressed.connect(func(): retry_pressed.emit())
	bottom.add_child(lose_skip)
	lose_panel.visible = false


func _build_win() -> void:
	var box := _panel_box(620.0)
	win_panel = box.get_meta("holder")
	root.add_child(win_panel)
	win_title = _label("LEVEL 1 CLEAR!", 68, GOLD, 14)
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
	var cr := _coin_row(60)
	box.add_child(cr[0])
	win_coins = cr[1]
	win_mult = MultiplierBar.new()
	win_mult.font = font
	win_mult.changed.connect(func(m: int): _set_btn_text(win_claim, "CLAIM x%d" % m))
	box.add_child(win_mult)
	win_claim = _button("CLAIM x2", GREEN, "ad", Vector2(520, 110))
	win_claim.pressed.connect(func(): claim_pressed.emit(win_mult.stop()))
	box.add_child(win_claim)
	win_skip = _link_button("No thanks")
	win_skip.pressed.connect(func(): next_pressed.emit())
	box.add_child(win_skip)
	win_panel.visible = false


func _build_star_drop() -> void:
	star_drop = StarDrop.new(self)
	root.add_child(star_drop)
	star_drop.done.connect(func(p: int): star_drop_done.emit(p))


func show_star_drop() -> void:
	_only(hud)
	star_drop.start()


func _build_overlays() -> void:
	popup_label = _label("", 60, GOLD, 14)
	_place(popup_label, Control.PRESET_CENTER_TOP, -340, top + 410, 340, top + 500)
	popup_label.pivot_offset = Vector2(340, 45)
	popup_label.modulate.a = 0.0
	root.add_child(popup_label)

	intro_panel = PanelContainer.new()
	var sb := _style(Color(0.08, 0.07, 0.2, 0.9), 30, 0)
	sb.set_content_margin_all(22)
	intro_panel.add_theme_stylebox_override("panel", sb)
	intro_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(intro_panel, Control.PRESET_CENTER_TOP, -310, top + 270, 310, top + 400)
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
	if star_drop:
		star_drop.visible = false
	for x in [hud, menu, shop, lose_panel, win_panel, pause_panel]:
		x.visible = x == c
	for m in _modals:
		m.visible = m == c
	settings_panel.visible = false
	daily_panel.visible = false
	hud.visible = c == hud or c == lose_panel or c == win_panel or c == pause_panel or c == results_panel
	coin_pill.visible = true


func show_menu(level: int, coins: int, world_name: String, world_no: int, step: int, star_total: int) -> void:
	_only(menu)
	set_coins(coins)
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
		if LevelGen.special_for(n) == "boss":
			border = Color("ff4fd8")
			if n > level:
				col = Color(0.35, 0.05, 0.3, 0.8)
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
	var sp := LevelGen.special_for(level)
	menu_hint.text = "BOSS FIGHT!\nTAP TO ROLL" if sp == "boss" else ("VAULT HEIST!\nTAP TO ROLL" if sp == "rush" else "TAP TO ROLL\nSLIDE TO STEER")
	menu_hint.label_settings.font_color = Color("ff6be0") if sp == "boss" else (GOLD if sp == "rush" else Color.WHITE)
	logo.modulate.a = 0.0
	logo.create_tween().tween_property(logo, "modulate:a", 1.0, 0.5)


## seconds_left = 0 -> ready; >0 -> cooldown; -1 -> no ad loaded yet
func set_free_state(seconds_left: int, reward: int) -> void:
	var text := "+%s" % fmt(reward)
	var shop_text := "+%s COINS" % fmt(reward)
	var is_ready := seconds_left == 0
	if seconds_left > 0:
		text = "%d:%02d" % [seconds_left / 60, seconds_left % 60]
		shop_text = "FREE COINS IN " + text
	elif seconds_left < 0:
		text = "LOADING"
		shop_text = "AD LOADING..."
	_set_btn_text(free_btn, text)
	_set_btn_text(shop_free_btn, shop_text)
	free_btn.disabled = not is_ready
	shop_free_btn.disabled = not is_ready


func show_shop(cat: String, sel: int, coins: int, slot: String) -> void:
	if not shop.visible:
		_only(shop)
	set_coins(coins)
	shop_title.text = "COLLECTION  %d / %d" % [Save.owned_count(), Custom.total_items()]
	for c in shop_tabs:
		_tab_style(shop_tabs[c], GOLD.darkened(0.1) if c == cat else BLUE)
	shop_side_row.visible = cat == "wall"
	for sl in shop_side_btns:
		var b: Button = shop_side_btns[sl]
		var on: bool = sl == slot
		b.add_theme_stylebox_override("normal", _style(GREEN if on else Color("4a4f6e"), 22, 5))
		b.add_theme_stylebox_override("hover", _style(GREEN if on else Color("4a4f6e"), 22, 5))
	for ch in shop_tiles.get_children():
		ch.queue_free()
	var items := Custom.items(cat)
	for i in items.size():
		var it: Dictionary = items[i]
		var owned := Save.owns(cat, i)
		var equipped := Save.equipped(slot) == i
		var rarity := Custom.rarity(it)
		var rcol: Color = Custom.RARITY_COLORS[rarity]
		var tile := Button.new()
		tile.custom_minimum_size = Vector2(128, 168)
		tile.focus_mode = Control.FOCUS_NONE
		tile.mouse_filter = Control.MOUSE_FILTER_PASS
		var base := Color(0.17, 0.15, 0.36) if owned else Color(0.12, 0.1, 0.25)
		var st := _style(base, 24, 6)
		st.border_color = rcol.darkened(0.25)
		st.border_width_bottom = 12
		if i == sel:
			st.border_color = GOLD
			st.border_width_left = 7
			st.border_width_right = 7
			st.border_width_top = 7
		tile.add_theme_stylebox_override("normal", st)
		tile.add_theme_stylebox_override("hover", st)
		tile.add_theme_stylebox_override("pressed", st)
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_top = 10
		v.offset_bottom = -14
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(v)
		var ic := _tile_icon(cat, it)
		ic.custom_minimum_size = Vector2(76, 76)
		v.add_child(_center(ic))
		var sub := ""
		var sub_col := Color(1, 1, 1, 0.7)
		if equipped:
			sub = "ON"
			sub_col = GREEN.lightened(0.3)
		elif owned:
			sub = "OWNED"
		elif Custom.is_exclusive(it):
			sub = Custom.unlock_text(it).replace("7-DAY STREAK", "DAY 7")
			sub_col = rcol.lightened(0.2)
		else:
			sub = fmt(int(it.price))
			sub_col = GOLD
		var l := _label(sub, 22, sub_col, 6)
		v.add_child(l)
		if not owned:
			var lock := IconDraw.new("lock", Color(1, 1, 1, 0.55))
			lock.position = Vector2(92, 8)
			lock.size = Vector2(26, 26)
			tile.add_child(lock)
		var idx := i
		tile.pressed.connect(func(): shop_pick.emit(idx))
		_juice(tile)
		shop_tiles.add_child(tile)
	var cur: Dictionary = items[sel]
	var rar := Custom.rarity(cur)
	shop_name.text = String(cur.name)
	shop_status.text = rar.to_upper()
	shop_status.label_settings.font_color = Custom.RARITY_COLORS[rar].lightened(0.15)
	var owned_sel := Save.owns(cat, sel)
	shop_action_btn.disabled = false
	if Save.equipped(slot) == sel:
		shop_action_btn.text = "EQUIPPED"
		shop_action_btn.disabled = true
	elif owned_sel:
		shop_action_btn.text = "EQUIP" if cat != "wall" else ("PUT LEFT" if slot == "wall_l" else "PUT RIGHT")
	elif Custom.is_exclusive(cur):
		shop_status.text = "EXCLUSIVE · " + Custom.unlock_text(cur)
		shop_action_btn.text = "REACH " + Custom.unlock_text(cur) if Custom.unlock_text(cur).begins_with("RANK") else "LOG IN 7 DAYS"
		shop_action_btn.disabled = true
	else:
		shop_status.text = "%s · %s COINS" % [rar.to_upper(), fmt(int(cur.price))]
		shop_action_btn.text = "BUY  %s" % fmt(int(cur.price))
		shop_action_btn.disabled = coins < int(cur.price)
	shop_name.pivot_offset = shop_name.size * 0.5
	shop_name.scale = Vector2(0.85, 0.85)
	shop_name.create_tween().tween_property(shop_name, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	shop_scroll.set_deferred("scroll_horizontal", maxi(0, sel * 140 - 220))


func show_settings(sound: bool, music: bool, vibe: bool, privacy_needed: bool) -> void:
	for pair in [["sound", sound], ["music", music], ["vibe", vibe]]:
		var b: Button = toggles[pair[0]]
		b.set_pressed_no_signal(pair[1])
		_style_toggle(b, pair[0], pair[1])
	privacy_btn.visible = privacy_needed
	set_season_text()
	_pop(settings_panel)


func set_season_text() -> void:
	_set_btn_text(season_btn, "SEASON: " + String(Season.NAMES.get(Save.season, "AUTO")))


func show_daily(day: int, amount: int) -> void:
	daily_day_label.text = "DAY %d OF 7" % day
	daily_amount_label.text = "+%s" % fmt(amount)
	for ch in daily_track.get_children():
		ch.queue_free()
	var ex := Custom.streak_unlock()
	for d in range(1, 8):
		var cell := PanelContainer.new()
		var col := GREEN if d < day else (GOLD.darkened(0.1) if d == day else Color(0.15, 0.13, 0.32))
		var sb := _style(col, 16, 4)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		cell.add_theme_stylebox_override("panel", sb)
		cell.custom_minimum_size = Vector2(70, 86)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_child(v)
		v.add_child(_label("D%d" % d, 20, Color.WHITE, 4))
		var ic := IconDraw.new("chest" if d == 7 else "coin", Color("ff4d1f") if d == 7 else GOLD)
		ic.custom_minimum_size = Vector2(36, 36)
		v.add_child(_center(ic))
		daily_track.add_child(cell)
	if day < 7:
		var tomorrow := (day + 1) * Save.DAILY_STEP
		daily_tomorrow.text = "Come back tomorrow: +%s" % fmt(tomorrow)
		if day + 1 == 7 and not ex.is_empty():
			daily_tomorrow.text += "\nand the exclusive %s %s!" % [String(Custom.item(ex[0], ex[1]).name), Custom.CAT_NAMES[ex[0]]]
		elif not ex.is_empty():
			daily_tomorrow.text += "\nDay 7: exclusive %s %s" % [String(Custom.item(ex[0], ex[1]).name), Custom.CAT_NAMES[ex[0]]]
	else:
		daily_tomorrow.text = "Max streak! Keep it going every day."
	_pop(daily_panel)


func hide_daily() -> void:
	daily_panel.visible = false


func show_hud(level: int) -> void:
	_only(hud)
	level_label.text = "LEVEL %d" % level
	progress.visible = true
	progress_boat.visible = true
	best_label.visible = false
	set_progress(0.0)


func show_endless_hud(best: int) -> void:
	_only(hud)
	progress.visible = false
	progress_boat.visible = false
	best_label.visible = true
	best_label.text = "BEST %s" % fmt(best)
	set_score(0)


func set_score(score: int) -> void:
	level_label.text = fmt(score)


func show_pause() -> void:
	_only(pause_panel)
	_pop(pause_panel)


func show_lose(can_continue: bool, progress_done: float, run_coins: int) -> void:
	_only(lose_panel)
	lose_title.text = "WRECKED!"
	lose_title.label_settings.font_color = Color("ff7b6b")
	lose_info.text = "You made it %d%% of the way" % int(progress_done * 100.0)
	lose_bar.visible = true
	lose_share.visible = false
	lose_bar.value = progress_done
	continue_btn.visible = can_continue
	lose_coins.text = fmt(run_coins)
	var has_coins := run_coins > 0
	lose_mult.visible = has_coins
	lose_claim.visible = has_coins
	lose_claim.disabled = false
	lose_mult.restart()
	_set_btn_text(lose_claim, "CLAIM x%d" % lose_mult.current())
	_set_btn_text(lose_skip, "No thanks" if has_coins else "Try again")
	_delay_skip(lose_skip, has_coins)
	_pop(lose_panel)


func show_lose_endless(score: int, best: int, new_best: bool, can_continue: bool, run_coins: int) -> void:
	show_lose(can_continue, 0.0, run_coins)
	lose_bar.visible = false
	lose_share.visible = Ads.can_share()
	lose_title.text = "NEW BEST!" if new_best else "SCORE %s" % fmt(score)
	lose_title.label_settings.font_color = GOLD if new_best else Color("ff7b6b")
	lose_info.text = ("%s  ·  previous best %s" % [fmt(score), fmt(best)]) if new_best else ("BEST  %s" % fmt(best))
	if new_best:
		lose_title.pivot_offset = lose_title.size * 0.5
		lose_title.scale = Vector2(1.6, 1.6)
		lose_title.create_tween().tween_property(lose_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_endless_best(best: int) -> void:
	endless_best.text = "BEST %s" % fmt(best) if best > 0 else "NEW MODE!"


func show_win(level: int, stars: int, run_coins: int, special := "normal") -> void:
	_only(win_panel)
	win_title.text = "LEVEL %d CLEAR!" % level
	if special == "boss":
		win_title.text = "BOSS DEFEATED!"
	elif special == "rush":
		win_title.text = "HEIST COMPLETE!"
	win_coins.text = "0"
	var has_coins := run_coins > 0
	win_mult.visible = has_coins
	win_claim.visible = has_coins
	win_claim.disabled = false
	win_mult.restart()
	_set_btn_text(win_claim, "CLAIM x%d" % win_mult.current())
	_set_btn_text(win_skip, "No thanks" if has_coins else "Next level")
	_delay_skip(win_skip, has_coins)
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
	tw.tween_method(func(v: float): win_coins.text = fmt(int(v)), 0.0, float(run_coins), 0.6)


## "No thanks" appears a moment later, so the player sees the offer first.
func _delay_skip(b: Button, delayed: bool) -> void:
	if not delayed:
		b.modulate.a = 1.0
		b.disabled = false
		return
	b.modulate.a = 0.0
	b.disabled = true
	var tw := b.create_tween()
	tw.tween_interval(1.4)
	tw.tween_callback(func(): b.disabled = false)
	tw.tween_property(b, "modulate:a", 1.0, 0.3)


## After the ad: show the multiplied amount and lock the claim button.
func show_claimed(total: int, on_win: bool) -> void:
	var l := win_coins if on_win else lose_coins
	var claim := win_claim if on_win else lose_claim
	var skip := win_skip if on_win else lose_skip
	claim.disabled = true
	l.text = fmt(total)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.7, 1.7)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK)
	_set_btn_text(skip, "Next level" if on_win else "Try again")
	skip.disabled = false
	skip.modulate.a = 1.0


func resume_spin(on_win: bool) -> void:
	var bar := win_mult if on_win else lose_mult
	var claim := win_claim if on_win else lose_claim
	bar.restart()
	claim.disabled = false


func set_progress(p: float) -> void:
	progress.value = p
	var r := progress.get_global_rect()
	progress_boat.position = Vector2(r.position.x + r.size.x * p - 22.0, r.position.y - 40.0)


func set_coins(n: int) -> void:
	coin_label.text = fmt(n)


func bump_coins() -> void:
	coin_pill.pivot_offset = coin_pill.size * 0.5
	coin_pill.scale = Vector2(1.15, 1.15)
	coin_pill.create_tween().tween_property(coin_pill, "scale", Vector2.ONE, 0.15)


## effects: kind -> seconds left (or -1 for "active, no timer").
func set_effects(effects: Dictionary) -> void:
	for k in effect_chips:
		var chip: PanelContainer = effect_chips[k][0]
		var l: Label = effect_chips[k][1]
		var v: float = effects.get(k, 0.0)
		chip.visible = v != 0.0
		l.text = "" if v < 0.0 else "%.0f" % ceilf(v)


## v = charge 0..1 (or time left while active).
func set_fever(v: float, active: bool) -> void:
	fever_bar.value = clampf(v, 0.0, 1.0)
	fever_label.text = "FEVER!" if active else "FEVER"
	if active:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		fever_fill.bg_color = Color("ff4fd8").lerp(Color("ffd166"), pulse)
		fever_label.label_settings.font_color = fever_fill.bg_color
	else:
		fever_fill.bg_color = Color("ff4fd8") if v < 0.99 else Color("ffd166")
		fever_label.label_settings.font_color = Color("ff8be6")


func combo_pop(n: int) -> void:
	fever_box.pivot_offset = fever_box.size * 0.5
	fever_box.scale = Vector2(1.12, 1.12)
	fever_box.create_tween().tween_property(fever_box, "scale", Vector2.ONE, 0.2)
	if n >= 3:
		popup("COMBO x%d" % n, Color("ff8be6"))


func fever_banner() -> void:
	popup("FEVER!!  x2 COINS", Color("ff4fd8"))
	popup_label.scale = Vector2(0.3, 0.3)
	fever_flash.color.a = 0.35
	if _fever_tw:
		_fever_tw.kill()
	_fever_tw = fever_flash.create_tween()
	_fever_tw.tween_property(fever_flash, "color:a", 0.0, 0.5)


## v < 0 hides the boss bar.
func set_boss(v: float) -> void:
	boss_box.visible = v >= 0.0
	if v >= 0.0:
		boss_bar.value = v
		boss_box.pivot_offset = boss_box.size * 0.5
		boss_box.scale = Vector2(1.08, 1.08)
		boss_box.create_tween().tween_property(boss_box, "scale", Vector2.ONE, 0.15)


func special_banner(title: String, desc: String, color: Color) -> void:
	intro(title, desc)
	intro_title.text = title
	intro_title.label_settings.font_color = color


## n < 0 hides the hearts (endless, races).
func set_lives(n: int, max_lives: int) -> void:
	lives_row.visible = n >= 0
	if n < 0:
		return
	if lives_row.get_child_count() != max_lives:
		for ch in lives_row.get_children():
			ch.queue_free()
		for k in max_lives:
			var h := IconDraw.new("heart", Color("ff3d6e"))
			h.custom_minimum_size = Vector2(38, 38)
			lives_row.add_child(h)
	for k in max_lives:
		var h: IconDraw = lives_row.get_child(k)
		var full := k < n
		if h.kind == "heart" and not full:
			h.pivot_offset = h.size * 0.5
			h.scale = Vector2(1.6, 1.6)
			h.create_tween().tween_property(h, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		h.set_kind("heart" if full else "heart_empty")


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
	intro_title.label_settings.font_color = GOLD
	intro_desc.text = desc
	intro_panel.visible = true
	intro_panel.modulate.a = 0.0
	var tw := intro_panel.create_tween()
	tw.tween_property(intro_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.6)
	tw.tween_property(intro_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): intro_panel.visible = false)


## dir: "left" / "right" (or the old "up"/"down" as bool true/false)
func hint(text: String, dir: Variant) -> void:
	if hint_box.visible and hint_label.text == text:
		return
	var kind: String = dir if dir is String else ("up" if dir else "down")
	hint_label.text = text
	hint_icon.set_kind(kind)
	hint_box.visible = true
	hint_box.modulate.a = 1.0
	if _hint_tw:
		_hint_tw.kill()
	hint_icon.offset_top = 0
	hint_icon.offset_bottom = 80
	var prop := "position:x" if kind == "left" or kind == "right" else "position:y"
	var d := -14.0 if kind == "up" or kind == "left" else 14.0
	_hint_tw = hint_icon.create_tween().set_loops(6)
	_hint_tw.tween_property(hint_icon, prop, d, 0.3).as_relative()
	_hint_tw.tween_property(hint_icon, prop, -d, 0.3).as_relative()


func hide_hint() -> void:
	hint_box.visible = false
