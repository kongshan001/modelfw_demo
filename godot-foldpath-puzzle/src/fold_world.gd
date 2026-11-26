class_name FoldWorld
extends Node3D

## Procedural paper diorama: platforms, folded paths, brass seams, hanging
## ribbons and a soft painted backdrop. All meshes are built from primitives.

var level: Dictionary = {}
var angles: Dictionary = {}
var platform_roots: Dictionary = {}
var platform_data: Dictionary = {}
var node_data: Dictionary = {}
var open_nodes: Array[String] = []

var _time := 0.0
var _halos: Array[Dictionary] = []
var _gems: Array[Dictionary] = []
var _ribbons: Array[Dictionary] = []
var _floaters: Array[Dictionary] = []
var _birds: Array[Dictionary] = []
var _flags: Array[Dictionary] = []
var _focus := Vector3.ZERO
var _view_size := 1280.0 / 720.0


func build(new_level: Dictionary, focus: Vector3, ortho_size: float) -> void:
	for child in get_children():
		child.queue_free()
	platform_roots.clear()
	platform_data.clear()
	_halos.clear()
	_gems.clear()
	_ribbons.clear()
	_floaters.clear()
	_birds.clear()
	_flags.clear()
	level = new_level
	angles = FoldLevel.initial_angles(level)
	node_data = FoldLevel.node_map(level)
	platform_data = FoldLevel.platform_map(level)
	_focus = focus
	_view_size = ortho_size
	open_nodes.clear()
	for cand in FoldLevel.link_candidates(level):
		open_nodes.append(String(cand["id"]))
	_build_environment()
	for p in level["platforms"]:
		_build_platform(p)
	_build_paths()
	_build_soft_shadows()
	_batch_platforms()
	_build_markers()
	_build_backdrop()
	apply_angles(angles)


func apply_angles(new_angles: Dictionary) -> void:
	angles = new_angles.duplicate()
	for pid in platform_roots.keys():
		var root: Node3D = platform_roots[pid]
		root.rotation.y = deg_to_rad(float(angles.get(pid, 0.0)))


func set_angle(pid: String, deg: float) -> void:
	angles[pid] = deg
	if platform_roots.has(pid):
		var root: Node3D = platform_roots[pid]
		root.rotation.y = deg_to_rad(deg)


func platform_angle(pid: String) -> float:
	return float(angles.get(pid, 0.0))


func tick(delta: float) -> void:
	_time += delta
	for g in _gems:
		var node: Node3D = g["node"]
		var base_y: float = g["base_y"]
		var phase: float = g["phase"]
		node.position.y = base_y + sin(_time * 1.5 + phase) * 0.05
		node.rotation.y += delta * 0.8
	for r in _ribbons:
		var node: Node3D = r["node"]
		var phase: float = r["phase"]
		var base: Vector3 = r["base_rot"]
		node.rotation.x = base.x + sin(_time * 1.35 + phase) * 0.09
		node.rotation.z = base.z + sin(_time * 1.05 + phase * 1.3) * 0.07
	for f in _floaters:
		var node: Node3D = f["node"]
		var base: Vector3 = f["pos"]
		var phase: float = f["phase"]
		node.position = base + Vector3(0, sin(_time * 0.7 + phase) * 0.05, 0)
		node.rotation.y += delta * float(f.get("spin", 0.05))
	for b in _birds:
		var node: Node3D = b["node"]
		var phase: float = b["phase"]
		var radius: float = b["radius"]
		var height: float = b["height"]
		var speed: float = b["speed"]
		var a := _time * speed + phase
		node.position = _focus + Vector3(cos(a) * radius, height + sin(a * 2.1) * 0.15, sin(a) * radius)
		node.rotation.y = -a + PI * 0.5
		node.rotation.z = sin(a * 2.0) * 0.12
	for f in _flags:
		var node: Node3D = f["node"]
		var phase: float = f["phase"]
		node.rotation.y = sin(_time * 1.9 + phase) * 0.25


func _material(key: String, metallic := 0.0, roughness := 0.94) -> StandardMaterial3D:
	return FoldPalette.mat(key, metallic, roughness)


func _part(parent: Node3D, mesh: Mesh, color_key: String, pos: Vector3, rot := Vector3.ZERO, shadow := true, material: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material if material != null else _material(color_key)
	mi.position = pos
	mi.rotation = rot
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, size: Vector3, pos: Vector3, color_key: String, rot := Vector3.ZERO, shadow := false, material: Material = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, color_key, pos, rot, shadow, material)


func _cylinder(parent: Node3D, radius: float, height: float, pos: Vector3, color_key: String, sides := 12, rot := Vector3.ZERO, shadow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _part(parent, mesh, color_key, pos, rot, shadow)


func _ring(parent: Node3D, inner: float, outer: float, pos: Vector3, color_key: String, rot := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 28
	mesh.ring_segments = 6
	var mat: Material = FoldPalette.glow(color_key, 1.1) if glow else _material(color_key, 0.28, 0.55)
	return _part(parent, mesh, color_key, pos, rot, false, mat)


func _cone(parent: Node3D, radius: float, height: float, pos: Vector3, color_key: String, rot := Vector3.ZERO, sides := 4, glow := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var mat: Material = FoldPalette.glow(color_key, 1.2) if glow else null
	return _part(parent, mesh, color_key, pos, rot, false, mat)


func _build_environment() -> void:
	var palette: Dictionary = level.get("palette", {})
	var sky := Color(String(palette.get("sky", "#CBD9CD")))
	var fog := Color(String(palette.get("fog", "#C6D3C7")))
	var sun_color := Color(String(palette.get("sun", "#FFE0AE")))
	var env := Environment.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky_gradient.gdshader")
	sky_mat.set_shader_parameter("top_color", sky.darkened(0.08))
	sky_mat.set_shader_parameter("horizon_color", Color(String(palette.get("horizon", "#E8DCC3"))))
	sky_mat.set_shader_parameter("bottom_color", sky.darkened(0.34))
	sky_mat.set_shader_parameter("top_power", 0.55)
	sky_mat.set_shader_parameter("bottom_power", 0.6)
	var sky_res := Sky.new()
	sky_res.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky_res
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = fog.lightened(0.35)
	env.ambient_light_energy = 0.34
	env.fog_enabled = true
	env.fog_light_color = fog
	env.fog_light_energy = 0.55
	env.fog_density = 0.0032
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.03
	env.tonemap_white = 1.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_color = sun_color
	sun.light_energy = 2.5
	sun.shadow_enabled = false
	sun.shadow_blur = 0.55
	sun.shadow_opacity = 0.9
	sun.shadow_bias = 0.025
	sun.shadow_normal_bias = 1.4
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 30.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(42, 138, 0)
	fill.light_color = Color("#C9DED6")
	fill.light_energy = 0.26
	fill.shadow_enabled = false
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)


func _build_platform(p: Dictionary) -> void:
	var pid := String(p["id"])
	var pivot := FoldMath.vec3(p["pivot"])
	var root := Node3D.new()
	root.name = "Platform_" + pid
	root.position = pivot
	add_child(root)
	platform_roots[pid] = root

	var size := FoldMath.vec3(p["size"])
	var shape := String(p.get("shape", "deck"))
	var color := String(p.get("color", "stone"))
	var trim := String(p.get("trim", "brass"))
	match shape:
		"bridge":
			_build_bridge(root, size, color, trim, p)
		"disc":
			_build_disc(root, size, color, trim, p)
		"ledge":
			_build_deck(root, size, color, trim, p, true)
		_:
			_build_deck(root, size, color, trim, p, false)

	for addon in p.get("addons", []):
		var apos := FoldMath.vec3(addon.get("pos", []))
		var asize := FoldMath.vec3(addon.get("size", [0.4, 0.4, 0.4]))
		var acolor := String(addon.get("color", "stone_2"))
		_box(root, asize, apos, acolor, Vector3.ZERO, true)
		if apos.y + asize.y * 0.5 > 0.08:
			_soft_shadow(root, Vector3(apos.x, 0.012, apos.z), Vector2(asize.x + 0.34, asize.z + 0.34), 0.0, 0.30)
		if asize.y >= 0.4:
			var top_y := apos.y + asize.y * 0.5 + 0.006
			_box(root, Vector3(asize.x * 0.55, 0.012, 0.025), Vector3(apos.x, top_y, apos.z - asize.z * 0.5 + 0.018), trim)
		if asize.y >= 0.7:
			_box(root, Vector3(0.04, asize.y * 0.55, 0.04), Vector3(apos.x - asize.x * 0.5, apos.y + asize.y * 0.1, apos.z), "brass_dark")

	for post in p.get("posts", []):
		var pos := FoldMath.vec3(post.get("pos", []))
		var h := float(post.get("height", 2.0))
		var radius := float(post.get("radius", 0.07))
		var pcolor := String(post.get("color", "teal"))
		_cylinder(root, radius, h, pos + Vector3(0, h * 0.5, 0), pcolor, 8, Vector3.ZERO, true)
		_soft_shadow(root, Vector3(pos.x, 0.012, pos.z), Vector2(radius * 5.0, radius * 5.0), 0.0, 0.30)
		_cylinder(root, radius * 1.9, 0.05, pos + Vector3(0, h, 0), "brass", 8)
		_cone(root, radius * 2.2, 0.18, pos + Vector3(0, h + 0.1, 0), pcolor, Vector3.ZERO, 8)

	for rib in p.get("ribbons", []):
		var pos := FoldMath.vec3(rib.get("pos", []))
		var length := float(rib.get("len", 0.8))
		var width := float(rib.get("width", 0.18))
		var rcolor := String(rib.get("color", "coral"))
		var rroot := Node3D.new()
		rroot.position = pos
		rroot.set_meta("fold_dynamic", true)
		root.add_child(rroot)
		var seg1 := length * 0.58
		var seg2 := length * 0.42
		_box(rroot, Vector3(width, seg1, 0.012), Vector3(0, -seg1 * 0.5, 0), rcolor, Vector3(0, 0, 0), false)
		_box(rroot, Vector3(width * 0.82, seg2, 0.012), Vector3(width * 0.06, -seg1 - seg2 * 0.5, 0.012), "mustard", Vector3(0.06, 0.12, 0), false)
		_ribbons.append({"node": rroot, "phase": _time + float(_ribbons.size()) * 1.7, "base_rot": Vector3.ZERO})


func _build_deck(root: Node3D, size: Vector3, color: String, trim: String, p: Dictionary, ledge: bool) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_box(root, Vector3(w, h, d), Vector3(0, -h * 0.5, 0), color, Vector3.ZERO, true)
	_box(root, Vector3(w * 0.92, h * 1.15, d * 0.92), Vector3(0, -h * 1.0, 0), "stone_dark")
	# Perimeter brass crease.
	_box(root, Vector3(w, 0.014, 0.028), Vector3(0, 0.006, -d * 0.5 + 0.016), trim, Vector3.ZERO, false)
	_box(root, Vector3(w, 0.014, 0.028), Vector3(0, 0.006, d * 0.5 - 0.016), trim, Vector3.ZERO, false)
	_box(root, Vector3(0.028, 0.014, d), Vector3(-w * 0.5 + 0.016, 0.006, 0), trim, Vector3.ZERO, false)
	_box(root, Vector3(0.028, 0.014, d), Vector3(w * 0.5 - 0.016, 0.006, 0), trim, Vector3.ZERO, false)
	# A hanging paper fold and a support mast make the slab feel suspended.
	_box(root, Vector3(w * 0.16, h * 2.4, 0.018), Vector3(-w * 0.28, -h * 1.55, d * 0.1), "coral", Vector3(0, 0.0, 0.04), false)
	_cylinder(root, 0.075, 1.25, Vector3(0, -h - 0.62, 0), "teal", 6, Vector3.ZERO, true)
	if ledge:
		_box(root, Vector3(0.06, 1.4, d * 0.7), Vector3(0, -h - 0.58, 0), "teal", Vector3.ZERO, true)
		_box(root, Vector3(0.34, 0.34, 0.34), Vector3(0.2, -h - 1.0, 0.35), "coral")
		_ring(root, 0.16, 0.19, Vector3(0, 0.01, d * 0.28), trim, Vector3.ZERO, false)


func _build_bridge(root: Node3D, size: Vector3, color: String, trim: String, _p: Dictionary) -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	_box(root, Vector3(w, h, d), Vector3(0, -h * 0.5, 0), color, Vector3.ZERO, true)
	_box(root, Vector3(w * 0.9, h * 1.2, d * 0.88), Vector3(0, -h * 1.05, 0), "stone_dark")
	var cap := CylinderMesh.new()
	cap.top_radius = d * 0.5
	cap.bottom_radius = d * 0.5
	cap.height = h
	cap.radial_segments = 12
	for sx in [-1.0, 1.0]:
		_part(root, cap, "stone_2", Vector3(w * 0.5 * sx, -h * 0.5, 0), Vector3.ZERO, true)
		_box(root, Vector3(0.04, h + 0.02, d), Vector3(w * 0.5 * sx - 0.02 * sx, -h * 0.5, 0), trim, Vector3.ZERO, false)
	_box(root, Vector3(w, 0.02, 0.035), Vector3(0, 0.006, -d * 0.5 + 0.02), trim, Vector3.ZERO, false)
	_box(root, Vector3(w, 0.02, 0.035), Vector3(0, 0.006, d * 0.5 - 0.02), trim, Vector3.ZERO, false)
	_ring(root, 0.2, 0.26, Vector3(0, 0.008, 0), trim, Vector3.ZERO, false)
	_ring(root, 0.07, 0.09, Vector3(0, 0.012, 0), "teal", Vector3.ZERO, false)
	_cylinder(root,0.09,1.1,Vector3(0,-h-0.5,0),"teal",8,Vector3.ZERO,true)
	_box(root, Vector3(0.45, 0.18, 0.45), Vector3(0, -h - 1.0, 0), "coral", Vector3.ZERO, true)
	_box(root, Vector3(w * 0.36, 0.02, 0.03), Vector3(0, 0.012, 0.1), "mustard", Vector3.ZERO, false)


func _build_disc(root: Node3D, size: Vector3, color: String, trim: String, _p: Dictionary) -> void:
	var radius := size.x * 0.5
	var h := size.y
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = h
	disc.radial_segments = 24
	disc.rings = 1
	_part(root, disc, color, Vector3(0, -h * 0.5, 0), Vector3.ZERO, true)
	var under := CylinderMesh.new()
	under.top_radius = radius * 0.95
	under.bottom_radius = radius * 0.8
	under.height = h * 1.3
	under.radial_segments = 24
	under.rings = 1
	_part(root, under, "stone_dark", Vector3(0, -h * 1.05, 0))
	_ring(root, radius - 0.075, radius + 0.015, Vector3(0, 0.008, 0), trim, Vector3.ZERO, false)
	_ring(root, radius * 0.43, radius * 0.47, Vector3(0, 0.012, 0), "brass_dark", Vector3.ZERO, false)
	for i in 3:
		var a := TAU * float(i) / 3.0 + 0.35
		var rr := radius * 0.82
		var p := Vector3(cos(a) * rr, 0.03, sin(a) * rr)
		_cylinder(root, 0.055, 0.08, p + Vector3(0, 0.04, 0), "teal", 6)
		_box(root, Vector3(0.11, 0.016, 0.06), p + Vector3(0, 0.085, 0), trim, Vector3(0, -a, 0), false)
	_cylinder(root,0.09,1.15,Vector3(0,-h-0.55,0),"teal",8,Vector3.ZERO,true)
	_cylinder(root,0.28,0.08,Vector3(0,-h-0.8,0),"coral",12,Vector3.ZERO,true)
	_box(root, Vector3(radius * 0.3, h * 2.0, 0.018), Vector3(radius * 0.72, -h * 1.3, 0), "coral", Vector3(0, 0.3, 0.08), false)


func _build_paths() -> void:
	for e in level["edges"]:
		var a := String(e[0])
		var b := String(e[1])
		var na: Dictionary = node_data[a]
		var nb: Dictionary = node_data[b]
		var pid := String(na["platform"])
		var root: Node3D = platform_roots[pid]
		var pa := FoldMath.vec3(na["pos"])
		var pb := FoldMath.vec3(nb["pos"])
		_path_segment(root, pa, pb)

	for n in level["nodes"]:
		var nid := String(n["id"])
		var pid := String(n["platform"])
		var root: Node3D = platform_roots[pid]
		var local := FoldMath.vec3(n["pos"])
		_build_pad(root, nid, local, String(n.get("kind", "path")))

	for pid in platform_roots.keys():
		var root: Node3D = platform_roots[pid]
		var pdata: Dictionary = platform_data[pid]
		if not bool(pdata.get("rotatable", false)):
			continue
		# A small brass mark on the rim makes the rotating part readable in debug.
		_cylinder(root, 0.02, 0.22, Vector3(0.0, 0.11, -FoldMath.vec3(pdata["size"]).z * 0.5 + 0.12), "brass", 4)


func _path_segment(root: Node3D, pa: Vector3, pb: Vector3) -> void:
	var dir := pb - pa
	var length := dir.length()
	if length < 0.02:
		return
	var x_axis := dir.normalized()
	var z_axis := x_axis.cross(Vector3.UP)
	if z_axis.length() < 0.001:
		z_axis = Vector3.FORWARD
	z_axis = z_axis.normalized()
	var y_axis := z_axis.cross(x_axis).normalized()
	var basis := Basis(x_axis, y_axis, z_axis)
	var mid := (pa + pb) * 0.5
	var base := BoxMesh.new()
	base.size = Vector3(length, 0.045, 0.30)
	var bm := MeshInstance3D.new()
	bm.mesh = base
	bm.material_override = _material("teal")
	bm.transform = Transform3D(basis, mid + Vector3(0, 0.010, 0))
	bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bm)
	var ribbon := BoxMesh.new()
	ribbon.size = Vector3(length, 0.022, 0.25)
	var mi := MeshInstance3D.new()
	mi.mesh = ribbon
	mi.material_override = _material("cream")
	mi.transform = Transform3D(basis, mid + Vector3(0, 0.026, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


func _build_pad(root: Node3D, nid: String, local: Vector3, kind: String) -> void:
	var pad := CylinderMesh.new()
	pad.top_radius = 0.205
	pad.bottom_radius = 0.22
	pad.height = 0.032
	pad.radial_segments = 8
	pad.rings = 1
	var base_color := "teal"
	if kind == "start":
		base_color = "cream"
	elif kind == "goal":
		base_color = "paper"
	_part(root, pad, base_color, local + Vector3(0, 0.016, 0))
	var inlay := BoxMesh.new()
	inlay.size = Vector3(0.105, 0.012, 0.105)
	var inlay_color := "paper"
	if kind == "start":
		inlay_color = "teal"
	elif kind == "goal":
		inlay_color = "amber"
	_part(root, inlay, inlay_color, local + Vector3(0, 0.036, 0), Vector3(0, PI * 0.25, 0))
	if local.y > 0.05:
		_cylinder(root, 0.055, local.y, Vector3(0, 0, 0) + Vector3(local.x, local.y * 0.5, local.z), "brass_dark", 6)

	if kind == "start":
		_ring(root, 0.19, 0.235, local + Vector3(0, 0.06, 0), "teal", Vector3.ZERO, false)
		var pole := Node3D.new()
		pole.position = local + Vector3(0.3, 0.02, 0.05)
		pole.set_meta("fold_dynamic", true)
		root.add_child(pole)
		_cylinder(pole, 0.012, 0.8, Vector3(0, 0.4, 0), "brass", 4)
		var flag := _box(pole, Vector3(0.26, 0.13, 0.012), Vector3(0.15, 0.7, 0), "coral", Vector3(0, 0, 0), false)
		flags_append(pole, flag)
	elif kind == "goal":
		_ring(root, 0.235, 0.3, local + Vector3(0, 0.062, 0), "amber", Vector3.ZERO, true)
		var gem := Node3D.new()
		gem.position = local + Vector3(0, 0.52, 0)
		gem.set_meta("fold_dynamic", true)
		root.add_child(gem)
		var top := CylinderMesh.new()
		top.bottom_radius = 0.13
		top.top_radius = 0.0
		top.height = 0.24
		top.radial_segments = 4
		top.rings = 1
		_part(gem, top, "amber", Vector3(0, 0.12, 0), Vector3.ZERO, false, FoldPalette.glow("amber", 1.15))
		var bottom := CylinderMesh.new()
		bottom.bottom_radius = 0.0
		bottom.top_radius = 0.13
		bottom.height = 0.24
		bottom.radial_segments = 4
		bottom.rings = 1
		_part(gem, bottom, "mustard", Vector3(0, -0.12, 0), Vector3.ZERO, false, FoldPalette.glow("mustard", 0.8))
		_gems.append({"node": gem, "base_y": gem.position.y, "phase": float(_gems.size()) * 2.1})
		var beam_mat := FoldPalette.translucent("amber", 0.07)
		var beam := CylinderMesh.new()
		beam.top_radius = 0.09
		beam.bottom_radius = 0.18
		beam.height = 1.1
		beam.radial_segments = 10
		_part(root, beam, "amber", local + Vector3(0, 0.55, 0), Vector3.ZERO, false, beam_mat)

	if nid in open_nodes:
		var halo := Node3D.new()
		halo.position = local + Vector3(0, 0.36, 0)
		root.add_child(halo)
		_ring(halo, 0.13, 0.165, Vector3.ZERO, "mint", Vector3.ZERO, true)


func flags_append(pole: Node3D, _flag: MeshInstance3D) -> void:
	_flags.append({"node": pole, "phase": float(_flags.size()) * 1.3})


## Static paper geometry inside each platform is merged per material so the
## whole diorama stays cheap on integrated GPUs. Animated children are marked
## "fold_dynamic" and stay as individual nodes.
func _batch_platforms() -> void:
	for pid in platform_roots.keys():
		var root: Node3D = platform_roots[pid]
		var groups := {}
		var victims: Array[Node] = []
		_collect_batchable(root, root, groups, victims)
		if victims.is_empty():
			continue
		for victim in victims:
			victim.queue_free()
		for key in groups.keys():
			var group: Dictionary = groups[key]
			var st: SurfaceTool = group["st"]
			var baked := st.commit()
			if baked == null:
				continue
			var mi := MeshInstance3D.new()
			mi.name = "BatchedPaper"
			mi.mesh = baked
			mi.material_override = group["mat"]
			mi.cast_shadow = group["shadow"]
			root.add_child(mi)


func _collect_batchable(node: Node, root: Node3D, groups: Dictionary, victims: Array[Node]) -> void:
	for child in node.get_children():
		if child.has_meta("fold_dynamic"):
			continue
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh == null or mi.material_override == null:
				continue
			var mat: Material = mi.material_override
			var shadow := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var key := str(mat.get_instance_id()) + "|" + ("cast" if shadow else "off")
			if not groups.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"st": st, "mat": mat, "shadow": shadow}
			var group: Dictionary = groups[key]
			var rel := root.global_transform.affine_inverse() * mi.global_transform
			(group["st"] as SurfaceTool).append_from(mi.mesh, 0, rel)
			victims.append(mi)
		else:
			_collect_batchable(child, root, groups, victims)


func _soft_shadow(parent: Node3D, pos: Vector3, size: Vector2, rot_deg: float, alpha: float) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = FoldPalette.soft_shadow(alpha)
	mi.position = pos
	mi.rotation.y = deg_to_rad(rot_deg)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_soft_shadows() -> void:
	for s in level.get("soft_shadows", []):
		var pos := FoldMath.vec3(s.get("pos", []))
		var size := FoldMath.vec3(s.get("size", [1, 1, 1]))
		_soft_shadow(self, pos, Vector2(size.x, size.z), float(s.get("rot", 0.0)), float(s.get("alpha", 0.2)))


func _build_markers() -> void:
	# No floating labels in-world: the HUD handles naming and hints.
	pass


func _screen_point(offset: Vector2, back: float) -> Vector3:
	var b := FoldMath.basis()
	var ppw := 720.0 / _view_size
	return _focus + b.x * (offset.x / ppw) + b.y * (-offset.y / ppw) - FoldMath.BACK * back


func _build_backdrop() -> void:
	var unshaded_sun := StandardMaterial3D.new()
	unshaded_sun.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	unshaded_sun.albedo_color = Color(String(level.get("palette", {}).get("horizon", "#E7DFC9")))
	unshaded_sun.disable_fog = true

	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 1.05
	sun_mesh.height = 2.1
	sun_mesh.radial_segments = 32
	sun_mesh.rings = 16
	var sun := MeshInstance3D.new()
	sun.mesh = sun_mesh
	sun.material_override = unshaded_sun
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.position = _screen_point(Vector2(-432, -176), 24.0)
	add_child(sun)
	var halo_mesh := SphereMesh.new()
	halo_mesh.radius = 1.42
	halo_mesh.height = 2.84
	halo_mesh.radial_segments = 24
	halo_mesh.rings = 12
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.material_override = FoldPalette.translucent("amber", 0.14)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = sun.position + FoldMath.BACK * 0.2
	add_child(halo)

	# A large, quiet paper ring and small floating layers frame the stage.
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.93
	ring_mesh.outer_radius = 0.995
	ring_mesh.rings = 36
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.material_override = _material("stone_2")
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position = _screen_point(Vector2(430, -178), 20.0)
	ring.rotation = Vector3(deg_to_rad(58), deg_to_rad(18), deg_to_rad(-22))
	add_child(ring)
	_floaters.append({"node": ring, "pos": ring.position, "phase": 0.7, "spin": 0.015})

	var sheet_defs := [
		[Vector2(-472, 126), 18.0, Vector3(1.5, 0.1, 0.9), "stone_2", 0.2],
		[Vector2(-350, 246), 22.0, Vector3(0.8, 0.08, 1.4), "coral", 0.7],
		[Vector2(462, 212), 17.0, Vector3(1.2, 0.08, 0.7), "teal", 1.3],
		[Vector2(330, -252), 24.0, Vector3(0.9, 0.07, 0.55), "mustard", 2.1],
		[Vector2(516, -30), 15.0, Vector3(0.55, 0.08, 1.0), "stone", 2.7],
		[Vector2(-520, -10), 26.0, Vector3(0.7, 0.08, 0.7), "plum", 3.4]
	]
	for item in sheet_defs:
		var pos := _screen_point(item[0], float(item[1]))
		var size: Vector3 = item[2]
		var mesh := BoxMesh.new()
		mesh.size = size
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material(String(item[3]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos
		mi.rotation = Vector3(0.12, float(item[4]), 0.1)
		add_child(mi)
		_floaters.append({"node": mi, "pos": pos, "phase": float(item[4]) * 2.0, "spin": 0.04})

	# Folded paper birds, always made from two triangular wings.
	for i in 3:
		var bird := Node3D.new()
		bird.name = "PaperBird%d" % i
		var mat := _material("cream")
		var wing := BoxMesh.new()
		wing.size = Vector3(0.34, 0.015, 0.13)
		for side in [-1.0, 1.0]:
			var mi := MeshInstance3D.new()
			mi.mesh = wing
			mi.material_override = mat
			mi.position = Vector3(0.17 * side, 0, 0)
			mi.rotation = Vector3(0, 0, 0.28 * -side)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bird.add_child(mi)
		var tip := _box(bird, Vector3(0.08, 0.04, 0.16), Vector3(0, 0, 0.12), "coral", Vector3.ZERO, false)
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bird)
		_birds.append({
			"node": bird, "phase": float(i) * 2.3 + 0.4,
			"radius": 2.8 + float(i) * 0.55, "height": 2.6 + float(i) * 0.35,
			"speed": 0.10 + float(i) * 0.02
		})
	# Place bird orbits around the stage rather than through it.
	for b in _birds:
		var node: Node3D = b["node"]
		node.position = _focus + Vector3(0, float(b["height"]), 0)
