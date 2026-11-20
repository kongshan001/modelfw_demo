extends SceneTree

# 1920×1080 花园截图：黄昏 / 路灯初亮 / 深夜 / 清晨。

const TIMES := [12.0, 17.8, 19.2, 0.0, 6.4]
const NAMES := ["garden_noon", "garden_dusk", "garden_lamps", "garden_night", "garden_dawn"]

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
	await create_timer(1.0).timeout
	for index in TIMES.size():
		scene.set_time(TIMES[index])
		await create_timer(1.2).timeout
		await _capture(String(NAMES[index]) + ".png")
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
