extends Node

# 主控：光照状态、可移动点光/方向光、Shader ↔ 原生 Light2D 路径切换、
# 参数入口（HUD/工具/测试共用）、输入与暂停。
#
# 世界是 320×180 美术像素，Camera2D zoom=4 → 1280×720 逻辑窗口下
# 1 美术像素 = 4 屏幕像素；1920×1080 时 canvas_items 再 1.5× = 6 屏幕像素。

const ORBIT_CENTER := Vector2(190.0, 118.0)
const ORBIT_RADIUS := Vector2(78.0, 42.0)
const LIGHT_RADIUS := 240.0
const AUTO_SPEED := 13.0
const AMBIENT_BASE := Color(0.30, 0.35, 0.48, 1.0)
const NATIVE_ENERGY := 2.2
const NATIVE_DIR_ENERGY := 1.35

const COLOR_PRESETS := [
	{"name": "暖灯", "color": Color(1.0, 0.73, 0.45, 1.0)},
	{"name": "月光", "color": Color(0.62, 0.77, 1.0, 1.0)},
	{"name": "炉火", "color": Color(1.0, 0.50, 0.23, 1.0)},
	{"name": "中性", "color": Color(1.0, 0.94, 0.84, 1.0)},
]

var light_angle := 330.0
var light_height := 64.0
var light_energy := 2.0
var normal_strength := 1.0
var roughness := 0.5
var spec_strength := 0.6
var ambient_strength := 0.9
var rim_strength := 0.16
var normals_on := true
var debug_mode := 0
var native_mode := false
var point_mode := true
var auto_orbit := true
var playing := true
var color_index := 0
var light_pos := Vector2.ZERO
var flip_test := false
var scale_test := false

var _glow: Sprite2D
var _rig: Node2D
var _point_light: PointLight2D
var _dir_light: DirectionalLight2D
var _fill_light: DirectionalLight2D
var _canvas_modulate: CanvasModulate
var _dragging := false
var _time := 0.0

@onready var world: Node2D = $World
@onready var hud = $HUD
@onready var debug_overlay: Node2D = $DebugOverlay


func _ready() -> void:
	_build_light_rig()
	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "CanvasModulate"
	add_child(_canvas_modulate)
	debug_overlay.setup(self)
	hud.setup(self)
	light_pos = _orbit_position(light_angle)
	_apply_lighting()
	hud.sync_from_main()
	print("SPRITE_NORMAL_LIGHT_READY viewport=%s sprites=%d" % [
		str(get_viewport().get_visible_rect().size),
		world.get_entries().size()])


func _build_light_rig() -> void:
	_rig = Node2D.new()
	_rig.name = "LightRig"
	add_child(_rig)

	_glow = Sprite2D.new()
	_glow.name = "EmberGlow"
	_glow.texture = load("res://assets/sprites/glow.png")
	_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glow.scale = Vector2(1.5, 1.5)
	_glow.z_index = 8
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = glow_mat
	_rig.add_child(_glow)

	_point_light = PointLight2D.new()
	_point_light.name = "NativePointLight"
	_point_light.texture = load("res://assets/sprites/light_radial.png")
	_point_light.texture_scale = 2.0
	_point_light.enabled = false
	_rig.add_child(_point_light)

	_dir_light = DirectionalLight2D.new()
	_dir_light.name = "NativeDirectionalLight"
	_dir_light.enabled = false
	_rig.add_child(_dir_light)

	# Native-mode ambient fill. CanvasModulate multiplies the final lit result,
	# so it cannot lift shadows on its own without crushing the point light;
	# a low cool DirectionalLight2D keeps the built-in path readable.
	_fill_light = DirectionalLight2D.new()
	_fill_light.name = "NativeFillLight"
	_fill_light.rotation = 0.0
	_fill_light.height = 54.0
	_fill_light.color = Color(0.55, 0.65, 0.90, 1.0)
	_fill_light.energy = 0.0
	_fill_light.enabled = false
	add_child(_fill_light)


func _process(delta: float) -> void:
	if playing and auto_orbit:
		light_angle = fposmod(light_angle + AUTO_SPEED * delta, 360.0)
		if point_mode:
			light_pos = _orbit_position(light_angle)
		_apply_lighting()
	elif not auto_orbit:
		_step_manual_light(delta)
	if debug_mode != 0:
		debug_overlay.queue_redraw()


func _step_manual_light(delta: float) -> void:
	var ax := float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT))
	var ay := float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
	if ax == 0.0 and ay == 0.0:
		return
	if point_mode:
		light_pos = Vector2(
			clampf(light_pos.x + ax * 64.0 * delta, 92.0, 306.0),
			clampf(light_pos.y + ay * 64.0 * delta, 34.0, 166.0))
		light_angle = _angle_from_pos(light_pos)
	else:
		if ax != 0.0:
			light_angle = fposmod(light_angle + ax * 55.0 * delta, 360.0)
		if ay != 0.0:
			set_light_height(clampf(light_height - ay * 48.0 * delta, 8.0, 160.0))
	_apply_lighting()
	hud.sync_from_main()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and point_mode:
			var canvas_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
			if Rect2(92, 30, 216, 140).has_point(canvas_pos):
				_dragging = true
				auto_orbit = false
				_set_light_from_world(canvas_pos)
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging and point_mode:
		var canvas_pos: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		_set_light_from_world(canvas_pos)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				set_playing(not playing)
			KEY_R:
				reset()
			KEY_V:
				set_normals_on(not normals_on)
			KEY_F:
				cycle_debug()
			KEY_M:
				set_native_mode(not native_mode)
			KEY_G:
				set_point_mode(not point_mode)
			KEY_A:
				set_auto_orbit(not auto_orbit)
			KEY_C:
				cycle_light_color()
			KEY_X:
				toggle_flip_test()
			KEY_Z:
				toggle_scale_test()
			KEY_H:
				set_ui_visible(not is_ui_visible())


func _set_light_from_world(pos: Vector2) -> void:
	light_pos = Vector2(clampf(pos.x, 92.0, 306.0), clampf(pos.y, 34.0, 166.0))
	light_angle = _angle_from_pos(light_pos)
	_apply_lighting()
	hud.sync_from_main()


func _orbit_position(angle_deg: float) -> Vector2:
	var a := deg_to_rad(angle_deg)
	return ORBIT_CENTER + Vector2(sin(a) * ORBIT_RADIUS.x,
			-cos(a) * ORBIT_RADIUS.y)


func _angle_from_pos(pos: Vector2) -> float:
	var d := pos - ORBIT_CENTER
	return fposmod(rad_to_deg(atan2(d.x / ORBIT_RADIUS.x,
			-d.y / ORBIT_RADIUS.y)), 360.0)


# ── 应用状态 ──────────────────────────────────────────────────────────────
func _apply_lighting() -> void:
	var color: Color = COLOR_PRESETS[color_index]["color"]
	var ambient: Color = AMBIENT_BASE * ambient_strength
	RenderingServer.global_shader_parameter_set("u_light_mode", 0 if point_mode else 1)
	RenderingServer.global_shader_parameter_set("u_light_pos", light_pos)
	RenderingServer.global_shader_parameter_set("u_light_height", light_height)
	RenderingServer.global_shader_parameter_set("u_light_radius", LIGHT_RADIUS)
	RenderingServer.global_shader_parameter_set("u_light_color", color)
	RenderingServer.global_shader_parameter_set("u_light_energy", light_energy)
	RenderingServer.global_shader_parameter_set("u_light_angle_deg", light_angle)
	RenderingServer.global_shader_parameter_set("u_ambient_color", ambient)
	RenderingServer.global_shader_parameter_set("u_normal_strength", normal_strength)
	RenderingServer.global_shader_parameter_set("u_roughness", roughness)
	RenderingServer.global_shader_parameter_set("u_spec_strength", spec_strength)
	RenderingServer.global_shader_parameter_set("u_rim_strength", rim_strength)
	RenderingServer.global_shader_parameter_set("u_debug_mode", debug_mode)
	RenderingServer.global_shader_parameter_set("u_normals_on", normals_on)

	_rig.position = light_pos
	_glow.visible = point_mode and debug_mode == 0
	_glow.modulate = color * (1.25 if native_mode else 1.0)
	_point_light.enabled = native_mode and point_mode
	_point_light.height = light_height
	_point_light.energy = light_energy * NATIVE_ENERGY
	_point_light.color = color
	_point_light.texture_scale = 6.0
	_dir_light.enabled = native_mode and not point_mode
	_dir_light.height = light_height
	_dir_light.energy = light_energy * NATIVE_DIR_ENERGY
	_dir_light.color = color
	_dir_light.rotation = deg_to_rad(light_angle)
	_fill_light.enabled = native_mode
	_fill_light.energy = ambient_strength * 0.7
	_canvas_modulate.color = (Color(0.22, 0.24, 0.30) +
			Color(0.38, 0.40, 0.46) * ambient_strength) if native_mode else Color.WHITE


func _notify_ui() -> void:
	_apply_lighting()
	if hud != null:
		hud.sync_from_main()
	if debug_overlay != null:
		debug_overlay.queue_redraw()


# ── 参数入口 ──────────────────────────────────────────────────────────────
func set_param(key: String, value: float) -> void:
	match key:
		"angle":
			set_light_angle(value)
		"height":
			set_light_height(value)
		"energy":
			set_light_energy(value)
		"normal_strength":
			set_normal_strength(value)
		"spec":
			set_spec_strength(value)
		"rough":
			set_roughness(value)
		"ambient":
			set_ambient_strength(value)
		"rim":
			set_rim_strength(value)


func set_light_angle(value: float) -> void:
	auto_orbit = false
	light_angle = fposmod(value, 360.0)
	if point_mode:
		light_pos = _orbit_position(light_angle)
	_notify_ui()


func set_light_height(value: float) -> void:
	light_height = clampf(value, 8.0, 160.0)
	_notify_ui()


func set_light_energy(value: float) -> void:
	light_energy = clampf(value, 0.0, 3.0)
	_notify_ui()


func set_normal_strength(value: float) -> void:
	normal_strength = clampf(value, 0.0, 2.0)
	_notify_ui()


func set_roughness(value: float) -> void:
	roughness = clampf(value, 0.0, 1.0)
	_notify_ui()


func set_spec_strength(value: float) -> void:
	spec_strength = clampf(value, 0.0, 1.5)
	_notify_ui()


func set_ambient_strength(value: float) -> void:
	ambient_strength = clampf(value, 0.0, 1.0)
	_notify_ui()


func set_rim_strength(value: float) -> void:
	rim_strength = clampf(value, 0.0, 1.0)
	_notify_ui()


func set_normals_on(value: bool) -> void:
	if native_mode and not value:
		native_mode = false
		world.set_native_mode(false)
	normals_on = value
	_notify_ui()


func set_debug_mode(mode: int) -> void:
	debug_mode = clampi(mode, 0, 4)
	if native_mode and debug_mode != 0:
		native_mode = false
		world.set_native_mode(false)
	_notify_ui()


func cycle_debug() -> void:
	set_debug_mode((debug_mode + 1) % 5)


func set_native_mode(value: bool) -> void:
	if value == native_mode:
		return
	native_mode = value
	if native_mode:
		normals_on = true
		debug_mode = 0
	world.set_native_mode(native_mode)
	_notify_ui()


func set_point_mode(value: bool) -> void:
	point_mode = value
	if point_mode:
		light_pos = _orbit_position(light_angle)
	_notify_ui()


func set_auto_orbit(value: bool) -> void:
	auto_orbit = value
	_notify_ui()


func set_playing(value: bool) -> void:
	playing = value
	hud.sync_from_main()


func set_ui_visible(value: bool) -> void:
	hud.set_ui_visible(value)


func cycle_light_color() -> void:
	color_index = (color_index + 1) % COLOR_PRESETS.size()
	_notify_ui()


func toggle_flip_test() -> void:
	flip_test = not flip_test
	world.set_flip("guardian", flip_test)
	_notify_ui()


func toggle_scale_test() -> void:
	scale_test = not scale_test
	world.set_scale_test(scale_test)
	_notify_ui()


func reset() -> void:
	light_angle = 330.0
	light_height = 64.0
	light_energy = 2.0
	normal_strength = 1.0
	roughness = 0.5
	spec_strength = 0.6
	ambient_strength = 0.9
	rim_strength = 0.16
	normals_on = true
	debug_mode = 0
	native_mode = false
	point_mode = true
	auto_orbit = true
	playing = true
	color_index = 0
	flip_test = false
	scale_test = false
	light_pos = _orbit_position(light_angle)
	world.set_native_mode(false)
	world.set_flip("guardian", false)
	world.set_scale_test(false)
	_notify_ui()
	print("SPRITE_NORMAL_LIGHT_RESET")


func simulate(seconds: float) -> void:
	if not playing:
		return
	var left := maxf(seconds, 0.0)
	while left > 0.0:
		var dt := minf(left, 1.0 / 30.0)
		if auto_orbit:
			light_angle = fposmod(light_angle + AUTO_SPEED * dt, 360.0)
			if point_mode:
				light_pos = _orbit_position(light_angle)
		_apply_lighting()
		left -= dt
	if hud != null:
		hud.sync_from_main()


# ── 查询（HUD / 工具 / smoke） ────────────────────────────────────────────
func get_params() -> Dictionary:
	return {
		"angle": light_angle,
		"height": light_height,
		"energy": light_energy,
		"normal_strength": normal_strength,
		"roughness": roughness,
		"rough": roughness,
		"spec": spec_strength,
		"ambient": ambient_strength,
		"rim": rim_strength,
		"normals": normals_on,
		"debug": debug_mode,
		"native": native_mode,
		"point": point_mode,
		"auto": auto_orbit,
		"paused": not playing,
		"color_name": String(COLOR_PRESETS[color_index]["name"]),
		"color": COLOR_PRESETS[color_index]["color"],
		"light_pos": light_pos,
		"radius": LIGHT_RADIUS,
		"flip": flip_test,
		"scale": scale_test,
	}


func get_light_vector_at(pos: Vector2) -> Vector3:
	if point_mode:
		var v := Vector3(light_pos.x - pos.x, light_pos.y - pos.y, light_height)
		return v.normalized()
	var a := deg_to_rad(light_angle)
	return Vector3(sin(a), -cos(a), clampf(light_height / 80.0, 0.02, 2.0)).normalized()


func get_light_pos() -> Vector2:
	return light_pos


func get_light_height() -> float:
	return light_height


func get_light_radius() -> float:
	return LIGHT_RADIUS


func get_orbit_center() -> Vector2:
	return ORBIT_CENTER


func get_orbit_radius() -> Vector2:
	return ORBIT_RADIUS


func get_light_sample_points() -> Array:
	if world.has_method("get_light_sample_points"):
		return world.get_light_sample_points()
	return []


func is_debug_enabled() -> bool:
	return debug_mode != 0


func is_point_mode() -> bool:
	return point_mode


func is_native_mode() -> bool:
	return native_mode


func is_paused() -> bool:
	return not playing


func is_ui_visible() -> bool:
	return hud.is_ui_visible()


func get_fps() -> int:
	return Engine.get_frames_per_second()


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func get_state_summary() -> Dictionary:
	var p := get_params()
	return {
		"angle": p["angle"],
		"height": p["height"],
		"light_pos": p["light_pos"],
		"energy": p["energy"],
		"normals": p["normals"],
		"debug": p["debug"],
		"native": p["native"],
		"point": p["point"],
		"auto": p["auto"],
		"paused": p["paused"],
		"flip": p["flip"],
		"scale": p["scale"],
		"normal_strength": p["normal_strength"],
	}
