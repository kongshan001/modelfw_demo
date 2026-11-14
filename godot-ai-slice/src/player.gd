extends CharacterBody3D

# Minimal third-person controller: WASD move, Space jump, fixed follow camera.
# The robot is built from primitives so the slice has no external asset deps.

const HeadProjectileScript := preload("res://src/head_projectile.gd")

const SPEED := 6.0
const JUMP_VELOCITY := 10.5
const GRAVITY := 24.0
const START_POSITION := Vector3(0.0, 1.1, 0.0)
const CAMERA_BASE := Vector3(0.0, 3.8, 6.2)

var _visual: Node3D
var _head: Node3D
var _camera: Camera3D
var _shake_time := 0.0
var _shake_duration := 0.0
var _shake_strength := 0.0
var _head_available := true
var _head_return := 0.0
var _demo_override := false
var _demo_dir := Vector3.ZERO
var _demo_jump := false

func _ready() -> void:
	add_to_group("player")
	_build_visual()
	_build_collision()
	_build_camera()
	respawn()

func _process(delta: float) -> void:
	if _camera == null:
		return
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var falloff := _shake_time / maxf(_shake_duration, 0.001)
		var amount := _shake_strength * falloff
		_camera.position = CAMERA_BASE + Vector3(
			randf_range(-amount, amount),
			randf_range(-amount, amount),
			0.0
		)
	else:
		_camera.position = CAMERA_BASE
	if not _head_available:
		_head_return -= delta
		if _head_return <= 0.0:
			_head_available = true
			if _head != null:
				_head.visible = true

func shake(strength: float = 0.12, duration: float = 0.18) -> void:
	_shake_strength = strength
	_shake_duration = duration
	_shake_time = duration

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input := Vector3.ZERO
	var jump_pressed := false
	if _demo_override:
		input = _demo_dir
		jump_pressed = _demo_jump
	else:
		if Input.is_key_pressed(KEY_A):
			input.x -= 1.0
		if Input.is_key_pressed(KEY_D):
			input.x += 1.0
		if Input.is_key_pressed(KEY_W):
			input.z -= 1.0
		if Input.is_key_pressed(KEY_S):
			input.z += 1.0
		jump_pressed = Input.is_key_pressed(KEY_SPACE)

	if input.length_squared() > 0.001:
		input = input.normalized()
		var target_yaw := atan2(input.x, input.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(1.0, delta * 12.0))

	velocity.x = input.x * SPEED
	velocity.z = input.z * SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif jump_pressed:
		velocity.y = JUMP_VELOCITY
	else:
		velocity.y = 0.0

	move_and_slide()
	if global_position.y < -12.0:
		respawn()

func respawn() -> void:
	global_position = START_POSITION
	velocity = Vector3.ZERO
	if _visual != null:
		_visual.rotation = Vector3.ZERO
	_head_available = true
	_head_return = 0.0
	if _head != null:
		_head.visible = true

func throw_head() -> void:
	if not _head_available or not Game.is_playing():
		return
	var parent := get_parent()
	if parent == null:
		return
	_head_available = false
	_head_return = 1.2
	if _head != null:
		_head.visible = false
	var dir := -_camera.global_transform.basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3(0.0, 0.0, -1.0)
	dir = dir.normalized()
	var projectile := Area3D.new()
	projectile.name = "HeadProjectile"
	projectile.set_script(HeadProjectileScript)
	parent.add_child(projectile)
	projectile.global_position = _head.global_position
	projectile.call("launch", dir)
	shake(0.06, 0.12)

func set_demo_input(dir: Vector3, jump: bool = false) -> void:
	_demo_override = true
	_demo_dir = dir
	_demo_jump = jump

func clear_demo_input() -> void:
	_demo_override = false
	_demo_dir = Vector3.ZERO
	_demo_jump = false

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body_color := Color(0.98, 0.78, 0.22)
	var head_color := Color(1.0, 0.62, 0.18)
	var dark := Color(0.08, 0.12, 0.18)
	var accent := Color(0.65, 0.82, 0.95)
	_add_box(Vector3(0.75, 0.85, 0.55), Vector3(0.0, 0.85, 0.0), body_color)
	_add_box(Vector3(0.18, 0.55, 0.18), Vector3(-0.5, 0.82, 0.0), accent)
	_add_box(Vector3(0.18, 0.55, 0.18), Vector3(0.5, 0.82, 0.0), accent)
	_add_box(Vector3(0.2, 0.5, 0.2), Vector3(-0.22, 0.3, 0.0), dark)
	_add_box(Vector3(0.2, 0.5, 0.2), Vector3(0.22, 0.3, 0.0), dark)

	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0.0, 1.52, 0.0)
	_visual.add_child(_head)
	_add_sphere(0.32, Vector3.ZERO, head_color, _head)
	_add_box(Vector3(0.42, 0.14, 0.08), Vector3(0.0, 0.03, 0.27), dark, _head)
	_add_box(Vector3(0.5, 0.08, 0.3), Vector3(0.0, 0.3, 0.0), accent, _head)

func _add_box(size: Vector3, pos: Vector3, color: Color, parent: Node3D = null) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mesh.material_override = mat
	mesh.position = pos
	var target: Node3D = _visual
	if parent != null:
		target = parent
	target.add_child(mesh)

func _add_sphere(radius: float, pos: Vector3, color: Color, parent: Node3D = null) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	mesh.material_override = mat
	mesh.position = pos
	var target: Node3D = _visual
	if parent != null:
		target = parent
	target.add_child(mesh)

func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.85, 0.0)
	add_child(shape)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "PlayerCamera"
	_camera.fov = 55.0
	_camera.position = CAMERA_BASE
	add_child(_camera)
	_camera.current = true
	_camera.look_at(global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
