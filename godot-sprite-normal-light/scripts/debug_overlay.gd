extends Node2D

# 世界坐标调试层：光半径环、巡游轨迹、每个受光样本点的光向量箭头、
# 光源高度竖杆。仅在调试开关打开时绘制。

const SAMPLE_COLOR := Color(1.0, 0.82, 0.45, 0.9)
const SAMPLE_COLOR_NATIVE := Color(0.55, 0.92, 0.95, 0.9)
const RING_COLOR := Color(1.0, 0.72, 0.36, 0.22)
const ORBIT_COLOR := Color(0.55, 0.72, 0.88, 0.20)

var main: Node


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = mat
	z_index = 30
	set_process(false)


func setup(main_node: Node) -> void:
	main = main_node
	set_process(true)


func _process(_delta: float) -> void:
	if main != null and main.is_debug_enabled():
		queue_redraw()


func _draw() -> void:
	if main == null or not main.is_debug_enabled():
		return
	var point_mode: bool = main.is_point_mode()
	var native: bool = main.is_native_mode()
	var color := SAMPLE_COLOR_NATIVE if native else SAMPLE_COLOR
	var light_pos: Vector2 = main.get_light_pos()
	var height: float = main.get_light_height()

	if point_mode:
		var center: Vector2 = main.get_orbit_center()
		var radius: Vector2 = main.get_orbit_radius()
		var orbit := PackedVector2Array()
		for i in range(65):
			var a := TAU * float(i) / 64.0
			orbit.append(center + Vector2(sin(a) * radius.x, -cos(a) * radius.y))
		draw_polyline(orbit, ORBIT_COLOR, 1.0)
		draw_arc(light_pos, main.get_light_radius(), 0.0, TAU, 72,
				RING_COLOR, 1.0, false)
		draw_line(light_pos, light_pos - Vector2(0, height * 0.22),
				Color(color.r, color.g, color.b, 0.5), 1.0)
		draw_line(light_pos - Vector2(2, 0), light_pos + Vector2(2, 0), color, 1.0)
		draw_line(light_pos - Vector2(0, 2), light_pos + Vector2(0, 2), color, 1.0)
		draw_circle(light_pos, 1.6, color)

	for anchor in main.get_light_sample_points():
		var l: Vector3 = main.get_light_vector_at(anchor)
		var d := Vector2(l.x, l.y)
		if d.length() < 0.001:
			continue
		d = d.normalized()
		var tip: Vector2 = anchor + d * 15.0
		draw_line(anchor, tip, color, 1.0)
		draw_line(tip, tip - d * 4.0 + Vector2(-d.y, d.x) * 2.5, color, 1.0)
		draw_line(tip, tip - d * 4.0 - Vector2(-d.y, d.x) * 2.5, color, 1.0)
		draw_circle(anchor, 1.0, Color(color.r, color.g, color.b, 0.6))

	if not point_mode:
		# directional compass: a circle with a long arrow showing L.xy
		var origin := Vector2(206, 72)
		draw_arc(origin, 13.0, 0.0, TAU, 24,
				Color(color.r, color.g, color.b, 0.35), 1.0, false)
		var l2: Vector3 = main.get_light_vector_at(Vector2(206, 110))
		var d2 := Vector2(l2.x, l2.y).normalized()
		draw_line(origin + d2 * 4.0, origin + d2 * 20.0, color, 1.0)
		draw_line(origin + d2 * 20.0, origin + d2 * 15.0 + Vector2(-d2.y, d2.x) * 3.5, color, 1.0)
		draw_line(origin + d2 * 20.0, origin + d2 * 15.0 - Vector2(-d2.y, d2.x) * 3.5, color, 1.0)
