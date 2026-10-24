class_name VictoryPanel
extends Control

# 胜负演出（规格 6.4）：全屏压暗 + 标题 + 胜利奖励 + 再战/退出。每场只展示一次。

var _audio: AudioDirector
var _shown := false
var _title: Label
var _reward_box: VBoxContainer
var _exp_label: Label
var _gold_label: Label

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()

func setup(audio: AudioDirector) -> void:
	_audio = audio

func show_panel(outcome: int, reward_exp: int, reward_gold: int) -> void:
	if _shown:
		return
	_shown = true
	match outcome:
		BattleTypes.Outcome.VICTORY:
			_title.text = "胜利！"
			_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		BattleTypes.Outcome.DEFEAT:
			_title.text = "战败…"
			_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
		BattleTypes.Outcome.ESCAPED:
			_title.text = "逃跑成功"
			_title.add_theme_color_override("font_color", Color(0.56, 0.9, 0.62))
		_:
			_title.text = "战斗结束"
			_title.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))

	_reward_box.visible = outcome == BattleTypes.Outcome.VICTORY
	_exp_label.text = "经验 +0"
	_gold_label.text = "金币 +0"
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	if outcome == BattleTypes.Outcome.VICTORY:
		_count_up(_exp_label, "经验", reward_exp, 0.0)
		_count_up(_gold_label, "金币", reward_gold, 0.18)

func is_shown() -> bool:
	return _shown

func _count_up(label: Label, prefix: String, value: int, delay: float) -> void:
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(
		func(number: float) -> void: label.text = "%s +%d" % [prefix, roundi(number)],
		0.0,
		float(value),
		0.75
	)

# ---------------------------------------------------------------- 构建

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.64)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.07, 0.06, 0.97)
	style.border_color = Color(0.84, 0.68, 0.34, 0.95)
	style.set_border_width_all(3)
	style.set_corner_radius_all(16)
	style.content_margin_left = 56
	style.content_margin_right = 56
	style.content_margin_top = 34
	style.content_margin_bottom = 34
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)

	_title = Label.new()
	_title.text = "胜利！"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", FontUtil.cjk_font())
	_title.add_theme_font_size_override("font_size", 78)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(_title)

	var divider := HSeparator.new()
	divider.add_theme_color_override("separator", Color(0.84, 0.68, 0.34, 0.4))
	box.add_child(divider)

	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 6)
	box.add_child(_reward_box)

	_exp_label = _make_reward_label()
	_reward_box.add_child(_exp_label)

	_gold_label = _make_reward_label()
	_reward_box.add_child(_gold_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)

	var again := _make_button("再战一场")
	again.pressed.connect(_on_again_pressed)
	buttons.add_child(again)

	var quit_button := _make_button("退出")
	quit_button.pressed.connect(_on_quit_pressed)
	buttons.add_child(quit_button)

func _make_reward_label() -> Label:
	var label := Label.new()
	label.text = "经验 +0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.66))
	return label

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FontUtil.cjk_font())
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", Color(1.0, 0.93, 0.76))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.9))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.86, 0.5))

	var normal := _button_style(Color(0.26, 0.16, 0.09), Color(0.76, 0.58, 0.28))
	var hover := _button_style(Color(0.37, 0.23, 0.12), Color(1.0, 0.86, 0.5))
	var pressed := _button_style(Color(0.48, 0.31, 0.14), Color(1.0, 0.86, 0.5))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(9)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

# ---------------------------------------------------------------- 按钮

func _on_again_pressed() -> void:
	_play_click()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit()

func _play_click() -> void:
	if _audio != null:
		_audio.play_sfx(&"click")
