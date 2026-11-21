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
# 主光 45° 左上 5600K；轮廓光 2px α0.5 6500K；环境反弹 8–12% 暖纸面。
const KEY_LIGHT := Color("#ffefd6")
const RIM_6500 := Color("#b7d7e8")
const RIM_BOUNCE := Color("#8fb8d0")
const BOUNCE_WARM := Color("#ffd9b0")
const RIM_WARM := RIM_6500
const RIM_COOL := RIM_BOUNCE

const OUTER_STUDIO := 0.98
const OUTER_MINI := 2.30
const DETAIL_STUDIO := 0.40

# 七档命名色阶（G1）：deep / shade / base / light / hi / reflect / sss。
# 每个材质从 base 程序化派生 7 档；阴影色相向冷侧 +15°~+20°（布/纸/蓝/金属），
# 暖材质（木/皮/金/锈）向红紫 −10°~−12°。base 色本身是受光中间调。
const RAMP_SPECS := {
	"teal": {"base": "#4fa58a", "shift": 20.0},
	"coral": {"base": "#e86a5c", "shift": -12.0},
	"mustard": {"base": "#f2b34c", "shift": -12.0},
	"blue": {"base": "#5a7fb8", "shift": 18.0},
	"plum": {"base": "#8a6fb0", "shift": 17.0},
	"wood": {"base": "#d9a86c", "shift": -12.0},
	"leather": {"base": "#8a5a3a", "shift": -12.0},
	"metal": {"base": "#b9c0c8", "shift": 20.0},
	"paper": {"base": "#f3e7d4", "shift": 14.0},
	"pink": {"base": "#e88fae", "shift": -10.0},
	"sky": {"base": "#6fa8d8", "shift": 18.0},
	"leaf": {"base": "#9ad17c", "shift": 20.0},
	"navy": {"base": "#45505e", "shift": 18.0},
	"rust": {"base": "#c95f5f", "shift": -12.0},
	"taupe": {"base": "#7c6a58", "shift": -10.0},
	"skin": {"base": "#e8bb91", "shift": 14.0},
	"hair": {"base": "#7a5236", "shift": 16.0},
}
const TONE_ORDER := ["deep", "shade", "base", "light", "hi"]

static var _batch_item: RID = RID()
static var _batch_pts := PackedVector2Array()
static var _batch_cols := PackedColorArray()
static var _batch_idx := PackedInt32Array()
static var _batch_offset := Vector2.ZERO
static var _batch_alpha := 1.0
static var _batch_xscale := 1.0
static var _silhouette := false
# 命中/斩击的屏幕轻震 2–3px（local 1.2 @2.1× ≈ 2.5px），由 PaperDollRenderer 注入。
static var _shake := Vector2.ZERO
# mini 缩略图：几何预算收紧（不补圆头、圆段数减半），线宽/细节裁剪由 PaintUtil 负责。
static var _mini := false
# 色板只由 primary 决定；缓存后每只纸偶的 17 次取色不再重复构建 ramp。
static var _palette_cache: Dictionary = {}
static var _ramp_cache: Dictionary = {}


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
		"hi": ramp["hi"],
		"reflect": ramp["reflect"],
		"sss": ramp["sss"],
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
		"skin": material("skin"),
		"hair": material("hair"),
		"key": KEY_LIGHT,
		"bounce": BOUNCE_WARM,
		"rim": RIM_6500,
		"rim_cool": RIM_BOUNCE,
	}
	_palette_cache[key] = pal
	return pal


static func ramp_for(primary: Color) -> Dictionary:
	var best := ""
	var best_dist := 1.0e9
	for key in RAMP_SPECS.keys():
		var base := Color(RAMP_SPECS[key]["base"])
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
	var cached: Dictionary = _ramp_cache.get(key, {})
	if not cached.is_empty():
		return cached
	var spec: Dictionary = RAMP_SPECS[key]
	var built := _build_ramp(Color(spec["base"]), float(spec["shift"]))
	_ramp_cache[key] = built
	return built


static func _build_ramp(base: Color, shift_deg: float) -> Dictionary:
	# 暗部色相偏移：shade 偏 0.65×、deep 偏满；明度不低于 base−≈25 L*。
	var h := base.h
	var s := base.s
	var v := base.v
	var sh := shift_deg / 360.0
	var shade := Color.from_hsv(fposmod(h + sh * 0.85, 1.0),
			minf(s * 1.06 + 0.02, 1.0), clampf(v * 0.76, 0.0, 1.0))
	var deep := Color.from_hsv(fposmod(h + sh, 1.0),
			minf(s * 1.12 + 0.03, 1.0), clampf(v * 0.64, 0.0, 1.0))
	var light := Color.from_hsv(fposmod(h - sh * 0.20, 1.0),
			maxf(s * 0.82, 0.0), minf(v + (1.0 - v) * 0.34, 1.0))
	var hi := Color.from_hsv(fposmod(h - sh * 0.32, 1.0),
			maxf(s * 0.42, 0.0), minf(v + (1.0 - v) * 0.74, 1.0))
	# 环境反射：冷影材质反射 6500K 天光，暖材质反射纸面暖反弹。
	var reflect := shade.lerp(RIM_6500, 0.22)
	if shift_deg < 0.0:
		reflect = shade.lerp(BOUNCE_WARM, 0.18)
	# 8–10% 红润 SSS（皮肤/木偶头/耳/手）；放在色阶里，paint 层按 α 使用。
	var sss := base.lerp(Color("#e8836f"), 0.40)
	return {
		"deep": deep, "shade": shade, "base": base,
		"light": light, "hi": hi, "reflect": reflect, "sss": sss,
	}


static func _derived_ramp(primary: Color) -> Dictionary:
	# 未命中命名色板时的兜底色：冷色相 +16°，暖色相 −12°。
	var warm := primary.h < 0.10 or primary.h > 0.90 or (primary.h > 0.02 and primary.h < 0.16)
	var shift := -12.0 if warm else 16.0
	return _build_ramp(primary, shift)


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
	_shake = Vector2.ZERO


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


static func set_shake(offset: Vector2) -> void:
	_shake = offset


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
	var ox := _batch_offset.x + _shake.x
	var oy := _batch_offset.y + _shake.y
	_batch_pts.append(Vector2((a.x + ox) * sx, a.y + oy))
	_batch_pts.append(Vector2((b.x + ox) * sx, b.y + oy))
	_batch_pts.append(Vector2((c.x + ox) * sx, c.y + oy))
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


# ------------------------------------------------------------------ 七档材质色阶（G1）

static func tone(ramp: Dictionary, index: int) -> Color:
	var key: String = TONE_ORDER[clampi(index, 0, TONE_ORDER.size() - 1)]
	if ramp.has(key):
		return ramp[key]
	if key == "hi" and ramp.has("highlight"):
		return ramp["highlight"]
	return ramp["base"]


# 胶囊肢体/躯干的 5 档色阶：外深内浅、逐层向 45° 左上收窄。
# 每档先画 0.5α 羽化边再压实色 → 1× 下 2–3px 软过渡，不出现硬色块。
static func capsule_tones(ci: CanvasItem, a: Vector2, b: Vector2, width: float, ramp: Dictionary,
		bands := 5, inset := 1.35, ink := INK, outline := 0.0) -> void:
	if width < 2.0:
		return
	if _mini:
		# 95px 卡片：7 档在 1× 以下不可见，直接平面 + 1 道受光边，守住烘焙预算。
		capsule(ci, a, b, width, tone(ramp, 1 if float((ramp["base"] as Color).v) < 0.46 else 0), ink, outline)
		return
	bands = clampi(bands, 2, 5)
	var unit := Vector2(-1.0, -0.78).normalized()
	var weight := [1.0, 1.0, 0.9, 0.78, 0.58]
	inset = clampf(inset, 0.6, width * 0.16)
	# 深色布（navy 等）跳过 deep：避免整块变成“墨色族”，也避免黑块。
	var start := 1 if float((ramp["base"] as Color).v) < 0.46 else 0
	bands = mini(bands, 5 - start)
	capsule(ci, a, b, width, tone(ramp, start), ink, outline)
	for i in range(1, bands):
		var w := width - float(i) * inset * 2.0
		if w < 1.2:
			break
		var off := unit * (float(i) * 0.55)
		var col := tone(ramp, start + i)
		var k: float = weight[mini(i, weight.size() - 1)]
		capsule(ci, a + off, b + off, w, alpha(col, k), Color.WHITE, 0.0)


# 椭圆（头/帽/包/肩甲）的 5 档色阶。
static func ellipse_tones(ci: CanvasItem, pos: Vector2, radii: Vector2, rot: float, ramp: Dictionary,
		bands := 5, inset := 1.25, ink := INK, outline := 0.0, segments := 32, start_tone := 0) -> void:
	if _mini:
		ellipse(ci, pos, radii, rot, tone(ramp, start_tone), ink, outline, segments)
		return
	bands = clampi(bands, 2, 5)
	var unit := Vector2(-0.82, -0.72).normalized()
	var weight := [1.0, 1.0, 0.92, 0.80, 0.58]
	inset = clampf(inset, 0.5, minf(radii.x, radii.y) * 0.18)
	ellipse(ci, pos, radii, rot, tone(ramp, start_tone), ink, outline, segments)
	for i in range(1, bands):
		var r := radii - Vector2(inset, inset) * float(i)
		if r.x < 1.0 or r.y < 1.0:
			break
		var off := unit * (float(i) * 0.5)
		var col := tone(ramp, start_tone + i)
		var k: float = weight[mini(i, weight.size() - 1)]
		ellipse(ci, pos + off, r, rot, alpha(col, k), Color.WHITE, 0.0, segments)


# 多边形（披风/裙/护甲板）的 4 档色阶：用 Geometry2D 内缩生成同形状的窄带。
# 只在 Studio 绘制；失败时退回平面色阶，不阻塞换装。
static func polygon_tones(ci: CanvasItem, points: PackedVector2Array, ramp: Dictionary,
		bands := 4, inset := 2.2, ink := INK, outline := 0.0) -> void:
	if points.size() < 3:
		return
	if _mini:
		polygon(ci, points, tone(ramp, 0), ink, outline)
		return
	bands = clampi(bands, 2, 5)
	var unit := Vector2(-0.82, -0.72).normalized()
	var weight := [1.0, 1.0, 0.92, 0.78, 0.58]
	var start := 1 if float((ramp["base"] as Color).v) < 0.46 else 0
	bands = mini(bands, 5 - start)
	polygon(ci, points, tone(ramp, start), ink, outline)
	for i in range(1, bands):
		var polys := Geometry2D.offset_polygon(points, -inset * float(i))
		if polys.is_empty():
			break
		var col := tone(ramp, start + i)
		var k: float = weight[mini(i, weight.size() - 1)]
		var off := unit * (float(i) * 0.6)
		for poly in polys:
			if poly.size() < 3:
				continue
			var shifted := PackedVector2Array()
			for p in poly:
				shifted.append(p + off)
			_fill(shifted, alpha(col, k), false)


static func ao_ellipse(ci: CanvasItem, pos: Vector2, radii: Vector2, rot := 0.0, strength := 0.12) -> void:
	# 12% AO：下巴/下摆/层叠处的接触暗部；不绕整圈。
	ellipse(ci, pos, radii, rot, Color(0.15, 0.19, 0.25, strength), Color.WHITE, 0.0, 24)


static func rim_stroke(ci: CanvasItem, a: Vector2, b: Vector2, alpha := 0.5, width := 0.95) -> void:
	# 轮廓光：2px @2.1×、α0.5、6500K。
	line(ci, a, b, alpha(RIM_6500, alpha), width)


static func bounce_stroke(ci: CanvasItem, a: Vector2, b: Vector2, alpha := 0.10) -> void:
	# 环境反弹：纸面暖色 8–12%。
	line(ci, a, b, alpha(BOUNCE_WARM, alpha), 0.9)


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

static func contact_shadow(ci: CanvasItem, center: Vector2, scale_y := 1.0, shake := Vector2.ZERO) -> void:
	# 双层接触影（G5）：半影 223×34（α≈0.06）+ 本影 150×28（α≈0.16）。
	# 主光来自 45° 左上，影子整体向右下偏移 2.2px；不绕角色一圈（避免外发光）。
	var base := center + shake + Vector2(2.2, 1.2)
	ci.draw_set_transform(base, 0.0, Vector2(1.0, 0.155 * scale_y))
	for i in 3:
		var r := 53.0 - float(i) * 7.0
		ci.draw_circle(Vector2.ZERO, r, Color(0.27, 0.20, 0.15, 0.022), true, -1.0, true)
	ci.draw_set_transform(base + Vector2(0, 0.4), 0.0, Vector2(1.0, 0.17 * scale_y))
	for i in 3:
		var r := 35.0 - float(i) * 5.0
		ci.draw_circle(Vector2.ZERO, r, Color(0.24, 0.17, 0.13, 0.055), true, -1.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func layer_shadow(ci: CanvasItem, points: PackedVector2Array, alpha := 0.13) -> void:
	# 剪纸层影：只压在下一层上，偏移 (1.7, 2.7) local；不绕整圈。
	if points.size() < 3:
		return
	var shifted := PackedVector2Array()
	for p in points:
		shifted.append(p + Vector2(1.7, 2.7))
	_fill(shifted, Color(0.14, 0.18, 0.24, alpha))


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
