extends SceneTree

## T-20261127-018 real-GPU screenshots at 1920x1080.
## Run: godot --path godot-legion-td -s tools/screenshot_legion_td.gd
## Output: docs/shots/*.png + last line LEGION_TD_SHOTS_OK

const D := preload("res://scripts/legion_data.gd")
const OUT_DIR := "res://docs/shots/"
const SIZE := Vector2i(1920, 1080)
const UI_SCALE := 1.5

var sv: SubViewport
var game
var captured: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	sv = SubViewport.new()
	sv.size = SIZE
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(sv)
	game = load("res://scenes/main.tscn").instantiate()
	sv.add_child(game)
	for i in 12:
		await process_frame
	game.ui.scale = Vector2(UI_SCALE, UI_SCALE)
	game.debug_lock_camera = true
	game.set_process(false)

	# 01 — 开局总览：核心、初始军团、建造点与三条石道。
	game.world.set_camera(Vector3(0, 0, 23), 56.0)
	await _warm()
	await _shot("01_overview.png")

	# 02 — 塔防交战：第 4 波、多座塔、框选军团。
	game.debug_add_resources(900, 90)
	for i in 6:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.debug_start_wave(4)
	# 让军团在中段石道迎敌，便于镜头同时拍到塔、单位和核心。
	game.units[0].global_position = Vector3(-4, 0, 13)
	game.units[1].global_position = Vector3(1, 0, 14)
	game.units[2].global_position = Vector3(4, 0, 11)
	game.units[3].global_position = Vector3(-1, 0, 10)
	for i in 7:
		var p: Vector3 = Vector3(-7 + i * 2.4, 0, 5 + (i % 3) * 2.5)
		game.debug_spawn_enemy("crawler" if i % 3 else "spitter", i % 3, p, 2.0, 0.2, 0.0)
	game.simulate(1.6)
	game.select_all_units()
	game.world.set_camera(Vector3(0, 0, 18), 42.0)
	await _warm()
	await _shot("02_battle.png")

	# 03 — 技能 / 混战特写：把敌人拉到军团附近并施放 Q。
	game.debug_add_resources(200, 20)
	for i in 5:
		var p: Vector3 = game.hero.global_position + Vector3(-6 + i * 3, 0, -4 - (i % 2) * 2)
		game.debug_spawn_enemy("crawler" if i % 2 == 0 else "spitter", i % 3, p, 2.2, 0.15, 0.0)
	game.simulate(0.4)
	game.world.set_camera(game.hero.global_position, 32.0)
	game.hero_skill()
	game.banner_t = 0.0
	await _warm()
	await _shot("03_hero_skill.png")

	# 04 — 建造面板：选中固定建造点。
	game.world.set_camera(Vector3(0, 0, 18), 44.0)
	game.select_pad(2)
	await _warm()
	await _shot("04_build_panel.png")

	# 05 — 每波三选一。
	game.clear_selection()
	game.banner_t = 0.0
	game.debug_force_upgrade()
	await _warm()
	await _shot("05_upgrade.png")

	# 06 — 帮助面板。
	game.pick_upgrade(0)
	game.ui.set_help_visible(true)
	game.world.set_camera(Vector3(0, 0, 22), 50.0)
	await _warm()
	await _shot("06_help.png")
	game.ui.set_help_visible(false)

	# 07 — 胜利结算。
	game.debug_win()
	await _warm()
	await _shot("07_win.png")

	# 08 — 失败结算。
	game.debug_lose()
	await _warm()
	await _shot("08_lose.png")

	# 09 — 三座敌人传送门与来袭虫群。
	game.restart_run(424242)
	game.set_process(false)
	game.debug_add_resources(500, 50)
	game.debug_start_wave(2)
	game.simulate(3.0)
	game.clear_selection()
	game.banner_t = 0.0
	game.world.set_camera(Vector3(0, 0, -25), 58.0)
	await _warm()
	await _shot("09_portals.png")

	print("LEGION_SHOT_COUNT=", captured.size())
	for p in captured:
		print("LEGION_SHOT_FILE=", p)
	print("LEGION_TD_SHOTS_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _warm() -> void:
	await create_timer(1.2).timeout
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	var path := ProjectSettings.globalize_path(OUT_DIR + name)
	var img: Image = sv.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("LEGION_SHOT_FAIL empty ", name)
		return
	img.save_png(path)
	print("LEGION_SHOT %s %dx%d" % [name, img.get_width(), img.get_height()])
	captured.append(path)
	await process_frame
