class_name StatusCommand
extends BattleCommand

var event: BattleEvent
var content: ContentDB

func _init(p_event: BattleEvent, p_content: ContentDB = null) -> void:
	event = p_event
	content = p_content

func play(ctx: BattleContext) -> void:
	var view: UnitView = _target_view(ctx)
	if view == null or view.unit_state == null:
		await ctx.wait(0.05)
		return
	view.set_statuses(view.unit_state.statuses)

	var status_id := StringName(event.data.get("status_id", ""))
	var status: StatusData = content.get_status(status_id) if content != null else null
	var label := status.display_name if status != null else String(status_id)
	var color := status.display_color if status != null else Color(0.78, 0.6, 1.0)

	match event.type:
		&"status_tick":
			view.set_hp(int(event.data.get("hp_after", view.unit_state.hp)), true)
			FloatText.spawn(ctx, view.global_position + Vector2(0, -250), "-%d" % int(event.data.get("amount", 0)), Color(0.78, 0.5, 1.0), 40)
			ctx.vfx_factory().play_skill(_visual_for_status(status_id), view.global_position + Vector2(0, -110))
			if ctx.camera != null:
				ctx.camera.shake(2.0, 0.08)
			await ctx.wait(0.22)
		&"status_apply", &"status_refresh":
			var text := label if event.type == &"status_apply" else label + "·刷新"
			FloatText.spawn(ctx, view.global_position + Vector2(0, -244), text, color, 26)
			ctx.vfx_factory().play_skill(_visual_for_status(status_id), view.global_position + Vector2(0, -110))
			await ctx.wait(0.16)
		_:
			FloatText.spawn(ctx, view.global_position + Vector2(0, -244), label + " 解除", Color(0.78, 0.78, 0.84), 24)
			await ctx.wait(0.12)

func _visual_for_status(status_id: StringName) -> StringName:
	match status_id:
		&"poison":
			return &"poison"
		&"sealed":
			return &"seal"
		&"war_cry", &"defending":
			return &"buff"
		_:
			return &"generic"

func _target_view(ctx: BattleContext) -> UnitView:
	if not event.target_ids.is_empty():
		return ctx.unit_view(event.target_ids[0])
	return ctx.unit_view(event.source_id)
