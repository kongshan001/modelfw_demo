extends SceneTree

# 真实 GPU 截图：1280×720，覆盖到货 / 自瞄 / 钩子飞行 / 命中 / 建造 / 放置 / 设施 / 夜晚 / 胜利。
const OUT_DIR := "res://docs/shots"

var _vp: SubViewport
var _scene: Node
var _world: RaftWorld
var _hud: RaftHud


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_vp = SubViewport.new()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(1.5).timeout
	_world = _scene.get_node("ViewportContainer/WorldViewport/World")
	_hud = _scene.get_node("HUD")
	_world.spawn_enabled = false
	_world.clear_loot()
	_world.debug_spawn_loot("barrel", Vector3(5.2, 0.0, -2.0))
	_world.debug_spawn_loot("crate", Vector3(-4.2, 0.0, 4.2))
	_world.debug_spawn_loot("fish", Vector3(2.2, 0.0, -5.5))
	await create_timer(0.5).timeout

	# 1. 到货：木筏、角色、漂浮物、HUD
	await _shot("01_arrival")

	# 2. 自瞄锁定 + 蓄力
	_hud.clear_toasts()
	_world.begin_charge()
	await create_timer(0.6).timeout
	await _shot("02_auto_lock")

	# 3. 钩子飞行（追踪绳索，等多几帧保证绳子拉出）
	_world.release_cast()
	for i in 16:
		await process_frame
		if _world.hook_state != "flying" or _world.hook_pos.distance_to(_world.call("_rod_tip")) > 3.0:
			break
	await _shot("03_hook_flight")

	# 4. 命中回收 + 飘字 + toast
	await create_timer(0.52).timeout
	await _shot("04_hook_catch")

	# 5. 扩建 + 建造菜单
	_world.inventory["planks"] = 30
	_world.inventory["wood"] = 30
	_world.build("expand", Vector2i(2, 0))
	await create_timer(0.5).timeout
	_world.build("expand", Vector2i(2, 1))
	await create_timer(0.5).timeout
	_world.build("expand", Vector2i(2, 2))
	await create_timer(0.5).timeout
	_world.build("expand", Vector2i(1, 2))
	await create_timer(0.55).timeout
	_hud.clear_toasts()
	_hud.clear_floaters()
	_hud.toggle_build(true)
	await create_timer(0.3).timeout
	await _shot("05_build_menu")

	# 6. 放置绿色 ghost
	_hud.toggle_build(false)
	_world.begin_place("expand")
	_world.update_ghost(Vector2i(-1, 1))
	await create_timer(0.25).timeout
	await _shot("06_placing")
	_world.cancel_placement()

	# 7. 设施：木箱 / 净水器 / 烤鱼架 + 自动收取
	_world.build("crate", Vector2i(2, 2))
	_world.build("purifier", Vector2i(2, 1))
	_world.build("grill", Vector2i(2, 0))
	_world.inventory["wood"] = 12
	_world.inventory["fish"] = 5
	_world.debug_tick_stations(20.0)
	_world.player.global_position = _world.cell_center(Vector2i(1, 1))
	_world.cam_size = 10.4
	await create_timer(0.6).timeout
	_hud.clear_toasts()
	_hud.clear_floaters()
	_world.debug_collect_stations()
	await create_timer(0.22).timeout
	await _shot("07_stations")

	# 8. 夜晚 / 环视
	_world.debug_set_day_phase(0.90)
	_world.cam_size = 11.2
	_world.orbit(deg_to_rad(-24.0))
	await create_timer(0.7).timeout
	_hud.clear_toasts()
	_hud.clear_floaters()
	await _shot("08_night")

	# 9. 胜利结算
	_world.day = 2
	_world.debug_set_day_phase(0.32)
	_world.orbit(deg_to_rad(24.0))
	_world.cam_size = 12.6
	_world.inventory["planks"] = 18
	for cell in [Vector2i(0, 2), Vector2i(-1, 2), Vector2i(-1, 1), Vector2i(-1, 0)]:
		_world.build("expand", cell)
	await create_timer(0.9).timeout
	await _shot("09_win")

	await create_timer(1.0).timeout
	print("FPS_SAMPLE ", Engine.get_frames_per_second())
	print("RAFT_SHOTS_OK")
	quit(0)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_DIR + "/" + name + ".png")
	image.save_png(path)
	print("SHOT ", name, " -> ", path)
