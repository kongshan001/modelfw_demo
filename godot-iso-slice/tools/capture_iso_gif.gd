extends SceneTree

# 脚本化录制：绕到残墙后 → 演示遮挡 → 关 Y-Sort 穿帮 → 关灯 → 走回灯下。
# Run:
#   godot --path godot-iso-slice --resolution 1280x720 -s tools/capture_iso_gif.gd
# Encode:
#   ffmpeg -framerate 15 -i /tmp/iso_slice_gif/frame_%03d.png \
#     -vf "split[s0][s1];[s0]palettegen=max_colors=160:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5" \
#     -loop 0 godot-iso-slice/docs/iso_slice.gif

const OUT := "/tmp/iso_slice_gif"
const FPS := 15.0
const FRAMES := 112

var _viewport: SubViewport
var _scene: Node
var _player: IsoPlayer
var _target := Vector2.ZERO


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

	_scene = load("res://scenes/dungeon.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	await create_timer(0.5).timeout

	_player = _scene.get_node("World/Player")
	_player.call("teleport", _scene.call("cell_pos", Vector2i(9, 8)))
	_player.get_node("Camera2D").reset_smoothing()
	_player.autopilot = true
	await create_timer(0.4).timeout

	for i in FRAMES:
		_tick(i)
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var img := _viewport.get_texture().get_image()
		img.save_png("%s/frame_%03d.png" % [OUT, i])

	print("ISO_GIF_OK frames=", FRAMES)
	quit(0)


func _tick(i: int) -> void:
	var moving := false

	if i < 17:
		_nav(Vector2i(9, 5))
		moving = true
	elif i < 33:
		_nav(Vector2i(6, 5))
		moving = true

	if i == 46:
		_scene.call("toggle_y_sort")
	if i == 61:
		_scene.call("toggle_y_sort")
	if i == 67:
		_scene.call("toggle_lights")
	if i == 82:
		_scene.call("toggle_lights")

	if i >= 88 and i < 104:
		_nav(Vector2i(9, 5))
		moving = true

	if not moving:
		_player.demo_input = Vector2.ZERO


func _nav(cell: Vector2i) -> void:
	var dest: Vector2 = _scene.call("cell_pos", cell)
	var delta := dest - _player.global_position
	if delta.length() < 14.0:
		_player.demo_input = Vector2.ZERO
		return
	var dir := delta.normalized()
	# demo_input 会先做 y/2 再归一化；这里乘 2 让屏幕方向保持 dir
	_player.demo_input = Vector2(dir.x, dir.y * 2.0)
