extends RefCounted

# 原创程序化瓦片/道具。全部在运行时用 Image 像素绘制，再烘焙为 TileSet 图集。
# 不读取任何外部贴图；不复制任何商业游戏素材。
#
# 方向位：N=1, E=2, S=4, W=8（用于墙体/地形过渡/海岸/河流接口）。

const Utils = preload("res://scripts/gen_utils.gd")

const TS := 32
const N := 1
const E := 2
const S := 4
const W := 8

# ---- 地牢色板 ----
const D_FLOOR := Color("#62645a")
const D_FLOOR_HI := Color("#7d7f71")
const D_FLOOR_LO := Color("#4e5048")
const D_MORTAR := Color("#343a34")
const D_WALL := Color("#3b474e")
const D_WALL_HI := Color("#7b878b")
const D_WALL_EDGE := Color("#1b2328")
const D_WOOD := Color("#6b5238")
const D_WOOD_HI := Color("#846746")
const D_MOSS := Color("#5a7547")
const D_GOLD := Color("#b8944e")

# ---- 生物群系色板 ----
const B_DEEP := Color("#123943")
const B_DEEP_HI := Color("#1b4d58")
const B_MID := Color("#1a5560")
const B_MID_HI := Color("#246a74")
const B_SHALLOW := Color("#2c7479")
const B_SHALLOW_HI := Color("#3d8d8b")
const B_FOAM := Color("#cfe6d9")
const B_SAND := Color("#d5c08a")
const B_SAND_HI := Color("#e4d3a0")
const B_SAND_LO := Color("#bca672")
const B_GRASS := Color("#6f9752")
const B_GRASS_HI := Color("#84ab60")
const B_GRASS_LO := Color("#5a8146")
const B_FOREST := Color("#3b6542")
const B_FOREST_HI := Color("#5a8853")
const B_FOREST_LO := Color("#2b4e34")
const B_ROCK := Color("#7d817b")
const B_ROCK_HI := Color("#9b9d93")
const B_ROCK_LO := Color("#5b615d")
const B_SNOW := Color("#e6ece6")
const B_SNOW_HI := Color("#f5f8f2")
const B_SNOW_LO := Color("#b9cbc8")
const B_RIVER := Color("#2f7f86")
const B_RIVER_HI := Color("#5fa8a4")


static func build_dungeon(seed_salt: int = 17021) -> Dictionary:
	var entries: Array[Dictionary] = []

	var floors: Dictionary = {}
	var kinds := ["stone", "moss", "wood", "gold"]
	for kind in kinds:
		var list: Array[String] = []
		for variant in 6:
			var name := "floor_%s_%d" % [kind, variant]
			entries.append({"name": name, "image": _dungeon_floor(kind, variant, seed_salt)})
			list.append(name)
		floors[kind] = list

	var shadows: Array[String] = []
	for mask in 16:
		var name := "shadow_%d" % mask
		entries.append({"name": name, "image": _floor_shadow(mask, seed_salt)})
		shadows.append(name)

	var walls: Array[String] = []
	for mask in 16:
		for variant in 2:
			var name := "wall_%d_%d" % [mask, variant]
			entries.append({"name": name, "image": _dungeon_wall(mask, variant, seed_salt)})
			walls.append(name)

	var packed := _pack(entries)
	var coords: Dictionary = packed["coords"]
	var result := {
		"tileset": packed["tileset"],
		"coords": coords,
		"floor": {},
		"shadow": _coords_list(coords, shadows),
		"wall": [],
		"props": {},
		"colors": {
			"void": Color("#0b1114"),
			"grid": Color(0.24, 0.33, 0.33, 0.12),
			"accent": Color("#e4b96f"),
		},
	}
	for kind in kinds:
		result["floor"][kind] = _coords_list(coords, floors[kind])
	var wall_coords: Array[Vector2i] = []
	for index in walls.size():
		wall_coords.append(coords[walls[index]])
	result["wall"] = wall_coords

	var props := {}
	props["torch"] = _tex(_torch())
	props["crate"] = _tex(_crate())
	props["barrel"] = _tex(_barrel())
	props["chest"] = _tex(_chest())
	props["table"] = _tex(_table())
	props["bones"] = _tex(_bones())
	props["mushrooms"] = _tex(_mushrooms())
	props["pillar"] = _tex(_pillar())
	props["start"] = _tex(_start_rune())
	props["exit"] = _tex(_exit_stairs())
	props["rug_a"] = _tex(_rug(0))
	props["rug_b"] = _tex(_rug(1))
	result["props"] = props
	return result


static func build_biome(seed_salt: int = 22037) -> Dictionary:
	var entries: Array[Dictionary] = []

	var water := {"deep": [], "mid": [], "shallow": []}
	for depth in ["deep", "mid", "shallow"]:
		var names: Array[String] = []
		for variant in 3:
			var name := "water_%s_%d" % [depth, variant]
			entries.append({"name": name, "image": _water_tile(depth, variant, seed_salt)})
			names.append(name)
		water[depth] = names

	var grass_names: Array[String] = []
	for variant in 5:
		var name := "grass_%d" % variant
		entries.append({"name": name, "image": _grass_tile(variant, seed_salt)})
		grass_names.append(name)

	var overlay_defs := {
		"sand": {"variants": 2, "maker": Callable(_make_sand)},
		"forest": {"variants": 2, "maker": Callable(_make_forest)},
		"rock": {"variants": 1, "maker": Callable(_make_rock)},
		"snow": {"variants": 1, "maker": Callable(_make_snow)},
	}
	var overlay_names := {}
	for key in overlay_defs:
		var names: Array[String] = []
		var variants: int = int(overlay_defs[key]["variants"])
		for mask in 16:
			for variant in variants:
				var name := "%s_%d_%d" % [key, mask, variant]
				var image: Image = overlay_defs[key]["maker"].call(mask, variant, seed_salt)
				entries.append({"name": name, "image": image})
				names.append(name)
		overlay_names[key] = names

	var coast_names: Array[String] = []
	for mask in 16:
		var name := "coast_%d" % mask
		entries.append({"name": name, "image": _coast_foam(mask, seed_salt)})
		coast_names.append(name)

	var river_names: Array[String] = []
	for mask in 16:
		var name := "river_%d" % mask
		entries.append({"name": name, "image": _river_tile(mask, seed_salt)})
		river_names.append(name)

	var packed := _pack(entries)
	var coords: Dictionary = packed["coords"]
	var result := {
		"tileset": packed["tileset"],
		"coords": coords,
		"water": {},
		"grass": _coords_list(coords, grass_names),
		"overlays": {},
		"coast": _coords_list(coords, coast_names),
		"river": _coords_list(coords, river_names),
		"props": {},
		"colors": {
			"deep": B_DEEP, "mid": B_MID, "shallow": B_SHALLOW,
			"sand": B_SAND, "grass": B_GRASS, "forest": B_FOREST,
			"rock": B_ROCK, "snow": B_SNOW, "river": B_RIVER,
			"void": Color("#0a252c"), "accent": Color("#e4b96f"),
		},
	}
	for depth in water:
		result["water"][depth] = _coords_list(coords, water[depth])
	for key in overlay_names:
		var list: Array[Vector2i] = []
		for name in overlay_names[key]:
			list.append(coords[name])
		result["overlays"][key] = list

	var props := {}
	var oak_names: Array[Texture2D] = []
	for variant in 6:
		oak_names.append(_tex(_tree_broadleaf(variant, seed_salt)))
	var pine_names: Array[Texture2D] = []
	for variant in 4:
		pine_names.append(_tex(_tree_conifer(variant, seed_salt)))
	var snow_pine: Array[Texture2D] = []
	for variant in 2:
		snow_pine.append(_tex(_tree_conifer_snow(variant, seed_salt)))
	props["oak"] = oak_names
	props["pine"] = pine_names
	props["snow_pine"] = snow_pine
	props["bush"] = _tex(_bush())
	props["boulder"] = _tex(_boulder())
	props["flowers"] = _tex(_flowers())
	props["tuft"] = _tex(_tuft())
	props["tower"] = _tex(_poi_tower())
	props["village"] = _tex(_poi_village())
	props["ruins"] = _tex(_poi_ruins())
	props["camp"] = _tex(_poi_camp())
	props["lighthouse"] = _tex(_poi_lighthouse())
	result["props"] = props
	return result


# ---------------------------------------------------------------------------
# 图集打包
# ---------------------------------------------------------------------------

static func _pack(entries: Array[Dictionary]) -> Dictionary:
	var cols := 16
	var rows := int(ceil(float(entries.size()) / float(cols)))
	var atlas := Image.create(cols * TS, rows * TS, false, Image.FORMAT_RGBA8)
	var coords: Dictionary = {}
	for index in entries.size():
		var coord := Vector2i(index % cols, index / cols)
		var image: Image = entries[index]["image"]
		atlas.blit_rect(image, Rect2i(0, 0, TS, TS), coord * TS)
		coords[entries[index]["name"]] = coord
	atlas.generate_mipmaps()
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = Vector2i(TS, TS)
	for key in coords:
		source.create_tile(coords[key])
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TS, TS)
	tileset.add_source(source, 0)
	return {"tileset": tileset, "coords": coords}


static func _coords_list(coords: Dictionary, names: Array[String]) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for name in names:
		list.append(coords[name])
	return list


static func _tex(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------------------
# 像素绘制基础
# ---------------------------------------------------------------------------

static func _blank() -> Image:
	return Image.create(TS, TS, false, Image.FORMAT_RGBA8)


static func _blank_size(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


static func _put(img: Image, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	if color.a <= 0.0:
		return
	var dst := img.get_pixel(x, y)
	var alpha := color.a + dst.a * (1.0 - color.a)
	if alpha <= 0.0001:
		return
	var rgb := Vector3(
		(color.r * color.a + dst.r * dst.a * (1.0 - color.a)) / alpha,
		(color.g * color.a + dst.g * dst.a * (1.0 - color.a)) / alpha,
		(color.b * color.a + dst.b * dst.a * (1.0 - color.a)) / alpha)
	img.set_pixel(x, y, Color(rgb.x, rgb.y, rgb.z, alpha))


static func _fill(img: Image, color: Color) -> void:
	for y in img.get_height():
		for x in img.get_width():
			img.set_pixel(x, y, color)


static func _wash(img: Image, c0: Color, c1: Color, salt: int, blotch := 5) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var fine := Utils.hash01(x, y, salt)
			var broad := Utils.hash01(x / blotch, y / blotch, salt + 17)
			var t := clampf(fine * 0.45 + broad * 0.75, 0.0, 1.0)
			img.set_pixel(x, y, c0.lerp(c1, t))


static func _disc(img: Image, cx: float, cy: float, radius: float, color: Color,
		feather := 1.0) -> void:
	var min_x := maxi(0, int(floor(cx - radius - feather)))
	var max_x := mini(img.get_width() - 1, int(ceil(cx + radius + feather)))
	var min_y := maxi(0, int(floor(cy - radius - feather)))
	var max_y := mini(img.get_height() - 1, int(ceil(cy + radius + feather)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var d := sqrt(pow(float(x) + 0.5 - cx, 2.0) + pow(float(y) + 0.5 - cy, 2.0))
			var a := clampf((radius - d) / maxf(0.001, feather), 0.0, 1.0)
			if a > 0.0:
				_put(img, x, y, Color(color.r, color.g, color.b, color.a * a))


static func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float,
		color: Color, feather := 1.0) -> void:
	var min_x := maxi(0, int(floor(cx - rx - feather)))
	var max_x := mini(img.get_width() - 1, int(ceil(cx + rx + feather)))
	var min_y := maxi(0, int(floor(cy - ry - feather)))
	var max_y := mini(img.get_height() - 1, int(ceil(cy + ry + feather)))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx := (float(x) + 0.5 - cx) / maxf(0.001, rx)
			var dy := (float(y) + 0.5 - cy) / maxf(0.001, ry)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf((1.0 - d) * minf(rx, ry) / maxf(0.001, feather), 0.0, 1.0)
			if a > 0.0:
				_put(img, x, y, Color(color.r, color.g, color.b, color.a * a))


static func _rect(img: Image, x0: int, y0: int, w: int, h: int, color: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_put(img, x, y, color)


static func _line(img: Image, x0: float, y0: float, x1: float, y1: float,
		width: float, color: Color) -> void:
	var length := maxf(1.0, Vector2(x1 - x0, y1 - y0).length())
	var steps := int(ceil(length * 1.5))
	for i in steps + 1:
		var t := float(i) / float(maxi(1, steps))
		var x := lerpf(x0, x1, t)
		var y := lerpf(y0, y1, t)
		_disc(img, x, y, width * 0.5, color, 0.8)


static func _triangle(img: Image, a: Vector2, b: Vector2, c: Vector2,
		color: Color, feather := 0.8) -> void:
	var min_x := maxi(0, int(floor(minf(a.x, minf(b.x, c.x))) - 1.0))
	var max_x := mini(img.get_width() - 1, int(ceil(maxf(a.x, maxf(b.x, c.x))) + 1.0))
	var min_y := maxi(0, int(floor(minf(a.y, minf(b.y, c.y))) - 1.0))
	var max_y := mini(img.get_height() - 1, int(ceil(maxf(a.y, maxf(b.y, c.y))) + 1.0))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var d := _triangle_distance(p, a, b, c)
			var alpha := clampf(0.5 + d / maxf(0.001, feather), 0.0, 1.0)
			if alpha > 0.0:
				_put(img, x, y, Color(color.r, color.g, color.b, color.a * alpha))


static func _triangle_distance(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	var ab := _edge_distance(p, a, b)
	var bc := _edge_distance(p, b, c)
	var ca := _edge_distance(p, c, a)
	var d1 := cross2(b - a, p - a)
	var d2 := cross2(c - b, p - b)
	var d3 := cross2(a - c, p - c)
	var has_neg := d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_pos := d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	var distance := minf(ab, minf(bc, ca))
	if has_neg and has_pos:
		return -distance
	return distance


static func _edge_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func cross2(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x


static func _speckles(img: Image, salt: int, color: Color, count: int,
		min_alpha := 0.35, max_alpha := 0.9) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for i in count:
		var x := int(Utils.hash01(i, 3, salt) * w)
		var y := int(Utils.hash01(i, 9, salt) * h)
		var a := lerpf(min_alpha, max_alpha, Utils.hash01(i, 13, salt))
		_put(img, x, y, Color(color.r, color.g, color.b, color.a * a))


static func _edge_fade(img: Image, mask: int, salt: int, depth := 3.0,
		dither := 0.24) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var dist := 999.0
			if (mask & N) == 0:
				dist = minf(dist, float(y) + 0.5)
			if (mask & E) == 0:
				dist = minf(dist, float(w - x) - 0.5)
			if (mask & S) == 0:
				dist = minf(dist, float(h - y) - 0.5)
			if (mask & W) == 0:
				dist = minf(dist, float(x) + 0.5)
			if dist > depth:
				continue
			var color := img.get_pixel(x, y)
			var fade := smoothstep(0.0, depth, dist)
			var a := color.a * clampf(fade * 1.15, 0.0, 1.0)
			if Utils.hash01(x, y, salt + 31) < dither:
				a *= 0.28
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))


# ---------------------------------------------------------------------------
# 地牢瓦片
# ---------------------------------------------------------------------------

static func _dungeon_floor(kind: String, variant: int, salt: int) -> Image:
	var img := _blank()
	var base := D_FLOOR
	var hi := D_FLOOR_HI
	var lo := D_FLOOR_LO
	if kind == "moss":
		base = D_FLOOR.lerp(D_MOSS, 0.28)
		hi = hi.lerp(D_MOSS, 0.25)
		lo = lo.lerp(D_MOSS, 0.2)
	elif kind == "wood":
		base = D_WOOD
		hi = D_WOOD_HI
		lo = Color("#4f3c29")
	elif kind == "gold":
		base = D_FLOOR.lerp(D_GOLD, 0.18)
		hi = D_FLOOR_HI.lerp(D_GOLD, 0.25)
		lo = D_FLOOR_LO
	_wash(img, lo, hi, salt + variant * 7, 4)
	# 石板缝：2×2 大石板，错缝 + 深色灰缝。
	var mortar := D_MORTAR
	for y in TS:
		for x in TS:
			var slab_w := 16
			var row := y / 16
			var offset := 8 if row % 2 == 1 else 0
			var local_x := posmod(x + offset, slab_w)
			var on_h := y % 16 == 0
			var on_v := local_x == 0
			if on_h or on_v:
				_put(img, x, y, Color(mortar.r, mortar.g, mortar.b, 0.72))
			elif y % 16 == 1 or local_x == 1:
				_put(img, x, y, Color(hi.r, hi.g, hi.b, 0.28))
	if kind == "wood":
		for y in TS:
			for x in TS:
				var plank := y / 8
				if y % 8 == 0 or posmod(x + plank * 5, 24) == 0:
					_put(img, x, y, Color(0.14, 0.1, 0.07, 0.55))
				elif y % 8 == 1:
					_put(img, x, y, Color(hi.r, hi.g, hi.b, 0.3))
	if kind == "moss":
		for i in 14:
			var cx := Utils.hash01(i, variant, salt + 3) * TS
			var cy := Utils.hash01(i, variant, salt + 5) * TS
			var r := 2.0 + Utils.hash01(i, variant, salt + 7) * 4.0
			_disc(img, cx, cy, r, Color(D_MOSS.r, D_MOSS.g, D_MOSS.b, 0.34), 1.2)
	if kind == "gold":
		for i in 10:
			var x := int(Utils.hash01(i, 4, salt + variant) * TS)
			var y := int(Utils.hash01(i, 8, salt + variant) * TS)
			_put(img, x, y, Color(D_GOLD.r, D_GOLD.g, D_GOLD.b, 0.55))
	# 碎石、裂纹、苔点。
	_speckles(img, salt + variant * 19, Color(0.16, 0.18, 0.16), 12, 0.15, 0.45)
	for i in 3:
		var x0 := Utils.hash01(i, variant, salt + 21) * TS
		var y0 := Utils.hash01(i, variant, salt + 23) * TS
		var x1 := clampf(x0 + (Utils.hash01(i, 2, salt) - 0.5) * 10.0, 1.0, TS - 2.0)
		var y1 := clampf(y0 + (Utils.hash01(i, 6, salt) - 0.5) * 10.0, 1.0, TS - 2.0)
		_line(img, x0, y0, x1, y1, 1.0, Color(0.12, 0.14, 0.13, 0.3))
	return img


static func _floor_shadow(mask: int, salt: int) -> Image:
	var img := _blank()
	for y in TS:
		for x in TS:
			var shadow := 0.0
			if (mask & N) != 0:
				shadow = maxf(shadow, 1.0 - float(y) / 4.5)
			if (mask & S) != 0:
				shadow = maxf(shadow, 1.0 - float(TS - 1 - y) / 4.5)
			if (mask & W) != 0:
				shadow = maxf(shadow, 1.0 - float(x) / 4.5)
			if (mask & E) != 0:
				shadow = maxf(shadow, 1.0 - float(TS - 1 - x) / 4.5)
			if shadow <= 0.0:
				continue
			var a := clampf(shadow, 0.0, 1.0) * 0.46
			a *= 0.75 + 0.25 * Utils.hash01(x, y, salt + 41)
			_put(img, x, y, Color(0.02, 0.04, 0.04, a))
	return img


static func _dungeon_wall(mask: int, variant: int, salt: int) -> Image:
	var img := _blank()
	_wash(img, Color("#334049"), Color("#48565c"), salt + variant * 13, 5)
	# 砖缝
	for y in TS:
		for x in TS:
			var row := y / 8
			var offset := 6 if row % 2 == 1 else 0
			if y % 8 == 0:
				_put(img, x, y, Color(0.08, 0.11, 0.12, 0.75))
			elif posmod(x + offset, 12) == 0:
				_put(img, x, y, Color(0.09, 0.12, 0.13, 0.55))
			elif y % 8 == 1:
				_put(img, x, y, Color(0.44, 0.51, 0.53, 0.18))
	_speckles(img, salt + variant * 31, Color(0.1, 0.13, 0.13), 18, 0.1, 0.4)
	if variant == 1:
		for i in 6:
			var cx := Utils.hash01(i, 5, salt) * TS
			var cy := Utils.hash01(i, 11, salt) * TS
			_disc(img, cx, cy, 2.0 + Utils.hash01(i, 7, salt) * 3.0,
					Color(D_MOSS.r, D_MOSS.g, D_MOSS.b, 0.22), 1.0)
	# 暴露边：亮顶/亮左，暗底/暗右。
	if (mask & N) == 0:
		_rect(img, 0, 0, TS, 3, Color(D_WALL_HI.r, D_WALL_HI.g, D_WALL_HI.b, 0.95))
		_rect(img, 0, 3, TS, 1, Color(0.68, 0.73, 0.7, 0.45))
		_rect(img, 0, 4, TS, 2, Color(0.05, 0.08, 0.09, 0.55))
	if (mask & W) == 0:
		_rect(img, 0, 0, 2, TS, Color(0.7, 0.76, 0.74, 0.7))
		_rect(img, 2, 0, 1, TS, Color(0.55, 0.62, 0.6, 0.35))
	if (mask & E) == 0:
		_rect(img, TS - 2, 0, 2, TS, Color(0.03, 0.06, 0.07, 0.82))
	if (mask & S) == 0:
		_rect(img, 0, TS - 3, TS, 3, Color(0.03, 0.06, 0.07, 0.86))
	# 外凸圆角。
	var corner_r := 4.0
	if (mask & N) == 0 and (mask & W) == 0:
		_corner_cut(img, 0, 0, corner_r)
	if (mask & N) == 0 and (mask & E) == 0:
		_corner_cut(img, TS - 1, 0, corner_r)
	if (mask & S) == 0 and (mask & W) == 0:
		_corner_cut(img, 0, TS - 1, corner_r)
	if (mask & S) == 0 and (mask & E) == 0:
		_corner_cut(img, TS - 1, TS - 1, corner_r)
	return img


static func _corner_cut(img: Image, cx: int, cy: int, radius: float) -> void:
	var dir_x := 1 if cx == 0 else -1
	var dir_y := 1 if cy == 0 else -1
	for y in TS:
		for x in TS:
			var dx := (x - cx) * dir_x
			var dy := (y - cy) * dir_y
			if dx < 0 or dy < 0:
				continue
			if Vector2(dx, dy).length() < radius:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


# ---------------------------------------------------------------------------
# 生物群系地形瓦片
# ---------------------------------------------------------------------------

static func _water_tile(depth: String, variant: int, salt: int) -> Image:
	var img := _blank()
	var c0 := B_DEEP
	var c1 := B_DEEP_HI
	var wave := Color(0.37, 0.63, 0.65, 0.35)
	if depth == "mid":
		c0 = B_MID
		c1 = B_MID_HI
		wave = Color(0.48, 0.76, 0.74, 0.4)
	elif depth == "shallow":
		c0 = B_SHALLOW
		c1 = B_SHALLOW_HI
		wave = Color(0.66, 0.9, 0.83, 0.5)
	_wash(img, c0, c1, salt + variant * 23, 6)
	# 波纹：短横向笔触 + 少量亮点。
	for i in 16:
		var x := Utils.hash01(i, variant, salt + 3) * TS
		var y := Utils.hash01(i, variant, salt + 7) * TS
		var length := 3.0 + Utils.hash01(i, variant, salt + 11) * 5.0
		var wobble := (Utils.hash01(i, variant, salt + 13) - 0.5) * 1.6
		_line(img, x, y, x + length, y + wobble, 1.0, wave)
	for i in 5:
		var x := int(Utils.hash01(i, 17, salt + variant) * TS)
		var y := int(Utils.hash01(i, 19, salt + variant) * TS)
		_put(img, x, y, Color(0.8, 0.94, 0.9, 0.5))
	# 深水更暗一点，浅水更亮。
	if depth == "deep":
		for y in TS:
			for x in TS:
				if Utils.hash01(x / 4, y / 4, salt + 29) < 0.22:
					_put(img, x, y, Color(0.02, 0.1, 0.12, 0.16))
	return img


static func _grass_tile(variant: int, salt: int) -> Image:
	var img := _blank()
	_wash(img, B_GRASS_LO, B_GRASS_HI, salt + variant * 17, 5)
	# 草叶
	for i in 22:
		var x := int(Utils.hash01(i, variant, salt + 3) * TS)
		var y := int(Utils.hash01(i, variant, salt + 5) * TS)
		var length := 2 + int(Utils.hash01(i, variant, salt + 7) * 3)
		var lean := 1 if Utils.hash01(i, variant, salt + 9) > 0.5 else -1
		for k in length:
			_put(img, x + (lean if k > 1 else 0), y - k,
					Color(B_GRASS_HI.r, B_GRASS_HI.g, B_GRASS_HI.b, 0.5))
	# 花/亮点
	for i in 3:
		var x := int(Utils.hash01(i, variant, salt + 21) * TS)
		var y := int(Utils.hash01(i, variant, salt + 27) * TS)
		var flower := Color("#f0df9e") if (i + variant) % 3 == 0 else Color("#d8b7a1")
		_put(img, x, y, flower)
		_put(img, x + 1, y, Color(flower.r, flower.g, flower.b, 0.6))
	# 少量暗斑让草地不完全平
	for i in 6:
		var x := Utils.hash01(i, variant, salt + 31) * TS
		var y := Utils.hash01(i, variant, salt + 33) * TS
		_disc(img, x, y, 2.0 + Utils.hash01(i, variant, salt + 37) * 2.5,
				Color(B_GRASS_LO.r, B_GRASS_LO.g, B_GRASS_LO.b, 0.25), 1.0)
	return img


static func _make_sand(mask: int, variant: int, salt: int) -> Image:
	var img := _blank()
	_wash(img, B_SAND_LO, B_SAND_HI, salt + variant * 19 + mask, 4)
	for i in 26:
		var x := int(Utils.hash01(i, variant, salt + 5) * TS)
		var y := int(Utils.hash01(i, variant, salt + 9) * TS)
		_put(img, x, y, Color(0.98, 0.92, 0.72, 0.35))
	# 海岸细沙纹理：浅浅的波纹线
	for i in 4:
		var y := int(Utils.hash01(i, variant, salt + 13) * TS)
		var x := Utils.hash01(i, variant, salt + 17) * TS
		_line(img, x, y, x + 7.0, y + 0.6, 1.0, Color(0.6, 0.5, 0.32, 0.22))
	_edge_fade(img, mask, salt + 43, 9.0, 0.4)
	return img


static func _make_forest(mask: int, variant: int, salt: int) -> Image:
	var img := _blank()
	var base := B_FOREST.lerp(B_FOREST_HI, Utils.hash01(variant, mask, salt) * 0.25)
	_fill(img, base)
	for i in 7:
		var cx := Utils.hash01(i, variant, salt + 3) * TS
		var cy := Utils.hash01(i, variant, salt + 7) * TS
		var r := 6.0 + Utils.hash01(i, variant, salt + 11) * 7.0
		_disc(img, cx, cy, r + 1.2, Color(B_FOREST_LO.r, B_FOREST_LO.g, B_FOREST_LO.b, 0.55), 1.4)
		_disc(img, cx - 0.7, cy - 0.9, r, Color(B_FOREST.r, B_FOREST.g, B_FOREST.b, 0.9), 1.2)
		_disc(img, cx - 2.0, cy - 2.2, r * 0.55,
				Color(B_FOREST_HI.r, B_FOREST_HI.g, B_FOREST_HI.b, 0.5), 1.0)
	for i in 22:
		var x := int(Utils.hash01(i, variant, salt + 13) * TS)
		var y := int(Utils.hash01(i, variant, salt + 17) * TS)
		_put(img, x, y, Color(0.58, 0.75, 0.51, 0.35))
	_edge_fade(img, mask, salt + 51, 10.0, 0.42)
	return img


static func _make_rock(mask: int, variant: int, salt: int) -> Image:
	var img := _blank()
	_wash(img, B_ROCK_LO, B_ROCK_HI, salt + mask * 3, 4)
	# 大块岩面 + 裂纹
	for i in 5:
		var cx := Utils.hash01(i, variant, salt + 5) * TS
		var cy := Utils.hash01(i, variant, salt + 7) * TS
		var rx := 5.0 + Utils.hash01(i, variant, salt + 9) * 6.0
		var ry := 4.0 + Utils.hash01(i, variant, salt + 11) * 5.0
		_ellipse(img, cx, cy, rx, ry, Color(B_ROCK.r, B_ROCK.g, B_ROCK.b, 0.55), 1.2)
		_ellipse(img, cx - 1.4, cy - 1.6, rx * 0.62, ry * 0.5,
				Color(B_ROCK_HI.r, B_ROCK_HI.g, B_ROCK_HI.b, 0.35), 1.0)
	for i in 4:
		var x0 := Utils.hash01(i, variant, salt + 19) * TS
		var y0 := Utils.hash01(i, variant, salt + 23) * TS
		_line(img, x0, y0, x0 + 5.0, y0 + 3.5, 1.0, Color(0.25, 0.29, 0.28, 0.5))
	_edge_fade(img, mask, salt + 57, 9.0, 0.42)
	return img


static func _make_snow(mask: int, variant: int, salt: int) -> Image:
	var img := _blank()
	_wash(img, B_SNOW_LO, B_SNOW_HI, salt + mask * 5, 5)
	for i in 7:
		var cx := Utils.hash01(i, variant, salt + 7) * TS
		var cy := Utils.hash01(i, variant, salt + 11) * TS
		var rx := 4.0 + Utils.hash01(i, variant, salt + 13) * 6.0
		_ellipse(img, cx, cy, rx, rx * 0.55,
				Color(B_SNOW_HI.r, B_SNOW_HI.g, B_SNOW_HI.b, 0.55), 1.2)
		_ellipse(img, cx + 1.5, cy + 2.0, rx * 0.7, rx * 0.3,
				Color(0.72, 0.82, 0.83, 0.22), 1.0)
	for i in 10:
		var x := int(Utils.hash01(i, variant, salt + 17) * TS)
		var y := int(Utils.hash01(i, variant, salt + 19) * TS)
		_put(img, x, y, Color(1, 1, 1, 0.6))
	for i in 7:
		var x := int(Utils.hash01(i, variant, salt + 23) * TS)
		var y := int(Utils.hash01(i, variant, salt + 29) * TS)
		_put(img, x, y, Color(0.52, 0.58, 0.57, 0.3))
		_put(img, x + 1, y, Color(0.62, 0.68, 0.67, 0.18))
	for i in 4:
		var y := 5.0 + Utils.hash01(i, variant, salt + 33) * 22.0
		var x := Utils.hash01(i, variant, salt + 37) * 20.0
		_line(img, x, y, x + 8.0, y + (Utils.hash01(i, variant, salt + 39) - 0.5) * 2.0,
				1.0, Color(0.63, 0.75, 0.76, 0.25))
	_edge_fade(img, mask, salt + 61, 9.0, 0.4)
	return img


static func _coast_foam(mask: int, salt: int) -> Image:
	var img := _blank()
	var foam := B_FOAM
	for y in TS:
		for x in TS:
			var d := 999.0
			if (mask & N) != 0:
				d = minf(d, float(y))
			if (mask & S) != 0:
				d = minf(d, float(TS - 1 - y))
			if (mask & W) != 0:
				d = minf(d, float(x))
			if (mask & E) != 0:
				d = minf(d, float(TS - 1 - x))
			if d > 7.0:
				continue
			var n := Utils.hash01(x, y, salt + mask * 7)
			if d > 2.0 and d < 6.0:
				_put(img, x, y, Color(0.17, 0.46, 0.47, 0.32 * (1.0 - d / 7.0)))
			var a := (1.0 - d / 8.0) * 0.95
			if d < 2.0:
				a = 1.0
			elif n < 0.24:
				a *= 0.2
			elif n > 0.86:
				a = minf(1.0, a + 0.2)
			_put(img, x, y, Color(0.94, 0.99, 0.94, a))
	# 外侧细浪线
	if (mask & N) != 0:
		_line(img, 2.0, 2.6, TS - 2.0, 2.6, 0.9, Color(foam.r, foam.g, foam.b, 0.5))
	if (mask & S) != 0:
		_line(img, 2.0, TS - 3.6, TS - 2.0, TS - 3.6, 0.9, Color(foam.r, foam.g, foam.b, 0.5))
	if (mask & W) != 0:
		_line(img, 2.6, 2.0, 2.6, TS - 2.0, 0.9, Color(foam.r, foam.g, foam.b, 0.5))
	if (mask & E) != 0:
		_line(img, TS - 3.6, 2.0, TS - 3.6, TS - 2.0, 0.9, Color(foam.r, foam.g, foam.b, 0.5))
	return img


static func _river_tile(mask: int, salt: int) -> Image:
	var img := _blank()
	var center := Vector2(TS * 0.5, TS * 0.5)
	var points: Array[Vector2] = []
	if (mask & N) != 0:
		points.append(Vector2(TS * 0.5, 0.0))
	if (mask & E) != 0:
		points.append(Vector2(TS, TS * 0.5))
	if (mask & S) != 0:
		points.append(Vector2(TS * 0.5, TS))
	if (mask & W) != 0:
		points.append(Vector2(0.0, TS * 0.5))
	if points.is_empty():
		points.append(center + Vector2(TS, 0))
	# 宽水带：中心 + 到各连接口
	var width := 17.0
	_disc(img, center.x, center.y, width * 0.62, Color(B_RIVER.r, B_RIVER.g, B_RIVER.b, 1.0), 2.0)
	for p in points:
		_line(img, center.x, center.y, p.x, p.y, width, Color(B_RIVER.r, B_RIVER.g, B_RIVER.b, 1.0))
	# 水色层次
	_disc(img, center.x, center.y, width * 0.4, Color(B_RIVER.r, B_RIVER.g, B_RIVER.b, 0.55), 2.5)
	for i in 6:
		var t := Utils.hash01(i, mask, salt + 3)
		var p := center.lerp(points[i % points.size()], t)
		_put(img, int(p.x), int(p.y), Color(B_RIVER_HI.r, B_RIVER_HI.g, B_RIVER_HI.b, 0.7))
	# 边缘浅色水光
	for i in 10:
		var angle := Utils.hash01(i, mask, salt + 9) * TAU
		var r := width * (0.34 + Utils.hash01(i, mask, salt + 11) * 0.2)
		var x := int(center.x + cos(angle) * r)
		var y := int(center.y + sin(angle) * r)
		_put(img, x, y, Color(0.75, 0.93, 0.88, 0.4))
	return img


# ---------------------------------------------------------------------------
# 地牢道具
# ---------------------------------------------------------------------------

static func _torch() -> Image:
	var img := _blank_size(18, 32)
	_ellipse(img, 9.0, 29.0, 5.0, 2.0, Color(0, 0, 0, 0.28), 1.0)
	_rect(img, 7, 16, 4, 13, Color("#5c4229"))
	_rect(img, 7, 16, 1, 13, Color("#7c5a39"))
	_rect(img, 4, 13, 10, 3, Color("#3c3a33"))
	_disc(img, 9.0, 11.5, 3.8, Color("#d9663c"), 1.2)
	_disc(img, 9.0, 10.5, 2.8, Color("#f2a64b"), 1.0)
	_disc(img, 9.0, 9.5, 1.7, Color("#ffe3a1"), 0.8)
	_put(img, 9, 4, Color("#ffd27a", 0.8))
	_put(img, 8, 5, Color("#ffd27a", 0.5))
	return img


static func _crate() -> Image:
	var img := _blank_size(22, 22)
	_ellipse(img, 11.0, 19.5, 8.0, 2.2, Color(0, 0, 0, 0.28))
	_rect(img, 2, 4, 18, 15, Color("#6d5236"))
	_rect(img, 2, 4, 18, 2, Color("#8a6a47"))
	_rect(img, 2, 17, 18, 2, Color("#4c3926"))
	_line(img, 3, 5, 19, 18, 1.4, Color("#4b3724"))
	_line(img, 19, 5, 3, 18, 1.4, Color("#4b3724"))
	_rect(img, 9, 4, 3, 15, Color("#7d5f3f"))
	return img


static func _barrel() -> Image:
	var img := _blank_size(18, 24)
	_ellipse(img, 9.0, 21.5, 7.0, 2.0, Color(0, 0, 0, 0.28))
	_ellipse(img, 9.0, 12.0, 7.0, 9.0, Color("#6b4d31"), 1.0)
	_rect(img, 4, 5, 10, 14, Color("#775738"))
	_rect(img, 5, 5, 2, 14, Color("#936e48"))
	_rect(img, 3, 8, 12, 2, Color("#37322b"))
	_rect(img, 3, 15, 12, 2, Color("#37322b"))
	_ellipse(img, 9.0, 5.0, 5.0, 2.0, Color("#4f3a26"), 0.8)
	return img


static func _chest() -> Image:
	var img := _blank_size(26, 22)
	_ellipse(img, 13.0, 19.5, 10.0, 2.2, Color(0, 0, 0, 0.3))
	_rect(img, 2, 8, 22, 10, Color("#5e432a"))
	_rect(img, 2, 8, 22, 2, Color("#8b673f"))
	_ellipse(img, 13.0, 8.0, 11.0, 4.0, Color("#6d4e30"), 1.0)
	_rect(img, 2, 11, 22, 2, Color(D_GOLD))
	_rect(img, 11, 10, 4, 6, Color("#d8b76a"))
	_put(img, 13, 12, Color("#4b3522"))
	return img


static func _table() -> Image:
	var img := _blank_size(32, 26)
	_ellipse(img, 16.0, 23.0, 12.0, 2.4, Color(0, 0, 0, 0.28))
	_rect(img, 3, 8, 26, 8, Color("#6c4f33"))
	_rect(img, 3, 8, 26, 2, Color("#8b6a46"))
	_rect(img, 5, 16, 3, 8, Color("#4d3824"))
	_rect(img, 24, 16, 3, 8, Color("#4d3824"))
	_rect(img, 9, 10, 5, 4, Color("#b8944e"))
	_rect(img, 16, 11, 3, 3, Color("#a9d6a8"))
	return img


static func _bones() -> Image:
	var img := _blank_size(22, 14)
	_line(img, 3, 10, 12, 6, 2.0, Color("#d8d3b8", 0.8))
	_line(img, 9, 11, 18, 8, 2.0, Color("#c7c2a7", 0.8))
	_disc(img, 3.0, 10.0, 2.0, Color("#e2ddc2", 0.9), 0.8)
	_disc(img, 18.0, 8.0, 2.0, Color("#e2ddc2", 0.9), 0.8)
	_disc(img, 12.0, 4.5, 2.5, Color("#d9d4ba", 0.85), 1.0)
	_put(img, 11, 4, Color(0.2, 0.2, 0.18, 0.8))
	_put(img, 13, 4, Color(0.2, 0.2, 0.18, 0.8))
	return img


static func _mushrooms() -> Image:
	var img := _blank_size(22, 16)
	for i in 4:
		var x := 3.0 + i * 4.5
		var y := 11.0 - (i % 2) * 2.0
		_rect(img, int(x), int(y), 1, 3, Color("#d9d2b8"))
		_disc(img, x + 0.5, y - 0.5, 2.6, Color("#9c6a63"), 0.8)
		_disc(img, x - 0.3, y - 1.2, 0.9, Color("#e0b9a5"), 0.5)
	return img


static func _pillar() -> Image:
	var img := _blank_size(24, 40)
	_ellipse(img, 12.0, 37.0, 9.0, 2.5, Color(0, 0, 0, 0.3))
	_rect(img, 4, 6, 16, 29, Color("#5a645f"))
	_rect(img, 4, 6, 4, 29, Color("#7c857d"))
	_rect(img, 16, 6, 4, 29, Color("#3c4643"))
	_rect(img, 2, 2, 20, 5, Color("#6e766e"))
	_rect(img, 2, 34, 20, 4, Color("#414b47"))
	for i in 5:
		_line(img, 5, 10.0 + i * 5.0, 19, 12.0 + i * 5.0, 0.8,
				Color(0.25, 0.3, 0.28, 0.45))
	return img


static func _start_rune() -> Image:
	var img := _blank_size(36, 36)
	_ellipse(img, 18.0, 27.0, 13.0, 5.0, Color(0, 0, 0, 0.3))
	for i in 24:
		var angle := float(i) / 24.0 * TAU
		var r := 12.0
		_put(img, int(18.0 + cos(angle) * r), int(18.0 + sin(angle) * r),
				Color(0.55, 0.86, 0.78, 0.8))
	for i in 8:
		var angle := float(i) / 8.0 * TAU
		_line(img, 18.0, 18.0, 18.0 + cos(angle) * 9.0, 18.0 + sin(angle) * 9.0,
				0.9, Color(0.48, 0.8, 0.72, 0.55))
	_disc(img, 18.0, 18.0, 4.0, Color(0.6, 0.9, 0.8, 0.35), 2.0)
	return img


static func _exit_stairs() -> Image:
	var img := _blank_size(36, 36)
	_ellipse(img, 18.0, 28.0, 14.0, 5.0, Color(0, 0, 0, 0.35))
	_rect(img, 4, 10, 28, 20, Color("#293034"))
	_rect(img, 4, 10, 28, 2, Color("#59635f"))
	for i in 4:
		var y := 13 + i * 4
		_rect(img, 6 + i, y, 24 - i * 2, 4, Color("#3e494b").lerp(Color("#141a1d"), float(i) / 4.0))
	_put(img, 18, 8, Color("#e4b96f", 0.8))
	return img


static func _rug(variant: int) -> Image:
	var img := _blank_size(96, 64)
	var base := Color("#8e4740") if variant == 0 else Color("#3f6260")
	var border := Color("#c9a45e") if variant == 0 else Color("#9fd6bd")
	_rect(img, 2, 2, 92, 60, Color(0.05, 0.06, 0.06, 0.32))
	_rect(img, 4, 4, 88, 56, base)
	_rect(img, 4, 4, 88, 4, border)
	_rect(img, 4, 56, 88, 4, border)
	_rect(img, 4, 4, 4, 56, border)
	_rect(img, 88, 4, 4, 56, border)
	for i in 6:
		_rect(img, 12 + i * 13, 14, 6, 36, Color(base.r, base.g, base.b, 0.8).lerp(border, 0.25))
		_disc(img, 15.0 + i * 13.0, 32.0, 2.0, border, 0.7)
		_put(img, 15 + i * 13, 20, Color(border.r, border.g, border.b, 0.4))
	return img


# ---------------------------------------------------------------------------
# 生物群系装饰
# ---------------------------------------------------------------------------

static func _tree_broadleaf(variant: int, salt: int) -> Image:
	var img := _blank_size(44, 50)
	_ellipse(img, 22.0, 45.0, 13.0, 4.0, Color(0.02, 0.06, 0.04, 0.28), 1.0)
	_rect(img, 20, 30, 4, 16, Color("#5b4630"))
	_rect(img, 20, 30, 1, 16, Color("#785c3e"))
	var offset := Vector2(Utils.hash01(variant, 1, salt) * 3.0 - 1.5,
			Utils.hash01(variant, 2, salt) * 2.0 - 1.0)
	_disc(img, 22.0 + offset.x, 21.0 + offset.y, 14.0,
			Color(0.14, 0.24, 0.16, 0.9), 1.5)
	for i in 5:
		var a := float(i) / 5.0 * TAU + variant * 0.7
		var cx := 22.0 + offset.x + cos(a) * (4.0 + Utils.hash01(i, variant, salt) * 3.0)
		var cy := 20.0 + offset.y + sin(a) * (3.0 + Utils.hash01(i, variant, salt + 3) * 2.5)
		var r := 7.5 + Utils.hash01(i, variant, salt + 5) * 3.5
		_disc(img, cx, cy, r, Color(B_FOREST.r, B_FOREST.g, B_FOREST.b, 0.95), 1.6)
	for i in 6:
		var cx := 16.0 + Utils.hash01(i, variant, salt + 7) * 12.0
		var cy := 14.0 + Utils.hash01(i, variant, salt + 9) * 9.0
		_disc(img, cx, cy, 4.0 + Utils.hash01(i, variant, salt + 11) * 3.0,
				Color(B_FOREST_HI.r, B_FOREST_HI.g, B_FOREST_HI.b, 0.35), 1.2)
	for i in 10:
		var x := 12.0 + Utils.hash01(i, variant, salt + 13) * 20.0
		var y := 12.0 + Utils.hash01(i, variant, salt + 17) * 20.0
		_put(img, int(x), int(y), Color(0.68, 0.84, 0.58, 0.35))
	return img


static func _tree_conifer(variant: int, salt: int) -> Image:
	var img := _blank_size(34, 52)
	_ellipse(img, 17.0, 47.5, 9.0, 3.0, Color(0.02, 0.06, 0.05, 0.3), 1.0)
	_rect(img, 15, 32, 4, 15, Color("#51402d"))
	var top := 4.0 + Utils.hash01(variant, 1, salt) * 3.0
	for layer in 4:
		var y0 := top + layer * 8.5
		var half := 5.0 + layer * 2.6
		_triangle(img, Vector2(17.0, y0), Vector2(17.0 - half, y0 + 12.0),
				Vector2(17.0 + half, y0 + 12.0), Color("#31553a"), 1.0)
		_triangle(img, Vector2(16.4, y0 + 1.0), Vector2(17.0 - half * 0.72, y0 + 10.0),
				Vector2(17.0 + half * 0.5, y0 + 10.0), Color("#477347"), 0.9)
		_line(img, 17.0 - half * 0.6, y0 + 9.0, 17.0 + half * 0.6, y0 + 9.0,
				0.7, Color(0.2, 0.34, 0.23, 0.5))
	return img


static func _tree_conifer_snow(variant: int, salt: int) -> Image:
	var img := _tree_conifer(variant, salt + 101)
	for layer in 4:
		var y0 := 4.0 + variant * 2.0 + layer * 8.5
		var half := 5.0 + layer * 2.6
		_line(img, 17.0 - half * 0.7, y0 + 4.0, 17.0 + half * 0.7, y0 + 4.0,
				1.8, Color(0.9, 0.95, 0.95, 0.75))
		_disc(img, 12.0 + Utils.hash01(layer, variant, salt) * 10.0,
				y0 + 8.0, 1.6, Color(0.95, 0.98, 0.97, 0.7), 0.7)
	return img


static func _bush() -> Image:
	var img := _blank_size(26, 20)
	_ellipse(img, 13.0, 17.0, 8.0, 2.5, Color(0.02, 0.06, 0.04, 0.25))
	for i in 4:
		_disc(img, 8.0 + i * 3.4, 10.0 - (i % 2) * 1.5, 5.2,
				Color(B_FOREST.r, B_FOREST.g, B_FOREST.b, 0.95), 1.0)
	for i in 3:
		_disc(img, 9.0 + i * 4.0, 8.5, 2.0,
				Color(B_FOREST_HI.r, B_FOREST_HI.g, B_FOREST_HI.b, 0.55), 0.8)
	_put(img, 17, 7, Color(0.9, 0.7, 0.55, 0.8))
	return img


static func _boulder() -> Image:
	var img := _blank_size(30, 22)
	_ellipse(img, 15.0, 19.0, 10.0, 2.6, Color(0.02, 0.05, 0.05, 0.28))
	_ellipse(img, 15.0, 12.0, 10.0, 7.5, Color(B_ROCK_LO.r, B_ROCK_LO.g, B_ROCK_LO.b, 0.95), 1.2)
	_ellipse(img, 14.0, 10.0, 7.5, 5.2, Color(B_ROCK.r, B_ROCK.g, B_ROCK.b, 0.95), 1.0)
	_ellipse(img, 12.0, 8.0, 4.2, 2.6, Color(B_ROCK_HI.r, B_ROCK_HI.g, B_ROCK_HI.b, 0.55), 1.0)
	_line(img, 17.0, 9.0, 21.0, 15.0, 0.8, Color(0.25, 0.3, 0.29, 0.45))
	return img


static func _flowers() -> Image:
	var img := _blank_size(20, 14)
	var colors := [Color("#f0df9e"), Color("#d8a7a0"), Color("#b8d8e8")]
	for i in 6:
		var x := 3.0 + Utils.hash01(i, 1, 907) * 14.0
		var y := 4.0 + Utils.hash01(i, 2, 907) * 7.0
		_disc(img, x, y, 1.4, colors[i % colors.size()], 0.6)
		_put(img, int(x), int(y + 2), Color(0.3, 0.45, 0.24, 0.7))
	return img


static func _tuft() -> Image:
	var img := _blank_size(18, 14)
	for i in 5:
		var x := 4.0 + i * 2.4
		var y := 12.0 - Utils.hash01(i, 1, 313) * 4.0
		_line(img, x, 12.0, x + (i - 2) * 0.8, y, 0.8, Color(0.38, 0.55, 0.29, 0.8))
	return img


# ---------------------------------------------------------------------------
# POI 地标
# ---------------------------------------------------------------------------

static func _poi_tower() -> Image:
	var img := _blank_size(46, 60)
	_ellipse(img, 23.0, 55.0, 15.0, 4.5, Color(0, 0, 0, 0.3))
	_rect(img, 13, 26, 20, 29, Color("#6f746c"))
	_rect(img, 13, 26, 5, 29, Color("#8e9287"))
	_rect(img, 28, 26, 5, 29, Color("#4d534e"))
	_rect(img, 10, 22, 26, 6, Color("#83887d"))
	for i in 4:
		_rect(img, 11 + i * 6, 16, 4, 7, Color("#6f746c"))
		_rect(img, 11 + i * 6, 16, 4, 2, Color("#9a9e91"))
	_rect(img, 16, 32, 5, 8, Color("#2d3432"))
	_rect(img, 16, 32, 5, 2, Color("#e4b96f"))
	_disc(img, 18.5, 39.0, 1.4, Color(1.0, 0.84, 0.45, 0.8), 0.6)
	_line(img, 23.0, 16.0, 23.0, 4.0, 1.0, Color("#4b3d2c"))
	_rect(img, 24, 6, 9, 5, Color("#a34e44"))
	_rect(img, 24, 6, 9, 1, Color("#d07463"))
	return img


static func _poi_village() -> Image:
	var img := _blank_size(62, 46)
	_ellipse(img, 31.0, 41.0, 24.0, 4.0, Color(0, 0, 0, 0.28))
	_house(img, 8, 20, 18, 18, Color("#b77452"), Color("#d7a06f"))
	_house(img, 27, 24, 16, 16, Color("#8d5b45"), Color("#c08a63"))
	_house(img, 43, 18, 14, 14, Color("#a35d4c"), Color("#d18e6a"))
	_line(img, 14.0, 42.0, 30.0, 34.0, 2.4, Color(0.45, 0.37, 0.25, 0.55))
	_line(img, 45.0, 42.0, 37.0, 35.0, 2.0, Color(0.45, 0.37, 0.25, 0.5))
	_disc(img, 31.0, 34.0, 3.0, Color(0.95, 0.77, 0.4, 0.25), 1.5)
	return img


static func _house(img: Image, x: float, y: float, w: float, h: float,
		roof: Color, roof_hi: Color) -> void:
	_rect(img, int(x), int(y + h * 0.4), int(w), int(h * 0.6), Color("#d7c9a9"))
	_rect(img, int(x), int(y + h * 0.4), int(w * 0.25), int(h * 0.6), Color("#e9dfc4"))
	_triangle(img, Vector2(x - 2.0, y + h * 0.44), Vector2(x + w * 0.5, y),
			Vector2(x + w + 2.0, y + h * 0.44), roof, 0.9)
	_triangle(img, Vector2(x, y + h * 0.4), Vector2(x + w * 0.5, y + 1.5),
			Vector2(x + w * 0.52, y + h * 0.4), roof_hi, 0.7)
	_rect(img, int(x + w * 0.42), int(y + h * 0.62), maxi(2, int(w * 0.16)),
			maxi(2, int(h * 0.38)), Color("#4b3b2a"))
	_rect(img, int(x + w * 0.15), int(y + h * 0.56), maxi(2, int(w * 0.16)),
			maxi(2, int(h * 0.16)), Color("#f0d38c"))
	_put(img, int(x + w * 0.2), int(y + h * 0.6), Color("#e4b96f"))


static func _poi_ruins() -> Image:
	var img := _blank_size(52, 42)
	_ellipse(img, 26.0, 37.0, 20.0, 4.0, Color(0, 0, 0, 0.28))
	for i in 3:
		var x := 8 + i * 13
		var h := 14 + (i % 2) * 8
		_rect(img, x, 36 - h, 7, h, Color("#777c74"))
		_rect(img, x, 36 - h, 2, h, Color("#95998e"))
		_rect(img, x - 1, 36 - h, 9, 3, Color("#61675f"))
		if i == 1:
			_rect(img, x + 1, 36 - h - 5, 5, 4, Color("#5b6058"))
	_rect(img, 12, 15, 28, 4, Color("#6f746c"))
	_rect(img, 12, 15, 28, 1, Color("#92968b"))
	_rect(img, 5, 34, 41, 4, Color("#5e645c"))
	for i in 5:
		_put(img, 10 + i * 7, 29 + (i % 3) * 2, Color("#a0a296", 0.6))
	_line(img, 36.0, 20.0, 43.0, 36.0, 2.0, Color("#5c6259", 0.8))
	return img


static func _poi_camp() -> Image:
	var img := _blank_size(54, 36)
	_ellipse(img, 27.0, 32.0, 22.0, 3.5, Color(0, 0, 0, 0.26))
	_triangle(img, Vector2(10.0, 32.0), Vector2(19.0, 12.0), Vector2(28.0, 32.0),
			Color("#d2b98a"), 1.0)
	_triangle(img, Vector2(13.0, 32.0), Vector2(19.0, 16.0), Vector2(25.0, 32.0),
			Color("#b89a6c"), 0.8)
	_triangle(img, Vector2(30.0, 32.0), Vector2(38.0, 16.0), Vector2(46.0, 32.0),
			Color("#c6a87b"), 1.0)
	_disc(img, 19.0, 33.0, 3.0, Color(0.97, 0.64, 0.3, 0.4), 2.0)
	_disc(img, 19.0, 32.0, 1.6, Color("#ffd27a"), 0.8)
	_disc(img, 19.0, 32.0, 3.4, Color(1.0, 0.7, 0.35, 0.3), 2.2)
	_rect(img, 24, 28, 24, 1, Color(0.35, 0.27, 0.18, 0.5))
	return img


static func _poi_lighthouse() -> Image:
	var img := _blank_size(36, 66)
	_ellipse(img, 18.0, 61.0, 12.0, 4.0, Color(0, 0, 0, 0.3))
	_rect(img, 10, 58, 16, 4, Color("#666b63"))
	var body := Color("#ece4d1")
	var stripe := Color("#a24e44")
	for i in 7:
		var y := 24 + i * 5
		var w := 12 - i
		_rect(img, 18 - w / 2, y, w, 5, body if i % 2 == 0 else stripe)
	_rect(img, 10, 20, 16, 4, Color("#3c4643"))
	_rect(img, 13, 12, 10, 8, Color("#f4e7c1"))
	_rect(img, 13, 12, 10, 2, Color("#4b4234"))
	_disc(img, 18.0, 16.0, 2.4, Color(1.0, 0.88, 0.56, 0.9), 0.8)
	_triangle(img, Vector2(9.0, 12.0), Vector2(18.0, 3.0), Vector2(27.0, 12.0),
			Color("#8e4b42"), 0.9)
	_line(img, 18.0, 2.0, 18.0, 0.0, 0.8, Color("#463a2c"))
	return img
