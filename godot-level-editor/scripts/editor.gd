extends Control

# 苔井工坊 · 2D 关卡编辑器主控。
# 布局：顶部工具栏 / 左侧工具与调色板 / 中央网格画布 / 右侧图层与属性 / 底部状态栏。

const EditorCanvasScript := preload("res://scripts/editor_canvas.gd")
const LevelData := preload("res://scripts/level_data.gd")
const TileArt := preload("res://scripts/tile_art.gd")
const LevelPreview := preload("res://scripts/level_preview.gd")

const SAVE_DIR := "user://levels"
const EXPORT_DIR := "user://exports"
const DEMO_PATH := "res://levels/demo_level.json"

const C_BG := Color("#0a1015")
const C_PANEL := Color("#121a20")
const C_BORDER := Color("#26343d")
const C_TEXT := Color("#cdd8d0")
const C_MUTED := Color("#7f928b")
const C_GOLD := Color("#e8b36a")
const C_ACCENT := Color("#a9cf7a")
const C_DANGER := Color("#e08a7a")

const TOOL_INFO := {
	"select": {"label": "选择", "key": "V", "hint": "点击选中；拖动实体移动"},
	"brush": {"label": "画笔", "key": "B", "hint": "连续绘制当前调色板"},
	"eraser": {"label": "橡皮", "key": "E", "hint": "擦除地形/碰撞/实体"},
	"rect": {"label": "矩形", "key": "R", "hint": "拖拽范围，松开填充"},
	"line": {"label": "直线", "key": "L", "hint": "拖拽起点到终点"},
	"picker": {"label": "取色", "key": "I", "hint": "拾取地形类型与变体"},
}
const TILE_KEYS := {"grass": "1", "dirt": "2", "wall": "3", "water": "4"}
const ENTITY_KEYS := {"spawn": "5", "enemy": "6", "chest": "7"}

var data: LevelData
var canvas: Control
var preview: LevelPreview

var layer_id := "terrain"
var tool := "brush"
var paint_type := "grass"
var paint_variant := -1
var entity_type := "spawn"
var auto_tiles := true
var selected_cell := Vector2i(-1, -1)
var selected_entity_id := ""
var current_path := ""
var dirty := false

var undo_records: Array = []
var redo_records: Array = []
var action_open := false
var action_before: Dictionary = {}
var action_label := ""

var _populating := false
var _fps_timer := 0.0
var _font_head: Font
var _font_mono: Font
var _last_json := ""

var _tool_buttons := {}
var _tile_buttons := {}
var _entity_buttons := {}
var _layer_buttons := {}
var _layer_vis_buttons := {}
var _layer_lock_buttons := {}
var _variant_option: OptionButton
var _auto_check: CheckButton
var _undo_button: Button
var _redo_button: Button
var _status_hint: Label
var _status_coord: Label
var _status_meta: Label
var _status_file: Label
var _status_dirty: Label
var _zoom_label: Label
var _fps_label: Label
var _props_title: Label
var _props_box: VBoxContainer
var _props_scroll: ScrollContainer
var _map_width_spin: SpinBox
var _map_height_spin: SpinBox
var _cell_option: OptionButton
var _name_edit: LineEdit
var _canvas_host: Control
var _caption_panel: PanelContainer
var _caption_label: Label
var _caption_tween: Tween
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _json_overlay: Control
var _json_title: Label
var _json_path: Label
var _json_edit: TextEdit
var _preview_overlay: Control
var _preview_info: Label
var _preview_button: Button
var _main_ui: VBoxContainer
var _pos_x_spin: SpinBox
var _pos_y_spin: SpinBox

var _save_dialog: FileDialog
var _load_dialog: FileDialog
var _export_dialog: FileDialog

var _tool_group := ButtonGroup.new()
var _tile_group := ButtonGroup.new()
var _entity_group := ButtonGroup.new()
var _layer_group := ButtonGroup.new()


func _ready() -> void:
	_build_theme()
	_load_initial_level()
	_build_ui()
	_build_file_dialogs()
	canvas.bind_level(data)
	canvas.editor = self
	_sync_all_from_data()
	await get_tree().process_frame
	canvas.fit_view()
	update_zoom_label()
	canvas.grab_focus()


func _process(delta: float) -> void:
	_fps_timer += delta
	if _fps_timer >= 0.3:
		_fps_timer = 0.0
		var fps := Engine.get_frames_per_second()
		_fps_label.text = "FPS %d" % fps
		var color := C_ACCENT
		if fps < 30:
			color = C_DANGER
		elif fps < 50:
			color = C_GOLD
		_fps_label.add_theme_color_override("font_color", color)
# ---------------- 主题 ----------------

func _system_font(names: Array, weight: int = 500) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.allow_system_fallback = true
	return font


func _build_theme() -> void:
	var ui_font := _system_font(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC", "Microsoft YaHei", "Noto Sans"])
	_font_head = _system_font(["PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Microsoft YaHei", "Noto Sans"], 600)
	_font_mono = _system_font(["SF Mono", "Menlo", "Consolas", "Noto Sans Mono CJK SC", "Courier New"], 400)
	var theme := Theme.new()
	theme.default_font = ui_font
	theme.default_font_size = 13
	theme.set_color("font_color", "Label", C_TEXT)
	theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.45))
	theme.set_constant("shadow_offset_x", "Label", 0)
	theme.set_constant("shadow_offset_y", "Label", 1)
	theme.set_stylebox("panel", "PanelContainer", _panel_style(C_PANEL, C_BORDER, 0, 8))

	var normal := _button_style(Color("#1d2830"), Color("#33434c"))
	var hover := _button_style(Color("#27343d"), Color("#465a65"))
	var pressed := _button_style(Color("#2c4034"), Color("#7d9f69"))
	var focus := _panel_style(Color(0, 0, 0, 0), Color("#7d9f69"), 0, 1)
	var disabled := _button_style(Color("#151d22"), Color("#222e35"))
	for type_name in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, normal)
		theme.set_stylebox("hover", type_name, hover)
		theme.set_stylebox("pressed", type_name, pressed)
		theme.set_stylebox("hover_pressed", type_name, pressed)
		theme.set_stylebox("focus", type_name, focus)
		theme.set_stylebox("disabled", type_name, disabled)
		theme.set_color("font_color", type_name, C_TEXT)
		theme.set_color("font_hover_color", type_name, Color("#eef4e8"))
		theme.set_color("font_pressed_color", type_name, Color("#f1f6e7"))
		theme.set_color("font_hover_pressed_color", type_name, Color("#f1f6e7"))
		theme.set_color("font_disabled_color", type_name, Color("#5c6c67"))
		theme.set_font_size("font_size", type_name, 13)
	theme.set_stylebox("normal", "LineEdit", _button_style(Color("#0d151a"), Color("#2c3c44")))
	theme.set_stylebox("focus", "LineEdit", _panel_style(Color("#0d151a"), Color("#7d9f69"), 0, 1))
	theme.set_color("font_color", "LineEdit", C_TEXT)
	theme.set_color("font_placeholder_color", "LineEdit", C_MUTED)
	theme.set_color("caret_color", "LineEdit", C_GOLD)
	theme.set_stylebox("normal", "TextEdit", _button_style(Color("#0a1115"), Color("#2c3c44")))
	theme.set_stylebox("focus", "TextEdit", _panel_style(Color("#0a1115"), Color("#536b5b"), 0, 1))
	theme.set_color("font_color", "TextEdit", Color("#c9d9cb"))
	theme.set_color("font_readonly_color", "TextEdit", Color("#b9cbbd"))
	theme.set_color("caret_color", "TextEdit", C_GOLD)
	theme.set_color("font_color", "CheckButton", C_TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color("#eef4e8"))
	theme.set_color("font_pressed_color", "CheckButton", C_ACCENT)
	theme.set_color("font_color", "PopupMenu", C_TEXT)
	theme.set_color("font_hover_color", "PopupMenu", Color("#f1f6e7"))
	theme.set_stylebox("panel", "PopupMenu", _panel_style(Color("#151f26"), C_BORDER, 0, 6))
	theme.set_stylebox("hover", "PopupMenu", _panel_style(Color("#2c4034"), Color("#7d9f69"), 0, 3))
	theme.set_stylebox("scroll", "VScrollBar", _panel_style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("grabber", "VScrollBar", _panel_style(Color("#2b3a42"), Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox("grabber_highlight", "VScrollBar", _panel_style(Color("#43565e"), Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox("grabber_pressed", "VScrollBar", _panel_style(Color("#5d7d63"), Color(0, 0, 0, 0), 0, 3))
	theme.set_stylebox("panel", "TooltipPanel", _panel_style(Color("#0c1318"), Color("#4b6154"), 0, 5))
	theme.set_color("font_color", "TooltipLabel", Color("#dbe6da"))
	theme.set_font_size("font_size", "TooltipLabel", 12)
	theme.set_type_variation("FlatButton", "Button")
	theme.set_stylebox("normal", "FlatButton", _flat_style(Color(0, 0, 0, 0), 4, 4))
	theme.set_stylebox("hover", "FlatButton", _flat_style(Color("#223039"), 4, 4))
	theme.set_stylebox("pressed", "FlatButton", _flat_style(Color("#2c4034"), 4, 4))
	theme.set_stylebox("focus", "FlatButton", _panel_style(Color(0, 0, 0, 0), Color("#7d9f69"), 0, 1))
	theme.set_font_size("font_size", "FlatButton", 11)
	theme.set_color("font_color", "FlatButton", C_MUTED)
	theme.set_color("font_hover_color", "FlatButton", C_TEXT)
	theme.set_color("font_pressed_color", "FlatButton", C_ACCENT)
	theme.set_type_variation("DangerButton", "Button")
	theme.set_stylebox("normal", "DangerButton", _button_style(Color("#2c1d1b"), Color("#59413d")))
	theme.set_stylebox("hover", "DangerButton", _button_style(Color("#3a2421"), Color("#a4574d")))
	theme.set_stylebox("pressed", "DangerButton", _button_style(Color("#4a2925"), Color("#d27a6d")))
	theme.set_color("font_color", "DangerButton", Color("#e5aaa0"))
	theme.set_color("font_hover_color", "DangerButton", Color("#ffd6cd"))
	theme.set_color("font_pressed_color", "DangerButton", Color("#ffd6cd"))
	self.theme = theme


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 9
	style.content_margin_right = 9
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _flat_style(bg: Color, radius: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _panel_style(bg: Color, border: Color, radius: int = 0, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _primary_button(button: Button) -> Button:
	var normal := _button_style(Color("#3f6045"), Color("#7d9f69"))
	var hover := _button_style(Color("#4e7553"), Color("#a9cf7a"))
	var pressed := _button_style(Color("#345238"), Color("#c4e096"))
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	hover.content_margin_left = 14
	hover.content_margin_right = 14
	pressed.content_margin_left = 14
	pressed.content_margin_right = 14
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_color_override("font_color", Color("#eff6e6"))
	button.add_theme_color_override("font_hover_color", Color("#ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("#ffffff"))
	return button


# ---------------- 初始化数据 ----------------

func _load_initial_level() -> void:
	var level := LevelData.new(36, 20, 16, "苔庭试炼")
	if FileAccess.file_exists(DEMO_PATH):
		var text := FileAccess.get_file_as_string(DEMO_PATH)
		var errors := level.from_json(text)
		if errors.is_empty():
			data = level
			return
		print("[苔井工坊] 示例 JSON 加载失败：", errors[0])
	data = LevelData.build_demo()
	current_path = ""
	dirty = false


# ---------------- 通用 UI 小工具 ----------------

func _full_rect(node: Control) -> void:
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _label(text: String, font_size: int = 13, color: Color = C_TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, height: int = 30) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


func _vsep() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	var rect := ColorRect.new()
	rect.color = C_BORDER
	rect.custom_minimum_size = Vector2(1, 22)
	margin.add_child(rect)
	return margin


func _divider() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	var rect := ColorRect.new()
	rect.color = C_BORDER
	rect.custom_minimum_size = Vector2(0, 1)
	margin.add_child(rect)
	return margin


func _section_row(title: String, suffix: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var title_label := _label(title, 12, C_GOLD)
	title_label.add_theme_font_override("font", _font_head)
	row.add_child(title_label)
	row.add_child(_spacer())
	if suffix != "":
		row.add_child(_label(suffix, 9, C_MUTED))
	return row


func _clear_box(box: Node) -> void:
	for child in box.get_children():
		child.queue_free()


func _short_path(path: String) -> String:
	if path == "":
		return "示例关卡"
	var base := path.get_file()
	return base if base != "" else path


# ---------------- 界面搭建 ----------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	_full_rect(bg)
	add_child(bg)

	var main := VBoxContainer.new()
	_full_rect(main)
	main.add_theme_constant_override("separation", 0)
	add_child(main)
	_main_ui = main
	main.add_child(_make_topbar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	main.add_child(body)
	body.add_child(_make_left_panel())
	body.add_child(_make_center_panel())
	body.add_child(_make_right_panel())

	main.add_child(_make_statusbar())
	_build_toast()
	_build_json_overlay()
	_build_preview_overlay()


func _make_topbar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 54)
	var style := _panel_style(Color("#111920"), C_BORDER, 0, 0)
	style.border_width_bottom = 1
	bar.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	margin.add_child(row)

	var mark := PanelContainer.new()
	mark.custom_minimum_size = Vector2(32, 32)
	var mark_style := _panel_style(Color("#a9cf7a"), Color("#d5e6b4"), 5, 1)
	mark_style.content_margin_left = 0
	mark_style.content_margin_right = 0
	mark_style.content_margin_top = 0
	mark_style.content_margin_bottom = 0
	mark.add_theme_stylebox_override("panel", mark_style)
	var mark_label := _label("苔", 18, Color("#152116"))
	mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark_label.add_theme_font_override("font", _font_head)
	mark.add_child(mark_label)
	row.add_child(mark)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", -2)
	var brand_name := _label("苔井工坊", 15, C_GOLD)
	brand_name.add_theme_font_override("font", _font_head)
	brand.add_child(brand_name)
	brand.add_child(_label("MOSSGARDEN · LEVEL STUDIO", 8, C_MUTED))
	row.add_child(brand)
	row.add_child(_vsep())

	var save_btn := _button("保存", 30)
	save_btn.tooltip_text = "保存编辑器 JSON（Ctrl/Cmd+S）"
	save_btn.pressed.connect(_on_save_pressed)
	row.add_child(save_btn)
	var load_btn := _button("加载", 30)
	load_btn.tooltip_text = "加载编辑器 JSON（Ctrl/Cmd+O）"
	load_btn.pressed.connect(_on_load_pressed)
	row.add_child(load_btn)
	var export_btn := _button("导出 JSON", 30)
	export_btn.tooltip_text = "导出运行时 JSON（Ctrl/Cmd+E）"
	export_btn.pressed.connect(_on_export_pressed)
	row.add_child(export_btn)
	row.add_child(_vsep())

	_undo_button = _button("撤销", 30)
	_undo_button.tooltip_text = "撤销（Ctrl/Cmd+Z）"
	_undo_button.pressed.connect(undo)
	row.add_child(_undo_button)
	_redo_button = _button("重做", 30)
	_redo_button.tooltip_text = "重做（Ctrl/Cmd+Shift+Z）"
	_redo_button.pressed.connect(redo)
	row.add_child(_redo_button)
	row.add_child(_vsep())

	_auto_check = CheckButton.new()
	_auto_check.text = "自动铺砖"
	_auto_check.button_pressed = true
	_auto_check.focus_mode = Control.FOCUS_NONE
	_auto_check.add_theme_font_size_override("font_size", 12)
	_auto_check.tooltip_text = "开启时，每次落笔会更新本格与周围八格的边缘；关闭后只改当前格"
	_auto_check.toggled.connect(_on_auto_toggled)
	row.add_child(_auto_check)
	var recalc_btn := _button("重算", 26)
	recalc_btn.theme_type_variation = "FlatButton"
	recalc_btn.tooltip_text = "按当前地形重新计算全部自动边缘（保留手动变体）"
	recalc_btn.pressed.connect(_on_recalc_pressed)
	row.add_child(recalc_btn)

	row.add_child(_spacer())
	_fps_label = _label("FPS --", 11, C_ACCENT)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(_fps_label)

	_preview_button = _button("▶ 运行预览", 32)
	_preview_button.tooltip_text = "把当前 JSON 载入可走的小场景（F5）"
	_primary_button(_preview_button)
	_preview_button.pressed.connect(open_preview)
	row.add_child(_preview_button)
	return bar


func _make_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(214, 0)
	var style := _panel_style(C_PANEL, C_BORDER, 0, 0)
	style.border_width_right = 1
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	scroll.add_child(box)

	box.add_child(_section_row("工具", "TOOLS"))
	var tools_grid := GridContainer.new()
	tools_grid.columns = 2
	tools_grid.add_theme_constant_override("h_separation", 4)
	tools_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(tools_grid)
	for id in TOOL_INFO:
		var info: Dictionary = TOOL_INFO[id]
		var btn := _button("%s  %s" % [info["label"], info["key"]], 29)
		btn.toggle_mode = true
		btn.button_group = _tool_group
		btn.theme_type_variation = "FlatButton"
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "%s（%s）：%s" % [info["label"], info["key"], info["hint"]]
		btn.pressed.connect(_on_tool_pressed.bind(id))
		tools_grid.add_child(btn)
		_tool_buttons[id] = btn
	box.add_child(_divider())
	box.add_child(_section_row("地形调色板", "1–4"))
	var tile_grid := GridContainer.new()
	tile_grid.columns = 2
	tile_grid.add_theme_constant_override("h_separation", 4)
	tile_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(tile_grid)
	for type in LevelData.TILE_TYPES:
		var btn := _button(String(LevelData.TILE_NAMES[type]), 38)
		btn.toggle_mode = true
		btn.button_group = _tile_group
		btn.icon = TileArt.icon_texture(type, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "%s，快捷键 %s" % [LevelData.TILE_NAMES[type], TILE_KEYS[type]]
		btn.pressed.connect(_on_tile_pressed.bind(type))
		tile_grid.add_child(btn)
		_tile_buttons[type] = btn

	var variant_row := HBoxContainer.new()
	variant_row.add_theme_constant_override("separation", 6)
	variant_row.add_child(_label("变体", 11, C_MUTED))
	_variant_option = OptionButton.new()
	_variant_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variant_option.custom_minimum_size = Vector2(0, 26)
	_variant_option.add_theme_font_size_override("font_size", 11)
	_variant_option.add_item("自动边缘")
	_variant_option.add_item("素面")
	_variant_option.add_item("缀饰")
	_variant_option.add_item("裂纹")
	_variant_option.tooltip_text = "自动边缘按邻接计算；其他选项写入手动变体，覆盖自动边"
	_variant_option.item_selected.connect(_on_variant_selected)
	variant_row.add_child(_variant_option)
	box.add_child(variant_row)

	var auto_row := HBoxContainer.new()
	auto_row.add_theme_constant_override("separation", 4)
	var recalc := _button("重算铺砖", 25)
	recalc.theme_type_variation = "FlatButton"
	recalc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recalc.add_theme_font_size_override("font_size", 11)
	recalc.tooltip_text = "按当前地形重算全部自动边缘；手动变体保留"
	recalc.pressed.connect(_on_recalc_pressed)
	auto_row.add_child(recalc)
	var clear_overrides := _button("清除覆盖", 25)
	clear_overrides.theme_type_variation = "FlatButton"
	clear_overrides.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_overrides.add_theme_font_size_override("font_size", 11)
	clear_overrides.tooltip_text = "把所有手动变体恢复为自动边缘"
	clear_overrides.pressed.connect(_on_clear_overrides_pressed)
	auto_row.add_child(clear_overrides)
	box.add_child(auto_row)
	box.add_child(_divider())

	box.add_child(_section_row("实体", "5–7"))
	var entity_col := VBoxContainer.new()
	entity_col.add_theme_constant_override("separation", 4)
	box.add_child(entity_col)
	for type in LevelData.ENTITY_TYPES:
		var btn := _button("%s    %s" % [LevelData.ENTITY_NAMES[type], ENTITY_KEYS[type]], 36)
		btn.toggle_mode = true
		btn.button_group = _entity_group
		btn.icon = TileArt.icon_texture(type, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.tooltip_text = "%s，快捷键 %s；选择后点击画布放置" % [LevelData.ENTITY_NAMES[type], ENTITY_KEYS[type]]
		btn.pressed.connect(_on_entity_pressed.bind(type))
		entity_col.add_child(btn)
		_entity_buttons[type] = btn
	box.add_child(_divider())
	box.add_child(_section_row("关卡"))
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 4)
	var clear_btn := _button("清空", 25)
	clear_btn.theme_type_variation = "FlatButton"
	clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn.add_theme_font_size_override("font_size", 11)
	clear_btn.tooltip_text = "清空当前关卡（可撤销）"
	clear_btn.pressed.connect(_on_clear_pressed)
	level_row.add_child(clear_btn)
	var reset_btn := _button("重置示例", 25)
	reset_btn.theme_type_variation = "FlatButton"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.add_theme_font_size_override("font_size", 11)
	reset_btn.tooltip_text = "恢复内置示例关卡（可撤销）"
	reset_btn.pressed.connect(_on_reset_demo_pressed)
	level_row.add_child(reset_btn)
	box.add_child(level_row)

	var hint := _label("中键 / 空格+左键 平移 · 滚轮缩放\n1–4 地形 · 5–7 实体 · B/E/R/L/I 工具", 10, C_MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0, 34)
	box.add_child(hint)
	return panel


func _make_center_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := _panel_style(Color("#080d11"), Color("#1e2a31"), 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)
	_canvas_host = Control.new()
	_canvas_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_canvas_host)

	canvas = EditorCanvasScript.new()
	_full_rect(canvas)
	canvas.editor = self
	_canvas_host.add_child(canvas)

	var zoom_box := PanelContainer.new()
	var zoom_style := _panel_style(Color(0.04, 0.06, 0.07, 0.9), Color("#3d4f45"), 5, 1)
	zoom_style.content_margin_left = 4
	zoom_style.content_margin_right = 4
	zoom_style.content_margin_top = 3
	zoom_style.content_margin_bottom = 3
	zoom_box.add_theme_stylebox_override("panel", zoom_style)
	zoom_box.anchor_left = 1.0
	zoom_box.anchor_top = 1.0
	zoom_box.anchor_right = 1.0
	zoom_box.anchor_bottom = 1.0
	zoom_box.offset_left = -204
	zoom_box.offset_top = -45
	zoom_box.offset_right = -10
	zoom_box.offset_bottom = -10
	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 3)
	zoom_box.add_child(zoom_row)
	var minus := _button("−", 24)
	minus.theme_type_variation = "FlatButton"
	minus.custom_minimum_size = Vector2(24, 24)
	minus.tooltip_text = "缩小"
	minus.pressed.connect(_on_zoom_out)
	zoom_row.add_child(minus)
	_zoom_label = _label("×1", 11, C_TEXT)
	_zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_label.custom_minimum_size = Vector2(34, 0)
	zoom_row.add_child(_zoom_label)
	var plus := _button("+", 24)
	plus.theme_type_variation = "FlatButton"
	plus.custom_minimum_size = Vector2(24, 24)
	plus.tooltip_text = "放大（滚轮）"
	plus.pressed.connect(_on_zoom_in)
	zoom_row.add_child(plus)
	var fit_btn := _button("适应", 24)
	fit_btn.theme_type_variation = "FlatButton"
	fit_btn.tooltip_text = "缩放至整张地图"
	fit_btn.pressed.connect(_on_fit_view)
	zoom_row.add_child(fit_btn)
	_canvas_host.add_child(zoom_box)

	_caption_panel = PanelContainer.new()
	var caption_style := _panel_style(Color(0.05, 0.08, 0.09, 0.92), Color("#7d9f69"), 6, 1)
	caption_style.content_margin_left = 16
	caption_style.content_margin_right = 16
	caption_style.content_margin_top = 7
	caption_style.content_margin_bottom = 7
	_caption_panel.add_theme_stylebox_override("panel", caption_style)
	_caption_panel.anchor_left = 0.5
	_caption_panel.anchor_right = 0.5
	_caption_panel.anchor_top = 1.0
	_caption_panel.anchor_bottom = 1.0
	_caption_panel.offset_left = -230
	_caption_panel.offset_right = 230
	_caption_panel.offset_top = -58
	_caption_panel.offset_bottom = -14
	_caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_label = _label("", 12, C_GOLD)
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption_panel.add_child(_caption_label)
	_caption_panel.visible = false
	_canvas_host.add_child(_caption_panel)
	return panel


func _make_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(306, 0)
	var style := _panel_style(C_PANEL, C_BORDER, 0, 0)
	style.border_width_left = 1
	panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	box.add_child(_section_row("图层", "LAYERS"))
	for id in LevelData.LAYER_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var name_btn := _button(String(LevelData.LAYER_NAMES[id]), 28)
		name_btn.toggle_mode = true
		name_btn.button_group = _layer_group
		name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_btn.add_theme_font_size_override("font_size", 12)
		name_btn.tooltip_text = String(LevelData.LAYER_DESCS[id])
		name_btn.pressed.connect(_on_layer_pressed.bind(id))
		row.add_child(name_btn)
		_layer_buttons[id] = name_btn
		var vis := _button("可见", 24)
		vis.theme_type_variation = "FlatButton"
		vis.custom_minimum_size = Vector2(44, 24)
		vis.add_theme_font_size_override("font_size", 10)
		vis.tooltip_text = "显示/隐藏该图层"
		vis.pressed.connect(_on_layer_visible_pressed.bind(id))
		row.add_child(vis)
		_layer_vis_buttons[id] = vis
		var lock := _button("自由", 24)
		lock.theme_type_variation = "FlatButton"
		lock.custom_minimum_size = Vector2(44, 24)
		lock.add_theme_font_size_override("font_size", 10)
		lock.tooltip_text = "锁定后该图层不可编辑"
		lock.pressed.connect(_on_layer_lock_pressed.bind(id))
		row.add_child(lock)
		_layer_lock_buttons[id] = lock
		box.add_child(row)
	box.add_child(_divider())
	box.add_child(_section_row("地图", "MAP"))
	var dim_row := HBoxContainer.new()
	dim_row.add_theme_constant_override("separation", 5)
	dim_row.add_child(_label("尺寸", 11, C_MUTED))
	_map_width_spin = SpinBox.new()
	_map_width_spin.min_value = 8
	_map_width_spin.max_value = 96
	_map_width_spin.step = 1
	_map_width_spin.custom_minimum_size = Vector2(0, 26)
	_map_width_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_width_spin.tooltip_text = "地图宽度（格）"
	_map_width_spin.value_changed.connect(_on_map_size_changed)
	dim_row.add_child(_map_width_spin)
	dim_row.add_child(_label("×", 11, C_MUTED))
	_map_height_spin = SpinBox.new()
	_map_height_spin.min_value = 8
	_map_height_spin.max_value = 96
	_map_height_spin.step = 1
	_map_height_spin.custom_minimum_size = Vector2(0, 26)
	_map_height_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_height_spin.tooltip_text = "地图高度（格）"
	_map_height_spin.value_changed.connect(_on_map_size_changed)
	dim_row.add_child(_map_height_spin)
	box.add_child(dim_row)

	var cell_row := HBoxContainer.new()
	cell_row.add_theme_constant_override("separation", 5)
	var cell_label := _label("格子", 11, C_MUTED)
	cell_label.custom_minimum_size = Vector2(30, 0)
	cell_row.add_child(cell_label)
	_cell_option = OptionButton.new()
	_cell_option.add_theme_font_size_override("font_size", 11)
	_cell_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cell_option.custom_minimum_size = Vector2(0, 26)
	_cell_option.add_item("16 px  ·  像素画")
	_cell_option.add_item("32 px  ·  放大")
	_cell_option.add_item("48 px  ·  展示")
	_cell_option.tooltip_text = "格子像素尺寸；16/32/48 都是整数倍，保持像素锐利"
	_cell_option.item_selected.connect(_on_cell_size_selected)
	cell_row.add_child(_cell_option)
	box.add_child(cell_row)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	var name_label := _label("名称", 11, C_MUTED)
	name_label.custom_minimum_size = Vector2(30, 0)
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.custom_minimum_size = Vector2(0, 26)
	_name_edit.placeholder_text = "关卡名称"
	_name_edit.add_theme_font_size_override("font_size", 12)
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	box.add_child(name_row)
	box.add_child(_divider())

	var prop_head := _section_row("属性", "INSPECTOR")
	box.add_child(prop_head)
	_props_title = _label("未选中", 11, C_MUTED)
	box.add_child(_props_title)
	_props_scroll = ScrollContainer.new()
	_props_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_props_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_props_scroll)
	_props_box = VBoxContainer.new()
	_props_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_props_box.add_theme_constant_override("separation", 7)
	_props_scroll.add_child(_props_box)
	return panel


func _make_statusbar() -> Control:
	var bar := PanelContainer.new()
	bar.custom_minimum_size = Vector2(0, 29)
	var style := _panel_style(Color("#0e151a"), C_BORDER, 0, 0)
	style.border_width_top = 1
	bar.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	bar.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	_status_hint = _label("", 11, C_MUTED)
	_status_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_hint.clip_text = true
	row.add_child(_status_hint)
	_status_coord = _label("格 --,--", 11, C_GOLD)
	row.add_child(_status_coord)
	_status_meta = _label("", 10, C_MUTED)
	row.add_child(_status_meta)
	_status_file = _label("示例关卡", 10, C_MUTED)
	row.add_child(_status_file)
	_status_dirty = _label("已保存", 10, C_ACCENT)
	row.add_child(_status_dirty)
	return bar


func _build_toast() -> void:
	var holder := Control.new()
	_full_rect(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_toast_panel = PanelContainer.new()
	var style := _panel_style(Color(0.045, 0.07, 0.075, 0.96), Color("#7d9f69"), 6, 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	_toast_panel.add_theme_stylebox_override("panel", style)
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.anchor_top = 1.0
	_toast_panel.anchor_bottom = 1.0
	_toast_panel.offset_left = -280
	_toast_panel.offset_right = 280
	_toast_panel.offset_top = -84
	_toast_panel.offset_bottom = -50
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label = _label("", 12, C_TEXT)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.clip_text = true
	_toast_panel.add_child(_toast_label)
	_toast_panel.visible = false
	holder.add_child(_toast_panel)


func _build_json_overlay() -> void:
	_json_overlay = Control.new()
	_full_rect(_json_overlay)
	_json_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_json_overlay.visible = false
	add_child(_json_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.035, 0.04, 0.82)
	_full_rect(dim)
	_json_overlay.add_child(dim)
	var center := CenterContainer.new()
	_full_rect(center)
	_json_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 570)
	var style := _panel_style(Color("#10181d"), Color("#3d4f45"), 7, 1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	var head := HBoxContainer.new()
	_json_title = _label("关卡 JSON", 16, C_GOLD)
	_json_title.add_theme_font_override("font", _font_head)
	head.add_child(_json_title)
	head.add_child(_spacer())
	var close_top := _button("关闭", 26)
	close_top.theme_type_variation = "FlatButton"
	close_top.pressed.connect(_hide_json_panel)
	head.add_child(close_top)
	box.add_child(head)
	_json_path = _label("", 10, C_MUTED)
	_json_path.clip_text = true
	box.add_child(_json_path)
	_json_edit = TextEdit.new()
	_json_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_json_edit.editable = false
	_json_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	_json_edit.add_theme_font_override("font", _font_mono)
	_json_edit.add_theme_font_size_override("font_size", 11)
	box.add_child(_json_edit)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 8)
	var note := _label("运行时格式：tiles / collision / entities；可直接交给 Godot/Unity/Web 读取。", 10, C_MUTED)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note.clip_text = true
	foot.add_child(note)
	var copy_btn := _button("复制", 26)
	copy_btn.theme_type_variation = "FlatButton"
	copy_btn.pressed.connect(_copy_json)
	foot.add_child(copy_btn)
	var close_bottom := _button("关闭", 26)
	close_bottom.pressed.connect(_hide_json_panel)
	foot.add_child(close_bottom)
	box.add_child(foot)


func _build_preview_overlay() -> void:
	_preview_overlay = Control.new()
	_full_rect(_preview_overlay)
	_preview_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview_overlay.visible = false
	add_child(_preview_overlay)
	var bg := ColorRect.new()
	bg.color = C_BG
	_full_rect(bg)
	_preview_overlay.add_child(bg)
	var margin := MarginContainer.new()
	_full_rect(margin)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_preview_overlay.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)
	var top := PanelContainer.new()
	var top_style := _panel_style(Color("#111c20"), Color("#33473f"), 5, 1)
	top_style.content_margin_left = 12
	top_style.content_margin_right = 12
	top_style.content_margin_top = 7
	top_style.content_margin_bottom = 7
	top.add_theme_stylebox_override("panel", top_style)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 10)
	top.add_child(top_row)
	var title := _label("运行预览 · 从当前 JSON 载入", 14, C_GOLD)
	title.add_theme_font_override("font", _font_head)
	top_row.add_child(title)
	_preview_info = _label("", 11, C_MUTED)
	_preview_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_info.clip_text = true
	top_row.add_child(_preview_info)
	var reload := _button("重载 JSON", 26)
	reload.theme_type_variation = "FlatButton"
	reload.tooltip_text = "重新序列化当前关卡并载入预览"
	reload.pressed.connect(open_preview)
	top_row.add_child(reload)
	var back := _button("返回编辑  Esc", 28)
	back.pressed.connect(close_preview)
	top_row.add_child(back)
	box.add_child(top)
	preview = LevelPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(preview)


func _build_file_dialogs() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	_save_dialog = _new_json_dialog("保存关卡 JSON", FileDialog.FILE_MODE_SAVE_FILE, SAVE_DIR, "苔庭试炼.json")
	_save_dialog.file_selected.connect(_on_save_selected)
	_load_dialog = _new_json_dialog("加载关卡 JSON", FileDialog.FILE_MODE_OPEN_FILE, SAVE_DIR, "")
	_load_dialog.file_selected.connect(_on_load_selected)
	_export_dialog = _new_json_dialog("导出运行时 JSON", FileDialog.FILE_MODE_SAVE_FILE, EXPORT_DIR, "苔庭试炼.runtime.json")
	_export_dialog.file_selected.connect(_on_export_selected)
	add_child(_save_dialog)
	add_child(_load_dialog)
	add_child(_export_dialog)


func _new_json_dialog(title: String, mode: FileDialog.FileMode, dir: String, file: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.title = title
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = false
	dialog.add_filter("*.json", "苔井关卡 JSON")
	dialog.size = Vector2i(760, 480)
	dialog.current_dir = ProjectSettings.globalize_path(dir)
	if file != "":
		dialog.current_file = file
	return dialog


# ---------------- 状态同步 ----------------

func _sync_all_from_data() -> void:
	_populating = true
	_map_width_spin.value = data.width
	_map_height_spin.value = data.height
	var sizes := [16, 32, 48]
	var cell_index := 0
	var best := 9999
	for index in sizes.size():
		var distance := absi(int(sizes[index]) - data.cell_size)
		if distance < best:
			best = distance
			cell_index = index
	_cell_option.select(cell_index)
	_name_edit.text = data.level_name
	_variant_option.select(maxi(paint_variant + 1, 0))
	_auto_check.button_pressed = auto_tiles
	for id in _tool_buttons:
		_tool_buttons[id].button_pressed = id == tool
	for type in _tile_buttons:
		_tile_buttons[type].button_pressed = type == paint_type
	for type in _entity_buttons:
		_entity_buttons[type].button_pressed = type == entity_type
	for id in _layer_buttons:
		_layer_buttons[id].button_pressed = id == layer_id
	_populating = false
	_refresh_layer_ui()
	_refresh_properties()
	_update_status_hint()
	_update_status()
	_update_history_buttons()
	update_zoom_label()
	if canvas != null:
		canvas.queue_redraw()


func _sync_map_fields() -> void:
	_populating = true
	_map_width_spin.value = data.width
	_map_height_spin.value = data.height
	var sizes := [16, 32, 48]
	var cell_index := 0
	var best := 9999
	for index in sizes.size():
		var distance := absi(int(sizes[index]) - data.cell_size)
		if distance < best:
			best = distance
			cell_index = index
	_cell_option.select(cell_index)
	_name_edit.text = data.level_name
	_populating = false


func _refresh_layer_ui() -> void:
	for id in LevelData.LAYER_IDS:
		var meta: Dictionary = data.layers.get(id, {})
		var visible := bool(meta.get("visible", true))
		var locked := bool(meta.get("locked", false))
		_layer_buttons[id].button_pressed = id == layer_id
		_layer_vis_buttons[id].text = "可见" if visible else "隐藏"
		_layer_vis_buttons[id].add_theme_color_override("font_color", C_ACCENT if visible else C_GOLD)
		_layer_lock_buttons[id].text = "锁定" if locked else "自由"
		_layer_lock_buttons[id].add_theme_color_override("font_color", C_GOLD if locked else C_MUTED)


func _refresh_after_edit() -> void:
	if selected_entity_id != "" and data.entity_by_id(selected_entity_id).is_empty():
		selected_entity_id = ""
	if not data.in_bounds(selected_cell.x, selected_cell.y):
		selected_cell = Vector2i(-1, -1)
	_sync_map_fields()
	_refresh_layer_ui()
	_refresh_properties()
	_update_status_hint()
	_update_status()
	_update_history_buttons()
	if canvas != null:
		canvas.queue_redraw()


# ---------------- 工具 / 调色板 ----------------

func _on_tool_pressed(id: String) -> void:
	_set_tool(id)


func _set_tool(id: String) -> void:
	tool = id
	for key in _tool_buttons:
		_tool_buttons[key].button_pressed = key == tool
	_update_status_hint()
	if canvas != null:
		canvas.refresh_cursor()
		canvas.queue_redraw()


func _on_tile_pressed(type: String) -> void:
	paint_type = type
	layer_id = "terrain"
	for key in _tile_buttons:
		_tile_buttons[key].button_pressed = key == paint_type
	for id in _layer_buttons:
		_layer_buttons[id].button_pressed = id == layer_id
	_set_tool("brush")
	selected_entity_id = ""
	_refresh_properties()
	_update_status()


func _on_entity_pressed(type: String) -> void:
	entity_type = type
	layer_id = "entities"
	for key in _entity_buttons:
		_entity_buttons[key].button_pressed = key == entity_type
	for id in _layer_buttons:
		_layer_buttons[id].button_pressed = id == layer_id
	_set_tool("brush")
	selected_entity_id = ""
	_refresh_properties()
	_update_status()


func _on_variant_selected(index: int) -> void:
	if _populating:
		return
	paint_variant = index - 1
	_update_status_hint()
	canvas.queue_redraw()
	var label := "自动边缘" if paint_variant < 0 else String(_variant_option.get_item_text(index))
	toast("画笔变体：%s%s" % [label, "（手动覆盖）" if paint_variant >= 0 else ""])


func _on_auto_toggled(on: bool) -> void:
	if _populating:
		return
	auto_tiles = on
	_update_status_hint()
	_update_status()
	toast("自动铺砖已%s：%s" % [
		"开启" if on else "关闭",
		"落笔会同步刷新周围边缘" if on else "只更新当前格，点“重算”恢复周围",
	])


func _on_layer_pressed(id: String) -> void:
	if id == layer_id:
		return
	layer_id = id
	if id != "entities":
		selected_entity_id = ""
	if id == "entities" and tool not in ["select", "brush", "eraser"]:
		_set_tool("select")
	for key in _layer_buttons:
		_layer_buttons[key].button_pressed = key == layer_id
	_refresh_layer_ui()
	_refresh_properties()
	_update_status_hint()
	_update_status()
	canvas.refresh_cursor()
	canvas.queue_redraw()


func _on_layer_visible_pressed(id: String) -> void:
	var meta: Dictionary = data.layers.get(id, {})
	meta["visible"] = not bool(meta.get("visible", true))
	data.layers[id] = meta
	_refresh_layer_ui()
	_mark_dirty(true)
	_update_status()
	canvas.queue_redraw()
	toast("%s层已%s" % [LevelData.LAYER_NAMES[id], "显示" if bool(meta["visible"]) else "隐藏"])


func _on_layer_lock_pressed(id: String) -> void:
	var meta: Dictionary = data.layers.get(id, {})
	meta["locked"] = not bool(meta.get("locked", false))
	data.layers[id] = meta
	_refresh_layer_ui()
	_mark_dirty(true)
	_update_status()
	canvas.queue_redraw()
	toast("%s层已%s" % [LevelData.LAYER_NAMES[id], "锁定" if bool(meta["locked"]) else "解锁"])


# ---------------- 自动铺砖 ----------------

func _on_recalc_pressed() -> void:
	var before := data.snapshot()
	var changed := data.recalculate_autotiles(false)
	var after := data.snapshot()
	if JSON.stringify(before) != JSON.stringify(after):
		_record_history("重算自动铺砖", before, after)
		_mark_dirty(true)
	_refresh_after_edit()
	toast("自动边缘已重算：%d 格更新（手动变体保留）" % changed)


func _on_clear_overrides_pressed() -> void:
	var before := data.snapshot()
	var cleared := data.clear_manual_overrides()
	var after := data.snapshot()
	if JSON.stringify(before) != JSON.stringify(after):
		_record_history("清除手动覆盖", before, after)
		_mark_dirty(true)
	_refresh_after_edit()
	toast("已恢复 %d 个手动变体为自动边缘" % cleared)


# ---------------- 地图设置 ----------------

func _on_map_size_changed(_value: float) -> void:
	if _populating:
		return
	var new_width := int(_map_width_spin.value)
	var new_height := int(_map_height_spin.value)
	if new_width == data.width and new_height == data.height:
		return
	var before := data.snapshot()
	data.resize(new_width, new_height, data.cell_size)
	_record_history("调整地图尺寸", before, data.snapshot())
	_mark_dirty(true)
	selected_entity_id = ""
	selected_cell = Vector2i(mini(selected_cell.x, data.width - 1), mini(selected_cell.y, data.height - 1))
	_refresh_after_edit()
	canvas.fit_view()
	update_zoom_label()
	toast("地图尺寸：%d × %d 格" % [data.width, data.height])


func _on_cell_size_selected(index: int) -> void:
	if _populating:
		return
	var sizes := [16, 32, 48]
	if index < 0 or index >= sizes.size():
		return
	var new_size: int = sizes[index]
	if new_size == data.cell_size:
		return
	var before := data.snapshot()
	data.resize(data.width, data.height, new_size)
	_record_history("调整格子大小", before, data.snapshot())
	_mark_dirty(true)
	_refresh_after_edit()
	canvas.fit_view()
	update_zoom_label()
	toast("格子大小：%d px（×%d 缩放仍为整数）" % [new_size, canvas.zoom])


func _on_name_changed(text: String) -> void:
	if _populating:
		return
	data.level_name = text.strip_edges() if text.strip_edges() != "" else "未命名关卡"
	_mark_dirty(true)
	_update_status()
	_update_file_labels()


# ---------------- 选择 / 状态 ----------------

func select_cell(cell: Vector2i) -> void:
	selected_cell = cell
	_update_status()
	if selected_entity_id == "":
		_refresh_properties()
	if canvas != null:
		canvas.queue_redraw()


func select_entity(id: String) -> void:
	selected_entity_id = id
	if id != "":
		var entity := data.entity_by_id(id)
		if not entity.is_empty():
			selected_cell = Vector2i(int(entity["x"]), int(entity["y"]))
	_refresh_properties()
	_update_status()
	if canvas != null:
		canvas.refresh_cursor()
		canvas.queue_redraw()


func sync_entity_selection() -> void:
	if selected_entity_id == "":
		return
	var entity := data.entity_by_id(selected_entity_id)
	if entity.is_empty():
		return
	_populating = true
	if _pos_x_spin != null:
		_pos_x_spin.value = int(entity["x"])
	if _pos_y_spin != null:
		_pos_y_spin.value = int(entity["y"])
	_populating = false
	_update_status()


func tool_label() -> String:
	if layer_id == "entities" and tool == "brush":
		return "放置"
	return String(TOOL_INFO.get(tool, {}).get("label", "工具"))


func _update_status_hint() -> void:
	if _status_hint == null:
		return
	var tile_name := String(LevelData.TILE_NAMES.get(paint_type, "地形"))
	var entity_name := String(LevelData.ENTITY_NAMES.get(entity_type, "实体"))
	var text := ""
	match tool:
		"select":
			if layer_id == "entities":
				text = "选择 · 点击实体查看属性；拖动移动；Delete 删除选中实体"
			else:
				text = "选择 · 点击格子查看 %s 与自动掩码；右侧可恢复自动边缘" % String(LevelData.LAYER_NAMES[layer_id])
		"brush":
			match layer_id:
				"terrain":
					text = "画笔 · 左键绘制%s；%s · 拖拽连续落笔" % [tile_name, "自动铺砖开启，邻格边缘同步" if auto_tiles else "自动铺砖关闭，只改当前格"]
				"collision":
					text = "碰撞画笔 · 左键标记实心格；预览中不可通行"
				"entities":
					text = "放置%s · 点击空格生成；右侧编辑属性；B 画笔状态下也可放置" % entity_name
		"eraser":
			text = "橡皮 · 左键擦除%s；拖拽连续擦除" % String(LevelData.LAYER_NAMES[layer_id])
		"rect":
			text = "矩形 · 左键拖拽范围，松开填充%s；Esc / 右键取消" % tile_name
		"line":
			text = "直线 · 左键拖拽起点到终点，松开绘制%s" % tile_name
		"picker":
			text = "取色 · 点击地形拾取类型与变体；点击实体拾取类型"
	if not is_layer_visible(layer_id):
		text = "⚠ " + String(LevelData.LAYER_NAMES[layer_id]) + "层已隐藏 — " + text
	elif is_layer_locked(layer_id):
		text = "🔒 " + String(LevelData.LAYER_NAMES[layer_id]) + "层已锁定 — " + text
	_status_hint.text = text


func _update_status() -> void:
	if _status_meta == null or data == null:
		return
	var undo_count := undo_records.size()
	var redo_count := redo_records.size()
	_status_meta.text = "自动铺砖 %s · 实体 %d · 撤销 %d / 重做 %d" % [
		"开" if auto_tiles else "关",
		data.entities.size(),
		undo_count,
		redo_count,
	]
	_update_file_labels()


func _update_file_labels() -> void:
	if _status_file == null:
		return
	_status_file.text = _short_path(current_path)
	if dirty:
		_status_dirty.text = "● 已修改"
		_status_dirty.add_theme_color_override("font_color", C_GOLD)
	else:
		_status_dirty.text = "已保存"
		_status_dirty.add_theme_color_override("font_color", C_ACCENT)


func _mark_dirty(value: bool) -> void:
	dirty = value
	_update_file_labels()
	_update_history_buttons()
	_update_status()


func update_hover(cell: Vector2i) -> void:
	if _status_coord == null or data == null:
		return
	if not data.in_bounds(cell.x, cell.y):
		_status_coord.text = "格 --,--"
		return
	var text := "格 %d,%d" % [cell.x, cell.y]
	var tile := data.get_tile(cell.x, cell.y)
	if not tile.is_empty():
		text += " · " + String(LevelData.TILE_NAMES.get(String(tile["type"]), "地形"))
		if int(tile.get("variant", -1)) >= 0:
			text += "（手动）"
	if data.collision_at(cell.x, cell.y):
		text += " · 碰撞"
	if layer_id == "entities":
		var entity := data.entity_at(cell.x, cell.y)
		if not entity.is_empty():
			text += " · %s %s" % [LevelData.ENTITY_NAMES.get(String(entity["type"]), "实体"), String(entity["id"])]
	_status_coord.text = text


func update_zoom_label() -> void:
	if _zoom_label != null and canvas != null:
		_zoom_label.text = "×%d" % canvas.zoom
	_update_status()


func is_layer_visible(id: String) -> bool:
	return bool(data.layers.get(id, {}).get("visible", true))


func is_layer_locked(id: String) -> bool:
	return bool(data.layers.get(id, {}).get("locked", false))


func apply_picked_tile(type: String, variant: int) -> void:
	paint_type = type
	paint_variant = variant
	layer_id = "terrain"
	_populating = true
	_variant_option.select(maxi(variant + 1, 0))
	_populating = false
	for key in _tile_buttons:
		_tile_buttons[key].button_pressed = key == paint_type
	for id in _layer_buttons:
		_layer_buttons[id].button_pressed = id == layer_id
	_set_tool("brush")
	_refresh_layer_ui()
	_refresh_properties()
	_update_status()


func apply_picked_entity(type: String) -> void:
	entity_type = type
	layer_id = "entities"
	for key in _entity_buttons:
		_entity_buttons[key].button_pressed = key == entity_type
	for id in _layer_buttons:
		_layer_buttons[id].button_pressed = id == layer_id
	_set_tool("brush")
	_refresh_layer_ui()
	_refresh_properties()
	_update_status()


# ---------------- 撤销 / 重做 ----------------

func begin_action(label: String) -> void:
	if action_open:
		return
	action_before = data.snapshot()
	action_label = label
	action_open = true


func end_action() -> void:
	if not action_open:
		return
	action_open = false
	var before := action_before
	action_before = {}
	var after := data.snapshot()
	if JSON.stringify(before) != JSON.stringify(after):
		_record_history(action_label, before, after)
		_mark_dirty(true)
	_refresh_after_edit()


func _record_history(label: String, before: Dictionary, after: Dictionary) -> void:
	undo_records.append({"label": label, "before": before, "after": after})
	while undo_records.size() > 80:
		undo_records.pop_front()
	redo_records.clear()
	_update_history_buttons()


func _mutate_with_undo(label: String, mutation: Callable) -> void:
	var before := data.snapshot()
	mutation.call()
	var after := data.snapshot()
	if JSON.stringify(before) != JSON.stringify(after):
		_record_history(label, before, after)
		_mark_dirty(true)
	_refresh_after_edit()


func undo() -> void:
	if action_open:
		end_action()
		return
	if undo_records.is_empty():
		toast("没有可撤销的操作。")
		return
	var record: Dictionary = undo_records.pop_back()
	data.restore(record["before"])
	redo_records.append(record)
	if selected_entity_id != "" and data.entity_by_id(selected_entity_id).is_empty():
		selected_entity_id = ""
	_mark_dirty(true)
	_refresh_after_edit()
	canvas.queue_redraw()
	toast("已撤销：%s" % String(record["label"]))


func redo() -> void:
	if redo_records.is_empty():
		toast("没有可重做的操作。")
		return
	var record: Dictionary = redo_records.pop_back()
	data.restore(record["after"])
	undo_records.append(record)
	if selected_entity_id != "" and data.entity_by_id(selected_entity_id).is_empty():
		selected_entity_id = ""
	_mark_dirty(true)
	_refresh_after_edit()
	canvas.queue_redraw()
	toast("已重做：%s" % String(record["label"]))


func _update_history_buttons() -> void:
	if _undo_button == null:
		return
	_undo_button.disabled = undo_records.is_empty()
	_redo_button.disabled = redo_records.is_empty()
	_undo_button.tooltip_text = "撤销（Ctrl/Cmd+Z）" if undo_records.is_empty() else "撤销：%s" % String(undo_records.back()["label"])
	_redo_button.tooltip_text = "重做（Ctrl/Cmd+Shift+Z）" if redo_records.is_empty() else "重做：%s" % String(redo_records.back()["label"])


# ---------------- 清空 / 重置 ----------------

func _on_clear_pressed() -> void:
	var before := data.snapshot()
	data.clear()
	_record_history("清空关卡", before, data.snapshot())
	selected_entity_id = ""
	selected_cell = Vector2i(-1, -1)
	_mark_dirty(true)
	_refresh_after_edit()
	canvas.queue_redraw()
	toast("关卡已清空（Ctrl/Cmd+Z 可撤销）")


func _on_reset_demo_pressed() -> void:
	var before := data.snapshot()
	var demo := LevelData.build_demo()
	var errors := data.from_dict(demo.to_dict())
	if not errors.is_empty():
		toast("示例载入失败：%s" % errors[0])
		return
	_record_history("重置示例关卡", before, data.snapshot())
	current_path = ""
	selected_entity_id = ""
	selected_cell = Vector2i(-1, -1)
	_mark_dirty(true)
	_refresh_after_edit()
	canvas.fit_view()
	update_zoom_label()
	toast("已重置为内置示例 · 苔庭试炼")


func _on_zoom_in() -> void:
	canvas.zoom_in()
	update_zoom_label()
	canvas.queue_redraw()


func _on_zoom_out() -> void:
	canvas.zoom_out()
	update_zoom_label()
	canvas.queue_redraw()


func _on_fit_view() -> void:
	canvas.fit_view()
	update_zoom_label()
	canvas.queue_redraw()


func focus_cell(cell: Vector2i, new_zoom: int = 2) -> void:
	if canvas == null or data == null or canvas.size.x <= 0:
		return
	canvas.zoom = clampi(new_zoom, 1, 4)
	var canvas_size: Vector2 = canvas.size
	var px: int = data.cell_size * int(canvas.zoom)
	var map_size: Vector2 = Vector2(data.width, data.height) * float(px)
	var base: Vector2 = (canvas_size - map_size) * 0.5
	canvas.pan = canvas_size * 0.5 - (Vector2(cell) + Vector2(0.5, 0.5)) * float(px) - base
	canvas._clamp_pan()
	canvas.queue_redraw()
	update_zoom_label()


# ---------------- Toast / 演示字幕 ----------------

func toast(text: String) -> void:
	if _toast_panel == null:
		return
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(_hide_toast)


func _hide_toast() -> void:
	if _toast_panel != null:
		_toast_panel.visible = false


func show_demo_caption(text: String, hold: float = 2.4) -> void:
	if _caption_panel == null:
		return
	if _caption_tween != null and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_label.text = text
	_caption_panel.visible = true
	_caption_panel.modulate.a = 1.0
	_caption_tween = create_tween()
	_caption_tween.tween_interval(hold)
	_caption_tween.tween_property(_caption_panel, "modulate:a", 0.0, 0.3)
	_caption_tween.tween_callback(_caption_panel.hide)


# ---------------- 文件 / JSON ----------------

func _on_save_pressed() -> void:
	if current_path != "":
		save_to_path(current_path)
		return
	_save_dialog.current_file = data.level_name + ".json"
	_save_dialog.popup_centered()


func _on_load_pressed() -> void:
	_load_dialog.popup_centered()


func _on_export_pressed() -> void:
	_export_dialog.current_file = data.level_name + ".runtime.json"
	_export_dialog.popup_centered()


func _on_save_selected(path: String) -> void:
	save_to_path(path)


func _on_load_selected(path: String) -> void:
	load_from_path(path)


func _on_export_selected(path: String) -> void:
	var text := export_to_path(path, true)
	if text != "":
		toast("运行时 JSON 已导出：%s" % path.get_file())


func _ensure_json(path: String) -> String:
	if path.to_lower().ends_with(".json"):
		return path
	return path + ".json"


func save_to_path(path: String) -> bool:
	path = _ensure_json(path)
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		toast("保存失败：%s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(data.to_json(false, true))
	file.close()
	current_path = path
	_mark_dirty(false)
	_update_status()
	toast("已保存：%s" % path.get_file())
	return true


func load_from_path(path: String) -> bool:
	if not FileAccess.file_exists(path):
		toast("加载失败：文件不存在")
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		toast("加载失败：%s" % error_string(FileAccess.get_open_error()))
		return false
	var text := file.get_as_text()
	file.close()
	var level := LevelData.new(1, 1, 16)
	var errors := level.from_json(text)
	if not errors.is_empty():
		toast("加载失败：%s" % errors[0])
		return false
	data = level
	selected_entity_id = ""
	selected_cell = Vector2i(-1, -1)
	undo_records.clear()
	redo_records.clear()
	action_open = false
	current_path = path
	dirty = false
	canvas.bind_level(data)
	_sync_all_from_data()
	canvas.fit_view()
	update_zoom_label()
	toast("已加载：%s · %d×%d" % [path.get_file(), data.width, data.height])
	return true


func export_to_path(path: String, show_panel: bool = true) -> String:
	path = _ensure_json(path)
	var dir := path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(dir)
	var text := data.to_json(true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		toast("导出失败：%s" % error_string(FileAccess.get_open_error()))
		return ""
	file.store_string(text)
	file.close()
	_last_json = text
	if show_panel:
		show_json_panel("导出的运行时 JSON", text, path)
	return text


func show_json_panel(title: String, text: String, path: String) -> void:
	if _json_overlay == null:
		return
	_last_json = text
	_json_title.text = title
	_json_path.text = path
	_json_edit.text = text
	_json_edit.scroll_vertical = 0
	_json_overlay.visible = true
	if _fps_label != null:
		_fps_label.visible = false


func _hide_json_panel() -> void:
	if _json_overlay != null:
		_json_overlay.visible = false
	if _fps_label != null:
		_fps_label.visible = true


func _copy_json() -> void:
	if _last_json == "":
		return
	DisplayServer.clipboard_set(_last_json)
	toast("JSON 已复制到剪贴板")


# ---------------- 运行预览 ----------------

func open_preview() -> void:
	if data == null or preview == null:
		return
	if canvas != null:
		canvas._cancel_gesture()
	var stats := data.validate()
	if not stats.get("ok", false):
		var errors: Array = stats.get("errors", [])
		toast("预览失败：%s" % (String(errors[0]) if not errors.is_empty() else "关卡校验未通过"))
		return
	if _json_overlay.visible:
		_hide_json_panel()
	_preview_overlay.visible = true
	var runtime_json := data.to_json(true, true)
	var result := preview.load_json(runtime_json)
	if not result.get("ok", false):
		_preview_overlay.visible = false
		toast("预览加载失败：%s" % String(result.get("errors", ["未知错误"])[0]))
		return
	if _main_ui != null:
		_main_ui.visible = false
	_last_json = runtime_json
	var warnings: Array = result.get("warnings", [])
	var info := "校验通过 · %d×%d · 可走 %d 格 · 实体 %d（敌 %d / 箱 %d）" % [
		data.width,
		data.height,
		int(stats.get("walkable", 0)),
		data.entities.size(),
		int(stats.get("enemy_count", 0)),
		int(stats.get("chest_count", 0)),
	]
	if not warnings.is_empty():
		info += " · 提示：" + String(warnings[0])
	_preview_info.text = info
	_write_preview_evidence(runtime_json)
	preview.queue_redraw()


func _write_preview_evidence(text: String) -> void:
	var path := EXPORT_DIR + "/_last_preview.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EXPORT_DIR))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(text)
		file.close()


func close_preview() -> void:
	if _preview_overlay != null:
		_preview_overlay.visible = false
	if _main_ui != null:
		_main_ui.visible = true
	if canvas != null:
		canvas.grab_focus()


# ---------------- 快捷键 ----------------

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _preview_overlay != null and _preview_overlay.visible:
		if key.keycode == KEY_ESCAPE:
			close_preview()
			get_viewport().set_input_as_handled()
		return
	if _json_overlay != null and _json_overlay.visible:
		if key.keycode == KEY_ESCAPE:
			_hide_json_panel()
			get_viewport().set_input_as_handled()
		return
	var focus := get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	var mod := key.ctrl_pressed or key.meta_pressed
	if mod:
		match key.keycode:
			KEY_S:
				_on_save_pressed()
				get_viewport().set_input_as_handled()
			KEY_O:
				_on_load_pressed()
				get_viewport().set_input_as_handled()
			KEY_E:
				_on_export_pressed()
				get_viewport().set_input_as_handled()
			KEY_Z:
				if key.shift_pressed:
					redo()
				else:
					undo()
				get_viewport().set_input_as_handled()
			KEY_Y:
				redo()
				get_viewport().set_input_as_handled()
		return
	if typing:
		return
	match key.keycode:
		KEY_F5:
			open_preview()
		KEY_ESCAPE:
			canvas._cancel_gesture()
			select_entity("")
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected_entity()
		KEY_V:
			_set_tool("select")
		KEY_B:
			_set_tool("brush")
		KEY_E:
			_set_tool("eraser")
		KEY_R:
			_set_tool("rect")
		KEY_L:
			_set_tool("line")
		KEY_I:
			_set_tool("picker")
		KEY_1:
			_on_tile_pressed("grass")
		KEY_2:
			_on_tile_pressed("dirt")
		KEY_3:
			_on_tile_pressed("wall")
		KEY_4:
			_on_tile_pressed("water")
		KEY_5:
			_on_entity_pressed("spawn")
		KEY_6:
			_on_entity_pressed("enemy")
		KEY_7:
			_on_entity_pressed("chest")
		_:
			return
	get_viewport().set_input_as_handled()


# ---------------- 属性面板 ----------------

func _refresh_properties() -> void:
	if _props_box == null or data == null:
		return
	_clear_box(_props_box)
	_pos_x_spin = null
	_pos_y_spin = null
	var entity := {}
	if selected_entity_id != "":
		entity = data.entity_by_id(selected_entity_id)
	if not entity.is_empty():
		_props_title.text = "实体 %s · %s" % [String(entity["id"]), String(LevelData.ENTITY_NAMES.get(String(entity["type"]), "实体"))]
		_build_entity_props(entity)
	elif data.in_bounds(selected_cell.x, selected_cell.y):
		_props_title.text = "格子 %d,%d · %s" % [selected_cell.x, selected_cell.y, String(LevelData.LAYER_NAMES[layer_id])]
		_build_cell_props()
	else:
		_props_title.text = "未选中"
		_build_empty_props()
	_props_scroll.scroll_vertical = 0


func _field_label(text: String, width: int = 72) -> Label:
	var label := _label(text, 11, C_MUTED)
	label.custom_minimum_size = Vector2(width, 0)
	return label


func _hint_label(text: String, color: Color = C_MUTED, font_size: int = 10) -> Label:
	var label := _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _new_spin(min_value: float, max_value: float, value: float, step: float = 1.0) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.step = step
	spin.value = value
	spin.custom_minimum_size = Vector2(0, 26)
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.add_theme_font_size_override("font_size", 11)
	return spin


func _field_row(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_field_label(label_text))
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _option_control(items: Array, current: String, display: Array = []) -> OptionButton:
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(0, 26)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.add_theme_font_size_override("font_size", 11)
	var selected := 0
	for index in items.size():
		var label := String(items[index])
		if index < display.size():
			label = String(display[index])
		option.add_item(label)
		if String(items[index]) == current:
			selected = index
	option.select(selected)
	return option


func _build_entity_props(entity: Dictionary) -> void:
	var entity_type := String(entity["type"])
	var props: Dictionary = entity.get("props", {})

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = TileArt.icon_texture(entity_type, 32)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	head.add_child(icon)
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	var title := _label(String(LevelData.ENTITY_NAMES.get(entity_type, "实体")), 13, C_GOLD)
	title.add_theme_font_override("font", _font_head)
	head_text.add_child(title)
	head_text.add_child(_label("id " + String(entity["id"]), 9, C_MUTED))
	head.add_child(head_text)
	head.add_child(_spacer())
	_props_box.add_child(head)

	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 4)
	pos_row.add_child(_field_label("位置", 52))
	pos_row.add_child(_label("X", 10, C_MUTED))
	_pos_x_spin = _new_spin(0, data.width - 1, int(entity["x"]))
	_pos_x_spin.value_changed.connect(_on_entity_position_changed.bind("x"))
	pos_row.add_child(_pos_x_spin)
	pos_row.add_child(_label("Y", 10, C_MUTED))
	_pos_y_spin = _new_spin(0, data.height - 1, int(entity["y"]))
	_pos_y_spin.value_changed.connect(_on_entity_position_changed.bind("y"))
	pos_row.add_child(_pos_y_spin)
	_props_box.add_child(pos_row)

	match entity_type:
		"spawn":
			var option := _option_control(LevelData.FACING_VALUES, String(props.get("facing", "up")), _facing_labels())
			option.item_selected.connect(_on_entity_prop_option.bind("facing", LevelData.FACING_VALUES))
			_props_box.add_child(_field_row("朝向", option))
			_props_box.add_child(_hint_label("预览会从这个出生点开始。素材朝向只影响初始观察方向。"))
		"enemy":
			var kind := _option_control(LevelData.ENEMY_KINDS, String(props.get("kind", "苔团")))
			kind.item_selected.connect(_on_entity_prop_option.bind("kind", LevelData.ENEMY_KINDS))
			_props_box.add_child(_field_row("种类", kind))
			var hp := _new_spin(1, 999, int(props.get("hp", 30)))
			hp.value_changed.connect(_on_entity_prop_number.bind("hp"))
			_props_box.add_child(_field_row("HP", hp))
			var damage := _new_spin(0, 999, int(props.get("damage", 5)))
			damage.value_changed.connect(_on_entity_prop_number.bind("damage"))
			_props_box.add_child(_field_row("伤害", damage))
			var facing := _option_control(LevelData.FACING_VALUES, String(props.get("facing", "left")), _facing_labels())
			facing.item_selected.connect(_on_entity_prop_option.bind("facing", LevelData.FACING_VALUES))
			_props_box.add_child(_field_row("朝向", facing))
			var patrol := _new_spin(0, 32, int(props.get("patrol", 3)))
			patrol.value_changed.connect(_on_entity_prop_number.bind("patrol"))
			_props_box.add_child(_field_row("巡逻半径", patrol))
			_props_box.add_child(_hint_label("HP / 伤害 / 巡逻半径写入 JSON；预览只展示 HP 条。"))
		"chest":
			var loot := _option_control(LevelData.LOOT_KINDS, String(props.get("loot", "金币")))
			loot.item_selected.connect(_on_entity_prop_option.bind("loot", LevelData.LOOT_KINDS))
			_props_box.add_child(_field_row("掉落", loot))
			var amount := _new_spin(1, 9999, int(props.get("amount", 25)))
			amount.value_changed.connect(_on_entity_prop_number.bind("amount"))
			_props_box.add_child(_field_row("数量", amount))
			_props_box.add_child(_hint_label("预览中走到宝箱上会拾取，并显示掉落内容。"))

	_props_box.add_child(_divider())
	var json_hint := _hint_label("属性写入 JSON：entities[i].props · 保存/导出都会保留。", C_MUTED, 9)
	_props_box.add_child(json_hint)
	var delete_btn := _button("删除此实体", 28)
	delete_btn.theme_type_variation = "DangerButton"
	delete_btn.pressed.connect(_delete_selected_entity)
	_props_box.add_child(delete_btn)


func _facing_labels() -> Array:
	var labels: Array = []
	for value in LevelData.FACING_VALUES:
		labels.append(LevelData.FACING_LABELS[value])
	return labels


func _build_cell_props() -> void:
	var cell := selected_cell
	var tile := data.get_tile(cell.x, cell.y)
	var tile_name := "空格子"
	if not tile.is_empty():
		tile_name = String(LevelData.TILE_NAMES.get(String(tile["type"]), "空格子"))
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	if not tile.is_empty():
		var icon := TextureRect.new()
		icon.texture = TileArt.icon_texture(String(tile["type"]), 32)
		icon.custom_minimum_size = Vector2(34, 34)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		heading.add_child(icon)
	var head_text := VBoxContainer.new()
	head_text.add_theme_constant_override("separation", 0)
	var name_label := _label(tile_name, 13, C_GOLD)
	name_label.add_theme_font_override("font", _font_head)
	head_text.add_child(name_label)
	head_text.add_child(_label("x %d · y %d" % [cell.x, cell.y], 9, C_MUTED))
	heading.add_child(head_text)
	_props_box.add_child(heading)

	if not tile.is_empty():
		var variant := int(tile.get("variant", -1))
		var mask := int(tile.get("mask", 0))
		var mode := "自动边缘" if variant < 0 else "手动变体 · %s" % _variant_name(variant)
		_props_box.add_child(_hint_label("变体：%s" % mode, C_TEXT, 11))
		_props_box.add_child(_hint_label("掩码 %d（%s）" % [mask, _mask_text(mask)], C_MUTED, 10))
		_props_box.add_child(_hint_label("外露边：%s" % _edge_text(mask), C_MUTED, 10))
		if variant >= 0:
			var restore := _button("恢复此格自动边缘", 26)
			restore.theme_type_variation = "FlatButton"
			restore.add_theme_font_size_override("font_size", 11)
			restore.pressed.connect(_on_restore_cell_auto)
			_props_box.add_child(restore)
	if layer_id == "collision" or data.collision_at(cell.x, cell.y):
		var solid := data.collision_at(cell.x, cell.y)
		_props_box.add_child(_hint_label("碰撞：%s" % ("实心（预览不可走）" if solid else "可通行"), C_DANGER if solid else C_ACCENT, 11))
		var toggle := _button("设为可通行" if solid else "设为实心碰撞", 26)
		toggle.theme_type_variation = "FlatButton"
		toggle.add_theme_font_size_override("font_size", 11)
		toggle.pressed.connect(_on_toggle_cell_collision)
		_props_box.add_child(toggle)
	if layer_id == "entities":
		var entity := data.entity_at(cell.x, cell.y)
		if entity.is_empty():
			_props_box.add_child(_hint_label("这个格子没有实体。用左侧实体按钮或 5–7 放置。", C_MUTED, 10))
		else:
			var pick := _button("选中此格的 %s %s" % [LevelData.ENTITY_NAMES.get(String(entity["type"]), "实体"), String(entity["id"])], 26)
			pick.theme_type_variation = "FlatButton"
			pick.add_theme_font_size_override("font_size", 11)
			pick.pressed.connect(select_entity.bind(String(entity["id"])))
			_props_box.add_child(pick)
	_props_box.add_child(_divider())
	_props_box.add_child(_hint_label("JSON：tiles[y][x] = {type, variant, mask} · collision[y][x] = 0/1", C_MUTED, 9))


func _variant_name(variant: int) -> String:
	match variant:
		0:
			return "素面"
		1:
			return "缀饰"
		2:
			return "裂纹"
		_:
			return "变体 %d" % variant


func _mask_text(mask: int) -> String:
	var parts: Array[String] = []
	if mask & LevelData.MASK_N:
		parts.append("北")
	if mask & LevelData.MASK_E:
		parts.append("东")
	if mask & LevelData.MASK_S:
		parts.append("南")
	if mask & LevelData.MASK_W:
		parts.append("西")
	if parts.is_empty():
		return "孤立，无同组邻格"
	return "连接 " + "、".join(parts)


func _edge_text(mask: int) -> String:
	var parts: Array[String] = []
	if not (mask & LevelData.MASK_N):
		parts.append("北")
	if not (mask & LevelData.MASK_E):
		parts.append("东")
	if not (mask & LevelData.MASK_S):
		parts.append("南")
	if not (mask & LevelData.MASK_W):
		parts.append("西")
	if parts.is_empty():
		return "无（四周连续）"
	return "、".join(parts)


func _build_empty_props() -> void:
	var intro := _label("选中实体或格子", 12, C_TEXT)
	intro.add_theme_font_override("font", _font_head)
	_props_box.add_child(intro)
	_props_box.add_child(_hint_label("点击画布上的实体会出现 HP / 种类 / 掉落 / 朝向；点击格子可查看自动掩码。"))
	_props_box.add_child(_divider())
	var stats_title := _label("当前关卡", 11, C_GOLD)
	stats_title.add_theme_font_override("font", _font_head)
	_props_box.add_child(stats_title)
	_props_box.add_child(_hint_label("地图 %d × %d · 格子 %d px" % [data.width, data.height, data.cell_size], C_TEXT, 10))
	_props_box.add_child(_hint_label("地块 %d · 碰撞 %d · 实体 %d" % [data.filled_tile_count(), data.collision_count(), data.entities.size()], C_TEXT, 10))
	_props_box.add_child(_hint_label("出生点 %d · 敌人 %d · 宝箱 %d" % [data.entity_count("spawn"), data.entity_count("enemy"), data.entity_count("chest")], C_TEXT, 10))
	_props_box.add_child(_divider())
	var rule_title := _label("自动铺砖规则", 11, C_GOLD)
	rule_title.add_theme_font_override("font", _font_head)
	_props_box.add_child(rule_title)
	_props_box.add_child(_hint_label("草/土：同类地面成组，外露边缘压暗并长出草叶。"))
	_props_box.add_child(_hint_label("石墙：按北/东/南/西邻居算连接掩码，外露边描线，转角随之生成。"))
	_props_box.add_child(_hint_label("水面：与非水格相邻处画泡沫岸线；连接处保持连续。"))
	_props_box.add_child(_hint_label("手动变体优先于自动边；“重算”只刷新自动格。"))
	_props_box.add_child(_divider())
	_props_box.add_child(_hint_label("快捷键：V/B/E/R/L/I 工具 · 1–4 地形 · 5–7 实体 · F5 预览", C_MUTED, 9))


func _on_entity_prop_number(value: float, key: String) -> void:
	if _populating:
		return
	var entity := data.entity_by_id(selected_entity_id)
	if entity.is_empty():
		return
	var before := data.snapshot()
	entity["props"][key] = int(round(value))
	_commit_after_change("修改属性 %s" % key, before)


func _on_entity_prop_option(index: int, key: String, values: Array) -> void:
	if _populating:
		return
	if index < 0 or index >= values.size():
		return
	var entity := data.entity_by_id(selected_entity_id)
	if entity.is_empty():
		return
	var before := data.snapshot()
	entity["props"][key] = String(values[index])
	_commit_after_change("修改属性 %s" % key, before)


func _on_entity_position_changed(value: float, axis: String) -> void:
	if _populating:
		return
	var entity := data.entity_by_id(selected_entity_id)
	if entity.is_empty():
		return
	var target := Vector2i(int(entity["x"]), int(entity["y"]))
	if axis == "x":
		target.x = int(round(value))
	else:
		target.y = int(round(value))
	if not data.in_bounds(target.x, target.y):
		toast("坐标超出地图范围。")
		sync_entity_selection()
		return
	var occupant := data.entity_at(target.x, target.y)
	if not occupant.is_empty() and String(occupant["id"]) != selected_entity_id:
		toast("该格已有实体 %s。" % String(occupant["id"]))
		sync_entity_selection()
		return
	if target == Vector2i(int(entity["x"]), int(entity["y"])):
		return
	var before := data.snapshot()
	data.move_entity(selected_entity_id, target.x, target.y)
	selected_cell = target
	_commit_after_change("移动实体", before)
	canvas.queue_redraw()
	_update_status()


func _commit_after_change(label: String, before: Dictionary) -> void:
	var after := data.snapshot()
	if JSON.stringify(before) != JSON.stringify(after):
		_record_history(label, before, after)
		_mark_dirty(true)
	_refresh_after_edit()


func _on_restore_cell_auto() -> void:
	var cell := selected_cell
	if not data.in_bounds(cell.x, cell.y):
		return
	var tile := data.get_tile(cell.x, cell.y)
	if tile.is_empty():
		return
	var before := data.snapshot()
	tile["variant"] = -1
	data.autotile_cell(cell.x, cell.y)
	_commit_after_change("恢复自动边缘", before)
	toast("已恢复此格自动边缘（需重算周围时点“重算铺砖”）")


func _on_toggle_cell_collision() -> void:
	var cell := selected_cell
	if not data.in_bounds(cell.x, cell.y):
		return
	var before := data.snapshot()
	var solid := not data.collision_at(cell.x, cell.y)
	data.paint_collision(cell.x, cell.y, solid)
	_commit_after_change("切换碰撞", before)
	toast("此格碰撞：%s" % ("实心" if solid else "可通行"))


func _delete_selected_entity() -> void:
	if selected_entity_id == "":
		return
	var entity := data.entity_by_id(selected_entity_id)
	if entity.is_empty():
		return
	var id := selected_entity_id
	var label := String(LevelData.ENTITY_NAMES.get(String(entity["type"]), "实体"))
	_mutate_with_undo("删除实体", func() -> void:
		data.remove_entity(id)
		selected_entity_id = ""
	)
	canvas.queue_redraw()
	toast("已删除 %s %s" % [label, id])


# ---------------- 对外测试 / 工具接口 ----------------

func set_level(level: LevelData) -> void:
	data = level
	current_path = ""
	dirty = false
	selected_entity_id = ""
	selected_cell = Vector2i(-1, -1)
	undo_records.clear()
	redo_records.clear()
	action_open = false
	canvas.bind_level(data)
	_sync_all_from_data()
	canvas.fit_view()
	update_zoom_label()


func get_undo_count() -> int:
	return undo_records.size()


func get_redo_count() -> int:
	return redo_records.size()



