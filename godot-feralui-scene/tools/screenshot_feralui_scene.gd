extends SceneTree
## 真实 GPU 1920×1080 截图：
## 夜全景 / 水塘微距 / 猫的交互 / 白昼 / 雨景 / 月树细节 / 风铃交互 / HUD。
## 用法：godot --path godot-feralui-scene -s tools/screenshot_feralui_scene.gd
## 输出到 res://docs/shots/
## 注：实时 FPS 在 SubViewport 离屏截图中没有参考意义，截图统一隐藏；游戏内默认显示。

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _wait(20)
	main.demo_set_fps_visible(false)
	main.demo_set_markers_visible(false)
	main.demo_set_hud_visible(false)

	await _pose(true, false, 22.0, 35.5, 21.5, Vector3(0, 2.15, 0.30), false)
	await _shot("01_night_wide")

	await _pose(true, false, 18.0, 31.0, 11.2, Vector3(4.0, 0.55, 1.75), false)
	await _shot("02_night_pond")

	await _pose(true, false, 10.0, 26.0, 8.2, Vector3(1.85, 0.7, -0.35), false)
	main.demo_set_hud_visible(true)
	main.demo_set_markers_visible(true)
	main.demo_focus_target("moss_cat")
	main.demo_interact("moss_cat")
	await create_timer(0.65).timeout
	await _shot("03_night_cat_interaction")
	main.demo_set_hud_visible(false)
	main.demo_set_markers_visible(false)
	main.demo_clear_focus()

	await _pose(false, false, 22.0, 35.5, 21.5, Vector3(0, 2.15, 0.30), false)
	await _shot("04_day_wide")

	await _pose(false, true, 4.0, 30.0, 16.5, Vector3(2.0, 1.0, 0.4), false)
	await _shot("05_day_rain")

	await _pose(true, false, -8.0, 27.0, 12.5, Vector3(-2.8, 2.6, -1.1), false)
	await _shot("06_night_tree_detail")

	# 风铃交互近景
	main.demo_reset()
	var chime_anchor := Vector3(5.73, 1.75, -1.35)
	for info in main.get_target_info():
		if info["id"] == "wind_chime":
			chime_anchor = info["anchor"]
	main.demo_set_hud_visible(true)
	main.demo_set_markers_visible(true)
	main.demo_focus_target("wind_chime")
	main.demo_interact("wind_chime")
	main.demo_set_view(8.0, 13.0, 5.2, chime_anchor, false)
	await create_timer(0.65).timeout
	await _shot("07_night_chime_interaction")
	main.demo_clear_focus()
	main.demo_set_hud_visible(false)
	main.demo_set_markers_visible(false)

	# UI 全景
	main.demo_reset()
	main.demo_set_hud_visible(true)
	main.demo_set_markers_visible(true)
	main.demo_focus_target("lantern_path")
	main.demo_interact("lantern_path")
	await create_timer(0.4).timeout
	await _shot("08_night_ui")

	print("FERALUI_SCENE_SHOTS_OK")
	quit(0)


func _pose(night: bool, rain: bool, yaw: float, pitch: float, dist: float,
		focus: Vector3, auto: bool) -> void:
	main.demo_set_phase(night, true)
	main.demo_set_weather(rain, true)
	main.demo_set_view(yaw, pitch, dist, focus, auto)
	await create_timer(0.55).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())


func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
