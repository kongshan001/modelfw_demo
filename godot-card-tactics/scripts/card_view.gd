class_name CardView
extends Control

const AssetLoaderScript = preload("res://scripts/asset_loader.gd")

const AtlasAnimScript = preload("res://scripts/atlas_anim.gd")
const CardDBScript = preload("res://scripts/card_db.gd")

# 手牌卡面：阵营卡框 + 单位/法术切帧图 + 费用/攻血 + 中文规则。
# 悬停放大由卡牌自己处理；扇形排布由 main 负责。

signal clicked(index: int)
signal hover_changed(index: int, entered: bool)

const CARD_SIZE := Vector2(104, 144)

var index := 0
var card: Dictionary = {}
var selected := false
var _hovered := false

var _frame: TextureRect
var _art: TextureRect
var _name: Label
var _cost: Label
var _cost_badge: Panel
var _type_line: Label
var _desc: Label
var _atk_badge: Panel
var _hp_badge: Panel
var _atk_label: Label
var _hp_label: Label
var _glow: Panel


func setup(card_data: Dictionary, hand_index: int, db: CardDBScript) -> void:
	card = card_data
	index = hand_index
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE
	pivot_offset = CARD_SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false

	_glow = Panel.new()
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow.add_theme_stylebox_override("panel", _flat(Color(0.98, 0.78, 0.35, 0.0), 8, Color(0.98, 0.78, 0.35, 0.0), 2))
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	_frame = TextureRect.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_path := db.card_frame_path(card)
	if AssetLoaderScript.exists(frame_path):
		_frame.texture = AssetLoaderScript.texture(frame_path)
	add_child(_frame)

	_art = TextureRect.new()
	_art.position = Vector2(10, 25)
	_art.size = Vector2(84, 66)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture = _card_art(db)
	add_child(_art)

	_cost_badge = Panel.new()
	_cost_badge.position = Vector2(-4, -4)
	_cost_badge.size = Vector2(27, 27)
	_cost_badge.add_theme_stylebox_override("panel", _flat(Color("#255f9e"), 14, Color("#9fd4ff"), 2))
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)

	_cost = Label.new()
	_cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cost.text = str(int(card.get("cost", 0)))
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost.add_theme_font_size_override("font_size", 15)
	_cost.add_theme_color_override("font_color", Color("#eaf7ff"))
	_cost.add_theme_constant_override("outline_size", 2)
	_cost.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.09, 0.9))
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.add_child(_cost)

	_name = Label.new()
	_name.position = Vector2(18, 3)
	_name.size = Vector2(82, 22)
	_name.text = str(card.get("name", "?"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 11)
	_name.add_theme_color_override("font_color", Color("#f6ecd2"))
	_name.add_theme_constant_override("outline_size", 3)
	_name.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	var is_unit := String(card.get("type", "")) == "unit"
	if is_unit:
		_atk_badge = _stat_badge(Vector2(3, 72), Color("#c98a3c"), Color("#ffe0a1"))
		_atk_label = _stat_label(_atk_badge, str(int(card.get("atk", 0))))
		_hp_badge = _stat_badge(Vector2(77, 72), Color("#3f7d58"), Color("#c7f3c9"))
		_hp_label = _stat_label(_hp_badge, str(int(card.get("hp", 0))))

	_type_line = Label.new()
	_type_line.position = Vector2(4, 90)
	_type_line.size = Vector2(96, 14)
	_type_line.text = _keyword_text(is_unit)
	_type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_line.add_theme_font_size_override("font_size", 8)
	_type_line.add_theme_color_override("font_color", Color("#d7c9a5"))
	_type_line.add_theme_constant_override("outline_size", 2)
	_type_line.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 0.9))
	_type_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type_line)

	_desc = Label.new()
	_desc.position = Vector2(5, 104)
	_desc.size = Vector2(94, 36)
	_desc.text = str(card.get("desc", ""))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.add_theme_font_size_override("font_size", 8)
	_desc.add_theme_color_override("font_color", Color(0.88, 0.85, 0.77, 0.95))
	_desc.add_theme_constant_override("outline_size", 2)
	_desc.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


func _card_art(db: CardDBScript) -> Texture2D:
	if String(card.get("type", "")) == "unit":
		return AtlasAnimScript.static_frame(str(card.get("sprite", "")), "units", "idle", 0)
	var icon := str(card.get("icon", ""))
	if icon.is_empty():
		return null
	return AtlasAnimScript.static_frame(icon, "icons", "", 0)


func _keyword_text(is_unit: bool) -> String:
	if not is_unit:
		return "法术 · " + db_faction_text(String(card.get("faction", "neutral")))
	var words: Array[String] = []
	var keywords: Array = card.get("keywords", [])
	if "ranged" in keywords:
		words.append("远程")
	if "provoke" in keywords:
		words.append("嘲讽")
	if "rush" in keywords:
		words.append("疾行")
	if int(card.get("opening_heal", 0)) > 0:
		words.append("登场治疗")
	if words.is_empty():
		words.append("随从")
	return " · ".join(words)


func db_faction_text(faction: String) -> String:
	match faction:
		"f1": return "晨光"
		"f2": return "风间"
		_: return "中立"


func _stat_badge(pos: Vector2, bg: Color, border: Color) -> Panel:
	var badge := Panel.new()
	badge.position = pos
	badge.size = Vector2(24, 24)
	badge.add_theme_stylebox_override("panel", _flat(bg, 12, border, 2))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	return badge


func _stat_label(badge: Panel, value: String) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#fff8e5"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return label


func set_selected(value: bool) -> void:
	selected = value
	if _glow:
		var border := Color(1.0, 0.8, 0.36, 0.95) if value else Color(0.98, 0.78, 0.35, 0.0)
		_glow.add_theme_stylebox_override("panel", _flat(Color(0.98, 0.78, 0.35, 0.0), 8, border, 2))
	if value:
		z_index = 40
		scale = Vector2(1.1, 1.1)
	elif not _hovered:
		z_index = 0
		scale = Vector2.ONE


func _on_mouse_entered() -> void:
	_hovered = true
	z_index = 60
	scale = Vector2(1.34, 1.34)
	if _frame:
		_frame.modulate = Color(1.08, 1.08, 1.08)
	hover_changed.emit(index, true)


func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 40 if selected else 0
	scale = Vector2(1.1, 1.1) if selected else Vector2.ONE
	if _frame:
		_frame.modulate = Color.WHITE
	hover_changed.emit(index, false)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(index)
			accept_event()


func _flat(bg: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	return style
