extends CharacterBody3D

# Minimal third-person controller: WASD move, Space jump, fixed follow camera.
# The robot is built from primitives so the slice has no external asset deps.

const SPEED := 6.0
const JUMP_VELOCITY := 10.5
const GRAVITY := 24.0
const START_POSITION := Vector3(0.0, 1.1, 0.0)

var _visual: Node3D
var _camera: Camera3D

func _ready() -> void:
	add_to_group("player")
	_build_visual()
	_build_collision()
	_build_camera()
	respawn()

func _physics_process(delta: float) -> void:
	if not Game.is_playing():
		velocity = Vector3.ZERO
		move_and_slide()
		return

	var input := Vector3.ZERO
	if Input.is_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		input.x += 1.0
	if Input.is_key_pressed(KEY_W):
		input.z -= 1.0
	if Input.is_key_pressed(KEY_S):
		input.z += 1.0

	if input.length_squared() > 0.001:
		input = input.normalized()
		var target_yaw := atan2(input.x, input.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, minf(1.0, delta * 12.0))

	velocity.x = input.x * SPEED
	velocity.z = input.z * SPEED

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_key_pressed(KEY_SPACE):
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

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var body_color := Color(0.98, 0.78, 0.22)
	var head_color := Color(1.0, 0.62, 0.18)
	var dark := Color(0.08, 0.12, 0.18)
	var accent := Color(0.65, 0.82, 0.95)
	_add_box(Vector3(0.75, 0.85, 0.55), Vector3(0.0, 0.85, 0.0), body_color)
	_add_sphere(0.32, Vector3(0.0, 1.52, 0.0), head_color)
	_add_box(Vector3(0.42, 0.14, 0.08), Vector3(0.0, 1.55, 0.27), dark)
	_add_box(Vector3(0.18, 0.55, 0.18), Vector3(-0.5, 0.82, 0.0), accent)
	_add_box(Vector3(0.18, 0.55, 0.18), Vector3(0.5, 0.82, 0.0), accent)
	_add_box(Vector3(0.2, 0.5, 0.2), Vector3(-0.22, 0.3, 0.0), dark)
	_add_box(Vector3(0.2, 0.5, 0.2), Vector3(0.22, 0.3, 0.0), dark)
	_add_box(Vector3(0.5, 0.08, 0.3), Vector3(0.0, 1.82, 0.0), accent)

func _add_box(size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	mesh.material_override = mat
	mesh.position = pos
	_visual.add_child(mesh)

func _add_sphere(radius: float, pos: Vector3, color: Color) -> void:
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
	_visual.add_child(mesh)

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
	_camera.position = Vector3(0.0, 3.8, 6.2)
	add_child(_camera)
	_camera.current = true
	_camera.look_at(global_position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
