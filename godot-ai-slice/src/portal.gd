extends Area3D

# Goal portal. Inactive until all cores are collected; entering an active
# portal wins the slice.

const Burst := preload("res://src/burst.gd")

var active := false
var _visual: Node3D
var _mat: StandardMaterial3D
var _light: OmniLight3D

func _ready() -> void:
	add_to_group("portal")
	_build()
	body_entered.connect(_on_body_entered)
	set_active(false)

func _process(_delta: float) -> void:
	if _visual == null:
		return
	if active:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.005) * 0.05
		_visual.scale = Vector3.ONE * pulse
	else:
		_visual.scale = Vector3.ONE

func _build() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 3.2, 1.2)
	shape.shape = box
	shape.position = Vector3(0.0, 1.5, 0.0)
	add_child(shape)

	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.position = Vector3(0.0, 1.6, 0.0)
	add_child(_visual)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.1
	torus.rings = 48
	torus.ring_segments = 12
	var mesh := MeshInstance3D.new()
	mesh.mesh = torus
	mesh.rotation.x = PI * 0.5
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.4, 0.5)
	_mat.emission_enabled = true
	_mat.emission = Color(0.2, 0.5, 1.0)
	_mat.emission_energy_multiplier = 2.0
	mesh.material_override = _mat
	_visual.add_child(mesh)

	_light = OmniLight3D.new()
	_light.position = Vector3(0.0, 1.6, 0.0)
	_light.omni_range = 5.0
	_light.light_energy = 0.0
	add_child(_light)

func set_active(value: bool) -> void:
	var was_active := active
	active = value
	if _mat != null:
		if active:
			_mat.albedo_color = Color(1.0, 0.82, 0.35)
			_mat.emission = Color(1.0, 0.65, 0.2)
		else:
			_mat.albedo_color = Color(0.35, 0.4, 0.5)
			_mat.emission = Color(0.2, 0.5, 1.0)
	if _light != null:
		_light.light_energy = 2.2 if active else 0.0
	if active and not was_active:
		Burst.burst(get_parent(), global_position + Vector3(0.0, 1.6, 0.0), Color(1.0, 0.72, 0.25), 18)
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("shake"):
			player.call("shake", 0.09, 0.2)

func _on_body_entered(body: Node3D) -> void:
	if active and body.is_in_group("player"):
		trigger()

func trigger() -> void:
	if active:
		Burst.burst(get_parent(), global_position + Vector3(0.0, 1.6, 0.0), Color(1.0, 0.9, 0.4), 26)
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("shake"):
			player.call("shake", 0.16, 0.3)
		Game.win()

func reset() -> void:
	set_active(false)
