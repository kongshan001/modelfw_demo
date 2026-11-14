extends Node3D

# A three-pin bowling target. Hit by the thrown head; topples with a burst.

const Burst := preload("res://src/burst.gd")

signal knocked

var down := false
var _visual: Node3D

func _ready() -> void:
	add_to_group("pins")
	_build()

func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.1
	cylinder.bottom_radius = 0.14
	cylinder.height = 0.5
	cylinder.radial_segments = 12
	body.mesh = cylinder
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.96, 0.96, 0.94)
	white.roughness = 0.7
	body.material_override = white
	body.position = Vector3(0.0, 0.25, 0.0)
	_visual.add_child(body)

	var band := MeshInstance3D.new()
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.135
	band_mesh.bottom_radius = 0.135
	band_mesh.height = 0.09
	band_mesh.radial_segments = 12
	band.mesh = band_mesh
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.85, 0.16, 0.16)
	red.roughness = 0.7
	band.material_override = red
	band.position = Vector3(0.0, 0.4, 0.0)
	_visual.add_child(band)

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	head.mesh = sphere
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.96, 0.96, 0.94)
	head_mat.roughness = 0.7
	head.material_override = head_mat
	head.position = Vector3(0.0, 0.6, 0.0)
	_visual.add_child(head)

func hit() -> void:
	if down:
		return
	down = true
	Burst.burst(get_parent(), global_position + Vector3(0.0, 0.4, 0.0), Color(1.0, 0.86, 0.45), 8)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "rotation:z", PI * 0.5, 0.25)
	tween.tween_property(_visual, "position:y", 0.18, 0.25)
	knocked.emit()

func reset() -> void:
	down = false
	if _visual != null:
		_visual.rotation = Vector3.ZERO
		_visual.position = Vector3.ZERO
	visible = true
