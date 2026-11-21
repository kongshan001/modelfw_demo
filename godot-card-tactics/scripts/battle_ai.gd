class_name BattleAI
extends RefCounted

const BattleCoreScript = preload("res://scripts/battle_core.gd")

# 简单 AI：出牌 → 走位 → 攻击 → 结束回合。
# 每个 next_action() 只执行一个动作，UI 可以按节奏播放；take_turn() 同步跑完一回合给测试用。
# 所有排序都有确定性的第二关键字，因此同 seed + 同玩家操作 => 同对局。

const OWNER := BattleCoreScript.AI

var phase := 0
var active := false
var _move_skipped := {}
var _play_skipped := {}
var _action_count := 0


func begin_turn(_core: BattleCoreScript) -> void:
	phase = 0
	active = true
	_move_skipped.clear()
	_play_skipped.clear()
	_action_count = 0


func next_action(core: BattleCoreScript) -> Dictionary:
	if not active or core.winner >= 0 or core.turn_owner != OWNER:
		return {"type": "none"}
	_action_count += 1
	if _action_count > 120:
		return _end_turn(core)

	if phase == 0:
		var play := _try_play(core)
		if not play.is_empty():
			return play
		phase = 1
	if phase == 1:
		var move := _try_move(core)
		if not move.is_empty():
			return move
		phase = 2
	if phase == 2:
		var attack := _try_attack(core)
		if not attack.is_empty():
			return attack
		phase = 3
	return _end_turn(core)


func take_turn(core: BattleCoreScript) -> Array[Dictionary]:
	begin_turn(core)
	var actions: Array[Dictionary] = []
	for _i in range(120):
		var action := next_action(core)
		if action.is_empty() or action.get("type", "") == "none":
			break
		actions.append(action)
		if action.get("type", "") == "end_turn" or core.winner >= 0:
			break
	return actions


func _end_turn(core: BattleCoreScript) -> Dictionary:
	active = false
	return core.end_turn()


func _try_play(core: BattleCoreScript) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for i in core.hands[OWNER].size():
		var card := core.hand_card(OWNER, i)
		if card.is_empty() or int(card.get("cost", 99)) > core.mana[OWNER]:
			continue
		if _play_skipped.has(card["id"]):
			continue
		if card.get("type", "") == "unit":
			var tile := _best_summon_tile(core, card)
			if tile.x >= 0:
				var score := 20.0 + int(card["cost"]) * 3.0
				for keyword in card.get("keywords", []):
					match String(keyword):
						"provoke": score += 6.0
						"ranged": score += 4.0
						"rush": score += 5.0
				if int(card.get("opening_heal", 0)) > 0:
					score += 4.0
				score += _tile_score(core, tile) * 0.4
				candidates.append({
					"score": score, "kind": "unit", "index": i, "pos": tile,
					"id": card["id"], "cost": int(card["cost"]),
				})
		elif card.get("type", "") == "spell":
			var target := _best_spell_target(core, card)
			if int(target.get("uid", -1)) >= 0:
				candidates.append({
					"score": float(target.get("score", 0.0)), "kind": "spell",
					"index": i, "target": int(target["uid"]), "id": card["id"],
					"cost": int(card["cost"]),
				})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(a["score"], b["score"]):
			if a["cost"] == b["cost"]:
				return String(a["id"]) < String(b["id"])
			return a["cost"] > b["cost"]
		return a["score"] > b["score"])
	var best: Dictionary = candidates[0]
	var result := {}
	if best["kind"] == "unit":
		result = core.play_unit(OWNER, best["index"], best["pos"])
	else:
		result = core.cast_spell(OWNER, best["index"], best["target"])
	if result.is_empty():
		_play_skipped[best["id"]] = true
	return result


func _best_summon_tile(core: BattleCoreScript, card: Dictionary) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	var rush: bool = "rush" in card.get("keywords", [])
	for tile in core.get_summon_tiles(OWNER):
		var score := _tile_score(core, tile)
		if rush:
			# 疾行单位落地即可攻击：优先找能打人的格子。
			var targets := _targets_from_card(core, card, tile)
			if not targets.is_empty():
				score += 35.0
		if score > best_score:
			best_score = score
			best = tile
	return best


func _tile_score(core: BattleCoreScript, tile: Vector2i) -> float:
	var player_general := core.general_unit(BattleCoreScript.PLAYER)
	var general_pos := Vector2i(4, 4)
	if not player_general.is_empty():
		general_pos = Vector2i(player_general["x"], player_general["y"])
	var dist := absi(tile.x - general_pos.x) + absi(tile.y - general_pos.y)
	var score := -float(dist) * 3.0 - float(tile.y) * 0.5
	for unit in core.units:
		if int(unit["owner"]) == OWNER:
			continue
		if absi(tile.x - int(unit["x"])) + absi(tile.y - int(unit["y"])) == 1:
			score -= 5.0
	return score


func _targets_from_card(core: BattleCoreScript, card: Dictionary, pos: Vector2i) -> Array[int]:
	# 只有一个格子的“假设攻击位”评估；不修改棋盘。
	var out: Array[int] = []
	var ranged: bool = "ranged" in card.get("keywords", [])
	for other in core.units:
		if int(other["owner"]) == OWNER:
			continue
		var tpos := Vector2i(other["x"], other["y"])
		if ranged:
			var dx := tpos.x - pos.x
			var dy := tpos.y - pos.y
			if (dx == 0) == (dy == 0):
				continue
			if absi(dx) + absi(dy) > 2:
				continue
		elif absi(tpos.x - pos.x) + absi(tpos.y - pos.y) != 1:
			continue
		out.append(int(other["uid"]))
	return out


func _best_spell_target(core: BattleCoreScript, card: Dictionary) -> Dictionary:
	var effect := String(card.get("effect", ""))
	var amount := int(card.get("amount", 0))
	var best: Dictionary = {}
	var best_score := -INF
	var required := String(card.get("target", ""))
	for unit in core.units:
		var owner := int(unit["owner"])
		var valid := false
		match required:
			"friendly_any": valid = owner == OWNER
			"friendly_minion": valid = owner == OWNER and not unit["is_general"]
			"enemy_minion": valid = owner != OWNER and not unit["is_general"]
			"enemy_any": valid = owner != OWNER
		if not valid:
			continue
		var score := -INF
		match effect:
			"damage":
				var hp := int(unit["hp"])
				var kills := amount >= hp
				score = 50.0 + float(unit["atk"]) * 5.0
				if kills:
					score += 40.0
				if unit["is_general"]:
					score = 90.0 + (60.0 if kills else 0.0) + float(amount) * 4.0
					if kills:
						score = 1000.0
			"heal":
				var missing := int(unit["max_hp"]) - int(unit["hp"])
				if missing < 2:
					continue
				score = 30.0 + float(mini(missing, amount)) * 3.0
				if unit["is_general"]:
					score += 20.0
			"buff_attack":
				score = 35.0 + float(unit["atk"]) * 3.0
		if score > best_score:
			best_score = score
			best = {"uid": int(unit["uid"]), "score": score}
	return best


func _try_move(core: BattleCoreScript) -> Dictionary:
	for unit in core.units_of(OWNER):
		var uid := int(unit["uid"])
		if not unit["can_move"] or _move_skipped.has(uid):
			continue
		# 当前就能打到人，先留着攻击。
		if unit["can_attack"] and not core.get_attack_targets(uid).is_empty():
			_move_skipped[uid] = true
			continue
		var current := Vector2i(unit["x"], unit["y"])
		var best_pos := current
		var best_score := _move_score(core, unit, current)
		var candidates: Array[Vector2i] = []
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.x >= BattleCoreScript.BOARD_W or next.y < 0 or next.y >= BattleCoreScript.BOARD_H:
				continue
			if not core.unit_at(next).is_empty():
				continue
			candidates.append(next)
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			if a.y == b.y:
				return a.x < b.x
			return a.y < b.y)
		for pos in candidates:
			var score := _move_score(core, unit, pos)
			if score > best_score:
				best_score = score
				best_pos = pos
		if best_pos == current:
			_move_skipped[uid] = true
			continue
		var result := core.move_unit(uid, best_pos)
		if not result.is_empty():
			return result
		_move_skipped[uid] = true
	return {}


func _move_score(core: BattleCoreScript, unit: Dictionary, pos: Vector2i) -> float:
	var uid := int(unit["uid"])
	var score := 0.0
	var player_general := core.general_unit(BattleCoreScript.PLAYER)
	var general_pos := Vector2i(4, 4)
	if not player_general.is_empty():
		general_pos = Vector2i(player_general["x"], player_general["y"])
	var dist := absi(pos.x - general_pos.x) + absi(pos.y - general_pos.y)
	score -= float(dist) * 4.0
	var targets := core.get_attack_targets_at(uid, pos)
	if not targets.is_empty():
		score += 60.0
		for target_uid in targets:
			var target := core.find_unit(target_uid)
			if target.is_empty():
				continue
			if target["is_general"]:
				score += 14.0
			if int(unit["atk"]) >= int(target["hp"]):
				score += 10.0
	if unit["is_general"]:
		# 将军不主动脱离后方，除非新位置能攻击。
		score = 200.0 if not targets.is_empty() else score * 0.1
		if pos == Vector2i(unit["x"], unit["y"]):
			score += 1.0
		return score
	if unit["ranged"]:
		var nearest := 99
		for enemy in core.units:
			if int(enemy["owner"]) == OWNER:
				continue
			nearest = mini(nearest, absi(pos.x - int(enemy["x"])) + absi(pos.y - int(enemy["y"])))
		if nearest == 2:
			score += 12.0
		elif nearest <= 1:
			score -= 8.0
	var adjacent_enemies := 0
	for enemy in core.units:
		if int(enemy["owner"]) == OWNER:
			continue
		if absi(pos.x - int(enemy["x"])) + absi(pos.y - int(enemy["y"])) == 1:
			adjacent_enemies += 1
	score -= float(adjacent_enemies) * 6.0
	if pos == Vector2i(unit["x"], unit["y"]):
		score += 2.0
	return score


func _try_attack(core: BattleCoreScript) -> Dictionary:
	var best_attacker := -1
	var best_target := -1
	var best_score := -INF
	for unit in core.units_of(OWNER):
		if not unit["can_attack"]:
			continue
		var uid := int(unit["uid"])
		for target_uid in core.get_attack_targets(uid):
			var target := core.find_unit(target_uid)
			if target.is_empty():
				continue
			var damage := int(unit["atk"])
			var score := 0.0
			if target["is_general"]:
				score = 1000.0 if damage >= int(target["hp"]) else 200.0 + float(damage) * 10.0
			elif damage >= int(target["hp"]):
				score = 180.0 + float(target["atk"]) * 8.0
			else:
				score = 120.0 - float(target["hp"]) * 2.0 + float(target["atk"]) * 5.0
			score += float(damage) * 0.1
			if score > best_score:
				best_score = score
				best_attacker = uid
				best_target = target_uid
	if best_attacker < 0:
		return {}
	return core.attack(best_attacker, best_target)
