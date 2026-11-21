class_name SideNav
extends Control

signal nav_selected(key: String)

const ITEMS := [
	["bag", "物\n品"],
	["alchemy", "炼\n丹"],
	["codex", "九\n州\n谱"],
]
const TAB_H := 116.0
const GAP := 12.0

var active_key := "bag"
var _hover := -1
var _tabs: Array = []
var _bgs: Array = []
var _labels: Array = []
var _glows: Array = []
var _built := false


func setup() -> void:
	size = Vector2(54, 3 * TAB_H + 2 * GAP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _built:
		return
	_built = true
	for i in range(3):
		var tab := Control.new()
		tab.position = Vector2(0, i * (TAB_H + GAP))
		tab.size = Vector2(54, TAB_H)
		tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tab)
		var glow := ThemeKit.glow_texture_rect("glow", Color(0.6, 1.0, 0.92, 0.0))
		glow.position = Vector2(-26, -20)
		glow.size = Vector2(104, TAB_H + 40)
		tab.add_child(glow)
		var bg := GradientRect.new()
		bg.position = Vector2.ZERO
		bg.setup(Vector2(54, TAB_H), 11.0, Color("2a586f"), Color("153447"),
			Color("b7914a"), 1.5, 0.4)
		tab.add_child(bg)
		var label := Label.new()
		label.text = ITEMS[i][1]
		label.position = Vector2(0, 0)
		label.size = Vector2(54, TAB_H)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ls := LabelSettings.new()
		ls.font = ThemeKit.body_font()
		ls.font_size = 17
		ls.font_color = ThemeKit.GOLD_BRIGHT
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
		var top := Color("b8f5ea") if active else (Color("356a84") if hovered else Color("2a586f"))
		var bottom := Color("5fcdbd") if active else (Color("1b465c") if hovered else Color("153447"))
		var border := Color("ecfffa") if active else (Color("e2c078") if hovered else Color("b7914a"))
		_bgs[i].setup(Vector2(54, TAB_H), 11.0, top, bottom, border, 1.8 if active else 1.5, 0.5)
		_labels[i].label_settings.font_color = Color("13544f") if active else ThemeKit.GOLD_BRIGHT
		_glows[i].modulate = Color(0.6, 1.0, 0.92, 0.30 if active else 0.0)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_tabs[i], "position:x", -8.0 if active else 0.0, 0.14)


func _hit(pos: Vector2) -> int:
	for i in range(3):
		if Rect2(0, i * (TAB_H + GAP), 54, TAB_H).has_point(pos):
			return i
	return -1


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
