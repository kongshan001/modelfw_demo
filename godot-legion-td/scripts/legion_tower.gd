class_name LegionTower
extends Node3D

# 固定建造点上的塔：自动索敌；棱镜单体光束 / 熔渣范围炮击 / 暮霜范围减速。
# 塔本身不受伤，靠射程与升级参与防守；升级重建模型，出售返还 60% 投入。

const D := preload("res://scripts/legion_data.gd")
const Art := preload("res://scripts/legion_art.gd")

var game: Node
var pad_index := 0
var kind := "prism"
var level := 1
var model: Node3D
var rig: Dictionary = {}
var cooldown := 0.0
var target: LegionActor = null
var range_ring: Node3D
var selected := false
var flash := 0.0
var _time := 0.0
var _head: Node3D
var _crystal: MeshInstance3D
var total_gold := 0
var total_essence := 0


func setup(p_game: Node, p_pad: int, p_kind: String) -> void:
	game = p_game
	pad_index = p_pad
	kind = p_kind
	level = 1
	var def: Dictionary = D.tower_def(kind)
	total_gold = int(def.cost)
	total_essence = int(def.essence)
	_build_model()
	range_ring = Art.build_range_ring(10.0, Color(def.accent), 0.5)
	range_ring.visible = false
	add_child(range_ring)
	set_process(false)


func _build_model() -> void:
	if model != null:
		model.queue_free()
	rig = Art.build_tower(kind, level)
	model = rig.root
	add_child(model)
	_head = rig.head
	_crystal = rig.get("crystal", null)


func effective_damage() -> float:
	var def: Dictionary = D.tower_def(kind)
	return float(def.damage) * (1.0 + 0.5 * (level - 1)) * game.stats.tower_dmg


func effective_range() -> float:
	var def: Dictionary = D.tower_def(kind)
	return float(def.range) * (1.0 + 0.08 * (level - 1)) * game.stats.tower_range


func effective_interval() -> float:
	var def: Dictionary = D.tower_def(kind)
	return float(def.interval) * (1.0 - 0.05 * (level - 1))


func effective_slow() -> float:
	var def: Dictionary = D.tower_def(kind)
	return maxf(float(def.slow), game.stats.tower_slow)


func upgrade_cost() -> Array:
	var def: Dictionary = D.tower_def(kind)
	if level >= D.TOWER_MAX_LEVEL:
		return [-1, -1]
	return [int(def.upgrade_gold[level]), int(def.upgrade_essence[level])]


func upgrade() -> bool:
	if level >= D.TOWER_MAX_LEVEL:
		return false
	var cost := upgrade_cost()
	if not game.spend(int(cost[0]), int(cost[1])):
		return false
	total_gold += int(cost[0])
	total_essence += int(cost[1])
	level += 1
	_build_model()
	if selected:
		_show_range()
	game.fx_build(global_position, Color(D.tower_def(kind).accent))
	return true


func sell_value() -> Array:
	return [int(round(total_gold * D.TOWER_SELL_RATE)), int(round(total_essence * D.TOWER_SELL_RATE))]


func set_selected(v: bool) -> void:
	selected = v
	if range_ring != null:
		range_ring.visible = v
		if v:
			_show_range()


func _show_range() -> void:
	if range_ring == null:
		return
	var r := effective_range()
	range_ring.scale = Vector3.ONE * (r / 10.0)
	range_ring.visible = true


func tick(dt: float) -> void:
	_time += dt
	if cooldown > 0.0:
		cooldown -= dt
	if flash > 0.0:
		flash -= dt
	if _head != null and target != null and is_instance_valid(target) and target.is_alive():
		var to: Vector3 = target.global_position - global_position
		var want := atan2(to.x, to.z)
		_head.rotation.y = lerp_angle(_head.rotation.y, want, clampf(dt * 8.0, 0.0, 1.0))
	if _crystal != null:
		_crystal.rotation.y += dt * 0.8
		var s := 1.0 + 0.03 * sin(_time * 3.0)
		_crystal.scale = _crystal.scale.lerp(Vector3(0.75 * s, 2.3 * s, 0.75 * s), 0.1)
	if target == null or not is_instance_valid(target) or not target.is_alive():
		target = null
		cooldown = minf(cooldown, 0.15)
	if kind == "frost":
		_tick_frost(dt)
		return
	if target == null:
		target = _acquire()
	if target == null:
		return
	var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if d > effective_range():
		target = null
		return
	if cooldown <= 0.0:
		_fire(target)


func _tick_frost(dt: float) -> void:
	if target == null:
		target = _acquire()
	if target == null:
		return
	var d := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
	if d > effective_range():
		target = null
		return
	if cooldown <= 0.0:
		cooldown = effective_interval()
		var r := effective_range()
		var hits := 0
		var dmg := effective_damage()
		var slow := effective_slow()
		var def: Dictionary = D.tower_def(kind)
		for e in game.enemies.duplicate():
			if e == null or not e.is_alive():
				continue
			var de := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
			if de <= r:
				e.take_damage(dmg, true)
				e.apply_slow(slow, float(def.slow_time))
				hits += 1
		game.fx_shockwave(global_position, r, Color(def.accent), 0.55)
		flash = 0.3
		if hits > 0:
			game.shake(0.04)


func _acquire() -> LegionActor:
	var best: LegionActor = null
	var best_score := -1e9
	var r := effective_range()
	for e in game.enemies:
		if e == null or not e.is_alive():
			continue
		var d := Vector2(e.global_position.x - global_position.x, e.global_position.z - global_position.z).length()
		if d > r:
			continue
		# 优先离核心更近的敌人
		var core_d := Vector2(e.global_position.x - LegionWorld.CORE_POS.x,
			e.global_position.z - LegionWorld.CORE_POS.z).length()
		var score := -core_d - d * 0.15
		if score > best_score:
			best_score = score
			best = e
	return best


func _fire(t: LegionActor) -> void:
	cooldown = effective_interval()
	flash = 0.22
	var def: Dictionary = D.tower_def(kind)
	var muzzle := global_position + Vector3(0, rig.get("muzzle", Vector3(0, 2.0, 0)).y, 0)
	var enchant_slow: float = game.stats.get("tower_slow", 0.0)
	if kind == "prism":
		game.fx_beam(global_position + Vector3(0, rig.muzzle.y, 0),
			t.global_position + Vector3(0, t.height * 0.55, 0), Color(def.accent), 0.12)
		t.take_damage(effective_damage(), true)
		if enchant_slow > 0.0:
			t.apply_slow(enchant_slow, 1.2)
		game.fx_impact(t.global_position + Vector3(0, t.height * 0.5, 0), Color(def.accent), 0.55)
	elif kind == "mortar":
		game.spawn_projectile("mortar", muzzle, t, effective_damage(), D.TEAM_PLAYER,
			float(def.aoe), enchant_slow, 1.2)
		game.shake(0.05)


func flash_hit() -> void:
	flash = 0.15
