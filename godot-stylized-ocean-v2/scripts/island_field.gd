class_name IslandField
extends RefCounted

# 海岛高度场：同一函数驱动地形网格与水深贴图，保证岸线与泡沫严格对齐。
# 全程程序化、确定性种子，无外部资产。

const AREA := 180.0          # 水深/岸距贴图覆盖 -90..90 m
const TEX_SIZE := 512        # 水深贴图（平滑色阶用）
const SHORE_TEX_SIZE := 1024 # 岸距场贴图（泡沫/湿沙边界用，0.176 m/px）
const SHORE_RANGE := 8.0     # 岸距编码范围 ±8 m
const WATERLINE_SEGMENTS := 2048
const MAX_DEPTH := 12.0
const COAST_BASE := 26.5

var seed_value := 20261126
var dune_noise: FastNoiseLite
var reef_noise: FastNoiseLite
var detail_noise: FastNoiseLite

# 每块礁石：pos(Vector2 世界 xz), size, water(bool), bump(高出水面米数), radius
var rock_sites: Array[Dictionary] = []

# 岸距场：R = 有符号岸距（0.5 = 水线，内陆为正，±8 m 线性），
# G = 岸线道具接触/泡沫环掩码，B = 沿岸泡沫宽度系数，A = 沿岸拍岸相位。
var shore_texture: ImageTexture
var _waterline_r := PackedFloat32Array()
var _waterline_slope := PackedFloat32Array()
var _shore_width_tab := PackedByteArray()
var _shore_phase_tab := PackedByteArray()
var _prop_mask_noise: FastNoiseLite


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

	_prop_mask_noise = FastNoiseLite.new()
	_prop_mask_noise.seed = p_seed + 515
	_prop_mask_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_prop_mask_noise.frequency = 0.30
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
				bump = rng.randf_range(0.22, 0.48)
			rock_sites.append({
				"pos": pos,
				"size": size,
				"water": in_water or base < 0.0,
				"bump": bump,
				"radius": size * 1.05 + 0.35,
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
			"bump": 0.05,
			"radius": size * 0.8 + 0.1,
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


# ───────────────────── 岸距场（SDF，供水面泡沫/湿沙/接触带共用） ─────────────────────
# 海岛近似星形，用极坐标水线半径表 + 法向修正得到有符号岸距，精度高于逐像素距离变换，
# 且能把沙丘/细节噪声造成的水线弯曲完整带进来；1024² 烘焙约 1.2 s（GDScript）。

func _ensure_waterline_table() -> void:
	if _waterline_r.size() == WATERLINE_SEGMENTS:
		return
	var n := WATERLINE_SEGMENTS
	_waterline_r.resize(n)
	_waterline_slope.resize(n)
	for i in n:
		var th := TAU * float(i) / float(n)
		var cr := coast_radius(th)
		var lo := cr * 0.55
		var hi := cr * 1.38
		for k in 26:
			var mid := (lo + hi) * 0.5
			if base_height(cos(th) * mid, sin(th) * mid) > 0.0:
				lo = mid
			else:
				hi = mid
		_waterline_r[i] = (lo + hi) * 0.5
	var dth := TAU / float(n)
	for i in n:
		var rp := _waterline_r[(i - 1 + n) % n]
		var rn := _waterline_r[(i + 1) % n]
		_waterline_slope[i] = (rn - rp) / (2.0 * dth)
	_shore_width_tab.resize(n)
	_shore_phase_tab.resize(n)
	var width_noise := FastNoiseLite.new()
	width_noise.seed = seed_value + 303
	width_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var phase_noise := FastNoiseLite.new()
	phase_noise.seed = seed_value + 909
	phase_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	for i in n:
		var th := TAU * float(i) / float(n)
		# 在圆上采样 2D 噪声，天然首尾相接
		var wn := width_noise.get_noise_2d(cos(th) * 1.9, sin(th) * 1.9)
		var pn := phase_noise.get_noise_2d(cos(th) * 3.3, sin(th) * 3.3)
		_shore_width_tab[i] = int(clampf(0.5 + 0.5 * wn * 1.35, 0.0, 1.0) * 255.0)
		_shore_phase_tab[i] = int(clampf(0.5 + 0.5 * pn * 1.25, 0.0, 1.0) * 255.0)


func waterline_radius(theta: float) -> float:
	_ensure_waterline_table()
	var u: float = theta * (float(WATERLINE_SEGMENTS) / TAU)
	if u < 0.0:
		u += float(WATERLINE_SEGMENTS)
	var i0 := int(u) % WATERLINE_SEGMENTS
	var i1 := (i0 + 1) % WATERLINE_SEGMENTS
	return lerpf(_waterline_r[i0], _waterline_r[i1], u - floor(u))


# 有符号岸距（米）：内陆 > 0，水中 < 0；按极坐标曲线法向修正。
func shore_distance_at(x: float, z: float) -> float:
	_ensure_waterline_table()
	var rr := sqrt(x * x + z * z)
	var th := atan2(z, x)
	var u: float = th * (float(WATERLINE_SEGMENTS) / TAU)
	if u < 0.0:
		u += float(WATERLINE_SEGMENTS)
	var i0 := int(u) % WATERLINE_SEGMENTS
	var i1 := (i0 + 1) % WATERLINE_SEGMENTS
	var f: float = u - floor(u)
	var r0 := lerpf(_waterline_r[i0], _waterline_r[i1], f)
	var slope := lerpf(_waterline_slope[i0], _waterline_slope[i1], f)
	var q := slope / maxf(r0, 1.0)
	return (r0 - rr) / sqrt(1.0 + q * q)


# 烘焙岸距场纹理。extra_sites: [{pos: Vector2, radius: float, weight: float}]，
# 用于棕榈/木屋等岸线道具的接触湿痕与局部泡沫（礁石自动加入）。
func bake_shore_texture(extra_sites: Array[Dictionary] = []) -> ImageTexture:
	_ensure_waterline_table()
	var n := SHORE_TEX_SIZE
	var half := AREA * 0.5
	var step := AREA / float(n)
	var data := PackedByteArray()
	data.resize(n * n * 4)
	var nseg := WATERLINE_SEGMENTS
	for py in n:
		var wz := -half + (float(py) + 0.5) * step
		var row := py * n
		for px in n:
			var wx := -half + (float(px) + 0.5) * step
			var rr := sqrt(wx * wx + wz * wz)
			var th := atan2(wz, wx)
			var u: float = th * (float(nseg) / TAU)
			if u < 0.0:
				u += float(nseg)
			var i0 := int(u) % nseg
			var i1 := (i0 + 1) % nseg
			var f: float = u - floor(u)
			var r0 := lerpf(_waterline_r[i0], _waterline_r[i1], f)
			var slope := lerpf(_waterline_slope[i0], _waterline_slope[i1], f)
			var q := slope / maxf(r0, 1.0)
			var sd := (r0 - rr) / sqrt(1.0 + q * q)
			var o := (row + px) * 4
			data[o] = int(clampf(0.5 + sd / (SHORE_RANGE * 2.0), 0.0, 1.0) * 255.0)
			data[o + 1] = 0
			data[o + 2] = _shore_width_tab[i0]
			data[o + 3] = _shore_phase_tab[i0]
	# 道具接触掩码（G）：礁石（水中/岸线）+ 岸线附近棕榈，软圆盘，供泡沫环与湿痕使用
	var sites: Array[Dictionary] = []
	for site in rock_sites:
		var p: Vector2 = site["pos"]
		var sz: float = site["size"]
		sites.append({"pos": p, "core": sz * 0.82 + 0.08, "width": sz * 0.25 + 0.15, "weight": 1.0})
	for site in extra_sites:
		sites.append(site)
	for site in sites:
		var pos: Vector2 = site["pos"]
		var core: float = site["core"]
		var wid: float = site["width"]
		var weight: float = site["weight"]
		var rad: float = core + wid * 1.8
		var px0 := clampi(int(floor((pos.x - rad + half) / step)), 0, n - 1)
		var px1 := clampi(int(ceil((pos.x + rad + half) / step)), 0, n - 1)
		var py0 := clampi(int(floor((pos.y - rad + half) / step)), 0, n - 1)
		var py1 := clampi(int(ceil((pos.y + rad + half) / step)), 0, n - 1)
		for py in range(py0, py1 + 1):
			var wz2 := -half + (float(py) + 0.5) * step
			for px in range(px0, px1 + 1):
				var wx2 := -half + (float(px) + 0.5) * step
				var dd := sqrt((wx2 - pos.x) * (wx2 - pos.x) + (wz2 - pos.y) * (wz2 - pos.y))
				if dd >= rad:
					continue
				var kk := (dd - core) / maxf(wid, 0.05)
				var patch := 0.55 + 0.45 * clampf(_prop_mask_noise.get_noise_2d(wx2, wz2) * 0.9 + 0.5, 0.0, 1.0)
				var val_f := exp(-kk * kk) * weight * patch
				var val := int(clampf(val_f, 0.0, 1.0) * 255.0)
				var o := (py * n + px) * 4
				if val > data[o + 1]:
					data[o + 1] = val
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, data)
	var tex := ImageTexture.create_from_image(img)
	shore_texture = tex
	return tex


func height_at(x: float, z: float) -> float:
	return height(x, z)


func water_depth_at(x: float, z: float) -> float:
	return maxf(0.0, -height(x, z))
