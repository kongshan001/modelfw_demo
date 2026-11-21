class_name PaperDoll
extends Control

# Equipment ring re-measured from the 529x356 reference (see docs/fidelity-1to1.md):
# slot centers are mapped by normalised coordinates onto the 1280x720 canvas.
signal slot_hovered(data, screen_pos)
signal slot_unhovered()
signal slot_clicked(data)
signal codex_pressed()

const SLOT_KEYS := ["artifact", "boots", "armor", "helmet", "necklace", "ring_left", "ring_right", "weapon"]
const SLOT_POS := {
	"artifact": Vector2(212, 3),
	"boots": Vector2(47, 48),
	"armor": Vector2(383, 49),
	"helmet": Vector2(-2, 186),
	"necklace": Vector2(430, 186),
	"ring_left": Vector2(47, 319),
	"ring_right": Vector2(382, 319),
	"weapon": Vector2(218, 367),
}

var _state: InventoryState
var _aura: TextureRect
var _char: TextureRect
var _char_base_y := 84.0
var _slots: Dictionary = {}
var _t := 0.0
var _draw_accum := 0.0
var _center := Vector2(267, 230)


func setup(state: InventoryState) -> void:
	_state = state
	size = Vector2(560, 470)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_aura = ThemeKit.glow_texture_rect("glow", Color(0.60, 0.94, 1.0, 0.24))
	_aura.position = Vector2(42, 22)
	_aura.size = Vector2(450, 400)
	add_child(_aura)

	_char = TextureRect.new()
	_char.texture = load("res://assets/char/cloud_fox.svg")
	_char.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_char.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_char.position = Vector2(204, _char_base_y)
	_char.size = Vector2(160, 204)
	_char.pivot_offset = Vector2(80, 204)
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
	codex.setup("图鉴", UIButton.Kind.ICE, Vector2(40, 40), 12)
	codex.position = Vector2(322, 117)
	codex.pressed.connect(func() -> void: codex_pressed.emit())
	add_child(codex)
	set_process(true)


func _on_slot_hovered(_s, d: Dictionary, pos: Vector2) -> void:
	slot_hovered.emit(d, pos)


func _process(delta: float) -> void:
	_t += delta
	if _char != null:
		_char.position.y = _char_base_y + sin(_t * 1.5) * 2.0
	if _aura != null:
		_aura.modulate.a = 0.22 + 0.045 * sin(_t * 1.2)
	_draw_accum += delta
	if _draw_accum >= 0.033:
		_draw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	# large soft halo disc behind the character (reference: pale blue circle)
	_draw_ellipse(_center, 262, 218, Color(0.80, 0.94, 1.0, 0.14))
	_draw_ellipse(_center + Vector2(0, 118), 92, 20, Color(0.10, 0.26, 0.36, 0.12))
	# two thin rings, normalised ellipse (1.22 x radius) to match the stretched canvas
	_draw_ellipse_ring(_center, 260, 214, Color(0.86, 0.98, 1.0, 0.50), 2.0)
	_draw_ellipse_ring(_center, 236, 194, Color(0.92, 1.0, 1.0, 0.26), 1.2)
	_draw_ellipse_ring(_center, 276, 226, Color(0.92, 0.82, 0.56, 0.22), 1.4)
	# small cardinal diamonds
	for i in range(8):
		var ang := TAU * i / 8.0 + _t * 0.02
		var p := _center + Vector2(cos(ang) * 262, sin(ang) * 214)
		var s := 2.6 if i % 2 == 0 else 1.6
		var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		draw_colored_polygon(pts, Color(0.92, 1.0, 1.0, 0.35))
	# floating sparkles
	for i in range(4):
		var ang := _t * (0.25 + i * 0.07) + i * 1.7
		var p := _center + Vector2(cos(ang) * (150 + i * 18), sin(ang * 1.2) * 120 - 18)
		var s := 1.8 + sin(_t * 2 + i) * 0.9
		draw_circle(p, maxf(0.7, s), Color(0.96, 1.0, 0.94, 0.32))


func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(48):
		var a := TAU * i / 48.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, col)


func _draw_ellipse_ring(center: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in range(65):
		var a := TAU * i / 64.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, width, true)


func get_slot(key: String) -> EquipSlot:
	return _slots.get(key, null)


func slot_rect(key: String) -> Rect2:
	var slot: EquipSlot = _slots.get(key, null)
	if slot == null:
		return Rect2()
	return Rect2(position + slot.position, slot.size)

