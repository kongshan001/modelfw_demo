extends SceneTree

# 真实 GPU 性能探针：1280×720 / vsync off。
# 用法：godot --path . --resolution 1280x720 -s tools/probe_proc_map.gd

const DURATION := 3.0
const SAMPLE := 0.5
const MIN_FPS := 30.0

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame
	await create_timer(0.5).timeout

	_scene.api_new("biome", "9001", 0, 0.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	await create_timer(0.5).timeout
	var biome_avg: float = await _measure("biome_idle", DURATION)

	_scene.api_set_debug({"biomes": true, "rooms": true, "connectivity": true, "bounds": true, "noise": true})
	await create_timer(0.3).timeout
	var debug_avg: float = await _measure("biome_debug", DURATION)

	_scene.api_new("dungeon", "2137", 0, 12.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	await create_timer(0.5).timeout
	var dungeon_avg: float = await _measure("dungeon_idle", DURATION)

	_scene.api_new("biome", "77", 0, 0.0, true)
	_scene.api_set_paused(false)
	_scene.set_speed(2.0)
	var gen_avg: float = await _measure("biome_generating_2stageps", 2.0)
	_scene.api_set_paused(true)
	var stats = _scene.api_get_gen().get_stats()
	print("FINAL generation_ms=%.1f apply_ms=%.1f signature=%s stage_ms=%s" % [
		float(stats.get("total_ms", 0.0)), _scene._apply_ms,
		_scene.api_get_signature(), str(stats.get("stage_ms", []))])
	if minf(minf(biome_avg, debug_avg), minf(dungeon_avg, gen_avg)) < MIN_FPS:
		printerr("PROC_MAP_PROBE_FAIL: below %.0f fps" % MIN_FPS)
		quit(1)
	else:
		print("PROC_MAP_PROBE_OK biome=%.1f debug=%.1f dungeon=%.1f generating=%.1f" % [
			biome_avg, debug_avg, dungeon_avg, gen_avg])
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
	for value in samples:
		total += value
		lowest = minf(lowest, value)
	var average := total / float(samples.size())
	print("%s: avg=%.1f min=%.1f samples=%s" % [label, average, lowest, str(samples)])
	return average
