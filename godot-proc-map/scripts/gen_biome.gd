extends RefCounted

# 生物群系世界生成器（视觉 Hero，纯数据）。
# 阶段：海拔场 → 气候场 → 生物群系 → 河流 → 植被 → 地标/区域。
# FastNoiseLite 三通道 + 岛屿遮罩 + 最陡下降河流 + Bridson Poisson 植被/地标 + 最近点区域。

const Utils = preload("res://scripts/gen_utils.gd")

const STAGES := ["elevation", "climate", "terrain", "rivers", "vegetation", "sites"]
const STAGE_LABELS := ["海拔场", "气候场", "生物群系", "河流", "植被", "地标与区域"]

const DEEP := 0
const MID := 1
const SHALLOW := 2
const SAND := 3
const GRASS := 4
const FOREST := 5
const ROCK := 6
const SNOW := 7

const BIOME_NAMES := ["深水", "浅滩", "海岸", "沙滩", "草地", "森林", "岩地", "雪原"]
const BIOME_COLORS := [
	Color("#123943"), Color("#1a5560"), Color("#2c7479"), Color("#d5c08a"),
	Color("#6f9752"), Color("#3b6542"), Color("#7d817b"), Color("#e6ece6"),
]

const POI_NAMES := [
	"灰鸥哨塔", "苔原村", "断钟遗迹", "北岬营地", "雾灯灯塔",
	"霜谷驿站", "旧盐仓", "松针村", "潮汐石阵", "白鹿哨站",
]

var width := 96
var height := 64
var seed_text := "9001"
var base_seed := 0
var sea_level := 0.0
var stage_index := -1
var finished := false
var stage_ms: Array[float] = []
var total_ms := 0.0

var streams: Dictionary = {}
var elevation: PackedFloat32Array
var moisture: PackedFloat32Array
var temperature: PackedFloat32Array
var biome: PackedByteArray
var river: PackedByteArray
var region: PackedInt32Array
var decor: Array = []
var pois: Array = []
var regions: Array = []
var signature := ""
var valid := false
var land_pct := 0.0
var largest_land_pct := 0.0
var river_count := 0
var river_cells := 0
var rivers_to_sea := 0
var longest_river := 0
var tree_count := 0
var rock_count := 0
var flower_count := 0
var stage_notes: Array[String] = []

var _elev_noise: FastNoiseLite
var _coast_noise: FastNoiseLite
var _detail_noise: FastNoiseLite
var _moist_noise: FastNoiseLite
var _temp_noise: FastNoiseLite
var _rngs: Dictionary = {}


func setup(seed_value: String, map_w: int, map_h: int, sea_param := 0.0) -> void:
	seed_text = seed_value
	width = map_w
	height = map_h
	sea_level = clampf(sea_param, -0.10, 0.10)
	base_seed = Utils.seed_from_text(seed_text)
	streams = {
		"海拔": Utils.mix32(base_seed, 5101),
		"气候": Utils.mix32(base_seed, 6203),
		"河流": Utils.mix32(base_seed, 7307),
		"植被": Utils.mix32(base_seed, 8409),
		"地标": Utils.mix32(base_seed, 9511),
		"区域": Utils.mix32(base_seed, 10613),
	}
	_rngs = {}
	for key in streams:
		var rng := RandomNumberGenerator.new()
		rng.seed = int(streams[key])
		_rngs[key] = rng
	_elev_noise = _make_noise(int(streams["海拔"]), 0.0125, 3,
			FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	_coast_noise = _make_noise(Utils.mix32(int(streams["海拔"]), 77), 0.018, 2,
			FastNoiseLite.TYPE_SIMPLEX)
	_detail_noise = _make_noise(Utils.mix32(int(streams["海拔"]), 99), 0.075, 1,
			FastNoiseLite.TYPE_SIMPLEX)
	_moist_noise = _make_noise(int(streams["气候"]), 0.022, 2,
			FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	_temp_noise = _make_noise(Utils.mix32(int(streams["气候"]), 55), 0.028, 2,
			FastNoiseLite.TYPE_PERLIN)

	elevation = PackedFloat32Array()
	elevation.resize(width * height)
	elevation.fill(0.0)
	moisture = PackedFloat32Array()
	moisture.resize(width * height)
	moisture.fill(0.0)
	temperature = PackedFloat32Array()
	temperature.resize(width * height)
	temperature.fill(0.0)
	biome = PackedByteArray()
	biome.resize(width * height)
	biome.fill(DEEP)
	river = PackedByteArray()
	river.resize(width * height)
	river.fill(0)
	region = PackedInt32Array()
	region.resize(width * height)
	region.fill(-1)
	decor = []
	pois = []
	regions = []
	signature = ""
	valid = false
	land_pct = 0.0
	largest_land_pct = 0.0
	river_count = 0
	river_cells = 0
	rivers_to_sea = 0
	longest_river = 0
	tree_count = 0
	rock_count = 0
	flower_count = 0
	stage_index = -1
	finished = false
	stage_ms = []
	total_ms = 0.0
	stage_notes = []


func _make_noise(noise_seed: int, frequency: float, octaves: int,
		noise_type: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	return noise


func get_stage_count() -> int:
	return STAGES.size()


func get_stage_label(index: int) -> String:
	return STAGE_LABELS[clampi(index, 0, STAGE_LABELS.size() - 1)]


func run_stage(index: int) -> void:
	if index < 0 or index >= STAGES.size():
		return
	var started := Time.get_ticks_usec()
	match index:
		0:
			_run_elevation()
		1:
			_run_climate()
		2:
			_run_terrain()
		3:
			_run_rivers()
		4:
			_run_vegetation()
		5:
			_run_sites()
	stage_index = index
	finished = index >= STAGES.size() - 1
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
	stage_ms.append(elapsed)
	total_ms += elapsed


func generate_all() -> bool:
	for index in STAGES.size():
		run_stage(index)
	return valid


func get_streams() -> Dictionary:
	return streams


func get_stats() -> Dictionary:
	var forest_cells := 0
	var grass_cells := 0
	var rock_cells := 0
	var snow_cells := 0
	for value in biome:
		match int(value):
			FOREST:
				forest_cells += 1
			GRASS:
				grass_cells += 1
			ROCK:
				rock_cells += 1
			SNOW:
				snow_cells += 1
	var land_cells := 0
	for value in biome:
		if int(value) >= SAND:
			land_cells += 1
	return {
		"land_pct": land_pct,
		"largest_land_pct": largest_land_pct,
		"forest_cells": forest_cells,
		"grass_cells": grass_cells,
		"rock_cells": rock_cells,
		"snow_cells": snow_cells,
		"land_cells": land_cells,
		"rivers": river_count,
		"river_cells": river_cells,
		"rivers_to_sea": rivers_to_sea,
		"longest_river": longest_river,
		"trees": tree_count,
		"rocks": rock_count,
		"flowers": flower_count,
		"pois": pois.size(),
		"regions": regions.size(),
		"total_ms": total_ms,
		"stage_ms": stage_ms.duplicate(),
		"valid": valid,
		"signature": signature,
		"stage_notes": stage_notes.duplicate(),
	}


func get_signature() -> String:
	return signature


func get_field(kind: String) -> PackedFloat32Array:
	match kind:
		"moisture":
			return moisture
		"temperature":
			return temperature
		_:
			return elevation


func land_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return int(biome[cell.y * width + cell.x]) >= SAND


func water_cell(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return true
	return int(biome[cell.y * width + cell.x]) < SAND


func biome_name(value: int) -> String:
	return BIOME_NAMES[clampi(value, 0, BIOME_NAMES.size() - 1)]


func biome_color(value: int) -> Color:
	return BIOME_COLORS[clampi(value, 0, BIOME_COLORS.size() - 1)]


func cell_info(cell: Vector2i) -> Dictionary:
	var info := {"valid": false}
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return info
	var index := cell.y * width + cell.x
	var b := int(biome[index])
	info["valid"] = true
	info["biome"] = b
	info["biome_name"] = BIOME_NAMES[b]
	info["elevation"] = elevation[index]
	info["moisture"] = moisture[index]
	info["temperature"] = temperature[index]
	info["river"] = int(river[index]) != 0
	info["land"] = b >= SAND
	info["region"] = region[index]
	for poi in pois:
		var poi_cell: Vector2i = poi["cell"]
		if poi_cell == cell:
			info["poi_name"] = poi["name"]
			break
	return info


# ---------------------------------------------------------------------------
# 阶段 0：海拔 / 岛屿遮罩
# ---------------------------------------------------------------------------

func _run_elevation() -> void:
	for y in height:
		for x in width:
			var index := y * width + x
			var nx := (float(x) + 0.5) / float(width) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(height) * 2.0 - 1.0
			var d := sqrt(nx * nx + ny * ny * 1.12)
			var coast := _coast_noise.get_noise_2d(float(x), float(y))
			var detail := _detail_noise.get_noise_2d(float(x), float(y))
			d = maxf(0.0, d + coast * 0.245 + detail * 0.06)
			var island := smoothstep(1.06, 0.28, d)
			var base := _elev_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var e := island * (0.8 + base * 0.36 + detail * 0.05) - 0.265
			elevation[index] = e
	stage_notes.append("岛屿遮罩 = 椭圆径向 * 海岸噪声扰动；高度 FBM 4 octaves")


# ---------------------------------------------------------------------------
# 阶段 1：湿度 / 温度
# ---------------------------------------------------------------------------

func _run_climate() -> void:
	for y in height:
		for x in width:
			var index := y * width + x
			var m := _moist_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var t := _temp_noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var latitude := 0.5 - float(y) / float(height)
			m = clampf(m * 0.82 + 0.09 + latitude * 0.06, 0.0, 1.0)
			t = clampf(t * 0.72 + 0.16 + latitude * 0.20, 0.0, 1.0)
			moisture[index] = m
			temperature[index] = t
	stage_notes.append("湿度 Simplex/FBM；温度 Perlin + 纬度梯度")


# ---------------------------------------------------------------------------
# 阶段 2：分类 + 小岛清理 + 海滩
# ---------------------------------------------------------------------------

func _run_terrain() -> void:
	var sea := sea_level
	for y in height:
		for x in width:
			var index := y * width + x
			var e := elevation[index]
			var m := moisture[index]
			var t := temperature[index]
			var e_check := e
			if e <= sea:
				if e < sea - 0.22:
					biome[index] = DEEP
				elif e < sea - 0.075:
					biome[index] = MID
				else:
					biome[index] = SHALLOW
				continue
			if e_check < sea + 0.055:
				biome[index] = SAND
				continue
			var snow_line := 0.69 + (0.5 - t) * 0.05 + (Utils.hash01(x, y, 777) - 0.5) * 0.05
			if e_check > snow_line:
				biome[index] = SNOW
			elif e_check > 0.55 or m < 0.24:
				biome[index] = ROCK
			elif m > 0.535 and e_check < 0.46:
				biome[index] = FOREST
			else:
				biome[index] = GRASS
	# 海滩：临水草地/森林至少一圈沙（4 邻，直接索引）。
	var original := biome.duplicate()
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var index := y * width + x
			var b := int(original[index])
			if b != GRASS and b != FOREST:
				continue
			if elevation[index] >= sea + 0.20:
				continue
			if int(original[index - 1]) < SAND or int(original[index + 1]) < SAND \
					or int(original[index - width]) < SAND or int(original[index + width]) < SAND:
				biome[index] = SAND
	_cleanup_and_stats()
	stage_notes.append("海拔 → 水/沙/草/林/岩/雪；临水海滩；最大陆块阈值清理")


func _cleanup_and_stats() -> void:
	var land := PackedByteArray()
	land.resize(width * height)
	var total := 0
	for i in width * height:
		if int(biome[i]) >= SAND:
			land[i] = 1
			total += 1
	if total == 0:
		land_pct = 0.0
		largest_land_pct = 0.0
		return
	var comps := Utils.bfs_components(width, height, land)
	var comp: PackedInt32Array = comps["comp"]
	var largest := int(comps["largest_size"])
	var largest_id := int(comps["largest_id"])
	var small_total := total - largest
	if float(small_total) > float(total) * 0.095:
		for i in width * height:
			if int(land[i]) != 0 and comp[i] != largest_id:
				var e := elevation[i]
				biome[i] = MID if e < sea_level - 0.08 else SHALLOW
		total = largest
		small_total = 0
	land_pct = float(total) / float(width * height)
	largest_land_pct = float(largest) / float(maxi(1, total)) * 100.0


# ---------------------------------------------------------------------------
# 阶段 3：河流
# ---------------------------------------------------------------------------

func _run_rivers() -> void:
	river.fill(0)
	# 只取局部高点作为河源，避免对上千个格子排序。
	var candidates: Array[Vector2i] = []
	for y in range(2, height - 2):
		for x in range(2, width - 2):
			var index := y * width + x
			if int(biome[index]) <= SAND:
				continue
			var e := elevation[index]
			if e < 0.26:
				continue
			if elevation[index - 1] > e + 0.0005 or elevation[index + 1] > e + 0.0005 \
					or elevation[index - width] > e + 0.0005 or elevation[index + width] > e + 0.0005 \
					or elevation[index - width - 1] > e + 0.0005 or elevation[index - width + 1] > e + 0.0005 \
					or elevation[index + width - 1] > e + 0.0005 or elevation[index + width + 1] > e + 0.0005:
				continue
			candidates.append(Vector2i(x, y))
	var sources: Array[Vector2i] = []
	for pick in 7:
		var best := Vector2i(-1, -1)
		var best_e := -999.0
		for cell in candidates:
			var index := cell.y * width + cell.x
			if elevation[index] <= best_e:
				continue
			var spaced := true
			for other in sources:
				if cell.distance_squared_to(other) < 9 * 9:
					spaced = false
					break
			if spaced:
				best = cell
				best_e = elevation[index]
		if best.x < 0:
			break
		sources.append(best)
	# 极端种子保底：至少给一个可用的高地河源。
	if sources.is_empty():
		var fallback_cell := Vector2i(-1, -1)
		var fallback_e := -999.0
		for i in width * height:
			if int(biome[i]) >= SAND and elevation[i] > fallback_e:
				fallback_e = elevation[i]
				fallback_cell = Vector2i(i % width, i / width)
		if fallback_cell.x >= 0:
			sources.append(fallback_cell)
	for source in sources:
		if river_count >= 5:
			break
		var result := _trace_river(source)
		var path: Array = result["path"]
		if path.is_empty():
			continue
		if not bool(result["reached_sea"]) and not bool(result["merged"]):
			# 死路：丢弃这条半成品，不在地图上留下断头河。
			continue
		_commit_river(path, bool(result["reached_sea"]))
	# 保底：至少一条河真正入海（用全图水体距离场引导）。
	if rivers_to_sea == 0 and not sources.is_empty():
		var water_dist := _water_distance_field()
		var result := _trace_river_fallback(sources[0], water_dist)
		var path: Array = result["path"]
		if not path.is_empty() and bool(result["reached_sea"]):
			_commit_river(path, true)
	stage_notes.append("河流 = 最陡下降 + 8 邻接桥接；不足时用地形距离场保底入海")


func _commit_river(path: Array, reached_sea: bool) -> void:
	for cell in path:
		river[cell.y * width + cell.x] = 1
	river_count += 1
	river_cells += path.size()
	longest_river = maxi(longest_river, path.size())
	if reached_sea:
		rivers_to_sea += 1
		_widen_mouth(path)


func _trace_river(source: Vector2i) -> Dictionary:
	var path: Array[Vector2i] = []
	var visited: Dictionary = {}
	var current := source
	var reached := false
	var merged := false
	for step in 140:
		if water_cell(current):
			reached = true
			break
		if int(river[current.y * width + current.x]) != 0:
			merged = true
			break
		path.append(current)
		visited[current] = true
		var best := Vector2i(-1, -1)
		var best_e := elevation[current.y * width + current.x]
		for offset in _neighbors8():
			var n := current + offset
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if visited.has(n):
				continue
			var ne := elevation[n.y * width + n.x]
			if ne < best_e - 0.0001:
				best_e = ne
				best = n
		if best.x < 0:
			break
		# 对角步补一格，保证 4 邻接连续。
		if best.x != current.x and best.y != current.y:
			var bridge_a := Vector2i(best.x, current.y)
			var bridge_b := Vector2i(current.x, best.y)
			var bridge := bridge_a
			if elevation[bridge_b.y * width + bridge_b.x] < elevation[bridge_a.y * width + bridge_a.x]:
				bridge = bridge_b
			if not water_cell(bridge) and not visited.has(bridge):
				path.append(bridge)
				visited[bridge] = true
		current = best
	return {"path": path, "reached_sea": reached, "merged": merged}


func _trace_river_fallback(source: Vector2i, water_dist: PackedInt32Array) -> Dictionary:
	var path: Array[Vector2i] = []
	var visited: Dictionary = {}
	var current := source
	var reached := false
	for step in 160:
		if water_cell(current):
			reached = true
			break
		path.append(current)
		visited[current] = true
		var best := Vector2i(-1, -1)
		var best_d := water_dist[current.y * width + current.x]
		for offset in _neighbors8():
			var n := current + offset
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if visited.has(n):
				continue
			var nd := water_dist[n.y * width + n.x]
			if nd >= 0 and (best.x < 0 or nd < best_d):
				best_d = nd
				best = n
		if best.x < 0:
			break
		current = best
	return {"path": path, "reached_sea": reached, "merged": false}


func _widen_mouth(path: Array) -> void:
	var start := maxi(0, path.size() - 4)
	for i in range(start, path.size()):
		var cell: Vector2i = path[i]
		var prev: Vector2i = path[maxi(0, i - 1)]
		var dir := cell - prev
		if dir == Vector2i.ZERO:
			continue
		var perpendicular := Vector2i(-dir.y, dir.x)
		for side in [perpendicular, -perpendicular]:
			var n: Vector2i = cell + side
			if n.x < 1 or n.y < 1 or n.x >= width - 1 or n.y >= height - 1:
				continue
			if int(biome[n.y * width + n.x]) < SAND:
				continue
			if river[n.y * width + n.x] == 0:
				river[n.y * width + n.x] = 1
				river_cells += 1


func _water_distance_field() -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(width * height)
	var head := 0
	var tail := 0
	for i in width * height:
		if int(biome[i]) < SAND:
			dist[i] = 0
			queue[tail] = i
			tail += 1
	while head < tail:
		var index := queue[head]
		head += 1
		var x := index % width
		var y := index / width
		var d := dist[index]
		for offset in _neighbors8():
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni := ny * width + nx
			if dist[ni] >= 0:
				continue
			dist[ni] = d + 1
			queue[tail] = ni
			tail += 1
	return dist


func _neighbors8() -> Array[Vector2i]:
	return [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


# ---------------------------------------------------------------------------
# 阶段 4：植被（Bridson Poisson）
# ---------------------------------------------------------------------------

func _run_vegetation() -> void:
	decor = []
	tree_count = 0
	rock_count = 0
	flower_count = 0
	var rng: RandomNumberGenerator = _rngs["植被"]
	var forest_points := _poisson(1.62, 10, "forest", 480, 20)
	for point in forest_points:
		var cell := _sample_cell(point)
		var cold := temperature[cell.y * width + cell.x] < 0.42 or elevation[cell.y * width + cell.x] > 0.30
		var kind := "pine" if cold else "oak"
		var variants := 4 if kind == "pine" else 6
		decor.append({"kind": kind, "pos": _world_pos(point, rng, 0.32),
			"scale": lerpf(1.02, 1.38, rng.randf()),
			"variant": rng.randi_range(0, variants - 1)})
		tree_count += 1
	var grass_points := _poisson(3.2, 8, "grass", 130, 10)
	for point in grass_points:
		var roll := rng.randf()
		if roll < 0.58:
			decor.append({"kind": "oak", "pos": _world_pos(point, rng, 0.4),
				"scale": lerpf(0.88, 1.15, rng.randf()),
				"variant": rng.randi_range(0, 5)})
			tree_count += 1
		else:
			decor.append({"kind": "bush", "pos": _world_pos(point, rng, 0.35),
				"scale": lerpf(0.8, 1.1, rng.randf()), "variant": 0})
	var high_points := _poisson(3.9, 8, "high", 80, 8)
	for point in high_points:
		var cell := _sample_cell(point)
		var b := int(biome[cell.y * width + cell.x])
		if b == SNOW and rng.randf() < 0.55:
			decor.append({"kind": "snow_pine", "pos": _world_pos(point, rng, 0.3),
				"scale": lerpf(0.9, 1.2, rng.randf()),
				"variant": rng.randi_range(0, 1)})
			tree_count += 1
		else:
			decor.append({"kind": "boulder", "pos": _world_pos(point, rng, 0.3),
				"scale": lerpf(0.75, 1.15, rng.randf()), "variant": 0})
			rock_count += 1
	var flower_points := _poisson(2.2, 6, "flower", 100, 8)
	for point in flower_points:
		var roll := rng.randf()
		if roll < 0.64:
			decor.append({"kind": "flowers", "pos": _world_pos(point, rng, 0.25),
				"scale": lerpf(0.75, 1.0, rng.randf()), "variant": 0})
			flower_count += 1
		else:
			decor.append({"kind": "tuft", "pos": _world_pos(point, rng, 0.25),
				"scale": lerpf(0.7, 1.0, rng.randf()), "variant": 0})
	stage_notes.append("植被 = 按群系分层的 Bridson Poisson；森林密、草地疏、岩雪点状")


func _sample_cell(point: Vector2) -> Vector2i:
	var x := int(floor(point.x))
	var y := int(floor(point.y))
	if x < 0 or y < 0 or x >= width or y >= height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func _world_pos(point: Vector2, rng: RandomNumberGenerator, jitter: float) -> Vector2:
	var p := point + Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
	return p * 32.0


func _poisson(min_dist: float, k: int, kind: String, limit: int, max_seeds := 10) -> Array[Vector2]:
	var cell_size := min_dist / sqrt(2.0)
	var grid_w := int(ceil(float(width) / cell_size)) + 1
	var grid_h := int(ceil(float(height) / cell_size)) + 1
	var buckets: Dictionary = {}
	var points: Array[Vector2] = []
	var active: Array[Vector2] = []
	var rng: RandomNumberGenerator = _rngs["植被"]
	var found_start := false
	for attempt in 400:
		var p := Vector2(rng.randf() * width, rng.randf() * height)
		if _accept_point(p, kind):
			_add_point(p, points, active, buckets, cell_size)
			found_start = true
			break
	if not found_start:
		return points
	var extra_seeds := 0
	while points.size() < limit:
		if active.is_empty():
			# 群系是碎片化的：重新播一个起点，覆盖其它森林/草地斑块。
			if extra_seeds >= max_seeds:
				break
			var seeded := false
			for attempt in 160:
				var p := Vector2(rng.randf() * width, rng.randf() * height)
				if not _accept_point(p, kind):
					continue
				if _too_close(p, points, buckets, cell_size, grid_w, grid_h, min_dist):
					continue
				_add_point(p, points, active, buckets, cell_size)
				extra_seeds += 1
				seeded = true
				break
			if not seeded:
				break
			continue
		var idx := rng.randi_range(0, active.size() - 1)
		var base := active[idx]
		var placed := false
		for attempt in k:
			var angle := rng.randf() * TAU
			var radius := min_dist * (1.0 + rng.randf())
			var candidate := base + Vector2(cos(angle), sin(angle)) * radius
			if candidate.x < 0.0 or candidate.y < 0.0 or candidate.x >= float(width) or candidate.y >= float(height):
				continue
			if not _accept_point(candidate, kind):
				continue
			if _too_close(candidate, points, buckets, cell_size, grid_w, grid_h, min_dist):
				continue
			_add_point(candidate, points, active, buckets, cell_size)
			placed = true
			break
		if not placed:
			active.remove_at(idx)
	return points


func _accept_point(point: Vector2, kind: String) -> bool:
	var cell := _sample_cell(point)
	if cell.x < 0:
		return false
	var index := cell.y * width + cell.x
	var b := int(biome[index])
	if river[index] != 0:
		return false
	match kind:
		"forest":
			return b == FOREST
		"grass":
			return b == GRASS
		"high":
			return b == ROCK or b == SNOW
		"flower":
			return b == GRASS
		"region":
			return b >= SAND
		"poi":
			if b < SAND:
				return false
			if (b == ROCK or b == SNOW) and elevation[index] > 0.52:
				return false
			return true
		"poi_relaxed":
			return b >= SAND
		_:
			return false


func _add_point(p: Vector2, points: Array[Vector2], active: Array[Vector2],
		buckets: Dictionary, cell_size: float) -> void:
	points.append(p)
	active.append(p)
	var key := Vector2i(int(p.x / cell_size), int(p.y / cell_size))
	if not buckets.has(key):
		buckets[key] = []
	buckets[key].append(p)


func _too_close(p: Vector2, points: Array[Vector2], buckets: Dictionary,
		cell_size: float, grid_w: int, grid_h: int, min_dist: float) -> bool:
	var gx := int(p.x / cell_size)
	var gy := int(p.y / cell_size)
	var min_sq := min_dist * min_dist
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var nx := gx + dx
			var ny := gy + dy
			if nx < 0 or ny < 0 or nx >= grid_w or ny >= grid_h:
				continue
			var key := Vector2i(nx, ny)
			if not buckets.has(key):
				continue
			for other in buckets[key]:
				if p.distance_squared_to(other) < min_sq:
					return true
	return false


# ---------------------------------------------------------------------------
# 阶段 5：地标 / 区域 / 签名
# ---------------------------------------------------------------------------

func _run_sites() -> void:
	pois = []
	var rng: RandomNumberGenerator = _rngs["地标"]
	var names := POI_NAMES.duplicate()
	_shuffle(names, rng)
	var points := _poisson(12.5, 18, "poi", 6, 2)
	if points.size() < 3:
		points = _poisson(8.0, 18, "poi_relaxed", 6, 2)
	var name_index := 0
	for point in points:
		var cell := _sample_cell(point)
		if cell.x < 0:
			continue
		var poi := _make_poi(cell, rng, names, name_index)
		pois.append(poi)
		name_index += 1
	# 保底：至少 3 个地标（在陆地格中按确定性顺序找间隔足够的位置）。
	if pois.size() < 3:
		var fallback: Array[Vector2i] = []
		for y in range(2, height - 2):
			for x in range(2, width - 2):
				var index := y * width + x
				if int(biome[index]) < SAND or river[index] != 0:
					continue
				var cell := Vector2i(x, y)
				var spaced := true
				for existing in fallback:
					if cell.distance_squared_to(existing) < 5 * 5:
						spaced = false
						break
				if spaced:
					fallback.append(cell)
				if fallback.size() >= 6:
					break
			if fallback.size() >= 6:
				break
		for cell in fallback:
			if pois.size() >= 3:
				break
			var poi := _make_poi(cell, rng, names, name_index)
			pois.append(poi)
			name_index += 1
	if pois.size() > 6:
		pois.resize(6)
	# 清出地标周围的空地，再放地标装饰。
	var cleared: Array = []
	for item in decor:
		if not item.has("pos"):
			continue
		var pos: Vector2 = item["pos"]
		var keep := true
		for poi in pois:
			var poi_pos: Vector2 = poi["pos"]
			if pos.distance_to(poi_pos) < 2.6 * 32.0:
				keep = false
				break
		if keep:
			cleared.append(item)
	decor = cleared
	for poi in pois:
		decor.append({"kind": poi["kind"], "pos": poi["pos"],
			"scale": 1.0, "variant": 0, "poi": true})
	_build_regions()
	_assign_regions()
	_finish_signature()
	valid = _validate()
	stage_notes.append("地标 = 陆地 Poisson 3–8 个；区域 = 地标 + 额外种子最近点划分")


func _make_poi(cell: Vector2i, rng: RandomNumberGenerator, names: Array,
		name_index: int) -> Dictionary:
	var occupied := false
	for poi in pois:
		var existing: Vector2i = poi["cell"]
		if existing == cell:
			occupied = true
			break
	if occupied:
		cell = _nearest_land(cell)
	var water_distance := _local_water_distance(cell, 6)
	var kind := _pick_poi_kind(cell, water_distance, rng)
	var name: String = names[name_index % names.size()]
	var used := false
	for poi in pois:
		if String(poi["name"]) == name:
			used = true
			break
	if used:
		for offset in names.size():
			var candidate: String = names[(name_index + offset) % names.size()]
			var taken := false
			for poi in pois:
				if String(poi["name"]) == candidate:
					taken = true
					break
			if not taken:
				name = candidate
				break
	return {
		"kind": kind,
		"cell": cell,
		"pos": Vector2(float(cell.x) + 0.5, float(cell.y) + 0.55) * 32.0,
		"name": name,
		"region": pois.size(),
		"water_distance": water_distance,
	}


func _local_water_distance(cell: Vector2i, radius: int) -> int:
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := cell.x + dx
				var y := cell.y + dy
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				if int(biome[y * width + x]) < SAND:
					return r
	return radius + 1


func _nearest_land(cell: Vector2i) -> Vector2i:
	for radius in range(1, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var candidate := cell + Vector2i(dx, dy)
				if land_cell(candidate):
					return candidate
	return cell


func _pick_poi_kind(cell: Vector2i, water_distance: int,
		rng: RandomNumberGenerator) -> String:
	var wd := water_distance
	var e := elevation[cell.y * width + cell.x]
	if wd <= 4 and rng.randf() < 0.62:
		return "lighthouse"
	if e > 0.34 and rng.randf() < 0.55:
		return "tower"
	var roll := rng.randf()
	if roll < 0.30:
		return "ruins"
	if roll < 0.58:
		return "camp"
	return "village"


func _shuffle(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = array[i]
		array[i] = array[j]
		array[j] = tmp


func _build_regions() -> void:
	regions = []
	for poi in pois:
		regions.append(poi["cell"])
	var extra := _poisson(8.5, 12, "region", 5, 2)
	for point in extra:
		var cell := _sample_cell(point)
		var too_close := false
		for existing in regions:
			if cell.distance_squared_to(existing) < 4 * 4:
				too_close = true
				break
		if not too_close:
			regions.append(cell)
		if regions.size() >= 9:
			break
	if regions.is_empty():
		# 极端情况下至少一个区域种子放在最高陆地上。
		var best := Vector2i.ZERO
		var best_e := -999.0
		for i in width * height:
			if int(biome[i]) >= SAND and elevation[i] > best_e:
				best_e = elevation[i]
				best = Vector2i(i % width, i / width)
		regions.append(best)


func _assign_regions() -> void:
	region.fill(-1)
	for y in height:
		for x in width:
			var index := y * width + x
			if int(biome[index]) < SAND:
				continue
			var best := -1
			var best_dist := 1 << 30
			for i in regions.size():
				var seed_cell: Vector2i = regions[i]
				var dx := x - seed_cell.x
				var dy := y - seed_cell.y
				var d := dx * dx + dy * dy
				if d < best_dist:
					best_dist = d
					best = i
			region[index] = best


func _finish_signature() -> void:
	var h := Utils.signature_start()
	h = Utils.fnv_int(h, base_seed)
	h = Utils.fnv_int(h, int(round(sea_level * 1000.0)))
	h = Utils.fnv_bytes(h, biome)
	h = Utils.fnv_bytes(h, river)
	for item in decor:
		h = Utils.fnv_int(h, String(item["kind"]).hash())
		if item.has("pos"):
			var pos: Vector2 = item["pos"]
			h = Utils.fnv_int(h, Utils.quantize(pos.x))
			h = Utils.fnv_int(h, Utils.quantize(pos.y))
		if item.has("scale"):
			h = Utils.fnv_int(h, Utils.quantize(float(item["scale"]) * 100.0))
		if item.has("variant"):
			h = Utils.fnv_int(h, int(item["variant"]))
	for poi in pois:
		h = Utils.fnv_int(h, String(poi["name"]).hash())
		h = Utils.fnv_int(h, String(poi["kind"]).hash())
		var cell: Vector2i = poi["cell"]
		h = Utils.fnv_int(h, cell.x)
		h = Utils.fnv_int(h, cell.y)
	for seed_cell in regions:
		h = Utils.fnv_int(h, seed_cell.x)
		h = Utils.fnv_int(h, seed_cell.y)
	signature = Utils.fmt_sig(h)


func _validate() -> bool:
	if land_pct < 0.15 or land_pct > 0.72:
		return false
	if largest_land_pct < 90.0:
		return false
	if rivers_to_sea < 1:
		return false
	if pois.size() < 3 or pois.size() > 8:
		return false
	return true
