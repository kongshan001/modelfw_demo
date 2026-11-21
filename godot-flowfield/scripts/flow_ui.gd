class_name FlowFieldUI
extends CanvasLayer

# 中文控制台：三视图、叠加开关、工具、地图/群数、运行状态、图例。

const C_BG := Color(0.145, 0.133, 0.208)
const C_PANEL := Color(0.176, 0.161, 0.259)
const C_PINK := Color(0.973, 0.259, 0.553)
const C_TEAL := Color(0.329, 1.0, 0.776)
const C_CYAN := Color(0.078, 0.945, 0.976)
const C_OBSTACLE := Color(0.086, 0.478, 0.486)
const C_TEXT := Color(0.937, 0.914, 0.969)
const C_DIM := Color(0.604, 0.569, 0.722)

var main = null
var sim = null
var view = null

var _font: SystemFont
var _font_bold: SystemFont
var _theme: Theme
var _root: Control
var _toast: Label
var _toast_tween: Tween
var _status: Label
var _meta: Label
var _pause_button: Button
var _view_buttons := {}
var _tool_buttons := {}
var _map_buttons := {}
var _agent_buttons := {}
var _toggle_buttons := {}
var _stats := {}
var _stat_timer := 0.0
var _recording := false


func _ready() -> void:
	_build_theme()
	_build_root()
	_build_header()
	_build_sidebar()
	_build_toast()


func bind(p_main, p_sim, p_view) -> void:
	main = p_main
	sim = p_sim
	view = p_view
	refresh()


func set_recording(value: bool) -> void:
	_recording = value
	refresh()


func notify(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)


func refresh() -> void:
	if main == null or sim == null or view == null:
		return
	for mode in _view_buttons:
		_view_buttons[mode].set_pressed_no_signal(mode == main.view_mode)
	for tool in _tool_buttons:
		_tool_buttons[tool].set_pressed_no_signal(tool == main.tool)
	for key in _toggle_buttons:
		_toggle_buttons[key].set_pressed_no_signal(bool(view.get("show_" + key)))
	for key in _map_buttons:
		_map_buttons[key].set_pressed_no_signal(key == sim.map_key)
	for count in _agent_buttons:
		_agent_buttons[count].set_pressed_no_signal(int(count) == sim.target_agent_count)
	_pause_button.text = "继续" if sim.paused else "暂停"
	_meta.text = "%d × %d · 种子 %d" % [sim.field.cols, sim.field.rows, sim.seed]
	_update_status()
	_update_stats()


func _process(delta: float) -> void:
	if sim == null:
		return
	_stat_timer += delta
	if _stat_timer >= 0.25:
		_stat_timer = 0.0
		_update_stats()
		_update_status()


func _build_theme() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Arial Unicode MS", "Helvetica Neue",
	])
	_font.allow_system_fallback = true
	_font_bold = SystemFont.new()
	_font_bold.font_names = _font.font_names
	_font_bold.allow_system_fallback = true
	_font_bold.font_weight = 700

	_theme = Theme.new()
	_theme.default_font = _font
	_theme.default_font_size = 12
	_theme.set_color("font_color", "Label", C_TEXT)
	_theme.set_color("font_color", "Button", C_DIM)
	_theme.set_color("font_hover_color", "Button", C_TEXT)
	_theme.set_constant("outline_size", "Label", 0)


func _build_root() -> void:
	_root = Control.new()
	_root.name = "UIRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)


func _build_header() -> void:
	var bar := ColorRect.new()
	bar.color = C_PINK
	bar.position = Vector2(22, 20)
	bar.size = Vector2(4, 30)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)

	var title := _label("流场寻路", 27, C_TEXT, true)
	title.position = Vector2(33, 10)
	title.size = Vector2(320, 42)
	_root.add_child(title)

	var en := _label("FLOW FIELD  ·  群体寻路与避障", 12, C_TEAL, true)
	en.position = Vector2(35, 52)
	en.size = Vector2(420, 20)
	_root.add_child(en)

	var sub := _label("代价场 → 积分场（BFS）→ 流场方向 · 双线性采样 + 分离避让", 11, C_DIM)
	sub.position = Vector2(35, 70)
	sub.size = Vector2(620, 18)
	_root.add_child(sub)

	_status = _label("● 运行中", 11, C_TEAL, true)
	_status.position = Vector2(650, 22)
	_status.size = Vector2(260, 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_status)

	_meta = _label("", 10, C_DIM)
	_meta.position = Vector2(620, 44)
	_meta.size = Vector2(290, 16)
	_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_meta)

	var engine_tag := _label("GODOT 4.6 · 原创复刻", 9, Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.8))
	engine_tag.position = Vector2(650, 62)
	engine_tag.size = Vector2(260, 14)
	engine_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(engine_tag)


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(928, 24)
	panel.size = Vector2(324, 672)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.155, 0.141, 0.231, 0.95)
	panel_style.border_color = Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.28)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(14)
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", panel_style)
	_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	_section(vbox, "视图", "VIEW")
	var view_row := _row(vbox)
	_view_buttons["cost"] = _button("代价场", C_TEAL, true)
	_view_buttons["integration"] = _button("积分场", C_TEAL, true)
	_view_buttons["flow"] = _button("流场", C_TEAL, true)
	var view_group := ButtonGroup.new()
	for key in ["cost", "integration", "flow"]:
		var b: Button = _view_buttons[key]
		b.button_group = view_group
		b.pressed.connect(_on_view.bind(key))
		view_row.add_child(b)

	var toggles := GridContainer.new()
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation", 4)
	toggles.add_theme_constant_override("v_separation", 4)
	vbox.add_child(toggles)
	for pair in [["grid", "网格"], ["numbers", "数值"], ["arrows", "箭头"], ["trails", "轨迹"], ["agents", "智能体"]]:
		var key: String = pair[0]
		var b := _button(str(pair[1]), C_TEAL, true)
		b.toggle_mode = true
		b.toggled.connect(_on_toggle.bind(key))
		_toggle_buttons[key] = b
		toggles.add_child(b)

	_separator(vbox)
	_section(vbox, "编辑工具", "TOOL")
	var tools_row1 := _row(vbox)
	_tool_buttons["goal"] = _button("目标", C_PINK, true)
	_tool_buttons["add_goal"] = _button("加目标", C_PINK, true)
	for key in ["goal", "add_goal"]:
		tools_row1.add_child(_tool_buttons[key])
	var tools_row2 := _row(vbox)
	_tool_buttons["obstacle"] = _button("障碍", C_PINK, true)
	_tool_buttons["erase"] = _button("擦除", C_PINK, true)
	for key in ["obstacle", "erase"]:
		tools_row2.add_child(_tool_buttons[key])
	var tool_group := ButtonGroup.new()
	for key in _tool_buttons:
		var b: Button = _tool_buttons[key]
		b.button_group = tool_group
		b.pressed.connect(_on_tool.bind(key))

	var actions := _row(vbox)
	var clear_btn := _button("清空障碍", C_TEAL)
	clear_btn.pressed.connect(_on_clear)
	actions.add_child(clear_btn)
	var sample_btn := _button("样例地图", C_TEAL)
	sample_btn.pressed.connect(_on_sample)
	actions.add_child(sample_btn)
	var random_btn := _button("随机地图", C_TEAL)
	random_btn.pressed.connect(_on_random)
	actions.add_child(random_btn)

	_separator(vbox)
	_section(vbox, "地图 / 群体", "MAP / AGENTS")
	var size_row := _row(vbox)
	var size_tag := _label("尺寸", 11, C_DIM)
	size_tag.custom_minimum_size = Vector2(36, 0)
	size_row.add_child(size_tag)
	for pair in [["small", "小"], ["medium", "中"], ["large", "大"]]:
		var key: String = pair[0]
		var b := _button(str(pair[1]), C_TEAL, true)
		b.toggled.connect(_on_map_size.bind(key))
		_map_buttons[key] = b
		size_row.add_child(b)
	var map_group := ButtonGroup.new()
	for key in _map_buttons:
		_map_buttons[key].button_group = map_group

	var count_row := _row(vbox)
	var count_tag := _label("群数", 11, C_DIM)
	count_tag.custom_minimum_size = Vector2(36, 0)
	count_row.add_child(count_tag)
	for n in [200, 500, 1000]:
		var b := _button(str(n), C_TEAL, true)
		b.toggled.connect(_on_agent_count.bind(n))
		_agent_buttons[str(n)] = b
		count_row.add_child(b)
	var count_group := ButtonGroup.new()
	for key in _agent_buttons:
		_agent_buttons[key].button_group = count_group

	var run_row := _row(vbox)
	_pause_button = _button("暂停", C_PINK)
	_pause_button.pressed.connect(_on_pause)
	run_row.add_child(_pause_button)
	var reset_btn := _button("重置", C_PINK)
	reset_btn.pressed.connect(_on_reset)
	run_row.add_child(reset_btn)

	_separator(vbox)
	_section(vbox, "运行状态", "STATE")
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 2)
	vbox.add_child(stats)
	for pair in [["fps", "渲染 FPS"], ["agents", "智能体"], ["reach", "可达格"], ["build", "重建"], ["goals", "目标数"], ["arrivals", "已到达"]]:
		var name: String = pair[0]
		var tag := _label(str(pair[1]), 11, C_DIM)
		stats.add_child(tag)
		var value := _label("—", 11, C_TEXT, true)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.add_child(value)
		_stats[name] = value

	_separator(vbox)
	_section(vbox, "图例", "LEGEND")
	var legend_row1 := HBoxContainer.new()
	legend_row1.add_theme_constant_override("separation", 6)
	vbox.add_child(legend_row1)
	_chip(legend_row1, C_OBSTACLE, "障碍")
	_chip(legend_row1, C_CYAN, "目标")
	_chip(legend_row1, C_PINK, "智能体")
	_chip(legend_row1, C_TEAL, "流场")

	var legend_row2 := HBoxContainer.new()
	legend_row2.add_theme_constant_override("separation", 5)
	vbox.add_child(legend_row2)
	var low := _label("积分 低", 10, C_DIM)
	legend_row2.add_child(low)
	var gradient := HBoxContainer.new()
	gradient.add_theme_constant_override("separation", 0)
	gradient.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gradient.custom_minimum_size = Vector2(150, 10)
	for i in 24:
		var color_rect := ColorRect.new()
		var t := float(i) / 23.0
		color_rect.color = _heat(t)
		color_rect.custom_minimum_size = Vector2(5, 10)
		color_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gradient.add_child(color_rect)
	legend_row2.add_child(gradient)
	var high := _label("高", 10, C_DIM)
	legend_row2.add_child(high)

	var help := _label("左键 当前工具 · 右键 快速设目标\nShift+左键 多目标 · 空格 暂停 · R 重置\nG 随机地图 · C 清空障碍 · 1/2/3 视图", 10, Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.9))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(290, 0)
	vbox.add_child(help)

	var footer := _label("T-20261121-009 · 视频研究复刻 · 无外部素材", 9, Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.65))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(footer)


func _build_toast() -> void:
	_toast = _label("", 11, C_TEAL, true)
	_toast.position = Vector2(28, 666)
	_toast.size = Vector2(884, 20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.09, 0.95))
	_toast.add_theme_constant_override("outline_size", 4)
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toast)


func _label(text: String, size: int, color: Color, bold := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	if bold:
		label.add_theme_font_override("font", _font_bold)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, accent: Color, toggle := false) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = toggle
	button.custom_minimum_size = Vector2(64, 25)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_stylebox_override("normal", _style(Color(1, 1, 1, 0.028), Color(1, 1, 1, 0.09), 7))
	button.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, 0.07), Color(accent.r, accent.g, accent.b, 0.45), 7))
	button.add_theme_stylebox_override("pressed", _style(Color(accent.r, accent.g, accent.b, 0.16), Color(accent.r, accent.g, accent.b, 0.85), 7))
	button.add_theme_stylebox_override("hover_pressed", _style(Color(accent.r, accent.g, accent.b, 0.22), Color(accent.r, accent.g, accent.b, 1.0), 7))
	button.add_theme_stylebox_override("disabled", _style(Color(1, 1, 1, 0.02), Color(1, 1, 1, 0.05), 7))
	button.add_theme_color_override("font_color", C_DIM)
	button.add_theme_color_override("font_hover_color", C_TEXT)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_hover_pressed_color", accent)
	button.add_theme_color_override("font_disabled_color", Color(C_DIM.r, C_DIM.g, C_DIM.b, 0.4))
	return button


func _style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 7
	style.content_margin_right = 7
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _section(parent: Control, zh: String, en: String) -> void:
	var label := Label.new()
	label.text = zh + "  " + en
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", C_TEAL)
	label.add_theme_font_override("font", _font_bold)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func _row(parent: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	return row


func _separator(parent: Control) -> void:
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.07)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _chip(parent: Control, color: Color, text: String) -> void:
	var chip := HBoxContainer.new()
	chip.add_theme_constant_override("separation", 4)
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(9, 9)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(swatch)
	var label := _label(text, 10, C_DIM)
	chip.add_child(label)
	parent.add_child(chip)


func _heat(t: float) -> Color:
	var c0 := C_CYAN
	var c1 := Color(0.247, 0.612, 1.0)
	var c2 := Color(0.478, 0.310, 0.839)
	var c3 := Color(0.819, 0.247, 0.557)
	if t < 0.34:
		return c0.lerp(c1, t / 0.34)
	elif t < 0.68:
		return c1.lerp(c2, (t - 0.34) / 0.34)
	return c2.lerp(c3, (t - 0.68) / 0.32)


func _update_stats() -> void:
	if sim == null:
		return
	var fps := Engine.get_frames_per_second()
	_stats["fps"].text = "采集" if _recording else str(fps)
	_stats["agents"].text = str(sim.agent_count)
	_stats["reach"].text = "%d / %d" % [sim.field.reachable_cells, sim.field.open_cells]
	_stats["build"].text = "%.2f ms" % sim.build_ms()
	_stats["goals"].text = str(sim.field.goals.size())
	_stats["arrivals"].text = str(sim.arrivals)


func _update_status() -> void:
	if _recording:
		_status.text = "● 录制中 · 30Hz 逻辑"
		_status.add_theme_color_override("font_color", C_PINK)
	elif sim.paused:
		_status.text = "● 已暂停 · 空格继续"
		_status.add_theme_color_override("font_color", C_PINK)
	else:
		_status.text = "● 运行中 · 30Hz 逻辑 / 60Hz 渲染"
		_status.add_theme_color_override("font_color", C_TEAL)


# 事件 -------------------------------------------------------------------

func _on_view(mode: String) -> void:
	if main != null:
		main.set_view_mode(mode)


func _on_toggle(pressed: bool, key: String) -> void:
	if main != null:
		main.set_show(key, pressed)


func _on_tool(key: String) -> void:
	if main != null:
		main.set_tool(key)


func _on_clear() -> void:
	if main != null:
		main.clear_obstacles()


func _on_sample() -> void:
	if main != null:
		main.load_sample_map()


func _on_random() -> void:
	if main != null:
		main.random_map()


func _on_map_size(_pressed: bool, key: String) -> void:
	if main != null:
		main.set_map_size(key)


func _on_agent_count(_pressed: bool, count: int) -> void:
	if main != null:
		main.set_agent_count(count)


func _on_pause() -> void:
	if main != null:
		main.toggle_pause()


func _on_reset() -> void:
	if main != null:
		main.reset_sim()
