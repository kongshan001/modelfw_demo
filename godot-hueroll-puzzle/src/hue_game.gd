extends Node3D

# HueRoll · 滚彩方庭 — scene assembly, camera, input, animation and feedback.
# All gameplay state lives in hue_sim.gd; this file turns it into a tactile 3D toy.

const LEVEL_DIR := "res://levels"
const SAVE_PATH := "user://hueroll_save.cfg"
const TILE_TOP := 0.04
var TILE_H := 0.18
const CUBE_SIZE := 0.94
const CUBE_HALF := 0.47
const ROLL_TIME := 0.20
const CAM_DIST := 17.0
const CAM_HEIGHT := 12.6
const CAM_MIN_SIZE := 6.5
const CAM_MAX_SIZE := 14.5
const CAM_LOOK_UP := 0.12
const CAM_FIT_V := 1.38
const CAM_FIT_H := 1.12

var levels: Array[Dictionary] = []
var sim: HueSim
var level_index := 0
var progress: Dictionary = {}

var ui: HueUI
var sfx: HueSfx

var camera: Camera3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var fill_light: DirectionalLight3D
var accent_light: OmniLight3D
var cube_light: OmniLight3D
var backdrop_mat: ShaderMaterial
var backdrop_quad: MeshInstance3D

var board_root: Node3D
var prop_root: Node3D
var decor_root: Node3D
var fx_root: Node3D
var token_root: Node3D
var cube_root: Node3D
var cube_plaque_mats: Dictionary = {}
var cube_glow: MeshInstance3D
var cube_glow_mat: StandardMaterial3D
var cube_shadow: MeshInstance3D
var hover_ring: MeshInstance3D
var hover_mat: ShaderMaterial
var hover_cell := Vector2i(-9999, -9999)

var target_vis: Dictionary = {}
var decor_floaters: Array[Dictionary] = []
var token_time := 0.0

var theme: Dictionary = {}
var board_center := Vector3.ZERO
var yaw_current := PI * 0.25
var yaw_target := PI * 0.25
var cam_size_current := 8.0
var cam_size_target := 8.0
var cam_rot_t := -1.0
var cam_rot_from := 0.0
var cam_rot_to := 0.0
var cam_rot_from_size := 8.0

var roll_anim: Dictionary = {}
var pending_dir := ""
var bumping := false
var overlay := ""
var debug_visible := false
var hint_seen := false
var win_pending := false
var win_timer := -1.0
var elapsed := 0.0
var perf_timer := 0.0
var key_dirs: Dictionary = {}

var _plane_mesh: PlaneMesh
var _quad_mesh: QuadMesh
var _token_halo_mesh: ArrayMesh
var _particle_material: StandardMaterial3D


func _ready() -> void:
	_load_levels()
	_load_progress()
	_build_stage()
	sim = HueSim.new()
	ui = HueUI.new()
	add_child(ui)
	ui.setup(self)
	load_level(0, true)


# ------------------------------------------------------------------ boot


func _load_levels() -> void:
	levels.clear()
	var names := DirAccess.get_files_at(LEVEL_DIR)
	names.sort()
	for n in names:
		if not n.ends_with(".json"):
			continue
		var f := FileAccess.open("%s/%s" % [LEVEL_DIR, n], FileAccess.READ)
		if f == null:
			push_error("HueRoll: cannot open level %s" % n)
			continue
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			push_error("HueRoll: bad level JSON %s" % n)
			continue
		levels.append(parsed)
	if levels.is_empty():
		push_error("HueRoll: no levels found")


func _load_progress() -> void:
	progress = {}
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var entries = cfg.get_value("progress", "entries", {})
		if typeof(entries) == TYPE_DICTIONARY:
			progress = entries


func _save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "entries", progress)
	cfg.save(SAVE_PATH)


func _build_stage() -> void:
	world_env = WorldEnvironment.new()
	world_env.name = "Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2438")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8c9d6")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env.environment = env
	add_child(world_env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 200.0
	camera.size = 8.0
	add_child(camera)

	backdrop_quad = MeshInstance3D.new()
	backdrop_quad.name = "Backdrop"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	backdrop_quad.mesh = quad
	backdrop_mat = ShaderMaterial.new()
	backdrop_mat.shader = load("res://shaders/backdrop.gdshader")
	backdrop_mat.render_priority = -100
	backdrop_quad.material_override = backdrop_mat
	backdrop_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	backdrop_quad.position = Vector3(0, 0, -80)
	camera.add_child(backdrop_quad)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color("fff0da")
	sun.light_energy = 0.74
	sun.rotation_degrees = Vector3(-52, -38, 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_max_distance = 32.0
	add_child(sun)

	fill_light = DirectionalLight3D.new()
	fill_light.name = "Fill"
	fill_light.light_color = Color("9fb6ff")
	fill_light.light_energy = 0.28
	fill_light.rotation_degrees = Vector3(-24, 142, 0)
	fill_light.shadow_enabled = false
	add_child(fill_light)

	var top_fill := DirectionalLight3D.new()
	top_fill.name = "TopFill"
	top_fill.light_color = Color("fff1dd")
	top_fill.light_energy = 0.90
	top_fill.rotation_degrees = Vector3(-90, 0, 0)
	top_fill.shadow_enabled = false
	add_child(top_fill)

	accent_light = OmniLight3D.new()
	accent_light.name = "AccentLight"
	accent_light.light_energy = 0.34
	accent_light.omni_range = 10.0
	accent_light.shadow_enabled = false
	add_child(accent_light)

	cube_light = OmniLight3D.new()
	cube_light.name = "CubeLight"
	cube_light.light_color = Color("ffe7c9")
	cube_light.light_energy = 0.30
	cube_light.omni_range = 3.2
	cube_light.shadow_enabled = false
	add_child(cube_light)

	board_root = Node3D.new()
	board_root.name = "Board"
	add_child(board_root)
	prop_root = Node3D.new()
	prop_root.name = "Props"
	add_child(prop_root)
	decor_root = Node3D.new()
	decor_root.name = "Decor"
	add_child(decor_root)
	token_root = Node3D.new()
	token_root.name = "Tokens"
	add_child(token_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)

	hover_ring = MeshInstance3D.new()
	hover_ring.mesh = HueArt.ring_mesh(0.74, 1.0, 48)
	hover_mat = HueArt.ring_material(Color("fff3e2"), 0.55, 0.35)
	hover_ring.material_override = hover_mat
	hover_ring.position = Vector3(0, 0.06, 0)
	hover_ring.visible = false
	hover_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(hover_ring)

	_plane_mesh = PlaneMesh.new()
	_plane_mesh.size = Vector2(1.04, 1.04)
	_plane_mesh.subdivide_width = 8
	_plane_mesh.subdivide_depth = 8
	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE
	_token_halo_mesh = HueArt.ring_mesh(0.82, 1.0, 40)

	_particle_material = StandardMaterial3D.new()
	_particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_particle_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_particle_material.albedo_texture = HueArt.soft_dot_texture(64)
	_particle_material.albedo_color = Color(1, 1, 1, 1)
	_particle_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_particle_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	sfx = HueSfx.new()
	add_child(sfx)
	get_viewport().size_changed.connect(_on_viewport_changed)


# ------------------------------------------------------------------ level lifecycle


func load_level(index: int, first := false) -> void:
	if index < 0 or index >= levels.size():
		return
	level_index = index
	overlay = ""
	win_pending = false
	win_timer = -1.0
	roll_anim = {}
	pending_dir = ""
	cam_rot_t = -1.0
	hover_ring.visible = false
	hint_seen = false
	token_time = 0.0

	var data: Dictionary = levels[index]
	if not sim.load_level(data):
		push_error("HueRoll: failed to load level %s" % data.get("id", "?"))
		return
	theme = sim.theme
	_apply_theme()
	_rebuild_board()
	_rebuild_cube()
	_reset_camera()
	_refresh_all(true)
	ui.close_overlays()
	ui.refresh()
	ui.show_hint(sim.hint)
	if not first:
		ui.flash_in()


func _apply_theme() -> void:
	var env := world_env.environment
	env.ambient_light_color = HueArt.theme_color(theme, "ambient", Color("d8c9d6")).lerp(Color("ece4d8"), 0.45)
	env.ambient_light_energy = 0.62
	env.background_color = HueArt.theme_color(theme, "bg_bottom", Color("f8e7d6"))
	backdrop_mat.set_shader_parameter("top_color", HueArt.theme_color(theme, "bg_top", Color("bfd7ef")))
	backdrop_mat.set_shader_parameter("bottom_color", HueArt.theme_color(theme, "bg_bottom", Color("f8e7d6")))
	backdrop_mat.set_shader_parameter("accent_color", HueArt.theme_color(theme, "accent", Color("e8796b")))
	accent_light.light_color = HueArt.theme_color(theme, "accent", Color("e8796b"))
	board_center = Vector3(sim.width * 0.5, 0.0, sim.height * 0.5)
	accent_light.position = board_center + Vector3(0, 4.5, 0)
	ui.set_theme(theme)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()


func _rebuild_board() -> void:
	_clear_children(board_root)
	_clear_children(prop_root)
	_clear_children(decor_root)
	_clear_children(fx_root)
	_clear_children(token_root)
	target_vis.clear()
	decor_floaters.clear()

	var side_col := HueArt.theme_color(theme, "tile_side", Color("6c5a70"))
	var accent_col := HueArt.theme_color(theme, "accent", Color("e8796b"))
	var base_top := HueArt.theme_color(theme, "tile_top", Color("f7efe3")).lerp(accent_col, 0.05).darkened(0.015)

	# A single dark island slab under the grid.
	var plate := MeshInstance3D.new()
	plate.mesh = HueArt.rounded_box_mesh(0.09, 14)
	plate.material_override = HueArt.matte(side_col.darkened(0.02), 0.76)
	plate.scale = Vector3(sim.width + 0.55, 0.42, sim.height + 0.55)
	plate.position = Vector3(sim.width * 0.5, TILE_TOP - 0.06 - 0.21, sim.height * 0.5)
	plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_root.add_child(plate)

	# Dark rim plates (1 draw call) + cream ceramic inlays in two subtle tints (2 calls).
	var rim_mesh := HueArt.rounded_box_mesh(0.04, 12)
	var top_mesh := HueArt.rounded_box_mesh(0.06, 12)
	var cells: Array = sim.walkable.keys()
	cells.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))

	var rims := MultiMesh.new()
	rims.transform_format = MultiMesh.TRANSFORM_3D
	rims.instance_count = cells.size()
	rims.mesh = rim_mesh
	for i in cells.size():
		var c: Vector2i = cells[i]
		var xf := Transform3D(Basis().scaled(Vector3(0.94, 0.18, 0.94)), Vector3(c.x + 0.5, TILE_TOP - 0.06 - 0.09, c.y + 0.5))
		rims.set_instance_transform(i, xf)
	var rims_mi := MultiMeshInstance3D.new()
	rims_mi.multimesh = rims
	rims_mi.material_override = HueArt.matte(side_col.lightened(0.14), 0.70)
	rims_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_root.add_child(rims_mi)

	for parity in 2:
		var subset: Array = []
		for c in cells:
			if (int(c.x) + int(c.y)) % 2 == parity:
				subset.append(c)
		var tops := MultiMesh.new()
		tops.transform_format = MultiMesh.TRANSFORM_3D
		tops.instance_count = subset.size()
		tops.mesh = top_mesh
		for i in subset.size():
			var c: Vector2i = subset[i]
			var xf := Transform3D(Basis().scaled(Vector3(0.80, 0.06, 0.80)), Vector3(c.x + 0.5, TILE_TOP - 0.03, c.y + 0.5))
			tops.set_instance_transform(i, xf)
		var tops_mi := MultiMeshInstance3D.new()
		tops_mi.multimesh = tops
		var top_mat := HueArt.matte(base_top.lightened(0.16).lerp(Color.WHITE, 0.015 * float(parity)), 0.50)
		top_mat.emission_enabled = true
		top_mat.emission = base_top.lightened(0.12)
		top_mat.emission_energy_multiplier = 0.55
		tops_mi.material_override = top_mat
		tops_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board_root.add_child(tops_mi)
	for cell in sim.pools:
		_build_pool(cell)
	for cell in sim.target_req:
		_build_target(cell)
	for cell in sim.props:
		_build_prop(cell)
	_build_decor()
	_update_backdrop(true)


func _cell_pos(cell: Vector2i, y: float) -> Vector3:
	return Vector3(cell.x + 0.5, y, cell.y + 0.5)


func _build_pool(cell: Vector2i) -> void:
	var color := HueArt.paint_color(str(sim.pools[cell]))
	var mi := MeshInstance3D.new()
	mi.mesh = _plane_mesh
	var mat := HueArt.puddle_material(color, 0.85)
	mi.material_override = mat
	mi.position = _cell_pos(cell, TILE_TOP + 0.012)
	mi.rotation.x = -PI * 0.5
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	board_root.add_child(mi)
	# A couple of glossy droplets give the puddle a bit of 3D body.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sim.level_id) + cell.x * 97 + cell.y * 31
	for i in 2:
		var drop := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.025, 0.045)
		sphere.height = sphere.radius * 1.4
		sphere.radial_segments = 8
		sphere.rings = 4
		drop.mesh = sphere
		drop.material_override = HueArt.paint_material(color)
		drop.position = _cell_pos(cell, TILE_TOP + 0.055)
		drop.position.x += rng.randf_range(-0.32, 0.32)
		drop.position.z += rng.randf_range(-0.32, 0.32)
		drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board_root.add_child(drop)


func _build_target(cell: Vector2i) -> void:
	var id := str(sim.target_req[cell])
	var color := HueArt.paint_color(id)

	var decal := MeshInstance3D.new()
	decal.mesh = _quad_mesh
	var decal_mat := HueArt.sigil_material(id, color, 0.98)
	decal.material_override = decal_mat
	decal.position = _cell_pos(cell, TILE_TOP + 0.045)
	decal.rotation.x = -PI * 0.5
	decal.scale = Vector3(0.86, 0.86, 0.86)
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	token_root.add_child(decal)

	var patch := MeshInstance3D.new()
	patch.mesh = HueArt.rounded_box_mesh()
	patch.material_override = HueArt.paint_material(color)
	patch.position = _cell_pos(cell, TILE_TOP + 0.028)
	patch.scale = Vector3(0.82, 0.014, 0.82)
	patch.visible = false
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	token_root.add_child(patch)

	var stamp := MeshInstance3D.new()
	stamp.mesh = _quad_mesh
	stamp.material_override = HueArt.sigil_material(id, HueArt.CREAM, 0.92)
	stamp.position = _cell_pos(cell, TILE_TOP + 0.049)
	stamp.rotation.x = -PI * 0.5
	stamp.scale = Vector3(0.66, 0.66, 0.66)
	stamp.visible = false
	stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	token_root.add_child(stamp)

	var token := Node3D.new()
	token.position = _cell_pos(cell, 0.66)
	token_root.add_child(token)

	var sprite := Sprite3D.new()
	sprite.texture = HueArt.sigil_texture(id)
	sprite.modulate = color
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.pixel_size = 0.0042
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	sprite.no_depth_test = false
	token.add_child(sprite)

	var halo := MeshInstance3D.new()
	halo.mesh = _token_halo_mesh
	var halo_mat := HueArt.ring_material(color, 0.38, 0.3)
	halo.material_override = halo_mat
	halo.scale = Vector3(0.55, 0.55, 0.55)
	token.add_child(halo)

	target_vis[cell] = {
		"id": id,
		"color": color,
		"decal": decal,
		"decal_mat": decal_mat,
		"patch": patch,
		"stamp": stamp,
		"token": token,
		"halo": halo,
		"phase": float(cell.x * 1.7 + cell.y * 2.3),
	}


func _build_prop(cell: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sim.level_id) * 13 + cell.x * 131 + cell.y * 17
	var node := Node3D.new()
	node.position = _cell_pos(cell, 0.0)
	prop_root.add_child(node)

	var base := MeshInstance3D.new()
	base.mesh = HueArt.rounded_box_mesh()
	base.material_override = HueArt.matte(HueArt.INK.darkened(0.12), 0.7)
	base.position = Vector3(0, -0.06, 0)
	base.scale = Vector3(0.8, 0.18, 0.8)
	node.add_child(base)

	var stone := MeshInstance3D.new()
	stone.mesh = HueArt.rounded_box_mesh()
	stone.material_override = HueArt.matte(HueArt.theme_color(theme, "tile_side", HueArt.INK).lightened(0.06), 0.6)
	stone.position = Vector3(0, 0.35, 0)
	stone.scale = Vector3(0.52, 0.7 + rng.randf_range(0.0, 0.25), 0.52)
	stone.rotation.y = rng.randf_range(-0.25, 0.25)
	node.add_child(stone)

	var cap := MeshInstance3D.new()
	cap.mesh = HueArt.rounded_box_mesh()
	cap.material_override = HueArt.matte(HueArt.theme_color(theme, "accent", Color("e8796b")), 0.4)
	cap.position = Vector3(0, 0.78 + rng.randf_range(0.0, 0.1), 0)
	cap.scale = Vector3(0.24, 0.09, 0.24)
	cap.rotation.y = rng.randf_range(0.0, TAU)
	node.add_child(cap)


func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(sim.level_id) * 7 + 20261126
	var center := board_center
	var cloud_color := HueArt.theme_color(theme, "cloud", Color("f3e3d3"))
	var accent := HueArt.theme_color(theme, "accent", Color("e8796b"))
	var side := HueArt.theme_color(theme, "tile_side", HueArt.INK)

	# Floating satellite slabs with a tiny flower or crystal.
	var satellites := [
		center + Vector3(-sim.width * 0.5 - 2.7, -0.85, -0.6),
		center + Vector3(sim.width * 0.5 + 2.5, -1.05, 0.9),
		center + Vector3(0.8, -1.25, -sim.height * 0.5 - 2.4),
	]
	for i in satellites.size():
		var node := Node3D.new()
		node.position = satellites[i]
		decor_root.add_child(node)
		var slab := MeshInstance3D.new()
		slab.mesh = HueArt.rounded_box_mesh()
		slab.material_override = HueArt.matte(cloud_color, 0.8)
		slab.scale = Vector3(0.9, 0.22, 0.9)
		slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(slab)
		if i % 2 == 0:
			var stem := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.025
			cyl.bottom_radius = 0.03
			cyl.height = 0.34
			cyl.radial_segments = 6
			stem.mesh = cyl
			stem.material_override = HueArt.matte(Color("6f9e77"), 0.8)
			stem.position = Vector3(0, 0.27, 0)
			node.add_child(stem)
			var bloom := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			sphere.height = 0.24
			sphere.radial_segments = 10
			sphere.rings = 5
			bloom.mesh = sphere
			bloom.material_override = HueArt.matte(accent.lightened(0.08), 0.55)
			bloom.position = Vector3(0, 0.54, 0)
			bloom.scale = Vector3(1.0, 0.78, 1.0)
			node.add_child(bloom)
		else:
			var crystal := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.5, 0.3)
			crystal.mesh = box
			crystal.material_override = HueArt.matte(accent.darkened(0.1), 0.35, 0.05)
			crystal.position = Vector3(0, 0.44, 0)
			crystal.rotation = Vector3(0.2, 0.5, 0.4)
			node.add_child(crystal)
		decor_floaters.append({
			"node": node, "base_y": node.position.y,
			"phase": float(i) * 1.7, "amp": 0.04,
		})

	# Soft clouds under and behind the island.
	for i in 5:
		var cloud := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 0.8
		sphere.radial_segments = 14
		sphere.rings = 7
		cloud.mesh = sphere
		var mat := HueArt.matte(cloud_color.lightened(0.04 + 0.03 * i), 0.95)
		mat.emission_enabled = true
		mat.emission = cloud_color.lightened(0.10)
		mat.emission_energy_multiplier = 0.24
		cloud.material_override = mat
		var ang := TAU * float(i) / 5.0 + rng.randf_range(-0.25, 0.25)
		var rad := maxf(sim.width, sim.height) * rng.randf_range(0.55, 0.9)
		cloud.position = center + Vector3(cos(ang) * rad, rng.randf_range(-2.4, -1.5), sin(ang) * rad)
		cloud.scale = Vector3(rng.randf_range(1.7, 3.0), rng.randf_range(0.28, 0.5), rng.randf_range(1.0, 1.8))
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor_root.add_child(cloud)
		decor_floaters.append({
			"node": cloud, "base_y": cloud.position.y,
			"phase": float(i) * 0.9, "amp": 0.05,
		})

	# Floating shards.
	for i in 6:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.13, 0.22, 0.13)
		shard.mesh = box
		var col := accent if i % 2 == 0 else cloud_color
		shard.material_override = HueArt.matte(col.lightened(0.05), 0.45)
		var ang := TAU * float(i) / 6.0 + 0.4
		var rad := maxf(sim.width, sim.height) * rng.randf_range(0.55, 0.8)
		shard.position = center + Vector3(cos(ang) * rad, rng.randf_range(0.4, 1.7), sin(ang) * rad)
		shard.rotation = Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU))
		shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor_root.add_child(shard)
		decor_floaters.append({
			"node": shard, "base_y": shard.position.y,
			"phase": float(i) * 1.3, "amp": 0.08, "spin": 0.25 + 0.1 * i,
		})

	# Small mossy stones along the plate rim.
	for i in 8:
		var rock := MeshInstance3D.new()
		rock.mesh = HueArt.rounded_box_mesh(0.10, 10)
		rock.material_override = HueArt.matte(side.lightened(0.16), 0.75)
		var ang := TAU * float(i) / 8.0 + 0.2
		var rx := sim.width * 0.5 + cos(ang) * (sim.width * 0.5 + 0.30)
		var rz := sim.height * 0.5 + sin(ang) * (sim.height * 0.5 + 0.30)
		rock.position = Vector3(rx, -0.30 + sin(ang) * 0.03, rz)
		rock.scale = Vector3(0.22, 0.10 + 0.04 * (i % 3), 0.18)
		rock.rotation.y = ang
		rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor_root.add_child(rock)


# ------------------------------------------------------------------ cube


func _rebuild_cube() -> void:
	if cube_root != null:
		cube_root.queue_free()
	if cube_shadow != null:
		cube_shadow.queue_free()
	if cube_glow != null:
		cube_glow.queue_free()
	cube_root = Node3D.new()
	cube_root.name = "Cube"
	add_child(cube_root)

	var base := MeshInstance3D.new()
	base.mesh = HueArt.rounded_box_mesh()
	base.material_override = HueArt.matte(Color("5b4a64"), 0.50, 0.03)
	base.scale = Vector3(CUBE_SIZE, CUBE_SIZE, CUBE_SIZE)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	cube_root.add_child(base)

	cube_plaque_mats.clear()
	var faces := {
		"up": {"pos": Vector3(0, 0.478, 0), "rot": Vector3(0, 0, 0)},
		"down": {"pos": Vector3(0, -0.478, 0), "rot": Vector3(PI, 0, 0)},
		"east": {"pos": Vector3(0.478, 0, 0), "rot": Vector3(0, 0, -PI * 0.5)},
		"west": {"pos": Vector3(-0.478, 0, 0), "rot": Vector3(0, 0, PI * 0.5)},
		"south": {"pos": Vector3(0, 0, 0.478), "rot": Vector3(PI * 0.5, 0, 0)},
		"north": {"pos": Vector3(0, 0, -0.478), "rot": Vector3(-PI * 0.5, 0, 0)},
	}
	for dir in faces:
		var info: Dictionary = faces[dir]
		var plaque := MeshInstance3D.new()
		plaque.mesh = HueArt.rounded_box_mesh()
		var mat := HueArt.paint_material(HueArt.paint_color("blank"))
		plaque.material_override = mat
		plaque.position = info.pos
		plaque.rotation = info.rot
		plaque.scale = Vector3(0.66, 0.024, 0.66)
		plaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cube_root.add_child(plaque)
		cube_plaque_mats[dir] = mat

	# Contact shadow and the bottom-colour halo live in world space.
	cube_shadow = MeshInstance3D.new()
	cube_shadow.mesh = _quad_mesh
	cube_shadow.material_override = HueArt.soft_shadow_material(0.28)
	cube_shadow.rotation.x = -PI * 0.5
	cube_shadow.scale = Vector3(0.98, 0.98, 1.0)
	cube_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cube_shadow)

	cube_glow = MeshInstance3D.new()
	cube_glow.mesh = _quad_mesh
	cube_glow_mat = HueArt.unshaded(HueArt.CREAM, 0.18)
	cube_glow_mat.albedo_texture = HueArt.soft_dot_texture(64)
	cube_glow.material_override = cube_glow_mat
	cube_glow.rotation.x = -PI * 0.5
	cube_glow.scale = Vector3(0.76, 0.76, 1.0)
	cube_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cube_glow)

	_place_cube(sim.pos)
	_update_cube_faces(true)


func _place_cube(cell: Vector2i) -> void:
	if cube_root == null:
		return
	cube_root.position = _cell_pos(cell, TILE_TOP + CUBE_HALF)
	cube_root.basis = Basis.IDENTITY
	cube_root.scale = Vector3.ONE
	_update_cube_ground_shadow(cell)
	if cube_light != null:
		cube_light.position = cube_root.position + Vector3(0, 1.55, 0)


func _update_cube_ground_shadow(cell: Vector2i) -> void:
	if cube_shadow == null or cube_glow == null:
		return
	var p := _cell_pos(cell, TILE_TOP + 0.052)
	cube_shadow.position = p
	cube_glow.position = p + Vector3(0, 0.004, 0)


func _update_cube_faces(instant := true) -> void:
	var down_id := str(sim.faces.get("down", "blank"))
	for dir in HueSim.FACE_DIRS:
		var mat: StandardMaterial3D = cube_plaque_mats.get(dir)
		if mat == null:
			continue
		var id := str(sim.faces.get(dir, "blank"))
		var c := HueArt.paint_color(id)
		if id == "blank":
			c = c.darkened(0.06)
		if instant:
			mat.albedo_color = c
			mat.emission = c * 0.10
		else:
			var tw := create_tween()
			tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(mat, "albedo_color", c, 0.12)
			tw.parallel().tween_property(mat, "emission", c * 0.10, 0.12)
	if cube_glow_mat != null:
		var gc := HueArt.paint_color(down_id)
		gc.a = 0.34 if down_id != "blank" else 0.14
		cube_glow_mat.albedo_color = gc
		cube_glow.visible = true


# ------------------------------------------------------------------ camera


func _reset_camera() -> void:
	yaw_current = PI * 0.25
	yaw_target = yaw_current
	cam_rot_t = -1.0
	var fit := _fit_for_yaw(yaw_current)
	cam_size_current = fit
	cam_size_target = fit
	camera.size = fit
	_place_camera(yaw_current)
	_update_backdrop(true)
	_update_key_dirs()


func _fit_for_yaw(yaw: float) -> float:
	var aspect := _viewport_aspect()
	var saved := camera.global_transform
	_place_camera(yaw)
	var inv := camera.global_transform.affine_inverse()
	var mx := 0.0
	var my := 0.0
	for corner in [
		Vector3(-0.7, 0.0, -0.7), Vector3(sim.width + 0.7, 0.0, -0.7),
		Vector3(-0.7, 0.0, sim.height + 0.7), Vector3(sim.width + 0.7, 0.0, sim.height + 0.7),
		Vector3(-0.7, 1.25, -0.7), Vector3(sim.width + 0.7, 1.25, sim.height + 0.7),
	]:
		var local: Vector3 = inv * corner
		mx = maxf(mx, absf(local.x))
		my = maxf(my, absf(local.y))
	var fit := maxf(my * 2.0 * CAM_FIT_V, mx * 2.0 / maxf(aspect, 0.1) * CAM_FIT_H)
	camera.global_transform = saved
	return clampf(fit, CAM_MIN_SIZE, CAM_MAX_SIZE)


func _place_camera(yaw: float) -> void:
	var eye := board_center + Vector3(cos(yaw) * CAM_DIST, CAM_HEIGHT, sin(yaw) * CAM_DIST)
	camera.position = eye
	camera.look_at(board_center + Vector3(0, CAM_LOOK_UP, 0), Vector3.UP)


func _update_backdrop(force := false) -> void:
	if backdrop_quad == null:
		return
	var aspect := _viewport_aspect()
	var s := camera.size
	backdrop_quad.scale = Vector3(s * aspect * 1.45, s * 1.45, 1.0)
	backdrop_quad.position = Vector3(0, 0, -80)
	if force:
		pass


func _viewport_aspect() -> float:
	var vs := get_viewport().get_visible_rect().size
	if vs.y <= 0.0:
		return 16.0 / 9.0
	return vs.x / vs.y


func request_rotate(delta: int) -> void:
	if overlay != "" or not roll_anim.is_empty() or cam_rot_t >= 0.0:
		return
	var target_yaw := yaw_target + float(delta) * PI * 0.5
	cam_rot_from = yaw_current
	cam_rot_to = target_yaw
	cam_rot_from_size = camera.size
	var target_fit := _fit_for_yaw(target_yaw)
	cam_size_target = target_fit
	cam_rot_t = 0.0
	hover_ring.visible = false
	if sfx:
		sfx.play("camera")


func _update_camera(delta: float) -> void:
	if cam_rot_t >= 0.0:
		cam_rot_t = minf(1.0, cam_rot_t + delta / 0.30)
		var e := cam_rot_t * cam_rot_t * (3.0 - 2.0 * cam_rot_t)
		yaw_current = lerpf(cam_rot_from, cam_rot_to, e)
		cam_size_current = lerpf(cam_rot_from_size, cam_size_target, e)
		yaw_target = cam_rot_to
		camera.size = cam_size_current
		_place_camera(yaw_current)
		_update_backdrop()
		if cam_rot_t >= 1.0:
			cam_rot_t = -1.0
			yaw_current = yaw_target
			camera.size = cam_size_target
			_place_camera(yaw_current)
			_update_key_dirs()
			_update_hover()
	elif absf(camera.size - cam_size_target) > 0.0005:
		camera.size = lerpf(camera.size, cam_size_target, clampf(delta * 10.0, 0.0, 1.0))
		_update_backdrop()


func _update_key_dirs() -> void:
	var b := camera.global_transform.basis
	var right := Vector2(b.x.x, b.x.z).normalized()
	var up := Vector2(b.y.x, b.y.z).normalized()
	var raw := {
		"w": -right + up,
		"d": right + up,
		"s": right - up,
		"a": -right - up,
	}
	var cardinals := {
		"north": Vector2(0, -1),
		"south": Vector2(0, 1),
		"east": Vector2(1, 0),
		"west": Vector2(-1, 0),
	}
	for key in raw:
		var v: Vector2 = raw[key]
		var best := "north"
		var best_dot := -999.0
		for dir in cardinals:
			var d: float = v.normalized().dot(cardinals[dir])
			if d > best_dot:
				best_dot = d
				best = dir
		key_dirs[key] = best


# ------------------------------------------------------------------ input


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_pointer(event.position)
		return
	if event is InputEventScreenTouch and event.pressed:
		_on_pointer(event.position)
		return


func _on_key(event: InputEventKey) -> void:
	var k := event.keycode
	if overlay == "select":
		if k == KEY_ESCAPE:
			_close_level_select()
		elif k >= KEY_1 and k <= KEY_6:
			var idx := int(k - KEY_1)
			if idx < levels.size():
				request_load_level(idx)
		return
	if overlay == "win":
		if k == KEY_ENTER or k == KEY_SPACE or k == KEY_N:
			request_next_level()
		elif k == KEY_ESCAPE:
			request_level_select()
		elif k == KEY_R:
			request_replay()
		return

	match k:
		KEY_W, KEY_UP:
			_try_key_roll("w")
		KEY_S, KEY_DOWN:
			_try_key_roll("s")
		KEY_A, KEY_LEFT:
			_try_key_roll("a")
		KEY_D, KEY_RIGHT:
			_try_key_roll("d")
		KEY_U, KEY_Z:
			request_undo()
		KEY_R:
			request_reset()
		KEY_Q:
			request_rotate(-1)
		KEY_E:
			request_rotate(1)
		KEY_ESCAPE:
			request_level_select()
		KEY_F1:
			debug_visible = not debug_visible
			ui.toggle_debug(debug_visible)
		KEY_M:
			if sfx:
				var on: bool = sfx.toggle_mute()
				ui.toast("音效已开启" if on else "音效已关闭")
		KEY_F2:
			request_level_select()


func _try_key_roll(key: String) -> void:
	if key_dirs.is_empty():
		_update_key_dirs()
	if key_dirs.has(key):
		try_roll(key_dirs[key])


func _on_pointer(pos: Vector2) -> void:
	if overlay != "" or not roll_anim.is_empty() or cam_rot_t >= 0.0:
		return
	var cell := _cell_under_pointer(pos)
	if cell == Vector2i(-9999, -9999):
		return
	var delta := cell - sim.pos
	if absi(delta.x) + absi(delta.y) != 1:
		return
	var dir := ""
	for d in HueSim.DIR_VECTORS:
		if HueSim.DIR_VECTORS[d] == delta:
			dir = d
			break
	if dir != "":
		try_roll(dir)


func _cell_under_pointer(pos: Vector2) -> Vector2i:
	if camera == null:
		return Vector2i(-9999, -9999)
	var origin := camera.project_ray_origin(pos)
	var normal := camera.project_ray_normal(pos)
	if absf(normal.y) < 0.0001:
		return Vector2i(-9999, -9999)
	var t := (TILE_TOP - origin.y) / normal.y
	if t < 0.0:
		return Vector2i(-9999, -9999)
	var hit := origin + normal * t
	var cell := Vector2i(floori(hit.x), floori(hit.z))
	if not sim.walkable.has(cell):
		return Vector2i(-9999, -9999)
	return cell


func _update_hover() -> void:
	if overlay != "" or not roll_anim.is_empty() or cam_rot_t >= 0.0:
		hover_ring.visible = false
		return
	if DisplayServer.get_name() == "headless":
		hover_ring.visible = false
		return
	if DisplayServer.is_touchscreen_available():
		hover_ring.visible = false
		return
	var vp := get_viewport()
	if vp.gui_get_hovered_control() != null:
		hover_ring.visible = false
		return
	var cell := _cell_under_pointer(vp.get_mouse_position())
	if cell == Vector2i(-9999, -9999) or cell == sim.pos:
		hover_ring.visible = false
		return
	var delta := cell - sim.pos
	if absi(delta.x) + absi(delta.y) != 1:
		hover_ring.visible = false
		return
	var dir := ""
	for d in HueSim.DIR_VECTORS:
		if HueSim.DIR_VECTORS[d] == delta:
			dir = d
			break
	if dir == "" or not sim.can_roll(dir):
		hover_ring.visible = false
		return
	hover_cell = cell
	hover_ring.position = _cell_pos(cell, TILE_TOP + 0.065)
	hover_ring.scale = Vector3(0.42, 0.42, 0.42)
	hover_ring.visible = true


# ------------------------------------------------------------------ rolling


func try_roll(dir: String) -> bool:
	if overlay != "" or cam_rot_t >= 0.0 or not roll_anim.is_empty():
		return false
	if not sim.can_roll(dir):
		_bump(dir)
		if sfx:
			sfx.play("bump")
		return false
	var res := sim.roll(dir)
	if not bool(res.ok):
		return false
	_start_roll_anim(dir, res)
	if not hint_seen:
		hint_seen = true
		ui.hide_hint()
	return true


func _start_roll_anim(dir: String, res: Dictionary) -> void:
	var start_cell: Vector2i = sim.pos - HueSim.DIR_VECTORS[dir]
	var from := _cell_pos(start_cell, TILE_TOP + CUBE_HALF)
	var to := _cell_pos(sim.pos, TILE_TOP + CUBE_HALF)
	var axis := Vector3(0, 0, 1)
	var angle := -PI * 0.5
	var pivot := Vector3.ZERO
	if dir == "east":
		axis = Vector3(0, 0, 1)
		angle = -PI * 0.5
		pivot = Vector3(from.x + CUBE_HALF, TILE_TOP, from.z)
	elif dir == "west":
		axis = Vector3(0, 0, 1)
		angle = PI * 0.5
		pivot = Vector3(from.x - CUBE_HALF, TILE_TOP, from.z)
	elif dir == "south":
		axis = Vector3(1, 0, 0)
		angle = PI * 0.5
		pivot = Vector3(from.x, TILE_TOP, from.z + CUBE_HALF)
	elif dir == "north":
		axis = Vector3(1, 0, 0)
		angle = -PI * 0.5
		pivot = Vector3(from.x, TILE_TOP, from.z - CUBE_HALF)
	roll_anim = {
		"t": 0.0,
		"dir": dir,
		"from": from,
		"to": to,
		"pivot": pivot,
		"axis": axis,
		"angle": angle,
		"result": res,
		"start_cell": start_cell,
		"end_cell": sim.pos,
	}
	cube_root.scale = Vector3.ONE
	cube_shadow.visible = false
	cube_glow.visible = false
	hover_ring.visible = false
	if sfx:
		sfx.play("roll")


func _update_roll(delta: float) -> void:
	if roll_anim.is_empty():
		return
	roll_anim.t = minf(1.0, float(roll_anim.t) + delta / ROLL_TIME)
	var t: float = float(roll_anim.t)
	var e := t * t * (3.0 - 2.0 * t)
	var axis: Vector3 = roll_anim.axis
	var angle: float = float(roll_anim.angle) * e
	var basis := Basis(axis, angle)
	var pivot: Vector3 = roll_anim.pivot
	var from: Vector3 = roll_anim.from
	var pos := pivot + basis * (from - pivot)
	# The cube is slightly inset from the cell edge, so ease the residual gap closed.
	var correction := 1.0 - CUBE_HALF * 2.0
	var dirv: Vector3 = (roll_anim.to - roll_anim.from)
	if dirv.length() > 0.001:
		pos += dirv.normalized() * correction * smoothstep(0.72, 1.0, t)
	cube_root.position = pos
	cube_root.basis = basis
	if cube_light != null:
		cube_light.position = Vector3(pos.x, pos.y + 1.55, pos.z)
	cube_shadow.position = Vector3(pos.x, TILE_TOP + 0.052, pos.z)
	cube_glow.position = Vector3(pos.x, TILE_TOP + 0.056, pos.z)
	cube_shadow.scale = Vector3(0.98, 0.98, 1.0) * lerpf(1.0, 0.72, sin(t * PI))
	if t >= 1.0:
		_finish_roll()


func _finish_roll() -> void:
	var data := roll_anim
	roll_anim = {}
	_place_cube(sim.pos)
	_update_cube_faces(false)
	cube_shadow.visible = true
	cube_glow.visible = true
	cube_shadow.scale = Vector3(0.98, 0.98, 1.0)
	_land_squash()
	var res: Dictionary = data.result
	var end_cell: Vector2i = data.end_cell
	var painted := str(res.get("painted", ""))
	var stamp_result := str(res.get("stamp_result", ""))
	var stamp := str(res.get("stamp", ""))
	if painted != "":
		_spawn_ring(end_cell, HueArt.paint_color(painted), 0.9, true)
		_spawn_burst(end_cell, HueArt.paint_color(painted), 16, 2.2)
		if sim.pools.has(end_cell):
			if sfx:
				sfx.play("dip")
			if painted in ["orange", "green", "purple"]:
				ui.toast("混出%s色！" % HueArt.color_name(painted), HueArt.paint_color(painted))
	if stamp != "":
		_refresh_target(end_cell, false)
		_spawn_ring(end_cell, HueArt.paint_color(stamp), 1.15, false)
		_spawn_burst(end_cell, HueArt.paint_color(stamp), 22, 3.0)
		if stamp_result == "ok":
			if sfx:
				sfx.play("stamp")
			_spawn_ring(end_cell, HueArt.paint_color("yellow").lightened(0.4), 1.45, false)
		elif stamp_result == "bad":
			if sfx:
				sfx.play("wrong")
			ui.toast("颜色不对，再试一次", HueArt.paint_color(stamp))
	if bool(res.get("won", false)):
		_begin_win()
	else:
		ui.refresh()
	if pending_dir != "":
		var nd := pending_dir
		pending_dir = ""
		try_roll(nd)


func _land_squash() -> void:
	cube_root.scale = Vector3(1.06, 0.92, 1.06)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(cube_root, "scale", Vector3.ONE, 0.16)
	_spawn_burst(sim.pos, HueArt.theme_color(theme, "tile_top", Color("f7efe3")), 6, 1.0)


func _bump(dir: String) -> void:
	if bumping or not roll_anim.is_empty() or cube_root == null:
		return
	bumping = true
	var base := _cell_pos(sim.pos, TILE_TOP + CUBE_HALF)
	var v: Vector2i = HueSim.DIR_VECTORS.get(dir, Vector2i.ZERO)
	var delta := Vector3(v.x, 0, v.y) * 0.075
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(cube_root, "position", base + delta, 0.07)
	tw.tween_property(cube_root, "position", base, 0.12)
	tw.tween_callback(func(): bumping = false)


func request_undo() -> void:
	if overlay == "select" or not roll_anim.is_empty():
		return
	if sim.undo():
		win_pending = false
		win_timer = -1.0
		if overlay == "win":
			overlay = ""
			ui.close_overlays()
		_place_cube(sim.pos)
		_update_cube_faces(true)
		_refresh_all(true)
		ui.refresh()
		if sfx:
			sfx.play("undo")


func request_reset() -> void:
	if overlay == "select" or not roll_anim.is_empty():
		return
	sim.reset()
	win_pending = false
	win_timer = -1.0
	if overlay == "win":
		overlay = ""
		ui.close_overlays()
	_place_cube(sim.pos)
	_update_cube_faces(true)
	_refresh_all(true)
	hint_seen = false
	ui.refresh()
	ui.show_hint(sim.hint)
	if sfx:
		sfx.play("reset")


func request_level_select() -> void:
	if overlay == "select":
		return
	overlay = "select"
	roll_anim = {}
	win_pending = false
	win_timer = -1.0
	hover_ring.visible = false
	ui.open_level_select(levels, progress, level_index)


func _close_level_select() -> void:
	if overlay != "select":
		return
	overlay = ""
	ui.close_overlays()


func request_close_level_select() -> void:
	_close_level_select()


func request_load_level(index: int) -> void:
	if index < 0 or index >= levels.size():
		return
	load_level(index)


func request_next_level() -> void:
	if level_index + 1 < levels.size():
		load_level(level_index + 1)
	else:
		request_level_select()


func request_replay() -> void:
	load_level(level_index)


func request_mute() -> void:
	if sfx:
		var on: bool = sfx.toggle_mute()
		ui.toast("音效已开启" if on else "音效已关闭")


# ------------------------------------------------------------------ target / state refresh


func _refresh_all(instant := true) -> void:
	for cell in target_vis:
		_refresh_target(cell, instant)
	_update_cube_faces(instant)
	_update_cube_ground_shadow(sim.pos)
	cube_shadow.visible = true
	cube_glow.visible = true
	ui.refresh()


func _refresh_target(cell: Vector2i, instant := true) -> void:
	if not target_vis.has(cell):
		return
	var vis: Dictionary = target_vis[cell]
	var locked := sim.is_locked(cell)
	var stamped := str(sim.stamp_color(cell))
	var req := str(sim.target_req[cell])
	var patch: MeshInstance3D = vis.patch
	var decal: MeshInstance3D = vis.decal
	var stamp: MeshInstance3D = vis.stamp
	var token: Node3D = vis.token
	var show_paint := locked or (stamped != "blank")
	patch.visible = show_paint
	if show_paint:
		var pc := HueArt.paint_color(req if locked else stamped)
		var mat: StandardMaterial3D = patch.material_override
		mat.albedo_color = pc
		mat.emission = pc * 0.10
	decal.visible = not locked
	stamp.visible = locked
	token.visible = not locked
	if locked:
		token.scale = Vector3.ONE
	elif instant:
		token.scale = Vector3.ONE
	if show_paint:
		if instant:
			patch.scale = Vector3(0.82, 0.014, 0.82)
		elif locked:
			patch.scale = Vector3(0.6, 0.01, 0.6)
			var tw := create_tween()
			tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			tw.tween_property(patch, "scale", Vector3(0.82, 0.014, 0.82), 0.28)
			var tw2 := create_tween()
			tw2.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tw2.tween_property(token, "scale", Vector3(0.01, 0.01, 0.01), 0.22)


func _update_tokens(delta: float) -> void:
	token_time += delta
	for cell in target_vis:
		var vis: Dictionary = target_vis[cell]
		var token: Node3D = vis.token
		if token.visible:
			var phase: float = vis.phase
			token.position.y = 0.66 + sin(token_time * 1.8 + phase) * 0.045
			var halo: MeshInstance3D = vis.halo
			halo.rotation.y += delta * 0.55
			halo.scale = Vector3(0.55, 0.55, 0.55) * (1.0 + sin(token_time * 2.2 + phase) * 0.035)


func _update_decor(delta: float) -> void:
	for item in decor_floaters:
		var node: Node3D = item.node
		if not is_instance_valid(node):
			continue
		var base_y: float = item.base_y
		var phase: float = item.phase
		var amp: float = item.amp
		node.position.y = base_y + sin(token_time * 0.7 + phase) * amp
		if item.has("spin"):
			node.rotation.y += delta * float(item.spin)


# ------------------------------------------------------------------ fx


func _spawn_ring(cell: Vector2i, color: Color, size := 1.0, splash := false) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = HueArt.ring_mesh(0.74, 1.0, 56)
	var mat := HueArt.ring_material(color, 0.9, 0.22)
	ring.material_override = mat
	ring.position = _cell_pos(cell, TILE_TOP + 0.058)
	ring.scale = Vector3(0.24, 0.24, 0.24) * size
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_root.add_child(ring)
	var tw := create_tween()
	tw.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(ring, "scale", Vector3(1.25, 1.25, 1.25) * size, 0.55)
	tw.parallel().tween_property(mat, "shader_parameter/tint", Color(color.r, color.g, color.b, 0.0), 0.55)
	tw.tween_callback(ring.queue_free)
	if splash:
		var ring2 := MeshInstance3D.new()
		ring2.mesh = HueArt.ring_mesh(0.82, 1.0, 48)
		var mat2 := HueArt.ring_material(color.lightened(0.25), 0.55, 0.35)
		ring2.material_override = mat2
		ring2.position = _cell_pos(cell, TILE_TOP + 0.062)
		ring2.scale = Vector3(0.4, 0.4, 0.4) * size
		ring2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fx_root.add_child(ring2)
		var tw2 := create_tween()
		tw2.tween_interval(0.06)
		tw2.tween_property(ring2, "scale", Vector3(1.05, 1.05, 1.05) * size, 0.42)
		tw2.parallel().tween_property(mat2, "shader_parameter/tint", Color(color.r, color.g, color.b, 0.0), 0.42)
		tw2.tween_callback(ring2.queue_free)


func _spawn_burst(cell: Vector2i, color: Color, amount: int, power: float) -> void:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 0.65
	p.one_shot = true
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 65.0
	p.gravity = Vector3(0, -3.2, 0)
	p.initial_velocity_min = power * 0.55
	p.initial_velocity_max = power
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.10
	p.color = color
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11, 0.11)
	quad.material = _particle_material
	p.mesh = quad
	p.position = _cell_pos(cell, TILE_TOP + 0.12)
	fx_root.add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(1.3)
	tw.tween_callback(p.queue_free)


func _spawn_confetti() -> void:
	var p := CPUParticles3D.new()
	p.amount = 90
	p.lifetime = 2.4
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 85.0
	p.gravity = Vector3(0, -2.4, 0)
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.13
	p.color = Color(1, 1, 1)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	ramp.colors = PackedColorArray([
		HueArt.paint_color("red"), HueArt.paint_color("yellow"), HueArt.paint_color("blue"),
		HueArt.paint_color("green"), HueArt.paint_color("purple"), HueArt.paint_color("orange"),
	])
	p.color_initial_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.16)
	quad.material = _particle_material
	p.mesh = quad
	p.position = board_center + Vector3(0, 1.3, 0)
	fx_root.add_child(p)
	p.emitting = true
	var tw := create_tween()
	tw.tween_interval(3.2)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ win


func _begin_win() -> void:
	if win_pending:
		return
	win_pending = true
	win_timer = 0.55
	var st := sim.stars()
	var entry: Dictionary = progress.get(sim.level_id, {})
	var best := int(entry.get("best", 999999))
	var stars_best := int(entry.get("stars", 0))
	entry["best"] = mini(best, sim.moves)
	entry["stars"] = maxi(stars_best, st)
	entry["name"] = sim.level_name
	progress[sim.level_id] = entry
	_save_progress()
	if sfx:
		sfx.play("win")
	_spawn_confetti()
	_spawn_ring(sim.pos, HueArt.GOLD, 1.7, true)
	ui.refresh()


func _open_win_panel() -> void:
	win_pending = false
	win_timer = -1.0
	overlay = "win"
	ui.show_win(sim.level_name, sim.stars(), sim.moves, sim.par, level_index == levels.size() - 1)


# ------------------------------------------------------------------ process / debug


func _process(delta: float) -> void:
	elapsed += delta
	_update_camera(delta)
	_update_roll(delta)
	_update_tokens(delta)
	_update_decor(delta)
	_update_hover()
	if win_timer >= 0.0:
		win_timer -= delta
		if win_timer <= 0.0 and sim.won and overlay == "":
			_open_win_panel()
	perf_timer -= delta
	if perf_timer <= 0.0:
		perf_timer = 0.25
		var dc := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		ui.set_perf(Engine.get_frames_per_second(), dc)


func _on_viewport_changed() -> void:
	if backdrop_quad == null or sim == null:
		return
	cam_size_target = _fit_for_yaw(yaw_target)
	if cam_rot_t < 0.0:
		camera.size = cam_size_target
		cam_size_current = cam_size_target
		_place_camera(yaw_current)
	_update_backdrop(true)


# ------------------------------------------------------------------ debug / tooling hooks


func debug_state() -> Dictionary:
	var s: Dictionary = sim.stats() if sim != null else {}
	s["level_index"] = level_index
	s["level_count"] = levels.size()
	s["level_id"] = sim.level_id if sim != null else ""
	s["overlay"] = overlay
	s["animating"] = not roll_anim.is_empty()
	s["debug"] = debug_visible
	return s


func debug_load_level(index: int) -> void:
	load_level(index)


func debug_reset() -> void:
	request_reset()


func debug_undo() -> void:
	request_undo()


func debug_apply_moves(moves: String, instant := true) -> void:
	if sim == null:
		return
	for ch in moves:
		var dir := ""
		match ch:
			"n": dir = "north"
			"e": dir = "east"
			"s": dir = "south"
			"w": dir = "west"
		if dir == "":
			continue
		var res := sim.roll(dir)
		if not bool(res.ok):
			break
	roll_anim = {}
	pending_dir = ""
	_place_cube(sim.pos)
	_update_cube_faces(true)
	_refresh_all(true)
	if sim.won and not win_pending:
		win_pending = true
		win_timer = 0.2
	ui.refresh()


func debug_show_win() -> void:
	if sim != null and sim.won:
		_open_win_panel()


func debug_open_select() -> void:
	request_level_select()


func debug_set_debug(on: bool) -> void:
	debug_visible = on
	ui.toggle_debug(on)


func debug_snapshot() -> Dictionary:
	return {
		"state": debug_state(),
		"faces": sim.faces.duplicate() if sim != null else {},
		"walkable": sim.walkable.duplicate() if sim != null else {},
		"pools": sim.pools.duplicate() if sim != null else {},
		"targets": sim.target_req.duplicate() if sim != null else {},
		"props": sim.props.duplicate() if sim != null else {},
		"stamps": sim.stamps.duplicate() if sim != null else {},
		"locked": sim.locked.duplicate() if sim != null else {},
		"progress": progress.duplicate(),
		"fps": Engine.get_frames_per_second(),
		"draw_calls": int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
	}
