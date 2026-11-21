class_name FogPlayer
extends CharacterBody2D
## 拾荒者：WASD 移动、鼠标瞄准、左键射击、R 换弹、Shift 冲刺、E 由 main 处理交互。
## 命中判定为 hitscan（世界层 1 + 敌人层 4），带曳光与命中反馈。

signal fired(from: Vector2, to: Vector2, hit_enemy: bool)
signal died
signal hurt(amount: int)
signal notify(text: String, color: Color)
signal dash_started

const SPEED := 218.0
const DASH_SPEED := 570.0
const DASH_TIME := 0.16
const DASH_COOLDOWN := 1.05
const MAG_SIZE := 12
const START_RESERVE := 96
const RELOAD_TIME := 1.35
const FIRE_INTERVAL := 0.14

var max_hp := 100.0
var hp := 100.0
var weapon_damage := 18
var mag := MAG_SIZE
var reserve := START_RESERVE
var reloading := false
var reload_timer := 0.0
var fire_cooldown := 0.0
var dash_cooldown := 0.0
var dash_timer := 0.0
var invuln := 0.0
var control_enabled := true
var dead := false
var aim := Vector2.RIGHT
var aim_override: Variant = null
var demo_god := false

var _dash_dir := Vector2.ZERO
var _shift_down := false
var _r_down := false
var _flash := 0.0
var _muzzle := 0.0
var _walk_time := 0.0
var _dash_trail: Array = []


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	z_index = 2
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)
	queue_redraw()


func _physics_process(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	_flash = maxf(0.0, _flash - delta)
	_muzzle = maxf(0.0, _muzzle - delta)
	_tick_dash_trail(delta)
	if reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			_finish_reload()

	if dead or not control_enabled:
		velocity = Vector2.ZERO
		_tick_walk(delta, Vector2.ZERO)
		queue_redraw()
		return

	_update_aim()
	_handle_reload_input()
	_handle_dash_input(delta)

	if fire_cooldown <= 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire()

	if dash_timer > 0.0:
		dash_timer -= delta
		velocity = _dash_dir * DASH_SPEED
		if int(Time.get_ticks_msec() / 26) % 2 == 0:
			_dash_trail.append({"pos": global_position, "t": 0.22})
	else:
		var dir := _move_input()
		velocity = dir * SPEED
		_tick_walk(delta, dir)
	move_and_slide()
	queue_redraw()


func _process(delta: float) -> void:
	# 冲刺残影衰减
	for i in range(_dash_trail.size() - 1, -1, -1):
		_dash_trail[i]["t"] = float(_dash_trail[i]["t"]) - delta
		if float(_dash_trail[i]["t"]) <= 0.0:
			_dash_trail.remove_at(i)
	queue_redraw()


func _move_input() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.y += 1.0
	return dir.normalized()


func _update_aim() -> void:
	var target: Vector2
	if aim_override != null:
		target = aim_override
	else:
		target = get_global_mouse_position()
	var delta := target - global_position
	if delta.length() > 2.0:
		aim = delta.normalized()


func _handle_reload_input() -> void:
	var down := Input.is_physical_key_pressed(KEY_R)
	if down and not _r_down:
		start_reload()
	_r_down = down


func _handle_dash_input(_delta: float) -> void:
	var down := Input.is_physical_key_pressed(KEY_SHIFT)
	if down and not _shift_down and dash_cooldown <= 0.0:
		var dir := _move_input()
		if dir == Vector2.ZERO:
			dir = aim
		_dash_dir = dir.normalized()
		dash_timer = DASH_TIME
		dash_cooldown = DASH_COOLDOWN
		invuln = maxf(invuln, 0.2)
		dash_started.emit()
	_shift_down = down


func _tick_walk(delta: float, dir: Vector2) -> void:
	if dir.length() > 0.1:
		_walk_time += delta
	else:
		_walk_time = 0.0


func _tick_dash_trail(delta: float) -> void:
	for i in range(_dash_trail.size() - 1, -1, -1):
		_dash_trail[i]["t"] = float(_dash_trail[i]["t"]) - delta * 0.4
		if float(_dash_trail[i]["t"]) <= 0.0:
			_dash_trail.remove_at(i)


func start_reload() -> void:
	if reloading or dead or mag >= MAG_SIZE or reserve <= 0:
		return
	reloading = true
	reload_timer = RELOAD_TIME
	notify.emit("换弹中…", Color("e9b35c"))


func _finish_reload() -> void:
	reloading = false
	var need := MAG_SIZE - mag
	var taken := mini(need, reserve)
	mag += taken
	reserve -= taken
	notify.emit("换弹完成 %d/%d" % [mag, MAG_SIZE], Color("78d39a"))


func _try_fire() -> void:
	if reloading:
		return
	if mag <= 0:
		if reserve > 0:
			start_reload()
		else:
			notify.emit("弹药耗尽", Color("df655b"))
		return
	mag -= 1
	fire_cooldown = FIRE_INTERVAL
	_muzzle = 0.05
	_shoot_ray()


func _shoot_ray() -> Vector2:
	var from := global_position + aim * 20.0
	var to := from + aim * 980.0
	var query := PhysicsRayQueryParameters2D.create(from, to, 1 | 4)
	query.collide_with_areas = false
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		fired.emit(from, to, false)
		return to
	var collider = hit.get("collider")
	var point: Vector2 = hit["position"]
	if collider != null and collider.has_method("take_damage"):
		collider.take_damage(weapon_damage, aim)
		fired.emit(from, point, true)
	else:
		fired.emit(from, point, false)
	return point


func take_damage(amount: int, from_dir := Vector2.RIGHT) -> bool:
	if dead or invuln > 0.0 or demo_god:
		return false
	hp = maxf(0.0, hp - float(amount))
	invuln = 0.35
	_flash = 0.18
	hurt.emit(amount)
	queue_redraw()
	if hp <= 0.0:
		dead = true
		control_enabled = false
		velocity = Vector2.ZERO
		died.emit()
		return true
	# 轻微击退
	global_position += from_dir.normalized() * 3.0
	return true


func heal(amount: int) -> int:
	var before := hp
	hp = minf(max_hp, hp + float(amount))
	queue_redraw()
	return int(hp - before)


func ammo_text() -> String:
	return "%02d / %03d" % [mag, reserve]


func demo_fire_at(point: Vector2) -> void:
	aim_override = point
	aim = (point - global_position).normalized()
	if mag <= 0:
		mag = MAG_SIZE
	_muzzle = 0.05
	fire_cooldown = 0.0
	_shoot_ray()
	mag = maxi(0, mag)
	queue_redraw()


func demo_aim_at(point: Vector2) -> void:
	aim_override = point
	aim = (point - global_position).normalized()
	queue_redraw()


func demo_clear_aim() -> void:
	aim_override = null


func _draw() -> void:
	for ghost in _dash_trail:
		var t := clampf(float(ghost["t"]) / 0.22, 0.0, 1.0)
		draw_circle(to_local(ghost["pos"]), 9.0, Color(0.36, 0.8, 0.76, 0.18 * t), true)
	# 影子
	_ellipse(Vector2(0, 8), 13.0, 6.0, Color(0, 0, 0, 0.42))
	var body_color := Color("315e61")
	if _flash > 0.0:
		body_color = Color("d9f2ea")
	if invuln > 0.0 and not dead and int(Time.get_ticks_msec() / 70) % 2 == 0:
		body_color = body_color.lightened(0.2)
	# 腿
	var stride := sin(_walk_time * 11.0) * 4.0
	var side := Vector2(-aim.y, aim.x)
	draw_circle(-side * 4.5 + aim * stride, 4.2, Color("1c2d31"), true)
	draw_circle(side * 4.5 - aim * stride, 4.2, Color("1c2d31"), true)
	# 背包（背对瞄准方向）
	draw_rect(Rect2(-aim * 10.0 - side * 8.0, Vector2(16, 16)), Color("4a3f2e"), true)
	draw_rect(Rect2(-aim * 10.0 - side * 8.0, Vector2(16, 16)), Color("7d6a45"), false, 1.2)
	# 躯干与头
	draw_circle(Vector2.ZERO, 11.5, body_color, true)
	draw_circle(Vector2.ZERO, 11.5, Color(0, 0, 0, 0.35), false, 1.5)
	draw_arc(Vector2.ZERO, 12.0, aim.angle() - 1.4, aim.angle() + 1.4, 12, Color(0.58, 0.92, 0.85, 0.85), 1.5)
	draw_circle(aim * 3.0, 6.4, Color("d8b58e"), true)
	draw_circle(aim * 3.0, 6.4, Color("2c2320"), false, 1.0)
	# 橙色围巾
	draw_arc(Vector2.ZERO, 9.0, aim.angle() + 1.9, aim.angle() + 4.4, 10, Color("d9834e"), 3.0)
	# 枪
	draw_set_transform(Vector2.ZERO, aim.angle())
	draw_rect(Rect2(7, -2.2, 19, 4.4), Color("20272a"), true)
	draw_rect(Rect2(15, -1.0, 11, 2.0), Color("6e7c7c"), true)
	draw_rect(Rect2(9, 2.0, 5, 4.5), Color("3d4a4a"), true)
	if _muzzle > 0.0:
		var pts := PackedVector2Array([
			Vector2(27, 0), Vector2(34, -5), Vector2(32, 0), Vector2(34, 5),
		])
		draw_colored_polygon(pts, Color(1.0, 0.82, 0.4, 0.9))
	_reset_draw_transform()
	if reloading:
		var ratio := 1.0 - reload_timer / RELOAD_TIME
		draw_arc(Vector2(0, -24), 11.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 22, Color("e9b35c"), 2.5)


func _reset_draw_transform() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(18):
		var a := TAU * float(i) / 18.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)
