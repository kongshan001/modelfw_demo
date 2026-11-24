extends SceneTree

# 1920×1080 真 GPU 截图矩阵：10 个 pattern + 时间轴 + 擦弹/命中 + 1200 弹 + 暂停。
# 用 1280×720 逻辑舞台 ×1.5 放进 1920×1080 SubViewport，UI 与世界一起缩放。
# 运行：
#   godot --path godot-bullet-hell --resolution 1280x720 -s tools/capture_bullet_hell.gd

const OUT_DIR := "res://docs/media"
const SLUGS := ["p01_single", "p02_fan3", "p03_fan5", "p04_ring", "p05_spiral", "p06_burst", "p07_sine", "p08_homing", "p09_split", "p10_wall"]
var vp: SubViewport
var stage: Node2D
var game
var out_abs := ""
var saved: Array[String] = []
var base_fps := 60
var only_stress := false

func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for arg in OS.get_cmdline_user_args():
		if arg == "--only=stress":
			only_stress = true
	out_abs = ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	stage = Node2D.new()
	stage.scale = Vector2(1.5, 1.5)
	vp.add_child(stage)
	game = load("res://scenes/main.tscn").instantiate()
	stage.add_child(game)
	await process_frame
	await process_frame
	# 实时渲染 1 秒，记录 1080p 空载/常规密度的真实 FPS（用于 HUD 读数）。
	game.set_process(true)
	await create_timer(2.5).timeout
	base_fps = Engine.get_frames_per_second()
	if base_fps <= 0:
		base_fps = 60
	game.set_process(false)
	print("capture viewport: ", vp.size, " base_fps=", base_fps)
	if only_stress:
		await _capture_stress_only()
		quit(0)
		return
	await _capture_patterns()
	await _capture_features()
	print("saved %d screenshots to %s" % [saved.size(), out_abs])
	quit(0)

func _capture_patterns() -> void:
	var hold := [2.6, 2.2, 2.2, 1.6, 1.8, 0.9, 0.45, 1.6, 1.32, 1.15]
	for id in 10:
		game.reset_run()
		game.debug_set_immunity(true)
		game.set_inspect(id)
		game.debug_step(float(hold[id]))
		game.hud.toast("", 0.0)
		game.hud.fps = base_fps
		var fname := "%02d_pattern_%s.png" % [id + 1, SLUGS[id]]
		await _capture(fname)
		print("pattern ", id + 1, " bullets=", game.field.pool.count)

func _capture_features() -> void:
	# 时间轴：第一阶环形段
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(10.4)
	game.hud.toast("", 0.0)
	game.hud.transition_left = 0.0
	game.hud.fps = base_fps
	await _capture("11_timeline_phase1.png")
	print("timeline phase1 bullets=", game.field.pool.count, " hp=", int(game.boss.hp))

	# 阶段切换横幅
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(11.6)
	game.hud.fps = base_fps
	await _capture("12_phase_transition.png")
	print("phase transition active=", game.transition_left)

	# 第三阶段
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(28.2)
	game.hud.toast("", 0.0)
	game.hud.transition_left = 0.0
	game.hud.fps = base_fps
	await _capture("13_timeline_phase3.png")
	print("timeline phase3 bullets=", game.field.pool.count, " hp=", int(game.boss.hp))

	# 擦弹：把一个环形弹放在玩家判定圈边缘
	game.reset_run()
	game.debug_set_immunity(true)
	game.set_inspect(3)
	game.debug_step(1.1)
	var b: Vector2 = game.debug_nearest_bullet(game.player.position)
	if b.x > -1000.0:
		var vv := Vector2(1, 0)
		for i in game.field.pool.count:
			if game.field.pool.pos[i] == b:
				vv = game.field.pool.vel[i]
				break
		var side := Vector2(-vv.y, vv.x).normalized()
		game.player.position = b + side * 14.0
		game.player.velocity = Vector2.ZERO
		game.player.autopilot = false
		game.player.invuln = 0.0
		game.debug_step(1.0 / 60.0)
	game.hud.toast("", 0.0)
	game.hud.fps = base_fps
	await _capture("14_graze.png")
	print("graze=", game.player.graze, " bullets=", game.field.pool.count)

	# 命中：直接让玩家与弹体重合，走真实碰撞/清弹/闪屏
	game.reset_run()
	game.debug_set_immunity(false)
	game.set_inspect(3)
	game.debug_force_hits(true)
	game.debug_step(1.0)
	var b2: Vector2 = game.debug_nearest_bullet(game.player.position)
	if b2.x > -1000.0:
		game.player.position = b2
		game.player.velocity = Vector2.ZERO
		game.player.autopilot = false
		game.player.invuln = 0.0
		game.debug_step(1.0 / 60.0)
	game.hud.fps = base_fps
	await _capture("15_hit.png")
	print("hit: lives=", game.player.lives, " bullets_after_clear=", game.field.pool.count)

	# 1200 弹压力场景
	await _stage_stress()
	await _capture("16_stress_1200.png")
	print("stress bullets=", game.field.pool.count, " high_water=", game.field.pool.high_water, " stress_fps=", game.hud.fps)

	# 暂停覆盖层
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(8.8)
	game.set_paused(true)
	game.hud.transition_left = 0.0
	game.hud.fps = base_fps
	await _capture("17_pause.png")
	print("paused=", game.paused)

	# 胜利覆盖层：跳到末阶段后走真实 HP 归零路径
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(2.2)
	game.timeline.phase_index = 2
	game.phase_index = 2
	game.boss.set_phase(2, 1900.0)
	game.boss.hp = 0.0
	game.debug_step(0.05)
	game.hud.transition_left = 0.0
	game.hud.toast("", 0.0)
	game.hud.fps = base_fps
	await _capture("18_victory.png")
	print("victory=", game.victory)

func _capture_stress_only() -> void:
	await _stage_stress()
	await _capture("16_stress_1200.png")
	print("stress-only bullets=", game.field.pool.count, " high_water=", game.field.pool.high_water, " stress_fps=", game.hud.fps)

func _stage_stress() -> void:
	game.reset_run()
	game.debug_set_immunity(true)
	game.set_inspect(0)
	game.debug_set_stress(true, 1200)
	game.set_process(true)
	await create_timer(3.0).timeout
	var stress_fps := Engine.get_frames_per_second()
	if stress_fps <= 0:
		stress_fps = 1
	game.set_process(false)
	game.debug_step(0.0)
	game.hud.toast("", 0.0)
	game.hud.fps = stress_fps

func _capture(fname: String) -> void:
	game.hud.queue_redraw()
	await process_frame
	await process_frame
	await process_frame
	var img := vp.get_texture().get_image()
	if img == null or img.is_empty():
		push_error("empty viewport image: " + fname)
		return
	var path := out_abs.path_join(fname)
	var err := img.save_png(path)
	if err != OK:
		push_error("save_png failed %s: %s" % [fname, error_string(err)])
	else:
		saved.append(fname)
		print("saved ", fname, " ", img.get_width(), "x", img.get_height())
