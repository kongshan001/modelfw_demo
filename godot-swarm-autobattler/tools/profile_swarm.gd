extends SceneTree

const Battle = preload("res://scripts/swarm_battle.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ally := [
		{"id": "spark_flea", "star": 2}, {"id": "rivet_grub", "star": 1},
		{"id": "prism_gadfly", "star": 1}, {"id": "arc_ant", "star": 1},
		{"id": "molten_weaver", "star": 1}, {"id": "crown_colossus", "star": 1},
		{"id": "tideheart_engine", "star": 1},
	]
	var enemy := [
		{"id": "magwire_mantis", "star": 1}, {"id": "spore_ballista", "star": 1},
		{"id": "arc_ant", "star": 1}, {"id": "weave_moth", "star": 1},
		{"id": "crown_colossus", "star": 1}, {"id": "prism_gadfly", "star": 2},
		{"id": "spark_flea", "star": 1},
	]
	for cfg in [
		{"name": "3000 fx=off", "cap": 1500, "fx": false, "separation": true, "targeting": true},
		{"name": "3000 fx=on", "cap": 1500, "fx": true, "separation": true, "targeting": true},
		{"name": "3000 sep=off", "cap": 1500, "fx": false, "separation": false, "targeting": true},
		{"name": "3000 target=off", "cap": 1500, "fx": false, "separation": true, "targeting": false},
		{"name": "1000 fx=on", "cap": 500, "fx": true, "separation": true, "targeting": true},
		{"name": "100 fx=on", "cap": 50, "fx": true, "separation": true, "targeting": true},
	]:
		var b = Battle.new()
		b.setup(ally, enemy, {
			"seed": 20261126, "flood": true, "cap": int(cfg["cap"]),
			"ally_scale": 1000.0, "enemy_scale": 1000.0,
			"fx": cfg["fx"], "separation": cfg["separation"], "targeting": cfg["targeting"],
			"profile": true,
		})
		var total_start: int = int(b.side_count[0]) + int(b.side_count[1])
		var total_us := 0
		var worst := 0
		var ticks := 0
		var split_us := 0
		var t_split := Time.get_ticks_usec()
		for i in 120:
			if b.finished:
				break
			var t0 := Time.get_ticks_usec()
			b.step(Battle.SIM_DT)
			var dt := Time.get_ticks_usec() - t0
			total_us += dt
			worst = maxi(worst, dt)
			ticks += 1
			if ticks == 30:
				split_us = Time.get_ticks_usec() - t_split
		print("PROFILE %-16s start=%d ticks=%d total_ms=%.1f avg_ms=%.2f worst_ms=%.2f first30_avg=%.2f q=%d visits=%d moves=%d attacks=%d splash=%d left=%d" % [
			String(cfg["name"]), total_start, ticks, total_us / 1000.0, total_us / 1000.0 / maxf(1.0, ticks),
			worst / 1000.0, split_us / 1000.0 / 30.0,
			b.stat_queries, b.stat_visits, b.stat_moves, b.stat_attacks, b.stat_splashes,
			b.side_count[0] + b.side_count[1]])
		if ticks > 0:
			print("  per20ms=", _snapshots(b))
	quit(0)

func _snapshots(b) -> String:
	# 再跑一个短窗口，给出每 20 tick 的平均耗时（仅用于定位热点）。
	var a := []
	for i in 5:
		var t0 := Time.get_ticks_usec()
		for k in 20:
			if b.finished:
				break
			b.step(Battle.SIM_DT)
		a.append("%.1f" % (float(Time.get_ticks_usec() - t0) / 1000.0 / 20.0))
	return ",".join(a)
