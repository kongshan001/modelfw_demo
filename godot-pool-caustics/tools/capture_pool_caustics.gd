extends SceneTree

# 10 秒 / 30 fps / 1920×1080 演示帧：池底 → F2−F1 分析 → 单格切缝 →
# 回到 3×3 → 熔岩变体。时间与相机由帧号驱动，保证离线渲染速度不影响节奏。
# 用法：godot --path godot-pool-caustics -s tools/capture_pool_caustics.gd

const OUT := "/tmp/pool_caustics_frames"
const SIZE := Vector2i(1920, 1080)
const FPS := 30
const FRAMES := 300
const TARGET := Vector3(0.55, -0.25, 0.0)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await create_timer(0.8).timeout

	var hud = _scene.get_hud()
	hud.set_ui_scale(1.5)
	hud.set_minimal(true)
	hud.set_stats_visible(false)
	hud.set_ui_visible(true)
	_scene.set_ui_visible(true)
	_scene.paused = true

	var segment := -1
	for i in FRAMES:
		var t := float(i) / float(FPS)
		var want := _segment_at(i)
		if want != segment:
			segment = want
			_enter_segment(segment, hud)
			await process_frame
		_update_camera(t, segment)
		_scene.set_time_override(2.5 + t * 1.05)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		var err := img.save_png("%s/frame_%04d.png" % [OUT, i])
		if err != OK:
			printerr("save frame failed ", i, " err=", err)
		if i % 30 == 0:
			print("CAPTURE frame=%d t=%.1fs segment=%d" % [i, t, segment])

	print("POOL_CAUSTICS_CAPTURE_OK frames=%d fps=%d size=%dx%d" % [
			FRAMES, FPS, SIZE.x, SIZE.y])
	quit(0)


func _segment_at(i: int) -> int:
	if i < 120:
		return 0  # 池底光网
	if i < 150:
		return 1  # F2−F1
	if i < 180:
		return 2  # 单格切缝
	if i < 225:
		return 3  # 回到 3×3
	return 4      # 熔岩


func _enter_segment(segment: int, hud) -> void:
	match segment:
		0:
			_scene.set_variant(0)
			_scene.set_search_3x3(true)
			_scene.set_debug_mode(0)
			hud.show_caption("3×3 邻域 · 最近 F1 / 次近 F2 → F2−F1 光网", 0.0)
		1:
			_scene.set_debug_mode(3)
			hud.show_caption("F2−F1 在边界归零，经指数衰减成为亮纹", 0.0)
		2:
			_scene.set_debug_mode(0)
			_scene.set_search_3x3(false)
			hud.show_caption("单格测距：像素只看本格，光场在格缝处断裂", 0.0)
		3:
			_scene.set_search_3x3(true)
			_scene.set_debug_mode(0)
			hud.show_caption("3×3 候选取齐 · 扭曲 / 交点鼓结 / 明暗聚散 / 宽柔光", 0.0)
		4:
			_scene.set_variant(1)
			hud.show_caption("同一 F2−F1 核心 → 熔岩裂缝：阈值 / 热色 / 辉光切换", 0.0)


func _update_camera(t: float, segment: int) -> void:
	var yaw := 2.4 + sin(t * 0.33) * 3.2
	var distance := 17.2
	if segment == 4:
		var k := clampf((t - 7.5) / 2.5, 0.0, 1.0)
		distance = lerpf(17.2, 15.4, k)
	_scene.get_pool_camera().set_pose(TARGET, yaw, 48.0, distance)


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for f in dir.get_files():
		if f.begins_with("frame_") and f.ends_with(".png"):
			dir.remove(f)
