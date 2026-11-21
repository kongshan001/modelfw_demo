extends SceneTree

## 真实 GPU 帧率测试：1280×720，关垂直同步，50/100/200 体视频绕障场景。
## 运行：godot --path godot-steering --resolution 1280x720 -s tools/bench_steering.gd

var _scene
var _sim
var _ui


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame
	_sim = _scene.get_node("Sim")
	_ui = _scene.get_node("UI")
	_ui.visible = false
	_sim.seed_value = 20261121
	print("SCREEN=" + str(root.size) + "  VSYNC=" + str(DisplayServer.window_get_vsync_mode()))
	for count in [50, 100, 200]:
		_sim.target_count = count
		_sim.apply_preset("video")
		_sim.paused = false
		_sim.set_show("flow", true)
		_sim.set_show("highlight", true)
		await create_timer(2.0).timeout
		var frames := 0
		var t0 := Time.get_ticks_usec()
		while true:
			await process_frame
			frames += 1
			if Time.get_ticks_usec() - t0 >= 4000000:
				break
		var dt := (Time.get_ticks_usec() - t0) / 1000000.0
		var fps := frames / dt
		print("FPS_%03d = %.1f   (sim %.2f ms/step, %d agents, pausing=%s)"
			% [count, fps, _sim.step_ms, _sim.agents.size(), str(_sim.paused)])
		_sim.paused = true
	print("BENCH_OK")
	quit(0)
