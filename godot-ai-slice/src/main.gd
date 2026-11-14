extends Node3D

# Vertical slice entry: builds a tiny sky-island level in code, then hands the
# loop to Game/HUD/Player/Coin/Portal. Keep this file readable: AI agents will
# be asked to extend it.

const PlayerScript := preload("res://src/player.gd")
const CoinScript := preload("res://src/coin.gd")
const PortalScript := preload("res://src/portal.gd")
const HudScript := preload("res://src/hud.gd")

var player: CharacterBody3D
var portal: Area3D
var hud: CanvasLayer
var _coins: Array[Node] = []

func _ready() -> void:
	_build_environment()
	_build_level()
	_build_player()
	_build_portal()
	_build_hud()
	Game.cores_changed.connect(_on_cores_changed)
	Game.reset_to_title()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F1:
		if hud != null:
			hud.call("toggle_debug")
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_R and Game.state != Game.TITLE:
		restart_level()
		get_viewport().set_input_as_handled()
		return
	if Game.state == Game.TITLE and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		start_game()
		get_viewport().set_input_as_handled()

func start_game() -> void:
	if Game.state != Game.TITLE:
		return
	_reset_level()
	Game.start()

func restart_level() -> void:
	_reset_level()
	Game.start()

func force_win() -> void:
	if Game.state == Game.TITLE:
		Game.start()
	for coin in _coins:
		coin.call("collect")
	if portal != null:
		portal.call("set_active", true)
		portal.call("trigger")

func _reset_level() -> void:
	for coin in _coins:
		coin.call("reset")
	if portal != null:
		portal.call("reset")
	if player != null:
		player.call("respawn")

func _on_cores_changed(collected: int, total: int) -> void:
	if portal != null:
		portal.call("set_active", collected >= total)

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.58, 0.78, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.8, 0.94)
	env.ambient_light_energy = 1.1
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	add_child(sun)

	_add_cloud(Vector3(-11.0, -4.5, -8.0), 3.0)
	_add_cloud(Vector3(9.0, -5.0, -11.0), 3.6)
	_add_cloud(Vector3(-4.0, -6.0, 10.0), 2.6)
	_add_cloud(Vector3(12.0, -3.5, 5.0), 2.2)

func _build_level() -> void:
	_add_island(Vector3(0.0, -0.5, 0.0), 5.5, 1.0, Color(0.55, 0.86, 0.42))
	_add_island(Vector3(6.2, 0.6, 2.8), 2.2, 0.6, Color(0.58, 0.82, 0.4))
	_add_island(Vector3(-5.4, 1.2, 4.2), 2.4, 0.6, Color(0.54, 0.8, 0.38))
	_add_island(Vector3(2.0, 1.8, -5.5), 2.0, 0.6, Color(0.6, 0.86, 0.45))
	_add_island(Vector3(5.2, 0.9, -4.2), 2.4, 0.6, Color(0.56, 0.82, 0.42))

	_add_tree(Vector3(-3.2, 0.0, 0.8), 1.0)
	_add_tree(Vector3(3.0, 0.0, -0.5), 0.85)
	_add_tree(Vector3(-1.2, 0.0, -2.8), 1.1)
	_add_tree(Vector3(2.5, 0.0, 2.0), 0.75)
	_add_tree(Vector3(7.0, 0.9, 3.5), 0.8)
	_add_tree(Vector3(-6.3, 1.5, 4.8), 0.9)
	_add_rock(Vector3(-4.2, 0.0, 2.8), 0.55)
	_add_rock(Vector3(4.1, 0.0, 1.0), 0.45)
	_add_rock(Vector3(0.6, 0.0, -4.2), 0.5)
	_add_rock(Vector3(6.3, 1.2, -4.6), 0.4)

	_build_coin(Vector3(0.0, 1.1, 2.8))
	_build_coin(Vector3(6.2, 1.9, 2.8))
	_build_coin(Vector3(-5.4, 2.5, 4.2))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PlayerScript)
	player.position = Vector3(0.0, 1.1, 0.0)
	add_child(player)

func _build_portal() -> void:
	portal = Area3D.new()
	portal.name = "Portal"
	portal.set_script(PortalScript)
	portal.position = Vector3(5.2, 1.2, -4.2)
	add_child(portal)

func _build_coin(pos: Vector3) -> void:
	var coin := Area3D.new()
	coin.set_script(CoinScript)
	coin.position = pos
	add_child(coin)
	_coins.append(coin)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.name = "HUD"
	hud.set_script(HudScript)
	add_child(hud)

func _add_island(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = "Island"
	body.position = pos
	add_child(body)

	var rock_mesh := MeshInstance3D.new()
	var rock_cylinder := CylinderMesh.new()
	rock_cylinder.top_radius = radius
	rock_cylinder.bottom_radius = radius * 0.82
	rock_cylinder.height = height
	rock_cylinder.radial_segments = 32
	rock_mesh.mesh = rock_cylinder
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.36, 0.32, 0.27)
	rock_mat.roughness = 0.95
	rock_mesh.material_override = rock_mat
	body.add_child(rock_mesh)

	var cap_mesh := MeshInstance3D.new()
	var cap_cylinder := CylinderMesh.new()
	cap_cylinder.top_radius = radius * 0.99
	cap_cylinder.bottom_radius = radius * 0.99
	cap_cylinder.height = 0.08
	cap_cylinder.radial_segments = 32
	cap_mesh.mesh = cap_cylinder
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = color
	cap_mat.roughness = 0.9
	cap_mesh.material_override = cap_mat
	cap_mesh.position = Vector3(0.0, height * 0.5 - 0.01, 0.0)
	body.add_child(cap_mesh)

	var shape := CollisionShape3D.new()
	var collision := CylinderShape3D.new()
	collision.radius = radius
	collision.height = height
	shape.shape = collision
	body.add_child(shape)

func _add_cloud(pos: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.15
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	mesh.position = pos
	mesh.scale = Vector3(1.7, 0.45, 1.0)
	add_child(mesh)

func _add_tree(pos: Vector3, scale: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.scale = Vector3.ONE * scale
	add_child(root)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.22
	trunk_mesh.height = 1.2
	trunk_mesh.radial_segments = 8
	trunk.mesh = trunk_mesh
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.45, 0.28, 0.16)
	trunk_mat.roughness = 0.95
	trunk.material_override = trunk_mat
	trunk.position = Vector3(0.0, 0.6, 0.0)
	root.add_child(trunk)

	var canopy := MeshInstance3D.new()
	var canopy_mesh := SphereMesh.new()
	canopy_mesh.radius = 0.85
	canopy_mesh.height = 1.5
	canopy.mesh = canopy_mesh
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.22, 0.62, 0.25)
	canopy_mat.roughness = 0.85
	canopy.material_override = canopy_mat
	canopy.position = Vector3(0.0, 1.55, 0.0)
	root.add_child(canopy)

func _add_rock(pos: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 1.4
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.48)
	mat.roughness = 1.0
	mesh.material_override = mat
	mesh.position = pos + Vector3(0.0, radius * 0.5, 0.0)
	mesh.scale = Vector3(1.0, 0.6, 0.85)
	add_child(mesh)
