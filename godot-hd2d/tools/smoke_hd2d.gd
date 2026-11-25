extends SceneTree

# Headless 自测：场景/2D 光照/长影/移轴参数/17 taps/焦带公式/UI 分层/开关/暂停。
# 用法：godot --headless --path godot-hd2d -s tools/smoke_hd2d.gd
# 成功末行：HD2D_SMOKE_OK checks=N

var checks := 0
var failures := 0
var _scene: Node
var _texts: Array[String] = []


func _initialize() -> void:
	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	await process_frame
	await create_timer(0.25).timeout
	await _run()
	_scene.queue_free()
	_scene = null
	_texts.clear()
	await process_frame
	await process_frame
	if failures == 0:
		print("HD2D_SMOKE_OK checks=%d" % checks)
		quit(0)
	else:
		printerr("HD2D_SMOKE_FAILED fails=%d checks=%d" % [failures, checks])
		quit(1)


func _run() -> void:
	await process_frame
	var world: HD2DWorld = _scene.world
	var hud: HD2DHud = _scene.hud
	var sun := world.get_sun()
	_check(world != null, "world exists")
	_check(hud != null and hud is CanvasLayer, "HUD is CanvasLayer")
	_check(sun is DirectionalLight2D, "sun is DirectionalLight2D")
	_check(world.ambient is CanvasModulate, "ambient is CanvasModulate")
	_check(world.get_occluder_count() >= 12, "LightOccluder2D count >= 12")
	_check(world.get_shadow_count() >= 8, "projected shadow casters >= 8")
	_check(world.get_lantern_count() == 2, "2 lantern point lights")
	_check(world.get_firefly_count() >= 20, "fireflies present")
	_check(world.get_crop_count() >= 40, "crop sprites present")
	_check(world.get_farmer() != null, "farmer exists")
	_check(world.sun.shadow_enabled == world.real_shadows_enabled(),
			"Light2D shadow enabled only on real-shadow renderer")
	_check(world.custom_shadows_enabled() == (not world.real_shadows_enabled()),
			"custom projected shadow path selected on GL")
	_check(world.get_farmer().get_node_or_null("AnimatedSprite2D") != null
			or _has_child_of_type(world.get_farmer(), "AnimatedSprite2D"),
			"farmer animated sprite")

	# 相机/像素对齐
	_check(_scene.camera is Camera2D, "2D camera")
	_check(is_equal_approx(_scene.camera.zoom.x, _scene.pixel_scale),
			"camera zoom matches pixel scale")
	_check(root.snap_2d_transforms_to_pixel and root.snap_2d_vertices_to_pixel,
			"pixel snapping enabled")
	_check(_scene.world.get_child_count() > 100, "world populated")

	# 光照方向 → 太阳旋转 + 长影方向随动
	_scene.set_light_angle(-38.0)
	var dir_a: Vector2 = world.shadow_direction()
	var t_a: Transform2D = world.get_farmer_shadow_transform()
	_scene.set_light_angle(38.0)
	var dir_b: Vector2 = world.shadow_direction()
	var t_b: Transform2D = world.get_farmer_shadow_transform()
	_check(absf(sun.rotation - deg_to_rad(38.0)) < 0.001, "sun rotation follows slider")
	_check(dir_a.distance_to(dir_b) > 0.5, "shadow direction changes with light angle")
	_check(t_a.origin.distance_to(t_b.origin) > 4.0, "cast shadow transform updates")
	_check(is_equal_approx(dir_a.length(), 1.0), "shadow direction normalized")

	# 光强/昼夜/暖冷
	var day_ambient: Color = world.ambient.color
	_scene.set_light_energy(0.5)
	_check(absf(sun.energy - 0.5) < 0.01, "light energy follows slider")
	_scene.set_night(true)
	_check(world.ambient.color.v < day_ambient.v, "night ambient darker")
	_check(world.lantern_lights[0].visible and world.lantern_lights[0].energy > 0.5,
			"lantern lights on at night")
	_check(world.fireflies[0].visible, "fireflies visible at night")
	_check(absf(float(_scene.atmos_mat.get_shader_parameter("night")) - 1.0) < 0.01,
			"atmosphere night uniform")
	_scene.set_night(false)
	_check(not world.lantern_lights[0].visible, "lantern lights off in daytime")

	# 移轴参数
	_scene.set_focus_y(0.42)
	_scene.set_band_half(0.10)
	_scene.set_feather(0.15)
	_scene.set_strength(0.8)
	_scene.set_radius(22.0)
	var mat: ShaderMaterial = _scene.post_mat
	_check(is_equal_approx(float(mat.get_shader_parameter("focus_y")), 0.42),
			"focus uniform")
	_check(is_equal_approx(float(mat.get_shader_parameter("band_half")), 0.10),
			"band uniform")
	_check(is_equal_approx(float(mat.get_shader_parameter("feather")), 0.15),
			"feather uniform")
	_check(is_equal_approx(float(mat.get_shader_parameter("strength")), 0.8),
			"strength uniform")
	_check(is_equal_approx(float(mat.get_shader_parameter("radius_px")), 22.0),
			"radius uniform")
	_check(_scene.post_rect is ColorRect and _scene.post_rect.material is ShaderMaterial,
			"post ColorRect + ShaderMaterial")

	# 焦带公式（与 shader 一致）
	_scene.set_focus_y(0.50)
	_scene.set_band_half(0.10)
	_scene.set_feather(0.20)
	_check(is_equal_approx(_scene.sample_band_weight(0.50), 0.0), "band: center sharp")
	_check(is_equal_approx(_scene.sample_band_weight(0.40), 0.0), "band: edge sharp")
	_check(_scene.sample_band_weight(0.30) > 0.0
			and _scene.sample_band_weight(0.30) < 1.0, "band: shoulder")
	_check(_scene.sample_band_weight(0.70) > _scene.sample_band_weight(0.60),
			"band: monotonic away from focus")
	_check(is_equal_approx(_scene.sample_band_weight(0.0), 1.0), "band: far edge fully blurred")

	# shader 结构：17 taps（3 处 texture 调用 × 循环 8 次 + 中心）权重和 28，焦内早退。
	var shader_text := FileAccess.get_file_as_string("res://shaders/tilt_shift.gdshader")
	_check(shader_text.contains("hint_screen_texture"), "shader reads screen texture")
	_check(shader_text.contains("for (int i = 0; i < 8; i++)"), "shader 8-ring loop")
	_check(_count_occurrences(shader_text, "texture(screen_tex") == 4,
			"17 taps: bokeh 3 samples x 8 loop + 1 early-return sample")
	_check(shader_text.contains("sum / 28.0"), "bokeh weights sum 28")
	_check(shader_text.contains("if (r < 0.5)") and shader_text.contains("COLOR = center"),
			"sharp band early point return")
	_check(shader_text.contains("uniform float radius_px"), "radius uniform in shader")

	# UI 分层与内容
	_check(hud.layer > _scene.post_layer.layer, "HUD layer above post layer")
	_check(hud.get_parent() == _scene, "HUD sibling of world/post, not child of post")
	var backbuffer := _find_child(_scene.post_layer, "BackBufferCopy")
	_check(backbuffer != null, "BackBufferCopy exists")
	_check(backbuffer != null and backbuffer.get_index() < _scene.post_rect.get_index(),
			"BackBufferCopy precedes post ColorRect")
	_collect_texts(hud)
	_check(_texts.has("焦点位置") or _has_text("焦点位置"), "Chinese label: focus")
	_check(_has_text("焦带宽度"), "Chinese label: band width")
	_check(_has_text("模糊强度"), "Chinese label: strength")
	_check(_has_text("散景半径"), "Chinese label: radius")
	_check(_has_text("光方向"), "Chinese label: light angle")
	_check(_has_text("移轴控制台"), "Chinese label: panel title")
	_check(_has_text("晨光") and _has_text("黄昏") and _has_text("夜灯"), "light presets")
	_check(_count_type(hud, "HSlider") >= 8, "8+ parameter sliders")
	_check(_has_text("FPS") and _has_text("Draw"), "FPS / draw calls label present")
	_check(hud.font is FontFile, "bundled CJK font loaded")
	_check(ResourceLoader.exists(hud.FONT_PATH), "bundled CJK font resource exists")
	_check(hud.ui_scale > 0.0, "HUD UI scale set")

	# 前后对比 / UI 显隐 / 暂停
	_scene.set_post_enabled(false)
	_check(_scene.post_rect.visible == false, "before mode hides tilt-shift")
	_check(_scene.api_snapshot()["post_enabled"] == false, "snapshot reflects before")
	_scene.set_post_enabled(true)
	_check(_scene.post_rect.visible == true, "after mode shows tilt-shift")
	_scene.set_ui_visible(false)
	_check(hud.visible == false, "UI hide")
	_scene.set_ui_visible(true)
	_check(hud.visible == true, "UI show")

	_scene.set_paused(true)
	var anim0: float = world.get_animation_time()
	await create_timer(0.16).timeout
	var anim1: float = world.get_animation_time()
	_check(world.paused and world.get_farmer().paused, "pause propagates")
	_check(is_equal_approx(anim0, anim1), "pause freezes animation time")
	_texts.clear()
	_collect_texts(hud)
	_check(_has_text("继续"), "pause button shows continue")
	_scene.set_paused(false)
	await create_timer(0.16).timeout
	_check(world.get_animation_time() > anim1, "resume advances animation time")

	# 预设/重置
	_scene.apply_preset("night")
	_check(_scene.night == true, "night preset")
	_scene.apply_preset("morning")
	_check(_scene.night == false and absf(_scene.light_angle + 38.0) < 0.01,
			"morning preset resets light")
	_scene.set_focus_y(0.9)
	_scene.reset_params()
	_check(absf(_scene.focus_y - 0.60) < 0.001, "reset focus")
	_check(_scene.post_enabled and not _scene.paused, "reset switches and pause")

	# 2D only
	_check(_count_type(_scene, "Camera3D") == 0, "no 3D camera")
	_check(_count_type(_scene, "WorldEnvironment") == 0, "no 3D environment")


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL ", label)


func _has_text(fragment: String) -> bool:
	for t in _texts:
		if t.contains(fragment):
			return true
	return false


func _collect_texts(node: Node) -> void:
	for child in node.get_children():
		if child is Label:
			_texts.append((child as Label).text)
		elif child is Button:
			_texts.append((child as Button).text)
		_collect_texts(child)


func _count_type(node: Node, type_name: String) -> int:
	var n := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		n += _count_type(child, type_name)
	return n


func _find_child(node: Node, name_fragment: String) -> Node:
	for child in node.get_children():
		if String(child.name).contains(name_fragment):
			return child
		var found := _find_child(child, name_fragment)
		if found != null:
			return found
	return null


func _has_child_of_type(node: Node, type_name: String) -> bool:
	for child in node.get_children():
		if child.is_class(type_name):
			return true
		if _has_child_of_type(child, type_name):
			return true
	return false


func _count_occurrences(text: String, needle: String) -> int:
	var count := 0
	var start := 0
	while true:
		var index := text.find(needle, start)
		if index < 0:
			break
		count += 1
		start = index + needle.length()
	return count
