extends CanvasLayer

# 中文参数面板：光方向/强度/光色、法线开关、水波速度/幅度/量化步长、
# 倒影/暖灯/调试/法线视图、暂停与重置；固定显示 FPS、draw calls、相机数量。
# UI 是原创的深墨+黄铜像素风；世界渲染 320×180，面板在 1280×720 逻辑层。

const PANEL_WIDTH := 344
const INK := Color(0.035, 0.075, 0.085)
const SUBTLE := Color(0.68, 0.80, 0.78)
const GOLD := Color(0.94, 0.76, 0.41)
const TEAL := Color(0.46, 0.84, 0.78)
const ROSE := Color(0.92, 0.52, 0.47)
const DIM := Color(0.45, 0.58, 0.57)

var main: Node

var _root: Control
var _panel: PanelContainer
var _sliders: Dictionary = {}
var _slider_values: Dictionary = {}
var _toggle_buttons: Dictionary = {}
var _slider_suffix: Dictionary = {}
var _light_button: Button
var _pause_button: Button
var _fps_label: Label
var _scene_label: Label
var _debug_label: Label
var _caption_label: Label
var _syncing := false
var _accum := 0.0


func _ready() -> void:
	_build_ui()
	set_process(true)


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()
	show_caption("静水回廊 · 单相机夜景法线实验")


func set_ui_visible(value: bool) -> void:
	if _root != null:
		_root.visible = value


func is_ui_visible() -> bool:
	return _root != null and _root.visible


func show_caption(text: String) -> void:
	if _caption_label == null:
		return
	_caption_label.text = text
	_caption_label.visible = text != ""


func sync_from_main() -> void:
	if main == null:
		return
	_syncing = true
	var p: Dictionary = main.get_params()
	_set_slider("angle", p["angle"])
	_set_slider("energy", p["energy"])
	_set_slider("wave_speed", p["wave_speed"])
	_set_slider("wave_amp", p["wave_amp"])
	_set_slider("wave_step", p["wave_step"])
	_set_slider("time_scale", p["time_scale"])
	_set_toggle("lamps", p["lamps"])
	_set_toggle("reflection", p["reflection"])
	_set_toggle("normals", p["normals"])
	_set_toggle("debug", p["debug"])
	_set_toggle("normal_view", p["normal_view"])
	if _light_button != null:
		_light_button.text = "光色 · %s  [C]" % String(p["light_name"])
	if _pause_button != null:
		_pause_button.text = "继续  [Space]" if bool(p["paused"]) else "暂停  [Space]"
		_pause_button.add_theme_color_override("font_color", GOLD if bool(p["paused"]) else SUBTLE)
	_update_debug_label(p)
	_syncing = false
	_refresh_stats()


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.22:
		return
	_accum = 0.0
	_refresh_stats()


func _refresh_stats() -> void:
	if main == null or _fps_label == null:
		return
	if not is_ui_visible():
		return
	var p: Dictionary = main.get_params()
	_fps_label.text = "FPS %d     DRAW %d     1 CAMERA" % [
		main.get_fps(), main.get_draw_calls()]
	_scene_label.text = "倒影 %d quads / 1 mesh   ·   水波 %dpx 格   ·   法线 %s" % [
		main.get_reflection_quad_count(), int(p["wave_step"]),
		"ON" if bool(p["normals"]) else "OFF"]
	_update_debug_label(p)


func _update_debug_label(p: Dictionary) -> void:
	if _debug_label == null:
		return
	if bool(p["debug"]) or bool(p["normal_view"]):
		_debug_label.visible = true
		_debug_label.text = "L %.0f°  E %.2f   ·   wave round shift %+d px @row 140\nreflection mesh: %d quads, 1 surface, mask 320×180" % [
			float(p["angle"]), float(p["energy"]),
			main.get_wave_shift_at_row(140), main.get_reflection_quad_count()]
	else:
		_debug_label.visible = false


# ── UI 构建 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monaco", "Consolas", "Monospace"])
	mono.allow_system_fallback = true

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", SUBTLE)
	theme.set_color("font_color", "Button", SUBTLE)
	theme.set_constant("separation", "HBoxContainer", 6)
	theme.set_constant("separation", "VBoxContainer", 6)

	_root = Control.new()
	_root.name = "HUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)

	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 16)
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.060, 0.070, 0.94)
	style.border_color = Color(0.40, 0.62, 0.57, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	var shell := PanelContainer.new()
	var shell_style := StyleBoxFlat.new()
	shell_style.bg_color = INK
	shell_style.border_color = Color(0.18, 0.33, 0.32, 0.9)
	shell_style.set_border_width_all(1)
	shell_style.set_corner_radius_all(0)
	shell_style.content_margin_left = 12
	shell_style.content_margin_right = 12
	shell_style.content_margin_top = 10
	shell_style.content_margin_bottom = 10
	shell.add_theme_stylebox_override("panel", shell_style)
	_panel.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	shell.add_child(column)

	var title_row := HBoxContainer.new()
	column.add_child(title_row)
	var title := Label.new()
	title.text = "静水回廊"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", GOLD)
	title_row.add_child(title)
	var title_tag := Label.new()
	title_tag.text = "STILLWATER"
	title_tag.add_theme_font_size_override("font_size", 9)
	title_tag.add_theme_color_override("font_color", DIM)
	title_tag.size_flags_vertical = Control.SIZE_SHRINK_END
	title_row.add_child(title_tag)

	_caption_label = Label.new()
	_caption_label.text = "2D 像素法线受光 · 单相机倒影 · 整格水波"
	_caption_label.add_theme_font_size_override("font_size", 10)
	_caption_label.add_theme_color_override("font_color", TEAL)
	column.add_child(_caption_label)

	var stats := PanelContainer.new()
	var stat_style := StyleBoxFlat.new()
	stat_style.bg_color = Color(0.016, 0.040, 0.047, 0.9)
	stat_style.border_color = Color(0.20, 0.35, 0.33, 0.8)
	stat_style.set_border_width_all(1)
	stat_style.content_margin_left = 7
	stat_style.content_margin_right = 7
	stat_style.content_margin_top = 4
	stat_style.content_margin_bottom = 4
	stats.add_theme_stylebox_override("panel", stat_style)
	column.add_child(stats)
	var stat_box := VBoxContainer.new()
	stat_box.add_theme_constant_override("separation", 1)
	stats.add_child(stat_box)
	_fps_label = Label.new()
	_fps_label.add_theme_font_override("font", mono)
	_fps_label.add_theme_font_size_override("font_size", 11)
	_fps_label.add_theme_color_override("font_color", TEAL)
	stat_box.add_child(_fps_label)
	_scene_label = Label.new()
	_scene_label.add_theme_font_size_override("font_size", 10)
	_scene_label.add_theme_color_override("font_color", SUBTLE)
	stat_box.add_child(_scene_label)

	_add_divider(column)
	_add_section(column, "光照 / LIGHTING")
	_add_slider_row(column, "angle", "光方向", 0.0, 360.0, 1.0, "°")
	_add_slider_row(column, "energy", "光强度", 0.0, 2.4, 0.01, "×")
	_light_button = _make_button("光色 · 冷月  [C]", GOLD)
	_light_button.pressed.connect(_on_light_preset)
	column.add_child(_light_button)
	_add_toggle_grid(column, [["normals", "法线受光"]])

	_add_divider(column)
	_add_section(column, "水面 / WATER")
	_add_slider_row(column, "wave_speed", "波速", 0.0, 2.5, 0.01, "×")
	_add_slider_row(column, "wave_amp", "波幅", 0.0, 4.0, 1.0, "px")
	_add_slider_row(column, "wave_step", "量化格", 1.0, 4.0, 1.0, "px")
	_add_toggle_grid(column, [["reflection", "倒影"], ["lamps", "暖灯"]])

	_add_divider(column)
	_add_section(column, "现场 / SCENE")
	_add_slider_row(column, "time_scale", "时流", 0.0, 2.0, 0.05, "×")
	_add_toggle_grid(column, [
		["debug", "调试叠加"],
		["normal_view", "法线视图"],
	])
	_debug_label = Label.new()
	_debug_label.add_theme_font_override("font", mono)
	_debug_label.add_theme_font_size_override("font_size", 9)
	_debug_label.add_theme_color_override("font_color", Color(0.70, 0.86, 0.76))
	_debug_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_label.custom_minimum_size = Vector2(PANEL_WIDTH - 34, 0)
	_debug_label.visible = false
	column.add_child(_debug_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	column.add_child(action_row)
	_pause_button = _make_button("暂停  [Space]", GOLD)
	_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_button.pressed.connect(_on_pause)
	action_row.add_child(_pause_button)
	var reset_button := _make_button("重置  [0]", SUBTLE)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_on_reset)
	action_row.add_child(reset_button)

	var hint := Label.new()
	hint.text = "Space 暂停 · L 灯 · R 倒影 · N 法线\nF 调试 · V 法线视图 · H 面板 · C 光色"
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(hint)


func _add_section(parent: VBoxContainer, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", TEAL)
	row.add_child(label)
	var line := ColorRect.new()
	line.color = Color(0.18, 0.32, 0.31, 0.9)
	line.custom_minimum_size = Vector2(0, 1)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)


func _add_divider(parent: VBoxContainer) -> void:
	var line := ColorRect.new()
	line.color = Color(0.12, 0.23, 0.23, 0.9)
	line.custom_minimum_size = Vector2(0, 1)
	parent.add_child(line)


func _add_slider_row(parent: VBoxContainer, key: String, label_text: String,
		min_value: float, max_value: float, step: float, suffix: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(54, 0)
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", SUBTLE)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 16)
	slider.focus_mode = Control.FOCUS_NONE
	var grabber := StyleBoxFlat.new()
	grabber.bg_color = GOLD
	grabber.content_margin_top = 4
	grabber.content_margin_bottom = 4
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = Color(0.10, 0.20, 0.20, 0.95)
	slider_bg.content_margin_top = 2
	slider_bg.content_margin_bottom = 2
	grabber.content_margin_top = 0
	grabber.content_margin_bottom = 0
	grabber.content_margin_left = 0
	grabber.content_margin_right = 0
	grabber.set_corner_radius_all(0)
	slider.add_theme_stylebox_override("slider", slider_bg)
	slider.add_theme_stylebox_override("grabber_area", grabber)
	slider.add_theme_stylebox_override("grabber_area_highlight", grabber)
	slider.value_changed.connect(_on_slider_changed.bind(key))
	row.add_child(slider)
	_sliders[key] = slider
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 10)
	value_label.add_theme_color_override("font_color", GOLD)
	row.add_child(value_label)
	_slider_values[key] = value_label
	_slider_suffix[key] = suffix


func _add_toggle_grid(parent: VBoxContainer, entries: Array) -> void:
	var grid := GridContainer.new()
	grid.columns = entries.size()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)
	for e in entries:
		var key: String = e[0]
		var text: String = e[1]
		var button := Button.new()
		button.text = text
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 23)
		button.add_theme_font_size_override("font_size", 10)
		button.add_theme_color_override("font_color", SUBTLE)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_hover_color", GOLD)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.09, 0.16, 0.17, 0.9)
		normal.border_color = Color(0.22, 0.35, 0.33, 0.9)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(0)
		var pressed := StyleBoxFlat.new()
		pressed.bg_color = Color(0.45, 0.75, 0.67, 0.9)
		pressed.border_color = GOLD
		pressed.set_border_width_all(1)
		pressed.set_corner_radius_all(0)
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.12, 0.22, 0.22, 0.95)
		hover.border_color = GOLD
		hover.set_border_width_all(1)
		hover.set_corner_radius_all(0)
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("hover", hover)
		button.toggled.connect(_on_toggle_changed.bind(key))
		grid.add_child(button)
		_toggle_buttons[key] = button


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", color)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.09, 0.16, 0.17, 0.95)
	normal.border_color = Color(0.25, 0.42, 0.38, 0.9)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.24, 0.23, 1.0)
	hover.border_color = GOLD
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


# ── 值同步 / 回调 ────────────────────────────────────────────────────────
func _set_slider(key: String, value: float) -> void:
	var slider: HSlider = _sliders.get(key)
	if slider == null:
		return
	slider.set_value_no_signal(value)
	var suffix: String = _slider_suffix.get(key, "")
	var label: Label = _slider_values.get(key)
	if label != null:
		if suffix == "°":
			label.text = "%d%s" % [int(round(value)), suffix]
		elif suffix == "px":
			label.text = "%d%s" % [int(round(value)), suffix]
		elif key == "energy":
			label.text = "%.2f%s" % [value, suffix]
		else:
			label.text = "%.2f%s" % [value, suffix]


func _set_toggle(key: String, value: bool) -> void:
	var button: Button = _toggle_buttons.get(key)
	if button == null:
		return
	button.set_pressed_no_signal(value)


func _on_slider_changed(value: float, key: String) -> void:
	if _syncing:
		return
	match key:
		"angle":
			main.set_light_angle(value)
		"energy":
			main.set_light_energy(value)
		"wave_speed":
			main.set_wave_speed(value)
		"wave_amp":
			main.set_wave_amplitude(value)
		"wave_step":
			main.set_wave_step(value)
		"time_scale":
			main.set_time_scale(value)
	sync_from_main()


func _on_toggle_changed(pressed: bool, key: String) -> void:
	if _syncing:
		return
	match key:
		"lamps":
			main.set_lamps_enabled(pressed)
		"reflection":
			main.set_reflection_enabled(pressed)
		"normals":
			main.set_normals_enabled(pressed)
		"debug":
			main.set_debug_enabled(pressed)
		"normal_view":
			main.set_normal_view(pressed)
	sync_from_main()


func _on_light_preset() -> void:
	main.cycle_light_preset()
	sync_from_main()


func _on_pause() -> void:
	main.set_paused(not main.is_paused())
	sync_from_main()


func _on_reset() -> void:
	main.reset_scene()
	sync_from_main()
