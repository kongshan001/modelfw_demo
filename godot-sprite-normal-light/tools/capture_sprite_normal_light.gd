extends SceneTree

# 10s 演示时间线（300 帧 @30fps）：法线 ON/OFF、点光巡游、法线图/光向量调试、
# 高光特写、原生 CanvasTexture+Light2D、翻转+2×缩放，最后回到主画面。
# 世界与字幕都渲染在 1280×720 SubViewport 中；HUD 隐藏，底部独立字幕。
# 用法：godot --path godot-sprite-normal-light --fixed-fps 30 \
#          -s tools/capture_sprite_normal_light.gd
# 之后由 tools/build_media.sh 生成 docs/sprite_normal_light.mp4 / .gif。

const OUT := "/tmp/sprite_normal_light_frames"
const SIZE := Vector2i(1280, 720)
const FRAMES := 300

var _scene
var _vp: SubViewport
var _caption: Label
var _cam: Camera2D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	_vp.snap_2d_transforms_to_pixel = true
	_vp.snap_2d_vertices_to_pixel = true
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout

	_cam = _scene.get_node("World/Camera2D")
	_scene.set_ui_visible(false)
	_scene.set_playing(false)
	_scene.set_auto_orbit(false)
	_scene.set_native_mode(false)
	_scene.set_debug_mode(0)
	_scene.set_normals_on(true)
	_scene.set_light_angle(330.0)
	_build_caption()
	await process_frame

	for i in range(FRAMES):
		_apply_timeline(i)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%03d.png" % [OUT, i])
		if err != OK:
			printerr("save frame %d failed: %d" % [i, err])
		if i % 60 == 0:
			print("CAPTURE frame=%d caption=%s" % [i, _caption.text])
	print("SPRITE_NORMAL_LIGHT_CAPTURE_OK frames=%d" % FRAMES)
	quit(0)


func _apply_timeline(i: int) -> void:
	if i == 0:
		_set_caption("灯影工坊 · 精灵法线贴图光照")
	elif i == 24:
		_set_caption("可移动点光 · 法线漫反射 + 高光")
	elif i == 75:
		_scene.set_light_angle(0.0)
		_scene.set_normals_on(false)
		_set_caption("法线 OFF · 平面贴图对比")
	elif i == 105:
		_scene.set_normals_on(true)
		_set_caption("法线 ON · 凹凸/轮廓读出体积")
	elif i == 135:
		_scene.set_debug_mode(1)
		_set_caption("调试 · 切线空间法线图")
	elif i == 165:
		_scene.set_debug_mode(4)
		_set_caption("调试 · 光照向量叠加")
	elif i == 195:
		_scene.set_debug_mode(0)
		_scene.set_light_angle(20.0)
		_scene.set_light_height(34.0)
		_scene.set_roughness(0.22)
		_scene.set_spec_strength(1.1)
		_scene.set_light_energy(2.0)
		_set_caption("高光 · 低粗糙度金属反光")
	elif i == 225:
		_cam.position = Vector2(160, 90)
		_cam.zoom = Vector2(4, 4)
		_scene.get_node("LightRig/EmberGlow").visible = true
		_scene.reset()
		_scene.set_playing(false)
		_scene.set_auto_orbit(false)
		_scene.set_light_angle(330.0)
		_scene.set_native_mode(true)
		_set_caption("原生路径 · CanvasTexture + Light2D")
	elif i == 267:
		_scene.set_native_mode(false)
		_scene.reset()
		_scene.set_playing(false)
		_scene.set_auto_orbit(false)
		_scene.set_light_angle(330.0)
		_scene.toggle_flip_test()
		_scene.toggle_scale_test()
		_set_caption("精灵翻转 + 2× 缩放 · 光照不破")
	elif i == 285:
		_scene.toggle_flip_test()
		_scene.toggle_scale_test()
		_scene.reset()
		_scene.set_playing(false)
		_scene.set_auto_orbit(false)
		_scene.set_light_angle(330.0)
		_set_caption("灯影工坊 · Godot 4.6 GL Compatibility")

	if i >= 24 and i < 75:
		var t := float(i - 24) / 51.0
		_scene.set_light_angle(310.0 + 50.0 * t)
	elif i >= 225 and i < 267:
		# native 段：让光缓慢划过，证明原生光源可移动
		var t2 := float(i - 225) / 42.0
		_scene.set_light_angle(330.0 + 55.0 * t2)


func _set_caption(text: String) -> void:
	if _caption != null:
		_caption.text = text


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.name = "VideoCaptions"
	layer.layer = 20
	_scene.add_child(layer)
	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)
	var bar := PanelContainer.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -58.0
	bar.offset_bottom = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.045, 0.82)
	style.border_color = Color(0.62, 0.48, 0.24, 0.75)
	style.border_width_top = 2
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	bar.add_theme_stylebox_override("panel", style)
	root_control.add_child(bar)
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "STHeiti",
		"Noto Sans CJK SC", "Sans-Serif"])
	font.allow_system_fallback = true
	var label := Label.new()
	label.text = "灯影工坊 · 精灵法线贴图光照"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.72, 1.0))
	bar.add_child(label)
	_caption = label


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
