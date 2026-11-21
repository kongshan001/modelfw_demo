extends Control

# 一次性把 14 种瓦片 × 4 个变体烘焙成图集，运行时地图只需 1 个纹理矩形/格。
# 这是为了在 Intel 集显上把每帧数千个 draw_circle/draw_line 降到几十个纹理批次。

const Tiles = preload("res://scripts/wfc_tileset.gd")
const TileArt = preload("res://scripts/tile_art.gd")

const TILE_PX := 128
const VARIANTS := 4
const COLS := 8
const ROWS := 8


func _draw() -> void:
	for tile in Tiles.TILE_COUNT:
		for variant in VARIANTS:
			var index := tile * VARIANTS + variant
			var col := index % COLS
			var row := index / COLS
			var rect := Rect2(col * TILE_PX, row * TILE_PX, TILE_PX, TILE_PX)
			TileArt.draw_full(self, tile, rect, tile * 1013 + variant * 97, 0.0, 1.0, false)
