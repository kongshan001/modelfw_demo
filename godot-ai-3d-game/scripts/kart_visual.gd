class_name KartVisual
extends Node3D

# 原创低模卡丁车。车身/轮组/尾翼/加速尾焰全部程序化；
# 玩家驾驶员优先使用 CC0 Fox.glb（带 Run 动画），缺图时退回程序化小狐狸。

const FOX_PATH := "res://assets/ai/cc0/fox/Fox.glb"
const WHEEL_RADIUS := 0.33

static var _blob_texture: ImageTexture

var body_color := Color("#f8efd7")
var accent_color := Color("#24cfd1")
var is_player := true

var _body_root: Node3D
var _wheel_root: Node3D
var _front_pivots: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _boost_flames: Array[MeshInstance3D] = []
var _driver_anim: AnimationPlayer
var _driver_model: Node3D
var _wheel_spin := 0.0
var _steer_smooth := 0.0
var _lean := 0.0
var _time := 0.0

var _mat_body: StandardMaterial3D
var _mat_accent: StandardMaterial3D
var _mat_cream: StandardMaterial3D
var _mat_dark: StandardMaterial3D
var _mat_tire: StandardMaterial3D
var _mat_flame: StandardMaterial3D


func setup(p_body: Color, p_accent: Color, player: bool) -> void:
	body_color = p_body
	accent_color = p_accent
	is_player = player
	_make_materials()
	_build_kart()
	_build_shadow()
	if is_player:
		_build_fox_driver()
	else:
		_build_robot_driver()


func _make_materials() -> void:
	_mat_body = _solid(body_color, 0.42)
	_mat_accent = _solid(accent_color, 0.36)
	_mat_cream = _solid(Color("#fff3d8"), 0.6)
	_mat_dark = _solid(Color("#203445"), 0.58)
	_mat_tire = _solid(Color("#24303b"), 0.94)
	_mat_flame = _solid(Color("#5ff8ff"), 0.25)
	_mat_flame.emission_enabled = true
	_mat_flame.emission = Color("#53dcf5")
	_mat_flame.emission_energy_multiplier = 1.35
	_mat_flame.albedo_color = Color(0.28, 0.86, 0.98, 0.86)
	_mat_flame.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_kart() -> void:
	_body_root = Node3D.new()
	_body_root.name = "Body"
	add_child(_body_root)
	_wheel_root = Node3D.new()
	_wheel_root.name = "Wheels"
	add_child(_wheel_root)

	# 低矮的卡丁车底盘，司机上半身从座舱里露出来。
	_box(_body_root, "Floorpan", Vector3(1.48, 0.11, 2.52), Vector3(0, 0.23, 0), _mat_dark)
	_box(_body_root, "Chassis", Vector3(1.32, 0.27, 1.84), Vector3(0, 0.38, 0.04), _mat_body)
	_box(_body_root, "Nose", Vector3(1.02, 0.24, 0.84), Vector3(0, 0.43, -1.26), _mat_accent)
	_box(_body_root, "NoseTip", Vector3(1.48, 0.14, 0.18), Vector3(0, 0.31, -1.70), _mat_cream)
	_box(_body_root, "FrontLip", Vector3(1.78, 0.09, 0.25), Vector3(0, 0.22, -1.78), _mat_dark)
	_box(_body_root, "FrontNumberPlate", Vector3(0.56, 0.18, 0.07), Vector3(0, 0.48, -1.70), _mat_cream)
	for side in [-1.0, 1.0]:
		_box(_body_root, "SidePod", Vector3(0.30, 0.20, 1.10), Vector3(side * 0.80, 0.39, 0.04), _mat_accent)
		_box(_body_root, "SideStripe", Vector3(0.04, 0.10, 1.72), Vector3(side * 0.66, 0.46, 0.0), _mat_cream)
		_box(_body_root, "RearPod", Vector3(0.42, 0.20, 0.44), Vector3(side * 0.70, 0.37, 0.96), _mat_body)

	# 开放座舱、低靠背，给狐狸驾驶员留出清晰的剪影。
	_box(_body_root, "CockpitRim", Vector3(1.06, 0.14, 0.94), Vector3(0, 0.54, 0.10), _mat_cream)
	_box(_body_root, "CockpitWell", Vector3(0.84, 0.10, 0.70), Vector3(0, 0.59, 0.10), _mat_dark)
	_box(_body_root, "Seat", Vector3(0.54, 0.30, 0.42), Vector3(0, 0.72, 0.40), _mat_dark)
	_box(_body_root, "SeatBack", Vector3(0.58, 0.30, 0.14), Vector3(0, 0.86, 0.58), _mat_accent)

	# 发动机、排气管、双尾灯
	_box(_body_root, "Engine", Vector3(0.60, 0.26, 0.40), Vector3(0, 0.43, 1.02), _mat_dark)
	var pipe_mesh := CylinderMesh.new()
	pipe_mesh.top_radius = 0.06
	pipe_mesh.bottom_radius = 0.08
	pipe_mesh.height = 0.34
	pipe_mesh.radial_segments = 8
	for side in [-1.0, 1.0]:
		var pipe := MeshInstance3D.new()
		pipe.name = "Exhaust"
		pipe.mesh = pipe_mesh
		pipe.position = Vector3(side * 0.26, 0.43, 1.30)
		pipe.rotation.x = PI * 0.5
		pipe.material_override = _mat_dark
		_body_root.add_child(pipe)
		_box(_body_root, "TailLamp", Vector3(0.20, 0.10, 0.05), Vector3(side * 0.53, 0.35, 1.56), _mat_flame)
	# 中央留空的双尾翼，不挡驾驶员。
	for side in [-1.0, 1.0]:
		_box(_body_root, "Winglet", Vector3(0.50, 0.08, 0.32), Vector3(side * 0.62, 0.98, 1.16), _mat_accent)
		_box(_body_root, "WingPost", Vector3(0.06, 0.26, 0.08), Vector3(side * 0.55, 0.84, 1.13), _mat_dark)
		_box(_body_root, "WingEnd", Vector3(0.08, 0.20, 0.34), Vector3(side * 0.89, 1.02, 1.16), _mat_cream)
	_box(_body_root, "RearBumper", Vector3(1.78, 0.10, 0.16), Vector3(0, 0.29, 1.48), _mat_cream)
	_box(_body_root, "BumperStripe", Vector3(0.55, 0.12, 0.19), Vector3(0, 0.33, 1.50), _mat_accent)

	# 方向盘压在胸前，不遮住狐狸的头。
	var wheel_torus := TorusMesh.new()
	wheel_torus.inner_radius = 0.14
	wheel_torus.outer_radius = 0.21
	wheel_torus.rings = 10
	wheel_torus.ring_segments = 8
	var steering := MeshInstance3D.new()
	steering.name = "SteeringWheel"
	steering.mesh = wheel_torus
	steering.position = Vector3(0, 0.82, -0.34)
	steering.rotation.x = 0.95
	steering.material_override = _mat_dark
	_body_root.add_child(steering)

	# 轮组：前轮有转向 pivot，所有轮内层负责滚动。
	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = 0.33
	tire_mesh.bottom_radius = 0.33
	tire_mesh.height = 0.28
	tire_mesh.radial_segments = 12
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.14
	hub_mesh.bottom_radius = 0.14
	hub_mesh.height = 0.30
	hub_mesh.radial_segments = 8
	for wx in [-0.92, 0.92]:
		for wz in [-0.88, 0.88]:
			var pivot := Node3D.new()
			pivot.name = "WheelPivot"
			pivot.position = Vector3(wx, 0.33, wz)
			_wheel_root.add_child(pivot)
			var spinner := Node3D.new()
			spinner.name = "WheelSpin"
			pivot.add_child(spinner)
			var tire := MeshInstance3D.new()
			tire.name = "Tire"
			tire.mesh = tire_mesh
			tire.rotation.z = PI * 0.5
			tire.material_override = _mat_tire
			spinner.add_child(tire)
			var hub := MeshInstance3D.new()
			hub.name = "Hub"
			hub.mesh = hub_mesh
			hub.rotation.z = PI * 0.5
			hub.material_override = _mat_accent
			hub.position.x = -0.01 if wx < 0.0 else 0.01
			spinner.add_child(hub)
			_spinners.append(spinner)
			if wz < 0.0:
				_front_pivots.append(pivot)
		# 前后挡泥板，补足玩具卡丁车的轮廓
		_box(_body_root, "FrontFender", Vector3(0.44, 0.10, 0.56), Vector3(wx, 0.58, -0.88), _mat_cream)
		_box(_body_root, "RearFender", Vector3(0.46, 0.10, 0.58), Vector3(wx, 0.57, 0.88), _mat_accent)

	# 车尾小旗，让玩家从追尾镜头一眼识别自己的车。
	var pole := _box(_body_root, "Antenna", Vector3(0.035, 0.90, 0.035), Vector3(-0.60, 1.14, 1.26), _mat_dark)
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.32, 0.19, 0.035)
	var flag := MeshInstance3D.new()
	flag.name = "Pennant"
	flag.mesh = flag_mesh
	flag.position = Vector3(-0.30, 1.38, 1.26)
	flag.material_override = _mat_cream if not is_player else _mat_accent
	_body_root.add_child(flag)

	# 加速尾焰
	for side in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = 0.58
		cone.radial_segments = 8
		var flame := MeshInstance3D.new()
		flame.name = "BoostFlame"
		flame.mesh = cone
		flame.position = Vector3(side * 0.26, 0.43, 1.61)
		flame.rotation.x = PI * 0.5
		flame.material_override = _mat_flame
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.visible = false
		_body_root.add_child(flame)
		_boost_flames.append(flame)


func _build_shadow() -> void:
	if _blob_texture == null:
		_blob_texture = _make_blob_texture()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _blob_texture
	mat.albedo_color = Color(0.05, 0.09, 0.14, 0.62)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.7, 3.8)
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = plane
	shadow.material_override = mat
	shadow.position = Vector3(0, 0.085, 0.12)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _make_blob_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var p := Vector2((float(x) + 0.5) / float(size) * 2.0 - 1.0, (float(y) + 0.5) / float(size) * 2.0 - 1.0)
			var d := clampf(1.0 - p.length(), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, d * d * 0.9))
	return ImageTexture.create_from_image(img)


func _build_fox_driver() -> void:
	if not ResourceLoader.exists(FOX_PATH):
		_build_fallback_fox()
		return
	var packed := load(FOX_PATH) as PackedScene
	if packed == null:
		_build_fallback_fox()
		return
	var model := packed.instantiate() as Node3D
	if model == null:
		_build_fallback_fox()
		return
	_driver_model = Node3D.new()
	_driver_model.name = "FoxDriver"
	_driver_model.rotation.y = PI
	_driver_model.scale = Vector3.ONE * 0.0078
	_driver_model.position = Vector3(0.0, 0.63, 0.08)
	_body_root.add_child(_driver_model)
	_driver_model.add_child(model)
	_driver_anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _driver_anim != null and _driver_anim.has_animation("Run"):
		_driver_anim.play("Run", 0.15, 1.35)
		_driver_anim.get_animation("Run").loop_mode = Animation.LOOP_LINEAR
	# 小围巾（不依赖骨骼，作为整体色块）
	var scarf := _box(_body_root, "Scarf", Vector3(0.34, 0.11, 0.46), Vector3(0.0, 0.94, 0.44), _mat_accent)
	scarf.rotation.x = -0.10


func _build_fallback_fox() -> void:
	push_warning("KartVisual: Fox.glb unavailable, using procedural driver fallback")
	_driver_model = Node3D.new()
	_driver_model.name = "FoxDriverFallback"
	_body_root.add_child(_driver_model)
	var orange := _solid(Color("#ee8b3e"), 0.75)
	var cream := _solid(Color("#fff0d2"), 0.75)
	var dark := _solid(Color("#302b35"), 0.6)
	_sphere_node(_driver_model, "Body", 0.29, Vector3(0, 0.98, 0.12), orange)
	_sphere_node(_driver_model, "Head", 0.25, Vector3(0, 1.28, -0.08), orange)
	_sphere_node(_driver_model, "Muzzle", 0.13, Vector3(0, 1.22, -0.30), cream)
	for side in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.11
		ear.height = 0.28
		ear.radial_segments = 6
		var ear_node := MeshInstance3D.new()
		ear_node.mesh = ear
		ear_node.position = Vector3(side * 0.14, 1.52, -0.05)
		ear_node.material_override = orange
		_driver_model.add_child(ear_node)
		_sphere_node(_driver_model, "Eye", 0.035, Vector3(side * 0.10, 1.32, -0.29), dark)
	var tail := CylinderMesh.new()
	tail.top_radius = 0.0
	tail.bottom_radius = 0.17
	tail.height = 0.65
	tail.radial_segments = 7
	var tail_node := MeshInstance3D.new()
	tail_node.name = "Tail"
	tail_node.mesh = tail
	tail_node.position = Vector3(0.22, 0.95, 0.52)
	tail_node.rotation.z = -0.85
	tail_node.material_override = orange
	_driver_model.add_child(tail_node)
	var tip := _sphere_node(_driver_model, "TailTip", 0.10, Vector3(0.45, 0.99, 0.55), cream)


func _build_robot_driver() -> void:
	_driver_model = Node3D.new()
	_driver_model.name = "RivalDriver"
	_body_root.add_child(_driver_model)
	_sphere_node(_driver_model, "Helmet", 0.25, Vector3(0, 1.04, 0.22), _mat_accent)
	var visor := _box(_driver_model, "Visor", Vector3(0.34, 0.11, 0.09), Vector3(0, 1.05, -0.02), _mat_dark)
	visor.rotation.x = 0.05
	var antenna := _box(_driver_model, "Antenna", Vector3(0.035, 0.34, 0.035), Vector3(0.15, 1.30, 0.20), _mat_cream)
	antenna.rotation.z = -0.20
	_sphere_node(_driver_model, "AntennaTip", 0.055, Vector3(0.195, 1.46, 0.20), _mat_accent)
	_box(_driver_model, "Shoulders", Vector3(0.58, 0.18, 0.30), Vector3(0, 0.88, 0.24), _mat_accent)


func _sphere_node(parent: Node3D, node_name: String, radius: float, pos: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = sphere
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = pos
	node.material_override = material
	parent.add_child(node)
	return node


func update_motion(delta: float, speed: float, steer: float, boosting: bool) -> void:
	_time += delta
	_steer_smooth = lerpf(_steer_smooth, steer, 1.0 - exp(-delta * 10.0))
	_wheel_spin += speed * delta / WHEEL_RADIUS
	for i in _front_pivots.size():
		_front_pivots[i].rotation.y = -_steer_smooth * 0.38
	for spinner in _spinners:
		spinner.rotation.x = _wheel_spin
	var target_lean := -_steer_smooth * clampf(absf(speed) / 22.0, 0.0, 1.0) * 0.075
	_lean = lerpf(_lean, target_lean, 1.0 - exp(-delta * 7.0))
	if _body_root != null:
		_body_root.rotation.z = _lean
		_body_root.position.y = sin(_time * 11.0 + speed * 0.24) * 0.012 * clampf(speed / 10.0, 0.0, 1.0)
	for flame in _boost_flames:
		flame.visible = boosting
		if boosting:
			var pulse := 0.86 + sin(_time * 24.0) * 0.18
			flame.scale = Vector3(0.90, pulse, 0.90)
	if _driver_anim != null:
		_driver_anim.speed_scale = 0.75 + clampf(absf(speed) / 24.0, 0.0, 1.0) * 1.1


func set_boosting(active: bool) -> void:
	for flame in _boost_flames:
		flame.visible = active
