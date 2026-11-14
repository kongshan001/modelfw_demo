extends SceneTree

# Render three 1280x720 stills for AI visual review: title / play / win.
# Run: godot --path godot-ai-slice --resolution 1280x720 -s tools/screenshot_slice.gd
# Output: /tmp/ai_slice_shots/{title,play,win}.png

const OUT := "/tmp/ai_slice_shots"

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	await create_timer(0.6).timeout
	await _shot("title")

	scene.call("start_game")
	await create_timer(0.8).timeout
	await _shot("play")

	scene.call("force_win")
	await create_timer(0.6).timeout
	await _shot("win")

	print("AI_SLICE_SHOTS_OK")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.save_png(OUT + "/" + name + ".png")
	print("SHOT " + name)
