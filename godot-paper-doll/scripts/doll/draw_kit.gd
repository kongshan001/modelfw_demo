class_name DrawKit
extends RefCounted

# 纸偶画笔：只使用 CanvasItem 的基础图元（圆/折线/多边形），
# 统一描边与圆角，保证所有槽位看起来是同一套纸木玩具。
#
# 性能：所有填充/描边在 PaperDollRenderer._draw 内先写进一个三角形缓冲，
# 最后用一次 canvas_item_add_triangle_array 提交。Intel 集显上这比每帧
# 提交数百条 draw_* 指令快一个数量级，外观顺序保持不变（按追加顺序绘制）。
#
# 视觉语言（T-20261120-008）：
#   L0 外轮廓  ow = 1.15 local（试衣镜 2.1× ≈ 2.4px）
#   L1 结构线  ow * 0.55（≈1.3px）
#   L2 细节线  0.4 local（≈0.8px）
#   缩略图 mini 只用 L0，并把线加粗到 2.3 local（2× 超采样后 ≈1.3px）。
# 色阶来自评审 §3 P0-1 的五档 ramp；木/布/皮/金/纸各有独立材质 ramp。

const INK := Color("#3a2f43")
const PAPER := Color("#f7eddc")
const WHITE := Color("#fffaf0")
const BLUSH := Color("#ef8e8a")
const GOLD := Color("#f2b34c")
const RIM_WARM := Color("#ffe0a8")
const RIM_COOL := Color("#a8d4dd")

const OUTER_STUDIO := 1.15
const OUTER_MINI := 2.30
const DETAIL_STUDIO := 0.40

# 评审给出的五档色阶 + 覆盖现有 8 组色板所需的邻近色系。
const RAMPS := {
	"teal": {"deep": "#2c5f50", "shade": "#3c8270", "base": "#4fa58a", "light": "#86c4b3", "hi": "#c9e5dc"},
	"coral": {"deep": "#8f3030", "shade": "#bd4b45", "base": "#e86a5c", "light": "#f4a196", "hi": "#ffd8cf"},
	"mustard": {"deep": "#8f5f1f", "shade": "#c98a2f", "base": "#f2b34c", "light": "#f8d391", "hi": "#fff0cd"},
	"blue": {"deep": "#2c4268", "shade": "#43628f", "base": "#5a7fb8", "light": "#9bb6db", "hi": "#dbe6f5"},
	"plum": {"deep": "#46356a", "shade": "#67518c", "base": "#8a6fb0", "light": "#b8a4d4", "hi": "#e6dcf2"},
	"wood": {"deep": "#7e5638", "shade": "#b07a4a", "base": "#d9a86c", "light": "#efcf9f", "hi": "#fff0d6"},
	"leather": {"deep": "#4f3020", "shade": "#6b432b", "base": "#8a5a3a", "light": "#b9855c", "hi": "#e0bd97"},
	"metal": {"deep": "#5e6670", "shade": "#7d8794", "base": "#b9c0c8", "light": "#e0e6ec", "hi": "#fffaf0"},
	"paper": {"deep": "#c9b394", "shade": "#ddc7a5", "base": "#f3e7d4", "light": "#fff9ee", "hi": "#fffdf7"},
	"pink": {"deep": "#8f4a62", "shade": "#c87391", "base": "#e88fae", "light": "#f5bdd0", "hi": "#ffe6ef"},
	"sky": {"deep": "#2f5c85", "shade": "#4b82b3", "base": "#6fa8d8", "light": "#a8cfec", "hi": "#e1f1fb"},
	"leaf": {"deep": "#4f7a34", "shade": "#71a34c", "base": "#9ad17c", "light": "#c3e6ae", "hi": "#eaf7df"},
	"navy": {"deep": "#232b36", "shade": "#323d4b", "base": "#45505e", "light": "#6d7b8d", "hi": "#aeb8c4"},
	"rust": {"deep": "#7a2f2f", "shade": "#a44747", "base": "#c95f5f", "light": "#e59a94", "hi": "#f8d4cd"},
	"taupe": {"deep": "#463d31", "shade": "#5f5445", "base": "#7c6a58", "light": "#a49482", "hi": "#d4c8b8"},
}

static var _batch_item: RID = RID()
static var _batch_pts := PackedVector2Array()
static var _batch_cols := PackedColorArray()
static var _batch_idx := PackedInt32Array()
static var _batch_offset := Vector2.ZERO
static var _batch_alpha := 1.0
static var _batch_xscale := 1.0
static var _silhouette := false
# mini 缩略图：几何预算收紧（不补圆头、圆段数减半），线宽/细节裁剪由 PaintUtil 负责。
static var _mini := false
# 色板只由 primary 决定；缓存后每只纸偶的 17 次取色不再重复构建 ramp。
static var _palette_cache: Dictionary = {}


static func make_palette(primary: Color) -> Dictionary:
	var key := primary.to_html(false)
	var cached: Dictionary = _palette_cache.get(key, {})
	if not cached.is_empty():
		return cached
	var ramp := ramp_for(primary)
	var wood := material("wood")
	var leather := material("leather")
	var metal := material("metal")
	var paper := material("paper")
	var pal := {
		"primary": ramp["base"],
		"base": ramp["base"],
		"shade": ramp["shade"],
		"deep": ramp["deep"],
		"light": ramp["light"],
		"highlight": ramp["hi"],
		"paper": PAPER,
		"paper_ramp": paper,
		"ink": INK,
		"white": WHITE,
		"blush": BLUSH,
		"accent": GOLD,
		"gold": material("mustard"),
		"wood": wood,
		"leather": leather,
		"metal": metal,
		"rim": RIM_WARM,
		"rim_cool": RIM_COOL,
	}
	_palette_cache[key] = pal
	return pal


static func ramp_for(primary: Color) -> Dictionary:
	var best := ""
	var best_dist := 1.0e9
	for key in RAMPS.keys():
		var base := Color(RAMPS[key]["base"])
		var dist := _rgb_dist(primary, base)
		if dist < best_dist:
			best_dist = dist
			best = key
	if best_dist <= 0.085:
		return _ramp_dict(best)
	return _derived_ramp(primary)


static func material(key: String) -> Dictionary:
	return _ramp_dict(key)


static func _ramp_dict(key: String) -> Dictionary:
	var raw: Dictionary = RAMPS[key]
	return {
		"deep": Color(raw["deep"]), "shade": Color(raw["shade"]), "base": Color(raw["base"]),
		"light": Color(raw["light"]), "hi": Color(raw["hi"]),
	}


static func _derived_ramp(primary: Color) -> Dictionary:
	var h := primary.h
	var s := primary.s
	var v := primary.v
	return {
		"deep": Color.from_hsv(h, minf(s * 1.05, 1.0), maxf(v * 0.52, 0.0)).lerp(INK, 0.10),
		"shade": Color.from_hsv(h, minf(s * 1.02, 1.0), maxf(v * 0.74, 0.0)),
		"base": primary,
		"light": Color.from_hsv(h, maxf(s * 0.78, 0.0), minf(v + (1.0 - v) * 0.32, 1.0)),
		"hi": Color.from_hsv(h, maxf(s * 0.42, 0.0), minf(v + (1.0 - v) * 0.72, 1.0)).lerp(WHITE, 0.24),
	}


static func _rgb_dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


static func far(palette: Dictionary) -> Color:
	var shade: Color = palette["shade"]
	return shade.darkened(0.12).lerp(Color("#5a6478"), 0.16)


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
	_batch_offset = Vector2.ZERO
	_batch_alpha = 1.0
	_batch_xscale = 1.0
	_silhouette = false
	_mini = false


static func set_mini(value: bool) -> void:
	_mini = value


static func set_offset(offset: Vector2) -> void:
	_batch_offset = offset


static func set_alpha(value: float) -> void:
	_batch_alpha = value


static func set_xscale(value: float) -> void:
	# 8 向侧身收窄：纸质侧视时整体 x 压缩（仅渲染，不改骨骼数据）。
	_batch_xscale = clampf(value, 0.45, 1.0)


static func set_silhouette(value: bool) -> void:
	_silhouette = value


static func end_batch() -> void:
	if _batch_idx.size() > 0:
		RenderingServer.canvas_item_add_triangle_array(
				_batch_item, _batch_idx, _batch_pts, _batch_cols)
	_batch_pts.clear()
	_batch_cols.clear()
	_batch_idx.clear()
	_batch_item = RID()


static func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	var out := color
	if _silhouette:
		out = Color(0.02, 0.02, 0.02, 1.0)
	else:
		out.a *= _batch_alpha
	var base := _batch_pts.size()
	var sx := _batch_xscale
	_batch_pts.append(Vector2((a.x + _batch_offset.x) * sx, a.y + _batch_offset.y))
	_batch_pts.append(Vector2((b.x + _batch_offset.x) * sx, b.y + _batch_offset.y))
	_batch_pts.append(Vector2((c.x + _batch_offset.x) * sx, c.y + _batch_offset.y))
	_batch_cols.append(out)
	_batch_cols.append(out)
	_batch_cols.append(out)
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
	var n := segments if segments > 0 else clampi(int(radius * 2.0), 10, 18 if _mini else 28)
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
	var n := segments if segments > 0 else clampi(int(outer * 2.0), 12, 20 if _mini else 30)
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
	# mini 缩略图在 2× 超采样后再缩小，折角圆头 <1px，直接省略。
	if half >= 0.55 and not _mini:
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

# outline 参数 = 实际线宽（local），不再 ×2。L0 传 ow(ctx)，L1 传 ow*0.55，
# 内层填充型部件传 0。所有默认值按 L0 处理，避免旧调用出现双黑边。
static func circle(ci: CanvasItem, pos: Vector2, radius: float, fill: Color, ink := INK, outline := OUTER_STUDIO) -> void:
	_disc(pos, radius, fill)
	if outline > 0.0:
		_ring(pos, radius, outline, ink)


static func ellipse(ci: CanvasItem, pos: Vector2, radii: Vector2, rot: float, fill: Color, ink := INK, outline := OUTER_STUDIO, segments := 32) -> void:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(pos + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	_fill(points, fill, true)
	if outline > 0.0:
		_stroke(points, ink, outline, true)


static func rrect(ci: CanvasItem, pos: Vector2, size: Vector2, radius: float, rot: float, fill: Color, ink := INK, outline := OUTER_STUDIO) -> void:
	var points := rrect_points(pos, size, radius, rot)
	_fill(points, fill, true)
	if outline > 0.0:
		_stroke(points, ink, outline, true)


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


static func polygon(ci: CanvasItem, points: PackedVector2Array, fill: Color, ink := INK, outline := OUTER_STUDIO) -> void:
	if points.size() < 3:
		return
	_fill(points, fill)
	if outline > 0.0:
		_stroke(points, ink, outline, true)


static func poly_at(ci: CanvasItem, center: Vector2, points: Array, rot: float, fill: Color, ink := INK, outline := OUTER_STUDIO) -> void:
	var packed := PackedVector2Array()
	for point in points:
		packed.append(center + (point as Vector2).rotated(rot))
	polygon(ci, packed, fill, ink, outline)


static func line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width := 1.15, aa := true) -> void:
	var d := b - a
	if d.length_squared() < 0.0001 or width <= 0.01:
		return
	var normal := Vector2(-d.y, d.x).normalized() * (width * 0.5)
	_quad(a + normal, b + normal, b - normal, a - normal, color)


static func polyline(ci: CanvasItem, points: PackedVector2Array, color: Color, width := 1.15, closed := false, aa := true) -> void:
	_stroke(points, color, width, closed)


static func capsule(ci: CanvasItem, a: Vector2, b: Vector2, width: float, fill: Color, ink := INK, outline := OUTER_STUDIO) -> void:
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
		_stroke(points, ink, outline, true)


static func arc(ci: CanvasItem, center: Vector2, radius: float, from: float, to: float, color: Color, width := 1.15) -> void:
	var span := to - from
	var steps := clampi(int(absf(span) * radius * 0.4), 6, 18 if _mini else 32)
	var points := PackedVector2Array()
	for i in range(steps + 1):
		var a := from + span * float(i) / float(steps)
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	_stroke(points, color, width, false)


static func star(ci: CanvasItem, center: Vector2, radius: float, points: int, fill: Color, ink := INK, outline := 0.8, inner := 0.44, rot := 0.0) -> void:
	var poly := PackedVector2Array()
	for i in points * 2:
		var a := rot - PI * 0.5 + PI * float(i) / float(points)
		var r := radius if i % 2 == 0 else radius * inner
		poly.append(center + Vector2(cos(a), sin(a)) * r)
	polygon(ci, poly, fill, ink, outline)


static func diamond(ci: CanvasItem, center: Vector2, size: Vector2, fill: Color, ink := INK, outline := 0.8) -> void:
	poly_at(ci, center, [
		Vector2(0, -size.y * 0.5), Vector2(size.x * 0.5, 0),
		Vector2(0, size.y * 0.5), Vector2(-size.x * 0.5, 0),
	], 0.0, fill, ink, outline)


static func ring(ci: CanvasItem, center: Vector2, radius: float, width: float, color: Color) -> void:
	_ring(center, radius, width, color)


# ------------------------------------------------------------------ 纸艺 / 光

static func contact_shadow(ci: CanvasItem, center: Vector2, scale_y := 1.0) -> void:
	# 环境影 223×34 + 接触影 168×32（1280 口径，@2.1× 试衣镜）；
	# 两层同心椭圆近似 blur 8，整体下移 2px；不绕角色一圈（避免外发光）。
	ci.draw_set_transform(center + Vector2(0, 1.0), 0.0, Vector2(1.0, 0.16 * scale_y))
	for i in 3:
		var r := 53.0 - float(i) * 6.0
		ci.draw_circle(Vector2.ZERO, r, Color(0.27, 0.20, 0.15, 0.030), true, -1.0, true)
	ci.draw_set_transform(center + Vector2(0, 1.0), 0.0, Vector2(1.0, 0.17 * scale_y))
	for i in 3:
		var r := 40.0 - float(i) * 6.0
		ci.draw_circle(Vector2.ZERO, r, Color(0.27, 0.20, 0.15, 0.105), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func layer_shadow(ci: CanvasItem, points: PackedVector2Array, alpha := 0.13) -> void:
	# 剪纸层影：只压在下一层上，偏移 (1.7, 2.7) local；不绕整圈。
	if points.size() < 3:
		return
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + Vector2(1.7, 2.7))
	_fill(shifted, Color(0.22, 0.16, 0.18, alpha))


static func layer_shadow_circle(ci: CanvasItem, center: Vector2, radius: float, alpha := 0.12) -> void:
	layer_shadow(ci, _ellipse_points(center, Vector2(radius, radius), 0.0, 24), alpha)


static func paper_fibers(ci: CanvasItem, center: Vector2, size: Vector2, seed_value: int, color: Color) -> void:
	# 4% 纸纤维：几根 1–3px 短线，只在 ≥3px 显示尺寸的 Studio 模式绘制。
	if size.x < 8.0 or size.y < 8.0:
		return
	var sx := float(seed_value % 97) * 0.13
	for i in 5:
		var fx := center.x + sin(sx + float(i) * 2.7) * size.x * 0.32
		var fy := center.y + cos(sx * 1.3 + float(i) * 1.9) * size.y * 0.28
		var dx := 1.4 + float(i % 3) * 0.9
		line(ci, Vector2(fx, fy), Vector2(fx + dx, fy - dx * 0.4), color, 0.32)


static func _ellipse_points(pos: Vector2, radii: Vector2, rot: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		points.append(pos + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	return points


static func shadow(ci: CanvasItem, center: Vector2, radii: Vector2, value := 0.18) -> void:
	# 兼容旧调用：单层椭圆（新代码请用 contact_shadow）。
	ci.draw_set_transform(center, 0.0, Vector2(1.0, radii.y / maxf(radii.x, 0.001)))
	ci.draw_circle(Vector2.ZERO, radii.x, Color(0.23, 0.18, 0.26, value), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
