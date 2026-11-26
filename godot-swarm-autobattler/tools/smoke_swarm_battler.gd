extends SceneTree

## Swarmforge headless smoke test.
## 运行：godot --headless --path godot-swarm-autobattler -s tools/smoke_swarm_battler.gd
## 末行：SWARM_BATTLER_SMOKE_OK

const Cards = preload("res://scripts/swarm_cards.gd")
const State = preload("res://scripts/swarm_state.gd")
const Battle = preload("res://scripts/swarm_battle.gd")
const Roster = preload("res://scripts/swarm_roster.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS  ", label, (("  [" + detail + "]") if detail != "" else ""))
	else:
		failures += 1
		printerr("FAIL  ", label, (("  [" + detail + "]") if detail != "" else ""))


func _run() -> void:
	_test_cards()
	_test_shop()
	_test_merge()
	_test_growth()
	_test_battle()
	_test_roster()
	_test_campaign()
	_test_reset()
	await _test_boot_scene()
	print("SMOKE_CHECKS=", checks, " FAILURES=", failures)
	if failures == 0:
		print("SWARM_BATTLER_SMOKE_OK")
		quit(0)
	else:
		printerr("SWARM_BATTLER_SMOKE_FAILED checks=%d failures=%d" % [checks, failures])
		quit(1)


func _test_cards() -> void:
	check(Cards.CARD_LIST.size() == 10, "卡池有 10 张原创卡")
	check(Cards.get_card("spark_flea").name == "火花蚤", "卡牌查询")
	check(Cards.get_card("nope").is_empty(), "未知卡牌返回空")
	check(Cards.role_label(Cards.get_card("prism_gadfly")) == "远程", "远程标签")
	check(Cards.role_label(Cards.get_card("weave_moth")) == "支援", "支援标签")
	check(Cards.role_label(Cards.get_card("molten_weaver")) == "溅射", "溅射标签")
	check(Cards.level_cost(2) == 5 and Cards.level_cost(5) == 11, "升本价格")
	check(Cards.level_cost(6) == -1, "满级不再收费")
	var odds6 := Cards.shop_odds(6)
	check(odds6.size() == 5 and int(odds6[4]) > 0, "Lv6 商店含 T5")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var rolled := Cards.roll_shop(rng, 4, 5)
	check(rolled.size() == 5, "商店固定 5 格")
	for id in rolled:
		check(not Cards.get_card(id).is_empty(), "商店卡牌 id 有效", String(id))
	check(Cards.sell_value({"id": "spark_flea", "star": 2}) == 9, "金卡出售返还 3 倍")


func _test_shop() -> void:
	var st = State.new()
	st.new_run(424242)
	check(st.shop.size() == 5, "初始商店 5 格")
	check(st.gold == 10, "初始金币 10")
	check(st.level == 2, "初始熔炉 Lv2")
	check(st.board.is_empty(), "初始空编队")
	check(st.heroes.size() == 4, "1 玩家 + 3 AI 英雄")
	check(int(st.heroes[0]["hp"]) == 30 and int(st.heroes[1]["hp"]) == 20, "英雄血量")
	check(st.ally_unit_total() == 0, "空编队单位数为 0")
	var id := String(st.shop[0])
	var cost := int(Cards.get_card(id)["cost"])
	var gold_before: int = st.gold
	var r := st.buy_slot(0)
	check(bool(r.get("ok", false)), "购买商店第 1 格")
	check(st.board.size() == 1, "购买后上场 1 张")
	check(st.gold == gold_before - cost, "购买扣除金币")
	check(String(st.shop[0]).is_empty(), "购买后商店格清空")
	var gold2: int = st.gold
	var rr := st.refresh_shop()
	check(bool(rr.get("ok", false)) and st.gold == gold2 - 1, "刷新花费 1 金币")
	check(st.shop.size() == 5, "刷新后 5 格")
	var refund := Cards.sell_value(st.board[0])
	var gold3: int = st.gold
	var sr := st.sell_card(0)
	check(bool(sr.get("ok", false)), "出售单位")
	check(st.board.is_empty() and st.gold == gold3 + refund, "出售返还金币")
	st.debug_set_gold(0)
	check(not bool(st.buy_slot(0).get("ok", true)), "金币不足无法购买")
	var g4: int = st.gold
	check(not bool(st.refresh_shop().get("ok", true)) and st.gold == g4, "金币不足无法刷新")


func _test_merge() -> void:
	var st = State.new()
	st.new_run(777)
	st.debug_set_gold(100)
	st.debug_set_board([])
	st.debug_set_shop(["spark_flea", "spark_flea", "spark_flea", "rivet_grub", "prism_gadfly"])
	check(bool(st.buy_slot(0).get("ok", false)), "三合一：买第 1 张")
	check(st.board.size() == 1, "三合一：买第 1 张后占 1 格")
	var r2 := st.buy_slot(1)
	check(bool(r2.get("ok", false)) and st.board.size() == 2, "三合一：买第 2 张")
	var r3 := st.buy_slot(2)
	check(bool(r3.get("ok", false)) and bool(r3.get("combined", false)), "三合一触发金卡")
	check(st.board.size() == 1, "三合一后只占 1 格")
	check(int(st.board[0]["star"]) == 2, "三合一后 ★★")
	check(String(st.board[0]["id"]) == "spark_flea", "三合一保留卡牌 id")
	check(st.ally_unit_total() == 6, "金卡编队 3×2=6 单位")
	check(String(st.shop[2]).is_empty(), "三合一消耗的商店格已清空")
	# 7 格上限
	var full := [
		{"id": "spark_flea", "star": 1}, {"id": "rivet_grub", "star": 1},
		{"id": "prism_gadfly", "star": 1}, {"id": "magwire_mantis", "star": 1},
		{"id": "arc_ant", "star": 1}, {"id": "spore_ballista", "star": 1},
		{"id": "weave_moth", "star": 1},
	]
	st.debug_set_board(full)
	st.debug_set_gold(50)
	st.debug_set_shop(["molten_weaver", "", "", "", ""])
	var gold_before: int = st.gold
	var r_full := st.buy_slot(0)
	check(not bool(r_full.get("ok", true)), "满 7 格时不能买新卡")
	check(st.board.size() == 7 and st.gold == gold_before, "满格失败不扣金币")
	st.debug_set_shop(["spark_flea", "", "", "", ""])
	# 场上有 1 张火花蚤，只有 1 份，不触发三合一，仍应满格失败
	check(not bool(st.buy_slot(0).get("ok", true)), "满格且未凑齐 3 份仍失败")


func _test_growth() -> void:
	var st = State.new()
	st.new_run(8888)
	st.debug_set_gold(100)
	st.debug_set_level(2)
	var gold_before: int = st.gold
	var lu := st.level_up()
	check(bool(lu.get("ok", false)), "升到 Lv3")
	check(st.level == 3 and st.gold == gold_before - 5, "升本扣 5 金币")
	st.debug_set_level(6)
	check(not bool(st.level_up().get("ok", true)), "Lv6 后不能继续升")
	st.debug_set_greed(0)
	st.debug_set_gold(100)
	check(st.get_ally_greed_mult() == 1.0 and st.get_enemy_greed_mult() == 1.0, "贪婪潮 0 层无加成")
	var g0: int = st.gold
	var gr := st.add_greed()
	check(bool(gr.get("ok", false)), "追潮 1 层")
	check(st.greed == 1 and st.gold == g0 + 2, "追潮立即 +2 金币")
	check(is_equal_approx(st.get_ally_greed_mult(), 1.15), "友军 +15%/层")
	check(is_equal_approx(st.get_enemy_greed_mult(), 1.30), "敌军 +30%/层")
	st.debug_set_greed(5)
	check(not bool(st.add_greed().get("ok", true)), "贪婪潮 5 层封顶")
	# 洪流 ×100
	var golden_army := [{"id": "spark_flea", "star": 2}]
	st.debug_set_board(golden_army)
	st.debug_set_greed(0)
	st.flood = false
	check(st.ally_unit_total() == 6, "常规模式金卡 6 单位")
	st.toggle_flood()
	check(st.ally_unit_total() == 600, "洪流模式金卡 600 单位")
	var seven := [
		{"id": "crown_colossus", "star": 2}, {"id": "tideheart_engine", "star": 2},
		{"id": "molten_weaver", "star": 2}, {"id": "weave_moth", "star": 2},
		{"id": "spore_ballista", "star": 2}, {"id": "arc_ant", "star": 2},
		{"id": "prism_gadfly", "star": 2},
	]
	st.debug_set_board(seven)
	var total := st.ally_unit_total()
	check(total <= Cards.UNIT_CAP_PER_SIDE and total >= Cards.UNIT_CAP_PER_SIDE - 6,
		"7 金卡洪流压到每边上限", "total=%d" % total)
	var counts := Cards.allocate_units(seven, 1.0, true, Cards.UNIT_CAP_PER_SIDE, 1.0)
	check(counts.size() == 7, "压上限后仍保留 7 张卡")
	var sum := 0
	for n in counts:
		sum += int(n)
	check(sum <= Cards.UNIT_CAP_PER_SIDE, "分配总数不超上限")


func _test_battle() -> void:
	var b = Battle.new()
	b.setup(
		[{"id": "spark_flea", "star": 1}, {"id": "prism_gadfly", "star": 1}, {"id": "rivet_grub", "star": 1}],
		[{"id": "rivet_grub", "star": 1}, {"id": "arc_ant", "star": 1}, {"id": "magwire_mantis", "star": 1}],
		{"seed": 99, "fx": false, "cap": 500}
	)
	check(b.side_count[0] > 0 and b.side_count[1] > 0, "编队生成双方单位")
	check(b.pos.size() == b.side_count[0] + b.side_count[1], "扁平数组单位数一致")
	var arena_ok := true
	for p in b.pos:
		if p.x < 0.0 or p.x > Battle.ARENA.x or p.y < 0.0 or p.y > Battle.ARENA.y:
			arena_ok = false
	check(arena_ok, "出生点都在竞技场内")
	var res: Dictionary = b.run_to_end(400)
	check(b.finished, "战斗在 tick 上限内结束")
	check(res.has("winner") and int(res["winner"]) in [0, 1, 2], "战斗有合法胜负")
	check(float(res["duration"]) > 0.0 and float(res["duration"]) <= 30.1, "战斗时长合法", "dur=%.1f" % float(res["duration"]))
	check(int(res["kills"]) > 0 or int(res["units"][0]) + int(res["units"][1]) > 0, "战斗产生伤亡或残留")
	check(res.has("log") and res["log"].size() >= 1, "战斗日志")
	check(res.has("surviving_cards"), "战斗结果含存活卡数")
	# 确定性
	var b2 = Battle.new()
	b2.setup(
		[{"id": "spark_flea", "star": 1}, {"id": "prism_gadfly", "star": 1}, {"id": "rivet_grub", "star": 1}],
		[{"id": "rivet_grub", "star": 1}, {"id": "arc_ant", "star": 1}, {"id": "magwire_mantis", "star": 1}],
		{"seed": 99, "fx": false, "cap": 500}
	)
	var res2: Dictionary = b2.run_to_end(400)
	check(int(res2["winner"]) == int(res["winner"]), "同种子胜负可复现")
	check(absf(float(res2["duration"]) - float(res["duration"])) < 0.01, "同种子时长可复现")
	check(res2["units"] == res["units"], "同种子剩余单位可复现")
	# 3000 单位规模
	var seven := [
		{"id": "spark_flea", "star": 1}, {"id": "rivet_grub", "star": 1},
		{"id": "prism_gadfly", "star": 1}, {"id": "arc_ant", "star": 1},
		{"id": "molten_weaver", "star": 1}, {"id": "crown_colossus", "star": 1},
		{"id": "tideheart_engine", "star": 1},
	]
	var b3 = Battle.new()
	b3.setup(seven, seven, {"seed": 5, "fx": false, "flood": true, "cap": 1500})
	check(b3.side_count[0] == 1500 and b3.side_count[1] == 1500, "洪流双方各 1500 单位",
		"%d vs %d" % [b3.side_count[0], b3.side_count[1]])
	check(b3.pos.size() == 3000, "同屏 3000 个扁平单位", "n=%d" % b3.pos.size())
	var t0 := Time.get_ticks_msec()
	var res3: Dictionary = b3.run_to_end(400)
	var elapsed := Time.get_ticks_msec() - t0
	print("SIM3000 ms=", elapsed, " ticks=", res3["ticks"], " winner=", res3["winner"],
		" units=", res3["units"], " dur=", res3["duration"])
	check(b3.finished, "3000 单位战斗可结束")
	check(b3.pos.size() == 3000, "3000 单位数组未被重建/丢失")
	# 洪流封顶时的敌方贪婪溢出转为 HP/ATK
	var bm = Battle.new()
	bm.setup([{"id": "rivet_grub", "star": 1}], [{"id": "rivet_grub", "star": 1}], {
		"seed": 3, "fx": false, "cap": 10, "flood": true, "enemy_stat_mult": 1.5,
	})
	var enemy_hp := 0.0
	for i in bm.pos.size():
		if int(bm.team[i]) == 1:
			enemy_hp = bm.max_hp[i]
			break
	check(is_equal_approx(enemy_hp, 34.0 * 1.5), "敌军 HP/ATK 溢出倍率生效", "hp=%.1f" % enemy_hp)
	# 镜像预演：没有步进也应能渲染编队
	var preview = Battle.new()
	preview.setup(seven, seven, {"seed": 5, "fx": false, "cap": 300})
	check(preview.pos.size() > 0 and preview.tick_count == 0, "编队预览零步进可用")


func _test_roster() -> void:
	var cards := [
		{"id": "spark_flea", "star": 2}, {"id": "spore_ballista", "star": 1},
		{"id": "molten_weaver", "star": 1},
	]
	var code := Roster.encode(cards, 4, 2, true)
	check(code.begins_with(Roster.PREFIX), "阵容码带 SWF1 前缀")
	check(code.length() > 30, "阵容码有内容", "len=%d" % code.length())
	var dec := Roster.decode(code)
	check(bool(dec.get("ok", false)), "阵容码可解析")
	check(dec["cards"].size() == 3, "解析保留 3 张卡")
	check(int(dec["level"]) == 4 and int(dec["greed"]) == 2 and bool(dec["flood"]), "解析保留等级/贪婪/洪流")
	check(int(dec["cards"][0]["star"]) == 2, "解析保留星级")
	var bad := Roster.decode("SWF1:%%%notbase64%%%")
	check(not bool(bad.get("ok", true)), "坏 base64 被拒绝")
	var bad2 := Roster.decode("hello")
	check(not bool(bad2.get("ok", true)), "无前缀被拒绝")
	var bad_json := JSON.stringify({"v": 1, "level": 4, "greed": 0, "flood": false, "cards": [{"id": "no_such_unit", "star": 1}]})
	var bad3 := Roster.decode(Roster.PREFIX + Marshalls.utf8_to_base64(bad_json))
	check(not bool(bad3.get("ok", true)), "未知卡牌被拒绝")
	var st = State.new()
	st.new_run(31337)
	var imp := st.import_code(code)
	check(bool(imp.get("ok", false)), "状态导入阵容码")
	check(st.board.size() == 3 and st.level == 4 and st.greed == 2 and st.flood, "导入覆盖编队/等级/贪婪/洪流")
	check(st.saved_code.begins_with(Roster.PREFIX), "导入后保存镜像码")
	var export2 := st.export_code()
	var dec2 := Roster.decode(export2)
	check(bool(dec2.get("ok", false)) and dec2["cards"].size() == 3, "重新导出再解析")


func _test_campaign() -> void:
	var st = State.new()
	st.new_run(2026)
	st.debug_set_gold(100)
	st.debug_set_shop(["spark_flea", "spark_flea", "spark_flea", "rivet_grub", "prism_gadfly"])
	st.buy_slot(0)
	st.buy_slot(1)
	st.buy_slot(2)
	check(st.board.size() == 1 and int(st.board[0]["star"]) == 2, "战役准备：金卡上场")
	var start := st.start_battle(false)
	check(bool(start.get("ok", false)) and st.phase == "battle", "进入战斗阶段")
	check(st.battle != null and st.battle.side_count[0] > 0, "战斗实例已生成")
	check(st.saved_code.begins_with(Roster.PREFIX), "开战时自动保存阵容码")
	var opp: int = int(st.encounter_index)
	check(opp >= 1 and opp <= 3, "有 AI 对手")
	var opp_hp := int(st.heroes[opp]["hp"])
	var fake := {
		"winner": 0, "surviving_cards": [3, 0], "units": [10, 0],
		"start_units": [12, 12], "hp_frac": [0.3, 0.0], "duration": 5.0,
		"seed": 1, "timeout": false, "kills": 12, "log": ["fake"],
	}
	var fin := st.finish_battle(fake)
	check(bool(fin.get("ok", false)) and st.phase == "result", "战斗结算进入 result")
	check(st.pending_damage == 5, "胜方对英雄造成 2 + 存活卡数伤害", "dmg=%d" % st.pending_damage)
	check(int(st.heroes[opp]["hp"]) <= opp_hp - 5, "对手英雄掉血", "%d -> %d" % [opp_hp, int(st.heroes[opp]["hp"])])
	check(st.last_win, "记录本场胜利")
	var gold_before: int = st.gold
	var round_before: int = int(st.round_no)
	var cont := st.continue_after_result()
	check(bool(cont.get("ok", false)) and st.phase == "shop", "结算后回到铸巢")
	check(st.round_no == round_before + 1, "回合数 +1")
	check(st.gold == gold_before + int(cont["income"]), "获得回合收入")
	check(not st.last_win, "新回合清空上一场胜利标记")
	check(not st.saved_code.is_empty(), "镜像阵容码保留")
	# 镜像试炼不应改变回合/金币
	var mirror_round: int = int(st.round_no)
	var mirror_gold: int = int(st.gold)
	var tr := st.start_battle(true)
	check(bool(tr.get("ok", false)) and st.training and st.phase == "battle", "进入镜像试炼")
	st.finish_battle(fake)
	check(st.phase == "result" and st.training, "试炼结算不推进战役")
	var back := st.continue_after_result()
	check(bool(back.get("ok", false)) and st.phase == "shop", "试炼后回到商店")
	check(st.round_no == mirror_round and st.gold == mirror_gold, "试炼不改回合与金币")
	# 胜负终点
	st.debug_force_victory()
	check(st.phase == "gameover" and st.final_outcome == "victory", "全灭 AI 进入胜利终局")
	st.new_run(11)
	st.debug_force_defeat()
	check(st.phase == "gameover" and st.final_outcome == "defeat", "玩家归零进入失败终局")
	# 真实跑完一场（不依赖假结果）
	var st2 = State.new()
	st2.new_run(7777)
	st2.debug_set_board([
		{"id": "spark_flea", "star": 1}, {"id": "rivet_grub", "star": 1},
		{"id": "prism_gadfly", "star": 1}, {"id": "arc_ant", "star": 1},
	])
	var s2 := st2.start_battle(false)
	check(bool(s2.get("ok", false)), "真实战斗开始")
	var resolved: Dictionary = st2.debug_resolve_current_battle()
	check(bool(resolved.get("ok", false)) and st2.phase in ["result", "gameover"], "真实战斗跑完并结算")


func _test_reset() -> void:
	var st = State.new()
	st.new_run(123)
	st.debug_set_gold(99)
	st.debug_set_level(5)
	st.debug_set_greed(4)
	st.debug_set_board([{"id": "spark_flea", "star": 2}])
	st.flood = true
	st.new_run(456)
	check(st.round_no == 1, "重置：回合回到 1")
	check(st.gold == 10 and st.level == 2 and st.greed == 0, "重置：金币/等级/贪婪归位")
	check(st.board.is_empty(), "重置：编队清空")
	check(not st.flood, "重置：洪流关闭")
	check(st.heroes.size() == 4 and int(st.heroes[0]["hp"]) == 30, "重置：英雄满血")
	check(st.phase == "shop" and st.battle == null, "重置：回到铸巢")
	check(st.shop.size() == 5, "重置：商店重新生成")
	check(st.log_lines.size() > 0, "重置：有日志")


func _test_boot_scene() -> void:
	var path := "res://scenes/main.tscn"
	if not ResourceLoader.exists(path):
		check(false, "主场景存在")
		return
	var packed = load(path)
	var scene = packed.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	check(scene.get("state") != null, "主场景实例化且状态就绪")
	if scene.has_method("debug_button_counts"):
		var counts: Dictionary = scene.debug_button_counts()
		check(int(counts.get("shop", 0)) == 5, "UI 生成 5 个商店按钮", str(counts))
		check(int(counts.get("board", 0)) == 7, "UI 生成 7 个上场槽", str(counts))
	scene.queue_free()
	await process_frame
