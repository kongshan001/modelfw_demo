class_name MistProjectile
extends Node3D
## 箭矢 / 投斧：抛物线飞行，命中时由 game 结算伤害与克制提示。

const Models = preload("res://scripts/models.gd")

var game
var kind := "arrow"
var team := "player"
var target_node: Node3D
var target_kind := "enemy"
var target_squad = null
var target_member_index := -1
var attacker_class := "archer"
var damage := 8.0
var attacker_height := 0.0
var source_pos := Vector3.ZERO
var elapsed := 0.0
var duration := 0.6
var arc_height := 1.0
var start_pos := Vector3.ZERO
var _mesh: MeshInstance3D
var _last_target := Vector3.ZERO
var _spin := 0.0
var arrived := false


func configure(game_ref, kind_id: String, from_pos: Vector3, target: Node3D, target_kind_id: String, team_id: String, class_id: String, dmg: float, shooter_height: float, speed: float) -> void:
	game = game_ref
	kind = kind_id
	team = team_id
	target_node = target
	target_kind = target_kind_id
	attacker_class = class_id
	damage = dmg
	attacker_height = shooter_height
	source_pos = from_pos
	start_pos = from_pos + Vector3(0, 0.95, 0)
	position = start_pos
	_last_target = start_pos + Vector3(0, 0, -1)
	if target_node != null:
		_last_target = target_node.global_position + Vector3(0, 0.95, 0)
	if target_kind == "member" and target_squad != null and target_member_index >= 0:
		_last_target = game.get_member_position(target_squad, target_member_index) + Vector3(0, 0.95, 0)
	var dist := start_pos.distance_to(_last_target)
	duration = clampf(dist / maxf(6.0, speed), 0.14, 1.6)
	arc_height = 0.6 + dist * 0.055
	_mesh = MeshInstance3D.new()
	_mesh.mesh = Models.arrow_mesh(kind)
	_mesh.material_override = Models.unit_material()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	if kind == "axe":
		_mesh.scale = Vector3.ONE * 1.25


func simulate(dt: float) -> void:
	if arrived:
		return
	elapsed += dt
	var target_pos := _target_position()
	_last_target = target_pos
	var t := clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	var pos := start_pos.lerp(target_pos, t)
	pos.y += sin(t * PI) * arc_height
	var prev := global_position
	var moved := pos - prev
	global_position = pos
	if moved.length() > 0.001:
		look_at(pos + moved.normalized(), Vector3.UP)
	if kind == "axe" and _mesh != null:
		_spin += dt * 16.0
		_mesh.rotation.z = _spin
	if t >= 1.0:
		arrived = true
		if game != null:
			game.on_projectile_arrived(self)


func _target_position() -> Vector3:
	if target_kind == "member" and target_squad != null and target_member_index >= 0:
		var p: Vector3 = game.get_member_position(target_squad, target_member_index)
		if p != Vector3.ZERO:
			return p + Vector3(0, 0.95, 0)
	if target_node != null and is_instance_valid(target_node) and target_node.is_inside_tree():
		return target_node.global_position + Vector3(0, 0.95, 0)
	return _last_target


func dispose() -> void:
	queue_free()
