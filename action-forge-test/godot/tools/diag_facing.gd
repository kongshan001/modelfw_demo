extends SceneTree

## T-023 walk-direction diagnosis.
## Samples the rest pose and each animation at 9 phases and reports, in the
## skeleton's local space:
##   - toe_dir   : average foot -> toes vector (where the feet point)
##   - hip_right : upperleg.l -> upperleg.r (character right, or its mirror)
##   - facing    : right x up from the hip line (geometric body facing)
##   - root_step : the direction the root bone travels in the clip
##   - stance    : average horizontal motion of the lower foot while it is low
##                 (negated => implied travel direction of the body)
## If toe_dir and root_step point the same way the animation is forward-facing;
## if they are ~90/180 deg apart the clip is side/back-walking.
##
## Usage: godot --headless --path action-forge-test/godot -s tools/diag_facing.gd

const FILES := {
	"AF_WALK_INPLACE": "res://assets/Rogue_WalkLoop_AF_inplace.glb",
	"AF_WALK_ROOT": "res://assets/Rogue_WalkLoop_AF_rootmotion.glb",
	"AF_MICHELLE_WALK": "res://assets/Rogue_MichelleWalk_AF_inplace.glb",
	"ROGUE_ORIGINAL": "res://assets/Rogue_original.glb",
	"MICHELLE_SOURCE": "res://assets/Michelle_Walk_source.glb",
}
const CLIP := {
	"ROGUE_ORIGINAL": "Walking_A",
	"MICHELLE_SOURCE": "Animation",
}

func _initialize() -> void:
	for key in FILES:
		var path: String = FILES[key]
		if not ResourceLoader.exists(path):
			print("DIAG_MISSING %s %s" % [key, path])
			continue
		var inst: Node3D = load(path).instantiate()
		root.add_child(inst)
		await process_frame
		await _diag(key, inst)
		inst.queue_free()
		await process_frame
	print("DIAG_DONE")
	quit(0)

func _diag(key: String, inst: Node3D) -> void:
	var sk := _find_skel(inst)
	var ap := _find_ap(inst)
	if sk == null:
		print("DIAG %s NO_SKELETON" % key)
		return
	var chain := []
	var node: Node = inst
	while node != null:
		if node is Node3D:
			var n3 := node as Node3D
			chain.append("%s rot=(%.1f,%.1f,%.1f) pos=(%.3f,%.3f,%.3f) scl=(%.3f,%.3f,%.3f)" % [
				n3.name, n3.rotation_degrees.x, n3.rotation_degrees.y, n3.rotation_degrees.z,
				n3.position.x, n3.position.y, n3.position.z,
				n3.scale.x, n3.scale.y, n3.scale.z])
		node = node.get_parent()
	print("DIAG %s bones=%d" % [key, sk.get_bone_count()])
	for line in chain:
		print("  NODE %s" % line)
	var rl := _rest_line(sk)
	print("  REST %s" % rl)
	if ap == null:
		print("  NO_ANIM")
		return
	var clip_name := String(CLIP.get(key, ""))
	if clip_name == "" or not ap.has_animation(clip_name):
		clip_name = ap.get_animation_list()[0] if not ap.get_animation_list().is_empty() else ""
	if clip_name == "":
		print("  NO_CLIP")
		return
	var an: Animation = ap.get_animation(clip_name)
	an.loop_mode = Animation.LOOP_NONE
	ap.play(clip_name)
	ap.speed_scale = 0.0
	print("  CLIP %s len=%.4f tracks=%d" % [clip_name, an.length, an.get_track_count()])
	for ti in an.get_track_count():
		print("    TRACK %s %s" % [an.track_get_path(ti), an.track_get_type(ti)])
	var rest_rot := {}
	for b in ["hips", "spine", "chest", "head", "upperleg.l", "upperleg.r", "lowerleg.l", "lowerleg.r", "foot.l", "foot.r", "toes.l", "toes.r"]:
		var bi := sk.find_bone(b)
		if bi >= 0:
			rest_rot[b] = sk.get_bone_global_pose(bi).basis.get_rotation_quaternion()
	var samples: Array[Dictionary] = []
	var n := 9
	for i in n:
		var t := an.length * float(i) / float(n - 1)
		ap.seek(t, true)
		await process_frame
		var s := _sample(sk)
		s["t"] = t
		samples.append(s)
		var fl := _delta_fwd(sk, "foot.l", rest_rot)
		var fr := _delta_fwd(sk, "foot.r", rest_rot)
		var ul := _delta_fwd(sk, "upperleg.l", rest_rot)
		var ur := _delta_fwd(sk, "upperleg.r", rest_rot)
		print("  SAMPLE t=%.3f toe=(%.2f,%.2f) facing=(%.2f,%.2f) hips_yaw=%.1f | footL_fwd=(%.2f,%.2f) footR_fwd=(%.2f,%.2f) upperlegL=(%.2f,%.2f) upperlegR=(%.2f,%.2f) | root_z=%.3f" % [
			t, s["toe"].x, s["toe"].y, s["facing"].x, s["facing"].y, s["hips_yaw"],
			fl.x, fl.y, fr.x, fr.y, ul.x, ul.y, ur.x, ur.y, s["root"].z])
	# Root travel over the whole clip (skeleton space).
	var root_a: Vector3 = samples[0]["root"]
	var root_b: Vector3 = samples[-1]["root"]
	var root_step := Vector2(root_b.x - root_a.x, root_b.z - root_a.z)
	print("  ROOT_STEP (%.3f,%.3f) len=%.3f" % [root_step.x, root_step.y, root_step.length()])
	# Stance: for each interval use the lower foot in the middle sample.
	var stance := Vector2.ZERO
	var stance_n := 0
	for i in range(1, samples.size() - 1):
		var prev: Dictionary = samples[i - 1]
		var cur: Dictionary = samples[i]
		var side := "l" if float(cur["foot_l_y"]) <= float(cur["foot_r_y"]) else "r"
		var p: Vector2 = cur["foot_" + side]
		var q: Vector2 = prev["foot_" + side]
		stance += p - q
		stance_n += 1
	if stance_n > 0:
		stance /= float(stance_n)
	print("  STANCE_AVG (%.3f,%.3f)  implied_travel=(%.3f,%.3f)" % [
		stance.x, stance.y, -stance.x, -stance.y])
	var toe_avg := Vector2.ZERO
	var facing_avg := Vector2.ZERO
	var yaw_min := 999.0
	var yaw_max := -999.0
	for s in samples:
		toe_avg += s["toe"]
		facing_avg += s["facing"]
		yaw_min = minf(yaw_min, s["hips_yaw"])
		yaw_max = maxf(yaw_max, s["hips_yaw"])
	toe_avg = (toe_avg / float(samples.size())).normalized()
	facing_avg = (facing_avg / float(samples.size())).normalized()
	if stance.length() > 0.0001:
		var travel := (-stance).normalized()
		print("  ANGLES toe_vs_travel=%.1f deg facing_vs_travel=%.1f deg toe_vs_facing=%.1f deg hips_yaw_range=%.1f..%.1f" % [
			rad_to_deg(toe_avg.angle_to(travel)), rad_to_deg(facing_avg.angle_to(travel)),
			rad_to_deg(toe_avg.angle_to(facing_avg)), yaw_min, yaw_max])
	else:
		print("  ANGLES toe_vs_facing=%.1f deg hips_yaw_range=%.1f..%.1f" % [
			rad_to_deg(toe_avg.angle_to(facing_avg)), yaw_min, yaw_max])
	if root_step.length() > 0.0001:
		print("  ANGLES toe_vs_rootstep=%.1f deg facing_vs_rootstep=%.1f deg" % [
			rad_to_deg(toe_avg.angle_to(root_step.normalized())),
			rad_to_deg(facing_avg.angle_to(root_step.normalized()))])

func _delta_fwd(sk: Skeleton3D, bone: String, rest_rot: Dictionary) -> Vector2:
	var bi := sk.find_bone(bone)
	if bi < 0 or not rest_rot.has(bone):
		return Vector2.ZERO
	var q := sk.get_bone_global_pose(bi).basis.get_rotation_quaternion()
	var dq := q * (rest_rot[bone] as Quaternion).inverse()
	var f := Basis(dq) * Vector3(0, 0, 1)
	return Vector2(f.x, f.z).normalized()

func _rest_line(sk: Skeleton3D) -> String:
	var toe := _toe_dir(sk)
	var facing := _facing(sk)
	return "toe=(%.3f,%.3f) facing=(%.3f,%.3f) hips_yaw=%.1f" % [
		toe.x, toe.y, facing.x, facing.y, _hips_yaw(sk)]

func _bone_pos(sk: Skeleton3D, bone: String) -> Vector3:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return Vector3.ZERO
	return sk.get_bone_global_pose(idx).origin

func _bone_rot(sk: Skeleton3D, bone: String) -> Quaternion:
	var idx := sk.find_bone(bone)
	if idx < 0:
		return Quaternion.IDENTITY
	return sk.get_bone_global_pose(idx).basis.get_rotation_quaternion()

func _toe_dir(sk: Skeleton3D) -> Vector2:
	var v := Vector2.ZERO
	var n := 0
	for side in ["l", "r"]:
		var f := _bone_pos(sk, "foot." + side)
		var t := _bone_pos(sk, "toes." + side)
		var d := t - f
		d.y = 0.0
		if d.length() > 0.001:
			v += Vector2(d.x, d.z).normalized()
			n += 1
	if n == 0:
		return Vector2.ZERO
	return (v / float(n)).normalized()

func _facing(sk: Skeleton3D) -> Vector2:
	var l := _bone_pos(sk, "upperleg.l")
	var r := _bone_pos(sk, "upperleg.r")
	var right := Vector3(r.x - l.x, 0.0, r.z - l.z)
	if right.length() < 0.001:
		return Vector2.ZERO
	right = right.normalized()
	var up := Vector3.UP
	# upperleg.l -> upperleg.r points to the model's -X side, so right x up
	# yields -Z; use up x right for the +Z front of KayKit glTF characters.
	var fwd := up.cross(right).normalized()
	return Vector2(fwd.x, fwd.z)

func _hips_yaw(sk: Skeleton3D) -> float:
	var q := _bone_rot(sk, "hips")
	var fwd := Basis(q) * Vector3(0, 0, 1)
	return rad_to_deg(atan2(fwd.x, fwd.z))

func _sample(sk: Skeleton3D) -> Dictionary:
	var toe := _toe_dir(sk)
	var facing := _facing(sk)
	var root := _bone_pos(sk, "root")
	var rq := _bone_rot(sk, "root")
	var rf := Basis(rq) * Vector3(0, 0, 1)
	return {
		"toe": toe,
		"facing": facing,
		"hips_yaw": _hips_yaw(sk),
		"root": root,
		"root_yaw": rad_to_deg(atan2(rf.x, rf.z)),
		"foot_l_y": _bone_pos(sk, "foot.l").y,
		"foot_r_y": _bone_pos(sk, "foot.r").y,
		"foot_l": Vector2(_bone_pos(sk, "foot.l").x, _bone_pos(sk, "foot.l").z),
		"foot_r": Vector2(_bone_pos(sk, "foot.r").x, _bone_pos(sk, "foot.r").z),
	}

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null
