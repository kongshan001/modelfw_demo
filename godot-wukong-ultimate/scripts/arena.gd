extends Node3D
class_name Arena

## Floating trial platform: procedural stone, rune rings, broken pillars,
## levitating shards, moonlit sky and stars. All geometry/materials are original.

const PLATFORM_RADIUS := 9.0
const PLAY_RADIUS := 8.2

var floaters: Array = []
var _t := 0.0
var stone_material: StandardMaterial3D
var stone_dark: StandardMaterial3D
var rune_material: StandardMaterial3D
var gold_material: StandardMaterial3D


func _ready() -> void:
	_build_sky()
	_build_lights()
	_build_platform()
	_build_pillars()
	_build_floaters()
	_build_distant_world()


func _process(delta: float) -> void:
	_t += delta
	for entry in floaters:
		var node: Node3D = entry.node
		var base: Vector3 = entry.base
		node.position = Vector3(base.x, base.y + sin(_t * entry.bob + entry.phase) * 0.22,
			base.z + sin(_t * entry.bob * 0.7 + entry.phase) * 0.10)
		node.rotation.y += delta * entry.spin
		node.rotation.x += delta * entry.spin * 0.35


# ── procedural textures ─────────────────────────────────────────────────────

func _noise_image(seed_value: int, base: Color, contrast: float) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	var img := Image.create(192, 192, false, Image.FORMAT_RGB8)
	for y in 192:
		for x in 192:
			var n := noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var grain := noise.get_noise_2d(float(x) * 4.3 + 31.0, float(y) * 4.3 + 17.0) * 0.5 + 0.5
			var v := clampf(0.55 + (n - 0.5) * contrast + (grain - 0.5) * 0.18, 0.0, 1.0)
			var col := Color(base.r * v, base.g * v, base.b * v)
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _build_materials() -> void:
	stone_material = StandardMaterial3D.new()
	stone_material.albedo_texture = _noise_image(17, Color(0.34, 0.38, 0.50), 0.55)
	stone_material.albedo_color = Color(1.25, 1.28, 1.42)
	stone_material.roughness = 0.88
	stone_material.metallic = 0.08
	stone_material.uv1_scale = Vector3(3.0, 3.0, 1.0)
	stone_material.rim_enabled = true
	stone_material.rim = 0.22

	stone_dark = StandardMaterial3D.new()
	stone_dark.albedo_texture = _noise_image(31, Color(0.20, 0.24, 0.34), 0.75)
	stone_dark.albedo_color = Color(1.00, 1.06, 1.25)
	stone_dark.roughness = 0.92
	stone_dark.metallic = 0.12
	stone_dark.uv1_scale = Vector3(2.0, 2.0, 1.0)

	gold_material = StandardMaterial3D.new()
	gold_material.albedo_color = Color(0.82, 0.56, 0.19)
	gold_material.metallic = 0.55
	gold_material.roughness = 0.32
	gold_material.emission_enabled = true
	gold_material.emission = Color(0.55, 0.34, 0.08)
	gold_material.emission_energy_multiplier = 0.40

	rune_material = StandardMaterial3D.new()
	rune_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rune_material.albedo_color = Color(0.40, 0.68, 1.0)
	rune_material.emission_enabled = true
	rune_material.emission = Color(0.33, 0.67, 1.0)
	rune_material.emission_energy_multiplier = 1.35
	rune_material.disable_receive_shadows = true


func _build_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.020, 0.040, 0.095)
	sky_mat.sky_horizon_color = Color(0.15, 0.22, 0.38)
	sky_mat.ground_horizon_color = Color(0.075, 0.11, 0.20)
	sky_mat.ground_bottom_color = Color(0.015, 0.022, 0.045)
	sky_mat.sky_energy_multiplier = 1.0
	sky_mat.ground_energy_multiplier = 0.45
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.44, 0.58)
	env.ambient_light_energy = 1.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.60
	env.fog_enabled = true
	env.fog_light_color = Color(0.10, 0.15, 0.28)
	env.fog_light_energy = 0.8
	env.fog_density = 0.006
	env.fog_sky_affect = 0.5
	env.fog_height = 0.0
	env.fog_height_density = 0.0
	env.glow_enabled = false
	env.glow_intensity = 0.75
	env.glow_strength = 1.0
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# moon
	var moon := MeshInstance3D.new()
	var moon_mesh := SphereMesh.new()
	moon_mesh.radius = 6.0
	moon_mesh.height = 14.0
	moon_mesh.radial_segments = 32
	moon_mesh.rings = 16
	moon.mesh = moon_mesh
	var moon_mat := StandardMaterial3D.new()
	moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_mat.albedo_color = Color(0.82, 0.88, 1.0)
	moon_mat.emission_enabled = true
	moon_mat.emission = Color(0.62, 0.75, 1.0)
	moon_mat.emission_energy_multiplier = 1.6
	moon.material_override = moon_mat
	moon.position = Vector3(-62, 38, -92)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(moon)

	# stars: one multimesh, camera-facing additive quads
	var star_img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var sd := Vector2(x + 0.5 - 16.0, y + 0.5 - 16.0).length() / 16.0
			var sa := clampf(1.0 - sd, 0.0, 1.0)
			sa = sa * sa * (3.0 - 2.0 * sa)
			star_img.set_pixel(x, y, Color(1, 1, 1, sa))
	var star_mat := StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.vertex_color_use_as_albedo = true
	star_mat.albedo_texture = ImageTexture.create_from_image(star_img)
	star_mat.albedo_color = Color(1, 1, 1, 0.9)
	star_mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.25, 1.25)
	quad.material = star_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = 340
	for i in 340:
		var az := randf() * TAU
		var el := deg_to_rad(randf_range(5.0, 72.0))
		var r := randf_range(95.0, 150.0)
		var p := Vector3(cos(az) * cos(el), sin(el), sin(az) * cos(el)) * r
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		var tint := Color(0.72, 0.84, 1.0).lerp(Color(1.0, 0.95, 0.85), randf())
		mm.set_instance_color(i, Color(tint.r, tint.g, tint.b, randf_range(0.35, 0.95)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _build_lights() -> void:
	var moon_light := DirectionalLight3D.new()
	moon_light.light_color = Color(0.63, 0.76, 1.0)
	moon_light.light_energy = 2.2
	moon_light.rotation_degrees = Vector3(-52, -32, 0)
	moon_light.shadow_enabled = false
	moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	moon_light.directional_shadow_max_distance = 40.0
	moon_light.shadow_bias = 0.04
	moon_light.shadow_normal_bias = 0.8
	add_child(moon_light)

	var warm_key := DirectionalLight3D.new()
	warm_key.light_color = Color(1.0, 0.74, 0.48)
	warm_key.light_energy = 1.15
	warm_key.rotation_degrees = Vector3(-38, -28, 0)
	warm_key.shadow_enabled = false
	add_child(warm_key)

	var front_fill := OmniLight3D.new()
	front_fill.light_color = Color(1.0, 0.84, 0.68)
	front_fill.light_energy = 4.0
	front_fill.omni_range = 24.0
	front_fill.position = Vector3(0.0, 4.8, -4.8)
	add_child(front_fill)

	var back_fill := OmniLight3D.new()
	back_fill.light_color = Color(1.0, 0.84, 0.66)
	back_fill.light_energy = 2.6
	back_fill.omni_range = 18.0
	back_fill.position = Vector3(0.0, 5.0, 6.0)
	add_child(back_fill)


func _build_platform() -> void:
	_build_materials()
	# floor collider
	var body := StaticBody3D.new()
	body.name = "ArenaFloor"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = PLATFORM_RADIUS
	cyl.height = 0.9
	shape.shape = cyl
	shape.position = Vector3(0, -0.45, 0)
	body.add_child(shape)
	add_child(body)

	# main disc
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = PLATFORM_RADIUS
	disc.bottom_radius = PLATFORM_RADIUS - 0.55
	disc.height = 0.9
	disc.radial_segments = 72
	disc.rings = 3
	floor_mesh.mesh = disc
	floor_mesh.material_override = stone_material
	floor_mesh.position = Vector3(0, -0.45, 0)
	add_child(floor_mesh)

	# bottom rough cone / cliff
	var cliff := MeshInstance3D.new()
	var cliff_mesh := CylinderMesh.new()
	cliff_mesh.top_radius = PLATFORM_RADIUS - 0.5
	cliff_mesh.bottom_radius = 2.0
	cliff_mesh.height = 4.5
	cliff_mesh.radial_segments = 36
	cliff_mesh.rings = 2
	cliff.mesh = cliff_mesh
	cliff.material_override = stone_dark
	cliff.position = Vector3(0, -3.1, 0)
	add_child(cliff)

	# rune rings
	_add_torus(7.55, 0.030, 0.02, rune_material, "RuneOuter")
	_add_torus(4.10, 0.022, 0.018, rune_material, "RuneInner")
	_add_torus(7.55, 0.055, 0.025, gold_material, "GoldOuter")
	_add_torus(2.55, 0.030, 0.025, gold_material, "GoldInner")

	# centre sigil: radiating spokes and arcs
	for i in 12:
		var a := TAU * float(i) / 12.0
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.055, 0.022, 1.15)
		slab.mesh = bm
		slab.material_override = rune_material
		slab.position = Vector3(cos(a) * 1.9, 0.018, sin(a) * 1.9)
		slab.rotation.y = -a + PI * 0.5
		add_child(slab)
	_add_torus(1.25, 0.028, 0.02, gold_material, "SigilGold")

	# broken outer slabs
	for i in 18:
		var a := TAU * float(i) / 18.0 + 0.06 * sin(i * 2.0)
		var slab := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9 + 0.3 * sin(i * 1.7), 0.13, 0.65)
		slab.mesh = bm
		slab.material_override = stone_dark
		slab.position = Vector3(cos(a) * (PLATFORM_RADIUS - 0.9), 0.01, sin(a) * (PLATFORM_RADIUS - 0.9))
		slab.rotation.y = -a
		slab.rotation.z = 0.01 * sin(i * 3.1)
		add_child(slab)


func _add_torus(radius: float, thickness: float, height: float, mat: Material, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var tor := TorusMesh.new()
	tor.inner_radius = radius - thickness
	tor.outer_radius = radius + thickness
	tor.rings = 72
	tor.ring_segments = 10
	mi.mesh = tor
	mi.material_override = mat
	mi.position.y = height
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _build_pillars() -> void:
	var spots := [
		Vector2(0.35, 8.55), Vector2(1.10, 8.65), Vector2(2.00, 8.55),
		Vector2(3.05, 8.62), Vector2(4.10, 8.55), Vector2(5.20, 8.65),
	]
	for i in spots.size():
		var a := TAU * float(i) / 6.0 + 0.18
		var p := Vector3(cos(a) * spots[i].y, 0.0, sin(a) * spots[i].y)
		var h: float = [3.2, 5.4, 2.4, 4.4, 1.8, 4.8][i]
		var pillar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.34
		cm.bottom_radius = 0.50
		cm.height = h
		cm.radial_segments = 9
		cm.rings = 3
		pillar.mesh = cm
		pillar.material_override = stone_material
		pillar.position = p + Vector3(0, h * 0.5, 0)
		pillar.rotation.x = 0.018 * sin(i * 3.0)
		pillar.rotation.z = 0.022 * cos(i * 2.0)
		add_child(pillar)
		var cap := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.95, 0.22, 0.95)
		cap.mesh = bm
		cap.material_override = stone_dark
		cap.position = p + Vector3(0, h + 0.06, 0)
		cap.rotation.y = a
		add_child(cap)
		if i % 2 == 0:
			var band := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.40
			tor.outer_radius = 0.48
			tor.rings = 32
			tor.ring_segments = 8
			band.mesh = tor
			band.material_override = gold_material if i == 0 else rune_material
			band.position = p + Vector3(0, h * 0.55, 0)
			add_child(band)


func _build_floaters() -> void:
	for i in 12:
		var a := TAU * float(i) / 12.0 + 0.4
		var r := randf_range(10.5, 16.0)
		var base := Vector3(cos(a) * r, randf_range(-2.8, 5.0), sin(a) * r)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := randf_range(0.5, 1.8)
		bm.size = Vector3(s * randf_range(0.8, 1.6), s * randf_range(0.3, 0.8), s * randf_range(0.8, 1.5))
		mi.mesh = bm
		mi.material_override = stone_dark
		mi.position = base
		mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(mi)
		floaters.append({
			"node": mi, "base": base, "bob": randf_range(0.25, 0.7),
			"phase": randf() * TAU, "spin": randf_range(-0.15, 0.15),
		})


func _build_distant_world() -> void:
	var mountain_mat := StandardMaterial3D.new()
	mountain_mat.albedo_color = Color(0.022, 0.030, 0.052)
	mountain_mat.roughness = 1.0
	mountain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	for i in 9:
		var a := TAU * float(i) / 9.0 + 0.25
		var rad := randf_range(28.0, 52.0)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(7.0, 15.0)
		cm.height = randf_range(12.0, 28.0)
		cm.radial_segments = 5
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mountain_mat
		mi.position = Vector3(cos(a) * rad, -6.0, sin(a) * rad)
		mi.rotation.y = randf() * TAU
		add_child(mi)
