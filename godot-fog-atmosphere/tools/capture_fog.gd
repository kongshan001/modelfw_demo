extends SceneTree
## 10 秒 / 30fps 源帧采集：昼雾 → 淡雾 → 暖金雾 → 入夜月光 → 潭边精灵。
## 用法：godot --path . --fixed-fps 30 -s tools/capture_fog.gd
## 输出：/tmp/fog_atmosphere_frames/frame_0000.jpg ... frame_0299.jpg
## 之后用 ffmpeg 编码 MP4/GIF（命令见 README）。

const FRAME_DIR := "/tmp/fog_atmosphere_frames"
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
	main.demo_set_hud_visible(true)

	var keys := [
		{"f": 0, "yaw": 18.0, "pitch": 36.0, "dist": 15.5, "focus": Vector3(0.0, 1.4, 0.0)},
		{"f": 55, "yaw": 36.0, "pitch": 33.0, "dist": 14.5, "focus": Vector3(1.5, 1.4, 1.5)},
		{"f": 100, "yaw": 74.0, "pitch": 27.0, "dist": 12.5, "focus": Vector3(4.0, 1.2, 4.0)},
		{"f": 140, "yaw": 118.0, "pitch": 20.0, "dist": 10.5, "focus": Vector3(9.5, 0.6, 6.0)},
		{"f": 170, "yaw": 126.0, "pitch": 16.0, "dist": 11.0, "focus": Vector3(9.5, 1.0, 6.0)},
		{"f": 200, "yaw": 45.0, "pitch": 7.0, "dist": 20.0, "focus": Vector3(0.0, 6.0, 0.0)},
		{"f": 250, "yaw": 34.0, "pitch": 9.0, "dist": 18.0, "focus": Vector3(0.0, 4.5, 0.0)},
		{"f": 275, "yaw": 80.0, "pitch": 14.0, "dist": 13.0, "focus": Vector3(5.0, 2.0, 4.0)},
		{"f": 300, "yaw": 120.0, "pitch": 16.0, "dist": 9.0, "focus": Vector3(9.5, 1.0, 6.0)},
	]

	for frame in range(FRAME_COUNT):
		if frame == 80:
			main.demo_set_fog(1, 1)
		elif frame == 100:
			main.demo_set_hud_visible(false)
			main.demo_set_fog(0, 0)
		elif frame == 140:
			main.demo_set_fog(2, 2)
			main.demo_set_fog_color(2)
		elif frame == 170:
			main.demo_set_phase(true, false)
		elif frame == 200:
			main.demo_set_fog_color(0)
			main.demo_set_fog(2, 2)
		var view := _view_at(keys, frame)
		main.demo_set_view(view[0], view[1], view[2], view[3])
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

	print("FOG_VIDEO_FRAMES_OK frames=%d" % FRAME_COUNT)
	quit(0)


func _view_at(keys: Array, frame: int) -> Array:
	for i in range(keys.size() - 1):
		var a: Dictionary = keys[i]
		var b: Dictionary = keys[i + 1]
		if frame >= int(a["f"]) and frame <= int(b["f"]):
			var span := maxf(1.0, float(int(b["f"]) - int(a["f"])))
			var t := clampf((float(frame) - float(a["f"])) / span, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return [
				lerpf(float(a["yaw"]), float(b["yaw"]), t),
				lerpf(float(a["pitch"]), float(b["pitch"]), t),
				lerpf(float(a["dist"]), float(b["dist"]), t),
				(a["focus"] as Vector3).lerp(b["focus"] as Vector3, t),
			]
	var last: Dictionary = keys[keys.size() - 1]
	return [float(last["yaw"]), float(last["pitch"]), float(last["dist"]), last["focus"]]


func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
