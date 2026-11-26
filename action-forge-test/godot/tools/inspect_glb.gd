extends SceneTree

func walk(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	print(pad, n.name, " [", n.get_class(), "]")
	if n is Skeleton3D:
		print(pad, "  bones=", n.get_bone_count(), " names=", _bone_names(n, 12))
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb()
		print(pad, "  aabb=", aabb)
	if n is AnimationPlayer:
		print(pad, "  anims=", n.get_animation_list())
		for a in n.get_animation_list():
			var anim: Animation = n.get_animation(a)
			print(pad, "    ", a, " len=", anim.length, " loops=", anim.loop_mode, " tracks=", anim.get_track_count(), " first_path=", anim.track_get_path(0) if anim.get_track_count() > 0 else "")
	for c in n.get_children():
		walk(c, depth + 1)

func _bone_names(sk: Skeleton3D, limit: int) -> String:
	var arr := []
	for i in mini(limit, sk.get_bone_count()):
		arr.append(sk.get_bone_name(i))
	return ",".join(arr)

func _init() -> void:
	for f in ["Rogue_MichelleWalk_AF_inplace.glb", "Rogue_MichelleWalk_AF_rootmotion.glb", "Rogue_MichelleWalk_AF_inplace_animonly.glb", "Michelle_Walk_source.glb", "Rogue_original.glb"]:
		print("===== ", f, " =====")
		var ps: PackedScene = load("res://assets/" + f)
		if ps == null:
			print("LOAD FAILED")
			continue
		var inst := ps.instantiate()
		walk(inst, 0)
		inst.free()
	quit()
