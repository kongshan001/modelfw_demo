extends Control

# 月下庭院背景：渐变、暖月晕、抽象藤蔓与少量萤火。全部程序化。

const TOP := Color("#0b130e")
const BOTTOM := Color("#141f15")
const GLOW := Color("#2d4830")
const VINE := Color("#607d55")

var _time := 0.0
var _redraw_accum := 0.0
var _fireflies: Array[Vector3] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 18:
		_fireflies.append(Vector3(_rand01(i * 17 + 4), _rand01(i * 29 + 9),
				0.25 + _rand01(i * 43 + 2) * 0.75))
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	_redraw_accum += delta
	if _redraw_accum >= 1.0 / 20.0:
		_redraw_accum = 0.0
		queue_redraw()


func _draw() -> void:
	var bands := 32
	for i in bands:
		var t := float(i) / float(bands - 1)
		var color := TOP.lerp(BOTTOM, t)
		draw_rect(Rect2(0.0, size.y * t, size.x, size.y / bands + 1.0), color)

	# 右上角的暖月晕。
	var center := Vector2(size.x * 0.82, size.y * 0.20)
	for i in 7:
		var radius := size.y * (0.10 + i * 0.085)
		draw_circle(center, radius, Color(0.40, 0.55, 0.34, 0.019))
	draw_circle(center, size.y * 0.035, Color(0.82, 0.86, 0.65, 0.10))
	draw_circle(center + Vector2(-size.y * 0.006, -size.y * 0.004),
			size.y * 0.030, Color(0.57, 0.68, 0.46, 0.10))

	# 很淡的庭园同心弧线。
	for i in 5:
		draw_arc(Vector2(size.x * 0.18, size.y * 0.92), size.x * (0.22 + i * 0.09),
				-PI * 0.78, -PI * 0.12, 50, Color(VINE.r, VINE.g, VINE.b, 0.045),
				1.2, true)
	for i in 4:
		draw_arc(Vector2(size.x * 0.93, size.y * 0.88), size.x * (0.14 + i * 0.08),
				PI * 1.02, PI * 1.80, 40, Color(VINE.r, VINE.g, VINE.b, 0.035),
				1.0, true)

	# 左侧抽象叶簇。
	_draw_leaf_cluster(Vector2(size.x * 0.045, size.y * 0.74), size.y * 0.25, 0.11)
	_draw_leaf_cluster(Vector2(size.x * 0.97, size.y * 0.33), size.y * 0.20, -0.08)

	# 漂浮萤火。
	for i in _fireflies.size():
		var data := _fireflies[i]
		var phase := _time * (0.14 + data.z * 0.18) + data.x * TAU + data.y * 3.0
		var pos := Vector2(
			data.x * size.x + sin(phase * 1.7) * size.x * 0.018,
			(0.12 + data.y * 0.78) * size.y + cos(phase * 1.1) * size.y * 0.024)
		var glow := 0.16 + 0.12 * (0.5 + 0.5 * sin(phase * 2.2))
		draw_circle(pos, 3.6, Color(0.82, 0.76, 0.45, glow * 0.32))
		draw_circle(pos, 1.0, Color(0.95, 0.89, 0.64, glow * 1.5))

	# 边缘暗角。
	var edge := maxf(26.0, size.y * 0.06)
	for i in 6:
		var alpha := 0.025 + i * 0.014
		var offset := edge * float(i) / 6.0
		draw_rect(Rect2(0.0, 0.0, size.x, offset), Color(0, 0, 0, alpha))
		draw_rect(Rect2(0.0, size.y - offset, size.x, offset), Color(0, 0, 0, alpha))
		draw_rect(Rect2(0.0, 0.0, offset, size.y), Color(0, 0, 0, alpha))
		draw_rect(Rect2(size.x - offset, 0.0, offset, size.y), Color(0, 0, 0, alpha))


func _draw_leaf_cluster(origin: Vector2, length: float, lean: float) -> void:
	var stem_end := origin + Vector2(length * 0.62, -length * 0.74)
	draw_line(origin, stem_end, Color(VINE.r, VINE.g, VINE.b, 0.08), 2.0, true)
	for i in 4:
		var t := 0.22 + i * 0.18
		var p := origin.lerp(stem_end, t)
		var side := -1.0 if i % 2 == 0 else 1.0
		var leaf_len := length * (0.16 - i * 0.018)
		var dir := Vector2(cos(lean + side * 0.85), sin(lean + side * 0.85))
		draw_colored_polygon(PackedVector2Array([
			p,
			p + dir * leaf_len + Vector2(0, -leaf_len * 0.35),
			p + dir * leaf_len * 0.7 + Vector2(0, -leaf_len * 0.75),
		]), Color(VINE.r, VINE.g, VINE.b, 0.05))


func _rand01(seed: int) -> float:
	var x := seed & 0x7fffffff
	x = (x ^ 61) ^ (x >> 16)
	x = x + (x << 3)
	x = x ^ (x >> 4)
	x = x * 0x27d4eb2d
	x = x ^ (x >> 15)
	return float(x & 0x7fffffff) / 2147483647.0
