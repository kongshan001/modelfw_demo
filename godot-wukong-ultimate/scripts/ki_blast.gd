extends Node3D
class_name KiBlast

## Fast silver-blue ki wave with a light, trail, and raycast impact.

var dir := Vector3.FORWARD
var speed := 20.0
var damage := 60
var power := 0.5
var owner_body: CollisionObject3D
var impact_callback: Callable
var life := 2.4
var dead := false

var _core: MeshInstance3D
var _glow: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _trail: CPUParticles3D
var _sparks: CPUParticles3D


func setup(origin: Vector3, direction: Vector3, charge_power: float,
		damage_value: int, exclude_body: CollisionObject3D,
		callback: Callable) -> void:
	global_position = origin
	dir = direction.normalized()
	power = clampf(charge_power, 0.2, 1.0)
	speed = 19.0 + 9.0 * power
	damage = damage_value
	owner_body = exclude_body
	impact_callback = callback
	add_to_group("projectiles")
	_build()


func _build() -> void:
	var radius := 0.10 + 0.11 * power
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 20
	sm.rings = 10
	core.mesh = sm
	core.material_override = _additive(Color(1.0, 0.98, 0.90), 8.0, 1.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	_core = core

	var glow := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = radius * 2.8
	gm.height = radius * 5.6
	gm.radial_segments = 20
	gm.rings = 10
	glow.mesh = gm
	glow.material_override = _additive(Color(0.40, 0.72, 1.0), 2.4, 0.30)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	_glow = glow

	# elongated wave/beam tail (visual read: 光束)
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	look_at(global_position + dir, up)
	var tail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 1.15
	cm.bottom_radius = radius * 0.30
	cm.height = 3.0
	cm.radial_segments = 12
	cm.rings = 1
	tail.mesh = cm
	tail.material_override = _additive(Color(0.55, 0.82, 1.0), 1.6, 0.42)
	tail.rotation.x = PI * 0.5
	tail.position = Vector3(0, 0, 1.55)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tail)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 2.0
	tm.outer_radius = radius * 2.3
	tm.rings = 32
	tm.ring_segments = 8
	ring.mesh = tm
	ring.material_override = _additive(Color(0.65, 0.86, 1.0), 3.0, 0.55)
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	_ring = ring

	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.80, 1.0)
	_light.light_energy = 2.0 + power * 2.5
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	add_child(_light)

	_trail = CPUParticles3D.new()
	_trail.amount = 48
	_trail.lifetime = 0.42
	_trail.local_coords = false
	_trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail.emission_sphere_radius = radius * 0.8
	_trail.direction = -dir
	_trail.spread = 80.0
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_min = 0.1
	_trail.initial_velocity_max = 1.2
	_trail.scale_amount_min = 0.35
	_trail.scale_amount_max = 1.3
	_trail.color = Color(0.60, 0.84, 1.0, 0.85)
	_trail.mesh = _soft_quad()
	_trail.emitting = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)

	_sparks = CPUParticles3D.new()
	_sparks.amount = 18
	_sparks.lifetime = 0.55
	_sparks.local_coords = false
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = radius * 1.4
	_sparks.direction = -dir
	_sparks.spread = 110.0
	_sparks.gravity = Vector3.ZERO
	_sparks.initial_velocity_min = 0.5
	_sparks.initial_velocity_max = 2.0
	_sparks.scale_amount_min = 0.4
	_sparks.scale_amount_max = 1.4
	_sparks.color = Color(1.0, 0.98, 0.9, 0.9)
	_sparks.mesh = _soft_quad()
	_sparks.emitting = true
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparks)


func _additive(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.disable_receive_shadows = true
	m.vertex_color_use_as_albedo = true
	return m


func _soft_quad() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var tex := ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	m.disable_receive_shadows = true
	q.material = m
	return q


func _physics_process(delta: float) -> void:
	if dead:
		return
	life -= delta
	if life <= 0.0:
		_explode(global_position, null)
		return
	var from := global_position
	var to := from + dir * speed * delta
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	if owner_body != null and is_instance_valid(owner_body):
		exclude.append(owner_body.get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2, exclude)
	query.collide_with_areas = false
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		_explode(hit.position, hit.get("collider"))
	else:
		global_position = to
		if _ring != null:
			_ring.rotation.y += delta * 9.0
		if _glow != null:
			var s := 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.02)
			_glow.scale = Vector3(s, s, s)


func _explode(pos: Vector3, collider: Object) -> void:
	if dead:
		return
	dead = true
	if impact_callback.is_valid():
		impact_callback.call(pos, dir, collider, damage, power)
	queue_free()
