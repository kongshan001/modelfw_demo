extends SceneTree

# 1920×1080 截图 + 10 秒 30fps 演示序列（PNG 帧，随后由 ffmpeg 编码）。
# 运行：godot --path . --resolution 1280x720 -s tools/capture_flowfield.gd
# 输出：docs/screenshots/*.png、capture_frames/frame_*.png

const LOGICAL_SIZE := Vector2i(1280, 720)
const CAPTURE_SIZE := Vector2i(1920, 1080)
const SHOT_DIR := "res://docs/screenshots"
const FRAME_DIR := "res://capture_frames"
const VIDEO_FRAMES := 300
const FIXED_DT := 1.0 / 30.0

var _viewport: SubViewport
var _main = null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	_viewport = SubViewport.new()
	_viewport.size = CAPTURE_SIZE
	_viewport.size_2d_override = LOGICAL_SIZE
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_viewport)
	_main = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(_main)
	await process_frame
	await process_frame
	_main.set_manual_capture(true)

	await _capture_stills()
	await _capture_video()

	_main.queue_free()
	_viewport.queue_free()
	await process_frame
	print("CAPTURE_DONE")
	quit(0)


func _advance(steps: int) -> void:
	for i in steps:
		_main.advance_logic(FIXED_DT)


func _capture(file_path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	if image.is_empty():
		push_error("空截图：" + file_path)
		return
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(file_path)
	print("SHOT " + file_path + " " + str(image.get_size()))


func _capture_stills() -> void:
	# 1. 流场总览：C 形回廊 + 500 智能体绕障。
	_main.set_map_size("medium")
	_main.set_agent_count(500)
	_main.set_view_mode("flow")
	_main.set_show("numbers", false)
	_main.set_show("arrows", true)
	_main.set_show("trails", true)
	_main.set_show("agents", true)
	_advance(150)
	await _capture(SHOT_DIR + "/01_flow_500.png")

	# 2. 积分场：热力色 + BFS 数值。
	_main.set_view_mode("integration")
	_main.set_show("numbers", true)
	_advance(10)
	await _capture(SHOT_DIR + "/02_integration_500.png")

	# 3. 代价场：刚绘制的障碍墙 + 数值。
	_main.set_view_mode("cost")
	_main.set_show("numbers", true)
	_main.set_show("arrows", false)
	var cols: int = _main.sim.field.cols
	var rows: int = _main.sim.field.rows
	_main.sim.apply_brush_line(
		Vector2i(roundi(cols * 0.70), roundi(rows * 0.24)),
		Vector2i(roundi(cols * 0.70), roundi(rows * 0.62)), "obstacle")
	_main.sim.apply_brush_line(
		Vector2i(roundi(cols * 0.70), roundi(rows * 0.62)),
		Vector2i(roundi(cols * 0.84), roundi(rows * 0.62)), "obstacle")
	_main.ui.notify("绘制障碍 · 流场实时重建")
	_advance(4)
	await _capture(SHOT_DIR + "/03_cost_edit.png")

	# 4. 大地图 + 1000 智能体。
	_main.load_sample_map()
	_main.set_map_size("large")
	_main.set_agent_count(1000)
	_main.set_view_mode("flow")
	_main.set_show("numbers", false)
	_main.set_show("arrows", true)
	_advance(120)
	await _capture(SHOT_DIR + "/04_flow_1000_large.png")

	# 5. 随机地图 + 目标切换后的流场。
	_main.random_map()
	_main.set_agent_count(500)
	_main.set_view_mode("flow")
	_advance(30)
	var goal_world: Vector2 = _main.sim.field.cell_center(
		Vector2i(_main.sim.field.cols - 5, roundi(_main.sim.field.rows * 0.5)))
	_main.sim.set_goal_world(goal_world)
	_main.ui.notify("目标切换 · 流场重算")
	_advance(40)
	await _capture(SHOT_DIR + "/05_random_goal_switch.png")


func _capture_video() -> void:
	# 回到样例地图，按 30fps 推进并逐帧截图。
	_main.load_sample_map()
	_main.set_map_size("medium")
	_main.set_agent_count(500)
	_main.set_view_mode("flow")
	_main.set_show("numbers", false)
	_main.set_show("arrows", true)
	_main.set_show("trails", true)
	_main.set_show("agents", true)
	_advance(60)

	var cols: int = _main.sim.field.cols
	var rows: int = _main.sim.field.rows
	for frame in VIDEO_FRAMES:
		if frame == 70:
			var right_goal := Vector2i(cols - 4, roundi(rows * 0.5))
			_main.sim.set_goal_world(_main.sim.field.cell_center(right_goal))
			_main.ui.notify("目标切换 → 右侧回廊 · 流场重算")
		elif frame == 160:
			_main.sim.apply_brush_line(
				Vector2i(roundi(cols * 0.62), roundi(rows * 0.30)),
				Vector2i(roundi(cols * 0.62), roundi(rows * 0.66)), "obstacle")
			_main.ui.notify("手绘障碍 · 群体绕行")
		elif frame == 230:
			var left_goal := Vector2i(roundi(cols * 0.13), roundi(rows * 0.5))
			_main.sim.set_goal_world(_main.sim.field.cell_center(left_goal))
			_main.ui.notify("目标切换 → 左侧 · 流场重算")
		_main.advance_logic(FIXED_DT)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		if image.get_size() != CAPTURE_SIZE:
			image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
		image.save_png("%s/frame_%04d.png" % [FRAME_DIR, frame])
		if frame % 30 == 0:
			print("FRAME %d/%d" % [frame, VIDEO_FRAMES])
