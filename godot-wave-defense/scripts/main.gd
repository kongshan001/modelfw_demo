extends Node2D
## 《苔关八波》主控：世界/单位/波次/HUD 接线；准备与战斗循环、建造经济、构筑、结算。
## 所有模拟走手动 tick（便于 headless 确定性验收），只有渲染与输入由引擎驱动。

const Data = preload("res://scripts/game_data.gd")
const Art = preload("res://scripts/art.gd")
const StateScript = preload("res://scripts/game_state.gd")
const WavesScript = preload("res://scripts/wave_manager.gd")
const ArenaScript = preload("res://scripts/arena_map.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const TowerScript = preload("res://scripts/tower.gd")
const WallScript = preload("res://scripts/wall.gd")
const FxScript = preload("res://scripts/fx.gd")
const HudScript = preload("res://scripts/hud.gd")

var state
var waves
var arena
var world: Node2D
var units: Node2D
var fx
var wall
var player
var ui_layer: CanvasLayer
var hud

var enemies: Array = []
var towers_by_pad: Array = [null, null, null]
var towers_ref: Array = towers_by_pad

var menu_mode := ""
var selected_pad := -1
var upgrade_open := false
var upgrade_data: Dictionary = {}
var upgrade_advance := false
var run_over := false
var manual_tick := false

var mouse_pos := Vector2(640, 360)
var hover_pad := -1
var shake := 0.0
var _run_seed := Data.DEFAULT_SEED
var _hud_accum := 0.0
var _shake_rng := RandomNumberGenerator.new()
var _pending_summons: Array = []
var _started := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shake_rng.seed = 20261122
	state = StateScript.new()
	state.load_save()
	_build_world()
	_build_hud()
	waves = WavesScript.new()
	start_new_run(Data.DEFAULT_SEED)
	_started = true


func _build_world() -> void:
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	arena = ArenaScript.new()
	arena.name = "Arena"
	world.add_child(arena)
	units = Node2D.new()
	units.name = "Units"
	units.y_sort_enabled = true
	world.add_child(units)
	wall = WallScript.new()
	wall.name = "Wall"
	units.add_child(wall)
	wall.setup(self)
	player = PlayerScript.new()
	player.name = "Player"
	units.add_child(player)
	player.setup(self, state)
	fx = FxScript.new()
	fx.name = "Fx"
	world.add_child(fx)


func _build_hud() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 20
	add_child(ui_layer)
	hud = HudScript.new()
	hud.name = "Hud"
	ui_layer.add_child(hud)
	hud.setup(self)


func _process(delta: float) -> void:
	if not _started:
		return
	_update_ui(delta)
	if manual_tick:
		return
	if _is_paused():
		return
	_tick(minf(delta, 0.05))


func _is_paused() -> bool:
	return run_over or upgrade_open or menu_mode != ""


func _update_ui(delta: float) -> void:
	if hud == null:
		return
	mouse_pos = get_global_mouse_position()
	hud.mouse_pos = mouse_pos
	hud.tick(delta)
	var new_hover := -1
	if not _is_paused() and not run_over:
		for i in range(Data.BUILD_PADS.size()):
			var pad: Dictionary = Data.BUILD_PADS[i]
			if mouse_pos.distance_to(Vector2(pad["pos"])) <= 46.0:
				new_hover = i
				break
	if new_hover != hover_pad:
		hover_pad = new_hover
		arena.set_hover_pad(new_hover)
	for i in range(towers_by_pad.size()):
		var tower = towers_by_pad[i]
		if tower != null and is_instance_valid(tower):
			var show := (menu_mode == "tower" and selected_pad == i) or (hover_pad == i and not _is_paused())
			tower.set_show_range(show)
	if _is_paused():
		shake = 0.0
		world.position = Vector2.ZERO
	_hud_accum += delta
	if _hud_accum >= 0.066:
		_hud_accum = 0.0
		hud.queue_redraw()


func _tick(delta: float) -> void:
	if _is_paused():
		return
	state.tick_time(delta)

	var input := _read_move_input()
	player.tick(delta, input, mouse_pos, enemies)

	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.tick(delta)
	_process_pending_summons()
	_cleanup_dead_enemies()
	if run_over:
		fx.tick(delta)
		return

	for i in range(towers_by_pad.size()):
		var tower = towers_by_pad[i]
		if tower != null and is_instance_valid(tower):
			tower.tick(delta, enemies)
	_cleanup_dead_enemies()
	_cleanup_dead_towers()
	if run_over:
		fx.tick(delta)
		return

	wall.tick(delta)
	var event: String = waves.tick(delta, enemies.size())
	if event == "started":
		hud.toast("第 %d 波来袭 · 守住卡口" % (waves.wave_index + 1), Art.RUST, 2.6)
	for spawn in waves.take_spawns():
		_spawn_enemy(String(spawn["type"]), float(spawn["offset"]))
	if event == "cleared":
		_on_wave_cleared()
	fx.tick(delta)
	_update_shake(delta)


func _update_shake(delta: float) -> void:
	if shake > 0.01:
		shake = maxf(0.0, shake - delta * 34.0)
		world.position = Vector2(
			_shake_rng.randf_range(-shake, shake),
			_shake_rng.randf_range(-shake, shake)
		)
	else:
		shake = 0.0
		world.position = Vector2.ZERO


func _read_move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v.y += 1.0
	return v.normalized() if v.length_squared() > 0.01 else Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if not _is_paused() and player.alive:
					player.cast_skill(enemies)
			KEY_N:
				if not _is_paused() and waves.phase == "prep":
					skip_prep()
			KEY_F:
				if not _is_paused():
					repair_wall()
			KEY_R:
				if run_over:
					start_new_run(_run_seed)
			KEY_ESCAPE:
				if menu_mode != "":
					close_menu()
			KEY_1, KEY_2, KEY_3:
				var index: int = event.keycode - KEY_1
				if upgrade_open:
					choose_upgrade(index)
				elif menu_mode == "build" and index < Data.TOWER_ORDER.size():
					try_build_tower(selected_pad, Data.TOWER_ORDER[index])
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_handle_click(get_global_mouse_position())


func _handle_click(pos: Vector2) -> void:
	if run_over:
		if hud.hit_test(pos)["kind"] == "restart":
			start_new_run(_run_seed)
		return
	if upgrade_open:
		var hit: Dictionary = hud.hit_test(pos)
		if String(hit["kind"]) == "upgrade":
			choose_upgrade(int(hit["index"]))
		return
	if menu_mode != "":
		var hit: Dictionary = hud.hit_test(pos)
		match String(hit["kind"]):
			"build":
				try_build_tower(selected_pad, String(hit["type"]))
			"upgrade_tower":
				try_upgrade_tower(selected_pad)
			"sell_tower":
				try_sell_tower(selected_pad)
			"cancel":
				close_menu()
		return
	var hit: Dictionary = hud.hit_test(pos)
	match String(hit["kind"]):
		"skip":
			skip_prep()
			return
		"repair":
			repair_wall()
			return
	for i in range(Data.BUILD_PADS.size()):
		var pad: Dictionary = Data.BUILD_PADS[i]
		if pos.distance_to(Vector2(pad["pos"])) <= 46.0:
			open_pad_menu(i)
			return
	if pos.distance_to(Data.WALL_POS) <= 58.0:
		repair_wall()


func open_pad_menu(index: int) -> void:
	if waves.phase != "prep" or run_over or upgrade_open:
		hud.toast("战斗期无法建造 · 先守住这一波", Art.AMBER)
		return
	selected_pad = index
	var tower = towers_by_pad[index]
	menu_mode = "tower" if tower != null and is_instance_valid(tower) else "build"
	hud.queue_redraw()


func close_menu() -> void:
	menu_mode = ""
	selected_pad = -1
	for i in range(towers_by_pad.size()):
		var tower = towers_by_pad[i]
		if tower != null and is_instance_valid(tower):
			tower.set_show_range(false)
	hud.queue_redraw()


func try_build_tower(pad_index: int, type_id: String) -> bool:
	if waves.phase != "prep" or run_over or upgrade_open:
		hud.toast("只有准备阶段可以建造", Art.AMBER)
		return false
	if pad_index < 0 or pad_index >= Data.BUILD_PADS.size() or not Data.TOWERS.has(type_id):
		return false
	if towers_by_pad[pad_index] != null:
		return false
	var cost := int(Data.TOWERS[type_id]["cost"])
	if not state.spend(cost):
		hud.toast("金币不足：需要 %d 金" % cost, Art.RED)
		return false
	var tower = TowerScript.new()
	tower.setup(type_id, state, self)
	tower.position = Vector2(Data.BUILD_PADS[pad_index]["pos"])
	tower.name = "Tower_" + String(Data.BUILD_PADS[pad_index]["id"])
	units.add_child(tower)
	towers_by_pad[pad_index] = tower
	close_menu()
	fx.ring(tower.position, 40.0, Art.TEAL, 0.4)
	fx.burst(tower.position + Vector2(0, 6), Art.STONE_LIGHT, 6, 45.0, 0.3)
	hud.toast("建成 %s · %s" % [String(Data.TOWERS[type_id]["name"]), String(Data.BUILD_PADS[pad_index]["name"])], Art.TEAL, 2.2)
	hud.queue_redraw()
	return true


func try_upgrade_tower(pad_index: int) -> bool:
	if waves.phase != "prep" or run_over or upgrade_open:
		hud.toast("只有准备阶段可以升级", Art.AMBER)
		return false
	var tower = towers_by_pad[pad_index]
	if tower == null or not is_instance_valid(tower) or tower.level >= 2:
		return false
	var cost: int = tower.upgrade_cost()
	if not state.spend(cost):
		hud.toast("金币不足：需要 %d 金" % cost, Art.RED)
		return false
	tower.upgrade()
	fx.ring(tower.position, 36.0, Art.GOLD, 0.38)
	hud.toast("%s 升至 Lv.2" % String(tower.def["name"]), Art.GOLD, 2.0)
	hud.queue_redraw()
	return true


func try_sell_tower(pad_index: int) -> bool:
	if waves.phase != "prep" or run_over or upgrade_open:
		hud.toast("只有准备阶段可以出售", Art.AMBER)
		return false
	var tower = towers_by_pad[pad_index]
	if tower == null or not is_instance_valid(tower):
		return false
	var refund: int = tower.sell_value()
	state.add_gold(refund)
	towers_by_pad[pad_index] = null
	fx.burst(tower.position, Art.STONE_LIGHT, 9, 55.0, 0.32)
	tower.queue_free()
	close_menu()
	hud.toast("出售防御塔 · 返还 %d 金" % refund, Art.GOLD, 2.0)
	hud.queue_redraw()
	return true


func repair_wall() -> bool:
	if waves.phase != "prep" or run_over or upgrade_open:
		hud.toast("战斗期无法修缮城墙", Art.AMBER)
		return false
	var cost: int = wall.repair_cost()
	if cost <= 0:
		hud.toast("城墙完好，无需修缮", Art.DIM)
		return false
	if not state.spend(cost):
		hud.toast("金币不足：需要 %d 金" % cost, Art.RED)
		return false
	wall.repair()
	fx.ring(Data.WALL_POS, 46.0, Art.GOLD, 0.42)
	hud.toast("城墙已修缮 · %d / %d" % [int(wall.hp), int(wall.max_hp)], Art.GOLD, 2.0)
	hud.queue_redraw()
	return true


func skip_prep() -> void:
	if waves.phase != "prep" or _is_paused():
		return
	waves.start_wave_now()
	hud.toast("提前开战 · 第 %d 波" % (waves.wave_index + 1), Art.RUST, 2.0)


func _on_wave_cleared() -> void:
	state.wave_cleared = waves.wave_cleared
	var reward: int = waves.wave_reward()
	state.add_gold(reward)
	var healed: int = state.heal_castle(Data.CASTLE_HEAL_PER_WAVE)
	arena.set_castle_ratio(float(state.castle_hp) / float(Data.CASTLE_MAX_HP))
	hud.toast("第 %d 波守住！ +%d 金 · 主城 +%d HP" % [waves.wave_cleared, reward, healed], Art.GOLD, 3.2)
	var milestone := Data.milestone_for_wave(waves.wave_cleared)
	if milestone >= 0:
		_open_upgrade(milestone, true)
	else:
		_advance_after_wave()


func _open_upgrade(index: int, advance: bool) -> void:
	upgrade_open = true
	upgrade_advance = advance
	upgrade_data = Data.UPGRADE_MILESTONES[index]
	menu_mode = ""
	selected_pad = -1
	hud.queue_redraw()


func choose_upgrade(index: int) -> bool:
	if not upgrade_open:
		return false
	var options: Array = upgrade_data.get("options", [])
	if index < 0 or index >= options.size():
		return false
	var id := String(options[index])
	if not state.apply_upgrade(id):
		return false
	var name := String(Data.UPGRADES[id]["name"])
	upgrade_open = false
	upgrade_data = {}
	arena.set_castle_ratio(float(state.castle_hp) / float(Data.CASTLE_MAX_HP))
	hud.toast("构筑完成 · " + name, Art.GOLD, 2.6)
	var should_advance := upgrade_advance
	upgrade_advance = false
	if should_advance:
		_advance_after_wave()
	hud.queue_redraw()
	return true


func _advance_after_wave() -> void:
	var won: bool = waves.advance_after_clear()
	if won:
		_finish(true)
		return
	hud.toast("第 %d 波准备 · %s" % [waves.wave_index + 1, waves.summary()], Art.TEAL, 3.4)
	hud.queue_redraw()


func _finish(win: bool) -> void:
	if run_over:
		return
	run_over = true
	upgrade_open = false
	upgrade_advance = false
	menu_mode = ""
	selected_pad = -1
	if win:
		state.wave_cleared = Data.WAVES.size()
	state.finish_run(win)
	hud.queue_redraw()


func damage_castle(amount: float) -> void:
	if run_over:
		return
	state.damage_castle(amount)
	arena.set_castle_ratio(float(state.castle_hp) / float(Data.CASTLE_MAX_HP))
	fx.damage_text(Data.CASTLE_POS + Vector2(0, -78), int(round(amount)), Art.RED, false)
	add_shake(2.4)
	if state.castle_hp <= 0:
		_finish(false)


func _spawn_enemy(type_id: String, offset: float, distance := 0.0):
	if enemies.size() >= Data.MAX_ENEMIES:
		return null
	if not Data.ENEMIES.has(type_id):
		return null
	var enemy = EnemyScript.new()
	enemy.configure(type_id, offset)
	enemy.bind(self, player, wall, towers_ref)
	units.add_child(enemy)
	enemy.set_path_distance(distance)
	enemies.append(enemy)
	if type_id == "boss":
		fx.ring(enemy.position, 64.0, Art.RUST, 0.6)
		hud.toast("裂关巨兽踏入苔关！", Art.RED, 3.0)
	return enemy


func _cleanup_dead_enemies() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy = enemies[i]
		if enemy == null or not is_instance_valid(enemy) or not bool(enemy.alive):
			if enemy != null and is_instance_valid(enemy):
				enemy.queue_free()
			enemies.remove_at(i)


func _cleanup_dead_towers() -> void:
	for i in range(towers_by_pad.size()):
		var tower = towers_by_pad[i]
		if tower != null and is_instance_valid(tower) and not bool(tower.alive):
			tower.queue_free()
			towers_by_pad[i] = null


func _process_pending_summons() -> void:
	if _pending_summons.is_empty():
		return
	var requests := _pending_summons
	_pending_summons = []
	for distance in requests:
		for i in range(4):
			_spawn_enemy("militia", -12.0 + float(i) * 8.0, maxf(0.0, float(distance) - 34.0 - float(i) * 14.0))
		fx.ring(Data.path_point_at(float(distance)), 70.0, Art.RUST, 0.5)


func on_enemy_damaged(enemy, amount: float, source: String) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var color := Art.CREAM
	match source:
		"bolt":
			color = Art.TEAL
		"cannon":
			color = Art.AMBER
		"lord":
			color = Art.CREAM
		"skill":
			color = Art.GOLD
	var big: bool = source == "cannon" or source == "skill" or enemy.type_id == "elite" or enemy.type_id == "boss"
	var pos: Vector2 = enemy.position + Vector2(0, -float(enemy.radius) * 2.0 - 10.0)
	fx.damage_text(pos, maxi(1, int(round(amount))), color, big)


func on_enemy_killed(enemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	var reward: int = state.kill_reward(int(enemy.gold))
	var pos: Vector2 = enemy.position
	fx.burst(pos, Art.RUST, 9, 95.0, 0.44)
	fx.gold_text(pos + Vector2(0, -18), reward)
	var target: Vector2 = player.position if player.alive else Data.CASTLE_POS
	fx.coin_fly(pos, target, reward)
	if enemy.type_id == "boss":
		hud.toast("裂关巨兽倒下了！", Art.GOLD, 4.0)
		add_shake(5.0)


func on_boss_summon(boss) -> void:
	_pending_summons.append(float(boss.path_distance))
	fx.ring(boss.position, 72.0, Art.RUST, 0.6)
	hud.toast("裂关巨兽怒吼：召唤四名民兵！", Art.RED, 2.8)
	add_shake(3.0)


func on_lord_attack(lord, target) -> void:
	var angle: float = (target.position - lord.position).angle()
	fx.slash(lord.position + Vector2(0, -14), angle, 34.0, Color("b9f0dc"))
	add_shake(0.35)


func on_lord_skill(lord, from_pos: Vector2, hit_count: int) -> void:
	fx.ring(lord.position + Vector2(0, -8), float(Data.PLAYER["skill_radius"]), Art.TEAL, 0.45, 2.5)
	fx.burst(lord.position, Art.TEAL, 12, 120.0, 0.42)
	fx.slash(lord.position + Vector2(0, -14), lord.facing.angle(), 52.0, Art.GOLD)
	add_shake(3.2)
	if hit_count > 0:
		hud.toast("回旋斩 · 命中 %d" % hit_count, Art.TEAL, 1.4)


func on_player_damaged(player_ref, amount: float) -> void:
	fx.damage_text(player_ref.position + Vector2(0, -46), maxi(1, int(round(amount))), Art.RED, false)
	add_shake(1.8)


func on_lord_died(player_ref) -> void:
	var penalty: int = mini(int(state.gold), Data.PLAYER_REVIVE_COST)
	if penalty > 0:
		state.add_gold(-penalty)
	fx.burst(player_ref.position, Art.TEAL_DARK, 12, 90.0, 0.5)
	hud.toast("守关人倒下 · %.0f 秒后复活（-%d 金）" % [Data.PLAYER_RESPAWN_TIME, penalty], Art.RED, 3.0)


func on_lord_revived(player_ref) -> void:
	fx.ring(player_ref.position, 38.0, Art.TEAL, 0.5)
	hud.toast("守关人重返苔关", Art.TEAL, 1.8)


func on_wall_damaged(amount: float, pos: Vector2) -> void:
	fx.damage_text(pos + Vector2(0, -46), maxi(1, int(round(amount))), Art.AMBER, false)
	add_shake(0.8)


func on_wall_destroyed() -> void:
	fx.explosion(Data.WALL_POS, 58.0, Art.RUST)
	hud.toast("城墙被攻破！敌军直扑主城", Art.RED, 3.2)
	add_shake(6.0)


func on_tower_damaged(tower, amount: float) -> void:
	fx.damage_text(tower.position + Vector2(0, -42), maxi(1, int(round(amount))), Art.RED, false)
	add_shake(0.8)


func on_tower_destroyed(tower) -> void:
	fx.explosion(tower.position, 48.0, Art.AMBER)
	hud.toast("%s 被摧毁 · 建造位已空出" % String(tower.def["name"]), Art.RED, 2.6)
	add_shake(3.5)


func add_shake(amount: float) -> void:
	shake = minf(8.0, maxf(shake, amount))


func get_active_boss():
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy) and bool(enemy.alive) and enemy.type_id == "boss":
			return enemy
	return null


func is_mouse_inside() -> bool:
	return Rect2(Vector2.ZERO, Data.ARENA_SIZE).has_point(mouse_pos)


func get_tower(pad_index: int):
	if pad_index < 0 or pad_index >= towers_by_pad.size():
		return null
	return towers_by_pad[pad_index]


# ——— 测试 / 截图演示钩子（不影响正常输入路径） ———

func demo_use_save_path(path: String) -> void:
	state.set_path(path)
	if not state.load_save():
		state.best_score = 0
		state.best_grade = ""
		state.best_wave = 0
		state.best_kills = 0
		state.runs = 0


func demo_start_run(seed := Data.DEFAULT_SEED) -> void:
	start_new_run(seed)


func demo_set_manual_tick(enabled: bool) -> void:
	manual_tick = enabled


func demo_tick(delta: float) -> void:
	_tick(delta)


func demo_set_gold(amount: int) -> void:
	state.gold = maxi(0, amount)
	hud.queue_redraw()


func demo_set_player_pos(pos: Vector2) -> void:
	player.position = pos
	player.queue_redraw()


func demo_set_player_hp(value: float) -> void:
	player.hp = clampf(value, 0.0, player.max_hp)
	player.queue_redraw()


func demo_spawn_enemy(type_id: String, distance := 0.0, offset := 0.0):
	return _spawn_enemy(type_id, offset, distance)


func demo_clear_enemies() -> void:
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()


func demo_build_tower(pad_index: int, type_id: String) -> bool:
	return try_build_tower(pad_index, type_id)


func demo_upgrade_tower(pad_index: int) -> bool:
	return try_upgrade_tower(pad_index)


func demo_sell_tower(pad_index: int) -> bool:
	return try_sell_tower(pad_index)


func demo_damage_wall(amount: float) -> void:
	wall.damage(amount)


func demo_repair_wall() -> bool:
	return repair_wall()


func demo_damage_castle(amount: float) -> void:
	damage_castle(amount)


func demo_set_castle_hp(value: int) -> void:
	state.castle_hp = clampi(value, 0, Data.CASTLE_MAX_HP)
	arena.set_castle_ratio(float(state.castle_hp) / float(Data.CASTLE_MAX_HP))
	hud.queue_redraw()


func demo_set_wave(index: int) -> void:
	demo_clear_enemies()
	waves.set_wave_for_demo(index, index)
	state.wave_cleared = index
	upgrade_open = false
	upgrade_advance = false
	menu_mode = ""
	selected_pad = -1
	run_over = false
	hud.toast("第 %d 波准备 · %s" % [index + 1, waves.summary()], Art.TEAL, 3.0)
	hud.queue_redraw()


func demo_skip_prep() -> void:
	if waves.phase == "prep":
		waves.start_wave_now()
		hud.queue_redraw()


func demo_open_build_menu(pad_index: int) -> void:
	selected_pad = pad_index
	var tower = towers_by_pad[pad_index]
	menu_mode = "tower" if tower != null and is_instance_valid(tower) else "build"
	hud.queue_redraw()


func demo_close_menu() -> void:
	close_menu()


func demo_open_upgrade(index: int, advance := false) -> void:
	_open_upgrade(clampi(index, 0, Data.UPGRADE_MILESTONES.size() - 1), advance)


func demo_choose_upgrade(index: int) -> bool:
	return choose_upgrade(index)


func demo_finish(win: bool, wave_override := -1) -> void:
	if wave_override >= 0:
		state.wave_cleared = clampi(wave_override, 0, Data.WAVES.size())
		waves.wave_cleared = state.wave_cleared
	_finish(win)


func demo_restart() -> void:
	start_new_run(_run_seed)


func demo_click(pos: Vector2) -> void:
	_handle_click(pos)


func demo_cast_skill() -> bool:
	return player.cast_skill(enemies)


func start_new_run(seed: int) -> void:
	_run_seed = seed
	_clear_dynamic_units()
	state.reset_run(seed)
	player.reset()
	wall.reset()
	waves.start_run(seed)
	menu_mode = ""
	selected_pad = -1
	upgrade_open = false
	upgrade_data = {}
	upgrade_advance = false
	run_over = false
	hover_pad = -1
	shake = 0.0
	world.position = Vector2.ZERO
	arena.set_hover_pad(-1)
	arena.set_castle_ratio(1.0)
	fx.clear()
	_pending_summons.clear()
	hud.toast("第 1 波准备 · 点击基座建塔，守住 8 波", Art.TEAL, 3.4)
	hud.queue_redraw()


func _clear_dynamic_units() -> void:
	for enemy in enemies:
		if enemy != null and is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	for i in range(towers_by_pad.size()):
		var tower = towers_by_pad[i]
		if tower != null and is_instance_valid(tower):
			tower.queue_free()
		towers_by_pad[i] = null
	_pending_summons.clear()
