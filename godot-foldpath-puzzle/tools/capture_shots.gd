extends SceneTree

# Real-GPU 1920x1080 screenshot rig. The scene renders into a 1920x1080
# SubViewport while the HUD lays out at 1280x720 and upscales 1.5x.
#   godot --path godot-foldpath-puzzle --resolution 1280x720 -s tools/capture_shots.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT_DIR := "res://docs/shots"

var vp: SubViewport
var game: FoldGame
var shots := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var abs_dir := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.gui_disable_input = true
	root.add_child(vp)
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as FoldGame
	vp.add_child(game)
	await _frames(24)
	game.debug_set_capture_mode(true)
	game.debug_clear_toast()

	# 01 — level 1 overview: the linked terrace and the lower court path.
	await _setup_level(0)
	await _frames(6)
	await _shot("01_l1_overview.png", "L1 overview")

	# 02 — the aligned seam: fox at the doorway, hint ring, exact connection.
	game.debug_clear_toast()
	game.debug_set_hint(1)
	game.debug_clear_toast()
	game.debug_set_player("u")
	await _frames(6)
	await _shot("02_l1_fold_connection.png", "L1 aligned seam")

	# 03 — level 2, bridge paused mid-turn, rider on the rotating end.
	await _setup_level(1)
	game.debug_instant_move("o")
	game.debug_set_angle("bridge", 45.0)
	game.select_platform("bridge")
	game.debug_set_hint(1)
	game.debug_clear_toast()
	await _frames(8)
	await _shot("03_l2_rotation.png", "L2 bridge mid-rotation")

	# 04 — level 2, fox walking the bridge ribbon.
	await _setup_level(1)
	game.debug_instant_move("i")
	game.select_platform("bridge")
	game.debug_clear_toast()
	game.debug_walk_to("o")
	await create_timer(0.24).timeout
	await _shot("04_l2_walking.png", "L2 walking the bridge")
	await _wait_until(func() -> bool: return not game.moving, 2.0)

	# 05 — level 3 loop: ring turned, ring/spire seam open.
	await _setup_level(2)
	game.debug_instant_move("r2")
	game.debug_set_angle("ring", 90.0)
	game.select_platform("ring")
	game.debug_clear_toast()
	await _frames(10)
	await _shot("05_l3_loop.png", "L3 ring/spire seam")

	# 06 — win card with real rotations / moves recorded.
	await _setup_level(2)
	game.debug_instant_move("r2")
	await _rotate_steps("ring", 6)
	game.debug_instant_move("t2")
	await _rotate_steps("spire", 6)
	game.debug_instant_move("g")
	await _wait_until(func() -> bool: return game.win, 2.0)
	await create_timer(0.55).timeout
	await _shot("06_win.png", "L3 win card")

	# 07 — debug overlay: projections, threshold circles, angles, FPS/draws.
	await _setup_level(2)
	game.debug_instant_move("r2")
	game.debug_set_angle("ring", 90.0)
	game.select_platform("ring")
	game.debug_set_debug(true)
	game.debug_clear_toast()
	vp.msaa_3d = Viewport.MSAA_DISABLED
	await _frames(120)
	await _shot("07_debug.png", "L3 debug overlay")

	print("FOLDPATH_CAPTURE_OK shots=%d dir=%s fps=%d" % [shots, abs_dir, Engine.get_frames_per_second()])
	game.queue_free()
	vp.queue_free()
	await _frames(2)
	quit(0)


func _setup_level(index: int) -> void:
	game.debug_set_debug(false)
	game.debug_load_level(index)
	game.debug_set_capture_mode(true)
	game.debug_clear_toast()
	game.debug_set_zoom(1.0)
	await _frames(4)


func _rotate_steps(pid: String, count: int) -> void:
	game.select_platform(pid)
	for i in count:
		game.rotate_selected(1)
		await _wait_until(func() -> bool: return not game.rotating, 1.0)
	await _frames(1)


func _shot(name: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	var err := img.save_png(path)
	shots += 1
	var st := game.debug_state()
	print("SHOT %s %s size=%s err=%d fps=%d draws=%d links=%d win=%s" % [
		name, label, str(img.get_size()), err, Engine.get_frames_per_second(),
		int(st.get("draws", 0)), int(st.get("link_count", 0)), str(st.get("win", false))
	])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait_until(pred: Callable, timeout := 3.0) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(timeout * 1000.0):
		if bool(pred.call()):
			return true
		await process_frame
	return bool(pred.call())
