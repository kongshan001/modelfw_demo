extends SceneTree

# 录制展示 demo：默认 Dance（原生 SambaDance）；加 `-- --run` 录制 baked Run。
# 用法：
#   godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_baked_demo.gd
#   CAPTURE_OUT=/tmp/xxx godot ... -s tools/capture_baked_demo.gd -- --run
# 输出：$CAPTURE_OUT/frame_000.png ...（默认 /tmp/mixamo_baked_demo_frames）

const OUT_DEFAULT := "/tmp/mixamo_baked_demo_frames"
const FPS := 15.0
const FRAMES := 60

var _viewport: SubViewport

func _initialize() -> void:
	var out_dir := OS.get_environment("CAPTURE_OUT")
	if out_dir.is_empty():
		out_dir = OUT_DEFAULT
	DirAccess.make_dir_recursive_absolute(out_dir)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.own_world_3d = true
	root.add_child(_viewport)

	var scene: Node = load("res://scenes/baked_demo.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	if "--run" in OS.get_cmdline_user_args():
		scene.call("set_run_mode")
	await create_timer(0.8).timeout

	for i in FRAMES:
		await create_timer(1.0 / FPS).timeout
		await RenderingServer.frame_post_draw
		var image := _viewport.get_texture().get_image()
		image.save_png(out_dir + "/frame_%03d.png" % i)

	print("CAPTURED ", FRAMES, " frames")
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)
