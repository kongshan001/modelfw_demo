class_name VictoryPanel
extends Control

# 胜负演出（规格 6.4）：全屏压暗 + 金框仪式面板 + 标题 + 奖励 + 再战/退出。
# 每场只展示一次；标题文本保持“胜利！/战败…/逃跑成功”，供冒烟探针识别。

var _audio: AudioDirector
var _shown := false
var _title: Label
var _subtitle: Label
var _reward_box: VBoxContainer
var _exp_label: Label
var _gold_label: Label
var _panel: PanelContainer

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
			_subtitle.text = "竹影摇金 · 此战告捷"
		BattleTypes.Outcome.DEFEAT:
			_title.text = "战败…"
			_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
			_subtitle.text = "山风低回 · 再整旗鼓"
		BattleTypes.Outcome.ESCAPED:
			_title.text = "逃跑成功"
			_title.add_theme_color_override("font_color", Color(0.56, 0.9, 0.62))
			_subtitle.text = "全身而退 · 来日再战"
		_:
			_title.text = "战斗结束"
			_title.add_theme_color_override("font_color", Color(0.86, 0.86, 0.86))
			_subtitle.text = ""
	_subtitle.visible = not _subtitle.text.is_empty()

	_reward_box.visible = outcome == BattleTypes.Outcome.VICTORY
	_exp_label.text = "经验 +0"
	_gold_label.text = "金币 +0"
	visible = true
	modulate.a = 0.0
	if _panel != null:
		_panel.pivot_offset = _panel.size * 0.5
		_panel.scale = Vector2(0.96, 0.96)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "modulate:a", 1.0, 0.25)
		tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
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
	dim.color = Color(0.03, 0.02, 0.045, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var glow := VictoryGlow.new()
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 0)
	var style := UiStyle.panel_style(18, Vector2i(56, 38), UiStyle.PANEL_BG_DEEP, UiStyle.GOLD_SOFT, 3)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 28
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	UiStyle.attach_inner_border(_panel, 13)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "战 · 斗 · 结 · 算"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_override("font", FontUtil.cjk_font())
	eyebrow.add_theme_font_size_override("font_size", 17)
	eyebrow.add_theme_color_override("font_color", Color(0.82, 0.66, 0.38, 0.9))
	box.add_child(eyebrow)

	_title = Label.new()
	_title.text = "胜利！"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", FontUtil.cjk_font())
	_title.add_theme_font_size_override("font_size", 84)
	_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_title.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.05, 0.85))
	_title.add_theme_constant_override("outline_size", 10)
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = ""
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_override("font", FontUtil.cjk_font())
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", Color(0.86, 0.8, 0.68))
	box.add_child(_subtitle)

	box.add_child(_make_divider())

	_reward_box = VBoxContainer.new()
	_reward_box.add_theme_constant_override("separation", 8)
	box.add_child(_reward_box)

	_exp_label = _add_reward_row("经", Color(0.62, 0.88, 0.56))
	_gold_label = _add_reward_row("金", Color(0.95, 0.76, 0.33))

	box.add_child(_make_divider())

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

	var ornaments := FrameOrnaments.new()
	ornaments.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(ornaments)

func _make_divider() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var left := ColorRect.new()
	left.color = Color(0.86, 0.68, 0.36, 0.4)
	left.custom_minimum_size = Vector2(0, 1)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var diamond := Label.new()
	diamond.text = "◆"
	diamond.add_theme_font_override("font", FontUtil.cjk_font())
	diamond.add_theme_font_size_override("font_size", 14)
	diamond.add_theme_color_override("font_color", UiStyle.GOLD)
	row.add_child(diamond)
	var right := ColorRect.new()
	right.color = Color(0.86, 0.68, 0.36, 0.4)
	right.custom_minimum_size = Vector2(0, 1)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return row

func _add_reward_row(glyph: String, tint: Color) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var badge := UiStyle.make_badge(glyph, tint, tint.lightened(0.35), Color(0.14, 0.1, 0.05), 32, 18)
	row.add_child(badge)
	var label := _make_reward_label()
	row.add_child(label)
	_reward_box.add_child(row)
	return label

func _make_reward_label() -> Label:
	var label := Label.new()
	label.text = "经验 +0"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FontUtil.cjk_font())
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.98, 0.9, 0.66))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", FontUtil.cjk_font())
	UiStyle.apply_button(button, false, 26)
	return button

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


# ---------------------------------------------------------------- 装饰绘制

class VictoryGlow extends Control:
	func _draw() -> void:
		var center := size * 0.5
		# 低透明度放射光
		for i in 14:
			var a0 := TAU * float(i) / 14.0 + 0.11
			var a1 := a0 + TAU / 28.0
			var points := PackedVector2Array([
				center,
				center + Vector2(cos(a0), sin(a0)) * 980.0,
				center + Vector2(cos(a1), sin(a1)) * 980.0,
			])
			draw_colored_polygon(points, Color(1.0, 0.85, 0.5, 0.022))
		for radius: float in [470.0, 350.0, 240.0]:
			draw_circle(center, radius, Color(0.95, 0.74, 0.34, 0.018))

class FrameOrnaments extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var inset := 7.0
		var arm := 30.0
		var color := Color(0.98, 0.82, 0.5, 0.62)
		_draw_corner(Vector2(inset, inset), Vector2(1, 0), Vector2(0, 1), arm, color)
		_draw_corner(Vector2(w - inset, inset), Vector2(-1, 0), Vector2(0, 1), arm, color)
		_draw_corner(Vector2(inset, h - inset), Vector2(1, 0), Vector2(0, -1), arm, color)
		_draw_corner(Vector2(w - inset, h - inset), Vector2(-1, 0), Vector2(0, -1), arm, color)

	func _draw_corner(origin: Vector2, dir_x: Vector2, dir_y: Vector2, arm: float, color: Color) -> void:
		draw_polyline(PackedVector2Array([origin + dir_x * arm, origin, origin + dir_y * arm]), color, 2.0, true)
		var diamond := PackedVector2Array([
			origin + dir_x * (arm + 6.0) + dir_y * 0.0,
			origin + dir_x * (arm + 11.0) + dir_y * 5.0,
			origin + dir_x * (arm + 6.0) + dir_y * 10.0,
			origin + dir_x * (arm + 1.0) + dir_y * 5.0,
		])
		draw_colored_polygon(diamond, color)
