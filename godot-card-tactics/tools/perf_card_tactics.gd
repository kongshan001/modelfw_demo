extends SceneTree

# 真实 GPU 性能采样（1280×720）：待机棋盘 + AI 行动期间。
# 用法：godot --path godot-card-tactics --resolution 1280x720 -s tools/perf_card_tactics.gd

var _scene


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	await process_frame
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await create_timer(1.5).timeout
	_scene.demo_showcase()
	await create_timer(2.5).timeout

	var idle: Dictionary = await _sample(8)
	var ai_done := [false]
	_scene.ai_turn_finished.connect(func() -> void: ai_done[0] = true)
	_scene.demo_end_turn()
	var action: Dictionary = await _sample(6)
	for _i in range(12):
		if ai_done[0]:
			break
		await create_timer(0.25).timeout

	print("CARD_TACTICS_PERF idle_avg=%.1f idle_min=%.1f idle_max=%.1f action_avg=%.1f action_min=%.1f action_max=%.1f adapter=%s" % [
		idle["avg"], idle["min"], idle["max"], action["avg"], action["min"], action["max"],
		RenderingServer.get_video_adapter_name(),
	])
	_scene.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _sample(count: int) -> Dictionary:
	var values: Array[float] = []
	for _i in count:
		await create_timer(0.5).timeout
		values.append(float(Engine.get_frames_per_second()))
	var total := 0.0
	var lowest := 9999.0
	var highest := 0.0
	for value in values:
		total += value
		lowest = minf(lowest, value)
		highest = maxf(highest, value)
	var avg := total / maxf(1.0, float(values.size()))
	print("PERF samples=", values)
	return {"avg": avg, "min": lowest, "max": highest}
