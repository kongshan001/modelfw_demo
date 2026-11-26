class_name WaterPipeline
extends RefCounted

# 水面数据管线（纯 CPU，可无头运行）：
#   1) 手绘水 mask 按 16px 格降采样，每格保留 8×8 子采样覆盖率与桥面裁切；
#   2) 2-Pass 8 邻域倒角距离变换（直向 ×1，斜向 ×1.414）得到连续水深；
#   3) 预分配队列 BFS 找连通水体，按“贴边 + 平均宽度”自动分海 / 河 / 湖；
#      内陆湖（不贴边）写入关海浪 / 关焦散标记；
#   4) 输出 mask / depth / category / flow 四张数据图，另附低洼积水两张。
# 所有 BFS 遍历只复用成员数组，不按格子 new 数组、匿名函数或字典。

const CELL := 16
const CAT_NONE := 0
const CAT_SEA := 1
const CAT_RIVER := 2
const CAT_LAKE := 3
const CAT_PUDDLE := 4

const INF := 9999.0
const DIAG := 1.41421356
const DEPTH_FALLOFF := 3.2
const PUDDLE_FALLOFF := 1.8
const RIVER_MAX_WIDTH := 9.5

var cell := CELL
var cols := 0
var rows := 0
var src_size := Vector2i.ZERO
var bridge_rect := Rect2()
var bridge_cells := 0
var build_ms := 0

var images: Dictionary = {}
var stats: Dictionary = {}
var bodies: Array = []

var _hard := PackedByteArray()
var _conn := PackedByteArray()
var _coverage := PackedFloat32Array()
var _bridge := PackedByteArray()
var _depth_cells := PackedFloat32Array()
var _display_depth := PackedFloat32Array()
var _lowland := PackedByteArray()
var _low_cov := PackedFloat32Array()
var _puddle_depth := PackedFloat32Array()
var _puddle_display := PackedFloat32Array()
var _cat := PackedByteArray()
var _flow_x := PackedFloat32Array()
var _flow_y := PackedFloat32Array()
var _comp := PackedInt32Array()
var _queue := PackedInt32Array()
var _low_queue := PackedInt32Array()


func build(mask_source: Image, cell_size: int = CELL, source_bridge_rect: Rect2 = Rect2()) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	cell = maxi(8, cell_size)
	src_size = mask_source.get_size()
	cols = maxi(1, src_size.x / cell)
	rows = maxi(1, src_size.y / cell)
	bridge_rect = source_bridge_rect
	var total := cols * rows

	_hard.resize(total)
	_conn.resize(total)
	_coverage.resize(total)
	_bridge.resize(total)
	_depth_cells.resize(total)
	_display_depth.resize(total)
	_lowland.resize(total)
	_low_cov.resize(total)
	_puddle_depth.resize(total)
	_puddle_display.resize(total)
	_cat.resize(total)
	_flow_x.resize(total)
	_flow_y.resize(total)
	_comp.resize(total)
	_queue.resize(total)
	_low_queue.resize(total)

	_downsample(mask_source)
	_chamfer_water()
	_chamfer_puddles()
	_classify_and_fill()
	_make_images()
	stats["build_ms"] = 0
	build_ms = (Time.get_ticks_usec() - t0) / 1000
	stats["build_ms"] = build_ms
	return {"images": images, "stats": stats, "bridge_rect": bridge_rect}


func _downsample(src: Image) -> void:
	var data := src.get_data()
	var sw := src.get_width()
	var sh := src.get_height()
	if src.get_format() != Image.FORMAT_RGBA8:
		# 允许调用方传入 L8 / RGB8：统一转 RGBA8，避免逐像素格式分支。
		var conv := src.duplicate()
		conv.convert(Image.FORMAT_RGBA8)
		data = conv.get_data()
		sw = conv.get_width()
		sh = conv.get_height()
	var samples := 8
	var step := float(cell) / float(samples)
	var bridge_total := 0
	for cy in rows:
		for cx in cols:
			var wcount := 0
			var ucount := 0
			var lcount := 0
			var bcount := 0
			for sy in samples:
				var py := int(float(cy * cell) + (float(sy) + 0.5) * step)
				py = clampi(py, 0, sh - 1)
				for sx in samples:
					var px := int(float(cx * cell) + (float(sx) + 0.5) * step)
					px = clampi(px, 0, sw - 1)
					var i := (py * sw + px) * 4
					if data[i] > 127:
						wcount += 1
					if data[i + 3] > 127:
						ucount += 1
					if data[i + 1] > 127:
						lcount += 1
					if data[i + 2] > 127:
						bcount += 1
			var n := float(samples * samples)
			var cov := float(wcount) / n
			var lcov := float(lcount) / n
			var bcov := float(bcount) / n
			var idx := cy * cols + cx
			_bridge[idx] = 1 if bcov >= 0.35 else 0
			if _bridge[idx] == 1:
				bridge_total += 1
				_coverage[idx] = 0.0
				_hard[idx] = 0
				# 桥下有水（mask.A）：BFS 连通与水深把桥格当水，避免河流被桥切断。
				_conn[idx] = 1 if ucount > 0 else 0
			else:
				_coverage[idx] = cov
				_hard[idx] = 1 if cov >= 0.5 else 0
				_conn[idx] = _hard[idx]
			_low_cov[idx] = lcov
			_lowland[idx] = 1 if (lcov >= 0.40 and _hard[idx] == 0 and _bridge[idx] == 0) else 0
	bridge_cells = bridge_total


func _chamfer_water() -> void:
	for i in _hard.size():
		_depth_cells[i] = INF if _conn[i] == 1 else 0.0
	# 正向：左 / 左上 / 上 / 右上。
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if _conn[i] == 0:
				continue
			var d := _depth_cells[i]
			if x > 0:
				d = minf(d, _depth_cells[i - 1] + 1.0)
			if y > 0:
				d = minf(d, _depth_cells[i - cols] + 1.0)
				if x > 0:
					d = minf(d, _depth_cells[i - cols - 1] + DIAG)
				if x < cols - 1:
					d = minf(d, _depth_cells[i - cols + 1] + DIAG)
			_depth_cells[i] = d
	# 反向：右 / 右下 / 下 / 左下。
	for y in range(rows - 1, -1, -1):
		for x in range(cols - 1, -1, -1):
			var i := y * cols + x
			if _conn[i] == 0:
				continue
			var d := _depth_cells[i]
			if x < cols - 1:
				d = minf(d, _depth_cells[i + 1] + 1.0)
			if y < rows - 1:
				d = minf(d, _depth_cells[i + cols] + 1.0)
				if x < cols - 1:
					d = minf(d, _depth_cells[i + cols + 1] + DIAG)
				if x > 0:
					d = minf(d, _depth_cells[i + cols - 1] + DIAG)
			_depth_cells[i] = d
	for i in _hard.size():
		var d := minf(_depth_cells[i], 40.0)
		_depth_cells[i] = d
		if _conn[i] == 1:
			_display_depth[i] = 1.0 - exp(-d / DEPTH_FALLOFF)
		else:
			_display_depth[i] = 0.0


func _chamfer_puddles() -> void:
	for i in _lowland.size():
		_puddle_depth[i] = INF if _lowland[i] == 1 else 0.0
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if _lowland[i] == 0:
				continue
			var d := _puddle_depth[i]
			if x > 0:
				d = minf(d, _puddle_depth[i - 1] + 1.0)
			if y > 0:
				d = minf(d, _puddle_depth[i - cols] + 1.0)
				if x > 0:
					d = minf(d, _puddle_depth[i - cols - 1] + DIAG)
				if x < cols - 1:
					d = minf(d, _puddle_depth[i - cols + 1] + DIAG)
			_puddle_depth[i] = d
	for y in range(rows - 1, -1, -1):
		for x in range(cols - 1, -1, -1):
			var i := y * cols + x
			if _lowland[i] == 0:
				continue
			var d := _puddle_depth[i]
			if x < cols - 1:
				d = minf(d, _puddle_depth[i + 1] + 1.0)
			if y < rows - 1:
				d = minf(d, _puddle_depth[i + cols] + 1.0)
				if x < cols - 1:
					d = minf(d, _puddle_depth[i + cols + 1] + DIAG)
				if x > 0:
					d = minf(d, _puddle_depth[i + cols - 1] + DIAG)
			_puddle_depth[i] = d
	for i in _lowland.size():
		var d := minf(_puddle_depth[i], 40.0)
		_puddle_depth[i] = d
		_puddle_display[i] = (1.0 - exp(-d / PUDDLE_FALLOFF)) if _lowland[i] == 1 else 0.0


func _classify_and_fill() -> void:
	_comp.fill(-1)
	_cat.fill(CAT_NONE)
	_flow_x.fill(0.0)
	_flow_y.fill(0.0)
	bodies.clear()
	var water_total := 0
	for i in _hard.size():
		if _hard[i] == 1:
			water_total += 1
	var comp_id := 0
	for y in rows:
		for x in cols:
			var seed_i := y * cols + x
			if _conn[seed_i] == 0 or _comp[seed_i] >= 0:
				continue
			# ── 预分配队列 BFS（8 邻域） ─────────────────────────────
			var head := 0
			var tail := 0
			_queue[tail] = seed_i
			tail += 1
			_comp[seed_i] = comp_id
			var area := 0
			var hard_area := 0
			var border := false
			var min_x := cols
			var max_x := -1
			var min_y := rows
			var max_y := -1
			var sum_x := 0.0
			var sum_y := 0.0
			var sxx := 0.0
			var sxy := 0.0
			var syy := 0.0
			var max_depth := 0.0
			while head < tail:
				var i := _queue[head]
				head += 1
				area += 1
				var cx := i % cols
				var cy := i / cols
				min_x = mini(min_x, cx)
				max_x = maxi(max_x, cx)
				min_y = mini(min_y, cy)
				max_y = maxi(max_y, cy)
				if cx == 0 or cy == 0 or cx == cols - 1 or cy == rows - 1:
					border = true
				if _hard[i] == 1:
					hard_area += 1
				var fx := float(cx)
				var fy := float(cy)
				sum_x += fx
				sum_y += fy
				sxx += fx * fx
				sxy += fx * fy
				syy += fy * fy
				max_depth = maxf(max_depth, _depth_cells[i])
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if ox == 0 and oy == 0:
							continue
						var nx := cx + ox
						var ny := cy + oy
						if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
							continue
						var ni := ny * cols + nx
						if _conn[ni] == 0 or _comp[ni] >= 0:
							continue
						_comp[ni] = comp_id
						_queue[tail] = ni
						tail += 1
			var bbox_w := max_x - min_x + 1
			var bbox_h := max_y - min_y + 1
			var avg_width := float(area) / float(maxi(maxi(bbox_w, bbox_h), 1))
			var cat := CAT_SEA
			if not border:
				cat = CAT_LAKE
			elif avg_width < RIVER_MAX_WIDTH:
				cat = CAT_RIVER
			# 主轴：协方差最大特征向量；河流方向取下游（+x / +y）。
			var n := float(area)
			var mx := sum_x / n
			var my := sum_y / n
			var cxx := sxx / n - mx * mx
			var cxy := sxy / n - mx * my
			var cyy := syy / n - my * my
			var theta := 0.5 * atan2(2.0 * cxy, cxx - cyy)
			var axis := Vector2(cos(theta), sin(theta))
			if absf(axis.x) >= absf(axis.y):
				if axis.x < 0.0:
					axis = -axis
			elif axis.y < 0.0:
				axis = -axis
			# 类别 / 流动写入（只遍历本分量刚生成的队列区间）。
			for k in tail:
				var i := _queue[k]
				_cat[i] = cat
				var flow := Vector2.ZERO
				if cat == CAT_SEA:
					flow = _sea_flow(i)
				elif cat == CAT_RIVER:
					flow = axis
				_flow_x[i] = flow.x
				_flow_y[i] = flow.y
			var names: Dictionary = {CAT_SEA: "sea", CAT_RIVER: "river", CAT_LAKE: "lake"}
			var labels: Dictionary = {CAT_SEA: "海域", CAT_RIVER: "河流", CAT_LAKE: "内陆湖"}
			var type_name: String = names[cat]
			var label: String = labels[cat]
			var body := {
				"id": comp_id,
				"type": type_name,
				"label": label,
				"cat": cat,
				"cells": hard_area,
				"coverage": float(hard_area) / float(maxi(water_total, 1)),
				"pct": 100.0 * float(hard_area) / float(maxi(cols * rows, 1)),
				"enclosed": not border,
				"waves": cat != CAT_LAKE,
				"caustics": cat != CAT_LAKE,
				"avg_width": avg_width,
				"max_depth": max_depth,
				"center": Vector2((min_x + max_x + 1) * 0.5 * cell, (min_y + max_y + 1) * 0.5 * cell),
			}
			bodies.append(body)
			comp_id += 1
	# 低洼积水类别（不参与海/河/湖分类，但复用同一 shader 与深度逻辑）。
	for i in _lowland.size():
		if _lowland[i] == 1:
			_cat[i] = CAT_PUDDLE
			_flow_x[i] = 0.0
			_flow_y[i] = 0.0
	var puddle_cells := 0
	for v in _lowland:
		puddle_cells += v
	var lake_count := 0
	var lake_caustic_off := false
	for b in bodies:
		if b["type"] == "lake":
			lake_count += 1
			lake_caustic_off = not b["caustics"] or lake_caustic_off
	stats = {
		"cell": cell,
		"cols": cols,
		"rows": rows,
		"source": [src_size.x, src_size.y],
		"bridge_cells": bridge_cells,
		"bridge_rect": [bridge_rect.position.x, bridge_rect.position.y, bridge_rect.size.x, bridge_rect.size.y],
		"water_cells": water_total,
		"water_pct": 100.0 * float(water_total) / float(maxi(cols * rows, 1)),
		"puddle_cells": puddle_cells,
		"puddle_pct": 100.0 * float(puddle_cells) / float(maxi(cols * rows, 1)),
		"bodies": bodies.duplicate(true),
		"body_count": bodies.size(),
		"lake_count": lake_count,
		"lake_caustic_off": lake_caustic_off,
		"waves": {"sea": true, "river": true, "lake": false},
		"caustics": {"sea": true, "river": true, "lake": false},
	}


func _sea_flow(i: int) -> Vector2:
	var x := i % cols
	var y := i / cols
	var dx := 0.0
	var dy := 0.0
	if x > 0 and x < cols - 1:
		dx = (_depth_cells[i + 1] - _depth_cells[i - 1]) * 0.5
	if y > 0 and y < rows - 1:
		dy = (_depth_cells[i + cols] - _depth_cells[i - cols]) * 0.5
	var onshore := Vector2(1.0, 0.16) - Vector2(dx, dy) * 0.55
	if onshore.length_squared() < 0.001:
		onshore = Vector2(1.0, 0.1)
	return onshore.normalized()


func _make_images() -> void:
	var mask_img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var depth_img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var cat_img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var flow_img := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var p_mask := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	var p_depth := Image.create(cols, rows, false, Image.FORMAT_RGBA8)
	for y in rows:
		for x in cols:
			var i := y * cols + x
			mask_img.set_pixel(x, y, Color(
				float(_hard[i]), _coverage[i], float(_bridge[i]), 1.0))
			depth_img.set_pixel(x, y, Color(
				_display_depth[i], clampf(_depth_cells[i] / 16.0, 0.0, 1.0), 0.0, 1.0))
			cat_img.set_pixel(x, y, Color(float(_cat[i]) * 0.25, 0.0, 0.0, 1.0))
			flow_img.set_pixel(x, y, Color(
				_flow_x[i] * 0.5 + 0.5, _flow_y[i] * 0.5 + 0.5, 0.5, 1.0))
			p_mask.set_pixel(x, y, Color(float(_lowland[i]), _low_cov[i], 0.0, 1.0))
			p_depth.set_pixel(x, y, Color(
				_puddle_display[i], clampf(_puddle_depth[i] / 16.0, 0.0, 1.0), 0.0, 1.0))
	images = {
		"mask": mask_img,
		"depth": depth_img,
		"category": cat_img,
		"flow": flow_img,
		"puddle_mask": p_mask,
		"puddle_depth": p_depth,
	}


func save_to(dir_path: String) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	var hashes := {}
	for key in images.keys():
		var img: Image = images[key]
		var path := dir_path.path_join("%s.png" % key)
		img.save_png(path)
		hashes[key] = _sha256(img)
	stats["hashes"] = hashes
	var meta := {
		"cell": cell, "cols": cols, "rows": rows,
		"source": [src_size.x, src_size.y],
		"bridge_cells": bridge_cells,
		"water_cells": stats.get("water_cells", 0),
		"puddle_cells": stats.get("puddle_cells", 0),
		"body_count": stats.get("body_count", 0),
		"lake_count": stats.get("lake_count", 0),
		"lake_caustic_off": stats.get("lake_caustic_off", false),
		"hashes": hashes,
		"bodies": _bodies_json(),
	}
	var f := FileAccess.open(dir_path.path_join("meta.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta, "  "))
		f.close()
	return {"dir": dir_path, "hashes": hashes, "meta": meta}


func _bodies_json() -> Array:
	var arr := []
	for b in bodies:
		var c: Vector2 = b["center"]
		arr.append({
			"type": b["type"], "label": b["label"], "cells": b["cells"],
			"pct": b["pct"], "enclosed": b["enclosed"],
			"avg_width": b["avg_width"], "max_depth": b["max_depth"],
			"center": [c.x, c.y],
		})
	return arr


# ── 查询（供 smoke / HUD 使用） ──────────────────────────────────────────
func cell_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / cell), int(world_pos.y / cell))


func hard_at(world_pos: Vector2) -> bool:
	return get_hard(cell_at(world_pos))


func get_hard(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return false
	return _hard[c.y * cols + c.x] == 1


func get_coverage(c: Vector2i) -> float:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return 0.0
	return _coverage[c.y * cols + c.x]


func get_depth_cells(c: Vector2i) -> float:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return 0.0
	return _depth_cells[c.y * cols + c.x]


func get_display_depth(c: Vector2i) -> float:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return 0.0
	return _display_depth[c.y * cols + c.x]


func get_category(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return CAT_NONE
	return _cat[c.y * cols + c.x]


func get_flow(c: Vector2i) -> Vector2:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return Vector2.ZERO
	var i := c.y * cols + c.x
	return Vector2(_flow_x[i], _flow_y[i])


func get_lowland(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return false
	return _lowland[c.y * cols + c.x] == 1


func is_bridge_cell(c: Vector2i) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return false
	return _bridge[c.y * cols + c.x] == 1


func is_under_bridge_water(c: Vector2i) -> bool:
	if not is_bridge_cell(c):
		return false
	return _conn[c.y * cols + c.x] == 1


func get_puddle_depth(c: Vector2i) -> float:
	if c.x < 0 or c.y < 0 or c.x >= cols or c.y >= rows:
		return 0.0
	return _puddle_display[c.y * cols + c.x]


func images_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for key in ["mask", "depth", "category", "flow", "puddle_mask", "puddle_depth"]:
		ctx.update(images[key].get_data())
	return ctx.finish().hex_encode()


func _sha256(img: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(img.get_data())
	return ctx.finish().hex_encode()


func body_of_type(type_name: String) -> Dictionary:
	for b in bodies:
		if b["type"] == type_name:
			return b
	return {}
