class_name HD2DWorld
extends Node2D

# 晨光农田：640×360 原创像素场景 + CanvasItem 2D 光照/长影。
# 画面元素全部程序化生成；光源与遮挡体在运行时组装。

const FARMER_SCRIPT := preload("res://scripts/farmer.gd")

const HOUSE_POS := Vector2(160, 66)
const WATER_POS := Vector2(404, 228)
const WINDOW_GLOWS := [Vector2(196, 146), Vector2(270, 146)]
const LANTERN_SPOTS := [Vector2(292, 194), Vector2(392, 268)]

var sun: DirectionalLight2D
var ambient: CanvasModulate
var lantern_lights: Array[PointLight2D] = []
var window_lights: Array[PointLight2D] = []
var lantern_glows: Array[Sprite2D] = []
var window_glows: Array[Sprite2D] = []
var fireflies: Array[Sprite2D] = []
var farmer: HD2DFarmer

var paused := false
var night := false
var warmth := 0.35
var angle_deg := -38.0
var energy := 0.75

var _crops: Array[Sprite2D] = []
var _crop_phase: Array[float] = []
var _firefly_base: Array[Vector2] = []
var _firefly_phase: Array[float] = []
var _time := 0.0
var _flow := 0.0
var _water_mat: ShaderMaterial
var _add_material: CanvasItemMaterial
var _occluder_count := 0

# GL Compatibility 在目标机（macOS / Intel HD 6000）上不渲染 Light2D 阴影，
# 因此用“沿光向压扁的剪影 sprite”实时投长影；支持真实阴影的渲染器上切回 Light2D 阴影。
var _texture_shadows: Array[Dictionary] = []
var _farmer_shadow: Sprite2D
var _shadow_material: CanvasItemMaterial
var _contact_material: CanvasItemMaterial
var _custom_shadows := true
var _real_shadows := false


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if paused:
		return
	_time += delta
	_flow += delta
	for i in _crops.size():
		_crops[i].rotation = sin(_time * 1.6 + _crop_phase[i]) * 0.018
	for i in fireflies.size():
		var p := _firefly_base[i]
		var ph := _firefly_phase[i]
		fireflies[i].position = p + Vector2(
			sin(_time * 0.7 + ph) * 5.0,
			cos(_time * 0.53 + ph * 1.7) * 3.5)
		fireflies[i].modulate.a = 0.45 + 0.35 * sin(_time * 2.3 + ph)
	if _water_mat != null:
		_water_mat.set_shader_parameter("flow", _flow)
	_refresh_dynamic_shadow()


func _build() -> void:
	_real_shadows = RenderingServer.get_rendering_device() != null
	_custom_shadows = not _real_shadows
	_add_material = CanvasItemMaterial.new()
	_add_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_add_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_shadow_material = CanvasItemMaterial.new()
	_shadow_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_shadow_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	_contact_material = CanvasItemMaterial.new()
	_contact_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_contact_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX

	ambient = CanvasModulate.new()
	add_child(ambient)

	var tex_ground := HD2DArt.make_ground()
	var tex_water := HD2DArt.make_water()
	var tex_house := HD2DArt.make_house()
	var tex_tree_big := HD2DArt.make_tree(0)
	var tex_tree_small := HD2DArt.make_tree(1)
	var tex_post := HD2DArt.make_lantern_post()
	var tex_fence := HD2DArt.make_fence()
	var tex_crop_a := HD2DArt.make_crop(0)
	var tex_crop_b := HD2DArt.make_crop(1)
	var tex_flower_a := HD2DArt.make_flower(0)
	var tex_flower_b := HD2DArt.make_flower(1)
	var tex_flower_c := HD2DArt.make_flower(2)
	var tex_rock := HD2DArt.make_rock()
	var tex_firefly := HD2DArt.make_firefly()
	var tex_bush_a := HD2DArt.make_bush(0)
	var tex_bush_b := HD2DArt.make_bush(1)
	var tex_hay := HD2DArt.make_hay()
	var tex_contact := HD2DArt.make_contact_shadow(34, 12)
	var tex_grass_l := HD2DArt.make_foreground_grass(200, 76, 771)
	var tex_grass_r := HD2DArt.make_foreground_grass(150, 68, 442)
	var tex_scarecrow := HD2DArt.make_scarecrow()
	var tex_dock := HD2DArt.make_dock()
	var glow_warm := HD2DArt.make_glow(Color("#ffc36a"), 64)
	var light_tex := HD2DArt.make_light_texture(128)
	var farmer_frames := HD2DArt.make_farmer_frames()

	_sprite(tex_ground, Vector2.ZERO, -1000)

	# 水面 + 动态反光（未暂停时流动）。
	var water := _sprite(tex_water, WATER_POS, -500)
	var glint := _sprite(tex_water, WATER_POS, -499)
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://shaders/water_glint.gdshader")
	_water_mat.set_shader_parameter("night", 0.0)
	glint.material = _water_mat
	glint.modulate = Color(1, 1, 1, 1)
	# 木栈桥（水面之上、前景草叶之下）。
	_sprite(tex_dock, Vector2(570, 244), -400)

	# 菜地里的秧苗：独立 sprite，可被光照亮；轻微摆动。
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	for row in [
		[242, 42, 148], [258, 42, 148], [274, 42, 148],
		[296, 42, 148], [312, 42, 148], [328, 42, 148],
		[258, 174, 236], [274, 174, 236], [290, 174, 236],
		[306, 174, 236], [322, 174, 236],
	]:
		var y: int = row[0]
		for x in range(row[1], row[2], 14):
			var tex := tex_crop_a if rng.randf() < 0.55 else tex_crop_b
			var crop := _sprite(tex, Vector2(x, y - 10), y + 12)
			crop.centered = true
			_crops.append(crop)
			_crop_phase.append(rng.randf() * TAU)

	# 野花与石块。
	for i in 18:
		var fx := rng.randi_range(16, 618)
		var fy := rng.randi_range(100, 342)
		if absf(float(fx) - 270.0) < 40.0 and fy > 190:
			continue
		var tex: Texture2D = [tex_flower_a, tex_flower_b, tex_flower_c][i % 3]
		_sprite(tex, Vector2(fx, fy), fy)
	for pos in [Vector2(58, 214), Vector2(348, 246), Vector2(606, 246), Vector2(430, 356)]:
		_sprite(tex_rock, pos, int(pos.y))

	# 栅栏。
	for x in range(18, 246, 26):
		_sprite(tex_fence, Vector2(x, 222), 234)
	for x in range(430, 620, 26):
		_sprite(tex_fence, Vector2(x, 232), 242)

	# 灌木与干草捆。
	for spot in [
		[Vector2(118, 208), tex_bush_a], [Vector2(338, 204), tex_bush_b],
		[Vector2(596, 220), tex_bush_a], [Vector2(442, 224), tex_bush_b],
	]:
		var bush_pos: Vector2 = spot[0]
		var bush_tex: Texture2D = spot[1]
		_sprite(bush_tex, bush_pos, int(bush_pos.y) + 24)
		_add_contact_shadow(Vector2(bush_pos.x + 17, bush_pos.y + 22), tex_contact, 1.3, 0.8)
	for spot in [Vector2(92, 226), Vector2(126, 230)]:
		_sprite(tex_hay, spot, int(spot.y) + 20)
		_add_contact_shadow(Vector2(spot.x + 15, spot.y + 19), tex_contact, 1.0, 0.7)
	# 田里的稻草人：与长影、菜地形成农场符号。
	_sprite(tex_scarecrow, Vector2(204, 226), 274)
	_add_contact_shadow(Vector2(219, 270), tex_contact, 1.0, 0.75)
	_add_scarecrow_occluder(Vector2(204, 226))
	_add_texture_shadow(tex_scarecrow, Vector2(219, 270), 68.0)

	# 农舍（z 以底边排序）。
	_sprite(tex_house, HOUSE_POS, int(HOUSE_POS.y) + 124)
	_add_contact_shadow(Vector2(232, 187), tex_contact, 3.6, 1.2)
	_add_house_occluder()
	_add_texture_shadow(tex_house, Vector2(232, 187), 128.0)
	for p in WINDOW_GLOWS:
		var glow := _add_glow(glow_warm, p, 34.0, 700)
		window_glows.append(glow)
		var light := PointLight2D.new()
		light.texture = light_tex
		light.position = p
		light.color = Color("#ffbc64")
		light.energy = 0.0
		light.texture_scale = 0.45
		light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(light)
		window_lights.append(light)

	# 树木与树冠/树干遮挡体。
	_add_tree(tex_tree_big, Vector2(398, 84), 96, 128, 0, tex_contact)
	_add_tree(tex_tree_small, Vector2(10, 118), 64, 90, 1, tex_contact)
	_add_tree(tex_tree_small, Vector2(584, 128), 64, 90, 2, tex_contact)
	_add_tree(tex_tree_small, Vector2(310, 36), 64, 90, 3, tex_contact)

	# 灯笼与暖色点光。
	for i in LANTERN_SPOTS.size():
		var pos: Vector2 = LANTERN_SPOTS[i]
		_sprite(tex_post, pos, int(pos.y) + 62)
		var head := pos + Vector2(9, 24)
		var glow := _add_glow(glow_warm, head, 62.0, 680)
		lantern_glows.append(glow)
		_add_contact_shadow(Vector2(pos.x + 10, pos.y + 61), tex_contact, 0.6, 0.6)
		var light := PointLight2D.new()
		light.texture = light_tex
		light.position = head
		light.color = Color("#ffb45f")
		light.energy = 0.0
		light.texture_scale = 0.8
		light.shadow_enabled = _real_shadows
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 2.0
		light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(light)
		lantern_lights.append(light)
		_add_lantern_occluder(pos)
		_add_texture_shadow(tex_post, pos + Vector2(10, 60), 72.0)

	# 农夫。
	farmer = FARMER_SCRIPT.new()
	add_child(farmer)
	farmer.setup(farmer_frames, glow_warm, light_tex)
	_farmer_shadow = _make_texture_shadow(
			farmer_frames.get_frame_texture("walk", 0))

	# 前景草叶剪影：只放在底部虚化带，给画面做前景框。
	_sprite(tex_grass_l, Vector2(0, 284), 900)
	_sprite(tex_grass_r, Vector2(490, 292), 901)

	# 萤火虫。
	for i in 26:
		var base: Vector2
		if i < 16:
			base = Vector2(rng.randf_range(418.0, 616.0), rng.randf_range(232.0, 344.0))
		else:
			base = Vector2(rng.randf_range(350.0, 470.0), rng.randf_range(100.0, 240.0))
		var s := _add_glow(tex_firefly, base, 8.0, 650)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		s.visible = false
		fireflies.append(s)
		_firefly_base.append(base)
		_firefly_phase.append(rng.randf() * TAU)

	# 方向光放在最后，确保已存在的遮挡体参与真实阴影贴图（若渲染器支持）。
	sun = DirectionalLight2D.new()
	sun.shadow_enabled = _real_shadows
	sun.shadow_filter = Light2D.SHADOW_FILTER_PCF5
	sun.shadow_filter_smooth = 2.0
	sun.max_distance = 1200.0
	add_child(sun)

	_apply_environment()
	_refresh_shadows()


func _sprite(tex: Texture2D, pos: Vector2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.position = pos
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)
	return s


func _add_glow(tex: Texture2D, pos: Vector2, size_px: float, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.position = pos
	s.z_index = z
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = _add_material
	var tex_size := float(tex.get_width())
	s.scale = Vector2.ONE * (size_px / tex_size)
	s.modulate = Color(1, 1, 1, 0)
	add_child(s)
	return s


func _add_tree(tex: Texture2D, pos: Vector2, w: int, h: int, variant: int,
		contact_tex: Texture2D) -> void:
	_sprite(tex, pos, int(pos.y) + h)
	var cx := float(w) * 0.5
	var cy := float(h) * 0.33
	var rx := float(w) * 0.43
	var ry := float(h) * 0.27
	var canopy := _ellipse_points(pos + Vector2(cx, cy), rx, ry, 14)
	var trunk := PackedVector2Array([
		pos + Vector2(cx - 5.0, float(h) * 0.48),
		pos + Vector2(cx + 5.0, float(h) * 0.48),
		pos + Vector2(cx + 6.0, float(h) - 3.0),
		pos + Vector2(cx - 6.0, float(h) - 3.0),
	])
	var local_canopy := PackedVector2Array()
	var local_trunk := PackedVector2Array()
	for p in canopy:
		local_canopy.append(p - pos)
	for p in trunk:
		local_trunk.append(p - pos)
	_add_occluder(local_canopy, pos, "tree_%d_a" % variant)
	_add_occluder(local_trunk, pos, "tree_%d_b" % variant)
	_add_texture_shadow(tex, pos + Vector2(cx, float(h) - 3.0), 104.0 if w > 80 else 82.0)
	_add_contact_shadow(pos + Vector2(cx, float(h) - 4.0), contact_tex,
			1.5 if w > 80 else 1.1, 0.85)


func _ellipse_points(center: Vector2, rx: float, ry: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var a := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


func _add_contact_shadow(pos: Vector2, tex: Texture2D, scale_x: float,
		scale_y: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.position = pos
	s.z_index = -449
	s.scale = Vector2(scale_x, scale_y)
	s.modulate = Color(1, 1, 1, 0.85)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.material = _contact_material
	add_child(s)
	return s


func _make_texture_shadow(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = _shadow_material
	s.z_index = -450
	s.visible = _custom_shadows
	add_child(s)
	return s


func _add_texture_shadow(tex: Texture2D, base: Vector2, length: float) -> Sprite2D:
	var s := _make_texture_shadow(tex)
	_texture_shadows.append({
		"node": s,
		"base": base,
		"length": length,
		"flip": 1,
	})
	return s


func _shadow_dir() -> Vector2:
	var r := deg_to_rad(angle_deg)
	return Vector2(-sin(r), cos(r)).normalized()


func _apply_texture_shadow(node: Sprite2D, base: Vector2, length: float,
		flip: int = 1) -> void:
	if node == null or node.texture == null:
		return
	var w := float(node.texture.get_width())
	var h := float(node.texture.get_height())
	var dir := _shadow_dir()
	var x_axis := Vector2(float(flip), 0.0)
	var y_axis := -dir * (length / h)
	var origin := base + dir * length - Vector2(float(flip) * w * 0.5, 0.0)
	node.transform = Transform2D(x_axis, y_axis, origin)
	node.modulate = _shadow_color()
	node.visible = _custom_shadows


func _shadow_color() -> Color:
	if night:
		return Color(0.025, 0.035, 0.065, 0.30)
	var warm := clampf(warmth, 0.0, 1.0)
	var cool := Color(0.065, 0.075, 0.105, 0.38)
	var hot := Color(0.090, 0.065, 0.060, 0.36)
	return cool.lerp(hot, warm)


func _refresh_shadows() -> void:
	if _shadow_material == null:
		return
	for spec in _texture_shadows:
		_apply_texture_shadow(spec.node as Sprite2D, spec.base as Vector2,
				float(spec.length), int(spec.flip))
	if _farmer_shadow != null and farmer != null:
		_apply_texture_shadow(_farmer_shadow, farmer.position, 56.0, farmer.facing())


func _refresh_dynamic_shadow() -> void:
	if not _custom_shadows or _farmer_shadow == null or farmer == null:
		return
	_apply_texture_shadow(_farmer_shadow, farmer.position, 56.0, farmer.facing())


func _add_scarecrow_occluder(pos: Vector2) -> void:
	_add_occluder(PackedVector2Array([
		Vector2(8, 0), Vector2(22, 0), Vector2(22, 46), Vector2(8, 46),
	]), pos, "scarecrow")


func _add_house_occluder() -> void:
	var poly := PackedVector2Array([
		Vector2(-2, 52), Vector2(28, 16), Vector2(116, 16),
		Vector2(146, 52), Vector2(146, 122), Vector2(-2, 122),
	])
	_add_occluder(poly, HOUSE_POS, "house")


func _add_lantern_occluder(pos: Vector2) -> void:
	_add_occluder(PackedVector2Array([
		Vector2(7, 0), Vector2(14, 0), Vector2(14, 62), Vector2(7, 62),
	]), pos, "lantern")
	_add_occluder(PackedVector2Array([
		Vector2(3, 18), Vector2(15, 18), Vector2(15, 31), Vector2(3, 31),
	]), pos, "lantern_head")


func _add_occluder(points: PackedVector2Array, pos: Vector2, tag: String) -> void:
	var poly := OccluderPolygon2D.new()
	poly.polygon = points
	var occ := LightOccluder2D.new()
	occ.occluder = poly
	occ.position = pos
	occ.name = "occ_" + tag
	add_child(occ)
	_occluder_count += 1


func _apply_environment() -> void:
	if ambient == null:
		return
	var warm := clampf(warmth, -1.0, 1.0)
	var neutral := Color("#fff0d2")
	var day_col := neutral.lerp(Color("#ffc46e"), warm) if warm >= 0.0 \
			else neutral.lerp(Color("#b9d4ff"), -warm)
	sun.color = day_col.lerp(Color("#9db4e8"), 0.78 if night else 0.0)
	sun.energy = energy * (0.34 if night else 1.0)
	sun.rotation = deg_to_rad(angle_deg)
	sun.shadow_enabled = _real_shadows

	var day_amb := Color("#6b776c")
	if warm >= 0.0:
		day_amb = day_amb.lerp(Color("#84755c"), warm)
	else:
		day_amb = day_amb.lerp(Color("#7d9099"), -warm)
	var night_amb := Color("#3b4661")
	ambient.color = day_amb.lerp(night_amb, 1.0 if night else 0.0)

	for i in lantern_lights.size():
		lantern_lights[i].visible = night
		lantern_lights[i].energy = 1.6 if night else 0.0
		lantern_lights[i].shadow_enabled = _real_shadows
		lantern_glows[i].modulate.a = 0.72 if night else 0.0
	for i in window_lights.size():
		window_lights[i].energy = 0.42 if night else 0.0
		window_glows[i].modulate.a = 0.62 if night else 0.0
	for f in fireflies:
		f.visible = night
	if farmer != null:
		farmer.set_night(night)
	if _water_mat != null:
		_water_mat.set_shader_parameter("night", 1.0 if night else 0.0)
	_refresh_shadows()


func set_environment(p_night: bool, p_warmth: float, p_angle: float, p_energy: float) -> void:
	night = p_night
	warmth = p_warmth
	angle_deg = p_angle
	energy = p_energy
	if sun != null:
		_apply_environment()


func set_paused(value: bool) -> void:
	paused = value
	if farmer != null:
		farmer.set_paused(value)


func get_sun() -> DirectionalLight2D:
	return sun


func get_occluder_count() -> int:
	return _occluder_count


func get_crop_count() -> int:
	return _crops.size()


func get_firefly_count() -> int:
	return fireflies.size()


func get_farmer() -> HD2DFarmer:
	return farmer


func get_shadow_count() -> int:
	return _texture_shadows.size() + (1 if _farmer_shadow != null else 0)


func shadow_direction() -> Vector2:
	return _shadow_dir()


func get_animation_time() -> float:
	return _time


func get_lantern_count() -> int:
	return lantern_lights.size()


func custom_shadows_enabled() -> bool:
	return _custom_shadows


func real_shadows_enabled() -> bool:
	return _real_shadows


func get_farmer_shadow_transform() -> Transform2D:
	return _farmer_shadow.transform if _farmer_shadow != null else Transform2D.IDENTITY


# 截图/对比用：冻结并回到确定性起始状态。
func reset_motion() -> void:
	_time = 0.0
	_flow = 0.0
	for i in _crops.size():
		_crops[i].rotation = 0.0
	for i in fireflies.size():
		fireflies[i].position = _firefly_base[i]
	if farmer != null:
		farmer.reset_to_start()
	if _water_mat != null:
		_water_mat.set_shader_parameter("flow", 0.0)
