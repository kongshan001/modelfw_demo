extends SceneTree

# 拍三张管线演示图：离线==运行时、运行时新 seed、回到烘焙 seed。
# Run: godot --path godot-iso-slice --resolution 1280x720 -s tools/screenshot_pipeline.gd
# Output: /tmp/iso_pipeline_shots/*.png

const OUT := "/tmp/iso_pipeline_shots"

var _viewport: SubViewport
var _scene: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	_scene = load("res://scenes/pipeline_demo.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	await create_timer(0.5).timeout
	await _shot("01_match")

	_scene.call("next_seed")
	await create_timer(0.35).timeout
	await _shot("02_runtime_only")

	_scene.call("back_to_baked")
	await create_timer(0.35).timeout
	await _shot("03_match_again")

	print("ISO_PIPELINE_SHOTS_OK")
	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.save_png(OUT + "/" + name + ".png")
	print("SHOT ", name)
