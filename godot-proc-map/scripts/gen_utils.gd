extends RefCounted

# 生成器共用工具：种子混合、确定性哈希、BFS、签名。
# 渲染层与生成层都通过这里的纯函数取随机/哈希，保证换线程、换帧率不影响结果。

const INF := 1 << 30


static func seed_from_text(text: String) -> int:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		trimmed = "0"
	if trimmed.is_valid_int():
		return absi(trimmed.to_int()) & 0x7fffffff
	return absi(trimmed.hash()) & 0x7fffffff


static func mix32(base: int, salt: int) -> int:
	var h := (base & 0xffffffff) ^ ((salt * 0x9e3779b1) & 0xffffffff)
	h = ((h ^ (h >> 16)) * 0x7feb352d) & 0xffffffff
	h = ((h ^ (h >> 15)) * 0x846ca68b) & 0xffffffff
	h = (h ^ (h >> 16)) & 0x7fffffff
	return h


static func hash01(x: int, y: int, salt: int) -> float:
	var h := (x * 374761393 + y * 668265263 + salt * 1274126177) & 0xffffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0xffffffff
	h = (h ^ (h >> 16)) & 0xffffffff
	return float(h & 0xffffff) / 16777215.0


static func fnv_int(h: int, value: int) -> int:
	var v := value & 0xffffffff
	for i in 4:
		h = (h ^ (v & 0xff)) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
		v >>= 8
	return h


static func fnv_bytes(h: int, data: PackedByteArray) -> int:
	for value in data:
		h = (h ^ value) & 0xffffffff
		h = (h * 16777619) & 0xffffffff
	return h


static func signature_start() -> int:
	return 2166136261


static func fmt_sig(h: int) -> String:
	return "%08X" % (h & 0xffffffff)


static func fmt_seed(value: int) -> String:
	return "%08X" % (value & 0xffffffff)


static func bfs_distances(width: int, height: int, walkable: PackedByteArray,
		start: Vector2i, diagonal := false) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	if start.x < 0 or start.y < 0 or start.x >= width or start.y >= height:
		return dist
	if int(walkable[start.y * width + start.x]) == 0:
		return dist
	dist[start.y * width + start.x] = 0
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(width * height)
	var head := 0
	var tail := 0
	queue[tail] = start.y * width + start.x
	tail += 1
	var offsets: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if diagonal:
		offsets.append_array([Vector2i(1, 1), Vector2i(1, -1),
			Vector2i(-1, 1), Vector2i(-1, -1)])
	while head < tail:
		var index := queue[head]
		head += 1
		var x := index % width
		var y := index / width
		var next_dist := dist[index] + 1
		for offset in offsets:
			var nx := x + offset.x
			var ny := y + offset.y
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				continue
			var ni := ny * width + nx
			if int(walkable[ni]) == 0 or dist[ni] >= 0:
				continue
			dist[ni] = next_dist
			queue[tail] = ni
			tail += 1
	return dist


static func bfs_components(width: int, height: int, walkable: PackedByteArray) -> Dictionary:
	var comp := PackedInt32Array()
	comp.resize(width * height)
	comp.fill(-1)
	var sizes: Array[int] = []
	var largest_id := -1
	var largest_size := 0
	var queue: PackedInt32Array = PackedInt32Array()
	queue.resize(width * height)
	for start in width * height:
		if int(walkable[start]) == 0 or comp[start] >= 0:
			continue
		var component_id := sizes.size()
		var head := 0
		var tail := 0
		queue[tail] = start
		tail += 1
		comp[start] = component_id
		while head < tail:
			var index := queue[head]
			head += 1
			var x := index % width
			var y := index / width
			if x > 0:
				var n := index - 1
				if int(walkable[n]) != 0 and comp[n] < 0:
					comp[n] = component_id
					queue[tail] = n
					tail += 1
			if x < width - 1:
				var n := index + 1
				if int(walkable[n]) != 0 and comp[n] < 0:
					comp[n] = component_id
					queue[tail] = n
					tail += 1
			if y > 0:
				var n := index - width
				if int(walkable[n]) != 0 and comp[n] < 0:
					comp[n] = component_id
					queue[tail] = n
					tail += 1
			if y < height - 1:
				var n := index + width
				if int(walkable[n]) != 0 and comp[n] < 0:
					comp[n] = component_id
					queue[tail] = n
					tail += 1
		sizes.append(tail)
		if tail > largest_size:
			largest_size = tail
			largest_id = component_id
	return {"comp": comp, "sizes": sizes, "largest_id": largest_id,
		"largest_size": largest_size}


static func farthest_pair(width: int, height: int, walkable: PackedByteArray,
		start: Vector2i) -> Dictionary:
	var first := bfs_distances(width, height, walkable, start)
	var a := start
	var best := 0
	for i in first.size():
		if first[i] > best:
			best = first[i]
			a = Vector2i(i % width, i / width)
	var second := bfs_distances(width, height, walkable, a)
	var b := a
	best = 0
	for i in second.size():
		if second[i] > best:
			best = second[i]
			b = Vector2i(i % width, i / width)
	return {"a": a, "b": b, "distance": best}


static func quantize(value: float, scale := 100.0) -> int:
	return int(roundf(value * scale))
