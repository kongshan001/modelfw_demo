extends Node3D

# 玩家：WASD 移动 / Shift 奔跑 / Tab 切换角色。
#
# 角色列表：
#   Michelle — 隐藏 Soldier 骨架 + RetargetModifier3D 重定向
#   Soldier  — 原生 Mixamo 动画
#   Xbot     — 原生 Mixamo 动画
# 三条 rig 都挂在同一个 Player 下，切换时只切换可见性与 AnimationPlayer。

signal state_changed(state: String)
signal character_changed(character_name: String)

const SOLDIER_SCENE := preload("res://assets/characters/Soldier.glb")
const MICHELLE_SCENE := preload("res://assets/characters/Michelle.glb")
const XBOT_SCENE := preload("res://assets/characters/Xbot.glb")

const WALK_SPEED := 1.7
const RUN_SPEED := 3.8

var _rigs: Array[Dictionary] = []
var _active := 0
var _state := "Idle"
var _demo_override := false
var _demo_dir := Vector2.ZERO
var _demo_run := false
var _label: Label3D
var _dance_rig: Dictionary = {}
var _dancing := false

func _ready() -> void:
	await _build_michelle_rig()
	_build_native_rig("Soldier", SOLDIER_SCENE, {"Idle": "Idle", "Walk": "Walk", "Run": "Run"})
	_build_native_rig("Xbot", XBOT_SCENE, {"Idle": "idle", "Walk": "walk", "Run": "run"})
	_build_dance_rig()

	_label = Label3D.new()
	_label.name = "PlayerLabel"
	_label.position = Vector3(0.0, 2.0, 0.0)
	_label.font_size = 44
	_label.outline_size = 10
	_label.modulate = Color(0.75, 0.9, 1.0)
	_label.outline_modulate = Color(0.02, 0.02, 0.03, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.pixel_size = 0.004
	add_child(_label)

	_set_active(0)

func _process(delta: float) -> void:
	var dir := _demo_dir if _demo_override else _read_input()
	var running := _demo_run if _demo_override else Input.is_key_pressed(KEY_SHIFT)
	var moving := dir.length_squared() > 0.001

	if _dancing:
		if moving:
			_end_dance()
		else:
			return

	var next_state := "Idle"
	if moving:
		next_state = "Run" if running else "Walk"
	if next_state != _state:
		_state = next_state
		_play_state(_state)
		state_changed.emit(_state)

	if moving:
		dir = dir.normalized()
		var yaw := atan2(dir.x, dir.y)
		rotation.y = lerp_angle(rotation.y, yaw, min(1.0, delta * 10.0))
		var speed := RUN_SPEED if running else WALK_SPEED
		position += Vector3(dir.x, 0.0, dir.y) * speed * delta

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_TAB:
		cycle_character()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_SPACE:
		toggle_dance()
		get_viewport().set_input_as_handled()

func cycle_character() -> void:
	if _rigs.is_empty():
		return
	_set_active((_active + 1) % _rigs.size())

func get_character_name() -> String:
	if _rigs.is_empty():
		return "Player"
	return String(_rigs[_active]["name"])

func get_state() -> String:
	return "Dance" if _dancing else _state

func set_demo_input(dir: Vector2, run: bool) -> void:
	_demo_override = true
	_demo_dir = dir
	_demo_run = run

func clear_demo_input() -> void:
	_demo_override = false

func _play_state(state: String) -> void:
	if _dancing or _rigs.is_empty():
		return
	var rig: Dictionary = _rigs[_active]
	var ap: AnimationPlayer = rig.get("ap")
	var anims: Dictionary = rig.get("anims", {})
	var anim_name := String(anims.get(state, state))
	if ap != null and ap.has_animation(anim_name):
		ap.play(anim_name, 0.2)

func _set_active(index: int, emit := true) -> void:
	if _rigs.is_empty():
		return
	if _dancing:
		_end_dance()
	_active = clampi(index, 0, _rigs.size() - 1)
	for i in _rigs.size():
		var rig: Dictionary = _rigs[i]
		var root: Node3D = rig["root"]
		root.visible = i == _active
		var ap: AnimationPlayer = rig.get("ap")
		if ap != null:
			ap.stop()
	if _dance_rig.has("root"):
		(_dance_rig["root"] as Node3D).visible = false
	_play_state(_state)
	if _label != null:
		_label.text = "Player · " + get_character_name()
	if emit:
		character_changed.emit(get_character_name())

func toggle_dance() -> void:
	if _rigs.is_empty() or get_character_name() != "Michelle":
		return
	if _dancing:
		_end_dance()
	else:
		_start_dance()

func _start_dance() -> void:
	if _dancing or _dance_rig.is_empty():
		return
	var ap: AnimationPlayer = _dance_rig.get("ap")
	if ap == null or not ap.has_animation("SambaDance"):
		return
	var active_rig: Dictionary = _rigs[_active]
	var source_ap: AnimationPlayer = active_rig.get("ap")
	if source_ap != null:
		source_ap.stop()
	(active_rig["root"] as Node3D).visible = false
	(_dance_rig["root"] as Node3D).visible = true
	ap.play("SambaDance")
	_dancing = true
	state_changed.emit("Dance")

func _end_dance() -> void:
	if not _dancing:
		return
	var ap: AnimationPlayer = _dance_rig.get("ap")
	if ap != null:
		ap.stop()
	(_dance_rig["root"] as Node3D).visible = false
	if not _rigs.is_empty():
		(_rigs[_active]["root"] as Node3D).visible = true
	_dancing = false
	_play_state(_state)
	state_changed.emit(_state)

func _build_dance_rig() -> void:
	var root := Node3D.new()
	root.name = "Rig_MichelleDance"
	add_child(root)
	var model: Node3D = MICHELLE_SCENE.instantiate()
	root.add_child(model)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	root.visible = false
	_dance_rig = {"root": root, "ap": ap}

func _build_michelle_rig() -> void:
	var rig := Node3D.new()
	rig.name = "Rig_Michelle"
	add_child(rig)

	var source: Node3D = SOLDIER_SCENE.instantiate()
	source.name = "SourceRig"
	rig.add_child(source)
	var source_skel := _find_skeleton(source)
	for mesh in source.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).visible = false
	var source_ap := source.find_child("AnimationPlayer", true, false) as AnimationPlayer

	var target: Node3D = MICHELLE_SCENE.instantiate()
	target.name = "TargetModel"
	rig.add_child(target)
	await get_tree().process_frame

	var target_skel := _find_skeleton(target)
	var target_root := target_skel.get_parent() as Node3D
	var meshes := target.find_children("*", "MeshInstance3D", true, false)

	var modifier := RetargetModifier3D.new()
	modifier.name = "Retarget"
	source_skel.add_child(modifier)
	modifier.profile = _build_profile(target_skel)
	modifier.set_position_enabled(false)
	modifier.set_scale_enabled(false)
	modifier.set_rotation_enabled(true)

	target_skel.reparent(modifier, true)
	target_root.reparent(modifier, true)
	for mesh in meshes:
		(mesh as MeshInstance3D).skeleton = mesh.get_path_to(target_skel)

	_rigs.append({
		"name": "Michelle",
		"root": rig,
		"ap": source_ap,
		"anims": {"Idle": "Idle", "Walk": "Walk", "Run": "Run"},
	})

func _build_native_rig(character_name: String, scene: PackedScene, anims: Dictionary) -> void:
	var rig := Node3D.new()
	rig.name = "Rig_" + character_name
	add_child(rig)
	var model: Node3D = scene.instantiate()
	model.name = character_name
	rig.add_child(model)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_rigs.append({
		"name": character_name,
		"root": rig,
		"ap": ap,
		"anims": anims,
	})

func _read_input() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		dir.y += 1.0
	if Input.is_key_pressed(KEY_A):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		dir.x += 1.0
	return dir

func _find_skeleton(model: Node) -> Skeleton3D:
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	return skeletons[0] as Skeleton3D

func _build_profile(skel: Skeleton3D) -> SkeletonProfile:
	var profile := SkeletonProfile.new()
	profile.bone_size = skel.get_bone_count()
	for i in skel.get_bone_count():
		profile.set_bone_name(i, skel.get_bone_name(i))
		var parent := skel.get_bone_parent(i)
		profile.set_bone_parent(i, &"" if parent < 0 else skel.get_bone_name(parent))
	profile.root_bone = skel.get_bone_name(0)
	var hips := skel.find_bone("mixamorig_Hips")
	if hips >= 0:
		profile.scale_base_bone = skel.get_bone_name(hips)
	return profile
