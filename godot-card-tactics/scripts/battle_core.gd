class_name BattleCore
extends RefCounted

const CardDBScript = preload("res://scripts/card_db.gd")

# 规则核心：9×5 棋盘、法力/抽牌/召唤/移动/攻击/法术/胜负。
# 不依赖任何节点或画面，headless 冒烟测试和 UI 共用同一套规则。
# 坐标：x 0..8 从左到右，y 0..4 从上到下；AI 将军在 (4,0)，玩家将军在 (4,4)。

const BOARD_W := 9
const BOARD_H := 5
const MANA_CAP := 9
const HAND_LIMIT := 6
const PLAYER := 0
const AI := 1

var db: CardDBScript
var seed_value := 0
var rng := RandomNumberGenerator.new()

var units: Array[Dictionary] = []
var hands: Array = [[], []]
var decks: Array = [[], []]
var mana: Array[int] = [1, 1]
var max_mana: Array[int] = [1, 1]
var started_turns: Array[int] = [0, 0]
var replace_used: Array[bool] = [false, false]
var turn_owner := PLAYER
var winner := -1
var next_uid := 1
var turn_serial := 0
var general_uids: Array[int] = [-1, -1]
var log_lines: Array[String] = []


func _init(db_ref: CardDBScript) -> void:
	db = db_ref


func setup(seed_in: int, player_deck: Array, ai_deck: Array) -> void:
	seed_value = seed_in
	rng.seed = seed_in
	units.clear()
	hands = [[], []]
	decks = [player_deck.duplicate(), ai_deck.duplicate()]
	for owner in [PLAYER, AI]:
		_shuffle(decks[owner])
	mana = [1, 1]
	max_mana = [1, 1]
	started_turns = [0, 0]
	replace_used = [false, false]
	turn_owner = PLAYER
	winner = -1
	next_uid = 1
	turn_serial = 0
	general_uids = [-1, -1]
	log_lines.clear()

	_spawn_general(PLAYER, "f1", Vector2i(4, 4))
	_spawn_general(AI, "f2", Vector2i(4, 0))
	for owner in [PLAYER, AI]:
		draw(owner, 3)
	log_line("对局开始。先手：你。")
	start_turn(PLAYER)


func _shuffle(arr: Array) -> void:
	# 自己实现 Fisher-Yates，确保同 seed 的牌序可复现。
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _spawn_general(owner: int, faction: String, pos: Vector2i) -> void:
	var data := db.general(faction)
	var uid := next_uid
	next_uid += 1
	general_uids[owner] = uid
	units.append({
		"uid": uid,
		"card_id": "general_" + faction,
		"name": data.get("name", "将军"),
		"owner": owner,
		"x": pos.x,
		"y": pos.y,
		"atk": int(data.get("atk", 2)),
		"hp": int(data.get("hp", 20)),
		"max_hp": int(data.get("hp", 20)),
		"ranged": false,
		"provoke": false,
		"rush": false,
		"is_general": true,
		"can_move": true,
		"can_attack": true,
		"opening_heal": 0,
		"faction": data.get("faction", faction),
		"sprite": data.get("sprite", faction + "_general"),
	})


func start_turn(owner: int) -> Array:
	turn_owner = owner
	replace_used[owner] = false
	if started_turns[owner] > 0:
		max_mana[owner] = mini(MANA_CAP, max_mana[owner] + 1)
	mana[owner] = max_mana[owner]
	started_turns[owner] += 1
	turn_serial += 1
	for unit in units:
		if unit["owner"] == owner:
			unit["can_move"] = true
			unit["can_attack"] = true
	var drawn := draw(owner, 1)
	log_line("—— %s的回合 · 法力 %d/%d ——" % [_who(owner), mana[owner], max_mana[owner]])
	return drawn


func end_turn() -> Dictionary:
	if winner >= 0:
		return {"type": "none"}
	var ending := turn_owner
	var drawn: Array = []
	if ending == PLAYER:
		turn_owner = AI
		drawn = start_turn(AI)
	else:
		turn_owner = PLAYER
		drawn = start_turn(PLAYER)
	return {
		"type": "end_turn",
		"ending": ending,
		"turn_owner": turn_owner,
		"drawn": drawn,
	}


func draw(owner: int, count := 1) -> Array:
	var drawn: Array = []
	for _i in count:
		if decks[owner].is_empty():
			log_line("%s的牌库已空。" % _who(owner))
			continue
		var card_id: String = decks[owner].pop_front()
		if hands[owner].size() >= HAND_LIMIT:
			log_line("%s手牌已满，%s 被弃置。" % [_who(owner), _card_name(card_id)])
			continue
		hands[owner].append(card_id)
		drawn.append(card_id)
	return drawn


func replace_card(owner: int, hand_index: int) -> bool:
	if winner >= 0 or owner != turn_owner or replace_used[owner]:
		return false
	if hand_index < 0 or hand_index >= hands[owner].size():
		return false
	var card_id: String = hands[owner][hand_index]
	hands[owner].remove_at(hand_index)
	decks[owner].append(card_id)
	replace_used[owner] = true
	draw(owner, 1)
	log_line("%s换掉了一张手牌。" % _who(owner))
	return true


func hand_card(owner: int, hand_index: int) -> Dictionary:
	if hand_index < 0 or hand_index >= hands[owner].size():
		return {}
	return db.card(hands[owner][hand_index])


func playable_hand_indices(owner: int) -> Array[int]:
	var out: Array[int] = []
	if winner >= 0 or owner != turn_owner:
		return out
	for i in hands[owner].size():
		var card := hand_card(owner, i)
		if not card.is_empty() and int(card.get("cost", 99)) <= mana[owner]:
			out.append(i)
	return out


func get_summon_tiles(owner: int) -> Array[Vector2i]:
	var seen := {}
	for unit in units:
		if unit["owner"] != owner:
			continue
		for neighbor in _neighbors(Vector2i(unit["x"], unit["y"])):
			if unit_at(neighbor).is_empty():
				seen[neighbor] = true
	var tiles: Array[Vector2i] = []
	for pos in seen.keys():
		tiles.append(pos)
	tiles.sort_custom(_sort_pos)
	return tiles


func can_play_unit(owner: int, hand_index: int, pos: Vector2i) -> bool:
	if winner >= 0 or owner != turn_owner:
		return false
	var card := hand_card(owner, hand_index)
	if card.is_empty() or card.get("type", "") != "unit":
		return false
	if mana[owner] < int(card.get("cost", 99)):
		return false
	return pos in get_summon_tiles(owner)


func play_unit(owner: int, hand_index: int, pos: Vector2i) -> Dictionary:
	if not can_play_unit(owner, hand_index, pos):
		return {}
	var card := hand_card(owner, hand_index)
	mana[owner] -= int(card["cost"])
	hands[owner].remove_at(hand_index)
	var uid := _spawn_unit(owner, card, pos)
	var result := {
		"type": "summon",
		"owner": owner,
		"uid": uid,
		"card_id": card["id"],
		"card_name": card["name"],
		"pos": pos,
		"deaths": [],
	}
	log_line("%s召唤了 %s。" % [_who(owner), card["name"]])
	var heal := int(card.get("opening_heal", 0))
	if heal > 0:
		var general := general_unit(owner)
		if not general.is_empty():
			general["hp"] = mini(int(general["max_hp"]), int(general["hp"]) + heal)
			log_line("%s 的登场效果：将军恢复 %d 点生命。" % [card["name"], heal])
	_check_winner()
	return result


func _spawn_unit(owner: int, card: Dictionary, pos: Vector2i) -> int:
	var keywords: Array = card.get("keywords", [])
	var uid := next_uid
	next_uid += 1
	units.append({
		"uid": uid,
		"card_id": card["id"],
		"name": card["name"],
		"owner": owner,
		"x": pos.x,
		"y": pos.y,
		"atk": int(card["atk"]),
		"hp": int(card["hp"]),
		"max_hp": int(card["hp"]),
		"ranged": "ranged" in keywords,
		"provoke": "provoke" in keywords,
		"rush": "rush" in keywords,
		"is_general": false,
		"can_move": true,
		"can_attack": "rush" in keywords,
		"opening_heal": int(card.get("opening_heal", 0)),
		"faction": card.get("faction", "neutral"),
		"sprite": card.get("sprite", ""),
	})
	return uid


# 仅供截图/演示工具摆拍：不扣手牌、不扣法力，单位默认已行动。
func debug_spawn(card_id: String, owner: int, pos: Vector2i) -> int:
	var card := db.card(card_id)
	if card.is_empty():
		return -1
	if not unit_at(pos).is_empty():
		return -1
	var uid := _spawn_unit(owner, card, pos)
	var unit := find_unit(uid)
	if not unit.is_empty():
		unit["can_move"] = false
		unit["can_attack"] = false
	return uid


func get_move_tiles(uid: int) -> Array[Vector2i]:
	var unit := find_unit(uid)
	if unit.is_empty() or winner >= 0 or int(unit["owner"]) != turn_owner or not unit["can_move"]:
		return []
	var tiles: Array[Vector2i] = []
	for pos in _neighbors(Vector2i(unit["x"], unit["y"])):
		if unit_at(pos).is_empty():
			tiles.append(pos)
	tiles.sort_custom(_sort_pos)
	return tiles


func move_unit(uid: int, pos: Vector2i) -> Dictionary:
	if not pos in get_move_tiles(uid):
		return {}
	var unit := find_unit(uid)
	var from := Vector2i(unit["x"], unit["y"])
	unit["x"] = pos.x
	unit["y"] = pos.y
	unit["can_move"] = false
	log_line("%s移动到 %s。" % [unit["name"], _pos_label(pos)])
	return {
		"type": "move",
		"owner": unit["owner"],
		"uid": uid,
		"from": from,
		"to": pos,
	}


func get_attack_targets(uid: int) -> Array[int]:
	var unit := find_unit(uid)
	if unit.is_empty():
		return []
	return get_attack_targets_at(uid, Vector2i(unit["x"], unit["y"]))


# AI 走位评估用：假设单位站在 pos，能打到谁（不修改棋盘）。
func get_attack_targets_at(uid: int, pos: Vector2i) -> Array[int]:
	var unit := find_unit(uid)
	var out: Array[int] = []
	if unit.is_empty() or winner >= 0:
		return out
	if int(unit["owner"]) != turn_owner or not unit["can_attack"]:
		return out
	var ranged: bool = unit["ranged"]
	for other in units:
		if int(other["owner"]) == int(unit["owner"]):
			continue
		var tpos := Vector2i(other["x"], other["y"])
		if ranged:
			if not _ranged_line_clear(pos, tpos):
				continue
		else:
			if _manhattan(pos, tpos) != 1:
				continue
		out.append(int(other["uid"]))
	# 嘲讽：相邻有嘲讽敌人时，攻击目标只能选嘲讽单位。
	var forced: Array[int] = []
	for other in units:
		if int(other["owner"]) == int(unit["owner"]) or not other["provoke"]:
			continue
		if _manhattan(pos, Vector2i(other["x"], other["y"])) == 1:
			forced.append(int(other["uid"]))
	if not forced.is_empty():
		var filtered: Array[int] = []
		for target_uid in out:
			if target_uid in forced:
				filtered.append(target_uid)
		return filtered
	out.sort()
	return out


func attack(attacker_uid: int, target_uid: int) -> Dictionary:
	if not target_uid in get_attack_targets(attacker_uid):
		return {}
	var attacker := find_unit(attacker_uid)
	var target := find_unit(target_uid)
	attacker["can_attack"] = false
	var damage := int(attacker["atk"])
	target["hp"] = int(target["hp"]) - damage
	var result := {
		"type": "attack",
		"owner": attacker["owner"],
		"attacker_uid": attacker_uid,
		"target_uid": target_uid,
		"attacker_name": attacker["name"],
		"target_name": target["name"],
		"damage": damage,
		"target_pos": Vector2i(target["x"], target["y"]),
		"attacker_pos": Vector2i(attacker["x"], attacker["y"]),
		"deaths": [],
	}
	log_line("%s 对 %s 造成 %d 点伤害。" % [attacker["name"], target["name"], damage])
	if int(target["hp"]) <= 0:
		_kill_unit(target, result["deaths"])
	_check_winner()
	return result


func can_cast(owner: int, hand_index: int, target_uid: int) -> bool:
	if winner >= 0 or owner != turn_owner:
		return false
	var card := hand_card(owner, hand_index)
	if card.is_empty() or card.get("type", "") != "spell":
		return false
	if mana[owner] < int(card.get("cost", 99)):
		return false
	return _valid_spell_target(owner, card, target_uid)


func _valid_spell_target(owner: int, card: Dictionary, target_uid: int) -> bool:
	var target := find_unit(target_uid)
	if target.is_empty():
		return false
	match String(card.get("target", "")):
		"friendly_any":
			return int(target["owner"]) == owner
		"friendly_minion":
			return int(target["owner"]) == owner and not target["is_general"]
		"enemy_minion":
			return int(target["owner"]) != owner and not target["is_general"]
		"enemy_any":
			return int(target["owner"]) != owner
		_:
			return false


func cast_spell(owner: int, hand_index: int, target_uid: int) -> Dictionary:
	if not can_cast(owner, hand_index, target_uid):
		return {}
	var card := hand_card(owner, hand_index)
	var target := find_unit(target_uid)
	mana[owner] -= int(card["cost"])
	hands[owner].remove_at(hand_index)
	var result := {
		"type": "spell",
		"owner": owner,
		"card_id": card["id"],
		"card_name": card["name"],
		"target_uid": target_uid,
		"target_pos": Vector2i(target["x"], target["y"]),
		"effect": card.get("effect", ""),
		"amount": int(card.get("amount", 0)),
		"deaths": [],
	}
	match String(card.get("effect", "")):
		"heal":
			var before := int(target["hp"])
			target["hp"] = mini(int(target["max_hp"]), before + int(card.get("amount", 0)))
			result["healed"] = int(target["hp"]) - before
			log_line("%s 使用 %s，%s 恢复 %d 点生命。" % [
				_who(owner), card["name"], target["name"], result["healed"]])
		"damage":
			var amount := int(card.get("amount", 0))
			target["hp"] = int(target["hp"]) - amount
			result["damage"] = amount
			log_line("%s 使用 %s，对 %s 造成 %d 点伤害。" % [
				_who(owner), card["name"], target["name"], amount])
			if int(target["hp"]) <= 0:
				_kill_unit(target, result["deaths"])
		"buff_attack":
			var amount := int(card.get("amount", 0))
			target["atk"] = int(target["atk"]) + amount
			result["attack_buff"] = amount
			log_line("%s 使用 %s，%s 获得 +%d 攻击。" % [
				_who(owner), card["name"], target["name"], amount])
	_check_winner()
	return result


func damage_unit(uid: int, amount: int, reason := "") -> Dictionary:
	var target := find_unit(uid)
	if target.is_empty():
		return {}
	target["hp"] = int(target["hp"]) - amount
	var result := {
		"type": "damage",
		"target_uid": uid,
		"damage": amount,
		"deaths": [],
		"owner": target["owner"],
		"target_name": target["name"],
	}
	if int(target["hp"]) <= 0:
		_kill_unit(target, result["deaths"])
	_check_winner()
	if not reason.is_empty():
		log_line(reason)
	return result


func _kill_unit(unit: Dictionary, deaths: Array) -> void:
	deaths.append({
		"uid": unit["uid"],
		"name": unit["name"],
		"owner": unit["owner"],
		"card_id": unit["card_id"],
		"x": unit["x"],
		"y": unit["y"],
		"is_general": unit["is_general"],
		"sprite": unit["sprite"],
	})
	log_line("%s 被消灭。" % unit["name"])
	units.erase(unit)


func _check_winner() -> void:
	if winner >= 0:
		return
	var p := general_unit(PLAYER)
	var a := general_unit(AI)
	if p.is_empty() and a.is_empty():
		winner = -1
	elif p.is_empty():
		winner = AI
		log_line("你的将军倒下了。")
	elif a.is_empty():
		winner = PLAYER
		log_line("对手的将军倒下了。")
	elif int(p["hp"]) <= 0:
		winner = AI
	elif int(a["hp"]) <= 0:
		winner = PLAYER


func general_unit(owner: int) -> Dictionary:
	var uid := general_uids[owner]
	if uid < 0:
		return {}
	return find_unit(uid)


func general_hp(owner: int) -> int:
	var general := general_unit(owner)
	return int(general.get("hp", 0))


func find_unit(uid: int) -> Dictionary:
	for unit in units:
		if int(unit["uid"]) == uid:
			return unit
	return {}


func unit_at(pos: Vector2i) -> Dictionary:
	for unit in units:
		if int(unit["x"]) == pos.x and int(unit["y"]) == pos.y:
			return unit
	return {}


func units_of(owner: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for unit in units:
		if int(unit["owner"]) == owner:
			out.append(unit)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["uid"]) < int(b["uid"]))
	return out


func fingerprint() -> String:
	var unit_rows: Array = []
	var sorted_units := units.duplicate()
	sorted_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["uid"]) < int(b["uid"]))
	for unit in sorted_units:
		unit_rows.append([
			unit["uid"], unit["owner"], unit["card_id"], unit["x"], unit["y"],
			unit["atk"], unit["hp"], unit["can_move"], unit["can_attack"],
		])
	return JSON.stringify({
		"seed": seed_value,
		"turn_owner": turn_owner,
		"mana": mana,
		"max_mana": max_mana,
		"started_turns": started_turns,
		"replace_used": replace_used,
		"winner": winner,
		"next_uid": next_uid,
		"hands": hands,
		"decks": decks,
		"units": unit_rows,
	})


func log_line(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 80:
		log_lines.remove_at(0)


func _who(owner: int) -> String:
	return "你" if owner == PLAYER else "对手"


func _card_name(card_id: String) -> String:
	var card := db.card(card_id)
	return card.get("name", card_id)


func _neighbors(pos: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var next: Vector2i = pos + offset
		if next.x >= 0 and next.x < BOARD_W and next.y >= 0 and next.y < BOARD_H:
			out.append(next)
	return out


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _ranged_line_clear(from: Vector2i, to: Vector2i) -> bool:
	var dx := to.x - from.x
	var dy := to.y - from.y
	if dx != 0 and dy != 0:
		return false
	var dist := absi(dx) + absi(dy)
	if dist < 1 or dist > 2:
		return false
	if dist == 2:
		var mid := Vector2i(from.x + int(dx * 0.5), from.y + int(dy * 0.5))
		if not unit_at(mid).is_empty():
			return false
	return true


func _sort_pos(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y


func _pos_label(pos: Vector2i) -> String:
	return "(%d,%d)" % [pos.x + 1, pos.y + 1]
