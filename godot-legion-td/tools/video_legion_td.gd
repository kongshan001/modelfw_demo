extends SceneTree

## T-20261127-018 10 s gameplay capture (1920x1080, 15 fps, manual stepping).
## Run: godot --path godot-legion-td -s tools/video_legion_td.gd
## Frames: /tmp/legionfall_frames_1080/frame_0000.png ...
## Then encode MP4/GIF with ffmpeg.

const D := preload("res://scripts/legion_data.gd")
const FRAME_DIR := "/tmp/legionfall_frames_1080"
const FPS := 15.0
const TOTAL := 150
const UI_SCALE := 1.5

var sv: SubViewport
var game
var saved := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	sv = SubViewport.new()
	sv.size = Vector2i(1920, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(sv)
	game = load("res://scenes/main.tscn").instantiate()
	sv.add_child(game)
	for i in 12:
		await process_frame
	game.ui.scale = Vector2(UI_SCALE, UI_SCALE)
	game.debug_lock_camera = true
	game.ui.debug_hide_perf = true
	game.paused = false
	game.set_process(false)

	# 准备镜头。
	game.world.set_camera(Vector3(0, 0, 23), 56.0)
	await _settle(4)

	# 建塔（视觉准备，不占用视频前段太久）。
	game.debug_add_resources(2000, 200)
	for i in [0, 1, 2, 3, 4, 5]:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
	game.clear_selection()

	# 第 4 波 + 中段交火布景。
	game.debug_start_wave(4)
	game.units[0].global_position = Vector3(-4, 0, 13)
	game.units[1].global_position = Vector3(1, 0, 14)
	game.units[2].global_position = Vector3(4, 0, 11)
	game.units[3].global_position = Vector3(-1, 0, 10)
	game.select_all_units()
	for i in 8:
		var p: Vector3 = Vector3(-8 + i * 2.3, 0, 4 + (i % 3) * 2.4)
		game.debug_spawn_enemy("crawler" if i % 3 else "spitter", i % 3, p, 2.2, 0.18, 0.0)

	var cam_start := Vector3(0, 0, 23)
	var cam_end := Vector3(0, 0, 16)
	for f in TOTAL:
		var t := float(f) / FPS
		if f < 15:
			# 0–1 s：总览，缓慢推近。
			var k := float(f) / 15.0
			game.world.set_camera(cam_start.lerp(cam_end, k), lerpf(56.0, 48.0, k))
		elif f < 27:
			# 1–1.8 s：展示建造面板。
			if f == 15:
				game.select_pad(2)
				game.world.set_camera(Vector3(8, 0, 8), 34.0)
			game.advance(1.0 / FPS)
		elif f < 42:
			# 1.8–2.8 s：镜头转向石道，准备交战。
			if f == 28:
				game.banner_t = 0.0
			if f == 27:
				game.clear_selection()
				game.select_all_units()
				game.world.set_camera(Vector3(0, 0, 13), 38.0)
			game.advance(1.0 / FPS)
		else:
			# 2.8–8.4 s：交战，期间施放英雄技能。
			if f == 54:
				game.hero_skill()
				game.world.set_camera(game.hero.global_position, 30.0)
			elif f == 72:
				game.world.set_camera(Vector3(0, 0, 13), 36.0)
			elif f == 92:
				game.debug_add_resources(0, 0)
				for i in 4:
					var p: Vector3 = Vector3(-4 + i * 3, 0, 8 + (i % 2) * 2)
					game.debug_spawn_enemy("crawler" if i % 2 else "spitter", i % 3, p, 2.0, 0.2, 0.0)
			game.advance(1.0 / FPS)
			# 缓慢横移镜头，让画面不死。
			if f > 42 and f < 126:
				var drift := sin((f - 42) * 0.02) * 1.8
				game.world.pan_camera(Vector3(drift * 0.03, 0, 0))
		if f == 126:
			# 8.4–10 s：波次结束，三选一。
			game.clear_selection()
			game.world.set_camera(Vector3(0, 0, 18), 52.0)
			game.debug_force_upgrade()
		await process_frame
		await RenderingServer.frame_post_draw
		_capture(f)

	print("LEGION_VIDEO_FRAMES=", saved, " dir=", FRAME_DIR)
	print("LEGION_TD_VIDEO_OK")
	game.queue_free()
	await process_frame
	sv.queue_free()
	quit(0)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw


func _capture(index: int) -> void:
	var img: Image = sv.get_texture().get_image()
	if img == null or img.is_empty():
		printerr("LEGION_VIDEO_FRAME_FAIL ", index)
		return
	var path := "%s/frame_%04d.png" % [FRAME_DIR, index]
	img.save_png(path)
	saved += 1
	if saved % 15 == 0:
		print("LEGION_VIDEO_PROGRESS=", saved, " last=", path)
