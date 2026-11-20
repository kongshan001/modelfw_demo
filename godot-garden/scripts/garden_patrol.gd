class_name GardenPatrol
extends Node3D

# 程序化巡逻 NPC：提灯守夜人 / 扫园人 / 小狐侍。
# 行为：沿手工 waypoint 闭环行走 → 到达后驻足（张望 / 扫地 / 摇尾）→ 继续。
# 路线已按水池、石圈、拱门石柱、石像的安全距离手工校验，不跑 A*，直线行走更平滑。

const ROLE_LANTERN := "lantern"
const ROLE_SWEEPER := "sweeper"
const ROLE_FOX := "fox"

# 角色外观（KayKit CC0 / glTF Fox CC0+CC-BY）。程序化模型保留为缺图/加载失败的回退。
const ROGUE_SCENE_PATH := "res://assets/models/kaykit/Rogue.glb"
const ROGUE_HOODED_SCENE_PATH := "res://assets/models/kaykit/Rogue_Hooded.glb"
const FOX_SCENE_PATH := "res://assets/models/fox/Fox.glb"
const ROGUE_IDLE_ANIM := "Idle"
const ROGUE_WALK_ANIM := "Walking_A"
const ROGUE_PAUSE_ANIM := "Interact" # 提灯人驻足：低手动作，保持灯在胸前、杆/手可见
const SWEEPER_PAUSE_ANIM := "Interact" # 扫园人驻足：弯腰干活
const FOX_WALK_ANIM := "Walk"
const FOX_PAUSE_ANIM := "Survey"
const ROGUE_MODEL_SCALE := 0.74 # 1.618m，旧守夜人帽顶约 1.665m
const FOX_MODEL_SCALE := 0.011 # Fox.glb 原始约 155 单位长，缩到约 1.7m，避免被草埋
const FOX_YAW_OFFSET := PI # Fox 头部在 +Z（骨骼实测），FSM forward 是 -Z
const ROGUE_WALK_SPEED_SCALE := 1.29 # 0.72 / (0.403 * 2 / 1.067 * 0.74) ≈ 1.29
const ROGUE_LANTERN_OFFSET := Vector3(0.06, -0.02, 0.0) # 灯杆原点贴住右手掌心
const ROGUE_LAMP_CENTER_HEIGHT := -0.17 # 相对 LanternRig 原点的灯心高度（手 0.47 + 0.34 ≈ 0.81m）
# 披风未蒙皮且伸到 y<0，会和地面/石阶穿插；武器隐藏，只留身体。
const ROGUE_HIDDEN_MESHES := [
	"Knife_Offhand", "1H_Crossbow", "2H_Crossbow", "Knife", "Throwable", "Rogue_Cape", "Cape",
]

var role := ROLE_LANTERN
var waypoints: Array[Vector3] = []
var speed := 0.8
var pause_min := 1.6
var pause_max := 3.4
var shadow_texture: Texture2D
var halo_texture: Texture2D
var halo_core_texture: Texture2D
var halos_forced_off := false
var camera_ref: Camera3D

var _walking := true
var _pause_timer := 0.0
var _wp := 1
var _time := 0.0
var _phase := 0.0
var _night := 0.0
var _night_glow := 0.0
var _look_target := 0.0

var _body: Node3D
var _head: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _tail: Node3D
var _lantern: Node3D
var _lantern_light: OmniLight3D
var _lantern_halo: Sprite3D
var _lantern_glass: StandardMaterial3D

var _uses_model := false
var _model_root: Node3D
var _model_player: AnimationPlayer
var _hand_anchor: Node3D
var _anim_state := ""
var _lantern_rig: Node3D
var _lantern_body: Node3D
var _wide_core: MeshInstance3D
var _wide_core_mat: StandardMaterial3D
var _lantern_halo_core: Sprite3D
var _lantern_halo_outer: Sprite3D
var _lantern_halo_far: Sprite3D
var _lantern_halo_wide: Sprite3D
var _lantern_halo_core_wide: Sprite3D
var _lantern_pool: MeshInstance3D
var _lantern_pool_mat: StandardMaterial3D
var _broom_rig: Node3D
var _walk_anim := ROGUE_WALK_ANIM
var _pause_anim := ""
var _walk_speed_scale := ROGUE_WALK_SPEED_SCALE
var _fallback_warned := false

func _ready() -> void:
	if not waypoints.is_empty():
		position = waypoints[0]
	_build()
	if not waypoints.is_empty():
		_wp = 1 % waypoints.size()
		_face_towards(waypoints[_wp], 1.0)

func _process(delta: float) -> void:
	_time += delta
	if waypoints.size() < 2:
		if _uses_model:
			_update_lantern_rig()
			_update_broom_rig()
		return
	if _uses_model:
		_update_lantern_rig()
		_update_broom_rig()
		return

	if _walking:
		_walk(delta)
	else:
		_pause_timer -= delta
		_idle(delta)
		if _pause_timer <= 0.0:
			_walking = true
			_wp = (_wp + 1) % waypoints.size()

	if _uses_model:
		_update_lantern_rig()
		_update_broom_rig()

func set_night(night: float, dusk := 0.0) -> void:
	_night = clampf(night, 0.0, 1.0)
	# 黄昏也点起灯（比深夜弱），远处能看见一点暖光在园里移动
	var glow := maxf(_night, clampf(dusk, 0.0, 1.0) * 0.55)
	_night_glow = glow
	if _lantern_glass != null:
		_lantern_glass.albedo_color = Color(0.50, 0.478, 0.322 + clampf(dusk, 0.0, 1.0) * 0.004)
	if _uses_model:
		# 根节点灯：稳定灯位，不随手臂摆动；亮度交给灯芯/光晕/地面池
		if _lantern_light != null:
			_lantern_light.light_energy = 0.008 + glow * 0.02
		if _lantern_halo_core != null:
			_lantern_halo_core.modulate.a = glow * 0.03
			_lantern_halo_core.visible = glow > 0.02
		if _lantern_halo_outer != null:
			_lantern_halo_outer.modulate.a = glow * 0.12
			_lantern_halo_outer.visible = glow > 0.02
		if _lantern_halo_far != null:
			_lantern_halo_far.modulate.a = glow * 0.12
			_lantern_halo_far.visible = glow > 0.02
		if _lantern_halo_wide != null:
			_lantern_halo_wide.modulate.a = glow * 0.40
			_lantern_halo_wide.visible = glow > 0.02
		if _lantern_halo_core_wide != null:
			_lantern_halo_core_wide.modulate.a = 0.0
			_lantern_halo_core_wide.visible = false
		if _lantern_pool != null:
			_lantern_pool.visible = glow > 0.02
		if _lantern_pool_mat != null:
			var pool_color := _lantern_pool_mat.albedo_color
			pool_color.a = glow * 0.45
			_lantern_pool_mat.albedo_color = pool_color
		if _lantern_glass != null:
			_lantern_glass.emission_energy_multiplier = 0.15
		if halos_forced_off:
			for node in [_lantern_halo_core, _lantern_halo_outer, _lantern_halo_far, _lantern_halo_wide, _lantern_halo_core_wide]:
				if node != null:
					node.visible = false
		return
	if _lantern_light != null:
		_lantern_light.light_energy = glow * 1.35
	if _lantern_halo != null:
		_lantern_halo.modulate.a = glow * 0.85
		_lantern_halo.visible = glow > 0.02
	if _lantern_glass != null:
		_lantern_glass.emission_energy_multiplier = 0.15 + glow * 2.6

	if halos_forced_off:
		for node in [_lantern_halo_core, _lantern_halo_outer, _lantern_halo_far, _lantern_halo_wide, _lantern_halo_core_wide]:
			if node != null:
				node.visible = false

func force_pause(seconds := 6.0) -> void:
	_walking = false
	_pause_timer = seconds
	_look_target = 0.0
	_phase = 0.0

# ---------------------------------------------------------------- 行为

func _walk(delta: float) -> void:
	var target := waypoints[_wp]
	var offset := target - global_position
	offset.y = 0.0
	if offset.length() <= 0.24:
		_walking = false
		_pause_timer = randf_range(pause_min, pause_max)
		_look_target = randf_range(-0.8, 0.8)
		return
	var step := minf(speed * delta, offset.length())
	position += offset.normalized() * step
	_face_towards(target, delta)
	_animate_walk(delta)

func _idle(delta: float) -> void:
	if _uses_model:
		# 骨骼动画自带呼吸/张望，不再叠加程序化四肢
		_update_model_animation(false)
		return
	var settle := minf(1.0, delta * 8.0)
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.0, settle)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.0, settle)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, 0.05, settle)
	_head.rotation.y = lerpf(_head.rotation.y, _look_target, settle * 0.5)
	_body.position.y = sin(_time * 1.7) * 0.01

	match role:
		ROLE_LANTERN:
			# 提灯人驻足时把灯举到身前、轻轻晃
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.62 + sin(_time * 1.3) * 0.06, settle)
			if _lantern != null:
				_lantern.rotation.z = sin(_time * 1.6) * 0.08
		ROLE_SWEEPER:
			# 扫园人：弯腰扫地
			_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.55 + sin(_time * 2.4) * 0.1, settle)
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.75 + sin(_time * 3.2) * 0.42, settle)
			_body.rotation.z = sin(_time * 3.2) * 0.03
		ROLE_FOX:
			# 小狐侍：尾巴摇、偶尔踮脚张望
			_tail.rotation.y = sin(_time * 3.4) * 0.5
			_tail.rotation.x = -0.35 + sin(_time * 2.1) * 0.1
			_head.rotation.y = sin(_time * 0.9) * 0.6
			_body.position.y = 0.01 + absf(sin(_time * 2.6)) * 0.02

	if role != ROLE_SWEEPER:
		_body.rotation.z = lerpf(_body.rotation.z, 0.0, settle)

func _animate_walk(delta: float) -> void:
	if _uses_model:
		# 只保留根节点 yaw，四肢交给 Walking_A
		_update_model_animation(true)
		return
	var cadence := 7.0 if role == ROLE_FOX else 6.0
	_phase += delta * cadence * (speed / 0.8)
	var swing := sin(_phase) * 0.5
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.7
	_body.position.y = absf(sin(_phase * 2.0)) * 0.022
	_head.rotation.y = lerpf(_head.rotation.y, 0.0, minf(1.0, delta * 6.0))

	match role:
		ROLE_LANTERN:
			# 提灯的手臂保持前抬，灯随步伐小摆
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, 0.55, minf(1.0, delta * 8.0))
			if _lantern != null:
				_lantern.rotation.z = sin(_phase) * 0.16
		ROLE_SWEEPER:
			_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -0.25 + swing * 0.2, minf(1.0, delta * 8.0))
		ROLE_FOX:
			_arm_r.rotation.x = swing * 0.7
			_tail.rotation.y = sin(_time * 4.0) * 0.35
			_tail.rotation.x = -0.3 + sin(_phase * 0.5) * 0.08

func _face_towards(target: Vector3, delta: float) -> void:
	var offset := target - global_position
	offset.y = 0.0
	if offset.length_squared() > 0.001:
		var yaw := atan2(-offset.x, -offset.z)
		rotation.y = lerp_angle(rotation.y, yaw, minf(1.0, delta * 6.0))

# ---------------------------------------------------------------- 构建

func _build() -> void:
	if role == ROLE_LANTERN and _build_humanoid(ROGUE_SCENE_PATH, true, ROGUE_PAUSE_ANIM):
		return
	if role == ROLE_SWEEPER and _build_humanoid(ROGUE_HOODED_SCENE_PATH, false, SWEEPER_PAUSE_ANIM):
		return
	if role == ROLE_FOX and _build_fox():
		return
	_build_procedural()

func _build_procedural() -> void:
	var palette := _palette()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var robe: Color = palette["robe"]
	var robe_dark: Color = palette["robe_dark"]
	var skin: Color = palette["skin"]
	var hair: Color = palette["hair"]

	# 下摆 / 上身 / 腰带
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.15
	skirt.bottom_radius = 0.25
	skirt.height = 0.62
	skirt.radial_segments = 8
	_attach(_body, skirt, _mat(robe), Vector3(0, 0.64, 0))
	var torso := CylinderMesh.new()
	torso.top_radius = 0.13
	torso.bottom_radius = 0.17
	torso.height = 0.3
	torso.radial_segments = 8
	_attach(_body, torso, _mat(robe_dark), Vector3(0, 1.07, 0))
	var sash := BoxMesh.new()
	sash.size = Vector3(0.34, 0.06, 0.28)
	_attach(_body, sash, _mat(palette["trim"]), Vector3(0, 0.95, 0))

	# 头部枢轴（驻足张望）
	_head = Node3D.new()
	_head.position = Vector3(0, 1.24, 0)
	_body.add_child(_head)
	var head := SphereMesh.new()
	head.radius = 0.145
	head.height = 0.29
	head.radial_segments = 10
	head.rings = 6
	_attach(_head, head, _mat(skin), Vector3(0, 0.12, 0))
	var hair_cap := SphereMesh.new()
	hair_cap.radius = 0.158
	hair_cap.height = 0.28
	hair_cap.radial_segments = 10
	hair_cap.rings = 6
	var hair_node := _attach(_head, hair_cap, _mat(hair), Vector3(0, 0.17, 0.01))
	hair_node.scale = Vector3(1.0, 0.8, 1.0)
	var back_hair := BoxMesh.new()
	back_hair.size = Vector3(0.24, 0.24, 0.1)
	_attach(_head, back_hair, _mat(hair), Vector3(0, 0.04, 0.11))
	var eye_mat := _mat(Color(0.06, 0.05, 0.05))
	eye_mat.roughness = 0.2
	for side in [-1.0, 1.0]:
		_attach(_head, _small_sphere(0.02), eye_mat, Vector3(side * 0.052, 0.105, -0.14))

	match role:
		ROLE_LANTERN:
			_hat(palette["hat"], 0.34, 0.17)
			_arm_r = _make_arm(0.19, 1.14, 0.4, _mat(robe_dark))
			_arm_l = _make_arm(-0.19, 1.14, 0.36, _mat(robe_dark))
			_build_lantern()
		ROLE_SWEEPER:
			_hat(palette["hat"], 0.36, 0.12)
			var sleeve := _mat(palette["robe"])
			_arm_r = _make_arm(0.19, 1.14, 0.36, sleeve)
			_arm_l = _make_arm(-0.19, 1.14, 0.36, sleeve)
			_build_broom()
		ROLE_FOX:
			_ears(palette["ear"])
			_arm_r = _make_arm(0.18, 1.12, 0.34, _mat(robe_dark))
			_arm_l = _make_arm(-0.18, 1.12, 0.34, _mat(robe_dark))
			_build_tail(palette["tail"])

	# 腿：袍下只露小腿，走路仍能看出摆动
	var trouser := _mat(Color(0.12, 0.1, 0.09))
	_leg_l = _make_leg(-0.07, 0.42, trouser)
	_leg_r = _make_leg(0.07, 0.42, trouser)

	scale = Vector3.ONE * float(palette["scale"])

	if shadow_texture != null:
		_add_shadow(shadow_texture)

# ---------------------------------------------------------------- Rogue 外观

func _build_humanoid(scene_path: String, with_lantern: bool, pause_anim: String) -> bool:
	# 调试开关：GARDEN_FORCE_PROCEDURAL=1 可模拟加载失败，验证回退
	if OS.has_environment("GARDEN_FORCE_PROCEDURAL"):
		_warn_model_fallback("GARDEN_FORCE_PROCEDURAL")
		return false
	if not ResourceLoader.exists(scene_path):
		_warn_model_fallback("model not found: " + scene_path)
		return false
	var packed := load(scene_path) as PackedScene
	if packed == null:
		_warn_model_fallback("load failed: " + scene_path)
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		_warn_model_fallback("instantiate failed: " + scene_path)
		return false
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var hand := model.find_child("handslot_r", true, false) as Node3D
	if player == null or hand == null or not player.has_animation(ROGUE_IDLE_ANIM) \
			or not player.has_animation(ROGUE_WALK_ANIM):
		_warn_model_fallback("AnimationPlayer/handslot_r/animations missing")
		model.free()
		return false

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_model_root.position = Vector3.ZERO # 模型脚底原点就在 y=0
	_model_root.rotation.y = PI # 模型正面 +Z，FSM forward 是 -Z
	_model_root.scale = Vector3.ONE * ROGUE_MODEL_SCALE
	add_child(_model_root)
	_model_root.add_child(model)
	_model_player = player
	_hand_anchor = hand
	_walk_anim = ROGUE_WALK_ANIM
	_pause_anim = pause_anim if player.has_animation(pause_anim) else ""
	_walk_speed_scale = ROGUE_WALK_SPEED_SCALE
	player.get_animation(ROGUE_IDLE_ANIM).loop_mode = Animation.LOOP_LINEAR
	player.get_animation(ROGUE_WALK_ANIM).loop_mode = Animation.LOOP_LINEAR
	if _pause_anim != "":
		player.get_animation(_pause_anim).loop_mode = Animation.LOOP_LINEAR
	_prepare_rogue_model(model)
	if with_lantern:
		_build_model_lantern()
	else:
		_build_model_broom()
	if shadow_texture != null:
		_add_shadow(shadow_texture, 0.45)
	_uses_model = true
	_update_model_animation(false)
	return true

func _build_fox() -> bool:
	if OS.has_environment("GARDEN_FORCE_PROCEDURAL"):
		_warn_model_fallback("GARDEN_FORCE_PROCEDURAL")
		return false
	if not ResourceLoader.exists(FOX_SCENE_PATH):
		_warn_model_fallback("fox model not found")
		return false
	var packed := load(FOX_SCENE_PATH) as PackedScene
	if packed == null:
		_warn_model_fallback("fox load failed")
		return false
	var model := packed.instantiate() as Node3D
	if model == null:
		_warn_model_fallback("fox instantiate failed")
		return false
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(FOX_WALK_ANIM) \
			or not player.has_animation(FOX_PAUSE_ANIM):
		_warn_model_fallback("fox animations missing")
		model.free()
		return false

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_model_root.rotation.y = FOX_YAW_OFFSET
	_model_root.scale = Vector3.ONE * FOX_MODEL_SCALE
	add_child(_model_root)
	_model_root.add_child(model)
	_model_player = player
	_walk_anim = FOX_WALK_ANIM
	_pause_anim = FOX_PAUSE_ANIM
	_walk_speed_scale = 1.0
	player.get_animation(FOX_WALK_ANIM).loop_mode = Animation.LOOP_LINEAR
	player.get_animation(FOX_PAUSE_ANIM).loop_mode = Animation.LOOP_LINEAR
	for node in _all_nodes(model):
		if node is MeshInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if node.mesh != null:
				for index in node.mesh.get_surface_count():
					var source := node.get_active_material(index) as StandardMaterial3D
					if source == null:
						continue
					var tuned := source.duplicate() as StandardMaterial3D
					tuned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
					node.set_surface_override_material(index, tuned)
	if shadow_texture != null:
		_add_shadow(shadow_texture, 0.35)
	_uses_model = true
	_update_model_animation(false)
	return true

func _prepare_rogue_model(model: Node3D) -> void:
	for node in _all_nodes(model):
		if not (node is MeshInstance3D):
			continue
		var mesh_instance := node as MeshInstance3D
		if ROGUE_HIDDEN_MESHES.has(String(mesh_instance.name)):
			mesh_instance.visible = false
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mesh_instance.mesh == null:
			continue
		# 逐 surface 做实例级材质覆盖，不改源 GLB / 共享网格
		for index in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.get_active_material(index) as StandardMaterial3D
			if source == null:
				continue
			var tuned := source.duplicate() as StandardMaterial3D
			tuned.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			tuned.roughness = 0.98
			tuned.metallic = 0.0
			tuned.metallic_specular = 0.05
			tuned.albedo_color = Color(0.84, 0.88, 0.94)
			mesh_instance.set_surface_override_material(index, tuned)

func _build_model_lantern() -> void:
	_lantern_rig = Node3D.new()
	_lantern_rig.name = "LanternRig"
	add_child(_lantern_rig)
	_lantern_body = Node3D.new()
	_lantern_body.name = "LanternBody"
	_lantern_rig.add_child(_lantern_body)
	_wide_core = MeshInstance3D.new()
	_wide_core.name = "WideCore"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 1.2)
	_wide_core.mesh = quad
	_wide_core_mat = StandardMaterial3D.new()
	_wide_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wide_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wide_core_mat.albedo_texture = _make_lantern_icon_texture()
	_wide_core_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	_wide_core_mat.disable_receive_shadows = true
	_wide_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wide_core_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_wide_core.material_override = _wide_core_mat
	_wide_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wide_core.visible = false
	add_child(_wide_core)

	var wood := _mat(Color(0.22, 0.16, 0.11), 0.8)
	var frame_mat := _mat(Color(0.11, 0.09, 0.07), 0.65, 0.35)
	frame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 提梁：两根短柱 + 掌心横杆（手心在 y=0，灯体挂在下方）
	var handle_mat := _mat(Color(0.35, 0.32, 0.27), 0.8)
	for sx in [-0.07, 0.07]:
		var hook := _attach(_lantern_body, _box(Vector3(0.02, 0.15, 0.02)), handle_mat,
			Vector3(float(sx), 0.025, -0.05))
		hook.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top_bar := _attach(_lantern_body, _box(Vector3(0.16, 0.02, 0.02)), handle_mat, Vector3(0, 0.10, -0.05))
	handle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	top_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var lamp_y := ROGUE_LAMP_CENTER_HEIGHT
	for sy in [-0.12, 0.12]:
		var plate := _attach(_lantern_body, _box(Vector3(0.22, 0.025, 0.22)), frame_mat,
			Vector3(0, lamp_y + float(sy), 0))
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-0.10, 0.10]:
		for sz in [-0.10, 0.10]:
			var post := _attach(_lantern_body, _box(Vector3(0.022, 0.215, 0.022)), frame_mat,
				Vector3(float(sx), lamp_y, float(sz)))
			post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_lantern_glass = _mat(Color(0.50, 0.478, 0.322), 0.4)
	_lantern_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_glass.emission_enabled = false
	var glass_mesh := _attach(_lantern_body, _box(Vector3(0.15, 0.19, 0.15)), _lantern_glass,
		Vector3(0, lamp_y, 0))
	var mullion := _attach(_lantern_body, _box(Vector3(0.012, 0.19, 0.012)), frame_mat,
		Vector3(0, lamp_y, -0.078))

	glass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if halo_texture != null:
		_lantern_halo_core = _make_lantern_halo(0.80, true)
		_lantern_halo_outer = _make_lantern_halo(2.2)
		_lantern_halo_far = _make_lantern_halo(4.5)
		_lantern_halo_wide = _make_lantern_halo(1.4)
		_lantern_halo_wide.position = Vector3(0, ROGUE_LAMP_CENTER_HEIGHT, 0.28)
		_lantern_halo_core_wide = _make_lantern_halo(1.5)
		_lantern_halo_core_wide.position = Vector3(0, ROGUE_LAMP_CENTER_HEIGHT, -0.05)
		_lantern_halo_core_wide.no_depth_test = true
		_lantern_halo_core_wide.render_priority = 2
		_lantern_halo_core_wide.scale.x *= 1.5
		_build_lantern_pool()

	_lantern_light = OmniLight3D.new()
	_lantern_light.name = "LanternLight"
	_lantern_light.position = Vector3(0.42, 0.72, -0.28) # 离灯玻璃 0.4m，避免近距离把窗格打爆
	_lantern_light.light_color = Color(1.0, 0.78, 0.52)
	_lantern_light.light_energy = 0.0
	_lantern_light.omni_range = 4.0
	_lantern_light.omni_attenuation = 1.8
	_lantern_light.shadow_enabled = false
	add_child(_lantern_light)

func _make_lantern_icon_texture() -> ImageTexture:
	# 远距识别用的“灯形”贴图：黑框、暖玻璃、提手，避免纯光球
	var w := 96
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			var c := Color(0, 0, 0, 0)
			if x >= 10 and x < 86 and y >= 6 and y < 122:
				c = Color(0.06, 0.05, 0.04, 1.0)
			if x >= 20 and x < 76 and y >= 22 and y < 104:
				c = Color(1.0, 0.76, 0.36, 1.0)
			if x >= 45 and x < 51 and y >= 22 and y < 104:
				c = Color(0.06, 0.05, 0.04, 1.0)
			if y >= 60 and y < 66 and x >= 20 and x < 76:
				c = Color(0.06, 0.05, 0.04, 1.0)
			if x >= 34 and x < 62 and y >= 0 and y < 8:
				c = Color(0.06, 0.05, 0.04, 1.0)
			if x >= 40 and x < 56 and y >= 122 and y < 128:
				c = Color(0.06, 0.05, 0.04, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _make_lantern_halo(size: float, flat := false) -> Sprite3D:
	var halo := Sprite3D.new()
	halo.texture = halo_core_texture if flat and halo_core_texture != null else halo_texture
	halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	halo.pixel_size = 0.01
	halo.scale = Vector3.ONE * (size / (float(halo_texture.get_width()) * halo.pixel_size))
	halo.modulate = Color(1.0, 0.78, 0.45, 0.0)
	halo.position = Vector3(0, ROGUE_LAMP_CENTER_HEIGHT, 0.0 if size < 3.0 else 0.35)
	halo.visible = false
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_rig.add_child(halo)
	return halo

func _build_lantern_pool() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(4.4, 4.4)
	_lantern_pool_mat = StandardMaterial3D.new()
	_lantern_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lantern_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_lantern_pool_mat.albedo_texture = halo_texture
	_lantern_pool_mat.albedo_color = Color(1.0, 0.78, 0.45, 0.0)
	_lantern_pool_mat.disable_receive_shadows = true
	_lantern_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = _lantern_pool_mat
	_lantern_pool = MeshInstance3D.new()
	_lantern_pool.name = "LanternPool"
	_lantern_pool.mesh = quad
	_lantern_pool.material_override = _lantern_pool_mat
	_lantern_pool.rotation.x = -PI * 0.5
	_lantern_pool.position = Vector3(0, 0.03, 0)
	_lantern_pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_pool.visible = false
	add_child(_lantern_pool)

func _update_lantern_rig() -> void:
	if _lantern_rig == null or _hand_anchor == null:
		return
	# 世界米偏移：角色右/下/前；灯保持竖直，只跟随位移不跟随手臂旋转
	_lantern_rig.global_position = _hand_anchor.global_position \
		+ global_transform.basis * ROGUE_LANTERN_OFFSET
	_lantern_rig.global_rotation = Vector3(0.0, rotation.y, 0.0)
	# 远/近光晕 LOD：近景用小光晕保护脸，广角用大亮芯保证识别
	var far_t := 0.0
	if camera_ref != null:
		far_t = clampf((camera_ref.global_position.distance_to(global_position) - 12.0) / 10.0, 0.0, 1.0)
	if _lantern_halo_core != null:
		_lantern_halo_core.modulate.a *= 0.0
	if _lantern_halo_wide != null:
		_lantern_halo_wide.modulate.a *= far_t
	if _lantern_halo_core_wide != null:
		_lantern_halo_core_wide.visible = false
	if _lantern_body != null:
		_lantern_body.scale = Vector3.ONE * lerpf(1.0, 2.0, far_t)
	if _wide_core != null:
		var glass_pos: Vector3 = _lantern_body.global_transform * Vector3(0, ROGUE_LAMP_CENTER_HEIGHT, 0)
		_wide_core.global_position = glass_pos + global_transform.basis * Vector3(0.30, 0, 0)
		if camera_ref != null:
			_wide_core.global_rotation = camera_ref.global_rotation
		_wide_core_mat.albedo_color = Color(1.0, 0.9, 0.72, far_t * _night_glow * 0.92)
		_wide_core.visible = false

func _build_model_broom() -> void:
	_broom_rig = Node3D.new()
	_broom_rig.name = "BroomRig"
	add_child(_broom_rig)
	var wood := _mat(Color(0.35, 0.24, 0.13), 0.85)
	var straw := _mat(Color(0.72, 0.58, 0.3), 0.9)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.022
	pole.height = 0.7
	pole.radial_segments = 5
	pole.rings = 1
	var pole_instance := _attach(_broom_rig, pole, wood, Vector3(0, -0.30, 0))
	pole_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var brush := _attach(_broom_rig, _box(Vector3(0.24, 0.12, 0.09)), straw, Vector3(0, -0.60, 0.02))
	brush.rotation.x = 0.15
	brush.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _update_broom_rig() -> void:
	if _broom_rig == null or _hand_anchor == null:
		return
	_broom_rig.global_position = _hand_anchor.global_position \
		+ global_transform.basis * Vector3(0.02, -0.04, 0.0)
	# 斜握扫地：制动时来回摆，行走时收成小角度
	var tilt := 0.55
	if not _walking:
		tilt = 0.72 + sin(_time * 3.2) * 0.22
	_broom_rig.global_rotation = Vector3(tilt, rotation.y, 0.0)

func _update_model_animation(walking: bool) -> void:
	if _model_player == null:
		return
	var state := "walk" if walking else "pause"
	if state == _anim_state:
		return
	_anim_state = state
	if walking:
		_model_player.play(_walk_anim, 0.18, _walk_speed_scale)
	else:
		var anim_name := _pause_anim if _pause_anim != "" else ROGUE_IDLE_ANIM
		_model_player.play(anim_name, 0.25, 1.3)
		var anim_length := _model_player.get_animation(anim_name).length
		_model_player.seek(0.35 * maxf(anim_length, 0.01), true)

func _warn_model_fallback(reason: String) -> void:
	if _fallback_warned:
		return
	_fallback_warned = true
	push_warning("GardenPatrol: Rogue unavailable (%s), using procedural model" % reason)

func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	for child in root.get_children():
		out.append_array(_all_nodes(child))
	return out

func _palette() -> Dictionary:
	match role:
		ROLE_SWEEPER:
			return {
				"robe": Color(0.44, 0.34, 0.21),
				"robe_dark": Color(0.36, 0.28, 0.18),
				"trim": Color(0.66, 0.54, 0.32),
				"skin": Color(0.88, 0.73, 0.58),
				"hair": Color(0.62, 0.6, 0.56),
				"hat": Color(0.72, 0.62, 0.38),
				"ear": Color(0.0, 0.0, 0.0),
				"tail": Color(0.0, 0.0, 0.0),
				"scale": 0.94,
			}
		ROLE_FOX:
			return {
				"robe": Color(0.62, 0.32, 0.14),
				"robe_dark": Color(0.48, 0.24, 0.11),
				"trim": Color(0.9, 0.72, 0.4),
				"skin": Color(0.93, 0.8, 0.65),
				"hair": Color(0.56, 0.24, 0.1),
				"hat": Color(0.0, 0.0, 0.0),
				"ear": Color(0.66, 0.32, 0.15),
				"tail": Color(0.78, 0.42, 0.18),
				"scale": 0.74,
			}
		_:
			return {
				"robe": Color(0.23, 0.28, 0.44),
				"robe_dark": Color(0.17, 0.21, 0.35),
				"trim": Color(0.72, 0.6, 0.32),
				"skin": Color(0.9, 0.76, 0.62),
				"hair": Color(0.08, 0.07, 0.07),
				"hat": Color(0.24, 0.22, 0.17),
				"ear": Color(0.0, 0.0, 0.0),
				"tail": Color(0.0, 0.0, 0.0),
				"scale": 1.0,
			}

func _hat(color: Color, radius: float, height: float) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.02
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 10
	cone.rings = 1
	_attach(_head, cone, _mat(color), Vector3(0, 0.34, 0))
	var brim := CylinderMesh.new()
	brim.top_radius = radius
	brim.bottom_radius = radius
	brim.height = 0.02
	brim.radial_segments = 10
	_attach(_head, brim, _mat(color.darkened(0.15)), Vector3(0, 0.26, 0))

func _ears(color: Color) -> void:
	var mat := _mat(color)
	for side in [-1.0, 1.0]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.005
		cone.bottom_radius = 0.06
		cone.height = 0.16
		cone.radial_segments = 6
		var ear := _attach(_head, cone, mat, Vector3(side * 0.085, 0.3, 0.0))
		ear.rotation.z = side * -0.25

func _build_lantern() -> void:
	_lantern = Node3D.new()
	_lantern.position = Vector3(0.05, -0.4, -0.1)
	_lantern.scale = Vector3.ONE * 1.15
	_arm_r.add_child(_lantern)
	var frame_mat := _mat(Color(0.12, 0.1, 0.08), 0.6, 0.3)
	for sy in [-0.09, 0.09]:
		_attach(_lantern, _box(Vector3(0.13, 0.025, 0.13)), frame_mat, Vector3(0, sy, 0))
	for sx in [-0.055, 0.055]:
		for sz in [-0.055, 0.055]:
			_attach(_lantern, _box(Vector3(0.022, 0.17, 0.022)), frame_mat, Vector3(sx, 0, sz))
	_lantern_glass = _mat(Color(0.50, 0.478, 0.322), 0.4)
	_lantern_glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lantern_glass.emission_enabled = false
	_attach(_lantern, _box(Vector3(0.095, 0.15, 0.095)), _lantern_glass, Vector3.ZERO)
	var hook := CylinderMesh.new()
	hook.top_radius = 0.006
	hook.bottom_radius = 0.006
	hook.height = 0.14
	_attach(_lantern, hook, frame_mat, Vector3(0, 0.2, 0))

	if halo_texture != null:
		_lantern_halo = Sprite3D.new()
		_lantern_halo.texture = halo_texture
		_lantern_halo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_lantern_halo.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		_lantern_halo.pixel_size = 0.01
		_lantern_halo.scale = Vector3(1.5, 1.5, 1.0)
		_lantern_halo.modulate = Color(1.0, 0.78, 0.45, 0.0)
		_lantern_halo.visible = false
		_lantern.add_child(_lantern_halo)

	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.72, 0.42)
	_lantern_light.light_energy = 0.0
	_lantern_light.omni_range = 6.0
	_lantern_light.omni_attenuation = 1.4
	_lantern_light.shadow_enabled = false
	_lantern_light.position = Vector3(0, -0.02, 0)
	_lantern.add_child(_lantern_light)

func _build_broom() -> void:
	var handle_mat := _mat(Color(0.35, 0.24, 0.13))
	var handle := CylinderMesh.new()
	handle.top_radius = 0.018
	handle.bottom_radius = 0.022
	handle.height = 1.05
	handle.radial_segments = 5
	var stick := _attach(_arm_r, handle, handle_mat, Vector3(0.02, -0.45, -0.16))
	stick.rotation.x = 0.5
	var brush := _attach(_arm_r, _box(Vector3(0.2, 0.13, 0.07)), _mat(Color(0.62, 0.48, 0.24)),
		Vector3(0.02, -0.93, -0.42))
	brush.rotation.x = 0.5

func _build_tail(color: Color) -> void:
	# 尾巴从后腰长出，向后上方翘起，末端颜色更浅
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.5, 0.16)
	_body.add_child(_tail)
	var mat := _mat(color)
	var segments := [
		{"pos": Vector3(0, 0.02, 0.1), "r": 0.1},
		{"pos": Vector3(0, 0.13, 0.22), "r": 0.115},
		{"pos": Vector3(0, 0.26, 0.3), "r": 0.1},
		{"pos": Vector3(0, 0.38, 0.33), "r": 0.072},
	]
	for index in segments.size():
		var item: Dictionary = segments[index]
		var node := _attach(_tail, _small_sphere(float(item["r"])), mat, item["pos"])
		if index == segments.size() - 1:
			node.material_override = _mat(color.lightened(0.38))

func _make_arm(x: float, y: float, length: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, 0)
	_body.add_child(pivot)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.048
	mesh.bottom_radius = 0.04
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0, -length * 0.5, 0)
	pivot.add_child(instance)
	var hand := _small_sphere(0.042)
	_attach(pivot, hand, _mat(Color(0.9, 0.76, 0.62)), Vector3(0, -length, 0))
	return pivot

func _make_leg(x: float, y: float, material: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, 0)
	_body.add_child(pivot)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.042
	mesh.bottom_radius = 0.036
	mesh.height = 0.4
	mesh.radial_segments = 6
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(0, -0.2, 0)
	pivot.add_child(instance)
	_attach(pivot, _box(Vector3(0.085, 0.05, 0.15)), _mat(Color(0.1, 0.08, 0.07)),
		Vector3(0, -0.41, -0.03))
	return pivot

func _add_shadow(texture: Texture2D, alpha := 0.5) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.9, 0.9)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color(1, 1, 1, alpha)
	material.disable_receive_shadows = true
	quad.material = material
	var shadow := MeshInstance3D.new()
	shadow.mesh = quad
	shadow.material_override = material
	shadow.rotation.x = -PI * 0.5
	shadow.position = Vector3(0, 0.02, 0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shadow)

func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _small_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	return mesh

func _attach(parent: Node3D, mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	parent.add_child(instance)
	return instance

func _mat(color: Color, roughness := 0.92, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
