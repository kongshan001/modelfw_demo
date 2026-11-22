extends PanelContainer

# 左侧中文控制台：种子 / 尺寸 / 参数 / 速度 / 单步 / 调试叠加 / 统计 / FPS / 子随机流。
# 控件由代码构建，1280 与 1920 共用一套布局，按 ui_scale 缩放。

const UiTheme = preload("res://scripts/ui_theme.gd")

var main = null
var _scale := 1.0
var _syncing := false
var _mode := "biome"

var seed_edit: LineEdit
var random_button: Button
var generate_button: Button
var restart_button: Button
var size_option: OptionButton
var param_label: Label
var param_slider: HSlider
var param_value: Label
var speed_slider: HSlider
var speed_value: Label
var pause_button: Button
var step_button: Button
var finish_button: Button
var progress: ProgressBar
var stage_value: Label
var stat_values: Dictionary = {}
var stat_names: Dictionary = {}
var debug_checks: Dictionary = {}
var noise_buttons: Dictionary = {}
var noise_group: ButtonGroup
var stream_label: Label
var sig_status: Label
var mode_badge: Label
var fps_value: Label
var time_value: Label
var _mono: SystemFont


func setup(main_node, ui_scale: float) -> void:
	main = main_node
	_scale = ui_scale
	_mono = SystemFont.new()
	_mono.font_names = PackedStringArray(["SF Mono", "Menlo", "Monaco", "Consolas", "Sans-Serif"])
	_mono.allow_system_fallback = true
	var style := UiTheme.panel_style(
		Color(0.07, 0.115, 0.12, 0.95), Color(0.30, 0.43, 0.41, 0.92), _scale, 8.0)
	style.content_margin_top = 9.0 * _scale
	style.content_margin_bottom = 9.0 * _scale
	style.content_margin_left = 11.0 * _scale
	style.content_margin_right = 11.0 * _scale
	add_theme_stylebox_override("panel", style)
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.name = "HudColumn"
	root.add_theme_constant_override("separation", int(round(4.0 * _scale)))
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := UiTheme.make_label("生成控制", 15.0, UiTheme.MINT, _scale)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	mode_badge = UiTheme.make_label("BIOME", 8.5, UiTheme.MUTED, _scale)
	mode_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(mode_badge)

	# 种子
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(seed_row)
	var seed_label := UiTheme.make_label("种子", 11.5, UiTheme.MUTED, _scale)
	seed_label.custom_minimum_size = Vector2(38.0 * _scale, 0.0)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.text = "9001"
	seed_edit.placeholder_text = "数字或文字"
	seed_edit.max_length = 24
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.custom_minimum_size = Vector2(0.0, 26.0 * _scale)
	seed_edit.add_theme_font_size_override("font_size", int(round(11.5 * _scale)))
	seed_edit.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(seed_edit)
	random_button = _small_button("随机", 42.0, 26.0, "换一个随机种子并立即生成（N）")
	random_button.pressed.connect(_on_random)
	seed_row.add_child(random_button)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(action_row)
	generate_button = _button("生成地图", 28.0)
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_primary(generate_button, _scale)
	generate_button.pressed.connect(_on_generate)
	action_row.add_child(generate_button)
	restart_button = _button("重开", 28.0)
	restart_button.custom_minimum_size = Vector2(60.0 * _scale, 28.0 * _scale)
	restart_button.tooltip_text = "同种子从第一阶段重新演示（R）"
	restart_button.pressed.connect(_on_restart)
	action_row.add_child(restart_button)

	# 尺寸
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(size_row)
	var size_label := UiTheme.make_label("尺寸", 11.5, UiTheme.MUTED, _scale)
	size_label.custom_minimum_size = Vector2(38.0 * _scale, 0.0)
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(size_label)
	size_option = OptionButton.new()
	size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_option.custom_minimum_size = Vector2(0.0, 26.0 * _scale)
	size_option.add_theme_font_size_override("font_size", int(round(11.5 * _scale)))
	size_option.item_selected.connect(_on_size_selected)
	size_row.add_child(size_option)

	# 参数
	var param_row := HBoxContainer.new()
	param_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(param_row)
	param_label = UiTheme.make_label("环路", 11.5, UiTheme.MUTED, _scale)
	param_label.custom_minimum_size = Vector2(38.0 * _scale, 0.0)
	param_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	param_row.add_child(param_label)
	param_slider = HSlider.new()
	param_slider.min_value = 0.0
	param_slider.max_value = 30.0
	param_slider.step = 1.0
	param_slider.value = 12.0
	param_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	param_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	param_slider.value_changed.connect(_on_param_changed)
	param_slider.drag_ended.connect(_on_param_drag_ended)
	param_row.add_child(param_slider)
	param_value = UiTheme.make_label("12%", 9.5, UiTheme.AMBER, _scale)
	param_value.custom_minimum_size = Vector2(48.0 * _scale, 0.0)
	param_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	param_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	param_row.add_child(param_value)

	# 速度
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(speed_row)
	var speed_label := UiTheme.make_label("速度", 11.5, UiTheme.MUTED, _scale)
	speed_label.custom_minimum_size = Vector2(38.0 * _scale, 0.0)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_label)
	speed_slider = HSlider.new()
	speed_slider.min_value = 1.0
	speed_slider.max_value = 8.0
	speed_slider.step = 1.0
	speed_slider.value = 2.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(speed_slider)
	speed_value = UiTheme.make_label("2 阶段/秒", 9.5, UiTheme.AMBER, _scale)
	speed_value.custom_minimum_size = Vector2(62.0 * _scale, 0.0)
	speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_value)

	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	root.add_child(run_row)
	pause_button = _button("暂停", 26.0)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(_on_pause)
	run_row.add_child(pause_button)
	step_button = _button("单步", 26.0)
	step_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_button.tooltip_text = "暂停并推进一个生成阶段（S）"
	step_button.pressed.connect(_on_step)
	run_row.add_child(step_button)
	finish_button = _button("完成", 26.0)
	finish_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish_button.tooltip_text = "立即执行剩余阶段（F）"
	finish_button.pressed.connect(_on_finish)
	run_row.add_child(finish_button)

	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0.0, 3.0 * _scale)
	progress.show_percentage = false
	progress.max_value = 1.0
	progress.value = 0.0
	root.add_child(progress)

	root.add_child(UiTheme.divider(_scale))

	var debug_head := HBoxContainer.new()
	root.add_child(debug_head)
	var debug_title := UiTheme.make_label("调试叠加", 12.0, UiTheme.MINT, _scale)
	debug_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_head.add_child(debug_title)
	var debug_note := UiTheme.make_label("可同时开启", 8.5, UiTheme.MUTED, _scale)
	debug_note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	debug_head.add_child(debug_note)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", int(round(8.0 * _scale)))
	grid.add_theme_constant_override("v_separation", 0)
	root.add_child(grid)
	_add_debug_check(grid, "connectivity", "连通性", "BFS 连通分量 / 不可达高亮（C）")
	_add_debug_check(grid, "rooms", "房间 / BSP", "BSP 切分线、房间 ID、起点终点（M）")
	_add_debug_check(grid, "biomes", "生物群系", "纯色群系分类与图例（B）")
	_add_debug_check(grid, "noise", "噪声场", "海拔/湿度/温度热力与等值线（V）")
	_add_debug_check(grid, "bounds", "边界 / 网格", "地图边界与 8 格网格（O）")

	var noise_row := HBoxContainer.new()
	noise_row.add_theme_constant_override("separation", int(round(5.0 * _scale)))
	root.add_child(noise_row)
	var noise_label := UiTheme.make_label("噪声源", 9.5, UiTheme.MUTED, _scale)
	noise_label.custom_minimum_size = Vector2(46.0 * _scale, 0.0)
	noise_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	noise_row.add_child(noise_label)
	noise_group = ButtonGroup.new()
	for pair in [["elevation", "海拔"], ["moisture", "湿度"], ["temperature", "温度"]]:
		var button := Button.new()
		button.text = pair[1]
		button.toggle_mode = true
		button.button_group = noise_group
		button.button_pressed = pair[0] == "elevation"
		button.add_theme_font_size_override("font_size", int(round(9.5 * _scale)))
		button.custom_minimum_size = Vector2(0.0, 21.0 * _scale)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_noise_field.bind(pair[0]))
		noise_row.add_child(button)
		noise_buttons[pair[0]] = button

	root.add_child(UiTheme.divider(_scale))

	var stats_head := HBoxContainer.new()
	root.add_child(stats_head)
	var stats_title := UiTheme.make_label("运行统计", 12.0, UiTheme.MINT, _scale)
	stats_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_head.add_child(stats_title)
	fps_value = UiTheme.make_label("-- FPS", 9.5, UiTheme.AMBER, _scale)
	fps_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_head.add_child(fps_value)

	for key in ["stage", "scale", "connect", "detail", "life", "time"]:
		_stat_row(root, key)

	sig_status = UiTheme.make_label("固定种子可复现", 8.5, UiTheme.MUTED, _scale)
	root.add_child(sig_status)
	var stream_title := UiTheme.make_label("子随机流（由种子派生）", 8.5, UiTheme.MUTED, _scale)
	root.add_child(stream_title)

	stream_label = Label.new()
	stream_label.add_theme_font_override("font", _mono)
	stream_label.add_theme_font_size_override("font_size", int(round(8.0 * _scale)))
	stream_label.add_theme_color_override("font_color", Color(0.62, 0.76, 0.7, 0.9))
	stream_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stream_label.custom_minimum_size = Vector2(0.0, 21.0 * _scale)
	root.add_child(stream_label)

	var hint := UiTheme.make_label("拖动/滚轮 · Space 暂停 · S 单步 · R 重开 · N 随机",
			8.0, Color(0.55, 0.66, 0.62, 0.85), _scale)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(hint)


func _stat_row(parent: VBoxContainer, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(6.0 * _scale)))
	row.custom_minimum_size = Vector2(0.0, 16.0 * _scale)
	parent.add_child(row)
	var name_label := UiTheme.make_label("—", 9.2, UiTheme.MUTED, _scale)
	name_label.custom_minimum_size = Vector2(66.0 * _scale, 0.0)
	row.add_child(name_label)
	var value_label := Label.new()
	value_label.text = "—"
	value_label.add_theme_font_override("font", _mono)
	value_label.add_theme_font_size_override("font_size", int(round(9.4 * _scale)))
	value_label.add_theme_color_override("font_color", UiTheme.TEXT)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(value_label)
	stat_names[key] = name_label
	stat_values[key] = value_label


func _add_debug_check(grid: GridContainer, key: String, text: String, tooltip: String) -> void:
	var check := CheckBox.new()
	check.text = text
	check.tooltip_text = tooltip
	check.add_theme_font_size_override("font_size", int(round(9.5 * _scale)))
	check.custom_minimum_size = Vector2(0.0, 20.0 * _scale)
	check.toggled.connect(_on_debug_toggled.bind(key))
	grid.add_child(check)
	debug_checks[key] = check


func _small_button(text: String, width: float, height: float, tooltip := "") -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(width * _scale, height * _scale)
	button.add_theme_font_size_override("font_size", int(round(10.0 * _scale)))
	return button


func _button(text: String, height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, height * _scale)
	button.add_theme_font_size_override("font_size", int(round(10.5 * _scale)))
	return button


# ---------------------------------------------------------------------------
# 外部同步
# ---------------------------------------------------------------------------

func configure_mode(state: Dictionary) -> void:
	_syncing = true
	_mode = String(state.get("mode", "biome"))
	mode_badge.text = "BIOME" if _mode == "biome" else "BSP DUNGEON"
	size_option.clear()
	var sizes: Array = state.get("sizes", [])
	for label in sizes:
		size_option.add_item(String(label))
	if size_option.item_count > 0:
		size_option.select(clampi(int(state.get("size_index", 0)), 0, size_option.item_count - 1))
	var param_cfg: Dictionary = state.get("param", {})
	param_label.text = String(param_cfg.get("label", "参数"))
	param_slider.min_value = float(param_cfg.get("min", 0.0))
	param_slider.max_value = float(param_cfg.get("max", 1.0))
	param_slider.step = float(param_cfg.get("step", 1.0))
	param_slider.value = float(param_cfg.get("value", 0.0))
	param_value.text = String(param_cfg.get("text", ""))
	debug_checks["rooms"].text = "房间 / BSP" if _mode == "dungeon" else "区域 / 地标"
	debug_checks["biomes"].disabled = _mode == "dungeon"
	debug_checks["noise"].text = "噪声场" if _mode == "biome" else "BSP 深度"
	for key in noise_buttons:
		noise_buttons[key].get_parent().visible = _mode == "biome"
	_syncing = false


func refresh(state: Dictionary) -> void:
	_syncing = true
	if not seed_edit.has_focus():
		seed_edit.text = String(state.get("seed_text", seed_edit.text))
	if size_option.item_count > 0:
		size_option.select(clampi(int(state.get("size_index", 0)), 0, size_option.item_count - 1))
	var speed := float(state.get("speed", 2.0))
	speed_slider.value = speed
	speed_value.text = "%d 阶段/秒" % int(round(speed))
	var param_cfg: Dictionary = state.get("param", {})
	param_slider.min_value = float(param_cfg.get("min", 0.0))
	param_slider.max_value = float(param_cfg.get("max", 1.0))
	param_slider.step = float(param_cfg.get("step", 1.0))
	param_slider.value = float(param_cfg.get("value", 0.0))
	param_value.text = String(param_cfg.get("text", ""))
	pause_button.text = "继续" if bool(state.get("paused", false)) else "暂停"
	step_button.disabled = bool(state.get("finished", false))
	finish_button.disabled = bool(state.get("finished", false))
	pause_button.disabled = bool(state.get("finished", false))
	var stage_index := int(state.get("stage_index", 0))
	var stage_count := int(state.get("stage_count", 1))
	progress.max_value = float(stage_count)
	progress.value = float(clampi(stage_index + 1, 0, stage_count))
	stat_values["stage"].text = "%d/%d · %s" % [clampi(stage_index + 1, 1, stage_count),
			stage_count, String(state.get("stage_name", "准备"))]
	stat_names["stage"].text = "阶段"
	stat_names["scale"].text = "规模"
	stat_names["connect"].text = "连通"
	stat_names["detail"].text = "结构"
	stat_names["life"].text = "资源"
	stat_names["time"].text = "耗时"
	stat_values["scale"].text = String(state.get("scale_text", "—"))
	stat_values["connect"].text = String(state.get("connect_text", "—"))
	stat_values["detail"].text = String(state.get("detail_text", "—"))
	stat_values["life"].text = String(state.get("life_text", "—"))
	stat_values["time"].text = String(state.get("time_text", "—"))
	if bool(state.get("capture_mode", false)):
		fps_value.text = "FPS · 录制"
	else:
		fps_value.text = "%d FPS" % int(state.get("fps", 0))
	var matched := bool(state.get("sig_match", false))
	var sig_text := String(state.get("signature", "—"))
	if bool(state.get("finished", false)):
		sig_status.text = ("签名 %s · 同种子一致 ✓" % sig_text) if matched else ("签名 %s · 新地图" % sig_text)
		sig_status.add_theme_color_override("font_color",
				UiTheme.MINT if matched else UiTheme.MUTED)
	else:
		sig_status.text = "签名 — · 生成中…"
		sig_status.add_theme_color_override("font_color", UiTheme.MUTED)
	for key in debug_checks:
		debug_checks[key].button_pressed = bool(state.get("debug", {}).get(key, false))
	for key in noise_buttons:
		noise_buttons[key].button_pressed = String(state.get("noise_field", "")) == key
	stream_label.text = String(state.get("streams_text", ""))
	_syncing = false


# ---------------------------------------------------------------------------
# 回调
# ---------------------------------------------------------------------------

func _on_seed_submitted(text: String) -> void:
	if not _syncing:
		main.ui_generate(text, size_option.selected, param_slider.value)


func _on_random() -> void:
	if not _syncing:
		main.ui_randomize()


func _on_generate() -> void:
	if not _syncing:
		main.ui_generate(seed_edit.text, size_option.selected, param_slider.value)


func _on_restart() -> void:
	if not _syncing:
		main.ui_restart()


func _on_size_selected(_index: int) -> void:
	if not _syncing:
		main.ui_generate(seed_edit.text, size_option.selected, param_slider.value)


func _on_param_changed(value: float) -> void:
	if _syncing:
		return
	param_value.text = _param_display(value)
	main.ui_param_changed(value)


func _on_param_drag_ended(value_changed: bool) -> void:
	if _syncing:
		return
	if value_changed:
		main.ui_apply_param()


func _param_display(value: float) -> String:
	if _mode == "biome":
		return "%+.2f" % (value / 100.0)
	return "%d%%" % int(round(value))


func _on_speed_changed(value: float) -> void:
	if not _syncing:
		main.set_speed(value)


func _on_pause() -> void:
	if not _syncing:
		main.ui_toggle_pause()


func _on_step() -> void:
	if not _syncing:
		main.ui_step()


func _on_finish() -> void:
	if not _syncing:
		main.ui_finish()


func _on_debug_toggled(pressed: bool, key: String) -> void:
	if not _syncing:
		main.ui_set_debug(key, pressed)


func _on_noise_field(field: String) -> void:
	if not _syncing:
		main.ui_set_noise_field(field)
