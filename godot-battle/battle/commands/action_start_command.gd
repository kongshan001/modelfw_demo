class_name ActionStartCommand
extends BattleCommand

var event: BattleEvent
var content: ContentDB

func _init(p_event: BattleEvent, p_content: ContentDB = null) -> void:
	event = p_event
	content = p_content

func play(ctx: BattleContext) -> void:
	if ctx.hud != null and ctx.hud.has_method("log_event"):
		ctx.hud.log_event(event)
	if ctx.hud != null and ctx.hud.has_method("highlight_actor"):
		ctx.hud.highlight_actor(event.source_id)
	var source: UnitView = ctx.unit_view(event.source_id)
	var kind := String(event.data.get("kind", "attack"))
	match kind:
		"attack":
			ctx.play_sfx(&"slash")
		"skill":
			ctx.play_sfx(&"cast")
		"item":
			ctx.play_sfx(&"heal")
		"defend":
			ctx.play_sfx(&"status")
	match kind:
		"attack":
			var target: UnitView = _target_view(ctx)
			if source != null and target != null:
				await source.lunge_to(target.global_position)
				await ctx.wait(0.04)
			else:
				await ctx.wait(0.12)
		"skill":
			await _play_skill(ctx, source)
		"defend":
			if source != null:
				source.set_selected(false)
			await ctx.wait(0.15)
		"item":
			await ctx.wait(0.12)
		_:
			await ctx.wait(0.1)

func _play_skill(ctx: BattleContext, source: UnitView) -> void:
	if source != null:
		await source.cast_pose()
		ctx.vfx_factory().cast_ring(source.global_position)
	if ctx.camera != null:
		ctx.camera.punch_zoom(1.04, 0.15)
	var visual_id := _visual_id()
	var target: UnitView = _target_view(ctx)
	var vfx := ctx.vfx_factory()
	if vfx.visuals_enabled and source != null and target != null and _has_projectile(visual_id):
		# 等弹道到达后，后续 Damage/Heal/Status 命令才播放命中特效。
		await vfx.projectile(
			source.global_position + Vector2(0, -140),
			target.global_position + Vector2(0, -110),
			visual_id
		)
	else:
		await ctx.wait(0.04)

func _visual_id() -> StringName:
	if content == null:
		return &""
	var skill := content.get_skill(StringName(event.data.get("skill_id", "")))
	return skill.visual_id if skill != null else &""

func _has_projectile(visual_id: StringName) -> bool:
	return visual_id == &"fire" or visual_id == &"seal" or visual_id == &"heal"

func _target_view(ctx: BattleContext) -> UnitView:
	if event.target_ids.is_empty():
		return null
	return ctx.unit_view(event.target_ids[0])
