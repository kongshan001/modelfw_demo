class_name PixelArt
extends RefCounted

# 原创程序化像素场景（先画 640×360，再按 2× 最近邻放大到 1280×720）：
#   左侧海湾、右上河流与木桥、右下内陆湖、中部石板广场与低洼积水。
# 同时输出下水掩码：
#   R = 主水体（海/河/湖），G = 低洼积水种子，B = 桥面裁切格。
# 所有线条与色块均由固定种子生成，每次重建完全一致。

const BASE_W := 640
const BASE_H := 360
const OUT_W := 1280
const OUT_H := 720
const SEED := 20261126

const BRIDGE_X0 := 484
const BRIDGE_X1 := 522
const BRIDGE_Y0 := 64
const BRIDGE_Y1 := 140

const C_OUTLINE := Color(0.13, 0.17, 0.14)
const C_GRASS := Color(0.33, 0.51, 0.31)
const C_GRASS_D := Color(0.24, 0.41, 0.27)
const C_GRASS_L := Color(0.46, 0.63, 0.38)
const C_GRASS_DRY := Color(0.51, 0.61, 0.34)
const C_SAND := Color(0.84, 0.76, 0.56)
const C_SAND_L := Color(0.92, 0.84, 0.64)
const C_SAND_D := Color(0.71, 0.61, 0.43)
const C_WET := Color(0.57, 0.53, 0.38)
const C_SEA_NEAR := Color(0.55, 0.76, 0.72)
const C_SEA_MID := Color(0.31, 0.57, 0.57)
const C_SEA_DEEP := Color(0.14, 0.34, 0.39)
const C_RIVER_NEAR := Color(0.52, 0.66, 0.55)
const C_RIVER_MID := Color(0.33, 0.49, 0.44)
const C_LAKE_NEAR := Color(0.36, 0.52, 0.45)
const C_LAKE_DEEP := Color(0.19, 0.30, 0.28)
const C_PEBBLE := Color(0.64, 0.65, 0.55)
const C_PEBBLE_D := Color(0.41, 0.45, 0.40)
const C_DIRT := Color(0.56, 0.47, 0.32)
const C_DIRT_D := Color(0.42, 0.35, 0.24)
const C_STONE := Color(0.52, 0.53, 0.48)
const C_STONE_L := Color(0.67, 0.67, 0.58)
const C_STONE_D := Color(0.33, 0.36, 0.33)
const C_WOOD_D := Color(0.28, 0.19, 0.13)
const C_WOOD := Color(0.52, 0.35, 0.22)
const C_WOOD_L := Color(0.67, 0.47, 0.29)
const C_PINE_D := Color(0.12, 0.28, 0.23)
const C_PINE := Color(0.18, 0.39, 0.30)
const C_PINE_L := Color(0.29, 0.50, 0.36)
const C_MAPLE_D := Color(0.48, 0.18, 0.18)
const C_MAPLE := Color(0.68, 0.27, 0.22)
const C_MAPLE_L := Color(0.85, 0.44, 0.29)
const C_WALL := Color(0.82, 0.73, 0.57)
const C_WALL_D := Color(0.63, 0.54, 0.41)
const C_ROOF := Color(0.27, 0.42, 0.42)
const C_ROOF_L := Color(0.37, 0.53, 0.50)
const C_PINK := Color(0.84, 0.47, 0.53)
const C_YELLOW := Color(0.91, 0.78, 0.36)
const C_CREAM := Color(0.93, 0.91, 0.78)
const C_WARM := Color(1.0, 0.75, 0.35)


static func build() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var base_ground := _build_ground()
	var t1 := Time.get_ticks_usec()
	var base_fore := _build_foreground()
	var t2 := Time.get_ticks_usec()
	var base_mask := _build_mask()
	var t3 := Time.get_ticks_usec()
	print("PIXEL_ART_BUILD ground_ms=%d foreground_ms=%d mask_ms=%d" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000])
	var out := {
		"ground": _upscale(base_ground),
		"foreground": _upscale(base_fore),
		"mask": _upscale(base_mask),
		"bridge_rect": bridge_rect(),
		"landmarks": landmarks(),
	}
	return out


static func bridge_rect() -> Rect2:
	return Rect2(BRIDGE_X0 * 2, BRIDGE_Y0 * 2, (BRIDGE_X1 - BRIDGE_X0) * 2, (BRIDGE_Y1 - BRIDGE_Y0) * 2)


static func landmarks() -> Dictionary:
	return {
		"sea": {"pos": Vector2(300, 430), "zoom": 1.75},
		"river": {"pos": Vector2(1004, 232), "zoom": 2.0},
		"lake": {"pos": Vector2(1032, 552), "zoom": 1.9},
		"shallow": {"pos": Vector2(330, 372), "zoom": 2.25},
		"islet": {"pos": Vector2(267, 300), "zoom": 2.4},
		"plaza": {"pos": Vector2(660, 596), "zoom": 1.8},
		"full": {"pos": Vector2(640, 360), "zoom": 1.0},
	}


# ── 地理 ─────────────────────────────────────────────────────────────────
static func _sea_shore(y: float) -> float:
	var shore := 160.0 + 10.0 * sin(y * 0.026 + 0.4) + 5.0 * sin(y * 0.09 + 1.7)
	shore -= 14.0 * exp(-pow((y - 280.0) / 90.0, 2.0))
	shore += 6.0 * exp(-pow((y - 60.0) / 50.0, 2.0))
	return shore


static func _river_points() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(382, -10), Vector2(388, 28), Vector2(402, 55), Vector2(430, 72),
		Vector2(462, 84), Vector2(494, 94), Vector2(526, 105), Vector2(558, 116),
		Vector2(596, 126), Vector2(646, 134),
	])


static func _river_distance(x: float, y: float) -> float:
	var pts := _river_points()
	var best := 9999.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((Vector2(x, y) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var d := Vector2(x, y).distance_to(a + ab * t)
		best = minf(best, d)
	return best


static func _river_halfwidth(y: float) -> float:
	return 26.0 + 2.2 * sin(y * 0.055 + 1.0)


static func _lake_radial(x: float, y: float) -> float:
	var dx := (x - 516.0) / 76.0
	var dy := (y - 276.0) / 58.0
	return sqrt(dx * dx + dy * dy)


static func _in_lake(x: float, y: float) -> bool:
	var dx := x - 516.0
	var dy := y - 276.0
	var ang := atan2(dy, dx)
	var edge := 1.0 + 0.055 * sin(ang * 3.0 + 1.3) + 0.035 * sin(ang * 7.0 - 0.6)
	if _lake_radial(x, y) > edge:
		return false
	if Vector2(x - 496.0, y - 262.0).length() < 7.0:
		return false
	return true


static func _lake_islet(x: float, y: float) -> bool:
	return Vector2(x - 496.0, y - 262.0).length() < 7.0


static func _islet(x: float, y: float) -> bool:
	return Vector2(x - 92.0, y - 120.0).length() < 8.0 \
			or Vector2(x - 70.0, y - 220.0).length() < 5.0 \
			or Vector2(x - 54.0, y - 292.0).length() < 4.0


static func _bridge_footprint(x: float, y: float) -> bool:
	if x < BRIDGE_X0 or x > BRIDGE_X1 or y < BRIDGE_Y0 or y > BRIDGE_Y1:
		return false
	var r := 4.0
	var cx := clampf(x, BRIDGE_X0 + r, BRIDGE_X1 - r)
	var cy := clampf(y, BRIDGE_Y0 + r, BRIDGE_Y1 - r)
	return Vector2(x - cx, y - cy).length() <= r + 0.001


static func _lowland_at(x: float, y: float) -> bool:
	var blobs := [
		Vector4(330, 300, 42, 26), Vector4(312, 318, 20, 12),
		Vector4(357, 292, 16, 11), Vector4(505, 175, 20, 12),
		Vector4(296, 214, 14, 9), Vector4(450, 318, 15, 10),
	]
	var wob := (_vnoise(x * 0.10, y * 0.10, 71) - 0.5) * 0.18
	for b in blobs:
		var q := pow((x - b.x) / b.z, 2.0) + pow((y - b.y) / b.w, 2.0)
		if q + wob < 1.0:
			return true
	return false


static func _water_polygon(x: float, y: float) -> bool:
	if x < _sea_shore(y):
		return not _islet(x, y)
	if _river_distance(x, y) < _river_halfwidth(y):
		return true
	if _in_lake(x, y):
		return true
	return false


static func _is_main_water(x: float, y: float) -> bool:
	return _water_polygon(x, y) and not _bridge_footprint(x, y)


# ── 哈希与噪声 ───────────────────────────────────────────────────────────
static func _hash(x: int, y: int, salt: int) -> float:
	var n := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


static func _vnoise(x: float, y: float, salt: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - float(xi)
	var yf := y - float(yi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := _hash(xi, yi, salt)
	var b := _hash(xi + 1, yi, salt)
	var c := _hash(xi, yi + 1, salt)
	var d := _hash(xi + 1, yi + 1, salt)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


# ── 地表 ─────────────────────────────────────────────────────────────────
static func _build_ground() -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	var paths := [
		PackedVector2Array([Vector2(300, 208), Vector2(318, 252), Vector2(330, 292),
			Vector2(336, 330), Vector2(362, 360)]),
		PackedVector2Array([Vector2(350, 300), Vector2(410, 258), Vector2(462, 210),
			Vector2(496, 166), Vector2(503, 141)]),
		PackedVector2Array([Vector2(376, 322), Vector2(420, 330), Vector2(452, 326)]),
	]
	for y in BASE_H:
		var fy := float(y)
		var shore := _sea_shore(fy)
		for x in BASE_W:
			var fx := float(x)
			var c: Color
			var water := false
			if fx < shore:
				if _islet(fx, fy):
					c = _islet_color(fx, fy)
				else:
					c = _sea_floor(fx, fy, shore)
					water = true
			elif fx < shore + 17.0:
				c = _beach_color(fx, fy, shore)
			else:
				var rd := 9999.0
				if fx >= 350.0 and fy <= 168.0:
					rd = _river_distance(fx, fy)
				if rd < _river_halfwidth(fy):
					c = _river_floor(fx, fy, rd)
					water = true
				elif fx >= 425.0 and fx <= 610.0 and fy >= 200.0 and fy <= 352.0 and _in_lake(fx, fy):
					c = _lake_floor(fx, fy)
					water = true
				elif fx >= 425.0 and fx <= 610.0 and fy >= 200.0 and fy <= 352.0 and _lake_islet(fx, fy):
					c = C_STONE_L
				else:
					c = _grass_color(fx, fy)
			if not water:
				if fx >= 268.0 and fx <= 545.0 and fy >= 130.0:
					var path_d := _path_distance(fx, fy, paths)
					if path_d < 9.0:
						c = _path_color(fx, fy, path_d, true)
					elif path_d < 12.0:
						c = c.lerp(C_DIRT, 0.22)
				if fx >= 270.0 and fx <= 540.0 and fy >= 155.0 and _lowland_at(fx, fy):
					c = c.lerp(C_WET, 0.16)
					if _hash(x, y, 13) > 0.86:
						c = c.darkened(0.05)
			img.set_pixel(x, y, c)
	# 水下大颗鹅卵石与海草，让浅滩透水时读得出来。
	_underwater_details(img)
	_draw_islets(img)
	# 岸上阴影（先铺阴影，再放物体）。
	_draw_shadows(img)
	# 岸上物体。
	_draw_house(img, Vector2(286, 150))
	_draw_pine(img, Vector2(236, 96), 34)
	_draw_pine(img, Vector2(418, 168), 24)
	_draw_maple(img, Vector2(354, 206), 26)
	_draw_bush(img, Vector2(304, 268), 13)
	_draw_bush(img, Vector2(388, 258), 10)
	_draw_bush(img, Vector2(566, 212), 12)
	_draw_rocks(img, Vector2(206, 330), 1.0)
	_draw_rocks(img, Vector2(566, 322), 0.9)
	_draw_rocks(img, Vector2(446, 92), 0.7)
	_draw_rocks(img, Vector2(610, 246), 0.8)
	_draw_lantern(img, Vector2(390, 282))
	_draw_lantern(img, Vector2(456, 118))
	_draw_fence(img, Vector2(392, 276), Vector2(468, 220))
	_draw_flowers(img, Vector2(258, 246), 1.1)
	_draw_flowers(img, Vector2(436, 310), 0.8)
	_draw_flowers(img, Vector2(592, 190), 0.9)
	_draw_flowers(img, Vector2(340, 356), 0.7)
	_draw_pier_posts_ground(img)
	return img


static func _grass_color(x: float, y: float) -> Color:
	var n1 := _vnoise(x * 0.045, y * 0.045, 3)
	var n2 := _vnoise(x * 0.17, y * 0.17, 7)
	var c := C_GRASS.lerp(C_GRASS_D, smoothstep(0.28, 0.72, n1))
	c = c.lerp(C_GRASS_L, smoothstep(0.62, 0.9, n2) * 0.55)
	if n2 > 0.82:
		c = c.lerp(C_GRASS_DRY, 0.5)
	if _hash(int(x), int(y), 21) > 0.965:
		c = c.lerp(C_GRASS_L, 0.7)
	return c


static func _sea_floor(x: float, y: float, shore: float) -> Color:
	var d := shore - x
	var n := _vnoise(x * 0.11, y * 0.11, 11)
	var t := clampf(d / 95.0, 0.0, 1.0)
	var c := C_SEA_NEAR.lerp(C_SEA_MID, smoothstep(0.04, 0.42, t))
	c = c.lerp(C_SEA_DEEP, smoothstep(0.40, 1.0, t))
	c = c.lerp(C_SEA_NEAR, (n - 0.5) * 0.20)
	if d < 8.0:
		c = c.lerp(C_SAND, 0.55)
	if d > 20.0 and d < 27.0 and _hash(int(x), int(y), 31) > 0.965:
		c = C_SEA_NEAR.lightened(0.10)
	return c


static func _islet_color(x: float, y: float) -> Color:
	var d := Vector2(x - 92.0, y - 120.0).length()
	if Vector2(x - 70.0, y - 220.0).length() < 5.0:
		d = Vector2(x - 70.0, y - 220.0).length()
	elif Vector2(x - 54.0, y - 292.0).length() < 4.0:
		d = Vector2(x - 54.0, y - 292.0).length()
	var c := C_STONE
	if d > 5.0:
		c = C_SAND_D
	if d > 6.5:
		c = C_GRASS_D
	if d < 2.2:
		c = C_STONE_L
	return c


static func _beach_color(x: float, y: float, shore: float) -> Color:
	var n := _vnoise(x * 0.16, y * 0.16, 17)
	var c := C_SAND.lerp(C_SAND_L, n)
	var d := x - shore
	if d < 3.0:
		c = C_WET.lerp(C_SAND_D, 0.5)
	elif d < 7.0:
		c = c.lerp(C_WET, 0.35)
	if _hash(int(x), int(y), 23) > 0.955:
		c = C_CREAM
	if _hash(int(x), int(y), 29) > 0.985:
		c = C_SAND_D
	return c


static func _river_floor(x: float, y: float, dist: float) -> Color:
	var hw := _river_halfwidth(y)
	var t := clampf(dist / maxf(hw, 1.0), 0.0, 1.0)
	var c := C_RIVER_NEAR.lerp(C_RIVER_MID, smoothstep(0.15, 0.9, t))
	if t > 0.8:
		c = c.lerp(C_SAND_D, 0.45)
	if _hash(int(x), int(y), 37) > 0.965:
		c = C_PEBBLE
	return c


static func _lake_floor(x: float, y: float) -> Color:
	var r := _lake_radial(x, y)
	var c := C_LAKE_NEAR.lerp(C_LAKE_DEEP, smoothstep(0.15, 0.95, r))
	if _hash(int(x), int(y), 41) > 0.972:
		c = C_PEBBLE_D
	if _hash(int(x), int(y), 43) > 0.992:
		c = C_PEBBLE
	return c


static func _path_distance(x: float, y: float, paths: Array) -> float:
	var best := 9999.0
	for pts in paths:
		for i in range(pts.size() - 1):
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var ab := b - a
			var t := clampf((Vector2(x, y) - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, Vector2(x, y).distance_to(a + ab * t))
	return best


static func _path_color(x: float, y: float, d: float, cobble: bool) -> Color:
	var n := _vnoise(x * 0.28, y * 0.28, 51)
	var c := C_DIRT.lerp(C_DIRT_D, smoothstep(0.3, 0.8, n))
	if cobble and _hash(floori(x / 4.0), floori(y / 4.0), 53) > 0.70:
		c = c.lerp(C_STONE_D, 0.45 + 0.25 * n)
	if d > 7.0:
		c = c.lerp(C_GRASS_D, 0.38)
	return c


static func _underwater_details(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 11
	# 海边浅滩鹅卵石带
	for i in 220:
		var y := rng.randf_range(4.0, 356.0)
		var shore := _sea_shore(y)
		var d := rng.randf_range(5.0, 44.0)
		var x := shore - d
		if x < 3.0 or _islet(x, y):
			continue
		var r := rng.randf_range(0.7, 2.1)
		var col := C_PEBBLE if rng.randf() > 0.45 else C_PEBBLE_D
		if rng.randf() > 0.8:
			col = C_SEA_NEAR.lightened(0.16)
		_ellipse(img, x, y, r * 1.3, r, col)
	# 海草
	for i in 26:
		var y := rng.randf_range(20.0, 340.0)
		var shore := _sea_shore(y)
		var x := shore - rng.randf_range(28.0, 92.0)
		if x < 2.0:
			continue
		for k in 4:
			var xx := x + rng.randf_range(-2.0, 2.0)
			var yy := y + float(k) * 1.6
			_blend(img, int(xx), int(yy), C_PINE_D, 0.55)
	# 河床与湖底
	for i in 110:
		var y := rng.randf_range(4.0, 140.0)
		var cx := 382.0 + y * 0.42
		var x := cx + rng.randf_range(-17.0, 17.0)
		if _river_distance(x, y) > _river_halfwidth(y) - 2.0:
			continue
		_ellipse(img, x, y, rng.randf_range(0.7, 1.8), rng.randf_range(0.5, 1.2),
				C_PEBBLE if rng.randf() > 0.5 else C_PEBBLE_D)
	for i in 70:
		var ang := rng.randf_range(0.0, TAU)
		var rad := sqrt(rng.randf()) * 0.9
		var x := 516.0 + cos(ang) * 76.0 * rad
		var y := 276.0 + sin(ang) * 58.0 * rad
		if not _in_lake(x, y):
			continue
		_ellipse(img, x, y, rng.randf_range(0.6, 1.6), rng.randf_range(0.5, 1.1),
				C_PEBBLE_D if rng.randf() > 0.4 else C_PEBBLE)


static func _draw_islets(img: Image) -> void:
	var islets: Array[Vector4] = [
		Vector4(92, 120, 8, 0), Vector4(70, 220, 5, 0),
		Vector4(54, 292, 4, 0), Vector4(496, 262, 7, 1),
	]
	for island in islets:
		var cx: float = island.x
		var cy: float = island.y
		var r: float = island.z
		var lake: int = int(island.w)
		# 水中的投影与环岛浅沙
		_shadow_ellipse(img, Vector2(cx + 2.0, cy + 2.0), r + 3.0, (r + 3.0) * 0.65, 0.22)
		_ellipse(img, cx, cy, r, r * 0.66, C_OUTLINE)
		_ellipse(img, cx, cy - 0.8, r - 1.0, (r - 1.0) * 0.60, C_SAND_D)
		_ellipse(img, cx, cy - 1.4, r - 2.5, (r - 2.5) * 0.55, C_STONE)
		_ellipse(img, cx - 1.0, cy - 2.4, r - 4.2, (r - 4.2) * 0.48, C_STONE_L)
		_ellipse(img, cx + 1.8, cy + 1.0, r * 0.34, r * 0.22, C_STONE_D)
		if lake == 1:
			for i in 4:
				_blend(img, int(cx - 2 + i), int(cy - 4), C_PINE_L, 0.8)
			_blend(img, int(cx), int(cy - 5), C_PINE, 0.9)
		else:
			_blend(img, int(cx - 2), int(cy - 4), C_CREAM, 0.5)


static func _draw_shadows(img: Image) -> void:
	_shadow_ellipse(img, Vector2(286, 168), 42, 12, 0.20)
	_shadow_ellipse(img, Vector2(236, 112), 30, 10, 0.24)
	_shadow_ellipse(img, Vector2(418, 180), 22, 8, 0.22)
	_shadow_ellipse(img, Vector2(354, 220), 30, 10, 0.24)
	_shadow_ellipse(img, Vector2(390, 292), 16, 5, 0.14)
	_shadow_ellipse(img, Vector2(456, 128), 14, 5, 0.14)
	_shadow_ellipse(img, Vector2(206, 340), 18, 6, 0.20)


static func _draw_house(img: Image, p: Vector2) -> void:
	# 小屋：朝右的墙 + 青瓦坡屋顶，暖窗。
	var wall := Rect2i(int(p.x) - 23, int(p.y) - 12, 46, 28)
	_outline_rect(img, wall, 2)
	_rect(img, Rect2i(wall.position.x + 2, wall.position.y + 2, wall.size.x - 4, wall.size.y - 2), C_WALL)
	_rect(img, Rect2i(wall.position.x + 2, wall.position.y + 16, wall.size.x - 4, 10), C_WALL_D)
	# 屋顶
	var roof := PackedVector2Array([
		p + Vector2(-30, -12), p + Vector2(-18, -26), p + Vector2(28, -26),
		p + Vector2(30, -12),
	])
	_fill_poly(img, roof, C_ROOF)
	_outline_poly(img, roof, C_OUTLINE)
	for i in 5:
		_line(img, p + Vector2(-18 + i * 9, -25), p + Vector2(-18 + i * 9, -13), C_ROOF_L)
	# 门与窗
	_rect(img, Rect2i(int(p.x) - 4, int(p.y) + 1, 9, 14), C_WOOD_D)
	_rect(img, Rect2i(int(p.x) + 9, int(p.y) - 5, 8, 8), C_WARM)
	_rect(img, Rect2i(int(p.x) - 18, int(p.y) - 5, 8, 8), C_WARM)
	_blend_rect(img, Rect2i(int(p.x) + 10, int(p.y) - 4, 6, 6), C_YELLOW, 0.5)
	# 烟囱与草
	_rect(img, Rect2i(int(p.x) + 16, int(p.y) - 30, 5, 10), C_STONE_D)
	for i in 12:
		_blend(img, int(p.x) - 26 + i * 5, int(p.y) + 17 + (i % 2), C_GRASS_D, 0.7)


static func _draw_pine(img: Image, p: Vector2, h: float) -> void:
	var base := p
	_rect(img, Rect2i(int(base.x) - 2, int(base.y) - 4, 4, 12), C_WOOD_D)
	for layer in 4:
		var w := h * (1.0 - float(layer) * 0.20)
		var yy := base.y - 4.0 - float(layer) * (h * 0.24)
		var tri := PackedVector2Array([
			Vector2(base.x - w * 0.5, yy),
			Vector2(base.x, yy - h * 0.46),
			Vector2(base.x + w * 0.5, yy),
		])
		_fill_poly(img, tri, C_PINE_D)
		var tri2 := PackedVector2Array([
			Vector2(base.x - w * 0.30, yy - 2.0),
			Vector2(base.x, yy - h * 0.42),
			Vector2(base.x + w * 0.16, yy - 3.0),
		])
		_fill_poly(img, tri2, C_PINE)
		for i in 4:
			var fx := base.x - w * 0.24 + float(i) * w * 0.14
			_blend(img, int(fx), int(yy - 4.0 - float(i % 2) * 3.0), C_PINE_L, 0.75)


static func _draw_maple(img: Image, p: Vector2, r: float) -> void:
	_rect(img, Rect2i(int(p.x) - 3, int(p.y) + 4, 6, 18), C_WOOD_D)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 31
	for i in 15:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.0, r * 0.8)
		var cx := p.x + cos(a) * d
		var cy := p.y - r * 0.5 + sin(a) * d * 0.7
		var rr := rng.randf_range(r * 0.24, r * 0.42)
		var col := C_MAPLE if rng.randf() > 0.45 else C_MAPLE_D
		_ellipse(img, cx, cy, rr * 1.1, rr, col)
	for i in 22:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(0.0, r * 0.8)
		var cx := int(p.x + cos(a) * d)
		var cy := int(p.y - r * 0.5 + sin(a) * d * 0.7 - 2.0)
		_blend(img, cx, cy, C_MAPLE_L, 0.8)


static func _draw_bush(img: Image, p: Vector2, r: float) -> void:
	_ellipse(img, p.x, p.y, r, r * 0.75, C_PINE_D)
	_ellipse(img, p.x - r * 0.25, p.y - r * 0.2, r * 0.65, r * 0.5, C_PINE)
	for i in 7:
		_blend(img, int(p.x - r + i * r * 0.3), int(p.y - r * 0.5), C_PINE_L, 0.65)


static func _draw_flowers(img: Image, p: Vector2, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(p.x * 3 + p.y * 7)
	for i in 17:
		var x := p.x + rng.randf_range(-18.0, 18.0) * scale
		var y := p.y + rng.randf_range(-11.0, 11.0) * scale
		var c := C_PINK if rng.randf() > 0.42 else C_YELLOW
		if rng.randf() > 0.86:
			c = C_CREAM
		_blend(img, int(x), int(y), C_GRASS_D, 0.6)
		_blend(img, int(x), int(y - 1), c, 0.9)
		if rng.randf() > 0.55:
			_blend(img, int(x + 1), int(y - 1), c, 0.6)


static func _draw_rocks(img: Image, p: Vector2, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(p.x * 5 + p.y * 11)
	for i in 5:
		var cx := p.x + rng.randf_range(-8.0, 8.0) * scale
		var cy := p.y + rng.randf_range(-4.0, 4.0) * scale
		var rx := rng.randf_range(2.5, 6.0) * scale
		var ry := rx * rng.randf_range(0.55, 0.85)
		_ellipse(img, cx, cy, rx, ry, C_STONE_D)
		_ellipse(img, cx - rx * 0.18, cy - ry * 0.22, rx * 0.75, ry * 0.6, C_STONE)
		_ellipse(img, cx - rx * 0.30, cy - ry * 0.32, rx * 0.35, ry * 0.3, C_STONE_L)


static func _draw_lantern(img: Image, p: Vector2) -> void:
	_ellipse(img, p.x, p.y + 4, 10, 5, C_STONE_D)
	_rect(img, Rect2i(int(p.x) - 2, int(p.y) - 12, 4, 16), C_STONE)
	_rect(img, Rect2i(int(p.x) - 5, int(p.y) - 15, 10, 4), C_STONE_L)
	_rect(img, Rect2i(int(p.x) - 4, int(p.y) - 20, 8, 6), C_WARM)
	_rect(img, Rect2i(int(p.x) - 7, int(p.y) - 23, 14, 4), C_STONE_D)
	_rect(img, Rect2i(int(p.x) - 1, int(p.y) - 28, 2, 5), C_STONE_L)
	_blend_rect(img, Rect2i(int(p.x) - 10, int(p.y) - 20, 20, 16), C_WARM, 0.08)


static func _draw_fence(img: Image, a: Vector2, b: Vector2) -> void:
	var n := 7
	for i in n:
		var t := float(i) / float(n - 1)
		var p := a.lerp(b, t)
		_rect(img, Rect2i(int(p.x) - 1, int(p.y) - 9, 3, 13), C_WOOD_D)
		_rect(img, Rect2i(int(p.x), int(p.y) - 9, 1, 12), C_WOOD)
	for i in n - 1:
		var p0 := a.lerp(b, float(i) / float(n - 1))
		var p1 := a.lerp(b, float(i + 1) / float(n - 1))
		_line(img, p0 + Vector2(0, -6), p1 + Vector2(0, -6), C_WOOD)
		_line(img, p0 + Vector2(0, -2), p1 + Vector2(0, -2), C_WOOD_D)


static func _draw_pier_posts_ground(img: Image) -> void:
	# 栈桥在水下的桩影（像素块），让前景栈桥落地。
	for i in 3:
		_blend(img, 136 + i * 13, 296, C_WOOD_D, 0.30)
		_blend(img, 137 + i * 13, 297, C_WOOD_D, 0.20)


# ── 前景（桥 / 栈桥 / 芦苇 / 睡莲 / 小船） ───────────────────────────────
static func _build_foreground() -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 桥的落影很窄，只沿桥缘压一圈，避免整块半透明面板压在水面上。
	_blend_rect(img, Rect2i(BRIDGE_X0 + 3, BRIDGE_Y0 + 4,
			BRIDGE_X1 - BRIDGE_X0 + 2, BRIDGE_Y1 - BRIDGE_Y0 + 3), C_OUTLINE, 0.16)
	_blend_rect(img, Rect2i(BRIDGE_X1, BRIDGE_Y0 + 6, 3, BRIDGE_Y1 - BRIDGE_Y0 - 2), C_OUTLINE, 0.13)
	_blend_rect(img, Rect2i(BRIDGE_X0 + 2, BRIDGE_Y1, BRIDGE_X1 - BRIDGE_X0 - 2, 3), C_OUTLINE, 0.13)
	_draw_bridge(img)
	_draw_pier(img)
	_draw_lily_pads(img)
	_draw_reeds(img, Vector2(176, 232), 1.0)
	_draw_reeds(img, Vector2(188, 306), 1.1)
	_draw_reeds(img, Vector2(430, 52), 0.8)
	_draw_reeds(img, Vector2(472, 334), 0.9)
	_draw_reeds(img, Vector2(576, 330), 0.8)
	return img


static func _draw_bridge(img: Image) -> void:
	var x0 := BRIDGE_X0
	var y0 := BRIDGE_Y0
	var x1 := BRIDGE_X1
	var y1 := BRIDGE_Y1
	# 桥面木板
	for y in range(y0, y1 + 1):
		var plank := int((y - y0) / 5)
		var c := C_WOOD if (plank % 2) == 0 else Color(0.47, 0.31, 0.20)
		c = c.lerp(C_WOOD_L, 0.12 * _hash(3, y, 61))
		for x in range(x0, x1 + 1):
			img.set_pixel(x, y, c)
		_line(img, Vector2(x0 + 2, y), Vector2(x1 - 2, y), C_WOOD_D if (y % 5) == 0 else c)
	# 边缘栏杆立柱/扶手
	for x in [x0 + 1, x0 + 3, x1 - 2, x1 - 4]:
		for y in range(y0 + 2, y1 - 1):
			_blend(img, x, y, C_WOOD_D, 0.72)
	for i in 4:
		var y := y0 + 3 + i * 24
		_rect(img, Rect2i(x0, y - 1, 6, 5), C_WOOD_D)
		_rect(img, Rect2i(x1 - 5, y - 1, 6, 5), C_WOOD_D)
		_rect(img, Rect2i(x0 + 1, y, 3, 2), C_WOOD_L)
		_rect(img, Rect2i(x1 - 4, y, 3, 2), C_WOOD_L)
	for i in 2:
		var y := y0 + 18 + i * 34
		_rect(img, Rect2i(x0 - 2, y - 10, 4, 20), C_WOOD_D)
		_rect(img, Rect2i(x1 - 2, y - 10, 4, 20), C_WOOD_D)
	# 顶部与底部横梁
	_rect(img, Rect2i(x0 - 2, y0 - 2, x1 - x0 + 4, 3), C_WOOD_D)
	_rect(img, Rect2i(x0 - 2, y1, x1 - x0 + 4, 3), C_WOOD_D)
	_outline_rect(img, Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), 1)
	# 栏杆高光
	_line(img, Vector2(x0 + 1, y0 + 4), Vector2(x0 + 1, y1 - 4), C_WOOD_L)
	_line(img, Vector2(x1 - 1, y0 + 4), Vector2(x1 - 1, y1 - 4), C_WOOD_L)


static func _draw_pier(img: Image) -> void:
	var y0 := 286
	var y1 := 300
	# 栈桥影子
	_blend_rect(img, Rect2i(108, y0 + 5, 58, y1 - y0 + 2), C_OUTLINE, 0.22)
	for x in range(108, 160):
		var plank := int((x - 108) / 5)
		var c := C_WOOD_D if (plank % 2) == 0 else C_WOOD
		for y in range(y0, y1):
			img.set_pixel(x, y, c)
		_line(img, Vector2(x, y0), Vector2(x, y1 - 1), C_WOOD_D if (x % 5) == 0 else c)
	# 桩
	for x in [110, 126, 142, 157]:
		_rect(img, Rect2i(x, y1 - 1, 3, 8), C_WOOD_D)
		_rect(img, Rect2i(x, y1 - 1, 1, 7), C_WOOD)
	for x in [111, 127, 143, 158]:
		_blend(img, x, y1 + 7, C_OUTLINE, 0.35)
	# 栏杆
	_line(img, Vector2(108, y0 + 1), Vector2(159, y0 + 1), C_WOOD_L)
	for x in [112, 132, 152]:
		_rect(img, Rect2i(x, y0 - 4, 2, 5), C_WOOD_D)
	# 系船柱与小船
	_rect(img, Rect2i(156, 278, 3, 8), C_WOOD_D)
	_draw_boat(img, Vector2(112, 262))


static func _draw_boat(img: Image, p: Vector2) -> void:
	var hull := PackedVector2Array([
		p + Vector2(-12, 0), p + Vector2(-8, 6), p + Vector2(8, 6),
		p + Vector2(13, 0), p + Vector2(9, 2), p + Vector2(-8, 2),
	])
	_fill_poly(img, hull, C_WOOD_D)
	_fill_poly(img, PackedVector2Array([
		p + Vector2(-12, 0), p + Vector2(-8, 6), p + Vector2(8, 6),
		p + Vector2(13, 0),
	]), C_WOOD)
	_line(img, p + Vector2(-10, 1), p + Vector2(11, 1), C_WOOD_L)
	_line(img, p + Vector2(4, 2), p + Vector2(-4, 5), C_WOOD_D)
	# 船桨
	_line(img, p + Vector2(-6, 4), p + Vector2(-16, 11), C_WOOD_L)
	_line(img, p + Vector2(-16, 11), p + Vector2(-20, 10), C_WOOD_D)
	# 船在浅水上的暗影
	_blend_rect(img, Rect2i(int(p.x) - 13, int(p.y) + 6, 27, 3), C_SEA_DEEP, 0.16)


static func _draw_lily_pads(img: Image) -> void:
	var pads: Array[Vector3] = [
		Vector3(470, 290, 7), Vector3(545, 264, 8), Vector3(574, 300, 6),
		Vector3(500, 320, 5), Vector3(561, 282, 4), Vector3(452, 266, 5),
	]
	for pad in pads:
		var cx: float = pad.x
		var cy: float = pad.y
		var r: float = pad.z
		_ellipse(img, cx, cy, r, r * 0.66, C_PINE_D)
		_ellipse(img, cx, cy - 0.6, r * 0.78, r * 0.5, C_PINE)
		_line(img, Vector2(cx, cy), Vector2(cx + r * 0.8, cy + r * 0.1), C_PINE_D)
		_blend(img, int(cx - r * 0.3), int(cy - r * 0.2), C_PINE_L, 0.7)
	# 两朵睡莲
	for p in [Vector2(470, 286), Vector2(548, 261)]:
		for i in 5:
			var a := -PI * 0.5 + (float(i) - 2.0) * 0.28
			_ellipse(img, p.x + cos(a) * 2.4, p.y + sin(a) * 2.4, 2.0, 1.4,
					C_PINK if i % 2 == 0 else C_CREAM)
		_blend(img, int(p.x), int(p.y), C_YELLOW, 0.9)


static func _draw_reeds(img: Image, p: Vector2, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(p.x * 7 + p.y * 13)
	for i in 9:
		var x := p.x + rng.randf_range(-9.0, 9.0) * scale
		var h := rng.randf_range(9.0, 22.0) * scale
		var lean := rng.randf_range(-3.0, 3.0)
		_line(img, Vector2(x, p.y), Vector2(x + lean, p.y - h), C_PINE_D)
		_line(img, Vector2(x + 1, p.y - h * 0.25), Vector2(x + lean + 1, p.y - h * 0.9), C_PINE_L)
		if rng.randf() > 0.6:
			_ellipse(img, x + lean, p.y - h - 1.0, 1.3, 3.0, C_WOOD_D)


# ── 掩码 ─────────────────────────────────────────────────────────────────
static func _build_mask() -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in BASE_H:
		var fy := float(y)
		var shore := _sea_shore(fy)
		for x in BASE_W:
			var fx := float(x)
			var wet := false
			if fx < shore:
				wet = not _islet(fx, fy)
			elif fx >= 350.0 and fx <= 646.0 and fy <= 168.0:
				wet = _river_distance(fx, fy) < _river_halfwidth(fy)
			elif fx >= 430.0 and fx <= 600.0 and fy >= 205.0 and fy <= 348.0:
				wet = _in_lake(fx, fy)
			var bridge := false
			if fx >= BRIDGE_X0 - 1 and fx <= BRIDGE_X1 + 1 and fy >= BRIDGE_Y0 - 1 and fy <= BRIDGE_Y1 + 1:
				bridge = _bridge_footprint(fx, fy)
			var water := wet and not bridge
			var low := false
			if fx >= 270.0 and fx <= 540.0 and fy >= 155.0 and not bridge and not wet:
				low = _lowland_at(fx, fy)
			# A = 桥下水体（能否连通），R = 实际绘制水体（桥面挖空）。
			img.set_pixel(x, y, Color(1.0 if water else 0.0,
					1.0 if low else 0.0, 1.0 if bridge else 0.0,
					1.0 if wet else 0.0))
	return img


# ── 画图工具 ─────────────────────────────────────────────────────────────
static func _upscale(src: Image) -> Image:
	var out := src.duplicate()
	out.resize(OUT_W, OUT_H, Image.INTERPOLATE_NEAREST)
	return out


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var bg := img.get_pixel(x, y)
	img.set_pixel(x, y, bg.lerp(c, clampf(a, 0.0, 1.0)))


static func _blend_rect(img: Image, r: Rect2i, c: Color, a: float) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_blend(img, x, y, c, a)


static func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			_put(img, x, y, c)


static func _outline_rect(img: Image, r: Rect2i, w: int) -> void:
	for i in w:
		_line(img, Vector2(r.position.x - i, r.position.y - i),
				Vector2(r.position.x + r.size.x + i, r.position.y - i), C_OUTLINE)
		_line(img, Vector2(r.position.x - i, r.position.y + r.size.y + i),
				Vector2(r.position.x + r.size.x + i, r.position.y + r.size.y + i), C_OUTLINE)
		_line(img, Vector2(r.position.x - i, r.position.y - i),
				Vector2(r.position.x - i, r.position.y + r.size.y + i), C_OUTLINE)
		_line(img, Vector2(r.position.x + r.size.x + i, r.position.y - i),
				Vector2(r.position.x + r.size.x + i, r.position.y + r.size.y + i), C_OUTLINE)


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	var x0 := floori(cx - rx)
	var x1 := ceili(cx + rx)
	var y0 := floori(cy - ry)
	var y1 := ceili(cy + ry)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) + 0.5 - cx) / maxf(rx, 0.1), 2.0) \
					+ pow((float(y) + 0.5 - cy) / maxf(ry, 0.1), 2.0)
			if q <= 1.0:
				_put(img, x, y, c)


static func _shadow_ellipse(img: Image, c: Vector2, rx: float, ry: float, a: float) -> void:
	var x0 := floori(c.x - rx)
	var x1 := ceili(c.x + rx)
	var y0 := floori(c.y - ry)
	var y1 := ceili(c.y + ry)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) + 0.5 - c.x) / rx, 2.0) + pow((float(y) + 0.5 - c.y) / ry, 2.0)
			if q <= 1.0:
				_blend(img, x, y, C_OUTLINE, a * (1.0 - q * 0.5))


static func _fill_poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	var min_y := 1e9
	var max_y := -1e9
	for p in pts:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(floori(min_y), ceili(max_y) + 1):
		var xs: Array[float] = []
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= float(y) and b.y > float(y)) or (b.y <= float(y) and a.y > float(y)):
				var t := (float(y) - a.y) / (b.y - a.y)
				xs.append(a.x + t * (b.x - a.x))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			for x in range(floori(xs[i]), ceili(xs[i + 1])):
				_put(img, x, y, c)


static func _outline_poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	for i in pts.size():
		_line(img, pts[i], pts[(i + 1) % pts.size()], c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var dx := b.x - a.x
	var dy := b.y - a.y
	var steps := int(maxf(absf(dx), absf(dy)))
	if steps == 0:
		_put(img, floori(a.x), floori(a.y), c)
		return
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		_put(img, floori(a.x + dx * t), floori(a.y + dy * t), c)
