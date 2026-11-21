extends Node3D

## 灯下客 · 长安一夜 — 10–15 分钟 3D 动作 vertical slice。
## 夜景街道由 world.gd 程序化生成；玩家/敌人用 CC0 KayKit 骨架 + 原创重着色；
## 剧情/任务/战斗/相机/HUD/结算全部在本脚本编排。

const SPAWN := Vector3(0.0, 0.06, 2.0)
const BOSS_SPAWN := Vector3(0.0, 0.06, 76.5)

var world: ChanganWorld
var player: ChanganPlayer
var hud: ChanganHUD
var camera: Camera3D
var cam_rig: Node3D
var spring: SpringArm3D
var player_fill: OmniLight3D
var npcs: Dictionary = {}

var enemies: Array = []
var wave_enemies: Array = []
var boss_ref: ChanganEnemy = null
var lock_target: Node3D = null
var attack_token: ChanganEnemy = null
var fire_zones: Array[Dictionary] = []

var game_state := "title"
var story_stage := "meet_ahe"
var quest_text := "去面摊找阿禾（E 交谈）"
var story_beats: Array[String] = []
var street_lights_lit := 0
var current_wave := 0
var encounter_active := false
var wave1_cleared := false
var wave2_cleared := false
var boss_spawned := false
var boss_defeated := false
var boss_intro_t := 0.0
var boss_phase2_done := false
var ahe_noodle_used := false
var ahe_intro_done := false

var elapsed := 0.0
var combo := 0
var combo_timer := 0.0
var max_combo := 0
var hits := 0
var hits_taken := 0
var choice := ""
var ending_text := ""

var dialogue_speaker := ""
var dialogue_lines: Array[String] = []
var dialogue_index := 0
var dialogue_on_end := Callable()
var dialogue_guard := 0.0
var interact_prompt := ""
var interact_id := ""
var toast_text := ""
var toast_timer := 0.0

var trauma := 0.0
var hitstop_timer := 0.0
var cam_yaw := PI
var cam_pitch := -0.18
var cam_distance := 4.2
var fov_target := 60.0
var cam_target := SPAWN + Vector3(0, 1.62, 0)
var cinematic := false
var cinematic_pos := Vector3.ZERO
var cinematic_look := Vector3.ZERO
var cinematic_fov := 55.0
var mouse_captured := false

var quest_marker: MeshInstance3D

var _t := 0.0
var _soft_tex: ImageTexture
var _spark_quad: QuadMesh
var _spark_mat: StandardMaterial3D
var _camera_snap := true
var _warmup_done := false
var _result_recorded := false

# 共享 VFX 资源 / 对象池：避免每次命中新建材质造成 Intel 集显掉帧
var _flash_mesh: SphereMesh
var _ring_mesh: TorusMesh
var _fx_warm_mat: StandardMaterial3D
var _fx_red_mat: StandardMaterial3D
var _spark_pool: Array[CPUParticles3D] = []
var _spark_idx := 0
var _dmg_pool: Array[Label3D] = []
var _dmg_tweens: Array[Tween] = []
var _dmg_idx := 0
var _fire_flame_quad_mesh: QuadMesh
var _fire_flame_mat: StandardMaterial3D
var _fire_oil_mesh: CylinderMesh
var _fire_oil_mat: StandardMaterial3D


func _ready() -> void:
	_build_world()
	_build_camera()
	_build_player()
	_build_npcs()
	_build_hud()
	_build_marker()
	_build_impact_assets()
	_connect_signals()
	_enter_title()
	_print_ready()
	_warm_effects.call_deferred()


func _build_world() -> void:
	world = ChanganWorld.new()
	world.name = "LampMarketStreet"
	add_child(world)
	street_lights_lit = 0


func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	add_child(cam_rig)
	spring = SpringArm3D.new()
	spring.name = "CameraArm"
	spring.collision_mask = 1
	spring.margin = 0.18
	var sphere := SphereShape3D.new()
	sphere.radius = 0.24
	spring.shape = sphere
	spring.spring_length = cam_distance
	cam_rig.add_child(spring)
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.near = 0.08
	camera.far = 240.0
	camera.fov = 60.0
	camera.position = Vector3(0.34, 0, cam_distance)
	spring.add_child(camera)
	camera.current = true
	cam_rig.global_position = cam_target + Vector3(0, 0, -cam_distance)
	cam_rig.rotation.y = cam_yaw
	spring.rotation.x = cam_pitch


func _build_player() -> void:
	player = ChanganPlayer.new()
	player.name = "ShenDeng"
	player.main = self
	player.position = SPAWN
	player.rotation.y = 0.0
	add_child(player)
	player.attack_landed.connect(_on_attack_landed)
	player.attack_whiffed.connect(_on_attack_whiffed)
	player.died.connect(_on_player_died)
	player.lamp_break_cast.connect(_on_lamp_break)
	player.qi_full.connect(_on_qi_full)
	# 玩家随身补光：替代摄像机 SpotLight，覆盖更小、Intel 上更便宜
	player_fill = OmniLight3D.new()
	player_fill.name = "PlayerFill"
	player_fill.light_color = Color(1.0, 0.86, 0.70)
	player_fill.light_energy = 2.2
	player_fill.omni_range = 11.0
	player_fill.omni_attenuation = 1.1
	player_fill.light_specular = 0.0
	player_fill.shadow_enabled = false
	player_fill.position = SPAWN + Vector3(0, 3.0, -1.3)
	add_child(player_fill)


func _build_npcs() -> void:
	var ahe := ChanganNPC.new()
	ahe.name = "Ahe"
	ahe.setup("ahe")
	ahe.position = Vector3(-5.05, 0.02, 12.6)
	ahe.rotation.y = PI * 0.5
	add_child(ahe)
	npcs["ahe"] = ahe

	var wenjiu := ChanganNPC.new()
	wenjiu.name = "WenJiu"
	wenjiu.setup("wenjiu")
	wenjiu.position = Vector3(2.95, 0.02, 55.2)
	wenjiu.rotation.y = -PI * 0.65
	add_child(wenjiu)
	npcs["wenjiu"] = wenjiu


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.layer = 10
	add_child(layer)
	hud = ChanganHUD.new()
	hud.name = "HUD"
	hud.main = self
	layer.add_child(hud)


func _build_marker() -> void:
	quest_marker = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.23
	tm.rings = 20
	tm.ring_segments = 6
	quest_marker.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.72, 0.28, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.68, 0.24)
	mat.emission_energy_multiplier = 3.0
	mat.disable_receive_shadows = true
	quest_marker.material_override = mat
	quest_marker.rotation.x = PI * 0.5
	quest_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(quest_marker)


func _build_impact_assets() -> void:
	_soft_tex = _make_soft_texture(48)
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_texture = _soft_tex
	_spark_mat.disable_receive_shadows = true
	_spark_quad = QuadMesh.new()
	_spark_quad.size = Vector2(0.14, 0.14)
	_spark_quad.material = _spark_mat

	# 共享命中闪光 / 地面环
	var flash_quad := QuadMesh.new()
	flash_quad.size = Vector2(1.0, 1.0)
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = 0.5
	_flash_mesh.height = 1.0
	_flash_mesh.radial_segments = 8
	_flash_mesh.rings = 4
	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.80
	_ring_mesh.outer_radius = 1.0
	_ring_mesh.rings = 32
	_ring_mesh.ring_segments = 6
	_fx_warm_mat = _fx_material(Color(1.0, 0.72, 0.36))
	_fx_red_mat = _fx_material(Color(1.0, 0.32, 0.18))

	# 火花对象池（4 个）
	for i in 4:
		var sparks := CPUParticles3D.new()
		sparks.amount = 12
		sparks.lifetime = 0.5
		sparks.one_shot = true
		sparks.explosiveness = 0.95
		sparks.local_coords = false
		sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		sparks.emission_sphere_radius = 0.15
		sparks.direction = Vector3.UP
		sparks.spread = 180.0
		sparks.gravity = Vector3(0, -8.0, 0)
		sparks.initial_velocity_min = 2.0
		sparks.initial_velocity_max = 6.0
		sparks.scale_amount_min = 0.4
		sparks.scale_amount_max = 1.4
		sparks.color = Color(1.0, 0.78, 0.42, 0.95)
		sparks.mesh = _spark_quad
		sparks.emitting = false
		sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sparks)
		_spark_pool.append(sparks)

	# 伤害数字对象池（6 个）
	for i in 6:
		var label := Label3D.new()
		label.font = hud.font
		label.font_size = 52
		label.outline_size = 12
		label.outline_modulate = Color(0.02, 0.02, 0.04, 0.95)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.render_priority = 20
		label.pixel_size = 0.0011
		label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.visible = false
		add_child(label)
		_dmg_pool.append(label)
		_dmg_tweens.append(null)

	# 共享火焰：1 个 billboard 火舌 + 1 个油迹（低 overdraw）
	var fire_quad := QuadMesh.new()
	fire_quad.size = Vector2(1.05, 1.25)
	_fire_flame_mat = StandardMaterial3D.new()
	_fire_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_fire_flame_mat.albedo_color = Color(1.0, 0.42, 0.10, 0.62)
	_fire_flame_mat.albedo_texture = _soft_tex
	_fire_flame_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_fire_flame_mat.disable_receive_shadows = true
	fire_quad.material = _fire_flame_mat
	_fire_flame_quad_mesh = fire_quad
	_fire_oil_mesh = CylinderMesh.new()
	_fire_oil_mesh.top_radius = 0.98
	_fire_oil_mesh.bottom_radius = 1.12
	_fire_oil_mesh.height = 0.02
	_fire_oil_mesh.radial_segments = 12
	_fire_oil_mat = StandardMaterial3D.new()
	_fire_oil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fire_oil_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fire_oil_mat.albedo_color = Color(0.05, 0.035, 0.02, 0.52)
	_fire_oil_mat.disable_receive_shadows = true


func _fx_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(color.r, color.g, color.b, 0.6)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	m.disable_receive_shadows = true
	return m


func _connect_signals() -> void:
	# NPC 无信号；敌人信号在 spawn 时连接
	pass


func _make_soft_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# ── lifecycle ───────────────────────────────────────────────────────────────

func _enter_title() -> void:
	game_state = "title"
	current_wave = 0
	encounter_active = false
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	_clear_enemies()
	quest_text = "去面摊找阿禾（E 交谈）"
	story_stage = "meet_ahe"
	_reset_stats()
	street_lights_lit = 0
	for i in world.lamps.size():
		world.set_street_lamp(i, false)
	world.restore_light()
	boss_spawned = false
	boss_defeated = false
	boss_phase2_done = false
	wave1_cleared = false
	wave2_cleared = false
	ahe_noodle_used = false
	ahe_intro_done = false
	player.reset_state(SPAWN, 0.0)
	player.visible = false
	if world.archway_sign != null:
		world.archway_sign.visible = false
	set_cinematic_camera(Vector3(0.4, 2.85, -1.4), Vector3(0.0, 3.15, 20.0), 55.0)
	_set_mouse_capture(false)
	_set_enemies_active(false)


func start_game() -> void:
	if game_state != "title":
		return
	game_state = "playing"
	player.controls_enabled = true
	player.visible = true
	if world.archway_sign != null:
		world.archway_sign.visible = true
	clear_cinematic_camera()
	cam_yaw = PI
	cam_pitch = -0.18
	cam_distance = 4.2
	_camera_snap = true
	_set_mouse_capture(true)
	quest_text = "去面摊找阿禾（E 交谈）"
	toast("WASD 移动 · 鼠标转视角 · Tab 锁定 · E 交互", 5.0)
	print("CHANGAN_START")


func return_to_title() -> void:
	_enter_title()
	print("CHANGAN_TITLE")


func restart_run() -> void:
	_clear_enemies()
	current_wave = 0
	encounter_active = false
	_reset_stats()
	game_state = "playing"
	player.reset_state(SPAWN, 0.0)
	player.visible = true
	if world.archway_sign != null:
		world.archway_sign.visible = true
	player.controls_enabled = true
	story_stage = "meet_ahe"
	quest_text = "去面摊找阿禾（E 交谈）"
	story_beats.clear()
	street_lights_lit = 0
	for i in world.lamps.size():
		world.set_street_lamp(i, false)
	world.restore_light()
	wave1_cleared = false
	wave2_cleared = false
	boss_spawned = false
	boss_defeated = false
	boss_phase2_done = false
	boss_intro_t = 0.0
	ahe_noodle_used = false
	ahe_intro_done = false
	choice = ""
	ending_text = ""
	_set_mouse_capture(true)
	clear_cinematic_camera()
	cam_yaw = PI
	cam_pitch = -0.18
	_camera_snap = true
	toast("再走一遍 · 三盏街灯还在等你", 3.0)
	print("CHANGAN_RESTART_RUN")


func _reset_stats() -> void:
	elapsed = 0.0
	combo = 0
	combo_timer = 0.0
	max_combo = 0
	hits = 0
	hits_taken = 0
	choice = ""
	ending_text = ""
	trauma = 0.0
	hitstop_timer = 0.0
	_result_recorded = false


# ── main loop ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	_t += delta
	if game_state == "playing":
		elapsed += delta
	if hitstop_timer > 0.0:
		hitstop_timer -= delta
		if hitstop_timer <= 0.0:
			_end_hitstop()
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
	if toast_timer > 0.0:
		toast_timer -= delta
	if dialogue_guard > 0.0:
		dialogue_guard -= delta
	trauma = maxf(0.0, trauma - delta * 1.5)
	_update_fire_zones(delta)
	if world != null and player != null:
		world.update_lamp_lights(player.global_position)
	if player_fill != null and player != null:
		player_fill.global_position = player.global_position + Vector3(0, 3.0, -1.3)
	_update_camera(delta)
	_update_triggers(delta)
	_update_interact_prompt()
	_update_marker(delta)
	_update_lock(delta)
	if game_state == "playing" and Input.is_action_just_pressed("interact"):
		if interact_id != "":
			interact(interact_id)
	if game_state == "dialogue" and dialogue_guard <= 0.0:
		if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("advance"):
			advance_dialogue()
	if boss_intro_t > 0.0:
		boss_intro_t -= delta
		if boss_intro_t <= 0.0:
			_end_boss_intro()
	_clamp_actors()


func _update_triggers(_delta: float) -> void:
	if game_state != "playing":
		return
	# Beat 2：走到街中段
	if player.global_position.z > 40.0 and not story_beats.has("B2"):
		_reach_beat("B2")
	# 跳过对话直接走进战斗 1 的兜底
	if story_stage == "meet_ahe" and player.global_position.z > 17.5:
		ahe_intro_done = true
		spawn_wave(1)
		quest_text = "击退泼皮"
		_reach_beat("B1")
		toast("战斗开始 · 左键刺拳 / 右键踢 / 空格翻滚", 3.5)
	# 战斗 2
	if story_stage == "light_street" and wave1_cleared and not encounter_active \
			and player.global_position.z > 43.0:
		spawn_wave(2)
		quest_text = "击退灯油贩"
		toast("油贩会掷火油瓶 · 保持在 4–6 米或直接冲脸", 3.5)
	# Boss
	if not boss_spawned and wave2_cleared \
			and story_stage in ["find_wenjiu", "boss_ready"] \
			and player.global_position.z > 72.0:
		spawn_boss()


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	if cinematic:
		camera.global_position = cinematic_pos
		camera.look_at(cinematic_look, Vector3.UP)
		camera.fov = cinematic_fov
		camera.rotation.z = 0.0
		return
	var target_dist := 3.8 if (boss_ref != null and not boss_ref.is_dead) else 4.2
	var target_fov := 55.0 if (boss_ref != null and not boss_ref.is_dead) else 60.0
	cam_distance = lerpf(cam_distance, target_dist, 1.0 - exp(-2.0 * delta))
	fov_target = target_fov
	var target := player.global_position + Vector3(0, 1.62, 0)
	if _camera_snap:
		cam_target = target
		_camera_snap = false
	else:
		cam_target = cam_target.lerp(target, 1.0 - exp(-10.0 * delta))
	var shake := trauma * trauma
	var jitter := Vector3(
		sin(_t * 57.0) * 0.62 + sin(_t * 33.0 + 1.3) * 0.38,
		sin(_t * 49.0 + 0.4) * 0.55,
		sin(_t * 63.0 + 2.2) * 0.45) * shake * 0.22
	cam_rig.global_position = cam_target + jitter
	cam_rig.rotation.y = cam_yaw
	spring.rotation.x = cam_pitch
	spring.spring_length = cam_distance
	camera.position = Vector3(0.34, 0, cam_distance)
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-3.0 * delta))
	camera.rotation.z = sin(_t * 41.0) * shake * 0.030


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and game_state == "playing" and not cinematic:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.0034
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.0026, -0.82, 0.16)
		return
	if game_state == "title":
		if (event is InputEventKey and event.pressed and not event.echo) \
				or (event is InputEventMouseButton and event.pressed):
			start_game()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_ESCAPE:
			match game_state:
				"playing":
					_pause()
				"paused":
					_resume()
				"dialogue":
					skip_dialogue()
				"defeat":
					return_to_title()
				"results":
					return_to_title()
			get_viewport().set_input_as_handled()
			return
		if game_state == "choice":
			if key == KEY_1:
				choose_ending("mercy")
			elif key == KEY_2:
				choose_ending("end")
			get_viewport().set_input_as_handled()
			return
		if key == KEY_R:
			if game_state == "results":
				restart_run()
			elif game_state == "defeat":
				retry_current_fight()
			elif game_state == "playing" and not encounter_active:
				retry_current_fight()
			get_viewport().set_input_as_handled()
	if game_state == "playing" and event is InputEventMouseButton and event.pressed:
		# 点击回到鼠标捕获（防止失焦后无法转视角）
		if mouse_captured == false:
			_set_mouse_capture(true)


func _pause() -> void:
	game_state = "paused"
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	_set_enemies_active(false)
	_set_mouse_capture(false)
	print("CHANGAN_PAUSE")


func _resume() -> void:
	game_state = "playing"
	player.controls_enabled = true
	_set_enemies_active(true)
	_set_mouse_capture(true)
	print("CHANGAN_RESUME")


func _set_mouse_capture(on: bool) -> void:
	mouse_captured = on
	if DisplayServer.get_name() == "headless":
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE)


func set_mouse_capture(on: bool) -> void:
	_set_mouse_capture(on)


func _clamp_actors() -> void:
	var bounds := _arena_bounds()
	player.global_position.x = clampf(player.global_position.x, bounds.position.x, bounds.end.x)
	player.global_position.z = clampf(player.global_position.z, bounds.position.y, bounds.end.y)
	for e in enemies:
		if e == null or not is_instance_valid(e) or e.is_dead:
			continue
		e.global_position.x = clampf(e.global_position.x, bounds.position.x, bounds.end.x)
		e.global_position.z = clampf(e.global_position.z, bounds.position.y, bounds.end.y)


func _arena_bounds() -> Rect2:
	if encounter_active and current_wave == 1:
		return Rect2(-5.5, 11.0, 11.0, 16.0)
	if encounter_active and current_wave == 2:
		return Rect2(-5.5, 37.5, 11.0, 16.5)
	if encounter_active and current_wave == 3:
		return Rect2(-10.8, 63.5, 21.6, 23.5)
	if player.global_position.z > 61.5:
		return Rect2(-11.8, 61.0, 23.6, 28.0)
	return Rect2(-5.6, 0.2, 11.2, 62.4)


# ── encounters ──────────────────────────────────────────────────────────────

func spawn_enemy(kind: String, pos: Vector3, slot_index: int) -> ChanganEnemy:
	var enemy := ChanganEnemy.new()
	enemy.setup(kind, pos, self, player, slot_index, enemies.size())
	add_child(enemy)
	enemy.died.connect(_on_enemy_died)
	enemies.append(enemy)
	return enemy


func spawn_wave(n: int) -> void:
	_clear_enemies()
	current_wave = n
	encounter_active = true
	attack_token = null
	wave_enemies.clear()
	if n == 1:
		wave_enemies.append(spawn_enemy("thug", Vector3(2.3, 0.06, 20.8), 0))
		wave_enemies.append(spawn_enemy("thug", Vector3(-2.4, 0.06, 22.0), 1))
		story_stage = "fight1"
	elif n == 2:
		wave_enemies.append(spawn_enemy("oil", Vector3(2.7, 0.06, 47.0), 0))
		wave_enemies.append(spawn_enemy("brute", Vector3(-1.8, 0.06, 49.0), 1))
		story_stage = "fight2"
	elif n == 3:
		boss_ref = spawn_enemy("boss", BOSS_SPAWN, 0)
		wave_enemies.append(boss_ref)
		boss_spawned = true
		story_stage = "boss"
		encounter_active = true
	for e in wave_enemies:
		e.active = true
	print("CHANGAN_WAVE_START n=%d count=%d" % [n, wave_enemies.size()])


func live_enemies() -> Array:
	var out: Array = []
	for e in enemies:
		if e != null and is_instance_valid(e) and not e.is_dead and e.visible:
			out.append(e)
	return out


func live_wave_enemies() -> Array:
	var out: Array = []
	for e in wave_enemies:
		if e != null and is_instance_valid(e) and not e.is_dead:
			out.append(e)
	return out


func request_attack_token(enemy: ChanganEnemy) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.archetype == "boss":
		return true
	if attack_token == null or not is_instance_valid(attack_token) or attack_token.is_dead:
		attack_token = enemy
		return true
	return attack_token == enemy


func release_attack_token(enemy: ChanganEnemy) -> void:
	if attack_token == enemy:
		attack_token = null


func _on_enemy_died(enemy: ChanganEnemy) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if enemy == boss_ref:
		_on_boss_defeated(enemy)
		return
	if not encounter_active:
		return
	if live_wave_enemies().is_empty():
		_on_wave_cleared(current_wave)


func _on_wave_cleared(n: int) -> void:
	if not encounter_active:
		return
	encounter_active = false
	attack_token = null
	combo = 0
	combo_timer = 0.0
	if n == 1:
		wave1_cleared = true
		story_stage = "light_street"
		quest_text = "点亮三盏街灯（%d/3）" % street_lights_lit
		toast("泼皮退去 · 街灯可以点亮：E 点亮街灯", 4.0)
		hud.tutorial_muted = false
	elif n == 2:
		wave2_cleared = true
		story_stage = "find_wenjiu"
		quest_text = "去鼓楼找闻九"
		toast("街灯 %d/3 · 去鼓楼找闻九" % street_lights_lit, 4.0)
	print("CHANGAN_WAVE_CLEAR n=%d" % n)


func _clear_enemies() -> void:
	for e in enemies:
		if e != null and is_instance_valid(e):
			e.active = false
			e.queue_free()
	enemies.clear()
	wave_enemies.clear()
	attack_token = null
	boss_ref = null


func _set_enemies_active(v: bool) -> void:
	for e in enemies:
		if e != null and is_instance_valid(e) and not e.is_dead:
			e.active = v
	if not v:
		attack_token = null


# ── boss ────────────────────────────────────────────────────────────────────

func spawn_boss() -> void:
	if boss_spawned:
		return
	_clear_enemies()
	current_wave = 3
	encounter_active = true
	wave_enemies.clear()
	boss_ref = spawn_enemy("boss", BOSS_SPAWN, 0)
	wave_enemies.append(boss_ref)
	boss_spawned = true
	boss_defeated = false
	boss_phase2_done = false
	story_stage = "boss"
	quest_text = "击败霍三更"
	_reach_beat("B3")
	boss_ref.active = false
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	boss_intro_t = 2.8
	if hud != null:
		hud.tutorial_muted = true
	set_cinematic_camera(Vector3(0.0, 2.7, 68.5), Vector3(0.0, 1.45, 76.5), 50.0)
	toast("霍三更 · 灯市行首", 3.0)
	add_trauma(0.25)
	print("CHANGAN_BOSS_START")


func _end_boss_intro() -> void:
	clear_cinematic_camera()
	player.controls_enabled = true
	if boss_ref != null and is_instance_valid(boss_ref) and not boss_ref.is_dead:
		boss_ref.active = true
	toast("灯数决定他能熄掉多少光 · 已点亮 %d/3" % street_lights_lit, 4.0)
	print("CHANGAN_BOSS_FIGHT")


func skip_boss_intro() -> void:
	if boss_intro_t > 0.0:
		boss_intro_t = 0.01


func on_boss_phase2(_boss: ChanganEnemy) -> void:
	if boss_phase2_done:
		return
	boss_phase2_done = true
	var duration := extinguish_duration()
	world.extinguish(duration)
	toast("熄灯 · %d 盏街灯撑住 %.0f 秒黑暗" % [street_lights_lit, duration], 4.0)
	add_trauma(0.55)
	print("CHANGAN_BOSS_PHASE2 lit=%d dark=%.1f" % [street_lights_lit, duration])


func extinguish_duration() -> float:
	return 20.0 - 5.0 * float(street_lights_lit)


func _on_boss_defeated(boss: ChanganEnemy) -> void:
	if boss_defeated:
		return
	boss_defeated = true
	encounter_active = false
	attack_token = null
	_set_enemies_active(false)
	player.play_victory()
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	world.restore_light()
	game_state = "choice"
	quest_text = "灯还亮着 · 做出选择"
	combo = 0
	combo_timer = 0.0
	add_trauma(0.7)
	spawn_impact(boss.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.72, 0.34), 1.6)
	story_stage = "ending"
	_set_mouse_capture(false)
	print("CHANGAN_BOSS_DEFEATED elapsed=%.1f max_combo=%d" % [elapsed, max_combo])


func choose_ending(kind: String) -> void:
	if game_state != "choice":
		return
	if kind != "mercy":
		kind = "end"
	choice = kind
	if kind == "mercy":
		ending_text = "灯还亮着。阿禾把摊子重新支起来，第一碗面没要钱。\n闻九把霍三更交给了巡夜人。第二天，街口的灯多了一盏——有人悄悄点上的。"
	else:
		ending_text = "霍三更的灯灭了。\n第二天，街口多了一盏没人认领的灯。阿禾说：沈哥，你把它点上吧。\n灯亮起来的时候，长安的夜还是那么长。"
	game_state = "results"
	_result_recorded = true
	_set_mouse_capture(false)
	print("CHANGAN_ENDING choice=%s time=%.1f lights=%d max_combo=%d hits_taken=%d" % [
		choice, elapsed, street_lights_lit, max_combo, hits_taken])


# ── story / interaction ─────────────────────────────────────────────────────

func _reach_beat(beat: String) -> void:
	if not story_beats.has(beat):
		story_beats.append(beat)
		print("CHANGAN_BEAT %s" % beat)


func _update_interact_prompt() -> void:
	interact_prompt = ""
	interact_id = ""
	if game_state != "playing" or encounter_active:
		return
	var best := 2.9
	for item in world.interactables:
		if item.get("kind", "") == "lamp":
			var idx: int = item["index"]
			if world.lamps[idx]["lit"]:
				continue
			var d: float = _flat_distance(player.global_position, item["pos"])
			if d < float(item["radius"]) and d < best:
				best = d
				interact_id = String(item["id"])
				interact_prompt = String(item["prompt"])
		elif item.get("kind", "") == "drum":
			var d2: float = _flat_distance(player.global_position, item["pos"])
			if d2 < float(item["radius"]) and d2 < best:
				best = d2
				interact_id = "drum"
				interact_prompt = "E  敲鼓"
	var ahe: ChanganNPC = npcs["ahe"]
	var ahe_d := _flat_distance(player.global_position, ahe.global_position)
	if ahe_d < 3.1 and ahe_d < best:
		best = ahe_d
		interact_id = "ahe"
		if story_stage == "meet_ahe":
			interact_prompt = "E  与阿禾交谈"
		elif not ahe_noodle_used:
			interact_prompt = "E  吃一碗面（+40 气血）"
		else:
			interact_prompt = "E  与阿禾交谈"
	var wenjiu: ChanganNPC = npcs["wenjiu"]
	var wen_d := _flat_distance(player.global_position, wenjiu.global_position)
	if wen_d < 3.0 and wen_d < best:
		best = wen_d
		interact_id = "wenjiu"
		interact_prompt = "E  与闻九交谈"


func interact(id: String) -> void:
	if game_state != "playing" or encounter_active:
		return
	match id:
		"lamp0", "lamp1", "lamp2":
			var index := int(id.substr(4))
			light_street_lamp(index)
		"ahe":
			_talk_ahe()
		"wenjiu":
			_talk_wenjiu()
		"drum":
			toast("鼓声滚过屋脊。广场的方向，灯影在晃。", 2.8)
			add_trauma(0.18)


func _talk_ahe() -> void:
	if story_stage == "meet_ahe":
		begin_dialogue("阿禾", [
			"沈哥，你可算来了。灯油被换了——点得着，可一股黑烟。",
			"霍三更的人说，三更鼓一响，这条街就归他了。",
			"面摊被砸了不打紧，可街上的灯不能灭。",
		], Callable(self, "_on_ahe_intro_done"))
	elif not ahe_noodle_used:
		ahe_noodle_used = true
		player.hp = mini(ChanganPlayer.MAX_HP, player.hp + 40)
		toast("阿禾的面 · 气血 +40", 2.6)
		begin_dialogue("阿禾", [
			"趁热吃。汤里没掺黑油。",
			"你要去鼓楼？把灯都点上。他怕灯。",
		], Callable())
	else:
		begin_dialogue("阿禾", [
			"灯亮着，街上就有人。",
			"别让三更鼓把你的灯也敲灭了。",
		], Callable())


func _on_ahe_intro_done() -> void:
	ahe_intro_done = true
	ahe_noodle_used = false
	if story_stage == "meet_ahe":
		spawn_wave(1)
		quest_text = "击退泼皮"
		_reach_beat("B1")
		toast("左键刺拳 / 右键踢 / 空格翻滚 · Tab 锁定", 4.0)


func _talk_wenjiu() -> void:
	if story_stage in ["find_wenjiu", "boss_ready"]:
		begin_dialogue("闻九", [
			"三更的熄灯术，怕的是街上的灯。你点亮几盏，他就熄几盏。",
			"灯越多，黑暗越短。别让他的铁尺在黑影里找到你。",
			"去吧，鼓我已经替你敲过了。霍三更在广场等你。",
		], Callable(self, "_on_wenjiu_done"))
	else:
		begin_dialogue("闻九", [
			"三十年更鼓，我敲过喜事，也敲过丧事。",
			"这条街的灯，今晚得有人守。",
		], Callable())


func _on_wenjiu_done() -> void:
	story_stage = "boss_ready"
	quest_text = "点亮街灯，前往鼓楼广场（%d/3）" % street_lights_lit
	toast("闻九敲了三下鼓 · 前往鼓楼广场", 4.0)
	add_trauma(0.18)


func light_street_lamp(index: int) -> void:
	if index < 0 or index >= world.lamps.size():
		return
	if world.lamps[index]["lit"]:
		return
	world.set_street_lamp(index, true)
	street_lights_lit = world.lit_count
	toast("街灯 %d / 3 · 灯亮着，街就有人" % street_lights_lit, 2.8)
	if story_stage == "light_street":
		quest_text = ("点亮三盏街灯（%d/3）" % street_lights_lit) if street_lights_lit < 3 else "去鼓楼找闻九"
	elif story_stage == "boss_ready":
		quest_text = "点亮街灯，前往鼓楼广场（%d/3）" % street_lights_lit
	add_trauma(0.08)
	print("CHANGAN_LAMP lit=%d" % street_lights_lit)


# ── dialogue ────────────────────────────────────────────────────────────────

func begin_dialogue(speaker: String, lines: Array[String], on_end := Callable()) -> void:
	if game_state in ["defeat", "results", "choice"]:
		return
	dialogue_speaker = speaker
	dialogue_lines = lines
	dialogue_index = 0
	dialogue_on_end = on_end
	dialogue_guard = 0.18
	game_state = "dialogue"
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	player.velocity = Vector3.ZERO
	_set_enemies_active(false)
	if speaker == "阿禾":
		npcs["ahe"].play_talk()
	elif speaker == "闻九":
		npcs["wenjiu"].play_talk()
	print("CHANGAN_DIALOGUE speaker=%s lines=%d" % [speaker, lines.size()])


func advance_dialogue() -> void:
	if game_state != "dialogue":
		return
	dialogue_index += 1
	if dialogue_index >= dialogue_lines.size():
		_end_dialogue()


func skip_dialogue() -> void:
	if game_state != "dialogue":
		return
	_end_dialogue()


func _end_dialogue() -> void:
	var cb := dialogue_on_end
	dialogue_on_end = Callable()
	game_state = "playing"
	player.controls_enabled = true
	_set_enemies_active(encounter_active)
	if cb.is_valid():
		cb.call()
	print("CHANGAN_DIALOGUE_END")


# ── combat callbacks ────────────────────────────────────────────────────────

func _on_attack_landed(kind: String, damage: int, heavy: bool, knockdown: bool, pos: Vector3) -> void:
	hits += 1
	combo = combo + 1 if combo_timer > 0.0 else 1
	combo_timer = 2.4
	max_combo = maxi(max_combo, combo)
	var color := Color(1.0, 0.94, 0.86)
	if kind in ["finisher", "lampbreak"]:
		color = Color(1.0, 0.76, 0.30)
	elif heavy:
		color = Color(1.0, 0.88, 0.56)
	spawn_damage_number(pos + Vector3(0, 0.15, 0), damage, color)
	var scale := 1.0
	if kind == "kick":
		scale = 1.15
	elif kind in ["finisher", "lampbreak"]:
		scale = 1.5
	spawn_impact(pos, Color(1.0, 0.72, 0.36), scale)
	var stop := 0.034
	if kind == "kick":
		stop = 0.067
	elif kind == "finisher":
		stop = 0.10
	elif kind == "lampbreak":
		stop = 0.134
	apply_hitstop(stop)
	var shake := 0.08
	if kind == "kick":
		shake = 0.15
	elif kind == "finisher":
		shake = 0.22
	elif kind == "lampbreak":
		shake = 0.28
	add_trauma(shake)
	if knockdown:
		toast("击倒 · 追击", 0.9)


func _on_attack_whiffed(pos: Vector3, dir: Vector3, heavy: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.55 if heavy else 0.38, 0.55 if heavy else 0.42)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.95, 0.88, 0.72, 0.35)
	mat.disable_receive_shadows = true
	mi.material_override = mat
	mi.rotation.y = atan2(dir.x, dir.z)
	mi.rotation.x = -0.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(1.2, 1.2, 1.6), 0.14)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.14)
	tw.chain().tween_callback(mi.queue_free)


func on_player_hurt(amount: int) -> void:
	if game_state in ["defeat", "results"]:
		return
	hits_taken += 1
	combo = 0
	combo_timer = 0.0
	hud.flash_red = 0.8
	add_trauma(0.42)
	apply_hitstop(0.03)
	spawn_damage_number(player.global_position + Vector3(0, 2.1, 0), amount, Color(1.0, 0.34, 0.28))
	spawn_enemy_impact(player.global_position + Vector3(0, 1.1, 0), false)


func _on_player_died() -> void:
	if game_state in ["defeat", "results", "choice"]:
		return
	game_state = "defeat"
	player.controls_enabled = false
	player.set_demo_move(Vector3.ZERO)
	_set_enemies_active(false)
	_set_mouse_capture(false)
	toast("", 0.0)
	print("CHANGAN_DEFEAT wave=%d" % current_wave)


func _on_lamp_break(pos: Vector3) -> void:
	add_trauma(0.30)
	for i in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7 + i * 0.25
		tm.outer_radius = 0.86 + i * 0.25
		tm.rings = 48
		tm.ring_segments = 6
		ring.mesh = tm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(1.0, 0.74, 0.32, 0.8)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.68, 0.24)
		mat.emission_energy_multiplier = 3.0
		mat.disable_receive_shadows = true
		ring.material_override = mat
		ring.scale = Vector3(0.3, 1, 0.3)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = pos + Vector3(0, 0.08 + i * 0.05, 0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(ring, "scale", Vector3(6.5, 1, 6.5), 0.7 + i * 0.1)
		tw.tween_property(mat, "albedo_color:a", 0.0, 0.7 + i * 0.1)
		tw.chain().tween_callback(ring.queue_free)


func _on_qi_full() -> void:
	toast("气已满 · Q 释放灯破", 2.0)


func apply_hitstop(duration: float) -> void:
	if duration <= 0.0:
		return
	hitstop_timer = maxf(hitstop_timer, duration)
	player.frozen = true
	player.freeze_anim(true)
	for e in enemies:
		if e != null and is_instance_valid(e) and not e.is_dead:
			e.frozen = true
			e.freeze_anim(true)


func _end_hitstop() -> void:
	hitstop_timer = 0.0
	player.frozen = false
	player.freeze_anim(false)
	for e in enemies:
		if e != null and is_instance_valid(e) and not e.is_dead:
			e.frozen = false
			e.freeze_anim(false)


# ── lock-on ─────────────────────────────────────────────────────────────────

func _update_lock(delta: float) -> void:
	if game_state != "playing":
		return
	if Input.is_action_just_pressed("lock"):
		toggle_lock()
	if lock_target != null:
		if not is_instance_valid(lock_target) or lock_target.is_dead \
				or player.global_position.distance_to(lock_target.global_position) > 10.0:
			lock_target = null
	# 锁定但不抢鼠标：只在玩家没有输入视角时轻微回正
	if lock_target != null and not cinematic:
		var to_target: Vector3 = lock_target.global_position - player.global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var desired := atan2(-to_target.x, -to_target.z)
			var input_move := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
			if input_move.length_squared() < 0.01 and player.state in ["idle", "move", "sprint"]:
				cam_yaw = lerp_angle(cam_yaw, desired, 1.0 - exp(-1.2 * delta))


func toggle_lock() -> void:
	if lock_target != null:
		lock_target = null
		return
	var best: Node3D = null
	var best_score := 999.0
	var forward := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	for e in live_enemies():
		var to_e: Vector3 = e.global_position - player.global_position
		to_e.y = 0.0
		var dist := to_e.length()
		if dist > 8.0:
			continue
		if dist > 0.01 and forward.dot(to_e.normalized()) < 0.2:
			continue
		var score := dist
		if score < best_score:
			best_score = score
			best = e
	lock_target = best
	if lock_target != null:
		toast("锁定 · %s" % lock_target.display_name, 1.2)


func nearest_enemy_in_front(origin: Vector3, range_m: float, min_dot: float) -> Node3D:
	var forward := Vector3(sin(player.rotation.y), 0, cos(player.rotation.y))
	var best: Node3D = null
	var best_dist := range_m
	for e in live_enemies():
		var to_e: Vector3 = e.global_position - origin
		to_e.y = 0.0
		var dist := to_e.length()
		if dist > best_dist:
			continue
		if dist > 0.01 and forward.dot(to_e.normalized()) < min_dot:
			continue
		best = e
		best_dist = dist
	return best


# ── VFX / damage numbers / fire ─────────────────────────────────────────────

func spawn_impact(pos: Vector3, color: Color, scale: float) -> void:
	var fx_mat := _fx_red_mat if color.r > color.g else _fx_warm_mat
	var flash := MeshInstance3D.new()
	flash.mesh = _flash_mesh
	flash.material_override = fx_mat
	flash.scale = Vector3.ONE * maxf(0.30, 0.34 * scale)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	flash.global_position = pos
	flash.transparency = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * (0.55 + 0.25 * scale), 0.16)
	tw.tween_property(flash, "transparency", 1.0, 0.18)
	tw.chain().tween_callback(flash.queue_free)

	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = fx_mat
	ring.scale = Vector3.ONE * maxf(0.12, 0.20 * scale)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	ring.global_position = Vector3(pos.x, 0.06, pos.z)
	ring.transparency = 0.0
	var tw2 := create_tween().set_parallel(true)
	var rs := 0.9 + 0.65 * scale
	tw2.tween_property(ring, "scale", Vector3(rs, 1, rs), 0.26)
	tw2.tween_property(ring, "transparency", 1.0, 0.28)
	tw2.chain().tween_callback(ring.queue_free)

	if scale >= 1.0 and not _spark_pool.is_empty():
		var sparks: CPUParticles3D = _spark_pool[_spark_idx]
		_spark_idx = (_spark_idx + 1) % _spark_pool.size()
		sparks.color = Color(color.r, color.g, color.b, 0.95)
		sparks.global_position = pos
		sparks.restart()
		sparks.emitting = true


func spawn_enemy_impact(pos: Vector3, heavy: bool) -> void:
	spawn_impact(pos, Color(1.0, 0.34, 0.18), 1.3 if heavy else 0.8)


func spawn_damage_number(pos: Vector3, amount: int, color: Color) -> void:
	if _dmg_pool.is_empty():
		return
	var idx := _dmg_idx
	_dmg_idx = (_dmg_idx + 1) % _dmg_pool.size()
	var label: Label3D = _dmg_pool[idx]
	var old_tw: Tween = _dmg_tweens[idx]
	if old_tw != null and old_tw.is_valid():
		old_tw.kill()
	label.visible = true
	label.text = str(amount)
	label.modulate = Color(color.r, color.g, color.b, 1.0)
	label.position = pos + Vector3(randf_range(-0.22, 0.22), randf_range(0.0, 0.18), randf_range(-0.18, 0.18))
	label.scale = Vector3.ONE * 1.32
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", label.position.y + 0.92, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, 0.76)
	tw.tween_property(label, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(label):
			label.visible = false)
	_dmg_tweens[idx] = tw


func spawn_oil_fire(pos: Vector3, duration := 2.5) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = Vector3(pos.x, 0.02, pos.z)
	var oil := MeshInstance3D.new()
	oil.mesh = _fire_oil_mesh
	oil.material_override = _fire_oil_mat
	oil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(oil)
	var flames: Array[MeshInstance3D] = []
	var flame := MeshInstance3D.new()
	flame.mesh = _fire_flame_quad_mesh
	flame.material_override = _fire_flame_mat
	flame.position = Vector3(0, 0.52, 0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flame)
	flames.append(flame)
	fire_zones.append({
		"root": root, "flames": flames, "pos": Vector3(pos.x, 0, pos.z),
		"timer": duration, "duration": duration, "tick": 0.25,
	})
	if fire_zones.size() > 4:
		var old: Dictionary = fire_zones.pop_front()
		if old["root"] != null and is_instance_valid(old["root"]):
			old["root"].queue_free()


func _update_fire_zones(delta: float) -> void:
	if fire_zones.is_empty():
		return
	var expired: Array = []
	for zone in fire_zones:
		zone["timer"] = float(zone["timer"]) - delta
		zone["tick"] = float(zone["tick"]) - delta
		var root: Node3D = zone["root"]
		if root != null and is_instance_valid(root):
			var k: float = clampf(float(zone["timer"]) / 0.4, 0.0, 1.0)
			var t: float = _t * 9.0
			var flames: Array = zone["flames"]
			for i in flames.size():
				var f: MeshInstance3D = flames[i]
				if is_instance_valid(f):
					f.scale = Vector3(0.8 + 0.25 * sin(t + i), k * (0.85 + 0.3 * sin(t * 1.3 + i)), 0.8 + 0.25 * cos(t + i))
		if float(zone["tick"]) <= 0.0:
			zone["tick"] = 0.5
			if game_state == "playing" and player != null and not player.is_dead():
				var d: float = player.global_position.distance_to(zone["pos"])
				if d < 1.55:
					if player.take_damage(2, zone["pos"], false):
						spawn_damage_number(player.global_position + Vector3(0, 1.7, 0), 2, Color(1.0, 0.42, 0.18))
		if float(zone["timer"]) <= 0.0:
			expired.append(zone)
	for zone in expired:
		fire_zones.erase(zone)
		var root2: Node3D = zone["root"]
		if root2 != null and is_instance_valid(root2):
			var tw := create_tween()
			tw.tween_property(root2, "scale", Vector3.ONE * 0.01, 0.28)
			tw.tween_callback(root2.queue_free)


func _free_later(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


# ── quest marker ────────────────────────────────────────────────────────────

func _update_marker(delta: float) -> void:
	if quest_marker == null:
		return
	quest_marker.visible = game_state == "playing" and not encounter_active
	if quest_marker.visible:
		var target = _marker_target()
		if target != null:
			quest_marker.global_position = target + Vector3(0, sin(_t * 2.2) * 0.10, 0)
			quest_marker.rotation.y += delta * 1.6
		else:
			quest_marker.visible = false


func _marker_target() -> Variant:
	match story_stage:
		"meet_ahe":
			return npcs["ahe"].global_position + Vector3(0, 2.45, 0)
		"light_street":
			for i in world.lamps.size():
				if not world.lamps[i]["lit"]:
					return world.lamps[i]["pos"] + Vector3(0, 4.7, 0)
			return npcs["wenjiu"].global_position + Vector3(0, 2.45, 0)
		"find_wenjiu":
			return npcs["wenjiu"].global_position + Vector3(0, 2.45, 0)
		"boss_ready":
			return world.drum_pos + Vector3(0, 3.2, 0)
	return null


# ── camera API ──────────────────────────────────────────────────────────────

func set_cinematic_camera(pos: Vector3, look: Vector3, fov := 55.0) -> void:
	cinematic = true
	cinematic_pos = pos
	cinematic_look = look
	cinematic_fov = fov
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)
	camera.fov = fov
	camera.rotation.z = 0.0


func clear_cinematic_camera() -> void:
	cinematic = false
	camera.fov = 60.0
	_camera_snap = true


func set_hud_visible(v: bool) -> void:
	if hud != null:
		hud.visible = v


func set_controls_enabled(v: bool) -> void:
	player.controls_enabled = v
	if not v:
		player.set_demo_move(Vector3.ZERO)


func get_stats() -> Dictionary:
	return {
		"elapsed": elapsed, "combo": combo, "max_combo": max_combo, "hits": hits,
		"hits_taken": hits_taken, "lights": street_lights_lit, "wave": current_wave,
		"boss_hp": boss_ref.hp if boss_ref != null and is_instance_valid(boss_ref) else 0,
		"stage": story_stage, "state": game_state, "choice": choice,
	}


# ── toast / small helpers ───────────────────────────────────────────────────

func toast(text: String, duration := 2.0) -> void:
	toast_text = text
	toast_timer = duration


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ── retry / defeat ──────────────────────────────────────────────────────────

func retry_current_fight() -> void:
	if game_state == "results":
		restart_run()
		return
	var wave := current_wave
	player.visible = true
	if boss_ref != null or wave == 3:
		_clear_enemies()
		game_state = "playing"
		player.reset_state(Vector3(0, 0.06, 67.0), 0.0)
		player.controls_enabled = true
		current_wave = 3
		encounter_active = true
		boss_ref = spawn_enemy("boss", BOSS_SPAWN, 0)
		wave_enemies.clear()
		wave_enemies.append(boss_ref)
		boss_ref.active = true
		boss_phase2_done = false
		boss_spawned = true
		story_stage = "boss"
		quest_text = "击败霍三更"
		clear_cinematic_camera()
		cam_yaw = PI
		_camera_snap = true
		_set_mouse_capture(true)
		print("CHANGAN_RETRY wave=3")
		return
	if wave == 2:
		_clear_enemies()
		game_state = "playing"
		player.reset_state(Vector3(0, 0.06, 41.0), 0.0)
		player.controls_enabled = true
		spawn_wave(2)
		quest_text = "击退灯油贩"
		clear_cinematic_camera()
		cam_yaw = PI
		_camera_snap = true
		_set_mouse_capture(true)
		print("CHANGAN_RETRY wave=2")
		return
	if wave == 1:
		_clear_enemies()
		game_state = "playing"
		player.reset_state(Vector3(0, 0.06, 14.0), 0.0)
		player.controls_enabled = true
		spawn_wave(1)
		quest_text = "击退泼皮"
		clear_cinematic_camera()
		cam_yaw = PI
		_camera_snap = true
		_set_mouse_capture(true)
		print("CHANGAN_RETRY wave=1")
		return
	# 无战斗：回出生点
	game_state = "playing"
	player.reset_state(SPAWN, 0.0)
	player.controls_enabled = true
	clear_cinematic_camera()
	_camera_snap = true
	_set_mouse_capture(true)
	print("CHANGAN_RETRY none")


# ── warm-up / ready print ───────────────────────────────────────────────────

func _warm_effects() -> void:
	# 首帧着色器/粒子预热：远离视野的小爆发，避免第一次命中卡顿
	spawn_impact(Vector3(0, -6, -8), Color(1.0, 0.6, 0.3), 0.2)
	_warmup_done = true


func _print_ready() -> void:
	var clips := PackedStringArray()
	var bones := 0
	if player != null and player.anim != null:
		clips = PackedStringArray(player.anim.get_animation_list())
		var skels := player.find_children("*", "Skeleton3D", true, false)
		if not skels.is_empty():
			bones = (skels[0] as Skeleton3D).get_bone_count()
	print("CHANGAN_ACTION_READY bones=%d clips=%d lanterns=%d lamps=%d" % [
		bones, clips.size(), world.lantern_count, world.lamps.size()])


# ── demo / test hooks ───────────────────────────────────────────────────────

func demo_teleport(pos: Vector3, facing := 0.0) -> void:
	player.global_position = pos
	player.rotation.y = facing
	player.velocity = Vector3.ZERO
	_camera_snap = true


func demo_move(dir: Vector3) -> void:
	player.set_demo_move(dir)


func demo_stop() -> void:
	player.set_demo_move(Vector3.ZERO)


func demo_attack(kind := "jab") -> void:
	player.begin_attack(kind)


func demo_roll(dir := Vector3.FORWARD) -> void:
	player.start_roll(dir)


func demo_damage_player(amount := 10, knockdown := false) -> void:
	player.take_damage(amount, player.global_position + Vector3(0, 0, -1), knockdown)


func demo_kill_player() -> void:
	player.hp = 1
	player.take_damage(99, player.global_position + Vector3(0, 0, -1), false)


func demo_light_lamp(index: int) -> void:
	light_street_lamp(index)


func demo_set_lights(n: int) -> void:
	for i in world.lamps.size():
		world.set_street_lamp(i, i < n)
	street_lights_lit = world.lit_count


func demo_talk(id: String) -> void:
	interact(id)


func demo_skip_dialogue() -> void:
	skip_dialogue()


func demo_start_wave(n: int) -> void:
	start_game_if_needed()
	spawn_wave(n)


func demo_clear_wave() -> void:
	for e in live_wave_enemies():
		e.hp = 1
		e.take_hit(999, Vector3.FORWARD, 0.2, true, true, "demo")


func demo_kill_enemy(enemy: ChanganEnemy) -> void:
	if enemy != null and is_instance_valid(enemy):
		enemy.hp = 1
		enemy.take_hit(999, Vector3.FORWARD, 0.2, true, true, "demo")


func demo_start_boss() -> void:
	start_game_if_needed()
	spawn_boss()
	skip_boss_intro()


func demo_boss_phase2() -> void:
	if boss_ref != null and is_instance_valid(boss_ref) and not boss_ref.is_dead:
		boss_ref.hp = mini(boss_ref.hp, boss_ref.max_hp / 2 + 1)
		boss_ref.take_hit(2, Vector3.FORWARD, 0.1, false, false, "demo")
		if boss_intro_t > 0.0:
			skip_boss_intro()


func demo_choose(kind: String) -> void:
	choose_ending(kind)


func demo_retry() -> void:
	retry_current_fight()


func demo_restart() -> void:
	restart_run()


func demo_force_results(kind := "mercy") -> void:
	world.restore_light()
	game_state = "choice"
	choose_ending(kind)


func demo_force_title() -> void:
	_enter_title()


func demo_set_player_hp(v: int) -> void:
	player.hp = clampi(v, 1, 100)


func demo_set_quest(text: String) -> void:
	quest_text = text


func start_game_if_needed() -> void:
	if game_state == "title":
		start_game()
	if game_state != "playing":
		game_state = "playing"
		player.controls_enabled = true
		clear_cinematic_camera()
