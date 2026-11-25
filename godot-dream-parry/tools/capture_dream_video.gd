extends SceneTree

# 10 秒成片帧源：探索 → 弹反反击 → Boss 丧钟闪避 → 窥梦断桥 → Boss 二阶段 → 胜利。
# 1280×720、真实渲染；录完用 ffmpeg 编码为 10s MP4/GIF。
# godot --path godot-dream-parry --resolution 1280x720 -s tools/capture_dream_video.gd

const OUT := "/tmp/dream_parry_video_frames"
const DURATION := 10.0
const VIEW_SIZE := Vector2i(1280, 720)

var vp: SubViewport
var world: DreamWorld
var player: DreamPlayer
var normal: DreamEnemy
var boss: DreamEnemy
var frames := 0
var _start_us := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_prepare_dir()
	vp = SubViewport.new()
	vp.size = VIEW_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	world = load("res://scenes/main.tscn").instantiate() as DreamWorld
	vp.add_child(world)
	await process_frame
	await process_frame
	player = world.player
	normal = world.normal_enemy
	boss = world.boss
	world.capture_mode = true
	world.hud.show_fps = false
	world.hud._intro_left = 0.0
	world.hud._toast_left = 0.0
	await create_timer(2.4).timeout

	_start_us = Time.get_ticks_usec()
	await _direct()
	var duration := float(Time.get_ticks_usec() - _start_us) / 1_000_000.0
	print("DREAM_PARRY_VIDEO_FRAMES_OK frames=%d source_seconds=%.2f" % [frames, duration])
	print("ENCODE_FPS %.3f" % (float(frames) / DURATION))
	world.queue_free()
	vp.queue_free()
	await process_frame
	quit(0)


func _capture_until(t: float) -> void:
	# 边等待边逐帧落盘。整段固定 10s 墙钟，因此最终按 frames/10 编码即真实时长。
	while float(Time.get_ticks_usec() - _start_us) / 1_000_000.0 < t:
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		image.save_jpg("%s/frame_%04d.jpg" % [OUT, frames], 0.92)
		frames += 1


func _direct() -> void:
	# 1) 醒梦庭探索
	world.clear_film_camera()
	world.debug_teleport_player(Vector3(0, 0.05, 3.4), 0.0)
	world.hud.show_room("醒梦庭")
	world.hud._toast_left = 0.0
	world.fx.clear_effects()
	await _capture_until(0.35)
	Input.action_press("move_forward")
	Input.action_press("move_right")
	await _capture_until(1.45)
	Input.action_release("move_forward")
	Input.action_release("move_right")

	# 2) 齿轮回廊：弹反窗口 → 完美弹反 → 反击
	await _capture_until(1.65)
	world.capture_mode = true
	world.fx.clear_effects()
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	normal.visible = true
	normal.global_position = Vector3(3.3, 0.05, -22.7)
	normal.global_rotation.y = PI
	normal.home = normal.global_position
	normal.aggro = true
	normal.attack_cooldown = 99.0
	normal.state = DreamEnemy.State.IDLE
	player.respawn_at(Vector3(3.3, 0.05, -25.15), 0.0)
	player.face_target(normal)
	player.hp = 74.0
	player.stamina = 82.0
	player.energy = 58.0
	player.state = DreamPlayer.State.FREE
	world.fx.clear_effects()
	world.set_film_camera(Vector3(8.0, 4.8, -19.0), Vector3(3.3, 1.0, -23.6), 7.2)
	normal.force_attack("sweep")
	normal.windup_left = 0.4
	normal._telegraph_root.scale = Vector3.ONE * normal._current_attack_range()
	normal._telegraph_mat.albedo_color = Color(1.0, 0.48, 0.18, 0.62)
	await _capture_until(1.85)
	player.start_parry()
	await _capture_until(2.18)
	player.state = DreamPlayer.State.PARRY
	player.state_time = 0.1
	player.parry_elapsed = 0.04
	world.resolve_enemy_attack(normal, DreamEnemy.ATTACK_DATA["sweep"], true)
	if normal.state != DreamEnemy.State.STAGGER:
		normal.on_parried()
		player.on_parry_success(normal)
	await _capture_until(2.45)
	player.state = DreamPlayer.State.FREE
	player.face_target(normal)
	player.press_attack()
	await _capture_until(2.52)
	player.release_attack()
	await _capture_until(3.55)

	# 3) 无钟之间：丧钟 AoE → 闪避
	await _capture_until(3.7)
	world.capture_mode = true
	world.fx.clear_effects()
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	player.hp = 66.0
	player.stamina = 76.0
	player.energy = 48.0
	world.has_relic = true
	world.bridge_revealed = true
	world.shards_collected = 2
	for shard in world.shards:
		shard["collected"] = true
		var node: Node3D = shard["node"]
		node.visible = false
	boss.reset_enemy()
	boss.global_position = DreamLevel.BOSS_HOME
	boss.global_rotation.y = PI * 0.5
	boss.aggro = true
	boss.state = DreamEnemy.State.IDLE
	boss.attack_cooldown = 99.0
	world.boss_engaged = true
	player.respawn_at(Vector3(25.6, 0.05, -22.0), -PI * 0.5)
	player.face_target(boss)
	world.fx.clear_effects()
	world.set_film_camera(Vector3(33.6, 6.8, -16.2), Vector3(26.8, 1.0, -22.3), 11.2)
	boss.force_attack("toll")
	boss._telegraph_root.position.y = 0.12
	boss._telegraph_root.scale = Vector3.ONE * 3.4
	boss._telegraph_mat.albedo_color = Color(0.82, 0.5, 1.0, 0.9)
	boss._telegraph_disc_mat.albedo_color = Color(0.55, 0.28, 1.0, 0.3)
	await _capture_until(4.15)
	player.start_dodge()
	await _capture_until(4.28)
	world.resolve_enemy_attack(boss, DreamEnemy.ATTACK_DATA["toll"], true)
	await _capture_until(5.55)

	# 4) 窥梦断桥
	await _capture_until(5.7)
	world.capture_mode = true
	world.fx.clear_effects()
	normal.visible = false
	world.has_relic = true
	world.bridge_revealed = true
	world.level.set_relic_taken(true)
	world.level.set_bridge_open(true)
	world.shards_collected = 1
	for i in world.shards.size():
		var collected: bool = i == 0
		world.shards[i]["collected"] = collected
		var node: Node3D = world.shards[i]["node"]
		node.visible = not collected
	boss.reset_enemy()
	boss.aggro = false
	world.boss_engaged = false
	player.respawn_at(Vector3(-9.4, 0.05, -22.0), PI * 0.5)
	player.hp = 88.0
	player.energy = 71.0
	player.stamina = 78.0
	player.state = DreamPlayer.State.FREE
	world.fx.clear_effects()
	world.hud.show_room("断桥秘园")
	world.hud._toast_left = 0.0
	world.set_film_camera(Vector3(-13.5, 6.2, -13.6), Vector3(-13.3, 0.5, -22.0), 10.2)
	await _capture_until(6.15)
	Input.action_press("move_forward")
	Input.action_press("move_left")
	await _capture_until(7.0)
	Input.action_release("move_forward")
	Input.action_release("move_left")
	await _capture_until(7.55)

	# 5) Boss 二阶段反击
	await _capture_until(7.65)
	world.capture_mode = true
	world.fx.clear_effects()
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.shards_collected = 2
	boss.reset_enemy()
	boss.global_position = DreamLevel.BOSS_HOME
	boss.global_rotation.y = PI * 0.5
	boss.aggro = true
	boss.phase_two = true
	boss.hp = boss.max_hp * 0.4
	boss.state = DreamEnemy.State.IDLE
	boss.attack_cooldown = 99.0
	world.boss_engaged = true
	player.respawn_at(Vector3(25.8, 0.05, -22.4), -PI * 0.5)
	player.face_target(boss)
	player.hp = 58.0
	player.energy = 72.0
	player.stamina = 70.0
	player.state = DreamPlayer.State.FREE
	world.fx.clear_effects()
	world.set_film_camera(Vector3(33.8, 6.9, -16.0), Vector3(26.8, 1.1, -22.5), 11.8)
	await _capture_until(7.95)
	player.press_attack()
	await _capture_until(8.0)
	player.release_attack()
	await _capture_until(9.1)

	# 6) 胜利
	await _capture_until(9.2)
	world.fx.clear_effects()
	boss.take_damage(99999.0, false, player.global_position)
	await _capture_until(9.35)
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.set_film_camera(Vector3(34.0, 10.0, -10.8), Vector3(27.0, 1.2, -22.6), 15.2)
	await _capture_until(DURATION)


func _prepare_dir() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
			dir.remove(file_name)
