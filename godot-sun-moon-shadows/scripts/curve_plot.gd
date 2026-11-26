class_name KneeCurvePlot
extends Control

# 影长曲线：横轴高度角 0..45°，纵轴 0..3H。
# 同时画「软膝」和「硬截断」两条曲线，当前开关加粗；60% 膝点与 3H 上限标出。
# 物体高度归一化为 1H，所以曲线与具体物体无关。

const H := 1.0
const X_MAX := 45.0
const Y_MAX := 3.15

var main: Node
var font: Font


func _ready() -> void:
	custom_minimum_size = Vector2(158, 88)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	if main == null:
		return
	var r := Rect2(2, 2, size.x - 4, size.y - 4)
	draw_rect(r, Color(0.035, 0.055, 0.075, 0.88), true)
	draw_rect(r, Color(0.32, 0.52, 0.55, 0.8), false, 1.0)
	var plot := Rect2(r.position + Vector2(20, 8), r.size - Vector2(28, 22))
	# 网格。
	for i in 4:
		var y := plot.position.y + plot.size.y * float(i) / 3.0
		draw_line(Vector2(plot.position.x, y),
				Vector2(plot.end.x, y), Color(0.24, 0.38, 0.40, 0.35), 1.0)
	for i in 4:
		var x := plot.position.x + plot.size.x * float(i) / 3.0
		draw_line(Vector2(x, plot.position.y),
				Vector2(x, plot.end.y), Color(0.24, 0.38, 0.40, 0.28), 1.0)

	var soft: bool = main.is_soft_knee()
	var soft_pts := PackedVector2Array()
	var hard_pts := PackedVector2Array()
	var steps := 80
	for i in steps + 1:
		var e := X_MAX * float(i) / float(steps)
		var ls := LightModel.shadow_length(H, maxf(e, 0.35), true)
		var lh := LightModel.shadow_length(H, maxf(e, 0.35), false)
		soft_pts.append(_map(plot, e, ls))
		hard_pts.append(_map(plot, e, lh))
	# 硬截断曲线用虚线，软膝曲线用实线；当前模式更亮。
	draw_polyline(hard_pts, Color(0.55, 0.38, 0.34, 0.55 if soft else 0.95), 1.0)
	draw_polyline(soft_pts, Color(0.42, 0.95, 0.72, 0.95 if soft else 0.32), 1.0)

	# 60% 膝点与 3H 上限。
	var knee_y := _map(plot, 0.0, 1.8).y
	var cap_y := _map(plot, 0.0, 3.0).y
	draw_dashed_line(Vector2(plot.position.x, knee_y),
			Vector2(plot.end.x, knee_y), Color(1.0, 0.82, 0.35, 0.75), 1.0, 3.0)
	draw_dashed_line(Vector2(plot.position.x, cap_y),
			Vector2(plot.end.x, cap_y), Color(0.95, 0.42, 0.35, 0.6), 1.0, 2.0)
	var knee_e := rad_to_deg(atan(1.0 / 1.8))
	var kx := _map(plot, knee_e, 0.0).x
	draw_line(Vector2(kx, plot.position.y), Vector2(kx, plot.end.y),
			Color(1.0, 0.82, 0.35, 0.38), 1.0)

	# 当前主光高度角。
	var solar: Dictionary = main.get_solar()
	var elev := float(solar.get("elevation", 0.0))
	if elev >= 0.0 and elev <= X_MAX:
		var cur_len := LightModel.shadow_length(H, maxf(elev, 0.35), soft)
		var cp := _map(plot, elev, cur_len)
		draw_line(Vector2(cp.x, plot.position.y), Vector2(cp.x, plot.end.y),
				Color(0.9, 0.95, 1.0, 0.25), 1.0)
		draw_circle(cp, 2.2, Color(1.0, 0.95, 0.65, 1.0))

	if font != null:
		var small := 10
		draw_string(font, Vector2(plot.position.x, r.end.y - 4),
				"0°", HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				Color(0.62, 0.72, 0.72, 1.0))
		draw_string(font, Vector2(plot.end.x - 16, r.end.y - 4),
				"45°", HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				Color(0.62, 0.72, 0.72, 1.0))
		draw_string(font, Vector2(r.position.x + 2, plot.position.y + 8),
				"3H", HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				Color(0.72, 0.56, 0.50, 1.0))
		draw_string(font, Vector2(r.position.x + 1, knee_y + 3),
				"1.8", HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				Color(0.86, 0.70, 0.35, 1.0))
		var tag := "软膝" if soft else "硬截"
		draw_string(font, Vector2(plot.end.x - 26, plot.position.y + 8),
				tag, HORIZONTAL_ALIGNMENT_LEFT, -1, small,
				Color(0.55, 0.95, 0.76, 1.0) if soft
						else Color(0.90, 0.62, 0.50, 1.0))


func _map(plot: Rect2, elevation: float, length: float) -> Vector2:
	var x := clampf(elevation / X_MAX, 0.0, 1.0)
	var y := clampf(length / Y_MAX, 0.0, 1.0)
	return Vector2(plot.position.x + x * plot.size.x,
			plot.end.y - y * plot.size.y)
