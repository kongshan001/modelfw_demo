class_name RaceWorld
extends Node3D

# 风车原野 · 青岚杯：单场景单圈卡丁车 vertical slice。
# 核心 loop：倒计时 → 油门/转向/加速带 → 与两名 AI 抢线 → 冲线判定名次 → 胜负/暂停/重开。

const COUNTDOWN_TIME := 3.35
const START_BACK := 6.0
const PLAYER_BODY := Color("#fff0d2")
const PLAYER_ACCENT := Color("#24d3d2")
const RIVAL_A_BODY := Color("#f26758")
const RIVAL_A_ACCENT := Color("#ffe7bb")
const RIVAL_B_BODY := Color("#f6c84d")
const RIVAL_B_ACCENT := Color("#275275")

enum RaceState { COUNTDOWN, RACING, PAUSED, FINISHED }

var state := RaceState.COUNTDOWN
var track: RaceTrack
var camera: Camera3D
var hud: RaceHud
var player: RaceKart
var rivals: Array[RaceKart] = []
var racers: Array[RaceKart] = []
var boost_pads: Array[Dictionary] = []

var countdown_left := COUNTDOWN_TIME
var race_goal := 0.0
var elapsed := 0.0
var go_flash := 0.0
var boost_flash := 0.0
var bump_flash := 0.0
var finish_time := 0.0
var finish_place := 0
var finish_won := false
var finish_best_kmh := 0.0
var finish_boost_count := 0
var capture_freeze := false

var _paused_from := RaceState.RACING
var _finish_order := 0
var _finish_orbit := 0.0
var _cam_shake := 0.0
var _anim_time := 0.0
var _windmill_rotor: Node3D
var _cloud_root: Node3D
var _cam_yaw := 0.0
var _cam_distance := 8.2
var _cam_height := 3.15
var _rng := RandomNumberGenerator.new()
var _film_mode := false
var _film_pos := Vector3.ZERO
var _film_look := Vector3.ZERO
var _decor_tree_count := 0


func _ready() -> void:
	_rng.seed = 20261124
	_setup_input()
	_build_environment()
	track = RaceTrack.new()
	add_child(track)
	track.build()
	race_goal = track.length + START_BACK
	_build_ground()
	_build_scenery()
	_build_windmill()
	_build_boost_pads()
	_spawn_racers()
	_build_camera()
	hud = get_node_or_null("HUD") as RaceHud
	if hud != null:
		hud.setup(self)
		if not hud.restart_requested.is_connected(restart_race):
			hud.restart_requested.connect(restart_race)
		if not hud.resume_requested.is_connected(resume_game):
			hud.resume_requested.connect(resume_game)
	_place_start()
	_reset_camera_immediate()
	state = RaceState.COUNTDOWN
	countdown_left = COUNTDOWN_TIME
	track.set_start_lights(false)
	print("AI_3D_GAME_READY karts=%d pads=%d trees=%d track=%.0fm race_goal=%.0fm" % [racers.size(), boost_pads.size(), _decor_tree_count, track.length, race_goal])


func _exit_tree() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


# ── 输入 ───────────────────────────────────────────────────────────────────
func _setup_input() -> void:
	_action("accelerate", [KEY_W, KEY_UP])
	_action("brake", [KEY_S, KEY_DOWN])
	_action("steer_left", [KEY_A, KEY_LEFT])
	_action("steer_right", [KEY_D, KEY_RIGHT])
	_action("pause", [KEY_ESCAPE, KEY_P])
	_action("restart", [KEY_R])


func _action(action_name: String, keys: Array) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name, 0.18)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = int(key)
		InputMap.action_add_event(action_name, event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart"):
		restart_race()
		get_viewport().set_input_as_handled()


# ── 场景构建 ───────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3d91ef")
	sky_mat.sky_horizon_color = Color("#c5efff")
	sky_mat.sky_curve = 0.15
	sky_mat.ground_horizon_color = Color("#b8e7ff")
	sky_mat.ground_bottom_color = Color("#4c9e62")
	sky_mat.sun_angle_max = 24.0
	sky_mat.sun_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.08
	sky_mat.ground_energy_multiplier = 0.6
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c3dacb")
	env.ambient_light_energy = 0.82
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	var world_env := WorldEnvironment.new()
	world_env.name = "SkyEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#fff0c8")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 85.0
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.4
	add_child(sun)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(360.0, 360.0)
	plane.subdivide_width = 2
	plane.subdivide_depth = 2
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ground.gdshader")
	var ground := MeshInstance3D.new()
	ground.name = "Grass"
	ground.mesh = plane
	ground.material_override = mat
	ground.position.y = -0.035
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_scenery() -> void:
	_build_hills()
	_build_mountains()
	_build_clouds()
	_build_trees()
	_build_bushes_and_flowers()
	_build_rocks()


func _build_hills() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 18:
		var angle := TAU * float(i) / 18.0 + _rng.randf_range(-0.11, 0.11)
		var radius := _rng.randf_range(80.0, 128.0)
		var pos := Vector3(cos(angle) * radius, _rng.randf_range(-11.0, -7.0), sin(angle) * radius)
		var sx := _rng.randf_range(25.0, 38.0)
		var sy := _rng.randf_range(7.0, 12.0)
		var sz := _rng.randf_range(22.0, 34.0)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(sx, sy, sz))
		transforms.append(Transform3D(basis, pos))
		colors.append(Color("#61bd54").lerp(Color("#7ccf61"), _rng.randf()))
	var mat := _vertex_color_material(Color("#ffffff"), 1.0, false)
	_add_multimesh("Hills", sphere, transforms, colors, mat, false)


func _build_mountains() -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 7
	cone.rings = 1
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var cap_transforms: Array[Transform3D] = []
	var cap_colors: Array[Color] = []
	for i in 22:
		var angle := TAU * float(i) / 22.0 + _rng.randf_range(-0.09, 0.09)
		var radius := _rng.randf_range(176.0, 238.0)
		var h := _rng.randf_range(27.0, 52.0)
		var w := _rng.randf_range(30.0, 48.0)
		var base_y := -5.0
		var pos := Vector3(cos(angle) * radius, base_y + h * 0.5, sin(angle) * radius)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(w, h, w * 0.9))
		transforms.append(Transform3D(basis, pos))
		colors.append(Color("#5a8198").lerp(Color("#7fa5ab"), _rng.randf()))
		var cap_h := h * 0.26
		var cap_w := w * 0.30
		var cap_pos := Vector3(cos(angle) * radius, base_y + h * 0.76 + cap_h * 0.5, sin(angle) * radius)
		cap_transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(cap_w, cap_h, cap_w * 0.9)), cap_pos))
		cap_colors.append(Color("#f3fbfc").lerp(Color("#d6eef2"), _rng.randf()))
	var mat := _vertex_color_material(Color("#ffffff"), 1.0, true)
	_add_multimesh("MountainRing", cone, transforms, colors, mat, false)
	_add_multimesh("SnowCaps", cone, cap_transforms, cap_colors, mat, false)


func _build_clouds() -> void:
	_cloud_root = Node3D.new()
	_cloud_root.name = "Clouds"
	add_child(_cloud_root)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 1.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 16:
		var angle := TAU * float(i) / 16.0 + _rng.randf_range(-0.18, 0.18)
		var radius := _rng.randf_range(72.0, 138.0)
		var center := Vector3(cos(angle) * radius, _rng.randf_range(27.0, 42.0), sin(angle) * radius)
		var lumps := _rng.randi_range(5, 7)
		for j in lumps:
			var p := center + Vector3(_rng.randf_range(-6.5, 6.5), _rng.randf_range(-1.2, 2.8), _rng.randf_range(-4.0, 4.0))
			var s := Vector3(_rng.randf_range(4.6, 7.6), _rng.randf_range(2.6, 4.3), _rng.randf_range(3.8, 6.4))
			transforms.append(Transform3D(Basis.IDENTITY.scaled(s), p))
			colors.append(Color("#ffffff").lerp(Color("#e5f7ff"), _rng.randf() * 0.6))
	var mat := _vertex_color_material(Color("#ffffff"), 1.0, false)
	mat.emission_enabled = true
	mat.emission = Color("#e8f9ff")
	mat.emission_energy_multiplier = 0.18
	_add_multimesh("CloudBanks", sphere, transforms, colors, mat, false, _cloud_root)


func _build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.17
	trunk_mesh.bottom_radius = 0.25
	trunk_mesh.height = 2.4
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 1.0
	canopy_mesh.height = 1.8
	canopy_mesh.radial_segments = 7
	canopy_mesh.rings = 4
	var trunk_transforms: Array[Transform3D] = []
	var canopy_transforms: Array[Transform3D] = []
	var canopy_colors: Array[Color] = []
	var tree_count := 96
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < 5000:
		attempts += 1
		var angle := _rng.randf_range(0.0, TAU)
		var radius := _rng.randf_range(12.0, 96.0)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if track.distance_to_center(pos) < 11.5:
			continue
		if pos.distance_to(Vector3(2.0, 0.0, -8.0)) < 12.5:
			continue
		var scale := _rng.randf_range(1.25, 2.35)
		trunk_transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale)), pos + Vector3.UP * (1.2 * scale)))
		var base_color := Color("#49b94e").lerp(Color("#9bdc5a"), _rng.randf())
		for j in 3:
			var offset := Vector3(_rng.randf_range(-0.9, 0.9), _rng.randf_range(0.0, 1.4), _rng.randf_range(-0.8, 0.8)) * scale
			var canopy_scale := scale * _rng.randf_range(0.85, 1.25)
			canopy_transforms.append(Transform3D(
				Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(canopy_scale * 1.35, canopy_scale * 1.05, canopy_scale * 1.35)),
				pos + Vector3.UP * (2.5 * scale) + offset))
			canopy_colors.append(base_color.lerp(Color("#c7ef6b"), _rng.randf() * 0.28))
		placed += 1
	_decor_tree_count = placed
	var trunk_mat := _solid(Color("#a96e43"), 0.94)
	_add_multimesh("TreeTrunks", trunk_mesh, trunk_transforms, [], trunk_mat, false)
	var canopy_mat := _vertex_color_material(Color("#ffffff"), 1.0, false)
	_add_multimesh("TreeCanopies", canopy_mesh, canopy_transforms, canopy_colors, canopy_mat, false)


func _build_bushes_and_flowers() -> void:
	var bush_mesh := SphereMesh.new()
	bush_mesh.radius = 1.0
	bush_mesh.height = 1.0
	bush_mesh.radial_segments = 7
	bush_mesh.rings = 3
	var bush_transforms: Array[Transform3D] = []
	var bush_colors: Array[Color] = []
	var flower_mesh := SphereMesh.new()
	flower_mesh.radius = 0.14
	flower_mesh.height = 0.14
	flower_mesh.radial_segments = 6
	flower_mesh.rings = 3
	var flower_transforms: Array[Transform3D] = []
	var flower_colors: Array[Color] = []
	var flower_palette := [Color("#ffe264"), Color("#ff9ab6"), Color("#fbf3e3"), Color("#70e8df"), Color("#ff8c5e")]
	for i in 52:
		var progress := _rng.randf_range(0.0, track.length)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var offset := side * _rng.randf_range(9.2, 15.5)
		var pos := track.point_at(progress) + track.right_at(progress) * offset
		var s := _rng.randf_range(0.45, 1.15)
		bush_transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s * 1.5, s * 0.9, s * 1.4)), pos + Vector3.UP * (0.35 * s)))
		bush_colors.append(Color("#2f9e52").lerp(Color("#68cf62"), _rng.randf()))
	for i in 120:
		var progress := _rng.randf_range(0.0, track.length)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var offset := side * _rng.randf_range(8.8, 10.6)
		var pos := track.point_at(progress) + track.right_at(progress) * offset
		var s := _rng.randf_range(0.75, 1.45)
		flower_transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), pos + Vector3.UP * 0.20))
		flower_colors.append(flower_palette[_rng.randi_range(0, flower_palette.size() - 1)])
	_add_multimesh("Bushes", bush_mesh, bush_transforms, bush_colors, _vertex_color_material(Color("#ffffff"), 1.0, false), false)
	_add_multimesh("Wildflowers", flower_mesh, flower_transforms, flower_colors, _vertex_color_material(Color("#ffffff"), 0.8, false), false)


func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 0.8
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 3
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	for i in 30:
		var progress := _rng.randf_range(0.0, track.length)
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var pos := track.point_at(progress) + track.right_at(progress) * side * _rng.randf_range(9.0, 18.0)
		var s := _rng.randf_range(0.25, 0.8)
		transforms.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(s * 1.3, s * 0.7, s)), pos + Vector3.UP * (s * 0.20)))
		colors.append(Color("#879aa1").lerp(Color("#b6c3bf"), _rng.randf()))
	_add_multimesh("Rocks", rock_mesh, transforms, colors, _vertex_color_material(Color("#ffffff"), 1.0, false), false)


func _build_windmill() -> void:
	var mill := Node3D.new()
	mill.name = "Windmill"
	mill.position = Vector3(2.0, 0.0, -8.0)
	mill.rotation.y = -0.55
	add_child(mill)
	var cream := _solid(Color("#f8e6c2"), 0.8)
	var coral := _solid(Color("#e1594f"), 0.8)
	var navy := _solid(Color("#285269"), 0.65)
	var wood := _solid(Color("#9b6947"), 0.9)
	var grass_mat := _solid(Color("#4eba57"), 0.98)

	var mound := CylinderMesh.new()
	mound.top_radius = 4.8
	mound.bottom_radius = 5.9
	mound.height = 0.38
	mound.radial_segments = 12
	_mesh_inst(mill, mound, Vector3(0, 0.19, 0), grass_mat, "Mound")
	var tower := CylinderMesh.new()
	tower.top_radius = 2.05
	tower.bottom_radius = 3.0
	tower.height = 7.8
	tower.radial_segments = 8
	tower.rings = 1
	_mesh_inst(mill, tower, Vector3(0, 4.1, 0), cream, "Tower")
	var band_a := CylinderMesh.new()
	band_a.top_radius = 2.55
	band_a.bottom_radius = 2.62
	band_a.height = 0.28
	band_a.radial_segments = 8
	_mesh_inst(mill, band_a, Vector3(0, 2.1, 0), coral, "BandA")
	var band_b := CylinderMesh.new()
	band_b.top_radius = 2.10
	band_b.bottom_radius = 2.17
	band_b.height = 0.24
	band_b.radial_segments = 8
	_mesh_inst(mill, band_b, Vector3(0, 5.5, 0), coral, "BandB")
	var roof := CylinderMesh.new()
	roof.top_radius = 0.0
	roof.bottom_radius = 2.55
	roof.height = 2.7
	roof.radial_segments = 8
	roof.rings = 1
	_mesh_inst(mill, roof, Vector3(0, 9.35, 0), coral, "Roof")
	var hub_base := CylinderMesh.new()
	hub_base.top_radius = 0.38
	hub_base.bottom_radius = 0.38
	hub_base.height = 0.7
	hub_base.radial_segments = 8
	var hub_mesh := _mesh_inst(mill, hub_base, Vector3(0, 7.9, 2.75), navy, "HubBase")
	hub_mesh.rotation.x = PI * 0.5
	var door := BoxMesh.new()
	door.size = Vector3(1.1, 2.2, 0.25)
	_mesh_inst(mill, door, Vector3(0, 1.35, -2.90), wood, "Door").rotation.x = -0.05
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(0.62, 0.75, 0.18)
	_mesh_inst(mill, window_mesh, Vector3(0, 4.3, -2.55), navy, "Window")
	# 侧面阳台
	var balcony := BoxMesh.new()
	balcony.size = Vector3(3.7, 0.22, 1.1)
	_mesh_inst(mill, balcony, Vector3(0, 3.4, -2.7), wood, "Balcony")
	for x in [-1.65, 0.0, 1.65]:
		var rail := BoxMesh.new()
		rail.size = Vector3(0.10, 0.75, 0.10)
		_mesh_inst(mill, rail, Vector3(x, 3.8, -3.18), cream, "BalconyPost")

	# 风车叶片：四片木叶 + 珊瑚叶尖，绕本地 Z 轴旋转。
	_windmill_rotor = Node3D.new()
	_windmill_rotor.name = "Rotor"
	_windmill_rotor.position = Vector3(0, 7.9, 3.18)
	mill.add_child(_windmill_rotor)
	var rotor_hub := CylinderMesh.new()
	rotor_hub.top_radius = 0.3
	rotor_hub.bottom_radius = 0.3
	rotor_hub.height = 0.6
	rotor_hub.radial_segments = 8
	var rotor_hub_mesh := _mesh_inst(_windmill_rotor, rotor_hub, Vector3.ZERO, coral, "RotorHub")
	rotor_hub_mesh.rotation.x = PI * 0.5
	for i in 4:
		var arm := Node3D.new()
		arm.name = "Blade%d" % i
		arm.rotation.z = float(i) * PI * 0.5
		_windmill_rotor.add_child(arm)
		var spar := BoxMesh.new()
		spar.size = Vector3(0.22, 4.6, 0.12)
		_mesh_inst(arm, spar, Vector3(0, 2.55, 0), cream, "BladeSpar")
		var sail := BoxMesh.new()
		sail.size = Vector3(1.18, 3.3, 0.08)
		_mesh_inst(arm, sail, Vector3(0.56, 2.9, 0.02), cream, "BladeSail")
		for rung in 4:
			var slat := BoxMesh.new()
			slat.size = Vector3(1.08, 0.08, 0.10)
			_mesh_inst(arm, slat, Vector3(0.50, 1.7 + float(rung) * 0.75, 0.03), wood, "BladeSlat")
		var tip := BoxMesh.new()
		tip.size = Vector3(1.32, 0.55, 0.10)
		_mesh_inst(arm, tip, Vector3(0.52, 4.72, 0.04), coral, "BladeTip")

	# 干草卷和路边小木牌
	for i in 3:
		var hay := CylinderMesh.new()
		hay.top_radius = 0.72
		hay.bottom_radius = 0.72
		hay.height = 1.15
		hay.radial_segments = 10
		var hay_mesh := _mesh_inst(mill, hay, Vector3(-6.0 + float(i) * 2.2, 0.72, -4.0), _solid(Color("#e5c15e"), 1.0), "Hay%d" % i)
		hay_mesh.rotation.z = PI * 0.5
		hay_mesh.rotation.y = _rng.randf_range(-0.4, 0.4)


func _build_boost_pads() -> void:
	var specs := [0.19, 0.47, 0.74]
	for i in specs.size():
		var progress: float = track.length * float(specs[i])
		var xf := track.grid_transform(progress, 0.0)
		var pad := Node3D.new()
		pad.name = "BoostPad%d" % i
		pad.transform = xf
		add_child(pad)
		var base_mat := _solid(Color("#128ba3"), 0.45)
		base_mat.emission_enabled = true
		base_mat.emission = Color("#31e5ee")
		base_mat.emission_energy_multiplier = 0.8
		var chevron_mat := _solid(Color("#eaffff"), 0.3)
		chevron_mat.emission_enabled = true
		chevron_mat.emission = Color("#9cffff")
		chevron_mat.emission_energy_multiplier = 2.4
		var base := BoxMesh.new()
		base.size = Vector3(5.05, 0.04, 4.0)
		_mesh_inst(pad, base, Vector3(0, 0.075, 0), base_mat, "PadBase")
		# 发光边框
		for side in [-1.0, 1.0]:
			var edge := BoxMesh.new()
			edge.size = Vector3(0.13, 0.045, 3.92)
			_mesh_inst(pad, edge, Vector3(side * 2.46, 0.10, 0), chevron_mat, "PadEdge")
			var cap := BoxMesh.new()
			cap.size = Vector3(5.05, 0.045, 0.13)
			_mesh_inst(pad, cap, Vector3(0, 0.10, side * 1.94), chevron_mat, "PadCap")
		# 三组人字形箭头，尖端朝向车头（本地 -Z）
		for row in 3:
			var z_center := -1.08 + float(row) * 1.08
			for side in [-1.0, 1.0]:
				var bar := BoxMesh.new()
				bar.size = Vector3(1.52, 0.05, 0.24)
				var bar_inst := _mesh_inst(pad, bar, Vector3(side * 0.63, 0.12, z_center), chevron_mat, "PadArrow")
				bar_inst.rotation.y = -side * 0.60
				bar_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		boost_pads.append({
			"node": pad,
			"center": xf.origin,
			"cooldown": 0.0,
			"base_mat": base_mat,
			"chevron_mat": chevron_mat,
			"progress": progress,
		})


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "ChaseCamera"
	camera.fov = 67.0
	camera.near = 0.08
	camera.far = 320.0
	camera.current = true
	add_child(camera)


func _spawn_racers() -> void:
	player = RaceKart.new()
	player.display_name = "阿栗"
	add_child(player)
	player.setup(track, true, PLAYER_BODY, PLAYER_ACCENT, 0.0, 0.0)
	player.bumped.connect(_on_player_bumped)

	var rival_a := RaceKart.new()
	rival_a.display_name = "齿轮仔"
	add_child(rival_a)
	rival_a.setup(track, false, RIVAL_A_BODY, RIVAL_A_ACCENT, -2.35, 22.4)
	rivals.append(rival_a)

	var rival_b := RaceKart.new()
	rival_b.display_name = "泡泡糖"
	add_child(rival_b)
	rival_b.setup(track, false, RIVAL_B_BODY, RIVAL_B_ACCENT, 2.35, 23.2)
	rivals.append(rival_b)
	racers.append(player)
	racers.append(rival_a)
	racers.append(rival_b)


func _place_start() -> void:
	var grid_progress := fposmod(-START_BACK, track.length)
	player.reset_at(grid_progress, 0.0)
	rivals[0].reset_at(grid_progress, -2.35)
	rivals[1].reset_at(grid_progress, 2.35)
	current_places()


# ── 冠军圈流程 ─────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if state != RaceState.PAUSED:
		_anim_time += dt
		_animate_world(dt)
		go_flash = maxf(0.0, go_flash - dt)
		boost_flash = maxf(0.0, boost_flash - dt)
		bump_flash = maxf(0.0, bump_flash - dt)
	if capture_freeze:
		_update_camera(dt)
		return
	match state:
		RaceState.COUNTDOWN:
			countdown_left = maxf(0.0, countdown_left - dt)
			if countdown_left <= 0.0:
				_start_race()
			_update_camera(dt)
		RaceState.RACING:
			elapsed += dt
			player.step_player(dt)
			for rival in rivals:
				rival.step_ai(dt, player.race_distance)
			_update_boost_pads(dt)
			current_places()
			_check_finish()
			_update_camera(dt)
		RaceState.FINISHED:
			_update_camera(dt)
		RaceState.PAUSED:
			pass


func _start_race() -> void:
	if state != RaceState.COUNTDOWN:
		return
	state = RaceState.RACING
	countdown_left = 0.0
	go_flash = 0.85
	player.release()
	for rival in rivals:
		rival.release()
	track.set_start_lights(true)
	print("RACE_GO go_flash=%.2f" % go_flash)


func _check_finish() -> void:
	for rival in rivals:
		if not rival.finished and rival.race_distance >= race_goal:
			_finish_order += 1
			rival.mark_finished(_finish_order)
			print("RIVAL_FINISH %s place=%d" % [rival.display_name, _finish_order])
	if not player.finished and player.race_distance >= race_goal:
		_finish_race()


func _finish_race() -> void:
	finish_place = 1 + _finish_order
	finish_time = elapsed
	finish_won = finish_place == 1
	finish_best_kmh = player.best_speed * 3.6
	finish_boost_count = player.boost_count
	player.mark_finished(finish_place)
	for rival in rivals:
		if not rival.finished:
			rival.stop()
	state = RaceState.FINISHED
	go_flash = 0.0
	_finish_orbit = 0.0
	_release_drive_actions()
	print("RACE_FINISH place=%d time=%.2f best_kmh=%.1f boosts=%d won=%s" % [
		finish_place, finish_time, finish_best_kmh, finish_boost_count, str(finish_won)])


func toggle_pause() -> void:
	if state == RaceState.PAUSED:
		state = _paused_from
		if state == RaceState.RACING:
			player.active = not player.finished
			for rival in rivals:
				rival.active = not rival.finished
		_release_drive_actions()
		return
	if state == RaceState.RACING or state == RaceState.COUNTDOWN:
		_paused_from = state
		state = RaceState.PAUSED
		player.active = false
		for rival in rivals:
			rival.active = false
		_release_drive_actions()


func resume_game() -> void:
	if state == RaceState.PAUSED:
		toggle_pause()


func restart_race() -> void:
	_release_drive_actions()
	var tree := get_tree()
	if tree == null:
		return
	if tree.current_scene == self:
		tree.reload_current_scene()
		return
	var parent := get_parent()
	if parent != null:
		var fresh: Node = load("res://scenes/main.tscn").instantiate()
		parent.add_child(fresh)
		queue_free()
	else:
		tree.reload_current_scene()


func _release_drive_actions() -> void:
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")


func _update_boost_pads(dt: float) -> void:
	for i in boost_pads.size():
		var pad: Dictionary = boost_pads[i]
		pad["cooldown"] = maxf(0.0, float(pad["cooldown"]) - dt)
		if float(pad["cooldown"]) > 0.0:
			continue
		var center: Vector3 = pad["center"]
		var dx := player.global_position.x - center.x
		var dz := player.global_position.z - center.z
		if dx * dx + dz * dz > 2.45 * 2.45:
			continue
		if player.apply_boost(1.45):
			pad["cooldown"] = 3.4
			boost_flash = 1.0
			_cam_shake = maxf(_cam_shake, 0.16)
			print("BOOST_PAD index=%d distance=%.0f" % [i, player.race_distance])


func _animate_world(dt: float) -> void:
	if _windmill_rotor != null:
		_windmill_rotor.rotation.z += dt * 0.55
	if _cloud_root != null:
		_cloud_root.rotation.y += dt * 0.0022
	for pad in boost_pads:
		var base_mat: StandardMaterial3D = pad["base_mat"]
		var chevron_mat: StandardMaterial3D = pad["chevron_mat"]
		var available := float(pad["cooldown"]) <= 0.0
		var pulse := 0.78 + sin(_anim_time * 5.5 + float(pad["progress"])) * 0.20
		chevron_mat.emission_energy_multiplier = (1.9 if available else 0.28) * pulse
		base_mat.emission_energy_multiplier = (0.55 if available else 0.12) * pulse
		var node: Node3D = pad["node"]
		node.position.y = sin(_anim_time * 2.4 + float(pad["progress"])) * 0.008


func _update_camera(delta: float) -> void:
	if camera == null or player == null:
		return
	if _film_mode:
		camera.global_position = _film_pos
		camera.look_at(_film_look, Vector3.UP)
		return
	var fov_target := 67.0
	if state == RaceState.FINISHED:
		_finish_orbit += delta * 0.32
		var orbit := _finish_orbit + 0.8
		var target_pos := player.global_position + Vector3(cos(orbit) * 7.0, 4.0, sin(orbit) * 7.0)
		camera.global_position = camera.global_position.lerp(target_pos, 1.0 - exp(-delta * 2.4))
		camera.look_at(player.global_position + Vector3(0, 0.95, 0), Vector3.UP)
		camera.fov = lerpf(camera.fov, 59.0, 1.0 - exp(-delta * 2.0))
		return
	# 相机是“平滑朝向的追尾支架”，而不是世界坐标弹簧：
	# 转向时围绕车摆动，但始终与车保持固定距离，避免相机抄内线穿过车身、把车甩出画面。
	var target_distance := 8.2 if state == RaceState.COUNTDOWN else 7.2
	var target_height := 3.15 if state == RaceState.COUNTDOWN else 2.65
	var follow := 1.0 - exp(-delta * 5.5)
	_cam_yaw = lerp_angle(_cam_yaw, player.yaw, follow)
	_cam_distance = lerpf(_cam_distance, target_distance, follow)
	_cam_height = lerpf(_cam_height, target_height, follow)
	var back := Vector3(sin(_cam_yaw), 0.0, cos(_cam_yaw))
	camera.global_position = player.global_position + back * _cam_distance + Vector3.UP * _cam_height
	var look_ahead := 4.2 + player.speed_kmh() * 0.020
	var look := player.global_position + player.forward() * look_ahead + Vector3.UP * 0.95
	if _cam_shake > 0.0:
		var shake := Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-0.5, 0.5), _rng.randf_range(-1, 1)) * _cam_shake * 0.18
		camera.global_position += shake
		_cam_shake = maxf(0.0, _cam_shake - delta * 1.7)
	camera.look_at(look, Vector3.UP)
	fov_target += clampf(player.speed_kmh() / 130.0, 0.0, 1.0) * 7.0
	if player.boost_timer > 0.0:
		fov_target += 5.0
	camera.fov = lerpf(camera.fov, fov_target, 1.0 - exp(-delta * 3.2))


func _reset_camera_immediate() -> void:
	if camera == null or player == null:
		return
	_cam_yaw = player.yaw
	_cam_distance = 8.2
	_cam_height = 3.15
	var forward := player.forward()
	camera.global_position = player.global_position - forward * _cam_distance + Vector3.UP * _cam_height
	camera.look_at(player.global_position + forward * 3.4 + Vector3.UP * 1.0, Vector3.UP)


func _on_player_bumped() -> void:
	_cam_shake = maxf(_cam_shake, 0.23)
	bump_flash = 1.0


func current_places() -> int:
	if player == null:
		return 1
	var place := 1
	for rival in rivals:
		if rival.finished or rival.race_distance > player.race_distance + 0.01:
			place += 1
	player.current_place = place
	return place


func place_of(kart: RaceKart) -> int:
	var place := 1
	for other in racers:
		if other == kart:
			continue
		if other.finished or other.race_distance > kart.race_distance + 0.01:
			place += 1
	return place


func countdown_number() -> int:
	return clampi(ceili(countdown_left), 0, 3)


func time_text() -> String:
	var total := elapsed
	var minutes := int(total / 60.0)
	var seconds := int(fmod(total, 60.0))
	var centis := int(fmod(total * 100.0, 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centis]


func finish_time_text() -> String:
	var total := finish_time
	var minutes := int(total / 60.0)
	var seconds := int(fmod(total, 60.0))
	var centis := int(fmod(total * 100.0, 100.0))
	return "%02d:%02d.%02d" % [minutes, seconds, centis]


# ── 截图/测试辅助（不改玩法规则） ─────────────────────────────────────────
func debug_start_now() -> void:
	countdown_left = 0.0
	_start_race()


func debug_place_player_at_distance(distance: float, speed_override := 18.0) -> void:
	var d := fposmod(player.start_progress + distance, track.length)
	player.global_position = track.point_at(d)
	var tangent := track.tangent_at(d)
	player.yaw = atan2(-tangent.x, -tangent.z)
	player.rotation.y = player.yaw
	player.last_progress = d
	player.race_distance = distance
	player.speed = speed_override
	_update_camera(1.0)


func debug_set_rival_distance(index: int, distance: float) -> void:
	if index < 0 or index >= rivals.size():
		return
	var rival := rivals[index]
	var d := fposmod(rival.start_progress + distance, track.length)
	rival.ai_progress = d
	rival.race_distance = distance
	rival.global_position = track.point_at(d) + track.right_at(d) * rival.ai_lane
	var tangent := track.tangent_at(d)
	rival.yaw = atan2(-tangent.x, -tangent.z)
	rival.rotation.y = rival.yaw


func set_film_camera(pos: Vector3, look: Vector3) -> void:
	_film_mode = true
	_film_pos = pos
	_film_look = look
	if camera != null:
		camera.global_position = pos
		camera.look_at(look, Vector3.UP)


func clear_film_camera() -> void:
	_film_mode = false


# ── 工具 ───────────────────────────────────────────────────────────────────
func _solid(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = 0.0
	return mat


func _vertex_color_material(base: Color, roughness: float, unshaded: bool) -> StandardMaterial3D:
	var mat := _solid(base, roughness)
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _mesh_inst(parent: Node3D, mesh: Mesh, pos: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], colors: Array[Color], material: Material, shadows: bool, parent: Node3D = null) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.use_colors = true
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		if i < colors.size():
			multimesh.set_instance_color(i, colors[i])
		else:
			multimesh.set_instance_color(i, Color.WHITE)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	return instance
