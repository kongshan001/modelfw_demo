class_name SimpleEventCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	match event.type:
		&"round_start":
			await ctx.wait(0.35)
		&"action_start":
			await _play_action_start(ctx)
		&"damage", &"status_tick":
			await _play_damage(ctx)
		&"heal":
			await _play_heal(ctx)
		&"death":
			if not event.target_ids.is_empty():
				var target_view: UnitView = ctx.unit_view(event.target_ids[0])
				if target_view != null:
					await target_view.die()
		&"status_apply", &"status_refresh", &"status_expire", &"mp_change", &"item_used", &"defend", &"flee_attempt", &"flee_result", &"action_skipped":
			var source_view: UnitView = ctx.unit_view(event.source_id)
			if source_view != null and source_view.unit_state != null:
				source_view.set_statuses(source_view.unit_state.statuses)
				source_view.set_mp(source_view.unit_state.mp, true)
			await ctx.wait(0.08)
		&"battle_end":
			ctx.session.show_result(int(event.data.get("outcome", BattleTypes.Outcome.NONE)))
		_:
			await ctx.wait(0.02)

func _play_action_start(ctx: BattleContext) -> void:
	var source: UnitView = ctx.unit_view(event.source_id)
	if source == null:
		return
	var kind := String(event.data.get("kind", "attack"))
	if kind == "attack":
		var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
		if target != null:
			await source.lunge_to(target.global_position)
			await ctx.wait(0.08)
		else:
			await ctx.wait(0.15)
	elif kind == "skill":
		await source.cast_pose()
	elif kind == "defend":
		source.set_selected(false)
		await ctx.wait(0.18)
	else:
		await ctx.wait(0.12)

func _play_damage(ctx: BattleContext) -> void:
	var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
	if target == null:
		return
	target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)
	await target.hurt()
	ctx.camera.shake(5.0, 0.12)
	if String(event.data.get("source_type", "")) == "status_tick":
		ctx.camera.shake(2.0, 0.08)
	await ctx.wait(0.08)
	var source: UnitView = ctx.unit_view(event.source_id)
	if source != null and String(event.data.get("kind", "")) != "skill":
		source.reset_pose()

func _play_heal(ctx: BattleContext) -> void:
	var target: UnitView = ctx.unit_view(event.target_ids[0]) if not event.target_ids.is_empty() else null
	if target != null:
		target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)
	await ctx.wait(0.18)
