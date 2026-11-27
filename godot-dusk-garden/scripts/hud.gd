extends CanvasLayer

# 全分辨率中文 HUD：标题/时钟/时间滑杆/自动速度/时段预设/路灯/萤火/暂停/
# 内部像素分辨率/相机复位/FPS·draw call·RT·状态。文字不经过低分辨率 3D 视口。

const PANEL_BG := Color(0.035, 0.065, 0.062, 0.93)
const PANEL_BORDER := Color(0.50, 0.70, 0.56, 0.42)
const INK := Color(0.055, 0.09, 0.085)
const SUBTLE := Color(0.71, 0.78, 0.70)
const DIM := Color(0.47, 0.56, 0.51)
const GOLD := Color(0.95, 0.78, 0.47)
const WARM := Color(1.0, 0.74, 0.46)
const TEAL := Color(0.55, 0.85, 0.70)
const ROSE := Color(0.90, 0.58, 0.48)

var main

var _root: Control
var _panel: PanelContainer
var _time_label: Label
var _phase_label: Label
var _time_slider: HSlider
var _auto_btn: Button
var _speed_slider: HSlider
var _speed_value: Label
var _stats_label: Label
var _toggle_lamps: Button
var _toggle_fireflies: Button
var _toggle_pause: Button
var _res_buttons: Array[Button] = []
var _reset_btn: Button
var _syncing := false


func _ready() -> void:
	_build_ui()


func setup(main_node) -> void:
	main = main_node
	sync_from_main()
	refresh_stats()


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func is_ui_visible() -> bool:
	return _root != null and _root.visible


func refresh_stats() -> void:
	if main == null or _stats_label == null:
		return
	var p: Dictionary = main.get_params()
	_stats_label.text = "FPS %d   DRAW %d\n内部 %s ×%d   像素吸附 %s\n路灯 %d/%d   萤火 %d/%d   %s" % [
		int(p["fps"]), int(p["draw_calls"]), String(p["internal_label"]),
		int(p["display_scale"]), "开" if bool(p["pixel_snap"]) else "关",
		int(p["lit"]), int(p["lamp_count"]), int(p["firefly_visible"]), int(p["firefly_total"]),
		"暂停" if bool(p["paused"]) else "实时"]


func sync_from_main() -> void:
	if main == null or _root == null:
		return
	_syncing = true
	var p: Dictionary = main.get_params()
	_time_slider.set_value_no_signal(float(p["time"]))
	_time_label.text = "%s · %s" % [String(p["clock"]), String(p["phase"])]
	_phase_label.text = "夜色 %d%%" % int(round(float(p["night"]) * 100.0))
	_auto_btn.text = "自动时间 · %s  [T]" % ("开" if bool(p["auto"]) else "关")
	_auto_btn.add_theme_color_override("font_color", GOLD if bool(p["auto"]) else SUBTLE)
	_speed_slider.set_value_no_signal(float(p["speed"]))
	_speed_value.text = "×%.2f" % float(p["speed"])
	_toggle_lamps.text = "路灯 · %s  [F]" % ("开" if bool(p["lamps"]) else "关")
	_toggle_lamps.add_theme_color_override("font_color", WARM if bool(p["lamps"]) else DIM)
	_toggle_fireflies.text = "萤火 · %s  [G]" % ("开" if bool(p["fireflies"]) else "关")
	_toggle_fireflies.add_theme_color_override("font_color", TEAL if bool(p["fireflies"]) else DIM)
	_toggle_pause.text = "继续  [Space]" if bool(p["paused"]) else "暂停  [Space]"
	_toggle_pause.add_theme_color_override("font_color", GOLD if bool(p["paused"]) else SUBTLE)
	for i in _res_buttons.size():
		var active := int(p["internal_index"]) == i
		_res_buttons[i].add_theme_color_override("font_color", GOLD if active else SUBTLE)
	_syncing = false
	refresh_stats()


func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Source Han Sans SC", "sans-serif",
	])
	font.allow_system_fallback = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monaco", "Consolas", "Monospace"])

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "Button", SUBTLE)
	theme.set_color("font_hover_color", "Button", TEAL)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", SUBTLE)

	var btn_normal := _flat(Color(0.07, 0.12, 0.11, 0.95), Color(0.27, 0.40, 0.32, 0.8), 1, 4)
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 4
	btn_normal.content_margin_bottom = 4
	var btn_hover := _flat(Color(0.10, 0.17, 0.15, 0.98), Color(0.47, 0.68, 0.52, 0.9), 1, 4)
	btn_hover.content_margin_left = 8
	btn_hover.content_margin_right = 8
	btn_hover.content_margin_top = 4
	btn_hover.content_margin_bottom = 4
	var btn_pressed := _flat(Color(0.12, 0.20, 0.17, 0.98), Color(0.62, 0.80, 0.58, 0.9), 1, 4)
	btn_pressed.content_margin_left = 8
	btn_pressed.content_margin_right = 8
	btn_pressed.content_margin_top = 4
	btn_pressed.content_margin_bottom = 4
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", btn_pressed)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "Button", 12)

	var slider_bg := _flat(Color(0.02, 0.045, 0.04, 0.95), Color(0.22, 0.34, 0.27, 0.8), 1, 2)
	slider_bg.content_margin_top = 3
	slider_bg.content_margin_bottom = 3
	var slider_fill := _flat(Color(0.34, 0.56, 0.44, 0.95), Color(0.55, 0.78, 0.56, 0.9), 0, 2)
	slider_fill.content_margin_top = 3
	slider_fill.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.name = "ControlPanel"
	_panel.position = Vector2(14, 14)
	_panel.custom_minimum_size = Vector2(400, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _flat(PANEL_BG, PANEL_BORDER, 1, 8)
	panel_style.border_width_left = 3
	panel_style.border_color = Color(0.62, 0.52, 0.32, 0.7)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_bottom = 11
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	# 标题
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 9)
	v.add_child(title_row)
	var title := _label("暮色回廊", 25, GOLD)
	title_row.add_child(title)
	var tag := _label("DUSK CLOISTER · 3D PIXEL", 9, DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_row.add_child(tag)
	var sub := _label("原创低模废墟花园 · 黄昏渐入深夜 · 路灯与萤火次第亮起", 11, DIM)
	v.add_child(sub)
	v.add_child(_separator())

	# 时钟 + 夜色百分比
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 6)
	v.add_child(time_row)
	_time_label = _label("18:30 · 黄昏", 19, WARM)
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(_time_label)
	_phase_label = _label("夜色 0%", 11, DIM)
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_row.add_child(_phase_label)

	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 1.0
	_time_slider.step = 0.001
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.custom_minimum_size = Vector2(0, 18)
	_time_slider.value_changed.connect(_on_time_changed)
	v.add_child(_time_slider)
	var time_marks := HBoxContainer.new()
	v.add_child(time_marks)
	var m0 := _label("18:30 黄昏", 9, DIM)
	m0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_marks.add_child(m0)
	var m1 := _label("20:30 暮蓝", 9, DIM)
	m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_marks.add_child(m1)
	var m2 := _label("22:30 深夜", 9, DIM)
	m2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_marks.add_child(m2)

	# 自动 + 速度
	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 8)
	v.add_child(auto_row)
	_auto_btn = _button("自动时间 · 开  [T]", _on_auto)
	_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_row.add_child(_auto_btn)
	_speed_value = _label("×1.00", 11, TEAL)
	_speed_value.custom_minimum_size = Vector2(52, 0)
	_speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	auto_row.add_child(_speed_value)
	_speed_slider = HSlider.new()
	_speed_slider.min_value = 0.2
	_speed_slider.max_value = 4.0
	_speed_slider.step = 0.1
	_speed_slider.value = 1.0
	_speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speed_slider.custom_minimum_size = Vector2(0, 16)
	_speed_slider.value_changed.connect(_on_speed_changed)
	v.add_child(_speed_slider)

	# 时段预设
	v.add_child(_separator())
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	v.add_child(preset_row)
	var p0 := _button("黄昏  18:50  [1]", func(): _preset(0))
	var p1 := _button("暮蓝  20:40  [2]", func(): _preset(1))
	var p2 := _button("深夜  22:20  [3]", func(): _preset(2))
	for b in [p0, p1, p2]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_row.add_child(b)

	# 开关
	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 6)
	v.add_child(toggle_row)
	_toggle_lamps = _button("路灯 · 开  [F]", func(): _toggle("lamps"))
	_toggle_fireflies = _button("萤火 · 开  [G]", func(): _toggle("fireflies"))
	_toggle_pause = _button("暂停  [Space]", func(): _toggle("paused"))
	for b in [_toggle_lamps, _toggle_fireflies, _toggle_pause]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle_row.add_child(b)

	# 内部像素分辨率 + 相机复位
	v.add_child(_separator())
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 6)
	v.add_child(res_row)
	var res_label := _label("内部 RT", 11, DIM)
	res_label.custom_minimum_size = Vector2(52, 0)
	res_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	res_row.add_child(res_label)
	var res_labels := ["320×180", "480×270", "640×360"]
	for i in 3:
		var idx := i
		var b := _button(res_labels[idx], func(): _set_res(idx))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_res_buttons.append(b)
		res_row.add_child(b)
	_reset_btn = _button("相机复位  [R]", _reset_camera)
	_reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(_reset_btn)

	# 统计
	v.add_child(_separator())
	_stats_label = _label("FPS --   DRAW --\n内部 640×360 ×2   像素吸附 开\n路灯 0/6   萤火 0/160   实时", 11, Color(0.62, 0.74, 0.66))
	_stats_label.add_theme_font_override("font", mono)
	v.add_child(_stats_label)
	var hint := _label("WASD 移动 · Shift 跑 · 左键前往 · 右键拖动环绕 · 滚轮缩放\nH 隐藏界面 · 空格暂停 · 1/2/3 时段 · Q/E 旋转 · P 像素吸附 · [ ] 微调时间", 9, Color(0.44, 0.53, 0.48))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _separator() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.40, 0.52, 0.42, 0.28)
	c.custom_minimum_size = Vector2(0, 1)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _flat(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = width
	s.border_width_right = width
	s.border_width_top = width
	s.border_width_bottom = width
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s


# ── 回调 ───────────────────────────────────────────────────────────────
func _on_time_changed(value: float) -> void:
	if _syncing or main == null:
		return
	main.auto_time = false
	main.set_time_of_day(value)
	main.set_param("auto", false)


func _on_speed_changed(value: float) -> void:
	if _syncing or main == null:
		return
	main.set_param("speed", value)


func _on_auto() -> void:
	if main == null:
		return
	main.set_param("auto", not main.auto_time)


func _preset(index: int) -> void:
	if main == null:
		return
	main.apply_preset(index)


func _toggle(key: String) -> void:
	if main == null:
		return
	match key:
		"lamps":
			main.set_param("lamps", not main.lamps_enabled)
		"fireflies":
			main.set_param("fireflies", not main.fireflies_enabled)
		"paused":
			main.set_param("paused", not main.paused)


func _set_res(index: int) -> void:
	if main == null:
		return
	main.set_param("internal_index", index)


func _reset_camera() -> void:
	if main == null:
		return
	main.set_param("camera_reset", true)
