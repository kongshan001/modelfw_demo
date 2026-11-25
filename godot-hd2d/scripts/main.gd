class_name HD2DMain
extends Node2D

# 主控：相机 → 世界 → 氛围层 → 移轴后处理 → HUD。
# 逻辑分辨率 1280×720；世界按 640×360 美术坐标绘制，用整数倍 Camera2D zoom 放大。

const WORLD_W := 640.0
const WORLD_H := 360.0
const BASE_H := 720.0
const ATMOS_LAYER := 2
const POST_LAYER := 10
const HUD_LAYER := 20

const DEFAULTS := {
	"focus_y": 0.60,
	"band_half": 0.14,
	"feather": 0.20,
	"strength": 1.1,
	"radius": 17.0,
	"light_angle": -38.0,
	"light_energy": 0.75,
	"warmth": 0.35,
	"night": false,
	"post_enabled": true,
}

var world: HD2DWorld
var camera: Camera2D
var post_layer: CanvasLayer
var post_rect: ColorRect
var post_mat: ShaderMaterial
var atmosphere: CanvasLayer
var atmos_mat: ShaderMaterial
var hud
var backbuffer: BackBufferCopy

var focus_y := 0.60
var band_half := 0.14
var feather := 0.20
var strength := 1.1
var radius := 17.0
var light_angle := -38.0
var light_energy := 0.75
var warmth := 0.35
var night := false
var post_enabled := true
var paused := false
var ui_visible := true

var pixel_scale := 2.0
var ui_scale := 1.0
var _stats_clock := 0.0
var _booted := false


func _ready() -> void:
	get_viewport().snap_2d_transforms_to_pixel = true
	get_viewport().snap_2d_vertices_to_pixel = true
	_compute_scales()
	_build_camera()
	_build_world()
	_build_atmosphere()
	_build_post()
	_build_hud()
	_apply_post()
	_apply_light()
	_booted = true
	set_process(true)


func _process(delta: float) -> void:
	if not _booted:
		return
	_stats_clock += delta
	if _stats_clock >= 0.25:
		_stats_clock = 0.0
		if hud != null and is_instance_valid(hud):
			var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
			hud.update_stats(Engine.get_frames_per_second(), draws,
					Vector2i(get_viewport_rect().size))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_B:
			set_post_enabled(not post_enabled)
		KEY_SPACE:
			set_paused(not paused)
		KEY_N:
			set_night(not night)
		KEY_H:
			set_ui_visible(not ui_visible)
		KEY_R:
			reset_params()
		KEY_1:
			apply_preset("morning")
		KEY_2:
			apply_preset("dusk")
		KEY_3:
			apply_preset("night")
		_:
			return
	get_viewport().set_input_as_handled()


func _compute_scales() -> void:
	var vs := get_viewport_rect().size
	pixel_scale = maxf(1.0, vs.y / WORLD_H)
	ui_scale = maxf(0.75, vs.y / BASE_H)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(WORLD_W * 0.5, WORLD_H * 0.5)
	camera.zoom = Vector2(pixel_scale, pixel_scale)
	camera.enabled = true
	camera.position_smoothing_enabled = false
	add_child(camera)


func _build_world() -> void:
	world = HD2DWorld.new()
	world.name = "World"
	add_child(world)


func _build_atmosphere() -> void:
	atmosphere = CanvasLayer.new()
	atmosphere.name = "Atmosphere"
	atmosphere.layer = ATMOS_LAYER
	add_child(atmosphere)
	var rect := ColorRect.new()
	rect.name = "AtmosphereRect"
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmosphere.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	atmos_mat = ShaderMaterial.new()
	atmos_mat.shader = load("res://shaders/atmosphere.gdshader")
	rect.material = atmos_mat


func _build_post() -> void:
	post_layer = CanvasLayer.new()
	post_layer.name = "TiltShiftLayer"
	post_layer.layer = POST_LAYER
	add_child(post_layer)
	backbuffer = BackBufferCopy.new()
	backbuffer.name = "BackBufferCopy"
	backbuffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	post_layer.add_child(backbuffer)
	post_rect = ColorRect.new()
	post_rect.name = "TiltShift"
	post_rect.color = Color.WHITE
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(post_rect)
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/tilt_shift.gdshader")
	post_rect.material = post_mat


func _build_hud() -> void:
	var script = load("res://scripts/hud.gd")
	hud = script.new()
	hud.name = "HUD"
	hud.layer = HUD_LAYER
	add_child(hud)
	hud.build(self, ui_scale)


func _apply_post() -> void:
	if post_mat == null:
		return
	post_mat.set_shader_parameter("focus_y", focus_y)
	post_mat.set_shader_parameter("band_half", band_half)
	post_mat.set_shader_parameter("feather", feather)
	post_mat.set_shader_parameter("strength", strength)
	post_mat.set_shader_parameter("radius_px", radius)
	post_mat.set_shader_parameter("post_enabled", post_enabled)
	post_mat.set_shader_parameter("screen_size", get_viewport_rect().size)
	post_rect.visible = post_enabled
	if hud != null and is_instance_valid(hud):
		hud.sync_from_main()


func _apply_light() -> void:
	if world != null:
		world.set_environment(night, warmth, light_angle, light_energy)
	if atmos_mat != null:
		atmos_mat.set_shader_parameter("night", 1.0 if night else 0.0)
		atmos_mat.set_shader_parameter("warmth", warmth)
	if hud != null and is_instance_valid(hud):
		hud.sync_from_main()


func set_focus_y(value: float) -> void:
	focus_y = clampf(value, 0.0, 1.0)
	_apply_post()


func set_band_half(value: float) -> void:
	band_half = clampf(value, 0.01, 0.49)
	_apply_post()


func set_feather(value: float) -> void:
	feather = clampf(value, 0.005, 0.5)
	_apply_post()


func set_strength(value: float) -> void:
	strength = clampf(value, 0.0, 1.5)
	_apply_post()


func set_radius(value: float) -> void:
	radius = clampf(value, 0.0, 48.0)
	_apply_post()


func set_light_angle(value: float) -> void:
	light_angle = value
	_apply_light()


func set_light_energy(value: float) -> void:
	light_energy = clampf(value, 0.0, 3.0)
	_apply_light()


func set_warmth(value: float) -> void:
	warmth = clampf(value, -1.0, 1.0)
	_apply_light()


func set_night(value: bool) -> void:
	night = value
	_apply_light()


func set_post_enabled(value: bool) -> void:
	post_enabled = value
	_apply_post()


func set_paused(value: bool) -> void:
	paused = value
	if world != null:
		world.set_paused(value)
	if hud != null and is_instance_valid(hud):
		hud.sync_from_main()


func set_ui_visible(value: bool) -> void:
	ui_visible = value
	if hud != null and is_instance_valid(hud):
		hud.visible = value


func reset_params() -> void:
	focus_y = float(DEFAULTS.focus_y)
	band_half = float(DEFAULTS.band_half)
	feather = float(DEFAULTS.feather)
	strength = float(DEFAULTS.strength)
	radius = float(DEFAULTS.radius)
	light_angle = float(DEFAULTS.light_angle)
	light_energy = float(DEFAULTS.light_energy)
	warmth = float(DEFAULTS.warmth)
	night = bool(DEFAULTS.night)
	post_enabled = bool(DEFAULTS.post_enabled)
	paused = false
	world.set_paused(false)
	_apply_post()
	_apply_light()


func apply_preset(preset: String) -> void:
	match preset:
		"morning":
			night = false
			warmth = 0.35
			light_angle = -38.0
			light_energy = 0.75
			focus_y = 0.60
			band_half = 0.14
			strength = 1.1
			radius = 17.0
		"dusk":
			night = false
			warmth = 1.0
			light_angle = -8.0
			light_energy = 0.7
			focus_y = 0.56
			band_half = 0.13
			strength = 1.15
			radius = 18.0
		"night":
			night = true
			warmth = 0.12
			light_angle = -22.0
			light_energy = 1.2
			focus_y = 0.62
			band_half = 0.14
			strength = 1.15
			radius = 17.0
		_:
			return
	_apply_post()
	_apply_light()


# 与 tilt_shift.gdshader 中 band_weight() 完全一致的 CPU 版本，供 smoke/调参。
func sample_band_weight(y: float) -> float:
	var d := maxf(absf(y - focus_y) - band_half, 0.0)
	return smoothstep(0.0, feather, d)


func api_snapshot() -> Dictionary:
	return {
		"focus_y": focus_y,
		"band_half": band_half,
		"feather": feather,
		"strength": strength,
		"radius": radius,
		"light_angle": light_angle,
		"light_energy": light_energy,
		"warmth": warmth,
		"night": night,
		"post_enabled": post_enabled,
		"paused": paused,
		"ui_visible": ui_visible,
		"pixel_scale": pixel_scale,
		"ui_scale": ui_scale,
		"post_layer": POST_LAYER,
		"hud_layer": HUD_LAYER,
	}
