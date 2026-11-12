extends Node3D

# 离线烘焙演示：animation-retarget-kit 把 Soldier 的 Run 烘焙到 Michelle，
# 这里直接播放目标模型自带的 baked clip（不再用 RetargetModifier3D）。

const BAKED_SCENE := preload("res://assets/characters/baked/Michelle_Run.glb")

var _camera: Camera3D
var _angle := 0.65
var _state_label: Label

func _ready() -> void:
	_build_environment()
	_build_lighting()
	_build_model()
	_build_camera()
	_build_hud()

func _process(delta: float) -> void:
	_angle += delta * 0.22
	var center := Vector3(0.0, 1.0, 0.0)
	_camera.position = Vector3(sin(_angle) * 3.4, 1.55, cos(_angle) * 3.4)
	_camera.look_at(center, Vector3.UP)

func _build_environment() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.115, 0.145, 0.175)
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 2.35
	torus.outer_radius = 2.45
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.48, 0.40, 0.24)
	ring_mat.roughness = 0.7
	ring.material_override = ring_mat
	ring.position = Vector3(0.0, 0.03, 0.0)
	add_child(ring)

	_add_pillar(Vector3(-5.5, 0.0, -3.5), Color(0.28, 0.42, 0.40), 2.8)
	_add_pillar(Vector3(5.8, 0.0, -2.0), Color(0.42, 0.30, 0.26), 2.2)
	_add_pillar(Vector3(4.5, 0.0, 4.2), Color(0.30, 0.36, 0.46), 3.0)
	_add_rock(Vector3(-3.8, 0.35, 3.0), 0.55)
	_add_rock(Vector3(4.6, 0.30, 1.4), 0.45)

func _build_lighting() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_energy = 0.9
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

func _build_model() -> void:
	var model: Node3D = BAKED_SCENE.instantiate()
	model.name = "BakedMichelle"
	add_child(model)
	var ap := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap != null and not ap.get_animation_list().is_empty():
		var clip_name: String = ap.get_animation_list()[0]
		var anim := ap.get_animation(clip_name)
		anim.loop_mode = Animation.LOOP_LINEAR
		ap.play(clip_name)

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "BakedCamera"
	_camera.fov = 45.0
	_camera.position = Vector3(sin(_angle) * 3.4, 1.55, cos(_angle) * 3.4)
	add_child(_camera)
	_camera.current = true
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.custom_minimum_size = Vector2(680.0, 0.0)
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
	title.text = "Baked Retarget · Soldier Run → Michelle"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "animation-retarget-kit: inspect → retarget → validate → Godot"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	box.add_child(subtitle)

	var controls := Label.new()
	controls.text = "No input · Camera orbit · Baked clip loop"
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color(0.88, 0.88, 0.82))
	box.add_child(controls)

	_state_label = Label.new()
	_state_label.text = "Michelle · Run (baked)"
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
