class_name MapView
extends Node3D
## 3D map presentation: terrain, path, props, spawn gate, beacon and ambience.
## Replaceable art interface: scenes/map_view.tscn + scripts/map_view.gd + materials/.
## Gameplay data (MapInfo) is injected; this script only builds visuals.

const GData = preload("res://scripts/game_data.gd")
const EMath = preload("res://scripts/ember_math.gd")
const MK = preload("res://scripts/mesh_kit.gd")
const Mat = preload("res://scripts/material_lib.gd")

const SCALE := 0.125
const HALF_W := 232.0
const HALF_H := 168.0
const FIELD_W_WORLD := 58.0
const FIELD_H_WORLD := 42.0

var map
var def: Dictionary
var art: Dictionary
var _time := 0.0
var _portal_ring: MeshInstance3D
var _portal_light: OmniLight3D
var _portal_flames: Array[Node3D] = []
var _portal_veil: MeshInstance3D
var _beacon_core: MeshInstance3D
var _beacon_light: OmniLight3D
var _beacon_orbs: Array[Node3D] = []
var _glows: Array[Node3D] = []


func setup(map_info) -> void:
	map = map_info
	def = map.def
	art = def["art"]
	_time = 0.0
	for child in get_children():
		child.queue_free()
	_build_ground()
	_build_path()
	_build_scatter()
	_build_props()
	_build_portal()
	_build_beacon()
	_build_border()
	_build_ambient()


func to_world(p: Vector2, y: float = 0.0) -> Vector3:
	return Vector3((p.x - HALF_W) * SCALE, y, (p.y - HALF_H) * SCALE)


func to_world_cell(cx: int, cy: int, y: float = 0.0) -> Vector3:
	return to_world(map.cell_center(cx, cy), y)


func px_at_world(world_pos: Vector3) -> Vector2:
	return Vector2(world_pos.x / SCALE + HALF_W, world_pos.z / SCALE + HALF_H)


func path_angle_at(distance: float) -> float:
	var p: Dictionary = map.point_at(distance)
	var seg: Dictionary = p["seg"]
	var a: Vector2 = seg["a"]
	var b: Vector2 = seg["b"]
	return atan2(b.y - a.y, b.x - a.x)


func col(key: String) -> Color:
	return Color(art[key])


func _build_ground() -> void:
	var st := MK.new_st()
	var map_seed := int(def["seed"])
	var cols := 68
	var rows := 52
	var heights := PackedFloat32Array()
	heights.resize((cols + 1) * (rows + 1))
	for iz in rows + 1:
		for ix in cols + 1:
			var wx := -FIELD_W_WORLD * 0.5 - 5.0 + ix
			var wz := -FIELD_H_WORLD * 0.5 - 5.0 + iz
			var px := Vector2(wx / SCALE + HALF_W, wz / SCALE + HALF_H)
			var h := 0.0
			if map.distance_to_path(px.x, px.y) >= 20.0:
				h = (EMath.hash2(ix, iz, map_seed) - 0.5) * 0.16
			heights[iz * (cols + 1) + ix] = h
	var palette: Array[Color] = []
	for hex in art["ground"]:
		palette.append(Color(hex))
	var dark: Color = Color(art["ground_dark"])
	for iz in rows:
		for ix in cols:
			var h00: float = heights[iz * (cols + 1) + ix]
			var h10: float = heights[iz * (cols + 1) + ix + 1]
			var h01: float = heights[(iz + 1) * (cols + 1) + ix]
			var h11: float = heights[(iz + 1) * (cols + 1) + ix + 1]
			var x0 := -FIELD_W_WORLD * 0.5 - 5.0 + ix
			var z0 := -FIELD_H_WORLD * 0.5 - 5.0 + iz
			var a := Vector3(x0, h00, z0)
			var b := Vector3(x0 + 1.0, h10, z0)
			var c := Vector3(x0 + 1.0, h11, z0 + 1.0)
			var d := Vector3(x0, h01, z0 + 1.0)
			var center_px := Vector2(((x0 + 0.5) / SCALE) + HALF_W, ((z0 + 0.5) / SCALE) + HALF_H)
			var dist_path: float = map.distance_to_path(center_px.x, center_px.y)
			var noise := _ground_noise(ix, iz, map_seed)
			var color: Color = palette[clampi(int(noise * 4.0), 0, 3)]
			if dist_path < 30.0:
				color = color.lerp(dark, clampf((30.0 - dist_path) / 30.0, 0.0, 0.6))
			color = color.darkened(EMath.hash2(ix, iz, map_seed + 5) * 0.07)
			if EMath.hash2(ix + 3, iz + 9, map_seed + 2) < 0.045:
				color = color.lightened(0.10)
			if absf(x0) > FIELD_W_WORLD * 0.5 or absf(z0) > FIELD_H_WORLD * 0.5:
				color = color.lerp(dark, 0.45).darkened(0.25)
			var n := (c - a).cross(b - a)
			if n.y < 0.0:
				n = -n
			MK.add_quad(st, a, b, c, d, color, n.normalized())
	# dark outer skirt so tilted camera never sees the void
	var skirt_a := Vector3(-70.0, -0.4, -55.0)
	var skirt_b := Vector3(70.0, -0.4, -55.0)
	var skirt_c := Vector3(70.0, -0.4, 55.0)
	var skirt_d := Vector3(-70.0, -0.4, 55.0)
	MK.add_quad(st, skirt_a, skirt_b, skirt_c, skirt_d, dark.darkened(0.5), Vector3.UP)
	var mi := MK.make_material_instance(MK.finish(st), Mat.get_mat("ground_ashen" if map.id == "ashen" else "ground_frost"))
	mi.name = "Ground"
	add_child(mi)


func _ground_noise(ix: int, iz: int, map_seed: int) -> float:
	var gx := float(ix) * 0.33
	var gz := float(iz) * 0.33
	var x0 := int(floor(gx))
	var z0 := int(floor(gz))
	var fx := gx - float(x0)
	var fz := gz - float(z0)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := EMath.hash2(x0, z0, map_seed)
	var b := EMath.hash2(x0 + 1, z0, map_seed)
	var c := EMath.hash2(x0, z0 + 1, map_seed)
	var d := EMath.hash2(x0 + 1, z0 + 1, map_seed)
	var coarse := lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)
	var detail := EMath.hash2(ix, iz, map_seed + 31)
	return clampf(coarse * 0.82 + detail * 0.18, 0.0, 0.999)


func _build_path() -> void:
	var st := MK.new_st()
	var layers := [
		{"w": 27.0, "y": 0.020, "color": col("path_edge")},
		{"w": 20.0, "y": 0.030, "color": col("path_base")},
		{"w": 14.0, "y": 0.040, "color": col("path_mid")},
	]
	for layer in layers:
		var width: float = layer["w"] * SCALE
		var y: float = layer["y"]
		var color: Color = layer["color"]
		for seg in map.segments:
			var a: Vector3 = to_world(seg["a"], y)
			var b: Vector3 = to_world(seg["b"], y)
			var dir := (b - a).normalized()
			var side := Vector3(-dir.z, 0.0, dir.x) * width * 0.5
			MK.add_quad(st, a - side, b - side, b + side, a + side, color, Vector3.UP)
		for i in range(1, map.points.size() - 1):
			var p: Vector3 = to_world(map.points[i], y)
			MK.add_disc(st, p, width * 0.5, 12, color)
	# worn lighter slabs
	var d := 24.0
	while d < map.total_len - 24.0:
		var p: Dictionary = map.point_at(d)
		var seg: Dictionary = p["seg"]
		var pa: Vector2 = seg["a"]
		var pb: Vector2 = seg["b"]
		var ang := atan2(pb.y - pa.y, pb.x - pa.x)
		var center: Vector3 = to_world(p["pos"], 0.052)
		var dir2 := Vector2.from_angle(ang)
		var sideways := Vector2(-dir2.y, dir2.x) * (2.0 + EMath.hash2(int(d), 3, 7) * 2.0)
		sideways *= 6.0
		center += Vector3(sideways.x, 0, sideways.y) * SCALE
		var plen := 4.0 + EMath.hash2(int(d), 9, 3) * 7.0
		var w := 1.2 + EMath.hash2(int(d), 12, 4) * 1.6
		var rot := Basis(Vector3.UP, -ang)
		var c := col("path_lit").darkened(EMath.hash2(int(d), 1, 2) * 0.2)
		var off := rot * Vector3(0, 0, plen * SCALE * 0.5)
		var sidev := rot * Vector3(w * SCALE * 0.5, 0, 0)
		MK.add_quad(st, center - off - sidev, center + off - sidev, center + off + sidev, center - off + sidev,
			c, Vector3.UP)
		d += 13.0
	# path-side rubble
	for seg in map.segments:
		var seg_len: float = seg["len"]
		var n := int(seg_len / 11.0)
		var a2: Vector2 = seg["a"]
		var b2: Vector2 = seg["b"]
		var dir := (b2 - a2).normalized()
		var side := Vector2(-dir.y, dir.x)
		for i in n:
			var t := float(i) / float(max(1, n))
			var p := a2.lerp(b2, t) + side * (12.5 + EMath.hash2(i, int(seg_len), 8) * 3.0)
			for s in [-1.0, 1.0]:
				var q: Vector2 = a2.lerp(b2, t) + side * (12.5 + EMath.hash2(i, int(seg_len), 8) * 3.0) * float(s)
				var size := 0.10 + EMath.hash2(i, int(seg_len), int(s) + 3) * 0.12
				var wp: Vector3 = to_world(q, 0.055)
				MK.add_box(st, wp, Vector3(size, size * 0.6, size), col("path_edge").lightened(0.06))
			if i % 2 == 0:
				var wp2: Vector3 = to_world(p, 0.058)
				MK.add_box(st, wp2, Vector3(0.12, 0.05, 0.12), col("path_lit").darkened(0.2))
	var mi := MK.make_material_instance(MK.finish(st), Mat.get_mat("path_ashen" if map.id == "ashen" else "path_frost"))
	mi.name = "Path"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

	# direction chevrons (unshaded, one draw call via MultiMesh)
	var chev := MK.new_st()
	MK.add_chevron(chev, Vector3.ZERO, 0.75, Color.WHITE)
	var chev_mesh := MK.finish(chev)
	var mult := MultiMesh.new()
	mult.transform_format = MultiMesh.TRANSFORM_3D
	mult.mesh = chev_mesh
	var chev_positions: Array[Transform3D] = []
	var dist := 48.0
	while dist < map.total_len - 30.0:
		var p: Dictionary = map.point_at(dist)
		var seg: Dictionary = p["seg"]
		var a: Vector2 = seg["a"]
		var b: Vector2 = seg["b"]
		var ang := atan2(b.y - a.y, b.x - a.x)
		var pos: Vector3 = to_world(p["pos"], 0.062)
		chev_positions.append(Transform3D(Basis(Vector3.UP, PI * 0.5 - ang), pos))
		dist += 78.0
	mult.instance_count = chev_positions.size()
	for i in chev_positions.size():
		mult.set_instance_transform(i, chev_positions[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mult
	mmi.material_override = Mat.unshaded(col("accent"), 1.0, 0.55)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.name = "PathChevrons"
	add_child(mmi)


func _build_scatter() -> void:
	var rng := EMath.Rng.new(int(def["decor_seed"]) + 77)
	var tuft_st := MK.new_st()
	for i in 5:
		var ang := (float(i) / 5.0) * TAU + 0.4
		var lean := Vector3(cos(ang), 0, sin(ang)) * 0.06
		var height := 0.26 + (i % 3) * 0.06
		var p0 := Vector3(cos(ang), 0, sin(ang)) * 0.02
		MK.add_tri(tuft_st, p0, p0 + lean + Vector3(0, height, 0), p0 + Vector3(-sin(ang), 0, cos(ang)) * 0.035,
			Color.WHITE)
	var tuft_mesh := MK.finish(tuft_st)
	var grass_colors := [Color(art["grass"]), Color(art["grass"]).darkened(0.18), Color(art["grass"]).lightened(0.12)]
	var tuft_positions: Array[Transform3D] = []
	for i in 520:
		var wx := (rng.next() - 0.5) * (FIELD_W_WORLD - 3.0)
		var wz := (rng.next() - 0.5) * (FIELD_H_WORLD - 3.0)
		var px := Vector2(wx / SCALE + HALF_W, wz / SCALE + HALF_H)
		if map.distance_to_path(px.x, px.y) < 18.0:
			continue
		var s := 0.9 + rng.next() * 1.1
		tuft_positions.append(Transform3D(Basis(Vector3.UP, rng.next() * TAU).scaled(Vector3(s, s, s)),
			Vector3(wx, 0.02, wz)))
	var tuft_mult := MultiMesh.new()
	tuft_mult.transform_format = MultiMesh.TRANSFORM_3D
	tuft_mult.use_colors = true
	tuft_mult.mesh = tuft_mesh
	tuft_mult.instance_count = tuft_positions.size()
	for i in tuft_positions.size():
		tuft_mult.set_instance_transform(i, tuft_positions[i])
		tuft_mult.set_instance_color(i, grass_colors[i % grass_colors.size()])
	var tuft_mmi := MultiMeshInstance3D.new()
	tuft_mmi.multimesh = tuft_mult
	tuft_mmi.material_override = Mat.get_mat("char_vertex")
	tuft_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tuft_mmi.name = "GrassTufts"
	add_child(tuft_mmi)

	var pebble_st := MK.new_st()
	MK.add_octa(pebble_st, Vector3.ZERO, Vector3(0.12, 0.05, 0.10), Color(0.75, 0.72, 0.7))
	MK.add_box(pebble_st, Vector3(0.08, 0.02, 0.04), Vector3(0.12, 0.06, 0.09), Color(0.6, 0.58, 0.55))
	var pebble_mesh := MK.finish(pebble_st)
	var pebble_positions: Array[Transform3D] = []
	for i in 140:
		var wx := (rng.next() - 0.5) * (FIELD_W_WORLD - 2.0)
		var wz := (rng.next() - 0.5) * (FIELD_H_WORLD - 2.0)
		var px := Vector2(wx / SCALE + HALF_W, wz / SCALE + HALF_H)
		if map.distance_to_path(px.x, px.y) < 16.0:
			continue
		var s := 0.6 + rng.next() * 1.4
		pebble_positions.append(Transform3D(Basis(Vector3.UP, rng.next() * TAU).scaled(Vector3(s, s, s)),
			Vector3(wx, 0.035, wz)))
	var pebble_mult := MultiMesh.new()
	pebble_mult.transform_format = MultiMesh.TRANSFORM_3D
	pebble_mult.mesh = pebble_mesh
	pebble_mult.instance_count = pebble_positions.size()
	for i in pebble_positions.size():
		pebble_mult.set_instance_transform(i, pebble_positions[i])
	var pebble_mmi := MultiMeshInstance3D.new()
	pebble_mmi.multimesh = pebble_mult
	pebble_mmi.material_override = Mat.get_mat("char_vertex")
	pebble_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pebble_mmi.name = "Pebbles"
	add_child(pebble_mmi)


func _build_props() -> void:
	for prop in map.props:
		var node := _make_prop(prop)
		var s := 0.5
		if prop["type"] == "tree":
			s = 0.9
		elif prop["type"] == "crystal":
			s = 0.8
		elif prop["type"] == "bones":
			s = 0.7
		node.scale = Vector3(s, s, s)
		node.position = to_world_cell(prop["cx"], prop["cy"], 0.0)
		add_child(node)


func _make_prop(prop: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Prop_%s_%d_%d" % [prop["type"], prop["cx"], prop["cy"]]
	root.rotation.y = EMath.hash2(prop["cx"], prop["cy"], int(def["seed"])) * TAU
	var prop_seed := float(prop["seed"])
	var st := MK.new_st()
	match String(prop["type"]):
		"tree":
			var h := 2.1 + prop_seed * 1.1
			var bark := Color(0.23, 0.18, 0.16)
			var bark_hi := Color(0.36, 0.28, 0.22)
			MK.add_cyl(st, Vector3.ZERO, 0.19, 0.09, h, 6, bark)
			MK.add_cyl(st, Vector3(0.02, h * 0.42, 0.01), 0.10, 0.055, h * 0.42, 5, bark_hi)
			var b1 := Basis.from_euler(Vector3(0.0, 0.4, -0.85))
			MK.add_cyl_xf(st, Transform3D(b1, Vector3(0.0, h * 0.55, 0.0)), 0.075, 0.025, 0.9, 5, bark)
			var b2 := Basis.from_euler(Vector3(-0.7, 1.2, 0.15))
			MK.add_cyl_xf(st, Transform3D(b2, Vector3(0.02, h * 0.72, 0.02)), 0.055, 0.02, 0.75, 5, bark)
			var b3 := Basis.from_euler(Vector3(0.9, 2.2, 0.4))
			MK.add_cyl_xf(st, Transform3D(b3, Vector3(-0.02, h * 0.85, 0.0)), 0.045, 0.018, 0.55, 5, bark_hi)
			var glow := MeshInstance3D.new()
			var gst := MK.new_st()
			MK.add_octa(gst, Vector3(0, 0, 0), Vector3(0.06, 0.1, 0.06), Color.WHITE)
			glow.mesh = MK.finish(gst)
			glow.material_override = Mat.emissive(col("accent"), 1.6)
			glow.position = Vector3(0.55, h * 0.55 + 0.8, 0.15)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glow)
			_glows.append(glow)
		"stones":
			var rock := Color(art["rock"]).darkened(0.3)
			MK.add_octa(st, Vector3(-0.2, 0.45, 0.0), Vector3(0.5, 0.55 + prop_seed * 0.3, 0.38), rock)
			MK.add_octa(st, Vector3(0.45, 0.25, 0.22), Vector3(0.32, 0.3, 0.3), rock.darkened(0.12))
			MK.add_octa(st, Vector3(0.05, 0.22, -0.45), Vector3(0.28, 0.22, 0.25), rock.lightened(0.08))
			MK.add_box(st, Vector3(-0.2, 0.35, 0.18), Vector3(0.08, 0.5, 0.06), col("accent").darkened(0.25))
			var glow := MeshInstance3D.new()
			var gst := MK.new_st()
			MK.add_octa(gst, Vector3(0, 0, 0), Vector3(0.05, 0.08, 0.05), Color.WHITE)
			glow.mesh = MK.finish(gst)
			glow.material_override = Mat.emissive(col("accent"), 1.2)
			glow.position = Vector3(-0.18, 0.72, 0.21)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glow)
			_glows.append(glow)
		"bones":
			var bone: Color = Color(0.78, 0.73, 0.62)
			MK.add_cyl(st, Vector3.ZERO, 0.10, 0.06, 1.65, 5, Color(0.25, 0.2, 0.17))
			MK.add_cyl(st, Vector3.ZERO, 0.18, 0.14, 0.12, 6, bone)
			MK.add_sphere(st, Vector3(0, 1.05, 0), 0.26, bone, 8, 5, Vector3(1.0, 0.85, 0.9))
			MK.add_box(st, Vector3(-0.11, 1.1, 0.20), Vector3(0.09, 0.12, 0.06), Color(0.05, 0.04, 0.05))
			MK.add_box(st, Vector3(0.11, 1.1, 0.20), Vector3(0.09, 0.12, 0.06), Color(0.05, 0.04, 0.05))
			MK.add_box(st, Vector3(-0.22, 0.55, 0.0), Vector3(0.55, 0.06, 0.07), bone.darkened(0.1), 0.4)
			MK.add_box(st, Vector3(0.18, 0.35, 0.02), Vector3(0.5, 0.05, 0.06), bone.darkened(0.18), -0.6)
			MK.add_cyl(st, Vector3(0, 1.42, 0), 0.11, 0.0, 0.34, 5, bone)
			var glow := MeshInstance3D.new()
			var gst := MK.new_st()
			MK.add_octa(gst, Vector3(-0.11, 0, 0), Vector3(0.025, 0.025, 0.025), Color.WHITE)
			MK.add_octa(gst, Vector3(0.11, 0, 0), Vector3(0.025, 0.025, 0.025), Color.WHITE)
			glow.mesh = MK.finish(gst)
			glow.material_override = Mat.emissive(col("accent"), 1.8)
			glow.position = Vector3(0, 1.10, 0.24)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glow)
			_glows.append(glow)
		"crystal":
			var crystal := Color(art["accent"])
			for i in 4:
				var ang := TAU * float(i) / 4.0 + prop_seed
				var radius := 0.25 + EMath.hash2(i, prop["cx"], int(def["seed"])) * 0.25
				var height := 0.75 + EMath.hash2(i, prop["cy"], int(def["seed"])) * 0.75
				var base := Vector3(cos(ang) * radius, 0, sin(ang) * radius)
				var tilt := Basis.from_euler(Vector3((prop_seed - 0.5) * 0.4, ang, (prop_seed - 0.5) * 0.3))
				MK.add_cyl_xf(st, Transform3D(tilt, base), 0.15 + (i % 2) * 0.04, 0.0, height, 5,
					crystal.darkened(0.35))
			MK.add_ring(st, Vector3(0, 0.02, 0), 0.45, 0.65, 10, crystal.darkened(0.5))
			var glow := MeshInstance3D.new()
			var gst := MK.new_st()
			MK.add_octa(gst, Vector3(0, 0, 0), Vector3(0.09, 0.22, 0.09), Color.WHITE)
			glow.mesh = MK.finish(gst)
			glow.material_override = Mat.emissive(crystal, 1.6)
			glow.position = Vector3(0, 0.9, 0)
			glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(glow)
			_glows.append(glow)
	var mi := MK.make_material_instance(MK.finish(st), Mat.get_mat("char_vertex"))
	root.add_child(mi)
	var shadow_st := MK.new_st()
	MK.add_disc(shadow_st, Vector3.ZERO, 1.0, 18, Color.WHITE)
	var shadow := MeshInstance3D.new()
	shadow.mesh = MK.finish(shadow_st)
	shadow.material_override = Mat.unshaded(Color(0, 0, 0), 1.0, 0.22)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.position.y = 0.055
	root.add_child(shadow)
	return root


func _build_portal() -> void:
	var gate := Node3D.new()
	gate.name = "SpawnGate"
	var entry: Dictionary = map.point_at(18.0)
	gate.position = to_world(map.portal)
	gate.rotation.y = PI * 0.5 - path_angle_at(18.0)
	gate.scale = Vector3(1.35, 1.35, 1.35)
	add_child(gate)
	var st := MK.new_st()
	var stone := Color(0.30, 0.27, 0.33)
	var stone_dark := Color(0.16, 0.14, 0.19)
	for s in [-1.0, 1.0]:
		MK.add_box(st, Vector3(1.55 * s, 0.12, 0), Vector3(0.85, 0.24, 0.85), stone_dark)
		MK.add_cyl(st, Vector3(1.55 * s, 0.22, 0), 0.33, 0.24, 2.45, 6, stone)
		MK.add_box(st, Vector3(1.55 * s, 2.72, 0), Vector3(0.75, 0.18, 0.75), stone)
		MK.add_cyl(st, Vector3(1.55 * s, 2.8, 0), 0.20, 0.0, 0.55, 5, stone_dark)
	MK.add_box(st, Vector3(0, 2.62, 0), Vector3(3.5, 0.32, 0.55), stone)
	MK.add_box(st, Vector3(0, 2.82, 0), Vector3(2.9, 0.12, 0.4), stone_dark)
	var mi := MK.make_material_instance(MK.finish(st), Mat.get_mat("char_vertex"))
	gate.add_child(mi)

	var rune_st := MK.new_st()
	for i in 5:
		MK.add_octa(rune_st, Vector3(-1.2 + i * 0.6, 2.62, 0.29), Vector3(0.06, 0.08, 0.02), Color.WHITE)
	MK.add_octa(rune_st, Vector3(-1.55, 1.7, 0.29), Vector3(0.05, 0.20, 0.02), Color.WHITE)
	MK.add_octa(rune_st, Vector3(1.55, 1.7, 0.29), Vector3(0.05, 0.20, 0.02), Color.WHITE)
	var runes := MeshInstance3D.new()
	runes.mesh = MK.finish(rune_st)
	runes.material_override = Mat.emissive(col("accent"), 2.0)
	runes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(runes)

	var veil_st := MK.new_st()
	MK.add_quad(veil_st, Vector3(-1.35, 0.18, 0), Vector3(1.35, 0.18, 0),
		Vector3(1.35, 2.45, 0), Vector3(-1.35, 2.45, 0), col("accent"), Vector3(0, 0, 1))
	_portal_veil = MeshInstance3D.new()
	_portal_veil.mesh = MK.finish(veil_st)
	var veil_mat := Mat.unshaded(col("accent"), 1.6, 0.16)
	veil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_portal_veil.material_override = veil_mat
	_portal_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(_portal_veil)

	var ring_pivot := Node3D.new()
	ring_pivot.position = Vector3(0, 1.35, 0)
	ring_pivot.rotation.x = PI * 0.5
	gate.add_child(ring_pivot)
	var ring_st := MK.new_st()
	MK.add_ring(ring_st, Vector3.ZERO, 1.15, 1.28, 24, Color.WHITE)
	_portal_ring = MeshInstance3D.new()
	_portal_ring.mesh = MK.finish(ring_st)
	_portal_ring.material_override = Mat.unshaded(col("accent"), 1.4, 0.65)
	_portal_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring_pivot.add_child(_portal_ring)

	for side in [-1.0, 1.0]:
		var flame := Node3D.new()
		flame.position = Vector3(1.55 * side, 3.3, 0)
		var fst := MK.new_st()
		MK.add_cyl(fst, Vector3.ZERO, 0.16, 0.0, 0.55, 6, Color.WHITE)
		var fmi := MeshInstance3D.new()
		fmi.mesh = MK.finish(fst)
		fmi.material_override = Mat.emissive(col("accent"), 2.2)
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.add_child(fmi)
		gate.add_child(flame)
		_portal_flames.append(flame)

	_portal_light = OmniLight3D.new()
	_portal_light.position = Vector3(0, 1.9, 0.8)
	_portal_light.light_color = col("accent")
	_portal_light.light_energy = 1.5
	_portal_light.omni_range = 6.0
	_portal_light.shadow_enabled = false
	gate.add_child(_portal_light)

	var motes := CPUParticles3D.new()
	motes.amount = 18
	motes.lifetime = 1.6
	motes.preprocess = 1.2
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(1.3, 0.15, 0.25)
	motes.position = Vector3(0, 0.2, 0)
	motes.direction = Vector3.UP
	motes.spread = 15.0
	motes.initial_velocity_min = 0.35
	motes.initial_velocity_max = 1.0
	motes.gravity = Vector3(0, 0.35, 0)
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.075, 0.075)
	q.material = Mat.unshaded(col("accent2"), 1.5, 0.8)
	motes.mesh = q
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(motes)


func _build_beacon() -> void:
	var beacon := Node3D.new()
	beacon.name = "Beacon"
	beacon.position = to_world(map.beacon)
	beacon.scale = Vector3(1.3, 1.3, 1.3)
	add_child(beacon)
	var st := MK.new_st()
	var stone := Color(0.34, 0.30, 0.34)
	var stone_dark := Color(0.17, 0.15, 0.19)
	MK.add_cyl(st, Vector3.ZERO, 1.25, 1.05, 0.38, 8, stone_dark)
	MK.add_cyl(st, Vector3(0, 0.38, 0), 0.95, 0.62, 3.1, 7, stone)
	MK.add_cyl(st, Vector3(0, 1.35, 0), 1.02, 1.02, 0.16, 8, stone_dark)
	MK.add_cyl(st, Vector3(0, 2.55, 0), 0.85, 0.85, 0.16, 8, stone_dark)
	MK.add_cyl(st, Vector3(0, 3.48, 0), 1.0, 0.85, 0.32, 8, stone)
	MK.add_cyl(st, Vector3(0, 3.8, 0), 0.66, 0.75, 0.32, 8, stone_dark)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		MK.add_cyl(st, Vector3(cos(ang) * 0.95, 0.38, sin(ang) * 0.95), 0.10, 0.06, 2.1, 5, stone_dark)
	MK.add_box(st, Vector3(0, 0.10, 1.55), Vector3(1.1, 0.2, 0.7), stone_dark)
	var mi := MK.make_material_instance(MK.finish(st), Mat.get_mat("char_vertex"))
	beacon.add_child(mi)

	var core_st := MK.new_st()
	MK.add_octa(core_st, Vector3.ZERO, Vector3(0.38, 0.6, 0.38), Color.WHITE)
	_beacon_core = MeshInstance3D.new()
	_beacon_core.mesh = MK.finish(core_st)
	_beacon_core.material_override = Mat.emissive(col("accent"), 2.0)
	_beacon_core.position = Vector3(0, 4.35, 0)
	_beacon_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(_beacon_core)

	var ring_pivot := Node3D.new()
	ring_pivot.position = Vector3(0, 4.25, 0)
	beacon.add_child(ring_pivot)
	for i in 3:
		var ang := TAU * float(i) / 3.0
		var orb := Node3D.new()
		orb.position = Vector3(cos(ang) * 0.95, 0, sin(ang) * 0.95)
		var ost := MK.new_st()
		MK.add_octa(ost, Vector3.ZERO, Vector3(0.08, 0.12, 0.08), Color.WHITE)
		var omi := MeshInstance3D.new()
		omi.mesh = MK.finish(ost)
		omi.material_override = Mat.emissive(col("accent"), 1.8)
		omi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(omi)
		ring_pivot.add_child(orb)

	_beacon_orbs.append(ring_pivot)

	_beacon_light = OmniLight3D.new()
	_beacon_light.position = Vector3(0, 4.2, 0)
	_beacon_light.light_color = col("accent")
	_beacon_light.light_energy = 1.8
	_beacon_light.omni_range = 8.0
	_beacon_light.shadow_enabled = false
	beacon.add_child(_beacon_light)

	var beam_st := MK.new_st()
	MK.add_cyl(beam_st, Vector3(0, 4.4, 0), 0.16, 0.5, 7.0, 8, Color.WHITE)
	var beam := MeshInstance3D.new()
	beam.mesh = MK.finish(beam_st)
	beam.material_override = Mat.unshaded(col("accent"), 1.0, 0.10)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(beam)
	var flame := CPUParticles3D.new()
	flame.amount = 14
	flame.lifetime = 1.1
	flame.preprocess = 0.6
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.18
	flame.position = Vector3(0, 4.35, 0)
	flame.direction = Vector3.UP
	flame.spread = 12.0
	flame.initial_velocity_min = 0.4
	flame.initial_velocity_max = 1.0
	flame.gravity = Vector3(0, 0.6, 0)
	flame.scale_amount_min = 0.5
	flame.scale_amount_max = 1.2
	var fq := QuadMesh.new()
	fq.size = Vector2(0.12, 0.12)
	fq.material = Mat.unshaded(col("accent2"), 1.8, 0.85)
	flame.mesh = fq
	beacon.add_child(flame)


func _build_border() -> void:
	var rng := EMath.Rng.new(int(def["seed"]) + 512)
	var rock_st := MK.new_st()
	MK.add_octa(rock_st, Vector3.ZERO, Vector3(1.0, 0.75, 0.9), Color(0.55, 0.52, 0.5))
	MK.add_octa(rock_st, Vector3(0.45, 0.15, 0.2), Vector3(0.55, 0.45, 0.5), Color(0.45, 0.43, 0.42))
	var rock_mesh := MK.finish(rock_st)
	var rocks: Array[Transform3D] = []
	for i in 64:
		var ang := TAU * float(i) / 64.0 + rng.next() * 0.08
		var rx := 32.0 + rng.next() * 6.0
		var rz := 24.0 + rng.next() * 5.0
		var pos := Vector3(cos(ang) * rx, -0.3 + rng.next() * 0.6, sin(ang) * rz)
		var s := 0.6 + rng.next() * 2.2
		rocks.append(Transform3D(Basis(Vector3.UP, rng.next() * TAU).scaled(Vector3(s, s * (0.5 + rng.next() * 0.7), s)), pos))
	var rock_mult := MultiMesh.new()
	rock_mult.transform_format = MultiMesh.TRANSFORM_3D
	rock_mult.use_colors = true
	rock_mult.mesh = rock_mesh
	rock_mult.instance_count = rocks.size()
	for i in rocks.size():
		rock_mult.set_instance_transform(i, rocks[i])
		rock_mult.set_instance_color(i, Color(1, 1, 1).darkened(rng.next() * 0.45))
	var rock_mmi := MultiMeshInstance3D.new()
	rock_mmi.multimesh = rock_mult
	rock_mmi.material_override = Mat.get_mat("char_vertex")
	rock_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rock_mmi.name = "BorderRocks"
	add_child(rock_mmi)

	var tree_st := MK.new_st()
	MK.add_cyl(tree_st, Vector3.ZERO, 0.25, 0.10, 3.1, 5, Color(0.14, 0.12, 0.13))
	MK.add_cyl_xf(tree_st, Transform3D(Basis.from_euler(Vector3(0.2, 0.5, -0.7)), Vector3(0.0, 2.3, 0)),
		0.08, 0.02, 1.2, 4, Color(0.12, 0.1, 0.11))
	MK.add_cyl_xf(tree_st, Transform3D(Basis.from_euler(Vector3(-0.5, 1.2, 0.2)), Vector3(0.0, 2.7, 0)),
		0.06, 0.02, 0.9, 4, Color(0.12, 0.1, 0.11))
	var tree_mesh := MK.finish(tree_st)
	var trees: Array[Transform3D] = []
	for i in 20:
		var ang := TAU * float(i) / 20.0 + 0.13
		var pos := Vector3(cos(ang) * (34.0 + rng.next() * 4.0), -0.2, sin(ang) * (26.0 + rng.next() * 3.0))
		var s := 0.8 + rng.next() * 1.1
		trees.append(Transform3D(Basis(Vector3.UP, rng.next() * TAU).scaled(Vector3(s, s, s)), pos))
	var tree_mult := MultiMesh.new()
	tree_mult.transform_format = MultiMesh.TRANSFORM_3D
	tree_mult.mesh = tree_mesh
	tree_mult.instance_count = trees.size()
	for i in trees.size():
		tree_mult.set_instance_transform(i, trees[i])
	var tree_mmi := MultiMeshInstance3D.new()
	tree_mmi.multimesh = tree_mult
	tree_mmi.material_override = Mat.get_mat("char_vertex")
	tree_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree_mmi.name = "BorderTrees"
	add_child(tree_mmi)


func _build_ambient() -> void:
	var motes := CPUParticles3D.new()
	motes.name = "AmbientMotes"
	motes.amount = 46
	motes.lifetime = 8.0
	motes.preprocess = 4.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(29.0, 1.2, 21.0)
	motes.position = Vector3(0, 1.6, 0)
	motes.direction = Vector3.UP
	motes.spread = 30.0
	motes.initial_velocity_min = 0.06
	motes.initial_velocity_max = 0.26
	if map.id == "frost":
		motes.direction = Vector3.DOWN
		motes.gravity = Vector3(0, -0.08, 0)
	else:
		motes.gravity = Vector3(0, 0.045, 0)
	motes.scale_amount_min = 0.4
	motes.scale_amount_max = 1.5
	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.055)
	q.material = Mat.unshaded(col("accent2"), 1.4, 0.55)
	motes.mesh = q
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


func _process(delta: float) -> void:
	_time += delta
	if _portal_ring != null:
		_portal_ring.rotation.y += delta * 0.9
	if _portal_light != null:
		_portal_light.light_energy = 1.25 + sin(_time * 2.6) * 0.28
	if _portal_veil != null:
		var m := _portal_veil.material_override as StandardMaterial3D
		if m != null:
			m.albedo_color.a = 0.12 + (sin(_time * 1.7) + 1.0) * 0.04
	for i in _portal_flames.size():
		var f: Node3D = _portal_flames[i]
		f.scale = Vector3(1.0, 0.85 + sin(_time * 6.0 + i) * 0.15, 1.0)
	if _beacon_core != null:
		_beacon_core.rotation.y += delta * 1.4
		_beacon_core.position.y = 4.35 + sin(_time * 1.8) * 0.06
	if _beacon_light != null:
		_beacon_light.light_energy = 1.55 + sin(_time * 2.2) * 0.35
	for orb in _beacon_orbs:
		orb.rotation.y += delta * 0.7
	for i in _glows.size():
		var g: Node3D = _glows[i]
		var s := 0.9 + sin(_time * 2.5 + i * 1.7) * 0.12
		g.scale = Vector3(s, s, s)
