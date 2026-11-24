class_name FireflyPlayer
extends Node2D

const ArtRes = preload("res://scripts/art.gd")
const Pool = preload("res://scripts/bullet_pool.gd")

# 原创“萤舟”玩家机：WASD/方向键移动，Shift 聚焦减速。
# 视觉机身约 22×26px；常驻判定环直径 18px；真实判定半径 2.6px。
# 自动射击由 main 控制，按住射击键也有效（兼容习惯）。

const SPEED := 300.0
const FOCUS_SPEED := 138.0
const HIT_RADIUS := 2.6
const GRAZE_RADIUS := 20.0
const START_LIVES := 5

var velocity := Vector2.ZERO
var focus := false
var autopilot := false
var invuln := 0.0
var lives := START_LIVES
var alive := true
var graze := 0
var time := 0.0
var manual_input := false
var _glow: Sprite2D

func _ready() -> void:
	z_index = 20
	position = Vector2(640.0, 596.0)
	_glow = Sprite2D.new()
	_glow.texture = ArtRes.glow_texture()
	_glow.scale = Vector2(0.86, 0.86)
	_glow.modulate = Color(ArtRes.CYAN, 0.55)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.z_index = -1
	add_child(_glow)
	queue_redraw()

func reset() -> void:
	position = Vector2(640.0, 596.0)
	velocity = Vector2.ZERO
	focus = false
	invuln = 1.2
	lives = START_LIVES
	alive = true
	graze = 0
	time = 0.0
	manual_input = false
	modulate.a = 1.0
	queue_redraw()

func tick(dt: float, bullets: Pool, bounds: Rect2) -> void:
	time += dt
	invuln = maxf(0.0, invuln - dt)
	if not alive:
		return
	var ix := 0.0
	var iy := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		ix -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		ix += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		iy -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		iy += 1.0
	var input_vec := Vector2(ix, iy)
	manual_input = input_vec.length_squared() > 0.01
	if manual_input:
		autopilot = false
	focus = Input.is_key_pressed(KEY_SHIFT) and not autopilot
	if autopilot:
		_tick_autopilot(dt, bullets)
	else:
		var desired := Vector2.ZERO
		if manual_input:
			var sp := FOCUS_SPEED if focus else SPEED
			desired = input_vec.normalized() * sp
		velocity = velocity.lerp(desired, minf(1.0, dt * 24.0))
		position += velocity * dt
	position.x = clampf(position.x, bounds.position.x + 18.0, bounds.end.x - 18.0)
	position.y = clampf(position.y, bounds.position.y + 30.0, bounds.end.y - 18.0)
	_glow.modulate = Color(ArtRes.CYAN, 0.48 + (0.2 if focus else 0.0))
	if invuln > 0.0:
		modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(time * 34.0))
	else:
		modulate.a = 1.0
	queue_redraw()

func _tick_autopilot(dt: float, bullets: Pool) -> void:
	var target := Vector2(
		640.0 + sin(time * 0.47) * 248.0 + sin(time * 1.37) * 22.0,
		566.0 + sin(time * 0.83) * 56.0
	)
	# 用每 2 颗采样一次做低成本避弹斥力，让演示看起来在主动走位。
	var repel := Vector2.ZERO
	var n := bullets.count
	var step := 2
	for i in range(0, n, step):
		var d := (position - bullets.pos[i])
		var dist := d.length()
		if dist < 82.0 and dist > 0.01:
			repel += d.normalized() * ((82.0 - dist) / 82.0)
	target += repel * 86.0
	target.x = clampf(target.x, 64.0, 1216.0)
	target.y = clampf(target.y, 160.0, 672.0)
	var desired := (target - position) * 4.8
	if desired.length() > 360.0:
		desired = desired.normalized() * 360.0
	velocity = velocity.lerp(desired, minf(1.0, dt * 6.5))
	position += velocity * dt

func apply_hit() -> bool:
	if not alive or invuln > 0.0:
		return false
	lives -= 1
	invuln = 2.2
	if lives <= 0:
		lives = 0
		alive = false
	return true

func shot_origin() -> Vector2:
	return position + Vector2(0.0, -17.0)

func _draw() -> void:
	var body := PackedVector2Array([
		Vector2(0.0, -15.0), Vector2(4.0, -5.0), Vector2(12.0, 7.0),
		Vector2(5.0, 5.0), Vector2(3.0, 11.0), Vector2(0.0, 8.0),
		Vector2(-3.0, 11.0), Vector2(-5.0, 5.0), Vector2(-12.0, 7.0),
		Vector2(-4.0, -5.0),
	])
	var edge := PackedVector2Array(body)
	edge.append(body[0])
	# 尾焰
	var flame := 5.0 + sin(time * 24.0) * 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, 9.0), Vector2(0.0, 14.0 + flame), Vector2(3.0, 9.0),
	]), Color(ArtRes.CYAN, 0.55))
	draw_colored_polygon(body, Color(0.045, 0.05, 0.11, 0.95))
	draw_polyline(edge, Color(ArtRes.CYAN, 0.95), 1.6, true)
	draw_line(Vector2(0.0, -11.0), Vector2(0.0, 3.0), Color(ArtRes.MAGENTA, 0.72), 1.4, true)
	# 判定可视化：直径 18px 的环 + 2.6px 实心点。
	var ring_alpha := 0.82 if focus else 0.34
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 32, Color(ArtRes.CYAN, ring_alpha), 1.2, true)
	if focus:
		for i in 4:
			var a := TAU * float(i) / 4.0 + time * 0.8
			draw_line(Vector2.from_angle(a) * 11.0, Vector2.from_angle(a) * 14.0, Color(ArtRes.CYAN, 0.7), 1.0, true)
	draw_circle(Vector2.ZERO, 2.6, Color(1.0, 0.97, 1.0, 1.0))
	draw_arc(Vector2.ZERO, 3.5, 0.0, TAU, 16, Color(ArtRes.RED, 0.9), 1.0, true)
	# 擦弹半径提示（很淡）
	draw_arc(Vector2.ZERO, GRAZE_RADIUS, 0.0, TAU, 48, Color(ArtRes.CYAN, 0.055), 1.0, true)
