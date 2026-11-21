extends SceneTree

# 流场正确性冒烟测试（headless）。
# 覆盖：可达性一致、流场单调、禁斜穿墙角、编辑重建、智能体碰撞/NaN、可复现性。
# 运行：godot --path . --headless -s tools/smoke_flowfield.gd
# 成功输出最后一行：FLOWFIELD_SMOKE_OK

const GridScript = preload("res://scripts/flow_field_grid.gd")
const SimScript = preload("res://scripts/flow_sim.gd")

const OFF_X := [1, 0, 0, -1, 1, 1, -1, -1]
const OFF_Y := [0, -1, 1, 0, -1, 1, -1, 1]

var _failures := 0


func _initialize() -> void:
	_check_reachability_sample()
	_check_reachability_random()
	_check_corner_rule()
	_check_flow_monotonic()
	_check_editing()
	_check_simulation()
	_check_determinism()
	if _failures == 0:
		print("FLOWFIELD_SMOKE_OK")
		quit(0)
	else:
		print("FLOWFIELD_SMOKE_FAIL failures=%d" % _failures)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] " + message)
	else:
		_failures += 1
		print("[FAIL] " + message)


# 独立 BFS：不复用被测实现的积分场，只读 cost/goals，验证可达集合。
func _bfs_reachable(grid) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(grid.total_cells())
	seen.fill(0)
	var queue: Array[int] = []
	for goal in grid.goals:
		if not grid.is_open(goal):
			continue
		var idx: int = grid.cell_index(goal)
		seen[idx] = 1
		queue.append(idx)
	var head := 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % grid.cols
		var y: int = idx / grid.cols
		for k in 8:
			var nx: int = x + OFF_X[k]
			var ny: int = y + OFF_Y[k]
			if nx < 0 or ny < 0 or nx >= grid.cols or ny >= grid.rows:
				continue
			var nidx: int = ny * grid.cols + nx
			if grid.cost[nidx] <= 0 or seen[nidx] == 1:
				continue
			if k >= 4 and (grid.cost[y * grid.cols + nx] <= 0 or grid.cost[ny * grid.cols + x] <= 0):
				continue
			seen[nidx] = 1
			queue.append(nidx)
	return seen


func _check_reachability_sample() -> void:
	var sim = SimScript.new()
	sim.setup(Rect2(28, 96, 884, 596), "medium", 421)
	var grid = sim.field
	var seen := _bfs_reachable(grid)
	var mismatch := 0
	for idx in grid.total_cells():
		var finite: bool = grid.integration[idx] < GridScript.INF
		if finite != (seen[idx] == 1):
			mismatch += 1
	_expect(mismatch == 0, "C 形样例：积分场有限值与独立 BFS 可达性一致（%d 格）" % grid.reachable_cells)
	_expect(grid.integration[grid.cell_index(grid.goals[0])] == 0, "目标格积分值为 0")
	sim.free()


func _check_reachability_random() -> void:
	var sim = SimScript.new()
	sim.setup(Rect2(28, 96, 884, 596), "large", 777)
	sim.load_random("large", 777)
	var grid = sim.field
	var seen := _bfs_reachable(grid)
	var mismatch := 0
	var unreachable_open := 0
	for idx in grid.total_cells():
		var finite: bool = grid.integration[idx] < GridScript.INF
		if finite != (seen[idx] == 1):
			mismatch += 1
		if grid.cost[idx] > 0 and seen[idx] == 0:
			unreachable_open += 1
	_expect(mismatch == 0, "随机大地图：可达性与 BFS 一致（可达 %d，不可达开放 %d）" % [
		grid.reachable_cells, unreachable_open])
	sim.free()


func _check_corner_rule() -> void:
	var grid = GridScript.new()
	grid.configure(3, 3, Vector2.ZERO, 20.0)
	grid.set_cost(Vector2i(1, 0), 0)
	grid.set_cost(Vector2i(0, 1), 0)
	grid.set_goals([Vector2i(0, 0)])
	grid.rebuild()
	_expect(grid.integration[grid.cell_index(Vector2i(1, 1))] == GridScript.INF,
		"禁斜穿墙角：两侧正交格均被堵时对角线不可达")
	grid.set_cost(Vector2i(1, 0), 1)
	grid.set_cost(Vector2i(0, 1), 1)
	grid.rebuild()
	_expect(grid.integration[grid.cell_index(Vector2i(1, 1))] == 1,
		"墙角解除后对角线一步可达")


func _check_flow_monotonic() -> void:
	var sim = SimScript.new()
	sim.setup(Rect2(28, 96, 884, 596), "medium", 421)
	var grid = sim.field
	var bad_flow := 0
	var bad_corner := 0
	var bad_goal := 0
	for idx in grid.total_cells():
		var dir: Vector2 = grid.flow[idx]
		if grid.cost[idx] <= 0 or grid.integration[idx] >= GridScript.INF:
			if dir.length_squared() > 0.0001:
				bad_flow += 1
			continue
		var x: int = idx % grid.cols
		var y: int = idx / grid.cols
		if grid.goals.has(Vector2i(x, y)):
			if dir.length_squared() > 0.0001:
				bad_goal += 1
			continue
		if dir.length_squared() < 0.5:
			bad_flow += 1
			continue
		var nx := x + roundi(dir.x)
		var ny := y + roundi(dir.y)
		if nx < 0 or ny < 0 or nx >= grid.cols or ny >= grid.rows:
			bad_flow += 1
			continue
		var nidx: int = ny * grid.cols + nx
		if grid.integration[nidx] >= grid.integration[idx]:
			bad_flow += 1
		if absi(nx - x) == 1 and absi(ny - y) == 1:
			if grid.cost[y * grid.cols + nx] <= 0 or grid.cost[ny * grid.cols + x] <= 0:
				bad_corner += 1
	_expect(bad_flow == 0, "流场单调：所有非目标可达格的流向邻格积分值更小（坏格 %d）" % bad_flow)
	_expect(bad_corner == 0, "流向无斜穿墙角（坏格 %d）" % bad_corner)
	_expect(bad_goal == 0, "目标格流向量为零（坏格 %d）" % bad_goal)
	sim.free()


func _check_editing() -> void:
	var sim = SimScript.new()
	sim.setup(Rect2(28, 96, 884, 596), "medium", 421)
	var base_reach: int = sim.field.reachable_cells
	var base_open: int = sim.field.open_cells
	var cell := Vector2i(3, 3)
	_expect(sim.apply_brush(cell, "obstacle"), "障碍画笔：可行走格可改为障碍")
	_expect(sim.field.cost[sim.field.cell_index(cell)] == 0, "障碍画笔：代价场写入 0")
	_expect(sim.field.reachable_cells < base_reach, "画障碍后积分场重建，可达格减少")
	_expect(sim.apply_brush(cell, "erase"), "擦除画笔：可恢复单格")
	_expect(sim.field.reachable_cells == base_reach and sim.field.open_cells == base_open,
		"擦除单格后可达格/开放格恢复基线")
	_expect(sim.clear_obstacles(), "清障：返回 changed=true")
	_expect(sim.field.open_cells == sim.field.total_cells()
		and sim.field.reachable_cells == sim.field.total_cells(),
		"清障后全图开放且连通（%d 格）" % sim.field.reachable_cells)
	var target: Vector2 = sim.field.cell_center(Vector2i(sim.field.cols - 4, sim.field.rows - 4))
	_expect(sim.set_goal_world(target), "目标放置：可行走处成功")
	_expect(sim.add_goal_world(sim.field.cell_center(Vector2i(2, sim.field.rows - 3))), "多目标：添加第二个目标")
	_expect(sim.field.goals.size() == 2, "多目标：目标数 = 2")
	_expect(sim.remove_goal_near(sim.field.cell_center(sim.field.goals[0])), "多目标：移除最近目标")
	_expect(sim.field.goals.size() == 1, "多目标：移除后目标数 = 1")
	sim.free()


func _circle_hits_wall(sim, p: Vector2) -> bool:
	var field = sim.field
	var r: float = sim.agent_radius * 0.94
	var min_cell: Vector2i = field.world_to_cell(p - Vector2(r, r))
	var max_cell: Vector2i = field.world_to_cell(p + Vector2(r, r))
	for y in range(maxi(0, min_cell.y), mini(field.rows - 1, max_cell.y) + 1):
		for x in range(maxi(0, min_cell.x), mini(field.cols - 1, max_cell.x) + 1):
			if field.cost[field.cell_index(Vector2i(x, y))] != 0:
				continue
			var rect: Rect2 = field.cell_rect(Vector2i(x, y))
			var nearest := Vector2(
				clampf(p.x, rect.position.x, rect.end.x),
				clampf(p.y, rect.position.y, rect.end.y))
			if p.distance_squared_to(nearest) < r * r:
				return true
	return false


func _check_simulation() -> void:
	var sim = SimScript.new()
	sim.setup(Rect2(28, 96, 884, 596), "medium", 421)
	sim.set_agent_count(500)
	var start: PackedVector2Array = sim.agent_pos.duplicate()
	var steps := 180
	for i in steps:
		sim.step_fixed(1.0 / 30.0)
	var bad_nan := 0
	var bad_wall := 0
	var moved := 0
	var total_dist := 0.0
	for i in sim.agent_count:
		var p: Vector2 = sim.agent_pos[i]
		var v: Vector2 = sim.agent_vel[i]
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(v.x) and is_finite(v.y)):
			bad_nan += 1
		if _circle_hits_wall(sim, p):
			bad_wall += 1
		var d := p.distance_to(start[i])
		total_dist += d
		if d > 2.0:
			moved += 1
	_expect(bad_nan == 0, "模拟 6 秒：位置/速度无 NaN（坏值 %d）" % bad_nan)
	_expect(bad_wall == 0, "模拟 6 秒：智能体圆不与障碍格重叠（穿墙 %d）" % bad_wall)
	_expect(moved > sim.agent_count / 2, "群体沿场移动：%d/%d 个智能体位移 > 2px" % [moved, sim.agent_count])
	_expect(total_dist > 1000.0, "群体累计位移有限且明显（%.0f px）" % total_dist)
	_expect(sim.arrivals > 0, "目标到达后重生机制运转（到达 %d 次）" % sim.arrivals)
	_expect(sim.avg_step_usec > 0.0 and sim.avg_step_usec < 33333.0,
		"500 智能体逻辑步长均值 %.2f ms < 33.3 ms" % sim.step_ms())
	sim.free()


func _check_determinism() -> void:
	var a = SimScript.new()
	var b = SimScript.new()
	for sim in [a, b]:
		sim.setup(Rect2(28, 96, 884, 596), "medium", 421)
		sim.set_agent_count(300)
	for i in 90:
		a.step_fixed(1.0 / 30.0)
		b.step_fixed(1.0 / 30.0)
	var field_equal: bool = a.field.integration == b.field.integration and a.field.flow == b.field.flow
	var max_delta := 0.0
	for i in a.agent_count:
		max_delta = maxf(max_delta, a.agent_pos[i].distance_to(b.agent_pos[i]))
	_expect(field_equal, "可复现：同地图同目标两次积分场/流场逐位相同")
	_expect(max_delta < 0.001, "可复现：同种子 300 智能体 90 步位置最大偏差 %.6f px" % max_delta)
	a.free()
	b.free()
