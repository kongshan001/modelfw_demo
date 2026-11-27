extends Node3D

# 主控：组装石盆、相机、调色/暗角层和中文 HUD；统一驱动参数、变体、
# 调试视图与时间。Voronoi 核心全部在 shader 中，本脚本只做接线。

const POOL_LINE := Color(0.58, 0.98, 0.97, 1.0)
const POOL_GLOW := Color(0.025, 0.52, 0.64, 1.0)
const LAVA_LINE := Color(1.0, 0.76, 0.38, 1.0)
const LAVA_GLOW := Color(1.0, 0.24, 0.055, 1.0)

const DEFAULT_PARAMS := {
	"scale": 0.72,
	"width": 0.050,
	"softness": 0.95,
	"brightness": 1.00,
	"speed": 0.46,
	"flow": -31.0,
}
const PARAM_UNIFORMS := {
	"scale": "u_scale",
	"width": "u_width",
	"softness": "u_softness",
	"brightness": "u_brightness",
	"speed": "u_speed",
	"flow": "u_flow_angle",
}

var params: Dictionary = DEFAULT_PARAMS.duplicate()
var variant := 0
var debug_mode := 0
var search_3x3 := true
var warp_on := true
var junction_on := true
var gather_on := true
var soft_on := true
var surface_on := true
var paused := false
var time_value := 0.0
var ui_visible := true
var caption := ""

var world
var camera_rig
var hud
var environment: Environment
var _postfx: CanvasLayer
var _vignette: ColorRect
var _focus_strength := 0.0
var _focus_pos := Vector2.ZERO
var _toggles := {
	"warp": 0.96,
	"junction": 1.42,
	"gather": 0.94,
	"soft": 0.95,
}

@onready var _hud = $HUD


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	hud = _hud
	_build_environment()
	_build_world()
	_build_camera()
	_build_postfx()
	hud.setup(self)
	_apply_variant_preset(false)
	_sync_uniforms()
	hud.sync_from_main()
	print("POOL_CAUSTICS_READY build_ms=%d params=%d" % [
			Time.get_ticks_msec() - t0, params.size()])
	print("POOL_CAUSTICS_CORE shader=caustics.gdshaderinc search=3x3 f1_f2=1 domain_warp=1")


func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.005, 0.030, 0.043)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.18, 0.36, 0.35)
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = environment
	add_child(we)


func _build_world() -> void:
	world = Node3D.new()
	world.name = "PoolWorld"
	world.set_script(load("res://scripts/pool_world.gd"))
	add_child(world)
	world.build()


func _build_camera() -> void:
	camera_rig = Camera3D.new()
	camera_rig.name = "PoolCamera"
	camera_rig.set_script(load("res://scripts/pool_camera.gd"))
	add_child(camera_rig)


func _build_postfx() -> void:
	_postfx = CanvasLayer.new()
	_postfx.name = "Grade"
	_postfx.layer = 5
	add_child(_postfx)
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/vignette.gdshader")
	mat.set_shader_parameter("u_amount", 0.72)
	_vignette.material = mat
	_postfx.add_child(_vignette)


func _process(delta: float) -> void:
	if not paused:
		time_value += delta
	if _focus_strength > 0.0001:
		_focus_strength = maxf(0.0, _focus_strength - delta * 0.32)
		world.set_shared_param("u_focus", Vector4(_focus_pos.x, _focus_pos.y,
				0.0, _focus_strength))
	world.set_time(time_value)
	if hud != null:
		hud.tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var hit: Variant = camera_rig.call("screen_to_floor", mb.position)
			if hit != null:
				var p: Vector3 = hit
				_focus_pos = Vector2(p.x, p.z)
				_focus_strength = 1.0
				world.set_shared_param("u_focus", Vector4(p.x, p.z, 0.0, 1.0))
				hud.show_toast("聚光 · %.1f, %.1f" % [p.x, p.z])
				return
	elif event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return
		match key.keycode:
			KEY_1:
				set_variant(0)
			KEY_2:
				set_variant(1)
			KEY_K:
				set_search_3x3(not search_3x3)
			KEY_D:
				set_debug_mode((debug_mode + 1) % 7)
			KEY_G:
				set_debug_mode(5)
			KEY_W:
				set_toggle("warp", not warp_on)
			KEY_B:
				set_toggle("junction", not junction_on)
			KEY_J:
				set_toggle("gather", not gather_on)
			KEY_L:
				set_toggle("soft", not soft_on)
			KEY_U:
				set_toggle("surface", not surface_on)
			KEY_SPACE:
				paused = not paused
				hud.sync_from_main()
			KEY_R:
				reset_all()
			KEY_H:
				set_ui_visible(not ui_visible)
			KEY_TAB:
				hud.call("toggle_panel")
				ui_visible = true
				hud.set_ui_visible(true)
			KEY_O:
				camera_rig.set("auto_orbit", not bool(camera_rig.get("auto_orbit")))
				hud.sync_from_main()


func toggle_pause() -> void:
	paused = not paused
	if hud != null:
		hud.sync_from_main()


func set_param(key: String, value: float) -> void:
	if not DEFAULT_PARAMS.has(key):
		return
	params[key] = value
	world.set_shared_param(PARAM_UNIFORMS[key], value)
	hud.sync_from_main()


func set_search_3x3(value: bool) -> void:
	search_3x3 = value
	world.set_shared_param("u_search_3x3", 1.0 if value else 0.0)
	hud.sync_from_main()


func set_debug_mode(value: int) -> void:
	debug_mode = clampi(value, 0, 6)
	world.set_shared_param("u_debug", debug_mode)
	_update_veil_visibility()
	if _vignette != null:
		var mat := _vignette.material as ShaderMaterial
		mat.set_shader_parameter("u_amount", 0.70 if debug_mode == 0 else 0.34)
	hud.sync_from_main()


func set_toggle(name: String, value: bool) -> void:
	match name:
		"warp":
			warp_on = value
			world.set_shared_param("u_warp_amount", _toggles["warp"] if value else 0.0)
		"junction":
			junction_on = value
			world.set_shared_param("u_junction", _toggles["junction"] if value else 0.0)
		"gather":
			gather_on = value
			world.set_shared_param("u_gather", _toggles["gather"] if value else 0.0)
		"soft":
			soft_on = value
			world.set_shared_param("u_soft_light", _toggles["soft"] if value else 0.0)
		"surface":
			surface_on = value
			_update_veil_visibility()
		"auto_orbit":
			camera_rig.set("auto_orbit", value)
		_:
			return
	hud.sync_from_main()


func set_variant(value: int) -> void:
	variant = clampi(value, 0, 1)
	_apply_variant_preset(true)
	if hud != null:
		hud.sync_from_main()


func _apply_variant_preset(update_ui: bool) -> void:
	if variant == 0:
		params = DEFAULT_PARAMS.duplicate()
		_toggles = {"warp": 0.96, "junction": 1.42, "gather": 0.94, "soft": 0.95}
		world.set_shared_param("u_style", 0.0)
		world.set_shared_param("u_gap_threshold", 0.0)
		world.set_shared_param("u_line_color", POOL_LINE)
		world.set_shared_param("u_glow_color", POOL_GLOW)
		environment.background_color = Color(0.005, 0.030, 0.043)
		environment.ambient_light_color = Color(0.18, 0.36, 0.35)
		world.floor_material.set_shader_parameter("u_floor_tint", Color(0.50, 0.72, 0.74))
		world.floor_material.set_shader_parameter("u_deep_tint", Color(0.004, 0.036, 0.043))
		var hero: ShaderMaterial = world.rock_materials[0]
		hero.set_shader_parameter("u_rock_light", Color(0.33, 0.46, 0.45))
		hero.set_shader_parameter("u_rock_dark", Color(0.016, 0.050, 0.048))
		hero.set_shader_parameter("u_moss_color", Color(0.18, 0.30, 0.17))
		hero.set_shader_parameter("u_moss_amount", 0.68)
		hero.set_shader_parameter("u_wet_spec", 0.42)
		var rim: ShaderMaterial = world.rock_materials[1]
		rim.set_shader_parameter("u_rock_light", Color(0.19, 0.30, 0.27))
		rim.set_shader_parameter("u_rock_dark", Color(0.012, 0.036, 0.039))
		rim.set_shader_parameter("u_moss_color", Color(0.18, 0.29, 0.18))
		rim.set_shader_parameter("u_moss_amount", 0.44)
		rim.set_shader_parameter("u_caustic_amount", 0.22)
		rim.set_shader_parameter("u_wet_spec", 0.12)
		world.water_material.set_shader_parameter("u_color", Color(0.32, 0.82, 0.90))
		world.water_material.set_shader_parameter("u_amount", 0.85)
		surface_on = true
	else:
		params = {
			"scale": 1.10,
			"width": 0.060,
			"softness": 0.88,
			"brightness": 1.55,
			"speed": 0.33,
			"flow": 22.0,
		}
		_toggles = {"warp": 0.42, "junction": 1.0, "gather": 0.33, "soft": 0.92}
		world.set_shared_param("u_style", 1.0)
		world.set_shared_param("u_gap_threshold", 0.0035)
		world.set_shared_param("u_line_color", LAVA_LINE)
		world.set_shared_param("u_glow_color", LAVA_GLOW)
		environment.background_color = Color(0.025, 0.009, 0.007)
		environment.ambient_light_color = Color(0.35, 0.12, 0.06)
		world.floor_material.set_shader_parameter("u_floor_tint", Color(0.30, 0.22, 0.18))
		world.floor_material.set_shader_parameter("u_deep_tint", Color(0.020, 0.008, 0.005))
		var hero: ShaderMaterial = world.rock_materials[0]
		hero.set_shader_parameter("u_rock_light", Color(0.17, 0.105, 0.085))
		hero.set_shader_parameter("u_rock_dark", Color(0.022, 0.013, 0.012))
		hero.set_shader_parameter("u_moss_color", Color(0.17, 0.09, 0.05))
		hero.set_shader_parameter("u_moss_amount", 0.18)
		hero.set_shader_parameter("u_wet_spec", 0.08)
		var rim: ShaderMaterial = world.rock_materials[1]
		rim.set_shader_parameter("u_rock_light", Color(0.105, 0.065, 0.055))
		rim.set_shader_parameter("u_rock_dark", Color(0.015, 0.008, 0.007))
		rim.set_shader_parameter("u_moss_color", Color(0.12, 0.065, 0.035))
		rim.set_shader_parameter("u_moss_amount", 0.10)
		rim.set_shader_parameter("u_caustic_amount", 0.8)
		rim.set_shader_parameter("u_wet_spec", 0.03)
		surface_on = false
	# 恢复各个开关的强度（变体预设会重置强度）。
	for key in PARAM_UNIFORMS:
		world.set_shared_param(PARAM_UNIFORMS[key], params[key])
	world.set_shared_param("u_warp_amount", _toggles["warp"] if warp_on else 0.0)
	world.set_shared_param("u_junction", _toggles["junction"] if junction_on else 0.0)
	world.set_shared_param("u_gather", _toggles["gather"] if gather_on else 0.0)
	world.set_shared_param("u_soft_light", _toggles["soft"] if soft_on else 0.0)
	_update_veil_visibility()
	if update_ui and hud != null:
		hud.sync_from_main()


func _update_veil_visibility() -> void:
	if world == null:
		return
	world.water_veil.visible = surface_on and debug_mode == 0


func set_line_color(c: Color) -> void:
	world.set_shared_param("u_line_color", c.lightened(0.18))
	world.set_shared_param("u_glow_color", c.darkened(0.18))
	if hud != null:
		hud.sync_from_main()


func set_time_override(value: float) -> void:
	time_value = value
	world.set_time(time_value)


func reset_all() -> void:
	variant = 0
	debug_mode = 0
	search_3x3 = true
	warp_on = true
	junction_on = true
	gather_on = true
	soft_on = true
	surface_on = true
	paused = false
	_focus_strength = 0.0
	world.set_shared_param("u_focus", Vector4.ZERO)
	world.set_shared_param("u_debug", 0)
	world.set_shared_param("u_search_3x3", 1.0)
	camera_rig.call("reset_pose")
	_apply_variant_preset(false)
	if _vignette != null:
		(_vignette.material as ShaderMaterial).set_shader_parameter("u_amount", 0.70)
	hud.sync_from_main()
	set_ui_visible(true)


func set_ui_visible(value: bool) -> void:
	ui_visible = value
	hud.set_ui_visible(value)


func sync_ui() -> void:
	if hud != null:
		hud.sync_from_main()


func _sync_uniforms() -> void:
	for key in params:
		world.set_shared_param(PARAM_UNIFORMS[key], params[key])
	world.set_shared_param("u_warp_amount", _toggles["warp"])
	world.set_shared_param("u_junction", _toggles["junction"])
	world.set_shared_param("u_gather", _toggles["gather"])
	world.set_shared_param("u_soft_light", _toggles["soft"])
	world.set_shared_param("u_search_3x3", 1.0 if search_3x3 else 0.0)
	world.set_shared_param("u_debug", debug_mode)


func get_state() -> Dictionary:
	return {
		"variant": variant,
		"debug": debug_mode,
		"search_3x3": search_3x3,
		"warp": warp_on,
		"junction": junction_on,
		"gather": gather_on,
		"soft": soft_on,
		"surface": surface_on,
		"paused": paused,
		"ui": ui_visible,
		"time": time_value,
		"focus": _focus_strength,
		"params": params.duplicate(),
		"camera_auto": bool(camera_rig.get("auto_orbit")),
	}


func get_pool_world() -> Node3D:
	return world


func get_pool_camera() -> Camera3D:
	return camera_rig


func get_hud() -> CanvasLayer:
	return hud
