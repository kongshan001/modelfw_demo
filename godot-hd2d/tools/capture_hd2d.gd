extends SceneTree

# 10s / 300 帧 1280×720 演示时间线：
# 移轴开 → 前后对比 → 光方向扫动（长影转动）→ 焦点上移 → 夜灯/萤火。
# 用法：godot --path godot-hd2d --fixed-fps 30 -s tools/capture_hd2d.gd
# 由 tools/build_media.sh 调 ffmpeg 生成 docs/hd2d_demo.mp4 / .gif

const OUT := "/tmp/hd2d_frames"
const SIZE := Vector2i(1280, 720)
const FRAMES := 300

var _vp: SubViewport
var _scene: Node
var _caption: Label


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
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
	_scene.set_ui_visible(false)
	_scene.set_paused(false)
	_build_caption()

	for i in FRAMES:
		var t := float(i) / 30.0
		var post := true
		var angle := -38.0
		var focus := 0.60
		var band := 0.14
		var strength := 1.10
		var radius := 17.0
		var night := false
		var energy := 0.75
		var warmth := 0.35
		var text := "移轴 开 · 焦内 1:1 · 17 点采样"
		if t >= 2.40 and t < 3.40:
			post = false
			text = "移轴 关 · 原始像素场景"
		elif t >= 3.40 and t < 6.40:
			var k := clampf((t - 3.40) / 2.0, 0.0, 1.0)
			k = k * k * (3.0 - 2.0 * k)
			angle = lerpf(-38.0, 38.0, k)
			text = "光方向 -38° / +38° · 长影跟随"
		elif t >= 6.40 and t < 7.80:
			var k := clampf((t - 6.40) / 1.4, 0.0, 1.0)
			angle = 38.0
			focus = lerpf(0.60, 0.36, k)
			band = lerpf(0.14, 0.10, k)
			radius = 19.0
			text = "焦点上移 · 焦带收窄"
		elif t >= 7.80:
			night = true
			angle = -22.0
			focus = 0.62
			band = 0.14
			radius = 17.0
			energy = 1.2
			warmth = 0.12
			text = "夜灯 · 萤火 · 暖色长影"
		_scene.set_post_enabled(post)
		_scene.set_light_angle(angle)
		_scene.set_focus_y(focus)
		_scene.set_band_half(band)
		_scene.set_strength(strength)
		_scene.set_radius(radius)
		_scene.set_light_energy(energy)
		_scene.set_warmth(warmth)
		_scene.set_night(night)
		_caption.text = text
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%03d.png" % [OUT, i])
		if err != OK:
			printerr("save frame %d failed: %d" % [i, err])
		if i % 60 == 0:
			print("CAPTURE frame=%d t=%.1fs %s" % [i, t, text])
	print("HD2D_CAPTURE_OK frames=%d" % FRAMES)
	quit(0)


func _build_caption() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	_vp.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.035, 0.05, 0.043, 0.78)
	bg.position = Vector2(180, 650)
	bg.size = Vector2(920, 46)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(bg)
	_caption = Label.new()
	_caption.text = "移轴 开"
	_caption.position = Vector2(0, 7)
	_caption.size = Vector2(920, 32)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font",
			load("res://assets/fonts/noto-sans-sc-subset.woff2"))
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color("#f3e5c6"))
	_caption.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_caption.add_theme_constant_override("shadow_offset_x", 2)
	_caption.add_theme_constant_override("shadow_offset_y", 2)
	bg.add_child(_caption)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
