extends SceneTree

## Real-GPU perf probe after the T-020 art pass.
## 720p window:  godot --path godot-legion-td --resolution 1280x720 -s tools/perf_legion_td.gd
## 1080p:        LEGION_PERF_1080=1 godot --path godot-legion-td -s tools/perf_legion_td.gd
## Peak scene:   LEGION_PERF_PEAK=1 (40 players + 20 enemies + 8 towers Lv3 + hero Q)
## Output JSON:  LEGION_PERF_OUT=docs/perf_run.json
## Last line: LEGION_TD_PERF_OK

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")
const SECONDS := 8.0

var game
var sv: SubViewport
var _draw_calls: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var use_1080 := OS.get_environment("LEGION_PERF_1080") == "1"
	var peak := OS.get_environment("LEGION_PERF_PEAK") == "1"
	var scale := float(OS.get_environment("LEGION_3D_SCALE")) if OS.get_environment("LEGION_3D_SCALE") != "" else 1.0
	if use_1080:
		sv = SubViewport.new()
		sv.size = Vector2i(1920, 1080)
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.scaling_3d_scale = scale
		root.add_child(sv)
	else:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	if use_1080:
		sv.add_child(game)
	else:
		root.add_child(game)
	for i in 5:
		await process_frame
	if use_1080:
		game.ui.scale = Vector2(1.5, 1.5)
	game.debug_lock_camera = true

	game.restart_run(20261127)
	game.debug_add_resources(99999, 9999)
	for i in 8:
		game.select_pad(i)
		game.build_tower_at_selected(D.TOWER_ORDER[i % 3])
		game.upgrade_selected_tower()
		game.upgrade_selected_tower()
	game.clear_selection()
	if peak:
		# 40 players + 20 enemies + 8 towers Lv3, plus a hero Q.
		var kinds := ["guard", "bolt", "adept"]
		for i in 40:
			var a := i * 2.39996
			var r := 5.0 + 9.0 * sqrt(float(i) / 40.0)
			game.debug_spawn_unit(kinds[i % 3], Vector3(cos(a) * r, 0, 8 + sin(a) * r))
		for i in 20:
			var lane := i % 3
			var p: Vector3 = game.world.lane_paths[lane][mini(4 + i % 6, game.world.lane_paths[lane].size() - 1)]
			game.debug_spawn_enemy("colossus" if i % 10 == 9 else ("spitter" if i % 3 == 0 else "crawler"),
				lane, p + Vector3((i % 3) * 1.2, 0, 0), 2.0, 0.3, 0.8)
		game.simulate(2.5)
		game.hero_skill()
		game.world.set_camera(Vector3(0, 0, 12), 52.0)
	else:
		game.debug_start_wave(4)
		game.simulate(4.0)
		game.hero_skill()
		game.world.set_camera(Vector3(0, 0, 18), 42.0)
	# Warm every T-020 VFX material once (avoids one-off shader-compile hitches in the tail).
	var warm: Array[Node] = []
	var wpos: Vector3 = game.world.get_cam_target() + Vector3(0, 1.0, 0)
	for fn in [func() -> Node: return Art.build_hero_skill_fx(2.0, Color("#F0B23C")),
			func() -> Node: return Art.build_projectile_visual("bolt"),
			func() -> Node: return Art.build_projectile_visual("fire"),
			func() -> Node: return Art.build_projectile_visual("acid"),
			func() -> Node: return Art.build_projectile_visual("mortar"),
			func() -> Node: return Art.build_impact_burst(Color("#FF8A3C"), 0.8),
			func() -> Node: return Art.build_shockwave(2.0, Color("#9FE8FF"))]:
		var node: Node = fn.call()
		game.add_child(node)
		node.global_position = wpos
		warm.append(node)
	# Warm Label3D damage numbers + death/scorch (first-use shader/font compiles).
	game.fx_damage_number(wpos + Vector3(0, 2, 0), 12, Color.WHITE)
	game.fx_death(wpos, Color("#FF8A3C"), false)
	for i in 12:
		await process_frame
	for n in warm:
		if is_instance_valid(n):
			n.queue_free()
	for f in game.fx:
		if is_instance_valid(f.node):
			f.node.queue_free()
	game.fx.clear()
	for i in 8:
		await process_frame

	var start := Time.get_ticks_usec()
	var frames := 0
	var frame_times: Array[float] = []
	var last := start
	_draw_calls.clear()
	while (Time.get_ticks_usec() - start) < int(SECONDS * 1_000_000.0):
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - last) / 1000.0)
		last = now
		frames += 1
		_draw_calls.append(int(RenderingServer.get_rendering_info(
			RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	var elapsed := (Time.get_ticks_usec() - start) / 1_000_000.0
	var avg := frames / elapsed
	frame_times.sort()
	var p95: float = frame_times[int(frame_times.size() * 0.95)] if not frame_times.is_empty() else 0.0
	var worst: float = frame_times[-1] if not frame_times.is_empty() else 0.0
	var p50: float = frame_times[int(frame_times.size() * 0.50)] if not frame_times.is_empty() else 0.0
	var dc_avg := 0
	var dc_max := 0
	if not _draw_calls.is_empty():
		for d in _draw_calls:
			dc_avg += d
			dc_max = maxi(dc_max, d)
		dc_avg = int(round(float(dc_avg) / _draw_calls.size()))
	var res := "1920x1080-subviewport" if use_1080 else "1280x720-window"
	print("PERF_RES=%s scale=%.2f peak=%s frames=%d seconds=%.2f avg_fps=%.1f p50_ms=%.2f p95_ms=%.2f worst_ms=%.2f" % [
		res, scale, str(peak), frames, elapsed, avg, p50, p95, worst])
	print("PERF_DRAW_CALLS avg=%d max=%d" % [dc_avg, dc_max])
	print("PERF_SCENE units=%d enemies=%d towers=%d" % [game.units.size(), game.enemies.size(), game.towers.size()])
	var out_path := OS.get_environment("LEGION_PERF_OUT")
	if out_path != "":
		if not out_path.begins_with("/"):
			out_path = ProjectSettings.globalize_path("res://" + out_path)
		var data := {
			"task": "T-20261127-020",
			"result": res,
			"peak_scene": peak,
			"render_scale": scale,
			"frames": frames,
			"seconds": snappedf(elapsed, 0.01),
			"avg_fps": snappedf(avg, 0.1),
			"p50_ms": snappedf(p50, 0.01),
			"p95_ms": snappedf(p95, 0.01),
			"worst_ms": snappedf(worst, 0.01),
			"draw_calls_avg": dc_avg,
			"draw_calls_max": dc_max,
			"units": game.units.size(),
			"enemies": game.enemies.size(),
			"towers": game.towers.size(),
			"engine": Engine.get_version_info().string,
			"gpu": RenderingServer.get_video_adapter_name(),
			"os": OS.get_name(),
			"timestamp": Time.get_datetime_string_from_system(),
		}
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(data, "  "))
			f.close()
	print("LEGION_TD_PERF_OK")
	game.queue_free()
	await process_frame
	if sv != null:
		sv.queue_free()
	quit(0)
