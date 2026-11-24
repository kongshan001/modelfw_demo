class_name HaloBoss
extends Node2D

const ArtRes = preload("res://scripts/art.gd")

# 原创 Boss “辉庭守望者 · 环”：悬浮机械光环，无外部贴图。
# 绘制限制在局部坐标，运动/受击/阶段由 main 显式 tick，便于固定步长测试。

const HIT_RADIUS := 34.0

signal damaged(amount: float)

var base_pos := Vector2(640.0, 124.0)
var max_hp := 1000.0
var hp := 1000.0
var phase := 0
var time := 0.0
var flash := 0.0
var invuln := false
var alive := true
var phase_color := ArtRes.MAGENTA
var _glow: Sprite2D
var _core_glow: Sprite2D

func _ready() -> void:
	z_index = 10
	_glow = Sprite2D.new()
	_glow.texture = ArtRes.glow_texture()
	_glow.scale = Vector2(2.4, 2.4)
	_glow.modulate = Color(phase_color, 0.62)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.z_index = -2
	add_child(_glow)
	_core_glow = Sprite2D.new()
	_core_glow.texture = ArtRes.glow_texture()
	_core_glow.scale = Vector2(1.15, 1.15)
	_core_glow.modulate = Color(0.96, 0.92, 1.0, 0.9)
	_core_glow.material = m
	_core_glow.z_index = -1
	add_child(_core_glow)
	position = base_pos
	queue_redraw()

func tick(dt: float) -> void:
	time += dt
	flash = maxf(0.0, flash - dt * 6.0)
	position = base_pos + Vector2(sin(time * 0.35) * 132.0, sin(time * 0.7) * 11.0)
	_glow.modulate = Color(phase_color, 0.50 + 0.16 * (0.5 + 0.5 * sin(time * 2.2)))
	_glow.rotation = time * 0.15
	_core_glow.modulate = Color(1.0, 0.96, 1.0, 0.75 + 0.2 * flash)
	if not alive:
		visible = false
	queue_redraw()

func tick_idle(dt: float) -> void:
	# 阶段切换/暂停时仍保留缓慢呼吸，不移动发射原点。
	time += dt
	flash = maxf(0.0, flash - dt * 6.0)
	_glow.modulate = Color(phase_color, 0.46 + 0.12 * (0.5 + 0.5 * sin(time * 2.2)))
	queue_redraw()

func set_phase(p_phase: int, p_hp: float) -> void:
	phase = p_phase
	max_hp = p_hp
	hp = p_hp
	alive = true
	visible = true
	flash = 1.0
	phase_color = [ArtRes.MAGENTA, ArtRes.CYAN, ArtRes.GOLD][clampi(p_phase, 0, 2)]
	_glow.modulate = Color(phase_color, 0.7)
	queue_redraw()

func take_damage(amount: float) -> float:
	if not alive or invuln:
		return 0.0
	var before := hp
	hp = maxf(0.0, hp - amount)
	flash = 0.22
	var dealt := before - hp
	if dealt > 0.0:
		emit_signal("damaged", dealt)
	return dealt

func defeat() -> void:
	alive = false
	hp = 0.0
	invuln = true
	flash = 1.0
	queue_redraw()

func _draw() -> void:
	var white_mix := flash * 0.8
	var pc := phase_color.lerp(Color.WHITE, white_mix)
	var armor := Color("#24183d").lerp(Color.WHITE, white_mix * 0.6)
	# 外层柔光
	draw_circle(Vector2.ZERO, 58.0, Color(pc, 0.035))
	draw_circle(Vector2.ZERO, 47.0, Color(pc, 0.05))
	# 24 段旋转刻度环
	var rot := time * 0.55
	for i in 24:
		var a0 := rot + TAU * float(i) / 24.0
		var a1 := a0 + TAU / 24.0 * 0.58
		var c := ArtRes.CYAN if i % 3 == 0 else pc
		draw_arc(Vector2.ZERO, 40.0, a0, a1, 6, Color(c, 0.52 + 0.3 * white_mix), 2.2, true)
	for i in 8:
		var a := -rot * 0.8 + TAU * float(i) / 8.0
		var p0 := Vector2.from_angle(a) * 30.0
		var p1 := Vector2.from_angle(a) * 35.0
		draw_line(p0, p1, Color(pc, 0.46), 1.2, true)
	# 内盘
	draw_circle(Vector2.ZERO, 27.0, Color("#130c22"))
	draw_arc(Vector2.ZERO, 27.0, 0.0, TAU, 64, Color(pc, 0.65), 1.6, true)
	draw_circle(Vector2.ZERO, 20.0, Color(armor, 0.85))
	draw_circle(Vector2.ZERO, 14.0, Color(pc, 0.32))
	draw_circle(Vector2.ZERO, 9.0, Color(0.95, 0.93, 1.0, 0.95))
	draw_circle(Vector2.ZERO, 4.5, Color(1, 1, 1, 1))
	# 三段轨道碎片
	for i in 3:
		var a := -time * 0.9 + TAU * float(i) / 3.0
		var p := Vector2.from_angle(a) * 54.0
		draw_line(p, p + Vector2.from_angle(a + 1.57) * 7.0, Color(pc, 0.75), 2.0, true)
		draw_circle(p, 2.6, Color(1, 1, 1, 0.8))
	# 受击白闪环
	if flash > 0.01:
		draw_arc(Vector2.ZERO, 46.0 + flash * 8.0, 0.0, TAU, 64, Color(1, 1, 1, flash * 0.55), 2.0, true)
