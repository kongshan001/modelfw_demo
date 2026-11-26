extends SceneTree

# 10-second 1280x720 gameplay film on the real GPU.
# Plays level 2 for real through the same walk/rotate APIs as the mouse:
# board the bridge, turn it in 15-degree steps while riding, cross the fold,
# reach the goal. Run with --fixed-fps 30 so each captured frame advances
# simulation time by exactly 1/30 s; encode 300 frames at 30 fps.
#   godot --path godot-foldpath-puzzle --resolution 1280x720 --fixed-fps 30 -s tools/capture_video.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const FRAME_DIR := "/tmp/foldpath_video_frames"
const VIEW := Vector2i(1280, 720)
const FPS := 30
const TOTAL_FRAMES := 300

var vp: SubViewport
var game: FoldGame
var frames := 0
var started_walk := false
var rotated_hint := false
var goal_requested := false
var link_toast_shown := false
var next_rot_at := 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(30, 30))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_clean_frames()
	vp = SubViewport.new()
	vp.size = VIEW
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.gui_disable_input = true
	root.add_child(vp)
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as FoldGame
	vp.add_child(game)
	await _frames(36)
	game.debug_set_capture_mode(true)
	game.debug_load_level(1)
	game.debug_clear_toast()
	await _frames(3)
	game.debug_clear_toast()
	game.elapsed = 0.0
	game.hud.toast("第 2 程 · 旋桥庭 —— 先登上旋桥，再把它转向对岸。", 2.8)
	var wall_start := Time.get_ticks_usec()

	for frame_idx in TOTAL_FRAMES:
		var t := float(frame_idx) / float(FPS)
		# 0.8 s: board the bridge.
		if not started_walk and t >= 0.8:
			started_walk = true
			game.debug_walk_to("o")
		# Arrival on the far end: show the rotation hint once.
		if started_walk and not rotated_hint and not game.moving and game.current_node == "o" and t > 1.6:
			rotated_hint = true
			game.debug_set_hint(1)
			next_rot_at = t + 0.3
		# Turn the bridge in visible 15-degree steps while the fox rides it.
		if rotated_hint and not goal_requested and game.current_node == "o" and not game.moving:
			var angle := float(game.angles.get("bridge", 0.0))
			if angle < 89.99 and not game.rotating and t >= next_rot_at:
				game.select_platform("bridge")
				game.rotate_selected(1)
				next_rot_at = t + 0.46
			if angle >= 89.99 and not game.rotating and not link_toast_shown:
				link_toast_shown = true
				game.hud.toast("屏幕上对齐了——折环亮起。", 1.7)
			if angle >= 89.99 and not game.rotating and t > next_rot_at + 0.35:
				goal_requested = true
				game.debug_walk_to("g")
		game.hud.update_hud(1.0 / float(FPS))
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_jpg("%s/frame_%04d.jpg" % [FRAME_DIR, frames], 0.92)
		frames += 1
	var wall := float(Time.get_ticks_usec() - wall_start) / 1_000_000.0
	print("FOLDPATH_VIDEO_FRAMES_OK frames=%d video_seconds=%.2f wall=%.1fs" % [frames, float(frames) / float(FPS), wall])
	print("FOLDPATH_VIDEO_STATE node=%s win=%s bridge=%.0f rotations=%d moves=%d" % [
		game.current_node, str(game.win), float(game.angles.get("bridge", 0.0)), game.rotations, game.moves
	])
	game.queue_free()
	vp.queue_free()
	await _frames(2)
	quit(0)


func _clean_frames() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	var d := DirAccess.open(FRAME_DIR)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".jpg"):
			d.remove(f)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
