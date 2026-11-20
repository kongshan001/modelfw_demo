extends Node2D

# 场景装配：铺瓦片、放道具、点烛光、给相机设边界。
# 技术点全部在这几个节点上：
#   Ground/Floor  地板层（y_sort 只为层内瓦片）
#   World         同时装 Walls 和 Player —— 玩家要和墙瓦片交错排序
#   Walls.y_sort_origin = 32  排序锚点落在菱形底边（瓦片中心 +32）

const MAP_SIZE := 14
const START := Vector2i(7, 11)
const RUG := Vector2i(9, 10)
const DARK := Color(0.23, 0.25, 0.33)

const LIGHT_TEX := preload("res://assets/fx/light.png")
const SHADOW_TEX := preload("res://assets/fx/shadow.png")
const MOTE_TEX := preload("res://assets/fx/mote.png")
const FLAME_TEX := preload("res://assets/fx/flame_glow.png")
const BARREL_TEX := preload("res://assets/props/barrel.png")
const CRATE_TEX := preload("res://assets/props/crate.png")
const VASE_TEX := preload("res://assets/props/vase.png")
const CANDLE_TEX := preload("res://assets/props/candle_stand.png")

const PROPS := [
	{"cell": Vector2i(11, 9), "tex": BARREL_TEX, "shadow": 0.5, "occ": 20.0},
	{"cell": Vector2i(12, 9), "tex": BARREL_TEX, "shadow": 0.5, "occ": 20.0},
	{"cell": Vector2i(3, 7), "tex": CRATE_TEX, "shadow": 0.55, "occ": 24.0},
	{"cell": Vector2i(12, 3), "tex": VASE_TEX, "shadow": 0.32, "occ": 12.0},
	{"cell": Vector2i(2, 12), "tex": VASE_TEX, "shadow": 0.32, "occ": 12.0},
]

const CANDLES := [
	Vector2i(2, 2), Vector2i(9, 2), Vector2i(3, 11),
	Vector2i(11, 11), Vector2i(7, 9), Vector2i(9, 4),
]

@onready var floor_layer: TileMapLayer = $Ground/Floor
@onready var world: Node2D = $World
@onready var walls: TileMapLayer = $World/Walls
@onready var player: IsoPlayer = $World/Player
@onready var lights: Node2D = $Lights
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var hud: IsoHud = $HUD

var y_sort_on := true
var lights_on := true

var _candle_lights: Array[PointLight2D] = []
var _time := 0.0


func _ready() -> void:
	_build_room()
	_spawn_props()
	_spawn_candles()
	_spawn_dust()
	_fit_camera()
	player.teleport(walls.map_to_local(START))
	player.get_node("Camera2D").reset_smoothing()
	hud.set_status(y_sort_on, lights_on)


func _process(delta: float) -> void:
	if not lights_on:
		return
	_time += delta
	for i in _candle_lights.size():
		var l := _candle_lights[i]
		var base: float = l.get_meta("base_energy", 1.0)
		l.energy = base * (1.0
			+ 0.09 * sin(_time * 7.1 + i * 1.7)
			+ 0.04 * sin(_time * 13.3 + i * 2.9))


# ── build ──────────────────────────────────────────────────────────────────
func _build_room() -> void:
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var cell := Vector2i(x, y)
			var variant := posmod(x * 7 + y * 13, 3)
			floor_layer.set_cell(cell, 0, Vector2i(variant, 0))
			if _is_wall(cell):
				walls.set_cell(cell, 0, Vector2i(posmod(x + y, 2), 1))
	floor_layer.set_cell(RUG, 0, Vector2i(3, 0))


func _is_wall(cell: Vector2i) -> bool:
	# 北侧两条边界墙（x=0 与 y=0）构成房间的“背板”
	if cell.x == 0 or cell.y == 0:
		return true
	# 房间中间的残墙：一排 + 一列，玩家可以绕到它后面
	if cell.y == 6 and cell.x >= 5 and cell.x <= 8:
		return true
	if cell.x == 5 and cell.y >= 6 and cell.y <= 9:
		return true
	# 两根孤柱
	if cell == Vector2i(10, 4) or cell == Vector2i(4, 10):
		return true
	return false


func _spawn_props() -> void:
	for item: Dictionary in PROPS:
		var pos := walls.map_to_local(item["cell"])
		var shadow_scale: float = item["shadow"]

		# 阴影先加：同 y 时先画，保证不盖住道具本体
		var shadow := Sprite2D.new()
		shadow.texture = SHADOW_TEX
		shadow.position = pos + Vector2(0, 2)
		shadow.scale = Vector2(shadow_scale, shadow_scale)
		world.add_child(shadow)

		var sprite := Sprite2D.new()
		sprite.texture = item["tex"]
		sprite.position = pos
		world.add_child(sprite)

		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var r: float = item["occ"]
		poly.polygon = PackedVector2Array([
			Vector2(0, -r * 0.5), Vector2(r, 0),
			Vector2(0, r * 0.5), Vector2(-r, 0),
		])
		occ.occluder = poly
		occ.position = pos
		world.add_child(occ)


func _spawn_candles() -> void:
	for cell in CANDLES:
		var pos := walls.map_to_local(cell)

		var shadow := Sprite2D.new()
		shadow.texture = SHADOW_TEX
		shadow.position = pos + Vector2(0, 2)
		shadow.scale = Vector2(0.32, 0.32)
		world.add_child(shadow)

		var stand := Sprite2D.new()
		stand.texture = CANDLE_TEX
		stand.position = pos
		world.add_child(stand)

		var light := PointLight2D.new()
		light.texture = LIGHT_TEX
		light.position = pos + Vector2(0, -76)
		light.color = Color(1.0, 0.71, 0.44)
		light.energy = 1.5
		light.texture_scale = 2.5
		light.shadow_enabled = true
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 4.0
		light.set_meta("base_energy", light.energy)
		lights.add_child(light)
		_candle_lights.append(light)

		var embers := CPUParticles2D.new()
		embers.texture = FLAME_TEX
		embers.position = pos + Vector2(0, -78)
		embers.amount = 5
		embers.lifetime = 0.9
		embers.direction = Vector2(0, -1)
		embers.spread = 28.0
		embers.initial_velocity_min = 5.0
		embers.initial_velocity_max = 14.0
		embers.gravity = Vector2(0, -10)
		embers.scale_amount_min = 0.1
		embers.scale_amount_max = 0.32
		embers.color = Color(1.0, 0.62, 0.28, 0.85)
		lights.add_child(embers)


func _spawn_dust() -> void:
	var dust := CPUParticles2D.new()
	dust.texture = MOTE_TEX
	dust.position = Vector2(0, 380)
	dust.amount = 36
	dust.lifetime = 7.0
	dust.preprocess = 4.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(760, 420)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 45.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 8.0
	dust.gravity = Vector2(1.5, -2.0)
	dust.scale_amount_min = 0.08
	dust.scale_amount_max = 0.3
	dust.color = Color(1.0, 0.86, 0.62, 0.22)
	lights.add_child(dust)


func _fit_camera() -> void:
	var cam: Camera2D = player.get_node("Camera2D")
	var top := walls.map_to_local(Vector2i(0, 0))
	var right := walls.map_to_local(Vector2i(MAP_SIZE - 1, 0))
	var left := walls.map_to_local(Vector2i(0, MAP_SIZE - 1))
	var bottom := walls.map_to_local(Vector2i(MAP_SIZE - 1, MAP_SIZE - 1))
	cam.limit_left = int(left.x) - 64
	cam.limit_right = int(right.x) + 64
	cam.limit_top = int(top.y) - 176
	cam.limit_bottom = int(bottom.y) + 64


# ── teaching toggles ───────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			toggle_y_sort()
		KEY_F2:
			toggle_lights()
		KEY_F3:
			get_tree().change_scene_to_file("res://scenes/pipeline_demo.tscn")
		KEY_F4:
			get_tree().change_scene_to_file("res://scenes/mod_demo.tscn")
		KEY_R:
			reset_player()


func toggle_y_sort() -> void:
	y_sort_on = not y_sort_on
	world.y_sort_enabled = y_sort_on
	walls.y_sort_enabled = y_sort_on
	hud.set_status(y_sort_on, lights_on)


func toggle_lights() -> void:
	lights_on = not lights_on
	lights.visible = lights_on
	canvas_modulate.color = DARK if lights_on else Color(1, 1, 1)
	hud.set_status(y_sort_on, lights_on)


func reset_player() -> void:
	player.teleport(walls.map_to_local(START))
	player.get_node("Camera2D").reset_smoothing()


# helpers for smoke / capture tools
func player_cell() -> Vector2i:
	return walls.local_to_map(walls.to_local(player.global_position))


func cell_pos(cell: Vector2i) -> Vector2:
	return walls.map_to_local(cell)
