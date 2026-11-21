class_name FlowFieldGrid
extends RefCounted

# 代价场 / 积分场 / 流场（纯数据与算法，不依赖节点）。
# 视频中的视觉语言：粉色网格、青色 8 邻域箭头、深青障碍、青色目标、粉色单位。
#
# 数据结构：
#   cost[i]        0 = 不可行走（障碍）；1 = 可行走平地
#   integration[i] 从任意目标格出发的 8 邻域 BFS 步数；INF = 不可达
#   flow[i]        指向积分值更小邻格的单位方向；目标/障碍/不可达 = 零向量
#
# 视频 01:37 的 BFS 伪代码以目标入队、逐格 +1；这里扩展到 8 邻接，
# 对角移动要求两侧正交格都可行走，禁止贴角穿墙。
# 固定邻域顺序 = 固定的平局裁决顺序，保证同地图同目标结果可复现。
# 地形代价：视频只演示“障碍/目标”，因此保持平地 + 障碍的二元代价；
# 若后续要加权，可把 BFS 换成 Dijkstra，而不改变 flow 的输出格式。

const INF := 1 << 30
const GOAL_VALUE := 0

const OFF_X := [1, 0, 0, -1, 1, 1, -1, -1]
const OFF_Y := [0, -1, 1, 0, -1, 1, -1, 1]
const DIR_X := [1.0, 0.0, 0.0, -1.0, 0.70710678, 0.70710678, -0.70710678, -0.70710678]
const DIR_Y := [0.0, -1.0, 1.0, 0.0, -0.70710678, 0.70710678, -0.70710678, 0.70710678]

var cols := 0
var rows := 0
var origin := Vector2.ZERO
var cell_size := 24.0

var cost := PackedInt32Array()
var integration := PackedInt32Array()
var flow := PackedVector2Array()
var goals: Array[Vector2i] = []

var open_cells := 0
var reachable_cells := 0
var last_build_usec := 0
var prof_integration_us := 0
var prof_flow_us := 0

var _queue := PackedInt32Array()
var _goal_mask := PackedByteArray()


func configure(p_cols: int, p_rows: int, p_origin: Vector2, p_cell_size: float) -> void:
	cols = maxi(1, p_cols)
	rows = maxi(1, p_rows)
	origin = p_origin
	cell_size = maxf(4.0, p_cell_size)
	var total := cols * rows
	cost.resize(total)
	cost.fill(1)
	integration.resize(total)
	integration.fill(INF)
	flow.resize(total)
	flow.fill(Vector2.ZERO)
	_goal_mask.resize(total)
	_goal_mask.fill(0)
	goals.clear()
	open_cells = total
	reachable_cells = 0
	last_build_usec = 0
	_queue.clear()


func total_cells() -> int:
	return cols * rows


func cell_index(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < cols and cell.y < rows


func is_open(cell: Vector2i) -> bool:
	return in_bounds(cell) and cost[cell_index(cell)] > 0


func is_goal_cell(cell: Vector2i) -> bool:
	return goals.has(cell)


func world_to_cell(world: Vector2) -> Vector2i:
	var local := (world - origin) / cell_size
	return Vector2i(floori(local.x), floori(local.y))


func cell_center(cell: Vector2i) -> Vector2:
	return origin + Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size


func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(cell) * cell_size, Vector2(cell_size, cell_size))


func set_goals(cells: Array) -> void:
	goals.clear()
	for cell: Vector2i in cells:
		if is_open(cell) and not goals.has(cell):
			goals.append(cell)


func set_cost(cell: Vector2i, value: int) -> bool:
	if not in_bounds(cell):
		return false
	var idx := cell_index(cell)
	var blocked := 1 if value <= 0 else 0
	var next_cost := 0 if blocked == 1 else 1
	if cost[idx] == next_cost:
		return false
	cost[idx] = next_cost
	return true


func clear_blocked() -> bool:
	var changed := false
	for i in cost.size():
		if cost[i] == 0:
			cost[i] = 1
			changed = true
	return changed


func largest_open_component() -> Array[Vector2i]:
	var total := cols * rows
	var seen := PackedByteArray()
	seen.resize(total)
	seen.fill(0)
	var best: Array[Vector2i] = []
	var queue: Array[Vector2i] = []
	var best_size := 0
	for start in total:
		if seen[start] == 1 or cost[start] <= 0:
			continue
		queue.clear()
		var comp_size := 0
		queue.append(Vector2i(start % cols, start / cols))
		seen[start] = 1
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			comp_size += 1
			for k in 4:
				var nx := cell.x + (1 if k == 0 else (-1 if k == 1 else 0))
				var ny := cell.y + (1 if k == 2 else (-1 if k == 3 else 0))
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				var ni := ny * cols + nx
				if seen[ni] == 1 or cost[ni] <= 0:
					continue
				seen[ni] = 1
				queue.append(Vector2i(nx, ny))
		if comp_size > best_size:
			best_size = comp_size
			best.clear()
			for cell in queue:
				best.append(cell)
	return best


func nearest_open_cell(cell: Vector2i, max_radius := 8) -> Vector2i:
	if is_open(cell):
		return cell
	for radius in range(1, max_radius + 1):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var probe := cell + Vector2i(dx, dy)
				if is_open(probe):
					return probe
	return Vector2i(-1, -1)


func rebuild() -> void:
	var start_usec := Time.get_ticks_usec()
	var total := cols * rows
	integration.fill(INF)
	flow.fill(Vector2.ZERO)
	_goal_mask.fill(0)
	open_cells = 0
	for i in total:
		if cost[i] > 0:
			open_cells += 1

	# 多源 BFS：目标先入队，8 邻接逐层 +1。
	_queue.clear()
	for goal in goals:
		if not is_open(goal):
			continue
		var idx := cell_index(goal)
		_goal_mask[idx] = 1
		integration[idx] = GOAL_VALUE
		_queue.append(idx)

	var head := 0
	var c_cols := cols
	var c_rows := rows
	while head < _queue.size():
		var idx := _queue[head]
		head += 1
		var x := idx % c_cols
		var y := idx / c_cols
		var next_value := integration[idx] + 1
		for k in 8:
			var nx: int = x + OFF_X[k]
			var ny: int = y + OFF_Y[k]
			if nx < 0 or ny < 0 or nx >= c_cols or ny >= c_rows:
				continue
			var nidx := ny * c_cols + nx
			if cost[nidx] <= 0 or integration[nidx] != INF:
				continue
			if k >= 4:
				# 禁斜穿墙角：两侧正交格都必须可行走。
				if cost[y * c_cols + nx] <= 0 or cost[ny * c_cols + x] <= 0:
					continue
			integration[nidx] = next_value
			_queue.append(nidx)

	var t_integration := Time.get_ticks_usec()
	reachable_cells = _queue.size()

	# 流场：每格选择积分值最小的邻格。固定遍历顺序，平局也确定。
	for idx in total:
		if cost[idx] <= 0 or integration[idx] >= INF or _goal_mask[idx] == 1:
			continue
		var x := idx % c_cols
		var y := idx / c_cols
		var best := INF
		var best_k := -1
		for k in 8:
			var nx: int = x + OFF_X[k]
			var ny: int = y + OFF_Y[k]
			if nx < 0 or ny < 0 or nx >= c_cols or ny >= c_rows:
				continue
			var nidx := ny * c_cols + nx
			if cost[nidx] <= 0:
				continue
			if k >= 4:
				if cost[y * c_cols + nx] <= 0 or cost[ny * c_cols + x] <= 0:
					continue
			var value := integration[nidx]
			if value < best:
				best = value
				best_k = k
		if best_k >= 0 and best < integration[idx]:
			flow[idx] = Vector2(DIR_X[best_k], DIR_Y[best_k])

	var t_flow := Time.get_ticks_usec()
	last_build_usec = t_flow - start_usec
	prof_integration_us = t_integration - start_usec
	prof_flow_us = t_flow - t_integration


# 双线性插值采样：视频 02:08 处专门讲过的平滑转向。
# 取单位所在格四角的流向量按面积权重混合；若四角都被墙占据则退回最近格。
func sample_direction(world: Vector2) -> Vector2:
	if cols <= 0 or rows <= 0:
		return Vector2.ZERO
	var c := cell_size
	var local_x := (world.x - origin.x) / c - 0.5
	var local_y := (world.y - origin.y) / c - 0.5
	var x0 := floori(local_x)
	var y0 := floori(local_y)
	var fx := local_x - x0
	var fy := local_y - y0
	var w00 := (1.0 - fx) * (1.0 - fy)
	var w10 := fx * (1.0 - fy)
	var w01 := (1.0 - fx) * fy
	var w11 := fx * fy
	var cols_l := cols
	var rows_l := rows
	var cost_l := cost
	var integ_l := integration
	var flow_l := flow
	var ax := 0.0
	var ay := 0.0
	var weight_sum := 0.0
	if x0 >= 0 and y0 >= 0 and x0 < cols_l and y0 < rows_l:
		var idx := y0 * cols_l + x0
		if cost_l[idx] > 0 and integ_l[idx] < INF:
			var v := flow_l[idx]
			ax += v.x * w00
			ay += v.y * w00
			weight_sum += w00
	if x0 + 1 >= 0 and y0 >= 0 and x0 + 1 < cols_l and y0 < rows_l:
		var idx := y0 * cols_l + x0 + 1
		if cost_l[idx] > 0 and integ_l[idx] < INF:
			var v := flow_l[idx]
			ax += v.x * w10
			ay += v.y * w10
			weight_sum += w10
	if x0 >= 0 and y0 + 1 >= 0 and x0 < cols_l and y0 + 1 < rows_l:
		var idx := (y0 + 1) * cols_l + x0
		if cost_l[idx] > 0 and integ_l[idx] < INF:
			var v := flow_l[idx]
			ax += v.x * w01
			ay += v.y * w01
			weight_sum += w01
	if x0 + 1 >= 0 and y0 + 1 >= 0 and x0 + 1 < cols_l and y0 + 1 < rows_l:
		var idx := (y0 + 1) * cols_l + x0 + 1
		if cost_l[idx] > 0 and integ_l[idx] < INF:
			var v := flow_l[idx]
			ax += v.x * w11
			ay += v.y * w11
			weight_sum += w11
	if weight_sum > 0.0001:
		var length := sqrt(ax * ax + ay * ay)
		if length > 1.0e-5:
			return Vector2(ax / length, ay / length)
	var cx := floori((world.x - origin.x) / c)
	var cy := floori((world.y - origin.y) / c)
	if cx >= 0 and cy >= 0 and cx < cols_l and cy < rows_l:
		return flow_l[cy * cols_l + cx]
	return Vector2.ZERO
