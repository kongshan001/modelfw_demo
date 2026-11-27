extends Node

# 暮色回廊 · 主控
# 管线：root Window (1280×720/1920×1080)
#   └ SubViewport 640×360（3D，最近邻）→ SubViewport 640×360（像素后期）
#     → TextureRect 最近邻整数倍放大 → 全分辨率中文 HUD。
# 时间：18:30 黄昏 → 22:30 深夜；路灯按阈值错峰点亮，萤火虫渐显；水面/云影/光柱联动。

const WorldScript := preload("res://scripts/garden_world.gd")
const HudScript := preload("res://scripts/hud.gd")
const PostShader := preload("res://shaders/post_pixel.gdshader")

const INTERNAL_OPTIONS: Array[Vector2i] = [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)]
const INTERNAL_LABELS: Array[String] = ["320×180", "480×270", "640×360"]
const PRESET_TIMES: Array[float] = [0.20, 0.52, 0.92]
const PRESET_LABELS: Array[String] = ["黄昏", "暮蓝", "深夜"]
const MOVIE_LENGTH := 10.4
const BASE_TIME_SPEED := 0.018

var world_viewport: SubViewport
var post_viewport: SubViewport
var post_rect: TextureRect
var post_mat: ShaderMaterial
var display_root: Control
var backdrop: ColorRect
var screen: TextureRect
var world
var camera: Camera3D
var hud

var internal_index := 2
var internal_size := Vector2i(640, 360)
var display_scale := 2
var screen_rect := Rect2()

var time_of_day := 0.10
var auto_time := true
var time_speed := 1.0
var lamps_enabled := true
var fireflies_enabled := true
var paused := false
var ui_visible := true
var wind := 1.0
var anim_time := 0.0
var cloud_offset := Vector2.ZERO
var night_amount := 0.0

var cam_yaw := -9.0
var cam_pitch := 22.0
var cam_dist := 9.0
var cam_fov := 50.0
var pixel_snap := true
var hud_scale_override := 0
var camera_override := false
var camera_override_target := Vector3.ZERO
var _cam_pos := Vector3.ZERO
var _cam_target := Vector3.ZERO
var _cam_initialized := false

var _lamp_levels: Array[float] = []
var _current_state: Dictionary = {}
var _fps_value := 0
var _draw_calls := 0
var _stats_tick := 0.0
var _marker: MeshInstance3D
var _marker_time := 0.0
var _marker_active := false

var _dragging := false
var _test_move := Vector3.ZERO
var _test_running := false
var movie_mode := false
var _movie_time := 0.0
var _movie_index := 0
var _movie_waypoints := [
	Vector3(1.4, 0, 4.0), Vector3(0.7, 0, 0.6), Vector3(0.3, 0, -3.2), Vector3(0.25, 0, -7.0)
]

var _time_keys := [
	{"t": 0.0, "sun_elev": 13.0, "sun_azim": -125.0, "sun_color": Color(1.0, 0.70, 0.44), "sun_energy": 1.35,
		"moon_energy": 0.0, "moon_elev": 20.0, "moon_azim": 45.0,
		"ambient": Color(0.54, 0.47, 0.48), "ambient_e": 0.68,
		"sky_top": Color(0.24, 0.31, 0.48), "sky_mid": Color(0.56, 0.43, 0.47), "sky_horizon": Color(0.98, 0.63, 0.38),
		"sun_glow": Color(1.0, 0.62, 0.30), "sun_sky": 1.0, "moon_sky": 0.0, "star": 0.0,
		"cloud_highlight": Color(0.98, 0.74, 0.54), "cloud_density": 0.82,
		"fog": Color(0.42, 0.36, 0.38), "fog_density": 0.012,
		"water_deep": Color(0.045, 0.11, 0.13), "water_shallow": Color(0.18, 0.31, 0.26),
		"shaft": Color(1.0, 0.72, 0.44), "shaft_i": 0.30,
		"exposure": 1.06, "tint": Color(0.30, 0.40, 0.62), "tint_strength": 0.0, "night": 0.0},
	{"t": 0.22, "sun_elev": 4.0, "sun_azim": -138.0, "sun_color": Color(1.0, 0.52, 0.30), "sun_energy": 0.80,
		"moon_energy": 0.0, "moon_elev": 22.0, "moon_azim": 48.0,
		"ambient": Color(0.46, 0.40, 0.44), "ambient_e": 0.60,
		"sky_top": Color(0.17, 0.23, 0.41), "sky_mid": Color(0.46, 0.33, 0.44), "sky_horizon": Color(0.93, 0.49, 0.30),
		"sun_glow": Color(1.0, 0.48, 0.24), "sun_sky": 0.60, "moon_sky": 0.0, "star": 0.04,
		"cloud_highlight": Color(0.92, 0.60, 0.45), "cloud_density": 0.76,
		"fog": Color(0.34, 0.29, 0.34), "fog_density": 0.014,
		"water_deep": Color(0.04, 0.09, 0.12), "water_shallow": Color(0.14, 0.25, 0.23),
		"shaft": Color(1.0, 0.62, 0.38), "shaft_i": 0.22,
		"exposure": 1.08, "tint": Color(0.30, 0.40, 0.64), "tint_strength": 0.02, "night": 0.12},
	{"t": 0.45, "sun_elev": -9.0, "sun_azim": -150.0, "sun_color": Color(0.75, 0.42, 0.34), "sun_energy": 0.0,
		"moon_energy": 0.13, "moon_elev": 26.0, "moon_azim": 55.0,
		"ambient": Color(0.28, 0.32, 0.46), "ambient_e": 0.42,
		"sky_top": Color(0.08, 0.13, 0.29), "sky_mid": Color(0.25, 0.29, 0.46), "sky_horizon": Color(0.57, 0.40, 0.46),
		"sun_glow": Color(0.90, 0.40, 0.25), "sun_sky": 0.16, "moon_sky": 0.25, "star": 0.26,
		"cloud_highlight": Color(0.54, 0.56, 0.68), "cloud_density": 0.64,
		"fog": Color(0.20, 0.24, 0.34), "fog_density": 0.016,
		"water_deep": Color(0.03, 0.07, 0.11), "water_shallow": Color(0.10, 0.19, 0.22),
		"shaft": Color(0.66, 0.76, 0.98), "shaft_i": 0.08,
		"exposure": 1.10, "tint": Color(0.28, 0.38, 0.66), "tint_strength": 0.06, "night": 0.52},
	{"t": 0.70, "sun_elev": -16.0, "sun_azim": -160.0, "sun_color": Color(0.60, 0.38, 0.34), "sun_energy": 0.0,
		"moon_energy": 0.30, "moon_elev": 33.0, "moon_azim": 60.0,
		"ambient": Color(0.16, 0.20, 0.33), "ambient_e": 0.37,
		"sky_top": Color(0.035, 0.06, 0.15), "sky_mid": Color(0.09, 0.13, 0.26), "sky_horizon": Color(0.20, 0.26, 0.39),
		"sun_glow": Color(0.65, 0.35, 0.26), "sun_sky": 0.0, "moon_sky": 0.72, "star": 0.74,
		"cloud_highlight": Color(0.35, 0.42, 0.58), "cloud_density": 0.50,
		"fog": Color(0.12, 0.16, 0.25), "fog_density": 0.018,
		"water_deep": Color(0.02, 0.05, 0.08), "water_shallow": Color(0.06, 0.13, 0.16),
		"shaft": Color(0.56, 0.70, 0.98), "shaft_i": 0.02,
		"exposure": 1.14, "tint": Color(0.26, 0.36, 0.64), "tint_strength": 0.08, "night": 0.82},
	{"t": 1.0, "sun_elev": -22.0, "sun_azim": -170.0, "sun_color": Color(0.52, 0.34, 0.34), "sun_energy": 0.0,
		"moon_energy": 0.40, "moon_elev": 41.0, "moon_azim": 66.0,
		"ambient": Color(0.12, 0.16, 0.27), "ambient_e": 0.33,
		"sky_top": Color(0.015, 0.025, 0.07), "sky_mid": Color(0.035, 0.055, 0.12), "sky_horizon": Color(0.10, 0.14, 0.23),
		"sun_glow": Color(0.50, 0.32, 0.28), "sun_sky": 0.0, "moon_sky": 1.0, "star": 1.0,
		"cloud_highlight": Color(0.24, 0.30, 0.45), "cloud_density": 0.40,
		"fog": Color(0.07, 0.10, 0.16), "fog_density": 0.020,
		"water_deep": Color(0.015, 0.04, 0.065), "water_shallow": Color(0.045, 0.10, 0.13),
		"shaft": Color(0.50, 0.64, 0.94), "shaft_i": 0.0,
		"exposure": 1.16, "tint": Color(0.24, 0.34, 0.62), "tint_strength": 0.10, "night": 1.0},
]


func _ready() -> void:
	movie_mode = Array(OS.get_cmdline_user_args()).has("--movie")
	DisplayServer.window_set_title("暮色回廊 · Dusk Cloister")
	_setup_viewport()
	_setup_world()
	_setup_camera()
	_setup_post()
	_setup_display()
	_setup_hud()
	_setup_marker()
	_apply_time(0.0)
	_layout_display()
	get_viewport().size_changed.connect(_on_window_resized)
	if movie_mode:
		_setup_movie_mode()
	else:
		# 开场稳定后把时间自动播放打开（默认在黄昏）。
		auto_time = true
	set_process(true)
	set_physics_process(true)
	print("DUSK_GARDEN_READY internal=%dx%d window=%dx%d scale=%d lamps=%d fireflies=%d" % [
		internal_size.x, internal_size.y, int(get_viewport().get_visible_rect().size.x),
		int(get_viewport().get_visible_rect().size.y), display_scale,
		world.lamps.size(), world.fireflies.count])


# ── 构建 ───────────────────────────────────────────────────────────────
func _setup_viewport() -> void:
	world_viewport = SubViewport.new()
	world_viewport.name = "WorldViewport"
	world_viewport.size = internal_size
	world_viewport.own_world_3d = true
	world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_viewport.msaa_3d = Viewport.MSAA_DISABLED
	world_viewport.msaa_2d = Viewport.MSAA_DISABLED
	world_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	world_viewport.use_taa = false
	world_viewport.use_debanding = false
	world_viewport.transparent_bg = false
	world_viewport.gui_disable_input = true
	world_viewport.handle_input_locally = false
	add_child(world_viewport)


func _setup_world() -> void:
	world = WorldScript.new()
	world.name = "GardenWorld"
	world_viewport.add_child(world)
	world.build()


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "GardenCamera"
	camera.fov = cam_fov
	camera.near = 0.08
	camera.far = 260.0
	world_viewport.add_child(camera)
	camera.current = true


func _setup_post() -> void:
	post_viewport = SubViewport.new()
	post_viewport.name = "PostViewport"
	post_viewport.size = internal_size
	post_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	post_viewport.msaa_2d = Viewport.MSAA_DISABLED
	post_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	post_viewport.use_taa = false
	post_viewport.use_debanding = false
	post_viewport.transparent_bg = false
	post_viewport.gui_disable_input = true
	post_viewport.handle_input_locally = false
	post_viewport.disable_3d = true
	add_child(post_viewport)
	post_mat = ShaderMaterial.new()
	post_mat.shader = PostShader
	post_mat.set_shader_parameter("world_tex", world_viewport.get_texture())
	post_mat.set_shader_parameter("levels", 20.0)
	post_mat.set_shader_parameter("dither", 0.18)
	post_mat.set_shader_parameter("exposure", 1.0)
	post_mat.set_shader_parameter("saturation", 1.07)
	post_mat.set_shader_parameter("vignette", 0.24)
	post_mat.set_shader_parameter("clarity", 0.05)
	post_rect = TextureRect.new()
	post_rect.name = "PostRect"
	post_rect.texture = world_viewport.get_texture()
	post_rect.material = post_mat
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post_rect.size = Vector2(internal_size)
	post_rect.position = Vector2.ZERO
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_viewport.add_child(post_rect)


func _setup_display() -> void:
	display_root = Control.new()
	display_root.name = "Display"
	display_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	display_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display_root)
	backdrop = ColorRect.new()
	backdrop.name = "Letterbox"
	backdrop.color = Color(0.028, 0.036, 0.038)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_root.add_child(backdrop)
	screen = TextureRect.new()
	screen.name = "PixelScreen"
	screen.texture = post_viewport.get_texture()
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_root.add_child(screen)


func _setup_hud() -> void:
	hud = HudScript.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	hud.setup(self)


func _setup_marker() -> void:
	_marker = MeshInstance3D.new()
	_marker.name = "ClickMarker"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.36
	torus.rings = 16
	torus.ring_segments = 5
	_marker.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(1.0, 0.78, 0.42, 0.9)
	mat.disable_receive_shadows = true
	_marker.material_override = mat
	_marker.position = Vector3(0, -20, 0)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	world.add_child(_marker)


func _setup_movie_mode() -> void:
	ui_visible = false
	hud.set_ui_visible(false)
	auto_time = false
	time_of_day = 0.10
	cam_yaw = -14.0
	cam_pitch = 23.0
	cam_dist = 8.2
	_movie_time = 0.0
	_movie_index = 0
	print("MOVIE_MODE start")


# ── 尺寸 / 像素化 ──────────────────────────────────────────────────────
func compute_display_scale(win: Vector2, internal: Vector2i) -> int:
	return maxi(1, int(floor(min(win.x / float(internal.x), win.y / float(internal.y)))))


func compute_screen_rect(win: Vector2, internal: Vector2i) -> Rect2:
	var s := compute_display_scale(win, internal)
	var size := Vector2(internal) * float(s)
	var pos := ((win - size) * 0.5).floor()
	return Rect2(pos, size)


func _layout_display() -> void:
	var win := get_viewport().get_visible_rect().size
	screen_rect = compute_screen_rect(win, internal_size)
	display_scale = compute_display_scale(win, internal_size)
	if screen != null:
		screen.position = screen_rect.position
		screen.size = screen_rect.size
		screen.texture = post_viewport.get_texture()


func _on_window_resized() -> void:
	_layout_display()


func set_internal_index(index: int) -> void:
	internal_index = clampi(index, 0, INTERNAL_OPTIONS.size() - 1)
	internal_size = INTERNAL_OPTIONS[internal_index]
	if world_viewport != null:
		world_viewport.size = internal_size
	if post_viewport != null:
		post_viewport.size = internal_size
	if post_rect != null:
		post_rect.size = Vector2(internal_size)
	_layout_display()
	if hud != null:
		hud.sync_from_main()


# ── 时间 / 环境 ────────────────────────────────────────────────────────
func _sample_time(t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	var out: Dictionary = _time_keys[0].duplicate(true)
	for i in _time_keys.size() - 1:
		var a: Dictionary = _time_keys[i]
		var b: Dictionary = _time_keys[i + 1]
		if t <= float(b["t"]) or i == _time_keys.size() - 2:
			var f := clampf((t - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.0001), 0.0, 1.0)
			var fs := f * f * (3.0 - 2.0 * f)
			for key in a.keys():
				if key == "t":
					continue
				var va = a[key]
				var vb = b[key]
				if va is Color:
					out[key] = (va as Color).lerp(vb as Color, fs)
				elif va is float:
					out[key] = lerpf(va, vb, fs)
			break
	out["t"] = t
	var sun_elev := deg_to_rad(float(out["sun_elev"]))
	var sun_azim := deg_to_rad(float(out["sun_azim"]))
	var moon_elev := deg_to_rad(float(out["moon_elev"]))
	var moon_azim := deg_to_rad(float(out["moon_azim"]))
	out["sun_dir"] = Vector3(sin(sun_azim) * cos(sun_elev), sin(sun_elev), cos(sun_azim) * cos(sun_elev))
	out["moon_dir"] = Vector3(sin(moon_azim) * cos(moon_elev), sin(moon_elev), cos(moon_azim) * cos(moon_elev))
	out["moon_color"] = Color(0.58, 0.70, 1.0)
	out["wind"] = wind
	return out


func _apply_time(delta: float) -> void:
	var state := _sample_time(time_of_day)
	_current_state = state
	night_amount = float(state["night"])

	var thresholds: Array[float] = world.get_lamp_thresholds()
	_lamp_levels.clear()
	for i in thresholds.size():
		var lv := 0.0
		if lamps_enabled:
			var x := clampf((time_of_day - thresholds[i]) / 0.045, 0.0, 1.0)
			lv = smoothstep(0.0, 1.0, x)
			if x > 0.001 and x < 0.999:
				var flick := 0.68 + 0.32 * sin(anim_time * 19.0 + i * 3.7)
				flick *= 0.75 + 0.25 * sin(anim_time * 7.3 + i * 1.7)
				lv *= clampf(flick, 0.18, 1.0)
		_lamp_levels.append(lv)
	world.apply_environment(state)
	world.apply_lamp_levels(_lamp_levels)

	var firefly_activity := smoothstep(0.30, 0.72, time_of_day)
	if not fireflies_enabled:
		firefly_activity = 0.0
	world.fireflies.set_activity(firefly_activity)

	if not paused and delta > 0.0:
		cloud_offset += Vector2(0.012, 0.005) * delta * wind
	RenderingServer.global_shader_parameter_set("g_time", anim_time)
	RenderingServer.global_shader_parameter_set("g_cloud_x", cloud_offset.x)
	RenderingServer.global_shader_parameter_set("g_cloud_z", cloud_offset.y)
	RenderingServer.global_shader_parameter_set("g_cloud_shadow", lerpf(0.30, 0.10, night_amount))
	RenderingServer.global_shader_parameter_set("g_fog_color", state["fog"])
	RenderingServer.global_shader_parameter_set("g_fog_density", float(state["fog_density"]))
	RenderingServer.global_shader_parameter_set("g_night", night_amount)
	RenderingServer.global_shader_parameter_set("g_wind", wind)
	RenderingServer.global_shader_parameter_set("g_sky_top", state["sky_top"])
	RenderingServer.global_shader_parameter_set("g_sky_mid", state["sky_mid"])
	RenderingServer.global_shader_parameter_set("g_sky_horizon", state["sky_horizon"])
	RenderingServer.global_shader_parameter_set("g_light_color", _current_light_color(state))
	RenderingServer.global_shader_parameter_set("g_star", float(state["star"]))
	RenderingServer.global_shader_parameter_set("g_lamp_warmth", Color(1.0, 0.68, 0.34))

	if post_mat != null:
		post_mat.set_shader_parameter("exposure", float(state["exposure"]))
		post_mat.set_shader_parameter("tint_strength", float(state["tint_strength"]))
		post_mat.set_shader_parameter("tint_color", state["tint"])
		post_mat.set_shader_parameter("levels", 20.0)
		post_mat.set_shader_parameter("dither", 0.18)
		_update_godrays(state)


# 屏幕空间丁达尔：把日/月盘周围的高光做径向散射，叠加在低分辨率后期上。
func _update_godrays(state: Dictionary) -> void:
	var sun_sky := float(state["sun_sky"])
	var moon_sky := float(state["moon_sky"])
	var use_moon := moon_sky > sun_sky
	var strength := moon_sky if use_moon else sun_sky
	if strength < 0.05 or camera == null or world_viewport == null:
		post_mat.set_shader_parameter("godray_strength", 0.0)
		return
	var dir: Vector3 = state["moon_dir"] if use_moon else state["sun_dir"]
	var far := camera.global_position + dir * 120.0
	if camera.is_position_behind(far):
		post_mat.set_shader_parameter("godray_strength", 0.0)
		return
	var sp := camera.unproject_position(far)
	var uv := sp / Vector2(world_viewport.size)
	if uv.x < -0.2 or uv.x > 1.2 or uv.y < -0.2 or uv.y > 1.2:
		post_mat.set_shader_parameter("godray_strength", 0.0)
		return
	post_mat.set_shader_parameter("godray_pos", uv)
	post_mat.set_shader_parameter("godray_strength", strength * 0.7)
	post_mat.set_shader_parameter("godray_color", Color(0.72, 0.82, 1.0) if use_moon else state["sun_glow"])


func _current_light_color(state: Dictionary) -> Color:
	var sun_e := float(state["sun_energy"])
	var moon_e := float(state["moon_energy"])
	return state["sun_color"] if sun_e >= moon_e else state["moon_color"]


func set_time_of_day(value: float, apply_now: bool = true) -> void:
	time_of_day = clampf(value, 0.0, 1.0)
	if apply_now:
		_apply_time(0.0)
	if hud != null:
		hud.sync_from_main()


func apply_preset(index: int) -> void:
	var i := clampi(index, 0, PRESET_TIMES.size() - 1)
	auto_time = false
	set_time_of_day(PRESET_TIMES[i])
	if hud != null:
		hud.sync_from_main()


func reset_camera() -> void:
	camera_override = false
	cam_yaw = -9.0
	cam_pitch = 22.0
	cam_dist = 9.0
	_cam_initialized = false


func set_camera_override(target: Vector3, yaw_deg: float, pitch_deg: float, dist: float) -> void:
	camera_override = true
	camera_override_target = target
	cam_yaw = yaw_deg
	cam_pitch = clampf(pitch_deg, 2.0, 80.0)
	cam_dist = dist
	_cam_initialized = false


func clear_camera_override() -> void:
	camera_override = false
	_cam_initialized = false


func get_clock_text() -> String:
	var minutes := int(round(18.0 * 60.0 + 30.0 + time_of_day * 240.0))
	return "%02d:%02d" % [int(minutes / 60) % 24, minutes % 60]


func get_phase_label() -> String:
	if time_of_day < 0.24:
		return "黄昏"
	elif time_of_day < 0.44:
		return "日落"
	elif time_of_day < 0.72:
		return "蓝调"
	return "深夜"


func get_lit_lamp_count() -> int:
	var n := 0
	for lv in _lamp_levels:
		if lv > 0.5:
			n += 1
	return n


func get_firefly_visible_count() -> int:
	if world == null or world.fireflies == null:
		return 0
	return int(world.fireflies.visible_count)


# ── 每帧 ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	var sim_delta := delta if not paused else 0.0
	if movie_mode:
		_update_movie(sim_delta)
	else:
		if auto_time and not paused:
			time_of_day = minf(1.0, time_of_day + delta * BASE_TIME_SPEED * time_speed)
			if time_of_day >= 1.0:
				auto_time = false
	if not paused:
		anim_time += delta
	_apply_time(sim_delta)
	_update_movement(sim_delta)
	_update_camera(delta)
	_update_marker(sim_delta)
	_stats_tick += delta
	if _stats_tick >= 0.25:
		_stats_tick = 0.0
		_fps_value = Engine.get_frames_per_second()
		_draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if _draw_calls < 0:
			_draw_calls = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		if hud != null:
			hud.refresh_stats()
			hud.sync_from_main()


func _update_movie(delta: float) -> void:
	_movie_time += delta
	var k := clampf(_movie_time / MOVIE_LENGTH, 0.0, 1.0)
	time_of_day = lerpf(0.14, 0.92, smoothstep(0.0, 1.0, k))
	cam_yaw = lerpf(-14.0, 5.0, k)
	cam_pitch = lerpf(23.0, 19.0, k)
	cam_dist = lerpf(8.2, 7.4, k)
	if _movie_index < _movie_waypoints.size():
		var keeper = world.keeper
		if not keeper.has_move_target:
			keeper.walk_to(_movie_waypoints[_movie_index])
			_movie_index += 1
	if _movie_time >= MOVIE_LENGTH:
		print("MOVIE_DONE frames=%d" % int(_movie_time * 30.0))
		get_tree().quit(0)


func _update_movement(delta: float) -> void:
	if movie_mode or paused:
		world.keeper.set_move_dir(Vector3.ZERO)
		return
	var dir := Vector3.ZERO
	if _test_move.length_squared() > 0.0001:
		dir = _test_move
	else:
		var basis := camera.global_transform.basis
		var forward := Vector3(-basis.z.x, 0.0, -basis.z.z).normalized()
		var right := Vector3(basis.x.x, 0.0, basis.x.z).normalized()
		var ix := 0.0
		var iz := 0.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			ix -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			ix += 1.0
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			iz += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			iz -= 1.0
		dir = forward * iz + right * ix
		world.keeper.running = Input.is_physical_key_pressed(KEY_SHIFT) or _test_running
	if _test_running:
		world.keeper.running = true
	if dir.length_squared() > 0.0001:
		world.keeper.set_move_dir(dir.normalized())
	else:
		world.keeper.set_move_dir(Vector3.ZERO)


func _update_camera(delta: float) -> void:
	if camera == null:
		return
	var target: Vector3 = camera_override_target if camera_override else world.keeper.global_position + Vector3(0, 1.0, 0)
	var yaw := deg_to_rad(cam_yaw)
	var pitch := deg_to_rad(cam_pitch)
	var desired: Vector3 = target + Vector3(
		sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * cam_dist
	desired.y = maxf(desired.y, 0.75)
	if not camera_override:
		# headless（无渲染/物理世界）下 world_3d 可能为 null；GPU 运行时正常做遮挡回拉。
		var world3d: World3D = world_viewport.world_3d if world_viewport != null else null
		if world3d != null:
			var space := world3d.direct_space_state
			if space != null:
				var query := PhysicsRayQueryParameters3D.create(target, desired, 1)
				query.collide_with_areas = false
				var hit := space.intersect_ray(query)
				if not hit.is_empty():
					desired = hit["position"] + hit["normal"] * 0.35
					desired.y = maxf(desired.y, 0.75)
	var snap := camera_override or not _cam_initialized
	if snap:
		_cam_pos = desired
		_cam_target = target
		_cam_initialized = true
	else:
		var k := 1.0 - exp(-delta * 9.0)
		_cam_pos = _cam_pos.lerp(desired, k)
		_cam_target = _cam_target.lerp(target, k)
	camera.global_position = _cam_pos
	camera.look_at(_cam_target, Vector3.UP)
	if pixel_snap:
		_apply_pixel_snap(_cam_target)


# 像素偏移补偿：把跟随锚点吸附到低分辨率 RT 的像素中心，
# 消掉角色在慢速移动时的亚像素抖动（世界随相机整体 1px 级吸附）。
func _apply_pixel_snap(anchor: Vector3) -> void:
	if camera == null or world_viewport == null or internal_size.y <= 0:
		return
	var depth := camera.global_position.distance_to(anchor)
	if depth < 0.4:
		return
	var sp := camera.unproject_position(anchor)
	if not is_finite(sp.x) or not is_finite(sp.y):
		return
	var px := Vector2(round(sp.x), round(sp.y)) - sp
	px.x = clampf(px.x, -0.5, 0.5)
	px.y = clampf(px.y, -0.5, 0.5)
	if absf(px.x) < 0.001 and absf(px.y) < 0.001:
		return
	var wpp := 2.0 * depth * tan(deg_to_rad(camera.fov) * 0.5) / float(internal_size.y)
	var b := camera.global_transform.basis
	camera.global_position += b.x * (-px.x * wpp) + b.y * (px.y * wpp)


func _update_marker(delta: float) -> void:
	if _marker == null or not _marker_active:
		return
	_marker_time += delta
	var t := _marker_time / 0.9
	if t >= 1.0:
		_marker_active = false
		_marker.position.y = -20.0
		return
	var s := lerpf(0.6, 1.5, t)
	_marker.scale = Vector3(s, s, s)
	var mat: StandardMaterial3D = _marker.material_override
	mat.albedo_color.a = (1.0 - t) * 0.85


# ── 输入 ───────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_dist = clampf(cam_dist * 0.9, 4.0, 26.0)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_dist = clampf(cam_dist * 1.1, 4.0, 26.0)
			return
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_click(mb.position)
			return
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.22
		cam_pitch = clampf(cam_pitch - mm.relative.y * 0.18, 6.0, 68.0)
		cam_yaw = fposmod(cam_yaw, 360.0)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			_handle_hotkey(k)


func _handle_hotkey(k: InputEventKey) -> void:
	match k.keycode:
		KEY_SPACE:
			set_param("paused", not paused)
		KEY_H:
			ui_visible = not ui_visible
			hud.set_ui_visible(ui_visible)
		KEY_F:
			set_param("lamps", not lamps_enabled)
		KEY_G:
			set_param("fireflies", not fireflies_enabled)
		KEY_T:
			set_param("auto", not auto_time)
		KEY_1:
			apply_preset(0)
		KEY_2:
			apply_preset(1)
		KEY_3:
			apply_preset(2)
		KEY_P:
			set_param("pixel_snap", not pixel_snap)
		KEY_R:
			reset_camera()
		KEY_Q:
			cam_yaw -= 8.0
		KEY_E:
			cam_yaw += 8.0
		KEY_BRACKETLEFT:
			auto_time = false
			set_time_of_day(time_of_day - 0.03)
		KEY_BRACKETRIGHT:
			auto_time = false
			set_time_of_day(time_of_day + 0.03)


func _handle_click(window_pos: Vector2) -> void:
	if not screen_rect.has_point(window_pos):
		return
	var local := (window_pos - screen_rect.position) / float(display_scale)
	var origin := camera.project_ray_origin(local)
	var dir := camera.project_ray_normal(local)
	if absf(dir.y) < 0.0001:
		return
	var t := (0.10 - origin.y) / dir.y
	if t <= 0.0 or t > 120.0:
		return
	var point := origin + dir * t
	point.x = clampf(point.x, -10.6, 10.6)
	point.z = clampf(point.z, -10.6, 10.6)
	world.keeper.walk_to(Vector3(point.x, world.keeper.global_position.y, point.z))
	_marker.position = Vector3(point.x, 0.16, point.z)
	_marker_time = 0.0
	_marker_active = true
	_marker.scale = Vector3.ONE


# ── 对外参数 / 自测接口 ────────────────────────────────────────────────
func set_param(key: String, value) -> void:
	match key:
		"time":
			set_time_of_day(float(value))
		"auto":
			auto_time = bool(value)
		"speed":
			time_speed = clampf(float(value), 0.2, 4.0)
		"lamps":
			lamps_enabled = bool(value)
			_apply_time(0.0)
		"fireflies":
			fireflies_enabled = bool(value)
			_apply_time(0.0)
		"paused":
			paused = bool(value)
			world.set_paused(paused)
		"ui":
			ui_visible = bool(value)
			hud.set_ui_visible(ui_visible)
		"internal_index":
			set_internal_index(int(value))
		"preset":
			apply_preset(int(value))
		"wind":
			wind = clampf(float(value), 0.0, 2.5)
			_apply_time(0.0)
		"pixel_snap":
			pixel_snap = bool(value)
		"camera_reset":
			reset_camera()
	if hud != null:
		hud.sync_from_main()


func get_params() -> Dictionary:
	return {
		"time": time_of_day,
		"clock": get_clock_text(),
		"phase": get_phase_label(),
		"auto": auto_time,
		"speed": time_speed,
		"lamps": lamps_enabled,
		"lit": get_lit_lamp_count(),
		"lamp_count": world.lamps.size() if world != null else 0,
		"fireflies": fireflies_enabled,
		"firefly_visible": get_firefly_visible_count(),
		"firefly_total": world.fireflies.count if world != null else 0,
		"paused": paused,
		"night": night_amount,
		"fps": _fps_value,
		"draw_calls": _draw_calls,
		"internal_index": internal_index,
		"internal_label": INTERNAL_LABELS[internal_index],
		"display_scale": hud_scale_override if hud_scale_override > 0 else display_scale,
		"pixel_snap": pixel_snap,
		"ui": ui_visible,
	}


func get_lamp_levels() -> Array[float]:
	return _lamp_levels.duplicate()


func get_internal_size() -> Vector2i:
	return internal_size


func get_display_scale() -> int:
	return display_scale


func get_fps() -> int:
	return _fps_value


func get_draw_calls() -> int:
	return _draw_calls


func set_test_move(dir: Vector3, running: bool = false) -> void:
	_test_move = dir
	_test_running = running


func clear_test_move() -> void:
	_test_move = Vector3.ZERO
	_test_running = false


func prewarm(seconds: float) -> void:
	anim_time += seconds
	world.prewarm_fireflies(seconds)
	_apply_time(0.0)


func get_character_position() -> Vector3:
	return world.keeper.global_position


func get_camera_position() -> Vector3:
	return camera.global_position


func set_ui_visible(value: bool) -> void:
	ui_visible = value
	if hud != null:
		hud.set_ui_visible(value)


func toggle_pause() -> void:
	set_param("paused", not paused)
