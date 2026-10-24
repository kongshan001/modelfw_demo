class_name DamageCommand
extends BattleCommand

const HIT_STOP := 0.06

var event: BattleEvent
var content: ContentDB

func _init(p_event: BattleEvent, p_content: ContentDB = null) -> void:
	event = p_event
	content = p_content

func play(ctx: BattleContext) -> void:
	var target: UnitView = _target_view(ctx)
	if target == null or target.unit_state == null:
		await ctx.wait(0.05)
		return
	var status_tick := event.type == &"status_tick"
	var crit := bool(event.data.get("crit", false))
	var amount := int(event.data.get("amount", 0))
	var source_type := String(event.data.get("source_type", ""))
	target.set_hp(int(event.data.get("hp_after", target.unit_state.hp)), true)

	var visual_id := &"poison" if status_tick else _visual_for_source(source_type)
	var impact_position := target.global_position + Vector2(0, -110)
	ctx.vfx_factory().play_impact(visual_id, impact_position)

	var text_color := Color(1.0, 0.86, 0.25) if crit else Color(1, 1, 1, 0.96)
	if status_tick:
		text_color = Color(0.78, 0.5, 1.0)
	FloatText.spawn(ctx, target.global_position + Vector2(0, -250), str(amount), text_color, 58 if crit else 42, crit)

	await target.hurt()

	if ctx.camera != null:
		if status_tick:
			ctx.camera.shake(2.0, 0.08)
		elif crit:
			ctx.camera.shake(7.0, 0.16)
			ctx.camera.punch_zoom(1.045, 0.18)
		else:
			ctx.camera.shake(5.0, 0.12)
	if crit:
		ctx.vfx_factory().screen_flash(Color(1.0, 0.9, 0.55), 0.22)

	await ctx.wait(HIT_STOP)

	if source_type == "attack":
		var source: UnitView = ctx.unit_view(event.source_id)
		if source != null and source != target:
			source.reset_pose()

func _visual_for_source(source_type: String) -> StringName:
	if source_type == "attack":
		return &"slash"
	if source_type == "status_tick" or source_type.is_empty():
		return &"generic"
	if content != null:
		var skill := content.get_skill(StringName(source_type))
		if skill != null:
			return skill.visual_id
	return StringName(source_type)

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
