extends SceneTree

# 录制离线烘焙 demo：Soldier Run → Michelle，目标模型原生播放 baked clip。
# 用法：godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_baked_demo.gd
# 输出：/tmp/mixamo_baked_demo_frames/frame_000.png ...

const OUT := "/tmp/mixamo_baked_demo_frames"
const FPS := 15.0
const FRAMES := 60

var _viewport: SubViewport

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/baked_demo.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	await create_timer(0.8).timeout

	for i in FRAMES:
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png(OUT + "/frame_%03d.png" % i)

	print("CAPTURED ", FRAMES, " frames")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)
