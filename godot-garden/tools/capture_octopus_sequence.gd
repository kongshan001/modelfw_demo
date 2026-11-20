extends SceneTree

# 章鱼近景序列：80 帧，黄昏固定，展示 idle → 缠绕石柱。

const FRAMES := 80
const INTERVAL := 0.16

func _initialize() -> void:
	var dir := "user://screenshots/octo_seq"
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
	scene.set_time(18.2)
	scene.focus_octopus(true)
	scene.set_ui_visible(false)
	await create_timer(1.2).timeout
	for index in FRAMES:
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		image.save_png(dir + "/frame_%03d.png" % index)
		await create_timer(INTERVAL).timeout
	scene.queue_free()
	vp.queue_free()
	print("OCTOPUS_SEQUENCE_OK frames=", FRAMES)
	quit(0)
