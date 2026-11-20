extends SceneTree

# 捕获 17:48 → 21:06 的连续帧，用于合成路灯/萤火渐亮的 GIF。

const FRAMES := 110
const STEP := 0.18
const OUT_DIR := "user://screenshots/seq"

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/garden.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_time(17.8)
	await create_timer(1.0).timeout
	scene.set_autoplay(true)

	for index in FRAMES:
		await create_timer(STEP).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png("%s/frame_%03d.png" % [OUT_DIR, index])
	print("SEQUENCE_OK frames=%d" % FRAMES)
	quit(0)
