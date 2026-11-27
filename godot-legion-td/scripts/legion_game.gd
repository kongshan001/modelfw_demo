class_name LegionGame
extends Node3D

# Legionfall 主控：3D 战场 + RTS 选择/指挥 + 塔防 + 波次 + 每波三选一 + 胜负重开。
# 输入尽量集中在此脚本，UI 只负责绘制与把按钮回调到这里的公开方法，便于 headless 测试。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")
const World := preload("res://scripts/legion_world.gd")
const Actor := preload("res://scripts/legion_actor.gd")
const Tower := preload("res://scripts/legion_tower.gd")
const Projectile := preload("res://scripts/legion_projectile.gd")
const UI := preload("res://scripts/legion_ui.gd")

const UI_STATE_PREP := "prep"
const UI_STATE_WAVE := "wave"
const UI_STATE_UPGRADE := "upgrade"
const UI_STATE_WIN := "win"
const UI_STATE_LOSE := "lose"
const MAX_FX := 80

var world: LegionWorld
var ui: LegionUI
var ui_layer: CanvasLayer

var seed_value := 0
var ui_state := UI_STATE_PREP
var paused := false
var speed := 1.0
var run_time := 0.0

var gold := D.START_GOLD
var essence := D.START_ESSENCE
var pop_used := 0
var pop_cap := D.START_POP_CAP
var core_hp := D.CORE_HP
var core_hp_max := D.CORE_HP
var kills := 0
var gold_earned := 0
var essence_earned := 0

var wave_index := 0
var wave_def: Dictionary = {}
var wave_total := 0
var wave_killed := 0
var spawn_left := 0
var spawn_queue: Array[Dictionary] = []
var wave_elapsed := 0.0
var prep_t := D.FIRST_PREP_TIME
var prep_total := D.FIRST_PREP_TIME
var modifier: Dictionary = D.MODIFIERS[0]

var units: Array[LegionActor] = []
var enemies: Array[LegionActor] = []
var towers: Array[LegionTower] = []
var projectiles: Array[LegionProjectile] = []
var fx: Array[Dictionary] = []
var hero: LegionActor = null
var hero_respawn_t := 0.0

var selected_units: Array[LegionActor] = []
var selected_pad_index := -1
var barracks_selected := false
var rally_point := World.RALLY_DEFAULT
var rally_point_set := false

var upgrade_levels: Dictionary = {}
var upgrade_choices: Array[String] = []
var rerolls_left := 1
var rerolls_used := 0
var stats: Dictionary = {}
var cooldowns: Dictionary = {"guard": 0.0, "bolt": 0.0, "adept": 0.0}

var attack_move_armed := false
var drag_active := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var debug_box := Rect2()
var debug_lock_camera := false

var banner_text := ""
var banner_sub := ""
var banner_t := 0.0

var groups: Dictionary = {1: [], 2: [], 3: []}
var _rng := RandomNumberGenerator.new()
var _wave_rng := RandomNumberGenerator.new()
var _upgrade_rng := RandomNumberGenerator.new()
var _shake_t := 0.0
var _shake_amp := 0.0
var _middle_drag := false
var _last_mouse := Vector2.ZERO
var _frame_time_acc := 0.0
var _frame_count := 0
var _hp_bars_dirty := 0.0


func _ready() -> void:
	set_process_unhandled_input(true)
	set_process(true)
	_rng.seed = 20261127
	world = World.new()
	world.name = "World"
	add_child(world)
	world.build()
	ui_layer = CanvasLayer.new()
	ui_layer.name = "HUDLayer"
	add_child(ui_layer)
	ui = UI.new()
	ui.name = "HUD"
	ui.set_game(self)
	ui_layer.add_child(ui)
	ui.size = Vector2(1280, 720)
	ui.position = Vector2.ZERO
	start_run(20261127)


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_ESCAPE) and false:
		pass
	var mouse := get_viewport().get_mouse_position()
	if not debug_lock_camera:
		_camera_keys(delta)
		_edge_scroll(mouse, delta)
	if _shake_t > 0.0 and world != null and world.camera != null:
		_shake_t -= delta
		world.apply_camera()
		var amp := _shake_amp * clampf(_shake_t / 0.16, 0.0, 1.0)
		world.camera.position += Vector3(_rng.randf_range(-amp, amp), _rng.randf_range(-amp, amp) * 0.4,
			_rng.randf_range(-amp, amp))
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			world.apply_camera()
	elif _shake_amp > 0.0:
		_shake_amp = 0.0
		if world != null:
			world.apply_camera()
	if not paused and (ui_state == UI_STATE_PREP or ui_state == UI_STATE_WAVE):
		advance(minf(delta, 0.05) * speed)
	if banner_t > 0.0:
		banner_t = maxf(0.0, banner_t - delta)
	_update_fps(delta)


func _update_fps(delta: float) -> void:
	_frame_time_acc += delta
	_frame_count += 1
	if _frame_time_acc >= 0.5:
		_frame_time_acc = 0.0
		_frame_count = 0


# ---------------------------------------------------------------- 开局 / 重开

func start_run(p_seed: int = 0) -> void:
	if p_seed <= 0:
		p_seed = int(Time.get_unix_time_from_system() * 1000.0) % 999983
		if p_seed <= 0:
			p_seed = 1
	seed_value = p_seed
	_rng.seed = seed_value
	_clear_entities()
	gold = D.START_GOLD
	essence = D.START_ESSENCE
	pop_cap = D.START_POP_CAP
	pop_used = 0
	core_hp = D.CORE_HP
	core_hp_max = D.CORE_HP
	kills = 0
	gold_earned = 0
	essence_earned = 0
	run_time = 0.0
	wave_index = 0
	wave_def = {}
	wave_total = 0
	wave_killed = 0
	spawn_left = 0
	spawn_queue.clear()
	wave_elapsed = 0.0
	prep_t = D.FIRST_PREP_TIME
	prep_total = D.FIRST_PREP_TIME
	modifier = D.MODIFIERS[0]
	paused = false
	speed = 1.0
	ui_state = UI_STATE_PREP
	hero = null
	hero_respawn_t = 0.0
	selected_units.clear()
	selected_pad_index = -1
	barracks_selected = false
	rally_point = World.RALLY_DEFAULT
	rally_point_set = false
	upgrade_levels.clear()
	upgrade_choices.clear()
	rerolls_left = 1
	rerolls_used = 0
	attack_move_armed = false
	drag_active = false
	debug_box = Rect2()
	cooldowns = {"guard": 0.0, "bolt": 0.0, "adept": 0.0}
	groups = {1: [], 2: [], 3: []}
	ui.set_help_visible(false)
	_recompute_stats()
	_sync_pad_visuals()
	world.rally_flag.visible = false
	world.set_camera(Vector3(0, 0, 23), 56.0)
	# 初始小队
	_spawn_player("guard", Vector3(-2.2, 0, 21.5))
	_spawn_player("guard", Vector3(1.4, 0, 22.4))
	_spawn_player("bolt", Vector3(4.2, 0, 20.4))
	_spawn_hero(Vector3(0.2, 0, 19.4))
	_pop_recount()
	_select_units(units.duplicate(), false)
	_set_banner("守住余烬核心", "第 1 波将在 %d 秒后抵达 · 框选军团，右键指挥" % int(prep_t), 3.4)
	ui.queue_redraw()


func restart_run(p_seed: int = 0) -> void:
	start_run(p_seed)


func _clear_entities() -> void:
	for a in units:
		if is_instance_valid(a):
			a.queue_free()
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	for t in towers:
		if is_instance_valid(t):
			t.queue_free()
	for p in projectiles:
		if is_instance_valid(p):
			p.queue_free()
	for f in fx:
		if is_instance_valid(f.node):
			f.node.queue_free()
	units.clear()
	enemies.clear()
	towers.clear()
	projectiles.clear()
	fx.clear()
	hero = null
	for pad in world.pads:
		pad.tower = null


func _sync_pad_visuals() -> void:
	for pad in world.pads:
		var tower = pad.get("tower", null)
		world.set_pad_available(int(pad.index), tower == null)


# ---------------------------------------------------------------- 状态

func _enter_prep(next_wave: int) -> void:
	ui_state = UI_STATE_PREP
	prep_t = D.PREP_TIME
	prep_total = D.PREP_TIME
	modifier = _roll_modifier(next_wave)
	_set_banner("第 %d 波即将开始" % next_wave,
		("修饰：%s · %s" % [modifier.name, modifier.desc]) if modifier.id != "none" else "整备军团，检查建造点", 2.8)


func _start_wave() -> void:
	if wave_index >= D.WAVES.size() or ui_state == UI_STATE_WIN or ui_state == UI_STATE_LOSE:
		return
	wave_index += 1
	wave_def = D.wave_def(wave_index - 1)
	wave_total = 0
	wave_killed = 0
	wave_elapsed = 0.0
	spawn_queue.clear()
	var groups_def: Array = wave_def.groups
	var at := 0.0
	var spacing := float(wave_def.spacing)
	for g in groups_def:
		var kind: String = g.type
		var count := int(g.count)
		var lane := int(g.lane)
		var m_count := maxi(1, int(round(count * float(modifier.count))))
		for k in m_count:
			spawn_queue.append({"at": at + k * spacing, "kind": kind, "lane": lane})
		if bool(modifier.extra_lane):
			var extra := (lane + 1) % 3
			var ec := maxi(1, int(round(count * 0.5)))
			for k in ec:
				spawn_queue.append({"at": at + 0.35 + k * spacing, "kind": kind, "lane": extra})
		at += m_count * spacing + 0.7
	spawn_queue.sort_custom(func(a, b): return a.at < b.at)
	wave_total = spawn_queue.size()
	spawn_left = spawn_queue.size()
	ui_state = UI_STATE_WAVE
	var sub := ""
	if modifier.id != "none":
		sub = "波次修饰：%s · %s" % [modifier.name, modifier.desc]
	_set_banner("第 %d 波 · %s" % [wave_index, wave_def.name], sub, 2.6)
	if modifier.id != "none":
		game_shake(0.05)
	ui.queue_redraw()


func _finish_wave() -> void:
	if ui_state != UI_STATE_WAVE:
		return
	var wd: Dictionary = wave_def
	var reward_gold := int(round(float(wd.reward_gold) * stats.wave_gold * float(modifier.get("gold", 1.0))))
	var reward_ess := int(wd.reward_essence)
	gold += reward_gold
	essence += reward_ess
	gold_earned += reward_gold
	essence_earned += reward_ess
	if wave_index >= D.WAVES.size():
		ui_state = UI_STATE_WIN
		paused = false
		_set_banner("裂隙肃清", "余烬核心守住了最后一波", 5.0)
		ui.queue_redraw()
		return
	_set_banner("第 %d 波肃清" % wave_index,
		"+%d 金币  +%d 精粹" % [reward_gold, reward_ess], 3.0)
	ui_state = UI_STATE_UPGRADE
	paused = false
	_roll_upgrades()
	ui.queue_redraw()


func _roll_upgrades() -> void:
	upgrade_choices.clear()
	var available: Array[String] = []
	for def in D.UPGRADE_POOL:
		var lv := int(upgrade_levels.get(def.id, 0))
		if lv < int(def.max):
			available.append(def.id)
	_upgrade_rng.seed = int(seed_value) * 31 + wave_index * 7919 + rerolls_used * 101
	var picked: Array[String] = []
	while picked.size() < 3 and not available.is_empty():
		var idx := _upgrade_rng.randi_range(0, available.size() - 1)
		picked.append(available[idx])
		available.remove_at(idx)
	upgrade_choices = picked


func _roll_modifier(next_wave: int) -> Dictionary:
	if next_wave <= 1 or next_wave > D.WAVES.size():
		return D.MODIFIERS[0]
	_wave_rng.seed = int(seed_value) + next_wave * 3571 + 19
	var idx := _wave_rng.randi_range(1, D.MODIFIERS.size() - 1)
	return D.MODIFIERS[idx]


func pick_upgrade(index: int) -> bool:
	if ui_state != UI_STATE_UPGRADE or index < 0 or index >= upgrade_choices.size():
		return false
	var id := upgrade_choices[index]
	upgrade_levels[id] = int(upgrade_levels.get(id, 0)) + 1
	_recompute_stats()
	# 生命类强化立即补足
	if id == "vigor":
		for u in units:
			if u != null and u.is_alive():
				var base_hp := float(D.unit_def(u.kind).hp)
				var old_max: float = u.max_hp
				u.max_hp = base_hp * stats.unit_hp
				u.hp += maxf(0.0, u.max_hp - old_max)
	if id == "hero" and hero != null:
		pass
	upgrade_choices.clear()
	var next_wave := mini(wave_index + 1, D.WAVES.size())
	_enter_prep(next_wave)
	ui.queue_redraw()
	return true


func reroll_upgrades() -> bool:
	if ui_state != UI_STATE_UPGRADE or rerolls_left <= 0:
		return false
	rerolls_left -= 1
	rerolls_used += 1
	_roll_upgrades()
	ui.queue_redraw()
	return true


func _recompute_stats() -> void:
	stats = {
		"unit_dmg": 1.0 + 0.18 * int(upgrade_levels.get("train", 0)),
		"unit_hp": 1.0 + 0.18 * int(upgrade_levels.get("vigor", 0)),
		"unit_speed": 1.0 + 0.12 * int(upgrade_levels.get("haste", 0)),
		"tower_range": 1.0 + 0.15 * int(upgrade_levels.get("range", 0)),
		"tower_dmg": 1.0 + 0.22 * int(upgrade_levels.get("slag", 0)),
		"wave_gold": 1.0 + 0.30 * int(upgrade_levels.get("tax", 0)),
		"essence_kill": int(upgrade_levels.get("essence", 0)),
		"hero_cd": maxf(0.35, 1.0 - 0.20 * int(upgrade_levels.get("hero", 0))),
		"tower_slow": 0.20 * int(upgrade_levels.get("frost", 0)),
	}
	pop_cap = D.START_POP_CAP + 4 * int(upgrade_levels.get("pop", 0))
	_pop_recount()


func _pop_recount() -> void:
	var p := 0
	for u in units:
		if u != null and u.is_alive() and not u.is_hero:
			p += int(D.unit_def(u.kind).pop)
	pop_used = p


# ---------------------------------------------------------------- 主循环推进

func advance(dt: float) -> void:
	if ui_state != UI_STATE_PREP and ui_state != UI_STATE_WAVE:
		return
	run_time += dt
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, float(cooldowns[k]) - dt)
	if hero_respawn_t > 0.0:
		hero_respawn_t = maxf(0.0, hero_respawn_t - dt)
		if hero_respawn_t <= 0.0 and hero == null:
			_spawn_hero(World.SPAWN_POS + Vector3(3.0, 0, 1.5))
			_set_banner("英雄归来", "焰语者 · 凯尔重返战场", 2.0)
	if ui_state == UI_STATE_PREP:
		prep_t -= dt
		if prep_t <= 0.0:
			_start_wave()
	elif ui_state == UI_STATE_WAVE:
		wave_elapsed += dt
		while not spawn_queue.is_empty() and float(spawn_queue[0].at) <= wave_elapsed:
			var s: Dictionary = spawn_queue.pop_front()
			_spawn_enemy_wave(s.kind, int(s.lane))
		spawn_left = spawn_queue.size()
	# 玩家 / 塔 / 弹体 / 敌人
	for u in units:
		if u != null and is_instance_valid(u):
			u.tick(dt)
	for t in towers:
		if t != null and is_instance_valid(t):
			t.tick(dt)
	for e in enemies:
		if e != null and is_instance_valid(e):
			e.tick(dt)
	for p in projectiles.duplicate():
		if p != null and is_instance_valid(p) and not p.done:
			p.tick(dt)
	_update_fx(dt)
	_separate_units(dt)
	_cleanup()
	_pop_recount()
	_prune_selection()
	if ui_state == UI_STATE_WAVE and spawn_queue.is_empty() and enemies.is_empty():
		_finish_wave()
	ui.queue_redraw()


func _cleanup() -> void:
	for arr in [units, enemies]:
		for i in range(arr.size() - 1, -1, -1):
			var a = arr[i]
			if a == null or not is_instance_valid(a) or (a.dead and a.death_t > 1.15):
				if a == hero:
					hero = null
				arr.remove_at(i)
				if is_instance_valid(a):
					a.queue_free()
	for i in range(projectiles.size() - 1, -1, -1):
		var p = projectiles[i]
		if p == null or not is_instance_valid(p) or p.done:
			projectiles.remove_at(i)


func _separate_units(dt: float) -> void:
	var all: Array = []
	for u in units:
		if u != null and u.is_alive():
			all.append(u)
	for e in enemies:
		if e != null and e.is_alive():
			all.append(e)
	for i in all.size():
		var a: LegionActor = all[i]
		for j in range(i + 1, all.size()):
			var b: LegionActor = all[j]
			var dx: float = b.global_position.x - a.global_position.x
			var dz: float = b.global_position.z - a.global_position.z
			var d: float = sqrt(dx * dx + dz * dz)
			var min_d: float = (a.radius + b.radius) * 0.86
			if d < min_d and d > 0.0001:
				var push: float = (min_d - d) * 0.5
				var nx: float = dx / d
				var nz: float = dz / d
				a.global_position -= Vector3(nx * push, 0, nz * push)
				b.global_position += Vector3(nx * push, 0, nz * push)
				a.position.y = maxf(0.0, world.height_at(a.position.x, a.position.z))
				b.position.y = maxf(0.0, world.height_at(b.position.x, b.position.z))


func _update_fx(dt: float) -> void:
	for i in range(fx.size() - 1, -1, -1):
		var f: Dictionary = fx[i]
		var node: Node3D = f.node
		if not is_instance_valid(node):
			fx.remove_at(i)
			continue
		f.t += dt
		var k := clampf(f.t / f.dur, 0.0, 1.0)
		match f.kind:
			"shock":
				node.scale = Vector3.ONE * lerpf(0.25, 1.0, ease(k, 0.2))
			"impact":
				node.scale = Vector3.ONE * lerpf(0.5, 1.6, ease(k, 0.2))
			"slash":
				node.scale = Vector3.ONE * lerpf(0.7, 1.3, ease(k, 0.3))
				node.rotation.z += dt * 8.0
			"beam":
				pass
			"build":
				node.scale = Vector3.ONE * lerpf(0.3, 1.0, ease(k, 0.2))
			"marker":
				node.scale = Vector3.ONE * lerpf(1.0, 0.4, k)
		if f.t >= f.dur:
			node.queue_free()
			fx.remove_at(i)


# ---------------------------------------------------------------- 生成

func _spawn_player(kind: String, pos: Vector3) -> LegionActor:
	var a := Actor.new()
	a.position = Vector3(pos.x, 0, pos.z)
	a.position.y = world.height_at(pos.x, pos.z)
	add_child(a)
	a.setup(self, kind, D.TEAM_PLAYER)
	units.append(a)
	return a


func _spawn_hero(pos: Vector3) -> LegionActor:
	var h: LegionActor = _spawn_player("hero", pos)
	hero = h
	return h


func _spawn_enemy_wave(kind: String, lane: int) -> void:
	var lane_pts: Array = world.lane_paths[lane]
	var start: Vector3 = lane_pts[0]
	var toward: Vector3 = lane_pts[1]
	var dir := (toward - start).normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var pos := start + dir * _rng.randf_range(1.2, 3.6) + side * _rng.randf_range(-1.1, 1.1)
	var hp_mult := (1.0 + 0.10 * (wave_index - 1)) * float(modifier.hp)
	var dmg_mult := (1.0 + 0.06 * (wave_index - 1)) * float(modifier.damage)
	var spd_mult := 1.0 * float(modifier.speed)
	_spawn_enemy(kind, lane, pos, hp_mult, dmg_mult, spd_mult)


func _spawn_enemy(kind: String, lane: int, pos: Vector3, hp_mult: float = 1.0,
		dmg_mult: float = 1.0, spd_mult: float = 1.0) -> LegionActor:
	var e := Actor.new()
	e.position = Vector3(pos.x, world.height_at(pos.x, pos.z), pos.z)
	add_child(e)
	e.setup(self, kind, D.TEAM_ENEMY, lane, hp_mult, dmg_mult, spd_mult)
	enemies.append(e)
	return e


# ---------------------------------------------------------------- 经济 / 招募 / 建塔

func can_afford(g: int, e: int) -> bool:
	return gold >= g and essence >= e


func spend(g: int, e: int) -> bool:
	if not can_afford(g, e):
		return false
	gold -= g
	essence -= e
	return true


func can_recruit_pop(kind: String) -> bool:
	return pop_used + int(D.unit_def(kind).pop) <= pop_cap


func recruit(kind: String) -> bool:
	if ui_state != UI_STATE_PREP and ui_state != UI_STATE_WAVE:
		return false
	if not D.UNITS.has(kind) or kind == "hero":
		return false
	var def: Dictionary = D.unit_def(kind)
	if float(cooldowns.get(kind, 0.0)) > 0.0:
		return false
	if not can_recruit_pop(kind):
		_set_banner("人口已满", "升级「扩编令」或等待单位阵亡", 1.4)
		return false
	if not spend(int(def.cost), int(def.essence)):
		return false
	cooldowns[kind] = float(def.cooldown)
	var pos := World.SPAWN_POS + Vector3(_rng.randf_range(-2.4, 2.4), 0, _rng.randf_range(-1.2, 1.6))
	var u: LegionActor = _spawn_player(kind, pos)
	if rally_point_set:
		u.command_move(rally_point + Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-0.8, 0.8)))
	fx_build(pos, D.C_TEAL)
	_pop_recount()
	return true


func build_tower_at_selected(kind: String) -> bool:
	if selected_pad_index < 0 or selected_pad_index >= world.pads.size():
		return false
	if not D.TOWERS.has(kind):
		return false
	var pad: Dictionary = world.pads[selected_pad_index]
	if pad.get("tower", null) != null:
		return false
	var def: Dictionary = D.tower_def(kind)
	if not spend(int(def.cost), int(def.essence)):
		return false
	var tower := Tower.new()
	tower.position = pad.pos + Vector3(0, world.height_at(pad.pos.x, pad.pos.z) + 0.02, 0)
	add_child(tower)
	tower.setup(self, selected_pad_index, kind)
	pad.tower = tower
	towers.append(tower)
	world.set_pad_available(selected_pad_index, false)
	tower.set_selected(true)
	fx_build(pad.pos, Color(def.accent))
	_set_banner("已建造 · %s" % def.name, def.role, 1.6)
	return true


func upgrade_selected_tower() -> bool:
	if selected_pad_index < 0:
		return false
	var pad: Dictionary = world.pads[selected_pad_index]
	var tower = pad.get("tower", null)
	if tower == null:
		return false
	return tower.upgrade()


func sell_selected_tower() -> bool:
	if selected_pad_index < 0:
		return false
	var pad: Dictionary = world.pads[selected_pad_index]
	var tower = pad.get("tower", null)
	if tower == null:
		return false
	var sv: Array = tower.sell_value()
	gold += int(sv[0])
	essence += int(sv[1])
	gold_earned += int(sv[0])
	towers.erase(tower)
	pad.tower = null
	world.set_pad_available(selected_pad_index, true)
	fx_build(tower.global_position, D.C_EMBER)
	tower.queue_free()
	ui.queue_redraw()
	return true


# ---------------------------------------------------------------- 战斗结算

func find_nearest_enemy(pos: Vector3, radius: float, exclude: LegionActor = null) -> LegionActor:
	var best: LegionActor = null
	var bd := radius
	for e in enemies:
		if e == null or e == exclude or not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - pos.x, e.global_position.z - pos.z).length()
		if d < bd:
			bd = d
			best = e
	return best


func find_nearest_player(pos: Vector3, radius: float, exclude: LegionActor = null) -> LegionActor:
	var best: LegionActor = null
	var bd := radius
	for u in units:
		if u == null or u == exclude or not u.is_alive():
			continue
		var d := Vector2(u.global_position.x - pos.x, u.global_position.z - pos.z).length()
		if d < bd:
			bd = d
			best = u
	return best


func on_actor_died(a: LegionActor, from_player: bool) -> void:
	if a.is_enemy:
		kills += 1
		wave_killed += 1
		var mult := float(modifier.get("gold", 1.0))
		var g := int(round(float(a.gold_reward) * mult))
		var e := int(a.essence_reward) + int(stats.essence_kill)
		gold += g
		essence += e
		gold_earned += g
		essence_earned += e
		fx_impact(a.global_position + Vector3(0, 0.4, 0), Color("#c47bff"), 1.0)
		if a.kind == "colossus":
			game_shake(0.28)
		_prune_selection()
	else:
		if a == hero:
			hero = null
			hero_respawn_t = D.HERO_RESPAWN
			_set_banner("英雄阵亡", "%.0f 秒后在兵营复活" % D.HERO_RESPAWN, 2.2)
			game_shake(0.2)
		_pop_recount()


func damage_core(amount: float) -> void:
	if ui_state == UI_STATE_LOSE or core_hp <= 0.0:
		return
	core_hp = maxf(0.0, core_hp - amount)
	fx_impact(world.CORE_POS + Vector3(0, 2.2, 0), D.C_BLOOD, 1.4)
	game_shake(0.22)
	if core_hp <= 0.0:
		core_hp = 0.0
		ui_state = UI_STATE_LOSE
		paused = false
		_set_banner("核心失守", "虚空蠕群突破了三线防线", 5.0)
		ui.queue_redraw()


func spawn_projectile(kind: String, from: Vector3, target: LegionActor, dmg: float,
		team: int, aoe: float = 0.0, slow: float = 0.0, slow_time: float = 0.0) -> void:
	var p: LegionProjectile = Projectile.new()
	add_child(p)
	p.setup(kind, from, target, dmg, team, aoe, slow, slow_time)
	projectiles.append(p)


func on_projectile_hit(p: LegionProjectile) -> void:
	var pos := p.global_position
	var color := D.C_ESSENCE
	match p.kind:
		"fire": color = Color("#ff9a4f")
		"mortar": color = Color("#ffb35c")
		"acid": color = Color("#b5ff8e")
		"frost": color = D.C_ICE
	if p.aoe > 0.0:
		fx_shockwave(pos, p.aoe, color, 0.35)
		if p.team == D.TEAM_PLAYER:
			for e in enemies.duplicate():
				if e != null and e.is_alive() and _dist_xz(e.global_position, pos) <= p.aoe:
					e.take_damage(p.damage, true)
					if p.slow > 0.0:
						e.apply_slow(p.slow, p.slow_time)
		else:
			for u in units.duplicate():
				if u != null and u.is_alive() and _dist_xz(u.global_position, pos) <= p.aoe:
					u.take_damage(p.damage, false)
		fx_impact(pos, color, maxf(0.7, p.aoe * 0.5))
	else:
		if p.target != null and is_instance_valid(p.target) and p.target.is_alive():
			p.target.take_damage(p.damage, p.team == D.TEAM_PLAYER)
			if p.slow > 0.0:
				p.target.apply_slow(p.slow, p.slow_time)
			fx_impact(pos, color, 0.6)
		else:
			fx_impact(pos, color, 0.4)


func _dist_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---------------------------------------------------------------- 英雄技能

func hero_skill_cooldown() -> float:
	return 20.0 * float(stats.get("hero_cd", 1.0))


func hero_skill() -> bool:
	if hero == null or not hero.is_alive() or hero.skill_cd > 0.0:
		return false
	if ui_state == UI_STATE_UPGRADE or ui_state == UI_STATE_WIN or ui_state == UI_STATE_LOSE:
		return false
	hero.skill_cd = hero_skill_cooldown()
	var lv := int(upgrade_levels.get("hero", 0))
	var radius := 9.0
	var dmg := 72.0 * (1.0 + 0.20 * lv) * float(stats.unit_dmg)
	for e in enemies.duplicate():
		if e != null and e.is_alive() and _dist_xz(e.global_position, hero.global_position) <= radius:
			e.take_damage(dmg, true)
			e.apply_slow(0.5, 2.5)
	fx_shockwave(hero.global_position, radius, Color("#ffb35c"), 0.55)
	fx_impact(hero.global_position + Vector3(0, 0.8, 0), Color("#ffd36a"), 1.6)
	game_shake(0.26)
	ui.queue_redraw()
	return true


# ---------------------------------------------------------------- 选择 / 指挥

func _select_units(list: Array, additive: bool) -> void:
	if not additive:
		selected_units.clear()
	for u in list:
		if u != null and is_instance_valid(u) and u.is_alive() and not selected_units.has(u):
			selected_units.append(u)
	selected_pad_index = -1
	barracks_selected = false
	_clear_pad_selection()
	_sync_selection_rings()


func select_all_units() -> void:
	if ui_state == UI_STATE_UPGRADE or ui_state == UI_STATE_WIN or ui_state == UI_STATE_LOSE:
		return
	_selection_clear_all()
	_select_units(units.duplicate(), false)


func _selection_clear_all() -> void:
	for u in selected_units:
		if is_instance_valid(u):
			u.set_selected(false)
	selected_units.clear()
	_clear_pad_selection()
	barracks_selected = false
	world.rally_flag.visible = false


func _clear_pad_selection() -> void:
	if selected_pad_index >= 0 and selected_pad_index < world.pads.size():
		var pad: Dictionary = world.pads[selected_pad_index]
		var t = pad.get("tower", null)
		if t != null and is_instance_valid(t):
			t.set_selected(false)
	selected_pad_index = -1
	if world.rally_flag != null:
		world.rally_flag.visible = false


func clear_selection() -> void:
	_selection_clear_all()
	ui.queue_redraw()


func _sync_selection_rings() -> void:
	for u in units:
		if u != null and is_instance_valid(u):
			u.set_selected(selected_units.has(u))
	for e in enemies:
		if e != null and is_instance_valid(e):
			e.set_selected(false)


func select_single_index(i: int) -> void:
	if i < 0 or i >= selected_units.size():
		return
	var u: LegionActor = selected_units[i]
	_selection_clear_all()
	if u != null and is_instance_valid(u) and u.is_alive():
		selected_units.append(u)
		u.set_selected(true)
	ui.queue_redraw()


func select_pad(index: int) -> void:
	if index < 0 or index >= world.pads.size():
		return
	_selection_clear_all()
	selected_pad_index = index
	var pad: Dictionary = world.pads[index]
	var t = pad.get("tower", null)
	if t != null and is_instance_valid(t):
		t.set_selected(true)
	ui.queue_redraw()


func select_barracks() -> void:
	_selection_clear_all()
	barracks_selected = true
	world.rally_flag.visible = rally_point_set
	ui.queue_redraw()


func _prune_selection() -> void:
	var changed := false
	for i in range(selected_units.size() - 1, -1, -1):
		var u: LegionActor = selected_units[i]
		if u == null or not is_instance_valid(u) or u.dead:
			selected_units.remove_at(i)
			changed = true
	for i in range(units.size()):
		if units[i] != null and is_instance_valid(units[i]):
			units[i].set_selected(selected_units.has(units[i]))
	if changed:
		ui.queue_redraw()


func command_move(p: Vector3) -> void:
	if selected_units.is_empty():
		return
	var q := clamp_to_land(p)
	for u in selected_units:
		if u != null and u.is_alive():
			u.command_move(q)
	fx_marker(q, D.C_TEAL)


func command_attack(t: LegionActor) -> void:
	if t == null or not t.is_alive() or selected_units.is_empty():
		return
	for u in selected_units:
		if u != null and u.is_alive():
			u.command_attack(t)
	fx_marker(t.global_position, Color("#ff6f7f"))


func command_attack_move(p: Vector3) -> void:
	if selected_units.is_empty():
		return
	var q := clamp_to_land(p)
	for u in selected_units:
		if u != null and u.is_alive():
			u.command_attack_move(q)
	fx_marker(q, Color("#ff8a5a"))


func stop_selected() -> void:
	for u in selected_units:
		if u != null and u.is_alive():
			u.stop()
	if not selected_units.is_empty():
		fx_marker(selected_units[0].global_position, D.C_DIM)
	ui.queue_redraw()


func arm_attack_move() -> void:
	attack_move_armed = not attack_move_armed
	ui.queue_redraw()


func set_rally(p: Vector3) -> void:
	rally_point = clamp_to_land(p)
	rally_point_set = true
	world.rally_flag.position = rally_point + Vector3(0, world.height_at(rally_point.x, rally_point.z), 0)
	world.rally_flag.visible = true
	fx_marker(rally_point, D.C_TEAL)
	_set_banner("集结点已设置", "新招募单位将前往此处", 1.5)


func clamp_to_land(p: Vector3) -> Vector3:
	var x := clampf(p.x, -44.0, 44.0)
	var z := clampf(p.z, -50.0, 44.0)
	if world.island_mask(x, z) >= 0.20:
		return Vector3(x, 0, z)
	for r in range(1, 15):
		for i in 8:
			var a := i * TAU / 8.0
			var xx := x + cos(a) * r * 1.2
			var zz := z + sin(a) * r * 1.2
			if world.island_mask(xx, zz) >= 0.20:
				return Vector3(xx, 0, zz)
	return World.CORE_POS + Vector3(0, 0, -2)


func jump_camera_world(p: Vector3) -> void:
	world.set_camera(p, world.get_cam_dist())


func select_pad_at_world(pos: Vector3) -> void:
	var best := -1
	var bd := 3.2
	for pad in world.pads:
		var d := _dist_xz(pos, pad.pos)
		if d < bd:
			bd = d
			best = int(pad.index)
	if best >= 0:
		select_pad(best)


# ---------------------------------------------------------------- 输入

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	var key := event.keycode
	# 三选一 / 结算优先
	if ui_state == UI_STATE_UPGRADE:
		if key == KEY_1 or key == KEY_2 or key == KEY_3:
			pick_upgrade(key - KEY_1)
			get_viewport().set_input_as_handled()
		elif key == KEY_R:
			reroll_upgrades()
			get_viewport().set_input_as_handled()
		elif key == KEY_ESCAPE:
			pass
		return
	if ui_state == UI_STATE_WIN or ui_state == UI_STATE_LOSE:
		if key == KEY_R or key == KEY_SPACE:
			restart_run()
			get_viewport().set_input_as_handled()
		return
	match key:
		KEY_SPACE:
			toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_TAB:
			toggle_speed()
			get_viewport().set_input_as_handled()
		KEY_H:
			ui.set_help_visible(not ui.is_help_visible())
			get_viewport().set_input_as_handled()
		KEY_A:
			if not ui.is_point_blocked(get_viewport().get_mouse_position()):
				arm_attack_move()
			get_viewport().set_input_as_handled()
		KEY_S:
			stop_selected()
			get_viewport().set_input_as_handled()
		KEY_F:
			select_all_units()
			get_viewport().set_input_as_handled()
		KEY_Q:
			hero_skill()
			get_viewport().set_input_as_handled()
		KEY_Z:
			recruit("guard")
			get_viewport().set_input_as_handled()
		KEY_X:
			recruit("bolt")
			get_viewport().set_input_as_handled()
		KEY_C:
			recruit("adept")
			get_viewport().set_input_as_handled()
		KEY_B:
			start_next_wave_early()
			get_viewport().set_input_as_handled()
		KEY_R:
			if ui_state == UI_STATE_WIN or ui_state == UI_STATE_LOSE:
				restart_run()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			if attack_move_armed:
				attack_move_armed = false
			elif ui.is_help_visible():
				ui.set_help_visible(false)
			else:
				clear_selection()
			get_viewport().set_input_as_handled()
		KEY_1, KEY_2, KEY_3:
			# 建造面板打开且该点为空时，1/2/3 直接建塔；否则作为编队呼叫。
			if not event.ctrl_pressed and selected_pad_index >= 0 \
					and selected_pad_index < world.pads.size() \
					and world.pads[selected_pad_index].get("tower", null) == null:
				build_tower_at_selected(D.TOWER_ORDER[key - KEY_1])
			else:
				_control_group(key - KEY_0, event.ctrl_pressed)
			get_viewport().set_input_as_handled()


func _control_group(n: int, assign: bool) -> void:
	if assign:
		groups[n] = selected_units.duplicate()
		_set_banner("编队 %d 已记录" % n, "%d 个单位" % groups[n].size(), 1.2)
	else:
		var g: Array = groups.get(n, [])
		var alive: Array = []
		for u in g:
			if u != null and is_instance_valid(u) and u.is_alive():
				alive.append(u)
		if not alive.is_empty():
			_selection_clear_all()
			_select_units(alive, false)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var pos := event.position
	if event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not ui.is_point_blocked(pos):
				world.zoom_camera(-4.0)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not ui.is_point_blocked(pos):
				world.zoom_camera(4.0)
			get_viewport().set_input_as_handled()
			return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if ui.is_modal() or ui.is_point_blocked(pos):
				ui.handle_click(pos)
				get_viewport().set_input_as_handled()
				return
			drag_active = true
			drag_start = pos
			drag_end = pos
			get_viewport().set_input_as_handled()
		else:
			if drag_active:
				drag_end = pos
				var moved := drag_start.distance_to(drag_end)
				drag_active = false
				if moved > 7.0:
					_box_select(Rect2(drag_start, drag_end - drag_start).abs())
				else:
					_left_click(drag_end)
				get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			if ui.is_modal() or ui.is_point_blocked(pos):
				return
			_right_click(pos)
			get_viewport().set_input_as_handled()
	elif event.button_index == MOUSE_BUTTON_MIDDLE:
		_middle_drag = event.pressed
		get_viewport().set_input_as_handled()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	drag_end = event.position
	if _middle_drag:
		var scale: float = world.get_cam_dist() / 700.0
		world.pan_camera(Vector3(-event.relative.x * scale, 0, -event.relative.y * scale))
		get_viewport().set_input_as_handled()
	ui.handle_hover(event.position)


func _left_click(pos: Vector2) -> void:
	var ground: Vector3 = world.screen_to_ground(pos)
	if ground == Vector3.INF:
		return
	if attack_move_armed:
		command_attack_move(ground)
		attack_move_armed = false
		return
	# 优先点选单位
	var best: LegionActor = null
	var bd := 1.35
	for u in units:
		if u == null or not u.is_alive():
			continue
		var d := _dist_xz(ground, u.global_position)
		if d < bd:
			bd = d
			best = u
	if best != null:
		if Input.is_key_pressed(KEY_SHIFT):
			if selected_units.has(best):
				selected_units.erase(best)
				best.set_selected(false)
			else:
				selected_units.append(best)
				best.set_selected(true)
			selected_pad_index = -1
			barracks_selected = false
		else:
			_selection_clear_all()
			selected_units.append(best)
			best.set_selected(true)
		ui.queue_redraw()
		return
	# 建造点
	var best_pad := -1
	var bpd := 2.8
	for pad in world.pads:
		var d := _dist_xz(ground, pad.pos)
		if d < bpd:
			bpd = d
			best_pad = int(pad.index)
	if best_pad >= 0:
		select_pad(best_pad)
		return
	# 兵营
	if _dist_xz(ground, World.BARRACKS_POS) < 4.0:
		select_barracks()
		return
	_selection_clear_all()
	ui.queue_redraw()


func _right_click(pos: Vector2) -> void:
	if barracks_selected:
		var gp: Vector3 = world.screen_to_ground(pos)
		if gp != Vector3.INF:
			set_rally(gp)
			return
	var ground: Vector3 = world.screen_to_ground(pos)
	if ground == Vector3.INF:
		return
	attack_move_armed = false
	# 优先攻击点到的敌人
	var best: LegionActor = null
	var bd := 2.0
	for e in enemies:
		if e == null or not e.is_alive():
			continue
		var d := _dist_xz(ground, e.global_position) + e.radius
		if d < bd:
			bd = d
			best = e
	if best != null:
		command_attack(best)
	else:
		command_move(ground)


func _box_select(rect: Rect2) -> void:
	var additive := Input.is_key_pressed(KEY_SHIFT)
	var picked: Array = []
	for u in units:
		if u == null or not u.is_alive():
			continue
		var sp: Vector2 = world.world_to_screen(u.global_position + Vector3(0, 0.8, 0))
		if rect.has_point(sp):
			picked.append(u)
	if picked.is_empty() and not additive:
		_selection_clear_all()
		ui.queue_redraw()
		return
	_select_units(picked, additive)
	ui.queue_redraw()


func _camera_keys(delta: float) -> void:
	if ui.is_modal():
		return
	var v := Vector3.ZERO
	if Input.is_key_pressed(KEY_UP):
		v.z -= 1
	if Input.is_key_pressed(KEY_DOWN):
		v.z += 1
	if Input.is_key_pressed(KEY_LEFT):
		v.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		v.x += 1
	if v != Vector3.ZERO:
		var speed_cam: float = (24.0 + world.get_cam_dist() * 0.32) * delta
		world.pan_camera(v.normalized() * speed_cam)


func _edge_scroll(mouse: Vector2, delta: float) -> void:
	if ui.is_modal() or ui.is_point_blocked(mouse):
		return
	var vs := get_viewport().get_visible_rect().size
	var edge := 8.0
	var v := Vector3.ZERO
	if mouse.x < edge:
		v.x -= 1
	elif mouse.x > vs.x - edge:
		v.x += 1
	if mouse.y < edge:
		v.z -= 1
	elif mouse.y > vs.y - edge:
		v.z += 1
	if v != Vector3.ZERO:
		var speed_cam: float = (20.0 + world.get_cam_dist() * 0.28) * delta
		world.pan_camera(v.normalized() * speed_cam)


func start_next_wave_early() -> void:
	if ui_state == UI_STATE_PREP and prep_t > 0.0:
		prep_t = 0.01


func toggle_pause() -> void:
	if ui.is_modal():
		return
	paused = not paused
	ui.queue_redraw()


func toggle_speed() -> void:
	speed = 2.0 if speed < 1.5 else 1.0
	ui.queue_redraw()


# ---------------------------------------------------------------- 特效

func fx_impact(pos: Vector3, color: Color, size: float) -> void:
	var node := Art.build_impact_burst(color, size)
	add_child(node)
	node.global_position = pos
	fx.append({"node": node, "t": 0.0, "dur": 0.26, "kind": "impact"})
	_trim_fx()


func fx_slash(pos: Vector3, color: Color, size: float) -> void:
	var node := Art.build_slash(color, size)
	add_child(node)
	node.global_position = pos + Vector3(0, 0.4, 0)
	node.rotation.y = _rng.randf_range(-0.4, 0.4)
	fx.append({"node": node, "t": 0.0, "dur": 0.20, "kind": "slash"})
	_trim_fx()


func fx_shockwave(center: Vector3, radius: float, color: Color, dur: float) -> void:
	var node := Art.build_shockwave(radius, color)
	add_child(node)
	node.global_position = center + Vector3(0, 0.05, 0)
	node.scale = Vector3.ONE * 0.25
	fx.append({"node": node, "t": 0.0, "dur": maxf(0.2, dur), "kind": "shock"})
	_trim_fx()


func fx_beam(a: Vector3, b: Vector3, color: Color, dur: float) -> void:
	var node := Node3D.new()
	add_child(node)
	var dist := a.distance_to(b)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.045
	mesh.bottom_radius = 0.075
	mesh.height = maxf(0.1, dist)
	mesh.radial_segments = 5
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Art.glow_mat(Color(color.r, color.g, color.b, 0.85))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	node.global_position = (a + b) * 0.5
	var dir := (b - a).normalized()
	if dir.length_squared() > 0.001:
		node.quaternion = Quaternion(Vector3.UP, dir)
	fx.append({"node": node, "t": 0.0, "dur": dur, "kind": "beam"})
	_trim_fx()


func fx_build(pos: Vector3, color: Color) -> void:
	var node := Art.build_shockwave(2.2, color)
	add_child(node)
	node.global_position = pos + Vector3(0, 0.05, 0)
	node.scale = Vector3.ONE * 0.3
	fx.append({"node": node, "t": 0.0, "dur": 0.5, "kind": "build"})
	fx_impact(pos + Vector3(0, 1.0, 0), color, 0.9)
	_trim_fx()


func fx_marker(pos: Vector3, color: Color) -> void:
	var node := Art.build_shockwave(1.8, color)
	add_child(node)
	node.global_position = pos + Vector3(0, 0.07, 0)
	fx.append({"node": node, "t": 0.0, "dur": 0.4, "kind": "marker"})
	_trim_fx()


func _trim_fx() -> void:
	while fx.size() > MAX_FX:
		var f: Dictionary = fx[0]
		if is_instance_valid(f.node):
			f.node.queue_free()
		fx.remove_at(0)


func game_shake(amount: float) -> void:
	_shake_amp = maxf(_shake_amp, amount)
	_shake_t = 0.16


func shake(amount: float) -> void:
	game_shake(amount)


func _set_banner(text: String, sub: String = "", dur: float = 2.5) -> void:
	banner_text = text
	banner_sub = sub
	banner_t = dur
	if ui != null:
		ui.queue_redraw()


# ---------------------------------------------------------------- 调试 / 验收 API

func debug_add_resources(g: int, e: int) -> void:
	gold += g
	essence += e


func debug_spawn_unit(kind: String, pos: Vector3) -> LegionActor:
	var u: LegionActor = _spawn_player(kind, pos)
	_pop_recount()
	return u


func debug_spawn_enemy(kind: String, lane: int, pos: Vector3, hp_mult: float = 1.0,
		dmg_mult: float = 1.0, spd_mult: float = 1.0) -> LegionActor:
	return _spawn_enemy(kind, lane, pos, hp_mult, dmg_mult, spd_mult)


func debug_start_wave(n: int) -> void:
	wave_index = clampi(n - 1, 0, D.WAVES.size() - 1)
	modifier = _roll_modifier(n)
	ui_state = UI_STATE_PREP
	prep_t = 0.01
	prep_total = 0.01
	advance(0.02)


func debug_force_upgrade() -> void:
	ui_state = UI_STATE_UPGRADE
	_roll_upgrades()


func debug_win() -> void:
	wave_index = D.WAVES.size()
	wave_def = D.wave_def(D.WAVES.size() - 1)
	ui_state = UI_STATE_WIN
	ui.queue_redraw()


func debug_lose() -> void:
	core_hp = 0.0
	ui_state = UI_STATE_LOSE
	ui.queue_redraw()


func debug_kill_all() -> void:
	for e in enemies.duplicate():
		if e != null and e.is_alive():
			e.take_damage(99999.0, true)
	spawn_queue.clear()
	spawn_left = 0


func debug_set_wave_progress(wave: int, killed: int = 0) -> void:
	wave_index = clampi(wave, 1, D.WAVES.size())
	wave_def = D.wave_def(wave_index - 1)
	wave_total = 12
	wave_killed = killed
	spawn_left = 0


func simulate(seconds: float, step: float = 1.0 / 60.0) -> void:
	var t := 0.0
	while t < seconds:
		advance(minf(step, seconds - t))
		t += step
