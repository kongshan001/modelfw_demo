extends SceneTree
## 10 秒 / 30fps 源帧采集：基地 → 移动 → 搜箱 → 战斗 → 背包 → 撤离 → 结算。
## 用法：godot --path . --fixed-fps 30 -s tools/capture_fog_harbor.gd
## 输出：/tmp/fog_harbor_frames/frame_0000.jpg ... frame_0299.jpg
## 之后用 ffmpeg 编码 MP4/GIF（命令见 README / docs/TECH.md）。

const FRAME_DIR := "/tmp/fog_harbor_frames"
const HarborMapScript = preload("res://scripts/harbor_map.gd")
const FRAME_COUNT := 300
const SIZE := Vector2i(1920, 1080)

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
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".jpg") or name.ends_with(".png"):
			dir.remove(name)
		name = dir.get_next()
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
	await _wait_frames(5)
	main.demo_use_save_path("user://fog_harbor_capture_save.json")
	main.demo_seed_state()
	await _wait_frames(8)

	var chest_index := 5
	var chest_pos := Vector2.ZERO
	var move_start := Vector2(280, 1260)
	var move_end := Vector2.ZERO
	var combat_base := Vector2(960, 720)

	for frame in range(FRAME_COUNT):
		if frame == 15:
			main.demo_start_raid()
			main.demo_set_god(true)
			chest_pos = main.demo_get_chests()[chest_index].global_position
			move_end = chest_pos + Vector2(0, 42)
			main.demo_set_crosshair(Vector2(760, 330))
		elif frame == 18:
			main.demo_move(Vector2(280, 1260))
			main.demo_aim_at(chest_pos)
		elif frame >= 20 and frame <= 55:
			var t := float(frame - 20) / 35.0
			main.demo_move(move_start.lerp(move_end, t))
			main.demo_aim_at(chest_pos)
			main.demo_set_crosshair(Vector2(600, 300))
		elif frame == 56:
			main.demo_set_manual_interaction(true)
			main.demo_aim_at(chest_pos)
			main.demo_prompt("按住 E 搜索补给箱", -1.0, "箱内约 3 件 · 背包 1 / 24 格")
		elif frame >= 57 and frame <= 77:
			main.demo_search_chest(chest_index, 0.045)
			main.demo_prompt("正在搜索补给箱", float(frame - 56) * 0.045 / 0.9, "保持按住 E · 箱内物资")
		elif frame == 78:
			main.demo_aim_at(chest_pos)
			main.demo_prompt("补给箱已搜索", -1.0, "背包 %d / 24 格" % main.demo_get_inventory().cells_used())
		elif frame == 92:
			main.demo_set_manual_interaction(false)
			main.demo_stage_combat()
			main.demo_set_crosshair(Vector2(830, 330))
		elif frame >= 96 and frame <= 168:
			var target_index := int((frame - 96) / 12) % maxi(1, main.demo_get_enemies().size())
			var enemy = main.demo_get_enemies()[target_index]
			var strafe := Vector2(sin(float(frame) * 0.16) * 26.0, cos(float(frame) * 0.11) * 12.0)
			main.demo_move(combat_base + strafe)
			main.demo_aim_at(enemy.global_position)
			if (frame - 96) % 12 == 0:
				main.demo_fire_at(enemy.global_position)
		elif frame == 176:
			main.demo_add_demo_loot()
			main.demo_open_backpack()
			var pack = main.demo_get_backpack()
			if pack != null:
				pack.selected_index = 0
				pack.refresh()
		elif frame == 204:
			main.demo_close_backpack()
		elif frame == 207:
			var zone_center: Vector2 = HarborMapScript.EXTRACTION_RECT.get_center()
			main.demo_teleport(zone_center)
			main.demo_aim_at(zone_center + Vector2(0, -80))
			main.demo_freeze_rules(true)
			main.demo_force_extraction_progress(2.15)
			main.demo_set_crosshair(Vector2(640, 380))
		elif frame == 226:
			main.demo_freeze_rules(false)
			main.demo_set_crosshair(Vector2(-1, -1))

		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		var path := "%s/frame_%04d.jpg" % [FRAME_DIR, frame]
		var err := image.save_jpg(path, 0.88)
		if err != OK:
			printerr("FAILED frame ", frame, " err=", err)
			quit(1)
			return
		if frame % 30 == 0:
			print("FRAME ", frame)

	print("FOG_HARBOR_VIDEO_FRAMES_OK frames=%d" % FRAME_COUNT)
	quit(0)


func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
	await RenderingServer.frame_post_draw
