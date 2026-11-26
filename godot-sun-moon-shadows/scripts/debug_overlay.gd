class_name ShadowDebugOverlay
extends Node2D

# 影子调试层：并集网格线框、单影/重影采样十字、投影方向。
# 不参与正常渲染；只有 F3 调试面板里的开关会打开它。

var world: Node


static func _heat(h: float) -> Color:
	if h < 0.25:
		return Color(0.10, 0.22, 0.55).lerp(Color(0.10, 0.70, 0.75), h / 0.25)
	if h < 0.55:
		return Color(0.10, 0.70, 0.75).lerp(Color(0.95, 0.88, 0.30), (h - 0.25) / 0.30)
	return Color(0.95, 0.88, 0.30).lerp(Color(0.95, 0.28, 0.24), (h - 0.55) / 0.45)


func _draw() -> void:
	if world == null:
		return
	if world.is_debug_flag("mesh"):
		var merged: Array = world.shadow_rig.get_merged() if world.shadow_rig else []
		for item in merged:
			var poly: PackedVector2Array = item["poly"]
			if poly.size() < 3:
				continue
			var closed := poly.duplicate()
			closed.append(poly[0])
			draw_polyline(closed, Color(0.42, 0.95, 1.0, 0.95), 1.0)
			# 顶点色高度对应的颜色点。
			var h01 := LightModel.height_norm(float(item["height"]))
			var c := _heat(h01)
			draw_circle(poly[0], 1.5, c)
		for rep in world.get_shadow_reports():
			var base: Vector2 = rep["base"]
			var tip: Vector2 = rep["tip"]
			draw_line(base, tip, Color(1.0, 0.86, 0.35, 0.45), 1.0)
			draw_rect(Rect2(base - Vector2(2, 2), Vector2(4, 4)),
					Color(1.0, 0.86, 0.35, 0.9), false, 1.0)
	if world.is_debug_flag("overlap"):
		var probe: Dictionary = world.get_overlap_probe()
		if bool(probe.get("found", false)):
			_cross(probe["single_point"], Color(0.35, 1.0, 1.0, 1.0), 5)
			_cross(probe["overlap_point"], Color(1.0, 0.82, 0.25, 1.0), 5)
			draw_line(probe["single_point"], probe["overlap_point"],
					Color(1.0, 1.0, 1.0, 0.35), 1.0)
	if world.is_debug_flag("heightmap"):
		# 高度图边缘框与 0.25 / 0.5 / 0.75 标尺。
		draw_rect(Rect2(8, 8, 624, 344), Color(1.0, 0.9, 0.5, 0.35), false, 1.0)
		for i in 4:
			var y := 18.0 + float(i) * 10.0
			var h := 1.0 - float(i) * 0.25
			draw_rect(Rect2(12, y, 8, 3), _heat(h))


func _cross(pos: Vector2, color: Color, r: int) -> void:
	draw_line(pos + Vector2(-r, 0), pos + Vector2(r, 0), color, 1.0)
	draw_line(pos + Vector2(0, -r), pos + Vector2(0, r), color, 1.0)
	draw_rect(Rect2(pos - Vector2(r + 2, r + 2), Vector2(r * 2 + 4, r * 2 + 4)),
			color, false, 1.0)
