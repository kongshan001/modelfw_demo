extends SceneTree
## 10 秒 / 30 fps 源帧采集：夜全景 → 苔灯亮起 → 苔猫回应 → 晨光 → 细雨。
## 用法：godot --path godot-feralui-scene --fixed-fps 30 -s tools/capture_feralui_scene.gd
## 输出：/tmp/feralui_scene_frames/frame_0000.jpg ... frame_0299.jpg
## 编码命令见 README（ffmpeg 输出 1920×1080 MP4 与 GIF）。

const FRAME_DIR := "/tmp/feralui_scene_frames"
const FRAME_COUNT := 300
const SIZE := Vector2i(1920, 1080)

var vp: SubViewport
var main
var _chime_target


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
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_2X
	root.add_child(vp)
	main = load("res://scenes/main.tscn").instantiate()
	vp.add_child(main)
	await _wait(24)
	main.demo_set_fps_visible(false)
	main.demo_set_hud_visible(true)
	main.demo_set_markers_visible(true)
	main.demo_set_phase(true, true)
	main.demo_set_weather(false, true)
	main.demo_set_quality(true)
	# 让苔灯从“收暗”开始，视频中段点亮，形成明确的微反馈。
	for t in main.world.get_interaction_targets():
		if t.get_display_id() == "lantern_path":
			t.lit = false
	main.world.tick(0.0, 1.0, 0.0, true)

	var keys := [
		{"f": 0, "yaw": 16.0, "pitch": 35.5, "dist": 23.5, "focus": Vector3(0, 2.15, 0.30)},
		{"f": 36, "yaw": 20.0, "pitch": 35.0, "dist": 21.0, "focus": Vector3(0, 2.15, 0.20)},
		{"f": 72, "yaw": 10.0, "pitch": 31.0, "dist": 12.6, "focus": Vector3(-1.30, 1.0, 1.0)},
		{"f": 100, "yaw": 6.0, "pitch": 28.0, "dist": 10.6, "focus": Vector3(-1.30, 0.95, 1.0)},
		{"f": 126, "yaw": 6.0, "pitch": 26.0, "dist": 8.3, "focus": Vector3(1.85, 0.72, -0.35)},
		{"f": 158, "yaw": 10.0, "pitch": 27.0, "dist": 8.5, "focus": Vector3(1.85, 0.75, -0.35)},
		{"f": 194, "yaw": 22.0, "pitch": 35.5, "dist": 21.5, "focus": Vector3(0, 2.15, 0.30)},
		{"f": 226, "yaw": 26.0, "pitch": 35.0, "dist": 20.0, "focus": Vector3(0, 2.0, 0.55)},
		{"f": 252, "yaw": 17.0, "pitch": 31.0, "dist": 17.5, "focus": Vector3(2.0, 1.0, 0.40)},
		{"f": 300, "yaw": 17.0, "pitch": 31.0, "dist": 17.5, "focus": Vector3(2.0, 1.0, 0.40)},
	]

	for frame in range(FRAME_COUNT):
		if frame == 54:
			main.demo_focus_target("lantern_path")
		elif frame == 84:
			main.demo_interact("lantern_path")
		elif frame == 110:
			main.demo_clear_focus()
		elif frame == 126:
			main.demo_focus_target("moss_cat")
		elif frame == 146:
			main.demo_interact("moss_cat")
		elif frame == 171:
			main.demo_clear_focus()
		elif frame == 205:
			main.demo_set_phase(false, false)
		elif frame == 245:
			main.demo_set_weather(true, false)
		var view := _view_at(keys, frame)
		main.demo_set_view(view[0], view[1], view[2], view[3], false)
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		var path := "%s/frame_%04d.jpg" % [FRAME_DIR, frame]
		var err := image.save_jpg(path, 0.92)
		if err != OK:
			printerr("FAILED frame ", frame, " err=", err)
			quit(1)
			return
		if frame % 30 == 0:
			print("FRAME ", frame)
	print("FERALUI_VIDEO_FRAMES_OK frames=%d" % FRAME_COUNT)
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
