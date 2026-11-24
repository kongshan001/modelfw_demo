class_name MistIsland
extends Node3D
## 程序化岛：高度场 + 低模地形网格 + 海岸泡沫 + 合并植被 + AStar3D 导航。
## 地图、房屋、登陆点、地标全部原创，seed 固定可复现。

const Balance = preload("res://scripts/balance.gd")
const Models = preload("res://scripts/models.gd")
const HouseScript = preload("res://scripts/house.gd")

const WATER_LEVEL := 0.55
const TERRAIN_STEP := 2.0
const TERRAIN_HALF := 54.0
const NAV_STEP := 2.0

var game
var island_index := 0
var data: Dictionary
var radius := 40.0
var plateau := 7.2
var seed_value := 0
var height_noise: FastNoiseLite
var houses: Array = []
var landing_points: Array = []
var squad_spawn_points: Array = []
var house_spots: Array = []
var is_built := false

var _astar := AStar3D.new()
var _nav_points: Dictionary = {}
var _nav_ids: Dictionary = {}
var _nav_half := 48.0
var _nav_count := 0
var _path_segments: Array = []


func build(index: int, game_ref) -> void:
	game = game_ref
	island_index = index
	data = Balance.island(index)
	radius = float(data["radius"])
	plateau = float(data["plateau"])
	seed_value = int(data["seed"])
	name = "Island_" + str(data["id"])

	height_noise = FastNoiseLite.new()
	height_noise.seed = seed_value
	height_noise.frequency = 0.055
	height_noise.fractal_octaves = 3
	height_noise.fractal_gain = 0.5

	_compute_landings()
	_compute_house_spots()
	_compute_squad_spawns()
	_build_path_segments()
	_build_terrain()
	_build_water()
	_build_foam()
	_build_props()
	_build_nav()
	_build_houses()
	is_built = true


# ---------------------------------------------------------------- height field

func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := p.length()
	var rr := d / radius
	var inland := clampf(1.0 - rr, 0.0, 1.0)
	var h := 0.34 + plateau * _smoothstep(0.12, 0.70, inland)
	for off in data["hill_offsets"]:
		var dv: Vector2 = p - (off as Vector2)
		var g := exp(-dv.length_squared() / (2.0 * 8.0 * 8.0))
		h += 1.15 * g * _smoothstep(0.10, 0.48, inland)
	h += height_noise.get_noise_2d(x * 0.85, z * 0.85) * 0.72 * _smoothstep(0.26, 0.72, inland)
	if rr > 1.0:
		h -= (rr - 1.0) * 12.0
	return h


func ground_pos(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


func slope_at(x: float, z: float) -> float:
	var e := 0.85
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector2(hx / (2.0 * e), hz / (2.0 * e)).length()


func normal_at(x: float, z: float) -> Vector3:
	var e := 0.8
	var hx := height_at(x + e, z) - height_at(x - e, z)
	var hz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-hx / (2.0 * e), 1.0, -hz / (2.0 * e)).normalized()


func is_terrain_walkable(x: float, z: float) -> bool:
	if Vector2(x, z).length() > radius * 1.04:
		return false
	if height_at(x, z) < WATER_LEVEL + 0.25:
		return false
	return slope_at(x, z) < 1.05


func is_walkable(pos: Vector3) -> bool:
	return is_terrain_walkable(pos.x, pos.z)


func clamp_to_walkable(pos: Vector3) -> Vector3:
	if is_terrain_walkable(pos.x, pos.z):
		return ground_pos(pos.x, pos.z)
	var id := _astar.get_closest_point(pos)
	if _nav_points.has(id):
		return _nav_points[id]
	return ground_pos(0, 0)


# ---------------------------------------------------------------- layout

func _compute_landings() -> void:
	landing_points.clear()
	for angle in data["landing_angles"]:
		var landing := _find_landing(float(angle))
		landing_points.append(landing)


func _find_landing(angle_deg: float) -> Dictionary:
	var dir := Vector2(cos(deg_to_rad(angle_deg)), sin(deg_to_rad(angle_deg)))
	var shore_r := radius * 0.9
	# 从海侧向内找水线，再向内退到可行走的滩地。
	for i in range(240, 0, -1):
		var r := float(i) / 240.0 * radius * 1.06
		var p := dir * r
		if height_at(p.x, p.y) >= WATER_LEVEL + 0.03:
			shore_r = r
			break
	var best := dir * (shore_r - 2.0)
	for attempt in range(12):
		var r := shore_r - 1.6 - float(attempt) * 0.7
		var p := dir * r
		if is_terrain_walkable(p.x, p.y) and slope_at(p.x, p.y) < 0.7:
			best = p
			break
	var outward := Vector3(dir.x, 0.0, dir.y)
	var ground := ground_pos(best.x, best.y)
	return {
		"pos": ground,
		"shore": ground_pos(dir.x * shore_r, dir.y * shore_r),
		"outward": outward,
		"boat": Vector3(dir.x * (radius * 0.9 + 15.0), WATER_LEVEL - 0.12, dir.y * (radius * 0.9 + 15.0)),
		"angle": angle_deg,
	}


func _compute_house_spots() -> void:
	house_spots.clear()
	var used: Array = []
	for i in range(data["house_positions"].size()):
		var desired: Vector2 = data["house_positions"][i]
		var spot := _find_buildable(desired, used, 8.0)
		used.append(spot)
		house_spots.append({
			"pos": ground_pos(spot.x, spot.y),
			"yaw": float(data["house_yaws"][i]),
			"variant": i % 3,
		})


func _find_buildable(desired: Vector2, used: Array, search_radius: float) -> Vector2:
	var best := desired
	var best_score := INF
	for ring in range(0, 7):
		var count := 1 if ring == 0 else 8 + ring * 4
		for i in range(count):
			var angle := float(i) / float(maxi(1, count)) * TAU + float(ring) * 0.35
			var r := float(ring) * search_radius / 6.0
			var candidate := desired + Vector2(cos(angle), sin(angle)) * r
			if not is_terrain_walkable(candidate.x, candidate.y):
				continue
			if slope_at(candidate.x, candidate.y) > 0.34:
				continue
			if height_at(candidate.x, candidate.y) < WATER_LEVEL + 2.4:
				continue
			var too_close := false
			for old in used:
				if candidate.distance_to(old) < 5.5:
					too_close = true
					break
			if too_close:
				continue
			for landing in landing_points:
				if candidate.distance_to(Vector2(landing["pos"].x, landing["pos"].z)) < 7.0:
					too_close = true
					break
			if too_close:
				continue
			var score := candidate.distance_to(desired) + slope_at(candidate.x, candidate.y) * 3.0
			if score < best_score:
				best_score = score
				best = candidate
				if ring == 0:
					return best
		if best_score < INF:
			break
	return best


func _compute_squad_spawns() -> void:
	squad_spawn_points.clear()
	for desired in data["squad_positions"]:
		var p: Vector2 = desired
		var spot := p
		if not is_terrain_walkable(p.x, p.y) or slope_at(p.x, p.y) > 0.5:
			var found := false
			for ring in range(1, 9):
				for i in range(8):
					var angle := float(i) / 8.0 * TAU
					var candidate := p + Vector2(cos(angle), sin(angle)) * float(ring) * 1.2
					if is_terrain_walkable(candidate.x, candidate.y) and slope_at(candidate.x, candidate.y) < 0.5:
						spot = candidate
						found = true
						break
				if found:
					break
		var pos := ground_pos(spot.x, spot.y)
		pos.y += 0.03
		squad_spawn_points.append(pos)


func _build_path_segments() -> void:
	_path_segments.clear()
	for landing in landing_points:
		var lp := Vector2(landing["pos"].x, landing["pos"].z)
		var best_i := 0
		var best_d := INF
		for i in range(house_spots.size()):
			var hp := Vector2(house_spots[i]["pos"].x, house_spots[i]["pos"].z)
			var d := lp.distance_to(hp)
			if d < best_d:
				best_d = d
				best_i = i
		if house_spots.size() > 0:
			_path_segments.append([lp, Vector2(house_spots[best_i]["pos"].x, house_spots[best_i]["pos"].z)])
	if house_spots.size() >= 2:
		_path_segments.append([
			Vector2(house_spots[0]["pos"].x, house_spots[0]["pos"].z),
			Vector2(house_spots[1]["pos"].x, house_spots[1]["pos"].z),
		])


# ---------------------------------------------------------------- terrain mesh

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water_sand := Color("6f7561")
	var wet_sand := Color("a08f68")
	var sand := Color("c9b583")
	var grass_low := Color("648a4f")
	var grass := Color("799c58")
	var grass_high := Color("93a867")
	var rock := Color("6d7269")
	var dirt := Color("a0845c")

	var steps := int(TERRAIN_HALF * 2.0 / TERRAIN_STEP)
	for iz in range(steps):
		for ix in range(steps):
			var x0 := -TERRAIN_HALF + float(ix) * TERRAIN_STEP
			var z0 := -TERRAIN_HALF + float(iz) * TERRAIN_STEP
			var x1 := x0 + TERRAIN_STEP
			var z1 := z0 + TERRAIN_STEP
			var p00 := Vector3(x0, height_at(x0, z0), z0)
			var p10 := Vector3(x1, height_at(x1, z0), z0)
			var p01 := Vector3(x0, height_at(x0, z1), z1)
			var p11 := Vector3(x1, height_at(x1, z1), z1)
			_add_terrain_tri(st, p00, p10, p11, water_sand, wet_sand, sand, grass_low, grass, grass_high, rock, dirt)
			_add_terrain_tri(st, p00, p11, p01, water_sand, wet_sand, sand, grass_low, grass, grass_high, rock, dirt)

	var mesh := st.commit()
	var node := MeshInstance3D.new()
	node.name = "Terrain"
	node.mesh = mesh
	var mat := Models.flat_material().duplicate() as StandardMaterial3D
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)


func _add_terrain_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, water_sand: Color, wet_sand: Color, sand: Color, grass_low: Color, grass: Color, grass_high: Color, rock: Color, dirt: Color) -> void:
	var centroid := (a + b + c) / 3.0
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0.0:
		normal = -normal
	var slope := 1.0 - clampf(normal.y, 0.0, 1.0)
	var base: Color
	if centroid.y < WATER_LEVEL + 0.1:
		base = water_sand
	elif centroid.y < WATER_LEVEL + 0.55:
		base = wet_sand
	elif centroid.y < 1.85:
		base = sand
	elif slope > 0.38:
		base = rock
	else:
		var t := clampf((centroid.y - 1.9) / 5.5, 0.0, 1.0)
		base = grass_low.lerp(grass_high, t)
		if height_noise.get_noise_2d(centroid.x * 0.18, centroid.z * 0.18) > 0.22:
			base = grass
		if _distance_to_paths(Vector2(centroid.x, centroid.z)) < 1.35 and centroid.y > WATER_LEVEL + 0.5:
			base = dirt
	var variation := height_noise.get_noise_2d(centroid.x * 2.7 + 90.0, centroid.z * 2.7 - 40.0) * 0.045
	var color := base.lightened(variation) if variation > 0.0 else base.darkened(-variation)
	for v in [a, b, c]:
		st.set_color(color)
		st.set_normal(normal)
		st.add_vertex(v)


func _distance_to_paths(p: Vector2) -> float:
	var best := INF
	for seg in _path_segments:
		var a: Vector2 = seg[0]
		var b: Vector2 = seg[1]
		var ab := b - a
		var denom := maxf(0.0001, ab.length_squared())
		var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


# ---------------------------------------------------------------- water & foam

func _build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(360.0, 360.0)
	var node := MeshInstance3D.new()
	node.name = "Sea"
	node.mesh = plane
	node.position.y = WATER_LEVEL
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("shore_radius", _average_shore_radius())
	mat.set_shader_parameter("island_center", Vector3.ZERO)
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _average_shore_radius() -> float:
	var total := 0.0
	var count := 0
	for i in range(64):
		var angle := float(i) / 64.0 * TAU
		var dir := Vector2(cos(angle), sin(angle))
		var lo := radius * 0.55
		var hi := radius * 1.06
		for _step in range(22):
			var mid := (lo + hi) * 0.5
			var p := dir * mid
			if height_at(p.x, p.y) < WATER_LEVEL:
				hi = mid
			else:
				lo = mid
		total += lo
		count += 1
	return total / float(maxi(1, count))


func _build_foam() -> void:
	for ring_index in range(2):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segments := 160
		var radii: Array[float] = []
		for i in range(segments + 1):
			var angle := float(i) / float(segments) * TAU
			var dir := Vector2(cos(angle), sin(angle))
			var lo := radius * 0.55
			var hi := radius * 1.06
			for _step in range(28):
				var mid := (lo + hi) * 0.5
				var p := dir * mid
				if height_at(p.x, p.y) < WATER_LEVEL:
					hi = mid
				else:
					lo = mid
			radii.append(lo)
		for i in range(segments):
			var a0 := float(i) / float(segments) * TAU
			var a1 := float(i + 1) / float(segments) * TAU
			var d0 := Vector2(cos(a0), sin(a0))
			var d1 := Vector2(cos(a1), sin(a1))
			var r0: float = radii[i]
			var r1: float = radii[i + 1]
			var width_off := 0.05 if ring_index == 0 else 2.5
			var width := 1.7 if ring_index == 0 else 2.3
			var y := WATER_LEVEL + 0.06 + (0.01 if ring_index == 0 else 0.0)
			var i00 := Vector3(d0.x * (r0 + width_off), y, d0.y * (r0 + width_off))
			var i01 := Vector3(d1.x * (r1 + width_off), y, d1.y * (r1 + width_off))
			var i10 := Vector3(d0.x * (r0 + width_off + width), y, d0.y * (r0 + width_off + width))
			var i11 := Vector3(d1.x * (r1 + width_off + width), y, d1.y * (r1 + width_off + width))
			_add_foam_quad(st, i00, i01, i11, i10)
		var node := MeshInstance3D.new()
		node.name = "Foam%d" % ring_index
		node.mesh = st.commit()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.88, 0.95, 0.90, 0.40 if ring_index == 0 else 0.20)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


func _add_foam_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := Vector3.UP
	for tri in [[a, b, c], [a, c, d]]:
		for v in tri:
			st.set_normal(normal)
			st.add_vertex(v)


# ---------------------------------------------------------------- props

func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 771
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass_st := SurfaceTool.new()
	grass_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tree_positions: Array = []
	var prop_count := 0

	for _i in range(92):
		var angle := rng.randf() * TAU
		var r := radius * rng.randf_range(0.18, 0.84)
		var p := Vector2(cos(angle), sin(angle)) * r
		if not is_terrain_walkable(p.x, p.y):
			continue
		if slope_at(p.x, p.y) > 0.42:
			continue
		if height_at(p.x, p.y) < WATER_LEVEL + 1.0:
			continue
		if _near_house(p, 4.6) or _near_landing(p, 3.2) or _near_path(p, 2.0) or _near_squad_spawn(p, 2.2):
			continue
		var crowded := false
		for old in tree_positions:
			if p.distance_to(old) < 2.2:
				crowded = true
				break
		if crowded:
			continue
		var pos := ground_pos(p.x, p.y)
		var h := rng.randf_range(2.4, 3.9)
		if rng.randf() < 0.30:
			Models.append_broadleaf(st, pos, h, int(rng.randi() % 3))
		else:
			Models.append_pine(st, pos, h, int(rng.randi() % 3))
		tree_positions.append(p)
		prop_count += 1
		if prop_count >= 48:
			break

	for _i in range(52):
		var angle := rng.randf() * TAU
		var r := radius * rng.randf_range(0.25, 0.92)
		var p := Vector2(cos(angle), sin(angle)) * r
		if not is_terrain_walkable(p.x, p.y):
			continue
		if _near_house(p, 3.2) or _near_landing(p, 2.1) or _near_path(p, 1.4):
			continue
		var pos := ground_pos(p.x, p.y)
		Models.append_rock(st, pos, rng.randf_range(0.28, 0.9), int(rng.randi() % 3))

	for _i in range(280):
		var angle := rng.randf() * TAU
		var r := radius * rng.randf_range(0.18, 0.88)
		var p := Vector2(cos(angle), sin(angle)) * r
		if not is_terrain_walkable(p.x, p.y) or slope_at(p.x, p.y) > 0.55:
			continue
		if height_at(p.x, p.y) < WATER_LEVEL + 0.4:
			continue
		if _near_path(p, 0.8) or _near_house(p, 1.8) or _near_landing(p, 1.6):
			continue
		Models.append_grass(grass_st, ground_pos(p.x, p.y), int(rng.randi() % 3))

	# 房屋旁的小树丛，形成聚落感
	for spot in house_spots:
		var center := Vector2(spot["pos"].x, spot["pos"].z)
		for k in range(3):
			var a := float(k) * 2.1 + float(seed_value % 7) * 0.3
			var cand := center + Vector2(cos(a), sin(a)) * (4.3 + 0.8 * float(k))
			if is_terrain_walkable(cand.x, cand.y) and slope_at(cand.x, cand.y) < 0.45:
				Models.append_broadleaf(st, ground_pos(cand.x, cand.y), rng.randf_range(2.0, 3.0), k)

	# 房屋旁的两段矮栅栏
	if house_spots.size() > 0:
		for i in range(mini(2, house_spots.size())):
			var center := Vector2(house_spots[i]["pos"].x, house_spots[i]["pos"].z)
			var tangent := Vector2(cos(float(house_spots[i]["yaw"]) * 0.01745), sin(float(house_spots[i]["yaw"]) * 0.01745))
			var a := center + tangent * 3.2 + Vector2(0.8, -1.0)
			var b := center + tangent * 5.6 + Vector2(0.8, -1.0)
			if is_terrain_walkable(a.x, a.y) and is_terrain_walkable(b.x, b.y):
				Models.append_fence(st, ground_pos(a.x, a.y), ground_pos(b.x, b.y), 3)

	# 每个登陆点的木质栈桥
	for landing in landing_points:
		var outward: Vector3 = landing["outward"]
		var shore: Vector3 = landing["shore"]
		Models.append_pier(st, shore, outward, 5.2)

	var node := MeshInstance3D.new()
	node.name = "Props"
	node.mesh = st.commit()
	node.material_override = Models.flat_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(node)

	var grass_node := MeshInstance3D.new()
	grass_node.name = "Grass"
	grass_node.mesh = grass_st.commit()
	grass_node.material_override = Models.flat_material()
	grass_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass_node)


func _near_house(p: Vector2, radius_check: float) -> bool:
	for spot in house_spots:
		if p.distance_to(Vector2(spot["pos"].x, spot["pos"].z)) < radius_check:
			return true
	return false


func _near_landing(p: Vector2, radius_check: float) -> bool:
	for landing in landing_points:
		if p.distance_to(Vector2(landing["pos"].x, landing["pos"].z)) < radius_check:
			return true
	return false


func _near_path(p: Vector2, radius_check: float) -> bool:
	return _distance_to_paths(p) < radius_check


func _near_squad_spawn(p: Vector2, radius_check: float) -> bool:
	for pos in squad_spawn_points:
		if p.distance_to(Vector2(pos.x, pos.z)) < radius_check:
			return true
	return false


# ---------------------------------------------------------------- navigation

func _build_nav() -> void:
	_astar.clear()
	_nav_points.clear()
	_nav_ids.clear()
	_nav_half = radius + 8.0
	var n := int(ceil(_nav_half * 2.0 / NAV_STEP)) + 1
	_nav_count = n
	for iz in range(n):
		for ix in range(n):
			var x := -_nav_half + float(ix) * NAV_STEP
			var z := -_nav_half + float(iz) * NAV_STEP
			if not is_terrain_walkable(x, z):
				continue
			var blocked := false
			for spot in house_spots:
				var hp := Vector2(spot["pos"].x, spot["pos"].z)
				if Vector2(x, z).distance_to(hp) < 2.7:
					blocked = true
					break
			if blocked:
				continue
			var id := iz * n + ix
			var pos := ground_pos(x, z)
			_astar.add_point(id, pos)
			_nav_points[id] = pos
			_nav_ids[Vector2i(ix, iz)] = id
	for iz in range(n):
		for ix in range(n):
			var id := iz * n + ix
			if not _nav_points.has(id):
				continue
			for offset in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
				var nx: int = ix + offset.x
				var nz: int = iz + offset.y
				if nx < 0 or nz < 0 or nx >= n or nz >= n:
					continue
				var nid := nz * n + nx
				if not _nav_points.has(nid):
					continue
				var pa: Vector3 = _nav_points[id]
				var pb: Vector3 = _nav_points[nid]
				if absf(pa.y - pb.y) > 2.4:
					continue
				if offset.x != 0 and offset.y != 0:
					if not _nav_points.has(iz * n + nx) or not _nav_points.has(nz * n + ix):
						continue
				_astar.connect_points(id, nid)


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	if _nav_points.is_empty():
		return PackedVector3Array([to])
	var start := clamp_to_walkable(from)
	var finish := clamp_to_walkable(to)
	var from_id := _astar.get_closest_point(start)
	var to_id := _astar.get_closest_point(finish)
	if from_id == -1 or to_id == -1:
		return PackedVector3Array([finish])
	var ids := _astar.get_id_path(from_id, to_id)
	if ids.is_empty():
		return PackedVector3Array([finish])
	for id in ids:
		result.append(_nav_points[id])
	if result.size() > 0 and result[result.size() - 1].distance_to(finish) > 1.2:
		result.append(finish)
	return _smooth_path(result)


func _smooth_path(points: PackedVector3Array) -> PackedVector3Array:
	if points.size() <= 2:
		return points
	var out := PackedVector3Array()
	out.append(points[0])
	var anchor := 0
	while anchor < points.size() - 1:
		var next := anchor + 1
		var probe := anchor + 2
		while probe < points.size():
			if _segment_walkable(points[anchor], points[probe]):
				next = probe
				probe += 1
			else:
				break
		out.append(points[next])
		anchor = next
	return out


func _segment_walkable(a: Vector3, b: Vector3) -> bool:
	var dist := a.distance_to(b)
	var steps := maxi(2, int(ceil(dist / 1.0)))
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		if not is_terrain_walkable(p.x, p.z):
			return false
	return true


func get_nearest_house(pos: Vector3):
	var best = null
	var best_d := INF
	for house in houses:
		if house.destroyed:
			continue
		var d: float = pos.distance_to(house.global_position)
		if d < best_d:
			best_d = d
			best = house
	return best


# ---------------------------------------------------------------- houses

func _build_houses() -> void:
	houses.clear()
	for i in range(house_spots.size()):
		var spot: Dictionary = house_spots[i]
		var house = HouseScript.new()
		add_child(house)
		var pos: Vector3 = spot["pos"]
		pos.y += 0.04
		house.configure(game, i, pos, float(spot["yaw"]), int(spot["variant"]))
		houses.append(house)


# ---------------------------------------------------------------- utils

func nav_point_count() -> int:
	return _nav_points.size()


func landing_count() -> int:
	return landing_points.size()


func _smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t := clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
