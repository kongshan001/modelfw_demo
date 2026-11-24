extends SceneTree

# 1920×1080 真 GPU 截图矩阵：起跑/追尾/加速/暂停/风景/冲线。
# HUD 自己按视口缩放，因此这里只把场景放进 1920×1080 SubViewport。
# 运行：
#   godot --path godot-ai-3d-game --resolution 1280x720 -s tools/screenshot_race.gd

const OUT_DIR := "res://docs/shots"
const VIEW_SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var world: RaceWorld
var saved: Array[String] = []


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	vp = SubViewport.new()
	vp.size = VIEW_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await process_frame
	world = scene as RaceWorld
	# 先冻结倒计时做 GPU 预热，避免第一张截图读到 shader 编译期的低 FPS。
	world.capture_freeze = true
	await create_timer(2.4).timeout
	print("SHOT_VIEWPORT ", vp.size, " hud_scale_target=", float(VIEW_SIZE.x) / 1280.0)

	# 01 起跑格 + 拱门 + 倒计时
	await _shot("01_start_grid")
	world.debug_start_now()
	await create_timer(0.3).timeout

	# 02 追尾竞速：中段弯道
	world.elapsed = 8.42
	world.debug_place_player_at_distance(world.track.length * 0.285, 23.8)
	world.debug_set_rival_distance(0, world.track.length * 0.30)
	world.debug_set_rival_distance(1, world.track.length * 0.255)
	world.player.visual.update_motion(0.016, 23.8, 0.12, false)
	await create_timer(0.8).timeout
	await _shot("02_chase_corner")

	# 03 加速带冲刺：低机位三分之四视角，同时看清车、箭头和 HUD
	world.elapsed = 12.18
	var pad_progress: float = world.boost_pads[1]["progress"]
	var pad_race := fposmod(pad_progress - world.player.start_progress, world.track.length)
	world.debug_place_player_at_distance(pad_race - 8.0, 30.0)
	world.player.boost_count = 0
	world.player.boost_timer = 0.0
	world.player.apply_boost(2.4)
	world.boost_flash = 1.0
	world.player.visual.update_motion(0.016, 30.0, 0.04, true)
	world.debug_set_rival_distance(0, pad_race - 12.0)
	world.debug_set_rival_distance(1, pad_race + 10.0)
	var pad_center: Vector3 = world.boost_pads[1]["center"]
	var pad_tangent := world.track.tangent_at(pad_progress)
	var pad_right := world.track.right_at(pad_progress)
	world.set_film_camera(
		world.player.global_position - pad_tangent * 4.8 - pad_right * 6.2 + Vector3.UP * 3.25,
		pad_center + Vector3.UP * 0.8)
	await create_timer(0.35).timeout
	await _shot("03_boost_pad")

	# 04 暂停：用固定的侧后机位做背景，避免低机位切镜时车身贴脸
	world.player.boost_timer = 0.0
	world.boost_flash = 0.0
	world.player.speed = 0.0
	world.player.visual.update_motion(0.016, 0.0, 0.0, false)
	var fwd := world.player.forward()
	var side := world.track.right_at(float(world.track.nearest(world.player.global_position)["progress"]))
	world.set_film_camera(
		world.player.global_position - fwd * 6.4 + side * 3.2 + Vector3.UP * 3.0,
		world.player.global_position + fwd * 4.0 + Vector3.UP * 0.9)
	await create_timer(0.4).timeout
	world.toggle_pause()
	await create_timer(0.35).timeout
	await _shot("04_pause")
	world.toggle_pause()
	world.clear_film_camera()

	# 05 航拍赛道：展示环形赛道、风车与三名车手位置
	world.capture_freeze = true
	world.clear_film_camera()
	world.player.boost_timer = 0.0
	world.boost_flash = 0.0
	world.set_film_camera(Vector3(58.0, 62.0, 66.0), Vector3(0.0, 0.0, -1.0))
	await create_timer(0.5).timeout
	await _shot("05_circuit_aerial")

	# 06 冲线结算：走真实 race_distance 判定
	world.clear_film_camera()
	world.capture_freeze = false
	world.debug_place_player_at_distance(world.race_goal - 8.0, 25.0)
	world.debug_set_rival_distance(0, world.race_goal - 22.0)
	world.debug_set_rival_distance(1, world.race_goal - 36.0)
	var waited := 0.0
	while world.state != RaceWorld.RaceState.FINISHED and waited < 5.0:
		await create_timer(0.1).timeout
		waited += 0.1
	world.capture_freeze = true
	await create_timer(1.25).timeout
	await _shot("06_finish_win")
	print("FINISH_STATE state=%d place=%d elapsed=%.2f" % [world.state, world.finish_place, world.finish_time])

	print("RACE_SHOTS_OK count=%d fps=%d" % [saved.size(), Engine.get_frames_per_second()])
	world.queue_free()
	vp.queue_free()
	await process_frame
	quit(0)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, shot_name])
	image.save_png(path)
	saved.append(path)
	print("SHOT ", shot_name, " -> ", path)
