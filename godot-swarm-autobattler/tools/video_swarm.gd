extends SceneTree

## 10 秒演示帧采集（15fps，1280×720，手动步进，确保录像节奏与实时帧率无关）。
## 运行：godot --path godot-swarm-autobattler -s tools/video_swarm.gd
## 帧输出：/tmp/swarmforge_frames_1080/frame_0000.png ...
## 之后用 ffmpeg 编码为 1920×1080 MP4 / 960×540 GIF。

const FRAME_DIR := "/tmp/swarmforge_frames_1080"
const FPS := 15.0
const TOTAL := 150
const SHOP_FRAMES := 18
const RESULT_AT := 138

var sv: SubViewport
var holder: Control
var game
var saved := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_move_to_foreground()
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	sv = SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(sv)
	holder = Control.new()
	holder.size = Vector2(1280, 720)
	holder.scale = Vector2(1.5, 1.5)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(holder)
	game = load("res://scenes/main.tscn").instantiate()
	holder.add_child(game)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw

	game.debug_flood_scene()
	game.debug_show_toast("洪流协议 ×100 · 每边 1,500 单位 · 贪婪潮 Lv.3 · 敌人获得更高增幅")
	for f in SHOP_FRAMES:
		await process_frame
		await RenderingServer.frame_post_draw
		_capture(f)
	game.debug_hide_toast()
	game.debug_video_start(3000)
	game.debug_get_view().set_speed(2.0)
	for f in range(SHOP_FRAMES, RESULT_AT):
		game.debug_video_frame(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		_capture(f)
	game.debug_video_finish()
	for f in range(RESULT_AT, TOTAL):
		await process_frame
		await RenderingServer.frame_post_draw
		_capture(f)
	print("VIDEO_FRAMES=", saved, " dir=", FRAME_DIR)
	print("SWARM_VIDEO_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


func _capture(index: int) -> void:
	var img: Image = sv.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("VIDEO_FRAME_FAIL ", index)
		return
	var path := "%s/frame_%04d.png" % [FRAME_DIR, index]
	img.save_png(path)
	saved += 1
	if saved % 15 == 0:
		print("VIDEO_PROGRESS=", saved, " last=", path)
