extends CanvasLayer

# 中文参数面板：雨强/密度/风/速度/长度、积水与渗干速度、涟漪/倒影开关、
# 暂停/重置、FPS 与 draw calls。世界固定 640×360 像素，UI 保持清晰。

const PANEL_WIDTH := 372
const SUBTLE := Color(0.72, 0.86, 0.80)
const WARM := Color(0.99, 0.84, 0.52)
const ACCENT := Color(0.55, 0.90, 0.76)
const DIM := Color(0.52, 0.66, 0.62)

var main: Node

var _root: Control
var _panel: PanelContainer
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _checks: Dictionary = {}
var _pause_button: Button
var _fps_label: Label
var _scene_label: Label
var _debug_hint: Label
var _caption: Label
var _stats_panel: PanelContainer
var _accum := 0.0


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func show_caption(text: String) -> void:
	if _caption != null:
		_caption.text = text
		_caption.visible = text != ""


func set_stats_visible(value: bool) -> void:
	if _stats_panel != null:
		_stats_panel.visible = value


func sync_from_main() -> void:
	if main == null:
		return
	var p: Dictionary = main.get_params()
	_set_slider("rain", p["rain"])
	_set_slider("density", p["density"])
	_set_slider("wind", p["wind"])
	_set_slider("speed", p["speed"])
	_set_slider("length", p["length"])
	_set_slider("fill", p["fill"])
	_set_slider("drain", p["drain"])
	_set_check("ripples", p["ripples"])
	_set_check("reflection", p["reflection"])
	_set_check("debug", p["debug"])
	if _pause_button != null:
		_pause_button.text = "继续" if bool(p["paused"]) else "暂停"
	_update_debug_hint(bool(p["debug"]))
	_refresh_stats()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.20:
		return
	_accum = 0.0
	_refresh_stats()


func _refresh_stats() -> void:
	if main == null or _fps_label == null:
		return
	_fps_label.text = "FPS %d      DRAW %d" % [main.get_fps(), main.get_draw_calls()]
	if _scene_label != null:
		_scene_label.text = "雨丝 %d   涟漪 %d   水位 %d%%  %s" % [
			main.get_rain().get_active_count(),
			main.get_ripple_count(),
			int(round(float(main.get_wet()) * 100.0)),
			main.get_state_label()]


# ── 构建 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "CheckBox", SUBTLE)
	theme.set_color("font_color", "Button", Color(0.90, 0.95, 0.88))

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 18)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.075, 0.070, 0.90)
	style.border_color = Color(0.36, 0.68, 0.58, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "雨落青苔"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", WARM)
	title_row.add_child(title)
	var title_tag := Label.new()
	title_tag.text = "RAIN & PUDDLES"
	title_tag.add_theme_font_size_override("font_size", 9)
	title_tag.add_theme_color_override("font_color", DIM)
	title_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(title_tag)

	var subtitle := Label.new()
	subtitle.text = "像素黄昏 · 低洼积水 · 双环涟漪 · 统一倒影裁切"
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", SUBTLE)
	column.add_child(subtitle)

	var stats := PanelContainer.new()
	_stats_panel = stats
	var stat_style := StyleBoxFlat.new()
	stat_style.bg_color = Color(0.02, 0.045, 0.045, 0.72)
	stat_style.border_color = Color(0.22, 0.38, 0.34, 0.7)
	stat_style.set_border_width_all(1)
	stat_style.set_corner_radius_all(3)
	stat_style.content_margin_left = 8
	stat_style.content_margin_right = 8
	stat_style.content_margin_top = 4
	stat_style.content_margin_bottom = 4
	stats.add_theme_stylebox_override("panel", stat_style)
	column.add_child(stats)
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 1)
	stats.add_child(stat_box)
	_fps_label = Label.new()
	_fps_label.add_theme_font_size_override("font_size", 11)
	_fps_label.add_theme_color_override("font_color", ACCENT)
	stat_box.add_child(_fps_label)
	_scene_label = Label.new()
	_scene_label.add_theme_font_size_override("font_size", 11)
	_scene_label.add_theme_color_override("font_color", SUBTLE)
	stat_box.add_child(_scene_label)

	_add_divider(column)

	_add_slider(column, "rain", "雨强", 0.0, 1.0, 0.01, 0.85)
	_add_slider(column, "density", "雨丝密度", 60.0, 600.0, 10.0, 360.0)
	_add_slider(column, "wind", "风向", -0.6, 0.6, 0.01, 0.26)
	_add_slider(column, "speed", "雨速", 0.4, 2.0, 0.05, 1.0)
	_add_slider(column, "length", "雨丝长度", 0.5, 1.8, 0.05, 1.0)
	_add_slider(column, "fill", "积水速度", 0.25, 4.0, 0.05, 1.0)
	_add_slider(column, "drain", "渗干速度", 0.25, 12.0, 0.05, 1.0)

	_add_divider(column)

	var toggles := GridContainer.new()
	toggles.columns = 3
	toggles.add_theme_constant_override("h_separation", 2)
	column.add_child(toggles)
	_add_check(toggles, "ripples", "涟漪")
	_add_check(toggles, "reflection", "倒影")
	_add_check(toggles, "debug", "网格")

	_debug_hint = Label.new()
	_debug_hint.text = "红=大占地遮挡   绿=灯柱 1×1 放行积水"
	_debug_hint.add_theme_font_size_override("font_size", 10)
	_debug_hint.add_theme_color_override("font_color", Color(0.70, 0.95, 0.72))
	_debug_hint.visible = false
	column.add_child(_debug_hint)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	column.add_child(buttons)
	_pause_button = _make_button("暂停")
	_pause_button.pressed.connect(_on_pause_pressed)
	buttons.add_child(_pause_button)
	var reset_btn := _make_button("重置")
	reset_btn.pressed.connect(_on_reset_pressed)
	buttons.add_child(reset_btn)
	var hint := Label.new()
	hint.text = "空格暂停 · R 重置 · H 收起 · F3 网格"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buttons.add_child(hint)

	_caption = Label.new()
	_caption.visible = false
	_caption.add_theme_font_size_override("font_size", 20)
	_caption.add_theme_color_override("font_color", Color(0.99, 0.91, 0.70))
	_caption.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.035))
	_caption.add_theme_constant_override("outline_size", 5)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -58
	_caption.offset_bottom = -24
	_root.add_child(_caption)


func _add_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color(0.30, 0.50, 0.44, 0.55)
	parent.add_child(line)


func _add_slider(parent: VBoxContainer, key: String, text: String,
		min_v: float, max_v: float, step: float, initial: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = text
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.custom_minimum_size = Vector2(62, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(160, 14)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", WARM)
	value_label.custom_minimum_size = Vector2(54, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_sliders[key] = slider
	_value_labels[key] = value_label
	_update_value_label(key, initial)


func _add_check(parent: GridContainer, key: String, text: String) -> void:
	var cb := CheckBox.new()
	cb.text = text
	cb.focus_mode = Control.FOCUS_NONE
	cb.add_theme_font_size_override("font_size", 11)
	cb.toggled.connect(_on_check_toggled.bind(key))
	parent.add_child(cb)
	_checks[key] = cb


func _make_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(72, 24)
	b.add_theme_font_size_override("font_size", 12)
	return b


func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)
	_update_value_label(key, value)


func _set_check(key: String, value: bool) -> void:
	if _checks.has(key):
		_checks[key].set_pressed_no_signal(value)


func _update_value_label(key: String, value: float) -> void:
	if not _value_labels.has(key):
		return
	var label: Label = _value_labels[key]
	match key:
		"rain":
			label.text = "%d%%" % int(round(value * 100.0))
		"density":
			label.text = "%d" % int(value)
		"wind":
			label.text = "%+.2f" % value
		"speed", "length", "fill", "drain":
			label.text = "%.2f×" % value


func _update_debug_hint(value: bool) -> void:
	if _debug_hint != null:
		_debug_hint.visible = value


func _on_slider_changed(value: float, key: String) -> void:
	_update_value_label(key, value)
	if main == null:
		return
	match key:
		"rain":
			main.set_rain_intensity(value)
		"density":
			main.set_density(int(value))
		"wind":
			main.set_wind(value)
		"speed":
			main.set_rain_speed(value)
		"length":
			main.set_rain_length(value)
		"fill":
			main.set_fill_speed(value)
		"drain":
			main.set_drain_speed(value)


func _on_check_toggled(pressed: bool, key: String) -> void:
	if main == null:
		return
	match key:
		"ripples":
			main.set_ripples_enabled(pressed)
		"reflection":
			main.set_reflection_enabled(pressed)
		"debug":
			main.set_debug_grid(pressed)
			_update_debug_hint(pressed)


func _on_pause_pressed() -> void:
	if main == null:
		return
	main.set_paused(not main.is_paused())
	sync_from_main()


func _on_reset_pressed() -> void:
	if main != null:
		main.reset()
