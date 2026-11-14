extends SceneTree

# Scripted gameplay capture: title -> walk to core -> two quick cuts -> portal -> win.
# Run: godot --path godot-ai-slice --resolution 1280x720 -s tools/capture_slice_gif.gd
# Output: /tmp/ai_slice_gif_frames/frame_000.png ... frame_104.png
#
# Encode:
#   ffmpeg -framerate 15 -i /tmp/ai_slice_gif_frames/frame_%03d.png \
#     -vf "split[s0][s1];[s0]palettegen=max_colors=128:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
#     -loop 0 godot-ai-slice/docs/gameplay.gif

const OUT := "/tmp/ai_slice_gif_frames"
const FPS := 15.0
const FRAMES := 105

var _viewport: SubViewport
var _scene: Node
var _player: Node3D
var _coins: Array = []
var _portal: Node3D
var _flash_rect: ColorRect
var _flash := 0.0
var _started := false
var _c1 := false
var _c2 := false
var _c3 := false
var _tp1 := false
var _tp2 := false
var _tp3 := false
var _won := false

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	_scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(_scene)

	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 60
	_viewport.add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(0.03, 0.05, 0.08, 0.0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash_rect)

	await process_frame
	await create_timer(0.4).timeout

	for i in FRAMES:
		var t := float(i) / FPS
		_tick(t)
		_flash = maxf(0.0, _flash - 0.08)
		_flash_rect.color = Color(0.03, 0.05, 0.08, _flash)
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
	if not _started and t >= 1.0:
		_scene.call("start_game")
		_player = _scene.get_node_or_null("Player")
		_portal = _scene.get_node_or_null("Portal")
		_coins = get_nodes_in_group("cores")
		_started = true
	if not _started:
		return

	if not _c1 and _player.global_position.z < 2.4:
		_player.call("set_demo_input", Vector3(0.0, 0.0, 1.0), false)
	else:
		_player.call("set_demo_input", Vector3.ZERO, false)

	if not _c1 and (_player.global_position.z >= 2.4 or t >= 1.5):
		_coins[0].call("collect")
		_c1 = true
	if t >= 2.0 and not _tp1:
		_teleport(Vector3(6.2, 1.5, 2.8))
		_tp1 = true
	if t >= 2.3 and not _c2:
		_coins[1].call("collect")
		_c2 = true
	if t >= 2.8 and not _tp2:
		_teleport(Vector3(-5.4, 1.8, 4.2))
		_tp2 = true
	if t >= 3.1 and not _c3:
		_coins[2].call("collect")
		_c3 = true
	if t >= 3.8 and not _tp3:
		_teleport(Vector3(5.2, 1.4, -4.2))
		_tp3 = true
	if t >= 4.2 and not _won:
		_portal.call("trigger")
		_won = true

func _teleport(pos: Vector3) -> void:
	if _player == null:
		return
	_player.global_position = pos
	_flash = 0.75
