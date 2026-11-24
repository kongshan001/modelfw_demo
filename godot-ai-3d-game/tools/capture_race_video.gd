extends SceneTree

# 10 秒成片的帧源：1920×1080、20fps、真实自动驾驶跑完 1 圈 + 结算。
# 帧先落 /tmp/race_video_frames，再由 ffmpeg 编码/加速为 10s MP4 与 GIF。
# 运行：
#   godot --path godot-ai-3d-game --resolution 1280x720 -s tools/capture_race_video.gd

const OUT := "/tmp/race_video_frames"
const CAPTURE_FPS := 20.0
const WARMUP := 1.8
const FINISH_HOLD_FRAMES := 46

var vp: SubViewport
var world: RaceWorld
var saved := 0
var started := false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_prepare_dir()
	vp = SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	root.add_child(vp)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	vp.add_child(scene)
	await process_frame
	await process_frame
	world = scene as RaceWorld
	# 逐帧 PNG 回读会把 Engine FPS 拉到个位数；录制时隐藏该读数，避免误导。
	# 真实性能由 perf_ai_3d_game.gd 单独测量，正常游戏里 FPS 标签继续显示。
	if world.hud != null:
		world.hud.show_fps = false
	# 预热期间冻结倒计时，避免录到 shader 首次编译的卡顿。
	world.capture_freeze = true
	await create_timer(WARMUP).timeout
	world.capture_freeze = false
	world.player.auto_drive = true

	var watchdog_us := Time.get_ticks_usec() + 160_000_000
	var finish_frame := -1
	while Time.get_ticks_usec() < watchdog_us:
		await create_timer(1.0 / CAPTURE_FPS).timeout
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		image.save_png("%s/frame_%04d.png" % [OUT, saved])
		saved += 1
		if not started and world.state == RaceWorld.RaceState.RACING:
			started = true
			print("RACE_VIDEO_START frame=%d countdown_done=%.2f" % [saved, world.elapsed])
		if world.state == RaceWorld.RaceState.FINISHED:
			if finish_frame < 0:
				finish_frame = saved
				print("RACE_VIDEO_FINISH frame=%d place=%d time=%.2f" % [saved, world.finish_place, world.finish_time])
			elif saved - finish_frame >= FINISH_HOLD_FRAMES:
				break
	world.player.auto_drive = false
	Input.action_release("accelerate")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	print("RACE_VIDEO_FRAMES_OK frames=%d source_seconds=%.2f finish_place=%d" % [saved, float(saved) / CAPTURE_FPS, world.finish_place])
	quit(0)


func _prepare_dir() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			dir.remove(file_name)
