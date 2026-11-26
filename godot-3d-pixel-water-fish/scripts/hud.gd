extends CanvasLayer

# 全分辨率中文 HUD：渲染/水面/鱼群/光照/视角/调试参数。
# HUD 在 root viewport 的 CanvasLayer 上，不经过低分辨率 3D RT，因此文字始终清晰。

const PANEL_WIDTH := 338
const INK := Color(0.035, 0.075, 0.082)
const PANEL_BG := Color(0.04, 0.09, 0.1, 0.9)
const SUBTLE := Color(0.69, 0.8, 0.78)
const DIM := Color(0.44, 0.58, 0.57)
const TEAL := Color(0.47, 0.86, 0.79)
const GOLD := Color(0.95, 0.77, 0.42)
const ROSE := Color(0.94, 0.56, 0.48)

var main: Node

var _root: Control
var _panel: PanelContainer
var _stats_label: Label
var _debug_label: Label
var _sliders: Dictionary = {}
var _buttons: Dictionary = {}
var _res_buttons: Array[Button] = []
var _syncing := false


func _ready() -> void:
	_build_ui()


func setup(main_node: Node) -> void:
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
	_stats_label.text = "FPS %d   DRAW %d\nRT %s ×%d   FISH %d" % [
		int(p["fps"]), int(p["draw_calls"]), String(p["internal_label"]),
		int(p["display_scale"]), int(p["fish_count"])]
	if _debug_label != null:
		_debug_label.text = "调试 · %s   视角 · %s   时段 %.2f   天气 · %s" % [
			String(p["debug_name"]),
			"水下" if bool(p["underwater"]) else "水上",
			float(p["time"]),
			"雨" if bool(p["rain"]) else "晴"]


func sync_from_main() -> void:
	if main == null or _panel == null:
		return
	_syncing = true
	var p: Dictionary = main.get_params()
	_set_slider("levels", float(p["levels"]))
	_set_slider("dither", float(p["dither"]))
	_set_slider("outline", float(p["outline"]))
	_set_slider("clarity", float(p["clarity"]))
	_set_slider("depth_dark", float(p["depth_dark"]))
	_set_slider("refraction", float(p["refraction"]))
	_set_slider("foam", float(p["foam"]))
	_set_slider("caustics", float(p["caustics"]))
	_set_slider("flow", float(p["flow"]))
	_set_slider("fish_count", float(p["fish_count"]))
	_set_slider("time", float(p["time"]))
	for i in _res_buttons.size():
		var active := int(p["internal_index"]) == i
		_res_buttons[i].add_theme_color_override("font_color", GOLD if active else SUBTLE)
		_res_buttons[i].add_theme_color_override("font_hover_color", GOLD if active else TEAL)
	if _buttons.has("palette"):
		_buttons["palette"].text = "调色板 · %s  [P]" % ("开" if bool(p["palette"]) else "关")
		_buttons["palette"].add_theme_color_override("font_color", GOLD if bool(p["palette"]) else SUBTLE)
	if _buttons.has("snap"):
		_buttons["snap"].text = "像素吸附 · %s" % ("开" if bool(p["pixel_snap"]) else "关")
		_buttons["snap"].add_theme_color_override("font_color", GOLD if bool(p["pixel_snap"]) else SUBTLE)
	if _buttons.has("pause"):
		_buttons["pause"].text = "继续  [Space]" if bool(p["paused"]) else "暂停  [Space]"
		_buttons["pause"].add_theme_color_override("font_color", GOLD if bool(p["paused"]) else SUBTLE)
	if _buttons.has("orbit"):
		_buttons["orbit"].text = "自动环绕 · %s  [G]" % ("开" if bool(p["auto_orbit"]) else "关")
		_buttons["orbit"].add_theme_color_override("font_color", TEAL if bool(p["auto_orbit"]) else SUBTLE)
	if _buttons.has("camera"):
		_buttons["camera"].text = "视角 · %s  [V]" % ("水下" if bool(p["underwater"]) else "水上")
		_buttons["camera"].add_theme_color_override("font_color", GOLD if bool(p["underwater"]) else TEAL)
	if _buttons.has("debug"):
		_buttons["debug"].text = "调试图 · %s  [F1]" % String(p["debug_name"])
		_buttons["debug"].add_theme_color_override("font_color", GOLD if int(p["debug"]) > 0 else SUBTLE)
	if _buttons.has("weather"):
		_buttons["weather"].text = "天气 · %s  [T 切时段]" % ("雨" if bool(p["rain"]) else "晴")
	_syncing = false
	refresh_stats()


func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var s: HSlider = _sliders[key]
	s.set_value_no_signal(value)
	var label: Label = s.get_meta("value_label")
	if label != null:
		label.text = _format_value(key, value)


func _format_value(key: String, value: float) -> String:
	match key:
		"levels":
			return "%d 阶" % int(round(value))
		"fish_count":
			return "%d 条" % int(round(value))
		"clarity", "depth_dark":
			return "%d%%" % int(round(value * 100.0))
		"time":
			return "%.2f" % value
		"caustics":
			return "%.1f×" % value
		_:
			return "%.2f" % value


# ── UI 构建 ────────────────────────────────────────────────────────────
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
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "Button", SUBTLE)
	theme.set_color("font_hover_color", "Button", TEAL)
	theme.set_color("font_pressed_color", "Button", GOLD)
	theme.set_color("font_focus_color", "Button", SUBTLE)
	var btn_normal := _flat(Color(0.07, 0.13, 0.14, 0.92), Color(0.19, 0.34, 0.34, 0.8), 1)
	btn_normal.content_margin_left = 8
	btn_normal.content_margin_right = 8
	btn_normal.content_margin_top = 3
	btn_normal.content_margin_bottom = 3
	var btn_hover := _flat(Color(0.09, 0.17, 0.18, 0.95), Color(0.32, 0.55, 0.52, 0.9), 1)
	btn_hover.content_margin_left = 8
	btn_hover.content_margin_right = 8
	btn_hover.content_margin_top = 3
	btn_hover.content_margin_bottom = 3
	theme.set_stylebox("normal", "Button", btn_normal)
	theme.set_stylebox("hover", "Button", btn_hover)
	theme.set_stylebox("pressed", "Button", _flat(Color(0.1, 0.2, 0.2, 0.95), Color(0.45, 0.7, 0.65, 0.9), 1))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_font_size("font_size", "Button", 12)

	var slider_bg := _flat(Color(0.02, 0.05, 0.055, 0.9), Color(0.15, 0.26, 0.26, 0.8), 1)
	slider_bg.content_margin_top = 2
	slider_bg.content_margin_bottom = 2
	var slider_fill := _flat(Color(0.22, 0.52, 0.5, 0.95), Color(0.4, 0.8, 0.72, 0.9), 0)
	slider_fill.content_margin_top = 2
	slider_fill.content_margin_bottom = 2
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
	_panel.name = "Panel"
	_panel.position = Vector2(14, 14)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := _flat(PANEL_BG, Color(0.3, 0.65, 0.6, 0.4), 1)
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	panel_style.content_margin_left = 13
	panel_style.content_margin_right = 13
	panel_style.content_margin_top = 11
	panel_style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_panel.add_child(vbox)

	# 标题
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)
	var title := Label.new()
	title.text = "像素水塘"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", GOLD)
	title_row.add_child(title)
	var tag := Label.new()
	tag.text = "PIXEL POND · 3D"
	tag.add_theme_font_size_override("font_size", 9)
	tag.add_theme_color_override("font_color", DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tag.size_flags_vertical = Control.SIZE_EXPAND_FILL
	title_row.add_child(tag)

	var subtitle := Label.new()
	subtitle.text = "低分辨率 3D · 量化抖动 · 风格化水面"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", TEAL)
	vbox.add_child(subtitle)

	_stats_label = Label.new()
	_stats_label.add_theme_font_override("font", mono)
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", TEAL)
	_stats_label.text = "FPS --   DRAW --\nRT 640×360 ×2   FISH 18"
	vbox.add_child(_stats_label)

	vbox.add_child(_separator())
	_section(vbox, "渲染")
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 4)
	vbox.add_child(res_row)
	var res_label := _small_label("内部分辨率", 96)
	res_row.add_child(res_label)
	for i in 3:
		var b := _make_button(["320×180", "480×270", "640×360"][i], func(): main.set_param("internal_index", i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		res_row.add_child(b)
		_res_buttons.append(b)
	_add_slider(vbox, "levels", "色阶", 2.0, 16.0, 1.0)
	_add_slider(vbox, "dither", "抖动", 0.0, 1.5, 0.05)
	_add_slider(vbox, "outline", "描边", 0.0, 2.5, 0.05)
	var toggle_row := HBoxContainer.new()
	toggle_row.add_theme_constant_override("separation", 4)
	vbox.add_child(toggle_row)
	_buttons["palette"] = _make_button("调色板 · 关  [P]", func(): main.set_param("palette", not main.get_params()["palette"]))
	_buttons["snap"] = _make_button("像素吸附 · 开", func(): main.set_param("pixel_snap", not main.get_params()["pixel_snap"]))
	for b in [_buttons["palette"], _buttons["snap"]]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		toggle_row.add_child(b)

	vbox.add_child(_separator())
	_section(vbox, "水面")
	_add_slider(vbox, "clarity", "透明度", 0.0, 1.0, 0.01)
	_add_slider(vbox, "depth_dark", "深水色", 0.0, 1.0, 0.01)
	_add_slider(vbox, "refraction", "折射", 0.0, 1.5, 0.05)
	_add_slider(vbox, "foam", "泡沫", 0.0, 2.0, 0.05)
	_add_slider(vbox, "caustics", "焦散", 0.0, 2.0, 0.05)
	_add_slider(vbox, "flow", "波纹", 0.0, 1.5, 0.05)

	vbox.add_child(_separator())
	_section(vbox, "鱼群 · 光照")
	_add_slider(vbox, "fish_count", "鱼数量", 6.0, 36.0, 1.0)
	var fish_row := HBoxContainer.new()
	fish_row.add_theme_constant_override("separation", 4)
	vbox.add_child(fish_row)
	_buttons["pause"] = _make_button("暂停  [Space]", func(): main.set_param("paused", not main.get_params()["paused"]))
	_buttons["weather"] = _make_button("天气 · 晴", func(): main.set_param("rain", not main.get_params()["rain"]))
	for b in [_buttons["pause"], _buttons["weather"]]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		fish_row.add_child(b)
	_add_slider(vbox, "time", "时段", 0.0, 1.0, 0.01)
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 4)
	vbox.add_child(preset_row)
	for i in 4:
		var names := ["晨光", "正午", "黄昏", "雨夜"]
		var b := _make_button(names[i], func(): main.set_param("preset", i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		preset_row.add_child(b)

	vbox.add_child(_separator())
	_section(vbox, "视角 · 调试")
	var view_row := HBoxContainer.new()
	view_row.add_theme_constant_override("separation", 4)
	vbox.add_child(view_row)
	_buttons["camera"] = _make_button("视角 · 水上  [V]", func(): main.set_param("underwater", not main.get_params()["underwater"]))
	_buttons["orbit"] = _make_button("自动环绕 · 开  [G]", func(): main.set_param("auto_orbit", not main.get_params()["auto_orbit"]))
	for b in [_buttons["camera"], _buttons["orbit"]]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11)
		view_row.add_child(b)
	_buttons["debug"] = _make_button("调试图 · 关闭  [F1]", func(): main.cycle_debug())
	_buttons["debug"].add_theme_font_size_override("font_size", 11)
	vbox.add_child(_buttons["debug"])

	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 10)
	_debug_label.add_theme_color_override("font_color", DIM)
	_debug_label.text = "调试 · 关闭   视角 · 水上   时段 0.42   天气 · 晴"
	vbox.add_child(_debug_label)

	var hint := Label.new()
	hint.text = "拖动旋转 · 滚轮缩放 · H 隐藏 UI · R 复位视角"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(hint)


func _section(parent: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", GOLD)
	row.add_child(lbl)
	var line := ColorRect.new()
	line.color = Color(0.25, 0.45, 0.42, 0.5)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	parent.add_child(row)


func _add_slider(parent: VBoxContainer, key: String, label_text: String, minv: float, maxv: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := _small_label(label_text, 72)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = minv
	slider.max_value = maxv
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 14)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", TEAL)
	row.add_child(value_label)
	slider.set_meta("value_label", value_label)
	slider.value_changed.connect(func(v: float) -> void:
		if _syncing:
			return
		main.set_param(key, v)
		value_label.text = _format_value(key, v)
	)
	_sliders[key] = slider


func _small_label(text: String, width: float) -> Label:
	var l := Label.new()
	l.text = text
	l.custom_minimum_size = Vector2(width, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", SUBTLE)
	return l


func _make_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(cb)
	return b


func _separator() -> ColorRect:
	var sep := ColorRect.new()
	sep.color = Color(0.22, 0.4, 0.38, 0.35)
	sep.custom_minimum_size = Vector2(0, 1)
	return sep


func _flat(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = border_width
	s.border_width_top = border_width
	s.border_width_right = border_width
	s.border_width_bottom = border_width
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	return s
