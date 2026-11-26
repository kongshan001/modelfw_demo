class_name SwarmBattleView
extends Node2D

## Battle render layer (T-20261126-026 art pass):
## - units: ONE MultiMesh + INSTANCE_CUSTOM atlas (10 cards x 12 frames), no per-unit Node
## - faction base shape + per-instance hit flash + gold elite outline are in the shader
## - state machine: idle/move/attack/death/spawn frames driven by battle events
## - VFX: ONE additive MultiMesh with 6 families (spark / shot / splash / death / spawn / victory)
## - environment: baked arena stage + 4 waving flags + 2 fog layers
## - shop preview uses the same pipeline with idle animation.

signal battle_finished(result)

const Battle = preload("res://scripts/swarm_battle.gd")
const Cards = preload("res://scripts/swarm_cards.gd")
const ThemeKit = preload("res://scripts/swarm_theme.gd")
const Art = preload("res://scripts/swarm_art.gd")

const UNIT_QUAD := 9.0
const FX_QUAD := 32.0
const FX_MAX := 1000
const FX_GOLD := Color("#ffd88a")

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
var _fx_buffer := PackedFloat32Array()
var _fx_dirty := false
var _applied_count := 0
var _base_scale := 1.0
var _unit_buffer := PackedFloat32Array()
var _sim_step := 0.1

var _n := 0
var _card_rows := PackedByteArray()
var _team := PackedByteArray()
var _gold := PackedByteArray()
var _tints := PackedColorArray()
var _base_alpha := PackedFloat32Array()
var _display_scale := PackedFloat32Array()
var _frames := PackedByteArray()
var _flash := PackedFloat32Array()
var _atk_t := PackedFloat32Array()
var _death_t := PackedFloat32Array()
var _spawn_t := PackedFloat32Array()
var _prev_cd := PackedFloat32Array()
var _prev_hp := PackedFloat32Array()
var _hidden := PackedByteArray()
var _anim_clock := 0.0
var _anim_accum := 0.0
var _victory_fired := false
var _flags: Array[Sprite2D] = []
var _fogs: Array[Sprite2D] = []

var _sim_ms_sum := 0.0
var _sim_frames := 0
var _render_ms_sum := 0.0
var _render_frames := 0
var _last_render_ms := 0.0
var _last_sim_ms := 0.0
var _dirty := true


func _ready() -> void:
	z_index = 0
	_build_environment()
	_build_units()
	_build_fx()
	queue_redraw()


func _build_environment() -> void:
	var bg := Sprite2D.new()
	bg.texture = Art.ARENA
	bg.centered = false
	bg.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(bg)
	var flag_positions := [
		Vector2(24, 42), Vector2(24, 238), Vector2(1128, 42), Vector2(1128, 238),
	]
	var flag_mats: Array[ShaderMaterial] = [Art.flag_material(), Art.flag_material(),
		Art.flag_material(), Art.flag_material()]
	for i in 4:
		var fl := Sprite2D.new()
		fl.texture = Art.FLAG_ALLY if i < 2 else Art.FLAG_ENEMY
		fl.centered = false
		fl.position = flag_positions[i]
		fl.scale = Vector2(0.5, 0.5)
		fl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fl.material = flag_mats[i]
		fl.modulate = Color(0.92, 0.96, 0.96, 0.82)
		add_child(fl)
		_flags.append(fl)
	for i in 2:
		var fog := Sprite2D.new()
		fog.texture = Art.FOG_A if i == 0 else Art.FOG_B
		fog.centered = false
		fog.position = Vector2(-70, -16) if i == 0 else Vector2(-20, 8)
		fog.scale = Vector2(2.6, 1.65)
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		fog.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		fog.modulate = Color(1, 1, 1, 0.55)
		fog.material = Art.fog_material(
			Vector2(0.0045, 0.0012) if i == 0 else Vector2(-0.003, 0.0018),
			Color(0.05, 0.14, 0.17, 0.18 if i == 0 else 0.12))
		add_child(fog)
		_fogs.append(fog)


func _build_units() -> void:
	_unit_mm = MultiMesh.new()
	_unit_mm.transform_format = MultiMesh.TRANSFORM_2D
	_unit_mm.use_colors = true
	_unit_mm.use_custom_data = true
	var uq := QuadMesh.new()
	uq.size = Vector2(UNIT_QUAD, UNIT_QUAD)
	_unit_mm.mesh = uq
	_unit_mm.instance_count = 0
	_unit_mmi = MultiMeshInstance2D.new()
	_unit_mmi.multimesh = _unit_mm
	_unit_mmi.texture = Art.UNIT_ATLAS
	_unit_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_unit_mmi.material = Art.unit_material()
	_unit_mmi.show_behind_parent = false
	add_child(_unit_mmi)


func _build_fx() -> void:
	_fx_mm = MultiMesh.new()
	_fx_mm.transform_format = MultiMesh.TRANSFORM_2D
	_fx_mm.use_colors = true
	_fx_mm.use_custom_data = true
	var fq := QuadMesh.new()
	fq.size = Vector2(FX_QUAD, FX_QUAD)
	_fx_mm.mesh = fq
	_fx_mm.instance_count = FX_MAX
	_fx_mmi = MultiMeshInstance2D.new()
	_fx_mmi.multimesh = _fx_mm
	_fx_mmi.texture = Art.VFX_ATLAS
	_fx_mmi.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fx_mmi.material = Art.fx_material()
	add_child(_fx_mmi)
	_fx_buffer.resize(FX_MAX * 16)
	for i in FX_MAX:
		_fx.append({"on": false})
		_hide_fx(i)
	_fx_mm.buffer = _fx_buffer
	_fx_dirty = false


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
	_victory_fired = false
	_anim_clock = 0.0
	_anim_accum = 0.0
	for i in FX_MAX:
		_fx[i] = {"on": false}
		_hide_fx(i)
	_fx_mm.buffer = _fx_buffer
	_fx_mmi.visible = false
	if battle == null:
		_unit_mm.instance_count = 0
		_unit_mmi.visible = false
		_applied_count = 0
		_n = 0
		return
	_n = battle.pos.size()
	var count := _n
	_base_scale = clampf(1.45 - float(count) / 6500.0, 0.92, 1.45)
	_sim_step = Battle.recommended_step(int(battle.side_count[0]) + int(battle.side_count[1]))
	_unit_mm.instance_count = count
	_unit_mmi.visible = count > 0
	_applied_count = count
	_unit_buffer.resize(count * 16)
	_card_rows.resize(count)
	_team.resize(count)
	_gold.resize(count)
	_tints.resize(count)
	_base_alpha.resize(count)
	_display_scale.resize(count)
	_frames.resize(count)
	_flash.resize(count)
	_atk_t.resize(count)
	_death_t.resize(count)
	_spawn_t.resize(count)
	_prev_cd.resize(count)
	_prev_hp.resize(count)
	_hidden.resize(count)
	_hidden.fill(0)
	var density := 0.94 if count < 400 else (0.86 if count < 1600 else 0.80)
	for i in count:
		var s := int(battle.team[i])
		var ci := int(battle.card_idx[i])
		var card_list: Array = battle.side_cards[s]
		var id := ""
		if ci < card_list.size():
			id = String(card_list[ci].get("id", ""))
		var row := Art.card_index(id)
		var card := Cards.get_card(id)
		var tier := int(card.get("tier", 1)) if not card.is_empty() else 1
		var base := ThemeKit.CYAN if s == 0 else ThemeKit.RED
		var tint := base.lerp(Color.WHITE, 0.20 + 0.035 * float(tier - 1))
		if int(battle.role[i]) == 2:
			tint = tint.lerp(Color.WHITE, 0.10)
		var gold := int(battle.star[i]) >= 2
		if gold:
			tint = tint.lerp(ThemeKit.GOLD, 0.30)
			tint = tint.lerp(Color.WHITE, 0.10)
		_card_rows[i] = row
		_team[i] = s
		_gold[i] = 1 if gold else 0
		_tints[i] = tint
		_base_alpha[i] = density
		_display_scale[i] = _base_scale * clampf(float(battle.size_mul[i]), 0.84, 1.30) * (1.04 if gold else 1.0)
		_frames[i] = 10
		_flash[i] = 0.0
		_atk_t[i] = -1.0
		_death_t[i] = -1.0
		_spawn_t[i] = 0.0
		_prev_cd[i] = battle.cooldown[i]
		_prev_hp[i] = battle.hp[i]
		var idx := i * 16
		var sign_x := -1.0 if s == 1 else 1.0
		_unit_buffer[idx] = _display_scale[i] * sign_x
		_unit_buffer[idx + 5] = _display_scale[i]
		_unit_buffer[idx + 3] = -2000.0
		_unit_buffer[idx + 7] = -2000.0
		_unit_buffer[idx + 8] = tint.r
		_unit_buffer[idx + 9] = tint.g
		_unit_buffer[idx + 10] = tint.b
		_unit_buffer[idx + 11] = density
		_unit_buffer[idx + 12] = float(row)
		_unit_buffer[idx + 13] = 10.0
		_unit_buffer[idx + 14] = 0.0
		_unit_buffer[idx + 15] = float((1 if gold else 0) + s * 2)
	_unit_mm.buffer = _unit_buffer
	# spawn gates: 4 rings + sparks, read as "units pour out of the gates"
	for s in 2:
		var gx := 46.0 if s == 0 else Battle.ARENA.x - 46.0
		for gy in [70.0, 240.0]:
			_spawn_fx(4, Vector2(gx, gy), Vector2.ZERO, s, 1.4, 0.34)
			for k in 6:
				var ang := TAU * float(k) / 6.0 + float(s)
				_spawn_fx(0, Vector2(gx, gy) + Vector2(cos(ang), sin(ang)) * 12.0,
					Vector2(cos(ang), sin(ang)) * 22.0, s, 0.55, 0.28)
	_tick_anim(0.0)
	_update_units_visual(1.0)
	_drain_fx(0.0)


func _unit_color(i: int) -> Color:
	return _tints[i]


func _tick_anim(dt: float) -> void:
	if battle == null or _n == 0:
		return
	_anim_clock += dt
	for i in _n:
		if int(battle.alive[i]) == 0:
			if _death_t[i] < 0.0:
				_death_t[i] = 0.0
				var p: Vector2 = battle.pos[i]
				_spawn_fx(3, p, Vector2(0, -10), int(_team[i]), 0.85, 0.18)
			else:
				_death_t[i] += dt
			var idx := i * 16
			var fade := clampf(1.0 - _death_t[i] / 0.18, 0.0, 1.0)
			_unit_buffer[idx + 11] = _base_alpha[i] * fade
			_unit_buffer[idx + 13] = float(7 + mini(2, int(_death_t[i] / 0.06)))
			if _death_t[i] >= 0.18 and _hidden[i] == 0:
				_hidden[i] = 1
				_unit_buffer[idx + 3] = -2000.0
				_unit_buffer[idx + 7] = -2000.0
			continue
		if _spawn_t[i] < 1.0:
			_spawn_t[i] += dt
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - dt / 0.06)
		if _atk_t[i] >= 0.0:
			_atk_t[i] += dt
			if _atk_t[i] >= 0.24:
				_atk_t[i] = -1.0
		# attack started? cooldown resets upward after _do_attack()
		var cd := float(battle.cooldown[i])
		if cd > _prev_cd[i] + 0.003:
			_atk_t[i] = 0.0
			if int(battle.role[i]) == 3:
				var tgt := int(battle.target[i])
				if tgt >= 0:
					_spawn_fx(2, battle.pos[tgt], Vector2.ZERO, int(_team[i]), 1.15, 0.20)
		_prev_cd[i] = cd
		if float(battle.hp[i]) < _prev_hp[i] - 0.001:
			_flash[i] = 1.0
		_prev_hp[i] = float(battle.hp[i])
		var frame := _frame_for(i)
		_frames[i] = frame
		var idx := i * 16
		_unit_buffer[idx + 11] = _base_alpha[i]
		_unit_buffer[idx + 13] = float(frame)
		_unit_buffer[idx + 14] = _flash[i]


func _frame_for(i: int) -> int:
	if _spawn_t[i] < 0.30:
		return 10
	if _atk_t[i] >= 0.0:
		return 4 + mini(2, int(_atk_t[i] / 0.08))
	var moving: bool = battle.pos[i].distance_squared_to(battle.prev[i]) > 0.12
	var phase := fmod(_anim_clock + float(i % 17) * 0.037, 1.0)
	if moving:
		return 2 + (int(phase / 0.125) % 2)
	if _gold[i] == 1:
		return 11
	return int(phase / 0.25) % 2


func _update_units_visual(interp: float) -> void:
	if battle == null:
		return
	var n: int = mini(_applied_count, battle.pos.size())
	if _unit_buffer.size() != n * 16:
		return
	var t0 := Time.get_ticks_usec()
	if battle.finished:
		interp = 1.0
	for i in n:
		if int(battle.alive[i]) == 0:
			if _death_t[i] >= 0.18 and _hidden[i] == 0:
				_hidden[i] = 1
				var idx0 := i * 16
				_unit_buffer[idx0 + 3] = -2000.0
				_unit_buffer[idx0 + 7] = -2000.0
			continue
		var p: Vector2 = battle.prev[i].lerp(battle.pos[i], interp)
		var idx := i * 16
		_unit_buffer[idx + 3] = p.x
		_unit_buffer[idx + 7] = p.y
	_unit_mm.buffer = _unit_buffer
	_last_render_ms = float(Time.get_ticks_usec() - t0) / 1000.0
	_render_ms_sum += _last_render_ms
	_render_frames += 1


func _hide_fx(i: int) -> void:
	var o := i * 16
	for k in 16:
		_fx_buffer[o + k] = 0.0
	_fx_buffer[o + 3] = -2000.0
	_fx_buffer[o + 7] = -2000.0
	_fx_dirty = true


func _write_fx(i: int, pos: Vector2, rot: float, sx: float, sy: float, col: Color,
		kind: int, frame: int) -> void:
	var o := i * 16
	var c := cos(rot)
	var sn := sin(rot)
	_fx_buffer[o] = sx * c
	_fx_buffer[o + 1] = -sy * sn
	_fx_buffer[o + 2] = 0.0
	_fx_buffer[o + 3] = pos.x
	_fx_buffer[o + 4] = sx * sn
	_fx_buffer[o + 5] = sy * c
	_fx_buffer[o + 6] = 0.0
	_fx_buffer[o + 7] = pos.y
	_fx_buffer[o + 8] = col.r
	_fx_buffer[o + 9] = col.g
	_fx_buffer[o + 10] = col.b
	_fx_buffer[o + 11] = col.a
	_fx_buffer[o + 12] = float(kind)
	_fx_buffer[o + 13] = float(frame)
	_fx_buffer[o + 14] = 0.0
	_fx_buffer[o + 15] = 0.0
	_fx_dirty = true


func _spawn_fx(kind: int, a: Vector2, b: Vector2, team: int, scale: float, life: float,
		color: Color = Color(0, 0, 0, 0)) -> void:
	var slot := _fx_cursor
	_fx_cursor = (_fx_cursor + 1) % FX_MAX
	if color.a <= 0.0:
		if kind == 5:
			color = FX_GOLD
		elif team == 0:
			color = ThemeKit.CYAN_SOFT
		else:
			color = ThemeKit.RED_SOFT
	var seed_val := float((slot * 37 + int(a.x) * 7 + int(a.y) * 13) % 97) / 97.0
	var vel := Vector2.ZERO
	if kind == 3:
		vel = Vector2(0, -18)
	elif kind == 5:
		var ang := seed_val * TAU + float(slot % 11) * 0.7
		vel = Vector2(cos(ang), sin(ang)) * (40.0 + 90.0 * seed_val)
	elif kind == 0:
		var ang2 := seed_val * TAU
		vel = Vector2(cos(ang2), sin(ang2)) * 6.0
	_fx[slot] = {
		"on": true, "kind": kind, "a": a, "b": b, "vel": vel,
		"age": 0.0, "life": maxf(0.05, life), "scale": scale,
		"color": color, "seed": seed_val,
	}
	var rot0 := 0.0
	if kind == 1:
		var d0 := b - a
		rot0 = d0.angle() if d0.length_squared() > 0.01 else 0.0
	_write_fx(slot, a, rot0, scale, scale, Color(color.r, color.g, color.b, 0.9), kind, 0)


func _drain_fx(delta: float) -> void:
	if battle != null and not is_preview:
		var events: Array = battle.drain_fx(110)
		for ev in events:
			var k := String(ev.get("k", "hit"))
			var a: Vector2 = ev.get("a", Vector2.ZERO)
			var b: Vector2 = ev.get("b", Vector2.ZERO)
			var team := int(ev.get("team", 0))
			if k == "shot":
				_spawn_fx(1, a, b, team, 1.0, 0.16)
			else:
				_spawn_fx(0, a, Vector2.ZERO, team, 1.0, 0.12)
	# Paused combat is a still frame: no need to rewrite 1000 FX every frame.
	if paused and not (battle != null and battle.finished):
		_fx_mmi.visible = _fx_active > 0
		return
	var dt := delta * clampf(speed, 1.0, 4.0)
	_fx_active = 0
	for i in FX_MAX:
		var slot: Dictionary = _fx[i]
		if not bool(slot.get("on", false)):
			continue
		var age := float(slot["age"]) + dt
		slot["age"] = age
		var life := float(slot["life"])
		if age >= life:
			slot["on"] = false
			_hide_fx(i)
			continue
		_fx_active += 1
		var t := clampf(age / life, 0.0, 1.0)
		var kind := int(slot["kind"])
		var col: Color = slot["color"]
		col.a = pow(1.0 - t, 1.15)
		var pos: Vector2 = slot["a"]
		var scale := float(slot["scale"])
		var rot := 0.0
		var sx := scale
		var sy := scale
		var frame := mini(2, int(t * 3.0))
		match kind:
			1:
				var p1: Vector2 = slot["b"]
				pos = Vector2(slot["a"]).lerp(p1, t)
				var d: Vector2 = p1 - Vector2(slot["a"])
				rot = d.angle() if d.length_squared() > 0.01 else 0.0
				sx = 0.85 + 0.15 * (1.0 - t)
				sy = 0.38
			2:
				scale *= 1.0 + 0.7 * t
				sx = scale
				sy = scale
			3:
				pos += Vector2(slot["vel"]) * age
				rot = 0.2
			4:
				scale *= 1.0 + 0.9 * t
				sx = scale
				sy = scale
			5:
				pos += Vector2(slot["vel"]) * dt
				slot["vel"] = Vector2(slot["vel"]) * 0.985
				scale *= 1.0 + 0.35 * t
				sx = scale
				sy = scale
				rot = float(slot["seed"]) * TAU
			_:
				pos += Vector2(slot["vel"]) * age * 0.5
				scale *= 1.0 + 0.7 * t
				sx = scale
				sy = scale
		_write_fx(i, pos, rot, sx, sy, col, kind, frame)
	if _fx_dirty:
		_fx_mm.buffer = _fx_buffer
		_fx_dirty = false
	_fx_mmi.visible = _fx_active > 0


func _spawn_victory() -> void:
	if _victory_fired:
		return
	_victory_fired = true
	var center := Vector2(Battle.ARENA.x * 0.5, Battle.ARENA.y * 0.5)
	for i in 220:
		var ang := float(i) * 2.399963 + 0.4
		var spd := 30.0 + 150.0 * fmod(float(i) * 0.618, 1.0)
		var col := FX_GOLD
		if i % 3 != 0:
			col = ThemeKit.CYAN_SOFT if i % 2 == 0 else ThemeKit.RED_SOFT
		_spawn_fx(5, center + Vector2(cos(ang), sin(ang)) * 6.0,
			Vector2.ZERO, 0, 0.55 + 0.9 * fmod(float(i) * 0.37, 1.0), 1.0, col)


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
			_spawn_victory()
			emit_signal("battle_finished", battle.result)
	if not manual:
		_anim_accum += delta
		if _anim_accum >= 0.05:
			var adt := minf(_anim_accum, 0.15)
			_anim_accum = 0.0
			if not paused:
				_tick_anim(adt)
		var interp := 1.0 if (paused or battle.finished or is_preview) else clampf(accumulator / _sim_step, 0.0, 1.0)
		_update_units_visual(interp)
		_dirty = false
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
	_tick_anim(real_dt)
	_update_units_visual(alpha)
	_drain_fx(real_dt)
	if battle.finished and running:
		running = false
		paused = true
		_spawn_victory()
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
	# A fast-forward is not a live frame: reset per-unit damage/attack deltas so
	# the capture shows charged attackers instead of a full-screen white flash.
	for i in _n:
		_flash[i] = 0.0
		_prev_hp[i] = battle.hp[i] if i < battle.hp.size() else 0.0
		_prev_cd[i] = battle.cooldown[i] if i < battle.cooldown.size() else 0.0
		_atk_t[i] = -1.0
	var charged := 0
	for i in _n:
		if charged >= 700:
			break
		if int(battle.alive[i]) == 1 and float(battle.cooldown[i]) < 0.12 and int(battle.target[i]) >= 0:
			_atk_t[i] = 0.09
			charged += 1
	_tick_anim(0.0)
	_update_units_visual(1.0)
	_drain_fx(0.0)
	_drain_fx(0.04)
	_drain_fx(0.04)
	if battle.finished and running:
		running = false
		paused = true
		_spawn_victory()
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
	# The stage is a baked texture + animated flags/fog; nothing dynamic here.
	pass
