extends Node

# 主控：时间（08:00–17:00，90s 走完一轮）、太阳模型、全局 shader uniform、
# 世界与 HUD 接线、键盘快捷键。花瓣照常飘落；暂停只冻结时间/日照。

const LOOP_SECONDS := 90.0
const UI_DESIGN := Vector2(1280.0, 720.0)
const DEFAULT_HOUR := SunModel.DAY_START_HOUR

var world: SakuraWorld
var hour := DEFAULT_HOUR
var _playing := true
var _speed := 1.0
var _shadows_enabled := true
var _debug_enabled := false
var _petals_enabled := true
var _ui_visible := true
var _solar: Dictionary = {}
var _hero_shadow_report: Dictionary = {}
var _global_uniforms: Dictionary = {}
var _time := 0.0

@onready var world_node: Node = $WorldViewport/World
@onready var hud = $HUD
@onready var display: TextureRect = $WorldDisplay


func _ready() -> void:
	world = world_node as SakuraWorld
	display.texture = $WorldViewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_ui_scale()
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_solar()
	hud.setup(self)
	print("SAKURA_SUNLIGHT_READY hour=%.2f viewport=%s" % [
		hour, str(get_viewport().get_visible_rect().size)])


func _process(delta: float) -> void:
	_time += delta
	_step_time(delta)
	if _petals_enabled:
		world.step_petals(delta)
	_global_uniforms["u_time"] = _time
	RenderingServer.global_shader_parameter_set("u_time", _time)


func _step_time(delta: float) -> void:
	if not _playing:
		return
	var span := SunModel.DAY_END_HOUR - SunModel.DAY_START_HOUR
	hour += delta * _speed * span / LOOP_SECONDS
	if hour >= SunModel.DAY_END_HOUR:
		hour = SunModel.DAY_START_HOUR \
				+ fposmod(hour - SunModel.DAY_START_HOUR, span)
	_apply_solar()


func simulate_time(seconds: float) -> void:
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		_time += dt
		_step_time(dt)
		if _petals_enabled:
			world.step_petals(dt)
		left -= dt


func simulate_petals(seconds: float) -> void:
	world.simulate_petals(seconds)


func _apply_solar() -> void:
	_solar = SunModel.state(hour, SunModel.DEFAULT_MAX_SHADOW_MULTIPLE)
	_global_uniforms["u_sun_dir"] = _solar["sun_dir"]
	_global_uniforms["u_sun_elevation"] = _solar["elevation"]
	_global_uniforms["u_sun_color"] = _solar["sun_color"]
	_global_uniforms["u_ambient_color"] = _solar["ambient_color"]
	_global_uniforms["u_shadow_color"] = _solar["shadow_color"]
	_global_uniforms["u_sun_intensity"] = _solar["sun_intensity"]
	_global_uniforms["u_shadow_strength"] = 1.0 if _shadows_enabled else 0.0
	_global_uniforms["u_time"] = _time
	RenderingServer.global_shader_parameter_set("u_sun_dir", _global_uniforms["u_sun_dir"])
	RenderingServer.global_shader_parameter_set("u_sun_elevation", _global_uniforms["u_sun_elevation"])
	RenderingServer.global_shader_parameter_set("u_sun_color", _global_uniforms["u_sun_color"])
	RenderingServer.global_shader_parameter_set("u_ambient_color", _global_uniforms["u_ambient_color"])
	RenderingServer.global_shader_parameter_set("u_shadow_color", _global_uniforms["u_shadow_color"])
	RenderingServer.global_shader_parameter_set("u_sun_intensity", _global_uniforms["u_sun_intensity"])
	RenderingServer.global_shader_parameter_set("u_shadow_strength", _global_uniforms["u_shadow_strength"])
	RenderingServer.global_shader_parameter_set("u_time", _global_uniforms["u_time"])
	if world != null:
		world.apply_solar(_solar, _shadows_enabled)
		var hero := world.get_hero_shadow()
		_hero_shadow_report = hero.get_report() if hero != null else {}


func _apply_ui_scale() -> void:
	if hud == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var ratio := minf(vp.x / UI_DESIGN.x, vp.y / UI_DESIGN.y)
	hud.scale = Vector2(ratio, ratio)


# ── 参数入口（HUD / 工具 / 测试共用） ─────────────────────────────────────
func set_hour(value: float) -> void:
	hour = clampf(value, SunModel.DAY_START_HOUR, SunModel.DAY_END_HOUR)
	_apply_solar()


func set_playing(value: bool) -> void:
	_playing = value


func set_speed(value: float) -> void:
	_speed = clampf(value, 0.5, 4.0)


func set_shadows_enabled(value: bool) -> void:
	_shadows_enabled = value
	world.set_shadows_enabled(value)
	_global_uniforms["u_shadow_strength"] = 1.0 if value else 0.0
	RenderingServer.global_shader_parameter_set("u_shadow_strength",
			_global_uniforms["u_shadow_strength"])


func set_debug_enabled(value: bool) -> void:
	_debug_enabled = value
	world.set_debug_enabled(value)


func set_petals_enabled(value: bool) -> void:
	_petals_enabled = value
	world.set_petals_enabled(value)


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	hud.set_ui_visible(value)


func toggle_ui() -> void:
	set_ui_visible(not _ui_visible)


func reset() -> void:
	hour = DEFAULT_HOUR
	_playing = true
	_speed = 1.0
	_shadows_enabled = true
	_debug_enabled = false
	_petals_enabled = true
	world.set_shadows_enabled(true)
	world.set_debug_enabled(false)
	world.set_petals_enabled(true)
	_apply_solar()
	hud.sync_from_main()


# ── 查询 / 测试接口 ──────────────────────────────────────────────────────
func get_hour() -> float:
	return hour


func get_ticks() -> int:
	return SunModel.hour_to_ticks(hour)


func get_elevation() -> float:
	return float(_solar.get("elevation", 0.0))


func get_azimuth() -> float:
	return float(_solar.get("azimuth", 0.0))


func get_phase() -> String:
	return String(_solar.get("phase", ""))


func get_sun_dir() -> Vector2:
	return _solar.get("sun_dir", Vector2.UP)


func get_shadow_dir() -> Vector2:
	return _solar.get("shadow_dir", Vector2.DOWN)


func get_solar() -> Dictionary:
	return _solar.duplicate(true)


func get_hero_shadow_report() -> Dictionary:
	return _hero_shadow_report.duplicate(true)


func get_global_uniform(uniform_name: String) -> Variant:
	return _global_uniforms.get(uniform_name, null)


func get_world() -> SakuraWorld:
	return world


func get_hud():
	return hud


func is_playing() -> bool:
	return _playing


func get_speed() -> float:
	return _speed


func are_shadows_enabled() -> bool:
	return _shadows_enabled


func is_debug_enabled() -> bool:
	return _debug_enabled


func are_petals_enabled() -> bool:
	return _petals_enabled


func is_ui_visible() -> bool:
	return _ui_visible


func get_fps() -> int:
	return int(Engine.get_frames_per_second())


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


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
		KEY_F3:
			set_debug_enabled(not _debug_enabled)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_P:
			set_petals_enabled(not _petals_enabled)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_1:
			set_hour(8.0)
			set_playing(false)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_2:
			set_hour(12.0)
			set_playing(false)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_3:
			set_hour(16.0)
			set_playing(false)
			hud.sync_from_main()
			get_viewport().set_input_as_handled()
