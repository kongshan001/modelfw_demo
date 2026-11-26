extends SceneTree

# 10 秒展示片：固定 15fps 步进，广角 → 岸线微距（湿沙/泡沫/透明浅水）→ 礁石 → 黄昏 → 夜晚。
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
	# 0–2.4s 广角绕岛（新岸线全景）
	if t < 2.4:
		var k := t / 2.4
		scene.set_camera_target(0.0, 0.0, 1.2)
		scene.set_camera_orbit(lerpf(84.0, 94.0, k), lerpf(58.0, 56.0, k), 118.0)
		scene.set_hour(11.5)
	# 2.4–5.2s 推近岸线：湿沙/水线/多层泡沫/沙底焦散
	elif t < 5.2:
		var k := smoothstep(0.0, 1.0, clampf((t - 2.4) / 1.05, 0.0, 1.0))
		scene.set_camera_target(lerpf(0.0, 0.0, k), lerpf(0.0, 27.0, k), lerpf(1.2, 0.2, k))
		scene.set_camera_orbit(lerpf(94.0, 70.0, k), lerpf(56.0, 40.0, k), lerpf(118.0, 24.0, k))
		scene.set_hour(11.5)
		if t > 3.6 and int(t * 15.0) % 5 == 0:
			scene.debug_paint_arc(Vector2(-1.0, 27.8), 1.6, 2, 0.5)
	# 5.2–7.0s 移到礁石小岛：泡沫环/湿岩基座/透明浅水
	elif t < 7.0:
		var k := smoothstep(0.0, 1.0, (t - 5.2) / 1.4)
		scene.set_camera_target(lerpf(0.0, 13.0, k), lerpf(27.0, 30.0, k), 0.2)
		scene.set_camera_orbit(lerpf(70.0, 100.0, k), lerpf(40.0, 42.0, k), 24.0)
		scene.set_hour(11.5)
	# 7.0–8.2s 拉远到黄昏全景
	elif t < 8.2:
		var k := smoothstep(0.0, 1.0, (t - 7.0) / 1.2)
		scene.set_camera_target(lerpf(13.0, 0.0, k), lerpf(30.0, 4.0, k), lerpf(0.2, 1.0, k))
		scene.set_camera_orbit(lerpf(100.0, 112.0, k), lerpf(42.0, 52.0, k), lerpf(24.0, 82.0, k))
		scene.set_hour(lerpf(11.5, 17.9, k))
	# 8.2–10s 夜景岸线：泡沫与水线在月光下的层次
	else:
		var k := smoothstep(0.0, 1.0, (t - 8.2) / 1.5)
		scene.set_camera_target(lerpf(0.0, 0.0, k), lerpf(4.0, 27.0, k), lerpf(1.0, 0.2, k))
		scene.set_camera_orbit(lerpf(112.0, 72.0, k), lerpf(52.0, 40.0, k), lerpf(82.0, 27.0, k))
		scene.set_hour(lerpf(17.9, 20.4, k))
		if t > 9.0 and int(t * 15.0) % 6 == 0:
			scene.debug_paint_arc(Vector2(2.0, 28.0), 1.4, 1, 0.35)
