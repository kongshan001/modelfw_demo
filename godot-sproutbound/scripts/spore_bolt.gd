extends Node3D
class_name SporeBolt

## 孢囊菇的孢子弹：直线慢速飞行，命中玩家 / 撞到世界 / 超时后炸成孢尘。

var main: Node
var damage := 10
var velocity := Vector3.ZERO
var life := 3.4
var color := Color(0.65, 1.0, 0.72)
var dead := false

var _t := 0.0
var _core: MeshInstance3D
var _halo: MeshInstance3D


func setup(main_ref: Node, from: Vector3, dir: Vector3, dmg: int,
		tint: Color = Color(0.65, 1.0, 0.72)) -> void:
	main = main_ref
	global_position = from
	velocity = dir.normalized() * 9.6
	damage = dmg
	color = tint


func _ready() -> void:
	_core = MeshInstance3D.new()
	_core.mesh = SproutStyle.low_sphere(0.14, 7, 4)
	var mat := SproutStyle.mat(color.lightened(0.2), 0.3, color, 3.4)
	_core.material_override = mat
	_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_core)

	_halo = MeshInstance3D.new()
	_halo.mesh = SproutStyle.low_sphere(0.25, 7, 4)
	_halo.material_override = SproutStyle.unshaded(Color(color.r, color.g, color.b, 0.28), true)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)

	var trail := CPUParticles3D.new()
	trail.amount = 12
	trail.lifetime = 0.42
	trail.local_coords = false
	trail.direction = Vector3(0.0, 0.0, 1.0)
	trail.spread = 18.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.5
	trail.gravity = Vector3(0.0, -0.4, 0.0)
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.7
	trail.color = Color(color.r, color.g, color.b, 0.6)
	var mesh := SproutStyle.low_sphere(0.04, 4, 2)
	var tmat := SproutStyle.unshaded(Color(color.r, color.g, color.b, 0.7), true)
	tmat.vertex_color_use_as_albedo = true
	mesh.material = tmat
	trail.mesh = mesh
	add_child(trail)


func _process(delta: float) -> void:
	if dead:
		return
	_t += delta
	velocity.y -= 1.1 * delta
	var prev := global_position
	global_position += velocity * delta
	_core.rotation.x += delta * 8.0
	_core.rotation.y += delta * 6.0
	var pulse := 1.0 + 0.12 * sin(_t * 22.0)
	_halo.scale = Vector3.ONE * pulse

	if main != null and main.player != null and not main.player.dead:
		var chest: Vector3 = main.player.global_position + Vector3(0.0, 0.85, 0.0)
		if global_position.distance_to(chest) < 0.66:
			main.player.take_damage(damage, prev, 0.35)
			_pop()
			return

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(prev, global_position, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_pop()
		return

	if _t > life or global_position.y < -2.0:
		_pop()


func _pop() -> void:
	if dead:
		return
	dead = true
	if main != null:
		main.spawn_spore_burst(global_position, color, 10)
		main.remove_bolt(self)
	queue_free()
