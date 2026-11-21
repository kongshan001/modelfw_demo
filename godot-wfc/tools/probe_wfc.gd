extends SceneTree

# 真实 GPU 性能探针：默认 16×10、20 步/秒的生成过程 + 成品地图动画。
# 关闭垂直同步，各连续采样 5 秒；验收门槛 30 FPS（Intel HD Graphics 6000）。
# 用法：godot --path godot-wfc --resolution 1280x720 -s tools/probe_wfc.gd

const DURATION := 5.0
const SAMPLE := 0.5
const MIN_FPS := 30.0

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	var guard := 0
	while not _scene.get_board().is_atlas_ready() and guard < 600:
		await process_frame
		guard += 1
	await create_timer(0.3).timeout

	_scene.new_map("2718", 16, 10, true, true)
	_scene.set_speed_value(20.0)
	_scene.set_view_mode("algo")
	await create_timer(1.2).timeout
	var algorithm_avg: float = await _measure("default_16x10_algo_20steps", DURATION)

	_scene.finish_now()
	_scene.set_view_mode("map")
	await create_timer(0.8).timeout
	var map_avg: float = await _measure("default_16x10_map", 3.0)

	var stats: Dictionary = _scene.get_solver().get_stats()
	print("FINAL_STATS steps=%d propagations=%d backtracks=%d restarts=%d" % [
		int(stats["steps"]), int(stats["propagations"]),
		int(stats["backtracks"]), int(stats["restarts"])])
	if minf(algorithm_avg, map_avg) < MIN_FPS:
		printerr("WFC_PROBE_FAIL: below %.0f fps (algo %.1f, map %.1f)" % [
			MIN_FPS, algorithm_avg, map_avg])
		quit(1)
	else:
		print("WFC_PROBE_OK algo_avg=%.1f map_avg=%.1f" % [algorithm_avg, map_avg])
		quit(0)


func _measure(label: String, duration: float) -> float:
	var samples: Array[float] = []
	var elapsed := 0.0
	while elapsed < duration:
		await create_timer(SAMPLE).timeout
		elapsed += SAMPLE
		samples.append(Engine.get_frames_per_second())
	var total := 0.0
	var lowest := 9999.0
	for sample in samples:
		total += sample
		lowest = minf(lowest, sample)
	var average := total / samples.size()
	print("%s: avg=%.1f min=%.1f samples=%s" % [label, average, lowest, str(samples)])
	return average
