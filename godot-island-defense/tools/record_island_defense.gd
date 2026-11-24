extends SceneTree
## 10 秒演出录制：1920×1080 @ 30fps，300 帧 JPG 写入 /tmp/island_defense_frames。
## 用法：godot --path godot-island-defense -s tools/record_island_defense.gd
## 之后用 ffmpeg 编码为 docs/mistbound_watch_demo.mp4 / .gif。

const SIZE := Vector2i(1920, 1080)
const FRAME_DIR := "/tmp/island_defense_frames"
const FPS := 30

var vp: SubViewport
var game
var frame_index := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	_clear_frames()
	vp = SubViewport.new()
	vp.size = SIZE
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	game = load("res://scenes/main.tscn").instantiate()
	vp.add_child(game)
	await _settle(24)
	game.auto_simulate = false
	game.demo_mode = true
	game.set_process(false)
	game.debug_start_playing(0, true)
	await _settle(20)
	game.prep_timer = 18.0
	_clear_banner()
	game.debug_move_squad(0, Vector3(-4.5, 0, 3.4))
	game.debug_move_squad(1, Vector3(5.5, 0, 2.6))
	game.debug_move_squad(2, Vector3(0.5, 0, -1.5))
	_sim(1.6)
	game.debug_select_squad(0, false)

	# 0–2s 布防
	for i in range(60):
		var t := float(i) / 59.0
		var pivot := Vector3(2.0, 0, 4.0).lerp(Vector3(0, 0, 1.2), t)
		_set_camera(pivot, lerpf(42.0, 35.0, t), lerpf(-30.0, -38.0, t), 48.0)
		await _tick(true)

	# 2–5s 登陆
	game.debug_launch_wave(1)
	game.wave_state = "active"
	game.wave_number = 1
	game.show_banner("第 1 波 · 海掠者登陆", "右键调度 · 守住三座房屋", 2.0)
	var landing: Dictionary = game.island.landing_points[0]
	for i in range(90):
		var t := float(i) / 89.0
		_set_camera(landing["pos"], lerpf(30.0, 24.0, t), lerpf(-42.0, -55.0, t), 45.0)
		if i == 45:
			_clear_banner()
		if i == 58:
			game.debug_spawn_enemy("raider", landing["pos"] + Vector3(-1.2, 0, 2.6))
			game.debug_spawn_enemy("raider", landing["pos"] + Vector3(1.4, 0, 3.4))
		await _tick(true)

	# 5–7.5s 接战 / 克制
	var spear = game.squads[2]
	game.debug_spawn_enemy("chieftain", spear.center + Vector3(2.8, 0, -1.6))
	game.debug_spawn_enemy("raider", spear.center + Vector3(0.8, 0, -3.0))
	game.debug_spawn_enemy("raider", spear.center + Vector3(4.2, 0, -2.8))
	game.debug_spawn_enemy("skirmisher", spear.center + Vector3(7.0, 0, -3.6))
	game.debug_select_squad(2, false)
	game.wave_number = 2
	for i in range(75):
		var t := float(i) / 74.0
		var pivot: Vector3 = spear.center.lerp(spear.center + Vector3(1.0, 0, -1.0), t)
		_set_camera(pivot, lerpf(20.0, 17.0, t), lerpf(-40.0, -47.0, t), 44.0)
		if i == 34 or i == 60:
			_clear_banner()
		await _tick(true)

	# 7.5–8.7s 房屋受击
	game.debug_damage_house(0, 82.0)
	var hpos: Vector3 = game.houses[0].global_position
	game.debug_spawn_enemy("brute", hpos + Vector3(2.2, 0, 1.4))
	game.debug_spawn_enemy("raider", hpos + Vector3(-2.0, 0, 2.0))
	game.wave_number = 3
	_clear_banner()
	for i in range(36):
		var t := float(i) / 35.0
		_set_camera(hpos + Vector3(0.0, 0, 1.0), lerpf(22.0, 18.0, t), lerpf(-26.0, -20.0, t), 44.0)
		await _tick(true)

	# 8.7–10s 结算
	game.kills = 21
	game.run_time = 101.5
	game.waves_cleared = 3
	game.wave_state = "done"
	game.houses[2].take_damage(99999.0)
	game.debug_finish(true, "三波海掠者尽数退去，屋火未熄。")
	_clear_banner()
	for i in range(40):
		var t := float(i) / 39.0
		_set_camera(Vector3(0, 0, 0), lerpf(36.0, 48.0, t), -38.0, 48.0)
		await _tick(false)

	print("ISLAND_DEFENSE_RECORD_OK frames=", frame_index)
	quit(0)


func _tick(simulate: bool) -> void:
	if simulate and game.state == "playing":
		game.simulate(1.0 / float(FPS))
	await process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := "%s/frame_%04d.jpg" % [FRAME_DIR, frame_index]
	var err := image.save_jpg(path, 0.92)
	if err != OK:
		printerr("FRAME SAVE FAIL ", path, " err=", err)
	frame_index += 1
	if frame_index % 60 == 0:
		print("recorded ", frame_index, " frames")


func _sim(seconds: float) -> void:
	var steps := maxi(1, int(seconds * float(FPS)))
	for _i in range(steps):
		if game.state != "playing":
			break
		game.simulate(1.0 / float(FPS))


func _set_camera(pos: Vector3, size_value: float, yaw_value: float, pitch_value: float) -> void:
	game.debug_focus_camera(pos, size_value, yaw_value, pitch_value)


func _clear_banner() -> void:
	game.banner_text = ""
	game.banner_sub = ""
	game.banner_timer = 0.0


func _settle(frames: int) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw


func _clear_frames() -> void:
	var dir := DirAccess.open(FRAME_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("frame_"):
			dir.remove(name)
		name = dir.get_next()
	dir.list_dir_end()
