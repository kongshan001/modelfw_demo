extends SceneTree

# Headless acceptance suite:
#   godot --headless --path godot-slot-defense -s tools/smoke_slot.gd
# Covers seeded reels, paylines, summons/upgrades, economy, shop, waves, boss,
# win/lose and restart. Prints SLOT_SMOKE_OK on success, exits 1 on failure.

const SlotLogic := preload("res://src/reel_slot.gd")

var fails: Array[String] = []
var checks := 0
var game: Node


func _initialize() -> void:
	_test_reel_logic()
	_test_paylines()
	_test_shop_logic()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	_test_spin_flow()
	_test_resolution_flow()
	_test_units()
	_test_shop_flow()
	_test_waves()
	_test_boss_and_endings()
	_test_restart()
	_test_input()

	if fails.is_empty():
		print("SLOT_SMOKE_OK checks=%d" % checks)
		quit(0)
	else:
		for f in fails:
			printerr("SLOT FAIL: ", f)
		printerr("SLOT_SMOKE_FAILED checks=%d fails=%d" % [checks, fails.size()])
		quit(1)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


func _grid(rows: Array) -> Array:
	return rows


func _test_reel_logic() -> void:
	var a := SlotLogic.new(4242)
	var b := SlotLogic.new(4242)
	var c := SlotLogic.new(4243)
	var same := true
	var differs := false
	for i in 6:
		var ga: Array = a.spin()
		var gb: Array = b.spin()
		var gc: Array = c.spin()
		if ga != gb:
			same = false
		if ga != gc:
			differs = true
	_check(same, "same seed produced different reel grids")
	_check(differs, "different seeds produced identical 6-spin sequence")
	_check(a.total_weight() == 100, "default symbol weights should total 100")


func _test_paylines() -> void:
	var triple := _grid([
		["blade", "blade", "blade"],
		["bow", "shield", "orb"],
		["orb", "crown", "steed"],
	])
	var r1: Dictionary = SlotLogic.resolve_grid(triple)
	_check(int(r1.triple_count) == 1, "row triple not detected")
	_check(r1.triples[0].symbol == "blade", "row triple symbol wrong")
	_check(int(r1.payout) == 0, "triple should not pay pair coins")

	var pair := _grid([
		["blade", "blade", "bow"],
		["shield", "crown", "steed"],
		["orb", "steed", "shield"],
	])
	var r2: Dictionary = SlotLogic.resolve_grid(pair)
	_check(int(r2.pair_count) == 1, "2-of-kind line not detected")
	_check(int(r2.payout) == 1, "2-of-kind payout should be 1")
	_check(int(r2.triple_count) == 0, "pair grid falsely reported a triple")

	var wild := _grid([
		["crown", "bow", "bow"],
		["shield", "blade", "steed"],
		["orb", "steed", "shield"],
	])
	var r3: Dictionary = SlotLogic.resolve_grid(wild)
	_check(int(r3.triple_count) == 1, "crown wildcard triple not detected")
	_check(r3.triples[0].symbol == "bow", "crown wildcard resolved to wrong symbol")
	_check(bool(r3.triples[0].wild), "wildcard triple flag missing")

	var crowns := _grid([
		["blade", "bow", "shield"],
		["steed", "orb", "blade"],
		["crown", "crown", "crown"],
	])
	var r4: Dictionary = SlotLogic.resolve_grid(crowns)
	_check(int(r4.triple_count) == 1, "3-crown line not detected")
	_check(r4.triples[0].symbol == "crown", "3-crown line should resolve to crown/upgrade")

	var multi := _grid([
		["blade", "blade", "blade"],
		["blade", "bow", "steed"],
		["blade", "orb", "shield"],
	])
	var r5: Dictionary = SlotLogic.resolve_grid(multi)
	_check(int(r5.triple_count) == 2, "crossing paylines should both settle")
	_check(int(r5.pair_count) == 1, "anti-diagonal pair should also settle")
	_check(int(r5.payout) == 1, "multi-line pair payout wrong")


func _test_shop_logic() -> void:
	var slot := SlotLogic.new(88)
	var blade0 := int(slot.weights.blade)
	slot.add_weight("blade", 10)
	_check(int(slot.weights.blade) == blade0 + 10, "add_weight did not change odds")
	var steed0 := int(slot.weights.steed)
	var crown0 := int(slot.weights.crown)
	var moved := slot.recast_symbol("steed", "crown")
	_check(moved == steed0 and moved > 0, "recast_symbol moved wrong weight")
	_check(int(slot.weights.steed) == 0, "recast_symbol left source weight")
	_check(int(slot.weights.crown) == crown0 + steed0, "recast_symbol did not add to crown")


func _test_spin_flow() -> void:
	game.start_run(777)
	_check(game.state == "idle", "new run should be idle")
	_check(game.gold == 8 and game.hearts == 7, "new run resources wrong")
	var expected_slot := SlotLogic.new(777)
	var expected: Array = expected_slot.spin()
	var ok: bool = game.request_spin()
	_check(ok, "first spin refused")
	_check(game.gold == 6, "spin did not cost 2 gold")
	_check(game.spin_grid == expected, "game spin diverged from same-seed pure logic")
	game.debug_tick(1.2)
	_check(not game.spinning, "spin animation did not finish")
	_check(game.state == "wave" and game.wave == 1, "first spin did not start wave 1")
	_check(int(game.stats.spins) == 1, "spin stat not counted")
	game.gold = 0
	_check(not game.request_spin(), "spin should be refused without gold")
	game.toggle_speed()
	_check(game.speed == 2.0, "speed toggle did not reach x2")
	game.toggle_speed()
	_check(game.speed == 1.0, "speed toggle did not return to x1")


func _test_resolution_flow() -> void:
	game.start_run(1001)
	var pair_res: Dictionary = SlotLogic.resolve_grid(_grid([
		["blade", "blade", "bow"],
		["shield", "crown", "steed"],
		["orb", "steed", "shield"],
	]))
	var gold0: int = game.gold
	game.debug_apply_result(pair_res)
	_check(game.gold == gold0 + 1, "pair resolution did not pay coins")

	game.start_run(1002)
	var triple_res: Dictionary = SlotLogic.resolve_grid(_grid([
		["bow", "bow", "bow"],
		["blade", "shield", "steed"],
		["orb", "steed", "blade"],
	]))
	game.debug_apply_result(triple_res)
	_check(game.units.size() == 1, "triple did not summon a unit")
	_check(game.units[0].type == "bow", "triple summoned wrong unit")

	game.start_run(1003)
	var multi_res: Dictionary = SlotLogic.resolve_grid(_grid([
		["blade", "blade", "blade"],
		["blade", "bow", "steed"],
		["blade", "orb", "shield"],
	]))
	var gold1: int = game.gold
	game.debug_apply_result(multi_res)
	_check(game.units.size() == 2, "crossing triples should summon two units")
	_check(game.gold == gold1 + int(multi_res.payout), "multi-line payout not applied")

	game.start_run(1004)
	game.debug_summon("bow")
	var crown_res: Dictionary = SlotLogic.resolve_grid(_grid([
		["blade", "blade", "shield"],
		["steed", "orb", "blade"],
		["crown", "crown", "crown"],
	]))
	game.debug_apply_result(crown_res)
	_check(game.units.size() == 1 and int(game.units[0].level) == 2, "3 crowns did not upgrade the unit")


func _test_units() -> void:
	game.start_run(1101)
	for i in 5:
		game.debug_summon("blade")
	_check(game.units.size() == 5, "five units did not fill the lane")
	var dmg0: float = float(game.units[0].dmg)
	game.debug_summon("blade")
	_check(game.units.size() == 5, "summon on a full board added a unit")
	_check(int(game.units[0].level) == 2, "summon on a full board did not upgrade a blade")
	_check(float(game.units[0].dmg) > dmg0, "upgrade did not raise damage")
	_check(float(game.units[0].hp) <= float(game.units[0].max_hp), "upgrade overflowed hp")


func _test_shop_flow() -> void:
	game.start_run(2001)
	game.debug_open_shop()
	_check(game.state == "shop", "shop did not open")
	_check(game.shop_offers.size() == 3, "shop should offer 3 items")
	var unique := {}
	for id in game.shop_offers:
		unique[id] = true
	_check(unique.size() == 3, "shop offers are not distinct")
	var guard := 0
	while not game.shop_offers.has("ledger") and guard < 12:
		game.debug_add_gold(10)
		game.reroll_shop()
		guard += 1
	_check(game.shop_offers.has("ledger"), "reroll never surfaced the ledger")
	var idx: int = game.shop_offers.find("ledger")
	game.debug_add_gold(20)
	var gold_before: int = game.gold
	var bought: bool = game.debug_buy(idx)
	_check(bought, "ledger purchase failed")
	_check(game.gold == gold_before - 4, "ledger cost not deducted")
	_check(game.spin_cost == 1, "ledger did not reduce spin cost")
	_check(game.kill_bonus == 1, "ledger did not add kill gold")
	_check(bool(game.shop_sold[idx]), "bought offer not marked sold")
	_check(not game.debug_buy(idx), "sold offer could be bought twice")

	var blade0 := int(game.slot.weights.blade)
	game.debug_apply_item("blade_magnet")
	_check(int(game.slot.weights.blade) == blade0 + 10, "blade magnet effect wrong")

	var steed0 := int(game.slot.weights.steed)
	var crown0 := int(game.slot.weights.crown)
	game.debug_apply_item("crown_swap")
	_check(int(game.slot.weights.steed) == 0, "crown swap left steed weight")
	_check(int(game.slot.weights.crown) == crown0 + steed0, "crown swap did not transfer weight")

	game.debug_summon("blade")
	var dmg0: float = float(game.units[0].dmg)
	var hp0: float = float(game.units[0].max_hp)
	game.debug_apply_item("quench")
	_check(is_equal_approx(game.dmg_mult, 1.25), "quench did not raise damage multiplier")
	_check(is_equal_approx(game.hp_mult, 1.2), "quench did not raise hp multiplier")
	_check(float(game.units[0].dmg) > dmg0, "quench did not buff an existing unit")
	_check(float(game.units[0].max_hp) > hp0, "quench did not raise existing unit hp")

	game.continue_shop()
	_check(game.state == "wave" and game.wave == 1, "continue did not start the next wave")
	_check(game.spin_cost == 1, "ledger did not persist across the wave")
	_check(int(game.stats.spins) == 0, "shop flow should not consume spins")


func _test_waves() -> void:
	game.start_run(3001)
	game.debug_start_wave(1)
	_check(game.state == "wave" and game.wave == 1, "wave 1 did not start")
	_check(not game.spawn_queue.is_empty(), "wave 1 has no spawns queued")
	game.debug_clear_wave()
	game.debug_tick(1.4)
	_check(game.state == "shop", "cleared wave did not open the shop")
	game.continue_shop()
	_check(game.state == "wave" and game.wave == 2, "shop continue did not advance to wave 2")
	game.debug_clear_wave()
	game.debug_tick(1.4)
	_check(game.state == "shop", "wave 2 did not return to the shop")


func _test_boss_and_endings() -> void:
	game.start_run(3002)
	game.debug_start_wave(6)
	game.debug_spawn("boss")
	_check(game.state == "wave" and game.wave == 6, "boss wave did not start")
	_check(game.boss_alive, "boss did not spawn")
	_check(game.boss_max_hp > 0.0, "boss hp not tracked")
	game.debug_kill_all_enemies()
	_check(game.boss_killed, "boss kill flag missing")
	game.debug_tick(2.0)
	_check(game.state == "win", "boss clear did not reach victory")

	game.start_run(3003)
	game.debug_start_wave(1)
	game.debug_set_hearts(1)
	game.debug_spawn("grunt")
	_check(game.enemies.size() == 1, "test enemy did not spawn")
	game.enemies[0].x = 660.0
	game.debug_tick(1.2)
	_check(game.hearts == 0, "breaching enemy did not drain the last heart")
	_check(game.state == "lose", "zero hearts did not reach defeat")
	_check(not game.request_spin(), "defeat state should not accept spins")


func _test_restart() -> void:
	game.start_run(3004)
	_check(game.state == "idle", "restart should return to idle")
	_check(game.wave == 0, "restart left wave index behind")
	_check(game.gold == 8 and game.hearts == 7, "restart did not reset resources")
	_check(game.units.is_empty() and game.enemies.is_empty(), "restart left actors behind")
	_check(game.spin_cost == 2 and game.kill_bonus == 0, "restart left shop stats behind")
	_check(is_equal_approx(game.dmg_mult, 1.0) and is_equal_approx(game.hp_mult, 1.0), "restart left combat buffs behind")
	_check(not game.boss_alive and not game.spinning, "restart left transient state behind")
	_check(game.shop_offers.is_empty(), "restart left shop offers behind")
	_check(int(game.stats.spins) == 0, "restart left stats behind")


func _test_input() -> void:
	game.start_run(4001)
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	_check(game.spinning, "SPACE did not start a spin")
	game.debug_tick(1.2)
	_check(game.state == "wave", "SPACE spin did not begin the wave")
	var fkey := InputEventKey.new()
	fkey.keycode = KEY_F
	fkey.pressed = true
	game._unhandled_input(fkey)
	_check(game.speed == 2.0, "F did not toggle speed")
	game._unhandled_input(fkey)

	game.start_run(4002)
	game.debug_open_shop()
	game.debug_add_gold(20)
	var gold_before: int = game.gold
	var one := InputEventKey.new()
	one.keycode = KEY_1
	one.pressed = true
	game._unhandled_input(one)
	_check(bool(game.shop_sold[0]), "key 1 did not buy shop card 0")
	_check(game.gold < gold_before, "key 1 purchase did not spend gold")
	game._unhandled_input(space)
	_check(game.state == "wave" and game.wave == 1, "SPACE in shop did not start the next wave")

	game.gold = 1
	var rkey := InputEventKey.new()
	rkey.keycode = KEY_R
	rkey.pressed = true
	game._unhandled_input(rkey)
	_check(game.state == "idle" and game.gold == 8, "R did not restart the run")

	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(270, 592)
	game._unhandled_input(click)
	_check(game.spinning, "SPIN button click did not spin")
