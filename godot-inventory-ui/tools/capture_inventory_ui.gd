extends SceneTree

# Usage:
#   godot --path . -s tools/capture_inventory_ui.gd -- --shots
#   godot --path . --fixed-fps 30 -s tools/capture_inventory_ui.gd -- --video
#
# Screenshots are rendered through a 1920x1080 SubViewport with a 1280x720
# logical canvas override. Video is captured at 30 fps into /tmp/inv_ui_frames.

const SHOT_DIR := "res://docs/media/screenshots"
const FRAME_DIR := "/tmp/inv_ui_frames"
const VIDEO_FRAMES := 360

var vp: SubViewport
var main_scene: Control
var ui: BackpackUI
var _fps_samples: Array[float] = []


func _initialize() -> void:
	call_deferred("_run")


func _setup_viewport(mode: String) -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	main_scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main_scene)
	ui = main_scene.get("ui")


func _save_shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path(SHOT_DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(name)
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " ", img.get_size())


func _sample_fps(seconds: float = 3.0) -> void:
	await create_timer(1.5).timeout
	var n := int(seconds / 0.5)
	for i in range(n):
		await create_timer(0.5).timeout
		_fps_samples.append(Engine.get_frames_per_second())
	var total := 0.0
	var mn := 9999.0
	for s in _fps_samples:
		total += s
		mn = minf(mn, s)
	var avg := total / maxf(1.0, float(_fps_samples.size()))
	print("FPS samples=", _fps_samples, " avg=", avg, " min=", mn)
	var f := FileAccess.open(ProjectSettings.globalize_path("res://docs/media/fps.txt"), FileAccess.WRITE)
	if f != null:
		f.store_line("capture: SubViewport 1920x1080, 2D canvas 1280x720 (1.5x)")
		f.store_line("renderer: GL Compatibility / OpenGL")
		f.store_line("gpu: %s" % RenderingServer.get_video_adapter_name())
		f.store_line("cpu: %s" % OS.get_processor_name())
		f.store_line("samples_fps: %s" % str(_fps_samples))
		f.store_line("avg_fps: %.2f" % avg)
		f.store_line("min_fps: %.2f" % mn)
		f.store_line("draw_calls: %d" % int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		f.store_line("measured_after: 1.5s warmup, 3s sampling, backpack open, idle")
		f.close()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var video := args.has("--video")
	_setup_viewport("video" if video else "shots")
	await create_timer(0.8).timeout
	await _sample_fps(3.0)
	if video:
		await _capture_video()
	else:
		await _capture_shots()
	print("CAPTURE_DONE")
	quit()


func _capture_shots() -> void:
	await _save_shot("01_overview_1920x1080.png")

	ui.hover_index(8)
	await create_timer(0.28).timeout
	await _save_shot("02_tooltip_1920x1080.png")
	ui.clear_hover()
	await create_timer(0.2).timeout

	ui.select_item_by_id("jiuzhuan_pill", true)
	await create_timer(0.3).timeout
	await _save_shot("03_selected_detail_1920x1080.png")

	ui.grid.clear_selection()
	ui.paper_doll.get_slot("necklace").press_for_test()
	await create_timer(0.3).timeout
	await _save_shot("04_equipment_detail_1920x1080.png")
	ui.detail.close_card()
	await create_timer(0.2).timeout

	ui.switch_page(2)
	await create_timer(0.35).timeout
	await _save_shot("05_page_two_1920x1080.png")

	ui.switch_page(1)
	ui.set_category("装备")
	await create_timer(0.35).timeout
	await _save_shot("06_filter_equipment_1920x1080.png")

	ui.set_category("全部")
	ui.select_item_by_id("huichun_pill", true)
	await create_timer(0.2).timeout
	ui.use_current()
	await create_timer(0.18).timeout
	await _save_shot("07_use_feedback_1920x1080.png")
	await create_timer(1.8).timeout

	ui.switch_page(4)
	await create_timer(0.35).timeout
	await _save_shot("08_empty_page_1920x1080.png")

	ui.switch_page(1)
	ui.select_item_by_id("huichun_pill", true)
	await create_timer(0.2).timeout
	ui.request_discard_current()
	await create_timer(0.25).timeout
	await _save_shot("09_discard_confirm_1920x1080.png")
	ui.confirm.cancel()
	await create_timer(0.25).timeout

	ui.select_item_by_id("huichun_pill", true)
	await create_timer(0.15).timeout
	ui.sort_current_page()
	await create_timer(0.45).timeout
	ui.detail.close_card()
	await create_timer(0.2).timeout
	await _save_shot("10_sorted_1920x1080.png")

	ui.side_nav.click_for_test("alchemy")
	await create_timer(0.35).timeout
	await _save_shot("11_placeholder_1920x1080.png")
	ui.placeholder.hide_overlay()
	await create_timer(0.3).timeout

	ui.close_panel()
	await create_timer(0.45).timeout
	await _save_shot("12_closed_1920x1080.png")


func _capture_video() -> void:
	var dir := FRAME_DIR
	DirAccess.make_dir_recursive_absolute(dir)
	# clean previous frames
	var old := DirAccess.open(dir)
	if old != null:
		old.list_dir_begin()
		var fname := old.get_next()
		while fname != "":
			if fname.ends_with(".jpg") or fname.ends_with(".png"):
				old.remove(fname)
			fname = old.get_next()
		old.list_dir_end()

	var events := {
		12: func() -> void: ui.hover_index(8),
		46: func() -> void: ui.hover_index(9),
		76: func() -> void:
			ui.clear_hover()
			ui.select_item_by_id("huichun_pill", true),
		116: func() -> void:
			ui.detail.close_card()
			ui.switch_page(2),
		150: func() -> void:
			ui.switch_page(1)
			ui.set_category("装备"),
		186: func() -> void:
			ui.set_category("全部"),
		200: func() -> void: ui.select_item_by_id("huichun_pill", true),
		228: func() -> void: ui.use_current(),
		258: func() -> void: ui.sort_current_page(),
		292: func() -> void: ui.switch_page(4),
		316: func() -> void: ui.switch_page(1),
		330: func() -> void: ui.close_panel(),
		346: func() -> void: ui.open_panel(true),
	}
	var frame := 0
	while frame < VIDEO_FRAMES:
		if events.has(frame):
			events[frame].call()
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_jpg("%s/frame_%04d.jpg" % [dir, frame], 0.92)
		if frame % 60 == 0:
			print("video frame ", frame)
		frame += 1
		await process_frame
	print("VIDEO_DONE frames=", VIDEO_FRAMES)
