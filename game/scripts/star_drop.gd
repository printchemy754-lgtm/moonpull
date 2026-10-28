class_name StarDrop
extends Control
## Reward star after every win: tap it a few times, each tap may upgrade its
## rarity (colour + sound), then it bursts open and pays out.

signal done(prize: int)

const RARITIES := [
	{"name": "RARE", "color": Color("39ff9f"), "prize": 60},
	{"name": "SUPER RARE", "color": Color("4fa3ff"), "prize": 120},
	{"name": "EPIC", "color": Color("c56bff"), "prize": 250},
	{"name": "MYTHIC", "color": Color("ff4f6b"), "prize": 500},
	{"name": "LEGENDARY", "color": Color("ffd166"), "prize": 1000},
]
const UP_CHANCE := [0.5, 0.35, 0.22, 0.12]
const TAPS := 4

var ui: GameUI
var rarity := 0
var taps_left := TAPS
var opened := false
var star: IconDraw
var glow: IconDraw
var name_label: Label
var hint: Label
var prize_label: Label
var collect: Button
var dots: Array[Control] = []
var _t := 0.0


static func roll_rarity(seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var r := 0
	for k in TAPS:
		if r < UP_CHANCE.size() and rng.randf() < float(UP_CHANCE[r]):
			r += 1
	return r


static func prize_for(r: int) -> int:
	return int(RARITIES[clampi(r, 0, RARITIES.size() - 1)].prize)


func _init(game_ui: GameUI) -> void:
	ui = game_ui
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.1, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	col.add_child(ui._label("STAR DROP", 72, Color.WHITE, 14))
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 420)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	glow = IconDraw.new("star", Color(1, 1, 1, 0.25))
	_center(glow, holder, 400.0)
	star = IconDraw.new("star", RARITIES[0].color)
	_center(star, holder, 300.0)
	name_label = ui._label("RARE", 56, RARITIES[0].color, 12)
	col.add_child(name_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	for k in TAPS:
		var d := IconDraw.new("star", Color.WHITE)
		d.custom_minimum_size = Vector2(40, 40)
		row.add_child(d)
		dots.append(d)
	hint = ui._label("TAP THE STAR!", 40, Color("cfe9ff"), 8)
	col.add_child(hint)
	prize_label = ui._label("", 64, GameUI.GOLD, 12)
	prize_label.visible = false
	col.add_child(prize_label)
	collect = ui._button("COLLECT", GameUI.GREEN, "", Vector2(420, 110))
	collect.visible = false
	collect.pressed.connect(_collect)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(collect)
	col.add_child(cc)
	visible = false


func _center(c: Control, parent: Control, s: float) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -s * 0.5
	c.offset_right = s * 0.5
	c.offset_top = -s * 0.5
	c.offset_bottom = s * 0.5
	parent.add_child(c)


func start() -> void:
	rarity = 0
	taps_left = TAPS
	opened = false
	_paint()
	for d in dots:
		(d as IconDraw).set_kind("star", Color.WHITE)
	hint.visible = true
	prize_label.visible = false
	collect.visible = false
	star.visible = true
	visible = true
	star.pivot_offset = star.size * 0.5
	star.scale = Vector2(0.2, 0.2)
	star.create_tween().tween_property(star, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("star", 0.8)


func _paint() -> void:
	var r: Dictionary = RARITIES[rarity]
	star.set_kind("star", r.color)
	glow.set_kind("star", Color(r.color.r, r.color.g, r.color.b, 0.28))
	name_label.text = r.name
	name_label.label_settings.font_color = r.color


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	glow.pivot_offset = glow.size * 0.5
	glow.rotation = _t * 0.6
	var s := 1.0 + sin(_t * 5.0) * 0.06
	glow.scale = Vector2(s, s)
	if not opened:
		star.pivot_offset = star.size * 0.5
		star.rotation = sin(_t * 3.0) * 0.06


func _gui_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if tap and not opened:
		accept_event()
		_tap()


func _tap() -> void:
	taps_left -= 1
	(dots[TAPS - 1 - taps_left] as IconDraw).set_kind("star", Color(1, 1, 1, 0.2))
	var up := rarity < UP_CHANCE.size() and randf() < float(UP_CHANCE[rarity])
	star.pivot_offset = star.size * 0.5
	var tw := star.create_tween()
	tw.tween_property(star, "scale", Vector2(0.78, 0.78), 0.06)
	tw.tween_property(star, "scale", Vector2(1.18, 1.18) if up else Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if up:
		rarity += 1
		_paint()
		tw.tween_property(star, "scale", Vector2.ONE, 0.15)
		Sfx.play("star", 1.0 + rarity * 0.15)
		Sfx.vibrate(40)
	else:
		Sfx.play("click", 0.9)
		Sfx.vibrate(15)
	if taps_left <= 0:
		_open()


func _open() -> void:
	opened = true
	hint.visible = false
	var prize := prize_for(rarity)
	var tw := star.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(star, "scale", Vector2(1.6, 1.6), 0.2)
	tw.tween_callback(func():
		star.visible = false
		prize_label.text = "+%s COINS" % GameUI.fmt(prize)
		prize_label.visible = true
		prize_label.pivot_offset = prize_label.size * 0.5
		prize_label.scale = Vector2(0.3, 0.3)
		prize_label.create_tween().tween_property(prize_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		collect.visible = true
		Sfx.play("win", 1.1)
		Sfx.vibrate(60))


func _collect() -> void:
	visible = false
	done.emit(prize_for(rarity))
