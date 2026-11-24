class_name BulletFx
extends Node2D

const ArtRes = preload("res://scripts/art.gd")

# 轻量反馈层：火花（固定容量）+ 冲击环。单个 additive 材质，避免粒子系统开销。
# 没有贴图；擦弹、命中、分裂、阶段切换共用同一套池。

const SPARK_CAP := 512
const RING_CAP := 32

var p_pos := PackedVector2Array()
var p_vel := PackedVector2Array()
var p_life := PackedFloat32Array()
var p_max := PackedFloat32Array()
var p_size := PackedFloat32Array()
var p_color := PackedColorArray()
var p_count := 0

var r_pos := PackedVector2Array()
var r_life := PackedFloat32Array()
var r_max := PackedFloat32Array()
var r_radius := PackedFloat32Array()
var r_width := PackedFloat32Array()
var r_color := PackedColorArray()
var r_count := 0

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 40
	p_pos.resize(SPARK_CAP)
	p_vel.resize(SPARK_CAP)
	p_life.resize(SPARK_CAP)
	p_max.resize(SPARK_CAP)
	p_size.resize(SPARK_CAP)
	p_color.resize(SPARK_CAP)
	r_pos.resize(RING_CAP)
	r_life.resize(RING_CAP)
	r_max.resize(RING_CAP)
	r_radius.resize(RING_CAP)
	r_width.resize(RING_CAP)
	r_color.resize(RING_CAP)
	rng.seed = 0xF1A5E
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m

func reset() -> void:
	p_count = 0
	r_count = 0
	queue_redraw()

func burst(at: Vector2, color: Color, amount := 14, speed := 190.0, size := 3.0) -> void:
	for k in amount:
		if p_count >= SPARK_CAP:
			break
		var i := p_count
		var a := rng.randf() * TAU
		var sp := speed * rng.randf_range(0.25, 1.0)
		p_pos[i] = at
		p_vel[i] = Vector2.from_angle(a) * sp
		p_max[i] = rng.randf_range(0.25, 0.7)
		p_life[i] = p_max[i]
		p_size[i] = size * rng.randf_range(0.55, 1.35)
		p_color[i] = color
		p_count += 1

func graze_spark(at: Vector2) -> void:
	burst(at, ArtRes.CYAN, 3, 55.0, 1.7)

func hit_burst(at: Vector2) -> void:
	burst(at, ArtRes.RED, 34, 260.0, 3.8)
	ring(at, ArtRes.RED, 28.0, 3.0, 0.55)

func ring(at: Vector2, color: Color, radius := 40.0, width := 2.5, duration := 0.5) -> void:
	if r_count >= RING_CAP:
		return
	var i := r_count
	r_pos[i] = at
	r_max[i] = duration
	r_life[i] = duration
	r_radius[i] = radius
	r_width[i] = width
	r_color[i] = color
	r_count += 1

func tick(dt: float) -> void:
	var i := 0
	while i < p_count:
		p_life[i] -= dt
		if p_life[i] <= 0.0:
			var last := p_count - 1
			p_pos[i] = p_pos[last]
			p_vel[i] = p_vel[last]
			p_life[i] = p_life[last]
			p_max[i] = p_max[last]
			p_size[i] = p_size[last]
			p_color[i] = p_color[last]
			p_count -= 1
			continue
		p_pos[i] += p_vel[i] * dt
		p_vel[i] *= (1.0 - minf(0.95, dt * 2.6))
		i += 1
	i = 0
	while i < r_count:
		r_life[i] -= dt
		if r_life[i] <= 0.0:
			var last := r_count - 1
			r_pos[i] = r_pos[last]
			r_life[i] = r_life[last]
			r_max[i] = r_max[last]
			r_radius[i] = r_radius[last]
			r_width[i] = r_width[last]
			r_color[i] = r_color[last]
			r_count -= 1
			continue
		i += 1
	queue_redraw()

func _draw() -> void:
	for i in p_count:
		var t: float = clampf(p_life[i] / p_max[i], 0.0, 1.0)
		var c := p_color[i]
		c.a *= t
		var p := p_pos[i]
		var s := p_size[i] * (0.35 + t * 0.65)
		draw_circle(p, s * 1.8, Color(c, c.a * 0.20))
		draw_circle(p, s, c)
	for i in r_count:
		var t: float = clampf(r_life[i] / r_max[i], 0.0, 1.0)
		var radius := r_radius[i] * (1.0 + (1.0 - t) * 0.8)
		var c := r_color[i]
		c.a *= t * 0.8
		draw_arc(r_pos[i], radius, 0.0, TAU, 48, c, r_width[i] * (0.4 + t * 0.6), true)
