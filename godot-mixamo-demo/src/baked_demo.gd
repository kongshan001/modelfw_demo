extends Node3D

# 离线烘焙演示：animation-retarget-kit 把 Soldier 的 Run 烘焙到 Michelle，
# 这里直接播放目标模型自带的 baked clip（不再用 RetargetModifier3D）。

const BAKED_SCENE := preload("res://assets/characters/baked/Michelle_Run.glb")
const DANCE_SCENE := preload("res://assets/characters/Michelle.glb")

const RUN_RADIUS := 4.2
const RUN_ANGULAR_SPEED := 0.8

# 前置 3/4 跟随镜头：在角色前方偏右，始终看向角色，展示正面跑姿。
const CAMERA_AHEAD := 1.8
const CAMERA_RIGHT := 3.3
const CAMERA_HEIGHT := 1.9
const CAMERA_LOOK_HEIGHT := 1.0

# 舞步使用运行时 demo 的固定正面机位，效果与 dance_demo.gif 一致。
const DANCE_CAMERA_POS := Vector3(0.0, 2.2, 4.8)
const DANCE_CAMERA_LOOK := Vector3(0.0, 1.2, 0.0)

enum Mode { DANCE, RUN }

var _camera: Camera3D
var _runner: Node3D
var _dancer: Node3D
var _run_ap: AnimationPlayer
var _dance_ap: AnimationPlayer
var _run_clip := ""
var _run_stage: Node3D
var _dance_stage: Node3D
var _mode := Mode.DANCE
var _run_angle := 0.0
var _state_label: Label

func _ready() -> void:
	_build_environment()
	_build_lighting()
	_build_models()
	_build_camera()
	_build_hud()
	set_dance_mode()

func _process(delta: float) -> void:
	if _mode != Mode.RUN:
		return
	_update_run(delta)

func _update_run(delta: float) -> void:
	_run_angle += delta * RUN_ANGULAR_SPEED
	if _runner == null or _camera == null:
		return
	var pos := Vector3(cos(_run_angle) * RUN_RADIUS, 0.0, sin(_run_angle) * RUN_RADIUS)
	_runner.position = pos
	var forward := Vector3(-sin(_run_angle), 0.0, cos(_run_angle))
	_runner.rotation.y = atan2(forward.x, forward.z)
	var right := Vector3(forward.z, 0.0, -forward.x)
	_camera.position = pos + forward * CAMERA_AHEAD + right * CAMERA_RIGHT + Vector3(0.0, CAMERA_HEIGHT, 0.0)
	_camera.look_at(pos + Vector3(0.0, CAMERA_LOOK_HEIGHT, 0.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_toggle_mode()
		get_viewport().set_input_as_handled()

func _toggle_mode() -> void:
	if _mode == Mode.DANCE:
		set_run_mode()
	else:
		set_dance_mode()

func set_dance_mode() -> void:
	_mode = Mode.DANCE
	if _runner != null:
		_runner.visible = false
		_runner.position = Vector3.ZERO
	if _run_ap != null:
		_run_ap.stop()
	if _dancer != null:
		_dancer.visible = true
		_dancer.position = Vector3.ZERO
		_dancer.rotation = Vector3.ZERO
	if _dance_ap != null and _dance_ap.has_animation("SambaDance"):
		_dance_ap.play("SambaDance")
	if _run_stage != null:
		_run_stage.visible = false
	if _dance_stage != null:
		_dance_stage.visible = true
	if _camera != null:
		_camera.position = DANCE_CAMERA_POS
		_camera.look_at(DANCE_CAMERA_LOOK, Vector3.UP)
	_update_mode_label()

func set_run_mode() -> void:
	_mode = Mode.RUN
	if _dancer != null:
		_dancer.visible = false
	if _dance_ap != null:
		_dance_ap.stop()
	if _runner != null:
		_runner.visible = true
	if _run_ap != null and _run_clip != "":
		_run_ap.play(_run_clip)
	if _run_stage != null:
		_run_stage.visible = true
	if _dance_stage != null:
		_dance_stage.visible = false
	_run_angle = 0.0
	_update_run(0.0)
	_update_mode_label()

func _update_mode_label() -> void:
	if _state_label == null:
		return
	_state_label.text = "Michelle · SambaDance (native)" if _mode == Mode.DANCE else "Michelle · Run (baked)"

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

	_run_stage = Node3D.new()
	_run_stage.name = "RunStage"
	add_child(_run_stage)
	_add_track_markers(_run_stage)
	_add_pillar(_run_stage, Vector3(-9.5, 0.0, -4.0), Color(0.28, 0.42, 0.40), 3.4)
	_add_pillar(_run_stage, Vector3(9.8, 0.0, -3.0), Color(0.42, 0.30, 0.26), 2.8)
	_add_pillar(_run_stage, Vector3(7.2, 0.0, 8.5), Color(0.30, 0.36, 0.46), 3.0)
	_add_pillar(_run_stage, Vector3(-7.0, 0.0, 8.0), Color(0.36, 0.40, 0.30), 2.6)
	_add_pillar(_run_stage, Vector3(-10.5, 0.0, 3.5), Color(0.34, 0.32, 0.44), 2.4)
	_add_rock(_run_stage, Vector3(-8.2, 0.35, 2.2), 0.55)
	_add_rock(_run_stage, Vector3(8.8, 0.30, 4.0), 0.45)

	# 舞步沿用运行时 demo 的近景舞台，保证与 dance_demo.gif 的观感一致。
	_dance_stage = Node3D.new()
	_dance_stage.name = "DanceStage"
	add_child(_dance_stage)
	_add_pillar(_dance_stage, Vector3(-6.5, 0.0, -3.5), Color(0.28, 0.42, 0.40), 2.8)
	_add_pillar(_dance_stage, Vector3(6.5, 0.0, -2.5), Color(0.42, 0.30, 0.26), 2.2)
	_add_pillar(_dance_stage, Vector3(7.0, 0.0, -5.0), Color(0.30, 0.36, 0.46), 3.2)
	_add_rock(_dance_stage, Vector3(-3.8, 0.35, 2.8), 0.55)
	_add_rock(_dance_stage, Vector3(4.8, 0.30, 1.2), 0.45)
	_add_rock(_dance_stage, Vector3(-1.2, 0.25, -5.0), 0.35)

func _add_track_markers(parent: Node3D) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RUN_RADIUS - 0.03
	torus.outer_radius = RUN_RADIUS + 0.03
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.28, 0.20)
	mat.roughness = 0.9
	ring.material_override = mat
	ring.position = Vector3(0.0, 0.02, 0.0)
	parent.add_child(ring)

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

func _build_models() -> void:
	var model: Node3D = BAKED_SCENE.instantiate()
	model.name = "BakedMichelle"
	_runner = model
	add_child(model)

	_run_ap = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _run_ap != null and not _run_ap.get_animation_list().is_empty():
		_run_clip = _run_ap.get_animation_list()[0]
		var anim := _run_ap.get_animation(_run_clip)
		anim.loop_mode = Animation.LOOP_LINEAR
		_run_ap.play(_run_clip)

	var dance: Node3D = DANCE_SCENE.instantiate()
	dance.name = "NativeMichelle"
	add_child(dance)
	_dancer = dance
	_dance_ap = dance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _dance_ap != null and _dance_ap.has_animation("SambaDance"):
		var dance_anim := _dance_ap.get_animation("SambaDance")
		dance_anim.loop_mode = Animation.LOOP_LINEAR

func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "BakedCamera"
	_camera.fov = 50.0
	_camera.position = DANCE_CAMERA_POS
	add_child(_camera)
	_camera.current = true
	_camera.look_at(DANCE_CAMERA_LOOK, Vector3.UP)

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
	title.text = "Michelle Showcase · Dance + Baked Run"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.62))
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Native SambaDance · Soldier Run → Michelle (animation-retarget-kit)"
	subtitle.add_theme_font_size_override("font_size", 17)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.82, 0.92))
	box.add_child(subtitle)

	var controls := Label.new()
	controls.text = "Space: Dance / Baked Run"
	controls.add_theme_font_size_override("font_size", 17)
	controls.add_theme_color_override("font_color", Color(0.88, 0.88, 0.82))
	box.add_child(controls)

	_state_label = Label.new()
	_state_label.text = "Michelle · SambaDance (native)"
	_state_label.add_theme_font_size_override("font_size", 18)
	_state_label.add_theme_color_override("font_color", Color(0.55, 0.95, 0.72))
	box.add_child(_state_label)

func _add_pillar(parent: Node3D, pos: Vector3, color: Color, height: float) -> void:
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
	parent.add_child(pillar)

func _add_rock(parent: Node3D, pos: Vector3, radius: float) -> void:
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
	parent.add_child(rock)
