extends SceneTree

# 固定 30fps / 300 帧（10 秒）离线录制：
#   0.4s 初始叠加态 → 20 步/秒逐步坍缩 → 完成后短暂停留算法视图 → 切换成品地图。
# 用法：godot --path godot-wfc --resolution 1280x720 -s tools/render_wfc_video.gd
# 输出：/tmp/wfc_video_frames/frame_0000.png ...；再由 tools/build_media.sh 编码。

const OUT := "/tmp/wfc_video_frames"
const SIZE := Vector2i(1280, 720)
const FPS := 30
const FRAMES := 300
const SIM_SPEED := 20.0

var _vp: SubViewport
var _scene
var _board


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	var guard := 0
	while not _scene.get_board().is_atlas_ready() and guard < 600:
		await process_frame
		guard += 1
	_board = _scene.get_board()
	_board.set_process(false)
	await create_timer(0.2).timeout

	_scene.new_map("2718", 16, 10, true, false)
	_scene.set_paused(true)
	_scene.set_speed_value(SIM_SPEED)
	_scene.set_view_mode("algo")
	_board.advance_animation(1.0 / FPS)

	var accum := 0.0
	var done_frame := -1
	var switched := false
	for frame in FRAMES:
		_board.advance_animation(1.0 / FPS)
		if frame >= 12 and not _scene.get_solver().finished:
			accum += SIM_SPEED / float(FPS)
			var steps := 0
			while accum >= 1.0 and steps < 4:
				_scene.step_once()
				accum -= 1.0
				steps += 1
			if _scene.get_solver().finished:
				done_frame = frame
		if not switched and done_frame >= 0 and frame >= done_frame + 24:
			_scene.set_view_mode("map")
			switched = true
		if not switched and frame >= FRAMES - 38:
			_scene.set_view_mode("map")
			switched = true
		await process_frame
		await RenderingServer.frame_post_draw
		var image := _vp.get_texture().get_image()
		var path := OUT + "/frame_%04d.png" % frame
		var err := image.save_png(path)
		if err != OK:
			printerr("frame save failed ", frame, ": ", err)
			quit(1)
			return
		if frame % 50 == 0:
			print("FRAME %d/%d collapsed=%d/%d event=%s" % [
				frame, FRAMES, _scene.get_solver().collapsed_cells(),
				_scene.get_solver().cell_count(), String(_scene.get_last_event()["event"])])
	print("WFC_VIDEO_FRAMES_OK done_frame=%d switched=%s final_collapsed=%d/%d" % [
		done_frame, switched, _scene.get_solver().collapsed_cells(),
		_scene.get_solver().cell_count()])
	quit(0)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			dir.remove(file_name)
