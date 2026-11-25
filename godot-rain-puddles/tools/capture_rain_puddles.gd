extends SceneTree

# 10 秒演示时间线（30 fps，1280×720）：积水中 → 满水倒影 → 雨停渗干 → 小雨 → 大雨。
# 用 1280×720 的 SubViewport 逐帧抓图；HUD 保留，便于看到参数与状态。
# 用法：godot --path godot-rain-puddles --fixed-fps 30 -s tools/capture_rain_puddles.gd
# 或直接跑 tools/build_media.sh（内含 --fixed-fps 30 + ffmpeg）。
# 之后用 tools/build_media.sh 调 ffmpeg 生成 mp4/gif。

const OUT := "/tmp/rain_puddles_frames"
const SIZE := Vector2i(1280, 720)
const FPS := 30
const FRAMES := 300

var _scene
var _hud
var _vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	_hud = _scene.get_node("HUD")
	_hud.scale = Vector2.ONE
	# 录制时逐帧存 PNG 会拉低实时 FPS；隐藏实时统计，避免视频里出现误导性的低 FPS。
	_hud.set_stats_visible(false)
	_scene.set_ui_visible(true)

	# 起始状态：积水中。
	_set_state({
		"rain": 0.90, "wet": 0.35, "density": 360, "wind": 0.18,
		"drain": 1.0, "speed": 1.0, "length": 1.0,
		"caption": "积水中 · 水位 35% · 雨丝 360",
	})
	for i in FRAMES:
		if i == 75:
			_set_state({
				"rain": 0.55, "wet": 1.0, "density": 360, "wind": 0.12,
				"drain": 1.0, "speed": 1.0, "length": 1.0,
				"caption": "满水 · 红枫 / 松树 / 暖灯倒影",
			})
		elif i == 150:
			_set_state({
				"rain": 0.0, "wet": 1.0, "density": 360, "wind": 0.12,
				"drain": 6.0, "speed": 1.0, "length": 1.0,
				"caption": "雨停 · 缓慢渗干（演示 ×6）",
			})
		elif i == 210:
			_set_state({
				"rain": 0.22, "wet": 0.35, "density": 150, "wind": 0.05,
				"drain": 1.0, "speed": 1.0, "length": 0.9,
				"caption": "小雨 22% · 涟漪更疏",
			})
		elif i == 255:
			_set_state({
				"rain": 1.0, "wet": 0.90, "density": 560, "wind": 0.42,
				"drain": 1.0, "speed": 1.25, "length": 1.2,
				"caption": "大雨 100% · 雨丝 560",
			})
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%03d.png" % [OUT, i])
		if err != OK:
			printerr("save frame %d failed: %d" % [i, err])
		if i % 60 == 0:
			print("CAPTURE frame=%d" % i)
	print("RAIN_PUDDLES_CAPTURE_OK frames=%d" % FRAMES)
	quit(0)


func _set_state(p: Dictionary) -> void:
	_scene.set_paused(false)
	_scene.set_rain_intensity(p["rain"])
	_scene.set_density(p["density"])
	_scene.set_wind(p["wind"])
	_scene.set_drain_speed(p["drain"])
	_scene.set_rain_speed(p["speed"])
	_scene.set_rain_length(p["length"])
	_scene.set_wet_level(p["wet"])
	_hud.sync_from_main()
	_hud.show_caption(p["caption"])


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
