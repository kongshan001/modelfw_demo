class_name TabBarUI
extends Control

signal page_changed(index: int)

const LABELS := ["一", "二", "三", "四", "临时"]
const TAB_W := 104.0
const TAB_H := 40.0
const GAP := 8.0

var active_index := 0
var _hover_index := -1
var _tabs: Array = []
var _bgs: Array = []
var _labels: Array = []
var _built := false
var _glow: TextureRect
var _underline: GradientRect
var _underline_tween: Tween


func setup() -> void:
	size = Vector2(552, TAB_H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		return
	_built = true
	_glow = ThemeKit.glow_texture_rect("glow", Color(0.55, 1.0, 0.90, 0.22))
	_glow.size = Vector2(160, 74)
	_glow.position = Vector2(-28, -18)
	add_child(_glow)
	for i in range(5):
		var tab := Control.new()
		tab.position = Vector2(i * (TAB_W + GAP), 0)
		tab.size = Vector2(TAB_W, TAB_H)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tab)
		var bg := GradientRect.new()
		bg.position = Vector2.ZERO
		bg.setup(Vector2(TAB_W, TAB_H), 9.0, Color("d9edfa"), Color("a4c6df"),
			Color("e9f8ff"), 2.0, 0.7)
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
		ls.font_size = 20
		ls.font_color = ThemeKit.TEXT_INK
		ls.outline_size = 2
		ls.outline_color = Color(0.92, 1.0, 1.0, 0.4)
		label.label_settings = ls
		tab.add_child(label)
		_tabs.append(tab)
		_bgs.append(bg)
		_labels.append(label)
	_underline = GradientRect.new()
	_underline.setup(Vector2(84, 4), 2.0, Color("fff5ce"), Color("f0bd5c"), Color("9a6a24"), 1.0, 0.7)
	_underline.position = Vector2(_tab_center(0) - 42, TAB_H - 5)
	add_child(_underline)
	mouse_entered.connect(func() -> void: pass)
	mouse_exited.connect(_on_mouse_exit)
	_apply_colors(false)


func _tab_center(i: int) -> float:
	return i * (TAB_W + GAP) + TAB_W * 0.5


func set_active(index: int, animate: bool = true) -> void:
	active_index = clampi(index, 0, 4)
	_apply_colors(false)
	_glow.position = Vector2(_tab_center(active_index) - 80, -18)
	if _underline_tween != null and _underline_tween.is_valid():
		_underline_tween.kill()
	var target_x := _tab_center(active_index) - 42
	if animate:
		_underline_tween = create_tween()
		_underline_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_underline_tween.tween_property(_underline, "position:x", target_x, 0.16)
	else:
		_underline.position.x = target_x


func _apply_colors(animated: bool) -> void:
	for i in range(5):
		var active := i == active_index
		var hovered := i == _hover_index and not active
		var top := Color("c9fbf1") if active else (Color("eaf8ff") if hovered else Color("d9eefb"))
		var bottom := Color("58cdbd") if active else (Color("b9daee") if hovered else Color("a4c9e2"))
		var border := Color("f4fffd") if active else Color("e9f8ff")
		_bgs[i].setup(Vector2(TAB_W, TAB_H), 9.0, top, bottom, border, 2.2, 0.76)
		_labels[i].label_settings.font_color = Color("ffffff") if active else Color(0.93, 0.99, 1.0)
		_labels[i].label_settings.outline_size = 3 if active else 3
		_labels[i].label_settings.outline_color = Color(0.06, 0.32, 0.30, 0.95) if active else Color(0.08, 0.26, 0.38, 0.85)
		_labels[i].label_settings.font_size = 20


func _hit_tab(pos: Vector2) -> int:
	for i in range(5):
		var r := Rect2(i * (TAB_W + GAP), 0, TAB_W, TAB_H)
		if r.has_point(pos):
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
