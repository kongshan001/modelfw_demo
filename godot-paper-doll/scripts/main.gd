extends Control

# 纸偶工坊主控：状态、试衣镜、衣柜、4×4 阵容、存档与对照弹层。
# 所有外观数据在内存中是 {slot: {variant, color}}，导出时再转 JSON。

const SAVE_PATH := "user://paperdoll_outfit.json"
const LINEUP_COUNT := 16

var studio: PaperDollRenderer
var cards: Array[LineupCard] = []
var slot_buttons: Dictionary = {}
var variant_buttons: Array[Button] = []
var color_buttons: Array[Button] = []
var dir_buttons: Dictionary = {}
var action_buttons: Array[Button] = []
var name_label: Label
var studio_info: Label
var variant_header: Label
var color_header: Label
var status_label: Label
var fps_label: Label
var combo_label: Label

var _outfit: Dictionary = {}
var _direction := 0
var _action := "idle"
var _selected_slot := "shirt"
var _lineup: Array = []
var _selected_card := 0
var _doll_name := "我的纸偶"
var _rng := RandomNumberGenerator.new()
var _fps_clock := 0.0
var _preview: Control
var _variant_grid: GridContainer
var _color_grid: GridContainer
var _content: MarginContainer
var _overlay: Control = null
var _overlay_dolls: Array = []
var _overlay_thumbs: Array = []
var _overlay_kind := ""
var _save_path := SAVE_PATH
var _preview_tag: Label
var _layer_button: Button
var _layer_view := false
var _show_mode := false
var _show_stage: Control


func _ready() -> void:
	theme = AtelierTheme.make_theme()
	_rng.randomize()
	resized.connect(queue_redraw)

	_lineup = DollData.load_lineup()
	if _lineup.size() != LINEUP_COUNT:
		_lineup = DollData.fallback_lineup()
	_apply_entry_to_state(_lineup[0])
	_selected_card = 0
	_build_ui()
	_refresh_all()
	_status("17 槽位就绪 · 点击阵容载入，↻ 单抽，R 随机")
	set_process(true)


func _process(delta: float) -> void:
	_fps_clock += delta
	if _fps_clock >= 0.5 and fps_label != null:
		_fps_clock = 0.0
		fps_label.text = "FPS %d" % Engine.get_frames_per_second()


# ------------------------------------------------------------------ 背景

func _draw() -> void:
	var w := size.x
	var h := size.y
	var top := Color("#f8f1e4")
	var bottom := Color("#eadbc6")
	for i in 22:
		var t := float(i) / 21.0
		draw_rect(Rect2(0, h * t / 22.0, w, h / 22.0 + 1.0), top.lerp(bottom, t))
	draw_circle(Vector2(70, 68), 190, Color(0.91, 0.42, 0.36, 0.07))
	draw_circle(Vector2(w - 46, h - 30), 230, Color(0.25, 0.61, 0.54, 0.08))
	draw_circle(Vector2(w * 0.44, -30), 140, Color(0.95, 0.70, 0.30, 0.08))
	for x in range(22, int(w), 30):
		for y in range(20, int(h), 30):
			draw_circle(Vector2(x, y), 1.1, Color(0.23, 0.18, 0.26, 0.055))
	for tape in [
		[Vector2(22, 22), 0.42], [Vector2(w - 76, 16), -0.35], [Vector2(w - 58, h - 36), 0.5],
	]:
		var center: Vector2 = tape[0]
		draw_set_transform(center, tape[1], Vector2.ONE)
		draw_rect(Rect2(-26, -9, 52, 18), Color(0.95, 0.82, 0.56, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var stitch := Color(0.23, 0.18, 0.26, 0.16)
	draw_dashed_line(Vector2(9, 9), Vector2(w - 9, 9), stitch, 1.2, 6.0)
	draw_dashed_line(Vector2(w - 9, 9), Vector2(w - 9, h - 9), stitch, 1.2, 6.0)
	draw_dashed_line(Vector2(w - 9, h - 9), Vector2(9, h - 9), stitch, 1.2, 6.0)
	draw_dashed_line(Vector2(9, h - 9), Vector2(9, 9), stitch, 1.2, 6.0)


# ------------------------------------------------------------------ 界面构建

func _build_ui() -> void:
	_content = MarginContainer.new()
	_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		_content.add_theme_constant_override("margin_" + side, 14)
	add_child(_content)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_content.add_child(column)
	column.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)
	body.add_child(_build_studio_panel())
	body.add_child(_build_wardrobe_panel())
	body.add_child(_build_lineup_panel())
	column.add_child(_build_footer())


func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 50)
	header.add_theme_constant_override("separation", 10)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -3)
	var title := AtelierTheme.make_label("纸偶工坊", 28, AtelierTheme.INK)
	title.add_theme_color_override("font_shadow_color", Color(1, 0.99, 0.95, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 1)
	titles.add_child(title)
	titles.add_child(AtelierTheme.make_label(
			"PAPERDOLL ATELIER · 17 SLOTS × 8 DIRECTIONS × 4 ACTIONS", 10, AtelierTheme.MUTED))
	header.add_child(titles)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var combo_panel := PanelContainer.new()
	combo_panel.add_theme_stylebox_override("panel", AtelierTheme.inner_style(10, Color("#fff3df")))
	combo_label = AtelierTheme.make_label(DollData.combination_text(), 11, AtelierTheme.MUTED)
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	combo_panel.add_child(combo_label)
	header.add_child(combo_panel)

	var random_doll := Button.new()
	random_doll.text = "随机纸偶"
	random_doll.custom_minimum_size = Vector2(104, 34)
	random_doll.tooltip_text = "随机 17 个槽位（R）"
	AtelierTheme.style_button(random_doll, 12)
	random_doll.pressed.connect(randomize_current)
	header.add_child(random_doll)

	var random_lineup := Button.new()
	random_lineup.text = "随机阵容"
	random_lineup.custom_minimum_size = Vector2(104, 34)
	random_lineup.tooltip_text = "重掷 4×4 全员"
	AtelierTheme.style_button(random_lineup, 12)
	random_lineup.pressed.connect(randomize_lineup)
	header.add_child(random_lineup)
	return header


func _build_studio_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(348, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", AtelierTheme.panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_child(AtelierTheme.make_label("试衣镜", 14))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	name_label = AtelierTheme.make_label(_doll_name, 11, AtelierTheme.CORAL_DEEP)
	head.add_child(name_label)
	var layer_toggle := Button.new()
	layer_toggle.text = "层视"
	layer_toggle.tooltip_text = "把 17 层沿右下展开，选中槽高亮（层视模式）"
	layer_toggle.custom_minimum_size = Vector2(52, 22)
	AtelierTheme.style_button(layer_toggle, 11)
	layer_toggle.pressed.connect(toggle_layer_view)
	head.add_child(layer_toggle)
	_layer_button = layer_toggle
	column.add_child(head)

	var preview_panel := PanelContainer.new()
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.custom_minimum_size = Vector2(0, 376)
	preview_panel.clip_contents = true
	preview_panel.add_theme_stylebox_override("panel", AtelierTheme.inner_style(12, Color("#f3e7d4")))
	_preview = Control.new()
	_preview.clip_contents = true
	_preview.resized.connect(_layout_studio)
	preview_panel.add_child(_preview)
	column.add_child(preview_panel)

	var stage := StageBackdrop.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.add_child(stage)
	studio = PaperDollRenderer.new()
	studio.show_shadow = true
	_preview.add_child(studio)
	studio.set_display_scale(2.10)
	studio.time_offset = 0.0

	_preview_tag = AtelierTheme.make_label("纸面舞台 · 主光左上 · 轮廓光右", 11, AtelierTheme.MUTED)
	_preview.add_child(_preview_tag)
	studio_info = AtelierTheme.make_label("", 11, AtelierTheme.INK)
	_preview.add_child(studio_info)

	column.add_child(AtelierTheme.make_label("方向 · 8", 11, AtelierTheme.MUTED))
	var direction_grid := GridContainer.new()
	direction_grid.columns = 3
	direction_grid.add_theme_constant_override("h_separation", 4)
	direction_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(direction_grid)
	for cell in [3, 4, 5, 2, -1, 6, 1, 0, 7]:
		if cell == -1:
			var center_tag := AtelierTheme.make_label("方向", 11, AtelierTheme.MUTED)
			center_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			center_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			direction_grid.add_child(center_tag)
			continue
		var dir: Dictionary = DollData.DIRS[cell]
		var button := Button.new()
		button.text = "%s %s" % [dir["label"], dir["name"]]
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "面向" + str(dir["name"])
		AtelierTheme.style_button(button, 11)
		button.pressed.connect(set_direction.bind(cell))
		direction_grid.add_child(button)
		dir_buttons[cell] = button

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 4)
	column.add_child(action_row)
	for i in DollData.ACTIONS.size():
		var act: Dictionary = DollData.ACTIONS[i]
		var button := Button.new()
		button.text = act["label"]
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = act["hint"]
		AtelierTheme.style_button(button, 12)
		button.pressed.connect(set_action.bind(act["id"]))
		action_row.add_child(button)
		action_buttons.append(button)

	var sheet_row := HBoxContainer.new()
	sheet_row.add_theme_constant_override("separation", 4)
	column.add_child(sheet_row)
	var dirs_button := Button.new()
	dirs_button.text = "8 向罗盘"
	dirs_button.custom_minimum_size = Vector2(0, 26)
	dirs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AtelierTheme.style_button(dirs_button, 11)
	dirs_button.pressed.connect(show_directions_sheet)
	sheet_row.add_child(dirs_button)
	var actions_button := Button.new()
	actions_button.text = "动作 · 3 关键帧"
	actions_button.custom_minimum_size = Vector2(0, 26)
	actions_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AtelierTheme.style_button(actions_button, 11)
	actions_button.pressed.connect(show_actions_sheet)
	sheet_row.add_child(actions_button)
	return panel


func _build_wardrobe_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(336, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", AtelierTheme.panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_child(AtelierTheme.make_label("衣柜 · 17 槽位", 14))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var random_slot := Button.new()
	random_slot.text = "本槽随机"
	random_slot.custom_minimum_size = Vector2(76, 24)
	AtelierTheme.style_button(random_slot, 11)
	random_slot.pressed.connect(_randomize_slot)
	head.add_child(random_slot)
	column.add_child(head)

	var slot_grid := GridContainer.new()
	slot_grid.columns = 3
	slot_grid.add_theme_constant_override("h_separation", 4)
	slot_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(slot_grid)
	for slot in DollData.SLOTS:
		var button := Button.new()
		button.text = str(slot["label"])
		button.custom_minimum_size = Vector2(0, 32)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = "选择 %s 槽位" % slot["label"]
		AtelierTheme.style_button(button, 11)
		button.pressed.connect(set_selected_slot.bind(str(slot["id"])))
		slot_grid.add_child(button)
		slot_buttons[slot["id"]] = button

	var variant_head := HBoxContainer.new()
	variant_header = AtelierTheme.make_label("变体", 12, AtelierTheme.INK)
	variant_head.add_child(variant_header)
	var vspacer := Control.new()
	vspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	variant_head.add_child(vspacer)
	column.add_child(variant_head)

	_variant_grid = GridContainer.new()
	_variant_grid.columns = 3
	_variant_grid.add_theme_constant_override("h_separation", 4)
	_variant_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_variant_grid)

	color_header = AtelierTheme.make_label("颜色", 12, AtelierTheme.INK)
	column.add_child(color_header)
	_color_grid = GridContainer.new()
	_color_grid.columns = 8
	_color_grid.add_theme_constant_override("h_separation", 4)
	_color_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_color_grid)

	var note := AtelierTheme.make_label(
			"每个槽位独立染色；方向与动作不改变槽位层级。", 11, AtelierTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(0, 30)
	column.add_child(note)
	var tip := AtelierTheme.make_label("1-4 动作 · ←→ 方向 · Tab 焦点 · R 随机 · S/L 存读 · F11 舞台", 11, AtelierTheme.MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(0, 30)
	column.add_child(tip)
	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tail)
	return panel


func _build_lineup_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", AtelierTheme.panel_style())
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)

	var head := HBoxContainer.new()
	head.add_child(AtelierTheme.make_label("阵容 · 4×4", 14))
	head.add_child(AtelierTheme.make_label("   点击载入 · ↻ 单抽", 11, AtelierTheme.MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(AtelierTheme.make_label("16 位独立纸偶", 11, AtelierTheme.MUTED))
	column.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for i in LINEUP_COUNT:
		if i >= _lineup.size():
			break
		var card := LineupCard.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.setup(i, _lineup[i])
		card.pressed.connect(_on_card_pressed)
		card.reroll_requested.connect(_on_card_reroll)
		grid.add_child(card)
		cards.append(card)
	return panel


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.custom_minimum_size = Vector2(0, 26)
	footer.add_theme_constant_override("separation", 8)
	status_label = AtelierTheme.make_label("", 11, AtelierTheme.MUTED)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.clip_text = true
	footer.add_child(status_label)
	var save_button := Button.new()
	save_button.text = "保存 JSON"
	save_button.custom_minimum_size = Vector2(90, 24)
	AtelierTheme.style_button(save_button, 11)
	save_button.pressed.connect(save_current)
	footer.add_child(save_button)
	var load_button := Button.new()
	load_button.text = "读取 JSON"
	load_button.custom_minimum_size = Vector2(90, 24)
	AtelierTheme.style_button(load_button, 11)
	load_button.pressed.connect(load_saved)
	footer.add_child(load_button)
	fps_label = AtelierTheme.make_label("FPS --", 11, AtelierTheme.TEAL_DEEP)
	fps_label.custom_minimum_size = Vector2(58, 0)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer.add_child(fps_label)
	return footer


# ------------------------------------------------------------------ 布局

func _layout_studio() -> void:
	if studio == null or _preview == null:
		return
	studio.position = Vector2(_preview.size.x * 0.5, _preview.size.y - 18.0)
	if _preview_tag != null:
		_preview_tag.position = Vector2(10, 7)
	if studio_info != null:
		studio_info.position = Vector2(10, _preview.size.y - 23.0)
		studio_info.size = Vector2(_preview.size.x - 20, 16)


# ------------------------------------------------------------------ 刷新

func _refresh_all() -> void:
	_refresh_studio()
	_refresh_slot_styles()
	_rebuild_variant_buttons()
	_refresh_color_grid()
	_refresh_direction_styles()
	_refresh_action_styles()
	_refresh_cards()


func _refresh_studio() -> void:
	if studio == null:
		return
	studio.set_doll(_outfit, _direction, _action)
	studio.set_explode(1.0 if _layer_view else 0.0)
	studio.highlight_slot = _selected_slot if _layer_view else ""
	_layout_studio()
	var dir: Dictionary = DollData.DIRS[_direction]
	name_label.text = _doll_name
	var slot_name := str(DollData.slot_by_id(_selected_slot).get("label", _selected_slot))
	studio_info.text = "层视 · 17 层 · 选中：%s" % slot_name if _layer_view else "%s %s · %s · 17 层" % [dir["label"], dir["name"], DollData.action_label(_action)]
	if _layer_button != null:
		AtelierTheme.style_toggle(_layer_button, _layer_view, AtelierTheme.TEAL_DEEP, 11)


func _refresh_slot_styles() -> void:
	for slot in DollData.SLOTS:
		var slot_id: String = slot["id"]
		var button: Button = slot_buttons[slot_id]
		var entry: Dictionary = _outfit[slot_id]
		var variant: Dictionary = DollData.variant_by_id(slot_id, str(entry["variant"]))
		button.text = "%s · %s" % [slot["label"], variant.get("label", "?")]
		AtelierTheme.style_toggle(button, slot_id == _selected_slot, AtelierTheme.CORAL_DEEP, 11)


func _rebuild_variant_buttons() -> void:
	_clear_children(_variant_grid)
	variant_buttons.clear()
	var slot: Dictionary = DollData.slot_by_id(_selected_slot)
	var variants: Array = slot["variants"]
	variant_header.text = "变体 · %s（%d）" % [slot["label"], variants.size()]
	for variant in variants:
		var button := Button.new()
		button.text = str(variant["label"])
		button.custom_minimum_size = Vector2(0, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(set_slot_variant.bind(_selected_slot, str(variant["id"])))
		_variant_grid.add_child(button)
		variant_buttons.append(button)
	_refresh_variant_styles()


func _refresh_variant_styles() -> void:
	var slot: Dictionary = DollData.slot_by_id(_selected_slot)
	var current := str(_outfit[_selected_slot]["variant"])
	for i in variant_buttons.size():
		var variant_id: String = slot["variants"][i]["id"]
		AtelierTheme.style_toggle(variant_buttons[i], variant_id == current, AtelierTheme.TEAL_DEEP, 11)


func _refresh_color_grid() -> void:
	_clear_children(_color_grid)
	color_buttons.clear()
	var palette := DollData.palette_for(_selected_slot)
	var current: Color = _outfit[_selected_slot]["color"]
	color_header.text = "颜色 · %s · #%s" % [DollData.slot_by_id(_selected_slot)["label"],
			current.to_html(false)]
	for i in palette.size():
		var swatch: Button = Button.new()
		var color: Color = palette[i]
		swatch.text = "✓" if color.is_equal_approx(current) else ""
		swatch.custom_minimum_size = Vector2(33, 30)
		swatch.tooltip_text = "#" + color.to_html(false)
		swatch.focus_mode = Control.FOCUS_ALL
		swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swatch.add_theme_font_override("font", AtelierTheme.font())
		swatch.add_theme_font_size_override("font_size", 12)
		swatch.add_theme_color_override("font_color", AtelierTheme.contrast_text(color))
		swatch.add_theme_stylebox_override("normal", _swatch_style(color, color.is_equal_approx(current)))
		swatch.add_theme_stylebox_override("hover", _swatch_style(color.lightened(0.10), color.is_equal_approx(current)))
		swatch.add_theme_stylebox_override("pressed", _swatch_style(color.darkened(0.08), true))
		swatch.add_theme_stylebox_override("focus", AtelierTheme.focus_style())
		swatch.pressed.connect(_on_color_pressed.bind(i))
		_color_grid.add_child(swatch)
		color_buttons.append(swatch)


func _refresh_direction_styles() -> void:
	for i in dir_buttons.keys():
		AtelierTheme.style_toggle(dir_buttons[i], int(i) == _direction, AtelierTheme.CORAL_DEEP, 11)


func _refresh_action_styles() -> void:
	for i in action_buttons.size():
		AtelierTheme.style_toggle(action_buttons[i], DollData.ACTIONS[i]["id"] == _action,
				AtelierTheme.PLUM_DEEP, 12)


func _refresh_cards() -> void:
	for i in cards.size():
		cards[i].apply_entry(_lineup[i])
		cards[i].set_selected(i == _selected_card)


# ------------------------------------------------------------------ 交互

func set_selected_slot(slot_id: String) -> void:
	if DollData.slot_by_id(slot_id).is_empty():
		return
	_selected_slot = slot_id
	_refresh_slot_styles()
	_rebuild_variant_buttons()
	_refresh_color_grid()
	_refresh_studio()


func set_slot_variant(slot_id: String, variant_id: String) -> bool:
	if DollData.variant_by_id(slot_id, variant_id).is_empty():
		return false
	_outfit[slot_id] = {"variant": variant_id, "color": _outfit[slot_id]["color"]}
	_refresh_slot_styles()
	_refresh_variant_styles()
	_refresh_studio()
	_status("%s → %s" % [DollData.slot_by_id(slot_id)["label"],
			DollData.variant_by_id(slot_id, variant_id)["label"]])
	return true


func set_slot_color(slot_id: String, color: Color) -> bool:
	if DollData.slot_by_id(slot_id).is_empty():
		return false
	_outfit[slot_id]["color"] = color
	_refresh_slot_styles()
	_refresh_color_grid()
	_refresh_studio()
	_status("%s 染色 #%s" % [DollData.slot_by_id(slot_id)["label"], color.to_html(false)])
	return true


func set_direction(index: int) -> void:
	_direction = clampi(index, 0, DollData.DIRS.size() - 1)
	_refresh_direction_styles()
	_refresh_studio()
	_status("面向 %s" % DollData.DIRS[_direction]["name"])


func set_action(action_id: String) -> void:
	if not DollData.is_action(action_id):
		return
	_action = action_id
	_refresh_action_styles()
	_refresh_studio()
	_status("动作 %s · %s" % [DollData.action_label(action_id),
			_action_hint(action_id)])


func randomize_current() -> void:
	_outfit = DollData.random_outfit(_rng)
	_doll_name = "即兴纸偶"
	_selected_card = -1
	_refresh_all()
	_status("已随机 17 槽位 · %s" % DollData.combination_text())


func randomize_slot() -> void:
	_randomize_slot()


func _randomize_slot() -> void:
	var slot: Dictionary = DollData.slot_by_id(_selected_slot)
	var variants: Array = slot["variants"]
	var variant: Dictionary = variants[_rng.randi_range(0, variants.size() - 1)]
	var palette := DollData.palette_for(_selected_slot)
	_outfit[_selected_slot] = {
		"variant": variant["id"],
		"color": palette[_rng.randi_range(0, palette.size() - 1)],
	}
	_selected_card = -1
	_refresh_all()
	_status("本槽随机 → %s" % variant["label"])


func randomize_lineup() -> void:
	for i in _lineup.size():
		var entry: Dictionary = _lineup[i]
		entry["outfit"] = DollData.random_outfit(_rng)
		entry["direction"] = _rng.randi_range(0, DollData.DIRS.size() - 1)
		entry["action"] = "walk" if i % 3 == 0 else "idle"
	_refresh_cards()
	if _selected_card >= 0 and _selected_card < _lineup.size():
		_apply_entry_to_state(_lineup[_selected_card])
		_refresh_studio()
		_refresh_slot_styles()
		_refresh_variant_styles()
		_refresh_color_grid()
		_refresh_direction_styles()
		_refresh_action_styles()
	_status("16 位阵容已重掷")


func randomize_card(index: int) -> void:
	if index < 0 or index >= _lineup.size():
		return
	var entry: Dictionary = _lineup[index]
	entry["outfit"] = DollData.random_outfit(_rng)
	entry["direction"] = _rng.randi_range(0, DollData.DIRS.size() - 1)
	entry["action"] = "walk" if _rng.randf() < 0.35 else "idle"
	cards[index].apply_entry(entry)
	cards[index].set_selected(index == _selected_card)
	if index == _selected_card:
		_apply_entry_to_state(entry)
		_refresh_studio()
		_refresh_slot_styles()
		_refresh_variant_styles()
		_refresh_color_grid()
		_refresh_direction_styles()
		_refresh_action_styles()
	_status("%02d 号已单抽" % (index + 1))


func load_lineup_entry(index: int) -> void:
	if index < 0 or index >= _lineup.size():
		return
	_selected_card = index
	_apply_entry_to_state(_lineup[index])
	_refresh_all()
	_status("载入 %s · %s" % [_doll_name, DollData.DIRS[_direction]["name"]])


func save_current(path := "") -> bool:
	var target := _save_path if path.is_empty() else path
	if not DollData.save_doll(target, _outfit, _direction, _action, _doll_name):
		_status("保存失败：无法写入", true)
		return false
	status_label.tooltip_text = ProjectSettings.globalize_path(target)
	_status("已保存 JSON · %s" % Time.get_time_string_from_system())
	return true


func load_saved(path := "") -> bool:
	var target := _save_path if path.is_empty() else path
	var data := DollData.load_doll(target)
	if data.is_empty():
		_status("读取失败：没有存档", true)
		return false
	_outfit = data["outfit"]
	_direction = int(data["direction"])
	_action = str(data["action"])
	_doll_name = str(data["name"])
	_selected_card = -1
	_refresh_all()
	status_label.tooltip_text = ProjectSettings.globalize_path(target)
	_status("已读取 JSON · %s" % Time.get_time_string_from_system())
	return true


func _on_card_pressed(index: int) -> void:
	load_lineup_entry(index)


func _on_card_reroll(index: int) -> void:
	randomize_card(index)


func _on_color_pressed(index: int) -> void:
	var palette := DollData.palette_for(_selected_slot)
	if index >= 0 and index < palette.size():
		set_slot_color(_selected_slot, palette[index])


func _apply_entry_to_state(entry: Dictionary) -> void:
	_outfit = DollData.normalize_outfit(entry["outfit"])
	_direction = int(entry["direction"])
	_action = str(entry["action"])
	_doll_name = str(entry.get("name", "我的纸偶"))


func _effective_z(slot_id: String) -> int:
	var variant := str(_outfit[slot_id]["variant"])
	return int(DollData.slot_by_id(slot_id)["z"]) + DollData.z_bonus(slot_id, _direction, variant)


func get_effective_z(slot_id: String) -> int:
	if not _outfit.has(slot_id):
		return -9999
	return _effective_z(slot_id)


func preview_clip_ok() -> bool:
	return _preview != null and _preview.clip_contents


func _action_hint(action_id: String) -> String:
	for action in DollData.ACTIONS:
		if action["id"] == action_id:
			return action["hint"]
	return ""


func _status(text: String, warn := false) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_label.add_theme_color_override("font_color", AtelierTheme.CORAL_DEEP if warn else AtelierTheme.MUTED)


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.set_border_width_all(3 if selected else 1)
	box.border_color = AtelierTheme.INK if selected else Color(AtelierTheme.INK, 0.28)
	box.content_margin_left = 2
	box.content_margin_right = 2
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ------------------------------------------------------------------ 对照弹层

func show_directions_sheet() -> void:
	_open_sheet("directions")


func show_actions_sheet() -> void:
	_open_sheet("actions")


func _open_sheet(kind: String) -> void:
	close_sheet()
	_overlay_kind = kind
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.14, 0.10, 0.13, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1110, 660) if kind == "directions" else Vector2(1180, 660)
	panel.add_theme_stylebox_override("panel", AtelierTheme.panel_style(18, true, AtelierTheme.CREAM))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var head := HBoxContainer.new()
	var title_text := "8 方向罗盘" if kind == "directions" else "4 动作 · 3 关键帧"
	var sub_text := "同一套关节 · 左向镜像 · 正/背/侧剪影分开" if kind == "directions" else "每动作 预备 / 冲击 / 跟随 三帧 · 不读文字也能区分"
	head.add_child(AtelierTheme.make_label(title_text, 18))
	head.add_child(AtelierTheme.make_label("   " + sub_text, 11, AtelierTheme.MUTED))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(88, 34)
	AtelierTheme.style_button(close_button, 12)
	close_button.pressed.connect(close_sheet)
	head.add_child(close_button)
	column.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 3 if kind == "directions" else 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(grid)

	if kind == "directions":
		# 罗盘：3×3 环，中心“方向”；填写顺序 = 左上/上/右上/左/中心/右/左下/下/右下。
		var thumbs_by_dir := {}
		for cell_index in [3, 4, 5, 2, -1, 6, 1, 0, 7]:
			if cell_index == -1:
				var center_cell := PanelContainer.new()
				center_cell.custom_minimum_size = Vector2(320, 190)
				center_cell.add_theme_stylebox_override("panel", AtelierTheme.inner_style(12, Color("#fff3df")))
				grid.add_child(center_cell)
				var center_tag := AtelierTheme.make_label("方向\n罗盘", 16, AtelierTheme.MUTED)
				center_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				center_tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				center_cell.add_child(center_tag)
				continue
			var parts := _make_sheet_cell(grid, Vector2(320, 190))
			var thumb: DollThumbnail = parts["thumb"]
			thumb.doll.show_effects = false
			thumb.set_doll(_outfit, cell_index, "walk", 0.80, 0.35, 24.0, true)
			_overlay_thumbs.append(thumb)
			thumbs_by_dir[cell_index] = thumb
			(parts["caption"] as Label).text = "%s  %s" % [
				DollData.DIRS[cell_index]["label"], DollData.DIRS[cell_index]["name"]]
		for i in 8:
			_overlay_dolls.append((thumbs_by_dir[i] as DollThumbnail).doll)
	else:
		# 4 动作（列）× 3 authored keys（行）；行 = 预备/冲击/跟随，读起来是四列剪影条。
		var keys := {
			"idle": [0.0, 1.05, 2.10],
			"walk": [0.0, 0.287, 0.574],
			"attack": [0.21, 0.47, 0.78],
			"hit": [0.03, 0.20, 0.60],
		}
		var key_names := {
			"idle": ["平静", "吸气", "呼气"],
			"walk": ["触地", "经过", "抬起"],
			"attack": ["预备", "冲击", "跟随"],
			"hit": ["受击", "后仰", "回正"],
		}
		var primary_dolls: Array[PaperDollRenderer] = []
		for k in 3:
			for i in DollData.ACTIONS.size():
				var action_id: String = DollData.ACTIONS[i]["id"]
				var parts := _make_sheet_cell(grid, Vector2(280, 190))
				var thumb: DollThumbnail = parts["thumb"]
				var stamp: float = keys[action_id][k]
				thumb.set_doll(_outfit, _direction, action_id, 0.80, stamp, 24.0, true)
				_overlay_thumbs.append(thumb)
				if k == 0:
					primary_dolls.append(thumb.doll)
				(parts["caption"] as Label).text = "%s · %s %.2fs" % [
					DollData.action_label(action_id), key_names[action_id][k], stamp]
		for doll in primary_dolls:
			_overlay_dolls.append(doll)
	_status("%s 对照 · 关闭后继续换装" % ("8 方向" if kind == "directions" else "4 动作"))


func _make_sheet_cell(grid: GridContainer, cell_size: Vector2) -> Dictionary:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = cell_size
	cell.clip_contents = true
	cell.add_theme_stylebox_override("panel", AtelierTheme.inner_style(12, Color("#f8efdf")))
	grid.add_child(cell)
	var body := Control.new()
	body.clip_contents = true
	cell.add_child(body)
	var stage := StageBackdrop.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(stage)
	# 对照页是静态姿势，同样烘焙成纹理，打开时主界面仍保持流畅。
	var thumb := DollThumbnail.new()
	thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(thumb)
	var ribbon := ColorRect.new()
	ribbon.color = Color(1.0, 0.98, 0.93, 0.72)
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(ribbon)
	var caption := AtelierTheme.make_label("", 11, AtelierTheme.INK)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(caption)
	body.resized.connect(func() -> void:
		ribbon.position = Vector2(0, body.size.y - 26.0)
		ribbon.size = Vector2(body.size.x, 24.0)
		caption.position = Vector2(0, body.size.y - 24.0)
		caption.size = Vector2(body.size.x, 20)
	)
	return {"cell": cell, "body": body, "thumb": thumb, "caption": caption}


# ------------------------------------------------------------------ 层视 / 舞台模式

func toggle_layer_view() -> void:
	_layer_view = not _layer_view
	_refresh_studio()
	_status("层视：17 层沿右下展开 · 选中槽高亮" if _layer_view else "层视关闭 · 回到整偶")


func toggle_stage_mode() -> void:
	if _show_mode:
		_show_mode = false
		if _show_stage != null:
			_show_stage.queue_free()
			_show_stage = null
		_content.visible = true
		return
	_show_mode = true
	_content.visible = false
	_show_stage = Control.new()
	_show_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_show_stage)
	var stage := StageBackdrop.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_stage.add_child(stage)
	var hero := PaperDollRenderer.new()
	hero.set_doll(_outfit, _direction, _action)
	hero.set_display_scale(3.35)
	_show_stage.add_child(hero)
	_show_stage.resized.connect(func() -> void:
		hero.position = Vector2(_show_stage.size.x * 0.5, _show_stage.size.y - 56.0)
	)
	hero.position = Vector2(size.x * 0.5, size.y - 56.0)
	var hint := AtelierTheme.make_label("F11 / ESC 退出舞台模式", 11, AtelierTheme.MUTED)
	hint.position = Vector2(18, 14)
	_show_stage.add_child(hint)
	_status("舞台模式 · 无 UI · F11 退出")


func close_sheet() -> void:
	if _overlay == null:
		return
	_overlay.queue_free()
	_overlay = null
	_overlay_dolls.clear()
	_overlay_thumbs.clear()
	_overlay_kind = ""


# ------------------------------------------------------------------ 工具/验收 API

func set_timeline_clock(t: float, freeze := true) -> void:
	if studio != null:
		studio.animate = not freeze
		studio.set_clock(t)
	for card in cards:
		card.set_animate(not freeze)
		card.set_clock(t)
	for thumb in _overlay_thumbs:
		thumb.set_clock(t)


func set_ui_visible(value: bool) -> void:
	if _content != null:
		_content.visible = value


func set_fps_visible(value: bool) -> void:
	if fps_label != null:
		fps_label.visible = value


func get_outfit() -> Dictionary:
	return DollData.normalize_outfit(DollData.encode_outfit(_outfit))


func get_direction() -> int:
	return _direction


func get_action() -> String:
	return _action


func get_lineup() -> Array:
	return _lineup


func get_card(index: int) -> LineupCard:
	if index < 0 or index >= cards.size():
		return null
	return cards[index]


func get_studio() -> PaperDollRenderer:
	return studio


func get_overlay_dolls() -> Array:
	return _overlay_dolls


func get_preset_count() -> int:
	return _lineup.size()


func get_selected_slot() -> String:
	return _selected_slot


func get_doll_name() -> String:
	return _doll_name


# ------------------------------------------------------------------ 键盘

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key == KEY_F11:
		if _overlay != null:
			close_sheet()
		toggle_stage_mode()
		get_viewport().set_input_as_handled()
		return
	if _show_mode:
		if key == KEY_ESCAPE or key == KEY_F11:
			toggle_stage_mode()
			get_viewport().set_input_as_handled()
		return
	if _overlay != null:
		if key == KEY_ESCAPE:
			close_sheet()
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_1, KEY_2, KEY_3, KEY_4:
			set_action(DollData.ACTIONS[key - KEY_1]["id"])
		KEY_R:
			randomize_current()
		KEY_S:
			save_current()
		KEY_L:
			load_saved()
		KEY_LEFT:
			set_direction(posmod(_direction - 1, DollData.DIRS.size()))
		KEY_RIGHT:
			set_direction(posmod(_direction + 1, DollData.DIRS.size()))
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	get_viewport().set_input_as_handled()
