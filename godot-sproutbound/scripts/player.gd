extends CharacterBody3D
class_name SproutPlayer

## 芽行者 — 原创阿栎帽小行者。第三人称剑击 FSM：
## 移动 / 疾跑 / 3 段连斩 / 闪避（无敌帧） / 受击 / 死亡。
## 角色、剑、围巾均为程序化低模，无外部模型或动画。

signal attack_strike(payload: Dictionary)
signal hurt(amount: int)
signal died
signal dodged

const MAX_HP := 100
const WALK_SPEED := 4.35
const SPRINT_SPEED := 6.5
const ACCEL := 27.0
const FRICTION := 24.0
const TURN_SPEED := 13.0
const GRAVITY := 24.0
const DODGE_TIME := 0.4
const DODGE_SPEED := 8.8
const DODGE_COOLDOWN := 0.22
const DODGE_INVULN := 0.28
const JUMP_SPEED := 7.6
const COYOTE_TIME := 0.09
const HURT_TIME := 0.28
const HURT_INVULN := 0.6
const COMBO_WINDOW := 0.62

const ATTACKS := {
	"slash1": {"label": "横斩", "total": 0.34, "hit": 0.105, "damage": 9,
		"range": 2.30, "arc": 80.0, "knockback": 0.32, "lunge": 1.1,
		"heavy": false, "color": Color(0.85, 1.0, 0.72)},
	"slash2": {"label": "回斩", "total": 0.37, "hit": 0.12, "damage": 11,
		"range": 2.42, "arc": 86.0, "knockback": 0.36, "lunge": 1.3,
		"heavy": false, "color": Color(0.78, 0.96, 0.66)},
	"finisher": {"label": "落叶斩", "total": 0.56, "hit": 0.22, "damage": 18,
		"range": 2.60, "arc": 96.0, "knockback": 1.05, "lunge": 1.8,
		"heavy": true, "color": Color(1.0, 0.86, 0.48)},
}

var main: Node
var hp := MAX_HP
var state := "idle"
var dead := false
var active := false
var controls_enabled := true

var attack_kind := ""
var attack_t := 0.0
var attack_hit_done := false
var combo_step := 0
var combo_window := 0.0
var queued_attack := false
var attack_count := 0
var hits_landed := 0

var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector3.FORWARD
var invuln_t := 0.0
var hurt_t := 0.0
var death_t := 0.0
var hurt_flash := 0.0
var coyote_t := 0.0
var was_airborne := false

var demo_override := false
var demo_axis := Vector3.ZERO

var model: Node3D
var hips: Array[Node3D] = []
var arm_l: Node3D
var arm_r: Node3D
var sword_root: Node3D
var sword_blade: MeshInstance3D
var scarf_tail: Node3D
var scarf_tail_2: Node3D
var head: Node3D
var cap_brim: MeshInstance3D
var debug_capsule: MeshInstance3D
var _flash_mats: Array[StandardMaterial3D] = []

var _t := 0.0
var _anim_phase := 0.0
var _facing_yaw := 0.0
var _last_wish := Vector3.ZERO
var _death_fall := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(48.0)
	up_direction = Vector3.UP
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.5
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.76
	add_child(col)
	_build_model()
	_build_debug_capsule()


# ------------------------------------------------------------------- input

func _physics_process(delta: float) -> void:
	_t += delta
	invuln_t = maxf(0.0, invuln_t - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	combo_window = maxf(0.0, combo_window - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 4.0)

	if dead:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if not active:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return

	if is_on_floor():
		coyote_t = COYOTE_TIME
	else:
		coyote_t = maxf(0.0, coyote_t - delta)
	was_airborne = not is_on_floor()

	if controls_enabled:
		_read_action_inputs()

	var wish := _wish_dir()
	var speed := SPRINT_SPEED if _sprinting(wish) else WALK_SPEED
	match state:
		"attack":
			_update_attack(delta)
		"dodge":
			_update_dodge(delta)
		"hurt":
			hurt_t -= delta
			velocity.x = move_toward(velocity.x, 0.0, FRICTION * 0.7 * delta)
			velocity.z = move_toward(velocity.z, 0.0, FRICTION * 0.7 * delta)
			if hurt_t <= 0.0:
				state = "idle"
		_:
			_update_locomotion(wish, speed, delta)

	velocity.y -= GRAVITY * delta
	move_and_slide()
	if was_airborne and is_on_floor() and velocity.y <= 0.1:
		if main != null:
			main.spawn_dodge_dust(global_position + Vector3(0.0, 0.05, 0.0),
				facing_dir())
		if state == "air":
			state = "idle"
	if state == "move" and Vector2(velocity.x, velocity.z).length() < 0.25:
		state = "idle"


func _read_action_inputs() -> void:
	if Input.is_action_just_pressed("attack"):
		try_attack()
	if Input.is_action_just_pressed("dodge"):
		try_dodge()
	if Input.is_action_just_pressed("jump"):
		try_jump()


func _wish_dir() -> Vector3:
	if demo_override:
		return demo_axis.limit_length(1.0)
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input.length_squared() < 0.001:
		return Vector3.ZERO
	var f: Vector3 = main.camera_flat_forward() if main != null else Vector3.FORWARD
	var r: Vector3 = main.camera_flat_right() if main != null else Vector3.RIGHT
	return (f * (-input.y) + r * input.x).limit_length(1.0)


func _sprinting(wish: Vector3) -> bool:
	if demo_override:
		return false
	return Input.is_action_pressed("sprint") and wish.length_squared() > 0.01 \
		and state in ["idle", "move"] and is_on_floor()


func _update_locomotion(wish: Vector3, speed: float, delta: float) -> void:
	var accel := ACCEL if is_on_floor() else ACCEL * 0.55
	if wish.length_squared() > 0.01:
		_last_wish = wish
		var target := wish * speed
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
		_facing_yaw = _rotate_toward(_facing_yaw, _yaw_from_dir(wish), TURN_SPEED * delta)
		rotation.y = _facing_yaw
		state = "sprint" if speed > WALK_SPEED + 0.1 else "move"
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0.0, FRICTION * delta)
		if state in ["move", "sprint"]:
			state = "idle"
	if not is_on_floor():
		state = "air"


# ------------------------------------------------------------------ attacks

func try_attack() -> bool:
	if dead or not controls_enabled:
		return false
	if state == "dodge" or state == "hurt":
		return false
	if state == "attack":
		if attack_t > ATTACKS[attack_kind].total * 0.3:
			queued_attack = true
		return false
	var step := 0
	if combo_window > 0.0 and combo_step < 2:
		step = combo_step + 1
	begin_attack(step)
	return true


func begin_attack(step: int) -> bool:
	if dead:
		return false
	var key := "slash1" if step == 0 else ("slash2" if step == 1 else "finisher")
	state = "attack"
	attack_kind = key
	attack_t = 0.0
	attack_hit_done = false
	combo_step = step
	combo_window = 0.0
	queued_attack = false
	attack_count += 1
	_snap_to_target()
	var dir := facing_dir()
	velocity.x = dir.x * ATTACKS[key].lunge
	velocity.z = dir.z * ATTACKS[key].lunge
	return true


func _snap_to_target() -> void:
	if main == null:
		return
	var target = main.find_attack_target(global_position, facing_dir(), 3.4)
	if target != null:
		var d: Vector3 = target.global_position - global_position
		_facing_yaw = _yaw_from_dir(Vector3(d.x, 0.0, d.z))
		rotation.y = _facing_yaw


func _update_attack(delta: float) -> void:
	var data: Dictionary = ATTACKS[attack_kind]
	attack_t += delta
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * 2.4 * delta)
	velocity.z = move_toward(velocity.z, 0.0, FRICTION * 2.4 * delta)
	if not attack_hit_done and attack_t >= float(data.hit):
		attack_hit_done = true
		var payload := {
			"damage": int(data.damage),
			"range": float(data.range),
			"arc": float(data.arc),
			"knockback": float(data.knockback),
			"heavy": bool(data.heavy),
			"pos": global_position + Vector3(0.0, 0.9, 0.0),
			"dir": facing_dir(),
			"label": String(data.label),
			"color": data.color,
			"step": combo_step,
		}
		attack_strike.emit(payload)
	if attack_t >= float(data.total):
		if queued_attack and combo_step < 2:
			begin_attack(combo_step + 1)
		else:
			state = "idle"
			queued_attack = false
			combo_window = COMBO_WINDOW


func facing_dir() -> Vector3:
	return Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))


# -------------------------------------------------------------------- dodge

func try_dodge() -> bool:
	if dead or not controls_enabled or dodge_cd > 0.0:
		return false
	if state == "dodge" or not is_on_floor():
		return false
	if state == "hurt":
		return false
	if state == "attack" and attack_t < ATTACKS[attack_kind].total * 0.3:
		return false
	var wish := _wish_dir()
	var dir := wish if wish.length_squared() > 0.01 else facing_dir()
	dodge_dir = dir.normalized()
	_facing_yaw = _yaw_from_dir(dodge_dir)
	rotation.y = _facing_yaw
	state = "dodge"
	dodge_t = 0.0
	dodge_cd = DODGE_COOLDOWN + DODGE_TIME * 0.35
	invuln_t = maxf(invuln_t, DODGE_INVULN)
	combo_window = 0.0
	queued_attack = false
	dodged.emit()
	if main != null:
		main.spawn_dodge_dust(global_position + Vector3(0.0, 0.08, 0.0), dodge_dir)
	return true


func _update_dodge(delta: float) -> void:
	dodge_t += delta
	var k: float = dodge_t / DODGE_TIME
	var spd: float = DODGE_SPEED * (1.0 - 0.72 * ease(k, 0.4))
	velocity.x = dodge_dir.x * spd
	velocity.z = dodge_dir.z * spd
	if dodge_t >= DODGE_TIME:
		state = "idle"
		combo_window = 0.0


func try_jump() -> bool:
	if dead or not controls_enabled:
		return false
	if state in ["dodge", "hurt"]:
		return false
	if not is_on_floor() and coyote_t <= 0.0:
		return false
	if state == "attack" and attack_t < ATTACKS[attack_kind].total * 0.25:
		return false
	velocity.y = JUMP_SPEED
	coyote_t = 0.0
	state = "air"
	if main != null:
		main.spawn_dodge_dust(global_position + Vector3(0.0, 0.05, 0.0),
			facing_dir())
	return true


func is_invulnerable() -> bool:
	return invuln_t > 0.0 or dead


func in_dodge_iframes() -> bool:
	return state == "dodge" and dodge_t < DODGE_INVULN


# -------------------------------------------------------------------- damage

func take_damage(amount: int, from_pos: Vector3, knockback: float = 0.4,
		_heavy: bool = false) -> bool:
	if dead:
		return false
	if is_invulnerable():
		return false
	hp = maxi(0, hp - amount)
	invuln_t = HURT_INVULN
	hurt_flash = 1.0
	combo_window = 0.0
	queued_attack = false
	var d := global_position - from_pos
	d.y = 0.0
	if d.length_squared() < 0.001:
		d = -facing_dir()
	d = d.normalized()
	velocity.x = d.x * (2.6 + knockback * 3.4)
	velocity.z = d.z * (2.6 + knockback * 3.4)
	state = "hurt"
	hurt_t = HURT_TIME
	hurt.emit(amount)
	if hp <= 0:
		_die()
	return true


func _die() -> void:
	dead = true
	state = "dead"
	active = false
	death_t = 0.0
	_death_fall = 0.0
	velocity = Vector3.ZERO
	died.emit()
	if main != null:
		main.spawn_spore_burst(global_position + Vector3(0.0, 0.15, 0.0),
			Color(0.85, 0.92, 0.7), 14)


func heal(amount: int) -> void:
	if dead:
		return
	hp = mini(MAX_HP, hp + amount)


func reset_state(pos: Vector3, yaw: float = PI) -> void:
	hp = MAX_HP
	dead = false
	state = "idle"
	attack_kind = ""
	attack_t = 0.0
	combo_step = 0
	combo_window = 0.0
	queued_attack = false
	dodge_t = 0.0
	dodge_cd = 0.0
	invuln_t = 0.0
	hurt_t = 0.0
	death_t = 0.0
	_death_fall = 0.0
	velocity = Vector3.ZERO
	global_position = pos
	_facing_yaw = yaw
	rotation.y = yaw
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	model.visible = true


func facing_yaw() -> float:
	return _facing_yaw


# --------------------------------------------------------------------- demo

func demo_move(dir: Vector3) -> void:
	demo_override = true
	demo_axis = dir.limit_length(1.0)


func demo_stop() -> void:
	demo_axis = Vector3.ZERO


# -------------------------------------------------------------------- model

func _build_debug_capsule() -> void:
	debug_capsule = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.3
	mesh.height = 1.5
	debug_capsule.mesh = mesh
	var mat := SproutStyle.mat(Color(0.35, 0.9, 1.0, 0.18), 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	debug_capsule.material_override = mat
	debug_capsule.position = Vector3(0.0, 0.76, 0.0)
	debug_capsule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug_capsule.visible = false
	add_child(debug_capsule)


func set_debug(v: bool) -> void:
	if debug_capsule != null:
		debug_capsule.visible = v


func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)

	var skin := SproutStyle.mat(Color(0.96, 0.83, 0.66), 0.9)
	var tunic := SproutStyle.mat(Color(0.34, 0.56, 0.35), 0.92)
	var tunic_dark := SproutStyle.mat(Color(0.25, 0.43, 0.28), 0.94)
	var cream := SproutStyle.mat(Color(0.93, 0.87, 0.70), 0.9)
	var scarf := SproutStyle.mat(Color(0.91, 0.53, 0.25), 0.9)
	var scarf_dark := SproutStyle.mat(Color(0.78, 0.41, 0.19), 0.92)
	var wood := SproutStyle.mat(Color(0.55, 0.37, 0.22), 0.9)
	var wood_dark := SproutStyle.mat(Color(0.43, 0.28, 0.16), 0.92)
	var blade := SproutStyle.mat(Color(0.80, 0.72, 0.48), 0.72,
		Color.BLACK, 0.0)
	var dark := SproutStyle.mat(Color(0.15, 0.17, 0.15), 0.95)
	var acorn := SproutStyle.mat(Color(0.58, 0.38, 0.22), 0.92)
	var acorn_dark := SproutStyle.mat(Color(0.45, 0.28, 0.15), 0.94)
	var leaf := SproutStyle.mat(Color(0.47, 0.70, 0.34), 0.9)
	_flash_mats = [tunic, tunic_dark, cream, scarf]

	# 腿（髋部枢轴便于摆动）
	for i in 2:
		var hip := Node3D.new()
		hip.position = Vector3(-0.135 + float(i) * 0.27, 0.52, 0.0)
		model.add_child(hip)
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.075
		leg_mesh.height = 0.4
		leg.mesh = leg_mesh
		leg.material_override = tunic_dark
		leg.position = Vector3(0.0, -0.2, 0.0)
		hip.add_child(leg)
		var boot := MeshInstance3D.new()
		var boot_mesh := BoxMesh.new()
		boot_mesh.size = Vector3(0.16, 0.11, 0.26)
		boot.mesh = boot_mesh
		boot.material_override = dark
		boot.position = Vector3(0.0, -0.43, -0.045)
		hip.add_child(boot)
		hips.append(hip)

	# 身体 / 下摆 / 腰带 / 挎包
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.27
	body_mesh.height = 0.72
	body.mesh = body_mesh
	body.material_override = tunic
	body.position = Vector3(0.0, 0.93, 0.0)
	body.scale = Vector3(1.0, 1.0, 0.9)
	model.add_child(body)

	var skirt := MeshInstance3D.new()
	skirt.mesh = SproutStyle.low_cylinder(0.26, 0.35, 0.26, 8)
	skirt.material_override = tunic_dark
	skirt.position = Vector3(0.0, 0.62, 0.0)
	model.add_child(skirt)

	var belt := MeshInstance3D.new()
	belt.mesh = SproutStyle.low_cylinder(0.285, 0.285, 0.07, 10)
	belt.material_override = cream
	belt.position = Vector3(0.0, 0.73, 0.0)
	model.add_child(belt)

	var satchel := MeshInstance3D.new()
	var bag := BoxMesh.new()
	bag.size = Vector3(0.26, 0.22, 0.14)
	satchel.mesh = bag
	satchel.material_override = SproutStyle.mat(Color(0.62, 0.47, 0.30), 0.92)
	satchel.position = Vector3(-0.19, 0.8, 0.22)
	model.add_child(satchel)

	# 头 / 眼 / 阿栎帽
	head = Node3D.new()
	head.position = Vector3(0.0, 1.3, 0.0)
	model.add_child(head)
	var face := MeshInstance3D.new()
	var face_mesh := SphereMesh.new()
	face_mesh.radius = 0.235
	face_mesh.height = 0.46
	face_mesh.radial_segments = 10
	face_mesh.rings = 6
	face.mesh = face_mesh
	face.material_override = skin
	head.add_child(face)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.028
		eye_mesh.height = 0.056
		eye_mesh.radial_segments = 6
		eye_mesh.rings = 4
		eye.mesh = eye_mesh
		eye.material_override = dark
		eye.position = Vector3(0.083 * side, 0.015, -0.205)
		head.add_child(eye)
	var cheek_mat := SproutStyle.mat(Color(0.92, 0.58, 0.48), 0.9)
	for side in [-1.0, 1.0]:
		var cheek := MeshInstance3D.new()
		cheek.mesh = SphereMesh.new()
		cheek.mesh.radius = 0.035
		cheek.mesh.height = 0.07
		cheek.material_override = cheek_mat
		cheek.position = Vector3(0.145 * side, -0.055, -0.185)
		head.add_child(cheek)

	var acorn_cap := MeshInstance3D.new()
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.275
	cap_mesh.height = 0.3
	cap_mesh.radial_segments = 9
	cap_mesh.rings = 4
	acorn_cap.mesh = cap_mesh
	acorn_cap.material_override = acorn
	acorn_cap.position = Vector3(0.0, 0.15, 0.0)
	acorn_cap.scale = Vector3(1.06, 0.75, 1.06)
	head.add_child(acorn_cap)
	cap_brim = MeshInstance3D.new()
	var brim := TorusMesh.new()
	brim.inner_radius = 0.2
	brim.outer_radius = 0.3
	brim.rings = 12
	brim.ring_segments = 4
	cap_brim.mesh = brim
	cap_brim.material_override = acorn_dark
	cap_brim.position = Vector3(0.0, 0.08, 0.0)
	head.add_child(cap_brim)
	var stem := MeshInstance3D.new()
	stem.mesh = SproutStyle.low_cylinder(0.022, 0.03, 0.12, 5)
	stem.material_override = wood
	stem.position = Vector3(0.0, 0.32, 0.02)
	stem.rotation.z = 0.25
	head.add_child(stem)

	# 围巾（领口 + 两段飘带，不复制参考角色的披风）
	var collar := MeshInstance3D.new()
	var collar_mesh := TorusMesh.new()
	collar_mesh.inner_radius = 0.16
	collar_mesh.outer_radius = 0.25
	collar_mesh.rings = 14
	collar_mesh.ring_segments = 5
	collar.mesh = collar_mesh
	collar.material_override = scarf
	collar.position = Vector3(0.0, 1.15, 0.0)
	model.add_child(collar)
	scarf_tail = Node3D.new()
	scarf_tail.position = Vector3(0.08, 1.11, 0.17)
	model.add_child(scarf_tail)
	var tail1 := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.14, 0.32, 0.035)
	tail1.mesh = tail_mesh
	tail1.material_override = scarf
	tail1.position = Vector3(0.0, -0.16, 0.02)
	scarf_tail.add_child(tail1)
	scarf_tail_2 = Node3D.new()
	scarf_tail_2.position = Vector3(0.0, -0.32, 0.02)
	scarf_tail.add_child(scarf_tail_2)
	var tail2 := MeshInstance3D.new()
	var tail_mesh2 := BoxMesh.new()
	tail_mesh2.size = Vector3(0.12, 0.24, 0.03)
	tail2.mesh = tail_mesh2
	tail2.material_override = scarf_dark
	tail2.position = Vector3(0.0, -0.11, 0.015)
	scarf_tail_2.add_child(tail2)

	# 手臂
	arm_l = Node3D.new()
	arm_l.position = Vector3(-0.31, 1.1, 0.0)
	model.add_child(arm_l)
	_add_arm(arm_l, tunic, skin, false)
	arm_r = Node3D.new()
	arm_r.position = Vector3(0.31, 1.1, 0.0)
	model.add_child(arm_r)
	_add_arm(arm_r, tunic, skin, true)

	# 树枝剑
	sword_root = Node3D.new()
	sword_root.position = Vector3(0.015, -0.38, -0.03)
	sword_root.rotation = Vector3(-0.28, 0.0, 0.0)
	arm_r.add_child(sword_root)
	var handle := MeshInstance3D.new()
	handle.mesh = SproutStyle.low_cylinder(0.032, 0.037, 0.2, 6)
	handle.material_override = wood
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(0.0, 0.0, 0.095)
	sword_root.add_child(handle)
	var pommel := MeshInstance3D.new()
	pommel.mesh = SproutStyle.low_sphere(0.048, 6, 3)
	pommel.material_override = wood_dark
	pommel.position = Vector3(0.0, 0.0, 0.205)
	sword_root.add_child(pommel)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.26, 0.055, 0.055)
	guard.mesh = guard_mesh
	guard.material_override = leaf
	guard.position = Vector3(0.0, 0.0, -0.04)
	sword_root.add_child(guard)
	sword_blade = MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.09, 0.035, 0.66)
	sword_blade.mesh = blade_mesh
	sword_blade.material_override = blade
	sword_blade.position = Vector3(0.0, 0.0, -0.39)
	sword_root.add_child(sword_blade)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.05, 0.026, 0.14)
	tip.mesh = tip_mesh
	tip.material_override = blade
	tip.position = Vector3(0.0, 0.0, -0.78)
	tip.rotation.y = PI / 4.0
	sword_root.add_child(tip)
	# 叶形护手上的小叶片
	for side in [-1.0, 1.0]:
		var leaf_bit := MeshInstance3D.new()
		var lb := SphereMesh.new()
		lb.radius = 0.06
		lb.height = 0.08
		lb.radial_segments = 5
		lb.rings = 3
		leaf_bit.mesh = lb
		leaf_bit.material_override = leaf
		leaf_bit.position = Vector3(0.16 * side, 0.0, -0.035)
		leaf_bit.scale = Vector3(1.0, 0.3, 0.6)
		sword_root.add_child(leaf_bit)

	# 脚底接地阴影（程序化圆盘；GL/Intel 上实时方向光阴影无输出，见 TECH）
	var blob := MeshInstance3D.new()
	var blob_mesh := SproutStyle.low_cylinder(0.42, 0.42, 0.01, 18)
	blob.mesh = blob_mesh
	blob.material_override = SproutStyle.unshaded(Color(0.04, 0.08, 0.04, 0.30))
	blob.position = Vector3(0.0, 0.02, 0.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(blob)


func _add_arm(root: Node3D, tunic: StandardMaterial3D, skin: StandardMaterial3D,
		sword_side: bool) -> void:
	var upper := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.068
	mesh.height = 0.34
	upper.mesh = mesh
	upper.material_override = tunic
	upper.position = Vector3(0.0, -0.16, 0.0)
	root.add_child(upper)
	var hand := MeshInstance3D.new()
	var hand_mesh := SphereMesh.new()
	hand_mesh.radius = 0.078
	hand_mesh.height = 0.15
	hand_mesh.radial_segments = 8
	hand_mesh.rings = 5
	hand.mesh = hand_mesh
	hand.material_override = skin
	hand.position = Vector3(0.0, -0.36, 0.0)
	root.add_child(hand)
	if not sword_side:
		root.rotation = Vector3(0.0, 0.0, 0.06)


# ------------------------------------------------------------------- visual

func _process(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.35 and state in ["move", "sprint"] and not dead
	if moving:
		_anim_phase += delta * (6.2 + speed * 0.85)
	else:
		_anim_phase += delta * 1.8

	var stride := 0.0
	if moving:
		stride = sin(_anim_phase) * clampf(speed / WALK_SPEED, 0.4, 1.35) * 0.62
	for i in hips.size():
		hips[i].rotation.x = stride if i == 0 else -stride
		hips[i].rotation.z = 0.0

	var bob := 0.0
	if moving:
		bob = absf(sin(_anim_phase)) * 0.035
	else:
		bob = sin(_t * 1.7) * 0.012
	model.position.y = bob
	model.rotation = Vector3.ZERO
	head.rotation.y = sin(_t * 0.7) * 0.06

	var rest_arm_l := Vector3(-stride * 0.45, 0.0, 0.06)
	arm_l.rotation = arm_l.rotation.lerp(rest_arm_l, 1.0 - exp(-12.0 * delta))
	arm_r.rotation = arm_r.rotation.lerp(
		Vector3(-stride * 0.35, 0.0, 0.0), 1.0 - exp(-12.0 * delta))

	var sway := sin(_t * 2.3 + 0.6) * 0.12 + speed * 0.03
	scarf_tail.rotation = Vector3(-0.28 - speed * 0.045 + sway * 0.4, 0.0, sway * 0.5)
	scarf_tail_2.rotation = Vector3(-0.18 + sway * 0.6, 0.0, sway * 0.7)

	match state:
		"attack":
			_pose_attack()
		"dodge":
			_pose_dodge()
		"hurt":
			var k := 1.0 - clampf(hurt_t / HURT_TIME, 0.0, 1.0)
			model.rotation.x = 0.18 * sin(k * PI)
			model.rotation.z = 0.05 * sin(k * PI * 2.0)
		"air":
			model.rotation.x = -0.08
			hips[0].rotation.x = -0.55
			hips[1].rotation.x = 0.22
			arm_l.rotation = Vector3(-0.5, 0.0, -0.4)
			arm_r.rotation = Vector3(-0.2, 0.0, 0.25)
		"dead":
			_death_fall = minf(1.0, _death_fall + delta * 2.2)
			model.rotation.z = ease(_death_fall, 0.4) * -PI * 0.5
			model.position.y = -0.1 * _death_fall
		_:
			model.rotation.x = lerpf(model.rotation.x, 0.0, 1.0 - exp(-10.0 * delta))

	for m in _flash_mats:
		if hurt_flash > 0.0:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.45, 0.3)
			m.emission_energy_multiplier = hurt_flash * 0.8
		else:
			m.emission_enabled = false


func _pose_attack() -> void:
	var data: Dictionary = ATTACKS[attack_kind]
	var total: float = data.total
	var hit_t: float = data.hit
	var t := clampf(attack_t / total, 0.0, 1.0)
	var arm := Vector3.ZERO
	var lean := 0.0
	var yaw := 0.0
	var sword_rot := Vector3(-0.28, 0.0, 0.0)
	if attack_kind == "finisher":
		var wind := clampf(attack_t / hit_t, 0.0, 1.0)
		var follow := clampf((attack_t - hit_t) / (total - hit_t), 0.0, 1.0)
		if attack_t < hit_t:
			arm = Vector3(-1.55, 0.1, 0.25).lerp(Vector3(-1.9, 0.0, 0.15), wind)
			sword_rot = Vector3(-1.0, 0.0, 0.0)
			lean = -0.06 * wind
			yaw = 0.0
		else:
			arm = Vector3(1.45, 0.0, 0.0).lerp(Vector3(0.3, 0.0, 0.0), ease(follow, 0.3))
			sword_rot = Vector3(0.5, 0.0, 0.0)
			lean = 0.14 * (1.0 - follow)
			yaw = 0.0
	else:
		var reverse := attack_kind == "slash2"
		var wind := clampf(attack_t / hit_t, 0.0, 1.0)
		var follow := clampf((attack_t - hit_t) / (total - hit_t), 0.0, 1.0)
		if attack_t < hit_t:
			if reverse:
				arm = Vector3(0.2, 0.15, -1.15).lerp(Vector3(0.35, 0.2, -1.3), wind)
				yaw = 0.25 * wind
			else:
				arm = Vector3(-0.1, -0.2, 1.1).lerp(Vector3(-0.25, -0.25, 1.35), wind)
				yaw = -0.28 * wind
			sword_rot = Vector3(-0.2, 0.4, 0.2)
		else:
			var k := ease(follow, 0.35)
			if reverse:
				arm = Vector3(0.55, 0.2, 1.3).lerp(Vector3(0.05, 0.0, 0.35), k)
				yaw = 0.3 - 0.5 * k
			else:
				arm = Vector3(0.55, 0.2, -1.25).lerp(Vector3(0.05, 0.0, -0.35), k)
				yaw = -0.3 + 0.55 * k
			sword_rot = Vector3(0.15, -0.4, -0.15)
	arm_r.rotation = arm
	arm_l.rotation = Vector3(0.2, 0.0, -0.25)
	sword_root.rotation = sword_rot
	model.rotation.y = yaw
	model.rotation.x = lean


func _pose_dodge() -> void:
	var k := clampf(dodge_t / DODGE_TIME, 0.0, 1.0)
	model.rotation.x = -0.5 * sin(k * PI)
	model.position.y = -0.08 * sin(k * PI)
	arm_l.rotation = Vector3(-0.6, 0.0, -0.5) * sin(k * PI)
	arm_r.rotation = Vector3(-0.9, 0.0, 0.6) * sin(k * PI)


# -------------------------------------------------------------------- utils

func _yaw_from_dir(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _rotate_toward(current: float, target: float, step: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	return current + clampf(diff, -step, step)
