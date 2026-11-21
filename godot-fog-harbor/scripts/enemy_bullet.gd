class_name FogEnemyBullet
extends Node2D
## 敌方弹丸：手动射线检测墙体，距离检测命中玩家。带短拖尾。

signal impacted(pos: Vector2)

var direction := Vector2.RIGHT
var speed := 620.0
var damage := 9
var color := Color("f0a35c")
var life := 2.2
var player: Node2D = null


func configure(player_node: Node2D, from: Vector2, dir: Vector2, dmg: int, spd: float, tint: Color) -> void:
	player = player_node
	global_position = from
	direction = dir.normalized()
	damage = dmg
	speed = spd
	color = tint
	z_index = 3
	rotation = direction.angle()


func _ready() -> void:
	queue_redraw()


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if player == null or not is_instance_valid(player):
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		impacted.emit(global_position)
		queue_free()
		return
	global_position = to
	if not bool(player.get("dead")):
		if global_position.distance_to(player.global_position) < 15.0:
			player.take_damage(damage, direction)
			impacted.emit(global_position)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.4, color, true)
	draw_circle(Vector2.ZERO, 1.7, Color(1.0, 0.95, 0.75), true)
	draw_line(Vector2(-13, 0), Vector2(-2, 0), Color(color.r, color.g, color.b, 0.35), 2.0)
	draw_circle(Vector2.ZERO, 7.5, Color(color.r, color.g, color.b, 0.12), true)
