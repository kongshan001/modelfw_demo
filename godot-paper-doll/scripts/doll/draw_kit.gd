class_name DrawKit
extends RefCounted

# 纸偶画笔：只使用 CanvasItem 的基础图元（圆/折线/多边形），
# 统一描边与圆角，保证所有槽位看起来是同一套纸木玩具。
#
# 性能：所有填充/描边在 PaperDollRenderer._draw 内先写进一个三角形缓冲，
# 最后用一次 canvas_item_add_triangle_array 提交。Intel 集显上这比每帧
# 提交数百条 draw_* 指令快一个数量级，外观顺序保持不变（按追加顺序绘制）。

const INK := Color("#3a2f43")
const PAPER := Color("#f7eddc")
const WHITE := Color("#fffaf0")
const BLUSH := Color("#ef8e8a")
const GOLD := Color("#f2b34c")

static var _batch_item: RID = RID()
static var _batch_pts := PackedVector2Array()
static var _batch_cols := PackedColorArray()
static var _batch_idx := PackedInt32Array()


static func make_palette(primary: Color) -> Dictionary:
	return {
		"primary": primary,
		"shade": primary.darkened(0.24),
		"deep": primary.darkened(0.42),
		"light": primary.lightened(0.34),
		"paper": PAPER,
		"ink": INK,
		"white": WHITE,
		"blush": BLUSH,
		"accent": GOLD,
	}


static func far(palette: Dictionary) -> Color:
	return (palette["primary"] as Color).darkened(0.30).lerp(INK, 0.10)


static func alpha(color: Color, value: float) -> Color:
	var out := color
	out.a = value
	return out


# ------------------------------------------------------------------ 批次

static func begin_batch(ci: CanvasItem) -> void:
	_batch_item = ci.get_canvas_item()
	_batch_pts.clear()
	_batch_cols.clear()
	_batch_idx.clear()


static func end_batch() -> void:
	if _batch_idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(
				_batch_item, _batch_idx, _batch_pts, _batch_cols)
	_batch_pts.clear()
	_batch_cols.clear()
	_batch_idx.clear()
	_batch_item = RID()


static func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var base := _batch_pts.size()
	_batch_pts.append(a)
	_batch_pts.append(b)
	_batch_pts.append(c)
	_batch_cols.append(color)
	_batch_cols.append(color)
	_batch_cols.append(color)
	_batch_idx.append(base)
	_batch_idx.append(base + 1)
	_batch_idx.append(base + 2)


static func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	_tri(a, b, c, color)
	_tri(a, c, d, color)


static func _fan(points: PackedVector2Array, color: Color, center := Vector2.INF) -> void:
	var n := points.size()
	if n < 2:
		return
	if center == Vector2.INF:
		center = Vector2.ZERO
		for p in points:
			center += p
		center /= float(n)
	for i in n:
		_tri(center, points[i], points[(i + 1) % n], color)


static func _fill(points: PackedVector2Array, color: Color, convex := false) -> void:
	if points.size() < 3:
		return
	if convex:
		_fan(points, color)
		return
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		_fan(points, color)
		return
	for i in range(0, indices.size(), 3):
		_tri(points[indices[i]], points[indices[i + 1]], points[indices[i + 2]], color)


static func _disc(center: Vector2, radius: float, color: Color, segments := 0) -> void:
	if radius <= 0.01:
		return
	var n := segments if segments > 0 else clampi(int(radius * 2.0), 10, 28)
	var prev := center + Vector2(radius, 0)
	for i in range(1, n + 1):
		var a := TAU * float(i) / float(n)
		var cur := center + Vector2(cos(a), sin(a)) * radius
		_tri(center, prev, cur, color)
		prev = cur


static func _ring(center: Vector2, radius: float, width: float, color: Color, segments := 0) -> void:
	if width <= 0.01 or radius <= 0.01:
		return
	var outer := radius + width * 0.5
	var inner := maxf(radius - width * 0.5, 0.05)
	var n := segments if segments > 0 else clampi(int(outer * 2.0), 12, 30)
	var prev_o := center + Vector2(outer, 0)
	var prev_i := center + Vector2(inner, 0)
	for i in range(1, n + 1):
		var a := TAU * float(i) / float(n)
		var dir := Vector2(cos(a), sin(a))
		var cur_o := center + dir * outer
		var cur_i := center + dir * inner
		_quad(prev_o, cur_o, cur_i, prev_i, color)
		prev_o = cur_o
		prev_i = cur_i


static func _stroke(points: PackedVector2Array, color: Color, width: float, closed := false) -> void:
	if width <= 0.01 or points.size() < 2:
		return
	var half := width * 0.5
	var n := points.size()
	var segs := n if closed else n - 1
	for i in segs:
		var a := points[i]
		var b := points[(i + 1) % n]
		var d := b - a
		if d.length_squared() < 0.0001:
			continue
		var normal := Vector2(-d.y, d.x).normalized() * half
		_quad(a + normal, b + normal, b - normal, a - normal, color)
	# 只在明显折角处补圆头；平滑曲线（胶囊/圆角矩形）跳过以压低顶点数。
	if half >= 0.8:
		var last := n if closed else n - 1
		for i in range(1, last):
			var prev := points[i - 1]
			var cur := points[i]
			var nxt := points[(i + 1) % n]
			var d1 := (cur - prev).normalized()
			var d2 := (nxt - cur).normalized()
			if d1.dot(d2) < 0.96:
				_disc(cur, half, color, 5)


# ------------------------------------------------------------------ 图元

static func circle(ci: CanvasItem, pos: Vector2, radius: float, fill: Color, ink := INK, outline := 1.6) -> void:
	_disc(pos, radius, fill)
	if outline > 0.0:
		_ring(pos, radius, outline * 2.0, ink)


static func ellipse(ci: CanvasItem, pos: Vector2, radii: Vector2, rot: float, fill: Color, ink := INK, outline := 1.6, segments := 32) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(pos + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	_fill(points, fill, true)
	if outline > 0.0:
		_stroke(points, ink, outline * 2.0, true)


static func rrect(ci: CanvasItem, pos: Vector2, size: Vector2, radius: float, rot: float, fill: Color, ink := INK, outline := 1.6) -> void:
	var points := rrect_points(pos, size, radius, rot)
	_fill(points, fill, true)
	if outline > 0.0:
		_stroke(points, ink, outline * 2.0, true)


static func rrect_points(pos: Vector2, size: Vector2, radius: float, rot := 0.0) -> PackedVector2Array:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var r := minf(radius, minf(hx, hy))
	var points := PackedVector2Array()
	if r <= 0.5:
		for corner in [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]:
			points.append(pos + corner.rotated(rot))
		return points
	var centers := [
		Vector2(hx - r, -hy + r),
		Vector2(hx - r, hy - r),
		Vector2(-hx + r, hy - r),
		Vector2(-hx + r, -hy + r),
	]
	var starts := [-PI * 0.5, 0.0, PI * 0.5, PI]
	for c in centers.size():
		for i in 7:
			var a: float = starts[c] + PI * 0.5 * float(i) / 6.0
			points.append(pos + (centers[c] + Vector2(cos(a), sin(a)) * r).rotated(rot))
	return points


static func polygon(ci: CanvasItem, points: PackedVector2Array, fill: Color, ink := INK, outline := 1.6) -> void:
	if points.size() < 3:
		return
	_fill(points, fill)
	if outline > 0.0:
		_stroke(points, ink, outline * 2.0, true)


static func poly_at(ci: CanvasItem, center: Vector2, points: Array, rot: float, fill: Color, ink := INK, outline := 1.6) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(center + (point as Vector2).rotated(rot))
	polygon(ci, packed, fill, ink, outline)


static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 1.6, aa := true) -> void:
	var d := b - a
	if d.length_squared() < 0.0001 or width <= 0.01:
		return
	var normal := Vector2(-d.y, d.x).normalized() * (width * 0.5)
	_quad(a + normal, b + normal, b - normal, a - normal, color)


static func polyline(ci: CanvasItem, points: PackedVector2Array, color: Color, width := 1.6, closed := false, aa := true) -> void:
	_stroke(points, color, width, closed)


static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, width: float, fill: Color, ink := INK, outline := 1.6) -> void:
	var r := width * 0.5
	var d := b - a
	if d.length_squared() < 0.0001:
		circle(ci, a, r, fill, ink, outline)
		return
	var dir := d.normalized()
	var normal := Vector2(-dir.y, dir.x)
	var points := PackedVector2Array()
	for i in range(1, 9):
		var ang := PI * float(i) / 8.0
		points.append(b + (normal * cos(ang) + dir * sin(ang)) * r)
	for i in range(1, 9):
		var ang := PI + PI * float(i) / 8.0
		points.append(a + (normal * cos(ang) + dir * sin(ang)) * r)
	_fill(points, fill, true)
	if outline > 0.0:
		_stroke(points, ink, outline * 2.0, true)


static func arc(ci: CanvasItem, center: Vector2, radius: float, from: float, to: float, color: Color, width := 1.6) -> void:
	var span := to - from
	var steps := clampi(int(absf(span) * radius * 0.4), 6, 32)
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var a := from + span * float(i) / float(steps)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	_stroke(points, color, width, false)


static func star(ci: CanvasItem, center: Vector2, radius: float, points: int, fill: Color, ink := INK, outline := 1.2, inner := 0.44, rot := 0.0) -> void:
	var poly := PackedVector2Array()
	for i in points * 2:
		var a := rot - PI * 0.5 + PI * float(i) / float(points)
		var r := radius if i % 2 == 0 else radius * inner
		poly.append(center + Vector2(cos(a), sin(a)) * r)
	polygon(ci, poly, fill, ink, outline)


static func diamond(ci: CanvasItem, center: Vector2, size: Vector2, fill: Color, ink := INK, outline := 1.2) -> void:
	poly_at(ci, center, [
		Vector2(0, -size.y * 0.5), Vector2(size.x * 0.5, 0),
		Vector2(0, size.y * 0.5), Vector2(-size.x * 0.5, 0),
	], 0.0, fill, ink, outline)


static func ring(ci: CanvasItem, center: Vector2, radius: float, width: float, color: Color) -> void:
	_ring(center, radius, width, color)


static func shadow(ci: CanvasItem, center: Vector2, radii: Vector2, value := 0.18) -> void:
	# 阴影在所有部件之前单独绘制（带变换），不进入三角形批次。
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radii.y / maxf(radii.x, 0.001)))
	ci.draw_circle(Vector2.ZERO, radii.x, Color(0.23, 0.18, 0.26, value), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
