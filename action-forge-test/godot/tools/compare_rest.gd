extends SceneTree

## T-023: compare rest pose (bone global transforms) of the AF export vs the
## original KayKit Rogue, to decide whether original/dance clips can be grafted
## onto the AF character by bone name.
## Usage: godot --headless --path action-forge-test/godot -s tools/compare_rest.gd

const A := "res://assets/Rogue_WalkLoop_AF_inplace.glb"
const B := "res://assets/Rogue_original.glb"

func _initialize() -> void:
	var a: Node3D = load(A).instantiate()
	var b: Node3D = load(B).instantiate()
	root.add_child(a)
	root.add_child(b)
	await process_frame
	var sa := _skel(a)
	var sb := _skel(b)
	var common := 0
	var max_pos := 0.0
	var max_rot := 0.0
	var worst := ""
	for i in sa.get_bone_count():
		var n := sa.get_bone_name(i)
		var j := sb.find_bone(n)
		if j < 0:
			continue
		common += 1
		var pa := sa.get_bone_global_pose(i).origin
		var pb := sb.get_bone_global_pose(j).origin
		var dp := pa.distance_to(pb)
		var qa := sa.get_bone_global_pose(i).basis.get_rotation_quaternion()
		var qb := sb.get_bone_global_pose(j).basis.get_rotation_quaternion()
		var dr := rad_to_deg(qa.angle_to(qb))
		if dp > max_pos or dr > max_rot:
			worst = n
		max_pos = maxf(max_pos, dp)
		max_rot = maxf(max_rot, dr)
	print("REST_COMPARE common=%d/%d max_pos=%.5f m max_rot=%.3f deg worst=%s" % [
		common, sa.get_bone_count(), max_pos, max_rot, worst])
	# Top-level scene transforms.
	print("REST_SCENE_A %s scl=%s" % [a.name, a.scale])
	print("REST_SCENE_B %s scl=%s" % [b.name, b.scale])
	# Total skinned mesh vertex counts for a quick fingerprint.
	var ma := 0
	var mb := 0
	for m in a.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh:
			ma += (m as MeshInstance3D).mesh.get_surface_count()
	for m in b.find_children("*", "MeshInstance3D", true, false):
		if (m as MeshInstance3D).mesh:
			mb += (m as MeshInstance3D).mesh.get_surface_count()
	print("REST_MESH surfaces_a=%d surfaces_b=%d" % [ma, mb])
	a.queue_free()
	b.queue_free()
	await process_frame
	print("REST_DONE")
	quit(0)

func _skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var r := _skel(c)
		if r != null:
			return r
	return null
