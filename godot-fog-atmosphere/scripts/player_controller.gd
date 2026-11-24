extends CharacterBody3D
## 第三人称角色：KayKit CC0 Rogue（缺图/加载失败时回退程序化人形）。
## WASD/方向键/左摇杆移动，Shift 奔跑；移动方向相对相机 yaw。
## 贴地行走（terrain_height）、圆形障碍推离、世界边界与深水阻挡。
## 模型/动画：Idle / Walking_A / Running_A（glTF 内嵌贴图，无外部运行库）。

const ROGUE_SCENE_PATH := "res://assets/models/kaykit/Rogue.glb"
const IDLE_ANIM := "Idle"
const WALK_ANIM := "Walking_A"
const RUN_ANIM := "Running_A"
const MODEL_SCALE := 0.74 # 2.33m 原始模型 → 约 1.73m
const MODEL_YAW_OFFSET := PI # 模型正面 +Z，角色前向约定为 -Z
const HIDDEN_MESHES := [
	"Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable", "Rogue_Cape", "Cape",
]
const WALK_SPEED := 2.0
const RUN_SPEED := 4.6
const ACCEL := 11.0
const TURN_SPEED := 12.0
const BODY_RADIUS := 0.38
const SPAWN_XZ := Vector2(1.5, 18.5)

var world: Node3D
var rig: Node3D
var fog_interaction: Node3D
var controls_enabled := true
var input_override := Vector2.ZERO
var override_active := false
var override_run := false
var uses_model := false

var model_root: Node3D
var animation_player: AnimationPlayer
var fallback_root: Node3D
var veil_material: StandardMaterial3D
var shadow_material: StandardMaterial3D
var fill_light: OmniLight3D

var _anim := ""
var _anim_time := 0.0
var _anim_speed := 0.0
var _fallback_leg_l: Node3D
var _fallback_leg_r: Node3D
var _fallback_arm_l: Node3D
var _fallback_arm_r: Node3D
var _fallback_body: Node3D
var _fog_tint := Color(0.9, 0.93, 0.88)


func setup(p_world: Node3D, p_rig: Node3D) -> void:
	world = p_world
	rig = p_rig
	name = "Player"
	_build_model()
	_build_fallback()
	_build_veil()
	_build_shadow()
	_build_fill_light()
	reset_to_spawn()


func reset_to_spawn() -> void:
	velocity = Vector3.ZERO
	rotation.y = 0.0
	var y: float = world.terrain_height(SPAWN_XZ.x, SPAWN_XZ.y)
	global_position = Vector3(SPAWN_XZ.x, y, SPAWN_XZ.y)
	_anim = ""
	_update_animation(true)


func teleport_to_xz(x: float, z: float) -> void:
	var resolved := _resolve_position(Vector3(x, 0.0, z))
	resolved.y = world.terrain_height(resolved.x, resolved.z)
	global_position = resolved
	velocity = Vector3.ZERO


func set_fog_interaction(node: Node3D) -> void:
	fog_interaction = node


func set_fog_tint(color: Color) -> void:
	_fog_tint = color


func set_nightness(t: float) -> void:
	if fill_light == null:
		return
	fill_light.light_color = Color(1.0, 0.92, 0.80).lerp(Color(0.62, 0.74, 1.0), t)
	fill_light.light_energy = lerpf(0.10, 0.48, t)


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_moving() -> bool:
	return horizontal_speed() > 0.25


func _process(delta: float) -> void:
	_anim_time += delta
	var move := _read_move_input()
	var dir := Vector3.ZERO
	if move.length() > 0.001:
		var yaw := deg_to_rad(rig.yaw_deg) if rig != null else 0.0
		var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		dir = (right * move.x + forward * move.y)
		if dir.length() > 1.0:
			dir = dir.normalized()
	var target_speed := RUN_SPEED if _run_pressed() else WALK_SPEED
	var desired := dir * target_speed
	var blend := 1.0 - exp(-delta * ACCEL)
	velocity.x = lerpf(velocity.x, desired.x, blend)
	velocity.z = lerpf(velocity.z, desired.z, blend)
	if move.length() < 0.001:
		velocity.x = move_toward(velocity.x, 0.0, delta * 7.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 7.0)

	var next := global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
	next = _resolve_position(next)
	next.y = world.terrain_height(next.x, next.z)
	global_position = next
	if dir.length() > 0.01:
		var target_yaw := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-delta * TURN_SPEED))

	_update_animation(false)
	_animate_fallback()
	_update_veil()


func _read_move_input() -> Vector2:
	if override_active:
		var v := input_override
		return v.limit_length(1.0)
	if not controls_enabled:
		return Vector2.ZERO
	var x := 0.0
	var y := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		y -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		x += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		x -= 1.0
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		-Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	if stick.length() > 0.20:
		x += stick.x
		y += stick.y
	return Vector2(x, y).limit_length(1.0)


func _run_pressed() -> bool:
	if override_active:
		return override_run
	return Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)


func _resolve_position(pos: Vector3) -> Vector3:
	var flat := Vector2(pos.x, pos.z)
	var boundary: float = world.walk_boundary_radius()
	if flat.length() > boundary:
		flat = flat.normalized() * boundary
	# 池岸阻挡：不走进水面（留 0.55m 岸沿）
	var pool := Vector2(world.pool_center().x, world.pool_center().z)
	var pool_keep: float = world.pool_radius() + 0.55
	var to_pool := flat - pool
	if to_pool.length() < pool_keep:
		flat = pool + to_pool.normalized() * pool_keep if to_pool.length() > 0.01 else pool + Vector2(1.0, 0.0) * pool_keep
	# 树干/石柱/灯笼：圆形推离
	for obstacle in world.obstacle_circles:
		var op: Vector2 = obstacle["pos"]
		var r: float = float(obstacle["radius"]) + BODY_RADIUS
		var delta := flat - op
		var d := delta.length()
		if d < r:
			flat = op + (delta / d if d > 0.0001 else Vector2.RIGHT) * r
	return Vector3(flat.x, pos.y, flat.y)


# ---------------------------------------------------------------- 模型与动画

func _build_model() -> void:
	uses_model = _build_humanoid()
	model_root.visible = uses_model
	if not uses_model:
		push_warning("Fogwood: Rogue unavailable, using procedural character")


func _build_humanoid() -> bool:
	model_root = Node3D.new()
	model_root.name = "ModelRoot"
	model_root.rotation.y = MODEL_YAW_OFFSET
	model_root.scale = Vector3.ONE * MODEL_SCALE
	add_child(model_root)
	if OS.has_environment("FOG_FORCE_PROCEDURAL"):
		return false
	if not ResourceLoader.exists(ROGUE_SCENE_PATH):
		return false
	var packed := load(ROGUE_SCENE_PATH) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		return false
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(IDLE_ANIM) \
			or not player.has_animation(WALK_ANIM) or not player.has_animation(RUN_ANIM):
		model.free()
		return false
	model_root.add_child(model)
	animation_player = player
	for anim_name in [IDLE_ANIM, WALK_ANIM, RUN_ANIM]:
		player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	for node in _all_nodes(model):
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		if HIDDEN_MESHES.has(String(mi.name)):
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for index in mi.mesh.get_surface_count():
			var source := mi.get_active_material(index) as StandardMaterial3D
			if source == null:
				continue
			var tuned := source.duplicate() as StandardMaterial3D
			tuned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tuned.roughness = 0.98
			tuned.metallic = 0.0
			tuned.metallic_specular = 0.05
			mi.set_surface_override_material(index, tuned)
	player.play(IDLE_ANIM)
	return true


func _update_animation(snap: bool) -> void:
	var speed := horizontal_speed()
	var want := IDLE_ANIM
	if speed > 0.25:
		want = RUN_ANIM if speed > WALK_SPEED * 1.30 else WALK_ANIM
	if want != _anim or snap:
		_anim = want
		if animation_player != null:
			animation_player.play(want, 0.20)
	if animation_player != null:
		if want == IDLE_ANIM:
			animation_player.speed_scale = 1.0
		else:
			var ref := WALK_SPEED if want == WALK_ANIM else RUN_SPEED
			animation_player.speed_scale = clampf(speed / ref, 0.6, 1.45)
	# 程序化回退的摆动幅度也跟速度走
	_anim_speed = speed


func _build_fallback() -> void:
	fallback_root = Node3D.new()
	fallback_root.name = "FallbackModel"
	fallback_root.rotation.y = MODEL_YAW_OFFSET
	add_child(fallback_root)
	var robe := _mat(Color(0.17, 0.21, 0.19), 1.0)
	var skin := _mat(Color(0.62, 0.50, 0.40), 1.0)
	var leather := _mat(Color(0.27, 0.20, 0.14), 1.0)
	_fallback_body = Node3D.new()
	fallback_root.add_child(_fallback_body)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.30
	capsule.height = 1.20
	body.mesh = capsule
	body.material_override = robe
	body.position.y = 0.95
	_fallback_body.add_child(body)
	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.21
	sphere.height = 0.42
	head.mesh = sphere
	head.material_override = skin
	head.position.y = 1.69
	_fallback_body.add_child(head)
	_fallback_leg_l = _fallback_limb(leather, Vector3(-0.13, 0.36, 0.0), Vector3(0.15, 0.70, 0.16))
	_fallback_leg_r = _fallback_limb(leather, Vector3(0.13, 0.36, 0.0), Vector3(0.15, 0.70, 0.16))
	_fallback_arm_l = _fallback_limb(robe, Vector3(-0.36, 1.16, 0.0), Vector3(0.12, 0.62, 0.14))
	_fallback_arm_r = _fallback_limb(robe, Vector3(0.36, 1.16, 0.0), Vector3(0.12, 0.62, 0.14))
	fallback_root.visible = not uses_model


func _fallback_limb(mat: StandardMaterial3D, pos: Vector3, size: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	fallback_root.add_child(pivot)
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position.y = -size.y * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	pivot.add_child(mi)
	return pivot


func _animate_fallback() -> void:
	if fallback_root == null or not fallback_root.visible:
		return
	var speed := _anim_speed
	var amp := clampf(speed / WALK_SPEED, 0.0, 1.25)
	var phase := _anim_time * (4.2 + speed * 2.2)
	_fallback_leg_l.rotation.x = sin(phase) * 0.62 * amp
	_fallback_leg_r.rotation.x = -sin(phase) * 0.62 * amp
	_fallback_arm_l.rotation.x = -sin(phase) * 0.52 * amp
	_fallback_arm_r.rotation.x = sin(phase) * 0.52 * amp
	_fallback_body.position.y = absf(sin(phase)) * 0.045 * amp
	_fallback_body.rotation.z = sin(phase) * 0.025 * amp


func _build_veil() -> void:
	# 角色周围的柔雾薄纱：雾越浓越明显，清雾时退去；避免角色被雾块硬切。
	var quad := QuadMesh.new()
	quad.size = Vector2(1.55, 2.05)
	veil_material = StandardMaterial3D.new()
	veil_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	veil_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	veil_material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	veil_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	veil_material.albedo_texture = world.make_particle_texture()
	veil_material.albedo_color = Color(_fog_tint.r, _fog_tint.g, _fog_tint.b, 0.08)
	veil_material.disable_receive_shadows = true
	veil_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	veil_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	veil_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var veil := MeshInstance3D.new()
	veil.name = "MistVeil"
	veil.mesh = quad
	veil.material_override = veil_material
	veil.position.y = 1.02
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil)


func _build_shadow() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 1.15)
	shadow_material = StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.albedo_texture = world.make_particle_texture()
	shadow_material.albedo_color = Color(0.02, 0.03, 0.025, 0.42)
	shadow_material.disable_receive_shadows = true
	shadow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var shadow := MeshInstance3D.new()
	shadow.name = "BlobShadow"
	shadow.mesh = quad
	shadow.material_override = shadow_material
	shadow.rotation.x = -PI * 0.5
	shadow.position.y = 0.035
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)


func _build_fill_light() -> void:
	# 极低能量的角色补光：白天近 0，夜间让角色在浓雾/月光下仍可辨认。
	fill_light = OmniLight3D.new()
	fill_light.name = "CharacterFill"
	fill_light.light_color = Color(1.0, 0.92, 0.80)
	fill_light.light_energy = 0.10
	fill_light.omni_range = 4.2
	fill_light.omni_attenuation = 1.6
	fill_light.shadow_enabled = false
	fill_light.position = Vector3(0.0, 1.15, 0.15)
	add_child(fill_light)


func _update_veil() -> void:
	if veil_material == null:
		return
	var local_fog := 1.0
	if fog_interaction != null:
		local_fog = fog_interaction.get_local_factor_at(global_position)
	veil_material.albedo_color = Color(_fog_tint.r, _fog_tint.g, _fog_tint.b, 0.035 + 0.14 * local_fog)


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return mat


func _all_nodes(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all_nodes(child))
	return out


func state() -> Dictionary:
	return {
		"position": global_position,
		"speed": horizontal_speed(),
		"moving": is_moving(),
		"animation": _anim,
		"model_loaded": uses_model,
		"fallback_visible": fallback_root != null and fallback_root.visible,
	}
