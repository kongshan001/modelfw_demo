extends CanvasLayer
## HUD：标题、实时 FPS、雾参数状态与快捷键。全部用系统字体，不打包字体资源。
## Tab 隐藏/显示；截图与 smoke 通过公开字段检查。

var root_control: Control
var title_label: Label
var subtitle_label: Label
var fps_label: Label
var state_label: Label
var hint_label: Label
var debug_label: Label
var panel_back: ColorRect
var hidden := false
var debug_on := false

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

	subtitle_label = _make_label("原创低模雾林 / 第三人称雾中行走 · 动态雾驱散 · 高度雾 · 雾片 · 伪光束", 12, Color(0.78, 0.82, 0.76, 0.85))
	subtitle_label.position = Vector2(28, 48)
	root_control.add_child(subtitle_label)

	debug_label = _make_label("", 13, Color(0.62, 1.0, 0.88, 0.95))
	debug_label.name = "Debug"
	debug_label.position = Vector2(28, 70)
	debug_label.size = Vector2(720, 26)
	debug_label.visible = false
	root_control.add_child(debug_label)

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
	panel_back.position = Vector2(22, -170)
	panel_back.size = Vector2(790, 146)
	panel_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(panel_back)

	state_label = _make_label("", 14, Color(0.86, 0.90, 0.84))
	state_label.name = "State"
	state_label.position = Vector2(38, -160)
	state_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	state_label.size = Vector2(760, 66)
	state_label.add_theme_constant_override("line_spacing", 4)
	root_control.add_child(state_label)

	hint_label = _make_label(
		"鼠标左键拖拽环绕 · 滚轮缩放 · WASD / 方向键移动 · Shift 奔跑 · V 自由 / 第三人称 · 空格 自动环绕\n" +
		"F 雾浓度   G 雾层高度   C 雾色   B 风速   N 昼夜   1 / 2 质量   R 重置   Tab 隐藏\n" +
		"Z / X 清除半径   Q / E 清除强度   T / Y 恢复速度   F1 调试环与局部雾量",
		12, Color(0.72, 0.77, 0.72, 0.88))
	hint_label.name = "Hints"
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.position = Vector2(38, -94)
	hint_label.size = Vector2(760, 58)
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
	var view := "第三人称" if bool(state.get("follow_view", true)) else "自由相机"
	state_label.text = "质量 %s · %s · %s · 雾浓度 %s · 雾层 %s · 雾色 %s · 风 %s\n雾片 %d · 粒子 %d · 光束 %d%s · 角色 %s %.1fm/s · 雾浪 %d\n雾清除 半径 %.1fm · 强度 %d%% · 恢复 %.1fs · 局部雾量 %d%%" % [
		quality,
		phase,
		view,
		String(state.get("fog_level_name", "中")),
		String(state.get("fog_height_name", "2.0m")),
		String(state.get("fog_color_name", "晨白")),
		String(state.get("wind_name", "1.4×")),
		int(state.get("puffs", 0)),
		int(state.get("particles", 0)),
		int(state.get("beams", 0)),
		" · god rays 开" if bool(state.get("god_rays", false)) else " · god rays 关",
		String(state.get("player_anim", "Idle")),
		float(state.get("player_speed", 0.0)),
		int(state.get("wakes", 0)),
		float(state.get("clear_radius", 4.5)),
		int(round(float(state.get("clear_strength", 0.85)) * 100.0)),
		float(state.get("recovery", 1.6)),
		int(round(float(state.get("local_factor", 1.0)) * 100.0)),
	]
	debug_on = bool(state.get("debug", false))
	debug_label.visible = debug_on and not hidden
	if debug_on:
		debug_label.text = "F1 调试  半径 %.1fm（淡出至 %.1fm） · 局部雾量 %d%% · 清除量 %d%% · 恢复 %.1fs · 雾浪 %d · 角色速度 %.2fm/s" % [
			float(state.get("clear_radius", 4.5)),
			float(state.get("clear_radius", 4.5)) * 1.55,
			int(round(float(state.get("local_factor", 1.0)) * 100.0)),
			int(round(float(state.get("clear_amount", 0.0)) * 100.0)),
			float(state.get("recovery", 1.6)),
			int(state.get("wakes", 0)),
			float(state.get("player_speed", 0.0)),
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
	debug_label.visible = (not hidden) and debug_on


func set_hud_visible(value: bool) -> void:
	hidden = not value
	root_control.visible = value
	debug_label.visible = value and debug_on
