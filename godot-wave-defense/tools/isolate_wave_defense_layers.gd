extends SceneTree
## 性能诊断：同一进程内切换可见层，隔离 2D 绘制成本。
## 用法：godot --path godot-wave-defense --resolution 1280x720 --disable-vsync --max-fps 0 \
##       --script tools/isolate_wave_defense_layers.gd

const Data = preload("res://scripts/game_data.gd")

var main
var _viewport: SubViewport
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_run()


func _run() -> void:
	_rng.seed = 20261125
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	main = scene
	main.demo_use_save_path("user://wd_ab_save.json")
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

	var modes := [
		"baseline", "no_hud", "no_fx", "no_arena",
		"no_hud_fx", "no_hud_fx_enemies", "no_hud_fx_towers", "no_world",
	]
	var m := 0
	var frames := 0
	var secs := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	var spawn_acc := 0.0
	var types := ["militia", "runner", "shield", "elite"]

	while m < modes.size():
		await process_frame
		var now := Time.get_ticks_usec()
		var dt := float(now - last) / 1000000.0
		last = now
		frames += 1
		secs += dt
		spawn_acc += dt
		if spawn_acc >= 0.08 and main.enemies.size() < 16:
			spawn_acc = 0.0
			var type_id: String = types[_rng.randi_range(0, types.size() - 1)]
			main.demo_spawn_enemy(type_id, _rng.randf_range(220.0, 900.0), _rng.randf_range(-14.0, 14.0))
		main.state.castle_hp = Data.CASTLE_MAX_HP
		main.player.hp = main.player.max_hp
		main.player.alive = true
		main.player.invuln_t = 5.0
		_apply_mode(modes[m])
		if secs >= 1.5:
			print("AB %-20s fps=%5.1f calls=%d prims=%d" % [
				modes[m], float(frames) / secs,
				int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
				int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])
			m += 1
			frames = 0
			secs = 0.0
	main.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _apply_mode(name: String) -> void:
	var hud_on := true
	var fx_on := true
	var arena_on := true
	var enemies_on := true
	var towers_on := true
	match name:
		"no_hud":
			hud_on = false
		"no_fx":
			fx_on = false
		"no_arena":
			arena_on = false
		"no_hud_fx":
			hud_on = false
			fx_on = false
		"no_hud_fx_enemies":
			hud_on = false
			fx_on = false
			enemies_on = false
		"no_hud_fx_towers":
			hud_on = false
			fx_on = false
			towers_on = false
		"no_world":
			hud_on = false
			fx_on = false
			arena_on = false
			enemies_on = false
			towers_on = false
	main.hud.visible = hud_on
	main.fx.visible = fx_on
	main.arena.visible = arena_on
	for enemy in main.enemies:
		if is_instance_valid(enemy):
			enemy.visible = enemies_on
	for tower in main.towers_by_pad:
		if tower != null and is_instance_valid(tower):
			tower.visible = towers_on
	main.wall.visible = towers_on
	main.player.visible = enemies_on
