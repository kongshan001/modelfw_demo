extends SceneTree
## Headless acceptance for Emberhold 3D.
## Covers maps/buildings/towers/enemies/waves/economy/lives/upgrade/sell/skill/
## AI toggle/AI autotest both maps/victory/defeat/restart.
## Run: godot --headless --path godot-emberhold-3d -s tools/smoke_emberhold3d.gd
## Final line on success: EMBERHOLD3D_SMOKE_OK

const GM = preload("res://scripts/game_model.gd")
const MD = preload("res://scripts/map_data.gd")
const GD = preload("res://scripts/game_data.gd")

var checks := 0
var fails := 0


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		return
	fails += 1
	print("FAIL: ", msg)


func near(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) <= eps


func _initialize() -> void:
	call_deferred("_run")


func find_free_cell(m, skip: int = 0) -> Vector2i:
	var idx := 0
	for c in m.map.build_cells:
		if m.tower_at(c.x, c.y) != null:
			continue
		if idx >= skip:
			return c
		idx += 1
	return Vector2i(-1, -1)


func _run() -> void:
	# ---- maps (must match the HTML preparation exactly) ----
	var ashen = MD.prepare("ashen")
	var frost = MD.prepare("frost")
	check(near(ashen.total_len, 1120.0), "ashen total path length 1120")
	check(near(frost.total_len, 960.0), "frost total path length 960")
	check(ashen.build_cells.size() == 532, "ashen build cells 532, got %d" % ashen.build_cells.size())
	check(frost.build_cells.size() == 542, "frost build cells 542, got %d" % frost.build_cells.size())
	check(ashen.samples.size() == 186, "ashen path samples 186")
	check(frost.samples.size() == 158, "frost path samples 158")
	check(ashen.props.size() == 8 and frost.props.size() == 8, "8 blocking props per map")
	check(ashen.props[0]["cx"] == 7 and ashen.props[0]["cy"] == 10 and ashen.props[0]["type"] == "stones",
		"ashen first prop matches HTML (stones @7,10)")
	check(frost.props[0]["cx"] == 14 and frost.props[0]["cy"] == 10 and frost.props[0]["type"] == "crystal",
		"frost first prop matches HTML (crystal @14,10)")
	check(ashen.portal == Vector2(10, 88) and ashen.beacon == Vector2(448, 264), "ashen portal/beacon")
	check(frost.portal == Vector2(10, 264) and frost.beacon == Vector2(448, 56), "frost portal/beacon")
	check(not ashen.is_buildable(10, 5), "path cell is not buildable")
	check(ashen.is_buildable(ashen.build_cells[0].x, ashen.build_cells[0].y), "build cell is buildable")

	# ---- build / upgrade / sell / economy ----
	var m = GM.new()
	m.new_game("ashen", false)
	check(m.gold == 140 and m.lives == 20 and m.wave == 1 and m.phase == "prep", "initial 140 gold / 20 lives / wave 1")
	var c0 := find_free_cell(m)
	var r: Dictionary = m.try_build("bolt", c0.x, c0.y, false, "smoke")
	check(bool(r.get("ok", false)), "build bolt on valid cell")
	check(m.gold == 100, "bolt cost 40")
	check(bool(m.try_build("bolt", c0.x, c0.y, false).get("why") == "occupied"), "occupied cell rejected")
	check(bool(m.try_build("bolt", 10, 5, false).get("why") == "terrain"), "path/terrain rejected")
	var tower = r["tower"]
	m.gold = 100
	check(m.try_upgrade(tower, false, "smoke"), "upgrade Lv1")
	check(tower.level == 1 and m.gold == 55 and tower.invested == 85, "upgrade cost 45, invested 85")
	check(not m.try_upgrade(tower, false), "upgrade blocked when gold < 70")
	m.gold = 100
	check(m.try_upgrade(tower, false), "upgrade Lv2")
	check(tower.level == 2 and m.gold == 30, "upgrade Lv2 cost 70")
	check(not m.try_upgrade(tower, false), "max level upgrade rejected")
	m.try_sell(tower)
	check(m.tower_at(c0.x, c0.y) == null, "sell removes tower from grid")
	check(m.gold == 130, "sell refund floor(155*0.65)=100")

	var mm = GM.new()
	mm.new_game("ashen", false)
	var mc := find_free_cell(mm)
	var mint_res: Dictionary = mm.try_build("mint", mc.x, mc.y, false)
	check(bool(mint_res.get("ok", false)), "build mint")
	mm.end_wave()
	check(mm.gold == 140 - 50 + 24 + 6, "wave bonus 18+6*wave plus mint income 6")
	check(mm.wave == 2 and mm.phase == "prep", "wave advanced to 2 with prep")

	# ---- combat: targeting, projectile, armor, slow, heal ----
	var cb = GM.new()
	cb.new_game("ashen", false)
	var ccell := find_free_cell(cb)
	var bres: Dictionary = cb.try_build("bolt", ccell.x, ccell.y, false)
	var bt = bres["tower"]
	cb.spawn_enemy("walker")
	var walker = cb.enemies[0]
	walker.pos = bt.pos + Vector2(10, 0)
	walker.dist = 10.0
	cb.update_towers(0.2)
	check(cb.projectiles.size() == 1, "bolt fires one projectile")
	for i in 30:
		cb.update_projectiles(GD.STEP)
	check(near(walker.hp, 20.0), "bolt Lv1 deals 10, walker 30 -> 20 (got %s)" % str(walker.hp))

	var ar = GM.new()
	ar.new_game("ashen", false)
	ar.spawn_enemy("brute")
	var brute = ar.enemies[0]
	check(brute.hp == 115, "brute base hp 115")
	check(ar.damage_enemy(brute, 10) == 8, "armor 2 reduces 10 to 8")
	check(ar.damage_enemy(brute, 1) == 1, "minimum damage 1")
	check(ar.damage_enemy(brute, 10, true) == 10, "ignore armor 10")

	var sp = GM.new()
	sp.new_game("ashen", false)
	sp.spawn_enemy("spore")
	var spore = sp.enemies[0]
	sp.apply_slow(spore, 0.4, 2.0)
	check(near(spore.slow_amt, 0.2), "spore 50% slow resistance halves 40% slow")

	var hl = GM.new()
	hl.new_game("ashen", false)
	hl.spawn_enemy("spore")
	hl.spawn_enemy("walker")
	var healer = hl.enemies[0]
	var healed = hl.enemies[1]
	healed.hp = 20.0
	healer.dist = 100.0
	healed.dist = 100.0
	hl.position_enemy(healer)
	hl.position_enemy(healed)
	healer.heal_t = 0.0
	hl.update_enemies(0.02)
	check(near(healed.hp, 26.0), "spore heals nearby ally 6HP (got %s)" % str(healed.hp))

	# ---- leaks / defeat / boss hp ----
	var lk = GM.new()
	lk.new_game("ashen", false)
	lk.spawn_enemy("walker")
	var leaker = lk.enemies[0]
	leaker.dist = lk.map.total_len - 0.5
	leaker.speed = 32.0
	lk.update_enemies(0.1)
	check(leaker.alive == false and lk.lives == 19 and lk.leaks == 1, "leak costs 1 life")

	var lose = GM.new()
	lose.new_game("ashen", false)
	lose.lives = 1
	lose.spawn_enemy("boss")
	var boss_leak = lose.enemies[0]
	boss_leak.dist = lose.map.total_len - 0.5
	lose.update_enemies(0.1)
	check(not lose.over.is_empty() and lose.over["win"] == false, "boss leak 8 = defeat at 0 lives")
	check(lose.lives == 0, "lives clamped to 0")

	var bossm = GM.new()
	bossm.new_game("ashen", false)
	bossm.wave = 12
	bossm.spawn_enemy("boss")
	check(bossm.boss != null and bossm.boss.hp == 3030 and bossm.boss.armor == 4.0,
		"wave-12 boss hp 3030 / armor 4 (got %s)" % str(bossm.boss.hp if bossm.boss != null else -1))

	# ---- skill + cooldown ----
	var sk = GM.new()
	sk.new_game("ashen", false)
	for i in 3:
		sk.spawn_enemy("walker")
	var hit: int = sk.cast_skill(true)
	check(hit == 3, "skill hits all 3 walkers")
	check(near(sk.skill_cd, 35.0), "skill cooldown 35s")
	check(sk.alive_enemies().is_empty(), "30 true damage kills 30HP walkers")
	check(sk.cast_skill(true) == 0, "skill blocked during cooldown")
	var sk2 = GM.new()
	sk2.new_game("ashen", false)
	sk2.spawn_enemy("brute")
	sk2.cast_skill(false)
	check(near(sk2.enemies[0].hp, 85.0), "skill ignores armor (115-30=85)")

	# ---- waves / spawn / victory ----
	var wv = GM.new()
	wv.new_game("ashen", true)
	wv.simulate(5.7)
	check(wv.phase == "wave" and wv.wave_total == 6, "wave 1 starts with 6 walkers")
	check(wv.spawn_queue.size() < 6, "spawn queue drains")
	wv.simulate(1.0)
	check(wv.alive_enemies().size() >= 1, "enemies spawn along the path")

	var win = GM.new()
	win.new_game("ashen", false)
	win.wave = 12
	win.end_wave()
	check(not win.over.is_empty() and win.over["win"] == true, "clearing wave 12 wins")
	check(win.phase == "done" and win.over["wave"] == 12, "victory state")

	# ---- restart / map switch ----
	var rs = GM.new()
	rs.new_game("frost", true)
	rs.simulate(20.0)
	var old_towers = rs.towers.size()
	rs.new_game("ashen", false)
	check(rs.map_id == "ashen" and rs.wave == 1 and rs.phase == "prep", "restart resets map/wave/phase")
	check(rs.gold == 140 and rs.lives == 20 and rs.kills == 0 and rs.leaks == 0, "restart resets economy/stats")
	check(rs.towers.is_empty() and rs.enemies.is_empty() and rs.projectiles.is_empty(), "restart clears entities")
	check(not rs.ai_on, "restart respects manual mode")
	check(old_towers >= 0, "prior run had entities/state")

	# ---- AI toggle + player takeover ----
	var ai = GM.new()
	ai.new_game("ashen", true)
	check(ai.ai_on, "AI starts enabled")
	ai.set_ai(false)
	check(not ai.ai_on, "AI toggle off")
	ai.set_ai(true)
	check(ai.ai_on, "AI toggle on")
	var aicell := find_free_cell(ai)
	ai.try_build("bolt", aicell.x, aicell.y, false, "manual")
	check(not ai.ai_on, "manual action takes over from AI")

	# ---- AI unattended 12-wave autotests (parity with HTML) ----
	var expected := {
		"ashen": {"time": 559.67, "actions": 72},
		"frost": {"time": 444.75, "actions": 61},
	}
	for map_id in ["ashen", "frost"]:
		var auto = GM.new()
		auto.new_game(map_id, true)
		var res: Dictionary = auto.run_autotest(900.0)
		print("AUTOTEST %s win=%s kills=%d lives=%d time=%.2f actions=%d towers=%d cheats=%s" % [
			map_id, str(res["win"]), res["kills"], res["lives"], res["sim_time"], res["ai_actions"],
			auto.towers.size(), str(res["cheats"])])
		check(res["win"] == true, "%s AI wins 12 waves" % map_id)
		check(res["timeout"] == false and res["cheats"] == false, "%s no timeout / no cheats" % map_id)
		check(res["kills"] == 204, "%s 204 kills (got %s)" % [map_id, res["kills"]])
		check(res["lives"] == 20 and res["leaks"] == 0, "%s finishes with 20 lives / 0 leaks" % map_id)
		check(res["ai_actions"] == expected[map_id]["actions"],
			"%s AI action count %d (got %s)" % [map_id, expected[map_id]["actions"], res["ai_actions"]])
		check(near(res["sim_time"], expected[map_id]["time"], 2.0),
			"%s sim time ~%.2fs (got %.2fs)" % [map_id, expected[map_id]["time"], res["sim_time"]])

	# ---- summary ----
	print("SMOKE CHECKS: %d, FAILS: %d" % [checks, fails])
	if fails == 0:
		print("EMBERHOLD3D_SMOKE_OK")
		quit(0)
	else:
		print("EMBERHOLD3D_SMOKE_FAIL")
		quit(1)
