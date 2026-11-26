extends SceneTree

# Live-window QA probe at 1280×720 (real GPU, no offscreen Supersampling):
#  * measures idle / rope FPS by wall clock;
#  * exercises the actual screen→ray click/drag path;
#  * verifies the undo retract finishes and removes a control point;
#  * saves a live 1280×720 screenshot with FPS + draw calls visible.
#   godot --path godot-knotline-puzzle --resolution 1280x720 -s tools/probe_live.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT := "res://docs/shots/08_live_1280.png"
const Paths := preload("res://tools/demo_paths.gd")

var game: KnotGame


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	Engine.max_fps = 0
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as KnotGame
	root.add_child(game)
	await _frames(50)
	game.debug_set_capture_mode(false)
	game.debug_clear_toast()

	var idle: Dictionary = await _measure(2.5)
	print("LIVE_IDLE fps=%.1f draws=%d" % [idle["fps"], idle["draws"]])

	# Screen-space click + drag through the real ray code.
	game.debug_load_level(0)
	game.debug_clear_toast()
	await _frames(4)
	var start_world := game.world.start_anchor_visible_position()
	var start_screen := game.camera_rig.screen_position(start_world)
	game.debug_screen_click(start_screen)
	await _frames(2)
	var p1: Array[Vector3] = Paths.for_level(game.levels[0])
	for i in range(1, mini(9, p1.size())):
		var wp: Vector3 = p1[i]
		if game.camera_rig.is_behind(wp):
			continue
		game.debug_screen_drag(game.camera_rig.screen_position(wp))
		await _frames(1)
	var after_click: Dictionary = game.debug_state()
	print("LIVE_SCREEN_DRAW started=%s points=%d steps=%d" % [str(game.started), int(after_click["points"]), int(after_click["steps"])])
	var before_undo := int(after_click["steps"])
	game.drawing = false
	game.debug_undo()
	await create_timer(0.4).timeout
	var after_undo: Dictionary = game.debug_state()
	print("LIVE_UNDO before=%d after=%d ok=%s" % [before_undo, int(after_undo["steps"]), str(int(after_undo["steps"]) < before_undo)])

	# Full wrap for the live performance shot.
	var wrap_done: Array[Vector3] = Paths.for_level(game.levels[0])
	if wrap_done.size() > 1:
		wrap_done.remove_at(wrap_done.size() - 1)
	game.debug_load_level(0)
	game.debug_clear_toast()
	game.debug_set_path(wrap_done, false)
	game.debug_set_elapsed(41.0)
	game.debug_set_camera(-52.0, 33.0, 7.4, Vector3(0.15, 0.75, 0.3))
	await _frames(80)
	var perf: Dictionary = await _measure(2.5)
	print("LIVE_ROPE fps=%.1f draws=%d" % [perf["fps"], perf["draws"]])
	var st: Dictionary = game.debug_state()
	print("LIVE_STATE steps=%d segs=%d win=%s" % [int(st["steps"]), int(st["segments"]), str(st["win"])])
	var sun := game.world.get_node_or_null("Sun") as DirectionalLight3D
	print("LIVE_SHADOW enabled=%s" % str(sun.shadow_enabled if sun != null else false))
	game.debug_set_debug(true)
	await _frames(15)
	var dbg_perf: Dictionary = await _measure(2.0)
	print("LIVE_DEBUG fps=%.1f draws=%d" % [dbg_perf["fps"], dbg_perf["draws"]])
	game.aim_root.visible = false
	game.set_process(false)
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT)
	img.save_png(path)
	print("LIVE_SHOT %s %s" % [path, str(img.get_size())])
	print("KNOTLINE_LIVE_OK fps=%.1f draws=%d" % [perf["fps"], perf["draws"]])
	game.set_process(true)
	game.queue_free()
	await _frames(2)
	quit(0)


func _measure(seconds: float) -> Dictionary:
	var start := Time.get_ticks_usec()
	var frames := 0
	while float(Time.get_ticks_usec() - start) / 1_000_000.0 < seconds:
		await process_frame
		frames += 1
	var elapsed := float(Time.get_ticks_usec() - start) / 1_000_000.0
	return {
		"fps": float(frames) / maxf(0.001, elapsed),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
	}


func _frames(n: int) -> void:
	for i in n:
		await process_frame
