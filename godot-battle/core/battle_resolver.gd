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
	var intents := _validate_player_intents(player_intents)
	for enemy in state.living(BattleTypes.Side.ENEMY):
		intents[enemy.id] = _decide_ai(enemy)
	var actions := _collect_actions(intents)
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

func _validate_player_intents(player_intents: Array[BattleIntent]) -> Dictionary:
	var result := {}
	for intent in player_intents:
		var actor := state.get_unit(intent.actor_id)
		if actor == null or actor.side != BattleTypes.Side.ALLY or not actor.is_alive():
			continue
		if _is_valid_intent(actor, intent):
			result[actor.id] = intent
		else:
			_emit(&"intent_rejected", actor.id, intent.target_ids, {"reason": "invalid"})
			result[actor.id] = BattleIntent.make(actor.id, BattleTypes.IntentKind.DEFEND)
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
		BattleTypes.IntentKind.DEFEND:
			return true
		_:
			return false

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
	if actor.has_status(&"defending"):
		actor.remove_status(&"defending")
		_emit(&"status_expire", actor.id, [actor.id], {"status_id": "defending", "reason": "owner_action"})
	match intent.kind:
		BattleTypes.IntentKind.ATTACK:
			_execute_attack(actor, intent)
		BattleTypes.IntentKind.SKILL:
			_execute_skill(actor, intent)
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
	var target := _pick_ai_target(targets)
	return BattleIntent.make(actor.id, BattleTypes.IntentKind.ATTACK, [target.id])

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
