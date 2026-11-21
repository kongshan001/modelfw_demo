extends SceneTree

const BattleAIScript = preload("res://scripts/battle_ai.gd")
const BattleCoreScript = preload("res://scripts/battle_core.gd")
const CardDBScript = preload("res://scripts/card_db.gd")

# Headless 冒烟测试：法力曲线 / 召唤合法性 / 移动与攻击范围 / 嘲讽 / 疾行 /
# 回合交替 / 手牌上限 / 换牌 / AI 完整回合 / 将军死亡判胜 / 同 seed 复现 / 数据与资产完整性。
# 用法：godot --path godot-card-tactics --headless -s tools/smoke_card_tactics.gd

var _db: CardDBScript
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_db = CardDBScript.new()
	_test_data_and_assets()
	_test_mana_curve()
	_test_summon_legality()
	_test_movement_and_attack_range()
	_test_provoke()
	_test_rush_and_opening_heal()
	_test_turn_draw_replace()
	_test_ai_completes_turn_and_finishes_game()
	_test_general_death()
	_test_seed_reproducibility()

	if _failures.is_empty():
		print("checks=%d" % _checks)
		print("CARD_TACTICS_SMOKE_OK")
		quit(0)
	else:
		printerr("CARD_TACTICS_SMOKE_FAIL (%d/%d checks failed)" % [_failures.size(), _checks])
		for failure in _failures:
			printerr("  - " + failure)
		quit(1)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS  " + message)
	else:
		_failures.append(message)
		printerr("FAIL  " + message)


func _new_core(seed_value := 1) -> BattleCoreScript:
	var core := BattleCoreScript.new(_db)
	core.setup(seed_value, _db.deck("player"), _db.deck("ai"))
	return core


func _clear_minions(core: BattleCoreScript) -> void:
	var keep: Array[Dictionary] = []
	for unit in core.units:
		if unit["is_general"]:
			keep.append(unit)
	core.units = keep


func _set_ready(core: BattleCoreScript, owner: int, move := true, attack := true) -> void:
	for unit in core.units:
		if int(unit["owner"]) == owner:
			unit["can_move"] = move
			unit["can_attack"] = attack


func _test_data_and_assets() -> void:
	print("— 数据与资产 —")
	_check(_db.cards.size() == 16, "卡牌总数 16（12 随从 + 4 法术）")
	var units := 0
	var spells := 0
	for card in _db.cards.values():
		if card["type"] == "unit":
			units += 1
		elif card["type"] == "spell":
			spells += 1
	_check(units == 12 and spells == 4, "随从 12 / 法术 4")
	_check(_db.deck("player").size() == 20, "玩家牌库 20 张")
	_check(_db.deck("ai").size() == 20, "AI 牌库 20 张")
	var decks_ok := true
	for deck_id in ["player", "ai"]:
		for card_id in _db.deck(deck_id):
			if not _db.cards.has(card_id):
				decks_ok = false
	_check(decks_ok, "牌库中的卡牌 id 都能在卡表里找到")

	var asset_ok := true
	var unit_sprites := [
		"f1_general", "f2_general", "f1_silverguardsquire", "f1_backlinearcher",
		"f1_sunstonetemplar", "f1_windbladecommander", "f1_ironcliffeguardian",
		"f2_onyxjaguar", "f2_sparrowhawk", "f2_lanternfox", "f2_mage4winds",
		"f2_heartofthesonghai", "neutral_healingmystic", "neutral_bonereaper",
	]
	for id in unit_sprites:
		if not FileAccess.file_exists("res://assets/duelyst_cc0/units/%s.png" % id):
			asset_ok = false
		if not FileAccess.file_exists("res://assets/duelyst_cc0/units/%s.json" % id):
			asset_ok = false
	for frame in ["f1_unit", "f1_spell", "f2_unit", "f2_spell", "neutral_unit", "neutral_spell"]:
		if not FileAccess.file_exists("res://assets/duelyst_cc0/card_backgrounds/%s.png" % frame):
			asset_ok = false
	for icon in ["icon_f1_sundropelixir", "icon_f1_truestrike", "icon_f2_phoenixfire", "icon_f2_cobrastrike"]:
		if not FileAccess.file_exists("res://assets/duelyst_cc0/icons/%s.png" % icon):
			asset_ok = false
		if not FileAccess.file_exists("res://assets/duelyst_cc0/icons/%s.json" % icon):
			asset_ok = false
	for fx in ["fx_impact", "fx_slashfrenzy", "fx_heal", "fx_buff", "fx_summonlegendary", "fx_f2_phoenixfire"]:
		if not FileAccess.file_exists("res://assets/duelyst_cc0/fx/%s.png" % fx):
			asset_ok = false
		if not FileAccess.file_exists("res://assets/duelyst_cc0/fx/%s.json" % fx):
			asset_ok = false
	_check(asset_ok, "所用 CC0 图集/帧 JSON 均存在")


func _test_mana_curve() -> void:
	print("— 法力曲线 —")
	var core := _new_core(5)
	_check(core.mana[0] == 1 and core.max_mana[0] == 1, "起始法力 1/1")
	_check(core.turn_owner == BattleCoreScript.PLAYER, "玩家先手")
	var ok := true
	for expected in range(2, 10):
		core.end_turn()
		core.end_turn()
		if core.max_mana[0] != mini(expected, 9) or core.mana[0] != mini(expected, 9):
			ok = false
	_check(ok, "每轮 +1，上限 9")
	core.end_turn()
	core.end_turn()
	core.end_turn()
	core.end_turn()
	_check(core.max_mana[0] == 9 and core.mana[0] == 9, "到达上限后保持 9/9")


func _test_summon_legality() -> void:
	print("— 召唤合法性 —")
	var core := _new_core(7)
	_clear_minions(core)
	core.turn_owner = BattleCoreScript.PLAYER
	core.mana[0] = 9
	core.max_mana[0] = 9
	core.hands[0] = ["f1_silverguardsquire", "f1_silverguardsquire", "f1_silverguardsquire"]
	var tiles := core.get_summon_tiles(BattleCoreScript.PLAYER)
	_check(Vector2i(3, 4) in tiles and Vector2i(5, 4) in tiles and Vector2i(4, 3) in tiles,
		"召唤格 = 将军相邻空格")
	_check(not (Vector2i(0, 0) in tiles), "远处格子不能召唤")
	_check(not core.can_play_unit(BattleCoreScript.PLAYER, 0, Vector2i(0, 0)), "can_play_unit 拒绝远处格子")
	_check(not core.can_play_unit(BattleCoreScript.PLAYER, 0, Vector2i(4, 4)), "不能召唤到已占用格")
	var hand_before: int = core.hands[0].size()
	var result := core.play_unit(BattleCoreScript.PLAYER, 0, Vector2i(3, 4))
	_check(not result.is_empty(), "相邻空格召唤成功")
	var summoned := core.unit_at(Vector2i(3, 4))
	_check(not summoned.is_empty() and int(summoned["owner"]) == BattleCoreScript.PLAYER,
		"召唤单位落在目标格")
	_check(core.mana[0] == 7, "召唤扣除 2 点法力")
	_check(core.hands[0].size() == hand_before - 1, "召唤后手牌 -1")
	core.mana[0] = 1
	_check(not core.can_play_unit(BattleCoreScript.PLAYER, 0, Vector2i(5, 4)), "法力不足时不能召唤")
	core.turn_owner = BattleCoreScript.AI
	core.mana[0] = 9
	_check(not core.can_play_unit(BattleCoreScript.PLAYER, 0, Vector2i(5, 4)), "非己方回合不能召唤")


func _test_movement_and_attack_range() -> void:
	print("— 移动 / 近战 / 远程 —")
	var core := _new_core(9)
	_clear_minions(core)
	core.turn_owner = BattleCoreScript.PLAYER
	core.mana[0] = 9
	var silver_uid := core.debug_spawn("f1_silverguardsquire", BattleCoreScript.PLAYER, Vector2i(4, 3))
	var onyx_uid := core.debug_spawn("f2_onyxjaguar", BattleCoreScript.AI, Vector2i(4, 2))
	_set_ready(core, BattleCoreScript.PLAYER)
	var moves := core.get_move_tiles(silver_uid)
	_check(Vector2i(3, 3) in moves and Vector2i(5, 3) in moves, "移动范围为相邻空格")
	_check(not (Vector2i(4, 1) in moves), "不能一次移动两格")
	_check(not (Vector2i(4, 2) in moves), "不能移动到已占用格")
	_check(onyx_uid in core.get_attack_targets(silver_uid), "近战可攻击相邻敌人")
	var attack_result := core.attack(silver_uid, onyx_uid)
	_check(not attack_result.is_empty(), "近战攻击成功")
	_check(int(core.find_unit(onyx_uid)["hp"]) == 1, "2 攻造成 2 点伤害")
	_check(core.get_attack_targets(silver_uid).is_empty(), "攻击后本回合不能再攻击")
	var moved := core.move_unit(silver_uid, Vector2i(5, 3))
	_check(not moved.is_empty(), "攻击后仍可移动一次")
	_check(core.move_unit(silver_uid, Vector2i(5, 2)).is_empty(), "移动后本回合不能再移动")

	var ranged_core := _new_core(10)
	_clear_minions(ranged_core)
	ranged_core.turn_owner = BattleCoreScript.PLAYER
	var archer_uid := ranged_core.debug_spawn("f1_backlinearcher", BattleCoreScript.PLAYER, Vector2i(2, 3))
	var target_uid := ranged_core.debug_spawn("f2_lanternfox", BattleCoreScript.AI, Vector2i(2, 1))
	_set_ready(ranged_core, BattleCoreScript.PLAYER)
	_check(target_uid in ranged_core.get_attack_targets(archer_uid), "远程可打同列 2 格且视线通畅")
	var blocker_uid := ranged_core.debug_spawn("f2_sparrowhawk", BattleCoreScript.AI, Vector2i(2, 2))
	_check(not (target_uid in ranged_core.get_attack_targets(archer_uid)), "中间有单位时远程被阻挡")
	ranged_core.units.erase(ranged_core.find_unit(blocker_uid))
	var diagonal_uid := ranged_core.debug_spawn("f2_lanternfox", BattleCoreScript.AI, Vector2i(3, 2))
	_check(not (diagonal_uid in ranged_core.get_attack_targets(archer_uid)), "远程不能打斜线")
	ranged_core.units.erase(ranged_core.find_unit(diagonal_uid))
	var far_uid := ranged_core.debug_spawn("f2_mage4winds", BattleCoreScript.AI, Vector2i(2, 0))
	_check(not (far_uid in ranged_core.get_attack_targets(archer_uid)), "远程射程上限 2 格")


func _test_provoke() -> void:
	print("— 嘲讽 —")
	var core := _new_core(12)
	_clear_minions(core)
	core.turn_owner = BattleCoreScript.PLAYER
	var silver_uid := core.debug_spawn("f1_silverguardsquire", BattleCoreScript.PLAYER, Vector2i(3, 3))
	var provoke_uid := core.debug_spawn("f2_lanternfox", BattleCoreScript.AI, Vector2i(3, 2))
	core.find_unit(provoke_uid)["provoke"] = true
	var other_uid := core.debug_spawn("f2_heartofthesonghai", BattleCoreScript.AI, Vector2i(4, 3))
	_set_ready(core, BattleCoreScript.PLAYER)
	var targets := core.get_attack_targets(silver_uid)
	_check(targets.size() == 1 and targets[0] == provoke_uid, "相邻有嘲讽时只能攻击嘲讽单位")
	core.units.erase(core.find_unit(provoke_uid))
	var free_targets := core.get_attack_targets(silver_uid)
	_check(other_uid in free_targets, "嘲讽移除后可攻击普通单位")


func _test_rush_and_opening_heal() -> void:
	print("— 疾行 / 登场治疗 —")
	var core := _new_core(13)
	_clear_minions(core)
	core.turn_owner = BattleCoreScript.AI
	core.mana[BattleCoreScript.AI] = 3
	core.max_mana[BattleCoreScript.AI] = 3
	core.hands[BattleCoreScript.AI] = ["f2_onyxjaguar"]
	core.debug_spawn("f1_silverguardsquire", BattleCoreScript.PLAYER, Vector2i(3, 1))
	var rush_result := core.play_unit(BattleCoreScript.AI, 0, Vector2i(3, 0))
	_check(not rush_result.is_empty(), "AI 在将军旁召唤猛虎刺客")
	var rush_uid := int(rush_result.get("uid", -1))
	var rush_unit := core.find_unit(rush_uid)
	_check(not rush_unit.is_empty() and bool(rush_unit["can_attack"]), "疾行单位召唤当回合可攻击")
	var rush_targets := core.get_attack_targets(rush_uid)
	_check(not rush_targets.is_empty(), "疾行单位落地即可锁定相邻目标")

	var heal_core := _new_core(14)
	_clear_minions(heal_core)
	heal_core.turn_owner = BattleCoreScript.PLAYER
	heal_core.mana[0] = 9
	heal_core.hands[0] = ["neutral_healingmystic"]
	heal_core.general_unit(BattleCoreScript.PLAYER)["hp"] = 14
	heal_core.play_unit(BattleCoreScript.PLAYER, 0, Vector2i(3, 4))
	_check(heal_core.general_hp(BattleCoreScript.PLAYER) == 16, "疗愈秘术师登场为将军恢复 2 点")


func _test_turn_draw_replace() -> void:
	print("— 回合 / 抽牌 / 换牌 —")
	var core := _new_core(11)
	_check(core.hands[BattleCoreScript.PLAYER].size() == 4, "开局玩家 4 张手牌")
	_check(core.hands[BattleCoreScript.AI].size() == 3, "AI 开局 3 张手牌")
	var deck_before: int = core.decks[BattleCoreScript.AI].size()
	core.end_turn()
	_check(core.turn_owner == BattleCoreScript.AI, "结束回合切换到 AI")
	_check(core.hands[BattleCoreScript.AI].size() == 4, "AI 回合开始抽 1 张")
	_check(core.decks[BattleCoreScript.AI].size() == deck_before - 1, "AI 牌库 -1")
	core.end_turn()
	_check(core.turn_owner == BattleCoreScript.PLAYER, "AI 结束回合切回玩家")
	_check(core.max_mana[BattleCoreScript.PLAYER] == 2, "玩家第二轮法力上限 2")

	core.hands[BattleCoreScript.PLAYER] = [
		"f1_silverguardsquire", "f1_silverguardsquire", "f1_silverguardsquire",
		"f1_silverguardsquire", "f1_silverguardsquire", "f1_silverguardsquire",
	]
	var deck_size: int = core.decks[BattleCoreScript.PLAYER].size()
	core.draw(BattleCoreScript.PLAYER, 1)
	_check(core.hands[BattleCoreScript.PLAYER].size() == 6, "手牌上限 6：抽到的牌被弃置")
	_check(core.decks[BattleCoreScript.PLAYER].size() == deck_size - 1, "满手时仍然消耗牌库")

	core.hands[BattleCoreScript.PLAYER] = ["f1_silverguardsquire", "f1_backlinearcher", "f1_truestrike"]
	core.replace_used[BattleCoreScript.PLAYER] = false
	var replaced := core.replace_card(BattleCoreScript.PLAYER, 0)
	_check(replaced, "每回合可换 1 张手牌")
	_check(core.hands[BattleCoreScript.PLAYER].size() == 3, "换牌后手牌数量不变")
	_check(core.replace_used[BattleCoreScript.PLAYER], "换牌标记生效")
	_check(not core.replace_card(BattleCoreScript.PLAYER, 0), "同回合不能换第二次")


func _test_ai_completes_turn_and_finishes_game() -> void:
	print("— AI —")
	var core := _new_core(20260227)
	core.end_turn()
	var ai := BattleAIScript.new()
	var actions := ai.take_turn(core)
	_check(not actions.is_empty(), "AI 回合产生了动作")
	_check(String(actions.back().get("type", "")) == "end_turn", "AI 以结束回合收尾")
	_check(core.turn_owner == BattleCoreScript.PLAYER, "AI 回合结束后交还玩家")
	_check(core.winner == -1, "首回合不会误判胜负")

	# 玩家只结束回合、不出牌：AI 应当能独立推进并击杀玩家将军。
	var full := _new_core(424242)
	var guard := 0
	var total_ai_actions := 0
	while full.winner < 0 and guard < 100:
		if full.turn_owner == BattleCoreScript.PLAYER:
			full.end_turn()
		else:
			var turn_ai := BattleAIScript.new()
			var turn_actions := turn_ai.take_turn(full)
			total_ai_actions += turn_actions.size()
		guard += 1
	_check(full.winner == BattleCoreScript.AI, "AI 能完整打完一局并获胜（%d 个动作）" % total_ai_actions)


func _test_general_death() -> void:
	print("— 胜负 —")
	var core := _new_core(15)
	var player_general := core.general_unit(BattleCoreScript.PLAYER)
	core.damage_unit(int(player_general["uid"]), 20, "测试：击杀玩家将军")
	_check(core.winner == BattleCoreScript.AI, "玩家将军死亡 -> AI 胜")
	_check(core.general_hp(BattleCoreScript.PLAYER) == 0, "将军血量为 0")
	_check(core.general_unit(BattleCoreScript.PLAYER).is_empty(), "将军单位被移除")
	_check(core.end_turn().get("type", "") == "none", "胜负已分后不能继续换回合")
	_check(core.play_unit(BattleCoreScript.PLAYER, 0, Vector2i(3, 4)).is_empty(), "胜负已分后不能出牌")

	var core2 := _new_core(16)
	core2.turn_owner = BattleCoreScript.PLAYER
	core2.mana[0] = 9
	core2.general_unit(BattleCoreScript.AI)["hp"] = 2
	var assassin_uid := core2.debug_spawn("f1_silverguardsquire", BattleCoreScript.PLAYER, Vector2i(4, 1))
	core2.find_unit(assassin_uid)["atk"] = 20
	core2.find_unit(assassin_uid)["can_attack"] = true
	var lethal := core2.attack(assassin_uid, int(core2.general_uids[BattleCoreScript.AI]))
	_check(not lethal.is_empty() and core2.winner == BattleCoreScript.PLAYER, "攻击击杀敌方将军 -> 玩家胜")


func _test_seed_reproducibility() -> void:
	print("— 复现 —")
	var first := _play_scripted(777)
	var second := _play_scripted(777)
	_check(first == second, "同 seed + 同操作 -> fingerprint 完全一致")
	var other := _play_scripted(778)
	_check(first != other, "不同 seed -> 初始状态/牌序不同")


func _play_scripted(seed_value: int) -> String:
	var core := _new_core(seed_value)
	var ai := BattleAIScript.new()
	for _round in range(4):
		var guard := 0
		while guard < 12:
			var played := false
			for i in core.hands[BattleCoreScript.PLAYER].size():
				var card := core.hand_card(BattleCoreScript.PLAYER, i)
				if card.get("type", "") != "unit":
					continue
				var tiles := core.get_summon_tiles(BattleCoreScript.PLAYER)
				if tiles.is_empty():
					continue
				if core.can_play_unit(BattleCoreScript.PLAYER, i, tiles[0]):
					core.play_unit(BattleCoreScript.PLAYER, i, tiles[0])
					played = true
					break
			if not played:
				break
			guard += 1
		core.end_turn()
		ai.begin_turn(core)
		ai.take_turn(core)
		if core.winner >= 0:
			break
	return core.fingerprint()
