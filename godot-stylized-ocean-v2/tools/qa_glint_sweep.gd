extends SceneTree

# QA 辅助：远离海岛的开阔水面，8 个相机方位扫描太阳闪点是否可见。
# 与 qa_acceptance_stylized_ocean.gd 的固定 05 机位互补，用于排除“只是相机角度不对”。
# 用法：godot --path godot-stylized-ocean-v2 -s tools/qa_glint_sweep.gd

const SIZE := Vector2i(1280, 720)

var vp: SubViewport
var scene


func _init() -> void:
	_run()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await create_timer(0.8).timeout
	scene.set_paused(true)
	scene.set_ui_visible(false)
	scene.set_hour(11.5)
	scene.set_clouds_visible(false)
	scene.ocean.clear_ripples()
	scene.ocean.set_sun_glint(2.0)
	scene.set_camera_target(0.0, 150.0, 0.0)   # x, z, y → 目标 (0, 0, 150)
	for yaw in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
		scene.set_camera_orbit(yaw, 35.0, 70.0)
		for i in 20:
			scene.tick(1.0 / 30.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var bright80 := 0
		var bright90 := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var c := img.get_pixel(x, y)
				var l := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
				if l > 0.8:
					bright80 += 1
				if l > 0.9:
					bright90 += 1
		print("GLINT_SWEEP yaw=%d water_open bright_gt_0.8=%d bright_gt_0.9=%d" % [
			int(yaw), bright80, bright90])
	print("STYLIZED_OCEAN_GLINT_SWEEP_OK")
	quit(0)
