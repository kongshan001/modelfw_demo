class_name PixelArt
extends RefCounted

# 全程序化原创像素素材：黄昏草地、红枫、松树、木灯柱、湿边石头，
# 以及一张离线烘好的倒影图集和前景蕨叶剪影。
# 不加载任何外部贴图；所有像素由本文件用固定种子绘制。

const W := 640
const H := 360


# ── 入口 ─────────────────────────────────────────────────────────────────
static func build_scene_art() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var ground := build_ground()
	var t_ground := Time.get_ticks_msec()
	var maple := build_maple()
	var pine := build_pine()
	var lamp_r := build_lamp(false)
	var lamp_l := build_lamp(true)
	var glow := build_glow()
	var t_props := Time.get_ticks_msec()
	var reflection := build_reflection(maple, pine, lamp_r, lamp_l)
	var t_refl := Time.get_ticks_msec()
	var foreground := build_foreground()
	var ring := build_ring()
	print("PIXEL_ART_MS ground=%d props=%d reflection=%d extra=%d" % [
		t_ground - t0, t_props - t_ground, t_refl - t_props,
		Time.get_ticks_msec() - t_refl])
	return {
		"ground": ground,
		"maple": maple,
		"pine": pine,
		"lamp_r": lamp_r,
		"lamp_l": lamp_l,
		"glow": glow,
		"reflection": reflection,
		"foreground": foreground,
		"ring": ring,
	}


# ── 基础工具 ─────────────────────────────────────────────────────────────
static func _hash01(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


static func _inb(x: int, y: int, w: int, h: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


static func _put(data: PackedByteArray, w: int, h: int, x: int, y: int, c: Color) -> void:
	if not _inb(x, y, w, h):
		return
	var i := (y * w + x) * 4
	data[i] = int(c.r * 255.0 + 0.5)
	data[i + 1] = int(c.g * 255.0 + 0.5)
	data[i + 2] = int(c.b * 255.0 + 0.5)
	data[i + 3] = int(c.a * 255.0 + 0.5)


static func _blend(data: PackedByteArray, w: int, h: int, x: int, y: int,
		c: Color, a: float) -> void:
	if not _inb(x, y, w, h) or a <= 0.0:
		return
	var i := (y * w + x) * 4
	var k := clampf(a, 0.0, 1.0)
	var ik := 1.0 - k
	data[i] = int(float(data[i]) * ik + c.r * 255.0 * k + 0.5)
	data[i + 1] = int(float(data[i + 1]) * ik + c.g * 255.0 * k + 0.5)
	data[i + 2] = int(float(data[i + 2]) * ik + c.b * 255.0 * k + 0.5)
	data[i + 3] = int(float(data[i + 3]) * ik + 255.0 * k + 0.5)


static func _blob(data: PackedByteArray, w: int, h: int, center: Vector2,
		radii: Vector2, color: Color, strength: float, falloff := 1.5) -> void:
	var x0 := int(center.x - radii.x)
	var x1 := int(center.x + radii.x)
	var y0 := int(center.y - radii.y)
	var y1 := int(center.y + radii.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - center.x) / radii.x, 2.0) \
					+ pow((float(y) - center.y) / radii.y, 2.0)
			if q > 1.0:
				continue
			var p := strength * pow(1.0 - q, falloff)
			if _hash01(x, y) < p:
				_blend(data, w, h, x, y, color, 0.55)


static func _soft_blob(data: PackedByteArray, w: int, h: int, center: Vector2,
		radii: Vector2, color: Color, strength: float, falloff := 1.8) -> void:
	var x0 := int(center.x - radii.x)
	var x1 := int(center.x + radii.x)
	var y0 := int(center.y - radii.y)
	var y1 := int(center.y + radii.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - center.x) / radii.x, 2.0) \
					+ pow((float(y) - center.y) / radii.y, 2.0)
			if q > 1.0:
				continue
			var a := strength * pow(1.0 - q, falloff)
			if a > 0.004:
				_blend(data, w, h, x, y, color, a)


static func _solid_ellipse(data: PackedByteArray, w: int, h: int, center: Vector2,
		radii: Vector2, color: Color) -> void:
	var x0 := int(center.x - radii.x)
	var x1 := int(center.x + radii.x)
	var y0 := int(center.y - radii.y)
	var y1 := int(center.y + radii.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - center.x) / radii.x, 2.0) \
					+ pow((float(y) - center.y) / radii.y, 2.0)
			if q <= 1.0:
				_put(data, w, h, x, y, color)


static func _brect(data: PackedByteArray, w: int, h: int, x0: int, y0: int,
		x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(data, w, h, x, y, color)


# ── Image 级工具（小图） ─────────────────────────────────────────────────
static func _iput(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _iblend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var old := img.get_pixel(x, y)
	img.set_pixel(x, y, Color(
		old.r + (c.r - old.r) * a,
		old.g + (c.g - old.g) * a,
		old.b + (c.b - old.b) * a,
		old.a + (1.0 - old.a) * a))


static func _irect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_iput(img, x, y, c)


static func _iellipse(img: Image, cx: float, cy: float, rx: float, ry: float,
		c: Color) -> void:
	var x0 := int(cx - rx)
	var x1 := int(cx + rx)
	var y0 := int(cy - ry)
	var y1 := int(cy + ry)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if pow((float(x) - cx) / rx, 2.0) + pow((float(y) - cy) / ry, 2.0) <= 1.0:
				_iput(img, x, y, c)


static func _iline(img: Image, a: Vector2i, b: Vector2i, c: Color, thick := 1) -> void:
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		for oy in range(thick):
			_iput(img, x0, y0 + oy, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _outline_silhouette(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a < 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a < 0.5:
					edge.append(Vector2i(nx, ny))
	for p in edge:
		_iput(img, p.x, p.y, c)


static func _img_from_bytes(data: PackedByteArray, w: int, h: int) -> Image:
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


# ── 地面 ─────────────────────────────────────────────────────────────────
static func build_ground() -> Image:
	# 底色在 320×180 上生成再 2× 最近邻放大：大色块更像像素草地，
	# 同时把 3 次噪声采样/像素的启动成本降到 1/4。
	var base_w := W / 2
	var base_h := H / 2
	var data := PackedByteArray()
	data.resize(base_w * base_h * 4)

	var broad := FastNoiseLite.new()
	broad.seed = 3141
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.frequency = 0.0065
	broad.fractal_type = FastNoiseLite.FRACTAL_FBM
	broad.fractal_octaves = 3
	broad.fractal_gain = 0.5

	var mid := FastNoiseLite.new()
	mid.seed = 2718
	mid.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mid.frequency = 0.030

	var fine := FastNoiseLite.new()
	fine.seed = 1618
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.frequency = 0.115

	var c_deep := Color8(52, 77, 45)
	var c_dark := Color8(63, 91, 49)
	var c_mid := Color8(77, 107, 54)
	var c_lit := Color8(91, 122, 57)
	var c_warm := Color8(107, 130, 62)
	var c_forest := Color8(19, 37, 31)
	var c_fore := Color8(32, 53, 38)

	for y in base_h:
		for x in base_w:
			var wx := float(x * 2)
			var wy := float(y * 2)
			var n1 := broad.get_noise_2d(wx, wy)
			var n2 := mid.get_noise_2d(wx, wy)
			var n3 := fine.get_noise_2d(wx, wy)
			var t := n1 * 0.55 + n2 * 0.33 + n3 * 0.12
			var c := c_deep
			if t > 0.22:
				c = c_warm
			elif t > 0.08:
				c = c_lit
			elif t > -0.06:
				c = c_mid
			elif t > -0.20:
				c = c_dark
			var hsh := _hash01(x, y)
			if hsh > 0.90:
				c = c.lightened(0.025)
			elif hsh < 0.10:
				c = c.darkened(0.025)

			if wy < 110.0:
				var sh := clampf((110.0 - wy) / 110.0, 0.0, 1.0)
				c = c.lerp(c_forest, sh * 0.56)
			if wy > 292.0:
				c = c.lerp(c_fore, clampf((wy - 292.0) / 68.0, 0.0, 1.0) * 0.28)

			var dx := (wx - 292.0) / 310.0
			var dy := (wy - 186.0) / 178.0
			var light := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			c = c.lerp(Color8(122, 138, 64), light * 0.20)
			_put(data, base_w, base_h, x, y, c)

	var base_img := _img_from_bytes(data, base_w, base_h)
	base_img.resize(W, H, Image.INTERPOLATE_NEAREST)
	data = base_img.get_data()

	# 远景林缘：压暗的树冠剪影 + 几根树干。
	var rng := RandomNumberGenerator.new()
	rng.seed = 88771
	for i in 30:
		var cx := rng.randf_range(-30.0, W + 30.0)
		var cy := rng.randf_range(-24.0, 58.0)
		var rx := rng.randf_range(22.0, 72.0)
		var ry := rng.randf_range(14.0, 40.0)
		var col := c_forest if i % 3 != 0 else Color8(29, 52, 42)
		_blob(data, W, H, Vector2(cx, cy), Vector2(rx, ry), col, 0.85, 1.1)
	for i in 16:
		var cx2 := rng.randf_range(-20.0, W + 20.0)
		var cy2 := rng.randf_range(2.0, 44.0)
		var rr := rng.randf_range(9.0, 26.0)
		_blob(data, W, H, Vector2(cx2, cy2), Vector2(rr, rr * 0.62),
				Color8(37, 64, 50), 0.55, 1.0)
	var trunks := [Vector2(58, 0), Vector2(146, -8), Vector2(438, -4), Vector2(566, -10)]
	for tr in trunks:
		var tx: int = int(tr.x)
		var tw := rng.randi_range(5, 10)
		_brect(data, W, H, tx, 0, tx + tw, 72, Color8(24, 36, 30))
		_brect(data, W, H, tx, 0, tx + 2, 72, Color8(44, 58, 41))
		_blob(data, W, H, Vector2(tx + tw * 0.5, 70), Vector2(tw + 6.0, 10.0),
				Color8(26, 46, 37), 0.55, 1.0)

	# 树影。
	_blob(data, W, H, Vector2(372, 166), Vector2(78, 30), Color8(28, 49, 36), 0.55, 1.2)
	_blob(data, W, H, Vector2(276, 292), Vector2(56, 26), Color8(27, 47, 35), 0.55, 1.2)
	_blob(data, W, H, Vector2(162, 238), Vector2(30, 12), Color8(35, 52, 37), 0.45, 1.2)
	_blob(data, W, H, Vector2(520, 234), Vector2(32, 12), Color8(35, 52, 37), 0.45, 1.2)

	# 灯下暖光池：三层柔和叠加，避免碎黄点像火星。
	for lamp in RainLayout.LAMPS:
		var base: Vector2 = lamp["pos"]
		_soft_blob(data, W, H, base + Vector2(0, -4), Vector2(86, 58),
				Color8(195, 172, 94), 0.20, 1.7)
		_soft_blob(data, W, H, base + Vector2(0, -8), Vector2(54, 36),
				Color8(222, 194, 106), 0.17, 1.8)
		_soft_blob(data, W, H, base + Vector2(0, -10), Vector2(28, 19),
				Color8(240, 213, 133), 0.14, 1.8)

	# 几块半埋的苔石（不占格，水洼可以盖过去）。
	for i in 4:
		var cx := rng.randf_range(410.0, 590.0)
		var cy := rng.randf_range(332.0, 352.0)
		var rx := rng.randf_range(7.0, 13.0)
		var ry := rng.randf_range(3.5, 6.0)
		_solid_ellipse(data, W, H, Vector2(cx + 1, cy + 1), Vector2(rx + 1.5, ry + 1.5),
				Color8(44, 57, 44))
		_solid_ellipse(data, W, H, Vector2(cx, cy), Vector2(rx, ry), Color8(88, 93, 75))
		_solid_ellipse(data, W, H, Vector2(cx - 1, cy - 1), Vector2(rx - 3, ry - 2),
				Color8(108, 111, 89))
		_blob(data, W, H, Vector2(cx + 2, cy), Vector2(rx - 2, ry - 1),
				Color8(60, 85, 49), 0.4, 1.0)

	# 草叶。
	for i in 150:
		var gx := rng.randi_range(0, W - 1)
		var gy := rng.randi_range(34, H - 2)
		if gy < 105 and rng.randf() < 0.7:
			continue
		var blades := rng.randi_range(1, 4)
		for b in blades:
			var blen := rng.randi_range(2, 6)
			var lean := rng.randi_range(-1, 1)
			var base_col := Color8(38, 61, 36)
			var tip_col := Color8(105, 128, 59) if rng.randf() < 0.6 else Color8(126, 128, 63)
			for k in blen:
				var px := gx + lean * k
				var py := gy - k
				var c := base_col.lerp(tip_col, float(k) / float(maxi(blen - 1, 1)))
				_blend(data, W, H, px, py, c, 0.85)

	# 红枫落下的叶子。
	for i in 64:
		var lx := int(rng.randf_range(268.0, 438.0))
		var ly := int(rng.randf_range(128.0, 250.0))
		var c: Color = [Color8(160, 54, 40), Color8(190, 76, 44), Color8(214, 112, 55)][i % 3]
		_blend(data, W, H, lx, ly, c, 0.9)
		if rng.randf() < 0.4:
			_blend(data, W, H, lx + 1, ly, c.darkened(0.2), 0.7)

	# 小花与三叶草。
	for i in 16:
		var fx := rng.randi_range(20, W - 20)
		var fy := rng.randi_range(120, H - 14)
		var stem_col := Color8(44, 68, 37)
		_brect(data, W, H, fx, fy - 2, fx, fy, stem_col)
		var petal: Color = [Color8(232, 219, 150), Color8(221, 106, 86),
				Color8(236, 232, 208)][i % 3]
		_put(data, W, H, fx - 1, fy - 3, petal)
		_put(data, W, H, fx + 1, fy - 3, petal)
		_put(data, W, H, fx, fy - 4, petal)
		_put(data, W, H, fx, fy - 3, Color8(210, 168, 72))

	# 中景小蕨丛：让空地不只是平涂草色。
	var fern_spots := [
		[Vector2(452.0, 266.0), -2.2, 30.0],
		[Vector2(320.0, 236.0), -0.7, 24.0],
		[Vector2(566.0, 214.0), -2.5, 26.0],
		[Vector2(96.0, 296.0), -0.5, 28.0],
		[Vector2(592.0, 330.0), -2.0, 22.0],
		[Vector2(212.0, 318.0), -0.9, 20.0],
		[Vector2(410.0, 320.0), -2.4, 22.0],
	]
	for spot in fern_spots:
		_fern_buf(data, W, H, spot[0], spot[1], spot[2], 3,
				Color8(41, 66, 43), Color8(66, 94, 52), rng)

	# 石头：与 PuddleField 的占位格对齐，积水会绕开。
	for rock in RainLayout.ROCK_CLUSTERS:
		var c: Vector2 = rock["pos"]
		var rx: float = rock["rx"]
		var ry: float = rock["ry"]
		_draw_boulder(data, W, H, c + Vector2(-rx * 0.35, 2), rx * 0.55, ry * 0.72, rng)
		_draw_boulder(data, W, H, c + Vector2(rx * 0.32, 4), rx * 0.46, ry * 0.62, rng)
		_draw_boulder(data, W, H, c + Vector2(rx * 0.05, -ry * 0.35), rx * 0.42, ry * 0.58, rng)
	var bank: Vector2 = RainLayout.STONE_BANK["pos"]
	var bank_rx: float = RainLayout.STONE_BANK["rx"]
	var bank_ry: float = RainLayout.STONE_BANK["ry"]
	for i in 5:
		var bx := bank.x - bank_rx + 14.0 + float(i) * (bank_rx * 2.0 - 20.0) / 4.0
		var by := bank.y + sin(float(i) * 1.7) * 4.0
		_draw_boulder(data, W, H, Vector2(bx, by), 19.0 + float(i % 2) * 5.0,
				bank_ry * 0.72, rng)
	_blob(data, W, H, bank, Vector2(bank_rx, bank_ry * 0.8),
			Color8(56, 66, 52), 0.5, 1.0)

	# 细碎石子。
	for i in 40:
		var sx := rng.randi_range(340, 470)
		var sy := rng.randi_range(170, 350)
		_blend(data, W, H, sx, sy, Color8(94, 95, 78), 0.6)

	return _img_from_bytes(data, W, H)


static func _fern_buf(data: PackedByteArray, w: int, h: int, root: Vector2,
		angle: float, length: float, fronds: int, dark: Color, mid: Color,
		rng: RandomNumberGenerator) -> void:
	for f in fronds:
		var dir := angle + rng.randf_range(-0.45, 0.45)
		var pos := root
		var step_len := length / 6.0
		for seg in 6:
			var t := float(seg) / 5.0
			_blend(data, w, h, int(pos.x), int(pos.y), mid if seg % 2 == 0 else dark, 0.9)
			_blend(data, w, h, int(pos.x) + 1, int(pos.y), dark, 0.8)
			var leaf := (1.0 - t) * 5.0 + 1.0
			var nx := cos(dir + PI * 0.5)
			var ny := sin(dir + PI * 0.5)
			for side in [-1.0, 1.0]:
				for k in int(leaf):
					_blend(data, w, h,
							int(pos.x + nx * float(k) * side),
							int(pos.y + ny * float(k) * side + float(k) * 0.4),
							dark if k < 2 else mid, 0.85)
			pos += Vector2(cos(dir), sin(dir)) * step_len
			dir += rng.randf_range(-0.12, 0.12)


static func _draw_boulder(data: PackedByteArray, w: int, h: int, c: Vector2,
		rx: float, ry: float, rng: RandomNumberGenerator) -> void:
	_solid_ellipse(data, w, h, c + Vector2(1, 2), Vector2(rx + 1.5, ry + 1.5),
			Color8(38, 50, 42))
	_solid_ellipse(data, w, h, c, Vector2(rx, ry), Color8(74, 80, 69))
	_solid_ellipse(data, w, h, c + Vector2(-1.5, -2), Vector2(rx - 3.0, ry - 2.5),
			Color8(94, 96, 81))
	_solid_ellipse(data, w, h, c + Vector2(-rx * 0.28, -ry * 0.34),
			Vector2(rx * 0.48, ry * 0.38), Color8(116, 114, 95))
	_blob(data, w, h, c + Vector2(rx * 0.30, ry * 0.10), Vector2(rx * 0.45, ry * 0.45),
			Color8(56, 82, 48), 0.55, 1.0)
	for i in 3:
		var px := int(c.x + rng.randf_range(-rx * 0.7, rx * 0.7))
		var py := int(c.y + rng.randf_range(-ry * 0.5, ry * 0.5))
		_blend(data, w, h, px, py, Color8(126, 128, 104), 0.5)


# ── 红枫 ─────────────────────────────────────────────────────────────────
static func build_maple() -> Image:
	var w := 112
	var h := 132
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150

	# 树干与枝条：深秋湿木，暗部偏冷。
	var wood_dark := Color8(45, 29, 23)
	var wood := Color8(76, 47, 32)
	var wood_lit := Color8(111, 71, 43)
	for y in range(86, h):
		var t := float(y - 86) / float(h - 86)
		var half := int(3.0 + t * 4.5)
		for x in range(56 - half, 56 + half + 1):
			_iput(img, x, y, wood if x < 58 else wood_dark)
		_iput(img, 56 - half, y, wood_lit)
	for b in 5:
		var start_p := Vector2i(56 + rng.randi_range(-2, 2), 92 + b * 3)
		var end_p := Vector2i(start_p.x + rng.randi_range(-16, 16),
				start_p.y - rng.randi_range(8, 20))
		_iline(img, start_p, end_p, wood_dark, 1)
		_iline(img, start_p + Vector2i(1, 0), end_p + Vector2i(1, 0), wood, 1)
	_iellipse(img, 56, 129, 13, 5, Color8(54, 39, 27))
	_iellipse(img, 56, 128, 9, 3, Color8(79, 54, 34))

	# 树冠：深红打底，砖红/珊瑚色分层，少量亮橙做受光点。
	var blobs := [
		[56, 50, 23, 18], [38, 44, 16, 14], [75, 42, 17, 15],
		[27, 60, 14, 12], [85, 60, 15, 12], [48, 30, 14, 12],
		[68, 29, 13, 11], [56, 71, 21, 14], [35, 80, 12, 10],
		[79, 80, 14, 10], [20, 47, 11, 9], [94, 48, 10, 9],
		[44, 15, 10, 9], [66, 15, 9, 8], [56, 91, 10, 7],
		[90, 71, 9, 8], [17, 66, 8, 7], [15, 82, 7, 6],
		[101, 72, 6, 6],
	]
	var deep := Color8(88, 31, 33)
	var base_c := Color8(136, 45, 42)
	var mid_c := Color8(174, 62, 47)
	var lit_c := Color8(201, 84, 54)
	var hot := Color8(219, 126, 72)
	# 轮廓层。
	for b in blobs:
		_iellipse(img, b[0], b[1], b[2] + 2, b[3] + 2, Color8(57, 23, 25))
	# 深色底。
	for b in blobs:
		_iellipse(img, b[0], b[1], b[2], b[3], deep)
	for b in blobs:
		_iellipse(img, b[0] - 1, b[1] - 2, b[2] * 0.90, b[3] * 0.88, base_c)
		if rng.randf() < 0.8:
			_iellipse(img, b[0] - 3, b[1] - 4, b[2] * 0.62, b[3] * 0.58, mid_c)
	# 受光叶团。
	for b in blobs:
		if rng.randf() < 0.62:
			_iellipse(img, b[0] - 4, b[1] - 6, b[2] * 0.34, b[3] * 0.30,
					lit_c if rng.randf() < 0.75 else mid_c)
	for i in 10:
		var bi: Array = blobs[rng.randi_range(0, blobs.size() - 1)]
		_iellipse(img, bi[0] - 5 + rng.randi_range(-2, 3),
				bi[1] - 7 + rng.randi_range(-2, 2),
				2.2 + rng.randi_range(0, 2), 1.8 + rng.randi_range(0, 2), hot)
	# 树冠下缘压暗，让体积沉下来。
	for b in blobs:
		if b[1] > 58:
			_iellipse(img, b[0] + 2, b[1] + 2, b[2] * 0.55, b[3] * 0.42, deep)
	# 边缘碎叶：打破圆团剪影。
	for i in 140:
		var ang := rng.randf() * TAU
		var rr := rng.randf_range(0.82, 1.12)
		var px := int(56.0 + cos(ang) * 48.0 * rr)
		var py := int(50.0 + sin(ang) * 44.0 * rr)
		if _hash01(px, py) < 0.35:
			continue
		var c: Color = [deep, base_c, mid_c, lit_c][i % 4]
		_iput(img, px, py, c)
		if i % 5 == 0:
			_iput(img, px + 1, py, mid_c)
	# 叶隙与少量橙黄点。
	for i in 46:
		var px := rng.randi_range(12, 100)
		var py := rng.randi_range(12, 96)
		if img.get_pixel(px, py).a < 0.5:
			continue
		var c: Color = deep if i % 3 == 0 else (hot if i % 11 == 0 else lit_c)
		_iput(img, px, py, c)
	for i in 60:
		var px := rng.randi_range(14, 98)
		var py := rng.randi_range(14, 94)
		if img.get_pixel(px, py).a > 0.5 and _hash01(px, py) > 0.72:
			_iput(img, px, py, base_c)

	_outline_silhouette(img, Color8(43, 19, 23))
	_iline(img, Vector2i(53, 98), Vector2i(53, 126), wood_lit, 1)
	return img


# ── 松树 ─────────────────────────────────────────────────────────────────
static func build_pine() -> Image:
	var w := 88
	var h := 138
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6161

	var trunk_dark := Color8(42, 29, 22)
	var trunk := Color8(70, 48, 32)
	for y in range(108, h):
		var t := float(y - 108) / float(h - 108)
		var half := int(3.5 + t * 4.5)
		for x in range(44 - half, 44 + half + 1):
			_iput(img, x, y, trunk if x < 45 else trunk_dark)
		_iput(img, 44 - half, y, Color8(98, 67, 41))
	_iellipse(img, 44, 134, 14, 5, Color8(39, 32, 25))
	_iellipse(img, 44, 133, 10, 3, Color8(67, 48, 31))

	# 七层下垂枝：层底做锯齿和暗缝，左侧留一点雨天冷光。
	var tiers := [
		[Vector2(6.0, 30.0), 13.0],
		[Vector2(19.0, 50.0), 20.0],
		[Vector2(35.0, 70.0), 26.0],
		[Vector2(51.0, 90.0), 31.0],
		[Vector2(68.0, 108.0), 35.0],
		[Vector2(86.0, 124.0), 38.0],
		[Vector2(104.0, 136.0), 29.0],
	]
	var c_dark := Color8(17, 35, 30)
	var c_base := Color8(27, 54, 45)
	var c_mid := Color8(39, 73, 58)
	var c_light := Color8(58, 94, 72)
	var c_high := Color8(94, 124, 98)
	var c_cool := Color8(58, 84, 88)
	for ti in tiers.size():
		var top: float = tiers[ti][0].x
		var bottom: float = tiers[ti][0].y
		var halfw: float = tiers[ti][1]
		for y in range(int(top), int(bottom) + 1):
			var t := (float(y) - top) / (bottom - top)
			var half := lerpf(1.5, halfw, pow(t, 0.86))
			for x in range(44 - int(half) - 1, 44 + int(half) + 2):
				var nx := (float(x) - 44.0) / maxf(half, 1.0)
				var edge := absf(nx)
				var wob := (_hash01(x, y + ti * 7) - 0.5) * 0.10
				if edge > 0.96 + wob:
					continue
				# 下缘锯齿：随机往下多画 1–3 像素的针叶尖。
				if edge > 0.72 and _hash01(x * 5, y * 3) > 0.78:
					continue
				var c := c_base
				if y > int(bottom) - 4:
					c = c_dark
				elif nx < -0.42:
					c = c_light
				elif nx < 0.12:
					c = c_mid
				if _hash01(x * 3, y * 5) > 0.94:
					c = c_high
				if nx > 0.55 and _hash01(x, y * 7) > 0.90:
					c = c_cool
				_iput(img, x, y, c)
		# 层底暗线和垂枝。
		_iline(img, Vector2i(44 - int(halfw * 0.82), int(bottom) - 2),
				Vector2i(44 + int(halfw * 0.82), int(bottom) - 2), c_dark, 1)
		for b in 5:
			var yy := int(rng.randf_range(top + 6.0, bottom - 2.0))
			var xx := 44 + (1 if b % 2 == 0 else -1) * int(halfw * rng.randf_range(0.55, 0.95))
			_iline(img, Vector2i(44, yy - 3), Vector2i(xx, yy + 3),
					c_dark if b % 2 == 0 else c_base, 1)

	# 小枯尖：只露 3–4 像素，不像大帽子。
	for y in range(3, 10):
		var half := int(1.0 + float(y - 3) * 0.36)
		for x in range(44 - half, 44 + half + 1):
			_iput(img, x, y, Color8(178, 153, 108) if x < 45 else Color8(127, 105, 75))
	# 基部红叶与苔。
	var berry := Color8(139, 39, 37)
	var berry_lit := Color8(178, 64, 45)
	for i in 9:
		var px := rng.randi_range(23, 65)
		var py := rng.randi_range(114, 132)
		_iput(img, px, py, berry if i % 2 == 0 else berry_lit)
	# 左缘冷反光。
	for i in 26:
		var yy := rng.randi_range(16, 120)
		var xx := 44 - int(lerpf(12.0, 34.0, float(yy) / 138.0)) + rng.randi_range(0, 3)
		if img.get_pixel(xx, yy).a > 0.5:
			_iput(img, xx, yy, c_light if i % 3 else c_cool)

	_outline_silhouette(img, Color8(13, 27, 23))
	return img


# ── 木灯柱 ───────────────────────────────────────────────────────────────
static func build_lamp(flip: bool) -> Image:
	var w := 64
	var h := 116
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var wood_dark := Color8(57, 37, 25)
	var wood := Color8(91, 58, 37)
	var wood_lit := Color8(129, 84, 49)
	var metal := Color8(48, 35, 26)
	var metal_lit := Color8(108, 84, 48)

	# 根部石块/树根。
	_iellipse(img, 32, 110, 16, 7, Color8(51, 47, 37))
	_iellipse(img, 32, 108, 13, 5, Color8(82, 65, 45))
	_iellipse(img, 28, 107, 6, 3, Color8(112, 88, 55))
	_iellipse(img, 44, 111, 5, 3, Color8(49, 74, 45))

	# 立柱。
	for y in range(18, 111):
		_irect(img, 24, y, 31, y, wood)
		_irect(img, 24, y, 25, y, wood_lit)
		_irect(img, 31, y, 31, y, wood_dark)
	for y in range(30, 106, 9):
		_iput(img, 27, y, wood_dark)
		_iput(img, 29, y + 3, wood_lit.darkened(0.15))
	for y in range(78, 98, 3):
		_iput(img, 30, y, Color8(65, 88, 51))
	# 顶部横臂与斜撑。
	_irect(img, 28, 15, 52, 21, wood_dark)
	_irect(img, 28, 16, 52, 18, wood)
	_irect(img, 28, 16, 50, 16, wood_lit)
	_irect(img, 49, 15, 52, 22, wood_dark)
	_iline(img, Vector2i(33, 35), Vector2i(48, 22), wood_dark, 2)
	_iline(img, Vector2i(34, 34), Vector2i(47, 23), wood, 1)
	# 铁箍。
	_irect(img, 28, 24, 31, 25, metal)
	_irect(img, 28, 54, 31, 55, metal)
	# 吊链。
	_irect(img, 48, 22, 49, 29, metal)
	_iput(img, 48, 23, metal_lit)
	_iput(img, 49, 26, metal_lit)

	# 灯笼：深框 + 暖玻璃 + 横向遮光条。
	_irect(img, 41, 28, 58, 32, metal)
	_irect(img, 42, 29, 57, 30, metal_lit)
	_irect(img, 43, 32, 56, 52, metal)
	_irect(img, 45, 33, 55, 51, Color8(255, 210, 112))
	_irect(img, 45, 33, 55, 36, Color8(255, 232, 158))
	_irect(img, 45, 44, 55, 46, Color8(215, 156, 67))
	_irect(img, 45, 49, 55, 51, Color8(166, 108, 49))
	_irect(img, 49, 32, 51, 51, metal)
	_irect(img, 54, 33, 55, 51, Color8(214, 155, 71))
	_irect(img, 42, 52, 57, 56, metal)
	_irect(img, 43, 53, 56, 54, metal_lit)
	_iput(img, 46, 34, Color8(255, 248, 200))
	_iput(img, 47, 35, Color8(255, 248, 200))
	# 灯笼高光外溢到木头的一点暖色。
	_iput(img, 40, 42, Color8(147, 104, 58))
	_iput(img, 39, 41, Color8(113, 82, 50))

	_outline_silhouette(img, Color8(38, 25, 20))
	if flip:
		img.flip_x()
	return img


# ── 灯光辉光 ─────────────────────────────────────────────────────────────
static func build_glow() -> Image:
	var w := 128
	var h := 128
	var data := PackedByteArray()
	data.resize(w * h * 4)
	var center := Vector2(64, 64)
	for y in h:
		for x in w:
			var d := center.distance_to(Vector2(float(x) + 0.5, float(y) + 0.5)) / 64.0
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, 2.9) * 0.55
			_put(data, w, h, x, y, Color(1.0, 0.81, 0.45, a))
	# 中心暖核，叠一层更亮的淡黄。
	for y in range(44, 84):
		for x in range(44, 84):
			var d := Vector2(float(x) - 64.0, float(y) - 64.0).length() / 20.0
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, 2.1) * 0.26
			var old := data[(y * w + x) * 4 + 3] / 255.0
			_put(data, w, h, x, y, Color(1.0, 0.92, 0.68, minf(0.85, old + a * (1.0 - old))))
	return _img_from_bytes(data, w, h)


# ── 倒影图集（离线镜像，shader 用统一 mask 裁切） ─────────────────────────
static func build_reflection(maple: Image, pine: Image, lamp_r: Image,
		lamp_l: Image) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	_stamp_flipped(img, pine, RainLayout.PINE["pos"], Color(0.74, 0.98, 1.0), 0.62, 0.42)
	_stamp_flipped(img, maple, RainLayout.MAPLE["pos"], Color(0.92, 0.66, 0.68), 0.50, 0.36)
	_stamp_flipped(img, lamp_r, RainLayout.LAMPS[0]["pos"], Color(1.0, 0.84, 0.66), 0.28, 0.55)
	_stamp_flipped(img, lamp_l, RainLayout.LAMPS[1]["pos"], Color(1.0, 0.84, 0.66), 0.28, 0.55)

	for i in RainLayout.LAMPS.size():
		var lamp: Dictionary = RainLayout.LAMPS[i]
		var base: Vector2 = lamp["pos"]
		var sign_x := -1.0 if bool(lamp["flip"]) else 1.0
		# 灯笼暖光在水下的拉长光晕。
		var warm := Color8(255, 207, 112)
		_warm_reflection_blob(img, base + Vector2(sign_x * 18.0, 58.0),
				Vector2(36.0, 58.0), warm, 0.84)
		_warm_reflection_blob(img, base + Vector2(sign_x * 18.0, 28.0),
				Vector2(17.0, 22.0), Color8(255, 235, 166), 0.30)
	return img


static func _stamp_flipped(dst: Image, src: Image, base_pos: Vector2,
		tint: Color, alpha: float, fade: float) -> void:
	var flipped: Image = src.duplicate()
	flipped.flip_y()
	var sw := src.get_width()
	var sh := src.get_height()
	var ox := int(base_pos.x - sw * 0.5)
	var oy := int(base_pos.y)
	var data := flipped.get_data()
	for y in sh:
		var row_fade := 1.0 - fade * (float(y) / float(sh))
		for x in sw:
			var i := (y * sw + x) * 4
			if data[i + 3] == 0:
				continue
			data[i] = int(float(data[i]) * tint.r)
			data[i + 1] = int(float(data[i + 1]) * tint.g)
			data[i + 2] = int(float(data[i + 2]) * tint.b)
			data[i + 3] = int(float(data[i + 3]) * alpha * row_fade)
	flipped = Image.create_from_data(sw, sh, false, Image.FORMAT_RGBA8, data)
	dst.blend_rect(flipped, Rect2i(0, 0, sw, sh), Vector2i(ox, oy))


static func _warm_reflection_blob(dst: Image, center: Vector2, radii: Vector2,
		color: Color, strength: float) -> void:
	# 平滑的暖光倒影：不要散点抖动，否则进入水面 shader 后会像电视雪花。
	var x0 := int(center.x - radii.x)
	var x1 := int(center.x + radii.x)
	var y0 := int(center.y - radii.y)
	var y1 := int(center.y + radii.y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - center.x) / radii.x, 2.0) \
					+ pow((float(y) - center.y) / radii.y, 2.0)
			if q > 1.0:
				continue
			var a := strength * pow(1.0 - q, 1.8) * 0.34
			if a > 0.003:
				_iblend(dst, x, y, color, a)


# ── 前景剪影 ─────────────────────────────────────────────────────────────
static func build_foreground() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9191
	var dark := Color8(10, 24, 19)
	var mid := Color8(20, 39, 29)

	# 只保留四角的大蕨叶，前景是清晰的剪影而不是满屏噪点。
	_draw_fern(img, Vector2(8, 384), -1.02, 116.0, 5, dark, mid, rng)
	_draw_fern(img, Vector2(58, 380), -1.28, 86.0, 3, dark, mid, rng)
	_draw_fern(img, Vector2(632, 378), -2.10, 118.0, 5, dark, mid, rng)
	_draw_fern(img, Vector2(586, 384), -1.82, 82.0, 3, dark, mid, rng)
	_draw_fern(img, Vector2(474, 376), -1.60, 52.0, 2, dark, mid, rng)

	# 底边少量草叶，保持前景透气。
	for i in 7:
		var bx := rng.randi_range(150, 520)
		var by := rng.randi_range(352, H - 1)
		var bh := rng.randi_range(3, 8)
		for k in bh:
			_iput(img, bx + int(k * 0.35), by - k, dark if k < bh * 0.6 else mid)

	# 只保留极轻的底边压暗；左右不再做暗角，避免屏幕边缘出现抖动噪点。
	for y in range(342, H):
		for x in W:
			var a := clampf(float(y - 342) / 26.0, 0.0, 1.0) * 0.055
			if _hash01(x / 2, y / 2) < a:
				_iput(img, x, y, Color(0.014, 0.034, 0.027, 0.7))
	return img


static func _draw_fern(img: Image, root: Vector2, angle: float, length: float,
		fronds: int, dark: Color, mid: Color, rng: RandomNumberGenerator) -> void:
	for f in fronds:
		var dir := angle + rng.randf_range(-0.38, 0.38)
		var pos := root
		var step_len := length / 7.0
		for s in 7:
			var t := float(s) / 6.0
			_iput(img, int(pos.x), int(pos.y), mid if s % 2 == 0 else dark)
			_iput(img, int(pos.x) + 1, int(pos.y), dark)
			var leaf := (1.0 - t) * 9.0 + 2.0
			var nx := cos(dir + PI * 0.5)
			var ny := sin(dir + PI * 0.5)
			for side in [-1.0, 1.0]:
				for k in int(leaf):
					var px := int(pos.x + nx * float(k) * side)
					var py := int(pos.y + ny * float(k) * side + float(k) * 0.35)
					_iput(img, px, py, dark if k < 3 else mid)
			pos += Vector2(cos(dir), sin(dir)) * step_len
			dir += rng.randf_range(-0.10, 0.10)


# ── 双环涟漪贴图 ─────────────────────────────────────────────────────────
static func build_ring() -> Image:
	var w := 32
	var h := 32
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(16, 16)
	var rings := [
		{"r": 9.0, "a": 0.55},
		{"r": 13.5, "a": 0.90},
	]
	for y in h:
		for x in w:
			var d := center.distance_to(Vector2(float(x) + 0.5, float(y) + 0.5))
			for ring in rings:
				var r: float = ring["r"]
				if absf(d - r) < 0.62:
					var a: float = ring["a"]
					_iput(img, x, y, Color(0.83, 0.96, 0.93, a))
	return img
