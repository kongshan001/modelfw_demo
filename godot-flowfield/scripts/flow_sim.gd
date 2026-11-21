class_name FlowFieldSim
extends Node

const GridField = preload("res://scripts/flow_field_grid.gd")

# 流场群体模拟：固定 30Hz 逻辑步长（渲染 60Hz + 帧间插值）、空间哈希分离、圆形单位 vs 格子碰撞。
# 所有随机行为都来自固定种子；同地图 + 同目标 + 同操作顺序可复现。
# 视频 03:13 的总结：转弯（双线性采样）、单位间碰撞（separation）、单位-障碍碰撞（圆 vs 格）。

signal field_changed
signal agents_changed

const FIXED_DT := 1.0 / 30.0
const MAX_GOALS := 8
const MAX_AGENTS := 1200
const TRAIL_LEN := 6
const SPAWN_FAR_STEPS := 12
const SAMPLE_SEED := 421
const MAP_PRESETS := {
	"small": Vector2i(24, 16),
	"medium": Vector2i(36, 24),
	"large": Vector2i(48, 32),
}

var field: GridField = GridField.new()
var play_rect := Rect2(28, 96, 884, 596)
var map_key := "medium"
var seed := SAMPLE_SEED

var agent_count := 0
var agent_radius := 4.0
var speed := 70.0
var target_agent_count := 500

var agent_pos := PackedVector2Array()
var agent_prev := PackedVector2Array()
var agent_vel := PackedVector2Array()
var agent_fade := PackedFloat32Array()
var trail := PackedVector2Array()
var trail_len := TRAIL_LEN
var trail_version := 0

var paused := false
var manual_step := false
var sim_time := 0.0
var arrivals := 0
var last_build_usec := 0
var last_step_usec := 0
var avg_step_usec := 0.0
# 审计用精确计数：bench 在每个采样段开始前清零，避免 EMA 受预热/上一轮影响。
var step_count := 0
var step_total_usec := 0
var step_max_usec := 0
# bench 消融开关：false = 初版行为（固定每 2 拍刷新/拖尾），true = 大群降到每 3 拍。
# 默认 true，主场景行为与 T-009 一致。
var large_group_10hz := true

var profiling := false
var prof := {}

var _speed_scale := PackedFloat32Array()
var _spawn_cells: Array[Vector2i] = []
var _goal_centers := PackedVector2Array()
var _goal_hit_r2 := 0.0
var _near_wall := PackedByteArray()
var _sep_x := PackedFloat32Array()
var _sep_y := PackedFloat32Array()
var _sep_hash_size := 9.0
var _sep_hash_cols := 1
var _sep_hash_rows := 1
var _sep_head := PackedInt32Array()
var _sep_next := PackedInt32Array()
var _flow_dir_x := PackedFloat32Array()
var _flow_dir_y := PackedFloat32Array()
var _force_flow_refresh := true
var _agent_rng := RandomNumberGenerator.new()
var _tick := 0
var _refresh_every := 2
var _trail_every := 2
var last_step_start_usec := 0


func setup(rect: Rect2, key := "medium", p_seed := SAMPLE_SEED) -> void:
	play_rect = rect
	map_key = key
	seed = p_seed
	load_sample(map_key, p_seed)


func set_paused(value: bool) -> void:
	paused = value


func set_manual_capture(value: bool) -> void:
	manual_step = value


func set_agent_count(value: int) -> void:
	target_agent_count = clampi(value, 1, MAX_AGENTS)
	reset()


# bench 消融：关闭后无论群数都按初版每 2 拍刷新/拖尾。
func set_large_group_10hz(value: bool) -> void:
	large_group_10hz = value
	if agent_count > 0:
		var decimate := large_group_10hz and agent_count > 700
		_refresh_every = 3 if decimate else 2
		_trail_every = 3 if decimate else 2
		_force_flow_refresh = true


func reset_step_stats() -> void:
	step_count = 0
	step_total_usec = 0
	step_max_usec = 0


func set_map_size(key: String) -> void:
	if not MAP_PRESETS.has(key):
		return
	map_key = key
	load_sample(map_key)


func reload_random() -> void:
	seed = (seed * 1664525 + 1013904223) & 0x7fffffff
	load_random(map_key, seed)


func _configure_layout() -> void:
	var dims: Vector2i = MAP_PRESETS[map_key]
	var cell := floorf(minf(play_rect.size.x / float(dims.x), play_rect.size.y / float(dims.y)))
	cell = maxf(cell, 8.0)
	var grid_size := Vector2(dims) * cell
	var origin := play_rect.position + (play_rect.size - grid_size) * 0.5
	field.configure(dims.x, dims.y, origin, cell)
	agent_radius = clampf(cell * 0.17, 2.6, 7.0)
	speed = cell * 2.9
	_sep_hash_size = maxf(agent_radius * 2.3, 4.0)
	_sep_hash_cols = maxi(1, ceili(field.cols * cell / _sep_hash_size))
	_sep_hash_rows = maxi(1, ceili(field.rows * cell / _sep_hash_size))
	_sep_head.resize(_sep_hash_cols * _sep_hash_rows)


# 视频 00:56 的大图构图：中间一个 C 形深青墙，单位从右侧绕过上下两条臂。
func load_sample(key := "", p_seed := SAMPLE_SEED) -> void:
	if key != "":
		map_key = key
	seed = p_seed
	_configure_layout()
	field.cost.fill(1)
	var cols := field.cols
	var rows := field.rows
	var x0 := clampi(roundi(cols * 0.37), 2, cols - 3)
	var x1 := clampi(roundi(cols * 0.56), x0 + 2, cols - 3)
	var y0 := clampi(roundi(rows * 0.22), 2, rows - 3)
	var y1 := clampi(roundi(rows * 0.78), y0 + 2, rows - 3)
	for y in range(y0, y1 + 1):
		field.set_cost(Vector2i(x0, y), 0)
	for x in range(x0, x1 + 1):
		field.set_cost(Vector2i(x, y0), 0)
		field.set_cost(Vector2i(x, y1), 0)
	var goal := Vector2i(clampi(roundi(cols * 0.13), 1, cols - 2), clampi(roundi(rows * 0.5), 1, rows - 2))
	field.set_cost(goal, 1)
	field.set_goals([goal])
	_rebuild_field()
	reset()


# 随机地图：散点 + 矩形墙块；目标落在最大连通域里。
func load_random(key: String, p_seed: int) -> void:
	map_key = key
	seed = p_seed
	_configure_layout()
	var cols := field.cols
	var rows := field.rows
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var best_component: Array[Vector2i] = []
	for attempt in 6:
		field.cost.fill(1)
		for y in range(1, rows - 1):
			for x in range(1, cols - 1):
				if rng.randf() < 0.10:
					field.set_cost(Vector2i(x, y), 0)
		var blob_count := 4 + rng.randi_range(0, 3)
		for i in blob_count:
			var w := rng.randi_range(2, 5)
			var h := rng.randi_range(2, 4)
			var bx := rng.randi_range(1, maxi(1, cols - w - 2))
			var by := rng.randi_range(1, maxi(1, rows - h - 2))
			for y in range(by, mini(rows - 2, by + h)):
				for x in range(bx, mini(cols - 2, bx + w)):
					field.set_cost(Vector2i(x, y), 0)
		best_component = field.largest_open_component()
		if best_component.size() >= int(cols * rows * 0.35):
			break
	var goal := Vector2i(clampi(roundi(cols * 0.13), 1, cols - 2), clampi(roundi(rows * 0.5), 1, rows - 2))
	if best_component.size() > 0:
		var target := Vector2(cols * 0.13, rows * 0.5)
		var best_score := INF
		for cell in best_component:
			var score := Vector2(cell).distance_squared_to(target)
			if score < best_score:
				best_score = score
				goal = cell
	field.set_cost(goal, 1)
	field.set_goals([goal])
	_rebuild_field()
	reset()


func reset() -> void:
	sim_time = 0.0
	arrivals = 0
	_tick = 0
	_agent_rng.seed = seed * 7919 + 17
	agent_count = target_agent_count
	# 大群时把方向/分离刷新降到 10Hz、拖尾降到 10Hz，换取 30fps 余量；移动仍按 30Hz 积分。
	var decimate := large_group_10hz and agent_count > 700
	_refresh_every = 3 if decimate else 2
	_trail_every = 3 if decimate else 2
	reset_step_stats()
	agent_pos.resize(agent_count)
	agent_prev.resize(agent_count)
	agent_vel.resize(agent_count)
	_sep_next.resize(agent_count)
	agent_fade.resize(agent_count)
	_speed_scale.resize(agent_count)
	_sep_x.resize(agent_count)
	_sep_y.resize(agent_count)
	_sep_x.fill(0.0)
	_sep_y.fill(0.0)
	_flow_dir_x.resize(agent_count)
	_flow_dir_y.resize(agent_count)
	trail.resize(agent_count * TRAIL_LEN)
	for i in agent_count:
		_speed_scale[i] = _agent_rng.randf_range(0.86, 1.14)
		var p := _spawn_position(false)
		if p == Vector2.INF:
			var any := field.nearest_open_cell(Vector2i(field.cols / 2, field.rows / 2), maxi(field.cols, field.rows))
			p = field.cell_center(any) if any.x >= 0 else Vector2(field.origin + Vector2(field.cols, field.rows) * field.cell_size * 0.5)
		agent_pos[i] = p
		agent_prev[i] = p
		var initial_dir := field.sample_direction(p)
		_flow_dir_x[i] = initial_dir.x
		_flow_dir_y[i] = initial_dir.y
		agent_vel[i] = initial_dir * speed * 0.35 * _speed_scale[i]
		agent_fade[i] = 1.0
		_fill_trail(i, p)
	_force_flow_refresh = true
	trail_version += 1
	last_step_start_usec = Time.get_ticks_usec()
	agents_changed.emit()


# 目标 / 障碍编辑 ----------------------------------------------------------

func set_goal_world(world: Vector2) -> bool:
	var cell := field.nearest_open_cell(field.world_to_cell(world), 10)
	if cell.x < 0:
		return false
	field.set_goals([cell])
	_rebuild_field()
	return true


func add_goal_world(world: Vector2) -> bool:
	var cell := field.nearest_open_cell(field.world_to_cell(world), 10)
	if cell.x < 0:
		return false
	if field.goals.has(cell) or field.goals.size() >= MAX_GOALS:
		return false
	var next_goals: Array[Vector2i] = []
	for goal in field.goals:
		next_goals.append(goal)
	next_goals.append(cell)
	field.set_goals(next_goals)
	_rebuild_field()
	return true


func remove_goal_near(world: Vector2) -> bool:
	if field.goals.is_empty():
		return false
	var cell := field.world_to_cell(world)
	var best := -1
	var best_dist := INF
	for i in field.goals.size():
		var dist := Vector2(field.goals[i] - cell).length_squared()
		if dist < best_dist:
			best_dist = dist
			best = i
	if best < 0 or best_dist > 16:
		return false
	var next_goals: Array[Vector2i] = []
	for i in field.goals.size():
		if i != best:
			next_goals.append(field.goals[i])
	field.set_goals(next_goals)
	_rebuild_field()
	return true


func apply_brush(cell: Vector2i, mode: String) -> bool:
	if not field.in_bounds(cell):
		return false
	var changed := _apply_brush_raw(cell, mode)
	if changed:
		_rebuild_field()
	return changed


func apply_brush_line(from: Vector2i, to: Vector2i, mode: String) -> bool:
	var changed := false
	var x0 := from.x
	var y0 := from.y
	var x1 := to.x
	var y1 := to.y
	var dx := absi(x1 - x0)
	var sx := 1 if x0 < x1 else -1
	var dy := -absi(y1 - y0)
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		if _apply_brush_raw(Vector2i(x0, y0), mode):
			changed = true
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	if changed:
		_rebuild_field()
	return changed


func clear_obstacles() -> bool:
	var changed := field.clear_blocked()
	if changed:
		_rebuild_field()
	return changed


func _apply_brush_raw(cell: Vector2i, mode: String) -> bool:
	if not field.in_bounds(cell):
		return false
	if field.goals.has(cell) and mode != "erase":
		return false
	var idx := field.cell_index(cell)
	match mode:
		"obstacle":
			if field.cost[idx] == 0:
				return false
			field.cost[idx] = 0
			return true
		"erase":
			if field.cost[idx] == 1:
				return false
			field.cost[idx] = 1
			return true
	return false


func _rebuild_field() -> void:
	field.rebuild()
	last_build_usec = field.last_build_usec
	_spawn_cells.clear()
	for idx in field.total_cells():
		if field.cost[idx] > 0 and field.integration[idx] < GridField.INF:
			_spawn_cells.append(Vector2i(idx % field.cols, idx / field.cols))
	_goal_centers.clear()
	for goal in field.goals:
		_goal_centers.append(field.cell_center(goal))
	_goal_hit_r2 = pow(field.cell_size * 0.8, 2.0)
	_force_flow_refresh = true
	var total := field.total_cells()
	_near_wall.resize(total)
	_near_wall.fill(0)
	for idx in total:
		if field.cost[idx] != 0:
			continue
		var bx := idx % field.cols
		var by := idx / field.cols
		for dy in range(-1, 2):
			var yy := by + dy
			if yy < 0 or yy >= field.rows:
				continue
			for dx in range(-1, 2):
				var xx := bx + dx
				if xx < 0 or xx >= field.cols:
					continue
				_near_wall[yy * field.cols + xx] = 1
	_nudge_agents_out_of_walls()
	field_changed.emit()


# 模拟 ---------------------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if paused or manual_step:
		return
	step_fixed(FIXED_DT)


func step_fixed(dt: float) -> void:
	var n := agent_count
	if n <= 0:
		return
	var start_usec := Time.get_ticks_usec()
	last_step_start_usec = start_usec
	sim_time += dt
	_tick += 1
	var t0 := start_usec

	var p_cols := field.cols
	var p_rows := field.rows
	var c := field.cell_size
	var ox := field.origin.x
	var oy := field.origin.y
	var cost_l := field.cost
	var integ_l := field.integration
	var flow_l := field.flow
	var pos := agent_pos
	var vel := agent_vel
	var scales := _speed_scale
	var fade_l := agent_fade
	var sep_arr_x := _sep_x
	var sep_arr_y := _sep_y
	var goals_l := _goal_centers
	var goal_count := goals_l.size()
	var radius := agent_radius
	var total_cells := p_cols * p_rows

	# 分离力用与分离半径同尺度的细网格哈希；成对累加，每对只算一次。
	# 30Hz 逻辑下每两拍刷新一次，方向/分离都在下一拍复用，降低 GDScript 热路径成本。
	var refresh_cached := _tick % _refresh_every == 1 or _force_flow_refresh
	if refresh_cached:
		var sep_head := _sep_head
		sep_head.fill(-1)
		var sep_next := _sep_next
		var hs := _sep_hash_size
		for i in n:
			var p := pos[i]
			var cx := clampi(floori((p.x - ox) / hs), 0, _sep_hash_cols - 1)
			var cy := clampi(floori((p.y - oy) / hs), 0, _sep_hash_rows - 1)
			var ci := cy * _sep_hash_cols + cx
			sep_next[i] = sep_head[ci]
			sep_head[ci] = i
		_compute_separation(sep_head, sep_next)
		_force_flow_refresh = false

	var t_hash := Time.get_ticks_usec()
	var sep_radius := radius * 2.3
	var sep_radius2 := sep_radius * sep_radius
	var wall_influence := radius * 2.1
	var wall_influence2 := wall_influence * wall_influence
	var near_wall := _near_wall
	var min_x := ox + radius
	var max_x := ox + p_cols * c - radius
	var min_y := oy + radius
	var max_y := oy + p_rows * c - radius
	var max_force := speed * 8.0
	var max_force2 := max_force * max_force

	for i in n:
		var p := pos[i]
		agent_prev[i] = p
		var v := vel[i]
		# 双线性插值采样内联（视频 02:08）：四角流向量按面积权重混合。
		# 与分离力同拍刷新/复用，30Hz 逻辑下每两拍重算一次。
		var smp_ax := _flow_dir_x[i]
		var smp_ay := _flow_dir_y[i]
		if refresh_cached:
			var smp_lx := (p.x - ox) / c - 0.5
			var smp_ly := (p.y - oy) / c - 0.5
			var smp_x0 := floori(smp_lx)
			var smp_y0 := floori(smp_ly)
			var smp_fx := smp_lx - smp_x0
			var smp_fy := smp_ly - smp_y0
			var smp_w00 := (1.0 - smp_fx) * (1.0 - smp_fy)
			var smp_w10 := smp_fx * (1.0 - smp_fy)
			var smp_w01 := (1.0 - smp_fx) * smp_fy
			var smp_w11 := smp_fx * smp_fy
			var smp_wsum := 0.0
			smp_ax = 0.0
			smp_ay = 0.0
			if smp_x0 >= 0 and smp_y0 >= 0 and smp_x0 < p_cols and smp_y0 < p_rows:
				var smp_i := smp_y0 * p_cols + smp_x0
				if cost_l[smp_i] > 0 and integ_l[smp_i] < GridField.INF:
					var sv := flow_l[smp_i]
					smp_ax += sv.x * smp_w00
					smp_ay += sv.y * smp_w00
					smp_wsum += smp_w00
			if smp_x0 + 1 >= 0 and smp_y0 >= 0 and smp_x0 + 1 < p_cols and smp_y0 < p_rows:
				var smp_i := smp_y0 * p_cols + smp_x0 + 1
				if cost_l[smp_i] > 0 and integ_l[smp_i] < GridField.INF:
					var sv := flow_l[smp_i]
					smp_ax += sv.x * smp_w10
					smp_ay += sv.y * smp_w10
					smp_wsum += smp_w10
			if smp_x0 >= 0 and smp_y0 + 1 >= 0 and smp_x0 < p_cols and smp_y0 + 1 < p_rows:
				var smp_i := (smp_y0 + 1) * p_cols + smp_x0
				if cost_l[smp_i] > 0 and integ_l[smp_i] < GridField.INF:
					var sv := flow_l[smp_i]
					smp_ax += sv.x * smp_w01
					smp_ay += sv.y * smp_w01
					smp_wsum += smp_w01
			if smp_x0 + 1 >= 0 and smp_y0 + 1 >= 0 and smp_x0 + 1 < p_cols and smp_y0 + 1 < p_rows:
				var smp_i := (smp_y0 + 1) * p_cols + smp_x0 + 1
				if cost_l[smp_i] > 0 and integ_l[smp_i] < GridField.INF:
					var sv := flow_l[smp_i]
					smp_ax += sv.x * smp_w11
					smp_ay += sv.y * smp_w11
					smp_wsum += smp_w11
			var smp_len := sqrt(smp_ax * smp_ax + smp_ay * smp_ay)
			if smp_wsum > 0.0001 and smp_len > 0.00001:
				smp_ax /= smp_len
				smp_ay /= smp_len
			else:
				var smp_cx := clampi(floori((p.x - ox) / c), 0, p_cols - 1)
				var smp_cy := clampi(floori((p.y - oy) / c), 0, p_rows - 1)
				var smp_fb := flow_l[smp_cy * p_cols + smp_cx]
				smp_ax = smp_fb.x
				smp_ay = smp_fb.y
			_flow_dir_x[i] = smp_ax
			_flow_dir_y[i] = smp_ay
		var own_speed := speed * scales[i]
		var ax := (smp_ax * own_speed - v.x) * 5.0
		var ay := (smp_ay * own_speed - v.y) * 5.0

		# 单位间分离（视频 03:17 的“单位间碰撞”）。
		var cx := clampi(floori((p.x - ox) / c), 0, p_cols - 1)
		var cy := clampi(floori((p.y - oy) / c), 0, p_rows - 1)
		var sep_x := sep_arr_x[i]
		var sep_y := sep_arr_y[i]
		var sep2 := sep_x * sep_x + sep_y * sep_y
		if sep2 > 9.0:
			var sep_len := sqrt(sep2)
			sep_x = sep_x / sep_len * 3.0
			sep_y = sep_y / sep_len * 3.0
		ax += sep_x * speed * 2.8
		ay += sep_y * speed * 2.8

		# 障碍软斥力：避免单位贴着墙角蹭行；硬碰撞在后面兜底。
		if near_wall[cy * p_cols + cx] == 1:
			var wall_x := 0.0
			var wall_y := 0.0
			for yy in range(maxi(0, cy - 1), mini(p_rows - 1, cy + 1) + 1):
				for xx in range(maxi(0, cx - 1), mini(p_cols - 1, cx + 1) + 1):
					var ci := yy * p_cols + xx
					if cost_l[ci] != 0:
						continue
					var rx := ox + xx * c
					var ry := oy + yy * c
					var nx := clampf(p.x, rx, rx + c)
					var ny := clampf(p.y, ry, ry + c)
					var dx := p.x - nx
					var dy := p.y - ny
					var d2 := dx * dx + dy * dy
					if d2 < wall_influence2 and d2 > 0.000001:
						var dl := sqrt(d2)
						var w := 1.0 - dl / wall_influence
						wall_x += dx / dl * w
						wall_y += dy / dl * w
			var wall2 := wall_x * wall_x + wall_y * wall_y
			if wall2 > 4.0:
				var wall_len := sqrt(wall2)
				wall_x = wall_x / wall_len * 2.0
				wall_y = wall_y / wall_len * 2.0
			ax += wall_x * speed * 3.2
			ay += wall_y * speed * 3.2

		var a2 := ax * ax + ay * ay
		if a2 > max_force2:
			var al := sqrt(a2)
			ax = ax / al * max_force
			ay = ay / al * max_force
		var vx := v.x + ax * dt
		var vy := v.y + ay * dt
		var v2 := vx * vx + vy * vy
		if v2 > own_speed * own_speed:
			var vl := sqrt(v2)
			vx = vx / vl * own_speed
			vy = vy / vl * own_speed
		vel[i] = Vector2(vx, vy)
		pos[i] = Vector2(p.x + vx * dt, p.y + vy * dt)

	var t_steer := Time.get_ticks_usec()
	# 圆形单位 vs 格子障碍：墙邻格才做精确推出，其余只夹紧边界。
	var margin := radius / c
	for i in n:
		var p := pos[i]
		var lx := (p.x - ox) / c
		var ly := (p.y - oy) / c
		var cx := floori(lx)
		var cy := floori(ly)
		if cx >= 0 and cy >= 0 and cx < p_cols and cy < p_rows:
			if near_wall[cy * p_cols + cx] == 0:
				p.x = clampf(p.x, min_x, max_x)
				p.y = clampf(p.y, min_y, max_y)
				pos[i] = p
				continue
			var fx := lx - cx
			var fy := ly - cy
			if cost_l[cy * p_cols + cx] > 0 and fx >= margin and fx <= 1.0 - margin and fy >= margin and fy <= 1.0 - margin:
				p.x = clampf(p.x, min_x, max_x)
				p.y = clampf(p.y, min_y, max_y)
				pos[i] = p
				continue
		pos[i] = _resolve_walls(p, ox, oy, c, p_cols, p_rows, cost_l, radius)

	var t_collide := Time.get_ticks_usec()
	for i in n:
		fade_l[i] = minf(1.0, fade_l[i] + dt * 2.8)
		var p := pos[i]
		var hit := false
		for g in goal_count:
			var gc := goals_l[g]
			var dx := p.x - gc.x
			var dy := p.y - gc.y
			if dx * dx + dy * dy < _goal_hit_r2:
				hit = true
				break
		if hit:
			_respawn_agent(i)

	var t_goal := Time.get_ticks_usec()
	if _tick % _trail_every == 0:
		_shift_trails()
	var t_trail := Time.get_ticks_usec()

	last_step_usec = Time.get_ticks_usec() - start_usec
	step_count += 1
	step_total_usec += last_step_usec
	step_max_usec = maxi(step_max_usec, last_step_usec)
	avg_step_usec = lerpf(avg_step_usec, float(last_step_usec), 0.06)
	if profiling:
		prof["hash"] = prof.get("hash", 0) + (t_hash - t0)
		prof["steer"] = prof.get("steer", 0) + (t_steer - t_hash)
		prof["collide"] = prof.get("collide", 0) + (t_collide - t_steer)
		prof["goal"] = prof.get("goal", 0) + (t_goal - t_collide)
		prof["trail"] = prof.get("trail", 0) + (t_trail - t_goal)
		prof["total"] = prof.get("total", 0) + last_step_usec


func _compute_separation(head: PackedInt32Array, next_agent: PackedInt32Array) -> void:
	var n := agent_count
	var cols_l := _sep_hash_cols
	var rows_l := _sep_hash_rows
	var pos := agent_pos
	var sep_arr_x := _sep_x
	var sep_arr_y := _sep_y
	sep_arr_x.fill(0.0)
	sep_arr_y.fill(0.0)
	var radius := agent_radius * 2.3
	var radius2 := radius * radius
	for ci in head.size():
		var i := head[ci]
		if i == -1:
			continue
		var cx := ci % cols_l
		var cy := ci / cols_l
		while i != -1:
			var pi := pos[i]
			# 自身格 + 右侧三格 + 下方格 = 每个单位对只遍历一次。
			for k in 5:
				var xx := cx
				var yy := cy
				match k:
					1:
						xx = cx + 1
						yy = cy - 1
					2:
						xx = cx + 1
					3:
						xx = cx + 1
						yy = cy + 1
					4:
						yy = cy + 1
				if xx < 0 or yy < 0 or xx >= cols_l or yy >= rows_l:
					continue
				var j := head[yy * cols_l + xx]
				while j != -1:
					if xx == cx and yy == cy and j <= i:
						j = next_agent[j]
						continue
					var q := pos[j]
					var dx := pi.x - q.x
					var dy := pi.y - q.y
					var d2 := dx * dx + dy * dy
					if d2 < radius2:
						var dl := sqrt(maxf(d2, 0.000001))
						if d2 < 0.000001:
							var angle := float(i * 37 + j * 17) * 0.618
							dx = cos(angle)
							dy = sin(angle)
							dl = 0.01
						var w := 1.0 - dl / radius
						var fx := dx / dl * w
						var fy := dy / dl * w
						sep_arr_x[i] += fx
						sep_arr_y[i] += fy
						sep_arr_x[j] -= fx
						sep_arr_y[j] -= fy
					j = next_agent[j]
			i = next_agent[i]


func _resolve_walls(p: Vector2, ox: float, oy: float, c: float, p_cols: int, p_rows: int, cost_l: PackedInt32Array, r: float) -> Vector2:
	var minx := clampi(floori((p.x - r - ox) / c) - 1, 0, p_cols - 1)
	var maxx := clampi(floori((p.x + r - ox) / c) + 1, 0, p_cols - 1)
	var miny := clampi(floori((p.y - r - oy) / c) - 1, 0, p_rows - 1)
	var maxy := clampi(floori((p.y + r - oy) / c) + 1, 0, p_rows - 1)
	for iteration in 3:
		var moved := false
		for cy in range(miny, maxy + 1):
			for cx in range(minx, maxx + 1):
				if cost_l[cy * p_cols + cx] != 0:
					continue
				var rx := ox + cx * c
				var ry := oy + cy * c
				var nearest_x := clampf(p.x, rx, rx + c)
				var nearest_y := clampf(p.y, ry, ry + c)
				var dx := p.x - nearest_x
				var dy := p.y - nearest_y
				var d2 := dx * dx + dy * dy
				if d2 >= r * r:
					continue
				if d2 < 0.000001:
					var dl := p.x - rx
					var dr := rx + c - p.x
					var dt := p.y - ry
					var db := ry + c - p.y
					var m := minf(minf(dl, dr), minf(dt, db))
					if m == dl:
						p.x = rx - r - 0.01
					elif m == dr:
						p.x = rx + c + r + 0.01
					elif m == dt:
						p.y = ry - r - 0.01
					else:
						p.y = ry + c + r + 0.01
				else:
					var dl := sqrt(d2)
					p.x = nearest_x + dx / dl * (r + 0.01)
					p.y = nearest_y + dy / dl * (r + 0.01)
				moved = true
		if not moved:
			break
	var min_x := ox + r
	var max_x := ox + p_cols * c - r
	var min_y := oy + r
	var max_y := oy + p_rows * c - r
	p.x = clampf(p.x, min_x, max_x)
	p.y = clampf(p.y, min_y, max_y)
	return p


func _respawn_agent(i: int) -> void:
	var p := _spawn_position(true)
	if p == Vector2.INF:
		agent_vel[i] = Vector2.ZERO
		return
	agent_pos[i] = p
	agent_prev[i] = p
	agent_vel[i] = Vector2.ZERO
	agent_fade[i] = 0.18
	_sep_x[i] = 0.0
	_sep_y[i] = 0.0
	_fill_trail(i, p)
	arrivals += 1


func _spawn_position(require_far: bool) -> Vector2:
	if _spawn_cells.is_empty():
		return Vector2.INF
	for attempt in 40:
		var cell: Vector2i = _spawn_cells[_agent_rng.randi_range(0, _spawn_cells.size() - 1)]
		if field.goals.has(cell):
			continue
		if require_far and field.integration[field.cell_index(cell)] < SPAWN_FAR_STEPS:
			continue
		var jitter := Vector2(
			_agent_rng.randf_range(-0.32, 0.32),
			_agent_rng.randf_range(-0.32, 0.32)) * field.cell_size
		var p := field.cell_center(cell) + jitter
		if _circle_free(p, agent_radius * 1.04):
			return p
	for attempt in 12:
		var fallback: Vector2i = _spawn_cells[_agent_rng.randi_range(0, _spawn_cells.size() - 1)]
		if not field.goals.has(fallback):
			return field.cell_center(fallback)
	return Vector2.INF


func _circle_free(p: Vector2, r: float) -> bool:
	var bounds := Rect2(field.origin, Vector2(field.cols, field.rows) * field.cell_size)
	if p.x < bounds.position.x + r or p.y < bounds.position.y + r or p.x > bounds.end.x - r or p.y > bounds.end.y - r:
		return false
	var min_cell := field.world_to_cell(p - Vector2(r, r))
	var max_cell := field.world_to_cell(p + Vector2(r, r))
	for y in range(maxi(0, min_cell.y - 1), mini(field.rows - 1, max_cell.y + 1) + 1):
		for x in range(maxi(0, min_cell.x - 1), mini(field.cols - 1, max_cell.x + 1) + 1):
			var cell := Vector2i(x, y)
			if field.cost[field.cell_index(cell)] != 0:
				continue
			var rect := field.cell_rect(cell)
			var nearest := Vector2(
				clampf(p.x, rect.position.x, rect.end.x),
				clampf(p.y, rect.position.y, rect.end.y))
			if p.distance_squared_to(nearest) < r * r:
				return false
	return true


func _nudge_agents_out_of_walls() -> void:
	for i in agent_count:
		if _circle_free(agent_pos[i], agent_radius * 0.98):
			continue
		var cell := field.nearest_open_cell(field.world_to_cell(agent_pos[i]), 12)
		if cell.x < 0:
			continue
		var p := field.cell_center(cell)
		if not _circle_free(p, agent_radius * 1.02):
			continue
		agent_pos[i] = p
		agent_prev[i] = p
		agent_vel[i] = Vector2.ZERO
		_fill_trail(i, p)


func _fill_trail(i: int, p: Vector2) -> void:
	var base := i * TRAIL_LEN
	for k in TRAIL_LEN:
		trail[base + k] = p


func _shift_trails() -> void:
	for i in agent_count:
		var base := i * TRAIL_LEN
		for k in range(TRAIL_LEN - 1):
			trail[base + k] = trail[base + k + 1]
		trail[base + TRAIL_LEN - 1] = agent_pos[i]
	trail_version += 1


# 供 UI / 工具读取 -----------------------------------------------------------

func build_ms() -> float:
	return float(last_build_usec) / 1000.0


func step_ms() -> float:
	return avg_step_usec / 1000.0


func render_alpha() -> float:
	if paused or manual_step:
		return 1.0
	var elapsed := Time.get_ticks_usec() - last_step_start_usec
	return clampf(float(elapsed) / (FIXED_DT * 1000000.0), 0.0, 1.0)


func reachable_ratio() -> float:
	if field.open_cells <= 0:
		return 0.0
	return float(field.reachable_cells) / float(field.open_cells)
