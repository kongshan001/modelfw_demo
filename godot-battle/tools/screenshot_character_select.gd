extends SceneTree

# 主角选择截图：1920×1080 SubViewport，凌霄 / 青鸾 / 确认朱印三张。

var _viewport: SubViewport

func _initialize() -> void:
	var previous := HeroRoster.load_saved_id()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: CharacterSelect = load("res://scenes/character_select.tscn").instantiate()
	scene.auto_enter_battle = false
	_viewport.add_child(scene)
	await process_frame
	scene.select_hero(&"swordsman_lingxiao", false)
	await create_timer(1.3).timeout
	await _capture("charselect_lingxiao.png")

	scene.select_hero(&"mage_qingluan", true)
	await create_timer(0.85).timeout
	await _capture("charselect_qingluan.png")

	scene.select_hero(&"healer_zisu", true)
	await create_timer(0.65).timeout
	scene.confirm()
	await create_timer(0.22).timeout
	await _capture("charselect_confirm.png")

	if previous.is_empty():
		HeroRoster.clear_saved_id()
	else:
		HeroRoster.save_id(previous)
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
