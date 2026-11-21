extends RefCounted

# 原创程序化瓦片画法。全部图形由 CanvasItem 在运行时绘制，不使用贴图。
# 同一套画法用于成品地图、算法视图里的候选缩略图和已坍缩格。

const Tiles = preload("res://scripts/wfc_tileset.gd")

const INK := Color("#2c382c")
const GRASS_DARK := Color("#4b633f")
const GRASS_MID := Color("#607b4c")
const GRASS_LIGHT := Color("#82955c")
const EARTH_WARM := Color("#8a7151")
const STONE_OUTLINE := Color("#6e5a3e")
const STONE := Color("#c3aa7a")
const STONE_LIGHT := Color("#e0c894")
const WATER_DARK := Color("#315c5c")
const WATER := Color("#4f8580")
const WATER_LIGHT := Color("#83ada0")
const ROOF := Color("#ad5d4b")
const ROOF_LIGHT := Color("#cc7b61")
const WALL := Color("#d3c3a0")
const WALL_SHADE := Color("#9d8d70")
const GLASS := Color("#9cbcb0")
const GLASS_LIGHT := Color("#cfe0cd")
const LANTERN := Color("#f0c574")


static func draw_full(canvas: CanvasItem, tile: int, rect: Rect2, cell_seed: int,
		time: float = 0.0, alpha: float = 1.0, animated: bool = true) -> void:
	if alpha <= 0.001 or rect.size.x < 1.0 or rect.size.y < 1.0:
		return
	var base := _vary(Tiles.base_color(tile), _rand01(cell_seed + 11) * 0.07 - 0.035)
	canvas.draw_rect(rect, _fade(base, alpha))
	if Tiles.is_path(tile):
		_draw_path(canvas, tile, rect, cell_seed, alpha)
		return
	match tile:
		Tiles.MEADOW:
			_draw_meadow(canvas, rect, cell_seed, alpha, animated)
		Tiles.FLOWERS:
			_draw_flowers(canvas, rect, cell_seed, alpha)
		Tiles.FOREST:
			_draw_forest(canvas, rect, cell_seed, alpha, animated)
		Tiles.POND:
			_draw_pond(canvas, rect, cell_seed, alpha, time, animated)
		Tiles.COTTAGE:
			_draw_cottage(canvas, rect, cell_seed, alpha, animated)
		Tiles.GREENHOUSE:
			_draw_greenhouse(canvas, rect, cell_seed, alpha)
		Tiles.RUIN:
			_draw_ruin(canvas, rect, alpha)


# 小图标：算法视图叠加态里的瓦片候选。
static func draw_thumbnail(canvas: CanvasItem, tile: int, rect: Rect2, alpha: float = 1.0) -> void:
	if alpha <= 0.001:
		return
	var base := Tiles.base_color(tile)
	canvas.draw_rect(rect, _fade(base, alpha))
	var center := rect.get_center()
	var unit := minf(rect.size.x, rect.size.y)
	if Tiles.is_path(tile):
		canvas.draw_circle(center, unit * 0.19, _fade(STONE_LIGHT, alpha))
		if Tiles.socket(tile, Tiles.N) == 1:
			canvas.draw_rect(Rect2(center.x - unit * 0.08, rect.position.y,
					unit * 0.16, center.y - rect.position.y), _fade(STONE, alpha))
		if Tiles.socket(tile, Tiles.E) == 1:
			canvas.draw_rect(Rect2(center.x, center.y - unit * 0.08,
					rect.end.x - center.x, unit * 0.16), _fade(STONE, alpha))
		if Tiles.socket(tile, Tiles.S) == 1:
			canvas.draw_rect(Rect2(center.x - unit * 0.08, center.y,
					unit * 0.16, rect.end.y - center.y), _fade(STONE, alpha))
		if Tiles.socket(tile, Tiles.W) == 1:
			canvas.draw_rect(Rect2(rect.position.x, center.y - unit * 0.08,
					center.x - rect.position.x, unit * 0.16), _fade(STONE, alpha))
		return
	match tile:
		Tiles.MEADOW:
			canvas.draw_circle(center + Vector2(-unit * 0.15, unit * 0.06), unit * 0.09,
					_fade(GRASS_LIGHT, alpha))
			canvas.draw_circle(center + Vector2(unit * 0.14, -unit * 0.05), unit * 0.07,
					_fade(GRASS_DARK, alpha))
		Tiles.FLOWERS:
			for offset in [Vector2(-0.16, 0.05), Vector2(0.12, -0.10), Vector2(0.04, 0.18)]:
				canvas.draw_circle(center + Vector2(offset.x, offset.y) * unit, unit * 0.06,
						_fade(Tiles.accent_color(tile), alpha))
		Tiles.FOREST:
			canvas.draw_circle(center + Vector2(-unit * 0.1, 0), unit * 0.18, _fade(GRASS_DARK, alpha))
			canvas.draw_circle(center + Vector2(unit * 0.12, unit * 0.08), unit * 0.14,
					_fade(Color("#35503a"), alpha))
		Tiles.POND:
			canvas.draw_circle(center, unit * 0.26, _fade(WATER_DARK, alpha))
			canvas.draw_circle(center, unit * 0.20, _fade(WATER, alpha))
			canvas.draw_circle(center + Vector2(-unit * 0.06, -unit * 0.06), unit * 0.04,
					_fade(WATER_LIGHT, alpha))
		Tiles.COTTAGE:
			canvas.draw_rect(Rect2(center - Vector2(unit * 0.19, unit * 0.13),
					Vector2(unit * 0.38, unit * 0.26)), _fade(WALL, alpha))
			canvas.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-unit * 0.24, -unit * 0.06),
				center + Vector2(0, -unit * 0.27),
				center + Vector2(unit * 0.24, -unit * 0.06),
			]), _fade(ROOF, alpha))
		Tiles.GREENHOUSE:
			canvas.draw_rect(Rect2(center - Vector2(unit * 0.21, unit * 0.16),
					Vector2(unit * 0.42, unit * 0.32)), _fade(GLASS, alpha))
			canvas.draw_line(center + Vector2(-unit * 0.21, 0), center + Vector2(unit * 0.21, 0),
					_fade(GRASS_DARK, alpha), maxf(1.0, unit * 0.03))
		Tiles.RUIN:
			canvas.draw_rect(Rect2(center - Vector2(unit * 0.20, unit * 0.10),
					Vector2(unit * 0.25, unit * 0.20)), _fade(Color("#9e9a81"), alpha))
			canvas.draw_rect(Rect2(center + Vector2(unit * 0.02, unit * 0.03),
					Vector2(unit * 0.18, unit * 0.15)), _fade(Color("#857f68"), alpha))


static func _draw_meadow(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float,
		animated: bool) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var count := 5 + int(_rand01(seed + 3) * 4.0)
	for i in count:
		var x := _rand01(seed + i * 17)
		var y := _rand01(seed + i * 31 + 8)
		var p := _point(rect, 0.10 + x * 0.80, 0.12 + y * 0.76)
		var sway := sin(Time.get_ticks_msec() * 0.0013 + x * 8.0) * unit * 0.014 if animated else 0.0
		var color := GRASS_LIGHT if i % 3 else GRASS_DARK
		canvas.draw_line(p, p + Vector2(sway, -unit * 0.075), _fade(color, alpha * 0.72),
				maxf(1.0, unit * 0.016))
		canvas.draw_line(p, p + Vector2(unit * 0.05 + sway, -unit * 0.035),
				_fade(color, alpha * 0.55), maxf(1.0, unit * 0.012))
	if _rand01(seed + 91) > 0.64:
		var flower := _point(rect, 0.18 + _rand01(seed + 13) * 0.64,
				0.16 + _rand01(seed + 14) * 0.68)
		canvas.draw_circle(flower, maxf(1.2, unit * 0.023), _fade(Color("#ead79d"), alpha))
		canvas.draw_circle(flower, maxf(0.8, unit * 0.011), _fade(Color("#c57d63"), alpha))


static func _draw_flowers(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var palette := [Color("#d98579"), Color("#e7c882"), Color("#d3b2c4"), Color("#f0dfb3")]
	for i in 8:
		var p := _point(rect, 0.12 + _rand01(seed + i * 41) * 0.76,
				0.12 + _rand01(seed + i * 59 + 2) * 0.76)
		canvas.draw_line(p, p + Vector2(0, unit * 0.05), _fade(GRASS_DARK, alpha * 0.6),
				maxf(0.8, unit * 0.012))
		canvas.draw_circle(p, maxf(1.0, unit * 0.022 + _rand01(seed + i) * unit * 0.012),
				_fade(palette[i % palette.size()], alpha))
		canvas.draw_circle(p, maxf(0.6, unit * 0.008), _fade(Color("#f2e5ba"), alpha))


static func _draw_forest(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float,
		animated: bool) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var canopy_colors := [Color("#304a34"), Color("#3d5b3b"), Color("#526d45")]
	# 轻微地面阴影，让树冠从草地里“浮”出来。
	canvas.draw_circle(_point(rect, 0.56, 0.58), unit * 0.30, _fade(Color("#31442f"), alpha * 0.16))
	for i in 3:
		var cx := 0.26 + _rand01(seed + i * 71) * 0.46
		var cy := 0.28 + _rand01(seed + i * 97 + 5) * 0.44
		var center := _point(rect, cx, cy)
		var radius := unit * (0.14 + _rand01(seed + i * 33) * 0.06)
		var sway := sin(Time.get_ticks_msec() * 0.0009 + seed * 0.13 + i) * unit * 0.008 \
				if animated else 0.0
		center.x += sway
		canvas.draw_line(center + Vector2(0, radius * 0.35), center + Vector2(0, radius * 0.9),
				_fade(Color("#54412f"), alpha), maxf(1.0, unit * 0.025))
		for layer in 3:
			var c: Color = canopy_colors[layer]
			var offset := Vector2((_rand01(seed + i * 10 + layer) - 0.5) * radius * 0.5,
					(_rand01(seed + i * 13 + layer) - 0.5) * radius * 0.5)
			canvas.draw_circle(center + offset, radius * (1.0 - layer * 0.18), _fade(c, alpha))
		canvas.draw_circle(center + Vector2(-radius * 0.20, -radius * 0.25), radius * 0.27,
				_fade(Color("#78905a"), alpha * 0.55))


static func _draw_pond(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float,
		time: float, animated: bool) -> void:
	var center := _point(rect, 0.50, 0.52)
	var unit := minf(rect.size.x, rect.size.y)
	var bank := PackedVector2Array()
	var water := PackedVector2Array()
	var count := 14
	for i in count:
		var angle := TAU * float(i) / float(count)
		var wobble := 1.0 + 0.12 * sin(angle * 3.0 + _rand01(seed + 7) * 4.0) \
				+ 0.05 * sin(angle * 5.0 + 1.7)
		bank.append(center + Vector2(cos(angle) * rect.size.x * 0.34 * wobble,
				sin(angle) * rect.size.y * 0.32 * wobble))
		water.append(center + Vector2(cos(angle) * rect.size.x * 0.29 * wobble,
				sin(angle) * rect.size.y * 0.275 * wobble))
	canvas.draw_colored_polygon(bank, _fade(Color("#566b48"), alpha))
	canvas.draw_colored_polygon(water, _fade(WATER_DARK, alpha))
	var inner := PackedVector2Array()
	for i in count:
		inner.append(center + (water[i] - center) * 0.80)
	canvas.draw_colored_polygon(inner, _fade(WATER, alpha))
	# 波光；时间只改变横向偏移，不影响布局。
	var shift := sin(time * 0.9 + seed * 0.1) * rect.size.x * 0.05 if animated else 0.0
	for i in 3:
		var y := center.y + rect.size.y * (-0.10 + i * 0.095)
		var half := rect.size.x * (0.11 - i * 0.012)
		canvas.draw_line(Vector2(center.x - half + shift * (i - 1), y),
				Vector2(center.x + half + shift * (i - 1), y),
				_fade(WATER_LIGHT, alpha * 0.42), maxf(1.0, unit * 0.012))
	# 睡莲和芦苇。
	for i in 2:
		var p := center + Vector2(rect.size.x * (-0.12 + i * 0.19),
				rect.size.y * (-0.15 + i * 0.14))
		canvas.draw_circle(p, unit * 0.032, _fade(Color("#6f8c54"), alpha))
		canvas.draw_line(p, p + Vector2(unit * 0.055, 0), _fade(Color("#3f5c3d"), alpha * 0.6),
				maxf(0.8, unit * 0.012))
	for i in 3:
		var p := center + Vector2(rect.size.x * (0.26 + i * 0.025),
				rect.size.y * (0.24 - i * 0.045))
		canvas.draw_line(p, p + Vector2(unit * 0.018, -unit * 0.10),
				_fade(Color("#78905a"), alpha * 0.8), maxf(1.0, unit * 0.012))


static func _draw_cottage(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float,
		animated: bool) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var center := _point(rect, 0.50, 0.51)
	var flip := -1.0 if _rand01(seed + 4) > 0.5 else 1.0
	# 影子
	canvas.draw_circle(center + Vector2(unit * 0.06, unit * 0.11), unit * 0.26,
			_fade(Color("#2d3e2c"), alpha * 0.28))
	# 石基与墙
	var wall_rect := Rect2(center + Vector2(-unit * 0.21, -unit * 0.10),
			Vector2(unit * 0.42, unit * 0.28))
	canvas.draw_rect(wall_rect, _fade(WALL_SHADE, alpha))
	canvas.draw_rect(Rect2(wall_rect.position + Vector2(unit * 0.025, -unit * 0.025),
			wall_rect.size - Vector2(unit * 0.05, unit * 0.05)), _fade(WALL, alpha))
	# 陶土坡屋顶
	var roof := PackedVector2Array([
		center + Vector2(-unit * 0.30, -unit * 0.06),
		center + Vector2(-unit * 0.06, -unit * 0.29),
		center + Vector2(unit * 0.28, -unit * 0.06),
		center + Vector2(unit * 0.21, unit * 0.02),
		center + Vector2(-unit * 0.25, unit * 0.02),
	])
	canvas.draw_colored_polygon(roof, _fade(ROOF, alpha))
	var roof_light := PackedVector2Array([
		center + Vector2(-unit * 0.23, -unit * 0.06),
		center + Vector2(-unit * 0.05, -unit * 0.23),
		center + Vector2(unit * 0.04, -unit * 0.06),
	])
	canvas.draw_colored_polygon(roof_light, _fade(ROOF_LIGHT, alpha))
	canvas.draw_line(center + Vector2(-unit * 0.05, -unit * 0.23),
			center + Vector2(-unit * 0.06, unit * 0.015), _fade(Color("#7f3f35"), alpha),
			maxf(1.0, unit * 0.018))
	# 烟囱与窗
	canvas.draw_rect(Rect2(center + Vector2(unit * 0.13 * flip, -unit * 0.27),
			Vector2(unit * 0.07, unit * 0.12)), _fade(Color("#8a6f5e"), alpha))
	for i in 2:
		var win := center + Vector2(unit * (-0.10 + i * 0.17), unit * 0.08)
		canvas.draw_rect(Rect2(win - Vector2(unit * 0.022, unit * 0.025),
				Vector2(unit * 0.044, unit * 0.05)), _fade(Color("#5e4d3c"), alpha))
		canvas.draw_circle(win, maxf(1.0, unit * 0.014), _fade(LANTERN, alpha * 0.92))
	if animated:
		var flicker := 0.30 + 0.08 * sin(Time.get_ticks_msec() * 0.006 + seed)
		canvas.draw_circle(center + Vector2(0, unit * 0.08), unit * 0.20,
				_fade(LANTERN, alpha * flicker * 0.20))


static func _draw_greenhouse(canvas: CanvasItem, rect: Rect2, seed: int, alpha: float) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var center := _point(rect, 0.50, 0.52)
	canvas.draw_circle(center + Vector2(unit * 0.05, unit * 0.10), unit * 0.23,
			_fade(Color("#2d3e2c"), alpha * 0.22))
	var glass_rect := Rect2(center + Vector2(-unit * 0.24, -unit * 0.16),
			Vector2(unit * 0.48, unit * 0.31))
	canvas.draw_rect(glass_rect, _fade(GLASS, alpha * 0.87))
	canvas.draw_rect(Rect2(glass_rect.position, Vector2(glass_rect.size.x, unit * 0.06)),
			_fade(GLASS_LIGHT, alpha * 0.42))
	# 玻璃框架
	canvas.draw_rect(glass_rect, _fade(Color("#e1dfc4"), alpha * 0.8), false, maxf(1.0, unit * 0.022))
	for i in 3:
		var x := glass_rect.position.x + glass_rect.size.x * float(i + 1) / 4.0
		canvas.draw_line(Vector2(x, glass_rect.position.y),
				Vector2(x, glass_rect.end.y), _fade(Color("#e1dfc4"), alpha * 0.58),
				maxf(1.0, unit * 0.012))
	for i in 4:
		var p := glass_rect.position + Vector2(glass_rect.size.x * (0.14 + i * 0.23),
				glass_rect.size.y * 0.72)
		canvas.draw_circle(p, unit * 0.045, _fade(Color("#547547"), alpha * 0.75))
		canvas.draw_circle(p + Vector2(-unit * 0.02, -unit * 0.025), unit * 0.022,
				_fade(Tiles.accent_color(Tiles.FLOWERS), alpha * 0.85))


static func _draw_ruin(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var center := _point(rect, 0.50, 0.54)
	canvas.draw_circle(center + Vector2(unit * 0.03, unit * 0.07), unit * 0.24,
			_fade(Color("#2d3e2c"), alpha * 0.20))
	# 残墙两段
	var left := Rect2(center + Vector2(-unit * 0.27, -unit * 0.08),
			Vector2(unit * 0.22, unit * 0.19))
	var right := Rect2(center + Vector2(unit * 0.05, -unit * 0.16),
			Vector2(unit * 0.18, unit * 0.12))
	canvas.draw_rect(left, _fade(Color("#88836d"), alpha))
	canvas.draw_rect(Rect2(left.position, Vector2(left.size.x, unit * 0.035)),
			_fade(Color("#b3ac91"), alpha))
	canvas.draw_rect(right, _fade(Color("#77735e"), alpha))
	# 碎石与苔藓
	for i in 4:
		var p := center + Vector2(unit * (-0.23 + i * 0.14), unit * (0.14 + 0.03 * (i % 2)))
		canvas.draw_circle(p, unit * 0.042, _fade(Color("#9c9479"), alpha))
		canvas.draw_circle(p + Vector2(unit * 0.018, -unit * 0.010), unit * 0.023,
				_fade(Color("#65794e"), alpha * 0.8))
	canvas.draw_line(left.position + Vector2(0, left.size.y * 0.45),
			left.position + Vector2(left.size.x, left.size.y * 0.35),
			_fade(Color("#5e714a"), alpha * 0.8), maxf(1.0, unit * 0.018))


static func _draw_path(canvas: CanvasItem, tile: int, rect: Rect2, seed: int, alpha: float) -> void:
	var unit := minf(rect.size.x, rect.size.y)
	var center := rect.get_center()
	var outline_w := maxf(2.0, unit * 0.28)
	var fill_w := maxf(1.0, unit * 0.205)
	for direction in Tiles.DIRS:
		if Tiles.socket(tile, direction) != 1:
			continue
		var end := center
		match direction:
			Tiles.N:
				end = Vector2(center.x, rect.position.y)
				canvas.draw_rect(Rect2(end - Vector2(outline_w * 0.5, 0),
						Vector2(outline_w, center.y - rect.position.y + outline_w * 0.5)),
						_fade(STONE_OUTLINE, alpha))
				canvas.draw_rect(Rect2(end - Vector2(fill_w * 0.5, 0),
						Vector2(fill_w, center.y - rect.position.y + fill_w * 0.5)),
						_fade(STONE, alpha))
			Tiles.E:
				end = Vector2(rect.end.x, center.y)
				canvas.draw_rect(Rect2(center.x - outline_w * 0.5, center.y - outline_w * 0.5,
						rect.end.x - center.x + outline_w * 0.5, outline_w), _fade(STONE_OUTLINE, alpha))
				canvas.draw_rect(Rect2(center.x - fill_w * 0.5, center.y - fill_w * 0.5,
						rect.end.x - center.x + fill_w * 0.5, fill_w), _fade(STONE, alpha))
			Tiles.S:
				end = Vector2(center.x, rect.end.y)
				canvas.draw_rect(Rect2(center.x - outline_w * 0.5, center.y - outline_w * 0.5,
						outline_w, rect.end.y - center.y + outline_w * 0.5), _fade(STONE_OUTLINE, alpha))
				canvas.draw_rect(Rect2(center.x - fill_w * 0.5, center.y - fill_w * 0.5,
						fill_w, rect.end.y - center.y + fill_w * 0.5), _fade(STONE, alpha))
			Tiles.W:
				end = Vector2(rect.position.x, center.y)
				canvas.draw_rect(Rect2(end.x, center.y - outline_w * 0.5,
						center.x - rect.position.x + outline_w * 0.5, outline_w), _fade(STONE_OUTLINE, alpha))
				canvas.draw_rect(Rect2(end.x, center.y - fill_w * 0.5,
						center.x - rect.position.x + fill_w * 0.5, fill_w), _fade(STONE, alpha))
		# 边缘的小碎石纹理
		for i in 2:
			var t := 0.25 + i * 0.33
			var p := center.lerp(end, t) + Vector2(unit * (_rand01(seed + i + direction * 3) - 0.5) * 0.06,
					unit * (_rand01(seed + i * 5 + direction) - 0.5) * 0.06)
			canvas.draw_circle(p, maxf(0.8, unit * 0.014), _fade(STONE_LIGHT, alpha * 0.48))
	canvas.draw_circle(center, maxf(1.4, unit * 0.11), _fade(STONE_OUTLINE, alpha))
	canvas.draw_circle(center, maxf(1.0, unit * 0.083), _fade(STONE, alpha))
	canvas.draw_circle(center + Vector2(-unit * 0.02, -unit * 0.02), maxf(0.7, unit * 0.026),
			_fade(STONE_LIGHT, alpha * 0.40))


static func _point(rect: Rect2, fx: float, fy: float) -> Vector2:
	return rect.position + Vector2(rect.size.x * fx, rect.size.y * fy)


static func _vary(color: Color, amount: float) -> Color:
	return color.lightened(amount) if amount >= 0.0 else color.darkened(-amount)


static func _fade(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


static func _rand01(seed: int) -> float:
	var x := seed & 0x7fffffff
	x = (x ^ 61) ^ (x >> 16)
	x = x + (x << 3)
	x = x ^ (x >> 4)
	x = x * 0x27d4eb2d
	x = x ^ (x >> 15)
	return float(x & 0x7fffffff) / 2147483647.0
