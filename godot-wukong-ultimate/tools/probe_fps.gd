extends SceneTree

## Real-window performance probe (Intel HD 6000 target: 30 fps+).
##   godot --path . --resolution 1280x720 -s tools/probe_fps.gd

var _scene: Node


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(2.4).timeout
	_scene.dummy.ai_enabled = false
	_scene.set_controls_enabled(false)
	var samples: Array[float] = []
	var elapsed := 0.0
	var burst := 0.0
	while elapsed < 12.0:
		await create_timer(0.5).timeout
		elapsed += 0.5
		samples.append(Engine.get_frames_per_second())
		burst += 0.5
		if burst >= 2.5:
			burst = 0.0
			_scene.demo_set_dummy_hp(240)
			_scene.demo_charge(0.8)
			await create_timer(0.3).timeout
			_scene.demo_fire_at_dummy(1.0, 120)
	var avg := 0.0
	var worst := 999.0
	for s in samples:
		avg += s
		worst = minf(worst, s)
	avg /= float(maxi(samples.size(), 1))
	print("WUKONG_ULT_FPS avg=%.1f min=%.1f samples=%d" % [avg, worst, samples.size()])
	print("WUKONG_ULT_FPS_OK" if avg >= 30.0 else "WUKONG_ULT_FPS_FAIL")
	_scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if avg >= 30.0 else 1)
