class_name PixelSurface
extends RefCounted

# 一个像素物件同时保留 albedo / 高度 / 粗糙度 / 自发光四层。
# finish() 把高度场差分成法线图，并把自发光遮罩塞进法线图 alpha 通道，
# 这样每个受光 Sprite 只需要绑定 2 张纹理（albedo + normal/emission），
# 粗糙度单独 1 张。所有图都是最近邻、无 mip 的 1× 像素图。

var width: int
var height: int
var image: Image
var heights: PackedFloat32Array
var roughness: PackedFloat32Array
var emission: PackedFloat32Array
# 每个像素的基础法线偏移（x/y）。高度场负责细部凹凸；
# 这张低分辨率法线层负责“屋顶朝哪边、树冠朝外、石头鼓起”的大形。
var normal_bias: PackedVector2Array

const EDGE_HEIGHT := -0.34


func _init(w: int, h: int) -> void:
	width = w
	height = h
	image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	heights = PackedFloat32Array()
	heights.resize(w * h)
	heights.fill(0.38)
	roughness = PackedFloat32Array()
	roughness.resize(w * h)
	roughness.fill(0.82)
	emission = PackedFloat32Array()
	emission.resize(w * h)
	emission.fill(0.0)
	normal_bias = PackedVector2Array()
	normal_bias.resize(w * h)
	normal_bias.fill(Vector2.ZERO)


func px(x: int, y: int, c: Color, h := -1.0, rough := -1.0, emit := -1.0) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	image.set_pixel(x, y, c)
	var i := y * width + x
	if h >= 0.0:
		heights[i] = h
	if rough >= 0.0:
		roughness[i] = rough
	if emit >= 0.0:
		emission[i] = emit


func rect(x0: int, y0: int, x1: int, y1: int, c: Color,
		h := -1.0, rough := -1.0, emit := -1.0) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			px(x, y, c, h, rough, emit)


func hline(x0: int, x1: int, y: int, c: Color, h := -1.0,
		rough := -1.0, emit := -1.0) -> void:
	for x in range(x0, x1 + 1):
		px(x, y, c, h, rough, emit)


func vline(x: int, y0: int, y1: int, c: Color, h := -1.0,
		rough := -1.0, emit := -1.0) -> void:
	for y in range(y0, y1 + 1):
		px(x, y, c, h, rough, emit)


func line(x0: int, y0: int, x1: int, y1: int, c: Color, h := -1.0,
		rough := -1.0, emit := -1.0) -> void:
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		px(x0, y0, c, h, rough, emit)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func disc(cx: float, cy: float, rx: float, ry: float, c: Color,
		h := -1.0, rough := -1.0, emit := -1.0) -> void:
	var x0 := int(floor(cx - rx))
	var x1 := int(ceil(cx + rx))
	var y0 := int(floor(cy - ry))
	var y1 := int(ceil(cy + ry))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var q := pow((float(x) + 0.5 - cx) / rx, 2.0) \
					+ pow((float(y) + 0.5 - cy) / ry, 2.0)
			if q <= 1.0:
				px(x, y, c, h, rough, emit)


func normal_px(x: int, y: int, nx: float, ny: float) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	normal_bias[y * width + x] = Vector2(nx, ny)


func normal_rect(x0: int, y0: int, x1: int, y1: int, nx: float, ny: float) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			normal_px(x, y, nx, ny)


func outline_rect(x0: int, y0: int, x1: int, y1: int, c: Color,
		h := -1.0, rough := -1.0, emit := -1.0) -> void:
	hline(x0, x1, y0, c, h, rough, emit)
	hline(x0, x1, y1, c, h, rough, emit)
	vline(x0, y0, y1, c, h, rough, emit)
	vline(x1, y0, y1, c, h, rough, emit)


func vgradient(x0: int, y0: int, x1: int, y1: int, top: Color, bottom: Color,
		h := -1.0, rough := -1.0, emit := -1.0) -> void:
	var span := float(maxi(y1 - y0, 1))
	for y in range(y0, y1 + 1):
		var t := float(y - y0) / span
		var c := top.lerp(bottom, t)
		hline(x0, x1, y, c, h, rough, emit)


# 固定种子噪声，用来打散砖石/树冠的规则感。
static func noise01(x: int, y: int, seed_value := 1337) -> float:
	var n := (x * 374761393 + y * 668265263 + seed_value * 1442695040) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _height_at(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= width or y >= height:
		return EDGE_HEIGHT
	if image.get_pixel(x, y).a < 0.5:
		return EDGE_HEIGHT
	return heights[y * width + x]


func finish(normal_gain := 1.85) -> Dictionary:
	var normal := Image.create(width, height, false, Image.FORMAT_RGBA8)
	normal.fill(Color(0.5, 0.5, 1.0, 0.0))
	var rough_img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	rough_img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a < 0.5:
				continue
			var dx := (_height_at(x + 1, y) - _height_at(x - 1, y)) * normal_gain
			var dy := (_height_at(x, y + 1) - _height_at(x, y - 1)) * normal_gain
			var i := y * width + x
			var bias := normal_bias[i]
			var n := Vector3(-dx + bias.x, -dy + bias.y, 1.0).normalized()
			normal.set_pixel(x, y, Color(
				n.x * 0.5 + 0.5,
				n.y * 0.5 + 0.5,
				n.z * 0.5 + 0.5,
				clampf(emission[i], 0.0, 1.0)))
			var r := clampf(roughness[i], 0.05, 1.0)
			rough_img.set_pixel(x, y, Color(r, r, r, 1.0))
	return {
		"image": image,
		"normal": normal,
		"roughness": rough_img,
		"width": width,
		"height": height,
	}
