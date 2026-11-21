extends SceneTree

## 无渲染冒烟测试：穿墙 / NaN / 限速 / 到达 / 确定性 / CPU 步进耗时。
## 运行：godot --path godot-steering --headless -s tools/smoke_steering.gd
## 成功输出最后一行：STEERING_SMOKE_OK

const SIM_SCRIPT := preload("res://scripts/steering_sim.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t_start := Time.get_ticks_msec()
	_case_flow(100, 2400, true)
	_case_corridor(200, 1800)
	_case_chase(30, 1200)
	_case_flock(150, 900)
	_case_determinism()
	_case_pressure(200, 300)

	var elapsed := Time.get_ticks_msec() - t_start
	print("— 冒烟测试总耗时: %d ms" % elapsed)
	if _failures.is_empty():
		print("STEERING_SMOKE_OK")
		quit(0)
	else:
		print("STEERING_SMOKE_FAILED (%d)" % _failures.size())
		for f in _failures:
			print("  · " + f)
		quit(1)


func _make_sim(preset: String, count: int, seed_value := 20261121):
	var sim = SIM_SCRIPT.new()
	root.add_child(sim)
	sim.set_physics_process(false)
	sim.set_process(false)
	sim.seed_value = seed_value
	sim.target_count = count
	sim.apply_preset(preset)
	return sim


func _case_flow(count: int, steps: int, require_arrival: bool) -> void:
	var sim = _make_sim("video", count)
	var t0 := Time.get_ticks_msec()
	var breach := 0
	var breaches := 0
	var nan_before := 0
	var min_clearance := INF
	for s in steps:
		sim.step_frames(1)
		var r := _check_frame(sim)
		breaches += r["breaches"]
		if r["breaches"] > 0:
			breach += 1
		min_clearance = minf(min_clearance, r["min_clearance"])
		nan_before += r["nan"]
	var arrived := _arrived_ever(sim)
	var ratio := float(arrived) / float(count)
	var ms := Time.get_ticks_msec() - t0
	print("· 视频绕障 %d 体 / %d 步: 穿墙帧 %d, 穿墙次数 %d, 最小间隙 %.2f, NaN %d, 到达 %.0f%%, CPU %.0f 步/秒, 接触修正 %d"
		% [count, steps, breach, breaches, min_clearance, nan_before + int(sim.nan_events), ratio * 100.0,
			steps * 1000.0 / maxf(1.0, ms), sim.contacts_total])
	if breach > 0:
		_failures.append("视频绕障存在穿墙帧 %d 帧 / %d 次" % [breach, breaches])
	if nan_before > 0 or sim.nan_events > 0:
		_failures.append("视频绕障出现 NaN/Inf")
	if not _speed_ok(sim):
		_failures.append("视频绕障速度超限")
	if require_arrival and ratio < 0.85:
		_failures.append("视频绕障到达率不足: %.0f%%" % (ratio * 100.0))
	if sim.contacts_total > steps * 4:
		_failures.append("视频绕障接触修正异常高: %d" % sim.contacts_total)
	_drop(sim)


func _case_corridor(count: int, steps: int) -> void:
	var sim = _make_sim("corridor", count)
	var t0 := Time.get_ticks_msec()
	var breach := 0
	var breaches := 0
	var min_clearance := INF
	for s in steps:
		sim.step_frames(1)
		var r := _check_frame(sim)
		breaches += r["breaches"]
		if r["breaches"] > 0:
			breach += 1
		min_clearance = minf(min_clearance, r["min_clearance"])
	var arrived := _arrived_ever(sim)
	var ratio := float(arrived) / float(count)
	var ms := Time.get_ticks_msec() - t0
	print("· 走廊拥堵 %d 体 / %d 步: 穿墙帧 %d, 穿墙次数 %d, 最小间隙 %.2f, 到达 %.0f%%, CPU %.0f 步/秒, 接触修正 %d"
		% [count, steps, breach, breaches, min_clearance, ratio * 100.0,
			steps * 1000.0 / maxf(1.0, ms), sim.contacts_total])
	if breach > 0:
		_failures.append("走廊拥堵存在穿墙帧 %d 帧 / %d 次" % [breach, breaches])
	if not _speed_ok(sim):
		_failures.append("走廊拥堵速度超限")
	if ratio < 0.8:
		_failures.append("走廊拥堵到达率不足: %.0f%%" % (ratio * 100.0))
	_drop(sim)


func _case_chase(count: int, steps: int) -> void:
	var sim = _make_sim("chase", count)
	var t0 := Time.get_ticks_msec()
	var breach := 0
	var breaches := 0
	var prey_travel := 0.0
	var prey = _prey(sim)
	var last_prey_pos: Vector2 = prey.pos if prey != null else Vector2.ZERO
	for s in steps:
		sim.step_frames(1)
		var r := _check_frame(sim)
		breaches += r["breaches"]
		if r["breaches"] > 0:
			breach += 1
		prey = _prey(sim)
		if prey != null:
			prey_travel += prey.pos.distance_to(last_prey_pos)
			last_prey_pos = prey.pos
	var ms := Time.get_ticks_msec() - t0
	print("· 追逐 %d 体 / %d 步: 穿墙帧 %d, 穿墙次数 %d, 猎物移动 %.0f px, CPU %.0f 步/秒"
		% [count, steps, breach, breaches, prey_travel, steps * 1000.0 / maxf(1.0, ms)])
	if breach > 0:
		_failures.append("追逐存在穿墙帧 %d 帧 / %d 次" % [breach, breaches])
	if not _speed_ok(sim):
		_failures.append("追逐速度超限")
	if prey_travel < 300.0:
		_failures.append("追逐猎物几乎未移动: %.0f px" % prey_travel)
	_drop(sim)


func _case_flock(count: int, steps: int) -> void:
	var sim = _make_sim("flock", count)
	var t0 := Time.get_ticks_msec()
	var breach := 0
	var breaches := 0
	for s in steps:
		sim.step_frames(1)
		var r := _check_frame(sim)
		breaches += r["breaches"]
		if r["breaches"] > 0:
			breach += 1
	var avg_speed: float = sim.get_stats()["avg_speed"]
	var ms := Time.get_ticks_msec() - t0
	print("· 羊群 %d 体 / %d 步: 穿墙帧 %d, 穿墙次数 %d, 平均速度 %.1f, CPU %.0f 步/秒"
		% [count, steps, breach, breaches, avg_speed, steps * 1000.0 / maxf(1.0, ms)])
	if breach > 0:
		_failures.append("羊群存在穿墙帧 %d 帧 / %d 次" % [breach, breaches])
	if not _speed_ok(sim):
		_failures.append("羊群速度超限")
	if avg_speed < 20.0:
		_failures.append("羊群平均速度过低: %.1f" % avg_speed)
	_drop(sim)


func _case_determinism() -> void:
	var a = _make_sim("video", 80, 777123)
	var b = _make_sim("video", 80, 777123)
	var c = _make_sim("video", 80, 777124)
	a.step_frames(900)
	b.step_frames(900)
	c.step_frames(900)
	var ha: int = a.get_state_checksum()
	var hb: int = b.get_state_checksum()
	var hc: int = c.get_state_checksum()
	print("· 确定性: A=%d B=%d C=%d" % [ha, hb, hc])
	if ha != hb:
		_failures.append("相同种子结果不一致")
	if ha == hc:
		_failures.append("不同种子结果意外一致")
	_drop(a)
	_drop(b)
	_drop(c)


func _case_pressure(count: int, steps: int) -> void:
	var sim = _make_sim("video", count)
	var t0 := Time.get_ticks_usec()
	sim.step_frames(steps)
	var us := Time.get_ticks_usec() - t0
	print("· CPU 压力 %d 体 × %d 步: %.2f ms/步 (≈ %.0f 步/秒), 接触 %d"
		% [count, steps, us / 1000.0 / steps, steps * 1000000.0 / maxf(1.0, us), sim.contacts_total])
	if us / 1000.0 / steps > 30.0:
		_failures.append("200 体单步 CPU 耗时超过 30ms: %.2f ms" % (us / 1000.0 / steps))
	_drop(sim)


var _clearance_sample := 0


func _check_frame(sim) -> Dictionary:
	_clearance_sample += 1
	var breaches := 0
	var nan := 0
	var min_clearance := INF
	for a in sim.agents:
		if not a.pos.is_finite() or not a.vel.is_finite():
			nan += 1
			continue
		var clearance: float = a.radius - 0.6
		if sim.is_point_blocked(a.pos, clearance):
			breaches += 1
		if _clearance_sample % 30 == 0:
			var d: float = 0.0
			if not sim.is_point_blocked(a.pos, 0.0):
				d = _approx_clearance(sim, a.pos)
			min_clearance = minf(min_clearance, d)
	return {"breaches": breaches, "nan": nan, "min_clearance": min_clearance}


func _approx_clearance(sim, pos: Vector2) -> float:
	var best := INF
	for r in sim.obstacles_rects:
		var nearest := Vector2(
			clampf(pos.x, r.position.x, r.end.x),
			clampf(pos.y, r.position.y, r.end.y))
		best = minf(best, pos.distance_to(nearest))
	for c in sim.obstacles_circles:
		best = minf(best, pos.distance_to(c["position"]) - c["radius"])
	return best


func _prey(sim):
	for a in sim.agents:
		if a.role == "prey":
			return a
	return null


func _arrived_ever(sim) -> int:
	var n := 0
	for a in sim.agents:
		if a.arrived:
			n += 1
	return n


func _speed_ok(sim) -> bool:
	var max_allowed := 0.0
	for a in sim.agents:
		max_allowed = maxf(max_allowed, a.max_speed)
	return sim.max_speed_seen <= max_allowed + 0.5


func _drop(sim) -> void:
	root.remove_child(sim)
	sim.queue_free()
