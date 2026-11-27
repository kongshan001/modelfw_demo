extends SceneTree

# 真实 GPU 剪影自检：把所有可见几何替换为纯黑 unshaded 材质，白底、隐藏天空/辉光/萤火/光柱，
# 从世界 SubViewport 直接 3× 最近邻放大到 1920×1080。
# 用途：检查角色与场景在纯黑剪影下是否仍有可读轮廓（不进入后期色调/抖动）。

const MAIN_SCENE := "res://scenes/main.tscn"
const OUT_PATH := "res://docs/shots/14_silhouette_1920.png"

var main
var cap: SubViewport
var cap_world: TextureRect


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_position(Vector2i(40, 40))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	var packed: PackedScene = load(MAIN_SCENE)
	main = packed.instantiate()
	root.add_child(main)
	await _frames(50)

	main.set_param("auto", false)
	main.set_time_of_day(0.55)
	main.world.keeper.teleport(Vector3(0.9, 0.15, 2.2), PI)
	main.world.keeper.set_walk_preview(true, 1.25)
	main.set_camera_override(Vector3(0.9, 0.95, 2.2), 20.0, 3.0, 3.0)
	main.set_ui_visible(false)
	main.hud.set_ui_visible(false)
	main.prewarm(1.0)
	await _frames(10)

	_apply_silhouette()
	await _frames(12)
	_setup_capture()
	await _frames(16)
	var img: Image = cap.get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT_PATH)
	img.save_png(path)
	print("SILHOUETTE_DONE ", path, " ", img.get_size())
	quit(0)


func _apply_silhouette() -> void:
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0, 0, 0)
	black.disable_receive_shadows = true

	var world = main.world
	# 白底 + 隐藏天穹。
	if world.env != null:
		world.env.background_mode = Environment.BG_COLOR
		world.env.background_color = Color(1, 1, 1)
		world.env.ambient_light_energy = 0.0
	for child in world.get_children():
		if child.name == "SkyDome":
			child.visible = false
	# 隐藏会干扰剪影的透明/发光物体。
	if world.fireflies != null:
		world.fireflies.visible = false
	for s in world.shaft_nodes:
		s.visible = false
	for lamp in world.lamps:
		for key in ["glow", "pool", "reflect"]:
			var n = lamp.get(key, null)
			if n != null:
				n.visible = false
		var l = lamp.get("light", null)
		if l != null:
			l.visible = false
	# 只保留角色 + 环境（白底），隐藏场景几何，得到干净的纯黑剪影。
	for child in world.get_children():
		if child == world.keeper or child is WorldEnvironment:
			continue
		child.visible = false
	# 角色接触阴影 / 地面光池。
	_hide_named(world, ["ContactShadow", "LanternPool", "ClickMarker"])

	# 所有几何统一纯黑。
	for node in _all_nodes(world):
		if node is GeometryInstance3D:
			node.material_override = black
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 白底兜底。
	RenderingServer.set_default_clear_color(Color(1, 1, 1))


func _all_nodes(root_node: Node) -> Array:
	var out: Array = []
	var stack: Array = [root_node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


func _hide_named(root_node: Node, names: Array) -> void:
	for n in _all_nodes(root_node):
		if names.has(String(n.name)):
			n.visible = false


func _setup_capture() -> void:
	cap = SubViewport.new()
	cap.size = Vector2i(1920, 1080)
	cap.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	cap.msaa_2d = Viewport.MSAA_DISABLED
	cap.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	cap.use_taa = false
	cap.gui_disable_input = true
	cap.handle_input_locally = false
	root.add_child(cap)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1)
	bg.size = Vector2(1920, 1080)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(bg)
	cap_world = TextureRect.new()
	cap_world.texture = main.world_viewport.get_texture()
	cap_world.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cap_world.stretch_mode = TextureRect.STRETCH_SCALE
	cap_world.position = Vector2.ZERO
	cap_world.size = Vector2(1920, 1080)
	cap_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(cap_world)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
