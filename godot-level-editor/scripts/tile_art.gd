class_name TileArt
extends RefCounted

# 运行时生成的原创 16×16 像素瓦片与实体图标。
# 自动瓦片的视觉完全由连接掩码（北/东/南/西）决定，
# 所以绘制规则、保存的 mask 与画面三者是一致的。

const SIZE := 16

const C_GRASS_A := Color("#5c8a4b")
const C_GRASS_B := Color("#537d43")
const C_GRASS_C := Color("#6b9a56")
const C_GRASS_DARK := Color("#35502c")
const C_GRASS_LIGHT := Color("#87b267")
const C_DIRT_A := Color("#8a6547")
const C_DIRT_B := Color("#7d5a3e")
const C_DIRT_C := Color("#997454")
const C_DIRT_DARK := Color("#59402f")
const C_DIRT_LIGHT := Color("#b08a63")
const C_WALL_MORTAR := Color("#43433f")
const C_WALL_A := Color("#75746e")
const C_WALL_B := Color("#686761")
const C_WALL_LIGHT := Color("#8e8c83")
const C_WALL_DARK := Color("#252823")
const C_MOSS := Color("#5d7d49")
const C_WATER_A := Color("#315774")
const C_WATER_B := Color("#3b6a8b")
const C_WATER_C := Color("#4a7c9c")
const C_WATER_LIGHT := Color("#79a3b8")
const C_FOAM := Color("#cfe2df")
const C_INK := Color("#1a2025")

static var _cache: Dictionary = {}


static func tile_texture(type: String, mask: int, variant: int = -1) -> Texture2D:
	var key := "%s|%d|%d" % [type, mask, variant]
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match type:
		"grass":
			_base_grass(img)
			if variant >= 0:
				_decorate_grass(img, variant)
			else:
				_edge_grass(img, mask)
		"dirt":
			_base_dirt(img)
			if variant >= 0:
				_decorate_dirt(img, variant)
			else:
				_edge_dirt(img, mask)
		"wall":
			_base_wall(img)
			if variant >= 0:
				_decorate_wall(img, variant)
			else:
				_edge_wall(img, mask)
		"water":
			_base_water(img)
			if variant >= 0:
				_decorate_water(img, variant)
			else:
				_edge_water(img, mask)
		_:
			img.fill(C_GRASS_A)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func palette_texture(type: String) -> Texture2D:
	return tile_texture(type, 5, -1)


static func icon_texture(kind: String, px: int = 32) -> Texture2D:
	var key := "icon|%s|%d" % [kind, px]
	if _cache.has(key):
		return _cache[key]
	var source: Texture2D = entity_texture(kind) if kind in ["spawn", "enemy", "chest"] else palette_texture(kind)
	var img := source.get_image()
	if img == null:
		return source
	img = img.duplicate()
	img.resize(px, px, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func entity_texture(type: String) -> Texture2D:
	var key := "entity|" + type
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match type:
		"spawn":
			_draw_spawn(img)
		"enemy":
			_draw_enemy(img)
		"chest":
			_draw_chest(img)
		_:
			_draw_marker(img, Color("#e8b36a"))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func player_texture(facing: String) -> Texture2D:
	var key := "player|" + facing
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(16, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_draw_player(img, facing)
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


static func _px(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, color)


static func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, color)


static func _hash(x: int, y: int, salt: int) -> float:
	var n := int(x) * 374761393 + int(y) * 668265263 + int(salt) * 1442695041
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(absi(n) & 0xffff) / 65535.0


# ---------------- 草地 ----------------

static func _base_grass(img: Image) -> void:
	for y in SIZE:
		for x in SIZE:
			var h := _hash(x, y, 3)
			var c := C_GRASS_A
			if h < 0.24:
				c = C_GRASS_B
			elif h > 0.82:
				c = C_GRASS_C
			_px(img, x, y, c)
	for i in 6:
		var x := 2 + int(_hash(i, 1, 11) * 12.0)
		var y := 2 + int(_hash(i, 2, 13) * 11.0)
		_px(img, x, y, C_GRASS_LIGHT)
		_px(img, x, y - 1, C_GRASS_C)
		_px(img, x + 1, y, C_GRASS_DARK)


static func _edge_grass(img: Image, mask: int) -> void:
	if (mask & 1) == 0:
		for x in SIZE:
			_px(img, x, 0, C_GRASS_DARK)
			if x % 3 != 1:
				_px(img, x, 1, C_GRASS_B)
		for i in 4:
			var x := 1 + int(_hash(i, 5, 3) * 13.0)
			_px(img, x, 0, C_GRASS_LIGHT)
			_px(img, x, 1, C_GRASS_LIGHT)
	if (mask & 4) == 0:
		for x in SIZE:
			_px(img, x, 15, C_GRASS_DARK)
		for i in 3:
			var x := 1 + int(_hash(i, 6, 5) * 13.0)
			_px(img, x, 14, C_GRASS_B)
			_px(img, x, 13, C_GRASS_DARK)
	if (mask & 8) == 0:
		for y in SIZE:
			_px(img, 0, y, C_GRASS_DARK)
	if (mask & 2) == 0:
		for y in SIZE:
			_px(img, 15, y, C_GRASS_DARK)


static func _decorate_grass(img: Image, variant: int) -> void:
	match variant:
		0:
			pass
		1:
			for spot in [Vector2i(4, 5), Vector2i(11, 10)]:
				_px(img, spot.x, spot.y, Color("#e7cd79"))
				_px(img, spot.x + 1, spot.y, Color("#e7cd79"))
				_px(img, spot.x, spot.y + 1, Color("#d8845f"))
				_px(img, spot.x + 1, spot.y + 1, Color("#f1df9b"))
				_px(img, spot.x, spot.y + 2, C_GRASS_DARK)
			_px(img, 8, 3, C_GRASS_LIGHT)
			_px(img, 8, 4, C_GRASS_C)
		2:
			for i in 6:
				var x := 2 + int(_hash(i, 7, 17) * 12.0)
				var y := 4 + int(_hash(i, 8, 19) * 9.0)
				_px(img, x, y, C_GRASS_DARK)
				_px(img, x, y - 1, C_GRASS_DARK)
				_px(img, x + 1, y, C_GRASS_LIGHT)
			_px(img, 3, 12, Color("#8fae63"))
			_px(img, 4, 12, Color("#8fae63"))


# ---------------- 泥土 ----------------

static func _base_dirt(img: Image) -> void:
	for y in SIZE:
		for x in SIZE:
			var h := _hash(x, y, 23)
			var c := C_DIRT_A
			if h < 0.27:
				c = C_DIRT_B
			elif h > 0.84:
				c = C_DIRT_C
			_px(img, x, y, c)
	for spot in [Vector2i(3, 4), Vector2i(11, 3), Vector2i(7, 11), Vector2i(13, 13)]:
		_px(img, spot.x, spot.y, C_DIRT_LIGHT)
		_px(img, spot.x + 1, spot.y, C_DIRT_B)
		_px(img, spot.x, spot.y + 1, C_DIRT_DARK)


static func _edge_dirt(img: Image, mask: int) -> void:
	if (mask & 1) == 0:
		for x in SIZE:
			_px(img, x, 0, C_DIRT_DARK)
	else:
		for x in range(0, SIZE, 3):
			_px(img, x, 0, C_DIRT_C)
	if (mask & 4) == 0:
		for x in SIZE:
			_px(img, x, 15, C_DIRT_DARK)
			if x % 4 != 0:
				_px(img, x, 14, C_DIRT_B)
	if (mask & 8) == 0:
		for y in SIZE:
			_px(img, 0, y, C_DIRT_DARK)
	if (mask & 2) == 0:
		for y in SIZE:
			_px(img, 15, y, C_DIRT_DARK)


static func _decorate_dirt(img: Image, variant: int) -> void:
	match variant:
		0:
			pass
		1:
			for spot in [Vector2i(4, 6), Vector2i(10, 11), Vector2i(12, 4)]:
				_px(img, spot.x, spot.y, Color("#c8a679"))
				_px(img, spot.x + 1, spot.y, Color("#a9855e"))
				_px(img, spot.x, spot.y + 1, C_DIRT_DARK)
			_px(img, 6, 2, C_DIRT_LIGHT)
		2:
			# 小雨蘑菇
			_rect(img, 8, 8, 2, 3, Color("#d9c9a3"))
			_rect(img, 6, 6, 6, 2, Color("#b1614f"))
			_px(img, 7, 7, Color("#e3a58e"))
			_px(img, 10, 7, Color("#e3a58e"))


# ---------------- 石墙 ----------------

static func _base_wall(img: Image) -> void:
	img.fill(C_WALL_MORTAR)
	# 交错砖块：每 4px 一层，横向 8px 错位
	for row in 4:
		var y := row * 4
		var offset := 0 if row % 2 == 0 else 4
		for col in range(-1, 3):
			var x := col * 8 + offset
			var shade := _hash(col + 4, row, 29)
			var brick := C_WALL_A if shade < 0.55 else C_WALL_B
			_rect(img, x, y, 7, 3, brick)
			for xx in range(x, x + 7):
				_px(img, xx, y, C_WALL_LIGHT)
				if xx == x:
					_px(img, xx, y + 1, C_WALL_LIGHT)
			_px(img, x + 6, y + 2, C_WALL_DARK)
	if _hash(3, 9, 31) > 0.45:
		_px(img, 4, 9, C_MOSS)
		_px(img, 5, 9, C_MOSS)
		_px(img, 5, 10, C_MOSS)
	if _hash(9, 3, 33) > 0.62:
		_px(img, 10, 3, C_MOSS)
		_px(img, 11, 4, C_MOSS)


static func _edge_wall(img: Image, mask: int) -> void:
	if (mask & 1) == 0:
		for x in SIZE:
			_px(img, x, 0, C_WALL_DARK)
			_px(img, x, 1, C_WALL_DARK)
			if x > 0 and x < SIZE - 1 and x % 5 != 0:
				_px(img, x, 2, C_WALL_LIGHT)
	if (mask & 4) == 0:
		for x in SIZE:
			_px(img, x, 15, C_WALL_DARK)
		for x in range(0, SIZE, 3):
			_px(img, x, 14, C_WALL_DARK)
	if (mask & 8) == 0:
		for y in SIZE:
			_px(img, 0, y, C_WALL_DARK)
			if y > 0 and y < SIZE - 1 and y % 4 != 0:
				_px(img, 1, y, C_WALL_LIGHT)
	if (mask & 2) == 0:
		for y in SIZE:
			_px(img, 15, y, C_WALL_DARK)
			if y % 4 == 2:
				_px(img, 14, y, C_WALL_DARK)


static func _decorate_wall(img: Image, variant: int) -> void:
	match variant:
		0:
			pass
		1:
			for spot in [Vector2i(2, 5), Vector2i(3, 6), Vector2i(11, 11), Vector2i(12, 10), Vector2i(9, 2)]:
				_px(img, spot.x, spot.y, C_MOSS)
				if _hash(spot.x, spot.y, 37) > 0.5:
					_px(img, spot.x + 1, spot.y, Color("#6d8f52"))
		2:
			for y in [3, 4, 5, 6, 7]:
				_px(img, 9 + (1 if y > 4 else 0), y, C_WALL_DARK)
			_px(img, 2, 11, C_WALL_DARK)
			_px(img, 3, 11, C_WALL_DARK)
			_px(img, 3, 12, C_WALL_DARK)


# ---------------- 水面 ----------------

static func _base_water(img: Image) -> void:
	for y in SIZE:
		var t := float(y) / 15.0
		var base := C_WATER_A.lerp(C_WATER_B, t)
		for x in SIZE:
			var c := base
			if _hash(x, y, 41) > 0.9:
				c = C_WATER_C
			_px(img, x, y, c)
	for band in 3:
		var y := 3 + band * 4
		var start := int(_hash(band, 1, 43) * 6.0)
		for x in range(start, mini(SIZE, start + 6)):
			if _hash(x, y, 47) > 0.25:
				_px(img, x, y, C_WATER_LIGHT)
	for i in 4:
		var x := int(_hash(i, 3, 53) * 14.0) + 1
		var y := int(_hash(i, 4, 59) * 12.0) + 2
		_px(img, x, y, C_WATER_C)
		_px(img, x + 1, y, C_WATER_C)


static func _edge_water(img: Image, mask: int) -> void:
	if (mask & 1) == 0:
		for x in SIZE:
			if x % 3 != 2:
				_px(img, x, 0, C_FOAM)
			if x % 4 == 0:
				_px(img, x, 1, C_FOAM)
			else:
				_px(img, x, 1, C_WATER_LIGHT)
	if (mask & 4) == 0:
		for x in SIZE:
			if x % 3 != 1:
				_px(img, x, 15, C_FOAM)
			else:
				_px(img, x, 15, C_WATER_LIGHT)
	if (mask & 8) == 0:
		for y in SIZE:
			if y % 4 != 3:
				_px(img, 0, y, C_FOAM)
			_px(img, 1, y, C_WATER_LIGHT)
	if (mask & 2) == 0:
		for y in SIZE:
			if y % 4 != 1:
				_px(img, 15, y, C_FOAM)
			_px(img, 14, y, C_WATER_LIGHT)


static func _decorate_water(img: Image, variant: int) -> void:
	match variant:
		0:
			pass
		1:
			# 睡莲
			for y in range(6, 12):
				for x in range(5, 12):
					var dx := float(x - 8) / 3.4
					var dy := float(y - 9) / 2.6
					if dx * dx + dy * dy <= 1.0 and not (x == 8 and y < 9):
						_px(img, x, y, Color("#6e9c5d"))
			_px(img, 8, 8, Color("#d9c37b"))
			_px(img, 9, 8, Color("#f0df9d"))
		2:
			for i in 3:
				var r := 2 + i * 2
				for x in range(8 - r, 8 + r + 1):
					_px(img, x, 8, C_WATER_LIGHT)
				_px(img, 8, 8, C_FOAM)


# ---------------- 实体 ----------------

static func _draw_spawn(img: Image) -> void:
	# 小旗 + 石基：一眼可读为“起点”
	_rect(img, 3, 12, 8, 2, Color("#3b4a45"))
	_rect(img, 4, 11, 6, 1, Color("#71806f"))
	for y in range(2, 12):
		_px(img, 4, y, Color("#d8d4bd"))
		_px(img, 5, y, Color("#8b8a7a"))
	var flag := Color("#e8b36a")
	for y in range(2, 7):
		var width := 7 - absi(y - 4)
		for x in range(6, 6 + width):
			_px(img, x, y, flag)
	_px(img, 6, 2, Color("#f7dfa8"))
	_px(img, 8, 4, Color("#6f9a55"))
	_px(img, 9, 4, Color("#6f9a55"))
	_px(img, 12, 1, Color("#f5ecc0"))
	_px(img, 13, 1, Color("#f5ecc0"))
	_px(img, 12, 0, Color("#f5ecc0"))
	_px(img, 12, 2, Color("#f5ecc0"))


static func _draw_enemy(img: Image) -> void:
	# 苔团小妖：紫色身体在绿地/泥地上都醒目
	for y in range(4, 15):
		for x in range(2, 14):
			var dx := float(x - 8) / 6.0
			var dy := float(y - 12) / 5.0
			if dx * dx + dy * dy <= 1.0:
				var c := Color("#7a639f")
				if y < 9:
					c = Color("#8b73b2")
				if x > 10 and y > 10:
					c = Color("#68528b")
				_px(img, x, y, c)
	for y in range(4, 15):
		for x in range(2, 14):
			var dx := float(x - 8) / 6.0
			var dy := float(y - 12) / 5.0
			if dx * dx + dy * dy <= 1.0:
				var outer := false
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if img.get_pixel(clampi(x + d.x, 0, 15), clampi(y + d.y, 0, 15)).a < 0.1:
						outer = true
				if outer:
					_px(img, x, y, C_INK)
	for x in [5, 10]:
		_rect(img, x, 8, 2, 2, Color("#f2ead7"))
		_px(img, x, 9, C_INK)
	_px(img, 7, 11, C_INK)
	_px(img, 8, 11, Color("#b49ad3"))
	_px(img, 8, 3, Color("#6f9a55"))
	_px(img, 9, 2, Color("#87b267"))
	_px(img, 10, 3, Color("#6f9a55"))


static func _draw_chest(img: Image) -> void:
	# 木箱 + 金扣
	_rect(img, 2, 13, 12, 2, Color(0.0, 0.0, 0.0, 0.25))
	_rect(img, 2, 5, 12, 10, Color("#6b4428"))
	_rect(img, 3, 6, 10, 8, Color("#93643a"))
	_rect(img, 2, 3, 12, 4, Color("#7b4f2e"))
	_rect(img, 3, 4, 10, 2, Color("#a97645"))
	for x in range(3, 13):
		_px(img, x, 7, Color("#c08c52"))
	_px(img, 2, 3, C_INK)
	_px(img, 13, 3, C_INK)
	_px(img, 2, 14, C_INK)
	_px(img, 13, 14, C_INK)
	_rect(img, 7, 6, 2, 6, Color("#d9ad5e"))
	_rect(img, 6, 8, 4, 3, Color("#e8c273"))
	_px(img, 7, 9, Color("#6b4a20"))
	_px(img, 8, 9, Color("#6b4a20"))
	_px(img, 4, 9, Color("#c08c52"))
	_px(img, 11, 11, Color("#c08c52"))


static func _draw_marker(img: Image, color: Color) -> void:
	_rect(img, 5, 5, 6, 6, color)
	_rect(img, 4, 6, 8, 4, color)
	_px(img, 7, 7, C_INK)
	_px(img, 8, 7, C_INK)


static func _draw_player(img: Image, facing: String) -> void:
	# 16×20 的小园丁：草帽 + 苔绿外套
	_rect(img, 3, 18, 10, 1, Color(0.0, 0.0, 0.0, 0.22))
	# 靴子
	_rect(img, 4, 16, 3, 3, Color("#4a392e"))
	_rect(img, 9, 16, 3, 3, Color("#4a392e"))
	# 外套
	_rect(img, 4, 10, 8, 7, Color("#4e7851"))
	_rect(img, 5, 11, 6, 4, Color("#5f8b5a"))
	_px(img, 4, 10, Color("#2f4a34"))
	_px(img, 11, 10, Color("#2f4a34"))
	# 手臂
	if facing == "left":
		_rect(img, 2, 11, 2, 4, Color("#d7b387"))
	elif facing == "right":
		_rect(img, 12, 11, 2, 4, Color("#d7b387"))
	else:
		_px(img, 3, 12, Color("#d7b387"))
		_px(img, 12, 12, Color("#d7b387"))
	# 头
	_rect(img, 5, 6, 6, 5, Color("#e2bd92"))
	if facing == "up":
		_rect(img, 5, 6, 6, 5, Color("#c9a67c"))
		_px(img, 7, 9, Color("#8a6a45"))
		_px(img, 8, 9, Color("#8a6a45"))
	elif facing == "left":
		_px(img, 6, 8, C_INK)
		_px(img, 5, 9, Color("#c9a67c"))
	elif facing == "right":
		_px(img, 9, 8, C_INK)
		_px(img, 10, 9, Color("#c9a67c"))
	else:
		_px(img, 6, 8, C_INK)
		_px(img, 9, 8, C_INK)
		_px(img, 7, 10, Color("#b08965"))
	# 草帽
	_rect(img, 2, 4, 12, 2, Color("#d8b56b"))
	_rect(img, 4, 2, 8, 2, Color("#c9a45c"))
	_rect(img, 5, 3, 6, 1, Color("#e6ca83"))
	_px(img, 2, 4, Color("#8f6f3c"))
	_px(img, 13, 4, Color("#8f6f3c"))
	for x in range(3, 13, 2):
		_px(img, x, 5, Color("#b18d4e"))
