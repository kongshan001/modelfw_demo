extends SceneTree

# 检查 Tripo GLB 的节点、三角面、材质与包围盒，用于确定缩放/原点/朝向。
# 运行：godot --headless --path godot-ai-3d-game -s tools/inspect_tripo_assets.gd

const ASSETS := {
	"kart": "res://assets/ai/tripo/kart/kart.glb",
	"windmill": "res://assets/ai/tripo/windmill/windmill.glb",
}


func _initialize() -> void:
	for key in ASSETS:
		await _inspect(key, ASSETS[key])
	quit(0)


func _inspect(label: String, path: String) -> void:
	print("=== %s : %s exists=%s ===" % [label, path, str(ResourceLoader.exists(path))])
	var packed := load(path) as PackedScene
	if packed == null:
		print("LOAD_FAILED")
		return
	var inst := packed.instantiate()
	root.add_child(inst)
	await process_frame
	var mesh_count := 0
	var tris := 0
	var aabb := AABB()
	var first := true
	var mesh_paths: Array[String] = []
	var textured := 0
	var materials: Array[String] = []
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			mesh_count += 1
			tris += mi.mesh.get_faces().size() / 3
			mesh_paths.append(str(inst.get_path_to(mi)))
			var local := mi.global_transform * mi.get_aabb()
			if first:
				aabb = local
				first = false
			else:
				aabb = aabb.merge(local)
			for s in mi.mesh.get_surface_count():
				var mat := mi.mesh.surface_get_material(s)
				if mat is StandardMaterial3D:
					var sm := mat as StandardMaterial3D
					if sm.albedo_texture != null:
						textured += 1
					materials.append(sm.resource_name)
	print("nodes=%d meshes=%d tris=%d textured_surfaces=%d" % [mesh_paths.size(), mesh_count, tris, textured])
	print("aabb_pos=%s size=%s center=%s" % [aabb.position, aabb.size, aabb.get_center()])
	print("materials=%s" % [materials])
	print("mesh_paths=%s" % [mesh_paths.slice(0, 12)])
	inst.queue_free()
	await process_frame
