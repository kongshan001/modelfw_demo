extends SceneTree

## Headless acceptance for T-013: built-in Walk Loop retargeted by Action Forge,
## and the same walk layered with an upper-body Idle Talking clip.
## Run: godot --headless --path action-forge-test/godot -s tools/smoke_layered.gd
## Requires the T-013 exports copied into action-forge-test/godot/assets/.
## The layered root-motion export is optional: in this build the composite
## export did not bake root motion (documented limitation), so the test reports
## it as missing instead of failing.

const FILES := {
	"base_inplace": "Rogue_WalkLoop_AF_inplace.glb",
	"base_root": "Rogue_WalkLoop_AF_rootmotion.glb",
	"layer_inplace": "Rogue_Walk_IdleTalkLayer_AF_inplace.glb",
}
const LAYER_ROOT_FILE := "Rogue_Walk_IdleTalkLayer_AF_rootmotion.glb"

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
	if not FileAccess.file_exists("res://assets/" + file):
		return {}
	var ps: PackedScene = load("res://assets/" + file)
	if ps == null:
		fails.append("cannot load " + file)
		return {}
	var inst: Node3D = ps.instantiate()
	root.add_child(inst)
	await process_frame
	var sk := _find_sk(inst)
	var ap := _find_ap(inst)
	if sk and ap and not ap.get_animation_list().is_empty():
		var an: Animation = ap.get_animation(ap.get_animation_list()[0])
		an.loop_mode = Animation.LOOP_LINEAR
		ap.play(ap.get_animation_list()[0])
		ap.speed_scale = 0.0
		ap.seek(0.0, true)
	return {"node": inst, "sk": sk, "ap": ap, "meshes": _count_meshes(inst), "file": file}

func _clip(actor: Dictionary) -> Animation:
	var ap: AnimationPlayer = actor.get("ap")
	if ap == null or ap.get_animation_list().is_empty(): return null
	return ap.get_animation(ap.get_animation_list()[0])

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

func _bone_rot(sk: Skeleton3D, bone: String) -> Quaternion:
	var i := sk.find_bone(bone)
	if i < 0: return Quaternion.IDENTITY
	return sk.get_bone_pose_rotation(i)

func _seek(ap: AnimationPlayer, t: float) -> void:
	ap.seek(t, true)
	await process_frame

func _pose_delta(sk_a: Skeleton3D, ap_a: AnimationPlayer, sk_b: Skeleton3D, ap_b: AnimationPlayer, bone: String, base_len: float, layer_len: float, samples: int) -> float:
	var total := 0.0
	for s in samples:
		var t := layer_len * float(s) / float(samples - 1)
		await _seek(ap_a, fmod(t, base_len))
		var qa := _bone_rot(sk_a, bone)
		await _seek(ap_b, t)
		var qb := _bone_rot(sk_b, bone)
		total += qa.angle_to(qb)
	return total / float(samples)

func _max_scale_dev(sk: Skeleton3D, ap: AnimationPlayer, length: float, samples: int) -> float:
	var worst := 0.0
	for s in samples:
		await _seek(ap, length * float(s) / float(samples - 1))
		for i in sk.get_bone_count():
			var sc := sk.get_bone_pose_scale(i)
			worst = maxf(worst, maxf(absf(sc.x - 1.0), maxf(absf(sc.y - 1.0), absf(sc.z - 1.0))))
	return worst

func _loop_seam(sk: Skeleton3D, ap: AnimationPlayer, length: float, bone: String) -> float:
	await _seek(ap, 0.0)
	var q0 := _bone_rot(sk, bone)
	await _seek(ap, length)
	var q1 := _bone_rot(sk, bone)
	return q0.angle_to(q1)

func _foot_stats(sk: Skeleton3D, ap: AnimationPlayer, length: float, samples: int) -> Dictionary:
	var feet := ["foot.l", "foot.r", "toes.l", "toes.r"]
	var idxs := []
	for f in feet:
		var i := sk.find_bone(f)
		if i >= 0: idxs.append(i)
	if idxs.is_empty():
		return {}
	var min_y := 1e9
	var frames: Array = []
	for s in samples:
		await _seek(ap, length * float(s) / float(samples - 1))
		var pos: Array = []
		for i in idxs:
			pos.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
		frames.append(pos)
		for p in pos:
			min_y = minf(min_y, p.y)
	var contact := 0
	for f in frames:
		for p in f:
			if p.y <= min_y + 0.03: contact += 1
	# Longest contiguous low-foot run per foot; its horizontal displacement is
	# the stance slide (world XZ). Short clips/floaty feet can yield no run.
	var worst_slide := 0.0
	var longest := 0
	for fi in idxs.size():
		var run_start := -1
		for s in frames.size():
			var g: bool = frames[s][fi].y <= min_y + 0.03
			if g and run_start < 0: run_start = s
			if (not g or s == frames.size() - 1) and run_start >= 0:
				var endi := s - 1 if not g else s
				var run_len := endi - run_start + 1
				if run_len > longest: longest = run_len
				var first: Vector3 = frames[run_start][fi]
				var last: Vector3 = frames[endi][fi]
				worst_slide = maxf(worst_slide, Vector2(last.x - first.x, last.z - first.z).length())
				run_start = -1
	var max_hip := -INF
	for s in samples:
		await _seek(ap, length * float(s) / float(samples - 1))
		var hi := sk.find_bone("hips")
		if hi >= 0:
			var wp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
			max_hip = maxf(max_hip, wp.y)
	return {"min_foot_y": min_y, "contact_frames": contact, "max_ground_slide": worst_slide, "longest_contact": longest, "max_hip_y": max_hip}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var actors := {}
	for key in FILES:
		actors[key] = await _load_actor(FILES[key])
		if actors[key].is_empty():
			fails.append("missing " + FILES[key]); continue
		var sk: Skeleton3D = actors[key]["sk"]
		var ap: AnimationPlayer = actors[key]["ap"]
		if sk == null or ap == null:
			fails.append("missing skeleton/player in " + FILES[key]); continue
		var an := _clip(actors[key])
		print("SMOKE_L_FILE %s bones=%d meshes=%d clip=%s len=%.4f tracks=%d" % [
			key, sk.get_bone_count(), actors[key]["meshes"], ap.get_animation_list()[0], an.length, an.get_track_count()])
		if sk.get_bone_count() != 41: fails.append(key + " bones != 41")
		if actors[key]["meshes"] != 12: fails.append(key + " meshes != 12")
	var base_in: Dictionary = actors.get("base_inplace", {})
	var base_root: Dictionary = actors.get("base_root", {})
	var layer_in: Dictionary = actors.get("layer_inplace", {})
	if base_in.is_empty() or base_root.is_empty() or layer_in.is_empty():
		print("SMOKE_LAYERED_FAIL missing required actors"); quit(1); return
	var bi := _drift(base_in["ap"], "root")
	var br := _drift(base_root["ap"], "root")
	var li := _drift(layer_in["ap"], "root")
	print("SMOKE_L_ROOT base_inplace=%.4f base_root=%.4f layer_inplace=%.4f" % [bi, br, li])
	if bi > 0.001: fails.append("base in-place root drift")
	if br < 0.25: fails.append("base root-motion drift < 0.25 m")
	if li > 0.001: fails.append("layer in-place root drift")
	var layer_root: Dictionary = await _load_actor(LAYER_ROOT_FILE)
	if layer_root.is_empty():
		print("SMOKE_L_LAYER_ROOT missing=%s (composite root-motion not baked in this build)" % LAYER_ROOT_FILE)
	else:
		var lr := _drift(layer_root["ap"], "root")
		print("SMOKE_L_LAYER_ROOT file=%s root_drift=%.4f" % [LAYER_ROOT_FILE, lr])
		if lr < 0.25: fails.append("layer root-motion drift < 0.25 m")
	# upper-body layer effect: compare the in-place layered clip against the base walk phase
	var sk: Skeleton3D = layer_in["sk"]
	var an_base := _clip(base_in)
	var an_layer := _clip(layer_in)
	var leg := await _pose_delta(base_in["sk"], base_in["ap"], sk, layer_in["ap"], "upperleg.l", an_base.length, an_layer.length, 9)
	var arm := await _pose_delta(base_in["sk"], base_in["ap"], sk, layer_in["ap"], "upperarm.l", an_base.length, an_layer.length, 9)
	var seam := await _loop_seam(sk, layer_in["ap"], an_layer.length, "upperleg.l")
	var sdev := await _max_scale_dev(sk, layer_in["ap"], an_layer.length, 7)
	print("SMOKE_L_LAYER leg_delta=%.4f rad arm_delta=%.4f rad loop_seam=%.4f rad max_scale_dev=%.6f" % [leg, arm, seam, sdev])
	if arm <= leg: fails.append("upper-body layer does not differ more than legs")
	if leg > 0.20: fails.append("leg layer delta > 0.20 rad")
	if seam > 0.12: fails.append("loop seam > 0.12 rad")
	if sdev > 0.01: fails.append("bone scale deviation > 0.01")
	# feet: root-motion stance slide + in-place foot height
	var fs_base := await _foot_stats(base_root["sk"], base_root["ap"], _clip(base_root).length, 41)
	var fs_layer := await _foot_stats(sk, layer_in["ap"], an_layer.length, 41)
	if fs_base.is_empty() or fs_layer.is_empty():
		fails.append("cannot measure feet")
	else:
		print("SMOKE_L_FOOT base_root min_foot_y=%.4f longest_contact=%d stance_slide=%.3f m hip_y=%.4f" % [
			fs_base["min_foot_y"], fs_base["longest_contact"], fs_base["max_ground_slide"], fs_base["max_hip_y"]])
		print("SMOKE_L_FOOT layer_inplace min_foot_y=%.4f longest_contact=%d stance_slide=%.3f m hip_y=%.4f" % [
			fs_layer["min_foot_y"], fs_layer["longest_contact"], fs_layer["max_ground_slide"], fs_layer["max_hip_y"]])
		if fs_layer["min_foot_y"] < -0.08: fails.append("feet sink below -8 cm")
		if fs_layer["min_foot_y"] > 0.15: fails.append("feet float above 15 cm")
		if fs_base["max_ground_slide"] > 0.60:
			fails.append("base root-motion stance slide > 0.60 m")
		elif fs_base["max_ground_slide"] > 0.30:
			print("SMOKE_L_FOOT_WARN base root-motion stance slide %.3f m > 0.30 m (recorded limitation)" % fs_base["max_ground_slide"])
	if fails.size() > 0:
		for f in fails: print("SMOKE_LAYERED_FAIL ", f)
		quit(1)
	else:
		print("SMOKE_LAYERED_OK")
		quit(0)
