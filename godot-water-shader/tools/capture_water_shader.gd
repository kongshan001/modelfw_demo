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
	_scene.snap_camera()
	_scene.show_caption("潮汐花园 · 海 / 河 / 湖共用 1 个水面 Shader · 零额外网格")
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
	if i == 66:
		_scene.set_focus(WaterController.CAT_SEA)
		_scene.set_camera_view(lm["shallow"]["pos"], lm["shallow"]["zoom"])
		_scene.show_caption("海域 · 浅滩透沙 · Voronoi 焦散 · 两道波前拍岸白沫")
	elif i == 126:
		_scene.set_focus(WaterController.CAT_RIVER)
		_scene.show_caption("河流 · 单向流动 · 木桥裁切与遮挡")
	elif i == 186:
		_scene.set_focus(WaterController.CAT_LAKE)
		_scene.show_caption("内陆湖 · BFS 不贴边 → 自动关海浪 / 关焦散")
	elif i == 228:
		_scene.set_focus(WaterController.CAT_ALL)
		_scene.set_camera_view(lm["full"]["pos"], lm["full"]["zoom"], true)
		_scene.set_rain(0.95)
		_scene.show_caption("降雨 · 低洼积水 / 雨点涟漪 · 复用同一套水面逻辑")
	elif i == 276:
		_scene.set_debug_view(2)
		_scene.show_caption("调试 · 2-Pass 8 邻域水深场（直向 1 / 斜向 1.414）")
	elif i == 288:
		_scene.set_debug_view(3)
		_scene.show_caption("调试 · 零分配 BFS：海 / 河 / 湖 / 积水")


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
