class_name PixelArt
extends RefCounted

# 全部像素图在运行时程序化生成，没有任何外部图像素材（字体除外）。
# 配色是原创的「苔绿 + 陶土 + 暖灯」；所有造型都按固定机位 3/4 俯视绘制。
# height 图不在这里生成：World 根据每张图的 alpha 与底边位置写入 R8 高度图。

const INK := Color8(24, 28, 38)
const INK_SOFT := Color8(38, 44, 56)
const GRASS_DEEP := Color8(36, 62, 50)
const GRASS_DARK := Color8(48, 82, 60)
const GRASS := Color8(66, 106, 72)
const GRASS_MID := Color8(84, 126, 82)
const GRASS_LIGHT := Color8(108, 148, 92)
const GRASS_HI := Color8(140, 174, 108)
const DIRT_DARK := Color8(88, 65, 52)
const DIRT := Color8(116, 88, 68)
const DIRT_LIGHT := Color8(148, 116, 88)
const STONE_DARK := Color8(66, 70, 82)
const STONE := Color8(102, 106, 118)
const STONE_LIGHT := Color8(146, 148, 156)
const WOOD_DARK := Color8(56, 38, 32)
const WOOD := Color8(94, 62, 46)
const WOOD_LIGHT := Color8(134, 92, 62)
const PLASTER := Color8(198, 180, 146)
const PLASTER_SHADE := Color8(164, 144, 112)
const PLASTER_DARK := Color8(132, 112, 88)
const ROOF_DARK := Color8(88, 48, 48)
const ROOF := Color8(138, 68, 58)
const ROOF_LIGHT := Color8(180, 98, 72)
const ROOF_HI := Color8(208, 126, 86)
const LEAF_DEEP := Color8(30, 60, 50)
const LEAF_DARK := Color8(40, 82, 62)
const LEAF := Color8(58, 108, 74)
const LEAF_LIGHT := Color8(84, 140, 88)
const LEAF_HI := Color8(116, 166, 100)
const GOLD_DARK := Color8(118, 78, 44)
const GOLD := Color8(174, 124, 54)
const GOLD_LIGHT := Color8(214, 170, 78)
const PINE_DEEP := Color8(26, 54, 52)
const PINE_DARK := Color8(36, 72, 62)
const PINE := Color8(50, 96, 74)
const PINE_LIGHT := Color8(74, 124, 90)
const LANTERN_GLOW := Color8(255, 210, 116)
const LANTERN := Color8(236, 154, 66)
const LANTERN_DARK := Color8(170, 96, 44)
const SKY_GLOW := Color8(255, 232, 176)


static func _canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	return img


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		var d := img.get_pixel(x, y)
		var a := c.a
		var out_a := a + d.a * (1.0 - a)
		if out_a <= 0.0001:
			return
		var rgb := Color(
			(c.r * a + d.r * d.a * (1.0 - a)) / out_a,
			(c.g * a + d.g * d.a * (1.0 - a)) / out_a,
			(c.b * a + d.b * d.a * (1.0 - a)) / out_a,
			out_a)
		img.set_pixel(x, y, rgb)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _hline(img: Image, x: int, y: int, w: int, c: Color) -> void:
	_rect(img, x, y, w, 1, c)


static func _vline(img: Image, x: int, y: int, h: int, c: Color) -> void:
	_rect(img, x, y, 1, h, c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_px(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float,
		c: Color) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx) / maxf(rx, 0.001)
			var dy := (float(y) + 0.5 - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, c)


static func _ellipse_dither(img: Image, cx: float, cy: float, rx: float, ry: float,
		c: Color, inner := 0.70, rng: RandomNumberGenerator = null) -> void:
	var r := rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.seed = int(cx * 131.0 + cy * 17.0 + rx * 7.0)
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := (float(x) + 0.5 - cx) / maxf(rx, 0.001)
			var dy := (float(y) + 0.5 - cy) / maxf(ry, 0.001)
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			if d <= inner or r.randf() < 0.58:
				_px(img, x, y, c)


static func _poly_fill(img: Image, pts: PackedVector2Array, c: Color) -> void:
	if pts.size() < 3:
		return
	var min_y := 99999.0
	var max_y := -99999.0
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(int(floor(min_y)), int(ceil(max_y)) + 1):
		var xs: Array[float] = []
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= float(y) and b.y > float(y)) or (b.y <= float(y) and a.y > float(y)):
				xs.append(a.x + (float(y) - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		var i := 0
		while i + 1 < xs.size():
			var x0 := int(ceil(xs[i]))
			var x1 := int(floor(xs[i + 1]))
			for x in range(x0, x1 + 1):
				_px(img, x, y, c)
			i += 2


static func _outline(img: Image, c: Color, only_opaque := true) -> void:
	var src := img.duplicate() as Image
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a < 0.4:
				continue
			var edge := false
			var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]
			for d in dirs:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					edge = true
					break
				if src.get_pixel(nx, ny).a < 0.4:
					edge = true
					break
			if edge:
				img.set_pixel(x, y, c)
	if not only_opaque:
		return


static func _shade(c: Color, amount: float) -> Color:
	if amount >= 0.0:
		return c.lerp(Color(1.0, 1.0, 1.0, c.a), amount)
	return c.lerp(Color(0.0, 0.0, 0.0, c.a), -amount)


static func _hash01(x: int, y: int, seed: int = 0) -> float:
	var n := x * 374761393 + y * 668265263 + seed * 1442695040888963407
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


# ── 地面 ──────────────────────────────────────────────────────────────────
static func _make_ground() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261126
	var img := _canvas(640, 272)
	var band_colors: Array[Color] = [GRASS_DARK, GRASS, GRASS_MID, GRASS_DARK]
	for y in 272:
		var t := float(y) / 271.0
		var base: Color
		if t < 0.22:
			base = GRASS_DARK.lerp(GRASS_MID, t / 0.22)
		elif t < 0.55:
			base = GRASS_MID.lerp(GRASS, (t - 0.22) / 0.33)
		else:
			base = GRASS.lerp(GRASS_DARK, (t - 0.55) / 0.45 * 0.9)
		for x in 640:
			var n := _hash01(x, y, 7)
			var c := base
			if n < 0.10:
				c = _shade(base, -0.08)
			elif n > 0.92:
				c = _shade(base, 0.07)
			# 4×4 Bayer 带纹，避免纯噪声的电视雪花感。
			var bayer: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
			var b: int = bayer[(y % 4) * 4 + (x % 4)]
			if b < 3:
				c = c.lerp(band_colors[(y / 68) % band_colors.size()], 0.18)
			img.set_pixel(x, y, c)

	# 大块苔痕 / 枯草 / 阴影地衣。
	for i in 34:
		var cx := rng.randf_range(10.0, 630.0)
		var cy := rng.randf_range(20.0, 260.0)
		var rx := rng.randf_range(18.0, 74.0)
		var ry := rng.randf_range(8.0, 26.0)
		var pick := rng.randf()
		var col := GRASS_DEEP if pick < 0.35 else (GRASS_LIGHT if pick < 0.7 else GOLD_DARK)
		_ellipse_dither(img, cx, cy, rx, ry, Color(col.r, col.g, col.b, 0.32), 0.55, rng)

	# 草叶：短竖线，远处细、近处粗。
	for i in 1450:
		var x := rng.randi_range(0, 639)
		var y := rng.randi_range(4, 271)
		var depth := float(y) / 272.0
		var h := rng.randi_range(1, 2 + int(depth * 3.0))
		var col := GRASS_LIGHT if rng.randf() < 0.55 else GRASS_DEEP
		if rng.randf() < 0.06:
			col = GRASS_HI
		for k in h:
			_px(img, x, y - k, Color(col.r, col.g, col.b, 0.85))

	# 野花小点。
	for i in 260:
		var x := rng.randi_range(4, 635)
		var y := rng.randi_range(14, 268)
		var roll := rng.randf()
		var petal := Color8(246, 236, 198)
		if roll > 0.72:
			petal = Color8(238, 198, 104)
		elif roll > 0.88:
			petal = Color8(206, 146, 168)
		_px(img, x, y, petal)
		if rng.randf() < 0.55:
			_px(img, x + 1, y, petal)
		if rng.randf() < 0.3:
			_px(img, x, y - 1, petal)

	# 石板前庭。
	_make_patio(img, rng)
	# 土路：从门前折向画面下方，另一条通向右侧。
	_make_path(img, rng)
	# 树下的落叶与蘑菇。
	for i in 90:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 70.0
		var x := int(410.0 + cos(a) * r)
		var y := int(186.0 + sin(a) * r * 0.45)
		_px(img, x, y, GOLD if rng.randf() < 0.5 else GOLD_DARK)
	for i in 26:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 52.0
		var x := int(486.0 + cos(a) * r)
		var y := int(202.0 + sin(a) * r * 0.45)
		_px(img, x, y, LEAF_DARK if rng.randf() < 0.6 else WOOD)
	for i in 7:
		var mx := rng.randi_range(270, 520)
		var my := rng.randi_range(120, 240)
		_px(img, mx, my, Color8(214, 190, 160))
		_px(img, mx, my + 1, Color8(176, 142, 118))
		_px(img, mx + 1, my, Color8(196, 168, 140))

	# 底部压暗，给前景草丛一个暗底。
	for y in range(248, 272):
		var a := float(y - 248) / 24.0 * 0.22
		for x in 640:
			var d := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(d.r * (1.0 - a), d.g * (1.0 - a), d.b * (1.0 - a), 1.0))
	return img


static func _make_patio(img: Image, rng: RandomNumberGenerator) -> void:
	# 房前不规则石板区（世界 y≈238..288）。
	_ellipse_dither(img, 140.0, 170.0, 98.0, 30.0, Color(DIRT.r, DIRT.g, DIRT.b, 0.9), 0.8, rng)
	var x := 54
	var y := 152
	while x < 236:
		var w := rng.randi_range(13, 26)
		var h := rng.randi_range(7, 11)
		var sy := y + rng.randi_range(-2, 3)
		_px_slab(img, x, sy, w, h, rng)
		x += w + rng.randi_range(1, 3)
		if x > 226:
			x = 54 + rng.randi_range(0, 10)
			y += rng.randi_range(9, 13)
			if y > 196:
				break
	# 石板之间的小草。
	for i in 26:
		var gx := rng.randi_range(58, 226)
		var gy := rng.randi_range(154, 194)
		_px(img, gx, gy, GRASS_LIGHT)
		_px(img, gx, gy + 1, GRASS_DARK)


static func _px_slab(img: Image, x: int, y: int, w: int, h: int,
		rng: RandomNumberGenerator) -> void:
	var base := STONE if rng.randf() < 0.55 else _shade(STONE, -0.12)
	_rect(img, x + 1, y + 1, w - 2, h - 2, base)
	_hline(img, x + 2, y + 1, w - 4, STONE_LIGHT)
	_vline(img, x + 1, y + 2, h - 4, _shade(base, 0.08))
	_hline(img, x + 2, y + h - 2, w - 4, _shade(base, -0.18))
	_px(img, x, y + 1, STONE_DARK)
	_px(img, x + w - 1, y + h - 2, STONE_DARK)
	# 缺角。
	if rng.randf() < 0.3:
		_px(img, x + w - 2, y, Color(0, 0, 0, 0))
	if rng.randf() < 0.3:
		_px(img, x + 1, y + h - 1, Color(0, 0, 0, 0))


static func _make_path(img: Image, rng: RandomNumberGenerator) -> void:
	var pts: Array[Vector2] = [
		Vector2(122, 154), Vector2(142, 178), Vector2(178, 208),
		Vector2(222, 236), Vector2(258, 272)]
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var steps := 10
		for s in steps:
			var t := float(s) / float(steps)
			var p := a.lerp(b, t)
			var r := lerpf(11.0, 16.0, float(i) / 3.0)
			_ellipse_dither(img, p.x, p.y, r, r * 0.62 + 1.0,
					Color(DIRT.r, DIRT.g, DIRT.b, 0.94), 0.78, rng)
			_ellipse(img, p.x - 1.0, p.y - 1.0, r * 0.55, r * 0.30,
					Color(DIRT_LIGHT.r, DIRT_LIGHT.g, DIRT_LIGHT.b, 0.34))
	# 石阶与碎砾。
	for i in 18:
		var t := rng.randf()
		var p := pts[0].lerp(pts[pts.size() - 1], t)
		p += Vector2(rng.randf_range(-7.0, 7.0), rng.randf_range(-3.0, 3.0))
		_ellipse(img, p.x, p.y, rng.randf_range(2.5, 5.0), rng.randf_range(1.5, 2.6),
				STONE if rng.randf() < 0.5 else _shade(STONE, -0.15))
		_px(img, int(p.x) - 1, int(p.y) - 1, STONE_LIGHT)
	for i in 90:
		var t := rng.randf()
		var p := pts[0].lerp(pts[pts.size() - 1], t)
		p += Vector2(rng.randf_range(-11.0, 11.0), rng.randf_range(-5.0, 5.0))
		_px(img, int(p.x), int(p.y), DIRT_LIGHT if rng.randf() < 0.5 else DIRT_DARK)
	# 从中间分叉向右侧空地。
	var pts2: Array[Vector2] = [
		Vector2(198, 232), Vector2(262, 244), Vector2(330, 256),
		Vector2(410, 270)]
	for i in range(pts2.size() - 1):
		var a := pts2[i]
		var b := pts2[i + 1]
		for s in 9:
			var t := float(s) / 9.0
			var p := a.lerp(b, t)
			_ellipse_dither(img, p.x, p.y, 8.5, 4.2,
					Color(DIRT.r, DIRT.g, DIRT.b, 0.90), 0.75, rng)
	for i in 26:
		var t := rng.randf()
		var p := pts2[0].lerp(pts2[3], t)
		p += Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-2.0, 2.0))
		_px(img, int(p.x), int(p.y), DIRT_LIGHT)


# ── 远景山脊 ──────────────────────────────────────────────────────────────
static func _make_ridge() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 884422
	var img := _canvas(640, 48)
	# 远层丘陵，浅蓝灰，给地平线一点空气感。
	for x in 640:
		var y := int(15.0 + sin(float(x) * 0.013 + 0.4) * 5.0
				+ sin(float(x) * 0.037 + 2.1) * 2.5)
		for yy in range(y, 48):
			var d := float(yy - y) / 48.0
			img.set_pixel(x, yy, Color8(92, 112, 124).lerp(Color8(74, 96, 108), d))
	# 近层丘陵。
	for x in 640:
		var y := int(27.0 + sin(float(x) * 0.010 + 1.2) * 4.5
				+ sin(float(x) * 0.029 + 2.7) * 2.0)
		for yy in range(y, 48):
			var d := float(yy - y) / 48.0
			img.set_pixel(x, yy, Color8(58, 82, 86).lerp(Color8(44, 66, 72), d))
	# 松树剪影：小三角，高低错落；视觉上不要像城墙垛口。
	for i in 76:
		var x := rng.randi_range(0, 638)
		var base_y := int(27.0 + sin(float(x) * 0.010 + 1.2) * 4.5
				+ sin(float(x) * 0.029 + 2.7) * 2.0) + 1
		var h := rng.randi_range(5, 17)
		var w := maxi(2, int(float(h) * 0.30))
		for tier in h:
			var half := int(float(h - tier) / float(h) * float(w))
			for xx in range(x - half, x + half + 1):
				if xx < 0 or xx > 639:
					continue
				img.set_pixel(xx, base_y - tier, Color8(38, 58, 62))
	# 山脚薄雾，让地平线不生硬。
	for x in 640:
		for y in range(38, 48):
			var a := float(y - 38) / 10.0 * 0.22
			var d := img.get_pixel(x, y)
			img.set_pixel(x, y, d.lerp(Color8(142, 158, 154), a))
	return img

# ── 房屋 ──────────────────────────────────────────────────────────────────
static func _make_house() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 771122
	var img := _canvas(196, 150)
	# 墙体。
	_rect(img, 20, 60, 156, 82, PLASTER)
	_rect(img, 20, 60, 156, 6, PLASTER_SHADE)
	_rect(img, 20, 136, 156, 8, PLASTER_DARK)
	# 木框架。
	for bx in [22, 92, 170]:
		_rect(img, bx, 62, 4, 78, WOOD_DARK)
		_rect(img, bx + 1, 64, 1, 74, WOOD)
	_hline(img, 22, 96, 152, WOOD_DARK)
	_hline(img, 22, 97, 152, WOOD)
	_hline(img, 22, 64, 152, WOOD_DARK)
	_line(img, 26, 64, 90, 96, WOOD_DARK)
	_line(img, 27, 64, 91, 96, WOOD)
	# 门。
	_rect(img, 48, 88, 40, 58, WOOD_DARK)
	_rect(img, 51, 92, 34, 54, WOOD)
	_rect(img, 54, 96, 28, 50, _shade(WOOD, -0.12))
	for yy in range(98, 144, 6):
		_hline(img, 54, yy, 28, WOOD_DARK)
	_px(img, 78, 120, GOLD_LIGHT)
	_px(img, 79, 120, GOLD)
	_px(img, 78, 121, GOLD_DARK)
	_rect(img, 46, 144, 44, 3, STONE_DARK)
	# 窗。
	_rect(img, 112, 102, 28, 28, WOOD_DARK)
	_rect(img, 114, 104, 24, 24, Color8(64, 88, 92))
	_rect(img, 115, 105, 22, 22, Color8(88, 118, 116))
	_hline(img, 114, 114, 24, WOOD_DARK)
	_vline(img, 124, 105, 22, WOOD_DARK)
	_px(img, 116, 107, Color8(150, 182, 166))
	_px(img, 130, 108, Color8(128, 166, 152))
	_rect(img, 110, 130, 32, 12, WOOD_DARK)
	_rect(img, 112, 132, 28, 8, DIRT_DARK)
	for i in 7:
		var fx := 113 + i * 4
		_px(img, fx, 132, Color8(218, 126, 104))
		_px(img, fx, 133, GRASS_DARK)
	# 小侧窗。
	_rect(img, 148, 88, 18, 16, WOOD_DARK)
	_rect(img, 150, 90, 14, 12, Color8(92, 124, 120))
	_hline(img, 150, 96, 14, WOOD_DARK)
	# 石基。
	for i in 12:
		var sx := 20 + i * 13
		_rect(img, sx, 138, 12, 7, STONE if i % 2 == 0 else STONE_DARK)
		_px(img, sx + 1, 139, STONE_LIGHT)
	# 屋顶（山墙），带瓦片与瓦脊。
	var roof := PackedVector2Array([
		Vector2(6, 70), Vector2(190, 70), Vector2(150, 8), Vector2(46, 8)])
	_poly_fill(img, roof, ROOF_DARK)
	var roof2 := PackedVector2Array([
		Vector2(10, 66), Vector2(186, 66), Vector2(148, 12), Vector2(48, 12)])
	_poly_fill(img, roof2, ROOF)
	for yy in range(18, 64, 5):
		var t := float(yy - 12) / 54.0
		var x0 := int(lerpf(48.0, 10.0, t))
		var x1 := int(lerpf(148.0, 186.0, t))
		_hline(img, x0, yy, x1 - x0, ROOF_DARK)
		if rng.randf() < 0.8:
			_hline(img, x0 + 2, yy - 1, maxi(1, x1 - x0 - 4), ROOF_LIGHT)
		for k in range(3):
			var vx := int(lerpf(float(x0), float(x1), float(k + 1) / 4.0))
			_px(img, vx, yy + 1, ROOF_DARK)
	_hline(img, 45, 10, 106, ROOF_HI)
	_hline(img, 46, 8, 104, _shade(ROOF_HI, 0.12))
	_hline(img, 8, 67, 178, _shade(ROOF_DARK, -0.18))
	_hline(img, 14, 71, 168, _shade(ROOF_DARK, -0.25))
	# 屋檐阴影。
	_rect(img, 20, 72, 156, 3, Color(32, 24, 28, 0.45))
	# 烟囱。
	_rect(img, 132, 0, 22, 32, STONE_DARK)
	_rect(img, 134, 2, 18, 28, STONE)
	_rect(img, 132, 0, 22, 4, STONE_LIGHT)
	for i in 5:
		_hline(img, 134, 8 + i * 5, 18, STONE_DARK)
	_px(img, 137, 4, STONE_LIGHT)
	# 苔藓与藤蔓。
	for i in 28:
		var mx := rng.randi_range(10, 186)
		var my := rng.randi_range(64, 74)
		_px(img, mx, my, GRASS_LIGHT if rng.randf() < 0.5 else GRASS_DARK)
	for i in 16:
		var vx := rng.randi_range(22, 30)
		var vy := rng.randi_range(64, 100)
		_px(img, vx, vy, LEAF_LIGHT if rng.randf() < 0.5 else LEAF_DARK)
	# 整体描边。
	_outline(img, INK)
	# 门/窗玻璃的暖光单独输出，夜里由 World 叠加。
	return {
		"image": img,
		"window_rects": [Rect2(114, 104, 24, 24), Rect2(150, 90, 14, 12)],
	}


# ── 树 ────────────────────────────────────────────────────────────────────
static func _make_oak() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 909090
	var img := _canvas(124, 140)
	# 树干与根。
	_rect(img, 56, 100, 16, 36, WOOD_DARK)
	_rect(img, 58, 102, 12, 34, WOOD)
	_vline(img, 60, 104, 30, WOOD_LIGHT)
	_vline(img, 66, 108, 26, _shade(WOOD, -0.18))
	_px(img, 52, 132, WOOD_DARK)
	_px(img, 51, 133, WOOD)
	_px(img, 72, 133, WOOD_DARK)
	_px(img, 73, 132, WOOD)
	# 树冠：先深色大团，再叠中间调与高光团。
	var blobs: Array[Dictionary] = [
		{"c": Vector2(62, 56), "r": Vector2(50, 38), "col": LEAF_DEEP},
		{"c": Vector2(34, 68), "r": Vector2(30, 26), "col": LEAF_DARK},
		{"c": Vector2(92, 66), "r": Vector2(30, 28), "col": LEAF_DARK},
		{"c": Vector2(58, 34), "r": Vector2(34, 26), "col": LEAF_DARK},
		{"c": Vector2(44, 54), "r": Vector2(30, 24), "col": LEAF},
		{"c": Vector2(80, 52), "r": Vector2(28, 22), "col": LEAF},
		{"c": Vector2(60, 72), "r": Vector2(36, 20), "col": LEAF},
		{"c": Vector2(36, 40), "r": Vector2(22, 18), "col": LEAF_LIGHT},
		{"c": Vector2(70, 32), "r": Vector2(22, 16), "col": LEAF_LIGHT},
		{"c": Vector2(50, 60), "r": Vector2(18, 13), "col": LEAF_HI},
		{"c": Vector2(84, 42), "r": Vector2(16, 12), "col": LEAF_HI},
	]
	for b in blobs:
		_ellipse(img, b["c"].x, b["c"].y, b["r"].x, b["r"].y, b["col"])
	# 零散叶簇，打破圆边。
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(30.0, 52.0)
		var x := 62.0 + cos(a) * r
		var y := 56.0 + sin(a) * r * 0.72
		var col := LEAF_DARK if rng.randf() < 0.55 else LEAF
		_ellipse(img, x, y, rng.randf_range(2.0, 5.0), rng.randf_range(1.5, 4.0), col)
	# 金色秋叶点缀。
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(22.0, 48.0)
		var x := 62.0 + cos(a) * r
		var y := 52.0 + sin(a) * r * 0.7
		_px(img, int(x), int(y), GOLD_LIGHT if rng.randf() < 0.45 else GOLD)
	# 底部暗面。
	for i in 22:
		var x := rng.randi_range(22, 104)
		var y := rng.randi_range(68, 82)
		_px(img, x, y, LEAF_DEEP)
	# 高光小点。
	for i in 35:
		var a := rng.randf() * TAU
		var r := rng.randf_range(10.0, 34.0)
		var x := 58.0 + cos(a) * r
		var y := 46.0 + sin(a) * r * 0.7
		_px(img, int(x), int(y), LEAF_HI)
	_outline(img, INK)
	return img


static func _make_pine() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 515151
	var img := _canvas(68, 124)
	_rect(img, 31, 100, 7, 24, WOOD_DARK)
	_rect(img, 33, 102, 3, 20, WOOD)
	var tiers: Array[Dictionary] = [
		{"y": 108, "w": 31, "c": PINE_DEEP},
		{"y": 92, "w": 27, "c": PINE_DARK},
		{"y": 76, "w": 23, "c": PINE_DEEP},
		{"y": 60, "w": 19, "c": PINE_DARK},
		{"y": 44, "w": 15, "c": PINE_DEEP},
		{"y": 28, "w": 11, "c": PINE_DARK},
		{"y": 12, "w": 6, "c": PINE},
	]
	for tier in tiers:
		var cy: float = float(tier["y"])
		var half: int = int(tier["w"])
		var h := 26
		var pts := PackedVector2Array([
			Vector2(34 - half, cy + 8), Vector2(34 + half, cy + 8),
			Vector2(34 + half / 2, cy - h + 8), Vector2(34, cy - h - 4),
			Vector2(34 - half / 2, cy - h + 8)])
		_poly_fill(img, pts, tier["c"])
		# 左侧受光边 & 叶簇纹理。
		for i in range(1, half, 3):
			_px(img, 34 - i, int(cy) - i / 2, PINE_LIGHT)
		for i in 16:
			var x := rng.randi_range(34 - half + 2, 34 + half - 2)
			var y := rng.randi_range(int(cy) - h, int(cy) + 4)
			_px(img, x, y, PINE if rng.randf() < 0.5 else PINE_LIGHT)
	# 树干高光与描边。
	_vline(img, 32, 104, 14, WOOD_LIGHT)
	_outline(img, INK)
	return img


# ── 石柱 / 路灯 / 木桶 / 灌木 ────────────────────────────────────────────
static func _make_pillar() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 202020
	var img := _canvas(36, 76)
	_rect(img, 4, 66, 28, 10, STONE_DARK)
	_rect(img, 7, 64, 22, 4, STONE)
	_rect(img, 10, 14, 16, 52, STONE_DARK)
	_rect(img, 12, 16, 12, 48, STONE)
	_vline(img, 14, 18, 44, STONE_LIGHT)
	_vline(img, 22, 20, 40, _shade(STONE, -0.12))
	for y in range(22, 62, 9):
		_hline(img, 12, y, 12, STONE_DARK)
		_px(img, 14, y + 1, STONE_LIGHT)
	_rect(img, 7, 8, 22, 8, STONE_DARK)
	_rect(img, 9, 9, 18, 5, STONE)
	_hline(img, 9, 9, 18, STONE_LIGHT)
	_rect(img, 8, 4, 20, 4, STONE_LIGHT)
	# 缺口与苔藓。
	_px(img, 16, 20, Color(0, 0, 0, 0))
	_px(img, 17, 20, Color(0, 0, 0, 0))
	for i in 18:
		var mx := rng.randi_range(9, 24)
		var my := rng.randi_range(50, 70)
		_px(img, mx, my, GRASS_LIGHT if rng.randf() < 0.5 else GRASS_DARK)
	_line(img, 26, 30, 28, 44, STONE_DARK)
	_outline(img, INK)
	return img


static func _make_pillar_broken() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 303030
	var img := _canvas(28, 44)
	_rect(img, 2, 36, 24, 8, STONE_DARK)
	_rect(img, 5, 33, 18, 4, STONE)
	_rect(img, 8, 14, 12, 20, STONE)
	_rect(img, 9, 10, 10, 5, STONE_LIGHT)
	_px(img, 12, 14, STONE_DARK)
	_px(img, 14, 12, Color(0, 0, 0, 0))
	_px(img, 15, 11, Color(0, 0, 0, 0))
	for i in 10:
		_px(img, rng.randi_range(8, 19), rng.randi_range(28, 38), GRASS_DARK)
	_outline(img, INK)
	return img


static func _make_lamp() -> Image:
	var img := _canvas(30, 104)
	# 石座。
	_rect(img, 9, 96, 12, 8, STONE_DARK)
	_rect(img, 10, 94, 10, 3, STONE)
	# 木柱。
	_rect(img, 13, 28, 5, 68, WOOD_DARK)
	_rect(img, 14, 30, 3, 64, WOOD)
	_vline(img, 15, 32, 62, WOOD_LIGHT)
	# 横臂与吊绳。
	_rect(img, 4, 28, 18, 3, WOOD_DARK)
	_rect(img, 5, 26, 14, 2, WOOD)
	_vline(img, 7, 31, 8, _shade(WOOD, -0.2))
	# 灯笼。
	_rect(img, 2, 39, 12, 2, WOOD_DARK)
	_rect(img, 3, 41, 10, 12, LANTERN_DARK)
	_rect(img, 4, 42, 8, 10, LANTERN)
	_rect(img, 5, 43, 6, 8, LANTERN_GLOW)
	_vline(img, 7, 42, 10, LANTERN_DARK)
	_hline(img, 3, 48, 10, LANTERN_DARK)
	_rect(img, 4, 53, 8, 2, WOOD_DARK)
	_px(img, 6, 46, Color8(255, 244, 196))
	_px(img, 7, 47, Color8(255, 230, 150))
	# 柱顶小屋檐与苔藓。
	_rect(img, 10, 24, 10, 3, ROOF_DARK)
	_hline(img, 9, 26, 12, ROOF)
	for i in 8:
		_px(img, 13 + i % 4, 90 - i, GRASS_DARK)
	_outline(img, INK)
	return img


static func _make_barrel() -> Image:
	var img := _canvas(26, 32)
	_ellipse(img, 13.0, 6.0, 10.0, 4.0, WOOD_DARK)
	_ellipse(img, 13.0, 5.0, 9.0, 3.0, WOOD_LIGHT)
	_rect(img, 3, 6, 20, 21, WOOD_DARK)
	for i in 6:
		var x := 5 + i * 3
		_rect(img, x, 7, 2, 19, WOOD if i % 2 == 0 else _shade(WOOD, -0.12))
	_hline(img, 4, 10, 18, STONE_DARK)
	_hline(img, 4, 22, 18, STONE_DARK)
	_hline(img, 4, 11, 18, STONE)
	_hline(img, 4, 23, 18, STONE)
	_ellipse(img, 13.0, 27.0, 9.0, 3.0, WOOD_DARK)
	_vline(img, 7, 12, 10, WOOD_LIGHT)
	_px(img, 15, 8, WOOD_LIGHT)
	_outline(img, INK)
	return img


static func _make_bush() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var img := _canvas(30, 22)
	_ellipse(img, 15.0, 12.0, 13.0, 8.0, LEAF_DARK)
	_ellipse(img, 11.0, 10.0, 8.0, 6.0, LEAF)
	_ellipse(img, 19.0, 11.0, 7.0, 5.0, LEAF)
	_ellipse(img, 13.0, 8.0, 5.0, 3.0, LEAF_LIGHT)
	for i in 8:
		_px(img, rng.randi_range(6, 24), rng.randi_range(6, 13),
				Color8(246, 226, 168) if rng.randf() < 0.6 else Color8(230, 156, 100))
	_outline(img, INK)
	return img


# ── 角色 ──────────────────────────────────────────────────────────────────
static func _make_character() -> Image:
	var img := _canvas(22, 38)
	# 靴子与腿。
	_rect(img, 7, 32, 3, 5, Color8(58, 42, 36))
	_rect(img, 12, 32, 3, 5, Color8(58, 42, 36))
	_rect(img, 6, 36, 5, 2, Color8(38, 30, 28))
	_rect(img, 12, 36, 5, 2, Color8(38, 30, 28))
	# 斗篷。
	var cloak := PackedVector2Array([
		Vector2(6, 16), Vector2(16, 16), Vector2(19, 32),
		Vector2(14, 30), Vector2(11, 33), Vector2(8, 29), Vector2(4, 32)])
	_poly_fill(img, cloak, Color8(48, 86, 82))
	_poly_fill(img, PackedVector2Array([
		Vector2(7, 17), Vector2(12, 17), Vector2(12, 31),
		Vector2(9, 28), Vector2(6, 30)]), Color8(66, 112, 100))
	# 围巾。
	_rect(img, 6, 15, 11, 3, Color8(214, 156, 68))
	_rect(img, 15, 17, 3, 6, Color8(180, 124, 54))
	# 头与帽子。
	_rect(img, 7, 8, 8, 8, Color8(222, 176, 132))
	_rect(img, 8, 12, 6, 3, Color8(198, 148, 112))
	_px(img, 9, 11, INK)
	_px(img, 13, 11, INK)
	_rect(img, 5, 5, 12, 4, Color8(96, 62, 44))
	_rect(img, 7, 2, 8, 4, Color8(120, 80, 52))
	_rect(img, 8, 1, 6, 2, Color8(148, 102, 62))
	_rect(img, 4, 8, 14, 2, Color8(72, 46, 36))
	# 小挎包与手。
	_rect(img, 15, 23, 4, 5, Color8(120, 78, 48))
	_rect(img, 16, 24, 2, 3, Color8(88, 54, 36))
	_px(img, 5, 20, Color8(222, 176, 132))
	# 手提小灯。
	_vline(img, 18, 27, 5, Color8(70, 48, 38))
	_rect(img, 17, 31, 4, 4, Color8(226, 158, 74))
	_px(img, 18, 32, Color8(255, 226, 150))
	_px(img, 19, 32, Color8(255, 196, 96))
	_outline(img, INK)
	return img


# ── 前景草丛 ──────────────────────────────────────────────────────────────
static func _make_foreground_grass() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123123
	var img := _canvas(640, 82)
	var clusters: Array[Dictionary] = []
	for i in 26:
		var x := -10.0 + i * 25.0 + rng.randf_range(-9.0, 9.0)
		var tall := 1.0
		if x > 250.0 and x < 430.0:
			tall = 0.38
		clusters.append({"x": x, "tall": tall, "y": 80.0 + rng.randf_range(-2.0, 2.0)})
	# 两侧更高的草墙。
	for i in 16:
		var left := i < 8
		var x := rng.randf_range(0.0, 64.0) if left else rng.randf_range(576.0, 639.0)
		clusters.append({"x": x, "tall": rng.randf_range(0.9, 1.3),
				"y": rng.randf_range(76.0, 84.0)})
	for cl in clusters:
		var cx: float = cl["x"]
		var tall: float = cl["tall"]
		var base_y: float = cl["y"]
		var blades := int(10 + 16 * tall)
		for b in blades:
			var bx := cx + rng.randf_range(-13.0, 13.0)
			var h := rng.randf_range(14.0, 48.0) * tall
			var bend := rng.randf_range(-4.0, 4.0) * tall
			var col := GRASS_DARK
			var roll := rng.randf()
			if roll > 0.72:
				col = GRASS_LIGHT
			elif roll > 0.45:
				col = GRASS_MID
			var top_col := GRASS_HI if rng.randf() < 0.45 else GRASS_LIGHT
			for k in int(h):
				var t := float(k) / maxf(h, 1.0)
				var x := int(bx + bend * t * t)
				var y := int(base_y - k)
				_px(img, x, y, col if k < int(h * 0.6) else top_col)
			if rng.randf() < 0.25:
				var tipx := int(bx + bend)
				var tipy := int(base_y - h)
				_px(img, tipx, tipy, Color8(238, 220, 150))
				_px(img, tipx + 1, tipy, Color8(214, 186, 118))
	# 草间的几朵小花。
	for i in 22:
		var x := rng.randi_range(0, 639)
		if x > 270 and x < 410 and rng.randf() < 0.7:
			continue
		var y := rng.randi_range(30, 78)
		_px(img, x, y, Color8(244, 232, 190))
		_px(img, x + 1, y, Color8(226, 204, 146))
	return img


# ── 天空 / 发光材质图 ────────────────────────────────────────────────────
static func _make_sun() -> Image:
	var img := _canvas(22, 22)
	_ellipse(img, 11.0, 11.0, 9.0, 9.0, Color8(255, 178, 96))
	_ellipse(img, 11.0, 11.0, 7.0, 7.0, Color8(255, 220, 128))
	_ellipse(img, 10.0, 10.0, 5.0, 5.0, Color8(255, 244, 190))
	_ellipse(img, 9.0, 9.0, 3.0, 3.0, Color8(255, 252, 228))
	for i in 4:
		var x := 2 + i * 6
		_px(img, x, 1, Color8(255, 212, 122))
		_px(img, x, 20, Color8(255, 198, 106))
		_px(img, 1, 3 + i * 5, Color8(255, 202, 110))
		_px(img, 20, 3 + i * 5, Color8(255, 206, 118))
	return img


static func _make_moon() -> Image:
	var img := _canvas(20, 20)
	_ellipse(img, 10.0, 10.0, 8.0, 8.0, Color8(206, 220, 244))
	_ellipse(img, 10.0, 10.0, 7.0, 7.0, Color8(238, 242, 246))
	# 用天空色的圆切出月牙。
	_ellipse(img, 15.0, 7.0, 7.5, 7.5, Color8(0, 0, 0, 0))
	var cut := _canvas(20, 20)
	_ellipse(cut, 15.0, 7.0, 7.5, 7.5, Color8(0, 0, 0, 1))
	for y in 20:
		for x in 20:
			if cut.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_ellipse(img, 8.0, 12.0, 2.5, 2.5, Color8(198, 210, 228))
	_ellipse(img, 11.0, 14.0, 1.5, 1.5, Color8(206, 216, 232))
	return img


static func _make_radial_glow(w: int, h: int, color: Color, power := 1.8) -> Image:
	var img := _canvas(w, h)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.5
	for y in h:
		for x in w:
			var dx := (float(x) + 0.5 - cx) / (float(w) * 0.5)
			var dy := (float(y) + 0.5 - cy) / (float(h) * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, power)
			# Bayer 抖动，保持像素发光质感。
			var b := ((x + (y % 2) * 2) % 4) / 4.0
			if a > 0.08 and rng_keep(x, y, a):
				img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	# 中心更亮。
	_ellipse(img, cx, cy, float(w) * 0.16, float(h) * 0.16,
			Color(color.r, color.g, color.b, 0.55))
	return img


static func rng_keep(x: int, y: int, a: float) -> bool:
	return _hash01(x, y, 99) < clampf(a * 1.35, 0.0, 1.0)


static func _make_lamp_pool() -> Image:
	return _make_radial_glow(112, 60, Color(1.0, 0.72, 0.32), 1.35)


static func _make_lamp_halo() -> Image:
	return _make_radial_glow(44, 44, Color(1.0, 0.78, 0.38), 2.0)


static func _make_window_glow() -> Image:
	var img := _make_radial_glow(40, 34, Color(1.0, 0.78, 0.42), 1.35)
	# 矩形窗芯，让光看起来是窗而不是悬浮的球。
	for y in range(9, 26):
		for x in range(12, 29):
			var edge := minf(minf(x - 12, 28 - x), minf(y - 9, 25 - y))
			var a := 0.20 + 0.32 * clampf(float(edge) / 5.0, 0.0, 1.0)
			_px(img, x, y, Color(1.0, 0.80, 0.46, a))
	_vline(img, 20, 9, 17, Color(0.45, 0.30, 0.14, 0.34))
	_hline(img, 12, 17, 17, Color(0.45, 0.30, 0.14, 0.34))
	return img


static func _make_firefly() -> Image:
	var img := _canvas(5, 5)
	img.set_pixel(2, 2, Color8(255, 244, 186))
	img.set_pixel(1, 2, Color(255, 220, 120, 0.55))
	img.set_pixel(3, 2, Color(255, 220, 120, 0.55))
	img.set_pixel(2, 1, Color(255, 220, 120, 0.55))
	img.set_pixel(2, 3, Color(255, 220, 120, 0.55))
	return img


static func _make_cloud() -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = 606060
	var img := _canvas(62, 18)
	for i in 7:
		var cx := rng.randf_range(12.0, 50.0)
		var cy := rng.randf_range(8.0, 13.0)
		var rx := rng.randf_range(6.0, 13.0)
		var ry := rng.randf_range(3.0, 6.0)
		_ellipse(img, cx, cy, rx, ry, Color(1.0, 0.95, 0.88, 0.55))
	for i in 5:
		var cx := rng.randf_range(18.0, 46.0)
		var cy := rng.randf_range(5.0, 9.0)
		_ellipse(img, cx, cy, rng.randf_range(4.0, 8.0), rng.randf_range(2.0, 4.0),
				Color(1.0, 0.98, 0.92, 0.65))
	return img


static func build() -> Dictionary:
	return {
		"ground": _make_ground(),
		"ridge": _make_ridge(),
		"house": _make_house(),
		"oak": _make_oak(),
		"pine": _make_pine(),
		"pillar": _make_pillar(),
		"pillar_broken": _make_pillar_broken(),
		"lamp": _make_lamp(),
		"barrel": _make_barrel(),
		"bush": _make_bush(),
		"character": _make_character(),
		"foreground_grass": _make_foreground_grass(),
		"sun": _make_sun(),
		"moon": _make_moon(),
		"sun_glow": _make_radial_glow(52, 52, Color(1.0, 0.70, 0.30), 1.7),
		"moon_glow": _make_radial_glow(44, 44, Color(0.52, 0.68, 1.0), 2.0),
		"lamp_pool": _make_lamp_pool(),
		"lamp_halo": _make_lamp_halo(),
		"window_glow": _make_window_glow(),
		"firefly": _make_firefly(),
		"cloud": _make_cloud(),
	}
