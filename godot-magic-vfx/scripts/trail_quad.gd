class_name TrailQuad
extends Node3D

# Flat scrolling flame sheet (one cached quad) attached to a projectile.
# Follows the projectile with a camera-facing basis; no per-frame mesh rebuild.

var mesh_inst: MeshInstance3D
var length := 3.2
var height := 1.0
var _seeded := false

func setup(mesh: Mesh, mat: Material, len: float, h: float) -> void:
	length = len
	height = h
	if mesh_inst == null:
		mesh_inst = MeshInstance3D.new()
		mesh_inst.name = "Sheet"
		mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_inst.custom_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 40, 80))
		add_child(mesh_inst)
	mesh_inst.mesh = mesh
	mesh_inst.material_override = mat
	mesh_inst.scale = Vector3(len, h, 1.0)
	mesh_inst.position = Vector3(len * 0.5, 0.0, 0.0)
	visible = true

func place(head: Vector3, backward: Vector3) -> void:
	var x := backward.normalized()
	if x.length_squared() < 0.5:
		x = Vector3.BACK
	var up := Vector3.UP
	var y := up - x * x.dot(up)
	if y.length_squared() < 0.001:
		y = Vector3.FORWARD
	y = y.normalized()
	var z := x.cross(y)
	global_transform = Transform3D(Basis(x, y, z), head)
