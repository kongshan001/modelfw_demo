extends SceneTree

# GPU 实拍（1920×1080）：
#   01 初始叠加态/熵热力
#   02 传播中的波前（只保留最近一步的高亮）
#   03 矛盾 → 回溯（红框 + 事件流）
#   04 算法视图完成态
#   05 成品地图（hero）
#   06 18×10 大图成品
# 用法：godot --path godot-wfc --resolution 1280x720 -s tools/screenshot_wfc.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)
const DEMO_SEED := "2718"

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	var atlas_wait := 0
	while not _scene.get_board().is_atlas_ready() and atlas_wait < 600:
		await process_frame
		atlas_wait += 1
	if not _scene.get_board().is_atlas_ready():
		printerr("screenshot: tile atlas did not become ready")
	else:
		print("ATLAS_OK wait_frames=", atlas_wait)
	await create_timer(0.20).timeout

	# 01 初始：160 格 × 14 候选，熵热力最亮。
	_scene.new_map(DEMO_SEED, 16, 10, true, false)
	_scene.set_paused(true)
	_scene.set_speed_value(20.0)
	_scene.set_view_mode("algo")
	_scene.get_board().set_process(false)
	await create_timer(0.20).timeout
	await _shot("01_superposition_1920")

	# 02 中盘：先走到 55 步，再清掉旧波前，只展示最新一次传播。
	var board = _scene.get_board()
	for i in 55:
		_scene.step_once()
	await create_timer(0.05).timeout
	for attempt in 24:
		board.reset_overlays()
		_scene.step_once()
		var event: Dictionary = _scene.get_last_event()
		if String(event["event"]) == "collapse" and event["wave"].size() > 0:
			break
	_scene.set_paused(true)
	board.set_process(false)
	await create_timer(0.15).timeout
	await _shot("02_wavefront_1920")

	# 03 回溯：继续走到第一次“矛盾 → 快照回滚”，只保留这张红框事件。
	var backtrack_found := false
	var guard := 0
	while not _scene.get_solver().finished and guard < 2000:
		_scene.step_once()
		guard += 1
		if String(_scene.get_last_event()["event"]) == "backtrack":
			backtrack_found = true
			break
	if backtrack_found:
		board.reset_overlays()
		board.mark_event(_scene.get_last_event())
		board.set_process(false)
		_scene.set_paused(true)
		await create_timer(0.15).timeout
		await _shot("03_backtrack_1920")
	else:
		printerr("screenshot: no backtrack event found for ", DEMO_SEED)

	# 04 算法视图完成态。
	var finish_guard := 0
	while not _scene.get_solver().finished and finish_guard < 3000:
		_scene.step_once()
		finish_guard += 1
	board.reset_overlays()
	_scene.set_paused(true)
	board.set_process(false)
	await create_timer(0.15).timeout
	await _shot("04_complete_algorithm_1920")

	# 05 成品地图（同一张图，保留萤火/水光）。
	_scene.set_view_mode("map")
	board.set_process(true)
	await create_timer(0.45).timeout
	board.set_process(false)
	await _shot("05_finished_map_1920")

	# 06 大图：18×10，另一颗种子，完整步进后再切成品。
	_scene.new_map("17", 18, 10, true, false)
	_scene.set_paused(true)
	board.set_process(false)
	var large_guard := 0
	while not _scene.get_solver().finished and large_guard < 4000:
		_scene.step_once()
		large_guard += 1
	_scene.set_view_mode("map")
	board.set_process(true)
	await create_timer(0.35).timeout
	board.set_process(false)
	await _shot("06_large_map_1920")

	print("WFC_SHOTS_OK")
	quit(0)


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_size())
