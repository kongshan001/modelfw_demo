class_name ModLoader
extends RefCounted

# 运行时 mod 加载器（PoC）。
# 安装：res://mods/<id>/ → user://mods/<id>/（模拟用户安装）
# 扫描：user://mods/*/manifest.json
# 校验：sha256 → GLTFDocument 解析 → 三角面数 → bounds/pivot/footprint
# 通过后才交给场景显示。

const SOURCE_DIR := "res://mods"
const INSTALL_DIR := "user://mods"
const TOL := 0.02


static func install_fixtures(overwrite := true) -> int:
	var dir := DirAccess.open(SOURCE_DIR)
	if dir == null:
		push_warning("mods source dir missing: " + SOURCE_DIR)
		return 0
	var installed := 0
	for folder in dir.get_directories():
		var src_dir := SOURCE_DIR + "/" + folder
		var text := FileAccess.get_file_as_string(src_dir + "/manifest.json")
		if text.is_empty():
			continue
		var manifest: Variant = JSON.parse_string(text)
		if typeof(manifest) != TYPE_DICTIONARY:
			continue
		var dst_dir := INSTALL_DIR + "/" + folder
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dst_dir))
		var files: Array[String] = ["manifest.json"]
		if manifest.has("file"):
			files.append(str(manifest["file"]))
		for f in files:
			var dst := dst_dir + "/" + f
			if not overwrite and FileAccess.file_exists(dst):
				continue
			var bytes := FileAccess.get_file_as_bytes(src_dir + "/" + f)
			if bytes.is_empty():
				push_warning("cannot read " + src_dir + "/" + f)
				continue
			var out := FileAccess.open(dst, FileAccess.WRITE)
			if out == null:
				push_warning("cannot write " + dst)
				continue
			out.store_buffer(bytes)
			out.close()
		installed += 1
	return installed


static func scan() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(INSTALL_DIR)
	if dir == null:
		return out
	for folder in dir.get_directories():
		var base := INSTALL_DIR + "/" + folder
		var text := FileAccess.get_file_as_string(base + "/manifest.json")
		if text.is_empty():
			continue
		var manifest: Variant = JSON.parse_string(text)
		if typeof(manifest) != TYPE_DICTIONARY:
			continue
		out.append({"dir": base, "manifest": manifest})
	out.sort_custom(func(a, b):
		return str(a["manifest"].get("id", "")) < str(b["manifest"].get("id", "")))
	return out


static func validate(entry: Dictionary) -> Dictionary:
	var m: Dictionary = entry["manifest"]
	var dir: String = entry["dir"]
	var res := {
		"ok": false, "reason": "", "scene": null,
		"tris": 0, "meshes": 0, "aabb": AABB(),
		"file": "", "sha": "",
	}
	for key in ["id", "file", "sha256", "bounds", "footprint", "pivot", "max_tris"]:
		if not m.has(key):
			res["reason"] = "manifest missing " + key
			return res

	var path := dir + "/" + str(m["file"])
	if not FileAccess.file_exists(path):
		res["reason"] = "file missing"
		return res
	var bytes := FileAccess.get_file_as_bytes(path)
	res["sha"] = _sha256(bytes)
	res["file"] = path
	if res["sha"] != str(m["sha256"]):
		res["reason"] = "sha256 mismatch"
		return res

	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	if err != OK:
		res["reason"] = "gltf parse error %d" % err
		return res
	var scene := doc.generate_scene(state)
	if scene == null:
		res["reason"] = "gltf scene empty"
		return res

	var info := _measure(scene)
	res["tris"] = info["tris"]
	res["meshes"] = info["meshes"]
	res["aabb"] = info["aabb"]

	if int(info["meshes"]) == 0:
		scene.free()
		res["reason"] = "no meshes"
		return res
	if int(info["tris"]) > int(m["max_tris"]):
		scene.free()
		res["reason"] = "tris %d > max %d" % [int(info["tris"]), int(m["max_tris"])]
		return res

	var b: Dictionary = m["bounds"]
	var dmin: Array = b["min"]
	var dmax: Array = b["max"]
	var box: AABB = info["aabb"]
	if (box.position.x < float(dmin[0]) - TOL or box.position.y < float(dmin[1]) - TOL
			or box.position.z < float(dmin[2]) - TOL
			or box.end.x > float(dmax[0]) + TOL or box.end.y > float(dmax[1]) + TOL
			or box.end.z > float(dmax[2]) + TOL):
		scene.free()
		res["reason"] = "bounds exceed manifest"
		return res

	var footprint := maxf(box.size.x, box.size.z)
	if footprint > float(m["footprint"]) + TOL:
		scene.free()
		res["reason"] = "footprint %.3f > %.3f" % [footprint, float(m["footprint"])]
		return res
	if absf(box.position.y) > TOL:
		scene.free()
		res["reason"] = "pivot not at base (min.y=%.3f)" % box.position.y
		return res

	res["ok"] = true
	res["scene"] = scene
	return res


static func style_unshaded(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src = mi.get_active_material(s)
			var mat: StandardMaterial3D
			if src is StandardMaterial3D:
				mat = (src as StandardMaterial3D).duplicate() as StandardMaterial3D
			else:
				mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.vertex_color_use_as_albedo = true
			mat.albedo_color = Color.WHITE
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.set_surface_override_material(s, mat)


static func _measure(root: Node) -> Dictionary:
	var box := AABB()
	var first := true
	var meshes := 0
	var tris := 0
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xform: Transform3D = item[1]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				meshes += 1
				tris += int(mi.mesh.get_faces().size() / 3)
				var local_box: AABB = mi.mesh.get_aabb()
				for i in 8:
					var p: Vector3 = xform * local_box.get_endpoint(i)
					if first:
						box = AABB(p, Vector3.ZERO)
						first = false
					else:
						box = box.expand(p)
		for child in node.get_children():
			stack.append([child, xform])
	return {"aabb": box, "tris": tris, "meshes": meshes}


static func _sha256(data: PackedByteArray) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish().hex_encode()
