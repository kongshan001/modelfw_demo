extends SceneTree

# 10-second 1280×720 gameplay film source on the real GPU.
# Draws level 2 through the same rope API as the mouse, holds the finished
# knot, then shows the win card. Run with --fixed-fps 30 so every captured
# frame advances simulation time by exactly 1/30 s; encode the 300 frames at
# 30 fps. (The frame readback is slower than real time, which is fine.)
#   godot --path godot-knotline-puzzle --resolution 1280x720 --fixed-fps 30 -s tools/capture_video.gd

const MAIN_SCENE := "res://scenes/main.tscn"
const FRAME_DIR := "/tmp/knotline_video_frames"
const VIEW := Vector2i(1280, 720)
const FPS := 30
const TOTAL_FRAMES := 300
const DRAW_START := 0.9
const DRAW_END := 7.35
const FINISH_AT := 8.45
const Paths := preload("res://tools/demo_paths.gd")

var vp: SubViewport
var game: KnotGame
var frames := 0
var dense: Array[Vector3] = []
var cursor := 0
var begun := false
var finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(VIEW)
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
	game = (load(MAIN_SCENE) as PackedScene).instantiate() as KnotGame
	vp.add_child(game)
	await _frames(40)
	game.debug_set_capture_mode(true)
	game.debug_load_level(1)
	game.debug_clear_toast()
	await _frames(4)
	game.debug_clear_toast()
	var path: Array[Vector3] = Paths.for_level(game.levels[1])
	dense = _densify(path, 0.09)
	game.hud.toast("第 2 结 · 双环庭 —— 绕住两柱，让绳子一上一下", 2.5)
	game.debug_begin_path()
	var wall_start := Time.get_ticks_usec()
	for frame_idx in TOTAL_FRAMES:
		var t := float(frame_idx) / float(FPS)
		if t >= DRAW_START and not begun:
			begun = true
			game.debug_begin_path()
			if not dense.is_empty():
				game.debug_append_point(dense[0])
				cursor = 1
		if begun and cursor < dense.size():
			var frac := clampf((t - DRAW_START) / (DRAW_END - DRAW_START), 0.0, 1.0)
			var target_idx := int(frac * float(dense.size() - 1))
			while cursor <= target_idx and cursor < dense.size():
				game.debug_append_point(dense[cursor])
				cursor += 1
		if cursor >= dense.size() and t >= FINISH_AT and not finished:
			finished = true
			game.debug_finish_path()
		game.camera_rig.orbit(1.5 / float(FPS), 0.0)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_jpg("%s/frame_%04d.jpg" % [FRAME_DIR, frames], 0.92)
		frames += 1
	var wall := float(Time.get_ticks_usec() - wall_start) / 1_000_000.0
	print("KNOTLINE_VIDEO_FRAMES_OK frames=%d video_seconds=%.2f wall=%.1fs" % [frames, float(frames) / float(FPS), wall])
	print("KNOTLINE_VIDEO_PATH points=%d steps=%d" % [dense.size(), cursor])
	game.queue_free()
	vp.queue_free()
	await _frames(2)
	quit(0)


func _densify(path: Array[Vector3], step: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if path.is_empty():
		return out
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var n := maxi(1, int(ceil(a.distance_to(b) / step)))
		for k in n:
			out.append(a.lerp(b, float(k) / float(n)))
	out.append(path[path.size() - 1])
	return out


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
