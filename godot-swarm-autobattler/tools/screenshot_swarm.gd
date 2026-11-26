extends SceneTree

## 真实 GPU 截图工具：在 SubViewport 中以 1920×1080 捕获 1280×720 设计稿（1.5×）。
## 运行：godot --path godot-swarm-autobattler -s tools/screenshot_swarm.gd
## 输出：docs/shots/*.png + 末行 SWARM_SHOTS_OK

const OUT_DIR := "res://docs/shots/"

var sv: SubViewport
var holder: Control
var game
var captured: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	sv = SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	sv.transparent_bg = false
	root.add_child(sv)
	holder = Control.new()
	holder.size = Vector2(1280, 720)
	holder.scale = Vector2(1.5, 1.5)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(holder)
	game = load("res://scenes/main.tscn").instantiate()
	holder.add_child(game)
	await process_frame
	await process_frame
	await process_frame

	game.debug_shop_scene()
	await _settle(5)
	await _shot("01_shop.png")

	game.debug_flood_scene()
	await _settle(5)
	await _shot("02_hundredfold_board.png")

	game.debug_greed_scene()
	await _settle(5)
	await _shot("03_greed_tide.png")

	game.debug_mount_battle(3000, 7.0, true, false, false)
	await _settle(6)
	await _shot("04_battle_3000.png")

	game.debug_perf_overlay(true)
	game.debug_mount_battle(3000, 4.0, true, true, false)
	await _settle(12)
	await _shot("05_perf_debug.png")

	game.debug_victory_scene()
	await _settle(6)
	await _shot("06_victory.png")

	game.debug_code_scene()
	await _settle(5)
	await _shot("07_roster_code.png")
	game._on_code_close()

	print("SHOT_COUNT=", captured.size())
	for p in captured:
		print("SHOT_FILE=", p)
	print("SWARM_SHOTS_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR + name)
	var img: Image = sv.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("SHOT_FAIL empty ", name)
		return
	img.save_png(path)
	var size := img.get_size()
	var px := img.get_pixel(int(size.x * 0.5), int(size.y * 0.5))
	var bytes := 0
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		bytes = f.get_length()
		f.close()
	print("SHOT %s %dx%d bytes=%d center=%s" % [name, int(size.x), int(size.y), bytes, str(px)])
	captured.append(path)
	await process_frame
