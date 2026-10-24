class_name ActionStartCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	var source: UnitView = ctx.unit_view(event.source_id)
	var kind := String(event.data.get("kind", "attack"))
	match kind:
		"attack":
			var target: UnitView = _target_view(ctx)
			if source != null and target != null:
				await source.lunge_to(target.global_position)
				await ctx.wait(0.08)
			else:
				await ctx.wait(0.15)
		"skill":
			await _play_skill(ctx, source)
		"defend":
			if source != null:
				source.set_selected(false)
			await ctx.wait(0.2)
		"item":
			await ctx.wait(0.15)
		_:
			await ctx.wait(0.12)

func _play_skill(ctx: BattleContext, source: UnitView) -> void:
	if source != null:
		await source.cast_pose()
		ctx.vfx_factory().cast_ring(source.global_position)
	if ctx.camera != null:
		ctx.camera.punch_zoom(1.04, 0.15)
	await ctx.wait(0.08)

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
