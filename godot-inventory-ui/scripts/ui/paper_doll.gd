class_name PaperDoll
extends Control

signal slot_hovered(data, screen_pos)
signal slot_unhovered()
signal slot_clicked(data)
signal codex_pressed()

const SLOT_KEYS := ["artifact", "boots", "armor", "helmet", "necklace", "ring_left", "ring_right", "weapon"]
const SLOT_POS := {
	"artifact": Vector2(222, 0),
	"boots": Vector2(26, 54),
	"armor": Vector2(432, 54),
	"helmet": Vector2(0, 186),
	"necklace": Vector2(456, 186),
	"ring_left": Vector2(58, 292),
	"ring_right": Vector2(398, 292),
	"weapon": Vector2(222, 316),
}

var _state: InventoryState
var _aura: TextureRect
var _rune: TextureRect
var _char: TextureRect
var _char_base_y := 62.0
var _slots: Dictionary = {}
var _t := 0.0
var _draw_accum := 0.0
var _center := Vector2(270, 206)


func setup(state: InventoryState) -> void:
	_state = state
	size = Vector2(560, 410)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_aura = ThemeKit.glow_texture_rect("glow", Color(0.55, 0.92, 1.0, 0.30))
	_aura.position = Vector2(54, -10)
	_aura.size = Vector2(432, 432)
	add_child(_aura)

	_rune = TextureRect.new()
	_rune.texture = ThemeKit.ui_tex("rune_ring")
	_rune.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rune.stretch_mode = TextureRect.STRETCH_SCALE
	_rune.position = Vector2(40, -24)
	_rune.size = Vector2(460, 460)
	_rune.pivot_offset = _rune.size * 0.5
	_rune.modulate = Color(0.80, 0.96, 1.0, 0.36)
	_rune.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rune)

	_char = TextureRect.new()
	_char.texture = load("res://assets/char/cloud_fox.svg")
	_char.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char.position = Vector2(174, _char_base_y)
	_char.size = Vector2(192, 240)
	_char.pivot_offset = Vector2(96, 240)
	_char.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_char)

	for key in SLOT_KEYS:
		var slot := EquipSlot.new()
		slot.setup(state.equipment_by_slot(key))
		slot.position = SLOT_POS[key]
		add_child(slot)
		slot.hovered.connect(_on_slot_hovered)
		slot.unhovered.connect(func(_s) -> void: slot_unhovered.emit())
		slot.clicked.connect(func(_s, d) -> void: slot_clicked.emit(d))
		_slots[key] = slot

	var codex := UIButton.new()
	codex.setup("图鉴", UIButton.Kind.ICE, Vector2(46, 46), 12)
	codex.position = Vector2(370, 138)
	codex.pressed.connect(func() -> void: codex_pressed.emit())
	add_child(codex)
	set_process(true)


func _on_slot_hovered(_s, d: Dictionary, pos: Vector2) -> void:
	slot_hovered.emit(d, pos)


func _process(delta: float) -> void:
	_t += delta
	if _rune != null:
		_rune.rotation += 0.09 * delta
	if _char != null:
		_char.position.y = _char_base_y + sin(_t * 1.5) * 2.5
	if _aura != null:
		_aura.modulate.a = 0.27 + 0.05 * sin(_t * 1.2)
	_draw_accum += delta
	if _draw_accum >= 0.033:
		_draw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	# soft ellipse under the character
	_draw_ellipse(_center + Vector2(0, 100), 80, 18, Color(0.08, 0.22, 0.32, 0.14))
	_draw_ellipse(_center + Vector2(0, 100), 48, 11, Color(0.08, 0.22, 0.32, 0.12))
	# aura ring
	draw_circle(_center, 200, Color(0.78, 0.94, 1.0, 0.16))
	draw_arc(_center, 200, 0, TAU, 96, Color(0.82, 0.97, 1.0, 0.55), 2.4, true)
	draw_arc(_center, 178, 0.4, TAU - 0.5, 72, Color(0.92, 1.0, 1.0, 0.38), 1.4, true)
	draw_arc(_center, 224, 2.2, 4.6, 40, Color(0.9, 0.8, 0.5, 0.30), 1.6, true)
	for i in range(8):
		var ang := TAU * i / 8.0 + _t * 0.02
		var p := _center + Vector2(cos(ang) * 212, sin(ang) * 212)
		var s := 3.0 if i % 2 == 0 else 1.8
		var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		draw_colored_polygon(pts, Color(0.92, 1.0, 1.0, 0.4))
	# floating sparkles
	for i in range(4):
		var ang := _t * (0.25 + i * 0.07) + i * 1.7
		var p := _center + Vector2(cos(ang) * (130 + i * 16), sin(ang * 1.2) * 112 - 20)
		var s := 2.0 + sin(_t * 2 + i) * 1.0
		draw_circle(p, maxf(0.8, s), Color(0.95, 1.0, 0.9, 0.35))


func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(40):
		var a := TAU * i / 40.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func get_slot(key: String) -> EquipSlot:
	return _slots.get(key, null)
