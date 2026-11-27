extends SceneTree

## Headless acceptance for the MediaPipe fast-mode reproduction → Rogue GLB.
## Run: godot --headless --path blender-mocap-plugin-test/godot -s tools/smoke.gd

const FILES := {
	"raw": "Rogue_MediaPipe_walk.glb",
	"simplified": "Rogue_MediaPipe_walk_simplified.glb",
}

var fails: Array[String] = []

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

func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var ps: PackedScene = load(path)
	if ps == null:
		fails.append("load " + path)
		return {}
	var inst: Node = ps.instantiate()
	root.add_child(inst)
	await process_frame
	var sk: Skeleton3D = _find(inst, "Skeleton3D")
	var ap: AnimationPlayer = _find(inst, "AnimationPlayer")
	if sk == null or ap == null or ap.get_animation_list().is_empty():
		fails.append("missing skeleton/animation " + path)
		return {}
	var name: String = str(ap.get_animation_list()[0])
	var an := ap.get_animation(name)
	an.loop_mode = Animation.LOOP_LINEAR
	ap.play(name)
	ap.speed_scale = 0.0
	ap.seek(0.0, true)
	return {"inst": inst, "sk": sk, "ap": ap, "name": name, "anim": an,
		"bones": sk.get_bone_count(), "meshes": _count_meshes(inst), "len": an.length,
		"tracks": an.get_track_count()}

func _root_drift(ap: AnimationPlayer) -> float:
	var an: Animation = ap.get_animation(ap.get_animation_list()[0])
	for t in an.get_track_count():
		if an.track_get_type(t) != Animation.TYPE_POSITION_3D: continue
		if not str(an.track_get_path(t)).ends_with(":hips"): continue
		var mn := Vector3(INF, INF, INF); var mx := Vector3(-INF, -INF, -INF)
		for k in an.track_get_key_count(t):
			var v: Vector3 = an.track_get_key_value(t, k)
			mn = mn.min(v); mx = mx.max(v)
		return Vector2(mx.x - mn.x, mx.z - mn.z).length()
	return -1.0

func _bone_rot(sk: Skeleton3D, name: String) -> Quaternion:
	var i := sk.find_bone(name)
	return Quaternion.IDENTITY if i < 0 else sk.get_bone_pose_rotation(i)

func _seek(ap: AnimationPlayer, t: float) -> void:
	ap.seek(t, true)
	await process_frame

func _measure(a: Dictionary) -> Dictionary:
	var sk: Skeleton3D = a.sk
	var ap: AnimationPlayer = a.ap
	var length: float = a.len
	var feet := ["foot.l", "foot.r", "toes.l", "toes.r"]
	var idxs := []
	for f in feet:
		var i := sk.find_bone(f)
		if i >= 0: idxs.append(i)
	var samples := 90
	var min_y := 1e9
	var frames: Array = []
	var hip_min := 1e9; var hip_max := -1e9
	for s in samples:
		await _seek(ap, length * float(s) / float(samples - 1))
		var pos: Array = []
		for i in idxs:
			pos.append(sk.global_transform * sk.get_bone_global_pose(i).origin)
		frames.append(pos)
		for p in pos: min_y = minf(min_y, p.y)
		var hi := sk.find_bone("hips")
		if hi >= 0:
			var hp: Vector3 = sk.global_transform * sk.get_bone_global_pose(hi).origin
			hip_min = minf(hip_min, hp.y); hip_max = maxf(hip_max, hp.y)
	var longest := 0; var worst := 0.0
	for fi in idxs.size():
		var run := -1
		for s in frames.size():
			var g: bool = frames[s][fi].y <= min_y + 0.03
			if g and run < 0: run = s
			if (not g or s == frames.size() - 1) and run >= 0:
				var endi := s - 1 if not g else s
				longest = maxi(longest, endi - run + 1)
				var p0: Vector3 = frames[run][fi]; var p1: Vector3 = frames[endi][fi]
				worst = maxf(worst, Vector2(p1.x - p0.x, p1.z - p0.z).length())
				run = -1
	var scale_dev := 0.0
	for s in 7:
		await _seek(ap, length * float(s) / 6.0)
		for i in sk.get_bone_count():
			var sc := sk.get_bone_pose_scale(i)
			scale_dev = maxf(scale_dev, maxf(absf(sc.x - 1.0), maxf(absf(sc.y - 1.0), absf(sc.z - 1.0))))
	await _seek(ap, 0.0)
	var q0 := _bone_rot(sk, "hips")
	await _seek(ap, length)
	var q1 := _bone_rot(sk, "hips")
	return {"min_foot_y": min_y, "longest_contact": longest, "stance_slide": worst,
		"hip_y_range": hip_max - hip_min, "scale_dev": scale_dev,
		"loop_seam_deg": rad_to_deg(q0.angle_to(q1)), "root_xz": _root_drift(ap)}

func _init() -> void:
	for key in FILES:
		var path: String = "res://assets/" + str(FILES[key])
		if not FileAccess.file_exists(path):
			if key == "simplified":
				print("SMOKE_SKIP simplified (not built yet)")
				continue
			fails.append("missing " + FILES[key])
			continue
		var a: Dictionary = await _load(path)
		if a.is_empty(): continue
		print("SMOKE_FILE %s bones=%d meshes=%d clip=%s len=%.4f tracks=%d root_xz=%.4f" % [
			key, a.bones, a.meshes, a.name, a.len, a.tracks, _root_drift(a.ap)])
		if a.bones != 41: fails.append(key + " bones != 41")
		if a.meshes != 12: fails.append(key + " meshes != 12")
		if absf(a.len - 4.9333) > 0.03: fails.append(key + " len != 4.9333")
		var m: Dictionary = await _measure(a)
		print("SMOKE_FOOT %s min_foot_y=%.4f longest=%d stance_slide=%.4f hip_y_range=%.4f scale_dev=%.6f loop_seam=%.3fdeg" % [
			key, m.min_foot_y, m.longest_contact, m.stance_slide, m.hip_y_range, m.scale_dev, m.loop_seam_deg])
		if m.scale_dev > 1e-5: fails.append(key + " bone scale drift")
		if m.min_foot_y < -0.05: fails.append(key + " foot below -5cm")
		if m.stance_slide > 0.60: fails.append(key + " stance slide > 0.60m")
	if fails.is_empty():
		print("MOCAP_SMOKE_OK")
	else:
		for f in fails: print("SMOKE_FAIL " + f)
		print("MOCAP_SMOKE_FAIL")
	quit()
