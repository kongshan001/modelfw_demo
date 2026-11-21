extends CharacterBody3D
class_name ChanganPlayer

## 沈灯 — 守灯人。第三人称拳脚 FSM：移动/冲刺/刺拳/踢击/3 连/翻滚（i-frames）/
## 受击/击倒/起身/胜利。角色网格为 CC0 KayKit Rogue 重着色，灯与缠布为程序化原创。

signal attack_landed(kind: String, damage: int, heavy: bool, knockdown: bool, pos: Vector3)
signal attack_whiffed(pos: Vector3, dir: Vector3, heavy: bool)
signal hurt(amount: int)
signal died
signal lamp_break_cast(pos: Vector3)
signal qi_full

const MODEL_PATH := "res://assets/models/kaykit/Rogue.glb"
const MODEL_SCALE := 0.80
const MAX_HP := 100
const MAX_QI := 100.0
const RUN_SPEED := 4.2
const SPRINT_SPEED := 6.0
const ACCEL := 28.0
const DECEL := 26.0
const ROLL_TIME := 0.45
const ROLL_SPEED := 7.1
const ROLL_IFRAME_START := 0.08
const ROLL_IFRAME_END := 0.30
const ROLL_COOLDOWN := 0.20

const ATTACKS := {
	"jab1": {"clip": "Unarmed_Melee_Attack_Punch_A", "speed": 3.0, "total": 0.42,
		"hit": 0.14, "damage": 6, "range": 2.05, "arc": 0.70, "knockback": 0.15,
		"hitstop": 0.034, "qi": 6.0, "heavy": false, "knockdown": false},
	"jab2": {"clip": "Unarmed_Melee_Attack_Punch_B", "speed": 3.0, "total": 0.44,
		"hit": 0.15, "damage": 6, "range": 2.05, "arc": 0.70, "knockback": 0.15,
		"hitstop": 0.034, "qi": 6.0, "heavy": false, "knockdown": false},
	"kick": {"clip": "Unarmed_Melee_Attack_Kick", "speed": 1.30, "total": 0.72,
		"hit": 0.28, "damage": 14, "range": 2.20, "arc": 0.62, "knockback": 0.6,
		"hitstop": 0.067, "qi": 10.0, "heavy": true, "knockdown": false},
	"finisher": {"clip": "Unarmed_Melee_Attack_Kick", "speed": 1.18, "total": 0.80,
		"hit": 0.32, "damage": 20, "range": 2.35, "arc": 0.60, "knockback": 1.0,
		"hitstop": 0.10, "qi": 14.0, "heavy": true, "knockdown": true},
	"lampbreak": {"clip": "2H_Melee_Attack_Spin", "speed": 3.2, "total": 0.78,
		"hit": 0.40, "damage": 30, "range": 3.0, "arc": 2.0, "knockback": 0.9,
		"hitstop": 0.134, "qi": 0.0, "heavy": true, "knockdown": true},
}

var main: Node
var hp := MAX_HP
var qi := 0.0
var state := "idle"
var controls_enabled := true
var frozen := false
var demo_axis := Vector3.ZERO

var model_root: Node3D
var anim: AnimationPlayer
var mesh_instances: Array[MeshInstance3D] = []
var body_tint := Color(0.66, 0.76, 0.98)

var attack_kind := ""
var attack_t := 0.0
var attack_hit_done := false
var combo_step := 0
var combo_window := 0.0
var queued_attack := ""
var queued_roll := false
var roll_t := 0.0
var roll_cooldown := 0.0
var roll_dir := Vector3.FORWARD
var knockdown_t := 0.0
var knockdown_phase := ""
var getup_t := 0.0
var hit_stun := 0.0
var dead := false
var iframe_debug := false
var attack_count := 0
var hits_landed := 0
var last_attack_target: Node3D

var _facing_yaw := 0.0
var _hurt_t := 0.0
var _qi_was_full := false
var _blob: MeshInstance3D
var _lamp_glow: MeshInstance3D
var _style_cache: StandardMaterial3D
var roll_ring: MeshInstance3D
var roll_ring_mat: StandardMaterial3D


func _ready() -> void:
	_ensure_input_map()
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.35
	up_direction = Vector3.UP
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.72
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.86
	add_child(col)
	_build_model()
	_build_shadow()
	_build_roll_ring()
	play_anim("Idle", 0.0)


func _build_roll_ring() -> void:
	roll_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.56
	tm.rings = 32
	tm.ring_segments = 6
	roll_ring.mesh = tm
	roll_ring_mat = StandardMaterial3D.new()
	roll_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	roll_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	roll_ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	roll_ring_mat.albedo_color = Color(0.55, 0.78, 1.0, 0.55)
	roll_ring_mat.emission_enabled = true
	roll_ring_mat.emission = Color(0.45, 0.72, 1.0)
	roll_ring_mat.emission_energy_multiplier = 1.8
	roll_ring_mat.disable_receive_shadows = true
	roll_ring.material_override = roll_ring_mat
	roll_ring.position.y = 0.055
	roll_ring.visible = false
	roll_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(roll_ring)


func _ensure_input_map() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_forward", KEY_UP)
	_add_key("move_back", KEY_S)
	_add_key("move_back", KEY_DOWN)
	_add_key("move_left", KEY_A)
	_add_key("move_left", KEY_LEFT)
	_add_key("move_right", KEY_D)
	_add_key("move_right", KEY_RIGHT)
	_add_mouse("jab", MOUSE_BUTTON_LEFT)
	_add_mouse("kick", MOUSE_BUTTON_RIGHT)
	_add_key("roll", KEY_SPACE)
	_add_key("sprint", KEY_SHIFT)
	_add_key("lock", KEY_TAB)
	_add_key("interact", KEY_E)
	_add_key("lamp_break", KEY_Q)
	_add_key("reset", KEY_R)
	_add_key("advance", KEY_ENTER)
	_add_key("advance", KEY_SPACE)
	_add_joy_button("jab", JOY_BUTTON_X)
	_add_joy_button("kick", JOY_BUTTON_Y)
	_add_joy_button("roll", JOY_BUTTON_B)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("lock", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("advance", JOY_BUTTON_A)
	_add_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("lamp_break", JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.5)


func _add_key(action: StringName, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)


func _add_mouse(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_button(action: StringName, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _add_joy_axis(action: StringName, axis: int, value: float, deadzone := 0.18) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
	if InputMap.action_get_deadzone(action) > 0.0:
		pass


# ── model ───────────────────────────────────────────────────────────────────

func _build_model() -> void:
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		push_error("ChanganPlayer: missing " + MODEL_PATH)
		return
	model_root = Node3D.new()
	model_root.name = "ShenDengModel"
	model_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(model_root)
	var model: Node3D = packed.instantiate()
	model_root.add_child(model)
	_hide_props(model)
	_style_model(model)
	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim == null:
		push_error("ChanganPlayer: no AnimationPlayer in KayKit Rogue")
		return
	for clip in ["Idle", "Walking_A", "Running_A", "Unarmed_Idle"]:
		if anim.has_animation(clip):
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# 腰间灯（沈灯的身份道具）+ 右臂缠布
	var lamp_holder := Node3D.new()
	lamp_holder.position = Vector3(0.42, 1.02, 0.02)
	model_root.add_child(lamp_holder)
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.20, 0.16)
	frame.mesh = bm
	frame.material_override = _mat(Color(0.09, 0.08, 0.07), 0.6, 0.4)
	lamp_holder.add_child(frame)
	_lamp_glow = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.055
	sm.height = 0.10
	sm.radial_segments = 10
	sm.rings = 6
	_lamp_glow.mesh = sm
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(1.0, 0.66, 0.28)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.62, 0.24)
	glow_mat.emission_energy_multiplier = 2.4
	_lamp_glow.material_override = glow_mat
	lamp_holder.add_child(_lamp_glow)
	# 纸白围巾 + 夜蓝披肩：沈灯的原创剪影色键
	var scarf := MeshInstance3D.new()
	var sm2 := BoxMesh.new()
	sm2.size = Vector3(0.56, 0.10, 0.30)
	scarf.mesh = sm2
	scarf.material_override = _mat(Color(0.92, 0.86, 0.72), 0.95)
	scarf.position = Vector3(0, 1.38, 0.03)
	model_root.add_child(scarf)
	var mantle := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.66, 0.14, 0.40)
	mantle.mesh = mm
	mantle.material_override = _mat(Color(0.10, 0.16, 0.34), 0.9)
	mantle.position = Vector3(0, 1.34, -0.04)
	model_root.add_child(mantle)
	# 背面纸白布条 + 金腰带：第三人称背影也能认出沈灯
	var back_strip := MeshInstance3D.new()
	var bsm := BoxMesh.new()
	bsm.size = Vector3(0.20, 0.66, 0.05)
	back_strip.mesh = bsm
	back_strip.material_override = _mat(Color(0.90, 0.84, 0.70), 0.95)
	back_strip.position = Vector3(0, 1.03, -0.235)
	model_root.add_child(back_strip)
	var belt := MeshInstance3D.new()
	var btm := TorusMesh.new()
	btm.inner_radius = 0.30
	btm.outer_radius = 0.35
	btm.rings = 18
	btm.ring_segments = 6
	belt.mesh = btm
	belt.material_override = _mat(Color(0.86, 0.62, 0.24), 0.35, 0.6)
	belt.position = Vector3(0, 0.92, 0.0)
	belt.rotation.x = PI * 0.5
	model_root.add_child(belt)
	for i in 3:
		var knot := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.03
		km.height = 0.05
		km.radial_segments = 6
		km.rings = 4
		knot.mesh = km
		knot.material_override = _mat(Color(0.98, 0.72, 0.30), 0.3, 0.6)
		knot.position = Vector3(-0.2 + i * 0.2, 1.43, 0.18)
		model_root.add_child(knot)


func _mat(color: Color, roughness := 0.8, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.disable_receive_shadows = true
	return m


func _hide_props(root: Node) -> void:
	var keywords := ["Dagger", "Crossbow", "Knife", "Sword", "Arrow", "Bow",
		"Shield", "Quiver", "Axe", "Mug", "Wand", "Staff", "Spellbook", "Bomb"]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for key in keywords:
			if String(node.name).contains(key):
				(node as MeshInstance3D).visible = false
				break


func _style_model(root: Node) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	var tex: Texture2D = null
	for node in meshes:
		var mi: MeshInstance3D = node
		mesh_instances.append(mi)
		for i in mi.mesh.get_surface_count():
			var mat: Material = mi.get_active_material(i)
			if tex == null and mat is StandardMaterial3D:
				tex = (mat as StandardMaterial3D).albedo_texture
	var tint := ShaderMaterial.new()
	tint.shader = load("res://shaders/character_tint.gdshader")
	if tex != null:
		tint.set_shader_parameter("albedo_tex", tex)
	# 夜蓝 / 灯金 / 纸白：沈灯的色键
	tint.set_shader_parameter("target_hue", 0.615)
	tint.set_shader_parameter("hue_mix", 0.90)
	tint.set_shader_parameter("saturation", 0.92)
	tint.set_shader_parameter("value_scale", 1.02)
	tint.set_shader_parameter("rim_color", Color(1.0, 0.68, 0.28))
	tint.set_shader_parameter("rim_strength", 0.44)
	tint.set_shader_parameter("emission_strength", 0.07)
	for node in meshes:
		var mi2: MeshInstance3D = node
		for i in mi2.mesh.get_surface_count():
			if tex != null:
				mi2.set_surface_override_material(i, tint)
			elif mi2.get_active_material(i) is StandardMaterial3D:
				var fallback: StandardMaterial3D = (mi2.get_active_material(i) as StandardMaterial3D).duplicate()
				fallback.albedo_color = Color(0.48, 0.62, 1.0)
				fallback.emission_enabled = true
				fallback.emission = Color(0.14, 0.24, 0.55)
				fallback.emission_energy_multiplier = 0.24
				mi2.set_surface_override_material(i, fallback)


func _build_shadow() -> void:
	_blob = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.44
	cm.bottom_radius = 0.52
	cm.height = 0.012
	cm.radial_segments = 18
	_blob.mesh = cm
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.albedo_color = Color(0, 0, 0, 0.40)
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.disable_receive_shadows = true
	_blob.material_override = bm
	_blob.position.y = 0.018
	_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_blob)


# ── physics / input ─────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if dead:
		return
	if frozen:
		return
	if roll_cooldown > 0.0:
		roll_cooldown -= delta
	if combo_window > 0.0:
		combo_window -= delta
		if combo_window <= 0.0 and state in ["idle", "move", "sprint"]:
			combo_step = 0
	if _hurt_t > 0.0:
		_hurt_t -= delta

	if controls_enabled:
		_handle_actions()

	match state:
		"roll":
			_process_roll(delta)
		"attack":
			_process_attack(delta)
		"hit":
			hit_stun -= delta
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			if hit_stun <= 0.0:
				_set_locomotion()
		"knockdown":
			_process_knockdown(delta)
		"getup":
			_process_getup(delta)
			if getup_t >= 0.80:
				state = "idle"
				_set_locomotion()
		"victory", "dead":
			velocity.x = 0.0
			velocity.z = 0.0
		_:
			_process_locomotion(delta)

	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	_update_lamp_light(delta)


func _handle_actions() -> void:
	if Input.is_action_just_pressed("jab"):
		_request_attack("jab")
	elif Input.is_action_just_pressed("kick"):
		_request_attack("kick")
	if Input.is_action_just_pressed("roll"):
		_request_roll()
	if Input.is_action_just_pressed("lamp_break"):
		try_lamp_break()


func _process_locomotion(delta: float) -> void:
	var wish := _wish_direction()
	var sprint := Input.is_action_pressed("sprint") and controls_enabled
	var speed := SPRINT_SPEED if sprint else RUN_SPEED
	if demo_axis.length_squared() > 0.01:
		wish = demo_axis.normalized()
	var target := wish * speed
	var rate := ACCEL if wish.length_squared() > 0.01 else DECEL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	if wish.length_squared() > 0.04:
		var yaw := atan2(wish.x, wish.z)
		if state != "sprint" or true:
			rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-14.0 * delta))
		state = "sprint" if sprint else "move"
		var clip := "Running_A"
		var spd := 1.0
		if sprint:
			spd = 1.25
		elif flat_speed < 3.0:
			clip = "Walking_A"
			spd = 1.05
		play_anim(clip, 0.16, spd)
	else:
		if state not in ["idle"]:
			state = "idle"
			play_anim("Unarmed_Idle" if anim != null and anim.has_animation("Unarmed_Idle") else "Idle", 0.22)
		elif anim != null and not anim.is_playing():
			play_anim("Unarmed_Idle" if anim.has_animation("Unarmed_Idle") else "Idle", 0.22)
		follow_lock_facing(delta)


func _wish_direction() -> Vector3:
	if not controls_enabled:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if cam != null:
		right = cam.global_basis.x
		right.y = 0.0
		right = right.normalized()
		forward = -cam.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
	var input := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	return (right * input.x + forward * input.y).normalized()


func follow_lock_facing(delta: float) -> void:
	if main != null and main.lock_target != null and is_instance_valid(main.lock_target):
		var d: Vector3 = main.lock_target.global_position - global_position
		d.y = 0.0
		if d.length_squared() > 0.01:
			rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), 1.0 - exp(-10.0 * delta))


# ── attack ──────────────────────────────────────────────────────────────────

func _request_attack(kind: String) -> void:
	if state == "attack":
		if attack_t >= 0.2:
			queued_attack = kind
		return
	if state in ["roll", "knockdown", "hit", "victory", "dead"]:
		return
	begin_attack(kind)


func begin_attack(kind: String) -> bool:
	if state in ["knockdown", "hit", "victory", "dead"] or dead:
		return false
	var resolved := kind
	if combo_window > 0.0 and combo_step >= 2:
		resolved = "finisher"
	elif resolved == "jab":
		resolved = "jab2" if (combo_window > 0.0 and combo_step == 1) else "jab1"
	_face_attack_target()
	var data: Dictionary = ATTACKS[resolved]
	attack_kind = resolved
	attack_t = 0.0
	attack_hit_done = false
	state = "attack"
	attack_count += 1
	play_anim(data["clip"], 0.06, data["speed"])
	# 连段推进
	if resolved in ["jab1", "jab2"]:
		combo_step += 1
		combo_window = 0.72
	elif resolved in ["kick", "finisher"]:
		combo_step = 0
		combo_window = 0.0
	else:
		combo_step = 0
		combo_window = 0.0
	return true


func _process_attack(delta: float) -> void:
	var data: Dictionary = ATTACKS[attack_kind]
	attack_t += delta
	# 攻击前冲
	if attack_t < float(data["hit"]) + 0.08:
		var lunge := 1.6 if attack_kind in ["kick", "finisher"] else 1.0
		velocity.x = sin(rotation.y) * lunge
		velocity.z = cos(rotation.y) * lunge
	else:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	if not attack_hit_done and attack_t >= float(data["hit"]):
		attack_hit_done = true
		_resolve_hit(data)
	if attack_t >= float(data["total"]):
		state = "idle"
		if queued_attack != "":
			var q := queued_attack
			queued_attack = ""
			begin_attack(q)
		elif queued_roll:
			queued_roll = false
			start_roll(_wish_direction_safe())
		else:
			_set_locomotion()


func _resolve_hit(data: Dictionary) -> void:
	var center := global_position + Vector3(0, 1.0, 0)
	var forward := Vector3(sin(rotation.y), 0, cos(rotation.y))
	var range: float = float(data["range"])
	var arc_dot: float = float(data["arc"])
	var hits_any := false
	var candidates := _live_enemies()
	for enemy in candidates:
		if enemy == null or not is_instance_valid(enemy):
			continue
		var to_enemy: Vector3 = enemy.global_position - global_position
		to_enemy.y = 0.0
		var dist := to_enemy.length()
		if dist > range + 0.35:
			continue
		if dist > 0.01:
			var dot := forward.dot(to_enemy.normalized())
			if dot < arc_dot:
				continue
		hits_any = true
		hits_landed += 1
		var kb: float = float(data["knockback"])
		enemy.take_hit(int(data["damage"]), to_enemy.normalized(), kb,
			bool(data["heavy"]), bool(data["knockdown"]), "player")
		qi = minf(MAX_QI, qi + float(data["qi"]))
		last_attack_target = enemy
		attack_landed.emit(attack_kind, int(data["damage"]), bool(data["heavy"]),
			bool(data["knockdown"]), enemy.global_position + Vector3(0, 1.35, 0))
		if data["knockdown"]:
			knockdowns_done += 1
		if attack_kind == "lampbreak":
			pass
	if not hits_any:
		attack_whiffed.emit(center + forward * range * 0.6, forward,
			bool(data["heavy"]))
	if qi >= MAX_QI and not _qi_was_full:
		_qi_was_full = true
		qi_full.emit()
	elif qi < MAX_QI:
		_qi_was_full = false


func _live_enemies() -> Array:
	if main == null:
		return []
	return main.live_enemies()


var knockdowns_done := 0
var lamp_breaks_done := 0


func try_lamp_break() -> bool:
	if qi < MAX_QI or state in ["attack", "roll", "knockdown", "hit", "victory", "dead"]:
		return false
	qi = 0.0
	_qi_was_full = false
	attack_kind = "lampbreak"
	attack_t = 0.0
	attack_hit_done = false
	state = "attack"
	combo_step = 0
	combo_window = 0.0
	lamp_breaks_done += 1
	_face_attack_target()
	play_anim(ATTACKS["lampbreak"]["clip"], 0.1, ATTACKS["lampbreak"]["speed"])
	lamp_break_cast.emit(global_position)
	return true


func _face_attack_target() -> void:
	if main == null:
		return
	var target: Node3D = null
	if main.lock_target != null and is_instance_valid(main.lock_target) and not main.lock_target.is_dead:
		target = main.lock_target
	else:
		target = main.nearest_enemy_in_front(global_position, 3.0, 0.35)
	if target != null:
		var d: Vector3 = target.global_position - global_position
		d.y = 0.0
		if d.length_squared() > 0.01:
			rotation.y = atan2(d.x, d.z)


# ── roll ────────────────────────────────────────────────────────────────────

func _request_roll() -> void:
	if state == "attack":
		var d: Dictionary = ATTACKS[attack_kind]
		if attack_hit_done and attack_t >= float(d["hit"]) + 0.06:
			queued_roll = true
		return
	if state in ["roll", "knockdown", "hit", "victory", "dead"]:
		return
	start_roll(_wish_direction_safe())


func start_roll(dir: Vector3) -> bool:
	if roll_cooldown > 0.0 or state in ["knockdown", "hit", "victory", "dead"] or dead:
		return false
	state = "roll"
	roll_t = 0.0
	roll_dir = dir.normalized() if dir.length_squared() > 0.01 else Vector3(sin(rotation.y), 0, cos(rotation.y))
	rotation.y = atan2(roll_dir.x, roll_dir.z)
	play_anim("Dodge_Forward", 0.06, 0.9)
	queued_attack = ""
	combo_step = 0
	combo_window = 0.0
	roll_ring.visible = true
	roll_ring.scale = Vector3(1, 1, 1) * 0.6
	roll_ring.transparency = 0.0
	return true


func _process_roll(delta: float) -> void:
	roll_t += delta
	var speed := ROLL_SPEED
	if roll_t > ROLL_TIME - 0.10:
		speed *= 0.45
	velocity.x = roll_dir.x * speed
	velocity.z = roll_dir.z * speed
	if roll_ring != null and roll_ring.visible:
		var k := clampf(roll_t / ROLL_TIME, 0.0, 1.0)
		roll_ring.scale = Vector3.ONE * (0.6 + 1.1 * k)
		roll_ring.transparency = k
	if roll_t >= ROLL_TIME:
		state = "idle"
		roll_cooldown = ROLL_COOLDOWN
		if roll_ring != null:
			roll_ring.visible = false
		_set_locomotion()


func invulnerable() -> bool:
	if iframe_debug:
		return true
	if state == "roll" and roll_t >= ROLL_IFRAME_START and roll_t <= ROLL_IFRAME_END:
		return true
	if state == "getup" and getup_t < 0.5:
		return true
	return false


func i_frame_window_active() -> bool:
	return state == "roll" and roll_t >= ROLL_IFRAME_START and roll_t <= ROLL_IFRAME_END


func _wish_direction_safe() -> Vector3:
	var w := _wish_direction()
	if demo_axis.length_squared() > 0.01:
		w = demo_axis.normalized()
	return w


# ── damage / knockdown ──────────────────────────────────────────────────────

func take_damage(amount: int, from: Vector3 = Vector3.ZERO, knockdown := false) -> bool:
	if dead or state == "victory" or invulnerable():
		return false
	hp = maxi(0, hp - amount)
	_hurt_t = 0.25
	hurt.emit(amount)
	if main != null:
		main.on_player_hurt(amount)
	if hp <= 0:
		dead = true
		state = "dead"
		play_anim("Death_A", 0.08, 1.0)
		died.emit()
		return true
	var away := global_position - from
	away.y = 0.0
	if away.length_squared() > 0.01:
		away = away.normalized()
		velocity = away * 2.8
	else:
		velocity = Vector3.ZERO
	if knockdown:
		_begin_knockdown()
	else:
		state = "hit"
		hit_stun = 0.38
		play_anim("Hit_A", 0.06, 1.8)
		combo_step = 0
		combo_window = 0.0
	return true


func _begin_knockdown() -> void:
	state = "knockdown"
	knockdown_phase = "down"
	knockdown_t = 0.0
	play_anim("Lie_Down", 0.08, 4.0)
	combo_step = 0
	combo_window = 0.0


func _process_knockdown(delta: float) -> void:
	knockdown_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if knockdown_phase == "down" and knockdown_t >= 1.0:
		knockdown_phase = "lie"
		knockdown_t = 0.0
		play_anim("Lie_Idle", 0.15, 1.0)
	elif knockdown_phase == "lie" and knockdown_t >= 0.18:
		knockdown_phase = "getup"
		knockdown_t = 0.0
		getup_t = 0.0
		state = "getup"
		play_anim("Lie_StandUp", 0.15, 2.9)
	elif knockdown_phase == "getdown":
		pass


func _process_getup(delta: float) -> void:
	getup_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)


func play_victory() -> void:
	state = "victory"
	combo_step = 0
	combo_window = 0.0
	velocity = Vector3.ZERO
	play_anim("Cheer", 0.2, 1.2)


func _set_locomotion() -> void:
	state = "idle"
	play_anim("Unarmed_Idle" if anim != null and anim.has_animation("Unarmed_Idle") else "Idle", 0.2)


# ── misc ────────────────────────────────────────────────────────────────────

func play_anim(clip: String, blend := 0.15, speed := 1.0) -> void:
	if anim == null:
		return
	if not anim.has_animation(clip):
		return
	anim.play(clip, blend, speed)
	anim.speed_scale = 1.0


func aim_at(world_pos: Vector3) -> void:
	var d := world_pos - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		rotation.y = atan2(d.x, d.z)


func set_demo_move(dir: Vector3) -> void:
	demo_axis = dir
	if dir == Vector3.ZERO:
		demo_axis = Vector3.ZERO


func is_busy() -> bool:
	return state in ["attack", "roll", "knockdown", "getup", "hit", "victory", "dead"]


func is_dead() -> bool:
	return dead


func has_attack_window() -> bool:
	return state not in ["roll", "knockdown", "getup", "hit", "victory", "dead"] and roll_cooldown <= 0.0


func reset_state(spawn: Vector3, facing: float) -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	rotation.y = facing
	hp = MAX_HP
	qi = 0.0
	dead = false
	state = "idle"
	attack_kind = ""
	attack_t = 0.0
	attack_hit_done = false
	combo_step = 0
	combo_window = 0.0
	roll_t = 0.0
	roll_cooldown = 0.0
	knockdown_t = 0.0
	knockdown_phase = ""
	getup_t = 0.0
	hit_stun = 0.0
	frozen = false
	if roll_ring != null:
		roll_ring.visible = false
	if anim != null:
		anim.speed_scale = 1.0
	play_anim("Unarmed_Idle" if anim != null and anim.has_animation("Unarmed_Idle") else "Idle", 0.15)


func reset_encounter_state(spawn: Vector3, facing: float) -> void:
	reset_state(spawn, facing)


func _update_lamp_light(_delta: float) -> void:
	if _lamp_glow != null:
		var s := 0.95 + 0.08 * sin(Time.get_ticks_msec() * 0.006)
		_lamp_glow.scale = Vector3.ONE * s


func _process(_delta: float) -> void:
	if main != null and main.game_state != "playing":
		demo_axis = Vector3.ZERO


func freeze_anim(v: bool) -> void:
	if anim != null:
		anim.speed_scale = 0.0 if v else 1.0
