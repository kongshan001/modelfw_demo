class_name FogEnemy
extends CharacterBody2D
## 三种敌人：潜伏者（近战）、雾港枪手（远程）、港区看守（精英/三连发）。
## FSM：PATROL → ALERT → CHASE → ATTACK → STAGGER → DEAD。
## 视野受雾限制：有效侦测半径 = 基础半径 × 0.85，并要求墙体视线通畅。

signal shoot_requested(from: Vector2, dir: Vector2, damage: int, speed: float, color: Color)
signal killed(enemy: FogEnemy)
signal melee_hit(pos: Vector2, dir: Vector2)

enum State { PATROL, ALERT, CHASE, ATTACK, STAGGER, DEAD }

const FOG_VISION_FACTOR := 0.85

const DEFS := {
	"lurker": {
		"name": "潜伏者", "hp": 55, "speed": 122.0, "detect": 250.0,
		"range": 48.0, "preferred": 30.0, "damage": 14, "windup": 0.48,
		"cooldown": 1.05, "ranged": false, "burst": 0, "projectile_speed": 0.0,
		"radius": 13.0, "knockback": 140.0, "color": Color("5e7d63"),
	},
	"gunner": {
		"name": "雾港枪手", "hp": 70, "speed": 96.0, "detect": 340.0,
		"range": 390.0, "preferred": 245.0, "damage": 9, "windup": 0.62,
		"cooldown": 1.65, "ranged": true, "burst": 1, "projectile_speed": 600.0,
		"radius": 13.0, "knockback": 135.0, "color": Color("4a6478"),
	},
	"elite": {
		"name": "港区看守", "hp": 170, "speed": 104.0, "detect": 420.0,
		"range": 380.0, "preferred": 230.0, "damage": 8, "windup": 0.55,
		"cooldown": 2.15, "ranged": true, "burst": 3, "burst_gap": 0.12,
		"projectile_speed": 660.0, "radius": 17.0, "knockback": 95.0,
		"melee_damage": 18, "melee_range": 56.0, "color": Color("7b4d46"),
	},
}

var archetype := "lurker"
var data: Dictionary = {}
var hp := 55
var max_hp := 55
var state: int = State.PATROL
var state_timer := 0.0
var attack_cd := 0.4
var player: Node2D = null
var fx: Node2D = null
var home := Vector2.ZERO
var patrol_points: Array = []
var patrol_index := 0
var patrol_wait := 0.0
var last_seen := Vector2.ZERO
var lost_timer := 0.0
var aim := Vector2.RIGHT
var flash := 0.0
var muzzle := 0.0
var dead := false
var attack_mode := "ranged"
var burst_left := 0
var burst_timer := 0.0
var _stuck_timer := 0.0
var _avoid_timer := 0.0
var _avoid_sign := 1.0
var _rng := RandomNumberGenerator.new()
var _alert_show := 0.0


func configure(kind: String, spawn_pos: Vector2, patrol_offsets: Array, player_node: Node2D, fx_node: Node2D) -> void:
	archetype = kind if DEFS.has(kind) else "lurker"
	data = DEFS[archetype]
	home = spawn_pos
	global_position = spawn_pos
	player = player_node
	fx = fx_node
	hp = int(data["hp"])
	max_hp = hp
	patrol_points.clear()
	for offset in patrol_offsets:
		patrol_points.append(spawn_pos + offset)
	_rng.seed = int(spawn_pos.x * 13.0 + spawn_pos.y * 7.0 + 41.0)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = float(data.get("radius", 13.0))
	shape.shape = circle
	add_child(shape)
	last_seen = global_position
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		velocity = Vector2.ZERO
		return
	state_timer = maxf(0.0, state_timer - delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	flash = maxf(0.0, flash - delta)
	muzzle = maxf(0.0, muzzle - delta)
	_alert_show = maxf(0.0, _alert_show - delta)
	_avoid_timer = maxf(0.0, _avoid_timer - delta)

	var visible := _can_see_player()
	var distance := _player_distance()
	if visible:
		last_seen = player.global_position
		lost_timer = 0.0
	else:
		lost_timer += delta

	match state:
		State.PATROL:
			_patrol(delta, visible, distance)
		State.ALERT:
			_alert(delta, visible)
		State.CHASE:
			_chase(delta, visible, distance)
		State.ATTACK:
			_attack(delta, visible, distance)
		State.STAGGER:
			_stagger(delta)
	queue_redraw()


func _patrol(delta: float, visible: bool, distance: float) -> void:
	if visible and distance <= _detect_range():
		_enter_alert()
		return
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if patrol_wait > 0.0:
		patrol_wait -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var target: Vector2 = patrol_points[patrol_index]
	if global_position.distance_to(target) < 18.0:
		patrol_wait = 1.1 + float(patrol_index % 2) * 0.5
		patrol_index = (patrol_index + 1) % patrol_points.size()
		velocity = Vector2.ZERO
		move_and_slide()
		return
	_steer_towards(target, float(data["speed"]) * 0.46, delta)


func _enter_alert() -> void:
	state = State.ALERT
	state_timer = 0.38
	_alert_show = 0.8
	velocity = Vector2.ZERO
	if fx != null and fx.has_method("float_text"):
		fx.float_text(global_position + Vector2(0, -32), "!", Color("e9b35c"))


func _alert(delta: float, visible: bool) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if player != null:
		aim = (player.global_position - global_position).normalized()
	if state_timer <= 0.0:
		if visible or _player_distance() <= _detect_range() * 1.35:
			state = State.CHASE
		else:
			state = State.PATROL
			patrol_wait = 0.4


func _chase(delta: float, visible: bool, distance: float) -> void:
	if lost_timer > 3.4:
		state = State.PATROL
		patrol_wait = 0.5
		return
	if player == null:
		return
	aim = (player.global_position - global_position).normalized()
	var ranged: bool = bool(data["ranged"])
	var melee_range := float(data.get("melee_range", 0.0))
	if visible and attack_cd <= 0.0:
		if ranged and melee_range > 0.0 and distance <= melee_range:
			_start_attack("melee")
			return
		if ranged and distance <= float(data["range"]):
			_start_attack("ranged")
			return
		if not ranged and distance <= float(data["range"]):
			_start_attack("melee")
			return
	var target := last_seen if not visible else player.global_position
	if ranged:
		var preferred := float(data["preferred"])
		if distance < preferred * 0.62 and visible:
			var away := (global_position - player.global_position).normalized()
			_steer_direction(away.rotated(0.28 * _avoid_sign), float(data["speed"]) * 0.9, delta)
		elif distance > preferred * 1.05 or not visible:
			_steer_towards(target, float(data["speed"]), delta)
		else:
			# 环绕，避免站桩对射
			var strafe := aim.rotated(PI * 0.5 * _avoid_sign)
			_steer_direction(strafe, float(data["speed"]) * 0.42, delta)
	else:
		_steer_towards(target, float(data["speed"]), delta)
	if visible and distance < 90.0 and not bool(data["ranged"]):
		_avoid_sign = -_avoid_sign


func _start_attack(mode: String) -> void:
	state = State.ATTACK
	attack_mode = mode
	state_timer = float(data["windup"])
	attack_cd = float(data["cooldown"]) + float(data["windup"])
	velocity = Vector2.ZERO
	burst_left = 0
	burst_timer = 0.0


func _attack(delta: float, visible: bool, distance: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()
	if player != null:
		aim = (player.global_position - global_position).normalized()
	if state_timer <= 0.0:
		if attack_mode == "melee":
			_do_melee(distance)
			state = State.CHASE
		elif burst_left <= 0 and burst_timer <= 0.0:
			burst_left = int(data.get("burst", 1))
			burst_timer = 0.0
	if attack_mode == "ranged" and burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			_fire_one()
			burst_left -= 1
			burst_timer = float(data.get("burst_gap", 0.16))
			if burst_left <= 0:
				state = State.CHASE
	if not visible and state == State.ATTACK and state_timer <= 0.0 and attack_mode == "melee":
		state = State.CHASE


func _do_melee(distance: float) -> void:
	if player == null:
		return
	var reach := float(data["range"]) + 12.0
	if distance <= reach and _has_los():
		player.take_damage(int(data["damage"]), aim)
		melee_hit.emit(global_position + aim * 22.0, aim)
		muzzle = 0.12
		if fx != null and fx.has_method("slash"):
			fx.slash(global_position + aim * 20.0, aim.angle(), Color("df655b"))


func _fire_one() -> void:
	if player == null:
		return
	var spread := _rng.randf_range(-0.055, 0.055)
	var dir := aim.rotated(spread)
	var from := global_position + aim * (float(data["radius"]) + 7.0)
	muzzle = 0.07
	shoot_requested.emit(from, dir, int(data["damage"]), float(data["projectile_speed"]), Color("f0a35c"))


func _stagger(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if state_timer <= 0.0:
		state = State.CHASE if _can_see_player() else State.PATROL


func take_damage(amount: int, from_dir := Vector2.RIGHT) -> void:
	if dead:
		return
	hp -= amount
	flash = 0.13
	state = State.STAGGER
	state_timer = 0.17
	velocity = from_dir.normalized() * float(data["knockback"])
	if fx != null:
		if fx.has_method("float_text"):
			fx.float_text(global_position + Vector2(0, -28), str(amount), Color("f0c66c"))
		if fx.has_method("spark"):
			fx.spark(global_position + Vector2(0, -4), Color("e9b35c"), 5)
	if hp <= 0:
		_die()


func _die() -> void:
	dead = true
	state = State.DEAD
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	z_index = 1
	killed.emit(self)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.18)
	tween.tween_callback(queue_free)
	if fx != null and fx.has_method("ring"):
		fx.ring(global_position, Color("df655b"), 30.0)


func _can_see_player() -> bool:
	if player == null or not is_instance_valid(player) or bool(player.get("dead")):
		return false
	if global_position.distance_to(player.global_position) > _detect_range():
		return false
	return _has_los()


func _has_los() -> bool:
	if player == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty()


func _detect_range() -> float:
	return float(data["detect"]) * FOG_VISION_FACTOR


func _player_distance() -> float:
	if player == null or not is_instance_valid(player):
		return 99999.0
	return global_position.distance_to(player.global_position)


func _steer_towards(target: Vector2, speed: float, _delta: float) -> void:
	var dir := (target - global_position).normalized()
	_steer_direction(dir, speed, _delta)


func _steer_direction(dir: Vector2, speed: float, delta: float) -> void:
	if _avoid_timer > 0.0:
		dir = dir.rotated(0.85 * _avoid_sign)
	velocity = dir * speed
	move_and_slide()
	if get_slide_collision_count() > 0:
		_stuck_timer += delta
		if _stuck_timer > 0.18:
			_avoid_timer = 0.5
			_avoid_sign = -_avoid_sign
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0


func state_name() -> String:
	match state:
		State.PATROL:
			return "PATROL"
		State.ALERT:
			return "ALERT"
		State.CHASE:
			return "CHASE"
		State.ATTACK:
			return "ATTACK"
		State.STAGGER:
			return "STAGGER"
		_:
			return "DEAD"


func demo_force_attack(mode := "ranged") -> void:
	state = State.ATTACK
	attack_mode = mode
	state_timer = 0.0
	attack_cd = 99.0


func demo_alert() -> void:
	state = State.CHASE
	state_timer = 0.0
	lost_timer = 0.0
	attack_cd = 0.0
	_alert_show = 0.8


func demo_show_telegraph(mode := "ranged") -> void:
	state = State.ATTACK
	attack_mode = mode
	state_timer = 1.2
	attack_cd = 0.0
	burst_left = 0
	burst_timer = 0.0


func _draw() -> void:
	var radius := float(data.get("radius", 13.0))
	_ellipse(Vector2(0, radius * 0.55), radius * 1.25, radius * 0.5, Color(0, 0, 0, 0.4))
	if state != State.PATROL and not dead:
		draw_circle(Vector2.ZERO, radius + 9.0, Color(0.85, 0.25, 0.2, 0.07), true)
	var body_color: Color = data["color"]
	if flash > 0.0:
		body_color = Color("f2f0e4")
	if archetype == "lurker":
		_draw_lurker(radius, body_color)
	elif archetype == "elite":
		_draw_elite(radius, body_color)
	else:
		_draw_gunner(radius, body_color)
	if dead:
		draw_line(Vector2(-radius, -radius * 0.2), Vector2(radius, radius * 0.25), Color(0.4, 0.1, 0.1, 0.8), 2.0)
		return
	if hp < max_hp:
		var bar := Rect2(Vector2(-19, -radius - 16), Vector2(38, 4))
		draw_rect(bar, Color(0.04, 0.06, 0.06, 0.85), true)
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(hp) / float(max_hp), 0.0, 1.0), 4)), Color("df655b"), true)
	if state == State.ALERT or _alert_show > 0.0:
		FogUITheme.draw_text(self, Vector2(-3, -radius - 21), "!", 18, Color("e9b35c"), true)
	if state == State.ATTACK and state_timer > 0.0:
		if attack_mode == "ranged":
			draw_line(aim * (radius + 2), aim * 190.0, Color(0.95, 0.35, 0.25, 0.16), 1.5)
			draw_circle(aim * (radius + 8), 3.0, Color(1.0, 0.55, 0.35, 0.85), true)
		else:
			draw_arc(Vector2.ZERO, radius + 16.0, aim.angle() - 0.7, aim.angle() + 0.7, 12, Color(0.95, 0.35, 0.25, 0.35), 2.5)


func _draw_lurker(radius: float, color: Color) -> void:
	draw_circle(Vector2.ZERO, radius, color, true)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.2), radius * 0.4, color.lightened(0.12), true)
	draw_line(Vector2(-radius * 0.7, radius * 0.45), Vector2(-radius * 1.3, radius * 0.8), Color("2d3b30"), 2.5)
	draw_line(Vector2(radius * 0.7, radius * 0.45), Vector2(radius * 1.3, radius * 0.8), Color("2d3b30"), 2.5)
	draw_circle(aim * radius * 0.62 - Vector2(0, 2), 2.0, Color("e4614e"), true)
	draw_circle(aim * radius * 0.62 + Vector2(0, 2), 2.0, Color("e4614e"), true)


func _draw_gunner(radius: float, color: Color) -> void:
	draw_circle(Vector2.ZERO, radius, color, true)
	draw_circle(Vector2.ZERO, radius * 0.55, color.lightened(0.13), true)
	draw_set_transform(Vector2.ZERO, aim.angle())
	draw_rect(Rect2(radius * 0.4, -1.6, radius * 1.35, 3.2), Color("1d2528"), true)
	draw_rect(Rect2(radius * 1.15, -0.8, radius * 0.8, 1.6), Color("8e9b99"), true)
	if muzzle > 0.0:
		draw_circle(Vector2(radius * 1.9, 0), 4.0, Color(1.0, 0.75, 0.4, 0.9), true)
	_reset_transform()
	draw_circle(aim * radius * 0.45, 2.2, Color("d7dfd9"), true)


func _draw_elite(radius: float, color: Color) -> void:
	draw_circle(Vector2.ZERO, radius, color, true)
	draw_arc(Vector2.ZERO, radius * 0.82, -2.4, 2.4, 18, color.lightened(0.25), 3.0)
	draw_rect(Rect2(-radius * 0.55, -radius * 0.55, radius * 1.1, radius * 0.35), Color("3a2a27"), true)
	draw_set_transform(Vector2.ZERO, aim.angle())
	draw_rect(Rect2(radius * 0.35, -2.2, radius * 1.5, 4.4), Color("1b2021"), true)
	draw_rect(Rect2(radius * 1.25, -1.1, radius * 0.9, 2.2), Color("b07a4f"), true)
	if muzzle > 0.0:
		draw_circle(Vector2(radius * 2.1, 0), 5.0, Color(1.0, 0.65, 0.3, 0.95), true)
	_reset_transform()
	draw_circle(aim * radius * 0.5, 2.6, Color("f0b24d"), true)


func _reset_transform() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)
