extends Node3D

# 原创低模鱼群：3 种体型/配色；程序化网格 + 顶点摆尾 + 简易 boids 群游。
# 不读取外部模型/动画；所有顶点色与几何在启动时生成。

const PondField = preload("res://scripts/pond_field.gd")
const SHADER_FISH = preload("res://shaders/fish.gdshader")

const SPECIES := [
	{
		"name": "赤锦",
		"len": 0.76, "width": 0.155, "height": 0.16,
		"color": Color(1.0, 0.33, 0.04), "belly": Color(1.0, 0.78, 0.45),
		"fin": Color(1.0, 0.68, 0.34), "seed": 1.0,
		"speed_min": 0.5, "speed_max": 0.9, "depth": -0.3,
		"weight": 0.44, "anchor": Vector2(-1.4, 0.2),
	},
	{
		"name": "青鳞",
		"len": 0.46, "width": 0.085, "height": 0.095,
		"color": Color(0.05, 0.34, 0.36), "belly": Color(0.35, 0.65, 0.55),
		"fin": Color(0.32, 0.58, 0.5), "seed": 2.0,
		"speed_min": 0.6, "speed_max": 1.05, "depth": -0.8,
		"weight": 0.33, "anchor": Vector2(2.4, -0.9),
	},
	{
		"name": "银灯",
		"len": 0.34, "width": 0.06, "height": 0.07,
		"color": Color(0.6, 0.8, 0.86), "belly": Color(0.95, 0.98, 0.95),
		"fin": Color(0.82, 0.93, 0.94), "seed": 3.0,
		"speed_min": 0.55, "speed_max": 1.0, "depth": -0.6,
		"weight": 0.23, "anchor": Vector2(-0.6, 2.2),
	},
]

const RIPPLE_SLOTS := 8

var fish_material: ShaderMaterial
var fish: Array = []
var total_requested := 18
var rng := RandomNumberGenerator.new()
var meshes: Array[ArrayMesh] = []

var ripple_pos := PackedVector2Array()
var ripple_birth := PackedFloat32Array()
var ripple_amp := PackedFloat32Array()
var _ripple_head := 0
var _rain_timer := 0.0


func setup() -> void:
	rng.seed = 20261126
	fish_material = ShaderMaterial.new()
	fish_material.shader = SHADER_FISH
	for spec in SPECIES:
		meshes.append(_build_fish_mesh(spec))
	for i in RIPPLE_SLOTS:
		ripple_pos.append(Vector2.ZERO)
		ripple_birth.append(-999.0)
		ripple_amp.append(0.0)
	set_fish_count(18)


func set_fish_count(count: int) -> void:
	total_requested = clampi(count, 6, 36)
	for f in fish:
		if is_instance_valid(f["pivot"]):
			f["pivot"].queue_free()
	fish.clear()
	var counts := _species_counts(total_requested)
	for s in SPECIES.size():
		var spec: Dictionary = SPECIES[s]
		for k in counts[s]:
			_spawn_one(s, spec, k, counts[s])


func _species_counts(total: int) -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	if total <= 0:
		return counts
	# 至少各 1 条，其余按权重分配
	counts[0] = 1
	counts[1] = 1
	counts[2] = 1
	var remain := total - 3
	for i in remain:
		var pick := 0
		var r := rng.randf()
		if r < 0.46:
			pick = 0
		elif r < 0.76:
			pick = 1
		else:
			pick = 2
		counts[pick] += 1
	return counts


func _spawn_one(species_idx: int, spec: Dictionary, index: int, group_count: int) -> void:
	var pivot := Node3D.new()
	pivot.name = "Fish_%s_%d" % [spec["name"], index]
	add_child(pivot)
	var body := MeshInstance3D.new()
	body.mesh = meshes[species_idx]
	body.material_override = fish_material
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(body)

	var anchor := _anchor(species_idx, rng.randf() * 10.0)
	var ang := rng.randf() * TAU
	var rad := rng.randf_range(0.4, 2.2)
	var p2 := Vector2(anchor.x + cos(ang) * rad, anchor.z + sin(ang) * rad)
	p2 = PondField.clamp_to_water(p2, 0.9)
	var y := clampf(float(spec["depth"]) + rng.randf_range(-0.12, 0.12), -1.35, -0.22)
	var floor_y := PondField.floor_y(p2)
	y = max(y, floor_y + 0.3)
	var pos := Vector3(p2.x, y, p2.y)
	pivot.position = pos
	var dir := Vector3(cos(ang + 1.2), 0, sin(ang + 1.2)).normalized()
	pivot.basis = Basis.looking_at(pos + dir, Vector3.UP)
	var phase := rng.randf() * TAU
	var swim_speed := rng.randf_range(2.6, 4.0)
	var bend := rng.randf_range(0.075, 0.12)
	_apply_instance(body, phase, swim_speed, bend, spec["len"])
	fish.append({
		"species": species_idx,
		"pos": pos,
		"vel": dir * rng.randf_range(float(spec["speed_min"]), float(spec["speed_max"])),
		"pivot": pivot,
		"body": body,
		"hull": null,
		"phase": phase,
		"swim_speed": swim_speed,
		"bend": bend,
		"ripple_timer": rng.randf_range(0.8, 3.5),
		"roll": rng.randf_range(-0.08, 0.08),
	})


func _apply_instance(inst: GeometryInstance3D, phase: float, speed: float, bend: float, body_len: float) -> void:
	inst.set_instance_shader_parameter("swim_phase", phase)
	inst.set_instance_shader_parameter("swim_speed", speed)
	inst.set_instance_shader_parameter("swim_bend", bend)
	inst.set_instance_shader_parameter("body_len", body_len)


func _anchor(species_idx: int, t: float) -> Vector3:
	var spec: Dictionary = SPECIES[species_idx]
	var base: Vector2 = spec["anchor"]
	var p := Vector2(
		base.x + sin(t * 0.11 + species_idx * 2.1) * 1.7,
		base.y + cos(t * 0.085 + species_idx * 1.3) * 1.1)
	p = PondField.clamp_to_water(p, 1.0)
	return Vector3(p.x, float(spec["depth"]), p.y)


func update_fish(delta: float, now: float, active: bool = true) -> void:
	if not active:
		return
	if delta <= 0.0:
		return
	var n := fish.size()
	for i in n:
		var f: Dictionary = fish[i]
		var pos: Vector3 = f["pos"]
		var vel: Vector3 = f["vel"]
		var species_idx: int = int(f["species"])
		var spec: Dictionary = SPECIES[species_idx]
		var acc := Vector3.ZERO
		var sep := Vector3.ZERO
		var coh := Vector3.ZERO
		var ali := Vector3.ZERO
		var neighbors := 0
		for j in n:
			if i == j:
				continue
			var other: Dictionary = fish[j]
			var d: Vector3 = pos - (other["pos"] as Vector3)
			var dist := d.length()
			if dist < 0.001:
				continue
			if dist < 0.95:
				sep += d / dist * (1.0 - dist / 0.95)
			if int(other["species"]) == species_idx and dist < 2.4:
				coh += other["pos"] as Vector3
				ali += other["vel"] as Vector3
				neighbors += 1
			# 避免和其他种类贴得太近
			if int(other["species"]) != species_idx and dist < 0.5:
				sep += d / dist * 0.8
		if neighbors > 0:
			coh /= float(neighbors)
			ali /= float(neighbors)
			acc += (coh - pos) * 0.35
			acc += (ali - vel) * 0.5
		acc += sep * 2.1

		var anchor := _anchor(species_idx, now)
		acc += (anchor - pos) * 0.24
		var target_y := float(spec["depth"]) + sin(now * 0.6 + float(f["phase"])) * 0.07
		acc.y += (target_y - pos.y) * 1.9

		var p2 := Vector2(pos.x, pos.z)
		var ahead := p2 + Vector2(vel.x, vel.z).normalized() * 0.9
		if PondField.fish_blocked(ahead, 0.65):
			var to_center := Vector3(PondField.POND_CENTER.x - pos.x, 0.0, PondField.POND_CENTER.y - pos.z)
			acc += to_center.normalized() * 2.4
		if PondField.fish_blocked(p2, 0.25):
			var to_center2 := Vector3(PondField.POND_CENTER.x - pos.x, 0.0, PondField.POND_CENTER.y - pos.z)
			acc += to_center2.normalized() * 3.2
		var fl := PondField.floor_y(p2)
		if pos.y < fl + 0.28:
			acc.y += (fl + 0.32 - pos.y) * 6.0
		if pos.y > -0.2:
			acc.y -= (pos.y + 0.2) * 5.0

		vel += acc * delta
		var horiz := Vector2(vel.x, vel.z).length()
		var min_s := float(spec["speed_min"])
		var max_s := float(spec["speed_max"])
		if horiz > max_s:
			var k := max_s / horiz
			vel.x *= k
			vel.z *= k
		elif horiz < min_s * 0.55 and horiz > 0.0001:
			var k2 := min_s / horiz
			vel.x *= k2
			vel.z *= k2
		vel.y = clampf(vel.y, -0.55, 0.55)
		pos += vel * delta

		# 边界兜底：万一穿出水面/岸线，拉回安全水域。
		var p3 := Vector2(pos.x, pos.z)
		if PondField.fish_blocked(p3, 0.3):
			var safe := PondField.clamp_to_water(p3, 0.6)
			pos.x = safe.x
			pos.z = safe.y
			vel *= 0.5
		pos.y = clampf(pos.y, fl + 0.26, -0.18)

		f["pos"] = pos
		f["vel"] = vel
		var pivot: Node3D = f["pivot"]
		pivot.position = pos
		var dir := vel
		dir.y *= 0.35
		if dir.length() > 0.01:
			var target_basis := Basis.looking_at(pos + dir.normalized(), Vector3.UP)
			var q := target_basis.get_rotation_quaternion()
			pivot.quaternion = pivot.quaternion.slerp(q, clampf(delta * 4.2, 0.0, 1.0))
		var body: MeshInstance3D = f["body"]
		body.rotation.z = sin(now * 1.7 + float(f["phase"])) * 0.09 + float(f["roll"]) * 0.4

		# 近水面鱼偶尔激起环纹
		f["ripple_timer"] = float(f["ripple_timer"]) - delta
		if float(f["ripple_timer"]) <= 0.0:
			if pos.y > -0.52 and rng.randf() < 0.75:
				spawn_ripple(Vector2(pos.x, pos.z), 0.5, now)
			f["ripple_timer"] = rng.randf_range(2.2, 4.6)


func update_rain(delta: float, now: float, rain_amount: float) -> void:
	if rain_amount < 0.05:
		return
	_rain_timer -= delta
	if _rain_timer > 0.0:
		return
	_rain_timer = rng.randf_range(0.08, 0.18)
	var x := rng.randf_range(PondField.BOUNDS_MIN.x + 2.0, PondField.BOUNDS_MAX.x - 2.0)
	var z := rng.randf_range(PondField.BOUNDS_MIN.y + 2.0, PondField.BOUNDS_MAX.y - 2.0)
	var p := Vector2(x, z)
	if not PondField.is_water(p):
		return
	spawn_ripple(p, rng.randf_range(0.35, 0.8), now)


func spawn_ripple(p: Vector2, amp: float, now: float) -> void:
	ripple_pos[_ripple_head] = p
	ripple_birth[_ripple_head] = now
	ripple_amp[_ripple_head] = amp
	_ripple_head = (_ripple_head + 1) % RIPPLE_SLOTS


# ── 程序化鱼网格 ────────────────────────────────────────────────────────
func _build_fish_mesh(spec: Dictionary) -> ArrayMesh:
	var L: float = spec["len"]
	var W: float = spec["width"]
	var H: float = spec["height"]
	var seed: float = spec["seed"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 7
	var segs := 8
	var ring_pos: Array = []
	var ring_t: Array = []
	var ring_ang: Array = []
	for r in rings + 1:
		var t := float(r) / float(rings)
		var z := -L * 0.5 + t * L
		var prof := sin(PI * (0.10 + 0.86 * t))
		var row: Array = []
		var row_ang: Array = []
		for s in segs:
			var ang := TAU * float(s) / float(segs)
			var x := cos(ang) * W * prof
			var y := sin(ang) * H * prof
			row.append(Vector3(x, y, z))
			row_ang.append(ang)
		ring_pos.append(row)
		ring_t.append(t)
		ring_ang.append(row_ang)

	for r in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = ring_pos[r][s]
			var b: Vector3 = ring_pos[r][s2]
			var c: Vector3 = ring_pos[r + 1][s2]
			var d: Vector3 = ring_pos[r + 1][s]
			var t0: float = ring_t[r]
			var t1: float = ring_t[r + 1]
			var ang0: float = ring_ang[r][s]
			var ang1: float = ring_ang[r][s2]
			var ca := _body_color(spec, L, W, H, a, t0, ang0)
			var cb := _body_color(spec, L, W, H, b, t0, ang1)
			var cc := _body_color(spec, L, W, H, c, t1, ang1)
			var cd := _body_color(spec, L, W, H, d, t1, ang0)
			var n := _outward_normal(a, W, H)
			_add_tri(st, a, b, c, ca, cb, cc, n)
			_add_tri(st, a, c, d, ca, cc, cd, n)

	# 头部封口（圆鼻）
	var nose := Vector3(0, 0, -L * 0.58)
	var nose_col := _body_color(spec, L, W, H, nose, 0.0, 0.0).darkened(0.12)
	for s in segs:
		var s2 := (s + 1) % segs
		var a: Vector3 = ring_pos[0][s]
		var b: Vector3 = ring_pos[0][s2]
		var ca := _body_color(spec, L, W, H, a, 0.0, ring_ang[0][s])
		var cb := _body_color(spec, L, W, H, b, 0.0, ring_ang[0][s2])
		_add_tri(st, nose, a, b, nose_col, ca, cb, Vector3(0, 0, -1))

	# 水平尾鳍（俯视可读）+ 竖直尾鳍（侧视可读）
	var fin_col: Color = spec["fin"]
	var tail_base := L * 0.48
	_add_tri(st, Vector3(0, 0, tail_base), Vector3(-W * 1.55, 0.005, L * 0.62), Vector3(0, 0, L * 0.71), fin_col, fin_col, fin_col, Vector3.UP)
	_add_tri(st, Vector3(0, 0, tail_base), Vector3(0, 0, L * 0.71), Vector3(W * 1.55, 0.005, L * 0.62), fin_col, fin_col, fin_col, Vector3.UP)
	_add_tri(st, Vector3(0, 0.002, tail_base), Vector3(0, H * 1.25, L * 0.62), Vector3(0, 0.002, L * 0.72), fin_col, fin_col.darkened(0.06), fin_col, Vector3(1, 0, 0))
	_add_tri(st, Vector3(0, 0.002, tail_base), Vector3(0, 0.002, L * 0.72), Vector3(0, -H * 0.9, L * 0.62), fin_col, fin_col, fin_col.darkened(0.08), Vector3(-1, 0, 0))

	# 胸鳍
	for side in [-1.0, 1.0]:
		var base := Vector3(float(side) * W * 0.85, -H * 0.1, -L * 0.12)
		var tip := Vector3(float(side) * W * 1.85, -H * 0.05, L * 0.02)
		var back := Vector3(float(side) * W * 0.8, -H * 0.12, L * 0.16)
		_add_tri(st, base, tip, back, fin_col, fin_col.lightened(0.08), fin_col, Vector3.UP)

	# 背鳍
	_add_tri(st, Vector3(0, H * 0.92, -L * 0.2), Vector3(0, H * 1.45, L * 0.06), Vector3(0, H * 0.85, L * 0.2), fin_col, fin_col.darkened(0.05), fin_col, Vector3(1, 0, 0))
	_add_tri(st, Vector3(0, H * 0.92, -L * 0.2), Vector3(0, H * 0.85, L * 0.2), Vector3(0, H * 1.45, L * 0.06), fin_col, fin_col, fin_col.darkened(0.05), Vector3(-1, 0, 0))
	return st.commit()


func _body_color(spec: Dictionary, L: float, W: float, H: float, p: Vector3, t: float, ang: float) -> Color:
	var base: Color = spec["color"]
	var belly: Color = spec["belly"]
	var seed: float = spec["seed"]
	var y_norm := sin(ang)
	var c := base
	if y_norm < 0.0:
		c = base.lerp(belly, smoothstep(0.0, -0.9, y_norm) * 0.62)
	# 物种花纹
	if seed < 1.5:
		# 赤锦：白斑
		var patch := 0.5 + 0.5 * sin(t * 18.0 + ang * 2.3 + seed * 2.1)
		var patch2 := 0.5 + 0.5 * sin(t * 9.0 - ang * 3.1 + 1.6)
		if patch * 0.65 + patch2 * 0.35 > 0.72:
			c = c.lerp(Color(1.0, 0.94, 0.84), 0.5)
	elif seed < 2.5:
		# 青鳞：纵向暗纹
		var stripe := 0.5 + 0.5 * sin(ang * 5.0 + t * 2.0)
		c = c.lerp(c.darkened(0.28), smoothstep(0.55, 0.95, stripe) * 0.55)
		c = c.lerp(Color(0.3, 0.55, 0.48), smoothstep(0.2, 0.7, y_norm) * 0.18)
	else:
		# 银灯：蓝背 + 银腹
		c = c.lerp(Color(0.35, 0.55, 0.66), smoothstep(0.0, 0.9, y_norm) * 0.5)
		c = c.lerp(Color(0.98, 0.99, 0.95), smoothstep(0.0, -0.7, y_norm) * 0.35)
	# 眼睛（头部两侧）
	if t < 0.24 and abs(cos(ang)) > 0.86 and abs(sin(ang)) < 0.5:
		c = Color(0.06, 0.07, 0.08)
	return c


func _outward_normal(p: Vector3, W: float, H: float) -> Vector3:
	if absf(p.x) + absf(p.y) < 0.00001:
		return Vector3.UP
	return Vector3(p.x / max(W, 0.001), p.y / max(H, 0.001), 0.0).normalized()


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, n: Vector3) -> void:
	st.set_normal(n)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


# ── 查询接口（HUD / smoke）──────────────────────────────────────────────
func get_fish_count() -> int:
	return fish.size()


func get_species_counts() -> Array[int]:
	var counts: Array[int] = [0, 0, 0]
	for f in fish:
		counts[int(f["species"])] += 1
	return counts


func get_positions() -> Array[Vector3]:
	var arr: Array[Vector3] = []
	for f in fish:
		arr.append(f["pos"] as Vector3)
	return arr


func all_inside_water() -> bool:
	for f in fish:
		var p: Vector3 = f["pos"]
		if PondField.fish_blocked(Vector2(p.x, p.z), 0.05):
			return false
		if p.y > 0.02 or p.y < PondField.floor_y(Vector2(p.x, p.z)) - 0.05:
			return false
	return true


func total_ripple_slots() -> int:
	return RIPPLE_SLOTS
