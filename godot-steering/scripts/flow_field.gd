class_name SteeringFlowField
extends RefCounted

## 流场寻路（视频中的青色箭头网格）：
## 以目标格为源做 8 邻域 BFS，每个可通行格记录“指向父格”的单位方向。
## 对角移动要求两侧正交格都可通行，避免贴角穿墙。

const NEIGHBORS := [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var cell_size := 22.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var blocked := PackedByteArray()
var distance := PackedInt32Array()
var direction := PackedVector2Array()
var goal_cell := Vector2i(-1, -1)
var built := false

var _queue := PackedInt32Array()


func build(rects: Array, circles: Array, bounds: Rect2, goal: Vector2, cell: float) -> void:
	cell_size = maxf(10.0, cell)
	origin = bounds.position
	cols = maxi(1, int(ceil(bounds.size.x / cell_size)))
	rows = maxi(1, int(ceil(bounds.size.y / cell_size)))
	var total := cols * rows
	blocked.resize(total)
	blocked.fill(0)
	distance.resize(total)
	distance.fill(-1)
	direction.resize(total)
	direction.fill(Vector2.ZERO)

	# 标记障碍占据的格子：格子矩形与障碍相交即视为不可通行。
	for r: Rect2 in rects:
		var r0 := int(floor((r.position.x - origin.x) / cell_size))
		var r1 := int(floor((r.end.x - origin.x) / cell_size))
		var c0 := int(floor((r.position.y - origin.y) / cell_size))
		var c1 := int(floor((r.end.y - origin.y) / cell_size))
		for cy in range(maxi(0, c0), mini(rows - 1, c1) + 1):
			for cx in range(maxi(0, r0), mini(cols - 1, r1) + 1):
				var cell_rect := Rect2(origin + Vector2(cx, cy) * cell_size, Vector2(cell_size, cell_size))
				if cell_rect.intersects(r):
					blocked[cy * cols + cx] = 1
	for c in circles:
		var center: Vector2 = c.position
		var radius: float = c.radius
		var r0 := int(floor((center.x - radius - origin.x) / cell_size))
		var r1 := int(floor((center.x + radius - origin.x) / cell_size))
		var c0 := int(floor((center.y - radius - origin.y) / cell_size))
		var c1 := int(floor((center.y + radius - origin.y) / cell_size))
		for cy in range(maxi(0, c0), mini(rows - 1, c1) + 1):
			for cx in range(maxi(0, r0), mini(cols - 1, r1) + 1):
				var cell_rect := Rect2(origin + Vector2(cx, cy) * cell_size, Vector2(cell_size, cell_size))
				var nearest := Vector2(
					clampf(center.x, cell_rect.position.x, cell_rect.end.x),
					clampf(center.y, cell_rect.position.y, cell_rect.end.y))
				if center.distance_squared_to(nearest) <= radius * radius:
					blocked[cy * cols + cx] = 1

	goal_cell = world_to_cell(goal)
	if not is_open(goal_cell):
		goal_cell = _find_open_near(goal_cell, 6)
	if not is_open(goal_cell):
		built = false
		return

	_queue.clear()
	var start := cell_index(goal_cell)
	distance[start] = 0
	_queue.push_back(start)
	var head := 0
	while head < _queue.size():
		var idx := _queue[head]
		head += 1
		var cx := idx % cols
		var cy := idx / cols
		var d := distance[idx]
		for n in NEIGHBORS:
			var nx: int = cx + n.x
			var ny: int = cy + n.y
			if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
				continue
			if blocked[ny * cols + nx] == 1:
				continue
			# 对角步：两侧正交格都需可通行。
			if n.x != 0 and n.y != 0:
				if blocked[cy * cols + nx] == 1 or blocked[ny * cols + cx] == 1:
					continue
			var nidx := ny * cols + nx
			if distance[nidx] >= 0:
				continue
			distance[nidx] = d + 1
			_queue.push_back(nidx)

	# 方向指向父格（距离更小的邻格）。
	for cy in rows:
		for cx in cols:
			var idx := cy * cols + cx
			if distance[idx] < 0 or idx == start:
				continue
			var best_d := distance[idx]
			var best_dir := Vector2.ZERO
			for n in NEIGHBORS:
				var nx: int = cx + n.x
				var ny: int = cy + n.y
				if nx < 0 or ny < 0 or nx >= cols or ny >= rows:
					continue
				if n.x != 0 and n.y != 0:
					if blocked[cy * cols + nx] == 1 or blocked[ny * cols + cx] == 1:
						continue
				var nidx := ny * cols + nx
				var nd := distance[nidx]
				if nd < 0 or nd >= best_d:
					continue
				best_d = nd
				best_dir = Vector2(n)
			if best_dir != Vector2.ZERO:
				direction[idx] = best_dir.normalized()
	built = false
	# 目标格本身的方向指向目标中心（供近目标采样）。
	direction[start] = (goal - cell_center(goal_cell)).normalized()
	built = true


func cell_center(cell: Vector2i) -> Vector2:
	return origin + (Vector2(cell) + Vector2(0.5, 0.5)) * cell_size


func cell_index(cell: Vector2i) -> int:
	return cell.y * cols + cell.x


func is_open(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return false
	return blocked[cell_index(cell)] == 0


func world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - origin.x) / cell_size)), int(floor((pos.y - origin.y) / cell_size)))


func sample(pos: Vector2) -> Vector2:
	if not built:
		return Vector2.ZERO
	var cell := world_to_cell(pos)
	if is_open(cell):
		return direction[cell_index(cell)]
	var open := _find_open_near(cell, 4)
	if open.x >= 0:
		return direction[cell_index(open)]
	return Vector2.ZERO


## 距目标格的曼哈顿格数（用于近目标减速/停止判断）。
func goal_distance_cells(pos: Vector2) -> int:
	if not built:
		return 9999
	var cell := world_to_cell(pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= cols or cell.y >= rows:
		return 9999
	var d := distance[cell_index(cell)]
	return d if d >= 0 else 9999


func _find_open_near(cell: Vector2i, radius: int) -> Vector2i:
	for ring in range(1, radius + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				var c := Vector2i(cell.x + dx, cell.y + dy)
				if is_open(c):
					return c
	return Vector2i(-1, -1)
