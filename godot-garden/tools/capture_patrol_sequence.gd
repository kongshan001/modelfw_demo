extends SceneTree

# 巡逻序列：90 帧，提灯人（KayKit Rogue）走近 → 驻足 → 折返，供验收与 GIF。
# 为看清步态，隐藏主角/妖灵，并给提灯人一条短往返路线（只改截图工具，不改游戏逻辑）。

const FRAMES := 90
const INTERVAL := 0.15
const CAM_POS := Vector3(1.5, 1.6, 8.4)
const LOOK_AT := Vector3(2.0, 1.0, 4.8)

func _initialize() -> void:
	var dir := "user://screenshots/patrol_seq"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".png"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/" + file))
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var scene = load("res://scenes/garden.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_time(18.3)
	scene.set_ui_visible(false)
	scene.set_film_camera(CAM_POS, LOOK_AT)

	var world = scene._world
	world.hero.visible = false
	world.hero.set_process(false)
	for monster in world.monsters:
		if is_instance_valid(monster):
			monster.visible = false
			monster.set_process(false)

	var npc = world.patrols[0]
	var demo_waypoints: Array[Vector3] = [Vector3(2.0, 0, 3.0), Vector3(2.0, 0, 5.6)]
	npc.waypoints = demo_waypoints
	npc.global_position = Vector3(2.0, 0, 3.0)
	npc.rotation.y = 0.0
	# 直接进入 WALK（force_pause(0) 会在下一帧把路点推进一格，导致先往反方向走）
	npc._walking = true
	npc._wp = 1
	npc._pause_timer = 0.0
	await create_timer(0.8).timeout
	for index in FRAMES:
		for node in world.find_children("*", "Label3D", true, false):
			if is_instance_valid(node):
				node.visible = false
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		image.save_png(dir + "/frame_%03d.png" % index)
		await create_timer(INTERVAL).timeout
	scene.queue_free()
	vp.queue_free()
	print("PATROL_SEQUENCE_OK frames=", FRAMES)
	quit(0)
