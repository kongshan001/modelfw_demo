class_name FloatText
extends Label

# 世界坐标飘字：向上漂浮、淡出、自动释放。暴击使用金色大字 + 弹出缩放。

static func spawn(ctx: BattleContext, world_position: Vector2, text: String, color: Color, font_size: int = 40, crit: bool = false) -> FloatText:
	var label := FloatText.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03, 0.95))
	label.add_theme_constant_override("outline_size", 7)
	label.size = Vector2(340, font_size + 26)
	label.pivot_offset = label.size * 0.5
	label.position = world_position - Vector2(label.size.x * 0.5, 36.0)
	label.z_index = 50
	ctx.vfx_layer.add_child(label)

	var start := label.position
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", start.y - 88.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.85).set_delay(0.15)
	if crit:
		label.scale = Vector2(0.5, 0.5)
		tween.tween_property(label, "scale", Vector2(1.18, 1.18), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_delay(0.18)
	tween.chain().tween_callback(label.queue_free)
	return label
