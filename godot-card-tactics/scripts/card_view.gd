class_name CardView
extends Control

const AssetLoaderScript = preload("res://scripts/asset_loader.gd")

const AtlasAnimScript = preload("res://scripts/atlas_anim.gd")
const CardDBScript = preload("res://scripts/card_db.gd")

# 手牌卡面：阵营卡框 + 单位/法术切帧图 + 费用/攻血 + 中文规则。
# 悬停放大由卡牌自己处理；扇形排布由 main 负责。
# T-019 美术整改：名称 12 / 类型 10 / 描述 10（≤16 字，最多 2 行），
# 名称带与规则区加深色内衬；悬停 1.24；不可出牌时费用徽章转红、卡面降亮；
# 选中改用近白描边，把金色留给“召唤位置”。

signal clicked(index: int)
signal hover_changed(index: int, entered: bool)

const CARD_SIZE := Vector2(104, 144)
const NAME_SIZE := 12
const TYPE_SIZE := 10
const DESC_SIZE := 10
const HOVER_SCALE := 1.24
const SELECT_SCALE := 1.1

static var _card_bold: SystemFont

const SHORT_DESC := {
	"f1_silverguardsquire": "朴实可靠的前排。",
	"f1_backlinearcher": "2 格直线 · 视线阻挡。",
	"f1_sunstonetemplar": "攻守均衡的中坚。",
	"f1_windbladecommander": "相邻敌人优先攻击它。",
	"f1_ironcliffeguardian": "厚实的前排壁垒。",
	"f2_onyxjaguar": "召唤当回合即可攻击。",
	"f2_sparrowhawk": "2 格直线攻击。",
	"f2_lanternfox": "轻盈的灵兽。",
	"f2_mage4winds": "2 格直线攻击。",
	"f2_heartofthesonghai": "高攻高血的大将。",
	"neutral_healingmystic": "己方将军回复 2 生命。",
	"neutral_bonereaper": "中立的稳健打手。",
	"f1_sundropelixir": "友方目标回复 4 生命。",
	"f1_truestrike": "敌方随从受到 3 伤害。",
	"f2_phoenixfire": "敌方目标受到 3 伤害。",
	"f2_cobrastrike": "友方随从永久 +2 攻击。",
}

var index := 0
var card: Dictionary = {}
var selected := false
var _hovered := false
var _affordable := true

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
	_glow.add_theme_stylebox_override("panel", _flat(Color(0.0, 0.0, 0.0, 0.0), 8, Color(0.0, 0.0, 0.0, 0.0), 2))
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
	_art.position = Vector2(10, 27)
	_art.size = Vector2(84, 54)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.texture = _card_art(db)
	add_child(_art)

	# 名称带暗幕（y=0–28）与规则区暗幕（y=84–144），保证亮斑上仍可读。
	var name_plate := Panel.new()
	name_plate.position = Vector2(4, 1)
	name_plate.size = Vector2(96, 26)
	name_plate.add_theme_stylebox_override("panel", _flat(Color(0.024, 0.050, 0.078, 0.72), 5, Color(0.0, 0.0, 0.0, 0.0), 0))
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_plate)

	var text_plate := Panel.new()
	text_plate.position = Vector2(2, 84)
	text_plate.size = Vector2(100, 58)
	text_plate.add_theme_stylebox_override("panel", _flat(Color(0.024, 0.050, 0.078, 0.82), 4, Color(0.95, 0.87, 0.69, 0.10), 1))
	text_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(text_plate)

	_cost_badge = Panel.new()
	_cost_badge.position = Vector2(-4, -4)
	_cost_badge.size = Vector2(28, 28)
	_cost_badge.add_theme_stylebox_override("panel", _cost_style(true))
	_cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_badge)

	_cost = Label.new()
	_cost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cost.text = str(int(card.get("cost", 0)))
	_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cost.add_theme_font_size_override("font_size", 16)
	_cost.add_theme_font_override("font", _bold())
	_cost.add_theme_color_override("font_color", Color("#eaf7ff"))
	_cost.add_theme_constant_override("outline_size", 2)
	_cost.add_theme_color_override("font_outline_color", Color(0.01, 0.04, 0.09, 0.9))
	_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cost_badge.add_child(_cost)

	_name = Label.new()
	_name.position = Vector2(15, 2)
	_name.size = Vector2(86, 22)
	_name.text = str(card.get("name", "?"))
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", NAME_SIZE)
	_name.add_theme_font_override("font", _bold())
	_name.add_theme_color_override("font_color", Color("#f8efd8"))
	_name.add_theme_constant_override("outline_size", 2)
	_name.add_theme_color_override("font_outline_color", Color(0.04, 0.03, 0.02, 0.95))
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name)

	var is_unit := String(card.get("type", "")) == "unit"
	if is_unit:
		_atk_badge = _stat_badge(Vector2(3, 69), Color("#c98a3c"), Color("#ffe0a1"))
		_atk_label = _stat_label(_atk_badge, str(int(card.get("atk", 0))))
		_hp_badge = _stat_badge(Vector2(77, 69), Color("#3f7d58"), Color("#c7f3c9"))
		_hp_label = _stat_label(_hp_badge, str(int(card.get("hp", 0))))

	_type_line = Label.new()
	_type_line.position = Vector2(5, 93)
	_type_line.size = Vector2(94, 13)
	_type_line.text = _keyword_text(is_unit)
	_type_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_type_line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_line.add_theme_font_size_override("font_size", TYPE_SIZE)
	_type_line.add_theme_font_override("font", _bold())
	_type_line.add_theme_color_override("font_color", Color("#e6d8b4"))
	_type_line.add_theme_constant_override("outline_size", 2)
	_type_line.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 0.9))
	_type_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type_line)

	_desc = Label.new()
	_desc.position = Vector2(5, 107)
	_desc.size = Vector2(94, 34)
	_desc.text = _display_desc()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_desc.max_lines_visible = 2
	_desc.clip_text = true
	_desc.add_theme_font_size_override("font_size", DESC_SIZE)
	_desc.add_theme_font_override("font", _bold())
	_desc.add_theme_constant_override("line_spacing", 0)
	_desc.add_theme_color_override("font_color", Color("#f2ead6"))
	_desc.add_theme_constant_override("outline_size", 1)
	_desc.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 0.85))
	_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc)

	# 选中描边必须在卡框之上才可见；glow 只画 2px 边框，不影响卡面内容。
	move_child(_glow, get_child_count() - 1)
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


func _display_desc() -> String:
	var id := String(card.get("id", ""))
	if SHORT_DESC.has(id):
		return String(SHORT_DESC[id])
	var text := str(card.get("desc", ""))
	if text.length() > 18:
		text = text.substr(0, 18)
	return text


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
	badge.add_theme_stylebox_override("panel", _flat_shadow(bg, 12, border, 2))
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
	label.add_theme_font_override("font", _bold())
	label.add_theme_color_override("font_color", Color("#fff8e5"))
	label.add_theme_constant_override("outline_size", 2)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.03, 0.95))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return label


func set_selected(value: bool) -> void:
	selected = value
	if _glow:
		var border := Color(0.97, 0.95, 0.88, 0.95) if value else Color(0.0, 0.0, 0.0, 0.0)
		_glow.add_theme_stylebox_override("panel", _flat(Color(0.0, 0.0, 0.0, 0.0), 8, border, 2))
	if value:
		z_index = 40
		scale = Vector2(HOVER_SCALE, HOVER_SCALE) if _hovered else Vector2(SELECT_SCALE, SELECT_SCALE)
	elif not _hovered:
		z_index = 0
		scale = Vector2.ONE


func set_affordable(value: bool) -> void:
	if value == _affordable:
		return
	_affordable = value
	if _cost_badge:
		_cost_badge.add_theme_stylebox_override("panel", _cost_style(value))
	if _cost:
		_cost.add_theme_color_override("font_color", Color("#eaf7ff") if value else Color("#ffd9d0"))
	if _art:
		_art.modulate = Color.WHITE if value else Color(0.60, 0.60, 0.64)
	_apply_frame_modulate()


func set_interactive(value: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if value:
		return
	_hovered = false
	z_index = 40 if selected else 0
	scale = Vector2(SELECT_SCALE, SELECT_SCALE) if selected else Vector2.ONE
	_apply_frame_modulate()


func _on_mouse_entered() -> void:
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	_hovered = true
	z_index = 60
	scale = Vector2(HOVER_SCALE, HOVER_SCALE)
	_apply_frame_modulate()
	hover_changed.emit(index, true)


func _on_mouse_exited() -> void:
	_hovered = false
	z_index = 40 if selected else 0
	scale = Vector2(SELECT_SCALE, SELECT_SCALE) if selected else Vector2.ONE
	_apply_frame_modulate()
	hover_changed.emit(index, false)


func _apply_frame_modulate() -> void:
	if _frame == null:
		return
	var v := 1.08 if _hovered else 1.0
	if not _affordable:
		v *= 0.72
	_frame.modulate = Color(v, v, v)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(index)
			accept_event()


func _bold() -> SystemFont:
	if _card_bold == null:
		_card_bold = SystemFont.new()
		_card_bold.font_names = PackedStringArray([
			"PingFang SC", "Hiragino Sans GB", "Heiti SC", "Noto Sans CJK SC",
			"Microsoft YaHei", "WenQuanYi Micro Hei", "sans-serif",
		])
		_card_bold.font_weight = 650
		_card_bold.allow_system_fallback = true
	return _card_bold


func _cost_style(affordable: bool) -> StyleBoxFlat:
	var bg := Color("#255f9e") if affordable else Color("#6e3038")
	var border := Color("#9fd4ff") if affordable else Color("#ff9a8f")
	var style := _flat_shadow(bg, 14, border, 2)
	return style


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


func _flat_shadow(bg: Color, radius: int, border: Color, border_width: int) -> StyleBoxFlat:
	var style := _flat(bg, radius, border, border_width)
	style.shadow_color = Color(0.01, 0.02, 0.03, 0.75)
	style.shadow_size = 2
	return style
