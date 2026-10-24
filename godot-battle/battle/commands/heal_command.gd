class_name HealCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	var target: UnitView = _target_view(ctx)
	if target == null or target.unit_state == null:
		await ctx.wait(0.05)
		return
	var amount := int(event.data.get("amount", 0))
	target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)
	FloatText.spawn(ctx, target.global_position + Vector2(0, -244), "+%d" % amount, Color(0.45, 1.0, 0.55), 44)
	ctx.vfx_factory().heal(target.global_position + Vector2(0, -110))
	await ctx.wait(0.3)

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
