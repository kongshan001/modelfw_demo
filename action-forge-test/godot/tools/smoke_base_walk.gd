extends SceneTree

func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_sk(c)
		if r: return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r: return r
	return null

func _count_meshes(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children(): c += _count_meshes(ch)
	return c

func _drift(ap: AnimationPlayer, bone: String) -> float:
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	var mn := Vector3(INF, INF, INF); var mx := Vector3(-INF, -INF, -INF)
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D: continue
		if not str(an.track_get_path(t)).ends_with(":" + bone): continue
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k)
			mn = mn.min(v); mx = mx.max(v)
	if mx.x == -INF: return 0.0
	return Vector2(mx.x - mn.x, mx.z - mn.z).length()

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for f in ["Rogue_WalkLoop_AF_inplace.glb", "Rogue_WalkLoop_AF_rootmotion.glb"]:
		var ps: PackedScene = load("res://assets/" + f)
		if ps == null: print("BASE_SMOKE_FAIL load ", f); quit(1); return
		var inst: Node3D = ps.instantiate(); root.add_child(inst); await process_frame
		var sk := _find_sk(inst); var ap := _find_ap(inst)
		var an: Animation = ap.get_animation(ap.get_animation_list()[0])
		print("BASE_SMOKE %s bones=%d meshes=%d anim=%s len=%.4f tracks=%d root_drift=%.4f" % [f, sk.get_bone_count(), _count_meshes(inst), ap.get_animation_list()[0], an.length, an.get_track_count(), _drift(ap, "root")])
		var an2: Animation = ap.get_animation(ap.get_animation_list()[0]); an2.loop_mode = Animation.LOOP_LINEAR; ap.play(ap.get_animation_list()[0])
		var miny := 1e9; var feet := []
		for fn in ["foot.l", "foot.r", "toes.l", "toes.r"]:
			var i := sk.find_bone(fn); if i >= 0: feet.append(i)
		for s in 41:
			ap.seek(an.length * float(s) / 40.0, true); await process_frame
			for i in feet:
				var wp: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin
				miny = minf(miny, wp.y)
		var q0: Quaternion = Quaternion.IDENTITY; var q1: Quaternion = Quaternion.IDENTITY
		var li := sk.find_bone("upperleg.l")
		if li >= 0:
			ap.seek(0, true); await process_frame; q0 = sk.get_bone_pose_rotation(li)
			ap.seek(an.length, true); await process_frame; q1 = sk.get_bone_pose_rotation(li)
		print("BASE_SMOKE_FOOT %s min_foot_y=%.4f loop_seam_leg=%.4f" % [f, miny, q0.angle_to(q1)])
		inst.queue_free(); await process_frame
	print("BASE_SMOKE_OK"); quit(0)
