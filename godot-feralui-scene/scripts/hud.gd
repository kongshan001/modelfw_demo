extends CanvasLayer
## 极简治愈系 HUD：品牌小标题、实时 FPS、昼夜/天气/画质/暂停药丸按钮、
## 屏幕物体标记与交互提示。全部文字使用系统字体，不打包字体文件。
## 设计分辨率 1280×720，由 main 按窗口比例统一缩放。

const DESIGN := Vector2(1280.0, 720.0)
const TEXT := Color(0.93, 0.90, 0.82)
const DIM := Color(0.67, 0.66, 0.73)
const FAINT := Color(0.52, 0.52, 0.63)
const WARM := Color(1.00, 0.82, 0.54)
const MOSS := Color(0.66, 0.82, 0.67)
const LILAC := Color(0.76, 0.67, 0.88)
const INK := Color(0.055, 0.060, 0.105, 0.72)
const BORDER := Color(0.79, 0.73, 0.59, 0.22)

var main: Node
var font: SystemFont
var root_control: Control
var title_label: Label
var subtitle_label: Label
var status_label: Label
var fps_label: Label
var debug_label: Label
var hint_label: Label
var detail_label: Label
var toast_label: Label
var phase_button: Button
var weather_button: Button
var quality_button: Button
var pause_button: Button
var pause_badge: Label
var marker_overlay: MarkerOverlay
var hidden := false
var debug_visible := false
var _toast_left := 0.0
var _toast_active := false
var _stats_accum := 0.0
var _last_draws := 0
var _last_tris := 0


class GardenMark extends Control:
	var accent := Color(1, 1, 1)

	func _draw() -> void:
		var c := Vector2(13, 13)
		draw_circle(c + Vector2(0, -4), 3.2, accent)
		draw_arc(c + Vector2(0.8, -4), 5.2, -1.4, 1.5, 20, Color(accent, 0.48), 1.1, true)
		draw_line(Vector2(4, 21), Vector2(12, 16), Color(accent, 0.55), 1.0, true)
		draw_line(Vector2(12, 16), Vector2(20, 20), Color(accent, 0.45), 1.0, true)
		draw_circle(Vector2(21, 21), 1.3, Color(accent, 0.75))


class MarkerOverlay extends Control:
	var markers: Array = []
	var ui_font: SystemFont
	var show_markers := true

	func _draw() -> void:
		if not show_markers:
			return
		for marker in markers:
			if not bool(marker.get("visible", true)):
				continue
			var pos: Vector2 = marker["pos"]
			var is_hover: bool = bool(marker.get("hovered", false))
			var dot_col: Color = Color(1.0, 0.86, 0.62, 0.92) if is_hover else Color(0.84, 0.82, 0.72, 0.30)
			var radius := 13.0 if is_hover else 3.2
			if is_hover:
				draw_arc(pos, radius, 0.0, TAU, 36, dot_col, 1.2, true)
				draw_circle(pos, 1.7, dot_col)
				draw_line(pos + Vector2(-5, 0), pos + Vector2(5, 0), Color(dot_col, 0.62), 0.8, true)
				draw_line(pos + Vector2(0, -5), pos + Vector2(0, 5), Color(dot_col, 0.62), 0.8, true)
				var label: String = str(marker.get("label", ""))
				var display := "E  ·  " + label
				var text_size := ui_font.get_string_size(display, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12)
				var box := Rect2(pos + Vector2(-text_size.x * 0.5 - 9.0, -47.0),
						Vector2(text_size.x + 18.0, 25.0))
				draw_rect(box, Color(0.045, 0.050, 0.085, 0.85), true)
				draw_rect(box, Color(0.88, 0.77, 0.58, 0.36), false, 1.0)
				draw_string(ui_font, box.position + Vector2(9.0, 17.0), display,
						HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color(0.96, 0.91, 0.81, 0.96))
			else:
				draw_arc(pos, radius + 2.0, 0.0, TAU, 18, Color(0.88, 0.82, 0.68, 0.11), 0.8, true)
				draw_circle(pos, radius, dot_col)


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	set_process(true)


func _build_ui() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti", "Microsoft YaHei",
		"Noto Sans CJK SC", "Noto Sans SC", "Avenir Next", "Helvetica Neue", "Arial"
	])
	font.allow_system_fallback = true
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 12
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", WARM)
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.93, 0.72))
	theme.set_color("font_focus_color", "Button", WARM)

	root_control = Control.new()
	root_control.name = "HUDRoot"
	root_control.position = Vector2.ZERO
	root_control.size = DESIGN
	root_control.custom_minimum_size = DESIGN
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.theme = theme
	add_child(root_control)

	var mark := GardenMark.new()
	mark.position = Vector2(27, 20)
	mark.size = Vector2(28, 28)
	mark.accent = Color(1.0, 0.82, 0.56)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(mark)

	title_label = _label("苔光浮庭", 25, Color(0.96, 0.91, 0.79))
	title_label.position = Vector2(61, 15)
	title_label.name = "Title"
	root_control.add_child(title_label)

	subtitle_label = _label("M O S S L I G H T   I S L E", 8, Color(0.71, 0.67, 0.80, 0.92))
	subtitle_label.position = Vector2(63, 45)
	root_control.add_child(subtitle_label)

	var fine := _label("原创程序化庭院 · 一盏灯 / 一阵风 / 一池月色", 10, Color(0.68, 0.67, 0.72, 0.92))
	fine.position = Vector2(63, 61)
	root_control.add_child(fine)

	fps_label = _label("FPS --", 12, Color(0.77, 0.85, 0.75, 0.95))
	fps_label.position = Vector2(1110, 21)
	fps_label.size = Vector2(142, 20)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.name = "FPS"
	root_control.add_child(fps_label)

	status_label = _label("夜 · 晴 · 高", 10, Color(0.75, 0.71, 0.83, 0.9))
	status_label.position = Vector2(1110, 39)
	status_label.size = Vector2(142, 18)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root_control.add_child(status_label)

	debug_label = _label("", 10, Color(0.71, 0.84, 0.82, 0.9))
	debug_label.position = Vector2(1010, 60)
	debug_label.size = Vector2(242, 18)
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.visible = false
	root_control.add_child(debug_label)

	hint_label = _label("拖拽 环绕   ·   滚轮 远近   ·   空格 自动环绕", 10,
			Color(0.88, 0.86, 0.83, 0.98))
	hint_label.position = Vector2(29, 664)
	hint_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.82))
	hint_label.add_theme_constant_override("outline_size", 3)
	root_control.add_child(hint_label)

	detail_label = _label("E / 鼠标点击 轻触小物   ·   H 收起界面   ·   R 重置", 10,
			Color(0.74, 0.72, 0.76, 0.95))
	detail_label.position = Vector2(29, 682)
	detail_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.82))
	detail_label.add_theme_constant_override("outline_size", 3)
	root_control.add_child(detail_label)

	var credit := _label("GL COMPATIBILITY   ·   1280×720", 8,
			Color(0.63, 0.62, 0.69, 0.78))
	credit.position = Vector2(1004, 688)
	credit.size = Vector2(248, 16)
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root_control.add_child(credit)

	var dock := PanelContainer.new()
	dock.name = "BottomDock"
	dock.position = Vector2(432, 606)
	dock.custom_minimum_size = Vector2(416, 50)
	dock.mouse_filter = Control.MOUSE_FILTER_STOP
	dock.add_theme_stylebox_override("panel", _panel_style(
			Color(0.050, 0.055, 0.095, 0.78), Color(0.82, 0.75, 0.59, 0.24), 18, 1))
	root_control.add_child(dock)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock.add_child(row)

	phase_button = _pill_button("夜 · N", 92)
	phase_button.pressed.connect(_on_phase_pressed)
	row.add_child(phase_button)

	weather_button = _pill_button("晴 · T", 92)
	weather_button.pressed.connect(_on_weather_pressed)
	row.add_child(weather_button)

	quality_button = _pill_button("高 · Q", 84)
	quality_button.pressed.connect(_on_quality_pressed)
	row.add_child(quality_button)

	pause_button = _pill_button("暂停 · P", 100)
	pause_button.pressed.connect(_on_pause_pressed)
	row.add_child(pause_button)

	var rule := ColorRect.new()
	rule.position = Vector2(462, 585)
	rule.size = Vector2(356, 1)
	rule.color = Color(0.88, 0.78, 0.60, 0.12)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(rule)

	toast_label = _label("", 13, Color(0.98, 0.91, 0.76, 1.0))
	toast_label.position = Vector2(240, 560)
	toast_label.size = Vector2(800, 24)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.07, 0.62))
	toast_label.add_theme_constant_override("outline_size", 4)
	toast_label.modulate.a = 0.0
	root_control.add_child(toast_label)

	pause_badge = _label("庭院静止   ·   P 继续", 11, Color(0.94, 0.87, 0.72, 0.92))
	pause_badge.position = Vector2(532, 100)
	pause_badge.size = Vector2(216, 24)
	pause_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_badge.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.06, 0.70))
	pause_badge.add_theme_constant_override("outline_size", 4)
	pause_badge.visible = false
	root_control.add_child(pause_badge)

	marker_overlay = MarkerOverlay.new()
	marker_overlay.name = "InteractionMarkers"
	marker_overlay.ui_font = font
	marker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	marker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(marker_overlay)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel_style(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 6
	return style


func _pill_button(text: String, width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 30)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color(0.86, 0.85, 0.83, 0.92))
	button.add_theme_color_override("font_hover_color", WARM)
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.91, 0.68))
	button.add_theme_stylebox_override("normal", _button_style(Color(0.10, 0.11, 0.18, 0.52), Color(0.74, 0.70, 0.60, 0.20), 15))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.16, 0.16, 0.24, 0.72), Color(1.0, 0.82, 0.55, 0.48), 15))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.20, 0.18, 0.25, 0.78), Color(1.0, 0.82, 0.55, 0.72), 15))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _button_style(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func setup(main_node: Node) -> void:
	main = main_node
	sync_from_main()


func sync_from_main() -> void:
	if main == null:
		return
	phase_button.text = ("夜 · N" if bool(main.get("night_mode")) else "昼 · N")
	weather_button.text = ("雨 · T" if bool(main.get("rain_mode")) else "晴 · T")
	quality_button.text = ("高 · Q" if bool(main.get("quality_high")) else "低 · Q")
	var paused: bool = bool(main.get("paused"))
	pause_button.text = "继续 · P" if paused else "暂停 · P"
	pause_badge.visible = paused
	status_label.text = "%s · %s · %s" % [
		"夜" if bool(main.get("night_mode")) else "昼",
		"雨" if bool(main.get("rain_mode")) else "晴",
		"高" if bool(main.get("quality_high")) else "低",
	]
	title_label.modulate = Color(1.0, 0.94, 0.84, 0.98)


func set_fps(fps: int, draws: int, tris: int) -> void:
	fps_label.text = "FPS %d" % fps
	_last_draws = draws
	_last_tris = tris
	if debug_visible:
		debug_label.text = "DRAW %d   TRI %s   ·   GL" % [draws, _format_tris(tris)]


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	debug_label.visible = value
	if value:
		debug_label.text = "DRAW %d   TRI %s   ·   GL" % [_last_draws, _format_tris(_last_tris)]


func show_toast(message: String) -> void:
	toast_label.text = message
	toast_label.modulate.a = 1.0
	_toast_left = 3.2
	_toast_active = true


func set_markers(markers: Array) -> void:
	if marker_overlay != null:
		marker_overlay.markers = markers
		marker_overlay.queue_redraw()


func set_ui_visible(value: bool) -> void:
	hidden = not value
	if root_control != null:
		root_control.visible = value


func toggle_visible() -> void:
	set_ui_visible(hidden)


func set_fps_visible(value: bool) -> void:
	if fps_label != null:
		fps_label.visible = value


func set_markers_visible(value: bool) -> void:
	if marker_overlay != null:
		marker_overlay.show_markers = value
		marker_overlay.queue_redraw()


func _process(delta: float) -> void:
	if _toast_active:
		_toast_left -= delta
		if _toast_left < 0.55:
			toast_label.modulate.a = clampf(_toast_left / 0.55, 0.0, 1.0)
		if _toast_left <= 0.0:
			_toast_active = false
			toast_label.text = ""


func _format_tris(tris: int) -> String:
	if tris >= 1000:
		return "%.1fk" % (float(tris) / 1000.0)
	return str(tris)


func _on_phase_pressed() -> void:
	if main != null:
		main.toggle_phase()


func _on_weather_pressed() -> void:
	if main != null:
		main.toggle_weather()


func _on_quality_pressed() -> void:
	if main != null:
		main.toggle_quality()


func _on_pause_pressed() -> void:
	if main != null:
		main.toggle_pause()
