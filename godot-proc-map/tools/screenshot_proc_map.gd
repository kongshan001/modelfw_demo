extends SceneTree

# 1920×1080 GPU 实拍：
#   01 群岛 Hero（完成态）
#   02 群岛阶段：海拔场（单步生成）
#   03 群岛调试：群系 + 区域 + 连通 + 边界
#   04 群岛噪声：湿度场覆盖
#   05 地牢 Hero（完成态）
#   06 地牢调试：BSP + 房间 + 连通
#   07 群岛 Hero 近景（POI/海岸）
# 用法：godot --path . --resolution 1280x720 -s tools/screenshot_proc_map.gd

const OUT := "res://docs/shots"
const SIZE := Vector2i(1920, 1080)
const BIOME_SEED := "9001"
const DUNGEON_SEED := "2137"

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_2d = Viewport.MSAA_DISABLED
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await process_frame
	await process_frame
	_scene.api_set_capture_mode(true)
	await create_timer(0.6).timeout

	# 01 群岛 Hero
	_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	await create_timer(0.5).timeout
	await _shot("01_biome_hero_1920")

	# 02 海拔场阶段
	_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
	await create_timer(0.35).timeout
	await _shot("02_biome_elevation_stage_1920")

	# 03 调试叠加
	_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
	_scene.api_finish()
	_scene.api_set_debug({"biomes": true, "rooms": true, "connectivity": true, "bounds": true})
	await create_timer(0.4).timeout
	await _shot("03_biome_debug_1920")

	# 04 湿度噪声
	_scene.api_set_debug({"noise": true, "bounds": true})
	_scene.api_set_noise_field("moisture")
	await create_timer(0.35).timeout
	await _shot("04_biome_moisture_1920")

	# 05 地牢 Hero
	_scene.api_new("dungeon", DUNGEON_SEED, 0, 12.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	await create_timer(0.45).timeout
	await _shot("05_dungeon_hero_1920")

	# 06 地牢调试
	_scene.api_set_debug({"rooms": true, "connectivity": true, "bounds": true})
	await create_timer(0.35).timeout
	await _shot("06_dungeon_debug_1920")

	# 07 群岛近景（第一个 POI）
	_scene.api_new("biome", BIOME_SEED, 0, 0.0, true)
	_scene.api_finish()
	_scene.api_set_debug({})
	var gen = _scene.api_get_gen()
	var focus_poi = null
	var best_wd := 999
	for poi in gen.pois:
		var cell: Vector2i = poi["cell"]
		if cell.x > int(gen.width * 0.66) or cell.y > int(gen.height * 0.72):
			continue
		var wd := int(poi.get("water_distance", 99))
		if wd < best_wd:
			best_wd = wd
			focus_poi = poi
	if focus_poi == null and gen.pois.size() > 0:
		focus_poi = gen.pois[0]
	if focus_poi != null:
		_scene.api_focus(focus_poi["pos"], 2.15)
	else:
		_scene.api_focus(Vector2(gen.width * 16, gen.height * 16), 2.0)
	await create_timer(0.35).timeout
	await _shot("07_biome_closeup_1920")

	print("PROC_MAP_SHOTS_OK")
	quit(0)


func _shot(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_size())
