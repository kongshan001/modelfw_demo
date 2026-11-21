extends Control

# 主控：搭 UI、创建求解器、按速度推进、把事件送给棋盘与状态面板。
# 视图：算法视图（候选/熵/波前）与成品地图；同种子严格复现同一张图。

const SolverScript = preload("res://scripts/wfc_solver.gd")
const BoardViewScript = preload("res://scripts/board_view.gd")
const BackdropScript = preload("res://scripts/backdrop.gd")
const HudScript = preload("res://scripts/hud.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const Tiles = preload("res://scripts/wfc_tileset.gd")

const SIZE_OPTIONS := [
	{"label": "12 × 8 · 小品", "cols": 12, "rows": 8},
	{"label": "16 × 10 · 标准", "cols": 16, "rows": 10},
	{"label": "18 × 10 · 大图", "cols": 18, "rows": 10},
]
const DEFAULT_SEED := "2718"
const DEFAULT_SIZE_INDEX := 1
const DEFAULT_SPEED := 20.0
const MAX_EVENT_LINES := 24

var solver = null
var board = null
var hud = null

var _seed_text := DEFAULT_SEED
var _size_index := DEFAULT_SIZE_INDEX
var _speed := DEFAULT_SPEED
var _backtrack_enabled := true
var _paused := false
var _running := false
var _elapsed := 0.0
var _accum := 0.0
var _refresh_accum := 0.0
var _ui_scale := 1.0
var _view_mode := "algo"
var _event_log: Array[String] = []
var _last_event: Dictionary = {}
var _status_message := "准备坍缩。"
var _ui_visible := true

var _backdrop: Control
var _main_margin: MarginContainer
var _topbar: HBoxContainer
var _content: HBoxContainer
var _right_column: VBoxContainer
var _hud_panel: PanelContainer
var _board_panel: PanelContainer
var _footer: PanelContainer
var _status_label: Label
var _meta_label: Label
var _view_buttons: Dictionary = {}
var _view_group: ButtonGroup
var _started := false


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	var layout_size := size
	if layout_size.x < 10.0 or layout_size.y < 10.0:
		layout_size = viewport_size
	_ui_scale = clampf(minf(layout_size.x / 1280.0, layout_size.y / 720.0), 0.78, 2.0)
	theme = UiTheme.make_theme(_ui_scale)
	_build_layout()
	_start_new_generation(_seed_text, 16, 10, true, true)
	_started = true
	set_process(true)


func _build_layout() -> void:
	_backdrop = BackdropScript.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_main_margin = MarginContainer.new()
	_main_margin.name = "MainMargin"
	_main_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := int(round(18.0 * _ui_scale))
	_main_margin.add_theme_constant_override("margin_left", margin)
	_main_margin.add_theme_constant_override("margin_right", margin)
	_main_margin.add_theme_constant_override("margin_top", margin)
	_main_margin.add_theme_constant_override("margin_bottom", margin)
	add_child(_main_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", int(round(10.0 * _ui_scale)))
	_main_margin.add_child(page)

	_topbar = HBoxContainer.new()
	_topbar.custom_minimum_size = Vector2(0.0, 50.0 * _ui_scale)
	_topbar.add_theme_constant_override("separation", int(round(12.0 * _ui_scale)))
	page.add_child(_topbar)
	_build_topbar()

	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", int(round(14.0 * _ui_scale)))
	page.add_child(_content)

	_hud_panel = HudScript.new()
	_hud_panel.name = "HUD"
	_hud_panel.custom_minimum_size = Vector2(292.0 * _ui_scale, 0.0)
	_hud_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_hud_panel)
	_hud_panel.setup(self, _ui_scale, SIZE_OPTIONS)
	hud = _hud_panel

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", int(round(8.0 * _ui_scale)))
	_content.add_child(_right_column)

	_board_panel = PanelContainer.new()
	_board_panel.name = "BoardFrame"
	_board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board_panel.add_theme_stylebox_override("panel", UiTheme.map_panel_style(_ui_scale))
	_right_column.add_child(_board_panel)

	board = BoardViewScript.new()
	board.name = "BoardView"
	board.ui_scale = _ui_scale
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(600.0 * _ui_scale, 400.0 * _ui_scale)
	_board_panel.add_child(board)

	_footer = PanelContainer.new()
	_footer.name = "Footer"
	_footer.custom_minimum_size = Vector2(0.0, 32.0 * _ui_scale)
	_footer.add_theme_stylebox_override("panel", UiTheme.footer_style(_ui_scale))
	_right_column.add_child(_footer)
	var foot_row := HBoxContainer.new()
	foot_row.add_theme_constant_override("separation", int(round(9.0 * _ui_scale)))
	_footer.add_child(foot_row)
	var dot := ColorRect.new()
	dot.color = UiTheme.AMBER
	dot.custom_minimum_size = Vector2(7.0 * _ui_scale, 7.0 * _ui_scale)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot_row.add_child(dot)
	_status_label = UiTheme.make_label(_status_message, 10.5, UiTheme.TEXT, _ui_scale)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot_row.add_child(_status_label)
	_meta_label = UiTheme.make_label("SEED —", 9.0, UiTheme.MUTED, _ui_scale)
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot_row.add_child(_meta_label)


func _build_topbar() -> void:
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_topbar.add_child(titles)
	var title := UiTheme.make_label("坍缩花园", 24.0, UiTheme.TEXT, _ui_scale)
	titles.add_child(title)
	var subtitle := UiTheme.make_label(
			"WAVE FUNCTION COLLAPSE  ·  原创程序化庭院瓦片  ·  权重熵 / 约束传播 / 快照回溯",
			9.5, UiTheme.MUTED, _ui_scale)
	titles.add_child(subtitle)

	var view_label := UiTheme.make_label("视图", 10.0, UiTheme.MUTED, _ui_scale)
	view_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_topbar.add_child(view_label)
	_view_group = ButtonGroup.new()
	for item in [["algo", "算法视图"], ["map", "成品地图"]]:
		var button := Button.new()
		button.text = String(item[1])
		button.toggle_mode = true
		button.button_group = _view_group
		button.button_pressed = String(item[0]) == _view_mode
		button.custom_minimum_size = Vector2(100.0 * _ui_scale, 31.0 * _ui_scale)
		button.add_theme_font_size_override("font_size", int(round(11.5 * _ui_scale)))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_view_button.bind(String(item[0])))
		_topbar.add_child(button)
		_view_buttons[String(item[0])] = button

	var divider := ColorRect.new()
	divider.color = Color(0.39, 0.51, 0.37, 0.32)
	divider.custom_minimum_size = Vector2(1.0 * _ui_scale, 26.0 * _ui_scale)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_topbar.add_child(divider)
	var mode := UiTheme.make_label("固定种子\n确定性输出", 8.6, UiTheme.MUTED, _ui_scale)
	mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_topbar.add_child(mode)


func _process(delta: float) -> void:
	if not _started or solver == null:
		return
	if _running and not _paused and not solver.finished:
		_elapsed += delta
		_accum += delta
		var interval := 1.0 / maxf(1.0, _speed)
		var budget := 0
		while _accum >= interval and budget < 8:
			_advance_one()
			_accum -= interval
			budget += 1
			if solver.finished:
				break
	else:
		_accum = 0.0

	_refresh_accum += delta
	if _refresh_accum >= 0.15:
		_refresh_accum = 0.0
		if hud != null and hud.visible:
			hud.refresh()
		if _footer != null and _footer.visible:
			_update_footer()


func _advance_one() -> void:
	if solver == null or solver.finished:
		return
	var event: Dictionary = solver.step()
	_last_event = event
	if board != null:
		board.mark_event(event)
	_log_event(event)
	if solver.finished:
		_running = false
		_paused = true
		if solver.failed:
			_status_message = "生成失败：请换一个种子，或开启回溯。"
		else:
			_status_message = "完成 · %d 格 · %.1f 秒 · 回溯 %d · 重开 %d · 按 Tab 查看成品地图" % [
				solver.cell_count(), _elapsed, solver.backtrack_count, solver.restart_count]
			_event_log.append("%s · 完成 %d 格" % [_time_stamp(), solver.cell_count()])
		_trim_events()
		if hud != null:
			hud.refresh()
		_update_footer()


func _log_event(event: Dictionary) -> void:
	var kind := String(event.get("event", ""))
	var target: Vector2i = event.get("target", Vector2i(-1, -1))
	var tile := int(event.get("tile", -1))
	var wave = event.get("wave", PackedInt32Array())
	var message := ""
	match kind:
		"collapse":
			message = "%s · 坍缩 (%d,%d) → %s" % [
				_time_stamp(), target.x, target.y, Tiles.name_of(tile)]
			if wave.size() > 0:
				message += " · 传播 %d 格" % wave.size()
			_status_message = "坍缩 (%d,%d) → %s · 波前 %d 格" % [
				target.x, target.y, Tiles.name_of(tile), wave.size()]
		"backtrack":
			message = "%s · 矛盾 @(%d,%d) → 回溯到 (%d,%d)" % [
				_time_stamp(), solver.last_conflict_cell.x, solver.last_conflict_cell.y,
				solver.last_backtrack_cell.x, solver.last_backtrack_cell.y]
			_status_message = "矛盾：候选耗尽 → 撤销快照，改选剩余瓦片"
		"restart":
			message = "%s · 回溯预算耗尽 → 自动重开 #%d" % [
				_time_stamp(), solver.attempt]
			_status_message = "无解路径 → 自动重开（仍使用同一基础种子，确定性重试）"
		"failed":
			message = "%s · 生成失败" % _time_stamp()
			_status_message = "生成失败：已达到重开上限。"
		"done":
			message = "%s · 全部坍缩" % _time_stamp()
	_event_log.append(message if not message.is_empty() else "%s · %s" % [_time_stamp(), kind])
	_trim_events()


func _trim_events() -> void:
	while _event_log.size() > MAX_EVENT_LINES:
		_event_log.pop_front()


func _time_stamp() -> String:
	return "%05.1fs" % _elapsed


func _update_footer() -> void:
	if _status_label == null or solver == null:
		return
	_status_label.text = _status_message
	var size_label: String = SIZE_OPTIONS[_size_index]["label"]
	_meta_label.text = "SEED %s  ·  %s  ·  回溯 %s" % [
		_seed_text, size_label, "开" if _backtrack_enabled else "关"]


func _on_view_button(mode: String) -> void:
	set_view_mode(mode)


func set_view_mode(mode: String) -> void:
	if mode not in ["algo", "map"]:
		return
	_view_mode = mode
	if board != null:
		board.set_view_mode(mode)
	for key in _view_buttons:
		var button: Button = _view_buttons[key]
		button.set_pressed_no_signal(String(key) == mode)
	if mode == "map" and solver != null:
		_status_message = "成品地图 · 悬停查看瓦片 / 按 Tab 回到算法视图"
	else:
		_status_message = "算法视图 · 每格叠加态、熵热力与传播波前"
	_update_footer()


func _on_view_toggle() -> void:
	set_view_mode("map" if _view_mode == "algo" else "algo")


# ── 对外控制（HUD / 键盘 / 验收工具共用） ───────────────────────────────

func generate_from_ui() -> void:
	if hud == null:
		return
	var seed_value: String = hud.seed_edit.text.strip_edges()
	if seed_value.is_empty():
		seed_value = DEFAULT_SEED
		hud.seed_edit.text = seed_value
	_speed = hud.speed_slider.value
	_size_index = hud.size_option.selected
	_backtrack_enabled = hud.backtrack_check.button_pressed
	var size: Dictionary = SIZE_OPTIONS[_size_index]
	_start_new_generation(seed_value, int(size["cols"]), int(size["rows"]),
			_backtrack_enabled, true)


func restart_from_ui() -> void:
	if hud == null:
		return
	var seed_value: String = hud.seed_edit.text.strip_edges()
	if seed_value.is_empty():
		seed_value = DEFAULT_SEED
	_speed = hud.speed_slider.value
	_size_index = hud.size_option.selected
	_backtrack_enabled = hud.backtrack_check.button_pressed
	var size: Dictionary = SIZE_OPTIONS[_size_index]
	_start_new_generation(seed_value, int(size["cols"]), int(size["rows"]),
			_backtrack_enabled, true)


func randomize_seed_and_generate() -> void:
	if hud == null:
		return
	var new_seed := randi_range(100000, 999999)
	hud.seed_edit.text = str(new_seed)
	generate_from_ui()


func set_size_index_from_ui(index: int) -> void:
	if index < 0 or index >= SIZE_OPTIONS.size():
		return
	_size_index = index
	generate_from_ui()


func set_speed(value: float) -> void:
	_speed = clampf(value, 1.0, 40.0)
	_accum = 0.0


func set_backtrack_from_ui(value: bool) -> void:
	_backtrack_enabled = value
	if solver != null:
		solver.backtrack_enabled = value
	_status_message = "回溯已%s · 之后的矛盾将%s" % [
		"开启" if value else "关闭", "尝试撤销快照" if value else "触发自动重开"]
	_update_footer()


func toggle_pause() -> void:
	if solver == null or solver.finished:
		return
	_paused = not _paused
	_status_message = "已暂停 · 可单步观察传播" if _paused else "继续运行 · %.1f 步/秒" % _speed
	_update_footer()
	if hud != null:
		hud.refresh()


func step_from_ui() -> void:
	if solver == null or solver.finished:
		return
	_paused = true
	_running = true
	_elapsed += 1.0 / maxf(1.0, _speed)
	_advance_one()
	if hud != null:
		hud.refresh()


func step_once() -> void:
	step_from_ui()


func _start_new_generation(seed_text: String, cols: int, rows: int,
		backtrack: bool, auto_start: bool) -> void:
	_seed_text = seed_text
	_backtrack_enabled = backtrack
	_speed = clampf(_speed, 1.0, 40.0)
	solver = SolverScript.new()
	solver.setup(_seed_text, cols, rows, backtrack)
	_elapsed = 0.0
	_accum = 0.0
	_event_log.clear()
	_last_event = {"event": "ready"}
	_running = auto_start
	_paused = not auto_start
	_view_mode = "algo"
	if board != null:
		board.set_solver(solver)
		board.set_view_mode("algo")
	if hud != null:
		hud.seed_edit.text = _seed_text
		hud.refresh()
	set_view_mode("algo")
	_status_message = "开始坍缩 · 种子 %s · %d × %d · 每格 14 种可能" % [
		_seed_text, cols, rows]
	_event_log.append("00.0s · 初始化 %d×%d · 每格 %d 种候选" % [cols, rows, Tiles.TILE_COUNT])
	_update_footer()


func _input(event: InputEvent) -> void:
	if not _started or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit and key.keycode != KEY_ESCAPE:
		return
	match key.keycode:
		KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_S:
			step_from_ui()
			get_viewport().set_input_as_handled()
		KEY_R:
			restart_from_ui()
			get_viewport().set_input_as_handled()
		KEY_N:
			randomize_seed_and_generate()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			_on_view_toggle()
			get_viewport().set_input_as_handled()
		KEY_H:
			_toggle_hud_panel()
			get_viewport().set_input_as_handled()
		KEY_B:
			if hud != null:
				hud.backtrack_check.button_pressed = not hud.backtrack_check.button_pressed
			get_viewport().set_input_as_handled()
		KEY_UP:
			_change_speed(2.0)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_change_speed(-2.0)
			get_viewport().set_input_as_handled()


func _change_speed(delta: float) -> void:
	set_speed(_speed + delta)
	if hud != null:
		hud.speed_slider.set_value_no_signal(_speed)
		hud.refresh()


func _toggle_hud_panel() -> void:
	_ui_visible = not _ui_visible
	if _hud_panel != null:
		_hud_panel.visible = _ui_visible
	if _topbar != null:
		_topbar.visible = _ui_visible
	_update_footer()


# ── 验收/截图工具接口 ────────────────────────────────────────────────

func get_solver():
	return solver


func get_board():
	return board


func get_seed_text() -> String:
	return _seed_text


func get_size_index() -> int:
	return _size_index


func get_speed() -> float:
	return _speed


func get_view_mode() -> String:
	return _view_mode


func is_backtrack_enabled() -> bool:
	return _backtrack_enabled


func is_paused() -> bool:
	return _paused


func is_running() -> bool:
	return _running


func get_event_log() -> Array[String]:
	return _event_log


func get_last_event() -> Dictionary:
	return _last_event


func set_ui_visible(value: bool) -> void:
	if _hud_panel != null:
		_hud_panel.visible = value
	if _topbar != null:
		_topbar.visible = value
	if _footer != null:
		_footer.visible = value
	_ui_visible = value


func new_map(seed_text: String, columns: int, rows: int,
		allow_backtrack: bool = true, auto_start: bool = false) -> void:
	var index := 1
	for i in SIZE_OPTIONS.size():
		if int(SIZE_OPTIONS[i]["cols"]) == columns and int(SIZE_OPTIONS[i]["rows"]) == rows:
			index = i
			break
	_size_index = index
	_seed_text = seed_text
	if hud != null:
		hud.seed_edit.text = seed_text
		hud.size_option.select(index)
		hud.backtrack_check.set_pressed_no_signal(allow_backtrack)
	_start_new_generation(seed_text, columns, rows, allow_backtrack, auto_start)


func set_speed_value(value: float) -> void:
	set_speed(value)
	if hud != null:
		hud.speed_slider.set_value_no_signal(_speed)
		hud.refresh()


func set_paused(value: bool) -> void:
	_paused = value
	if hud != null:
		hud.refresh()
	_update_footer()


func finish_now() -> void:
	if solver == null:
		return
	_paused = true
	_running = false
	if not solver.finished:
		solver.generate_full()
		if board != null:
			var event := {"event": "done" if not solver.failed else "failed",
					"target": solver.last_target, "tile": solver.last_tile,
					"wave": PackedInt32Array()}
			board.mark_event(event)
			_last_event = event
	_elapsed = maxf(_elapsed, 0.0)
	if solver.failed:
		_status_message = "生成失败：请换一个种子，或开启回溯。"
	else:
		_status_message = "完成 · %d 格 · 回溯 %d · 重开 %d · 按 Tab 查看成品地图" % [
			solver.cell_count(), solver.backtrack_count, solver.restart_count]
	if hud != null:
		hud.refresh()
	_update_footer()
