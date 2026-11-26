extends SceneTree

# Live-window QA probe at 1280x720 (real GPU, no offscreen supersampling):
#  * measures idle / active FPS by wall clock;
#  * exercises the real screen→node click and screen→platform drag paths;
#  * verifies undo, reset, win and the debug overlay;
#  * saves a live 1280x720 screenshot with FPS + draw calls visible.
#   godot --path godot-foldpath-puzzle --resolution 1280x720 -s tools/probe_live.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT := "res://docs/shots/08_live_1280.png"

var game: FoldGame


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	Engine.max_fps = 0
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as FoldGame
	root.add_child(game)
	await _frames(60)
	game.debug_clear_toast()

	var idle := await _measure(2.5)
	print("LIVE_IDLE fps=%.1f draws=%d" % [idle["fps"], idle["draws"]])

	# Real screen click on a path node.
	game.debug_load_level(0)
	await _frames(8)
	var u_screen := game.debug_node_screen("u")
	game.debug_screen_click(u_screen)
	var walked: bool = await _wait_until(func() -> bool: return not game.moving, 3.0)
	print("LIVE_CLICK node=u walked=%s at=%s" % [str(walked), game.current_node])
	_check(walked and game.current_node == "u", "live click walk to u")

	# Real screen drag on the rotating bridge (L2).
	game.debug_load_level(1)
	await _frames(8)
	game.debug_clear_toast()
	var pivot: Vector3 = FoldMath.vec3((FoldLevel.platform_map(game.level)["bridge"] as Dictionary)["pivot"])
	var p_screen: Vector2 = game.cam.screen_of(pivot)
	game.debug_screen_drag(p_screen + Vector2(-70, 0), p_screen + Vector2(80, 0))
	var settled: bool = await _wait_until(func() -> bool: return not game.rotating, 1.0)
	var angle := float(game.angles.get("bridge", 0.0))
	print("LIVE_DRAG bridge_angle=%.1f rotating=%s" % [angle, str(game.rotating)])
	_check(settled and absf(angle - 90.0) < 0.01, "live drag rotates the bridge to 90")
	_check(game.actions.size() >= 1, "live drag records an undo action")

	# Undo the drag rotation.
	game.undo()
	var undone: bool = await _wait_until(func() -> bool: return not game.rotating, 1.0)
	print("LIVE_UNDO angle=%.1f ok=%s" % [float(game.angles.get("bridge", 0.0)), str(undone)])
	_check(undone and absf(float(game.angles.get("bridge", 0.0))) < 0.01, "live undo restores the bridge")

	# Reset returns to the initial state.
	game.reset_level()
	await _frames(6)
	_check(game.current_node == "s" and game.actions.is_empty(), "live reset restores start")

	# Complete L1 through the real click route and capture the end state.
	game.debug_load_level(0)
	await _frames(6)
	var g_screen := game.debug_node_screen("g")
	game.debug_screen_click(g_screen)
	var won: bool = await _wait_until(func() -> bool: return game.win, 4.5)
	print("LIVE_WIN reached=%s node=%s" % [str(won), game.current_node])
	_check(won and game.current_node == "g", "live click route wins L1")

	# Debug overlay + live performance screenshot (solved L3 is the busiest).
	game.debug_load_level(2)
	await _frames(8)
	game.debug_instant_move("r2")
	game.debug_set_angle("ring", 90.0)
	game.debug_instant_move("t2")
	game.debug_set_angle("spire", 90.0)
	await _frames(12)
	game.debug_set_debug(true)
	game.debug_clear_toast()
	await _frames(30)
	var active := await _measure(2.5)
	print("LIVE_ACTIVE fps=%.1f draws=%d links=%d" % [active["fps"], active["draws"], game.links.size()])
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT)
	img.save_png(path)
	print("LIVE_SHOT %s size=%s" % [path, str(img.get_size())])

	# 1920x1080 window support sanity check.
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _frames(20)
	print("LIVE_1920 window=%s viewport=%s" % [str(DisplayServer.window_get_size()), str(root.get_visible_rect().size)])
	var big := await _measure(1.5)
	print("LIVE_1920 fps=%.1f draws=%d" % [big["fps"], big["draws"]])
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _frames(5)

	print("FOLDPATH_LIVE_OK fps=%.1f draws=%d" % [active["fps"], active["draws"]])
	game.queue_free()
	await _frames(2)
	quit(0)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("LIVE_CHECK ok: ", msg)
	else:
		printerr("FOLDPATH LIVE FAIL: ", msg)
		quit(1)


func _measure(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var frames := 0
	while float(Time.get_ticks_usec() - start) / 1_000_000.0 < seconds:
		await process_frame
		frames += 1
	var dt := float(Time.get_ticks_usec() - start) / 1_000_000.0
	return {
		"fps": float(frames) / dt,
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	}


func _wait_until(pred: Callable, timeout := 3.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout * 1000.0):
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())


func _frames(n: int) -> void:
	for i in n:
		await process_frame
