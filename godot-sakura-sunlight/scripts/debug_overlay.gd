class_name SunDebugOverlay
extends Node2D

# F3 调试视图：在 640×360 世界里画出太阳向量、影向、两段影子的
# 分段点和总长度。文字刻意用英文/数字，中文参数在 HUD 面板里。

const GRID := Color(0.86, 0.96, 0.78, 0.10)
const GUIDE := Color(0.96, 0.98, 0.88, 0.55)
const TRUNK_C := Color(1.00, 0.72, 0.28, 0.95)
const CROWN_C := Color(0.32, 0.92, 0.96, 0.95)
const BASE_C := Color(1.00, 0.96, 0.86, 0.95)
const LIGHT_C := Color(1.00, 0.86, 0.46, 1.0)
const SHADOW_C := Color(0.52, 0.72, 1.00, 1.0)

var world: Node


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var data: Dictionary = world.get_debug_data()
	if data.is_empty():
		return
	_draw_grid()
	var reports: Array = data["shadows"]
	var font := ThemeDB.fallback_font

	for r in reports:
		var base: Vector2 = r["base"]
		var direction: Vector2 = r["direction"]
		var tip: Vector2 = base + r["tip"]
		var junction: Vector2 = base + r["junction"]
		draw_dashed_line(base, tip, GUIDE, 1.0, 3.0)
		if bool(r["two_part"]):
			draw_line(base, junction, TRUNK_C, 1.0)
			draw_line(junction, tip, CROWN_C, 1.0)
			draw_circle(junction, 2.0, TRUNK_C)
		else:
			draw_line(base, tip, TRUNK_C, 1.0)
		draw_circle(base, 2.5, BASE_C)
		draw_circle(tip, 2.0, CROWN_C)
		var label := "%s L%.0f" % [r["name"], float(r["total_length"])]
		draw_string(font, tip + Vector2(4.0, -3.0), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 7, GUIDE)
		if bool(r["two_part"]):
			var h := float(r["visual_height"])
			draw_line(base + Vector2(-24.0, 0.0), base + Vector2(-24.0, -h),
					Color(1, 1, 1, 0.45), 1.0)
			draw_line(base + Vector2(-28.0, 0.0), base + Vector2(-20.0, 0.0),
					Color(1, 1, 1, 0.45), 1.0)
			draw_line(base + Vector2(-28.0, -h), base + Vector2(-20.0, -h),
					Color(1, 1, 1, 0.45), 1.0)
			draw_string(font, base + Vector2(-44.0, -h * 0.5), "H%.0f" % h,
					HORIZONTAL_ALIGNMENT_LEFT, -1, 7, GUIDE)

	# 太阳向量 / 影向小图例。
	var anchor := Vector2(322.0, 34.0)
	var sun_dir: Vector2 = data["sun_dir"]
	var shadow_dir: Vector2 = data["shadow_dir"]
	draw_arc(anchor, 30.0, -PI, 0.0, 32, Color(1, 1, 1, 0.16), 1.0)
	draw_line(anchor + Vector2(-34, 0), anchor + Vector2(34, 0),
			Color(1, 1, 1, 0.22), 1.0)
	draw_line(anchor, anchor + sun_dir * 26.0, LIGHT_C, 2.0)
	draw_circle(anchor + sun_dir * 26.0, 3.0, LIGHT_C)
	draw_line(anchor, anchor + shadow_dir * 26.0, SHADOW_C, 2.0)
	draw_circle(anchor + shadow_dir * 26.0, 2.0, SHADOW_C)
	draw_string(font, anchor + Vector2(-32, -30), "SUN", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 7, LIGHT_C)
	draw_string(font, anchor + Vector2(18, 38), "SHADOW", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 7, SHADOW_C)
	draw_string(font, Vector2(20.0, 348.0),
			"az %.1f  elev %.1f  cells 1px" % [data["azimuth"], data["elevation"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 7, GUIDE)


func _draw_grid() -> void:
	for x in range(0, 641, 40):
		draw_line(Vector2(x, 0), Vector2(x, 360), GRID, 1.0)
	for y in range(0, 361, 40):
		draw_line(Vector2(0, y), Vector2(640, y), GRID, 1.0)
