class_name BattleLog
extends PanelContainer

# 左下战斗日志：RichTextLabel + 自动滚动。事件格式化由 BattleHUD 负责。

var _label: RichTextLabel

func _init() -> void:
	custom_minimum_size = Vector2(560, 270)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_following = true
	_label.scroll_active = false
	_label.selection_enabled = false
	_label.fit_content = false
	_label.custom_minimum_size = Vector2(0, 236)
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.add_theme_font_override("normal_font", FontUtil.cjk_font())
	_label.add_theme_font_override("bold_font", FontUtil.cjk_font())
	_label.add_theme_font_size_override("normal_font_size", 17)
	_label.add_theme_font_size_override("bold_font_size", 17)
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
