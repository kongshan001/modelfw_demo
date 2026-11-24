extends SceneTree
## 真实 GPU 截图：第三人称角色 + 动态雾驱散。
## 1920×1080 SubViewport + 1280×720 逻辑画布；输出 docs/shots/09..16。
## 用法：godot --path . --resolution 1280x720 -s tools/screenshot_fog_interaction.gd
## 末行：FOG_INTERACTION_SHOTS_OK

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

	# 09 / 10 / 11：浓雾中静止 → 行走驱散 → 停下恢复
	main.demo_reset()
	main.demo_set_fog(2, 2)
	main.demo_set_fog_color(0)
	main.demo_set_follow_view(26.0, 20.0, 7.2)
	await _settle(30)
	await _shot("09_character_idle_fog_1920x1080")

	main.demo_set_player_input(0.0, 1.0, false)
	await _seconds(1.0)
	await _settle(2)
	await _shot("10_character_walk_clear_1920x1080")

	main.demo_clear_player_input()
	await _seconds(2.4)
	await _settle(2)
	await _shot("11_character_stop_restore_1920x1080")

	# 12 / 13：同一静止机位与清除量，半径 2m vs 10m（先走动充能，再回位抓静止帧）
	await _charge_clear_then_pose(1.5, 18.5, 2.0)
	await _shot("12_clear_radius_2m_1920x1080")

	await _charge_clear_then_pose(1.5, 18.5, 10.0)
	await _shot("13_clear_radius_10m_1920x1080")

	# 14：F1 调试（半径 / 淡出环 / 局部雾量）
	await _charge_clear_then_pose(1.5, 18.5, 4.5)
	main.demo_set_clear_debug(true)
	await _settle(4)
	await _shot("14_debug_f1_view_1920x1080")
	main.demo_set_clear_debug(false)
	main.demo_clear_player_input()

	# 15：夜雾 + 灯笼 + 角色
	main.demo_set_phase(true, true)
	main.demo_set_fog(2, 2)
	main.demo_set_fog_color(0)
	main.demo_teleport_player(4.0, 2.0)
	main.demo_set_follow_view(34.0, 16.0, 6.4)
	main.demo_set_hud_visible(false)
	main.demo_set_player_input(0.6, 0.4, true)
	await _seconds(1.1)
	await _settle(2)
	await _shot("15_night_character_fog_1920x1080")
	main.demo_clear_player_input()

	# 16：高角度俯瞰清雾范围（HUD 隐藏）
	main.demo_set_phase(false, true)
	main.demo_set_fog(2, 2)
	main.demo_set_hud_visible(false)
	main.demo_teleport_player(1.5, 18.5)
	main.demo_set_follow_view(42.0, 38.0, 11.5)
	main.demo_set_player_input(0.4, 1.0, true)
	await _seconds(0.9)
	await _settle(2)
	await _shot("16_clear_zone_wide_1920x1080")

	print("FOG_INTERACTION_SHOTS_OK")
	quit(0)


func _settle(frames: int) -> void:
	for _i in range(maxi(1, frames)):
		await process_frame
	await RenderingServer.frame_post_draw


func _seconds(seconds: float) -> void:
	await create_timer(seconds).timeout


func _charge_clear_then_pose(x: float, z: float, radius: float) -> void:
	main.demo_teleport_player(x, z)
	main.demo_set_fog_clear(radius, 0.85, 1.6)
	main.demo_set_player_input(0.0, 1.0, false)
	await _seconds(0.55)
	main.demo_clear_player_input()
	main.demo_teleport_player(x, z)
	await _settle(3)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("FAILED save ", path, " err=", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
