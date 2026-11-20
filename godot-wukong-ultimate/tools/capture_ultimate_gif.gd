extends SceneTree

## Scripted 8-second gameplay capture (20 fps source frames).
##   godot --path . --resolution 1280x720 -s tools/capture_ultimate_gif.gd
## Frames -> /tmp/wukong_ult_gif/frame_%03d.png ; encode with ffmpeg.

const OUT := "/tmp/wukong_ult_gif"
const FPS := 20.0
const FRAMES := 160

var vp: SubViewport
var scene: Node
var player
var dummy


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await create_timer(1.0).timeout
	scene.set_controls_enabled(false)
	scene.dummy.ai_enabled = false
	player = scene.player
	dummy = scene.dummy
	Engine.time_scale = 0.34
	var prev_game: float = scene._t
	for i in FRAMES:
		_timeline(i)
		await create_timer(1.0 / FPS, true, false, true).timeout
		var now_game: float = scene._t
		var dt_game: float = now_game - prev_game
		prev_game = now_game
		if dt_game > 0.001:
			var target := 1.0 / FPS
			Engine.time_scale = clampf(Engine.time_scale * target / dt_game, 0.08, 1.0)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/frame_%03d.png" % [OUT, i])
	print("WUKONG_ULT_GIF_OK frames=%d fps=%d" % [FRAMES, int(FPS)])
	scene.queue_free()
	vp.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _timeline(i: int) -> void:
	if i == 0:
		scene.set_hud_visible(false)
		scene.set_cinematic_camera(Vector3(2.15, 1.12, 0.55), Vector3(-1.2, 1.25, 3.5), 44.0)
	if i > 0 and i < 24:
		var k := float(i) / 24.0
		var pos := Vector3(2.15, 1.12 + 0.06 * k, 0.55 - 0.5 * k)
		scene.set_cinematic_camera(pos, Vector3(-1.2, 1.25, 3.5), 44.0)
	if i == 24:
		scene.set_hud_visible(true)
		scene.set_cinematic_camera(Vector3(2.8, 2.1, 7.8), Vector3(-0.2, 1.15, 0.5), 50.0)
		scene.demo_run()
	if i == 44:
		scene.demo_stop()
		scene.set_cinematic_camera(Vector3(2.4, 1.5, -2.5), Vector3(-1.2, 1.25, -0.6), 45.0)
		player.aim_at(dummy.global_position)
		player.begin_charge()
	if i == 66:
		player.charging = false
		player.charge = 0.0
		scene.demo_set_dummy_hp(120)
		scene.demo_fire_at_dummy(1.0, 120)
		scene.set_cinematic_camera(Vector3(5.4, 2.2, -0.1), Vector3(1.2, 1.10, -3.3), 46.0)
	if i == 88:
		scene.set_cinematic_camera(Vector3(4.6, 2.5, 4.0), Vector3(-0.4, 1.2, 0.2), 48.0)
	if i > 110:
		var k := float(i - 110) / float(FRAMES - 110)
		var ang := -0.5 + k * 0.6
		var center := Vector3(-0.4, 1.2, 0.2)
		var pos := center + Vector3(sin(ang) * 5.8, 1.6, cos(ang) * 5.8)
		scene.set_cinematic_camera(pos, center, 48.0)
