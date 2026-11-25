class_name DreamFx
extends Node3D

# 轻量战斗/梦境特效：不依赖第三方资源，全部程序化几何 + Tween。
# 只在真实渲染时创建；headless 下创建节点不报错，逻辑测试不受影响。

var _spark_mesh: QuadMesh
var _spark_material: StandardMaterial3D


func _ready() -> void:
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.075, 0.075)
	_spark_material = StandardMaterial3D.new()
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_material.albedo_color = Color(1.0, 0.86, 0.48, 1.0)
	_spark_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func ring(pos: Vector3, color: Color, radius := 1.0, duration := 0.45) -> void:
	var mesh_instance := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.955
	torus.outer_radius = 1.0
	torus.rings = 20
	torus.ring_segments = 36
	mesh_instance.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.42)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.15
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos + Vector3.UP * 0.06
	mesh_instance.scale = Vector3.ONE * radius
	add_child(mesh_instance)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3.ONE * radius * 1.45, duration)
	tween.tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration)
	tween.chain().tween_callback(mesh_instance.queue_free)


func sparks(pos: Vector3, color: Color, amount := 18) -> void:
	var particles := CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.18
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 1.4
	particles.initial_velocity_max = 4.2
	particles.gravity = Vector3(0.0, -5.5, 0.0)
	particles.scale_amount_min = 0.55
	particles.scale_amount_max = 1.4
	particles.mesh = _spark_mesh
	var mat := _spark_material.duplicate() as StandardMaterial3D
	mat.albedo_color = color
	particles.material_override = mat
	particles.position = pos + Vector3.UP * 0.9
	particles.emitting = true
	add_child(particles)
	get_tree().create_timer(0.95).timeout.connect(particles.queue_free)


func slash(pos: Vector3, yaw: float, color: Color, heavy := false) -> void:
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(1.9 if heavy else 1.35, 0.22 if heavy else 0.13)
	mesh_instance.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.34)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.position = pos + Vector3.UP * 1.0
	mesh_instance.rotation = Vector3(0.0, yaw + PI * 0.25, 0.25)
	add_child(mesh_instance)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mesh_instance, "scale", Vector3(1.35, 1.0, 1.35), 0.18)
	tween.tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.22)
	tween.chain().tween_callback(mesh_instance.queue_free)


func burst_light(pos: Vector3, color: Color, energy := 3.4, light_range := 5.0) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	light.position = pos + Vector3.UP * 1.2
	add_child(light)
	var tween := create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.32)
	tween.tween_callback(light.queue_free)


func damage_number(pos: Vector3, value: int, critical := false) -> void:
	var label := Label3D.new()
	label.text = str(value)
	label.font_size = 54 if critical else 38
	label.pixel_size = 0.0042
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(1.0, 0.76, 0.3) if critical else Color(0.92, 0.96, 1.0)
	label.outline_size = 10
	label.outline_modulate = Color(0.04, 0.05, 0.1, 0.9)
	label.position = pos + Vector3(0.0, 1.8, 0.0)
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.9, 0.65)
	tween.tween_property(label, "modulate", Color(label.modulate.r, label.modulate.g, label.modulate.b, 0.0), 0.65)
	tween.chain().tween_callback(label.queue_free)


func afterimage(pos: Vector3, color: Color) -> void:
	# 闪避残影：一枚竖向薄片，避免复制骨骼模型的昂贵开销。
	var mesh_instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 1.4)
	mesh_instance.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.18)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	mesh_instance.position = pos + Vector3.UP * 0.8
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color", Color(color.r, color.g, color.b, 0.0), 0.28)
	tween.tween_property(mesh_instance, "scale", Vector3(0.6, 0.8, 0.6), 0.28)
	tween.chain().tween_callback(mesh_instance.queue_free)


func clear_effects() -> void:
	for child in get_children():
		child.queue_free()
