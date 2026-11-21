extends SceneTree

## 10 秒实机录屏（20 fps 源帧，1280×720）：
##   godot --path . --resolution 1280x720 -s tools/capture_gif.gd
## 帧 -> /tmp/changan_gif/frame_%03d.png，再用 ffmpeg 编码 GIF/MP4。
## 自适应 Engine.time_scale 保持每帧约 1/20 s 游戏时间，避免录屏加速。

const OUT := "/tmp/changan_gif"
const FPS := 20.0
const FRAMES := 200

var vp: SubViewport
var scene


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
	await create_timer(1.2).timeout
	scene.set_mouse_capture(false)
	scene.set_hud_visible(true)
	Engine.time_scale = 0.35
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
	print("CHANGAN_GIF_OK frames=%d fps=%d" % [FRAMES, int(FPS)])
	scene.queue_free()
	vp.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _timeline(i: int) -> void:
	if i == 0:
		scene.set_cinematic_camera(Vector3(0.4, 2.85, -1.4), Vector3(0.0, 3.15, 20.0), 55.0)
	if i == 10:
		scene.start_game()
		Engine.time_scale = 0.35
		scene.demo_teleport(Vector3(0, 0.06, 3.2), 0.0)
		scene.demo_move(Vector3(0, 0, 1))
	if i == 42:
		scene.demo_stop()
		scene.demo_teleport(Vector3(0, 0.06, 15.0), 0.0)
		scene.demo_set_lights(1)
		scene.demo_start_wave(1)
		scene.set_controls_enabled(false)
		_place_enemies()
	if i >= 50 and i <= 92 and (i - 50) % 8 == 0:
		var t = scene.wave_enemies[0]
		if is_instance_valid(t) and not t.is_dead:
			scene.player.aim_at(t.global_position)
		scene.player.combo_window = 1.0
		scene.player.combo_step = ((i - 50) / 8) % 3
		scene.player.begin_attack("jab" if scene.player.combo_step < 2 else "kick")
	if i == 96:
		scene.player.reset_state(Vector3(0, 0.06, 17.0), 0.0)
		scene.player.start_roll(Vector3(0, 0, 1))
	if i == 108:
		scene.demo_set_lights(3)
		scene.demo_teleport(Vector3(1.8, 0.06, 69.6), 0.0)
		scene.demo_start_boss()
	if i == 116:
		scene.skip_boss_intro()
	if i == 122:
		scene.demo_teleport(Vector3(3.7, 0.06, 72.0), PI * 0.75)
		if scene.boss_ref != null and is_instance_valid(scene.boss_ref):
			scene.boss_ref.global_position = Vector3(0.0, 0.06, 76.5)
			scene.boss_ref.rotation.y = PI
			scene.boss_ref.active = false
			scene.boss_ref.play_anim("Idle", 0.1)
		scene.demo_boss_phase2()
		scene.set_cinematic_camera(Vector3(1.7, 2.05, 70.2), Vector3(0.0, 1.48, 76.5), 47.0)
	if i == 150:
		if scene.boss_ref != null and is_instance_valid(scene.boss_ref) and not scene.boss_ref.is_dead:
			scene.demo_kill_enemy(scene.boss_ref)
	if i == 162:
		scene.world.restore_light()
		scene.elapsed = 634.0
		scene.max_combo = 7
		scene.hits_taken = 3
		scene.demo_choose("mercy")
	if i == 176:
		scene.set_hud_visible(true)


func _place_enemies() -> void:
	for e in scene.wave_enemies:
		e.active = true
		e.global_position = scene.player.global_position + Vector3(-1.7 if e.slot == 0 else 2.2, 0, 2.3)
		e.rotation.y = PI
