extends SceneTree
## 《苔关八波》10 秒 30fps 实机素材：建塔 → 第 1 波接敌 → 第 4 波精英 → 第 8 波 Boss。
## 用法：godot --path . --script tools/capture_wave_defense_reel.gd
## 输出：res://docs/frames/wd_0000.png … wd_0299.png（后续用 ffmpeg 合成 mp4/GIF）

const Data = preload("res://scripts/game_data.gd")
const FRAME_DIR := "res://docs/frames/"
const FPS := 30
const TOTAL_FRAMES := 300

var main
var _viewport: SubViewport
var _frame := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FRAME_DIR))
	for file in DirAccess.get_files_at(FRAME_DIR):
		if file.begins_with("wd_") and file.ends_with(".png"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(FRAME_DIR + file))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene = load("res://scenes/main.tscn").instantiate()
	_viewport.add_child(scene)
	await process_frame
	main = scene
	main.demo_use_save_path("user://wd_reel_save.json")
	main.demo_set_manual_tick(true)
	main.demo_start_run(Data.DEFAULT_SEED)

	for f in range(TOTAL_FRAMES):
		_frame = f
		_direct(f)
		main.demo_tick(1.0 / float(FPS))
		await RenderingServer.frame_post_draw
		var image: Image = _viewport.get_texture().get_image()
		image.save_png(FRAME_DIR + "wd_%04d.png" % f)
		if f % 30 == 0:
			print("FRAME %03d/300" % f)

	print("FRAMES_DONE %d" % TOTAL_FRAMES)
	main.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)


func _direct(f: int) -> void:
	# 0.0–0.8s：准备阶段 + 建造面板。
	if f == 0:
		main.demo_set_gold(600)
		main.demo_open_build_menu(0)
	# 0.8s：建造弩塔，1.0s 提前开战。
	if f == 24:
		main.demo_build_tower(0, "crossbow")
	if f == 30:
		main.demo_skip_prep()
		main.waves.spawn_cursor = main.waves.spawn_plan.size()
		for i in range(6):
			main.demo_spawn_enemy("militia", 300.0 + float(i) * 44.0, -12.0 + float(i % 3) * 11.0)
	# 1.2–3.6s：领主靠近兵线，自动攻击；2.0s 回旋斩。
	if f >= 34 and f <= 108:
		var d := 350.0 + float(f - 34) * 2.4
		main.demo_set_player_pos(Data.path_point_at(d) + Vector2(-30, 42))
	if f == 60:
		main.demo_cast_skill()
	# 3.7s：切到第 4 波准备，补炮塔。
	if f == 110:
		main.demo_set_wave(3)
		main.demo_set_gold(1400)
		main.demo_build_tower(1, "cannon")
		main.demo_upgrade_tower(1)
		main.demo_build_tower(2, "cannon")
	# 3.9s：开战并摆出精英 + 盾兵 + 斥候。
	if f == 118:
		main.demo_skip_prep()
		main.waves.spawn_cursor = main.waves.spawn_plan.size()
		main.demo_spawn_enemy("runner", 512.0, -10.0)
		main.demo_spawn_enemy("runner", 536.0, 9.0)
		main.demo_spawn_enemy("shield", 576.0, 8.0)
		main.demo_spawn_enemy("elite", 616.0, -4.0)
		main.demo_spawn_enemy("shield", 652.0, 12.0)
	if f >= 120 and f <= 202:
		var d := 640.0 + sin(float(f) * 0.08) * 30.0
		main.demo_set_player_pos(Data.path_point_at(d) + Vector2(24, 64))
	if f == 150:
		main.demo_cast_skill()
	# 6.8s：切到第 8 波，Boss 登场。
	if f == 204:
		main.demo_set_wave(7)
		main.demo_set_gold(1600)
		main.demo_upgrade_tower(2)
	if f == 212:
		main.demo_skip_prep()
		main.waves.spawn_cursor = main.waves.spawn_plan.size()
		main.demo_spawn_enemy("boss", 700.0, 0.0)
		main.demo_spawn_enemy("militia", 742.0, -14.0)
		main.demo_spawn_enemy("militia", 768.0, 12.0)
		main.demo_spawn_enemy("militia", 794.0, -7.0)
		main.demo_spawn_enemy("militia", 820.0, 15.0)
	if f >= 214:
		var d := 742.0 + sin(float(f) * 0.07) * 24.0
		main.demo_set_player_pos(Data.path_point_at(d) + Vector2(-26, 66))
	if f == 250:
		main.demo_cast_skill()
