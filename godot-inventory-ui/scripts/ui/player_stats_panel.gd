class_name PlayerStatsPanel
extends Control

# Re-measured from the reference (see docs/fidelity-1to1.md):
#   HP bar x 92..242 @ y 253..267 -> 223..586 @ 512..540
#   stats rows y 300..317 / 322..339 -> 607..641 / 651..686
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
const BAR_W := 358.0
const BAR_H := 30.0
const BAR_X := 165.0
const INK := Color("2f5c86")


func setup(state: InventoryState) -> void:
	_state = state
	size = Vector2(600, 178)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_track = GradientRect.new()
	_hp_track.position = Vector2(BAR_X, 8)
	_hp_track.setup(Vector2(BAR_W, BAR_H), 15.0, Color(0.14, 0.28, 0.40, 0.32), Color(0.10, 0.22, 0.33, 0.40),
		Color(0.90, 0.98, 1.0, 0.42), 1.4, 0.0)
	add_child(_hp_track)
	_hp_fill = GradientRect.new()
	_hp_fill.position = Vector2(BAR_X, 8)
	_hp_fill.setup(Vector2(240, BAR_H), 15.0, ThemeKit.HP_TOP, ThemeKit.HP_BOTTOM,
		Color("b84848"), 1.6, 0.65)
	add_child(_hp_fill)
	_hp_label = ThemeKit.make_label(self, "2086 / 2586", 20, ThemeKit.TEXT_LIGHT,
		Vector2(BAR_X, 8), Vector2(BAR_W, BAR_H), HORIZONTAL_ALIGNMENT_CENTER,
		ThemeKit.body_font(), 3, Color(0.30, 0.10, 0.10, 0.9))

	_mp_track = GradientRect.new()
	_mp_track.position = Vector2(BAR_X, 46)
	_mp_track.setup(Vector2(BAR_W, BAR_H), 15.0, Color(0.14, 0.28, 0.40, 0.32), Color(0.10, 0.22, 0.33, 0.40),
		Color(0.90, 0.98, 1.0, 0.42), 1.4, 0.0)
	add_child(_mp_track)
	_mp_fill = GradientRect.new()
	_mp_fill.position = Vector2(BAR_X, 46)
	_mp_fill.setup(Vector2(210, BAR_H), 15.0, ThemeKit.MP_TOP, ThemeKit.MP_BOTTOM,
		Color("2f6fae"), 1.6, 0.65)
	add_child(_mp_fill)
	_mp_label = ThemeKit.make_label(self, "1969 / 2769", 20, ThemeKit.TEXT_LIGHT,
		Vector2(BAR_X, 46), Vector2(BAR_W, BAR_H), HORIZONTAL_ALIGNMENT_CENTER,
		ThemeKit.body_font(), 3, Color(0.06, 0.18, 0.32, 0.9))

	ThemeKit.make_label(self, "气血", 26, INK, Vector2(44, 7), Vector2(112, 32),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(1, 1, 1, 0.45))
	ThemeKit.make_label(self, "魔法", 26, INK, Vector2(44, 45), Vector2(112, 32),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(1, 1, 1, 0.45))

	_add_stat("攻击", "attack", Vector2(60, 92), Vector2(160, 92), Vector2(32, 109))
	_add_stat("灵力", "spirit", Vector2(346, 92), Vector2(438, 92), Vector2(308, 109))
	_add_stat("防御", "defense", Vector2(60, 136), Vector2(160, 136), Vector2(32, 153))
	_add_stat("速度", "speed", Vector2(346, 136), Vector2(438, 136), Vector2(308, 153))

	update_values(false)


func _add_stat(label_text: String, key: String, label_pos: Vector2, value_pos: Vector2, _icon_pos: Vector2) -> void:
	ThemeKit.make_label(self, label_text, 24, INK, label_pos, Vector2(100, 34),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(1, 1, 1, 0.42))
	var value_label := ThemeKit.make_label(self, "0", 28, INK, value_pos, Vector2(130, 34),
		HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 2, Color(1, 1, 1, 0.42))
	_stat_values[key] = value_label


func bar_rects() -> Dictionary:
	return {
		"hp": Rect2(position + _hp_track.position, _hp_track.size),
		"mp": Rect2(position + _mp_track.position, _mp_track.size),
	}


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
	_draw_scaled(Vector2(25, 21), 1.35, 0)
	_draw_scaled(Vector2(25, 59), 1.35, 1)
	_draw_scaled(Vector2(32, 109), 1.15, 2)
	_draw_scaled(Vector2(308, 109), 1.15, 3)
	_draw_scaled(Vector2(32, 153), 1.15, 4)
	_draw_scaled(Vector2(308, 153), 1.15, 5)


func _draw_scaled(c: Vector2, scale: float, kind: int) -> void:
	draw_set_transform(c, 0.0, Vector2(scale, scale))
	match kind:
		0:
			_draw_heart(Vector2.ZERO, Color("ff9c9c"))
		1:
			_draw_drop(Vector2.ZERO, Color("83d8ff"))
		2:
			_draw_badge(Vector2.ZERO, Color("ffd36b"), 0)
		3:
			_draw_badge(Vector2.ZERO, Color("f2a1d9"), 1)
		4:
			_draw_badge(Vector2.ZERO, Color("ffb36b"), 2)
		5:
			_draw_badge(Vector2.ZERO, Color("7fe0a6"), 3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


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
