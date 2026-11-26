extends SceneTree

## T-023: prove that an original-Rogue clip can be grafted onto the smaller
## Action Forge rig by bone name (rest rotations match; position tracks scale
## by 0.8032).  Prints head/hips heights for idle vs walk.
## Usage: godot --headless --path action-forge-test/godot -s tools/test_graft.gd

const AF := "res://assets/Rogue_WalkLoop_AF_inplace.glb"
const ORIG := "res://assets/Rogue_original.glb"
const POS_SCALE := 0.8032

func _initialize() -> void:
	var target: Node3D = load(AF).instantiate()
	root.add_child(target)
	var source: Node3D = load(ORIG).instantiate()
	root.add_child(source)
	await process_frame
	var ta := _ap(target)
	var sa := _ap(source)
	var tsk := _skel(target)
	var target_prefix := ""
	var tan: Animation = ta.get_animation(ta.get_animation_list()[0])
	for i in tan.get_track_count():
		var p := str(tan.track_get_path(i))
		if p.contains(":"):
			target_prefix = p.get_slice(":", 0)
			break
	print("GRAFT target_prefix=%s target_clips=%s" % [target_prefix, ta.get_animation_list()])
	# graft Idle
	var src: Animation = sa.get_animation("Idle")
	var an: Animation = src.duplicate(true)
	var mapped := 0
	var skipped := 0
	for i in an.get_track_count():
		var p := str(an.track_get_path(i))
		var bone := p.get_slice(":", 1)
		if tsk.find_bone(bone) < 0:
			skipped += 1
			continue
		an.track_set_path(i, target_prefix + ":" + bone)
		if an.track_get_type(i) == Animation.TYPE_POSITION_3D:
			for k in an.track_get_key_count(i):
				an.track_set_key_value(i, k, an.track_get_key_value(i, k) * POS_SCALE)
		mapped += 1
	an.loop_mode = Animation.LOOP_LINEAR
	ta.get_animation_library("").add_animation("Idle_grafted", an)
	print("GRAFT idle tracks=%d mapped=%d skipped=%d len=%.3f" % [an.get_track_count(), mapped, skipped, an.length])
	ta.play("Idle_grafted")
	for t in [0.0, 0.5, 1.0, 1.5]:
		ta.seek(t, true)
		await process_frame
		print("GRAFT_IDLE t=%.2f head=(%.3f,%.3f,%.3f) hips=(%.3f,%.3f,%.3f) footL_y=%.3f footR_y=%.3f" % [
			t, _pos(tsk, "head").x, _pos(tsk, "head").y, _pos(tsk, "head").z,
			_pos(tsk, "hips").x, _pos(tsk, "hips").y, _pos(tsk, "hips").z,
			_pos(tsk, "foot.l").y, _pos(tsk, "foot.r").y])
	print("GRAFT_DONE")
	quit(0)

func _pos(sk: Skeleton3D, b: String) -> Vector3:
	var i := sk.find_bone(b)
	return sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.ZERO

func _skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D: return n as Skeleton3D
	for c in n.get_children():
		var r := _skel(c)
		if r: return r
	return null

func _ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n as AnimationPlayer
	for c in n.get_children():
		var r := _ap(c)
		if r: return r
	return null
