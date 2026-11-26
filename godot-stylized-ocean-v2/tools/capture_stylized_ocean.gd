extends SceneTree

# 10 秒展示片：固定 15fps 步进，广角环绕 → 岸线涟漪 → 落石水花 → 黄昏 → 夜晚。
# 输出 /tmp/ocean_v2_frames/frame_000.png...，再由 tools/build_media.sh 编码。
# 用法：godot --path godot-stylized-ocean-v2 -s tools/capture_stylized_ocean.gd

const FPS := 15.0
const FRAMES := 150
const OUT := "/tmp/ocean_v2_frames"
const SIZE := Vector2i(1280, 720)
const STEP := 1.0 / FPS

var vp: SubViewport
var scene
var _drop_done := false


func _init() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var vp2 := SubViewport.new()
	vp = vp2
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await create_timer(0.8).timeout
	scene.set_ui_visible(false)
	scene.set_paused(true)
	scene.set_hour(11.5)
	scene.set_camera_orbit(84.0, 58.0, 120.0)
	scene.ocean.clear_ripples()
	for i in 30:
		scene.tick(STEP)

	for frame in FRAMES:
		var t := float(frame) / FPS
		_apply_timeline(t)
		scene.tick(STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/frame_%03d.png" % [OUT, frame])
		if frame % 30 == 0:
			print("frame ", frame)
	print("STYLIZED_OCEAN_FRAMES_OK frames=", FRAMES)
	quit(0)


func _apply_timeline(t: float) -> void:
	# 0–2.6s 广角绕岛
	if t < 2.6:
		var k := t / 2.6
		scene.set_camera_target(0.0, 0.0, 1.2)
		scene.set_camera_orbit(lerpf(84.0, 96.0, k), lerpf(58.0, 56.0, k), 118.0)
		scene.set_hour(11.5)
	# 2.6–4.4s 推近岸线，画涟漪
	elif t < 4.4:
		var k := (t - 2.6) / 1.8
		scene.set_camera_target(0.0, lerpf(6.0, 24.0, k), 0.6)
		scene.set_camera_orbit(lerpf(96.0, 102.0, k), lerpf(56.0, 52.0, k), lerpf(118.0, 58.0, minf(1.0, k * 1.6)))
		scene.set_virtual_cursor(Vector2(620.0, 430.0))
		if not _drop_done and t > 3.1:
			_drop_done = true
			scene._drop_rock(Vector3(4.0, 0.0, 28.0), Vector2(4.0, 28.0))
		if t > 3.4 and int(t * 15.0) % 3 == 0:
			scene.debug_paint_arc(Vector2(-2.0, 25.0), 3.5, 3, 0.65)
	# 4.4–6.4s 拉远，黄昏过渡
	elif t < 6.4:
		var k := (t - 4.4) / 2.0
		scene.set_virtual_cursor(Vector2(-99999, -99999))
		scene.set_camera_target(0.0, 0.0, 1.2)
		scene.set_camera_orbit(lerpf(102.0, 110.0, k), lerpf(52.0, 57.0, k), lerpf(58.0, 105.0, k))
		scene.set_hour(lerpf(11.5, 17.9, smoothstep(0.0, 1.0, k)))
	# 6.4–8.2s 黄昏→夜晚
	elif t < 8.2:
		var k := (t - 6.4) / 1.8
		scene.set_camera_target(0.0, 0.0, 1.2)
		scene.set_camera_orbit(lerpf(110.0, 98.0, k), lerpf(57.0, 54.0, k), 106.0)
		scene.set_hour(lerpf(17.9, 20.4, smoothstep(0.0, 1.0, k)))
	# 8.2–10s 夜景 + 涟漪
	else:
		var k := (t - 8.2) / 1.8
		scene.set_camera_target(0.0, 0.0, 1.2)
		scene.set_camera_orbit(lerpf(98.0, 94.0, k), lerpf(54.0, 57.0, k), 108.0)
		scene.set_hour(20.4)
		if int(t * 15.0) % 4 == 0:
			scene.debug_paint_arc(Vector2(16.0, 28.0), 4.0, 2, 0.5)
