class_name HeroCard
extends Button

# 底部角色长廊的一张卡：头部缩略图、姓名、职业；选中金框 + 主色底线。

signal card_pressed(profile: HeroProfile)

const CARD_SIZE := Vector2(138, 100)

var profile: HeroProfile
var _thumb: TextureRect
var _glyph: PanelContainer
var _name_label: Label
var _class_label: Label
var _accent_line: ColorRect
var _selected := false
var _accent := Color(0.45, 0.8, 1.0)

func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	pivot_offset = CARD_SIZE * 0.5
	_build()
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

func _build() -> void:
	_name_label = SelectStyle.label("", 20, SelectStyle.TEXT)
	_name_label.position = Vector2(72, 16)
	_name_label.size = Vector2(58, 26)
	add_child(_name_label)

	_class_label = SelectStyle.label("", 14, SelectStyle.MUTED)
	_class_label.position = Vector2(72, 46)
	_class_label.size = Vector2(58, 20)
	add_child(_class_label)

	_thumb = TextureRect.new()
	_thumb.position = Vector2(10, 12)
	_thumb.size = Vector2(54, 54)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_thumb)

	_glyph = PanelContainer.new()
	_glyph.position = Vector2(10, 12)
	_glyph.size = Vector2(54, 54)
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.visible = false
	add_child(_glyph)

	_accent_line = ColorRect.new()
	_accent_line.position = Vector2(10, 86)
	_accent_line.size = Vector2(118, 2)
	_accent_line.color = Color(1.0, 0.84, 0.46, 0.28)
	_accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_accent_line)

func setup(hero: HeroProfile, texture: Texture2D) -> void:
	profile = hero
	_accent = hero.accent
	_name_label.text = hero.display_name
	_class_label.text = hero.hero_class
	_name_label.add_theme_color_override("font_color", SelectStyle.TEXT)
	if texture != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(300, 30, 424, 424)
		_thumb.texture = atlas
		_thumb.visible = true
		_glyph.visible = false
	else:
		_thumb.visible = false
		_glyph.visible = true
		_glyph.add_theme_stylebox_override("panel", _glyph_style())
		for child in _glyph.get_children():
			child.queue_free()
		var glyph := SelectStyle.label(_class_glyph(hero.hero_class), 24, Color(1.0, 0.96, 0.86))
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_glyph.add_child(glyph)
	_apply_style()

func set_selected(value: bool) -> void:
	if _selected == value:
		return
	_selected = value
	_apply_style()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE if value else Vector2(0.97, 0.97), 0.18).set_trans(Tween.TRANS_CUBIC)

func _apply_style() -> void:
	if profile == null:
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.13, 0.14, 0.12) if _selected else Color(0.07, 0.05, 0.085, 0.9)
	normal.border_color = SelectStyle.GOLD if _selected else SelectStyle.GOLD_DIM
	normal.set_border_width_all(2 if _selected else 1)
	normal.set_corner_radius_all(10)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.18, 0.15, 0.12)
	hover.border_color = SelectStyle.GOLD_SOFT
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.1, 0.08, 0.1)
	pressed.border_color = _accent
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if _accent_line != null:
		_accent_line.color = Color(_accent.r, _accent.g, _accent.b, 0.85 if _selected else 0.16)

func _glyph_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(_accent.r, _accent.g, _accent.b, 0.16)
	style.border_color = Color(_accent.r, _accent.g, _accent.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(27)
	return style

func _class_glyph(hero_class: String) -> String:
	match hero_class:
		"剑客":
			return "剑"
		"法师":
			return "法"
		"医师":
			return "医"
		_:
			return "?"

func _on_pressed() -> void:
	if profile != null:
		card_pressed.emit(profile)

func _on_hover(entered: bool) -> void:
	if _selected:
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.15, 1.12, 1.08) if entered else Color.WHITE, 0.14)
