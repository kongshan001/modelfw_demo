extends SceneTree

# Tripo GLB 朝向/材质目检：四个正交方向 + 3/4 视角，浅灰底真实 GPU 渲染。
# 运行：godot --path godot-ai-3d-game --resolution 1280x720 -s tools/tripo_turntable.gd

const OUT := "/tmp/tripo_views"
const SIZE := Vector2i(768, 768)

const ASSETS := {
	"kart": "res://assets/ai/tripo/kart/kart.glb",
	"windmill": "res://assets/ai/tripo/windmill/windmill.glb",
}

var vp: SubViewport
var cam: Camera3D


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	await process_frame
	_build_stage()
	for key in ASSETS:
		await _capture(key, ASSETS[key])
	print("TRIPO_TURNTABLE_OK dir=%s" % OUT)
	quit(0)


func _build_stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#eef2f4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f4f7f8")
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	vp.add_child(world_env)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	key_light.light_color = Color("#fff4dc")
	key_light.light_energy = 1.2
	key_light.shadow_enabled = false
	vp.add_child(key_light)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	fill.light_color = Color("#dcefff")
	fill.light_energy = 0.6
	fill.shadow_enabled = false
	vp.add_child(fill)

	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.01
	cam.far = 100.0
	cam.current = true
	vp.add_child(cam)


func _capture(key: String, path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("LOAD_FAILED ", path)
		return
	var inst := packed.instantiate() as Node3D
	vp.add_child(inst)
	await process_frame
	var box := _combined_aabb(inst)
	var size := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var dist := size * 3.0 + 1.0
	cam.size = size * 1.22
	var center := box.get_center()
	var views := {
		"pos_z": Vector3(0.0, 0.15, 1.0),
		"neg_z": Vector3(0.0, 0.15, -1.0),
		"pos_x": Vector3(1.0, 0.15, 0.0),
		"neg_x": Vector3(-1.0, 0.15, 0.0),
		"3q_neg_z_pos_x": Vector3(0.72, 0.45, -0.72),
	}
	for view in views:
		var dir: Vector3 = views[view]
		cam.look_at_from_position(center + dir.normalized() * dist, center, Vector3.UP)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := vp.get_texture().get_image()
		var out := "%s/%s_%s.png" % [OUT, key, view]
		image.save_png(out)
		print("TRIPO_VIEW %s" % out)
	print("%s aabb_pos=%s aabb_size=%s" % [key, box.position, box.size])
	inst.queue_free()
	await process_frame


func _combined_aabb(root: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			var box := mi.global_transform * mi.get_aabb()
			if first:
				aabb = box
				first = false
			else:
				aabb = aabb.merge(box)
	return aabb
