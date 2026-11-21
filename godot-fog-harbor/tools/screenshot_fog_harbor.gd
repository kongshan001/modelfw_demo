extends SceneTree
## 真实 GPU 截图：1920×1080 SubViewport + 1280×720 逻辑画布（canvas_items 拉伸等价）。
## 用法：godot --path . -s tools/screenshot_fog_harbor.gd

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
	await _settle(6)
	main.demo_use_save_path("user://fog_harbor_capture_save.json")
	main.demo_seed_state()
	await _settle(12)
	await _shot("01_base_1920x1080")

	main.demo_start_raid()
	await _settle(20)
	main.demo_set_god(true)
	main.demo_teleport(Vector2(760, 800))
	main.demo_aim_at(Vector2(1120, 650))
	main.demo_set_crosshair(Vector2(812, 302))
	await _settle(20)
	await _shot("02_map_1920x1080")

	main.demo_loot_setup()
	await _settle(10)
	await _shot("03_search_1920x1080")

	main.demo_set_manual_interaction(false)
	main.demo_stage_combat()
	await _settle(12)
	var enemies: Array = main.demo_get_enemies()
	if enemies.size() > 0:
		main.demo_fire_at(enemies[0].global_position)
	await _settle(2)
	await _shot("04_combat_1920x1080")
	if enemies.size() > 1:
		main.demo_fire_at(enemies[1].global_position)
	await _settle(3)
	await _shot("04b_combat_1920x1080")

	main.demo_add_demo_loot()
	main.demo_open_backpack()
	var pack = main.demo_get_backpack()
	if pack != null and main.demo_get_inventory().entries.size() > 0:
		pack.selected_index = 0
		pack.refresh()
	await _settle(6)
	await _shot("05_backpack_1920x1080")
	main.demo_close_backpack()
	await process_frame

	main.demo_set_manual_interaction(false)
	main.demo_freeze_rules(false)
	main.demo_extraction_setup()
	await _settle(8)
	await _shot("06_extraction_1920x1080")

	main.demo_finish(true, "撤离成功")
	await _settle(10)
	await _shot("07_result_success_1920x1080")

	main.demo_start_raid()
	await _settle(16)
	main.demo_add_demo_loot()
	main.demo_finish(false, "阵亡")
	await _settle(10)
	await _shot("08_result_death_1920x1080")

	print("FOG_HARBOR_SHOTS_OK")
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
