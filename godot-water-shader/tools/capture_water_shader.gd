extends SceneTree

# 10 秒演示时间线（30 fps, 300 帧, 1920×1080 离屏）：
#   全景 → 海域浅滩/波前 → 河流木桥 → 内陆湖 → 降雨积水 → 水深/类别调试。
# 用法：godot --path godot-water-shader --fixed-fps 30 -s tools/capture_water_shader.gd
# 再由 tools/build_media.sh 调 ffmpeg 生成 mp4/gif。

const OUT := "/tmp/water_shader_frames"
const SIZE := Vector2i(1920, 1080)
const FPS := 30
const FRAMES := 300

var _scene
var _hud
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
	await process_frame
	_hud = _scene.get_hud()
	_hud.set_display_scale(1.5)
	_hud.set_stats_visible(false)
	_scene.set_ui_visible(false)
	_scene.set_focus(WaterController.CAT_ALL)
	var lm0: Dictionary = _scene.get_landmarks()
	_scene.set_camera_view(lm0["hero_shore"]["pos"], lm0["hero_shore"]["zoom"], true)
	_scene.show_caption("")
	await create_timer(0.5).timeout

	for i in FRAMES:
		_apply_timeline(i)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%03d.png" % [OUT, i])
		if err != OK:
			printerr("save frame %d failed: %d" % [i, err])
		if i % 30 == 0:
			print("CAPTURE frame=%d" % i)
	print("WATER_SHADER_CAPTURE_OK frames=%d" % FRAMES)
	quit(0)


func _apply_timeline(i: int) -> void:
	var lm: Dictionary = _scene.get_landmarks()
	if i == 30:
		# 1s 切到浅滩；t≈1.4s 两道波前同时处于中段（便于 GIF 抽帧验证）。
		_scene.set_camera_view(lm["shallow"]["pos"], lm["shallow"]["zoom"], true)
	elif i == 120:
		_scene.set_camera_view(lm["hero_bridge"]["pos"], lm["hero_bridge"]["zoom"], true)
	elif i == 180:
		_scene.set_camera_view(lm["hero_lake"]["pos"], lm["hero_lake"]["zoom"], true)
	elif i == 228:
		_scene.set_camera_view(lm["hero_rain"]["pos"], lm["hero_rain"]["zoom"], true)
		_scene.set_rain(0.95)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
