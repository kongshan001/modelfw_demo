extends SceneTree

# 无头验收：走真实游戏方法，不伪造表现。
# Run: godot --headless --path godot-raft-fishing -s tools/smoke_raft.gd

var _fails: Array[String] = []
var _checks := 0
var _done := false


func _initialize() -> void:
	var watchdog := create_timer(120.0)
	watchdog.timeout.connect(func() -> void:
		if not _done:
			printerr("RAFT_SMOKE_TIMEOUT")
			quit(1))
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await create_timer(0.25).timeout

	var world: RaftWorld = scene.get_node("ViewportContainer/WorldViewport/World")
	var hud: RaftHud = scene.get_node("HUD")
	world.spawn_enabled = false
	await process_frame

	# ── 初始状态 ──
	_check(world.is_playing(), "initial state should be playing")
	_check(world.raft.size() == 4, "initial raft should be 4 tiles, got %d" % world.raft.size())
	_check(world.inventory["planks"] == 3, "initial planks should be 3")
	_check(world.inventory["water"] == 1, "initial water should be 1")
	_check(RaftWorld.WIN_TILES == 12, "win tiles should be 12")
	_check(RaftWorld.WIN_DAY == 4, "win day should be 4")
	_check(world.thirst > 0.0 and world.hunger > 0.0, "survival meters should start above 0")
	_check(hud.build_menu != null, "build menu should be constructed")
	_check(hud.labels.has("objective"), "HUD objective label should exist")
	_check(RaftWorld.COSTS["purifier"]["planks"] == 2 and RaftWorld.COSTS["purifier"]["wood"] == 2,
		"purifier cost should be 2 planks + 2 wood")

	# ── 音效资源在运行时合成 ──
	_check(world._sfx.size() >= 8, "procedural sound bank should be generated")
	for key in world._sfx:
		_check(world._sfx[key] is AudioStreamWAV and world._sfx[key].data.size() > 100,
			"sound %s should contain PCM data" % key)

	# ── 定期刷新漂浮物 ──
	world.clear_loot()
	world.spawn_enabled = true
	await create_timer(3.2).timeout
	_check(world.loot.size() >= 1, "spawner should refresh loot while playing")
	world.spawn_enabled = false
	world.clear_loot()

	# ── 自动锁定最近漂浮物 ──

	var far: FloatLoot = world.debug_spawn_loot("barrel", Vector3(9.0, 0.0, 0.0))
	var near: FloatLoot = world.debug_spawn_loot("crate", Vector3(4.5, 0.0, 0.0))
	world.begin_charge()
	await process_frame
	_check(world.hook_state == "charging", "hold should enter charging state")
	_check(world.locked_loot == near, "auto lock should pick nearest floating loot")
	# 移动目标后锁定应更新到仍然最近的那个
	near.global_position = Vector3(3.2, 0.0, 3.2)
	await process_frame
	_check(world.locked_loot == near, "lock should refresh while holding")

	# ── 松手抛钩 + 追踪移动目标 ──
	var planks_before: int = world.inventory["planks"]
	world.release_cast()
	await create_timer(0.08).timeout
	_check(world.hook_state == "flying", "release should launch the hook")
	near.global_position += Vector3(3.0, 0.0, -2.5)
	var caught := false
	for i in 240:
		await process_frame
		if not world.last_catch.is_empty():
			caught = true
			break
	_check(caught, "hook should track and catch the moved target")
	_check(world.hook_state == "returning", "after a catch the hook should reel back")
	_check(world.last_catch.get("kind", "") == "crate", "caught loot should be the crate")
	_check(not is_instance_valid(near), "caught loot should be freed")
	_check(world.inventory["planks"] >= planks_before + 1, "crate should add at least 1 plank")
	_check(int(world.last_catch.get("wood", 0)) >= 2 and int(world.last_catch.get("wood", 0)) <= 4,
		"crate wood roll should be 2..4")
	await _wait_until_idle(world)

	# ── 范围 / 冷却 ──
	world.clear_loot()
	world.spawn_enabled = false
	var too_far: FloatLoot = world.debug_spawn_loot("fish", Vector3(26.0, 0.0, 0.0))
	world.begin_charge()
	await process_frame
	_check(world.locked_loot == null, "loot beyond 20m should not lock")
	world.release_cast()
	_check(world.hook_state == "idle", "release with no target should not fly")
	_check(too_far.alive, "uncatchable loot should remain")
	await create_timer(0.45).timeout
	world.begin_charge()
	await process_frame
	_check(world.hook_state == "charging", "hook can recharge after cooldown")
	world.release_cast()
	await _wait_until_idle(world)

	# ── 资源表：桶/箱木材平均 ×3 ──
	var barrels := 0
	var crates := 0
	var crate_planks := 0
	for i in 300:
		var b := world.roll_loot("barrel")
		var c := world.roll_loot("crate")
		barrels += int(b["wood"])
		crates += int(c["wood"])
		crate_planks += int(c["planks"])
		_check(int(b["wood"]) >= 2 and int(b["wood"]) <= 4, "barrel wood must be 2..4")
		_check(int(c["planks"]) >= 1 and int(c["planks"]) <= 2, "crate planks must be 1..2")
	var avg_b := float(barrels) / 300.0
	var avg_c := float(crates) / 300.0
	_check(absf(avg_b - 3.0) < 0.20, "barrel average wood should be ~3, got %.2f" % avg_b)
	_check(absf(avg_c - 3.0) < 0.20, "crate average wood should be ~3, got %.2f" % avg_c)
	_check(float(crate_planks) / 300.0 > 1.2, "crate should average >1.2 planks")
	print("LOOT_AVG barrel_wood=%.2f crate_wood=%.2f crate_planks=%.2f" % [
		avg_b, avg_c, float(crate_planks) / 300.0])
	world.clear_loot()

	# ── 建造扣料 + 放置校验 ──
	world.inventory["wood"] = 40
	world.inventory["planks"] = 40
	var p0: int = world.inventory["planks"]
	_check(world.build("expand", Vector2i(2, 0)), "expand should build next to raft")
	_check(world.raft.size() == 5, "raft should have 5 tiles after expand")
	_check(world.inventory["planks"] == p0 - 2, "expand should cost 2 planks")
	_check(not world.build("expand", Vector2i(6, 6)), "floating tile far from raft should be rejected")
	_check(world.build("expand", Vector2i(2, 1)), "second expand should build")
	_check(world.build("expand", Vector2i(2, 2)), "third expand should build")
	_check(world.can_place("crate", Vector2i(2, 0)), "crate should fit empty deck")
	var p1: int = world.inventory["planks"]
	_check(world.build("crate", Vector2i(2, 0)), "crate should be buildable")
	_check(world.inventory["planks"] == p1 - 3, "crate should cost 3 planks")
	_check(world.stations.has(Vector2i(2, 0)), "crate station should be registered")
	var crate: RaftStation = world.stations[Vector2i(2, 0)]
	_check(crate.kind == "crate", "crate station kind")
	_check(not world.can_place("purifier", Vector2i(2, 0)), "occupied deck cell should be rejected")

	# ── 箱子自动存取 / 自动取料 ──
	world.inventory["wood"] = 30
	world.inventory["planks"] = 20
	world.auto_store(true)
	_check(int(crate.stored["wood"]) == 8, "auto store should move 8 excess wood, got %s" % crate.stored["wood"])
	_check(int(crate.stored["planks"]) == 8, "auto store should move 8 excess planks, got %s" % crate.stored["planks"])
	_check(world.inventory["wood"] == 22 and world.inventory["planks"] == 12, "auto store should leave thresholds")
	world.inventory["wood"] = 0
	var stored_wood_before: int = int(crate.stored["wood"])
	var p2: int = world.inventory["planks"]
	_check(world.build("purifier", Vector2i(2, 1)), "purifier should be buildable")
	_check(int(crate.stored["wood"]) == stored_wood_before - 2,
		"build should auto-withdraw wood from crate when inventory is empty")
	_check(world.inventory["planks"] == p2 - 2, "purifier should cost 2 planks")
	_check(world.build("grill", Vector2i(2, 2)), "grill should be buildable")
	var purifier: RaftStation = world.stations[Vector2i(2, 1)]
	var grill: RaftStation = world.stations[Vector2i(2, 2)]

	# 材料不足
	world.inventory["wood"] = 0
	world.inventory["planks"] = 0
	crate.stored["wood"] = 0
	crate.stored["planks"] = 0
	var tiles_before_bad: int = world.raft.size()
	_check(not world.build("expand", Vector2i(0, 2)), "build without materials must fail")
	_check(world.raft.size() == tiles_before_bad, "failed build must not add a tile")

	# ── 放置模式（真的走后 begin_place → ghost → try_place） ──
	world.inventory["planks"] = 2
	world.inventory["wood"] = 0
	world.begin_place("expand")
	world.update_ghost(Vector2i(0, -1))
	_check(world.placement_mode, "build menu entry should enter placement mode")
	_check(world.ghost.visible, "placement ghost should be visible")
	_check(world.can_place("expand", Vector2i(0, -1)), "ghost cell should be a valid expansion")
	var t_before: int = world.raft.size()
	_check(world.try_place(Vector2i(0, -1)), "try_place should build the previewed tile")
	_check(world.raft.size() == t_before + 1, "placement should add exactly one tile")
	_check(not world.placement_mode, "placement should exit when planks run out")

	# ── 净水器：木→水，35% 省木；烤鱼架：鱼→烤鱼 ──
	_check(RaftStation.FREE_WOOD_CHANCE == 0.35, "purifier free-wood chance should be 35%")
	world.inventory["wood"] = 200
	world.inventory["fish"] = 10
	world.inventory["water"] = 1
	world.inventory["cooked"] = 0
	purifier.timer = 0.0
	world.debug_tick_stations(18.2)
	_check(purifier.ready_water == 1, "purifier should make 1 water per 18s batch")
	world.player.global_position = world.cell_center(Vector2i(1, 1))
	world.debug_collect_stations()
	_check(world.inventory["water"] >= 2, "purifier output should auto-collect when close")
	world.inventory["fish"] = 10
	grill.timer = 0.0
	world.debug_tick_stations(12.2)
	_check(grill.ready_cooked == 1, "grill should cook 1 fish per 12s batch")
	world.debug_collect_stations()
	_check(world.inventory["cooked"] >= 1, "grill output should auto-collect when close")

	# 省木统计：连续 batch，免费木材次数应 >0 且实际耗木少于产量
	purifier.timer = 0.0
	purifier.ready_water = 0
	purifier.produced = 0
	purifier.free_batches = 0
	world.inventory["wood"] = 200
	for i in 24:
		world.debug_tick_stations(18.05)
		purifier.take_output()
	var consumed := 200 - int(world.inventory["wood"])
	_check(purifier.produced >= 20, "purifier should produce repeatedly, got %d" % purifier.produced)
	_check(purifier.free_batches > 0, "35%% free-wood batches should occur")
	_check(consumed < purifier.produced, "35%% saving should consume less wood than water produced")
	print("PURIFY produced=%d free_batches=%d wood_consumed=%d" % [
		purifier.produced, purifier.free_batches, consumed])

	# ── 水 / 食物 / 体力 ──
	world.thirst = 10.0
	world.inventory["water"] = 2
	_check(world.drink_water(), "drink should work with water in bag")
	_check(world.thirst > 45.0 and world.inventory["water"] == 1, "drink should restore thirst and consume water")
	world.hunger = 10.0
	world.inventory["cooked"] = 1
	_check(world.eat_cooked(), "cooked fish should be edible")
	_check(world.hunger > 50.0 and world.inventory["cooked"] == 0, "cooked fish should restore food")
	world.hunger = 10.0
	world.inventory["fish"] = 1
	_check(world.eat_raw(), "raw fish should be edible")
	_check(world.hunger > 25.0, "raw fish should restore some food")
	var st0: float = world.stamina
	world.update_stamina(0.5, true)
	_check(world.stamina < st0, "sprinting should drain stamina")
	world.update_stamina(1.0, false)
	_check(world.stamina > 0.0, "stamina should regenerate when not sprinting")

	# ── 失败与重开 ──
	world.thirst = 0.5
	world.debug_tick_survival(4.0)
	_check(world.state == RaftWorld.STATE_LOST, "empty thirst should lose")
	_check(world.end_reason.contains("渴"), "lose reason should mention thirst")
	await process_frame
	await process_frame
	_check(hud.end_overlay.visible, "end overlay should show after losing")
	_check(hud.end_title.text.contains("漂"), "lose title should be shown")
	scene.restart_game()
	await create_timer(0.5).timeout
	var scene2 := current_scene
	_check(scene2 != null and scene2 != scene, "restart should reload a fresh scene")
	if scene2 != null:
		var world2: RaftWorld = scene2.get_node("ViewportContainer/WorldViewport/World")
		_check(world2.is_playing(), "restarted game should be playing")
		_check(world2.raft.size() == 4, "restarted raft should be 4 tiles")
		_check(world2.thirst > 50.0, "restarted survival meter should reset")

		# ── 扩建目标胜利 + 结算 UI ──
		world2.spawn_enabled = false
		world2.inventory["planks"] = 100
		world2.inventory["wood"] = 100
		var wins_cells := [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(1, 2),
			Vector2i(0, 2), Vector2i(-1, 2), Vector2i(-1, 1), Vector2i(-1, 0)]
		for cell in wins_cells:
			world2.build("expand", cell)
		_check(world2.raft.size() == 12, "raft should reach 12 tiles, got %d" % world2.raft.size())
		_check(world2.state == RaftWorld.STATE_WON, "reaching 12 tiles should win")
		await process_frame
		await process_frame
		var hud2: RaftHud = scene2.get_node("HUD")
		_check(hud2.end_overlay.visible, "win overlay should show")
		_check(hud2.end_title.text.contains("岸"), "win title should mention shore")
		_check(world2.get_prompt() == "", "prompt hides after game over")
		print("WIN tiles=%d day=%d" % [world2.raft.size(), world2.day])

		# ── 生存到第 4 天同样胜利 ──
		scene2.restart_game()
		await create_timer(0.5).timeout
		var scene3 := current_scene
		_check(scene3 != null and scene3 != scene2, "second restart should reload")
		if scene3 != null:
			var world3: RaftWorld = scene3.get_node("ViewportContainer/WorldViewport/World")
			world3.spawn_enabled = false
			world3.day = 3
			world3.day_time = RaftWorld.DAY_LENGTH - 0.08
			await create_timer(0.4).timeout
			_check(world3.state == RaftWorld.STATE_WON, "surviving into day 4 should win")
			_check(world3.end_reason.contains("夜晚"), "day win reason should mention the nights")
			print("WIN_DAY day=%d" % world3.day)

	_done = true
	if _fails.is_empty():
		print("RAFT_SMOKE_OK checks=%d" % _checks)
	else:
		for f in _fails:
			printerr("RAFT_SMOKE_FAIL: ", f)
	if current_scene != null:
		current_scene.queue_free()
		await process_frame
	quit(0 if _fails.is_empty() else 1)


func _wait_until_idle(world: RaftWorld, max_frames := 180) -> void:
	for i in max_frames:
		if world.hook_state == "idle" and world.cooldown <= 0.0:
			return
		await process_frame


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)
