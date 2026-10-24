class_name TargetSelector
extends RefCounted

# 目标选择：高亮合法 UnitView、接收点击、按槽位解析键盘选择。

signal target_chosen(unit_id: StringName)

var _ctx: BattleContext
var _state: BattleState
var _side: int = BattleTypes.Side.ENEMY
var _active := false

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
		view.set_targetable(valid)
		if valid and not view.clicked.is_connected(_on_view_clicked):
			view.clicked.connect(_on_view_clicked)

func end() -> void:
	_active = false
	if _ctx != null:
		for value in _ctx.unit_views.values():
			var view: UnitView = value
			if view == null or not is_instance_valid(view):
				continue
			view.set_targetable(false)
			if view.clicked.is_connected(_on_view_clicked):
				view.clicked.disconnect(_on_view_clicked)
	_ctx = null
	_state = null

func is_active() -> bool:
	return _active

func side() -> int:
	return _side

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
	target_chosen.emit(unit_id)
	return true

func _on_view_clicked(view: UnitView) -> void:
	if view != null:
		choose(view.unit_id)
