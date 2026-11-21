class_name HeroDetailPanel
extends PanelContainer

# 右侧卷轴：姓名/称号、职业·性别·种族、描述、语录、四维、技能与确认按钮。
# 内容随选中角色重排；属性条用 0.45s 动画，标题与主色同步。

signal confirm_pressed

const STAT_NAMES := ["气血", "攻击", "法术", "身法"]

var _profile: HeroProfile
var _accent := Color(0.45, 0.8, 1.0)
var _content: VBoxContainer
var _name: Label
var _title: Label
var _tags: HBoxContainer
var _description: Label
var _quote: Label
var _role: Label
var _skill_row: HBoxContainer
var _confirm: Button
var _stat_bars: Array[ProgressBar] = []
var _stat_values: Array[Label] = []

func _init() -> void:
	custom_minimum_size = Vector2(580, 890)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var style := SelectStyle.panel_style(_accent)
	add_theme_stylebox_override("panel", style)
	UiStyle.attach_inner_border(self, 13)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 11)
	margin.add_child(_content)

	var eyebrow := SelectStyle.label("主 / 角 / 档 / 案", 15, Color(0.82, 0.66, 0.38, 0.92))
	_content.add_child(eyebrow)

	_name = SelectStyle.label("", 46, SelectStyle.TEXT)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_name)

	_title = SelectStyle.label("", 19, SelectStyle.GOLD_SOFT)
	_content.add_child(_title)

	_tags = HBoxContainer.new()
	_tags.add_theme_constant_override("separation", 8)
	_tags.custom_minimum_size = Vector2(0, 32)
	_content.add_child(_tags)

	_description = SelectStyle.label("", 19, Color(0.9, 0.87, 0.8))
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.max_lines_visible = 3
	_description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_description.custom_minimum_size = Vector2(0, 104)
	_content.add_child(_description)

	_quote = SelectStyle.label("", 20, SelectStyle.GOLD)
	_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quote.max_lines_visible = 2
	_quote.custom_minimum_size = Vector2(0, 54)
	_content.add_child(_quote)

	_content.add_child(SelectStyle.divider())

	var stats_header := SelectStyle.label("四 维", 14, SelectStyle.MUTED)
	_content.add_child(stats_header)
	for index in STAT_NAMES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.custom_minimum_size = Vector2(0, 23)
		var stat_name := SelectStyle.label(STAT_NAMES[index], 17, Color(0.82, 0.78, 0.7))
		stat_name.custom_minimum_size = Vector2(46, 0)
		row.add_child(stat_name)
		var bar := SelectStyle.stat_bar(_accent)
		row.add_child(bar)
		var value := SelectStyle.label("0", 16, SelectStyle.GOLD_SOFT)
		value.custom_minimum_size = Vector2(30, 0)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_content.add_child(row)
		_stat_bars.append(bar)
		_stat_values.append(value)

	var skill_header := SelectStyle.label("技 能", 14, SelectStyle.MUTED)
	_content.add_child(skill_header)
	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 7)
	_skill_row.custom_minimum_size = Vector2(0, 30)
	_content.add_child(_skill_row)

	var role_header := SelectStyle.label("定 位", 14, SelectStyle.MUTED)
	_content.add_child(role_header)
	_role = SelectStyle.label("", 18, Color(0.9, 0.86, 0.78))
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.custom_minimum_size = Vector2(0, 26)
	_content.add_child(_role)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(spacer)

	var hint := SelectStyle.label("确认后进入现有战斗 · 选择会被记住", 13, SelectStyle.HINT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(hint)

	_confirm = SelectStyle.big_button("踏 入 试 炼   ›", _accent)
	_confirm.custom_minimum_size = Vector2(0, 58)
	_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm.pressed.connect(func() -> void: confirm_pressed.emit())
	_content.add_child(_confirm)

func show_profile(profile: HeroProfile, animated: bool) -> void:
	if profile == null:
		return
	var changed := _profile == null or _profile.id != profile.id
	_profile = profile
	_accent = profile.accent
	_name.text = profile.display_name
	_title.text = "「%s」" % profile.title
	_description.text = profile.description
	_quote.text = "“%s”" % profile.quote
	_quote.add_theme_color_override("font_color", profile.accent.lightened(0.35))
	_role.text = _role_text(profile.hero_class)
	_rebuild_tags(profile)
	_rebuild_skills(profile)
	_refresh_stats(profile, animated)
	_confirm.disabled = false
	if animated and changed:
		_content.modulate.a = 0.35
		var tween := create_tween()
		tween.tween_property(_content, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_CUBIC)
	else:
		_content.modulate.a = 1.0

func set_confirm_enabled(enabled: bool) -> void:
	if _confirm != null:
		_confirm.disabled = not enabled

func _role_text(hero_class: String) -> String:
	match hero_class:
		"剑客":
			return "近战 · 破甲与单体爆发"
		"法师":
			return "远程 · 群体法术与控制"
		"医师":
			return "辅助 · 治疗与净化"
		_:
			return "未知定位"

func _rebuild_tags(profile: HeroProfile) -> void:
	for child in _tags.get_children():
		_tags.remove_child(child)
		child.queue_free()
	_tags.add_child(SelectStyle.tag("职业 · %s" % profile.hero_class, profile.accent))
	_tags.add_child(SelectStyle.tag(profile.gender, profile.accent))
	_tags.add_child(SelectStyle.tag(profile.race, profile.accent))

func _rebuild_skills(profile: HeroProfile) -> void:
	for child in _skill_row.get_children():
		_skill_row.remove_child(child)
		child.queue_free()
	for skill_name in profile.skills:
		_skill_row.add_child(SelectStyle.tag(skill_name, profile.accent))

func _refresh_stats(profile: HeroProfile, animated: bool) -> void:
	var values := [profile.hp_bar, profile.atk_bar, profile.mag_bar, profile.spd_bar]
	for index in _stat_bars.size():
		var bar := _stat_bars[index]
		var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill != null:
			fill.bg_color = profile.accent
		var target := float(values[index])
		_stat_values[index].text = str(int(target))
		if animated:
			var tween := create_tween()
			tween.tween_interval(index * 0.045)
			tween.tween_property(bar, "value", target, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			bar.value = target
