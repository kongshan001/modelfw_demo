extends Node3D
## 大气控制：WorldEnvironment（指数深度雾 + 高度雾）、天空 shader、太阳/月光、
## 雾色预设、昼/夜平滑过渡、质量档。所有参数按帧写入，便于 UI 与截图工具实时调。
##
## 注意：Godot 4.6 GL Compatibility 支持深度雾/高度雾，不支持体积雾（volumetric fog）；
## 这里用环境雾 + 雾片 + 粒子 + 伪光束逼近参考观感，不做 ray-marching 体渲染。

const FOG_COLORS := [
	{"name": "晨白", "color": Color(0.86, 0.83, 0.73)},
	{"name": "冷蓝", "color": Color(0.55, 0.66, 0.80)},
	{"name": "暖金", "color": Color(0.88, 0.78, 0.58)},
	{"name": "苔绿", "color": Color(0.60, 0.72, 0.56)},
]
const FOG_DENSITIES := [0.0004, 0.0020, 0.0044, 0.0085]
const FOG_DENSITY_NAMES := ["淡", "中", "浓", "重"]
const FOG_HEIGHTS := [0.4, 1.2, 2.4, 3.6]
const FOG_HEIGHT_NAMES := ["0.4m", "1.2m", "2.4m", "3.6m"]

var env: Environment
var world_env: WorldEnvironment
var sky_material: ShaderMaterial
var sun: DirectionalLight3D

var night := false
var nightness := 0.0
var fog_level := 1
var fog_height_level := 1
var fog_color_index := 0
var high_quality := true

var _night_target := 0.0
var _day_ambient := Color(0.58, 0.585, 0.47)
var _night_ambient := Color(0.22, 0.29, 0.42)
var _day_sun := Color(1.0, 0.90, 0.72)
var _night_sun := Color(0.62, 0.74, 1.0)
var _sky_base_horizon := Color(0.82, 0.80, 0.70)
var _sky_night_horizon := Color(0.14, 0.21, 0.32)
var _fog_tint := Color(0.80, 0.84, 0.79)


func setup() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = _day_ambient
	env.ambient_light_energy = 0.62
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 0.88
	env.glow_hdr_scale = 1.4
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE

	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = FOG_COLORS[0]["color"]
	env.fog_light_energy = 1.0
	env.fog_density = FOG_DENSITIES[fog_level]
	env.fog_height = FOG_HEIGHTS[fog_height_level]
	env.fog_height_density = 0.045
	env.fog_sun_scatter = 0.22
	env.fog_sky_affect = 0.22
	env.fog_aerial_perspective = 0.0
	env.ssao_enabled = false
	env.ssil_enabled = false
	env.sdfgi_enabled = false

	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky

	world_env = WorldEnvironment.new()
	world_env.name = "Atmosphere"
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.name = "SunMoon"
	sun.light_color = _day_sun
	sun.light_energy = 1.05
	sun.rotation_degrees = Vector3(-42.0, -30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 48.0
	sun.shadow_blur = 1.4
	add_child(sun)
	_apply_all()


func set_phase(p_night: bool, instant: bool = false) -> void:
	night = p_night
	_night_target = 1.0 if night else 0.0
	if instant:
		nightness = _night_target
		_apply_all()


func toggle_phase() -> void:
	set_phase(not night)


func set_fog_level(level: int) -> void:
	fog_level = clampi(level, 0, FOG_DENSITIES.size() - 1)
	_apply_all()


func set_fog_height_level(level: int) -> void:
	fog_height_level = clampi(level, 0, FOG_HEIGHTS.size() - 1)
	_apply_all()


func cycle_fog_color() -> int:
	fog_color_index = (fog_color_index + 1) % FOG_COLORS.size()
	_apply_all()
	return fog_color_index


func set_fog_color_index(index: int) -> void:
	fog_color_index = clampi(index, 0, FOG_COLORS.size() - 1)
	_apply_all()


func set_quality(high: bool) -> void:
	high_quality = high
	sun.shadow_enabled = high
	_apply_all()


func _process(delta: float) -> void:
	if absf(nightness - _night_target) > 0.001:
		var speed := 1.0 / 1.25
		nightness = move_toward(nightness, _night_target, delta * speed)
		_apply_all()


func _apply_all() -> void:
	if env == null:
		return
	var t := nightness
	_fog_tint = FOG_COLORS[fog_color_index]["color"]
	env.fog_light_color = _fog_tint.lerp(Color(0.26, 0.36, 0.50), t * 0.58)
	env.fog_light_energy = lerpf(0.78, 0.45, t)
	env.fog_density = FOG_DENSITIES[fog_level]
	env.fog_height = FOG_HEIGHTS[fog_height_level]
	env.fog_height_density = lerpf(0.026, 0.050, t)
	env.fog_sun_scatter = lerpf(0.22, 0.12, t)
	env.fog_sky_affect = lerpf(0.22, 0.12, t)
	env.ambient_light_color = _day_ambient.lerp(_night_ambient, t)
	env.ambient_light_energy = lerpf(0.74, 0.26, t)
	env.glow_intensity = lerpf(0.55, 1.1, t)
	env.glow_hdr_threshold = lerpf(0.88, 0.70, t)
	env.tonemap_exposure = lerpf(1.02, 1.0, t)
	env.background_energy_multiplier = lerpf(1.0, 0.75, t)

	sun.light_color = _day_sun.lerp(_night_sun, t)
	sun.light_energy = lerpf(1.18, 0.30, t)
	sun.rotation_degrees = Vector3(lerpf(-42.0, -30.0, t), lerpf(-30.0, -58.0, t), 0.0)

	var sun_dir := sun.global_transform.basis.z.normalized()
	var moon_dir := Vector3(-0.52, 0.36, -0.78).normalized()
	sky_material.set_shader_parameter("zenith_color", Color(0.40, 0.53, 0.62).lerp(Color(0.035, 0.065, 0.13), t))
	var horizon := _sky_base_horizon.lerp(_sky_night_horizon, t)
	horizon = horizon.lerp(_fog_tint, 0.22)
	sky_material.set_shader_parameter("horizon_color", horizon)
	sky_material.set_shader_parameter("ground_color", Color(0.10, 0.11, 0.09).lerp(Color(0.02, 0.03, 0.05), t))
	sky_material.set_shader_parameter("sun_dir", sun_dir)
	sky_material.set_shader_parameter("sun_color", _day_sun)
	sky_material.set_shader_parameter("sun_amount", lerpf(0.42, 0.03, t))
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("moon_color", Color(0.78, 0.86, 1.0))
	sky_material.set_shader_parameter("moon_amount", lerpf(0.0, 1.0, t))
	sky_material.set_shader_parameter("moon_size", 0.99930)
	sky_material.set_shader_parameter("star_amount", lerpf(0.0, 0.8, t))
	sky_material.set_shader_parameter("haze_amount", lerpf(0.55, 0.35, t))


func fog_state() -> Dictionary:
	return {
		"night": night,
		"nightness": nightness,
		"fog_level": fog_level,
		"fog_level_name": FOG_DENSITY_NAMES[fog_level],
		"fog_density": env.fog_density,
		"fog_height_level": fog_height_level,
		"fog_height_name": FOG_HEIGHT_NAMES[fog_height_level],
		"fog_height": env.fog_height,
		"fog_height_density": env.fog_height_density,
		"fog_color_index": fog_color_index,
		"fog_color_name": FOG_COLORS[fog_color_index]["name"],
		"fog_color": _fog_tint,
		"sun_dir": sun.global_transform.basis.z.normalized(),
		"moon_dir": Vector3(-0.52, 0.36, -0.78).normalized(),
		"sun_energy": sun.light_energy,
		"quality_high": high_quality,
	}


func get_ray_anchor() -> Vector3:
	# 屏幕 god rays 的锚点：夜晚用月亮方向远景，白天用太阳方向；若都不可见，
	# 主控会回退到精灵。这里给出方向与距离，由主控投影判定。
	var dir := Vector3(-0.52, 0.36, -0.78).normalized() if nightness > 0.45 else sun.global_transform.basis.z.normalized()
	return dir


func get_fog_tint() -> Color:
	return _fog_tint
