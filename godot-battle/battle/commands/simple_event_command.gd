class_name SimpleEventCommand
extends BattleCommand

# 通用兜底命令：处理无需专属演出的简单事件；未知事件只做短等待，不中断播放。

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	match event.type:
		&"mp_change":
			var mp_view := _affected_view(ctx)
			if mp_view != null:
				mp_view.set_mp(int(event.data.get("mp_after", 0)), true)
			await ctx.wait(0.08)
		&"defend", &"item_used":
			var source := ctx.unit_view(event.source_id)
			if source != null and source.unit_state != null:
				source.set_statuses(source.unit_state.statuses)
			await ctx.wait(0.1)
		&"flee_attempt", &"flee_result", &"action_skipped", &"status_resist", &"intent_rejected":
			var view := _affected_view(ctx)
			if view != null and view.unit_state != null:
				view.set_statuses(view.unit_state.statuses)
			await ctx.wait(0.1)
		&"round_end":
			await ctx.wait(0.05)
		_:
			await ctx.wait(0.05)

func _affected_view(ctx: BattleContext) -> UnitView:
	if not event.target_ids.is_empty():
		return ctx.unit_view(event.target_ids[0])
	return ctx.unit_view(event.source_id)
