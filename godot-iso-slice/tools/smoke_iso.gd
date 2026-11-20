extends SceneTree

# 无头验收：瓦片/排序/碰撞/光照/动画/移动全都断言一遍。
# Run: godot --headless --path godot-iso-slice -s tools/smoke_iso.gd

const WALL_CELLS := 36  # 边界 27 + 残墙 L 7 + 孤柱 2

var _fails: Array[String] = []


func _initialize() -> void:
	var scene: Node = load("res://scenes/dungeon.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.2).timeout

	var player: IsoPlayer = scene.get_node("World/Player")
	var walls: TileMapLayer = scene.get_node("World/Walls")
	var floor_layer: TileMapLayer = scene.get_node("Ground/Floor")
	var world: Node2D = scene.get_node("World")
	var lights: Node2D = scene.get_node("Lights")
	var canvas_mod: CanvasModulate = scene.get_node("CanvasModulate")
	var camera: Camera2D = player.get_node("Camera2D")

	# ── 排序结构 ──
	_check(world.y_sort_enabled, "World.y_sort_enabled should be true")
	_check(walls.y_sort_enabled, "Walls.y_sort_enabled should be true")
	_check(walls.y_sort_origin == 32, "Walls.y_sort_origin should be 32")
	_check(camera.limit_right > camera.limit_left, "camera limits not set")

	# ── 瓦片与 TileData ──
	_check(floor_layer.get_used_cells().size() == 196, "floor cell count != 196")
	_check(walls.get_used_cells().size() == WALL_CELLS,
		"wall cell count %d != %d" % [walls.get_used_cells().size(), WALL_CELLS])
	var td := walls.get_cell_tile_data(Vector2i(7, 6))
	_check(td != null, "no wall TileData at (7,6)")
	if td:
		_check(td.get_collision_polygons_count(0) == 1, "wall collision polygon missing")
		_check(td.get_occluder_polygons_count(0) == 1, "wall occluder polygon missing")
		_check(td.texture_origin == Vector2i(0, 48), "tile texture_origin != (0,48)")
	var tileset := walls.tile_set
	_check(tileset.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC, "tile shape != isometric")
	_check(tileset.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN, "tile layout != diamond down")

	# ── 角色锚点与动画 ──
	var sprite: AnimatedSprite2D = player.get_node("Sprite")
	var col: CollisionShape2D = player.get_node("CollisionShape2D")
	_check(sprite.position == Vector2.ZERO, "sprite must sit at the foot origin")
	_check(col.position.y < 0.0 and col.position.y > -20.0,
		"collision capsule should hug the feet")
	var frames := sprite.sprite_frames
	_check(frames != null, "sprite frames not built")
	if frames:
		_check(frames.has_animation("idle_0") and frames.has_animation("idle_7"),
			"missing idle animations")
		_check(frames.has_animation("walk_0") and frames.has_animation("walk_7"),
			"missing walk animations")
		_check(frames.get_frame_count("idle_3") == 2, "idle frame count != 2")
		_check(frames.get_frame_count("walk_3") == 4, "walk frame count != 4")

	# ── 等距数学 ──
	_check(IsoMath.screen_motion(Vector2(0, 1)).y == 0.5, "Y / 2 compensation missing")
	_check(IsoMath.dir_index(Vector2(1, 0)) == 0, "dir_index right != 0")
	_check(IsoMath.dir_index(Vector2(0, 1)) == 2, "dir_index down != 2")
	_check(IsoMath.dir_index(Vector2(-1, 0)) == 4, "dir_index left != 4")
	_check(IsoMath.dir_index(Vector2(0, -1)) == 6, "dir_index up != 6")
	_check(IsoMath.dir_index(Vector2(1, 1)) == 1, "dir_index down-right != 1")

	# ── 移动 + 朝向 ──
	player.autopilot = true
	player.demo_input = Vector2(0, 1)
	await physics_frame
	await physics_frame
	_check(player.facing == 2, "facing down should pick front animation")

	player.demo_input = Vector2(1, 0)
	var x0 := player.global_position.x
	for i in 20:
		await physics_frame
	_check(player.global_position.x > x0 + 20.0, "player did not move right")
	player.demo_input = Vector2.ZERO
	await physics_frame

	# ── 墙体碰撞：从 (7,7) 顶向 (7,6) 的墙 1 秒，不能穿进去 ──
	player.teleport(scene.call("cell_pos", Vector2i(7, 7)))
	var wall_pos: Vector2 = scene.call("cell_pos", Vector2i(7, 6))
	player.demo_input = Vector2(1, -1)
	for i in 60:
		await physics_frame
	var dist := player.global_position.distance_to(wall_pos)
	_check(dist > 40.0, "player penetrated the wall (dist %.1f)" % dist)
	player.demo_input = Vector2.ZERO
	player.autopilot = false

	# ── 光照 ──
	var point_lights := 0
	for child in lights.get_children():
		if child is PointLight2D:
			point_lights += 1
			_check(child.shadow_enabled, "PointLight2D without shadow")
	_check(point_lights == 6, "candle light count %d != 6" % point_lights)
	_check(canvas_mod.color != Color(1, 1, 1), "ambient should be dark initially")

	scene.call("toggle_lights")
	_check(not lights.visible, "lights did not turn off")
	_check(canvas_mod.color == Color(1, 1, 1), "ambient did not go white")
	scene.call("toggle_lights")
	_check(lights.visible, "lights did not turn back on")

	scene.call("toggle_y_sort")
	_check(not world.y_sort_enabled, "y-sort toggle failed")
	_check(not walls.y_sort_enabled, "wall y-sort toggle failed")
	scene.call("toggle_y_sort")
	_check(world.y_sort_enabled, "y-sort did not restore")

	if _fails.is_empty():
		print("ISO_SMOKE_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("SMOKE FAIL: ", f)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)
