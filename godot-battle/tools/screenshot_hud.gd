extends SceneTree

# Task 3 HUD 截图：默认手动模式，先截指令面板，再程序化完成一回合，
# 在第二回合指令阶段截取含出手顺序条与战斗日志的画面。

const WARMUP := 0.8

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.skip_story = true
	_viewport.add_child(scene)
	await process_frame
	var hud: BattleHUD = scene.get_node("UILayer/BattleHUD")
	var session: BattleSession = scene.get_node("BattleSession")
	var phase_started := hud.is_collecting()
	session.command_phase_started.connect(func() -> void: phase_started = true)

	await create_timer(WARMUP).timeout
	if not await _wait_until(func() -> bool: return phase_started and hud.is_collecting(), 6.0):
		printerr("SCREENSHOT_HUD_FAIL: command phase did not start")
		quit(1)
		return
	await create_timer(0.25).timeout
	await _capture("task3_hud.png")

	var enemies := session.engine.state.living(BattleTypes.Side.ENEMY)
	if enemies.is_empty():
		printerr("SCREENSHOT_HUD_FAIL: no living enemies")
		quit(1)
		return
	var primary := enemies[0].id
	hud.select_attack()
	await create_timer(0.35).timeout
	await _capture("task3_hud_target.png")
	hud.choose_target(primary)
	hud.select_skill(&"fire_spell")
	hud.choose_target(primary)
	hud.select_defend()

	if not await _wait_until(func() -> bool: return not hud.is_collecting(), 3.0):
		printerr("SCREENSHOT_HUD_FAIL: first command phase did not finish")
		quit(1)
		return
	hud.toggle_speed()

	if not await _wait_until(func() -> bool: return hud.is_collecting(), 30.0):
		printerr("SCREENSHOT_HUD_FAIL: second command phase did not start")
		quit(1)
		return
	await create_timer(0.6).timeout
	await _capture("task3_hud_battle.png")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await create_timer(0.1).timeout
		elapsed += 0.1
	return false

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
