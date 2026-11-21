extends Control

# 棋盘绘制：算法视图（熵热力/候选叠加/波前/回溯）与成品地图视图。
# 所有图元都在 _draw() 里程序化绘制，不依赖外部贴图。

const Tiles = preload("res://scripts/wfc_tileset.gd")
const TileArt = preload("res://scripts/tile_art.gd")
const TileBaker = preload("res://scripts/tile_baker.gd")

signal atlas_ready

const HEAT_LOW := Color("#1c2b23")
const HEAT_HIGH := Color("#4c3f2b")
const MINT := Color("#a9d6a8")
const AMBER := Color("#efbf73")
const CORAL := Color("#e88870")

const ATLAS_TILE_PX := 128
const ATLAS_VARIANTS := 4
const ATLAS_COLS := 8
const ATLAS_ROWS := 8
const MASK_TEX_PX := 128
const MASK_ICON_PX := 24
const MASK_GAP := 5

var solver = null
var view_mode := "algo"
var ui_scale := 1.0

var _time := 0.0
var _map_anim_accum := 0.0
var _wave: Dictionary = {}
var _latest_index := -1
var _latest_time := -100.0
var _backtrack_index := -1
var _backtrack_time := -100.0
var _hover_index := -1
var _hover_pos := Vector2.ZERO
var _map_rect := Rect2()
var _atlas_texture: ImageTexture = null
var _atlas_image: Image = null
var _atlas_ready := false
var _icon_images: Array[Image] = []
var _mask_textures: Dictionary = {}
var _banner_text := ""
var _banner_time := -100.0
var _banner_color := CORAL


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	_bake_atlas.call_deferred()


func is_atlas_ready() -> bool:
	return _atlas_ready


func _bake_atlas() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _atlas_ready:
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(ATLAS_TILE_PX * ATLAS_COLS, ATLAS_TILE_PX * ATLAS_ROWS)
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var baker := TileBaker.new()
	baker.size = Vector2(vp.size)
	vp.add_child(baker)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	if image != null and image.get_width() > 0:
		_atlas_image = image
		_atlas_texture = ImageTexture.create_from_image(image)
		_mask_textures.clear()
		_icon_images.clear()
		for tile in Tiles.TILE_COUNT:
			var region_rect := _atlas_region(tile, 0)
			var source := Rect2i(int(region_rect.position.x), int(region_rect.position.y),
					ATLAS_TILE_PX, ATLAS_TILE_PX)
			var icon_image := image.get_region(source)
			icon_image.resize(MASK_ICON_PX, MASK_ICON_PX, Image.INTERPOLATE_LANCZOS)
			_icon_images.append(icon_image)
		_atlas_ready = true
		atlas_ready.emit()
		queue_redraw()
	vp.queue_free()


func set_solver(value) -> void:
	solver = value
	_mask_textures.clear()
	_wave.clear()
	_latest_index = -1
	_backtrack_index = -1
	_banner_time = -100.0
	queue_redraw()


func set_view_mode(mode: String) -> void:
	view_mode = mode
	if mode == "map":
		_banner_time = -100.0
		_wave.clear()
	queue_redraw()


func reset_overlays() -> void:
	_wave.clear()
	_latest_index = -1
	_backtrack_index = -1
	_banner_time = -100.0
	queue_redraw()


func mark_event(event: Dictionary) -> void:
	if solver == null:
		return
	var kind := String(event.get("event", ""))
	var target_value = event.get("target", Vector2i(-1, -1))
	var target := Vector2i(target_value)
	if kind == "collapse":
		_latest_index = _index_of(target)
		_latest_time = _time
		var wave_value = event.get("wave", PackedInt32Array())
		_mark_wave(wave_value, "propagate")
	elif kind == "backtrack":
		var restored := solution_index(solver.last_backtrack_cell)
		if restored >= 0:
			_latest_index = restored
			_backtrack_index = restored
			_backtrack_time = _time
		_mark_wave(event.get("wave", PackedInt32Array()), "backtrack")
		if solver.last_conflict_cell.x >= 0:
			_mark_single(solution_index(solver.last_conflict_cell), "conflict")
		_banner_text = "冲突 → 回溯一格"
		_banner_color = CORAL
		_banner_time = _time
	elif kind == "restart":
		_wave.clear()
		_latest_index = -1
		_backtrack_index = -1
		_latest_time = _time
		_banner_text = "无解路径 → 自动重开"
		_banner_color = AMBER
		_banner_time = _time
	elif kind == "failed":
		_latest_index = _index_of(target)
		_latest_time = _time
	queue_redraw()


func _process(delta: float) -> void:
	advance_animation(delta)


# 供离线录像按固定 30fps 手动推进动效；运行时由 _process 调这个函数。
func advance_animation(delta: float) -> void:
	_time += delta
	var keep := {}
	for key in _wave.keys():
		var item: Dictionary = _wave[key]
		if _time - float(item["time"]) < 1.15:
			keep[key] = item
	_wave = keep
	var animate := not _wave.is_empty() \
			or _time - _latest_time < 0.8 \
			or _time - _backtrack_time < 1.4 \
			or _time - _banner_time < 1.4
	if view_mode == "map":
		_map_anim_accum += delta
		if _map_anim_accum >= 1.0 / 12.0:
			_map_anim_accum = 0.0
			animate = true
	if animate:
		queue_redraw()


func _draw() -> void:
	if solver == null:
		return
	_map_rect = _compute_map_rect()
	var map := _map_rect
	if map.size.x < 2.0:
		return
	# 地图在卡片内的投影与底板
	draw_rect(Rect2(map.position + Vector2(0.0, 7.0 * ui_scale), map.size),
			Color(0.01, 0.02, 0.015, 0.38))
	draw_rect(map, Color("#152018"))

	var cell_w := map.size.x / float(solver.width)
	var cell_h := map.size.y / float(solver.height)
	for y in solver.height:
		for x in solver.width:
			var rect := Rect2(map.position + Vector2(x * cell_w, y * cell_h),
					Vector2(cell_w, cell_h))
			if view_mode == "map":
				_draw_map_cell(x, y, rect)
			else:
				_draw_algo_cell(x, y, rect)
	_draw_grid(map, cell_w, cell_h)
	if view_mode == "map":
		_draw_map_life(map)
	else:
		_draw_algorithm_overlay(map, cell_w, cell_h)
	_draw_frame(map)
	_draw_banner(map)
	if _hover_index >= 0:
		_draw_hover(map, cell_w, cell_h)


func _draw_algo_cell(x: int, y: int, rect: Rect2) -> void:
	var index: int = y * int(solver.width) + x
	var mask: int = solver.get_mask(x, y)
	var inset := maxf(0.7, 1.2 * ui_scale)
	var cell := Rect2(rect.position + Vector2(inset, inset),
			rect.size - Vector2(inset * 2.0, inset * 2.0))
	if mask == 0:
		draw_rect(cell, CORAL.darkened(0.4))
		return
	var count := _popcount(mask)
	if count == 1:
		var tile := _first_tile(mask)
		_draw_tile_texture(tile, cell, index * 37 + tile)
		# 已坍缩：薄荷色小角标。
		var marker := maxf(2.0, cell.size.x * 0.045)
		draw_rect(Rect2(cell.position, Vector2(marker, marker)), MINT)
	else:
		var mask_texture := _get_mask_texture(mask)
		if mask_texture != null:
			draw_texture_rect(mask_texture, cell, false)
		else:
			var entropy: float = solver.entropy_of(mask)
			var max_entropy: float = solver.max_initial_entropy()
			var heat := clampf(entropy / maxf(max_entropy, 0.001), 0.0, 1.0)
			draw_rect(cell, HEAT_LOW.lerp(HEAT_HIGH, pow(heat, 0.7)))


# 同一 mask 的叠加态视觉完全一致（候选集合、权重熵都只由 mask 决定），
# 因此把 300 格 × 14 候选烘焙成约 40 张 128×128 的「候选拼贴」纹理，
# 每格只需 1 个纹理矩形。既保留精确候选，又把 Intel 集显的绘制压到最低。
func _get_mask_texture(mask: int) -> ImageTexture:
	if _mask_textures.has(mask):
		return _mask_textures[mask]
	if not _atlas_ready or _icon_images.size() != Tiles.TILE_COUNT:
		return null
	var image := Image.create(MASK_TEX_PX, MASK_TEX_PX, false, Image.FORMAT_RGBA8)
	var entropy: float = solver.entropy_of(mask)
	var heat := clampf(entropy / maxf(solver.max_initial_entropy(), 0.001), 0.0, 1.0)
	image.fill(HEAT_LOW.lerp(HEAT_HIGH, pow(heat, 0.7)))
	# 轻微的内边框，让每格的候选拼贴保持可读的卡片感。
	image.fill_rect(Rect2i(0, 0, MASK_TEX_PX, 1), Color(0.08, 0.12, 0.08, 0.6))
	image.fill_rect(Rect2i(0, MASK_TEX_PX - 1, MASK_TEX_PX, 1), Color(0.02, 0.03, 0.02, 0.5))
	var count := _popcount(mask)
	var cols := 4
	var rows := int(ceil(float(count) / float(cols)))
	var grid_w := MASK_ICON_PX * cols + MASK_GAP * (cols - 1)
	var grid_h := MASK_ICON_PX * rows + MASK_GAP * (rows - 1)
	var origin := Vector2i((MASK_TEX_PX - grid_w) / 2, (MASK_TEX_PX - grid_h) / 2)
	var ordinal := 0
	var m := mask
	while m != 0:
		var low := m & -m
		var tile := _bit_index(low)
		var col := ordinal % cols
		var row := ordinal / cols
		var destination := origin + Vector2i(col * (MASK_ICON_PX + MASK_GAP),
				row * (MASK_ICON_PX + MASK_GAP))
		image.blit_rect(_icon_images[tile], Rect2i(0, 0, MASK_ICON_PX, MASK_ICON_PX), destination)
		ordinal += 1
		m &= m - 1
	var texture := ImageTexture.create_from_image(image)
	_mask_textures[mask] = texture
	return texture


func _draw_map_cell(x: int, y: int, rect: Rect2) -> void:
	var index: int = y * int(solver.width) + x
	var mask: int = solver.get_mask(x, y)
	if mask == 0:
		draw_rect(rect, Color("#402a25"))
		return
	if _popcount(mask) != 1:
		var mask_texture := _get_mask_texture(mask)
		if mask_texture != null:
			draw_texture_rect(mask_texture, rect, false)
		else:
			draw_rect(rect, Color("#243027"))
		return
	var tile := _first_tile(mask)
	_draw_tile_texture(tile, rect, index * 73 + tile)


func _draw_tile_texture(tile: int, rect: Rect2, variant_seed: int) -> void:
	if _atlas_ready and _atlas_texture != null:
		var variant := int(_hash01(variant_seed) * float(ATLAS_VARIANTS)) % ATLAS_VARIANTS
		draw_texture_rect_region(_atlas_texture, rect, _atlas_region(tile, variant))
	else:
		TileArt.draw_full(self, tile, rect, variant_seed, _time, 1.0, false)


func _atlas_region(tile: int, variant: int) -> Rect2:
	var index := tile * ATLAS_VARIANTS + clampi(variant, 0, ATLAS_VARIANTS - 1)
	var col := index % ATLAS_COLS
	var row := index / ATLAS_COLS
	return Rect2(col * ATLAS_TILE_PX, row * ATLAS_TILE_PX, ATLAS_TILE_PX, ATLAS_TILE_PX)


func _draw_grid(map: Rect2, cell_w: float, cell_h: float) -> void:
	if view_mode != "algo":
		# 成品地图只在同类型地景之间留极淡的缝，帮助读出尺度。
		var line_color := Color(0.06, 0.09, 0.06, 0.055)
		for x in range(1, solver.width):
			draw_line(Vector2(map.position.x + x * cell_w, map.position.y),
					Vector2(map.position.x + x * cell_w, map.end.y), line_color, 0.6)
		for y in range(1, solver.height):
			draw_line(Vector2(map.position.x, map.position.y + y * cell_h),
					Vector2(map.end.x, map.position.y + y * cell_h), line_color, 0.6)
		return
	var line_color := Color(0.44, 0.56, 0.41, 0.20)
	for x in range(1, solver.width):
		draw_line(Vector2(map.position.x + x * cell_w, map.position.y),
				Vector2(map.position.x + x * cell_w, map.end.y), line_color, 1.0)
	for y in range(1, solver.height):
		draw_line(Vector2(map.position.x, map.position.y + y * cell_h),
				Vector2(map.end.x, map.position.y + y * cell_h), line_color, 1.0)


func _draw_algorithm_overlay(map: Rect2, cell_w: float, cell_h: float) -> void:
	# 波前/回溯边框只在有事件的格上绘制。
	for index in _wave.keys():
		var cx: int = int(index) % int(solver.width)
		var cy: int = int(index) / int(solver.width)
		_draw_wave_border(int(index), _cell_rect(Vector2i(cx, cy), map, cell_w, cell_h))
	if _backtrack_index >= 0 and _time - _backtrack_time < 1.4:
		var fade := clampf(1.0 - (_time - _backtrack_time) / 1.4, 0.0, 1.0)
		var bx: int = _backtrack_index % int(solver.width)
		var by: int = _backtrack_index / int(solver.width)
		draw_rect(_cell_rect(Vector2i(bx, by), map, cell_w, cell_h).grow(1.0),
				_with_alpha(CORAL, 0.55 * fade), false, maxf(1.0, 2.0 * ui_scale))
	if _latest_index >= 0 and _time - _latest_time < 0.8:
		var fade := clampf(1.0 - (_time - _latest_time) / 0.8, 0.0, 1.0)
		var lx: int = _latest_index % int(solver.width)
		var ly: int = _latest_index / int(solver.width)
		var rect := _cell_rect(Vector2i(lx, ly), map, cell_w, cell_h)
		draw_arc(rect.get_center(), rect.size.x * (0.15 + (1.0 - fade) * 0.45), 0, TAU, 20,
				_with_alpha(MINT, fade * 0.7), maxf(1.0, 1.5 * ui_scale), true)

	# 当前熵最低的目标格：琥珀色角标与脉冲。
	var low: Dictionary = solver.lowest_entropy_cell()
	var low_cell: Vector2i = low["cell"]
	if low_cell.x >= 0:
		var rect := _cell_rect(low_cell, map, cell_w, cell_h)
		var pulse := 0.5 + 0.5 * sin(_time * 3.2)
		draw_rect(rect.grow(1.0 * ui_scale), _with_alpha(AMBER, 0.32 + pulse * 0.30), false,
				maxf(1.0, 1.8 * ui_scale))
		var corner := maxf(3.0, rect.size.x * 0.12)
		draw_line(rect.position + Vector2(0, corner), rect.position, AMBER,
				maxf(1.0, 2.0 * ui_scale))
		draw_line(rect.position, rect.position + Vector2(corner, 0), AMBER,
				maxf(1.0, 2.0 * ui_scale))
		draw_circle(rect.position + Vector2(rect.size.x * 0.14, rect.size.y * 0.14),
				maxf(1.2, 2.2 * ui_scale), _with_alpha(AMBER, 0.85))


func _draw_map_life(map: Rect2) -> void:
	# 成品视图只保留少量环境生命：屋灯 + 全图萤火；不再逐格画粒子。
	var map_seed: int = int(solver.base_seed)
	for y in solver.height:
		for x in solver.width:
			var mask: int = solver.get_mask(x, y)
			if _popcount(mask) != 1:
				continue
			if _first_tile(mask) != Tiles.COTTAGE:
				continue
			var index: int = y * int(solver.width) + x
			var rect := _cell_rect(Vector2i(x, y), map,
					map.size.x / solver.width, map.size.y / solver.height)
			var p := rect.position + rect.size * Vector2(0.58, 0.44)
			var flicker := 0.5 + 0.5 * sin(_time * 2.4 + _hash01(index + map_seed) * 10.0)
			draw_circle(p, rect.size.x * 0.10, Color(1.0, 0.76, 0.40, 0.05 + flicker * 0.045))
			draw_circle(p, maxf(1.1, rect.size.x * 0.015),
					Color(1.0, 0.82, 0.48, 0.42 + flicker * 0.40))
	for i in 12:
		var seed_value := int(map_seed) + i * 163
		var pos := map.position + Vector2(
			map.size.x * (0.05 + 0.90 * _hash01(seed_value + 7)),
			map.size.y * (0.05 + 0.90 * _hash01(seed_value + 19)))
		pos += Vector2(sin(_time * 0.50 + i) * map.size.x * 0.012,
				cos(_time * 0.42 + i * 1.7) * map.size.y * 0.014)
		var glow := 0.35 + 0.65 * (0.5 + 0.5 * sin(_time * 1.7 + i * 2.1))
		draw_circle(pos, map.size.x * 0.008, Color(0.94, 0.83, 0.48, 0.12 * glow))
		draw_circle(pos, maxf(0.7, map.size.x * 0.0022),
				Color(1.0, 0.90, 0.60, 0.55 * glow))


func _draw_wave_border(index: int, cell: Rect2) -> void:
	if not _wave.has(index):
		return
	var item: Dictionary = _wave[index]
	var age := _time - float(item["time"])
	var kind := String(item["kind"])
	if age < 0.0 or age > 1.15:
		return
	var fade := clampf(1.0 - age / 1.15, 0.0, 1.0)
	var color := CORAL if kind in ["backtrack", "conflict"] else AMBER
	var width := maxf(0.8, (1.4 + (1.0 - fade) * 2.2) * ui_scale)
	draw_rect(cell.grow(0.5), _with_alpha(color, fade * 0.9), false, width)
	# 扩散的波前小圆点，强化“传播”而不是静态描边。
	if kind == "propagate" and cell.size.x > 22.0:
		var center := cell.get_center()
		var radius := cell.size.x * lerpf(0.10, 0.48, 1.0 - fade)
		draw_arc(center, radius, 0, TAU, 14, _with_alpha(color, fade * 0.24),
				maxf(0.8, 1.0 * ui_scale), true)


func _draw_frame(map: Rect2) -> void:
	draw_rect(map, Color(0.62, 0.73, 0.53, 0.21), false, maxf(1.0, 1.2 * ui_scale))
	# 四个角的装饰短线，和背景花园线条呼应。
	var arm := 12.0 * ui_scale
	var color := Color(0.72, 0.83, 0.61, 0.34)
	draw_line(map.position, map.position + Vector2(arm, 0), color, maxf(1.0, 1.0 * ui_scale))
	draw_line(map.position, map.position + Vector2(0, arm), color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.end.x, map.position.y), Vector2(map.end.x - arm, map.position.y),
			color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.end.x, map.position.y), Vector2(map.end.x, map.position.y + arm),
			color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.position.x, map.end.y), Vector2(map.position.x + arm, map.end.y),
			color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.position.x, map.end.y), Vector2(map.position.x, map.end.y - arm),
			color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.end.x, map.end.y), Vector2(map.end.x - arm, map.end.y),
			color, maxf(1.0, 1.0 * ui_scale))
	draw_line(Vector2(map.end.x, map.end.y), Vector2(map.end.x, map.end.y - arm),
			color, maxf(1.0, 1.0 * ui_scale))


func _draw_banner(map: Rect2) -> void:
	if view_mode == "map":
		return
	if _banner_text.is_empty() or _time - _banner_time >= 1.4:
		return
	var fade := clampf(1.0 - (_time - _banner_time) / 1.4, 0.0, 1.0)
	var font := _font()
	if font == null:
		return
	var font_size := int(round(10.5 * ui_scale))
	var panel_w := 148.0 * ui_scale
	var panel_h := 27.0 * ui_scale
	var panel := Rect2(Vector2(map.get_center().x - panel_w * 0.5,
			map.position.y + 10.0 * ui_scale), Vector2(panel_w, panel_h))
	draw_rect(panel, Color(0.055, 0.070, 0.050, 0.93 * fade))
	draw_rect(panel, _with_alpha(_banner_color, 0.85 * fade), false,
			maxf(1.0, 1.2 * ui_scale))
	var text_size := font.get_string_size(_banner_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, panel.position + Vector2((panel_w - text_size.x) * 0.5,
			panel_h * 0.5 + text_size.y * 0.32), _banner_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			_with_alpha(_banner_color, fade))


func _draw_hover(map: Rect2, cell_w: float, cell_h: float) -> void:
	if solver == null or _hover_index < 0:
		return
	var x: int = _hover_index % int(solver.width)
	var y: int = _hover_index / int(solver.width)
	var cell := _cell_rect(Vector2i(x, y), map, cell_w, cell_h)
	draw_rect(cell, Color(1.0, 1.0, 1.0, 0.8), false, maxf(1.0, 1.0 * ui_scale))
	if not map.has_point(_hover_pos):
		return
	var mask: int = solver.get_mask(x, y)
	var title := "格 (%d,%d)" % [x, y]
	var detail := ""
	if _popcount(mask) == 1:
		detail = Tiles.name_of(_first_tile(mask))
	else:
		detail = "候选 %d · H %.2f" % [_popcount(mask), solver.entropy_of(mask)]
	var panel_w := 172.0 * ui_scale
	var panel_h := 45.0 * ui_scale
	var pos := _hover_pos + Vector2(14.0 * ui_scale, 14.0 * ui_scale)
	if pos.x + panel_w > size.x - 8.0:
		pos.x = _hover_pos.x - panel_w - 14.0 * ui_scale
	if pos.y + panel_h > size.y - 8.0:
		pos.y = _hover_pos.y - panel_h - 14.0 * ui_scale
	pos.x = maxf(8.0, pos.x)
	pos.y = maxf(8.0, pos.y)
	var panel := Rect2(pos, Vector2(panel_w, panel_h))
	draw_rect(panel, Color(0.035, 0.055, 0.04, 0.94))
	draw_rect(panel, Color(0.64, 0.80, 0.59, 0.32), false, 1.0)
	var font := _font()
	if font != null:
		draw_string(font, pos + Vector2(10.0, 18.0) * ui_scale, title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(12.0 * ui_scale), MINT)
		draw_string(font, pos + Vector2(10.0, 35.0) * ui_scale, detail,
				HORIZONTAL_ALIGNMENT_LEFT, -1, int(11.0 * ui_scale), Color(0.84, 0.83, 0.72))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var map := _compute_map_rect()
		if map.size.x > 0.0 and map.has_point(event.position):
			var cell_w: float = map.size.x / float(solver.width)
			var cell_h: float = map.size.y / float(solver.height)
			var x: int = clampi(int((event.position.x - map.position.x) / cell_w), 0, solver.width - 1)
			var y: int = clampi(int((event.position.y - map.position.y) / cell_h), 0, solver.height - 1)
			_hover_index = y * solver.width + x
			_hover_pos = event.position
			queue_redraw()
		else:
			_hover_index = -1
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover_index = -1
		queue_redraw()


func _compute_map_rect() -> Rect2:
	if solver == null:
		return Rect2()
	var pad := 18.0 * ui_scale
	var max_w := maxf(1.0, size.x - pad * 2.0)
	var max_h := maxf(1.0, size.y - pad * 2.0)
	var cell := minf(max_w / solver.width, max_h / solver.height)
	var map_size := Vector2(cell * solver.width, cell * solver.height)
	return Rect2((size - map_size) * 0.5, map_size)


func _cell_rect(cell: Vector2i, map: Rect2, cell_w: float, cell_h: float) -> Rect2:
	return Rect2(map.position + Vector2(cell.x * cell_w, cell.y * cell_h),
			Vector2(cell_w, cell_h))


func _index_of(cell: Vector2i) -> int:
	if solver == null or cell.x < 0 or cell.y < 0 or cell.x >= solver.width or cell.y >= solver.height:
		return -1
	return cell.y * solver.width + cell.x


func solution_index(cell: Vector2i) -> int:
	return _index_of(cell)


func _mark_wave(wave, kind: String) -> void:
	if wave == null:
		return
	for value in wave:
		var index := int(value)
		_wave[index] = {"time": _time, "kind": kind}


func _mark_single(index: int, kind: String) -> void:
	if index >= 0:
		_wave[index] = {"time": _time, "kind": kind}


func _first_tile(mask: int) -> int:
	return _bit_index(mask & -mask)


func _bit_index(value: int) -> int:
	var index := 0
	var v := value
	while v > 1:
		v >>= 1
		index += 1
	return index


func _popcount(value: int) -> int:
	var count := 0
	var v := value
	while v != 0:
		v &= v - 1
		count += 1
	return count


func _with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, color.a * alpha)


func _hash01(value: int) -> float:
	var x := (value * 747796405 + 2891336453) & 0x7fffffff
	x = ((x >> ((x >> 28) + 4)) ^ x) * 277803737
	x = (x >> 22) ^ x
	return float(x & 0x7fffffff) / 2147483647.0


func _font() -> Font:
	var font := get_theme_default_font()
	if font == null:
		font = ThemeDB.fallback_font
	return font
