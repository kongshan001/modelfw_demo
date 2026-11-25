class_name DreamPlayer
extends CharacterBody3D

# 缄梦者：轻击/重击、0.18s 弹反窗、i-frames 闪避、共享忆能回梦。
# 所有时间窗与资源消耗都是公开常量，便于 tools/smoke_dream_parry.gd 直接验证。

signal died
signal parry_succeeded(target)
signal health_changed

const MODEL_PATH := "res://assets/models/kaykit/Knight.glb"
const MODEL_SCALE := 0.96
const MODEL_YAW := PI # KayKit 正面 +Z；玩家 forward 为 -Z

const MAX_HP := 100.0
const MAX_STAMINA := 100.0
const MAX_ENERGY := 100.0
const START_ENERGY := 55.0

const MOVE_SPEED := 4.8
const LOCK_MOVE_SPEED := 3.9
const GRAVITY := 24.0

const PARRY_WINDOW := 0.18
const PARRY_TOTAL := 0.45
const PARRY_STAMINA_COST := 8.0
const PARRY_COOLDOWN := 0.16
const PARRY_ENERGY_GAIN := 20.0

const DODGE_IFRAMES := 0.26
const DODGE_TOTAL := 0.42
const DODGE_STAMINA_COST := 22.0
const DODGE_SPEED := 9.6

const LIGHT_COST := 14.0
const LIGHT_DAMAGE := 12.0
const LIGHT_RANGE := 2.75
const LIGHT_IMPACT := 0.16
const LIGHT_TOTAL := 0.48
const HEAVY_COST := 26.0
const HEAVY_DAMAGE := 26.0
const HEAVY_RANGE := 3.15
const HEAVY_IMPACT := 0.34
const HEAVY_TOTAL := 0.82
const HEAVY_HOLD := 0.32
const RIPOSTE_MULT := 2.2

const HEAL_COST := 35.0
const HEAL_AMOUNT := 35.0
const HEAL_APPLY := 0.38
const HEAL_TOTAL := 0.80

enum State { FREE, ATTACK, PARRY, DODGE, HIT, HEAL, DEAD }

var world: Node = null
var state: State = State.FREE
var hp := MAX_HP
var stamina := MAX_STAMINA
var energy := START_ENERGY
var controls_enabled := true
var lock_target: Node3D = null
var parry_elapsed := 0.0
var dodge_elapsed := 0.0
var hit_invuln := 0.0
var parry_cooldown := 0.0
var parry_success_count := 0
var dodge_success_count := 0
var damage_taken := 0.0
var state_time := 0.0
var charge_time := 0.0
var attack_held := false
var attack_heavy := false
var riposte_ready := false

var _stamina_delay := 0.0
var _attack_hit_done := false
var _heal_done := false
var _dodge_dir := Vector3.BACK
var _knockback := Vector3.ZERO
var _hit_was_lethal := false

var model_root: Node3D
var model: Node3D
var anim: AnimationPlayer
var _umbrella: Node3D
var _canopy: Node3D
var _canopy_mat: StandardMaterial3D
var _blob_shadow: MeshInstance3D
var _current_anim := ""
var _anim_speed := 1.0
var _step_time := 0.0
var _uses_model := false
var _procedural_fallback: Node3D
var _procedural_umbrella: Node3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.72
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.86, 0.0)
	add_child(shape)
	_build_model()
	_build_blob_shadow()


# ------------------------------------------------------------------ 构建外观

func _build_model() -> void:
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	model_root.rotation.y = MODEL_YAW
	model_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(model_root)
	var built := _try_kaykit_model()
	if not built:
		_build_procedural_fallback()


func _try_kaykit_model() -> bool:
	if OS.has_environment("DREAM_FORCE_PROCEDURAL"):
		return false
	if not ResourceLoader.exists(MODEL_PATH):
		return false
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return false
	anim = instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand := instance.find_child("handslot_r", true, false) as Node3D
	if anim == null or hand == null or not anim.has_animation("Idle"):
		instance.free()
		anim = null
		return false
	model = instance
	model_root.add_child(model)
	_degrease_model()
	_umbrella = _build_umbrella()
	hand.add_child(_umbrella)
	_umbrella.position = Vector3(0.0, 0.0, 0.03)
	_umbrella.rotation = Vector3(0.0, 0.0, 0.0)
	for loco in ["Idle", "Running_A", "Walking_A"]:
		if anim.has_animation(loco):
			anim.get_animation(loco).loop_mode = Animation.LOOP_LINEAR
	anim.play("Idle", 0.0)
	_current_anim = "Idle"
	_uses_model = true
	return true


func _degrease_model() -> void:
	var hidden := [
		"1H_Sword", "2H_Sword", "1H_Sword_Offhand", "Badge_Shield", "Rectangle_Shield",
		"Round_Shield", "Spike_Shield", "Knight_Cape",
	]
	for node in _all_nodes(model):
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if hidden.has(String(mesh_instance.name)):
				mesh_instance.visible = false
				continue
			if mesh_instance.mesh == null:
				continue
			for index in mesh_instance.mesh.get_surface_count():
				var source := mesh_instance.get_active_material(index) as StandardMaterial3D
				if source == null:
					continue
				var tinted := source.duplicate() as StandardMaterial3D
				tinted.albedo_color = tinted.albedo_color * Color(1.06, 1.02, 0.98, 1.0)
				if tinted.emission_enabled:
					tinted.emission = tinted.emission * 0.5 + Color(0.05, 0.12, 0.14)
				mesh_instance.set_surface_override_material(index, tinted)


func _build_procedural_fallback() -> void:
	# 缺图回退：保留完整可玩的低模骑士+雨伞，不因资源缺失阻断玩法。
	_uses_model = false
	_procedural_fallback = Node3D.new()
	_procedural_fallback.name = "ProceduralFallback"
	model_root.add_child(_procedural_fallback)
	var dark := _flat_material(Color(0.12, 0.16, 0.28))
	var cloak := _flat_material(Color(0.20, 0.30, 0.44))
	_add_box(_procedural_fallback, "Body", Vector3(0, 0.95, 0), Vector3(0.56, 0.8, 0.38), dark)
	_add_box(_procedural_fallback, "Cloak", Vector3(0, 0.72, 0.12), Vector3(0.68, 0.62, 0.26), cloak)
	_add_sphere(_procedural_fallback, "Head", Vector3(0, 1.55, 0), 0.24, _flat_material(Color(0.86, 0.81, 0.72)))
	_add_box(_procedural_fallback, "Visor", Vector3(0, 1.56, -0.20), Vector3(0.34, 0.10, 0.08), _flat_material(Color(0.08, 0.1, 0.15)))
	_add_box(_procedural_fallback, "LegL", Vector3(-0.14, 0.32, 0), Vector3(0.18, 0.64, 0.2), dark)
	_add_box(_procedural_fallback, "LegR", Vector3(0.14, 0.32, 0), Vector3(0.18, 0.64, 0.2), dark)
	_add_box(_procedural_fallback, "ArmL", Vector3(-0.38, 1.02, 0), Vector3(0.16, 0.62, 0.18), dark)
	_procedural_umbrella = Node3D.new()
	_procedural_umbrella.position = Vector3(0.44, 0.95, 0)
	_procedural_fallback.add_child(_procedural_umbrella)
	var umb := _build_umbrella()
	_procedural_umbrella.add_child(umb)
	_procedural_umbrella.rotation.z = -0.22
	anim = null


func _build_umbrella() -> Node3D:
	var root := Node3D.new()
	root.name = "Umbrella"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.13, 0.09, 0.08)
	wood.roughness = 0.65
	wood.metallic = 0.15
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.63, 0.32)
	brass.metallic = 0.65
	brass.roughness = 0.3
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.022
	shaft.bottom_radius = 0.026
	shaft.height = 1.86
	var shaft_mesh := MeshInstance3D.new()
	shaft_mesh.mesh = shaft
	shaft_mesh.material_override = brass
	shaft_mesh.position = Vector3(0, 0.99, 0)
	shaft_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shaft_mesh)
	var handle := TorusMesh.new()
	handle.inner_radius = 0.055
	handle.outer_radius = 0.085
	handle.rings = 12
	handle.ring_segments = 16
	var handle_mesh := MeshInstance3D.new()
	handle_mesh.mesh = handle
	handle_mesh.material_override = brass
	handle_mesh.rotation.x = PI * 0.5
	handle_mesh.position = Vector3(0.055, 0.06, 0.0)
	handle_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(handle_mesh)
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.03
	tip.height = 0.22
	var tip_mesh := MeshInstance3D.new()
	tip_mesh.mesh = tip
	tip_mesh.material_override = brass
	tip_mesh.position = Vector3(0.0, 2.02, 0.0)
	tip_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(tip_mesh)

	_canopy = Node3D.new()
	_canopy.name = "Canopy"
	_canopy.position = Vector3(0.0, 1.82, 0.0)
	root.add_child(_canopy)
	_canopy_mat = StandardMaterial3D.new()
	_canopy_mat.albedo_color = Color(0.88, 0.78, 0.56, 0.99)
	_canopy_mat.roughness = 0.48
	_canopy_mat.emission_enabled = true
	_canopy_mat.emission = Color(0.24, 0.4, 0.33)
	_canopy_mat.emission_energy_multiplier = 0.35
	_canopy_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.02
	canopy_mesh.bottom_radius = 0.82
	canopy_mesh.height = 0.32
	canopy_mesh.radial_segments = 12
	canopy_mesh.rings = 2
	var canopy_instance := MeshInstance3D.new()
	canopy_instance.mesh = canopy_mesh
	canopy_instance.material_override = _canopy_mat
	canopy_instance.position = Vector3(0.0, 0.02, 0.0)
	canopy_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_canopy.add_child(canopy_instance)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.78
	rim.outer_radius = 0.84
	rim.rings = 24
	rim.ring_segments = 12
	var rim_mesh := MeshInstance3D.new()
	rim_mesh.mesh = rim
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.98, 0.79, 0.38)
	rim_mat.metallic = 0.55
	rim_mat.emission_enabled = true
	rim_mat.emission = Color(0.75, 0.54, 0.25)
	rim_mat.emission_energy_multiplier = 0.7
	rim_mesh.material_override = rim_mat
	rim_mesh.position = Vector3(0.0, -0.09, 0.0)
	rim_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_canopy.add_child(rim_mesh)
	for i in 8:
		var rib := MeshInstance3D.new()
		var rib_mesh := BoxMesh.new()
		rib_mesh.size = Vector3(0.02, 0.02, 0.66)
		rib.mesh = rib_mesh
		var rib_mat := StandardMaterial3D.new()
		rib_mat.albedo_color = Color(0.78, 0.62, 0.37)
		rib_mat.metallic = 0.4
		rib.material_override = rib_mat
		rib.position = Vector3(cos(float(i) * TAU / 8.0) * 0.37, -0.1, sin(float(i) * TAU / 8.0) * 0.37)
		rib.rotation.y = -float(i) * TAU / 8.0
		rib.rotation.x = 0.14
		rib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_canopy.add_child(rib)
	_canopy.scale = Vector3(0.62, 0.92, 0.62)
	var canopy_gem := MeshInstance3D.new()
	var gem_mesh := SphereMesh.new()
	gem_mesh.radius = 0.055
	gem_mesh.height = 0.11
	canopy_gem.mesh = gem_mesh
	var gem_mat := StandardMaterial3D.new()
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem_mat.albedo_color = Color(0.55, 1.0, 0.9)
	gem_mat.emission_enabled = true
	gem_mat.emission = Color(0.5, 1.0, 0.9)
	gem_mat.emission_energy_multiplier = 1.4
	canopy_gem.material_override = gem_mat
	canopy_gem.position = Vector3(0.0, 2.06, 0.0)
	canopy_gem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(canopy_gem)
	return root


func _build_blob_shadow() -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(float(x) - 31.5, float(y) - 31.5).length() / 31.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * 0.62
			image.set_pixel(x, y, Color(0.0, 0.0, 0.0, a))
	var texture := ImageTexture.create_from_image(image)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = texture
	mat.albedo_color = Color(0.0, 0.0, 0.0, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(1.7, 1.7)
	_blob_shadow = MeshInstance3D.new()
	_blob_shadow.name = "BlobShadow"
	_blob_shadow.mesh = quad
	_blob_shadow.material_override = mat
	_blob_shadow.rotation.x = -PI * 0.5
	_blob_shadow.position.y = 0.015
	_blob_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob_shadow)


func _flat_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat


func _add_box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _add_sphere(parent: Node3D, node_name: String, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh_instance.mesh = sphere
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
	return mesh_instance


func _all_nodes(node: Node) -> Array:
	var result: Array = []
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		result.append(current)
		for child in current.get_children():
			stack.append(child)
	return result


# ------------------------------------------------------------------ 主循环

func _physics_process(delta: float) -> void:
	hit_invuln = maxf(0.0, hit_invuln - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	_regen(delta)

	match state:
		State.FREE:
			_process_free(delta)
		State.ATTACK:
			_advance_attack(delta)
		State.PARRY:
			_advance_parry(delta)
		State.DODGE:
			_advance_dodge(delta)
		State.HIT:
			_advance_hit(delta)
		State.HEAL:
			_advance_heal(delta)
		State.DEAD:
			velocity.x = 0.0
			velocity.z = 0.0
			_apply_gravity(delta)
			move_and_slide()

	_animate_canopy(delta)
	_pose_umbrella(delta)
	_update_lock_target()


func _process_free(delta: float) -> void:
	if not controls_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		_update_locomotion_anim(false)
		return
	if attack_held:
		charge_time += delta
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var move_dir := _camera_relative(input)
	var moving := move_dir.length_squared() > 0.001
	if lock_target != null and is_instance_valid(lock_target):
		_face_towards(lock_target.global_position, delta, 12.0)
	elif moving:
		_face_direction(move_dir, delta, 14.0)
	var speed := LOCK_MOVE_SPEED if lock_target != null else MOVE_SPEED
	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	_apply_gravity(delta)
	move_and_slide()
	_update_locomotion_anim(moving, speed)
	_step_time += delta
	if moving and _step_time > 0.34:
		_step_time = 0.0
		if world != null and world.has_method("spawn_step_dust"):
			world.spawn_step_dust(global_position)


func _advance_attack(delta: float) -> void:
	state_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	var impact := HEAVY_IMPACT if attack_heavy else LIGHT_IMPACT
	if not _attack_hit_done and state_time >= impact:
		_attack_hit_done = true
		_resolve_attack()
	var total := HEAVY_TOTAL if attack_heavy else LIGHT_TOTAL
	if state_time >= total:
		state = State.FREE
		_attack_hit_done = false
		_update_locomotion_anim(false)


func _advance_parry(delta: float) -> void:
	state_time += delta
	parry_elapsed += delta
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	if state_time >= PARRY_TOTAL:
		state = State.FREE
		parry_elapsed = 0.0
		parry_cooldown = PARRY_COOLDOWN
		_update_locomotion_anim(false)


func _advance_dodge(delta: float) -> void:
	state_time += delta
	dodge_elapsed += delta
	var t := clampf(state_time / DODGE_TOTAL, 0.0, 1.0)
	var speed := lerpf(DODGE_SPEED, 3.4, t * t)
	velocity.x = _dodge_dir.x * speed + _knockback.x
	velocity.z = _dodge_dir.z * speed + _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, clampf(delta * 8.0, 0.0, 1.0))
	_apply_gravity(delta)
	move_and_slide()
	if world != null and world.has_method("spawn_dodge_trail") and state_time < DODGE_IFRAMES:
		world.spawn_dodge_trail(global_position)
	if state_time >= DODGE_TOTAL:
		state = State.FREE
		dodge_elapsed = 0.0
		_knockback = Vector3.ZERO
		_update_locomotion_anim(false)


func _advance_hit(delta: float) -> void:
	state_time += delta
	velocity.x = _knockback.x
	velocity.z = _knockback.z
	_knockback = _knockback.lerp(Vector3.ZERO, clampf(delta * 7.0, 0.0, 1.0))
	_apply_gravity(delta)
	move_and_slide()
	if state_time >= 0.36:
		state = State.FREE
		_knockback = Vector3.ZERO
		_update_locomotion_anim(false)


func _advance_heal(delta: float) -> void:
	state_time += delta
	velocity.x = 0.0
	velocity.z = 0.0
	_apply_gravity(delta)
	move_and_slide()
	if not _heal_done and state_time >= HEAL_APPLY:
		_heal_done = true
		hp = minf(MAX_HP, hp + HEAL_AMOUNT)
		health_changed.emit()
		if world != null:
			world.toast("回梦 +%d" % int(HEAL_AMOUNT), Color(0.55, 1.0, 0.82))
			world.fx.ring(global_position, Color(0.45, 1.0, 0.78), 0.9, 0.55)
			world.fx.sparks(global_position, Color(0.55, 1.0, 0.82), 12)
	if state_time >= HEAL_TOTAL:
		state = State.FREE
		_update_locomotion_anim(false)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.2


func _regenerate(delta: float) -> void:
	# 忆能：缓慢自然回复；命中与完美弹反回能更快。
	if state != State.DEAD:
		energy = minf(MAX_ENERGY, energy + 1.35 * delta)


func _regen(delta: float) -> void:
	_regenerate(delta)
	var action_state := state in [State.ATTACK, State.PARRY, State.DODGE, State.HIT, State.HEAL]
	if action_state or attack_held:
		_stamina_delay = 0.55
	else:
		_stamina_delay = maxf(0.0, _stamina_delay - delta)
		if _stamina_delay <= 0.0:
			stamina = minf(MAX_STAMINA, stamina + 23.0 * delta)


# ------------------------------------------------------------------ 公开战斗接口

func press_attack() -> void:
	if not controls_enabled or state == State.DEAD or state != State.FREE:
		return
	if stamina < 6.0:
		world.toast("气力不足", Color(0.95, 0.7, 0.55))
		return
	attack_held = true
	charge_time = 0.0


func release_attack() -> void:
	if not attack_held:
		return
	attack_held = false
	if not controls_enabled or state != State.FREE:
		return
	if charge_time >= HEAVY_HOLD and stamina >= HEAVY_COST:
		_start_attack(true)
	elif stamina >= LIGHT_COST:
		_start_attack(false)
	else:
		world.toast("气力不足", Color(0.95, 0.7, 0.55))


func _start_attack(heavy: bool) -> void:
	state = State.ATTACK
	state_time = 0.0
	attack_heavy = heavy
	_attack_hit_done = false
	stamina = maxf(0.0, stamina - (HEAVY_COST if heavy else LIGHT_COST))
	_stamina_delay = 0.55
	if lock_target != null and is_instance_valid(lock_target):
		_face_towards(lock_target.global_position, 1.0, 100.0)
	if heavy:
		_play_anim("2H_Melee_Attack_Chop", 2.0, 0.1)
		if world != null:
			world.toast("重击蓄势", Color(1.0, 0.82, 0.48), 0.5)
	else:
		_play_anim("1H_Melee_Attack_Slice_Horizontal", 2.2, 0.08)


func _resolve_attack() -> void:
	var heavy := attack_heavy
	var damage := HEAVY_DAMAGE if heavy else LIGHT_DAMAGE
	var reach := HEAVY_RANGE if heavy else LIGHT_RANGE
	var forward := get_facing()
	var yaw := global_rotation.y
	if world != null:
		world.fx.slash(global_position + forward * 0.75, yaw, Color(1.0, 0.78, 0.4) if heavy else Color(0.62, 0.95, 0.9), heavy)
		if world.has_method("player_attack"):
			world.player_attack(self, damage, reach, forward, heavy)


func start_parry() -> void:
	if not controls_enabled or state == State.DEAD:
		return
	if state != State.FREE or parry_cooldown > 0.0:
		return
	if stamina < 4.0:
		world.toast("气力不足", Color(0.95, 0.7, 0.55))
		return
	state = State.PARRY
	state_time = 0.0
	parry_elapsed = 0.0
	attack_held = false
	stamina = maxf(0.0, stamina - PARRY_STAMINA_COST)
	_stamina_delay = 0.55
	if lock_target != null and is_instance_valid(lock_target):
		_face_towards(lock_target.global_position, 1.0, 100.0)
	_play_anim("Block", 2.4, 0.06)


func on_parry_success(target: Node3D) -> void:
	parry_success_count += 1
	energy = minf(MAX_ENERGY, energy + PARRY_ENERGY_GAIN)
	stamina = minf(MAX_STAMINA, stamina + 10.0)
	state = State.FREE
	parry_elapsed = 0.0
	parry_cooldown = 0.12
	hit_invuln = maxf(hit_invuln, 0.18)
	parry_succeeded.emit(target)
	if world != null:
		world.toast("完美弹反 · 反击时机", Color(1.0, 0.84, 0.4), 1.2)
		world.fx.ring(global_position, Color(1.0, 0.8, 0.34), 1.35, 0.5)
		world.fx.ring(global_position, Color(0.6, 1.0, 0.92), 0.75, 0.35)
		world.fx.sparks(global_position + get_facing() * 0.9, Color(1.0, 0.88, 0.52), 30)
		world.fx.burst_light(global_position, Color(1.0, 0.8, 0.4), 4.2, 6.0)
		world.camera_shake(0.13)
		world.parry_lesson_shown = true


func start_dodge() -> void:
	if not controls_enabled or state == State.DEAD:
		return
	if state != State.FREE:
		return
	if stamina < DODGE_STAMINA_COST:
		world.toast("气力不足", Color(0.95, 0.7, 0.55))
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := _camera_relative(input)
	if direction.length_squared() < 0.01:
		direction = -get_facing()
		if lock_target != null and is_instance_valid(lock_target):
			direction = (global_position - lock_target.global_position)
			direction.y = 0.0
			direction = direction.normalized()
	_dodge_dir = direction.normalized()
	state = State.DODGE
	state_time = 0.0
	dodge_elapsed = 0.0
	attack_held = false
	stamina = maxf(0.0, stamina - DODGE_STAMINA_COST)
	_stamina_delay = 0.55
	_knockback = Vector3.ZERO
	_face_direction(_dodge_dir, 1.0, 100.0)
	var local := global_transform.basis.inverse() * _dodge_dir
	var dodge_anim := "Dodge_Backward"
	if local.z < -0.4:
		dodge_anim = "Dodge_Forward"
	elif local.x < -0.4:
		dodge_anim = "Dodge_Left"
	elif local.x > 0.4:
		dodge_anim = "Dodge_Right"
	_play_anim(dodge_anim, 1.08, 0.04)
	if world != null:
		world.fx.ring(global_position, Color(0.5, 0.8, 1.0), 0.5, 0.24)


func try_heal() -> void:
	if not controls_enabled or state == State.DEAD:
		return
	if state != State.FREE:
		return
	if hp >= MAX_HP:
		world.toast("梦血已满", Color(0.8, 0.85, 0.95))
		return
	if energy < HEAL_COST:
		world.toast("忆能不足 · 弹反可回能", Color(0.95, 0.7, 0.55))
		return
	energy -= HEAL_COST
	state = State.HEAL
	state_time = 0.0
	_heal_done = false
	attack_held = false
	_play_anim("Use_Item", 2.0, 0.1)
	if world != null:
		world.fx.ring(global_position, Color(0.55, 1.0, 0.78), 0.7, 0.7)


func consume_energy(amount: float) -> bool:
	if energy < amount:
		return false
	energy -= amount
	return true


func add_energy(amount: float) -> void:
	energy = minf(MAX_ENERGY, energy + amount)


func take_damage(amount: float, source_pos: Vector3) -> bool:
	if state == State.DEAD or hit_invuln > 0.0:
		return false
	hp = maxf(0.0, hp - amount)
	damage_taken += amount
	health_changed.emit()
	_stamina_delay = 0.8
	hit_invuln = 0.65
	attack_held = false
	var away := global_position - source_pos
	away.y = 0.0
	_knockback = away.normalized() * 4.2
	if hp <= 0.0:
		_die()
		return true
	state = State.HIT
	state_time = 0.0
	_heal_done = true
	_play_anim("Hit_A", 1.9, 0.05)
	if world != null:
		world.toast("-%d 梦血" % int(amount), Color(1.0, 0.55, 0.55), 0.7)
		world.fx.sparks(global_position, Color(0.9, 0.35, 0.4), 14)
		world.camera_shake(0.2)
	return true


func _die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	state_time = 0.0
	attack_held = false
	collision_layer = 0
	collision_mask = 1
	_play_anim("Death_A", 1.0, 0.08)
	lock_target = null
	died.emit()


func is_invulnerable() -> bool:
	return hit_invuln > 0.0 or (state == State.DODGE and dodge_elapsed <= DODGE_IFRAMES)


func is_dodging_with_iframes() -> bool:
	return state == State.DODGE and dodge_elapsed <= DODGE_IFRAMES


func is_parry_active() -> bool:
	return state == State.PARRY and parry_elapsed <= PARRY_WINDOW


func parry_faces(pos: Vector3) -> bool:
	var to := pos - global_position
	to.y = 0.0
	if to.length_squared() < 0.001:
		return true
	return get_facing().dot(to.normalized()) >= 0.0


func on_dodge_success() -> void:
	dodge_success_count += 1


func respawn_at(pos: Vector3, yaw := 0.0) -> void:
	state = State.FREE
	state_time = 0.0
	parry_elapsed = 0.0
	dodge_elapsed = 0.0
	hit_invuln = 1.0
	parry_cooldown = 0.0
	hp = MAX_HP
	stamina = MAX_STAMINA
	energy = START_ENERGY
	attack_held = false
	lock_target = null
	_knockback = Vector3.ZERO
	velocity = Vector3.ZERO
	collision_layer = 2
	collision_mask = 1
	global_position = pos
	global_rotation = Vector3(0.0, yaw, 0.0)
	visible = true
	if anim != null:
		anim.play("Idle", 0.0)
		_current_anim = "Idle"
	health_changed.emit()
	if world != null:
		world.fx.ring(pos, Color(0.6, 0.95, 1.0), 1.2, 0.7)


func set_controls_enabled(enabled: bool) -> void:
	controls_enabled = enabled
	if not enabled:
		attack_held = false


func heal_full() -> void:
	hp = MAX_HP
	stamina = MAX_STAMINA
	health_changed.emit()


func face_target(target: Node3D) -> void:
	lock_target = target
	if target != null and is_instance_valid(target):
		_face_towards(target.global_position, 1.0, 100.0)


func get_facing() -> Vector3:
	return -global_transform.basis.z


func state_label() -> String:
	match state:
		State.FREE: return "FREE"
		State.ATTACK: return "ATTACK"
		State.PARRY: return "PARRY"
		State.DODGE: return "DODGE"
		State.HIT: return "HIT"
		State.HEAL: return "HEAL"
		State.DEAD: return "DEAD"
	return "?"


# ------------------------------------------------------------------ 移动/朝向/动画

func _camera_relative(input: Vector2) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var forward := Vector3(0.0, 0.0, -1.0)
	var right := Vector3(1.0, 0.0, 0.0)
	if camera != null:
		forward = -camera.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			forward = forward.normalized()
		right = camera.global_transform.basis.x
		right.y = 0.0
		if right.length_squared() > 0.001:
			right = right.normalized()
	var direction := right * input.x - forward * input.y
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction


func _face_direction(direction: Vector3, delta: float, speed: float) -> void:
	if direction.length_squared() < 0.001:
		return
	var target_yaw := atan2(-direction.x, -direction.z)
	global_rotation.y = lerp_angle(global_rotation.y, target_yaw, clampf(delta * speed, 0.0, 1.0))


func _face_towards(pos: Vector3, delta: float, speed: float) -> void:
	var direction := pos - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	_face_direction(direction.normalized(), delta, speed)


func _update_lock_target() -> void:
	if lock_target == null:
		return
	if not is_instance_valid(lock_target):
		lock_target = null
		return
	if lock_target.has_method("is_alive") and not lock_target.is_alive():
		lock_target = null


func _update_locomotion_anim(moving: bool, speed := 0.0) -> void:
	if anim == null:
		return
	if state != State.FREE:
		return
	var desired := "Running_A" if moving else "Idle"
	if _current_anim != desired:
		var speed_scale := 1.0
		if moving:
			speed_scale = clampf(speed / 4.8, 0.8, 1.25)
		_play_anim(desired, speed_scale, 0.16)


func _play_anim(anim_name: String, speed := 1.0, blend := 0.1) -> void:
	if anim == null:
		return
	if not anim.has_animation(anim_name):
		return
	if _current_anim == anim_name and anim.is_playing():
		anim.speed_scale = speed
		return
	anim.play(anim_name, blend, speed)
	_current_anim = anim_name
	_anim_speed = speed


func _pose_umbrella(delta: float) -> void:
	if _umbrella == null or not is_instance_valid(_umbrella):
		return
	var hand := _umbrella.get_parent() as Node3D
	if hand == null:
		return
	var yaw := global_rotation.y
	var pitch := deg_to_rad(-12.0)
	var roll := deg_to_rad(26.0)
	var lift := 0.0
	if state == State.PARRY:
		pitch = deg_to_rad(-78.0)
		roll = deg_to_rad(-6.0)
	elif state == State.ATTACK:
		var t := clampf(state_time / (HEAVY_TOTAL if attack_heavy else LIGHT_TOTAL), 0.0, 1.0)
		roll = deg_to_rad(-84.0) * sin(t * PI)
		pitch = deg_to_rad(-22.0 + 24.0 * t)
		lift = 0.12 * sin(t * PI)
	elif state == State.DODGE:
		pitch = deg_to_rad(-30.0)
		roll = deg_to_rad(24.0)
	elif state == State.HEAL:
		pitch = deg_to_rad(-14.0)
		roll = deg_to_rad(-12.0)
	var basis := Basis.from_euler(Vector3(pitch, yaw, roll))
	var grip := hand.global_position
	var origin := grip + Vector3(0.0, 0.22 + lift, 0.0) + basis.x.normalized() * 0.48
	_umbrella.global_transform = Transform3D(basis, origin)


func _animate_canopy(delta: float) -> void:
	if _canopy == null:
		return
	var open := state == State.PARRY or (state == State.ATTACK and attack_heavy)
	var target := Vector3(1.0, 1.0, 1.0) if open else Vector3(0.62, 0.92, 0.62)
	_canopy.scale = _canopy.scale.lerp(target, clampf(delta * 12.0, 0.0, 1.0))
	if _canopy_mat != null:
		var glow := 1.15 if state == State.PARRY else 0.35
		_canopy_mat.emission_energy_multiplier = lerpf(_canopy_mat.emission_energy_multiplier, glow, clampf(delta * 10.0, 0.0, 1.0))
