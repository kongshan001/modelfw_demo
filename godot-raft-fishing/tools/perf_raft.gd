extends SceneTree

# 真实 GPU 性能探针：1280×720、关闭垂直同步，压满漂浮物测平均帧率。
const FRAMES := 360

var _vp: SubViewport
var _scene: Node
var _world: RaftWorld


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(1.0).timeout
	_world = _scene.get_node("ViewportContainer/WorldViewport/World")
	_world.spawn_enabled = true
	for i in 8:
		var a := TAU * float(i) / 8.0
		_world.debug_spawn_loot("barrel" if i % 3 != 0 else "crate",
			Vector3(cos(a) * 8.0, 0.0, sin(a) * 8.0))
	_world.begin_charge()
	await create_timer(1.0).timeout
	_world.release_cast()
	await create_timer(0.5).timeout

	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		if i > 30:
			samples.append(dt)
	var total := 0.0
	var min_fps := 9999.0
	for dt in samples:
		total += dt
		if dt > 0.0:
			min_fps = minf(min_fps, 1.0 / dt)
	var avg := float(samples.size()) / total
	print("RAFT_PERF fps_avg=%.1f fps_min=%.1f frames=%d" % [avg, min_fps, samples.size()])
	if avg >= 30.0:
		print("RAFT_PERF_OK")
	else:
		printerr("RAFT_PERF_FAIL fps_avg=%.1f" % avg)
	quit(0 if avg >= 30.0 else 1)
