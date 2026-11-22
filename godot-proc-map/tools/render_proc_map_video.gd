extends SceneTree

# 固定 30fps / 300 帧（10 秒）离线录制：
#  0.0–1.2s 群岛 Hero 缓推 → 1.2–2.9s 切地牢 + BSP 调试 → 2.9–5.9s 群岛分阶段生成
#  → 5.9–6.9s 完成态 → 6.9s 同种子复现（签名一致）→ 7.3–10s Hero 近景缓推。
# 用法：godot --path . --resolution 1280x720 -s tools/render_proc_map_video.gd
# 输出：/tmp/proc_map_frames/frame_0000.png ...，再由 tools/build_media.sh 编码。

const OUT := "/tmp/proc_map_frames"
const W := 1280
const H := 720
const FPS := 30
const FRAMES := 300
const BIOME_SEED := "9001"
const DUNGEON_SEED := "2137"

var _vp: SubViewport
var _scene
var _focus_poi: Dictionary = {}
var _start_center := Vector2.ZERO
var _closeup_start := 220


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_clear_frames()
	_vp = SubViewport.new()
	_vp.size = Vector2i(W, H)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	_scene.api_set_capture_mode(true)
	await create_timer(0.5).timeout

	_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	var view = _scene.api_get_view()
	_start_center = view.get_scene_center()
	_pick_focus_poi()

	for frame in FRAMES:
		_apply_script(frame)
		await process_frame
		await RenderingServer.frame_post_draw
		var image := _vp.get_texture().get_image()
		var path := OUT + "/frame_%04d.png" % frame
		var err := image.save_png(path)
		if err != OK:
			printerr("frame save failed ", frame, ": ", err)
			quit(1)
			return
		if frame % 50 == 0:
			print("FRAME %d/%d stage=%d mode=%s" % [frame, FRAMES,
				int(_scene.api_get_gen().stage_index), String(_scene._mode)])
	print("PROC_MAP_VIDEO_FRAMES_OK frames=%d size=%dx%d fps=%d" % [FRAMES, W, H, FPS])
	quit(0)


func _apply_script(frame: int) -> void:
	if frame < 1:
		return
	if frame == 1:
		_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
		_scene.api_finish()
		_scene.api_set_debug({})
		_pick_focus_poi()
		return
	if frame < 36:
		var t := float(frame) / 35.0
		_scene.api_focus(_start_center, 1.0 + 0.055 * t)
		return
	if frame == 36:
		_scene.api_new("dungeon", DUNGEON_SEED, 0, 12.0, true)
		_scene.api_finish()
		_scene.api_set_debug({})
		return
	if frame == 58:
		_scene.api_set_debug({"rooms": true, "connectivity": true, "bounds": true})
		return
	if frame == 80:
		_scene.api_set_debug({})
		return
	if frame == 88:
		_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
		return
	if frame == 106 or frame == 124 or frame == 142 or frame == 160 or frame == 178:
		_scene.api_step()
		return
	if frame == 206:
		_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
		_scene.api_finish()
		_scene.api_set_debug({})
		_scene.api_reset_camera()
		var view = _scene.api_get_view()
		_start_center = view.get_scene_center()
		_pick_focus_poi()
		return
	if frame >= _closeup_start:
		var t := clampf(float(frame - _closeup_start) / 62.0, 0.0, 1.0)
		var ease_t := t * t * (3.0 - 2.0 * t)
		var target: Vector2 = _focus_poi.get("pos", _start_center)
		var center := _start_center.lerp(target, ease_t * 0.92)
		var factor := 1.0 + 1.18 * ease_t
		_scene.api_focus(center, factor)
		return


func _pick_focus_poi() -> void:
	_focus_poi = {}
	var gen = _scene.api_get_gen()
	if gen == null:
		return
	var best_wd := 999
	for poi in gen.pois:
		var cell: Vector2i = poi["cell"]
		if cell.x > int(gen.width * 0.62) or cell.y > int(gen.height * 0.68):
			continue
		var wd := int(poi.get("water_distance", 99))
		if wd < best_wd:
			best_wd = wd
			_focus_poi = poi
	if _focus_poi.is_empty() and gen.pois.size() > 0:
		_focus_poi = gen.pois[0]


func _clear_frames() -> void:
	var dir := DirAccess.open(OUT)
	if dir == null:
		return
	for file_name in dir.get_files():
		if file_name.begins_with("frame_") and file_name.ends_with(".png"):
			dir.remove(file_name)
