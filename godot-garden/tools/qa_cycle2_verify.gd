extends SceneTree

# QA 只读探针（Cycle 2）：核对 960×540/MSAA/线性过滤、灯笼右手挂点间隙、
# PAUSE 动画、模型尺寸与隐藏网格。不修改游戏逻辑，不改场景状态（结束后释放）。

func _initialize() -> void:
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(false)
	scene.set_time(18.4)

	var vp: SubViewport = scene._viewport
	print("VERIFY viewport=%s msaa_3d=%d ssaa=%d taa=%s display_filter=%d" % [
		str(vp.size), vp.msaa_3d, vp.screen_space_aa, str(vp.use_taa),
		scene._display.texture_filter])
	print("VERIFY texel=%s renderer=%s" % [
		str(scene._post_mat.get_shader_parameter("u_texel")),
		RenderingServer.get_video_adapter_name()])

	var lantern = scene._world.patrols[0]
	lantern.force_pause(5.0)
	await create_timer(0.6).timeout

	var hand_r: Node3D = lantern._hand_anchor
	var hand_l: Node3D = lantern._model_root.find_child("handslot_l", true, false)
	var rig: Node3D = lantern._lantern_rig
	var lamp_center: Vector3 = rig.global_position + Vector3.UP * GardenPatrol.ROGUE_LAMP_CENTER_HEIGHT
	print("VERIFY lantern anim=%s len=%.2f loop=%d playing_speed=%.2f player_speed=%.2f" % [
		str(lantern._model_player.current_animation),
		lantern._model_player.get_animation(lantern._model_player.current_animation).length,
		lantern._model_player.get_animation(lantern._model_player.current_animation).loop_mode,
		lantern._model_player.get_playing_speed(),
		lantern._model_player.speed_scale])
	print("VERIFY hands right_y=%.3f left_y=%.3f raised_right=%s" % [
		hand_r.global_position.y, hand_l.global_position.y,
		str(hand_r.global_position.y > hand_l.global_position.y)])
	print("VERIFY lantern rig=%s hand_r=%s gap_hand_rig=%.3f gap_hand_lamp=%.3f rig_offset_const=%s" % [
		str(rig.global_position.snapped(Vector3.ONE * 0.001)),
		str(hand_r.global_position.snapped(Vector3.ONE * 0.001)),
		rig.global_position.distance_to(hand_r.global_position),
		lamp_center.distance_to(hand_r.global_position),
		str(GardenPatrol.ROGUE_LANTERN_OFFSET)])

	var lantern_aabb := _model_aabb(lantern._model_root)
	print("VERIFY lantern model_aabb_size=%s height=%.3f" % [
		str(lantern_aabb.size.snapped(Vector3.ONE * 0.001)), lantern_aabb.size.y])
	_report_hidden(lantern._model_root, "lantern")

	var sweeper = scene._world.patrols[1]
	sweeper.force_pause(5.0)
	await create_timer(0.3).timeout
	var sweeper_aabb := _model_aabb(sweeper._model_root)
	print("VERIFY sweeper model_aabb_size=%s height=%.3f broom=%s broom_gap=%.3f" % [
		str(sweeper_aabb.size.snapped(Vector3.ONE * 0.001)), sweeper_aabb.size.y,
		str(sweeper._broom_rig != null),
		sweeper._broom_rig.global_position.distance_to(sweeper._hand_anchor.global_position)])
	_report_hidden(sweeper._model_root, "sweeper")

	var fox = scene._world.patrols[2]
	fox.force_pause(5.0)
	await create_timer(0.3).timeout
	var fox_aabb := _model_aabb(fox._model_root)
	print("VERIFY fox model_aabb_size=%s length=%.3f height=%.3f anim=%s" % [
		str(fox_aabb.size.snapped(Vector3.ONE * 0.001)),
		maxf(fox_aabb.size.x, fox_aabb.size.z), fox_aabb.size.y,
		str(fox._model_player.current_animation)])

	scene.focus_patrol(0)
	await create_timer(0.25).timeout
	var cam: Camera3D = scene._camera
	var target: Vector3 = lantern.global_position + Vector3(0, 1.0, 0)
	var dist: float = cam.global_position.distance_to(target)
	var pitch: float = rad_to_deg(asin((cam.global_position.y - target.y) / dist))
	print("VERIFY lantern_camera distance=%.2f pitch=%.1f pos=%s target=%s" % [
		dist, pitch, str(cam.global_position.snapped(Vector3.ONE * 0.01)),
		str(target.snapped(Vector3.ONE * 0.01))])

	scene.queue_free()
	await process_frame
	quit(0)

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
			var corner: Vector3 = local.get_endpoint(i)
			var point: Vector3 = xf * corner
			if first:
				out = AABB(point, Vector3.ZERO)
				first = false
			else:
				out = out.expand(point)
	return out

func _report_hidden(root: Node3D, label: String) -> void:
	var hidden: Array[String] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			hidden.append(String(mi.name))
	print("VERIFY %s hidden_meshes=%s" % [label, str(hidden)])
