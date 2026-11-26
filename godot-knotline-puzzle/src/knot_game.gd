class_name KnotGame
extends Node3D

## Knotline · 线屿 — main controller.
## Owns the rope simulation, orbit camera, input modes, HUD and acceptance
## debug hooks. All rendering assets are generated in code / shaders.

const ROPE_RADIUS := 0.068
const ROPE_SHADER := preload("res://shaders/rope.gdshader")
const ROPE_COLOR_A := Color("#F8E5C4")
const ROPE_COLOR_B := Color("#C9513A")

var levels: Array[Dictionary] = []
var level_index := 0
var level: Dictionary = {}
var world: KnotWorld
var camera_rig: KnotOrbitCamera
var hud: KnotHud
var sfx: KnotSfx
var rope: KnotRope

var rope_mesh: MeshInstance3D
var rope_shadow: MeshInstance3D
var rope_mat: ShaderMaterial
var tip_marker: Node3D
var aim_root: Node3D
var _aim_inner_mat: StandardMaterial3D
var _aim_outer_mat: StandardMaterial3D
var _debug_root: Node3D

var mode := "draw"
var started := false
var drawing := false
var won := false
var debug := false

var _lmb_down := false
var _cam_drag := false
var _drag_last := Vector2.ZERO
var _rmb_down := false
var _rmb_last := Vector2.ZERO
var _rmb_travel := 0.0
var _pen_lift := 0.0
var _hover_id := ""
var _metrics: Dictionary = {}
var _eval: Dictionary = {"win": false, "checks": [], "goal_ok": false, "goal_distance": 0.0}
var _metrics_acc := 0.0
var _hud_acc := 0.0
var _debug_acc := 0.0
var _hud_last_ms := 0
var _crossings_dirty := false
var _hint_index := 0
var _elapsed := 0.0
var _undo: Dictionary = {}
var _done_states: Dictionary = {}
var _resolved_prev := 0
var _win_time := 0.0
var _capture_mode := false
var _debug_aim := Vector3.INF
var _debug_aim_gold := false
var _quiet := false
var _tick := 0.0


func _ready() -> void:
	levels = KnotLevel.load_all()
	if levels.is_empty():
		push_error("Knotline: no valid levels in res://levels")
		return
	world = KnotWorld.new()
	world.name = "World"
	add_child(world)
	camera_rig = KnotOrbitCamera.new()
	camera_rig.name = "OrbitCamera"
	add_child(camera_rig)
	_build_rope_visuals()
	_build_debug_root()
	sfx = KnotSfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	hud = KnotHud.new()
	hud.name = "Hud"
	add_child(hud)
	_load_level(0)


func _build_rope_visuals() -> void:
	rope_mesh = MeshInstance3D.new()
	rope_mesh.name = "Rope"
	rope_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rope_mat = ShaderMaterial.new()
	rope_mat.shader = ROPE_SHADER
	rope_mat.set_shader_parameter("color_a", ROPE_COLOR_A)
	rope_mat.set_shader_parameter("color_b", ROPE_COLOR_B)
	rope_mat.set_shader_parameter("bands", 12.0)
	rope_mat.set_shader_parameter("twist", 1.35)
	rope_mesh.material_override = rope_mat
	add_child(rope_mesh)

	rope_shadow = MeshInstance3D.new()
	rope_shadow.name = "RopeShadow"
	rope_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rope_shadow.position = Vector3(0.075, 0.014, 0.055)
	rope_shadow.scale = Vector3(1.0, 0.001, 1.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.albedo_color = Color(0.20, 0.13, 0.09, 0.15)
	rope_shadow.material_override = shadow_mat
	add_child(rope_shadow)

	tip_marker = Node3D.new()
	tip_marker.name = "RopeTip"
	add_child(tip_marker)
	var tip_inner := MeshInstance3D.new()
	var tip_mesh := SphereMesh.new()
	tip_mesh.radius = 0.055
	tip_mesh.height = 0.11
	tip_mesh.radial_segments = 10
	tip_mesh.rings = 5
	tip_inner.mesh = tip_mesh
	var tip_mat := StandardMaterial3D.new()
	tip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tip_mat.albedo_color = Color("#FFF5E2")
	tip_inner.material_override = tip_mat
	tip_inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip_marker.add_child(tip_inner)
	tip_marker.visible = false

	aim_root = Node3D.new()
	aim_root.name = "Aim"
	add_child(aim_root)
	_aim_inner_mat = StandardMaterial3D.new()
	_aim_inner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_inner_mat.albedo_color = Color("#FFF6E4")
	_aim_outer_mat = StandardMaterial3D.new()
	_aim_outer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_outer_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_outer_mat.albedo_color = Color(0.4, 0.85, 0.78, 0.38)
	var ai := MeshInstance3D.new()
	var aim_mesh := SphereMesh.new()
	aim_mesh.radius = 0.045
	aim_mesh.height = 0.09
	aim_mesh.radial_segments = 10
	aim_mesh.rings = 5
	ai.mesh = aim_mesh
	ai.material_override = _aim_inner_mat
	ai.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_root.add_child(ai)
	var ao := MeshInstance3D.new()
	var outer_mesh := SphereMesh.new()
	outer_mesh.radius = 0.085
	outer_mesh.height = 0.17
	outer_mesh.radial_segments = 10
	outer_mesh.rings = 5
	ao.mesh = outer_mesh
	ao.material_override = _aim_outer_mat
	ao.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	aim_root.add_child(ao)
	aim_root.visible = false


func _build_debug_root() -> void:
	_debug_root = Node3D.new()
	_debug_root.name = "DebugMarkers"
	_debug_root.visible = false
	add_child(_debug_root)


func _load_level(index: int) -> void:
	if levels.is_empty():
		return
	level_index = clampi(index, 0, levels.size() - 1)
	level = levels[level_index]
	world.build(level)
	rope = KnotRope.new()
	rope.setup(world.start_anchor_visible_position(), KnotLevel.obstacles(level), {
		"ground_y": 0.0,
		"bounds_radius": 4.3,
		"wrap_band": 0.58,
		"crossing_min_delta": 0.12,
	})
	mode = "draw"
	started = false
	drawing = false
	won = false
	_undo = {}
	_done_states.clear()
	_resolved_prev = 0
	_hint_index = 0
	_elapsed = 0.0
	_win_time = 0.0
	_pen_lift = 0.0
	_metrics_acc = 0.0
	_metrics = {}
	_crossings_dirty = false
	_debug_aim = Vector3.INF
	_debug_aim_gold = false
	_hover_id = ""
	if rope_mesh != null:
		rope_mesh.mesh = null
	if rope_shadow != null:
		rope_shadow.mesh = null
	if tip_marker != null:
		tip_marker.visible = false
	if aim_root != null:
		aim_root.visible = false
	if hud != null:
		hud.hide_win()
		hud.set_level(level, level_index, levels.size())
	var cam := KnotLevel.camera_defaults(level)
	camera_rig.setup(float(cam["yaw"]), float(cam["pitch"]), float(cam["distance"]), cam["focus"], true)
	_refresh_metrics(true)
	_rebuild_rope()
	_update_targets(true)
	_update_debug_markers(true)
	_refresh_hud(true)
	if hud != null:
		var prefix := "第 %d 结 · %s" % [level_index + 1, String(level.get("name", ""))]
		hud.toast("%s —— %s" % [prefix, String(level.get("blurb", ""))], 4.2)


func _process(delta: float) -> void:
	_tick += delta
	if rope == null:
		return
	if not _capture_mode:
		_pan_camera(delta)
	if started and not won:
		_elapsed += delta
	# Pen lift while drawing (Shift).
	var lift_target := 0.30 if (drawing and Input.is_key_pressed(KEY_SHIFT)) else 0.0
	_pen_lift = move_toward(_pen_lift, lift_target, delta * 2.6)

	if _undo.has("t"):
		_process_undo(delta)
	elif drawing and mode == "draw" and not won and _lmb_down:
		_sample_pointer()

	if won:
		_win_time += delta
		if _win_time > 0.9:
			camera_rig.orbit(delta * 3.2, 0.0)

	if _crossings_dirty and started and not won:
		_metrics_acc += delta
		if _metrics_acc >= 0.18:
			_metrics_acc = 0.0
			_refresh_metrics(true)
			_update_targets(false)
			_update_debug_markers(false)
			_refresh_hud(false)

	if not _capture_mode:
		_update_pointer_aim()
	else:
		_update_capture_aim()
	_update_tip_marker()

	_hud_acc += delta
	if _hud_acc >= 0.12:
		_hud_acc = 0.0
		_refresh_hud(false)
	_debug_acc += delta
	if debug and _debug_acc >= 0.4:
		_debug_acc = 0.0
		_update_debug_markers(false)


func _pan_camera(delta: float) -> void:
	var mx := 0.0
	var mz := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mz += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mz -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mx += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mx -= 1.0
	if mx == 0.0 and mz == 0.0:
		return
	var speed := 2.3 * (camera_rig.current_distance / 9.0) * delta
	camera_rig.pan(mx * speed, mz * speed)


func _unhandled_input(event: InputEvent) -> void:
	if hud == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		var mouse := get_viewport().get_mouse_position()
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			camera_rig.zoom(0.92)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			camera_rig.zoom(1.08)
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_lmb_down = true
				_drag_last = mouse
				if mode == "camera":
					_cam_drag = true
				else:
					_try_draw_click(mouse)
			else:
				_lmb_down = false
				_drawing_stop()
				_cam_drag = false
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				_rmb_down = true
				_rmb_last = mouse
				_rmb_travel = 0.0
			else:
				if _rmb_down and _rmb_travel < 5.0:
					_finish_stroke()
				_rmb_down = false
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var mouse := get_viewport().get_mouse_position()
		if _rmb_down:
			var d := mouse - _rmb_last
			_rmb_travel += d.length()
			if d.length() > 0.05:
				camera_rig.orbit(-d.x * 0.28, -d.y * 0.22)
				_rmb_last = mouse
			get_viewport().set_input_as_handled()
			return
		if _cam_drag and mode == "camera":
			var d2 := mouse - _drag_last
			if d2.length() > 0.05:
				camera_rig.orbit(-d2.x * 0.28, -d2.y * 0.22)
				_drag_last = mouse
			get_viewport().set_input_as_handled()
			return
	elif event is InputEventKey:
		var k := event as InputEventKey
		if not k.pressed or k.echo:
			return
		match k.keycode:
			KEY_TAB:
				_toggle_mode()
			KEY_Z:
				_do_undo()
			KEY_R:
				_reset_level()
			KEY_SPACE:
				_finish_stroke()
			KEY_ESCAPE:
				_cancel_stroke()
			KEY_H:
				_cycle_hint()
			KEY_F1:
				_toggle_debug()
			KEY_M:
				if sfx != null:
					var mute := sfx.toggle_mute()
					hud.toast("音效已" + ("关闭" if mute else "打开"), 1.4)
			KEY_ENTER, KEY_KP_ENTER:
				if won:
					_load_level((level_index + 1) % levels.size())
			_:
				if k.keycode >= KEY_1 and k.keycode < KEY_1 + levels.size():
					_load_level(k.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _toggle_mode() -> void:
	if won:
		return
	mode = "camera" if mode == "draw" else "draw"
	_drawing_stop()
	_cam_drag = false
	hud.toast("镜头模式 · 左键拖动旋转" if mode == "camera" else "绘制模式 · 左键画线", 1.6)
	_refresh_hud(true)
	_update_pointer_aim()


func _drawing_stop() -> void:
	drawing = false


func _try_draw_click(mouse: Vector2) -> void:
	if won or _undo.has("t"):
		return
	if not started:
		if _near_start(mouse):
			_start_stroke(mouse)
		else:
			if not _quiet:
				hud.toast("先从发光的「起点」按住左键开始", 2.4)
			if sfx != null:
				sfx.error()
		return
	if _near_tip(mouse):
		drawing = true
		_sample_pointer_at(mouse)
		if sfx != null:
			sfx.click()
	else:
		if not _quiet:
			hud.toast("从绳头的白色小球继续；按 R 可以重来", 2.2)
		if sfx != null:
			sfx.error()


func _start_stroke(mouse: Vector2) -> void:
	started = true
	drawing = true
	_elapsed = 0.0
	_done_states.clear()
	_resolved_prev = 0
	if sfx != null:
		sfx.start_stroke()
	_sample_pointer_at(mouse)
	if not _quiet:
		hud.toast("一笔开始 · 绕柱画圈，右键拖动可转镜头", 2.6)
	_refresh_hud(true)


func _near_start(mouse: Vector2) -> bool:
	var p := world.start_anchor_visible_position()
	if camera_rig.is_behind(p):
		return false
	return camera_rig.screen_position(p).distance_to(mouse) <= 58.0


func _near_tip(mouse: Vector2) -> bool:
	if not started:
		return false
	var p := rope.last_point()
	if camera_rig.is_behind(p):
		return false
	return camera_rig.screen_position(p).distance_to(mouse) <= 58.0


func _sample_pointer() -> void:
	_sample_pointer_at(get_viewport().get_mouse_position())


func _sample_pointer_at(mouse: Vector2) -> void:
	if not started or rope == null:
		return
	var info := _pointer_draw_point(mouse)
	if not info["valid"]:
		return
	var p: Vector3 = info["point"]
	if p.distance_to(rope.last_point()) < rope.min_step:
		return
	var added := rope.add_point(p)
	if added <= 0:
		if rope.points.size() >= rope.max_points and not _quiet:
			hud.toast("绳子已经很长了，收笔或撤销吧", 1.6)
		return
	_refresh_metrics(false)
	_crossings_dirty = true
	_metrics_acc = 0.0
	_rebuild_rope()
	_update_targets(false)
	_refresh_hud(false)


func _pointer_draw_point(mouse: Vector2) -> Dictionary:
	var origin := camera_rig.ray_origin(mouse)
	var dir := camera_rig.ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 80.0, 1)
	query.hit_from_inside = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var point := Vector3.ZERO
	var valid := true
	var surface := false
	var normal := Vector3.UP
	var pillar_id := ""
	if not hit.is_empty():
		point = hit["position"]
		normal = hit["normal"]
		surface = true
		var collider = hit["collider"]
		if collider != null and collider.has_meta("pillar_id"):
			pillar_id = String(collider.get_meta("pillar_id"))
	else:
		var ref := rope.last_point()
		if not started:
			ref = world.start_anchor_visible_position()
		var fwd := camera_rig.camera_forward()
		var denom := fwd.dot(dir)
		if absf(denom) > 0.0001:
			var t := (fwd.dot(ref) - fwd.dot(origin)) / denom
			if t > 0.0:
				point = origin + dir * t
			else:
				point = ref
		else:
			point = ref
		if point.distance_to(ref) > 3.1:
			point = ref + (point - ref).normalized() * 3.1
		point.y = clampf(point.y, 0.10, 3.6)
		if not started:
			valid = _near_start(mouse)
	var flat := Vector2(point.x, point.z)
	if flat.length() > 4.25:
		flat = flat.normalized() * 4.25
		point.x = flat.x
		point.z = flat.y
	point.y += _pen_lift
	point.y = clampf(point.y, 0.09, 3.75)
	if surface:
		point += normal * 0.018
	return {
		"valid": valid,
		"point": point,
		"surface": surface,
		"normal": normal,
		"pillar_id": pillar_id,
	}


func _update_pointer_aim() -> void:
	if aim_root == null or world == null:
		return
	if mode != "draw" or won or _undo.has("t"):
		aim_root.visible = false
		_clear_hover()
		return
	var mouse := get_viewport().get_mouse_position()
	if not started:
		if _near_start(mouse):
			aim_root.visible = true
			aim_root.position = world.start_anchor_visible_position()
			_set_aim_tint(true)
		else:
			aim_root.visible = false
		_clear_hover()
		return
	var info := _pointer_draw_point(mouse)
	var id := String(info.get("pillar_id", ""))
	if id != "":
		if _hover_id != id:
			_clear_hover()
			world.set_pillar_hover(id, true)
			_hover_id = id
	else:
		_clear_hover()
	if drawing:
		aim_root.visible = false
	else:
		aim_root.visible = true
		aim_root.position = info["point"]
		_set_aim_tint(_near_tip(mouse))


func _update_capture_aim() -> void:
	if aim_root == null:
		return
	if _debug_aim == Vector3.INF or mode != "draw":
		aim_root.visible = false
		return
	aim_root.visible = true
	aim_root.position = _debug_aim
	_set_aim_tint(_debug_aim_gold)


func _set_aim_tint(gold: bool) -> void:
	if _aim_inner_mat == null:
		return
	_aim_inner_mat.albedo_color = Color("#FFF6E4") if not gold else Color("#FFE2A6")
	_aim_outer_mat.albedo_color = Color(0.4, 0.85, 0.78, 0.38) if not gold else Color(1.0, 0.75, 0.35, 0.5)


func _clear_hover() -> void:
	if _hover_id != "" and world != null:
		world.set_pillar_hover(_hover_id, false)
		_hover_id = ""


func _update_tip_marker() -> void:
	if tip_marker == null or rope == null:
		return
	var show_tip := started and not won and not _undo.has("t") and rope.points.size() > 1
	tip_marker.visible = show_tip
	if show_tip:
		tip_marker.position = rope.last_point()
		var s := 1.0 + sin(_tick * 3.4) * 0.08
		tip_marker.scale = Vector3(s, s, s)


func _finish_stroke() -> void:
	if not started or rope == null:
		if hud != null and not _quiet:
			hud.toast("先画一条线，再收笔", 1.8)
		return
	if _undo.has("t"):
		return
	_refresh_metrics(true)
	_update_targets(false)
	_refresh_hud(true)
	if bool(_eval.get("win", false)):
		_win()
	else:
		if sfx != null:
			sfx.error()
		if not _quiet:
			var missing := ""
			for c in _eval.get("checks", []):
				if not bool(c.get("ok", false)) and not bool(c.get("optional", false)):
					missing = String(c.get("text", ""))
					break
			hud.toast("还没结成：%s。线还在，可以继续画。" % missing, 3.0)


func _win() -> void:
	if won:
		return
	won = true
	drawing = false
	_win_time = 0.0
	if sfx != null:
		sfx.win()
	world.celebrate()
	_update_targets(false)
	var stats_line := "节点 %d · 绳长 %.1f m · 用时 %s" % [rope.step_count(), rope.length(), _format_time(_elapsed)]
	var is_last := level_index == levels.size() - 1
	hud.show_win({
		"level_line": "第 %d 结 · %s" % [level_index + 1, String(level.get("name", ""))],
		"stats_line": stats_line,
		"footer": "回车 · 再玩一遍      R · 重玩本结" if is_last else "回车 · 下一关      R · 重玩本结",
		"last": is_last,
	})
	if aim_root != null:
		aim_root.visible = false
	if tip_marker != null:
		tip_marker.visible = false


func _do_undo() -> void:
	if rope == null or won:
		return
	if _undo.has("t"):
		return
	if drawing:
		if hud != null:
			hud.toast("先松开左键，再撤销", 1.4)
		return
	var info := rope.undo_info()
	if info.is_empty():
		if hud != null:
			hud.toast("已经回到起点了", 1.4)
		return
	_undo = {
		"t": 0.0,
		"dur": 0.20,
		"info": info,
	}
	if sfx != null:
		sfx.undo()
	_process_undo(0.0)


func _process_undo(delta: float) -> void:
	if not _undo.has("t"):
		return
	var t: float = float(_undo["t"]) + delta / float(_undo["dur"])
	_undo["t"] = minf(1.0, t)
	var info: Dictionary = _undo["info"]
	var keep: int = int(info["keep_count"])
	var base: PackedVector3Array = rope.points.slice(0, keep)
	var from: Vector3 = info["last_point"]
	var to: Vector3 = info["target_point"]
	var k := ease(clampf(t, 0.0, 1.0), 0.45)
	var visible_points := base.duplicate()
	visible_points.append(from.lerp(to, k))
	_rebuild_rope_view(visible_points)
	tip_marker.visible = true
	if tip_marker.visible:
		tip_marker.position = from.lerp(to, k)
		tip_marker.scale = Vector3.ONE
	if t >= 1.0:
		_undo = {}
		rope.undo_last_control()
		_refresh_metrics(true)
		_rebuild_rope()
		_update_targets(false)
		_update_debug_markers(true)
		_refresh_hud(true)
		if started and rope.points.size() <= 1:
			started = false
			drawing = false
			_elapsed = 0.0


func _cancel_stroke() -> void:
	if rope == null:
		return
	if not started and rope.points.size() <= 1:
		return
	rope.reset()
	started = false
	drawing = false
	won = false
	_undo = {}
	_elapsed = 0.0
	_done_states.clear()
	_resolved_prev = 0
	_pen_lift = 0.0
	if hud != null:
		hud.hide_win()
		hud.toast("这一笔收回起点", 1.6)
	_refresh_metrics(true)
	_rebuild_rope()
	_update_targets(true)
	_update_debug_markers(true)
	_refresh_hud(true)


func _reset_level() -> void:
	if levels.is_empty():
		return
	var idx := level_index
	_load_level(idx)
	if hud != null and not _quiet:
		hud.toast("本结已重置", 1.4)


func _cycle_hint() -> void:
	if level.is_empty() or hud == null:
		return
	var hints: Array = level.get("hints", [])
	if hints.is_empty():
		return
	_hint_index = (_hint_index + 1) % hints.size()
	hud.toast(String(hints[_hint_index]), 4.5)


func _toggle_debug() -> void:
	debug = not debug
	_debug_root.visible = debug
	if hud != null:
		hud.set_debug_visible(debug)
	_update_debug_markers(true)
	_refresh_hud(true)


func _refresh_metrics(full: bool) -> void:
	if rope == null or world == null:
		return
	if full:
		_metrics = rope.analyze(world.pillars, 3)
		_crossings_dirty = false
		var resolved := int(_metrics.get("resolved_crossings", 0))
		if resolved > _resolved_prev and started and not won and not _quiet:
			if sfx != null:
				sfx.crossing()
			hud.toast("自交 · 两股绳子分出上下了", 1.8)
		_resolved_prev = resolved
	else:
		var samples := rope.sample(2)
		var winding := rope.compute_winding(samples, world.pillars)
		_metrics["samples"] = samples
		_metrics["winding"] = winding
		_metrics["steps"] = rope.step_count()
		_metrics["length"] = rope.length()
		if not _metrics.has("crossings"):
			_metrics["crossings"] = []
		if not _metrics.has("resolved_crossings"):
			_metrics["resolved_crossings"] = 0
		if not _metrics.has("flat_crossings"):
			_metrics["flat_crossings"] = 0
	_eval = KnotLevel.evaluate(level, _metrics, rope.last_point())


func _update_targets(force: bool) -> void:
	if world == null or rope == null:
		return
	var resolved := int(_metrics.get("resolved_crossings", 0))
	for c in _eval.get("checks", []):
		if String(c.get("kind", "")) != "wrap":
			continue
		var key := String(c.get("key", ""))
		var id := key.substr(5)
		var done := bool(c.get("ok", false))
		var prev := bool(_done_states.get(id, false))
		world.set_pillar_done(id, done, not _quiet)
		_done_states[id] = done
		if done and not prev and started and not _quiet:
			if sfx != null:
				sfx.wrap_done()
			var pillar_name := id
			for p in world.pillars:
				if p["id"] == id:
					pillar_name = p["name"]
					break
			if bool(c.get("optional", false)):
				world.play_bell(id)
				hud.toast("「%s」响了 · 额外达成" % pillar_name, 2.0)
			else:
				hud.toast("「%s」绕满一圈" % pillar_name, 1.6)
	if force:
		pass
	_resolved_prev = resolved


func _rebuild_rope() -> void:
	if rope == null:
		return
	_rebuild_rope_view(rope.points)


func _rebuild_rope_view(points: PackedVector3Array) -> void:
	if rope_mesh == null:
		return
	if points.size() < 2:
		rope_mesh.mesh = null
		if rope_shadow != null:
			rope_shadow.mesh = null
		return
	var mesh := KnotTube.build_from_controls(points, ROPE_RADIUS, 10, 3)
	rope_mesh.mesh = mesh
	if rope_shadow != null:
		rope_shadow.mesh = mesh
	var l := KnotTube.polyline_length(points)
	rope_mat.set_shader_parameter("bands", clampf(l / 0.24, 6.0, 110.0))


func _refresh_hud(force: bool) -> void:
	if hud == null or rope == null:
		return
	var now := Time.get_ticks_msec()
	if not force and now - _hud_last_ms < 90:
		return
	_hud_last_ms = now
	var state := {
		"mode": mode,
		"drawing": drawing,
		"started": started,
		"won": won,
		"steps": rope.step_count(),
		"length": rope.length(),
		"time_str": _format_time(_elapsed),
		"fps": Engine.get_frames_per_second(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"segments": _metrics.get("samples", PackedVector3Array()).size(),
		"checks": _eval.get("checks", []),
		"hint": _context_hint(),
		"debug": debug,
		"debug_text": _debug_text(),
		"capture": _capture_mode,
	}
	hud.refresh(state)


func _context_hint() -> String:
	if won:
		return "结成了！回车继续，R 重玩本结。"
	if levels.is_empty():
		return ""
	if not started:
		return "从发光的「起点」按住左键，开始这一笔；右键拖动可先转镜头。"
	if _undo.has("t"):
		return "正在收回最后一笔…"
	var missing := _missing_step_hint()
	if mode == "camera":
		var tail := "" if missing == "" else " 还差：" + missing
		return "镜头模式 · 左键拖动旋转 · WASD 平移 · Tab 回绘制。" + tail
	if bool(_eval.get("win", false)):
		return "目标都达成 · 按 Space 或右键单击收笔，结成！"
	var prefix := "" if drawing else "继续：从绳头白色小球按住左键。"
	return prefix + missing


func _missing_step_hint() -> String:
	for c in _eval.get("checks", []):
		if bool(c.get("ok", false)) or bool(c.get("optional", false)):
			continue
		var kind := String(c.get("kind", ""))
		if kind == "wrap":
			var id := String(c.get("key", "")).substr(5)
			var w: Dictionary = _metrics.get("winding", {}).get(id, {})
			var angle := float(w.get("angle_deg", 0.0))
			var nm := id
			var need := 360
			for p in world.pillars:
				if p["id"] == id:
					nm = p["name"]
					need = int(round(float(p["turns"]) * 360.0))
					break
			return "绕住「%s」还差：%.0f° / %d°（绕到背面时按住右键转镜头）。" % [nm, angle, need]
		if kind == "crossing":
			if int(_metrics.get("flat_crossings", 0)) > 0:
				return "交叉处上下还没分开：按住 Shift 抬笔，让这一股从上面跨过去。"
			return "还差一次自交上下：把线绕回来跨过自己，Shift 抬笔更清楚。"
		if kind == "goal":
			return "把绳头拖到发光的「结台」。"
	return "继续把线画完。"


func _debug_text() -> String:
	if not debug or world == null:
		return ""
	var lines: Array[String] = []
	lines.append("[color=#F2C879]DEBUG · F1 关闭[/color]")
	lines.append("模式 %s · %s" % [mode, "画线中" if drawing else ("已收笔" if won else "待继续")])
	lines.append("控制点 %d · 采样 %d · 长 %.2f m" % [rope.points.size(), _metrics.get("samples", PackedVector3Array()).size(), rope.length()])
	lines.append("结台距离 %.2f m · 用时 %s" % [float(_eval.get("goal_distance", 0.0)), _format_time(_elapsed)])
	lines.append("[color=#8FD3C7]绕柱 winding（带符号）[/color]")
	var winding: Dictionary = _metrics.get("winding", {})
	for p in world.pillars:
		var id := String(p["id"])
		var w: Dictionary = winding.get(id, {})
		var deg := float(w.get("signed_deg", 0.0))
		var turns := float(w.get("turns", 0.0))
		var ok := absf(turns) >= float(p["turns"]) - 0.035
		lines.append(" %s  %+.0f°  %.2f 圈  %s" % [p["name"], deg, turns, "✓" if ok else ""])
	lines.append("自交 有效 %d / 平交 %d" % [int(_metrics.get("resolved_crossings", 0)), int(_metrics.get("flat_crossings", 0))])
	lines.append("交点 青=上 橙=下 灰=平")
	if _capture_mode:
		lines.append("截图模式 1920×1080 · 实时 FPS 不采样")
	else:
		lines.append("FPS %d · Draw %d" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))])
	lines.append("相机 yaw %.0f pitch %.0f dist %.1f" % [camera_rig.current_yaw, camera_rig.current_pitch, camera_rig.current_distance])
	return "\n".join(lines)


func _update_debug_markers(force: bool) -> void:
	if _debug_root == null:
		return
	for c in _debug_root.get_children():
		_debug_root.remove_child(c)
		c.queue_free()
	if not debug or rope == null:
		return
	var samples: PackedVector3Array = _metrics.get("samples", rope.sample(3))
	if samples.size() > 1:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p in samples:
			im.surface_add_vertex(p)
		im.surface_end()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("#7CF0C9")
		mat.no_depth_test = true
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_debug_root.add_child(mi)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	sphere.radial_segments = 6
	sphere.rings = 3
	mm.mesh = sphere
	var count := 0
	for i in range(0, samples.size(), 8):
		count += 1
	mm.instance_count = count
	var gi := 0
	for i in range(0, samples.size(), 8):
		mm.set_instance_transform(gi, Transform3D(Basis(), samples[i]))
		gi += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color("#FFE1A1")
	pmat.no_depth_test = true
	mmi.material_override = pmat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_root.add_child(mmi)
	var crossings: Array = _metrics.get("crossings", [])
	var order: Array[int] = []
	for i in crossings.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return float(crossings[a]["delta"]) > float(crossings[b]["delta"]))
	var picked: Array[int] = []
	for i in mini(3, order.size()):
		picked.append(order[i])
	var primary := -1
	for i in picked.size():
		if bool(crossings[picked[i]].get("resolved", false)):
			primary = picked[i]
			break
	for idx in picked:
		var c: Dictionary = crossings[idx]
		var above: Vector3 = c["above"]
		var below: Vector3 = c["below"]
		var resolved := bool(c.get("resolved", false))
		_add_debug_ball(above, Color("#6BE3C8") if resolved else Color("#9A948A"), 0.05)
		_add_debug_ball(below, Color("#FF8D6B") if resolved else Color("#6F6860"), 0.05)
		var im2 := ImmediateMesh.new()
		im2.surface_begin(Mesh.PRIMITIVE_LINES)
		im2.surface_add_vertex(below)
		im2.surface_add_vertex(above)
		im2.surface_end()
		var line := MeshInstance3D.new()
		line.mesh = im2
		var lm := StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(0.85, 0.78, 0.66, 0.7)
		lm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		lm.no_depth_test = true
		line.material_override = lm
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_debug_root.add_child(line)
		if idx == primary:
			_add_debug_label(above + Vector3(0.0, 0.18, 0.0), "上", Color("#8DF5D8"), true)
			_add_debug_label(below + Vector3(0.0, -0.16, 0.0), "下", Color("#FFA98E"), true)
		elif not resolved:
			_add_debug_label((above + below) * 0.5 + Vector3(0.0, 0.10, 0.0), "平", Color("#C9C0B0"), false)


func _add_debug_label(pos: Vector3, text: String, color: Color, big: bool = false) -> void:
	var l3 := Label3D.new()
	l3.text = text
	l3.position = pos
	l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l3.font_size = 44 if big else 30
	l3.pixel_size = 0.0032 if big else 0.0024
	l3.modulate = color
	l3.outline_size = 7 if big else 5
	l3.outline_modulate = Color(0.12, 0.1, 0.08, 0.85)
	l3.no_depth_test = true
	l3.font = KnotFont.ui_font()
	_debug_root.add_child(l3)


func _add_debug_ball(pos: Vector3, color: Color, radius: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.no_depth_test = true
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debug_root.add_child(mi)


func _format_time(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	return "%02d:%02d" % [s / 60, s % 60]


# ---------------------------------------------------------------------------
# Debug / capture hooks (used only by tools, never by gameplay input).
# ---------------------------------------------------------------------------

func debug_load_level(index: int) -> void:
	_quiet = true
	_load_level(index)
	_quiet = false


func debug_set_capture_mode(on: bool) -> void:
	_capture_mode = on
	if on and aim_root != null:
		aim_root.visible = false


func debug_hide_hud(hidden: bool) -> void:
	if hud != null:
		hud.visible = not hidden


func debug_clear_toast() -> void:
	if hud != null:
		hud.toast_panel.visible = false
		hud.toast_panel.modulate.a = 0.0


func debug_set_camera(yaw: float, pitch: float, distance: float, focus: Vector3) -> void:
	camera_rig.setup(yaw, pitch, distance, focus, true)


func debug_set_mode(new_mode: String) -> void:
	mode = new_mode
	_refresh_hud(true)


func debug_set_path(points: Array, finish: bool = false) -> bool:
	_quiet = true
	rope.reset()
	started = false
	drawing = false
	won = false
	_undo = {}
	_done_states.clear()
	_resolved_prev = 0
	_elapsed = 0.0
	if hud != null:
		hud.hide_win()
	for p in points:
		if typeof(p) == TYPE_VECTOR3:
			if not started:
				started = true
			rope.add_point(p)
	drawing = false
	_refresh_metrics(true)
	_rebuild_rope()
	_update_targets(false)
	_update_debug_markers(true)
	_refresh_hud(true)
	if finish:
		_finish_stroke()
	_quiet = false
	return bool(_eval.get("win", false))


func debug_begin_path() -> void:
	_quiet = true
	rope.reset()
	started = false
	drawing = false
	won = false
	_undo = {}
	_done_states.clear()
	_resolved_prev = 0
	_elapsed = 0.0
	if hud != null:
		hud.hide_win()
	_refresh_metrics(true)
	_rebuild_rope()
	_refresh_hud(true)
	_quiet = false


func debug_append_point(p: Vector3) -> void:
	_quiet = true
	if not started:
		started = true
	rope.add_point(p)
	_refresh_metrics(false)
	_crossings_dirty = true
	_rebuild_rope()
	_update_targets(false)
	_refresh_hud(false)
	_quiet = false


func debug_finish_path() -> bool:
	_quiet = true
	_finish_stroke()
	_quiet = false
	return won


func debug_set_aim(p: Vector3, gold: bool = false) -> void:
	_debug_aim = p
	_debug_aim_gold = gold
	if aim_root != null:
		aim_root.visible = true
		aim_root.position = p
		_set_aim_tint(gold)


func debug_clear_aim() -> void:
	_debug_aim = Vector3.INF
	if aim_root != null:
		aim_root.visible = false


func debug_set_hover(id: String) -> void:
	if id == "":
		_clear_hover()
		return
	if _hover_id != id:
		_clear_hover()
		world.set_pillar_hover(id, true)
		_hover_id = id


func debug_clear_hover() -> void:
	_clear_hover()


func debug_set_debug(on: bool) -> void:
	debug = on
	_debug_root.visible = on
	hud.set_debug_visible(on)
	_update_debug_markers(true)
	_refresh_hud(true)


func debug_set_elapsed(seconds: float) -> void:
	_elapsed = seconds
	_refresh_hud(true)


func debug_screen_click(mouse: Vector2) -> void:
	_try_draw_click(mouse)


func debug_screen_drag(mouse: Vector2) -> void:
	if started:
		_sample_pointer_at(mouse)


func debug_undo() -> void:
	_do_undo()


func debug_refresh() -> void:
	_refresh_metrics(true)
	_update_targets(false)
	_update_debug_markers(true)
	_refresh_hud(true)


func debug_state() -> Dictionary:
	return {
		"level": level_index,
		"steps": rope.step_count() if rope != null else 0,
		"points": rope.points.size() if rope != null else 0,
		"length": rope.length() if rope != null else 0.0,
		"winding": _metrics.get("winding", {}),
		"resolved_crossings": _metrics.get("resolved_crossings", 0),
		"flat_crossings": _metrics.get("flat_crossings", 0),
		"goal_distance": _eval.get("goal_distance", 0.0),
		"checks": _eval.get("checks", []),
		"win": bool(_eval.get("win", false)),
		"won": won,
		"fps": Engine.get_frames_per_second(),
		"draw_calls": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"segments": _metrics.get("samples", PackedVector3Array()).size(),
	}
