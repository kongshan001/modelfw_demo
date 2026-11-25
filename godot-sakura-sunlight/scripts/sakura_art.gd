class_name SakuraArt
extends RefCounted

# 全程序化原创像素素材：草地、远景树篱、三棵樱花树（树干/树冠分件）、
# 石头、草丛、野花、飘落花瓣、接触阴影、树干阴影条，以及树冠/石头剪影。
# 不加载任何外部贴图；固定种子，每次启动生成同一座庭院。

const W := 640
const H := 360

const C_OUTLINE := Color(0.39, 0.17, 0.26)
const C_PLUM_DEEP := Color(0.58, 0.24, 0.35)
const C_PLUM_DARK := Color(0.76, 0.34, 0.47)
const C_ROSE := Color(0.91, 0.48, 0.61)
const C_ROSE_LIGHT := Color(0.99, 0.66, 0.76)
const C_PETAL_PALE := Color(1.00, 0.85, 0.90)
const C_BLOSSOM := Color(1.00, 0.96, 0.98)

const C_GRASS := Color(0.43, 0.67, 0.34)
const C_GRASS_LIGHT := Color(0.52, 0.76, 0.41)
const C_GRASS_DARK := Color(0.34, 0.56, 0.30)
const C_GRASS_DEEP := Color(0.27, 0.46, 0.26)
const C_GRASS_GOLD := Color(0.64, 0.74, 0.40)

const C_ROCK := Color(0.64, 0.66, 0.64)
const C_ROCK_LIGHT := Color(0.84, 0.85, 0.80)
const C_ROCK_DARK := Color(0.47, 0.49, 0.51)
const C_MOSS := Color(0.48, 0.68, 0.36)
const C_MOSS_LIGHT := Color(0.60, 0.78, 0.42)

const C_HEDGE_DARK := Color(0.25, 0.39, 0.30)
const C_HEDGE := Color(0.33, 0.48, 0.34)
const C_HEDGE_LIGHT := Color(0.42, 0.58, 0.38)

const C_TRUNK_DARK := Color(0.34, 0.22, 0.18)
const C_TRUNK := Color(0.52, 0.35, 0.26)
const C_TRUNK_LIGHT := Color(0.68, 0.49, 0.35)


static func build() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var art: Dictionary = {}
	art["ground"] = _build_ground()
	art["hedge"] = _build_hedge()
	var t_ground := Time.get_ticks_msec()

	art["tree_hero"] = _build_tree(_tree_cfg_hero(), 1107)
	art["tree_right"] = _build_tree(_tree_cfg_right(), 2203)
	art["tree_sapling"] = _build_tree(_tree_cfg_sapling(), 3301)
	var t_trees := Time.get_ticks_msec()

	art["rock_big"] = _build_rock(56, 38, 4101, 1.0)
	art["rock_mid"] = _build_rock(38, 27, 4201, 0.7)
	art["rock_small"] = _build_rock(25, 18, 4301, 0.45)
	art["tuft"] = _build_tuft()
	art["flower"] = _build_flower()
	art["petal"] = _build_petal()
	art["contact"] = _build_contact()
	art["trunk_shadow"] = _build_trunk_shadow()
	var t_props := Time.get_ticks_msec()

	print("SAKURA_ART_MS ground=%d trees=%d props=%d total=%d" % [
		t_ground - t0, t_trees - t_ground, t_props - t_trees,
		Time.get_ticks_msec() - t0])
	return art


# ── 确定性工具 ───────────────────────────────────────────────────────────
static func _hash01(x: int, y: int, seed: int) -> float:
	var h := (x * 374761393 + y * 668265263 + seed * 1442695041) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177 & 0x7fffffff
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0


static func _inb(x: int, y: int, w: int, h: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


static func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var old := img.get_pixel(x, y)
	var k := clampf(a, 0.0, 1.0)
	img.set_pixel(x, y, Color(
		old.r + (c.r - old.r) * k,
		old.g + (c.g - old.g) * k,
		old.b + (c.b - old.b) * k,
		old.a + (1.0 - old.a) * k))


static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(img, x, y, c)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float,
		c: Color, dither := 1.0) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - cx) / maxf(rx, 0.001), 2.0) \
					+ pow((float(y) - cy) / maxf(ry, 0.001), 2.0)
			if q <= 1.0:
				if dither < 1.0 and _hash01(x, y, 17) > dither:
					continue
				_put(img, x, y, c)


static func _line(img: Image, a: Vector2i, b: Vector2i, c: Color, thick := 1) -> void:
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
			_put(img, x0, y0 + oy, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _outline(img: Image, c: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var edge: Array[Vector2i] = []
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a >= 0.6:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				if img.get_pixel(nx, ny).a >= 0.6:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		_put(img, p.x, p.y, c)


static func _trim_alpha(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var minx := w
	var miny := h
	var maxx := -1
	var maxy := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.01:
				minx = mini(minx, x)
				miny = mini(miny, y)
				maxx = maxi(maxx, x)
				maxy = maxi(maxy, y)
	if maxx < 0:
		return img
	return img.get_region(Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1))


static func _silhouette(src: Image) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var out := _img(w, h)
	for y in h:
		for x in w:
			var a := src.get_pixel(x, y).a
			if a > 0.55:
				# 到最近透明像素的近似距离：0/1/2，越靠边越透，影子更柔。
				var depth := 2
				for r in [1, 2]:
					var hit := false
					for dy in range(-r, r + 1):
						for dx in range(-r, r + 1):
							if absi(dx) != r and absi(dy) != r:
								continue
							var nx: int = x + dx
							var ny: int = y + dy
							if nx < 0 or ny < 0 or nx >= w or ny >= h:
								hit = true
							elif src.get_pixel(nx, ny).a < 0.2:
								hit = true
					if hit:
						depth = mini(depth, r)
				var alpha := 0.92
				if depth == 1:
					alpha = 0.48
				elif depth == 2:
					alpha = 0.74
				out.set_pixel(x, y, Color(1, 1, 1, alpha))
			elif a > 0.02 and _hash01(x, y, 88) < 0.42:
				out.set_pixel(x, y, Color(1, 1, 1, 0.24))
	return _trim_alpha(out)


# ── 地面 ─────────────────────────────────────────────────────────────────
static func _build_ground() -> Image:
	var data := PackedByteArray()
	data.resize(W * H * 4)

	var broad := FastNoiseLite.new()
	broad.seed = 20261125
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.frequency = 0.020
	broad.fractal_type = FastNoiseLite.FRACTAL_FBM
	broad.fractal_octaves = 3
	broad.fractal_gain = 0.48

	var mid := FastNoiseLite.new()
	mid.seed = 731
	mid.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mid.frequency = 0.085

	for y in H:
		for x in W:
			var n := broad.get_noise_2d(float(x), float(y)) * 0.60 					+ mid.get_noise_2d(float(x), float(y)) * 0.40
			var c := C_GRASS
			if n > 0.34:
				c = C_GRASS.lerp(C_GRASS_LIGHT, clampf((n - 0.34) * 1.7, 0.0, 0.55))
			elif n < -0.34:
				c = C_GRASS.lerp(C_GRASS_DARK, clampf((-n - 0.34) * 1.8, 0.0, 0.60))
			var hsh := _hash01(x, y, 901)
			if hsh > 0.986:
				c = c.lightened(0.025)
			elif hsh < 0.014:
				c = c.darkened(0.025)
			var i := (y * W + x) * 4
			data[i] = int(c.r * 255.0 + 0.5)
			data[i + 1] = int(c.g * 255.0 + 0.5)
			data[i + 2] = int(c.b * 255.0 + 0.5)
			data[i + 3] = 255

	var img := Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, data)

	# 细碎草叶纹理：短竖线而不是噪点，读起来更像手绘草地。
	for i in 6200:
		var x := int(_hash01(i, 3, 501) * float(W))
		var y := int(_hash01(i, 7, 502) * float(H))
		var ln := 1 + int(_hash01(i, 11, 503) * 3.0)
		var roll := _hash01(i, 13, 504)
		var c := C_GRASS_DARK
		if roll > 0.45:
			c = C_GRASS_LIGHT
		elif roll > 0.16:
			c = C_GRASS_GOLD
		for k in ln:
			_blend(img, x, y + k, c, 0.24)
			if k == 0 and _hash01(i, 17, 505) > 0.58:
				_blend(img, x + 1, y, c, 0.16)

	# 落在草地上的樱花瓣（围绕树根位置）。
	var petal_spots := [
		Vector2(300, 190), Vector2(505, 168), Vector2(404, 292),
	]
	for i in 150:
		var source: Vector2 = petal_spots[i % petal_spots.size()]
		var x := int(source.x + (_hash01(i, 21, 611) - 0.5) * 145.0)
		var y := int(source.y + 10.0 + _hash01(i, 23, 612) * 112.0)
		if _inb(x, y, W, H):
			var c := C_PETAL_PALE if _hash01(i, 29, 613) > 0.35 else C_ROSE_LIGHT
			_blend(img, x, y, c, 0.72)
			if _hash01(i, 31, 614) > 0.74:
				_blend(img, x + 1, y, c, 0.46)

	# 零星的背景小野花。
	for i in 52:
		var x := int(_hash01(i, 41, 701) * float(W))
		var y := int(_hash01(i, 43, 702) * float(H))
		var c := C_BLOSSOM if _hash01(i, 47, 703) > 0.46 else C_GRASS_GOLD
		_blend(img, x, y, c, 0.68)
		_blend(img, x + 1, y, c, 0.40)
		_blend(img, x, y - 1, Color(0.36, 0.55, 0.27), 0.50)

	return img


# ── 远景树篱 ─────────────────────────────────────────────────────────────
static func _build_hedge() -> Image:
	var img := _img(W, 96)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1701

	# 三层灌木团叠出景深，不再用一条连续色带。
	for i in 17:
		var cx := -20.0 + float(i) * 40.0 + rng.randf_range(-10.0, 10.0)
		var cy := 41.0 + rng.randf_range(-8.0, 8.0)
		var rx := rng.randf_range(30.0, 48.0)
		var ry := rng.randf_range(15.0, 23.0)
		_bush(img, cx, cy, rx, ry, C_HEDGE_DARK, C_HEDGE, 1702 + i)

	for i in 14:
		var cx := -10.0 + float(i) * 47.0 + rng.randf_range(-12.0, 12.0)
		var cy := 59.0 + rng.randf_range(-5.0, 7.0)
		var rx := rng.randf_range(26.0, 42.0)
		var ry := rng.randf_range(13.0, 20.0)
		_bush(img, cx, cy, rx, ry, C_HEDGE, C_HEDGE_LIGHT, 1802 + i)

	for i in 11:
		var cx := float(i) * 62.0 + rng.randf_range(-8.0, 18.0)
		var cy := 75.0 + rng.randf_range(-4.0, 6.0)
		var rx := rng.randf_range(24.0, 38.0)
		var ry := rng.randf_range(10.0, 17.0)
		_bush(img, cx, cy, rx, ry, C_HEDGE_DARK, C_HEDGE, 1902 + i)

	# 远处的两团花树，压低饱和度，避免抢主体。
	for center in [Vector2(104.0, 55.0), Vector2(548.0, 50.0)]:
		for i in 5:
			var dx := (_hash01(i, 3, 2001) - 0.5) * 44.0
			var dy := (_hash01(i, 7, 2002) - 0.5) * 24.0
			var rr := 9.0 + _hash01(i, 11, 2003) * 9.0
			_ellipse(img, center.x + dx, center.y + dy, rr, rr * 0.72,
					Color(0.70, 0.47, 0.56), 0.62)
			_ellipse(img, center.x + dx - 2.0, center.y + dy - 2.0, rr * 0.55,
					rr * 0.38, Color(0.84, 0.62, 0.68), 0.42)

	# 树篱顶部的小叶片高光。
	for i in 260:
		var x := int(_hash01(i, 21, 2101) * float(W))
		var y := int(24.0 + _hash01(i, 23, 2102) * 60.0)
		if _inb(x, y, W, 96) and img.get_pixel(x, y).a > 0.5:
			var c := C_HEDGE_LIGHT if _hash01(i, 27, 2103) > 0.45 else C_HEDGE_DARK
			_put(img, x, y, c)

	return _trim_alpha(img)


static func _bush(img: Image, cx: float, cy: float, rx: float, ry: float,
		dark: Color, light: Color, seed: int) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) - cx) / rx, 2.0) + pow((float(y) - cy) / ry, 2.0)
			var keep := q <= 0.82 or (q <= 1.02 and _hash01(x, y, seed) > 0.42)
			if not keep:
				continue
			var t := (float(y) - (cy - ry)) / (2.0 * ry)
			var c := dark
			if t < 0.38 and _hash01(x, y, seed + 1) > 0.30:
				c = light
			elif t < 0.66 and _hash01(x, y, seed + 2) > 0.55:
				c = dark.lerp(light, 0.45)
			_put(img, x, y, c)


# ── 樱花树 ───────────────────────────────────────────────────────────────
static func _tree_cfg_hero() -> Dictionary:
	return {
		"w": 150, "h": 108, "seed": 1107,
		"trunk_visible": 33, "trunk_w": 52, "trunk_h": 58,
		"clusters": [
			Vector3(70, 16, 19), Vector3(91, 19, 17), Vector3(49, 21, 16),
			Vector3(109, 24, 15), Vector3(33, 31, 16), Vector3(61, 29, 18),
			Vector3(82, 30, 19), Vector3(101, 34, 17), Vector3(120, 38, 13),
			Vector3(21, 44, 13), Vector3(43, 44, 16), Vector3(67, 43, 19),
			Vector3(91, 45, 18), Vector3(113, 47, 15), Vector3(133, 50, 11),
			Vector3(30, 57, 14), Vector3(51, 57, 17), Vector3(75, 56, 20),
			Vector3(99, 58, 17), Vector3(121, 60, 13), Vector3(40, 70, 14),
			Vector3(62, 69, 17), Vector3(87, 70, 17), Vector3(110, 71, 14),
			Vector3(51, 82, 13), Vector3(74, 82, 15), Vector3(97, 82, 13),
			Vector3(62, 93, 10), Vector3(84, 92, 10),
		],
		"cluster_ry": 0.62,
		"branches": [
			[Vector2i(26, 44), Vector2i(12, 15)],
			[Vector2i(28, 38), Vector2i(39, 9)],
			[Vector2i(27, 30), Vector2i(23, 5)],
		],
	}


static func _tree_cfg_right() -> Dictionary:
	return {
		"w": 112, "h": 84, "seed": 2203,
		"trunk_visible": 26, "trunk_w": 40, "trunk_h": 46,
		"clusters": [
			Vector3(52, 14, 15), Vector3(69, 16, 14), Vector3(36, 20, 13),
			Vector3(84, 22, 12), Vector3(24, 28, 12), Vector3(44, 27, 15),
			Vector3(61, 28, 16), Vector3(79, 30, 14), Vector3(96, 33, 11),
			Vector3(16, 38, 10), Vector3(32, 39, 13), Vector3(51, 39, 15),
			Vector3(69, 41, 14), Vector3(86, 43, 12), Vector3(102, 45, 9),
			Vector3(25, 50, 12), Vector3(42, 51, 14), Vector3(60, 51, 15),
			Vector3(78, 52, 13), Vector3(95, 53, 11), Vector3(34, 62, 11),
			Vector3(52, 62, 13), Vector3(71, 63, 12), Vector3(88, 64, 10),
			Vector3(44, 72, 10), Vector3(63, 73, 11), Vector3(79, 73, 9),
		],
		"cluster_ry": 0.62,
		"branches": [
			[Vector2i(20, 34), Vector2i(9, 12)],
			[Vector2i(20, 30), Vector2i(31, 7)],
		],
	}


static func _tree_cfg_sapling() -> Dictionary:
	return {
		"w": 66, "h": 53, "seed": 3301,
		"trunk_visible": 17, "trunk_w": 26, "trunk_h": 31,
		"clusters": [
			Vector3(32, 10, 11), Vector3(44, 12, 10), Vector3(22, 16, 9),
			Vector3(54, 18, 8), Vector3(13, 23, 8), Vector3(31, 22, 11),
			Vector3(47, 24, 10), Vector3(60, 27, 7), Vector3(21, 30, 9),
			Vector3(39, 31, 11), Vector3(54, 33, 8), Vector3(30, 40, 9),
			Vector3(44, 41, 8),
		],
		"cluster_ry": 0.62,
		"branches": [
			[Vector2i(13, 23), Vector2i(5, 8)],
			[Vector2i(13, 19), Vector2i(20, 5)],
		],
	}


static func _build_tree(cfg: Dictionary, seed: int) -> Dictionary:
	var trunk := _build_trunk(cfg, seed + 5)
	var canopy_full := _build_canopy(cfg, seed)
	var canopy := _trim_alpha(canopy_full)
	var crown_shadow := _silhouette(canopy)
	var visible_trunk: int = cfg["trunk_visible"]
	var visual_height := float(visible_trunk + canopy.get_height())
	return {
		"trunk": trunk,
		"canopy": canopy,
		"trunk_visible": visible_trunk,
		"visual_height": visual_height,
		"canopy_w": canopy.get_width(),
		"canopy_h": canopy.get_height(),
		"crown_shadow": crown_shadow,
		"width": cfg["w"],
	}


static func _build_trunk(cfg: Dictionary, seed: int) -> Image:
	var w: int = cfg["trunk_w"]
	var h: int = cfg["trunk_h"]
	var img := _img(w, h)
	var base_x := float(w) * 0.5
	var top_y := 3
	var bottom_y := h - 1

	# 主干：上窄下宽，带 1px 侧弯。
	for y in range(top_y, bottom_y + 1):
		var t := float(y - top_y) / float(maxi(bottom_y - top_y, 1))
		var cx := base_x + sin(t * 2.4) * 1.4
		var half := lerpf(2.8, 6.8, t)
		var x0 := int(round(cx - half))
		var x1 := int(round(cx + half))
		_rect(img, x0 - 1, y, x1 + 1, y, C_OUTLINE)
		_rect(img, x0, y, x1, y, C_TRUNK)
		_put(img, x0, y, C_TRUNK_LIGHT)
		_put(img, x1, y, C_TRUNK_DARK)
		if _hash01(x0, y, seed) > 0.72:
			_put(img, x0 + 1, y, C_TRUNK_DARK)

	# 根部的分叉。
	_rect(img, int(base_x) - 11, bottom_y - 3, int(base_x) - 4, bottom_y, C_OUTLINE)
	_rect(img, int(base_x) - 10, bottom_y - 3, int(base_x) - 5, bottom_y, C_TRUNK_DARK)
	_rect(img, int(base_x) + 4, bottom_y - 3, int(base_x) + 12, bottom_y, C_OUTLINE)
	_rect(img, int(base_x) + 5, bottom_y - 3, int(base_x) + 11, bottom_y, C_TRUNK_DARK)

	# 伸进树冠的枝条（大部分会被树冠盖住）。
	for b in cfg["branches"]:
		var a: Vector2i = b[0]
		var c: Vector2i = b[1]
		_line(img, a, c, C_OUTLINE, 3)
		_line(img, a + Vector2i(0, 1), c + Vector2i(0, 1), C_TRUNK, 1)
		_line(img, a, c, C_TRUNK_LIGHT, 1)

	# 树皮纹理。
	for i in 7:
		var bx := int(_hash01(i, 3, seed) * float(w))
		var by := 12 + int(_hash01(i, 7, seed) * float(h - 22))
		var ln := 2 + int(_hash01(i, 11, seed) * 5.0)
		_rect(img, bx, by, bx, by + ln, C_TRUNK_DARK)

	return _trim_alpha(img)


static func _build_canopy(cfg: Dictionary, seed: int) -> Image:
	var w: int = cfg["w"]
	var h: int = cfg["h"]
	var img := _img(w, h)
	var clusters: Array = cfg["clusters"]
	var ry_scale: float = cfg["cluster_ry"]
	var inside := PackedByteArray()
	inside.resize(w * h)

	# 先画上层的叶簇，再画下层；每个叶簇自己的上亮下暗叠出蓬松的层次。
	# 叶簇刻意做小（rx 9~20），避免几个大椭圆叠成“粉色松饼”。
	var ordered := clusters.duplicate()
	ordered.sort_custom(func(a, b): return float(a.y) < float(b.y))

	for cluster in ordered:
		var cx: float = cluster.x
		var cy: float = cluster.y
		var rx: float = cluster.z
		var ry: float = rx * ry_scale
		var x0 := int(floor(cx - rx - 3.0))
		var x1 := int(ceil(cx + rx + 3.0))
		var y0 := int(floor(cy - ry - 3.0))
		var y1 := int(ceil(cy + ry + 3.0))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				if not _inb(x, y, w, h):
					continue
				var q := pow((float(x) - cx) / rx, 2.0) 						+ pow((float(y) - cy) / ry, 2.0)
				var keep := q <= 0.80
				if not keep and q <= 1.02:
					keep = _hash01(x, y, seed) > 0.40
				if not keep and q <= 1.16:
					keep = _hash01(x, y, seed + 1) > 0.88
				if not keep:
					continue
				var idx := y * w + x
				var local_y := (float(y) - (cy - ry)) / (2.0 * ry)
				local_y = clampf(local_y + (_hash01(x, y, seed + 2) - 0.5) * 0.14,
						0.0, 1.0)
				var c := C_ROSE
				if local_y < 0.22:
					c = C_PETAL_PALE if _hash01(x, y, seed + 3) > 0.55 else C_ROSE_LIGHT
				elif local_y < 0.48:
					c = C_ROSE_LIGHT if _hash01(x, y, seed + 4) > 0.34 else C_ROSE
				elif local_y < 0.76:
					c = C_ROSE
				elif local_y < 0.92:
					c = C_PLUM_DARK
				else:
					c = C_PLUM_DEEP
				if q > 0.94:
					c = c.darkened(0.035)
				_put(img, x, y, c)
				inside[idx] = 1

		# 叶簇顶部的一小片散粉高光。
		if rx > 12.0:
			_ellipse(img, cx - rx * 0.18, cy - ry * 0.50, rx * 0.42, ry * 0.20,
					C_ROSE_LIGHT, 0.34)
			if _hash01(int(cx), int(cy), seed + 5) > 0.50:
				_ellipse(img, cx - rx * 0.26, cy - ry * 0.55, rx * 0.24, ry * 0.12,
						C_PETAL_PALE, 0.28)

	# 大块的白色花团：先找叶簇内部的点，再画小十字/圆瓣。
	var blossoms := 0
	var attempts := 0
	while blossoms < 20 and attempts < 300:
		attempts += 1
		var bx := int(_hash01(attempts, 31, seed + 20) * float(w))
		var by := int((0.06 + _hash01(attempts, 37, seed + 21) * 0.72) * float(h))
		if not _inb(bx, by, w, h) or inside[by * w + bx] == 0:
			continue
		var rr := 1 + int(_hash01(attempts, 41, seed + 22) * 3.0)
		var ok := true
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				var px := bx + dx
				var py := by + dy
				if not _inb(px, py, w, h) or inside[py * w + px] == 0:
					ok = false
		if not ok:
			continue
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if dx * dx + dy * dy > rr * rr + 1:
					continue
				if _hash01(bx + dx, by + dy, seed + 23) < 0.24:
					continue
				_put(img, bx + dx, by + dy,
						C_BLOSSOM if _hash01(bx + dx, by + dy, seed + 24) > 0.55
						else C_PETAL_PALE)
		blossoms += 1

	# 单像素白花，填满花团的空隙。
	for i in 84:
		var bx := int(_hash01(i, 51, seed + 30) * float(w))
		var by := int((0.04 + _hash01(i, 53, seed + 31) * 0.78) * float(h))
		if not _inb(bx, by, w, h) or inside[by * w + bx] == 0:
			continue
		_put(img, bx, by, C_BLOSSOM)
		if _hash01(i, 57, seed + 32) > 0.55:
			_put(img, bx + 1, by, C_PETAL_PALE)
		if _hash01(i, 59, seed + 33) > 0.76:
			_put(img, bx, by + 1, C_PETAL_PALE)

	# 整棵树冠的底缘加深；内部不再画大块暗带。
	for y in h:
		for x in w:
			if inside[y * w + x] == 0:
				continue
			var below_out := y + 1 >= h or inside[(y + 1) * w + x] == 0
			if below_out:
				_put(img, x, y, C_PLUM_DEEP)

	_outline(img, C_OUTLINE)
	return img


# ── 石头 ─────────────────────────────────────────────────────────────────
static func _build_rock(w: int, h: int, seed: int, moss_amount: float) -> Dictionary:
	var img := _img(w, h)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.54
	var rx := float(w) * 0.45
	var ry := float(h) * 0.43

	for y in h:
		for x in w:
			var q := pow((float(x) - cx) / rx, 2.0) + pow((float(y) - cy) / ry, 2.0)
			var keep := false
			if q <= 0.80:
				keep = true
			elif q <= 1.03:
				keep = _hash01(x, y, seed) > 0.34
			elif q <= 1.16:
				keep = _hash01(x, y, seed + 1) > 0.86
			if not keep:
				continue
			var t := float(y) / float(maxi(h - 1, 1))
			var n := _hash01(x, y, seed + 2)
			var c := C_ROCK
			if t < 0.34:
				c = C_ROCK_LIGHT
			elif t > 0.70:
				c = C_ROCK_DARK
			if n < 0.10:
				c = c.lightened(0.06)
			elif n > 0.92:
				c = c.darkened(0.06)
			if x < int(cx) - 3 and t < 0.45 and n > 0.40 and n < 0.40 + 0.28 * moss_amount:
				c = C_MOSS
			_put(img, x, y, c)

	_ellipse(img, cx - rx * 0.20, cy - ry * 0.62, rx * 0.56, ry * 0.24,
			C_MOSS_LIGHT, 0.42 * moss_amount)
	_ellipse(img, cx + rx * 0.30, cy - ry * 0.35, rx * 0.22, ry * 0.13,
			C_ROCK_LIGHT, 0.70)
	# 两块大面：让石头在全局侧光下仍有自己的体块。
	_ellipse(img, cx - rx * 0.28, cy - ry * 0.18, rx * 0.34, ry * 0.30,
			C_ROCK_LIGHT, 0.36)
	_ellipse(img, cx + rx * 0.05, cy + ry * 0.26, rx * 0.42, ry * 0.24,
			C_ROCK_DARK, 0.38)

	for i in 3:
		var ax := int(cx - rx * 0.45 + _hash01(i, 3, seed) * rx * 0.9)
		var ay := int(cy - ry * 0.1 + _hash01(i, 5, seed) * ry * 0.35)
		_line(img, Vector2i(ax, ay), Vector2i(ax + 3 + i, ay + 4 + i),
				C_ROCK_DARK, 1)

	_outline(img, C_OUTLINE)
	var trimmed := _trim_alpha(img)
	return {
		"image": trimmed,
		"shadow": _silhouette(trimmed),
		"width": trimmed.get_width(),
		"height": trimmed.get_height(),
	}


# ── 草 / 花 / 花瓣 ───────────────────────────────────────────────────────
static func _build_tuft() -> Image:
	var img := _img(14, 12)
	var seed := 5501
	for i in 6:
		var x0 := 1.5 + float(i) * 2.15 + _hash01(i, 3, seed) * 0.9
		var hgt := 4 + int(_hash01(i, 7, seed) * 7.0)
		var bend := (_hash01(i, 11, seed) - 0.5) * 2.6
		var phase := _hash01(i, 13, seed) * TAU
		for j in hgt:
			var t := float(j) / float(maxi(hgt - 1, 1))
			var x := int(round(x0 + bend * t + sin(t * 3.0 + phase) * 0.55))
			var y := 10 - j
			var c := C_GRASS
			if j > hgt * 0.55:
				c = C_GRASS_LIGHT
			if j > hgt - 2:
				c = C_GRASS_GOLD
			if j < 2:
				c = C_GRASS_DARK
			_put(img, x, y, c)
			if j == hgt - 1:
				_put(img, x, y, C_GRASS_GOLD)
	# 稀疏根点，不画成横杠。
	if _hash01(3, 1, seed) > 0.40:
		_put(img, 3, 10, C_GRASS_DARK)
	if _hash01(9, 1, seed) > 0.40:
		_put(img, 9, 10, C_GRASS_DARK)
	return img


static func _build_flower() -> Image:
	var img := _img(8, 12)
	var green := Color(0.30, 0.50, 0.25)
	var green_light := Color(0.42, 0.63, 0.31)
	_rect(img, 4, 5, 4, 11, green)
	_put(img, 3, 8, green_light)
	_put(img, 5, 7, green_light)
	_put(img, 3, 4, green_light)
	_put(img, 4, 3, Color(1.00, 0.91, 0.45))
	for p in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(5, 2), Vector2i(6, 3),
			Vector2i(2, 4), Vector2i(6, 4), Vector2i(3, 5), Vector2i(5, 5),
			Vector2i(4, 1)]:
		_put(img, p.x, p.y, C_BLOSSOM)
	_put(img, 1, 6, green_light)
	_put(img, 4, 2, C_PETAL_PALE)
	return img


static func _build_petal() -> Image:
	var img := _img(6, 5)
	var rows := [
		[0, 2, C_PETAL_PALE], [0, 3, C_ROSE_LIGHT],
		[1, 1, C_ROSE_LIGHT], [1, 2, C_BLOSSOM], [1, 3, C_PETAL_PALE],
		[1, 4, C_PETAL_PALE],
		[2, 0, C_ROSE_LIGHT], [2, 1, C_PETAL_PALE], [2, 2, C_PETAL_PALE],
		[2, 3, C_ROSE_LIGHT], [2, 4, C_ROSE_LIGHT], [2, 5, C_ROSE_LIGHT],
		[3, 1, C_ROSE_LIGHT], [3, 2, C_ROSE_LIGHT], [3, 3, C_ROSE_LIGHT],
		[3, 4, C_ROSE_LIGHT],
		[4, 2, C_PLUM_DARK], [4, 3, C_ROSE_LIGHT],
	]
	for p in rows:
		img.set_pixel(int(p[1]), int(p[0]), p[2])
	return img


static func _build_contact() -> Image:
	var img := _img(34, 12)
	for y in 12:
		for x in 34:
			var q := pow((float(x) - 16.5) / 16.0, 2.0) + pow((float(y) - 5.5) / 5.2, 2.0)
			if q > 1.0:
				continue
			var a := pow(1.0 - q, 1.55) * 0.85
			if _hash01(x, y, 8801) < 0.18:
				a *= 0.55
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img


static func _build_trunk_shadow() -> Image:
	var img := _img(20, 64)
	var seed := 9901
	for y in 64:
		var t := float(y) / 63.0
		var half := lerpf(5.6, 3.2, t)
		if t > 0.92:
			half = lerpf(half, 4.2, (t - 0.92) / 0.08)
		var cx := 9.5 + sin(t * 2.0) * 0.8
		for x in range(int(floor(cx - half)), int(ceil(cx + half)) + 1):
			var edge := absf(float(x) - cx) / maxf(half, 0.001)
			var a := 0.95 if edge < 0.55 else 0.62
			if _hash01(x, y, seed) > 0.90:
				a *= 0.65
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return img
