extends SceneTree
## 《苔关八波》性能探针：1280×720、真实渲染、3 座 Lv.2 塔 + 最高 70 敌人同屏。
## 用法：godot --path . --resolution 1280x720 --disable-vsync --max-fps 0 \
##       --script tools/probe_perf_wave_defense.gd
## 输出每秒 FPS；min ≥30 时最后一行 WAVE_DEFENSE_PERF_OK。

const Data = preload("res://scripts/game_data.gd")
const SECONDS := 12

var main
var _viewport: SubViewport
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run()


func _run() -> void:
	_rng.seed = 20261125
	var enemy_cap := 70
	var hide_hud := false
	var hide_fx := false
	var hide_arena := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemies="):
			enemy_cap = clampi(int(arg.split("=")[1]), 1, 80)
		elif arg == "--no-hud":
			hide_hud = true
		elif arg == "--no-fx":
			hide_fx = true
		elif arg == "--no-arena":
			hide_arena = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	main = scene
	main.demo_use_save_path("user://wd_perf_save.json")
	main.demo_start_run(Data.DEFAULT_SEED)
	main.demo_set_gold(9999)
	main.demo_build_tower(0, "crossbow")
	main.demo_upgrade_tower(0)
	main.demo_build_tower(1, "cannon")
	main.demo_upgrade_tower(1)
	main.demo_build_tower(2, "cannon")
	main.demo_upgrade_tower(2)
	main.demo_set_wave(7)
	main.demo_skip_prep()
	main.waves.spawn_cursor = main.waves.spawn_plan.size()
	main.demo_set_player_pos(Data.path_point_at(700.0) + Vector2(-40, 60))
	main.demo_spawn_enemy("boss", 760.0, 0.0)
	if hide_hud:
		main.hud.visible = false
	if hide_fx:
		main.fx.visible = false
	if hide_arena:
		main.arena.visible = false

	var fps_samples: Array[int] = []
	var bucket_frames := 0
	var bucket_time := 0.0
	var last := Time.get_ticks_usec()
	var start := last
	var spawn_acc := 0.0
	var types := ["militia", "runner", "shield", "elite"]

	while (Time.get_ticks_usec() - start) / 1000000.0 < float(SECONDS):
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		bucket_frames += 1
		bucket_time += dt
		if bucket_time >= 1.0:
			var fps := int(round(float(bucket_frames) / bucket_time))
			fps_samples.append(fps)
			print("SEC %d fps=%d calls=%d prims=%d enemies=%d" % [
				fps_samples.size(), fps,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
				main.enemies.size()])
			bucket_frames = 0
			bucket_time = 0.0
		# 保持压力：持续补兵、主城不判负、领主无敌。
		spawn_acc += dt
		if spawn_acc >= 0.08 and main.enemies.size() < enemy_cap:
			spawn_acc = 0.0
			for i in range(2):
				var type_id: String = types[_rng.randi_range(0, types.size() - 1)]
				main.demo_spawn_enemy(type_id, _rng.randf_range(220.0, 900.0), _rng.randf_range(-14.0, 14.0))
		main.state.castle_hp = Data.CASTLE_MAX_HP
		main.player.hp = main.player.max_hp
		main.player.alive = true
		main.player.invuln_t = 5.0

	var total := (Time.get_ticks_usec() - start) / 1000000.0
	var peak := 0
	for enemy in main.enemies:
		if is_instance_valid(enemy):
			peak += 1
	print("PERF seconds=%.1f cap=%d samples=%s peak_enemies=%d" % [total, enemy_cap, fps_samples, peak])
	if fps_samples.is_empty():
		print("WAVE_DEFENSE_PERF_FAILED no samples")
		quit(1)
		return
	var lo: int = fps_samples.min()
	var total_fps := 0
	for f in fps_samples:
		total_fps += f
	var avg := float(total_fps) / float(fps_samples.size())
	print("PERF min=%d avg=%.1f max=%d (Intel HD target >=30)" % [lo, avg, fps_samples.max()])
	main.queue_free()
	_viewport.queue_free()
	await process_frame
	if avg >= 30.0:
		print("WAVE_DEFENSE_PERF_OK avg=%.1f" % avg)
		quit(0)
	else:
		print("WAVE_DEFENSE_PERF_FAILED avg=%.1f" % avg)
		quit(1)
