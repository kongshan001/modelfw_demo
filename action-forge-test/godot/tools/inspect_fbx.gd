extends SceneTree

func walk(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	print(pad, n.name, " [", n.get_class(), "]")
	if n is Skeleton3D:
		print(pad, "  bones=", n.get_bone_count())
	if n is AnimationPlayer:
		print(pad, "  anims=", n.get_animation_list())
		for a in n.get_animation_list():
			var an: Animation = n.get_animation(a)
			print(pad, "    ", a, " len=", an.length, " tracks=", an.get_track_count())
	for c in n.get_children():
		walk(c, depth + 1)

func _init() -> void:
	var ps: PackedScene = load("res://assets/Rogue_Walk_IdleTalkLayer_AF.fbx")
	if ps == null:
		print("FBX_LOAD_FAIL")
		quit(1); return
	var inst := ps.instantiate()
	print("FBX_INSTANCE ", inst.name)
	walk(inst, 0)
	inst.free()
	quit()
