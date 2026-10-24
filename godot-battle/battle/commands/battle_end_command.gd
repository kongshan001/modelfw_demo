class_name BattleEndCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	var outcome := int(event.data.get("outcome", BattleTypes.Outcome.NONE))
	if ctx.session != null and ctx.session.has_method("show_result"):
		ctx.session.show_result(outcome)
	await ctx.wait(0.5)
