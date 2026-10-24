class_name BackgroundView
extends Node2D

# 原创程序化竹林黎明：天空暖光 → 远山 → 竹林中景 → 地面 → 前景草石，
# 叠加雾带、光柱、飘叶与暗角。所有元素由 draw_* 原语绘制，不依赖外部素材。
# 若 visual_catalog.json 提供了背景图，则整层替换为 Sprite2D（暗角保留）。
# headless 下跳过 GPU 粒子，静态绘制仍可安全执行。

const W := 1920.0
const H := 1080.0
const HORIZON := 612.0
const OUTLINE := Color(0.09, 0.1, 0.08, 0.55)

var _fog: GPUParticles2D
var _mist: GPUParticles2D
var _leaves: LeafLayer
var _override_sprite: Sprite2D
static var _vignette_texture: ImageTexture

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
	if _override_sprite == null:
		_draw_sky()
		_draw_mountains()
		_draw_horizon_mist()
		_draw_canopies()
		_draw_bamboo()
		_draw_ground()
		_draw_light_shafts()
		_draw_ground_mist()
		_draw_foreground()
	_draw_vignette()

func _draw_sky() -> void:
	var top := Color(0.45, 0.49, 0.58)
	var mid := Color(0.9, 0.73, 0.56)
	var low := Color(1.0, 0.92, 0.77)
	var strips := 60
	for i in strips:
		var t := float(i) / float(strips - 1)
		var color := top.lerp(mid, t / 0.6) if t < 0.6 else mid.lerp(low, (t - 0.6) / 0.4)
		draw_rect(Rect2(0, HORIZON * t * 0.86, W, HORIZON / float(strips) + 2.0), color, true)
	# 破晓太阳与暖光晕
	var sun := Vector2(1452, 296)
	for halo: Array in [[210.0, 0.055], [150.0, 0.075], [100.0, 0.11]]:
		draw_circle(sun, float(halo[0]), Color(1.0, 0.9, 0.68, float(halo[1])))
	draw_circle(sun, 54.0, Color(1.0, 0.93, 0.76, 0.5))
	draw_circle(sun, 44.0, Color(1.0, 0.96, 0.82, 0.8))
	# 薄云带
	_ellipse(Vector2(1260, 190), 420, 24, Color(1.0, 0.94, 0.84, 0.1))
	_ellipse(Vector2(880, 290), 360, 18, Color(1.0, 0.92, 0.82, 0.08))
	_ellipse(Vector2(1570, 350), 300, 16, Color(1.0, 0.9, 0.8, 0.08))

func _draw_mountains() -> void:
	# 远山（蓝灰雾色）
	var far := PackedVector2Array([
		Vector2(0, 448), Vector2(150, 372), Vector2(290, 424), Vector2(430, 326),
		Vector2(560, 410), Vector2(700, 356), Vector2(840, 432), Vector2(980, 340),
		Vector2(1120, 416), Vector2(1270, 364), Vector2(1420, 430), Vector2(1570, 358),
		Vector2(1730, 426), Vector2(1920, 378), Vector2(1920, 700), Vector2(0, 700),
	])
	draw_colored_polygon(far, Color(0.44, 0.48, 0.53, 0.55))
	draw_polyline(far.slice(0, 14), Color(1.0, 0.9, 0.72, 0.14), 2.5, true)
	# 近山（青绿），山脊带一条暖色逆光
	var near := PackedVector2Array([
		Vector2(0, 536), Vector2(190, 452), Vector2(360, 514), Vector2(540, 430),
		Vector2(730, 520), Vector2(910, 456), Vector2(1090, 526), Vector2(1270, 442),
		Vector2(1460, 518), Vector2(1640, 466), Vector2(1820, 524), Vector2(1920, 484),
		Vector2(1920, 716), Vector2(0, 716),
	])
	draw_colored_polygon(near, Color(0.28, 0.4, 0.36, 0.82))
	draw_polyline(near.slice(0, 12), Color(1.0, 0.88, 0.66, 0.2), 2.0, true)
	# 山脚薄雾
	_ellipse(Vector2(960, 560), 1050, 52, Color(1.0, 0.92, 0.8, 0.13))
	_ellipse(Vector2(420, 600), 620, 40, Color(1.0, 0.9, 0.78, 0.09))
	_ellipse(Vector2(1520, 606), 560, 38, Color(1.0, 0.9, 0.78, 0.08))

func _draw_horizon_mist() -> void:
	_ellipse(Vector2(960, 636), 980, 38, Color(1.0, 0.95, 0.86, 0.09))

func _draw_canopies() -> void:
	# 画面上缘的竹林冠层：把天空与中景压到一起，形成剧场式框景
	_ellipse(Vector2(70, 34), 270, 190, Color(0.09, 0.18, 0.13, 0.2))
	_ellipse(Vector2(1852, 20), 300, 200, Color(0.09, 0.18, 0.13, 0.18))
	_canopy(Vector2(96, 24), 1.0, Color(0.1, 0.22, 0.15, 0.5))
	_canopy(Vector2(344, -18), 0.8, Color(0.12, 0.25, 0.17, 0.36))
	_canopy(Vector2(1816, 10), -1.0, Color(0.1, 0.22, 0.15, 0.48))
	_canopy(Vector2(1588, -24), -0.75, Color(0.18, 0.3, 0.19, 0.3))

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

func _draw_bamboo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5A9E
	# 远景竹林：低对比度，铺满中景
	for i in 32:
		var x := rng.randf_range(20.0, 1900.0)
		var base_y := rng.randf_range(636.0, 700.0)
		var height := rng.randf_range(240.0, 470.0)
		var lean := rng.randf_range(-26.0, 26.0)
		var width := rng.randf_range(4.0, 8.0)
		var edge := clampf(absf(x - 960.0) / 960.0, 0.0, 1.0)
		var color := Color(0.3, 0.44, 0.33, 0.26 + 0.24 * edge)
		_draw_stalk(x, base_y, height, lean, width, color, rng.randf_range(0.0, TAU))
	# 近景框景竹：左右两侧更粗更深，形成剧场边框
	var frames := [34.0, 82.0, 128.0, 176.0, 1738.0, 1786.0, 1834.0, 1884.0]
	for index in frames.size():
		var x: float = frames[index]
		var height := 520.0 + float((index * 67) % 210)
		var lean := -18.0 if index < 4 else 18.0
		var color := Color(0.12, 0.23, 0.17, 0.92)
		_draw_stalk(x, 716.0, height, lean, 11.0 + float(index % 3), color, float(index) * 1.7)
	# 中央再做几根淡竹，让背景有纵深但不抢角色
	for x: float in [420.0, 760.0, 1160.0, 1510.0]:
		_draw_stalk(x, 680.0, 380.0, (x - 960.0) * 0.015, 6.0, Color(0.32, 0.47, 0.36, 0.3), x * 0.01)

func _draw_stalk(x: float, base_y: float, height: float, lean: float, width: float, color: Color, seed_value: float) -> void:
	var top := Vector2(x + lean, base_y - height)
	draw_line(Vector2(x, base_y), top, Color(0.07, 0.12, 0.09, color.a * 0.8), width + 2.5, true)
	draw_line(Vector2(x, base_y), top, color, width, true)
	# 朝阳侧暖色描边
	draw_line(Vector2(x + width * 0.35, base_y), top + Vector2(width * 0.35, 0), Color(1.0, 0.82, 0.55, color.a * 0.22), maxf(1.0, width * 0.25), true)
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

func _draw_ground() -> void:
	var top := Color(0.47, 0.53, 0.33)
	var bottom := Color(0.17, 0.23, 0.16)
	var strips := 46
	for i in strips:
		var t := float(i) / float(strips - 1)
		var color := top.lerp(bottom, t)
		draw_rect(Rect2(0, HORIZON + (H - HORIZON) * t, W, (H - HORIZON) / float(strips) + 2.0), color, true)
	# 晨光下的中央场地
	_ellipse(Vector2(960, 866), 800, 214, Color(0.9, 0.76, 0.48, 0.09))
	_ellipse(Vector2(960, 872), 590, 150, Color(0.98, 0.84, 0.58, 0.06))
	# 地平线暖边
	draw_rect(Rect2(0, HORIZON - 3, W, 5), Color(1.0, 0.9, 0.7, 0.2), true)
	draw_rect(Rect2(0, HORIZON + 2, W, 5), Color(0.16, 0.22, 0.15, 0.25), true)
	# 断续草纹 / 光斑（避免整幅横线显得像条纹地板）
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBEEF
	for i in 34:
		var y := HORIZON + 20.0 + float(i) * 12.0 + rng.randf_range(-5.0, 5.0)
		var x0 := rng.randf_range(-180.0, 1760.0)
		var length := rng.randf_range(240.0, 620.0)
		var alpha := 0.035 + 0.03 * (1.0 - float(i) / 34.0)
		var tint := Color(0.92, 0.86, 0.58, alpha) if i % 3 != 0 else Color(0.16, 0.22, 0.13, alpha * 1.2)
		draw_line(Vector2(x0, y), Vector2(x0 + length, y - rng.randf_range(3.0, 12.0)), tint, rng.randf_range(1.5, 3.5), true)
	# 零散草叶（中景）
	for i in 38:
		var x := rng.randf_range(20.0, 1900.0)
		var y := rng.randf_range(HORIZON + 20.0, 960.0)
		var lean := rng.randf_range(-8.0, 8.0)
		var h := rng.randf_range(6.0, 20.0)
		draw_line(Vector2(x, y), Vector2(x + lean, y - h), Color(0.32, 0.44, 0.24, 0.38), 1.5, true)
	# 地平线低矮灌木剪影，柔化直线边界
	for i in 22:
		var x := rng.randf_range(0.0, W)
		var base := HORIZON + rng.randf_range(4.0, 20.0)
		for blade in 3:
			var offset := float(blade - 1) * 5.0
			draw_line(Vector2(x + offset, base), Vector2(x + offset + rng.randf_range(-3.0, 3.0), base - rng.randf_range(8.0, 20.0)), Color(0.15, 0.26, 0.17, 0.5), 1.5, true)
	# 阳光落在地面的暖斑
	_ellipse(Vector2(1380, 806), 420, 120, Color(1.0, 0.9, 0.62, 0.045))
	_ellipse(Vector2(520, 846), 360, 104, Color(1.0, 0.9, 0.62, 0.035))

func _draw_light_shafts() -> void:
	# 从右上破晓处斜射进竹林的光柱，宽面低透明度 + 亮芯
	_light_beam(Vector2(1210, 0), Vector2(1432, 0), Vector2(942, 840), Vector2(690, 840), Color(1.0, 0.94, 0.76, 0.045))
	_light_beam(Vector2(1380, 0), Vector2(1516, 0), Vector2(1120, 800), Vector2(920, 800), Color(1.0, 0.95, 0.8, 0.05))
	_light_beam(Vector2(1540, 0), Vector2(1652, 0), Vector2(1330, 780), Vector2(1160, 780), Color(1.0, 0.96, 0.84, 0.038))
	_light_beam(Vector2(1286, 0), Vector2(1358, 0), Vector2(1046, 900), Vector2(894, 900), Color(1.0, 0.98, 0.9, 0.05))
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
	# 叠一条更窄的亮芯，营造柔和体积感
	var mid_top := a.lerp(b, 0.5)
	var mid_bottom := d.lerp(c, 0.5)
	draw_colored_polygon(PackedVector2Array([
		mid_top + Vector2(-22, 0), mid_top + Vector2(22, 0),
		mid_bottom + Vector2(34, 0), mid_bottom + Vector2(-34, 0),
	]), Color(color.r, color.g, color.b, color.a * 0.7))

func _draw_ground_mist() -> void:
	_ellipse(Vector2(960, 704), 1100, 44, Color(1.0, 0.92, 0.79, 0.055))
	_ellipse(Vector2(520, 760), 540, 30, Color(1.0, 0.9, 0.76, 0.04))
	_ellipse(Vector2(1470, 788), 500, 28, Color(1.0, 0.9, 0.76, 0.04))

func _draw_foreground() -> void:
	# 前景草簇（画面下缘 + 两侧收边）
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xF00D
	for i in 58:
		var x := rng.randf_range(0.0, W)
		var y := rng.randf_range(930.0, 1080.0)
		_grass_tuft(Vector2(x, y), rng.randf_range(14.0, 40.0), Color(0.16, 0.28, 0.16, 0.85), rng)
	# 两侧加高，形成舞台框
	for x: float in [40.0, 96.0, 152.0, 1780.0, 1832.0, 1886.0]:
		_grass_tuft(Vector2(x, 1010.0), 58.0, Color(0.12, 0.23, 0.13, 0.92), rng)
	# 石块
	_rock(Vector2(150, 972), 66, Color(0.34, 0.37, 0.3))
	_rock(Vector2(1812, 946), 54, Color(0.31, 0.34, 0.28))
	_rock(Vector2(1780, 1008), 34, Color(0.27, 0.3, 0.25))
	# 地面落花 / 落叶
	for i in 18:
		var pos := Vector2(rng.randf_range(80.0, 1840.0), rng.randf_range(900.0, 1050.0))
		var angle := rng.randf_range(0.0, TAU)
		var tint := Color(0.85, 0.68, 0.38, 0.55) if i % 2 == 0 else Color(0.6, 0.68, 0.4, 0.5)
		_bamboo_leaf(pos, angle, rng.randf_range(5.0, 10.0), tint)

func _grass_tuft(origin: Vector2, height: float, color: Color, rng: RandomNumberGenerator) -> void:
	var blades := 4
	for i in blades:
		var lean := rng.randf_range(-height * 0.3, height * 0.3)
		var tip := origin + Vector2(lean, -height * rng.randf_range(0.65, 1.0))
		draw_line(origin + Vector2(rng.randf_range(-5.0, 5.0), 0), tip, color, rng.randf_range(1.5, 3.0), true)
		draw_line(origin, tip, Color(color.r + 0.08, color.g + 0.1, color.b + 0.04, color.a * 0.5), 1.0, true)

func _rock(origin: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([
		origin + Vector2(-radius, 0),
		origin + Vector2(-radius * 0.72, -radius * 0.55),
		origin + Vector2(-radius * 0.2, -radius * 0.85),
		origin + Vector2(radius * 0.4, -radius * 0.7),
		origin + Vector2(radius, -radius * 0.2),
		origin + Vector2(radius * 0.82, 0),
	])
	draw_colored_polygon(points, color)
	draw_polyline(points, Color(0.1, 0.12, 0.09, 0.5), 2.5, true)
	draw_polyline(PackedVector2Array([
		origin + Vector2(-radius * 0.55, -radius * 0.45),
		origin + Vector2(-radius * 0.15, -radius * 0.66),
		origin + Vector2(radius * 0.2, -radius * 0.55),
	]), Color(0.92, 0.86, 0.62, 0.18), 2.0, true)

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
			var a := clampf((d - 0.62) / 0.72, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a) * 0.4
			image.set_pixel(x, y, Color(0.035, 0.03, 0.045, a))
	_vignette_texture = ImageTexture.create_from_image(image)
	return _vignette_texture

func _ellipse(center: Vector2, rx: float, ry: float, color: Color, count: int = 30) -> void:
	var points := PackedVector2Array()
	for i in count:
		var angle := TAU * float(i) / float(count)
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_colored_polygon(points, color)

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
