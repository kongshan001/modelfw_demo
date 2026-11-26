class_name KnotWorld
extends Node3D

## Original low-poly toy diorama built from primitives at runtime.
## The island, pillars, start loop, goal pad and props are all generated —
## no borrowed assets. Only pillars and the island floor are ray targets.

const FONT_PATH := "res://assets/fonts/NotoSansSC-Knotline.otf"
const GROUND_Y := 0.0
const ISLAND_RADIUS := 4.55
const VOID_Y := -2.2

var level: Dictionary = {}
var pillars: Array[Dictionary] = []
var palette: Dictionary = {}
var start_pos := Vector3.ZERO
var goal_pos := Vector3.ZERO
var goal_radius := 0.6
var start_radius := 0.6

var _pillar_views: Dictionary = {}
var _animated: Array[Dictionary] = []
var _shadow_spots: Array[Dictionary] = []
var _time := 0.0
var _font: Font
var _env: WorldEnvironment


func build(level_data: Dictionary) -> void:
	_clear()
	level = level_data
	pillars = KnotLevel.normalize_pillars(level)
	palette = KnotLevel.palette(level)
	start_pos = KnotLevel.start_point(level)
	goal_pos = KnotLevel.goal_point(level)
	goal_radius = float(level.get("goal_radius", 0.6))
	start_radius = float(level.get("start_radius", 0.62))
	_time = 0.0
	_font = null
	_build_environment()
	_build_island()
	for p in pillars:
		_build_pillar(p)
	_build_start()
	_build_goal()
	_build_decor()
	_build_guide_stones()
	_build_clouds()
	_build_contact_shadows()
	_build_dust()
	_process(0.0)


func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_pillar_views.clear()
	_animated.clear()
	_shadow_spots.clear()
	_env = null


func _build_environment() -> void:
	_env = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = palette["sky_top"]
	sm.sky_horizon_color = palette["sky_bottom"]
	sm.ground_bottom_color = palette["sky_bottom"].darkened(0.12)
	sm.ground_horizon_color = palette["sky_bottom"]
	sm.sun_angle_max = 12.0
	sm.sun_curve = 0.12
	sm.use_debanding = true
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = palette["sky_bottom"].lerp(Color("#BFDCD8"), 0.34)
	env.ambient_light_energy = 0.52
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	_env.environment = env
	add_child(_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("#FFF1D8")
	sun.light_energy = 1.38
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
	sun.shadow_blur = 0.6
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-24.0, 138.0, 0.0)
	fill.light_color = Color("#CFE7F4")
	fill.light_energy = 0.24
	fill.shadow_enabled = false
	add_child(fill)


func _build_island() -> void:
	var root := Node3D.new()
	root.name = "Island"
	add_child(root)
	var rock_mat := _mat(palette["rock"], 0.95)
	var edge_mat := _mat(palette["island_edge"], 0.9)
	var grass_mat := _mat(palette["island_top"], 0.96)

	var top := CylinderMesh.new()
	top.top_radius = ISLAND_RADIUS
	top.bottom_radius = ISLAND_RADIUS * 0.98
	top.height = 0.24
	top.radial_segments = 16
	top.rings = 1
	_mesh(root, top, Vector3(0.0, -0.12, 0.0), grass_mat, false)

	var rim := CylinderMesh.new()
	rim.top_radius = ISLAND_RADIUS + 0.04
	rim.bottom_radius = ISLAND_RADIUS - 0.02
	rim.height = 0.12
	rim.radial_segments = 16
	_mesh(root, rim, Vector3(0.0, -0.26, 0.0), edge_mat, false)

	var body := CylinderMesh.new()
	body.top_radius = ISLAND_RADIUS * 0.99
	body.bottom_radius = ISLAND_RADIUS * 0.46
	body.height = 1.45
	body.radial_segments = 14
	_mesh(root, body, Vector3(0.0, -1.05, 0.0), rock_mat, false)

	var tip := CylinderMesh.new()
	tip.top_radius = ISLAND_RADIUS * 0.46
	tip.bottom_radius = 0.05
	tip.height = 1.15
	tip.radial_segments = 10
	_mesh(root, tip, Vector3(0.0, -2.34, 0.0), _mat(palette["rock"].darkened(0.08), 0.95), false)

	# Soft grass patches for a hand-made look.
	var patch_mat := _mat(palette["island_top"].lightened(0.08), 0.95)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("id", "knotline"))) + 71
	for i in 9:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1.1, 3.9)
		var disc := CylinderMesh.new()
		disc.top_radius = rng.randf_range(0.22, 0.55)
		disc.bottom_radius = disc.top_radius * 0.94
		disc.height = 0.025
		disc.radial_segments = 9
		var mi := _mesh(root, disc, Vector3(cos(ang) * dist, 0.012, sin(ang) * dist), patch_mat, false)
		mi.rotation.y = rng.randf() * TAU

	# Ground collider: top exactly at y = 0.
	var body3d := StaticBody3D.new()
	body3d.name = "GroundBody"
	body3d.collision_layer = 1
	body3d.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ISLAND_RADIUS - 0.05
	cyl.height = 0.6
	shape.shape = cyl
	shape.position = Vector3(0.0, -0.3, 0.0)
	body3d.add_child(shape)
	root.add_child(body3d)

	# Out-of-reach floating islets frame the diorama.
	_build_float_isle(Vector3(5.9, -0.85, -2.1), 0.88, 1)
	_build_float_isle(Vector3(-5.7, -1.15, 1.6), 0.7, 2)
	_build_float_isle(Vector3(2.9, -1.7, -5.6), 1.12, 3)


func _build_float_isle(pos: Vector3, scale_v: float, seed_v: int) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var rock_mat := _mat(palette["rock"].darkened(0.1), 0.95)
	var grass_mat := _mat(palette["island_top"].darkened(0.06), 0.95)
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0 * scale_v
	disc.bottom_radius = 0.32 * scale_v
	disc.height = 1.05 * scale_v
	disc.radial_segments = 9
	_mesh(root, disc, Vector3.ZERO, rock_mat, false)
	var top := CylinderMesh.new()
	top.top_radius = 1.03 * scale_v
	top.bottom_radius = 0.99 * scale_v
	top.height = 0.16 * scale_v
	top.radial_segments = 9
	_mesh(root, top, Vector3(0.0, 0.52 * scale_v, 0.0), grass_mat, false)
	var bush := SphereMesh.new()
	bush.radius = 0.28 * scale_v
	bush.height = 0.42 * scale_v
	bush.radial_segments = 7
	bush.rings = 4
	_mesh(root, bush, Vector3(0.2 * scale_v, 0.78 * scale_v, 0.1 * scale_v), _mat(palette["leaf"], 0.9), false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 977 + 13
	root.rotation.y = rng.randf() * TAU


func _build_pillar(p: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Pillar_" + p["id"]
	root.position = Vector3(p["pos3"].x, 0.0, p["pos3"].z)
	add_child(root)
	var r: float = p["radius"]
	var h: float = p["height"]
	var color: Color = p["color"]
	var top_color: Color = p["top_color"]

	_contact_shadow(root, r * 2.15, 0.16)
	var shaft_mat := _mat(color, 0.86)
	var shaft := CylinderMesh.new()
	shaft.top_radius = r * 0.93
	shaft.bottom_radius = r
	shaft.height = h - 0.14
	shaft.radial_segments = 14
	shaft.rings = 1
	_mesh(root, shaft, Vector3(0.0, 0.14 + (h - 0.14) * 0.5, 0.0), shaft_mat, true)

	var plinth := CylinderMesh.new()
	plinth.top_radius = r * 1.55
	plinth.bottom_radius = r * 1.68
	plinth.height = 0.16
	plinth.radial_segments = 14
	_mesh(root, plinth, Vector3(0.0, 0.08, 0.0), _mat(color.darkened(0.12), 0.92), true)

	var knob := SphereMesh.new()
	knob.radius = r * 1.16
	knob.height = r * 2.1
	knob.radial_segments = 12
	knob.rings = 6
	_mesh(root, knob, Vector3(0.0, h + 0.06, 0.0), _mat(top_color, 0.72), true)

	for band_y in [h * 0.32, h * 0.68]:
		var band := TorusMesh.new()
		band.inner_radius = r * 0.93
		band.outer_radius = r * 1.04
		band.rings = 22
		band.ring_segments = 5
		_mesh(root, band, Vector3(0.0, band_y, 0.0), _mat(top_color.darkened(0.05), 0.8), true)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(color.lightened(0.28), 0.36 if p["required"] else 0.24)
	ring_mat.no_depth_test = false
	var ring := TorusMesh.new()
	ring.inner_radius = r + 0.17
	ring.outer_radius = r + 0.235
	ring.rings = 32
	ring.ring_segments = 6
	var ring_mi := _mesh(root, ring, Vector3(0.0, h * 0.56, 0.0), ring_mat, false)
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var bead: MeshInstance3D = null
	if p["required"]:
		var bead_mesh := SphereMesh.new()
		bead_mesh.radius = 0.055
		bead_mesh.height = 0.11
		bead_mesh.radial_segments = 8
		bead_mesh.rings = 4
		var bead_mat := StandardMaterial3D.new()
		bead_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bead_mat.albedo_color = Color(color.lightened(0.35), 1.0)
		bead = _mesh(root, bead_mesh, Vector3(r + 0.23, h * 0.56, 0.0), bead_mat, false)
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_animated.append({
			"node": bead, "kind": "orbit", "radius": r + 0.23, "height": h * 0.56,
			"angle": float(hash(p["id"]) % 360) * 0.0174, "speed": 1.1,
		})

	if not p["required"]:
		var bell := SphereMesh.new()
		bell.radius = 0.075
		bell.height = 0.14
		bell.radial_segments = 8
		bell.rings = 4
		var bell_mat := _mat(Color("#E9C46A"), 0.45)
		bell_mat.metallic = 0.25
		var bell_mi := _mesh(root, bell, Vector3(0.0, h + 0.22, 0.0), bell_mat, true)
		_animated.append({"node": bell_mi, "kind": "bell", "phase": float(hash(p["id"]) % 100) * 0.1})

	var label := _label3d("「%s」" % p["name"], Vector3(0.0, h + 0.52, 0.0), 52)
	root.add_child(label)

	# Collider is the visual shaft only.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("pillar_id", String(p["id"]))
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = r * 0.97
	cyl.height = h
	shape.shape = cyl
	shape.position = Vector3(0.0, h * 0.5, 0.0)
	body.add_child(shape)
	root.add_child(body)

	_pillar_views[p["id"]] = {
		"root": root,
		"ring": ring_mi,
		"ring_mat": ring_mat,
		"shaft_mat": shaft_mat,
		"bead": bead,
		"base_color": color,
		"height": h,
		"radius": r,
		"required": p["required"],
		"hover": false,
		"done": false,
	}


func _build_start() -> void:
	var root := Node3D.new()
	root.name = "Start"
	root.position = start_pos
	add_child(root)
	_contact_shadow(root, 0.58, 0.10)
	var pad := CylinderMesh.new()
	pad.top_radius = 0.42
	pad.bottom_radius = 0.46
	pad.height = 0.09
	pad.radial_segments = 18
	_mesh(root, pad, Vector3(0.0, -0.045, 0.0), _mat(Color("#F6EAD2"), 0.8), false)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color("#F4B860")
	var loop := TorusMesh.new()
	loop.inner_radius = 0.13
	loop.outer_radius = 0.21
	loop.rings = 24
	loop.ring_segments = 7
	var loop_mi := _mesh(root, loop, Vector3(0.0, 0.13, 0.0), ring_mat, true)
	loop_mi.rotation_degrees.x = 90.0
	_animated.append({"node": loop_mi, "kind": "spin", "phase": 0.0, "base": loop_mi.position})

	var pearl := SphereMesh.new()
	pearl.radius = 0.055
	pearl.height = 0.11
	pearl.radial_segments = 8
	pearl.rings = 4
	var pearl_mi := _mesh(root, pearl, Vector3(0.0, 0.13, 0.0), _mat(Color("#FFF6E2"), 0.35), true)
	_animated.append({"node": pearl_mi, "kind": "bob", "phase": 0.0, "base_y": 0.13})

	var light := OmniLight3D.new()
	light.light_color = Color("#FFD28A")
	light.light_energy = 0.45
	light.omni_range = 1.9
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(light)

	var label := _label3d("起点", Vector3(0.0, 0.72, 0.0), 48)
	root.add_child(label)
	_pillar_views["__start"] = {"root": root, "loop": loop_mi}


func _build_goal() -> void:
	var root := Node3D.new()
	root.name = "Goal"
	root.position = goal_pos
	add_child(root)
	_contact_shadow(root, goal_radius * 1.22, 0.10)
	var pad := CylinderMesh.new()
	pad.top_radius = goal_radius
	pad.bottom_radius = goal_radius + 0.08
	pad.height = 0.1
	pad.radial_segments = 20
	_mesh(root, pad, Vector3(0.0, -0.05, 0.0), _mat(Color("#F7EAD2"), 0.78), false)

	var inner := CylinderMesh.new()
	inner.top_radius = goal_radius * 0.78
	inner.bottom_radius = goal_radius * 0.78
	inner.height = 0.025
	inner.radial_segments = 20
	_mesh(root, inner, Vector3(0.0, 0.012, 0.0), _mat(Color("#F1C98A"), 0.86), false)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color("#F4B860")
	var ring := TorusMesh.new()
	ring.inner_radius = goal_radius * 0.86
	ring.outer_radius = goal_radius * 0.97
	ring.rings = 32
	ring.ring_segments = 6
	var ring_mi := _mesh(root, ring, Vector3(0.0, 0.045, 0.0), ring_mat, false)
	_animated.append({"node": ring_mi, "kind": "pulse", "phase": 0.0})

	for i in 4:
		var ang := TAU * float(i) / 4.0 + PI * 0.25
		var post := CylinderMesh.new()
		post.top_radius = 0.026
		post.bottom_radius = 0.036
		post.height = 0.30
		post.radial_segments = 6
		_mesh(root, post, Vector3(cos(ang) * (goal_radius + 0.20), 0.15, sin(ang) * (goal_radius + 0.20)), _mat(palette["island_edge"], 0.85), true)
		var bulb := SphereMesh.new()
		bulb.radius = 0.055
		bulb.height = 0.11
		bulb.radial_segments = 8
		bulb.rings = 4
		_mesh(root, bulb, Vector3(cos(ang) * (goal_radius + 0.20), 0.33, sin(ang) * (goal_radius + 0.20)), _mat(Color("#F4B860"), 0.4), true)

	var gem := Node3D.new()
	gem.position = Vector3(0.0, 0.42, 0.0)
	root.add_child(gem)
	var gem_mat := StandardMaterial3D.new()
	gem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gem_mat.albedo_color = Color("#F6B84E")
	var gem_ring := TorusMesh.new()
	gem_ring.inner_radius = 0.09
	gem_ring.outer_radius = 0.145
	gem_ring.rings = 20
	gem_ring.ring_segments = 6
	var gem_ring_mi := _mesh(gem, gem_ring, Vector3.ZERO, gem_mat, false)
	gem_ring_mi.rotation_degrees.x = 90.0
	var orb := SphereMesh.new()
	orb.radius = 0.055
	orb.height = 0.11
	orb.radial_segments = 8
	orb.rings = 4
	var orb_mat := StandardMaterial3D.new()
	orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	orb_mat.albedo_color = Color("#FFF4D8")
	_mesh(gem, orb, Vector3.ZERO, orb_mat, false)
	_animated.append({"node": gem, "kind": "gem", "phase": 0.0})

	var light := OmniLight3D.new()
	light.light_color = Color("#FFD28A")
	light.light_energy = 0.5
	light.omni_range = 2.2
	light.shadow_enabled = false
	light.position = Vector3(0.0, 0.45, 0.0)
	root.add_child(light)

	var label := _label3d("结台", Vector3(0.0, 0.95, 0.0), 48)
	root.add_child(label)
	_pillar_views["__goal"] = {"root": root, "ring": ring_mi, "mat": ring_mat}


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("id", "knotline"))) + 419
	var spots: Array[Vector3] = []
	var tries := 0
	while spots.size() < 14 and tries < 160:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(1.25, 3.95)
		var p := Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		var ok := true
		for pillar in pillars:
			if p.distance_to(Vector3(pillar["pos3"].x, 0.0, pillar["pos3"].z)) < pillar["radius"] + 0.95:
				ok = false
				break
		if not ok:
			continue
		if Vector2(p.x - start_pos.x, p.z - start_pos.z).length() < 0.95:
			continue
		if Vector2(p.x - goal_pos.x, p.z - goal_pos.z).length() < 1.0:
			continue
		for s in spots:
			if Vector2(p.x - s.x, p.z - s.z).length() < 0.62:
				ok = false
				break
		if ok:
			spots.append(p)

	var leaf_colors := [palette["leaf"], palette["leaf"].lightened(0.12), palette["leaf"].darkened(0.1)]
	var bush_mat := _mat(leaf_colors[0], 0.92)
	var bush_mat2 := _mat(leaf_colors[1], 0.92)
	var stone_mat := _mat(Color("#B9B3A4"), 0.96)
	for i in spots.size():
		var p := spots[i]
		if i % 4 == 0:
			_build_rock(p, stone_mat, rng)
		elif i % 4 == 1:
			_build_bush(p, bush_mat, bush_mat2, rng)
		elif i % 4 == 2:
			_build_flower(p, rng)
		else:
			_build_mushroom(p, rng)

	# A small signpost near the start.
	var sign_root := Node3D.new()
	sign_root.position = start_pos + Vector3(0.5, 0.0, -0.4)
	add_child(sign_root)
	_contact_shadow(sign_root, 0.20, 0.10)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.025
	stick.bottom_radius = 0.03
	stick.height = 0.55
	stick.radial_segments = 6
	_mesh(sign_root, stick, Vector3(0.0, 0.275, 0.0), _mat(Color("#A9745B"), 0.9), true)
	var board := BoxMesh.new()
	board.size = Vector3(0.34, 0.19, 0.035)
	_mesh(sign_root, board, Vector3(0.0, 0.52, 0.0), _mat(Color("#F1DDB8"), 0.85), true)
	sign_root.rotation.y = -0.5


func _build_rock(p: Vector3, mat: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = rng.randf_range(0.12, 0.25)
	mesh.height = mesh.radius * 1.7
	mesh.radial_segments = 6
	mesh.rings = 3
	var root := Node3D.new()
	root.position = p
	add_child(root)
	_contact_shadow(root, mesh.radius * 1.25, 0.13)
	var mi := _mesh(root, mesh, Vector3(0.0, mesh.height * 0.32, 0.0), mat, true)
	mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
	mi.scale = Vector3(1.0, 0.7, 0.9)


func _build_bush(p: Vector3, m1: StandardMaterial3D, m2: StandardMaterial3D, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	var s := rng.randf_range(0.26, 0.38)
	_contact_shadow(root, s * 1.15, 0.13)
	var a := SphereMesh.new()
	a.radius = s
	a.height = s * 1.7
	a.radial_segments = 8
	a.rings = 4
	_mesh(root, a, Vector3(0.0, s * 0.85, 0.0), m1, true)
	var b := SphereMesh.new()
	b.radius = s * 0.66
	b.height = s * 1.2
	b.radial_segments = 7
	b.rings = 4
	_mesh(root, b, Vector3(s * 0.55, s * 0.6, s * 0.22), m2, true)
	root.rotation.y = rng.randf() * TAU


func _build_flower(p: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	_contact_shadow(root, 0.14, 0.10)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.018
	stem.height = rng.randf_range(0.22, 0.34)
	stem.radial_segments = 5
	_mesh(root, stem, Vector3(0.0, stem.height * 0.5, 0.0), _mat(palette["leaf"], 0.9), true)
	var petal_col: Color = palette["petal"] if rng.randf() > 0.4 else Color("#F2CC8F")
	var petal_mat := _mat(petal_col, 0.8)
	var petal_mesh := SphereMesh.new()
	petal_mesh.radius = 0.078
	petal_mesh.height = 0.052
	petal_mesh.radial_segments = 7
	petal_mesh.rings = 3
	_mesh(root, petal_mesh, Vector3(0.0, stem.height + 0.012, 0.0), petal_mat, true)
	var core := SphereMesh.new()
	core.radius = 0.032
	core.height = 0.05
	core.radial_segments = 6
	core.rings = 3
	_mesh(root, core, Vector3(0.0, stem.height + 0.038, 0.0), _mat(Color("#FFE3A1"), 0.7), true)


func _build_mushroom(p: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = p
	add_child(root)
	_contact_shadow(root, 0.13, 0.10)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.026
	stem.bottom_radius = 0.033
	stem.height = 0.12
	stem.radial_segments = 6
	_mesh(root, stem, Vector3(0.0, 0.06, 0.0), _mat(Color("#F4E6CE"), 0.9), true)
	var cap := SphereMesh.new()
	cap.radius = rng.randf_range(0.075, 0.11)
	cap.height = cap.radius * 0.9
	cap.radial_segments = 8
	cap.rings = 3
	_mesh(root, cap, Vector3(0.0, 0.15, 0.0), _mat(palette["petal"].darkened(0.05), 0.85), true)
	root.rotation.y = rng.randf() * TAU


## Flat stone trail that quietly points from start toward the targets.
func _build_guide_stones() -> void:
	var way := _guide_waypoints()
	if way.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("id", "knotline"))) + 913
	var stone_xforms: Array[Transform3D] = []
	var pebble_xforms: Array[Transform3D] = []
	for i in range(way.size() - 1):
		var a := way[i]
		var b := way[i + 1]
		var seg := b - a
		var n := maxi(1, int(seg.length() / 0.62))
		var perp := Vector2(-seg.y, seg.x).normalized()
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var p := a.lerp(b, t) + perp * rng.randf_range(-0.13, 0.13)
			if _guide_spot_blocked(p):
				continue
			var radius := rng.randf_range(0.10, 0.17)
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(radius, 0.035, radius * rng.randf_range(0.8, 1.1)))
			stone_xforms.append(Transform3D(basis, Vector3(p.x, 0.017, p.y)))
			if rng.randf() < 0.4:
				var pr := 0.035
				var pb := Basis().scaled(Vector3(pr, pr * 0.7, pr))
				var off := Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22))
				pebble_xforms.append(Transform3D(pb, Vector3(p.x + off.x, 0.024, p.y + off.y)))
	if not stone_xforms.is_empty():
		var stone := CylinderMesh.new()
		stone.top_radius = 1.0
		stone.bottom_radius = 1.05
		stone.height = 1.0
		stone.radial_segments = 8
		var mat := _mat(palette["island_edge"].lightened(0.26), 0.95)
		_add_multimesh(stone, stone_xforms, mat, true)
	if not pebble_xforms.is_empty():
		var peb := SphereMesh.new()
		peb.radius = 1.0
		peb.height = 1.4
		peb.radial_segments = 5
		peb.rings = 3
		_add_multimesh(peb, pebble_xforms, _mat(Color("#E4CDA8"), 0.95), true)


func _add_multimesh(mesh: Mesh, xforms: Array[Transform3D], mat: Material, casts: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _guide_waypoints() -> Array[Vector2]:
	var s := Vector2(start_pos.x, start_pos.z)
	var g := Vector2(goal_pos.x, goal_pos.z)
	var out: Array[Vector2] = [s]
	match String(level.get("id", "")):
		"first_knot":
			out.append(Vector2(-1.45, 1.05))
			out.append(Vector2(-0.72, 0.10))
			out.append(Vector2(1.30, -0.40))
		"double_loop":
			out.append(Vector2(-2.15, 0.10))
			out.append(Vector2(-0.65, 0.92))
			out.append(Vector2(0.65, 0.42))
			out.append(Vector2(2.10, 0.72))
		_:
			out.append((s + g) * 0.5)
	out.append(g)
	return out


func _guide_spot_blocked(p: Vector2) -> bool:
	for pillar in pillars:
		if p.distance_to(pillar["center"]) < float(pillar["radius"]) + 0.42:
			return true
	if p.distance_to(Vector2(start_pos.x, start_pos.z)) < 0.78:
		return true
	if p.distance_to(Vector2(goal_pos.x, goal_pos.z)) < 0.85:
		return true
	return false


func _build_clouds() -> void:
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.albedo_color = Color(1.0, 0.96, 0.89, 0.5)
	var bases := [Vector3(5.2, 3.0, -8.5), Vector3(-5.8, 4.0, -7.0), Vector3(8.8, 2.0, -1.0)]
	var scales := [1.0, 0.85, 0.7]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(level.get("id", "knotline"))) + 1223
	var xforms: Array[Transform3D] = []
	for bi in bases.size():
		var base: Vector3 = bases[bi]
		var base_scale: float = scales[bi]
		for i in 3:
			var r := rng.randf_range(0.6, 1.0) * base_scale
			var basis := Basis().scaled(Vector3(r * 1.35, r * 0.48, r))
			var p := base + Vector3(i * 0.85 * base_scale - 0.8 * base_scale, rng.randf_range(-0.1, 0.15), 0.0)
			xforms.append(Transform3D(basis, p))
	if xforms.is_empty():
		return
	var blob := SphereMesh.new()
	blob.radius = 1.0
	blob.height = 2.0
	blob.radial_segments = 8
	blob.rings = 4
	_add_multimesh(blob, xforms, cloud_mat, false)


func _build_dust() -> void:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 28
	dust.lifetime = 7.5
	dust.preprocess = 4.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 4.1
	dust.position = Vector3(0.0, 0.8, 0.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.initial_velocity_min = 0.015
	dust.initial_velocity_max = 0.06
	dust.gravity = Vector3(0.0, 0.02, 0.0)
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.4
	dust.mesh = _particle_sphere(0.018, Color("#FFF4DA"))
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dust)


func _particle_sphere(radius: float, color: Color) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 5
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	return mesh


func _create_burst(at: Vector3, color: Color, amount: int, power: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = 1.5
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = power * 0.55
	p.initial_velocity_max = power
	p.gravity = Vector3(0.0, -1.8, 0.0)
	p.scale_amount_min = 0.55
	p.scale_amount_max = 1.5
	p.mesh = _particle_sphere(0.042, color)
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	get_tree().create_timer(1.8).timeout.connect(p.queue_free)
	return p


func _label3d(text: String, pos: Vector3, size: int) -> Label3D:
	if _font == null:
		_font = KnotFont.ui_font()
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.0023
	l.outline_size = 7
	l.modulate = Color("#40382F")
	l.outline_modulate = Color(1.0, 0.97, 0.9, 0.92)
	l.no_depth_test = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	if _font != null:
		l.font = _font
	return l


func _contact_shadow(parent: Node, radius: float, _alpha: float = 0.13, pos: Vector3 = Vector3(0.0, 0.004, 0.0)) -> void:
	if not (parent is Node3D):
		return
	var wp: Vector3 = (parent as Node3D).global_position + pos
	_shadow_spots.append({"pos": wp, "radius": radius})


func _build_contact_shadows() -> void:
	if _shadow_spots.is_empty():
		return
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 1.0
	disc.radial_segments = 14
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = disc
	mm.instance_count = _shadow_spots.size()
	for i in _shadow_spots.size():
		var spot: Dictionary = _shadow_spots[i]
		var r := float(spot["radius"])
		var p: Vector3 = spot["pos"]
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(r, 0.008, r)), p))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.15, 0.11, 0.07, 0.13)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _mat(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = 0.0
	return m


func _mesh(parent: Node, mesh: Mesh, pos: Vector3, mat: Material, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_time += delta
	for a in _animated:
		var node: Node3D = a["node"]
		if not is_instance_valid(node):
			continue
		match String(a["kind"]):
			"spin":
				node.rotation.y += delta * 0.9
				var base: Vector3 = a.get("base", node.position)
				node.position.y = base.y + sin(_time * 1.7 + float(a.get("phase", 0.0))) * 0.03
			"bob":
				node.position.y = float(a.get("base_y", node.position.y)) + sin(_time * 2.1 + float(a.get("phase", 0.0))) * 0.02
			"pulse":
				var s := 1.0 + sin(_time * 2.3) * 0.035
				node.scale = Vector3(s, 1.0, s)
			"bell":
				node.rotation.z = sin(_time * 1.35 + float(a.get("phase", 0.0))) * 0.16
			"orbit":
				var ang := float(a.get("angle", 0.0)) + _time * float(a.get("speed", 1.0))
				var rr := float(a.get("radius", 0.3))
				var hh := float(a.get("height", 1.0))
				node.position = Vector3(cos(ang) * rr, hh + sin(_time * 2.0) * 0.02, sin(ang) * rr)
			"gem":
				node.rotation.y += delta * 1.1
				node.position.y = 0.42 + sin(_time * 1.9) * 0.035
	# Start loop gets a slow spin independent of its yaw.
	var start_view = _pillar_views.get("__start", {})
	if not start_view.is_empty():
		var loop: Node3D = start_view["loop"]
		if is_instance_valid(loop):
			loop.rotation.y += delta * 1.2
	var goal_view = _pillar_views.get("__goal", {})
	if not goal_view.is_empty():
		var gm: StandardMaterial3D = goal_view.get("mat")
		if gm != null:
			gm.albedo_color = Color("#F4B860").lerp(Color("#FFF1C9"), 0.5 + 0.5 * sin(_time * 2.3))


func set_pillar_hover(id: String, hover: bool) -> void:
	var view: Dictionary = _pillar_views.get(id, {})
	if view.is_empty():
		return
	if bool(view.get("hover", false)) == hover:
		return
	view["hover"] = hover
	if bool(view.get("done", false)):
		return
	var mat: StandardMaterial3D = view["ring_mat"]
	var base: Color = view["base_color"]
	mat.albedo_color = Color(base.lightened(0.45 if hover else 0.28), 0.75 if hover else (0.36 if view["required"] else 0.24))


func set_pillar_done(id: String, done: bool, fx: bool = true) -> void:
	var view: Dictionary = _pillar_views.get(id, {})
	if view.is_empty():
		return
	if bool(view.get("done", false)) == done:
		return
	view["done"] = done
	var mat: StandardMaterial3D = view["ring_mat"]
	var base_col: Color = view["base_color"]
	mat.albedo_color = Color("#FFC24A", 1.0) if done else Color(base_col.lightened(0.28), 0.36)
	var bead = view.get("bead")
	if bead != null and is_instance_valid(bead):
		bead.visible = not done
	if done:
		var ring: Node3D = view["ring"]
		if is_instance_valid(ring):
			var tw := create_tween()
			tw.tween_property(ring, "scale", Vector3(1.28, 1.28, 1.28), 0.18).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(ring, "scale", Vector3(1.0, 1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK)
		if fx:
			var root: Node3D = view["root"]
			if is_instance_valid(root):
				_create_burst(root.position + Vector3(0.0, float(view.get("height", 1.0)) * 0.56, 0.0), Color("#FFE3A3"), 16, 1.5)


func celebrate() -> void:
	var colors := [Color("#FFD477"), Color("#F1A7A0"), Color("#8FD3C7"), Color("#FFF1C9")]
	for i in 4:
		var p := _create_burst(goal_pos + Vector3(0.0, 0.4, 0.0), colors[i], 22, 2.6)
		p.direction = Vector3(cos(i * TAU / 4.0), 1.0, sin(i * TAU / 4.0)).normalized()
		p.spread = 40.0
		p.position += Vector3(cos(i * TAU / 4.0) * 0.15, 0.0, sin(i * TAU / 4.0) * 0.15)


func play_bell(id: String) -> void:
	var view: Dictionary = _pillar_views.get(id, {})
	if view.is_empty():
		return
	var root: Node3D = view["root"]
	if is_instance_valid(root):
		_create_burst(root.position + Vector3(0.0, float(view.get("height", 1.0)) + 0.22, 0.0), Color("#FFE9B0"), 10, 1.0)


func pillar_world_y(id: String) -> float:
	var view: Dictionary = _pillar_views.get(id, {})
	if view.is_empty():
		return 0.0
	return float(view.get("height", 1.0)) * 0.56


func start_anchor_visible_position() -> Vector3:
	return start_pos + Vector3(0.0, 0.13, 0.0)
