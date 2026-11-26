extends SceneTree

# 时间延时采集：06:00 → 次日 06:00，150 帧 @ 15fps = 10s。
# 帧写到 /tmp/sms_frames，再由 tools/build_media.sh 编码 MP4/GIF。
# 运行：godot --path godot-sun-moon-shadows -s tools/capture_sequence.gd

const FRAME_DIR := "/tmp/sms_frames"
const COUNT := 150
const START_HOUR := 6.0

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	var dir := DirAccess.open(FRAME_DIR)
	if dir != null:
		for f in dir.get_files():
			if f.begins_with("f_") and f.ends_with(".png"):
				dir.remove(f)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.9).timeout
	_scene.set_playing(false)
	_scene.set_ui_visible(true)
	_scene.set_debug_enabled(false)
	var hud = _scene.get_hud()
	for i in COUNT:
		var hour := fposmod(START_HOUR + 24.0 * float(i) / float(COUNT), 24.0)
		_scene.set_hour(hour)
		_scene.set_lamps_enabled(true)
		_scene.set_soft_knee(true)
		_scene.set_shadows_enabled(true)
		hud.sync_from_main()
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		img.save_png("%s/f_%03d.png" % [FRAME_DIR, i])
		if i % 15 == 0:
			print("FRAME %d/%d hour=%.2f" % [i, COUNT, hour])
	print("SEQUENCE_OK frames=%d" % COUNT)
	_scene.queue_free()
	_vp.queue_free()
	await process_frame
	quit(0)
