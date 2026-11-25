class_name DreamWorld
extends Node3D

# 《梦隙 · 残响》主控：
# 程序化等轴梦境关卡 / 类魂循环 / 0.18s 弹反 / 闪避 i-frames / 共享忆能 / 窥梦遗物开门。
# 原创设定、关卡与名称；角色模型为 KayKit CC0（CREDITS.md）。

enum RunState { PLAYING, DEAD, VICTORY }

const START_POS := Vector3(0.0, 0.05, 3.4)
const START_YAW := 0.0
const CAMERA_OFFSET := Vector3(10.8, 13.8, 10.8)
const CAMERA_SIZE := 14.3
const INTERACT_RANGE := 2.35
const RELIC_COST := 25.0
const RIFT_POS := Vector3(-8.0, 0.0, -22.0)
const ALTAR_POS := Vector3(4.5, 0.0, -27.2)
const NORMAL_HOME := Vector3(0.0, 0.05, -23.0)
const BOSS_HOME := Vector3(28.5, 0.05, -23.0)
const DEATH_RESPAWN_TIME := 2.4

var level: DreamLevel
var player: DreamPlayer
var normal_enemy: DreamEnemy
var boss: DreamEnemy
var enemies: Array = []
var hud: DreamHud
var fx: DreamFx
var camera: Camera3D

var run_state: RunState = RunState.PLAYING
var paused := false
var capture_mode := false
var run_time := 0.0
var death_count := 0
var death_timer := 0.0
var shards_collected := 0
var has_relic := false
var bridge_revealed := false
var attack_token: DreamEnemy = null
var boss_engaged := false
var last_damage_dealt := 0.0
var parry_lesson_shown := false
var room_name := ""
var checkpoints: Array = []
var shards: Array = []
var last_checkpoint: Dictionary = {}

var _camera_focus := Vector3.ZERO
var _film_camera := false
var _camera_shake := 0.0
var _shake_time := 0.0
var _dodge_trail_cooldown := 0.0
var _last_room := ""
var _boss_announced := false
var _checkpoint_hint_shown := false
var _level_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	fx = DreamFx.new()
	fx.name = "Fx"
	fx.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fx)
	level = DreamLevel.new()
	level.name = "Level"
	level.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(level)
	checkpoints = level.checkpoints
	shards = level.shards
	last_checkpoint = checkpoints[0]
	_build_actors()
	_build_camera()
	_build_hud()
	player.died.connect(_on_player_died)
	_normal_room()
	_snap_camera()
	hud.show_room("醒梦庭")
	hud.push_toast("从残梦灯醒来 · 循着断桥的雾声前行", Color(0.72, 0.95, 0.86), 2.8)


func _exit_tree() -> void:
	if get_tree() != null:
		get_tree().paused = false


# ------------------------------------------------------------------ 输入

func _setup_input() -> void:
	_key("move_forward", KEY_W)
	_key("move_backward", KEY_S)
	_key("move_left", KEY_A)
	_key("move_right", KEY_D)
	_key("dodge", KEY_SPACE)
	_key("heal", KEY_Q)
	_key("interact", KEY_E)
	_key("restart", KEY_R)
	_key("lock_on", KEY_TAB)
	_key("pause", KEY_ESCAPE)
	_key("pause", KEY_P)
	_mouse("attack", MOUSE_BUTTON_LEFT)
	_mouse("parry", MOUSE_BUTTON_RIGHT)
	_mouse("lock_on", MOUSE_BUTTON_MIDDLE)
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		InputMap.action_set_deadzone(action, 0.2)


func _ensure_action(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)


func _key(action: String, keycode: Key) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey and (existing as InputEventKey).physical_keycode == keycode:
			return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _mouse(action: String, button: MouseButton) -> void:
	_ensure_action(action)
	for existing in InputMap.action_get_events(action):
		if existing is InputEventMouseButton and (existing as InputEventMouseButton).button_index == button:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if run_state != RunState.VICTORY:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if paused:
		if event.is_action_pressed("restart"):
			toggle_pause()
			respawn_at_checkpoint()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("restart"):
		if run_state == RunState.VICTORY:
			restart_run()
		elif run_state == RunState.DEAD:
			respawn_at_checkpoint()
		else:
			respawn_at_checkpoint()
			hud.push_toast("从残梦灯重开 · 已保留记忆残片", Color(0.7, 0.82, 0.9), 1.0)
		get_viewport().set_input_as_handled()
		return
	if run_state != RunState.PLAYING:
		return
	if event.is_action_pressed("lock_on"):
		toggle_lock_on()
	elif event.is_action_pressed("attack"):
		player.press_attack()
	elif event.is_action_released("attack"):
		player.release_attack()
	elif event.is_action_pressed("parry"):
		player.start_parry()
	elif event.is_action_pressed("dodge"):
		player.start_dodge()
	elif event.is_action_pressed("heal"):
		player.try_heal()
	elif event.is_action_pressed("interact"):
		interact()
	else:
		return
	get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if run_state == RunState.VICTORY:
		return
	paused = not paused
	player.attack_held = false
	get_tree().paused = paused


# ------------------------------------------------------------------ 构建

func _build_actors() -> void:
	player = DreamPlayer.new()
	player.name = "Player"
	player.world = self
	player.position = START_POS
	player.rotation.y = START_YAW
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)

	normal_enemy = DreamEnemy.new()
	normal_enemy.name = "LostWanderer"
	normal_enemy.world = self
	normal_enemy.setup(false)
	normal_enemy.home = NORMAL_HOME
	normal_enemy.position = NORMAL_HOME
	normal_enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemies.append(normal_enemy)
	add_child(normal_enemy)

	boss = DreamEnemy.new()
	boss.name = "PendulumWarden"
	boss.world = self
	boss.setup(true)
	boss.home = BOSS_HOME
	boss.position = BOSS_HOME
	boss.process_mode = Node.PROCESS_MODE_PAUSABLE
	enemies.append(boss)
	add_child(boss)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "IsoCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CAMERA_SIZE
	camera.near = 0.05
	camera.far = 120.0
	camera.current = true
	add_child(camera)
	_camera_focus = player.global_position + Vector3(0, 1.0, 0)
	_snap_camera()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = DreamHud.new()
	hud.name = "HUD"
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.world = self
	layer.add_child(hud)


func _normal_room() -> void:
	_last_room = _room_name_for(player.global_position)
	room_name = _last_room


# ------------------------------------------------------------------ 主循环

func _process(delta: float) -> void:
	if paused:
		return
	_level_time += delta
	level.animate_level(delta)
	_dodge_trail_cooldown = maxf(0.0, _dodge_trail_cooldown - delta)
	_update_camera(delta)
	_update_room()
	if run_state == RunState.PLAYING:
		run_time += delta
		_update_boss_aggro()
		_check_victory()
		if player.global_position.y < -2.5:
			hud.push_toast("坠入梦雾 · 回到残梦灯", Color(0.7, 0.8, 0.95), 1.2)
			respawn_at_checkpoint()
	elif run_state == RunState.DEAD:
		death_timer += delta
		if death_timer >= DEATH_RESPAWN_TIME:
			respawn_at_checkpoint()


func _update_camera(delta: float) -> void:
	if camera == null or player == null or _film_camera:
		return
	var focus := player.global_position + Vector3(0, 0.95, 0)
	if player.lock_target != null and is_instance_valid(player.lock_target):
		focus += (player.lock_target.global_position - player.global_position) * 0.16
	elif boss_engaged and boss != null and boss.is_alive():
		focus += (boss.global_position - player.global_position) * 0.18
	else:
		focus += player.get_facing() * 1.15
	_camera_focus = _camera_focus.lerp(focus, clampf(delta * 5.2, 0.0, 1.0))
	var desired_size := 16.2 if boss_engaged and boss != null and boss.is_alive() else CAMERA_SIZE
	camera.size = lerpf(camera.size, desired_size, clampf(delta * 2.0, 0.0, 1.0))
	camera.position = _camera_focus + CAMERA_OFFSET
	camera.look_at(_camera_focus, Vector3.UP)
	if _camera_shake > 0.0:
		var amount := _camera_shake
		camera.h_offset = sin(_level_time * 91.0) * amount
		camera.v_offset = cos(_level_time * 73.0) * amount * 0.7
		_camera_shake = maxf(0.0, _camera_shake - delta * 1.8)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


func _snap_camera() -> void:
	if camera == null or player == null:
		return
	_camera_focus = player.global_position + Vector3(0, 0.95, 0) + player.get_facing() * 1.15
	camera.position = _camera_focus + CAMERA_OFFSET
	camera.look_at(_camera_focus, Vector3.UP)
	camera.size = CAMERA_SIZE
	camera.h_offset = 0.0
	camera.v_offset = 0.0


func _update_room() -> void:
	var new_room := _room_name_for(player.global_position)
	if new_room != _last_room:
		_last_room = new_room
		room_name = new_room
		if hud != null:
			hud.show_room(new_room)
		if new_room == "断桥秘园" and has_relic and not bridge_revealed:
			hud.push_toast("雾里有一条看不见的路……按 E 窥梦", Color(0.55, 0.95, 0.86), 2.0)


func _room_name_for(pos: Vector3) -> String:
	if pos.x < -11.0:
		return "断桥秘园"
	if pos.x > 20.5:
		return "无钟之间"
	if pos.z > -8.5:
		return "醒梦庭"
	if pos.z > -14.5 and pos.x < 4.5:
		return "无名回廊"
	if pos.x > 8.0 and pos.x < 18.5:
		return "无名回廊"
	return "齿轮回廊"


func _update_boss_aggro() -> void:
	if boss == null or not boss.is_alive() or boss.aggro:
		return
	if player.global_position.x > 19.6:
		boss.aggro = true
		boss_engaged = true
		if not _boss_announced:
			_boss_announced = true
			hud.push_toast("钟摆守梦人 · 抬起头来", Color(0.95, 0.55, 0.72), 2.0)
			fx.ring(boss.global_position, Color(0.9, 0.35, 0.55), 3.0, 0.9)
			camera_shake(0.10)


# ------------------------------------------------------------------ 战斗判定

func combat_enabled() -> bool:
	return run_state == RunState.PLAYING and not paused and not capture_mode


func request_attack_token(enemy: DreamEnemy) -> bool:
	if attack_token == null or not is_instance_valid(attack_token) or not attack_token.is_alive():
		attack_token = enemy
		return true
	return attack_token == enemy


func release_attack_token(enemy: DreamEnemy) -> void:
	if attack_token == enemy:
		attack_token = null


func telegraph_started(enemy: DreamEnemy) -> void:
	if capture_mode:
		return
	if enemy == normal_enemy and not parry_lesson_shown and player != null:
		var dist := _flat_distance(player.global_position, enemy.global_position)
		if dist < 7.5:
			hud.push_toast("看清起手 · 在命中前按下右键", Color(0.95, 0.84, 0.55), 1.6)


func resolve_enemy_attack(enemy: DreamEnemy, data: Dictionary, _token: bool) -> void:
	if run_state != RunState.PLAYING or player == null:
		return
	var to_player := player.global_position - enemy.global_position
	to_player.y = 0.0
	var distance := to_player.length()
	var attack_range := float(data["range"])
	if distance > attack_range + 0.45:
		return
	var aoe := bool(data["aoe"])
	if not aoe and distance > 1.4:
		var enemy_forward := -enemy.global_transform.basis.z
		if enemy_forward.dot(to_player.normalized()) < -0.25:
			return
	var parryable := bool(data["parryable"])
	if player.is_parry_active() and parryable and player.parry_faces(enemy.global_position):
		enemy.on_parried()
		player.on_parry_success(enemy)
		parry_lesson_shown = true
		return
	if player.is_invulnerable():
		if player.is_dodging_with_iframes():
			player.on_dodge_success()
			hud.push_toast("闪避 · 无伤", Color(0.6, 0.9, 1.0), 0.55)
			fx.ring(player.global_position, Color(0.5, 0.8, 1.0), 1.0, 0.35)
		return
	var dealt := player.take_damage(float(data["damage"]), enemy.global_position)
	if dealt:
		enemy.damage_dealt += float(data["damage"])
		camera_shake(0.22)


func player_attack(attacker: DreamPlayer, damage: float, reach: float, forward: Vector3, heavy: bool) -> void:
	var hit_any := false
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var to_enemy: Vector3 = enemy.global_position - attacker.global_position
		to_enemy.y = 0.0
		var distance: float = to_enemy.length()
		if distance > reach + enemy.body_radius():
			continue
		if distance > 0.45 and forward.dot(to_enemy.normalized()) < -0.15:
			continue
		var applied: float = enemy.take_damage(damage, true, attacker.global_position)
		if applied > 0.0:
			hit_any = true
			attacker.add_energy(4.0 if not heavy else 7.0)
			fx.ring(enemy.global_position, Color(1.0, 0.78, 0.42), 0.9, 0.35)
	if hit_any:
		last_damage_dealt = damage
		camera_shake(0.06)


func on_enemy_died(enemy: DreamEnemy) -> void:
	if enemy == boss:
		boss_engaged = false
		if hud != null:
			hud.push_toast("钟摆守梦人 · 沉默", Color(0.92, 0.78, 0.9), 2.2)
		fx.burst_light(enemy.global_position, Color(0.9, 0.4, 0.9), 5.0, 8.0)
		_check_victory()
	elif hud != null:
		hud.push_toast("巡游者散入雾中", Color(0.8, 0.7, 0.8), 1.2)


func _check_victory() -> void:
	if run_state != RunState.PLAYING:
		return
	if boss != null and not boss.is_alive() and shards_collected >= 2:
		_win()


func _win() -> void:
	run_state = RunState.VICTORY
	boss_engaged = false
	player.set_controls_enabled(false)
	player.lock_target = null
	attack_token = null
	fx.ring(player.global_position, Color(1.0, 0.84, 0.5), 3.4, 1.2)
	camera_shake(0.14)


# ------------------------------------------------------------------ 交互 / 遗物 / 记忆

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _find_interactable() -> Dictionary:
	var best: Dictionary = {}
	var best_distance := INTERACT_RANGE
	for checkpoint in checkpoints:
		var distance := _flat_distance(player.global_position, checkpoint["pos"])
		if distance <= best_distance:
			best = {
				"kind": "checkpoint",
				"data": checkpoint,
				"distance": distance,
				"prompt": "在%s旁歇息 · 恢复并重置梦魇" % String(checkpoint["name"]),
			}
			best_distance = distance
	if not has_relic:
		var altar_distance := _flat_distance(player.global_position, ALTAR_POS)
		if altar_distance <= best_distance:
			best = {
				"kind": "relic",
				"distance": altar_distance,
				"prompt": "取得遗物「窥梦棱镜」",
			}
			best_distance = altar_distance
	if not bridge_revealed and has_relic:
		var rift_distance := _flat_distance(player.global_position, RIFT_POS)
		if rift_distance <= 2.8 and rift_distance <= best_distance:
			best = {
				"kind": "rift",
				"distance": rift_distance,
				"prompt": "开启窥梦 · 看破断桥（-25 忆能）",
			}
			best_distance = rift_distance
	for shard in shards:
		if bool(shard["collected"]):
			continue
		var shard_node: Node3D = shard["node"]
		var shard_distance := _flat_distance(player.global_position, shard_node.global_position)
		if shard_distance <= best_distance:
			best = {
				"kind": "shard",
				"data": shard,
				"distance": shard_distance,
				"prompt": "拾取记忆残片 · %s" % String(shard["label"]),
			}
			best_distance = shard_distance
	return best


func get_interact_text() -> String:
	if run_state != RunState.PLAYING or paused:
		return ""
	var interactable := _find_interactable()
	return String(interactable.get("prompt", ""))


func _interact() -> void:
	if run_state != RunState.PLAYING:
		return
	var interactable := _find_interactable()
	if interactable.is_empty():
		return
	match String(interactable["kind"]):
		"checkpoint":
			_rest_at_checkpoint(interactable["data"])
		"relic":
			_take_relic()
		"rift":
			use_relic()
		"shard":
			_collect_shard(interactable["data"])


func _rest_at_checkpoint(checkpoint: Dictionary) -> void:
	last_checkpoint = checkpoint
	player.heal_full()
	player.energy = maxf(player.energy, 65.0)
	player.stamina = DreamPlayer.MAX_STAMINA
	normal_enemy.reset_enemy()
	if boss != null and boss.is_alive():
		boss.reset_enemy()
	boss_engaged = false
	attack_token = null
	hud.push_toast("残梦灯亮起 · 梦魇归位", Color(0.62, 0.95, 0.82), 1.8)
	fx.ring(player.global_position, Color(0.55, 1.0, 0.82), 2.2, 0.8)
	fx.sparks(player.global_position + Vector3.UP, Color(0.55, 1.0, 0.82), 18)


func _take_relic() -> void:
	has_relic = true
	level.set_relic_taken(true)
	hud.push_toast("获得遗物 · 窥梦棱镜", Color(0.62, 1.0, 0.86), 2.2)
	fx.ring(player.global_position, Color(0.55, 1.0, 0.86), 2.0, 0.7)
	fx.sparks(player.global_position + Vector3.UP, Color(0.55, 1.0, 0.86), 26)
	fx.burst_light(player.global_position, Color(0.55, 1.0, 0.86), 4.0, 7.0)
	camera_shake(0.08)


func use_relic() -> bool:
	if run_state != RunState.PLAYING:
		return false
	if not has_relic:
		hud.push_toast("还没有能看破幻象的遗物", Color(0.8, 0.75, 0.7), 1.2)
		return false
	if bridge_revealed:
		hud.push_toast("断桥已在梦中显形", Color(0.6, 0.9, 0.82), 1.0)
		return false
	if not player.consume_energy(RELIC_COST):
		hud.push_toast("忆能不足 · 弹反可回能", Color(0.95, 0.7, 0.55), 1.4)
		return false
	bridge_revealed = true
	level.set_bridge_open(true)
	hud.push_toast("看破幻象 · 断桥显形", Color(0.55, 1.0, 0.86), 2.4)
	fx.ring(Vector3(-8.1, 0.1, -22.0), Color(0.55, 1.0, 0.86), 2.4, 0.9)
	fx.ring(Vector3(-11.0, 0.1, -22.0), Color(0.55, 1.0, 0.86), 2.0, 1.1)
	fx.sparks(Vector3(-11.0, 0.3, -22.0), Color(0.55, 1.0, 0.86), 36)
	fx.burst_light(Vector3(-11.0, 0.4, -22.0), Color(0.55, 1.0, 0.86), 4.2, 8.0)
	camera_shake(0.12)
	return true


func _collect_shard(shard: Dictionary) -> void:
	if bool(shard["collected"]):
		return
	shard["collected"] = true
	var shard_node: Node3D = shard["node"]
	shard_node.visible = false
	shards_collected += 1
	hud.push_toast("拾取记忆残片  %d / 2" % shards_collected, Color(0.62, 1.0, 0.86), 2.0)
	fx.ring(shard_node.global_position, Color(0.6, 1.0, 0.88), 1.4, 0.6)
	fx.sparks(shard_node.global_position, Color(0.6, 1.0, 0.88), 24)
	fx.burst_light(shard_node.global_position, Color(0.6, 1.0, 0.88), 3.0, 5.0)
	if shards_collected >= 2 and boss != null and not boss.is_alive():
		_check_victory()
	elif shards_collected >= 2:
		hud.push_toast("记忆已齐 · 去无钟之间敲响结局", Color(0.95, 0.82, 0.5), 2.0)


func interact() -> void:
	_interact()


func get_objective_text() -> String:
	if not has_relic:
		if shards_collected == 0:
			return "探索醒梦庭与齿轮回廊\n寻找第一枚记忆残片"
		return "取得遗物「窥梦棱镜」\n它在齿轮回廊的祭坛上"
	if not bridge_revealed:
		return "按 E 使用窥梦棱镜，看破西侧断桥\n（消耗 25 忆能）"
	if shards_collected < 2:
		return "跨过隐藏断桥\n拾取第二枚记忆残片"
	if boss != null and boss.is_alive():
		return "进入无钟之间\n击败钟摆守梦人"
	return "记忆已归位\n等待梦潮退去"


func get_threat_hint() -> Dictionary:
	if player == null or run_state != RunState.PLAYING:
		return {}
	var nearest: DreamEnemy = null
	var nearest_distance := 9.0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		if enemy.state != DreamEnemy.State.WINDUP:
			continue
		var distance := _flat_distance(player.global_position, enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		var data: Dictionary = DreamEnemy.ATTACK_DATA[nearest.current_attack]
		var seconds := nearest.telegraph_seconds_left()
		if bool(data["parryable"]):
			return {
				"text": "右键 · 弹反",
				"sub": "%s · %.2fs 起手" % [String(data["label"]), seconds],
			}
		return {
			"text": "空格 · 闪避",
			"sub": "%s · 不可弹反" % String(data["label"]),
		}
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.can_be_riposted():
			continue
		if _flat_distance(player.global_position, enemy.global_position) < 3.4:
			return {
				"text": "左键 · 反击",
				"sub": "梦魇失衡 · 反击伤害加倍",
			}
	return {}


func is_boss_bar_visible() -> bool:
	if boss == null or not boss.is_alive() or run_state != RunState.PLAYING:
		return false
	return boss.aggro or boss_engaged or player.global_position.x > 19.6


func toggle_lock_on() -> void:
	if player.lock_target != null and is_instance_valid(player.lock_target) and player.lock_target.is_alive():
		player.lock_target = null
		hud.push_toast("解除锁定", Color(0.7, 0.78, 0.84), 0.6)
		return
	var nearest: DreamEnemy = null
	var nearest_distance := 15.0
	for enemy in enemies:
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive():
			continue
		var distance := _flat_distance(player.global_position, enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		player.face_target(nearest)
		hud.push_toast("锁定 · %s" % nearest.display_name, Color(0.92, 0.82, 0.62), 0.9)


# ------------------------------------------------------------------ 死亡/重生/重开

func _on_player_died() -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.DEAD
	death_count += 1
	death_timer = 0.0
	attack_token = null
	player.set_controls_enabled(false)
	hud.push_toast("梦碎了", Color(0.95, 0.62, 0.58), 2.0)
	camera_shake(0.28)


func respawn_at_checkpoint() -> void:
	if last_checkpoint.is_empty():
		return
	run_state = RunState.PLAYING
	death_timer = 0.0
	player.respawn_at(last_checkpoint["spawn"], float(last_checkpoint["yaw"]))
	player.set_controls_enabled(true)
	player.energy = maxf(player.energy, 45.0)
	normal_enemy.reset_enemy()
	if boss != null and boss.is_alive():
		boss.reset_enemy()
	boss_engaged = false
	_boss_announced = false
	attack_token = null
	_snap_camera()
	_update_room()
	hud.show_room(_room_name_for(player.global_position))
	hud.push_toast("残梦灯重燃 · 梦魇归位", Color(0.62, 0.95, 0.82), 1.8)
	fx.ring(player.global_position, Color(0.55, 1.0, 0.9), 2.5, 0.9)


func restart_run() -> void:
	get_tree().paused = false
	paused = false
	capture_mode = false
	run_state = RunState.PLAYING
	run_time = 0.0
	death_count = 0
	shards_collected = 0
	has_relic = false
	bridge_revealed = false
	parry_lesson_shown = false
	boss_engaged = false
	_boss_announced = false
	attack_token = null
	last_checkpoint = checkpoints[0]
	for shard in shards:
		shard["collected"] = false
		var shard_node: Node3D = shard["node"]
		shard_node.visible = true
	level.set_bridge_open(false)
	level.set_relic_taken(false)
	normal_enemy.reset_enemy()
	boss.reset_enemy()
	player.respawn_at(START_POS, START_YAW)
	player.set_controls_enabled(true)
	player.parry_success_count = 0
	player.dodge_success_count = 0
	player.damage_taken = 0.0
	player.energy = DreamPlayer.START_ENERGY
	_snap_camera()
	_last_room = _room_name_for(player.global_position)
	room_name = _last_room
	hud.show_room("醒梦庭")
	hud.push_toast("新的一梦开始", Color(0.7, 0.95, 0.86), 2.0)


# ------------------------------------------------------------------ 特效/相机 API

func toast(text: String, color: Color, duration := 1.3) -> void:
	if hud != null:
		hud.push_toast(text, color, duration)


func camera_shake(amount: float) -> void:
	_camera_shake = maxf(_camera_shake, amount)


func spawn_step_dust(pos: Vector3) -> void:
	fx.ring(pos + Vector3(0, 0.02, 0), Color(0.42, 0.6, 0.62), 0.25, 0.24)


func spawn_dodge_trail(pos: Vector3) -> void:
	if _dodge_trail_cooldown > 0.0:
		return
	_dodge_trail_cooldown = 0.06
	fx.afterimage(pos, Color(0.4, 0.75, 1.0))


func set_film_camera(pos: Vector3, look_at: Vector3, size_value := CAMERA_SIZE) -> void:
	_film_camera = true
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size_value
	camera.position = pos
	camera.look_at(look_at, Vector3.UP)
	camera.h_offset = 0.0
	camera.v_offset = 0.0


func clear_film_camera() -> void:
	_film_camera = false
	_snap_camera()


func debug_teleport_player(pos: Vector3, yaw := 0.0) -> void:
	player.global_position = pos
	player.global_rotation = Vector3(0, yaw, 0)
	player.velocity = Vector3.ZERO
	player.lock_target = null
	_snap_camera()
	_update_room()


func debug_grant_relic() -> void:
	has_relic = true
	level.set_relic_taken(true)


func debug_reveal_bridge() -> void:
	if not has_relic:
		debug_grant_relic()
	bridge_revealed = true
	level.set_bridge_open(true)


func debug_collect_shard(index: int) -> void:
	if index >= 0 and index < shards.size():
		_collect_shard(shards[index])


func debug_engage_boss() -> void:
	if boss != null and boss.is_alive():
		boss.aggro = true
		boss_engaged = true


func debug_freeze_player(frozen: bool) -> void:
	player.process_mode = Node.PROCESS_MODE_DISABLED if frozen else Node.PROCESS_MODE_PAUSABLE
