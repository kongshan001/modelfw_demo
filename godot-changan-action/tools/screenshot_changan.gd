extends SceneTree

## 真实 GPU 截图（1920×1080）：
##   godot --path . --resolution 1920x1080 -s tools/screenshot_changan.gd
## 输出 docs/shots/*.png。只用实机渲染，不伪造截图。

const OUT := "res://docs/shots"
const W := 1920
const H := 1080

var vp: SubViewport
var scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	scene = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await create_timer(1.6).timeout
	scene.set_mouse_capture(false)
	scene.set_hud_visible(true)

	# 01 — 标题 / 夜街第一眼
	await create_timer(0.8).timeout
	await _shot("01_title")

	scene.start_game()
	scene.set_mouse_capture(false)
	await create_timer(0.5).timeout

	# 02 — 夜街全景（牌楼/灯笼/摊位/地面层次）
	scene.demo_teleport(Vector3(0.0, 0.06, 7.4), 0.0)
	scene.demo_light_lamp(0)
	scene.set_cinematic_camera(Vector3(1.25, 1.95, 2.6), Vector3(0.0, 1.45, 24.0), 58.0)
	scene.demo_set_quest("去面摊找阿禾（E 交谈）")
	await create_timer(1.2).timeout
	await _shot("02_street_night")

	# 03 — 阿禾对话（过肩）
	scene.demo_teleport(Vector3(-3.35, 0.06, 12.6), 0.0)
	scene.player.aim_at(Vector3(-5.05, 0.0, 12.6))
	scene.demo_talk("ahe")
	scene.set_cinematic_camera(Vector3(-1.0, 1.95, 9.2), Vector3(-4.4, 1.25, 13.2), 52.0)
	await create_timer(0.7).timeout
	await _shot("03_dialogue_ahe")
	scene.demo_skip_dialogue()
	await create_timer(0.3).timeout

	# 04 — 战斗 1：两泼皮 + 锁定
	scene.demo_teleport(Vector3(0.0, 0.06, 16.5), 0.0)
	scene.demo_start_wave(1)
	await create_timer(0.2).timeout
	scene.set_controls_enabled(false)
	for e in scene.wave_enemies:
		e.active = false
		e.global_position = scene.player.global_position + Vector3(-1.9 if e.slot == 0 else 3.2, 0, 2.4)
		e.rotation.y = PI
		e.play_anim("Idle", 0.1)
	scene.lock_target = scene.wave_enemies[0]
	scene.set_cinematic_camera(Vector3(3.35, 2.45, 12.2), Vector3(0.0, 1.20, 19.5), 55.0)
	await create_timer(0.8).timeout
	await _shot("04_combat1")

	# 05 — 3 连终结 / 命中数字 / 连击
	scene.player.global_position = Vector3(0.0, 0.06, 17.6)
	scene.player.rotation.y = 0.0
	var enemy = scene.wave_enemies[0]
	enemy.global_position = Vector3(0.2, 0.06, 19.2)
	enemy.hp = enemy.max_hp
	enemy.state = "idle"
	enemy.rotation.y = PI
	scene.wave_enemies[1].visible = false
	scene.set_cinematic_camera(Vector3(3.2, 2.25, 14.6), Vector3(0.0, 1.25, 19.3), 49.0)
	scene.combo = 2
	scene.combo_timer = 2.4
	scene.player.combo_window = 1.0
	scene.player.combo_step = 2
	scene.player.begin_attack("kick")
	await create_timer(0.38).timeout
	await _shot("05_combo_finisher")

	# 06 — 翻滚（i-frames）
	scene.demo_clear_wave()
	await create_timer(0.4).timeout
	for e in scene.enemies:
		if is_instance_valid(e):
			e.visible = false
	for l in scene._dmg_pool:
		if is_instance_valid(l):
			l.visible = false
	scene.combo = 0
	scene.combo_timer = 0.0
	scene.toast_text = ""
	scene.toast_timer = 0.0
	scene.demo_teleport(Vector3(0.0, 0.06, 23.2), 0.0)
	scene.demo_set_lights(1)
	scene.demo_set_quest("空格翻滚 · i-frames 0.08–0.30s")
	var brute = scene.spawn_enemy("brute", Vector3(-1.5, 0.06, 25.6), 0)
	brute.rotation.y = atan2(1.5, -2.4)
	brute.active = true
	brute._start_attack("slam")
	await create_timer(0.10).timeout
	scene.set_cinematic_camera(Vector3(4.5, 2.0, 23.2), Vector3(0.0, 0.9, 25.6), 50.0)
	scene.player.start_roll(Vector3(0, 0, 1))
	await create_timer(0.22).timeout
	await _shot("06_roll_iframes")
	brute.active = false
	brute.visible = false

	# 07 — 街灯 3/3（三种暖光 + HUD）
	scene.demo_set_lights(3)
	scene.demo_teleport(Vector3(1.8, 0.06, 27.0), 0.0)
	scene.player.aim_at(Vector3(3.4, 0.0, 30.0))
	scene.demo_set_quest("点亮三盏街灯（3/3）")
	scene.toast_text = ""
	scene.toast_timer = 0.0
	scene.set_cinematic_camera(Vector3(-1.2, 2.25, 25.2), Vector3(2.4, 2.2, 31.5), 52.0)
	await create_timer(1.0).timeout
	await _shot("07_street_lamps")

	# 08 — Boss 二阶段熄灯
	scene.demo_teleport(Vector3(0.0, 0.06, 69.5), 0.0)
	scene.demo_start_boss()
	await create_timer(0.2).timeout
	scene.skip_boss_intro()
	await create_timer(0.2).timeout
	if scene.boss_ref != null:
		scene.boss_ref.global_position = Vector3(0.0, 0.06, 76.5)
		scene.boss_ref.rotation.y = PI
	scene.demo_boss_phase2()
	await create_timer(0.2).timeout
	scene.demo_teleport(Vector3(3.7, 0.06, 72.0), PI * 0.75)
	if scene.boss_ref != null and is_instance_valid(scene.boss_ref):
		scene.boss_ref.global_position = Vector3(0.0, 0.06, 76.5)
		scene.boss_ref.rotation.y = PI
		scene.boss_ref.active = false
		scene.boss_ref.play_anim("Idle", 0.1)
	scene.set_cinematic_camera(Vector3(1.7, 2.05, 70.2), Vector3(0.0, 1.48, 76.5), 47.0)
	await create_timer(1.1).timeout
	await _shot("08_boss_phase2")

	# 09 — 结算（Boss 已败、灯已恢复，和真实流程一致）
	if scene.boss_ref != null and is_instance_valid(scene.boss_ref):
		scene.demo_kill_enemy(scene.boss_ref)
	await create_timer(0.4).timeout
	scene.world.restore_light()
	scene.elapsed = 612.0
	scene.max_combo = 7
	scene.hits_taken = 3
	scene.street_lights_lit = 3
	scene.set_hud_visible(true)
	scene.demo_force_results("mercy")
	scene.set_mouse_capture(false)
	scene.set_cinematic_camera(Vector3(1.8, 2.2, 69.0), Vector3(0.0, 1.5, 77.0), 50.0)
	await create_timer(0.6).timeout
	await _shot("09_results")

	print("CHANGAN_SCREENSHOTS_OK 9 shots")
	await _cleanup()
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT) + "/" + name + ".png")
	print("SHOT ", name)


func _cleanup() -> void:
	scene.queue_free()
	vp.queue_free()
	await process_frame
	await process_frame
