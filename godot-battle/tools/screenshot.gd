extends SceneTree

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	for index in 3:
		await create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "user://screenshots/task1_%d.png" % index
		image.save_png(path)
		print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame
	quit(0)
