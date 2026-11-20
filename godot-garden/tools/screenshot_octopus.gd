extends SceneTree

# 章鱼近景：黄昏 / 深夜 / 缠绕石柱三张，1920×1080。

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/garden.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.focus_octopus(true)
	scene.set_ui_visible(false)
	scene.set_time(18.2)
	await create_timer(1.6).timeout
	await _capture("octopus_dusk.png")

	scene.set_time(0.0)
	await create_timer(1.6).timeout
	await _capture("octopus_night.png")

	scene._world.octopus.force_wrap()
	scene.set_time(18.3)
	await create_timer(1.4).timeout
	await _capture("octopus_wrap.png")

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
