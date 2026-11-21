extends CharacterBody3D
class_name ChanganEnemy

## 灯市敌人：泼皮（近战 2 连）/ 油贩（掷油瓶 + 火）/ 打手（砸地 + 冲撞）/
## 霍三更（Boss，两阶段）。共享 KayKit CC0 骨架与 76 段动作；造型用程序化
## 色键、半面具与铁尺重做。AI 用攻击令牌保证 1vN 不同时糊脸。

signal hp_changed(hp: int, max_hp: int)
signal died(enemy)
signal phase_changed(phase: int)
signal attack_telegraphed

const ARCHETYPES := {
	"thug": {
		"name": "泼皮", "model": "res://assets/models/kaykit/Rogue_Hooded.glb",
		"hp": 40, "speed": 3.0, "poise": 1, "damage": 8, "attack_range": 2.0,
		"aggro": 9.0, "scale": 0.78, "radius": 0.33, "height": 1.68,
		"tint": Color(0.95, 0.68, 0.58), "rim": Color(1.0, 0.45, 0.18),
	},
	"oil": {
		"name": "油贩", "model": "res://assets/models/kaykit/Mage.glb",
		"hp": 30, "speed": 3.6, "poise": 1, "damage": 6, "attack_range": 2.0,
		"aggro": 11.0, "scale": 0.78, "radius": 0.33, "height": 1.70,
		"tint": Color(0.60, 0.92, 0.74), "rim": Color(0.35, 1.0, 0.62),
	},
	"brute": {
		"name": "打手", "model": "res://assets/models/kaykit/Knight.glb",
		"hp": 90, "speed": 2.4, "poise": 3, "damage": 15, "attack_range": 2.4,
		"aggro": 10.0, "scale": 0.90, "radius": 0.40, "height": 1.95,
		"tint": Color(0.72, 0.78, 0.98), "rim": Color(0.55, 0.68, 1.0),
	},
	"boss": {
		"name": "霍三更", "model": "res://assets/models/kaykit/Knight.glb",
		"hp": 180, "speed": 3.4, "poise": 5, "damage": 12, "attack_range": 2.8,
		"aggro": 16.0, "scale": 1.02, "radius": 0.46, "height": 2.15,
		"tint": Color(0.64, 0.48, 0.46), "rim": Color(1.0, 0.38, 0.10),
	},
}

var archetype := "thug"
var display_name := "泼皮"
var max_hp := 40
var hp := 40
var move_speed := 3.0
var poise_max := 1
var poise := 1
var attack_range := 2.0
var aggro_range := 9.0
var damage_base := 8
var model_scale := 0.78
var body_tint := Color.WHITE
var rim_color := Color.WHITE

var main: Node
var player: ChanganPlayer
var slot := 0
var active := false
var frozen := false
var is_dead := false
var phase := 1
var state := "idle"
var attack_kind := ""
var attack_t := 0.0
var attack_cooldown := 0.0
var attack_cycle := 0
var token_held := false
var alert_t := 0.62
var circle_t := 0.0
var attack_check := 0.0
var stagger_t := 0.0
var flinch_t := 0.0
var knockdown_t := 0.0
var knockdown_phase := ""
var getup_t := 0.0
var poise_timer := 0.0
var charge_dir := Vector3.FORWARD
var hits_taken := 0
var lamp_break_used_phase := 0
var model_root: Node3D
var anim: AnimationPlayer
var mesh_instances: Array[MeshInstance3D] = []
var telegraph_disc: MeshInstance3D
var telegraph_line: MeshInstance3D
var telegraph_mat: StandardMaterial3D
var line_mat: StandardMaterial3D
var blink_light: OmniLight3D
var blob: MeshInstance3D
var _flash_mat: StandardMaterial3D
var _flash_timer := 0.0
var _plan: Dictionary = {}
var _hits_fired: Array[bool] = []
var _charge_t := 0.0
var _charge_hit_done := false
var _rng := RandomNumberGenerator.new()
var _index_in_wave := 0
var boss_aura: CPUParticles3D


func setup(kind: String, spawn: Vector3, main_ref: Node, player_ref: ChanganPlayer,
		slot_index := 0, wave_index := 0) -> void:
	archetype = kind
	main = main_ref
	player = player_ref
	slot = slot_index
	_index_in_wave = wave_index
	position = spawn
	var data: Dictionary = ARCHETYPES[kind]
	display_name = data["name"]
	max_hp = int(data["hp"])
	hp = max_hp
	move_speed = float(data["speed"])
	poise_max = int(data["poise"])
	poise = poise_max
	attack_range = float(data["attack_range"])
	aggro_range = float(data["aggro"])
	damage_base = int(data["damage"])
	model_scale = float(data["scale"])
	body_tint = data["tint"]
	rim_color = data["rim"]
	_rng.seed = hash(kind) + wave_index * 97
	attack_cooldown = 0.6 + 0.35 * slot


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	var cap := CapsuleShape3D.new()
	cap.radius = float(ARCHETYPES[archetype]["radius"])
	cap.height = float(ARCHETYPES[archetype]["height"])
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = cap.height * 0.5
	add_child(col)
	_build_model()
	_build_shadow()
	_build_telegraph()
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.0, 0.72, 0.42, 0.55)
	_flash_mat.disable_receive_shadows = true
	hp_changed.emit(hp, max_hp)
	if archetype == "boss":
		add_to_group("boss")


func _build_model() -> void:
	var path: String = ARCHETYPES[archetype]["model"]
	var packed: PackedScene = load(path)
	if packed == null:
		push_error("ChanganEnemy missing model " + path)
		return
	model_root = Node3D.new()
	model_root.name = "Model"
	model_root.scale = Vector3.ONE * model_scale
	add_child(model_root)
	var model: Node3D = packed.instantiate()
	model_root.add_child(model)
	_hide_props(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var tex: Texture2D = null
	for node in meshes:
		var mi: MeshInstance3D = node
		mesh_instances.append(mi)
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if tex == null and mat is StandardMaterial3D:
				tex = (mat as StandardMaterial3D).albedo_texture
	if archetype == "boss":
		# 霍三更：黑长袍 + 余烬橙边，专门压暗以区分于杂兵
		var boss_mat := StandardMaterial3D.new()
		boss_mat.albedo_color = Color(0.13, 0.085, 0.095)
		boss_mat.roughness = 0.62
		boss_mat.metallic = 0.30
		boss_mat.emission_enabled = true
		boss_mat.emission = Color(0.55, 0.11, 0.035)
		boss_mat.emission_energy_multiplier = 0.26
		boss_mat.rim_enabled = true
		boss_mat.rim = 0.90
		boss_mat.rim_tint = 0.65
		for node in meshes:
			var mi_b: MeshInstance3D = node
			for i in mi_b.mesh.get_surface_count():
				mi_b.set_surface_override_material(i, boss_mat)
		_build_boss_signature(model)
		return
	var hue := 0.02
	var sat := 1.12
	var val := 1.05
	var rim_strength := 0.44
	var emission := 0.10
	match archetype:
		"oil":
			hue = 0.42
			sat = 1.10
			val = 1.12
			rim_strength = 0.42
		"brute":
			hue = 0.60
			sat = 0.72
			val = 0.96
			rim_strength = 0.40
			emission = 0.07
		"boss":
			hue = 0.055
			sat = 1.75
			val = 0.50
			rim_strength = 1.05
			emission = 0.46
	if tex != null:
		var tint := ShaderMaterial.new()
		tint.shader = load("res://shaders/character_tint.gdshader")
		tint.set_shader_parameter("albedo_tex", tex)
		tint.set_shader_parameter("target_hue", hue)
		tint.set_shader_parameter("hue_mix", 0.90)
		tint.set_shader_parameter("saturation", sat)
		tint.set_shader_parameter("value_scale", val)
		tint.set_shader_parameter("rim_color", rim_color)
		tint.set_shader_parameter("rim_strength", rim_strength)
		tint.set_shader_parameter("emission_strength", emission)
		for node in meshes:
			var mi2: MeshInstance3D = node
			for i in mi2.mesh.get_surface_count():
				mi2.set_surface_override_material(i, tint)
	if archetype == "thug":
		_add_thug_scarf()
	elif archetype == "oil":
		_add_oil_bottle(model_root)
	elif archetype == "brute":
		_add_brute_plates()


func _hide_props(root: Node) -> void:
	var keywords := ["Dagger", "Crossbow", "Knife", "Sword", "Arrow", "Bow",
		"Shield", "Quiver", "Axe", "Mug", "Wand", "Staff", "Spellbook", "Bomb", "Book"]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for key in keywords:
			if String(node.name).contains(key):
				(node as MeshInstance3D).visible = false
				break


func _build_boss_signature(_model: Node3D) -> void:
	# 半面具 + 橙眼 + 双角：霍三更的原创剪影（不依赖骨骼，保证动画下不丢）
	var mask := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.50, 0.19, 0.07)
	mask.mesh = bm
	mask.material_override = _mat(Color(0.055, 0.05, 0.06), 0.35, 0.7)
	mask.position = Vector3(0, 1.62, 0.72)
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(mask)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.42, 0.10)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.38, 0.08)
	eye_mat.emission_energy_multiplier = 5.0
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.095, 0.032, 0.02)
		eye.mesh = em
		eye.material_override = eye_mat
		eye.position = Vector3(sx * 0.10, 1.655, 0.775)
		model_root.add_child(eye)
	var horn_mat := _mat(Color(0.12, 0.10, 0.10), 0.45, 0.4)
	for sx in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.005
		cone.bottom_radius = 0.075
		cone.height = 0.34
		cone.radial_segments = 6
		horn.mesh = cone
		horn.material_override = horn_mat
		horn.position = Vector3(sx * 0.30, 1.88, 0.02)
		horn.rotation.z = sx * 0.45
		model_root.add_child(horn)
	# 铁尺（长杆，橙光尺锋）
	var ruler := Node3D.new()
	ruler.name = "IronRuler"
	ruler.position = Vector3(0.58, 0.68, 0.18)
	ruler.rotation = Vector3(0.12, 0, -0.16)
	model_root.add_child(ruler)
	var rod := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.065, 1.42, 0.085)
	rod.mesh = rm
	rod.material_override = _mat(Color(0.16, 0.16, 0.19), 0.30, 0.8)
	rod.position = Vector3(0, 0.42, 0)
	rod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ruler.add_child(rod)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.085, 0.20, 0.10)
	tip.mesh = tm
	var tip_mat := StandardMaterial3D.new()
	tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip_mat.albedo_color = Color(1.0, 0.35, 0.06)
	tip_mat.emission_enabled = true
	tip_mat.emission = Color(1.0, 0.32, 0.05)
	tip_mat.emission_energy_multiplier = 2.6
	tip.material_override = tip_mat
	tip.position = Vector3(0, 1.16, 0)
	ruler.add_child(tip)
	# 肩披 + 长袍后摆
	var mantle := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.92, 0.34, 0.50)
	mantle.mesh = mm
	mantle.material_override = _mat(Color(0.055, 0.05, 0.06), 0.9)
	mantle.position = Vector3(0, 1.38, -0.02)
	mantle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(mantle)
	var robe := MeshInstance3D.new()
	var rbm := BoxMesh.new()
	rbm.size = Vector3(0.66, 1.05, 0.14)
	robe.mesh = rbm
	robe.material_override = _mat(Color(0.09, 0.065, 0.07), 0.95)
	robe.position = Vector3(0, 0.98, -0.25)
	model_root.add_child(robe)
	# 二阶段余烬（无实光，纯 emissive，保持 ≤5 实光）
	boss_aura = CPUParticles3D.new()
	boss_aura.amount = 60
	boss_aura.lifetime = 1.3
	boss_aura.local_coords = false
	boss_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	boss_aura.emission_sphere_radius = 0.55
	boss_aura.direction = Vector3.UP
	boss_aura.spread = 40.0
	boss_aura.gravity = Vector3(0, 1.2, 0)
	boss_aura.initial_velocity_min = 0.3
	boss_aura.initial_velocity_max = 1.2
	boss_aura.scale_amount_min = 0.25
	boss_aura.scale_amount_max = 0.8
	boss_aura.color = Color(1.0, 0.38, 0.08, 0.9)
	var aura_mesh := QuadMesh.new()
	aura_mesh.size = Vector2(0.10, 0.10)
	var aura_mat := StandardMaterial3D.new()
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	aura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	aura_mat.albedo_color = Color(1.0, 0.4, 0.1, 0.75)
	aura_mat.albedo_texture = _make_soft_texture(24)
	aura_mat.disable_receive_shadows = true
	aura_mesh.material = aura_mat
	boss_aura.mesh = aura_mesh
	boss_aura.position = Vector3(0, 1.0, 0)
	boss_aura.emitting = false
	boss_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(boss_aura)


func _add_thug_scarf() -> void:
	var scarf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.54, 0.12, 0.30)
	scarf.mesh = bm
	scarf.material_override = _mat(Color(0.62, 0.16, 0.10), 0.9)
	scarf.position = Vector3(0, 1.35, 0.03)
	model_root.add_child(scarf)
	var knot := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(0.12, 0.26, 0.06)
	knot.mesh = km
	knot.material_override = _mat(Color(0.52, 0.12, 0.08), 0.9)
	knot.position = Vector3(-0.18, 1.22, 0.20)
	knot.rotation.z = 0.25
	model_root.add_child(knot)


func _add_brute_plates() -> void:
	var plate_mat := _mat(Color(0.22, 0.24, 0.30), 0.45, 0.6)
	for sx in [-1.0, 1.0]:
		var plate := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.30, 0.18, 0.42)
		plate.mesh = bm
		plate.material_override = plate_mat
		plate.position = Vector3(sx * 0.44, 1.42, 0.0)
		plate.rotation.z = sx * -0.25
		model_root.add_child(plate)
	var crest := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.08, 0.22, 0.36)
	crest.mesh = cm
	crest.material_override = plate_mat
	crest.position = Vector3(0, 1.88, 0.0)
	model_root.add_child(crest)


func _add_oil_bottle(root: Node3D) -> void:
	var bottle := Node3D.new()
	bottle.position = Vector3(0.36, 1.02, 0.12)
	root.add_child(bottle)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.07
	cm.height = 0.18
	cm.radial_segments = 8
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.20, 0.14, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.35, 0.8, 0.28)
	mat.emission_energy_multiplier = 0.35
	body.material_override = mat
	bottle.add_child(body)
	var cork := MeshInstance3D.new()
	var cm2 := CylinderMesh.new()
	cm2.top_radius = 0.035
	cm2.bottom_radius = 0.04
	cm2.height = 0.06
	cm2.radial_segments = 8
	cork.mesh = cm2
	cork.material_override = _mat(Color(0.42, 0.30, 0.18), 0.9)
	cork.position.y = 0.12
	bottle.add_child(cork)


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.disable_receive_shadows = true
	return m


func _make_soft_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _build_shadow() -> void:
	blob = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.46
	cm.bottom_radius = 0.54
	cm.height = 0.012
	cm.radial_segments = 16
	blob.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0, 0, 0, 0.40)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	blob.material_override = mat
	blob.position.y = 0.018
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)


func _build_telegraph() -> void:
	telegraph_mat = StandardMaterial3D.new()
	telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	telegraph_mat.albedo_color = Color(1.0, 0.28, 0.10, 0.40)
	telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	telegraph_mat.disable_receive_shadows = true
	telegraph_disc = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.0
	cm.bottom_radius = 1.0
	cm.height = 0.012
	cm.radial_segments = 28
	telegraph_disc.mesh = cm
	telegraph_disc.material_override = telegraph_mat
	telegraph_disc.position.y = 0.035
	telegraph_disc.visible = false
	telegraph_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(telegraph_disc)

	line_mat = telegraph_mat.duplicate()
	telegraph_line = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.012, 1.0)
	telegraph_line.mesh = bm
	telegraph_line.material_override = line_mat
	telegraph_line.position.y = 0.036
	telegraph_line.visible = false
	telegraph_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(telegraph_line)


# ── main AI loop ────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if is_dead or frozen:
		return
	if not active or player == null or not is_instance_valid(player) or player.is_dead():
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if attack_cooldown > 0.0:
		attack_cooldown -= delta
	if poise_timer > 0.0:
		poise_timer -= delta
		if poise_timer <= 0.0:
			poise = poise_max
	if attack_check > 0.0:
		attack_check -= delta

	match state:
		"idle":
			alert_t -= delta
			_face_player(delta, 6.0)
			velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 16.0 * delta)
			play_anim("Idle", 0.2)
			if alert_t <= 0.0 or _flat_dist() < aggro_range * 0.55:
				state = "approach"
		"approach", "circle":
			_process_chase(delta)
		"attack":
			_process_attack(delta)
		"recover":
			stagger_t -= delta
			velocity.x = move_toward(velocity.x, 0, 14.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 14.0 * delta)
			if stagger_t <= 0.0:
				state = "approach"
		"flinch":
			flinch_t -= delta
			velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 16.0 * delta)
			if flinch_t <= 0.0:
				state = "approach"
		"stagger":
			stagger_t -= delta
			velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
			if stagger_t <= 0.0:
				state = "approach"
		"knockdown":
			_process_knockdown(delta)
		"getup":
			getup_t += delta
			velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
			if getup_t >= 0.80:
				state = "approach"
		"dead":
			velocity.x = 0.0
			velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5


func _process_chase(delta: float) -> void:
	var dist := _flat_dist()
	var to_player := _flat_to_player()
	_face_player(delta, 8.0)
	var wants_attack := dist <= attack_range and attack_cooldown <= 0.0
	if wants_attack and not token_held and attack_check <= 0.0:
		attack_check = 0.30
		if main != null and main.request_attack_token(self):
			token_held = true
	# 油贩：保持 4–6m 投油瓶；打手：远距冲撞
	if not token_held and attack_cooldown <= 0.0 and attack_check <= 0.0:
		var wants_ranged := (archetype == "oil" and dist > 3.4 and dist < 8.5) \
			or (archetype == "brute" and dist > 3.4 and dist < 7.5)
		if wants_ranged:
			attack_check = 0.30
			if main != null and main.request_attack_token(self):
				token_held = true
	if token_held and attack_cooldown <= 0.0:
		if archetype == "oil" and dist > 3.4 and dist < 8.5:
			_start_attack("throw")
			return
		if archetype == "brute" and dist > 3.4 and dist < 7.5:
			_start_attack("charge")
			return
	if token_held and dist <= attack_range * 0.98 and attack_cooldown <= 0.0:
		_start_attack(_choose_attack(dist))
		return
	if token_held and dist > attack_range * 0.98:
		velocity.x = to_player.x * move_speed
		velocity.z = to_player.z * move_speed
		play_anim("Running_A", 0.15, 1.1)
		return
	if dist > 4.9:
		state = "approach"
		velocity.x = to_player.x * move_speed
		velocity.z = to_player.z * move_speed
		play_anim("Running_A", 0.15, 1.05)
	elif state == "approach" and dist <= 4.4:
		state = "circle"
		circle_t = 0.9
	if state == "circle":
		circle_t -= delta
		var side := 1.0 if slot % 2 == 0 else -1.0
		var tangent := Vector3(-to_player.z, 0, to_player.x) * side
		var radial := -to_player * clampf((dist - 3.4) * 0.7, -0.6, 0.8)
		var move := (tangent * 0.55 + radial).normalized()
		velocity.x = move.x * move_speed * 0.55
		velocity.z = move.z * move_speed * 0.55
		play_anim("Walking_A", 0.18, 1.0)
		if circle_t <= 0.0:
			state = "approach"
	else:
		velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 12.0 * delta)


func _choose_attack(dist: float) -> String:
	if archetype == "thug":
		return "combo"
	if archetype == "oil":
		if dist > 3.4 and attack_cooldown <= 0.0 and _rng.randf() < 0.72:
			return "throw"
		return "stab"
	if archetype == "brute":
		attack_cycle += 1
		if dist > 2.8 and attack_cycle % 3 == 0:
			return "charge"
		return "slam"
	# boss
	attack_cycle += 1
	if phase == 2 and attack_cycle % 4 == 0:
		return "charge"
	match attack_cycle % 3:
		0:
			return "triple"
		1:
			return "sweep"
		_:
			return "oil"


func _start_attack(kind: String) -> void:
	state = "attack"
	attack_kind = kind
	attack_t = 0.0
	_charge_t = 0.0
	_charge_hit_done = false
	_plan = _attack_plan(kind)
	_hits_fired.clear()
	for i in (_plan.get("hits", []) as Array).size():
		_hits_fired.append(false)
	telegraph_disc.visible = false
	telegraph_line.visible = false
	charge_dir = _flat_to_player()
	var tdata: Dictionary = _plan.get("telegraph", {})
	if tdata.get("kind", "") == "circle":
		telegraph_disc.visible = true
		telegraph_disc.scale = Vector3(0.25, 1, 0.25)
		if tdata.get("at_player", false):
			telegraph_disc.global_position = player.global_position + Vector3(0, 0.035, 0)
		else:
			telegraph_disc.global_position = global_position + Vector3(0, 0.035, 0)
	elif tdata.get("kind", "") == "line":
		telegraph_line.visible = true
		var length: float = float(tdata.get("length", 4.0))
		telegraph_line.scale = Vector3(1.35, 1.0, length)
		telegraph_line.global_position = global_position + charge_dir * (length * 0.5) + Vector3(0, 0.036, 0)
		telegraph_line.rotation.y = atan2(charge_dir.x, charge_dir.z)
		telegraph_line.scale.x = 1.2
	play_anim(_plan["clip"], 0.10, float(_plan["anim_speed"]))
	attack_telegraphed.emit()
	if archetype == "boss":
		if phase == 2:
			attack_cooldown = 0.85
		else:
			attack_cooldown = 1.35
	else:
		attack_cooldown = 1.4 + _rng.randf_range(0.0, 0.7)


func _attack_plan(kind: String) -> Dictionary:
	match kind:
		"combo":
			return {"clip": "1H_Melee_Attack_Chop", "anim_speed": 1.55, "total": 1.30,
				"telegraph": {"kind": "circle", "radius": 2.1},
				"hits": [
					{"t": 0.42, "damage": 8, "radius": 2.1, "arc": 0.35, "knockdown": false},
					{"t": 0.84, "damage": 8, "radius": 2.1, "arc": 0.35, "knockdown": false,
						"clip": "1H_Melee_Attack_Slice_Horizontal"},
				]}
		"stab":
			return {"clip": "1H_Melee_Attack_Stab", "anim_speed": 1.8, "total": 0.95,
				"telegraph": {"kind": "circle", "radius": 2.0},
				"hits": [{"t": 0.40, "damage": 6, "radius": 2.0, "arc": 0.5, "knockdown": false}]}
		"throw":
			return {"clip": "Throw", "anim_speed": 1.25, "total": 1.30,
				"telegraph": {"kind": "circle", "radius": 1.7, "at_player": true},
				"hits": [{"t": 0.55, "damage": 0, "radius": 0.1, "arc": -2.0,
					"knockdown": false, "special": "oil_throw"}]}
		"slam":
			return {"clip": "2H_Melee_Attack_Chop", "anim_speed": 1.15, "total": 1.62,
				"telegraph": {"kind": "circle", "radius": 1.95},
				"hits": [{"t": 0.72, "damage": 15, "radius": 1.95, "arc": -2.0, "knockdown": true}]}
		"charge":
			return {"clip": "Running_A", "anim_speed": 1.2, "total": 1.55,
				"telegraph": {"kind": "line", "length": 6.0 if archetype == "boss" else 4.2},
				"dash": {"start": 0.62, "end": 1.05, "speed": 10.0 if archetype == "boss" else 8.5},
				"hits": [{"t": 0.66, "damage": 18 if archetype == "boss" else 12,
					"radius": 1.45, "arc": -2.0, "knockdown": archetype == "boss"}]}
		"triple":
			var speedup := 1.0 if phase == 1 else 0.82
			return {"clip": "2H_Melee_Attack_Slice", "anim_speed": 1.55, "total": 2.15 * speedup,
				"telegraph": {"kind": "circle", "radius": 2.55},
				"hits": [
					{"t": 0.52 * speedup, "damage": 10, "radius": 2.55, "arc": 0.30, "knockdown": false},
					{"t": 0.94 * speedup, "damage": 10, "radius": 2.55, "arc": 0.30, "knockdown": false},
					{"t": 1.42 * speedup, "damage": 14, "radius": 2.65, "arc": 0.30, "knockdown": true},
				]}
		"sweep":
			return {"clip": "2H_Melee_Attack_Spin", "anim_speed": 1.9, "total": 1.55,
				"telegraph": {"kind": "circle", "radius": 3.0},
				"hits": [{"t": 0.60, "damage": 12, "radius": 3.0, "arc": -2.0, "knockdown": false}]}
		"oil":
			return {"clip": "Throw", "anim_speed": 1.3, "total": 1.55,
				"telegraph": {"kind": "circle", "radius": 1.8, "at_player": true},
				"hits": [{"t": 0.62, "damage": 0, "radius": 0.1, "arc": -2.0,
					"knockdown": false, "special": "boss_oil"}]}
	return {"clip": "Idle", "anim_speed": 1.0, "total": 1.0, "hits": []}


func _process_attack(delta: float) -> void:
	attack_t += delta
	var total: float = float(_plan.get("total", 1.0))
	# 预警收缩
	if telegraph_disc.visible:
		var base_radius: float = float((_plan.get("telegraph", {}) as Dictionary).get("radius", 2.0))
		var pulse := 0.92 + 0.08 * sin(attack_t * 26.0)
		telegraph_disc.scale = Vector3(base_radius * pulse, 1, base_radius * pulse)
		telegraph_mat.albedo_color.a = 0.30 + 0.22 * sin(attack_t * 18.0)
	if telegraph_line.visible:
		line_mat.albedo_color.a = 0.24 + 0.20 * sin(attack_t * 20.0)
	# 冲撞位移
	var dash: Dictionary = _plan.get("dash", {})
	if not dash.is_empty():
		var ds: float = float(dash["start"])
		var de: float = float(dash["end"])
		if attack_t >= ds and attack_t <= de:
			velocity.x = charge_dir.x * float(dash["speed"])
			velocity.z = charge_dir.z * float(dash["speed"])
			if archetype == "boss" and not _charge_hit_done and attack_t > ds + 0.1:
				main.spawn_oil_fire(global_position + charge_dir * 1.4, 0.55)
		else:
			velocity.x = move_toward(velocity.x, 0, 16.0 * delta)
			velocity.z = move_toward(velocity.z, 0, 16.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 18.0 * delta)
	var hits: Array = _plan.get("hits", [])
	for i in hits.size():
		if _hits_fired[i]:
			continue
		var h: Dictionary = hits[i]
		if attack_t < float(h["t"]):
			continue
		_hits_fired[i] = true
		if h.has("clip") and anim != null:
			play_anim(String(h["clip"]), 0.08, float(_plan["anim_speed"]))
		if h.has("special"):
			if String(h["special"]) == "oil_throw":
				_throw_oil(player.global_position)
			elif String(h["special"]) == "boss_oil":
				main.spawn_oil_fire(player.global_position, 2.5)
				main.spawn_oil_fire(player.global_position + Vector3(1.2, 0, 0.6), 2.5)
		else:
			_melee_hit(float(h["radius"]), int(h["damage"]), bool(h["knockdown"]), float(h["arc"]))
		if h.has("special") and attack_kind == "charge":
			_charge_hit_done = true
	if attack_t >= total:
		_end_attack()


func _end_attack() -> void:
	state = "recover"
	stagger_t = 0.34 if archetype != "boss" else 0.30
	telegraph_disc.visible = false
	telegraph_line.visible = false
	if token_held and main != null:
		main.release_attack_token(self)
		token_held = false
	play_anim("Idle", 0.2)


func _melee_hit(radius: float, dmg: int, knockdown: bool, arc: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > radius + 0.30:
		return
	if arc > -1.5 and dist > 0.01:
		var forward := Vector3(sin(rotation.y), 0, cos(rotation.y))
		if forward.dot(to_player.normalized()) < arc:
			return
	player.take_damage(dmg, global_position, knockdown)
	if main != null:
		main.spawn_enemy_impact(player.global_position + Vector3(0, 1.1, 0), knockdown)


func _throw_oil(target: Vector3) -> void:
	if main == null:
		return
	var bottle := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.11
	cm.height = 0.26
	cm.radial_segments = 8
	bottle.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.22, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.85, 0.30)
	mat.emission_energy_multiplier = 0.45
	bottle.material_override = mat
	bottle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(bottle)
	var start := global_position + Vector3(0, 1.4, 0)
	var end := target + Vector3(0, 0.12, 0)
	var apex := (start + end) * 0.5 + Vector3(0, 2.4, 0)
	bottle.global_position = start
	var tw := create_tween()
	tw.tween_method(_bottle_step.bind(bottle, start, apex, end), 0.0, 1.0, 0.8)
	tw.tween_callback(_finish_bottle.bind(bottle, end))


func _bottle_step(t: float, bottle: MeshInstance3D, start: Vector3, apex: Vector3, end: Vector3) -> void:
	if is_instance_valid(bottle):
		bottle.global_position = _bezier(start, apex, end, t)
		bottle.rotation.x += 0.35


func _finish_bottle(bottle: MeshInstance3D, end: Vector3) -> void:
	if is_instance_valid(bottle):
		bottle.queue_free()
	if main != null:
		main.spawn_oil_fire(end, 2.5)


func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	var it := 1.0 - t
	return a * it * it + b * 2.0 * it * t + c * t * t


func _face_player(delta: float, rate: float) -> void:
	var to_player := _flat_to_player()
	if to_player.length_squared() > 0.001:
		var yaw := atan2(to_player.x, to_player.z)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-rate * delta))


func _flat_to_player() -> Vector3:
	if player == null or not is_instance_valid(player):
		return Vector3.ZERO
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		d = d.normalized()
	return d


func _flat_dist() -> float:
	if player == null or not is_instance_valid(player):
		return 999.0
	var d: Vector3 = player.global_position - global_position
	d.y = 0.0
	return d.length()


# ── damage ──────────────────────────────────────────────────────────────────

func take_hit(amount: int, dir: Vector3, knockback: float, heavy: bool,
		knockdown: bool, source := "player") -> void:
	if is_dead:
		return
	hp = maxi(0, hp - amount)
	hits_taken += 1
	hp_changed.emit(hp, max_hp)
	_flash()
	if hp <= 0:
		_die()
		return
	var away := Vector3(dir.x, 0, dir.z)
	if away.length_squared() < 0.01:
		away = Vector3(sin(rotation.y), 0, cos(rotation.y))
	away = away.normalized()
	velocity = away * (2.2 + knockback * 3.2)
	if archetype == "boss":
		if source == "lampbreak" and lamp_break_used_phase != phase:
			lamp_break_used_phase = phase
			_begin_knockdown(1.2, "lampbreak")
		elif knockdown:
			# 3 连后的 0.8s 破绽
			_release_token()
			state = "stagger"
			stagger_t = 0.8
			play_anim("Hit_B", 0.08, 1.4)
		else:
			poise -= 1
			if poise <= 0:
				poise = poise_max
				poise_timer = 1.6
				state = "flinch"
				flinch_t = 0.16
				play_anim("Hit_A", 0.06, 1.7)
		_check_phase()
		return
	if knockdown:
		_begin_knockdown(1.0, "heavy")
	elif heavy:
		_release_token()
		state = "stagger"
		stagger_t = 0.5
		play_anim("Hit_B", 0.08, 1.5)
	else:
		poise -= 1
		if poise <= 0:
			poise = poise_max
			poise_timer = 1.4
			_release_token()
			state = "flinch"
			flinch_t = 0.2
			play_anim("Hit_A", 0.06, 1.8)
	_check_phase()


func _check_phase() -> void:
	if archetype != "boss" or phase != 1:
		return
	if hp <= max_hp / 2:
		phase = 2
		phase_changed.emit(phase)
		if boss_aura != null:
			boss_aura.emitting = true
		if main != null:
			main.on_boss_phase2(self)


func _begin_knockdown(duration: float, _source: String) -> void:
	_release_token()
	state = "knockdown"
	knockdown_phase = "down"
	knockdown_t = 0.0
	stagger_t = duration
	play_anim("Lie_Down", 0.08, 4.0)


func _process_knockdown(delta: float) -> void:
	knockdown_t += delta
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	if knockdown_phase == "down" and knockdown_t >= 0.85:
		knockdown_phase = "lie"
		knockdown_t = 0.0
		play_anim("Lie_Idle", 0.12, 1.0)
	elif knockdown_phase == "lie" and knockdown_t >= 0.22:
		knockdown_phase = "getup"
		getup_t = 0.0
		state = "getup"
		play_anim("Lie_StandUp", 0.12, 3.0)


func _release_token() -> void:
	if token_held and main != null:
		main.release_attack_token(self)
		token_held = false
	telegraph_disc.visible = false
	telegraph_line.visible = false


func _flash() -> void:
	if _flash_mat == null:
		return
	_flash_timer = 0.09
	for mi in mesh_instances:
		if is_instance_valid(mi):
			mi.material_overlay = _flash_mat


func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			for mi in mesh_instances:
				if is_instance_valid(mi):
					mi.material_overlay = null


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	active = false
	hp = 0
	_release_token()
	state = "dead"
	telegraph_disc.visible = false
	telegraph_line.visible = false
	hp_changed.emit(0, max_hp)
	play_anim("Death_A", 0.08, 1.0)
	if archetype == "boss":
		play_anim("Lie_Down", 0.1, 3.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(blob, "scale", Vector3(1.6, 1.0, 1.6), 1.0)
	if archetype != "boss":
		tw.tween_property(self, "position:y", -0.12, 1.2).set_delay(0.5)
		tw.tween_interval(2.2)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(self):
				visible = false)
	died.emit(self)




func play_anim(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	anim.play(clip, blend, speed)
	anim.speed_scale = 1.0


func freeze_anim(v: bool) -> void:
	if anim != null:
		anim.speed_scale = 0.0 if v else 1.0


func reset_enemy(spawn: Vector3) -> void:
	is_dead = false
	active = false
	hp = max_hp
	state = "idle"
	alert_t = 0.6
	attack_t = 0.0
	attack_cooldown = 0.6
	poise = poise_max
	poise_timer = 0.0
	phase = 1
	knockdown_t = 0.0
	knockdown_phase = ""
	getup_t = 0.0
	stagger_t = 0.0
	flinch_t = 0.0
	token_held = false
	hits_taken = 0
	lamp_break_used_phase = 0
	global_position = spawn
	visible = true
	rotation = Vector3.ZERO
	if blob != null:
		blob.scale = Vector3.ONE
	play_anim("Idle", 0.1)
	hp_changed.emit(hp, max_hp)


func display_hp_ratio() -> float:
	return float(hp) / float(maxi(1, max_hp))


func is_attacking() -> bool:
	return state == "attack"
