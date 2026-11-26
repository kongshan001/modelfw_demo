extends SceneTree

# Offscreen 1920x1080 performance probe (no screenshot stalls).
#   godot --path godot-hueroll-puzzle --resolution 1280x720 -s tools/perf1080_hueroll.gd

var vp: SubViewport
var game: Node
var samples: Array[float] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.own_world_3d = true
	root.add_child(vp)
	game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	await process_frame
	await create_timer(1.5).timeout
	game.debug_load_level(3)
	await create_timer(0.4).timeout
	game.debug_apply_moves("nennennwwsswnen", true)
	await create_timer(1.5).timeout
	await _sample("garden1080", 5.0)
	game.debug_load_level(5)
	await create_timer(0.4).timeout
	game.debug_apply_moves("wnennwwwnne", true)
	await create_timer(1.5).timeout
	await _sample("rainbow1080", 5.0)
	print("HUEROLL_PERF1080_OK viewport=%s" % str(vp.size))
	quit(0)


func _sample(label: String, seconds: float) -> void:
	samples.clear()
	var t := 0.0
	while t < seconds:
		await create_timer(0.25).timeout
		t += 0.25
		samples.append(Engine.get_frames_per_second())
	var sum := 0.0
	var mn := 9999.0
	var mx := 0.0
	for v in samples:
		sum += v
		mn = minf(mn, v)
		mx = maxf(mx, v)
	var dc := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	print("PERF %s avg=%.1f min=%.1f max=%.1f draw_calls=%d" % [label, sum / samples.size(), mn, mx, dc])
