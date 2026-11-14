extends Area3D

# The robot's detachable head, thrown as a bowling ball. It does not use rigid
# body physics: a short kinematic arc + distance checks against the "pins" group
# keeps the slice deterministic and easy to test.

const Burst := preload("res://src/burst.gd")

var _velocity := Vector3.ZERO
var _life := 0.0
var _done := false
var _visual: Node3D

func _ready() -> void:
	add_to_group("head_projectiles")
	monitoring = false
	monitorable = false
	_build()

func _build() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.32
	mesh.height = 0.64
	sphere.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.62, 0.18)
	mat.roughness = 0.45
	sphere.material_override = mat
	_visual.add_child(sphere)

	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.42, 0.14, 0.08)
	visor.mesh = box
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.08, 0.12, 0.18)
	dark.roughness = 0.5
	visor.material_override = dark
	visor.position = Vector3(0.0, 0.03, 0.27)
	_visual.add_child(visor)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.25)
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)

func launch(dir: Vector3) -> void:
	_velocity = dir.normalized() * 14.0 + Vector3.UP * 0.4
	_life = 1.3

func _process(delta: float) -> void:
	if _done:
		return
	global_position += _velocity * delta
	_velocity.y -= 8.0 * delta
	_visual.rotation.x += delta * 12.0
	_visual.rotation.z += delta * 6.0

	for pin in get_tree().get_nodes_in_group("pins"):
		if pin == null or not pin.has_method("hit"):
			continue
		var pin_node := pin as Node3D
		if global_position.distance_to(pin_node.global_position + Vector3(0.0, 0.4, 0.0)) < 1.5:
			pin.call("hit")

	_life -= delta
	if _life <= 0.0:
		_finish()

func _finish() -> void:
	_done = true
	Burst.burst(get_parent(), global_position, Color(1.0, 0.72, 0.25), 12)
	queue_free()
