class_name BackgroundView
extends Node2D

const W := 1920.0
const H := 1080.0
var _fog: GPUParticles2D

func _ready() -> void:
	_build_fog()

func _build_fog() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 22.0
	mat.gravity = Vector3.ZERO
	mat.color = Color(0.85, 0.9, 1.0, 0.10)
	mat.scale_min = 2.0
	mat.scale_max = 5.0
	_fog = GPUParticles2D.new()
	_fog.process_material = mat
	_fog.texture = _soft_circle_texture()
	_fog.amount = 40
	_fog.lifetime = 16.0
	_fog.preprocess = 8.0
	_fog.position = Vector2(0, 560)
	_fog.emitting = true
	add_child(_fog)

func _soft_circle_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _draw() -> void:
	# 天空渐变（分条绘制）
	for i in 48:
		var t := float(i) / 47.0
		var color := Color(0.72, 0.86, 0.95).lerp(Color(0.98, 0.92, 0.78), t)
		draw_rect(Rect2(0, H * t * 0.55, W, H * 0.55 / 48.0 + 2.0), color, true)
	# 远山
	draw_colored_polygon(PackedVector2Array([Vector2(0, 430), Vector2(220, 230), Vector2(470, 430), Vector2(690, 280), Vector2(980, 450), Vector2(1240, 300), Vector2(1560, 450), Vector2(1920, 340), Vector2(1920, 700), Vector2(0, 700)]), Color(0.42, 0.58, 0.55))
	draw_colored_polygon(PackedVector2Array([Vector2(0, 520), Vector2(300, 390), Vector2(620, 540), Vector2(900, 400), Vector2(1240, 550), Vector2(1600, 420), Vector2(1920, 520), Vector2(1920, 760), Vector2(0, 760)]), Color(0.27, 0.46, 0.36))
	# 竹林
	for i in 22:
		var x := 60.0 + i * 86.0
		var h := 260.0 + float((i * 53) % 160)
		draw_line(Vector2(x, 600), Vector2(x + 18, 600 - h), Color(0.24, 0.38, 0.24, 0.75), 6.0)
	# 地面
	draw_colored_polygon(PackedVector2Array([Vector2(0, 690), Vector2(1920, 690), Vector2(1920, 1080), Vector2(0, 1080)]), Color(0.36, 0.5, 0.3))
	for i in 20:
		draw_line(Vector2(0, 720 + i * 18), Vector2(1920, 700 + i * 20), Color(0.28, 0.4, 0.24, 0.25), 2.0)
	# 光斑
	for i in 9:
		var p := Vector2(220 + i * 190, 160 + (i * 137) % 360)
		draw_circle(p, 26.0 + (i * 7) % 22, Color(1.0, 0.95, 0.75, 0.08))
