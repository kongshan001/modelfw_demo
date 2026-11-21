extends SceneTree

## One-off model inspection: bounds, bones, clips. Headless:
##   godot --headless --path . -s tools/inspect_models.gd

func _initialize() -> void:
	for path in [
		"res://assets/models/kaykit/Rogue.glb",
		"res://assets/models/kaykit/Rogue_Hooded.glb",
		"res://assets/models/kaykit/Mage.glb",
		"res://assets/models/kaykit/Knight.glb",
	]:
		var packed: PackedScene = load(path)
		if packed == null:
			print("MISSING ", path)
			continue
		var node: Node3D = packed.instantiate()
		root.add_child(node)
		var aabb := AABB()
		var first := true
		for mi in node.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi
			var box := m.global_transform * m.get_aabb()
			if first:
				aabb = box
				first = false
			else:
				aabb = aabb.merge(box)
		var skels := node.find_children("*", "Skeleton3D", true, false)
		var anim := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		print("MODEL %s aabb=%s bones=%d clips=%d" % [
			path.get_file(), str(aabb), (skels[0] as Skeleton3D).get_bone_count() if not skels.is_empty() else 0,
			anim.get_animation_list().size() if anim != null else 0])
		if anim != null:
			for clip in ["Idle", "Walking_A", "Running_A", "Unarmed_Idle",
					"Unarmed_Melee_Attack_Punch_A", "Unarmed_Melee_Attack_Punch_B",
					"Unarmed_Melee_Attack_Kick", "Dodge_Forward", "Dodge_Backward",
					"Hit_A", "Hit_B", "Lie_Down", "Lie_Idle", "Lie_StandUp", "Cheer",
					"Death_A", "Throw", "Interact", "Spellcast_Shoot",
					"1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Horizontal",
					"2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice", "2H_Melee_Attack_Spin"]:
				if anim.has_animation(clip):
					print("  CLIP %-38s %.2fs" % [clip, anim.get_animation(clip).length])
		if not skels.is_empty():
			var sk := skels[0] as Skeleton3D
			var names := PackedStringArray()
			for i in sk.get_bone_count():
				var n := sk.get_bone_name(i)
				if "hand" in n or "head" in n or "spine" in n:
					names.append(n)
			print("  BONES ", names)
		node.queue_free()
	quit(0)
