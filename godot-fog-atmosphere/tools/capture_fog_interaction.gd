extends SceneTree
## 10 秒 / 30fps 源帧采集：第三人称行走清雾 → 停下恢复 → 半径 2m/10m 对比 → 夜雾。
## 用法：godot --path . --fixed-fps 30 -s tools/capture_fog_interaction.gd
## 输出：/tmp/fog_interaction_frames/frame_0000.jpg ... frame_0299.jpg
## 之后用 ffmpeg 编码 MP4/GIF（命令见 README）。

const FRAME_DIR := "/tmp/fog_interaction_frames"
const FRAME_COUNT := 300
const SIZE := Vector2i(1280, 720)

var vp: SubViewport
var main


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)
	_clean_frames()
	call_deferred("_run")


func _clean_frames() -> void:
	var dir := DirAccess.open(FRAME_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".jpg") or entry.ends_with(".png"):
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


func _run() -> void:
	vp = SubViewport.new()
	vp.size = SIZE
	vp.size_2d_override = Vector2i(1280, 720)
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _wait(12)
	main.demo_reset()
	main.demo_set_fps_visible(false)
	main.demo_set_fog(2, 2)
	main.demo_set_fog_color(0)
	main.demo_set_hud_visible(true)

	for frame in range(FRAME_COUNT):
		if frame == 45:
			main.demo_set_player_input(0.0, 1.0, false)
		elif frame == 90:
			main.demo_set_player_input(0.0, 1.0, true)
		elif frame == 140:
			main.demo_clear_player_input()
		elif frame == 200:
			main.demo_teleport_player(1.5, 18.5)
			main.demo_set_fog_clear(2.0, 0.85, 1.6)
			main.demo_set_player_input(0.0, 1.0, false)
		elif frame == 212:
			main.demo_clear_player_input()
			main.demo_teleport_player(1.5, 18.5)
		elif frame == 232:
			main.demo_teleport_player(1.5, 18.5)
			main.demo_set_fog_clear(10.0, 0.85, 1.6)
			main.demo_set_player_input(0.0, 1.0, false)
		elif frame == 244:
			main.demo_clear_player_input()
			main.demo_teleport_player(1.5, 18.5)
		elif frame == 262:
			main.demo_set_phase(true, true)
			main.demo_set_fog(2, 2)
			main.demo_set_fog_clear(4.5, 0.85, 1.6)
			main.demo_teleport_player(3.4, 1.6)
			main.demo_set_player_input(0.7, 0.4, true)
		var view := _view_at(frame)
		main.demo_set_follow_view(view[0], view[1], view[2])
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		var path := "%s/frame_%04d.jpg" % [FRAME_DIR, frame]
		var err := image.save_jpg(path, 0.90)
		if err != OK:
			printerr("FAILED frame ", frame, " err=", err)
			quit(1)
			return
		if frame % 30 == 0:
			print("FRAME ", frame)

	print("FOG_INTERACTION_VIDEO_FRAMES_OK frames=%d" % FRAME_COUNT)
	quit(0)


func _view_at(frame: int) -> Array:
	# 相机只做缓慢环绕，保证角色始终在画面中
	var yaw := 20.0
	var pitch := 21.0
	var dist := 7.4
	if frame < 45:
		yaw = lerpf(16.0, 28.0, smooth01(float(frame) / 45.0))
	elif frame < 140:
		yaw = lerpf(28.0, 52.0, smooth01(float(frame - 45) / 95.0))
		pitch = lerpf(21.0, 18.0, smooth01(float(frame - 45) / 95.0))
	elif frame < 200:
		yaw = lerpf(52.0, 40.0, smooth01(float(frame - 140) / 60.0))
		pitch = 20.0
	elif frame < 232:
		yaw = lerpf(32.0, 28.0, smooth01(float(frame - 200) / 32.0))
		pitch = 20.0
		dist = 7.4
	elif frame < 262:
		yaw = lerpf(28.0, 26.0, smooth01(float(frame - 232) / 30.0))
		pitch = 20.0
		dist = 7.4
	else:
		yaw = lerpf(26.0, 40.0, smooth01(float(frame - 262) / 38.0))
		pitch = 16.0
		dist = 6.4
	return [yaw, pitch, dist]


func smooth01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
