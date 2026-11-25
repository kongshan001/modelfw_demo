extends Node3D
## 天幕、月光/日光、雾、辉光与低空云。昼夜与晴雨在这里统一插值；
## 花瓣、萤火、草风等由 world 读取当前 nightness/rain_amount 后自行更新。

const Geo = preload("res://scripts/geo.gd")
const SKY_SHADER = preload("res://shaders/sky.gdshader")

const MOON_DIR := Vector3(-0.34, 0.68, -0.66)

var world_environment: WorldEnvironment
var env: Environment
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D
var sky_mesh: MeshInstance3D
var sky_material: ShaderMaterial
var cloud_nodes: Array[MeshInstance3D] = []
var cloud_material: StandardMaterial3D

var nightness := 1.0
var target_nightness := 1.0
var rain_amount := 0.0
var target_rain := 0.0
var night_target := true
var rain_target := false
var quality_high := true
var anim_time := 0.0
var moon_dir := MOON_DIR

var _cloud_base: Array[Vector3] = []
var _cloud_phase: Array[float] = []


func setup() -> void:
	_build_environment()
	_build_lights()
	_build_sky()
	_build_clouds()
	apply_state(1.0, 0.0, true)


func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.035, 0.035, 0.075)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.38, 0.50)
	env.ambient_light_energy = 1.10
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.08
	env.tonemap_white = 1.55
	env.glow_enabled = true
	env.glow_intensity = 0.42
	env.glow_strength = 0.92
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 1.02
	env.glow_hdr_scale = 2.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.07, 0.08, 0.15)
	env.fog_light_energy = 0.38
	env.fog_density = 0.0030
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.2

	world_environment = WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.environment = env
	add_child(world_environment)


func _build_lights() -> void:
	key_light = DirectionalLight3D.new()
	key_light.name = "MoonKey"
	key_light.light_color = Color(0.58, 0.70, 0.98)
	key_light.light_energy = 0.86
	key_light.light_specular = 0.65
	key_light.rotation_degrees = Vector3(-50, -34, 0)
	key_light.shadow_enabled = true
	key_light.shadow_bias = 0.035
	key_light.shadow_normal_bias = 1.6
	key_light.shadow_opacity = 0.64
	key_light.shadow_blur = 1.35
	key_light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	key_light.directional_shadow_max_distance = 42.0
	add_child(key_light)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "SkyFill"
	fill_light.light_color = Color(0.40, 0.52, 0.70)
	fill_light.light_energy = 0.20
	fill_light.light_specular = 0.0
	fill_light.shadow_enabled = false
	fill_light.rotation_degrees = Vector3(-28, 142, 0)
	add_child(fill_light)


func _build_sky() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 118.0
	sphere.height = 236.0
	sphere.radial_segments = 48
	sphere.rings = 24

	sky_material = ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	sky_material.set_shader_parameter("nightness", 1.0)
	sky_material.set_shader_parameter("rain_amount", 0.0)
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("u_time", 0.0)

	sky_mesh = MeshInstance3D.new()
	sky_mesh.name = "NightSky"
	sky_mesh.mesh = sphere
	sky_mesh.material_override = sky_material
	sky_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sky_mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	sky_mesh.extra_cull_margin = 40000.0
	add_child(sky_mesh)


func _build_clouds() -> void:
	var tex := Geo.make_cloud_texture(128)
	cloud_material = StandardMaterial3D.new()
	cloud_material.albedo_texture = tex
	cloud_material.albedo_color = Color(0.24, 0.22, 0.38, 0.48)
	cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	cloud_material.billboard_keep_scale = true
	cloud_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloud_material.disable_receive_shadows = true
	cloud_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	cloud_material.no_depth_test = false

	var placements := [
		Vector3(-11.0, -4.4, 6.0), Vector3(8.0, -5.1, 8.5),
		Vector3(-6.0, -5.7, -9.0), Vector3(12.0, -6.0, -3.0),
		Vector3(0.0, -7.1, 1.0), Vector3(-15.0, -6.2, -2.0),
		Vector3(4.0, -4.0, -12.0),
	]
	var sizes := [Vector2(13.0, 6.4), Vector2(10.5, 5.2), Vector2(14.0, 6.8), Vector2(11.0, 4.8),
		Vector2(17.0, 7.5), Vector2(12.0, 5.6), Vector2(10.0, 4.6)]
	for i in range(placements.size()):
		var quad := QuadMesh.new()
		quad.size = sizes[i]
		var mi := MeshInstance3D.new()
		mi.name = "LowCloud%d" % i
		mi.mesh = quad
		mi.material_override = cloud_material
		mi.position = placements[i]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(mi)
		cloud_nodes.append(mi)
		_cloud_base.append(placements[i])
		_cloud_phase.append(float(i) * 1.37 + 0.4)


func set_night(value: bool, immediate := false) -> void:
	night_target = value
	target_nightness = 1.0 if value else 0.0
	if immediate:
		nightness = target_nightness
		apply_state(nightness, rain_amount, quality_high)


func set_weather(value: bool, immediate := false) -> void:
	rain_target = value
	target_rain = 1.0 if value else 0.0
	if immediate:
		rain_amount = target_rain
		apply_state(nightness, rain_amount, quality_high)


func advance(delta: float) -> void:
	anim_time += delta
	var blend := 1.0 - exp(-delta * 2.1)
	nightness = lerpf(nightness, target_nightness, blend)
	rain_amount = lerpf(rain_amount, target_rain, blend)
	if absf(nightness - target_nightness) < 0.001:
		nightness = target_nightness
	if absf(rain_amount - target_rain) < 0.001:
		rain_amount = target_rain
	apply_state(nightness, rain_amount, quality_high)
	_animate_clouds()


func apply_state(t: float, rain: float, high: bool) -> void:
	quality_high = high
	if env == null:
		return
	t = clampf(t, 0.0, 1.0)
	rain = clampf(rain, 0.0, 1.0)
	var dayness := 1.0 - t

	# t 是“夜度”；所有昼夜配色用 dayness 过渡，避免色温/能量反向。
	var night_ambient := Color(0.29, 0.37, 0.49)
	var day_ambient := Color(0.66, 0.71, 0.64)
	var ambient := night_ambient.lerp(day_ambient, dayness)
	ambient = ambient.lerp(Color(0.48, 0.52, 0.58), rain * 0.38)
	env.ambient_light_color = ambient
	env.ambient_light_energy = lerpf(1.12, 0.96, dayness) * (1.0 - rain * 0.14)
	env.tonemap_exposure = lerpf(1.08, 0.97, dayness)

	var moon_color := Color(0.62, 0.75, 1.0)
	var sun_color := Color(1.0, 0.84, 0.63)
	var key_color := moon_color.lerp(sun_color, dayness)
	key_color = key_color.lerp(Color(0.68, 0.76, 0.86), rain * 0.46)
	key_light.light_color = key_color
	key_light.light_energy = lerpf(1.28, 1.16, dayness) * (1.0 - rain * 0.26)
	key_light.rotation_degrees = Vector3(lerpf(-51.0, -39.0, dayness), lerpf(-35.0, -24.0, dayness), 0.0)
	key_light.shadow_opacity = lerpf(0.52, 0.48, dayness) * (1.0 - rain * 0.18)
	key_light.shadow_enabled = high

	fill_light.light_color = Color(0.33, 0.50, 0.58).lerp(Color(0.65, 0.70, 0.68), dayness)
	fill_light.light_energy = lerpf(0.33, 0.14, dayness) * (1.0 - rain * 0.18)

	var fog_night := Color(0.060, 0.078, 0.135)
	var fog_day := Color(0.74, 0.78, 0.70)
	var fog_col := fog_night.lerp(fog_day, dayness).lerp(Color(0.46, 0.49, 0.54), rain * 0.44)
	env.fog_light_color = fog_col
	env.fog_density = lerpf(0.0018, 0.0030, dayness) + rain * 0.0024
	env.fog_light_energy = lerpf(0.34, 0.58, dayness) * (1.0 - rain * 0.18)

	env.glow_intensity = lerpf(0.44, 0.10, dayness) * (1.0 - rain * 0.24)
	env.glow_enabled = high or t > 0.5

	sky_material.set_shader_parameter("nightness", t)
	sky_material.set_shader_parameter("rain_amount", rain)
	sky_material.set_shader_parameter("moon_dir", moon_dir)
	sky_material.set_shader_parameter("u_time", anim_time)

	var cloud_night := Color(0.21, 0.20, 0.36, 0.56)
	var cloud_day := Color(0.76, 0.80, 0.76, 0.34)
	var cloud_col := cloud_night.lerp(cloud_day, dayness).lerp(Color(0.44, 0.46, 0.52, 0.60), rain * 0.45)
	cloud_material.albedo_color = cloud_col


func _animate_clouds() -> void:
	for i in range(cloud_nodes.size()):
		var node := cloud_nodes[i]
		var p := _cloud_base[i]
		var phase := _cloud_phase[i]
		node.position = p + Vector3(
			sin(anim_time * 0.024 + phase) * 2.1,
			sin(anim_time * 0.045 + phase * 1.8) * 0.20,
			cos(anim_time * 0.018 + phase) * 1.3)
		node.rotation.z = sin(anim_time * 0.02 + phase) * 0.035


func set_quality(high: bool) -> void:
	quality_high = high
	if not high:
		for i in range(cloud_nodes.size()):
			cloud_nodes[i].visible = i < 4
	else:
		for node in cloud_nodes:
			node.visible = true
	apply_state(nightness, rain_amount, high)


func set_anim_time(value: float) -> void:
	anim_time = value
	if sky_material != null:
		sky_material.set_shader_parameter("u_time", anim_time)


func reset() -> void:
	set_night(true, true)
	set_weather(false, true)
	set_quality(true)


func get_state() -> Dictionary:
	return {
		"night": night_target,
		"nightness": nightness,
		"rain": rain_target,
		"rain_amount": rain_amount,
		"quality_high": quality_high,
	}
