class_name BubbleCommand
extends BattleCommand

# 技能喊招气泡：显示在出手者头顶，约 0.5s 内返回，不阻塞行动演出。

var text: String = ""
var source_id: StringName = &""

func _init(p_text: String, p_source_id: StringName) -> void:
	text = p_text
	source_id = p_source_id

func play(ctx: BattleContext) -> void:
	if ctx.bubble == null or text.is_empty():
		return
	var view: UnitView = ctx.unit_view(source_id)
	if view == null:
		return
	var anchor := view.get_global_transform_with_canvas().origin + Vector2(0, -300)
	ctx.bubble.show_text(text, anchor)
	await ctx.wait(0.08)

func skip(ctx: BattleContext) -> void:
	if ctx.bubble != null:
		ctx.bubble.hide_now()
