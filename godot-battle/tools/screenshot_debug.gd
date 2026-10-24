extends SceneTree

# 调试 UI 截图：F1 控制台 + F3 浮层（含 state/validate 回显），以及录像回放模式。
# 用法：godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_debug.gd
# 输出：user://screenshots/plan2b_debug_console_overlay.png / plan2b_debug_replay.png

const CAPTURE_DIR := "user://screenshots"
const WARMUP := 0.6

var _viewport: SubViewport
var _debug: Node

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_debug = root.get_node_or_null("BattleDebug")
	if _debug == null:
		_fail("autoload BattleDebug missing")
		return
	if not await _verify_dump_screenshot():
		return
	_viewport = _make_viewport()

	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.skip_story = true
	_viewport.add_child(scene)
	await process_frame
	var hud: BattleHUD = scene.get_node("UILayer/BattleHUD")
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 8.0):
		_fail("command phase did not start")
		return
	await create_timer(WARMUP).timeout

	_debug.toggle_overlay()
	_debug.toggle_console()
	var console := scene.get_node_or_null("UILayer/DebugConsole")
	if console == null:
		_fail("DebugConsole node missing under UILayer")
		return
	console.execute_command("add_status hero_swordsman war_cry")
	console.execute_command("state")
	console.execute_command("validate")
	console.execute_command("seed")
	await create_timer(0.4).timeout
	await _capture("plan2b_debug_console_overlay.png")

	# 生成一段 3 回合录像，再以回放模式加载，截取「回放模式」标签 + 浮层。
	_debug.toggle_console()
	var replay_path := _make_replay()
	scene.queue_free()
	await process_frame
	_debug.pending_replay_path = replay_path

	var replay_scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	replay_scene.start_auto_mode = false
	replay_scene.skip_story = true
	_viewport.add_child(replay_scene)
	await process_frame
	var replay_session: BattleSession = replay_scene.get_node("BattleSession")
	if not replay_session.replay_mode:
		_fail("replay scene did not enter replay mode")
		return
	_debug.toggle_overlay()
	if not await _wait_until(func() -> bool: return replay_session.engine.state.round >= 2 or replay_session.engine.is_over(), 20.0):
		_fail("replay mode did not reach round 2")
		return
	await create_timer(0.5).timeout
	await _capture("plan2b_debug_replay.png")

	replay_scene.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	quit(0)

func _verify_dump_screenshot() -> bool:
	# 在真实窗口视口跑一局开场帧，验证 dump_replay 会把截图存到录像旁。
	if DisplayServer.get_name() == "headless":
		print("SCREENSHOT_DEBUG: headless, skip dump screenshot check")
		return true
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.skip_story = true
	root.add_child(scene)
	await process_frame
	await RenderingServer.frame_post_draw
	var replay_path: String = _debug.dump_replay()
	var png_path := replay_path.get_basename() + ".png" if not replay_path.is_empty() else ""
	scene.queue_free()
	await process_frame
	if replay_path.is_empty():
		_fail("dump_replay returned empty path")
		return false
	if not FileAccess.file_exists(png_path):
		_fail("dump screenshot missing: " + png_path)
		return false
	print("SCREENSHOT_DEBUG: dump screenshot=" + ProjectSettings.globalize_path(png_path))
	return true

func _make_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _make_replay() -> String:
	var content := ContentDB.load_all()
	var encounter := content.get_encounter(&"enc_bamboo_01")
	var engine := BattleEngine.new(encounter, content, 424242, true)
	for i in 3:
		if engine.is_over():
			break
		engine.resolve_round(_auto_intents(engine))
	return engine.dump_replay("user://replays/plan2b_screenshot.json")

func _auto_intents(engine: BattleEngine) -> Array[BattleIntent]:
	var intents: Array[BattleIntent] = []
	var allies := engine.state.living(BattleTypes.Side.ALLY)
	var enemies := engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		return intents
	for ally in allies:
		if ally.id == &"hero_healer" and ally.mp >= 30:
			var target := _lowest_ally(allies)
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [target.id], &"heal_single"))
		elif ally.id == &"hero_mage" and ally.mp >= 25:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.SKILL, [enemies[0].id], &"fire_spell"))
		else:
			intents.append(BattleIntent.make(ally.id, BattleTypes.IntentKind.ATTACK, [enemies[0].id]))
	return intents

func _lowest_ally(allies: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := allies.duplicate()
	sorted.sort_custom(func(a, b): return float(a.hp) / a.data.max_hp < float(b.hp) / b.data.max_hp)
	return sorted[0] if not sorted.is_empty() else null

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await process_frame
	return predicate.call()

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := CAPTURE_DIR + "/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	printerr("SCREENSHOT_DEBUG_FAIL: " + message)
	quit(1)
