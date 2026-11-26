class_name IslandField
extends RefCounted

# 海岛高度场：同一函数驱动地形网格与水深贴图，保证岸线与泡沫严格对齐。
# 全程程序化、确定性种子，无外部资产。

const AREA := 180.0          # 水深贴图覆盖 -90..90 m
const TEX_SIZE := 512
const MAX_DEPTH := 12.0
const COAST_BASE := 26.5

var seed_value := 20261126
var dune_noise: FastNoiseLite
var reef_noise: FastNoiseLite
var detail_noise: FastNoiseLite

# 每块礁石：pos(Vector2 世界 xz), size, water(bool), bump(高出水面米数), radius
var rock_sites: Array[Dictionary] = []


func _init(p_seed := 20261126) -> void:
	seed_value = p_seed
	dune_noise = FastNoiseLite.new()
	dune_noise.seed = p_seed
	dune_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	dune_noise.frequency = 0.055
	dune_noise.fractal_octaves = 3

	reef_noise = FastNoiseLite.new()
	reef_noise.seed = p_seed + 31
	reef_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	reef_noise.frequency = 0.038
	reef_noise.fractal_octaves = 3

	detail_noise = FastNoiseLite.new()
	detail_noise.seed = p_seed + 77
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	detail_noise.frequency = 0.55

	_build_rock_sites()


static func wrap_pi(a: float) -> float:
	return atan2(sin(a), cos(a))


func coast_radius(theta: float) -> float:
	var c := COAST_BASE
	c += 2.5 * sin(3.0 * theta + 0.8)
	c += 1.9 * sin(5.0 * theta + 2.2)
	c += 1.2 * sin(8.0 * theta + 4.9)
	c += 0.8 * sin(11.0 * theta + 1.3)
	# 西侧海湾（参考帧左侧的大弧形沙滩）
	c -= 4.4 * exp(-pow(wrap_pi(theta - 2.85) / 0.46, 2.0))
	# 东南侧沙嘴
	c += 2.8 * exp(-pow(wrap_pi(theta + 0.62) / 0.36, 2.0))
	return c


func base_height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var theta := atan2(z, x)
	var cr := coast_radius(theta)
	var d := r / cr
	if d < 1.0:
		var h := 2.05 * smoothstep(0.93, 0.44, d) + 0.55 * smoothstep(0.87, 0.60, d)
		var dn := dune_noise.get_noise_2d(x, z) * 0.8
		dn += dune_noise.get_noise_2d(x * 2.7 + 11.0, z * 2.7 - 7.0) * 0.28
		h += dn * smoothstep(0.91, 0.56, d)
		h += detail_noise.get_noise_2d(x, z) * 0.045
		return max(h, 0.03)
	# 海床：浅礁盘 → 陆架 → 深海
	var s := r - cr
	var depth := 0.42 * smoothstep(0.0, 2.0, s)
	depth += 1.5 * smoothstep(1.0, 7.0, s)
	depth += 3.5 * smoothstep(5.0, 15.0, s)
	depth += 8.2 * smoothstep(14.0, 33.0, s)
	depth += 10.0 * smoothstep(36.0, 64.0, s)
	var shelf := reef_noise.get_noise_2d(x * 1.15, z * 1.15)
	depth += shelf * 0.7 * smoothstep(1.0, 6.0, s) * smoothstep(52.0, 14.0, s)
	# 礁盘沙脊：让泡沫出现参考帧里的离岸弧线
	var ridges := sin(s * 0.62 + reef_noise.get_noise_2d(x * 0.3, z * 0.3) * 3.4)
	depth -= max(0.0, ridges) * 0.42 * smoothstep(30.0, 6.0, s) * smoothstep(1.0, 3.0, s)
	depth = max(depth, 0.0)
	return -depth


func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	for site in rock_sites:
		var bump: float = site.bump
		if bump <= 0.0:
			continue
		var pos: Vector2 = site.pos
		var dx := x - pos.x
		var dz := z - pos.y
		var dd := sqrt(dx * dx + dz * dz)
		var rad: float = site.radius
		if dd < rad:
			var k := 1.0 - dd / rad
			h = max(h, -0.35 + (bump + 0.35) * smoothstep(0.0, 1.0, k))
	return h


func _build_rock_sites() -> void:
	rock_sites.clear()
	# 岸上/水线巨石群：角度(度), 数量, 半径范围, 尺寸范围, 是否允许泡水
	var clusters := [
		[118.0, 5, 21.0, 28.5, 1.15, 2.7],
		[28.0, 4, 22.0, 29.0, 1.25, 2.9],
		[-52.0, 4, 21.5, 28.0, 0.95, 2.4],
		[171.0, 3, 25.0, 30.5, 0.9, 1.9],
		[-128.0, 3, 23.0, 29.0, 0.85, 1.8],
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	for cluster in clusters:
		var theta0 := deg_to_rad(float(cluster[0]))
		var count: int = cluster[1]
		for i in count:
			var theta := theta0 + rng.randf_range(-0.22, 0.22)
			var rr := rng.randf_range(float(cluster[2]), float(cluster[3]))
			var size := rng.randf_range(float(cluster[4]), float(cluster[5]))
			var pos := Vector2(cos(theta) * rr, sin(theta) * rr)
			var base := base_height(pos.x, pos.y)
			var in_water := base < 0.30
			var bump := 0.0
			if in_water:
				bump = rng.randf_range(0.45, 0.95)
			rock_sites.append({
				"pos": pos,
				"size": size,
				"water": in_water or base < 0.0,
				"bump": bump,
				"radius": size * 1.35 + 0.8,
				"land": not in_water,
			})
	# 浅滩礁石（参考帧里离岸的深色礁岩，带一圈白沫）
	for spec in [[-158.0, 34.0, 2.2], [-96.0, 39.0, 2.8], [8.0, 38.0, 2.3],
			[63.0, 35.0, 1.9], [148.0, 43.0, 2.5], [-28.0, 45.0, 2.0]]:
		var theta := deg_to_rad(float(spec[0]))
		var rr: float = spec[1]
		var size: float = spec[2]
		rock_sites.append({
			"pos": Vector2(cos(theta) * rr, sin(theta) * rr),
			"size": size,
			"water": true,
			"bump": 0.55,
			"radius": size * 1.5 + 1.2,
			"land": false,
		})


# 烘焙水深贴图：R 通道 sqrt(depth/max) 编码，保证浅水 1–2cm 的精度供泡沫使用。
# 先铺基础高度，再把礁石隆起局部盖章，避免每像素遍历全部礁石。
func bake_height_texture() -> ImageTexture:
	var step := AREA / float(TEX_SIZE)
	var half := AREA * 0.5
	var heights := PackedFloat32Array()
	heights.resize(TEX_SIZE * TEX_SIZE)
	for y in TEX_SIZE:
		var z := -half + (float(y) + 0.5) * step
		var row := y * TEX_SIZE
		for x in TEX_SIZE:
			var wx := -half + (float(x) + 0.5) * step
			heights[row + x] = base_height(wx, z)
	for site in rock_sites:
		var bump: float = site.bump
		if bump <= 0.0:
			continue
		var pos: Vector2 = site.pos
		var rad: float = site.radius
		var px0 := int(floor((pos.x - rad + half) / step))
		var px1 := int(ceil((pos.x + rad + half) / step))
		var py0 := int(floor((pos.y - rad + half) / step))
		var py1 := int(ceil((pos.y + rad + half) / step))
		px0 = clampi(px0, 0, TEX_SIZE - 1)
		px1 = clampi(px1, 0, TEX_SIZE - 1)
		py0 = clampi(py0, 0, TEX_SIZE - 1)
		py1 = clampi(py1, 0, TEX_SIZE - 1)
		for py in range(py0, py1 + 1):
			var wz := -half + (float(py) + 0.5) * step
			for px in range(px0, px1 + 1):
				var wx := -half + (float(px) + 0.5) * step
				var dd := sqrt((wx - pos.x) * (wx - pos.x) + (wz - pos.y) * (wz - pos.y))
				if dd >= rad:
					continue
				var k := 1.0 - dd / rad
				var bh := -0.35 + (bump + 0.35) * smoothstep(0.0, 1.0, k)
				var i := py * TEX_SIZE + px
				if bh > heights[i]:
					heights[i] = bh
	var img := Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var data := PackedByteArray()
	data.resize(TEX_SIZE * TEX_SIZE * 4)
	for i in TEX_SIZE * TEX_SIZE:
		var depth := clampf(-heights[i], 0.0, MAX_DEPTH)
		var enc := int(clampf(sqrt(depth / MAX_DEPTH), 0.0, 1.0) * 255.0 + 0.5)
		var o := i * 4
		data[o] = enc
		data[o + 1] = enc
		data[o + 2] = enc
		data[o + 3] = 255
	img.set_data(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	return tex


func height_at(x: float, z: float) -> float:
	return height(x, z)


func water_depth_at(x: float, z: float) -> float:
	return maxf(0.0, -height(x, z))
