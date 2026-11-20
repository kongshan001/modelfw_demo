extends CanvasLayer

# 参数面板：波形、浪向、泡沫、透明、倒影、碎金、时间，及 5 点浮力调试开关。
# 3D 世界是 640×360 的像素画面；HUD 直接画在 1280×720 上，文字保持清晰。

const PANEL_WIDTH := 372
const SUBTLE := Color(0.72, 0.86, 0.88)
const WARM := Color(0.98, 0.84, 0.52)
const ACCENT := Color(0.50, 0.88, 0.82)

var main: Node

var _root: Control
var _panel: PanelContainer
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _debug_check: CheckBox
var _pause_check: CheckBox
var _fps_label: Label


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()


func sync_from_main() -> void:
	if main == null:
		return
	var params: Dictionary = main.get_params()
	_set_slider("height", params["height"])
	_set_slider("direction", params["direction"])
	_set_slider("foam", params["foam"])
	_set_slider("transparency", params["transparency"])
	_set_slider("reflection", params["reflection"])
	_set_slider("sparkle", params["sparkle"])
	_set_slider("time", params["time"])
	if _debug_check != null:
		_debug_check.set_pressed_no_signal(main.is_debug_points())
	if _pause_check != null:
		_pause_check.set_pressed_no_signal(main.is_paused())


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func _process(_delta: float) -> void:
	if _fps_label != null and _root != null and _root.visible:
		_fps_label.text = "FPS %d" % int(Engine.get_frames_per_second())


# ── 构建 ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 14

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(18.0, 18.0)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.09, 0.86)
	style.border_color = Color(0.32, 0.70, 0.72, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_panel.add_child(column)

	var title := Label.new()
	title.text = "PIXEL OCEAN · 像素海"
	title.add_theme_font_size_override("font_size", 21)
	title.add_theme_color_override("font_color", ACCENT)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "3 道浪 · 五点浮力 · 平面倒影 · 像素水纹"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", SUBTLE)
	column.add_child(subtitle)

	_add_divider(column)

	var presets := HBoxContainer.new()
	presets.add_theme_constant_override("separation", 6)
	column.add_child(presets)
	presets.add_child(_make_button("1 正午", _on_preset.bind(0)))
	presets.add_child(_make_button("2 晚霞", _on_preset.bind(1)))
	presets.add_child(_make_button("3 夜", _on_preset.bind(2)))

	_add_divider(column)

	_add_slider_row(column, "height", "波高", 0.0, 2.0, 0.01, 1.0)
	_add_slider_row(column, "direction", "浪向", -180.0, 180.0, 1.0, 0.0)
	_add_slider_row(column, "foam", "泡沫", 0.0, 1.6, 0.01, 0.9)
	_add_slider_row(column, "transparency", "透明", 0.0, 1.0, 0.01, 0.22)
	_add_slider_row(column, "reflection", "倒影", 0.0, 1.0, 0.01, 0.85)
	_add_slider_row(column, "sparkle", "碎金", 0.0, 1.6, 0.01, 1.05)
	_add_slider_row(column, "time", "时间", 0.0, 24.0, 0.1, 18.4)

	_add_divider(column)

	_debug_check = CheckBox.new()
	_debug_check.text = "显示 5 点浮力采样"
	_debug_check.add_theme_color_override("font_color", SUBTLE)
	_debug_check.toggled.connect(_on_debug_toggled)
	column.add_child(_debug_check)

	_pause_check = CheckBox.new()
	_pause_check.text = "暂停波浪"
	_pause_check.add_theme_color_override("font_color", SUBTLE)
	_pause_check.toggled.connect(_on_pause_toggled)
	column.add_child(_pause_check)

	_add_divider(column)

	var hint := Label.new()
	hint.text = "拖拽旋转 · 滚轮缩放 · 1/2/3 预设 · ↑↓ 波高 · ←→ 浪向\nR 倒影 · F 泡沫 · T 透明 · G 碎金 · O 五点 · H 面板 · C 复位"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.58, 0.72, 0.74))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(PANEL_WIDTH - 28.0, 0.0)
	column.add_child(hint)

	_fps_label = Label.new()
	_fps_label.text = "FPS --"
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.80, 0.92, 0.90))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.anchor_left = 0.0
	_fps_label.anchor_top = 1.0
	_fps_label.anchor_right = 0.0
	_fps_label.anchor_bottom = 1.0
	_fps_label.offset_left = 18.0
	_fps_label.offset_top = -32.0
	_fps_label.offset_right = 128.0
	_fps_label.offset_bottom = -10.0
	_root.add_child(_fps_label)


func _add_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.color = Color(0.28, 0.52, 0.54, 0.45)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", SUBTLE)
	button.add_theme_color_override("font_hover_color", WARM)
	button.pressed.connect(callback)
	return button


func _add_slider_row(parent: VBoxContainer, key: String, title: String,
		min_value: float, max_value: float, step: float, value: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size = Vector2(46.0, 0.0)
	name_label.add_theme_color_override("font_color", SUBTLE)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(170.0, 16.0)
	slider.value_changed.connect(_on_slider.bind(key))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(54.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", WARM)
	row.add_child(value_label)

	_sliders[key] = slider
	_value_labels[key] = value_label
	_update_value_label(key, value)


func _set_slider(key: String, value: float) -> void:
	if not _sliders.has(key):
		return
	var slider: HSlider = _sliders[key]
	slider.set_value_no_signal(value)
	_update_value_label(key, value)


func _update_value_label(key: String, value: float) -> void:
	if not _value_labels.has(key):
		return
	var label: Label = _value_labels[key]
	match key:
		"direction":
			label.text = "%+.0f°" % value
		"time":
			var hours := int(value)
			var minutes := int(round((value - hours) * 60.0))
			if minutes == 60:
				hours = (hours + 1) % 24
				minutes = 0
			label.text = "%02d:%02d" % [hours, minutes]
		_:
			label.text = "%.2f" % value


func _on_slider(value: float, key: String) -> void:
	_update_value_label(key, value)
	if main == null:
		return
	match key:
		"height":
			main.set_wave_height(value)
		"direction":
			main.set_wave_direction(value)
		"foam":
			main.set_foam_amount(value)
		"transparency":
			main.set_transparency(value)
		"reflection":
			main.set_reflection_strength(value)
		"sparkle":
			main.set_sparkle_amount(value)
		"time":
			main.set_time_of_day(value)


func _on_preset(index: int) -> void:
	if main != null:
		main.set_preset(index)
		sync_from_main()


func _on_debug_toggled(value: bool) -> void:
	if main != null:
		main.set_debug_points(value)


func _on_pause_toggled(value: bool) -> void:
	if main != null:
		main.set_paused(value)
