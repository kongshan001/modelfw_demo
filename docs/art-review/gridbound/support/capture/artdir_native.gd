extends SceneTree

# 美术评审临时脚本（仅 /tmp 副本）：补拍 1280×720 原生渲染。
# 注意：必须在场景 _ready 之前设定 SubViewport 尺寸，根节点才会按 1.0 scale 布局。

const OUT := "/Users/ks_128/Documents/modelfw_demo/docs/art-review/gridbound"
const SIZE := Vector2i(1280, 720)

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
	print("NATIVE scene=", _scene.size, " scale=", _scene.scale)

	var uids: Dictionary = _scene.demo_showcase()
	await create_timer(0.6).timeout
	_scene.demo_select_unit(int(uids["f1_sunstonetemplar"]))
	await create_timer(0.4).timeout
	await _shot("ev_native_1280_highlight")

	uids = _scene.demo_showcase()
	await create_timer(0.6).timeout
	_scene.demo_select_hand(2)
	_scene.demo_hover_card(2, true)
	await create_timer(0.4).timeout
	await _shot("ev_native_1280_hand_hover")

	print("ARTDIR_NATIVE_OK")
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
