extends SceneTree

func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls): return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r: return r
	return null

func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children(): c += _count_meshes(ch)
	return c

func _init() -> void:
	var path := "res://assets/Rogue_MediaPipe_walk.fbx"
	print("FBX_EXISTS ", FileAccess.file_exists(path))
	var ps: PackedScene = load(path)
	print("FBX_PACKED ", ps != null)
	if ps == null: quit(); return
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	await process_frame
	var sk: Skeleton3D = _find(inst, "Skeleton3D")
	var ap: AnimationPlayer = _find(inst, "AnimationPlayer")
	print("FBX_BONES ", sk.get_bone_count() if sk else -1, " MESHES ", _count_meshes(inst))
	if ap:
		print("FBX_ANIMS ", ap.get_animation_list())
		for a in ap.get_animation_list():
			var an := ap.get_animation(a)
			print("FBX_ANIM ", a, " len=", an.length, " tracks=", an.get_track_count())
	quit()
