extends Node3D
## Emberhold 3D scene controller: state flow, camera, 3D view sync, HUD wiring,
## input, map transitions and QA/debug hooks. Simulation lives in game_model.gd.

const GameModelScript = preload("res://scripts/game_model.gd")
const MapDataScript = preload("res://scripts/map_data.gd")
const GData = preload("res://scripts/game_data.gd")
const EMath = preload("res://scripts/ember_math.gd")
const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")
const MapViewScene = preload("res://scenes/map_view.tscn")
const TowerViewScene = preload("res://scenes/tower_view.tscn")
const EnemyViewScene = preload("res://scenes/enemy_view.tscn")
const ProjectileViewScene = preload("res://scenes/projectile_view.tscn")
const VFXScene = preload("res://scenes/vfx.tscn")
const FIELD_RECT := Rect2(0, 48, 928, 672)

@onready var field_box: SubViewportContainer = $FieldLayer/FieldBox
@onready var field_view: SubViewport = $FieldLayer/FieldBox/FieldView
@onready var camera: Camera3D = $FieldLayer/FieldBox/FieldView/Camera3D
@onready var sun: DirectionalLight3D = $FieldLayer/FieldBox/FieldView/Sun
@onready var fill_light: DirectionalLight3D = $FieldLayer/FieldBox/FieldView/Fill
@onready var world_env: WorldEnvironment = $FieldLayer/FieldBox/FieldView/WorldEnvironment
@onready var map_root: Node3D = $FieldLayer/FieldBox/FieldView/World/MapRoot
@onready var towers_root: Node3D = $FieldLayer/FieldBox/FieldView/World/Towers
@onready var enemies_root: Node3D = $FieldLayer/FieldBox/FieldView/World/Enemies
@onready var projectiles_root: Node3D = $FieldLayer/FieldBox/FieldView/World/Projectiles
@onready var vfx_root: Node3D = $FieldLayer/FieldBox/FieldView/World/VFXRoot
@onready var indicators_root: Node3D = $FieldLayer/FieldBox/FieldView/World/Indicators
@onready var hud = $UILayer/HUD
@onready var dither: TextureRect = $DitherLayer/Dither

var model = null
var map_view = null
var scene_name := "menu"
var selected_map := "ashen"
var speed := 1
var selected_tower = null
var build_type := ""
var hover_cell := Vector2i(-1, -1)
var hover_enemy = null
var real_time := 0.0
var menu_time := 0.0
var accum := 0.0
var fps := 60.0
var draw_calls := 0
var _perf_timer := 0.0
var _scale_timer := 0.0
var _last_field_scale := 1.0
var transitioning := false
var transition_t := 0.0
var transition_hold := false
var transition_mid: Callable = Callable()
var dither_mat: ShaderMaterial
var freeze_sim := false
var visuals_enabled := true
var tower_views: Dictionary = {}
var enemy_views: Dictionary = {}
var projectile_views: Dictionary = {}
var ghost = null
var ghost_type := ""
var range_root: Node3D
var range_mesh: MeshInstance3D
var range_fill: MeshInstance3D
var range_mat: StandardMaterial3D
var range_fill_mat: StandardMaterial3D
var cell_marker: Node3D
var cell_mat: StandardMaterial3D
var _field_mouse := Vector2(-999, -999)
var _bench_active := false
var _bench_time := 0.0
var _bench_frames := 0
var _movie_mode := false
var _bench_pending := false
var _field_highres := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	field_box.stretch = false
	_setup_environment()
	_build_indicators()
	dither_mat = ShaderMaterial.new()
	dither_mat.shader = preload("res://shaders/dither.gdshader")
	dither_mat.set_shader_parameter("blocks", Vector2(116.0, 84.0))
	dither.material = dither_mat
	dither.anchor_left = 0.0
	dither.anchor_top = 0.0
	dither.anchor_right = 0.0
	dither.anchor_bottom = 0.0
	dither.offset_left = 0.0
	dither.offset_top = 48.0
	dither.offset_right = 928.0
	dither.offset_bottom = 720.0
	dither.visible = false
	hud.action.connect(_on_hud_action)
	hud.field_pressed.connect(_on_field_pressed)
	hud.field_moved.connect(_on_field_moved)
	hud.field_exited.connect(_on_field_exited)
	get_tree().root.size_changed.connect(_check_render_scale)

	var args := OS.get_cmdline_user_args()
	var autotest_map := ""
	var force_shadows := false
	for arg in args:
		if arg.begins_with("--autotest="):
			autotest_map = arg.substr(11)
		elif arg == "--bench":
			_bench_pending = true
		elif arg == "--movie":
			_movie_mode = true
		elif arg == "--shadows":
			force_shadows = true
	if force_shadows:
		sun.shadow_enabled = true
		sun.directional_shadow_mode = 0
		sun.directional_shadow_max_distance = 60.0
	if autotest_map != "":
		_run_cli_autotest(autotest_map)
		return
	_enter_menu("ashen")
	_check_render_scale()
	if _bench_pending:
		_start_bench.call_deferred()
	elif _movie_mode:
		_start_movie()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#17141f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#59606b")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("#241f2b")
	env.fog_light_energy = 0.6
	env.fog_density = 0.012
	env.fog_sky_affect = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	sun.rotation_degrees = Vector3(-54, -36, 0)
	sun.light_color = Color("#ffb070")
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	sun.directional_shadow_mode = 1
	sun.directional_shadow_max_distance = 90.0
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 1.0
	fill_light.rotation_degrees = Vector3(38, 142, 0)
	fill_light.light_color = Color("#8fa6c8")
	fill_light.light_energy = 0.28
	fill_light.shadow_enabled = false
	sun.shadow_enabled = false
	sun.directional_shadow_mode = 1
	sun.directional_shadow_max_distance = 60.0
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 220.0
	camera.size = 50.0
	_apply_camera()


func _apply_environment(map_def: Dictionary) -> void:
	if world_env.environment == null:
		_setup_environment()
	var art: Dictionary = map_def["art"]
	var env := world_env.environment
	env.background_color = Color(art["sky"])
	env.ambient_light_color = Color(art["ambient"])
	env.fog_light_color = Color(art["fog"])
	env.fog_density = 0.011 if map_def["id"] == "ashen" else 0.014
	sun.light_color = Color(art["sun"]).lerp(Color.WHITE, 0.15)
	fill_light.light_color = Color(art["accent"]).lerp(Color(0.55, 0.55, 0.7), 0.45)


func _apply_camera() -> void:
	var yaw := deg_to_rad(-11.0)
	var pitch := deg_to_rad(-57.0)
	var size := 47.0
	var target := Vector3(0, 0.7, 0.5)
	if scene_name == "menu":
		yaw = deg_to_rad(-12.0 + sin(menu_time * 0.16) * 8.0)
		pitch = deg_to_rad(-54.0)
		size = 49.0
		target = Vector3(0, 0.8, 0)
	else:
		if hud != null and FIELD_RECT.has_point(hud.mouse_pos):
			var m: Vector2 = hud.mouse_pos - FIELD_RECT.position
			target += Vector3((m.x / 928.0 - 0.5) * 1.1, 0, (m.y / 672.0 - 0.5) * 0.7)
		if model != null and model.shake > 0.0:
			target += Vector3(randf_range(-1, 1), randf_range(-1, 1) * 0.5, randf_range(-1, 1)) * model.shake * 0.012
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	camera.size = size
	camera.position = target + dir * 70.0
	camera.look_at(target, Vector3.UP)


func _check_render_scale() -> void:
	if _field_highres:
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var ts := tex.get_size()
	if ts.x <= 0:
		return
	var s := clampf(float(ts.x) / 1280.0, 1.0, 2.0)
	if absf(s - _last_field_scale) < 0.01:
		return
	_last_field_scale = s
	_apply_field_scale(s)


func _apply_field_scale(s: float) -> void:
	field_box.position = Vector2(0, 48)
	field_box.size = Vector2(928.0 * s, 672.0 * s)
	field_box.scale = Vector2(1.0 / s, 1.0 / s)
	field_view.size = Vector2i(roundi(928.0 * s), roundi(672.0 * s))


func _process(delta: float) -> void:
	real_time += delta
	_scale_timer += delta
	if _scale_timer > 0.75:
		_scale_timer = 0.0
		_check_render_scale()
	if transitioning:
		if not transition_hold:
			transition_t += delta
			var p := clampf(transition_t / 0.88, 0.0, 1.0)
			dither_mat.set_shader_parameter("progress", p)
			if p >= 1.0:
				_end_transition()
		if scene_name == "menu":
			menu_time += delta
		_sync_views(delta)
		_update_indicators()
		_apply_camera()
		_update_hud_state()
		_update_perf(delta)
		return
	if scene_name == "menu":
		menu_time += delta
	if model != null and scene_name == "playing" and not freeze_sim:
		accum = minf(accum + delta * float(speed), 0.25)
		var steps := 0
		while accum >= GData.STEP and steps < 40:
			model.simulate(GData.STEP)
			accum -= GData.STEP
			steps += 1
			if not model.over.is_empty():
				accum = 0.0
				break
		if steps >= 40:
			accum = minf(accum, GData.STEP)
	else:
		accum = 0.0
	_sync_views(delta)
	_update_indicators()
	_apply_camera()
	_update_hud_state()
	_update_perf(delta)
	if _bench_active:
		_process_bench(delta)


func _update_perf(delta: float) -> void:
	fps = lerpf(fps, float(Engine.get_frames_per_second()), 0.08)
	_perf_timer += delta
	if _perf_timer > 0.25:
		_perf_timer = 0.0
		draw_calls = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))


func _update_hud_state() -> void:
	hud.model = model
	hud.scene_name = scene_name
	hud.selected_tower = selected_tower
	hud.build_type = build_type
	hud.menu_map = selected_map
	hud.game_speed = speed
	hud.fps = fps
	hud.draw_calls = draw_calls
	hud.hover_enemy = hover_enemy


# ---------- state flow ----------

func _enter_menu(map_id: String) -> void:
	_teardown_game()
	selected_map = map_id
	scene_name = "menu"
	model = null
	_install_map(map_id, null)
	selected_tower = null
	build_type = ""
	hover_enemy = null
	hover_cell = Vector2i(-1, -1)
	hide_indicators()
	menu_time = 0.0
	_apply_camera()


func _enter_game(map_id: String, ai_start: bool, new_speed: int) -> void:
	_teardown_game()
	model = GameModelScript.new()
	model.new_game(map_id, ai_start)
	model.speed = new_speed
	speed = new_speed
	_connect_model()
	_install_map(map_id, model.map)
	scene_name = "playing"
	selected_map = map_id
	selected_tower = null
	build_type = ""
	hover_enemy = null
	hover_cell = Vector2i(-1, -1)
	accum = 0.0
	freeze_sim = false
	menu_time = 0.0
	hide_indicators()
	_apply_camera()
	var map_def: Dictionary = MapDataScript.MAP_DEFS[map_id]
	hud.show_toast("%s · 第 1 波" % map_def["name"], "AI 托管中 · 可随时按 A 接管" if ai_start else "准备布防")


func _install_map(map_id: String, map_info) -> void:
	if map_view != null:
		map_view.queue_free()
		map_view = null
	var info = map_info if map_info != null else MapDataScript.prepare(map_id)
	map_view = MapViewScene.instantiate()
	map_root.add_child(map_view)
	map_view.setup(info)
	_apply_environment(map_view.def)


func _teardown_game() -> void:
	_clear_views()
	_clear_vfx()
	if map_view != null:
		map_view.queue_free()
		map_view = null
	model = null
	selected_tower = null
	build_type = ""
	hover_enemy = null
	hover_cell = Vector2i(-1, -1)
	hide_indicators()


func _connect_model() -> void:
	model.enemy_spawned.connect(_on_enemy_spawned)
	model.enemy_killed.connect(_on_enemy_killed)
	model.enemy_leaked.connect(_on_enemy_leaked)
	model.enemy_healed.connect(_on_enemy_healed)
	model.boss_spawned.connect(_on_boss_spawned)
	model.tower_built.connect(_on_tower_built)
	model.tower_upgraded.connect(_on_tower_upgraded)
	model.tower_sold.connect(_on_tower_sold)
	model.tower_fired.connect(_on_tower_fired)
	model.impact.connect(_on_impact)
	model.skill_cast.connect(_on_skill_cast)
	model.game_over.connect(_on_game_over)
	model.toast.connect(_on_toast)


# ---------- transitions ----------

func _begin_transition(mid: Callable) -> void:
	if transitioning:
		return
	transitioning = true
	transition_hold = false
	transition_t = 0.0
	transition_mid = mid
	var img := field_view.get_texture().get_image()
	if img != null:
		dither.texture = ImageTexture.create_from_image(img)
	dither_mat.set_shader_parameter("progress", 0.0)
	dither.visible = true
	mid.call()


func _end_transition() -> void:
	transitioning = false
	transition_hold = false
	transition_t = 0.0
	dither.visible = false
	transition_mid = Callable()


func _start_manual() -> void:
	_begin_transition(func(): _enter_game(selected_map, false, 1))


func _start_watch() -> void:
	_begin_transition(func(): _enter_game(selected_map, true, 2))


func _restart_run() -> void:
	if transitioning:
		return
	var map_id: String = model.map_id if model != null else selected_map
	var ai: bool = model.ai_on if model != null else false
	var spd := speed
	_begin_transition(func(): _enter_game(map_id, ai, spd))


func _switch_map_run() -> void:
	if transitioning:
		return
	var cur: String = model.map_id if model != null else selected_map
	var nxt := "frost" if cur == "ashen" else "ashen"
	var ai: bool = model.ai_on if model != null else false
	var spd := speed
	_begin_transition(func(): _enter_game(nxt, ai, spd))


func _back_to_menu() -> void:
	if transitioning:
		return
	var last: String = model.map_id if model != null else selected_map
	_begin_transition(func(): _enter_menu(last))


# ---------- view sync ----------

func _clear_views() -> void:
	for v in tower_views.values():
		if is_instance_valid(v):
			v.queue_free()
	for v in enemy_views.values():
		if is_instance_valid(v):
			v.queue_free()
	for v in projectile_views.values():
		if is_instance_valid(v):
			v.queue_free()
	tower_views.clear()
	enemy_views.clear()
	projectile_views.clear()


func _clear_vfx() -> void:
	for child in vfx_root.get_children():
		child.queue_free()


func _spawn_enemy_view(enemy) -> void:
	if not visuals_enabled or map_view == null:
		return
	var v = EnemyViewScene.instantiate()
	enemies_root.add_child(v)
	v.setup(enemy.type)
	if enemy.type == "boss":
		v.scale = Vector3(1.55, 1.55, 1.55)
	elif enemy.type == "brute":
		v.scale = Vector3(1.22, 1.22, 1.22)
	else:
		v.scale = Vector3(1.12, 1.12, 1.12)
	enemy_views[enemy.id] = v
	v.sync(enemy, map_view.to_world(enemy.pos, 0.02), 0.0)


func _spawn_tower_view(tower) -> void:
	if not visuals_enabled or map_view == null:
		return
	var v = TowerViewScene.instantiate()
	towers_root.add_child(v)
	v.setup(tower.type, tower.level)
	v.scale = Vector3(1.3, 1.3, 1.3)
	v.position = map_view.to_world(tower.pos)
	v.set_facing(tower.angle)
	tower_views[tower.id] = v


func _sync_views(delta: float) -> void:
	if model == null or map_view == null:
		return
	var seen_enemies: Dictionary = {}
	for e in model.enemies:
		if not e.alive:
			continue
		seen_enemies[e.id] = true
		var v = enemy_views.get(e.id)
		if v == null or not is_instance_valid(v):
			_spawn_enemy_view(e)
			v = enemy_views.get(e.id)
		if v != null:
			v.sync(e, map_view.to_world(e.pos, 0.02), delta)
	for id in enemy_views.keys():
		if not seen_enemies.has(id):
			var v = enemy_views[id]
			if is_instance_valid(v):
				v.queue_free()
			enemy_views.erase(id)
	var seen_towers: Dictionary = {}
	for t in model.towers:
		seen_towers[t.id] = true
		var v = tower_views.get(t.id)
		if v == null or not is_instance_valid(v):
			_spawn_tower_view(t)
			v = tower_views.get(t.id)
		if v != null:
			v.set_level(t.level)
			v.set_facing(t.angle)
	for id in tower_views.keys():
		if not seen_towers.has(id):
			var v = tower_views[id]
			if is_instance_valid(v):
				v.queue_free()
			tower_views.erase(id)
	var seen_proj: Dictionary = {}
	for p in model.projectiles:
		seen_proj[p.id] = true
		var v = projectile_views.get(p.id)
		if v == null or not is_instance_valid(v):
			v = ProjectileViewScene.instantiate()
			projectiles_root.add_child(v)
			v.setup(p.kind)
			projectile_views[p.id] = v
		v.sync_world(map_view.to_world(p.pos), map_view.to_world(p.last), p, delta)
	for id in projectile_views.keys():
		if not seen_proj.has(id):
			var v = projectile_views[id]
			if is_instance_valid(v):
				v.queue_free()
			projectile_views.erase(id)
	if hover_enemy != null and not hover_enemy.alive:
		hover_enemy = null


func _rebuild_views() -> void:
	_clear_views()
	if model == null:
		return
	for t in model.towers:
		_spawn_tower_view(t)
	for e in model.enemies:
		if e.alive:
			_spawn_enemy_view(e)
	for p in model.projectiles:
		var v = ProjectileViewScene.instantiate()
		projectiles_root.add_child(v)
		v.setup(p.kind)
		projectile_views[p.id] = v


# ---------- model signals ----------

func _on_enemy_spawned(enemy) -> void:
	_spawn_enemy_view(enemy)


func _on_enemy_killed(enemy) -> void:
	var px: Vector2 = enemy.pos
	if _visuals_on():
		var pos := _world(px, 0.35)
		var v = _vfx(pos)
		match enemy.type:
			"moth":
				v.play_burst([Color(0.55, 0.9, 0.85), Color(0.85, 1, 0.95)], 9, 2.4, 0.45, 0.10, 3.0)
			"spore":
				v.play_burst([Color(0.72, 0.58, 1.0), Color(0.9, 0.8, 1.0)], 10, 2.4, 0.5, 0.11, 3.0)
			"boss":
				v.play_burst([Color(1, 0.55, 0.2), Color(1, 0.85, 0.45), Color(0.9, 0.25, 0.15)], 32, 5.5, 1.1, 0.18, 2.0)
				v.play_ring(Color(1, 0.8, 0.4), 4.5, 1.0, 0.12)
			"brute":
				v.play_burst([Color(0.8, 0.55, 0.4), Color(0.9, 0.82, 0.65)], 10, 2.8, 0.5, 0.12, 3.5)
			_:
				v.play_burst([Color(0.8, 0.72, 0.55), Color(0.65, 0.6, 0.55)], 8, 2.2, 0.5, 0.10, 5.0)
		v.play_text("+%d" % enemy.reward, Color("#ffe7a8"), 0.55, 0.9)
	var ev = enemy_views.get(enemy.id)
	if ev != null and is_instance_valid(ev):
		ev.queue_free()
	enemy_views.erase(enemy.id)


func _on_enemy_leaked(enemy) -> void:
	var ev = enemy_views.get(enemy.id)
	if ev != null and is_instance_valid(ev):
		ev.queue_free()
	enemy_views.erase(enemy.id)
	if _visuals_on() and map_view != null:
		var bp: Vector2 = model.map.beacon
		var v = _vfx(_world(bp, 0.4))
		v.play_burst([Color(0.9, 0.42, 0.32), Color(0.7, 0.3, 0.25), Color(0.85, 0.8, 0.7)], 14, 3.0, 0.7, 0.13, 3.0)
		v.play_ring(Color(0.9, 0.42, 0.32), 2.2, 0.6, 0.09)
		v.play_text("−%d 生命" % enemy.leak, Color(0.9, 0.42, 0.32), 0.65, 1.0)
	hud.flash_life()


func _on_enemy_healed(enemy, radius: float) -> void:
	if _visuals_on():
		var v = _vfx(_world(enemy.pos, 0.2))
		v.play_ring(Color(0.72, 0.58, 1.0), radius * 0.125, 0.55, 0.06)
		v.play_burst([Color(0.72, 0.58, 1.0), Color(0.9, 0.82, 1.0)], 5, 1.4, 0.45, 0.08, -0.6)


func _on_boss_spawned(enemy) -> void:
	if _visuals_on():
		var v = _vfx(_world(enemy.pos, 0.5))
		v.play_ring(Color(1, 0.55, 0.2), 3.0, 0.9, 0.12)


func _on_tower_built(tower) -> void:
	_spawn_tower_view(tower)
	if _visuals_on():
		var v = _vfx(_world(tower.pos, 0.2))
		var col: Color = Color(GData.TOWERS[tower.type]["color"])
		v.play_burst([col, Color(0.9, 0.85, 0.7)], 8, 2.0, 0.45, 0.10, 4.0)
		v.play_ring(col, 1.5, 0.38, 0.06)


func _on_tower_upgraded(tower) -> void:
	var v = tower_views.get(tower.id)
	if v != null and is_instance_valid(v):
		v.set_level(tower.level)
	if _visuals_on():
		var col: Color = Color(GData.TOWERS[tower.type]["color"])
		var fx = _vfx(_world(tower.pos, 0.2))
		fx.play_burst([col, Color(1, 0.9, 0.6), Color(0.9, 0.85, 0.7)], 12, 2.4, 0.55, 0.11, 2.0)
		fx.play_ring(col, 2.0, 0.5, 0.07)


func _on_tower_sold(tower, refund: int) -> void:
	var v = tower_views.get(tower.id)
	if v != null and is_instance_valid(v):
		v.queue_free()
	tower_views.erase(tower.id)
	if selected_tower == tower:
		selected_tower = null
	if _visuals_on():
		var fx = _vfx(_world(tower.pos, 0.3))
		fx.play_burst([Color(0.72, 0.68, 0.6), Color(0.95, 0.76, 0.42)], 10, 2.2, 0.5, 0.11, 4.0)
		fx.play_text("+%d" % refund, Color("#ffe7a8"), 0.55, 0.9)


func _on_tower_fired(tower, kind: String) -> void:
	var v = tower_views.get(tower.id)
	if v != null and is_instance_valid(v):
		v.pulse_fire()


func _on_impact(kind: String, pos: Vector2, radius: float) -> void:
	if not _visuals_on():
		return
	var v = _vfx(_world(pos, 0.35))
	if kind == "flame":
		v.play_burst([Color(1, 0.55, 0.18), Color(1, 0.8, 0.4), Color(0.9, 0.3, 0.15)], 10, 3.2, 0.5, 0.13, 4.0)
		v.play_ring(Color(1, 0.72, 0.35), radius * 0.125, 0.4, 0.07)
	elif kind == "frost":
		v.play_burst([Color(0.55, 0.9, 0.88), Color(0.85, 1, 0.97)], 6, 1.8, 0.4, 0.09, 2.0)
		v.play_ring(Color(0.55, 0.9, 0.88), 1.2, 0.3, 0.05)
	else:
		v.play_burst([Color(1, 0.78, 0.45), Color(1, 0.9, 0.6)], 3, 1.2, 0.3, 0.07, 2.0)


func _on_skill_cast(count: int) -> void:
	hud.flash_skill()
	if _visuals_on():
		var v = _vfx(Vector3.ZERO)
		v.play_skill(Vector2(58.0, 42.0))


func _on_game_over(win: bool) -> void:
	scene_name = "over"
	selected_tower = null
	build_type = ""
	hover_cell = Vector2i(-1, -1)
	hide_indicators()
	if _visuals_on() and map_view != null:
		var bp: Vector2 = model.map.beacon
		var v = _vfx(_world(bp, 0.5))
		if win:
			for i in 4:
				v.play_ring(Color(1, 0.72, 0.35), 3.0 + i * 1.4, 0.8 + i * 0.15, 0.09)
			v.play_burst([Color(1, 0.55, 0.2), Color(1, 0.85, 0.5), Color(0.95, 0.76, 0.42)], 34, 5.0, 1.2, 0.16, 1.5)
		else:
			v.play_burst([Color(0.85, 0.35, 0.3), Color(0.25, 0.15, 0.2)], 26, 4.0, 1.0, 0.16, 3.0)


func _on_toast(title: String, sub: String) -> void:
	hud.show_toast(title, sub)


func _visuals_on() -> bool:
	return visuals_enabled and map_view != null and scene_name != "menu"


func _world(px: Vector2, y: float = 0.0) -> Vector3:
	if map_view == null:
		return Vector3(0, y, 0)
	return map_view.to_world(px, y)


func _vfx(world_pos: Vector3):
	var v = VFXScene.instantiate()
	vfx_root.add_child(v)
	v.position = world_pos
	while vfx_root.get_child_count() > 60:
		var first := vfx_root.get_child(0)
		first.queue_free()
		vfx_root.remove_child(first)
	return v


# ---------- indicators ----------

func _build_indicators() -> void:
	range_root = Node3D.new()
	range_root.name = "RangeRing"
	indicators_root.add_child(range_root)
	var st := MK.new_st()
	for i in 48:
		var a := TAU * float(i) / 48.0
		var p := Vector3(cos(a), 0, sin(a))
		MK.add_box(st, p, Vector3(0.022, 0.012, 0.11), Color.WHITE, -a)
	range_mesh = MeshInstance3D.new()
	range_mesh.mesh = MK.finish(st)
	range_mat = Mat.unshaded(Color("#ffd27a"), 1.2, 0.6)
	range_mesh.material_override = range_mat
	range_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_mesh.position.y = 0.10
	range_root.add_child(range_mesh)
	var fill_st := MK.new_st()
	MK.add_disc(fill_st, Vector3.ZERO, 0.98, 40, Color.WHITE)
	range_fill = MeshInstance3D.new()
	range_fill.mesh = MK.finish(fill_st)
	range_fill_mat = Mat.unshaded(Color("#ffd27a"), 0.8, 0.055)
	range_fill.material_override = range_fill_mat
	range_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	range_fill.position.y = 0.085
	range_root.add_child(range_fill)
	range_root.visible = false

	cell_marker = Node3D.new()
	cell_marker.name = "CellMarker"
	indicators_root.add_child(cell_marker)
	var cst := MK.new_st()
	MK.add_box(cst, Vector3(0, 0, -0.94), Vector3(1.9, 0.02, 0.06), Color.WHITE)
	MK.add_box(cst, Vector3(0, 0, 0.94), Vector3(1.9, 0.02, 0.06), Color.WHITE)
	MK.add_box(cst, Vector3(-0.94, 0, 0), Vector3(0.06, 0.02, 1.9), Color.WHITE)
	MK.add_box(cst, Vector3(0.94, 0, 0), Vector3(0.06, 0.02, 1.9), Color.WHITE)
	var cmi := MeshInstance3D.new()
	cmi.mesh = MK.finish(cst)
	cell_mat = Mat.unshaded(Color(0.5, 0.95, 0.5, 0.7), 1.0, 0.7)
	cmi.material_override = cell_mat
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cmi.position.y = 0.10
	cell_marker.add_child(cmi)
	cell_marker.visible = false


func _can_build_at(cell: Vector2i) -> bool:
	if model == null or map_view == null or cell.x < 0:
		return false
	if not model.is_buildable(cell.x, cell.y):
		return false
	if model.tower_at(cell.x, cell.y) != null:
		return false
	if build_type == "":
		return false
	return model.gold >= int(GData.TOWERS[build_type]["cost"])


func _hide_indicators() -> void:
	if range_root != null:
		range_root.visible = false
	if cell_marker != null:
		cell_marker.visible = false
	if ghost != null:
		ghost.visible = false


func hide_indicators() -> void:
	_hide_indicators()


func _ensure_ghost() -> void:
	if build_type == ghost_type:
		return
	if ghost != null:
		ghost.queue_free()
		ghost = null
	ghost_type = ""
	if build_type == "":
		return
	ghost = TowerViewScene.instantiate()
	ghost.setup(build_type, 0, true)
	ghost.scale = Vector3(1.3, 1.3, 1.3)
	indicators_root.add_child(ghost)
	ghost.visible = false
	ghost_type = build_type


func _update_indicators() -> void:
	if model == null or map_view == null or (scene_name != "playing" and scene_name != "paused"):
		_hide_indicators()
		return
	_ensure_ghost()
	var show_range := false
	var center_px := Vector2.ZERO
	var radius_px := 0.0
	var color := Color("#ffd27a")
	var valid := true
	if selected_tower != null:
		var still := false
		for t in model.towers:
			if t == selected_tower:
				still = true
				break
		if not still:
			selected_tower = null
	if selected_tower != null:
		show_range = true
		center_px = selected_tower.pos
		radius_px = GData.tower_range(selected_tower.type, selected_tower.level)
		color = Color(GData.TOWERS[selected_tower.type]["color"])
	elif build_type != "" and hover_cell.x >= 0:
		show_range = true
		center_px = model.map.cell_center(hover_cell.x, hover_cell.y)
		radius_px = GData.tower_range(build_type, 0)
		color = Color(GData.TOWERS[build_type]["color"])
		valid = _can_build_at(hover_cell)
		if not valid:
			color = Color("#d66058")
	if show_range and radius_px > 0.0:
		var wp: Vector3 = map_view.to_world(center_px, 0.0)
		range_root.position = Vector3(wp.x, 0, wp.z)
		var r := radius_px * 0.125
		range_root.scale = Vector3(r, 1, r)
		var pulse := 0.45 + sin(real_time * 3.0) * 0.10
		range_mat.albedo_color = Color(color.r, color.g, color.b, pulse)
		range_fill_mat.albedo_color = Color(color.r, color.g, color.b, 0.06)
		range_root.visible = true
	else:
		range_root.visible = false
	if ghost != null:
		var show_ghost := build_type != "" and hover_cell.x >= 0
		ghost.visible = show_ghost
		if show_ghost:
			var wp: Vector3 = map_view.to_world_cell(hover_cell.x, hover_cell.y, 0.02)
			ghost.position = wp
			ghost.set_ghost_valid(valid)
	if cell_marker != null:
		var show_cell := build_type != "" and hover_cell.x >= 0
		cell_marker.visible = show_cell
		if show_cell:
			var wp: Vector3 = map_view.to_world_cell(hover_cell.x, hover_cell.y, 0.06)
			cell_marker.position = wp
			cell_mat.albedo_color = Color(0.5, 0.95, 0.5, 0.75) if valid else Color(0.95, 0.3, 0.28, 0.8)


# ---------- input ----------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	if transitioning:
		return
	var key := ke.keycode
	if scene_name == "menu":
		match key:
			KEY_ENTER:
				_start_manual()
			KEY_W:
				_start_watch()
			KEY_LEFT, KEY_A:
				_choose_menu_map("ashen")
			KEY_RIGHT, KEY_D:
				_choose_menu_map("frost")
		return
	if scene_name == "over":
		match key:
			KEY_R, KEY_ENTER:
				_restart_run()
			KEY_M:
				_switch_map_run()
			KEY_ESCAPE:
				_back_to_menu()
		return
	if model == null:
		return
	match key:
		KEY_SPACE, KEY_P:
			_toggle_pause()
		KEY_ESCAPE:
			if build_type != "" or selected_tower != null:
				build_type = ""
				selected_tower = null
				_update_indicators()
			else:
				_toggle_pause()
		KEY_1:
			_pick_build("bolt")
		KEY_2:
			_pick_build("flame")
		KEY_3:
			_pick_build("frost")
		KEY_4:
			_pick_build("mint")
		KEY_U, KEY_E:
			_manual_upgrade()
		KEY_S, KEY_X:
			_manual_sell()
		KEY_A:
			_toggle_ai()
		KEY_F, KEY_TAB:
			_cycle_speed()
		KEY_Q:
			_cast_skill_manual()
		KEY_R:
			_restart_run()
		KEY_M:
			_switch_map_run()


func _choose_menu_map(id: String) -> void:
	if transitioning or selected_map == id:
		return
	_begin_transition(func(): _enter_menu(id))


func _on_hud_action(id: String) -> void:
	if transitioning:
		return
	match id:
		"menu_manual":
			if scene_name == "menu":
				_start_manual()
		"menu_ai":
			if scene_name == "menu":
				_start_watch()
		"menu_map_ashen":
			_choose_menu_map("ashen")
		"menu_map_frost":
			_choose_menu_map("frost")
		"shop_bolt":
			_pick_build("bolt")
		"shop_flame":
			_pick_build("flame")
		"shop_frost":
			_pick_build("frost")
		"shop_mint":
			_pick_build("mint")
		"upgrade":
			_manual_upgrade()
		"sell":
			_manual_sell()
		"cancel_build":
			build_type = ""
			_update_indicators()
		"ai_toggle":
			_toggle_ai()
		"skill":
			_cast_skill_manual()
		"speed":
			_cycle_speed()
		"pause":
			_toggle_pause()
		"restart", "pause_restart", "over_restart":
			_restart_run()
		"switch_map", "pause_menu_switch", "over_switch":
			_switch_map_run()
		"menu", "pause_menu", "over_menu":
			_back_to_menu()
		"resume":
			_toggle_pause(0)
		_:
			pass


func _on_field_moved(local_pos: Vector2) -> void:
	_field_mouse = local_pos
	if model == null or map_view == null or (scene_name != "playing" and scene_name != "paused"):
		return
	hover_cell = _pick_cell(local_pos)
	hover_enemy = _pick_enemy(local_pos)
	_update_indicators()


func _on_field_exited() -> void:
	_field_mouse = Vector2(-999, -999)
	hover_cell = Vector2i(-1, -1)
	hover_enemy = null
	_update_indicators()


func _on_field_pressed(local_pos: Vector2, button: int) -> void:
	if transitioning or model == null or (scene_name != "playing" and scene_name != "paused"):
		return
	if button == 2:
		build_type = ""
		selected_tower = null
		_update_indicators()
		return
	var cell := _pick_cell(local_pos)
	if cell.x < 0:
		return
	hover_cell = cell
	var tower = model.tower_at(cell.x, cell.y)
	if tower != null:
		selected_tower = tower
		build_type = ""
		_update_indicators()
		return
	if build_type != "":
		var def: Dictionary = GData.TOWERS[build_type]
		if not model.is_buildable(cell.x, cell.y):
			hud.show_toast("这里不能建造", "请选择路径旁的草地")
			return
		if model.gold < int(def["cost"]):
			hud.show_toast("金币不足", "还差 %d 金" % int(ceil(def["cost"] - model.gold)))
			return
		var res: Dictionary = model.try_build(build_type, cell.x, cell.y, false, "手动布防")
		if bool(res.get("ok", false)):
			selected_tower = res["tower"]
			build_type = ""
			hud.show_toast("%s建成" % def["name"], "手动布防")
			_update_indicators()
		return
	selected_tower = null
	_update_indicators()


func _pick_build(type: String) -> void:
	if scene_name != "playing" and scene_name != "paused":
		return
	if model == null:
		return
	if build_type == type:
		build_type = ""
	else:
		build_type = type
		selected_tower = null
	_ensure_ghost()
	_update_indicators()


func _manual_upgrade() -> void:
	if model == null or selected_tower == null or (scene_name != "playing" and scene_name != "paused"):
		return
	var def: Dictionary = GData.TOWERS[selected_tower.type]
	if selected_tower.level >= 2:
		hud.show_toast("已满级", "该塔已达到 Lv3")
		return
	var cost: int = def["upgrades"][selected_tower.level]
	if model.gold < cost:
		hud.show_toast("金币不足", "升级需要 %d 金" % cost)
		return
	var lv: int = selected_tower.level + 1
	if model.try_upgrade(selected_tower, false, "手动强化"):
		hud.show_toast("%s → Lv%d" % [def["name"], lv + 1], "火力与范围提升")
	_update_indicators()


func _manual_sell() -> void:
	if model == null or selected_tower == null or (scene_name != "playing" and scene_name != "paused"):
		return
	var refund := int(floor(selected_tower.invested * GData.SELL_RATIO))
	var type_name: String = GData.TOWERS[selected_tower.type]["name"]
	if model.try_sell(selected_tower):
		hud.show_toast("已出售", "%s · 返还 %d 金" % [type_name, refund])
		selected_tower = null
	_update_indicators()


func _cast_skill_manual() -> void:
	if model == null:
		return
	if scene_name != "playing":
		hud.show_toast("现在无法施放", "战斗进行中才能施放")
		return
	if model.skill_cd > 0.0:
		hud.show_toast("烬雨冷却中", "还需 %d 秒" % int(ceil(model.skill_cd)))
		return
	if model.alive_enemies().is_empty():
		hud.show_toast("没有目标", "等敌群进入场内再施放")
		return
	model.cast_skill(false)


func _toggle_pause(force: int = -1) -> void:
	if model == null or transitioning or scene_name == "menu" or scene_name == "over":
		return
	var should_pause: bool
	if force == -1:
		should_pause = scene_name == "playing"
	else:
		should_pause = force != 0.0
	if should_pause:
		scene_name = "paused"
	elif scene_name == "paused":
		scene_name = "playing"
		accum = 0.0


func _cycle_speed() -> void:
	if model == null or scene_name == "menu" or scene_name == "over":
		return
	speed = speed % 3 + 1
	model.speed = speed


func _toggle_ai() -> void:
	if model == null or scene_name == "menu" or scene_name == "over":
		return
	model.set_ai(not model.ai_on)


# ---------- picking helpers ----------

func _mouse_to_viewport(local_pos: Vector2) -> Vector2:
	var disp := field_box.size * field_box.scale
	if disp.x <= 0.0:
		return local_pos
	return Vector2(local_pos.x * field_view.size.x / disp.x,
		local_pos.y * field_view.size.y / disp.y)


func _pick_cell(local_pos: Vector2) -> Vector2i:
	if map_view == null:
		return Vector2i(-1, -1)
	var mouse := _mouse_to_viewport(local_pos)
	var origin := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	if absf(dir.y) < 0.00001:
		return Vector2i(-1, -1)
	var t := -origin.y / dir.y
	if t <= 0.0:
		return Vector2i(-1, -1)
	var world := origin + dir * t
	var px: Vector2 = map_view.px_at_world(world)
	if px.x < 0.0 or px.x >= GData.FIELD_W or px.y < 0.0 or px.y >= GData.FIELD_H:
		return Vector2i(-1, -1)
	return Vector2i(int(floor(px.x / GData.TILE)), int(floor(px.y / GData.TILE)))


func _pick_enemy(local_pos: Vector2) -> Variant:
	if model == null:
		return null
	var mouse := _mouse_to_viewport(local_pos)
	var scale := field_view.size.x / 928.0
	var best = null
	var best_d := 34.0 * scale
	for e in model.enemies:
		if not e.alive:
			continue
		var v = enemy_views.get(e.id)
		if v == null or not is_instance_valid(v):
			continue
		var wp: Vector3 = v.position + Vector3(0, v.head_height(), 0)
		var sp := camera.unproject_position(wp)
		var d := sp.distance_to(mouse)
		if d < best_d:
			best_d = d
			best = e
	return best


# ---------- QA / debug hooks ----------

func debug_start_game(map_id: String, ai: bool, spd: int = 1) -> void:
	_enter_game(map_id, ai, spd)
	_update_hud_state()


func debug_menu(map_id: String) -> void:
	_enter_menu(map_id)
	_update_hud_state()


func debug_freeze(on: bool) -> void:
	freeze_sim = on


func debug_pause(on: bool) -> void:
	if on:
		scene_name = "paused"
	elif scene_name == "paused":
		scene_name = "playing"


func debug_set_speed(n: int) -> void:
	speed = clampi(n, 1, 3)
	if model != null:
		model.speed = speed


func debug_fast_forward(seconds: float) -> void:
	if model == null:
		return
	var old := visuals_enabled
	visuals_enabled = false
	var steps := int(seconds / GData.STEP)
	for i in steps:
		if not model.over.is_empty():
			break
		model.simulate(GData.STEP)
	visuals_enabled = old
	accum = 0.0
	_rebuild_views()
	_update_indicators()
	_update_hud_state()


func debug_advance_boss_visible(max_seconds: float = 100.0) -> bool:
	if model == null or model.boss == null:
		return false
	var old := visuals_enabled
	visuals_enabled = false
	var steps := int(max_seconds / GData.STEP)
	var found := false
	for i in steps:
		if not model.over.is_empty() or model.boss == null or not model.boss.alive:
			break
		model.simulate(GData.STEP)
		if i % 6 == 0:
			var wp: Vector3 = map_view.to_world(model.boss.pos, 0.6)
			var sp: Vector2 = camera.unproject_position(wp)
			var vr := Vector2(field_view.size)
			var developed: bool = model.remaining_enemies() <= 14 and model.boss.hp < model.boss.max_hp * 0.85
			if developed and sp.x > vr.x * 0.18 and sp.x < vr.x * 0.78 and sp.y > vr.y * 0.30 and sp.y < vr.y * 0.72:
				found = true
				break
	visuals_enabled = old
	_rebuild_views()
	_update_indicators()
	_update_hud_state()
	return found


func debug_advance_until_boss(max_seconds: float = 650.0) -> bool:
	if model == null:
		return false
	var old := visuals_enabled
	visuals_enabled = false
	var steps := int(max_seconds / GData.STEP)
	var found := false
	for i in steps:
		if not model.over.is_empty():
			break
		if model.boss != null and model.boss.alive:
			found = true
			break
		model.simulate(GData.STEP)
	visuals_enabled = old
	accum = 0.0
	if scene_name != "over":
		_rebuild_views()
	_update_indicators()
	_update_hud_state()
	return found


func debug_set_gold(amount: int) -> void:
	if model != null:
		model.gold = amount


func debug_advance_until_combat(min_enemies: int = 8, min_towers: int = 8, max_seconds: float = 600.0) -> bool:
	if model == null:
		return false
	var old := visuals_enabled
	visuals_enabled = false
	freeze_sim = true
	var steps := int(max_seconds / GData.STEP)
	var found := false
	for i in steps:
		if not model.over.is_empty():
			break
		model.simulate(GData.STEP)
		if model.phase == "wave" and model.wave >= 3 and model.towers.size() >= min_towers 				and model.alive_enemies().size() >= min_enemies:
			found = true
			break
	visuals_enabled = old
	accum = 0.0
	if scene_name != "over":
		_rebuild_views()
	_update_indicators()
	_update_hud_state()
	return found


func debug_pick(type: String) -> void:
	_pick_build(type)


func debug_hover_cell(cx: int, cy: int) -> void:
	hover_cell = Vector2i(cx, cy)
	_update_indicators()


func debug_clear_hover() -> void:
	hover_cell = Vector2i(-1, -1)
	hover_enemy = null
	_update_indicators()


func debug_select_tower(index: int) -> void:
	if model == null or index < 0 or index >= model.towers.size():
		return
	selected_tower = model.towers[index]
	build_type = ""
	_update_indicators()


func debug_set_ai(on: bool) -> void:
	if model != null:
		model.set_ai(on)


func debug_force_finish(win: bool) -> void:
	if model != null:
		model.finish_game(win)


func debug_hold_current_transition(progress: float) -> void:
	if not transitioning:
		return
	transition_hold = true
	dither_mat.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	dither.visible = true
	_update_hud_state()


func debug_set_field_highres(on: bool, factor: float = 1.5) -> void:
	_field_highres = on
	if on:
		_apply_field_scale(factor)
	else:
		_apply_field_scale(1.0)


func debug_set_hud_rate(hz: float) -> void:
	if hud != null:
		hud.hud_interval = 1.0 / maxf(1.0, hz)


func debug_show_transition(progress: float) -> void:
	var img := field_view.get_texture().get_image()
	if img != null:
		dither.texture = ImageTexture.create_from_image(img)
	dither_mat.set_shader_parameter("progress", clampf(progress, 0.0, 1.0))
	dither.visible = true
	transitioning = true
	transition_hold = true


func debug_clear_transition() -> void:
	_end_transition()


func get_state() -> Dictionary:
	var state := {
		"scene": scene_name,
		"map": model.map_id if model != null else selected_map,
		"wave": model.wave if model != null else 0,
		"phase": model.phase if model != null else "",
		"gold": model.gold if model != null else 0,
		"lives": model.lives if model != null else 0,
		"kills": model.kills if model != null else 0,
		"leaks": model.leaks if model != null else 0,
		"enemies": model.alive_enemies().size() if model != null else 0,
		"towers": model.towers.size() if model != null else 0,
		"ai": model.ai_on if model != null else false,
		"speed": speed,
		"fps": fps,
		"draw_calls": draw_calls,
		"tower_views": tower_views.size(),
		"enemy_views": enemy_views.size(),
		"projectile_views": projectile_views.size(),
		"vfx_nodes": vfx_root.get_child_count(),
		"transitioning": transitioning,
		"over": model.over if model != null else {},
	}
	return state


# ---------- bench / movie / CLI autotest ----------

func _start_bench() -> void:
	Engine.max_fps = 0
	if OS.get_cmdline_user_args().has("--nohud"):
		hud.visible = false
	if OS.get_cmdline_user_args().has("--notext"):
		hud.debug_skip_text = true
	_enter_game("ashen", true, 3)
	debug_fast_forward(300.0)
	_bench_active = true
	_bench_time = 0.0
	_bench_frames = 0
	print("BENCH_START towers=%d enemies=%d wave=%d" % [
		model.towers.size() if model != null else 0,
		model.alive_enemies().size() if model != null else 0,
		model.wave if model != null else 0])


func _process_bench(delta: float) -> void:
	_bench_time += delta
	if _bench_time > 1.0:
		_bench_frames += 1
	if _bench_time > 8.0:
		var measured := float(_bench_frames) / maxf(0.001, _bench_time - 1.0)
		print("BENCH_RESULT fps=%.1f engine_fps=%d draw_calls=%d towers=%d enemies=%d wave=%d" % [
			measured, Engine.get_frames_per_second(), draw_calls,
			model.towers.size() if model != null else 0,
			model.alive_enemies().size() if model != null else 0,
			model.wave if model != null else 0])
		get_tree().quit()


func _start_movie() -> void:
	Engine.max_fps = 0
	debug_set_hud_rate(30.0)
	hud.hide_perf = true
	_enter_game("ashen", true, 1)
	debug_fast_forward(468.0)
	freeze_sim = false


func _run_cli_autotest(map_id: String) -> void:
	Engine.max_fps = 0
	var m = GameModelScript.new()
	m.new_game(map_id, true)
	var res: Dictionary = m.run_autotest(900.0)
	print("EMBERHOLD3D_AUTOTEST " + JSON.stringify(res))
	get_tree().quit()

