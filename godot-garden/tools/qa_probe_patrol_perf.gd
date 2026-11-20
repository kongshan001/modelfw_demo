extends SceneTree

# QA 专用：巡逻性能 A/B 交错探针（不改游戏逻辑）。
# probe_patrol.gd 的 A/B 是“先隐藏 6s、后显示 6s”的单次顺序采样，在本机负载波动下
# 会出现 -7.4 ~ +15.3 FPS 的巨大漂移。本脚本用 shown/hidden 交替、正反顺序各 4 块，
# 取均值/中位数，并记录 draw call，得到可重复的巡逻渲染成本。
#
# 用法（需前台窗口，否则 macOS 会把窗口限速）：
#   open -a Godot --args --path <abs>/godot-garden --resolution 1280x720 \
#     --log-file /tmp/qa_perf.log -s res://tools/qa_probe_patrol_perf.gd

const WARMUP := 2.0
const BLOCK_SECONDS := 4.0
const CYCLES := 4

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(18.2)
	await create_timer(WARMUP).timeout

	var shown_fps: Array[float] = []
	var hidden_fps: Array[float] = []
	var shown_draws: Array[float] = []
	var hidden_draws: Array[float] = []
	var shown_first := true
	for cycle in CYCLES:
		var order: Array = [true, false]
		if not shown_first:
			order = [false, true]
		for visible in order:
			scene._world.set_patrol_visible(visible)
			await create_timer(0.5).timeout
			var sample := await _sample(BLOCK_SECONDS)
			if visible:
				shown_fps.append(sample["fps"])
				shown_draws.append(sample["draws"])
			else:
				hidden_fps.append(sample["fps"])
				hidden_draws.append(sample["draws"])
			print("PERF_BLOCK cycle=%d visible=%s fps=%.1f draws=%.1f" % [
				cycle, visible, sample["fps"], sample["draws"]])
		shown_first = not shown_first

	scene._world.set_patrol_visible(true)
	var shown_avg := _avg(shown_fps)
	var hidden_avg := _avg(hidden_fps)
	print("PERF_SHOWN fps_avg=%.1f fps_median=%.1f draws=%.1f blocks=%d" % [
		shown_avg, _median(shown_fps), _avg(shown_draws), shown_fps.size()])
	print("PERF_HIDDEN fps_avg=%.1f fps_median=%.1f draws=%.1f blocks=%d" % [
		hidden_avg, _median(hidden_fps), _avg(hidden_draws), hidden_fps.size()])
	print("PERF_COST avg=%.1f median=%.1f draw_delta=%.1f" % [
		hidden_avg - shown_avg,
		_median(hidden_fps) - _median(shown_fps),
		_avg(hidden_draws) - _avg(shown_draws)])
	print("QA_PERF_DONE")
	scene.queue_free()
	await process_frame
	quit(0)

func _sample(duration: float) -> Dictionary:
	var start_us := Time.get_ticks_usec()
	var start_frames := Engine.get_process_frames()
	var draws := 0.0
	var draw_samples := 0
	while true:
		await process_frame
		var elapsed := float(Time.get_ticks_usec() - start_us) / 1000000.0
		draws += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		draw_samples += 1
		if elapsed >= duration:
			break
	var seconds := float(Time.get_ticks_usec() - start_us) / 1000000.0
	var frames := Engine.get_process_frames() - start_frames
	return {"fps": float(frames) / maxf(seconds, 0.001), "draws": draws / float(maxi(draw_samples, 1))}

func _avg(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / float(maxi(values.size(), 1))

func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var middle := sorted.size() / 2
	if sorted.size() % 2 == 0:
		return (sorted[middle - 1] + sorted[middle]) * 0.5
	return sorted[middle]
