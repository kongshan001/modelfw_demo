class_name VFXFactory
extends RefCounted

# 程序化 2D 特效：粒子 + Line2D/Polygon2D 组合，不依赖外部素材。
# headless 下跳过所有节点创建，但仍正常返回，方便冒烟测试与门禁。

var visuals_enabled := true

var _rng := RandomNumberGenerator.new()
var _scene_tree: SceneTree
var _layer: Node2D
var _ui_layer: CanvasLayer

static var _soft_texture: ImageTexture

func _init(p_tree: SceneTree, p_layer: Node2D, p_ui_layer: CanvasLayer = null, seed_value: int = 9001) -> void:
	_scene_tree = p_tree
	_layer = p_layer
	_ui_layer = p_ui_layer
	_rng.seed = seed_value
	visuals_enabled = DisplayServer.get_name() != "headless"

func play_skill(visual_id: StringName, position: Vector2) -> void:
	if not visuals_enabled:
		return
	match visual_id:
		&"slash":
			slash(position)
		&"fire":
			fire(position)
		&"thunder":
			thunder(position)
		&"seal":
			seal(position)
		&"heal":
			heal(position)
		&"poison":
			poison(position)
		&"aoe":
			aoe(position)
		&"buff":
			buff(position)
		_:
			generic(position)

func play_impact(visual_id: StringName, position: Vector2) -> void:
	if not visuals_enabled:
		return
	play_skill(visual_id, position)

func slash(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	for index in 3:
		var arc := Line2D.new()
		var points := PackedVector2Array()
		for step in 13:
			var t := float(step) / 12.0
			var angle := lerpf(-2.5, 0.8, t)
			var radius := 72.0 + index * 12.0
			points.append(Vector2(cos(angle) * radius, sin(angle) * radius * 0.72))
		arc.points = points
		arc.width = 11.0 - index * 3.5
		arc.default_color = Color(1.0, 0.96 - index * 0.14, 0.66 - index * 0.16, 0.95)
		arc.antialiased = true
		root.add_child(arc)
	root.scale = Vector2(0.55, 0.55)
	_burst(root, Color(1.0, 0.95, 0.7, 0.9), 16, 0.45, 80.0, 260.0, Vector3.UP, 110.0, Vector3(0, 260, 0), 0.18, 0.5)
	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(root, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tween.chain().tween_callback(root.queue_free)

func fire(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var flash := _flash(root, 52.0, Color(1.0, 0.5, 0.12, 0.55))
	var flash_tween := flash.create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(2.0, 2.0), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5)
	_burst(root, Color(1.0, 0.58, 0.12, 0.95), 32, 0.85, 90.0, 280.0, Vector3.UP, 80.0, Vector3(0, -130, 0), 0.35, 1.0)
	_burst(root, Color(1.0, 0.92, 0.45, 0.95), 14, 0.65, 40.0, 170.0, Vector3.UP, 70.0, Vector3(0, -90, 0), 0.16, 0.42)
	_schedule_free(root, 0.45, 0.5)

func thunder(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	for layer in 2:
		var bolt := Line2D.new()
		var points := PackedVector2Array()
		var steps := 9
		for step in steps:
			var t := float(step) / float(steps - 1)
			var y := lerpf(-540.0, 24.0, t)
			var jitter := 0.0 if step == 0 or step == steps - 1 else _rng.randf_range(-42.0, 42.0) * (1.0 - layer * 0.35)
			points.append(Vector2(jitter, y))
		bolt.points = points
		bolt.width = 16.0 if layer == 0 else 6.0
		bolt.default_color = Color(0.55, 0.75, 1.0, 0.35) if layer == 0 else Color(0.9, 0.97, 1.0, 0.95)
		bolt.antialiased = true
		root.add_child(bolt)
	_burst(root, Color(0.75, 0.88, 1.0, 0.9), 24, 0.55, 120.0, 340.0, Vector3.UP, 150.0, Vector3(0, 160, 0), 0.2, 0.6)
	screen_flash(Color(0.9, 0.95, 1.0), 0.38)
	_schedule_free(root, 0.12, 0.32)

func heal(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var ring := _ring(root, 72.0, Color(0.45, 1.0, 0.6, 0.9), 5.0)
	ring.position = Vector2(0, 62)
	ring.scale = Vector2(0.4, 0.14)
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.5, 0.5), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.75).set_delay(0.15)
	var motes := _burst(root, Color(0.55, 1.0, 0.65, 0.95), 28, 1.0, 45.0, 130.0, Vector3.UP, 26.0, Vector3(0, -28, 0), 0.22, 0.5)
	motes.position = Vector2(0, 58)
	_burst(root, Color(0.9, 1.0, 0.9, 0.9), 12, 0.9, 30.0, 90.0, Vector3.UP, 40.0, Vector3(0, -20, 0), 0.12, 0.3).position = Vector2(0, 40)
	var glow := _flash(root, 44.0, Color(0.4, 1.0, 0.55, 0.3))
	var glow_tween := glow.create_tween()
	glow_tween.tween_property(glow, "scale", Vector2(1.8, 1.8), 0.6)
	glow_tween.parallel().tween_property(glow, "modulate:a", 0.0, 0.6)
	_schedule_free(root, 0.6, 0.45)

func seal(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var ring := _ring(root, 78.0, Color(0.82, 0.45, 1.0, 0.95), 6.0)
	ring.scale = Vector2(0.3, 0.3)
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.15, 1.15), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "rotation", TAU * 0.8, 0.9)
	for index in 6:
		var angle := TAU * float(index) / 6.0
		var rune := Polygon2D.new()
		rune.polygon = PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(0, 20)])
		rune.color = Color(1.0, 0.85, 0.4, 0.9)
		rune.position = Vector2(cos(angle), sin(angle)) * 92.0
		rune.rotation = angle + PI / 2.0
		root.add_child(rune)
	var glyph := Label.new()
	glyph.text = "封"
	glyph.add_theme_font_override("font", FontUtil.cjk_font())
	glyph.add_theme_font_size_override("font_size", 72)
	glyph.add_theme_color_override("font_color", Color(0.95, 0.75, 1.0, 1.0))
	glyph.add_theme_color_override("font_outline_color", Color(0.35, 0.08, 0.5, 0.95))
	glyph.add_theme_constant_override("outline_size", 8)
	glyph.position = Vector2(-36, -58)
	root.add_child(glyph)
	_burst(root, Color(0.82, 0.5, 1.0, 0.9), 20, 0.8, 40.0, 160.0, Vector3.UP, 120.0, Vector3(0, 60, 0), 0.18, 0.45)
	_schedule_free(root, 0.55, 0.5)

func poison(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	_flash(root, 40.0, Color(0.55, 0.25, 0.75, 0.35))
	_burst(root, Color(0.55, 0.95, 0.35, 0.9), 20, 0.9, 30.0, 110.0, Vector3.UP, 55.0, Vector3(0, -35, 0), 0.25, 0.65)
	_burst(root, Color(0.72, 0.4, 1.0, 0.9), 16, 1.0, 25.0, 95.0, Vector3.UP, 45.0, Vector3(0, -25, 0), 0.2, 0.55)
	_schedule_free(root, 0.55, 0.45)

func aoe(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var ring := _ring(root, 105.0, Color(1.0, 0.55, 0.2, 0.9), 7.0)
	ring.scale = Vector2(0.25, 0.09)
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.7, 0.6), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.6)
	var fill := _flash(root, 90.0, Color(1.0, 0.6, 0.2, 0.22))
	fill.scale = Vector2(1.0, 0.35)
	var fill_tween := fill.create_tween()
	fill_tween.tween_property(fill, "scale", Vector2(1.7, 0.6), 0.55)
	fill_tween.parallel().tween_property(fill, "modulate:a", 0.0, 0.55)
	_burst(root, Color(1.0, 0.7, 0.35, 0.9), 22, 0.7, 60.0, 190.0, Vector3.UP, 60.0, Vector3(0, 180, 0), 0.25, 0.6)
	_schedule_free(root, 0.35, 0.35)

func buff(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var ring := _ring(root, 64.0, Color(1.0, 0.85, 0.35, 0.9), 5.0)
	ring.position = Vector2(0, 58)
	ring.scale = Vector2(0.5, 0.18)
	var ring_tween := ring.create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(1.35, 0.45), 0.55)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.6).set_delay(0.1)
	var motes := _burst(root, Color(1.0, 0.86, 0.4, 0.95), 20, 0.9, 40.0, 120.0, Vector3.UP, 30.0, Vector3(0, -20, 0), 0.2, 0.45)
	motes.position = Vector2(0, 55)
	_schedule_free(root, 0.5, 0.4)

func cast_ring(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var ring := _ring(root, 58.0, Color(0.7, 0.9, 1.0, 0.85), 4.0)
	ring.scale = Vector2(0.35, 0.12)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(1.1, 0.38), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.32)
	_burst(root, Color(0.75, 0.9, 1.0, 0.8), 10, 0.4, 20.0, 70.0, Vector3.UP, 50.0, Vector3(0, -20, 0), 0.12, 0.3)
	_schedule_free(root, 0.12, 0.25)

func generic(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	var flash := _flash(root, 42.0, Color(1.0, 0.92, 0.7, 0.7))
	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector2(2.2, 2.2), 0.3)
	tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	_burst(root, Color(1.0, 0.95, 0.8, 0.9), 18, 0.5, 70.0, 220.0, Vector3.UP, 160.0, Vector3(0, 150, 0), 0.16, 0.42)
	_schedule_free(root, 0.2, 0.3)

func death_burst(position: Vector2) -> void:
	if not visuals_enabled:
		return
	var root := _root(position)
	_flash(root, 54.0, Color(0.12, 0.05, 0.2, 0.55))
	_burst(root, Color(0.42, 0.18, 0.62, 0.9), 26, 0.9, 50.0, 190.0, Vector3.UP, 180.0, Vector3(0, 110, 0), 0.25, 0.7)
	_burst(root, Color(0.85, 0.8, 0.95, 0.8), 14, 0.7, 40.0, 150.0, Vector3.UP, 160.0, Vector3(0, 80, 0), 0.12, 0.35)
	_schedule_free(root, 0.35, 0.5)

func screen_flash(color: Color = Color.WHITE, alpha: float = 0.3) -> void:
	if not visuals_enabled or _ui_layer == null:
		return
	var rect := ColorRect.new()
	rect.color = Color(color.r, color.g, color.b, alpha)
	rect.size = Vector2(1920, 1080)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.z_index = 100
	_ui_layer.add_child(rect)
	var tween := rect.create_tween()
	tween.tween_property(rect, "color:a", 0.0, 0.22)
	tween.tween_callback(rect.queue_free)

func _root(position: Vector2, z: int = 20) -> Node2D:
	var root := Node2D.new()
	root.position = position
	root.z_index = z
	_layer.add_child(root)
	return root

func _ring(parent: Node2D, radius: float, color: Color, width: float) -> Line2D:
	var ring := Line2D.new()
	ring.points = _circle_points(radius)
	ring.width = width
	ring.default_color = color
	ring.antialiased = true
	parent.add_child(ring)
	return ring

func _flash(parent: Node2D, radius: float, color: Color) -> Polygon2D:
	var flash := Polygon2D.new()
	flash.polygon = _circle_points(radius)
	flash.color = color
	parent.add_child(flash)
	return flash

func _burst(parent: Node2D, color: Color, amount: int, lifetime: float, velocity_min: float, velocity_max: float, direction: Vector3, spread: float, gravity: Vector3, scale_min: float, scale_max: float) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.texture = _soft_circle_texture()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.local_coords = false
	particles.z_index = 2
	var material := ParticleProcessMaterial.new()
	material.direction = direction
	material.spread = spread
	material.initial_velocity_min = velocity_min
	material.initial_velocity_max = velocity_max
	material.gravity = gravity
	material.color = color
	material.scale_min = scale_min
	material.scale_max = scale_max
	material.damping_min = 10.0
	material.damping_max = 30.0
	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true
	return particles

func _schedule_free(node: Node, hold: float, fade: float) -> void:
	var tween := node.create_tween()
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(node, "modulate:a", 0.0, fade)
	tween.tween_callback(node.queue_free)

static func _circle_points(radius: float, count: int = 40) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in count + 1:
		var angle := TAU * float(index) / float(count)
		points.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	return points

static func _soft_circle_texture() -> ImageTexture:
	if _soft_texture != null:
		return _soft_texture
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var distance := Vector2(x - 15.5, y - 15.5).length() / 16.0
			image.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - distance, 0.0, 1.0)))
	_soft_texture = ImageTexture.create_from_image(image)
	return _soft_texture
