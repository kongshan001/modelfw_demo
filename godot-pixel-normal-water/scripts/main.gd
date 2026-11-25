extends Node2D

# 主控：程序化夜景、2D 法线受光材质、单相机倒影 Mesh、整格水波、
# 暖灯点光、调试叠加与 HUD 接线。
#
# 关键约束：
#   - 只有 tscn 里的一个 Camera2D；整个项目不实例化 SubViewport / Viewport。
#   - 倒影没有第二相机、没有抓屏、没有后处理：一次镜像 Mesh + 水面 mask。
#   - 所有时间从 _process 的 time_value 注入 shader，暂停时真正冻结。

const WORLD := NormalWaterLayout.WORLD
const WATERLINE := NormalWaterLayout.WATERLINE
const CAM_ZOOM := NormalWaterLayout.CAMERA_ZOOM

var art: Dictionary
var reflection: NormalWaterReflection
var debug_overlay: NormalWaterDebugOverlay
var overlay_material: ShaderMaterial
var lit_materials: Array[ShaderMaterial] = []
var lit_objects: Array[Dictionary] = []
var lamp_glows: Array[Sprite2D] = []
var lamp_positions: Array[Vector2] = []
var water_base: Sprite2D
var camera: Camera2D

var light_preset := 0
var light_angle_deg := NormalWaterLayout.DEFAULT_LIGHT_ANGLE_DEG
var light_energy := NormalWaterLayout.DEFAULT_LIGHT_ENERGY
var lamps_on := true
var reflection_on := true
var normals_on := true
var debug_on := false
var normal_view := false
var paused := false
var time_scale := 1.0
var wave_speed := NormalWaterLayout.DEFAULT_WAVE_SPEED
var wave_amplitude := NormalWaterLayout.DEFAULT_WAVE_AMPLITUDE
var wave_step := NormalWaterLayout.DEFAULT_WAVE_STEP
var time_value := 0.0
var ui_visible := true

var _world: Node2D
var _hud
var _glow_texture: Texture2D


func _ready() -> void:
	_world = $World
	camera = $Camera2D
	_hud = $HUD
	camera.position = WORLD * 0.5
	camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	camera.make_current()

	_build_scene()
	_hud.setup(self)
	_update_visuals()
	_hud.sync_from_main()
	print("NORMAL_WATER_READY objects=%d materials=%d reflection_quads=%d cameras=1 viewports=0"
			% [lit_objects.size(), lit_materials.size(), reflection.get_quad_count()])


func _build_scene() -> void:
	art = NormalWaterArt.build_scene_art()

	# 背景天空/远山/远镇（不参与法线光照，也不进入倒影）。
	var sky := _add_unlit_sprite("Sky", art["sky"]["image"], Vector2.ZERO, -100)
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 水底色（静态深水 + 月影），倒影 Mesh 叠加在它上面。
	water_base = _add_unlit_sprite("WaterBase", art["water"]["image"], Vector2.ZERO, -40)
	water_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# 共享水面 mask 的一次性镜像 Mesh。近岸物按树/灯的先后顺序打包。
	var sources: Array = []
	for id in ["tavern", "maple", "townhouse", "pine"]:
		var layout_obj := NormalWaterLayout.object_by_id(id)
		sources.append({
			"id": id,
			"image": art[id]["image"],
			"pos": Vector2(layout_obj["pos"]),
			"foot": WATERLINE,
		})
	for lamp_def in NormalWaterLayout.LAMPS:
		sources.append({
			"id": String(lamp_def["id"]),
			"image": art["lamp"]["image"],
			"pos": Vector2(lamp_def["pos"]),
			"foot": WATERLINE,
		})
	reflection = NormalWaterReflection.new()
	reflection.name = "Reflections"
	reflection.setup(sources, art["mask"], WATERLINE, -30)
	_world.add_child(reflection)

	_build_water_overlay()
	_build_bank()
	_build_objects()
	_build_lamps()
	_build_foreground()
	_build_debug_overlay()


func _add_unlit_sprite(sprite_name: String, image: Image, pos: Vector2,
		z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = sprite_name
	s.centered = false
	s.texture = ImageTexture.create_from_image(image)
	s.position = pos
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_world.add_child(s)
	return s


func _make_lit_sprite(object_id: String, entry: Dictionary, pos: Vector2i, z: int,
		emission: float, normal_strength := 1.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = object_id.capitalize()
	s.centered = false
	s.texture = ImageTexture.create_from_image(entry["image"])
	s.position = Vector2(pos)
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var normal_tex := ImageTexture.create_from_image(entry["normal"])
	var rough_tex := ImageTexture.create_from_image(entry["roughness"])
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/lit_sprite.gdshader")
	mat.set_shader_parameter("u_normal_tex", normal_tex)
	mat.set_shader_parameter("u_rough_tex", rough_tex)
	mat.set_shader_parameter("u_emission_strength", emission)
	mat.set_shader_parameter("u_normal_strength", normal_strength)
	s.material = mat
	_world.add_child(s)

	lit_materials.append(mat)
	lit_objects.append({
		"id": object_id,
		"sprite": s,
		"material": mat,
		"albedo": entry["image"],
		"normal": entry["normal"],
		"roughness": entry["roughness"],
		"emission": emission,
	})
	return s


func _build_bank() -> void:
	var bank := NormalWaterLayout.BANK
	_make_lit_sprite("bank", art["bank"], bank["pos"], bank["z"], 0.0, 1.0)


func _build_objects() -> void:
	for obj in NormalWaterLayout.OBJECTS:
		var id := String(obj["id"])
		_make_lit_sprite(id, art[id], obj["pos"], int(obj["z"]),
				float(obj["emission"]), 1.0 if id != "maple" else 1.15)


func _build_lamps() -> void:
	_glow_texture = ImageTexture.create_from_image(art["glow"])
	lamp_positions.clear()
	for lamp_def in NormalWaterLayout.LAMPS:
		var lid := String(lamp_def["id"])
		_make_lit_sprite(lid, art["lamp"], lamp_def["pos"], int(lamp_def["z"]), 1.15, 1.0)
		var lpos := Vector2(lamp_def["pos"]) + Vector2(lamp_def["lantern"])
		lamp_positions.append(lpos)
		var glow := Sprite2D.new()
		glow.name = "Glow_" + lid
		glow.centered = true
		glow.texture = _glow_texture
		glow.position = lpos
		glow.z_index = 20
		glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var glow_mat := CanvasItemMaterial.new()
		glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = glow_mat
		_world.add_child(glow)
		lamp_glows.append(glow)


func _build_foreground() -> void:
	for rock in NormalWaterLayout.ROCKS:
		_make_lit_sprite(String(rock["id"]), art[String(rock["id"])], rock["pos"],
				int(rock["z"]), 0.0, 1.0)
	_make_lit_sprite("boulder", art["boulder"], NormalWaterLayout.BOULDER["pos"],
			int(NormalWaterLayout.BOULDER["z"]), 0.0, 1.0)
	_make_lit_sprite("dock", art["dock"], NormalWaterLayout.DOCK["pos"],
			int(NormalWaterLayout.DOCK["z"]), 0.0, 1.0)


func _build_water_overlay() -> void:
	var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	white.fill(Color(1, 1, 1, 1))
	var s := Sprite2D.new()
	s.name = "WaterOverlay"
	s.centered = false
	s.texture = ImageTexture.create_from_image(white)
	s.scale = WORLD
	s.position = Vector2.ZERO
	s.z_index = -20
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay_material = ShaderMaterial.new()
	overlay_material.shader = load("res://shaders/water_overlay.gdshader")
	overlay_material.set_shader_parameter("u_mask", ImageTexture.create_from_image(art["mask"]))
	overlay_material.set_shader_parameter("u_world_size", WORLD)
	overlay_material.set_shader_parameter("u_waterline", WATERLINE)
	overlay_material.set_shader_parameter("u_lamp_a_x", lamp_world_x(0))
	overlay_material.set_shader_parameter("u_lamp_b_x", lamp_world_x(1))
	overlay_material.set_shader_parameter("u_moon_x", NormalWaterLayout.MOON_X)
	s.material = overlay_material
	_world.add_child(s)


func _build_debug_overlay() -> void:
	debug_overlay = NormalWaterDebugOverlay.new()
	debug_overlay.name = "DebugOverlay"
	debug_overlay.setup(reflection, art["mask"], WATERLINE)
	_world.add_child(debug_overlay)


func lamp_world_x(index: int) -> float:
	var lamp: Dictionary = NormalWaterLayout.LAMPS[index]
	return float(lamp["pos"].x + lamp["lantern"].x)


func _process(delta: float) -> void:
	if not paused:
		time_value += delta * time_scale
	_update_visuals()


func _update_visuals() -> void:
	if reflection == null:
		return
	reflection.set_time(time_value)
	reflection.set_wave_params(wave_speed, wave_amplitude, wave_step)
	reflection.set_lamps_on(lamps_on)
	if reflection_on and not reflection.is_reflection_enabled():
		reflection.set_reflection_enabled(true)
	elif not reflection_on and reflection.is_reflection_enabled():
		reflection.set_reflection_enabled(false)

	if overlay_material != null:
		overlay_material.set_shader_parameter("u_time", time_value)
		overlay_material.set_shader_parameter("u_wave_speed", wave_speed)
		overlay_material.set_shader_parameter("u_wave_amplitude", wave_amplitude)
		overlay_material.set_shader_parameter("u_wave_step", wave_step)
		overlay_material.set_shader_parameter("u_lamps_on", lamps_on)

	_apply_light_uniforms()
	_update_lamp_glows()

	if debug_overlay != null:
		debug_overlay.visible = debug_on
		if debug_on:
			debug_overlay.sync(light_angle_deg, light_energy, time_value,
					wave_speed, wave_amplitude, wave_step)
			debug_overlay.set_debug_mode(1 if normal_view else 0)


func _apply_light_uniforms() -> void:
	var preset: Dictionary = NormalWaterLayout.LIGHT_PRESETS[light_preset]
	var color: Vector3 = preset["color"]
	var ambient: Vector3 = preset["ambient"]
	var angle := deg_to_rad(light_angle_deg)
	var dir := Vector2(sin(angle), -cos(angle))
	var debug_mode := 1 if normal_view else 0
	var lamp_a := lamp_positions[0] if lamp_positions.size() > 0 else Vector2.ZERO
	var lamp_b := lamp_positions[1] if lamp_positions.size() > 1 else Vector2.ZERO
	for mat in lit_materials:
		mat.set_shader_parameter("u_light_dir", dir)
		mat.set_shader_parameter("u_light_color", color)
		mat.set_shader_parameter("u_light_energy", light_energy)
		mat.set_shader_parameter("u_ambient_color", ambient)
		mat.set_shader_parameter("u_lamps_on", lamps_on)
		mat.set_shader_parameter("u_lamp_a", lamp_a)
		mat.set_shader_parameter("u_lamp_b", lamp_b)
		mat.set_shader_parameter("u_lamp_energy", NormalWaterLayout.LAMP_ENERGY)
		mat.set_shader_parameter("u_lamp_color", NormalWaterLayout.LAMP_COLOR)
		mat.set_shader_parameter("u_lamp_radius", NormalWaterLayout.LAMP_RADIUS)
		mat.set_shader_parameter("u_lamp_height", NormalWaterLayout.LAMP_HEIGHT)
		mat.set_shader_parameter("u_specular_strength", 0.26)
		mat.set_shader_parameter("u_normals_on", normals_on)
		mat.set_shader_parameter("u_debug_mode", debug_mode)
		mat.set_shader_parameter("u_time", time_value)


func _update_lamp_glows() -> void:
	for i in lamp_glows.size():
		var glow := lamp_glows[i]
		if glow == null:
			continue
		var phase := 0.0 if i == 0 else 1.7
		var flick := 0.93 + 0.07 * sin(time_value * 3.1 + phase)
		glow.visible = lamps_on
		glow.modulate = Color(1.0, 0.88, 0.68, 0.92 * flick)
		var s := 0.96 + 0.04 * sin(time_value * 2.2 + phase)
		glow.scale = Vector2(s, s)


# ── 状态 / HUD / smoke 接口 ──────────────────────────────────────────────
func set_light_angle(value: float) -> void:
	light_angle_deg = fposmod(value, 360.0)
	_apply_light_uniforms()


func set_light_energy(value: float) -> void:
	light_energy = clampf(value, 0.0, 2.4)
	_apply_light_uniforms()


func set_light_preset(index: int) -> void:
	light_preset = posmod(index, NormalWaterLayout.LIGHT_PRESETS.size())
	var preset: Dictionary = NormalWaterLayout.LIGHT_PRESETS[light_preset]
	light_angle_deg = float(preset["angle"])
	light_energy = float(preset["energy"])
	_apply_light_uniforms()


func cycle_light_preset() -> void:
	set_light_preset(light_preset + 1)


func set_lamps_enabled(value: bool) -> void:
	lamps_on = value
	reflection.set_lamps_on(value)
	_update_visuals()


func set_reflection_enabled(value: bool) -> void:
	reflection_on = value
	reflection.set_reflection_enabled(value)


func set_normals_enabled(value: bool) -> void:
	normals_on = value
	_apply_light_uniforms()


func set_debug_enabled(value: bool) -> void:
	debug_on = value
	if debug_overlay != null:
		debug_overlay.visible = value


func set_normal_view(value: bool) -> void:
	normal_view = value
	_apply_light_uniforms()


func set_wave_speed(value: float) -> void:
	wave_speed = clampf(value, 0.0, 2.5)
	_update_visuals()


func set_wave_amplitude(value: float) -> void:
	wave_amplitude = clampf(value, 0.0, 4.0)
	_update_visuals()


func set_wave_step(value: float) -> void:
	wave_step = clampf(round(value), 1.0, 4.0)
	_update_visuals()


func set_paused(value: bool) -> void:
	paused = value
	_update_visuals()


func is_paused() -> bool:
	return paused


func set_time_scale(value: float) -> void:
	time_scale = clampf(value, 0.0, 2.0)


func set_time_value(value: float) -> void:
	time_value = maxf(0.0, value)
	_update_visuals()


func set_ui_visible(value: bool) -> void:
	ui_visible = value
	if _hud != null:
		_hud.set_ui_visible(value)


func reset_scene() -> void:
	light_preset = 0
	light_angle_deg = NormalWaterLayout.DEFAULT_LIGHT_ANGLE_DEG
	light_energy = NormalWaterLayout.DEFAULT_LIGHT_ENERGY
	lamps_on = true
	reflection_on = true
	normals_on = true
	debug_on = false
	normal_view = false
	paused = false
	time_scale = 1.0
	wave_speed = NormalWaterLayout.DEFAULT_WAVE_SPEED
	wave_amplitude = NormalWaterLayout.DEFAULT_WAVE_AMPLITUDE
	wave_step = NormalWaterLayout.DEFAULT_WAVE_STEP
	time_value = 0.0
	if reflection != null:
		reflection.set_reflection_enabled(true)
	if debug_overlay != null:
		debug_overlay.visible = false
	_update_visuals()


func focus_camera(center: Vector2, zoom_value: float) -> void:
	camera.position = center
	camera.zoom = Vector2(zoom_value, zoom_value)


func reset_camera() -> void:
	camera.position = WORLD * 0.5
	camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)


func get_params() -> Dictionary:
	return {
		"angle": light_angle_deg,
		"energy": light_energy,
		"light_name": String(NormalWaterLayout.LIGHT_PRESETS[light_preset]["name"]),
		"light_preset": light_preset,
		"lamps": lamps_on,
		"reflection": reflection_on,
		"normals": normals_on,
		"debug": debug_on,
		"normal_view": normal_view,
		"paused": paused,
		"time_scale": time_scale,
		"wave_speed": wave_speed,
		"wave_amp": wave_amplitude,
		"wave_step": wave_step,
		"time": time_value,
	}


func get_light_state() -> Dictionary:
	var preset: Dictionary = NormalWaterLayout.LIGHT_PRESETS[light_preset]
	var angle := deg_to_rad(light_angle_deg)
	return {
		"angle": light_angle_deg,
		"dir": Vector2(sin(angle), -cos(angle)),
		"energy": light_energy,
		"color": preset["color"],
		"ambient": preset["ambient"],
		"name": String(preset["name"]),
	}


func get_time() -> float:
	return time_value


func get_fps() -> int:
	return int(Engine.get_frames_per_second())


func get_draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func get_reflection_quad_count() -> int:
	return reflection.get_quad_count() if reflection != null else 0


func get_wave_shift_at_row(row: int) -> int:
	return reflection.quantized_shift(row, time_value) if reflection != null else 0


func get_lit_objects() -> Array[Dictionary]:
	return lit_objects


func get_lit_materials() -> Array[ShaderMaterial]:
	return lit_materials


func get_lamp_glows() -> Array[Sprite2D]:
	return lamp_glows


func get_lamp_positions() -> Array[Vector2]:
	return lamp_positions


func get_reflection() -> NormalWaterReflection:
	return reflection


func get_overlay_material() -> ShaderMaterial:
	return overlay_material


func get_debug_overlay() -> NormalWaterDebugOverlay:
	return debug_overlay


func get_camera() -> Camera2D:
	return camera


func get_mask_image() -> Image:
	return art["mask"]


func get_art() -> Dictionary:
	return art


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var key: Key = key_event.keycode
	match key:
		KEY_SPACE:
			set_paused(not paused)
		KEY_L:
			set_lamps_enabled(not lamps_on)
		KEY_R:
			set_reflection_enabled(not reflection_on)
		KEY_N:
			set_normals_enabled(not normals_on)
		KEY_F:
			set_debug_enabled(not debug_on)
		KEY_V:
			set_normal_view(not normal_view)
		KEY_H:
			set_ui_visible(not ui_visible)
		KEY_C:
			cycle_light_preset()
		KEY_LEFT:
			set_light_angle(light_angle_deg - 5.0)
		KEY_RIGHT:
			set_light_angle(light_angle_deg + 5.0)
		KEY_UP:
			set_light_energy(light_energy + 0.08)
		KEY_DOWN:
			set_light_energy(light_energy - 0.08)
		KEY_BRACKETLEFT:
			set_wave_speed(wave_speed - 0.1)
		KEY_BRACKETRIGHT:
			set_wave_speed(wave_speed + 0.1)
		KEY_MINUS:
			set_wave_amplitude(wave_amplitude - 1.0)
		KEY_EQUAL:
			set_wave_amplitude(wave_amplitude + 1.0)
		KEY_0:
			reset_scene()
		_:
			return
	_hud.sync_from_main()
