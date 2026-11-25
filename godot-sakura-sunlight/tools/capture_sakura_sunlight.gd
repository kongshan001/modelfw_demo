extends SceneTree

# 10 秒（300 帧 @ 30fps）演示时间线：08:00 → 17:00 的连续日照，
# 固定机位、UI 保留、花瓣持续飘落。1280×720 SubViewport 逐帧抓图。
# 用法：godot --path godot-sakura-sunlight --fixed-fps 30 -s tools/capture_sakura_sunlight.gd
# 之后由 tools/build_media.sh 调 ffmpeg 生成 docs/sakura_sunlight.mp4 / .gif。

const OUT := "/tmp/sakura_sunlight_frames"
const SIZE := Vector2i(1280, 720)
const FRAMES := 300

var _scene
var _vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	var hud = _scene.get_node("HUD")
	hud.set_fps_visible(false)
	_scene.set_ui_visible(true)
	_scene.set_playing(false)
	_scene.set_debug_enabled(false)

	for i in FRAMES:
		var hour := 8.0 + 9.0 * float(i) / float(FRAMES)
		_scene.set_hour(hour)
		hud.sync_from_main()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%03d.png" % [OUT, i])
		if err != OK:
			printerr("save frame %d failed: %d" % [i, err])
		if i % 60 == 0:
			print("CAPTURE frame=%d hour=%.2f" % [i, hour])
	print("SAKURA_SUNLIGHT_CAPTURE_OK frames=%d" % FRAMES)
	quit(0)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
