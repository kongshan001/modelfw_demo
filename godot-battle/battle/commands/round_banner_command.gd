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

	var order_strip := _build_order_strip(ctx)

	var tween_in := label.create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(label, "modulate:a", 1.0, 0.16)
	tween_in.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if order_strip != null:
		order_strip.create_tween().tween_property(order_strip, "modulate:a", 1.0, 0.16)
	await ctx.wait(0.5)

	var tween_out := label.create_tween()
	tween_out.set_parallel(true)
	tween_out.tween_property(label, "modulate:a", 0.0, 0.16)
	tween_out.tween_property(label, "scale", Vector2(1.08, 1.08), 0.16)
	tween_out.chain().tween_callback(label.queue_free)
	if order_strip != null and is_instance_valid(order_strip):
		var strip_out := order_strip.create_tween()
		strip_out.tween_property(order_strip, "modulate:a", 0.0, 0.2)
		strip_out.tween_callback(order_strip.queue_free)
	await ctx.wait(0.18)

func _build_order_strip(ctx: BattleContext) -> Node:
	var order: Array = event.data.get("order", [])
	if order.is_empty() or ctx.ui_layer == null:
		return null
	var panel := PanelContainer.new()
	panel.name = "TurnOrderPreview"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.11, 0.72)
	style.border_color = Color(1.0, 0.9, 0.55, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(48, 48)
	panel.z_index = 79
	panel.modulate.a = 0.0
	ctx.ui_layer.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var session := ctx.session as BattleSession
	for index in order.size():
		var unit_state: BattleUnitState = null
		if session != null and session.engine != null:
			unit_state = session.engine.state.get_unit(StringName(String(order[index])))
		var display_name := String(order[index])
		var tint := Color(1.0, 0.62, 0.5)
		if unit_state != null:
			display_name = unit_state.data.display_name
			if unit_state.side == BattleTypes.Side.ALLY:
				tint = Color(0.55, 0.8, 1.0)
		var chip := Label.new()
		chip.text = display_name
		chip.add_theme_font_override("font", FontUtil.cjk_font())
		chip.add_theme_font_size_override("font_size", 22)
		chip.add_theme_color_override("font_color", tint)
		chip.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.06, 0.9))
		chip.add_theme_constant_override("outline_size", 4)
		row.add_child(chip)
		if index < order.size() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_font_override("font", FontUtil.cjk_font())
			arrow.add_theme_font_size_override("font_size", 20)
			arrow.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7, 0.75))
			row.add_child(arrow)
	return panel

func skip(ctx: BattleContext) -> void:
	if ctx.ui_layer == null:
		return
	for child in ctx.ui_layer.get_children():
		if String(child.name) == "TurnOrderPreview":
			child.queue_free()
		elif child is Label and String(child.text).begins_with("第 ") and String(child.text).ends_with(" 回合"):
			child.queue_free()
