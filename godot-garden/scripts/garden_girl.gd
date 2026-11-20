class_name GardenGirl
extends Node3D

# 低多边形小女孩：红上衣、白裙、金发、黑腿；沿石径行走并摆动手脚。

var shadow_texture: Texture2D
var walking := true

var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _phase := 0.0

func _ready() -> void:
	_build()

func _process(delta: float) -> void:
	if walking:
		_phase += delta * 9.0
		var swing := sin(_phase) * 0.55
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.8
		_arm_r.rotation.x = swing * 0.8
		_body.position.y = sin(_phase * 2.0) * 0.016
	else:
		var settle := minf(1.0, delta * 10.0)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, settle)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, settle)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.0, settle)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.0, settle)
		_body.position.y = lerpf(_body.position.y, 0.0, settle)

func _build() -> void:
	var skin := _mat(Color(0.93, 0.77, 0.61))
	var red := _mat(Color(0.55, 0.12, 0.1))
	var white := _mat(Color(0.86, 0.83, 0.74))
	var black := _mat(Color(0.075, 0.065, 0.06))
	var hair := _mat(Color(0.85, 0.68, 0.28))

	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	# 裙摆 / 上衣 / 领口
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.1
	skirt.bottom_radius = 0.22
	skirt.height = 0.34
	skirt.radial_segments = 10
	_attach(_body, skirt, white, Vector3(0, 0.52, 0))
	var top := CylinderMesh.new()
	top.top_radius = 0.1
	top.bottom_radius = 0.13
	top.height = 0.28
	top.radial_segments = 10
	_attach(_body, top, red, Vector3(0, 0.8, 0))
	var collar := BoxMesh.new()
	collar.size = Vector3(0.16, 0.04, 0.14)
	_attach(_body, collar, white, Vector3(0, 0.95, -0.02))

	# 头 / 头发 / 眼睛
	var head := SphereMesh.new()
	head.radius = 0.15
	head.height = 0.3
	head.radial_segments = 10
	head.rings = 6
	_attach(_body, head, skin, Vector3(0, 1.08, 0))
	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.17
	hair_cap.height = 0.3
	hair_cap.radial_segments = 10
	hair_cap.rings = 6
	var hair_node := _attach(_body, hair_cap, hair, Vector3(0, 1.13, 0.01))
	hair_node.scale = Vector3(1.0, 0.85, 1.0)
	var back_hair := BoxMesh.new()
	back_hair.size = Vector3(0.28, 0.26, 0.12)
	_attach(_body, back_hair, hair, Vector3(0, 1.0, 0.11))
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.018
		eye.height = 0.036
		eye.radial_segments = 6
		eye.rings = 3
		_attach(_body, eye, black, Vector3(side * 0.055, 1.08, -0.138))
		var strand := BoxMesh.new()
		strand.size = Vector3(0.045, 0.22, 0.05)
		_attach(_body, strand, hair, Vector3(side * 0.15, 0.99, 0.01))

	# 手脚枢轴
	_leg_l = _make_limb(_body, Vector3(-0.06, 0.42, 0), 0.035, 0.32, black, true)
	_leg_r = _make_limb(_body, Vector3(0.06, 0.42, 0), 0.035, 0.32, black, true)
	_arm_l = _make_limb(_body, Vector3(-0.155, 0.9, 0), 0.028, 0.24, white, false)
	_arm_r = _make_limb(_body, Vector3(0.155, 0.9, 0), 0.028, 0.24, white, false)

	# 脚下软阴影
	if shadow_texture != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.95, 0.95)
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.albedo_texture = shadow_texture
		shadow_mat.albedo_color = Color(1, 1, 1, 0.52)
		shadow_mat.disable_receive_shadows = true
		quad.material = shadow_mat
		var shadow := MeshInstance3D.new()
		shadow.mesh = quad
		shadow.material_override = shadow_mat
		shadow.rotation.x = -PI * 0.5
		shadow.position = Vector3(0, 0.02, 0)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shadow)

	# 一点暖色补光，避免深夜完全没入黑暗
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.9, 0.15)
	light.light_color = Color(1.0, 0.76, 0.55)
	light.light_energy = 0.32
	light.omni_range = 2.5
	light.shadow_enabled = false
	add_child(light)

func _make_limb(parent: Node3D, pos: Vector3, radius: float, length: float,
		material: Material, leg: bool) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 0.9
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0, -length * 0.5, 0)
	pivot.add_child(instance)
	if leg:
		var shoe_mesh := BoxMesh.new()
		shoe_mesh.size = Vector3(0.09, 0.055, 0.15)
		var shoe_instance := MeshInstance3D.new()
		shoe_instance.mesh = shoe_mesh
		shoe_instance.material_override = _mat(Color(0.16, 0.1, 0.08))
		shoe_instance.position = Vector3(0, -length - 0.02, -0.03)
		pivot.add_child(shoe_instance)
	return pivot

func _attach(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _mat(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
