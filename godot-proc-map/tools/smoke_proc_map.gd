extends SceneTree

# 无头验收（PROC_MAP_SMOKE_OK 在最后一行）：
#   A. 地牢：40 seeds + 5 个压力尺寸；房间不重叠/不出界，BFS 100% 连通，
#      AStarGrid2D 起终点可达，同 seed 签名与网格逐步一致，生成耗时中位数 ≤50ms。
#   B. 群岛：100 seeds；最大陆块 ≥90%，河流 ≥1 且至少 1 条入海，POI 3–8，
#      同 seed 逐格一致，海平面参数有效，生成耗时中位数 ≤100ms。
#   C. 主场景：分阶段/单步/完成、算法切换、调试开关、签名记录。
# 用法：godot --headless --path . -s tools/smoke_proc_map.gd

const Dungeon = preload("res://scripts/gen_dungeon.gd")
const Biome = preload("res://scripts/gen_biome.gd")
const Utils = preload("res://scripts/gen_utils.gd")

var _fails: Array[String] = []
var _dungeon_ms: Array[float] = []
var _stress_ms: Array[float] = []
var _biome_ms: Array[float] = []
var _largest_min := 1000.0
var _rivers_min := 999
var _poi_min := 99
var _poi_max := 0
var _rooms_total := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_dungeon()
	_test_dungeon_determinism()
	_test_biome()
	_test_biome_determinism()
	_test_biome_parameter()
	await _test_main_scene()
	print("DUNGEON seeds=%d rooms_avg=%.1f median_ms=%.2f p95_ms=%.2f stress_median_ms=%.2f" % [
		40, float(_rooms_total) / 40.0, _median(_dungeon_ms), _p95(_dungeon_ms),
		_median(_stress_ms)])
	print("BIOME seeds=100 largest_min=%.1f%% rivers_min=%d poi_range=%d..%d median_ms=%.2f p95_ms=%.2f" % [
		_largest_min, _rivers_min, _poi_min, _poi_max, _median(_biome_ms), _p95(_biome_ms)])
	if _fails.is_empty():
		print("PROC_MAP_SMOKE_OK")
		quit(0)
	else:
		for failure in _fails:
			printerr("PROC_MAP_SMOKE_FAIL: ", failure)
		quit(1)


# ---------------------------------------------------------------------------
# A. 地牢
# ---------------------------------------------------------------------------

func _test_dungeon() -> void:
	var seeds := _seed_list(40)
	var time_samples: Array[float] = []
	for index in seeds.size():
		var seed_text := seeds[index]
		var gen = Dungeon.new()
		gen.setup(seed_text, 64, 48, 0.12)
		var ok: bool = gen.generate_all()
		if not ok:
			_fails.append("dungeon seed %s generate failed" % seed_text)
			continue
		var stats: Dictionary = gen.get_stats()
		time_samples.append(float(stats["total_ms"]))
		var label := "dungeon seed %s" % seed_text
		if int(stats["rooms"]) < 5:
			_fails.append(label + ": too few rooms")
		if float(stats["reachable_pct"]) < 99.999:
			_fails.append(label + ": reachable floors %.2f%%" % float(stats["reachable_pct"]))
		if int(stats["component_count"]) != 1:
			_fails.append(label + ": floor components %d" % int(stats["component_count"]))
		if int(stats["reachable_rooms"]) != int(stats["rooms"]):
			_fails.append(label + ": unreachable rooms")
		if not gen.floor_cell(gen.start) or not gen.floor_cell(gen.exit):
			_fails.append(label + ": start/exit not floor")
		# 房间不重叠、不出界、中心是地板。
		for i in gen.rooms.size():
			var rect: Rect2i = gen.rooms[i]["rect"]
			if rect.position.x < 1 or rect.position.y < 1 or rect.end.x > gen.width - 1 \
					or rect.end.y > gen.height - 1:
				_fails.append(label + ": room out of bounds")
			var center: Vector2i = gen.rooms[i]["center"]
			if not gen.floor_cell(center):
				_fails.append(label + ": room center not floor")
			for j in range(i + 1, gen.rooms.size()):
				var other: Rect2i = gen.rooms[j]["rect"]
				if rect.intersects(other):
					_fails.append(label + ": rooms overlap")
		# 独立 BFS 复核。
		var dist := Utils.bfs_distances(gen.width, gen.height, gen.grid, gen.start)
		var floor_count := 0
		var reachable := 0
		for i in gen.grid.size():
			if int(gen.grid[i]) != 0:
				floor_count += 1
				if dist[i] >= 0:
					reachable += 1
		if reachable != floor_count:
			_fails.append(label + ": independent BFS %d/%d" % [reachable, floor_count])
		if dist[gen.exit.y * gen.width + gen.exit.x] <= 0:
			_fails.append(label + ": exit not reachable by BFS")
		_rooms_total += int(stats["rooms"])
		if index < 10:
			var astar := _astar_check(gen)
			if not astar:
				_fails.append(label + ": AStarGrid2D no path")
	_dungeon_ms = time_samples
	# 压力尺寸：80×60，只验证连通与耗时（不作为 50ms 档）。
	for seed_text in ["7", "42", "2718", "8888", "garden"]:
		var gen = Dungeon.new()
		gen.setup(seed_text, 80, 60, 0.2)
		var ok: bool = gen.generate_all()
		if not ok or int(gen.get_stats()["reachable_rooms"]) != gen.rooms.size():
			_fails.append("dungeon stress %s failed" % seed_text)
		_stress_ms.append(float(gen.get_stats()["total_ms"]))
	# 不同 seed 应产生不同签名。
	var sigs := {}
	for seed_text in seeds.slice(0, 20):
		var gen = Dungeon.new()
		gen.setup(seed_text, 64, 48, 0.12)
		gen.generate_all()
		sigs[gen.get_signature()] = true
	if sigs.size() < 18:
		_fails.append("dungeon signature diversity too low: %d/20" % sigs.size())
	if _median(_dungeon_ms) > 50.0:
		_fails.append("dungeon median generation %.2fms > 50ms" % _median(_dungeon_ms))


func _astar_check(gen) -> bool:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, gen.width, gen.height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in gen.height:
		for x in gen.width:
			if not gen.floor_cell(Vector2i(x, y)):
				astar.set_point_solid(Vector2i(x, y), true)
	astar.update()
	var path := astar.get_id_path(gen.start, gen.exit)
	return path.size() > 0


func _test_dungeon_determinism() -> void:
	for seed_text in ["2137", "42", "8888"]:
		var a = Dungeon.new()
		a.setup(seed_text, 64, 48, 0.12)
		a.generate_all()
		var b = Dungeon.new()
		b.setup(seed_text, 64, 48, 0.12)
		for stage in b.get_stage_count():
			b.run_stage(stage)
		if a.get_signature() != b.get_signature():
			_fails.append("dungeon %s: staged signature mismatch" % seed_text)
		if a.grid != b.grid:
			_fails.append("dungeon %s: staged grid mismatch" % seed_text)
		if a.start != b.start or a.exit != b.exit:
			_fails.append("dungeon %s: start/exit mismatch" % seed_text)
		# 参数必须影响结果。
		var c = Dungeon.new()
		c.setup(seed_text, 64, 48, 0.3)
		c.generate_all()
		if c.get_signature() == a.get_signature():
			_fails.append("dungeon %s: loop parameter did not change signature" % seed_text)


# ---------------------------------------------------------------------------
# B. 群岛
# ---------------------------------------------------------------------------

func _test_biome() -> void:
	var seeds := _seed_list(100)
	var times: Array[float] = []
	for seed_text in seeds:
		var gen = Biome.new()
		gen.setup(seed_text, 96, 64, 0.0)
		var ok: bool = gen.generate_all()
		if not ok:
			_fails.append("biome seed %s failed: largest=%.1f rivers=%d poi=%d" % [
				seed_text, gen.largest_land_pct, gen.rivers_to_sea, gen.pois.size()])
			continue
		var stats: Dictionary = gen.get_stats()
		times.append(float(stats["total_ms"]))
		_largest_min = minf(_largest_min, float(stats["largest_land_pct"]))
		_rivers_min = mini(_rivers_min, int(stats["rivers_to_sea"]))
		_poi_min = mini(_poi_min, int(stats["pois"]))
		_poi_max = maxi(_poi_max, int(stats["pois"]))
		var label := "biome seed %s" % seed_text
		if float(stats["land_pct"]) < 0.15 or float(stats["land_pct"]) > 0.72:
			_fails.append(label + ": land fraction %.2f" % float(stats["land_pct"]))
		if float(stats["largest_land_pct"]) < 90.0:
			_fails.append(label + ": largest land %.1f%%" % float(stats["largest_land_pct"]))
		if int(stats["rivers_to_sea"]) < 1:
			_fails.append(label + ": no river to sea")
		if int(stats["rivers"]) < 1:
			_fails.append(label + ": no river")
		if int(stats["pois"]) < 3 or int(stats["pois"]) > 8:
			_fails.append(label + ": POI count %d" % int(stats["pois"]))
		if int(stats["trees"]) < 50:
			_fails.append(label + ": too few trees")
		# POI/河流/区域细节。
		var poi_cells := {}
		var river_land_cells := 0
		var river_touches_sea := false
		for poi in gen.pois:
			var cell: Vector2i = poi["cell"]
			if not gen.land_cell(cell):
				_fails.append(label + ": POI on water")
			if int(gen.river[cell.y * gen.width + cell.x]) != 0:
				_fails.append(label + ": POI on river")
			if poi_cells.has(cell):
				_fails.append(label + ": duplicate POI cell")
			poi_cells[cell] = true
			if int(gen.region[cell.y * gen.width + cell.x]) < 0:
				_fails.append(label + ": POI has no region")
		for i in gen.river.size():
			if int(gen.river[i]) == 0:
				continue
			if int(gen.biome[i]) < 3:
				_fails.append(label + ": river painted on water")
				break
			river_land_cells += 1
			var x: int = i % gen.width
			var y: int = i / gen.width
			if (x > 0 and int(gen.biome[i - 1]) < 3) \
					or (x < gen.width - 1 and int(gen.biome[i + 1]) < 3) \
					or (y > 0 and int(gen.biome[i - gen.width]) < 3) \
					or (y < gen.height - 1 and int(gen.biome[i + gen.width]) < 3):
				river_touches_sea = true
		if river_land_cells <= 0:
			_fails.append(label + ": no river cells")
		if not river_touches_sea:
			_fails.append(label + ": river does not reach sea (independent)")
	_biome_ms = times
	if _median(_biome_ms) > 100.0:
		_fails.append("biome median generation %.2fms > 100ms" % _median(_biome_ms))
	if _p95(_biome_ms) > 250.0:
		_fails.append("biome p95 generation %.2fms > 250ms (load spike?)" % _p95(_biome_ms))


func _test_biome_determinism() -> void:
	for seed_text in ["9001", "42", "77", "12345", "hello"]:
		var a = Biome.new()
		a.setup(seed_text, 96, 64, 0.0)
		a.generate_all()
		var b = Biome.new()
		b.setup(seed_text, 96, 64, 0.0)
		for stage in b.get_stage_count():
			b.run_stage(stage)
		if a.get_signature() != b.get_signature():
			_fails.append("biome %s: staged signature mismatch" % seed_text)
		if a.biome != b.biome or a.river != b.river or a.region != b.region:
			_fails.append("biome %s: staged arrays mismatch" % seed_text)
		for i in a.pois.size():
			if a.pois[i]["cell"] != b.pois[i]["cell"] or a.pois[i]["name"] != b.pois[i]["name"]:
				_fails.append("biome %s: POI mismatch" % seed_text)
				break


func _test_biome_parameter() -> void:
	var high = Biome.new()
	high.setup("9001", 96, 64, 0.06)
	high.generate_all()
	var low = Biome.new()
	low.setup("9001", 96, 64, -0.06)
	low.generate_all()
	if high.land_pct >= low.land_pct:
		_fails.append("biome: sea level did not reduce land (high=%.2f low=%.2f)" % [
			high.land_pct, low.land_pct])
	if high.get_signature() == low.get_signature():
		_fails.append("biome: sea level did not change signature")


# ---------------------------------------------------------------------------
# C. 主场景契约
# ---------------------------------------------------------------------------

func _test_main_scene() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	if scene.api_get_gen() == null:
		_fails.append("main: generator not created on start")
		scene.queue_free()
		return
	var gen = scene.api_get_gen()
	if int(gen.get_stage_count()) != 6:
		_fails.append("main: expected 6 biome stages")
	# 分阶段推进。
	scene.api_set_paused(true)
	var before: int = int(gen.stage_index)
	scene.api_step()
	if int(gen.stage_index) != before + 1 and not gen.finished:
		_fails.append("main: step did not advance stage")
	scene.api_finish()
	if scene.api_get_signature().length() != 8:
		_fails.append("main: missing signature after finish")
	# 调试开关契约。
	scene.api_set_debug({"connectivity": true, "rooms": true, "biomes": true, "noise": true, "bounds": true})
	var flags: Dictionary = scene.api_debug_state()
	if not (bool(flags["connectivity"]) and bool(flags["noise"])):
		_fails.append("main: debug flags not applied")
	scene.api_set_debug({})
	flags = scene.api_debug_state()
	for key in flags:
		if bool(flags[key]):
			_fails.append("main: debug flag %s did not clear" % key)
	# 切换到地牢。
	scene.api_new("dungeon", "2137", 0, 12.0, true)
	scene.api_finish()
	if int(scene.api_get_gen().get_stage_count()) != 5:
		_fails.append("main: expected 5 dungeon stages")
	if scene.api_get_signature().length() != 8:
		_fails.append("main: missing dungeon signature")
	# 同种子重开：签名一致。
	var first_sig: String = scene.api_get_signature()
	scene.api_new("dungeon", "2137", 0, 12.0, true)
	scene.api_finish()
	if scene.api_get_signature() != first_sig:
		_fails.append("main: same-seed dungeon signature mismatch")
	scene.queue_free()
	await process_frame
	print("UI_CONTRACT_OK")


# ---------------------------------------------------------------------------
# 工具
# ---------------------------------------------------------------------------

func _seed_list(count: int) -> Array[String]:
	var seeds: Array[String] = []
	for i in count:
		seeds.append(str(i + 1))
	seeds.append_array(["2137", "2718", "9001", "12345", "garden", "biome", "rift"])
	return seeds.slice(0, count)


func _median(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) * 0.5


func _p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size()) * 0.95)) - 1, 0, sorted.size() - 1)
	return sorted[index]
