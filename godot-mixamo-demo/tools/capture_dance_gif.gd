extends SceneTree

# 录 Michelle 的 SambaDance：Idle → Dance → Idle。
# 用法：godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_dance_gif.gd
# 输出：/tmp/mixamo_dance_frames/frame_000.png ...

const OUT := "/tmp/mixamo_dance_frames"
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

	var scene: Node = load("res://scenes/demo.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout

	var player: Node = scene.get("player")
	if player == null:
		printerr("CAPTURE_FAIL: player missing")
		quit(1)
		return

	var started := false
	var stopped := false
	for i in FRAMES:
		var t := float(i) / FPS
		if t >= 0.5 and not started:
			player.call("toggle_dance")
			started = true
		if t >= 3.5 and not stopped:
			player.call("toggle_dance")
			stopped = true
		player.call("set_demo_input", Vector2.ZERO, false)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png(OUT + "/frame_%03d.png" % i)

	print("CAPTURED ", FRAMES, " frames")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)
