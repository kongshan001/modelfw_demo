class_name BattleResolver
extends RefCounted

var state: BattleState
var rng: BattleRng
var content: ContentDB
var events: Array[BattleEvent] = []

var _seq: int = 0
var _speed_rolls: Dictionary = {}

func _init(p_state: BattleState, p_rng: BattleRng, p_content: ContentDB) -> void:
	state = p_state
	rng = p_rng
	content = p_content

func resolve_round(player_intents: Array[BattleIntent]) -> Array[BattleEvent]:
	events = []
	_speed_rolls.clear()
	if state.is_over():
		return events
	state.round += 1
	_roll_speeds()
	var order := _ordered_living()
	var order_ids: Array[String] = []
	for unit in order:
		order_ids.append(String(unit.id))
	_emit(&"round_start", &"", order_ids, {"order": order_ids})
	_tick_round_start_statuses(order)
	_check_end()
	if state.is_over():
		return events
	var flee_requested := _has_flee_intent(player_intents)
	var intents := _validate_player_intents(player_intents, flee_requested)
	for enemy in state.living(BattleTypes.Side.ENEMY):
		intents[enemy.id] = _decide_ai(enemy)
	var actions: Array[BattleIntent] = []
	if flee_requested:
		var chance := compute_flee_chance()
		_emit(&"flee_attempt", &"party", [], {"chance": chance})
		if rng.chance(chance):
			state.outcome = BattleTypes.Outcome.ESCAPED
			_emit(&"flee_result", &"party", [], {"success": true})
			_emit(&"battle_end", &"", [], {"outcome": state.outcome})
			return events
		_emit(&"flee_result", &"party", [], {"success": false})
		for enemy in state.living(BattleTypes.Side.ENEMY):
			if intents.has(enemy.id):
				actions.append(intents[enemy.id])
	else:
		actions = _collect_actions(intents)
	actions.sort_custom(_compare_actions)
	for intent in actions:
		if state.is_over():
			break
		_execute_intent(intent)
		_check_end()
	if not state.is_over():
		_finish_round()
	return events

func _roll_speeds() -> void:
	for unit in state.units:
		if unit.is_alive():
			_speed_rolls[unit.id] = float(unit.data.speed) * rng.randf_range(0.95, 1.05)

func _ordered_living() -> Array[BattleUnitState]:
	var living: Array[BattleUnitState] = []
	for unit in state.living(BattleTypes.Side.ALLY):
		living.append(unit)
	for unit in state.living(BattleTypes.Side.ENEMY):
		living.append(unit)
	living.sort_custom(func(a, b):
		var sa := float(_speed_rolls.get(a.id, 0.0))
		var sb := float(_speed_rolls.get(b.id, 0.0))
		if is_equal_approx(sa, sb):
			return String(a.id) < String(b.id)
		return sa > sb)
	return living

func _validate_player_intents(player_intents: Array[BattleIntent], flee_requested: bool) -> Dictionary:
	var result := {}
	for intent in player_intents:
		var actor := state.get_unit(intent.actor_id)
		if actor == null or actor.side != BattleTypes.Side.ALLY or not actor.is_alive():
			continue
		if _is_valid_intent(actor, intent):
			result[actor.id] = intent
		else:
			_emit(&"intent_rejected", actor.id, intent.target_ids, {"reason": _invalid_reason(actor, intent)})
			result[actor.id] = BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
	if not flee_requested:
		for ally in state.living(BattleTypes.Side.ALLY):
			if not result.has(ally.id):
				_emit(&"intent_rejected", ally.id, [], {"reason": "missing"})
				result[ally.id] = BattleIntent.make(ally.id, BattleTypes.IntentKind.DEFEND)
	return result

func _is_valid_intent(actor: BattleUnitState, intent: BattleIntent) -> bool:
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			if intent.target_ids.size() != 1:
				return false
			var attack_target := state.get_unit(intent.target_ids[0])
			return attack_target != null and attack_target.is_alive() and attack_target.side != actor.side
		BattleTypes.IntentKind.SKILL:
			var skill := content.get_skill(intent.skill_id)
			if skill == null or not actor.data.skills.has(skill.id):
				return false
			if actor.mp < skill.mp_cost:
				return false
			if skill.target_type == SkillData.TargetType.SELF:
				return true
			if intent.target_ids.size() != 1:
				return false
			var skill_target := state.get_unit(intent.target_ids[0])
			if skill_target == null or not skill_target.is_alive():
				return false
			if skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES:
				return skill_target.side == actor.side
			return skill_target.side != actor.side
		BattleTypes.IntentKind.ITEM:
			if intent.target_ids.size() != 1:
				return false
			var item := content.get_item(intent.item_id)
			if item == null or state.item_remaining(item.id) <= 0:
				return false
			var item_target := state.get_unit(intent.target_ids[0])
			return item_target != null and item_target.is_alive() and item_target.side == actor.side
		BattleTypes.IntentKind.DEFEND:
			return true
		_:
			return false

func _invalid_reason(actor: BattleUnitState, intent: BattleIntent) -> String:
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			if intent.target_ids.size() == 1:
				var attack_target := state.get_unit(intent.target_ids[0])
				if attack_target != null and not attack_target.is_alive():
					return "target_dead"
			return "invalid_target"
		BattleTypes.IntentKind.SKILL:
			var skill := content.get_skill(intent.skill_id)
			if skill == null or not actor.data.skills.has(skill.id):
				return "unknown_skill"
			if actor.mp < skill.mp_cost:
				return "mp"
			if intent.target_ids.size() != 1:
				return "invalid_target"
			var skill_target := state.get_unit(intent.target_ids[0])
			if skill_target == null:
				return "invalid_target"
			if not skill_target.is_alive():
				return "target_dead"
			var ally_skill := skill.target_type == SkillData.TargetType.SINGLE_ALLY or skill.target_type == SkillData.TargetType.ALL_ALLIES
			if ally_skill != (skill_target.side == actor.side):
				return "invalid_target"
			return "invalid_target"
		BattleTypes.IntentKind.ITEM:
			var item := content.get_item(intent.item_id)
			if item == null:
				return "unknown_item"
			if state.item_remaining(item.id) <= 0:
				return "item"
			if intent.target_ids.size() != 1:
				return "invalid_target"
			var item_target := state.get_unit(intent.target_ids[0])
			if item_target == null:
				return "invalid_target"
			if not item_target.is_alive():
				return "target_dead"
			return "invalid_target"
	return "unknown_kind"

func _collect_actions(intents: Dictionary) -> Array[BattleIntent]:
	var actions: Array[BattleIntent] = []
	for unit in state.units:
		if unit.is_alive() and intents.has(unit.id):
			actions.append(intents[unit.id])
	return actions

func _compare_actions(a: BattleIntent, b: BattleIntent) -> bool:
	var sa := float(_speed_rolls.get(a.actor_id, 0.0))
	var sb := float(_speed_rolls.get(b.actor_id, 0.0))
	if is_equal_approx(sa, sb):
		return String(a.actor_id) < String(b.actor_id)
	return sa > sb

func _execute_intent(intent: BattleIntent) -> void:
	var actor := state.get_unit(intent.actor_id)
	if actor == null or not actor.is_alive():
		if actor != null:
			_emit(&"action_skipped", actor.id, [], {"reason": "dead"})
		return
	for status in actor.statuses.duplicate():
		if status.data.expires_on_owner_action:
			actor.remove_status(status.data.id)
			_emit(&"status_expire", actor.id, [actor.id], {"status_id": String(status.data.id), "reason": "owner_action"})
	for status in actor.statuses.duplicate():
		if not status.data.skips_action:
			continue
		actor.remove_status(status.data.id)
		_emit(&"action_skipped", actor.id, [actor.id], {"reason": String(status.data.id), "status_id": String(status.data.id)})
		_emit(&"status_expire", actor.id, [actor.id], {"status_id": String(status.data.id), "reason": "skipped"})
		return
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			_execute_attack(actor, intent)
		BattleTypes.IntentKind.SKILL:
			_execute_skill(actor, intent)
		BattleTypes.IntentKind.ITEM:
			_execute_item(actor, intent)
		BattleTypes.IntentKind.DEFEND:
			_execute_defend(actor)
		_:
			_emit(&"intent_rejected", actor.id, [], {"reason": "unsupported"})
			_execute_defend(actor)

func _execute_attack(actor: BattleUnitState, intent: BattleIntent) -> void:
	var target := _resolve_attack_target(actor, intent)
	if target == null:
		_emit(&"action_skipped", actor.id, [], {"reason": "no_target"})
		return
	_emit(&"action_start", actor.id, [target.id], {"kind": "attack"})
	var damage := _compute_damage(actor, target, BattleTypes.DamageType.PHYSICAL, 1.0)
	_apply_damage(actor.id, target, int(damage["amount"]), bool(damage["crit"]), &"attack")

func _resolve_attack_target(actor: BattleUnitState, intent: BattleIntent) -> BattleUnitState:
	if not intent.target_ids.is_empty():
		var target := state.get_unit(intent.target_ids[0])
		if target != null and target.is_alive() and target.side != actor.side:
			return target
	var enemies := state.living_enemies_of(actor)
	if enemies.is_empty():
		return null
	return enemies[rng.randi_range(0, enemies.size() - 1)]

func _compute_damage(source: BattleUnitState, target: BattleUnitState, damage_type: int, power: float) -> Dictionary:
	var base := 0.0
	if damage_type == BattleTypes.DamageType.PHYSICAL:
		base = source.atk_value() * power - target.defense_value() * 0.6
	else:
		base = source.magic_value() * power - target.resistance_value() * 0.5
	base = maxf(1.0, base)
	var variance := rng.randf_range(0.9, 1.1)
	var crit := false
	if source.data.crit_rate > 0.0:
		crit = rng.chance(source.data.crit_rate)
	var crit_multiplier := 1.0
	if crit:
		crit_multiplier = 1.6 if damage_type == BattleTypes.DamageType.PHYSICAL else 1.5
	var amount := maxi(1, roundi(base * variance * crit_multiplier * target.damage_taken_mult()))
	return {"amount": amount, "crit": crit}

func _apply_damage(source_id: StringName, target: BattleUnitState, amount: int, crit: bool, source_type: StringName) -> void:
	var hp_before := target.hp
	target.hp = maxi(0, target.hp - amount)
	_emit(&"damage", source_id, [target.id], {
		"amount": amount,
		"crit": crit,
		"hp_before": hp_before,
		"hp_after": target.hp,
		"source_type": String(source_type),
	})
	if target.hp <= 0 and target.alive:
		target.alive = false
		target.statuses.clear()
		_emit(&"death", source_id, [target.id], {})

func _execute_defend(actor: BattleUnitState) -> void:
	_emit(&"action_start", actor.id, [], {"kind": "defend"})
	var status := content.get_status(&"defending")
	if status == null:
		push_error("Missing status: defending")
		return
	var applied := actor.add_status(status, state.round)
	_emit(&"defend", actor.id, [actor.id], {})
	_emit(&"status_apply" if applied else &"status_refresh", actor.id, [actor.id], {"status_id": "defending"})

func _decide_ai(actor: BattleUnitState) -> BattleIntent:
	var targets := state.living_enemies_of(actor)
	if targets.is_empty():
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
	var profile := actor.data.ai_profile
	if profile == &"brute":
		var war_cry := _owned_skill(actor, &"war_cry")
		if not actor.has_status(&"war_cry") and _can_cast(actor, war_cry):
			return _skill_intent(actor, war_cry.id, [actor.id])
		var ground_split := _owned_skill(actor, &"ground_split")
		if targets.size() >= 2 and _can_cast(actor, ground_split) and rng.chance(0.6):
			return _skill_intent(actor, ground_split.id, [_pick_ai_target(targets).id])
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])
	if profile == &"fox":
		var priority := _priority_allies(targets)
		var seal_target := _first_unsealed(priority)
		var charm_seal := _owned_skill(actor, &"charm_seal")
		if seal_target != null and _can_cast(actor, charm_seal) and rng.chance(0.7):
			return _skill_intent(actor, charm_seal.id, [seal_target.id])
		var fox_fire := _owned_skill(actor, &"fox_fire")
		if _can_cast(actor, fox_fire):
			return _skill_intent(actor, fox_fire.id, [_pick_ai_target(targets).id])
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])
	if profile == &"poison_melee":
		var poison_strike := _owned_skill(actor, &"poison_strike")
		if _can_cast(actor, poison_strike) and rng.chance(0.6):
			return _skill_intent(actor, poison_strike.id, [_pick_ai_target(targets).id])
		return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])
	var skill := _first_castable_skill(actor)
	if skill != null and rng.chance(0.6):
		var target_id := actor.id if skill.target_type == SkillData.TargetType.SELF else _pick_ai_target(targets).id
		return _skill_intent(actor, skill.id, [target_id])
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [_pick_ai_target(targets).id])

func _owned_skill(actor: BattleUnitState, skill_id: StringName) -> SkillData:
	if not actor.data.skills.has(skill_id):
		return null
	return content.get_skill(skill_id)

func _can_cast(actor: BattleUnitState, skill: SkillData) -> bool:
	return skill != null and actor.mp >= skill.mp_cost

func _first_castable_skill(actor: BattleUnitState) -> SkillData:
	for skill_id in actor.data.skills:
		var skill := content.get_skill(skill_id)
		if _can_cast(actor, skill):
			return skill
	return null

func _skill_intent(actor: BattleUnitState, skill_id: StringName, target_ids: Array) -> BattleIntent:
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.SKILL, target_ids, skill_id)

func _priority_allies(candidates: Array[BattleUnitState]) -> Array[BattleUnitState]:
	var healer: BattleUnitState = null
	var mage: BattleUnitState = null
	for candidate in candidates:
		if healer == null and _is_healer(candidate):
			healer = candidate
		elif mage == null and _is_mage(candidate):
			mage = candidate
	var priority: Array[BattleUnitState] = []
	if healer != null:
		priority.append(healer)
	if mage != null:
		priority.append(mage)
	if priority.is_empty():
		priority.append(_lowest_hp(candidates))
	return priority

func _is_healer(unit: BattleUnitState) -> bool:
	for skill_id in unit.data.skills:
		var skill := content.get_skill(skill_id)
		if skill == null:
			continue
		for effect in skill.effects:
			if effect.kind == BattleEffect.Kind.HEAL:
				return true
	return false

func _is_mage(unit: BattleUnitState) -> bool:
	return unit.data.magic > unit.data.atk and not _is_healer(unit)

func _first_unsealed(candidates: Array[BattleUnitState]) -> BattleUnitState:
	for candidate in candidates:
		if not candidate.has_status(&"sealed"):
			return candidate
	return null

func _pick_ai_target(candidates: Array[BattleUnitState]) -> BattleUnitState:
	if candidates.size() == 1:
		return candidates[0]
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	if rng.chance(0.2):
		return sorted[rng.randi_range(0, sorted.size() - 1)]
	return sorted[0]

func _check_end() -> void:
	if state.is_over():
		return
	if state.living(BattleTypes.Side.ENEMY).is_empty():
		state.outcome = BattleTypes.Outcome.VICTORY
		_emit(&"battle_end", &"", [], {"outcome": state.outcome})
	elif state.living(BattleTypes.Side.ALLY).is_empty():
		state.outcome = BattleTypes.Outcome.DEFEAT
		_emit(&"battle_end", &"", [], {"outcome": state.outcome})

func _finish_round() -> void:
	for unit in state.units:
		if not unit.is_alive():
			continue
		for status in unit.statuses.duplicate():
			if status.data.expires_on_owner_action:
				continue
			if status.applied_round >= state.round:
				continue
			status.remaining -= 1
			if status.remaining <= 0:
				unit.remove_status(status.data.id)
				_emit(&"status_expire", &"", [unit.id], {
					"status_id": String(status.data.id),
					"reason": "duration",
				})
	_emit(&"round_end", &"", [], {"round": state.round})
	if state.round >= state.max_rounds and not state.is_over():
		state.outcome = BattleTypes.Outcome.DEFEAT
		_emit(&"battle_end", &"", [], {"outcome": state.outcome, "reason": "round_limit"})

func _emit(event_type: StringName, source_id: StringName, target_ids: Array, data: Dictionary = {}) -> void:
	_seq += 1
	events.append(BattleEvent.make(_seq, state.round, event_type, source_id, target_ids, data))

func _execute_skill(actor: BattleUnitState, intent: BattleIntent) -> void:
	var skill := content.get_skill(intent.skill_id)
	if skill == null or actor.mp < skill.mp_cost:
		_emit(&"intent_rejected", actor.id, [], {"reason": "mp"})
		_execute_defend(actor)
		return
	var targets := _resolve_targets(actor, intent, skill)
	if targets.is_empty():
		_emit(&"action_skipped", actor.id, [], {"reason": "no_target"})
		return
	var target_ids: Array[StringName] = []
	for target in targets:
		target_ids.append(target.id)
	_emit(&"action_start", actor.id, target_ids, {"kind": "skill", "skill_id": String(skill.id)})
	if skill.mp_cost > 0:
		var mp_before := actor.mp
		actor.mp = maxi(0, actor.mp - skill.mp_cost)
		_emit(&"mp_change", actor.id, [actor.id], {
			"amount": mp_before - actor.mp,
			"mp_before": mp_before,
			"mp_after": actor.mp,
			"reason": "skill",
			"skill_id": String(skill.id),
		})
	for effect in skill.effects:
		for target in targets:
			_apply_effect(actor, target, effect, skill.id)

func _resolve_targets(actor: BattleUnitState, intent: BattleIntent, skill: SkillData) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	if skill.target_type == SkillData.TargetType.SELF:
		result.append(actor)
		return result
	var candidates: Array[BattleUnitState]
	if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.ALL_ENEMIES:
		candidates = state.living_enemies_of(actor)
	else:
		candidates = state.living_allies_of(actor)
	if candidates.is_empty():
		return result
	var primary: BattleUnitState = null
	if not intent.target_ids.is_empty():
		var candidate := state.get_unit(intent.target_ids[0])
		if candidate != null and candidate.is_alive() and candidates.has(candidate):
			primary = candidate
	if primary == null:
		primary = _lowest_hp(candidates)
	if skill.target_type == SkillData.TargetType.SINGLE_ENEMY or skill.target_type == SkillData.TargetType.SINGLE_ALLY:
		result.append(primary)
		return result
	return _nearest_targets(primary, candidates, skill.max_targets)

func _lowest_hp(candidates: Array[BattleUnitState]) -> BattleUnitState:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var pa := float(a.hp) / float(a.data.max_hp)
		var pb := float(b.hp) / float(b.data.max_hp)
		if is_equal_approx(pa, pb):
			return String(a.id) < String(b.id)
		return pa < pb)
	return sorted[0]

func _nearest_targets(primary: BattleUnitState, candidates: Array[BattleUnitState], max_targets: int) -> Array[BattleUnitState]:
	var sorted := candidates.duplicate()
	sorted.sort_custom(func(a, b):
		var da := absi(a.slot - primary.slot)
		var db := absi(b.slot - primary.slot)
		if da == db:
			return String(a.id) < String(b.id)
		return da < db)
	var result: Array[BattleUnitState] = []
	for index in mini(max_targets, sorted.size()):
		result.append(sorted[index])
	return result

func _apply_effect(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect, source_type: StringName) -> void:
	match effect.kind:
		BattleEffect.Kind.DAMAGE:
			if not target.is_alive():
				return
			var damage := _compute_damage(source, target, effect.damage_type, effect.power)
			_apply_damage(source.id, target, int(damage["amount"]), bool(damage["crit"]), source_type)
		BattleEffect.Kind.HEAL:
			if not target.is_alive():
				return
			_apply_heal(source, target, effect)
		BattleEffect.Kind.APPLY_STATUS:
			if not target.is_alive():
				return
			_apply_status_effect(source.id, target, effect)
		BattleEffect.Kind.CLEANSE:
			_apply_cleanse(source.id, target, effect)
		BattleEffect.Kind.RESTORE_MP:
			if not target.is_alive():
				return
			_restore_mp(source, target, effect)

func _apply_heal(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect) -> void:
	var amount := 0
	if effect.flat_amount > 0:
		amount = effect.flat_amount
	else:
		amount = roundi(source.magic_value() * effect.power * rng.randf_range(0.95, 1.05))
	var hp_before := target.hp
	target.hp = mini(target.data.max_hp, target.hp + amount)
	_emit(&"heal", source.id, [target.id], {
		"amount": target.hp - hp_before,
		"hp_before": hp_before,
		"hp_after": target.hp,
	})

func compute_status_chance(target: BattleUnitState, base_chance: float) -> float:
	return clampf(base_chance * (1.0 - target.seal_resist_bonus()), 0.0, 1.0)

func _tick_round_start_statuses(order: Array[BattleUnitState]) -> void:
	for unit in order:
		if not unit.is_alive():
			continue
		for status in unit.statuses.duplicate():
			if not unit.is_alive():
				break
			if status.data.poison_max_hp_ratio > 0.0:
				var amount := maxi(1, roundi(float(unit.data.max_hp) * status.data.poison_max_hp_ratio))
				var hp_before := unit.hp
				unit.hp = maxi(0, unit.hp - amount)
				_emit(&"status_tick", unit.id, [unit.id], {
					"status_id": String(status.data.id),
					"amount": amount,
					"hp_before": hp_before,
					"hp_after": unit.hp,
				})
				if unit.hp <= 0 and unit.alive:
					unit.alive = false
					unit.statuses.clear()
					_emit(&"death", unit.id, [unit.id], {})

func _apply_status_effect(source_id: StringName, target: BattleUnitState, effect: BattleEffect) -> void:
	var status := content.get_status(effect.status_id)
	if status == null:
		push_error("Missing status: " + String(effect.status_id))
		return
	var chance := effect.status_chance
	if status.skips_action:
		chance = compute_status_chance(target, chance)
	if chance <= 0.0:
		_emit(&"status_resist", source_id, [target.id], {"status_id": String(status.id)})
		return
	if chance < 1.0 and not rng.chance(chance):
		_emit(&"status_resist", source_id, [target.id], {"status_id": String(status.id)})
		return
	var applied := target.add_status(status, state.round)
	_emit(&"status_apply" if applied else &"status_refresh", source_id, [target.id], {
		"status_id": String(status.id),
		"duration": status.duration,
	})

func _apply_cleanse(source_id: StringName, target: BattleUnitState, effect: BattleEffect) -> void:
	var removed := 0
	for status in target.statuses.duplicate():
		if removed >= effect.cleanse_count:
			break
		if status.data.kind == StatusData.Kind.DEBUFF:
			target.remove_status(status.data.id)
			removed += 1
			_emit(&"status_expire", source_id, [target.id], {
				"status_id": String(status.data.id),
				"reason": "cleanse",
			})

func _restore_mp(source: BattleUnitState, target: BattleUnitState, effect: BattleEffect) -> void:
	var mp_before := target.mp
	target.mp = mini(target.data.max_mp, target.mp + effect.flat_amount)
	_emit(&"mp_change", source.id, [target.id], {
		"amount": target.mp - mp_before,
		"mp_before": mp_before,
		"mp_after": target.mp,
		"reason": "item",
	})

func _has_flee_intent(player_intents: Array[BattleIntent]) -> bool:
	for intent in player_intents:
		if intent.kind == BattleTypes.IntentKind.FLEE:
			return true
	return false

func compute_flee_chance() -> float:
	var ally_average := _average_speed(state.living(BattleTypes.Side.ALLY))
	var enemy_average := _average_speed(state.living(BattleTypes.Side.ENEMY))
	return clampf(0.5 + (ally_average - enemy_average) / 10.0 * 0.08, 0.5, 0.9)

func _average_speed(units: Array[BattleUnitState]) -> float:
	if units.is_empty():
		return 0.0
	var total := 0.0
	for unit in units:
		total += float(_speed_rolls.get(unit.id, unit.data.speed))
	return total / float(units.size())

func _execute_item(actor: BattleUnitState, intent: BattleIntent) -> void:
	var item := content.get_item(intent.item_id)
	if item == null or state.item_remaining(item.id) <= 0:
		_emit(&"intent_rejected", actor.id, [], {"reason": "item"})
		_execute_defend(actor)
		return
	var target := actor
	if not intent.target_ids.is_empty():
		var candidate := state.get_unit(intent.target_ids[0])
		if candidate != null and candidate.is_alive() and candidate.side == actor.side:
			target = candidate
	_emit(&"action_start", actor.id, [target.id], {"kind": "item", "item_id": String(item.id)})
	state.consume_item(item.id)
	_emit(&"item_used", actor.id, [target.id], {"item_id": String(item.id), "remaining": state.item_remaining(item.id)})
	for effect in item.effects:
		_apply_effect(actor, target, effect, item.id)
