extends SceneTree

var files := [
	["Rogue_MichelleWalk_AF_inplace.glb", ["foot.l", "foot.r", "toes.l", "toes.r"]],
	["Rogue_MichelleWalk_AF_rootmotion.glb", ["foot.l", "foot.r", "toes.l", "toes.r"]],
	["Michelle_Walk_source.glb", ["mixamorig_LeftFoot", "mixamorig_RightFoot", "mixamorig_LeftToeBase", "mixamorig_RightToeBase"]],
]

func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r = _find_sk(c)
		if r: return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r: return r
	return null

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for entry in files:
		var f: String = entry[0]
		var foot_names: Array = entry[1]
		var ps: PackedScene = load("res://assets/" + f)
		var inst: Node3D = ps.instantiate()
		root.add_child(inst)
		await process_frame
		var sk := _find_sk(inst)
		var ap := _find_ap(inst)
		var names := ap.get_animation_list()
		var an: Animation = ap.get_animation(names[0])
		an.loop_mode = Animation.LOOP_LINEAR
		ap.play(names[0])
		await process_frame
		var idxs := []
		for fn in foot_names:
			var i := sk.find_bone(fn)
			if i >= 0: idxs.append(i)
		print("== ", f, " bones=", sk.get_bone_count(), " feet=", idxs.size(), " clip=", an.length)
		var min_all := 1e9
		for p in 25:
			var t := an.length * float(p) / 24.0
			ap.seek(t, true)
			await process_frame
			var lo := 1e9
			for i in idxs:
				var wp: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
				lo = minf(lo, wp.y)
			min_all = minf(min_all, lo)
			if p % 4 == 0:
				var hips := sk.find_bone("hips")
				if hips < 0: hips = sk.find_bone("mixamorig_Hips")
				var hy := (sk.global_transform * sk.get_bone_global_pose(hips).origin).y if hips >= 0 else -1.0
				print("  t=%.3f min_foot_y=%.4f hips_y=%.4f" % [t, lo, hy])
		print("  MIN_FOOT_Y_OVER_CLIP=%.4f" % min_all)
		inst.queue_free()
		await process_frame
	quit()
