class_name SwarmBattleView
extends Node2D

## 战斗渲染层：
## - 每个单位只更新 MultiMesh 的 2D transform，一 draw call 画完全场。
## - 逻辑 5–10Hz 自适应；渲染用 prev→pos 插值到 60fps。
## - 弹道/火花用第二个固定容量 MultiMesh，仅视觉。
## - 商店阶段显示同一套编队的静态预览。

signal battle_finished(result)

const Battle = preload("res://scripts/swarm_battle.gd")
const Cards = preload("res://scripts/swarm_cards.gd")
const ThemeKit = preload("res://scripts/swarm_theme.gd")

const UNIT_QUAD := 6.0
const FX_QUAD := 15.0
const FX_MAX := 480

var battle = null
var is_preview := true
var running := false
var paused := false
var manual := false
var speed := 1.0
var accumulator := 0.0
var alpha := 1.0

var _unit_mm: MultiMesh
var _unit_mmi: MultiMeshInstance2D
var _fx_mm: MultiMesh
var _fx_mmi: MultiMeshInstance2D
var _fx: Array = []
var _fx_cursor := 0
var _fx_active := 0
var _applied_count := 0
var _base_scale := 6.0
var _unit_buffer := PackedFloat32Array()
var _dead_applied := PackedByteArray()
var _sim_step := 0.1

var _sim_ms_sum := 0.0
var _sim_frames := 0
var _render_ms_sum := 0.0
var _render_frames := 0
var _last_render_ms := 0.0
var _last_sim_ms := 0.0
var _dirty := true


func _ready() -> void:
	z_index = 0
	var unit_tex := _make_unit_texture()
	var fx_tex := _make_fx_texture()
	_unit_mm = MultiMesh.new()
	_unit_mm.transform_format = MultiMesh.TRANSFORM_2D
	_unit_mm.use_colors = true
	var uq := QuadMesh.new()
	uq.size = Vector2(UNIT_QUAD, UNIT_QUAD)
	_unit_mm.mesh = uq
	_unit_mm.instance_count = 0
	_unit_mmi = MultiMeshInstance2D.new()
	_unit_mmi.multimesh = _unit_mm
	_unit_mmi.texture = unit_tex
	_unit_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_unit_mmi.show_behind_parent = false
	add_child(_unit_mmi)

	_fx_mm = MultiMesh.new()
	_fx_mm.transform_format = MultiMesh.TRANSFORM_2D
	_fx_mm.use_colors = true
	var fq := QuadMesh.new()
	fq.size = Vector2(FX_QUAD, 3.0)
	_fx_mm.mesh = fq
	_fx_mm.instance_count = FX_MAX
	_fx_mmi = MultiMeshInstance2D.new()
	_fx_mmi.multimesh = _fx_mm
	_fx_mmi.texture = fx_tex
	_fx_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fx_mmi.z_index = 3
	add_child(_fx_mmi)
	for i in FX_MAX:
		_fx.append({"on": false})
		_fx_mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-100, -100)))
		_fx_mm.set_instance_color(i, Color(1, 1, 1, 1))
	queue_redraw()


func set_battle(b, preview: bool) -> void:
	battle = b
	is_preview = preview
	running = not preview
	paused = false
	manual = false
	speed = 1.0
	accumulator = 0.0
	alpha = 1.0 if preview else 0.0
	_dirty = true
	_sim_step = 0.1
	_sim_ms_sum = 0.0
	_sim_frames = 0
	_render_ms_sum = 0.0
	_render_frames = 0
	_last_render_ms = 0.0
	_last_sim_ms = 0.0
	_fx_active = 0
	_fx_cursor = 0
	for i in FX_MAX:
		_fx[i] = {"on": false}
		_fx_mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-100, -100)))
	_fx_mmi.visible = false
	if battle == null:
		_unit_mm.instance_count = 0
		_unit_mmi.visible = false
		_applied_count = 0
		queue_redraw()
		return
	var count: int = battle.pos.size()
	_base_scale = clampf(1.75 - float(count) / 5000.0, 0.95, 1.75)
	_sim_step = Battle.recommended_step(int(battle.side_count[0]) + int(battle.side_count[1]))
	_unit_mm.instance_count = count
	_unit_mmi.visible = count > 0
	_applied_count = count
	# 一次性写入 MultiMesh buffer（8 transform + 4 color），之后每帧只改 origin.x/y。
	_unit_buffer.resize(count * 12)
	_dead_applied.resize(count)
	_dead_applied.fill(0)
	for i in count:
		var col := _unit_color(i)
		var s := _base_scale * float(battle.size_mul[i])
		var idx := i * 12
		_unit_buffer[idx] = s
		_unit_buffer[idx + 1] = 0.0
		_unit_buffer[idx + 2] = 0.0
		_unit_buffer[idx + 3] = -1000.0
		_unit_buffer[idx + 4] = 0.0
		_unit_buffer[idx + 5] = s
		_unit_buffer[idx + 6] = 0.0
		_unit_buffer[idx + 7] = -1000.0
		_unit_buffer[idx + 8] = col.r
		_unit_buffer[idx + 9] = col.g
		_unit_buffer[idx + 10] = col.b
		_unit_buffer[idx + 11] = col.a
	_unit_mm.buffer = _unit_buffer
	queue_redraw()
	_update_units_visual(1.0 if preview else 0.0)
	_dirty = false


func _unit_color(i: int) -> Color:
	var s: int = battle.team[i]
	var base := ThemeKit.CYAN if s == 0 else ThemeKit.RED
	var ci: int = battle.card_idx[i]
	var card_list: Array = battle.side_cards[s]
	var tier := 1
	if ci < card_list.size():
		var def := Cards.get_card(String(card_list[ci].get("id", "")))
		tier = int(def.get("tier", 1))
	base = base.lerp(Color.WHITE, 0.055 * float(tier - 1))
	if int(battle.star[i]) >= 2:
		base = base.lerp(ThemeKit.GOLD if s == 0 else ThemeKit.VIOLET, 0.32)
	if int(battle.role[i]) == 2:
		base = base.lerp(Color.WHITE, 0.2)
	var n: int = _applied_count
	var alpha := 0.92 if n < 400 else (0.82 if n < 1600 else 0.74)
	return Color(base.r, base.g, base.b, alpha)


func _update_units_visual(interp: float) -> void:
	if battle == null:
		return
	var n: int = mini(_applied_count, battle.pos.size())
	if _unit_buffer.size() != n * 12:
		return
	var t0 := Time.get_ticks_usec()
	if battle.finished:
		interp = 1.0
	for i in n:
		var idx := i * 12
		if battle.alive[i] == 0:
			if _dead_applied[i] == 0:
				_unit_buffer[idx + 3] = -1000.0
				_unit_buffer[idx + 7] = -1000.0
				_dead_applied[i] = 1
			continue
		var p: Vector2 = battle.prev[i].lerp(battle.pos[i], interp)
		_unit_buffer[idx + 3] = p.x
		_unit_buffer[idx + 7] = p.y
	_unit_mm.buffer = _unit_buffer
	_last_render_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_render_ms_sum += _last_render_ms
	_render_frames += 1


func _spawn_fx(ev: Dictionary) -> void:
	var kind := 0 if String(ev.get("k", "shot")) == "shot" else 1
	var slot := _fx_cursor
	_fx_cursor = (_fx_cursor + 1) % FX_MAX
	var life := 0.16 if kind == 0 else 0.13
	_fx[slot] = {
		"on": true, "kind": kind,
		"a": ev.get("a", Vector2.ZERO), "b": ev.get("b", Vector2.ZERO),
		"age": 0.0, "life": life, "team": int(ev.get("team", 0)),
		"seed": float((_fx_cursor * 37) % 19) / 19.0,
	}


func _drain_fx(delta: float) -> void:
	if battle != null and not is_preview:
		var events: Array = battle.drain_fx(110)
		for ev in events:
			_spawn_fx(ev)
	_fx_active = 0
	var dt := delta * clampf(speed, 1.0, 4.0)
	if paused:
		dt = 0.0
	for i in FX_MAX:
		var slot: Dictionary = _fx[i]
		if not bool(slot.get("on", false)):
			_fx_mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-100, -100)))
			continue
		var age := float(slot["age"]) + dt
		slot["age"] = age
		var life := float(slot["life"])
		if age >= life:
			slot["on"] = false
			_fx_mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-100, -100)))
			continue
		_fx_active += 1
		var t := clampf(age / life, 0.0, 1.0)
		var a: Vector2 = slot["a"]
		var b: Vector2 = slot["b"]
		var col: Color = ThemeKit.CYAN if int(slot["team"]) == 0 else ThemeKit.RED
		col.a = (1.0 - t) * (0.9 if int(slot["kind"]) == 0 else 0.75)
		if int(slot["kind"]) == 0:
			var p := a.lerp(b, t)
			var d := b - a
			var ang := d.angle() if d.length_squared() > 0.01 else 0.0
			var sc := 0.55 + 0.75 * (1.0 - t)
			_fx_mm.set_instance_transform_2d(i, Transform2D(ang, Vector2(sc, 1.0), 0.0, p))
			_fx_mm.set_instance_color(i, col)
		else:
			var jitter := Vector2(cos(float(slot["seed"]) * TAU), sin(float(slot["seed"]) * TAU)) * (4.0 * t)
			var sc := 0.25 + 0.65 * (1.0 - t)
			_fx_mm.set_instance_transform_2d(i, Transform2D(float(slot["seed"]) * TAU, Vector2(sc, sc), 0.0, a + jitter))
			_fx_mm.set_instance_color(i, col)
	_fx_mmi.visible = _fx_active > 0


func _process(delta: float) -> void:
	if battle == null:
		return
	if running and not paused and not is_preview and not manual:
		accumulator += delta * speed
		var steps := 0
		var t0 := Time.get_ticks_usec()
		while accumulator >= _sim_step and steps < 8:
			battle.step(_sim_step)
			accumulator -= _sim_step
			steps += 1
			if battle.finished:
				break
		if steps > 0:
			var total_ms := float(Time.get_ticks_usec() - t0) / 1000.0
			_last_sim_ms = total_ms / float(steps)
			_sim_ms_sum += total_ms
			_sim_frames += steps
		if battle.finished:
			running = false
			paused = true
			_dirty = true
			emit_signal("battle_finished", battle.result)
	var interp := 1.0 if (paused or battle.finished or is_preview) else clampf(accumulator / _sim_step, 0.0, 1.0)
	if not manual and (running and not paused or _dirty):
		_update_units_visual(interp)
		_dirty = false
	if not manual:
		_drain_fx(delta)


func advance_manual(real_dt: float) -> void:
	if battle == null or not running or paused or is_preview:
		return
	accumulator += real_dt * speed
	var steps := 0
	var t0 := Time.get_ticks_usec()
	while accumulator >= _sim_step and steps < 12:
		battle.step(_sim_step)
		accumulator -= _sim_step
		steps += 1
		if battle.finished:
			break
	if steps > 0:
		var total_ms := float(Time.get_ticks_usec() - t0) / 1000.0
		_last_sim_ms = total_ms / float(steps)
		_sim_ms_sum += total_ms
		_sim_frames += steps
	alpha = 1.0 if (paused or battle.finished) else clampf(accumulator / _sim_step, 0.0, 1.0)
	_update_units_visual(alpha)
	_drain_fx(real_dt)
	if battle.finished and running:
		running = false
		paused = true
		emit_signal("battle_finished", battle.result)


func debug_advance(seconds: float) -> void:
	if battle == null:
		return
	var steps := mini(int(seconds / _sim_step), 500)
	var t0 := Time.get_ticks_usec()
	for i in steps:
		if battle.finished:
			break
		battle.step(_sim_step)
	if steps > 0:
		_last_sim_ms = float(Time.get_ticks_usec() - t0) / (float(steps) * 1000.0)
		_sim_ms_sum += _last_sim_ms * float(steps)
		_sim_frames += steps
	accumulator = 0.0
	alpha = 1.0
	_update_units_visual(1.0)
	_drain_fx(0.0)
	_drain_fx(0.04)
	_drain_fx(0.04)
	if battle.finished and running:
		running = false
		paused = true
		emit_signal("battle_finished", battle.result)


func set_paused(value: bool) -> void:
	paused = value
	_dirty = true


func set_speed(value: float) -> void:
	speed = clampf(value, 1.0, 4.0)


func total_units() -> int:
	if battle == null:
		return 0
	return int(battle.side_count[0]) + int(battle.side_count[1])


func ally_count() -> int:
	return 0 if battle == null else int(battle.side_count[0])


func enemy_count() -> int:
	return 0 if battle == null else int(battle.side_count[1])


func avg_sim_ms() -> float:
	return _sim_ms_sum / maxf(1.0, float(_sim_frames))


func avg_render_ms() -> float:
	return _render_ms_sum / maxf(1.0, float(_render_frames))


func _draw() -> void:
	var arena := Battle.ARENA
	draw_rect(Rect2(0, 0, arena.x, arena.y), Color(0.028, 0.052, 0.083, 1.0), true)
	draw_rect(Rect2(0, 0, arena.x * 0.5, arena.y), Color(0.06, 0.20, 0.19, 0.08), true)
	draw_rect(Rect2(arena.x * 0.5, 0, arena.x * 0.5, arena.y), Color(0.24, 0.07, 0.06, 0.07), true)
	# 细网格：全部线合并为一次 multiline。
	var lines := PackedVector2Array()
	var x := 45.0
	while x < arena.x:
		lines.append(Vector2(x, 10)); lines.append(Vector2(x, arena.y - 10))
		x += 45.0
	var y := 38.0
	while y < arena.y:
		lines.append(Vector2(10, y)); lines.append(Vector2(arena.x - 10, y))
		y += 38.0
	draw_multiline(lines, Color(0.12, 0.26, 0.33, 0.18), 0.7, true)
	# 潮汐中线刻度
	var dash := PackedVector2Array()
	var mid := arena.x * 0.5
	var yy := 18.0
	while yy < arena.y - 18.0:
		dash.append(Vector2(mid, yy)); dash.append(Vector2(mid, yy + 7.0))
		yy += 14.0
	draw_multiline(dash, Color(0.35, 0.65, 0.68, 0.3), 1.0, true)
	# 上下六角装饰
	var hex_lines := PackedVector2Array()
	for hx in [90.0, 300.0, 510.0, 690.0, 900.0, 1110.0]:
		for cy in [26.0, arena.y - 26.0]:
			var pts := ThemeKit.hex_points(Vector2(hx, cy), 9.0)
			for k in 6:
				hex_lines.append(pts[k]); hex_lines.append(pts[(k + 1) % 6])
	draw_multiline(hex_lines, Color(0.24, 0.42, 0.45, 0.18), 0.8, true)
	# 中线菱形
	var diamond := PackedVector2Array([
		Vector2(mid, arena.y * 0.5 - 18), Vector2(mid + 12, arena.y * 0.5),
		Vector2(mid, arena.y * 0.5 + 18), Vector2(mid - 12, arena.y * 0.5),
	])
	draw_colored_polygon(diamond, Color(0.05, 0.12, 0.16, 0.95))
	var dout := PackedVector2Array(diamond)
	dout.append(diamond[0])
	draw_polyline(dout, Color(0.3, 0.65, 0.65, 0.5), 1.0, true)
	# 阵营角标：两种颜色各一次 multiline。
	var blue := PackedVector2Array([
		Vector2(20, 20), Vector2(20, 42), Vector2(20, 20), Vector2(42, 20),
		Vector2(20, arena.y - 20), Vector2(20, arena.y - 42),
		Vector2(20, arena.y - 20), Vector2(42, arena.y - 20),
	])
	var red := PackedVector2Array([
		Vector2(arena.x - 20, 20), Vector2(arena.x - 20, 42),
		Vector2(arena.x - 20, 20), Vector2(arena.x - 42, 20),
		Vector2(arena.x - 20, arena.y - 20), Vector2(arena.x - 20, arena.y - 42),
		Vector2(arena.x - 20, arena.y - 20), Vector2(arena.x - 42, arena.y - 20),
	])
	draw_multiline(blue, ThemeKit.CYAN_DIM, 2.0, true)
	draw_multiline(red, ThemeKit.RED.darkened(0.2), 2.0, true)
	draw_rect(Rect2(0.5, 0.5, arena.x - 1, arena.y - 1), Color(0.18, 0.36, 0.45, 0.85), false, 1.0)


func _make_unit_texture() -> ImageTexture:
	var n := 24
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := (Vector2(n, n) - Vector2.ONE) * 0.5
	for py in n:
		for px in n:
			var d := Vector2(px, py) - c
			var q := absf(d.x) * 0.866 + absf(d.y) * 0.5
			var a := 0.0
			var lum := 1.0
			if q < 9.4:
				a = 1.0
			if q < 6.4:
				lum = 1.0
			elif q < 8.0:
				lum = 0.55
			if q >= 9.4 and q < 11.0:
				a = 0.28
				lum = 0.5
			img.set_pixel(px, py, Color(lum, lum, lum, a))
	return ImageTexture.create_from_image(img)


func _make_fx_texture() -> ImageTexture:
	var n := 32
	var img := Image.create(n, 8, false, Image.FORMAT_RGBA8)
	for py in 8:
		for px in n:
			var ax := float(px) / float(n - 1)
			var ay := 1.0 - absf(float(py) - 3.5) / 4.0
			var a := ax * ax * ay
			img.set_pixel(px, py, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
