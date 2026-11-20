extends SceneTree

# GPU 性能与回退探针：默认 / 关倒影 / 降内部分辨率，各测 5s 平均与最低 FPS。
# 用法：godot --path godot-pixel-ocean --resolution 1280x720 -s tools/probe_pixel_ocean.gd

const DURATION := 5.0
const SAMPLE := 0.5

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(0.5).timeout
	_scene.set_auto_orbit(false)
	_scene.set_preset(1)
	_scene.set_time_of_day(18.4)
	_scene.set_camera_orbit(32.0, 12.0, 8.8)
	_scene.set_ui_visible(false)
	await create_timer(2.0).timeout

	var default_avg: float = await _measure("default_640x360_refl_on")
	_scene.set_reflection_strength(0.0)
	await create_timer(1.0).timeout
	await _measure("refl_off")
	_scene.set_reflection_strength(0.9)
	var vp: SubViewport = _scene.get_world_viewport()
	vp.size = Vector2i(512, 288)
	await create_timer(1.0).timeout
	await _measure("refl_on_512x288")
	vp.size = Vector2i(640, 360)
	await create_timer(0.5).timeout

	print("PRIMITIVES=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			" DRAW_CALLS=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if default_avg < 30.0:
		printerr("PIXEL_OCEAN_PROBE_FAIL: default avg below 30 fps (%.1f)" % default_avg)
		quit(1)
	else:
		print("PIXEL_OCEAN_PROBE_OK")
		quit(0)


func _measure(label: String) -> float:
	var samples: Array[float] = []
	var elapsed := 0.0
	while elapsed < DURATION:
		await create_timer(SAMPLE).timeout
		elapsed += SAMPLE
		samples.append(Engine.get_frames_per_second())
	var total := 0.0
	var lowest := 999.0
	for s in samples:
		total += s
		lowest = minf(lowest, s)
	var average := total / samples.size()
	print("%s: avg=%.1f min=%.1f samples=%s" % [
		label, average, lowest, str(samples)])
	return average
