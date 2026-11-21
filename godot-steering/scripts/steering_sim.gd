extends Node2D

## 群体寻路与避障 · Steering Behavior 核心模拟
## 参考视频（仅研究引用，无素材复制）：BV1yCqfYuEh1
## 固定 60Hz 步长 → 邻域哈希 → 行为力合成 → 限力积分 → 硬碰撞矫正 → 绘制。
## 视觉语言沿用视频的“深蓝底 + 青色流场箭头 + 青绿障碍 + 粉色单位”。

signal config_changed

const FlowField := preload("res://scripts/flow_field.gd")

const STEP := 1.0 / 60.0
const WORLD := Rect2(0, 0, 1600, 900)
const PLAY := Rect2(38, 38, 1524, 824)

const C_BG := Color(0.063, 0.066, 0.157, 1.0)
const C_GRID := Color(0.24, 0.28, 0.55, 0.10)
const C_BORDER := Color(0.28, 0.42, 0.55, 0.75)
const C_FLOW := Color(0.30, 0.88, 0.82, 0.72)
const C_OBSTACLE := Color(0.075, 0.46, 0.43, 1.0)
const C_OBSTACLE_EDGE := Color(0.19, 0.80, 0.73, 0.95)
const C_OBSTACLE_TOP := Color(0.24, 0.95, 0.84, 0.9)
const C_AGENT := Color(1.0, 0.35, 0.63, 1.0)
const C_AGENT_DARK := Color(0.20, 0.04, 0.12, 1.0)
const C_GOAL := Color(0.24, 0.90, 1.0, 1.0)
const C_PREY := Color(1.0, 0.45, 0.26, 1.0)
const C_PREDATOR := Color(0.55, 0.72, 1.0, 1.0)
const C_LEADER := Color(1.0, 0.85, 0.35, 1.0)

const BEHAVIOR_KEYS := [
	"seek", "flee", "arrive", "pursue", "evade", "wander",
	"separation", "alignment", "cohesion", "leader", "flow", "avoidance",
]
const BEHAVIOR_LABELS := {
	"seek": "靠近 Seek", "flee": "逃离 Flee", "arrive": "抵达 Arrive",
	"pursue": "追逐 Pursue", "evade": "躲避 Evade", "wander": "漫游 Wander",
	"separation": "分离 Separation", "alignment": "对齐 Alignment",
	"cohesion": "聚合 Cohesion", "leader": "队列 Leader",
	"flow": "流场跟随 Flow", "avoidance": "避障 Avoidance",
}
const PRESET_ORDER := ["video", "chase", "corridor", "flock"]
const PRESET_LABELS := {
	"video": "视频绕障", "chase": "追逐", "corridor": "走廊拥堵", "flock": "羊群",
}
const PRESET_HINTS := {
	"video": "流场寻路 + 避障：绕开 C 形障碍并在右侧汇合",
	"chase": "1 个猎物逃跑，其余单位追逐；动态目标",
	"corridor": "窄门两侧拥挤，分离力把队伍挤成两股",
	"flock": "分离 / 对齐 / 聚合 + 漫游；无目标羊群",
}
const PRESET_WEIGHTS := {
	"video": {
		"seek": 0.0, "flee": 0.0, "arrive": 0.0, "pursue": 0.0, "evade": 0.0, "wander": 0.0,
		"separation": 1.35, "alignment": 0.0, "cohesion": 0.0, "leader": 0.0,
		"flow": 1.3, "avoidance": 2.4,
	},
	"chase": {
		"seek": 0.0, "flee": 1.1, "arrive": 0.0, "pursue": 1.5, "evade": 0.9, "wander": 0.7,
		"separation": 0.7, "alignment": 0.0, "cohesion": 0.0, "leader": 0.0,
		"flow": 0.0, "avoidance": 2.6,
	},
	"corridor": {
		"seek": 0.0, "flee": 0.0, "arrive": 0.0, "pursue": 0.0, "evade": 0.0, "wander": 0.0,
		"separation": 1.25, "alignment": 0.18, "cohesion": 0.0, "leader": 0.0,
		"flow": 1.25, "avoidance": 2.5,
	},
	"flock": {
		"seek": 0.0, "flee": 0.0, "arrive": 0.0, "pursue": 0.0, "evade": 0.0, "wander": 0.9,
		"separation": 1.3, "alignment": 1.0, "cohesion": 0.75, "leader": 0.0,
		"flow": 0.0, "avoidance": 1.6,
	},
}
const PREY_ALLOWED := ["flee", "evade", "wander", "separation", "avoidance"]
const PREDATOR_ALLOWED := ["pursue", "separation", "alignment", "avoidance"]
const B_SEEK := 1 << 0
const B_FLEE := 1 << 1
const B_ARRIVE := 1 << 2
const B_PURSUE := 1 << 3
const B_EVADE := 1 << 4
const B_WANDER := 1 << 5
const B_SEPARATION := 1 << 6
const B_ALIGNMENT := 1 << 7
const B_COHESION := 1 << 8
const B_LEADER := 1 << 9
const B_FLOW := 1 << 10
const B_AVOIDANCE := 1 << 11
const B_GROUP := B_SEPARATION | B_ALIGNMENT | B_COHESION
const B_PREY_MASK := B_FLEE | B_EVADE | B_WANDER | B_SEPARATION | B_AVOIDANCE
const B_PRED_MASK := B_PURSUE | B_SEPARATION | B_ALIGNMENT | B_AVOIDANCE

const DOMINANT_COLORS := {
	"flow": Color(0.30, 0.95, 0.88, 0.95),
	"avoidance": Color(1.0, 0.55, 0.28, 0.95),
	"separation": Color(1.0, 0.85, 0.30, 0.95),
	"alignment": Color(0.55, 1.0, 0.55, 0.95),
	"cohesion": Color(0.75, 0.62, 1.0, 0.95),
	"wander": Color(0.88, 0.88, 0.95, 0.85),
	"pursue": Color(1.0, 0.38, 0.48, 0.95),
	"flee": Color(1.0, 0.45, 0.35, 0.95),
	"evade": Color(1.0, 0.62, 0.30, 0.95),
	"seek": Color(0.50, 0.72, 1.0, 0.95),
	"arrive": Color(0.60, 0.80, 1.0, 0.95),
	"leader": Color(1.0, 0.85, 0.35, 0.95),
}

class Agent:
	var id := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var radius := 9.0
	var max_speed := 150.0
	var max_force := 480.0
	var wander_angle := 0.0
	var heading := Vector2.RIGHT
	var role := "boid"
	var forces: Dictionary = {}
	var dominant := "—"
	var neighbors: Array[int] = []
	var rays: Array = []
	var _best_mag := 0.0
	var _best_key := "—"
	var contacts := 0
	var arrived := false
	var last_flow := Vector2.ZERO
	var phase := 0.0
	var force_total := Vector2.ZERO
	var avoid_hot := false
	var cached_avoid := Vector2.ZERO
	var cached_imminent := false
	var cached_sep := Vector2.ZERO

	func force_len() -> float:
		return force_total.length()


var agents: Array[Agent] = []
var obstacles_rects: Array[Rect2] = []
var obstacles_circles: Array = []
var circle_positions := PackedVector2Array()
var circle_radii := PackedFloat32Array()
var draw_shapes: Array = []
var goal := Vector2(1230, 450)
var preset_name := "video"
var weights := {}
var enabled := {}
var params := {
	"max_speed": 150.0,
	"max_force": 480.0,
	"lookahead": 110.0,
	"neighbor_radius": 56.0,
}
var show := {
	"vectors": true,
	"rays": true,
	"neighbors": true,
	"flow": true,
	"highlight": true,
}
var target_count := 120
var paused := false
var selected := -1
var flow := FlowField.new()
var rng := RandomNumberGenerator.new()
var seed_value := 20261121

var sim_time := 0.0
var step_ms := 0.0
var contacts_total := 0
var max_speed_seen := 0.0
var steps_done := 0
var hint := PRESET_HINTS["video"]
var goal_visible := true
var _last_selected_hit := false
var _hash := {}
var _hash_cell := 56.0
var _lookahead := 110.0
var _neighbor_radius := 56.0
var _prey_ref: Agent = null
var _step_us_accum := 0
var _step_us_samples := 0
var _mm_boids: MultiMeshInstance2D
var _mm_prey: MultiMeshInstance2D
var _mm_pred: MultiMeshInstance2D
var _mm_selected: MultiMeshInstance2D
var _ring_groups := {}
var _agent_tex := {}
var _ring_tex: ImageTexture
var _meshes_dirty := true


func _ready() -> void:
	rng.seed = seed_value
	_create_agent_renderer()
	_apply_preset_internal("video")
	_update_agent_multimeshes()
	set_process(true)


func _process(_delta: float) -> void:
	if _meshes_dirty:
		_meshes_dirty = false
		_update_agent_multimeshes()
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if paused:
		return
	# 固定步长：行为积分与渲染帧率解耦，保证同参数可复现。
	_step(STEP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: Vector2 = get_global_mouse_position()
		if event.pressed and event.double_click:
			set_goal(mouse)
		elif event.pressed:
			select_at(mouse)


# ---------------------------------------------------------------- 公共 API

func apply_preset(name: String) -> void:
	if not PRESET_WEIGHTS.has(name):
		return
	_apply_preset_internal(name)


func set_agent_count(n: int) -> void:
	n = clampi(n, 20, 300)
	if n == target_count:
		return
	target_count = n
	reset_sim(false)


func set_paused(value: bool) -> void:
	paused = value


func toggle_pause() -> void:
	paused = not paused


func reset_sim(reset_seed := true) -> void:
	if reset_seed:
		rng.seed = seed_value
	_spawn_agents()
	sim_time = 0.0
	contacts_total = 0
	max_speed_seen = 0.0
	steps_done = 0
	selected = -1 if agents.is_empty() else mini(selected, agents.size() - 1)
	_update_agent_multimeshes()
	config_changed.emit()
	queue_redraw()


func set_goal(pos: Vector2) -> void:
	goal = Vector2(
		clampf(pos.x, PLAY.position.x + 20.0, PLAY.end.x - 20.0),
		clampf(pos.y, PLAY.position.y + 20.0, PLAY.end.y - 20.0))
	_rebuild_flow()
	queue_redraw()


func set_behavior_enabled(key: String, value: bool) -> void:
	if not enabled.has(key):
		return
	enabled[key] = value
	if value and weights.get(key, 0.0) <= 0.0:
		weights[key] = 0.8
	config_changed.emit()


func set_behavior_weight(key: String, value: float) -> void:
	if not weights.has(key):
		return
	weights[key] = maxf(0.0, value)
	if weights[key] > 0.0:
		enabled[key] = true
	config_changed.emit()


func set_param(key: String, value: float) -> void:
	if not params.has(key):
		return
	match key:
		"max_speed":
			params[key] = clampf(value, 60.0, 260.0)
		"max_force":
			params[key] = clampf(value, 120.0, 1000.0)
		"lookahead":
			params[key] = clampf(value, 40.0, 240.0)
		"neighbor_radius":
			params[key] = clampf(value, 24.0, 140.0)
		_:
			params[key] = value
	_apply_params_to_agents()


func set_show(kind: String, value: bool) -> void:
	if show.has(kind):
		show[kind] = value
		_update_agent_multimeshes()
		queue_redraw()


func set_seed(value: int) -> void:
	seed_value = value
	reset_sim(true)


func select_at(pos: Vector2) -> bool:
	var best := -1
	var best_d := 30.0 * 30.0
	for i in agents.size():
		var a: Agent = agents[i]
		var d: float = a.pos.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = i
	selected = best
	_last_selected_hit = best >= 0
	queue_redraw()
	return _last_selected_hit


func select_index(index: int) -> void:
	selected = clampi(index, -1, agents.size() - 1)
	_update_agent_multimeshes()
	queue_redraw()


func get_config() -> Dictionary:
	return {
		"preset": preset_name,
		"preset_label": PRESET_LABELS.get(preset_name, preset_name),
		"hint": hint,
		"count": target_count,
		"paused": paused,
		"weights": weights.duplicate(),
		"enabled": enabled.duplicate(),
		"params": params.duplicate(),
		"show": show.duplicate(),
		"labels": BEHAVIOR_LABELS.duplicate(),
		"presets": PRESET_LABELS.duplicate(),
		"preset_order": PRESET_ORDER.duplicate(),
	}


func get_stats() -> Dictionary:
	var speed_sum := 0.0
	var arrived := 0
	for a: Agent in agents:
		speed_sum += a.vel.length()
		if a.pos.distance_to(goal) < 160.0:
			arrived += 1
	return {
		"fps": Engine.get_frames_per_second(),
		"count": agents.size(),
		"sim_ms": step_ms,
		"avg_speed": speed_sum / maxf(1.0, agents.size()),
		"arrived": arrived,
		"contacts": contacts_total,
		"seed": seed_value,
		"goal_visible": goal_visible,
	}


func get_selected_info() -> Dictionary:
	if selected < 0 or selected >= agents.size():
		return {"valid": false}
	var a: Agent = agents[selected]
	return {
		"valid": true,
		"id": a.id,
		"role": a.role,
		"dominant": a.dominant,
		"speed": a.vel.length(),
		"neighbors": a.neighbors.size(),
		"force": a.force_len(),
	}


func get_state_checksum() -> int:
	var h := 17
	for a: Agent in agents:
		h = hash([h, int(round(a.pos.x * 100.0)), int(round(a.pos.y * 100.0)),
			int(round(a.vel.x * 100.0)), int(round(a.vel.y * 100.0))])
	return h


func is_point_blocked(point: Vector2, clearance := 0.0) -> bool:
	for r: Rect2 in obstacles_rects:
		var nearest := Vector2(
			clampf(point.x, r.position.x, r.end.x),
			clampf(point.y, r.position.y, r.end.y))
		if point.distance_to(nearest) < clearance:
			return true
	for i in circle_positions.size():
		if point.distance_to(circle_positions[i]) < circle_radii[i] + clearance:
			return true
	return not PLAY.grow(-clearance).has_point(point)


func step_frames(n: int) -> void:
	for _i in n:
		_step(STEP)
	_update_agent_multimeshes()


# ---------------------------------------------------------------- 预设与生成

func _apply_preset_internal(name: String) -> void:
	preset_name = name
	hint = PRESET_HINTS.get(name, "")
	goal_visible = name != "flock"
	var preset_weights: Dictionary = PRESET_WEIGHTS[name]
	weights.clear()
	enabled.clear()
	for key in BEHAVIOR_KEYS:
		weights[key] = float(preset_weights.get(key, 0.0))
		enabled[key] = weights[key] > 0.0
	_build_scene(name)
	rng.seed = seed_value
	_spawn_agents()
	sim_time = 0.0
	contacts_total = 0
	selected = 0 if not agents.is_empty() else -1
	_update_agent_multimeshes()
	config_changed.emit()
	queue_redraw()


func _build_scene(name: String) -> void:
	obstacles_rects.clear()
	obstacles_circles.clear()
	draw_shapes.clear()
	match name:
		"video":
			# 视频同款 C 形障碍（开口朝右），两个圆形石柱。
			var c_shape := [
				Rect2(540, 280, 280, 56),
				Rect2(540, 280, 56, 340),
				Rect2(540, 564, 280, 56),
			]
			for r: Rect2 in c_shape:
				obstacles_rects.append(r)
			draw_shapes.append({
				"type": "poly",
				"points": PackedVector2Array([
					Vector2(540, 280), Vector2(820, 280), Vector2(820, 336),
					Vector2(596, 336), Vector2(596, 564), Vector2(820, 564),
					Vector2(820, 620), Vector2(540, 620),
				]),
			})
			obstacles_circles.append({"position": Vector2(1005, 250), "radius": 34.0})
			obstacles_circles.append({"position": Vector2(1005, 650), "radius": 34.0})
			draw_shapes.append({"type": "circle", "position": Vector2(1005, 250), "radius": 34.0})
			draw_shapes.append({"type": "circle", "position": Vector2(1005, 650), "radius": 34.0})
			goal = Vector2(1230, 450)
		"chase":
			# 石柱 + 方块，猎物在右侧，追捕者从左侧出发。
			var pillars := [
				{"position": Vector2(480, 220), "radius": 52.0},
				{"position": Vector2(1010, 250), "radius": 62.0},
				{"position": Vector2(560, 680), "radius": 46.0},
				{"position": Vector2(1080, 650), "radius": 68.0},
			]
			for p in pillars:
				obstacles_circles.append(p)
				draw_shapes.append({"type": "circle", "position": p["position"], "radius": p["radius"]})
			var block := Rect2(790, 400, 130, 96)
			obstacles_rects.append(block)
			draw_shapes.append({
				"type": "poly",
				"points": PackedVector2Array([
					block.position, Vector2(block.end.x, block.position.y),
					block.end, Vector2(block.position.x, block.end.y),
				]),
			})
			goal = Vector2(1240, 450)
		"corridor":
			# 中间竖墙 + 窄门；两侧留出排队拥堵空间。
			var top := Rect2(760, 38, 52, 326)
			var bottom := Rect2(760, 520, 52, 342)
			obstacles_rects.append(top)
			obstacles_rects.append(bottom)
			draw_shapes.append({
				"type": "poly",
				"points": PackedVector2Array([
					top.position, Vector2(top.end.x, top.position.y), top.end, Vector2(top.position.x, top.end.y),
				]),
			})
			draw_shapes.append({
				"type": "poly",
				"points": PackedVector2Array([
					bottom.position, Vector2(bottom.end.x, bottom.position.y), bottom.end, Vector2(bottom.position.x, bottom.end.y),
				]),
			})
			draw_shapes.append({"type": "gate", "position": Vector2(786, 450), "size": Vector2(52, 156)})
			goal = Vector2(1350, 450)
		"flock":
			var stones := [
				{"position": Vector2(430, 250), "radius": 58.0},
				{"position": Vector2(1080, 280), "radius": 66.0},
				{"position": Vector2(760, 650), "radius": 52.0},
			]
			for p in stones:
				obstacles_circles.append(p)
				draw_shapes.append({"type": "circle", "position": p["position"], "radius": p["radius"]})
			goal = Vector2(800, 450)
	_sync_hot_obstacles()
	_rebuild_flow()


func _sync_hot_obstacles() -> void:
	circle_positions.clear()
	circle_radii.clear()
	for c in obstacles_circles:
		circle_positions.append(c["position"])
		circle_radii.append(c["radius"])


func _rebuild_flow() -> void:
	flow.build(obstacles_rects, obstacles_circles, PLAY, goal, 22.0)


func _spawn_agents() -> void:
	agents.clear()
	_prey_ref = null
	var spawn_region := PLAY.grow(-26.0)
	match preset_name:
		"corridor":
			spawn_region = Rect2(80, 100, 620, 700)
		"chase":
			spawn_region = Rect2(90, 120, 860, 660)
	# 候选点：确定性网格 + 抖动，避开障碍与目标点。
	var candidates: Array[Vector2] = []
	var spacing := 38.0
	var y := spawn_region.position.y + 14.0
	while y < spawn_region.end.y - 10.0:
		var x := spawn_region.position.x + 14.0
		while x < spawn_region.end.x - 10.0:
			var p := Vector2(x + rng.randf_range(-7.0, 7.0), y + rng.randf_range(-7.0, 7.0))
			var ok := not is_point_blocked(p, 24.0)
			if ok and preset_name != "chase" and p.distance_to(goal) < 80.0:
				ok = false
			if ok:
				candidates.append(p)
			x += spacing
		y += spacing
	_shuffle(candidates)
	# 候选不足时用拒绝采样补齐。
	var guard := 0
	while candidates.size() < target_count and guard < 2000:
		guard += 1
		var p := spawn_region.position + Vector2(
			rng.randf() * spawn_region.size.x, rng.randf() * spawn_region.size.y)
		if not is_point_blocked(p, 22.0):
			candidates.append(p)

	var prey_pos := Vector2(1240, 450)
	for i in target_count:
		var a := Agent.new()
		a.id = i
		if preset_name == "chase" and i == 0:
			a.role = "prey"
			a.pos = prey_pos + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-8.0, 8.0))
			a.max_speed = params["max_speed"] * 1.12
			a.radius = 11.0
		elif preset_name == "chase":
			a.role = "predator"
			a.pos = candidates[i % maxi(1, candidates.size())]
			a.max_speed = params["max_speed"] * rng.randf_range(0.94, 1.05)
			a.radius = rng.randf_range(8.5, 10.0)
		else:
			a.role = "boid"
			a.pos = candidates[i % maxi(1, candidates.size())]
			a.max_speed = params["max_speed"] * rng.randf_range(0.92, 1.08)
			a.radius = rng.randf_range(8.5, 10.0)
		a.max_force = params["max_force"] * rng.randf_range(0.92, 1.08)
		a.wander_angle = rng.randf() * TAU
		a.phase = rng.randf() * TAU
		var fdir := flow.sample(a.pos)
		if fdir == Vector2.ZERO or preset_name == "chase":
			fdir = Vector2.RIGHT.rotated(rng.randf() * TAU)
		a.vel = fdir * a.max_speed * 0.25
		a.heading = fdir.normalized()
		agents.append(a)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func _apply_params_to_agents() -> void:
	for a: Agent in agents:
		var speed_scale: float = 1.12 if a.role == "prey" else 1.0
		a.max_speed = params["max_speed"] * speed_scale
		a.max_force = params["max_force"]
	_neighbor_radius = params["neighbor_radius"]
	_lookahead = params["lookahead"]
	_hash_cell = _neighbor_radius


# ---------------------------------------------------------------- 模拟步进

var nan_events := 0


func _step(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	if agents.is_empty():
		return
	sim_time += dt
	steps_done += 1
	_neighbor_radius = params["neighbor_radius"]
	_lookahead = params["lookahead"]
	_hash_cell = maxf(24.0, _neighbor_radius)
	# 邻域每 3 步刷新一次：56px 半径内 2 帧位移 < 8px，视觉无差；
	# 这是 200 体密集汇合时的主要性能来源。
	var refresh_neighbors := steps_done % 8 == 1
	if refresh_neighbors:
		_rebuild_hash()
	_prey_ref = _find_prey()
	var base_mask := _build_active_mask()
	var prey_mask := base_mask & B_PREY_MASK
	var pred_mask := base_mask & B_PRED_MASK
	var chase := preset_name == "chase"

	for a: Agent in agents:
		var mask := base_mask
		if chase:
			if a.role == "prey":
				mask = prey_mask
			elif a.role == "predator":
				mask = pred_mask
		var need_neighbors := (mask & B_GROUP) != 0
		if not need_neighbors and a.role != "prey" and (mask & (B_FLEE | B_EVADE)) != 0:
			need_neighbors = true
		if not need_neighbors and (mask & B_PURSUE) != 0 and _prey_ref == null:
			need_neighbors = true
		if need_neighbors and refresh_neighbors:
			a.neighbors.clear()
			_fill_neighbors(a)
		if not a.forces.is_empty():
			a.forces.clear()
		a.last_flow = Vector2.ZERO
		a._best_mag = 0.0
		a._best_key = "—"
		var total := Vector2.ZERO

		if mask & B_FLOW:
			total += _contribute(a, "flow", _flow_force(a))
		if mask & B_SEEK:
			total += _contribute(a, "seek", _seek_force(a, goal))
		if mask & B_ARRIVE:
			total += _contribute(a, "arrive", _arrive_force(a, goal))
		if mask & B_FLEE:
			var threat = _threat_for(a)
			if threat != null:
				total += _contribute(a, "flee", _flee_force(a, threat.pos, 300.0))
		if mask & B_EVADE:
			var threat2 = _threat_for(a)
			if threat2 != null:
				total += _contribute(a, "evade", _evade_force(a, threat2))
		if mask & B_PURSUE:
			var prey = _pursue_target(a)
			if prey != null:
				total += _contribute(a, "pursue", _pursue_force(a, prey))
		if mask & B_WANDER:
			total += _contribute(a, "wander", _wander_force(a))
		if mask & B_SEPARATION:
			if (steps_done & 1) == 0 or a.cached_sep == Vector2.ZERO:
				a.cached_sep = _separation_force(a)
			total += _contribute(a, "separation", a.cached_sep)
		if mask & B_ALIGNMENT:
			total += _contribute(a, "alignment", _alignment_force(a))
		if mask & B_COHESION:
			total += _contribute(a, "cohesion", _cohesion_force(a))
		if mask & B_LEADER and a.id > 0:
			var prev: Agent = agents[a.id - 1]
			var follow := prev.pos - prev.heading * 46.0
			total += _contribute(a, "leader", _arrive_force(a, follow))
		if mask & B_AVOIDANCE:
			if (steps_done & 1) == 0 or a.avoid_hot:
				_avoidance_force(a)
				a.cached_avoid = _avoid_sum
				a.cached_imminent = _avoid_imminent
			else:
				_avoid_sum = a.cached_avoid
				_avoid_imminent = a.cached_imminent
			var avoid_force := _avoid_sum
			var avoid_weight: float = weights.get("avoidance", 1.0)
			var contribution := avoid_force * avoid_weight
			if _avoid_imminent and avoid_force.length_squared() > 0.0001:
				# 优先级：即将碰撞时，避障额外压过其它行为。
				contribution += avoid_force.normalized() * a.max_force * 0.7
			total += contribution
			var avoid_mag := contribution.length()
			if avoid_mag > a._best_mag:
				a._best_mag = avoid_mag
				a._best_key = "avoidance"
			if a.id == selected:
				a.forces["avoidance"] = contribution

		var boundary := _boundary_force(a)
		if boundary.length_squared() > 0.0001:
			total += boundary
			if a.id == selected:
				a.forces["boundary"] = boundary

		a.dominant = a._best_key

		a.force_total = total.limit_length(a.max_force)
		a.vel += a.force_total * dt
		var vel_sq := a.vel.length_squared()
		if vel_sq > a.max_speed * a.max_speed:
			a.vel = a.vel * (a.max_speed / sqrt(vel_sq))
			vel_sq = a.max_speed * a.max_speed
		a.pos += a.vel * dt
		if not a.pos.is_finite() or not a.vel.is_finite():
			a.pos = PLAY.get_center()
			a.vel = Vector2.ZERO
			nan_events += 1
		if vel_sq > 0.25:
			a.heading = a.vel / sqrt(vel_sq)
		if a.pos.distance_squared_to(goal) < 25600.0:
			a.arrived = true
		if vel_sq > max_speed_seen * max_speed_seen:
			max_speed_seen = sqrt(vel_sq)

	for a: Agent in agents:
		_resolve_collisions(a)
	_meshes_dirty = true

	var elapsed := Time.get_ticks_usec() - t0
	_step_us_accum += elapsed
	_step_us_samples += 1
	if _step_us_samples >= 30:
		step_ms = float(_step_us_accum) / float(_step_us_samples) / 1000.0
		_step_us_accum = 0
		_step_us_samples = 0


func _build_active_mask() -> int:
	var mask := 0
	for i in BEHAVIOR_KEYS.size():
		var key: String = BEHAVIOR_KEYS[i]
		if enabled.get(key, false) and float(weights.get(key, 0.0)) > 0.0:
			mask |= 1 << i
	return mask


func _contribute(a: Agent, key: String, raw: Vector2) -> Vector2:
	var contribution := raw * float(weights.get(key, 0.0))
	var mag := contribution.length()
	if mag > a._best_mag:
		a._best_mag = mag
		a._best_key = key
	if a.id == selected:
		a.forces[key] = contribution
	return contribution


func _fill_neighbors(a: Agent) -> void:
	var radius := _neighbor_radius
	var r2 := radius * radius
	var cx := int(floor(a.pos.x / _hash_cell))
	var cy := int(floor(a.pos.y / _hash_cell))
	var scanned := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			var bucket = _hash.get(Vector2i(cx + ox, cy + oy))
			if bucket == null:
				continue
			for j: int in bucket:
				if j == a.id:
					continue
				scanned += 1
				if scanned > 24:
					return
				var b: Agent = agents[j]
				if a.pos.distance_squared_to(b.pos) <= r2:
					a.neighbors.append(j)
					if a.neighbors.size() >= 10:
						return


# ---------------------------------------------------------------- 个体行为

func _seek_force(a: Agent, target: Vector2) -> Vector2:
	var dir := a.pos.direction_to(target)
	if dir == Vector2.ZERO:
		return -a.vel
	return dir * a.max_speed - a.vel


func _arrive_force(a: Agent, target: Vector2) -> Vector2:
	var dist := a.pos.distance_to(target)
	if dist < 4.0:
		return -a.vel * 1.5
	var speed := a.max_speed * clampf(dist / 120.0, 0.0, 1.0)
	return a.pos.direction_to(target) * speed - a.vel


func _flee_force(a: Agent, point: Vector2, radius: float) -> Vector2:
	var offset := a.pos - point
	var dist := offset.length()
	if dist < 0.001:
		return a.heading.rotated(PI * 0.5) * a.max_speed - a.vel
	if dist > radius:
		return Vector2.ZERO
	var desired := offset / dist * a.max_speed
	return (desired - a.vel) * (1.0 - 0.45 * dist / radius)


func _evade_force(a: Agent, threat: Agent) -> Vector2:
	var dist := a.pos.distance_to(threat.pos)
	var look := clampf(dist / maxf(a.max_speed, 30.0), 0.0, 1.0)
	return _flee_force(a, threat.pos + threat.vel * look, 330.0)


func _pursue_force(a: Agent, target: Agent) -> Vector2:
	var dist := a.pos.distance_to(target.pos)
	if dist < 38.0:
		return _arrive_force(a, target.pos)
	var look := clampf(dist / maxf(a.max_speed, 30.0), 0.0, 1.2)
	return _seek_force(a, target.pos + target.vel * look)


func _wander_force(a: Agent) -> Vector2:
	a.wander_angle += rng.randf_range(-1.0, 1.0) * 2.6 * STEP
	var forward := a.heading
	if a.vel.length() > 5.0:
		forward = a.vel.normalized()
	var target := a.pos + forward * 70.0 + Vector2.from_angle(a.wander_angle) * 42.0
	return _seek_force(a, target)


func _threat_for(a: Agent) -> Agent:
	if a.role == "prey":
		return _nearest_predator(a)
	if a.role == "predator":
		return null
	return _nearest_neighbor(a)


func _pursue_target(a: Agent) -> Agent:
	var prey := _find_prey()
	if prey != null:
		return prey
	return _nearest_neighbor(a)


func _find_prey() -> Agent:
	if _prey_ref != null and is_instance_valid(_prey_ref):
		return _prey_ref
	for a: Agent in agents:
		if a.role == "prey":
			return a
	return null


func _nearest_predator(a: Agent) -> Agent:
	var best: Agent = null
	var best_d := INF
	for b: Agent in agents:
		if b.role != "predator":
			continue
		var d: float = a.pos.distance_squared_to(b.pos)
		if d < best_d:
			best_d = d
			best = b
	return best


func _nearest_neighbor(a: Agent) -> Agent:
	var best: Agent = null
	var best_d := INF
	for j: int in a.neighbors:
		var b: Agent = agents[j]
		var d: float = a.pos.distance_squared_to(b.pos)
		if d < best_d:
			best_d = d
			best = b
	if best == null and agents.size() > 1:
		for b: Agent in agents:
			if b == a:
				continue
			var d: float = a.pos.distance_squared_to(b.pos)
			if d < best_d:
				best_d = d
				best = b
	return best


# ---------------------------------------------------------------- 群体行为

func _separation_force(a: Agent) -> Vector2:
	var count: int = mini(a.neighbors.size(), 6)
	if count == 0:
		return Vector2.ZERO
	# 只用最近 10 个邻居，按 1/距离² 加权（比逐邻居开方快一个量级）。
	var px := 0.0
	var py := 0.0
	var ax := a.pos.x
	var ay := a.pos.y
	var limit_sq := _neighbor_radius * _neighbor_radius
	for k in count:
		var b: Agent = agents[a.neighbors[k]]
		var dx := ax - b.pos.x
		var dy := ay - b.pos.y
		var d2 := dx * dx + dy * dy
		if d2 > limit_sq:
			continue
		if d2 < 0.01:
			d2 = 0.01
		var inv := 1.0 / d2
		px += dx * inv
		py += dy * inv
	if px == 0.0 and py == 0.0:
		return Vector2.ZERO
	var inv_len := a.max_speed / sqrt(px * px + py * py)
	return Vector2(px * inv_len - a.vel.x, py * inv_len - a.vel.y)


func _alignment_force(a: Agent) -> Vector2:
	var count: int = mini(a.neighbors.size(), 8)
	if count == 0:
		return Vector2.ZERO
	var vx := 0.0
	var vy := 0.0
	for k in count:
		var b: Agent = agents[a.neighbors[k]]
		vx += b.vel.x
		vy += b.vel.y
	if vx * vx + vy * vy < 64.0:
		return Vector2.ZERO
	var inv_len := a.max_speed / sqrt(vx * vx + vy * vy)
	return Vector2(vx * inv_len - a.vel.x, vy * inv_len - a.vel.y)


func _cohesion_force(a: Agent) -> Vector2:
	var count: int = mini(a.neighbors.size(), 8)
	if count == 0:
		return Vector2.ZERO
	var cx := 0.0
	var cy := 0.0
	for k in count:
		var b: Agent = agents[a.neighbors[k]]
		cx += b.pos.x
		cy += b.pos.y
	var inv := 1.0 / float(count)
	return _seek_force(a, Vector2(cx * inv, cy * inv))


func _flow_force(a: Agent) -> Vector2:
	var dir := flow.sample(a.pos)
	a.last_flow = dir
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	var dist := a.pos.distance_to(goal)
	if dist < 26.0:
		return -a.vel * 1.5
	var speed := a.max_speed * clampf(dist / 120.0, 0.12, 1.0)
	return dir * speed - a.vel


func _boundary_force(a: Agent) -> Vector2:
	var margin := 90.0
	var push := Vector2.ZERO
	if a.pos.x < PLAY.position.x + margin:
		push.x += 1.0 - (a.pos.x - PLAY.position.x) / margin
	if a.pos.x > PLAY.end.x - margin:
		push.x -= 1.0 - (PLAY.end.x - a.pos.x) / margin
	if a.pos.y < PLAY.position.y + margin:
		push.y += 1.0 - (a.pos.y - PLAY.position.y) / margin
	if a.pos.y > PLAY.end.y - margin:
		push.y -= 1.0 - (PLAY.end.y - a.pos.y) / margin
	if push.length_squared() < 0.0001:
		return Vector2.ZERO
	return push.normalized() * a.max_speed - a.vel


# ---------------------------------------------------------------- 局部避障

const WHISKER_COS := 0.8525245
const WHISKER_SIN := 0.5226872

var _hit_t := 2.0
var _hit_point := Vector2.ZERO
var _hit_normal := Vector2.ZERO
var _avoid_sum := Vector2.ZERO
var _avoid_imminent := false
var _nr_idx := PackedInt32Array()
var _nc_idx := PackedInt32Array()


func _avoidance_force(a: Agent) -> void:
	var speed := a.vel.length()
	var look := clampf(30.0 + speed * 0.7, 56.0, _lookahead)
	var bx := a.heading.x
	var by := a.heading.y
	if speed > 5.0:
		bx = a.vel.x / speed
		by = a.vel.y / speed
	var ax := a.pos.x
	var ay := a.pos.y
	var sum_x := 0.0
	var sum_y := 0.0
	var imminent := false
	var strongest := 0.0
	var record: bool = a.id == selected
	if record:
		a.rays.clear()
	var hit_any := false

	# 宽相位：只保留胡须长度内可能命中的障碍，避免每根射线遍历全场。
	_nr_idx.clear()
	_nc_idx.clear()
	var look_sq := look * look
	for i in obstacles_rects.size():
		var r: Rect2 = obstacles_rects[i]
		var ddx := 0.0
		if ax < r.position.x:
			ddx = r.position.x - ax
		elif ax > r.end.x:
			ddx = ax - r.end.x
		var ddy := 0.0
		if ay < r.position.y:
			ddy = r.position.y - ay
		elif ay > r.end.y:
			ddy = ay - r.end.y
		if ddx * ddx + ddy * ddy <= look_sq:
			_nr_idx.append(i)
	for i in circle_positions.size():
		var ddx := ax - circle_positions[i].x
		var ddy := ay - circle_positions[i].y
		var reach := look + circle_radii[i]
		if ddx * ddx + ddy * ddy <= reach * reach:
			_nc_idx.append(i)

	for k in 3:
		var dx := bx
		var dy := by
		if k == 0:
			dx = bx * WHISKER_COS + by * WHISKER_SIN
			dy = -bx * WHISKER_SIN + by * WHISKER_COS
		elif k == 2:
			dx = bx * WHISKER_COS - by * WHISKER_SIN
			dy = bx * WHISKER_SIN + by * WHISKER_COS
		var tx := ax + dx * look
		var ty := ay + dy * look
		var hit := _raycast(ax, ay, tx, ty)
		if record:
			a.rays.append({"from": Vector2(ax, ay), "to": Vector2(tx, ty), "hit": hit,
				"point": _hit_point, "normal": _hit_normal})
		if not hit:
			continue
		hit_any = true
		var t := _hit_t
		var nx := _hit_normal.x
		var ny := _hit_normal.y
		var proximity := 1.0 - clampf(t, 0.0, 1.0)
		var weight := 0.55
		if k == 1:
			weight = 0.95
		# 动力：沿障碍切向滑行；斥力：沿障碍法线离开。
		var tang_x := -ny
		var tang_y := nx
		if tang_x * dx + tang_y * dy < 0.0:
			tang_x = -tang_x
			tang_y = -tang_y
		var repel := 1.2 + 2.0 * proximity
		var drive := 0.55 + 0.8 * proximity
		var scale := weight * (0.4 + proximity)
		sum_x += (nx * repel + tang_x * drive) * scale
		sum_y += (ny * repel + tang_y * drive) * scale
		strongest = maxf(strongest, scale)
		if t < 0.45:
			imminent = true

	var near := _near_obstacle_repulsion(a)
	if near.length_squared() > 0.0001:
		sum_x += near.x * 1.1
		sum_y += near.y * 1.1
		strongest = maxf(strongest, 0.85)
		hit_any = true
	if strongest > 0.8:
		imminent = true
	_avoid_sum = Vector2(sum_x, sum_y)
	_avoid_imminent = imminent
	a.avoid_hot = hit_any


func _near_obstacle_repulsion(a: Agent) -> Vector2:
	var out_x := 0.0
	var out_y := 0.0
	var margin := a.radius + 26.0
	var ax := a.pos.x
	var ay := a.pos.y
	for ri in _nr_idx:
		var r: Rect2 = obstacles_rects[ri]
		var nx := clampf(ax, r.position.x, r.end.x)
		var ny := clampf(ay, r.position.y, r.end.y)
		var ox := ax - nx
		var oy := ay - ny
		var d2 := ox * ox + oy * oy
		if d2 >= margin * margin:
			continue
		if d2 > 0.000001:
			var d := sqrt(d2)
			var s := (1.0 - d / margin) / d
			out_x += ox * s
			out_y += oy * s
		else:
			var cx := ax - r.get_center().x
			var cy := ay - r.get_center().y
			if absf(cx) > absf(cy):
				out_x += signf(cx) * 1.5
			else:
				out_y += signf(cy) * 1.5
	for ci in _nc_idx:
		var ox := ax - circle_positions[ci].x
		var oy := ay - circle_positions[ci].y
		var d2 := ox * ox + oy * oy
		var reach := circle_radii[ci] + margin
		if d2 >= reach * reach:
			continue
		if d2 > 0.000001:
			var d := sqrt(d2)
			var s := (1.0 - d / reach) / d
			out_x += ox * s
			out_y += oy * s
		else:
			out_x += 1.5
	return Vector2(out_x, out_y)


## 三根胡须共用的最近交点查询：结果写入 _hit_t/_hit_point/_hit_normal。
func _raycast(fx: float, fy: float, tx: float, ty: float) -> bool:
	_hit_t = 2.0
	var dx := tx - fx
	var dy := ty - fy
	for ri in _nr_idx:
		_ray_rect_try(fx, fy, dx, dy, obstacles_rects[ri])
	for ci in _nc_idx:
		_ray_circle_try(fx, fy, dx, dy, circle_positions[ci].x, circle_positions[ci].y, circle_radii[ci])
	return _hit_t <= 1.0


func _ray_rect_try(fx: float, fy: float, dx: float, dy: float, rect: Rect2) -> void:
	var tmin := 0.0
	var tmax := 1.0
	var nx := 0.0
	var ny := 0.0
	if absf(dx) < 0.000001:
		if fx < rect.position.x or fx > rect.end.x:
			return
	else:
		var tx1 := (rect.position.x - fx) / dx
		var tx2 := (rect.end.x - fx) / dx
		var sign_x := -1.0
		if tx1 > tx2:
			var tmp := tx1
			tx1 = tx2
			tx2 = tmp
			sign_x = 1.0
		if tx1 > tmin:
			tmin = tx1
			nx = sign_x
		tmax = minf(tmax, tx2)
		if tmin > tmax:
			return
	if absf(dy) < 0.000001:
		if fy < rect.position.y or fy > rect.end.y:
			return
	else:
		var ty1 := (rect.position.y - fy) / dy
		var ty2 := (rect.end.y - fy) / dy
		var sign_y := -1.0
		if ty1 > ty2:
			var tmp2 := ty1
			ty1 = ty2
			ty2 = tmp2
			sign_y = 1.0
		if ty1 > tmin:
			tmin = ty1
			nx = 0.0
			ny = sign_y
		tmax = minf(tmax, ty2)
		if tmin > tmax:
			return
	if tmin < 0.0 or tmin > 1.0 or tmin >= _hit_t:
		return
	if nx == 0.0 and ny == 0.0:
		# 起点在矩形内：沿最近的面朝外。
		var ox := fx - rect.get_center().x
		var oy := fy - rect.get_center().y
		if absf(ox) > absf(oy):
			nx = signf(ox)
		else:
			ny = signf(oy)
		if nx == 0.0 and ny == 0.0:
			nx = 1.0
	_hit_t = tmin
	_hit_point = Vector2(fx + dx * tmin, fy + dy * tmin)
	_hit_normal = Vector2(nx, ny).normalized()


func _ray_circle_try(fx: float, fy: float, dx: float, dy: float,
		cx: float, cy: float, radius: float) -> void:
	var ox := fx - cx
	var oy := fy - cy
	var a := dx * dx + dy * dy
	if a < 0.000001:
		return
	var b := 2.0 * (ox * dx + oy * dy)
	var c := ox * ox + oy * oy - radius * radius
	var disc := b * b - 4.0 * a * c
	if disc < 0.0:
		return
	var t := (-b - sqrt(disc)) / (2.0 * a)
	if t < 0.0:
		t = 0.0
	if t > 1.0 or t >= _hit_t:
		return
	var px := fx + dx * t
	var py := fy + dy * t
	var nx := px - cx
	var ny := py - cy
	var nl := sqrt(nx * nx + ny * ny)
	if nl < 0.000001:
		nx = -dx
		ny = -dy
		nl = sqrt(nx * nx + ny * ny)
		if nl < 0.000001:
			return
	_hit_t = t
	_hit_point = Vector2(px, py)
	_hit_normal = Vector2(nx / nl, ny / nl)


# ---------------------------------------------------------------- 空间哈希与碰撞

func _rebuild_hash() -> void:
	_hash.clear()
	for i in agents.size():
		var a: Agent = agents[i]
		var key := Vector2i(int(floor(a.pos.x / _hash_cell)), int(floor(a.pos.y / _hash_cell)))
		var bucket: Array = _hash.get(key, [])
		if bucket.is_empty():
			_hash[key] = bucket
		bucket.append(i)


func _resolve_collisions(a: Agent) -> void:
	var ax := a.pos.x
	var ay := a.pos.y
	var near := false
	var sep := a.radius + 4.0
	var sep_sq := sep * sep
	for r: Rect2 in obstacles_rects:
		if r.grow(sep).has_point(a.pos):
			near = true
			break
	if not near:
		for i in circle_positions.size():
			var dx := ax - circle_positions[i].x
			var dy := ay - circle_positions[i].y
			var reach := circle_radii[i] + sep
			if dx * dx + dy * dy < reach * reach:
				near = true
				break
	if near:
		for _pass in 2:
			var moved := false
			for r: Rect2 in obstacles_rects:
				var nearest := Vector2(
					clampf(a.pos.x, r.position.x, r.end.x),
					clampf(a.pos.y, r.position.y, r.end.y))
				var offset := a.pos - nearest
				var dist := offset.length()
				if dist >= a.radius:
					continue
				var before := a.pos
				var normal := Vector2.ZERO
				if dist > 0.001:
					normal = offset / dist
					a.pos = nearest + normal * a.radius
				else:
					# 已进入矩形内部：沿最近的面推出去。
					var left := a.pos.x - r.position.x
					var right := r.end.x - a.pos.x
					var top := a.pos.y - r.position.y
					var bottom := r.end.y - a.pos.y
					var m := minf(minf(left, right), minf(top, bottom))
					if m == left:
						a.pos.x = r.position.x - a.radius
						normal = Vector2.LEFT
					elif m == right:
						a.pos.x = r.end.x + a.radius
						normal = Vector2.RIGHT
					elif m == top:
						a.pos.y = r.position.y - a.radius
						normal = Vector2.UP
					else:
						a.pos.y = r.end.y + a.radius
						normal = Vector2.DOWN
				_strip_inward(a, normal)
				if a.pos.distance_squared_to(before) > 0.0025:
					moved = true
					a.contacts += 1
					contacts_total += 1
			for i in circle_positions.size():
				var offset: Vector2 = a.pos - circle_positions[i]
				var dist: float = offset.length()
				var reach: float = circle_radii[i] + a.radius
				if dist >= reach:
					continue
				var before: Vector2 = a.pos
				var normal: Vector2 = offset / dist if dist > 0.001 else Vector2.RIGHT
				a.pos = circle_positions[i] + normal * reach
				_strip_inward(a, normal)
				if a.pos.distance_squared_to(before) > 0.0025:
					moved = true
					a.contacts += 1
					contacts_total += 1
			if not moved:
				break
	# 场地边界：硬夹取（避免越界）。
	var min_x := PLAY.position.x + a.radius
	var max_x := PLAY.end.x - a.radius
	var min_y := PLAY.position.y + a.radius
	var max_y := PLAY.end.y - a.radius
	if a.pos.x < min_x:
		a.pos.x = min_x
		_strip_inward(a, Vector2.RIGHT)
	elif a.pos.x > max_x:
		a.pos.x = max_x
		_strip_inward(a, Vector2.LEFT)
	if a.pos.y < min_y:
		a.pos.y = min_y
		_strip_inward(a, Vector2.DOWN)
	elif a.pos.y > max_y:
		a.pos.y = max_y
		_strip_inward(a, Vector2.UP)


func _strip_inward(a: Agent, normal: Vector2) -> void:
	var vn := a.vel.dot(normal)
	if vn < 0.0:
		a.vel -= normal * vn


# ---------------------------------------------------------------- 绘制

func _draw() -> void:
	_draw_background()
	if show.get("flow", false):
		_draw_flow_field()
	_draw_obstacles()
	_draw_goal()
	_draw_debug_overlays()
	_draw_selected_vectors()


func _draw_background() -> void:
	draw_rect(WORLD, C_BG, true)
	for i in 4:
		draw_circle(goal, 150.0 - i * 28.0, Color(0.16, 0.72, 0.9, 0.012))
	var lines := PackedVector2Array()
	var x := PLAY.position.x
	while x <= PLAY.end.x:
		lines.append(Vector2(x, PLAY.position.y))
		lines.append(Vector2(x, PLAY.end.y))
		x += 44.0
	var y := PLAY.position.y
	while y <= PLAY.end.y:
		lines.append(Vector2(PLAY.position.x, y))
		lines.append(Vector2(PLAY.end.x, y))
		y += 44.0
	draw_multiline(lines, C_GRID, 1.0)
	draw_rect(PLAY, C_BORDER, false, 2.0)
	# 四角标记
	var corner := 22.0
	for p in [PLAY.position, Vector2(PLAY.end.x, PLAY.position.y), PLAY.end, Vector2(PLAY.position.x, PLAY.end.y)]:
		draw_circle(p, 3.0, Color(0.35, 0.8, 0.9, 0.5))
	draw_line(PLAY.position + Vector2(corner, 0), PLAY.position + Vector2(corner * 2.0, 0), C_OBSTACLE_EDGE, 2.0)


func _draw_flow_field() -> void:
	if not flow.built:
		return
	var pts := PackedVector2Array()
	var step_cells := 4
	var cy := 1
	while cy < flow.rows:
		var cx := 1
		while cx < flow.cols:
			var cell := Vector2i(cx, cy)
			if flow.is_open(cell):
				var d := flow.direction[flow.cell_index(cell)]
				if d != Vector2.ZERO:
					var p := flow.cell_center(cell)
					var half := 8.0
					pts.append(p - d * half)
					pts.append(p + d * half)
					var tip := p + d * half
					pts.append(tip)
					pts.append(tip - d.rotated(0.55) * 5.6)
					pts.append(tip)
					pts.append(tip - d.rotated(-0.55) * 5.6)
			cx += step_cells
		cy += step_cells
	draw_multiline(pts, C_FLOW, 2.2)


func _draw_obstacles() -> void:
	for shape in draw_shapes:
		var kind: String = shape.get("type", "")
		if kind == "poly":
			var points: PackedVector2Array = shape["points"]
			var shadow := PackedVector2Array()
			for p in points:
				shadow.append(p + Vector2(8.0, 10.0))
			draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.28))
			draw_colored_polygon(points, C_OBSTACLE)
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, C_OBSTACLE_EDGE, 2.0, true)
			draw_line(points[0], points[1], C_OBSTACLE_TOP, 2.5, true)
		elif kind == "circle":
			var pos: Vector2 = shape["position"]
			var radius: float = shape["radius"]
			draw_circle(pos + Vector2(7.0, 9.0), radius, Color(0.0, 0.0, 0.0, 0.26))
			draw_circle(pos, radius, C_OBSTACLE)
			draw_arc(pos, radius, 0.0, TAU, 56, C_OBSTACLE_EDGE, 2.0, true)
			draw_arc(pos, radius * 0.82, -2.5, -0.55, 22, C_OBSTACLE_TOP, 2.0, true)
		elif kind == "gate":
			var pos: Vector2 = shape["position"]
			var size: Vector2 = shape["size"]
			var top := pos - size * 0.5
			draw_line(top, top + Vector2(0, size.y), Color(0.25, 0.95, 0.85, 0.25), 3.0, true)
			for k in 3:
				var yy := top.y + size.y * (0.25 + 0.25 * k)
				draw_line(Vector2(top.x - 10.0, yy), Vector2(top.x + 2.0, yy), Color(0.25, 0.95, 0.85, 0.28), 2.0, true)


func _draw_goal() -> void:
	if not goal_visible:
		return
	var pulse := 0.5 + 0.5 * sin(sim_time * 2.4)
	draw_circle(goal, 27.0 + pulse * 7.0, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.055))
	draw_circle(goal, 18.0, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.10))
	draw_arc(goal, 160.0, 0.0, TAU, 72, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.055), 1.2, true)
	draw_arc(goal, 20.0, 0.0, TAU, 48, C_GOAL, 2.2, true)
	draw_arc(goal, 31.0 + pulse * 5.0, 0.0, TAU, 48, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.30), 1.2, true)
	draw_circle(goal, 6.5, C_GOAL)
	for i in 4:
		var ang := sim_time * 0.7 + i * PI * 0.5
		var dir := Vector2.from_angle(ang)
		draw_line(goal + dir * 25.0, goal + dir * 33.0, Color(C_GOAL.r, C_GOAL.g, C_GOAL.b, 0.7), 2.0, true)
	var prey := _find_prey()
	if prey != null:
		draw_arc(prey.pos, prey.radius + 9.0 + pulse * 2.0, 0.0, TAU, 40,
			Color(1.0, 0.45, 0.26, 0.85), 2.0, true)


func _draw_debug_overlays() -> void:
	var sel := _selected_agent()
	if sel == null:
		return
	if show.get("neighbors", false):
		var links := 0
		for j: int in sel.neighbors:
			draw_line(sel.pos, (agents[j] as Agent).pos, Color(0.45, 0.9, 1.0, 0.20), 1.0, true)
			links += 1
			if links >= 8:
				break
		draw_arc(sel.pos, params["neighbor_radius"], 0.0, TAU, 64, Color(0.45, 0.9, 1.0, 0.13), 1.0, true)
	if show.get("rays", false):
		for rec in sel.rays:
			var hit: bool = rec.get("hit", false)
			var color := Color(0.62, 0.88, 1.0, 0.38)
			if hit:
				color = Color(1.0, 0.34, 0.38, 0.92)
			draw_line(rec["from"], rec["to"], color, 1.8, true)
			if hit:
				var point: Vector2 = rec["point"]
				var normal: Vector2 = rec["normal"]
				draw_circle(point, 3.2, color)
				draw_line(point, point + normal * 17.0, Color(1.0, 0.85, 0.5, 0.85), 1.8, true)


func _create_agent_renderer() -> void:
	_agent_tex["boid"] = _make_body_texture(C_AGENT)
	_agent_tex["prey"] = _make_body_texture(C_PREY)
	_agent_tex["predator"] = _make_body_texture(C_PREDATOR)
	_ring_tex = _make_ring_texture()
	_mm_boids = _make_agent_mmi(_agent_tex["boid"], 1)
	_mm_prey = _make_agent_mmi(_agent_tex["prey"], 1)
	_mm_pred = _make_agent_mmi(_agent_tex["predator"], 1)
	for key in DOMINANT_COLORS:
		var ring: MultiMeshInstance2D = _make_agent_mmi(_ring_tex, 2)
		var col: Color = DOMINANT_COLORS[key]
		ring.modulate = Color(col.r, col.g, col.b, 0.62)
		_ring_groups[key] = ring
	_mm_selected = _make_agent_mmi(_ring_tex, 3)
	_mm_selected.modulate = Color(0.96, 1.0, 1.0, 0.95)


func _make_agent_mmi(texture: Texture2D, z: int) -> MultiMeshInstance2D:
	var quad := QuadMesh.new()
	quad.size = Vector2(64, 64)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.mesh = quad
	mm.instance_count = 300
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.texture = texture
	mmi.z_index = z
	add_child(mmi)
	return mmi


func _make_body_texture(body: Color) -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dark := Color(0.16, 0.03, 0.09, 1.0)
	for y in 64:
		for x in 64:
			var dx := x - 31.5
			var dy := y - 31.5
			var d := sqrt(dx * dx + dy * dy)
			var col := Color(0, 0, 0, 0)
			if d <= 30.6:
				col = dark
			if d <= 28.6:
				col = body
			if d <= 29.4 and d > 28.0:
				col = Color(dark.r, dark.g, dark.b, clampf(30.6 - d, 0.0, 1.0))
			if d <= 27.6:
				var glyph := minf(
					_seg_dist(x, y, 31.0, 32.0, 47.0, 32.0),
					minf(_seg_dist(x, y, 47.0, 32.0, 40.0, 26.0),
						_seg_dist(x, y, 47.0, 32.0, 40.0, 38.0)))
				if glyph < 2.9:
					col = dark
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


func _make_ring_texture() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var dx := x - 31.5
			var dy := y - 31.5
			var d := sqrt(dx * dx + dy * dy)
			var alpha := 0.0
			if d >= 26.5 and d <= 30.5:
				alpha = clampf(2.2 - absf(d - 28.5), 0.0, 1.0)
			if alpha > 0.0:
				img.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(img)


func _seg_dist(px: float, py: float, x1: float, y1: float, x2: float, y2: float) -> float:
	var vx := x2 - x1
	var vy := y2 - y1
	var wx := px - x1
	var wy := py - y1
	var len2 := vx * vx + vy * vy
	var t := 0.0
	if len2 > 0.000001:
		t = clampf((wx * vx + wy * vy) / len2, 0.0, 1.0)
	var cx := x1 + vx * t
	var cy := y1 + vy * t
	return sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy))


func _update_agent_multimeshes() -> void:
	if _mm_boids == null:
		return
	var counts := {"boid": 0, "prey": 0, "predator": 0}
	var ring_counts := {}
	for key in _ring_groups:
		ring_counts[key] = 0
	var selected_count := 0
	for a: Agent in agents:
		var mmi: MultiMeshInstance2D = _mm_boids
		if a.role == "prey":
			mmi = _mm_prey
		elif a.role == "predator":
			mmi = _mm_pred
		var idx: int = counts[a.role]
		if idx < 300:
			var sc := a.radius / 27.0
			var ang := a.heading.angle()
			var c := cos(ang)
			var sn := sin(ang)
			mmi.multimesh.set_instance_transform_2d(idx,
				Transform2D(Vector2(c * sc, sn * sc), Vector2(-sn * sc, c * sc), a.pos))
			counts[a.role] = idx + 1
		if show.get("highlight", false) and _ring_groups.has(a.dominant):
			var ring: MultiMeshInstance2D = _ring_groups[a.dominant]
			var ri: int = ring_counts[a.dominant]
			if ri < 300:
				var rs: float = (a.radius + 2.2) / 28.5
				ring.multimesh.set_instance_transform_2d(ri,
					Transform2D(Vector2(rs, 0), Vector2(0, rs), a.pos))
				ring_counts[a.dominant] = ri + 1
		if a.id == selected:
			var ss: float = (a.radius + 3.4) / 28.5
			_mm_selected.multimesh.set_instance_transform_2d(0,
				Transform2D(Vector2(ss, 0), Vector2(0, ss), a.pos))
			selected_count = 1
	_mm_boids.multimesh.visible_instance_count = counts["boid"]
	_mm_prey.multimesh.visible_instance_count = counts["prey"]
	_mm_pred.multimesh.visible_instance_count = counts["predator"]
	for key in _ring_groups:
		(_ring_groups[key] as MultiMeshInstance2D).multimesh.visible_instance_count = ring_counts[key]
	_mm_selected.multimesh.visible_instance_count = selected_count


func _draw_selected_vectors() -> void:
	if not show.get("vectors", false):
		return
	var sel := _selected_agent()
	if sel == null:
		return
	_draw_arrow(sel.pos, sel.pos + sel.vel * 0.5, Color(0.90, 0.95, 1.0, 0.92), 2.0)
	_draw_arrow(sel.pos, sel.pos + sel.force_total * 0.22, Color(1.0, 0.35, 0.66, 0.95), 2.6)
	var avoid: Vector2 = sel.forces.get("avoidance", Vector2.ZERO)
	if avoid.length_squared() > 0.0001:
		_draw_arrow(sel.pos, sel.pos + avoid * 0.15, Color(1.0, 0.58, 0.26, 0.92), 2.0)
	var flowf: Vector2 = sel.forces.get("flow", Vector2.ZERO)
	if flowf.length_squared() > 0.0001:
		_draw_arrow(sel.pos, sel.pos + flowf * 0.18, Color(0.32, 0.95, 0.90, 0.9), 1.8)


func _draw_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var delta := to - from
	var length := delta.length()
	if length < 1.0:
		return
	var dir := delta / length
	var head := minf(12.0, length * 0.42)
	draw_line(from, to, color, width, true)
	draw_line(to, to - dir.rotated(0.52) * head, color, width, true)
	draw_line(to, to - dir.rotated(-0.52) * head, color, width, true)


func _selected_agent() -> Agent:
	if selected < 0 or selected >= agents.size():
		return null
	return agents[selected]
