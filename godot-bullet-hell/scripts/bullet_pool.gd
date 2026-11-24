class_name BulletPool
extends RefCounted

# 定长结构数组 + 紧凑布局的弹幕池。
# - 每颗子弹只存位置/速度/半径/寿命/行为参数；没有 per-bullet 对象。
# - 出屏或寿命结束后用“写指针压实”移除，顺序稳定、无分配。
# - 追踪/正弦/定时分裂由 behavior + 4 个参数表达。

signal grazed(pos: Vector2)
signal split_burst(pos: Vector2, color: Color, count: int)

enum Behavior { STRAIGHT, SINE, HOMING, SPLIT }
enum Kind { ORB, SHARD, BLOOM, CORE }

const FLAG_GRAZED := 1
const FLAG_CHILD := 2
const FLAG_HIT := 4
const DEFAULT_CAPACITY := 4096

var capacity := DEFAULT_CAPACITY
var count := 0
var seed_value := 0xB17B17
var high_water := 0

var pos := PackedVector2Array()
var vel := PackedVector2Array()
var radius := PackedFloat32Array()
var age := PackedFloat32Array()
var life := PackedFloat32Array()
var behavior := PackedInt32Array()
var kind := PackedInt32Array()
var p0 := PackedFloat32Array()
var p1 := PackedFloat32Array()
var p2 := PackedFloat32Array()
var p3 := PackedFloat32Array()
var color := PackedColorArray()
var flags := PackedInt32Array()

var rng := RandomNumberGenerator.new()

func _init(cap := DEFAULT_CAPACITY, p_seed := 0xB17B17) -> void:
	capacity = cap
	seed_value = p_seed
	pos.resize(cap)
	vel.resize(cap)
	radius.resize(cap)
	age.resize(cap)
	life.resize(cap)
	behavior.resize(cap)
	kind.resize(cap)
	p0.resize(cap)
	p1.resize(cap)
	p2.resize(cap)
	p3.resize(cap)
	color.resize(cap)
	flags.resize(cap)
	rng.seed = seed_value

func reset() -> void:
	count = 0
	high_water = 0
	rng.seed = seed_value

func clear() -> void:
	count = 0

func spawn(p_pos: Vector2, p_vel: Vector2, p_radius := 6.0, p_color := Color.WHITE, p_kind := Kind.ORB, p_behavior := Behavior.STRAIGHT, p_life := 8.0, a0 := 0.0, a1 := 0.0, a2 := 0.0, a3 := 0.0, p_flags := 0) -> bool:
	if count >= capacity:
		return false
	var i := count
	pos[i] = p_pos
	vel[i] = p_vel
	radius[i] = p_radius
	age[i] = 0.0
	life[i] = p_life
	behavior[i] = p_behavior
	kind[i] = p_kind
	p0[i] = a0
	p1[i] = a1
	p2[i] = a2
	p3[i] = a3
	color[i] = p_color
	flags[i] = p_flags
	count += 1
	if count > high_water:
		high_water = count
	return true

func render_velocity(i: int) -> Vector2:
	var base := vel[i]
	if behavior[i] == Behavior.SINE:
		var perp := Vector2(-base.y, base.x).normalized()
		return base + perp * cos(age[i] * p1[i] + p3[i]) * p0[i]
	return base

func _move(src: int, dst: int) -> void:
	pos[dst] = pos[src]
	vel[dst] = vel[src]
	radius[dst] = radius[src]
	age[dst] = age[src]
	life[dst] = life[src]
	behavior[dst] = behavior[src]
	kind[dst] = kind[src]
	p0[dst] = p0[src]
	p1[dst] = p1[src]
	p2[dst] = p2[src]
	p3[dst] = p3[src]
	color[dst] = color[src]
	flags[dst] = flags[src]

# 固定步长可复现：所有行为只依赖 dt、当前玩家位置和池内 seed。
# bounds 是逻辑舞台（0,0,1280,720）；出界外扩 90 像素后回收。
func step(dt: float, player_pos: Vector2, player_hit_radius: float, player_graze_radius: float, bounds: Rect2) -> Dictionary:
	var hits := 0
	var grazes := 0
	var hit_pos := Vector2.ZERO
	var split_requests: Array[Dictionary] = []
	var n := count
	for i in n:
		if life[i] <= 0.0:
			continue
		age[i] += dt
		var px := pos[i].x
		var py := pos[i].y
		var vx: float
		var vy: float
		var b := behavior[i]
		if b == Behavior.SINE:
			var base := vel[i]
			var bl := base.length()
			var perp := Vector2(-base.y, base.x).normalized()
			var lateral := cos(age[i] * p1[i] + p3[i]) * p0[i]
			vx = base.x + perp.x * lateral
			vy = base.y + perp.y * lateral
			if bl <= 0.001:
				vx = base.x
				vy = base.y
		elif b == Behavior.HOMING:
			var v := vel[i]
			if age[i] <= p2[i]:
				var desired := (player_pos - Vector2(px, py))
				if desired.length_squared() > 1.0:
					var current := v.angle()
					var target := desired.angle()
					var diff := wrapf(target - current, -PI, PI)
					var max_turn := p0[i] * dt
					current += clampf(diff, -max_turn, max_turn)
					v = Vector2.from_angle(current) * p1[i]
					vel[i] = v
			vx = v.x
			vy = v.y
		else:
			vx = vel[i].x
			vy = vel[i].y

		px += vx * dt
		py += vy * dt
		pos[i] = Vector2(px, py)

		if age[i] >= life[i]:
			life[i] = 0.0
			continue
		if px < bounds.position.x - 90.0 or px > bounds.end.x + 90.0 or py < bounds.position.y - 90.0 or py > bounds.end.y + 90.0:
			life[i] = 0.0
			continue

		var dx := px - player_pos.x
		var dy := py - player_pos.y
		var d2 := dx * dx + dy * dy
		var hit_r := radius[i] + player_hit_radius
		if player_hit_radius > 0.0 and (flags[i] & FLAG_HIT) == 0 and d2 <= hit_r * hit_r:
			flags[i] |= FLAG_HIT
			hits += 1
			if hits == 1:
				hit_pos = Vector2(px, py)
		elif player_graze_radius > 0.0 and (flags[i] & FLAG_GRAZED) == 0:
			var graze_r := radius[i] + player_graze_radius
			if d2 <= graze_r * graze_r:
				flags[i] |= FLAG_GRAZED
				grazes += 1
				emit_signal("grazed", Vector2(px, py))

		if b == Behavior.SPLIT and (flags[i] & FLAG_CHILD) == 0 and age[i] >= p0[i]:
			split_requests.append({
				"pos": Vector2(px, py),
				"color": color[i],
				"count": maxi(1, int(p1[i])),
				"speed": p2[i],
				"radius": p3[i] if p3[i] > 0.0 else 5.5,
			})
			life[i] = 0.0

	var w := 0
	for r in n:
		if life[r] > 0.0:
			if w != r:
				_move(r, w)
			w += 1
	var removed := n - w
	count = w

	for req in split_requests:
		var c: Color = req["color"]
		var cnt: int = req["count"]
		var spd: float = req["speed"]
		var base_angle: float = rng.randf() * TAU
		var r: float = req["radius"]
		for k in cnt:
			var a := base_angle + TAU * float(k) / float(cnt)
			spawn(req["pos"], Vector2.from_angle(a) * spd, r, c, Kind.BLOOM, Behavior.STRAIGHT, 6.0, 0.0, 0.0, 0.0, 0.0, FLAG_CHILD)
		emit_signal("split_burst", req["pos"], c, cnt)

	return {
		"hits": hits,
		"grazes": grazes,
		"hit_pos": hit_pos,
		"removed": removed,
		"active": count,
	}

func clear_radius(center: Vector2, radius: float) -> int:
	# 玩家被弹/阶段切换时的局部净化；返回清理数量。
	var removed := 0
	for i in count:
		if pos[i].distance_squared_to(center) <= radius * radius:
			life[i] = 0.0
			removed += 1
	var w := 0
	for r in count:
		if life[r] > 0.0:
			if w != r:
				_move(r, w)
			w += 1
	count = w
	return removed

func active_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.resize(count)
	for i in count:
		out[i] = pos[i]
	return out
