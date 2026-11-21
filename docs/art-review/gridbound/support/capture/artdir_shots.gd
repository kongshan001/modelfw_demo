extends SceneTree

# 美术评审用的临时截图脚本（只存在于 /tmp 副本，不进入项目）。
# 目的：补拍交互高亮状态（召唤金格 / 移动青格 / 攻击红圈 / 单位选中），
# 1280 原生渲染见同目录 artdir_native.gd。

const OUT := "/Users/ks_128/Documents/modelfw_demo/docs/art-review/gridbound"
const SIZE := Vector2i(1920, 1080)

var _vp: SubViewport
var _scene


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_vp = SubViewport.new()
	_vp.size = SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(_vp)
	_scene = load("res://scenes/main.tscn").instantiate()
	_vp.add_child(_scene)
	await _settle()
	await create_timer(0.8).timeout

	# A. 单位选中：青色可移动 + 红色可攻击 + 金色选中环
	var uids: Dictionary = _scene.demo_showcase()
	await create_timer(0.6).timeout
	_scene.demo_select_unit(int(uids["f1_sunstonetemplar"]))
	await create_timer(0.4).timeout
	await _shot("ev_highlight_unit_1920")

	# B. 手牌选中：金色召唤格 + 选中卡
	uids = _scene.demo_showcase()
	await create_timer(0.6).timeout
	_scene.demo_select_hand(0)
	await create_timer(0.4).timeout
	await _shot("ev_highlight_summon_1920")

	print("ARTDIR_SHOTS_OK")
	quit(0)


func _settle() -> void:
	for _i in 3:
		await process_frame
	await RenderingServer.frame_post_draw


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _vp.get_texture().get_image()
	var path := OUT + "/" + shot_name + ".png"
	var err := image.save_png(path)
	if err != OK:
		printerr("failed to save ", path, ": ", err)
	else:
		print("SHOT ", path, " ", image.get_width(), "x", image.get_height())
