class_name SunMoonWorld
extends Node2D

# 固定机位的 640×360 像素林间空地。
# 所有实体共用 lit_sprite 材质；影子是一个 MeshInstance2D（单次 draw）；
# 高度图是 640×360 单通道 R8；路灯/窗光/萤火是阴影之后的加法层。

const WORLD := Vector2(640.0, 360.0)
const GROUND_Y := 88.0
const SHADOW_Z := 30
const DEFAULT_HOUR := 8.0

const DEBUG_FLAGS := ["heightmap", "occlusion", "mesh", "overlap"]

var art: Dictionary = {}
var lit_material: ShaderMaterial
var ground_material: ShaderMaterial
var shadow_material: ShaderMaterial
var sky_material: ShaderMaterial
var lamp_pool_material: ShaderMaterial
var lamp_halo_material: ShaderMaterial
var window_material: ShaderMaterial
var firefly_material: ShaderMaterial
var sun_glow_material: ShaderMaterial
var moon_glow_material: ShaderMaterial

var height_image: Image
var height_texture: ImageTexture
var height_view: Sprite2D
var shadow_rig: ShadowBuilder
var shadow_mesh: MeshInstance2D
var debug_overlay: ShadowDebugOverlay

var casters: Array[Dictionary] = []
var lamps: Array[Dictionary] = []
var windows: Array[Sprite2D] = []
var fireflies: Array[Dictionary] = []
var clouds: Array[Dictionary] = []
var height_sources: Array[Dictionary] = []

var state: Dictionary = {}
var soft_knee := true
var shadows_enabled := true
var lamps_enabled := true
var debug_flags: Dictionary = {}
var overlap_probe: Dictionary = {}
var _lamps_on := false
var _time := 0.0
var _sun_sprite: Sprite2D
var _moon_sprite: Sprite2D
var _sun_glow: Sprite2D
var _moon_glow: Sprite2D
var _character: Sprite2D
var _character_base := Vector2(366, 300)
var _character_glow: Sprite2D
var _foreground_occluder: Sprite2D
var _white_tex: ImageTexture
var _height_debug_texture: ImageTexture


func _ready() -> void:
	art = PixelArt.build()
	_make_materials()
	_build_sky()
	_build_ground()
	_build_props()
	_build_character()
	_build_foreground()
	_build_heightmap()
	_build_shadows()
	_build_lamps()
	_build_fireflies()
	_build_debug()
	state = LightModel.state(DEFAULT_HOUR, true)
	apply_light(state, true, true, true)
	print("SUN_MOON_WORLD_READY casters=%d heightmap=R8 %s shadow=union" % [
		casters.size(), str(height_image.get_size())])


func _process(delta: float) -> void:
	step_visuals(delta)


func _make_materials() -> void:
	lit_material = ShaderMaterial.new()
	lit_material.shader = load("res://shaders/lit_sprite.gdshader")
	ground_material = ShaderMaterial.new()
	ground_material.shader = load("res://shaders/ground_lit.gdshader")
	shadow_material = ShaderMaterial.new()
	shadow_material.shader = load("res://shaders/shadow_union.gdshader")
	sky_material = ShaderMaterial.new()
	sky_material.shader = load("res://shaders/sky.gdshader")
	var lamp_shader: Shader = load("res://shaders/lamp_glow.gdshader")
	lamp_pool_material = _glow_material(lamp_shader, Color(1.0, 0.67, 0.28), 0.0, 0.055)
	lamp_halo_material = _glow_material(lamp_shader, Color(1.0, 0.80, 0.42), 0.0, 0.075)
	window_material = _glow_material(lamp_shader, Color(1.0, 0.75, 0.38), 0.0, 0.035)
	firefly_material = _glow_material(lamp_shader, Color(1.0, 0.88, 0.52), 0.9, 0.16)
	sun_glow_material = _glow_material(lamp_shader, Color(1.0, 0.68, 0.28), 0.5, 0.02)
	moon_glow_material = _glow_material(lamp_shader, Color(0.50, 0.66, 1.0), 0.35, 0.015)
	_white_tex = ImageTexture.create_from_image(_white_image())


func _glow_material(shader: Shader, color: Color, intensity: float,
		flicker: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("glow_color", color)
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("flicker", flicker)
	return mat


static func _white_image() -> Image:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	return img


# ── 天空 / 地面 / 景物 ────────────────────────────────────────────────────
func _build_sky() -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.position = Vector2.ZERO
	sky.size = WORLD
	sky.color = Color.WHITE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.material = sky_material
	sky.z_index = -100
	add_child(sky)

	var ridge := Sprite2D.new()
	ridge.name = "FarRidge"
	ridge.centered = false
	ridge.texture = ImageTexture.create_from_image(art["ridge"])
	ridge.position = Vector2(0.0, 42.0)
	ridge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ridge.material = lit_material
	ridge.z_index = -90
	add_child(ridge)

	var cloud_img: Image = art["cloud"]
	for i in 3:
		var cloud := Sprite2D.new()
		cloud.name = "Cloud%d" % i
		cloud.centered = false
		cloud.texture = ImageTexture.create_from_image(cloud_img)
		cloud.position = Vector2(58.0 + i * 196.0, 14.0 + (i % 2) * 19.0)
		cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cloud.modulate = Color(1.0, 0.96, 0.90, 0.62)
		cloud.z_index = -95
		add_child(cloud)
		clouds.append({"sprite": cloud, "base_x": cloud.position.x,
				"speed": 1.4 + i * 0.7})

	_sun_glow = _add_glow("SunGlow", art["sun_glow"], Vector2.ZERO,
			sun_glow_material, -89, true)
	_moon_glow = _add_glow("MoonGlow", art["moon_glow"], Vector2.ZERO,
			moon_glow_material, -89, true)
	_sun_sprite = _add_topleft("Sun", art["sun"], Vector2.ZERO, -88, false)
	_moon_sprite = _add_topleft("Moon", art["moon"], Vector2.ZERO, -88, false)
	_sun_sprite.offset = -Vector2(art["sun"].get_width(), art["sun"].get_height()) * 0.5
	_moon_sprite.offset = -Vector2(art["moon"].get_width(), art["moon"].get_height()) * 0.5


func _build_ground() -> void:
	var ground := Sprite2D.new()
	ground.name = "Ground"
	ground.centered = false
	ground.texture = ImageTexture.create_from_image(art["ground"])
	ground.position = Vector2(0.0, GROUND_Y)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.material = ground_material
	ground.z_index = -70
	add_child(ground)


func _build_props() -> void:
	# 房屋（左后方，最高）。
	var house_base := Vector2(150, 262)
	var house_img: Image = art["house"]["image"]
	_add_prop("House", house_img, house_base, 8)
	# 夜里的窗光，位置由像素矩形映射到世界。
	var hw := float(house_img.get_width())
	var hh := float(house_img.get_height())
	for i in art["house"]["window_rects"].size():
		var r: Rect2 = art["house"]["window_rects"][i]
		var glow := _add_glow("WindowGlow%d" % i, art["window_glow"],
				house_base + Vector2(r.position.x + r.size.x * 0.5 - hw * 0.5,
						r.position.y + r.size.y * 0.5 - hh), window_material, 44, false)
		glow.visible = false
		windows.append(glow)

	# 两棵不同高度的树。松树更靠前，z 更高。
	_add_prop("Oak", art["oak"], Vector2(410, 262), 10)
	_add_prop("Pine", art["pine"], Vector2(488, 276), 12)
	# 石柱 / 断柱。
	_add_prop("Pillar", art["pillar"], Vector2(320, 240), 9)
	_add_prop("PillarBroken", art["pillar_broken"], Vector2(596, 238), 7)
	# 木桶 / 灌木。
	_add_prop("BarrelA", art["barrel"], Vector2(238, 274), 15)
	_add_prop("BarrelB", art["barrel"], Vector2(262, 270), 15)
	_add_prop("BushA", art["bush"], Vector2(300, 292), 13)
	_add_prop("BushB", art["bush"], Vector2(520, 298), 14)
	_build_casters()


func _build_character() -> void:
	_character = _add_prop("Character", art["character"], _character_base, 18)
	_character_glow = _add_glow("CharacterLantern", art["lamp_halo"],
			_character_base + Vector2(7, -5), lamp_halo_material, 46, false)
	_character_glow.scale = Vector2(0.55, 0.55)
	_character_glow.visible = false


func _build_foreground() -> void:
	var grass := Sprite2D.new()
	grass.name = "ForegroundGrass"
	grass.centered = false
	grass.texture = ImageTexture.create_from_image(art["foreground_grass"])
	grass.position = Vector2(0.0, 280.0)
	grass.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grass.material = lit_material
	grass.z_index = 25
	add_child(grass)
	height_sources.append({
		"name": "ForegroundGrass",
		"image": art["foreground_grass"],
		"origin": Vector2(0.0, 280.0),
		"bottom_y": 362.0,
		"z": 25,
	})
	# 前景遮挡条：同一片草的底缘再画在影子之上，证明高草能挡住其后的影子。
	var source: Image = art["foreground_grass"]
	var strip := Image.create(640, 30, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	strip.blit_rect(source, Rect2i(0, source.get_height() - 30, 640, 30), Vector2i.ZERO)
	_foreground_occluder = Sprite2D.new()
	_foreground_occluder.name = "ForegroundFringe"
	_foreground_occluder.centered = false
	_foreground_occluder.texture = ImageTexture.create_from_image(strip)
	_foreground_occluder.position = Vector2(0.0, 332.0)
	_foreground_occluder.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foreground_occluder.material = lit_material
	_foreground_occluder.z_index = 58
	add_child(_foreground_occluder)


func _add_topleft(node_name: String, img: Image, pos: Vector2, z: int,
		use_material := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = false
	s.texture = ImageTexture.create_from_image(img)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if use_material:
		s.material = lit_material
	s.z_index = z
	add_child(s)
	return s


func _add_prop(node_name: String, img: Image, base: Vector2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = false
	s.texture = ImageTexture.create_from_image(img)
	s.offset = Vector2(-float(img.get_width()) * 0.5, -float(img.get_height()))
	s.position = base
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = lit_material
	s.z_index = z
	add_child(s)
	height_sources.append({
		"name": node_name,
		"image": img,
		"origin": base + Vector2(-float(img.get_width()) * 0.5,
				-float(img.get_height())),
		"bottom_y": base.y,
		"z": z,
	})
	return s


func _add_glow(node_name: String, img: Image, pos: Vector2, mat: ShaderMaterial,
		z: int, centered: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.centered = centered
	s.texture = ImageTexture.create_from_image(img)
	s.position = pos
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.material = mat
	s.z_index = z
	add_child(s)
	return s


# ── 高度图（单通道 R8） ───────────────────────────────────────────────────
func _build_heightmap() -> void:
	height_image = Image.create(640, 360, false, Image.FORMAT_R8)
	height_image.fill(Color(0, 0, 0, 1))
	var sorted := height_sources.duplicate()
	sorted.sort_custom(func(a, b): return int(a["z"]) < int(b["z"]))
	# 从后往前盖写：前景物体覆盖后景物体的可视表面高度。
	for src in sorted:
		_stamp_height(src)
	height_texture = ImageTexture.create_from_image(height_image)
	height_material_bind()
	_build_height_debug_texture()


func _stamp_height(src: Dictionary) -> void:
	var img: Image = src["image"]
	var origin: Vector2 = src["origin"]
	var bottom_y := float(src["bottom_y"])
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		var wy := origin.y + float(y)
		if wy < 0.0 or wy >= 360.0:
			continue
		var hpx := bottom_y - wy
		var norm := clampf(hpx / LightModel.HEIGHT_MAX, 0.0, 1.0)
		var value := int(round(norm * 255.0))
		for x in w:
			var wx := int(origin.x) + x
			if wx < 0 or wx >= 640:
				continue
			if img.get_pixel(x, y).a < 0.35:
				continue
			height_image.set_pixel(wx, int(wy), Color(value / 255.0,
					value / 255.0, value / 255.0, 1.0))


func height_material_bind() -> void:
	if shadow_material != null and height_texture != null:
		shadow_material.set_shader_parameter("height_map", height_texture)


static func _heat_rgb(h: float) -> Color:
	if h < 0.25:
		return Color(0.10, 0.22, 0.55).lerp(Color(0.10, 0.70, 0.75), h / 0.25)
	if h < 0.55:
		return Color(0.10, 0.70, 0.75).lerp(Color(0.95, 0.88, 0.30), (h - 0.25) / 0.30)
	return Color(0.95, 0.88, 0.30).lerp(Color(0.95, 0.28, 0.24), (h - 0.55) / 0.45)


func _build_height_debug_texture() -> void:
	var img := Image.create(640, 360, false, Image.FORMAT_RGBA8)
	for y in 360:
		for x in 640:
			var h := height_image.get_pixel(x, y).r
			var c := _heat_rgb(h)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.86))
	_height_debug_texture = ImageTexture.create_from_image(img)
	height_view = Sprite2D.new()
	height_view.name = "HeightMapView"
	height_view.centered = false
	height_view.texture = _height_debug_texture
	height_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	height_view.z_index = 94
	height_view.visible = false
	add_child(height_view)


func sample_height_px(point: Vector2) -> float:
	var x := int(floor(point.x))
	var y := int(floor(point.y))
	if x < 0 or y < 0 or x >= 640 or y >= 360:
		return 0.0
	return height_image.get_pixel(x, y).r * LightModel.HEIGHT_MAX


func sample_height01(point: Vector2) -> float:
	return clampf(sample_height_px(point) / LightModel.HEIGHT_MAX, 0.0, 1.0)


# ── 2.5D 影子网格 ─────────────────────────────────────────────────────────
func _build_casters() -> void:
	var specs: Array[Dictionary] = []
	# 房屋：墙基、屋檐、屋脊三层。
	specs.append({
		"name": "house", "base": Vector2(150, 262), "height": 150.0,
		"footprint": _ground_rect(150.0, 14.0),
		"bands": [
			{"h": 66.0, "poly": ShadowBuilder.rect_poly(170.0, 14.0, 5.0)},
			{"h": 112.0, "poly": ShadowBuilder.rect_poly(132.0, 10.0, 3.0)},
			{"h": 148.0, "poly": ShadowBuilder.rect_poly(94.0, 8.0, 2.0)},
		],
	})
	# 橡树：树干接触面 + 三层树冠。
	specs.append({
		"name": "oak", "base": Vector2(410, 262), "height": 140.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 16, 7, 12),
		"bands": [
			{"h": 62.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 46, 24, 16)},
			{"h": 104.0, "poly": ShadowBuilder.ellipse_poly(2, -4, 38, 18, 16)},
			{"h": 138.0, "poly": ShadowBuilder.ellipse_poly(4, -5, 20, 10, 12)},
		],
	})
	# 松树。
	specs.append({
		"name": "pine", "base": Vector2(488, 276), "height": 124.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 12, 5, 12),
		"bands": [
			{"h": 40.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 24, 10, 12)},
			{"h": 82.0, "poly": ShadowBuilder.ellipse_poly(0, -3, 17, 8, 12)},
			{"h": 120.0, "poly": ShadowBuilder.ellipse_poly(0, -4, 8, 4, 10)},
		],
	})
	specs.append({
		"name": "pillar", "base": Vector2(320, 240), "height": 76.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 12, 5, 10),
		"bands": [
			{"h": 52.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 10, 5, 10)},
			{"h": 74.0, "poly": ShadowBuilder.ellipse_poly(0, -4, 14, 5, 10)},
		],
	})
	specs.append({
		"name": "pillar_broken", "base": Vector2(596, 238), "height": 44.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 10, 4, 10),
		"bands": [
			{"h": 40.0, "poly": ShadowBuilder.ellipse_poly(0, -3, 9, 4, 10)},
		],
	})
	specs.append({
		"name": "lamp_l", "base": Vector2(150, 310), "height": 104.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 8, 4, 10),
		"bands": [
			{"h": 78.0, "poly": ShadowBuilder.ellipse_poly(-8, -2, 9, 5, 10)},
			{"h": 100.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 4, 3, 8)},
		],
	})
	specs.append({
		"name": "lamp_r", "base": Vector2(548, 300), "height": 104.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 8, 4, 10),
		"bands": [
			{"h": 78.0, "poly": ShadowBuilder.ellipse_poly(8, -2, 9, 5, 10)},
			{"h": 100.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 4, 3, 8)},
		],
	})
	for b in [Vector2(238, 274), Vector2(262, 270)]:
		specs.append({
			"name": "barrel_%d" % int(b.x), "base": b, "height": 32.0,
			"footprint": ShadowBuilder.ellipse_poly(0, 0, 10, 4, 10),
			"bands": [
				{"h": 30.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 10, 4, 10)},
			],
		})
	for b in [Vector2(300, 292), Vector2(520, 298)]:
		specs.append({
			"name": "bush_%d" % int(b.x), "base": b, "height": 22.0,
			"footprint": ShadowBuilder.ellipse_poly(0, 0, 12, 4, 10),
			"bands": [
				{"h": 18.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 10, 4, 10)},
			],
		})
	specs.append({
		"name": "character", "base": _character_base, "height": 38.0,
		"footprint": ShadowBuilder.ellipse_poly(0, 0, 7, 4, 10),
		"bands": [
			{"h": 28.0, "poly": ShadowBuilder.ellipse_poly(0, -2, 7, 5, 10)},
			{"h": 37.0, "poly": ShadowBuilder.ellipse_poly(0, -4, 5, 4, 8)},
		],
	})
	casters = specs


static func _ground_rect(w: float, d: float) -> PackedVector2Array:
	var hw := w * 0.5
	var hd := d * 0.5
	return PackedVector2Array([
		Vector2(-hw, hd), Vector2(hw, hd),
		Vector2(hw, -hd), Vector2(-hw, -hd)])


func _build_shadows() -> void:
	shadow_rig = ShadowBuilder.new()
	shadow_rig.setup(casters)
	shadow_mesh = MeshInstance2D.new()
	shadow_mesh.name = "ShadowUnionMesh"
	shadow_mesh.texture = _white_tex
	shadow_mesh.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow_mesh.material = shadow_material
	shadow_mesh.z_index = SHADOW_Z
	add_child(shadow_mesh)


# ── 路灯 / 萤火 / 调试 ────────────────────────────────────────────────────
func _build_lamps() -> void:
	var lamp_specs: Array[Dictionary] = [
		{"base": Vector2(150, 310), "flip": false},
		{"base": Vector2(548, 300), "flip": true},
	]
	for i in lamp_specs.size():
		var spec: Dictionary = lamp_specs[i]
		var base: Vector2 = spec["base"]
		var img: Image = art["lamp"]
		if bool(spec["flip"]):
			img = img.duplicate() as Image
			img.flip_x()
		var post := _add_prop("Lamp%d" % i, img, base, 16)
		var lantern_x := -8.0 if not bool(spec["flip"]) else 8.0
		var lantern_pos := base + Vector2(lantern_x, -57.0)
		var pool := _add_glow("LampPool%d" % i, art["lamp_pool"],
				base + Vector2(0, -2), lamp_pool_material, 44, true)
		pool.scale = Vector2(0.92, 0.92)
		pool.visible = false
		var halo := _add_glow("LampHalo%d" % i, art["lamp_halo"],
				lantern_pos, lamp_halo_material, 45, true)
		halo.visible = false
		lamps.append({
			"name": "lamp_%d" % i,
			"base": base,
			"post": post,
			"pool": pool,
			"halo": halo,
			"lantern_pos": lantern_pos,
		})


func _build_fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 774411
	for i in 10:
		var base := Vector2(rng.randf_range(210.0, 590.0),
				rng.randf_range(230.0, 340.0))
		var s := _add_glow("Firefly%d" % i, art["firefly"], base,
				firefly_material, 55, true)
		s.scale = Vector2(rng.randf_range(0.8, 1.4), rng.randf_range(0.8, 1.4))
		s.visible = false
		fireflies.append({
			"sprite": s,
			"base": base,
			"phase": rng.randf() * TAU,
			"amplitude": rng.randf_range(4.0, 12.0),
			"speed": rng.randf_range(0.25, 0.65),
		})


func _build_debug() -> void:
	debug_flags = {}
	for f in DEBUG_FLAGS:
		debug_flags[f] = false
	debug_overlay = ShadowDebugOverlay.new()
	debug_overlay.name = "ShadowDebugOverlay"
	debug_overlay.world = self
	debug_overlay.z_index = 96
	add_child(debug_overlay)


# ── 每帧光照入口 ─────────────────────────────────────────────────────────
func apply_light(light_state: Dictionary, show_shadows: bool, use_soft_knee: bool,
		use_lamps: bool) -> void:
	state = light_state
	shadows_enabled = show_shadows
	soft_knee = use_soft_knee
	lamps_enabled = use_lamps
	_update_celestial()
	_update_clouds()
	if shadow_rig != null:
		shadow_rig.update(state, soft_knee)
		shadow_mesh.mesh = shadow_rig.get_mesh()
		shadow_mesh.visible = shadows_enabled
	_update_lamps()
	if bool(debug_flags.get("overlap", false)):
		overlap_probe = _find_preferred_overlap()
	if debug_overlay != null:
		debug_overlay.queue_redraw()
	_update_shadow_debug_material()


func _update_shadow_debug_material() -> void:
	if shadow_material == null:
		return
	var mode := 1 if bool(debug_flags.get("occlusion", false)) else 0
	shadow_material.set_shader_parameter("debug_mode", mode)


func _update_celestial() -> void:
	var sun_elev := float(state.get("sun_elevation", -90.0))
	var moon_elev := float(state.get("moon_elevation", -90.0))
	var sun_alpha := smoothstep(0.8, 6.0, sun_elev) if bool(state.get("sun_up", false)) else 0.0
	var moon_alpha := smoothstep(0.8, 6.0, moon_elev) if bool(state.get("moon_up", false)) else 0.0
	var sun_pos: Vector2 = state.get("sun_sky", Vector2(320, 92))
	var moon_pos: Vector2 = state.get("moon_sky", Vector2(320, 92))
	_sun_sprite.position = sun_pos
	_moon_sprite.position = moon_pos
	_sun_glow.position = sun_pos
	_moon_glow.position = moon_pos
	_sun_sprite.modulate = Color(1, 1, 1, sun_alpha)
	_moon_sprite.modulate = Color(1, 1, 1, moon_alpha)
	_sun_glow.modulate = Color(1, 1, 1, sun_alpha)
	_moon_glow.modulate = Color(1, 1, 1, moon_alpha)
	_sun_sprite.visible = sun_alpha > 0.02
	_moon_sprite.visible = moon_alpha > 0.02
	_sun_glow.visible = sun_alpha > 0.02
	_moon_glow.visible = moon_alpha > 0.02


func _update_clouds() -> void:
	var night := float(state.get("night", 0.0))
	for c in clouds:
		var s: Sprite2D = c["sprite"]
		s.modulate = Color(1.0, 0.93 + 0.05 * (1.0 - night), 0.88,
				lerpf(0.64, 0.06, night))


func _update_lamps() -> void:
	var night := float(state.get("night", 0.0))
	_lamps_on = lamps_enabled and night > 0.22
	var lamp_strength := (0.50 + 0.70 * night) * (1.0 if _lamps_on else 0.0)
	lamp_pool_material.set_shader_parameter("intensity", lamp_strength * 0.90)
	lamp_halo_material.set_shader_parameter("intensity", lamp_strength * 1.15)
	window_material.set_shader_parameter("intensity", night * 0.55 * (1.0 if lamps_enabled else 0.0))
	firefly_material.set_shader_parameter("intensity", 1.2 * smoothstep(0.35, 0.8, night))
	for lamp in lamps:
		var on := _lamps_on
		(lamp["pool"] as Sprite2D).visible = on
		(lamp["halo"] as Sprite2D).visible = on
	for w in windows:
		w.visible = night > 0.18 and lamps_enabled
	if _character_glow != null:
		_character_glow.visible = _lamps_on
		_character_glow.modulate = Color(1, 1, 1, 0.7 + night * 0.3)
	for f in fireflies:
		(f["sprite"] as Sprite2D).visible = night > 0.55


func step_visuals(delta: float) -> void:
	_time += delta
	for c in clouds:
		var s: Sprite2D = c["sprite"]
		s.position.x += float(c["speed"]) * delta
		if s.position.x > 680.0:
			s.position.x = -80.0
	for f in fireflies:
		var s: Sprite2D = f["sprite"]
		var phase := float(f["phase"]) + _time * float(f["speed"]) * 3.0
		var base: Vector2 = f["base"]
		s.position = base + Vector2(cos(phase) * float(f["amplitude"]),
				sin(phase * 1.3) * float(f["amplitude"]) * 0.45)
		s.modulate = Color(1, 1, 1, 0.45 + 0.45 * sin(phase * 2.7))
	if _character != null:
		var bob := 0.0 if sin(_time * 2.2) < 0.2 else -1.0
		_character.position = _character_base + Vector2(0, bob)


# ── 调试入口 / 查询 ──────────────────────────────────────────────────────
func set_debug_flag(flag: String, value: bool) -> void:
	if not debug_flags.has(flag):
		return
	debug_flags[flag] = value
	if flag == "heightmap" and height_view != null:
		height_view.visible = value
	if flag == "occlusion":
		_update_shadow_debug_material()
	if flag == "overlap":
		overlap_probe = _find_preferred_overlap() if value else {}
	if debug_overlay != null:
		debug_overlay.queue_redraw()


func is_debug_flag(flag: String) -> bool:
	return bool(debug_flags.get(flag, false))


func _find_preferred_overlap() -> Dictionary:
	if shadow_rig == null:
		return {}
	var prefer: Array[String] = ["oak", "pine"]
	var p := shadow_rig.find_overlap_probe(Rect2(0, 0, 640, 360), prefer)
	if not bool(p.get("found", false)):
		p = shadow_rig.find_overlap_probe()
	return p


func refresh_overlap_probe() -> Dictionary:
	overlap_probe = _find_preferred_overlap() if shadow_rig != null else {}
	if debug_overlay != null:
		debug_overlay.queue_redraw()
	return overlap_probe


func get_overlap_probe() -> Dictionary:
	if overlap_probe.is_empty() and shadow_rig != null:
		overlap_probe = _find_preferred_overlap()
	return overlap_probe


func find_overlap_hour(step := 0.25, prefer: Array[String] = []) -> Dictionary:
	if shadow_rig == null:
		return {"hour": -1.0, "probe": {}}
	var saved_state := state.duplicate(true)
	var saved_probe := overlap_probe
	if prefer.is_empty():
		prefer = ["oak", "pine"]
	var hour := 6.0
	while hour <= 18.0:
		var st := LightModel.state(hour, true)
		shadow_rig.update(st, true)
		var probe := shadow_rig.find_overlap_probe(Rect2(0, 0, 640, 360), prefer)
		if bool(probe.get("found", false)):
			shadow_rig.update(saved_state, soft_knee)
			overlap_probe = saved_probe
			return {"hour": hour, "probe": probe}
		hour += step
	shadow_rig.update(saved_state, soft_knee)
	overlap_probe = saved_probe
	return {"hour": -1.0, "probe": {}}


func get_shadow_stats() -> Dictionary:
	return shadow_rig.get_stats() if shadow_rig != null else {}


func get_shadow_reports() -> Array[Dictionary]:
	return shadow_rig.get_reports() if shadow_rig != null else []


func get_shadow_alpha_at(point: Vector2) -> float:
	if shadow_rig == null or not shadow_rig.point_inside_merged(point):
		return 0.0
	return float(state.get("shadow_alpha", 0.0))


func get_shadow_coverage(point: Vector2) -> int:
	return shadow_rig.coverage_count(point) if shadow_rig != null else 0


func get_height_info() -> Dictionary:
	return {
		"format": "R8",
		"size": height_image.get_size() if height_image != null else Vector2i.ZERO,
		"channels": 1,
		"normalization_px": LightModel.HEIGHT_MAX,
		"gl_compatibility_note": "GLES3 下 R16F 采样不稳定，使用等价单通道 R8（256 级）。",
	}


func get_occlusion_debug() -> Dictionary:
	var roof := sample_height_px(Vector2(178, 150))
	var wall := sample_height_px(Vector2(178, 230))
	var ground := sample_height_px(Vector2(360, 320))
	var tree := 140.0
	var barrel := 32.0
	return {
		"roof_height": roof,
		"wall_height": wall,
		"ground_height": ground,
		"tree_caster": tree,
		"barrel_caster": barrel,
		"barrel_vs_roof": LightModel.occlusion_allows(barrel, roof),
		"tree_vs_roof": LightModel.occlusion_allows(tree, roof),
		"tree_vs_ground": LightModel.occlusion_allows(tree, ground),
	}


func get_prop_count() -> int:
	return height_sources.size()


func get_tree_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in height_sources:
		if s["name"] in ["Oak", "Pine"]:
			out.append(s)
	return out


func are_lamps_on() -> bool:
	return _lamps_on


func get_lamps() -> Array[Dictionary]:
	return lamps


func get_windows() -> Array[Sprite2D]:
	return windows


func get_shadow_mesh_node() -> MeshInstance2D:
	return shadow_mesh


func get_height_texture() -> ImageTexture:
	return height_texture


func get_height_image() -> Image:
	return height_image


func get_height_view() -> Sprite2D:
	return height_view


func get_debug_overlay() -> ShadowDebugOverlay:
	return debug_overlay


func get_state() -> Dictionary:
	return state


func get_sun_sprite() -> Sprite2D:
	return _sun_sprite


func get_moon_sprite() -> Sprite2D:
	return _moon_sprite


func get_character_sprite() -> Sprite2D:
	return _character


func get_foreground_occluder() -> Sprite2D:
	return _foreground_occluder


func get_fireflies() -> Array[Dictionary]:
	return fireflies


func get_clouds() -> Array[Dictionary]:
	return clouds
