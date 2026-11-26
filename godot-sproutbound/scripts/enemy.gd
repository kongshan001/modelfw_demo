extends CharacterBody3D
class_name SproutEnemy

## 菌怪 AI：idle / patrol / alert / chase / windup / strike / recover / hurt / dead。
## 三种原创变体：菌仔（近战）、孢囊菇（远程）、菌卫（精英 AoE 拍地）。
## 低模菌菇、颜色与 UI 均原创；不复刻参考视频的紫色发光眼造型。

signal died(enemy)
signal attack_landed(pos: Vector3, heavy: bool)

const STATE_CN := {
	"idle": "待机", "patrol": "巡逻", "alert": "警觉", "chase": "追击",
	"windup": "前摇", "strike": "出招", "recover": "硬直", "hurt": "受击",
	"dead": "消散", "return": "回巢",
}

const STATE_COLORS := {
	"idle": Color(0.72, 0.82, 0.68),
	"patrol": Color(0.66, 0.80, 0.62),
	"alert": Color(1.0, 0.82, 0.35),
	"chase": Color(1.0, 0.62, 0.3),
	"windup": Color(1.0, 0.35, 0.26),
	"strike": Color(1.0, 0.24, 0.18),
	"recover": Color(0.8, 0.72, 0.5),
	"hurt": Color(0.9, 0.55, 0.55),
	"dead": Color(0.5, 0.5, 0.5),
	"return": Color(0.6, 0.75, 0.8),
}

const KIND_DEFS := {
	"cap": {
		"name": "菌仔", "hp": 42, "speed": 2.55, "detect": 8.2, "attack_range": 1.95,
		"windup": 0.52, "strike": 0.18, "recover": 0.78, "damage": 12,
		"cooldown": 0.5, "knockback": 0.5, "radius": 0.5, "scale": 1.0,
		"leash": 21.0, "patrol_radius": 3.4, "ranged": false, "aoe": 0.0,
		"cap": Color(0.87, 0.41, 0.33), "cap_dark": Color(0.67, 0.28, 0.23),
		"stem": Color(0.95, 0.89, 0.76), "spot": Color(0.99, 0.93, 0.78),
		"eye": Color(1.0, 0.72, 0.30),
	},
	"spitter": {
		"name": "孢囊菇", "hp": 30, "speed": 2.05, "detect": 10.5, "attack_range": 9.2,
		"windup": 0.82, "strike": 0.2, "recover": 1.05, "damage": 10,
		"cooldown": 1.5, "knockback": 0.25, "radius": 0.5, "scale": 1.05,
		"leash": 23.0, "patrol_radius": 2.8, "ranged": true, "aoe": 0.0,
		"prefer_min": 5.4, "prefer_max": 9.0,
		"cap": Color(0.29, 0.60, 0.54), "cap_dark": Color(0.20, 0.45, 0.41),
		"stem": Color(0.83, 0.90, 0.79), "spot": Color(0.73, 0.97, 0.78),
		"eye": Color(0.82, 1.0, 0.72),
	},
	"warden": {
		"name": "菌卫", "hp": 108, "speed": 1.8, "detect": 9.0, "attack_range": 2.75,
		"windup": 0.92, "strike": 0.24, "recover": 1.05, "damage": 24,
		"cooldown": 1.25, "knockback": 0.95, "radius": 0.85, "scale": 1.55,
		"leash": 23.0, "patrol_radius": 2.2, "ranged": false, "aoe": 2.95,
		"cap": Color(0.47, 0.46, 0.36), "cap_dark": Color(0.32, 0.32, 0.26),
		"stem": Color(0.88, 0.83, 0.70), "spot": Color(0.56, 0.69, 0.40),
		"eye": Color(1.0, 0.58, 0.24),
	},
}

var main: Node
var kind := "cap"
var def: Dictionary
var display_name := "菌仔"
var max_hp := 42
var hp := 42
var speed := 2.5
var detect_range := 8.2
var attack_range := 1.95
var windup_time := 0.52
var strike_time := 0.18
var recover_time := 0.78
var damage := 12
var cooldown_time := 0.5
var hit_radius := 0.5
var body_scale := 1.0
var leash := 21.0

var state := "idle"
var active := false
var aggro := false
var dead := false
var spawn_pos := Vector3.ZERO
var home_yaw := 0.0
var state_t := 0.0
var cooldown := 0.0
var hit_flash := 0.0
var attack_done := false
var debug_view := false

var model: Node3D
var body: Node3D
var cap_pivot: Node3D
var arm_l: Node3D
var arm_r: Node3D
var foot_l: MeshInstance3D
var foot_r: MeshInstance3D
var charge_orb: MeshInstance3D
var telegraph_ring: MeshInstance3D
var telegraph_mat: StandardMaterial3D
var debug_detect_ring: MeshInstance3D
var debug_attack_ring: MeshInstance3D
var debug_label: Label3D
var alert_label: Label3D
var debug_capsule: MeshInstance3D

var _mats: Array[StandardMaterial3D] = []
var _eye_mats: Array[StandardMaterial3D] = []
var _eye_base: Array[float] = []
var _facing_yaw := 0.0
var _t := 0.0
var _anim_phase := 0.0
var _idle_t := 0.0
var _patrol_wait := 0.0
var _patrol_target := Vector3.ZERO
var _patrol_has := false
var _los_timer := 0.0
var _los_ok := false
var _spawn_t := 0.0
var _death_t := 0.0
var _death_emitted := false
var _knock := Vector3.ZERO
var _debug_acc := 0.0


func setup(kind_name: String, main_ref: Node, pos: Vector3) -> void:
	kind = kind_name
	main = main_ref
	def = KIND_DEFS[kind]
	display_name = String(def.name)
	max_hp = int(def.hp)
	hp = max_hp
	speed = float(def.speed)
	detect_range = float(def.detect)
	attack_range = float(def.attack_range)
	windup_time = float(def.windup)
	strike_time = float(def.strike)
	recover_time = float(def.recover)
	damage = int(def.damage)
	cooldown_time = float(def.cooldown)
	hit_radius = float(def.radius)
	body_scale = float(def.scale)
	leash = float(def.leash)
	spawn_pos = pos
	position = pos
	home_yaw = PI


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	var cap := CapsuleShape3D.new()
	cap.radius = hit_radius
	cap.height = 1.1 * body_scale
	var col := CollisionShape3D.new()
	col.shape = cap
	col.position.y = 0.55 * body_scale
	add_child(col)
	_build_model()
	_build_telegraphs()
	_build_labels()
	_build_debug_capsule()
	_set_state("idle")
	_spawn_t = 0.0
	model.scale = Vector3.ONE * 0.01
	rotation.y = home_yaw
	_facing_yaw = home_yaw


# ---------------------------------------------------------------------- AI

func _physics_process(delta: float) -> void:
	_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	hit_flash = maxf(0.0, hit_flash - delta * 6.5)
	_spawn_t = minf(1.0, _spawn_t + delta * 3.0)
	_apply_flash()
	if debug_view and not dead:
		_debug_acc += delta
		if _debug_acc >= 0.25:
			_debug_acc = 0.0
			_update_debug_label()

	if dead:
		_update_dead(delta)
		return

	if not active:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		velocity.y -= 24.0 * delta
		move_and_slide()
		_animate(delta)
		return

	state_t += delta
	var player = main.player if main != null else null
	if player == null or player.dead:
		_think_idle(delta)
		_apply_gravity(delta)
		move_and_slide()
		_animate(delta)
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = 0.18
		_los_ok = _has_line_of_sight(player)

	match state:
		"idle":
			_idle_t -= delta
			if dist <= detect_range and _los_ok:
				_alert()
			elif _idle_t <= 0.0:
				_pick_patrol_point()
				_set_state("patrol")
			_decel(delta)
		"patrol":
			if dist <= detect_range and _los_ok:
				_alert()
			else:
				_update_patrol(delta)
		"alert":
			_stop_and_face(to_player, delta, 10.0)
			if state_t >= 0.42:
				aggro = true
				alert_label.visible = false
				_set_state("chase")
		"chase":
			if not _los_ok and dist > detect_range + 3.0:
				_set_state("return")
			elif dist > leash:
				_set_state("return")
			else:
				_update_chase(player, dist, to_player, delta)
		"windup":
			_stop_and_face(to_player, delta, 12.0)
			_show_telegraph(state_t / windup_time)
			if state_t >= windup_time:
				_strike(player)
		"strike":
			_update_strike(delta)
		"recover":
			_decel(delta)
			if state_t >= recover_time:
				_set_state("chase" if aggro else "idle")
		"hurt":
			_update_hurt(delta)
		"return":
			_update_return(delta, player)
		_:
			_set_state("idle")

	_apply_gravity(delta)
	move_and_slide()
	_separate()
	_animate(delta)


func _think_idle(delta: float) -> void:
	if state != "idle":
		_set_state("idle")
	_idle_t -= delta
	_decel(delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0


func _update_chase(player, dist: float, to_player: Vector3, delta: float) -> void:
	if bool(def.ranged):
		var prefer_min: float = def.prefer_min
		var prefer_max: float = def.prefer_max
		if dist > prefer_max:
			_move_toward(player.global_position, speed, delta)
		elif dist < prefer_min:
			_move_toward(global_position - to_player.normalized() * 2.0, speed * 0.9, delta)
		else:
			_decel(delta)
			_face(to_player, delta, 8.0)
		if dist <= attack_range and _los_ok and cooldown <= 0.0:
			_begin_windup()
	else:
		if dist > attack_range * 0.92:
			_move_toward(player.global_position, speed, delta)
		else:
			_decel(delta)
			_face(to_player, delta, 12.0)
			if cooldown <= 0.0:
				_begin_windup()


func _update_patrol(delta: float) -> void:
	if not _patrol_has:
		_pick_patrol_point()
	var dist := Vector2(global_position.x - _patrol_target.x,
		global_position.z - _patrol_target.z).length()
	if dist < 0.55 or state_t > 6.0:
		_patrol_has = false
		_patrol_wait = _randf_range(0.9, 2.4)
		_set_state("idle")
		_idle_t = _patrol_wait
	else:
		_move_toward(_patrol_target, speed * 0.42, delta)


func _pick_patrol_point() -> void:
	var radius: float = def.patrol_radius * _randf_range(0.4, 1.0)
	var a := _randf_range(0.0, TAU)
	var p := spawn_pos + Vector3(sin(a) * radius, 0.0, cos(a) * radius)
	if main != null and main.world != null:
		p.y = main.world.ground_y(p.x, p.z) + 0.05
	_patrol_target = p
	_patrol_has = true


func _update_return(delta: float, player) -> void:
	_patrol_has = false
	var dist_home := Vector2(global_position.x - spawn_pos.x,
		global_position.z - spawn_pos.z).length()
	if dist_home < 1.2:
		aggro = false
		hp = maxi(hp, int(max_hp * 0.5))
		_set_state("idle")
		_idle_t = 2.0
		return
	_move_toward(spawn_pos, speed * 0.85, delta)
	if player != null and not player.dead:
		var d: Vector3 = player.global_position - global_position
		d.y = 0.0
		if d.length() <= detect_range * 0.6 and _los_ok:
			aggro = true
			_set_state("chase")


func _alert() -> void:
	_set_state("alert")
	alert_label.visible = true
	alert_label.scale = Vector3.ONE * 0.2
	alert_label.modulate = Color(1.0, 0.80, 0.32, 1.0)
	var tw := create_tween()
	tw.tween_property(alert_label, "scale", Vector3.ONE * 1.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if main != null:
		main.spawn_alert_ping(global_position)


func _begin_windup() -> void:
	_set_state("windup")
	attack_done = false
	velocity.x = 0.0
	velocity.z = 0.0
	# 远程不画巨大的“攻击范围”圈，用口中充能球作前摇提示。
	telegraph_ring.visible = not bool(def.ranged)
	charge_orb.visible = bool(def.ranged)
	charge_orb.scale = Vector3.ONE * 0.05


func _show_telegraph(k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	var pulse := 0.72 + 0.28 * sin(_t * 18.0)
	telegraph_mat.albedo_color = Color(1.0, 0.45 + 0.25 * k, 0.22, 0.32 + 0.4 * k * pulse)
	telegraph_ring.scale = Vector3.ONE * (1.0 + 0.04 * sin(_t * 10.0))
	for m in _eye_mats:
		m.emission_energy_multiplier = 2.2 + k * 2.6
	if bool(def.ranged):
		charge_orb.scale = Vector3.ONE * (0.12 + k * 0.6)


func _strike(player) -> void:
	_set_state("strike")
	attack_done = true
	telegraph_ring.visible = false
	charge_orb.visible = false
	for m in _eye_mats:
		m.emission_energy_multiplier = 2.0
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if bool(def.ranged):
		var mouth := global_position + Vector3(0.0, 1.0 * body_scale, 0.0) \
			+ facing_dir() * (0.5 * body_scale)
		var aim: Vector3 = (player.global_position + Vector3(0.0, 0.9, 0.0) - mouth).normalized()
		if main != null:
			main.spawn_enemy_bolt(self, mouth, aim, damage)
		velocity.x = -facing_dir().x * 0.6
		velocity.z = -facing_dir().z * 0.6
	else:
		var vertical: float = player.global_position.y - global_position.y
		var arc_ok := facing_dir().dot(to_player.normalized()) > -0.15
		var reach := attack_range + 0.55
		if vertical > 1.05:
			arc_ok = false
		if float(def.aoe) > 0.0:
			reach = float(def.aoe)
			arc_ok = true
			if main != null:
				main.spawn_shockwave(global_position + Vector3(0.0, 0.06, 0.0),
					float(def.aoe), Color(0.96, 0.76, 0.42))
		if dist <= reach and arc_ok:
			var hit: bool = player.take_damage(damage,
				global_position + facing_dir() * 0.3, float(def.knockback),
				int(def.aoe) > 0)
			if hit:
				attack_landed.emit(global_position, int(def.aoe) > 0)
		var lunge := 2.6 if float(def.aoe) == 0.0 else 1.4
		velocity.x = facing_dir().x * lunge
		velocity.z = facing_dir().z * lunge


func _update_strike(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	if state_t >= strike_time:
		cooldown = cooldown_time
		_set_state("recover")


func _update_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	if state_t >= 0.32:
		_set_state("chase")
		aggro = true


func _update_dead(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y -= 24.0 * delta
	move_and_slide()
	_death_t += delta
	var k := clampf(_death_t / 0.9, 0.0, 1.0)
	model.scale = Vector3(body_scale * (1.0 + 0.18 * k),
		body_scale * (1.0 - 0.9 * k), body_scale * (1.0 + 0.18 * k))
	model.rotation.z = k * 0.7
	if _death_t > 1.05:
		queue_free()


func _set_state(new_state: String) -> void:
	state = new_state
	state_t = 0.0
	telegraph_ring.visible = false if new_state != "windup" else telegraph_ring.visible
	charge_orb.visible = false
	alert_label.visible = new_state == "alert"


# ------------------------------------------------------------------ damage

func take_damage(amount: int, from_pos: Vector3, knockback: float = 0.4,
		heavy: bool = false) -> bool:
	if dead:
		return false
	hp -= amount
	hit_flash = 1.0
	aggro = true
	var d := global_position - from_pos
	d.y = 0.0
	if d.length_squared() < 0.001:
		d = Vector3.FORWARD
	d = d.normalized()
	if state in ["idle", "patrol", "alert", "return"]:
		_set_state("chase")
	var stagger := true
	if kind == "warden" and not heavy:
		stagger = false
	if not stagger:
		velocity.x = d.x * 0.9
		velocity.z = d.z * 0.9
	elif not heavy:
		_set_state("hurt")
		velocity.x = d.x * (2.2 + knockback * 4.0)
		velocity.z = d.z * (2.0 + knockback * 4.0)
	elif float(def.aoe) > 0.0:
		velocity.x = d.x * 0.8
		velocity.z = d.z * 0.8
	else:
		_set_state("hurt")
		velocity.x = d.x * 4.2
		velocity.z = d.z * 4.2
	if hp <= 0:
		_die()
	return true


func _die() -> void:
	if dead:
		return
	dead = true
	hp = 0
	state = "dead"
	state_t = 0.0
	_death_t = 0.0
	telegraph_ring.visible = false
	charge_orb.visible = false
	alert_label.visible = false
	debug_label.visible = false
	debug_detect_ring.visible = false
	debug_attack_ring.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity.x *= 0.3
	velocity.z *= 0.3
	if not _death_emitted:
		_death_emitted = true
		died.emit(self)
	if main != null:
		main.spawn_spore_burst(global_position + Vector3(0.0, 0.7, 0.0),
			def.cap, 16)


func is_alive() -> bool:
	return not dead and hp > 0


func facing_dir() -> Vector3:
	return Vector3(-sin(_facing_yaw), 0.0, -cos(_facing_yaw))


func aim_at(pos: Vector3) -> void:
	var d: Vector3 = pos - global_position
	d.y = 0.0
	if d.length_squared() > 0.001:
		_facing_yaw = atan2(-d.x, -d.z)
		rotation.y = _facing_yaw


func force_hurt(amount: int, from_pos: Vector3) -> void:
	take_damage(amount, from_pos, 0.2, false)


func demo_set_state(state_name: String) -> void:
	if state_name == "windup":
		_begin_windup()
	elif state_name == "strike":
		_set_state("strike")
		attack_done = true
	elif state_name in STATE_COLORS:
		_set_state(state_name)
	if state_name == "alert":
		alert_label.visible = true


func set_debug(v: bool) -> void:
	debug_view = v
	debug_label.visible = v and not dead
	debug_detect_ring.visible = false
	debug_attack_ring.visible = v and not dead
	debug_capsule.visible = v and not dead
	if v:
		_update_debug_label()


# ------------------------------------------------------------------- motion

func _move_toward(target: Vector3, spd: float, delta: float) -> void:
	var d: Vector3 = target - global_position
	d.y = 0.0
	if d.length_squared() < 0.0001:
		_decel(delta)
		return
	d = d.normalized()
	var target_v := d * spd
	velocity.x = move_toward(velocity.x, target_v.x, 16.0 * delta)
	velocity.z = move_toward(velocity.z, target_v.z, 16.0 * delta)
	_face(d, delta, 8.0)


func _stop_and_face(to_player: Vector3, delta: float, turn_speed: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	if to_player.length_squared() > 0.001:
		_face(to_player.normalized(), delta, turn_speed)


func _decel(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)


func _face(dir: Vector3, delta: float, turn_speed: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	var diff := wrapf(target_yaw - _facing_yaw, -PI, PI)
	_facing_yaw += clampf(diff, -turn_speed * delta, turn_speed * delta)
	rotation.y = _facing_yaw


func _separate() -> void:
	if main == null:
		return
	for other in main.enemies:
		if other == self or not is_instance_valid(other) or not other.is_alive():
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var dist := d.length()
		var min_dist: float = (hit_radius + other.hit_radius) * 0.8
		if dist > 0.001 and dist < min_dist:
			var push := (min_dist - dist) * 0.6
			global_position += d.normalized() * push


func _has_line_of_sight(player) -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 0.95 * body_scale, 0.0)
	var to: Vector3 = player.global_position + Vector3(0.0, 0.9, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := space.intersect_ray(query)
	return hit.is_empty()


func _randf_range(a: float, b: float) -> float:
	return randf_range(a, b)


# -------------------------------------------------------------------- model

func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	model.scale = Vector3.ONE * body_scale
	add_child(model)
	body = Node3D.new()
	model.add_child(body)

	var stem_mat := SproutStyle.mat(def.stem, 0.92)
	var cap_mat := SproutStyle.mat(def.cap, 0.9)
	var cap_dark_mat := SproutStyle.mat(def.cap_dark, 0.92)
	var spot_mat := SproutStyle.mat(def.spot, 0.75,
		def.spot, 0.35 if kind == "spitter" else 0.0)
	var eye_mat := SproutStyle.mat(def.eye, 0.4, def.eye, 2.2)
	var dark_mat := SproutStyle.mat(Color(0.12, 0.14, 0.12), 0.9)
	_mats = [stem_mat, cap_mat, cap_dark_mat]
	_eye_mats = [eye_mat]
	_eye_base = [2.2]

	var stem_h := 0.62 if kind != "spitter" else 0.76
	var stem_r := 0.33 if kind != "warden" else 0.4
	var stem := MeshInstance3D.new()
	stem.mesh = SproutStyle.low_cylinder(stem_r * 0.72, stem_r, stem_h, 8)
	stem.material_override = stem_mat
	stem.position = Vector3(0.0, stem_h * 0.5 + 0.02, 0.0)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(stem)

	# 脚
	var foot_mesh := BoxMesh.new()
	foot_mesh.size = Vector3(0.18, 0.11, 0.27)
	foot_l = MeshInstance3D.new()
	foot_l.mesh = foot_mesh
	foot_l.material_override = cap_dark_mat
	foot_l.position = Vector3(-0.17, 0.055, -0.05)
	body.add_child(foot_l)
	foot_r = MeshInstance3D.new()
	foot_r.mesh = foot_mesh
	foot_r.material_override = cap_dark_mat
	foot_r.position = Vector3(0.17, 0.055, -0.05)
	body.add_child(foot_r)

	# 手臂
	for side in [-1.0, 1.0]:
		var arm_root := Node3D.new()
		arm_root.position = Vector3(0.34 * side, stem_h * 0.62, -0.06)
		body.add_child(arm_root)
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.055 if kind != "warden" else 0.09
		arm_mesh.height = 0.3 if kind != "warden" else 0.44
		arm.mesh = arm_mesh
		arm.material_override = stem_mat
		arm.position = Vector3(0.06 * side, -0.14, 0.0)
		arm.rotation.z = 0.35 * side
		arm_root.add_child(arm)
		var hand := MeshInstance3D.new()
		hand.mesh = SproutStyle.low_sphere(0.07 if kind != "warden" else 0.11, 6, 3)
		hand.material_override = stem_mat
		hand.position = Vector3(0.12 * side, -0.28, 0.0)
		arm_root.add_child(hand)
		if side < 0.0:
			arm_l = arm_root
		else:
			arm_r = arm_root
		if kind == "warden" and side > 0.0:
			var club := MeshInstance3D.new()
			club.mesh = SproutStyle.low_sphere(0.24, 5, 3)
			club.material_override = SproutStyle.mat(SproutStyle.STONE, 0.95)
			club.position = Vector3(0.2, -0.34, 0.0)
			club.scale = Vector3(1.0, 1.25, 1.0)
			arm_root.add_child(club)

	cap_pivot = Node3D.new()
	cap_pivot.position = Vector3(0.0, stem_h + 0.0, 0.0)
	body.add_child(cap_pivot)

	if kind == "spitter":
		var funnel := MeshInstance3D.new()
		funnel.mesh = SproutStyle.low_cylinder(0.16, 0.6, 0.42, 9)
		funnel.material_override = cap_mat
		funnel.position = Vector3(0.0, 0.08, 0.0)
		funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cap_pivot.add_child(funnel)
		var rim := MeshInstance3D.new()
		var rim_mesh := TorusMesh.new()
		rim_mesh.inner_radius = 0.5
		rim_mesh.outer_radius = 0.61
		rim_mesh.rings = 16
		rim_mesh.ring_segments = 4
		rim.mesh = rim_mesh
		rim.material_override = cap_dark_mat
		rim.position = Vector3(0.0, -0.11, 0.0)
		cap_pivot.add_child(rim)
		var snout := MeshInstance3D.new()
		var snout_mesh := SproutStyle.low_cylinder(0.1, 0.17, 0.42, 7)
		snout.mesh = snout_mesh
		snout.material_override = cap_mat
		snout.rotation.x = PI / 2.0
		snout.position = Vector3(0.0, 0.02, -0.42)
		cap_pivot.add_child(snout)
		var snout_hole := MeshInstance3D.new()
		snout_hole.mesh = SproutStyle.low_sphere(0.1, 6, 3)
		snout_hole.material_override = dark_mat
		snout_hole.position = Vector3(0.0, 0.02, -0.64)
		cap_pivot.add_child(snout_hole)
		for i in 5:
			var a := float(i) * TAU / 5.0
			var sac := MeshInstance3D.new()
			sac.mesh = SproutStyle.low_sphere(0.11, 6, 3)
			sac.material_override = spot_mat
			sac.position = Vector3(sin(a) * 0.48, -0.02, cos(a) * 0.48)
			cap_pivot.add_child(sac)
	else:
		var cap_r := 0.62 if kind != "warden" else 0.78
		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = cap_r
		cap_mesh.height = cap_r * 1.35
		cap_mesh.radial_segments = 9
		cap_mesh.rings = 5
		cap.mesh = cap_mesh
		cap.material_override = cap_mat
		cap.position = Vector3(0.0, 0.11, 0.0)
		cap.scale = Vector3(1.12, 0.66, 1.12)
		cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		cap_pivot.add_child(cap)
		if kind == "warden":
			var warden_stone := SproutStyle.mat(Color(0.64, 0.62, 0.52), 0.98)
			for i in 4:
				var a := float(i) * TAU / 4.0 + 0.5
				var plate := MeshInstance3D.new()
				var plate_mesh := BoxMesh.new()
				plate_mesh.size = Vector3(0.5, 0.2, 0.42)
				plate.mesh = plate_mesh
				plate.material_override = warden_stone
				plate.position = Vector3(sin(a) * 0.52, 0.3, cos(a) * 0.52)
				plate.rotation.y = a
				plate.rotation.z = 0.3
				cap_pivot.add_child(plate)
			var stone_rim := MeshInstance3D.new()
			var srim := TorusMesh.new()
			srim.inner_radius = 0.66
			srim.outer_radius = 0.78
			srim.rings = 18
			srim.ring_segments = 4
			stone_rim.mesh = srim
			stone_rim.material_override = warden_stone
			stone_rim.position = Vector3(0.0, -0.06, 0.0)
			stone_rim.scale = Vector3(1.05, 0.6, 1.05)
			cap_pivot.add_child(stone_rim)
			for i in 3:
				var moss := MeshInstance3D.new()
				moss.mesh = SproutStyle.low_sphere(0.17, 5, 2)
				moss.material_override = SproutStyle.mat(Color(0.44, 0.61, 0.34), 0.95)
				moss.position = Vector3(-0.25 + i * 0.25, 0.34, -0.1)
				moss.scale = Vector3(1.0, 0.35, 0.8)
				cap_pivot.add_child(moss)
		# 菌盖斑点
		for i in 5:
			var a := float(i) * TAU / 5.0 + 0.3
			var spot := MeshInstance3D.new()
			spot.mesh = SproutStyle.low_sphere(0.1 if kind != "warden" else 0.14, 6, 3)
			spot.material_override = spot_mat
			spot.position = Vector3(sin(a) * cap_r * 0.62, 0.24 + 0.08 * cos(a * 2.0),
				cos(a) * cap_r * 0.62)
			spot.scale = Vector3(1.0, 0.35, 1.0)
			cap_pivot.add_child(spot)

	# 眼睛（长在菌柄上部，正面 -Z）
	var eye_z := -0.265 if kind != "spitter" else -0.24
	var eye_y := stem_h * 0.78
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = SproutStyle.low_sphere(0.062, 7, 4)
		eye.material_override = eye_mat
		eye.position = Vector3(0.13 * side, eye_y, eye_z)
		body.add_child(eye)
		var brow := MeshInstance3D.new()
		var brow_mesh := BoxMesh.new()
		brow_mesh.size = Vector3(0.13, 0.035, 0.05)
		brow.mesh = brow_mesh
		brow.material_override = cap_dark_mat
		brow.position = Vector3(0.14 * side, eye_y + 0.09, eye_z - 0.015)
		brow.rotation.z = -0.3 * side
		body.add_child(brow)

	charge_orb = MeshInstance3D.new()
	charge_orb.mesh = SproutStyle.low_sphere(0.12, 7, 4)
	var orb_mat := SproutStyle.mat(Color(0.72, 1.0, 0.78), 0.3,
		Color(0.7, 1.0, 0.8), 3.0)
	charge_orb.material_override = orb_mat
	charge_orb.position = Vector3(0.0, 0.94, -0.52)
	charge_orb.visible = false
	charge_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(charge_orb)

	var blob := MeshInstance3D.new()
	var blob_mesh := SproutStyle.low_cylinder(0.5, 0.5, 0.01, 16)
	blob.mesh = blob_mesh
	blob.material_override = SproutStyle.unshaded(Color(0.04, 0.08, 0.04, 0.28))
	blob.position = Vector3(0.0, 0.018, 0.0)
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(blob)
	model.scale = Vector3.ONE * 0.01


func _build_telegraphs() -> void:
	telegraph_mat = SproutStyle.unshaded(Color(1.0, 0.5, 0.25, 0.55), true)
	telegraph_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 28
	torus.ring_segments = 4
	telegraph_ring.mesh = torus
	telegraph_ring.material_override = telegraph_mat
	var radius := float(def.aoe) if float(def.aoe) > 0.0 else attack_range
	telegraph_ring.scale = Vector3.ONE * radius
	telegraph_ring.position = Vector3(0.0, 0.08, 0.0)
	telegraph_ring.visible = false
	telegraph_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(telegraph_ring)

	var dbg_attack_mat := SproutStyle.unshaded(Color(1.0, 0.3, 0.2, 0.36), true)
	debug_attack_ring = MeshInstance3D.new()
	var torus2 := TorusMesh.new()
	torus2.inner_radius = 0.985
	torus2.outer_radius = 1.0
	torus2.rings = 26
	torus2.ring_segments = 4
	debug_attack_ring.mesh = torus2
	debug_attack_ring.material_override = dbg_attack_mat
	debug_attack_ring.scale = Vector3.ONE * radius
	debug_attack_ring.position = Vector3(0.0, 0.1, 0.0)
	debug_attack_ring.visible = false
	add_child(debug_attack_ring)

	var dbg_detect_mat := SproutStyle.unshaded(Color(0.35, 0.85, 1.0, 0.15), true)
	debug_detect_ring = MeshInstance3D.new()
	var torus3 := TorusMesh.new()
	torus3.inner_radius = 0.992
	torus3.outer_radius = 1.0
	torus3.rings = 40
	torus3.ring_segments = 4
	debug_detect_ring.mesh = torus3
	debug_detect_ring.material_override = dbg_detect_mat
	debug_detect_ring.scale = Vector3.ONE * detect_range
	debug_detect_ring.position = Vector3(0.0, 0.06, 0.0)
	debug_detect_ring.visible = false
	add_child(debug_detect_ring)


func _build_debug_capsule() -> void:
	debug_capsule = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = hit_radius
	mesh.height = 1.1 * body_scale
	debug_capsule.mesh = mesh
	var mat := SproutStyle.mat(Color(0.35, 0.9, 1.0, 0.18), 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	debug_capsule.material_override = mat
	debug_capsule.position = Vector3(0.0, 0.55 * body_scale, 0.0)
	debug_capsule.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	debug_capsule.visible = false
	add_child(debug_capsule)


func _build_labels() -> void:
	var font := SproutStyle.cjk()
	alert_label = Label3D.new()
	alert_label.text = "!"
	alert_label.font = font
	alert_label.font_size = 96
	alert_label.pixel_size = 0.005
	alert_label.modulate = Color(1.0, 0.8, 0.32)
	alert_label.outline_size = 18
	alert_label.outline_modulate = Color(0.16, 0.12, 0.04)
	alert_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert_label.no_depth_test = true
	alert_label.position = Vector3(0.0, 1.75 * body_scale, 0.0)
	alert_label.visible = false
	add_child(alert_label)

	debug_label = Label3D.new()
	debug_label.font = font
	debug_label.font_size = 34
	debug_label.pixel_size = 0.0032
	debug_label.modulate = Color(0.92, 1.0, 0.9)
	debug_label.outline_size = 10
	debug_label.outline_modulate = Color(0.02, 0.06, 0.03, 0.9)
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_label.no_depth_test = true
	debug_label.position = Vector3(0.0, 2.0 * body_scale, 0.0)
	debug_label.visible = false
	add_child(debug_label)


func _update_debug_label() -> void:
	if debug_label == null:
		return
	var dist := 0.0
	if main != null and main.player != null:
		dist = global_position.distance_to(main.player.global_position)
	var new_text := "%s [%s]\nHP %d/%d · %.1fm · %s" % [
		display_name, STATE_CN.get(state, state), maxi(hp, 0), max_hp, dist,
		"远程" if bool(def.ranged) else ("范围" if float(def.aoe) > 0.0 else "近战")]
	if debug_label.text != new_text:
		debug_label.text = new_text
	var col: Color = STATE_COLORS.get(state, Color.WHITE)
	debug_label.modulate = col


func _apply_flash() -> void:
	var flash := hit_flash
	for m in _mats:
		if flash > 0.0:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.86, 0.58)
			m.emission_energy_multiplier = flash * 0.62
		else:
			m.emission_enabled = false
	if state != "windup":
		for i in _eye_mats.size():
			_eye_mats[i].emission_energy_multiplier = _eye_base[i]


# ------------------------------------------------------------------- visual

func _animate(delta: float) -> void:
	if dead:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	var moving := spd > 0.25 and state in ["patrol", "chase", "return"]
	if moving:
		_anim_phase += delta * (7.0 + spd * 1.4)
	else:
		_anim_phase += delta * 1.6

	body.position.y = absf(sin(_anim_phase)) * (0.045 if moving else 0.012)
	body.rotation.z = sin(_anim_phase) * 0.055 if moving else sin(_t * 1.3) * 0.02
	body.rotation.x = 0.0
	cap_pivot.rotation.z = -sin(_anim_phase) * 0.09 if moving else sin(_t * 1.1) * 0.03
	cap_pivot.rotation.x = 0.0
	foot_l.position.z = -0.05 + (sin(_anim_phase) * 0.09 if moving else 0.0)
	foot_r.position.z = -0.05 - (sin(_anim_phase) * 0.09 if moving else 0.0)

	var arm_rest := 0.0
	match state:
		"alert":
			arm_l.rotation.z = 0.35 + sin(_t * 16.0) * 0.12
			arm_r.rotation.z = -0.35 - sin(_t * 16.0) * 0.12
			cap_pivot.rotation.x = -0.08
		"windup":
			var k := clampf(state_t / windup_time, 0.0, 1.0)
			body.rotation.x = 0.16 * k
			cap_pivot.rotation.x = 0.22 * k
			arm_l.rotation.z = 0.35 + 0.9 * k
			arm_r.rotation.z = -0.35 - 0.9 * k
		"strike":
			var k2 := clampf(state_t / strike_time, 0.0, 1.0)
			body.rotation.x = -0.28 * (1.0 - k2)
			arm_l.rotation.z = 1.2 * (1.0 - k2)
			arm_r.rotation.z = -1.2 * (1.0 - k2)
		"hurt":
			var k3 := clampf(state_t / 0.32, 0.0, 1.0)
			body.scale = Vector3(1.0 + 0.16 * (1.0 - k3), 0.86 + 0.14 * k3,
				1.0 + 0.16 * (1.0 - k3))
			body.rotation.x = 0.2 * (1.0 - k3)
		_:
			body.scale = body.scale.lerp(Vector3.ONE, 1.0 - exp(-14.0 * delta))
			arm_l.rotation.z = lerpf(arm_l.rotation.z, arm_rest, 1.0 - exp(-10.0 * delta))
			arm_r.rotation.z = lerpf(arm_r.rotation.z, -arm_rest, 1.0 - exp(-10.0 * delta))

	if _spawn_t < 1.0 and not dead:
		var pop := ease(_spawn_t, 0.3)
		model.scale = Vector3.ONE * body_scale * (0.3 + 0.7 * pop) * Vector3(
			1.0 + 0.15 * (1.0 - pop), 1.0, 1.0 + 0.15 * (1.0 - pop))
	else:
		model.scale = Vector3.ONE * body_scale


