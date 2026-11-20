extends Node

# 主控：搭世界、昼夜调色、镜像相机倒影、参数入口和键盘操作。
# 画面结构：1280×720 窗口 ← 2× 最近邻放大 ← 640×360 的 3D SubViewport。
# 倒影：另一个 320×180 SubViewport 共享同一个 World3D，用镜像相机从水下拍，
#       水面 shader 以 (1-u, v) 采样它。镜像平面不固定在 y=0，而是跟着
#       木筏所在水面的平均高度（木筏吃水线）走：波浪把水面抬到 y≈+0.5 时，
#       若仍按 y=0 镜像，倒影会被压到水线下方 2h，看起来像船悬空。
#       镜像平面随木筏平滑起伏，远处天空反射的微小漂移可以忽略。

const PIXEL_SIZE := Vector2i(640, 360)
const REFLECTION_SIZE := Vector2i(320, 180)
const CAMERA_FOV := 46.0
const SUN_AZIMUTH_DEG := 222.0
const WATER_LEVEL := 0.0
const OCEAN_LAYER := 1 << 1
const UNDERWATER_LAYER := 1 << 2

const PRESET_TIMES := [12.5, 18.4, 22.5]

@onready var _world_viewport: SubViewport = $WorldViewport
@onready var _display: TextureRect = $WorldDisplay
@onready var _world: Node3D = $WorldViewport/World
@onready var _hud = $HUD

# 当前参数（HUD / 按键读改这些）
var wave_height := 1.15
var wave_direction := 0.0
var foam_amount := 0.85
var transparency := 0.22
var reflection_strength := 0.90
var sparkle_amount := 1.10
var time_of_day := 18.4
var paused := false
var debug_points := false

var _camera
var _sun: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: WorldEnvironment
var _sky: MeshInstance3D
var _sky_mat: ShaderMaterial
var _seabed_mat: ShaderMaterial
var _ocean
var _raft
var _reflection_vp: SubViewport
var _reflection_cam: Camera3D
var _mirror_plane_y := WATER_LEVEL
var _reflection_enabled := true
var _ui_visible := true
var _palette: Dictionary = {}


# 时间 → 天空 / 海水 / 光。颜色都是原创手调的 4 档水色 + 天际色。
const SKY_KEYS := [
	{
		"t": 0.0,
		"zenith": Color(0.010, 0.020, 0.055),
		"horizon": Color(0.040, 0.075, 0.140),
		"sun": Color(0.66, 0.80, 1.00),
		"sun_energy": 0.42,
		"sun_elev": 8.0,
		"ambient": Color(0.14, 0.22, 0.40),
		"ambient_energy": 1.00,
		"stars": 1.0,
		"clouds": 0.10,
		"cloud": Color(0.08, 0.12, 0.22),
		"deep": Color(0.008, 0.030, 0.055),
		"mid": Color(0.018, 0.070, 0.120),
		"light": Color(0.040, 0.160, 0.240),
		"crest": Color(0.120, 0.340, 0.460),
		"foam": Color(0.68, 0.84, 1.00),
		"gold": Color(0.66, 0.82, 1.00),
	},
	{
		"t": 6.5,
		"zenith": Color(0.16, 0.19, 0.36),
		"horizon": Color(0.78, 0.44, 0.36),
		"sun": Color(1.00, 0.66, 0.42),
		"sun_energy": 0.80,
		"sun_elev": 3.0,
		"ambient": Color(0.30, 0.28, 0.40),
		"ambient_energy": 0.95,
		"stars": 0.25,
		"clouds": 0.55,
		"cloud": Color(0.88, 0.58, 0.52),
		"deep": Color(0.050, 0.100, 0.170),
		"mid": Color(0.120, 0.220, 0.300),
		"light": Color(0.300, 0.420, 0.460),
		"crest": Color(0.800, 0.580, 0.480),
		"foam": Color(0.96, 0.84, 0.78),
		"gold": Color(1.00, 0.72, 0.45),
	},
	{
		"t": 9.0,
		"zenith": Color(0.18, 0.42, 0.65),
		"horizon": Color(0.68, 0.84, 0.86),
		"sun": Color(1.00, 0.94, 0.80),
		"sun_energy": 1.15,
		"sun_elev": 56.0,
		"ambient": Color(0.50, 0.66, 0.76),
		"ambient_energy": 0.95,
		"stars": 0.0,
		"clouds": 0.35,
		"cloud": Color(0.93, 0.96, 0.96),
		"deep": Color(0.030, 0.160, 0.240),
		"mid": Color(0.070, 0.380, 0.470),
		"light": Color(0.180, 0.620, 0.620),
		"crest": Color(0.620, 0.920, 0.860),
		"foam": Color(0.96, 0.99, 1.00),
		"gold": Color(1.00, 0.90, 0.64),
	},
	{
		"t": 16.0,
		"zenith": Color(0.18, 0.40, 0.62),
		"horizon": Color(0.74, 0.82, 0.82),
		"sun": Color(1.00, 0.86, 0.62),
		"sun_energy": 1.20,
		"sun_elev": 34.0,
		"ambient": Color(0.52, 0.58, 0.66),
		"ambient_energy": 0.95,
		"stars": 0.0,
		"clouds": 0.45,
		"cloud": Color(0.96, 0.88, 0.78),
		"deep": Color(0.035, 0.150, 0.230),
		"mid": Color(0.070, 0.310, 0.400),
		"light": Color(0.180, 0.520, 0.550),
		"crest": Color(0.600, 0.860, 0.790),
		"foam": Color(0.98, 0.98, 0.96),
		"gold": Color(1.00, 0.82, 0.52),
	},
	{
		"t": 18.4,
		"zenith": Color(0.20, 0.13, 0.34),
		"horizon": Color(1.00, 0.55, 0.28),
		"sun": Color(1.00, 0.58, 0.26),
		"sun_energy": 1.30,
		"sun_elev": 4.5,
		"ambient": Color(0.46, 0.28, 0.40),
		"ambient_energy": 0.95,
		"stars": 0.15,
		"clouds": 0.85,
		"cloud": Color(0.96, 0.55, 0.40),
		"deep": Color(0.030, 0.040, 0.120),
		"mid": Color(0.090, 0.100, 0.280),
		"light": Color(0.240, 0.160, 0.380),
		"crest": Color(0.850, 0.430, 0.360),
		"foam": Color(1.00, 0.90, 0.76),
		"gold": Color(1.00, 0.74, 0.30),
	},
	{
		"t": 21.5,
		"zenith": Color(0.010, 0.020, 0.055),
		"horizon": Color(0.040, 0.075, 0.140),
		"sun": Color(0.66, 0.80, 1.00),
		"sun_energy": 0.42,
		"sun_elev": 8.0,
		"ambient": Color(0.14, 0.22, 0.40),
		"ambient_energy": 1.00,
		"stars": 1.0,
		"clouds": 0.08,
		"cloud": Color(0.08, 0.12, 0.22),
		"deep": Color(0.008, 0.030, 0.055),
		"mid": Color(0.018, 0.070, 0.120),
		"light": Color(0.040, 0.160, 0.240),
		"crest": Color(0.120, 0.340, 0.460),
		"foam": Color(0.68, 0.84, 1.00),
		"gold": Color(0.66, 0.82, 1.00),
	},
	{
		"t": 24.0,
		"zenith": Color(0.010, 0.020, 0.055),
		"horizon": Color(0.040, 0.075, 0.140),
		"sun": Color(0.66, 0.80, 1.00),
		"sun_energy": 0.42,
		"sun_elev": 8.0,
		"ambient": Color(0.14, 0.22, 0.40),
		"ambient_energy": 1.00,
		"stars": 1.0,
		"clouds": 0.10,
		"cloud": Color(0.08, 0.12, 0.22),
		"deep": Color(0.008, 0.030, 0.055),
		"mid": Color(0.018, 0.070, 0.120),
		"light": Color(0.040, 0.160, 0.240),
		"crest": Color(0.120, 0.340, 0.460),
		"foam": Color(0.68, 0.84, 1.00),
		"gold": Color(0.66, 0.82, 1.00),
	},
]


func _ready() -> void:
	_world_viewport.size = PIXEL_SIZE
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_display.texture = _world_viewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_build_environment()
	_build_sky()
	_build_seabed()
	_build_ocean()
	_build_raft()
	_build_camera()
	_build_reflection()

	_apply_time_of_day(time_of_day)
	set_wave_height(wave_height)
	set_wave_direction(wave_direction)
	set_foam_amount(foam_amount)
	set_transparency(transparency)
	set_reflection_strength(reflection_strength)
	set_sparkle_amount(sparkle_amount)
	set_debug_points(false)
	set_paused(false)

	_hud.setup(self)
	await get_tree().process_frame
	_raft.update_buoyancy(1.0)


func _process(delta: float) -> void:
	if not paused:
		_ocean.tick(delta)
		_raft.update_buoyancy(delta)
	_camera.update_camera(delta)
	_update_fill_light()
	_update_reflection_camera()
	_sky_mat.set_shader_parameter("u_time", _ocean.wave_time)
	_seabed_mat.set_shader_parameter("u_time", _ocean.wave_time)


func _unhandled_input(event: InputEvent) -> void:
	if _camera != null and _camera.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_1:
			set_preset(0)
		KEY_2:
			set_preset(1)
		KEY_3:
			set_preset(2)
		KEY_UP:
			set_wave_height(wave_height + 0.1)
			_hud.sync_from_main()
		KEY_DOWN:
			set_wave_height(wave_height - 0.1)
			_hud.sync_from_main()
		KEY_LEFT:
			set_wave_direction(wave_direction - 10.0)
			_hud.sync_from_main()
		KEY_RIGHT:
			set_wave_direction(wave_direction + 10.0)
			_hud.sync_from_main()
		KEY_R:
			set_reflection_strength(0.0 if reflection_strength > 0.01 else 0.90)
			_hud.sync_from_main()
		KEY_F:
			set_foam_amount(0.25 if foam_amount > 0.5 else 1.0)
			_hud.sync_from_main()
		KEY_T:
			set_transparency(0.22 if transparency > 0.6 else transparency + 0.35)
			_hud.sync_from_main()
		KEY_G:
			set_sparkle_amount(0.0 if sparkle_amount > 0.1 else 1.10)
			_hud.sync_from_main()
		KEY_O:
			set_debug_points(not debug_points)
			_hud.sync_from_main()
		KEY_H:
			set_ui_visible(not _ui_visible)
		KEY_SPACE, KEY_P:
			set_paused(not paused)
			_hud.sync_from_main()
		KEY_C:
			_camera.reset()
		_:
			return
	get_viewport().set_input_as_handled()


# ── 世界搭建 ─────────────────────────────────────────────────────────────
func _build_environment() -> void:
	_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.075, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.28, 0.40)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.environment = env
	_world.add_child(_env)

	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.light_color = Color(1.0, 0.58, 0.26)
	_sun.light_energy = 1.3
	_sun.shadow_enabled = false
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_world.add_child(_sun)

	# 从镜头方向补一盏无阴影弱光，保证逆光时木筏/角色仍可读
	_fill = DirectionalLight3D.new()
	_fill.name = "CameraFill"
	_fill.light_color = Color(0.55, 0.48, 0.52)
	_fill.light_energy = 0.38
	_fill.shadow_enabled = false
	_world.add_child(_fill)


func _build_sky() -> void:
	_sky = MeshInstance3D.new()
	_sky.name = "SkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = 320.0
	sphere.height = 640.0
	sphere.radial_segments = 48
	sphere.rings = 24
	_sky.mesh = sphere
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/sky.gdshader")
	_sky.material_override = _sky_mat
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sky.extra_cull_margin = 20.0
	_world.add_child(_sky)


func _build_seabed() -> void:
	var seabed := MeshInstance3D.new()
	seabed.name = "Seabed"
	var plane := PlaneMesh.new()
	plane.size = Vector2(70.0, 70.0)
	plane.subdivide_width = 2
	plane.subdivide_depth = 2
	seabed.mesh = plane
	_seabed_mat = ShaderMaterial.new()
	_seabed_mat.shader = preload("res://shaders/seabed.gdshader")
	seabed.material_override = _seabed_mat
	seabed.position.y = -3.4
	seabed.layers = UNDERWATER_LAYER
	seabed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_world.add_child(seabed)

	# 几块水下石头，给“透明海水”一点深度参照
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.22, 0.28, 0.27)
	rock_mat.roughness = 1.0
	rock_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	for i in 5:
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 1.0
		rock_mesh.height = 2.0
		rock_mesh.radial_segments = 6
		rock_mesh.rings = 4
		rock.mesh = rock_mesh
		rock.material_override = rock_mat
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(15.0, 30.0)
		var rock_scale := rng.randf_range(0.20, 0.50)
		rock.position = Vector3(cos(angle) * radius, -3.5, sin(angle) * radius)
		rock.scale = Vector3(rock_scale, rock_scale * rng.randf_range(0.45, 0.7), rock_scale)
		rock.rotation.y = rng.randf_range(0.0, TAU)
		rock.layers = UNDERWATER_LAYER
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(rock)


func _build_ocean() -> void:
	_ocean = preload("res://scripts/ocean.gd").new()
	_ocean.name = "Ocean"
	_world.add_child(_ocean)
	_ocean.set_raft(Vector3.ZERO, 2.05)


func _build_raft() -> void:
	_raft = preload("res://scripts/raft.gd").new()
	_raft.name = "Raft"
	_raft.ocean = _ocean
	_world.add_child(_raft)
	_raft.position = Vector3(0.0, 0.15, 0.0)


func _build_camera() -> void:
	_camera = preload("res://scripts/orbit_camera.gd").new()
	_camera.name = "OrbitCamera"
	_camera.fov = CAMERA_FOV
	_world.add_child(_camera)
	_camera.setup(Vector3(0.0, 0.95, 0.0), 32.0, 12.0, 8.8)
	_camera.current = true


func _build_reflection() -> void:
	_reflection_vp = SubViewport.new()
	_reflection_vp.name = "ReflectionViewport"
	_reflection_vp.size = REFLECTION_SIZE
	_reflection_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_reflection_vp.transparent_bg = false
	_reflection_vp.msaa_3d = Viewport.MSAA_DISABLED
	_reflection_vp.positional_shadow_atlas_size = 0
	add_child(_reflection_vp)
	_reflection_vp.world_3d = _world_viewport.world_3d

	_reflection_cam = Camera3D.new()
	_reflection_cam.name = "ReflectionCamera"
	_reflection_cam.fov = CAMERA_FOV
	_reflection_cam.near = 0.03
	_reflection_cam.far = 700.0
	_reflection_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_reflection_cam.cull_mask = 1  # 只拍天空 / 木筏 / 角色，不拍水面和海床
	_reflection_vp.add_child(_reflection_cam)
	_reflection_cam.current = true

	_ocean.set_reflection_texture(_reflection_vp.get_texture())


func _update_reflection_camera() -> void:
	if _reflection_cam == null or _camera == null:
		return
	if not _reflection_enabled or reflection_strength <= 0.01:
		return
	var xform: Transform3D = _camera.global_transform
	var pos: Vector3 = _camera.global_position
	var forward: Vector3 = -xform.basis.z
	var up: Vector3 = xform.basis.y

	# 镜像平面 = 木筏吃水线（五点平均水位，已做平滑）。反射相机必须留在水下。
	var plane_y: float = WATER_LEVEL
	if _raft != null:
		plane_y = _raft.get_waterline_y()
	plane_y = minf(plane_y, pos.y - 0.35)
	_mirror_plane_y = plane_y

	var mirrored_pos := Vector3(pos.x, 2.0 * plane_y - pos.y, pos.z)
	var mirrored_forward := Vector3(forward.x, -forward.y, forward.z)
	var mirrored_up := Vector3(up.x, -up.y, up.z)
	_reflection_cam.global_transform = Transform3D(Basis.IDENTITY, mirrored_pos).looking_at(
			mirrored_pos + mirrored_forward, mirrored_up)
	_reflection_cam.fov = _camera.fov


func _update_fill_light() -> void:
	if _fill == null or _camera == null:
		return
	var emit_dir: Vector3 = (Vector3(0.0, 0.95, 0.0) - _camera.global_position).normalized()
	_fill.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 8.0, 0.0)).looking_at(
			Vector3(0.0, 8.0, 0.0) + emit_dir * 10.0, Vector3.UP)


# ── 时间 / 调色 ───────────────────────────────────────────────────────────
func _apply_time_of_day(hour: float) -> void:
	time_of_day = clampf(hour, 0.0, 24.0)
	_palette = _palette_at(time_of_day)

	var elev := deg_to_rad(_palette["sun_elev"])
	var azim := deg_to_rad(SUN_AZIMUTH_DEG)
	var sun_dir := Vector3(
		cos(elev) * cos(azim),
		sin(elev),
		cos(elev) * sin(azim)).normalized()

	_sun.light_color = _palette["sun"]
	_sun.light_energy = _palette["sun_energy"]
	_sun.global_transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 12.0, 0.0)).looking_at(
			Vector3(0.0, 12.0, 0.0) - sun_dir * 10.0, Vector3.UP)

	var env := _env.environment
	env.ambient_light_color = _palette["ambient"]
	env.ambient_light_energy = _palette["ambient_energy"]
	env.background_color = _palette["horizon"]

	_sky_mat.set_shader_parameter("u_zenith", _palette["zenith"])
	_sky_mat.set_shader_parameter("u_horizon", _palette["horizon"])
	_sky_mat.set_shader_parameter("u_sun_color", _palette["sun"])
	_sky_mat.set_shader_parameter("u_cloud_color", _palette["cloud"])
	_sky_mat.set_shader_parameter("u_sun_dir", sun_dir)
	_sky_mat.set_shader_parameter("u_stars", _palette["stars"])
	_sky_mat.set_shader_parameter("u_clouds", _palette["clouds"])

	_ocean.set_palette(_palette["deep"], _palette["mid"], _palette["light"],
			_palette["crest"], _palette["foam"], _palette["gold"], _palette["horizon"])
	_ocean.set_sun(sun_dir, _palette["sun"])

	var sand: Color = (_palette["mid"] as Color).lerp(_palette["light"], 0.35).darkened(0.35)
	var dark: Color = (_palette["deep"] as Color).darkened(0.35)
	_seabed_mat.set_shader_parameter("u_sand", sand)
	_seabed_mat.set_shader_parameter("u_dark", dark)

	_fill.light_color = (_palette["ambient"] as Color).lerp(_palette["sun"] as Color, 0.35)
	_fill.light_energy = 0.38

	_raft.set_night_factor(clampf(_palette["stars"], 0.0, 1.0))


func _palette_at(hour: float) -> Dictionary:
	if hour <= SKY_KEYS[0]["t"]:
		return SKY_KEYS[0].duplicate()
	for i in SKY_KEYS.size() - 1:
		var a: Dictionary = SKY_KEYS[i]
		var b: Dictionary = SKY_KEYS[i + 1]
		if hour >= a["t"] and hour <= b["t"]:
			var f: float = (hour - a["t"]) / (b["t"] - a["t"])
			var out := {}
			for key in a:
				if key == "t":
					out[key] = hour
					continue
				var va = a[key]
				var vb = b[key]
				if va is Color:
					out[key] = (va as Color).lerp(vb as Color, f)
				else:
					out[key] = lerpf(va, vb, f)
			return out
	return SKY_KEYS[SKY_KEYS.size() - 1].duplicate()


# ── 参数入口（HUD / 键盘 / 工具共用） ─────────────────────────────────────
func set_wave_height(value: float) -> void:
	wave_height = clampf(value, 0.0, 2.0)
	_ocean.set_wave_height(wave_height)


func set_wave_direction(value: float) -> void:
	wave_direction = clampf(value, -180.0, 180.0)
	_ocean.set_wave_direction(wave_direction)


func set_foam_amount(value: float) -> void:
	foam_amount = clampf(value, 0.0, 1.6)
	_ocean.set_foam(foam_amount)


func set_transparency(value: float) -> void:
	transparency = clampf(value, 0.0, 1.0)
	_ocean.set_opacity(lerpf(1.0, 0.48, transparency))


func set_reflection_strength(value: float) -> void:
	reflection_strength = clampf(value, 0.0, 1.0)
	_reflection_enabled = reflection_strength > 0.01
	_ocean.set_reflection_strength(reflection_strength)
	_ocean.set_reflection_enabled(_reflection_enabled)
	if _reflection_vp != null:
		_reflection_vp.render_target_update_mode = (
			SubViewport.UPDATE_ALWAYS if _reflection_enabled
			else SubViewport.UPDATE_DISABLED)


func set_sparkle_amount(value: float) -> void:
	sparkle_amount = clampf(value, 0.0, 1.6)
	_ocean.set_sparkle(sparkle_amount)


func set_time_of_day(hour: float) -> void:
	_apply_time_of_day(hour)


func set_preset(index: int) -> void:
	match index:
		0:
			_set_preset_values(PRESET_TIMES[0], 1.0, 0.80, 0.55, 0.70, 0.22)
		1:
			_set_preset_values(PRESET_TIMES[1], 1.15, 0.85, 0.90, 1.10, 0.22)
		2:
			_set_preset_values(PRESET_TIMES[2], 0.90, 0.65, 0.70, 0.55, 0.18)
		_:
			return


func _set_preset_values(hour: float, height: float, foam: float,
		reflection: float, sparkle: float, clear: float) -> void:
	_apply_time_of_day(hour)
	set_wave_height(height)
	set_foam_amount(foam)
	set_reflection_strength(reflection)
	set_sparkle_amount(sparkle)
	set_transparency(clear)


func set_debug_points(value: bool) -> void:
	debug_points = value
	if _raft != null:
		_raft.set_debug_points(value)


func set_paused(value: bool) -> void:
	paused = value


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	_hud.set_ui_visible(value)


func set_camera_orbit(yaw_deg: float, pitch_deg: float, distance: float) -> void:
	_camera.set_view(yaw_deg, pitch_deg, distance)


func set_auto_orbit(value: bool) -> void:
	_camera.auto_orbit = value


func set_wave_clock(value: float) -> void:
	_ocean.wave_time = value
	_ocean.water_material.set_shader_parameter("u_time", value)


# ── 工具/验收用查询 ───────────────────────────────────────────────────────
func get_params() -> Dictionary:
	return {
		"height": wave_height,
		"direction": wave_direction,
		"foam": foam_amount,
		"transparency": transparency,
		"reflection": reflection_strength,
		"sparkle": sparkle_amount,
		"time": time_of_day,
	}


func is_debug_points() -> bool:
	return debug_points


func is_paused() -> bool:
	return paused


func get_ocean() -> MeshInstance3D:
	return _ocean


func get_raft() -> Node3D:
	return _raft


func get_camera() -> Camera3D:
	return _camera


func get_reflection_viewport() -> SubViewport:
	return _reflection_vp


func get_reflection_camera() -> Camera3D:
	return _reflection_cam


func get_mirror_plane_y() -> float:
	return _mirror_plane_y


func get_world_viewport() -> SubViewport:
	return _world_viewport


func get_sun() -> DirectionalLight3D:
	return _sun


func get_sky_material() -> ShaderMaterial:
	return _sky_mat


func get_seabed_material() -> ShaderMaterial:
	return _seabed_mat


func get_world_environment() -> WorldEnvironment:
	return _env


func get_palette() -> Dictionary:
	return _palette
