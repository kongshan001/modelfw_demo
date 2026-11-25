class_name DreamEnemy
extends CharacterBody3D

# 梦魇：普通巡游者 / 钟摆守梦人。
# 可读起手（预警圈+动作）→ 命中帧 → 硬直；弹反造成长硬直并开放反击窗口。
# 同一时刻只有持有攻击令牌的梦魇可以起手。

signal died

const NORMAL_MODEL := "res://assets/models/kaykit/Rogue_Hooded.glb"
const BOSS_MODEL := "res://assets/models/kaykit/Mage.glb"

const ATTACK_DATA := {
	"sweep": {
		"windup": 0.68, "damage": 14.0, "range": 2.7, "parryable": true,
		"aoe": false, "anim": "1H_Melee_Attack_Slice_Horizontal", "label": "梦刃横扫",
	},
	"slam": {
		"windup": 0.88, "damage": 22.0, "range": 3.35, "parryable": true,
		"aoe": false, "anim": "2H_Melee_Attack_Chop", "label": "钟摆重砸",
	},
	"boss_sweep": {
		"windup": 0.72, "damage": 17.0, "range": 3.55, "parryable": true,
		"aoe": false, "anim": "2H_Melee_Attack_Spin", "label": "逆钟回旋",
	},
	"toll": {
		"windup": 1.18, "damage": 26.0, "range": 5.2, "parryable": false,
		"aoe": true, "anim": "Spellcast_Raise", "label": "丧钟领域",
	},
}

enum State { IDLE, CHASE, WINDUP, RECOVER, STAGGER, DEAD }

var world: Node = null
var is_boss := false
var display_name := "失忆巡游者"
var max_hp := 60.0
var hp := 60.0
var max_poise := 34.0
var poise := 0.0
var speed := 2.25
var aggro_range := 8.5
var attack_cooldown := 1.1
var home := Vector3.ZERO
var state: State = State.IDLE
var state_time := 0.0
var aggro := false
var token_held := false
var current_attack := "sweep"
var windup_left := 0.0
var windup_duration := 0.0
var recover_left := 0.0
var stagger_left := 0.0
var riposte_window := 0.0
var attack_index := 0
var phase_two := false
var hit_flash_left := 0.0
var damage_dealt := 0.0
var parried_count := 0

var model_root: Node3D
var model: Node3D
var anim: AnimationPlayer
var _current_anim := ""
var _uses_model := false
var _procedural: Node3D
var _telegraph_root: Node3D
var _telegraph_ring: MeshInstance3D
var _telegraph_disc: MeshInstance3D
var _telegraph_mat: StandardMaterial3D
var _telegraph_disc_mat: StandardMaterial3D
var _flash_mat: StandardMaterial3D
var _flash_meshes: Array = []
var _halo: Node3D
var _halo_hands: Node3D
var _blade: Node3D
var _body_shape: CollisionShape3D
var _model_scale := 1.0
var _attack_sequence: Array[String] = ["sweep"]
var _gravity := 24.0
var _hit_flash_clear := 0.0
var _ghost_spawn := 0.0


func setup(boss: bool) -> void:
	is_boss = boss
	if boss:
		display_name = "钟摆守梦人"
		max_hp = 160.0
		hp = max_hp
		max_poise = 86.0
		speed = 1.9
		aggro_range = 11.0
		attack_cooldown = 1.25
		_model_scale = 1.28
		_attack_sequence = ["slam", "toll", "boss_sweep", "slam", "boss_sweep"]
	else:
		display_name = "失忆巡游者"
		max_hp = 60.0
		hp = max_hp
		max_poise = 34.0
		speed = 2.35
		aggro_range = 8.0
		attack_cooldown = 1.05
		_model_scale = 0.98
		_attack_sequence = ["sweep"]


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.25
	_build_collision()
	_build_model()
	_build_blob_shadow()
	_build_telegraph()


func _build_collision() -> void:
	_body_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.46 if is_boss else 0.34
	capsule.height = 2.2 if is_boss else 1.68
	_body_shape.shape = capsule
	_body_shape.position.y = capsule.height * 0.5
	add_child(_body_shape)


func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	model_root.rotation.y = PI
	model_root.scale = Vector3.ONE * _model_scale
	add_child(model_root)
	if not _try_model():
		_build_procedural()


func _try_model() -> bool:
	if OS.has_environment("DREAM_FORCE_PROCEDURAL"):
		return false
	var path := BOSS_MODEL if is_boss else NORMAL_MODEL
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return false
	anim = instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null or not anim.has_animation("Idle"):
		instance.free()
		anim = null
		return false
	model = instance
	model_root.add_child(model)
	_tune_model()
	if is_boss:
		_build_boss_regalia()
		_build_boss_weapon()
	else:
		_build_wanderer_blade()
	anim.play("Idle", 0.0)
	_current_anim = "Idle"
	_uses_model = true
	return true


func _tune_model() -> void:
	var hidden := ["1H_Crossbow", "2H_Crossbow", "Throwable", "Knife_Offhand", "Rogue_Cape", "Mage_Cape"]
	if is_boss:
		hidden += ["2H_Staff", "1H_Wand", "Spellbook", "Spellbook_open", "Mage_Hat"]
	else:
		hidden += ["Knife"]
	for node in _all_nodes(model):
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if hidden.has(String(mesh_instance.name)):
				mesh_instance.visible = false
				continue
			if mesh_instance.mesh == null:
				continue
			_flash_meshes.append(mesh_instance)
			for index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(index) as StandardMaterial3D
				if source == null:
					continue
				var tinted := source.duplicate() as StandardMaterial3D
				if is_boss:
					tinted.albedo_color = tinted.albedo_color * Color(0.58, 0.44, 0.72, 1.0)
					tinted.emission_enabled = true
					tinted.emission = Color(0.16, 0.04, 0.24)
					tinted.emission_energy_multiplier = 0.55
				else:
					tinted.albedo_color = tinted.albedo_color * Color(0.7, 0.42, 0.5, 1.0)
				mesh_instance.set_surface_override_material(index, tinted)
	_flash_mat = StandardMaterial3D.new()
	_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_mat.albedo_color = Color(1.0, 0.72, 0.58, 0.34)
	_flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for loco in ["Idle", "Running_A"]:
		if anim.has_animation(loco):
			anim.get_animation(loco).loop_mode = Animation.LOOP_LINEAR


func _build_wanderer_blade() -> void:
	var hand := model.find_child("handslot_r", true, false) as Node3D
	if hand == null:
		return
	_blade = Node3D.new()
	_blade.name = "DreamBlade"
	hand.add_child(_blade)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.10, 0.06, 0.18)
	dark.metallic = 0.5
	dark.roughness = 0.35
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.78, 0.3, 0.55)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.18, 0.5)
	glow.emission_energy_multiplier = 1.4
	var blade_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.075, 1.05, 0.035)
	blade_mesh.mesh = box
	blade_mesh.material_override = dark
	blade_mesh.position = Vector3(0.0, 0.52, 0.0)
	blade_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(blade_mesh)
	var edge := MeshInstance3D.new()
	var edge_box := BoxMesh.new()
	edge_box.size = Vector3(0.018, 1.02, 0.05)
	edge.mesh = edge_box
	edge.material_override = glow
	edge.position = Vector3(0.045, 0.52, 0.0)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(edge)
	var guard := MeshInstance3D.new()
	var guard_box := BoxMesh.new()
	guard_box.size = Vector3(0.3, 0.06, 0.09)
	guard.mesh = guard_box
	guard.material_override = glow
	guard.position = Vector3(0.0, 0.02, 0.0)
	guard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(guard)


func _build_boss_regalia() -> void:
	# 原创钟摆冠冕：背后悬浮钟面 + 分针，随阶段加速。
	_halo = Node3D.new()
	_halo.name = "PendulumHalo"
	_halo.position = Vector3(0.0, 2.08, 0.55)
	_halo.scale = Vector3.ONE * 0.9
	model_root.add_child(_halo)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.19, 0.12, 0.17)
	bronze.metallic = 0.55
	bronze.roughness = 0.3
	bronze.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rose := StandardMaterial3D.new()
	rose.albedo_color = Color(0.8, 0.35, 0.58)
	rose.emission_enabled = true
	rose.emission = Color(0.82, 0.18, 0.48)
	rose.emission_energy_multiplier = 1.7
	rose.cull_mode = BaseMaterial3D.CULL_DISABLED
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 0.92
	disc_mesh.bottom_radius = 0.92
	disc_mesh.height = 0.1
	disc_mesh.radial_segments = 32
	disc.mesh = disc_mesh
	disc.material_override = bronze
	disc.rotation.x = PI * 0.5
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.add_child(disc)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.9
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 10
	ring.mesh = ring_mesh
	ring.material_override = rose
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo.add_child(ring)
	_halo_hands = Node3D.new()
	_halo_hands.name = "ClockHands"
	_halo_hands.position = Vector3.ZERO
	_halo.add_child(_halo_hands)
	var hand_long := MeshInstance3D.new()
	var hand_box := BoxMesh.new()
	hand_box.size = Vector3(0.05, 0.74, 0.04)
	hand_long.mesh = hand_box
	hand_long.material_override = rose
	hand_long.position = Vector3(0.0, 0.28, 0.08)
	hand_long.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo_hands.add_child(hand_long)
	var hand_short := MeshInstance3D.new()
	var short_box := BoxMesh.new()
	short_box.size = Vector3(0.06, 0.44, 0.05)
	hand_short.mesh = short_box
	hand_short.material_override = rose
	hand_short.position = Vector3(0.2, 0.12, 0.09)
	hand_short.rotation.z = -PI * 0.5
	hand_short.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo_hands.add_child(hand_short)
	# 挂在背后的钟摆，用细链和坠锤强化剪影。
	var chain := MeshInstance3D.new()
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.018
	chain_mesh.bottom_radius = 0.018
	chain_mesh.height = 1.2
	chain.mesh = chain_mesh
	chain.material_override = bronze
	chain.position = Vector3(0.0, -1.1, 0.55)
	chain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(chain)
	var bob := MeshInstance3D.new()
	var bob_mesh := SphereMesh.new()
	bob_mesh.radius = 0.26
	bob_mesh.height = 0.52
	bob.mesh = bob_mesh
	bob.material_override = rose
	bob.position = Vector3(0.0, -1.78, 0.55)
	bob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model_root.add_child(bob)


func _build_boss_weapon() -> void:
	# 钟摆权杖：长柄 + 时钟环 + 分针刃。跟随手部动画，可读出挥击方向。
	var hand := model.find_child("handslot_r", true, false) as Node3D
	if hand == null:
		return
	_blade = Node3D.new()
	_blade.name = "PendulumStaff"
	hand.add_child(_blade)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.34, 0.21, 0.18)
	bronze.metallic = 0.6
	bronze.roughness = 0.32
	var rose := StandardMaterial3D.new()
	rose.albedo_color = Color(0.85, 0.36, 0.58)
	rose.emission_enabled = true
	rose.emission = Color(0.9, 0.18, 0.5)
	rose.emission_energy_multiplier = 1.4
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.03
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = 2.0
	shaft.mesh = shaft_mesh
	shaft.material_override = bronze
	shaft.position = Vector3(0.0, 1.0, 0.0)
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(shaft)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.34
	ring_mesh.outer_radius = 0.4
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = rose
	ring.position = Vector3(0.0, 2.05, 0.0)
	ring.rotation.x = PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(ring)
	var hand_blade := MeshInstance3D.new()
	var hand_box := BoxMesh.new()
	hand_box.size = Vector3(0.1, 1.15, 0.06)
	hand_blade.mesh = hand_box
	hand_blade.material_override = rose
	hand_blade.position = Vector3(0.0, 2.25, 0.0)
	hand_blade.rotation.z = -0.34
	hand_blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(hand_blade)
	var counter := MeshInstance3D.new()
	var counter_box := BoxMesh.new()
	counter_box.size = Vector3(0.06, 0.72, 0.06)
	counter.mesh = counter_box
	counter.material_override = rose
	counter.position = Vector3(-0.16, 1.98, 0.0)
	counter.rotation.z = 0.9
	counter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blade.add_child(counter)


func _build_procedural() -> void:
	# 缺图回退：梦魇剪影 + 攻击预警仍然是完整的。
	_uses_model = false
	_procedural = Node3D.new()
	_procedural.name = "ProceduralEnemy"
	model_root.add_child(_procedural)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.20, 0.12, 0.28) if is_boss else Color(0.22, 0.10, 0.16)
	cloth.roughness = 0.9
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.4, 0.64)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.2, 0.55)
	var height := 1.9 if is_boss else 1.55
	var body := MeshInstance3D.new()
	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.18
	body_mesh.bottom_radius = 0.55 if is_boss else 0.4
	body_mesh.height = height
	body_mesh.radial_segments = 8
	body.mesh = body_mesh
	body.material_override = cloth
	body.position.y = height * 0.5
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_procedural.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.3 if is_boss else 0.24
	head_mesh.height = head_mesh.radius * 2.0
	head.mesh = head_mesh
	head.material_override = cloth
	head.position.y = height + 0.12
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_procedural.add_child(head)
	for i in 2:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.045
		eye_mesh.height = 0.09
		eye.mesh = eye_mesh
		eye.material_override = glow
		eye.position = Vector3(-0.09 + 0.18 * i, height + 0.14, -0.24)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_procedural.add_child(eye)
	var weapon := MeshInstance3D.new()
	var weapon_mesh := BoxMesh.new()
	weapon_mesh.size = Vector3(0.08, 1.1 if not is_boss else 1.8, 0.06)
	weapon.mesh = weapon_mesh
	weapon.material_override = glow
	weapon.position = Vector3(0.65, height * 0.72, 0.0)
	weapon.rotation.z = 0.35
	weapon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_procedural.add_child(weapon)
	anim = null


func _build_blob_shadow() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.6
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	var texture := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture
	mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	var shadow_size := 2.6 if is_boss else 1.35
	quad.size = Vector2(shadow_size, shadow_size)
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = quad
	shadow.material_override = mat
	shadow.rotation.x = -PI * 0.5
	shadow.position.y = 0.02
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _build_telegraph() -> void:
	_telegraph_root = Node3D.new()
	_telegraph_root.name = "Telegraph"
	_telegraph_root.position.y = 0.035
	_telegraph_root.visible = false
	add_child(_telegraph_root)
	_telegraph_mat = StandardMaterial3D.new()
	_telegraph_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_telegraph_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_telegraph_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_telegraph_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.24)
	_telegraph_mat.emission_enabled = true
	_telegraph_mat.emission = Color(1.0, 0.4, 0.14)
	_telegraph_mat.emission_energy_multiplier = 0.9
	_telegraph_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_telegraph_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 12
	_telegraph_ring.mesh = torus
	_telegraph_ring.material_override = _telegraph_mat
	_telegraph_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph_root.add_child(_telegraph_ring)
	_telegraph_disc_mat = _telegraph_mat.duplicate() as StandardMaterial3D
	_telegraph_disc_mat.albedo_color = Color(1.0, 0.28, 0.22, 0.14)
	_telegraph_disc_mat.emission_enabled = true
	_telegraph_disc_mat.emission = Color(1.0, 0.22, 0.16)
	_telegraph_disc_mat.emission_energy_multiplier = 0.5
	_telegraph_disc = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 1.0
	disc_mesh.bottom_radius = 1.0
	disc_mesh.height = 0.012
	disc_mesh.radial_segments = 40
	_telegraph_disc.mesh = disc_mesh
	_telegraph_disc.material_override = _telegraph_disc_mat
	_telegraph_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_telegraph_root.add_child(_telegraph_disc)
	var light := OmniLight3D.new()
	light.name = "TelegraphLight"
	light.light_color = Color(1.0, 0.38, 0.2)
	light.light_energy = 0.0
	light.omni_range = 3.5
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.8, 0.0)
	_telegraph_root.add_child(light)


func _all_nodes(node: Node) -> Array:
	var result: Array = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result


# ------------------------------------------------------------------ AI 主循环

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_update_hit_flash(delta)
	if _halo_hands != null:
		_halo_hands.rotation.z += delta * (1.4 if phase_two else 0.55)
	if _halo != null:
		_halo.rotation.y += delta * 0.18
	if world == null:
		return
	var player: Node3D = world.player
	if player == null or not is_instance_valid(player):
		return
	if not world.combat_enabled():
		_apply_gravity(delta)
		move_and_slide()
		_update_idle_anim()
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var player_dead: bool = player.state == DreamPlayer.State.DEAD if "state" in player else false
	if player_dead:
		_release_token()
		state = State.IDLE
		_telegraph_root.visible = false
		_apply_gravity(delta)
		move_and_slide()
		return

	match state:
		State.IDLE:
			_update_idle(delta, distance, player)
		State.CHASE:
			_update_chase(delta, distance, to_player, player)
		State.WINDUP:
			_update_windup(delta, player)
		State.RECOVER:
			_update_recover(delta)
		State.STAGGER:
			_update_stagger(delta, player)
		State.DEAD:
			pass
	state_time += delta


func _update_idle(delta: float, distance: float, player: Node3D) -> void:
	if distance <= aggro_range:
		aggro = true
		state = State.CHASE
		if is_boss and world != null:
			world.boss_engaged = true
		return
	if is_boss and aggro and distance <= aggro_range * 1.4:
		state = State.CHASE
		return
	if is_boss and not aggro:
		return
	# 缓慢回到巡游点，保持“梦魇在场”的呼吸感。
	if global_position.distance_to(home) > 0.4:
		var dir := home - global_position
		dir.y = 0.0
		dir = dir.normalized()
		velocity.x = dir.x * speed * 0.42
		velocity.z = dir.z * speed * 0.42
		_face_direction(dir, delta, 5.0)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	_update_move_anim(velocity.length() > 0.1)


func _update_chase(delta: float, distance: float, to_player: Vector3, player: Node3D) -> void:
	_face_towards(player.global_position, delta, 8.0)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if is_boss:
		aggro = true
		world.boss_engaged = true
	if distance <= _current_attack_range() and attack_cooldown <= 0.0:
		if world.request_attack_token(self):
			_begin_attack(_choose_attack())
			return
	if distance > 1.0:
		var dir := to_player.normalized()
		var stop := _current_attack_range() * 0.82
		if distance > stop:
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
		else:
			# 近身绕步，避免贴脸抖动。
			var orbit := Vector3(-dir.z, 0.0, dir.x)
			velocity.x = orbit.x * speed * 0.42
			velocity.z = orbit.z * speed * 0.42
	_apply_gravity(delta)
	move_and_slide()
	_update_move_anim(velocity.length() > 0.1)
	if distance > aggro_range * 1.9 and not is_boss:
		aggro = false
		state = State.IDLE


func _update_windup(delta: float, player: Node3D) -> void:
	_face_towards(player.global_position, delta, 4.0)
	windup_left -= delta
	var data: Dictionary = ATTACK_DATA[current_attack]
	var progress := 1.0 - clampf(windup_left / maxf(windup_duration, 0.001), 0.0, 1.0)
	var radius := float(data["range"]) if not bool(data["aoe"]) else float(data["range"])
	_telegraph_root.scale = Vector3.ONE * maxf(0.35, radius * (0.55 + 0.45 * progress))
	var col := Color(1.0, 0.45, 0.18, 0.55) if bool(data["parryable"]) else Color(0.65, 0.45, 1.0, 0.62)
	_telegraph_mat.albedo_color = Color(col.r, col.g, col.b, 0.22 + progress * 0.5)
	_telegraph_mat.emission = Color(col.r, col.g, col.b)
	_telegraph_disc_mat.albedo_color = Color(col.r, col.g, col.b, 0.04 + progress * 0.16)
	_telegraph_disc_mat.emission = Color(col.r, col.g, col.b)
	if windup_left <= 0.0:
		_telegraph_root.visible = false
		state = State.RECOVER
		recover_left = 0.72 if not is_boss else 0.82
		state_time = 0.0
		world.resolve_enemy_attack(self, data, token_held)


func _update_recover(delta: float) -> void:
	recover_left -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	_update_move_anim(false)
	if recover_left <= 0.0:
		_release_token()
		attack_cooldown = 0.75 if (is_boss and phase_two) else (1.05 if is_boss else 1.1)
		state = State.CHASE


func _update_stagger(delta: float, player: Node3D) -> void:
	stagger_left -= delta
	riposte_window = maxf(0.0, riposte_window - delta)
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	if stagger_left <= 0.0:
		riposte_window = 0.0
		state = State.CHASE
		attack_cooldown = 0.35


func _begin_attack(attack_key: String) -> void:
	token_held = true
	current_attack = attack_key
	var data: Dictionary = ATTACK_DATA[attack_key]
	windup_duration = float(data["windup"])
	if phase_two:
		windup_duration *= 0.84
	windup_left = windup_duration
	state = State.WINDUP
	state_time = 0.0
	_play_anim(String(data["anim"]), 1.45 if not is_boss else 1.3, 0.08)
	var radius := float(data["range"])
	_telegraph_root.scale = Vector3.ONE * radius * 0.55
	_telegraph_root.visible = true
	if world != null:
		world.telegraph_started(self)


func _choose_attack() -> String:
	if not is_boss:
		return "sweep"
	var key := _attack_sequence[attack_index % _attack_sequence.size()]
	attack_index += 1
	return key


func _current_attack_range() -> float:
	if state == State.WINDUP:
		return float(ATTACK_DATA[current_attack]["range"])
	if is_boss:
		return 3.1
	return 2.4


func _release_token() -> void:
	if token_held and world != null:
		world.release_attack_token(self)
	token_held = false


# ------------------------------------------------------------------ 受击/弹反/死亡


func on_parried() -> void:
	if state == State.DEAD:
		return
	parried_count += 1
	_release_token()
	state = State.STAGGER
	state_time = 0.0
	stagger_left = 1.65
	riposte_window = 1.65
	poise = 0.0
	_telegraph_root.visible = false
	_play_anim("Hit_A", 1.45, 0.04)
	if world != null:
		world.fx.ring(global_position, Color(1.0, 0.8, 0.34), 1.8, 0.5)
		world.fx.sparks(global_position + Vector3.UP, Color(1.0, 0.7, 0.3), 24)


func take_damage(amount: float, riposte := false, source_pos := Vector3.ZERO) -> float:
	if state == State.DEAD:
		return 0.0
	var critical := riposte_window > 0.0
	var final := amount * (2.2 if critical else 1.0)
	hp = maxf(0.0, hp - final)
	hit_flash_left = 0.09
	_flash_hit_meshes(true)
	if world != null:
		world.fx.damage_number(global_position, int(round(final)), critical)
		world.fx.sparks(global_position + Vector3.UP, Color(1.0, 0.72, 0.45), 16 if not is_boss else 20)
		world.camera_shake(0.06 if not critical else 0.1)
		world.last_damage_dealt = final
	if hp <= 0.0:
		_die()
		return final
	poise += final * 1.05
	if poise >= max_poise:
		poise = 0.0
		_break_poise()
	elif state == State.WINDUP and critical:
		# 反击窗口内打中正在起手的梦魇：直接打断本次起手。
		state = State.STAGGER
		stagger_left = maxf(stagger_left, 0.8)
		riposte_window = maxf(riposte_window, 0.8)
		_telegraph_root.visible = false
		_release_token()
	if is_boss and not phase_two and hp <= max_hp * 0.5:
		_enter_phase_two()
	return final


func _break_poise() -> void:
	if state == State.DEAD:
		return
	_release_token()
	state = State.STAGGER
	state_time = 0.0
	stagger_left = 0.95
	riposte_window = 0.55
	_telegraph_root.visible = false
	_play_anim("Hit_A", 1.6, 0.05)
	if world != null:
		world.toast("%s · 破韧" % display_name, Color(0.95, 0.78, 0.5), 0.8)
		world.fx.ring(global_position, Color(0.9, 0.65, 0.3), 1.4, 0.4)
		world.fx.sparks(global_position + Vector3.UP, Color(1.0, 0.75, 0.4), 20)


func _enter_phase_two() -> void:
	phase_two = true
	speed *= 1.18
	attack_cooldown = 0.8
	if world != null:
		world.toast("钟摆守梦人 · 敲响第二声", Color(0.95, 0.55, 0.9), 1.6)
		world.fx.ring(global_position, Color(0.85, 0.3, 0.9), 3.2, 0.8)
		world.camera_shake(0.18)


func _die() -> void:
	state = State.DEAD
	state_time = 0.0
	_flash_hit_meshes(false)
	_release_token()
	_telegraph_root.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	_play_anim("Death_A", 1.0, 0.06)
	if _halo != null:
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_halo, "scale", Vector3.ZERO, 0.8)
		tween.tween_property(_halo, "rotation:y", _halo.rotation.y + 1.2, 0.8)
	died.emit()
	if world != null:
		world.on_enemy_died(self)


func reset_enemy() -> void:
	state = State.IDLE
	state_time = 0.0
	hp = max_hp
	poise = 0.0
	aggro = false
	phase_two = false
	riposte_window = 0.0
	stagger_left = 0.0
	windup_left = 0.0
	recover_left = 0.0
	attack_cooldown = 1.0
	attack_index = 0
	_release_token()
	_telegraph_root.visible = false
	collision_layer = 4
	collision_mask = 1
	visible = true
	global_position = home
	velocity = Vector3.ZERO
	attacks_animation("Idle")
	if _halo != null:
		_halo.scale = Vector3.ONE
		_halo.visible = true
	if is_boss:
		world.boss_engaged = false


func attacks_animation(anim_name: String) -> void:
	if anim != null and anim.has_animation(anim_name):
		anim.play(anim_name, 0.0)
		_current_anim = anim_name


func is_alive() -> bool:
	return state != State.DEAD


func body_radius() -> float:
	if _body_shape != null and _body_shape.shape is CapsuleShape3D:
		return (_body_shape.shape as CapsuleShape3D).radius
	return 0.55 if is_boss else 0.4


func is_staggered() -> bool:
	return state == State.STAGGER


func can_be_riposted() -> bool:
	return riposte_window > 0.0 and state != State.DEAD


func telegraph_seconds_left() -> float:
	if state != State.WINDUP:
		return 0.0
	return maxf(0.0, windup_left)


func current_attack_parryable() -> bool:
	if state != State.WINDUP:
		return false
	return bool(ATTACK_DATA[current_attack]["parryable"])


func debug_skip_windup() -> void:
	if state == State.WINDUP:
		windup_left = 0.015


func force_attack(attack_key: String) -> void:
	if state == State.DEAD:
		return
	if not ATTACK_DATA.has(attack_key):
		return
	if not token_held:
		if not world.request_attack_token(self):
			return
	aggro = true
	_begin_attack(attack_key)


func _update_hit_flash(delta: float) -> void:
	if hit_flash_left > 0.0:
		hit_flash_left -= delta
		if hit_flash_left <= 0.0:
			_flash_hit_meshes(false)


func _flash_hit_meshes(enabled: bool) -> void:
	for node in _flash_meshes:
		if is_instance_valid(node):
			node.material_overlay = _flash_mat if enabled else null
	if enabled and _blade != null:
		for child in _blade.get_children():
			if child is MeshInstance3D:
				child.material_overlay = _flash_mat
	elif not enabled and _blade != null:
		for child in _blade.get_children():
			if child is MeshInstance3D:
				child.material_overlay = null


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.2


func _face_towards(pos: Vector3, delta: float, speed_value: float) -> void:
	var direction := pos - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, clampf(delta * speed_value, 0.0, 1.0))


func _face_direction(direction: Vector3, delta: float, speed_value: float) -> void:
	var target_yaw := atan2(-direction.x, -direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, clampf(delta * speed_value, 0.0, 1.0))


func _play_anim(anim_name: String, speed_value := 1.0, blend := 0.1) -> void:
	if anim == null:
		return
	if not anim.has_animation(anim_name):
		return
	if _current_anim == anim_name and anim.is_playing():
		anim.speed_scale = speed_value
		return
	anim.play(anim_name, blend, speed_value)
	_current_anim = anim_name


func _update_idle_anim() -> void:
	if anim != null and state != State.WINDUP and state != State.STAGGER and _current_anim != "Idle":
		_play_anim("Idle", 1.0, 0.2)


func _update_move_anim(moving: bool) -> void:
	if state == State.WINDUP or state == State.STAGGER or state == State.DEAD:
		return
	var desired := "Running_A" if moving else "Idle"
	if _current_anim != desired:
		_play_anim(desired, 1.0 if not is_boss else 0.82, 0.18)
