extends SceneTree
## 真实 GPU 截图：1920×1080 SubViewport + 1280×720 逻辑画布（与 project.godot 的 canvas_items 拉伸等价）。
## 用法：godot --path . -s tools/screenshot_fog.gd
## 输出：docs/shots/*.png；末行 FOG_SHOTS_OK

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _run() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _settle(40)
	main.demo_set_fps_visible(false)

	main.demo_reset()
	main.demo_set_fog(2, 2)
	main.demo_set_view(26.0, 36.0, 15.5, Vector3(0, 1.4, 0))
	await _settle(24)
	await _shot("01_day_mist_dense_1920x1080")

	main.demo_set_fog(0, 0)
	await _settle(24)
	await _shot("02_day_mist_light_1920x1080")

	main.demo_set_hud_visible(false)
	main.demo_set_fog(2, 2)
	main.demo_set_view(118.0, 20.0, 10.5, Vector3(9.5, 0.6, 6.0))
	await _settle(24)
	await _shot("03_day_pool_close_1920x1080")

	main.demo_set_hud_visible(true)
	main.demo_set_fog(1, 1)
	main.demo_set_fog_color(2)
	main.demo_set_view(26.0, 36.0, 15.5, Vector3(0, 1.4, 0))
	await _settle(24)
	await _shot("04_day_fog_warm_1920x1080")

	main.demo_set_hud_visible(false)
	main.demo_set_phase(true, true)
	main.demo_set_fog(2, 2)
	main.demo_set_fog_color(0)
	main.demo_set_view(38.0, 6.0, 22.0, Vector3(0.0, 6.5, 0.0))
	await _settle(36)
	await _shot("05_night_moonbeams_1920x1080")

	main.demo_set_view(120.0, 16.0, 9.0, Vector3(9.5, 1.0, 6.0))
	await _settle(20)
	await _shot("06_night_lantern_pool_1920x1080")

	main.demo_set_hud_visible(true)
	main.demo_set_phase(false, true)
	main.demo_set_fog(1, 1)
	main.demo_set_fog_color(0)
	main.demo_set_view(26.0, 36.0, 15.5, Vector3(0, 1.4, 0))
	main.demo_set_quality(true)
	await _settle(24)
	await _shot("07_quality_high_1920x1080")

	main.demo_set_quality(false)
	await _settle(24)
	await _shot("08_quality_low_1920x1080")

	print("FOG_SHOTS_OK")
	quit(0)


func _settle(frames: int) -> void:
	for _i in range(maxi(1, frames)):
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("FAILED save ", path, " err=", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
