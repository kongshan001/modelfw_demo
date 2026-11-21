class_name CharacterSelect
extends Control

# 主角选择界面控制器：舞台布局、6 人切换、键盘/鼠标输入、确认朱印与进入战斗。

signal hero_changed(profile: HeroProfile)
signal confirmed(profile: HeroProfile)

const BATTLE_SCENE := "res://scenes/battle_scene.tscn"
const BG := Color(0.035, 0.03, 0.05)

var auto_enter_battle := true

var profiles: Array[HeroProfile] = []
var _cards: Array[HeroCard] = []
var _current_index := -1
var _busy := false

var _backdrop: SelectBackdrop
var _portrait: HeroPortraitView
var _detail: HeroDetailPanel
var _roster: HBoxContainer
var _seal: PanelContainer
var _fade: ColorRect

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_background()
	profiles = HeroRoster.load_all()
	_build_chrome()
	if profiles.is_empty():
		_show_error()
		return
	_build_portrait()
	_build_detail()
	_build_roster()
	_build_arrows()
	_build_overlays()
	var initial := profiles[0]
	var saved := HeroRoster.load_saved_id()
	if saved != &"":
		var found := HeroRoster.find(profiles, saved)
		if found != null:
			initial = found
	select_hero(initial.id, false)
	_play_intro()
	set_process(true)

func _process(_delta: float) -> void:
	if _backdrop == null:
		return
	var mouse := get_viewport().get_mouse_position()
	_backdrop.set_parallax((mouse - Vector2(960, 540)) * -0.018)

func _unhandled_input(event: InputEvent) -> void:
	if _busy or profiles.is_empty():
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_step(1 if event.is_action_pressed("ui_right") else -1)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A:
				_step(-1)
				get_viewport().set_input_as_handled()
			KEY_D:
				_step(1)
				get_viewport().set_input_as_handled()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
				_jump(int(event.keycode - KEY_1))
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				confirm()
				get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- 公共接口

func select_hero(id: StringName, animated := true) -> bool:
	var profile := HeroRoster.find(profiles, id)
	if profile == null:
		return false
	var index := profiles.find(profile)
	if index == _current_index and animated:
		return true
	_current_index = index
	for card_index in _cards.size():
		_cards[card_index].set_selected(card_index == index)
	_portrait.show_profile(profile, animated)
	_detail.show_profile(profile, animated)
	_backdrop.set_accent(profile.accent)
	hero_changed.emit(profile)
	return true

func selected_id() -> StringName:
	if _current_index < 0 or _current_index >= profiles.size():
		return &""
	return profiles[_current_index].id

func card_count() -> int:
	return _cards.size()

func selected_profile() -> HeroProfile:
	if _current_index < 0 or _current_index >= profiles.size():
		return null
	return profiles[_current_index]

func confirm() -> void:
	if _busy or profiles.is_empty():
		return
	_busy = true
	var profile := profiles[_current_index]
	var saved := HeroRoster.save_id(profile.id)
	if saved != OK:
		push_error("Cannot save hero selection: %s" % error_string(saved))
	_detail.set_confirm_enabled(false)
	confirmed.emit(profile)
	_play_seal(profile)
	if auto_enter_battle:
		await get_tree().create_timer(0.72).timeout
		var changed := get_tree().change_scene_to_file(BATTLE_SCENE)
		if changed != OK:
			push_error("Cannot enter battle scene: %s" % error_string(changed))
			_busy = false
			_detail.set_confirm_enabled(true)
			_fade.color = Color(0, 0, 0, 0)
	else:
		await get_tree().create_timer(0.35).timeout
		_busy = false

# ---------------------------------------------------------------- 构建

func _build_background() -> void:
	var base := ColorRect.new()
	base.color = BG
	base.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)
	_backdrop = SelectBackdrop.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)

func _build_chrome() -> void:
	var title_box := VBoxContainer.new()
	title_box.position = Vector2(66, 148)
	title_box.size = Vector2(152, 500)
	title_box.add_theme_constant_override("separation", 2)
	add_child(title_box)
	for character in ["山", "海", "试", "炼"]:
		var glyph := SelectStyle.label(character, 72, SelectStyle.GOLD)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.custom_minimum_size = Vector2(152, 84)
		glyph.add_theme_constant_override("outline_size", 10)
		title_box.add_child(glyph)

	var subtitle := SelectStyle.label("择一主角\n踏入试炼", 18, SelectStyle.MUTED)
	subtitle.position = Vector2(66, 672)
	subtitle.size = Vector2(190, 70)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_constant_override("line_spacing", 8)
	subtitle.add_theme_constant_override("outline_size", 4)
	add_child(subtitle)

	var title_line := ColorRect.new()
	title_line.position = Vector2(236, 170)
	title_line.size = Vector2(1, 452)
	title_line.color = Color(1.0, 0.84, 0.46, 0.18)
	title_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_line)

	var eyebrow := SelectStyle.label("主 角 选 择", 25, SelectStyle.GOLD_SOFT)
	eyebrow.position = Vector2(288, 38)
	eyebrow.size = Vector2(360, 38)
	add_child(eyebrow)
	var underline := ColorRect.new()
	underline.position = Vector2(290, 82)
	underline.size = Vector2(300, 1)
	underline.color = Color(1.0, 0.84, 0.46, 0.28)
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(underline)

	var hint := SelectStyle.label("← → 切换    1–6 直选    Enter 确认", 16, SelectStyle.HINT)
	hint.position = Vector2(1180, 44)
	hint.size = Vector2(640, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_constant_override("outline_size", 3)
	add_child(hint)

	var version := SelectStyle.label("山海试炼 · 主角选择", 13, Color(0.55, 0.52, 0.5, 0.8))
	version.position = Vector2(1640, 1038)
	version.size = Vector2(240, 22)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)

func _build_portrait() -> void:
	_portrait = HeroPortraitView.new()
	_portrait.name = "HeroPortrait"
	_portrait.position = Vector2(250, 90)
	_portrait.size = Vector2(760, 844)
	add_child(_portrait)

func _build_detail() -> void:
	_detail = HeroDetailPanel.new()
	_detail.name = "HeroDetail"
	_detail.position = Vector2(1260, 100)
	_detail.size = Vector2(580, 890)
	_detail.confirm_pressed.connect(confirm)
	add_child(_detail)

func _build_roster() -> void:
	_roster = HBoxContainer.new()
	_roster.name = "HeroRoster"
	_roster.position = Vector2(280, 948)
	_roster.size = Vector2(900, 100)
	_roster.add_theme_constant_override("separation", 12)
	add_child(_roster)
	for profile in profiles:
		var card := HeroCard.new()
		_roster.add_child(card)
		card.setup(profile, _portrait_texture(profile))
		card.card_pressed.connect(_on_card_pressed)
		_cards.append(card)

func _build_arrows() -> void:
	var left := _arrow_button("‹")
	left.position = Vector2(184, 470)
	left.pressed.connect(func() -> void: _step(-1))
	add_child(left)
	var right := _arrow_button("›")
	right.position = Vector2(1022, 470)
	right.pressed.connect(func() -> void: _step(1))
	add_child(right)

func _build_overlays() -> void:
	_seal = PanelContainer.new()
	_seal.position = Vector2(570, 400)
	_seal.size = Vector2(240, 240)
	_seal.pivot_offset = Vector2(120, 120)
	_seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seal.visible = false
	var seal_style := StyleBoxFlat.new()
	seal_style.bg_color = Color(0.68, 0.1, 0.09, 0.94)
	seal_style.border_color = SelectStyle.GOLD
	seal_style.set_border_width_all(4)
	seal_style.set_corner_radius_all(18)
	seal_style.shadow_color = Color(0, 0, 0, 0.6)
	seal_style.shadow_size = 20
	_seal.add_theme_stylebox_override("panel", seal_style)
	var seal_label := SelectStyle.label("山 海", 62, Color(1.0, 0.94, 0.85))
	seal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	seal_label.add_theme_constant_override("outline_size", 8)
	_seal.add_child(seal_label)
	add_child(_seal)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

func _show_error() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(660, 400)
	panel.size = Vector2(600, 220)
	panel.add_theme_stylebox_override("panel", SelectStyle.panel_style(SelectStyle.DANGER))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := SelectStyle.label("角色数据缺失", 34, SelectStyle.DANGER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var hint := SelectStyle.label("请检查 res://roster/heroes 下的 6 份 HeroProfile 资源。", 18, SelectStyle.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	add_child(panel)

func _play_intro() -> void:
	_backdrop.play_intro()
	modulate.a = 0.0
	var root_tween := create_tween()
	root_tween.tween_property(self, "modulate:a", 1.0, 0.45)
	_portrait.modulate.a = 0.0
	_portrait.scale = Vector2(0.975, 0.975)
	var portrait_tween := create_tween().set_parallel(true)
	portrait_tween.tween_property(_portrait, "modulate:a", 1.0, 0.6).set_delay(0.12)
	portrait_tween.tween_property(_portrait, "scale", Vector2.ONE, 0.7).set_delay(0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for index in _cards.size():
		var card := _cards[index]
		card.modulate.a = 0.0
		var card_tween := create_tween()
		card_tween.tween_interval(0.22 + index * 0.055)
		card_tween.tween_property(card, "modulate:a", 1.0, 0.22)

func _play_seal(profile: HeroProfile) -> void:
	_seal.visible = true
	_seal.modulate.a = 0.0
	_seal.scale = Vector2(1.7, 1.7)
	_seal.rotation = deg_to_rad(-7.0)
	var strike := create_tween().set_parallel(true)
	strike.tween_property(_seal, "modulate:a", 1.0, 0.1)
	strike.tween_property(_seal, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if auto_enter_battle:
		var fade := create_tween()
		fade.tween_interval(0.2)
		fade.tween_property(_seal, "modulate:a", 0.92, 0.08)
		fade.tween_property(_fade, "color:a", 1.0, 0.34)
	else:
		var out := create_tween()
		out.tween_interval(0.45)
		out.tween_property(_seal, "modulate:a", 0.0, 0.2)

# ---------------------------------------------------------------- 输入辅助

func _step(direction: int) -> void:
	if profiles.is_empty():
		return
	var next := posmod(_current_index + direction, profiles.size())
	select_hero(profiles[next].id, true)

func _jump(index: int) -> void:
	if index < 0 or index >= profiles.size():
		return
	select_hero(profiles[index].id, true)

func _on_card_pressed(profile: HeroProfile) -> void:
	select_hero(profile.id, true)

func _portrait_texture(profile: HeroProfile) -> Texture2D:
	if profile.portrait_path.is_empty() or not ResourceLoader.exists(profile.portrait_path):
		return null
	return load(profile.portrait_path) as Texture2D

func _arrow_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size = Vector2(56, 76)
	button.custom_minimum_size = Vector2(56, 76)
	button.add_theme_font_override("font", SelectStyle.font())
	button.add_theme_font_size_override("font_size", 46)
	button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.46, 0.82))
	button.add_theme_color_override("font_hover_color", SelectStyle.GOLD)
	button.add_theme_color_override("font_pressed_color", SelectStyle.GOLD_SOFT)
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.focus_mode = Control.FOCUS_NONE
	return button
