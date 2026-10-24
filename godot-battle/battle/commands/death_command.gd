class_name DeathCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	var target: UnitView = _target_view(ctx)
	if target == null:
		await ctx.wait(0.05)
		return
	ctx.vfx_factory().death_burst(target.global_position + Vector2(0, -110))
	await target.die()
	await ctx.wait(0.12)

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
