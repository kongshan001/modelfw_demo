extends PanelContainer

# 左侧控制/状态面板。中文 UI；所有控件由代码构建，便于 1280/1920 自适应。

const UiTheme = preload("res://scripts/ui_theme.gd")

var main = null
var ui_scale := 1.0

var seed_edit: LineEdit
var size_option: OptionButton
var speed_slider: HSlider
var speed_value: Label
var backtrack_check: CheckBox
var generate_button: Button
var restart_button: Button
var pause_button: Button
var step_button: Button
var progress_bar: ProgressBar
var progress_label: Label
var low_entropy_label: Label
var stat_values: Dictionary = {}
var event_labels: Array[Label] = []

var _syncing := false


func setup(main_node, scale_factor: float, size_options: Array) -> void:
	main = main_node
	ui_scale = scale_factor
	add_theme_stylebox_override("panel", UiTheme.panel_style(
		Color(0.075, 0.115, 0.080, 0.94), Color(0.28, 0.39, 0.27, 0.9), ui_scale, 8.0))
	_build(size_options)
	refresh()


func _build(size_options: Array) -> void:
	var root := VBoxContainer.new()
	root.name = "HudColumn"
	root.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	add_child(root)

	var head := HBoxContainer.new()
	root.add_child(head)
	var title := UiTheme.make_label("生成控制", 15.0, UiTheme.MINT, ui_scale)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var mark := UiTheme.make_label("WFC · 14 TILES", 8.5, UiTheme.MUTED, ui_scale)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(mark)

	# 种子
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	root.add_child(seed_row)
	var seed_label := UiTheme.make_label("种子", 12.0, UiTheme.MUTED, ui_scale)
	seed_label.custom_minimum_size = Vector2(42.0 * ui_scale, 0.0)
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.text = "2718"
	seed_edit.placeholder_text = "数字或文字"
	seed_edit.max_length = 24
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.custom_minimum_size = Vector2(0.0, 30.0 * ui_scale)
	seed_edit.add_theme_font_size_override("font_size", int(round(12.0 * ui_scale)))
	seed_edit.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(seed_edit)
	var random_button := _small_button("随机", 46.0 * ui_scale, 30.0 * ui_scale)
	random_button.pressed.connect(_on_random_seed)
	random_button.tooltip_text = "生成一个随机种子并立即生成（N）"
	seed_row.add_child(random_button)

	# 尺寸
	var size_row := HBoxContainer.new()
	size_row.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	root.add_child(size_row)
	var size_label := UiTheme.make_label("尺寸", 12.0, UiTheme.MUTED, ui_scale)
	size_label.custom_minimum_size = Vector2(42.0 * ui_scale, 0.0)
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_row.add_child(size_label)
	size_option = OptionButton.new()
	size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_option.custom_minimum_size = Vector2(0.0, 30.0 * ui_scale)
	size_option.add_theme_font_size_override("font_size", int(round(12.0 * ui_scale)))
	for option in size_options:
		size_option.add_item(String(option["label"]))
	var initial_size := 1 if size_options.size() > 1 else 0
	size_option.select(initial_size)
	size_option.item_selected.connect(_on_size_selected)
	size_row.add_child(size_option)

	# 速度
	var speed_row := HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	root.add_child(speed_row)
	var speed_label := UiTheme.make_label("速度", 12.0, UiTheme.MUTED, ui_scale)
	speed_label.custom_minimum_size = Vector2(42.0 * ui_scale, 0.0)
	speed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_label)
	speed_slider = HSlider.new()
	speed_slider.min_value = 1.0
	speed_slider.max_value = 40.0
	speed_slider.step = 1.0
	speed_slider.value = 20.0
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speed_slider.value_changed.connect(_on_speed_changed)
	speed_row.add_child(speed_slider)
	speed_value = UiTheme.make_label("20 步/秒", 10.5, UiTheme.AMBER, ui_scale)
	speed_value.custom_minimum_size = Vector2(58.0 * ui_scale, 0.0)
	speed_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	speed_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_row.add_child(speed_value)

	backtrack_check = CheckBox.new()
	backtrack_check.text = "允许回溯（快照回滚）"
	backtrack_check.button_pressed = true
	backtrack_check.add_theme_font_size_override("font_size", int(round(11.0 * ui_scale)))
	backtrack_check.toggled.connect(_on_backtrack_toggled)
	root.add_child(backtrack_check)

	var generate_row := HBoxContainer.new()
	generate_row.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	root.add_child(generate_row)
	generate_button = _button("生成地图", 32.0 * ui_scale)
	generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_primary(generate_button, ui_scale)
	generate_button.pressed.connect(_on_generate)
	generate_row.add_child(generate_button)
	restart_button = _button("重开", 32.0 * ui_scale)
	restart_button.custom_minimum_size = Vector2(76.0 * ui_scale, 32.0 * ui_scale)
	restart_button.pressed.connect(_on_restart)
	restart_button.tooltip_text = "同种子从第一格重新演示（R）"
	generate_row.add_child(restart_button)

	var run_row := HBoxContainer.new()
	run_row.add_theme_constant_override("separation", int(round(7.0 * ui_scale)))
	root.add_child(run_row)
	pause_button = _button("暂停", 31.0 * ui_scale)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.pressed.connect(_on_pause)
	run_row.add_child(pause_button)
	step_button = _button("单步", 31.0 * ui_scale)
	step_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step_button.pressed.connect(_on_step)
	step_button.tooltip_text = "暂停并前进一次坍缩（S）"
	run_row.add_child(step_button)

	root.add_child(UiTheme.divider(ui_scale))

	var status_head := HBoxContainer.new()
	root.add_child(status_head)
	var status_title := UiTheme.make_label("算法状态", 13.0, UiTheme.MINT, ui_scale)
	status_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_head.add_child(status_title)
	var elapsed := UiTheme.make_label("固定种子可复现", 8.5, UiTheme.MUTED, ui_scale)
	elapsed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_head.add_child(elapsed)

	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", int(round(5.0 * ui_scale)))
	root.add_child(stats_row)
	for item in [
		["collapsed", "坍缩"], ["propagations", "传播"],
		["backtracks", "回溯"], ["restarts", "重开"],
	]:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_constant_override("separation", 0)
		stats_row.add_child(card)
		var value := UiTheme.make_label("0", 16.0, UiTheme.AMBER, ui_scale)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(value)
		var caption := UiTheme.make_label(String(item[1]), 8.5, UiTheme.MUTED, ui_scale)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(caption)
		stat_values[String(item[0])] = value

	var progress_head := HBoxContainer.new()
	root.add_child(progress_head)
	var progress_title := UiTheme.make_label("坍缩进度", 10.0, UiTheme.MUTED, ui_scale)
	progress_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_head.add_child(progress_title)
	progress_label = UiTheme.make_label("0 / 0", 10.0, UiTheme.TEXT, ui_scale)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_head.add_child(progress_label)
	progress_bar = ProgressBar.new()
	progress_bar.show_percentage = false
	progress_bar.custom_minimum_size = Vector2(0.0, 6.0 * ui_scale)
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	root.add_child(progress_bar)
	low_entropy_label = UiTheme.make_label("下一个：—", 9.5, UiTheme.MUTED, ui_scale)
	root.add_child(low_entropy_label)

	root.add_child(UiTheme.divider(ui_scale))
	var event_head := HBoxContainer.new()
	root.add_child(event_head)
	var event_title := UiTheme.make_label("事件流", 12.0, UiTheme.MINT, ui_scale)
	event_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_head.add_child(event_title)
	var hint := UiTheme.make_label("最近 3 条", 8.5, UiTheme.MUTED, ui_scale)
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_head.add_child(hint)
	for i in 3:
		var line := UiTheme.make_label("—", 9.5, UiTheme.MUTED, ui_scale)
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.custom_minimum_size = Vector2(0.0, 16.0 * ui_scale)
		line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root.add_child(line)
		event_labels.append(line)

	root.add_child(UiTheme.divider(ui_scale))

	var legend_title := UiTheme.make_label("图例", 10.0, UiTheme.MUTED, ui_scale)
	root.add_child(legend_title)
	_add_legend_row(root, [
		[Color("#2b3c2f"), "熵低"], [Color("#744a34"), "熵高"],
		[UiTheme.MINT, "已坍缩"], [UiTheme.AMBER, "波前"], [UiTheme.CORAL, "冲突/回溯"],
	])

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.custom_minimum_size = Vector2(0.0, 2.0 * ui_scale)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(spacer)

	var keys := UiTheme.make_label(
			"空格 暂停/继续 · S 单步 · R 重开 · N 随机种子\nTab 切视图 · H 收起面板 · ↑↓ 调速",
			9.0, UiTheme.MUTED, ui_scale)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(keys)


func _add_legend_row(parent: VBoxContainer, items: Array) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(round(5.0 * ui_scale)))
	parent.add_child(row)
	for item in items:
		var swatch := ColorRect.new()
		swatch.color = item[0]
		swatch.custom_minimum_size = Vector2(8.0 * ui_scale, 8.0 * ui_scale)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(swatch)
		var label := UiTheme.make_label(String(item[1]), 8.3, UiTheme.MUTED, ui_scale)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(label)
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(1.0 * ui_scale, 0.0)
		row.add_child(gap)


func _small_button(text: String, min_width: float, min_height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, min_height)
	button.add_theme_font_size_override("font_size", int(round(11.0 * ui_scale)))
	return button


func _button(text: String, min_height: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, min_height)
	button.add_theme_font_size_override("font_size", int(round(12.0 * ui_scale)))
	return button


func refresh() -> void:
	if main == null:
		return
	var solver = main.get_solver()
	if solver == null:
		return
	_syncing = true
	if not seed_edit.has_focus() and seed_edit.text != main.get_seed_text():
		seed_edit.text = main.get_seed_text()
	if size_option.selected != main.get_size_index():
		size_option.select(main.get_size_index())
	if absf(speed_slider.value - main.get_speed()) > 0.01:
		speed_slider.set_value_no_signal(main.get_speed())
	speed_value.text = "%d 步/秒" % int(round(main.get_speed()))
	if backtrack_check.button_pressed != main.is_backtrack_enabled():
		backtrack_check.set_pressed_no_signal(main.is_backtrack_enabled())
	_syncing = false

	var collapsed: int = solver.collapsed_cells()
	var total: int = solver.cell_count()
	stat_values["collapsed"].text = "%d" % collapsed
	stat_values["propagations"].text = "%d" % solver.propagation_count
	stat_values["backtracks"].text = "%d" % solver.backtrack_count
	stat_values["restarts"].text = "%d" % solver.restart_count
	progress_label.text = "%d / %d" % [collapsed, total]
	progress_bar.max_value = float(total)
	progress_bar.value = float(collapsed)
	var low: Dictionary = solver.lowest_entropy_cell()
	var low_cell: Vector2i = low["cell"]
	if solver.finished:
		low_entropy_label.text = "已完成 · %s" % ("可切换成品地图" if not solver.failed else "生成失败")
	elif low_cell.x >= 0:
		low_entropy_label.text = "下一个：(%d,%d) · H %.2f · 候选 %d" % [
			low_cell.x, low_cell.y, float(low["entropy"]), int(low["count"])]
	else:
		low_entropy_label.text = "下一个：—"

	if solver.finished:
		pause_button.text = "已完成"
	elif main.is_paused() or not main.is_running():
		pause_button.text = "继续" if main.is_running() else "已暂停"
	else:
		pause_button.text = "暂停"
	pause_button.disabled = solver.finished
	step_button.disabled = solver.finished
	generate_button.disabled = false
	restart_button.disabled = false

	var events: Array[String] = main.get_event_log()
	for i in event_labels.size():
		var index := events.size() - 1 - i
		event_labels[i].text = events[index] if index >= 0 else "—"
		event_labels[i].add_theme_color_override("font_color",
				UiTheme.CORAL if "回溯" in event_labels[i].text or "矛盾" in event_labels[i].text
				else UiTheme.MUTED)


func _on_seed_submitted(_text: String) -> void:
	main.generate_from_ui()


func _on_random_seed() -> void:
	if _syncing or main == null:
		return
	main.randomize_seed_and_generate()


func _on_size_selected(index: int) -> void:
	if _syncing or main == null:
		return
	main.set_size_index_from_ui(index)


func _on_speed_changed(value: float) -> void:
	if _syncing or main == null:
		return
	main.set_speed(float(value))


func _on_backtrack_toggled(value: bool) -> void:
	if _syncing or main == null:
		return
	main.set_backtrack_from_ui(value)


func _on_generate() -> void:
	if main != null:
		main.generate_from_ui()


func _on_restart() -> void:
	if main != null:
		main.restart_from_ui()


func _on_pause() -> void:
	if main != null:
		main.toggle_pause()


func _on_step() -> void:
	if main != null:
		main.step_from_ui()
