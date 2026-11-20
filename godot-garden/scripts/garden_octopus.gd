class_name GardenOctopus
extends Node3D

# 程序化章鱼：8 条 Verlet 触手 + 距离约束 + 地面/石柱碰撞投影 + 螺旋缠绕目标 +
# 夜间/睡眠体色。触手网格每帧用 ImmediateMesh 重建，身体是低多边形球体。

const ARM_COUNT := 8
const SEGMENTS := 12
const GRAVITY := Vector3(0.0, -9.8, 0.0)
const GROUND_Y := 0.045
const POST_RADIUS := 0.6
const POST_HEIGHT := 2.2
const BODY_POS := Vector3(1.05, 0.64, 0.05)

var shadow_texture: Texture2D

var _mat: ShaderMaterial
var _arm_materials: Array[ShaderMaterial] = []
var _tip_meshes: Array[MeshInstance3D] = []
var _body_node: Node3D
var _body_lean := 0.0
var _state := "idle"
var _state_timer := 0.0
var _time := 0.0
var _night := 0.0
var _sleep := 0.0
var _blink_timer := 0.0
var _next_blink := 3.5

var _arm_points: Array = [] # Array[Array[Vector3]]
var _arm_prev: Array = []
var _arm_base_offset: Array[Vector3] = []
var _arm_dir: Array[Vector3] = []
var _arm_length: Array[float] = []
var _arm_phase: Array[float] = []
var _wrap_arms := [3, 4, 5]
var _eyes: Array[Node3D] = []


func _ready() -> void:
	_build_materials()
	_build_body()
	_build_arms()
	_build_mesh()
	set_process(true)

func set_night(night: float) -> void:
	_night = clampf(night, 0.0, 1.0)

func force_wrap() -> void:
	_state = "wrap"
	_state_timer = 0.0
	_body_lean = 1.0

# ---------------------------------------------------------------- 构建

func _build_materials() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/octopus.gdshader")
	_mat.set_shader_parameter("u_arm", 0.0)

func _unshaded(color: Color, emission := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material

func _build_body() -> void:
	_body_node = Node3D.new()
	_body_node.name = "Body"
	_body_node.position = BODY_POS
	_body_node.rotation.y = deg_to_rad(40.0)
	add_child(_body_node)

	var body := _add_sphere(_body_node, Vector3.ZERO, 0.52, _mat, 12, 8)
	body.scale = Vector3(1.15, 1.0, 1.0)
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var mantle := _add_sphere(_body_node, Vector3(0, 0.28, -0.26), 0.4, _mat, 10, 6)
	mantle.scale = Vector3(1.1, 0.9, 1.1)
	var face := _add_sphere(_body_node, Vector3(0, 0.02, 0.34), 0.3, _mat, 10, 6)
	face.scale = Vector3(1.05, 0.9, 0.9)

	var white := _unshaded(Color(0.95, 0.88, 0.75), 0.05)
	for p in [Vector3(0.22, 0.38, 0.02), Vector3(-0.24, 0.33, 0.1), Vector3(0.02, 0.44, -0.18)]:
		var spot := _add_sphere(_body_node, p, 0.08, white, 6, 3)
		spot.scale = Vector3(1.2, 0.22, 0.9)

	var eye_yellow := _unshaded(Color(0.96, 0.86, 0.22), 0.4)
	var pupil := _unshaded(Color(0.08, 0.07, 0.08))
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.21, 0.13, 0.46)
		_body_node.add_child(pivot)
		_add_sphere(pivot, Vector3.ZERO, 0.13, eye_yellow, 8, 5)
		var black := _add_sphere(pivot, Vector3(0, 0.0, 0.11), 0.055, pupil, 6, 3)
		black.scale = Vector3(0.55, 1.2, 0.4)
		_eyes.append(pivot)

	var mouth_mat := _unshaded(Color(0.35, 0.08, 0.07))
	_add_box(_body_node, Vector3(0, -0.06, 0.55), Vector3(0.14, 0.025, 0.03), mouth_mat)

	if shadow_texture != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(2.0, 1.2)
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.albedo_texture = shadow_texture
		shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
		shadow_mat.disable_receive_shadows = true
		quad.material = shadow_mat
		var shadow := MeshInstance3D.new()
		shadow.mesh = quad
		shadow.material_override = shadow_mat
		shadow.rotation.x = -PI * 0.5
		shadow.position = Vector3(BODY_POS.x, 0.02, BODY_POS.z)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)

func _build_arms() -> void:
	for i in ARM_COUNT:
		var angle := TAU * float(i) / ARM_COUNT + 0.15
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var base := BODY_POS + Vector3(cos(angle) * 0.42, -0.22, sin(angle) * 0.42)
		var length := 2.4 + float(i % 3) * 0.35
		var phase := float(i) * 1.7
		var points: Array[Vector3] = []
		var prev: Array[Vector3] = []
		for j in SEGMENTS:
			var t := float(j) / float(SEGMENTS - 1)
			var p := base + dir * (length * t) + Vector3(0, -0.15 * t * t, 0)
			p += Vector3(-dir.z, 0, dir.x) * sin(t * 2.0 + phase) * 0.15 * t
			points.append(p)
			prev.append(p)
		_arm_points.append(points)
		_arm_prev.append(prev)
		_arm_base_offset.append(base - BODY_POS)
		_arm_dir.append(dir)
		_arm_length.append(length)
		_arm_phase.append(phase)

func _build_mesh() -> void:
	var mesh := _make_arm_mesh()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.05
	tip_mesh.height = 0.1
	tip_mesh.radial_segments = 6
	tip_mesh.rings = 3
	for index in ARM_COUNT:
		var material := ShaderMaterial.new()
		material.shader = load("res://shaders/octopus_arm.gdshader")
		material.set_shader_parameter("base_radius", 0.18)
		material.set_shader_parameter("tip_radius", 0.03)
		_arm_materials.append(material)
		var instance := MeshInstance3D.new()
		instance.name = "Arm%d" % index
		instance.mesh = mesh
		instance.material_override = material
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 6, 8))
		add_child(instance)
		var tip := MeshInstance3D.new()
		tip.mesh = tip_mesh
		tip.material_override = _mat
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tip)
		_tip_meshes.append(tip)
	_update_arm_materials()

func _make_arm_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 36
	var sides := 8
	for r in rings - 1:
		var t0 := float(r) / float(rings - 1)
		var t1 := float(r + 1) / float(rings - 1)
		for k in sides:
			var k2 := (k + 1) % sides
			var u0 := float(k) / float(sides)
			var u1 := float(k2) / float(sides)
			_st_vertex(st, u0, t0)
			_st_vertex(st, u1, t0)
			_st_vertex(st, u0, t1)
			_st_vertex(st, u1, t0)
			_st_vertex(st, u1, t1)
			_st_vertex(st, u0, t1)
	return st.commit()

func _st_vertex(st: SurfaceTool, u: float, v: float) -> void:
	st.set_uv(Vector2(u, v))
	st.add_vertex(Vector3(0, v, 0))

# ---------------------------------------------------------------- 每帧

func _process(delta: float) -> void:
	var dt := minf(delta, 0.033)
	_time += delta
	_state_timer += delta
	if _state == "wrap":
		if _state_timer > 7.0:
			_state = "idle"
			_state_timer = 0.0
	elif _state_timer > 9.0:
		_state = "wrap"
		_state_timer = 0.0

	var target_lean := 1.0 if _state == "wrap" else 0.0
	_body_lean = move_toward(_body_lean, target_lean, delta * 1.6)
	var target_sleep := 0.0 if _state == "wrap" else smoothstep(0.6, 0.92, _night)
	_sleep = lerpf(_sleep, target_sleep, minf(1.0, delta * 2.0))

	var bob := sin(_time * 1.25) * 0.035
	_body_node.position = BODY_POS + Vector3(-0.13, 0, -0.09) * _body_lean + Vector3(0, bob, 0)
	_body_node.rotation.y = deg_to_rad(40.0 + 10.0 * _body_lean) + sin(_time * 0.65) * 0.02
	_body_node.rotation.z = sin(_time * 0.9) * 0.02 + _body_lean * 0.05

	for i in ARM_COUNT:
		_simulate_arm(i, dt)
	_update_arm_materials()

	_mat.set_shader_parameter("u_night", _night)
	_mat.set_shader_parameter("u_sleep", _sleep)

	_blink_timer -= delta
	if _blink_timer <= 0.0:
		_blink_timer = _next_blink
		_next_blink = 2.5 + randf() * 4.0 if _sleep < 0.5 else 6.0
	var eye_scale := 0.25 if _sleep > 0.6 else (1.0 if _blink_timer > 0.18 else 0.12)
	for eye in _eyes:
		eye.scale.y = lerpf(eye.scale.y, eye_scale, minf(1.0, delta * 18.0))

func _simulate_arm(index: int, dt: float) -> void:
	var points: Array = _arm_points[index]
	var prev: Array = _arm_prev[index]
	var base := _body_node.position + _arm_base_offset[index].rotated(Vector3.UP, _body_node.rotation.y)
	var target_array := _arm_targets(index, base)
	var spring := 3.4 if _state == "wrap" and index in _wrap_arms else (2.2 if _sleep > 0.5 else 1.35)

	for j in range(1, SEGMENTS):
		var p: Vector3 = points[j]
		var velocity: Vector3 = (p - prev[j]) * 0.9
		prev[j] = p
		p += velocity + GRAVITY * dt * dt
		p += (target_array[j] - p) * minf(1.0, spring * dt)
		points[j] = p

	points[0] = base
	var rest := _arm_length[index] / float(SEGMENTS - 1)
	for iteration in 4:
		for j in range(1, SEGMENTS):
			var a: Vector3 = points[j - 1]
			var b: Vector3 = points[j]
			var delta_vec := b - a
			var d := delta_vec.length()
			if d > 0.0001:
				var correction := delta_vec * (1.0 - rest / d) * 0.5
				if j == 1:
					points[j] = b - correction * 2.0
				else:
					points[j - 1] = a + correction
					points[j] = b - correction
		points[0] = base
		for j in range(1, SEGMENTS):
			points[j] = _collide(points[j])

func _arm_targets(index: int, base: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var direction := _arm_dir[index]
	var length := _arm_length[index]
	var phase := _arm_phase[index]
	var side := Vector3(-direction.z, 0, direction.x)
	var wrapping := _state == "wrap" and index in _wrap_arms
	var start_angle := atan2(base.z, base.x)
	for j in SEGMENTS:
		var t := float(j) / float(SEGMENTS - 1)
		var target: Vector3
		if wrapping:
			# 螺旋缠绕：绕过石柱，半径略大于柱面，随 t 上升。
			var weight := smoothstep(0.12, 0.42, t)
			var angle := start_angle + t * 0.65 * TAU
			var helix := Vector3(cos(angle) * 0.66, 0.3 + t * 1.4, sin(angle) * 0.66)
			target = base.lerp(helix, weight)
			target.y += sin(_time * 1.6 + phase + t * 3.0) * 0.02
		elif _sleep > 0.5:
			# 睡眠：触手向身体收拢。
			target = base + direction * (length * 0.22 * t) + Vector3(0, 0.1 + t * 0.08, 0)
			target += side * sin(phase + t * 2.0) * 0.12 * t
		else:
			# 清醒：触手向外伸展、沿 Y 轴缓慢旋转，形成 S 形而不是放射状直线。
			var curve_dir := direction.rotated(Vector3.UP, t * (1.05 + 0.3 * sin(phase)))
			target = base + curve_dir * (length * 0.8 * t)
			target.y += 0.1 + (sin(_time * 1.2 + phase + t * 2.2) * 0.18 + 0.2) * t + 0.22 * t * t
			target += side * sin(_time * 0.8 + phase + t * 1.8) * 0.18 * t
		out.append(target)
	return out

func _collide(point: Vector3) -> Vector3:
	var p := point
	if p.y < GROUND_Y:
		p.y = GROUND_Y
	var flat := Vector2(p.x, p.z)
	var distance := flat.length()
	if p.y < POST_HEIGHT and distance < POST_RADIUS + 0.05:
		if distance < 0.001:
			p.x = POST_RADIUS + 0.05
		else:
			var n := flat.normalized()
			p.x = n.x * (POST_RADIUS + 0.05)
			p.z = n.y * (POST_RADIUS + 0.05)
	return p

# ---------------------------------------------------------------- 触手网格

func _update_arm_materials() -> void:
	for index in _arm_materials.size():
		var material := _arm_materials[index]
		material.set_shader_parameter("arm_points", PackedVector3Array(_arm_points[index]))
		material.set_shader_parameter("u_night", _night)
		material.set_shader_parameter("u_sleep", _sleep)
		if index < _tip_meshes.size():
			_tip_meshes[index].position = _arm_points[index][SEGMENTS - 1]

# ---------------------------------------------------------------- 工具

func _add_sphere(parent: Node3D, position: Vector3, radius: float, material: Material,
		radial := 8, rings := 4) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance

func _add_box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance
