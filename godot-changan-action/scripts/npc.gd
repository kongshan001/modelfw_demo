extends Node3D
class_name ChanganNPC

## 阿禾（面摊小掌柜）/ 闻九（老更夫）。CC0 KayKit 网格 + 程序化身份道具：
## 围裙/发髻/长筷、披风/更锣/长须。只做 idle/talk，不参与战斗。

var npc_id := "ahe"
var display_name := "阿禾"
var model_root: Node3D
var anim: AnimationPlayer
var body_tint := Color(0.95, 0.55, 0.45)
var name_label: Label3D


func setup(id: String) -> void:
	npc_id = id


func _ready() -> void:
	if npc_id == "wenjiu":
		display_name = "闻九"
		body_tint = Color(0.55, 0.68, 0.95)
		_build_model("res://assets/models/kaykit/Rogue_Hooded.glb", 0.80)
		_add_wenjiu_props()
	else:
		display_name = "阿禾"
		body_tint = Color(1.0, 0.58, 0.48)
		_build_model("res://assets/models/kaykit/Mage.glb", 0.76)
		_add_ahe_props()
	_build_shadow()
	_add_name_label()
	if anim != null and anim.has_animation("Idle"):
		anim.play("Idle", 0.2)
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR


func _add_name_label() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Hiragino Sans GB",
		"Noto Sans CJK SC", "Microsoft YaHei", "sans-serif"])
	var label := Label3D.new()
	label.text = display_name
	label.font = font
	label.font_size = 22
	label.outline_size = 6
	label.outline_modulate = Color(0.02, 0.02, 0.04, 0.95)
	label.modulate = Color(1.0, 0.78, 0.42)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.00085
	label.position = Vector3(0, 2.08, 0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	name_label = label


func _process(_delta: float) -> void:
	if name_label == null:
		return
	var cam := get_viewport().get_camera_3d()
	name_label.visible = cam != null and cam.global_position.distance_to(global_position) < 17.0


func _build_model(path: String, scale_value: float) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		return
	model_root = Node3D.new()
	model_root.scale = Vector3.ONE * scale_value
	add_child(model_root)
	var model: Node3D = packed.instantiate()
	model_root.add_child(model)
	_hide_props(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var tex: Texture2D = null
	for node in meshes:
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if tex == null and mat is StandardMaterial3D:
				tex = (mat as StandardMaterial3D).albedo_texture
	var hue := 0.985 if npc_id != "wenjiu" else 0.66
	var sat := 0.95 if npc_id != "wenjiu" else 0.62
	if tex != null:
		var tint := ShaderMaterial.new()
		tint.shader = load("res://shaders/character_tint.gdshader")
		tint.set_shader_parameter("albedo_tex", tex)
		tint.set_shader_parameter("target_hue", hue)
		tint.set_shader_parameter("hue_mix", 0.88)
		tint.set_shader_parameter("saturation", sat)
		tint.set_shader_parameter("value_scale", 1.08)
		tint.set_shader_parameter("rim_color", Color(1.0, 0.72, 0.34) if npc_id != "wenjiu" else Color(0.55, 0.68, 1.0))
		tint.set_shader_parameter("rim_strength", 0.36)
		tint.set_shader_parameter("emission_strength", 0.08)
		for node in meshes:
			var mi2: MeshInstance3D = node
			for i in mi2.mesh.get_surface_count():
				mi2.set_surface_override_material(i, tint)


func _hide_props(root: Node) -> void:
	var keywords := ["Dagger", "Crossbow", "Knife", "Sword", "Arrow", "Bow",
		"Shield", "Quiver", "Axe", "Mug", "Wand", "Staff", "Spellbook", "Bomb", "Book"]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for key in keywords:
			if String(node.name).contains(key):
				(node as MeshInstance3D).visible = false
				break


func _mat(color: Color, roughness := 0.85, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.disable_receive_shadows = true
	return m


func _part(mesh: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(mi)
	return mi


func _add_ahe_props() -> void:
	# 围裙（朱砂）+ 发髻 + 长筷
	var apron := BoxMesh.new()
	apron.size = Vector3(0.52, 0.72, 0.08)
	_part(apron, Vector3(0, 0.92, 0.20), _mat(Color(0.62, 0.16, 0.12), 0.92))
	var bun := SphereMesh.new()
	bun.radius = 0.13
	bun.height = 0.24
	_part(bun, Vector3(0, 1.86, -0.10), _mat(Color(0.10, 0.075, 0.06), 0.8))
	for sx in [-0.07, 0.07]:
		var stick := CylinderMesh.new()
		stick.top_radius = 0.012
		stick.bottom_radius = 0.014
		stick.height = 0.36
		stick.radial_segments = 6
		_part(stick, Vector3(sx, 1.92, -0.14), _mat(Color(0.92, 0.84, 0.68), 0.7),
			Vector3(0.25, 0, sx * 1.2))
	var band := TorusMesh.new()
	band.inner_radius = 0.19
	band.outer_radius = 0.23
	band.rings = 20
	band.ring_segments = 6
	_part(band, Vector3(0, 1.0, 0.05), _mat(Color(0.94, 0.88, 0.74), 0.9), Vector3(PI * 0.5, 0, 0))


func _add_wenjiu_props() -> void:
	# 旧披风（靛青）+ 更锣（黄铜）+ 长须
	var cloak := BoxMesh.new()
	cloak.size = Vector3(0.72, 1.05, 0.22)
	_part(cloak, Vector3(0, 1.02, -0.16), _mat(Color(0.12, 0.20, 0.34), 0.94))
	var gong := CylinderMesh.new()
	gong.top_radius = 0.26
	gong.bottom_radius = 0.26
	gong.height = 0.035
	gong.radial_segments = 24
	_part(gong, Vector3(0.30, 1.03, 0.24), _mat(Color(0.68, 0.50, 0.20), 0.35, 0.65),
		Vector3(PI * 0.5, 0, 0.2))
	var mallet := CylinderMesh.new()
	mallet.top_radius = 0.03
	mallet.bottom_radius = 0.035
	mallet.height = 0.44
	mallet.radial_segments = 8
	_part(mallet, Vector3(-0.34, 1.18, 0.15), _mat(Color(0.32, 0.20, 0.12), 0.8),
		Vector3(0.2, 0, 0.45))
	var beard := BoxMesh.new()
	beard.size = Vector3(0.20, 0.36, 0.08)
	_part(beard, Vector3(0, 1.54, 0.18), _mat(Color(0.86, 0.84, 0.80), 0.95))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.17
	cap.bottom_radius = 0.21
	cap.height = 0.16
	cap.radial_segments = 12
	_part(cap, Vector3(0, 1.88, 0), _mat(Color(0.10, 0.10, 0.14), 0.9))


func _build_shadow() -> void:
	var blob := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.5
	cm.height = 0.012
	cm.radial_segments = 16
	blob.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.38)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	blob.material_override = mat
	blob.position.y = 0.018
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func face_to(pos: Vector3) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		rotation.y = atan2(d.x, d.z)


func play_talk() -> void:
	if anim != null and anim.has_animation("Interact"):
		anim.play("Interact", 0.2, 0.8)
