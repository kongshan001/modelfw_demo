extends SceneTree

## Headless acceptance for the Action Forge -> Godot retarget test.
## Run: godot --headless --path action-forge-test/godot -s tools/smoke.gd

var fails: Array[String] = []

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

func _load_actor(file: String) -> Dictionary:
	var ps: PackedScene = load("res://assets/" + file)
	if ps == null:
		fails.append("cannot load " + file)
		return {}
	var inst: Node3D = ps.instantiate()
	root.add_child(inst)
	await process_frame
	return {"node": inst, "sk": _find_sk(inst), "ap": _find_ap(inst), "meshes": _count_meshes(inst)}

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
	var af := await _load_actor("Rogue_MichelleWalk_AF_inplace.glb")
	var af_root := await _load_actor("Rogue_MichelleWalk_AF_rootmotion.glb")
	var ref := await _load_actor("Michelle_Walk_source.glb")
	var orig := await _load_actor("Rogue_original.glb")
	if fails.size() > 0:
		for f in fails: print("SMOKE_FAIL ", f)
		quit(1); return
	var af_sk: Skeleton3D = af["sk"]; var af_ap: AnimationPlayer = af["ap"]
	var ref_sk: Skeleton3D = ref["sk"]; var ref_ap: AnimationPlayer = ref["ap"]
	var orig_sk: Skeleton3D = orig["sk"]
	if af_sk == null or af_ap == null or ref_sk == null or ref_ap == null or orig_sk == null:
		print("SMOKE_FAIL missing skeleton/player"); quit(1); return
	var af_names := af_ap.get_animation_list()
	var af_an: Animation = af_ap.get_animation(af_names[0])
	var ref_names := ref_ap.get_animation_list()
	var ref_an: Animation = ref_ap.get_animation(ref_names[0])
	print("SMOKE_AF_INPLACE bones=%d meshes=%d anim=%s len=%.4f tracks=%d" % [af_sk.get_bone_count(), af["meshes"], af_names[0], af_an.length, af_an.get_track_count()])
	print("SMOKE_MICHELLE bones=%d meshes=%d anim=%s len=%.4f tracks=%d" % [ref_sk.get_bone_count(), ref["meshes"], ref_names[0], ref_an.length, ref_an.get_track_count()])
	if af_sk.get_bone_count() != 41: fails.append("AF bones != 41")
	if af["meshes"] != 12: fails.append("AF meshes != 12")
	if absf(af_an.length - 1.0333333) > 0.001: fails.append("AF clip length")
	if ref_sk.get_bone_count() != 65: fails.append("Michelle bones != 65")
	if absf(ref_an.length - 1.0333333) > 0.001: fails.append("Michelle clip length")
	var d_in := _drift(af_ap, "root")
	var d_root := _drift(af_root["ap"], "root")
	print("SMOKE_ROOT_DRIFT inplace=%.4f rootmotion=%.4f" % [d_in, d_root])
	if d_in > 0.0001: fails.append("in-place root drift > 0.1 mm")
	if d_root <= d_in: fails.append("root-motion drift not larger than in-place")
	# playback actually moves a leg
	af_ap.play(af_names[0]); af_ap.seek(0, true); await process_frame
	var af_leg := af_sk.find_bone("upperleg.l")
	var q0: Quaternion = af_sk.get_bone_pose_rotation(af_leg)
	af_ap.seek(0.3, true); await process_frame
	var q1: Quaternion = af_sk.get_bone_pose_rotation(af_leg)
	var dq := q0.angle_to(q1)
	print("SMOKE_PLAY af_leg_angle_delta=%.4f rad" % dq)
	if dq < 0.001: fails.append("AF animation does not move the leg")
	# original Rogue bone names vs AF
	var af_set := {}
	for i in af_sk.get_bone_count(): af_set[af_sk.get_bone_name(i)] = true
	var common := 0
	for i in orig_sk.get_bone_count():
		if af_set.has(orig_sk.get_bone_name(i)): common += 1
	print("SMOKE_ORIGINAL_ROGUE bones=%d common_with_af=%d/%d" % [orig_sk.get_bone_count(), common, af_sk.get_bone_count()])
	if orig_sk.get_bone_count() != 41 or common != 41: fails.append("original Rogue bone names differ")
	# animation-only GLB: node names / direct binding
	var ps: PackedScene = load("res://assets/Rogue_MichelleWalk_AF_inplace_animonly.glb")
	var inst: Node = ps.instantiate()
	var ap2 := _find_ap(inst)
	var sk2 := _find_sk(inst)
	var dotted := 0
	for i in af_sk.get_bone_count():
		if af_sk.get_bone_name(i).contains("."): dotted += 1
	var has_sanitized := false
	if ap2:
		var an2: Animation = ap2.get_animation(ap2.get_animation_list()[0])
		for t in an2.get_track_count():
			if str(an2.track_get_path(t)).contains("upperarm_l"): has_sanitized = true
		print("SMOKE_ANIMONLY tracks=%d skeleton3d=%s dotted_af_bones=%d sanitized_path=%s" % [an2.get_track_count(), "yes" if sk2 else "no", dotted, str(has_sanitized)])
	else:
		fails.append("anim-only has no AnimationPlayer")
	if sk2 != null: fails.append("anim-only unexpectedly has a Skeleton3D")
	if not has_sanitized: fails.append("anim-only expected sanitized path upperarm_l")
	inst.free()
	if fails.size() > 0:
		for f in fails: print("SMOKE_FAIL ", f)
		quit(1)
	else:
		print("SMOKE_OK")
		quit(0)
