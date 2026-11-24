extends Node3D
## 雾林微光 · Fogwood — 主控。
## 组装程序化场景、环绕相机、环境雾/天空/昼夜、雾片粒子/光束、HUD、屏幕后处理与输入。
## 供 tools/ 下的 smoke / screenshot / capture / fps 工具调用的 demo_* API 在文末。

const CameraRigScript = preload("res://scripts/camera_rig.gd")
const WorldBuilderScript = preload("res://scripts/world_builder.gd")
const FogSystemScript = preload("res://scripts/fog_system.gd")
const AtmosphereScript = preload("res://scripts/atmosphere.gd")
const HUDScript = preload("res://scripts/hud.gd")
const PostFXScript = preload("res://scripts/post_fx.gd")

const WIND_SPEEDS := [0.4, 0.8, 1.4, 2.2]
const WIND_NAMES := ["0.4×", "0.8×", "1.4×", "2.2×"]

var world: Node3D
var rig: Node3D
var fog: Node3D
var atmosphere: Node3D
var hud: CanvasLayer
var post: CanvasLayer

var quality_high := true
var wind_level := 2
var god_rays_active := true
var ray_strength_override := -1.0
var _ray_is_sky := false

var _state_timer := 0.0
var _fps_timer := 0.0
var _current_fps := 60
var _frame_ms := 16.0


func _ready() -> void:
	world = WorldBuilderScript.new()
	world.name = "FogWorld"
	add_child(world)

	atmosphere = AtmosphereScript.new()
	atmosphere.name = "AtmosphereController"
	add_child(atmosphere)
	atmosphere.setup()

	fog = FogSystemScript.new()
	fog.name = "FogSystem"
	add_child(fog)
	fog.setup(world)

	rig = CameraRigScript.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.reset()

	post = PostFXScript.new()
	post.name = "PostFXLayer"
	add_child(post)

	hud = HUDScript.new()
	hud.name = "HUD"
	add_child(hud)

	_apply_wind(wind_level)
	_apply_quality(true)
	_apply_phase_visuals(0.0)
	_refresh_hud()


func _process(delta: float) -> void:
	if atmosphere != null:
		var t: float = atmosphere.nightness
		_apply_phase_visuals(t)
		fog.apply_phase(t)
		fog.set_tint(atmosphere.get_fog_tint())
		_update_water(delta)
		_update_post_fx(t)
		if world.grass_material != null:
			world.grass_material.set_shader_parameter("wind_speed", 0.55 + WIND_SPEEDS[wind_level] * 0.8)

	_fps_timer += delta
	if _fps_timer >= 0.20:
		_fps_timer = 0.0
		_current_fps = Engine.get_frames_per_second()
		_frame_ms = 1000.0 / maxf(1.0, float(_current_fps))
		hud.set_fps(_current_fps, _frame_ms)

	_state_timer += delta
	if _state_timer >= 0.25:
		_state_timer = 0.0
		_refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key := key_event.physical_keycode
	match key:
		KEY_F:
			atmosphere.set_fog_level((atmosphere.fog_level + 1) % 4)
			fog.set_fog_level(atmosphere.fog_level)
		KEY_G:
			atmosphere.set_fog_height_level((atmosphere.fog_height_level + 1) % 4)
		KEY_C:
			atmosphere.cycle_fog_color()
			fog.set_tint(atmosphere.get_fog_tint())
		KEY_B:
			_apply_wind((wind_level + 1) % WIND_SPEEDS.size())
		KEY_N:
			atmosphere.toggle_phase()
			_apply_phase_visuals(atmosphere.nightness)
			_refresh_hud()
		KEY_1:
			_apply_quality(true)
		KEY_2:
			_apply_quality(false)
		KEY_R:
			reset_demo()
			return
		KEY_SPACE:
			rig.auto_orbit = not rig.auto_orbit
		KEY_TAB:
			hud.toggle_visible()
			return
		_:
			return
	_refresh_hud()


# ---------------------------------------------------------------- 视觉接线

func _apply_wind(level: int) -> void:
	wind_level = clampi(level, 0, WIND_SPEEDS.size() - 1)
	fog.set_wind(WIND_SPEEDS[wind_level])
	if world.grass_material != null:
		world.grass_material.set_shader_parameter("wind_speed", 0.55 + WIND_SPEEDS[wind_level] * 0.8)


func _apply_quality(high: bool) -> void:
	quality_high = high
	fog.set_quality(high)
	atmosphere.set_quality(high)
	if post != null:
		post.set_quality(high)
	if world.grass_multimesh != null:
		var total: int = world.grass_placed
		world.grass_multimesh.multimesh.visible_instance_count = total if high else int(total * 0.45)
	_refresh_hud()


func _apply_phase_visuals(t: float) -> void:
	if world == null:
		return
	if world.lantern_orb_material != null:
		world.lantern_orb_material.albedo_color = Color(1.25, 0.90, 0.52).lerp(Color(2.4, 1.75, 0.92), t)
	if world.lantern_glow_material != null:
		world.lantern_glow_material.albedo_color = Color(1.0, 0.66, 0.28, 0.30).lerp(Color(1.0, 0.72, 0.34, 0.70), t)
	if world.lantern_pool_material != null:
		world.lantern_pool_material.albedo_color = Color(1.0, 0.62, 0.24, 0.10).lerp(Color(1.0, 0.68, 0.28, 0.34), t)
	if world.wisp_material != null:
		world.wisp_material.albedo_color = Color(1.5, 2.3, 2.5).lerp(Color(2.0, 3.0, 3.2), t)
	if world.wisp_halo_material != null:
		world.wisp_halo_material.albedo_color = Color(0.62, 0.92, 1.0, 0.18).lerp(Color(0.70, 0.95, 1.0, 0.50), t)


func _update_water(delta: float) -> void:
	if world.water_material == null:
		return
	var state: Dictionary = atmosphere.fog_state()
	world.water_material.set_shader_parameter("camera_pos", rig.camera.global_position)
	world.water_material.set_shader_parameter("wisp_pos", world.wisp_node.global_position)
	world.water_material.set_shader_parameter("wisp_strength", lerpf(0.12, 0.40, atmosphere.nightness))
	world.water_material.set_shader_parameter("sun_dir", state["sun_dir"])
	world.water_material.set_shader_parameter("sun_energy", state["sun_energy"])
	world.water_material.set_shader_parameter("sun_color", atmosphere.sun.light_color)
	world.water_material.set_shader_parameter("wave_speed", 0.6 + WIND_SPEEDS[wind_level] * 0.35)
	world.water_material.set_shader_parameter("sky_color", Color(0.20, 0.30, 0.32).lerp(Color(0.05, 0.09, 0.15), atmosphere.nightness))
	world.water_material.set_shader_parameter("sky_top_color", Color(0.40, 0.53, 0.62).lerp(Color(0.035, 0.065, 0.13), atmosphere.nightness))
	world.water_material.set_shader_parameter("sky_horizon_color", Color(0.82, 0.80, 0.70).lerp(Color(0.14, 0.21, 0.32), atmosphere.nightness))


func _update_post_fx(t: float) -> void:
	if post == null or not quality_high:
		god_rays_active = false
		if post != null:
			post.set_ray_strength(0.0)
		return
	var anchor: Variant = _pick_ray_anchor()
	var strength := 0.0
	var color := Color(1.0, 0.90, 0.70)
	if anchor != null:
		var anchor_pos: Vector3 = anchor
		var screen_pos: Vector2 = rig.camera.unproject_position(anchor_pos)
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var uv := Vector2(screen_pos.x / maxf(1.0, view_size.x), screen_pos.y / maxf(1.0, view_size.y))
		if uv.x > 0.02 and uv.x < 0.98 and uv.y > 0.02 and uv.y < 0.98:
			god_rays_active = true
			post.set_light_uv(uv)
			if _ray_is_sky:
				strength = lerpf(0.28, 0.75, t)
			else:
				strength = lerpf(0.14, 0.38, t)
			color = Color(1.0, 0.90, 0.70).lerp(Color(0.62, 0.78, 1.0), t)
		else:
			god_rays_active = false
	else:
		god_rays_active = false
	if ray_strength_override >= 0.0:
		strength = ray_strength_override
	post.set_ray_strength(strength)
	post.set_ray_color(color)


func _pick_ray_anchor() -> Variant:
	# 天空光源（月亮/太阳）在画面内时优先，god rays 会从月盘/光柱方向拉出；
	# 否则回退到精灵与灯笼，保持低调的径向光晕。
	_ray_is_sky = false
	var dir: Vector3 = atmosphere.get_ray_anchor()
	var far_pos: Vector3 = rig.camera.global_position + dir * 90.0
	if rig.camera.is_position_in_frustum(far_pos):
		var sky_screen: Vector2 = rig.camera.unproject_position(far_pos)
		var sky_size: Vector2 = get_viewport().get_visible_rect().size
		var sky_uv := Vector2(sky_screen.x / maxf(1.0, sky_size.x), sky_screen.y / maxf(1.0, sky_size.y))
		if sky_uv.x > 0.08 and sky_uv.x < 0.92 and sky_uv.y > 0.04 and sky_uv.y < 0.85:
			_ray_is_sky = true
			return far_pos
	var candidates: Array[Vector3] = [world.wisp_node.global_position]
	for pos in world.lantern_orb_positions:
		candidates.append(pos)
	for pos in candidates:
		if not rig.camera.is_position_in_frustum(pos):
			continue
		var screen_pos: Vector2 = rig.camera.unproject_position(pos)
		var view_size: Vector2 = get_viewport().get_visible_rect().size
		var uv := Vector2(screen_pos.x / maxf(1.0, view_size.x), screen_pos.y / maxf(1.0, view_size.y))
		if uv.x > 0.06 and uv.x < 0.94 and uv.y > 0.06 and uv.y < 0.94:
			return pos
	return null


# ---------------------------------------------------------------- HUD

func _refresh_hud() -> void:
	if hud == null or atmosphere == null:
		return
	var state: Dictionary = atmosphere.fog_state()
	var counts: Dictionary = fog.get_counts()
	hud.update_state({
		"night": atmosphere.night,
		"high_quality": quality_high,
		"fog_level_name": state["fog_level_name"],
		"fog_height_name": state["fog_height_name"],
		"fog_color_name": state["fog_color_name"],
		"wind_name": WIND_NAMES[wind_level],
		"puffs": counts["puffs"],
		"particles": counts["particles"],
		"beams": counts["beams"],
		"god_rays": god_rays_active,
	})


func reset_demo() -> void:
	atmosphere.set_phase(false, true)
	atmosphere.set_fog_level(1)
	atmosphere.set_fog_height_level(1)
	atmosphere.set_fog_color_index(0)
	_apply_wind(2)
	_apply_quality(true)
	fog.set_fog_level(1)
	fog.set_tint(atmosphere.get_fog_tint())
	rig.reset()
	_apply_phase_visuals(0.0)
	_refresh_hud()


# ---------------------------------------------------------------- Demo / 工具 API

func demo_set_view(yaw: float, pitch: float, distance: float, focus: Vector3 = Vector3(0, 1.4, 0), auto: bool = false) -> void:
	rig.set_view(yaw, pitch, distance, focus, auto)


func demo_set_auto_orbit(value: bool) -> void:
	rig.auto_orbit = value


func demo_set_quality(high: bool) -> void:
	_apply_quality(high)


func demo_set_phase(night: bool, instant: bool = true) -> void:
	atmosphere.set_phase(night, instant)
	_apply_phase_visuals(atmosphere.nightness)
	fog.apply_phase(atmosphere.nightness)
	fog.set_tint(atmosphere.get_fog_tint())
	_refresh_hud()


func demo_set_fog(level: int, height_level: int) -> void:
	atmosphere.set_fog_level(level)
	atmosphere.set_fog_height_level(height_level)
	fog.set_fog_level(level)
	_refresh_hud()


func demo_set_fog_color(index: int) -> void:
	atmosphere.set_fog_color_index(index)
	fog.set_tint(atmosphere.get_fog_tint())
	_refresh_hud()


func demo_cycle_fog_color() -> void:
	atmosphere.cycle_fog_color()
	fog.set_tint(atmosphere.get_fog_tint())
	_refresh_hud()


func demo_set_wind_level(level: int) -> void:
	_apply_wind(level)
	_refresh_hud()


func demo_set_wind_speed(speed: float) -> void:
	fog.set_wind(speed)
	_refresh_hud()


func demo_set_hud_visible(value: bool) -> void:
	hud.set_hud_visible(value)


func demo_set_fps_visible(value: bool) -> void:
	hud.set_fps_visible(value)


func demo_set_ray_override(value: float) -> void:
	ray_strength_override = value


func demo_get_counts() -> Dictionary:
	return fog.get_counts()


func demo_get_fog_state() -> Dictionary:
	return atmosphere.fog_state()


func demo_get_wind() -> float:
	return WIND_SPEEDS[wind_level]


func demo_get_camera() -> Camera3D:
	return rig.camera


func demo_reset() -> void:
	reset_demo()
