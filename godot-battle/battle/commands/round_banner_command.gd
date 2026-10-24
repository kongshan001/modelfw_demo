class_name RoundBannerCommand
extends BattleCommand

var event: BattleEvent

func _init(p_event: BattleEvent) -> void:
	event = p_event

func play(ctx: BattleContext) -> void:
	if ctx.ui_layer == null:
		await ctx.wait(0.2)
		return
	var round_number := int(event.data.get("round", event.round))
	if round_number <= 0:
		round_number = event.round
	var label := Label.new()
	label.text = "第 %d 回合" % round_number
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 56)
	label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.04, 0.95))
	label.add_theme_constant_override("outline_size", 10)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(600, 92)
	label.position = Vector2(660, 64)
	label.pivot_offset = label.size * 0.5
	label.modulate.a = 0.0
	label.scale = Vector2(0.78, 0.78)
	label.z_index = 80
	ctx.ui_layer.add_child(label)

	var tween_in := label.create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(label, "modulate:a", 1.0, 0.16)
	tween_in.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await ctx.wait(0.5)

	var tween_out := label.create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(label, "modulate:a", 0.0, 0.16)
	tween_out.tween_property(label, "scale", Vector2(1.08, 1.08), 0.16)
	tween_out.chain().tween_callback(label.queue_free)
	await ctx.wait(0.18)

func skip(ctx: BattleContext) -> void:
	if ctx.ui_layer == null:
		return
	for child in ctx.ui_layer.get_children():
		if child is Label and String(child.text).begins_with("第 ") and String(child.text).ends_with(" 回合"):
			child.queue_free()
