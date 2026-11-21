class_name FlowFieldView
extends Node2D

# 三视图（代价场 / 积分场 / 流场）+ 叠加层：
#   父节点 _draw       ：底色、格子、网格线、数值、箭头、HUD 角标
#   子节点 TrailLayer  ：粉色单位拖尾（低频重绘）
#   子节点 Glow/Core   ：MultiMesh 单位光点（逐帧更新变换）
#   子节点 Overlay     ：目标脉冲、悬停格提示（逐帧）

const C_BG := Color(0.145, 0.133, 0.208)
const C_PANEL := Color(0.176, 0.161, 0.259)
const C_GRID := Color(0.663, 0.314, 0.525)
const C_PINK := Color(0.973, 0.259, 0.553)
const C_TEAL := Color(0.329, 1.0, 0.776)
const C_CYAN := Color(0.078, 0.945, 0.976)
const C_OBSTACLE := Color(0.086, 0.478, 0.486)
const C_TEXT := Color(0.937, 0.914, 0.969)
const C_DIM := Color(0.604, 0.569, 0.722)

var sim = null
var view_mode := "flow"
var show_grid := true
var show_numbers := false
var show_arrows := true
var show_agents := true
var show_trails := true
# bench 消融开关：默认值即主场景当前行为（关 AA、大群隔一取样）。
var trail_antialias := false
var trail_half_sampling := true

var hover_cell := Vector2i(-1, -1)
var hover_active := false
var hover_mode := "goal"

var _font: SystemFont
var _glow_texture: ImageTexture
var _trail_layer: Node2D
var _overlay_layer: Node2D
var _glow_mm: MultiMeshInstance2D
var _core_mm: MultiMeshInstance2D
var _mm_count := -1
var _clock := 0.0
var _max_integration := 1
var _last_trail_version := -1
var _agent_shades := PackedColorArray()


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray([
		"PingFang SC", "Hiragino Sans GB", "Microsoft YaHei",
		"Noto Sans CJK SC", "Arial Unicode MS", "Helvetica Neue",
	])
	_font.allow_system_fallback = true
	_glow_texture = _make_glow_texture(64)

	_trail_layer = Node2D.new()
	_trail_layer.name = "TrailLayer"
	add_child(_trail_layer)
	_trail_layer.draw.connect(_draw_trails.bind(_trail_layer))

	_glow_mm = MultiMeshInstance2D.new()
	_glow_mm.name = "AgentGlow"
	_glow_mm.texture = _glow_texture
	_glow_mm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var glow_mat := CanvasItemMaterial.new()
	glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_mm.material = glow_mat
	add_child(_glow_mm)

	_core_mm = MultiMeshInstance2D.new()
	_core_mm.name = "AgentCore"
	_core_mm.texture = _glow_texture
	_core_mm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_core_mm)

	_overlay_layer = Node2D.new()
	_overlay_layer.name = "Overlay"
	add_child(_overlay_layer)
	_overlay_layer.draw.connect(_draw_overlay.bind(_overlay_layer))
	queue_redraw()


func bind(p_sim) -> void:
	sim = p_sim
	if not sim.field_changed.is_connected(_on_field_changed):
		sim.field_changed.connect(_on_field_changed)
	if not sim.agents_changed.is_connected(_on_agents_changed):
		sim.agents_changed.connect(_on_agents_changed)
	_on_field_changed()
	_on_agents_changed()


func set_view_mode(mode: String) -> void:
	view_mode = mode
	queue_redraw()
	_overlay_layer.queue_redraw()


func set_show(key: String, value: bool) -> void:
	match key:
		"grid":
			show_grid = value
		"numbers":
			show_numbers = value
		"arrows":
			show_arrows = value
		"agents":
			show_agents = value
			_glow_mm.visible = value
			_core_mm.visible = value
		"trails":
			show_trails = value
			_trail_layer.queue_redraw()
		_:
			return
	queue_redraw()


# bench 消融：仅影响拖尾绘制，不改默认视觉（默认 false/true）。
func set_trail_options(antialias: bool, half_sampling: bool) -> void:
	trail_antialias = antialias
	trail_half_sampling = half_sampling
	if _trail_layer != null:
		_trail_layer.queue_redraw()


func set_hover(cell: Vector2i, active: bool, mode := "goal") -> void:
	hover_cell = cell
	hover_active = active
	hover_mode = mode


func grid_rect() -> Rect2:
	if sim == null:
		return Rect2()
	return Rect2(sim.field.origin, Vector2(sim.field.cols, sim.field.rows) * sim.field.cell_size)


func _on_field_changed() -> void:
	_max_integration = 1
	if sim != null:
		for value in sim.field.integration:
			if value < sim.field.INF and value > _max_integration:
				_max_integration = value
	queue_redraw()
	_overlay_layer.queue_redraw()


func _on_agents_changed() -> void:
	_ensure_agent_multimesh(sim.agent_count)
	queue_redraw()


func _process(delta: float) -> void:
	if sim == null:
		return
	if sim.manual_step:
		_clock = sim.sim_time
	else:
		_clock += delta
	_update_agents()
	if sim.trail_version != _last_trail_version:
		_last_trail_version = sim.trail_version
		_trail_layer.queue_redraw()
	_overlay_layer.queue_redraw()


func _ensure_agent_multimesh(count: int) -> void:
	if count == _mm_count:
		return
	_mm_count = count
	var quad := QuadMesh.new()
	quad.size = Vector2(64.0, 64.0)
	for node: MultiMeshInstance2D in [_glow_mm, _core_mm]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.mesh = quad
		mm.instance_count = count
		var scale := 0.001
		for i in count:
			var t := Transform2D(0.0, Vector2.ZERO)
			t.x = Vector2(scale, 0.0)
			t.y = Vector2(0.0, scale)
			mm.set_instance_transform_2d(i, t)
			mm.set_instance_color(i, Color(1, 1, 1, 0))
		node.multimesh = mm
	_agent_shades.resize(count)
	for i in count:
		var t := float(i % 17) / 17.0
		_agent_shades[i] = Color(0.973, 0.259, 0.553).lerp(Color(1.0, 0.62, 0.80), t * 0.55)


func _update_agents() -> void:
	if sim.agent_count <= 0 or _mm_count != sim.agent_count:
		return
	var glow := _glow_mm.multimesh
	var core := _core_mm.multimesh
	if glow == null or core == null:
		return
	var alpha: float = sim.render_alpha()
	var pos_arr: PackedVector2Array = sim.agent_pos
	var prev_arr: PackedVector2Array = sim.agent_prev
	var fade_arr: PackedFloat32Array = sim.agent_fade
	var radius: float = sim.agent_radius
	var glow_scale := radius * 4.6 / 64.0
	var core_scale := radius * 1.9 / 64.0
	var show := show_agents
	_glow_mm.visible = show
	_core_mm.visible = show
	if not show:
		return
	for i in sim.agent_count:
		var p: Vector2 = prev_arr[i].lerp(pos_arr[i], alpha)
		var fade := fade_arr[i]
		var tg := Transform2D(0.0, p)
		tg.x = Vector2(glow_scale, 0.0)
		tg.y = Vector2(0.0, glow_scale)
		glow.set_instance_transform_2d(i, tg)
		var shade := _agent_shades[i]
		glow.set_instance_color(i, Color(shade.r, shade.g, shade.b, 0.42 * fade))
		var tc := Transform2D(0.0, p)
		tc.x = Vector2(core_scale, 0.0)
		tc.y = Vector2(0.0, core_scale)
		core.set_instance_transform_2d(i, tc)
		core.set_instance_color(i, Color(1.0, 0.90, 0.96, 0.92 * fade))


# 基础层 -----------------------------------------------------------------

func _draw() -> void:
	if sim == null:
		return
	var rect := grid_rect()
	draw_rect(rect.grow(9.0), Color(0.08, 0.071, 0.125, 0.72))
	draw_rect(rect.grow(2.0), Color(0.35, 0.17, 0.32, 0.35))

	var cols: int = sim.field.cols
	var rows: int = sim.field.rows
	var cell: float = sim.field.cell_size
	var origin: Vector2 = sim.field.origin
	for y in rows:
		for x in cols:
			var idx := y * cols + x
			var cell_rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
			var color := _cell_color(x, y, idx)
			draw_rect(cell_rect, color)
			if sim.field.cost[idx] == 0:
				var a := cell_rect.position + Vector2(cell * 0.16, cell * 0.84)
				var b := cell_rect.position + Vector2(cell * 0.84, cell * 0.16)
				draw_line(a, b, Color(0.02, 0.20, 0.22, 0.55), 1.0, true)

	if show_numbers:
		_draw_numbers(cols, rows, cell, origin)
	if show_arrows:
		_draw_arrows(cols, rows, cell, origin)
	if show_grid:
		_draw_grid(cols, rows, cell, origin, rect)
	_draw_hud_corners(rect, cell)


func _cell_color(x: int, y: int, idx: int) -> Color:
	var cost: int = sim.field.cost[idx]
	if cost == 0:
		return C_OBSTACLE
	if sim.field.goals.has(Vector2i(x, y)):
		return C_CYAN
	var integration: int = sim.field.integration[idx]
	var finite: bool = integration < sim.field.INF
	var checker := 0.012 if (x + y) % 2 == 0 else 0.0
	match view_mode:
		"cost":
			if finite:
				return Color(0.082 + checker, 0.192 + checker, 0.196 + checker)
			return Color(0.10, 0.09, 0.15)
		"integration":
			if finite:
				return _heat_color(float(integration) / float(maxi(1, _max_integration)))
			return Color(0.105, 0.095, 0.15)
		_:
			if finite:
				var t := float(integration) / float(maxi(1, _max_integration))
				var h := _heat_color(t)
				return Color(
					0.145 + h.r * 0.10 + checker,
					0.133 + h.g * 0.10 + checker,
					0.208 + h.b * 0.10 + checker)
			return Color(0.105, 0.095, 0.15)


func _heat_color(t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	var c0 := Color(0.078, 0.945, 0.976)
	var c1 := Color(0.247, 0.612, 1.0)
	var c2 := Color(0.478, 0.310, 0.839)
	var c3 := Color(0.819, 0.247, 0.557)
	if t < 0.34:
		return c0.lerp(c1, t / 0.34)
	elif t < 0.68:
		return c1.lerp(c2, (t - 0.34) / 0.34)
	return c2.lerp(c3, (t - 0.68) / 0.32)


func _draw_numbers(cols: int, rows: int, cell: float, origin: Vector2) -> void:
	var font_size := int(clampf(cell * 0.32, 7.0, 13.0))
	var text_color := Color(1, 1, 1, 0.84)
	var shadow := Color(0.05, 0.03, 0.09, 0.72)
	var goal_value := "0"
	for y in rows:
		for x in cols:
			var idx := y * cols + x
			if sim.field.cost[idx] == 0:
				continue
			var value: String
			if view_mode == "cost":
				value = "1"
			elif sim.field.goals.has(Vector2i(x, y)):
				value = goal_value
			elif sim.field.integration[idx] >= sim.field.INF:
				value = "×"
			else:
				value = str(sim.field.integration[idx])
			var base := origin + Vector2(x * cell, y * cell + cell * 0.5 + font_size * 0.36)
			draw_string(_font, base + Vector2(0.7, 0.7), value, HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, shadow)
			draw_string(_font, base, value, HORIZONTAL_ALIGNMENT_CENTER, cell, font_size, text_color)


func _draw_arrows(cols: int, rows: int, cell: float, origin: Vector2) -> void:
	var points := PackedVector2Array()
	var colors := PackedColorArray()
	var half := cell * 0.30
	var head := cell * 0.19
	var width := maxf(1.5, cell * 0.10)
	var alpha := 0.94 if view_mode == "flow" else 0.82
	for y in rows:
		for x in cols:
			var idx := y * cols + x
			if sim.field.cost[idx] == 0 or sim.field.integration[idx] >= sim.field.INF:
				continue
			if sim.field.goals.has(Vector2i(x, y)):
				continue
			var dir: Vector2 = sim.field.flow[idx]
			if dir.length_squared() < 0.5:
				continue
			var center := origin + Vector2(x + 0.5, y + 0.5) * cell
			var tip := center + dir * half
			var tail := center - dir * half
			var perp := Vector2(-dir.y, dir.x)
			var color := C_TEAL
			if view_mode == "integration":
				var t := float(sim.field.integration[idx]) / float(maxi(1, _max_integration))
				color = C_TEAL.lerp(C_CYAN, t * 0.4)
			color.a = alpha
			points.append(tail)
			points.append(tip)
			colors.append(color)
			points.append(tip)
			points.append(tip - dir * head + perp * head * 0.62)
			colors.append(color)
			points.append(tip)
			points.append(tip - dir * head - perp * head * 0.62)
			colors.append(color)
	if points.size() > 0:
		draw_multiline_colors(points, colors, width, true)


func _draw_grid(cols: int, rows: int, cell: float, origin: Vector2, rect: Rect2) -> void:
	var lines := PackedVector2Array()
	for x in range(cols + 1):
		var px := origin.x + x * cell
		lines.append(Vector2(px, rect.position.y))
		lines.append(Vector2(px, rect.end.y))
	for y in range(rows + 1):
		var py := origin.y + y * cell
		lines.append(Vector2(rect.position.x, py))
		lines.append(Vector2(rect.end.x, py))
	draw_multiline(lines, Color(C_GRID.r, C_GRID.g, C_GRID.b, 0.42), 1.0, true)
	draw_rect(rect, Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.72), false, 1.6, true)


func _draw_hud_corners(rect: Rect2, cell: float) -> void:
	var l := minf(cell * 0.9, 24.0)
	var c := Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.88)
	var w := 2.0
	var corners := [
		[rect.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(rect.end.x, rect.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(rect.position.x, rect.end.y), Vector2(1, 0), Vector2(0, -1)],
		[rect.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for corner in corners:
		var p: Vector2 = corner[0]
		draw_line(p, p + corner[1] * l, c, w, true)
		draw_line(p, p + corner[2] * l, c, w, true)


# 叠加层 -----------------------------------------------------------------

func _draw_overlay(canvas: CanvasItem) -> void:
	if sim == null:
		return
	var cell: float = sim.field.cell_size
	var pulse := 0.5 + 0.5 * sin(_clock * 3.2)
	for goal in sim.field.goals:
		var center: Vector2 = sim.field.cell_center(goal)
		canvas.draw_circle(center, cell * (0.68 + 0.16 * pulse), Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.10))
		canvas.draw_arc(center, cell * (0.34 + 0.08 * pulse), 0.0, TAU, 28, Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.62), 2.0, true)
		canvas.draw_circle(center, cell * 0.15, Color(0.90, 1.0, 1.0, 0.96))

	if hover_active and sim.field.in_bounds(hover_cell):
		var cell_rect: Rect2 = sim.field.cell_rect(hover_cell)
		var tint := Color(1, 1, 1, 0.06)
		var border := Color(1, 1, 1, 0.66)
		match hover_mode:
			"obstacle":
				tint = Color(C_OBSTACLE.r, C_OBSTACLE.g, C_OBSTACLE.b, 0.38)
				border = Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.92)
			"erase":
				tint = Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.14)
				border = Color(C_PINK.r, C_PINK.g, C_PINK.b, 0.92)
			_:
				tint = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.12)
				border = Color(C_CYAN.r, C_CYAN.g, C_CYAN.b, 0.80)
		canvas.draw_rect(cell_rect, tint)
		canvas.draw_rect(cell_rect, border, false, 2.0, true)
		if hover_mode == "goal" or hover_mode == "add_goal":
			canvas.draw_arc(sim.field.cell_center(hover_cell), cell * 0.30, 0.0, TAU, 24, border, 1.8, true)


func _draw_trails(canvas: CanvasItem) -> void:
	if sim == null or not show_trails or not show_agents:
		return
	var cell: float = sim.field.cell_size
	var max_jump := cell * 2.4
	var points := PackedVector2Array()
	var count: int = sim.agent_count
	var tlen: int = sim.trail_len
	var trail: PackedVector2Array = sim.trail
	# 大群只画一半拖尾，线段数从 5000 降到 2500，视觉密度几乎不变。
	var stride := 2 if trail_half_sampling and count > 700 else 1
	for i in range(0, count, stride):
		var base := i * tlen
		for k in range(tlen - 1):
			var a := trail[base + k]
			var b := trail[base + k + 1]
			if a.distance_squared_to(b) > max_jump * max_jump:
				continue
			points.append(a)
			points.append(b)
	if points.size() > 0:
		# 拖尾线段数量随群数线性增长，关闭抗锯齿可显著降低 GLES3 的批次开销。
		canvas.draw_multiline(points, Color(0.973, 0.259, 0.553, 0.115), 1.1, trail_antialias)


func _make_glow_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := (size - 1) * 0.5
	for y in size:
		for x in size:
			var dx := (x - center) / center
			var dy := (y - center) / center
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if d < 1.0:
				a = pow(1.0 - d, 2.2)
				if d < 0.36:
					a = 1.0
				elif d < 0.52:
					a = maxf(a, 0.55)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
