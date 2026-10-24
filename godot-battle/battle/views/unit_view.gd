class_name UnitView
extends Node2D

signal clicked(view: UnitView)

const BAR_WIDTH := 104.0
const BAR_HEIGHT := 9.0

var unit_id: StringName
var side: int = BattleTypes.Side.ALLY
var home_position := Vector2.ZERO
var unit_state: BattleUnitState
var is_ally := false

var _sprite: Sprite2D
var _name_label: Label
var _hp_bg: ColorRect
var _hp_trail: ColorRect
var _hp_fill: ColorRect
var _mp_bg: ColorRect
var _mp_fill: ColorRect
var _status_row: HBoxContainer
var _selection: Polygon2D
var _target_arrow: Polygon2D
var _click_area: Area2D
var _idle_tween: Tween
var _body_color := Color(0.35, 0.6, 1.0)
var _visual_rng := RandomNumberGenerator.new()

func _ready() -> void:
	_build_placeholder()
	_build_bars()
	_build_click_area()

func setup(unit: BattleUnitState, home: Vector2, ally: bool) -> void:
	unit_state = unit
	unit_id = unit.id
	side = unit.side
	is_ally = ally
	home_position = home
	position = home
	_visual_rng.seed = hash(String(unit_id)) + 17
	_body_color = Color(0.32, 0.62, 1.0) if ally else Color(0.95, 0.36, 0.3)
	_name_label.text = unit.data.display_name
	refresh_from_state(unit)
	visible = true
	_start_idle()

func refresh_from_state(unit: BattleUnitState) -> void:
	unit_state = unit
	set_hp(unit.hp, false)
	set_mp(unit.mp, false)
	set_statuses(unit.statuses)
	visible = unit.is_alive() or unit.hp > 0
	if not unit.is_alive():
		modulate.a = 0.35
		rotation = deg_to_rad(-12.0)
		position = home_position + Vector2(0, 26)

func _build_placeholder() -> void:
	_sprite = Sprite2D.new()
	_sprite.visible = false
	add_child(_sprite)
	var shadow := Polygon2D.new()
	shadow.polygon = _ellipse_points(64, 18)
	shadow.color = Color(0, 0, 0, 0.28)
	shadow.position = Vector2(0, 10)
	add_child(shadow)

func _draw() -> void:
	# 程序化 Q 版剪影：脚底在 y=0，身高约 210px
	draw_circle(Vector2(0, -178), 38.0, _body_color.lightened(0.25))
	draw_rect(Rect2(-36, -150, 72, 92), _body_color, true)
	draw_colored_polygon(PackedVector2Array([Vector2(-24, -58), Vector2(24, -58), Vector2(40, 6), Vector2(-40, 6)]), _body_color.darkened(0.15))
	if is_ally:
		draw_line(Vector2(34, -122), Vector2(78, -186), Color(0.9, 0.9, 0.95), 7.0)
	else:
		draw_line(Vector2(-34, -122), Vector2(-74, -178), Color(0.55, 0.35, 0.2), 7.0)
	draw_circle(Vector2(-12, -184), 3.5, Color(0.1, 0.1, 0.15))
	draw_circle(Vector2(12, -184), 3.5, Color(0.1, 0.1, 0.15))

func _build_bars() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(-70, -262)
	_name_label.size = Vector2(140, 24)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_override("font", FontUtil.cjk_font())
	_name_label.add_theme_font_size_override("font_size", 18)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_name_label)

	_hp_bg = _bar(Color(0.1, 0.1, 0.12, 0.9), Vector2(-BAR_WIDTH / 2, -238))
	_hp_trail = _bar(Color(1, 1, 1, 0.6), Vector2(-BAR_WIDTH / 2, -238))
	_hp_fill = _bar(Color(0.3, 0.9, 0.4), Vector2(-BAR_WIDTH / 2, -238))
	_mp_bg = _bar(Color(0.1, 0.1, 0.12, 0.9), Vector2(-BAR_WIDTH / 2, -226))
	_mp_fill = _bar(Color(0.35, 0.65, 1.0), Vector2(-BAR_WIDTH / 2, -226))

	_status_row = HBoxContainer.new()
	_status_row.position = Vector2(-BAR_WIDTH / 2, -214)
	_status_row.size = Vector2(BAR_WIDTH, 18)
	_status_row.add_theme_constant_override("separation", 4)
	add_child(_status_row)

	_selection = Polygon2D.new()
	_selection.polygon = _ellipse_points(58, 16)
	_selection.color = Color(1.0, 0.85, 0.2, 0.55)
	_selection.position = Vector2(0, 8)
	_selection.visible = false
	add_child(_selection)

	_target_arrow = Polygon2D.new()
	_target_arrow.polygon = PackedVector2Array([Vector2(-14, -292), Vector2(14, -292), Vector2(0, -270)])
	_target_arrow.color = Color(1.0, 0.85, 0.15)
	_target_arrow.visible = false
	add_child(_target_arrow)

func _bar(color: Color, pos: Vector2) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.position = pos
	rect.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	add_child(rect)
	return rect

func _build_click_area() -> void:
	_click_area = Area2D.new()
	_click_area.input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(136, 290)
	collision.shape = shape
	collision.position = Vector2(0, -140)
	_click_area.add_child(collision)
	add_child(_click_area)
	_click_area.input_event.connect(_on_input_event)

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(self)

func _ellipse_points(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(Vector2(cos(angle) * rx, sin(angle) * ry))
	return points

func set_hp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_hp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	_hp_fill.size.x = target_width
	if animate:
		var tween := create_tween()
		tween.tween_property(_hp_trail, "size:x", target_width, 0.35).set_delay(0.15)
	else:
		_hp_trail.size.x = target_width

func set_mp(value: int, animate: bool = true) -> void:
	if unit_state == null:
		return
	var ratio := clampf(float(value) / float(maxi(1, unit_state.data.max_mp)), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	if animate:
		create_tween().tween_property(_mp_fill, "size:x", target_width, 0.25)
	else:
		_mp_fill.size.x = target_width

func set_statuses(statuses: Array[StatusInstance]) -> void:
	for child in _status_row.get_children():
		child.queue_free()
	for status in statuses:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = status.data.display_color
		dot.tooltip_text = status.data.display_name
		_status_row.add_child(dot)

func set_selected(value: bool) -> void:
	_selection.visible = value
	if value:
		_position_glow()

func set_targetable(value: bool) -> void:
	_target_arrow.visible = value

func _position_glow() -> void:
	_selection.modulate.a = 0.4 + 0.4 * absf(sin(Time.get_ticks_msec() / 300.0))

func _start_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	position = home_position
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(self, "position:y", home_position.y - 4.0, 0.9).set_trans(Tween.TRANS_SINE)
	_idle_tween.tween_property(self, "position:y", home_position.y, 0.9).set_trans(Tween.TRANS_SINE)

func stop_animations() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	position = home_position
	rotation = 0.0
	scale = Vector2.ONE
	modulate = Color.WHITE

func lunge_to(target_position: Vector2) -> void:
	stop_animations()
	var direction := signf(target_position.x - home_position.x)
	var destination := target_position - Vector2(direction * 120.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "position", destination, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished

func reset_pose() -> void:
	stop_animations()
	_start_idle()

func cast_pose() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.18)
	tween.parallel().tween_property(self, "modulate", Color(1.4, 1.6, 2.0), 0.18)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.2)
	await tween.finished

func hurt() -> void:
	stop_animations()
	var base := position
	var knock := base + Vector2(14.0 if is_ally else -14.0, 0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(3.0, 3.0, 3.0), 0.04)
	tween.tween_property(self, "modulate", Color.WHITE, 0.08)
	tween.parallel().tween_property(self, "position", knock, 0.08)
	tween.tween_property(self, "position", base, 0.12)
	await tween.finished
	if unit_state == null or unit_state.is_alive():
		_start_idle()

func die() -> void:
	stop_animations()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.parallel().tween_property(self, "rotation", deg_to_rad(-70.0), 0.35)
	tween.parallel().tween_property(self, "position:y", home_position.y + 34.0, 0.35)
	await tween.finished
	visible = false
