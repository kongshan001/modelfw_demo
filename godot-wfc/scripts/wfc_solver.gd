extends RefCounted

# 波函数坍缩求解器（纯逻辑，不依赖渲染）。
#
# 叠加态：每格一个 14-bit 掩码，bit t 表示瓦片 t 仍可能。
# 约束：相邻边的接口值必须相同（0 草地 / 1 石径）；外边界禁止石径接口。
# 传播：坍缩格入栈，逐方向求邻格允许瓦片并做交集，变化则继续入栈。
# 熵：H = ln(Σw) - (Σ w ln w)/Σw；选 H 最小的未坍缩格。
# 回溯：每次坍缩前保存棋盘快照；矛盾时恢复快照并把这次选择从该格候选中剔除。
# 确定性：所有随机数来自按（种子, 重开序号）初始化的 RNG；同输入同输出。

const Tiles = preload("res://scripts/wfc_tileset.gd")

const MAX_RESTARTS := 48
const BACKTRACK_BUDGET := 48
const MAX_STEPS_SAFETY := 100000

var width := 16
var height := 12
var base_seed_text := "20261121"
var base_seed := 20261121
var backtrack_enabled := true

var board := PackedInt32Array()
var finished := false
var failed := false
var attempt := 0

# 累计统计（跨内置重开保留）。
var step_count := 0
var propagation_count := 0
var backtrack_count := 0
var restart_count := 0
var contradiction_count := 0

var last_event := "idle"
var last_target := Vector2i(-1, -1)
var last_tile := -1
var last_wave := PackedInt32Array()
var last_backtrack_cell := Vector2i(-1, -1)
var last_conflict_cell := Vector2i(-1, -1)

var _compat: Array = []
var _snapshots: Array = []
var _jitter := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()
var _pending_cell := -1
var _attempt_backtracks := 0


func setup(seed_text: String, columns: int, rows: int, allow_backtrack: bool) -> void:
	width = clampi(columns, 4, 32)
	height = clampi(rows, 4, 24)
	base_seed_text = seed_text.strip_edges()
	if base_seed_text.is_empty():
		base_seed_text = "20261121"
	base_seed = _seed_from_text(base_seed_text)
	backtrack_enabled = allow_backtrack
	step_count = 0
	propagation_count = 0
	backtrack_count = 0
	restart_count = 0
	contradiction_count = 0
	attempt = 0
	_compat = Tiles.build_compat()
	_reset_attempt()
	last_event = "ready"
	last_target = Vector2i(-1, -1)
	last_tile = -1
	last_wave = PackedInt32Array()
	last_backtrack_cell = Vector2i(-1, -1)
	last_conflict_cell = Vector2i(-1, -1)


func _reset_attempt() -> void:
	var count := width * height
	board.resize(count)
	_jitter.resize(count)
	_rng.seed = _seed_for_attempt()
	_snapshots.clear()
	_pending_cell = -1
	_attempt_backtracks = 0
	finished = false
	failed = false
	for y in height:
		for x in width:
			var index := y * width + x
			board[index] = Tiles.boundary_mask(x, y, width, height)
			_jitter[index] = _rng.randf_range(0.0, 0.0008)


func step() -> Dictionary:
	if finished:
		return _event("done", last_target, last_tile, PackedInt32Array())
	if cell_count() == 0:
		finished = true
		failed = true
		return _event("failed", Vector2i.ZERO, -1, PackedInt32Array())

	var index := _pick_cell()
	if index < 0:
		var complete := _all_collapsed()
		finished = true
		failed = not complete or not validate_constraints()
		last_event = "done" if not failed else "failed"
		return _event(last_event, last_target, last_tile, PackedInt32Array())

	var candidates := board[index]
	var tile := _weighted_choice(candidates)
	_snapshots.append({
		"board": board.duplicate(),
		"cell": index,
		"candidates": candidates,
		"chosen": tile,
	})
	board[index] = Tiles.bit(tile)
	_pending_cell = -1
	step_count += 1

	var target := Vector2i(index % width, index / width)
	var spread := _propagate(index)
	if spread["conflict"]:
		contradiction_count += 1
		var conflict_index := int(spread["cell"])
		last_conflict_cell = Vector2i(conflict_index % width, conflict_index / width)
		last_target = target
		last_tile = tile
		if backtrack_enabled and _attempt_backtracks < BACKTRACK_BUDGET:
			var restored := _restore_alternative()
			if restored["ok"]:
				_attempt_backtracks += 1
				last_event = "backtrack"
				last_wave = PackedInt32Array([int(restored["cell"])])
				return _event("backtrack", target, tile, last_wave)
		if attempt < MAX_RESTARTS:
			attempt += 1
			restart_count += 1
			_reset_attempt()
			last_event = "restart"
			last_target = target
			last_tile = tile
			last_wave = PackedInt32Array()
			return _event("restart", target, tile, last_wave)
		finished = true
		failed = true
		last_event = "failed"
		return _event("failed", target, tile, PackedInt32Array())

	last_event = "collapse"
	last_target = target
	last_tile = tile
	last_wave = spread["changed"]
	if _all_collapsed():
		finished = true
		if not validate_constraints():
			failed = true
			last_event = "failed"
	return _event(last_event, target, tile, last_wave)


func generate_full(max_steps: int = MAX_STEPS_SAFETY) -> bool:
	var guard := 0
	while not finished and guard < max_steps:
		step()
		guard += 1
	if not finished:
		failed = true
		finished = true
	return not failed and validate_constraints()


func _pick_cell() -> int:
	if _pending_cell >= 0 and _pending_cell < board.size() and board[_pending_cell] != 0:
		return _pending_cell
	var best := -1
	var best_entropy := INF
	for index in board.size():
		var mask := board[index]
		if _popcount(mask) <= 1:
			continue
		var score := entropy_of(mask) + _jitter[index]
		if score < best_entropy - 0.000001:
			best_entropy = score
			best = index
	return best


func _weighted_choice(mask: int) -> int:
	var total := 0.0
	var m := mask
	while m != 0:
		var low := m & -m
		total += float(Tiles.WEIGHTS[_bit_index(low)])
		m &= m - 1
	if total <= 0.0:
		return _bit_index(mask & -mask)
	var roll := _rng.randf() * total
	m = mask
	while m != 0:
		var low := m & -m
		var tile := _bit_index(low)
		roll -= float(Tiles.WEIGHTS[tile])
		if roll <= 0.0:
			return tile
		m &= m - 1
	return _bit_index(mask & -mask)


func _propagate(start_index: int) -> Dictionary:
	var stack: Array[int] = [start_index]
	var queued: Dictionary = {start_index: true}
	var changed := PackedInt32Array()

	while not stack.is_empty():
		var index: int = stack.pop_back()
		queued.erase(index)
		var domain := board[index]
		if domain == 0:
			return {"conflict": true, "cell": index, "changed": changed}

		var x := index % width
		var y := index / width
		for direction in Tiles.DIRS:
			var nx := x
			var ny := y
			match direction:
				Tiles.N:
					ny -= 1
				Tiles.E:
					nx += 1
				Tiles.S:
					ny += 1
				Tiles.W:
					nx -= 1
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			var neighbor := ny * width + nx
			var allowed := 0
			var m := domain
			while m != 0:
				var low := m & -m
				allowed |= int(_compat[direction][_bit_index(low)])
				m &= m - 1
			var narrowed := board[neighbor] & allowed
			if narrowed == board[neighbor]:
				continue
			if narrowed == 0:
				return {"conflict": true, "cell": neighbor, "changed": changed}
			board[neighbor] = narrowed
			propagation_count += 1
			changed.append(neighbor)
			if not queued.has(neighbor):
				queued[neighbor] = true
				stack.push_back(neighbor)

	return {"conflict": false, "cell": -1, "changed": changed}


func _restore_alternative() -> Dictionary:
	var restores := 0
	while not _snapshots.is_empty():
		var snapshot: Dictionary = _snapshots.pop_back()
		restores += 1
		var cell := int(snapshot["cell"])
		var remaining := int(snapshot["candidates"]) & ~Tiles.bit(int(snapshot["chosen"]))
		if remaining == 0:
			continue
		board = snapshot["board"].duplicate()
		board[cell] = remaining
		_pending_cell = cell
		backtrack_count += restores
		last_backtrack_cell = Vector2i(cell % width, cell / width)
		last_target = last_backtrack_cell
		return {"ok": true, "cell": cell}
	backtrack_count += restores
	return {"ok": false}


func _all_collapsed() -> bool:
	for mask in board:
		if _popcount(mask) != 1:
			return false
	return true


func validate_constraints() -> bool:
	return validation_errors().is_empty()


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	for y in height:
		for x in width:
			var index := y * width + x
			var mask := board[index]
			if _popcount(mask) != 1:
				errors.append("格 (%d,%d) 仍未坍缩" % [x, y])
				continue
			var tile := _tile_of(mask)
			if x == 0 and Tiles.socket(tile, Tiles.W) == 1:
				errors.append("左边界 (%d,%d) 有石径伸出" % [x, y])
			if x == width - 1 and Tiles.socket(tile, Tiles.E) == 1:
				errors.append("右边界 (%d,%d) 有石径伸出" % [x, y])
			if y == 0 and Tiles.socket(tile, Tiles.N) == 1:
				errors.append("上边界 (%d,%d) 有石径伸出" % [x, y])
			if y == height - 1 and Tiles.socket(tile, Tiles.S) == 1:
				errors.append("下边界 (%d,%d) 有石径伸出" % [x, y])
			for direction in Tiles.DIRS:
				var nx := x
				var ny := y
				match direction:
					Tiles.N:
						ny -= 1
					Tiles.E:
						nx += 1
					Tiles.S:
						ny += 1
					Tiles.W:
						nx -= 1
				if nx < 0 or nx >= width or ny < 0 or ny >= height:
					continue
				var other_mask := board[ny * width + nx]
				if _popcount(other_mask) != 1:
					continue
				var other := _tile_of(other_mask)
				if Tiles.socket(tile, direction) != Tiles.socket(other, Tiles.OPPOSITE[direction]):
					errors.append("接口不符: (%d,%d)%s ↔ (%d,%d)" % [
						x, y, Tiles.NAMES[tile], nx, ny])
			if errors.size() > 40:
				return errors
	return errors


func signature() -> String:
	var chars := PackedStringArray()
	for mask in board:
		if _popcount(mask) == 1:
			chars.append(String.chr(65 + _tile_of(mask)))
		else:
			chars.append("?")
	return "".join(chars)


func get_tiles() -> PackedInt32Array:
	var tiles := PackedInt32Array()
	tiles.resize(board.size())
	for i in board.size():
		tiles[i] = _tile_of(board[i])
	return tiles


func get_mask(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return 0
	return board[y * width + x]


func cell_count() -> int:
	return width * height


func collapsed_cells() -> int:
	var count := 0
	for mask in board:
		if _popcount(mask) == 1:
			count += 1
	return count


func entropy_at(x: int, y: int) -> float:
	return entropy_of(get_mask(x, y))


func entropy_of(mask: int) -> float:
	if mask == 0:
		return INF
	if _popcount(mask) == 1:
		return 0.0
	var total := 0.0
	var weighted_logs := 0.0
	var m := mask
	while m != 0:
		var low := m & -m
		var tile := _bit_index(low)
		var weight := float(Tiles.WEIGHTS[tile])
		total += weight
		weighted_logs += weight * log(weight)
		m &= m - 1
	if total <= 0.0:
		return 0.0
	return log(total) - weighted_logs / total


func max_initial_entropy() -> float:
	return entropy_of(Tiles.all_mask())


func lowest_entropy_cell() -> Dictionary:
	var index := _pick_cell()
	if index < 0:
		return {"cell": Vector2i(-1, -1), "entropy": 0.0, "count": 0}
	return {
		"cell": Vector2i(index % width, index / width),
		"entropy": entropy_of(board[index]),
		"count": _popcount(board[index]),
	}


func candidate_tiles(mask: int) -> Array[int]:
	var out: Array[int] = []
	var m := mask
	while m != 0:
		var low := m & -m
		out.append(_bit_index(low))
		m &= m - 1
	return out


func get_stats() -> Dictionary:
	return {
		"steps": step_count,
		"propagations": propagation_count,
		"backtracks": backtrack_count,
		"restarts": restart_count,
		"contradictions": contradiction_count,
		"connected": collapsed_cells(),
		"total": cell_count(),
		"attempt": attempt,
		"finished": finished,
		"failed": failed,
	}


func _event(kind: String, target: Vector2i, tile: int, wave: PackedInt32Array) -> Dictionary:
	return {
		"event": kind,
		"target": target,
		"tile": tile,
		"wave": wave,
		"finished": finished,
		"failed": failed,
	}


func _seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_valid_int():
		return int(trimmed)
	return abs(trimmed.hash())


func _seed_for_attempt() -> int:
	# splitmix-ish 混合，避免相邻种子产生高度相似的初始抖动。
	var value := base_seed ^ (attempt * 0x45D9F3B)
	value = (value ^ (value >> 16)) * 0x45D9F3B
	value = value ^ (value >> 16)
	return abs(value)


func _tile_of(mask: int) -> int:
	if mask <= 0:
		return -1
	return _bit_index(mask & -mask)


func _bit_index(bit_value: int) -> int:
	var index := 0
	var value := bit_value
	while value > 1:
		value >>= 1
		index += 1
	return index


func _popcount(value: int) -> int:
	var count := 0
	var v := value
	while v != 0:
		v &= v - 1
		count += 1
	return count
