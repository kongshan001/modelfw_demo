class_name SelectBackdrop
extends Control

# 程序化山海晨雾背景：天空渐变、日轮、三层远山、云气、竹影、飘落花瓣与暗角。
# 只在一个 _draw 里画，粒子更新不创建节点；角色主色用于中心光晕。

const DESIGN := Vector2(1920, 1080)

var _accent := Color(0.45, 0.8, 1.0)
var _accent_target := Color(0.45, 0.8, 1.0)
var _parallax := Vector2.ZERO
var _parallax_target := Vector2.ZERO
var _time := 0.0
var _rng := RandomNumberGenerator.new()

var _petal_x: Array[float] = []
var _petal_y: Array[float] = []
var _petal_speed: Array[float] = []
var _petal_phase: Array[float] = []
var _petal_size: Array[float] = []
var _petal_tint: Array[Color] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 20261027
	for index in 54:
		_petal_x.append(_rng.randf_range(0.0, DESIGN.x))
		_petal_y.append(_rng.randf_range(0.0, DESIGN.y))
		_petal_speed.append(_rng.randf_range(8.0, 24.0))
		_petal_phase.append(_rng.randf_range(0.0, TAU))
		_petal_size.append(_rng.randf_range(2.0, 5.0))
		var roll := _rng.randf()
		if roll < 0.45:
			_petal_tint.append(Color(1.0, 0.86, 0.55, 0.55))
		elif roll < 0.75:
			_petal_tint.append(Color(1.0, 0.72, 0.66, 0.42))
		else:
			_petal_tint.append(Color(0.62, 0.86, 1.0, 0.42))
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	_accent = _accent.lerp(_accent_target, minf(1.0, delta * 3.2))
	_parallax = _parallax.lerp(_parallax_target, minf(1.0, delta * 3.5))
	for index in _petal_y.size():
		_petal_y[index] += _petal_speed[index] * delta
		if _petal_y[index] > DESIGN.y + 20.0:
			_petal_y[index] = -20.0
			_petal_x[index] = _rng.randf_range(0.0, DESIGN.x)
	queue_redraw()

func set_accent(color: Color) -> void:
	_accent_target = color

func set_parallax(offset: Vector2) -> void:
	_parallax_target = offset.limit_length(26.0)

func play_intro() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	_draw_sky()
	_draw_sun()
	_draw_mountain_layer([
		Vector2(0, 640), Vector2(150, 500), Vector2(300, 560), Vector2(470, 420),
		Vector2(640, 520), Vector2(830, 400), Vector2(1010, 520), Vector2(1190, 430),
		Vector2(1380, 540), Vector2(1580, 460), Vector2(1760, 540), Vector2(1920, 500),
	], Color(0.24, 0.24, 0.34, 0.92), 0.18)
	_draw_clouds()
	_draw_mountain_layer([
		Vector2(0, 720), Vector2(170, 580), Vector2(340, 640), Vector2(520, 520),
		Vector2(700, 610), Vector2(880, 500), Vector2(1060, 590), Vector2(1240, 540),
		Vector2(1420, 630), Vector2(1610, 550), Vector2(1790, 620), Vector2(1920, 580),
	], Color(0.14, 0.2, 0.25, 0.96), 0.36)
	_draw_mountain_layer([
		Vector2(0, 840), Vector2(180, 700), Vector2(360, 760), Vector2(540, 660),
		Vector2(720, 740), Vector2(900, 650), Vector2(1080, 730), Vector2(1260, 680),
		Vector2(1440, 760), Vector2(1620, 690), Vector2(1800, 750), Vector2(1920, 710),
	], Color(0.06, 0.12, 0.11, 0.98), 0.58)
	_draw_ground()
	_draw_bamboo()
	_draw_glow()
	_draw_petals()
	_draw_vignette()

func _draw_sky() -> void:
	var stops := [
		[0.0, Color(0.05, 0.04, 0.1)],
		[0.32, Color(0.13, 0.1, 0.2)],
		[0.55, Color(0.35, 0.21, 0.25)],
		[0.68, Color(0.72, 0.42, 0.31)],
		[0.78, Color(0.34, 0.23, 0.22)],
		[1.0, Color(0.035, 0.06, 0.055)],
	]
	var bands := 36
	for index in bands:
		var t0 := float(index) / bands
		var t1 := float(index + 1) / bands
		var color := _sample_stops(stops, (t0 + t1) * 0.5)
		draw_rect(Rect2(0, t0 * DESIGN.y, DESIGN.x, (t1 - t0) * DESIGN.y + 1.0), color)

func _sample_stops(stops: Array, t: float) -> Color:
	for index in stops.size() - 1:
		var a: Array = stops[index]
		var b: Array = stops[index + 1]
		if t >= float(a[0]) and t <= float(b[0]):
			var span: float = maxf(0.0001, float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1] as Color, (t - float(a[0])) / span)
	return stops[stops.size() - 1][1] as Color

func _draw_sun() -> void:
	var center := Vector2(1080, 286) + _parallax * 0.22
	for index in 12:
		var radius := 90.0 + index * 21.0
		var alpha := 0.026 - index * 0.0018
		draw_circle(center, radius, Color(1.0, 0.82, 0.58, maxf(0.0, alpha)))
	draw_circle(center, 74.0, Color(1.0, 0.88, 0.66, 0.92))
	draw_circle(center, 62.0, Color(1.0, 0.94, 0.8, 0.85))
	# 立绘后的柔和日轮，形成角色光环。
	var halo := Vector2(630, 470) + _parallax * 0.1
	for index in 10:
		draw_circle(halo, 250.0 - index * 20.0, Color(1.0, 0.85, 0.62, 0.006 + index * 0.003))

func _draw_mountain_layer(peaks: Array, color: Color, parallax_scale: float) -> void:
	var points := PackedVector2Array()
	var offset := _parallax * parallax_scale
	points.append(Vector2(-40, DESIGN.y))
	for point in peaks:
		points.append((point as Vector2) + offset)
	points.append(Vector2(DESIGN.x + 40, DESIGN.y))
	draw_colored_polygon(points, color)
	# 山脊高光
	var ridge := PackedVector2Array()
	for point in peaks:
		ridge.append((point as Vector2) + offset)
	draw_polyline(ridge, Color(1.0, 0.85, 0.7, 0.08), 2.0, true)

func _draw_clouds() -> void:
	for band in 5:
		var y := 360.0 + band * 74.0
		var drift := sin(_time * 0.05 + band) * 40.0
		for index in 6:
			var x := fposmod(index * 360.0 + drift + band * 120.0, DESIGN.x + 400.0) - 200.0
			var radius := 90.0 + index % 3 * 42.0
			draw_circle(Vector2(x, y), radius, Color(1.0, 0.9, 0.82, 0.028))

func _draw_ground() -> void:
	draw_rect(Rect2(0, 820, DESIGN.x, 260), Color(0.035, 0.065, 0.06, 0.96))
	for index in 4:
		var y := 840.0 + index * 46.0
		draw_rect(Rect2(0, y, DESIGN.x, 22), Color(0.08, 0.14, 0.11, 0.12))
	# 草叶
	for index in 70:
		var x := float(index) * 28.0 + 11.0
		var base := 900.0 + float((index * 37) % 140)
		var sway := sin(_time * 0.8 + index) * 4.0
		draw_line(Vector2(x, base), Vector2(x + sway, base - 22.0 - index % 18), Color(0.16, 0.28, 0.2, 0.55), 2.0)

func _draw_bamboo() -> void:
	for side in 2:
		for index in 4:
			var x := (26.0 + index * 34.0) if side == 0 else (1780.0 + index * 34.0)
			var sway := sin(_time * 0.4 + index * 0.8) * 5.0
			var top := 150.0 + index * 40.0
			draw_line(Vector2(x, 1080), Vector2(x + sway, top), Color(0.055, 0.12, 0.09, 0.85), 7.0)
			for node in 5:
				var y := 980.0 - node * 150.0
				draw_line(Vector2(x - 5, y), Vector2(x + 5, y), Color(0.12, 0.2, 0.14, 0.6), 2.0)
			for leaf in 4:
				var ly := 260.0 + leaf * 130.0
				var dir := -1.0 if leaf % 2 == 0 else 1.0
				var points := PackedVector2Array([
					Vector2(x + sway, ly),
					Vector2(x + dir * 46.0 + sway, ly - 24.0),
					Vector2(x + dir * 62.0 + sway, ly - 6.0),
				])
				draw_colored_polygon(points, Color(0.08, 0.17, 0.12, 0.75))

func _draw_glow() -> void:
	var center := Vector2(630, 620) + _parallax * 0.08
	for index in 20:
		var radius := 400.0 - index * 17.0
		draw_circle(center, radius, Color(_accent.r, _accent.g, _accent.b, 0.006))
	# 中央光柱
	var shaft := PackedVector2Array([
		Vector2(500, 0), Vector2(800, 0), Vector2(900, 900), Vector2(380, 900),
	])
	draw_colored_polygon(shaft, Color(1.0, 0.9, 0.7, 0.012))

func _draw_petals() -> void:
	for index in _petal_x.size():
		var x := _petal_x[index] + sin(_time * 0.7 + _petal_phase[index]) * 18.0
		var y := _petal_y[index]
		var tint := _petal_tint[index]
		var size := _petal_size[index]
		draw_line(Vector2(x, y), Vector2(x + size * 1.6, y + size), tint, 2.0)
		draw_circle(Vector2(x, y), size * 0.45, tint)

func _draw_vignette() -> void:
	for index in 8:
		var alpha := 0.045 * (1.0 - float(index) / 8.0)
		var band := 13.0
		draw_rect(Rect2(0, index * band, DESIGN.x, band), Color(0, 0, 0, alpha))
		draw_rect(Rect2(0, DESIGN.y - (index + 1) * band, DESIGN.x, band), Color(0, 0, 0, alpha))
		draw_rect(Rect2(index * 17, 0, 17, DESIGN.y), Color(0, 0, 0, alpha))
		draw_rect(Rect2(DESIGN.x - (index + 1) * 17, 0, 17, DESIGN.y), Color(0, 0, 0, alpha))
