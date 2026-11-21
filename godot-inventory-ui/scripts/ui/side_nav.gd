class_name SideNav
extends Control

signal nav_selected(key: String)

# Reference (529x356): active tab 495..528 x 43..107 -> 78x129 at 1280x720,
# pitch 72 px -> 145.6 (129 + 16 gap).
const ITEMS := [
	["bag", "物\n品"],
	["alchemy", "炼\n丹"],
	["codex", "九\n州\n谱"],
]
const TAB_H := 129.0
const GAP := 16.0

var active_key := "bag"
var _hover := -1
var _tabs: Array = []
var _bgs: Array = []
var _labels: Array = []
var _glows: Array = []
var _built := false


func setup() -> void:
	size = Vector2(78, 3 * TAB_H + 2 * GAP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		return
	_built = true
	for i in range(3):
		var tab := Control.new()
		tab.position = Vector2(0, i * (TAB_H + GAP))
		tab.size = Vector2(78, TAB_H)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tab)
		var glow := ThemeKit.glow_texture_rect("glow", Color(0.6, 1.0, 0.92, 0.0))
		glow.position = Vector2(-26, -20)
		glow.size = Vector2(128, TAB_H + 40)
		tab.add_child(glow)
		var bg := GradientRect.new()
		bg.position = Vector2.ZERO
		bg.setup(Vector2(78, TAB_H), 12.0, Color("3f6b98"), Color("2a5075"),
			Color("7595b5"), 1.6, 0.4)
		tab.add_child(bg)
		var label := Label.new()
		label.text = ITEMS[i][1]
		label.position = Vector2(0, 0)
		label.size = Vector2(78, TAB_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font = ThemeKit.body_font()
		ls.font_size = 25
		ls.font_color = Color("e6f4ff")
		ls.outline_size = 3
		ls.outline_color = Color(0.03, 0.10, 0.16, 0.9)
		label.label_settings = ls
		tab.add_child(label)
		_tabs.append(tab)
		_bgs.append(bg)
		_labels.append(label)
		_glows.append(glow)
	mouse_exited.connect(_on_mouse_exit)
	_apply()


func _apply() -> void:
	for i in range(3):
		var key: String = ITEMS[i][0]
		var active := key == active_key
		var hovered := i == _hover and not active
		var top := Color("5bcdf5") if active else (Color("4c7ba9") if hovered else Color("3f6b98"))
		var bottom := Color("2fb4e6") if active else (Color("33597f") if hovered else Color("2a5075"))
		var border := Color("e8fcff") if active else (Color("a9c4dc") if hovered else Color("7595b5"))
		_bgs[i].setup(Vector2(78, TAB_H), 12.0, top, bottom, border, 2.0 if active else 1.6, 0.5)
		_labels[i].label_settings.font_color = Color("12506e") if active else Color("e6f4ff")
		_glows[i].modulate = Color(0.6, 1.0, 0.92, 0.28 if active else 0.0)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_tabs[i], "position:x", -8.0 if active else 0.0, 0.14)


func _hit(pos: Vector2) -> int:
	for i in range(3):
		if Rect2(0, i * (TAB_H + GAP), 78, TAB_H).has_point(pos):
			return i
	return -1


func tab_rect(i: int) -> Rect2:
	return Rect2(0, i * (TAB_H + GAP), 78, TAB_H)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit(event.position)
		if h != _hover:
			_hover = h
			_apply()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var idx := _hit(event.position)
		if idx >= 0:
			var key: String = ITEMS[idx][0]
			set_active(key)
			nav_selected.emit(key)
			accept_event()


func _on_mouse_exit() -> void:
	_hover = -1
	_apply()


func set_active(key: String) -> void:
	active_key = key
	_apply()


func click_for_test(key: String) -> void:
	set_active(key)
	nav_selected.emit(key)
