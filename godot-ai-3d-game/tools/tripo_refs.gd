extends SceneTree

# Tripo 图生 3D 的原创参考图：1024×1024、浅灰纯色底、真实 GPU 渲染。
# 车辆参考只保留车体（隐藏车轮/驾驶员/尾旗/尾灯/尾焰），
# 风车参考只保留塔身（隐藏旋转叶片/草堆/土台），
# 这样游戏内仍由程序化车轮滚动/转向、程序化叶片旋转。
# 运行：
#   godot --path godot-ai-3d-game --resolution 1280x720 -s tools/tripo_refs.gd

const OUT := "/tmp/tripo_refs"
const SIZE := Vector2i(1024, 1024)

var vp: SubViewport
var cam: Camera3D
var shot_count := 0


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.transparent_bg = false
	root.add_child(vp)
	await process_frame

	await _capture_kart()
	await _capture_windmill()

	print("TRIPO_REFS_OK count=%d dir=%s" % [shot_count, OUT])
	quit(0)


func _make_stage() -> Node3D:
	var stage := Node3D.new()
	vp.add_child(stage)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#eef2f4")
	env.background_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4f7f8")
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	stage.add_child(world_env)

	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	key.light_color = Color("#fff4dc")
	key.light_energy = 1.15
	key.shadow_enabled = false
	stage.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-28.0, 146.0, 0.0)
	fill.light_color = Color("#dcefff")
	fill.light_energy = 0.55
	fill.shadow_enabled = false
	stage.add_child(fill)

	cam = Camera3D.new()
	cam.name = "RefCamera"
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.05
	cam.far = 200.0
	cam.current = true
	stage.add_child(cam)
	return stage


func _capture_kart() -> void:
	var stage := _make_stage()
	var kart := KartVisual.new()
	kart.name = "KartRef"
	kart.setup(Color("#fff0d2"), Color("#24d3d2"), true)
	stage.add_child(kart)

	# 只留车体几何；车轮/驾驶员/装饰/特效在游戏内继续由代码驱动。
	var wheels := kart.get_node_or_null("Wheels")
	if wheels != null:
		wheels.visible = false
	var shadow := kart.get_node_or_null("BlobShadow")
	if shadow != null:
		shadow.visible = false
	var body := kart.get_node_or_null("Body")
	if body != null:
		for child in body.get_children():
			if child.name in ["FoxDriver", "Scarf", "Antenna", "Pennant", "TailLamp", "BoostFlame", "SteeringWheel"]:
				child.visible = false
			if child is Node3D:
				for grandchild in child.get_children():
					if grandchild.name == "TailLamp":
						grandchild.visible = false

	cam.size = 4.15
	await _snap("kart_3q", Vector3(4.35, 2.55, -5.15), Vector3(0.0, 0.60, 0.10))

	cam.size = 3.60
	await _snap("kart_front", Vector3(0.0, 1.75, -7.0), Vector3(0.0, 0.62, 0.0))

	cam.size = 3.60
	await _snap("kart_side", Vector3(7.0, 1.75, 0.0), Vector3(0.0, 0.62, 0.0))

	stage.queue_free()
	await process_frame


func _capture_windmill() -> void:
	var stage := _make_stage()
	# 借真实 RaceWorld 的风车构建，再隐藏其余场景，避免复制一份几何。
	var world: Node = load("res://scenes/main.tscn").instantiate()
	stage.add_child(world)
	await process_frame
	await process_frame
	if world is RaceWorld:
		(world as RaceWorld).capture_freeze = true
		(world as RaceWorld).hud.visible = false
	for child in world.get_children():
		if child.name == "Windmill":
			continue
		if child is WorldEnvironment:
			(child as WorldEnvironment).environment = null
		elif child is Node3D or child is CanvasLayer:
			child.visible = false
	var mill := world.get_node_or_null("Windmill") as Node3D
	if mill == null:
		push_error("tripo_refs: Windmill not found")
		return
	for child in mill.get_children():
		if child.name in ["Rotor", "Mound", "Hay0", "Hay1", "Hay2"]:
			child.visible = false

	# 风车根节点在 (2,0,-8)，朝向 -0.55 rad；机位按世界坐标布置。
	cam.size = 12.4
	var mill_center := mill.global_position + Vector3(0.0, 5.15, 0.0)
	await _snap("windmill_3q", mill.global_position + Vector3(13.0, 6.4, -1.5), mill_center)

	stage.queue_free()
	await process_frame


func _snap(image_name: String, cam_pos: Vector3, target: Vector3) -> void:
	# RaceWorld 自带 ChaseCamera；每张图前重新夺回当前相机。
	cam.current = true
	cam.look_at_from_position(cam_pos, target, Vector3.UP)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	var path := "%s/%s.png" % [OUT, image_name]
	image.save_png(path)
	shot_count += 1
	print("TRIPO_REF %s -> %s" % [image_name, path])
