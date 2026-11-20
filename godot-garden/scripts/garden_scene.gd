extends Node3D

# 废墟花园主控：640×360 内部渲染 → NEAREST 放大，UI 保持 1920×1080 清晰。
# 时间从黄昏走向深夜再走向清晨；路灯、萤火、光束、水面、云影随时间和开关变化。

const RENDER_SIZE := Vector2i(960, 540) # 非像素风：内部 960×540 + 线性放大
const START_HOURS := 17.8
const SPEED_HOURS_PER_SEC := 600.0 / 3600.0 # ×600：一天 2.4 分钟
const CAMERA_TARGET := Vector3(-1.5, 0.8, 4.5)
const CAMERA_DISTANCE := 27.5
const CAMERA_PITCH_DEG := 48.0
const CAMERA_AZIMUTH_DEG := 45.0
# 巡逻近景机位：按角色手工选方位，避开树木/废墟遮挡
const PATROL_CAMERAS := {
	"lantern": {"azimuth": 140.0, "pitch": 16.0, "distance": 5.8, "anchor": Vector3(-5, 0, 3)},
	"sweeper": {"azimuth": 155.0, "pitch": 22.0, "distance": 6.8},
	"fox": {"azimuth": 100.0, "pitch": 16.0, "distance": 5.8},
}

var hours := START_HOURS
var autoplay := true
var features := {
	"fireflies": true,
	"lamps": true,
	"beams": true,
	"clouds": true,
	"patrols": true,
}

var _viewport: SubViewport
var _display: TextureRect
var _post_mat: ShaderMaterial
var _world: GardenWorld
var _ui: GardenUI
var _game_ui: GardenGameUI
var _camera: Camera3D
var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _fill: DirectionalLight3D
var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _elapsed := 0.0
var exposure_override := -1.0
var _zoom := 1.0
var _octopus_focus := false
var _patrol_focus := -1
var _film_camera := false
var _film_position := Vector3.ZERO
var _film_target := Vector3.ZERO

func _ready() -> void:
	_build_viewport()
	_build_environment()
	_build_lights()
	_build_camera()
	_build_world()
	_build_screen()
	_apply_time(0.0)
	set_process(true)
	set_process_unhandled_input(true)

func _process(delta: float) -> void:
	_elapsed += delta
	if autoplay:
		hours = fposmod(hours + delta * SPEED_HOURS_PER_SEC, 24.0)
	_apply_time(delta)
	_update_camera()
	if _ui != null:
		_ui.sync(hours, autoplay)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_autoplay(not autoplay)
				get_viewport().set_input_as_handled()
			KEY_F1:
				set_ui_visible(not _ui.visible)
				get_viewport().set_input_as_handled()
			KEY_R:
				set_time(START_HOURS)
				get_viewport().set_input_as_handled()
			KEY_1:
				toggle_feature("fireflies")
			KEY_2:
				toggle_feature("lamps")
			KEY_3:
				toggle_feature("beams")
			KEY_4:
				toggle_feature("clouds")
			KEY_5:
				toggle_feature("patrols")
			KEY_ESCAPE:
				get_tree().quit()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - 0.04, 0.65, 1.7)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + 0.04, 0.65, 1.7)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_command_at_screen(event.position)
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- 公共接口

func set_time(h: float) -> void:
	hours = fposmod(h, 24.0)
	_apply_time(0.0)
	if _ui != null:
		_ui.sync(hours, autoplay)

func set_autoplay(value: bool) -> void:
	autoplay = value
	if _ui != null:
		_ui.sync(hours, autoplay)

func toggle_feature(key: String) -> void:
	if not features.has(key):
		return
	features[key] = not features[key]
	if key == "patrols" and _world != null:
		_world.set_patrol_visible(features[key])
	if _ui != null:
		_ui.sync(hours, autoplay)

func set_ui_visible(value: bool) -> void:
	if _ui != null:
		_ui.visible = value
	if _game_ui != null:
		_game_ui.visible = value

func _command_at_screen(screen_position: Vector2) -> void:
	if _world == null or _world.hero == null or _camera == null or _display == null:
		return
	var display_size := _display.size
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return
	var mouse := screen_position * Vector2(RENDER_SIZE) / display_size
	var origin := _camera.project_ray_origin(mouse)
	var direction := _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.001:
		return
	var distance := -origin.y / direction.y
	if distance <= 0.0:
		return
	var point := origin + direction * distance
	var monster = _world.nearest_monster(point, 1.4)
	if monster != null:
		_world.hero.command_attack(monster)
	else:
		_world.hero.command_move(point)

func focus_octopus(enabled := true) -> void:
	_octopus_focus = enabled
	if enabled:
		_patrol_focus = -1

func focus_patrol(index := 0) -> void:
	_patrol_focus = index
	_octopus_focus = false
	_film_camera = false

func set_film_camera(position: Vector3, target: Vector3) -> void:
	_film_camera = true
	_patrol_focus = -1
	_octopus_focus = false
	_film_position = position
	_film_target = target

func clear_film_camera() -> void:
	_film_camera = false

# ---------------------------------------------------------------- 构建

func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "WorldViewport"
	_viewport.size = RENDER_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_viewport.use_taa = false
	_viewport.transparent_bg = false
	add_child(_viewport)

func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.2, 0.24, 0.2)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.56, 0.48)
	_env.ambient_light_energy = 0.55
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 1.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.03
	_env.glow_hdr_threshold = 1.15
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.24, 0.3, 0.27)
	_env.fog_light_energy = 0.5
	_env.fog_density = 0.007
	_env.fog_sky_affect = 0.4
	_env.adjustment_enabled = true
	_env.adjustment_brightness = 1.0
	_env.adjustment_contrast = 1.04
	_env.adjustment_saturation = 1.05
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.sky_top_color = Color(0.18, 0.28, 0.42)
	_sky_mat.sky_horizon_color = Color(0.55, 0.58, 0.55)
	_sky_mat.ground_bottom_color = Color(0.06, 0.07, 0.06)
	_sky_mat.ground_horizon_color = Color(0.3, 0.3, 0.25)
	_sky_mat.sun_angle_max = 8.0
	_sky_mat.sun_curve = 0.12
	_sky_mat.sky_energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.background_energy_multiplier = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	_viewport.add_child(world_env)

func _build_lights() -> void:
	_sun = DirectionalLight3D.new()
	_sun.name = "Sun"
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 55.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.shadow_bias = 0.02
	_sun.shadow_normal_bias = 0.4
	_sun.light_angular_distance = 1.1
	_viewport.add_child(_sun)
	_moon = DirectionalLight3D.new()
	_moon.name = "Moon"
	_moon.shadow_enabled = false
	_moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_moon.directional_shadow_max_distance = 48.0
	_moon.shadow_bias = 0.03
	_moon.shadow_normal_bias = 0.5
	_moon.light_color = Color(0.55, 0.7, 1.0)
	_moon.light_energy = 0.0
	_viewport.add_child(_moon)
	_fill = DirectionalLight3D.new()
	_fill.name = "SkyFill"
	_fill.shadow_enabled = false
	_fill.light_color = Color(0.42, 0.58, 0.85)
	_fill.light_energy = 0.0
	_fill.rotation_degrees = Vector3(-35, 300, 0)
	_viewport.add_child(_fill)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.fov = 32.0
	_camera.near = 0.5
	_camera.far = 120.0
	_camera.current = true
	_viewport.add_child(_camera)
	_camera.global_position = _camera_position(0.0)
	_camera.look_at(CAMERA_TARGET)

func _build_world() -> void:
	_world = GardenWorld.new()
	_world.name = "World"
	_viewport.add_child(_world)
	_world.build(_camera)

func _build_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Screen"
	add_child(layer)
	_display = TextureRect.new()
	_display.name = "PixelDisplay"
	_display.texture = _viewport.get_texture()
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_SCALE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_display)
	_post_mat = ShaderMaterial.new()
	_post_mat.shader = load("res://shaders/post_process.gdshader")
	_post_mat.set_shader_parameter("u_texel", Vector2(1.0 / RENDER_SIZE.x, 1.0 / RENDER_SIZE.y))
	_display.material = _post_mat
	_ui = GardenUI.new()
	_ui.name = "UI"
	layer.add_child(_ui)
	_ui.setup(self)
	_game_ui = GardenGameUI.new()
	_game_ui.name = "GameUI"
	layer.add_child(_game_ui)
	_game_ui.setup(_world.hero, _world.quest)

# ---------------------------------------------------------------- 时间与光照

func _apply_time(_delta: float) -> void:
	var h := hours
	var sun_alt := sin((h - 4.9) / 14.2 * PI)
	var day := clampf(sun_alt, 0.0, 1.0)
	var night := clampf(-sun_alt, 0.0, 1.0)
	var low_sun := clampf(1.0 - absf(sun_alt) / 0.55, 0.0, 1.0) * (1.0 - night)
	var dusk_glow := smoothstep(0.05, 0.18, day) * (1.0 - smoothstep(0.45, 0.8, day))
	var twilight := smoothstep(18.6, 19.2, h) * (1.0 - smoothstep(20.4, 21.6, h))

	# 太阳/月亮
	var sun_energy := pow(day, 0.5) * (2.2 + dusk_glow * 1.4)
	_sun.light_energy = sun_energy
	_sun.light_color = Color(1.0, 0.55, 0.28).lerp(Color(1.0, 0.98, 0.9), clampf(sun_alt / 0.9, 0.0, 1.0))
	_sun.rotation_degrees = Vector3(-(8.0 + day * 62.0), 105.0 + (h - 12.0) * 0.8, 0.0)
	_moon.light_energy = pow(night, 0.8) * 0.48
	_moon.rotation_degrees = Vector3(-(10.0 + night * 15.0), 300.0 + (h - 12.0) * 6.0, 0.0)
	_fill.light_energy = 0.08 + dusk_glow * 0.45 + night * 0.15 + twilight * 0.15
	_fill.rotation_degrees = Vector3(-35.0, 300.0 + (h - 12.0) * 4.0, 0.0)

	# 环境色：暖直射 + 冷天光/冷补光，阴影偏蓝绿
	var ambient := Color(0.08, 0.13, 0.22).lerp(Color(0.55, 0.62, 0.62), day)
	ambient = ambient.lerp(Color(0.36, 0.36, 0.38), low_sun * 0.5)
	ambient = ambient.lerp(Color(0.2, 0.28, 0.42), twilight * 0.45)
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = 0.32 + day * 0.3 + dusk_glow * 0.8 + twilight * 0.35
	var bg := Color(0.015, 0.035, 0.05).lerp(Color(0.34, 0.42, 0.4), day)
	bg = bg.lerp(Color(0.32, 0.25, 0.22), low_sun * 0.62)
	bg = bg.lerp(Color(0.12, 0.16, 0.24), twilight * 0.5)
	_env.background_color = bg
	if _sky_mat != null:
		var top := Color(0.012, 0.02, 0.05).lerp(Color(0.16, 0.3, 0.48), day)
		top = top.lerp(Color(0.3, 0.22, 0.25), low_sun * 0.55)
		top = top.lerp(Color(0.06, 0.09, 0.18), twilight * 0.5)
		var horizon := bg.lerp(Color(0.95, 0.58, 0.34), low_sun * 0.55)
		_sky_mat.sky_top_color = top
		_sky_mat.sky_horizon_color = horizon
		_sky_mat.ground_horizon_color = horizon.darkened(0.25)
		_sky_mat.ground_bottom_color = bg.darkened(0.45)
	_env.fog_light_color = bg.lerp(Color(0.45, 0.55, 0.58), 0.5)
	_env.fog_density = 0.006 + night * 0.012 + dusk_glow * 0.008
	_env.fog_light_energy = 0.45 + dusk_glow * 0.3 + twilight * 0.2
	_env.adjustment_saturation = 1.0 + low_sun * 0.08

	var lamp_level := _lamp_level(h) if features.lamps else 0.0
	var firefly_level := _firefly_level(h) if features.fireflies else 0.0
	var beam_level := _beam_level(h) if features.beams else 0.0
	var cloud_level := (0.018 + day * 0.045) if features.clouds else 0.0
	if exposure_override >= 0.0:
		_env.tonemap_exposure = exposure_override
	else:
		_env.tonemap_exposure = 1.0 + dusk_glow * 0.45
	_env.glow_intensity = 0.35 + lamp_level * 0.45 + night * 0.2

	_world.set_lamp_level(lamp_level, _elapsed)
	_world.set_firefly_level(firefly_level)
	_world.set_water_state(night, lamp_level, -_sun.global_transform.basis.z, low_sun)
	_world.set_cloud_level(cloud_level)
	_world.set_mist_level(night)
	_world.set_octopus_time(night)
	_world.set_patrol_night(night, low_sun)
	_world.set_beam_level(beam_level, -_sun.global_transform.basis.z, _camera.global_position, night)

	_post_mat.set_shader_parameter("u_night", night)
	_post_mat.set_shader_parameter("u_warm", low_sun)
	_post_mat.set_shader_parameter("u_vignette", 0.2 + night * 0.1)
	_post_mat.set_shader_parameter("u_bloom", 0.06 + lamp_level * 0.1 + night * 0.04)

func _lamp_level(h: float) -> float:
	if h >= 17.4 and h < 20.6:
		return smoothstep(17.4, 19.4, h)
	if h >= 20.6 or h < 5.2:
		return 1.0
	if h >= 5.2 and h < 6.8:
		return 1.0 - smoothstep(5.2, 6.8, h)
	return 0.0

func _firefly_level(h: float) -> float:
	if h >= 19.2 and h < 24.0:
		return smoothstep(19.2, 21.0, h)
	if h >= 0.0 and h < 5.2:
		return 1.0
	if h >= 5.2 and h < 6.8:
		return 1.0 - smoothstep(5.2, 6.8, h)
	return 0.0

func _beam_level(h: float) -> float:
	var dusk := smoothstep(16.2, 17.4, h) * (1.0 - smoothstep(19.0, 19.8, h))
	var dawn := smoothstep(5.0, 6.2, h) * (1.0 - smoothstep(7.0, 8.8, h))
	return maxf(dusk, dawn)

func _camera_position(orbit: float) -> Vector3:
	var distance := CAMERA_DISTANCE * _zoom
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	var azimuth := deg_to_rad(CAMERA_AZIMUTH_DEG) + orbit
	var horizontal := cos(pitch) * distance
	var height := sin(pitch) * distance
	var pos := CAMERA_TARGET + Vector3(cos(azimuth) * horizontal, height, sin(azimuth) * horizontal)
	return pos

func _update_camera() -> void:
	if _film_camera:
		_camera.global_position = _film_position
		_camera.look_at(_film_target)
		return
	if _patrol_focus >= 0 and _world != null and _patrol_focus < _world.patrols.size():
		var npc: Node3D = _world.patrols[_patrol_focus]
		var shot: Dictionary = PATROL_CAMERAS.get(String(npc.role), {"azimuth": 38.0, "pitch": 22.0, "distance": 7.5})
		# 提灯人是 1.618m 的 Q 版大头身，取景重心抬高到 1.0m
		var focus_height := 1.0 if String(npc.role) == GardenPatrol.ROLE_LANTERN else 0.85
		var focus_target: Vector3 = npc.global_position + Vector3(0, focus_height, 0)
		var focus_orbit := sin(_elapsed * 0.12) * 0.05
		var focus_distance: float = shot["distance"]
		var focus_pitch := deg_to_rad(float(shot["pitch"]))
		var focus_azimuth := deg_to_rad(float(shot["azimuth"])) + focus_orbit
		if shot.has("anchor"):
			# 锚点机位：相机始终朝锚点方向取景（提灯人绕水池，机位停在水面中央，避开树冠）
			var anchor: Vector3 = shot["anchor"]
			focus_azimuth = atan2(anchor.z - npc.global_position.z, anchor.x - npc.global_position.x) + focus_orbit
		var focus_horizontal := cos(focus_pitch) * focus_distance
		var focus_pos := focus_target + Vector3(cos(focus_azimuth) * focus_horizontal, sin(focus_pitch) * focus_distance, sin(focus_azimuth) * focus_horizontal)
		focus_pos = focus_pos
		_camera.global_position = focus_pos
		_camera.look_at(focus_target)
		return
	if _octopus_focus:
		var focus_target := Vector3(-0.1, 0.9, 2.0)
		var focus_orbit := sin(_elapsed * 0.18) * 0.04
		var focus_distance := 10.0
		var focus_pitch := deg_to_rad(32.0)
		var focus_azimuth := deg_to_rad(40.0) + focus_orbit
		var focus_horizontal := cos(focus_pitch) * focus_distance
		var focus_pos := focus_target + Vector3(cos(focus_azimuth) * focus_horizontal, sin(focus_pitch) * focus_distance, sin(focus_azimuth) * focus_horizontal)
		focus_pos = focus_pos
		_camera.global_position = focus_pos
		_camera.look_at(focus_target)
		return
	var orbit := sin(_elapsed * 0.025) * 0.025
	var cam_pos := _camera_position(orbit)
	_camera.global_position = cam_pos
	_camera.look_at(CAMERA_TARGET)
