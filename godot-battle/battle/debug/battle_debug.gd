extends Node

# 调试单例（project autoload `BattleDebug`）。
# 只在 debug 构建启用；headless 下安全：不截图、不依赖窗口，核心测试无 session 时保持惰性。

var session: BattleSession = null
var pending_replay_path := ""

var _last_verify: Dictionary = {}
var _console = null
var _overlay = null
var _step_count := 0

func _ready() -> void:
	set_process_unhandled_input(true)

# ---------------------------------------------------------------- session

func register_session(p_session: BattleSession) -> void:
	_free_ui()
	session = p_session
	if not _debug_enabled():
		return
	_ensure_ui()
	print("DEBUG_READY: F1 console / F3 overlay / F6 step mode / F7 step once")

func _free_ui() -> void:
	if _console != null and is_instance_valid(_console):
		_console.queue_free()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_console = null
	_overlay = null

func _debug_enabled() -> bool:
	return OS.is_debug_build()

func _sequencer() -> BattleSequencer:
	if session != null and is_instance_valid(session):
		return session.sequencer
	return null

# ---------------------------------------------------------------- replay dump / replay

func dump_replay() -> String:
	if session == null or not is_instance_valid(session) or session.engine == null:
		print("DUMP_FAIL: 没有活动战斗")
		return ""
	var path := session.engine.dump_replay()
	if path.is_empty():
		print("DUMP_FAIL: 引擎无录像记录器")
		return ""
	print("REPLAY_PATH: " + ProjectSettings.globalize_path(path))
	_capture_screenshot(path.get_basename() + ".png")
	return path

func replay(path: String) -> bool:
	if not _debug_enabled():
		print("REPLAY_DISABLED: release build")
		return false
	path = _clean_path(path)
	if path.is_empty():
		print("REPLAY_FAIL: 缺少录像路径")
		return false
	if not FileAccess.file_exists(path):
		print("REPLAY_FAIL: 文件不存在 " + path)
		return false
	var data := BattleReplay.load_file(path)
	if data.is_empty():
		print("REPLAY_FAIL: 无法解析 " + path)
		return false
	var content := ContentDB.load_all()
	var result := BattleReplay.verify(data, content, false)
	_last_verify = result
	for warning in result["warnings"]:
		print("REPLAY_WARN " + String(warning))
	if not bool(result["ok"]):
		for error in result["errors"]:
			print("REPLAY_FAIL " + String(error))
		var divergence: Dictionary = result["first_divergence"]
		if not divergence.is_empty():
			print("REPLAY_DIVERGENCE " + JSON.stringify(divergence, "  ", true))
		return false
	print("REPLAY_OK " + path)
	pending_replay_path = path
	_close_for_scene_change()
	if get_tree() != null and get_tree().current_scene != null:
		var error := get_tree().reload_current_scene()
		if error != OK:
			print("REPLAY_PENDING: reload failed (%d), 等待下一次 BattleSession.start" % error)
	else:
		print("REPLAY_PENDING " + path + "（无 current_scene，等待下一次 BattleSession.start）")
	return true

func consume_pending_replay() -> String:
	var path := pending_replay_path
	pending_replay_path = ""
	return path

func last_verify_result() -> Dictionary:
	return _last_verify

func exit_replay() -> void:
	print("REPLAY_EXIT")
	pending_replay_path = ""
	if get_tree() != null and get_tree().current_scene != null:
		get_tree().reload_current_scene()

# ---------------------------------------------------------------- toggles

func toggle_console() -> void:
	if not _debug_enabled():
		return
	_ensure_ui()
	if _console == null or not is_instance_valid(_console):
		return
	_console.call("toggle")

func toggle_overlay() -> void:
	if not _debug_enabled():
		return
	_ensure_ui()
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.call("toggle")

func step_toggle() -> void:
	var sequencer := _sequencer()
	if sequencer == null:
		print("STEP_MODE unavailable: 没有活动战斗")
		return
	var enabled := not sequencer.is_step_mode()
	sequencer.set_step_mode(enabled)
	if not enabled:
		# 释放正在等待单步的播放循环。
		sequencer.request_step()
	print("STEP_MODE " + ("on" if enabled else "off"))

func step_once() -> void:
	var sequencer := _sequencer()
	if sequencer == null:
		print("STEP unavailable: 没有活动战斗")
		return
	if not sequencer.is_step_mode():
		sequencer.set_step_mode(true)
	_step_count += 1
	sequencer.request_step()
	print("STEP #%d" % _step_count)

func timescale(value: float) -> void:
	var speed := clampf(value, 0.1, 100.0)
	var sequencer := _sequencer()
	if sequencer != null:
		# ctx.wait 已按 playback_speed 缩放；再改 Engine.time_scale 会双重加速。
		sequencer.playback_speed = speed
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = speed
	print("TIMESCALE %.2fx" % speed)

# ---------------------------------------------------------------- state text

func state_text() -> String:
	if session == null or not is_instance_valid(session) or session.engine == null:
		return "没有活动战斗"
	var engine := session.engine
	var state := engine.state
	var lines: Array[String] = []
	lines.append("seed=%d round=%d outcome=%s" % [engine.seed_value, state.round, _outcome_name(state.outcome)])
	lines.append("items={" + _items_text(state) + "}")
	var sequencer := _sequencer()
	if sequencer != null:
		lines.append("speed=%.2fx step=%s queue=%d playing=%s" % [
			sequencer.playback_speed, str(sequencer.is_step_mode()), sequencer.queue_size(), str(sequencer.is_playing()),
		])
	for unit in state.units:
		lines.append("%s %s hp=%d/%d mp=%d/%d alive=%s statuses=[%s]" % [
			_side_name(unit.side), String(unit.id), unit.hp, unit.data.max_hp, unit.mp, unit.data.max_mp,
			str(unit.is_alive()), _status_text(unit),
		])
	lines.append("rng=BattleRng(seed=%d state=%d)" % [engine.seed_value, engine.rng.state()])
	return "\n".join(lines)

func fuzz(count: int = 10) -> void:
	print("FUZZ: 核心随机 fuzz 在 tests/cases/test_fuzz.gd（默认 50 局），运行 bash tools/run_tests.sh；本次请求 %d 局。" % count)

# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not _debug_enabled():
		return
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_F1:
			toggle_console()
			get_viewport().set_input_as_handled()
		KEY_F3:
			toggle_overlay()
			get_viewport().set_input_as_handled()
		KEY_F6:
			step_toggle()
			get_viewport().set_input_as_handled()
		KEY_F7:
			step_once()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if _console != null and is_instance_valid(_console) and _console.visible:
				_console.call("close")
				get_viewport().set_input_as_handled()
			elif session != null and is_instance_valid(session) and session.replay_mode:
				exit_replay()
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- ui

func _ensure_ui() -> void:
	if not _debug_enabled():
		return
	if session == null or not is_instance_valid(session):
		return
	var ctx := session.context
	if ctx == null or ctx.ui_layer == null or not is_instance_valid(ctx.ui_layer):
		return
	if _console == null or not is_instance_valid(_console) or _console.get_parent() != ctx.ui_layer:
		if _console != null and is_instance_valid(_console):
			_console.queue_free()
		var console_script: Script = load("res://ui/debug/debug_console.gd")
		if console_script != null:
			_console = console_script.new()
			_console.name = "DebugConsole"
			ctx.ui_layer.add_child(_console)
	if _overlay == null or not is_instance_valid(_overlay) or _overlay.get_parent() != ctx.ui_layer:
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.queue_free()
		var overlay_script: Script = load("res://ui/debug/debug_overlay.gd")
		if overlay_script != null:
			_overlay = overlay_script.new()
			_overlay.name = "DebugOverlay"
			ctx.ui_layer.add_child(_overlay)

func _close_for_scene_change() -> void:
	if _console != null and is_instance_valid(_console) and _console.visible:
		_console.call("close")
	if _overlay != null and is_instance_valid(_overlay) and _overlay.visible:
		_overlay.call("close")

func _capture_screenshot(png_path: String) -> void:
	if not _debug_enabled():
		return
	if DisplayServer.get_name() == "headless":
		print("REPLAY_SCREENSHOT_SKIPPED: headless")
		return
	var viewport := get_viewport()
	if viewport == null:
		return
	var texture := viewport.get_texture()
	if texture == null:
		print("REPLAY_SCREENSHOT_SKIPPED: 无视口纹理")
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		print("REPLAY_SCREENSHOT_SKIPPED: 空图像")
		return
	var error := image.save_png(png_path)
	if error == OK:
		print("REPLAY_SCREENSHOT: " + ProjectSettings.globalize_path(png_path))
	else:
		print("REPLAY_SCREENSHOT_FAIL: %d %s" % [error, png_path])

# ---------------------------------------------------------------- helpers

func _clean_path(path: String) -> String:
	var cleaned := path.strip_edges()
	if cleaned.begins_with("\"") and cleaned.ends_with("\"") and cleaned.length() >= 2:
		cleaned = cleaned.substr(1, cleaned.length() - 2)
	return cleaned

func _items_text(state: BattleState) -> String:
	var keys: Array = state.item_uses.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%d" % [String(key), int(state.item_uses[key])])
	return ", ".join(parts)

func _status_text(unit: BattleUnitState) -> String:
	var parts: Array[String] = []
	for status in unit.statuses:
		parts.append("%s:%d" % [String(status.data.id), status.remaining])
	return ", ".join(parts)

func _side_name(side: int) -> String:
	return "ALLY" if side == BattleTypes.Side.ALLY else "ENEMY"

func _outcome_name(outcome: int) -> String:
	match outcome:
		BattleTypes.Outcome.VICTORY:
			return "VICTORY"
		BattleTypes.Outcome.DEFEAT:
			return "DEFEAT"
		BattleTypes.Outcome.ESCAPED:
			return "ESCAPED"
		_:
			return "NONE"
