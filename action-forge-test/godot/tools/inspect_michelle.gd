extends SceneTree

func _find_sk(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n
	for c in n.get_children():
		var r := _find_sk(c); if r: return r
	return null
func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r := _find_ap(c); if r: return r
	return null
func _find_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): _find_meshes(c, out)
func _drift(ap: AnimationPlayer, bone: String) -> float:
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	var mn := Vector3(INF, INF, INF); var mx := Vector3(-INF, -INF, -INF)
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D: continue
		if not str(an.track_get_path(t)).ends_with(":" + bone): continue
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k); mn = mn.min(v); mx = mx.max(v)
	if mx.x == -INF: return 0.0
	return Vector2(mx.x - mn.x, mx.z - mn.z).length()
func _bone(sk: Skeleton3D, needle: String) -> int:
	for i in sk.get_bone_count():
		if sk.get_bone_name(i).to_lower().contains(needle.to_lower()): return i
	return -1
func _foot_stats(sk: Skeleton3D, ap: AnimationPlayer, length: float, samples: int) -> Dictionary:
	var ids := []
	for n in ["LeftFoot", "RightFoot", "LeftToeBase", "RightToeBase"]:
		var i := _bone(sk, n); if i >= 0: ids.append(i)
	if ids.is_empty(): return {}
	var miny := 1e9; var frames: Array = []
	for s in samples:
		ap.seek(length * float(s) / float(samples - 1), true); await process_frame
		var pos: Array = []
		for i in ids:
			var p: Vector3 = sk.global_transform * sk.get_bone_global_pose(i).origin; pos.append(p); miny = minf(miny, p.y)
		frames.append(pos)
	var worst := 0.0; var longest := 0
	for fi in ids.size():
		var start := -1
		for s in frames.size():
			var g: bool = frames[s][fi].y <= miny + 0.03
			if g and start < 0: start = s
			if (not g or s == frames.size() - 1) and start >= 0:
				var e := s - 1 if not g else s
				longest = maxi(longest, e - start + 1)
				var a: Vector3 = frames[start][fi]; var b: Vector3 = frames[e][fi]
				worst = maxf(worst, Vector2(b.x - a.x, b.z - a.z).length()); start = -1
	return {"min_foot_y": miny, "stance_slide": worst, "longest": longest}
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	for f in ["Michelle_WalkLoop_AF_inplace.glb", "Michelle_WalkLoop_AF_rootmotion.glb", "Michelle_Walk_source.glb"]:
		var ps: PackedScene = load("res://assets/" + f)
		if ps == null: print("MICHELLE_FAIL load ", f); continue
		var inst: Node3D = ps.instantiate()
		var is_af: bool = String(f).begins_with("Michelle_WalkLoop")
		if is_af: inst.scale = Vector3.ONE * 0.618  # normalize the app's 2.692 m export to the source's 1.664 m
		root.add_child(inst); await process_frame
		var sk := _find_sk(inst); var ap := _find_ap(inst)
		var meshes: Array = []; _find_meshes(inst, meshes)
		var an: Animation = ap.get_animation(ap.get_animation_list()[0]) if ap else null
		if ap and an:
			an.loop_mode = Animation.LOOP_LINEAR
			ap.play(ap.get_animation_list()[0])
			ap.speed_scale = 0.0
			ap.seek(0.0, true)
		var aabb := (meshes[0] as MeshInstance3D).get_aabb() if meshes.size() > 0 else AABB()
		var height := aabb.size.y * inst.scale.y
		var hi := _bone(sk, "Hips"); var head := _bone(sk, "Head"); var foot := _bone(sk, "LeftFoot")
		var hips_y := (sk.global_transform * sk.get_bone_global_pose(hi).origin).y if hi >= 0 else -1.0
		var head_y := (sk.global_transform * sk.get_bone_global_pose(head).origin).y if head >= 0 else -1.0
		var foot_y := (sk.global_transform * sk.get_bone_global_pose(foot).origin).y if foot >= 0 else -1.0
		print("MICHELLE %s bones=%d meshes=%d aabb_height=%.3f hips_y=%.3f head_y=%.3f foot_y=%.3f anim=%s len=%.4f tracks=%d hips_drift=%.4f" % [
			f, sk.get_bone_count() if sk else -1, meshes.size(), height, hips_y, head_y, foot_y,
			ap.get_animation_list()[0] if ap else "-", an.length if an else 0, an.get_track_count() if an else 0,
			_drift(ap, "hips") if ap else 0.0])
		if ap and sk:
			var fs := await _foot_stats(sk, ap, an.length, 41)
			if not fs.is_empty():
				print("MICHELLE_FOOT %s min_foot_y=%.3f stance_slide=%.3f longest=%d" % [f, fs["min_foot_y"], fs["stance_slide"], fs["longest"]])
		inst.queue_free(); await process_frame
	quit()
