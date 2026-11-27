extends RefCounted

# 原创程序化河床贴图：冷绿淤泥 + 磨圆卵石 + 苔斑 + 细砂。
# 只生成一次（默认 768²），无外部素材；焦散光网在 shader 中另行计算。


static func build(size: int = 768) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5EED_CA05

	var broad := FastNoiseLite.new()
	broad.seed = 7341
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.frequency = 0.006
	broad.fractal_octaves = 3

	var fine := FastNoiseLite.new()
	fine.seed = 9127
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.frequency = 0.028
	fine.fractal_octaves = 2

	# 淤泥底色：暗青绿为主，低频噪声让水底有深浅层次。
	var deep := Color(0.045, 0.105, 0.100)
	var mid := Color(0.105, 0.195, 0.174)
	var silt := Color(0.170, 0.225, 0.172)
	for y in size:
		for x in size:
			var n := broad.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var m := fine.get_noise_2d(float(x) + 71.0, float(y) - 33.0) * 0.5 + 0.5
			var col := deep.lerp(mid, smoothstep(0.28, 0.80, n))
			col = col.lerp(silt, smoothstep(0.56, 0.92, n * 0.65 + m * 0.35) * 0.34)
			col = col.darkened(0.10 * m)
			img.set_pixel(x, y, col)

	# 苔斑：大而软的低对比绿色区域。
	for i in 34:
		var center := Vector2(rng.randf_range(0.0, float(size)), rng.randf_range(0.0, float(size)))
		var radius := rng.randf_range(18.0, 74.0)
		var tint := Color(0.15, 0.27, 0.16, 1.0).lerp(Color(0.20, 0.32, 0.18), rng.randf())
		var strength := rng.randf_range(0.12, 0.34)
		_soft_disc(img, center, radius, tint, strength, 0.65)

	# 卵石：先阴影后石体，烘焙左上不冷光；大小/旋转/颜色都是原创随机分布。
	for i in 118:
		var center := Vector2(rng.randf_range(0.0, float(size)), rng.randf_range(0.0, float(size)))
		var rx := rng.randf_range(4.5, 21.0)
		var ry := rx * rng.randf_range(0.55, 0.92)
		var angle := rng.randf_range(-PI, PI)
		var tone := rng.randf()
		var stone := Color(0.20, 0.30, 0.27).lerp(Color(0.34, 0.39, 0.32), tone)
		if rng.randf() < 0.22:
			stone = stone.lerp(Color(0.38, 0.35, 0.26), 0.42)
		if rng.randf() < 0.18:
			stone = stone.lerp(Color(0.16, 0.27, 0.20), 0.45)
		_draw_pebble(img, center + Vector2(2.2, 3.0), rx * 1.22, ry * 1.22, angle,
				Color(0.012, 0.030, 0.027), 0.44, false)
		_draw_pebble(img, center, rx, ry, angle, stone, 1.0, true)

	# 细砂与碎屑：少量亮点，避免近看完全平坦。
	for i in 2200:
		var x := rng.randi_range(0, size - 1)
		var y := rng.randi_range(0, size - 1)
		var c := img.get_pixel(x, y)
		if rng.randf() < 0.5:
			c = c.lightened(rng.randf_range(0.03, 0.12))
		else:
			c = c.darkened(rng.randf_range(0.03, 0.10))
		img.set_pixel(x, y, c)

	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _soft_disc(img: Image, center: Vector2, radius: float, tint: Color,
		strength: float, falloff: float) -> void:
	var size := img.get_width()
	var r0 := int(maxf(0.0, center.x - radius))
	var r1 := int(minf(float(size - 1), center.x + radius))
	var c0 := int(maxf(0.0, center.y - radius))
	var c1 := int(minf(float(size - 1), center.y + radius))
	for y in range(c0, c1 + 1):
		for x in range(r0, r1 + 1):
			var d := Vector2(float(x), float(y)).distance_to(center) / radius
			if d >= 1.0:
				continue
			var a := pow(1.0 - d, falloff) * strength
			var old := img.get_pixel(x, y)
			img.set_pixel(x, y, old.lerp(tint, a))


static func _draw_pebble(img: Image, center: Vector2, rx: float, ry: float,
		angle: float, base: Color, alpha: float, lit: bool) -> void:
	var size := img.get_width()
	var ca := cos(angle)
	var sa := sin(angle)
	var reach := int(maxf(rx, ry)) + 2
	var x0 := int(maxf(0.0, center.x - reach))
	var x1 := int(minf(float(size - 1), center.x + reach))
	var y0 := int(maxf(0.0, center.y - reach))
	var y1 := int(minf(float(size - 1), center.y + reach))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := float(x) - center.x
			var dy := float(y) - center.y
			var lx := (dx * ca + dy * sa) / rx
			var ly := (-dx * sa + dy * ca) / ry
			# 轻微的轮廓扰动，避免所有卵石都是标准椭圆。
			var wobble := 1.0 + 0.045 * sin(atan2(ly, lx) * 5.0 + rx)
			var q := (lx * lx + ly * ly) / (wobble * wobble)
			if q > 1.0:
				continue
			var edge := smoothstep(0.52, 1.0, q)
			var shade := 1.0
			var col := base
			if lit:
				# 左上方受光，右下压暗；再压一圈湿边。
				var to_light := clampf(-(lx * 0.55 + ly * 0.78), -1.0, 1.0)
				shade = 0.74 + 0.34 * (to_light * 0.5 + 0.5)
				col = col * shade
				col = col.darkened(0.24 * edge)
				var rim := smoothstep(0.74, 0.96, q) * (1.0 - smoothstep(0.96, 1.0, q))
				col = col.lightened(0.10 * rim)
				var glint := Vector2(lx + 0.34, ly + 0.48).length()
				if glint < 0.19:
					col = col.lightened(0.20 * (1.0 - glint / 0.19))
			else:
				col = base
			var old := img.get_pixel(x, y)
			img.set_pixel(x, y, old.lerp(col, alpha * (1.0 - edge * 0.15)))
