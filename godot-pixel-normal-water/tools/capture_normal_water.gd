extends SceneTree

# 10 秒（300 帧 @30fps）演示时间线。
# 用 Godot Movie Maker 直接录制 PNG 序列（--write-movie /tmp/normal_water_frames/frame.png），
# 避免逐帧 get_image()/save_png() 的主线程开销；画面仍是单 Camera2D、零 SubViewport。
# 用法：godot --path godot-pixel-normal-water --fixed-fps 30 \
#         --write-movie /tmp/normal_water_frames/frame.png -s tools/capture_normal_water.gd
# 或直接跑 tools/build_media.sh。

const OUT := "/tmp/normal_water_frames"
const FPS := 30
const FRAMES := 300

var _scene
var _caption: Label
var _param: Label
var _title: Label
var _last_caption := ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(_scene)
	# _ready() 在下一帧前完成；先把 HUD CanvasLayer 直接隐藏，避免 Movie Maker
	# 把接口面板录进演示视频。再等一帧让相机、倒影和材质都初始化。
	var hud: Node = _scene.get_node_or_null("HUD")
	if hud != null:
		hud.visible = false
	_build_caption_overlay()
	_set_caption("01 / 夜景全景 · 墙体、瓦面、树冠都在算法线受光")
	await process_frame
	_scene.set_ui_visible(false)
	_scene.set_paused(false)
	_scene.set_light_preset(0)
	_scene.set_lamps_enabled(true)
	_scene.set_reflection_enabled(true)
	_scene.set_debug_enabled(false)
	_scene.set_normal_view(false)
	_scene.set_wave_speed(1.0)
	_scene.set_wave_amplitude(2.0)
	_scene.set_wave_step(1.0)
	_scene.reset_camera()

	for frame in FRAMES:
		_update_timeline(frame)
		await process_frame

	print("NORMAL_WATER_CAPTURE_OK frames=%d fps=%d" % [FRAMES, FPS])
	quit(0)


func _build_caption_overlay() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Monaco", "Consolas", "Monospace"])
	mono.allow_system_fallback = true

	var layer := CanvasLayer.new()
	layer.name = "CaptureCaption"
	layer.layer = 30
	root.add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)

	_title = Label.new()
	_title.position = Vector2(44, 28)
	_title.text = "静水回廊 · STILLWATER"
	_title.add_theme_font_override("font", font)
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.95, 0.80, 0.49, 0.95))
	_title.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.95))
	_title.add_theme_constant_override("outline_size", 8)
	root_control.add_child(_title)

	var tag := Label.new()
	tag.position = Vector2(46, 56)
	tag.text = "2D PIXEL NORMAL LIGHT · SINGLE-CAMERA REFLECTION"
	tag.add_theme_font_override("font", mono)
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.60, 0.78, 0.74, 0.78))
	tag.add_theme_color_override("font_outline_color", Color(0.01, 0.03, 0.04, 0.9))
	tag.add_theme_constant_override("outline_size", 5)
	root_control.add_child(tag)

	_caption = Label.new()
	_caption.position = Vector2(44, 638)
	_caption.add_theme_font_override("font", font)
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.add_theme_color_override("font_color", Color(0.94, 0.90, 0.77, 0.98))
	_caption.add_theme_color_override("font_outline_color", Color(0.01, 0.035, 0.045, 0.98))
	_caption.add_theme_constant_override("outline_size", 9)
	root_control.add_child(_caption)

	_param = Label.new()
	_param.position = Vector2(46, 674)
	_param.add_theme_font_override("font", mono)
	_param.add_theme_font_size_override("font_size", 12)
	_param.add_theme_color_override("font_color", Color(0.46, 0.84, 0.78, 0.92))
	_param.add_theme_color_override("font_outline_color", Color(0.01, 0.035, 0.045, 0.98))
	_param.add_theme_constant_override("outline_size", 6)
	root_control.add_child(_param)


func _set_caption(text: String) -> void:
	if text != _last_caption and _caption != null:
		_caption.text = text
		_last_caption = text


func _camera_lerp(a_center: Vector2, a_zoom: float, b_center: Vector2, b_zoom: float,
		t: float) -> void:
	var e := _ease(t)
	_scene.focus_camera(a_center.lerp(b_center, e), lerpf(a_zoom, b_zoom, e))


func _update_timeline(frame: int) -> void:
	# 00.0–02.5s 全景；月光方向缓慢扫过
	if frame < 75:
		_scene.reset_camera()
		_scene.set_light_angle(lerpf(35.0, 310.0, _ease(frame / 74.0)))
		_scene.set_lamps_enabled(true)
		_scene.set_reflection_enabled(true)
		_scene.set_debug_enabled(false)
		_scene.set_normal_view(false)
		_scene.set_wave_amplitude(2.0)
		_scene.set_wave_step(1.0)
		_set_caption("01 / 夜景全景 · 墙体、瓦面、树冠都在算法线受光")
	# 02.5–03.0s 平滑推进到酒馆，光从右上
	elif frame < 90:
		_camera_lerp(Vector2(160, 90), 4.0, Vector2(67, 80), 8.0, (frame - 75) / 14.0)
		_scene.set_light_angle(312.0)
		_set_caption("02 / 建筑受光 · 同一机位，改变月光方向")
	# 03.0–04.2s 同一机位扫光到左上，展示方向响应
	elif frame < 126:
		_scene.focus_camera(Vector2(67, 80), 8.0)
		_scene.set_light_angle(lerpf(312.0, 78.0, _ease((frame - 90) / 35.0)))
		_set_caption("02 / 法线正交拆解：屋顶 / 梁柱 / 树冠重新受光")
	# 04.2–05.0s 平滑拉到水面倒影
	elif frame < 142:
		_camera_lerp(Vector2(67, 80), 8.0, Vector2(150, 126), 6.2, (frame - 126) / 15.0)
		_scene.set_light_angle(35.0)
		_scene.set_wave_amplitude(4.0)
		_scene.set_wave_step(2.0)
		_scene.set_lamps_enabled(true)
		_scene.set_reflection_enabled(true)
		_set_caption("03 / 单 Mesh 倒影 · 一张 water mask 裁切")
	# 05.0–06.5s 量化水波
	elif frame < 196:
		_scene.focus_camera(Vector2(135, 132), 7.2)
		_scene.set_light_angle(35.0)
		_scene.set_wave_amplitude(4.0)
		_scene.set_wave_step(2.0)
		_set_caption("04 / round() 量化：水波整行整格跳动，不做平滑拉伸")
	# 06.5–07.1s 暖灯开关
	elif frame < 214:
		_scene.focus_camera(Vector2(150, 126), 6.2)
		_scene.set_wave_amplitude(2.0)
		_scene.set_wave_step(1.0)
		_scene.set_lamps_enabled(not (frame >= 198 and frame < 207))
		_set_caption("05 / 暖灯开关：灯芯、点光、暖色倒影同步")
	# 07.1–07.6s 倒影开关
	elif frame < 228:
		_scene.focus_camera(Vector2(150, 126), 6.2)
		_scene.set_lamps_enabled(true)
		_scene.set_reflection_enabled(not (frame >= 214 and frame < 223))
		_set_caption("05 / 倒影开关：单 Mesh 隐藏，水面波光仍在")
	# 07.6–08.2s 平滑回到全景
	elif frame < 246:
		_camera_lerp(Vector2(150, 126), 6.2, Vector2(160, 90), 4.0, (frame - 228) / 17.0)
		_scene.set_reflection_enabled(true)
		_scene.set_debug_enabled(false)
		_scene.set_normal_view(false)
		_scene.set_light_angle(35.0)
		_set_caption("回到全景 · 单 Camera2D / 单倒影 Mesh")
	# 08.2–09.0s 调试视图
	elif frame < 270:
		_scene.reset_camera()
		_scene.set_lamps_enabled(true)
		_scene.set_reflection_enabled(true)
		_scene.set_wave_amplitude(2.0)
		_scene.set_wave_step(1.0)
		_scene.set_light_angle(35.0)
		_scene.set_debug_enabled(true)
		_scene.set_normal_view(true)
		_set_caption("06 / 调试：法线 RGB + 光向量 + 倒影四边形")
	# 09.0–10.0s 收尾
	else:
		_scene.set_debug_enabled(false)
		_scene.set_normal_view(false)
		_scene.set_lamps_enabled(true)
		_scene.set_reflection_enabled(true)
		_scene.reset_camera()
		_scene.set_light_angle(35.0)
		_set_caption("静水回廊 · 原创像素夜景 / 2D 单相机")

	if _param != null:
		var p: Dictionary = _scene.get_params()
		_param.text = "L %3d°   WAVE %dpx / step %dpx   REFLECT %s   LAMPS %s" % [
			int(round(float(p["angle"]))),
			int(round(float(p["wave_amp"]))),
			int(round(float(p["wave_step"]))),
			"ON" if bool(p["reflection"]) else "OFF",
			"ON" if bool(p["lamps"]) else "OFF"]


func _ease(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if (f.begins_with("frame") and f.ends_with(".png")) or f.ends_with(".wav"):
			dir.remove(f)
