extends SceneTree

# Real-GPU 1920×1080 screenshot rig. The scene renders into a 1920×1080
# SubViewport while UI lays out at the 1280×720 design size and upscales 1.5×.
#   godot --path godot-knotline-puzzle --resolution 1280x720 -s tools/capture_shots.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT_DIR := "res://docs/shots"
const Paths := preload("res://tools/demo_paths.gd")

var vp: SubViewport
var game: KnotGame
var levels: Array[Dictionary] = []


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
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as KnotGame
	vp.add_child(game)
	await _frames(12)
	game.debug_set_capture_mode(true)
	levels = game.levels

	# 01 — level 1 overview
	game.debug_load_level(0)
	game.debug_clear_toast()
	await _frames(8)
	await _shot("01_overview.png", "level1 overview")

	# 02 — mid-stroke on the first loop
	var p1: Array[Vector3] = Paths.for_level(levels[0])
	var partial: Array[Vector3] = []
	for i in mini(13, p1.size()):
		partial.append(p1[i])
	game.debug_set_path(partial, false)
	game.debug_set_elapsed(18.0)
	game.debug_set_mode("draw")
	game.debug_set_hover("qing")
	if p1.size() > 13:
		game.debug_set_aim(p1[13], false)
	await _frames(6)
	await _shot("02_drawing.png", "level1 drawing")

	# 03 — wrap complete, heading to the goal pad
	var wrap_done: Array[Vector3] = p1.duplicate()
	if wrap_done.size() > 1:
		wrap_done.remove_at(wrap_done.size() - 1)
	game.debug_set_path(wrap_done, false)
	game.debug_set_elapsed(41.0)
	game.debug_clear_hover()
	game.debug_set_aim(KnotLevel.goal_point(levels[0]), true)
	await _frames(6)
	await _shot("03_wrap_done.png", "level1 wrap complete")

	# 04 — level 2 both loops + lifted self-crossing
	var p2: Array[Vector3] = Paths.for_level(levels[1])
	game.debug_load_level(1)
	game.debug_clear_toast()
	game.debug_set_path(p2, false)
	game.debug_set_elapsed(63.0)
	game.debug_clear_aim()
	await _frames(8)
	await _shot("04_double_wrap.png", "level2 both loops")

	# 05 — win card on level 2, with confetti
	game.debug_set_path(p2, false)
	game.debug_set_elapsed(78.0)
	game.debug_clear_aim()
	game.debug_finish_path()
	await create_timer(0.45).timeout
	await _shot("05_win.png", "level2 win")

	# 06 — debug overlay: samples, crossing OVER/UNDER, winding numbers
	game.debug_load_level(1)
	game.debug_clear_toast()
	game.debug_set_path(p2, false)
	game.debug_set_elapsed(63.0)
	game.debug_clear_aim()
	game.debug_set_camera(-46.0, 44.0, 8.6, Vector3(0.0, 0.6, 0.2))
	game.debug_set_debug(true)
	await _frames(10)
	await _shot("06_debug.png", "level2 debug")

	# 07 — level 2 overview before solving
	game.debug_set_debug(false)
	game.debug_load_level(1)
	game.debug_clear_toast()
	await _frames(8)
	await _shot("07_level2_overview.png", "level2 overview")

	print("KNOTLINE_CAPTURE_OK dir=", abs_dir, " fps=", Engine.get_frames_per_second())
	_cleanup()
	quit(0)


func _shot(name: String, label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	img.save_png(path)
	var st := game.debug_state()
	print("SHOT %s %s fps=%d draws=%d segs=%d steps=%d win=%s" % [
		name, label, Engine.get_frames_per_second(), int(st.get("draw_calls", 0)),
		int(st.get("segments", 0)), int(st.get("steps", 0)), str(st.get("win", false))
	])


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _cleanup() -> void:
	if vp != null:
		root.remove_child(vp)
		vp.queue_free()
	await process_frame
