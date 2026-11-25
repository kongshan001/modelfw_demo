extends Node3D
## 苔猫：睡在踏石边的原创低模小猫。呼吸、眨眼、尾巴摆动；轻触会抬头、摆尾并扬起暖色微尘。
## 全部几何与材质均为程序化生成，不依赖外部模型。

signal interacted(id: String, message: String, anchor: Vector3)

const Geo = preload("res://scripts/geo.gd")

var display_name := "苔猫"
var display_id := "moss_cat"
var focused := false
var nightness := 1.0
var rain_amount := 0.0
var quality_high := true
var joy := 0.0
var pet_count := 0

var body_pivot: Node3D
var head_pivot: Node3D
var tail_pivot: Node3D
var eye_group: MeshInstance3D
var eye_material: StandardMaterial3D
var sparkles: CPUParticles3D
var time := 0.0
var phase := 0.0


func _ready() -> void:
	phase = fmod(absf(position.x) * 1.21 + absf(position.z) * 0.77, TAU)
	_build()


func _build() -> void:
	_build_cushion()
	body_pivot = Node3D.new()
	body_pivot.name = "BodyPivot"
	add_child(body_pivot)

	var ginger := Color(0.90, 0.55, 0.28)
	var ginger_light := Color(0.98, 0.72, 0.43)
	var cream := Color(1.0, 0.91, 0.74)
	var dark := Color(0.62, 0.34, 0.18)
	var body_st := Geo.surface()
	Geo.add_ico(body_st, Vector3(0, 0.28, -0.07), Vector3(0.33, 0.21, 0.41),
			ginger, Basis.IDENTITY, 111, 0.06)
	Geo.add_ico(body_st, Vector3(0, 0.28, -0.28), Vector3(0.32, 0.22, 0.24),
			ginger_light, Basis.IDENTITY, 112, 0.08)
	Geo.add_ico(body_st, Vector3(0, 0.28, 0.20), Vector3(0.235, 0.17, 0.20),
			cream, Basis.IDENTITY, 113, 0.07)
	Geo.add_ico(body_st, Vector3(0.0, 0.39, 0.05), Vector3(0.23, 0.045, 0.22),
			ginger_light, Basis.IDENTITY, 114, 0.12)
	for px in [-0.18, 0.18]:
		Geo.add_ico(body_st, Vector3(px, 0.075, 0.24), Vector3(0.075, 0.055, 0.13),
				cream, Basis.IDENTITY, 115 + int(px * 10.0), 0.10)
		Geo.add_ico(body_st, Vector3(px, 0.075, -0.28), Vector3(0.09, 0.06, 0.14),
				cream, Basis.IDENTITY, 121 + int(px * 10.0), 0.10)
	Geo.add_ico(body_st, Vector3(0, 0.34, -0.36), Vector3(0.10, 0.09, 0.09),
			dark, Basis.IDENTITY, 127, 0.10)
	var body_mesh := MeshInstance3D.new()
	body_mesh.name = "GingerBody"
	body_mesh.mesh = Geo.finish(body_st)
	body_mesh.material_override = Geo.make_vcol_material(0.98)
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body_pivot.add_child(body_mesh)

	head_pivot = Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position = Vector3(0, 0.45, 0.31)
	body_pivot.add_child(head_pivot)

	var head_st := Geo.surface()
	Geo.add_ico(head_st, Vector3(0, 0.08, 0.02), Vector3(0.225, 0.19, 0.19),
			ginger, Basis.IDENTITY, 131, 0.06)
	Geo.add_ico(head_st, Vector3(0, 0.02, 0.16), Vector3(0.105, 0.075, 0.085),
			cream, Basis.IDENTITY, 132, 0.07)
	Geo.add_ico(head_st, Vector3(0.0, 0.045, 0.238), Vector3(0.025, 0.017, 0.018),
			Color(0.82, 0.52, 0.50), Basis.IDENTITY, 133, 0.04)
	# 三角耳与粉色内耳。
	for ex in [-1.0, 1.0]:
		var bx: float = 0.125 * ex
		Geo.add_cone(head_st, Vector3(bx, 0.21, 0.01), 0.108, 0.23, 3,
				ginger_light, Color(1.0, 0.64, 0.45))
		Geo.add_cone(head_st, Vector3(bx, 0.245, 0.02), 0.050, 0.11, 3,
				Color(1.0, 0.66, 0.58))
	# 三根胡须 + 金铜色小铃铛。
	for side in [-1.0, 1.0]:
		for w in range(2):
			Geo.add_cylinder(head_st,
				Vector3(0.09 * side, 0.04 - 0.015 * float(w), 0.235),
				Vector3(0.30 * side, 0.055 - 0.035 * float(w), 0.27),
				0.0035, 0.0015, 3, Color(0.96, 0.90, 0.76))
	Geo.add_ico(head_st, Vector3(0, -0.07, 0.155), Vector3(0.037, 0.032, 0.022),
			Color(0.87, 0.55, 0.21), Basis.IDENTITY, 140, 0.08)
	Geo.add_ico(head_st, Vector3(-0.16, 0.02, 0.05), Vector3(0.075, 0.06, 0.06),
			cream, Basis.IDENTITY, 135, 0.08)
	Geo.add_ico(head_st, Vector3(0.16, 0.02, 0.05), Vector3(0.075, 0.06, 0.06),
			cream, Basis.IDENTITY, 136, 0.08)
	# 额头三缕短纹。
	for i in range(3):
		Geo.add_ico(head_st, Vector3(-0.07 + i * 0.07, 0.205, 0.08),
				Vector3(0.018, 0.028, 0.020), dark, Basis.IDENTITY, 140 + i, 0.04)
	var head_mesh := MeshInstance3D.new()
	head_mesh.name = "Head"
	head_mesh.mesh = Geo.finish(head_st)
	head_mesh.material_override = Geo.make_vcol_material(0.98)
	head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	head_pivot.add_child(head_mesh)

	var eye_st := Geo.surface()
	for ex in [-1.0, 1.0]:
		Geo.add_ico(eye_st, Vector3(0.083 * ex, 0.095, 0.175),
				Vector3(0.034, 0.023, 0.012),
				Color(0.98, 0.72, 0.28), Basis.IDENTITY, 150 + int(ex * 5.0), 0.02)
	eye_material = StandardMaterial3D.new()
	eye_material.albedo_color = Color(0.10, 0.09, 0.06)
	eye_material.emission_enabled = true
	eye_material.emission = Color(0.60, 0.44, 0.14)
	eye_material.emission_energy_multiplier = 0.9
	eye_material.roughness = 0.3
	eye_group = MeshInstance3D.new()
	eye_group.name = "AmberEyes"
	eye_group.mesh = Geo.finish(eye_st)
	eye_group.material_override = eye_material
	eye_group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_pivot.add_child(eye_group)

	tail_pivot = Node3D.new()
	tail_pivot.name = "TailPivot"
	tail_pivot.position = Vector3(0, 0.27, -0.37)
	body_pivot.add_child(tail_pivot)
	var tail_st := Geo.surface()
	var tail_pts := [
		Vector3(0.00, 0.02, 0.00), Vector3(0.15, 0.15, -0.10),
		Vector3(0.27, 0.31, -0.14), Vector3(0.34, 0.47, -0.06),
		Vector3(0.36, 0.58, 0.08), Vector3(0.28, 0.62, 0.19),
	]
	var tail_radii := [0.082, 0.074, 0.066, 0.058, 0.046, 0.024]
	for i in range(tail_pts.size() - 1):
		var c: Color = ginger.lerp(ginger_light, float(i) / 5.0)
		if i == 2:
			c = dark
		elif i == 3:
			c = ginger_light
		Geo.add_cylinder(tail_st, tail_pts[i], tail_pts[i + 1],
				tail_radii[i], tail_radii[i + 1], 6, c, true)
	Geo.add_ico(tail_st, tail_pts[tail_pts.size() - 1], Vector3(0.035, 0.035, 0.035),
			cream, Basis.IDENTITY, 160, 0.08)
	var tail_mesh := MeshInstance3D.new()
	tail_mesh.name = "Tail"
	tail_mesh.mesh = Geo.finish(tail_st)
	tail_mesh.material_override = Geo.make_vcol_material(0.98)
	tail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	tail_pivot.add_child(tail_mesh)

	_build_sparkles()


func _build_cushion() -> void:
	var st := Geo.surface()
	Geo.add_stone(st, Vector3(0, 0.02, 0.05), 0.85, 0.60, 0.10, 9, 211,
			Color(0.52, 0.51, 0.50), Color(0.36, 0.35, 0.40), 0.35)
	Geo.add_ico(st, Vector3(-0.44, 0.035, 0.26), Vector3(0.20, 0.025, 0.14),
			Color(0.31, 0.42, 0.31), Basis.IDENTITY, 212, 0.15)
	Geo.add_ico(st, Vector3(0.39, 0.03, -0.21), Vector3(0.17, 0.025, 0.12),
			Color(0.30, 0.40, 0.29), Basis.IDENTITY, 213, 0.15)
	var mat := Geo.make_vcol_material(0.95)
	var mi := MeshInstance3D.new()
	mi.name = "CushionStone"
	mi.mesh = Geo.finish(st)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mi)


func _build_sparkles() -> void:
	var tex := Geo.make_radial_texture(32, 2.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.albedo_color = Color(1.0, 0.78, 0.56, 0.82)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad := QuadMesh.new()
	quad.size = Vector2(0.16, 0.16)
	sparkles = CPUParticles3D.new()
	sparkles.name = "AffectionMotes"
	sparkles.emitting = false
	sparkles.one_shot = true
	sparkles.amount = 16
	sparkles.lifetime = 1.8
	sparkles.explosiveness = 0.85
	sparkles.randomness = 0.55
	sparkles.mesh = quad
	sparkles.material_override = mat
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = 0.23
	sparkles.direction = Vector3.UP
	sparkles.spread = 70.0
	sparkles.initial_velocity_min = 0.12
	sparkles.initial_velocity_max = 0.45
	sparkles.gravity = Vector3(0, 0.20, 0)
	sparkles.scale_amount_min = 0.30
	sparkles.scale_amount_max = 0.92
	sparkles.color = Color(1.0, 0.82, 0.62, 0.80)
	sparkles.position = Vector3(0, 0.65, 0.22)
	sparkles.local_coords = false
	add_child(sparkles)


func tick(delta: float, t: float, night: float, rain: float, high: bool) -> void:
	time = t
	nightness = night
	rain_amount = rain
	quality_high = high
	joy = maxf(0.0, joy - delta * 0.45)
	var breath := 1.0 + sin(t * 1.35 + phase) * 0.011
	body_pivot.scale = Vector3(1.0, breath, 1.0)
	var joy_wave := sin((1.0 - joy) * PI * 2.2) * joy
	head_pivot.rotation.y = sin(t * 0.37 + phase) * 0.13 + (0.10 if focused else 0.0)
	head_pivot.rotation.x = 0.02 + sin(t * 0.71 + phase) * 0.018 - joy_wave * 0.23
	head_pivot.position.y = 0.45 + joy_wave * 0.055
	var tail_swish := sin(t * 0.73 + phase) * 0.13 + joy * sin(t * 3.4) * 0.28
	tail_pivot.rotation.y = tail_swish
	tail_pivot.rotation.z = 0.03 + sin(t * 0.53 + phase) * 0.025 + joy * 0.10
	# 周期性眨眼（约 6.3s 一次，0.18s）。
	var bt := fmod(t + phase * 1.7, 6.3)
	var blink := 1.0
	if bt < 0.18:
		blink = 0.08 + 0.92 * absf(bt / 0.09 - 1.0)
	eye_group.scale = Vector3(1.0, blink, 1.0)
	eye_material.emission_energy_multiplier = 0.8 + nightness * 0.7 + joy * 0.5
	if focused:
		eye_material.emission_energy_multiplier += 0.25


func interact() -> bool:
	pet_count += 1
	joy = 1.0
	sparkles.restart()
	sparkles.emitting = true
	var messages := [
		"苔猫抬起头，尾巴在踏石上绕了一圈。",
		"它眯起眼，像把一小片月光收进了胡须。",
		"小猫轻轻呼噜，萤火也放慢了脚步。",
	]
	var message: String = messages[(pet_count - 1) % messages.size()]
	interacted.emit(display_id, message, get_interaction_anchor())
	return true


func set_focused(value: bool) -> void:
	focused = value


func get_interaction_anchor() -> Vector3:
	return global_position + Vector3(0, 0.72, 0.38)


func get_display_name() -> String:
	return display_name


func get_display_id() -> String:
	return display_id


func reset() -> void:
	pet_count = 0
	joy = 0.0
	focused = false
	sparkles.emitting = false


func get_joy() -> float:
	return joy
