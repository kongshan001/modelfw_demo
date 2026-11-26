extends RefCounted

# 池塘解析场 + 低分辨率遮罩贴图。
# 同一套参数同时服务：地形网格高度、水面 mask/深度色、岛影、鱼群边界与 smoke 断言。
# 世界单位：1 m；水面 y = 0；俯视相机绕原点环绕。

const WATER_LEVEL := 0.0
const BOUNDS_MIN := Vector2(-15.0, -11.0)
const BOUNDS_MAX := Vector2(15.0, 11.0)
const POND_CENTER := Vector2(0.0, 0.0)
const POND_RADII := Vector2(12.6, 8.5)
const FIELD_W := 384
const FIELD_H := 288

# center/radii 为世界单位；rot 为弧度；height 为草岛顶面高度。
const ISLANDS := [
	{"center": Vector2(-4.2, -1.6), "radii": Vector2(2.35, 1.8), "rot": 0.38, "height": 0.62, "seed": 11},
	{"center": Vector2(4.4, 2.1), "radii": Vector2(2.55, 1.95), "rot": -0.28, "height": 0.58, "seed": 27},
	{"center": Vector2(-8.7, 4.5), "radii": Vector2(1.3, 1.0), "rot": 0.62, "height": 0.44, "seed": 41},
	{"center": Vector2(9.0, -4.6), "radii": Vector2(1.15, 0.9), "rot": 0.12, "height": 0.4, "seed": 55},
]

# 露出水面的石头 (x, z, 半径, 高度, seed)
const ROCKS := [
	{"pos": Vector2(-3.6, -1.1), "radius": 0.62, "height": 0.82, "seed": 7, "on_island": 0},
	{"pos": Vector2(3.8, 1.7), "radius": 0.78, "height": 1.0, "seed": 21, "on_island": 1},
	{"pos": Vector2(-5.1, -2.3), "radius": 0.45, "height": 0.55, "seed": 33, "on_island": 0},
	{"pos": Vector2(5.3, 2.7), "radius": 0.5, "height": 0.62, "seed": 47, "on_island": 1},
	{"pos": Vector2(1.5, -4.9), "radius": 0.52, "height": 0.3, "seed": 61, "on_island": -1},
	{"pos": Vector2(-7.0, 1.0), "radius": 0.4, "height": 0.22, "seed": 73, "on_island": -1},
	{"pos": Vector2(7.6, -1.4), "radius": 0.34, "height": 0.18, "seed": 81, "on_island": -1},
]

static func pond_radius_factor(p: Vector2) -> float:
	var q := Vector2(p.x / POND_RADII.x, p.y / POND_RADII.y)
	var ang := atan2(q.y, q.x)
	var r := pow(pow(abs(q.x), 2.6) + pow(abs(q.y), 2.6), 1.0 / 2.6)
	r += 0.035 * sin(ang * 3.0 + 0.8)
	r += 0.022 * sin(ang * 5.0 - 1.7)
	r += 0.011 * sin(ang * 8.0 + 0.3)
	return r

# 正值在水里（到岸的距离，米），负值在岸上。
static func shore_distance(p: Vector2) -> float:
	return (1.0 - pond_radius_factor(p)) * 5.2

static func island_local(index: int, p: Vector2) -> Vector2:
	var cfg: Dictionary = ISLANDS[index]
	var d: Vector2 = p - (cfg["center"] as Vector2)
	return d.rotated(-float(cfg["rot"]))

# 负值在岛内，正值在水里（到岛缘的近似米数）。
static func island_distance(index: int, p: Vector2) -> float:
	var cfg: Dictionary = ISLANDS[index]
	var q := island_local(index, p)
	var radii: Vector2 = cfg["radii"]
	var nq := Vector2(q.x / radii.x, q.y / radii.y)
	var ang := atan2(nq.y, nq.x)
	var rr := nq.length() + 0.075 * sin(ang * 4.0 + float(cfg["seed"])) + 0.035 * sin(ang * 7.0 - 1.1)
	return (rr - 1.0) * min(radii.x, radii.y)

static func nearest_island(p: Vector2) -> int:
	var best := -1
	var best_d := 1e9
	for i in ISLANDS.size():
		var d := island_distance(i, p)
		if d < best_d:
			best_d = d
			best = i
	return best

static func is_land(p: Vector2) -> bool:
	if pond_radius_factor(p) > 1.0:
		return true
	for i in ISLANDS.size():
		if island_distance(i, p) < 0.0:
			return true
	return false

static func is_water(p: Vector2) -> bool:
	return not is_land(p)

# 0 = 岸/岛边，1 = 深水。
static func depth_factor(p: Vector2) -> float:
	if not is_water(p):
		return 0.0
	# 主体深度由离岸距离决定；近岛单独压成浅滩，避免岛靠近时整池变浅。
	var shore_df := clampf(shore_distance(p) / 3.1, 0.0, 1.0)
	var island_min := 1e9
	for i in ISLANDS.size():
		island_min = min(island_min, island_distance(i, p))
	var island_factor := smoothstep(0.12, 1.7, island_min)
	return clampf(shore_df * (0.34 + 0.66 * island_factor), 0.0, 1.0)

static func floor_y(p: Vector2) -> float:
	if not is_water(p):
		return 0.12
	var df := depth_factor(p)
	var ripple := 0.05 * sin(p.x * 1.7 + p.y * 0.9) + 0.03 * sin(p.y * 2.3 - p.x * 1.1)
	return -0.15 - 1.65 * df + ripple

static func bank_y(p: Vector2) -> float:
	var out := -shore_distance(p)
	return 0.05 + 0.42 * smoothstep(0.15, 2.6, out) + 0.08 * sin(p.x * 0.7 + p.y * 1.1)

static func terrain_y(p: Vector2) -> float:
	if is_water(p):
		return floor_y(p)
	return bank_y(p)

static func island_top_y(index: int, p: Vector2) -> float:
	var cfg: Dictionary = ISLANDS[index]
	var q := island_local(index, p)
	var radii: Vector2 = cfg["radii"]
	var nq := Vector2(q.x / radii.x, q.y / radii.y)
	var r := clampf(nq.length(), 0.0, 1.0)
	# 中间略鼓，岸边稍低的草帽形
	return float(cfg["height"]) + 0.12 * (1.0 - r * r)

# 鱼群安全边界：距水边/岛缘 >= margin 米。
static func fish_blocked(p: Vector2, margin: float) -> bool:
	if pond_radius_factor(p) > 1.0:
		return true
	for i in ISLANDS.size():
		if island_distance(i, p) < margin:
			return true
	return false

# 找到一个合法的鱼活动点（给生成/避让用）。
static func clamp_to_water(p: Vector2, margin: float = 1.0) -> Vector2:
	var out := p
	if not fish_blocked(out, margin):
		return out
	var center: Vector2 = POND_CENTER
	for _i in 14:
		out = out.lerp(center, 0.16)
		if not fish_blocked(out, margin):
			return out
	return Vector2(0.0, 0.0)

# 生成 RGBA8 场贴图：
# R = 水深系数 0..1；G = 离岸/离岛距离（米/4，截断）；
# B = 陆地 mask；A = 水面 mask。
static func build_field_texture() -> ImageTexture:
	var img := Image.create(FIELD_W, FIELD_H, false, Image.FORMAT_RGBA8)
	var size := BOUNDS_MAX - BOUNDS_MIN
	for y in FIELD_H:
		var v := (float(y) + 0.5) / float(FIELD_H)
		var wz := BOUNDS_MIN.y + v * size.y
		for x in FIELD_W:
			var u := (float(x) + 0.5) / float(FIELD_W)
			var wx := BOUNDS_MIN.x + u * size.x
			var p := Vector2(wx, wz)
			var water := is_water(p)
			var df := depth_factor(p)
			var d_shore := shore_distance(p)
			var d_island := 1e9
			for i in ISLANDS.size():
				d_island = min(d_island, island_distance(i, p))
			var d_near := d_shore
			if is_land(p) and d_island < 1e8:
				d_near = min(d_near, d_island) if d_island > -0.01 else d_island
			var land := 1.0 if not water else 0.0
			img.set_pixel(x, y, Color(df, clampf(d_near / 4.0, 0.0, 1.0), land, 1.0 if water else 0.0))
	return ImageTexture.create_from_image(img)

static func field_uv(p: Vector2) -> Vector2:
	var size := BOUNDS_MAX - BOUNDS_MIN
	return Vector2((p.x - BOUNDS_MIN.x) / size.x, (p.y - BOUNDS_MIN.y) / size.y)

static func island_rock_position(index: int) -> Vector3:
	var cfg: Dictionary = ISLANDS[index]
	var p: Vector2 = cfg["center"]
	return Vector3(p.x + 0.35, float(cfg["height"]) + 0.1, p.y + 0.15)

static func is_rock_above_water(rock: Dictionary) -> bool:
	var p: Vector2 = rock["pos"]
	if int(rock["on_island"]) >= 0:
		return true
	return float(rock["height"]) > 0.4
