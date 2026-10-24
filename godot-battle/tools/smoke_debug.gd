extends SceneTree

# 调试工具冒烟（headless）：
# 1) 加载战斗场景 auto 一局 → BattleDebug.dump_replay()
# 2) 正常录像校验通过；篡改 snapshot → 以 snapshot_mismatch 失败
# 3) 设置 pending replay，再次加载场景进入回放模式，播放 2 个完整回合
# 用法：godot --headless --path godot-battle -s tools/smoke_debug.gd

const BATTLE_TIMEOUT_MS := 180000
const REPLAY_TIMEOUT_MS := 120000
const FAST_PLAYBACK := 500.0

var _debug: Node

func _initialize() -> void:
	await _run()

func _run() -> void:
	_debug = root.get_node_or_null("BattleDebug")
	if _debug == null:
		_fail("autoload BattleDebug missing")
		return
	var content := ContentDB.load_all()

	# 1) 真实场景自动打一局，使用场景 session 的录像器 dump。
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.start_auto_mode = true
	scene.skip_story = true
	root.add_child(scene)
	await process_frame
	var session: BattleSession = scene.get_node("BattleSession")
	session.sequencer.playback_speed = FAST_PLAYBACK
	var finished := [false]
	session.battle_finished.connect(func(_outcome: int) -> void: finished[0] = true)
	if not await _wait_until(func() -> bool: return finished[0] or session.engine.is_over(), BATTLE_TIMEOUT_MS):
		scene.queue_free()
		_fail("auto battle did not finish")
		return
	var replay_path: String = _debug.dump_replay()
	if replay_path.is_empty():
		scene.queue_free()
		_fail("dump_replay returned empty path")
		return
	if not FileAccess.file_exists(replay_path):
		scene.queue_free()
		_fail("dump file missing: " + replay_path)
		return
	print("DEBUG_SMOKE: auto battle outcome=%d rounds=%d replay=%s" % [
		session.engine.state.outcome, session.engine.state.round, replay_path,
	])
	scene.queue_free()
	await process_frame
	Engine.time_scale = 1.0

	# 2) 正常校验 + 篡改 snapshot 校验。
	var replay := BattleReplay.load_file(replay_path)
	if replay.is_empty():
		_fail("replay not loadable")
		return
	var verification := BattleReplay.verify(replay, content, true)
	if not bool(verification["ok"]):
		_fail("replay verify failed: " + str(verification["errors"]))
		return
	print("DEBUG_SMOKE: replay verify OK")

	var tampered := replay.duplicate(true)
	var snapshots: Array = tampered.get("snapshots", [])
	if snapshots.size() < 2:
		_fail("expected at least 2 snapshots, got %d" % snapshots.size())
		return
	var snapshot: Dictionary = snapshots[1]
	var units: Array = snapshot.get("units", [])
	if units.is_empty():
		_fail("snapshot round 2 has no units")
		return
	units[0]["hp"] = int(units[0]["hp"]) - 1
	var tampered_result := BattleReplay.verify(tampered, content, true)
	if bool(tampered_result["ok"]):
		_fail("tampered snapshot still verifies")
		return
	var reason := String(tampered_result["first_divergence"].get("reason", ""))
	if reason != "snapshot_mismatch":
		_fail("tampered snapshot reason=%s errors=%s" % [reason, str(tampered_result["errors"])])
		return
	print("DEBUG_SMOKE: tampered snapshot rejected (round=%s field=%s)" % [
		str(tampered_result["first_divergence"].get("round", 0)),
		str(tampered_result["first_divergence"].get("field", "")),
	])

	# 3) 回放模式：直接设置 pending path，场景 start 时由 BattleSession 消费。
	_debug.pending_replay_path = replay_path
	var replay_scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	replay_scene.start_auto_mode = false
	replay_scene.skip_story = true
	root.add_child(replay_scene)
	await process_frame
	var replay_session: BattleSession = replay_scene.get_node("BattleSession")
	if not replay_session.replay_mode:
		replay_scene.queue_free()
		_fail("session did not enter replay mode")
		return
	replay_session.sequencer.playback_speed = FAST_PLAYBACK
	if not await _check_shortcuts(replay_scene, replay_session):
		replay_scene.queue_free()
		return
	if not await _wait_until(func() -> bool: return replay_session.engine.state.round >= 3 or replay_session.engine.is_over(), REPLAY_TIMEOUT_MS):
		replay_scene.queue_free()
		_fail("replay did not complete 2 rounds (round=%d)" % replay_session.engine.state.round)
		return
	if replay_session.context.hud.visible:
		replay_scene.queue_free()
		_fail("HUD should be hidden in replay mode")
		return
	if not _has_label(replay_session.context.ui_layer, "回放模式"):
		replay_scene.queue_free()
		_fail("replay mode label missing")
		return
	print("DEBUG_SMOKE: replay mode played rounds=%d seed=%d" % [
		replay_session.engine.state.round, replay_session.engine.seed_value,
	])
	replay_scene.queue_free()
	await process_frame
	Engine.time_scale = 1.0
	print("DEBUG_SMOKE_OK")
	quit(0)

func _check_shortcuts(scene: Node, session: BattleSession) -> bool:
	var console := scene.get_node_or_null("UILayer/DebugConsole")
	var overlay := scene.get_node_or_null("UILayer/DebugOverlay")
	if console == null or overlay == null:
		_fail("debug UI nodes missing (console=%s overlay=%s)" % [str(console), str(overlay)])
		return false
	_press_key(KEY_F1)
	await process_frame
	if not console.visible:
		_fail("F1 did not open console")
		return false
	_press_key(KEY_F1)
	await process_frame
	if console.visible:
		_fail("F1 did not close console")
		return false
	_press_key(KEY_F3)
	await process_frame
	if not overlay.visible:
		_fail("F3 did not open overlay")
		return false
	_press_key(KEY_F3)
	await process_frame
	if overlay.visible:
		_fail("F3 did not close overlay")
		return false
	_press_key(KEY_F6)
	await process_frame
	if not session.sequencer.is_step_mode():
		_fail("F6 did not enable step mode")
		return false
	_press_key(KEY_F7)
	await process_frame
	_press_key(KEY_F6)
	await process_frame
	if session.sequencer.is_step_mode():
		_fail("F6 did not disable step mode")
		return false
	print("DEBUG_SMOKE: F1/F3/F6/F7 shortcuts OK")
	return true

func _press_key(keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	root.push_input(event)

func _wait_until(predicate: Callable, timeout_ms: int) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()

func _has_label(node: Node, needle: String) -> bool:
	if node == null:
		return false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Label and String(current.text).contains(needle):
			return true
		for child in current.get_children():
			stack.append(child)
	return false

func _fail(message: String) -> void:
	printerr("DEBUG_SMOKE_FAIL: " + message)
	quit(1)
