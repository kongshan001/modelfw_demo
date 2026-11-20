extends SceneTree

# 真机帧率采样（窗口 1280×720，GL Compatibility）。
# 用法：godot --path godot-paper-doll --resolution 1280x720 -s tools/perf_paperdoll.gd
# 输出 PAPERDOLL_FPS_OK / PAPERDOLL_FPS_LOW，供 tools/verify.sh 判定 Intel 30fps+。


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	DisplayServer.window_move_to_foreground()
	DisplayServer.window_request_attention()
	await create_timer(1.0).timeout
	await create_timer(1.0).timeout

	var samples: Array[float] = []
	for i in 5:
		await create_timer(1.0).timeout
		samples.append(float(Engine.get_frames_per_second()))
	var total := 0.0
	var low := 999.0
	for sample in samples:
		total += sample
		low = minf(low, sample)
	var avg := total / samples.size()
	var gpu := RenderingServer.get_video_adapter_name()
	print("PAPERDOLL_FPS samples=%s avg=%.1f min=%.1f gpu=%s" % [str(samples), avg, low, gpu])
	if low >= 30.0:
		print("PAPERDOLL_FPS_OK min=%.1f avg=%.1f" % [low, avg])
		quit(0)
	else:
		printerr("PAPERDOLL_FPS_LOW min=%.1f avg=%.1f" % [low, avg])
		quit(1)
