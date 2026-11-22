extends Control

# 世界视图：TileMapLayer 地形 + 程序化装饰 + 调试叠加 + 屏幕空间地图装饰（chrome）。
# 地图本身放在 SubViewport 里，HUD 与 chrome 走普通 Control，截图时整体放大到 1920×1080。

signal hover_changed(info: Dictionary)

const TileArt = preload("res://scripts/tile_art.gd")
const Utils = preload("res://scripts/gen_utils.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const GenBiome = preload("res://scripts/gen_biome.gd")

const TILE := 32.0
const POI_KINDS := ["tower", "village", "ruins", "camp", "lighthouse"]

var _kits: Dictionary = {}
var _font: SystemFont
var _font_mono: SystemFont
var _mode := ""
var _gen = null
var _stage := -1
var _stage_count := 1
var _finished := false
var _stage_caption := ""
var _debug := {"connectivity": false, "rooms": false, "biomes": false,
	"noise": false, "bounds": false}
var _noise_field := "elevation"
var _field_preview_kind := "elevation"
var _ui_scale := 1.0

var _sub_container: SubViewportContainer
var _viewport: SubViewport
var _world: Node2D
var _camera: Camera2D
var _background: Node2D
var _layers: Dictionary = {}
var _decor_layer: Node2D
var _glow_layer: Node2D
var _overlay_layer: Node2D
var _field_sprite: Sprite2D
var _relief_sprite: Sprite2D
var _water_sprite: Sprite2D
var _debug_sprites: Dictionary = {}
var _vignette: TextureRect
var _chrome: Control

var _content_size := Vector2(1024, 768)
var _fit_rect := Rect2(0, 0, 1024, 768)
var _biome_fit_applied := false
var _biome_tiles_stage := -1
var _relief_texture: Texture2D
var _water_texture: Texture2D
var _fit_zoom := 1.0
var _auto_fit := true
var _dragging := false
var _hover_cell := Vector2i(-1, -1)
var _hover_info: Dictionary = {}
var _legend_rect := Rect2()
var _plaque_rect := Rect2()

var _decor_items: Array = []
var _rug_items: Array = []
var _textures_cache: Dictionary = {}
var _field_textures: Dictionary = {}
var _glow_texture: ImageTexture
var _biome_colors: Dictionary = {}


func setup() -> void:
	name = "MapView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_font = UiTheme.make_font()
	_font_mono = SystemFont.new()
	_font_mono.font_names = PackedStringArray(["SF Mono", "Menlo", "Monaco", "Consolas", "Sans-Serif"])
	_font_mono.allow_system_fallback = true
	_build_nodes()
	resized.connect(_on_resized)


func _build_nodes() -> void:
	_sub_container = SubViewportContainer.new()
	_sub_container.name = "MapSubViewport"
	_sub_container.stretch = true
	_sub_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub_container)

	_viewport = SubViewport.new()
	_viewport.name = "WorldViewport"
	_viewport.size = Vector2i(960, 600)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.transparent_bg = false
	_viewport.msaa_2d = Viewport.MSAA_DISABLED
	_sub_container.add_child(_viewport)

	_world = Node2D.new()
	_world.name = "World"
	_viewport.add_child(_world)

	_background = Node2D.new()
	_background.name = "Backdrop"
	_background.z_index = -100
	_world.add_child(_background)
	_background.draw.connect(_draw_background.bind(_background))

	var layer_order := [
		["ocean", 0], ["ground", 1], ["sand", 2], ["coast", 3], ["forest", 4],
		["rock", 5], ["snow", 6], ["river", 7],
		["floor", 2], ["shadow", 3], ["wall", 4],
	]
	for entry in layer_order:
		var layer := TileMapLayer.new()
		layer.name = String(entry[0]).capitalize()
		layer.z_index = int(entry[1])
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.tile_set = null
		layer.visible = false
		_world.add_child(layer)
		_layers[entry[0]] = layer

	_water_sprite = Sprite2D.new()
	_water_sprite.name = "WaterTint"
	_water_sprite.centered = false
	_water_sprite.position = Vector2.ZERO
	_water_sprite.scale = Vector2(TILE, TILE)
	_water_sprite.z_index = 0
	_water_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_water_sprite.visible = false
	_world.add_child(_water_sprite)

	_decor_layer = Node2D.new()
	_decor_layer.name = "Decor"
	_decor_layer.z_index = 10
	_world.add_child(_decor_layer)
	_decor_layer.draw.connect(_draw_decor.bind(_decor_layer))

	_glow_layer = Node2D.new()
	_glow_layer.name = "Glow"
	_glow_layer.z_index = 11
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = glow_mat
	_world.add_child(_glow_layer)
	_glow_layer.draw.connect(_draw_glow.bind(_glow_layer))

	_field_sprite = Sprite2D.new()
	_field_sprite.name = "FieldPreview"
	_field_sprite.centered = false
	_field_sprite.position = Vector2.ZERO
	_field_sprite.scale = Vector2(TILE, TILE)
	_field_sprite.z_index = 15
	_field_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_field_sprite.visible = false
	_world.add_child(_field_sprite)

	_relief_sprite = Sprite2D.new()
	_relief_sprite.name = "Relief"
	_relief_sprite.centered = false
	_relief_sprite.position = Vector2.ZERO
	_relief_sprite.scale = Vector2(TILE, TILE)
	_relief_sprite.z_index = 9
	_relief_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_relief_sprite.visible = false
	_world.add_child(_relief_sprite)

	var debug_z := {"connectivity": 22, "biomes": 21, "regions": 23, "noise": 24, "bsp": 22}
	for key in ["connectivity", "biomes", "regions", "noise", "bsp"]:
		var sprite := Sprite2D.new()
		sprite.name = "Debug_" + key
		sprite.centered = false
		sprite.position = Vector2.ZERO
		sprite.scale = Vector2(TILE, TILE)
		sprite.z_index = int(debug_z.get(key, 20))
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.visible = false
		_world.add_child(sprite)
		_debug_sprites[key] = sprite

	_overlay_layer = Node2D.new()
	_overlay_layer.name = "Overlay"
	_overlay_layer.z_index = 30
	_world.add_child(_overlay_layer)
	_overlay_layer.draw.connect(_draw_overlay.bind(_overlay_layer))

	_camera = Camera2D.new()
	_camera.name = "Camera"
	_camera.position = Vector2(1024, 768)
	_camera.zoom = Vector2(0.4, 0.4)
	_camera.enabled = true
	_world.add_child(_camera)
	_camera.make_current()

	_glow_texture = _make_glow_texture()
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = _make_vignette_texture()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_vignette)

	_chrome = Control.new()
	_chrome.name = "Chrome"
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chrome)
	_chrome.draw.connect(_draw_chrome.bind(_chrome))


# ---------------------------------------------------------------------------
# 对外 API
# ---------------------------------------------------------------------------

func ensure_kit(mode: String) -> void:
	if _kits.has(mode):
		return
	if mode == "dungeon":
		_kits[mode] = TileArt.build_dungeon()
	else:
		_kits[mode] = TileArt.build_biome()
	if mode == "biome":
		_biome_colors = _kits[mode]["colors"]


func prepare(mode: String, gen, stage_count: int) -> void:
	ensure_kit(mode)
	_mode = mode
	_gen = gen
	_stage = -1
	_stage_count = stage_count
	_finished = false
	_stage_caption = ""
	_field_textures = {}
	_auto_fit = true
	_hover_cell = Vector2i(-1, -1)
	_hover_info = {}
	_decor_items = []
	_rug_items = []
	_clear_all_layers()
	_clear_decor()
	_field_sprite.visible = false
	for key in _debug_sprites:
		_debug_sprites[key].visible = false
	_content_size = Vector2(gen.width * TILE, gen.height * TILE)
	_fit_rect = Rect2(Vector2.ZERO, _content_size)
	_biome_fit_applied = false
	_biome_tiles_stage = -1
	_relief_texture = null
	_water_texture = null
	if _relief_sprite != null:
		_relief_sprite.visible = false
	if _water_sprite != null:
		_water_sprite.visible = false
	var kit: Dictionary = _kits[mode]
	var tileset: TileSet = kit["tileset"]
	for key in _layers:
		var layer: TileMapLayer = _layers[key]
		layer.tile_set = tileset
		layer.visible = false
	if mode == "dungeon":
		for key in ["floor", "shadow", "wall"]:
			_layers[key].visible = true
		_vignette.modulate = Color(1, 1, 1, 1.0)
	else:
		for key in ["ocean", "ground", "sand", "coast", "forest", "rock", "snow", "river"]:
			_layers[key].visible = true
		_vignette.modulate = Color(1, 1, 1, 0.82)
	_background.queue_redraw()
	_chrome.queue_redraw()
	_overlay_layer.queue_redraw()
	_decor_layer.queue_redraw()
	_glow_layer.queue_redraw()
	_fit_camera()


func apply(gen, stage: int, finished: bool) -> void:
	_gen = gen
	_stage = stage
	_finished = finished
	if _mode == "dungeon":
		_apply_dungeon(gen, stage, finished)
	else:
		_apply_biome(gen, stage, finished)
	_update_debug()
	_chrome.queue_redraw()
	_overlay_layer.queue_redraw()


func set_stage_caption(caption: String) -> void:
	_stage_caption = caption
	_chrome.queue_redraw()


func set_debug(flags: Dictionary, noise_field: String) -> void:
	for key in _debug:
		_debug[key] = bool(flags.get(key, false))
	_noise_field = noise_field
	_update_debug()


func set_hover_cell(cell: Vector2i, info: Dictionary) -> void:
	_hover_cell = cell
	_hover_info = info
	_overlay_layer.queue_redraw()
	_chrome.queue_redraw()


func reset_camera() -> void:
	_auto_fit = true
	_fit_camera()
	_chrome.queue_redraw()


func focus_camera(world_pos: Vector2, zoom_multiplier := 1.0) -> void:
	_auto_fit = false
	_camera.position = world_pos
	var target := _fit_zoom * zoom_multiplier
	_camera.zoom = Vector2(target, target)
	_chrome.queue_redraw()


func screen_to_world(local_pos: Vector2) -> Vector2:
	var vp_size := Vector2(_viewport.size)
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = size
	var zoom := _camera.zoom.x
	return _camera.position + (local_pos - vp_size * 0.5) / maxf(0.001, zoom)


func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / TILE), floor(world_pos.y / TILE))


func get_camera_zoom() -> float:
	return _camera.zoom.x


func get_scene_center() -> Vector2:
	return _content_size * 0.5


# ---------------------------------------------------------------------------
# 输入：悬停、拖拽、缩放
# ---------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				_dragging = true
				_auto_fit = false
				accept_event()
			elif _dragging:
				_dragging = false
				accept_event()
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			_zoom_at(button_event.position, 1.18)
			accept_event()
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			_zoom_at(button_event.position, 1.0 / 1.18)
			accept_event()
		elif button_event.double_click and button_event.button_index == MOUSE_BUTTON_LEFT:
			reset_camera()
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _dragging:
			_auto_fit = false
			_camera.position -= motion.relative / maxf(0.001, _camera.zoom.x)
			_chrome.queue_redraw()
			accept_event()
		_update_hover(motion.position)


func _zoom_at(local_pos: Vector2, factor: float) -> void:
	var before := screen_to_world(local_pos)
	var new_zoom := clampf(_camera.zoom.x * factor, _fit_zoom * 0.55, 6.0)
	_camera.zoom = Vector2(new_zoom, new_zoom)
	var after := screen_to_world(local_pos)
	_camera.position += before - after
	_auto_fit = false
	_chrome.queue_redraw()


func _update_hover(local_pos: Vector2) -> void:
	if _gen == null or _mode == "":
		return
	var world_pos := screen_to_world(local_pos)
	var cell := world_to_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= _gen.width or cell.y >= _gen.height:
		if _hover_cell.x >= 0:
			_hover_cell = Vector2i(-1, -1)
			_hover_info = {}
			hover_changed.emit({})
			_overlay_layer.queue_redraw()
		return
	if cell == _hover_cell:
		return
	_hover_cell = cell
	_hover_info = _gen.cell_info(cell)
	_hover_info["cell"] = cell
	hover_changed.emit(_hover_info)
	_overlay_layer.queue_redraw()


func _on_resized() -> void:
	if _auto_fit:
		_fit_camera()
	_chrome.queue_redraw()


func _fit_camera() -> void:
	var vp := Vector2(_viewport.size)
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = size
	if vp.x <= 1.0 or vp.y <= 1.0:
		vp = Vector2(960, 600)
	var fit := minf(vp.x / maxf(1.0, _fit_rect.size.x), vp.y / maxf(1.0, _fit_rect.size.y))
	_fit_zoom = clampf(fit * 0.94, 0.05, 4.0)
	_camera.position = _fit_rect.get_center()
	_camera.zoom = Vector2(_fit_zoom, _fit_zoom)
	_camera.force_update_scroll()
	_chrome.queue_redraw()


# ---------------------------------------------------------------------------
# 地牢渲染
# ---------------------------------------------------------------------------

func _apply_dungeon(gen, stage: int, finished: bool) -> void:
	if stage <= 0:
		_clear_all_layers()
		_clear_decor()
		return
	_build_dungeon_tiles(gen)
	if (stage == 1 or stage == 3) and _auto_fit:
		_fit_rect = _floor_fit_rect(gen)
		_fit_camera()
	if stage >= 4:
		_set_dungeon_decor(gen)
	else:
		_clear_decor()


func _build_dungeon_tiles(gen) -> void:
	var floor_layer: TileMapLayer = _layers["floor"]
	var shadow_layer: TileMapLayer = _layers["shadow"]
	var wall_layer: TileMapLayer = _layers["wall"]
	floor_layer.clear()
	shadow_layer.clear()
	wall_layer.clear()
	var w: int = gen.width
	var h: int = gen.height
	var wall_cells := PackedByteArray()
	wall_cells.resize(w * h)
	wall_cells.fill(0)
	for y in h:
		for x in w:
			if not gen.floor_cell(Vector2i(x, y)):
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if not gen.floor_cell(Vector2i(nx, ny)):
						wall_cells[ny * w + nx] = 1
	var kit: Dictionary = _kits["dungeon"]
	var floor_sets: Dictionary = kit["floor"]
	var shadows: Array = kit["shadow"]
	var walls: Array = kit["wall"]
	for y in h:
		for x in w:
			var index := y * w + x
			var cell := Vector2i(x, y)
			if gen.floor_cell(cell):
				var room: Dictionary = gen.room_at(cell)
				var kind := "stone"
				if not room.is_empty():
					kind = String(room["kind"])
				var variants: Array = floor_sets[kind]
				var variant := int(Utils.hash01(x, y, 11) * variants.size()) % variants.size()
				floor_layer.set_cell(cell, 0, variants[variant])
				var shadow_mask := 0
				if x > 0 and int(wall_cells[index - 1]) != 0:
					shadow_mask |= 8
				if x < w - 1 and int(wall_cells[index + 1]) != 0:
					shadow_mask |= 2
				if y > 0 and int(wall_cells[index - w]) != 0:
					shadow_mask |= 1
				if y < h - 1 and int(wall_cells[index + w]) != 0:
					shadow_mask |= 4
				if shadow_mask != 0:
					shadow_layer.set_cell(cell, 0, shadows[shadow_mask])
			elif int(wall_cells[index]) != 0:
				var mask := 0
				if x > 0 and int(wall_cells[index - 1]) != 0:
					mask |= 8
				if x < w - 1 and int(wall_cells[index + 1]) != 0:
					mask |= 2
				if y > 0 and int(wall_cells[index - w]) != 0:
					mask |= 1
				if y < h - 1 and int(wall_cells[index + w]) != 0:
					mask |= 4
				var variant := 0 if Utils.hash01(x, y, 17) < 0.5 else 1
				wall_layer.set_cell(cell, 0, walls[mask * 2 + variant])


func _set_dungeon_decor(gen) -> void:
	_rug_items = []
	_decor_items = []
	for item in gen.decor:
		var kind := String(item["kind"])
		if kind.begins_with("rug"):
			_rug_items.append(item)
		else:
			_decor_items.append(item)
	_decor_items.sort_custom(_decor_y_less)
	_decor_layer.queue_redraw()
	_glow_layer.queue_redraw()


func _decor_y_less(a: Dictionary, b: Dictionary) -> bool:
	var pa: Vector2 = a.get("pos", Vector2.ZERO)
	var pb: Vector2 = b.get("pos", Vector2.ZERO)
	if is_equal_approx(pa.y, pb.y):
		return String(a["kind"]) < String(b["kind"])
	return pa.y < pb.y


# ---------------------------------------------------------------------------
# 生物群系渲染
# ---------------------------------------------------------------------------

func _apply_biome(gen, stage: int, finished: bool) -> void:
	if stage <= 1:
		_clear_all_layers()
		_clear_decor()
		_biome_tiles_stage = -1
		_relief_sprite.visible = false
		_water_sprite.visible = false
		_field_preview_kind = "elevation" if stage == 0 else "moisture"
		_show_field_preview(gen, _field_preview_kind)
		return
	_field_sprite.visible = false
	if _biome_tiles_stage < 2:
		_build_biome_base(gen)
		_biome_tiles_stage = 2
	if stage >= 3 and _biome_tiles_stage < 3:
		_fill_river_layer(gen)
		_biome_tiles_stage = 3
	if _water_texture == null:
		_water_texture = _get_water_tint_texture(gen)
	_water_sprite.texture = _water_texture
	_water_sprite.visible = true
	_update_relief(gen)
	if stage == 2 and _auto_fit and not _biome_fit_applied:
		_biome_fit_applied = true
		_fit_rect = _land_fit_rect(gen)
		_fit_camera()
	if stage >= 4:
		_set_biome_decor(gen)
	else:
		_clear_decor()


func _show_field_preview(gen, kind: String) -> void:
	var texture := _get_field_texture(gen, kind)
	_field_sprite.texture = texture
	_field_sprite.visible = true
	_field_sprite.modulate = Color(1, 1, 1, 1)


func _build_biome_base(gen) -> void:
	var layer_names := ["ocean", "ground", "sand", "coast", "forest", "rock", "snow"]
	for name in layer_names:
		_layers[name].clear()
	var kit: Dictionary = _kits["biome"]
	var water_sets: Dictionary = kit["water"]
	var grass: Array = kit["grass"]
	var overlays: Dictionary = kit["overlays"]
	var coast: Array = kit["coast"]
	var rivers: Array = kit["river"]
	var w: int = gen.width
	var h: int = gen.height
	for y in h:
		for x in w:
			var index := y * w + x
			var cell := Vector2i(x, y)
			var b := int(gen.biome[index])
			if b < 3:
				var variants: Array = water_sets["mid"]
				var variant := int(Utils.hash01(x, y, 31) * variants.size()) % variants.size()
				_layers["ocean"].set_cell(cell, 0, variants[variant])
				var land_mask := _mask_land(gen, x, y)
				if land_mask != 0:
					_layers["coast"].set_cell(cell, 0, coast[land_mask])
				continue
			var region := int(gen.region[index])
			var grass_variant := posmod(region + int(Utils.hash01(x, y, 37) * 5.0), grass.size())
			_layers["ground"].set_cell(cell, 0, grass[grass_variant])
			var water_mask := _mask_water(gen, x, y)
			if water_mask != 0:
				_layers["coast"].set_cell(cell, 0, coast[water_mask])
			match b:
				3:
					var mask := _same_mask(gen, x, y, 3)
					var list: Array = overlays["sand"]
					var variant := int(Utils.hash01(x, y, 41) * 2.0) % 2
					_layers["sand"].set_cell(cell, 0, list[mask * 2 + variant])
				5:
					var mask := _same_mask(gen, x, y, 5)
					var list: Array = overlays["forest"]
					var variant := int(Utils.hash01(x, y, 43) * 2.0) % 2
					_layers["forest"].set_cell(cell, 0, list[mask * 2 + variant])
				6:
					var mask := _same_mask(gen, x, y, 6)
					var list: Array = overlays["rock"]
					_layers["rock"].set_cell(cell, 0, list[mask])
				7:
					var mask := _same_mask(gen, x, y, 7)
					var list: Array = overlays["snow"]
					_layers["snow"].set_cell(cell, 0, list[mask])
	_layers["river"].clear()


func _fill_river_layer(gen) -> void:
	var river_layer: TileMapLayer = _layers["river"]
	river_layer.clear()
	var rivers: Array = _kits["biome"]["river"]
	for y in gen.height:
		for x in gen.width:
			if int(gen.river[y * gen.width + x]) == 0:
				continue
			var mask := _mask_river(gen, x, y)
			river_layer.set_cell(Vector2i(x, y), 0, rivers[mask])


func _mask_land(gen, x: int, y: int) -> int:
	var mask := 0
	if y > 0 and int(gen.biome[(y - 1) * gen.width + x]) >= 3:
		mask |= 1
	if x < gen.width - 1 and int(gen.biome[y * gen.width + x + 1]) >= 3:
		mask |= 2
	if y < gen.height - 1 and int(gen.biome[(y + 1) * gen.width + x]) >= 3:
		mask |= 4
	if x > 0 and int(gen.biome[y * gen.width + x - 1]) >= 3:
		mask |= 8
	return mask


func _mask_water(gen, x: int, y: int) -> int:
	var mask := 0
	if y > 0 and int(gen.biome[(y - 1) * gen.width + x]) < 3:
		mask |= 1
	if x < gen.width - 1 and int(gen.biome[y * gen.width + x + 1]) < 3:
		mask |= 2
	if y < gen.height - 1 and int(gen.biome[(y + 1) * gen.width + x]) < 3:
		mask |= 4
	if x > 0 and int(gen.biome[y * gen.width + x - 1]) < 3:
		mask |= 8
	return mask


func _same_mask(gen, x: int, y: int, value: int) -> int:
	var mask := 0
	if y > 0 and int(gen.biome[(y - 1) * gen.width + x]) == value:
		mask |= 1
	if x < gen.width - 1 and int(gen.biome[y * gen.width + x + 1]) == value:
		mask |= 2
	if y < gen.height - 1 and int(gen.biome[(y + 1) * gen.width + x]) == value:
		mask |= 4
	if x > 0 and int(gen.biome[y * gen.width + x - 1]) == value:
		mask |= 8
	return mask


func _mask_river(gen, x: int, y: int) -> int:
	var mask := 0
	if y > 0 and _river_like(gen, x, y - 1):
		mask |= 1
	if x < gen.width - 1 and _river_like(gen, x + 1, y):
		mask |= 2
	if y < gen.height - 1 and _river_like(gen, x, y + 1):
		mask |= 4
	if x > 0 and _river_like(gen, x - 1, y):
		mask |= 8
	return mask


func _river_like(gen, x: int, y: int) -> bool:
	var i: int = y * int(gen.width) + x
	if int(gen.biome[i]) < 3:
		return true
	return int(gen.river[i]) != 0


func _set_biome_decor(gen) -> void:
	_rug_items = []
	_decor_items = gen.decor.duplicate()
	_decor_items.sort_custom(_decor_y_less)
	_decor_layer.queue_redraw()
	_glow_layer.queue_redraw()


func _floor_fit_rect(gen) -> Rect2:
	var min_x: int = gen.width
	var min_y: int = gen.height
	var max_x := 0
	var max_y := 0
	var found := false
	for y in gen.height:
		for x in gen.width:
			if gen.floor_cell(Vector2i(x, y)):
				found = true
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if not found:
		return Rect2(Vector2.ZERO, _content_size)
	var margin := 6
	min_x = maxi(0, min_x - margin)
	min_y = maxi(0, min_y - margin)
	max_x = mini(gen.width - 1, max_x + margin)
	max_y = mini(gen.height - 1, max_y + margin)
	return Rect2(Vector2(min_x, min_y) * TILE,
			Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE)


func _land_fit_rect(gen) -> Rect2:
	var min_x: int = gen.width
	var min_y: int = gen.height
	var max_x := 0
	var max_y := 0
	for y in gen.height:
		for x in gen.width:
			if int(gen.biome[y * gen.width + x]) >= 3:
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if min_x > max_x:
		return Rect2(Vector2.ZERO, _content_size)
	var margin := 5
	min_x = maxi(0, min_x - margin)
	min_y = maxi(0, min_y - margin)
	max_x = mini(gen.width - 1, max_x + margin)
	max_y = mini(gen.height - 1, max_y + margin)
	return Rect2(Vector2(min_x, min_y) * TILE,
			Vector2(max_x - min_x + 1, max_y - min_y + 1) * TILE)


func _get_water_tint_texture(gen) -> Texture2D:
	var key := "water_" + str(gen.get_signature()) + "_" + str(gen.stage_index)
	if _field_textures.has(key):
		return _field_textures[key]
	var w: int = gen.width
	var h: int = gen.height
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var deep := Color("#10343f")
	var mid := Color("#1c5a64")
	var shallow := Color("#347f82")
	for y in h:
		for x in w:
			var index: int = y * w + x
			if int(gen.biome[index]) >= 3:
				continue
			var e := float(gen.elevation[index])
			var t := clampf((e - (gen.sea_level - 0.26)) / 0.26, 0.0, 1.0)
			var color: Color
			if t < 0.55:
				color = deep.lerp(mid, t / 0.55)
			else:
				color = mid.lerp(shallow, (t - 0.55) / 0.45)
			var n := _smooth_noise(float(x) * 0.13 + 11.0, float(y) * 0.13 + 5.0, 913)
			n = n * 0.72 + _smooth_noise(float(x) * 0.31 + 3.0, float(y) * 0.31 + 17.0, 917) * 0.28
			color = color.lightened((n - 0.5) * 0.16)
			color.a = 0.64
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


func _smooth_noise(x: float, y: float, salt: int) -> float:
	var x0 := int(floor(x))
	var y0 := int(floor(y))
	var tx := x - float(x0)
	var ty := y - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := Utils.hash01(x0, y0, salt)
	var b := Utils.hash01(x0 + 1, y0, salt)
	var c := Utils.hash01(x0, y0 + 1, salt)
	var d := Utils.hash01(x0 + 1, y0 + 1, salt)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


func _update_relief(gen) -> void:
	if _relief_sprite == null:
		return
	if _relief_texture == null:
		_relief_texture = _get_relief_texture(gen)
	_relief_sprite.texture = _relief_texture
	_relief_sprite.visible = true


func _get_relief_texture(gen) -> Texture2D:
	var key := "relief_" + str(gen.get_signature()) + "_" + str(gen.stage_index)
	if _field_textures.has(key):
		return _field_textures[key]
	var w: int = gen.width
	var h: int = gen.height
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var index: int = y * w + x
			if int(gen.biome[index]) < 3:
				continue
			var x0 := maxi(0, x - 1)
			var x1 := mini(w - 1, x + 1)
			var y0 := maxi(0, y - 1)
			var y1 := mini(h - 1, y + 1)
			var gx: float = float(gen.elevation[y * w + x1]) - float(gen.elevation[y * w + x0])
			var gy: float = float(gen.elevation[y1 * w + x]) - float(gen.elevation[y0 * w + x])
			var x2 := maxi(0, x - 3)
			var x3 := mini(w - 1, x + 3)
			var y2 := maxi(0, y - 3)
			var y3 := mini(h - 1, y + 3)
			var gx2: float = float(gen.elevation[y * w + x3]) - float(gen.elevation[y * w + x2])
			var gy2: float = float(gen.elevation[y3 * w + x]) - float(gen.elevation[y2 * w + x])
			var shade := 0.5 + (gx + gy) * 6.5 + (gx2 + gy2) * 3.2
			shade = clampf(shade, 0.0, 1.0)
			var color := Color(0, 0, 0, 0)
			if shade > 0.52:
				color = Color(1.0, 0.98, 0.88, (shade - 0.52) * 0.95)
			elif shade < 0.47:
				color = Color(0.04, 0.1, 0.12, (0.47 - shade) * 0.9)
			img.set_pixel(x, y, color)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


# ---------------------------------------------------------------------------
# 装饰 / 光晕绘制
# ---------------------------------------------------------------------------

func _clear_decor() -> void:
	_rug_items = []
	_decor_items = []
	_decor_layer.queue_redraw()
	_glow_layer.queue_redraw()


func _clear_all_layers() -> void:
	for key in _layers:
		_layers[key].clear()


func _draw_background(canvas: CanvasItem) -> void:
	var huge := 4.0
	var origin := -_content_size * 1.5
	var area := _content_size * huge
	var base := Color("#0a2228")
	if _mode == "dungeon":
		base = Color("#090f12")
	canvas.draw_rect(Rect2(origin, area), base, true)
	# 细微的深色网格/横纹，避免背景纯色。
	var line := Color(0.3, 0.42, 0.4, 0.05) if _mode == "dungeon" else Color(0.35, 0.55, 0.55, 0.045)
	var step := 128.0
	var start_x: float = floorf(origin.x / step) * step
	var start_y: float = floorf(origin.y / step) * step
	var cols := int(area.x / step) + 2
	var rows := int(area.y / step) + 2
	for i in cols:
		var x := start_x + i * step
		canvas.draw_line(Vector2(x, origin.y), Vector2(x, origin.y + area.y), line, 1.0)
	for i in rows:
		var y := start_y + i * step
		canvas.draw_line(Vector2(origin.x, y), Vector2(origin.x + area.x, y), line, 1.0)
	if _mode == "biome":
		# 地图外圈的大陆架渐变。
		var frame := Rect2(Vector2(-64, -64), _content_size + Vector2(128, 128))
		canvas.draw_rect(frame, Color(0.08, 0.22, 0.25, 0.22), false, 3.0)


func _draw_decor(canvas: CanvasItem) -> void:
	if _gen == null:
		return
	var props: Dictionary = _kits[_mode]["props"]
	for item in _rug_items:
		if not item.has("rect"):
			continue
		var rect: Rect2i = item["rect"]
		var kind := String(item["kind"])
		var texture: Texture2D = props.get(kind, null)
		if texture == null:
			continue
		var target := Rect2(Vector2(rect.position) * TILE + Vector2(2, 2),
				Vector2(rect.size) * TILE - Vector2(4, 4))
		canvas.draw_texture_rect(texture, target, false, Color(1, 1, 1, 0.94))
	for item in _decor_items:
		var kind := String(item["kind"])
		var texture: Texture2D = _prop_texture(props, kind, int(item.get("variant", 0)))
		if texture == null:
			continue
		var pos: Vector2 = item.get("pos", Vector2.ZERO)
		var scale_factor: float = float(item.get("scale", 1.0))
		if kind in POI_KINDS:
			scale_factor *= 1.35
		var w := texture.get_width() * scale_factor
		var h := texture.get_height() * scale_factor
		var rect := Rect2(pos.x - w * 0.5, pos.y - h + 9.0 * scale_factor, w, h)
		canvas.draw_texture_rect(texture, rect, false, Color(1, 1, 1, 1))


func _prop_texture(props: Dictionary, kind: String, variant: int) -> Texture2D:
	var value = props.get(kind, null)
	if value == null:
		return null
	if value is Array:
		var list: Array = value
		if list.is_empty():
			return null
		return list[posmod(variant, list.size())]
	return value


func _draw_glow(canvas: CanvasItem) -> void:
	if _gen == null:
		return
	for item in _decor_items:
		var kind := String(item["kind"])
		var pos: Vector2 = item.get("pos", Vector2.ZERO)
		if kind == "torch":
			var target := Rect2(pos.x - 82, pos.y - 94, 164, 164)
			canvas.draw_texture_rect(_glow_texture, target, false, Color(1.0, 0.68, 0.34, 0.52))
		elif kind in POI_KINDS:
			var color := Color(1.0, 0.73, 0.4, 0.22)
			if kind == "lighthouse":
				color = Color(0.75, 0.9, 0.95, 0.2)
			elif kind == "ruins":
				color = Color(0.55, 0.8, 0.7, 0.12)
			var target := Rect2(pos.x - 52, pos.y - 66, 104, 104)
			canvas.draw_texture_rect(_glow_texture, target, false, color)
		elif kind == "start":
			var target := Rect2(pos.x - 48, pos.y - 42, 96, 96)
			canvas.draw_texture_rect(_glow_texture, target, false, Color(0.4, 0.8, 0.95, 0.26))
		elif kind == "exit":
			var target := Rect2(pos.x - 44, pos.y - 38, 88, 88)
			canvas.draw_texture_rect(_glow_texture, target, false, Color(0.95, 0.8, 0.45, 0.2))


# ---------------------------------------------------------------------------
# 调试叠加
# ---------------------------------------------------------------------------

func _update_debug() -> void:
	if _gen == null:
		return
	var stage := _stage
	for key in _debug_sprites:
		_debug_sprites[key].visible = false
	# 字段预览只在生成早期显示。
	var early_field := _mode == "biome" and stage <= 1
	_field_sprite.visible = early_field
	if _mode == "biome":
		if _debug["noise"] and stage >= 2:
			var tex := _get_field_texture(_gen, _noise_field)
			_set_debug_sprite("noise", tex, true)
		if _debug["biomes"] and stage >= 2:
			_set_debug_sprite("biomes", _get_biome_debug_texture(_gen), false)
		if _debug["connectivity"] and stage >= 2:
			_set_debug_sprite("connectivity", _get_connectivity_texture(_gen), false)
		if _debug["rooms"] and stage >= 5:
			_set_debug_sprite("regions", _get_region_texture(_gen), false)
	else:
		if stage >= 1:
			if _debug["noise"]:
				_set_debug_sprite("bsp", _get_bsp_texture(_gen), false)
			if _debug["connectivity"] and stage >= 3:
				_set_debug_sprite("connectivity", _get_connectivity_texture(_gen), false)
	_chrome.queue_redraw()
	_overlay_layer.queue_redraw()


func _set_debug_sprite(key: String, texture: Texture2D, linear: bool) -> void:
	var sprite: Sprite2D = _debug_sprites[key]
	sprite.texture = texture
	sprite.visible = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST


func _get_field_texture(gen, kind: String) -> Texture2D:
	var key := "%s_%s" % [kind, str(gen.get_signature()) + str(gen.stage_index)]
	if _field_textures.has(key):
		return _field_textures[key]
	var values: PackedFloat32Array = gen.get_field(kind)
	var ramp := _field_ramp(kind)
	var img := Image.create(gen.width, gen.height, false, Image.FORMAT_RGBA8)
	var min_value := 1e9
	var max_value := -1e9
	for value in values:
		min_value = minf(min_value, value)
		max_value = maxf(max_value, value)
	if max_value - min_value < 0.0001:
		max_value = min_value + 1.0
	var w: int = gen.width
	var h: int = gen.height
	for y in h:
		for x in w:
			var value: float = values[y * w + x]
			var t := clampf((value - min_value) / (max_value - min_value), 0.0, 1.0)
			var color := _ramp_color(ramp, t)
			# 等值线：与左/上格跨过 0.1 的倍数时压暗。
			var quant := int(t * 12.0)
			var line := false
			if x > 0:
				var left: float = values[y * w + x - 1]
				if int(clampf((left - min_value) / (max_value - min_value), 0.0, 1.0) * 12.0) != quant:
					line = true
			if y > 0:
				var up: float = values[(y - 1) * w + x]
				if int(clampf((up - min_value) / (max_value - min_value), 0.0, 1.0) * 12.0) != quant:
					line = true
			if line:
				color = color.lerp(Color(0.04, 0.1, 0.11), 0.5)
			img.set_pixel(x, y, color)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


func _field_ramp(kind: String) -> Array[Color]:
	if kind == "moisture":
		return [Color("#42362a"), Color("#8b7a4e"), Color("#7ea36a"), Color("#3f8a86"),
			Color("#245e78")]
	if kind == "temperature":
		return [Color("#274a72"), Color("#3b7a89"), Color("#c8c59b"), Color("#d99a5b"),
			Color("#b8573f")]
	return [Color("#0d2737"), Color("#1b5661"), Color("#7fa998"), Color("#d8cd9a"),
		Color("#8d9a72"), Color("#f1f1e6")]


func _ramp_color(ramp: Array[Color], t: float) -> Color:
	var scaled := clampf(t, 0.0, 1.0) * float(ramp.size() - 1)
	var index := int(floor(scaled))
	var frac := scaled - float(index)
	var a := ramp[clampi(index, 0, ramp.size() - 1)]
	var b := ramp[clampi(index + 1, 0, ramp.size() - 1)]
	return a.lerp(b, frac)


func _get_biome_debug_texture(gen) -> Texture2D:
	var key := "biomes_" + str(gen.get_signature())
	if _field_textures.has(key):
		return _field_textures[key]
	var w: int = gen.width
	var h: int = gen.height
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var index: int = y * w + x
			var color: Color = gen.biome_color(int(gen.biome[index]))
			color.a = 0.58
			if int(gen.river[index]) != 0:
				color = Color(0.2, 0.55, 0.62, 0.68)
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


func _get_region_texture(gen) -> Texture2D:
	var key := "regions_" + str(gen.get_signature())
	if _field_textures.has(key):
		return _field_textures[key]
	var palette := [Color("#e4b96f"), Color("#7fd0b0"), Color("#e39a7a"),
		Color("#8fb7d9"), Color("#c9a8d8"), Color("#b9d18a"), Color("#d8c18a"),
		Color("#8fd0c9"), Color("#d68f9d")]
	var w: int = gen.width
	var h: int = gen.height
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var index: int = y * w + x
			var rid := int(gen.region[index])
			if rid < 0:
				continue
			var color: Color = palette[rid % palette.size()]
			color.a = 0.32
			var boundary := false
			if x > 0 and int(gen.region[index - 1]) != rid:
				boundary = true
			if y > 0 and int(gen.region[index - w]) != rid:
				boundary = true
			if boundary:
				color = Color(0.06, 0.1, 0.1, 0.75)
			img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


func _get_connectivity_texture(gen) -> Texture2D:
	var key := "conn_%s_%d" % [str(gen.get_signature()), int(_stage)]
	if _field_textures.has(key):
		return _field_textures[key]
	var img := Image.create(gen.width, gen.height, false, Image.FORMAT_RGBA8)
	if _mode == "biome":
		var land := PackedByteArray()
		land.resize(gen.width * gen.height)
		for i in land.size():
			land[i] = 1 if int(gen.biome[i]) >= 3 else 0
		var comps := Utils.bfs_components(gen.width, gen.height, land)
		var comp: PackedInt32Array = comps["comp"]
		var largest := int(comps["largest_id"])
		var w: int = gen.width
		var h: int = gen.height
		for y in h:
			for x in w:
				var i: int = y * w + x
				if int(land[i]) == 0:
					continue
				var color := Color(0.35, 0.75, 0.55, 0.42)
				if comp[i] != largest:
					color = Color(0.9, 0.35, 0.3, 0.62)
				img.set_pixel(x, y, color)
	else:
		var dist: PackedInt32Array = gen.dist
		var max_dist := 1
		for value in dist:
			max_dist = maxi(max_dist, value)
		var w: int = gen.width
		var h: int = gen.height
		for y in h:
			for x in w:
				var i: int = y * w + x
				if not gen.floor_cell(Vector2i(x, y)):
					continue
				var color := Color(0.32, 0.1, 0.08, 0.65)
				if dist.size() == gen.width * gen.height and dist[i] >= 0:
					var t := float(dist[i]) / float(max_dist)
					color = Color("#3e8f9a").lerp(Color("#e4b96f"), t)
					color.a = 0.42
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


func _get_bsp_texture(gen) -> Texture2D:
	var key := "bsp_" + str(gen.get_signature())
	if _field_textures.has(key):
		return _field_textures[key]
	var img := Image.create(gen.width, gen.height, false, Image.FORMAT_RGBA8)
	var palette := [Color("#3e6f78"), Color("#5b8f78"), Color("#8fa06a"), Color("#c9a96a"),
		Color("#c48768")]
	for leaf in gen.leaves:
		var rect: Rect2i = leaf["rect"]
		var depth := int(leaf["depth"])
		var color: Color = palette[mini(depth, palette.size() - 1)]
		color.a = 0.26
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				img.set_pixel(x, y, color)
	for room in gen.rooms:
		var rect: Rect2i = room["rect"]
		var color := Color(0.85, 0.8, 0.6, 0.22)
		if String(room["kind"]) == "gold":
			color = Color(0.9, 0.7, 0.35, 0.3)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_field_textures[key] = tex
	return tex


# ---------------------------------------------------------------------------
# 世界坐标叠加（BSP/房间/边界/POI/悬停）
# ---------------------------------------------------------------------------

func _draw_overlay(canvas: CanvasItem) -> void:
	if _gen == null:
		return
	var zoom := maxf(0.01, _camera.zoom.x)
	var line_w := maxf(0.7, 1.2 / zoom)
	if _debug["bounds"]:
		_draw_bounds(canvas, zoom, line_w)
	if _mode == "dungeon":
		_draw_dungeon_overlay(canvas, zoom, line_w)
	else:
		_draw_biome_overlay(canvas, zoom, line_w)
	if _hover_cell.x >= 0:
		var rect := Rect2(Vector2(_hover_cell) * TILE, Vector2(TILE, TILE))
		canvas.draw_rect(rect, Color(1.0, 0.87, 0.55, 0.9), false, maxf(0.8, 1.6 / zoom))


func _draw_bounds(canvas: CanvasItem, zoom: float, line_w: float) -> void:
	var border := Rect2(Vector2.ZERO, _content_size)
	canvas.draw_rect(border, Color(0.55, 0.82, 0.72, 0.65), false, line_w * 1.4)
	var inner := border.grow(-TILE)
	canvas.draw_rect(inner, Color(0.55, 0.82, 0.72, 0.22), false, line_w)
	var step_cells := 8
	for x in range(step_cells, int(_gen.width), step_cells):
		var px := x * TILE
		canvas.draw_line(Vector2(px, 0), Vector2(px, _content_size.y),
				Color(0.55, 0.82, 0.72, 0.08), maxf(0.6, 1.0 / zoom))
	for y in range(step_cells, int(_gen.height), step_cells):
		var py := y * TILE
		canvas.draw_line(Vector2(0, py), Vector2(_content_size.x, py),
				Color(0.55, 0.82, 0.72, 0.08), maxf(0.6, 1.0 / zoom))


func _draw_dungeon_overlay(canvas: CanvasItem, zoom: float, line_w: float) -> void:
	var show_bsp: bool = bool(_debug["rooms"]) or _stage == 0
	if show_bsp:
		for split in _gen.splits:
			var rect: Rect2i = split["rect"]
			var color := Color(0.55, 0.8, 0.7, 0.45)
			if bool(split["vertical"]):
				var px := (rect.position.x + int(split["position"])) * TILE
				canvas.draw_line(Vector2(px, rect.position.y * TILE),
						Vector2(px, rect.end.y * TILE), color, line_w)
			else:
				var py := (rect.position.y + int(split["position"])) * TILE
				canvas.draw_line(Vector2(rect.position.x * TILE, py),
						Vector2(rect.end.x * TILE, py), color, line_w)
		for room in _gen.rooms:
			var rect: Rect2i = room["rect"]
			var color := Color(0.95, 0.8, 0.5, 0.72)
			match String(room["kind"]):
				"moss":
					color = Color(0.6, 0.9, 0.62, 0.72)
				"wood":
					color = Color(0.9, 0.7, 0.46, 0.72)
				"gold":
					color = Color(1.0, 0.85, 0.42, 0.9)
			var center: Vector2i = room["center"]
			var reachable := true
			if _stage >= 3:
				reachable = _gen.dist[center.y * _gen.width + center.x] >= 0
			if not reachable:
				color = Color(1.0, 0.32, 0.26, 0.95)
			canvas.draw_rect(Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE),
					color, false, line_w * 1.2)
			var font_size := int(clampf(22.0 / zoom, 14.0, 44.0))
			_draw_text(canvas, Vector2(rect.position) * TILE + Vector2(5.0 / zoom, 18.0 / zoom),
					"R%d" % int(room["id"]), font_size, Color(1, 0.95, 0.8, 0.8))
	if _stage >= 3:
		_draw_marker(canvas, _gen.start, "起点", Color(0.5, 0.9, 1.0), zoom)
		_draw_marker(canvas, _gen.exit, "终点", Color(1.0, 0.78, 0.4), zoom)
	if _debug["rooms"]:
		for split in _gen.splits:
			var rect: Rect2i = split["rect"]
			var color := Color(0.35, 0.65, 0.6, 0.18)
			canvas.draw_rect(Rect2(Vector2(rect.position) * TILE, Vector2(rect.size) * TILE),
					color, false, line_w)


func _draw_biome_overlay(canvas: CanvasItem, zoom: float, line_w: float) -> void:
	pass


func _draw_marker(canvas: CanvasItem, cell: Vector2i, label: String, color: Color,
		zoom: float) -> void:
	var pos := (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
	canvas.draw_circle(pos, 10.0, color)
	canvas.draw_arc(pos, 16.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.65),
			maxf(0.7, 1.2 / zoom))
	var font_size := int(clampf(18.0 / zoom, 12.0, 40.0))
	var text_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
	var label_pos := pos + Vector2(20.0, 6.0)
	if label_pos.x + text_width > _content_size.x - 10.0:
		label_pos.x = pos.x - text_width - 20.0
	_draw_text(canvas, label_pos, label, font_size, color)


func _draw_text(canvas: CanvasItem, pos: Vector2, text: String, font_size: int,
		color: Color) -> void:
	canvas.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, 4, Color(0.02, 0.05, 0.06, 0.85))
	canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# ---------------------------------------------------------------------------
# 屏幕空间 chrome
# ---------------------------------------------------------------------------

func _draw_chrome(canvas: CanvasItem) -> void:
	if _gen == null:
		return
	var s := clampf(minf(size.x / 960.0, size.y / 600.0), 0.65, 2.6)
	_ui_scale = s
	var rect := Rect2(Vector2(10, 10) * s, size - Vector2(20, 20) * s)
	canvas.draw_rect(rect, Color(0.55, 0.75, 0.68, 0.35), false, maxf(1.0, 1.0 * s))
	canvas.draw_rect(rect.grow(-4.0 * s), Color(0.04, 0.08, 0.09, 0.18), false,
			maxf(1.0, 1.0 * s))
	# 角标
	var tick := 14.0 * s
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]:
		var sx := 1.0 if corner.x < rect.get_center().x else -1.0
		var sy := 1.0 if corner.y < rect.get_center().y else -1.0
		canvas.draw_line(corner, corner + Vector2(tick * sx, 0), Color(0.85, 0.72, 0.45, 0.7),
				maxf(1.0, 1.2 * s))
		canvas.draw_line(corner, corner + Vector2(0, tick * sy), Color(0.85, 0.72, 0.45, 0.7),
				maxf(1.0, 1.2 * s))
	_draw_plaque(canvas, s)
	_draw_compass(canvas, s, rect)
	_draw_scale_bar(canvas, s, rect)
	if _mode == "biome":
		_draw_biome_legend(canvas, s, rect)
	elif _debug["rooms"]:
		_draw_dungeon_legend(canvas, s, rect)
	if _field_sprite.visible or (_mode == "biome" and _debug["noise"]):
		_draw_field_legend(canvas, s, rect)
	if _mode == "biome" and _stage >= 5:
		_draw_poi_labels(canvas, s, rect)
	if _hover_cell.x >= 0 and not _hover_info.is_empty():
		_draw_hover(canvas, s, rect)


func _draw_plaque(canvas: CanvasItem, s: float) -> void:
	var box_rect := Rect2(Vector2(26, 26) * s, Vector2(254, 56) * s)
	_plaque_rect = box_rect
	canvas.draw_rect(box_rect, Color(0.025, 0.06, 0.07, 0.76), true)
	canvas.draw_rect(box_rect, Color(0.6, 0.78, 0.7, 0.32), false, maxf(1.0, s))
	var title := "苔原群岛 · 世界图"
	var sub := "SEED %s · %d × %d" % [_gen.seed_text, _gen.width, _gen.height]
	if _mode == "dungeon":
		title = "无名地牢 · 剖面图"
		sub = "SEED %s · %d × %d" % [_gen.seed_text, _gen.width, _gen.height]
	if _stage_caption != "":
		sub += " · " + _stage_caption
	_draw_chrome_text(canvas, Vector2(38, 50) * s, title, int(15 * s), Color(0.96, 0.9, 0.75, 1))
	_draw_chrome_text(canvas, Vector2(38, 70) * s, sub, int(9.5 * s), Color(0.7, 0.82, 0.76, 1))


func _draw_compass(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var center := Vector2(rect.end.x - 54.0 * s, rect.position.y + 54.0 * s)
	var radius := 26.0 * s
	var brass := Color(0.86, 0.73, 0.45, 0.78)
	var faint := Color(0.55, 0.72, 0.66, 0.35)
	canvas.draw_circle(center, radius, Color(0.03, 0.07, 0.08, 0.5))
	canvas.draw_arc(center, radius, 0.0, TAU, 40, faint, maxf(1.0, s))
	canvas.draw_arc(center, radius * 0.66, 0.0, TAU, 32, faint, maxf(0.8, 0.8 * s))
	for i in 8:
		var angle := -PI * 0.5 + float(i) / 8.0 * TAU
		var length := radius * (1.0 if i % 2 == 0 else 0.55)
		var tip := center + Vector2(cos(angle), sin(angle)) * length
		var side := Vector2(cos(angle + PI * 0.5), sin(angle + PI * 0.5)) * 2.2 * s
		canvas.draw_colored_polygon(PackedVector2Array([tip, center + side, center - side]), brass)
		canvas.draw_line(center, tip, brass, maxf(0.6, 0.7 * s))
	for i in 4:
		var angle := -PI * 0.5 + float(i) / 4.0 * TAU
		var label: String = ["N", "E", "S", "W"][i]
		var pos := center + Vector2(cos(angle), sin(angle)) * (radius + 10.0 * s)
		var width := _font_mono.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1,
				int(8.5 * s)).x
		_draw_chrome_text(canvas, pos - Vector2(width * 0.5, -3.0 * s), label,
				int(8.5 * s), Color(0.88, 0.79, 0.58, 0.9))


func _draw_scale_bar(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var zoom := _camera.zoom.x
	var cells := 10
	for candidate in [4, 8, 10, 16, 20]:
		var pixels: float = float(candidate) * TILE * zoom
		if pixels >= 58.0 * s and pixels <= 170.0 * s:
			cells = candidate
			break
	var length := cells * TILE * zoom
	var origin := Vector2(rect.position.x + 24.0 * s, rect.end.y - 26.0 * s)
	var color := Color(0.92, 0.86, 0.7, 0.85)
	canvas.draw_line(origin, origin + Vector2(length, 0), color, maxf(1.0, 1.2 * s))
	canvas.draw_line(origin + Vector2(0, -5.0 * s), origin + Vector2(0, 5.0 * s), color,
			maxf(1.0, s))
	canvas.draw_line(origin + Vector2(length, -5.0 * s), origin + Vector2(length, 5.0 * s),
			color, maxf(1.0, s))
	_draw_chrome_text(canvas, origin + Vector2(0, 18.0 * s), "%d 格" % cells,
			int(9.5 * s), color)


func _draw_biome_legend(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	if _stage < 2:
		return
	var entries := [
		["沙滩", Color("#d5c08a")], ["草地", Color("#6f9752")],
		["森林", Color("#3b6542")], ["岩地", Color("#7d817b")],
		["雪原", Color("#e6ece6")], ["河流", Color("#2f7f86")],
	]
	var box_w := 214.0 * s
	var box_h := 86.0 * s
	var box_rect := Rect2(Vector2(rect.end.x - box_w - 22.0 * s,
			rect.end.y - box_h - 22.0 * s), Vector2(box_w, box_h))
	_legend_rect = box_rect
	canvas.draw_rect(box_rect, Color(0.025, 0.06, 0.07, 0.72), true)
	canvas.draw_rect(box_rect, Color(0.6, 0.78, 0.7, 0.26), false, maxf(1.0, s))
	for i in entries.size():
		var col := i % 2
		var row := i / 2
		var origin := box_rect.position + Vector2(12.0 + col * 100.0, 18.0 + row * 22.0) * s
		var sw := 8.0 * s
		canvas.draw_rect(Rect2(origin, Vector2(sw, sw)), entries[i][1], true)
		canvas.draw_rect(Rect2(origin, Vector2(sw, sw)), Color(0, 0, 0, 0.25), false, 1.0)
		_draw_chrome_text(canvas, origin + Vector2(14.0 * s, 8.0 * s), String(entries[i][0]),
				int(9.5 * s), Color(0.86, 0.87, 0.78, 0.95))


func _draw_dungeon_legend(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var entries := [
		["石室", Color("#5b5d54")], ["苔室", Color("#5f7a4a")],
		["木室", Color("#6b5238")], ["金库", Color("#b8944e")],
		["起点", Color("#80d8ff")], ["终点", Color("#e4b96f")],
	]
	var box_w := 208.0 * s
	var box_h := 86.0 * s
	var box_rect := Rect2(Vector2(rect.end.x - box_w - 22.0 * s,
			rect.end.y - box_h - 22.0 * s), Vector2(box_w, box_h))
	canvas.draw_rect(box_rect, Color(0.025, 0.06, 0.07, 0.72), true)
	canvas.draw_rect(box_rect, Color(0.6, 0.78, 0.7, 0.26), false, maxf(1.0, s))
	for i in entries.size():
		var col := i % 2
		var row := i / 2
		var origin := box_rect.position + Vector2(12.0 + col * 98.0, 18.0 + row * 22.0) * s
		var sw := 8.0 * s
		canvas.draw_rect(Rect2(origin, Vector2(sw, sw)), entries[i][1], true)
		canvas.draw_rect(Rect2(origin, Vector2(sw, sw)), Color(0, 0, 0, 0.25), false, 1.0)
		_draw_chrome_text(canvas, origin + Vector2(14.0 * s, 8.0 * s), String(entries[i][0]),
				int(9.5 * s), Color(0.86, 0.87, 0.78, 0.95))


func _draw_field_legend(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var kind := _noise_field
	if _field_sprite.visible:
		kind = _field_preview_kind
	var labels := {"elevation": "海拔", "moisture": "湿度", "temperature": "温度"}
	var ramp := _field_ramp(kind)
	var bar := Rect2(Vector2(rect.end.x - 44.0 * s, rect.position.y + 150.0 * s),
			Vector2(12.0 * s, 150.0 * s))
	var steps := 24
	for i in steps:
		var t := 1.0 - float(i) / float(steps - 1)
		var color := _ramp_color(ramp, t)
		var h := bar.size.y / float(steps)
		canvas.draw_rect(Rect2(bar.position + Vector2(0, i * h), Vector2(bar.size.x, h + 1.0)),
				color, true)
	canvas.draw_rect(bar, Color(0.8, 0.85, 0.78, 0.45), false, maxf(1.0, s))
	_draw_chrome_text(canvas, bar.position + Vector2(-2.0 * s, -10.0 * s),
			String(labels.get(kind, kind)), int(9.5 * s), Color(0.88, 0.85, 0.7, 0.95))
	_draw_chrome_text(canvas, bar.position + Vector2(bar.size.x + 5.0 * s, 8.0 * s),
			"高", int(8.5 * s), Color(0.7, 0.8, 0.74, 0.9))
	_draw_chrome_text(canvas, bar.position + Vector2(bar.size.x + 5.0 * s, bar.size.y),
			"低", int(8.5 * s), Color(0.7, 0.8, 0.74, 0.9))


func _draw_poi_labels(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var zoom := _camera.zoom.x
	var vp := Vector2(_viewport.size)
	if vp.x < 2.0:
		return
	var font_size := int(round(10.5 * s))
	var text_color := Color(1.0, 0.94, 0.8, 0.97)
	for poi in _gen.pois:
		var world_pos: Vector2 = poi["pos"]
		var screen_pos := (world_pos - _camera.position) * zoom + vp * 0.5
		var dot := screen_pos + Vector2(0, -2.0 * s)
		var label := String(poi["name"])
		var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var label_pos := dot + Vector2(9.0 * s, -7.0 * s)
		if label_pos.x + text_size.x > rect.end.x - 10.0 * s:
			label_pos.x = dot.x - text_size.x - 9.0 * s
		var label_box := Rect2(label_pos - Vector2(3.0 * s, float(font_size)),
				text_size + Vector2(6.0 * s, 5.0 * s))
		if _legend_rect.size != Vector2.ZERO and label_box.intersects(_legend_rect):
			label_pos.y = _legend_rect.position.y - 9.0 * s
		if _plaque_rect.size != Vector2.ZERO and label_box.intersects(_plaque_rect):
			label_pos.y = _plaque_rect.end.y + font_size + 4.0 * s
		if label_pos.y < rect.position.y + 8.0 * s:
			label_pos.y = dot.y + 16.0 * s
		if label_pos.y > rect.end.y - 10.0 * s:
			label_pos.y = dot.y - 14.0 * s
		canvas.draw_circle(dot, 2.6 * s, Color(0.98, 0.82, 0.5, 0.95))
		canvas.draw_arc(dot, 4.6 * s, 0.0, TAU, 16, Color(0.98, 0.82, 0.5, 0.5),
				maxf(0.8, 1.0 * s))
		canvas.draw_line(dot + Vector2(4.6 * s, 0) * signf(label_pos.x - dot.x),
				label_pos - Vector2(1.0 * s, -2.0 * s),
				Color(0.98, 0.82, 0.5, 0.35), maxf(0.6, 0.7 * s))
		_draw_chrome_text(canvas, label_pos, label, font_size, text_color)


func _draw_hover(canvas: CanvasItem, s: float, rect: Rect2) -> void:
	var text := ""
	if _mode == "biome":
		text = "格 %d,%d · %s" % [_hover_cell.x, _hover_cell.y,
			String(_hover_info.get("biome_name", ""))]
		if _hover_info.get("river", false):
			text += " · 河流"
		if _hover_info.has("poi_name"):
			text += " · " + String(_hover_info["poi_name"])
	else:
		text = "格 %d,%d · %s" % [_hover_cell.x, _hover_cell.y,
			String(_hover_info.get("district", ""))]
		if _hover_info.get("floor", false):
			text += " · 可达" if _hover_info.get("reachable", false) else " · 不可达"
	var font_size := int(9.5 * s)
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var origin := Vector2(rect.get_center().x - text_size.x * 0.5,
			rect.position.y + 22.0 * s)
	canvas.draw_rect(Rect2(origin - Vector2(6 * s, 12 * s), text_size + Vector2(12 * s, 8 * s)),
			Color(0.02, 0.05, 0.06, 0.72), true)
	_draw_chrome_text(canvas, origin, text, font_size, Color(0.9, 0.9, 0.8, 0.92))


func _draw_chrome_text(canvas: CanvasItem, pos: Vector2, text: String, font_size: int,
		color: Color) -> void:
	canvas.draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, 3, Color(0.02, 0.05, 0.06, 0.8))
	canvas.draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


# ---------------------------------------------------------------------------
# 纹理工具
# ---------------------------------------------------------------------------

func _make_glow_texture() -> ImageTexture:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := float(size) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5 - center, float(y) + 0.5 - center).length() / center
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 2.2)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _make_vignette_texture() -> ImageTexture:
	var w := 320
	var h := 180
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var nx := (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var ny := (float(y) + 0.5) / float(h) * 2.0 - 1.0
			var d := sqrt(nx * nx * 0.82 + ny * ny)
			var a := smoothstep(0.45, 1.25, d) * 0.72
			# 左上略亮，右下更暗。
			var warm := clampf(0.5 - (nx + ny) * 0.22, 0.0, 1.0)
			var color := Color(0.02, 0.05, 0.06, a).lerp(
					Color(0.16, 0.14, 0.08, a * 0.35), warm * 0.35)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
