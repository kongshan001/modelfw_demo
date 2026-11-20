class_name Art
extends RefCounted

# 程序化像素美术：所有贴图在运行时用 Image 画出，不依赖外部素材。
# 原创配色与造型，仅用于本项目。

const INK := Color("#1b2430")
const WOOD_D := Color("#5b3a25")
const WOOD_M := Color("#8a5a33")
const WOOD_L := Color("#c0844c")
const WOOD_HI := Color("#e0ab6b")
const NAIL := Color("#efdca8")
const COAT_D := Color("#1f5f5c")
const COAT_M := Color("#2f8b80")
const COAT_L := Color("#57b3a0")
const SKIN := Color("#f0c290")
const SKIN_D := Color("#c98d63")
const HAT := Color("#e7c15e")
const HAT_D := Color("#b8863b")
const CORAL := Color("#d9654a")
const SILVER := Color("#b9d7dd")
const SILVER_D := Color("#6f9aa6")
const WATER := Color("#57b8d9")
const WATER_L := Color("#bfeef2")
const FOAM := Color("#eaf7e3")
const STONE := Color("#59646b")
const COPPER := Color("#c47a4a")

static var _cache: Dictionary = {}


# ── low level ─────────────────────────────────────────────────────────────
static func _img(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)


static func _line(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		_put(img, x0, y0, c)
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


static func _ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for yy in range(-ry, ry + 1):
		var span := int(float(rx) * sqrt(maxf(0.0, 1.0 - pow(float(yy) / float(ry), 2.0))))
		if span <= 0:
			_put(img, cx, cy + yy, c)
		else:
			img.fill_rect(Rect2i(cx - span, cy + yy, span * 2 + 1, 1), c)


# ── world textures ────────────────────────────────────────────────────────
static func wood_tile() -> Texture2D:
	if _cache.has("wood_tile"):
		return _cache["wood_tile"]
	var img := _img(32, 32)
	img.fill(WOOD_M)
	for row in 4:
		var y := row * 8
		var tone := WOOD_M.lerp(WOOD_L, 0.18 + 0.10 * float(row % 2))
		_rect(img, 0, y, 32, 7, tone)
		_rect(img, 0, y + 7, 32, 1, WOOD_D)
		_rect(img, 0, y, 32, 1, tone.lightened(0.08))
		var seam := 8 if row % 2 == 0 else 24
		_rect(img, seam, y, 1, 7, WOOD_D)
		# 木纹
		_rect(img, 3, y + 2, 9, 1, WOOD_D.lerp(tone, 0.55))
		_rect(img, 15 if row % 2 == 0 else 4, y + 4, 12, 1, WOOD_D.lerp(tone, 0.65))
		_put(img, 5, y + 3, NAIL)
		_put(img, 26, y + 3, NAIL)
	# 四角描边，贴到 2m 甲板上像拼板
	var edge := Color(INK, 0.55)
	_rect(img, 0, 0, 32, 1, edge)
	_rect(img, 0, 31, 32, 1, edge)
	_rect(img, 0, 0, 1, 32, edge)
	_rect(img, 31, 0, 1, 32, edge)
	var t := _tex(img)
	_cache["wood_tile"] = t
	return t


static func barrel() -> Texture2D:
	if _cache.has("barrel"):
		return _cache["barrel"]
	var img := _img(26, 30)
	# 轮廓
	_ellipse(img, 13, 7, 9, 4, INK)
	_rect(img, 4, 7, 18, 18, INK)
	_ellipse(img, 13, 25, 9, 4, INK)
	# 桶身
	_rect(img, 5, 7, 16, 18, WOOD_M)
	_ellipse(img, 13, 7, 8, 3, WOOD_D)
	_ellipse(img, 13, 25, 8, 3, WOOD_D)
	for x in range(6, 21, 3):
		_rect(img, x, 8, 1, 16, WOOD_D.lerp(WOOD_M, 0.35))
	# 金属箍
	for yy in [12, 20]:
		_rect(img, 4, yy, 18, 2, STONE)
		_rect(img, 4, yy, 18, 1, STONE.lightened(0.25))
		_put(img, 7, yy, NAIL)
		_put(img, 18, yy, NAIL)
	# 顶盖
	_ellipse(img, 13, 7, 6, 2, WOOD_L)
	_rect(img, 9, 6, 8, 1, WOOD_HI)
	# 红色布条，原创小记号
	_rect(img, 19, 14, 3, 5, CORAL)
	_put(img, 22, 15, CORAL.lightened(0.2))
	_put(img, 19, 19, CORAL.darkened(0.2))
	var t := _tex(img)
	_cache["barrel"] = t
	return t


static func crate() -> Texture2D:
	if _cache.has("crate"):
		return _cache["crate"]
	var img := _img(26, 24)
	_rect(img, 2, 4, 22, 19, INK)
	_rect(img, 3, 5, 20, 17, WOOD_M)
	_rect(img, 3, 5, 20, 4, WOOD_L)
	_rect(img, 3, 9, 20, 1, WOOD_D)
	# X 支撑
	_line(img, 5, 10, 21, 20, WOOD_D)
	_line(img, 6, 10, 22, 20, WOOD_D)
	_line(img, 21, 10, 5, 20, WOOD_D)
	_line(img, 20, 10, 4, 20, WOOD_D)
	# 边框
	_rect(img, 4, 6, 2, 15, WOOD_D)
	_rect(img, 20, 6, 2, 15, WOOD_D)
	_rect(img, 4, 19, 18, 2, WOOD_D)
	# 铆钉与蓝漆
	for p in [Vector2i(5, 7), Vector2i(20, 7), Vector2i(5, 19), Vector2i(20, 19)]:
		_put(img, p.x, p.y, NAIL)
	_rect(img, 11, 12, 4, 3, Color("#4b94a4"))
	_put(img, 12, 11, Color("#79c5d1"))
	var t := _tex(img)
	_cache["crate"] = t
	return t


static func fish() -> Texture2D:
	if _cache.has("fish"):
		return _cache["fish"]
	var img := _img(28, 17)
	# 尾
	_ellipse(img, 5, 8, 4, 5, INK)
	_ellipse(img, 5, 8, 3, 4, SILVER_D)
	# 身
	_ellipse(img, 16, 8, 10, 6, INK)
	_ellipse(img, 16, 8, 9, 5, SILVER)
	# 背/腹
	_rect(img, 10, 3, 11, 2, SILVER_D)
	_rect(img, 12, 12, 8, 2, WATER_L)
	# 鳍
	_line(img, 14, 10, 18, 14, SILVER_D)
	_line(img, 18, 4, 21, 1, SILVER_D)
	# 眼
	_put(img, 22, 7, INK)
	_put(img, 23, 7, Color.WHITE)
	_put(img, 23, 6, Color.WHITE)
	# 青色高光
	_rect(img, 12, 6, 6, 1, WATER_L)
	_put(img, 17, 9, WOOD_HI)
	var t := _tex(img)
	_cache["fish"] = t
	return t


static func cooked_fish() -> Texture2D:
	if _cache.has("cooked_fish"):
		return _cache["cooked_fish"]
	var img := _img(28, 17)
	_ellipse(img, 5, 8, 4, 5, INK)
	_ellipse(img, 5, 8, 3, 4, Color("#9a5b35"))
	_ellipse(img, 16, 8, 10, 6, INK)
	_ellipse(img, 16, 8, 9, 5, Color("#d98c4b"))
	_rect(img, 10, 3, 11, 2, Color("#a35d2e"))
	_rect(img, 12, 12, 8, 2, Color("#f3c46f"))
	_line(img, 11, 6, 15, 10, Color("#7a4326"))
	_line(img, 15, 5, 19, 9, Color("#7a4326"))
	_line(img, 19, 5, 22, 9, Color("#7a4326"))
	_put(img, 22, 7, INK)
	_put(img, 23, 7, Color.WHITE)
	# 热气
	_put(img, 10, 1, Color(1, 1, 1, 0.6))
	_put(img, 12, 0, Color(1, 1, 1, 0.35))
	var t := _tex(img)
	_cache["cooked_fish"] = t
	return t


static func hook() -> Texture2D:
	if _cache.has("hook"):
		return _cache["hook"]
	var img := _img(12, 20)
	_rect(img, 5, 0, 2, 8, Color("#8d724d"))
	_rect(img, 3, 8, 6, 2, STONE)
	_rect(img, 7, 9, 2, 6, INK)
	_rect(img, 4, 14, 6, 2, INK)
	_rect(img, 3, 11, 2, 4, INK)
	_rect(img, 3, 10, 1, 4, SILVER)
	_rect(img, 4, 14, 5, 1, SILVER)
	_put(img, 8, 12, Color.WHITE)
	_put(img, 3, 13, CORAL)
	var t := _tex(img)
	_cache["hook"] = t
	return t


static func shadow() -> Texture2D:
	if _cache.has("shadow"):
		return _cache["shadow"]
	var img := _img(28, 12)
	for yy in 12:
		var f := 1.0 - absf(float(yy) - 5.5) / 6.0
		var span := int(13.0 * sqrt(maxf(0.0, f)))
		if span > 0:
			img.fill_rect(Rect2i(14 - span, yy, span * 2, 1), Color(0.03, 0.09, 0.10, 0.30 * f))
	var t := _tex(img)
	_cache["shadow"] = t
	return t


static func water_ring() -> Texture2D:
	if _cache.has("water_ring"):
		return _cache["water_ring"]
	var img := _img(32, 32)
	for rad in [10.0, 12.5, 15.0]:
		for i in 48:
			var a := TAU * float(i) / 48.0
			_put(img, 16 + int(cos(a) * rad), 16 + int(sin(a) * rad),
				Color(0.86, 0.98, 0.93, 0.35 if rad > 11.0 else 0.55))
	var t := _tex(img)
	_cache["water_ring"] = t
	return t


static func droplet() -> Texture2D:
	if _cache.has("droplet"):
		return _cache["droplet"]
	var img := _img(5, 6)
	_put(img, 2, 0, FOAM)
	_put(img, 1, 1, FOAM)
	_put(img, 3, 1, FOAM)
	_rect(img, 1, 2, 3, 3, FOAM)
	_put(img, 2, 5, WATER_L)
	var t := _tex(img)
	_cache["droplet"] = t
	return t


static func bubble() -> Texture2D:
	if _cache.has("bubble"):
		return _cache["bubble"]
	var img := _img(8, 8)
	for i in 8:
		var a := TAU * float(i) / 8.0
		_put(img, 4 + int(cos(a) * 3.0), 4 + int(sin(a) * 3.0), Color(0.85, 0.98, 0.98, 0.75))
	_put(img, 2, 2, Color(1, 1, 1, 0.95))
	var t := _tex(img)
	_cache["bubble"] = t
	return t


static func flag() -> Texture2D:
	if _cache.has("flag"):
		return _cache["flag"]
	var img := _img(32, 24)
	_rect(img, 0, 0, 32, 24, Color("#2f8b80"))
	_rect(img, 0, 0, 32, 2, Color("#57b3a0"))
	# 原创浪形徽记
	for x in range(6, 27):
		var y := 12 + int(sin(float(x) * 0.55) * 3.0)
		_put(img, x, y, FOAM)
		_put(img, x, y + 1, Color("#bfeef2"))
	_rect(img, 5, 6, 3, 12, CORAL)
	_put(img, 24, 5, HAT)
	_put(img, 25, 5, HAT)
	_put(img, 24, 6, HAT)
	_rect(img, 0, 22, 32, 2, Color("#1f5f5c"))
	var t := _tex(img)
	_cache["flag"] = t
	return t


static func crate_panel() -> Texture2D:
	if _cache.has("crate_panel"):
		return _cache["crate_panel"]
	var img := _img(32, 32)
	img.fill(WOOD_M)
	_rect(img, 0, 0, 32, 4, WOOD_L)
	_rect(img, 0, 28, 32, 4, WOOD_D)
	_rect(img, 0, 0, 4, 32, WOOD_D)
	_rect(img, 28, 0, 4, 32, WOOD_D)
	_line(img, 4, 4, 28, 28, WOOD_D)
	_line(img, 5, 4, 29, 28, WOOD_D)
	_line(img, 28, 4, 4, 28, WOOD_D)
	_line(img, 27, 4, 3, 28, WOOD_D)
	for p in [Vector2i(2, 2), Vector2i(29, 2), Vector2i(2, 29), Vector2i(29, 29)]:
		_put(img, p.x, p.y, NAIL)
	_rect(img, 13, 14, 6, 5, Color("#4b94a4"))
	_put(img, 15, 13, Color("#79c5d1"))
	var t := _tex(img)
	_cache["crate_panel"] = t
	return t


static func ghost_tile() -> Texture2D:
	if _cache.has("ghost_tile"):
		return _cache["ghost_tile"]
	var img := _img(32, 32)
	img.fill(Color(0.55, 1.0, 0.84, 0.22))
	for y in 32:
		for x in 32:
			if (x + y) % 8 < 2:
				img.set_pixel(x, y, Color(0.55, 1.0, 0.84, 0.34))
	_rect(img, 0, 0, 32, 2, Color(0.75, 1.0, 0.9, 0.95))
	_rect(img, 0, 30, 32, 2, Color(0.75, 1.0, 0.9, 0.95))
	_rect(img, 0, 0, 2, 32, Color(0.75, 1.0, 0.9, 0.95))
	_rect(img, 30, 0, 2, 32, Color(0.75, 1.0, 0.9, 0.95))
	var t := _tex(img)
	_cache["ghost_tile"] = t
	return t


static func metal_panel() -> Texture2D:
	if _cache.has("metal_panel"):
		return _cache["metal_panel"]
	var img := _img(32, 32)
	img.fill(Color("#7d8f8f"))
	_rect(img, 0, 0, 32, 3, Color("#a9bcb8"))
	_rect(img, 0, 29, 32, 3, Color("#536666"))
	for i in 4:
		_rect(img, 3 + i * 8, 7, 2, 18, Color("#9fb3ae"))
	_rect(img, 0, 15, 32, 2, Color("#566868"))
	var t := _tex(img)
	_cache["metal_panel"] = t
	return t


# ── character ─────────────────────────────────────────────────────────────
static func fisher_frames() -> Dictionary:
	if _cache.has("fisher"):
		return _cache["fisher"]
	var out := {}
	for dir in 4:
		var frames: Array[Texture2D] = []
		for bob in 2:
			frames.append(_fisher(dir, bob))
		out[dir] = frames
	_cache["fisher"] = out
	return out


static func _fisher(dir: int, bob: int) -> Texture2D:
	var img := _img(28, 36)
	var y := bob
	# 钓竿（在身体后面）
	var rod_a := Vector2i(21, 17 + y)
	var rod_b := Vector2i(26, 4 + y)
	if dir == 1:
		rod_b = Vector2i(1, 6 + y)
	elif dir == 2:
		rod_b = Vector2i(27, 6 + y)
	elif dir == 3:
		rod_b = Vector2i(2, 4 + y)
	_line(img, rod_a.x, rod_a.y, rod_b.x, rod_b.y, INK)
	_line(img, rod_a.x, rod_a.y - 1, rod_b.x, rod_b.y - 1, Color("#8d724d"))
	_put(img, rod_b.x, rod_b.y, NAIL)
	if dir == 0:
		# 卷线器
		_rect(img, 22, 15, 3, 2, STONE)
	# 腿
	for side in [0, 1]:
		_rect(img, 10 + side * 5, 27 + y, 4, 6, INK)
		_rect(img, 10 + side * 5, 30 + y, 5, 3, Color("#3b3a3e"))
		_rect(img, 10 + side * 5, 27 + y, 3, 3, Color("#6c6a64"))
	# 身体（雨披）
	_rect(img, 7, 13 + y, 14, 16, INK)
	_rect(img, 8, 14 + y, 12, 13, COAT_M)
	_rect(img, 8, 14 + y, 12, 3, COAT_L)
	_rect(img, 9, 24 + y, 10, 3, COAT_D)
	# 双臂
	_rect(img, 5, 16 + y, 3, 8, INK)
	_rect(img, 6, 17 + y, 2, 6, COAT_L)
	_rect(img, 21, 15 + y, 3, 8, INK)
	_rect(img, 21, 16 + y, 2, 7, COAT_L)
	_put(img, 22, 22 + y, SKIN)
	_put(img, 6, 22 + y, SKIN)
	# 围巾
	_rect(img, 9, 14 + y, 10, 2, CORAL)
	_put(img, 19, 16 + y, CORAL)
	_put(img, 18, 17 + y, CORAL.darkened(0.2))
	if dir == 1:
		_rect(img, 5, 13 + y, 3, 2, CORAL)
	elif dir == 2:
		_rect(img, 20, 13 + y, 3, 2, CORAL)
	# 头
	_rect(img, 9, 6 + y, 10, 9, INK)
	_rect(img, 10, 7 + y, 8, 7, SKIN)
	_rect(img, 10, 12 + y, 8, 2, SKIN_D)
	# 五官
	if dir == 0:
		_put(img, 12, 9 + y, INK)
		_put(img, 16, 9 + y, INK)
		_put(img, 13, 11 + y, INK)
		_put(img, 14, 11 + y, SKIN_D)
		_put(img, 15, 11 + y, SKIN_D)
	elif dir == 1:
		_put(img, 12, 9 + y, INK)
		_put(img, 16, 9 + y, SKIN_D)
		_put(img, 11, 11 + y, SKIN_D)
	elif dir == 2:
		_put(img, 15, 9 + y, INK)
		_put(img, 11, 9 + y, SKIN_D)
		_put(img, 16, 11 + y, SKIN_D)
	else:
		_rect(img, 11, 8 + y, 6, 3, Color("#7b5437"))
		_put(img, 10, 8 + y, SKIN_D)
	# 草帽
	_rect(img, 4, 4 + y, 20, 3, INK)
	_rect(img, 5, 4 + y, 18, 2, HAT)
	_rect(img, 7, 0 + y, 14, 6, INK)
	_rect(img, 8, 1 + y, 12, 4, HAT)
	_rect(img, 8, 3 + y, 12, 1, HAT_D)
	_rect(img, 7, 0 + y, 4, 1, HAT.lightened(0.15))
	if dir == 1:
		_rect(img, 4, 5 + y, 4, 1, HAT_D)
	elif dir == 2:
		_rect(img, 20, 5 + y, 4, 1, HAT_D)
	return _tex(img)


# ── HUD icons ─────────────────────────────────────────────────────────────
static func glow() -> Texture2D:
	if _cache.has("glow"):
		return _cache["glow"]
	var img := _img(32, 32)
	for y in 32:
		for x in 32:
			var d := Vector2(float(x) - 15.5, float(y) - 15.5).length() / 16.0
			var a := pow(maxf(0.0, 1.0 - d), 2.2)
			if a > 0.01:
				img.set_pixel(x, y, Color(1.0, 0.78, 0.42, a))
	var t := _tex(img)
	_cache["glow"] = t
	return t


static func icon(kind: String) -> Texture2D:
	var key := "icon_" + kind
	if _cache.has(key):
		return _cache[key]
	var img := _img(18, 18)
	match kind:
		"wood":
			_ellipse(img, 7, 11, 5, 4, INK)
			_ellipse(img, 7, 11, 4, 3, WOOD_L)
			_ellipse(img, 7, 11, 2, 2, WOOD_HI)
			_ellipse(img, 12, 7, 4, 3, INK)
			_ellipse(img, 12, 7, 3, 2, WOOD_M)
			_rect(img, 4, 7, 9, 4, WOOD_D)
		"plank":
			_rect(img, 2, 6, 14, 7, INK)
			_rect(img, 3, 7, 12, 5, WOOD_L)
			_rect(img, 3, 7, 12, 1, WOOD_HI)
			_put(img, 5, 10, NAIL)
			_put(img, 13, 10, NAIL)
			_line(img, 6, 8, 12, 8, WOOD_D)
		"fish":
			_ellipse(img, 10, 9, 7, 4, INK)
			_ellipse(img, 10, 9, 6, 3, SILVER)
			_ellipse(img, 4, 9, 2, 3, SILVER_D)
			_put(img, 14, 8, INK)
			_put(img, 8, 7, WATER_L)
		"cooked":
			_ellipse(img, 10, 9, 7, 4, INK)
			_ellipse(img, 10, 9, 6, 3, Color("#d98c4b"))
			_ellipse(img, 4, 9, 2, 3, Color("#9a5b35"))
			_line(img, 7, 7, 9, 11, Color("#7a4326"))
			_line(img, 11, 7, 13, 11, Color("#7a4326"))
			_put(img, 14, 8, INK)
		"water":
			_ellipse(img, 9, 11, 5, 5, INK)
			_ellipse(img, 9, 11, 4, 4, WATER)
			_rect(img, 8, 3, 2, 4, INK)
			_put(img, 8, 4, WATER)
			_put(img, 7, 9, WATER_L)
			_put(img, 8, 8, FOAM)
		"stamina":
			_rect(img, 8, 2, 4, 7, INK)
			_rect(img, 4, 8, 10, 3, INK)
			_rect(img, 5, 9, 8, 1, HAT)
			_rect(img, 8, 1, 2, 8, HAT)
			_rect(img, 5, 11, 4, 4, HAT)
		"storage":
			_rect(img, 2, 4, 14, 12, INK)
			_rect(img, 3, 5, 12, 10, WOOD_M)
			_rect(img, 3, 5, 12, 2, WOOD_L)
			_line(img, 4, 7, 14, 14, WOOD_D)
			_line(img, 14, 7, 4, 14, WOOD_D)
			_put(img, 4, 6, NAIL)
			_put(img, 13, 6, NAIL)
		"purifier":
			_rect(img, 5, 3, 9, 13, INK)
			_rect(img, 6, 4, 7, 11, Color("#4b94a4"))
			_rect(img, 6, 4, 7, 2, WATER_L)
			_rect(img, 3, 2, 13, 3, COPPER)
			_rect(img, 8, 13, 3, 3, COPPER)
			_put(img, 8, 15, WATER)
			_put(img, 9, 16, WATER)
		"grill":
			_rect(img, 2, 7, 14, 3, INK)
			_rect(img, 3, 8, 12, 1, STONE)
			for i in 5:
				_put(img, 3 + i * 3, 7, STONE.lightened(0.2))
			_rect(img, 4, 11, 2, 5, INK)
			_rect(img, 12, 11, 2, 5, INK)
			_rect(img, 5, 12, 3, 2, Color("#e8743b"))
			_rect(img, 9, 13, 3, 2, Color("#e8743b"))
			_put(img, 8, 5, Color("#f3c46f"))
		"expand":
			_rect(img, 2, 2, 6, 6, INK)
			_rect(img, 3, 3, 4, 4, WOOD_L)
			_rect(img, 10, 2, 6, 6, INK)
			_rect(img, 11, 3, 4, 4, WOOD_L)
			_rect(img, 2, 10, 6, 6, INK)
			_rect(img, 3, 11, 4, 4, WOOD_L)
			_rect(img, 10, 10, 6, 6, Color(0.85, 0.98, 0.93, 0.55))
			_rect(img, 11, 11, 4, 4, Color(0.85, 0.98, 0.93, 0.85))
			_line(img, 12, 10, 14, 16, Color("#2f8b80"))
	var tex := _tex(img)
	_cache[key] = tex
	return tex
