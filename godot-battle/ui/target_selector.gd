class_name TargetSelector
extends RefCounted

# 目标选择：只保留一个目标箭头，默认落在前排尖端；鼠标悬停/点击会移动箭头，
# 1–4 / QWE 按槽位直接确认。命中区允许与后排重叠，数字键是稳定的兜底选择。

signal target_chosen(unit_id: StringName)

var _ctx: BattleContext
var _state: BattleState
var _side: int = BattleTypes.Side.ENEMY
var _active := false
var _highlighted: StringName = &""

func begin(ctx: BattleContext, state: BattleState, side: int) -> void:
	end()
	if ctx == null or state == null:
		return
	_ctx = ctx
	_state = state
	_side = side
	_active = true
	for value in ctx.unit_views.values():
		var view: UnitView = value
		if view == null or not is_instance_valid(view):
			continue
		var unit: BattleUnitState = view.unit_state
		var valid: bool = unit != null and unit.is_alive() and unit.side == side
		if valid:
			if not view.clicked.is_connected(_on_view_clicked):
				view.clicked.connect(_on_view_clicked)
			if not view.hovered.is_connected(_on_view_hovered):
				view.hovered.connect(_on_view_hovered)
	_highlighted = _default_target_id()
	_refresh_highlight()

func end() -> void:
	_active = false
	if _ctx != null:
		for value in _ctx.unit_views.values():
			var view: UnitView = value
			if view == null or not is_instance_valid(view):
				continue
			view.set_target_highlight(false)
			if view.clicked.is_connected(_on_view_clicked):
				view.clicked.disconnect(_on_view_clicked)
			if view.hovered.is_connected(_on_view_hovered):
				view.hovered.disconnect(_on_view_hovered)
	_highlighted = &""
	_ctx = null
	_state = null

func is_active() -> bool:
	return _active

func side() -> int:
	return _side

func highlighted_id() -> StringName:
	return _highlighted if _active else &""

func choose_slot(slot: int) -> bool:
	if not _active or _state == null:
		return false
	for unit in _state.living(_side):
		if unit.slot == slot:
			return choose(unit.id)
	return false

func choose(unit_id: StringName) -> bool:
	if not _active or _state == null:
		return false
	var unit := _state.get_unit(unit_id)
	if unit == null or not unit.is_alive() or unit.side != _side:
		return false
	_highlighted = unit_id
	_refresh_highlight()
	target_chosen.emit(unit_id)
	return true

func _on_view_clicked(view: UnitView) -> void:
	if view != null:
		choose(view.unit_id)

func _on_view_hovered(view: UnitView) -> void:
	if not _active or _state == null or view == null:
		return
	var unit := _state.get_unit(view.unit_id)
	if unit == null or not unit.is_alive() or unit.side != _side:
		return
	_highlighted = unit.id
	_refresh_highlight()

func _refresh_highlight() -> void:
	if _ctx == null:
		return
	for value in _ctx.unit_views.values():
		var view: UnitView = value
		if view == null or not is_instance_valid(view):
			continue
		view.set_target_highlight(view.unit_id == _highlighted)

func _default_target_id() -> StringName:
	# 默认高亮前排尖端（row=1），没有尖端时退回首个存活目标。
	if _state == null:
		return &""
	var layout := BattleFieldLayout.new()
	var first: BattleUnitState = null
	for unit in _state.living(_side):
		if first == null:
			first = unit
		var slot := layout.slot(unit.side, unit.slot)
		if int(slot.get("row", 0)) == 1:
			return unit.id
	return first.id if first != null else &""
