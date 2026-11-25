class_name PuddleField
extends RefCounted

# 低洼盆地场（CPU 生成 + 单张 RGBA 贴图给 shader）：
#   R = 高度（越小越低洼），G = 大占地遮挡，B = 灯柱格标记，A = 边缘噪声。
# 水线 waterline 随湿度上升：h < waterline 的格子积水，所以水洼从最深处
# 向浅处自然长大；退水时反向收缩。
# 占位规则：大石头/石岸写入遮挡；细灯柱占 1×1 格，按“放行积水”规则清除
# 遮挡，水可以从灯柱脚下穿过，避免方形干边。

signal generated

const TEX_W := 320
const TEX_H := 180
const TEX_SCALE := 2.0

# 与 shaders/water_mask.gdshaderinc 必须保持一致。
const EDGE_SOFT := 0.010
const EDGE_JITTER := 0.010

const WATERLINE_FULL_PERCENTILE := 0.19
const WATERLINE_DRY_MARGIN := 0.014
const RIPPLE_SPAWN_INSET := 0.008

var height := PackedFloat32Array()
var block := PackedByteArray()
var edge := PackedFloat32Array()
var lamp_flag := PackedByteArray()

var lamp_cells: Array[Vector2i] = []
var blocked_cells: Array[Vector2i] = []
var rock_cells: Array[Vector2i] = []
var bank_cells: Array[Vector2i] = []
var spawn_points := PackedVector2Array()

var waterline_dry := 0.0
var waterline_full := 0.0
var height_min := 0.0
var height_max := 0.0

var _texture: ImageTexture
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_generate()


# ── 生成 ─────────────────────────────────────────────────────────────────
func _generate() -> void:
	height.resize(TEX_W * TEX_H)
	edge.resize(TEX_W * TEX_H)
	block.resize(TEX_W * TEX_H)
	lamp_flag.resize(TEX_W * TEX_H)
	block.fill(0)
	lamp_flag.fill(0)

	var low := FastNoiseLite.new()
	low.seed = 20261125
	low.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	low.frequency = 0.017
	low.fractal_type = FastNoiseLite.FRACTAL_FBM
	low.fractal_octaves = 3
	low.fractal_gain = 0.55

	var fine := FastNoiseLite.new()
	fine.seed = 77231
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.frequency = 0.085

	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = 4411
	edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	edge_noise.frequency = 0.12

	var warp := FastNoiseLite.new()
	warp.seed = 9907
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency = 0.035

	for ty in TEX_H:
		for tx in TEX_W:
			var i := ty * TEX_W + tx
			var wx := (float(tx) + 0.5) * TEX_SCALE
			var wy := (float(ty) + 0.5) * TEX_SCALE
			var n_low := low.get_noise_2d(float(tx), float(ty))
			var n_fine := fine.get_noise_2d(float(tx), float(ty))
			var h := 0.50 + n_low * 0.26 + n_fine * 0.030
			h += (float(tx) / float(TEX_W) - 0.5) * 0.030

			# 大尺度盆地：噪声扰动椭圆边界，避免正圆水洼。
			var w := warp.get_noise_2d(float(tx), float(ty))
			for basin in RainLayout.BASINS:
				var center: Vector2 = basin["pos"]
				var radii: Vector2 = basin["radii"]
				var depth: float = basin["depth"]
				var q := pow((wx - center.x) / radii.x, 2.0) \
						+ pow((wy - center.y) / radii.y, 2.0)
				q += w * 0.11
				var bowl := 1.0 - smoothstep(0.05, 1.0, q)
				h -= depth * bowl

			height[i] = clampf(h, 0.02, 0.96)
			edge[i] = edge_noise.get_noise_2d(float(tx), float(ty)) * 0.5 + 0.5

	height_min = 1.0
	height_max = 0.0
	for h in height:
		height_min = minf(height_min, h)
		height_max = maxf(height_max, h)
	var sorted := height.duplicate()
	sorted.sort()
	var full_index := clampi(int(float(sorted.size()) * WATERLINE_FULL_PERCENTILE), 0, sorted.size() - 1)
	waterline_full = sorted[full_index]
	waterline_dry = height_min - WATERLINE_DRY_MARGIN

	# 1) 大占地道具：石头/石岸写遮挡（它们会挡住积水）。
	_stamp_blockers()
	# 2) 灯柱也先占 1×1 格（模拟普通摆放）。
	for lamp in RainLayout.LAMPS:
		var cell: Vector2i = RainLayout.lamp_cell(lamp)
		lamp_cells.append(cell)
		_stamp_cell_flag(cell, lamp_flag, 1)
	# 3) 细灯柱规则：发光、1×1、非边界 → 放行积水，清掉遮挡。
	_apply_thin_lamp_rule()
	_collect_spawn_points()
	_texture = _build_texture()
	generated.emit()


func _stamp_blockers() -> void:
	var cells: Dictionary = {}
	for rock in RainLayout.ROCK_CLUSTERS:
		var c: Vector2 = rock["pos"]
		var rx: float = rock["rx"]
		var ry: float = rock["ry"]
		_stamp_ellipse_cells(c, rx, ry, cells, rock_cells)
	var bank_c: Vector2 = RainLayout.STONE_BANK["pos"]
	var bank_rx: float = RainLayout.STONE_BANK["rx"]
	var bank_ry: float = RainLayout.STONE_BANK["ry"]
	_stamp_ellipse_cells(bank_c, bank_rx, bank_ry, cells, bank_cells)
	for key in cells.keys():
		var cell: Vector2i = key
		blocked_cells.append(cell)
		var rect := RainLayout.cell_rect(cell)
		for ty in range(int(rect.position.y / TEX_SCALE), int(rect.end.y / TEX_SCALE)):
			for tx in range(int(rect.position.x / TEX_SCALE), int(rect.end.x / TEX_SCALE)):
				if tx >= 0 and tx < TEX_W and ty >= 0 and ty < TEX_H:
					block[ty * TEX_W + tx] = 1


func _stamp_ellipse_cells(center: Vector2, rx: float, ry: float,
		into: Dictionary, out_list: Array[Vector2i]) -> void:
	var min_cell := RainLayout.world_to_cell(center - Vector2(rx, ry))
	var max_cell := RainLayout.world_to_cell(center + Vector2(rx, ry))
	for cy in range(min_cell.y, max_cell.y + 1):
		for cx in range(min_cell.x, max_cell.x + 1):
			var cell := Vector2i(cx, cy)
			if cell.x < 0 or cell.y < 0 or cell.x >= 40 or cell.y >= 23:
				continue
			var p := (Vector2(cell) + Vector2(0.5, 0.5)) * RainLayout.RULE_CELL
			var q := pow((p.x - center.x) / rx, 2.0) + pow((p.y - center.y) / ry, 2.0)
			if q <= 1.0:
				into[cell] = true
				if not out_list.has(cell):
					out_list.append(cell)


func _stamp_cell_flag(cell: Vector2i, target: PackedByteArray, value: int) -> void:
	var rect := RainLayout.cell_rect(cell)
	for ty in range(int(rect.position.y / TEX_SCALE), int(rect.end.y / TEX_SCALE)):
		for tx in range(int(rect.position.x / TEX_SCALE), int(rect.end.x / TEX_SCALE)):
			if tx >= 0 and tx < TEX_W and ty >= 0 and ty < TEX_H:
				target[ty * TEX_W + tx] = value


func _apply_thin_lamp_rule() -> void:
	# 规则：EmitsLight && 1×1 格 && 非房间边界 → 放行积水。
	for cell in lamp_cells:
		var rect := RainLayout.cell_rect(cell)
		for ty in range(int(rect.position.y / TEX_SCALE), int(rect.end.y / TEX_SCALE)):
			for tx in range(int(rect.position.x / TEX_SCALE), int(rect.end.x / TEX_SCALE)):
				if tx >= 0 and tx < TEX_W and ty >= 0 and ty < TEX_H:
					block[ty * TEX_W + tx] = 0
		blocked_cells.erase(cell)
		rock_cells.erase(cell)
		bank_cells.erase(cell)


func _collect_spawn_points() -> void:
	spawn_points.clear()
	var limit := waterline_full - RIPPLE_SPAWN_INSET
	for ty in range(1, TEX_H - 1, 2):
		for tx in range(1, TEX_W - 1, 2):
			var i := ty * TEX_W + tx
			if height[i] >= limit or block[i] == 1:
				continue
			spawn_points.append(Vector2((float(tx) + 0.5) * TEX_SCALE,
					(float(ty) + 0.5) * TEX_SCALE))


func _build_texture() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(TEX_W * TEX_H * 4)
	for i in TEX_W * TEX_H:
		var o := i * 4
		data[o] = int(round(clampf(height[i], 0.0, 1.0) * 255.0))
		data[o + 1] = 255 if block[i] == 1 else 0
		data[o + 2] = 255 if lamp_flag[i] == 1 else 0
		data[o + 3] = int(round(clampf(edge[i], 0.0, 1.0) * 255.0))
	var img := Image.create_from_data(TEX_W, TEX_H, false, Image.FORMAT_RGBA8, data)
	return ImageTexture.create_from_image(img)


# ── 查询（CPU 与 shader 同构） ────────────────────────────────────────────
func get_field_texture() -> ImageTexture:
	return _texture


func waterline_at(wet: float) -> float:
	# 0.40 次幂：前 1/3 时间先漫过深盆，后段慢慢啃浅边，
	# 让 22s 的积水过程在画面上持续可读（时间口径不变）。
	var t := pow(clampf(wet, 0.0, 1.0), 0.40)
	return lerpf(waterline_dry, waterline_full, t)


func mask_from_texel(tx: int, ty: int, waterline: float) -> float:
	if tx < 0 or ty < 0 or tx >= TEX_W or ty >= TEX_H:
		return 0.0
	var i := ty * TEX_W + tx
	if block[i] == 1:
		return 0.0
	var d := waterline - height[i] + (edge[i] - 0.5) * EDGE_JITTER
	return smoothstep(0.0, EDGE_SOFT, d)


func mask_at_world(pos: Vector2, wet: float) -> float:
	var tx := clampi(int(pos.x / TEX_SCALE), 0, TEX_W - 1)
	var ty := clampi(int(pos.y / TEX_SCALE), 0, TEX_H - 1)
	return mask_from_texel(tx, ty, waterline_at(wet))


func water_fraction(wet: float) -> float:
	var wl := waterline_at(wet)
	var wet_count := 0
	var total := 0
	for ty in range(0, TEX_H, 2):
		for tx in range(0, TEX_W, 2):
			total += 1
			if mask_from_texel(tx, ty, wl) > 0.5:
				wet_count += 1
	return float(wet_count) / float(total)


func is_blocked(cell: Vector2i) -> bool:
	return blocked_cells.has(cell)


func is_lamp_cell(cell: Vector2i) -> bool:
	return lamp_cells.has(cell)


func lamp_permeable(cell: Vector2i) -> bool:
	# 灯柱规则：只要它在 1×1 灯柱列表里，就允许该格积水。
	return is_lamp_cell(cell) and not is_blocked(cell)


func lamp_rule_report() -> Array:
	var out: Array = []
	for lamp in RainLayout.LAMPS:
		var cell: Vector2i = RainLayout.lamp_cell(lamp)
		out.append({
			"cell": cell,
			"width": 1,
			"emits_light": true,
			"permeable": lamp_permeable(cell),
			"water_at_full": mask_at_world(lamp["pos"], 1.0) > 0.5,
		})
	return out


func percent_covered_by_lamps_at_full() -> int:
	var n := 0
	for lamp in RainLayout.LAMPS:
		var cell: Vector2i = RainLayout.lamp_cell(lamp)
		var c := (Vector2(cell) + Vector2(0.5, 0.5)) * RainLayout.RULE_CELL
		if mask_at_world(c, 1.0) > 0.5:
			n += 1
	return n


func pick_spawn_point(rng: RandomNumberGenerator, waterline: float) -> Vector2:
	if spawn_points.is_empty():
		return Vector2(-1.0, -1.0)
	for _attempt in 10:
		var p := spawn_points[rng.randi_range(0, spawn_points.size() - 1)]
		var tx := int(p.x / TEX_SCALE)
		var ty := int(p.y / TEX_SCALE)
		if mask_from_texel(tx, ty, waterline) > 0.35:
			return p
	return Vector2(-1.0, -1.0)


func get_texture_size() -> Vector2i:
	return Vector2i(TEX_W, TEX_H)
