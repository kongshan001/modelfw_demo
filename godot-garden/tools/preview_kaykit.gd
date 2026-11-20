extends SceneTree

# 接入预演：低机位（俯角约 7°）下，程序化提灯守夜人 vs KayKit Rogue（CC0）。
# 只做截图，不改 GardenPatrol。
# KayKit 是 Q 版大头身；宽檐角色（Mage）在 16° 俯角会挡脸，这里改用 Rogue 并把机位压低。

const SPOT := Vector3(2.0, 0.0, 3.0)
const CAMERA_POS := Vector3(5.7, 1.55, 6.2)
const LOOK_AT := Vector3(2.0, 1.0, 3.0)

var _viewport: SubViewport
var _scene

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://screenshots"))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_scene = load("res://scenes/garden.tscn").instantiate()
	_viewport.add_child(_scene)
	await process_frame
	_scene.set_autoplay(false)
	_scene.set_ui_visible(false)
	_scene.set_time(18.2)
	_scene.set_film_camera(CAMERA_POS, LOOK_AT)

	var npc = _scene._world.patrols[0]
	npc.global_position = SPOT
	npc.rotation.y = _face(SPOT)
	npc.force_pause(20.0)
	await create_timer(1.4).timeout
	await _capture("preview_a_procedural.png")

	npc.visible = false
	var model = load("res://assets/models/kaykit/Rogue.glb").instantiate()
	model.scale = Vector3.ONE * 0.58
	model.position = SPOT
	model.rotation.y = _face(SPOT) + PI
	_scene._world.add_child(model)
	_hide_props(model)
	_nearest_filter(model)
	var player = model.find_child("AnimationPlayer", true, false)
	if player != null:
		player.play("Idle")
		player.seek(0.6, true)
	await process_frame
	_add_lantern(model)
	await create_timer(1.6).timeout
	await _capture("preview_b_kaykit_rogue.png")

	_scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)

func _face(pos: Vector3) -> float:
	var offset := CAMERA_POS - pos
	return atan2(-offset.x, -offset.z)

func _hide_props(root: Node3D) -> void:
	var keywords := ["Dagger", "Crossbow", "Knife", "Sword", "Arrow", "Bow", "Shield", "Quiver", "Axe", "Mug", "Wand", "Staff", "Spellbook"]
	for node in _all(root):
		if node is MeshInstance3D:
			for key in keywords:
				if String(node.name).contains(key):
					node.visible = false
					break

func _add_lantern(root: Node3D) -> void:
	var hand = root.find_child("handslot_l", true, false)
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * 0.9
	var base := root.global_position + Vector3(0.3, 1.0, -0.25)
	if hand != null:
		base = hand.global_position
	var toward_camera := (CAMERA_POS - base).normalized()
	holder.position = base + toward_camera * 0.16 + Vector3(0, -0.08, 0)
	_scene._world.add_child(holder)
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.12, 0.1, 0.08)
	frame.roughness = 0.6
	frame.metallic = 0.3
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.95, 0.72, 0.36)
	glass.emission_enabled = true
	glass.emission = Color(1.0, 0.7, 0.34)
	glass.emission_energy_multiplier = 2.6
	var box := BoxMesh.new()
	box.size = Vector3(0.16, 0.16, 0.16)
	var glass_box := BoxMesh.new()
	glass_box.size = Vector3(0.1, 0.13, 0.1)
	var frame_mesh := MeshInstance3D.new()
	frame_mesh.mesh = box
	frame_mesh.material_override = frame
	holder.add_child(frame_mesh)
	var glass_mesh := MeshInstance3D.new()
	glass_mesh.mesh = glass_box
	glass_mesh.material_override = glass
	glass_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glass_mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.42)
	light.light_energy = 1.1
	light.omni_range = 5.5
	light.shadow_enabled = false
	holder.add_child(light)

func _nearest_filter(root: Node) -> void:
	for node in _all(root):
		if node is MeshInstance3D and node.mesh != null:
			for index in node.mesh.get_surface_count():
				var material = node.mesh.surface_get_material(index)
				if material is StandardMaterial3D:
					material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

func _all(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child in node.get_children():
		out.append_array(_all(child))
	return out

func _capture(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := _viewport.get_texture().get_image()
	var path := "user://screenshots/" + file_name
	image.save_png(path)
	print("SCREENSHOT: " + ProjectSettings.globalize_path(path))
