extends Node

# 主控：搭像素场景、低洼场、雨丝/涟漪/水面层，维护 22s 积水 / 75s 渗干，
# 接线 HUD 和键盘。世界渲染在 640×360 的 SubViewport，窗口 1280×720 起。

const WORLD := Vector2(640.0, 360.0)
const FILL_SECONDS := 22.0
const DRAIN_SECONDS := 75.0
const DEFAULT_DENSITY := 360
const DEFAULT_INTENSITY := 0.85
const DEFAULT_WIND := 0.26

var field: PuddleField
var rain: RainField
var ripples: RippleField
var wet := 0.0
var rain_intensity := DEFAULT_INTENSITY
var density := DEFAULT_DENSITY
var wind := DEFAULT_WIND
var rain_speed := 1.0
var rain_length := 1.0
var fill_speed := 1.0
var drain_speed := 1.0
var paused := false
var ripples_enabled := true
var reflection_enabled := true
var debug_grid := false

var _art: Dictionary = {}
var _water_mat: ShaderMaterial
var _water_layer: ColorRect
var _ground: Sprite2D
var _foreground: Sprite2D
var _props: Array[Sprite2D] = []
var _prop_root: Node2D
var _glow: MultiMeshInstance2D
var _debug: Node2D
var _time := 0.0
var _ui_visible := true

@onready var _world: Node2D = $WorldViewport/World
@onready var _display: TextureRect = $WorldDisplay
@onready var _hud = $HUD


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	field = PuddleField.new()
	var t_field := Time.get_ticks_msec()
	_art = PixelArt.build_scene_art()
	var t_art := Time.get_ticks_msec()
	_build_world()
	_display.texture = $WorldViewport.get_texture()
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hud.setup(self)
	_update_shader_uniforms()
	_hud.sync_from_main()
	print("RAIN_PUDDLES_READY field_ms=%d art_ms=%d nodes_ms=%d total_ms=%d" % [
		t_field - t0, t_art - t_field, Time.get_ticks_msec() - t_art,
		Time.get_ticks_msec() - t0])


func _build_world() -> void:
	# 地面
	_ground = Sprite2D.new()
	_ground.name = "Ground"
	_ground.centered = false
	_ground.texture = ImageTexture.create_from_image(_art["ground"])
	_ground.z_index = -10
	_world.add_child(_ground)

	# 积水合成层（湿边 + 水色 + 倒影 + 水面闪光），单次绘制。
	_water_layer = ColorRect.new()
	_water_layer.name = "WaterLayer"
	_water_layer.position = Vector2.ZERO
	_water_layer.size = WORLD
	_water_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water_surface.gdshader")
	_water_mat.set_shader_parameter("u_field", field.get_field_texture())
	var refl_tex := ImageTexture.create_from_image(_art["reflection"])
	_water_mat.set_shader_parameter("u_reflection", refl_tex)
	_water_mat.set_shader_parameter("u_reflection_on", 1.0)
	_water_layer.material = _water_mat
	_water_layer.z_index = 0
	_world.add_child(_water_layer)

	# 涟漪
	ripples = RippleField.new()
	ripples.name = "Ripples"
	ripples.z_index = 2
	_world.add_child(ripples)
	ripples.setup(field, _art["ring"])

	# 道具（按脚底 y 顺序叠放；水面在其下）
	_prop_root = Node2D.new()
	_prop_root.name = "Props"
	_prop_root.z_index = 10
	_world.add_child(_prop_root)
	_add_prop(_art["maple"], RainLayout.MAPLE["pos"])
	# 左灯臂朝右，用未翻转的图；右灯臂朝左，用翻转图。
	_add_prop(_art["lamp_r"], RainLayout.LAMPS[0]["pos"])
	_add_prop(_art["lamp_l"], RainLayout.LAMPS[1]["pos"])
	_add_prop(_art["pine"], RainLayout.PINE["pos"])

	# 灯笼暖光（MultiMesh，一个绘制）
	_glow = MultiMeshInstance2D.new()
	_glow.name = "LanternGlow"
	_glow.texture = ImageTexture.create_from_image(_art["glow"])
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow.z_index = 20
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = cm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = RainLayout.LAMPS.size()
	_glow.multimesh = mm
	_world.add_child(_glow)
	for i in RainLayout.LAMPS.size():
		var lamp: Dictionary = RainLayout.LAMPS[i]
		var sign_x := -1.0 if bool(lamp["flip"]) else 1.0
		var p: Vector2 = lamp["pos"] + Vector2(sign_x * RainLayout.LANTERN_OFFSET.x,
				RainLayout.LANTERN_OFFSET.y)
		mm.set_instance_transform_2d(i, Transform2D(0.0, Vector2(160.0, 160.0), 0.0, p))
		mm.set_instance_color(i, Color(1.0, 0.80, 0.46, 0.56))

	# 雨丝
	rain = RainField.new()
	rain.name = "Rain"
	rain.z_index = 30
	_world.add_child(rain)
	rain.set_density(density)
	rain.set_wind(wind)
	rain.set_speed_scale(rain_speed)
	rain.set_length_scale(rain_length)
	rain.set_intensity(rain_intensity)

	# 前景蕨叶剪影
	_foreground = Sprite2D.new()
	_foreground.name = "Foreground"
	_foreground.centered = false
	_foreground.texture = ImageTexture.create_from_image(_art["foreground"])
	_foreground.z_index = 40
	_world.add_child(_foreground)

	# 调试网格
	_debug = Node2D.new()
	_debug.name = "DebugGrid"
	_debug.set_script(load("res://scripts/debug_grid.gd"))
	_debug.set("field", field)
	_debug.z_index = 60
	_debug.visible = false
	_world.add_child(_debug)
	_debug.call("queue_redraw")


func _add_prop(image: Image, base_pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = ImageTexture.create_from_image(image)
	s.position = base_pos - Vector2(float(image.get_width()) * 0.5,
			float(image.get_height()))
	s.z_index = 0
	_prop_root.add_child(s)
	_props.append(s)


func _process(delta: float) -> void:
	if not paused:
		_time += delta
		_step_water(delta)
		rain.step(delta)
		ripples.step(delta, field.waterline_at(wet), rain_intensity)
		_update_glow()
	_update_shader_uniforms()
	_update_wet_tint()


func _step_water(dt: float) -> void:
	if rain_intensity > 0.01:
		var rate := rain_intensity * fill_speed / FILL_SECONDS
		wet = minf(1.0, wet + rate * dt)
	else:
		wet = maxf(0.0, wet - drain_speed / DRAIN_SECONDS * dt)


func _update_shader_uniforms() -> void:
	if _water_mat == null:
		return
	var wl := field.waterline_at(wet)
	_water_mat.set_shader_parameter("u_waterline", wl)
	_water_mat.set_shader_parameter("u_wet", wet)
	_water_mat.set_shader_parameter("u_rain", rain_intensity)
	_water_mat.set_shader_parameter("u_time", _time)
	_water_mat.set_shader_parameter("u_reflection_on", 1.0 if reflection_enabled else 0.0)
	if ripples != null and ripples.get_shader_material() != null:
		ripples.get_shader_material().set_shader_parameter("u_waterline", wl)


func _update_wet_tint() -> void:
	var tint := Color(1.0, 1.0, 1.0).lerp(Color(0.84, 0.92, 0.95), wet * 0.30)
	if _ground != null:
		_ground.modulate = tint
	for p in _props:
		p.modulate = tint


func _update_glow() -> void:
	if _glow == null or _glow.multimesh == null:
		return
	for i in RainLayout.LAMPS.size():
		var flick := 0.52 + 0.035 * sin(_time * 2.2 + float(i) * 2.4)
		_glow.multimesh.set_instance_color(i, Color(1.0, 0.86, 0.55, flick))


# ── 参数入口（HUD / 工具 / 测试共用） ─────────────────────────────────────
func set_rain_intensity(value: float) -> void:
	rain_intensity = clampf(value, 0.0, 1.0)
	rain.set_intensity(rain_intensity)
	_update_shader_uniforms()


func set_density(value: int) -> void:
	density = clampi(value, 60, 600)
	rain.set_density(density)


func set_wind(value: float) -> void:
	wind = clampf(value, -0.6, 0.6)
	rain.set_wind(wind)


func set_rain_speed(value: float) -> void:
	rain_speed = clampf(value, 0.4, 2.0)
	rain.set_speed_scale(rain_speed)


func set_rain_length(value: float) -> void:
	rain_length = clampf(value, 0.5, 1.8)
	rain.set_length_scale(rain_length)


func set_fill_speed(value: float) -> void:
	fill_speed = clampf(value, 0.25, 4.0)


func set_drain_speed(value: float) -> void:
	drain_speed = clampf(value, 0.25, 12.0)


func set_wet_level(value: float) -> void:
	wet = clampf(value, 0.0, 1.0)
	_update_shader_uniforms()


func set_ripples_enabled(value: bool) -> void:
	ripples_enabled = value
	ripples.set_enabled(value)


func set_reflection_enabled(value: bool) -> void:
	reflection_enabled = value
	_update_shader_uniforms()


func set_debug_grid(value: bool) -> void:
	debug_grid = value
	_debug.visible = value
	if value:
		_debug.call("queue_redraw")


func set_paused(value: bool) -> void:
	paused = value
	rain.set_paused(value)


func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	_hud.set_ui_visible(value)


func toggle_ui() -> void:
	set_ui_visible(not _ui_visible)


func reset() -> void:
	wet = 0.0
	rain_intensity = DEFAULT_INTENSITY
	density = DEFAULT_DENSITY
	wind = DEFAULT_WIND
	rain_speed = 1.0
	rain_length = 1.0
	fill_speed = 1.0
	drain_speed = 1.0
	paused = false
	ripples_enabled = true
	reflection_enabled = true
	debug_grid = false
	rain.set_paused(false)
	rain.set_intensity(rain_intensity)
	rain.set_density(density)
	rain.set_wind(wind)
	rain.set_speed_scale(rain_speed)
	rain.set_length_scale(rain_length)
	rain.reset_drops()
	ripples.set_enabled(true)
	ripples.reset()
	_debug.visible = false
	_update_shader_uniforms()
	_update_wet_tint()
	_hud.sync_from_main()


func simulate_water(seconds: float) -> void:
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		_step_water(dt)
		left -= dt
	_update_shader_uniforms()


func simulate_effects(seconds: float) -> void:
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		_time += dt
		rain.step(dt)
		ripples.step(dt, field.waterline_at(wet), rain_intensity)
		left -= dt
	_update_shader_uniforms()


# ── 查询 / 测试接口 ──────────────────────────────────────────────────────
func get_field() -> PuddleField:
	return field


func get_rain() -> RainField:
	return rain


func get_ripples() -> RippleField:
	return ripples


func get_water_material() -> ShaderMaterial:
	return _water_mat


func get_ripple_material() -> ShaderMaterial:
	return ripples.get_shader_material()


func get_wet() -> float:
	return wet


func get_ripple_count() -> int:
	return ripples.get_active_count()


func get_state_label() -> String:
	if wet >= 0.999:
		return "满水"
	if rain_intensity <= 0.01 and wet > 0.005:
		return "渗干中"
	if wet > 0.005:
		return "积水中"
	return "干燥"


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func get_fps() -> int:
	return int(Engine.get_frames_per_second())


func is_paused() -> bool:
	return paused


func is_debug_grid() -> bool:
	return debug_grid


func get_params() -> Dictionary:
	return {
		"rain": rain_intensity,
		"density": density,
		"wind": wind,
		"speed": rain_speed,
		"length": rain_length,
		"fill": fill_speed,
		"drain": drain_speed,
		"wet": wet,
		"ripples": ripples_enabled,
		"reflection": reflection_enabled,
		"debug": debug_grid,
		"paused": paused,
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			set_paused(not paused)
			_hud.sync_from_main()
			get_viewport().set_input_as_handled()
		KEY_R:
			reset()
			get_viewport().set_input_as_handled()
		KEY_H:
			toggle_ui()
			get_viewport().set_input_as_handled()
		KEY_F3:
			set_debug_grid(not debug_grid)
			_hud.sync_from_main()
			get_viewport().set_input_as_handled()
