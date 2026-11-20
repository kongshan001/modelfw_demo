class_name GardenUI
extends Control

# 左上时间面板：时间滑杆、播放/暂停、萤火/路灯/光束/云影开关。
# UI 在低分辨率世界之外，保持 1920×1080 的清晰文字。

const GOLD := Color(1.0, 0.82, 0.5)
const TEXT := Color(0.94, 0.91, 0.84)
const MUTED := Color(0.66, 0.65, 0.6)
const TOGGLE_KEYS := ["fireflies", "lamps", "beams", "clouds", "patrols"]
const TOGGLE_NAMES := {
	"fireflies": "萤火",
	"lamps": "路灯",
	"beams": "光束",
	"clouds": "云影",
	"patrols": "游人",
}

var _scene
var _font: SystemFont
var _clock: Label
var _subtitle: Label
var _slider: HSlider
var _play_button: Button
var _toggle_buttons: Dictionary = {}
var _updating := false

func setup(scene: Node3D) -> void:
	_scene = scene
	_build()
	sync(_scene.hours, _scene.autoplay)

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "Arial Unicode MS",
	])

	var panel := PanelContainer.new()
	panel.position = Vector2(26, 26)
	panel.custom_minimum_size = Vector2(344, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.012, 0.022, 0.026, 0.7)
	panel_style.border_color = Color(0.72, 0.64, 0.44, 0.55)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := _label("废墟花园", 21, TEXT)
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	_subtitle = _label("黄昏 · 实时像素渲染", 12, MUTED)
	box.add_child(_subtitle)
	box.add_child(_divider())

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 8)
	box.add_child(time_row)
	time_row.add_child(_label("时间", 13, MUTED))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(filler)
	_clock = _label("17:21", 27, GOLD)
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_row.add_child(_clock)

	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 24.0
	_slider.step = 0.01
	_slider.value = 17.35
	_slider.custom_minimum_size = Vector2(300, 20)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(_slider)
	_slider.value_changed.connect(_on_time_changed)
	box.add_child(_slider)

	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 8)
	box.add_child(play_row)
	_play_button = _button("暂停", 15)
	_play_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play_button.pressed.connect(_on_play_pressed)
	play_row.add_child(_play_button)
	play_row.add_child(_label("×600", 12, MUTED))
	box.add_child(_divider())

	box.add_child(_label("显示", 12, MUTED))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for key in TOGGLE_KEYS:
		var button := _button("", 14)
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(146, 30)
		button.set_pressed_no_signal(true)
		button.toggled.connect(_on_toggle.bind(key))
		grid.add_child(button)
		_toggle_buttons[key] = button
	box.add_child(_divider())

	var hint := _label("拖动时间，看路灯与萤火一点点亮起。", 12, MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(300, 34)
	box.add_child(hint)
	box.add_child(_label("空格 播放/暂停 · F1 隐藏 UI · 1–5 开关 · 滚轮缩放", 12, Color(0.78, 0.76, 0.7)))

func sync(hours: float, autoplay: bool) -> void:
	if _clock == null:
		return
	_clock.text = _format_time(hours)
	_subtitle.text = _phase_name(hours) + " · 实时像素渲染"
	_play_button.text = "暂停" if autoplay else "播放"
	_updating = true
	_slider.value = hours
	_updating = false
	for key in TOGGLE_KEYS:
		var button: Button = _toggle_buttons[key]
		var active: bool = _scene.features[key]
		button.set_pressed_no_signal(active)
		button.text = ("● " if active else "○ ") + TOGGLE_NAMES[key]
		button.add_theme_color_override("font_color", GOLD if active else MUTED)

func _on_time_changed(value: float) -> void:
	if _updating or _scene == null:
		return
	_scene.set_time(value)
	if _scene.autoplay:
		_scene.set_autoplay(false)

func _on_play_pressed() -> void:
	if _scene == null:
		return
	_scene.set_autoplay(not _scene.autoplay)

func _on_toggle(pressed: bool, key: String) -> void:
	if _scene == null:
		return
	if bool(_scene.features[key]) != pressed:
		_scene.toggle_feature(key)

func _format_time(hours: float) -> String:
	var total_minutes := int(floor(hours * 60.0)) % (24 * 60)
	var h := total_minutes / 60
	var m := total_minutes % 60
	return "%02d:%02d" % [h, m]

func _phase_name(hours: float) -> String:
	if hours >= 11.0 and hours < 15.0:
		return "正午"
	if hours >= 15.0 and hours < 17.2:
		return "午后"
	if hours >= 17.2 and hours < 19.0:
		return "黄昏"
	if hours >= 19.0 and hours < 21.5:
		return "蓝调"
	if hours >= 21.5 or hours < 4.9:
		return "深夜"
	if hours >= 4.9 and hours < 7.0:
		return "清晨"
	return "白天"

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _divider() -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(0.8, 0.7, 0.5, 0.16)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86))
	button.add_theme_color_override("font_pressed_color", GOLD)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.075, 0.08, 0.6)
	normal.border_color = Color(0.55, 0.5, 0.38, 0.25)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.12, 0.11, 0.08, 0.85)
	hover.border_color = Color(0.95, 0.8, 0.45, 0.5)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.22, 0.16, 0.09, 0.9)
	pressed.border_color = GOLD
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _style_slider(slider: HSlider) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.16, 0.16, 0.14, 0.8)
	bg.set_corner_radius_all(3)
	bg.content_margin_top = 3
	bg.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.66, 0.34, 0.9)
	fill.set_corner_radius_all(3)
	var fill_hover := fill.duplicate() as StyleBoxFlat
	fill_hover.bg_color = GOLD
	slider.add_theme_stylebox_override("slider", bg)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill_hover)
	var image := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			var d := Vector2(x - 5.5, y - 5.5).length()
			var a := clampf(6.0 - d, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 0.86, 0.55, a))
	var texture := ImageTexture.create_from_image(image)
	slider.add_theme_icon_override("grabber", texture)
	slider.add_theme_icon_override("grabber_highlight", texture)
