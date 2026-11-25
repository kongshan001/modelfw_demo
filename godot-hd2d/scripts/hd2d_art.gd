class_name HD2DArt
extends RefCounted

# 所有像素素材都在运行时用固定种子绘制：无外部贴图、无第三方素材。
# 世界坐标系：640×360（在 1280×720 / 1920×1080 下按整数倍最近邻放大）。

const WORLD_SIZE := Vector2i(640, 360)

const GRASS_A := Color("#5c8543")
const GRASS_B := Color("#56803f")
const GRASS_C := Color("#638c49")
const GRASS_D := Color("#4a7036")
const GRASS_LIGHT := Color("#739f52")
const GRASS_DARK := Color("#3f6330")
const DIRT_EDGE := Color("#84643f")
const DIRT := Color("#b58d5c")
const DIRT_LIGHT := Color("#c9a371")
const SOIL := Color("#6d4b32")
const SOIL_LIGHT := Color("#7e5939")
const SOIL_DARK := Color("#553822")
const FOREST_DARK := Color("#1f342c")
const FOREST_MID := Color("#2b483a")
const FOREST_LIGHT := Color("#3b5b47")
const STONE := Color("#7b7263")
const STONE_LIGHT := Color("#9b9280")
const OUTLINE := Color("#2b2420")
const WOOD := Color("#5f402b")
const WOOD_LIGHT := Color("#7d5738")
const CREAM := Color("#cdb98f")
const CREAM_SHADE := Color("#b19c73")
const ROOF_DARK := Color("#5d332b")
const ROOF := Color("#8c4a39")
const ROOF_LIGHT := Color("#a85a44")
const ROOF_HI := Color("#bd7051")
const WINDOW_WARM := Color("#f2c16e")
const WATER_EDGE := Color("#2f5c5d")
const WATER_DARK := Color("#2b666d")
const WATER := Color("#3a8790")
const WATER_LIGHT := Color("#5ba5a5")
const WATER_HI := Color("#93c8bd")


static func make_ground() -> ImageTexture:
	var im := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	im.fill(GRASS_A)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261125

	# 大块草色变化：先铺 16×16，再用低透明度椭圆打散规律。
	for ty in range(0, 360, 8):
		for tx in range(0, 640, 8):
			var c := GRASS_A
			var roll := rng.randf()
			if roll < 0.18:
				c = GRASS_B
			elif roll < 0.32:
				c = GRASS_C
			im.fill_rect(Rect2i(tx, ty, 8, 8), c)
	for patch in [
		[Vector2i(180, 250), Vector2i(170, 90), GRASS_LIGHT],
		[Vector2i(455, 190), Vector2i(130, 90), GRASS_LIGHT],
		[Vector2i(310, 330), Vector2i(210, 60), GRASS_DARK],
		[Vector2i(620, 80), Vector2i(120, 90), GRASS_B],
	]:
		_blend_ellipse(im, patch[0].x, patch[0].y, patch[1].x, patch[1].y, patch[2], 0.22)

	# 顶部远处林带：纵向渐变 + 小尺度树冠剪影 + 晨雾，避免大块重复图案。
	for y in range(0, 82):
		var t := float(y) / 82.0
		im.fill_rect(Rect2i(0, y, 640, 1), Color("#20382f").lerp(Color("#547150"), t))
	for x in range(-16, 672, 11):
		var cy := 52 + int(5.0 * sin(float(x) * 0.19) + 3.0 * sin(float(x) * 0.47))
		var r := 7 + int(3.0 * sin(float(x) * 0.31 + 2.0))
		_disc(im, x, cy, r, FOREST_MID)
	for x in range(-9, 676, 14):
		var cy2 := 65 + int(4.0 * sin(float(x) * 0.27 + 1.4))
		var r2 := 5 + int(3.0 * sin(float(x) * 0.41))
		_disc(im, x, cy2, r2, FOREST_LIGHT)
	_blend_ellipse(im, 320, 76, 360, 15, Color("#c9d6b4"), 0.16)
	# 农舍前的踩实土院。
	_blend_ellipse(im, 232, 198, 126, 30, Color("#b08e60"), 0.35)
	_blend_ellipse(im, 232, 196, 100, 20, Color("#c3a26f"), 0.20)

	# 通往农舍的土路与岔路。
	_stroke_path(im, [
		Vector2(232, 186), Vector2(236, 218), Vector2(247, 252),
		Vector2(270, 288), Vector2(301, 322), Vector2(320, 360),
	], 38, DIRT_EDGE)
	_stroke_path(im, [
		Vector2(232, 186), Vector2(236, 218), Vector2(247, 252),
		Vector2(270, 288), Vector2(301, 322), Vector2(320, 360),
	], 30, DIRT)
	_stroke_path(im, [
		Vector2(232, 186), Vector2(236, 218), Vector2(247, 252),
		Vector2(270, 288), Vector2(301, 322), Vector2(320, 360),
	], 22, DIRT_LIGHT)
	_stroke_path(im, [
		Vector2(282, 300), Vector2(335, 300), Vector2(390, 302),
		Vector2(438, 300),
	], 20, DIRT_EDGE)
	_stroke_path(im, [
		Vector2(282, 300), Vector2(335, 300), Vector2(390, 302),
		Vector2(438, 300),
	], 13, DIRT_LIGHT)

	# 路面碎石与车辙。
	for i in 80:
		var t := rng.randf()
		var p := _path_point(t)
		var px := int(p.x + rng.randf_range(-13.0, 13.0))
		var py := int(p.y + rng.randf_range(-3.0, 3.0))
		var c := DIRT_EDGE if rng.randf() < 0.6 else GRASS_DARK
		im.fill_rect(Rect2i(px, py, rng.randi_range(1, 3), 1), c)

	# 三块菜地：土壤、垄沟、田埂石。
	_draw_field(im, Rect2i(34, 236, 118, 46), rng)
	_draw_field(im, Rect2i(34, 290, 118, 46), rng)
	_draw_field(im, Rect2i(166, 250, 74, 86), rng)

	# 池塘岸线（水面由独立 sprite 叠加）。
	_ellipse(im, 520, 300, 104, 60, Color("#54573c"))
	_ellipse(im, 520, 300, 96, 53, Color("#3e5550"))
	for i in 46:
		var a := rng.randf() * TAU
		var rr := rng.randf()
		var sx := int(520.0 + cos(a) * (96.0 + rr * 10.0))
		var sy := int(300.0 + sin(a) * (53.0 + rr * 7.0))
		im.fill_rect(Rect2i(sx, sy, rng.randi_range(2, 4), rng.randi_range(1, 3)),
				STONE if rng.randf() < 0.5 else STONE_LIGHT)

	# 草丛、野花与零散小石子。
	for i in 780:
		var x := rng.randi_range(2, 637)
		var y := rng.randi_range(88, 357)
		if _in_field(x, y) or _near_path(x, y) or _in_pond(x, y):
			continue
		var tuft := GRASS_DARK if rng.randf() < 0.55 else GRASS_LIGHT
		var h := rng.randi_range(2, 4)
		im.fill_rect(Rect2i(x, y, 1, h), tuft)
		if rng.randf() < 0.45:
			im.fill_rect(Rect2i(x + 1, y + 1, 1, max(1, h - 1)), tuft)
	for i in 55:
		var x := rng.randi_range(6, 630)
		var y := rng.randi_range(96, 350)
		if _in_field(x, y) or _in_pond(x, y):
			continue
		if rng.randf() < 0.5:
			im.set_pixel(x, y, Color("#dfc26e"))
			im.set_pixel(x + 1, y, Color("#d8d2ae"))
			if rng.randf() < 0.35:
				im.set_pixel(x + 2, y, Color("#dfc26e"))
		else:
			im.set_pixel(x, y, Color("#c78394"))
			im.set_pixel(x, y + 1, Color("#7c5361"))

	return ImageTexture.create_from_image(im)


static func make_water() -> ImageTexture:
	var im := Image.create(232, 144, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	_ellipse(im, 116, 72, 108, 63, Color("#2c4d4d"))
	_ellipse(im, 116, 70, 102, 56, WATER_DARK)
	_ellipse(im, 116, 68, 94, 48, WATER)
	_ellipse(im, 110, 60, 78, 34, WATER_LIGHT)
	# 水面横向反光与深水色带。
	var rng := RandomNumberGenerator.new()
	rng.seed = 1125
	for i in 14:
		var y := rng.randi_range(30, 120)
		var w := rng.randi_range(8, 26)
		var x := rng.randi_range(28, 180)
		var c := WATER_HI if rng.randf() < 0.25 else WATER_LIGHT
		im.fill_rect(Rect2i(x, y, w, 1), Color(c, 0.24))
	for i in 18:
		var y := rng.randi_range(48, 118)
		im.fill_rect(Rect2i(rng.randi_range(24, 190), y, rng.randi_range(6, 22), 1), WATER_DARK)
	# 睡莲与边岸水草。
	for p in [Vector2i(74, 88), Vector2i(146, 104), Vector2i(168, 78), Vector2i(96, 118)]:
		_ellipse(im, p.x, p.y, 7, 4, Color("#376b3c"))
		_ellipse(im, p.x - 1, p.y - 1, 5, 3, Color("#4f8b48"))
		if rng.randf() < 0.7:
			im.fill_rect(Rect2i(p.x + 3, p.y - 3, 3, 3), Color("#e9a7b9"))
	for i in 12:
		var side := rng.randf()
		var x := int(26.0 + side * 180.0)
		var y := 116 + rng.randi_range(-6, 10)
		im.fill_rect(Rect2i(x, y - 10, 1, 12), Color("#4a7540"))
		im.fill_rect(Rect2i(x + 1, y - 7, 1, 6), Color("#6a9450"))
	return ImageTexture.create_from_image(im)


static func make_house() -> ImageTexture:
	var w := 144
	var h := 124
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))

	# 石基与台阶。
	im.fill_rect(Rect2i(12, 110, 120, 12), Color("#6b6152"))
	im.fill_rect(Rect2i(12, 110, 120, 3), Color("#8c8170"))
	for x in range(14, 130, 11):
		im.fill_rect(Rect2i(x, 114, 1, 8), Color("#554c40"))
	im.fill_rect(Rect2i(52, 117, 40, 7), Color("#8e8069"))
	im.fill_rect(Rect2i(52, 117, 40, 2), Color("#aa9a7f"))

	# 灰泥墙与木梁。
	im.fill_rect(Rect2i(16, 64, 112, 48), CREAM)
	im.fill_rect(Rect2i(16, 64, 112, 4), Color("#e7d7b1"))
	im.fill_rect(Rect2i(16, 100, 112, 12), CREAM_SHADE)
	for x in [16, 44, 100, 125]:
		im.fill_rect(Rect2i(x, 64, 3, 48), WOOD)
	im.fill_rect(Rect2i(16, 64, 112, 3), WOOD)
	im.fill_rect(Rect2i(16, 86, 112, 2), Color("#6b4a32"))
	im.fill_rect(Rect2i(16, 108, 112, 3), WOOD)
	# 墙体斑驳。
	var rng := RandomNumberGenerator.new()
	rng.seed = 4411
	for i in 20:
		var x := rng.randi_range(20, 120)
		var y := rng.randi_range(70, 104)
		im.fill_rect(Rect2i(x, y, rng.randi_range(1, 4), 1), CREAM_SHADE)

	# 门与门框。
	im.fill_rect(Rect2i(60, 80, 28, 30), Color("#4a3225"))
	im.fill_rect(Rect2i(62, 82, 24, 28), Color("#70462c"))
	im.fill_rect(Rect2i(65, 85, 18, 22), Color("#86573a"))
	im.fill_rect(Rect2i(66, 87, 16, 1), Color("#5d3a26"))
	im.fill_rect(Rect2i(66, 94, 16, 1), Color("#5d3a26"))
	im.fill_rect(Rect2i(66, 101, 16, 1), Color("#5d3a26"))
	im.fill_rect(Rect2i(82, 96, 2, 3), Color("#ddb45e"))

	# 两扇窗：白天是暗琥珀，夜晚由叠加光斑点亮。
	for wx in [27, 101]:
		im.fill_rect(Rect2i(wx, 72, 19, 16), Color("#4a3327"))
		im.fill_rect(Rect2i(wx + 2, 74, 15, 12), WINDOW_WARM)
		im.fill_rect(Rect2i(wx + 2, 74, 15, 2), Color("#f7dc9f"))
		im.fill_rect(Rect2i(wx + 9, 74, 1, 12), Color("#5b4030"))
		im.fill_rect(Rect2i(wx + 2, 80, 15, 1), Color("#5b4030"))
		im.fill_rect(Rect2i(wx - 1, 88, 21, 3), Color("#7b5a3a"))

	# 烟囱先画，再让屋顶盖住下半段（避免悬空）。
	im.fill_rect(Rect2i(101, 0, 15, 26), Color("#756557"))
	im.fill_rect(Rect2i(99, 0, 19, 4), Color("#93806c"))
	im.fill_rect(Rect2i(103, 4, 2, 19), Color("#5e5146"))
	im.fill_rect(Rect2i(109, 4, 1, 19), Color("#8b7967"))
	im.fill_rect(Rect2i(100, 23, 17, 3), Color("#5b4d41"))

	# 大坡度屋顶：瓦片行列 + 高光 + 深色檐口。
	for y in range(18, 68):
		var t := float(y - 18) / 50.0
		var half := int(28.0 + t * 44.0)
		var x0 := 72 - half
		var x1 := 72 + half
		im.fill_rect(Rect2i(x0, y, x1 - x0, 1), ROOF if (y % 6) != 0 else ROOF_DARK)
		if (y % 6) == 2:
			for x in range(x0 + 2 + (y % 11), x1 - 2, 7):
				im.fill_rect(Rect2i(x, y, 3, 1), ROOF_LIGHT)
	im.fill_rect(Rect2i(26, 64, 92, 5), ROOF_DARK)
	im.fill_rect(Rect2i(30, 61, 84, 3), Color("#3d2624"))
	# 屋脊与斜脊高光。
	im.fill_rect(Rect2i(43, 17, 58, 3), Color("#422823"))
	im.fill_rect(Rect2i(46, 20, 52, 1), ROOF_HI)
	for x in range(30, 116, 10):
		im.fill_rect(Rect2i(x, 24, 2, 34), Color(ROOF_HI, 0.45))
	im.fill_rect(Rect2i(20, 30, 4, 28), ROOF_DARK)
	im.fill_rect(Rect2i(120, 30, 4, 28), ROOF_DARK)

	# 门旁木桶与花箱。
	im.fill_rect(Rect2i(24, 102, 12, 9), Color("#4b3325"))
	im.fill_rect(Rect2i(25, 103, 10, 7), Color("#775032"))
	im.fill_rect(Rect2i(25, 105, 10, 1), Color("#3c2a1f"))
	im.fill_rect(Rect2i(25, 108, 10, 1), Color("#3c2a1f"))
	im.fill_rect(Rect2i(90, 103, 15, 8), Color("#58402c"))
	for i in 4:
		im.fill_rect(Rect2i(92 + i * 3, 99 - (i % 2), 2, 4),
				Color("#e0a3b2") if i % 2 == 0 else Color("#e8d28a"))
		im.fill_rect(Rect2i(93 + i * 3, 102, 1, 2), Color("#527a40"))
	return ImageTexture.create_from_image(im)


static func make_tree(variant: int = 0) -> ImageTexture:
	var big := variant == 0
	var w := 96 if big else 64
	var h := 128 if big else 90
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + variant * 97
	var trunk_x := w / 2 - 5
	var trunk_top := int(h * 0.50)
	var trunk_bottom := h - 3

	# 树干与树根。
	im.fill_rect(Rect2i(trunk_x + 2, trunk_top, 8, trunk_bottom - trunk_top), OUTLINE)
	im.fill_rect(Rect2i(trunk_x + 3, trunk_top, 6, trunk_bottom - trunk_top), WOOD)
	im.fill_rect(Rect2i(trunk_x + 3, trunk_top, 2, trunk_bottom - trunk_top), WOOD_LIGHT)
	im.fill_rect(Rect2i(trunk_x - 1, trunk_bottom - 3, 14, 3), OUTLINE)
	im.fill_rect(Rect2i(trunk_x - 3, trunk_bottom - 1, 20, 2), OUTLINE)
	for i in 6:
		var y := trunk_top + rng.randi_range(2, trunk_bottom - trunk_top - 2)
		im.fill_rect(Rect2i(trunk_x + rng.randi_range(4, 7), y, 1, rng.randi_range(2, 5)),
				Color("#4a3123"))

	# 树冠：多团重叠球 + 深色描边，团与团之间保留内部轮廓。
	var blobs := [
		[Vector2(w * 0.50, h * 0.30), int(w * 0.27)],
		[Vector2(w * 0.32, h * 0.40), int(w * 0.20)],
		[Vector2(w * 0.68, h * 0.40), int(w * 0.21)],
		[Vector2(w * 0.44, h * 0.20), int(w * 0.18)],
		[Vector2(w * 0.58, h * 0.21), int(w * 0.17)],
		[Vector2(w * 0.50, h * 0.49), int(w * 0.19)],
	]
	for b in blobs:
		_disc(im, int(b[0].x), int(b[0].y), int(b[1]) + 2, OUTLINE)
	for b in blobs:
		_disc(im, int(b[0].x), int(b[0].y), int(b[1]), Color("#2f673a"))
	for b in blobs:
		_disc(im, int(b[0].x) - 1, int(b[0].y) - 1, int(b[1]) - 2, Color("#3a7440"))
	for b in blobs:
		_disc(im, int(b[0].x) + 3, int(b[0].y) + 3, maxi(3, int(b[1]) - 6),
				Color("#325f39"))
	# 受光面偏向屏幕左上。
	for b in blobs:
		var cx := int(b[0].x) - int(b[1]) / 4
		var cy := int(b[0].y) - int(b[1]) / 3
		_disc(im, cx, cy, max(3, int(b[1]) - 7), Color("#5d9e4c"))
	for i in 46:
		var a := rng.randf() * TAU
		var rr := rng.randf() * w * 0.30
		var x := int(w * 0.5 + cos(a) * rr)
		var y := int(h * 0.33 + sin(a) * rr * 0.8)
		var c := Color("#6fa955") if rng.randf() < 0.6 else Color("#8fbe66")
		im.fill_rect(Rect2i(x, y, rng.randi_range(1, 3), rng.randi_range(1, 2)), c)
	for i in 34:
		var x := rng.randi_range(8, w - 9)
		var y := rng.randi_range(int(h * 0.12), int(h * 0.55))
		im.set_pixel(x, y, Color("#2a5834"))
	return ImageTexture.create_from_image(im)


static func make_lantern_post() -> ImageTexture:
	var im := Image.create(20, 62, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	# 木柱与横臂。
	im.fill_rect(Rect2i(8, 14, 5, 46), OUTLINE)
	im.fill_rect(Rect2i(9, 15, 3, 45), WOOD)
	im.fill_rect(Rect2i(9, 15, 1, 44), WOOD_LIGHT)
	im.fill_rect(Rect2i(3, 12, 13, 3), OUTLINE)
	im.fill_rect(Rect2i(4, 12, 11, 1), WOOD_LIGHT)
	# 吊灯。
	im.fill_rect(Rect2i(3, 15, 1, 4), Color("#3c2a20"))
	im.fill_rect(Rect2i(4, 18, 10, 2), OUTLINE)
	im.fill_rect(Rect2i(3, 20, 12, 10), OUTLINE)
	im.fill_rect(Rect2i(4, 21, 10, 8), Color("#7a4a2d"))
	im.fill_rect(Rect2i(5, 22, 8, 6), Color("#f5c56e"))
	im.fill_rect(Rect2i(6, 23, 6, 4), Color("#ffe2a0"))
	im.fill_rect(Rect2i(8, 22, 1, 6), Color("#b87837"))
	im.fill_rect(Rect2i(4, 21, 1, 7), Color("#4b2e20"))
	im.fill_rect(Rect2i(13, 21, 1, 7), Color("#4b2e20"))
	im.fill_rect(Rect2i(5, 29, 8, 1), OUTLINE)
	# 柱脚草丛。
	im.fill_rect(Rect2i(5, 58, 11, 3), Color("#4e7938"))
	im.fill_rect(Rect2i(7, 57, 2, 3), Color("#6f9e4b"))
	return ImageTexture.create_from_image(im)


static func make_fence() -> ImageTexture:
	# 一段一根立柱 + 两条横栏；横向重复后形成连续栅栏，而不是一串 H。
	var im := Image.create(26, 22, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	im.fill_rect(Rect2i(3, 8, 23, 2), OUTLINE)
	im.fill_rect(Rect2i(3, 15, 23, 2), OUTLINE)
	im.fill_rect(Rect2i(3, 8, 23, 1), WOOD_LIGHT)
	im.fill_rect(Rect2i(3, 15, 23, 1), WOOD_LIGHT)
	im.fill_rect(Rect2i(4, 1, 4, 20), OUTLINE)
	im.fill_rect(Rect2i(5, 2, 2, 18), WOOD)
	im.fill_rect(Rect2i(5, 2, 1, 18), WOOD_LIGHT)
	im.fill_rect(Rect2i(3, 0, 6, 2), OUTLINE)
	im.fill_rect(Rect2i(5, 0, 2, 2), WOOD_LIGHT)
	return ImageTexture.create_from_image(im)


static func make_crop(variant: int = 0) -> ImageTexture:
	var im := Image.create(14, 20, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var stem := Color("#3f7439")
	var leaf := Color("#5c9b45") if variant == 0 else Color("#7ea94a")
	var hi := Color("#8fc45f") if variant == 0 else Color("#b2ce6a")
	im.fill_rect(Rect2i(6, 6, 2, 14), stem)
	for p in [[3, 9], [9, 11], [4, 13], [8, 8]]:
		im.fill_rect(Rect2i(p[0], p[1], 4, 2), leaf)
		im.fill_rect(Rect2i(p[0] + 1, p[1] - 1, 2, 1), hi)
	if variant == 1:
		im.fill_rect(Rect2i(5, 3, 4, 3), Color("#e7cf72"))
		im.set_pixel(5, 3, Color("#fff0b0"))
	im.fill_rect(Rect2i(5, 19, 4, 1), Color("#4e7938"))
	return ImageTexture.create_from_image(im)


static func make_rock() -> ImageTexture:
	var im := Image.create(22, 14, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	_ellipse(im, 11, 9, 10, 5, OUTLINE)
	_ellipse(im, 11, 8, 9, 4, STONE)
	_ellipse(im, 9, 6, 6, 3, STONE_LIGHT)
	im.fill_rect(Rect2i(5, 10, 11, 2), Color("#5e574d"))
	return ImageTexture.create_from_image(im)


static func make_flower(variant: int = 0) -> ImageTexture:
	var im := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var petal := Color("#e7a2b3") if variant == 0 else Color("#ead57e")
	if variant == 2:
		petal = Color("#d9e6d1")
	im.set_pixel(3, 5, Color("#4f7f3e"))
	im.set_pixel(3, 4, Color("#4f7f3e"))
	im.set_pixel(3, 2, petal)
	im.set_pixel(2, 3, petal)
	im.set_pixel(4, 3, petal)
	im.set_pixel(3, 4, petal)
	im.set_pixel(3, 3, Color("#e8b84e"))
	return ImageTexture.create_from_image(im)


static func make_contact_shadow(w: int = 34, h: int = 12) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	for i in 4:
		var rx := maxi(1, int(float(w) * 0.5 * (1.0 - float(i) * 0.16)))
		var ry := maxi(1, int(float(h) * 0.5 * (1.0 - float(i) * 0.14)))
		var a := 0.10 + float(i) * 0.085
		_ellipse(im, w / 2, h / 2, rx, ry, Color(0.02, 0.03, 0.05, a))
	return ImageTexture.create_from_image(im)


static func make_bush(variant: int = 0) -> ImageTexture:
	var im := Image.create(34, 24, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400 + variant
	var blobs := [
		[Vector2(10, 13), 8], [Vector2(22, 12), 9], [Vector2(16, 9), 7],
	]
	for b in blobs:
		_disc(im, int(b[0].x), int(b[0].y), int(b[1]) + 1, OUTLINE)
	for b in blobs:
		_disc(im, int(b[0].x), int(b[0].y), int(b[1]), Color("#356b3c"))
	for b in blobs:
		_disc(im, int(b[0].x) - 1, int(b[0].y) - 1, int(b[1]) - 2, Color("#4f8c4a"))
	for i in 14:
		var x := rng.randi_range(5, 29)
		var y := rng.randi_range(4, 17)
		im.fill_rect(Rect2i(x, y, rng.randi_range(1, 2), 1), Color("#77b45d"))
	if variant == 1:
		for p in [Vector2i(9, 7), Vector2i(21, 6), Vector2i(16, 11)]:
			im.set_pixel(p.x, p.y, Color("#e7b0be"))
			im.set_pixel(p.x + 1, p.y, Color("#f1d6d9"))
	im.fill_rect(Rect2i(5, 21, 25, 2), Color("#2b2420"))
	return ImageTexture.create_from_image(im)


static func make_hay() -> ImageTexture:
	var im := Image.create(30, 20, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	im.fill_rect(Rect2i(1, 3, 28, 16), OUTLINE)
	im.fill_rect(Rect2i(2, 4, 26, 14), Color("#c9a34e"))
	im.fill_rect(Rect2i(2, 4, 26, 3), Color("#e0bd68"))
	for y in range(7, 17, 3):
		im.fill_rect(Rect2i(3, y, 24, 1), Color("#a47e3a"))
	for x in [7, 21]:
		im.fill_rect(Rect2i(x, 4, 2, 14), Color("#6b4c2d"))
	im.fill_rect(Rect2i(4, 1, 22, 2), Color("#d8b45d"))
	im.fill_rect(Rect2i(4, 17, 22, 2), Color("#8e6b36"))
	im.set_pixel(5, 6, Color("#f0d68a"))
	im.set_pixel(25, 15, Color("#8e6b36"))
	return ImageTexture.create_from_image(im)


static func make_foreground_grass(w: int, h: int, seed_value: int) -> ImageTexture:
	# 底部前景：成簇的阔叶剪影，在移轴后处理里会成为柔和的暗色景深框。
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in 5:
		var cx := rng.randi_range(8, w - 8)
		_ellipse(im, cx, h - 4, rng.randi_range(18, 32), rng.randi_range(6, 11),
				Color("#1b3524"))
		_ellipse(im, cx - 4, h - 7, rng.randi_range(10, 18), rng.randi_range(4, 7),
				Color("#284b30"))
	for i in int(w * 0.30):
		var x := rng.randi_range(2, w - 3)
		var bh := rng.randi_range(maxi(12, h / 2), h - 3)
		var lean := rng.randf_range(-10.0, 10.0)
		var col := Color("#203f2a") if rng.randf() < 0.65 else Color("#315b37")
		for j in bh:
			var px := x + int(lean * float(j) / float(bh))
			var py := h - 1 - j
			im.fill_rect(Rect2i(px, py, 2, 1), col)
			if j > bh * 2 / 3 and rng.randf() < 0.3:
				im.fill_rect(Rect2i(px + 2, py, 1, 1), Color("#4c7a44"))
		if rng.randf() < 0.18:
			im.fill_rect(Rect2i(x + int(lean), h - 1 - bh, 3, 2), Color("#7c9851"))
	for y in range(h - 5, h):
		im.fill_rect(Rect2i(0, y, w, 1), Color("#183020"))
	return ImageTexture.create_from_image(im)


static func make_scarecrow() -> ImageTexture:
	var im := Image.create(30, 46, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	# 立柱与横臂。
	im.fill_rect(Rect2i(13, 10, 4, 36), OUTLINE)
	im.fill_rect(Rect2i(14, 11, 2, 34), Color("#6f4c31"))
	im.fill_rect(Rect2i(2, 20, 26, 4), OUTLINE)
	im.fill_rect(Rect2i(3, 20, 24, 2), Color("#7d5738"))
	# 稻草手。
	for p in [Vector2i(2, 19), Vector2i(24, 19)]:
		im.fill_rect(Rect2i(p.x, p.y, 4, 2), Color("#c8a24f"))
		for j in 3:
			im.fill_rect(Rect2i(p.x + j * 2, p.y + 2, 1, 4), Color("#a9833b"))
	# 布衣与补丁。
	im.fill_rect(Rect2i(9, 23, 12, 16), Color("#3f5a6a"))
	im.fill_rect(Rect2i(10, 23, 10, 3), Color("#57768a"))
	im.fill_rect(Rect2i(9, 36, 12, 4), Color("#334b59"))
	im.fill_rect(Rect2i(17, 27, 3, 3), Color("#8b6a45"))
	im.fill_rect(Rect2i(11, 31, 2, 2), Color("#8b6a45"))
	im.fill_rect(Rect2i(12, 34, 8, 1), Color("#9d7c3f"))
	# 麻布头、草帽。
	im.fill_rect(Rect2i(10, 9, 10, 11), OUTLINE)
	im.fill_rect(Rect2i(11, 10, 8, 9), Color("#c5a16d"))
	im.fill_rect(Rect2i(12, 12, 2, 1), Color("#453129"))
	im.fill_rect(Rect2i(17, 12, 1, 1), Color("#453129"))
	im.fill_rect(Rect2i(13, 16, 4, 1), Color("#7b563d"))
	im.fill_rect(Rect2i(8, 7, 14, 3), Color("#2e2420"))
	im.fill_rect(Rect2i(9, 6, 12, 2), Color("#b58e4d"))
	im.fill_rect(Rect2i(11, 3, 8, 4), Color("#c9a45b"))
	im.fill_rect(Rect2i(11, 3, 8, 1), Color("#8f6c36"))
	# 草绳。
	im.fill_rect(Rect2i(10, 30, 10, 2), Color("#8f6c3a"))
	return ImageTexture.create_from_image(im)


static func make_dock() -> ImageTexture:
	var im := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	im.fill_rect(Rect2i(8, 4, 56, 13), OUTLINE)
	im.fill_rect(Rect2i(9, 5, 55, 11), Color("#8a6440"))
	for x in range(9, 62, 7):
		im.fill_rect(Rect2i(x, 5, 5, 11), Color("#9f7650"))
		im.fill_rect(Rect2i(x + 1, 6, 3, 9), Color("#b58a5d"))
		im.fill_rect(Rect2i(x + 3, 5, 1, 11), Color("#6f4d31"))
	for x in [12, 34, 58]:
		im.fill_rect(Rect2i(x, 12, 3, 12), OUTLINE)
		im.fill_rect(Rect2i(x + 1, 13, 1, 10), Color("#6b4a2f"))
	im.fill_rect(Rect2i(10, 2, 52, 3), Color("#c39a64"))
	im.fill_rect(Rect2i(8, 15, 56, 2), Color("#5b4029"))
	return ImageTexture.create_from_image(im)


static func make_firefly() -> ImageTexture:
	var im := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	_ellipse(im, 3, 3, 3, 3, Color(1.0, 0.75, 0.28, 0.15))
	_ellipse(im, 3, 3, 2, 2, Color(1.0, 0.82, 0.4, 0.55))
	im.fill_rect(Rect2i(3, 2, 1, 3), Color(1.0, 0.95, 0.7, 1.0))
	im.fill_rect(Rect2i(2, 3, 3, 1), Color(1.0, 0.95, 0.7, 1.0))
	return ImageTexture.create_from_image(im)


static func make_light_texture(size: int = 128) -> ImageTexture:
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.55)
			# 轻微像素台阶，保留 2D 灯光的手绘感。
			a = snappedf(a, 1.0 / 40.0)
			im.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(im)


static func make_glow(color: Color, size: int = 64) -> ImageTexture:
	var im := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - half + 0.5, float(y) - half + 0.5).length() / half
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 2.0)
			im.set_pixel(x, y, Color(color.r, color.g, color.b, a * color.a))
	return ImageTexture.create_from_image(im)


static func make_farmer_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("idle")
	frames.add_animation("walk")
	frames.set_animation_speed("idle", 3.0)
	frames.set_animation_speed("walk", 7.0)
	frames.set_animation_loop("idle", true)
	frames.set_animation_loop("walk", true)
	for i in 2:
		frames.add_frame("idle", _farmer_frame(0, i * 1))
	for i in 4:
		frames.add_frame("walk", _farmer_frame(i, 0))
	return frames


static func _farmer_frame(step: int, bob: int) -> ImageTexture:
	var im := Image.create(24, 34, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	var skin := Color("#e5b287")
	var hat := Color("#d8b168")
	var hat_dark := Color("#a77f45")
	var coat := Color("#4f728c")
	var coat_dark := Color("#3b5870")
	var pants := Color("#6a4b34")
	var boot := Color("#332720")
	var oy := bob
	# 影子底座由光照系统负责，这里只画角色。
	# 腿：walk 第 0/2 帧前后错开。
	var l1 := 0
	var l2 := 0
	if step == 0:
		l1 = -2
		l2 = 2
	elif step == 2:
		l1 = 2
		l2 = -2
	im.fill_rect(Rect2i(8, 25 + oy, 4, 6), pants)
	im.fill_rect(Rect2i(13, 25 + oy, 4, 6), pants)
	im.fill_rect(Rect2i(8 + l1, 29 + oy, 4, 3), boot)
	im.fill_rect(Rect2i(13 + l2, 29 + oy, 4, 3), boot)
	# 外套与身体。
	im.fill_rect(Rect2i(7, 16 + oy, 11, 11), Color("#2e2420"))
	im.fill_rect(Rect2i(8, 16 + oy, 9, 10), coat)
	im.fill_rect(Rect2i(8, 16 + oy, 2, 9), coat_dark)
	im.fill_rect(Rect2i(12, 20 + oy, 5, 2), Color("#c79b58"))
	# 手臂。
	im.fill_rect(Rect2i(5, 17 + oy, 3, 8), Color("#2e2420"))
	im.fill_rect(Rect2i(6, 18 + oy, 2, 6), coat_dark)
	im.fill_rect(Rect2i(17, 17 + oy, 3, 8), Color("#2e2420"))
	im.fill_rect(Rect2i(17, 18 + oy, 2, 6), coat)
	# 头与草帽。
	im.fill_rect(Rect2i(9, 9 + oy, 7, 8), Color("#2e2420"))
	im.fill_rect(Rect2i(10, 10 + oy, 5, 6), skin)
	im.fill_rect(Rect2i(11, 12 + oy, 1, 1), Color("#3a2c24"))
	im.fill_rect(Rect2i(14, 12 + oy, 1, 1), Color("#3a2c24"))
	im.fill_rect(Rect2i(12, 15 + oy, 2, 1), Color("#b77e63"))
	im.fill_rect(Rect2i(5, 8 + oy, 15, 3), Color("#2e2420"))
	im.fill_rect(Rect2i(6, 7 + oy, 13, 2), hat)
	im.fill_rect(Rect2i(8, 4 + oy, 9, 4), hat)
	im.fill_rect(Rect2i(9, 3 + oy, 7, 1), hat_dark)
	im.fill_rect(Rect2i(7, 7 + oy, 2, 1), hat_dark)
	# 挎包。
	im.fill_rect(Rect2i(16, 24 + oy, 4, 4), Color("#8b5a36"))
	im.fill_rect(Rect2i(16, 24 + oy, 4, 1), Color("#b17a4b"))
	return ImageTexture.create_from_image(im)


static func make_grabber() -> ImageTexture:
	var im := Image.create(12, 18, false, Image.FORMAT_RGBA8)
	im.fill(Color(0, 0, 0, 0))
	im.fill_rect(Rect2i(3, 1, 6, 16), OUTLINE)
	im.fill_rect(Rect2i(4, 2, 4, 14), Color("#f0c06a"))
	im.fill_rect(Rect2i(5, 3, 2, 12), Color("#ffe1a0"))
	im.fill_rect(Rect2i(2, 6, 8, 2), OUTLINE)
	im.fill_rect(Rect2i(2, 11, 8, 2), OUTLINE)
	return ImageTexture.create_from_image(im)


static func _draw_field(im: Image, r: Rect2i, rng: RandomNumberGenerator) -> void:
	im.fill_rect(r.grow(2), Color("#8a7047"))
	im.fill_rect(r, SOIL)
	for y in range(r.position.y, r.end.y, 6):
		im.fill_rect(Rect2i(r.position.x, y, r.size.x, 2), SOIL_DARK)
		im.fill_rect(Rect2i(r.position.x, y + 2, r.size.x, 1), SOIL_LIGHT)
	for x in range(r.position.x + 4, r.end.x, 12):
		im.fill_rect(Rect2i(x, r.position.y, 1, r.size.y), Color("#65452e"))
	for i in 16:
		im.fill_rect(Rect2i(r.position.x + rng.randi_range(0, r.size.x - 2),
				r.position.y + rng.randi_range(0, r.size.y - 1),
				rng.randi_range(1, 3), 1), SOIL_LIGHT)


static func _forest_bump(im: Image, x: int, base: int, r: int, h: int, color: Color) -> void:
	for yy in range(h):
		var w := int(float(r) * (1.0 - float(yy) / float(h)))
		im.fill_rect(Rect2i(x - w, base - yy, w * 2, 1), color)


static func _stroke_path(im: Image, pts: Array, width: int, color: Color) -> void:
	var prev: Vector2 = pts[0]
	for i in range(1, pts.size()):
		var p: Vector2 = pts[i]
		var steps: int = max(1, int(prev.distance_to(p) / 3.0))
		for s in steps + 1:
			var t := float(s) / float(steps)
			_disc(im, int(lerpf(prev.x, p.x, t)), int(lerpf(prev.y, p.y, t)), width / 2, color)
		prev = p


static func _path_point(t: float) -> Vector2:
	var pts := [Vector2(232, 186), Vector2(236, 218), Vector2(247, 252),
			Vector2(270, 288), Vector2(301, 322), Vector2(320, 360)]
	var scaled := t * float(pts.size() - 1)
	var i := clampi(int(scaled), 0, pts.size() - 2)
	return pts[i].lerp(pts[i + 1], scaled - float(i))


static func _in_field(x: int, y: int) -> bool:
	return (x >= 32 and x <= 154 and y >= 234 and y <= 338) \
			or (x >= 164 and x <= 242 and y >= 248 and y <= 338)


static func _in_pond(x: int, y: int) -> bool:
	var dx := float(x - 520) / 106.0
	var dy := float(y - 300) / 62.0
	return dx * dx + dy * dy < 1.0


static func _near_path(x: int, y: int) -> bool:
	if x >= 206 and x <= 336 and y >= 180:
		return absf(float(x) - _path_point(clampf(float(y - 186) / 174.0, 0.0, 1.0)).x) < 22.0
	return false


static func _put(im: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, color)


static func _rect(im: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	var x0 := clampi(x, 0, im.get_width())
	var y0 := clampi(y, 0, im.get_height())
	var x1 := clampi(x + w, 0, im.get_width())
	var y1 := clampi(y + h, 0, im.get_height())
	if x1 <= x0 or y1 <= y0:
		return
	im.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)


static func _disc(im: Image, cx: int, cy: int, r: int, color: Color) -> void:
	var r2 := r * r
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r2:
				_put(im, cx + x, cy + y, color)


static func _ellipse(im: Image, cx: int, cy: int, rx: int, ry: int, color: Color) -> void:
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	for y in range(-ry, ry + 1):
		for x in range(-rx, rx + 1):
			if float(x * x) / rx2 + float(y * y) / ry2 <= 1.0:
				_put(im, cx + x, cy + y, color)


static func _blend_ellipse(im: Image, cx: int, cy: int, rx: int, ry: int,
		color: Color, alpha: float) -> void:
	var rx2 := float(rx * rx)
	var ry2 := float(ry * ry)
	for y in range(max(0, cy - ry), min(im.get_height(), cy + ry + 1)):
		for x in range(max(0, cx - rx), min(im.get_width(), cx + rx + 1)):
			var dx := float(x - cx)
			var dy := float(y - cy)
			if dx * dx / rx2 + dy * dy / ry2 <= 1.0:
				im.set_pixel(x, y, im.get_pixel(x, y).lerp(color, alpha))
