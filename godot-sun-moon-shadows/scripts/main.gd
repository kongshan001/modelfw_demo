extends Node

# 主控：0–24h 时间、暂停/倍速、3 个全局 shader 向量、世界与 HUD 接线。
# 世界是 640×360 像素画布，按整数倍最近邻放到 1280×720 / 1920×1080 窗口。

const DESIGN := Vector2(640.0, 360.0)
const DEFAULT_HOUR := 8.0
const DEFAULT_SPEED := 16.0
const BASE_HOURS_PER_SECOND := 0.02
const SPEEDS: Array[float] = [1.0, 4.0, 16.0, 64.0]

var hour := DEFAULT_HOUR
var world: SunMoonWorld
var hud: SunMoonHUD
var _playing := true
var _speed := DEFAULT_SPEED
var _shadows_enabled := true
var _soft_knee := true
var _lamps_enabled := true
var _debug_enabled := false
var _ui_visible := true
var _solar: Dictionary = {}
var _global_uniforms: Dictionary = {}
var _time := 0.0
var _pixel_scale := 2

@onready var world_viewport: SubViewport = $WorldViewport
@onready var display: TextureRect = $WorldDisplay
@onready var background: ColorRect = $Backdrop
@onready var hud_layer: CanvasLayer = $HUD


func _ready() -> void:
	world = $WorldViewport/World as SunMoonWorld
	hud = hud_layer as SunMoonHUD
	display.texture = world_viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()
	_apply_light()
	hud.setup(self)
	hud.sync_from_main()
	print("SUN_MOON_SHADOWS_READY hour=%.2f speed=%d viewport=%s scale=%d" % [
		hour, int(_speed), str(get_viewport().get_visible_rect().size), _pixel_scale])


func _process(delta: float) -> void:
	_time += delta
	if _playing:
		_step_time(delta)
		_apply_light()


func _step_time(delta: float) -> void:
	hour = fposmod(hour + delta * _speed * BASE_HOURS_PER_SECOND, 24.0)


func simulate_time(seconds: float) -> void:
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		_time += dt
		if _playing:
			_step_time(dt)
		left -= dt
	_apply_light()


func _apply_light() -> void:
	_solar = LightModel.state(hour, _soft_knee)
	var light_dir: Vector2 = _solar["light_dir"]
	var elevation01 := clampf(float(_solar["elevation"]) / 90.0, 0.0, 1.0)
	var night := float(_solar["night"])
	var light_color: Color = _solar["light_color"]
	var intensity := float(_solar["intensity"])
	var shadow_color: Color = _solar["shadow_color"]
	var shadow_alpha := float(_solar["shadow_alpha"])
	var u_dir := Vector4(light_dir.x, light_dir.y, elevation01, night)
	var u_color := Color(light_color.r, light_color.g, light_color.b, intensity)
	var u_amb := Color(shadow_color.r, shadow_color.g, shadow_color.b, shadow_alpha)
	_global_uniforms["u_light_dir"] = u_dir
	_global_uniforms["u_light_color"] = u_color
	_global_uniforms["u_ambient_sub"] = u_amb
	RenderingServer.global_shader_parameter_set("u_light_dir", u_dir)
	RenderingServer.global_shader_parameter_set("u_light_color", u_color)
	RenderingServer.global_shader_parameter_set("u_ambient_sub", u_amb)
	if world != null:
		world.apply_light(_solar, _shadows_enabled, _soft_knee, _lamps_enabled)


func _apply_scale() -> void:
	var vp := get_viewport().get_visible_rect().size
	var scale := maxi(1, int(floor(minf(vp.x / DESIGN.x, vp.y / DESIGN.y))))
	_pixel_scale = scale
	var content := Vector2(DESIGN.x * scale, DESIGN.y * scale)
	var origin := ((vp - content) * 0.5).floor()
	if display != null:
		display.position = origin
		display.size = content
	if hud_layer != null:
		hud_layer.scale = Vector2(scale, scale)
		hud_layer.offset = origin


# ── 参数入口 ─────────────────────────────────────────────────────────────
func set_hour(value: float) -> void:
	hour = fposmod(value, 24.0)
	_apply_light()


func set_playing(value: bool) -> void:
	_playing = value


func set_speed(value: float) -> void:
	_speed = clampf(value, 1.0, 64.0)


func set_shadows_enabled(value: bool) -> void:
	_shadows_enabled = value
	if world != null:
		world.apply_light(_solar, _shadows_enabled, _soft_knee, _lamps_enabled)


func set_soft_knee(value: bool) -> void:
	_soft_knee = value
	_apply_light()


func set_lamps_enabled(value: bool) -> void:
	_lamps_enabled = value
	if world != null:
		world.apply_light(_solar, _shadows_enabled, _soft_knee, _lamps_enabled)


func set_debug_enabled(value: bool) -> void:
	_debug_enabled = value
	if not value:
		for flag in SunMoonWorld.DEBUG_FLAGS:
			world.set_debug_flag(flag, false)
	hud.set_debug_visible(value)
	hud.sync_from_main()


func toggle_debug() -> void:
	set_debug_enabled(not _debug_enabled)


func set_debug_flag(flag: String, value: bool) -> void:
	if value and not _debug_enabled:
		_debug_enabled = true
		hud.set_debug_visible(true)
	world.set_debug_flag(flag, value)
	if flag == "overlap" and value:
		world.refresh_overlap_probe()
	hud.sync_from_main()


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	hud.set_ui_visible(value)


func toggle_ui() -> void:
	set_ui_visible(not _ui_visible)


func reset() -> void:
	hour = DEFAULT_HOUR
	_playing = true
	_speed = DEFAULT_SPEED
	_shadows_enabled = true
	_soft_knee = true
	_lamps_enabled = true
	_debug_enabled = false
	for flag in SunMoonWorld.DEBUG_FLAGS:
		world.set_debug_flag(flag, false)
	hud.set_debug_visible(false)
	hud.sync_from_main()
	_apply_light()


# ── 查询 / 测试接口 ──────────────────────────────────────────────────────
func get_hour() -> float:
	return hour


func get_phase() -> String:
	return String(_solar.get("phase", ""))


func get_solar() -> Dictionary:
	return _solar.duplicate(true)


func get_global_uniform(uniform_name: String) -> Variant:
	return _global_uniforms.get(uniform_name, null)


func get_world() -> SunMoonWorld:
	return world


func get_hud() -> SunMoonHUD:
	return hud


func is_playing() -> bool:
	return _playing


func get_speed() -> float:
	return _speed


func are_shadows_enabled() -> bool:
	return _shadows_enabled


func is_soft_knee() -> bool:
	return _soft_knee


func are_lamps_enabled() -> bool:
	return _lamps_enabled


func is_debug_enabled() -> bool:
	return _debug_enabled


func is_ui_visible() -> bool:
	return _ui_visible


func get_pixel_scale() -> int:
	return _pixel_scale


func get_fps() -> int:
	return int(Engine.get_frames_per_second())


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func get_world_viewport() -> SubViewport:
	return world_viewport


# ── 键盘 ─────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			set_playing(not _playing)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_R:
			reset()
			get_viewport().set_input_as_handled()
		KEY_H:
			toggle_ui()
			get_viewport().set_input_as_handled()
		KEY_S:
			set_shadows_enabled(not _shadows_enabled)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_K:
			set_soft_knee(not _soft_knee)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_L:
			set_lamps_enabled(not _lamps_enabled)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_F3:
			toggle_debug()
			get_viewport().set_input_as_handled()
		KEY_G:
			set_debug_flag("heightmap", not world.is_debug_flag("heightmap"))
			get_viewport().set_input_as_handled()
		KEY_O:
			set_debug_flag("occlusion", not world.is_debug_flag("occlusion"))
			get_viewport().set_input_as_handled()
		KEY_B:
			set_debug_flag("mesh", not world.is_debug_flag("mesh"))
			get_viewport().set_input_as_handled()
		KEY_V:
			set_debug_flag("overlap", not world.is_debug_flag("overlap"))
			get_viewport().set_input_as_handled()
		KEY_1:
			set_playing(false)
			set_hour(12.0)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_2:
			set_playing(false)
			set_hour(18.3333)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_3:
			set_playing(false)
			set_hour(21.0)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_4:
			set_playing(false)
			set_hour(0.5)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
