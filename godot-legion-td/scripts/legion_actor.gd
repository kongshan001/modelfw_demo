class_name LegionActor
extends Node3D

# RTS 单位 / 英雄 / 敌人共用的轻量 AI：
# 玩家侧支持单选、框选、移动、攻击、攻击移动、停止与自动索敌；
# 敌人侧沿三线石道推进，遇到阻挡/射程内目标先交战，抵达核心后攻击核心。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")

enum State { IDLE, MOVE, ATTACK, DEAD }

var game: Node
var kind := "guard"
var team := 0
var is_enemy := false
var is_hero := false
var lane := 0

var hp := 1.0
var max_hp := 1.0
var damage := 1.0
var attack_range := 1.0
var attack_interval := 1.0
var move_speed := 1.0
var aggro_range := 1.0
var radius := 0.5
var height := 1.8
var gold_reward := 0
var essence_reward := 0
var splash := 0.0

var state: State = State.IDLE
var attack_cd := 0.0
var skill_cd := 0.0
var slow_t := 0.0
var slow_pct := 0.0
var selected := false
var dead := false

var has_move := false
var move_target := Vector3.ZERO
var attack_move := false
var attack_anchor := Vector3.ZERO
var target: LegionActor = null
var target_core := false
var path: Array = []
var path_index := 0

var model: Node3D
var rig: Dictionary = {}
var selection_ring: Node3D
var slow_ring: Node3D
var hp_root: Node3D
var hp_fill: MeshInstance3D
var hp_fill_pivot: Node3D
var _hp_bg: MeshInstance3D

var anim_t := 0.0
var facing := 0.0
var death_t := 0.0
var atk_anim := 0.0
var hit_flash := 0.0
var _moving := false
var _last_pos := Vector3.ZERO
var _base_model_y := 0.0
var _body_base_y := 0.82
var _speed_base := 1.0
var _dmg_base := 1.0
var _idle_anchor := Vector3.ZERO
var _scan_t := 0.0
var _attack_target_core := false
var _rng := RandomNumberGenerator.new()


func setup(p_game: Node, p_kind: String, p_team: int, p_lane: int = 0,
		hp_mult: float = 1.0, dmg_mult: float = 1.0, speed_mult: float = 1.0) -> void:
	game = p_game
	kind = p_kind
	team = p_team
	is_enemy = p_team == D.TEAM_ENEMY
	lane = p_lane
	_rng.seed = hash(str(p_kind)) + p_lane * 977 + 31
	var def: Dictionary = D.enemy_def(p_kind) if is_enemy else D.unit_def(p_kind)
	var hp_scale := hp_mult if is_enemy else float(game.stats.get("unit_hp", 1.0))
	max_hp = float(def.hp) * hp_scale
	hp = max_hp
	damage = float(def.damage) * (dmg_mult if is_enemy else 1.0)
	attack_range = float(def.range)
	attack_interval = float(def.interval)
	move_speed = float(def.speed) * (speed_mult if is_enemy else 1.0)
	aggro_range = float(def.aggro)
	radius = float(def.radius)
	height = float(def.height)
	gold_reward = int(def.get("gold", 0))
	essence_reward = int(def.get("essence", 0))
	splash = float(def.get("splash", 0.0))
	if is_enemy:
		_speed_base = move_speed
		_dmg_base = damage
	else:
		is_hero = p_kind == "hero"
		_speed_base = float(def.speed)
		_dmg_base = float(def.damage)
		name = "Hero" if is_hero else ("Unit_" + p_kind)
		if is_hero:
			skill_cd = 0.0
	# 模型
	if is_enemy:
		rig = Art.build_enemy(kind)
	else:
		rig = Art.build_unit(kind)
	model = rig.root
	model.name = "Model"
	add_child(model)
	_base_model_y = model.position.y
	var body_node: Node3D = rig.get("body", null)
	if body_node != null:
		_body_base_y = body_node.position.y
	# 选中环 / 减速环 / 血条
	var ring_color := D.C_GOLD if is_hero else (D.C_BLOOD if is_enemy else D.C_TEAL)
	selection_ring = Art.build_selection_ring(radius + 0.34, ring_color)
	selection_ring.visible = false
	add_child(selection_ring)
	slow_ring = Art.build_selection_ring(radius + 0.16, D.C_ICE)
	slow_ring.visible = false
	add_child(slow_ring)
	_build_hp_bar()
	_idle_anchor = global_position
	_last_pos = global_position
	position.y = p_game.world.height_at(position.x, position.z)
	if is_enemy:
		path = p_game.world.lane_paths[lane]
		path_index = mini(1, path.size() - 1)
	set_process(false)


func _build_hp_bar() -> void:
	hp_root = Node3D.new()
	hp_root.position.y = height + 0.48
	add_child(hp_root)
	var bg_color := Color(0.03, 0.025, 0.04, 0.78)
	var fg := D.C_BLOOD if is_enemy else (D.C_GOLD if is_hero else D.C_TEAL)
	if is_enemy:
		fg = Color("#ff5f74") if not bool(D.enemy_def(kind).get("elite", false)) else Color("#c47bff")
	_hp_bg = _bar_quad(0.92, 0.105, bg_color)
	hp_root.add_child(_hp_bg)
	var fill := _bar_quad(0.84, 0.062, fg)
	hp_fill_pivot = Node3D.new()
	hp_fill_pivot.position.x = -0.42
	hp_root.add_child(hp_fill_pivot)
	fill.position.x = 0.42
	hp_fill_pivot.add_child(fill)
	hp_fill = fill
	hp_root.visible = is_enemy


func _bar_quad(w: float, h: float, color: Color) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Art.billboard_material(color, Art.white_texture(), false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ---------------------------------------------------------------- 指令

func command_move(p: Vector3) -> void:
	if dead:
		return
	target = null
	target_core = false
	has_move = true
	attack_move = false
	move_target = p
	state = State.MOVE
	attack_anchor = p


func command_attack(t: LegionActor) -> void:
	if dead or t == null or t.dead:
		return
	target = t
	has_move = false
	attack_move = false
	state = State.ATTACK
	attack_anchor = global_position


func command_attack_move(p: Vector3) -> void:
	if dead:
		return
	target = null
	target_core = false
	has_move = true
	attack_move = true
	move_target = p
	state = State.MOVE
	attack_anchor = p


func stop() -> void:
	if dead:
		return
	target = null
	target_core = false
	has_move = false
	attack_move = false
	state = State.IDLE
	_idle_anchor = global_position


func set_selected(v: bool) -> void:
	selected = v
	if selection_ring != null:
		selection_ring.visible = v
	_refresh_hp_visibility()


func apply_slow(pct: float, dur: float) -> void:
	if pct <= 0.0:
		return
	if pct >= slow_pct or slow_t < 0.25:
		slow_pct = pct
	slow_t = maxf(slow_t, dur)
	_refresh_hp_visibility()


func current_speed() -> float:
	var mul := 1.0 if slow_t <= 0.0 else (1.0 - slow_pct)
	if is_enemy:
		return move_speed * mul
	return _speed_base * game.stats.unit_speed * mul if game != null else _speed_base * mul


func current_damage() -> float:
	if is_enemy:
		return damage
	return _dmg_base * game.stats.unit_dmg if game != null else _dmg_base


func take_damage(amount: float, from_player: bool = true) -> void:
	if dead:
		return
	hp -= amount
	hit_flash = 0.12
	if hp_fill_pivot != null:
		var ratio := clampf(hp / max_hp, 0.0, 1.0)
		hp_fill_pivot.scale.x = maxf(ratio, 0.001)
	hp_root.visible = true
	if hp <= 0.0:
		die(from_player)


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	if hp_fill_pivot != null:
		hp_fill_pivot.scale.x = clampf(hp / max_hp, 0.001, 1.0)


func die(from_player: bool = true) -> void:
	if dead:
		return
	dead = true
	state = State.DEAD
	death_t = 0.0
	hp = 0.0
	selection_ring.visible = false
	slow_ring.visible = false
	hp_root.visible = false
	if game != null:
		game.on_actor_died(self, from_player)


func is_alive() -> bool:
	return not dead and hp > 0.0


# ---------------------------------------------------------------- 每帧

func tick(dt: float) -> void:
	if dead:
		_tick_death(dt)
		return
	if attack_cd > 0.0:
		attack_cd -= dt
	if skill_cd > 0.0:
		skill_cd -= dt
	if slow_t > 0.0:
		slow_t -= dt
		if slow_t <= 0.0:
			slow_pct = 0.0
	if hit_flash > 0.0:
		hit_flash -= dt
	if slow_ring != null:
		slow_ring.visible = slow_t > 0.0
		slow_ring.rotation.y += dt * 0.6
	if atk_anim > 0.0:
		atk_anim -= dt
	_moving = false
	if _validate_target():
		_tick_combat(dt)
	else:
		_scan_t -= dt
		if is_enemy:
			_tick_enemy(dt)
		else:
			_tick_player(dt)
	_tick_motion_after(dt)
	_animate(dt)
	_refresh_hp_visibility()


func _validate_target() -> bool:
	if target == null or not is_instance_valid(target):
		target = null
		return false
	if target.dead or target.hp <= 0.0:
		target = null
		return false
	return true


func _tick_combat(dt: float) -> void:
	var d := _flat_distance(global_position, target.global_position)
	if d > attack_range:
		_move_toward(target.global_position, dt)
		state = State.ATTACK
	else:
		_face(target.global_position)
		state = State.ATTACK
		if attack_cd <= 0.0:
			_attack_actor(target)


func _tick_player(dt: float) -> void:
	# 已有显式攻击目标由 _validate/_tick_combat 处理；其余为移动/攻击移动/待命。
	if has_move:
		var d := _flat_distance(global_position, move_target)
		if d <= 0.45:
			has_move = false
			state = State.IDLE
			_idle_anchor = global_position
			return
		if attack_move and _scan_t <= 0.0:
			_scan_t = 0.25
			var found: LegionActor = game.find_nearest_enemy(global_position, aggro_range, self)
			if found != null:
				target = found
				state = State.ATTACK
				return
		_move_toward(move_target, dt)
		state = State.MOVE
		return
	# 待命自动索敌；离锚点太远则拉回。
	if _scan_t <= 0.0:
		_scan_t = 0.3
		var found: LegionActor = game.find_nearest_enemy(global_position, aggro_range, self)
		if found != null:
			if _flat_distance(found.global_position, _idle_anchor) <= 15.0:
				target = found
				state = State.ATTACK
	state = State.IDLE


func _tick_enemy(dt: float) -> void:
	# 先找附近的玩家单位；没有就沿路线推进，最后攻击核心。
	if _scan_t <= 0.0:
		_scan_t = 0.25
		var found: LegionActor = game.find_nearest_player(global_position, aggro_range, self)
		if found != null:
			target = found
			_attack_target_core = false
			state = State.ATTACK
			return
	var core_pos: Vector3 = LegionWorld.CORE_POS
	var dcore := _flat_distance(global_position, core_pos)
	if dcore < attack_range + 2.4:
		_attack_target_core = true
		if attack_cd <= 0.0:
			_face(core_pos)
			attack_cd = attack_interval
			atk_anim = 0.32
			game.damage_core(damage * (1.0 + 0.06 * (game.wave_index - 1)))
			game.fx_impact(core_pos + Vector3(0, 1.4, 0), Color("#ff5f74"), 1.2)
		state = State.ATTACK
		return
	_attack_target_core = false
	if path.is_empty():
		target_core = true
		_move_toward(core_pos, dt)
		return
	while path_index < path.size() and _flat_distance(global_position, path[path_index]) < 1.4:
		path_index += 1
	if path_index >= path.size():
		if dcore > attack_range + 2.0:
			_move_toward(core_pos, dt)
		state = State.MOVE
		return
	var wp: Vector3 = path[path_index]
	_move_toward(wp, dt)
	state = State.MOVE


func _attack_actor(t: LegionActor) -> void:
	if t == null or t.dead:
		return
	attack_cd = attack_interval
	atk_anim = 0.34
	_face(t.global_position)
	var muzzle := global_position + Vector3(0, height * 0.62, 0)
	if is_enemy:
		if kind == "spitter":
			game.spawn_projectile("acid", muzzle, t, damage, D.TEAM_ENEMY, 0.0, 0.0, 0.0)
		elif kind == "colossus":
			game.fx_impact(t.global_position, Color("#ff8a55"), 1.5)
			game.shake(0.12)
			t.take_damage(damage, false)
		else:
			game.fx_slash(t.global_position + Vector3(0, 0.8, 0), Color("#c47bff"), 0.8)
			t.take_damage(damage, false)
	else:
		if is_hero:
			game.fx_slash(t.global_position + Vector3(0, 1.0, 0), Color("#ffd36a"), 1.2)
			t.take_damage(current_damage(), true)
		elif kind == "bolt":
			game.spawn_projectile("bolt", muzzle, t, current_damage(), D.TEAM_PLAYER, 0.0, 0.0, 0.0)
		elif kind == "adept":
			game.spawn_projectile("fire", muzzle, t, current_damage(), D.TEAM_PLAYER, splash, 0.0, 0.0)
		else:
			game.fx_slash(t.global_position + Vector3(0, 0.8, 0), Color("#7ff0d8"), 0.75)
			t.take_damage(current_damage(), true)


func _move_toward(p: Vector3, dt: float) -> void:
	var to := Vector3(p.x - global_position.x, 0, p.z - global_position.z)
	var d := to.length()
	if d < 0.001:
		return
	var dir := to / d
	var spd := current_speed()
	var step := minf(spd * dt, d)
	# 地形边界保护：不走进虚空/熔岩
	var next := global_position + dir * step
	var m: float = game.world.island_mask(next.x, next.z)
	if m < 0.12:
		return
	global_position = next
	position.y = maxf(0.0, game.world.height_at(position.x, position.z))
	_face(global_position - dir)
	_moving = true


func _face(toward: Vector3) -> void:
	var to := Vector3(toward.x - global_position.x, 0, toward.z - global_position.z)
	if to.length_squared() < 0.0001:
		return
	facing = atan2(to.x, to.z)
	rotation.y = facing


func _tick_motion_after(dt: float) -> void:
	pass


func _tick_death(dt: float) -> void:
	death_t += dt
	var t := clampf(death_t / 0.85, 0.0, 1.0)
	model.rotation_degrees.z = lerpf(0.0, -82.0, ease(t, 0.4))
	model.position.y = _base_model_y - 0.35 * t
	if hp_root != null:
		hp_root.visible = false


func _animate(dt: float) -> void:
	if rig.is_empty():
		return
	var spd := current_speed()
	anim_t += dt * (4.5 + spd * 0.7) * (1.0 if _moving else 0.55)
	var swing := 0.0
	if _moving:
		swing = sin(anim_t * 1.4) * 0.55
	else:
		swing = sin(anim_t * 0.4) * 0.04
	var legs: Array = rig.get("legs", [])
	if legs.size() >= 2:
		legs[0].rotation.x = swing
		legs[1].rotation.x = -swing
	elif legs.size() == 1:
		legs[0].rotation.x = swing * 0.5
	var arms: Array = rig.get("arms", [])
	var attack_pose := 0.0
	if atk_anim > 0.0:
		attack_pose = sin((1.0 - atk_anim / 0.34) * PI) * 1.1
	if arms.size() >= 2:
		arms[0].rotation.x = -swing * 0.6 - attack_pose * 0.15
		arms[1].rotation.x = swing * 0.6 - attack_pose
	elif arms.size() == 1:
		arms[0].rotation.x = -attack_pose
	var body: Node3D = rig.get("body", null)
	if body != null:
		if is_enemy and (kind == "crawler" or kind == "spitter"):
			body.position.y = _body_base_y + (0.025 * absf(sin(anim_t * 3.0)) if _moving else 0.0)
		else:
			body.position.y = _body_base_y + (0.02 * sin(anim_t * 1.4) if _moving else 0.01 * sin(anim_t * 0.4))
	var cape: Node3D = rig.get("cape", null)
	if cape != null:
		cape.rotation.x = -0.12 + sin(anim_t * 0.8) * 0.06 + (0.15 if _moving else 0.0)
	model.position.y = _base_model_y + (0.03 if _moving else 0.0) * absf(sin(anim_t * 1.4))
	if hit_flash > 0.0:
		model.scale = Vector3.ONE * (1.0 + hit_flash * 0.35)
	else:
		model.scale = Vector3.ONE


func _refresh_hp_visibility() -> void:
	if hp_root == null or dead:
		return
	hp_root.visible = is_enemy or selected or hp < max_hp - 0.01


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
