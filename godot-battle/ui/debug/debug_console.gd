extends CanvasLayer

# F1 调试控制台。仅 debug 构建由 BattleDebug 创建；命令直接作用于当前 BattleSession。
# 调试操作 kill / set_hp / add_status 统一走 engine.apply_debug_op，保证写入录像。

const HELP := "命令：dump | replay <path> | seed | state | step [on|off] | step | timescale <n> | kill <id> | set_hp <id> <n> | add_status <id> <status> | validate | skip"

var _panel: PanelContainer
var _output: RichTextLabel
var _input: LineEdit
var _debug: Node = null
var _lines: Array[String] = []

func _ready() -> void:
	layer = 128
	visible = false
	_debug = get_node_or_null("/root/BattleDebug")
	_build()
	_append("[color=#8fd3ff][b]战斗调试控制台[/b][/color]  F1 / ESC 关闭")
	_append("[color=#9aa4b2]%s[/color]" % HELP)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_refresh_output()
	if _input != null:
		_input.grab_focus()

func close() -> void:
	visible = false
	if _input != null:
		_input.release_focus()

func is_open() -> bool:
	return visible

func execute_command(line: String) -> void:
	var text := line.strip_edges()
	if text.is_empty():
		return
	if _output == null:
		return
	_append("[color=#ffd54a]> %s[/color]" % _escape(text))
	var result := _run(text)
	if not result.is_empty():
		_append(_escape(result))

# ---------------------------------------------------------------- commands

func _run(line: String) -> String:
	var parts := line.split(" ", false)
	if parts.is_empty():
		return ""
	var command := String(parts[0]).to_lower()
	match command:
		"help":
			return HELP
		"dump":
			if _debug == null:
				return "BattleDebug 不可用"
			var path: String = _debug.dump_replay()
			return "已保存：" + path if not path.is_empty() else "dump 失败"
		"replay":
			if _debug == null:
				return "BattleDebug 不可用"
			var replay_path := line.substr(6).strip_edges()
			if replay_path.is_empty():
				return "用法：replay <path>"
			var ok: bool = _debug.replay(replay_path)
			if ok:
				return "回放校验通过，正在重载场景…"
			var divergence: Dictionary = _debug.last_verify_result().get("first_divergence", {})
			return "回放失败：" + (JSON.stringify(divergence, " ", true) if not divergence.is_empty() else "见控制台输出")
		"seed":
			var engine := _engine()
			if engine == null:
				return "没有活动战斗"
			return "seed=%d  replay=%s" % [engine.seed_value, str(_is_replay())]
		"state":
			if _debug == null:
				return "BattleDebug 不可用"
			return String(_debug.state_text())
		"step":
			if _debug == null:
				return "BattleDebug 不可用"
			if parts.size() >= 2:
				var value := String(parts[1]).to_lower()
				var sequencer := _sequencer()
				if sequencer == null:
					return "没有活动战斗"
				if value == "on":
					sequencer.set_step_mode(true)
					return "单步模式 on（F7 / step 前进）"
				if value == "off":
					sequencer.set_step_mode(false)
					sequencer.request_step()
					return "单步模式 off"
				return "用法：step on|off 或 step（单步一次）"
			_debug.step_once()
			return "已请求单步"
		"timescale":
			if parts.size() < 2 or not String(parts[1]).is_valid_float():
				return "用法：timescale <n>"
			if _debug == null:
				return "BattleDebug 不可用"
			_debug.timescale(float(parts[1]))
			return "timescale = %s" % String(parts[1])
		"kill":
			if parts.size() < 2:
				return "用法：kill <unit_id>"
			return _apply_op({"op": "kill", "unit_id": String(parts[1])})
		"set_hp":
			if parts.size() < 3 or not String(parts[2]).is_valid_int():
				return "用法：set_hp <unit_id> <hp>"
			return _apply_op({"op": "set_hp", "unit_id": String(parts[1]), "hp": int(parts[2])})
		"add_status":
			if parts.size() < 3:
				return "用法：add_status <unit_id> <status_id>"
			return _apply_op({"op": "add_status", "unit_id": String(parts[1]), "status_id": String(parts[2])})
		"validate":
			var state_engine := _engine()
			if state_engine == null:
				return "没有活动战斗"
			var issues := BattleInvariants.check(state_engine.state)
			if issues.is_empty():
				return "VALIDATE_OK：不变量通过"
			return "VALIDATE_FAIL：\n- " + "\n- ".join(issues)
		"skip":
			var sequencer := _sequencer()
			if sequencer == null:
				return "没有活动战斗"
			sequencer.skip_all()
			return "已跳过当前播放"
		_:
			return "未知命令：%s（help 查看帮助）" % command

func _apply_op(op: Dictionary) -> String:
	var engine := _engine()
	if engine == null:
		return "没有活动战斗"
	var unit_id := StringName(op.get("unit_id", ""))
	if engine.state.get_unit(unit_id) == null:
		return "未知单位：" + String(unit_id)
	if String(op.get("op", "")) == "add_status":
		var status_id := StringName(op.get("status_id", ""))
		var status_session := _session()
		if status_session == null or status_session.content == null or status_session.content.get_status(status_id) == null:
			return "未知状态：" + String(status_id)
	engine.apply_debug_op(op)
	var active_session := _session()
	if active_session != null and active_session.context != null:
		active_session.context.apply_snapshot(engine.state)
	return "OK " + JSON.stringify(op)

# ---------------------------------------------------------------- helpers

func _session() -> BattleSession:
	if _debug == null:
		return null
	var current = _debug.session
	if current == null or not is_instance_valid(current):
		return null
	return current

func _engine() -> BattleEngine:
	var session := _session()
	if session == null:
		return null
	return session.engine

func _sequencer() -> BattleSequencer:
	var session := _session()
	if session == null:
		return null
	return session.sequencer

func _is_replay() -> bool:
	var session := _session()
	return session != null and session.replay_mode

func _append(text: String) -> void:
	_lines.append(text)
	while _lines.size() > 240:
		_lines.pop_front()
	_refresh_output()

func _refresh_output() -> void:
	if _output != null:
		_output.text = "\n".join(_lines)

func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

func _on_submit(text: String) -> void:
	if _input != null:
		_input.clear()
	execute_command(text)

# ---------------------------------------------------------------- build

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "ConsolePanel"
	_panel.position = Vector2(24, 470)
	_panel.size = Vector2(920, 500)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.88)
	style.border_color = Color(0.32, 0.72, 0.92, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 12
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)

	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.custom_minimum_size = Vector2(0, 400)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_font_override("normal_font", FontUtil.cjk_font())
	_output.add_theme_font_override("bold_font", FontUtil.cjk_font())
	_output.add_theme_font_size_override("normal_font_size", 17)
	_output.add_theme_font_size_override("bold_font_size", 17)
	box.add_child(_output)

	_input = LineEdit.new()
	_input.name = "ConsoleInput"
	_input.placeholder_text = "输入命令，回车执行（help 查看帮助）"
	_input.clear_button_enabled = true
	_input.add_theme_font_override("font", FontUtil.cjk_font())
	_input.add_theme_font_size_override("font_size", 19)
	_input.text_submitted.connect(_on_submit)
	box.add_child(_input)
