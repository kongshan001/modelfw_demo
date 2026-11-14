extends Area3D

# Collectible energy core. The slice only needs one behavior: touch it, score.

signal collected

var _active := true
var _visual: Node3D
var _phase := 0.0

func _ready() -> void:
	add_to_group("cores")
	_phase = absf(position.x) * 0.7
	_build()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if _visual == null:
		return
	_visual.rotation.y += delta * 2.2
	_visual.position.y = sin(Time.get_ticks_msec() * 0.002 + _phase) * 0.12

func _build() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	shape.shape = sphere
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.22
	torus.outer_radius = 0.46
	torus.rings = 32
	torus.ring_segments = 10
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.65, 0.1)
	mat.emission_energy_multiplier = 2.0
	mesh.material_override = mat
	_visual.add_child(mesh)

	var core := MeshInstance3D.new()
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.18
	sphere_mesh.height = 0.36
	core.mesh = sphere_mesh
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(1.0, 0.95, 0.6)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.9, 0.5)
	core_mat.emission_energy_multiplier = 3.0
	core.material_override = core_mat
	_visual.add_child(core)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.3)
	light.light_energy = 1.2
	light.omni_range = 3.0
	add_child(light)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collect()

func collect() -> void:
	if not _active:
		return
	_active = false
	visible = false
	Game.collect_core()
	collected.emit()

func reset() -> void:
	_active = true
	visible = true
