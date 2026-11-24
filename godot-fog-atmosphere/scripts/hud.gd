extends CanvasLayer
## HUD：标题、实时 FPS、雾参数状态与快捷键。全部用系统字体，不打包字体资源。
## Tab 隐藏/显示；截图与 smoke 通过公开字段检查。

var root_control: Control
var title_label: Label
var subtitle_label: Label
var fps_label: Label
var state_label: Label
var hint_label: Label
var panel_back: ColorRect
var hidden := false

var _font: SystemFont


func _ready() -> void:
	layer = 20
	_build()


func _build() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Noto Sans SC", "Helvetica Neue", "Arial"
	])

	root_control = Control.new()
	root_control.name = "HUDRoot"
	root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	title_label = _make_label("雾林微光 · FOGWOOD", 22, Color(0.94, 0.95, 0.90))
	title_label.position = Vector2(26, 18)
	title_label.name = "Title"
	root_control.add_child(title_label)

	subtitle_label = _make_label("原创低模雾林 / 高度雾 · 深度雾 · 雾片 · 伪光束", 12, Color(0.78, 0.82, 0.76, 0.85))
	subtitle_label.position = Vector2(28, 48)
	root_control.add_child(subtitle_label)

	fps_label = _make_label("FPS --", 17, Color(0.72, 0.92, 0.72))
	fps_label.name = "FPS"
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	fps_label.position = Vector2(-180, 20)
	fps_label.size = Vector2(154, 24)
	root_control.add_child(fps_label)

	panel_back = ColorRect.new()
	panel_back.color = Color(0.02, 0.035, 0.038, 0.62)
	panel_back.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel_back.position = Vector2(22, -142)
	panel_back.size = Vector2(690, 118)
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(panel_back)

	state_label = _make_label("", 14, Color(0.86, 0.90, 0.84))
	state_label.name = "State"
	state_label.position = Vector2(38, -130)
	state_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	state_label.size = Vector2(660, 44)
	state_label.add_theme_constant_override("line_spacing", 5)
	root_control.add_child(state_label)

	hint_label = _make_label(
		"鼠标左键拖拽环绕 · 滚轮缩放 · WASD 平移 · 空格 自动环绕\n" +
		"F 雾浓度   G 雾层高度   C 雾色   B 风速   N 昼夜   1 / 2 质量   R 重置   Tab 隐藏",
		12, Color(0.72, 0.77, 0.72, 0.88))
	hint_label.name = "Hints"
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(38, -82)
	hint_label.size = Vector2(670, 48)
	hint_label.add_theme_constant_override("line_spacing", 4)
	root_control.add_child(hint_label)


func _make_label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func update_state(state: Dictionary) -> void:
	var phase := "夜" if bool(state.get("night", false)) else "昼"
	var quality := "高" if bool(state.get("high_quality", true)) else "低"
	state_label.text = "质量 %s · %s · 雾浓度 %s · 雾层 %s · 雾色 %s · 风 %s\n雾片 %d · 粒子 %d · 光束 %d%s" % [
		quality,
		phase,
		String(state.get("fog_level_name", "中")),
		String(state.get("fog_height_name", "2.0m")),
		String(state.get("fog_color_name", "晨白")),
		String(state.get("wind_name", "1.4×")),
		int(state.get("puffs", 0)),
		int(state.get("particles", 0)),
		int(state.get("beams", 0)),
		" · god rays 开" if bool(state.get("god_rays", false)) else " · god rays 关",
	]


func set_fps(fps: int, frame_ms: float) -> void:
	var color := Color(0.72, 0.92, 0.72)
	if fps < 30:
		color = Color(0.98, 0.72, 0.38)
	if fps < 20:
		color = Color(0.98, 0.45, 0.38)
	fps_label.text = "FPS %d · %.1fms" % [fps, frame_ms]
	fps_label.add_theme_color_override("font_color", color)


func set_fps_visible(value: bool) -> void:
	fps_label.visible = value


func toggle_visible() -> void:
	hidden = not hidden
	root_control.visible = not hidden


func set_hud_visible(value: bool) -> void:
	hidden = not value
	root_control.visible = value
