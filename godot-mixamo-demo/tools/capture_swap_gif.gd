extends SceneTree

# 录角色切换：Michelle（重定向）→ Soldier（原生）→ Xbot（原生）。
# 用法：godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_swap_gif.gd
# 输出：/tmp/mixamo_swap_frames/frame_000.png ...

const OUT := "/tmp/mixamo_swap_frames"
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

	var swapped_soldier := false
	var swapped_xbot := false
	for i in FRAMES:
		var t := float(i) / FPS
		if t >= 1.7 and not swapped_soldier:
			player.call("cycle_character")
			swapped_soldier = true
		if t >= 2.7 and not swapped_xbot:
			player.call("cycle_character")
			swapped_xbot = true

		var dir := Vector2.ZERO
		var run := false
		if t >= 0.8 and t < 2.7:
			dir = Vector2(1.0, 0.0)
		elif t >= 2.7:
			dir = Vector2(-0.35, -1.0).normalized()
			run = true
		player.call("set_demo_input", dir, run)

		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png(OUT + "/frame_%03d.png" % i)

	print("CAPTURED ", FRAMES, " frames")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)
