class_name LegionProjectile
extends Node3D

# 极简追踪弹：弩矢 / 火球 / 酸液 / 熔渣炮弹。命中时由游戏统一结算伤害与 AoE。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")

var kind := "bolt"
var team := 0
var target: LegionActor = null
var target_pos := Vector3.ZERO
var damage := 0.0
var aoe := 0.0
var slow := 0.0
var slow_time := 0.0
var speed := 22.0
var age := 0.0
var done := false
var from_pos := Vector3.ZERO
var start_y := 0.0


func setup(p_kind: String, p_from: Vector3, p_target: LegionActor, p_damage: float,
		p_team: int, p_aoe: float = 0.0, p_slow: float = 0.0, p_slow_time: float = 0.0) -> void:
	kind = p_kind
	from_pos = p_from
	team = p_team
	target = p_target
	damage = p_damage
	aoe = p_aoe
	slow = p_slow
	slow_time = p_slow_time
	target_pos = p_target.global_position + Vector3(0, p_target.height * 0.55, 0) if p_target != null else p_from
	match kind:
		"bolt": speed = 30.0
		"fire": speed = 19.0
		"acid": speed = 17.0
		"mortar": speed = 15.0
		_: speed = 22.0
	global_position = p_from
	start_y = p_from.y
	var vis := Art.build_projectile_visual(kind)
	add_child(vis)
	set_process(false)


func tick(dt: float) -> void:
	if done:
		return
	age += dt
	if target != null and is_instance_valid(target) and target.is_alive():
		target_pos = target.global_position + Vector3(0, target.height * 0.55, 0)
	var to := target_pos - global_position
	var dist := to.length()
	var step := speed * dt
	if kind == "mortar":
		# 抛物线：先升高再落点
		var total := maxf(0.35, from_pos.distance_to(target_pos) / speed)
		var t := clampf(age / total, 0.0, 1.0)
		var dir := Vector3(target_pos.x - from_pos.x, 0, target_pos.z - from_pos.z)
		global_position = Vector3(
			from_pos.x + dir.x * t,
			lerpf(from_pos.y, target_pos.y, t) + sin(t * PI) * 4.0,
			from_pos.z + dir.z * t)
		rotation.y += dt * 6.0
		if t >= 1.0:
			_finish()
		return
	if dist <= maxf(step, 0.45):
		_finish()
		return
	global_position += to / dist * step
	rotation.y += dt * 12.0
	if age > 2.6:
		_finish()


func _finish() -> void:
	done = true
	var g := get_parent()
	if g != null:
		g.on_projectile_hit(self)
	queue_free()
