class_name BackgroundView
extends Node2D

# 原创程序化竹林黎明：天空暖光 → 远山 → 竹林中景 → 林间空地 → 前景草石，
# 叠加雾带、光柱、飘叶与轻暗角。所有元素由 draw_* 原语与确定性程序纹理生成，
# 不依赖外部素材。
#
# 地面是一块从敌侧远端（左缘 y≈480）铺到近景的**林间空地**：
#   远侧雾草 → 中央受光泥地/苔藓/石径 → 近景深草；
# 边缘由插值曲线 + 噪声扰动 + 草须 + 薄雾软收，没有矩形石台、描金边框或均匀网格。
# 空地中央只保留一圈半埋的石环作为阵型锚点（非方形棋盘）。
# 若 visual_catalog.json 提供了背景图，则天空/竹林/地面替换为 Sprite2D，
# 但光柱、地面光斑、地面薄雾、暗角与雾/叶层仍叠加在贴图之上。

const W := 1920.0
const H := 1080.0
const HORIZON := 612.0
const GROUND_TOP := 458.0
const GROUND_H := H - GROUND_TOP
const OUTLINE := Color(0.09, 0.1, 0.08, 0.55)

# 空地远缘：左（敌侧）更高、右（我侧）略低；插值后为平滑草坡，再叠噪声扰动。
const CLEARING_EDGE := [
	Vector2(0, 492), Vector2(120, 480), Vector2(250, 486), Vector2(390, 502),
	Vector2(540, 524), Vector2(700, 548), Vector2(860, 572), Vector2(1040, 592),
	Vector2(1230, 602), Vector2(1430, 600), Vector2(1640, 588), Vector2(1800, 578),
	Vector2(1920, 574),
]

# 空地中央的石环锚点（很淡、非网格）。
const RING_CENTER := Vector2(900, 788)
const RING_RX := 300.0
const RING_RY := 92.0

var _fog: GPUParticles2D
var _mist: GPUParticles2D
var _leaves: LeafLayer
var _override_sprite: Sprite2D
static var _vignette_texture: ImageTexture
static var _clearing_texture: ImageTexture

func _ready() -> void:
	_apply_override()
	_build_fog()
	_leaves = LeafLayer.new()
	_leaves.name = "FloatingLeaves"
	_leaves.z_index = 3
	add_child(_leaves)

func _apply_override() -> void:
	var entry := VisualCatalog.background_entry()
	var texture := VisualCatalog.load_texture(entry.get("path", ""))
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "CatalogBackground"
	sprite.texture = texture
	sprite.centered = false
	var scale_value := maxf(0.05, float(entry.get("scale", 1.0)))
	sprite.scale = Vector2(scale_value, scale_value)
	var tint: Variant = entry.get("modulate", [])
	if tint is Array and tint.size() >= 4:
		sprite.modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]), float(tint[3]))
	sprite.z_index = -10
	add_child(sprite)
	_override_sprite = sprite

# ---------------------------------------------------------------- 绘制总览

func _draw() -> void:
	var procedural := _override_sprite == null
	if procedural:
		_draw_sky()
		_draw_mountains()
		_draw_horizon_mist()
		_draw_canopies()
		# 远处竹林在空地之后；近景框景竹在空地之上，竹脚落在草里。
		_draw_bamboo_far()
		_draw_clearing()
		_draw_ground_paint()
		_draw_ground_props()
		_draw_bamboo_frames()
	# 光柱 / 地面光斑 / 地面薄雾属于氛围叠加层，替换背景贴图后仍要绘制。
	_draw_ground_light()
	_draw_light_shafts()
	_draw_ground_mist()
	if procedural:
		_draw_foreground()
	_draw_vignette()

func _draw_sky() -> void:
	var top := Color(0.46, 0.52, 0.79)
	var mid := Color(1.0, 0.78, 0.47)
	var low := Color(1.0, 0.92, 0.69)
	var strips := 60
	for i in strips:
		var t := float(i) / float(strips - 1)
		var color := top.lerp(mid, t / 0.6) if t < 0.6 else mid.lerp(low, (t - 0.6) / 0.4)
		draw_rect(Rect2(0, HORIZON * t * 0.86, W, HORIZON / float(strips) + 2.0), color, true)
	# 破晓太阳与暖光晕
	var sun := Vector2(1452, 296)
	for halo: Array in [[210.0, 0.06], [150.0, 0.08], [100.0, 0.12]]:
		draw_circle(sun, float(halo[0]), Color(1.0, 0.9, 0.68, float(halo[1])))
	draw_circle(sun, 54.0, Color(1.0, 0.93, 0.76, 0.55))
	draw_circle(sun, 44.0, Color(1.0, 0.96, 0.82, 0.85))
	# 薄云带
	_ellipse(Vector2(1260, 190), 420, 24, Color(1.0, 0.94, 0.84, 0.12))
	_ellipse(Vector2(880, 290), 360, 18, Color(1.0, 0.92, 0.82, 0.1))
	_ellipse(Vector2(1570, 350), 300, 16, Color(1.0, 0.9, 0.8, 0.09))

func _draw_mountains() -> void:
	# 远山（蓝灰雾色）
	var far := PackedVector2Array([
		Vector2(0, 448), Vector2(150, 372), Vector2(290, 424), Vector2(430, 326),
		Vector2(560, 410), Vector2(700, 356), Vector2(840, 432), Vector2(980, 340),
		Vector2(1120, 416), Vector2(1270, 364), Vector2(1420, 430), Vector2(1570, 358),
		Vector2(1730, 426), Vector2(1920, 378), Vector2(1920, 700), Vector2(0, 700),
	])
	draw_colored_polygon(far, Color(0.51, 0.58, 0.7, 0.52))
	draw_polyline(far.slice(0, 14), Color(1.0, 0.9, 0.72, 0.18), 2.5, true)
	# 近山（青绿），山脊带一条暖色逆光
	var near := PackedVector2Array([
		Vector2(0, 536), Vector2(190, 452), Vector2(360, 514), Vector2(540, 430),
		Vector2(730, 520), Vector2(910, 456), Vector2(1090, 526), Vector2(1270, 442),
		Vector2(1460, 518), Vector2(1640, 466), Vector2(1820, 524), Vector2(1920, 484),
		Vector2(1920, 716), Vector2(0, 716),
	])
	draw_colored_polygon(near, Color(0.32, 0.53, 0.39, 0.8))
	draw_polyline(near.slice(0, 12), Color(1.0, 0.88, 0.66, 0.24), 2.0, true)
	# 山脚薄雾
	_ellipse(Vector2(960, 556), 1050, 56, Color(1.0, 0.92, 0.79, 0.14))
	_ellipse(Vector2(420, 592), 620, 42, Color(1.0, 0.9, 0.76, 0.09))
	_ellipse(Vector2(1520, 596), 560, 40, Color(1.0, 0.9, 0.76, 0.08))

func _draw_horizon_mist() -> void:
	# 林缘暖雾：位于空地远缘之上，帮助山脚、竹林与草坡过渡。
	_ellipse(Vector2(960, 548), 1080, 42, Color(1.0, 0.93, 0.78, 0.09))
	_ellipse(Vector2(420, 574), 640, 34, Color(1.0, 0.92, 0.78, 0.07))
	_ellipse(Vector2(1530, 580), 580, 32, Color(1.0, 0.92, 0.78, 0.06))

func _draw_canopies() -> void:
	# 画面上缘的竹林冠层：把天空与中景压到一起，形成剧场式框景（比旧版更透光）。
	_ellipse(Vector2(70, 34), 270, 190, Color(0.1, 0.2, 0.14, 0.13))
	_ellipse(Vector2(1852, 20), 300, 200, Color(0.1, 0.2, 0.14, 0.11))
	_canopy(Vector2(96, 24), 1.0, Color(0.13, 0.26, 0.18, 0.4))
	_canopy(Vector2(344, -18), 0.8, Color(0.15, 0.29, 0.19, 0.28))
	_canopy(Vector2(1816, 10), -1.0, Color(0.13, 0.26, 0.18, 0.38))
	_canopy(Vector2(1588, -24), -0.75, Color(0.2, 0.33, 0.21, 0.23))

func _canopy(origin: Vector2, side: float, color: Color) -> void:
	var end := origin + Vector2(side * 150.0, 86.0)
	draw_line(origin, end, Color(0.08, 0.14, 0.1, color.a * 0.7), 3.0, true)
	for i in 7:
		var t := 0.2 + float(i) * 0.12
		var anchor := origin.lerp(end, t)
		var angle: float
		if side > 0.0:
			angle = 0.55 + float(i % 3) * 0.34
		else:
			angle = PI - 0.55 - float(i % 3) * 0.34
		_bamboo_leaf(anchor, angle, 58.0 + float((i * 23) % 46), color.lightened(0.04 * float(i % 2)))
		_bamboo_leaf(anchor + Vector2(0, 10), angle + 0.45, 42.0 + float((i * 17) % 30), color.darkened(0.08))

# ---------------------------------------------------------------- 竹林

func _draw_bamboo_far() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A9E
	# 远景竹林：低对比度，铺满中景；竹脚被空地草坡自然遮住。
	for i in 32:
		var x := rng.randf_range(20.0, 1900.0)
		var base_y := rng.randf_range(636.0, 700.0)
		var height := rng.randf_range(240.0, 470.0)
		var lean := rng.randf_range(-26.0, 26.0)
		var width := rng.randf_range(4.0, 8.0)
		var edge := clampf(absf(x - 960.0) / 960.0, 0.0, 1.0)
		var color := Color(0.38, 0.54, 0.39, 0.2 + 0.22 * edge)
		_draw_stalk(x, base_y, height, lean, width, color, rng.randf_range(0.0, TAU))
	# 中央再做几根淡竹，让背景有纵深但不抢角色
	for x: float in [420.0, 760.0, 1160.0, 1510.0]:
		_draw_stalk(x, 680.0, 380.0, (x - 960.0) * 0.015, 6.0, Color(0.4, 0.56, 0.42, 0.26), x * 0.01)

func _draw_bamboo_frames() -> void:
	# 近景框景竹：左右两侧更粗更深；画在空地之上，根部落在草里。
	var frames := [34.0, 82.0, 128.0, 176.0, 1738.0, 1786.0, 1834.0, 1884.0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF4A3
	for index in frames.size():
		var x: float = frames[index]
		var height := 520.0 + float((index * 67) % 210)
		var lean := -18.0 if index < 4 else 18.0
		var color := Color(0.15, 0.29, 0.19, 0.82)
		_draw_stalk(x, 716.0, height, lean, 11.0 + float(index % 3), color, float(index) * 1.7)
		# 竹脚草须与根瘤，避免竹竿像插在空地上
		_ellipse(Vector2(x, 714.0), 20.0, 6.0, Color(0.16, 0.25, 0.14, 0.35), 14)
		_grass_tuft(Vector2(x + rng.randf_range(-9.0, 9.0), 716.0), rng.randf_range(22.0, 40.0), Color(0.24, 0.38, 0.18, 0.85), rng, 5)

func _draw_stalk(x: float, base_y: float, height: float, lean: float, width: float, color: Color, seed_value: float) -> void:
	var top := Vector2(x + lean, base_y - height)
	draw_line(Vector2(x, base_y), top, Color(0.07, 0.12, 0.09, color.a * 0.8), width + 2.5, true)
	draw_line(Vector2(x, base_y), top, color, width, true)
	# 朝阳侧暖色描边
	draw_line(Vector2(x + width * 0.35, base_y), top + Vector2(width * 0.35, 0), Color(1.0, 0.84, 0.58, color.a * 0.28), maxf(1.0, width * 0.25), true)
	# 竹节
	var segments := int(height / 52.0)
	for i in segments:
		var t := float(i + 1) / float(segments + 1)
		var joint := Vector2(x, base_y).lerp(top, t)
		draw_line(joint - Vector2(width * 0.9, 1.5), joint + Vector2(width * 0.9, 1.5), Color(0.08, 0.15, 0.1, color.a * 0.9), 2.0, true)
	# 竹叶：每根 2~3 簇
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_value * 100000.0) + 17
	var clusters := 3 + int(seed_value) % 2
	for c in clusters:
		var t := 0.3 + 0.2 * float(c) + rng.randf_range(0.0, 0.06)
		var anchor := Vector2(x, base_y).lerp(top, minf(t, 0.94))
		var side := -1.0 if fmod(seed_value + float(c), 2.0) < 1.0 else 1.0
		for leaf_index in 4:
			var droop := rng.randf_range(-0.2, 0.9)
			var angle := droop if side > 0.0 else PI - droop
			var length := rng.randf_range(34.0, 66.0)
			var tint := color.lightened(0.12) if leaf_index == 1 else color
			tint.a *= 0.85
			_bamboo_leaf(anchor + Vector2(side * rng.randf_range(2.0, 14.0), rng.randf_range(-8.0, 8.0)), angle, length, tint)

func _bamboo_leaf(origin: Vector2, angle: float, length: float, color: Color) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var perp := Vector2(-dir.y, dir.x)
	var tip := origin + dir * length
	var mid := origin + dir * length * 0.5
	var width := length * 0.16
	var points := PackedVector2Array([origin, mid + perp * width, tip, mid - perp * width])
	draw_colored_polygon(points, color)

# ---------------------------------------------------------------- 林间空地

static func _clearing_edge_y(x: float) -> float:
	var previous: Vector2 = CLEARING_EDGE[0]
	for i in range(1, CLEARING_EDGE.size()):
		var next: Vector2 = CLEARING_EDGE[i]
		if x <= next.x:
			var t := clampf((x - previous.x) / maxf(1.0, next.x - previous.x), 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(previous.y, next.y, t)
		previous = next
	var last: Vector2 = CLEARING_EDGE[CLEARING_EDGE.size() - 1]
	return last.y

func _draw_clearing() -> void:
	var texture := _get_clearing_texture()
	if texture == null:
		_ellipse(Vector2(960, 800), 1240, 330, Color(0.56, 0.62, 0.36, 0.95))
	else:
		draw_texture_rect(texture, Rect2(0, GROUND_TOP, W, GROUND_H), false)
	_draw_clearing_edge_fringe()

func _draw_clearing_edge_fringe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xED6E
	# 远缘柔雾：让草坡从山脚雾里长出来，而不是一条切边。
	for i in 9:
		var x := 60.0 + float(i) * 225.0 + rng.randf_range(-50.0, 50.0)
		var y := _clearing_edge_y(x) + rng.randf_range(-8.0, 4.0)
		_soft_ellipse(Vector2(x, y), rng.randf_range(190.0, 330.0), rng.randf_range(16.0, 30.0), Color(0.98, 0.94, 0.8, 0.07), 3)
	# 远侧草须：沿边缘成簇，低饱和，接住地平线的光。
	for i in 38:
		var x := rng.randf_range(0.0, W)
		var y := _clearing_edge_y(x) + rng.randf_range(-2.0, 16.0)
		_grass_tuft(Vector2(x, y), rng.randf_range(9.0, 26.0), Color(0.4, 0.53, 0.3, 0.55), rng, 3)
	# 几丛矮灌木，打散折线
	for x: float in [210.0, 760.0, 1320.0, 1710.0]:
		var y := _clearing_edge_y(x) + 8.0
		for i in 5:
			var offset := (float(i) - 2.0) * 9.0
			var tip := Vector2(x + offset + rng.randf_range(-5.0, 5.0), y - rng.randf_range(14.0, 32.0))
			draw_line(Vector2(x + offset, y), tip, Color(0.26, 0.4, 0.23, 0.5), rng.randf_range(1.5, 2.8), true)

static func _get_clearing_texture() -> ImageTexture:
	if _clearing_texture != null:
		return _clearing_texture
	const PIXEL_W := 960
	const PIXEL_H := 310
	var macro := FastNoiseLite.new()
	macro.seed = 0x51CE
	macro.frequency = 0.011
	macro.fractal_octaves = 4
	macro.fractal_type = FastNoiseLite.FRACTAL_FBM
	var detail := FastNoiseLite.new()
	detail.seed = 0xBEEF
	detail.frequency = 0.055
	detail.fractal_octaves = 3
	detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	var macro_image := macro.get_image(PIXEL_W, PIXEL_H)
	var detail_image := detail.get_image(PIXEL_W, PIXEL_H)
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = 0xE006
	edge_noise.frequency = 0.006
	edge_noise.fractal_octaves = 2
	var edges := PackedFloat32Array()
	edges.resize(PIXEL_W)
	for x in PIXEL_W:
		var wx := float(x) / float(PIXEL_W - 1) * W
		edges[x] = _clearing_edge_y(wx) + edge_noise.get_noise_1d(wx) * 11.0
	var image := Image.create(PIXEL_W, PIXEL_H, false, Image.FORMAT_RGBA8)
	for y in PIXEL_H:
		var v := float(y) / float(PIXEL_H - 1)
		var wy := GROUND_TOP + v * GROUND_H
		for x in PIXEL_W:
			var edge: float = edges[x]
			var alpha := smoothstep(edge - 8.0, edge + 46.0, wy)
			if alpha <= 0.004:
				# 透明区仍写入草地色，避免线性过滤在远缘插出黑边。
				image.set_pixel(x, y, Color(0.58, 0.68, 0.42, 0.0))
				continue
			var wx := float(x) / float(PIXEL_W - 1) * W
			var macro_v := macro_image.get_pixel(x, y).r
			var detail_v := detail_image.get_pixel(x, y).r
			# 远侧雾草 → 中央受光苔藓/泥地 → 近景深草
			var mid_mix := smoothstep(0.0, 0.42, v)
			var r := lerpf(0.595, 0.525, mid_mix)
			var g := lerpf(0.725, 0.675, mid_mix)
			var b := lerpf(0.41, 0.28, mid_mix)
			var dirt_mix := smoothstep(0.46, 0.72, macro_v) * smoothstep(0.1, 0.38, v) * (1.0 - smoothstep(0.72, 1.0, v))
			dirt_mix *= 0.85
			r = lerpf(r, 0.865, dirt_mix)
			g = lerpf(g, 0.735, dirt_mix)
			b = lerpf(b, 0.41, dirt_mix)
			var near_mix := smoothstep(0.66, 1.0, v)
			r = lerpf(r, 0.375, near_mix)
			g = lerpf(g, 0.545, near_mix)
			b = lerpf(b, 0.23, near_mix)
			# 敌侧后方一束暖光 + 中央受光空地
			var ex := (wx - 440.0) / 430.0
			var ey := (wy - 585.0) / 300.0
			var sun := maxf(0.0, 1.0 - ex * ex - ey * ey) * 0.14
			var cx := (wx - 690.0) / 620.0
			var cy := (wy - 750.0) / 360.0
			sun += maxf(0.0, 1.0 - cx * cx - cy * cy) * 0.13
			r = lerpf(r, 1.0, sun)
			g = lerpf(g, 0.9, sun)
			b = lerpf(b, 0.58, sun)
			# 细碎笔触，避免大片平涂
			var mottle := detail_v - 0.5
			r = clampf(r + mottle * 0.085, 0.0, 1.0)
			g = clampf(g + mottle * 0.08, 0.0, 1.0)
			b = clampf(b + mottle * 0.05, 0.0, 1.0)
			image.set_pixel(x, y, Color(r, g, b, alpha))
	_clearing_texture = ImageTexture.create_from_image(image)
	return _clearing_texture

# ---------------------------------------------------------------- 地面笔触与细节

func _draw_ground_paint() -> void:
	_draw_bamboo_shadows()
	_draw_path()
	_draw_center_ring()

func _draw_bamboo_shadows() -> void:
	# 右上破晓斜射，竹影朝左下；低透明度、宽窄不一，避免形成规则条纹。
	var bands := [
		[Vector2(1435, 566), Vector2(1080, 1080), 64.0, 0.045],
		[Vector2(1570, 590), Vector2(1230, 1050), 34.0, 0.035],
		[Vector2(1690, 598), Vector2(1430, 1010), 22.0, 0.03],
		[Vector2(980, 548), Vector2(720, 900), 22.0, 0.028],
		[Vector2(720, 540), Vector2(500, 820), 30.0, 0.024],
		[Vector2(1160, 600), Vector2(980, 900), 18.0, 0.024],
		[Vector2(300, 500), Vector2(160, 900), 50.0, 0.032],
	]
	for band: Array in bands:
		_shadow_band(band[0], band[1], float(band[2]), Color(0.13, 0.22, 0.15, float(band[3])))
	# 竹叶碎影
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5AD0
	for i in 26:
		var p := Vector2(rng.randf_range(720.0, 1820.0), rng.randf_range(560.0, 1020.0))
		var size := rng.randf_range(18.0, 60.0)
		_ellipse(p, size, size * rng.randf_range(0.22, 0.4), Color(0.12, 0.22, 0.14, rng.randf_range(0.018, 0.04)), 12)

func _shadow_band(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x) * (width * 0.5)
	draw_colored_polygon(PackedVector2Array([a + perp, b + perp, b - perp, a - perp]), color)

func _draw_path() -> void:
	# 一条很淡的踩踏土径：从前景草间蜿蜒到敌侧草地，不经过角色脚底。
	var points := PackedVector2Array([
		Vector2(742, 1082), Vector2(706, 1010), Vector2(668, 944), Vector2(630, 880),
		Vector2(596, 816), Vector2(566, 754), Vector2(540, 700), Vector2(508, 656),
		Vector2(468, 616), Vector2(416, 586), Vector2(356, 556),
	])
	var widths := [148.0, 104.0, 58.0]
	var alphas := [0.022, 0.028, 0.032]
	for i in 3:
		draw_polyline(points, Color(0.88, 0.77, 0.52, float(alphas[i])), float(widths[i]), true)
	# 踏脚石：大小与间距不规则，避免读成新网格。
	var stones := [
		Vector2(704, 1002), Vector2(666, 928), Vector2(628, 858),
		Vector2(592, 792), Vector2(560, 728), Vector2(520, 674),
	]
	for i in stones.size():
		var p: Vector2 = stones[i]
		_flat_stone(p, 13.0 + float((i * 7) % 9), 0.5)

func _flat_stone(origin: Vector2, radius: float, alpha: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(origin.x * 13.0 + origin.y * 7.0)
	var points := PackedVector2Array()
	var count := 8
	for i in count:
		var angle := TAU * float(i) / float(count)
		var r := radius * rng.randf_range(0.78, 1.08)
		points.append(origin + Vector2(cos(angle) * r, sin(angle) * r * 0.45))
	draw_colored_polygon(points, Color(0.62, 0.6, 0.49, alpha * 0.55))
	var rim := points.duplicate()
	rim.append(points[0])
	draw_polyline(rim, Color(0.35, 0.34, 0.26, alpha * 0.35), 1.2, true)
	draw_line(origin + Vector2(-radius * 0.5, -radius * 0.16), origin + Vector2(radius * 0.2, -radius * 0.2), Color(0.95, 0.9, 0.72, alpha * 0.35), 1.5, true)

func _draw_center_ring() -> void:
	# 半埋石环：只当“场地中心”的暗示，不连线、不成格、不描金。
	_soft_ellipse(RING_CENTER, RING_RX * 1.06, RING_RY * 1.04, Color(0.96, 0.86, 0.56, 0.05), 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x0A11
	for i in 34:
		if i == 7 or i == 18 or i == 29:
			continue
		var angle := TAU * float(i) / 34.0 + rng.randf_range(-0.025, 0.025)
		var radius_scale := rng.randf_range(0.97, 1.03)
		var p := RING_CENTER + Vector2(cos(angle) * RING_RX * radius_scale, sin(angle) * RING_RY * radius_scale)
		var size := rng.randf_range(9.0, 18.0)
		if i % 5 == 0:
			size += 3.5
		_ellipse(p + Vector2(0, size * 0.3), size * 1.1, size * 0.32, Color(0.16, 0.2, 0.12, 0.12), 12)
		var stone := PackedVector2Array([
			p + Vector2(-size, 0.0), p + Vector2(-size * 0.7, -size * 0.42),
			p + Vector2(-size * 0.15, -size * 0.55), p + Vector2(size * 0.55, -size * 0.38),
			p + Vector2(size, 0.0), p + Vector2(size * 0.5, size * 0.26), p + Vector2(-size * 0.5, size * 0.28),
		])
		draw_colored_polygon(stone, Color(0.58, 0.57, 0.47, 0.58))
		draw_line(p + Vector2(-size * 0.55, -size * 0.35), p + Vector2(size * 0.2, -size * 0.42), Color(1.0, 0.92, 0.7, 0.25), 1.4, true)
	# 环内的暖土与浅苔，给中心一点重量，但保持低对比。
	_ellipse(RING_CENTER + Vector2(0, 8), 160.0, 42.0, Color(0.88, 0.79, 0.54, 0.045), 24)
	_ellipse(RING_CENTER + Vector2(-34, 2), 82.0, 28.0, Color(0.45, 0.55, 0.3, 0.055), 20)

func _draw_ground_props() -> void:
	_draw_bamboo_roots()
	# 石块避开单位脚底、HUD 面板与名字信息带。
	_painted_rock(Vector2(148, 706), 50.0, 0.95)
	_painted_rock(Vector2(334, 626), 21.0, 0.75)
	_painted_rock(Vector2(1180, 704), 32.0, 0.8)
	_painted_rock(Vector2(1782, 966), 54.0, 0.9)
	_painted_rock(Vector2(724, 1042), 17.0, 0.65)
	_painted_rock(Vector2(1092, 1018), 19.0, 0.65)
	_bamboo_stump(Vector2(1038, 712), 24.0)
	_bamboo_stump(Vector2(1648, 1012), 30.0)
	_bamboo_stump(Vector2(706, 986), 20.0)
	_draw_meadow_grass()
	_fallen_leaves()
	_flowers()

func _draw_meadow_grass() -> void:
	# 中景稀疏草簇与苔斑，给空地尺度感，不挡角色脚底。
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x6A55
	for i in 34:
		var x := rng.randf_range(20.0, 1900.0)
		var y := rng.randf_range(_clearing_edge_y(x) + 30.0, 930.0)
		_grass_tuft(Vector2(x, y), rng.randf_range(7.0, 18.0), Color(0.36, 0.5, 0.26, 0.55), rng, 3)
	for i in 20:
		var x := rng.randf_range(30.0, 1890.0)
		var y := rng.randf_range(_clearing_edge_y(x) + 34.0, 940.0)
		_ellipse(Vector2(x, y), rng.randf_range(5.0, 13.0), rng.randf_range(2.0, 5.0), Color(0.4, 0.5, 0.3, 0.18), 10)

func _draw_bamboo_roots() -> void:
	for cluster: Vector2 in [Vector2(700, 566), Vector2(1120, 602), Vector2(1300, 612)]:
		for i in 4:
			var dir := -1.0 + 0.6 * float(i)
			var end := cluster + Vector2(dir * (24.0 + 10.0 * float(i)), 9.0 + 5.0 * float(i))
			draw_line(cluster, end, Color(0.28, 0.24, 0.16, 0.5), 2.4, true)
			draw_line(end, end + Vector2(dir * 12.0, 3.0), Color(0.24, 0.21, 0.14, 0.38), 1.4, true)

func _painted_rock(origin: Vector2, radius: float, strength: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(origin.x * 97.0 + origin.y * 31.0 + radius * 13.0)
	var points := PackedVector2Array()
	var count := 9
	for i in count:
		var angle := TAU * float(i) / float(count)
		var rr := radius * rng.randf_range(0.78, 1.12)
		points.append(origin + Vector2(cos(angle) * rr, sin(angle) * rr * rng.randf_range(0.48, 0.68)))
	# 接触阴影
	_ellipse(origin + Vector2(radius * 0.12, radius * 0.26), radius * 1.18, radius * 0.34, Color(0.12, 0.16, 0.1, 0.18 * strength), 24)
	# 石体：深底 → 中色 → 受光面
	draw_colored_polygon(points, Color(0.3, 0.32, 0.25, 0.9 * strength))
	var mid := PackedVector2Array()
	for point: Vector2 in points:
		mid.append(origin + (point - origin) * 0.86 + Vector2(-2.0, -radius * 0.12))
	draw_colored_polygon(mid, Color(0.47, 0.48, 0.37, 0.9 * strength))
	var lit := PackedVector2Array([
		origin + Vector2(-radius * 0.68, -radius * 0.12),
		origin + Vector2(-radius * 0.36, -radius * 0.52),
		origin + Vector2(radius * 0.08, -radius * 0.44),
		origin + Vector2(radius * 0.3, -radius * 0.1),
		origin + Vector2(-radius * 0.08, -radius * 0.2),
	])
	draw_colored_polygon(lit, Color(0.72, 0.7, 0.52, 0.6 * strength))
	# 苔藓与裂纹
	_ellipse(origin + Vector2(-radius * 0.3, radius * 0.05), radius * 0.34, radius * 0.14, Color(0.36, 0.47, 0.26, 0.5 * strength), 16)
	_ellipse(origin + Vector2(radius * 0.3, radius * 0.12), radius * 0.22, radius * 0.1, Color(0.4, 0.5, 0.28, 0.4 * strength), 14)
	draw_line(origin + Vector2(radius * 0.1, -radius * 0.3), origin + Vector2(radius * 0.24, radius * 0.16), Color(0.18, 0.19, 0.14, 0.35 * strength), 1.2, true)
	draw_line(origin + Vector2(-radius * 0.4, -radius * 0.18), origin + Vector2(-radius * 0.1, radius * 0.12), Color(0.18, 0.19, 0.14, 0.3 * strength), 1.0, true)

func _bamboo_stump(origin: Vector2, radius: float) -> void:
	_ellipse(origin + Vector2(0, radius * 0.18), radius * 1.25, radius * 0.34, Color(0.12, 0.16, 0.1, 0.2), 20)
	var height := radius * 1.15
	var body := PackedVector2Array([
		origin + Vector2(-radius, 0.0), origin + Vector2(-radius * 0.82, -height),
		origin + Vector2(radius * 0.82, -height), origin + Vector2(radius, 0.0),
	])
	draw_colored_polygon(body, Color(0.47, 0.42, 0.28, 0.9))
	draw_line(origin + Vector2(-radius * 0.7, -height * 0.2), origin + Vector2(-radius * 0.78, -height * 0.92), Color(0.72, 0.64, 0.42, 0.35), 2.0, true)
	# 截面年轮
	_ellipse(origin + Vector2(0, -height), radius * 0.85, radius * 0.3, Color(0.76, 0.65, 0.42, 0.95), 24)
	_ellipse_ring(origin + Vector2(0, -height), radius * 0.55, radius * 0.19, Color(0.44, 0.36, 0.22, 0.5), 1.4)
	_ellipse_ring(origin + Vector2(0, -height), radius * 0.28, radius * 0.1, Color(0.44, 0.36, 0.22, 0.4), 1.2)
	# 新芽
	var shoot := origin + Vector2(radius * 0.35, -height)
	draw_line(shoot, shoot + Vector2(radius * 0.7, -radius * 1.2), Color(0.36, 0.55, 0.26, 0.9), 2.5, true)
	_bamboo_leaf(shoot + Vector2(radius * 0.55, -radius * 0.85), -0.55, radius * 1.5, Color(0.42, 0.62, 0.28, 0.9))
	_bamboo_leaf(shoot + Vector2(radius * 0.6, -radius * 0.75), 1.2, radius * 1.3, Color(0.48, 0.66, 0.3, 0.85))

func _fallen_leaves() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1EAF0
	var tints := [Color(0.78, 0.6, 0.28, 0.55), Color(0.62, 0.6, 0.32, 0.5), Color(0.7, 0.46, 0.26, 0.45)]
	for i in 46:
		var x := rng.randf_range(40.0, 1880.0)
		var y := rng.randf_range(_clearing_edge_y(x) + 24.0, 1050.0)
		var tint: Color = tints[rng.randi_range(0, tints.size() - 1)]
		_bamboo_leaf(Vector2(x, y), rng.randf_range(0.0, TAU), rng.randf_range(5.0, 10.0), tint)
	# 近竹丛处更密，形成自然的落叶带
	for i in 18:
		var x := rng.randf_range(0.0, W)
		var y := _clearing_edge_y(x) + rng.randf_range(6.0, 30.0)
		_bamboo_leaf(Vector2(x, y), rng.randf_range(0.0, TAU), rng.randf_range(4.0, 8.0), Color(0.72, 0.58, 0.3, 0.45))

func _flowers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF10A
	var spots := [
		Vector2(294, 762), Vector2(168, 790), Vector2(548, 620), Vector2(986, 606),
		Vector2(1318, 664), Vector2(1752, 952), Vector2(772, 1034), Vector2(1128, 1030),
		Vector2(430, 772), Vector2(1218, 764), Vector2(858, 700), Vector2(1310, 762),
	]
	for spot: Vector2 in spots:
		for i in rng.randi_range(2, 4):
			var pos := spot + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-10.0, 10.0))
			_flower(pos, rng.randf_range(3.0, 5.5), rng.randi_range(0, 2))

func _flower(origin: Vector2, size: float, palette: int) -> void:
	var petal := Color(0.97, 0.93, 0.82, 0.85)
	if palette == 1:
		petal = Color(0.95, 0.74, 0.78, 0.85)
	elif palette == 2:
		petal = Color(0.98, 0.88, 0.55, 0.9)
	draw_line(origin, origin + Vector2(0, size * 1.2), Color(0.3, 0.44, 0.22, 0.6), 1.0, true)
	for i in 5:
		var angle := TAU * float(i) / 5.0 + 0.3
		var p := origin + Vector2(cos(angle) * size, sin(angle) * size * 0.8)
		_ellipse(p, size * 0.55, size * 0.4, petal, 8)
	draw_circle(origin, size * 0.32, Color(0.92, 0.74, 0.3, 0.9))

# ---------------------------------------------------------------- 光、雾、前景

func _draw_ground_light() -> void:
	# 左上敌群背后补一层暖光，避免敌方后排落在竹林暗带里；
	# 其余为中央受光空地、右中与近景的晨光衰减。
	_soft_ellipse(Vector2(470, 588), 500.0, 168.0, Color(1.0, 0.83, 0.5, 0.16), 5)
	_soft_ellipse(Vector2(760, 792), 650.0, 230.0, Color(1.0, 0.86, 0.55, 0.09), 5)
	_soft_ellipse(Vector2(1120, 850), 480.0, 160.0, Color(1.0, 0.87, 0.58, 0.05), 4)
	_soft_ellipse(Vector2(1450, 700), 320.0, 110.0, Color(1.0, 0.89, 0.62, 0.04), 3)
	_soft_ellipse(Vector2(960, 1010), 620.0, 120.0, Color(1.0, 0.89, 0.62, 0.035), 3)
	# 一层很淡的整体暖光，把空地收成同一块受光面（仍低于单位与 HUD 的对比）。
	_soft_ellipse(Vector2(900, 780), 1050.0, 360.0, Color(1.0, 0.83, 0.48, 0.065), 4)

func _draw_light_shafts() -> void:
	# 从右上破晓处斜射进竹林的光柱，宽面低透明度 + 亮芯
	_light_beam(Vector2(1210, 0), Vector2(1432, 0), Vector2(942, 840), Vector2(690, 840), Color(1.0, 0.94, 0.76, 0.05))
	_light_beam(Vector2(1380, 0), Vector2(1516, 0), Vector2(1120, 800), Vector2(920, 800), Color(1.0, 0.95, 0.8, 0.058))
	_light_beam(Vector2(1540, 0), Vector2(1652, 0), Vector2(1330, 780), Vector2(1160, 780), Color(1.0, 0.96, 0.84, 0.044))
	_light_beam(Vector2(1286, 0), Vector2(1358, 0), Vector2(1046, 900), Vector2(894, 900), Color(1.0, 0.98, 0.9, 0.055))
	# 光柱里的浮尘
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51F7
	for i in 28:
		var t := rng.randf()
		var x := lerpf(780.0, 1480.0, t) + rng.randf_range(-70.0, 70.0)
		var y := rng.randf_range(120.0, 880.0)
		draw_circle(Vector2(x, y), rng.randf_range(1.0, 2.8), Color(1.0, 0.96, 0.82, rng.randf_range(0.06, 0.18)))

func _light_beam(a: Vector2, b: Vector2, c: Vector2, d: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), color)
	var mid_top := a.lerp(b, 0.5)
	var mid_bottom := d.lerp(c, 0.5)
	draw_colored_polygon(PackedVector2Array([
		mid_top + Vector2(-22, 0), mid_top + Vector2(22, 0),
		mid_bottom + Vector2(34, 0), mid_bottom + Vector2(-34, 0),
	]), Color(color.r, color.g, color.b, color.a * 0.7))

func _draw_ground_mist() -> void:
	_ellipse(Vector2(960, 700), 1150, 40, Color(1.0, 0.93, 0.8, 0.05))
	_ellipse(Vector2(520, 748), 560, 28, Color(1.0, 0.91, 0.78, 0.035))
	_ellipse(Vector2(1470, 772), 500, 26, Color(1.0, 0.91, 0.78, 0.035))
	# 远端林缘薄雾：压住空地远缘，让敌群读起来在雾光里而不在暗带里。
	_soft_ellipse(Vector2(470, 556), 600.0, 36.0, Color(1.0, 0.95, 0.86, 0.06), 3)

func _draw_foreground() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF00D
	# 底边柔暗渐变（中心在画外，避免出现一条硬边）。
	_soft_ellipse(Vector2(960, 1128), 1200.0, 128.0, Color(0.22, 0.32, 0.17, 0.12), 4)
	# 近景草更深更密，但有暖色草尖。
	for i in 78:
		var x := rng.randf_range(0.0, W)
		var y := rng.randf_range(950.0, 1080.0)
		var tint := Color(0.24, 0.38, 0.18, 0.9) if i % 4 != 0 else Color(0.36, 0.46, 0.22, 0.8)
		_grass_tuft(Vector2(x, y), rng.randf_range(16.0, 46.0), tint, rng, 5)
	# 更宽的草叶，增加近景的层次与手绘感。
	for i in 18:
		var x := rng.randf_range(0.0, W)
		var y := rng.randf_range(990.0, 1075.0)
		for b in 3:
			var tint := Color(0.26, 0.4, 0.19, 0.9) if b != 1 else Color(0.38, 0.5, 0.24, 0.85)
			_broad_blade(Vector2(x + rng.randf_range(-12.0, 12.0), y), rng.randf_range(24.0, 58.0), rng.randf_range(-16.0, 16.0), tint)
	# 两侧舞台收边
	for x: float in [32.0, 78.0, 126.0, 170.0, 1750.0, 1802.0, 1852.0, 1894.0]:
		_grass_tuft(Vector2(x, 1024.0), 66.0, Color(0.2, 0.33, 0.16, 0.95), rng, 6)
		_broad_blade(Vector2(x, 1030.0), 76.0, -8.0 if x < 960.0 else 8.0, Color(0.22, 0.35, 0.17, 0.95))
	# 前景零星落叶
	for i in 12:
		var x := rng.randf_range(120.0, 1800.0)
		var y := rng.randf_range(960.0, 1060.0)
		_bamboo_leaf(Vector2(x, y), rng.randf_range(0.0, TAU), rng.randf_range(5.0, 9.0), Color(0.7, 0.56, 0.28, 0.4))

func _grass_tuft(origin: Vector2, height: float, color: Color, rng: RandomNumberGenerator, blades: int = 4) -> void:
	for i in blades:
		var lean := rng.randf_range(-height * 0.3, height * 0.3)
		var tip := origin + Vector2(lean, -height * rng.randf_range(0.65, 1.0))
		draw_line(origin + Vector2(rng.randf_range(-5.0, 5.0), 0), tip, color, rng.randf_range(1.5, 3.0), true)
		draw_line(origin, tip, Color(color.r + 0.12, color.g + 0.13, color.b + 0.04, color.a * 0.5), 1.0, true)

func _broad_blade(origin: Vector2, height: float, lean: float, color: Color) -> void:
	# 柳叶形草叶：宽根部 + 细尖端，比直线更有绘制感。
	var tip := origin + Vector2(lean, -height)
	var width := clampf(height * 0.065, 1.5, 4.2)
	var points := PackedVector2Array([
		origin + Vector2(-width, 0.0),
		origin + Vector2(lean * 0.35 - width * 0.6, -height * 0.5),
		tip,
		origin + Vector2(lean * 0.35 + width * 0.6, -height * 0.5),
		origin + Vector2(width, 0.0),
	])
	draw_colored_polygon(points, color)
	draw_line(origin, tip, Color(color.r + 0.12, color.g + 0.13, color.b + 0.05, color.a * 0.5), 1.0, true)

func _draw_vignette() -> void:
	var texture := _get_vignette_texture()
	if texture != null:
		draw_texture_rect(texture, Rect2(0, 0, W, H), false)

static func _get_vignette_texture() -> ImageTexture:
	if _vignette_texture != null:
		return _vignette_texture
	var image := Image.create(320, 180, false, Image.FORMAT_RGBA8)
	for y in 180:
		for x in 320:
			var nx := (float(x) / 319.0 - 0.5) * 2.0
			var ny := (float(y) / 179.0 - 0.5) * 2.0
			var d := sqrt(nx * nx * 0.8 + ny * ny)
			var a := clampf((d - 0.72) / 0.55, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a) * 0.08
			image.set_pixel(x, y, Color(0.04, 0.035, 0.045, a))
	_vignette_texture = ImageTexture.create_from_image(image)
	return _vignette_texture

# ---------------------------------------------------------------- 几何辅助

func _ellipse(center: Vector2, rx: float, ry: float, color: Color, count: int = 30) -> void:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)

func _ellipse_ring(center: Vector2, rx: float, ry: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polyline(points, color, width, true)

func _soft_ellipse(center: Vector2, rx: float, ry: float, color: Color, layers: int = 4) -> void:
	for i in layers:
		var t := float(i) / float(maxi(1, layers - 1))
		var scale_out := 1.0 - t * 0.55
		_ellipse(center, rx * scale_out, ry * scale_out, Color(color.r, color.g, color.b, color.a / float(layers)), 40)

# ---------------------------------------------------------------- 雾粒子

func _build_fog() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_fog = _make_mist_emitter(Vector2(960, 596), Vector2(1040, 30), Color(1.0, 0.94, 0.85, 0.09), 36, 3.0, 6.0)
	_mist = _make_mist_emitter(Vector2(960, 764), Vector2(1100, 34), Color(1.0, 0.9, 0.78, 0.05), 24, 4.0, 8.0)

func _make_mist_emitter(pos: Vector2, extents: Vector2, color: Color, amount: int, scale_min: float, scale_max: float) -> GPUParticles2D:
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(extents.x, extents.y, 1.0)
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 6.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 11.0
	mat.gravity = Vector3.ZERO
	mat.color = color
	mat.scale_min = scale_min
	mat.scale_max = scale_max
	var particles := GPUParticles2D.new()
	particles.process_material = mat
	particles.texture = _soft_circle_texture()
	particles.amount = amount
	particles.lifetime = 20.0
	particles.preprocess = 10.0
	particles.position = pos
	particles.emitting = true
	add_child(particles)
	return particles

static func _soft_circle_texture() -> ImageTexture:
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var distance := Vector2(x - 15.5, y - 15.5).length() / 16.0
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)

# ---------------------------------------------------------------- 飘叶层

class LeafLayer extends Node2D:
	const COUNT := 16

	var _leaves: Array[Dictionary] = []
	var _elapsed := 0.0
	var _rng := RandomNumberGenerator.new()

	func _ready() -> void:
		_rng.seed = 0x1EAF
		for i in COUNT:
			_leaves.append({
				"pos": Vector2(_rng.randf_range(0.0, 1980.0), _rng.randf_range(110.0, 920.0)),
				"speed": _rng.randf_range(7.0, 22.0),
				"sway": _rng.randf_range(0.5, 1.4),
				"phase": _rng.randf_range(0.0, TAU),
				"spin": _rng.randf_range(-0.6, 0.6),
				"size": _rng.randf_range(5.0, 10.0),
				"tint": Color(0.82, 0.68, 0.36, 0.62) if i % 3 != 0 else Color(0.52, 0.68, 0.38, 0.55),
				"depth": _rng.randf_range(0.55, 1.0),
			})
		if DisplayServer.get_name() == "headless":
			set_process(false)

	func _process(delta: float) -> void:
		_elapsed += delta
		for leaf in _leaves:
			var pos: Vector2 = leaf["pos"]
			pos.x += float(leaf["speed"]) * float(leaf["depth"]) * delta
			pos.y += sin(_elapsed * float(leaf["sway"]) + float(leaf["phase"])) * 8.0 * delta
			if pos.x > 2000.0:
				pos.x = -40.0
				pos.y = _rng.randf_range(110.0, 920.0)
			leaf["pos"] = pos
		queue_redraw()

	func _draw() -> void:
		for leaf in _leaves:
			var pos: Vector2 = leaf["pos"]
			var angle := float(leaf["phase"]) + _elapsed * float(leaf["spin"]) + sin(_elapsed * 0.7 + float(leaf["phase"])) * 0.5
			var dir := Vector2(cos(angle), sin(angle))
			var perp := Vector2(-dir.y, dir.x)
			var length: float = leaf["size"]
			var width := length * 0.34
			var tint: Color = leaf["tint"]
			var points := PackedVector2Array([
				pos,
				pos + dir * length * 0.5 + perp * width,
				pos + dir * length,
				pos + dir * length * 0.5 - perp * width,
			])
			draw_colored_polygon(points, tint)
			draw_line(pos, pos + dir * length, Color(0.25, 0.22, 0.12, tint.a * 0.6), 1.0, true)
