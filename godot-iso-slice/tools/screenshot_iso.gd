extends SceneTree

# 拍 5 张验证图：起始、墙后遮挡、Y-Sort 关闭的穿帮、灯光关闭、墙前。
# Run:
#   godot --path godot-iso-slice --resolution 1280x720 -s tools/screenshot_iso.gd
# Output: /tmp/iso_slice_shots/*.png

const OUT := "/tmp/iso_slice_shots"

var _viewport: SubViewport
var _scene: Node


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	_scene = load("res://scenes/dungeon.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout
	await _shot("01_start")

	# 等距的“正后方”是屏幕正上方：残墙 (7,6) 的正上方是 (6,5)
	await _place(Vector2i(6, 5))
	await _shot("02_behind_wall")

	# 关掉 Y-Sort：玩家永远后画，遮挡穿帮
	_scene.call("toggle_y_sort")
	await create_timer(0.2).timeout
	await _shot("03_ysort_off")

	_scene.call("toggle_y_sort")
	_scene.call("toggle_lights")
	await create_timer(0.2).timeout
	await _shot("04_lights_off")

	_scene.call("toggle_lights")
	await _place(Vector2i(8, 7))
	await _shot("05_front_wall")

	print("ISO_SHOTS_OK")
	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _place(cell: Vector2i) -> void:
	var pos: Vector2 = _scene.call("cell_pos", cell)
	var player: Node = _scene.get_node("World/Player")
	player.call("teleport", pos)
	player.get_node("Camera2D").reset_smoothing()
	await create_timer(0.45).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	image.save_png(OUT + "/" + name + ".png")
	print("SHOT ", name)
