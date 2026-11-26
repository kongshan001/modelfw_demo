extends SceneTree

## T-023 gait analysis: frame-by-frame foot positions + foot orientation + hips yaw.
## Purpose: distinguish (a) 180 deg yaw offset on hips/root from (b) reversed
## locomotion (moonwalk) and (c) wrong preview movement code.
##
## Usage: godot --headless --path action-forge-test/godot -s tools/diag_gait.gd

const CASES := [
	{"key": "AF_QUATERNIUS_WALK", "path": "res://assets/Rogue_WalkLoop_AF_inplace.glb", "clip": "walk_loop_fit", "rig": "kaykit"},
	{"key": "AF_MICHELLE_WALK", "path": "res://assets/Rogue_MichelleWalk_AF_inplace.glb", "clip": "Michelle Walk_fit", "rig": "kaykit"},
	{"key": "AF_MICHELLE_YAWFIX", "path": "res://assets/Rogue_MichelleWalk_AF_inplace_yawfix.glb", "clip": "Michelle Walk_fit_yawfix", "rig": "kaykit"},
	{"key": "ROGUE_ORIGINAL_WALK", "path": "res://assets/Rogue_original.glb", "clip": "Walking_A", "rig": "kaykit"},
	{"key": "MICHELLE_SOURCE_WALK", "path": "res://assets/Michelle_Walk_source.glb", "clip": "Animation", "rig": "mixamo"},
]

func _initialize() -> void:
	for c in CASES:
		if not ResourceLoader.exists(c["path"]):
			print("GAIT_MISSING ", c["key"])
			continue
		var inst: Node3D = load(c["path"]).instantiate()
		root.add_child(inst)
		await process_frame
		await _case(c, inst)
		inst.queue_free()
		await process_frame
	print("GAIT_DONE")
	quit(0)

func _case(c: Dictionary, inst: Node3D) -> void:
	var sk := _find_skel(inst)
	var ap := _find_ap(inst)
	if sk == null or ap == null or not ap.has_animation(c["clip"]):
		print("GAIT_SKIP ", c["key"])
		return
	var rig: String = c["rig"]
	var names := _names(rig)
	var an: Animation = ap.get_animation(c["clip"])
	an.loop_mode = Animation.LOOP_NONE
	ap.play(c["clip"])
	ap.speed_scale = 0.0
	var rest := {}
	for b in ["hips", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "foot.l", "foot.r", "toes.l", "toes.r"]:
		var bn: String = names.get(b, b)
		var bi := sk.find_bone(bn)
		if bi >= 0:
			rest[b] = (sk.global_transform.basis * sk.get_bone_global_pose(bi).basis).get_rotation_quaternion()
	var frames := 31
	var rows: Array[Dictionary] = []
	for i in frames:
		var t: float = an.length * float(i) / float(frames - 1)
		ap.seek(t, true)
		await process_frame
		var fl := _pos(sk, names["foot.l"])
		var fr := _pos(sk, names["foot.r"])
		var tl := _pos(sk, names["toes.l"])
		var tr := _pos(sk, names["toes.r"])
		var hips := _pos(sk, names["hips"])
		var ul := _pos(sk, names["upperleg.l"])
		var ur := _pos(sk, names["upperleg.r"])
		var hl := Vector3(ur.x - ul.x, 0.0, ur.z - ul.z)
		var body_fwd := Vector2.ZERO
		if hl.length() > 0.0001:
			var f := Vector3.UP.cross(hl.normalized())
			body_fwd = Vector2(f.x, f.z).normalized()
		var facing := _delta_fwd(sk, names["foot.l"], rest, "foot.l")
		var face_r := _delta_fwd(sk, names["foot.r"], rest, "foot.r")
		var toe_dir := Vector2.ZERO
		var td := tl - fl
		if Vector2(td.x, td.z).length() > 0.001:
			toe_dir = Vector2(td.x, td.z).normalized()
		rows.append({
			"t": t, "fl": fl, "fr": fr, "tl": tl, "tr": tr, "hips": hips,
			"facing": facing, "face_r": face_r, "toe": toe_dir,
			"hip_line": Vector2(ur.x - ul.x, ur.z - ul.z).normalized(),
			"body_fwd": body_fwd,
		})
	var total_root := sk.get_bone_global_pose(sk.find_bone(names["root"])).origin if sk.find_bone(names["root"]) >= 0 else Vector3.ZERO
	print("GAIT %s rig=%s clip=%s len=%.3f bones=%d skel_global=%s" % [c["key"], rig, c["clip"], an.length, sk.get_bone_count(), sk.global_transform])
	print("  root_pos=(%.3f,%.3f,%.3f) " % [total_root.x, total_root.y, total_root.z])
	for i in rows.size():
		var r: Dictionary = rows[i]
		print("  F%02d t=%.3f footL=(%+.3f,%+.3f,y%.3f) footR=(%+.3f,%+.3f,y%.3f) toe=(%+.2f,%+.2f) bootFwdL=(%+.2f,%+.2f) bootFwdR=(%+.2f,%+.2f) bodyFwd=(%+.2f,%+.2f)" % [
			i, r["t"], r["fl"].x, r["fl"].z, r["fl"].y, r["fr"].x, r["fr"].z, r["fr"].y,
			r["toe"].x, r["toe"].y, r["facing"].x, r["facing"].y, r["face_r"].x, r["face_r"].y,
			r["body_fwd"].x, r["body_fwd"].y])
	# Per-foot stance: frames where that foot is in the lower 20% of its own Y range.
	for side in ["fl", "fr"]:
		var ys: Array[float] = []
		for r in rows:
			ys.append(float(r[side].y))
		var lo: float = ys.min()
		var hi: float = ys.max()
		var thresh: float = lo + (hi - lo) * 0.22
		var mv := Vector2.ZERO
		var n := 0
		var contacts := 0
		for i in range(1, rows.size()):
			var a: Dictionary = rows[i - 1]
			var b: Dictionary = rows[i]
			if float(a[side].y) <= thresh and float(b[side].y) <= thresh:
				var pa: Vector3 = a[side]
				var pb: Vector3 = b[side]
				if a[side] != null:
					var d := Vector2(b[side].x - a[side].x, b[side].z - a[side].z)
					if d.length() > 0.0005:
						mv += d.normalized()
						n += 1
			if float(b[side].y) <= thresh:
				contacts += 1
		if n > 0:
			mv /= float(n)
		print("  STANCE %s y_range=[%.3f,%.3f] contact_frames=%d/%d avg_dir=(%+.2f,%+.2f) speed=%.4f m/frame" % [
			side, lo, hi, contacts, rows.size(), mv.x, mv.y, mv.length()])
	var body_avg := Vector2.ZERO
	for r in rows:
		body_avg += r["body_fwd"]
	body_avg = (body_avg / float(rows.size())).normalized()
	var boot_avg: Vector2 = (rows[0]["facing"] + rows[0]["face_r"]).normalized()
	print("  BODY body_fwd_avg=(%+.2f,%+.2f) yaw=%.1f deg | boot_fwd_first=(%+.2f,%+.2f) yaw=%.1f deg" % [
		body_avg.x, body_avg.y, _yaw(body_avg), boot_avg.x, boot_avg.y, _yaw(boot_avg)])
	var rel := ""
	for side in ["fl", "fr"]:
		var ys: Array[float] = []
		for r in rows:
			ys.append(float(r[side].y))
		var lo: float = ys.min()
		var hi: float = ys.max()
		var thresh: float = lo + (hi - lo) * 0.22
		var mv := Vector2.ZERO
		var n := 0
		for i in range(1, rows.size()):
			var a: Dictionary = rows[i - 1]
			var b: Dictionary = rows[i]
			if float(a[side].y) <= thresh and float(b[side].y) <= thresh:
				var d := Vector2(b[side].x - a[side].x, b[side].z - a[side].z)
				if d.length() > 0.0005:
					mv += d.normalized()
					n += 1
		if n > 0:
			mv /= float(n)
			rel += "%s stance_yaw=%.1f " % [side, _yaw(mv)]
	print("  STANCE_YAW %s (0=+Z,180=-Z) vs body_yaw=%.1f" % [rel, _yaw(body_avg)])

func _names(rig: String) -> Dictionary:
	if rig == "mixamo":
		return {
			"root": "mixamorig_Hips", "hips": "mixamorig_Hips",
			"upperleg.l": "mixamorig_LeftUpLeg", "upperleg.r": "mixamorig_RightUpLeg",
			"lowerleg.l": "mixamorig_LeftLeg", "lowerleg.r": "mixamorig_RightLeg",
			"foot.l": "mixamorig_LeftFoot", "foot.r": "mixamorig_RightFoot",
			"toes.l": "mixamorig_LeftToeBase", "toes.r": "mixamorig_RightToeBase",
		}
	return {
		"root": "root", "hips": "hips",
		"upperleg.l": "upperleg.l", "upperleg.r": "upperleg.r",
		"lowerleg.l": "lowerleg.l", "lowerleg.r": "lowerleg.r",
		"foot.l": "foot.l", "foot.r": "foot.r",
		"toes.l": "toes.l", "toes.r": "toes.r",
	}

func _yaw(v: Vector2) -> float:
	return rad_to_deg(atan2(v.x, v.y))

func _pos(sk: Skeleton3D, bone: String) -> Vector3:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(idx).origin

func _delta_fwd(sk: Skeleton3D, bone: String, rest: Dictionary, key: String) -> Vector2:
	var bi := sk.find_bone(bone)
	if bi < 0 or not rest.has(key):
		return Vector2.ZERO
	var q := (sk.global_transform.basis * sk.get_bone_global_pose(bi).basis).get_rotation_quaternion()
	var dq := q * (rest[key] as Quaternion).inverse()
	var f := Basis(dq) * Vector3(0, 0, 1)
	return Vector2(f.x, f.z).normalized()

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for ch in n.get_children():
		var r := _find_skel(ch)
		if r != null:
			return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for ch in n.get_children():
		var r := _find_ap(ch)
		if r != null:
			return r
	return null
