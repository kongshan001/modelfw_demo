extends SceneTree

# 录三个角色的 SambaDance：Michelle → Soldier → Xbot。
# 用法：godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_all_dances_gif.gd
# 输出：/tmp/mixamo_all_dances_frames/frame_000.png ...

const OUT := "/tmp/mixamo_all_dances_frames"
const FPS := 15.0
const FRAMES := 120

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

	var michelle_on := false
	var soldier_on := false
	var xbot_on := false
	var soldier_switched := false
	var xbot_switched := false
	for i in FRAMES:
		var t := float(i) / FPS
		if t >= 0.4 and not michelle_on:
			player.call("toggle_dance")
			michelle_on = true
		if t >= 2.6 and michelle_on:
			player.call("toggle_dance")
			michelle_on = false
		if t >= 2.7 and not soldier_switched:
			player.call("cycle_character")
			soldier_switched = true
		if t >= 3.0 and not soldier_on:
			player.call("toggle_dance")
			soldier_on = true
		if t >= 5.2 and soldier_on:
			player.call("toggle_dance")
			soldier_on = false
		if t >= 5.3 and not xbot_switched:
			player.call("cycle_character")
			xbot_switched = true
		if t >= 5.6 and not xbot_on:
			player.call("toggle_dance")
			xbot_on = true
		if t >= 7.8 and xbot_on:
			player.call("toggle_dance")
			xbot_on = false

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
