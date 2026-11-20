extends SceneTree

# Builds res://assets/tiles/dungeon_tileset.tres from the generated atlas.
# Run once after gen_art.py:
#   godot --headless --path godot-iso-slice --editor --quit   # import PNGs
#   godot --headless --path godot-iso-slice -s tools/build_tileset.gd
#
# Atlas layout (128x160 cells, logical tile 128x64):
#   row 0: floor A, floor B, floor C, rug
#   row 1: wall A, wall B
# Every tile's footprint diamond is drawn at cell y=128, so texture_origin
# shifts the art up by 48 px and the footprint lands on the logical tile.

const ATLAS := "res://assets/tiles/iso_tiles.png"
const OUT := "res://assets/tiles/dungeon_tileset.tres"

const TILE_W := 128
const TILE_H := 64
const CELL := Vector2i(128, 160)
const TEXTURE_ORIGIN := Vector2i(0, 48)

# foot-print diamond, inset a little so the player can hug the wall
const FOOT := [
	Vector2(0, -27), Vector2(58, 0), Vector2(0, 27), Vector2(-58, 0),
]

const WALL_TILES := [Vector2i(0, 1), Vector2i(1, 1)]

func _initialize() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_W, TILE_H)
	# 这两行决定菱形排列；只设 tile_size 会退回矩形堆叠，地砖之间会留缝。
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN

	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	ts.add_occlusion_layer()
	ts.set_occlusion_layer_light_mask(0, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load(ATLAS)
	src.texture_region_size = CELL
	# The source must live in the TileSet before per-tile data can see the
	# physics / occlusion layers configured above.
	ts.add_source(src, 0)

	for y in 2:
		for x in 4:
			src.create_tile(Vector2i(x, y))
			var td := src.get_tile_data(Vector2i(x, y), 0)
			td.texture_origin = TEXTURE_ORIGIN

	for coords in WALL_TILES:
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array(FOOT))
		var occ := OccluderPolygon2D.new()
		occ.polygon = PackedVector2Array(FOOT)
		td.add_occluder_polygon(0)
		td.set_occluder_polygon(0, 0, occ)
	var err := ResourceSaver.save(ts, OUT)
	if err != OK:
		push_error("save failed: %s" % err)
		quit(1)
		return
	print("ISO_TILESET_OK ", OUT, " tiles=", src.get_tiles_count())
	quit(0)
