class_name TabBarUI
extends Control

signal page_changed(index: int)

# Reference tabs: 42.5x27 px at 529x356 -> 103x54 at 1280x720; pitch 45.5 -> 110.
const LABELS := ["一", "二", "三", "四", "临时"]
const TAB_W := 103.0
const TAB_H := 54.0
const GAP := 7.0

var active_index := 0
var _hover_index := -1
var _tabs: Array = []
var _bgs: Array = []
var _labels: Array = []
var _built := false
var _glow: TextureRect


func setup() -> void:
	size = Vector2(5 * TAB_W + 4 * GAP, TAB_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		return
	_built = true
	_glow = ThemeKit.glow_texture_rect("glow", Color(0.55, 1.0, 0.90, 0.10))
	_glow.size = Vector2(170, 90)
	_glow.position = Vector2(-32, -20)
	add_child(_glow)
	for i in range(5):
		var tab := Control.new()
		tab.position = Vector2(i * (TAB_W + GAP), 0)
		tab.size = Vector2(TAB_W, TAB_H)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tab)
		var bg := GradientRect.new()
		bg.position = Vector2.ZERO
		bg.setup(Vector2(TAB_W, TAB_H), 9.0, Color("96c0df"), Color("5a96c6"),
			Color("d8efff"), 2.0, 0.62)
		tab.add_child(bg)
		var label := Label.new()
		label.text = LABELS[i]
		label.position = Vector2.ZERO
		label.size = Vector2(TAB_W, TAB_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font = ThemeKit.body_font()
		ls.font_size = 26
		ls.font_color = Color("eefaff")
		ls.outline_size = 3
		ls.outline_color = Color(0.06, 0.24, 0.36, 0.85)
		label.label_settings = ls
		tab.add_child(label)
		_tabs.append(tab)
		_bgs.append(bg)
		_labels.append(label)
	mouse_entered.connect(func() -> void: pass)
	mouse_exited.connect(_on_mouse_exit)
	_apply_colors(false)


func _tab_center(i: int) -> float:
	return i * (TAB_W + GAP) + TAB_W * 0.5


func tab_rect(i: int) -> Rect2:
	return Rect2(i * (TAB_W + GAP), 0, TAB_W, TAB_H)


func set_active(index: int, animate: bool = true) -> void:
	active_index = clampi(index, 0, 4)
	_apply_colors(false)
	if _glow != null:
		_glow.position = Vector2(_tab_center(active_index) - 85, -18)


func _apply_colors(_animated: bool) -> void:
	for i in range(5):
		var active := i == active_index
		var hovered := i == _hover_index and not active
		var top := Color("83dfe0") if active else (Color("a9cfe9") if hovered else Color("96c0df"))
		var bottom := Color("4fd8c6") if active else (Color("6da6d3") if hovered else Color("5a96c6"))
		var border := Color("eaffff") if active else (Color("e6f6ff") if hovered else Color("d8efff"))
		_bgs[i].setup(Vector2(TAB_W, TAB_H), 9.0, top, bottom, border, 2.0, 0.66)
		_labels[i].label_settings.font_color = Color("ffffff") if active else Color("e8f7ff")
		_labels[i].label_settings.outline_size = 3
		_labels[i].label_settings.outline_color = Color(0.05, 0.28, 0.28, 0.9) if active else Color(0.06, 0.24, 0.36, 0.85)
		_labels[i].label_settings.font_size = 26


func _hit_tab(pos: Vector2) -> int:
	for i in range(5):
		if Rect2(i * (TAB_W + GAP), 0, TAB_W, TAB_H).has_point(pos):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit_tab(event.position)
		if h != _hover_index:
			_hover_index = h
			_apply_colors(true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _hit_tab(event.position)
		if idx >= 0:
			set_active(idx, true)
			page_changed.emit(idx)
			accept_event()


func _on_mouse_exit() -> void:
	if _hover_index != -1:
		_hover_index = -1
		_apply_colors(true)


func click_tab_for_test(index: int) -> void:
	set_active(index, true)
	page_changed.emit(index)
