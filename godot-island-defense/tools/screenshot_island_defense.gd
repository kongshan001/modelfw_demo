extends SceneTree
## 真实 GPU 截图：1920×1080 SubViewport + 1280×720 逻辑 HUD。
## 用法：godot --path godot-island-defense -s tools/screenshot_island_defense.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var game


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	call_deferred("_run")


func _run() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	await _settle(30)

	game.auto_simulate = false
	game.demo_mode = true
	game.set_process(false)
	_clear_banner()
	game.debug_focus_camera(Vector3(0, 0, 0), 48.0, -28.0, 46.0)
	await _settle(20)
	await _shot("01_intro_1920x1080")

	# 布防
	game.debug_start_playing(0, true)
	await _settle(24)
	game.prep_timer = 18.0
	game.squads[0].teleport(game.island.clamp_to_walkable(Vector3(-4.0, 0, 3.4)))
	game.squads[1].teleport(game.island.clamp_to_walkable(Vector3(5.0, 0, 2.6)))
	game.squads[2].teleport(game.island.clamp_to_walkable(Vector3(0.5, 0, -3.0)))
	await _settle(4)
	game.debug_select_squad(0, false)
	game.debug_focus_camera(Vector3(0, 0, 0.8), 36.0, -37.0, 48.0)
	await _settle(12)
	await _shot("02_deployment_1920x1080")

	# 登陆 / 第一波
	game.debug_launch_wave(1)
	_sim(4.6)
	_clear_banner()
	var landing: Dictionary = game.island.landing_points[0]
	game.debug_focus_camera(landing["pos"], 23.0, -53.0, 45.0)
	await _settle(12)
	await _shot("03_landing_1920x1080")

	# 克制 / 混战
	game.debug_start_playing(0, true)
	await _settle(24)
	game.debug_move_squad(2, Vector3(0.0, 0, 0))
	game.debug_move_squad(1, Vector3(-5.0, 0, 4.6))
	game.debug_move_squad(0, Vector3(5.2, 0, 3.4))
	_sim(2.6)
	game.debug_select_squad(2, false)
	game.debug_spawn_enemy("chieftain", Vector3(3.2, 0, -2.6))
	game.debug_spawn_enemy("raider", Vector3(1.2, 0, -4.0))
	game.debug_spawn_enemy("raider", Vector3(4.8, 0, -4.4))
	game.debug_spawn_enemy("skirmisher", Vector3(8.5, 0, -5.0))
	game.wave_state = "active"
	game.wave_number = 2
	_sim(1.8)
	_clear_banner()
	game.debug_focus_camera(Vector3(1.2, 0, -1.0), 18.5, -45.0, 44.0)
	await _settle(10)
	await _shot("04_counter_1920x1080")

	# 房屋受击
	game.debug_start_playing(0, true)
	await _settle(24)
	game.debug_damage_house(0, 82.0)
	var hpos: Vector3 = game.houses[0].global_position
	game.debug_spawn_enemy("brute", hpos + Vector3(2.4, 0, 1.6))
	game.debug_spawn_enemy("raider", hpos + Vector3(-2.3, 0, 2.2))
	game.debug_spawn_enemy("raider", hpos + Vector3(3.4, 0, -1.4))
	game.wave_state = "active"
	game.wave_number = 2
	_sim(3.2)
	_clear_banner()
	game.debug_focus_camera(hpos + Vector3(0.5, 0, 1.0), 18.0, -22.0, 44.0)
	await _settle(12)
	await _shot("05_house_under_attack_1920x1080")

	# 暂停
	_sim(0.4)
	game.set_paused(true)
	await _settle(8)
	await _shot("06_pause_1920x1080")
	game.set_paused(false)

	# 胜利
	game.debug_start_playing(0, true)
	await _settle(20)
	game.kills = 23
	game.run_time = 118.5
	game.waves_cleared = 3
	game.wave_state = "done"
	game.houses[2].take_damage(99999.0)
	game.debug_finish(true, "三波海掠者尽数退去，三座房屋中两座仍在冒烟。")
	_clear_banner()
	await _settle(10)
	await _shot("07_victory_1920x1080")

	# 失败
	game.debug_start_playing(0, true)
	await _settle(20)
	game.kills = 17
	game.run_time = 86.4
	game.waves_cleared = 2
	game.debug_destroy_all_houses()
	_clear_banner()
	await _settle(12)
	await _shot("08_defeat_1920x1080")

	# 第二岛
	game.debug_start_playing(1, true)
	await _settle(24)
	game.prep_timer = 18.0
	game.debug_select_squad(0, false)
	game.debug_focus_camera(Vector3(0, 0, 0), 45.0, -42.0, 47.0)
	_clear_banner()
	await _settle(12)
	await _shot("09_island2_1920x1080")

	print("ISLAND_DEFENSE_SHOTS_OK")
	quit(0)


func _clear_banner() -> void:
	game.banner_text = ""
	game.banner_sub = ""
	game.banner_timer = 0.0


func _sim(seconds: float) -> void:
	var steps := maxi(1, int(seconds / (1.0 / 30.0)))
	for _i in range(steps):
		if game.state != "playing":
			break
		game.simulate(1.0 / 30.0)
	await process_frame


func _settle(frames: int) -> void:
	for _i in range(maxi(1, frames)):
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		printerr("FAILED save ", path, " err=", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
