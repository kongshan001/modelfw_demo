extends SceneTree

# 真实 GPU 渲染基准：加载主场景，分别以 200 / 500 / 1000 智能体运行并采样帧率。
# 运行：godot --path . --resolution 1280x720 -s tools/bench_flowfield.gd
# 关闭垂直同步，输出 BENCH 行；成功结束输出 BENCH_DONE。

const COUNTS := [200, 500, 1000]
const WARMUP_FRAMES := 60
const SAMPLE_FRAMES := 180
const SETTLE_FRAMES := 30

var _main = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	_main = scene
	await process_frame
	await process_frame
	var viewport_size := root.get_visible_rect().size
	print("BENCH viewport=%dx%d vsync=disabled" % [viewport_size.x, viewport_size.y])
	for count in COUNTS:
		_main.set_agent_count(count)
		_main.set_view_mode("flow")
		_main.set_show("arrows", true)
		_main.set_show("numbers", false)
		for i in WARMUP_FRAMES:
			await process_frame
		var last := Time.get_ticks_usec()
		var sample_start := last
		var worst_usec := 0
		for i in SAMPLE_FRAMES:
			await process_frame
			var now := Time.get_ticks_usec()
			worst_usec = maxi(worst_usec, now - last)
			last = now
		var elapsed := float(last - sample_start) / 1000000.0
		var avg_fps := float(SAMPLE_FRAMES) / maxf(elapsed, 0.0001)
		var sim = _main.sim
		var step_ms: float = sim.step_ms()
		var budget_pct := step_ms / (1000.0 / 30.0) * 100.0
		print("BENCH agents=%d avg_fps=%.1f worst_frame_ms=%.1f logic_step_ms=%.2f logic_budget=%.0f%% build_ms=%.2f" % [
			count, avg_fps, float(worst_usec) / 1000.0, step_ms, budget_pct, sim.build_ms()])
		# 让渲染线程/GPU 在下一档前回到稳定状态。
		for i in SETTLE_FRAMES:
			await process_frame
	print("BENCH_DONE")
	quit(0)
