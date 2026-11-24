class_name BulletBackground
extends Node2D

const ArtRes = preload("res://scripts/art.gd")

# 程序化舞台：shader 渐变 + 星屑 + 飘落绯瓣 + 节拍环 + 边框。
# 不依赖任何贴图资产，保持 1 个全屏 draw call + 少量 2D primitives。

const BG_SHADER := preload("res://shaders/background.gdshader")

var time := 0.0
var beat_pulse := 0.0
var phase_color := ArtRes.MAGENTA
var _stars: Array[Vector4] = []
var _petals: Array[Vector4] = []
var _rng := RandomNumberGenerator.new()
var _redraw_accum := 0.0

func _ready() -> void:
	z_index = -100
	_rng.seed = 0x51A7F13
	var bg := ColorRect.new()
	bg.position = Vector2.ZERO
	bg.size = Vector2(1280, 720)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BG_SHADER
	bg.material = mat
	bg.z_index = -1
	add_child(bg)
	for i in 64:
		_stars.append(Vector4(_rng.randf_range(0.0, 1280.0), _rng.randf_range(0.0, 720.0), _rng.randf_range(0.3, 0.8), _rng.randf_range(0.0, TAU)))
	for i in 30:
		_petals.append(Vector4(_rng.randf_range(0.0, 1280.0), _rng.randf_range(0.0, 720.0), _rng.randf_range(8.0, 26.0), _rng.randf_range(0.0, TAU)))
	queue_redraw()

func tick(dt: float) -> void:
	time += dt
	_redraw_accum += dt
	if _redraw_accum >= 0.033:
		_redraw_accum = 0.0
		queue_redraw()

func _draw() -> void:
	# 远处同心光环，给 Boss 一个“舞台中心”。
	var center := Vector2(640.0, 150.0)
	for i in 3:
		var rr := 238.0 + float(i) * 92.0
		var a := 0.035 + 0.02 * (1.0 - beat_pulse) + 0.012 * float(i)
		draw_arc(center, rr, 0.0, TAU, 96, Color(phase_color, a), 1.0, true)
	# 节拍环
	if beat_pulse > 0.001:
		draw_arc(center, 268.0 + (1.0 - beat_pulse) * 28.0, 0.0, TAU, 96, Color(phase_color, 0.10 * beat_pulse), 2.0, true)
		draw_arc(center, 268.0 + (1.0 - beat_pulse) * 52.0, 0.0, TAU, 96, Color(ArtRes.CYAN, 0.045 * beat_pulse), 1.0, true)

	# 星屑：低亮度闪烁，不喧宾夺主。
	for s in _stars:
		var tw := 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 1.3 + s.w))
		var c := Color(ArtRes.LILAC, 0.030 + 0.055 * tw)
		if int(s.w * 10.0) % 5 == 0:
			c = Color(ArtRes.CYAN, 0.026 + 0.050 * tw)
		draw_circle(Vector2(s.x, s.y), s.z, c)

	# 绯瓣：缓慢下落 + 横向摆动。
	for p in _petals:
		var x := p.x + sin(time * 0.34 + p.w) * 26.0
		var y := fmod(p.y + time * p.z, 760.0) - 20.0
		var ang := time * 0.7 + p.w
		var dir := Vector2.from_angle(ang)
		var c := Color(ArtRes.MAGENTA, 0.065) if int(p.w * 7.0) % 3 != 0 else Color(ArtRes.CYAN, 0.055)
		draw_line(Vector2(x, y) - dir * 3.0, Vector2(x, y) + dir * 3.0, c, 1.2, true)
		draw_circle(Vector2(x, y), 1.2, Color(c, c.a * 1.2))

	# 舞台边框与四角括号。
	var border := Color(ArtRes.LINE, 0.45)
	draw_rect(Rect2(18.0, 16.0, 1244.0, 688.0), border, false, 1.0)
	var corner := Color(phase_color, 0.55)
	for corner_pos in [Vector2(18, 16), Vector2(1262, 16), Vector2(18, 704), Vector2(1262, 704)]:
		var sx := 1.0 if corner_pos.x < 640.0 else -1.0
		var sy := 1.0 if corner_pos.y < 360.0 else -1.0
		draw_line(corner_pos, corner_pos + Vector2(28.0 * sx, 0.0), corner, 2.0, true)
		draw_line(corner_pos, corner_pos + Vector2(0.0, 20.0 * sy), corner, 2.0, true)
