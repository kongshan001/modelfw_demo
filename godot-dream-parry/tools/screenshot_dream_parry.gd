extends SceneTree

# 1920×1080 真 GPU 验收截图：探索 / 弹反窗口 / 反击 / 遗物断桥 / Boss 闪避 / Boss 对决 / 胜利。
# godot --path godot-dream-parry --resolution 1280x720 -s tools/screenshot_dream_parry.gd

const OUT_DIR := "res://docs/shots"
const VIEW_SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var world: DreamWorld
var player: DreamPlayer
var normal: DreamEnemy
var boss: DreamEnemy
var saved := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
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
	await create_timer(2.2).timeout

	await _shot_awakening()
	await _shot_parry_window()
	await _shot_riposte()
	await _shot_relic_bridge()
	await _shot_boss_dodge()
	await _shot_boss_duel()
	await _shot_victory()

	print("DREAM_PARRY_SHOTS_OK count=%d size=%s" % [saved, str(VIEW_SIZE)])
	world.queue_free()
	vp.queue_free()
	await process_frame
	quit(0)


func _shot_awakening() -> void:
	world.capture_mode = true
	world.clear_film_camera()
	world.debug_teleport_player(Vector3(0, 0.05, 3.4), 0.0)
	player.hp = 92.0
	player.energy = 62.0
	player.stamina = 88.0
	world.hud.show_room("醒梦庭")
	world.hud._toast_left = 0.0
	world.set_film_camera(Vector3(8.7, 9.6, 12.2), Vector3(0.0, 0.85, 1.6), 11.2)
	await create_timer(0.35).timeout
	await _shot("01_awakening_court")


func _prepare_gallery_closeup() -> void:
	world.capture_mode = true
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.has_relic = false
	world.bridge_revealed = false
	world.level.set_relic_taken(false)
	world.level.set_bridge_open(false)
	world.shards_collected = 0
	for shard in world.shards:
		shard["collected"] = false
		var node: Node3D = shard["node"]
		node.visible = true
	# 巡游者：让玩家正面看到起手与预警。
	normal.global_position = Vector3(3.3, 0.05, -22.7)
	normal.global_rotation.y = PI
	normal.home = normal.global_position
	normal.aggro = true
	normal.state = DreamEnemy.State.IDLE
	normal.attack_cooldown = 99.0
	normal.visible = true
	player.respawn_at(Vector3(3.3, 0.05, -25.15), 0.0)
	player.face_target(normal)
	player.hp = 74.0
	player.stamina = 82.0
	player.energy = 58.0
	world.attack_token = null
	boss.reset_enemy()
	boss.aggro = false
	world.boss_engaged = false
	await create_timer(0.25).timeout
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.fx.clear_effects()
	world.set_film_camera(Vector3(8.0, 4.8, -19.0), Vector3(3.3, 1.0, -23.6), 7.2)


func _shot_parry_window() -> void:
	await _prepare_gallery_closeup()
	normal.force_attack("sweep")
	# 冻结 AI 时手动把预警圈停在接近命中、可读的位置。
	normal.windup_left = 0.19
	normal._telegraph_root.scale = Vector3.ONE * normal._current_attack_range() * 0.96
	normal._telegraph_mat.albedo_color = Color(1.0, 0.48, 0.18, 0.62)
	normal._telegraph_disc_mat.albedo_color = Color(1.0, 0.28, 0.22, 0.12)
	player.start_parry()
	await create_timer(0.055).timeout
	await _shot("02_parry_window")
	# 截图后仍在窗口内，完成真实弹反判定。
	player.state = DreamPlayer.State.PARRY
	player.state_time = 0.1
	player.parry_elapsed = 0.04
	var data: Dictionary = DreamEnemy.ATTACK_DATA["sweep"]
	world.resolve_enemy_attack(normal, data, true)
	if normal.state != DreamEnemy.State.STAGGER:
		normal.on_parried()
		player.on_parry_success(normal)


func _shot_riposte() -> void:
	await create_timer(0.12).timeout
	player.state = DreamPlayer.State.FREE
	player.state_time = 0.0
	player.face_target(normal)
	player.press_attack()
	await create_timer(0.04).timeout
	player.release_attack()
	await create_timer(0.18).timeout
	await _shot("03_riposte")
	# 清理定格特效
	world.hud._toast_left = 0.0


func _shot_relic_bridge() -> void:
	world.capture_mode = true
	world.hud._toast_left = 0.0
	world.hud.room_title_left = 0.0
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
	normal.state = DreamEnemy.State.IDLE
	normal.global_position = Vector3(0, 0.05, -23.0)
	normal.visible = false
	normal.global_position = Vector3(0, 0.05, -80.0)
	normal._telegraph_root.visible = false
	boss.reset_enemy()
	boss.aggro = false
	boss.state = DreamEnemy.State.IDLE
	world.boss_engaged = false
	world.debug_teleport_player(Vector3(-10.4, 0.05, -22.0), PI * 0.5)
	player.hp = 88.0
	player.energy = 71.0
	player.stamina = 78.0
	await create_timer(0.25).timeout
	world.fx.clear_effects()
	world.hud.show_room("断桥秘园")
	world.hud._toast_left = 0.0
	world.set_film_camera(Vector3(-13.5, 6.2, -13.6), Vector3(-13.3, 0.5, -22.0), 10.2)
	await create_timer(0.20).timeout
	await _shot("04_relic_bridge")


func _shot_boss_dodge() -> void:
	# 叙事上第二枚残片已拾取，目标转向无钟之间。
	world.shards_collected = 2
	for shard in world.shards:
		shard["collected"] = true
		var node: Node3D = shard["node"]
		node.visible = false
	world.has_relic = true
	world.bridge_revealed = true
	boss.reset_enemy()
	boss.global_position = DreamLevel.BOSS_HOME
	boss.global_rotation.y = PI * 0.5
	boss.aggro = true
	boss.state = DreamEnemy.State.IDLE
	boss.attack_cooldown = 99.0
	world.boss_engaged = true
	player.respawn_at(Vector3(25.6, 0.05, -22.0), -PI * 0.5)
	player.face_target(boss)
	player.hp = 66.0
	player.energy = 48.0
	player.stamina = 76.0
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	await create_timer(0.2).timeout
	world.hud.room_title_left = 0.0
	world.fx.clear_effects()
	boss.force_attack("toll")
	boss.windup_left = 0.36
	boss._telegraph_root.position.y = 0.12
	boss._telegraph_root.scale = Vector3.ONE * 3.4
	boss._telegraph_mat.albedo_color = Color(0.82, 0.5, 1.0, 0.9)
	boss._telegraph_mat.emission = Color(0.72, 0.3, 1.0)
	boss._telegraph_disc_mat.albedo_color = Color(0.55, 0.28, 1.0, 0.3)
	boss._telegraph_disc_mat.emission = Color(0.55, 0.25, 1.0)
	player.start_dodge()
	await create_timer(0.06).timeout
	world.resolve_enemy_attack(boss, DreamEnemy.ATTACK_DATA["toll"], true)
	await create_timer(0.04).timeout
	world.set_film_camera(Vector3(33.6, 6.8, -16.2), Vector3(26.8, 1.0, -22.3), 11.2)
	await _shot("05_boss_dodge")


func _shot_boss_duel() -> void:
	# 深红二阶段、清空硬直，玩家挥伞反击。
	boss.reset_enemy()
	boss.global_position = DreamLevel.BOSS_HOME
	boss.global_rotation.y = PI * 0.5
	boss.aggro = true
	boss.phase_two = true
	boss.hp = boss.max_hp * 0.38
	boss.state = DreamEnemy.State.IDLE
	boss.attack_cooldown = 99.0
	world.boss_engaged = true
	world.shards_collected = 2
	world.has_relic = true
	world.bridge_revealed = true
	player.respawn_at(Vector3(25.8, 0.05, -22.4), -PI * 0.5)
	player.face_target(boss)
	player.hp = 58.0
	player.energy = 72.0
	player.stamina = 70.0
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.set_film_camera(Vector3(33.8, 6.9, -16.0), Vector3(26.8, 1.1, -22.5), 11.8)
	await create_timer(0.25).timeout
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.fx.clear_effects()
	player.press_attack()
	await create_timer(0.05).timeout
	player.release_attack()
	await create_timer(0.18).timeout
	world.fx.sparks(boss.global_position + Vector3.UP, Color(1.0, 0.72, 0.4), 28)
	await _shot("06_boss_duel")


func _shot_victory() -> void:
	boss.take_damage(99999.0, false, player.global_position)
	await create_timer(0.6).timeout
	world.hud.room_title_left = 0.0
	world.hud._toast_left = 0.0
	world.fx.clear_effects()
	world.set_film_camera(Vector3(34.0, 10.0, -10.8), Vector3(27.0, 1.2, -22.6), 15.2)
	await create_timer(0.3).timeout
	await _shot("07_victory")


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name + ".png")
	image.save_png(path)
	saved += 1
	print("SHOT ", name, " -> ", path)
