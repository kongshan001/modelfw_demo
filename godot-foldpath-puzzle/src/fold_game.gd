class_name FoldGame
extends Node3D

## Foldpath controller. Owns level state, screen-space fold links, the walk
## graph, platform rotation, undo/hints, HUD wiring and debug hooks.

const FOOT := Vector3(0.0, 0.042, 0.0)
const NODE_CLICK_PX := 27.0
const DRAG_START_PX := 4.0
const WALK_SPEED := 2.7
const LINK_TIME := 0.58

var levels: Array[Dictionary] = []
var level_index := 0
var level: Dictionary = {}
var angles: Dictionary = {}
var current_node := ""
var goal_node := ""

var cam: FoldCamera
var world: FoldWorld
var player: FoldPlayer
var hud: FoldHud

var links: Array[Dictionary] = []
var screen_nodes: Dictionary = {}
var node_depths: Dictionary = {}
var open_nodes: Array[String] = []
var selected_platform := ""
var hover_node := ""
var hover_platform := ""

var moving := false
var rotating := false
var win := false
var debug := false
var capture_mode := false
var elapsed := 0.0
var win_elapsed := 0.0
var moves := 0
var rotations := 0

var actions: Array[Dictionary] = []
var hint_index := 0
var hint_focus := ""
var hint_nodes: Array[String] = []
var hint_until := -1.0

var _walk_steps: Array[Dictionary] = []
var _walk_index := 0
var _walk_t := 0.0
var _walk_dur := 0.5
var _walk_from := Vector3.ZERO
var _walk_to := Vector3.ZERO
var _walk_dir := Vector3.ZERO
var _move_origin := ""
var _move_target := ""
var _last_yaw := 0.0
var _rot: Dictionary = {}
var _drag: Dictionary = {}
var _press_node := ""
var _press_platform := ""
var _press_screen := Vector2.ZERO
var _mouse_design := Vector2.ZERO
var _cursor_hand := false
var _links_before_rotate: Array[String] = []
var _just_walked_link := false


func _ready() -> void:
	var all_levels := FoldLevel.load_all()
	levels.clear()
	for lvl in all_levels:
		var err := FoldLevel.validate(lvl)
		if err == "":
			levels.append(lvl)
		else:
			push_error("Foldpath: invalid level %s: %s" % [String(lvl.get("id", "?")), err])
	if levels.is_empty():
		push_error("Foldpath: no valid levels in res://levels")
		return
	cam = FoldCamera.new()
	cam.name = "FoldCamera"
	add_child(cam)
	world = FoldWorld.new()
	world.name = "World"
	add_child(world)
	player = FoldPlayer.new()
	player.name = "Player"
	add_child(player)
	hud = FoldHud.new()
	hud.name = "Hud"
	add_child(hud)
	hud.game = self
	load_level(0)


func load_level(index: int) -> void:
	if levels.is_empty():
		return
	level_index = posmod(index, levels.size())
	level = levels[level_index]
	angles = FoldLevel.initial_angles(level)
	open_nodes.clear()
	for cand in FoldLevel.link_candidates(level):
		open_nodes.append(String(cand["id"]))
	current_node = String(level["start"])
	goal_node = String(level["goal"])
	actions.clear()
	links.clear()
	_walk_steps.clear()
	_walk_index = 0
	_rot.clear()
	_drag.clear()
	moving = false
	rotating = false
	win = false
	debug = debug
	elapsed = 0.0
	win_elapsed = 0.0
	moves = 0
	rotations = 0
	hint_index = 0
	hint_focus = ""
	hint_nodes.clear()
	hint_until = -1.0
	_press_node = ""
	_press_platform = ""
	hover_node = ""
	hover_platform = ""
	_just_walked_link = false
	selected_platform = _first_rotatable()
	cam.configure(level)
	world.build(level, cam.focus, cam.base_size)
	world.apply_angles(angles)
	_last_yaw = _initial_face()
	_refresh_links()
	_update_screen_nodes()
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	if hud != null:
		hud.set_level(level, level_index, levels)
		hud.hide_win()
		hud.set_hint("")
		hud.set_debug(debug)
		hud.clear_toast()
		if capture_mode:
			hud.toast("", 0.1)
		else:
			hud.toast("点击发光的路径节点，让小折狐出发。", 2.4)
	_update_hover()


func _first_rotatable() -> String:
	for p in level.get("platforms", []):
		if bool(p.get("rotatable", false)):
			return String(p["id"])
	return ""


func _platform(pid: String) -> Dictionary:
	var platforms := FoldLevel.platform_map(level)
	return platforms.get(pid, {})


func _is_rotatable(pid: String) -> bool:
	var p := _platform(pid)
	return bool(p.get("rotatable", false))


func _step_degrees(pid: String) -> float:
	var p := _platform(pid)
	return float(p.get("step", 15.0))


func _node_pos(nid: String) -> Vector3:
	var w := FoldLevel.node_world(level, angles, nid)
	return w


func _initial_face() -> float:
	var nodes := FoldLevel.node_map(level)
	if not nodes.has(current_node):
		return 0.0
	for e in level.get("edges", []):
		var a := String(e[0])
		var b := String(e[1])
		if a == current_node or b == current_node:
			var other := b if a == current_node else a
			var dir := _node_pos(other) - _node_pos(current_node)
			if dir.length_squared() > 0.0001:
				return atan2(-dir.x, -dir.z)
	return 0.0


func _process(delta: float) -> void:
	if level.is_empty():
		return
	if not win:
		elapsed += delta
	_tick_rotation(delta)
	_tick_walk(delta)
	_refresh_links()
	_update_screen_nodes()
	if not moving:
		if win:
			player.celebrate()
		else:
			player.idle(_node_pos(current_node) + FOOT, _last_yaw)
	world.tick(delta)
	_update_hover()
	if hud != null:
		hud.update_hud(delta)


func _refresh_links() -> void:
	if level.is_empty():
		return
	links = FoldLevel.active_links(level, angles, cam.focus, cam.effective_size())


func _update_screen_nodes() -> void:
	screen_nodes.clear()
	node_depths.clear()
	if level.is_empty():
		return
	var world_nodes := FoldLevel.all_world(level, angles)
	for nid in world_nodes.keys():
		var p: Vector3 = world_nodes[nid]
		screen_nodes[nid] = cam.screen_of(p)
		node_depths[nid] = cam.depth_of(p)


func _link_keys() -> Array[String]:
	var out: Array[String] = []
	for link in links:
		var a := String(link["a"])
		var b := String(link["b"])
		if a < b:
			out.append(a + "+" + b)
		else:
			out.append(b + "+" + a)
	return out


func _link_for(a: String, b: String) -> Dictionary:
	return FoldLevel.link_for(links, a, b)


# ---------------------------------------------------------------- movement

func request_move(to_id: String) -> bool:
	if level.is_empty() or win:
		return false
	if moving:
		hud.toast("小折狐还在走路。", 1.4)
		return false
	if rotating:
		hud.toast("等纸桥停稳再走。", 1.4)
		return false
	if not FoldLevel.node_map(level).has(to_id):
		return false
	if to_id == current_node:
		hud.toast("小折狐已经在这里了。", 1.2)
		return false
	_refresh_links()
	var route := FoldLevel.find_route(level, current_node, to_id, links)
	if route.size() < 2:
		hud.toast("现在走不到那里——先旋转纸桥，让折环对齐。", 2.4)
		return false
	_walk_steps.clear()
	for i in range(1, route.size()):
		var a := route[i - 1]
		var b := route[i]
		var link := _link_for(a, b)
		_walk_steps.append({"a": a, "b": b, "link": not link.is_empty()})
	_walk_index = 0
	_walk_t = 0.0
	_move_origin = current_node
	_move_target = to_id
	_just_walked_link = false
	moving = true
	_begin_step()
	_update_hover()
	return true


func _begin_step() -> void:
	if _walk_index >= _walk_steps.size():
		_finish_walk()
		return
	var step: Dictionary = _walk_steps[_walk_index]
	var a := String(step["a"])
	var b := String(step["b"])
	_walk_from = _node_pos(a) + FOOT
	_walk_to = _node_pos(b) + FOOT
	_walk_dir = _walk_to - _walk_from
	_walk_t = 0.0
	var is_link := bool(step["link"])
	if is_link:
		_walk_dur = LINK_TIME
		_just_walked_link = true
		var mid := cam.screen_of((_walk_from + _walk_to) * 0.5)
		if hud != null:
			hud.pulse_fold(mid)
	else:
		_walk_dur = clampf(_walk_dir.length() / WALK_SPEED, 0.28, 1.05)


func _tick_walk(delta: float) -> void:
	if not moving or _walk_index >= _walk_steps.size():
		return
	_walk_t += delta / maxf(0.05, _walk_dur)
	var t := clampf(_walk_t, 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var pos := _walk_from.lerp(_walk_to, e)
	var step: Dictionary = _walk_steps[_walk_index]
	var is_link := bool(step["link"])
	if is_link:
		player.fold(pos, _last_yaw, t)
	else:
		player.walk(pos, _walk_dir)
	if t >= 1.0:
		current_node = String(step["b"])
		if not is_link and _walk_dir.length_squared() > 0.0001:
			_last_yaw = atan2(-_walk_dir.x, -_walk_dir.z)
		_walk_index += 1
		if _walk_index >= _walk_steps.size():
			_finish_walk()
		else:
			_begin_step()


func _finish_walk() -> void:
	if not moving:
		return
	moving = false
	actions.append({"type": "move", "from": _move_origin, "to": current_node})
	moves += 1
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	_refresh_links()
	_update_screen_nodes()
	if current_node == goal_node:
		_win()
	elif _just_walked_link:
		hud.toast("折过来了。", 1.2)
	_just_walked_link = false
	_update_hover()


func finish_walk_now() -> void:
	if not moving:
		return
	_walk_index = _walk_steps.size()
	current_node = String(_walk_steps[_walk_steps.size() - 1]["b"])
	moving = false
	actions.append({"type": "move", "from": _move_origin, "to": current_node})
	moves += 1
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	_refresh_links()
	_update_screen_nodes()
	if current_node == goal_node:
		_win()
	_update_hover()


# ---------------------------------------------------------------- rotation

func select_platform(pid: String) -> void:
	if pid == "":
		return
	selected_platform = pid
	_update_hover()


func rotate_selected(dir: int) -> void:
	if level.is_empty() or win or moving or rotating:
		return
	var pid := selected_platform
	if pid == "" or not _is_rotatable(pid):
		pid = _first_rotatable()
	if pid == "":
		hud.toast("这一关没有可旋转的纸桥。", 1.8)
		return
	selected_platform = pid
	var step := _step_degrees(pid)
	var from := float(angles.get(pid, 0.0))
	var target := FoldMath.snap_angle(from + float(dir) * step, step)
	_begin_rotate(pid, target, 0.2, true, from)


func _begin_rotate(pid: String, target: float, duration: float, record: bool, action_from: float) -> void:
	if pid == "" or moving or win:
		return
	_links_before_rotate = _link_keys()
	_rot = {
		"pid": pid,
		"from": float(angles.get(pid, 0.0)),
		"to": target,
		"t": 0.0,
		"dur": maxf(0.05, duration),
		"record": record,
		"action_from": action_from
	}
	rotating = true
	selected_platform = pid


func _tick_rotation(delta: float) -> void:
	if _rot.is_empty():
		return
	_rot["t"] = float(_rot["t"]) + delta / float(_rot["dur"])
	var t := clampf(float(_rot["t"]), 0.0, 1.0)
	var e := t * t * (3.0 - 2.0 * t)
	var pid := String(_rot["pid"])
	var a := lerpf(float(_rot["from"]), float(_rot["to"]), e)
	angles[pid] = a
	world.set_angle(pid, a)
	if t >= 1.0:
		angles[pid] = float(_rot["to"])
		world.set_angle(pid, angles[pid])
		var record := bool(_rot["record"])
		var action_from := float(_rot["action_from"])
		var to := float(_rot["to"])
		_rot.clear()
		rotating = false
		if record:
			if absf(to - action_from) > 0.01:
				actions.append({"type": "rotate", "pid": pid, "from": action_from, "to": to})
				rotations += 1
		_refresh_links()
		_update_screen_nodes()
		var before := _links_before_rotate
		var after := _link_keys()
		var new_link := false
		for key in after:
			if not before.has(key):
				new_link = true
				break
		if new_link and not capture_mode:
			hud.toast("屏幕上对齐了——折环亮起。", 1.8)
		_update_hover()


func _finish_drag() -> void:
	if _drag.is_empty():
		return
	var pid := String(_drag.get("pid", ""))
	var from := float(_drag.get("start_angle", 0.0))
	var active := bool(_drag.get("active", false))
	_drag.clear()
	if not active:
		return
	var step := _step_degrees(pid)
	var target := FoldMath.snap_angle(float(angles.get(pid, 0.0)), step)
	_begin_rotate(pid, target, 0.16, true, from)


# ---------------------------------------------------------------- keyboard step

## Arrow keys / WASD move the fox one graph hop toward the requested screen
## direction. This is the keyboard alternative to clicking a node.
func keyboard_step(dir: Vector2) -> bool:
	if level.is_empty() or win or moving or rotating:
		return false
	_refresh_links()
	var adj := FoldLevel.adjacency(level, links)
	if not adj.has(current_node):
		return false
	var best := ""
	var best_dot := 0.2
	var best_dist := INF
	var from_screen: Vector2 = screen_nodes.get(current_node, Vector2.ZERO)
	for raw in adj[current_node]:
		var nid := String(raw)
		if not screen_nodes.has(nid):
			continue
		var to_screen: Vector2 = screen_nodes[nid]
		var delta := to_screen - from_screen
		if delta.length() < 0.5:
			continue
		var dot := delta.normalized().dot(dir.normalized())
		if dot > best_dot + 0.001 or (absf(dot - best_dot) <= 0.001 and delta.length() < best_dist):
			best = nid
			best_dot = dot
			best_dist = delta.length()
	if best == "":
		hud.toast("这个方向没有相连的节点。", 1.3)
		return false
	return request_move(best)


# ---------------------------------------------------------------- undo / reset / hints

func undo() -> void:
	if level.is_empty() or moving or rotating:
		return
	if win:
		hud.toast("本关已完成。按 Enter 进入下一关。", 1.8)
		return
	if actions.is_empty():
		hud.toast("没有可撤销的步骤。", 1.4)
		return
	var action: Dictionary = actions.pop_back()
	if String(action["type"]) == "move":
		current_node = String(action["from"])
		moves = maxi(0, moves - 1)
		win = false
		player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
		win = false
		hud.hide_win()
		_refresh_links()
		_update_screen_nodes()
		hud.toast("已撤销移动。", 1.3)
	else:
		var pid := String(action["pid"])
		var from := float(action["from"])
		rotations = maxi(0, rotations - 1)
		selected_platform = pid
		_begin_rotate(pid, from, 0.18, false, from)
		hud.toast("已撤销旋转。", 1.3)
	_update_hover()


func reset_level() -> void:
	if levels.is_empty():
		return
	load_level(level_index)
	hud.toast("已重置本关。", 1.4)


func use_hint() -> void:
	if level.is_empty():
		return
	var hints: Array = level.get("hints", [])
	if hints.is_empty():
		hud.toast("这一关没有提示。", 1.2)
		return
	var h: Dictionary = hints[hint_index % hints.size()]
	hint_index += 1
	hint_focus = String(h.get("focus", ""))
	hint_nodes.clear()
	for nid in FoldLevel.hint_focus_ids(level, hint_focus):
		hint_nodes.append(String(nid))
	hint_until = elapsed + 6.0
	if _is_rotatable(hint_focus):
		selected_platform = hint_focus
	var text := String(h.get("text", ""))
	hud.set_hint(text)
	hud.toast(text, 4.0)
	_update_hover()


func next_level() -> void:
	if levels.is_empty():
		return
	load_level(level_index + 1)


func _win() -> void:
	if win:
		return
	win = true
	win_elapsed = elapsed
	moving = false
	rotating = false
	_rot.clear()
	player.celebrate()
	var stats := {
		"level": String(level.get("name", "")),
		"moves": moves,
		"rotations": rotations,
		"seconds": win_elapsed,
		"next_is_last": level_index == levels.size() - 1
	}
	hud.show_win(stats)


# ---------------------------------------------------------------- input

func _design_pos(p: Vector2) -> Vector2:
	if p.x > FoldMath.VIEW.x + 1.0 or p.y > FoldMath.VIEW.y + 1.0:
		var win_size := Vector2(DisplayServer.window_get_size())
		if win_size.x > 0.0 and win_size.y > 0.0:
			return Vector2(p.x * FoldMath.VIEW.x / win_size.x, p.y * FoldMath.VIEW.y / win_size.y)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if capture_mode or level.is_empty():
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.set_zoom(cam.zoom + 0.05, level)
			_refresh_links()
			_update_hover()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.set_zoom(cam.zoom - 0.05, level)
			_refresh_links()
			_update_hover()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var pos := _design_pos(event.position)
			if event.pressed:
				_on_press(pos)
			else:
				_on_release(pos)
	elif event is InputEventMouseMotion:
		_mouse_design = _design_pos(event.position)
		if not _drag.is_empty():
			_drag_motion()
		else:
			_update_hover()
	elif event is InputEventKey and event.pressed and not event.echo:
		_key(event)


func _key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_Q:
			rotate_selected(-1)
		KEY_E:
			rotate_selected(1)
		KEY_LEFT, KEY_A:
			keyboard_step(Vector2.LEFT)
		KEY_RIGHT, KEY_D:
			keyboard_step(Vector2.RIGHT)
		KEY_UP, KEY_W:
			keyboard_step(Vector2.UP)
		KEY_DOWN, KEY_S:
			keyboard_step(Vector2.DOWN)
		KEY_Z:
			undo()
		KEY_R:
			reset_level()
		KEY_H:
			use_hint()
		KEY_F1:
			debug = not debug
			hud.set_debug(debug)
			hud.toast("调试叠加：开" if debug else "调试叠加：关", 1.2)
		KEY_1, KEY_2, KEY_3:
			var idx := int(event.keycode) - int(KEY_1)
			if idx < levels.size():
				load_level(idx)
		KEY_ENTER, KEY_KP_ENTER:
			if win:
				next_level()
		KEY_ESCAPE:
			if win:
				hud.hide_win()
				hud.toast("按 Enter 进入下一关。", 1.8)


func _on_press(pos: Vector2) -> void:
	if win or hud.is_pointer_over_ui(pos):
		return
	_press_screen = pos
	_press_node = _pick_node(pos, NODE_CLICK_PX)
	var hit := _pick_platform(pos)
	_press_platform = String(hit.get("id", ""))
	if _press_platform != "" and _is_rotatable(_press_platform):
		selected_platform = _press_platform
		_drag = {
			"pid": _press_platform,
			"start_angle": float(angles.get(_press_platform, 0.0)),
			"start": pos,
			"active": false
		}
	else:
		_drag.clear()
	_update_hover()


func _on_release(pos: Vector2) -> void:
	if win or hud.is_pointer_over_ui(pos):
		_drag.clear()
		_press_node = ""
		_press_platform = ""
		return
	if not _drag.is_empty():
		var was_active := bool(_drag.get("active", false))
		_finish_drag()
		if was_active:
			_press_node = ""
			_press_platform = ""
			return
	var node := _press_node
	var platform := _press_platform
	_press_node = ""
	_press_platform = ""
	if node != "":
		request_move(node)
	elif platform != "":
		select_platform(platform)
	_update_hover()


func _drag_motion() -> void:
	if _drag.is_empty():
		return
	var pid := String(_drag.get("pid", ""))
	if pid == "":
		return
	var dx := _mouse_design.x - (_drag["start"] as Vector2).x
	if absf(dx) > DRAG_START_PX:
		_drag["active"] = true
	if not bool(_drag.get("active", false)):
		return
	var raw := float(_drag["start_angle"]) + dx * 0.55
	angles[pid] = raw
	world.set_angle(pid, raw)
	selected_platform = pid
	_refresh_links()
	_update_screen_nodes()
	_update_cursor(true)


func _interact_lift() -> float:
	return 0.36 * 0.81649658 * (720.0 / maxf(0.1, cam.effective_size()))


func _pick_node(screen: Vector2, radius: float) -> String:
	var best := ""
	var best_dist := radius
	var best_depth := -INF
	var lift := _interact_lift()
	for nid in screen_nodes.keys():
		var p: Vector2 = screen_nodes[nid]
		var d := screen.distance_to(p)
		if open_nodes.has(String(nid)):
			d = minf(d, screen.distance_to(p + Vector2(0, -lift)))
		var depth := float(node_depths.get(nid, 0.0))
		if d < best_dist - 1.0 or (absf(d - best_dist) <= 1.0 and depth > best_depth):
			best = String(nid)
			best_dist = d
			best_depth = depth
	return best


func _pick_platform(screen: Vector2) -> Dictionary:
	var ray := cam.screen_ray(screen)
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	var best := ""
	var best_t := INF
	for p in level.get("platforms", []):
		var pid := String(p["id"])
		var size := FoldMath.vec3(p["size"])
		var pick_size := Vector3(maxf(size.x, 0.7), maxf(size.y + 0.55, 0.8), maxf(size.z, 0.7))
		var center := Vector3(0, -size.y * 0.5, 0)
		var t := FoldMath.ray_yaw_box(origin, dir, FoldMath.vec3(p["pivot"]), float(angles.get(pid, 0.0)), center, pick_size)
		if t >= 0.0 and t < best_t:
			best_t = t
			best = pid
	return {"id": best, "t": best_t} if best != "" else {}


func _update_hover() -> void:
	if level.is_empty() or win:
		hover_node = ""
		hover_platform = ""
		_update_cursor(false)
		return
	var mouse := _mouse_design
	if hud != null and hud.is_pointer_over_ui(mouse):
		hover_node = ""
		hover_platform = ""
		_update_cursor(false)
		return
	hover_node = _pick_node(mouse, NODE_CLICK_PX)
	var hit := _pick_platform(mouse)
	hover_platform = String(hit.get("id", ""))
	var hand := hover_node != "" or (hover_platform != "" and _is_rotatable(hover_platform))
	_update_cursor(hand or not _drag.is_empty())


func _update_cursor(hand: bool) -> void:
	if hand == _cursor_hand:
		return
	_cursor_hand = hand
	if not _drag.is_empty() and bool(_drag.get("active", false)):
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if hand else Input.CURSOR_ARROW)


# ---------------------------------------------------------------- HUD / debug hooks

func hud_snapshot() -> Dictionary:
	var platforms: Array[Dictionary] = []
	if debug:
		for p in level.get("platforms", []):
			var pid := String(p["id"])
			var pivot := FoldMath.vec3(p["pivot"])
			platforms.append({
				"id": pid,
				"name": String(p.get("name", pid)),
				"angle": float(angles.get(pid, 0.0)),
				"screen": cam.screen_of(pivot),
				"rotatable": bool(p.get("rotatable", false))
			})
	var edges: Array[Dictionary] = []
	if debug:
		for e in level.get("edges", []):
			var a := String(e[0])
			var b := String(e[1])
			if screen_nodes.has(a) and screen_nodes.has(b):
				edges.append({"a": a, "b": b, "sa": screen_nodes[a], "sb": screen_nodes[b]})
	var sel_name := ""
	var sel_angle := 0.0
	var sel_rot := false
	if selected_platform != "":
		var p := _platform(selected_platform)
		sel_name = String(p.get("name", selected_platform))
		sel_angle = float(angles.get(selected_platform, 0.0))
		sel_rot = bool(p.get("rotatable", false))
	var titles: Array[String] = []
	for lvl in levels:
		titles.append(String(lvl.get("name", "")))
	return {
		"level_name": String(level.get("name", "")),
		"level_subtitle": String(level.get("subtitle", "")),
		"level_index": level_index,
		"level_titles": titles,
		"objective": String(level.get("objective", "")),
		"has_rotatable": _first_rotatable() != "",
		"selected_name": sel_name,
		"selected_angle": sel_angle,
		"selected_rotatable": sel_rot,
		"can_undo": not actions.is_empty() and not moving and not rotating and not win,
		"moving": moving,
		"rotating": rotating,
		"win": win,
		"debug": debug,
		"screen_nodes": screen_nodes,
		"node_depths": node_depths,
		"links": links,
		"open_nodes": open_nodes,
		"hover_node": hover_node,
		"hover_platform": hover_platform,
		"selected_platform": selected_platform,
		"current_node": current_node,
		"goal_node": goal_node,
		"hint_nodes": hint_nodes,
		"hint_active": hint_until >= 0.0 and elapsed <= hint_until,
		"hint_focus": hint_focus,
		"edges": edges,
		"platforms": platforms,
		"link_px": float(level.get("link_px", 18.0)),
		"lift_px": _interact_lift(),
		"fps": Engine.get_frames_per_second(),
		"draws": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		"zoom": cam.zoom if cam != null else 1.0,
		"ortho": cam.effective_size() if cam != null else 0.0,
		"actions": actions.size(),
		"moves": moves,
		"rotations": rotations,
		"elapsed": elapsed,
		"win_elapsed": win_elapsed,
		"link_count": links.size(),
		"player_screen": cam.screen_of(player.position) if player != null else Vector2.ZERO,
		"player_node": current_node,
		"walk_steps": _walk_steps.size() if moving else 0,
		"walk_index": _walk_index,
		"fold_flash": not _drag.is_empty()
	}


func is_pointer_over_ui(pos: Vector2) -> bool:
	return hud != null and hud.is_pointer_over_ui(pos)


func debug_state() -> Dictionary:
	var snap := hud_snapshot()
	var pairs: Array[String] = []
	for link in links:
		pairs.append("%s+%s@%.1fpx" % [String(link["a"]), String(link["b"]), float(link["dist"])])
	snap["link_pairs"] = pairs
	snap["screen_nodes"] = screen_nodes.duplicate()
	return snap


func debug_load_level(index: int) -> void:
	load_level(index)


func debug_set_angle(pid: String, deg: float) -> void:
	if level.is_empty():
		return
	angles[pid] = deg
	world.set_angle(pid, deg)
	_refresh_links()
	_update_screen_nodes()
	if not moving:
		player.position = _node_pos(current_node) + FOOT
	_update_hover()


func debug_set_player(node_id: String) -> void:
	if level.is_empty() or not FoldLevel.node_map(level).has(node_id):
		return
	current_node = node_id
	moving = false
	win = false
	_last_yaw = _initial_face()
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	hud.hide_win()
	_refresh_links()
	_update_screen_nodes()
	_update_hover()


func debug_walk_to(node_id: String) -> bool:
	return request_move(node_id)


func debug_instant_move(node_id: String) -> bool:
	if level.is_empty() or win:
		return false
	_refresh_links()
	var route := FoldLevel.find_route(level, current_node, node_id, links)
	if route.size() < 2:
		return false
	var from := current_node
	current_node = node_id
	actions.append({"type": "move", "from": from, "to": node_id})
	moves += 1
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	win = false
	hud.hide_win()
	_refresh_links()
	_update_screen_nodes()
	if current_node == goal_node:
		_win()
	return true


func debug_route(to_id: String) -> Array[String]:
	_refresh_links()
	return FoldLevel.find_route(level, current_node, to_id, links)


func debug_force_win() -> void:
	if level.is_empty():
		return
	current_node = goal_node
	_update_screen_nodes()
	player.teleport(_node_pos(current_node) + FOOT, _last_yaw)
	_win()


func debug_clear_toast() -> void:
	if hud != null:
		hud.clear_toast()


func debug_set_debug(on: bool) -> void:
	debug = on
	if hud != null:
		hud.set_debug(on)


func debug_set_capture_mode(on: bool) -> void:
	capture_mode = on
	_drag.clear()
	hover_node = ""
	hover_platform = ""
	if on:
		debug = false
		if hud != null:
			hud.set_debug(false)
			hud.clear_toast()
	if hud != null:
		hud.clear_hint()


func debug_set_zoom(mult: float) -> void:
	cam.set_zoom(mult, level)
	_refresh_links()
	_update_screen_nodes()
	_update_hover()


func debug_screen_click(pos: Vector2) -> void:
	_mouse_design = pos
	_on_press(pos)
	_on_release(pos)


func debug_screen_drag(from_pos: Vector2, to_pos: Vector2) -> void:
	_mouse_design = from_pos
	_on_press(from_pos)
	_mouse_design = to_pos
	_drag_motion()
	_on_release(to_pos)


func debug_get_link_distance(a: String, b: String) -> float:
	for link in links:
		if (String(link["a"]) == a and String(link["b"]) == b) or (String(link["a"]) == b and String(link["b"]) == a):
			return float(link["dist"])
	return -1.0


func debug_node_screen(node_id: String) -> Vector2:
	return screen_nodes.get(node_id, Vector2(-9999, -9999))


func debug_set_hint(index: int) -> void:
	var hints: Array = level.get("hints", [])
	if hints.is_empty():
		return
	hint_index = index % hints.size()
	use_hint()
