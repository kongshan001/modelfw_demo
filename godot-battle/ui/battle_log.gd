class_name BattleLog
extends PanelContainer

# 左下战斗日志：标题行 + RichTextLabel + 自动滚动。事件格式化由 BattleHUD 负责。

var _label: RichTextLabel

func _init() -> void:
	custom_minimum_size = Vector2(600, 220)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	UiStyle.attach_inner_border(self, 9)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	var title := Label.new()
	title.text = "◆ 战斗记录"
	title.add_theme_font_override("font", FontUtil.cjk_font())
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", UiStyle.GOLD_SOFT)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var hint := Label.new()
	hint.text = "自动滚动"
	hint.add_theme_font_override("font", FontUtil.cjk_font())
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.62, 0.58, 0.54, 0.8))
	header.add_child(hint)

	var divider := ColorRect.new()
	divider.color = Color(0.86, 0.68, 0.36, 0.3)
	divider.custom_minimum_size = Vector2(0, 1)
	box.add_child(divider)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_following = true
	_label.scroll_active = false
	_label.selection_enabled = false
	_label.fit_content = false
	_label.custom_minimum_size = Vector2(0, 160)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("normal_font", FontUtil.cjk_font())
	_label.add_theme_font_override("bold_font", FontUtil.cjk_font())
	_label.add_theme_font_size_override("normal_font_size", 18)
	_label.add_theme_font_size_override("bold_font_size", 18)
	_label.add_theme_color_override("default_color", Color(0.9, 0.89, 0.84))
	_label.add_theme_constant_override("line_separation", 4)
	box.add_child(_label)

func append_line(line: String) -> void:
	if _label == null:
		return
	_label.append_text(line + "\n")

func clear() -> void:
	if _label != null:
		_label.clear()

func line_count() -> int:
	return _label.get_line_count() if _label != null else 0
