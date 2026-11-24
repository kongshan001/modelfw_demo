extends SceneTree

# Headless 验收：10 pattern 生成数量/方向、子弹生命周期、命中/擦弹、
# 追踪/分裂、时间轴推进、暂停/重开、确定性、1200 弹容量。
# 运行：
#   godot --headless --path godot-bullet-hell -s tools/smoke_bullet_hell.gd
# 末行输出 BULLET_HELL_SMOKE_OK。

const PoolScript = preload("res://scripts/bullet_pool.gd")
const RunnerScript = preload("res://scripts/pattern_runner.gd")
const TimelineScript = preload("res://scripts/boss_timeline.gd")
const BOARD := Rect2(0.0, 0.0, 1280.0, 720.0)
const BOSS := Vector2(640.0, 140.0)
const PLAYER := Vector2(640.0, 600.0)
const DT := 1.0 / 60.0

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	print("=== BULLET HELL SMOKE ===")
	_test_meta()
	_test_patterns()
	_test_lifecycle()
	_test_collision_and_graze()
	_test_clear_radius_and_capacity()
	_test_timeline()
	_test_determinism()
	await _test_main_pause_restart()
	print("checks: %d, failures: %d" % [checks, failures.size()])
	if failures.is_empty():
		print("BULLET_HELL_SMOKE_OK")
		quit(0)
	else:
		for f in failures:
			print("FAIL: ", f)
		quit(1)

func _check(name: String, ok: bool, detail := "") -> void:
	checks += 1
	if ok:
		print("PASS  ", name, "" if detail == "" else "  [" + detail + "]")
	else:
		failures.append(name + ("" if detail == "" else " :: " + detail))
		print("FAIL  ", name, "" if detail == "" else "  [" + detail + "]")

func _near(a: float, b: float, eps := 0.01) -> bool:
	return absf(a - b) <= eps

func _test_meta() -> void:
	_check("10 patterns registered", RunnerScript.NAMES.size() == 10 and RunnerScript.CODES.size() == 10)
	var uniq := {}
	for n in RunnerScript.NAMES:
		uniq[n] = true
	_check("pattern names unique", uniq.size() == 10)
	_check("timeline has 3 phases", TimelineScript.PHASES.size() == 3)
	_check("timeline first phase starts P01", int(TimelineScript.PHASES[0]["events"][0]["pattern"]) == 0)

func _run_pattern_emission(id: int, steps: int) -> Array:
	var pool = PoolScript.new(4096, 0xB17B17)
	var runner = RunnerScript.new(id, 0x1234)
	for i in steps:
		runner.update(DT, pool, BOSS, PLAYER)
	return [pool, runner]

func _test_patterns() -> void:
	var one: Array = _run_pattern_emission(0, 2)
	var p = one[0]
	_check("P01 single emits 1", p.count == 1, "count=%d" % p.count)
	if p.count >= 1:
		_check("P01 aimed at player", _near(p.vel[0].angle(), Vector2.DOWN.angle(), 0.01), "angle=%.3f" % p.vel[0].angle())
		_check("P01 speed 300", _near(p.vel[0].length(), 300.0, 0.1))

	var fan3: Array = _run_pattern_emission(1, 1)
	p = fan3[0]
	_check("P02 fan3 emits 3", p.count == 3, "count=%d" % p.count)
	if p.count == 3:
		var target := (PLAYER - BOSS).angle()
		var degs: Array[float] = []
		var all_speed := true
		for i in 3:
			degs.append(rad_to_deg(wrapf(p.vel[i].angle() - target, -PI, PI)))
			all_speed = all_speed and _near(p.vel[i].length(), 260.0, 0.1)
		degs.sort()
		_check("P02 fan ±13°", _near(degs[0], -13.0, 0.2) and _near(degs[1], 0.0, 0.2) and _near(degs[2], 13.0, 0.2), str(degs))
		_check("P02 speed 260", all_speed)

	var fan5: Array = _run_pattern_emission(2, 1)
	p = fan5[0]
	_check("P03 fan5 emits 5", p.count == 5, "count=%d" % p.count)
	if p.count == 5:
		var target := (PLAYER - BOSS).angle()
		var degs: Array[float] = []
		for i in 5:
			degs.append(rad_to_deg(wrapf(p.vel[i].angle() - target, -PI, PI)))
		degs.sort()
		_check("P03 fan ±22°", _near(degs[0], -22.0, 0.2) and _near(degs[4], 22.0, 0.2) and _near(degs[2], 0.0, 0.2), str(degs))

	var ring: Array = _run_pattern_emission(3, 1)
	p = ring[0]
	_check("P04 ring emits 24", p.count == 24, "count=%d" % p.count)
	if p.count == 24:
		var angles := {}
		var speeds_ok := true
		for i in 24:
			angles[snappedf(p.vel[i].angle(), 0.001)] = true
			speeds_ok = speeds_ok and _near(p.vel[i].length(), 230.0, 0.1)
		_check("P04 24 distinct directions", angles.size() == 24, "unique=%d" % angles.size())
		_check("P04 speed 230", speeds_ok)

	var spiral: Array = _run_pattern_emission(4, 61)
	p = spiral[0]
	_check("P05 spiral ~19 waves ×2", p.count >= 30 and p.count <= 44, "count=%d" % p.count)
	if p.count > 2:
		var speed_ok := true
		var directions := {}
		for i in p.count:
			speed_ok = speed_ok and _near(p.vel[i].length(), 210.0, 0.1)
			directions[snappedf(p.vel[i].angle(), 0.02)] = true
		_check("P05 speed 210", speed_ok)
		_check("P05 angle advances", directions.size() >= 6, "unique_dirs=%d" % directions.size())

	var burst: Array = _run_pattern_emission(5, 19)
	p = burst[0]
	_check("P06 burst 3 pulses ×5", p.count == 15, "count=%d" % p.count)
	if p.count == 15:
		var speeds := {}
		for i in p.count:
			var key := int(round(p.vel[i].length()))
			speeds[key] = int(speeds.get(key, 0)) + 1
		_check("P06 speed layers 200..460", speeds.get(200, 0) == 3 and speeds.get(265, 0) == 3 and speeds.get(330, 0) == 3 and speeds.get(395, 0) == 3 and speeds.get(460, 0) == 3, str(speeds))

	var sine: Array = _run_pattern_emission(6, 71)
	p = sine[0]
	_check("P07 sine flower 48", p.count == 48, "count=%d" % p.count)
	if p.count == 48:
		var smin := INF
		var smax := -INF
		var all_behavior := true
		for i in p.count:
			var sp: float = p.vel[i].length()
			smin = minf(smin, sp)
			smax = maxf(smax, sp)
			all_behavior = all_behavior and p.behavior[i] == PoolScript.Behavior.SINE
		_check("P07 sine speed modulation", smin < 190.0 and smax > 310.0, "min=%.1f max=%.1f" % [smin, smax])
		_check("P07 all SINE behavior", all_behavior)

	var homing: Array = _run_pattern_emission(7, 2)
	p = homing[0]
	var runner_h = homing[1]
	_check("P08 homing emits 5", p.count == 5, "count=%d" % p.count)
	if p.count >= 1:
		_check("P08 HOMING behavior", p.behavior[0] == PoolScript.Behavior.HOMING)
		var new_player := Vector2(120.0, 600.0)
		for i in 60:
			p.step(DT, new_player, 0.0, 0.0, BOARD)
		_check("P08 steering toward new target", p.vel[0].x < -40.0, "vx=%.1f" % p.vel[0].x)

	var split: Array = _run_pattern_emission(8, 1)
	p = split[0]
	_check("P09 split emits 2 parents", p.count == 2, "count=%d" % p.count)
	for i in 72:
		p.step(DT, PLAYER, 0.0, 0.0, BOARD)
	_check("P09 timed split → 24 children", p.count == 24, "count=%d" % p.count)
	if p.count == 24:
		_check("P09 children flagged", (p.flags[0] & PoolScript.FLAG_CHILD) != 0 and _near(p.radius[0], 5.5, 0.01))

	var wall: Array = _run_pattern_emission(9, 1)
	p = wall[0]
	_check("P10 wall emits 18 of 21", p.count == 18, "count=%d" % p.count)
	if p.count == 18:
		var wall_ok := true
		for i in 18:
			wall_ok = wall_ok and _near(p.vel[i].length(), 158.0, 0.1) and p.vel[i].y > 0.0
		_check("P10 wall speed/direction", wall_ok)

func _test_lifecycle() -> void:
	var pool = PoolScript.new(64, 0xB17B17)
	pool.spawn(Vector2(640, 100), Vector2(0, -600), 5, Color.WHITE, 0, 0, 10.0)
	for i in 60:
		pool.step(DT, PLAYER, 0.0, 0.0, BOARD)
	_check("out-of-bounds bullet culled", pool.count == 0, "count=%d" % pool.count)
	pool.spawn(Vector2(640, 360), Vector2.ZERO, 5, Color.WHITE, 0, 0, 0.2)
	for i in 30:
		pool.step(DT, PLAYER, 0.0, 0.0, BOARD)
	_check("lifetime bullet culled", pool.count == 0, "count=%d" % pool.count)

func _test_collision_and_graze() -> void:
	var pool = PoolScript.new(64, 0xB17B17)
	pool.spawn(PLAYER, Vector2.ZERO, 5, Color.WHITE, 0, 0, 5.0)
	var r1 := pool.step(DT, PLAYER, 2.6, 20.0, BOARD)
	_check("circle collision hit", int(r1["hits"]) == 1, str(r1))
	var r2 := pool.step(DT, PLAYER, 2.6, 20.0, BOARD)
	_check("hit flag prevents recount", int(r2["hits"]) == 0, str(r2))
	pool.clear()
	pool.spawn(PLAYER + Vector2(12, 0), Vector2.ZERO, 5, Color.WHITE, 0, 0, 5.0)
	var r3 := pool.step(DT, PLAYER, 2.6, 20.0, BOARD)
	_check("graze without hit", int(r3["grazes"]) == 1 and int(r3["hits"]) == 0, str(r3))
	var r4 := pool.step(DT, PLAYER, 2.6, 20.0, BOARD)
	_check("graze counted once", int(r4["grazes"]) == 0, str(r4))

func _test_clear_radius_and_capacity() -> void:
	var pool = PoolScript.new(2048, 0xB17B17)
	for i in 3:
		pool.spawn(Vector2(640 + i * 10, 360), Vector2.ZERO, 5, Color.WHITE, 0, 0, 20.0)
	for i in 3:
		pool.spawn(Vector2(100 + i * 10, 100), Vector2.ZERO, 5, Color.WHITE, 0, 0, 20.0)
	var cleared := pool.clear_radius(Vector2(640, 360), 50.0)
	_check("clear_radius keeps far bullets", cleared == 3 and pool.count == 3, "cleared=%d count=%d" % [cleared, pool.count])
	pool.reset()
	for i in 1200:
		pool.spawn(Vector2(80 + (i * 37) % 1120, 120 + (i * 53) % 540), Vector2(20, 10), 5, Color.WHITE, 0, 0, 20.0)
	_check("1200 bullet capacity", pool.count == 1200 and pool.high_water == 1200, "count=%d high=%d" % [pool.count, pool.high_water])
	pool.step(DT, Vector2(-1000, -1000), 0.0, 0.0, BOARD)
	_check("1200 bullets step without loss", pool.count == 1200, "count=%d" % pool.count)
	pool.reset()
	for i in 1000:
		pool.spawn(Vector2(100 + i % 1000, 300), Vector2.ZERO, 4, Color.WHITE, 0, 0, 0.5)
	for i in 45:
		pool.step(DT, Vector2(-1000, -1000), 0.0, 0.0, BOARD)
	_check("1000 bullet lifetime cleanup", pool.count == 0, "count=%d" % pool.count)

func _test_timeline() -> void:
	var tl = TimelineScript.new()
	tl.reset()
	var seen := {}
	var t := 0.0
	while t < 9.9:
		var ev := tl.update(DT)
		seen[int(tl.current_pattern())] = true
		if bool(ev["pattern_changed"]):
			seen[int(ev["pattern"])] = true
		t += DT
	_check("phase 0 before 10s", tl.phase_index == 0, "phase=%d" % tl.phase_index)
	_check("phase 0 saw P01-P04", seen.has(0) and seen.has(1) and seen.has(2) and seen.has(3), str(seen.keys()))
	_check("beat grid 120 BPM", _near(tl.beat_float(), 19.8, 0.05), "beat=%.2f" % tl.beat_float())
	for i in 24:
		tl.update(DT)
	_check("phase advance at 10s", tl.phase_index == 1, "phase=%d" % tl.phase_index)
	seen.clear()
	t = 0.0
	while t < 11.4:
		var ev := tl.update(DT)
		seen[int(tl.current_pattern())] = true
		if bool(ev["pattern_changed"]):
			seen[int(ev["pattern"])] = true
		t += DT
	_check("phase 1 saw P05-P08", seen.has(4) and seen.has(5) and seen.has(6) and seen.has(7), str(seen.keys()))
	for i in 24:
		tl.update(DT)
	_check("phase advance at 22s", tl.phase_index == 2, "phase=%d" % tl.phase_index)
	seen.clear()
	t = 0.0
	while t < 15.4:
		var ev := tl.update(DT)
		seen[int(tl.current_pattern())] = true
		if bool(ev["pattern_changed"]):
			seen[int(ev["pattern"])] = true
		t += DT
	_check("phase 2 saw split/wall/reprises", seen.has(8) and seen.has(9) and seen.has(6) and seen.has(4), str(seen.keys()))
	var timeline_patterns := {}
	for ph in TimelineScript.PHASES:
		for e in ph["events"]:
			timeline_patterns[int(e["pattern"])] = true
	_check("timeline covers all 10 patterns", timeline_patterns.size() == 10, str(timeline_patterns.keys()))
	var finished := false
	for i in 48:
		var ev := tl.update(DT)
		finished = finished or bool(ev["finished"])
	_check("timeline finishes after 38s", finished and tl.finished, "finished=%s" % str(tl.finished))

func _signature() -> PackedFloat32Array:
	var pool = PoolScript.new(4096, 0xB17B17)
	var runner = RunnerScript.new(8, 0xABCDEF)
	for i in 130:
		runner.update(DT, pool, BOSS, PLAYER)
		pool.step(DT, PLAYER, 0.0, 0.0, BOARD)
	var out := PackedFloat32Array()
	for i in pool.count:
		out.append(snappedf(pool.pos[i].x, 0.0001))
		out.append(snappedf(pool.pos[i].y, 0.0001))
		out.append(snappedf(pool.vel[i].x, 0.0001))
		out.append(snappedf(pool.vel[i].y, 0.0001))
	return out

func _test_determinism() -> void:
	var a := _signature()
	var b := _signature()
	_check("fixed-seed split determinism", a.size() > 0 and a == b, "samples=%d" % a.size())

func _test_main_pause_restart() -> void:
	var packed = load("res://scenes/main.tscn")
	_check("main scene loads", packed != null)
	if packed == null:
		return
	var game = packed.instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	game.debug_step(2.6)
	var snap1: Dictionary = game.debug_snapshot()
	_check("timeline running produces bullets", int(snap1["bullets"]) > 0, str(snap1))
	var bullets_before := int(snap1["bullets"])
	var time_before: float = game.run_time
	game.set_paused(true)
	game.debug_step(1.0)
	var snap2: Dictionary = game.debug_snapshot()
	_check("pause freezes bullets", int(snap2["bullets"]) == bullets_before, "before=%d after=%d" % [bullets_before, int(snap2["bullets"])])
	_check("pause freezes simulation time", _near(game.run_time, time_before, 0.0001), "before=%.3f after=%.3f" % [time_before, game.run_time])
	game.set_paused(false)
	game.reset_run()
	var snap3: Dictionary = game.debug_snapshot()
	_check("restart clears bullets", int(snap3["bullets"]) == 0, str(snap3))
	_check("restart resets phase/lives/graze", int(snap3["phase"]) == 0 and int(snap3["lives"]) == 5 and int(snap3["graze"]) == 0 and not bool(snap3["paused"]), str(snap3))

	# 受击/游戏结束/胜利状态整合
	game.reset_run()
	game.set_inspect(3)
	game.debug_force_hits(true)
	game.debug_step(1.0)
	var b: Vector2 = game.debug_nearest_bullet(game.player.position)
	if b.x > -1000.0:
		game.player.position = b
		game.player.velocity = Vector2.ZERO
		game.player.autopilot = false
		game.player.invuln = 0.0
		var lives_before: int = game.player.lives
		game.debug_step(1.0 / 60.0)
		_check("hit integration decrements life", game.player.lives == lives_before - 1, "lives=%d" % game.player.lives)
		game.player.lives = 1
		game.player.alive = true
		game.player.invuln = 0.0
		var b2: Vector2 = game.debug_nearest_bullet(game.player.position)
		if b2.x > -1000.0:
			game.player.position = b2
			game.debug_step(1.0 / 60.0)
		_check("last life → game over", game.game_over, "lives=%d" % game.player.lives)
		game.reset_run()
		_check("restart after game over", not game.game_over and game.player.lives == 5 and int(game.field.pool.count) == 0)
	game.reset_run()
	game.debug_set_immunity(true)
	game.debug_step(2.2)
	game.timeline.phase_index = 2
	game.phase_index = 2
	game.boss.set_phase(2, 1900.0)
	game.boss.hp = 0.0
	game.debug_step(0.05)
	_check("boss hp zero → victory", game.victory, "phase=%d hp=%.0f" % [game.phase_index, game.boss.hp])
	game.reset_run()

	# 键位路由：1–0 观察、Q 返回、P 暂停、TAB 演示、R 重开
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_1
	game._unhandled_input(ev)
	_check("key 1 → inspect P01", game.inspect_id == 0, "inspect=%d" % game.inspect_id)
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_9
	game._unhandled_input(ev)
	_check("key 9 → inspect P09", game.inspect_id == 8, "inspect=%d" % game.inspect_id)
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_0
	game._unhandled_input(ev)
	_check("key 0 → inspect P10", game.inspect_id == 9, "inspect=%d" % game.inspect_id)
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_Q
	game._unhandled_input(ev)
	_check("key Q exits inspect", game.inspect_id == -1, "inspect=%d" % game.inspect_id)
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_P
	game._unhandled_input(ev)
	_check("key P pauses", game.paused)
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_P
	game._unhandled_input(ev)
	_check("key P resumes", not game.paused)
	var demo_before: bool = game.demo
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_TAB
	game._unhandled_input(ev)
	_check("key TAB toggles demo", game.demo != demo_before, "before=%s after=%s" % [str(demo_before), str(game.demo)])
	ev = InputEventKey.new(); ev.pressed = true; ev.keycode = KEY_R
	game._unhandled_input(ev)
	_check("key R restarts", game.inspect_id == -1 and int(game.field.pool.count) == 0 and game.phase_index == 0)
	game.queue_free()
	await process_frame
