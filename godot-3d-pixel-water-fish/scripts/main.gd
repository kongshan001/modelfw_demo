extends Node

# 主控：低分辨率 3D RT → 整数倍最近邻放大；3D 内后期量化/抖动/描边；
# 场景/水面/鱼群接线；轨道相机（水上/水下）；中文全分辨率 HUD；调试视图。
#
# 关键管线：
#   root Window (1280×720 或 1920×1080)
#     └── SubViewport 640×360 (nearest, no AA)
#           └── Node3D 世界 + Camera3D
#                 └── PixelPost 全屏四边形（spatial shader，可采样深度）
#     └── TextureRect（整数倍放大，最近邻）
#     └── HUD CanvasLayer（全分辨率，不被像素化）

const PondField = preload("res://scripts/pond_field.gd")
const WorldBuilder = preload("res://scripts/world_builder.gd")
const FishManager = preload("res://scripts/fish_manager.gd")
const HUD = preload("res://scripts/hud.gd")
const SHADER_POST = preload("res://shaders/post_pixel.gdshader")
const SHADER_DEBUG_NORMAL = preload("res://shaders/debug_normal.gdshader")
const SHADER_DEBUG_DEPTH = preload("res://shaders/debug_depth.gdshader")

const INTERNAL_OPTIONS := [Vector2i(320, 180), Vector2i(480, 270), Vector2i(640, 360)]
const INTERNAL_LABELS := ["320×180", "480×270", "640×360"]
const DEBUG_NAMES := ["关闭", "低分辨率 RT", "深度", "法线", "描边", "水面 Mask"]
const MOOD_PRESETS := [
	{"name": "晨光", "time": 0.06, "rain": false},
	{"name": "正午", "time": 0.46, "rain": false},
	{"name": "黄昏", "time": 0.8, "rain": false},
	{"name": "雨夜", "time": 0.95, "rain": true},
]

# 时段关键帧：太阳高度/方位、颜色、天空、雾。
const MOOD_KEYS := [
	{"t": 0.0, "elev": 16.0, "azim": -68.0, "sun": Color(1.0, 0.8, 0.62), "energy": 1.12,
		"sky": Color(0.82, 0.88, 0.87), "ambient": Color(0.82, 0.85, 0.8), "ambient_e": 0.7,
		"fog": Color(0.72, 0.82, 0.8), "fog_d": 0.006, "exposure": 1.04},
	{"t": 0.28, "elev": 42.0, "azim": -30.0, "sun": Color(1.0, 0.96, 0.85), "energy": 1.35,
		"sky": Color(0.72, 0.87, 0.9), "ambient": Color(0.8, 0.88, 0.86), "ambient_e": 0.76,
		"fog": Color(0.58, 0.78, 0.78), "fog_d": 0.0045, "exposure": 1.05},
	{"t": 0.5, "elev": 68.0, "azim": 8.0, "sun": Color(1.0, 0.99, 0.93), "energy": 1.45,
		"sky": Color(0.62, 0.84, 0.93), "ambient": Color(0.74, 0.87, 0.9), "ambient_e": 0.78,
		"fog": Color(0.55, 0.78, 0.8), "fog_d": 0.004, "exposure": 1.05},
	{"t": 0.8, "elev": 22.0, "azim": 66.0, "sun": Color(1.0, 0.73, 0.5), "energy": 1.24,
		"sky": Color(0.9, 0.8, 0.68), "ambient": Color(0.84, 0.78, 0.7), "ambient_e": 0.6,
		"fog": Color(0.76, 0.7, 0.64), "fog_d": 0.005, "exposure": 1.04},
	{"t": 1.0, "elev": 26.0, "azim": -120.0, "sun": Color(0.6, 0.75, 1.0), "energy": 0.7,
		"sky": Color(0.14, 0.22, 0.36), "ambient": Color(0.4, 0.5, 0.72), "ambient_e": 0.45,
		"fog": Color(0.15, 0.24, 0.36), "fog_d": 0.008, "exposure": 0.96},
]

var viewport: SubViewport
var composite_viewport: SubViewport
var composite_rect: ColorRect
var world_root: Node3D
var camera: Camera3D
var post_material: ShaderMaterial
var debug_normal_material: ShaderMaterial
var debug_depth_material: ShaderMaterial
var world
var fish_manager
var hud: CanvasLayer
var display_root: Control
var screen_rect: TextureRect
var backdrop: ColorRect

var internal_index := 2
var internal_size := Vector2i(640, 360)
var display_scale := 2

var paused := false
var time_scale := 1.0
var anim_time := 0.0
var time_of_day := 0.42
var weather_rain := false
var rain_amount := 0.0
var levels := 12.0
var dither := 0.2
var outline := 1.0
var palette_on := false
var pixel_snap := true
var clarity := 0.45
var depth_dark := 0.3
var refraction := 0.4
var foam := 0.45
var caustics := 1.0
var ripple_flow := 0.6
var fish_count := 20
var debug_mode := 0
var auto_orbit := true
var ui_visible := true

var cam_yaw := deg_to_rad(26.0)
var cam_pitch := deg_to_rad(62.0)
var cam_dist := 16.0
var cam_target := Vector3(0.0, 0.1, 0.0)
var target_yaw := cam_yaw
var target_pitch := cam_pitch
var target_dist := cam_dist
var target_target := cam_target
var mode_underwater := false
var underwater_amount := 0.0

var base_sky_color := Color(0.63, 0.8, 0.86)
var base_fog_color := Color(0.42, 0.68, 0.7)
var base_fog_density := 0.006
var base_exposure := 1.0

var fps_value := 0
var draw_calls := 0
var _fps_accum := 0.0
var _dragging := false
var _last_mouse := Vector2.ZERO
var _saved_overrides: Array = []
var _hidden_nodes: Array = []
var _debug_overrides_active := false
var _debug_saved_env_bg: Color
var _rng := RandomNumberGenerator.new()
var _movie_mode := false
var _movie_time := 0.0
var _movie_stage := 0
var _started := false


func _ready() -> void:
	_rng.seed = 20261126
	_movie_mode = Array(OS.get_cmdline_user_args()).has("--movie")
	_setup_viewport()
	_setup_world()
	_setup_camera()
	_setup_composite()
	_setup_display()
	_setup_hud()
	_apply_all_params()
	_apply_internal_resolution()
	_apply_mood()
	_layout_display()
	get_viewport().size_changed.connect(_layout_display)
	if _movie_mode:
		_setup_movie_mode()
	_started = true
	_print_ready.call_deferred()


func _print_ready() -> void:
	await get_tree().process_frame
	print("WATER_FISH_READY internal=%dx%d window=%dx%d display_scale=%d fish=%d debug=%d" % [
		internal_size.x, internal_size.y, get_viewport().get_visible_rect().size.x,
		get_viewport().get_visible_rect().size.y, display_scale, fish_manager.get_fish_count(), debug_mode])


# ── 建立节点树 ─────────────────────────────────────────────────────────
func _setup_viewport() -> void:
	viewport = SubViewport.new()
	viewport.name = "WorldViewport"
	viewport.size = internal_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.use_taa = false
	viewport.use_debanding = false
	viewport.transparent_bg = false
	viewport.gui_disable_input = true
	viewport.handle_input_locally = false
	add_child(viewport)
	world_root = Node3D.new()
	world_root.name = "PondWorld"
	viewport.add_child(world_root)


func _setup_display() -> void:
	display_root = Control.new()
	display_root.name = "Display"
	display_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	display_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display_root)
	backdrop = ColorRect.new()
	backdrop.color = Color(0.015, 0.025, 0.03)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_root.add_child(backdrop)
	screen_rect = TextureRect.new()
	screen_rect.name = "PixelScreen"
	screen_rect.texture = composite_viewport.get_texture()
	screen_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	screen_rect.stretch_mode = TextureRect.STRETCH_SCALE
	screen_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_root.add_child(screen_rect)


func _setup_world() -> void:
	world = WorldBuilder.new()
	world.build(world_root)
	fish_manager = FishManager.new()
	fish_manager.name = "FishSchool"
	world_root.add_child(fish_manager)
	fish_manager.setup()
	fish_manager.set_fish_count(fish_count)
	_init_water_rock_params()


func _init_water_rock_params() -> void:
	var rp := PackedVector2Array()
	var rr := PackedFloat32Array()
	for r in PondField.ROCKS:
		rp.append(r["pos"])
		rr.append(float(r["radius"]))
	while rp.size() < 8:
		rp.append(Vector2.ZERO)
		rr.append(0.0)
	world.water_material.set_shader_parameter("rock_pos", rp)
	world.water_material.set_shader_parameter("rock_radius", rr)
	world.water_material.set_shader_parameter("rock_count", float(PondField.ROCKS.size()))


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "PondCamera"
	camera.fov = 48.0
	camera.near = 0.05
	camera.far = 80.0
	world_root.add_child(camera)
	camera.current = true
	_update_camera_transform(1.0, true)


func _setup_composite() -> void:
	# 第二段：640×360 画布后期，采样 WorldViewport 的最终 3D 纹理。
	# 这样水面（自身也采样屏幕）能完整进入后期，GL Compatibility 下不会丢。
	composite_viewport = SubViewport.new()
	composite_viewport.name = "CompositeViewport"
	composite_viewport.size = internal_size
	composite_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	composite_viewport.msaa_2d = Viewport.MSAA_DISABLED
	composite_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	composite_viewport.use_taa = false
	composite_viewport.use_debanding = false
	composite_viewport.transparent_bg = false
	composite_viewport.gui_disable_input = true
	composite_viewport.handle_input_locally = false
	add_child(composite_viewport)

	post_material = ShaderMaterial.new()
	post_material.shader = SHADER_POST
	post_material.set_shader_parameter("world_tex", viewport.get_texture())
	post_material.set_shader_parameter("outline_color", Color(0.045, 0.09, 0.1))
	composite_rect = ColorRect.new()
	composite_rect.name = "PixelPost"
	composite_rect.position = Vector2.ZERO
	composite_rect.size = Vector2(internal_size)
	composite_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	composite_rect.material = post_material
	composite_viewport.add_child(composite_rect)

	debug_normal_material = ShaderMaterial.new()
	debug_normal_material.shader = SHADER_DEBUG_NORMAL
	debug_depth_material = ShaderMaterial.new()
	debug_depth_material.shader = SHADER_DEBUG_DEPTH


func _setup_hud() -> void:
	hud = HUD.new()
	hud.name = "HUD"
	hud.layer = 10
	add_child(hud)
	hud.setup(self)


# ── 显示缩放 ───────────────────────────────────────────────────────────
static func compute_display_scale(window_size: Vector2, inner: Vector2i) -> int:
	var sx := int(window_size.x) / maxi(inner.x, 1)
	var sy := int(window_size.y) / maxi(inner.y, 1)
	return maxi(1, mini(sx, sy))


func _layout_display() -> void:
	if display_root == null or screen_rect == null:
		return
	var win := get_viewport().get_visible_rect().size
	var scale := compute_display_scale(win, internal_size)
	display_scale = scale
	var w := float(internal_size.x * scale)
	var h := float(internal_size.y * scale)
	screen_rect.position = Vector2((win.x - w) * 0.5, (win.y - h) * 0.5)
	screen_rect.size = Vector2(w, h)


func _apply_internal_resolution() -> void:
	internal_index = clampi(internal_index, 0, INTERNAL_OPTIONS.size() - 1)
	internal_size = INTERNAL_OPTIONS[internal_index]
	viewport.size = internal_size
	composite_viewport.size = internal_size
	composite_rect.size = Vector2(internal_size)
	screen_rect.texture = composite_viewport.get_texture()
	post_material.set_shader_parameter("world_tex", viewport.get_texture())
	RenderingServer.global_shader_parameter_set("g_res_x", float(internal_size.x))
	RenderingServer.global_shader_parameter_set("g_res_y", float(internal_size.y))
	_layout_display()


# ── 参数应用 ───────────────────────────────────────────────────────────
func _apply_all_params() -> void:
	RenderingServer.global_shader_parameter_set("g_light_steps", 3.0)
	RenderingServer.global_shader_parameter_set("g_pixel_snap", 1.0 if pixel_snap else 0.0)
	RenderingServer.global_shader_parameter_set("g_caustics", caustics)
	RenderingServer.global_shader_parameter_set("g_time", anim_time)
	RenderingServer.global_shader_parameter_set("g_rain", 0.0)
	_apply_post_params()
	_apply_water_params()
	_apply_mood()


func _apply_post_params() -> void:
	if post_material == null:
		return
	post_material.set_shader_parameter("levels", levels)
	post_material.set_shader_parameter("dither", dither)
	post_material.set_shader_parameter("outline", outline)
	post_material.set_shader_parameter("palette_on", 1.0 if palette_on else 0.0)
	post_material.set_shader_parameter("debug_mode", float(debug_mode))
	post_material.set_shader_parameter("exposure", base_exposure)
	post_material.set_shader_parameter("saturation", 1.04)
	post_material.set_shader_parameter("lift", 0.018)


func _apply_water_params() -> void:
	if world == null or world.water_material == null:
		return
	var m: ShaderMaterial = world.water_material
	m.set_shader_parameter("clarity", clarity)
	m.set_shader_parameter("depth_dark", depth_dark)
	m.set_shader_parameter("refraction", refraction)
	m.set_shader_parameter("foam", foam)
	m.set_shader_parameter("flow", ripple_flow)
	m.set_shader_parameter("rain_amount", rain_amount)
	m.set_shader_parameter("sky_color", base_sky_color)
	m.set_shader_parameter("sun_color", world.light.light_color)
	m.set_shader_parameter("debug_mask", 1.0 if debug_mode == 5 else 0.0)
	if world.shaft_material != null:
		world.shaft_material.set_shader_parameter("intensity", 0.14 + underwater_amount * 0.06)


func _apply_mood() -> void:
	if world == null:
		return
	var key := _mood_at(time_of_day)
	var sky: Color = key["sky"]
	var sun: Color = key["sun"]
	var energy: float = key["energy"]
	var ambient: Color = key["ambient"]
	var ambient_e: float = key["ambient_e"]
	var fog: Color = key["fog"]
	var fog_d: float = key["fog_d"]
	var exposure: float = key["exposure"]
	if weather_rain:
		sky = sky.lerp(Color(0.36, 0.44, 0.48), 0.55)
		sun = sun.lerp(Color(0.66, 0.74, 0.84), 0.5)
		energy *= 0.55
		ambient = ambient.lerp(Color(0.42, 0.55, 0.6), 0.5)
		ambient_e *= 0.85
		fog = fog.lerp(Color(0.38, 0.5, 0.53), 0.5)
		fog_d *= 1.7
		exposure *= 0.92
	var sun_rot := Vector3(-float(key["elev"]), float(key["azim"]), 0.0)
	world.light.rotation_degrees = sun_rot
	world.light.light_color = sun
	world.light.light_energy = energy
	if world.environment != null:
		var env: Environment = world.environment.environment
		env.ambient_light_color = ambient
		env.ambient_light_energy = ambient_e
		env.background_color = sky
	base_sky_color = sky
	base_fog_color = fog
	base_fog_density = fog_d
	base_exposure = exposure
	var sun_vec: Vector3 = world.light.global_transform.basis.z.normalized()
	RenderingServer.global_shader_parameter_set("g_sun_dir_x", sun_vec.x)
	RenderingServer.global_shader_parameter_set("g_sun_dir_y", sun_vec.y)
	RenderingServer.global_shader_parameter_set("g_sun_dir_z", sun_vec.z)
	RenderingServer.global_shader_parameter_set("g_sun_color", sun)
	RenderingServer.global_shader_parameter_set("g_sky_color", sky)
	_apply_post_params()
	if world.water_material != null:
		world.water_material.set_shader_parameter("sky_color", sky.lerp(Color(0.55, 0.8, 0.86), 0.45))
		world.water_material.set_shader_parameter("sun_color", sun)
	if world.shaft_material != null:
		world.shaft_material.set_shader_parameter("beam_color", sky.lerp(Color(0.7, 0.95, 0.95), 0.6))


func _mood_at(t: float) -> Dictionary:
	t = clampf(t, 0.0, 1.0)
	for i in MOOD_KEYS.size() - 1:
		var a: Dictionary = MOOD_KEYS[i]
		var b: Dictionary = MOOD_KEYS[i + 1]
		if t >= float(a["t"]) and t <= float(b["t"]):
			var span := maxf(float(b["t"]) - float(a["t"]), 0.0001)
			var k := smoothstep(0.0, 1.0, (t - float(a["t"])) / span)
			return {
				"elev": lerpf(float(a["elev"]), float(b["elev"]), k),
				"azim": lerpf(float(a["azim"]), float(b["azim"]), k),
				"sun": (a["sun"] as Color).lerp(b["sun"] as Color, k),
				"energy": lerpf(float(a["energy"]), float(b["energy"]), k),
				"sky": (a["sky"] as Color).lerp(b["sky"] as Color, k),
				"ambient": (a["ambient"] as Color).lerp(b["ambient"] as Color, k),
				"ambient_e": lerpf(float(a["ambient_e"]), float(b["ambient_e"]), k),
				"fog": (a["fog"] as Color).lerp(b["fog"] as Color, k),
				"fog_d": lerpf(float(a["fog_d"]), float(b["fog_d"]), k),
				"exposure": lerpf(float(a["exposure"]), float(b["exposure"]), k),
			}
	return MOOD_KEYS[MOOD_KEYS.size() - 1].duplicate()


# ── 每帧 ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	delta = clampf(delta, 0.0, 0.05)
	if _movie_mode:
		_cinematic(delta)
	if not paused:
		anim_time += delta * time_scale
	RenderingServer.global_shader_parameter_set("g_time", anim_time)

	var rain_target := 1.0 if weather_rain else 0.0
	rain_amount = move_toward(rain_amount, rain_target, delta * 2.2)
	RenderingServer.global_shader_parameter_set("g_rain", rain_amount)

	if not paused:
		fish_manager.update_fish(delta, anim_time, true)
		fish_manager.update_rain(delta, anim_time, rain_amount)

	_update_camera_transform(delta, false)
	var want_underwater := 1.0 if camera.global_position.y < -0.02 else 0.0
	underwater_amount = move_toward(underwater_amount, want_underwater, delta * 4.0)
	RenderingServer.global_shader_parameter_set("g_underwater", underwater_amount)

	_update_world_uniforms(delta)
	_update_hud_stats(delta)

	if _movie_mode and _movie_time > 10.0:
		get_tree().quit()


func _update_camera_transform(delta: float, instant: bool) -> void:
	if auto_orbit and not _dragging:
		target_yaw += deg_to_rad(2.2) * delta
	var k := 1.0 if instant else 1.0 - exp(-delta * 5.0)
	cam_yaw = lerp_angle(cam_yaw, target_yaw, k)
	cam_pitch = lerpf(cam_pitch, target_pitch, k)
	cam_dist = lerpf(cam_dist, target_dist, k)
	cam_target = cam_target.lerp(target_target, k)
	var want_fov := 58.0 if mode_underwater else 48.0
	camera.fov = lerpf(camera.fov, want_fov, k)
	var cp := cos(cam_pitch)
	var offset := Vector3(sin(cam_yaw) * cp, sin(cam_pitch), cos(cam_yaw) * cp) * cam_dist
	var pos := cam_target + offset
	if mode_underwater and pos.y < 0.25:
		var safe := PondField.clamp_to_water(Vector2(pos.x, pos.z), 0.9)
		pos.x = safe.x
		pos.z = safe.y
		var fy := PondField.floor_y(Vector2(pos.x, pos.z))
		pos.y = clampf(pos.y, fy + 0.32, -0.18)
	camera.global_position = pos
	camera.look_at(cam_target, Vector3.UP)


func _update_world_uniforms(_delta: float) -> void:
	var uw := underwater_amount
	var fog := base_fog_color.lerp(Color(0.12, 0.4, 0.44), uw)
	var fog_d := lerpf(base_fog_density, 0.17, uw)
	var sky := base_sky_color.lerp(Color(0.18, 0.5, 0.54), uw * 0.9)
	RenderingServer.global_shader_parameter_set("g_fog_color", fog)
	RenderingServer.global_shader_parameter_set("g_fog_density", fog_d)
	RenderingServer.global_shader_parameter_set("g_sky_color", sky)
	RenderingServer.global_shader_parameter_set("g_caustics", caustics)
	RenderingServer.global_shader_parameter_set("g_pixel_snap", 1.0 if pixel_snap else 0.0)
	if world.environment != null:
		world.environment.environment.background_color = sky
	if world.water_material != null:
		var m: ShaderMaterial = world.water_material
		m.set_shader_parameter("rain_amount", rain_amount)
		m.set_shader_parameter("clarity", clarity)
		m.set_shader_parameter("depth_dark", depth_dark)
		m.set_shader_parameter("refraction", refraction)
		m.set_shader_parameter("foam", foam)
		m.set_shader_parameter("flow", ripple_flow)
		var sun_vec: Vector3 = world.light.global_transform.basis.z
		m.set_shader_parameter("sun_xz", Vector2(sun_vec.x, sun_vec.z))
		m.set_shader_parameter("ripple_pos", fish_manager.ripple_pos)
		m.set_shader_parameter("ripple_birth", fish_manager.ripple_birth)
		m.set_shader_parameter("ripple_amp", fish_manager.ripple_amp)
		var fp := PackedVector2Array()
		var all_positions: Array[Vector3] = fish_manager.get_positions()
		for i in mini(all_positions.size(), 12):
			var fv: Vector3 = all_positions[i]
			fp.append(Vector2(fv.x, fv.z))
		while fp.size() < 12:
			fp.append(Vector2(999.0, 999.0))
		m.set_shader_parameter("fish_pos", fp)
		m.set_shader_parameter("fish_count", float(mini(all_positions.size(), 12)))
	if world.shaft_material != null:
		world.shaft_material.set_shader_parameter("intensity", 0.2 + underwater_amount * 0.22)
		world.shaft_material.set_shader_parameter("beam_color", base_sky_color.lerp(Color(0.78, 0.98, 0.96), 0.65))


func _update_hud_stats(delta: float) -> void:
	_fps_accum += delta
	if _fps_accum < 0.25:
		return
	_fps_accum = 0.0
	fps_value = Engine.get_frames_per_second()
	draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if draw_calls < 0:
		draw_calls = int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if hud != null:
		hud.refresh_stats()


# ── 参数接口 ───────────────────────────────────────────────────────────
func get_params() -> Dictionary:
	return {
		"internal_index": internal_index,
		"internal_label": INTERNAL_LABELS[internal_index],
		"rt_x": internal_size.x, "rt_y": internal_size.y,
		"display_scale": display_scale,
		"levels": levels, "dither": dither, "outline": outline,
		"palette": palette_on, "pixel_snap": pixel_snap,
		"clarity": clarity, "depth_dark": depth_dark, "refraction": refraction,
		"foam": foam, "caustics": caustics, "flow": ripple_flow,
		"fish_count": fish_count, "paused": paused,
		"auto_orbit": auto_orbit, "underwater": mode_underwater,
		"debug": debug_mode, "debug_name": DEBUG_NAMES[debug_mode],
		"time": time_of_day, "rain": weather_rain,
		"fps": fps_value, "draw_calls": draw_calls,
		"ui_visible": ui_visible,
	}


func set_param(key: String, value) -> void:
	match key:
		"internal_index":
			internal_index = clampi(int(value), 0, INTERNAL_OPTIONS.size() - 1)
			_apply_internal_resolution()
		"internal_res":
			set_param("internal_index", value)
		"levels":
			levels = clampf(float(value), 2.0, 20.0)
			_apply_post_params()
		"dither":
			dither = clampf(float(value), 0.0, 1.5)
			_apply_post_params()
		"outline":
			outline = clampf(float(value), 0.0, 2.5)
			_apply_post_params()
		"palette":
			palette_on = bool(value)
			_apply_post_params()
		"pixel_snap":
			pixel_snap = bool(value)
			RenderingServer.global_shader_parameter_set("g_pixel_snap", 1.0 if pixel_snap else 0.0)
		"clarity":
			clarity = clampf(float(value), 0.0, 1.0)
			_apply_water_params()
		"depth_dark":
			depth_dark = clampf(float(value), 0.0, 1.0)
			_apply_water_params()
		"refraction":
			refraction = clampf(float(value), 0.0, 1.5)
			_apply_water_params()
		"foam":
			foam = clampf(float(value), 0.0, 2.0)
			_apply_water_params()
		"caustics":
			caustics = clampf(float(value), 0.0, 2.0)
			RenderingServer.global_shader_parameter_set("g_caustics", caustics)
		"flow":
			ripple_flow = clampf(float(value), 0.0, 1.5)
			_apply_water_params()
		"fish_count":
			fish_count = clampi(int(value), 6, 36)
			fish_manager.set_fish_count(fish_count)
		"paused":
			paused = bool(value)
		"auto_orbit":
			auto_orbit = bool(value)
		"underwater":
			set_camera_mode("underwater" if bool(value) else "above")
		"debug":
			_set_debug_mode(int(value))
		"time":
			time_of_day = clampf(float(value), 0.0, 1.0)
			_apply_mood()
		"rain":
			weather_rain = bool(value)
			_apply_mood()
		"preset":
			var idx := clampi(int(value), 0, MOOD_PRESETS.size() - 1)
			var p: Dictionary = MOOD_PRESETS[idx]
			time_of_day = float(p["time"])
			weather_rain = bool(p["rain"])
			_apply_mood()
		"ui":
			_set_ui_visible(bool(value))
		"reset_view":
			_reset_view()
	_sync_hud()


func _set_ui_visible(value: bool) -> void:
	ui_visible = value
	if hud != null:
		hud.set_ui_visible(value)
	_sync_hud()


func _reset_view() -> void:
	mode_underwater = false
	target_yaw = deg_to_rad(26.0)
	target_pitch = deg_to_rad(62.0)
	target_dist = 16.0
	target_target = Vector3(0.0, 0.1, 0.0)
	auto_orbit = true
	_sync_hud()


func _sync_hud() -> void:
	if hud != null:
		hud.sync_from_main()


func set_camera_mode(mode: String) -> void:
	if mode == "underwater":
		mode_underwater = true
		target_pitch = deg_to_rad(-3.0)
		target_dist = 7.0
		target_target = Vector3(0.0, -0.2, -2.0)
		target_yaw = deg_to_rad(5.0)
	else:
		mode_underwater = false
		target_pitch = deg_to_rad(62.0)
		target_dist = 16.0
		target_target = Vector3(0.0, 0.1, 0.0)
		target_yaw = cam_yaw - 0.2
	_sync_hud()


func snap_camera() -> void:
	_update_camera_transform(1.0, true)


func apply_camera_view(yaw_deg: float, pitch_deg: float, dist: float, target: Vector3, underwater: bool) -> void:
	mode_underwater = underwater
	auto_orbit = false
	target_yaw = deg_to_rad(yaw_deg)
	target_pitch = deg_to_rad(pitch_deg)
	target_dist = dist
	target_target = target
	cam_yaw = target_yaw
	cam_pitch = target_pitch
	cam_dist = dist
	cam_target = target
	_update_camera_transform(1.0, true)
	underwater_amount = 1.0 if camera.global_position.y < -0.02 else 0.0
	RenderingServer.global_shader_parameter_set("g_underwater", underwater_amount)
	_update_world_uniforms(0.0)
	_sync_hud()


func prewarm_simulation(seconds: float) -> void:
	var step := 1.0 / 60.0
	var steps := int(seconds / step)
	for i in steps:
		rain_amount = move_toward(rain_amount, 1.0 if weather_rain else 0.0, step * 2.2)
		if not paused:
			anim_time += step
			fish_manager.update_fish(step, anim_time, true)
			fish_manager.update_rain(step, anim_time, rain_amount)
	RenderingServer.global_shader_parameter_set("g_time", anim_time)
	RenderingServer.global_shader_parameter_set("g_rain", rain_amount)
	_update_camera_transform(1.0, true)
	_update_world_uniforms(0.0)


func _set_debug_mode(mode: int) -> void:
	debug_mode = clampi(mode, 0, DEBUG_NAMES.size() - 1)
	if _debug_overrides_active:
		_restore_debug_overrides()
	if debug_mode == 2:
		_apply_debug_overrides(debug_depth_material)
	elif debug_mode == 3:
		_apply_debug_overrides(debug_normal_material)
	if post_material != null:
		post_material.set_shader_parameter("debug_mode", float(debug_mode))
	if world != null and world.water_material != null:
		world.water_material.set_shader_parameter("debug_mask", 1.0 if debug_mode == 5 else 0.0)
	_sync_hud()


func cycle_debug() -> void:
	_set_debug_mode((debug_mode + 1) % DEBUG_NAMES.size())


func _apply_debug_overrides(mat: ShaderMaterial) -> void:
	_debug_overrides_active = true
	_saved_overrides.clear()
	_hidden_nodes.clear()
	_debug_saved_env_bg = world.environment.environment.background_color
	world.environment.environment.background_color = Color(0.02, 0.035, 0.045)
	if world.water != null:
		world.water.visible = false
		_hidden_nodes.append(world.water)
	if world.shafts != null:
		world.shafts.visible = false
		_hidden_nodes.append(world.shafts)
	if world.decor != null:
		world.decor.visible = false
		_hidden_nodes.append(world.decor)
	for cp in world.bubble_emitters:
		cp.visible = false
		_hidden_nodes.append(cp)
	for f in fish_manager.fish:
		var hull: MeshInstance3D = f["hull"]
		if is_instance_valid(hull):
			hull.visible = false
			_hidden_nodes.append(hull)
	var stack: Array[Node] = [world_root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is GeometryInstance3D:
			var geo: GeometryInstance3D = node
			_saved_overrides.append({"node": geo, "mat": geo.material_override})
			geo.material_override = mat


func _restore_debug_overrides() -> void:
	_debug_overrides_active = false
	for item in _saved_overrides:
		var geo: GeometryInstance3D = item["node"]
		if is_instance_valid(geo):
			geo.material_override = item["mat"]
	_saved_overrides.clear()
	for node in _hidden_nodes:
		if is_instance_valid(node):
			node.visible = true
	_hidden_nodes.clear()
	if world != null and world.environment != null:
		world.environment.environment.background_color = _debug_saved_env_bg


# ── 输入 ───────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_last_mouse = mb.position
			if mb.pressed:
				auto_orbit = false
				_sync_hud()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_dist = clampf(target_dist * 0.92, 5.0, _max_zoom())
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_dist = clampf(target_dist * 1.08, 5.0, _max_zoom())
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		target_yaw -= mm.relative.x * 0.006
		var pitch_min := deg_to_rad(-30.0) if mode_underwater else deg_to_rad(18.0)
		var pitch_max := deg_to_rad(-0.5) if mode_underwater else deg_to_rad(82.0)
		target_pitch = clampf(target_pitch - mm.relative.y * 0.004, pitch_min, pitch_max)
		_last_mouse = mm.position
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				_set_ui_visible(not ui_visible)
			KEY_V:
				set_camera_mode("above" if mode_underwater else "underwater")
				_sync_hud()
			KEY_SPACE:
				paused = not paused
				_sync_hud()
			KEY_F1:
				cycle_debug()
			KEY_1:
				set_param("internal_index", 0)
			KEY_2:
				set_param("internal_index", 1)
			KEY_3:
				set_param("internal_index", 2)
			KEY_P:
				set_param("palette", not palette_on)
			KEY_T:
				var current := 0
				for i in MOOD_PRESETS.size():
					if is_equal_approx(time_of_day, float(MOOD_PRESETS[i]["time"])):
						current = i
				set_param("preset", (current + 1) % MOOD_PRESETS.size())
			KEY_G:
				set_param("auto_orbit", not auto_orbit)
			KEY_R:
				_reset_view()


# ── HUD 辅助 ───────────────────────────────────────────────────────────
func _max_zoom() -> float:
	return 14.0 if mode_underwater else 24.0


func get_fps() -> int:
	return fps_value


func get_draw_calls() -> int:
	return draw_calls


func get_internal_size() -> Vector2i:
	return internal_size


func get_display_scale() -> int:
	return display_scale


func get_underwater_amount() -> float:
	return underwater_amount


func get_debug_name() -> String:
	return DEBUG_NAMES[debug_mode]


func ui_hidden() -> bool:
	return not ui_visible


# ── 电影录制 / 截图工具接口 ─────────────────────────────────────────────
func _setup_movie_mode() -> void:
	_set_ui_visible(false)
	set_param("fish_count", 22)
	set_param("preset", 1)
	set_param("auto_orbit", false)
	target_yaw = deg_to_rad(18.0)
	target_pitch = deg_to_rad(64.0)
	target_dist = 17.0
	_movie_time = 0.0
	_movie_stage = 0


func _cinematic(delta: float) -> void:
	_movie_time += delta
	var t := _movie_time
	if t < 2.8:
		if _movie_stage != 0:
			_movie_stage = 0
		target_yaw = deg_to_rad(18.0 + 36.0 * (t / 2.8))
		target_pitch = deg_to_rad(lerpf(64.0, 55.0, t / 2.8))
		target_dist = lerpf(17.0, 14.0, t / 2.8)
		target_target = Vector3(0.0, 0.05, 0.0)
	elif t < 4.0:
		if _movie_stage != 1:
			_movie_stage = 1
		var k := (t - 2.8) / 1.2
		target_yaw = deg_to_rad(54.0 + 20.0 * k)
		target_pitch = deg_to_rad(lerpf(55.0, 33.0, k))
		target_dist = lerpf(14.0, 10.0, k)
		target_target = Vector3(-1.0, -0.15, 0.6)
	elif t < 7.2:
		if _movie_stage != 2:
			_movie_stage = 2
			mode_underwater = true
			target_target = Vector3(0.0, -0.2, -2.0)
			target_yaw = deg_to_rad(5.0)
		target_pitch = deg_to_rad(-3.0)
		target_dist = 7.0
		target_yaw = deg_to_rad(5.0 + (t - 4.0) * 7.0)
	elif t < 10.0:
		if _movie_stage != 3:
			_movie_stage = 3
			mode_underwater = false
			set_param("preset", 2)
			target_target = Vector3(0.0, 0.05, 0.0)
		var k2 := clampf((t - 7.2) / 2.8, 0.0, 1.0)
		target_yaw = deg_to_rad(96.0 + 16.0 * k2)
		target_pitch = deg_to_rad(lerpf(58.0, 50.0, k2))
		target_dist = lerpf(15.0, 13.0, k2)


func capture_layout() -> Dictionary:
	return {
		"scale": display_scale,
		"rect": screen_rect.get_global_rect(),
		"internal": internal_size,
		"window": get_viewport().get_visible_rect().size,
	}
