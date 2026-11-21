extends CanvasLayer

## 中文控制台：场景预设 / 行为开关与权重 / 参数 / 显示开关 / 选中单位信息。
## UI 全部程序化构建，不依赖外部字体或皮肤；中文使用系统字体。

const BEHAVIOR_SHORT := {
	"flow": "流场跟随", "avoidance": "避障", "separation": "分离",
	"alignment": "对齐", "cohesion": "聚合", "leader": "队列跟随",
	"seek": "靠近", "arrive": "抵达", "flee": "逃离",
	"pursue": "追逐", "evade": "躲避", "wander": "漫游",
}
const BEHAVIOR_EN := {
	"flow": "Flow", "avoidance": "Avoidance", "separation": "Separation",
	"alignment": "Alignment", "cohesion": "Cohesion", "leader": "Leader",
	"seek": "Seek", "arrive": "Arrive", "flee": "Flee",
	"pursue": "Pursue", "evade": "Evade", "wander": "Wander",
}
const PARAM_META := {
	"max_speed": {"label": "最大速度", "min": 60.0, "max": 260.0, "step": 5.0, "unit": "px/s"},
	"max_force": {"label": "最大转向力", "min": 120.0, "max": 1000.0, "step": 20.0, "unit": "px/s²"},
	"lookahead": {"label": "避障探测距离", "min": 40.0, "max": 240.0, "step": 5.0, "unit": "px"},
	"neighbor_radius": {"label": "邻域半径", "min": 24.0, "max": 140.0, "step": 2.0, "unit": "px"},
}
const SHOW_META := {
	"vectors": "力向量（选中）",
	"rays": "避障射线（选中）",
	"neighbors": "邻居连线（选中）",
	"flow": "流场箭头",
	"highlight": "主导行为高亮",
}
const C_PANEL := Color(0.055, 0.065, 0.145, 0.92)
const C_PANEL_EDGE := Color(0.28, 0.78, 0.75, 0.28)
const C_TEXT := Color(0.88, 0.94, 1.0, 1.0)
const C_DIM := Color(0.60, 0.70, 0.85, 1.0)
const C_ACCENT := Color(0.32, 0.92, 0.84, 1.0)
const C_PINK := Color(1.0, 0.38, 0.66, 1.0)
const C_BTN := Color(0.10, 0.12, 0.23, 1.0)
const C_BTN_HOVER := Color(0.16, 0.20, 0.36, 1.0)
const C_BTN_DOWN := Color(0.30, 0.14, 0.25, 1.0)

var sim
var _theme: Theme
var _title_panel: PanelContainer
var _side_panel: PanelContainer
var _preset_label: Label
var _hint_label: Label
var _stats_label: Label
var _selected_label: Label
var _pause_button: Button
var _count_slider: HSlider
var _count_value: Label
var _preset_buttons := {}
var _behavior_checks := {}
var _behavior_sliders := {}
var _behavior_values := {}
var _param_sliders := {}
var _param_values := {}
var _show_checks := {}
var _syncing := false
var _ui_clock := 0.0


func _ready() -> void:
	_make_theme()
	_build_title()
	_build_side_panel()


func bind(target) -> void:
	sim = target
	refresh()
	_update_stats()


func _make_theme() -> void:
	_theme = Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
	])
	_theme.default_font = font
	_theme.default_font_size = 14
	_theme.set_color("font_color", "Label", C_TEXT)
	_theme.set_color("font_color", "Button", C_TEXT)
	_theme.set_color("font_hover_color", "Button", Color(1, 1, 1, 1))
	_theme.set_color("font_color", "CheckBox", C_TEXT)
	_theme.set_color("font_color", "CheckButton", C_TEXT)


func _root_control() -> Control:
	var control := Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.theme = _theme
	add_child(control)
	return control


func _panel_style(bg := C_PANEL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = C_PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	return style


func _section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", C_ACCENT)
	label.custom_minimum_size = Vector2(0, 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return label


func _button(text: String, width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	if width > 0.0:
		b.custom_minimum_size.x = width
	b.add_theme_stylebox_override("normal", _button_style(C_BTN))
	b.add_theme_stylebox_override("hover", _button_style(C_BTN_HOVER))
	b.add_theme_stylebox_override("pressed", _button_style(C_BTN_DOWN))
	b.add_theme_stylebox_override("focus", _button_style(C_BTN_HOVER))
	return b


func _button_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = C_PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _build_title() -> void:
	var control := _root_control()
	_title_panel = PanelContainer.new()
	_title_panel.add_theme_stylebox_override("panel", _panel_style())
	_title_panel.position = Vector2(18, 16)
	_title_panel.custom_minimum_size = Vector2(436, 0)
	_title_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control.add_child(_title_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_title_panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	box.add_child(title_row)
	var title := Label.new()
	title.text = "转向行为实验场"
	title.add_theme_font_size_override("font_size", 23)
	title.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	title_row.add_child(title)
	var en := Label.new()
	en.text = "STEERING BEHAVIOR"
	en.add_theme_font_size_override("font_size", 11)
	en.add_theme_color_override("font_color", C_ACCENT)
	en.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(en)

	var sub := Label.new()
	sub.text = "群体寻路 · 三须避障 · 流场跟随 · 分离/对齐/聚合"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_DIM)
	box.add_child(sub)

	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 6)
	box.add_child(preset_row)
	var group := ButtonGroup.new()
	group.allow_unpress = false
	var order := ["video", "chase", "corridor", "flock"]
	for i in order.size():
		var key: String = order[i]
		var b := _button("", 96)
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_on_preset_pressed.bind(key))
		preset_row.add_child(b)
		_preset_buttons[key] = b
	_preset_label = Label.new()
	_preset_label.add_theme_font_size_override("font_size", 13)
	_preset_label.add_theme_color_override("font_color", C_PINK)
	box.add_child(_preset_label)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", C_DIM)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(410, 0)
	box.add_child(_hint_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 13)
	_stats_label.add_theme_color_override("font_color", Color(0.80, 0.90, 1.0, 1.0))
	box.add_child(_stats_label)


func _build_side_panel() -> void:
	var control := _root_control()
	_side_panel = PanelContainer.new()
	_side_panel.add_theme_stylebox_override("panel", _panel_style())
	_side_panel.anchor_left = 1.0
	_side_panel.anchor_right = 1.0
	_side_panel.anchor_top = 0.0
	_side_panel.anchor_bottom = 1.0
	_side_panel.offset_left = -386
	_side_panel.offset_right = -16
	_side_panel.offset_top = 16
	_side_panel.offset_bottom = -16
	_side_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	control.add_child(_side_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_side_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var header_label := Label.new()
	header_label.text = "控制台"
	header_label.add_theme_font_size_override("font_size", 16)
	header.add_child(header_label)
	var header_pad := Control.new()
	header_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(header_pad)
	var hide_hint := Label.new()
	hide_hint.text = "H 隐藏 · 空格暂停"
	hide_hint.add_theme_font_size_override("font_size", 11)
	hide_hint.add_theme_color_override("font_color", C_DIM)
	header.add_child(hide_hint)

	_selected_label = Label.new()
	_selected_label.add_theme_font_size_override("font_size", 12)
	_selected_label.add_theme_color_override("font_color", C_PINK)
	_selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_label.custom_minimum_size = Vector2(330, 34)
	column.add_child(_selected_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 5)
	scroll.add_child(content)

	content.add_child(_section("模拟 SIMULATION"))

	var count_row := HBoxContainer.new()
	count_row.add_theme_constant_override("separation", 8)
	content.add_child(count_row)
	var count_label := Label.new()
	count_label.text = "智能体数量"
	count_label.custom_minimum_size.x = 96
	count_row.add_child(count_label)
	_count_slider = HSlider.new()
	_count_slider.min_value = 20
	_count_slider.max_value = 300
	_count_slider.step = 10
	_count_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count_slider.focus_mode = Control.FOCUS_NONE
	_count_slider.value_changed.connect(_on_count_changed)
	count_row.add_child(_count_slider)
	_count_value = Label.new()
	_count_value.custom_minimum_size.x = 40
	_count_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_row.add_child(_count_value)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	content.add_child(action_row)
	_pause_button = _button("暂停", 0)
	_pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_button.pressed.connect(_on_pause_pressed)
	action_row.add_child(_pause_button)
	var reset_button := _button("重置", 0)
	reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_button.pressed.connect(_on_reset_pressed)
	action_row.add_child(reset_button)

	content.add_child(_section("群体行为 GROUP"))
	for key in ["flow", "avoidance", "separation", "alignment", "cohesion", "leader"]:
		content.add_child(_behavior_row(key))

	content.add_child(_section("个体行为 INDIVIDUAL"))
	for key in ["seek", "arrive", "flee", "pursue", "evade", "wander"]:
		content.add_child(_behavior_row(key))

	content.add_child(_section("参数 PARAMETERS"))
	for key in ["max_speed", "max_force", "lookahead", "neighbor_radius"]:
		content.add_child(_param_row(key))

	content.add_child(_section("显示 VISUALIZATION"))
	for key in ["vectors", "rays", "neighbors", "flow", "highlight"]:
		var check := CheckBox.new()
		check.text = SHOW_META[key]
		check.focus_mode = Control.FOCUS_NONE
		check.add_theme_font_size_override("font_size", 13)
		check.toggled.connect(_on_show_toggled.bind(key))
		content.add_child(check)
		_show_checks[key] = check
	var legend := Label.new()
	legend.text = "高亮：流场 青 / 避障 橙 / 分离 黄 / 对齐 绿 / 聚合 紫 / 漫游 白"
	legend.add_theme_font_size_override("font_size", 11)
	legend.add_theme_color_override("font_color", C_DIM)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(legend)

	content.add_child(_section("操作 CONTROLS"))
	var help := Label.new()
	help.text = "左键选中单位 · 双击空地设置目标\n空格 暂停 · R 重置 · 1–4 切换预设\nV 力向量 · B 射线 · N 邻居 · G 流场 · L 高亮"
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", C_DIM)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(help)


func _behavior_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var check := CheckBox.new()
	check.text = "%s %s" % [BEHAVIOR_SHORT[key], BEHAVIOR_EN[key]]
	check.focus_mode = Control.FOCUS_NONE
	check.custom_minimum_size.x = 146
	check.add_theme_font_size_override("font_size", 12)
	check.toggled.connect(_on_behavior_toggled.bind(key))
	row.add_child(check)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 3.0
	slider.step = 0.05
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size.x = 90
	slider.value_changed.connect(_on_behavior_weight_changed.bind(key))
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 32
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	_behavior_checks[key] = check
	_behavior_sliders[key] = slider
	_behavior_values[key] = value
	return row


func _param_row(key: String) -> HBoxContainer:
	var meta: Dictionary = PARAM_META[key]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var label := Label.new()
	label.text = meta["label"]
	label.custom_minimum_size.x = 146
	label.add_theme_font_size_override("font_size", 12)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = meta["min"]
	slider.max_value = meta["max"]
	slider.step = meta["step"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_param_changed.bind(key))
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 56
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 12)
	row.add_child(value)
	_param_sliders[key] = slider
	_param_values[key] = value
	return row


# ---------------------------------------------------------------- 状态刷新

func refresh() -> void:
	if sim == null or _syncing:
		return
	_syncing = true
	var cfg: Dictionary = sim.get_config()
	_preset_label.text = "当前场景：" + String(cfg["preset_label"])
	_hint_label.text = String(cfg["hint"])
	for key in _preset_buttons:
		var b: Button = _preset_buttons[key]
		b.text = String(cfg["presets"].get(key, key))
		b.set_pressed_no_signal(key == cfg["preset"])
	_count_slider.set_value_no_signal(float(cfg["count"]))
	_count_value.text = str(cfg["count"])
	for key in _behavior_checks:
		var on: bool = cfg["enabled"].get(key, false)
		_behavior_checks[key].set_pressed_no_signal(on)
		var w: float = float(cfg["weights"].get(key, 0.0))
		_behavior_sliders[key].set_value_no_signal(w)
		_behavior_sliders[key].editable = on
		_behavior_values[key].text = "%.2f" % w
	for key in _param_sliders:
		var v: float = float(cfg["params"].get(key, 0.0))
		_param_sliders[key].set_value_no_signal(v)
		_param_values[key].text = "%d %s" % [int(v), PARAM_META[key]["unit"]]
	for key in _show_checks:
		_show_checks[key].set_pressed_no_signal(bool(cfg["show"].get(key, false)))
	_pause_button.text = "继续" if cfg["paused"] else "暂停"
	_syncing = false
	_update_stats()


func _process(delta: float) -> void:
	_ui_clock += delta
	if _ui_clock < 0.18:
		return
	_ui_clock = 0.0
	_update_stats()


func _update_stats() -> void:
	if sim == null:
		return
	var stats: Dictionary = sim.get_stats()
	var goal_text := "目标区 %d" % int(stats["arrived"])
	if not bool(stats.get("goal_visible", true)):
		goal_text = "无目标 · 自由漫游"
	_stats_label.text = "FPS %d   ·   单位 %d   ·   模拟 %.2f ms\n%s   ·   接触修正 %d   ·   种子 %d" % [
		int(stats["fps"]), int(stats["count"]), float(stats["sim_ms"]),
		goal_text, int(stats["contacts"]), int(stats["seed"]),
	]
	var info: Dictionary = sim.get_selected_info()
	if not info.get("valid", false):
		_selected_label.text = "点击任意单位查看它的力向量、避障射线与主导行为。"
	else:
		var role_names := {"prey": "猎物", "predator": "追捕者", "boid": "单位"}
		var dominant: String = String(info["dominant"])
		var dominant_name: String = BEHAVIOR_SHORT.get(dominant, "—")
		_selected_label.text = "选中 #%d · %s · 主导行为：%s\n速度 %.0f px/s · 邻居 %d · 转向力 %.0f" % [
			int(info["id"]), role_names.get(info["role"], "单位"), dominant_name,
			float(info["speed"]), int(info["neighbors"]), float(info["force"]),
		]


# ---------------------------------------------------------------- 控件回调

func _on_preset_pressed(key: String) -> void:
	if sim == null:
		return
	sim.apply_preset(key)


func _on_count_changed(value: float) -> void:
	if _syncing or sim == null:
		return
	_count_value.text = str(int(value))
	sim.set_agent_count(int(value))


func _on_pause_pressed() -> void:
	if sim == null:
		return
	sim.toggle_pause()
	refresh()


func _on_reset_pressed() -> void:
	if sim == null:
		return
	sim.reset_sim(true)


func _on_behavior_toggled(pressed: bool, key: String) -> void:
	if _syncing or sim == null:
		return
	sim.set_behavior_enabled(key, pressed)


func _on_behavior_weight_changed(value: float, key: String) -> void:
	if _syncing or sim == null:
		return
	sim.set_behavior_weight(key, value)


func _on_param_changed(value: float, key: String) -> void:
	if _syncing or sim == null:
		return
	sim.set_param(key, value)
	_param_values[key].text = "%d %s" % [int(value), PARAM_META[key]["unit"]]


func _on_show_toggled(pressed: bool, key: String) -> void:
	if _syncing or sim == null:
		return
	sim.set_show(key, pressed)
