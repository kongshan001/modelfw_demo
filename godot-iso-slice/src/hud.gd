class_name IsoHud
extends CanvasLayer

# 极简 HUD：标题 + 操作提示 + 两个教学开关的实时状态。
# 暗角也在这一层，先加暗角再加文字，保证文字压在暗角上面。

var _status: Label


func _ready() -> void:
	var vignette := TextureRect.new()
	vignette.texture = preload("res://assets/ui/vignette.png")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	var panel := PanelContainer.new()
	panel.position = Vector2(28, 24)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.065, 0.09, 0.82)
	style.border_color = Color(1.0, 0.78, 0.45, 0.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	ui.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)

	var title := Label.new()
	title.text = "ISO SLICE · 烛光地牢"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.87, 0.64))
	box.add_child(title)

	var hint := Label.new()
	hint.text = "WASD / 方向键   移动\nF1  Y-Sort    F2  烛光    F3  烘焙管线    F4  Mod 导入\nR  回到起点"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.80, 0.83, 0.90, 0.92))
	box.add_child(hint)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", Color(0.98, 0.71, 0.40))
	box.add_child(_status)

	var tip := Label.new()
	tip.text = "走到墙后试试：关掉 F1，遮挡会立刻穿帮。"
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", Color(0.78, 0.80, 0.86, 0.7))
	tip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tip.offset_left = 30.0
	tip.offset_right = 900.0
	tip.offset_top = -52.0
	tip.offset_bottom = -26.0
	ui.add_child(tip)


func set_status(y_sort: bool, lights: bool) -> void:
	if _status == null:
		return
	_status.text = "Y-SORT %s        LIGHTS %s" % [
		"ON" if y_sort else "OFF",
		"ON" if lights else "OFF",
	]
