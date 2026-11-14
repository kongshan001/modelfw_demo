extends RefCounted

# Tiny procedural burst for collect / portal feedback. No textures or audio.

static func burst(parent: Node3D, origin: Vector3, color: Color, count: int = 12) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "JuiceBurst"
	parent.add_child(root)
	root.global_position = origin

	for i in count:
		var mesh := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.06
		sphere.height = 0.12
		mesh.mesh = sphere
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh.material_override = mat
		root.add_child(mesh)

		var dir := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(0.4, 1.4),
			randf_range(-1.0, 1.0)
		).normalized()
		var target := dir * randf_range(0.6, 1.4)
		var tween := mesh.create_tween()
		tween.set_parallel(true)
		tween.tween_property(mesh, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(mesh, "scale", Vector3.ZERO, 0.45)

	var cleanup := root.create_tween()
	cleanup.tween_interval(0.55)
	cleanup.tween_callback(root.queue_free)
