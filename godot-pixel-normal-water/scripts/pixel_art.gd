class_name NormalWaterArt
extends RefCounted

# 全程序化原创像素夜景：天空/远山/河岸/木屋/杂货铺/枫树/松树/街灯/石头/码头。
# 每个受光物件同时生成 albedo、法线（R/G/B）与粗糙度；
# 自发光遮罩写在法线图 alpha 里（0=无，1=灯窗/灯芯）。
# 不加载任何外部贴图；固定种子保证每次启动一致。

const W := 320
const H := 180
const WATERLINE := 120

# —— 夜色调色板 ——
const SKY_TOP := Color(0.008, 0.027, 0.055)
const SKY_MID := Color(0.027, 0.082, 0.125)
const SKY_LOW := Color(0.055, 0.155, 0.180)
const SKY_HORIZON := Color(0.085, 0.205, 0.205)
const NIGHT_BLUE := Color(0.043, 0.105, 0.145)
const HILL_FAR := Color(0.043, 0.115, 0.150)
const HILL_NEAR := Color(0.061, 0.152, 0.173)
const FOG := Color(0.145, 0.300, 0.305)
const MOON := Color(0.84, 0.90, 0.79)
const MOON_DARK := Color(0.55, 0.68, 0.65)
const STAR := Color(0.68, 0.82, 0.78)

const INK := Color(0.075, 0.065, 0.070)
const WALL := Color(0.57, 0.44, 0.32)
const WALL_LIGHT := Color(0.70, 0.56, 0.41)
const WALL_DARK := Color(0.38, 0.29, 0.24)
const TIMBER := Color(0.20, 0.145, 0.125)
const TIMBER_LIGHT := Color(0.32, 0.235, 0.18)
const ROOF := Color(0.19, 0.27, 0.29)
const ROOF_DARK := Color(0.10, 0.16, 0.18)
const ROOF_LIGHT := Color(0.30, 0.39, 0.40)
const STONE := Color(0.32, 0.36, 0.34)
const STONE_LIGHT := Color(0.46, 0.49, 0.44)
const STONE_DARK := Color(0.18, 0.23, 0.22)
const IRON := Color(0.11, 0.13, 0.13)
const IRON_LIGHT := Color(0.26, 0.30, 0.28)
const GOLD := Color(1.00, 0.72, 0.34)
const GOLD_HOT := Color(1.00, 0.90, 0.60)
const GOLD_DEEP := Color(0.76, 0.38, 0.16)
const GLASS_COOL := Color(0.22, 0.37, 0.42)
const GLASS_COOL_LIGHT := Color(0.40, 0.60, 0.62)
const PLANT := Color(0.33, 0.42, 0.26)
const PLANT_LIGHT := Color(0.46, 0.55, 0.31)
const CORAL := Color(0.62, 0.34, 0.35)
const CORAL_LIGHT := Color(0.78, 0.48, 0.44)
const MAPLE_DARK := Color(0.29, 0.18, 0.25)
const MAPLE_MID := Color(0.53, 0.29, 0.34)
const MAPLE_LIGHT := Color(0.73, 0.43, 0.42)
const MAPLE_TIP := Color(0.88, 0.60, 0.49)
const PINE_DARK := Color(0.075, 0.165, 0.185)
const PINE_MID := Color(0.13, 0.26, 0.27)
const PINE_LIGHT := Color(0.23, 0.38, 0.35)
const WOOD := Color(0.34, 0.25, 0.20)
const WOOD_LIGHT := Color(0.49, 0.36, 0.26)
const WOOD_DARK := Color(0.20, 0.145, 0.13)
const WATER_SHORE := Color(0.040, 0.185, 0.200)
const WATER_DEEP := Color(0.020, 0.075, 0.100)


static func build_scene_art() -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var sky := build_sky()
	var mask := build_water_mask()
	var water := build_water_base(mask)
	var t_bg := Time.get_ticks_msec()
	var bank := build_bank()
	var tavern := build_tavern()
	var townhouse := build_townhouse()
	var maple := build_maple()
	var pine := build_pine()
	var lamp := build_lamp()
	var rock_a := build_rock_cluster(34, 18, 17)
	var rock_b := build_rock_cluster(38, 16, 31)
	var boulder := build_boulder()
	var dock := build_dock()
	var glow := build_glow()
	var t_props := Time.get_ticks_msec()
	print("NORMAL_WATER_ART_MS bg=%d props=%d total=%d" % [
		t_bg - t0, t_props - t_bg, Time.get_ticks_msec() - t0])
	return {
		"sky": sky,
		"mask": mask,
		"water": water,
		"bank": bank,
		"tavern": tavern,
		"townhouse": townhouse,
		"maple": maple,
		"pine": pine,
		"lamp": lamp,
		"rock_quay": rock_a,
		"rock_wall": rock_b,
		"boulder": boulder,
		"dock": dock,
		"glow": glow,
	}


# ── 基础小工具 ───────────────────────────────────────────────────────────
static func _blend_pixel(img: Image, x: int, y: int, c: Color, a: float) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var old := img.get_pixel(x, y)
	var k := clampf(a, 0.0, 1.0)
	img.set_pixel(x, y, Color(
		old.r + (c.r - old.r) * k,
		old.g + (c.g - old.g) * k,
		old.b + (c.b - old.b) * k,
		maxf(old.a, k)))


static func _bayer4(x: int, y: int) -> float:
	var m := [
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0,
	]
	return (m[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


static func _grass_tuft(s: PixelSurface, x: int, y: int, seed_value: int) -> void:
	var h := 2 + int(PixelSurface.noise01(x, y, seed_value) * 3.0)
	var c := PLANT if PixelSurface.noise01(x + 1, y, seed_value) < 0.5 else PLANT_LIGHT
	for i in h:
		s.px(x + (i % 2), y - i, c, 0.45, 0.9)
	s.px(x + 1, y - h, PLANT_LIGHT, 0.5, 0.9)


# ── 天空 / 远山 / 远镇 / 月亮 ────────────────────────────────────────────
static func build_sky() -> Dictionary:
	var s := PixelSurface.new(W, H)
	# 竖向渐变 + 4×4 有序抖动，避免 8-bit 色带。
	for y in 106:
		var c: Color
		if y < 50:
			c = SKY_TOP.lerp(SKY_MID, float(y) / 50.0)
		elif y < 84:
			c = SKY_MID.lerp(SKY_LOW, float(y - 50) / 34.0)
		else:
			c = SKY_LOW.lerp(SKY_HORIZON, float(y - 84) / 22.0)
		for x in W:
			var d := (_bayer4(x, y) - 0.5) * 0.020
			s.px(x, y, Color(
				clampf(c.r + d * 0.45, 0.0, 1.0),
				clampf(c.g + d, 0.0, 1.0),
				clampf(c.b + d * 0.8, 0.0, 1.0)))
	for y in range(106, H):
		s.vgradient(0, y, W - 1, y, SKY_HORIZON, WATER_DEEP)

	# 星星：固定哈希位置，少量十字亮星。
	for i in 86:
		var x := int(PixelSurface.noise01(i, 11, 71) * float(W))
		var y := 2 + int(PixelSurface.noise01(i, 19, 71) * 82.0)
		var moon_d := Vector2(x - 252, y - 26).length()
		if moon_d < 22.0:
			continue
		var bright := 0.30 + PixelSurface.noise01(i, 23, 71) * 0.60
		var c := STAR.lerp(Color(0.84, 0.80, 0.63), PixelSurface.noise01(i, 29, 71))
		s.px(x, y, c.darkened(1.0 - bright), 0.0, 0.0)
		if bright > 0.82:
			s.px(x - 1, y, Color(c.r, c.g, c.b).darkened(0.28))
			s.px(x + 1, y, Color(c.r, c.g, c.b).darkened(0.45))
			s.px(x, y - 1, Color(c.r, c.g, c.b).darkened(0.38))
			s.px(x, y + 1, Color(c.r, c.g, c.b).darkened(0.55))

	# 月晕：径向抖动，颜色逐段混进当前天空。
	for y in range(2, 50):
		for x in range(226, 279):
			var d := Vector2(x + 0.5 - 252.0, y + 0.5 - 26.0).length()
			if d < 24.0:
				var alpha := pow(1.0 - d / 24.0, 2.3) * 0.23
				var stepa: float = floor(alpha * 14.0) / 14.0
				if _bayer4(x, y) < stepa * 4.0:
					var old := s.image.get_pixel(x, y)
					s.px(x, y, old.lerp(Color(0.52, 0.69, 0.70), 0.55))
	# 月盘
	s.disc(252.0, 26.0, 9.4, 9.4, MOON)
	s.disc(252.5, 27.0, 8.2, 8.2, Color(0.77, 0.85, 0.74))
	for p in [Vector2i(248, 22), Vector2i(255, 30), Vector2i(251, 31),
			Vector2i(257, 23), Vector2i(246, 29)]:
		s.disc(float(p.x), float(p.y), 1.3, 1.1, MOON_DARK)
	s.px(248, 19, Color(0.94, 0.97, 0.86))
	s.px(243, 30, Color(0.65, 0.74, 0.67))
	# 薄云穿过月亮下半部
	for x in range(224, 285):
		var top := 31 + int(round(1.4 * sin(float(x) * 0.19)))
		for y in range(top, top + 3):
			if _bayer4(x, y) < 0.62 and PixelSurface.noise01(x, y, 97) < 0.8:
				_blend_pixel(s.image, x, y, Color(0.10, 0.18, 0.24), 0.55)

	# 远山两层
	for x in W:
		var top1 := 85 + int(round(4.5 * sin(float(x) * 0.071 + 0.7)
				+ 2.5 * sin(float(x) * 0.029 + 2.1)))
		for y in range(top1, 106):
			var n := PixelSurface.noise01(x, y, 5) * 0.05
			var c := HILL_FAR.lerp(HILL_NEAR, clampf(float(y - top1) / 28.0, 0.0, 1.0))
			s.px(x, y, Color(c.r + n, c.g + n, c.b + n))
	for x in W:
		var top2 := 93 + int(round(2.4 * sin(float(x) * 0.121 + 2.9)
				+ 1.2 * sin(float(x) * 0.37)))
		for y in range(top2, 108):
			var c := HILL_NEAR.darkened(0.14 + 0.10 * (float(y - top2) / 15.0))
			s.px(x, y, c)

	# 远景小镇：稀疏屋顶与 1px 暖窗，只在建筑间空隙里露出来。
	var far_blocks := [
		Vector4i(148, 86, 21, 20), Vector4i(175, 80, 13, 26),
		Vector4i(191, 88, 11, 18), Vector4i(280, 86, 14, 18),
		Vector4i(300, 82, 13, 22),
	]
	for b in far_blocks:
		var bx: int = b.x
		var by: int = b.y
		var bw: int = b.z
		var bh: int = b.w
		s.rect(bx, by, bx + bw - 1, by + bh, Color(0.055, 0.125, 0.155))
		# 坡屋顶
		s.line(bx - 1, by, bx + bw / 2, by - 3, Color(0.075, 0.155, 0.18))
		s.line(bx + bw / 2, by - 3, bx + bw, by, Color(0.075, 0.155, 0.18))
		for wy in range(by + 4, by + bh - 2, 5):
			for wx in range(bx + 2, bx + bw - 1, 5):
				if PixelSurface.noise01(wx, wy, 44) > 0.55:
					s.px(wx, wy, Color(0.90, 0.63, 0.29), 0.0, 0.0, 0.0)
	# 远处两层小塔，作为空隙中的视觉锚点
	_far_pagoda(s, 177, 73)
	s.rect(282, 76, 286, 96, Color(0.05, 0.12, 0.145))
	s.line(277, 77, 290, 77, Color(0.08, 0.16, 0.18))
	s.line(279, 72, 288, 72, Color(0.08, 0.16, 0.18))
	s.px(285, 82, Color(0.83, 0.57, 0.28))

	# 河面雾带
	for y in range(94, 101):
		for x in W:
			if _bayer4(x, y) < 0.30 and PixelSurface.noise01(x, y, 13) > 0.44:
				_blend_pixel(s.image, x, y, FOG, 0.24)
	for i in 12:
		var fx := int(PixelSurface.noise01(i, 3, 222) * 310.0) + 5
		var fy := 96 + int(PixelSurface.noise01(i, 4, 222) * 3.0)
		_blend_pixel(s.image, fx, fy, FOG, 0.20)
	return {"image": s.image}


static func _far_pagoda(s: PixelSurface, cx: int, top: int) -> void:
	var dark := Color(0.045, 0.105, 0.125)
	s.rect(cx - 2, top + 8, cx + 2, top + 23, dark)
	for i in 3:
		var y := top + 3 + i * 6
		var half := 7 + i * 2
		s.line(cx - half, y, cx + half, y, Color(0.065, 0.135, 0.16))
		s.line(cx - half + 1, y + 1, cx + half - 1, y + 1, dark)
		s.px(cx - half + 3, y + 3, Color(0.34, 0.34, 0.22))
		s.px(cx + half - 3, y + 3, Color(0.34, 0.34, 0.22))
	s.px(cx, top, Color(0.09, 0.17, 0.18))
	s.px(cx, top + 1, Color(0.09, 0.17, 0.18))
	s.px(cx, top + 19, Color(0.89, 0.61, 0.28))


# ── 水面遮罩 / 水底色 ────────────────────────────────────────────────────
static func build_water_mask() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for x in W:
		# 岸线用 1px 抖动；水面从水线往下一律裁切。
		var edge := WATERLINE
		if PixelSurface.noise01(x, 0, 90) > 0.78:
			edge = WATERLINE - 1
		for y in range(edge, H):
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
	return img


static func build_water_base(mask: Image) -> Dictionary:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(WATERLINE, H):
		var depth := float(y - WATERLINE) / float(H - WATERLINE)
		var c := WATER_SHORE.lerp(WATER_DEEP, depth)
		for x in W:
			if mask.get_pixel(x, y).a < 0.5:
				continue
			var n := (PixelSurface.noise01(x, y, 19) - 0.5) * 0.018
			var band := 0.0
			if y % 7 == 0 and x % 11 < 5:
				band = 0.012
			if y % 13 == 3 and x % 17 < 3:
				band = -0.010
			# 靠近岸边的月光/天空反光更亮，深处更暗。
			var sky_mix := (1.0 - minf(depth * 2.6, 1.0)) * 0.16
			var col := c.lerp(Color(0.16, 0.36, 0.38), sky_mix)
			col = col.lightened(band)
			col = Color(col.r + n, col.g + n, col.b + n)
			img.set_pixel(x, y, col)
	# 一列很淡的月影，动画波光由 water overlay 叠加
	for y in range(WATERLINE + 2, 166):
		var depth := float(y - WATERLINE) / 60.0
		var spread := 2.0 + depth * 8.0
		for x in range(int(252.0 - spread), int(252.0 + spread) + 1):
			if (x + y) % 5 > 1 and PixelSurface.noise01(x, y, 321) > 0.46:
				_blend_pixel(img, x, y, Color(0.47, 0.62, 0.49), 0.10)
	# 几片漂浮的暗叶
	for p in [Vector2i(152, 137), Vector2i(163, 144), Vector2i(218, 154)]:
		img.set_pixel(p.x, p.y, Color(0.20, 0.31, 0.23))
		img.set_pixel(p.x + 1, p.y, Color(0.27, 0.37, 0.25))
		img.set_pixel(p.x, p.y + 1, Color(0.10, 0.20, 0.17))
	return {"image": img}


# ── 石板河岸 ─────────────────────────────────────────────────────────────
static func build_bank() -> Dictionary:
	var s := PixelSurface.new(W, 24)
	# 深色泥土地基：上方是湿苔河岸，下方接近水线更暗。
	for y in 24:
		var t := float(y) / 23.0
		var base := Color(0.105, 0.135, 0.115).lerp(Color(0.075, 0.105, 0.105), t)
		for x in W:
			var n := (PixelSurface.noise01(x, y, 9) - 0.5) * 0.05
			s.px(x, y, Color(base.r + n, base.g + n, base.b + n), 0.30, 0.95)
	# 上缘湿苔
	for x in W:
		if PixelSurface.noise01(x, 1, 3) > 0.42:
			s.px(x, 0, Color(0.15, 0.21, 0.14), 0.30, 0.96)
		if PixelSurface.noise01(x, 2, 4) > 0.62:
			s.px(x, 1, Color(0.11, 0.17, 0.12), 0.28, 0.96)
	# 不规则鹅卵石铺地：每块石头独立椭圆 + 暗缝，避免整排横线。
	for row in 4:
		var cols := 27 if row < 3 else 22
		for col in cols:
			var jx := int(PixelSurface.noise01(col, row, 32) * 5.0) - 2
			var jy := int(PixelSurface.noise01(col, row, 33) * 2.0) - 1
			var cx := col * (12 if row < 3 else 15) + (5 if row % 2 == 1 else 0) + 4 + jx
			var cy := 4 + row * 5 + jy
			if row == 3:
				cy = 19 + jy
			if cx < 2 or cx > W - 3:
				continue
			var rx := 4.0 + PixelSurface.noise01(col, row, 34) * 2.7
			var ry := 2.0 + PixelSurface.noise01(col, row, 35) * 1.2
			if row == 3:
				rx += 1.0
				ry += 0.5
			var shade := 0.68 + PixelSurface.noise01(col, row, 36) * 0.36
			var stone := Color(0.16, 0.20, 0.19).lerp(Color(0.30, 0.33, 0.30), shade)
			# 暗缝/阴影底
			s.disc(cx, cy + 1, rx + 1.3, ry + 1.0, Color(0.045, 0.075, 0.078), 0.20, 0.97)
			# 石面
			s.disc(cx, cy, rx, ry, stone, 0.36 + shade * 0.14, 0.93)
			# 只有一部分石头接月光，避免均匀高光
			if PixelSurface.noise01(col, row, 38) > 0.50:
				s.hline(int(cx - rx + 1.0), int(cx + rx - 1.0), int(cy - ry),
						stone.lightened(0.12), 0.47, 0.92)
			if PixelSurface.noise01(col, row, 39) > 0.55:
				s.px(int(cx), int(cy + ry - 0.5), stone.lightened(0.05), 0.42, 0.93)
			# 石块边角的苔藓/缝隙
			if PixelSurface.noise01(col, row, 40) > 0.78:
				s.px(int(cx - rx), int(cy), Color(0.19, 0.27, 0.17), 0.39, 0.96)
				s.px(int(cx - rx) + 1, int(cy) - 1, Color(0.25, 0.33, 0.20), 0.41, 0.95)
	# 临水压顶石：一条明确的石砌岸线，让建筑/树有“站得住”的地面，
	# 同时与上面散乱鹅卵石区分开。
	for col in 16:
		var x0 := col * 20 + (7 if col % 2 == 0 else 0)
		var x1 := mini(x0 + 19, W - 1)
		var shade := 0.70 + PixelSurface.noise01(col, 3, 63) * 0.32
		var slab := Color(0.13, 0.17, 0.17).lerp(Color(0.28, 0.31, 0.29), shade)
		s.rect(maxi(x0, 0), 17, x1, 21, slab, 0.46 + shade * 0.12, 0.92)
		s.hline(maxi(x0, 0), x1, 17, slab.lightened(0.10), 0.58, 0.90)
		s.hline(maxi(x0, 0), x1, 21, Color(0.07, 0.10, 0.10), 0.30, 0.96)
		if x0 > 0:
			s.px(x0, 17, Color(0.06, 0.09, 0.09), 0.34, 0.97)
			s.px(x0, 18, Color(0.06, 0.09, 0.09), 0.30, 0.97)
	# 水线暗影与湿石
	for x in W:
		s.px(x, 22, Color(0.055, 0.09, 0.095), 0.20, 0.98)
		s.px(x, 23, Color(0.028, 0.060, 0.072), 0.16, 0.99)
	# 草丛、苔藓、系船环
	for x in [15, 44, 86, 121, 151, 193, 231, 272, 307]:
		if PixelSurface.noise01(x, 6, 7) > 0.22:
			_grass_tuft(s, x, 3, 7 + x)
	for p in [Vector2i(71, 3), Vector2i(72, 3), Vector2i(143, 2), Vector2i(241, 3)]:
		s.px(p.x, p.y, Color(0.28, 0.37, 0.23), 0.36, 0.96)
		s.px(p.x, p.y - 1, Color(0.37, 0.46, 0.28), 0.40, 0.95)
	for cx in [101, 219]:
		s.hline(cx - 2, cx + 2, 18, IRON_LIGHT.darkened(0.18), 0.54, 0.55)
		s.hline(cx - 2, cx + 2, 19, IRON, 0.52, 0.55)
		s.px(cx, 20, IRON_LIGHT.darkened(0.25), 0.5, 0.55)
	# 水线附近几块较大的湿石
	for p in [Vector2i(33, 20), Vector2i(49, 21), Vector2i(167, 20),
			Vector2i(186, 21), Vector2i(286, 20)]:
		s.disc(p.x, p.y, 4.5, 2.2, Color(0.12, 0.17, 0.16), 0.38, 0.95)
		s.px(p.x - 1, p.y - 2, Color(0.26, 0.31, 0.28), 0.46, 0.93)
	return s.finish(2.2)


# ── 酒馆 ─────────────────────────────────────────────────────────────────
static func _window(s: PixelSurface, x0: int, y0: int, x1: int, y1: int,
		warm: bool, arched := false) -> void:
	# 外框
	s.rect(x0 - 1, y0 - 1, x1 + 1, y1 + 1, TIMBER, 0.52, 0.68)
	s.rect(x0, y0, x1, y1, TIMBER_LIGHT, 0.58, 0.66)
	var glass_top := y0 if not arched else y0 + 1
	if arched:
		for x in range(x0, x1 + 1):
			if x < x0 + 2 or x > x1 - 2:
				s.px(x, y0, TIMBER_LIGHT, 0.58, 0.66)
	# 玻璃：暖窗用暗琥珀底 + 少量亮芯；发光遮罩也逐像素变化，
	# 不让整扇窗变成一块纯白自发光卡片。
	for y in range(glass_top, y1):
		for x in range(x0 + 1, x1):
			var lit := warm
			var c: Color
			if lit:
				var t := float(y - glass_top) / maxf(float(y1 - glass_top), 1.0)
				c = GOLD_DEEP.darkened(0.22).lerp(GOLD_DEEP, 0.25 + t * 0.48)
				if (x * 3 + y * 5) % 17 == 0:
					c = GOLD
				if x == x0 + 1 and y == glass_top + 1:
					c = GOLD_HOT
				if y == y1 - 1:
					c = c.darkened(0.28)
			else:
				c = GLASS_COOL.lerp(GLASS_COOL_LIGHT,
						0.22 + 0.38 * float(y - glass_top) / maxf(float(y1 - glass_top), 1.0))
				if (x - y) % 11 == 0:
					c = GLASS_COOL_LIGHT.darkened(0.12)
			var emit := 0.0
			if lit:
				emit = 0.48 + 0.20 * float(y - glass_top) / maxf(float(y1 - glass_top), 1.0)
			s.px(x, y, c, 0.20, 0.16 if lit else 0.30, emit)
	# 窗棂
	var mx := (x0 + x1) / 2
	var my := (glass_top + y1) / 2
	s.vline(mx, glass_top, y1 - 1, TIMBER, 0.58, 0.70)
	s.hline(x0 + 1, x1 - 1, my, TIMBER, 0.58, 0.70)
	# 上沿高光与内侧投影
	s.hline(x0, x1, y0, TIMBER_LIGHT.lightened(0.08), 0.62, 0.64)
	s.hline(x0 + 1, x1 - 1, glass_top, Color(0.12, 0.10, 0.09), 0.25, 0.72)
	if warm:
		s.px(x0 + 1, y1 - 1, GOLD_DEEP.darkened(0.25), 0.2, 0.18, 0.20)


static func build_tavern() -> Dictionary:
	var s := PixelSurface.new(92, 82)
	# 屋顶三角
	var ridge := 45
	for x in 92:
		var top := int(round(5.0 + pow(absf(float(x - ridge)) / 45.0, 0.84) * 25.0))
		for y in range(top, 31):
			var row := (y - top) / 3
			var c := ROOF
			if (x + row * 3) % 9 == 0:
				c = ROOF_DARK
			elif (x + row * 2) % 11 == 0:
				c = ROOF_LIGHT
			if row % 2 == 0:
				c = c.lightened(0.03)
			s.px(x, y, c, 0.76 - float(y - top) * 0.007, 0.55)
			# 大形法线：屋脊左右两坡分别朝外、微朝上。
			var side := -1.0 if x < ridge else 1.0
			var slope := absf(float(x - ridge)) / 45.0
			s.normal_px(x, y, side * (0.28 + slope * 0.28), -0.22 - (1.0 - slope) * 0.10)
		# 瓦檐高光 + 外轮廓
		s.px(x, top, ROOF_LIGHT, 0.82, 0.50)
		if x == 0 or x == 91:
			s.px(x, top + 1, ROOF_DARK)
	# 屋脊
	s.line(ridge - 1, 4, ridge + 1, 4, ROOF_LIGHT, 0.9, 0.45)
	for x in range(ridge - 4, ridge + 5):
		s.px(x, 5, ROOF_DARK, 0.84, 0.50)
	# 屋檐底边
	s.rect(0, 30, 91, 33, TIMBER, 0.58, 0.72)
	s.hline(1, 90, 33, TIMBER_LIGHT.darkened(0.1), 0.5, 0.74)
	s.hline(0, 91, 34, Color(0.10, 0.11, 0.12), 0.4, 0.78)
	# 墙面
	s.rect(6, 34, 85, 80, WALL, 0.40, 0.80)
	for y in range(34, 81):
		for x in range(6, 86):
			var n := PixelSurface.noise01(x, y, 61)
			if n > 0.72:
				var old := s.image.get_pixel(x, y)
				s.px(x, y, old.lightened(0.035), 0.40, 0.80)
			if n < 0.13:
				var old2 := s.image.get_pixel(x, y)
				s.px(x, y, old2.darkened(0.04), 0.40, 0.80)
	# 墙面大形法线：轻微凸面，让左右两侧对方向光产生不同的衰减。
	for y in range(34, 74):
		for x in range(6, 86):
			if s.image.get_pixel(x, y).a >= 0.5:
				var nx := clampf((float(x) - 46.0) / 48.0, -1.0, 1.0) * 0.26
				s.normal_px(x, y, nx, -0.03)
	# 檐下阴影
	for y in range(34, 38):
		var c := WALL.darkened(0.10 + 0.13 * float(y - 34))
		s.hline(6, 85, y, c, 0.35, 0.84)
	# 木构架
	for bx in [8, 28, 58, 83]:
		s.vline(bx, 34, 80, TIMBER, 0.60, 0.70)
		s.vline(bx + 1, 34, 80, TIMBER_LIGHT.darkened(0.16), 0.60, 0.70)
	s.hline(6, 85, 34, TIMBER, 0.62, 0.68)
	s.hline(6, 85, 35, TIMBER_LIGHT.darkened(0.12), 0.60, 0.68)
	s.hline(6, 85, 53, TIMBER, 0.62, 0.68)
	s.hline(6, 85, 54, TIMBER_LIGHT.darkened(0.12), 0.60, 0.68)
	s.hline(6, 85, 78, TIMBER, 0.60, 0.70)
	# 斜撑
	s.line(11, 37, 26, 51, TIMBER, 0.56, 0.72)
	s.line(12, 37, 27, 51, TIMBER_LIGHT.darkened(0.2), 0.56, 0.72)
	s.line(60, 37, 81, 51, TIMBER, 0.56, 0.72)
	s.line(59, 37, 80, 51, TIMBER_LIGHT.darkened(0.2), 0.56, 0.72)

	# 两层窗
	_window(s, 14, 39, 25, 49, true)
	_window(s, 34, 38, 52, 50, true)
	_window(s, 64, 39, 78, 49, false)
	# 窗台花箱
	for box_x in [13, 33, 63]:
		var x0: int = int(box_x)
		s.rect(x0, 50, x0 + 13, 52, WOOD_DARK, 0.7, 0.76)
		for i in 6:
			var x: int = x0 + 1 + i * 2
			var c := CORAL_LIGHT if i % 2 == 0 else CORAL
			s.px(x, 49, c, 0.62, 0.84)
			s.px(x + 1, 50, PLANT, 0.6, 0.88)

	# 底层：大橱窗 + 门 + 右侧冷窗
	_window(s, 14, 59, 36, 71, true)
	# 橱窗里的酒瓶/杯子剪影
	for i in 4:
		var x := 17 + i * 5
		s.vline(x, 63, 68, Color(0.31, 0.20, 0.16), 0.18, 0.16, 0.2)
		s.px(x, 62, Color(0.88, 0.72, 0.42), 0.2, 0.16, 0.5)
	s.rect(11, 56, 39, 58, Color(0.25, 0.20, 0.16), 0.66, 0.78)
	# 遮雨棚
	for x in range(11, 40):
		var c := Color(0.24, 0.39, 0.36) if (x / 4) % 2 == 0 else Color(0.60, 0.46, 0.30)
		s.px(x, 56, c, 0.72, 0.76)
		s.px(x, 57, c.darkened(0.22), 0.68, 0.78)
	for x in range(11, 40, 4):
		s.px(x, 58, TIMBER, 0.62, 0.80)
	# 门
	s.rect(42, 57, 54, 80, TIMBER, 0.52, 0.70)
	s.rect(43, 59, 53, 80, Color(0.22, 0.14, 0.11), 0.22, 0.72)
	s.rect(44, 61, 52, 79, GOLD_DEEP.darkened(0.35), 0.25, 0.66, 0.55)
	for y in range(61, 80, 4):
		s.hline(45, 51, y, Color(0.42, 0.24, 0.14), 0.31, 0.72)
	s.px(51, 71, GOLD_HOT, 0.4, 0.36, 0.8)
	s.px(52, 71, GOLD, 0.4, 0.36, 0.5)
	s.rect(44, 58, 52, 58, TIMBER_LIGHT, 0.64, 0.70)
	# 冷窗
	_window(s, 61, 59, 79, 71, false)
	# 门牌/小招牌
	s.rect(58, 56, 62, 58, WOOD_DARK, 0.7, 0.78)
	s.px(60, 57, GOLD, 0.8, 0.4, 0.9)

	# 右侧悬挂招牌
	s.line(82, 39, 91, 39, IRON, 0.66, 0.50)
	s.line(84, 39, 84, 43, IRON, 0.62, 0.52)
	s.rect(80, 43, 90, 55, WOOD_DARK, 0.64, 0.74)
	s.rect(81, 44, 89, 54, Color(0.41, 0.27, 0.18), 0.7, 0.72)
	# 金色小酒杯
	s.rect(83, 47, 87, 51, GOLD_DEEP, 0.78, 0.42, 0.55)
	s.px(84, 48, GOLD_HOT, 0.8, 0.36, 0.8)
	s.line(88, 48, 89, 48, GOLD, 0.78, 0.42)
	s.line(88, 49, 89, 50, GOLD_DEEP, 0.78, 0.42)
	s.line(87, 52, 88, 52, Color(0.66, 0.39, 0.16))

	# 石基 + 台阶
	s.rect(4, 73, 88, 80, STONE_DARK, 0.45, 0.88)
	for row in 2:
		for col in 9:
			var x0 := 5 + col * 9 + (3 if row % 2 == 1 else 0)
			var y0 := 73 + row * 4
			var c := STONE.darkened(0.12 + PixelSurface.noise01(col, row, 29) * 0.16)
			s.rect(x0, y0, mini(x0 + 8, 88), y0 + 3, c, 0.48, 0.88)
			s.hline(x0, mini(x0 + 8, 88), y0, STONE_LIGHT.darkened(0.22), 0.56, 0.86)
	# 台阶和门垫
	s.rect(40, 77, 56, 81, STONE, 0.62, 0.86)
	s.rect(42, 78, 54, 79, STONE_LIGHT, 0.66, 0.82)
	# 底部高光/阴影，压住脚底
	for x in range(4, 89):
		if PixelSurface.noise01(x, 81, 48) > 0.35:
			s.px(x, 81, STONE_DARK.darkened(0.15), 0.32, 0.92)

	# 烟囱
	s.rect(66, 0, 77, 19, Color(0.32, 0.21, 0.18), 0.90, 0.82)
	for y in range(2, 18, 3):
		s.hline(67, 76, y, Color(0.24, 0.15, 0.13), 0.86, 0.82)
	for row in 4:
		for col in 2:
			var x := 68 + col * 4 + (1 if row % 2 == 0 else 0)
			s.px(x, 2 + row * 4, Color(0.44, 0.29, 0.23), 0.92, 0.80)
	s.rect(64, 0, 79, 2, STONE_DARK, 0.96, 0.78)
	s.hline(64, 79, 0, STONE, 0.96, 0.76)
	# 轻烟（静态像素团，不额外做粒子）
	for p in [Vector2i(73, -1), Vector2i(76, -3), Vector2i(71, -5)]:
		if p.y >= 0:
			s.px(p.x, p.y, Color(0.26, 0.34, 0.36), 0.0, 0.95)
	# 屋脊上的小鸟
	s.rect(36, 3, 38, 5, INK, 0.0, 0.9)
	s.px(39, 3, INK, 0.0, 0.9)
	s.px(38, 2, INK, 0.0, 0.9)
	s.px(35, 4, Color(0.08, 0.12, 0.13), 0.0, 0.9)
	# 墙脚苔藓/藤蔓
	for x in [9, 12, 53, 70, 86]:
		for i in 3 + int(PixelSurface.noise01(x, 8, 4) * 4):
			var c := PLANT.darkened(0.15 + 0.1 * i)
			s.px(x + (i % 2), 80 - i, c, 0.48, 0.92)
	for p in [Vector2i(2, 75), Vector2i(3, 73), Vector2i(1, 78)]:
		s.px(p.x, p.y, WOOD_DARK, 0.62, 0.80)
	return s.finish(1.9)


# ── 杂货铺 ───────────────────────────────────────────────────────────────
static func build_townhouse() -> Dictionary:
	var s := PixelSurface.new(74, 72)
	# 屋顶
	for x in range(0, 74):
		var top := 5 + int(round(pow(absf(float(x - 29)) / 45.0, 0.9) * 14.0))
		for y in range(top, 20):
			var c := ROOF.lerp(ROOF_LIGHT, 0.10)
			if y % 3 == 0:
				c = ROOF_DARK
			elif (x + y) % 13 == 0:
				c = ROOF_LIGHT
			s.px(x, y, c, 0.72 - float(y - top) * 0.006, 0.58)
			var side := -1.0 if x < 29 else 1.0
			var slope := absf(float(x - 29)) / 45.0
			s.normal_px(x, y, side * (0.24 + slope * 0.24), -0.20)
		s.px(x, top, ROOF_LIGHT, 0.80, 0.52)
	s.rect(0, 19, 73, 21, TIMBER, 0.56, 0.74)
	s.hline(1, 72, 21, TIMBER_LIGHT.darkened(0.12), 0.5, 0.76)
	# 烟囱
	s.rect(54, 0, 63, 13, Color(0.31, 0.22, 0.20), 0.92, 0.84)
	s.rect(53, 0, 64, 2, STONE_DARK, 0.96, 0.80)
	s.hline(53, 64, 0, STONE, 0.98, 0.76)
	for y in range(3, 12, 3):
		s.hline(55, 62, y, Color(0.23, 0.16, 0.15), 0.88, 0.84)

	# 上层墙：灰绿色灰泥 + 木构
	s.rect(5, 21, 68, 46, Color(0.36, 0.43, 0.37), 0.42, 0.82)
	for y in range(21, 47):
		for x in range(5, 69):
			if PixelSurface.noise01(x, y, 104) > 0.76:
				var old := s.image.get_pixel(x, y)
				s.px(x, y, old.lightened(0.035), 0.42, 0.82)
	for y in range(21, 47):
		for x in range(5, 69):
			if s.image.get_pixel(x, y).a >= 0.5:
				s.normal_px(x, y, clampf((float(x) - 37.0) / 38.0, -1.0, 1.0) * 0.22, -0.02)
	for bx in [7, 25, 48, 66]:
		s.vline(bx, 21, 46, TIMBER, 0.60, 0.72)
	s.hline(5, 68, 22, TIMBER, 0.62, 0.70)
	s.hline(5, 68, 46, TIMBER, 0.62, 0.70)
	s.line(8, 23, 24, 45, TIMBER_LIGHT.darkened(0.18), 0.55, 0.74)
	s.line(49, 23, 65, 45, TIMBER, 0.55, 0.74)
	# 上层三窗
	_window(s, 11, 26, 20, 36, true)
	_window(s, 29, 26, 44, 36, false)
	_window(s, 52, 26, 62, 36, true)
	# 阳台
	s.rect(5, 38, 68, 40, WOOD_DARK, 0.70, 0.76)
	for x in range(7, 68, 4):
		s.vline(x, 41, 45, WOOD, 0.62, 0.78)
		s.px(x, 40, WOOD_LIGHT, 0.64, 0.76)
	s.hline(5, 68, 45, WOOD_LIGHT.darkened(0.15), 0.58, 0.78)
	for x in [12, 38, 58]:
		s.rect(x, 39, x + 7, 41, WOOD, 0.66, 0.78)
		s.px(x + 1, 38, CORAL, 0.62, 0.86)
		s.px(x + 3, 38, CORAL_LIGHT, 0.62, 0.86)
		s.px(x + 5, 38, PLANT_LIGHT, 0.62, 0.86)

	# 底层石墙 + 店面
	s.rect(2, 47, 71, 71, STONE_DARK, 0.44, 0.90)
	for row in 6:
		for col in 12:
			var x0 := 3 + col * 6 + (3 if row % 2 == 1 else 0)
			var y0 := 48 + row * 4
			var c := STONE.darkened(0.08 + PixelSurface.noise01(col, row, 33) * 0.18)
			s.rect(x0, y0, mini(x0 + 5, 70), y0 + 3, c, 0.48 + PixelSurface.noise01(col, row, 36) * 0.12, 0.9)
			s.hline(x0, mini(x0 + 5, 70), y0, STONE_LIGHT.darkened(0.18), 0.55, 0.88)
	# 遮阳棚
	for x in range(7, 35):
		var c := Color(0.56, 0.34, 0.31) if (x / 4) % 2 == 0 else Color(0.73, 0.61, 0.45)
		s.px(x, 49, c, 0.75, 0.76)
		s.px(x, 50, c.darkened(0.22), 0.72, 0.78)
		s.px(x, 51, TIMBER.darkened(0.1), 0.66, 0.8)
	for x in range(7, 35, 4):
		s.px(x, 51, TIMBER, 0.72, 0.78)
	# 大橱窗
	_window(s, 10, 55, 31, 67, true)
	for i in 3:
		var x := 13 + i * 6
		s.rect(x, 60, x + 2, 66, Color(0.36, 0.24, 0.16), 0.22, 0.2, 0.25)
		s.px(x, 59, Color(0.92, 0.78, 0.48), 0.22, 0.2, 0.5)
	# 门
	s.rect(36, 53, 47, 71, TIMBER, 0.56, 0.70)
	s.rect(37, 55, 46, 71, Color(0.17, 0.13, 0.12), 0.2, 0.74)
	s.rect(38, 56, 45, 70, Color(0.31, 0.20, 0.14), 0.25, 0.7, 0.4)
	s.px(44, 62, GOLD, 0.4, 0.38, 0.7)
	s.px(39, 57, GOLD_HOT, 0.25, 0.5, 0.4)
	s.rect(35, 53, 48, 54, TIMBER_LIGHT, 0.65, 0.70)
	# 右侧冷窗
	_window(s, 51, 55, 64, 67, false)
	# 门边小灯
	s.line(69, 43, 69, 48, IRON, 0.7, 0.5)
	s.rect(65, 48, 71, 56, IRON, 0.72, 0.48)
	s.rect(66, 49, 70, 55, GOLD, 0.78, 0.24, 1.0)
	s.px(67, 50, GOLD_HOT, 0.8, 0.2, 1.0)
	s.px(66, 55, GOLD_DEEP, 0.6, 0.35, 0.7)
	# 小招牌
	s.rect(49, 48, 60, 51, WOOD_DARK, 0.70, 0.76)
	s.px(53, 49, GOLD, 0.78, 0.4, 0.8)
	s.px(55, 49, GOLD_HOT, 0.78, 0.4, 0.9)
	s.px(57, 49, GOLD_DEEP, 0.78, 0.4, 0.6)
	# 台阶 + 门口杂物
	s.rect(34, 69, 50, 71, STONE, 0.64, 0.88)
	for p in [Vector2i(4, 68), Vector2i(6, 68), Vector2i(65, 68)]:
		s.px(p.x, p.y, PLANT, 0.56, 0.9)
	return s.finish(2.0)


# ── 枫树 ─────────────────────────────────────────────────────────────────
static func build_maple() -> Dictionary:
	var s := PixelSurface.new(62, 76)
	# 主干、枝杈与根
	s.line(30, 75, 31, 46, Color(0.23, 0.155, 0.135), 0.55, 0.82)
	s.line(30, 62, 30, 51, Color(0.29, 0.20, 0.16), 0.58, 0.80)
	s.line(30, 54, 22, 39, Color(0.21, 0.145, 0.125), 0.52, 0.84)
	s.line(31, 55, 41, 36, Color(0.21, 0.145, 0.125), 0.52, 0.84)
	s.line(31, 49, 34, 30, Color(0.19, 0.13, 0.12), 0.5, 0.84)
	s.rect(27, 64, 34, 75, Color(0.25, 0.17, 0.14), 0.5, 0.86)
	for i in 5:
		s.line(28 + (i % 2), 66 + i * 2, 26 + (i % 2), 73 + i, Color(0.15, 0.105, 0.10))
	s.line(25, 75, 31, 69, Color(0.22, 0.15, 0.13), 0.48, 0.88)
	s.line(37, 75, 31, 69, Color(0.22, 0.15, 0.13), 0.48, 0.88)
	s.rect(25, 74, 38, 75, Color(0.24, 0.17, 0.12), 0.4, 0.9)
	# 树冠：先铺暗底，再一层完整云团，最后只给朝光面加亮块。
	# 不用随机噪点铺满树冠；轮廓与体积由团块的拼接关系决定。
	var clusters: Array[Vector4] = [
		Vector4(31, 11, 13, 8), Vector4(19, 21, 12, 10),
		Vector4(44, 20, 13, 10), Vector4(9, 35, 9, 8),
		Vector4(53, 34, 10, 8), Vector4(26, 36, 14, 11),
		Vector4(41, 39, 12, 10), Vector4(15, 47, 8, 7),
		Vector4(49, 47, 8, 7), Vector4(31, 49, 12, 9),
	]
	for i in clusters.size():
		var b: Vector4 = clusters[i]
		var dark := MAPLE_DARK.darkened(0.10 + PixelSurface.noise01(i, 4, 15) * 0.10)
		s.disc(b.x + 0.6, b.y + 1.2, b.z + 1.4, b.w + 1.4, dark, 0.40, 0.94)
	for i in clusters.size():
		var b: Vector4 = clusters[i]
		var mid := MAPLE_MID.lerp(MAPLE_LIGHT, PixelSurface.noise01(i, 8, 17) * 0.26)
		s.disc(b.x, b.y, b.z, b.w, mid, 0.52 + 0.06 * PixelSurface.noise01(i, 2, 2), 0.93)
	# 叶簇高光：不用一整个大亮圆，改用多个 2–4px 的小叶团，
	# 这样树冠不会变成粉色气泡，而是能看出叶簇层次。
	for i in clusters.size():
		var b: Vector4 = clusters[i]
		for j in 7:
			var nx := PixelSurface.noise01(i, j * 3, 111) - 0.72
			var ny := PixelSurface.noise01(i, j * 3 + 1, 112) - 0.64
			var hx := b.x + nx * b.z * 1.45
			var hy := b.y - 0.10 * b.w + ny * b.w * 1.25
			var rr := 1.4 + PixelSurface.noise01(i, j * 3 + 2, 113) * 2.4
			var light := MAPLE_LIGHT.lerp(MAPLE_TIP,
					PixelSurface.noise01(i, j, 114) * 0.45)
			s.disc(hx, hy, rr, rr * 0.82, light, 0.60, 0.92)
			if j % 3 == 0:
				s.px(int(round(hx)) - 1, int(round(hy)) - 1, MAPLE_TIP, 0.66, 0.90)
	# 暗叶缝：稀疏的小块，填出叶簇之间的层次
	for i in clusters.size():
		var b: Vector4 = clusters[i]
		for j in 3:
			var nx := PixelSurface.noise01(i, j * 5 + 3, 121) - 0.55
			var ny := PixelSurface.noise01(i, j * 5 + 4, 122) - 0.40
			if PixelSurface.noise01(i, j, 123) < 0.50:
				continue
			var hx := b.x + nx * b.z * 1.1
			var hy := b.y + ny * b.w * 0.9
			s.disc(hx, hy, 1.3, 1.2, MAPLE_DARK, 0.38, 0.95)
	# 外缘小团块，打碎圆球轮廓
	var lobes: Array[Vector4] = [
		Vector4(7, 28, 4, 4), Vector4(13, 14, 5, 4), Vector4(23, 5, 5, 4),
		Vector4(35, 3, 5, 4), Vector4(47, 8, 5, 4), Vector4(56, 21, 4, 5),
		Vector4(58, 36, 3, 4), Vector4(54, 44, 4, 3), Vector4(43, 54, 4, 3),
		Vector4(29, 57, 4, 3), Vector4(17, 54, 3, 3), Vector4(5, 42, 3, 4),
	]
	for i in lobes.size():
		var b: Vector4 = lobes[i]
		var c := MAPLE_MID.lerp(MAPLE_TIP, PixelSurface.noise01(i, 5, 37) * 0.5)
		s.disc(b.x, b.y, b.z, b.w, c, 0.56, 0.92)
		if i % 3 == 0:
			s.px(int(b.x) + 1, int(b.y) - 1, MAPLE_TIP, 0.65, 0.9)
	# 少量内部暗缝（固定位置，不是逐像素噪点）
	for p in [Vector2i(22, 24), Vector2i(23, 25), Vector2i(37, 29), Vector2i(38, 30),
			Vector2i(17, 37), Vector2i(45, 43), Vector2i(31, 40), Vector2i(32, 41),
			Vector2i(9, 32), Vector2i(50, 27)]:
		s.px(p.x, p.y, MAPLE_DARK, 0.38, 0.95)
	# 垂下的几串叶
	for p in [Vector2i(13, 55), Vector2i(21, 59), Vector2i(45, 55), Vector2i(39, 60)]:
		s.px(p.x, p.y, MAPLE_MID, 0.52, 0.93)
		s.px(p.x + 1, p.y + 1, MAPLE_DARK, 0.4, 0.95)
		s.px(p.x, p.y + 2, MAPLE_TIP, 0.57, 0.92)
	# 外轮廓：只贴一圈暗梅色，让树从夜色里“立”出来。
	var outline: Array[Vector2i] = []
	for y in 76:
		for x in 62:
			if s.image.get_pixel(x, y).a >= 0.5:
				continue
			var near := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < 62 and ny < 76:
					if s.image.get_pixel(nx, ny).a >= 0.5:
						near = true
						break
			if near:
				outline.append(Vector2i(x, y))
	for p in outline:
		s.px(p.x, p.y, MAPLE_DARK.darkened(0.16), 0.36, 0.95)
	# 树冠高度场：低频团块起伏，让法线光扫过叶簇而不是整片平贴片。
	for y in range(0, 58):
		for x in 62:
			if s.image.get_pixel(x, y).a < 0.5:
				continue
			var wave := PixelSurface.noise01(x / 3, y / 3, 27) * 0.13
			var fine := PixelSurface.noise01(x, y, 31) * 0.035
			s.heights[y * 62 + x] = 0.47 + wave + fine
			var nx := clampf((float(x) - 31.0) / 31.0, -1.0, 1.0) * 0.62
			var ny := clampf((float(y) - 30.0) / 29.0, -1.0, 1.0) * 0.42 - 0.12
			s.normal_px(x, y, nx, ny)
	# 根部草丛
	for x in [19, 24, 38, 43]:
		_grass_tuft(s, x, 73, x + 3)
	return s.finish(2.35)


# ── 松树 ─────────────────────────────────────────────────────────────────
static func build_pine() -> Dictionary:
	var s := PixelSurface.new(34, 64)
	# 树干
	s.rect(15, 20, 19, 63, Color(0.18, 0.14, 0.13), 0.5, 0.86)
	for y in range(24, 62, 5):
		s.px(17, y, Color(0.11, 0.09, 0.09), 0.45, 0.9)
	s.rect(12, 60, 22, 63, Color(0.20, 0.15, 0.13), 0.45, 0.88)
	# 四层锯齿树冠
	for tier in 4:
		var top_y := 1 + tier * 11
		var bottom_y := top_y + 16
		var max_half := 5 + tier * 4
		for y in range(top_y, mini(bottom_y, 60)):
			var k := float(y - top_y) / float(bottom_y - top_y)
			var half := int(round(2.0 + k * max_half
					+ sin(float(y) * 0.9 + tier) * 1.2))
			for x in range(17 - half, 18 + half):
				var c := PINE_DARK
				var n := PixelSurface.noise01(x, y, tier + 4)
				if x > 17 + half / 3:
					c = PINE_MID
				if x > 17 + half / 2 and n > 0.4:
					c = PINE_LIGHT
				if n > 0.82:
					c = PINE_MID.darkened(0.15)
				if y == top_y:
					c = PINE_LIGHT
				s.px(x, y, c, 0.42 + 0.25 * (1.0 - k), 0.9)
		# 分叉针叶尖
		for x in range(17 - max_half - 2, 18 + max_half + 2, 3):
			if PixelSurface.noise01(x, tier, 7) > 0.45:
				s.px(x, bottom_y - 1 + int(PixelSurface.noise01(x, tier, 8) * 2.0), PINE_DARK, 0.34, 0.92)
	# 树冠大形法线：左/右枝叶朝向两侧，顶部微朝上。
	for y in 64:
		for x in 34:
			if s.image.get_pixel(x, y).a >= 0.5:
				s.normal_px(x, y, clampf((float(x) - 17.0) / 17.0, -1.0, 1.0) * 0.45,
						clampf((float(y) - 30.0) / 30.0, -1.0, 1.0) * 0.24 - 0.08)
	# 顶部亮边
	for p in [Vector2i(18, 0), Vector2i(17, 1), Vector2i(19, 1), Vector2i(16, 2)]:
		s.px(p.x, p.y, PINE_LIGHT, 0.65, 0.86)
	# 苔藓脚
	for x in [13, 19, 24]:
		_grass_tuft(s, x, 62, x + 9)
	return s.finish(2.1)


# ── 街灯 ─────────────────────────────────────────────────────────────────
static func build_lamp() -> Dictionary:
	var s := PixelSurface.new(26, 52)
	# 底座
	s.rect(7, 46, 19, 51, IRON, 0.55, 0.42)
	s.hline(6, 20, 51, IRON, 0.48, 0.50)
	s.hline(8, 18, 46, IRON_LIGHT, 0.62, 0.36)
	for x in [9, 16]:
		s.px(x, 48, IRON_LIGHT.darkened(0.1), 0.58, 0.36)
	# 灯柱
	s.rect(11, 18, 14, 46, IRON, 0.56, 0.36)
	s.vline(14, 18, 46, IRON_LIGHT.darkened(0.18), 0.58, 0.34)
	s.px(11, 22, IRON_LIGHT, 0.6, 0.3)
	# 装饰弯枝
	s.line(8, 28, 11, 25, IRON, 0.6, 0.36)
	s.line(8, 30, 11, 29, IRON, 0.6, 0.36)
	s.line(8, 31, 9, 34, IRON, 0.58, 0.4)
	s.line(17, 28, 14, 25, IRON, 0.6, 0.36)
	s.line(17, 30, 14, 29, IRON, 0.6, 0.36)
	# 灯笼吊架
	s.line(13, 18, 13, 21, IRON, 0.7, 0.36)
	s.rect(7, 4, 18, 18, IRON, 0.72, 0.38)
	s.rect(8, 6, 17, 17, GOLD_DEEP.darkened(0.12), 0.28, 0.2, 0.66)
	for y in range(6, 17):
		for x in range(8, 17):
			var c := GOLD_DEEP
			if x == 9 or x == 12 or x == 15:
				c = IRON
			elif x == 10 or x == 11 or x == 13 or x == 14:
				c = GOLD
				if (x + y) % 7 == 0:
					c = GOLD_HOT
			if y >= 13 and c != IRON:
				c = GOLD_DEEP.darkened(0.08)
			if y <= 7 and c != IRON:
				c = GOLD
			s.px(x, y, c, 0.2, 0.18, 0.68 if c != IRON else 0.0)
	# 中央灯芯：只保留 2×3 的亮核，外面仍是琥珀玻璃
	for y in range(9, 13):
		for x in range(10, 12):
			s.px(x, y, GOLD_HOT, 0.16, 0.14, 0.95)
	s.px(11, 9, Color(1.0, 0.95, 0.76), 0.16, 0.14, 1.0)
	# 窗棂 / 顶盖
	s.vline(12, 6, 17, IRON, 0.56, 0.4)
	s.vline(15, 6, 17, IRON, 0.56, 0.4)
	s.hline(8, 17, 11, IRON, 0.58, 0.4)
	s.vline(9, 6, 17, IRON, 0.54, 0.4)
	s.rect(6, 3, 19, 5, IRON, 0.68, 0.36)
	s.hline(7, 18, 3, IRON_LIGHT, 0.72, 0.3)
	s.rect(8, 1, 17, 2, IRON, 0.65, 0.4)
	s.px(13, 0, IRON_LIGHT, 0.7, 0.3)
	# 底部暖尘/光斑
	s.px(13, 20, GOLD_HOT, 0.3, 0.2, 0.7)
	s.px(12, 22, GOLD, 0.34, 0.2, 0.3)
	return s.finish(1.9)


# ── 石头 ─────────────────────────────────────────────────────────────────
static func _rock_layer(w: int, h: int, seed_value: int, height_scale := 0.7) -> Dictionary:
	var s := PixelSurface.new(w, h)
	var lobes := [
		Vector4(w * 0.28, h * 0.54, w * 0.27, h * 0.42),
		Vector4(w * 0.58, h * 0.58, w * 0.30, h * 0.38),
		Vector4(w * 0.78, h * 0.67, w * 0.20, h * 0.27),
	]
	for i in lobes.size():
		var b: Vector4 = lobes[i]
		var base := Color(0.18, 0.24, 0.23).lerp(Color(0.30, 0.35, 0.32),
				PixelSurface.noise01(i, seed_value, 1) * 0.5)
		s.disc(b.x, b.y, b.z + 1, b.w + 1, base.darkened(0.18), 0.28, 0.94)
	for i in lobes.size():
		var b: Vector4 = lobes[i]
		var base := Color(0.26, 0.33, 0.31).lerp(Color(0.42, 0.45, 0.40),
				PixelSurface.noise01(i, seed_value, 2) * 0.55)
		s.disc(b.x, b.y, b.z, b.w, base, 0.5, 0.92)
		s.disc(b.x - b.z * 0.20, b.y - b.w * 0.26, b.z * 0.58, b.w * 0.45,
			base.lightened(0.13), 0.64, 0.90)
	# 裂纹与苔藓
	for i in 8:
		var x := int(PixelSurface.noise01(i, 2, seed_value) * w)
		var y := int(h * 0.45 + PixelSurface.noise01(i, 3, seed_value) * h * 0.45)
		if s.image.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1)).a > 0.5:
			s.px(x, y, Color(0.14, 0.19, 0.18), 0.32, 0.94)
			if i % 2 == 0:
				s.px(x + 1, y + 1, Color(0.19, 0.25, 0.23), 0.38, 0.94)
	for i in 6:
		var x := int(PixelSurface.noise01(i, 4, seed_value) * w)
		var y := int(h * 0.68 + PixelSurface.noise01(i, 5, seed_value) * h * 0.25)
		if s.image.get_pixel(clampi(x, 0, w - 1), clampi(y, 0, h - 1)).a > 0.5:
			s.px(x, y, Color(0.28, 0.38, 0.25), 0.48, 0.94)
	# 给轮廓内每像素一个圆顶高度，避免整块平贴片
	for y in h:
		for x in w:
			if s.image.get_pixel(x, y).a < 0.5:
				continue
			var q := pow((float(x) - w * 0.52) / (w * 0.55), 2.0) \
					+ pow((float(y) - h * 0.62) / (h * 0.55), 2.0)
			var domed := height_scale * clampf(1.0 - q * 0.55, 0.0, 1.0)
			s.heights[y * w + x] = 0.25 + domed * 0.55 \
					+ PixelSurface.noise01(x, y, seed_value + 9) * 0.08
			s.normal_px(x, y, clampf((float(x) - w * 0.52) / (w * 0.5), -1.0, 1.0) * 0.48,
					clampf((float(y) - h * 0.58) / (h * 0.52), -1.0, 1.0) * 0.30 - 0.08)
	return s.finish(2.2)


static func build_rock_cluster(w: int, h: int, seed_value: int) -> Dictionary:
	return _rock_layer(w, h, seed_value)


static func build_boulder() -> Dictionary:
	return _rock_layer(42, 26, 73, 0.92)


# ── 码头 ─────────────────────────────────────────────────────────────────
static func build_dock() -> Dictionary:
	var s := PixelSurface.new(84, 44)
	# 四根木桩（贯穿水面到底）
	for px in [9, 31, 55, 77]:
		var base := Color(0.19, 0.14, 0.12)
		s.rect(px, 7, px + 4, 43, base, 0.5, 0.82)
		s.vline(px + 1, 7, 43, Color(0.30, 0.22, 0.16), 0.55, 0.80)
		s.vline(px + 4, 7, 43, Color(0.10, 0.09, 0.09), 0.45, 0.86)
		# 绳结
		s.px(px + 2, 22, Color(0.61, 0.49, 0.29), 0.55, 0.78)
		s.px(px + 3, 23, Color(0.45, 0.34, 0.22), 0.55, 0.80)
	# 甲板底边
	s.rect(0, 14, 83, 18, WOOD_DARK, 0.46, 0.84)
	# 甲板（横向木板）
	for row in 4:
		var y := 2 + row * 3
		var c := WOOD.darkened(0.08 + row * 0.025)
		s.rect(0, y, 83, y + 2, c, 0.65, 0.78)
		s.hline(0, 83, y, WOOD_LIGHT.darkened(0.05), 0.72, 0.74)
		s.hline(0, 83, y + 2, WOOD_DARK.darkened(0.08), 0.58, 0.82)
		for x in range(4, 84, 12):
			if (x + row) % 24 < 12:
				s.px(x, y + 1, Color(0.23, 0.18, 0.15), 0.64, 0.8)
	# 甲板前缘、绳子、系船柱
	s.rect(0, 15, 83, 16, WOOD_LIGHT.darkened(0.2), 0.68, 0.76)
	s.rect(70, 0, 75, 8, WOOD_DARK, 0.74, 0.76)
	s.hline(69, 76, 0, WOOD_LIGHT, 0.8, 0.72)
	s.line(74, 8, 78, 13, Color(0.52, 0.42, 0.26), 0.6, 0.84)
	s.line(75, 8, 79, 12, Color(0.38, 0.30, 0.18), 0.55, 0.84)
	# 甲板上的旧绳盘
	s.disc(57, 8, 5.0, 2.0, Color(0.38, 0.30, 0.20), 0.72, 0.84)
	s.disc(57, 8, 3.0, 1.2, Color(0.18, 0.14, 0.12), 0.68, 0.86)
	s.px(53, 7, Color(0.56, 0.45, 0.28), 0.7, 0.8)
	# 甲板边缘青苔
	for x in [2, 6, 21, 46, 67]:
		s.px(x, 1, PLANT, 0.75, 0.9)
		s.px(x + 1, 1, PLANT_LIGHT, 0.75, 0.9)
	return s.finish(2.0)


# ── 灯晕贴图 ─────────────────────────────────────────────────────────────
static func build_glow() -> Image:
	var size := 40
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c := Vector2(size * 0.5, size * 0.5)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length() / (size * 0.5)
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, 2.35)
			# 12 级量化，保留像素扇贝边
			a = floor(a * 12.0) / 12.0
			if a <= 0.0:
				continue
			var ring := 0.0
			if d > 0.28 and d < 0.42:
				ring = 0.10
			var col := Color(1.0, 0.58 + 0.20 * (1.0 - d), 0.26 + ring, a * 0.64)
			img.set_pixel(x, y, col)
	# 核心亮核
	for y in range(17, 23):
		for x in range(17, 23):
			var d := Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length()
			if d < 3.2:
				img.set_pixel(x, y, Color(1.0, 0.90, 0.62, 0.9))
	return img
