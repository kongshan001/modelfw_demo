extends SceneTree
## 《苔关八波》1920×1080 验收截图：W1 战斗、建造面板、W4 精英、三选一、
## W8 Boss、失败结算、胜利结算。
## 用法：godot --path . --resolution 1920x1080 --script tools/screenshot_wave_defense.gd
## 输出：res://docs/shots/wd_*.png

const Data = preload("res://scripts/game_data.gd")
const SAVE_PATH := "user://wd_shot_save.json"
const SHOT_DIR := "res://docs/shots/"

var main
var _viewport: SubViewport
var _shot_count := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
	_remove_save()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	main = scene
	# 1280×720 逻辑画布按 1.5 倍绘制到真正的 1920×1080 SubViewport。
	main.scale = Vector2(1.5, 1.5)
	main.ui_layer.scale = Vector2(1.5, 1.5)
	main.demo_use_save_path(SAVE_PATH)
	main.demo_set_manual_tick(true)
	print("SUBVIEWPORT=%s" % _viewport.size)

	await _shot_build_menu()
	await _shot_wave1()
	await _shot_wave4()
	await _shot_upgrade()
	await _shot_boss()
	await _shot_defeat()
	await _shot_victory()

	print("SCREENSHOTS_DONE %d" % _shot_count)
	main.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _remove_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _settle(frames := 4) -> void:
	for i in range(frames):
		await process_frame


func _capture(name: String) -> void:
	main.hud.toast_t = 0.0
	main.hud.toast_text = ""
	main.hud.queue_redraw()
	await _settle(2)
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path := SHOT_DIR + name
	image.save_png(path)
	_shot_count += 1
	print("SHOT: %s (%dx%d)" % [ProjectSettings.globalize_path(path), image.get_width(), image.get_height()])


func _clear_text_near(pos: Vector2, radius: float) -> void:
	var kept: Array = []
	for eff in main.fx.effects:
		if String(eff["kind"]) == "text" and (eff["pos"] as Vector2).distance_to(pos) <= radius:
			continue
		kept.append(eff)
	main.fx.effects = kept
	main.fx.queue_redraw()


func _tick_until(kinds: Array, max_seconds: float, warmup := 0.6) -> void:
	var t := 0.0
	while t < max_seconds:
		main.demo_tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if t < warmup:
			continue
		for eff in main.fx.effects:
			if String(eff["kind"]) in kinds:
				return


func _shot_build_menu() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(300)
	main.demo_build_tower(0, "crossbow")
	main.arena.set_hover_pad(1)
	main.demo_open_build_menu(1)
	await _settle()
	await _capture("wd_01_build_menu.png")


func _shot_wave1() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(400)
	main.demo_build_tower(0, "crossbow")
	main.demo_skip_prep()
	# 手工摆位以便构图；关闭本波自动生成，保持 HUD “剩余 6 / 6” 自洽。
	main.waves.spawn_cursor = main.waves.spawn_plan.size()
	main.demo_spawn_enemy("militia", 300.0, -8.0)
	main.demo_spawn_enemy("militia", 338.0, 7.0)
	main.demo_spawn_enemy("militia", 378.0, -2.0)
	main.demo_spawn_enemy("militia", 420.0, 10.0)
	main.demo_spawn_enemy("militia", 462.0, -5.0)
	main.demo_spawn_enemy("militia", 504.0, 6.0)
	main.demo_set_player_pos(Data.path_point_at(408.0) + Vector2(-26, 48))
	_tick_until(["beam", "slash"], 2.5, 0.9)
	await _settle(2)
	await _capture("wd_02_wave1_combat.png")


func _shot_wave4() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(2000)
	main.demo_build_tower(0, "crossbow")
	main.demo_upgrade_tower(0)
	main.demo_build_tower(1, "cannon")
	main.demo_upgrade_tower(1)
	main.demo_build_tower(2, "cannon")
	main.state.apply_upgrade("range")
	main.demo_set_wave(3)
	main.demo_skip_prep()
	main.demo_spawn_enemy("runner", 512.0, -10.0)
	main.demo_spawn_enemy("shield", 560.0, 8.0)
	main.demo_spawn_enemy("elite", 604.0, -4.0)
	main.demo_spawn_enemy("shield", 648.0, 12.0)
	main.demo_set_player_pos(Data.path_point_at(640.0) + Vector2(46, 52))
	main.waves.spawn_cursor = main.waves.spawn_plan.size()
	_tick_until(["explosion", "beam", "slash"], 3.0, 1.1)
	await _settle(2)
	await _capture("wd_03_wave4_elite.png")


func _shot_upgrade() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.state.kills = 48
	main.demo_open_upgrade(1, false)
	await _settle()
	await _capture("wd_04_upgrade_choice.png")


func _shot_boss() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(3000)
	main.demo_build_tower(0, "crossbow")
	main.demo_upgrade_tower(0)
	main.demo_build_tower(1, "cannon")
	main.demo_upgrade_tower(1)
	main.demo_build_tower(2, "cannon")
	main.demo_upgrade_tower(2)
	main.state.apply_upgrade("range")
	main.state.apply_upgrade("tower_rate")
	main.demo_set_wave(7)
	main.demo_skip_prep()
	main.demo_spawn_enemy("boss", 700.0, 0.0)
	main.demo_spawn_enemy("militia", 742.0, -14.0)
	main.demo_spawn_enemy("militia", 768.0, 12.0)
	main.demo_spawn_enemy("militia", 794.0, -7.0)
	main.demo_spawn_enemy("militia", 820.0, 15.0)
	main.demo_set_player_pos(Data.path_point_at(742.0) + Vector2(-30, 66))
	main.waves.spawn_cursor = main.waves.spawn_plan.size()
	_tick_until(["explosion", "beam", "slash"], 3.2, 1.4)
	var boss = main.get_active_boss()
	if boss != null:
		boss.flash = 0.0
		boss.queue_redraw()
		_clear_text_near(boss.position, 120.0)
	await _settle(2)
	await _capture("wd_05_wave8_boss.png")


func _shot_defeat() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_wave(7)
	main.state.kills = 96
	main.demo_set_gold(180)
	main.demo_finish(true, 8)
	main.demo_restart()
	# 真打一段失败：墙破、3 名敌人破门、主城归零。
	main.demo_set_wave(4)
	main.demo_skip_prep()
	main.waves.spawn_cursor = main.waves.spawn_plan.size()
	main.state.kills = 118
	main.demo_set_gold(240)
	main.demo_set_player_pos(Vector2(1160, 640))
	main.demo_damage_wall(999.0)
	main.demo_spawn_enemy("shield", Data.path_length() - 8.0, -4.0)
	main.demo_spawn_enemy("shield", Data.path_length() - 12.0, 8.0)
	main.demo_spawn_enemy("elite", Data.path_length() - 16.0, 0.0)
	main.demo_set_castle_hp(14)
	var guard := 0
	while not main.run_over and guard < 600:
		main.demo_tick(1.0 / 60.0)
		guard += 1
	await _settle()
	await _capture("wd_06_defeat_result.png")


func _shot_victory() -> void:
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_wave(7)
	main.demo_set_gold(3000)
	main.demo_build_tower(0, "crossbow")
	main.demo_upgrade_tower(0)
	main.demo_build_tower(1, "cannon")
	main.demo_upgrade_tower(1)
	main.demo_build_tower(2, "cannon")
	main.demo_upgrade_tower(2)
	main.state.kills = 150
	main.demo_set_gold(300)
	main.demo_set_castle_hp(100)
	main.waves.wave_cleared = 8
	main.waves.phase = "victory"
	main.demo_finish(true, 8)
	await _settle()
	await _capture("wd_07_victory_result.png")
