extends SceneTree

# Real-GPU FPS probe (GL Compatibility, Intel HD).
#   godot --path . -s tools/probe_pixel_vfx.gd
# 1) the actual game in a 1280x720 window;
# 2) a 1920x1080 offscreen render (Mac display is smaller than 1080p).
# Effects fire continuously. Writes docs/perf.json.

const SECONDS := 4.0
var _samples: Array[float] = []

func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await create_timer(0.6).timeout
	await _warmup(main)
	var r720 := await _measure(main, "720p_window")
	main.queue_free()
	await process_frame
	await create_timer(0.3).timeout

	DisplayServer.window_set_size(Vector2i(640, 360))
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	var main2 = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main2)
	await process_frame
	await create_timer(0.6).timeout
	main2.set_hud_ui_scale(1.5)
	await _warmup(main2)
	var r1080 := await _measure(main2, "1080p_offscreen")

	var data := {
		"device": RenderingServer.get_video_adapter_name(),
		"driver": "OpenGL 4.1 Compatibility",
		"resolution_720p": r720,
		"resolution_1080p": r1080,
		"note": "1920x1080 is rendered offscreen because the test Mac's display is 1440x900; the world is integer-scaled 3x.",
	}
	var f := FileAccess.open("res://docs/perf.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "  "))
		f.close()
	print("PIXEL_VFX_FPS_OK 720p=%.1f 1080p=%.1f" % [r720["avg"], r1080["avg"]])
	quit(0)

func _warmup(main) -> void:
	# Upload every sheet and compile the canvas pipeline before timing.
	main.trigger_slash()
	await create_timer(0.5).timeout
	main.trigger_fireball()
	await create_timer(1.0).timeout
	main.trigger_freeze()
	await create_timer(0.8).timeout
	main.trigger_coins()
	await create_timer(0.8).timeout
	main.reset_all()
	await create_timer(0.4).timeout

func _measure(main, label: String) -> Dictionary:
	await create_timer(0.5).timeout
	_samples.clear()
	var frames := 0
	var elapsed := 0.0
	var last := Time.get_ticks_usec()
	var effects := 0
	while elapsed < SECONDS:
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1_000_000.0
		last = now
		elapsed += dt
		frames += 1
		var fps := Engine.get_frames_per_second()
		if fps > 0:
			_samples.append(float(fps))
		if frames % 24 == 0:
			effects += 1
			match effects % 4:
				0: main.trigger_slash()
				1: main.trigger_fireball()
				2: main.trigger_freeze()
				3: main.trigger_coins()
	var avg := float(frames) / elapsed
	var min_fps := 999.0
	for s in _samples:
		min_fps = minf(min_fps, s)
	print("PROBE %s frames=%d sec=%.2f avg=%.1f min_sample=%.1f root=%s" % [
		label, frames, elapsed, avg, min_fps, str(root.size)])
	return {"avg": snappedf(avg, 0.1), "min_sample": snappedf(min_fps, 0.1),
		"frames": frames, "seconds": snappedf(elapsed, 0.01)}
