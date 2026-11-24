class_name ShotLayer
extends Node2D

const ArtRes = preload("res://scripts/art.gd")

# 玩家自动射击的小型弹池：瞄准 Boss，900px/s，最多 96 发。
# 独立于敌弹池，避免敌弹 4096 容量和判定逻辑被友军弹污染。

const CAPACITY := 96
const SPEED := 900.0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var life := PackedFloat32Array()
var count := 0

func _ready() -> void:
	z_index = 21
	pos.resize(CAPACITY)
	vel.resize(CAPACITY)
	life.resize(CAPACITY)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m

func reset() -> void:
	count = 0

func fire(origin: Vector2, target: Vector2) -> void:
	if count >= CAPACITY:
		return
	var dir := target - origin
	if dir.length_squared() < 1.0:
		dir = Vector2.UP
	dir = dir.normalized()
	var i := count
	pos[i] = origin
	vel[i] = dir * SPEED
	life[i] = 2.0
	count += 1

func tick(dt: float, boss_pos: Vector2, boss_radius: float, boss_active: bool) -> Array[Vector2]:
	var hits: Array[Vector2] = []
	var i := 0
	while i < count:
		pos[i] += vel[i] * dt
		life[i] -= dt
		var hit := false
		if boss_active:
			if pos[i].distance_to(boss_pos) <= boss_radius + 2.0:
				hits.append(pos[i])
				hit = true
		if hit or life[i] <= 0.0 or pos[i].x < -30.0 or pos[i].x > 1310.0 or pos[i].y < -30.0 or pos[i].y > 750.0:
			var last := count - 1
			pos[i] = pos[last]
			vel[i] = vel[last]
			life[i] = life[last]
			count -= 1
		else:
			i += 1
	queue_redraw()
	return hits

func _draw() -> void:
	for i in count:
		var d := vel[i].normalized()
		var tail := pos[i] - d * 17.0
		draw_line(tail, pos[i], Color(ArtRes.CYAN, 0.55), 2.2, true)
		draw_line(tail + d * 4.0, pos[i], Color(0.93, 0.99, 1.0, 0.95), 1.1, true)
		draw_circle(pos[i], 2.2, Color(1.0, 1.0, 1.0, 0.95))
