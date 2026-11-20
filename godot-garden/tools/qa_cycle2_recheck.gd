extends SceneTree

# QA Cycle 2 复审只读探针：实测灯笼挂点距离 / Spellcast 播放倍速 / 狐狸 AABB 与朝向 /
# 扫帚触地高度 / 光晕参数 / 近景机位。不修改游戏逻辑，只读场景实例，结束释放。

const LAMP := 0
const SWEEPER := 1
const FOX := 2

func _initialize() -> void:
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(18.4)

	var vp: SubViewport = scene._viewport
	print("RECHECK viewport=%s msaa_3d=%d ssaa=%d display_filter=%d" % [
		str(vp.size), vp.msaa_3d, vp.screen_space_aa, scene._display.texture_filter])

	await _check_lantern(scene)
	await _check_sweeper(scene)
	await _check_fox(scene)
	await _check_camera(scene)

	scene.queue_free()
	await process_frame
	quit(0)

func _check_lantern(scene) -> void:
	var lantern = scene._world.patrols[LAMP]
	lantern.force_pause(10.0)
	await create_timer(0.8).timeout

	var hand_r: Node3D = lantern._hand_anchor
	var hand_l: Node3D = lantern._model_root.find_child("handslot_l", true, false)
	var rig: Node3D = lantern._lantern_rig
	var ap: AnimationPlayer = lantern._model_player
	var anim := ap.current_animation
	var anim_res := ap.get_animation(anim)
	var lamp_center: Vector3 = rig.global_position \
		+ Vector3.UP * GardenPatrol.ROGUE_LAMP_CENTER_HEIGHT

	print("RECHECK lantern anim=%s len=%.3f loop=%d is_playing=%s get_playing_speed=%.3f speed_scale=%.3f" % [
		anim, anim_res.length, anim_res.loop_mode, str(ap.is_playing()),
		ap.get_playing_speed(), ap.speed_scale])
	print("RECHECK lantern hand_r_y=%.3f hand_l_y=%.3f raised=%s" % [
		hand_r.global_position.y, hand_l.global_position.y,
		str(hand_r.global_position.y > hand_l.global_position.y)])
	print("RECHECK lantern rig=%s hand_r=%s gap_hand_rig=%.4f gap_hand_lamp=%.4f offset=%s" % [
		str(rig.global_position.snapped(Vector3.ONE * 0.001)),
		str(hand_r.global_position.snapped(Vector3.ONE * 0.001)),
		rig.global_position.distance_to(hand_r.global_position),
		lamp_center.distance_to(hand_r.global_position),
		str(GardenPatrol.ROGUE_LANTERN_OFFSET)])

	# 实测 1s 内动画位置增量，独立验证倍速（不只看 get_playing_speed）
	var pos0 := ap.current_animation_position
	await create_timer(1.0).timeout
	var advance := ap.current_animation_position - pos0
	if advance < 0.0:
		advance += anim_res.length
	print("RECHECK lantern anim_advance_1s=%.3f expected_1.3x=1.300 speed=%.3f anim_now=%s" % [
		advance, ap.get_playing_speed(), ap.current_animation])

	var core = lantern._lantern_halo_core
	var outer = lantern._lantern_halo_outer
	var far = lantern._lantern_halo_far
	var tex_w := 0.0
	if outer != null and outer.texture != null:
		tex_w = float(outer.texture.get_width())
	print("RECHECK lantern halo_core=%s halo_outer=%s halo_far=%s light_range=%.2f light_energy=%.3f" % [
		_halo_desc(core), _halo_desc(outer), _halo_desc(far),
		lantern._lantern_light.omni_range, lantern._lantern_light.light_energy])
	if outer != null:
		print("RECHECK lantern halo_outer_world_m=%.3f core_world_m=%.3f tex_w=%.1f pixel_size=%.3f" % [
			outer.scale.x * tex_w * outer.pixel_size,
			core.scale.x * tex_w * core.pixel_size, tex_w, outer.pixel_size])

	# 行走态再测一次挂点间隙
	lantern._walking = true
	await create_timer(0.3).timeout
	print("RECHECK lantern walking gap_hand_rig=%.4f gap_hand_lamp=%.4f anim=%s speed=%.2f" % [
		lantern._lantern_rig.global_position.distance_to(hand_r.global_position),
		(lantern._lantern_rig.global_position + Vector3.UP * GardenPatrol.ROGUE_LAMP_CENTER_HEIGHT).distance_to(hand_r.global_position),
		ap.current_animation, ap.get_playing_speed()])
	lantern._walking = false
	lantern.force_pause(10.0)

func _check_sweeper(scene) -> void:
	var sweeper = scene._world.patrols[SWEEPER]
	sweeper.force_pause(10.0)
	await create_timer(0.5).timeout
	var hand: Node3D = sweeper._hand_anchor
	print("RECHECK sweeper hand_y=%.3f broom_rig=%s gap_hand_broom=%.4f anim=%s speed=%.2f" % [
		hand.global_position.y,
		str(sweeper._broom_rig.global_position.snapped(Vector3.ONE * 0.001)),
		sweeper._broom_rig.global_position.distance_to(hand.global_position),
		sweeper._model_player.current_animation,
		sweeper._model_player.get_playing_speed()])

	# 驻足摆动 1.2s 采样最低点
	var low_pause := 999.0
	var high_pause := -999.0
	for i in 12:
		await create_timer(0.1).timeout
		var y := _min_world_y(sweeper._broom_rig)
		low_pause = minf(low_pause, y)
		high_pause = maxf(high_pause, y)
	print("RECHECK sweeper broom_bottom_pause min_y=%.3f max_y=%.3f (ground=0)" % [
		low_pause, high_pause])

	# 行走斜握
	sweeper._walking = true
	await create_timer(0.2).timeout
	print("RECHECK sweeper broom_bottom_walk min_y=%.3f tilt=%.2f" % [
		_min_world_y(sweeper._broom_rig), sweeper._broom_rig.global_rotation.x])
	sweeper._walking = false
	sweeper.force_pause(10.0)

func _check_fox(scene) -> void:
	var fox = scene._world.patrols[FOX]
	fox.force_pause(10.0)
	await create_timer(0.3).timeout
	# 固定到 Walk 姿态，避免 Survey 扭头影响朝向测量（与截图工具同做法）
	if fox._model_player != null and fox._model_player.has_animation("Walk"):
		fox._anim_state = "pause"
		fox._model_player.play("Walk", 0.0)
		fox._model_player.seek(0.2, true)
	await process_frame
	await process_frame

	var aabb := _model_aabb(fox._model_root)
	print("RECHECK fox aabb_size=%s length=%.3f height=%.3f yaw_root=%.3f model_root_yaw=%.3f scale=%s" % [
		str(aabb.size.snapped(Vector3.ONE * 0.001)),
		maxf(aabb.size.x, aabb.size.z), aabb.size.y,
		fox.rotation.y, fox._model_root.rotation.y,
		str(fox._model_root.scale.snapped(Vector3.ONE * 0.0001))])

	var skel := _find_skeleton(fox._model_root)
	if skel == null:
		print("RECHECK fox NO_SKELETON")
		return
	skel.force_update_all_bone_transforms()
	var head := _bone_world(skel, "b_Head_05")
	var neck := _bone_world(skel, "b_Neck_04")
	var hip := _bone_world(skel, "b_Hip_01")
	var tail := _bone_world(skel, "b_Tail_01")
	var model_plus_z: Vector3 = fox._model_root.global_transform.basis.z.normalized()
	var root_minus_z: Vector3 = -fox.global_transform.basis.z.normalized()
	var hip_head := _flat_dir(hip, head)
	var neck_head := _flat_dir(neck, head)
	var hip_tail := _flat_dir(hip, tail)
	print("RECHECK fox dirs model_plusZ=%s root_minusZ=%s angle_model_vs_root=%.2f deg" % [
		str(model_plus_z.snapped(Vector3.ONE * 0.001)),
		str(root_minus_z.snapped(Vector3.ONE * 0.001)),
		rad_to_deg(model_plus_z.angle_to(root_minus_z))])
	print("RECHECK fox dirs dot(hip->head,model+Z)=%.4f dot(hip->head,root-Z)=%.4f dot(neck->head,model+Z)=%.4f dot(hip->tail,model+Z)=%.4f" % [
		hip_head.dot(model_plus_z), hip_head.dot(root_minus_z),
		neck_head.dot(model_plus_z), hip_tail.dot(model_plus_z)])
	print("RECHECK fox bones head=%s hip=%s tail=%s" % [
		str(head.snapped(Vector3.ONE * 0.001)),
		str(hip.snapped(Vector3.ONE * 0.001)),
		str(tail.snapped(Vector3.ONE * 0.001))])

func _check_camera(scene) -> void:
	scene.focus_patrol(0)
	await create_timer(0.25).timeout
	var cam: Camera3D = scene._camera
	var lantern = scene._world.patrols[LAMP]
	var target: Vector3 = lantern.global_position + Vector3(0, 1.0, 0)
	var dist: float = cam.global_position.distance_to(target)
	var pitch: float = rad_to_deg(asin((cam.global_position.y - target.y) / dist))
	print("RECHECK camera distance=%.2f pitch=%.1f pos=%s target=%s" % [
		dist, pitch, str(cam.global_position.snapped(Vector3.ONE * 0.01)),
		str(target.snapped(Vector3.ONE * 0.01))])

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _halo_desc(halo) -> String:
	if halo == null:
		return "null"
	return "scale=%.2f a=%.2f vis=%s" % [halo.scale.x, halo.modulate.a, str(halo.visible)]

func _bone_world(skel: Skeleton3D, bone_name: String) -> Vector3:
	var index := skel.find_bone(bone_name)
	if index < 0:
		return Vector3.INF
	return skel.global_transform * skel.get_bone_global_pose(index).origin

func _flat_dir(from: Vector3, to: Vector3) -> Vector3:
	var d := to - from
	d.y = 0.0
	return d.normalized()

func _min_world_y(root: Node3D) -> float:
	var lowest := INF
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var local: AABB = mi.get_aabb()
		var xf: Transform3D = mi.global_transform
		for i in 8:
			lowest = minf(lowest, (xf * local.get_endpoint(i)).y)
	return lowest

func _model_aabb(root: Node3D) -> AABB:
	var first := true
	var out := AABB()
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var local: AABB = mi.get_aabb()
		var xf: Transform3D = mi.global_transform
		for i in 8:
			var point: Vector3 = xf * local.get_endpoint(i)
			if first:
				out = AABB(point, Vector3.ZERO)
				first = false
			else:
				out = out.expand(point)
	return out
