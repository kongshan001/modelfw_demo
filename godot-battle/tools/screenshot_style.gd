extends SceneTree

# 画风后处理截图：原画 / 卡通渲染 / 水墨，各一张 1920×1080。
# 用法：godot --path godot-battle --resolution 1920x1080 -s tools/screenshot_style.gd
# 输出：user://screenshots/style_0_original.png / style_1_toon.png / style_2_ink.png

const CAPTURE_DIR := "user://screenshots"
const SHOTS := [
	{"mode": 0, "file": "style_0_original.png"},
	{"mode": 1, "file": "style_1_toon.png"},
	{"mode": 2, "file": "style_2_ink.png"},
]

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.skip_story = true
	_viewport.add_child(scene)
	await process_frame

	var hud: BattleHUD = scene.get_node("UILayer/BattleHUD")
	if not await _wait_until(func() -> bool: return hud.is_collecting(), 8.0):
		_fail("command phase did not start")
		return
	await create_timer(0.6).timeout

	var fx: StylePostProcess = scene.get_node_or_null("StyleFX")
	if fx == null:
		_fail("StyleFX missing")
		return

	# 冻结战斗，保证三张图是同一帧的三种画风。
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	for shot in SHOTS:
		fx.set_style(int(shot["mode"]), true, false)
		await process_frame
		await create_timer(0.08).timeout
		await _capture(String(shot["file"]))

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
	var path := CAPTURE_DIR + "/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	printerr("SCREENSHOT_STYLE_FAIL: " + message)
	quit(1)
