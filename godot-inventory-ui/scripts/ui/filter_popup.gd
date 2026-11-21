class_name FilterPopup
extends Control

signal category_selected(category: String)
signal closed

const PANEL_POS := Vector2(1084, 150)
const PANEL_W := 118.0
const ROW_H := 30.0

var categories: Array = []
var _rows: Array = []
var _current := "全部"
var _hover := -1
var _bg: GradientRect
var _open := false
var _tween: Tween


func setup(cats: Array) -> void:
	categories = cats
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_bg = GradientRect.new()
	_bg.position = PANEL_POS
	_bg.setup(Vector2(PANEL_W, ROW_H * categories.size() + 12), 10.0,
		Color(0.055, 0.15, 0.215, 0.97), Color(0.025, 0.075, 0.12, 0.98),
		Color(0.91, 0.77, 0.46, 0.9), 1.5, 0.0)
	add_child(_bg)
	for i in range(categories.size()):
		var label := Label.new()
		label.text = str(categories[i])
		label.position = PANEL_POS + Vector2(16, 6 + i * ROW_H)
		label.size = Vector2(PANEL_W - 32, ROW_H)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font = ThemeKit.body_font()
		ls.font_size = 14
		ls.font_color = Color("dcecf5")
		label.label_settings = ls
		add_child(label)
		_rows.append(label)
	mouse_exited.connect(func() -> void:
		_hover = -1
		_repaint())


func show_popup(current: String) -> void:
	_current = current
	visible = true
	_open = true
	_repaint()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	modulate.a = 0.0
	_bg.position.y = PANEL_POS.y - 8
	_tween = create_tween().set_parallel(true)
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.12)
	_tween.tween_property(_bg, "position:y", PANEL_POS.y, 0.12)


func hide_popup(emit_closed: bool = false) -> void:
	if not _open:
		return
	_open = false
	visible = false
	if emit_closed:
		closed.emit()


func is_open() -> bool:
	return _open


func _repaint() -> void:
	for i in range(_rows.size()):
		var active: bool = str(categories[i]) == _current
		var hovered: bool = i == _hover and not active
		var c := Color("ffe9b3") if active else (Color("f3fbff") if hovered else Color("d3e6f1"))
		_rows[i].label_settings.font_color = c
		_rows[i].text = ("◆  " if active else "    ") + str(categories[i])


func _row_at(pos: Vector2) -> int:
	var panel := Rect2(PANEL_POS, Vector2(PANEL_W, ROW_H * categories.size() + 12))
	if not panel.has_point(pos):
		return -1
	var idx := int((pos.y - PANEL_POS.y - 6) / ROW_H)
	if idx >= 0 and idx < categories.size():
		return idx
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _row_at(event.position)
		if h != _hover:
			_hover = h
			_repaint()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _row_at(event.position)
		if idx >= 0:
			_current = str(categories[idx])
			hide_popup(false)
			category_selected.emit(_current)
		else:
			hide_popup(true)
		accept_event()
