class_name PixelVfxHud
extends Control

# Original pixel-styled HUD at native 1280x720. Panels and pixel icons are
# drawn as hard-edged rects; Chinese copy uses a SystemFont so no font file is
# bundled with the project.

const EFFECT_BUTTONS := [
	Rect2(44, 614, 204, 62),
	Rect2(260, 614, 204, 62),
	Rect2(476, 614, 204, 62),
	Rect2(692, 614, 204, 62),
]
const SPEED_BUTTONS := [
	Rect2(1004, 628, 74, 34),
	Rect2(1082, 628, 74, 34),
	Rect2(1160, 628, 74, 34),
]
const SPEEDS := [0.5, 1.0, 2.0]
const EFFECT_LABELS := ["挥剑", "火球", "冰冻", "金币"]
const EFFECT_SUBS := ["DOUBLE SLASH", "FIREBALL", "FREEZE", "COIN BURST"]
const EFFECT_KEYS := ["1", "2", "3", "4"]
const ACCENTS := [
	Color("#ff6d9e"),
	Color("#ff8a3d"),
	Color("#7fd4ff"),
	Color("#f5c84b"),
]
const PANEL := Color("#0d1320")
const PANEL_TOP := Color("#111a2b")
const BORDER := Color("#2b3c58")
const BORDER_HI := Color("#455e80")
const TEXT := Color("#dbe5f4")
const MUTED := Color("#8394ad")
const GOLD := Color("#f5c84b")

var main
var font_regular: SystemFont
var font_bold: SystemFont
var fps_override := -1
var hover := -1
var speed_hover := -1
var press: Array[float] = [0.0, 0.0, 0.0, 0.0]
var flash: Array[float] = [0.0, 0.0, 0.0, 0.0]
var score := 0
var speed := 1.0
var capture := false
var _last_score := -1
var _last_state := ""

var fps_label: Label
var score_caption: Label
var subtitle: Label
var hint: Label
var ice_label: Label
var burn_label: Label
var effect_labels: Array[Label] = []
var effect_subs: Array[Label] = []
var speed_labels: Array[Label] = []

func setup(main_ref) -> void:
	main = main_ref
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	font_regular = _make_font(false)
	font_bold = _make_font(true)

	subtitle = _label("像素特效试验场  ·  POWERED BY PIXELFX (MIT)", Vector2(52, 51), 14, MUTED)
	hint = _label("1–4 触发特效   ·   5 / 6 / 7 切换速度   ·   点击金币也可拾取   ·   R 重置",
			Vector2(44, 676), 13, Color("#7d8da6"))
	score_caption = _label("金币分数", Vector2(878, 29), 13, MUTED)
	fps_label = _label("60 FPS", Vector2(1094, 42), 21, TEXT, true)
	fps_label.size = Vector2(150, 28)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in 4:
		var b: Rect2 = EFFECT_BUTTONS[i]
		var l := _label(EFFECT_LABELS[i], b.position + Vector2(48, 11), 18, TEXT, true)
		effect_labels.append(l)
		var s := _label(EFFECT_SUBS[i], b.position + Vector2(48, 37), 10, MUTED)
		effect_subs.append(s)

	_label("速度", Vector2(930, 621), 14, MUTED, true)
	for i in 3:
		var b: Rect2 = SPEED_BUTTONS[i]
		var text := ("0.5×" if i == 0 else ("1×" if i == 1 else "2×"))
		var l := _label(text, b.position + Vector2(0, 6), 15, MUTED, true)
		l.size = Vector2(b.size.x, 20)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speed_labels.append(l)

	ice_label = _label("冰冻  0.0s", Vector2(78, 96), 15, Color("#c9f2ff"), true)
	ice_label.size = Vector2(138, 30)
	ice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ice_label.visible = false
	burn_label = _label("灼烧  0.0s", Vector2(268, 96), 15, Color("#ffd6b0"), true)
	burn_label.size = Vector2(138, 30)
	burn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	burn_label.visible = false

	queue_redraw()

func _make_font(bold: bool) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Microsoft YaHei",
		"Noto Sans CJK SC", "Arial Unicode MS", "sans-serif",
	])
	f.font_weight = 700 if bold else 400
	f.allow_system_fallback = true
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.hinting = TextServer.HINTING_LIGHT
	return f

func _label(text: String, at: Vector2, size_px: int, color: Color,
		bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = at
	l.add_theme_font_override("font", font_bold if bold else font_regular)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func update_state(score_value: int, speed_value: float, fps: int) -> void:
	score = score_value
	speed = speed_value
	if capture:
		fps_label.text = "DEMO"
	elif fps_override > 0:
		fps_label.text = "%d FPS" % fps_override
	else:
		fps_label.text = "%d FPS" % fps
	if score != _last_score:
		_last_score = score
		queue_redraw()
	var dummy: TrainingDummy = main.world.dummy
	var state := "%d:%d:%d:%d" % [
		int(dummy.frozen_remaining * 10.0),
		int(dummy.burn_remaining * 10.0),
		int(speed_value * 10.0),
		hover,
	]
	if state != _last_state:
		_last_state = state
		queue_redraw()
	if dummy.frozen_remaining > 0.0:
		ice_label.visible = true
		ice_label.text = "冰冻  %.1fs" % dummy.frozen_remaining
	else:
		ice_label.visible = false
	if dummy.burn_remaining > 0.0:
		burn_label.visible = true
		burn_label.text = "灼烧  %.1fs" % dummy.burn_remaining
	else:
		burn_label.visible = false
	var selected := 1
	if absf(speed - 0.5) < 0.01:
		selected = 0
	elif absf(speed - 2.0) < 0.01:
		selected = 2
	for i in 3:
		var active := i == selected
		speed_labels[i].add_theme_color_override("font_color", GOLD if active else MUTED)

func tick_visual(delta: float) -> void:
	for i in 4:
		press[i] = maxf(0.0, press[i] - delta)
		flash[i] = maxf(0.0, flash[i] - delta)
	queue_redraw()

func flash_effect(index: int) -> void:
	if index >= 0 and index < 4:
		flash[index] = 0.35
		press[index] = 0.12
		queue_redraw()

func set_fps_override(value: int) -> void:
	fps_override = value
	queue_redraw()

func set_capture_mode(enabled: bool) -> void:
	capture = enabled
	fps_label.text = "DEMO" if enabled else "60 FPS"
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _button_at(event.position)
		if h != hover:
			hover = h
			queue_redraw()
		var sh := _speed_at(event.position)
		if sh != speed_hover:
			speed_hover = sh
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var idx := _button_at(event.position)
		if idx >= 0 and idx < 4:
			main.trigger_effect_index(idx)
			press[idx] = 0.14
			accept_event()
			queue_redraw()
			return
		var si := _speed_at(event.position)
		if si >= 0:
			main.set_speed(SPEEDS[si])
			accept_event()
			queue_redraw()

func _button_at(p: Vector2) -> int:
	for i in 4:
		var r: Rect2 = EFFECT_BUTTONS[i]
		if r.has_point(p):
			return i
	return -1

func _speed_at(p: Vector2) -> int:
	for i in 3:
		var r: Rect2 = SPEED_BUTTONS[i]
		if r.has_point(p):
			return i
	return -1

func _draw() -> void:
	if main == null or main.world == null:
		return
	_panel(Rect2(24, 20, 1232, 64))
	_panel(Rect2(24, 596, 1232, 100))

	# title block
	draw_rect(Rect2(32, 30, 8, 34), GOLD)
	draw_rect(Rect2(32, 30, 8, 3), Color("#fff0ab"))
	PixelFont.draw_shadowed(self, "PIXEL VFX LAB", Vector2(52, 30), 3,
			Color("#eef4ff"), Color(0.02, 0.03, 0.06, 0.9), 2)
	draw_rect(Rect2(52, 66, 304, 1), Color("#2b3c58"))

	# score strip
	draw_rect(Rect2(858, 28, 212, 48), Color("#0a101b"))
	draw_rect(Rect2(858, 28, 212, 1), BORDER)
	draw_rect(Rect2(858, 75, 212, 1), Color("#060a12"))
	_icon_coin(Vector2(866, 46), 18, GOLD)
	var score_text := "%04d" % score
	PixelFont.draw_shadowed(self, score_text, Vector2(890, 48), 4,
			Color("#ffd76a"), Color(0.12, 0.07, 0.02, 0.9), 2)

	# FPS strip
	draw_rect(Rect2(1084, 28, 160, 48), Color("#0a101b"))
	draw_rect(Rect2(1084, 28, 160, 1), BORDER)
	draw_rect(Rect2(1084, 75, 160, 1), Color("#060a12"))
	draw_rect(Rect2(1092, 36, 2, 2), Color("#8be28b"))

	# status chips
	var dummy: TrainingDummy = main.world.dummy
	if dummy.frozen_remaining > 0.0:
		_draw_chip(Rect2(44, 96, 180, 30), Color("#152a3f"), Color("#3a8bd8"))
		_icon_snow(Vector2(52, 102), 18, Color("#a6ecff"))
		var ratio: float = dummy.frozen_remaining / maxf(dummy.frozen_total, 0.001)
		draw_rect(Rect2(52, 118, 164, 2), Color("#0a1724"))
		draw_rect(Rect2(52, 118, round(164 * ratio), 2), Color("#62c8f4"))
	if dummy.burn_remaining > 0.0:
		_draw_chip(Rect2(234, 96, 180, 30), Color("#301810"), Color("#a8431f"))
		_icon_fire(Vector2(242, 102), 18, Color("#ffd166"))
		var ratio: float = dummy.burn_remaining / maxf(dummy.burn_total, 0.001)
		draw_rect(Rect2(242, 118, 164, 2), Color("#1e0d08"))
		draw_rect(Rect2(242, 118, round(164 * ratio), 2), Color("#ff8a3d"))

	# buttons
	for i in 4:
		_draw_effect_button(i)
	# speed group
	draw_rect(Rect2(916, 614, 308, 62), Color("#0a101b"))
	draw_rect(Rect2(916, 614, 308, 1), BORDER)
	draw_rect(Rect2(916, 675, 308, 1), Color("#060a12"))
	draw_rect(Rect2(932, 626, 2, 34), Color("#3a4e6e"))
	for i in 3:
		_draw_speed_button(i)
	# key hint inside the bottom panel
	draw_rect(Rect2(44, 678, 4, 4), Color("#3a4e6e"))

func _draw_effect_button(i: int) -> void:
	var b: Rect2 = EFFECT_BUTTONS[i]
	var accent: Color = ACCENTS[i]
	var hot := hover == i
	var lit := press[i] > 0.0
	var base := Color("#162136") if hot else Color("#111a2b")
	if lit:
		base = Color("#233454")
	draw_rect(b, BORDER)
	draw_rect(b.grow(-2), base)
	draw_rect(Rect2(b.position.x + 2, b.position.y + 2, b.size.x - 4, 2), BORDER_HI)
	draw_rect(Rect2(b.position.x + 2, b.position.y + 2, 5, b.size.y - 4), accent)
	draw_rect(Rect2(b.position.x + 7, b.position.y + 2, 1, b.size.y - 4), Color(0, 0, 0, 0.25))
	if flash[i] > 0.0:
		draw_rect(b.grow(-2), Color(accent.r, accent.g, accent.b, 0.12 * flash[i] / 0.35))
	# key badge
	var badge := Rect2(b.position.x + b.size.x - 30, b.position.y + 9, 18, 20)
	draw_rect(badge, Color("#0a101b"))
	draw_rect(badge, BORDER)
	PixelFont.draw(self, EFFECT_KEYS[i], badge.position + Vector2(4, 3), 2, Color("#cfd8e8"))
	if i == 0:
		_icon_sword(Vector2(b.position.x + 16, b.position.y + 16), 28, accent)
	elif i == 1:
		_icon_fire(Vector2(b.position.x + 16, b.position.y + 16), 28, accent)
	elif i == 2:
		_icon_snow(Vector2(b.position.x + 16, b.position.y + 16), 28, accent)
	else:
		_icon_coin(Vector2(b.position.x + 18, b.position.y + 18), 18, accent)

func _draw_speed_button(i: int) -> void:
	var b: Rect2 = SPEED_BUTTONS[i]
	var active := absf(speed - SPEEDS[i]) < 0.01
	var hot := speed_hover == i
	draw_rect(b, GOLD if active else (BORDER_HI if hot else BORDER))
	draw_rect(b.grow(-2), Color("#1b2740") if active else Color("#0d1420"))
	if active:
		draw_rect(Rect2(b.position.x + 2, b.position.y + 2, b.size.x - 4, 2), Color("#ffd76a"))

func _draw_chip(rect: Rect2, fill: Color, border: Color) -> void:
	draw_rect(rect, border)
	draw_rect(rect.grow(-2), fill)
	draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 1), Color(1, 1, 1, 0.08))

func _panel(rect: Rect2) -> void:
	draw_rect(rect, BORDER)
	draw_rect(rect.grow(-2), PANEL)
	draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 2), PANEL_TOP)
	draw_rect(Rect2(rect.position.x + 2, rect.position.y + 2, rect.size.x - 4, 1), BORDER_HI)
	# notched pixel corners
	for corner in [
		rect.position,
		rect.position + Vector2(rect.size.x - 6, 0),
		rect.position + Vector2(0, rect.size.y - 6),
		rect.position + rect.size - Vector2(6, 6),
	]:
		draw_rect(Rect2(corner + Vector2(1, 1), Vector2(4, 4)), Color("#070b13"))

func _icon_sword(at: Vector2, s: int, c: Color) -> void:
	var k := s / 28.0
	var blade := Color("#dbe5f4")
	var dark := Color("#65788e")
	draw_line(at + Vector2(7, 21) * k, at + Vector2(20, 7) * k, dark, maxf(1.0, 3.0 * k))
	draw_line(at + Vector2(8, 20) * k, at + Vector2(21, 6) * k, blade, maxf(1.0, 2.0 * k))
	draw_rect(Rect2(at + Vector2(5, 17) * k, Vector2(8, 2) * k), GOLD)
	draw_rect(Rect2(at + Vector2(4, 21) * k, Vector2(3, 2) * k), Color("#8a6238"))
	draw_rect(Rect2(at + Vector2(19, 4) * k, Vector2(2, 2) * k), Color.WHITE)

func _icon_fire(at: Vector2, s: int, c: Color) -> void:
	var k := s / 28.0
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(14, 3) * k, at + Vector2(22, 14) * k, at + Vector2(21, 21) * k,
		at + Vector2(14, 25) * k, at + Vector2(7, 21) * k, at + Vector2(6, 14) * k,
	]), Color("#c9281f"))
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(14, 9) * k, at + Vector2(19, 16) * k, at + Vector2(18, 22) * k,
		at + Vector2(14, 24) * k, at + Vector2(10, 22) * k, at + Vector2(9, 16) * k,
	]), Color("#ff8a3d"))
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(14, 14) * k, at + Vector2(17, 19) * k, at + Vector2(14, 23) * k,
		at + Vector2(12, 20) * k,
	]), Color("#ffd166"))
	draw_rect(Rect2(at + Vector2(13, 18) * k, Vector2(2, 3) * k), Color.WHITE)

func _icon_snow(at: Vector2, s: int, c: Color) -> void:
	var k := s / 28.0
	var mid := at + Vector2(14, 14) * k
	for dir in [Vector2(1, 0), Vector2(0, 1), Vector2(0.707, 0.707), Vector2(0.707, -0.707)]:
		var d: Vector2 = dir
		draw_line(mid - d * 10.0 * k, mid + d * 10.0 * k, c, maxf(1.0, 2.0 * k))
		draw_line(mid + d * 6.0 * k, mid + d * 6.0 * k + d.orthogonal() * 3.0 * k, c, maxf(1.0, 1.0 * k))
		draw_line(mid + d * 6.0 * k, mid + d * 6.0 * k - d.orthogonal() * 3.0 * k, c, maxf(1.0, 1.0 * k))
	draw_rect(Rect2(mid - Vector2(1, 1), Vector2(2, 2)), Color.WHITE)

func _icon_coin(at: Vector2, s: int, c: Color) -> void:
	var k := s / 18.0
	var center := at + Vector2(9, 9) * k
	for y in range(-8, 9):
		var half := int(floor(sqrt(float(64 - y * y))))
		draw_rect(Rect2(center.x - half * k, center.y + y * k, half * 2 * k + 1, 1 * k),
				Color("#a86a10"))
	for y in range(-6, 7):
		var half := int(floor(sqrt(float(36 - y * y))))
		draw_rect(Rect2(center.x - half * k, center.y + y * k, half * 2 * k + 1, 1 * k),
				Color("#f5b92c"))
	draw_rect(Rect2(center + Vector2(-3, -4) * k, Vector2(3, 4) * k), Color("#ffde5e"))
	draw_rect(Rect2(center + Vector2(-1, -2) * k, Vector2(1, 2) * k), Color("#fff6c4"))
