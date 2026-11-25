extends Node
## 轻量屏幕空间交互：把可交互小物投影成 HUD 标记，鼠标悬停/点击与 E 触发。
## 不依赖物理拾取，避免给软场景添加碰撞体；小物用屏幕距离容差保证可点。

const DESIGN := Vector2(1280.0, 720.0)
const HOVER_RADIUS := 62.0

var main
var world
var camera: Camera3D
var hud
var targets: Array = []

var hovered = null
var forced_hover_id := ""
var last_markers: Array = []
var enabled := true
var _press_pos := Vector2(-1000, -1000)
var _pressing := false
var _mouse_design := Vector2.ZERO


func setup(main_node: Node, world_node: Node, camera_node: Camera3D, hud_node: CanvasLayer) -> void:
	main = main_node
	world = world_node
	camera = camera_node
	hud = hud_node
	targets = world.get_interaction_targets()
	set_process(true)


func _process(_delta: float) -> void:
	if not enabled or camera == null or hud == null:
		return
	if main != null and bool(main.paused):
		_clear_hover()
		hud.set_markers([])
		return
	if hud.hidden:
		_clear_hover()
		hud.set_markers([])
		return
	_refresh_targets()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or main == null or bool(main.paused):
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.physical_keycode == KEY_E:
			if hovered != null:
				_interact(hovered)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_pressing = true
				_press_pos = mb.position
			elif _pressing:
				_pressing = false
				if mb.position.distance_to(_press_pos) <= 7.0:
					var picked = _pick_target(_to_design(mb.position))
					if picked != null:
						_interact(picked)
						get_viewport().set_input_as_handled()


func _refresh_targets() -> void:
	var markers: Array = []
	var mouse := _to_design(get_viewport().get_mouse_position())
	_mouse_design = mouse
	var best = null
	var best_dist := HOVER_RADIUS
	var forced_target = null
	for target in targets:
		var anchor: Vector3 = target.get_interaction_anchor()
		if camera.is_position_behind(anchor):
			continue
		var screen: Vector2 = camera.unproject_position(anchor)
		var vp_size := camera.get_viewport().get_visible_rect().size
		if vp_size.x <= 1.0 or vp_size.y <= 1.0:
			continue
		var design_pos := Vector2(screen.x / vp_size.x * DESIGN.x, screen.y / vp_size.y * DESIGN.y)
		var on_screen := design_pos.x > -80.0 and design_pos.x < DESIGN.x + 80.0 \
				and design_pos.y > -80.0 and design_pos.y < DESIGN.y + 80.0
		if not on_screen:
			continue
		var target_id: String = target.get_display_id()
		if forced_hover_id != "" and target_id == forced_hover_id:
			forced_target = target
		var d := design_pos.distance_to(mouse)
		if d < best_dist:
			best_dist = d
			best = target
		markers.append({
			"pos": design_pos,
			"label": target.get_display_name(),
			"id": target_id,
			"hovered": false,
			"visible": true,
		})
	if forced_hover_id != "" and forced_target != null:
		best = forced_target
	for marker in markers:
		if best != null and marker["id"] == best.get_display_id():
			marker["hovered"] = true
	_set_hover(best)
	last_markers = markers
	hud.set_markers(markers)


func _pick_target(mouse_design: Vector2):
	if camera == null:
		return null
	var best = null
	var best_dist := HOVER_RADIUS
	for target in targets:
		var anchor: Vector3 = target.get_interaction_anchor()
		if camera.is_position_behind(anchor):
			continue
		var screen: Vector2 = camera.unproject_position(anchor)
		var vp_size := camera.get_viewport().get_visible_rect().size
		var pos := Vector2(screen.x / vp_size.x * DESIGN.x, screen.y / vp_size.y * DESIGN.y)
		var d := pos.distance_to(mouse_design)
		if d < best_dist:
			best_dist = d
			best = target
	return best


func _to_design(pos: Vector2) -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return Vector2.ZERO
	return Vector2(pos.x / vp_size.x * DESIGN.x, pos.y / vp_size.y * DESIGN.y)


func _set_hover(target) -> void:
	if target == hovered:
		return
	if hovered != null:
		hovered.set_focused(false)
	hovered = target
	if hovered != null:
		hovered.set_focused(true)


func _clear_hover() -> void:
	if hovered != null:
		hovered.set_focused(false)
		hovered = null


func _interact(target) -> void:
	if target == null:
		return
	target.interact()


func set_forced_hover(id: String) -> void:
	forced_hover_id = id


func clear_forced_hover() -> void:
	forced_hover_id = ""
	_refresh_targets()


func reset() -> void:
	forced_hover_id = ""
	_clear_hover()
	last_markers.clear()
	if hud != null:
		hud.set_markers([])
