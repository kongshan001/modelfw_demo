class_name ShadowBuilder
extends RefCounted

# 约 40 行核心的「顶点坍缩」等价实现：
#   1. 每个物体有一条贴地足迹 + 若干高度层（树干、树冠、屋檐…）。
#   2. 每个高度层按 h/H × 总影长 沿影向平移；高处顶点偏移更大。
#   3. 所有层与足迹求凸包 = 背光边坍缩、迎光边锚在接触点。
#   4. 所有凸包做多边形并集，同高度取 max，合并成一份网格、一次绘制。
# 并集保证重叠树影只覆盖一次 alpha，不会出现 2D 半透明贴片叠黑。
# 高度颜色写进顶点色，供 shader 做 2.5D 接收面遮挡测试。

var casters: Array[Dictionary] = []
var merged: Array[Dictionary] = []
var mesh: ArrayMesh
var reports: Array[Dictionary] = []
var stats: Dictionary = {}


func setup(caster_specs: Array[Dictionary]) -> void:
	casters = caster_specs


func update(state: Dictionary, soft_knee: bool) -> void:
	var elevation := maxf(float(state.get("elevation", 45.0)), 1.0)
	var direction: Vector2 = state.get("shadow_dir", Vector2.DOWN)
	var raw_items: Array[Dictionary] = []
	reports.clear()
	for caster in casters:
		var height := float(caster["height"])
		var base: Vector2 = caster["base"]
		var raw_length := LightModel.raw_shadow_length(height, elevation)
		var length := LightModel.shadow_length(height, elevation, soft_knee)
		var cap := LightModel.shadow_cap(height)
		var knee := LightModel.shadow_knee(height)
		var points := PackedVector2Array()
		var footprint: PackedVector2Array = caster["footprint"]
		for p in footprint:
			points.append(base + p)
		var band_offsets: Array[float] = []
		var bands: Array = caster.get("bands", [])
		for band in bands:
			var band_h := float(band["h"])
			var offset_len := LightModel.band_offset(length, band_h, height)
			band_offsets.append(offset_len)
			var offset := direction * offset_len
			var poly: PackedVector2Array = band["poly"]
			for p in poly:
				points.append(base + p + offset)
		if footprint.size() + bands.size() * 3 < 3:
			continue
		var hull := _clean_poly(Geometry2D.convex_hull(points))
		if hull.size() < 3:
			continue
		var area := absf(_poly_area(hull))
		if area < 0.5:
			continue
		raw_items.append({"poly": hull, "height": height, "name": caster["name"]})
		reports.append({
			"name": caster["name"],
			"base": base,
			"height": height,
			"height01": LightModel.height_norm(height),
			"elevation": elevation,
			"raw_length": raw_length,
			"length": length,
			"cap": cap,
			"knee": knee,
			"soft_knee": soft_knee,
			"compressed": raw_length > knee + 0.001,
			"direction": direction,
			"tip": base + direction * length,
			"band_offsets": band_offsets,
			"hull_vertices": hull.size(),
			"hull_area": area,
		})
	_merge_items(raw_items)
	_build_mesh()
	var total_area := 0.0
	var tri_vertices := 0
	for item in merged:
		total_area += absf(_poly_area(item["poly"]))
		var tri := Geometry2D.triangulate_polygon(item["poly"])
		tri_vertices += tri.size()
	stats = {
		"casters": casters.size(),
		"raw_hulls": raw_items.size(),
		"union_polygons": merged.size(),
		"vertices": tri_vertices,
		"area": total_area,
		"raw_area": _sum_area(raw_items),
		"draw_layers": 1,
		"single_mesh": true,
		"overlap_merged": merged.size() < raw_items.size(),
	}


func _merge_items(raw_items: Array[Dictionary]) -> void:
	var out: Array[Dictionary] = []
	var queue: Array[Dictionary] = raw_items.duplicate()
	var guard := 0
	while not queue.is_empty() and guard < 512:
		guard += 1
		var item: Dictionary = queue.pop_back()
		var poly: PackedVector2Array = item["poly"]
		var h := float(item["height"])
		var hit := -1
		for i in out.size():
			if _polys_overlap(poly, out[i]["poly"]):
				hit = i
				break
		if hit < 0:
			out.append({"poly": poly, "height": h})
			continue
		var other: Dictionary = out[hit]
		out.remove_at(hit)
		h = maxf(h, float(other["height"]))
		var pieces := Geometry2D.merge_polygons(poly, other["poly"])
		for p in pieces:
			var clean := _clean_poly(p)
			if clean.size() >= 3 and absf(_poly_area(clean)) > 0.5:
				queue.append({"poly": clean, "height": h})
	# 去掉包含关系的重复块，按面积从大到小排序，方便调试。
	out.sort_custom(func(a, b): return absf(_poly_area(a["poly"])) > absf(_poly_area(b["poly"])))
	merged = out


func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for item in merged:
		var poly: PackedVector2Array = item["poly"]
		var h01 := LightModel.height_norm(float(item["height"]))
		var col := Color(h01, h01, h01, 1.0)
		var indices := Geometry2D.triangulate_polygon(poly)
		if indices.is_empty():
			continue
		for idx in indices:
			st.set_color(col)
			st.add_vertex(Vector3(poly[idx].x, poly[idx].y, 0.0))
	mesh = st.commit()


func _sum_area(items: Array[Dictionary]) -> float:
	var a := 0.0
	for it in items:
		a += absf(_poly_area(it["poly"]))
	return a


static func _poly_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func _clean_poly(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or p.distance_to(out[out.size() - 1]) > 0.01:
			out.append(p)
	if out.size() > 1 and out[0].distance_to(out[out.size() - 1]) <= 0.01:
		out.remove_at(out.size() - 1)
	return out


func _polys_overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	var hit := Geometry2D.intersect_polygons(a, b)
	for p in hit:
		if absf(_poly_area(p)) > 0.05:
			return true
	return false


func point_inside_merged(point: Vector2) -> bool:
	for item in merged:
		if Geometry2D.is_point_in_polygon(point, item["poly"]):
			return true
	return false


func coverage_count(point: Vector2) -> int:
	var n := 0
	for item in merged:
		if Geometry2D.is_point_in_polygon(point, item["poly"]):
			n += 1
	return n


func get_stats() -> Dictionary:
	return stats.duplicate(true)


func get_reports() -> Array[Dictionary]:
	return reports.duplicate(true)


func get_merged() -> Array[Dictionary]:
	return merged


func get_mesh() -> ArrayMesh:
	return mesh


# 找一对真实重叠的物体影子，并返回「单影点 / 重叠点」供像素采样验证。
func find_overlap_probe(viewport: Rect2 = Rect2(0, 0, 640, 360),
		prefer_names: Array[String] = []) -> Dictionary:
	var hulls: Array[Dictionary] = []
	for caster in casters:
		var rep: Dictionary = {}
		for r in reports:
			if r["name"] == caster["name"]:
				rep = r
				break
		if rep.is_empty():
			continue
		var elevation := float(rep["elevation"])
		var direction: Vector2 = rep["direction"]
		var height := float(caster["height"])
		var length := float(rep["length"])
		var pts := PackedVector2Array()
		for p in caster["footprint"]:
			pts.append(caster["base"] + p)
		for band in caster.get("bands", []):
			var off := LightModel.band_offset(length, float(band["h"]), height)
			for p in band["poly"]:
				pts.append(caster["base"] + p + direction * off)
		var hull := _clean_poly(Geometry2D.convex_hull(pts))
		if hull.size() >= 3:
			hulls.append({"name": caster["name"], "poly": hull,
					"base": caster["base"]})
	for i in hulls.size():
		for j in range(i + 1, hulls.size()):
			if not prefer_names.is_empty():
				if not prefer_names.has(String(hulls[i]["name"])) 						or not prefer_names.has(String(hulls[j]["name"])):
					continue
			var inter := Geometry2D.intersect_polygons(hulls[i]["poly"], hulls[j]["poly"])
			var best := PackedVector2Array()
			var best_area := 0.0
			for p in inter:
				var ar := absf(_poly_area(p))
				if ar > best_area:
					best_area = ar
					best = p
			if best.size() < 3 or best_area < 12.0:
				continue
			var overlap_pt := _centroid(best)
			if not viewport.has_point(overlap_pt):
				continue
			var single_pt := _find_single_point(hulls[i]["poly"],
					hulls[j]["poly"], viewport)
			if single_pt == Vector2.INF:
				single_pt = _find_single_point(hulls[j]["poly"],
						hulls[i]["poly"], viewport)
			if single_pt == Vector2.INF:
				continue
			return {
				"found": true,
				"pair": [hulls[i]["name"], hulls[j]["name"]],
				"overlap_point": overlap_pt,
				"single_point": single_pt,
				"overlap_area": best_area,
				"overlap_coverage": coverage_count(overlap_pt),
				"single_coverage": coverage_count(single_pt),
			}
	return {"found": false}


func _find_single_point(only_poly: PackedVector2Array, other_poly: PackedVector2Array,
		viewport: Rect2) -> Vector2:
	# 从 only_poly 的边界向质心方向内缩，找一个不在 other 内的点。
	var c := _centroid(only_poly)
	var xs: Array[float] = []
	for p in only_poly:
		xs.append(p.x)
	var ymin := 9999.0
	var ymax := -9999.0
	for p in only_poly:
		ymin = minf(ymin, p.y)
		ymax = maxf(ymax, p.y)
	for k in range(1, 10):
		var t := float(k) / 10.0
		for q in [c.lerp(only_poly[0], t), c.lerp(only_poly[only_poly.size() / 2], t),
				c + Vector2(0.0, -t * (ymax - ymin) * 0.5)]:
			if viewport.has_point(q) and Geometry2D.is_point_in_polygon(q, only_poly) \
					and not Geometry2D.is_point_in_polygon(q, other_poly):
				return q.floor() + Vector2(0.5, 0.5)
	return Vector2.INF


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(float(poly.size()), 1.0)


# 常用足迹 / 高度层。
static func ellipse_poly(cx: float, cy: float, rx: float, ry: float,
		n: int = 14) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		out.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return out


static func rect_poly(w: float, h: float, y_offset := 0.0) -> PackedVector2Array:
	var hw := w * 0.5
	return PackedVector2Array([
		Vector2(-hw, y_offset), Vector2(hw, y_offset),
		Vector2(hw, y_offset - h), Vector2(-hw, y_offset - h)])
