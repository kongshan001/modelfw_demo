extends SceneTree

# Headless 验收：精灵/法线图加载、Shader 参数、光源移动与暂停、
# 法线开关、调试视图、原生 CanvasTexture+Light2D 路径、翻转/缩放、
# 暂停/重置、像素完美与导入设置。
# 用法：godot --headless --path godot-sprite-normal-light \
#          -s tools/smoke_sprite_normal_light.gd
# 末行：SPRITE_NORMAL_LIGHT_SMOKE_OK checks=N

var _checks := 0
var _failures: Array[String] = []
var _scene
var _world
var _hud


func _initialize() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await process_frame
	_world = _scene.get_node("World")
	_hud = _scene.get_node("HUD")

	await _check_assets()
	await _check_shader()
	await _check_light_motion()
	await _check_toggles()
	await _check_native_path()
	await _check_flip_scale()
	await _check_reset()
	await _check_scene_shape()

	var summary := "checks=%d failures=%d" % [_checks, _failures.size()]
	if _failures.is_empty():
		print("SMOKE_SUMMARY ", summary)
		print("SPRITE_NORMAL_LIGHT_SMOKE_OK")
		quit(0)
	else:
		for f in _failures:
			printerr("SMOKE_FAIL ", f)
		printerr("SPRITE_NORMAL_LIGHT_SMOKE_FAIL ", summary)
		quit(1)


func _check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(label)


func _check_assets() -> void:
	var entries: Dictionary = _world.get_entries()
	_check(entries.size() == 5, "five lit sprites (wall/floor/guardian/barrel/golem)")
	var expected := {
		"room_wall": Vector2i(320, 116),
		"room_floor": Vector2i(320, 64),
		"guardian": Vector2i(64, 88),
		"barrel": Vector2i(44, 54),
		"golem": Vector2i(36, 48),
	}
	for name in expected:
		_check(entries.has(name), "has entry " + name)
		if not entries.has(name):
			continue
		var e: Dictionary = entries[name]
		var albedo: Texture2D = e["albedo"]
		var normal: Texture2D = e["normal"]
		_check(albedo != null and normal != null, name + " albedo/normal loaded")
		_check(Vector2i(albedo.get_size()) == expected[name], name + " albedo size")
		_check(Vector2i(normal.get_size()) == expected[name], name + " normal size")
		var img: Image = normal.get_image()
		_check(img != null and img.get_width() == expected[name].x, name + " normal image readable")
		var min_a := 1.0
		var max_a := 0.0
		var nonflat := false
		var w := img.get_width()
		var h := img.get_height()
		for y in range(0, h, maxi(1, h / 16)):
			for x in range(0, w, maxi(1, w / 16)):
				var c := img.get_pixel(x, y)
				if c.a < 0.05:
					continue
				min_a = minf(min_a, c.a)
				max_a = maxf(max_a, c.a)
				if absf(c.r - 0.5) > 0.03 or absf(c.g - 0.5) > 0.03:
					nonflat = true
		_check(nonflat, name + " normal map is not flat")
		if name in ["guardian", "barrel", "golem"]:
			_check(max_a - min_a > 0.05, name + " roughness alpha varies")
		var sprite: Sprite2D = e["sprite"]
		_check(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
				name + " nearest filtering")
		_check(sprite.centered == false, name + " centered=false")
		_check(Vector2(sprite.position) == Vector2(sprite.position).round(),
				name + " integer position")
		_check(sprite.material is ShaderMaterial, name + " shader material in shader path")
		var mat: ShaderMaterial = e["material"]
		_check(mat.shader != null and mat.shader.resource_path.ends_with(
				"sprite_normal_light.gdshader"), name + " custom shader attached")
		_check(mat.get_shader_parameter("normal_tex") == normal,
				name + " normal texture bound to shader")
		var ct: CanvasTexture = e["canvas_texture"]
		_check(ct.diffuse_texture == albedo and ct.normal_texture == normal,
				name + " native CanvasTexture diffuse+normal")

	# normal map import is a real normal map (lossless, green-up)
	for name in expected:
		var path := "res://assets/sprites/%s_normal.png.import" % name
		var f := FileAccess.open(path, FileAccess.READ)
		_check(f != null, name + " import file readable")
		if f != null:
			var text := f.get_as_text()
			_check(text.contains("compress/normal_map=2"), name + " imported as normal map")
			_check(text.contains("process/normal_map_invert_y=false"), name + " green stays +Y")
			_check(text.contains("mipmaps/generate=false"), name + " no mipmaps")
	# shader source keeps the key lighting math
	var sf := FileAccess.open("res://shaders/sprite_normal_light.gdshader", FileAccess.READ)
	_check(sf != null, "shader source readable")
	if sf != null:
		var src := sf.get_as_text()
		_check(src.contains("hint_normal"), "shader uses hint_normal")
		_check(src.contains("transpose(inverse(basis))"), "normal matrix inverse-transpose")
		_check(src.contains("flip_x"), "shader supports flip_x")
		_check(src.contains("u_spec_strength") and src.contains("u_roughness"),
				"shader exposes spec/roughness")
		_check(src.contains("u_rim_strength"), "shader has rim term")
		_check(src.contains("u_light_height"), "shader uses light height")


func _check_shader() -> void:
	_scene.set_light_angle(123.0)
	var p: Dictionary = _scene.get_params()
	_check(absf(float(p["angle"]) - 123.0) < 0.01, "angle parameter applied")
	_check(_scene.is_point_mode(), "starts in point-light mode")
	var pos: Vector2 = scene_light_pos()
	_check(pos.distance_to(_scene.get_orbit_center()) > 20.0, "point light position on orbit")

	_scene.set_light_height(91.0)
	_scene.set_light_energy(1.83)
	_scene.set_normal_strength(1.37)
	_scene.set_spec_strength(0.93)
	_scene.set_roughness(0.31)
	_scene.set_ambient_strength(0.64)
	_scene.set_rim_strength(0.42)
	p = _scene.get_params()
	_check(absf(float(p["height"]) - 91.0) < 0.01, "light height applied")
	_check(absf(float(p["energy"]) - 1.83) < 0.01, "light energy applied")
	_check(absf(float(p["normal_strength"]) - 1.37) < 0.01, "normal strength applied")
	_check(absf(float(p["spec"]) - 0.93) < 0.01, "specular applied")
	_check(absf(float(p["rough"]) - 0.31) < 0.01, "roughness applied")
	_check(absf(float(p["ambient"]) - 0.64) < 0.01, "ambient applied")
	_check(absf(float(p["rim"]) - 0.42) < 0.01, "rim applied")
	# direction vector debug math is finite and normalized
	var l: Vector3 = _scene.get_light_vector_at(Vector2(202, 124))
	_check(l.length() > 0.99 and l.length() < 1.01, "light vector normalized")
	_check(l.z > 0.0, "light vector points above the plane")


func _check_light_motion() -> void:
	_scene.set_light_angle(20.0)
	_scene.set_playing(true)
	_scene.set_auto_orbit(true)
	var before_angle: float = float(_scene.get_params()["angle"])
	var before_pos: Vector2 = scene_light_pos()
	_scene.simulate(1.0)
	var after_angle: float = float(_scene.get_params()["angle"])
	var after_pos: Vector2 = scene_light_pos()
	_check(absf(after_angle - before_angle) > 5.0, "auto orbit advances angle")
	_check(after_pos.distance_to(before_pos) > 2.0, "auto orbit moves the point light")

	_scene.set_playing(false)
	var paused_angle: float = float(_scene.get_params()["angle"])
	_scene.simulate(1.0)
	_check(absf(float(_scene.get_params()["angle"]) - paused_angle) < 0.001,
			"pause freezes simulated light motion")
	_check(_scene.is_paused(), "paused state exposed")

	_scene.set_playing(true)
	_scene.set_auto_orbit(false)
	_scene.set_light_angle(45.0)
	var a1: float = float(_scene.get_params()["angle"])
	var p1: Vector2 = scene_light_pos()
	_scene.set_light_angle(210.0)
	var p2: Vector2 = scene_light_pos()
	_check(p2.distance_to(p1) > 40.0, "manual angle moves the light")
	_scene.set_point_mode(false)
	_check(not _scene.is_point_mode(), "directional mode switch")
	var l2: Vector3 = _scene.get_light_vector_at(Vector2(202, 124))
	_check(l2.z > 0.0 and l2.length() > 0.99, "directional light vector valid")
	_scene.set_point_mode(true)
	_scene.set_auto_orbit(true)


func _check_toggles() -> void:
	_scene.set_normals_on(false)
	var p: Dictionary = _scene.get_params()
	_check(not bool(p["normals"]), "normals off toggle")
	for name in _world.get_entries():
		var mat: ShaderMaterial = _world.get_entries()[name]["material"]
		_check(mat.get_shader_parameter("normal_tex") != null, name + " normal stays bound when off")
	_scene.set_normals_on(true)
	_check(bool(_scene.get_params()["normals"]), "normals on toggle")

	_scene.set_debug_mode(0)
	_check(not _scene.is_debug_enabled(), "debug off")
	_scene.cycle_debug()
	_check(int(_scene.get_params()["debug"]) == 1, "debug cycles to normal map")
	_scene.cycle_debug()
	_check(int(_scene.get_params()["debug"]) == 2, "debug cycles to light vector")
	_scene.cycle_debug()
	_check(int(_scene.get_params()["debug"]) == 3, "debug cycles to diffuse")
	_scene.cycle_debug()
	_check(int(_scene.get_params()["debug"]) == 4, "debug cycles to lit + vectors")
	_scene.cycle_debug()
	_check(int(_scene.get_params()["debug"]) == 0, "debug cycles back to lit")

	var sliders: Dictionary = _hud.get("_sliders")
	_check(sliders != null and sliders.size() == 8, "HUD has 8 parameter sliders")
	_check(_hud.get_node_or_null("HUDRoot") != null, "HUD root exists")
	var overlay: Node = _scene.get_node_or_null("DebugOverlay")
	_check(overlay != null, "debug overlay exists")


func _check_native_path() -> void:
	_scene.set_native_mode(true)
	_check(_scene.is_native_mode(), "native mode flag")
	var rig = _scene.get_node("LightRig")
	var pl: PointLight2D = rig.get_node_or_null("NativePointLight")
	var fill: DirectionalLight2D = _scene.get_node_or_null("NativeFillLight")
	_check(pl != null and pl.enabled, "native PointLight2D enabled")
	_check(fill != null and fill.enabled, "native fill DirectionalLight2D enabled")
	var cm: CanvasModulate = _scene.get_node_or_null("CanvasModulate")
	_check(cm != null and cm.color != Color.WHITE, "native CanvasModulate ambient active")
	for name in _world.get_entries():
		var e: Dictionary = _world.get_entries()[name]
		var sprite: Sprite2D = e["sprite"]
		_check(sprite.material == null, name + " native mode drops custom material")
		_check(sprite.texture is CanvasTexture, name + " native mode uses CanvasTexture")
		var ct: CanvasTexture = sprite.texture
		_check(ct.normal_texture == e["normal"], name + " native normal texture bound")

	_scene.set_point_mode(false)
	_check(not _scene.is_point_mode(), "native directional selected")
	var dl: DirectionalLight2D = rig.get_node("NativeDirectionalLight")
	_check(dl.enabled, "native DirectionalLight2D enabled")
	_check(not pl.enabled, "point light disabled in directional mode")
	_scene.set_point_mode(true)
	_scene.set_native_mode(false)
	_check(not _scene.is_native_mode(), "back to shader path")
	_check(not pl.enabled and not fill.enabled, "native lights off in shader path")
	_check(cm.color == Color.WHITE, "CanvasModulate neutral in shader path")
	var guard: Sprite2D = _world.get_entry("guardian")["sprite"]
	_check(guard.material is ShaderMaterial, "shader material restored")


func _check_flip_scale() -> void:
	_scene.toggle_flip_test()
	var e: Dictionary = _world.get_entry("guardian")
	var sprite: Sprite2D = e["sprite"]
	var mat: ShaderMaterial = e["material"]
	_check(sprite.flip_h, "guardian flip_h")
	_check(float(mat.get_shader_parameter("flip_x")) == -1.0, "flip_x uniform -1")
	_scene.toggle_flip_test()
	_check(not sprite.flip_h, "guardian flip restored")
	_check(float(mat.get_shader_parameter("flip_x")) == 1.0, "flip_x uniform restored")

	var ge: Dictionary = _world.get_entry("golem")
	var gs: Sprite2D = ge["sprite"]
	var rest_pos: Vector2 = gs.position
	var size: Vector2i = ge["size"]
	var rest_feet := rest_pos + Vector2(size.x * 0.5, size.y)
	_scene.toggle_scale_test()
	_check(gs.scale == Vector2(2.0, 2.0), "golem scale test 2x")
	var scaled_feet := gs.position + Vector2(size.x, size.y * 2.0)
	_check(scaled_feet.distance_to(rest_feet) < 0.01, "scaled feet stay anchored")
	_scene.toggle_scale_test()
	_check(gs.scale == Vector2.ONE and gs.position == rest_pos, "golem scale restored")


func _check_reset() -> void:
	_scene.set_light_angle(77.0)
	_scene.set_native_mode(true)
	_scene.set_normals_on(false)
	_scene.set_debug_mode(2)
	_scene.toggle_flip_test()
	_scene.toggle_scale_test()
	_scene.reset()
	var p: Dictionary = _scene.get_params()
	_check(absf(float(p["angle"]) - 330.0) < 0.01, "reset angle")
	_check(absf(float(p["height"]) - 64.0) < 0.01, "reset height")
	_check(absf(float(p["energy"]) - 2.0) < 0.01, "reset energy")
	_check(absf(float(p["normal_strength"]) - 1.0) < 0.01, "reset normal strength")
	_check(absf(float(p["rough"]) - 0.5) < 0.01, "reset roughness")
	_check(absf(float(p["ambient"]) - 0.9) < 0.01, "reset ambient")
	_check(bool(p["normals"]) and int(p["debug"]) == 0, "reset normals/debug")
	_check(not bool(p["native"]) and bool(p["point"]) and bool(p["auto"]), "reset mode/auto")
	_check(not bool(p["flip"]) and not bool(p["scale"]), "reset flip/scale")
	_check(not _scene.is_paused(), "reset resumes")


func _check_scene_shape() -> void:
	var cameras: Array = _scene.find_children("*", "Camera2D", true, false)
	_check(cameras.size() == 1, "exactly one Camera2D")
	var cam: Camera2D = cameras[0]
	_check(cam.zoom == Vector2(4, 4), "camera zoom 4 for pixel-perfect art")
	var subviews: Array = _scene.find_children("*", "SubViewport", true, false)
	_check(subviews.is_empty(), "no SubViewport at runtime")
	_check(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 0,
			"project default texture filter is nearest")
	_check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true,
			"snap 2d transforms")
	_check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel") == true,
			"snap 2d vertices")
	_check(DisplayServer.get_name() != "", "display server available")


func scene_light_pos() -> Vector2:
	return _scene.get_light_pos()
