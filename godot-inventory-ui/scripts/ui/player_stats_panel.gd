class_name PlayerStatsPanel
extends Control

var _state: InventoryState
var _hp_fill: GradientRect
var _mp_fill: GradientRect
var _hp_label: Label
var _mp_label: Label
var _hp_track: GradientRect
var _mp_track: GradientRect
var _hp_tween: Tween
var _mp_tween: Tween
var _stat_values: Dictionary = {}
const BAR_W := 300.0
const BAR_H := 22.0


func setup(state: InventoryState) -> void:
	_state = state
	size = Vector2(560, 178)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_track = GradientRect.new()
	_hp_track.position = Vector2(126, 5)
	_hp_track.setup(Vector2(BAR_W, BAR_H), 11.0, Color(0.10, 0.22, 0.32, 0.30), Color(0.08, 0.18, 0.27, 0.38),
		Color(0.95, 0.99, 1.0, 0.35), 1.5, 0.0)
	add_child(_hp_track)
	_hp_fill = GradientRect.new()
	_hp_fill.position = Vector2(126, 5)
	_hp_fill.setup(Vector2(240, BAR_H), 11.0, ThemeKit.HP_TOP, ThemeKit.HP_BOTTOM,
		Color("a83934"), 1.6, 0.75)
	add_child(_hp_fill)
	_hp_label = ThemeKit.make_label(self, "2086 / 2586", 14, ThemeKit.TEXT_LIGHT,
		Vector2(126, 5), Vector2(BAR_W, BAR_H), HORIZONTAL_ALIGNMENT_CENTER,
		ThemeKit.body_font(), 3, Color(0.35, 0.05, 0.05, 0.9))

	_mp_track = GradientRect.new()
	_mp_track.position = Vector2(126, 41)
	_mp_track.setup(Vector2(BAR_W, BAR_H), 11.0, Color(0.10, 0.22, 0.32, 0.30), Color(0.08, 0.18, 0.27, 0.38),
		Color(0.95, 0.99, 1.0, 0.35), 1.5, 0.0)
	add_child(_mp_track)
	_mp_fill = GradientRect.new()
	_mp_fill.position = Vector2(126, 41)
	_mp_fill.setup(Vector2(210, BAR_H), 11.0, ThemeKit.MP_TOP, ThemeKit.MP_BOTTOM,
		Color("2a5f9e"), 1.6, 0.75)
	add_child(_mp_fill)
	_mp_label = ThemeKit.make_label(self, "1969 / 2769", 14, ThemeKit.TEXT_LIGHT,
		Vector2(126, 41), Vector2(BAR_W, BAR_H), HORIZONTAL_ALIGNMENT_CENTER,
		ThemeKit.body_font(), 3, Color(0.03, 0.13, 0.27, 0.9))

	ThemeKit.make_label(self, "气血", 19, ThemeKit.TEXT_LIGHT, Vector2(38, 0), Vector2(76, 30),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.12, 0.27, 0.37, 0.85))
	ThemeKit.make_label(self, "魔法", 19, ThemeKit.TEXT_LIGHT, Vector2(38, 36), Vector2(76, 30),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.12, 0.27, 0.37, 0.85))

	_add_stat("攻击", "attack", Vector2(8, 78))
	_add_stat("灵力", "spirit", Vector2(278, 78))
	_add_stat("防御", "defense", Vector2(8, 116))
	_add_stat("速度", "speed", Vector2(278, 116))

	update_values(false)


func _add_stat(label_text: String, key: String, pos: Vector2) -> void:
	ThemeKit.make_label(self, label_text, 17, ThemeKit.TEXT_LIGHT, pos + Vector2(30, 0), Vector2(70, 28),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.12, 0.27, 0.37, 0.85))
	var value_label := ThemeKit.make_label(self, "0", 21, ThemeKit.TEXT_LIGHT, pos + Vector2(96, 0), Vector2(120, 28),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 3, Color(0.12, 0.27, 0.37, 0.85))
	_stat_values[key] = value_label


func update_values(animate: bool = false) -> void:
	if _state == null:
		return
	var hp_ratio := clampf(float(_state.player["hp"]) / float(maxi(1, _state.player["hp_max"])), 0.0, 1.0)
	var mp_ratio := clampf(float(_state.player["mp"]) / float(maxi(1, _state.player["mp_max"])), 0.0, 1.0)
	var hp_w := BAR_W * hp_ratio
	var mp_w := BAR_W * mp_ratio
	if animate:
		if _hp_tween != null and _hp_tween.is_valid():
			_hp_tween.kill()
		_hp_tween = create_tween()
		_hp_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_hp_tween.tween_property(_hp_fill, "size:x", hp_w, 0.22)
		if _mp_tween != null and _mp_tween.is_valid():
			_mp_tween.kill()
		_mp_tween = create_tween()
		_mp_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_mp_tween.tween_property(_mp_fill, "size:x", mp_w, 0.22)
	else:
		_hp_fill.size.x = hp_w
		_mp_fill.size.x = mp_w
	_hp_label.text = "%d / %d" % [int(_state.player["hp"]), int(_state.player["hp_max"])]
	_mp_label.text = "%d / %d" % [int(_state.player["mp"]), int(_state.player["mp_max"])]
	for key in _stat_values.keys():
		_stat_values[key].text = str(int(_state.player.get(key, 0)))
	queue_redraw()


func _draw() -> void:
	_draw_heart(Vector2(17, 17), Color("ff9c9c"))
	_draw_drop(Vector2(17, 53), Color("83d8ff"))
	_draw_badge(Vector2(22, 94), Color("ffd36b"), 0)
	_draw_badge(Vector2(292, 94), Color("f2a1d9"), 1)
	_draw_badge(Vector2(22, 132), Color("ffb36b"), 2)
	_draw_badge(Vector2(292, 132), Color("7fe0a6"), 3)


func _draw_heart(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, 9))
	pts.append(c + Vector2(-10, -1))
	pts.append(c + Vector2(-8, -8))
	pts.append(c + Vector2(-2, -10))
	pts.append(c + Vector2(0, -6))
	pts.append(c + Vector2(2, -10))
	pts.append(c + Vector2(8, -8))
	pts.append(c + Vector2(10, -1))
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.55), 1.2)
	draw_circle(c + Vector2(-3, -3), 2.4, Color(1, 1, 1, 0.5))


func _draw_drop(c: Vector2, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(0, -11), c + Vector2(7, -2), c + Vector2(9, 4),
		c + Vector2(5, 10), c + Vector2(-1, 11), c + Vector2(-7, 7),
		c + Vector2(-9, 1), c + Vector2(-5, -5),
	])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.55), 1.2)
	draw_circle(c + Vector2(-3, 0), 2.0, Color(1, 1, 1, 0.5))


func _draw_badge(c: Vector2, col: Color, kind: int) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0), c + Vector2(0, 12), c + Vector2(-12, 0)])
	draw_colored_polygon(pts, col.darkened(0.06))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.65), 1.2)
	var ink := Color(0.36, 0.25, 0.12, 0.9)
	match kind:
		0:  # up arrow
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(2, 0), c + Vector2(2, 7),
				c + Vector2(-2, 7), c + Vector2(-2, 0), c + Vector2(-6, 0),
			]), Color(1.0, 0.98, 0.9))
		1:  # spirit flower
			for i in range(4):
				var a := TAU * i / 4.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 4.5, 3.2, Color(1, 1, 1, 0.9))
			draw_circle(c, 2.2, Color(1, 0.92, 0.55))
		2:  # shield
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-5, -5), c + Vector2(5, -5), c + Vector2(4, 4), c + Vector2(0, 8), c + Vector2(-4, 4),
			]), Color(1, 1, 1, 0.9))
			draw_line(c + Vector2(-2, 1), c + Vector2(0, 4), Color(0.55, 0.32, 0.2), 1.5)
			draw_line(c + Vector2(0, 4), c + Vector2(3, -1), Color(0.55, 0.32, 0.2), 1.5)
		3:  # lightning
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(1, -8), c + Vector2(-5, 1), c + Vector2(0, 1), c + Vector2(-1, 8),
				c + Vector2(6, -2), c + Vector2(1, -2),
			]), Color(1, 1, 1, 0.94))
