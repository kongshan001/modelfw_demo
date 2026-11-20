extends SceneTree

# 拍三张 mod 导入图：合法、坏尺寸、坏哈希。
# Run: godot --path godot-iso-slice --resolution 1280x720 -s tools/screenshot_mod.gd
# Output: /tmp/iso_mod_shots/*.png

const OUT := "/tmp/iso_mod_shots"

var _viewport: SubViewport
var _scene: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	_scene = load("res://scenes/mod_demo.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	await _shot("01_valid")

	_scene.call("_select", 1)  # bad_scale
	await create_timer(0.4).timeout
	await _shot("02_bad_scale")

	_scene.call("_select", 0)  # bad_hash
	await create_timer(0.4).timeout
	await _shot("03_bad_hash")

	print("ISO_MOD_SHOTS_OK")
	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.save_png(OUT + "/" + name + ".png")
	print("SHOT ", name)
