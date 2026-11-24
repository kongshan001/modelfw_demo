extends Node3D
## 《雾屿守望》主控：开场 → 布防 → 波次 → 胜负 → 下一岛。
## 所有单位/地图/UI 均由代码生成；本文件只处理状态、输入、结算与演示钩子。

const Balance = preload("res://scripts/balance.gd")
const IslandScript = preload("res://scripts/island.gd")
const SquadScript = preload("res://scripts/squad.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const BoatScript = preload("res://scripts/boat.gd")
const ProjectileScript = preload("res://scripts/projectile.gd")
const CameraRigScript = preload("res://scripts/camera_rig.gd")
const HudScript = preload("res://scripts/hud.gd")
const FxScript = preload("res://scripts/fx.gd")
const UI = preload("res://scripts/ui_style.gd")

const FIXED_DT := 1.0 / 60.0

var state := "intro"
var paused := false
var speed_index := 0
var auto_simulate := true
var demo_mode := false
var hold_waves := false

var island_index := 0
var island = null
var houses: Array = []
var squads: Array = []
var enemies: Array = []
var boats: Array = []
var projectiles: Array = []
var selected_squads: Array = []

var wave_number := 1
var waves_total := 3
var waves_cleared := 0
var wave_state := "prep"
var prep_timer := Balance.PREP_TIME

var sim_time := 0.0
var run_time := 0.0
var kills := 0
var houses_lost := 0
var squads_lost := 0
var islands_cleared := 0
var result_reason := ""
var banner_text := ""
var banner_sub := ""
var banner_timer := 0.0

var selecting := false
var selection_rect := Rect2()
var _drag_active := false
var _drag_start := Vector2.ZERO
var _last_mouse_ui := Vector2(640, 360)
var _hovered_squad = null
var _sim_accum := 0.0
var _feedback_last: Dictionary = {}
var _boss_announced := false

var world_root: Node3D
var units_root: Node3D
var fx
var camera_rig
var hud


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_environment()
	world_root = Node3D.new()
	world_root.name = "World"
	add_child(world_root)
	units_root = Node3D.new()
	units_root.name = "Units"
	add_child(units_root)
	fx = FxScript.new()
	fx.name = "FX"
	add_child(fx)
	camera_rig = CameraRigScript.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 10
	add_child(layer)
	hud = HudScript.new()
	hud.name = "HUD"
	hud.game = self
	layer.add_child(hud)
	_setup_run(0, true, [], false)


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fb7b1")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d7d1")
	env.ambient_light_energy = 0.46
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.98
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.14
	env.fog_enabled = true
	env.fog_light_color = Color("a8c1ba")
	env.fog_light_energy = 0.45
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.18
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52, -34, 0)
	sun.light_color = Color("ffe2b0")
	sun.light_energy = 1.28
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.light_angular_distance = 0.25
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-28, 152, 0)
	fill.light_color = Color("9fc5cb")
	fill.light_energy = 0.22
	fill.shadow_enabled = false
	add_child(fill)


# ---------------------------------------------------------------- setup / run flow

func _setup_run(index: int, intro: bool, preserved_classes: Array, keep_stats: bool) -> void:
	if not keep_stats:
		sim_time = 0.0
		run_time = 0.0
		kills = 0
		houses_lost = 0
		squads_lost = 0
		islands_cleared = 0
	_clear_units()
	island_index = clampi(index, 0, Balance.island_count() - 1)
	island = IslandScript.new()
	island.name = "Island"
	world_root.add_child(island)
	island.build(island_index, self)
	houses = island.houses
	camera_rig.configure(island.radius)
	_spawn_squads(preserved_classes)
	_reset_waves()
	deselect_all()
	selecting = false
	_drag_active = false
	selection_rect = Rect2()
	paused = false
	speed_index = 0
	_boss_announced = false
	_feedback_last.clear()
	banner_text = ""
	banner_sub = ""
	banner_timer = 0.0
	result_reason = ""
	state = "intro" if intro else "playing"
	var center := Vector3(0, island.height_at(0, 0), 0)
	if intro:
		camera_rig.snap_view(center, 52.0, -24.0, 48.0)
		camera_rig.set_orbit(4.2)
	else:
		camera_rig.snap_view(center, 46.0, -38.0, 50.0)
		camera_rig.set_orbit(0.0)
		show_banner("第 1 波即将登陆", "先布防，再迎敌", 3.2)
	if hud != null:
		hud.queue_redraw()


func start_battle() -> void:
	if state != "intro":
		return
	hold_waves = false
	state = "playing"
	prep_timer = Balance.PREP_TIME
	wave_state = "prep"
	banner_timer = 0.0
	camera_rig.set_orbit(0.0)
	camera_rig.set_zoom(44.0)
	show_banner("第 1 波即将登陆", "右键移动小队 · 高地增伤", 3.6)


func toggle_pause() -> void:
	if state != "playing":
		return
	paused = not paused


func set_paused(value: bool) -> void:
	if state != "playing":
		return
	paused = value


func toggle_speed() -> void:
	if state != "playing":
		return
	speed_index = 1 - speed_index


func speed_mult() -> float:
	return 2.0 if speed_index == 1 else 1.0


func restart_run() -> void:
	hold_waves = false
	_setup_run(0, false, [], false)
	show_banner("重新布防", "三队守军已就位", 3.0)


func has_next_island() -> bool:
	return island_index + 1 < Balance.island_count()


func result_primary_action() -> void:
	if state == "victory" and has_next_island():
		advance_island()
	else:
		restart_run()


func advance_island() -> void:
	var preserved: Array = []
	for squad in squads:
		if squad.alive and squad.living_count() > 0:
			preserved.append(squad.class_id)
	if preserved.is_empty():
		restart_run()
		return
	_setup_run(island_index + 1, false, preserved, true)
	show_banner("抵达 " + str(island.data["name"]), "幸存队伍补员至四人 · 阵亡队伍不再归来", 4.5)


func _clear_units() -> void:
	if island != null and is_instance_valid(island):
		island.queue_free()
	island = null
	houses = []
	for squad in squads:
		if is_instance_valid(squad):
			squad.queue_free()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	for boat in boats:
		if is_instance_valid(boat):
			boat.queue_free()
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	squads.clear()
	enemies.clear()
	boats.clear()
	projectiles.clear()
	selected_squads.clear()
	if fx != null:
		fx.clear_all()
	if hud != null:
		hud._hover_card = -1


func _spawn_squads(preserved_classes: Array) -> void:
	var classes: Array = preserved_classes.duplicate() if not preserved_classes.is_empty() else ["shield", "archer", "spear"]
	for i in range(classes.size()):
		var class_id := str(classes[i])
		var spawn: Vector3 = island.squad_spawn_points[i % island.squad_spawn_points.size()]
		var squad = SquadScript.new()
		units_root.add_child(squad)
		squad.configure(self, i, class_id, spawn)
		squads.append(squad)


func _reset_waves() -> void:
	waves_total = Balance.wave_count(island_index)
	wave_number = 1
	waves_cleared = 0
	wave_state = "prep"
	prep_timer = Balance.PREP_TIME


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	_update_banner(delta)
	if auto_simulate:
		if state == "playing" and not paused:
			_sim_accum += delta * speed_mult()
			var steps := 0
			while _sim_accum >= FIXED_DT and steps < 8:
				simulate(FIXED_DT)
				_sim_accum -= FIXED_DT
				steps += 1
			if steps >= 8:
				_sim_accum = 0.0
		if not demo_mode:
			_update_camera_input(delta)
			if state == "playing" and not paused:
				_update_hover()


func _update_camera_input(delta: float) -> void:
	if state == "victory" or state == "defeat":
		return
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_A):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		move.x += 1.0
	if Input.is_key_pressed(KEY_W):
		move.y += 1.0
	if Input.is_key_pressed(KEY_S):
		move.y -= 1.0
	if move.length_squared() > 0.0:
		camera_rig.pan_input(delta, move.normalized())
	var rotate := 0.0
	if Input.is_key_pressed(KEY_Q):
		rotate -= 1.0
	if Input.is_key_pressed(KEY_E):
		rotate += 1.0
	if rotate != 0.0:
		camera_rig.rotate_by(rotate * 82.0 * delta)


func _update_hover() -> void:
	if not is_inside_tree():
		return
	var squad = _pick_squad_at(_last_mouse_ui)
	if _hovered_squad != null and is_instance_valid(_hovered_squad) and _hovered_squad != squad:
		_hovered_squad.set_hovered(false)
	_hovered_squad = squad
	if squad != null:
		squad.set_hovered(true)


func simulate(dt: float) -> void:
	if state != "playing":
		return
	sim_time += dt
	run_time += dt
	_update_waves(dt)

	for boat in boats.duplicate():
		if is_instance_valid(boat) and not boat.done:
			boat.simulate(dt)
	for squad in squads.duplicate():
		if is_instance_valid(squad):
			squad.simulate(dt)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			enemy.simulate(dt)
	for projectile in projectiles.duplicate():
		if is_instance_valid(projectile) and not projectile.arrived:
			projectile.simulate(dt)

	_separate_enemies()
	_cleanup_dead()
	_check_outcome()


func advance(real_dt: float) -> float:
	if state != "playing" or paused:
		return 0.0
	var scaled := real_dt * speed_mult()
	simulate(scaled)
	return scaled


func _update_waves(dt: float) -> void:
	if hold_waves or state != "playing":
		return
	if wave_state == "prep":
		prep_timer -= dt
		if prep_timer <= 0.0:
			_start_wave(wave_number)
	elif wave_state == "active":
		if boats.is_empty() and enemies.is_empty():
			waves_cleared += 1
			if waves_cleared >= waves_total:
				wave_state = "done"
				_end_run(true, "三波海掠者尽数退去，屋火未熄。")
			else:
				wave_number += 1
				wave_state = "prep"
				prep_timer = Balance.INTERMISSION
				show_banner("第 %d 波已退" % (wave_number - 1), "下一波将在 %d 秒后登陆" % int(Balance.INTERMISSION), 4.0)


func _start_wave(number: int) -> void:
	if island == null:
		return
	wave_number = number
	wave_state = "active"
	var wave_data: Array = island.data["waves"]
	if number < 1 or number > wave_data.size():
		return
	var wave: Dictionary = wave_data[number - 1]
	show_banner("第 %d 波 · 海掠者登陆" % number, "守住房屋 · 利用兵种克制", 3.6)
	var delay_acc := 0.0
	var boat_index := 0
	for group in wave["groups"]:
		var type_id := str(group["type"])
		var remaining := int(group["count"])
		var landing_idx := clampi(int(group["landing"]), 0, island.landing_points.size() - 1)
		var landing: Dictionary = island.landing_points[landing_idx]
		while remaining > 0:
			var take := mini(5, remaining)
			var types: Array = []
			for _i in range(take):
				types.append(type_id)
			var boat = BoatScript.new()
			units_root.add_child(boat)
			boat.configure(self, landing, types, delay_acc, boat_index)
			boats.append(boat)
			delay_acc += 1.35
			boat_index += 1
			remaining -= take


# ---------------------------------------------------------------- input / selection

func _to_ui(pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return pos
	var xf := get_viewport().get_final_transform()
	return xf.affine_inverse() * pos


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_last_mouse_ui = _to_ui(event.position)
	if event is InputEventMouseButton:
		if state != "playing" or paused:
			return
		var ui_pos := _to_ui(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if hud != null and hud.is_blocking_point(ui_pos):
					return
				selecting = true
				_drag_active = true
				_drag_start = ui_pos
				selection_rect = Rect2(_drag_start, Vector2.ZERO)
				get_viewport().set_input_as_handled()
			elif _drag_active:
				_drag_active = false
				var rect := _rect_from_points(_drag_start, ui_pos)
				_finish_selection(ui_pos, rect)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if hud == null or not hud.is_blocking_point(ui_pos):
				_order_move(ui_pos)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and selecting and _drag_active:
		selection_rect = _rect_from_points(_drag_start, _last_mouse_ui)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				if state == "playing":
					toggle_pause()
				elif state == "intro":
					start_battle()
			KEY_T:
				if state == "playing":
					toggle_speed()
					get_viewport().set_input_as_handled()
			KEY_R:
				if state != "intro":
					restart_run()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				if state == "playing":
					toggle_pause()
			KEY_1, KEY_2, KEY_3:
				if state == "playing" and not paused:
					var idx: int = event.keycode - KEY_1
					select_squad_index(idx, true)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if state != "victory" and state != "defeat" and state != "intro":
				camera_rig.zoom_step(1.0)
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if state != "victory" and state != "defeat" and state != "intro":
				camera_rig.zoom_step(-1.0)
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and state != "victory" and state != "defeat":
			var xf := get_viewport().get_final_transform()
			var s := maxf(0.01, xf.get_scale().x)
			camera_rig.pan_pixels(event.relative / s)


func _rect_from_points(a: Vector2, b: Vector2) -> Rect2:
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), Vector2(absf(a.x - b.x), absf(a.y - b.y)))


func _finish_selection(pos: Vector2, rect: Rect2) -> void:
	selecting = false
	if rect.size.length() < 7.0:
		var squad = _pick_squad_at(pos)
		if squad != null:
			select_squad(squad)
		else:
			deselect_all()
	else:
		_select_in_rect(rect)
	selection_rect = Rect2()


func _pick_squad_at(screen_pos: Vector2) -> Variant:
	if camera_rig == null or camera_rig.camera == null:
		return null
	var best = null
	var best_dist := 26.0
	for squad in squads:
		if not squad.alive:
			continue
		var center: Vector2 = squad.screen_center(camera_rig.camera)
		var d := center.distance_to(screen_pos)
		if d < best_dist:
			best_dist = d
			best = squad
		for member_pos in squad.member_screen_positions(camera_rig.camera):
			var md: float = (member_pos as Vector2).distance_to(screen_pos)
			if md < 20.0 and md < best_dist:
				best_dist = md
				best = squad
	return best


func _select_in_rect(rect: Rect2) -> void:
	var found: Array = []
	for squad in squads:
		if not squad.alive:
			continue
		var inside := false
		var center: Vector2 = squad.screen_center(camera_rig.camera)
		if rect.has_point(center):
			inside = true
		if not inside:
			for p in squad.member_screen_positions(camera_rig.camera):
				if rect.has_point(p):
					inside = true
					break
		if inside:
			found.append(squad)
	_set_selection(found)


func select_squad(squad, focus := false) -> void:
	if squad == null or not squad.alive:
		return
	_set_selection([squad])
	if focus:
		camera_rig.focus_on(squad.center)


func select_squad_index(index: int, focus := false) -> bool:
	if index < 0 or index >= squads.size():
		return false
	var squad = squads[index]
	if not squad.alive:
		return false
	select_squad(squad, focus)
	return true


func _set_selection(list: Array) -> void:
	for squad in squads:
		squad.set_selected(list.has(squad))
	selected_squads = list.duplicate()
	if _hovered_squad != null and is_instance_valid(_hovered_squad):
		_hovered_squad.set_hovered(false)
	_hovered_squad = null


func deselect_all() -> void:
	for squad in squads:
		squad.set_selected(false)
	selected_squads.clear()


func _order_move(screen_pos: Vector2) -> void:
	if selected_squads.is_empty() or island == null:
		return
	var ground: Vector3 = camera_rig.project_ground(screen_pos, Callable(island, "height_at"))
	var base: Vector3 = island.clamp_to_walkable(ground)
	var right := Vector3(camera_rig.camera.global_transform.basis.x.x, 0.0, camera_rig.camera.global_transform.basis.x.z).normalized()
	var count := selected_squads.size()
	for i in range(count):
		var offset := Vector3.ZERO
		if count > 1:
			offset = right * ((float(i) - (float(count) - 1.0) * 0.5) * 2.7)
		var target: Vector3 = island.clamp_to_walkable(base + offset)
		var squad = selected_squads[i]
		squad.issue_move(island, target)
		fx.ring(target, UI.class_color(squad.class_id))


# ---------------------------------------------------------------- combat pipeline

func compute_damage(base: float, attacker_class: String, defender_class: String, attacker_pos: Vector3, defender_pos: Vector3, ranged: bool, defender_enemy_type := "") -> Dictionary:
	var counter_value := Balance.counter(attacker_class, defender_class)
	var height_value := Balance.height_multiplier(attacker_pos.y, defender_pos.y)
	var resist := 1.0
	if ranged:
		resist = Balance.ranged_resist(defender_class, defender_enemy_type)
	return {
		"damage": maxf(0.0, base * counter_value * height_value * resist),
		"counter": counter_value,
		"height": height_value,
		"resist": resist,
		"height_label": Balance.height_label(attacker_pos.y, defender_pos.y),
	}


func damage_enemy(enemy, base: float, attacker_class: String, attacker_pos: Vector3, ranged: bool) -> float:
	if enemy == null or not is_instance_valid(enemy) or not enemy.alive:
		return 0.0
	var info := compute_damage(base, attacker_class, enemy.class_id, attacker_pos, enemy.global_position, ranged, enemy.type_id)
	enemy.take_damage(float(info["damage"]))
	_show_feedback("e" + str(enemy.get_instance_id()), enemy.global_position + Vector3(0, 2.0, 0), info)
	return float(info["damage"])


func damage_member(squad, index: int, base: float, attacker_class: String, attacker_pos: Vector3, ranged: bool, enemy_type := "") -> float:
	if squad == null or not squad.alive:
		return 0.0
	if index < 0 or index >= squad.members.size() or not bool(squad.members[index]["alive"]):
		return 0.0
	var member_pos: Vector3 = squad.get_member_position(index)
	if member_pos == Vector3.ZERO:
		return 0.0
	var info := compute_damage(base, attacker_class, squad.class_id, attacker_pos, member_pos, ranged, "")
	squad.take_member_damage(index, float(info["damage"]))
	_show_feedback("s" + str(squad.get_instance_id()) + ":" + str(index), member_pos + Vector3(0, 1.8, 0), info)
	return float(info["damage"])


func _show_feedback(key: String, pos: Vector3, info: Dictionary) -> void:
	var counter_value := float(info["counter"])
	var height_value := float(info["height"])
	var resist := float(info["resist"])
	if absf(counter_value - 1.0) < 0.01 and absf(height_value - 1.0) < 0.01 and absf(resist - 1.0) < 0.01:
		return
	var last: float = float(_feedback_last.get(key, -99.0))
	if sim_time - last < 0.9:
		return
	_feedback_last[key] = sim_time
	var parts: Array = []
	if resist < 0.9:
		parts.append("盾挡")
	if counter_value > 1.2:
		parts.append("克制 ×%.1f" % counter_value)
	elif counter_value < 0.85:
		parts.append("被克 ×%.2f" % counter_value)
	if height_value > 1.1:
		parts.append("居高")
	elif height_value < 0.95:
		parts.append("仰攻")
	if parts.is_empty():
		return
	var color := UI.AMBER
	if counter_value < 0.85:
		color = UI.RED
	elif resist < 0.9:
		color = UI.BLUE
	fx.float_text(pos, " · ".join(parts), color, 32)


func find_nearest_enemy(pos: Vector3, max_range: float):
	var best = null
	var best_d := max_range
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var d := Vector2(enemy.global_position.x - pos.x, enemy.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = enemy
	return best


func find_nearest_player_member(pos: Vector3, max_range: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d := max_range
	for squad in squads:
		if not squad.alive:
			continue
		for i in range(squad.members.size()):
			if not bool(squad.members[i]["alive"]):
				continue
			var mp: Vector3 = squad.get_member_position(i)
			if mp == Vector3.ZERO:
				continue
			var d := Vector2(mp.x - pos.x, mp.z - pos.z).length()
			if d < best_d:
				best_d = d
				best = {"squad": squad, "index": i, "pos": mp}
	return best


func get_member_position(squad, index: int) -> Vector3:
	if squad == null:
		return Vector3.ZERO
	return squad.get_member_position(index)


func spawn_enemy(type_id: String, pos: Vector3):
	if island == null:
		return null
	var ground: Vector3 = island.clamp_to_walkable(pos)
	ground.y += 0.03
	var enemy = EnemyScript.new()
	units_root.add_child(enemy)
	enemy.configure(self, type_id, ground, enemies.size() % 3)
	enemies.append(enemy)
	if type_id == "chieftain" and not _boss_announced:
		_boss_announced = true
		show_banner("潮汐首领登陆", "重盾首领 — 用长矛与高地围杀", 3.4)
	return enemy


func spawn_projectile(team: String, kind: String, from_pos: Vector3, target_node, target_kind: String, target_squad, member_index: int, class_id: String, damage_value: float, shooter_height: float, speed: float) -> void:
	var projectile = ProjectileScript.new()
	units_root.add_child(projectile)
	projectile.target_squad = target_squad
	projectile.target_member_index = member_index
	projectile.configure(self, kind, from_pos, target_node, target_kind, team, class_id, damage_value, shooter_height, speed)
	projectiles.append(projectile)


func on_projectile_arrived(projectile) -> void:
	if projectile == null:
		return
	projectiles.erase(projectile)
	if projectile.team == "player":
		if projectile.target_node != null and is_instance_valid(projectile.target_node) and projectile.target_node.alive:
			damage_enemy(projectile.target_node, projectile.damage, projectile.attacker_class, projectile.source_pos, true)
			fx.hit(projectile.global_position, Color("f0d49a"))
		else:
			fx.hit(projectile.global_position, Color("8f9388"))
	else:
		var squad = projectile.target_squad
		if squad != null and is_instance_valid(squad) and squad.alive:
			var idx: int = projectile.target_member_index
			if idx >= 0 and idx < squad.members.size() and bool(squad.members[idx]["alive"]):
				damage_member(squad, idx, projectile.damage, projectile.attacker_class, projectile.source_pos, true, "")
				fx.hit(projectile.global_position, Color("d96a55"))
	projectile.queue_free()


func _separate_enemies() -> void:
	for i in range(enemies.size()):
		var a = enemies[i]
		if not is_instance_valid(a) or not a.alive:
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if not is_instance_valid(b) or not b.alive:
				continue
			var flat := Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z)
			var d := flat.length()
			if d > 0.001 and d < 0.82:
				var push := flat.normalized() * (0.82 - d) * 0.5
				var pa: Vector3 = a.global_position + Vector3(push.x, 0, push.y)
				var pb: Vector3 = b.global_position - Vector3(push.x, 0, push.y)
				if island.is_terrain_walkable(pa.x, pa.z):
					a.global_position = Vector3(pa.x, island.height_at(pa.x, pa.z), pa.z)
				if island.is_terrain_walkable(pb.x, pb.z):
					b.global_position = Vector3(pb.x, island.height_at(pb.x, pb.z), pb.z)


func _cleanup_dead() -> void:
	var kept_enemies: Array = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			kept_enemies.append(enemy)
		elif is_instance_valid(enemy):
			enemy.queue_free()
	enemies = kept_enemies
	var kept_boats: Array = []
	for boat in boats:
		if is_instance_valid(boat) and not boat.done:
			kept_boats.append(boat)
	boats = kept_boats
	var kept_projectiles: Array = []
	for projectile in projectiles:
		if is_instance_valid(projectile) and not projectile.arrived:
			kept_projectiles.append(projectile)
	projectiles = kept_projectiles


# ---------------------------------------------------------------- callbacks

func on_enemy_died(enemy) -> void:
	kills += 1
	if enemy != null:
		fx.death(enemy.global_position + Vector3(0, 0.9, 0), Color("b45343"))
		if enemy.type_id == "chieftain":
			show_banner("潮汐首领倒下", "海面暂退 — 守住最后的房屋", 3.0)
	if hud != null:
		hud.queue_redraw()


func on_member_died(_squad, _index: int) -> void:
	if hud != null:
		hud.queue_redraw()


func on_squad_wiped(squad) -> void:
	squads_lost += 1
	selected_squads.erase(squad)
	if squad != null:
		show_banner("「%s」全灭" % str(squad.data["title"]), "永久损失 — 本岛无法复活", 3.8)
		camera_rig.shake(0.28)
	_check_outcome()


func on_house_damaged(_house, _amount: float) -> void:
	if hud != null:
		hud.queue_redraw()


func on_house_destroyed(house) -> void:
	houses_lost += 1
	var alive_count := houses_alive()
	if alive_count > 0:
		show_banner("一座房屋被焚毁", "剩余房屋 %d / %d" % [alive_count, houses_total()], 3.6)
	else:
		show_banner("最后的房屋陷入火海", "", 2.5)
	camera_rig.shake(0.36)
	if house != null:
		fx.death(house.global_position + Vector3(0, 1.8, 0), Color("e08a4a"))
	_check_outcome()


func on_boat_finished(boat) -> void:
	boats.erase(boat)


# ---------------------------------------------------------------- outcome / UI state

func _check_outcome() -> void:
	if state != "playing":
		return
	if houses_alive() <= 0:
		_end_run(false, "所有房屋被焚毁，岛上再无灯火。")
		return
	if alive_squad_count() <= 0:
		_end_run(false, "最后一支小队倒下，防线彻底崩溃。")
		return
	if waves_cleared >= waves_total and wave_state == "done" and enemies.is_empty() and boats.is_empty():
		_end_run(true, "海掠者尽数退去，屋火未熄。接下来，是更远的暮火湾。")


func _end_run(victory: bool, reason: String) -> void:
	if state != "playing":
		return
	state = "victory" if victory else "defeat"
	paused = false
	selecting = false
	_drag_active = false
	selection_rect = Rect2()
	deselect_all()
	camera_rig.set_orbit(0.0)
	result_reason = reason
	if victory:
		waves_cleared = waves_total
		islands_cleared += 1
		camera_rig.set_zoom(48.0)
	else:
		camera_rig.shake(0.5)
	if hud != null:
		hud.queue_redraw()


func show_banner(text: String, sub := "", duration := 3.2) -> void:
	banner_text = text
	banner_sub = sub
	banner_timer = maxf(0.3, duration)


func _update_banner(delta: float) -> void:
	if banner_timer > 0.0:
		banner_timer = maxf(0.0, banner_timer - delta)
		if banner_timer <= 0.0:
			banner_text = ""


func enemies_remaining() -> int:
	var total := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.alive:
			total += 1
	for boat in boats:
		if is_instance_valid(boat):
			total += boat.remaining_count()
	return total


func houses_alive() -> int:
	var n := 0
	for house in houses:
		if is_instance_valid(house) and not house.destroyed:
			n += 1
	return n


func houses_total() -> int:
	return houses.size()


func alive_squad_count() -> int:
	var n := 0
	for squad in squads:
		if is_instance_valid(squad) and squad.alive:
			n += 1
	return n


func is_squad_engaged(squad) -> bool:
	if squad == null or not squad.alive:
		return false
	var reach := float(squad.data["range"]) + 0.5
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var d := Vector2(enemy.global_position.x - squad.center.x, enemy.global_position.z - squad.center.z).length()
		if d <= reach:
			return true
	return false


func get_result_stats() -> Dictionary:
	return {
		"island": str(island.data["name"]) if island != null else "",
		"waves": waves_cleared,
		"waves_total": waves_total,
		"kills": kills,
		"houses_alive": houses_alive(),
		"houses_total": houses_total(),
		"squads_alive": alive_squad_count(),
		"squads_total": squads.size(),
		"time": run_time,
		"islands_cleared": islands_cleared,
	}


# ---------------------------------------------------------------- demo / test hooks

func debug_start_playing(index := 0, hold := true) -> void:
	_setup_run(index, false, [], false)
	state = "playing"
	hold_waves = hold
	wave_state = "prep"
	prep_timer = 999.0 if hold else 2.0
	camera_rig.set_orbit(0.0)


func debug_spawn_enemy(type_id: String, pos: Vector3):
	return spawn_enemy(type_id, pos)


func debug_launch_wave(number: int) -> void:
	if island == null:
		return
	wave_state = "active"
	_start_wave(number)


func debug_kill_enemies() -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.alive:
			enemy.take_damage(99999.0)
	_cleanup_dead()


func debug_clear_boats() -> void:
	for boat in boats:
		if is_instance_valid(boat):
			boat.queue_free()
	boats.clear()


func debug_move_squad(index: int, target: Vector3) -> void:
	if index >= 0 and index < squads.size():
		squads[index].issue_move(island, target)


func debug_select_squad(index: int, focus := false) -> bool:
	return select_squad_index(index, focus)


func debug_damage_house(index: int, amount: float) -> void:
	if index >= 0 and index < houses.size():
		houses[index].take_damage(amount)


func debug_destroy_all_houses() -> void:
	for house in houses:
		if is_instance_valid(house) and not house.destroyed:
			house.take_damage(99999.0)


func debug_finish(victory: bool, reason: String) -> void:
	_end_run(victory, reason)


func debug_focus_camera(pos: Vector3, zoom_value := 34.0, yaw_value := -38.0, pitch_value := 50.0) -> void:
	camera_rig.set_orbit(0.0)
	if pos.y <= 0.001 and island != null:
		pos.y = island.height_at(pos.x, pos.z)
	camera_rig.snap_view(pos, zoom_value, yaw_value, pitch_value)


func debug_set_hold_waves(value: bool) -> void:
	hold_waves = value


func debug_set_prep(seconds: float) -> void:
	prep_timer = seconds


func debug_mark_waves_done() -> void:
	waves_cleared = waves_total
	wave_state = "done"
	_cleanup_dead()
	_check_outcome()


func debug_clear_selection() -> void:
	deselect_all()
