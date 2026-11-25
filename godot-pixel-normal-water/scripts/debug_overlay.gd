class_name NormalWaterDebugOverlay
extends Node2D

# 调试叠加（世界坐标绘制，4× 相机放大会成为硬边像素图）：
#   - 右上角光向量箭头与冷月方向；
#   - 每个倒影四边形的青色线框；
#   - 水面 mask 上缘的黄色折线；
#   - 左侧若干行的 round() 量化水波取样刻度。
# 法线本身由 lit_sprite.gdshader 的 u_debug_mode=1 输出到全屏物件上。

var reflection: NormalWaterReflection
var mask_image: Image
var light_dir := Vector2(0.574, -0.819)
var light_angle_deg := 35.0
var light_energy := 1.18
var time_value := 0.0
var waterline := 120.0
var wave_step := 1.0
var amplitude := 2.0
var wave_speed := 1.0
var mode := 0

var _shoreline := PackedVector2Array()
var _font: Font

const CYAN := Color(0.38, 0.90, 0.86, 0.82)
const CYAN_DIM := Color(0.28, 0.64, 0.62, 0.42)
const GOLD := Color(1.0, 0.78, 0.33, 0.90)
const ROSE := Color(1.0, 0.46, 0.39, 0.90)


func setup(reflection_node: NormalWaterReflection, mask: Image, water_y: float) -> void:
	reflection = reflection_node
	mask_image = mask
	waterline = water_y
	_font = ThemeDB.fallback_font
	_build_shoreline()
	z_index = 90
	visible = false


func _build_shoreline() -> void:
	_shoreline.clear()
	if mask_image == null:
		return
	for x in mask_image.get_width():
		var first := -1
		for y in range(int(waterline) - 2, mask_image.get_height()):
			if mask_image.get_pixel(x, y).a >= 0.5:
				first = y
				break
		if first >= 0:
			_shoreline.append(Vector2(float(x) + 0.5, float(first) + 0.5))


func sync(angle_deg: float, energy: float, t: float, wave_speed_value: float,
		amplitude_value: float, step_value: float) -> void:
	light_angle_deg = angle_deg
	light_energy = energy
	time_value = t
	wave_speed = wave_speed_value
	amplitude = amplitude_value
	wave_step = maxf(1.0, step_value)
	var a := deg_to_rad(angle_deg)
	light_dir = Vector2(sin(a), -cos(a))
	queue_redraw()


func set_debug_mode(value: int) -> void:
	mode = value
	queue_redraw()


func _draw() -> void:
	if _font == null:
		_font = ThemeDB.fallback_font
	# 水线
	_dashed_hline(Vector2(0, waterline), 320.0, Color(0.34, 0.72, 0.70, 0.25), 6, 4)
	# mask 上缘
	if _shoreline.size() > 1:
		draw_polyline(_shoreline, Color(1.0, 0.80, 0.34, 0.72), 1.0, false)
	# 倒影四边形线框
	if reflection != null:
		for quad in reflection.get_quads():
			if quad.size() >= 4:
				draw_polyline(PackedVector2Array([
					quad[0], quad[1], quad[2], quad[3], quad[0]
				]), CYAN, 1.0, false)
	# 水波量化刻度：开阔水面上每 4 行取一次，横线向左/右跳整格
	for i in 14:
		var y := int(waterline) + 3 + i * 4
		if y >= 178:
			break
		var shift: int = reflection.quantized_shift(y, time_value) if reflection != null else 0
		var x0 := 120 + shift * 4
		var len := 28
		var c := CYAN_DIM
		if absi(shift) > 0:
			c = Color(0.48, 0.86, 0.72, 0.65)
		draw_line(Vector2(x0, y), Vector2(x0 + len, y), c, 1.0)
		if i % 3 == 0:
			draw_line(Vector2(x0, y - 1), Vector2(x0, y + 1), c, 1.0)
	# 光向量（顶部中央，UI 面板展开时也不遮挡；具体数值放在 HUD）
	var origin := Vector2(160.0, 23.0)
	var tip := origin + light_dir * 18.0
	draw_line(origin, tip, GOLD, 1.0)
	draw_circle(origin, 2.0, Color(0.94, 0.86, 0.55, 0.9))
	var side := Vector2(-light_dir.y, light_dir.x)
	draw_line(tip, tip - light_dir * 4.0 + side * 2.5, GOLD, 1.0)
	draw_line(tip, tip - light_dir * 4.0 - side * 2.5, GOLD, 1.0)
	draw_arc(origin, 7.0, 0.0, TAU, 16, ROSE, 1.0, false)
	# 法线视图提示标记
	if mode == 1:
		draw_string(_font, Vector2(176, 10), "NORMAL rgb",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.85, 1.0, 0.95, 0.9))
	elif mode == 2:
		draw_string(_font, Vector2(176, 10), "ROUGH r",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color(0.85, 1.0, 0.95, 0.9))


func _dashed_hline(start: Vector2, length: float, color: Color,
		dash: int, gap: int) -> void:
	var x := 0.0
	while x < length:
		draw_line(start + Vector2(x, 0), start + Vector2(minf(x + dash, length), 0),
				color, 1.0)
		x += dash + gap
