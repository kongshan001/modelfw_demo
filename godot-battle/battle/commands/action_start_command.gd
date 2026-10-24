class_name ActionStartCommand
extends BattleCommand

var event: BattleEvent
var content: ContentDB

func _init(p_event: BattleEvent, p_content: ContentDB = null) -> void:
	event = p_event
	content = p_content

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
	var skill: SkillData = null
	if content != null:
		skill = content.get_skill(StringName(event.data.get("skill_id", "")))
	var visual_id: StringName = skill.visual_id if skill != null else &"generic"
	if source != null:
		await source.cast_pose()
	var targets := event.target_ids
	for index in targets.size():
		var target: UnitView = ctx.unit_view(targets[index])
		if target == null:
			continue
		var effect_position := target.global_position + Vector2(0, -110)
		if visual_id == &"aoe":
			effect_position = target.global_position
		ctx.vfx_factory().play_skill(visual_id, effect_position)
		if index < targets.size() - 1:
			await ctx.wait(0.08)

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
