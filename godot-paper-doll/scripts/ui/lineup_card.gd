class_name LineupCard
extends PanelContainer

# 4×4 阵容中的一张卡：点击载入试衣镜，右上角 ↻ 只重掷这一位。

signal pressed(index: int)
signal reroll_requested(index: int)

var index := 0
var entry: Dictionary = {}
var doll: PaperDollRenderer

var _name_label: Label
var _preview: Control
var _thumb: DollThumbnail
var _dice: Button
var _built := false
var _selected := false
var _signature := ""


func setup(idx: int, data: Dictionary) -> void:
	index = idx
	_ensure_built()
	apply_entry(data)


func _ensure_built() -> void:
	if _built:
		return
	_built = true
	custom_minimum_size = Vector2(126, 130)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("panel", AtelierTheme.card_style(false))
	tooltip_text = "点击载入到试衣镜"

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 1)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	column.add_child(header)
	_name_label = AtelierTheme.make_label("", 11)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.clip_text = true
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_name_label)
	_dice = Button.new()
	_dice.text = "↻"
	_dice.tooltip_text = "只重掷这一位"
	_dice.custom_minimum_size = Vector2(24, 22)
	_dice.add_theme_font_size_override("font_size", 13)
	AtelierTheme.style_button(_dice, 12)
	_dice.pressed.connect(func() -> void: reroll_requested.emit(index))
	header.add_child(_dice)

	_preview = Control.new()
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview.clip_contents = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_preview)

	_thumb = DollThumbnail.new()
	_thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.add_child(_thumb)
	doll = _thumb.doll
	doll.show_effects = false


func apply_entry(data: Dictionary) -> void:
	entry = data
	var dir := clampi(int(data["direction"]), 0, 7)
	var action := str(data["action"])
	_name_label.text = "%s %s" % [DollData.DIRS[dir]["label"], data["name"]]
	# 卡片只烘焙一张快照，避免 16 个实时木偶同时提交上千条绘制指令。
	# 17 套外观签名相同则跳过重烘焙，随机当前纸偶时不会连带卡顿阵容。
	var signature := DollData.outfit_signature(data["outfit"])
	if signature == _signature and doll.direction == dir and doll.action == action:
		return
	_signature = signature
	_thumb.set_doll(data["outfit"], dir, action, 0.56,
			DollData.showcase_time(index, action), 4.0, true)


func set_selected(value: bool) -> void:
	_selected = value
	add_theme_stylebox_override("panel", AtelierTheme.card_style(value))
	queue_redraw()


func set_clock(value: float) -> void:
	_thumb.set_clock(value)


func set_animate(_value: bool) -> void:
	# 阵容卡是烘焙快照；动作与方向变化时由 apply_entry 重新烘焙。
	pass


func clip_ok() -> bool:
	return _preview != null and _preview.clip_contents


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(index)
		accept_event()


func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y - 23.0)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.30))
	draw_circle(Vector2.ZERO, 36.0, Color(0.23, 0.18, 0.26, 0.09))
	draw_set_transform(center, 0.0, Vector2(1.0, 0.20))
	draw_circle(Vector2.ZERO, 28.0, Color(0.25, 0.61, 0.54, 0.12))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _selected:
		draw_circle(Vector2(size.x - 12, 11), 3.6, AtelierTheme.CORAL_DEEP)
