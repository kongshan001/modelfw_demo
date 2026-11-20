class_name GardenGameUI
extends Control

# 游戏 HUD：右上任务卷轴（任务/目标/气血）、底部操作提示、完成横幅与提示条。

var _hero
var _quest
var _font: SystemFont
var _objective: Label
var _hp_label: Label
var _hp_bar: ProgressBar
var _banner: Label
var _banner_sub: Label
var _toast: Label
var _toast_tween: Tween
var _last_stage := ""

func setup(hero, quest: GardenQuest) -> void:
	_hero = hero
	_quest = quest
	_build()
	if _quest != null:
		_last_stage = _quest.stage
		_quest.changed.connect(_on_quest_changed)
		_quest.completed.connect(_on_quest_completed)
	if _hero != null:
		_hero.hp_changed.connect(_on_hp_changed)
		_hero.downed.connect(_on_downed)
		_hero.respawned.connect(_on_respawned)
		_on_hp_changed(_hero.hp, _hero.max_hp)
	_sync()

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC",
		"Microsoft YaHei", "Arial Unicode MS",
	])

	var panel := PanelContainer.new()
	panel.position = Vector2(1500, 28)
	panel.custom_minimum_size = Vector2(392, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.028, 0.032, 0.8)
	style.border_color = Color(0.72, 0.64, 0.44, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var eyebrow := _label("试 炼 任 务", 12, Color(0.82, 0.66, 0.38, 0.95))
	box.add_child(eyebrow)
	var title := _label(_quest.title if _quest != null else "", 24, Color(0.96, 0.92, 0.82))
	title.add_theme_constant_override("outline_size", 4)
	box.add_child(title)
	box.add_child(_label("委托人 · " + (_quest.giver if _quest != null else ""), 13, Color(0.66, 0.64, 0.58)))

	_objective = _label("", 17, Color(1.0, 0.82, 0.5))
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(0, 46)
	box.add_child(_objective)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	box.add_child(hp_row)
	var hp_title := _label("气血", 13, Color(0.66, 0.64, 0.58))
	hp_title.custom_minimum_size = Vector2(34, 0)
	hp_row.add_child(hp_title)
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 220
	_hp_bar.value = 220
	_hp_bar.custom_minimum_size = Vector2(0, 10)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1.0, 0.95, 0.82, 0.1)
	bg.set_corner_radius_all(5)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.86, 0.3, 0.22)
	fill.set_corner_radius_all(5)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	hp_row.add_child(_hp_bar)
	_hp_label = _label("220 / 220", 12, Color(0.9, 0.86, 0.78))
	_hp_label.custom_minimum_size = Vector2(70, 0)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(_hp_label)

	var divider := ColorRect.new()
	divider.color = Color(0.8, 0.7, 0.5, 0.16)
	divider.custom_minimum_size = Vector2(0, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)
	box.add_child(_label("自动寻路 · 靠近自动战斗", 12, Color(0.75, 0.72, 0.64)))
	box.add_child(_label("点击地面移动 · 点击妖灵攻击", 12, Color(0.62, 0.6, 0.54)))

	var hint := _label("点击地面移动 · 点击妖灵攻击 · 默认自动完成任务", 14, Color(0.93, 0.9, 0.84))
	hint.position = Vector2(0, 1020)
	hint.size = Vector2(1920, 26)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_constant_override("outline_size", 6)
	add_child(hint)

	_banner = _label("试炼完成", 44, Color(1.0, 0.84, 0.46))
	_banner.position = Vector2(0, 360)
	_banner.size = Vector2(1920, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 8)
	_banner.visible = false
	add_child(_banner)
	_banner_sub = _label("石圈的妖灵已清理", 20, Color(0.92, 0.88, 0.8))
	_banner_sub.position = Vector2(0, 424)
	_banner_sub.size = Vector2(1920, 32)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_constant_override("outline_size", 5)
	_banner_sub.visible = false
	add_child(_banner_sub)

	_toast = _label("", 20, Color(1.0, 0.9, 0.68))
	_toast.position = Vector2(0, 900)
	_toast.size = Vector2(1920, 32)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_constant_override("outline_size", 5)
	_toast.visible = false
	add_child(_toast)

func _sync() -> void:
	if _quest == null:
		return
	_objective.text = _quest.objective_text()
	if _quest.stage == GardenQuest.STAGE_COMPLETE:
		_objective.text = "试炼完成"

func _on_quest_changed() -> void:
	if _quest == null:
		return
	_sync()
	if _quest.stage == _last_stage:
		return
	_last_stage = _quest.stage
	match _quest.stage:
		GardenQuest.STAGE_FIGHT:
			_show_toast("任务接取：清理石圈的妖灵")
		GardenQuest.STAGE_RETURN:
			_show_toast("妖灵已清理，回到石像复命")
		GardenQuest.STAGE_COMPLETE:
			_show_toast("试炼完成 · 石圈的妖灵已清理")

func _on_quest_completed() -> void:
	_banner.visible = true
	_banner_sub.visible = true
	_banner.modulate.a = 0.0
	_banner_sub.modulate.a = 0.0
	_banner.scale = Vector2(1.08, 1.08)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_banner, "modulate:a", 1.0, 0.35)
	tween.tween_property(_banner_sub, "modulate:a", 1.0, 0.35)
	tween.tween_property(_banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK)
	var hide := create_tween()
	hide.tween_interval(3.5)
	hide.tween_property(_banner, "modulate:a", 0.0, 0.6)
	hide.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.6)

func _on_hp_changed(current: int, max_value: int) -> void:
	if _hp_bar == null:
		return
	_hp_bar.max_value = max_value
	_hp_bar.value = current
	_hp_label.text = "%d / %d" % [current, max_value]

func _on_downed() -> void:
	_show_toast("你倒下了……", Color(1.0, 0.5, 0.4))

func _on_respawned() -> void:
	_show_toast("重新站起来", Color(1.0, 0.85, 0.5))

func _show_toast(text: String, color := Color(1.0, 0.9, 0.68)) -> void:
	if _toast == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
