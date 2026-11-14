extends SceneTree

# Bowling-head capture: walk toward the lane, throw the head, knock all pins.
# Run: godot --path godot-ai-slice --resolution 1280x720 -s tools/capture_bowling_gif.gd
# Output: /tmp/ai_slice_bowling_frames/frame_000.png ...
#
# Encode:
#   ffmpeg -framerate 15 -i /tmp/ai_slice_bowling_frames/frame_%03d.png \
#     -vf "split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
#     -loop 0 godot-ai-slice/docs/bowling.gif

const OUT := "/tmp/ai_slice_bowling_frames"
const FPS := 15.0
const FRAMES := 60

var _viewport: SubViewport
var _scene: Node
var _player: Node3D
var _started := false
var _thrown := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	_scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	await create_timer(0.3).timeout

	for i in FRAMES:
		var t := float(i) / FPS
		_tick(t)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png(OUT + "/frame_%03d.png" % i)

	print("CAPTURED ", FRAMES, " frames")
	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _tick(t: float) -> void:
	if not _started and t >= 0.2:
		_scene.call("start_game")
		_player = _scene.get_node_or_null("Player")
		_started = true
	if not _started or _player == null or _thrown:
		return

	if _player.global_position.z > -2.2:
		_player.call("set_demo_input", Vector3(0.0, 0.0, -1.0), false)
	else:
		_player.call("set_demo_input", Vector3.ZERO, false)
		_player.call("throw_head")
		_thrown = true
