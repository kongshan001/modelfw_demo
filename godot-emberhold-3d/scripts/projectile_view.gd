class_name ProjectileView
extends Node3D
## 3D projectile presentation. Gameplay position comes from GameModel in HTML
## field pixels; this node converts it to world space and adds height/arc.

const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")

var kind: String = "bolt"
var _spin: Node3D
var _time := 0.0


func setup(kind_key: String) -> void:
	kind = kind_key
	for child in get_children():
		child.queue_free()
	_spin = Node3D.new()
	add_child(_spin)
	var st := MK.new_st()
	var color := Color(1, 0.72, 0.35)
	if kind == "bolt":
		MK.add_box(st, Vector3.ZERO, Vector3(0.55, 0.055, 0.055), Color.WHITE)
		MK.add_octa(st, Vector3(0.31, 0, 0), Vector3(0.10, 0.06, 0.06), Color.WHITE)
		color = Color(1.0, 0.78, 0.42)
	elif kind == "flame":
		MK.add_sphere(st, Vector3.ZERO, 0.15, Color.WHITE, 7, 4)
		MK.add_octa(st, Vector3(0, 0.12, 0), Vector3(0.09, 0.20, 0.09), Color.WHITE)
		color = Color(1.0, 0.45, 0.15)
	else:
		MK.add_octa(st, Vector3.ZERO, Vector3(0.15, 0.22, 0.15), Color.WHITE)
		MK.add_octa(st, Vector3.ZERO, Vector3(0.07, 0.11, 0.07), Color.WHITE, 0.7)
		color = Color(0.55, 0.95, 0.92)
	var mi := MeshInstance3D.new()
	mi.mesh = MK.finish(st)
	mi.material_override = Mat.unshaded(color, 2.0, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(mi)


func sync_world(world_pos: Vector3, target_world: Vector3, model_proj, delta: float) -> void:
	_time += delta
	var t: float = clampf(model_proj.travel / maxf(1.0, model_proj.total), 0.0, 1.0)
	var start_y := 1.25
	if kind == "flame":
		start_y = 1.35
	elif kind == "frost":
		start_y = 1.35
	var y := lerpf(start_y, 0.62, t)
	if kind == "flame":
		y += sin(t * PI) * 2.3
	elif kind == "frost":
		y += sin(_time * 8.0) * 0.05
	elif kind == "bolt":
		y += 0.05
	position = Vector3(world_pos.x, y, world_pos.z)
	var dx := target_world.x - world_pos.x
	var dz := target_world.z - world_pos.z
	if absf(dx) + absf(dz) > 0.0001:
		rotation.y = atan2(-dz, dx)
	if kind == "frost":
		_spin.rotation.x += delta * 9.0
		_spin.rotation.z += delta * 5.0
	elif kind == "flame":
		var s := 0.9 + sin(_time * 22.0) * 0.12
		_spin.scale = Vector3(s, s, s)
