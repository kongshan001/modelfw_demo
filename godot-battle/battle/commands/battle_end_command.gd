class_name BattleEndCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	if ctx.hud != null and ctx.hud.has_method("log_event"):
		ctx.hud.log_event(event)
	var outcome := int(event.data.get("outcome", BattleTypes.Outcome.NONE))
	match outcome:
		BattleTypes.Outcome.VICTORY:
			ctx.play_sfx(&"victory")
		BattleTypes.Outcome.DEFEAT:
			ctx.play_sfx(&"defeat")
		BattleTypes.Outcome.ESCAPED:
			ctx.play_sfx(&"click")
	if ctx.session != null and ctx.session.has_method("show_result"):
		ctx.session.show_result(outcome)
	await ctx.wait(0.5)
