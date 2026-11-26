extends SceneTree

## 10 秒实机录屏（1280×720，20 fps 源帧）：
##   godot --path . --resolution 1280x720 -s tools/capture_sproutbound_video.gd
## 帧 -> /tmp/sproutbound_gif/frame_%03d.png；再用 ffmpeg 编码 MP4/GIF。
## 自适应 Engine.time_scale，保证每张源帧约推进 1/20 秒游戏时间。

const OUT := "/tmp/sproutbound_gif"
const FPS := 20.0
const FRAMES := 200

var vp: SubViewport
var scene
var _spitter = null
var _warden = null


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
	await process_frame
	scene.set_mouse_capture(false)
	scene.start_game()
	scene.set_controls_enabled(true)
	scene.hud.clear_overlays()
	for e in scene.enemies:
		e.active = false
		e.demo_set_state("idle")
	# 采集用 HUD FPS 冻结为 1280×720 正常游玩实测基准（TECH 性能表 41.9/44.1）。
	const BENCH_FPS := 42
	await create_timer(1.5).timeout
	var held_fps: int = scene.hold_fps_value(BENCH_FPS)
	print("VIDEO held_fps=%d (benchmark 1280x720)" % held_fps)

	scene.restart_game()
	await create_timer(0.6).timeout
	scene.set_controls_enabled(true)
	scene.hud.clear_overlays()
	for e in scene.enemies:
		e.active = false
		e.demo_set_state("idle")
	# 起始机位：贴着草甸小径
	scene.cam_yaw = PI
	scene.cam_pitch = 0.3
	scene.cam_dist = 5.2
	scene.snap_camera()
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
			Engine.time_scale = clampf(Engine.time_scale * target / dt_game, 0.04, 1.0)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("%s/frame_%03d.png" % [OUT, i])
	print("SPROUTBOUND_VIDEO_OK frames=%d fps=%d" % [FRAMES, Engine.get_frames_per_second()])
	scene.queue_free()
	vp.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _timeline(i: int) -> void:
	# --- 0-29：草甸小径行走
	if i == 2:
		scene.demo_move(Vector3(0.0, 0.0, 1.0))
	if i == 20:
		_setup_fight()
	if i == 29:
		scene.demo_stop()
		scene.demo_teleport(Vector3(0.0, scene.world.ground_y(0.0, 8.0) + 0.06, 8.0), PI)
		scene.cam_yaw = PI - 0.45
		scene.cam_pitch = 0.31
		scene.cam_dist = 5.0
		scene.snap_camera()
		scene.hud.clear_overlays()

	# --- 30-84：三连斩 + 闪避 + 孢弹
	if i == 32:
		scene.player.begin_attack(0)
	if i == 43:
		scene.player.begin_attack(1)
	if i == 54:
		scene.player.begin_attack(2)
	if i == 62 and _spitter != null:
		scene.demo_kill_enemy(scene.enemies[0])
	if i == 68 and _spitter != null:
		scene.player.demo_move(Vector3(0.8, 0.0, 0.0))
		scene.player.try_dodge()
		_spitter.charge_orb.visible = true
		_spitter.charge_orb.scale = Vector3.ONE * 0.8
		var mouth: Vector3 = _spitter.global_position \
			+ Vector3(0.0, 1.0 * _spitter.body_scale, 0.0) \
			+ _spitter.facing_dir() * (0.5 * _spitter.body_scale)
		var aim: Vector3 = (scene.player.global_position + Vector3(0.0, 0.9, 0.0) - mouth).normalized()
		scene.spawn_enemy_bolt(_spitter, mouth, aim, 10)
	if i == 76:
		scene.player.demo_stop()
		scene.player.dodge_cd = 0.0
		scene.player.try_jump()
	if i == 80:
		if _spitter != null:
			_spitter.charge_orb.visible = false
		scene.player.begin_attack(1)

	# --- 85-119：跳跃 / 侧闪 / 精英登场 & 清场
	if i == 86 and _warden != null:
		_warden.visible = true
		_warden.global_position = Vector3(2.6, scene.world.ground_y(2.6, 12.8) + 0.05, 12.8)
		_warden.active = false
		_warden.aim_at(scene.player.global_position)
		_warden.demo_set_state("windup")
		_warden.telegraph_ring.visible = true
	if i == 96:
		scene.player.demo_move(Vector3(-0.9, 0.0, 0.0))
		scene.player.try_dodge()
	if i == 102:
		scene.player.demo_stop()
	if i == 108 and _warden != null:
		scene.demo_kill_enemy(_warden)
		scene.hud.show_toast("菌怪散尽 · 石拱门苏醒了", 1.2)
	if i == 112:
		scene.demo_kill_all()
	if i == 118:
		scene.demo_teleport(Vector3(0.9, scene.world.ground_y(0.9, 35.6) + 0.06, 35.6), PI)
		scene.set_cinematic_camera(Vector3(3.8, 2.65, 31.6), Vector3(0.2, 1.75, 38.6), 50.0)

	# --- 120-139：石拱门前
	if i == 120:
		scene.hud.clear_overlays()
		scene.hud.show_toast("走入光门，完成这次远行", 1.6)
	if i == 132:
		scene.demo_enter_portal()

	# --- 140-199：胜利结算
	if i == 142:
		scene.hud.clear_overlays()


func _setup_fight() -> void:
	# 主角身后的敌人清到远处，只保留 3 只参与镜头
	var keep = [scene.enemies[0], scene.enemies[1], scene.enemies[4], scene.enemies[8]]
	for e in scene.enemies:
		if e in keep:
			continue
		e.visible = false
		e.active = false
		e.global_position = Vector3(0.0, -12.0, 90.0)
	var c1 = scene.enemies[0]
	var c2 = scene.enemies[1]
	_spitter = scene.enemies[4]
	_warden = scene.enemies[8]
	for e in [c1, c2, _spitter]:
		e.visible = true
		e.active = false
	c1.global_position = Vector3(-1.1, scene.world.ground_y(-1.1, 10.2) + 0.05, 10.2)
	c2.global_position = Vector3(0.5, scene.world.ground_y(0.5, 10.7) + 0.05, 10.7)
	_spitter.global_position = Vector3(2.1, scene.world.ground_y(2.1, 9.8) + 0.05, 9.8)
	for e in [c1, c2, _spitter]:
		e.aim_at(scene.player.global_position)
		e.demo_set_state("chase")
	_warden.visible = false
	_warden.active = false
	_warden.global_position = Vector3(2.6, scene.world.ground_y(2.6, 12.8) + 0.05, 12.8)
