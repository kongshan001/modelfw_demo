class_name FoldHud
extends CanvasLayer

## Chinese HUD and the screen-space fold overlay. The overlay is deliberately
## drawn in 1280x720 design pixels so the alignment rings track the projected
## 3D points exactly.

const VIEW := Vector2(1280.0, 720.0)
const INK := Color("#26332F")
const INK_SOFT := Color("#5D6B62")
const MUTED := Color("#8A958C")
const PAPER := Color("#FBF3E3")
const PAPER_SOFT := Color("#F3E9D6")
const EDGE := Color("#D9C6A3")
const CORAL := Color("#C86B4D")
const TEAL := Color("#2F5B58")
const MINT := Color("#9FCDB6")
const AMBER := Color("#F2B45C")
const BRASS := Color("#D9B268")
const PLUM := Color("#6F596C")

var game
var root: Control
var overlay: Control
var vignette: ColorRect
var top_card: PanelContainer
var status_card: PanelContainer
var controls_panel: PanelContainer
var toast_panel: PanelContainer
var toast_label: Label
var debug_card: PanelContainer
var debug_label: Label
var win_layer: Control
var win_title: Label
var win_sub: Label
var win_stats: Label
var win_primary: Button
var win_replay: Button

var title_label: Label
var subtitle_label: Label
var objective_label: Label
var hint_label: Label
var chip_row: HBoxContainer
var chips: Array[Button] = []
var selected_label: Label
var angle_label: Label
var angle_dial: AngleDial
var btn_undo: Button
var btn_reset: Button
var btn_hint: Button
var btn_rot_l: Button
var btn_rot_r: Button

var _font: Font
var _font_bold: Font
var _font_mono: Font
var _theme: Theme
var _snap: Dictionary = {}
var _level_shown := -1
var _time := 0.0
var _toast_tween: Tween
var _debug_acc := 0.0
var _fold_pulses: Array[Dictionary] = []
var _confetti: Array[Dictionary] = []
var _hint_text := ""
var _last_debug_text := ""


class AngleDial:
	extends Control

	var angle_deg := 0.0
	var accent := Color("#C86B4D")

	func _init() -> void:
		custom_minimum_size = Vector2(60, 60)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_angle(deg: float) -> void:
		angle_deg = deg
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r + 1.0, Color(0.35, 0.32, 0.25, 0.08))
		draw_arc(c, r, 0.0, TAU, 40, Color(0.35, 0.32, 0.25, 0.25), 1.0, true)
		for i in 12:
			var a := TAU * float(i) / 12.0 - PI * 0.5
			var inner := r - (4.0 if i % 3 == 0 else 2.0)
			var col := Color(0.35, 0.32, 0.25, 0.42)
			draw_line(c + Vector2(cos(a), sin(a)) * inner, c + Vector2(cos(a), sin(a)) * r, col, 1.0)
		var a := deg_to_rad(angle_deg) - PI * 0.5
		draw_line(c, c + Vector2(cos(a), sin(a)) * (r - 5.0), accent, 2.0, true)
		draw_circle(c, 2.6, accent)


func _ready() -> void:
	layer = 5
	_font = _make_font(false)
	_font_bold = _make_font(true)
	_font_mono = _make_mono()
	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 14
	_build()


func _make_font(bold: bool) -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Noto Sans SC", "Microsoft YaHei", "Source Han Sans SC", "Arial"
	])
	if bold:
		sf.font_weight = 700
	return sf


func _make_mono() -> Font:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Menlo", "SF Mono", "Consolas", "Noto Sans Mono", "Arial"])
	return sf


func _label(text: String, size: int, color: Color = INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font_bold if bold else _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _panel_style(bg: Color = Color(PAPER, 0.94), border: Color = Color(EDGE, 0.85), radius := 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 16.0
	st.content_margin_right = 16.0
	st.content_margin_top = 13.0
	st.content_margin_bottom = 13.0
	st.shadow_color = Color(0.10, 0.14, 0.12, 0.16)
	st.shadow_size = 10
	st.shadow_offset = Vector2(0, 5)
	return st


func _dark_style(bg: Color = Color(0.10, 0.15, 0.13, 0.90), radius := 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = Color(1.0, 0.95, 0.82, 0.12)
	st.set_border_width_all(1)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 16.0
	st.content_margin_right = 16.0
	st.content_margin_top = 10.0
	st.content_margin_bottom = 10.0
	return st


func _btn_style(bg: Color, border: Color, radius := 8) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = bg
	st.border_color = border
	st.set_border_width_all(1)
	st.set_corner_radius_all(radius)
	st.content_margin_left = 10.0
	st.content_margin_right = 10.0
	st.content_margin_top = 5.0
	st.content_margin_bottom = 5.0
	return st


func _mk_button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _font_bold if primary else _font)
	b.add_theme_font_size_override("font_size", 12 if not primary else 13)
	b.add_theme_color_override("font_color", PAPER if primary else INK)
	b.add_theme_color_override("font_hover_color", PAPER if primary else INK)
	b.add_theme_color_override("font_pressed_color", PAPER if primary else INK)
	b.add_theme_stylebox_override("normal", _btn_style(TEAL if primary else Color(PAPER, 0.55), Color(TEAL, 0.55) if primary else Color(EDGE, 0.85)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(TEAL, 0.86) if primary else Color(AMBER, 0.25), Color(TEAL, 0.7) if primary else Color(BRASS, 0.8)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.16, 0.33, 0.31) if primary else Color(CORAL, 0.22), Color(TEAL, 0.8) if primary else Color(CORAL, 0.8)))
	b.add_theme_stylebox_override("disabled", _btn_style(Color(PAPER, 0.30), Color(EDGE, 0.45)))
	b.add_theme_color_override("font_disabled_color", Color(MUTED, 0.65))
	return b


func _chip_style(active: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(CORAL, 0.12) if active else Color(PAPER, 0.35)
	st.border_color = CORAL if active else Color(EDGE, 0.7)
	st.set_border_width_all(1)
	st.set_corner_radius_all(7)
	st.content_margin_left = 9.0
	st.content_margin_right = 9.0
	st.content_margin_top = 3.0
	st.content_margin_bottom = 3.0
	return st


func _build() -> void:
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _theme
	add_child(root)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vignette.material = vm
	root.add_child(vignette)

	overlay = Control.new()
	overlay.name = "ScreenOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)

	_build_top_card()
	_build_controls()
	_build_status_card()
	_build_toast()
	_build_debug_card()
	_build_win()


func _build_top_card() -> void:
	top_card = PanelContainer.new()
	top_card.name = "LevelCard"
	top_card.add_theme_stylebox_override("panel", _panel_style())
	top_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top_card.offset_left = 24
	top_card.offset_top = 20
	top_card.offset_right = 446
	top_card.offset_bottom = 226
	top_card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(top_card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	top_card.add_child(vb)

	var brand_row := HBoxContainer.new()
	brand_row.add_theme_constant_override("separation", 8)
	vb.add_child(brand_row)
	var brand := _label("折径", 20, INK, true)
	brand_row.add_child(brand)
	var brand_en := _label("FOLDPATH", 10, MUTED)
	brand_en.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(brand_en)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand_row.add_child(spacer)
	var tag := _label("等轴折纸解谜", 10, INK_SOFT)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand_row.add_child(tag)

	chip_row = HBoxContainer.new()
	chip_row.add_theme_constant_override("separation", 5)
	vb.add_child(chip_row)
	for i in 3:
		var chip := _mk_button("0%d" % (i + 1))
		chip.custom_minimum_size = Vector2(78, 25)
		chip.add_theme_font_size_override("font_size", 11)
		chip.pressed.connect(_on_chip_pressed.bind(i))
		chip_row.add_child(chip)
		chips.append(chip)

	var sep := ColorRect.new()
	sep.color = Color(EDGE, 0.7)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	title_label = _label("纸阶", 30, INK, true)
	vb.add_child(title_label)
	subtitle_label = _label("PAPER STEPS", 10, MUTED)
	vb.add_child(subtitle_label)
	objective_label = _label("", 13, INK_SOFT)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.custom_minimum_size = Vector2(378, 0)
	vb.add_child(objective_label)
	hint_label = _label("按 H 查看提示", 11, CORAL)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.custom_minimum_size = Vector2(378, 0)
	vb.add_child(hint_label)


func _build_controls() -> void:
	controls_panel = PanelContainer.new()
	controls_panel.name = "Controls"
	controls_panel.add_theme_stylebox_override("panel", _dark_style(Color(0.10, 0.15, 0.13, 0.72), 10))
	controls_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	controls_panel.offset_left = 24
	controls_panel.offset_top = -54
	controls_panel.offset_right = 848
	controls_panel.offset_bottom = -20
	controls_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(controls_panel)
	var l := _label("点击 / WASD 行走   ·   拖动 / Q E 旋转   ·   Z 撤销   ·   R 重置   ·   H 提示   ·   滚轮缩放   ·   F1 调试", 11, Color(0.94, 0.90, 0.80, 0.86))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	controls_panel.add_child(l)


func _build_status_card() -> void:
	status_card = PanelContainer.new()
	status_card.name = "StatusCard"
	status_card.add_theme_stylebox_override("panel", _panel_style())
	status_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	status_card.offset_left = -388
	status_card.offset_top = -232
	status_card.offset_right = -24
	status_card.offset_bottom = -20
	status_card.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(status_card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	status_card.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vb.add_child(header)
	var rot_tag := _label("可旋转构件", 10, MUTED)
	header.add_child(rot_tag)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	var qe_tag := _label("Q / E", 10, INK_SOFT)
	header.add_child(qe_tag)

	var angle_row := HBoxContainer.new()
	angle_row.add_theme_constant_override("separation", 12)
	vb.add_child(angle_row)
	angle_dial = AngleDial.new()
	angle_dial.accent = CORAL
	angle_row.add_child(angle_dial)
	var angle_vb := VBoxContainer.new()
	angle_vb.add_theme_constant_override("separation", 1)
	angle_vb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	angle_row.add_child(angle_vb)
	selected_label = _label("旋桥", 17, INK, true)
	angle_vb.add_child(selected_label)
	angle_label = _label("0° · 拖动或按 Q/E", 11, INK_SOFT)
	angle_vb.add_child(angle_label)

	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 6)
	vb.add_child(rot_row)
	btn_rot_l = _mk_button("− 15°")
	btn_rot_l.custom_minimum_size = Vector2(128, 28)
	btn_rot_l.pressed.connect(_on_rotate.bind(-1))
	rot_row.add_child(btn_rot_l)
	btn_rot_r = _mk_button("+ 15°")
	btn_rot_r.custom_minimum_size = Vector2(128, 28)
	btn_rot_r.pressed.connect(_on_rotate.bind(1))
	rot_row.add_child(btn_rot_r)

	var sep := ColorRect.new()
	sep.color = Color(EDGE, 0.7)
	sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 6)
	vb.add_child(action_row)
	btn_undo = _mk_button("撤销 Z")
	btn_undo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_undo.pressed.connect(_on_undo)
	action_row.add_child(btn_undo)
	btn_reset = _mk_button("重置 R")
	btn_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_reset.pressed.connect(_on_reset)
	action_row.add_child(btn_reset)
	btn_hint = _mk_button("提示 H")
	btn_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_hint.pressed.connect(_on_hint)
	action_row.add_child(btn_hint)


func _build_toast() -> void:
	toast_panel = PanelContainer.new()
	toast_panel.name = "Toast"
	toast_panel.add_theme_stylebox_override("panel", _dark_style(Color(0.10, 0.15, 0.13, 0.93), 18))
	toast_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_panel.offset_left = -280
	toast_panel.offset_right = 280
	toast_panel.offset_top = 22
	toast_panel.offset_bottom = 68
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.visible = false
	root.add_child(toast_panel)
	toast_label = _label("", 12, PAPER)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_panel.add_child(toast_label)


func _build_debug_card() -> void:
	debug_card = PanelContainer.new()
	debug_card.name = "DebugCard"
	debug_card.add_theme_stylebox_override("panel", _dark_style(Color(0.07, 0.11, 0.10, 0.92), 12))
	debug_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_card.offset_left = -418
	debug_card.offset_top = 20
	debug_card.offset_right = -24
	debug_card.offset_bottom = 262
	debug_card.mouse_filter = Control.MOUSE_FILTER_STOP
	debug_card.visible = false
	root.add_child(debug_card)
	debug_label = _label("", 10, Color(0.85, 0.93, 0.87, 0.94))
	debug_label.add_theme_font_override("font", _font_mono)
	debug_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	debug_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	debug_card.add_child(debug_label)


func _build_win() -> void:
	win_layer = Control.new()
	win_layer.name = "WinLayer"
	win_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_layer.visible = false
	root.add_child(win_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.12, 0.10, 0.42)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	win_layer.add_child(dim)
	var card := PanelContainer.new()
	card.name = "WinCard"
	var st := _panel_style(Color(0.985, 0.955, 0.89, 0.98), Color(BRASS, 0.9), 20)
	st.set_border_width_all(2)
	st.shadow_size = 22
	card.add_theme_stylebox_override("panel", st)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -268
	card.offset_top = -172
	card.offset_right = 268
	card.offset_bottom = 172
	win_layer.add_child(card)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	card.add_child(vb)
	var eyebrow := _label("FOLD COMPLETE", 11, CORAL)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(eyebrow)
	win_title = _label("折径完成", 34, INK, true)
	win_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(win_title)
	win_sub = _label("", 13, INK_SOFT)
	win_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(win_sub)
	var line := ColorRect.new()
	line.color = Color(BRASS, 0.55)
	line.custom_minimum_size = Vector2(0, 1)
	vb.add_child(line)
	win_stats = _label("", 14, INK)
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(win_stats)
	var flavor := _label("屏幕把两个深度，折成了同一条路。", 11, MUTED)
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(flavor)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)
	win_replay = _mk_button("再走一次")
	win_replay.custom_minimum_size = Vector2(150, 38)
	win_replay.pressed.connect(_on_win_replay)
	row.add_child(win_replay)
	win_primary = _mk_button("下一关 Enter", true)
	win_primary.custom_minimum_size = Vector2(190, 38)
	win_primary.pressed.connect(_on_win_next)
	row.add_child(win_primary)


func _process(delta: float) -> void:
	_time += delta
	var stale: Array[Dictionary] = []
	for p in _fold_pulses:
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) > 0.7:
			stale.append(p)
	for p in stale:
		_fold_pulses.erase(p)
	for c in _confetti:
		c["vel"] = (c["vel"] as Vector2) + Vector2(0, 300.0) * delta
		c["pos"] = (c["pos"] as Vector2) + (c["vel"] as Vector2) * delta
		c["spin"] = float(c["spin"]) + delta * float(c.get("spin_speed", 2.0))
	overlay.queue_redraw()


func _draw_overlay() -> void:
	var snap := _snap
	if overlay == null:
		return
	# Dust motes.
	for i in 18:
		var seed_x := fposmod(float(i) * 137.7 + sin(float(i) * 2.1) * 90.0, VIEW.x)
		var seed_y := fposmod(float(i) * 83.3 + cos(float(i) * 1.7) * 70.0, VIEW.y)
		var x := fposmod(seed_x + _time * (2.0 + float(i % 4)) * 3.0, VIEW.x)
		var y := fposmod(seed_y - _time * (1.0 + float(i % 3)) * 2.2, VIEW.y)
		var a := 0.10 + 0.05 * sin(_time * 1.2 + float(i))
		overlay.draw_circle(Vector2(x, y), 1.1 + float(i % 2) * 0.7, Color(1.0, 0.96, 0.84, a))

	if snap.is_empty():
		return
	var debug := bool(snap.get("debug", false))
	var win := bool(snap.get("win", false))
	var _links: Array = snap.get("links", [])
	var current := String(snap.get("current_node", ""))
	var t := _time

	# Hint focus.
	if bool(snap.get("hint_active", false)) and not win:
		for nid in snap.get("hint_nodes", []):
			var sp = snap.get("screen_nodes", {}).get(String(nid), Vector2.ZERO)
			var rr := 22.0 + 2.5 * sin(t * 4.0)
			overlay.draw_arc(sp, rr, -PI * 0.2, PI * 1.2, 26, Color(AMBER, 0.85), 2.0, true)
			overlay.draw_arc(sp, rr + 5.0, PI * 0.8, PI * 2.2, 26, Color(AMBER, 0.35), 1.2, true)

	# Loose endpoints that are not currently matched.
	var linked := {}
	for link in _links:
		linked[String(link["a"])] = true
		linked[String(link["b"])] = true
	for nid in snap.get("open_nodes", []):
		var key := String(nid)
		if linked.has(key):
			continue
		var sp: Vector2 = snap.get("screen_nodes", {}).get(key, Vector2.ZERO)
		var col := Color(MINT, 0.40)
		overlay.draw_circle(sp, 2.2, col)
		overlay.draw_line(sp + Vector2(-7, 0), sp + Vector2(-3, 0), col, 1.2)
		overlay.draw_line(sp + Vector2(3, 0), sp + Vector2(7, 0), col, 1.2)

	# Active fold links: pulse, diamond glyph, and (if not exact) a thread.
	for i in _links.size():
		var link: Dictionary = _links[i]
		var sa: Vector2 = link.get("sa", link.get("sb", Vector2.ZERO))
		var sb: Vector2 = link.get("sb", sa)
		var lift := 0.36 * 0.81649658 * 720.0 / maxf(0.1, float(snap.get("ortho", 7.0)))
		sa += Vector2(0, -lift)
		sb += Vector2(0, -lift)
		var mid := (sa + sb) * 0.5
		var player_here := current == String(link["a"]) or current == String(link["b"])
		var base_alpha := 0.95 if player_here else 0.72
		var rr := 15.5 + sin(t * 3.2 + float(i) * 1.4) * 2.2
		overlay.draw_arc(mid, rr, 0.0, TAU, 30, Color(MINT, base_alpha), 2.2, true)
		overlay.draw_arc(mid, rr + 5.5, 0.0, TAU, 30, Color(MINT, 0.22), 1.0, true)
		if sa.distance_to(sb) > 0.8:
			overlay.draw_line(sa, sb, Color(MINT, 0.55), 1.2)
			overlay.draw_arc(sa, 7.0, 0.0, TAU, 16, Color(MINT, 0.8), 1.2, true)
			overlay.draw_arc(sb, 7.0, 0.0, TAU, 16, Color(MINT, 0.8), 1.2, true)
		# Two paper flaps folding toward each other.
		var d := 3.2
		var up := PackedVector2Array([mid + Vector2(0, -d - 2.0), mid + Vector2(-d, -d + 1.5), mid + Vector2(d, -d + 1.5)])
		var down := PackedVector2Array([mid + Vector2(0, d + 2.0), mid + Vector2(-d, d - 1.5), mid + Vector2(d, d - 1.5)])
		overlay.draw_colored_polygon(up, Color(PAPER, 0.92))
		overlay.draw_colored_polygon(down, Color(PAPER, 0.92))
		if debug:
			overlay.draw_string(_font_mono, mid + Vector2(22, -8), "%s+%s · %.1fpx" % [String(link["a"]), String(link["b"]), float(link["dist"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MINT, 0.95))

	if debug:
		_draw_debug(snap)

	# Hovered node.
	if String(snap.get("hover_node", "")) != "":
		var h_sp: Vector2 = snap.get("screen_nodes", {}).get(String(snap["hover_node"]), Vector2.ZERO)
		if snap.get("open_nodes", []).has(String(snap["hover_node"])):
			h_sp += Vector2(0, -float(snap.get("lift_px", 0.0)))
		overlay.draw_arc(h_sp, 17.5, 0.0, TAU, 24, Color(PAPER, 0.9), 1.6, true)

	# Fold pulses.
	for p in _fold_pulses:
		var k := float(p["t"]) / 0.7
		var rr := 12.0 + 34.0 * k
		overlay.draw_arc(p["pos"], rr, 0.0, TAU, 26, Color(MINT, (1.0 - k) * 0.8), 2.0, true)
		overlay.draw_arc(p["pos"], rr * 0.6, 0.0, TAU, 20, Color(PAPER, (1.0 - k) * 0.5), 1.2, true)

	# Win confetti.
	for c in _confetti:
		var p: Vector2 = c["pos"]
		var size_px := float(c["size"])
		var ang := float(c["spin"])
		var pts := PackedVector2Array([
			p + Vector2(cos(ang), sin(ang)) * size_px,
			p + Vector2(cos(ang + 2.094), sin(ang + 2.094)) * size_px,
			p + Vector2(cos(ang + 4.188), sin(ang + 4.188)) * size_px
		])
		overlay.draw_colored_polygon(pts, c["color"])


func _draw_debug(snap: Dictionary) -> void:
	var nodes: Dictionary = snap.get("screen_nodes", {})
	var link_px := float(snap.get("link_px", 18.0))
	# Path graph.
	for e in snap.get("edges", []):
		overlay.draw_line(e["sa"], e["sb"], Color(0.35, 0.78, 0.92, 0.50), 1.0, true)
	# Threshold circles on every loose end.
	for nid in snap.get("open_nodes", []):
		var sp: Vector2 = nodes.get(String(nid), Vector2.ZERO)
		overlay.draw_arc(sp, link_px, 0.0, TAU, 40, Color(0.35, 0.78, 0.92, 0.28), 1.0, true)
	# Node dots and labels.
	for nid in nodes.keys():
		var sp: Vector2 = nodes[nid]
		var kind := "path"
		if String(nid) == String(snap.get("goal_node", "")):
			kind = "goal"
		elif String(nid) == String(snap.get("current_node", "")):
			kind = "player"
		var base := Color(0.92, 0.86, 0.70)
		if String(nid) == String(snap.get("goal_node", "")):
			base = AMBER
		if String(nid) == String(snap.get("current_node", "")):
			base = CORAL
		overlay.draw_circle(sp, 3.4, base)
		overlay.draw_string(_font_mono, sp + Vector2(6, -5), "%s d%.1f" % [String(nid), float(snap.get("node_depths", {}).get(nid, 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.92, 0.96, 0.90, 0.9))
	# Platform pivots and rotation.
	for p in snap.get("platforms", []):
		var sp: Vector2 = p["screen"]
		overlay.draw_line(sp + Vector2(-5, 0), sp + Vector2(5, 0), Color(0.95, 0.82, 0.45, 0.8), 1.0)
		overlay.draw_line(sp + Vector2(0, -5), sp + Vector2(0, 5), Color(0.95, 0.82, 0.45, 0.8), 1.0)
		overlay.draw_string(_font_mono, sp + Vector2(8, 12), "%s %.0f°%s" % [String(p["id"]), float(p["angle"]), " R" if bool(p["rotatable"]) else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.95, 0.88, 0.62, 0.9))
	var ps: Vector2 = snap.get("player_screen", Vector2.ZERO)
	overlay.draw_circle(ps, 5.0, Color(1.0, 0.5, 0.35, 0.9))


# ---------------------------------------------------------------- data binding

func set_level(level: Dictionary, index: int, all_levels: Array[Dictionary]) -> void:
	_level_shown = index
	title_label.text = String(level.get("name", ""))
	subtitle_label.text = String(level.get("subtitle", "")).to_upper()
	objective_label.text = String(level.get("objective", ""))
	for i in chips.size():
		if i < all_levels.size():
			chips[i].visible = true
			chips[i].text = "0%d  %s" % [i + 1, String(all_levels[i].get("name", ""))]
			chips[i].add_theme_stylebox_override("normal", _chip_style(i == index))
			chips[i].add_theme_stylebox_override("hover", _chip_style(i == index))
			chips[i].add_theme_color_override("font_color", CORAL if i == index else INK_SOFT)
		else:
			chips[i].visible = false
	set_hint("")
	win_layer.visible = false
	_confetti.clear()
	_debug_acc = 0.0


func update_hud(delta: float) -> void:
	if game == null:
		return
	_snap = game.hud_snapshot()
	if int(_snap.get("level_index", -1)) != _level_shown:
		# Level data is normally pushed by set_level; this is a fallback.
		_level_shown = int(_snap.get("level_index", -1))
	var moving := bool(_snap.get("moving", false))
	var rotating := bool(_snap.get("rotating", false))
	var winning := bool(_snap.get("win", false))
	var sel_name := String(_snap.get("selected_name", ""))
	var sel_rot := bool(_snap.get("selected_rotatable", false))
	var angle := float(_snap.get("selected_angle", 0.0))
	selected_label.text = sel_name if sel_name != "" else "固定构件"
	angle_label.text = "%d° · %s" % [int(round(fposmod(angle, 360.0))), "拖动或按 Q/E" if sel_rot else "本关无需旋转"]
	angle_dial.accent = CORAL if sel_rot else MUTED
	angle_dial.set_angle(angle)
	var can_rot := sel_rot and not moving and not rotating and not winning
	btn_rot_l.disabled = not can_rot
	btn_rot_r.disabled = not can_rot
	btn_undo.disabled = not bool(_snap.get("can_undo", false))
	btn_reset.disabled = winning
	btn_hint.disabled = winning
	# Debug card is throttled.
	_debug_acc += delta
	if debug_card.visible and _debug_acc >= 0.12:
		_debug_acc = 0.0
		var txt := _debug_text(_snap)
		if txt != _last_debug_text:
			_last_debug_text = txt
			debug_label.text = txt


func _debug_text(s: Dictionary) -> String:
	var link_txt := ""
	for link in s.get("links", []):
		link_txt += "%s+%s %.1fpx\n" % [String(link["a"]), String(link["b"]), float(link["dist"])]
	if link_txt == "":
		link_txt = "—\n"
	var p := ""
	for plat in s.get("platforms", []):
		p += "%s %s %.0f°%s  " % [String(plat["id"]), String(plat["name"]), float(plat["angle"]), " ↻" if bool(plat["rotatable"]) else ""]
	return "FOLDPATH DEBUG · F1\n" + \
		"L%d %s   node=%s   %s\n" % [int(s.get("level_index", 0)) + 1, String(s.get("level_name", "")), String(s.get("current_node", "")), "MOVING" if bool(s.get("moving", false)) else ("WIN" if bool(s.get("win", false)) else "IDLE")] + \
		"FPS %d   DRAW %d   ORTHO %.2f   ZOOM %.2f\n" % [int(s.get("fps", 0)), int(s.get("draws", 0)), float(s.get("ortho", 0.0)), float(s.get("zoom", 1.0))] + \
		"折环 %d   阈值 %.0fpx   角度/深度差已计入\n" % [int(s.get("link_count", 0)), float(s.get("link_px", 18.0))] + \
		"活动折环:\n" + link_txt + \
		"平台: " + p + "\n" + \
		"操作 %d   移动 %d   旋转 %d   时间 %.1fs" % [int(s.get("actions", 0)), int(s.get("moves", 0)), int(s.get("rotations", 0)), float(s.get("elapsed", 0.0))]


func set_hint(text: String) -> void:
	_hint_text = text
	if hint_label != null:
		hint_label.text = text if text != "" else "按 H 查看提示"
		hint_label.add_theme_color_override("font_color", CORAL if text != "" else MUTED)


func clear_hint() -> void:
	set_hint("")


func set_debug(on: bool) -> void:
	if debug_card != null:
		debug_card.visible = on
		_last_debug_text = ""
	if on and _snap.is_empty() and game != null:
		_snap = game.hud_snapshot()


func toast(text: String, seconds := 2.4) -> void:
	if toast_panel == null or text == "":
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_label.text = text
	toast_panel.visible = true
	toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_panel, "modulate:a", 1.0, 0.14)
	_toast_tween.tween_interval(maxf(0.4, seconds))
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.28)
	_toast_tween.tween_callback(func() -> void:
		if toast_panel != null:
			toast_panel.visible = false
	)


func clear_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	if toast_panel != null:
		toast_panel.visible = false
		toast_panel.modulate.a = 0.0


func pulse_fold(pos: Vector2) -> void:
	_fold_pulses.append({"pos": pos, "t": 0.0})


func show_win(stats: Dictionary) -> void:
	win_layer.visible = true
	win_sub.text = "第 %d 程 · %s" % [int(_snap.get("level_index", 0)) + 1, String(stats.get("level", ""))]
	var secs := int(stats.get("seconds", 0.0))
	win_stats.text = "移动 %d  ·  旋转 %d  ·  用时 %02d:%02d" % [int(stats.get("moves", 0)), int(stats.get("rotations", 0)), secs / 60, secs % 60]
	win_primary.text = "回到第一关 Enter" if bool(stats.get("next_is_last", false)) else "下一关 Enter"
	_spawn_confetti()


func hide_win() -> void:
	win_layer.visible = false
	_confetti.clear()


func _spawn_confetti() -> void:
	_confetti.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(_snap.get("level_index", 0))
	var palette := [CORAL, AMBER, MINT, TEAL, Color("#E9DDC7"), PLUM]
	for i in 64:
		_confetti.append({
			"pos": Vector2(rng.randf_range(360.0, 920.0), rng.randf_range(120.0, 300.0)),
			"vel": Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-160.0, -30.0)),
			"spin": rng.randf_range(0.0, TAU),
			"spin_speed": rng.randf_range(-4.0, 4.0),
			"size": rng.randf_range(4.0, 8.0),
			"color": palette[rng.randi_range(0, palette.size() - 1)]
		})


func is_pointer_over_ui(pos: Vector2) -> bool:
	if top_card != null and top_card.visible and top_card.get_global_rect().has_point(pos):
		return true
	if status_card != null and status_card.visible and status_card.get_global_rect().has_point(pos):
		return true
	if debug_card != null and debug_card.visible and debug_card.get_global_rect().has_point(pos):
		return true
	if win_layer != null and win_layer.visible:
		return true
	return false


func _on_chip_pressed(index: int) -> void:
	if game != null:
		game.load_level(index)


func _on_rotate(dir: int) -> void:
	if game != null:
		game.rotate_selected(dir)


func _on_undo() -> void:
	if game != null:
		game.undo()


func _on_reset() -> void:
	if game != null:
		game.reset_level()


func _on_hint() -> void:
	if game != null:
		game.use_hint()


func _on_win_replay() -> void:
	if game != null:
		game.load_level(game.level_index)


func _on_win_next() -> void:
	if game != null:
		game.next_level()
