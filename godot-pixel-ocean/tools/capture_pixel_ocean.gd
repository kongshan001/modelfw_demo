extends SceneTree

# 9 秒 GIF/MP4 素材：固定 15fps 步进，晚霞→正午→低机位倒影→夜。
# 用法：godot --path godot-pixel-ocean --resolution 1280x720 -s tools/capture_pixel_ocean.gd
# 输出帧到 /tmp/pixel_ocean_frames/frame_000.png ...，再由 tools/build_media.sh 编码。

const FPS := 15.0
const FRAMES := 135
const OUT := "/tmp/pixel_ocean_frames"
const SIZE := Vector2i(1280, 720)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.4).timeout
	_scene.set_auto_orbit(false)
	_scene.set_ui_visible(false)
	_scene.set_paused(true)

	# 先让木筏稳定在水面上
	_scene.set_time_of_day(18.4)
	_scene.set_wave_height(1.0)
	for i in 30:
		_scene.get_ocean().tick(0.1)
		_scene.get_raft().update_buoyancy(0.1)

	for frame in FRAMES:
		var t := float(frame) / FPS
		_apply_timeline(t)
		_scene.get_ocean().tick(1.0 / FPS)
		_scene.get_raft().update_buoyancy(1.0 / FPS)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/frame_%03d.png" % [OUT, frame]
		_vp.get_texture().get_image().save_png(path)
		if frame % 30 == 0:
			print("FRAME ", frame)

	print("PIXEL_OCEAN_FRAMES_OK frames=", FRAMES)
	quit(0)


func _apply_timeline(t: float) -> void:
	var yaw := 30.0
	var pitch := 12.0
	var dist := 8.8
	var hour := 18.4
	var height := 1.0
	var foam := 0.85
	var refl := 0.90
	var spark := 1.10
	var clear := 0.22

	if t < 2.5:
		var k := _smooth(t / 2.5)
		yaw = lerpf(28.0, 38.0, k)
		height = lerpf(1.0, 1.2, k)
	elif t < 4.2:
		var k := _smooth((t - 2.5) / 1.7)
		hour = lerpf(18.4, 12.5, k)
		yaw = lerpf(38.0, 46.0, k)
		height = lerpf(1.2, 1.35, k)
		foam = lerpf(0.85, 1.0, k)
		refl = lerpf(0.90, 0.60, k)
		spark = lerpf(1.10, 0.80, k)
		clear = lerpf(0.22, 0.25, k)
	elif t < 5.3:
		var k := _smooth((t - 4.2) / 1.1)
		yaw = lerpf(46.0, 40.0, k)
		pitch = lerpf(12.0, 18.0, k)
		dist = lerpf(8.8, 9.4, k)
		height = lerpf(1.35, 1.15, k)
		foam = 1.0
		refl = 0.60
		spark = 0.80
		clear = 0.25
	elif t < 6.9:
		var k := _smooth((t - 5.3) / 1.6)
		hour = lerpf(12.5, 18.4, k)
		yaw = lerpf(40.0, 20.0, k)
		pitch = lerpf(18.0, 5.0, k)
		dist = lerpf(9.4, 7.2, k)
		height = lerpf(1.15, 1.30, k)
		foam = lerpf(1.0, 0.9, k)
		refl = lerpf(0.60, 1.0, k)
		spark = lerpf(0.80, 1.20, k)
		clear = lerpf(0.25, 0.15, k)
	elif t < 7.8:
		var k := _smooth((t - 6.9) / 0.9)
		yaw = lerpf(20.0, 25.0, k)
		pitch = lerpf(5.0, 7.0, k)
		dist = 7.2
		height = 1.30
		foam = 0.9
		refl = 1.0
		spark = 1.20
		clear = 0.15
	else:
		var k := _smooth(clampf((t - 7.8) / 1.2, 0.0, 1.0))
		hour = lerpf(18.4, 22.5, k)
		yaw = lerpf(25.0, 36.0, k)
		pitch = lerpf(7.0, 11.0, k)
		dist = lerpf(7.2, 8.4, k)
		height = lerpf(1.30, 0.95, k)
		foam = lerpf(0.9, 0.65, k)
		refl = lerpf(1.0, 0.70, k)
		spark = lerpf(1.20, 0.60, k)
		clear = lerpf(0.15, 0.18, k)

	_scene.set_time_of_day(hour)
	_scene.set_camera_orbit(yaw, pitch, dist)
	_scene.set_wave_height(height)
	_scene.set_foam_amount(foam)
	_scene.set_reflection_strength(refl)
	_scene.set_sparkle_amount(spark)
	_scene.set_transparency(clear)


func _smooth(value: float) -> float:
	var x := clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
