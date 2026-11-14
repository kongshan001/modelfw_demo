extends Node3D

# 可运行的小型 3D 游戏 Demo：
# - 左侧 NPC：Soldier 原生 Idle
# - 玩家：Michelle 网格 + 隐藏 Soldier 骨架，通过 RetargetModifier3D 重定向
# - WASD 移动 / Shift 奔跑，第三人称跟随相机

const PlayerScript := preload("res://src/player.gd")

var player: Node3D
var camera: Camera3D
var _state_label: Label

func _ready() -> void:
	_build_environment()
	_build_lighting()
	_build_player()
	_build_camera()
	_build_hud()

func _process(delta: float) -> void:
	if player == null or camera == null:
		return
	var desired := player.position + Vector3(0.0, 2.2, 4.8)
	camera.position = camera.position.lerp(desired, min(1.0, delta * 8.0))
	camera.look_at(player.position + Vector3(0.0, 1.2, 0.0), Vector3.UP)
	if _state_label != null:
		_state_label.text = player.get_character_name() + " · " + player.get_state()

func _build_environment() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.12, 0.15, 0.18)
	ground_mat.roughness = 1.0
	ground_mat.metallic = 0.0
	ground.material_override = ground_mat
	add_child(ground)

	_add_pillar(Vector3(-6.5, 0.0, -3.5), Color(0.28, 0.42, 0.40), 2.8)
	_add_pillar(Vector3(6.5, 0.0, -2.5), Color(0.42, 0.30, 0.26), 2.2)
	_add_pillar(Vector3(7.0, 0.0, -5.0), Color(0.30, 0.36, 0.46), 3.2)
	_add_rock(Vector3(-3.8, 0.35, 2.8), 0.55)
	_add_rock(Vector3(4.8, 0.30, 1.2), 0.45)
	_add_rock(Vector3(-1.2, 0.25, -5.0), 0.35)

func _build_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	key.light_color = Color(1.0, 0.95, 0.85)
	key.light_energy = 2.0
	key.shadow_enabled = true
	add_child(key)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 150.0, 0.0)
	fill.light_color = Color(0.65, 0.80, 1.0)
	fill.light_energy = 0.7
	add_child(fill)

func _build_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0.0, 0.0, 0.0)
	add_child(player)

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "MainCamera"
	camera.fov = 50.0
	camera.position = Vector3(0.0, 2.2, 4.8)
	add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.075, 0.86)
	style.border_color = Color(1.0, 0.84, 0.46, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 14.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Mixamo → Godot 4.6 · Character Swap"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Tab: Michelle / Soldier / Xbot  ·  Space: Dance (all)"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	box.add_child(subtitle)

	var controls := Label.new()
	controls.text = "WASD Move  ·  Shift Run  ·  Tab Switch  ·  Space Dance"
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color(0.88, 0.88, 0.82))
	box.add_child(controls)

	_state_label = Label.new()
	_state_label.text = "Michelle · Idle"
	_state_label.add_theme_font_size_override("font_size", 18)
	_state_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	box.add_child(_state_label)

func _add_pillar(pos: Vector3, color: Color, height: float) -> void:
	var pillar := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.42
	mesh.height = height
	mesh.radial_segments = 8
	pillar.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	pillar.material_override = mat
	pillar.position = pos + Vector3(0.0, height * 0.5, 0.0)
	add_child(pillar)

func _add_rock(pos: Vector3, radius: float) -> void:
	var rock := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.4
	mesh.radial_segments = 12
	mesh.rings = 6
	rock.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.33, 0.36)
	mat.roughness = 1.0
	rock.material_override = mat
	rock.position = pos
	rock.scale = Vector3(1.0, 0.6, 0.8)
	add_child(rock)
