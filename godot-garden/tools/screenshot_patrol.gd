extends SceneTree

# 巡逻角色截图矩阵：黄昏/夜间近景、默认广角、960×540 源画面、混合阵营、扫园人/小狐。
# 只做截图，不改游戏逻辑。

var _viewport: SubViewport
var _scene

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/garden.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	_scene.set_autoplay(false)
	_scene.set_ui_visible(false)

	_scene.set_time(18.2)
	await create_timer(2.0).timeout
	await _capture("patrol_wide_dusk.png")

	# 同机位无巡逻，用于前后对比
	_scene.toggle_feature("patrols")
	await create_timer(0.4).timeout
	await _capture("patrol_wide_dusk_off.png")
	_scene.toggle_feature("patrols")

	# 石圈对侧定点机位：扫园人有/无
	var sweeper = _scene._world.patrols[1]
	var sweeper_pos: Vector3 = sweeper.global_position
	var compare_cam := Vector3(16.0 - sweeper_pos.x, 2.4, 10.0 - sweeper_pos.z)
	_scene.set_film_camera(compare_cam, sweeper_pos + Vector3(0, 0.85, 0))
	await create_timer(0.6).timeout
	await _capture("patrol_compare_on.png")
	_scene.toggle_feature("patrols")
	await create_timer(0.25).timeout
	await _capture("patrol_compare_off.png")
	_scene.toggle_feature("patrols")
	_scene.clear_film_camera()

	# 提灯人近景（16°/5.8，验收姿态朝机位）
	_scene._world.hero.visible = false
	if _scene._world.octopus != null:
		_scene._world.octopus.visible = false
	_scene.toggle_feature("fireflies")
	for m in _scene._world.monsters:
		if is_instance_valid(m):
			m.visible = false
	var lantern = _scene._world.patrols[0]
	lantern.global_position = Vector3(2.2, 0.0, 3.2)
	_scene.set_film_camera(Vector3(5.7, 1.55, 6.2), Vector3(2.2, 1.0, 3.2))
	_scene.exposure_override = 1.0
	_scene._env.fog_enabled = false
	await create_timer(0.3).timeout
	lantern.force_pause(8.0)
	if lantern._model_player != null:
		lantern._model_player.seek(0.35, true)
		lantern._model_player.pause()
	await create_timer(0.15).timeout
	lantern.halos_forced_off = true
	lantern.set_process(false)
	if lantern._model_player != null:
		lantern._model_player.pause()
		lantern._model_player.speed_scale = 0.0
	# 冻结后手动关掉所有光晕，避免 set_night 重新点亮
	for prop in ["_lantern_halo_core", "_lantern_halo_outer", "_lantern_halo_far", "_lantern_halo_wide", "_lantern_halo_core_wide"]:
		var node = lantern.get(prop)
		if node != null:
			node.visible = false
	_scene.set_time(18.4)
	await create_timer(0.8).timeout
	_face_patrol_to_camera(_scene, lantern)
	await create_timer(0.8).timeout
	await _capture("patrol_lantern_dusk.png")
	await _capture_internal("cycle2_960x540.png")

	_scene.set_time(0.0)
	await create_timer(1.6).timeout
	await _capture("patrol_lantern_night.png")
	_scene.set_ui_visible(true)
	await create_timer(0.4).timeout
	await _capture("cycle3_ui_pause.png")
	_scene.set_ui_visible(false)

	# 默认广角：正午 / 深夜
	lantern.set_process(true)
	_scene.clear_film_camera()
	_scene._patrol_focus = -1
	_scene.set_time(12.0)
	await create_timer(1.2).timeout
	await _capture("cycle1_noon.png")
	# 广角夜景：把提灯人放到远离路灯的池南岸，单独验证手持灯识别
	var lant_wide = _scene._world.patrols[0]
	lant_wide.global_position = Vector3(-5.0, 0.0, -4.0)
	lant_wide.force_pause(8.0)
	_scene.set_time(0.0)
	await create_timer(1.2).timeout
	await _capture("cycle1_wide_night.png")
	_scene.toggle_feature("lamps")
	await create_timer(0.4).timeout
	await _capture("cycle3_lantern_only.png")
	_scene.toggle_feature("lamps")

	# 扫园人 / 小狐近景
	_scene._world.patrols[1].force_pause(8.0)
	_scene.focus_patrol(1)
	_scene.set_time(17.9)
	await create_timer(1.6).timeout
	await _capture("patrol_sweeper.png")

	var fox = _scene._world.patrols[2]
	fox.global_position = Vector3(7.4, 0.0, 4.4)
	fox.rotation.y = _face_from(fox.global_position, Vector3(5.3, 1.3, 6.8))
	fox.force_pause(12.0)
	if fox._model_player != null:
		fox._anim_state = "pause"
		fox._model_player.play("Walk", 0.2)
		fox._model_player.seek(0.35, true)
	_scene.set_film_camera(Vector3(5.3, 1.3, 6.8), fox.global_position + Vector3(0, 0.5, 0))
	await create_timer(1.4).timeout
	await _capture("patrol_fox.png")

	# 混合阵营：KayKit Rogue + 程序化扫园人 + 程序化小女孩
	await _stage_mixed_cast()
	await create_timer(1.2).timeout
	await _capture("cycle2_mixed_cast.png")

	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _stage_mixed_cast() -> void:
	var world = _scene._world
	for monster in world.monsters:
		if is_instance_valid(monster):
			monster.visible = false
			monster.set_process(false)
	var cam := Vector3(6.6, 1.7, 7.0)
	var hero = world.hero
	hero.set_process(false)
	hero.global_position = Vector3(2.9, 0.0, 3.0)
	hero.rotation.y = _face_from(hero.global_position, cam)
	var hero_model = hero.get_node_or_null("HeroModel")
	if hero_model != null:
		hero_model.walking = false

	var lantern = world.patrols[0]
	lantern.global_position = Vector3(2.2, 0.0, 3.2)
	lantern.rotation.y = _face_from(lantern.global_position, cam) + 0.35
	lantern.force_pause(10.0)

	var sweeper = world.patrols[1]
	sweeper.global_position = Vector3(1.2, 0.0, 4.5)
	sweeper.rotation.y = _face_from(sweeper.global_position, cam)
	sweeper.force_pause(10.0)

	if world.octopus != null:
		world.octopus.visible = false
	_scene.set_film_camera(cam, Vector3(2.2, 1.0, 3.8))

func _face_patrol_to_camera(scene, npc) -> void:
	var cam: Camera3D = scene._camera
	npc.rotation.y = _face_from(npc.global_position, cam.global_position) - 0.5

func _face_from(pos: Vector3, target: Vector3) -> float:
	var to_target := target - pos
	return atan2(-to_target.x, -to_target.z)

func _hide_floaters() -> void:
	if _scene == null or _scene._world == null:
		return
	for node in _scene._world.find_children("*", "Label3D", true, false):
		if is_instance_valid(node):
			node.visible = false

func _capture(file_name: String) -> void:
	_hide_floaters()
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))

func _capture_internal(file_name: String) -> void:
	_hide_floaters()
	await RenderingServer.frame_post_draw
	var image: Image = _scene._viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
