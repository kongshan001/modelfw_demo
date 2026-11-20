class_name GardenHero
extends Node3D

# 玩家主角（小女孩模型）：A* 网格寻路、任务目标、自动战斗、手动点击覆盖。
# 任务阶段：accept（走到石像）→ fight（清 3 只妖灵）→ return（回石像）→ complete。

signal hp_changed(current: int, max_hp: int)
signal downed
signal respawned

var world: Node
var quest: GardenQuest
var monsters: Array = []
var shadow_texture: Texture2D
var halo_texture: Texture2D

var max_hp := 220
var hp := 220
var speed := 2.6
var attack_damage := 16
var attack_range := 1.7
var attack_cooldown := 0.72
var respawn_position := Vector3.ZERO
var turn_in_position := Vector3.ZERO

const KNIGHT_PATH := "res://assets/models/kaykit/Knight.glb"
const KNIGHT_SCALE := 0.74
const KNIGHT_HIDDEN := ["1H_Sword_Offhand", "2H_Sword", "Badge_Shield", "Rectangle_Shield", "Round_Shield", "Spike_Shield", "Knight_Cape"]

var _model: GardenGirl
var _knight: Node3D
var _knight_player: AnimationPlayer
var _knight_anim := ""
var _attack_anim_timer := 0.0
var _ring: MeshInstance3D
var _path: Array[Vector3] = []
var _path_index := 0
var _path_target := Vector3.ZERO
var _manual_timer := 0.0
var _target: GardenMonster
var _attack_timer := 0.0
var _downed := false
var _respawn_timer := 0.0
var _time := 0.0

func _ready() -> void:
	_build()
	if quest != null:
		quest.stage_changed.connect(_on_stage_changed)

func _build() -> void:
	_model = GardenGirl.new()
	_model.name = "HeroModel"
	_model.shadow_texture = shadow_texture
	_model.scale = Vector3.ONE * 0.95
	_set_walking(false)
	add_child(_model)
	if _build_knight():
		_model.visible = false

	if halo_texture != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.8, 1.8)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_texture = halo_texture
		material.albedo_color = Color(1.0, 0.8, 0.38, 0.32)
		material.disable_receive_shadows = true
		quad.material = material
		_ring = MeshInstance3D.new()
		_ring.mesh = quad
		_ring.material_override = material
		_ring.rotation.x = -PI * 0.5
		_ring.position.y = 0.035
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)

func _build_knight() -> bool:
	if OS.has_environment("GARDEN_FORCE_PROCEDURAL"):
		return false
	if not ResourceLoader.exists(KNIGHT_PATH):
		return false
	var packed := load(KNIGHT_PATH) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		return false
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation("Idle") or not player.has_animation("Running_A"):
		model.free()
		return false
	var root := Node3D.new()
	root.name = "HeroKnight"
	root.rotation.y = PI
	root.scale = Vector3.ONE * KNIGHT_SCALE
	add_child(root)
	root.add_child(model)
	_knight = root
	_knight_player = player
	player.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
	player.get_animation("Running_A").loop_mode = Animation.LOOP_LINEAR
	for node in _all_nodes(model):
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if KNIGHT_HIDDEN.has(String(mi.name)):
				mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if mi.mesh != null:
				for index in mi.mesh.get_surface_count():
					var src := mi.get_active_material(index) as StandardMaterial3D
					if src == null:
						continue
					var tuned := src.duplicate() as StandardMaterial3D
					tuned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					tuned.roughness = 0.98
					tuned.metallic = 0.0
					tuned.metallic_specular = 0.05
					mi.set_surface_override_material(index, tuned)
	if shadow_texture != null:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.9, 0.9)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = shadow_texture
		mat.albedo_color = Color(1, 1, 1, 0.45)
		mat.disable_receive_shadows = true
		quad.material = mat
		var shadow := MeshInstance3D.new()
		shadow.mesh = quad
		shadow.material_override = mat
		shadow.rotation.x = -PI * 0.5
		shadow.position = Vector3(0, 0.02, 0)
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(shadow)
	player.play("Idle")
	return true

func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out

func _set_walking(value: bool) -> void:
	if _model != null:
		_model.walking = value
	if _knight_player == null or _attack_anim_timer > 0.0:
		return
	var state := "walk" if value else "idle"
	if state == _knight_anim:
		return
	_knight_anim = state
	if value:
		_knight_player.play("Running_A", 0.15, 1.6)
	else:
		_knight_player.play("Idle", 0.2)

func _process(delta: float) -> void:
	_time += delta
	_attack_anim_timer = maxf(0.0, _attack_anim_timer - delta)
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_manual_timer = maxf(0.0, _manual_timer - delta)

	if _downed:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			_respawn()
		return
	if quest == null or world == null:
		return

	if quest.stage == GardenQuest.STAGE_ACCEPT:
		_go_to_quest_giver(delta, false)
		return
	if quest.stage == GardenQuest.STAGE_RETURN:
		_go_to_quest_giver(delta, true)
		return
	if quest.stage == GardenQuest.STAGE_COMPLETE:
		_stop_walk()
		return

	if _manual_timer > 0.0:
		if _target != null and is_instance_valid(_target) and _target.is_alive():
			_engage(_target, delta)
		else:
			_follow_path(delta)
		return

	if _target == null or not is_instance_valid(_target) or not _target.is_alive():
		_target = _nearest_monster()
	if _target != null:
		_engage(_target, delta)
	else:
		_stop_walk()

# ---------------------------------------------------------------- 任务/寻路

func _go_to_quest_giver(delta: float, turn_in: bool) -> void:
	var giver: Vector3 = world.quest_giver_position()
	var flat := Vector2(global_position.x - giver.x, global_position.z - giver.z)
	if flat.length() <= 3.45:
		_stop_walk()
		if turn_in:
			quest.turn_in()
		else:
			quest.accept()
		return
	if _path.is_empty() or _path_target.distance_to(turn_in_position) > 0.6:
		_path = world.find_path(global_position, turn_in_position)
		_path_index = 0
		_path_target = turn_in_position
	_follow_path(delta)

func command_move(point: Vector3) -> void:
	if _downed:
		return
	_target = null
	_manual_timer = 5.0
	_path = world.find_path(global_position, point)
	_path_index = 0
	_path_target = point
	if world.has_method("spawn_click_marker"):
		world.spawn_click_marker(point)

func command_attack(monster: GardenMonster) -> void:
	if _downed or monster == null or not is_instance_valid(monster) or not monster.is_alive():
		return
	_target = monster
	_manual_timer = 8.0
	_path.clear()
	_path_index = 0
	_path_target = monster.global_position

func _engage(target: GardenMonster, delta: float) -> void:
	if not is_instance_valid(target) or not target.is_alive():
		_target = null
		_stop_walk()
		return
	var offset: Vector3 = target.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	_face(offset)
	if distance > attack_range:
		if _path.is_empty() or _path_target.distance_to(target.global_position) > 1.0:
			_path = world.find_path(global_position, target.global_position)
			_path_index = 0
			_path_target = target.global_position
		_follow_path(delta)
	else:
		_stop_walk()
		if _attack_timer <= 0.0:
			_attack_timer = attack_cooldown
			_attack(target)

func _nearest_monster() -> GardenMonster:
	var best: GardenMonster = null
	var best_distance := 1e20
	for candidate in monsters:
		if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive():
			continue
		var d := global_position.distance_squared_to(candidate.global_position)
		if d < best_distance:
			best_distance = d
			best = candidate
	return best

func _follow_path(delta: float) -> void:
	while _path_index < _path.size():
		var waypoint: Vector3 = _path[_path_index]
		var offset := waypoint - global_position
		offset.y = 0.0
		if offset.length() <= 0.2:
			_path_index += 1
			continue
		var step := minf(speed * delta, offset.length())
		position += offset.normalized() * step
		_face(offset)
		_set_walking(true)
		return
	_path.clear()
	_path_index = 0
	_stop_walk()

func _stop_walk() -> void:
	_set_walking(false)

func _face(offset: Vector3) -> void:
	if offset.length_squared() > 0.001:
		rotation.y = atan2(-offset.x, -offset.z)

# ---------------------------------------------------------------- 战斗

func _attack(target: GardenMonster) -> void:
	target.take_damage(attack_damage)
	if _knight_player != null:
		_knight_anim = "attack"
		_attack_anim_timer = 0.55
		_knight_player.play("1H_Melee_Attack_Chop", 0.08, 1.2)
	_set_walking(false)
	var tween := create_tween()
	tween.tween_property(_knight if _knight != null else _model, "position:z", -0.18, 0.07)
	tween.tween_property(_knight if _knight != null else _model, "position:z", 0.0, 0.14)
	if halo_texture != null:
		var sprite := Sprite3D.new()
		sprite.texture = halo_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		sprite.pixel_size = 0.01
		sprite.modulate = Color(1.0, 0.82, 0.38, 0.65)
		sprite.position = target.global_position + Vector3(0, 0.75, 0)
		get_parent().add_child(sprite)
		var flash := create_tween().set_parallel(true)
		flash.tween_property(sprite, "scale", Vector3.ONE * 2.4, 0.22)
		flash.tween_property(sprite, "modulate:a", 0.0, 0.26)
		flash.chain().tween_callback(sprite.queue_free)

func take_damage(amount: int) -> void:
	if _downed:
		return
	hp = maxi(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	_spawn_damage_number("-%d" % amount, Color(1.0, 0.45, 0.32))
	if hp <= 0:
		_go_down()

func is_downed() -> bool:
	return _downed

func _go_down() -> void:
	_downed = true
	_respawn_timer = 2.5
	_target = null
	_path.clear()
	_model.visible = false
	if _knight != null:
		_knight.visible = false
	_set_walking(false)
	if _ring != null:
		_ring.visible = false
	downed.emit()

func _respawn() -> void:
	_downed = false
	hp = max_hp
	global_position = respawn_position
	_model.visible = _knight == null
	if _knight != null:
		_knight.visible = true
		_knight_anim = ""
		_knight_player.play("Idle", 0.2)
	if _ring != null:
		_ring.visible = true
	hp_changed.emit(hp, max_hp)
	respawned.emit()

func _on_stage_changed(_stage: String) -> void:
	_target = null
	_path.clear()
	_path_index = 0

# ---------------------------------------------------------------- 反馈

func _spawn_damage_number(text: String, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = ThemeDB.fallback_font
	label.font_size = 56
	label.pixel_size = 0.004
	label.outline_size = 9
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = global_position + Vector3(0, 1.25, 0)
	get_parent().add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 0.7, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.1)
	tween.chain().tween_callback(label.queue_free)
