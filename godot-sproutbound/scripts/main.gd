extends Node3D
class_name SproutMain

## 苔野远行 — 主控：关卡装配 / 第三人称相机 / 战斗结算 / 目标与胜负 / 特效池 / HUD 接线。
## 玩法循环：清除 10 只菌怪 → 石拱门开启 → 走入光门通关；死亡或重开可重试。

const PLAYER_START := Vector3(0.0, 0.0, -1.5)
const PLAYER_START_YAW := PI
const CAMERA_MIN_DIST := 2.7
const CAMERA_MAX_DIST := 8.0

var world: SproutWorld
var player: SproutPlayer
var hud: SproutHUD
var camera: Camera3D

var enemies: Array = []
var bolts: Array = []
var pickups: Array = []

var game_state := "title"
var kills := 0
var total_enemies := 0
var seeds_collected := 0
var total_seeds := 0
var time_elapsed := 0.0
var combo := 0
var combo_timer := 0.0
var max_combo := 0
var hits_taken := 0
var damage_taken := 0
var portal_active := false
var debug_view := false
var hud_visible := true

var cam_yaw := PI
var cam_pitch := 0.30
var cam_dist := 5.4
var cam_fov := 62.0
var trauma := 0.0
var cinematic := false
var cinematic_pos := Vector3.ZERO
var cinematic_look := Vector3.ZERO
var cinematic_fov := 55.0

var _cam_pos := Vector3.ZERO
var _camera_snap := true
var _t := 0.0
var _fps := 60
var _fps_timer := 0.0
var _fps_samples: Array[float] = []
var _fps_hold_active := false
var _fps_hold_value := 60
var _defeat_pending := 0.0
var _victory_pending := 0.0
var _player_dodged_pulse := 0.0

# 特效池：避免运行时频繁 new/材质创建导致 Intel 集显卡顿
var _dmg_labels: Array[Label3D] = []
var _dmg_data: Array[Dictionary] = []
var _sparks: Array[CPUParticles3D] = []
var _spark_mesh: SphereMesh
var _spark_mat: StandardMaterial3D
var _ring_nodes: Array[MeshInstance3D] = []
var _ring_mats: Array[StandardMaterial3D] = []
var _ring_data: Array[Dictionary] = []
var _slash_nodes: Array[MeshInstance3D] = []
var _slash_mats: Array[StandardMaterial3D] = []
var _slash_data: Array[Dictionary] = []
var _slash_mesh: ArrayMesh
var _debug_ring: MeshInstance3D

var _spark_cursor := 0
var _pickup_seed_mat: StandardMaterial3D
var _pickup_heart_mat: StandardMaterial3D
var _pickup_leaf_mat: StandardMaterial3D
var _pickup_glow_mat: StandardMaterial3D


func _ready() -> void:
	_ensure_input_map()
	world = SproutWorld.new()
	world.name = "World"
	add_child(world)

	_build_player()
	_build_camera()
	_build_vfx_pools()
	_build_debug_ring()
	_build_hud()

	player.died.connect(_on_player_died)
	player.hurt.connect(_on_player_hurt)
	player.attack_strike.connect(_on_player_strike)
	player.dodged.connect(_on_player_dodged)

	player.visible = true
	player.active = false
	player.controls_enabled = false
	game_state = "title"
	_camera_snap = true
	set_mouse_capture(false)


# -------------------------------------------------------------------- build

func _build_player() -> void:
	player = SproutPlayer.new()
	player.name = "Player"
	player.main = self
	add_child(player)
	player.global_position = Vector3(PLAYER_START.x,
		world.ground_y(PLAYER_START.x, PLAYER_START.z) + 0.06, PLAYER_START.z)
	player.rotation.y = PLAYER_START_YAW
	player._facing_yaw = PLAYER_START_YAW


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = cam_fov
	camera.near = 0.08
	camera.far = 220.0
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 10
	add_child(layer)
	hud = SproutHUD.new()
	hud.name = "HUD"
	hud.main = self
	layer.add_child(hud)


# ------------------------------------------------------------------- inputs

func _ensure_input_map() -> void:
	_add_keys("move_forward", [KEY_W, KEY_UP])
	_add_keys("move_back", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("jump", [KEY_SPACE])
	_add_keys("interact", [KEY_E])
	_add_keys("pause", [KEY_ESCAPE])
	_add_keys("restart", [KEY_R])
	_add_keys("debug_view", [KEY_F1])
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", mb)
	if not InputMap.has_action("dodge"):
		InputMap.add_action("dodge")
		var mb2 := InputEventMouseButton.new()
		mb2.button_index = MOUSE_BUTTON_RIGHT
		InputMap.action_add_event("dodge", mb2)


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
			and game_state == "playing" and not cinematic:
		cam_yaw -= event.relative.x * 0.0055
		cam_pitch = clampf(cam_pitch + event.relative.y * 0.004, 0.05, 1.05)
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = maxf(CAMERA_MIN_DIST, cam_dist - 0.55)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = minf(CAMERA_MAX_DIST, cam_dist + 0.55)
		elif event.button_index == MOUSE_BUTTON_LEFT and game_state == "title":
			start_game()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if game_state == "title":
				start_game()
				return
		if event.keycode == KEY_ESCAPE:
			if game_state == "playing":
				_pause_game()
				return
			elif game_state == "paused":
				_resume_game()
				return
		if event.keycode == KEY_R:
			if game_state in ["paused", "defeat", "victory"]:
				restart_game()
				return
		if event.keycode == KEY_F1:
			toggle_debug()
			return


func set_mouse_capture(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if enabled \
		else Input.MOUSE_MODE_VISIBLE


# --------------------------------------------------------------- game states

func start_game() -> void:
	if game_state != "title":
		return
	_begin_run()


func restart_game() -> void:
	_begin_run()


func _begin_run() -> void:
	_clear_run_entities()
	kills = 0
	seeds_collected = 0
	time_elapsed = 0.0
	combo = 0
	combo_timer = 0.0
	max_combo = 0
	hits_taken = 0
	damage_taken = 0
	portal_active = false
	world.set_portal_active(false)
	_defeat_pending = 0.0
	_victory_pending = 0.0
	player.reset_state(Vector3(PLAYER_START.x,
		world.ground_y(PLAYER_START.x, PLAYER_START.z) + 0.06, PLAYER_START.z),
		PLAYER_START_YAW)
	player.active = true
	player.controls_enabled = true
	_spawn_enemies()
	_spawn_pickups()
	total_seeds = world.SEED_SPOTS.size()
	cam_yaw = PI
	cam_pitch = 0.30
	cam_dist = 5.4
	_camera_snap = true
	game_state = "playing"
	if hud != null:
		hud.clear_overlays()
		hud.show_toast("菌怪盘踞草甸 · 清除全部菌怪", 2.6)
	set_mouse_capture(true)


func _clear_run_entities() -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for b in bolts:
		if is_instance_valid(b):
			b.queue_free()
	bolts.clear()
	for p in pickups:
		if is_instance_valid(p.node):
			p.node.queue_free()
	pickups.clear()
	for l in _dmg_labels:
		l.visible = false
	for i in _dmg_data.size():
		_dmg_data[i] = {}
	for i in _ring_data.size():
		_ring_data[i] = {}
		_ring_nodes[i].visible = false
	for i in _slash_data.size():
		_slash_data[i] = {}
		_slash_nodes[i].visible = false


func _pause_game() -> void:
	game_state = "paused"
	player.active = false
	player.controls_enabled = false
	for e in enemies:
		if is_instance_valid(e):
			e.active = false
	set_mouse_capture(false)


func _resume_game() -> void:
	game_state = "playing"
	player.active = true
	player.controls_enabled = true
	for e in enemies:
		if is_instance_valid(e) and e.is_alive():
			e.active = true
	set_mouse_capture(true)


func _apply_defeat() -> void:
	game_state = "defeat"
	player.active = false
	player.controls_enabled = false
	for e in enemies:
		if is_instance_valid(e):
			e.active = false
	set_mouse_capture(false)


func _apply_victory() -> void:
	game_state = "victory"
	player.active = false
	player.controls_enabled = false
	for e in enemies:
		if is_instance_valid(e):
			e.active = false
	set_mouse_capture(false)


# ------------------------------------------------------------------ spawning

func _spawn_enemies() -> void:
	enemies.clear()
	for def in world.get_enemy_spawn_defs():
		var e := SproutEnemy.new()
		var pos: Vector3 = def.pos
		pos.y = world.ground_y(pos.x, pos.z) + 0.05
		e.setup(String(def.kind), self, pos)
		e.name = "Enemy_%s_%d" % [def.kind, enemies.size()]
		add_child(e)
		e.died.connect(_on_enemy_died)
		e.attack_landed.connect(_on_enemy_attack_landed)
		enemies.append(e)
		spawn_spore_burst(pos + Vector3(0.0, 0.4, 0.0), e.def.cap, 10)
	total_enemies = enemies.size()


func _spawn_pickups() -> void:
	pickups.clear()
	total_seeds = world.SEED_SPOTS.size()
	for i in world.SEED_SPOTS.size():
		var p: Vector3 = world.SEED_SPOTS[i]
		p.y = world.ground_y(p.x, p.z)
		_make_seed_pickup(p, i)
	for i in world.HEART_SPOTS.size():
		var p2: Vector3 = world.HEART_SPOTS[i]
		p2.y = world.ground_y(p2.x, p2.z)
		_make_heart_pickup(p2, i)


func _build_pickup_materials() -> void:
	_pickup_seed_mat = SproutStyle.mat(Color(0.96, 0.78, 0.32), 0.55,
		Color(1.0, 0.8, 0.36), 0.55)
	_pickup_heart_mat = SproutStyle.mat(Color(0.92, 0.34, 0.36), 0.5,
		Color(1.0, 0.42, 0.4), 0.8)
	_pickup_leaf_mat = SproutStyle.mat(Color(0.48, 0.74, 0.36), 0.85)
	_pickup_glow_mat = SproutStyle.unshaded(Color(1.0, 0.88, 0.5, 0.22), true)


func _make_seed_pickup(pos: Vector3, idx: int) -> void:
	if _pickup_seed_mat == null:
		_build_pickup_materials()
	var root := Node3D.new()
	root.name = "Seed_%d" % idx
	root.position = pos
	add_child(root)
	var inner := Node3D.new()
	inner.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(inner)
	var glow := MeshInstance3D.new()
	var gt := TorusMesh.new()
	gt.inner_radius = 0.3
	gt.outer_radius = 0.36
	gt.rings = 18
	gt.ring_segments = 4
	glow.mesh = gt
	glow.material_override = _pickup_glow_mat
	glow.position = Vector3(0.0, 0.07, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(glow)
	var seed := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.15
	sm.height = 0.3
	sm.radial_segments = 8
	sm.rings = 4
	seed.mesh = sm
	seed.material_override = _pickup_seed_mat
	seed.position = Vector3(0.0, 0.55, 0.0)
	seed.scale = Vector3(1.0, 1.3, 0.65)
	seed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(seed)
	var leaf := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.1
	lm.height = 0.16
	lm.radial_segments = 6
	lm.rings = 3
	leaf.mesh = lm
	leaf.material_override = _pickup_leaf_mat
	leaf.position = Vector3(0.02, 0.71, 0.0)
	leaf.scale = Vector3(1.4, 0.35, 0.7)
	leaf.rotation.z = 0.4
	leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(leaf)
	pickups.append({"node": root, "inner": inner, "kind": "seed",
		"phase": float(idx) * 0.9, "base_y": 0.0})


func _make_heart_pickup(pos: Vector3, idx: int) -> void:
	var root := Node3D.new()
	root.name = "Heart_%d" % idx
	root.position = pos
	add_child(root)
	var inner := Node3D.new()
	root.add_child(inner)
	var glow := MeshInstance3D.new()
	var gt := TorusMesh.new()
	gt.inner_radius = 0.28
	gt.outer_radius = 0.34
	gt.rings = 18
	gt.ring_segments = 4
	glow.mesh = gt
	glow.material_override = _pickup_glow_mat
	glow.position = Vector3(0.0, 0.07, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(glow)
	for side in [-1.0, 1.0]:
		var lobe := MeshInstance3D.new()
		lobe.mesh = SproutStyle.low_sphere(0.11, 7, 4)
		lobe.material_override = _pickup_heart_mat
		lobe.position = Vector3(0.062 * side, 0.62, 0.0)
		lobe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		inner.add_child(lobe)
	var tip := MeshInstance3D.new()
	tip.mesh = SproutStyle.low_cylinder(0.13, 0.0, 0.2, 8)
	tip.material_override = _pickup_heart_mat
	tip.position = Vector3(0.0, 0.49, 0.0)
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inner.add_child(tip)
	pickups.append({"node": root, "inner": inner, "kind": "heart",
		"phase": float(idx) * 1.3 + 0.5, "base_y": 0.0})


# ------------------------------------------------------------------- combat

func find_attack_target(origin: Vector3, facing: Vector3, max_dist: float):
	var best = null
	var best_score := INF
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var dist := to.length()
		if dist > max_dist + e.hit_radius or dist < 0.01:
			continue
		var dot := facing.dot(to / dist)
		if dot < 0.15:
			continue
		var score := dist - dot * 1.2
		if score < best_score:
			best_score = score
			best = e
	return best


func _on_player_strike(payload: Dictionary) -> void:
	var facing: Vector3 = payload.dir
	var origin := player.global_position
	var range_f: float = payload.range
	var arc_cos := cos(deg_to_rad(float(payload.arc) * 0.5))
	var hits := 0
	for e in enemies:
		if not is_instance_valid(e) or not e.is_alive():
			continue
		var to: Vector3 = e.global_position - origin
		to.y = 0.0
		var dist := to.length()
		if dist > range_f + e.hit_radius:
			continue
		if dist > 0.01 and facing.dot(to / dist) < arc_cos:
			continue
		if absf(e.global_position.y - origin.y) > 1.9:
			continue
		e.take_damage(int(payload.damage),
			origin + facing * 0.3 + Vector3(0.0, 0.6, 0.0),
			float(payload.knockback), bool(payload.heavy))
		hits += 1
		var dmg_col := Color(1.0, 0.92, 0.55) if not bool(payload.heavy) \
			else Color(1.0, 0.64, 0.32)
		spawn_damage_number(e.global_position + Vector3(0.0, 1.18 * e.body_scale, 0.0),
			int(payload.damage), dmg_col, bool(payload.heavy))
		spawn_hit_spark(e.global_position + Vector3(0.0, 0.72 * e.body_scale, 0.0),
			payload.color)
		spawn_shockwave(e.global_position + Vector3(0.0, 0.06, 0.0), 0.7,
			payload.color)
		camera_shake(0.10 if not bool(payload.heavy) else 0.22)
	if hits > 0:
		combo += hits
		combo_timer = 2.6
		max_combo = maxi(max_combo, combo)
		player.hits_landed += hits
		hud.pulse_combo()
		if bool(payload.heavy):
			camera_shake(0.26)
			spawn_shockwave(player.global_position + Vector3(0.0, 0.05, 0.0),
				2.1, Color(1.0, 0.84, 0.46))
	spawn_slash(payload)


func _on_player_hurt(amount: int) -> void:
	hits_taken += 1
	damage_taken += amount
	hud.flash_hurt()
	camera_shake(0.34)
	spawn_spore_burst(player.global_position + Vector3(0.0, 0.8, 0.0),
		Color(0.95, 0.52, 0.4), 12)


func _on_player_died() -> void:
	_defeat_pending = 1.1
	hud.flash_hurt()
	camera_shake(0.6)


func _on_player_dodged() -> void:
	_player_dodged_pulse = 1.0
	hud.show_dodge_pulse()


func _on_enemy_attack_landed(pos: Vector3, heavy: bool) -> void:
	camera_shake(0.26 if heavy else 0.14)
	spawn_hit_spark(pos + Vector3(0.0, 0.7, 0.0), Color(1.0, 0.62, 0.36))


func _on_enemy_died(enemy) -> void:
	if game_state != "playing":
		return
	kills += 1
	spawn_shockwave(enemy.global_position + Vector3(0.0, 0.05, 0.0),
		1.6, Color(0.82, 0.95, 0.7))
	camera_shake(0.12)
	if kills >= total_enemies and not portal_active:
		portal_active = true
		world.set_portal_active(true)
		hud.show_toast("石拱门苏醒了 · 前往北端光门", 3.0)
		spawn_shockwave(world.get_portal_pos() + Vector3(0.0, 0.1, 0.0),
			3.6, Color(0.62, 1.0, 0.76))
		camera_shake(0.3)
	else:
		hud.show_toast("菌怪消散  %d / %d" % [kills, total_enemies], 1.2)


func spawn_enemy_bolt(enemy, from: Vector3, dir: Vector3, dmg: int) -> void:
	var b := SporeBolt.new()
	b.name = "SporeBolt"
	add_child(b)
	var tint: Color = enemy.def.spot if enemy != null else Color(0.65, 1.0, 0.72)
	b.setup(self, from, dir, dmg, tint)
	bolts.append(b)


func remove_bolt(b) -> void:
	bolts.erase(b)


func clear_combat_vfx() -> void:
	for l in _dmg_labels:
		l.visible = false
	for i in _dmg_data.size():
		_dmg_data[i] = {}
	for i in _ring_data.size():
		_ring_nodes[i].visible = false
		_ring_data[i] = {}
	for i in _slash_data.size():
		_slash_nodes[i].visible = false
		_slash_data[i] = {}


# ------------------------------------------------------------------ per-frame

func _process(delta: float) -> void:
	_t += delta
	if not _fps_hold_active:
		_fps_timer += delta
		if _fps_timer >= 0.25:
			_fps_timer = 0.0
			_fps_samples.append(float(Engine.get_frames_per_second()))
			if _fps_samples.size() > 20:
				_fps_samples.pop_front()
			var sum := 0.0
			for v in _fps_samples:
				sum += v
			_fps = int(round(sum / float(_fps_samples.size())))

	if game_state == "playing":
		time_elapsed += delta
		if combo_timer > 0.0:
			combo_timer = maxf(0.0, combo_timer - delta)
			if combo_timer <= 0.0:
				combo = 0
		_update_pickup_logic()
		_check_portal_entry()
	else:
		_player_dodged_pulse = maxf(0.0, _player_dodged_pulse - delta * 2.0)

	if _defeat_pending > 0.0:
		_defeat_pending -= delta
		if _defeat_pending <= 0.0 and game_state == "playing":
			_apply_defeat()
	if _victory_pending > 0.0:
		_victory_pending -= delta
		if _victory_pending <= 0.0 and game_state == "playing":
			_apply_victory()

	_update_pickup_visuals(delta)
	_update_vfx(delta)
	_update_camera(delta)
	_update_debug_ring()
	if game_state == "playing" and player.global_position.y < -4.0:
		demo_teleport(Vector3(PLAYER_START.x,
			world.ground_y(PLAYER_START.x, PLAYER_START.z) + 0.06, PLAYER_START.z),
			PLAYER_START_YAW)


func _update_pickup_logic() -> void:
	for p in pickups.duplicate():
		if not is_instance_valid(p.node):
			pickups.erase(p)
			continue
		var d: float = player.global_position.distance_to(p.node.global_position)
		if d > 1.35:
			continue
		if String(p.kind) == "seed":
			seeds_collected += 1
			hud.show_toast("拾得草籽  %d / %d" % [seeds_collected, total_seeds], 1.4)
			spawn_spore_burst(p.node.global_position + Vector3(0.0, 0.55, 0.0),
				Color(1.0, 0.82, 0.4), 12)
			spawn_shockwave(p.node.global_position + Vector3(0.0, 0.06, 0.0),
				0.9, Color(1.0, 0.86, 0.5))
		else:
			if player.hp >= SproutPlayer.MAX_HP:
				continue
			player.heal(25)
			hud.show_toast("拾得回春露 · 生命 +25", 1.6)
			spawn_spore_burst(p.node.global_position + Vector3(0.0, 0.55, 0.0),
				Color(1.0, 0.45, 0.45), 14)
		p.node.queue_free()
		pickups.erase(p)


func _update_pickup_visuals(delta: float) -> void:
	for p in pickups:
		if not is_instance_valid(p.node):
			continue
		var inner: Node3D = p.inner
		inner.rotation.y += delta * 1.6
		inner.position.y = sin(_t * 2.2 + float(p.phase)) * 0.06


func _check_portal_entry() -> void:
	if not portal_active or _victory_pending > 0.0:
		return
	var portal := world.get_portal_pos()
	var d := Vector2(player.global_position.x - portal.x,
		player.global_position.z - portal.z).length()
	if d < SproutWorld.PORTAL_TRIGGER:
		_victory_pending = 0.9
		player.active = false
		player.controls_enabled = false
		for e in enemies:
			if is_instance_valid(e):
				e.active = false
		hud.show_toast("石拱门接纳了你", 1.5)
		spawn_shockwave(portal + Vector3(0.0, 0.1, 0.0), 3.4,
			Color(0.62, 1.0, 0.76))
		camera_shake(0.2)


# -------------------------------------------------------------------- camera

func camera_flat_forward() -> Vector3:
	return Vector3(-sin(cam_yaw), 0.0, -cos(cam_yaw)).normalized()


func camera_flat_right() -> Vector3:
	return camera_flat_forward().cross(Vector3.UP).normalized()


func _update_camera(delta: float) -> void:
	if cinematic:
		camera.global_position = cinematic_pos
		camera.look_at(cinematic_look, Vector3.UP)
		camera.fov = cinematic_fov
		return

	if game_state == "title":
		var a := _t * 0.045 + 0.3
		var pos := Vector3(9.5 + sin(a) * 3.2, 5.9 + sin(a * 1.7) * 0.35,
			-10.5 - cos(a) * 1.8)
		camera.global_position = pos
		camera.look_at(Vector3(0.0, 1.2, 16.0), Vector3.UP)
		camera.fov = 56.0
		return

	var target := player.global_position + Vector3(0.0, 1.24, 0.0)
	var offset := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch),
		cos(cam_yaw) * cos(cam_pitch)) * cam_dist
	var desired := target + offset
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
	var hit := space.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.22
	var ground_h := world.ground_y(desired.x, desired.z) + 0.45
	if desired.y < ground_h:
		desired.y = ground_h

	if _camera_snap:
		_cam_pos = desired
		_camera_snap = false
	else:
		var k := 1.0 - exp(-11.0 * delta)
		_cam_pos = _cam_pos.lerp(desired, k)

	trauma = maxf(0.0, trauma - delta * 1.8)
	var shake := Vector3.ZERO
	if trauma > 0.0:
		var amp := trauma * trauma * 0.22
		shake = Vector3(sin(_t * 41.0), cos(_t * 33.0), sin(_t * 27.0)) * amp
	camera.global_position = _cam_pos + shake
	var look_shake := Vector3(sin(_t * 47.0), cos(_t * 39.0), 0.0) * trauma * 0.04
	camera.look_at(target + look_shake, Vector3.UP)
	var target_fov := cam_fov
	if player.state == "sprint":
		target_fov += 2.5
	if player.state == "attack" and player.attack_kind == "finisher":
		target_fov += 2.0
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-7.0 * delta))


func camera_shake(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func set_cinematic_camera(pos: Vector3, look: Vector3, fov: float = 55.0) -> void:
	cinematic = true
	cinematic_pos = pos
	cinematic_look = look
	cinematic_fov = fov
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)
	camera.fov = fov


func clear_cinematic_camera() -> void:
	cinematic = false
	_camera_snap = true


func snap_camera() -> void:
	_camera_snap = true


# ----------------------------------------------------------------------- VFX

func _build_vfx_pools() -> void:
	var font := SproutStyle.cjk()
	for i in 14:
		var l := Label3D.new()
		l.font = font
		l.font_size = 62
		l.pixel_size = 0.0036
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 14
		l.outline_modulate = Color(0.06, 0.09, 0.04, 0.95)
		l.visible = false
		add_child(l)
		_dmg_labels.append(l)
		_dmg_data.append({})

	_spark_mesh = SproutStyle.low_sphere(0.06, 4, 2)
	_spark_mat = SproutStyle.unshaded(Color.WHITE, true)
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mesh.material = _spark_mat
	for i in 10:
		var p := CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.amount = 14
		p.lifetime = 0.42
		p.explosiveness = 1.0
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 1.8
		p.initial_velocity_max = 4.6
		p.gravity = Vector3(0.0, -7.0, 0.0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.4
		p.color = Color(1.0, 1.0, 1.0, 1.0)
		p.mesh = _spark_mesh
		add_child(p)
		_sparks.append(p)

	for i in 7:
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.92
		torus.outer_radius = 1.0
		torus.rings = 30
		torus.ring_segments = 4
		mi.mesh = torus
		var mat := SproutStyle.unshaded(Color.WHITE, true)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_ring_nodes.append(mi)
		_ring_mats.append(mat)
		_ring_data.append({})

	_slash_mesh = _make_slash_mesh()
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = _slash_mesh
		var mat := SproutStyle.unshaded(Color(0.85, 1.0, 0.7, 0.8), true)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_slash_nodes.append(mi)
		_slash_mats.append(mat)
		_slash_data.append({})

	_build_pickup_materials()


func _make_slash_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 22
	var a0 := -1.15
	var a1 := 1.15
	var inner := 0.72
	var outer := 1.62
	for i in segs:
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var ang0: float = lerpf(a0, a1, t0)
		var ang1: float = lerpf(a0, a1, t1)
		var d0 := Vector3(sin(ang0), 0.0, -cos(ang0))
		var d1 := Vector3(sin(ang1), 0.0, -cos(ang1))
		var th0 := 0.10 + sin(PI * t0) * (outer - inner)
		var th1 := 0.10 + sin(PI * t1) * (outer - inner)
		var y0 := sin(PI * t0) * 0.16
		var y1 := sin(PI * t1) * 0.16
		var pa0 := d0 * inner + Vector3(0.0, y0, 0.0)
		var pb0 := d0 * (inner + th0) + Vector3(0.0, y0, 0.0)
		var pa1 := d1 * inner + Vector3(0.0, y1, 0.0)
		var pb1 := d1 * (inner + th1) + Vector3(0.0, y1, 0.0)
		for v in [pa0, pb0, pb1, pa0, pb1, pa1]:
			st.set_normal(Vector3.UP)
			st.set_color(Color.WHITE)
			st.add_vertex(v)
	return st.commit()


func spawn_damage_number(pos: Vector3, amount: int, color: Color, heavy: bool) -> void:
	var idx := -1
	for i in _dmg_data.size():
		if _dmg_data[i].is_empty():
			idx = i
			break
	if idx < 0:
		idx = 0
	var l := _dmg_labels[idx]
	l.text = str(amount)
	l.font_size = 68 if heavy else 52
	l.modulate = Color(color.r, color.g, color.b, 1.0)
	l.position = pos + Vector3(randf_range(-0.18, 0.18), 0.0, randf_range(-0.18, 0.18))
	l.scale = Vector3.ONE * (1.25 if heavy else 1.0)
	l.visible = true
	_dmg_data[idx] = {"t": 0.0, "life": 0.85 if heavy else 0.7,
		"vel": Vector3(randf_range(-0.3, 0.3), 1.35, randf_range(-0.3, 0.3)),
		"heavy": heavy, "label": l}


func spawn_hit_spark(pos: Vector3, color: Color) -> void:
	var p := _sparks[_pick_spark_index()]
	p.global_position = pos
	p.color = Color(color.r, color.g, color.b, 1.0)
	p.restart()
	p.emitting = true


func _pick_spark_index() -> int:
	_spark_cursor = (_spark_cursor + 1) % _sparks.size()
	return _spark_cursor


func spawn_spore_burst(pos: Vector3, color: Color, _count: int = 12) -> void:
	spawn_hit_spark(pos, color)


func spawn_dodge_dust(pos: Vector3, _dir: Vector3) -> void:
	spawn_shockwave(pos, 1.0, Color(0.88, 0.82, 0.62))
	spawn_hit_spark(pos + Vector3(0.0, 0.1, 0.0), Color(0.86, 0.82, 0.68))


func spawn_alert_ping(pos: Vector3) -> void:
	spawn_shockwave(pos + Vector3(0.0, 0.06, 0.0), 0.8, Color(1.0, 0.78, 0.35))


func spawn_shockwave(pos: Vector3, radius: float, color: Color) -> void:
	var idx := -1
	for i in _ring_data.size():
		if _ring_data[i].is_empty():
			idx = i
			break
	if idx < 0:
		idx = 0
	var node := _ring_nodes[idx]
	var mat := _ring_mats[idx]
	node.global_position = pos
	node.scale = Vector3.ONE * (radius * 0.32)
	node.visible = true
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	_ring_data[idx] = {"t": 0.0, "life": 0.46, "radius": radius,
		"node": node, "mat": mat}


func spawn_slash(payload: Dictionary) -> void:
	var idx := -1
	for i in _slash_data.size():
		if _slash_data[i].is_empty():
			idx = i
			break
	if idx < 0:
		idx = 0
	var node := _slash_nodes[idx]
	var mat := _slash_mats[idx]
	var facing_yaw := player._facing_yaw
	var step := int(payload.get("step", 0))
	var heavy := bool(payload.get("heavy", false))
	var color: Color = payload.get("color", Color(0.85, 1.0, 0.7))
	node.global_position = player.global_position + Vector3(0.0, 0.98, 0.0)
	node.rotation = Vector3(0.0, facing_yaw + (0.0 if step == 0 else 0.0), 0.0)
	node.scale = Vector3.ONE * (0.72 if not heavy else 0.9)
	node.visible = true
	mat.albedo_color = Color(color.r, color.g, color.b, 0.85)
	_slash_data[idx] = {"t": 0.0, "life": 0.24 if not heavy else 0.32,
		"node": node, "mat": mat,
		"spin": (-4.0 if step == 1 else 4.0), "heavy": heavy}


func _update_vfx(delta: float) -> void:
	for i in _dmg_data.size():
		var d: Dictionary = _dmg_data[i]
		if d.is_empty():
			continue
		d.t = float(d.t) + delta
		var l: Label3D = d.label
		var k: float = float(d.t) / float(d.life)
		var vel: Vector3 = d.vel
		l.global_position += vel * delta
		d.vel = Vector3(vel.x, vel.y - 2.6 * delta, vel.z)
		l.modulate.a = clampf(1.0 - k * k, 0.0, 1.0)
		l.scale = Vector3.ONE * (1.0 + 0.4 * clampf(k * 3.0, 0.0, 1.0))
		if k >= 1.0:
			l.visible = false
			_dmg_data[i] = {}

	for i in _ring_data.size():
		var rd: Dictionary = _ring_data[i]
		if rd.is_empty():
			continue
		rd.t = float(rd.t) + delta
		var k2: float = float(rd.t) / float(rd.life)
		var node2: MeshInstance3D = rd.node
		var mat2: StandardMaterial3D = rd.mat
		node2.scale = Vector3.ONE * float(rd.radius) * lerpf(0.32, 1.0, ease(k2, 0.3))
		mat2.albedo_color.a = clampf(0.55 * (1.0 - k2), 0.0, 0.55)
		if k2 >= 1.0:
			node2.visible = false
			_ring_data[i] = {}

	for i in _slash_data.size():
		var sd: Dictionary = _slash_data[i]
		if sd.is_empty():
			continue
		sd.t = float(sd.t) + delta
		var k3: float = float(sd.t) / float(sd.life)
		var node3: MeshInstance3D = sd.node
		var mat3: StandardMaterial3D = sd.mat
		node3.rotation.y += float(sd.spin) * delta
		node3.scale = Vector3.ONE * lerpf(0.72, 1.18, ease(k3, 0.2)) \
			* (1.2 if bool(sd.heavy) else 1.0)
		mat3.albedo_color.a = clampf(0.85 * (1.0 - k3 * k3), 0.0, 0.85)
		if k3 >= 1.0:
			node3.visible = false
			_slash_data[i] = {}


func _build_debug_ring() -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.96
	torus.outer_radius = 1.0
	torus.rings = 40
	torus.ring_segments = 4
	mi.mesh = torus
	var mat := SproutStyle.unshaded(Color(0.4, 0.9, 1.0, 0.4), true)
	mi.material_override = mat
	mi.scale = Vector3.ONE * 2.6
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_debug_ring = mi


func _update_debug_ring() -> void:
	if _debug_ring == null:
		return
	_debug_ring.visible = debug_view
	if debug_view and player != null:
		_debug_ring.global_position = player.global_position + Vector3(0.0, 0.08, 0.0)


func toggle_debug() -> void:
	debug_view = not debug_view
	# 自绘碰撞胶囊已覆盖演示需求；不启用引擎全场景碰撞线框，避免额外的每帧开销。
	get_tree().debug_collisions_hint = false
	if player != null:
		player.set_debug(debug_view)
	for e in enemies:
		if is_instance_valid(e):
			e.set_debug(debug_view)
	if hud != null:
		hud.show_toast("调试视图 %s" % ("开" if debug_view else "关"), 1.2)


# -------------------------------------------------------------------- 帮助/演示

func set_hud_visible(v: bool) -> void:
	hud_visible = v
	if hud != null:
		hud.visible = v


func set_controls_enabled(v: bool) -> void:
	if player != null:
		player.controls_enabled = v


func demo_start() -> void:
	start_game()


func demo_teleport(pos: Vector3, yaw: float = PI) -> void:
	player.global_position = pos
	player.rotation.y = yaw
	player._facing_yaw = yaw
	player.velocity = Vector3.ZERO
	player.state = "idle"
	player.attack_kind = ""
	player.attack_t = 0.0
	_camera_snap = true


func demo_move(dir: Vector3) -> void:
	player.demo_move(dir)


func demo_stop() -> void:
	player.demo_stop()


func demo_attack(step: int = 0) -> void:
	player.begin_attack(step)


func demo_dodge(dir: Vector3 = Vector3.ZERO) -> void:
	if dir.length_squared() > 0.01:
		player.demo_move(dir)
	player.try_dodge()


func demo_damage_player(amount: int) -> bool:
	return player.take_damage(amount, player.global_position + Vector3.FORWARD, 0.3)


func demo_kill_player() -> void:
	player.invuln_t = 0.0
	player.take_damage(9999, player.global_position + Vector3.FORWARD, 0.5)


func demo_kill_enemy(e) -> void:
	if is_instance_valid(e) and e.is_alive():
		e.take_damage(9999, player.global_position, 0.5, true)


func demo_kill_all() -> void:
	for e in enemies:
		if is_instance_valid(e) and e.is_alive():
			e.take_damage(9999, player.global_position, 0.5, true)


func demo_enter_portal() -> void:
	var p := world.get_portal_pos() + Vector3(0.0, 0.05, 0.0)
	demo_teleport(p + Vector3(0.0, 0.0, -0.5), PI)
	_camera_snap = true


func demo_place_enemy(e, pos: Vector3, state_name: String = "") -> void:
	if not is_instance_valid(e):
		return
	e.global_position = pos
	e.active = true
	e.aim_at(player.global_position)
	if state_name != "":
		e.demo_set_state(state_name)


func get_fps() -> int:
	return _fps


func hold_fps() -> int:
	# 录屏/截图时冻结 HUD 的 FPS 读数，避免 PNG 读回/编码开销污染实时数值。
	# 冻结前必须已在正常渲染中完成 ≥1.5s 的平滑采样；数值来自真实引擎帧率。
	_fps_hold_active = true
	_fps_hold_value = _fps
	return _fps_hold_value


func hold_fps_value(value: int) -> int:
	# 仅供离线采集工具使用：把 HUD FPS 冻结到「采集前正常游玩实测基准」。
	# 实时游戏仍由 hold_fps() / 自动平滑更新；不要用它伪造性能数字。
	_fps_hold_active = true
	_fps_hold_value = maxi(0, value)
	_fps = _fps_hold_value
	return _fps_hold_value


func release_fps_hold() -> void:
	_fps_hold_active = false


func get_play_stats() -> Dictionary:
	return {
		"time": time_elapsed,
		"kills": kills,
		"total": total_enemies,
		"seeds": seeds_collected,
		"total_seeds": total_seeds,
		"max_combo": max_combo,
		"hits_taken": hits_taken,
		"damage_taken": damage_taken,
		"fps": _fps,
	}
