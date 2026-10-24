extends SceneTree

const FRAME_COUNT := 10
const INTERVAL := 0.8

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.start_auto_mode = true
	root.add_child(scene)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	for index in FRAME_COUNT:
		await create_timer(INTERVAL).timeout
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var path := "user://screenshots/task2_%d.png" % index
		image.save_png(path)
		print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame
	quit(0)
