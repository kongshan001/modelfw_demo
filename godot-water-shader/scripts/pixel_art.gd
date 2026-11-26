class_name PixelArt
extends RefCounted

# 原创程序化像素场景（先画 640×360，再按 2× 最近邻放大到 1280×720）：
#   左侧海湾、右上河流与木桥、右下内陆湖、中部石板广场与低洼积水。
# 视觉整改（T-20261126-005，brief = docs/art-review-T-20261126-004.md）：
#   - 统一右上光 (0.55,-0.83)，所有贴地物有左下投影 + 2–3px 接触影；
#   - 水下沙底/鹅卵石/海草成为真实材质，水面 shader 按深度透出；
#   - 岸线湿沙带 8–12 逻辑 px（4–6 base px）、水线暗线由 shader 叠加；
#   - 3/4 俯视房屋、桥栏杆/湿木/桥影、俯视小船、放射状芦苇簇、睡莲成组；
#   - 新增 reflections 图层（桥/船/礁石/芦苇的静态风格化倒影）。
# 输出：
#   ground / foreground / mask / reflections / reeds(簇) / bridge_rect / landmarks

const BASE_W := 640
const BASE_H := 360
const OUT_W := 1280
const OUT_H := 720
const SEED := 20261126

const BRIDGE_X0 := 484
const BRIDGE_X1 := 522
const BRIDGE_Y0 := 64
const BRIDGE_Y1 := 140

# ── 色板（brief 6.1 / 6.7 / 6.8；全部 sRGB） ─────────────────────────────
const C_OUTLINE := Color8(30, 44, 40)
const C_SHADOW := Color8(30, 58, 54)          # #1E3A36
const C_GRASS_D := Color8(47, 90, 68)         # #2F5A44
const C_GRASS_M := Color8(63, 107, 69)        # #3F6B45
const C_GRASS := Color8(86, 127, 75)          # #567F4B
const C_GRASS_L := Color8(127, 160, 92)       # #7FA05C
const C_GRASS_LL := Color8(163, 179, 107)     # #A3B36B
const C_GRASS_DRY := Color8(139, 144, 84)
const C_SAND := Color8(232, 217, 172)         # #E8D9AC
const C_SAND_L := Color8(245, 233, 192)       # #F5E9C0
const C_SAND_D := Color8(201, 181, 126)       # #C9B57E
const C_SAND_UW := Color8(191, 168, 120)      # 水下沙底（略暗于干沙）
const C_WET := Color8(168, 150, 112)          # #A89670
const C_WET_D := Color8(130, 117, 90)         # #82755A
const C_SILT := Color8(104, 122, 101)         # #687A65
const C_SILT_D := Color8(63, 88, 79)          # #3F584F
const C_PEBBLE := Color8(164, 168, 142)       # #A4A88E
const C_PEBBLE_D := Color8(111, 118, 99)      # #6F7663
const C_PEBBLE_L := Color8(196, 198, 172)
const C_DIRT := Color8(139, 117, 80)          # #8B7550
const C_DIRT_L := Color8(180, 154, 110)       # #B49A6E
const C_DIRT_D := Color8(94, 81, 56)          # #5E5138
const C_GRAVEL := Color8(110, 106, 88)        # #6E6A58
const C_STONE := Color8(140, 138, 114)        # #8C8A72
const C_STONE_D := Color8(111, 107, 88)       # #6F6B58
const C_STONE_L := Color8(180, 176, 152)      # #B4B098
const C_WOOD_D := Color8(58, 42, 28)          # #3A2A1C
const C_WOOD := Color8(104, 69, 43)           # #68452B
const C_WOOD_M := Color8(122, 81, 52)         # #7A5134
const C_WOOD_L := Color8(154, 107, 73)        # #9A6B49
const C_WOOD_WET := Color8(74, 52, 35)
const C_PINE_D := Color8(31, 69, 56)
const C_PINE := Color8(46, 92, 71)
const C_PINE_L := Color8(74, 122, 88)
const C_MAPLE_D := Color8(122, 46, 40)
const C_MAPLE := Color8(166, 65, 48)
const C_MAPLE_L := Color8(208, 108, 66)
const C_WALL := Color8(214, 195, 158)
const C_WALL_D := Color8(166, 143, 108)
const C_ROOF_D := Color8(43, 71, 71)          # #2B4747
const C_ROOF := Color8(63, 100, 100)          # #3F6464
const C_ROOF_L := Color8(90, 127, 119)        # #5A7F77
const C_PINK := Color8(214, 120, 135)
const C_YELLOW := Color8(232, 199, 92)
const C_CREAM := Color8(237, 232, 199)
const C_WARM := Color8(255, 210, 122)         # #FFD27A
const C_LILY_D := Color8(52, 104, 74)
const C_LILY := Color8(91, 148, 96)
const C_LILY_L := Color8(144, 184, 126)
const C_FOAM := Color8(232, 242, 222)         # #E8F2DE
const C_FOAM_WASH := Color8(156, 205, 189)    # #9CCDBD
const C_WATERLINE := Color8(43, 74, 69)       # #2B4A45

const REED_W := 40
const REED_H := 36
const REED_BASE := Vector2(20, 34)


static func build() -> Dictionary:
	var t0 := Time.get_ticks_usec()
	var base_ground := _build_ground()
	var t1 := Time.get_ticks_usec()
	var base_fore := _build_foreground()
	var t2 := Time.get_ticks_usec()
	var base_mask := _build_mask()
	var t3 := Time.get_ticks_usec()
	var reed_clusters := _build_reeds()
	var base_refl := _build_reflections(reed_clusters)
	var base_shore := _build_shore_overlay(base_mask)
	var t4 := Time.get_ticks_usec()
	print("PIXEL_ART_BUILD ground_ms=%d foreground_ms=%d mask_ms=%d shore_ms=%d refl_ms=%d" % [
		(t1 - t0) / 1000, (t2 - t1) / 1000, (t3 - t2) / 1000, (t4 - t3) / 1000,
		Time.get_ticks_usec() - t4])
	var reeds: Array = []
	for c in reed_clusters:
		reeds.append({
			"pos": Vector2(c["base"].x * 2.0, c["base"].y * 2.0),
			"image": _double(c["image"]),
			"anchor": REED_BASE * 2.0,
			"phase": c["phase"],
		})
	return {
		"ground": _upscale(base_ground),
		"foreground": _upscale(base_fore),
		"mask": _upscale(base_mask),
		"reflections": _upscale(base_refl),
		"shore": _upscale(base_shore),
		"reeds": reeds,
		"bridge_rect": bridge_rect(),
		"landmarks": landmarks(),
	}


static func bridge_rect() -> Rect2:
	return Rect2(BRIDGE_X0 * 2, BRIDGE_Y0 * 2, (BRIDGE_X1 - BRIDGE_X0) * 2, (BRIDGE_Y1 - BRIDGE_Y0) * 2)


static func landmarks() -> Dictionary:
	return {
		"sea": {"pos": Vector2(300, 430), "zoom": 1.75},
		"river": {"pos": Vector2(1000, 230), "zoom": 1.90},
		"lake": {"pos": Vector2(860, 460), "zoom": 1.60},
		"shallow": {"pos": Vector2(330, 372), "zoom": 2.25},
		"islet": {"pos": Vector2(267, 300), "zoom": 2.40},
		"plaza": {"pos": Vector2(660, 596), "zoom": 1.80},
		"full": {"pos": Vector2(640, 360), "zoom": 1.00},
		# hero 机位（带边界夹取；lake/bridge 靠右，靠右构图）
		"hero_shore": {"pos": Vector2(420, 420), "zoom": 1.70},
		"hero_bridge": {"pos": Vector2(900, 300), "zoom": 1.70},
		"hero_lake": {"pos": Vector2(866, 468), "zoom": 1.55},
		"hero_rain": {"pos": Vector2(640, 360), "zoom": 1.00},
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
				# 河岸/湖岸湿土带（陆侧 2–6 base px）。
				if fy <= 175.0 and fx >= 345.0:
					var rbank := _river_distance(fx, fy) - _river_halfwidth(fy)
					if rbank < 6.0:
						c = c.lerp(C_WET_D, (1.0 - smoothstep(0.5, 6.0, rbank)) * 0.55)
				if fx >= 430.0 and fx <= 605.0 and fy >= 205.0 and fy <= 350.0:
					var lbank := (_lake_radial(fx, fy) - 1.0) * 58.0
					if lbank < 7.0:
						c = c.lerp(C_WET_D, (1.0 - smoothstep(0.5, 7.0, lbank)) * 0.50)
				if fx >= 268.0 and fx <= 545.0 and fy >= 130.0:
					var path_d := _path_distance(fx, fy, paths)
					if path_d < 10.5:
						c = _path_color(fx, fy, path_d, true)
					elif path_d < 14.0:
						c = c.lerp(C_DIRT, 0.18)
						# 小路左下投影
						c = c.lerp(C_GRASS_D, 0.22)
				if fx >= 270.0 and fx <= 540.0 and fy >= 155.0 and _lowland_at(fx, fy):
					c = c.lerp(C_WET, 0.16)
					if _hash(x, y, 13) > 0.86:
						c = c.darkened(0.05)
			img.set_pixel(x, y, c)
	# 水下细节（沙纹/鹅卵石/海草）与岸上细节。
	_underwater_details(img)
	_draw_islets(img)
	_draw_beach_details(img)
	# 阴影在下，物体在上。
	_draw_shadows(img)
	_draw_house(img, Vector2(286, 150))
	_draw_pine(img, Vector2(236, 96), 34)
	_draw_pine(img, Vector2(418, 168), 24)
	_draw_maple(img, Vector2(354, 206), 26)
	_draw_bush(img, Vector2(304, 268), 13)
	_draw_bush(img, Vector2(388, 258), 10)
	_draw_bush(img, Vector2(566, 212), 12)
	_draw_bush(img, Vector2(336, 338), 9)
	_draw_rocks(img, Vector2(206, 330), 1.0)
	_draw_rocks(img, Vector2(566, 322), 0.9)
	_draw_rocks(img, Vector2(446, 92), 0.7)
	_draw_rocks(img, Vector2(610, 246), 0.8)
	_draw_lantern(img, Vector2(390, 282))
	_draw_lantern(img, Vector2(456, 118))
	_draw_fence(img, Vector2(392, 276), Vector2(468, 220))
	_draw_stone_wall(img)
	_draw_flowers(img, Vector2(258, 246), 1.1)
	_draw_flowers(img, Vector2(436, 310), 0.8)
	_draw_flowers(img, Vector2(592, 190), 0.9)
	_draw_flowers(img, Vector2(340, 356), 0.7)
	_draw_flowers(img, Vector2(318, 300), 0.8)
	_draw_flowers(img, Vector2(610, 300), 0.6)
	_draw_grass_tufts(img)
	_draw_pier_posts_ground(img)
	return img


static func _grass_color(x: float, y: float) -> Color:
	# 40–80px（base 20–40px）大色块 + 稀疏斑点，不再 2–4px 等密度噪点。
	var n1 := _vnoise(x * 0.028, y * 0.028, 3)
	var n2 := _vnoise(x * 0.085, y * 0.085, 7)
	var n3 := _vnoise(x * 0.21, y * 0.21, 12)
	# 大色块以 #567F4B 中调为主，暗调只留给树影/坡下；避免整片草地发闷。
	var c := C_GRASS_M.lerp(C_GRASS, smoothstep(0.12, 0.55, n1) * 0.92)
	c = c.lerp(C_GRASS_L, smoothstep(0.40, 0.86, n2) * 0.66)
	c = c.lerp(C_GRASS_D, smoothstep(0.55, 0.15, n1) * 0.20)
	if n3 > 0.86:
		c = c.lerp(C_GRASS_LL, 0.22)
	# 右上光：非常轻的对角日照，避免整片草地死平。
	var sun := clampf(0.5 + (x - y) * 0.0009, 0.0, 1.0)
	c = c.lerp(C_GRASS_LL, sun * 0.06)
	if _hash(int(x), int(y), 21) > 0.988:
		c = c.lerp(C_GRASS_L, 0.8)
	return c


static func _sea_floor(x: float, y: float, shore: float) -> Color:
	var d := shore - x
	var n := _vnoise(x * 0.10, y * 0.10, 11)
	var n2 := _vnoise(x * 0.045, y * 0.045, 14)
	# 沙底：暖沙 → 海草淤泥 → 深槽淤泥。水色由 shader 叠加。
	var c := C_SAND_UW.lerp(C_SAND_L, n2 * 0.22)
	c = c.lerp(C_SILT, smoothstep(16.0, 64.0, d) * 0.55)
	c = c.lerp(C_SILT_D, smoothstep(56.0, 120.0, d) * 0.75)
	c = c.lerp(C_WET_D, (1.0 - smoothstep(0.0, 2.5, d)) * 0.45)
	# 沙纹 2px/8–12px（base 1px/4–6px）。
	var rip := sin(y * 0.9 + x * 0.18 + n * 3.0)
	if d < 44.0 and rip > 0.70:
		c = c.lerp(C_SAND_L, 0.28)
	if d > 8.0 and d < 56.0 and _hash(int(x), int(y), 31) > 0.972:
		c = C_PEBBLE_L
	return c


static func _islet_color(x: float, y: float) -> Color:
	var d := Vector2(x - 92.0, y - 120.0).length()
	if Vector2(x - 70.0, y - 220.0).length() < 5.0:
		d = Vector2(x - 70.0, y - 220.0).length()
	elif Vector2(x - 54.0, y - 292.0).length() < 4.0:
		d = Vector2(x - 54.0, y - 292.0).length()
	var c := C_STONE
	if d > 5.0:
		c = C_WET_D
	if d > 6.5:
		c = C_GRASS_D
	if d < 2.2:
		c = C_STONE_L
	return c


static func _beach_color(x: float, y: float, shore: float) -> Color:
	var n := _vnoise(x * 0.16, y * 0.16, 17)
	var n2 := _vnoise(x * 0.06, y * 0.06, 19)
	var d := x - shore
	var c := C_SAND.lerp(C_SAND_L, n * 0.55)
	c = c.lerp(C_SAND_D, smoothstep(0.42, 0.82, n2) * 0.35)
	# 湿沙带：水线陆侧 0–4.5 base px（9 逻辑 px），外缘暗。
	if d < 2.0:
		c = C_WET_D
	elif d < 4.5:
		c = C_WET.lerp(C_WET_D, 0.28 * n)
	elif d < 6.5:
		c = c.lerp(C_WET, 0.38)
	# 干沙亮边只在右上受光侧。
	if d > 7.0 and _hash(int(x), int(y), 23) > 0.945:
		c = C_SAND_L
	if _hash(int(x), int(y), 29) > 0.986:
		c = C_SAND_D
	if d > 6.0 and sin(y * 0.8 + x * 0.1) > 0.78:
		c = c.lerp(C_SAND_L, 0.22)
	return c


static func _river_floor(x: float, y: float, dist: float) -> Color:
	var hw := _river_halfwidth(y)
	var t := clampf(dist / maxf(hw, 1.0), 0.0, 1.0)
	var n := _vnoise(x * 0.15, y * 0.15, 33)
	var c := C_SAND_D.lerp(C_DIRT_L, n * 0.40)
	c = c.lerp(C_SILT, smoothstep(0.45, 1.0, t) * 0.50)
	if t > 0.78:
		c = c.lerp(C_WET_D, 0.35)
	if _hash(int(x), int(y), 37) > 0.955:
		c = C_PEBBLE
	if _hash(int(x), int(y), 38) > 0.986:
		c = C_PEBBLE_D
	return c


static func _lake_floor(x: float, y: float) -> Color:
	var r := _lake_radial(x, y)
	var n := _vnoise(x * 0.12, y * 0.12, 41)
	var c := C_SAND_D.lerp(C_SILT, 0.30 + n * 0.20)
	c = c.lerp(C_SILT_D, smoothstep(0.35, 0.95, r) * 0.60)
	if _hash(int(x), int(y), 43) > 0.970:
		c = C_PEBBLE_D
	if _hash(int(x), int(y), 44) > 0.992:
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
	var n2 := _vnoise(x * 0.09, y * 0.09, 52)
	var c := C_DIRT.lerp(C_DIRT_D, smoothstep(0.3, 0.8, n) * 0.7)
	c = c.lerp(C_DIRT_L, smoothstep(0.55, 0.9, n2) * 0.5)
	if cobble and _hash(floori(x / 4.0), floori(y / 4.0), 53) > 0.72:
		c = c.lerp(C_STONE_D, 0.40 + 0.25 * n)
	if _hash(floori(x / 3.0), floori(y / 3.0), 54) > 0.95:
		c = C_GRAVEL
	if d > 8.0:
		c = c.lerp(C_GRASS_D, 0.42)
	return c


static func _underwater_details(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 11
	# 海边浅滩鹅卵石带（带右上高光）。
	for i in 300:
		var y := rng.randf_range(4.0, 356.0)
		var shore := _sea_shore(y)
		var d := rng.randf_range(3.0, 48.0)
		var x := shore - d
		if x < 3.0 or _islet(x, y):
			continue
		var r := rng.randf_range(0.7, 2.2)
		var col := C_PEBBLE if rng.randf() > 0.45 else C_PEBBLE_D
		_ellipse(img, x, y, r * 1.3, r, col)
		if rng.randf() > 0.45:
			_blend(img, int(x - r * 0.3), int(y - r * 0.4), C_PEBBLE_L, 0.8)
		if rng.randf() > 0.86:
			_blend(img, int(x + r * 0.2), int(y + r * 0.6), C_SILT_D, 0.35)
	# 海草：放射状 3–5 叶，双色。
	for i in 34:
		var y := rng.randf_range(20.0, 340.0)
		var shore := _sea_shore(y)
		var x := shore - rng.randf_range(18.0, 88.0)
		if x < 4.0:
			continue
		var base_x := x
		var base_y := y
		for k in rng.randi_range(3, 5):
			var lean := rng.randf_range(-3.0, 3.0)
			var h := rng.randf_range(2.0, 5.0)
			_line(img, Vector2(base_x, base_y), Vector2(base_x + lean, base_y - h), C_PINE_D)
			_line(img, Vector2(base_x + 1, base_y), Vector2(base_x + lean * 0.7, base_y - h * 0.8), C_PINE)
	# 河床与湖底碎石。
	for i in 120:
		var y := rng.randf_range(4.0, 140.0)
		var cx := 382.0 + y * 0.42
		var x := cx + rng.randf_range(-18.0, 18.0)
		if _river_distance(x, y) > _river_halfwidth(y) - 2.0:
			continue
		var r := rng.randf_range(0.7, 1.8)
		_ellipse(img, x, y, r, r * 0.8, C_PEBBLE if rng.randf() > 0.5 else C_PEBBLE_D)
	for i in 80:
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
		# 左下接触影 + 环岛浅湿边（不再是亮沙圈）。
		_shadow_ellipse(img, Vector2(cx - 2.0, cy + 2.4), r + 2.6, (r + 2.6) * 0.52, 0.34)
		_ellipse(img, cx, cy + 0.4, r + 0.9, (r + 0.9) * 0.66, C_WET_D)
		# 3 个岩块叠成不规则礁石，3 档色 + 右上 rim。
		_ellipse(img, cx - r * 0.30, cy + r * 0.10, r * 0.72, r * 0.52, C_STONE_D)
		_ellipse(img, cx + r * 0.34, cy - r * 0.16, r * 0.55, r * 0.42, C_STONE_D)
		_ellipse(img, cx + r * 0.02, cy - r * 0.22, r * 0.62, r * 0.46, C_STONE)
		_ellipse(img, cx - r * 0.24, cy - r * 0.08, r * 0.42, r * 0.32, C_STONE)
		_ellipse(img, cx + r * 0.15, cy - r * 0.30, r * 0.30, r * 0.22, C_STONE_L)
		_blend(img, int(cx + r * 0.60), int(cy - r * 0.10), C_STONE_L, 0.9)
		_ellipse(img, cx - r * 0.25, cy + r * 0.28, r * 0.45, r * 0.20, C_STONE_D)
		if lake == 1:
			for i in 5:
				_blend(img, int(cx - 2 + i), int(cy - 5), C_PINE_L, 0.85)
			_blend(img, int(cx), int(cy - 6), C_PINE, 0.9)
			_blend(img, int(cx + 2), int(cy - 4), C_CREAM, 0.6)
		else:
			_blend(img, int(cx - 2), int(cy - 4), C_GRASS_L, 0.7)
			_blend(img, int(cx + 1), int(cy - 3), C_CREAM, 0.6)


static func _draw_beach_details(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 71
	# 沙滩贝壳/小石/海玻璃。
	for i in 26:
		var y := rng.randf_range(10.0, 350.0)
		var shore := _sea_shore(y)
		var d := rng.randf_range(7.0, 15.0)
		var x := shore + d
		var c := C_CREAM if rng.randf() > 0.5 else C_PINK
		if rng.randf() > 0.75:
			c = C_PEBBLE
		_blend(img, int(x), int(y), c, 0.85)
		if rng.randf() > 0.6:
			_blend(img, int(x) + 1, int(y), c, 0.55)
	# 漂流木：2px 厚 + 右上亮边 + 左下影。
	for i in 3:
		var y := 120.0 + i * 82.0
		var shore := _sea_shore(y)
		var x := shore + 9.0 + i * 2.0
		_blend_rect(img, Rect2i(int(x) - 1, int(y) + 2, 9, 2), C_SHADOW, 0.24)
		_line(img, Vector2(x, y), Vector2(x + 7, y + 2), C_WOOD_M)
		_line(img, Vector2(x, y + 1), Vector2(x + 7, y + 3), C_WOOD_D)
		_blend(img, int(x + 2), int(y), C_WOOD_L, 0.7)


static func _draw_shadows(img: Image) -> void:
	# 统一左下影（光从右上）。投影色 #1E3A36 α0.30–0.36，接触影 2–3px α0.45。
	_shadow_ellipse(img, Vector2(286 - 19, 150 + 15), 40, 14, 0.56)  # 房屋
	_shadow_ellipse(img, Vector2(236 - 14, 96 + 13), 26, 10, 0.56)   # 大松
	_shadow_ellipse(img, Vector2(418 - 9, 168 + 10), 16, 7, 0.44)    # 小松
	_shadow_ellipse(img, Vector2(354 - 12, 206 + 13), 22, 9, 0.56)   # 红枫
	_shadow_ellipse(img, Vector2(304 - 5, 268 + 6), 12, 5, 0.28)
	_shadow_ellipse(img, Vector2(388 - 4, 258 + 5), 9, 4, 0.26)
	_shadow_ellipse(img, Vector2(566 - 5, 212 + 6), 11, 4, 0.26)
	_shadow_ellipse(img, Vector2(336 - 4, 338 + 5), 8, 3, 0.24)
	_shadow_ellipse(img, Vector2(390 - 4, 282 + 5), 9, 4, 0.30)
	_shadow_ellipse(img, Vector2(456 - 4, 118 + 5), 8, 3, 0.26)
	_shadow_ellipse(img, Vector2(206 - 4, 330 + 4), 11, 4, 0.30)
	_shadow_ellipse(img, Vector2(566 - 4, 322 + 4), 10, 4, 0.30)
	_shadow_ellipse(img, Vector2(446 - 3, 92 + 3), 7, 3, 0.26)
	_shadow_ellipse(img, Vector2(610 - 3, 246 + 3), 8, 3, 0.26)
	_shadow_ellipse(img, Vector2(258 - 3, 246 + 4), 10, 4, 0.22)
	_shadow_ellipse(img, Vector2(436 - 3, 310 + 4), 8, 3, 0.22)
	_shadow_ellipse(img, Vector2(592 - 3, 190 + 4), 8, 3, 0.22)
	# 栅栏落影（左下 2px）。
	for i in 7:
		var t := float(i) / 6.0
		var p := Vector2(392, 276).lerp(Vector2(468, 220), t)
		_blend_rect(img, Rect2i(int(p.x) - 3, int(p.y) - 2, 3, 1), C_SHADOW, 0.30)
	# 湖岸石墙落影。
	for i in 9:
		var x := 456 + i * 15
		var y := 214 + int(3.0 * sin(float(i) * 0.8))
		_blend_rect(img, Rect2i(x - 2, y + 6, 12, 2), C_SHADOW, 0.28)


static func _draw_house(img: Image, p: Vector2) -> void:
	# 3/4 俯视：屋顶占 ~70% 足迹，4 条瓦带、屋脊高光、烟囱影、整屋左下影。
	var wall := Rect2i(int(p.x) - 23, int(p.y) + 0, 46, 17)
	# 墙体
	_rect(img, wall, C_WALL)
	_blend_rect(img, Rect2i(wall.position.x, wall.position.y + 10, wall.size.x, 7), C_WALL_D, 0.75)
	_blend_rect(img, Rect2i(wall.position.x, wall.position.y, 9, 17), C_WALL_D, 0.35)
	_outline_rect(img, wall, 1)
	# 屋顶（上缘 70%）：梯形 + 出檐。
	var roof := PackedVector2Array([
		p + Vector2(-29, 1), p + Vector2(-20, -26), p + Vector2(27, -26),
		p + Vector2(32, 1),
	])
	_fill_poly(img, roof, C_ROOF)
	# 4 条瓦带 + 竖缝。
	for i in 4:
		var yy := p.y - 24.0 + float(i) * 6.3
		_line(img, Vector2(p.x - 21.0 - float(i), yy), Vector2(p.x + 27.0 + float(i) * 0.8, yy), C_ROOF_D)
		for j in 6:
			var xx := p.x - 18.0 + float(j) * 8.0 + float(i) * 1.2
			_blend(img, int(xx), int(yy + 1.0), C_ROOF_D, 0.55)
	# 屋脊高光（右上受光）。
	_line(img, Vector2(p.x - 20, p.y - 26), Vector2(p.x + 27, p.y - 26), C_ROOF_L)
	_line(img, Vector2(p.x + 27, p.y - 26), Vector2(p.x + 32, p.y + 1), C_ROOF_L)
	_line(img, Vector2(p.x - 29, p.y + 1), Vector2(p.x - 20, p.y - 26), C_ROOF_D)
	_outline_poly(img, roof, C_OUTLINE)
	# 烟囱 + 投在屋顶上的左下影。
	_blend_rect(img, Rect2i(int(p.x) + 8, int(p.y) - 33, 7, 13), C_SHADOW, 0.38)
	_rect(img, Rect2i(int(p.x) + 14, int(p.y) - 30, 6, 11), C_STONE_D)
	_rect(img, Rect2i(int(p.x) + 15, int(p.y) - 30, 3, 9), C_STONE)
	_rect(img, Rect2i(int(p.x) + 13, int(p.y) - 31, 8, 2), C_STONE_L)
	# 窗户：2px 暖光，不做大光晕。
	for wx in [int(p.x) - 18, int(p.x) + 9]:
		_rect(img, Rect2i(wx, int(p.y) + 3, 9, 7), C_WOOD_D)
		_rect(img, Rect2i(wx + 1, int(p.y) + 4, 7, 5), C_WARM)
		_rect(img, Rect2i(wx + 1, int(p.y) + 4, 7, 2), C_YELLOW)
		_line(img, Vector2(wx + 4, p.y + 4), Vector2(wx + 4, p.y + 8), C_WOOD_D)
	# 门 + 门框 + 台阶。
	_rect(img, Rect2i(int(p.x) - 4, int(p.y) + 8, 9, 12), C_WOOD_D)
	_rect(img, Rect2i(int(p.x) - 3, int(p.y) + 9, 7, 10), C_WOOD)
	_line(img, Vector2(p.x - 1, p.y + 9), Vector2(p.x - 1, p.y + 18), C_WOOD_L)
	_rect(img, Rect2i(int(p.x) - 6, int(p.y) + 19, 13, 2), C_STONE_D)
	# 接触影。
	_blend_rect(img, Rect2i(int(p.x) - 24, int(p.y) + 16, 48, 2), C_SHADOW, 0.42)
	# 草沿墙根。
	for i in 9:
		_blend(img, int(p.x) - 23 + i * 6, int(p.y) + 17 + (i % 2), C_GRASS_D, 0.75)


static func _draw_pine(img: Image, p: Vector2, h: float) -> void:
	_rect(img, Rect2i(int(p.x) - 2, int(p.y) - 4, 4, 14), C_WOOD_D)
	_blend(img, int(p.x) + 1, int(p.y) - 2, C_WOOD_L, 0.55)
	# 5 层针叶，每层带阶梯缺口 + 右上亮边。
	for layer in 5:
		var w := h * (1.0 - float(layer) * 0.15)
		var yy := p.y - 4.0 - float(layer) * (h * 0.155)
		var hh := h * 0.34
		var tri := PackedVector2Array([
			Vector2(p.x - w * 0.5, yy),
			Vector2(p.x - w * 0.18, yy - hh * 0.55),
			Vector2(p.x, yy - hh),
			Vector2(p.x + w * 0.20, yy - hh * 0.52),
			Vector2(p.x + w * 0.5, yy),
			Vector2(p.x + w * 0.20, yy - 1.5),
			Vector2(p.x, yy - 3.0),
			Vector2(p.x - w * 0.22, yy - 1.5),
		])
		_fill_poly(img, tri, C_PINE_D)
		var inner := PackedVector2Array([
			Vector2(p.x - w * 0.28, yy - 2.0),
			Vector2(p.x - w * 0.06, yy - hh * 0.82),
			Vector2(p.x + w * 0.10, yy - hh * 0.55),
			Vector2(p.x + w * 0.24, yy - 2.0),
		])
		_fill_poly(img, inner, C_PINE)
		# 顶层右上亮边 1px。
		_line(img, Vector2(p.x + 1, yy - hh + 1), Vector2(p.x + w * 0.22, yy - hh * 0.5), C_PINE_L)
		_blend(img, int(p.x + w * 0.30), int(yy - 2), C_PINE_L, 0.65)
		# 层底暗缺口。
		for i in 3:
			var nx := p.x - w * 0.30 + float(i) * w * 0.30
			_blend(img, int(nx), int(yy + 1), C_PINE_D, 0.8)
	# 树冠右缘 2px 亮边（brief 要求 2px 亮边，base 1px）。
	_line(img, Vector2(p.x + h * 0.20, p.y - h * 0.60), Vector2(p.x + h * 0.34, p.y - h * 0.25), C_PINE_L)


static func _draw_maple(img: Image, p: Vector2, r: float) -> void:
	_rect(img, Rect2i(int(p.x) - 3, int(p.y) + 4, 6, 18), C_WOOD_D)
	_blend(img, int(p.x) + 1, int(p.y) + 6, C_WOOD_L, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 31
	# 4 个大叶团 + 2 个补团：3 档色，右上亮、左下暗。
	var clusters: Array[Vector3] = [
		Vector3(-r * 0.45, -r * 0.55, r * 0.46), Vector3(r * 0.30, -r * 0.62, r * 0.50),
		Vector3(r * 0.05, -r * 0.22, r * 0.44), Vector3(-r * 0.34, -r * 0.10, r * 0.36),
	]
	for cl in clusters:
		var cx := p.x + cl.x
		var cy := p.y + cl.y
		var rr: float = cl.z
		_ellipse(img, cx - 1.0, cy + 1.5, rr * 1.1, rr * 0.9, C_MAPLE_D)
		_ellipse(img, cx, cy, rr, rr * 0.82, C_MAPLE)
		_ellipse(img, cx + rr * 0.18, cy - rr * 0.22, rr * 0.64, rr * 0.48, C_MAPLE_L)
		# 叶缺口。
		_blend(img, int(cx - rr * 0.4), int(cy + rr * 0.2), C_MAPLE_D, 0.8)
		_blend(img, int(cx + rr * 0.5), int(cy + rr * 0.1), C_MAPLE_D, 0.75)
	for i in 14:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(r * 0.25, r * 0.8)
		_blend(img, int(p.x + cos(a) * d), int(p.y - r * 0.45 + sin(a) * d * 0.7),
				C_MAPLE_L if rng.randf() > 0.4 else C_MAPLE, 0.7)


static func _draw_bush(img: Image, p: Vector2, r: float) -> void:
	_ellipse(img, p.x - 0.5, p.y + 1.0, r, r * 0.72, C_PINE_D)
	_ellipse(img, p.x, p.y, r * 0.92, r * 0.64, C_PINE)
	_ellipse(img, p.x + r * 0.22, p.y - r * 0.20, r * 0.55, r * 0.38, C_PINE_L)
	for i in 6:
		_blend(img, int(p.x - r * 0.8 + i * r * 0.3), int(p.y - r * 0.45), C_PINE_L, 0.6)


static func _draw_flowers(img: Image, p: Vector2, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(p.x * 3 + p.y * 7)
	# 成组 3–5 小簇；每簇 4–7 朵，底部有接触影。
	for g in rng.randi_range(3, 5):
		var gx := p.x + rng.randf_range(-14.0, 14.0) * scale
		var gy := p.y + rng.randf_range(-8.0, 8.0) * scale
		_blend_rect(img, Rect2i(int(gx) - 4, int(gy) + 1, 9, 2), C_SHADOW, 0.20)
		for i in rng.randi_range(4, 7):
			var x := gx + rng.randf_range(-4.0, 4.0)
			var y := gy + rng.randf_range(-3.0, 2.0)
			var c := C_PINK if rng.randf() > 0.42 else C_YELLOW
			if rng.randf() > 0.86:
				c = C_CREAM
			_blend(img, int(x), int(y + 1), C_GRASS_D, 0.75)
			_blend(img, int(x), int(y), c, 0.95)
			if rng.randf() > 0.55:
				_blend(img, int(x + 1), int(y), c, 0.6)


static func _draw_rocks(img: Image, p: Vector2, scale: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + int(p.x * 5 + p.y * 11)
	for i in 5:
		var cx := p.x + rng.randf_range(-8.0, 8.0) * scale
		var cy := p.y + rng.randf_range(-4.0, 4.0) * scale
		var rx := rng.randf_range(2.5, 6.0) * scale
		var ry := rx * rng.randf_range(0.55, 0.85)
		_shadow_ellipse(img, Vector2(cx - 1.0, cy + ry * 0.6), rx * 1.05, ry * 0.55, 0.30)
		_ellipse(img, cx, cy, rx, ry, C_STONE_D)
		_ellipse(img, cx - rx * 0.12, cy - ry * 0.22, rx * 0.80, ry * 0.62, C_STONE)
		# 右上 rim 1–2px。
		_ellipse(img, cx + rx * 0.16, cy - ry * 0.34, rx * 0.42, ry * 0.30, C_STONE_L)
		_blend(img, int(cx + rx * 0.55), int(cy - ry * 0.15), C_STONE_L, 0.9)
		_blend(img, int(cx - rx * 0.4), int(cy + ry * 0.3), C_STONE_D, 0.85)


static func _draw_lantern(img: Image, p: Vector2) -> void:
	_shadow_ellipse(img, Vector2(p.x - 3.0, p.y + 5.0), 10, 5, 0.32)
	_rect(img, Rect2i(int(p.x) - 2, int(p.y) - 12, 4, 16), C_STONE)
	_rect(img, Rect2i(int(p.x) + 1, int(p.y) - 12, 1, 14), C_STONE_L)
	_rect(img, Rect2i(int(p.x) - 5, int(p.y) - 15, 10, 4), C_STONE_L)
	_rect(img, Rect2i(int(p.x) - 4, int(p.y) - 20, 8, 6), C_WARM)
	_rect(img, Rect2i(int(p.x) - 4, int(p.y) - 20, 8, 2), C_YELLOW)
	_rect(img, Rect2i(int(p.x) - 7, int(p.y) - 23, 14, 4), C_STONE_D)
	_rect(img, Rect2i(int(p.x) - 1, int(p.y) - 28, 2, 5), C_STONE_L)
	# 2px 暖光，不加光晕。
	_rect(img, Rect2i(int(p.x) - 3, int(p.y) - 19, 2, 2), C_CREAM)


static func _draw_fence(img: Image, a: Vector2, b: Vector2) -> void:
	var n := 7
	for i in n:
		var t := float(i) / float(n - 1)
		var p := a.lerp(b, t)
		_blend_rect(img, Rect2i(int(p.x) - 2, int(p.y) - 7, 2, 11), C_SHADOW, 0.24)
		_rect(img, Rect2i(int(p.x) - 1, int(p.y) - 9, 3, 13), C_WOOD_D)
		_rect(img, Rect2i(int(p.x), int(p.y) - 9, 1, 12), C_WOOD_M)
	for i in n - 1:
		var p0 := a.lerp(b, float(i) / float(n - 1))
		var p1 := a.lerp(b, float(i + 1) / float(n - 1))
		_line(img, p0 + Vector2(0, -6), p1 + Vector2(0, -6), C_WOOD_M)
		_line(img, p0 + Vector2(0, -2), p1 + Vector2(0, -2), C_WOOD_D)


static func _draw_stone_wall(img: Image) -> void:
	# 湖岸北侧矮石挡墙（brief 6.9：湖岸要有石/湿土与影）。
	for i in 9:
		var x := 456 + i * 15
		var y := 214 + int(3.0 * sin(float(i) * 0.8))
		_rect(img, Rect2i(x - 6, y - 4, 13, 7), C_STONE_D)
		_rect(img, Rect2i(x - 5, y - 4, 11, 5), C_STONE)
		_line(img, Vector2(x - 5, y - 4), Vector2(x + 6, y - 4), C_STONE_L)
		_blend(img, int(x + 4), int(y + 1), C_STONE_D, 0.9)
		_blend(img, int(x + 7), int(y + 2), C_WET_D, 0.6)


static func _draw_grass_tufts(img: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 91
	for i in 240:
		var x := rng.randf_range(185.0, 630.0)
		var y := rng.randf_range(20.0, 352.0)
		if _is_main_water(x, y) or _water_polygon(x, y):
			continue
		if x < _sea_shore(y) + 17.0:
			continue
		var h := rng.randf_range(1.0, 3.0)
		var c := C_GRASS_L if rng.randf() > 0.45 else C_GRASS_D
		_line(img, Vector2(x, y), Vector2(x + rng.randf_range(-1.0, 1.0), y - h), c)
		if rng.randf() > 0.7:
			_blend(img, int(x) + 1, int(y) - 1, C_GRASS_LL, 0.7)


static func _draw_pier_posts_ground(img: Image) -> void:
	for i in 3:
		_blend(img, 136 + i * 13, 296, C_WOOD_D, 0.30)
		_blend(img, 137 + i * 13, 297, C_WOOD_D, 0.20)


# ── 前景（桥 / 栈桥 / 睡莲） ─────────────────────────────────────────────
static func _build_foreground() -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_bridge(img)
	_draw_pier(img)
	_draw_lily_pads(img)
	return img


static func _draw_bridge(img: Image) -> void:
	var x0 := BRIDGE_X0
	var y0 := BRIDGE_Y0
	var x1 := BRIDGE_X1
	var y1 := BRIDGE_Y1
	# 桥面：横向木板，8px 板缝（base 4px）；板面 +6 L*，只用 1px 上缘高光。
	for y in range(y0, y1 + 1):
		var local := y - y0
		var plank := int(local / 4)
		var c := C_WOOD_M
		if (plank % 2) == 1:
			c = c.darkened(0.04)
		if local % 4 == 3:
			c = C_WOOD_D
		for x in range(x0 + 4, x1 - 3):
			img.set_pixel(x, y, c)
		if local % 4 == 0 and local > 0:
			_line(img, Vector2(x0 + 5, y), Vector2(x1 - 4, y), C_WOOD_L)
		# 木纹：稀疏 1–2px 深线。
		if local % 7 == 0:
			_blend(img, x0 + 8, y, C_WOOD_D, 0.55)
			_blend(img, x1 - 8, y, C_WOOD_D, 0.45)
	# 双侧栏杆：4px 宽，立柱每 12 base px（24 显示），栏杆在桥面之外露头。
	_rect(img, Rect2i(x0, y0 + 2, 4, y1 - y0 - 4), C_WOOD_D)
	_rect(img, Rect2i(x1 - 3, y0 + 2, 4, y1 - y0 - 4), C_WOOD_D)
	_line(img, Vector2(x0 + 1, y0 + 3), Vector2(x0 + 1, y1 - 3), C_WOOD_M)
	_line(img, Vector2(x1 - 2, y0 + 3), Vector2(x1 - 2, y1 - 3), C_WOOD)
	_line(img, Vector2(x0 + 3, y0 + 3), Vector2(x0 + 3, y1 - 3), C_WOOD_L)
	_line(img, Vector2(x1 - 1, y0 + 3), Vector2(x1 - 1, y1 - 3), C_WOOD_L)
	for i in 6:
		var y := y0 + 4 + i * 12
		_rect(img, Rect2i(x0 - 2, y - 3, 7, 6), C_WOOD_D)
		_rect(img, Rect2i(x1 - 5, y - 3, 7, 6), C_WOOD_D)
		_line(img, Vector2(x0 - 1, y - 3), Vector2(x0 + 4, y - 3), C_WOOD_L)
		_line(img, Vector2(x1 - 4, y - 3), Vector2(x1 + 1, y - 3), C_WOOD_L)
		_blend(img, int(x0 + 4), int(y + 3), C_SHADOW, 0.34)
		_blend(img, int(x1 - 1), int(y + 3), C_SHADOW, 0.34)
	# 桥端湿木 6 显示 px（base 3px）+ 水线。
	_blend_rect(img, Rect2i(x0, y0, x1 - x0 + 1, 3), C_WOOD_WET, 0.85)
	_blend_rect(img, Rect2i(x0, y1 - 2, x1 - x0 + 1, 3), C_WOOD_WET, 0.85)
	_line(img, Vector2(x0, y0 + 3), Vector2(x1, y0 + 3), C_WOOD_L)
	# 两端石块 + 接触影。
	for side in [y0 - 2, y1 + 1]:
		_blend_rect(img, Rect2i(x0 - 4, side, 8, 4), C_STONE_D, 0.9)
		_blend_rect(img, Rect2i(x1 - 3, side, 8, 4), C_STONE_D, 0.9)
		_blend_rect(img, Rect2i(x0 - 4, side + 1, 8, 1), C_STONE, 0.8)
		_blend_rect(img, Rect2i(x1 - 3, side + 1, 8, 1), C_STONE, 0.8)
	_outline_rect(img, Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1), 1)
	_line(img, Vector2(x0 + 1, y0 + 4), Vector2(x0 + 1, y1 - 4), C_WOOD_L)


static func _draw_pier(img: Image) -> void:
	var y0 := 286
	var y1 := 300
	for x in range(108, 160):
		var plank := int((x - 108) / 5)
		var c := C_WOOD if (plank % 2) == 0 else C_WOOD_M
		for y in range(y0, y1):
			img.set_pixel(x, y, c)
		_line(img, Vector2(x, y0), Vector2(x, y1 - 1), C_WOOD_D if (x % 5) == 0 else c)
	# 右上高光 + 湿木端。
	_line(img, Vector2(108, y0 + 1), Vector2(159, y0 + 1), C_WOOD_L)
	_blend_rect(img, Rect2i(108, y1 - 3, 52, 3), C_WOOD_WET, 0.8)
	# 桩与接触影。
	for x in [110, 126, 142, 157]:
		_blend_rect(img, Rect2i(x - 1, y1 + 4, 6, 4), C_SHADOW, 0.30)
		_rect(img, Rect2i(x, y1 - 1, 3, 8), C_WOOD_D)
		_rect(img, Rect2i(x, y1 - 1, 1, 7), C_WOOD_M)
	# 栏杆立柱。
	for x in [112, 132, 152]:
		_rect(img, Rect2i(x, y0 - 4, 2, 5), C_WOOD_D)
		_rect(img, Rect2i(x, y0 - 4, 1, 4), C_WOOD)
	# 系船柱。
	_rect(img, Rect2i(156, 278, 3, 8), C_WOOD_D)
	_blend(img, 157, 279, C_WOOD_L, 0.7)
	_draw_boat(img, Vector2(112, 262))


static func _draw_boat(img: Image, p: Vector2) -> void:
	# 俯视小船：尖头朝右，双色船壳 + 座板 + 双桨 + 水面接触影。
	var hull := PackedVector2Array([
		p + Vector2(-13, -3), p + Vector2(-9, -6), p + Vector2(8, -5),
		p + Vector2(14, 0), p + Vector2(8, 5), p + Vector2(-9, 6), p + Vector2(-13, 3),
	])
	_fill_poly(img, hull, C_WOOD_D)
	var inner := PackedVector2Array([
		p + Vector2(-10, -2), p + Vector2(-7, -4), p + Vector2(7, -3),
		p + Vector2(11, 0), p + Vector2(7, 3), p + Vector2(-7, 4), p + Vector2(-10, 2),
	])
	_fill_poly(img, inner, C_WOOD_M)
	_line(img, p + Vector2(-8, -3), p + Vector2(7, -2), C_WOOD_L)
	for i in 3:
		_line(img, p + Vector2(-5 + i * 5, -3), p + Vector2(-5 + i * 5, 3), C_WOOD_D)
	# 双桨。
	_line(img, p + Vector2(-1, 3), p + Vector2(10, 9), C_WOOD_L)
	_line(img, p + Vector2(0, -3), p + Vector2(11, -9), C_WOOD_L)
	_line(img, p + Vector2(10, 9), p + Vector2(14, 10), C_WOOD_D)
	_line(img, p + Vector2(11, -9), p + Vector2(15, -10), C_WOOD_D)
	# 船舷右上亮边 + 水下阴影。
	_line(img, p + Vector2(-9, -5), p + Vector2(8, -4), C_WOOD_L)
	_blend_rect(img, Rect2i(int(p.x) - 13, int(p.y) + 6, 28, 3), C_SILT_D, 0.25)


static func _draw_lily_pads(img: Image) -> void:
	# 睡莲成组：12–18 显示 px（base 6–9px），2 色 + 缺口 + 1px 高光，4–6 片/组。
	var groups: Array[Vector3] = [
		Vector3(470, 290, 1.0), Vector3(545, 264, 1.1), Vector3(574, 300, 0.9),
		Vector3(505, 322, 0.8), Vector3(558, 318, 0.7), Vector3(452, 266, 0.8),
	]
	var pads: Array[Vector3] = [
		Vector3(-4, -3, 8), Vector3(5, -2, 7), Vector3(-2, 4, 6), Vector3(6, 5, 5),
	]
	for g in groups:
		for pad in pads:
			var cx: float = g.x + pad.x * g.z
			var cy: float = g.y + pad.y * g.z * 0.7
			var r: float = pad.z * g.z * 0.55
			if r < 3.0:
				continue
			_ellipse(img, cx, cy, r, r * 0.64, C_LILY_D)
			_ellipse(img, cx, cy - 0.5, r * 0.82, r * 0.50, C_LILY)
			_line(img, Vector2(cx, cy), Vector2(cx + r * 0.85, cy + r * 0.18), C_LILY_D)
			_blend(img, int(cx - r * 0.3), int(cy - r * 0.25), C_LILY_L, 0.9)
		# 花 6–8 显示 px（base 3–4px）。
		var fx: float = g.x + 2.0 * g.z
		var fy: float = g.y - 4.0 * g.z
		for i in 5:
			var a := -PI * 0.5 + (float(i) - 2.0) * 0.30
			_ellipse(img, fx + cos(a) * 2.2, fy + sin(a) * 2.2, 1.8, 1.3,
					C_PINK if i % 2 == 0 else C_CREAM)
		_blend(img, int(fx), int(fy), C_YELLOW, 0.95)


# ── 芦苇簇（独立 sprite，可在 main.gd 做 ±2px 风摆） ──────────────────────
static func _build_reeds() -> Array:
	var specs := [
		{"base": Vector2(155, 220), "scale": 1.0, "phase": 0.0},
		{"base": Vector2(158, 318), "scale": 1.15, "phase": 1.7},
		{"base": Vector2(426, 52), "scale": 0.85, "phase": 3.1},
		{"base": Vector2(474, 336), "scale": 1.0, "phase": 4.6},
		{"base": Vector2(580, 326), "scale": 0.9, "phase": 2.4},
	]
	var out: Array = []
	for spec in specs:
		var img := Image.create(REED_W, REED_H, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var base: Vector2 = spec["base"]
		var scale_v: float = spec["scale"]
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED + int(base.x * 7 + base.y * 13)
		# 基部接触影 2 base px。
		_shadow_ellipse(img, Vector2(REED_BASE.x, REED_BASE.y + 0.5), 12.0 * scale_v, 3.0, 0.45)
		for i in rng.randi_range(9, 12):
			var dx := rng.randf_range(-10.0, 10.0) * scale_v
			var h := rng.randf_range(11.0, 22.0) * scale_v
			var lean := rng.randf_range(-5.0, 5.0) * scale_v
			var x0 := REED_BASE.x + dx * 0.6
			var y0 := REED_BASE.y
			_line(img, Vector2(x0, y0), Vector2(x0 + lean, y0 - h), C_PINE_D)
			_line(img, Vector2(x0 + 0.8, y0), Vector2(x0 + lean + 0.8, y0 - h * 0.92), C_PINE)
			_line(img, Vector2(x0 + 0.6, y0 - h * 0.35), Vector2(x0 + lean + 0.6, y0 - h * 0.85), C_PINE_L)
			if rng.randf() > 0.55:
				_ellipse(img, x0 + lean, y0 - h - 1.0, 1.2, 2.8, C_WOOD_D)
		out.append({"base": base, "image": img, "phase": spec["phase"]})
	return out


# ── 倒影图层（水面上、前景下） ────────────────────────────────────────────
static func _build_reflections(reed_clusters: Array) -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 桥：桥端湿木 + 栏杆在桥下水面拉出 8–12 base px 的断续倒影。
	_blend_rect(img, Rect2i(BRIDGE_X0 + 1, BRIDGE_Y1 + 1,
			BRIDGE_X1 - BRIDGE_X0 - 2, 7), C_SHADOW, 0.42)
	for i in 12:
		var y := BRIDGE_Y1 + 2 + i
		var a := 0.28 * (1.0 - float(i) / 14.0)
		if (i / 2) % 2 == 0:
			_blend_rect(img, Rect2i(BRIDGE_X0 + 4, y, 4, 1), C_WOOD_D, a)
			_blend_rect(img, Rect2i(BRIDGE_X1 - 8, y, 4, 1), C_WOOD_D, a)
	for i in 5:
		_blend_rect(img, Rect2i(BRIDGE_X0 + 10 + i * 3, BRIDGE_Y1 + 6 + i, 2, 1), C_WOOD_WET, 0.18)
	# 小船倒影。
	for i in 7:
		var a := 0.16 * (1.0 - float(i) / 8.0)
		if (i / 2) % 2 == 0:
			_blend_rect(img, Rect2i(100, 268 + i, 24, 1), C_WOOD_D, a)
	# 礁石/湖心岛倒影：向右下偏移 2px，2px dither 打断。
	var islets: Array[Vector3] = [
		Vector3(92, 120, 8), Vector3(70, 220, 5), Vector3(54, 292, 4), Vector3(496, 262, 7),
	]
	for islet in islets:
		var cx: float = islet.x
		var cy: float = islet.y
		var r: float = islet.z
		for k in 6:
			var t := float(k) / 6.0
			var rr := r * (1.0 - t * 0.35)
			for x in range(int(cx - rr), int(cx + rr), 2):
				if (x / 2 + k) % 3 == 0:
					continue
				_blend(img, x, int(cy + r * 0.6 + k), C_STONE_D, 0.11 * (1.0 - t))
		_blend(img, int(cx - 1), int(cy + r * 0.7), C_SHADOW, 0.22)
	# 湖：岛周接触影 + 石墙落影 + 睡莲下暗斑（读成贴水而不是贴片）。
	var lake_islet := Vector2(496, 262)
	for k in 4:
		var rr := 9.0 - float(k) * 1.0
		for x in range(int(lake_islet.x - rr), int(lake_islet.x + rr), 2):
			if (x / 2 + k) % 4 == 0:
				continue
			_blend(img, x, int(lake_islet.y + 5 + k), C_SHADOW, 0.24 * (1.0 - float(k) / 5.0))
	for x in range(456, 590, 2):
		if (x / 2) % 3 == 0:
			continue
		_blend(img, x, 220, C_SHADOW, 0.22)
		_blend(img, x, 221, C_SHADOW, 0.16)
	var lily_spots := [Vector2(470, 290), Vector2(545, 264), Vector2(574, 300),
			Vector2(505, 322), Vector2(558, 318), Vector2(452, 266)]
	for p in lily_spots:
		_shadow_ellipse(img, Vector2(p.x - 1.0, p.y + 2.5), 7.0, 3.0, 0.22)
		_blend(img, int(p.x - 2), int(p.y + 2), C_SHADOW, 0.20)
	# 芦苇倒影：只拉 4–6 base px 的细线。
	for c in reed_clusters:
		var base: Vector2 = c["base"]
		for i in 7:
			var dx := -8.0 + float(i) * 2.7
			_blend(img, int(base.x + dx), int(base.y + 1 + (i % 2)),
					C_PINE_D, 0.12)
			_blend(img, int(base.x + dx + 1), int(base.y + 3 + (i % 3)),
					C_PINE_D, 0.08)
	# 栈桥桩倒影。
	for x in [110, 126, 142, 157]:
		for i in 4:
			_blend(img, x + 1, 306 + i, C_WOOD_D, 0.12)
	return img


# ── 岸线覆盖层（水面之上、前景之下） ─────────────────────────────────────
# 16px 数据本身无法表达 8–12 逻辑 px 的湿沙带；这里用解析水线画一层：
#   水侧 2px 暗水线 #2B4A45 α0.55 → 陆侧湿沙 #A89670 4–6 base px（8–12 逻辑）
#   → 外缘 #82755A 1–2px → 干沙亮边 #F5E9C0（仅右上受光）。
static func _build_shore_overlay(mask: Image) -> Image:
	var img := Image.create(BASE_W, BASE_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 501
	# 海：按 16px 掩码的真实水线找边缘；湿沙在陆侧，白芯/青沫在水侧。
	for y in BASE_H:
		var fy := float(y)
		var shore := _sea_shore(fy)
		var sx := int(floor(shore))
		var edge_x := -1
		for x in range(maxi(sx - 12, 1), mini(sx + 24, BASE_W - 1)):
			if mask.get_pixel(x, y).r < 0.5:
				edge_x = x
				break
		if edge_x < 0:
			continue
		edge_x += int(round((_vnoise(fy * 0.35, 3.0, 91) - 0.5) * 2.0))
		# 水侧：2px 暗水线 + 白芯 2–4 base px（30% 断口）+ 青沫 4–6px。
		_blend(img, edge_x - 1, y, C_WATERLINE, 0.55)
		_blend(img, edge_x - 2, y, C_WATERLINE, 0.35)
		if _hash(y, 7, 83) > 0.22:
			var core_w := 2 + int(rng.randf() * 2.0)
			for i in core_w:
				_blend(img, edge_x - 2 - i, y, C_FOAM, 0.92 - float(i) * 0.06)
			for i in 6:
				_blend(img, edge_x - 2 - core_w - i, y, C_FOAM_WASH, 0.22)
		# 陆侧：湿沙 4–5 base px（8–10 逻辑），外缘 1px 暗湿沙。
		var wet_start := 1
		var wet_w := 4 + int(rng.randf() * 2.0)
		for i in wet_w:
			var xx := edge_x + wet_start + i
			var t := float(i) / float(maxi(wet_w - 1, 1))
			var col := C_WET.lerp(C_WET_D, t * 0.38)
			if i == wet_w - 1 and _vnoise(float(xx) * 0.4, fy * 0.4, 77) > 0.58:
				continue
			_blend(img, xx, y, col, 0.92)
		_blend(img, edge_x + wet_start + wet_w, y, C_WET_D, 0.52)
		if _hash(y, 3, 81) > 0.40:
			_blend(img, edge_x + wet_start + wet_w + 1, y, C_SAND_L, 0.60)

	# 河：沿水线两侧；桥格（mask.B）跳过。
	for y in range(0, 176):
		var fy := float(y)
		var cx := 382.0 + fy * 0.42
		var hw := _river_halfwidth(fy)
		for side in [-1, 1]:
			var approx := int(cx + float(side) * hw)
			var edge_x := -1
			if side < 0:
				for x in range(mini(approx + 8, BASE_W - 1), maxi(approx - 12, 0), -1):
					var px := mask.get_pixel(x, y)
					if px.b > 0.5:
						continue
					var inner := mask.get_pixel(x + 1, y) if x + 1 < BASE_W else px
					if px.r < 0.5 and inner.r > 0.5:
						edge_x = x
						break
			else:
				for x in range(maxi(approx - 8, 0), mini(approx + 12, BASE_W - 1)):
					var px := mask.get_pixel(x, y)
					if px.b > 0.5:
						continue
					var inner := mask.get_pixel(x - 1, y) if x > 0 else px
					if px.r < 0.5 and inner.r > 0.5:
						edge_x = x
						break
			if edge_x < 0:
				continue
			edge_x += int(round((_vnoise(fy * 0.6, float(side) * 7.0, 93) - 0.5) * 2.0))
			# 水侧 1px 暗线 + 1–2px 断口白沫（河泡沫减半）。
			_blend(img, edge_x - side, y, C_WATERLINE, 0.35)
			if _hash(y, side + 9, 84) > 0.55:
				_blend(img, edge_x - side * 2, y, C_FOAM, 0.42)
			# 陆侧湿土 4–6px。
			for i in 5:
				_blend(img, edge_x + side * (1 + i), y,
						C_WET_D.lerp(C_WET, 0.55 if i < 2 else 0.2), 0.55)

	# 湖：从中心向两侧扫描，只画 1px 暗水线 + 陆侧湿土，不出现泡沫环。
	for y in range(204, 352):
		var fy := float(y)
		for side in [-1, 1]:
			var start_x := 516
			var edge_x := -1
			var x := start_x
			while x > 424 and x < 612:
				var px := mask.get_pixel(x, y)
				if _in_lake(float(x), fy) and px.r < 0.5:
					edge_x = x
					break
				x += side
			if edge_x < 0:
				continue
			_blend(img, edge_x - side, y, C_WATERLINE, 0.55)
			_blend(img, edge_x - side * 2, y, C_WATERLINE, 0.30)
			for i in 5:
				_blend(img, edge_x + side * (1 + i), y,
						C_WET_D.lerp(C_WET, 0.45 if i < 2 else 0.18), 0.50)

	# 海面礁石：2–4 逻辑 px 的断续泡沫领 + 水侧接触影（不画整圈）。
	var sea_islets: Array[Vector3] = [Vector3(92, 120, 8), Vector3(70, 220, 5), Vector3(54, 292, 4)]
	for isl in sea_islets:
		var cx: float = isl.x
		var cy: float = isl.y
		var r: float = isl.z
		for k in 96:
			var ang := float(k) / 96.0 * TAU
			if _hash(k, 5, 87) < 0.30:
				continue
			var ca := cos(ang)
			var sa := sin(ang) * 0.66
			var x0 := int(cx + ca * (r + 1.2))
			var y0 := int(cy + sa * (r + 1.2))
			var x1 := int(cx + ca * (r + 2.6))
			var y1 := int(cy + sa * (r + 2.6))
			_blend(img, x0, y0, C_FOAM, 0.80)
			_blend(img, x1, y1, C_FOAM_WASH, 0.38)
			_blend(img, int(cx + ca * (r + 0.4)), int(cy + sa * (r + 0.4)), C_WATERLINE, 0.35)
	# 湖心岛：只画 1px 暗水线与左下影，无泡沫。
	var lake_isl := Vector3(496, 262, 7)
	for k in 80:
		var ang := float(k) / 80.0 * TAU
		var ca := cos(ang)
		var sa := sin(ang) * 0.66
		_blend(img, int(lake_isl.x + ca * (lake_isl.z + 0.8)),
				int(lake_isl.y + sa * (lake_isl.z + 0.8)), C_WATERLINE, 0.35)
		if sa > -0.2:
			_blend(img, int(lake_isl.x + ca * (lake_isl.z + 1.8)),
					int(lake_isl.y + sa * (lake_isl.z + 1.8)), C_SHADOW, 0.22)
	return img


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


static func _double(src: Image) -> Image:
	var out := src.duplicate()
	out.resize(src.get_width() * 2, src.get_height() * 2, Image.INTERPOLATE_NEAREST)
	return out


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	img.set_pixel(x, y, c)


static func _blend(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var sa := clampf(a, 0.0, 1.0)
	var bg := img.get_pixel(x, y)
	if bg.a < 0.001:
		img.set_pixel(x, y, Color(c.r, c.g, c.b, sa))
		return
	# 正确的 source-over：保留半透明图层（倒影/芦苇簇）的 alpha。
	var oa := sa + bg.a * (1.0 - sa)
	if oa < 0.001:
		return
	var rgb := (Vector3(c.r, c.g, c.b) * sa + Vector3(bg.r, bg.g, bg.b) * bg.a * (1.0 - sa)) / oa
	img.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, oa))


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
				_blend(img, x, y, C_SHADOW, a * (1.0 - q * 0.45))


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
