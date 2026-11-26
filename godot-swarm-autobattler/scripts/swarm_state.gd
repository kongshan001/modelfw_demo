class_name SwarmGameState
extends RefCounted

## 单局状态：金币、商店、升本、三合一、7 格编队、英雄血量、贪婪潮、阵容码。
## 纯逻辑，不知道 UI；主场景根据 phase 切换表现。

const Cards = preload("res://scripts/swarm_cards.gd")
const Roster = preload("res://scripts/swarm_roster.gd")
const Battle = preload("res://scripts/swarm_battle.gd")

const PLAYER_HP := 30
const AI_HP := 20
const AI_COUNT := 3
const START_GOLD := 10
const INCOME_BASE := 6
const INTEREST_CAP := 3
const GREED_MAX := Cards.MAX_GREED
const GREED_ALLY_STEP := 0.15
const GREED_ENEMY_STEP := 0.30
const GREED_GOLD := 2

var run_seed := 0
var round_no := 1
var gold := START_GOLD
var level := 2
var greed := 0
var flood := false
var board: Array = []
var shop: Array = []
var rerolls := 0
var heroes: Array = []
var phase := "shop" # shop / battle / result / gameover
var selected := -1
var last_win := false
var training := false
var last_result: Dictionary = {}
var pending_damage := 0
var pending_target := ""
var saved_code := ""
var battle_seed := 0
var battle = null
var encounter_cards: Array = []
var encounter_label := ""
var encounter_index := -1
var encounter_mirror := false
var encounter_scale := 1.0
var log_lines: Array[String] = []
var final_outcome := ""
var stats_battles := 0
var stats_wins := 0
var stats_units_deployed := 0
var stats_peak_units := 0
var stats_rounds_won := 0


func new_run(seed: int = 0) -> void:
	run_seed = seed if seed != 0 else int(Time.get_ticks_usec() & 0x7fffffff)
	round_no = 1
	gold = START_GOLD
	level = 2
	greed = 0
	flood = false
	board.clear()
	shop.clear()
	rerolls = 0
	phase = "shop"
	selected = -1
	last_win = false
	training = false
	last_result = {}
	pending_damage = 0
	pending_target = ""
	saved_code = ""
	battle_seed = 0
	battle = null
	encounter_cards = []
	encounter_label = ""
	encounter_index = -1
	encounter_mirror = false
	encounter_scale = 1.0
	log_lines = []
	final_outcome = ""
	stats_battles = 0
	stats_wins = 0
	stats_units_deployed = 0
	stats_peak_units = 0
	stats_rounds_won = 0
	heroes = [
		{"name": "蔚蓝铸巢", "short": "蔚蓝", "hp": PLAYER_HP, "max_hp": PLAYER_HP, "color": Color("#35e0c8"), "you": true},
		{"name": "赤锈议会", "short": "赤锈", "hp": AI_HP, "max_hp": AI_HP, "color": Color("#ff6248"), "you": false},
		{"name": "苍盐苗圃", "short": "苍盐", "hp": AI_HP, "max_hp": AI_HP, "color": Color("#b8a6ff"), "you": false},
		{"name": "黄铜残响", "short": "黄铜", "hp": AI_HP, "max_hp": AI_HP, "color": Color("#f0b45a"), "you": false},
	]
	_roll_shop()
	_log("第 1 回合 · 铸巢点火。购买编队，或先追一次贪婪潮。")


func _rng_for(tag: String, n: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var s := run_seed ^ (round_no * 7919) ^ (n * 104729) ^ tag.hash()
	rng.seed = absi(s) + 1
	return rng


func _roll_shop() -> void:
	shop = Cards.roll_shop(_rng_for("shop", rerolls), level, Cards.SHOP_SIZE)


func _log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 12:
		log_lines.pop_front()


func refresh_shop() -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "现在不在铸巢阶段"}
	if gold < 1:
		return {"ok": false, "msg": "金币不足，刷新需要 1"}
	gold -= 1
	rerolls += 1
	_roll_shop()
	_log("刷新商店（-1◆）。")
	return {"ok": true, "msg": "商店已刷新"}


func buy_slot(index: int) -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "战斗中不能购买"}
	if index < 0 or index >= shop.size():
		return {"ok": false, "msg": "无效的商店格"}
	var id := String(shop[index])
	if id.is_empty():
		return {"ok": false, "msg": "这一格已经买空了"}
	var card := Cards.get_card(id)
	if card.is_empty():
		return {"ok": false, "msg": "未知卡牌"}
	var cost := int(card["cost"])
	if gold < cost:
		return {"ok": false, "msg": "金币不足，需要 %d" % cost}
	var copies: Array[int] = []
	for i in board.size():
		var e: Dictionary = board[i]
		if String(e["id"]) == id and int(e["star"]) == 1:
			copies.append(i)
	var can_merge := copies.size() >= 2
	if not can_merge and board.size() >= Cards.BOARD_MAX:
		return {"ok": false, "msg": "上场已满 7 格；出售单位或凑三合一"}
	gold -= cost
	shop[index] = ""
	selected = -1
	if can_merge:
		var first := mini(copies[0], copies[1])
		var remove_hi := maxi(copies[0], copies[1])
		board.remove_at(remove_hi)
		board.remove_at(mini(first, board.size() - 1))
		board.insert(mini(first, board.size()), {"id": id, "star": 2})
		var msg := "三合一！%s 升为金卡 ★★，单位与数值 ×2" % String(card["name"])
		_log(msg)
		return {"ok": true, "msg": msg, "combined": true, "gold": gold}
	var unit_msg := "入手 %s（%s 编队）。" % [String(card["name"]), Cards.role_label(card)]
	board.append({"id": id, "star": 1})
	_log(unit_msg)
	return {"ok": true, "msg": unit_msg, "combined": false, "gold": gold}


func sell_card(index: int) -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "战斗中不能出售"}
	if index < 0 or index >= board.size():
		return {"ok": false, "msg": "没有选中单位"}
	var entry: Dictionary = board[index]
	var refund := Cards.sell_value(entry)
	var card := Cards.get_card(String(entry["id"]))
	board.remove_at(index)
	gold += refund
	selected = -1
	var msg := "出售 %s，返还 %d◆。" % [String(card.get("name", "单位")), refund]
	_log(msg)
	return {"ok": true, "msg": msg, "refund": refund}


func level_up() -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "现在不在铸巢阶段"}
	if level >= Cards.MAX_LEVEL:
		return {"ok": false, "msg": "熔炉已满级 Lv.6"}
	var cost := Cards.level_cost(level)
	if cost < 0:
		return {"ok": false, "msg": "无法继续升级"}
	if gold < cost:
		return {"ok": false, "msg": "金币不足，升本需要 %d" % cost}
	gold -= cost
	level += 1
	_log("熔炉升到 Lv.%d，高星卡出现率提高（- %d◆）。" % [level, cost])
	return {"ok": true, "msg": "熔炉 Lv.%d" % level}


func add_greed() -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "战斗中不能追潮"}
	if greed >= GREED_MAX:
		return {"ok": false, "msg": "贪婪潮已到 5 层上限"}
	greed += 1
	gold += GREED_GOLD
	_log("贪婪潮 +1（Lv.%d）：双方编队变大，立即 +%d◆。" % [greed, GREED_GOLD])
	return {"ok": true, "msg": "贪婪潮 Lv.%d" % greed}


func toggle_flood() -> Dictionary:
	flood = not flood
	if flood:
		_log("洪流协议 ×100 开启。下一场战斗双方编队放大 100 倍（每边上限 %s）。" % Cards.format_units(Cards.UNIT_CAP_PER_SIDE))
	else:
		_log("洪流协议关闭，回到常规编队。")
	return {"ok": true, "flood": flood}


func get_ally_greed_mult() -> float:
	return 1.0 + GREED_ALLY_STEP * float(greed)


func get_enemy_greed_mult() -> float:
	return 1.0 + GREED_ENEMY_STEP * float(greed)


## 洪流 ×100 会把双方都压到每边 1500；此时贪婪潮的数量增幅会被上限吃掉。
## 为了让风险仍然成立，洪流封顶时把敌方的贪婪溢出转成每层 +6% HP/ATK。
func enemy_stat_multiplier() -> float:
	if flood and greed > 0:
		return 1.0 + 0.06 * float(greed)
	return 1.0


func ally_unit_counts() -> Array:
	return Cards.allocate_units(board, get_ally_greed_mult(), flood, Cards.UNIT_CAP_PER_SIDE, 1.0)


func ally_unit_total() -> int:
	return Cards.squad_total(board, get_ally_greed_mult(), flood, Cards.UNIT_CAP_PER_SIDE, 1.0)


func alive_ai_indices() -> Array:
	var out: Array = []
	for i in range(1, heroes.size()):
		if int(heroes[i]["hp"]) > 0:
			out.append(i)
	return out


func next_opponent_index() -> int:
	var alive := alive_ai_indices()
	if alive.is_empty():
		return -1
	return int(alive[(round_no - 1) % alive.size()])


func _build_ai_encounter() -> Dictionary:
	var idx := next_opponent_index()
	if idx < 0:
		return {"cards": [], "label": "无", "index": -1, "scale": 1.0}
	var rng := _rng_for("ai_roster", idx * 31)
	var cards := Cards.roll_ai_roster(rng, round_no)
	var scale := minf(1.55, 1.0 + 0.06 * float(round_no - 1))
	return {
		"cards": cards,
		"label": String(heroes[idx]["name"]),
		"index": idx,
		"scale": scale,
	}


func preview_snapshot() -> Dictionary:
	var enc := _build_ai_encounter()
	return {
		"ally_cards": board.duplicate(true),
		"enemy_cards": enc["cards"],
		"ally_label": "蔚蓝铸群",
		"enemy_label": enc["label"],
		"ally_greed": get_ally_greed_mult(),
		"enemy_greed": get_enemy_greed_mult(),
		"flood": flood,
		"cap": Cards.UNIT_CAP_PER_SIDE,
		"ally_scale": 1.0,
		"enemy_scale": enc["scale"],
		"seed": absi(run_seed ^ (round_no * 3571)) + 11,
	}


func make_preview_battle():
	var snap := preview_snapshot()
	var b = Battle.new()
	b.setup(snap["ally_cards"], snap["enemy_cards"], {
		"seed": snap["seed"],
		"ally_greed": snap["ally_greed"],
		"enemy_greed": snap["enemy_greed"],
		"flood": snap["flood"],
		"cap": snap["cap"],
		"ally_scale": snap["ally_scale"],
		"enemy_scale": snap["enemy_scale"],
		"ally_label": snap["ally_label"],
		"enemy_label": snap["enemy_label"],
		"fx": false,
	})
	return b


func start_battle(with_training: bool = false) -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "现在不能开战"}
	if board.is_empty():
		return {"ok": false, "msg": "至少上场 1 个单位"}
	var enemy_cards: Array = []
	var enemy_label := ""
	var target_idx := -1
	var scale := 1.0
	var mirror := false
	if with_training:
		var decoded: Dictionary = Roster.decode(saved_code) if not saved_code.is_empty() else {"ok": false}
		if bool(decoded.get("ok", false)):
			enemy_cards = decoded["cards"].duplicate(true)
			enemy_label = "镜像试炼 · 已保存编队"
		else:
			var enc := _build_ai_encounter()
			enemy_cards = enc["cards"].duplicate(true)
			enemy_label = "镜像试炼 · 内置 AI"
			scale = 1.0
		mirror = true
	else:
		var enc := _build_ai_encounter()
		if enc["index"] < 0:
			return {"ok": false, "msg": "所有对手都已被击败"}
		enemy_cards = enc["cards"].duplicate(true)
		enemy_label = String(enc["label"])
		target_idx = int(enc["index"])
		scale = float(enc["scale"])
		saved_code = export_code()
	battle_seed = absi(run_seed ^ (round_no * 9157) ^ (target_idx * 3571) ^ (1 if mirror else 0)) + 97
	var ally_greed := get_ally_greed_mult()
	var enemy_greed := ally_greed if mirror else get_enemy_greed_mult()
	var b = Battle.new()
	b.setup(board, enemy_cards, {
		"seed": battle_seed,
		"ally_greed": ally_greed,
		"enemy_greed": enemy_greed,
		"flood": flood,
		"cap": Cards.UNIT_CAP_PER_SIDE,
		"ally_scale": 1.0,
		"enemy_scale": scale,
		"enemy_stat_mult": 1.0 if mirror else enemy_stat_multiplier(),
		"ally_label": "蔚蓝铸群",
		"enemy_label": enemy_label.split(" · ")[0] if enemy_label.begins_with("镜像") else enemy_label,
		"fx": true,
	})
	if b.side_count[0] <= 0:
		return {"ok": false, "msg": "编队生成失败"}
	battle = b
	training = with_training
	encounter_cards = enemy_cards
	encounter_label = enemy_label
	encounter_index = target_idx
	encounter_mirror = mirror
	encounter_scale = scale
	phase = "battle"
	selected = -1
	last_result = {}
	pending_damage = 0
	pending_target = ""
	stats_battles += 1
	stats_units_deployed += b.side_count[0]
	stats_peak_units = maxi(stats_peak_units, b.side_count[0])
	var label := "镜像试炼" if mirror else "第 %d 回合" % round_no
	_log("%s：%s vs %s（%s vs %s 单位）。" % [
		label, "蔚蓝铸群", enemy_label,
		Cards.format_units(b.side_count[0]), Cards.format_units(b.side_count[1])])
	return {"ok": true, "msg": "战斗开始", "battle": b}


func finish_battle(result: Dictionary) -> Dictionary:
	if phase != "battle" or battle == null:
		return {"ok": false, "msg": "没有进行中的战斗"}
	last_result = result.duplicate(true)
	last_result["training"] = training
	pending_damage = 0
	pending_target = ""
	if training:
		phase = "result"
		if int(result.get("winner", 2)) == 0:
			_log("镜像试炼胜利。试炼不改变英雄血量与回合。")
		elif int(result.get("winner", 2)) == 1:
			_log("镜像试炼失败。试炼不改变英雄血量与回合。")
		else:
			_log("镜像试炼平局。")
		return {"ok": true, "phase": phase}
	var winner := int(result.get("winner", 2))
	var surviving: Array = result.get("surviving_cards", [0, 0])
	var opp := encounter_index
	if winner == 0:
		last_win = true
		stats_wins += 1
		stats_rounds_won += 1
		var dmg := 2 + int(surviving[0])
		_hurt_hero(opp, dmg)
		pending_damage = dmg
		pending_target = String(heroes[opp]["name"])
		_log("我方获胜，%s -%d HP。" % [pending_target, dmg])
	elif winner == 1:
		last_win = false
		var dmg := 2 + int(surviving[1])
		_hurt_hero(0, dmg)
		pending_damage = dmg
		pending_target = "蔚蓝铸巢"
		_log("我方战败，蔚蓝铸巢 -%d HP。" % dmg)
	else:
		last_win = false
		_hurt_hero(0, 2)
		_hurt_hero(opp, 2)
		pending_damage = 2
		pending_target = "双方"
		_log("平局，双方各 -2 HP。")
	_ai_attrition(opp)
	if int(heroes[0]["hp"]) <= 0:
		final_outcome = "defeat"
		phase = "gameover"
		_log("铸巢熄灭。最终回合：%d。按 R 重开。" % round_no)
	elif alive_ai_indices().is_empty():
		final_outcome = "victory"
		phase = "gameover"
		_log("全部对手熄灭。群铸完成，潮汐归你。")
	else:
		phase = "result"
	return {"ok": true, "phase": phase}


func _hurt_hero(index: int, damage: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	var h: Dictionary = heroes[index]
	h["hp"] = maxi(0, int(h["hp"]) - damage)
	heroes[index] = h


func _ai_attrition(opponent: int) -> void:
	var alive := alive_ai_indices()
	var candidates: Array = []
	for i in alive:
		if i != opponent:
			candidates.append(i)
	if candidates.is_empty():
		return
	var rng := _rng_for("attrition", 3)
	var target := int(candidates[rng.randi_range(0, candidates.size() - 1)])
	var dmg := 1 + rng.randi_range(0, 2)
	_hurt_hero(target, dmg)
	_log("远方战报：%s 与邻巢交火，-%d HP。" % [String(heroes[target]["name"]), dmg])


func continue_after_result() -> Dictionary:
	if phase != "result":
		return {"ok": false, "msg": "当前没有待结算结果"}
	if training:
		training = false
		battle = null
		phase = "shop"
		selected = -1
		last_result = {}
		return {"ok": true, "income": 0, "training": true}
	var interest := mini(INTEREST_CAP, int(gold / 10))
	var income := INCOME_BASE + interest + (1 if last_win else 0)
	gold += income
	round_no += 1
	rerolls = 0
	battle = null
	last_result = {}
	encounter_cards = []
	encounter_label = ""
	encounter_index = -1
	encounter_mirror = false
	encounter_scale = 1.0
	phase = "shop"
	selected = -1
	training = false
	_roll_shop()
	_log("第 %d 回合 · 收入 +%d◆（基础 %d，利息 %d%s）。" % [
		round_no, income, INCOME_BASE, interest, "，胜利 +1" if last_win else ""])
	last_win = false
	return {"ok": true, "income": income, "interest": interest, "round": round_no}


func income_preview() -> Dictionary:
	var interest := mini(INTEREST_CAP, int(gold / 10))
	return {
		"base": INCOME_BASE,
		"interest": interest,
		"win_bonus": 1 if last_win else 0,
		"total": INCOME_BASE + interest + (1 if last_win else 0),
	}


func export_code() -> String:
	return Roster.encode(board, level, greed, flood)


func save_current_code() -> String:
	saved_code = export_code()
	_log("编队已保存为阵容码，可用于镜像试炼。")
	return saved_code


func import_code(code: String) -> Dictionary:
	if phase != "shop":
		return {"ok": false, "msg": "只能在铸巢阶段导入"}
	var decoded := Roster.decode(code)
	if not bool(decoded.get("ok", false)):
		return {"ok": false, "msg": String(decoded.get("msg", "阵容码无效"))}
	board = decoded["cards"].duplicate(true)
	level = int(decoded["level"])
	greed = int(decoded["greed"])
	flood = bool(decoded["flood"])
	saved_code = Roster.encode(board, level, greed, flood)
	selected = -1
	_log("阵容码导入成功：%d 张卡，Lv.%d，贪婪潮 %d。" % [board.size(), level, greed])
	return {"ok": true, "msg": "导入成功", "cards": board.size()}


func selected_sell_value() -> int:
	if selected < 0 or selected >= board.size():
		return 0
	return Cards.sell_value(board[selected])


func state_summary() -> Dictionary:
	var hp: Array = []
	for h in heroes:
		hp.append(int(h["hp"]))
	return {
		"seed": run_seed,
		"round": round_no,
		"gold": gold,
		"level": level,
		"greed": greed,
		"flood": flood,
		"phase": phase,
		"board": board.duplicate(true),
		"shop": shop.duplicate(),
		"ally_units": ally_unit_total(),
		"hero_hp": hp,
		"training": training,
		"saved_code": saved_code,
		"stats_battles": stats_battles,
		"stats_wins": stats_wins,
	}


# ---- 测试/截图工具的确定性钩子（不参与正常玩法） ----

func debug_set_gold(value: int) -> void:
	gold = maxi(0, value)


func debug_set_level(value: int) -> void:
	level = clampi(value, 2, Cards.MAX_LEVEL)


func debug_set_greed(value: int) -> void:
	greed = clampi(value, 0, Cards.MAX_GREED)


func debug_set_round(value: int) -> void:
	round_no = maxi(1, value)


func debug_set_board(cards: Array) -> void:
	board = cards.duplicate(true)
	selected = -1


func debug_set_shop(ids: Array) -> void:
	shop = ids.duplicate()
	while shop.size() < Cards.SHOP_SIZE:
		shop.append("")


func debug_set_hero_hp(index: int, value: int) -> void:
	if index < 0 or index >= heroes.size():
		return
	var h: Dictionary = heroes[index]
	h["hp"] = clampi(value, 0, int(h["max_hp"]))
	heroes[index] = h


func debug_force_victory() -> void:
	for i in range(1, heroes.size()):
		debug_set_hero_hp(i, 0)
	final_outcome = "victory"
	phase = "gameover"


func debug_force_defeat() -> void:
	debug_set_hero_hp(0, 0)
	final_outcome = "defeat"
	phase = "gameover"


func debug_resolve_current_battle() -> Dictionary:
	if battle == null:
		return {"ok": false, "msg": "没有战斗"}
	var result: Dictionary = battle.run_to_end()
	return finish_battle(result)
