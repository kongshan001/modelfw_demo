extends CanvasLayer

# F3 调试浮层：每帧读取当前 BattleSession / Sequencer，显示种子、回合、当前事件、
# 队列、倍速、RNG 状态与双方单位 HP/MP/状态。仅 debug 构建由 BattleDebug 创建。

var _panel: PanelContainer
var _label: RichTextLabel
var _debug: Node = null
var _session: BattleSession = null
var _last_event := ""

func _ready() -> void:
	layer = 127
	visible = false
	_debug = get_node_or_null("/root/BattleDebug")
	_build()
	_refresh()
	set_process(false)

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	_refresh()
	set_process(true)

func close() -> void:
	visible = false
	set_process(false)

func _process(_delta: float) -> void:
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	if _debug == null:
		_label.text = "[color=#ff8a80]BattleDebug 不可用[/color]"
		return
	var current = _debug.session
	if current == null or not is_instance_valid(current):
		_label.text = "[color=#ff8a80]调试浮层：没有活动战斗[/color]"
		return
	if current != _session:
		_session = current
		_last_event = ""
	var engine: BattleEngine = _session.engine
	if engine == null:
		_label.text = "[color=#ff8a80]调试浮层：引擎尚未启动[/color]"
		return
	var state := engine.state
	var sequencer := _session.sequencer
	var event_text := _current_event(sequencer)
	var queue := sequencer.queue_size() if sequencer != null else 0
	var speed := sequencer.playback_speed if sequencer != null else 1.0
	var step := sequencer.is_step_mode() if sequencer != null else false

	var lines: Array[String] = []
	lines.append("[color=#ffd54a][b]调试浮层 F3[/b][/color]  seed=%d  round=%d  outcome=%s" % [
		engine.seed_value, state.round, _outcome_name(state.outcome),
	])
	lines.append("event: %s   queue: %d   speed: %.2fx   step: %s" % [event_text, queue, speed, "on" if step else "off"])
	lines.append("rng: BattleRng(seed=%d, state=%d)   items: %s" % [
		engine.seed_value, engine.rng.state(), _items_text(state),
	])
	lines.append("[color=#9ad0ff]我方[/color]")
	for unit in state.units:
		if unit.side == BattleTypes.Side.ALLY:
			lines.append(_unit_line(unit))
	lines.append("[color=#ffb38a]敌方[/color]")
	for unit in state.units:
		if unit.side == BattleTypes.Side.ENEMY:
			lines.append(_unit_line(unit))
	_label.text = "\n".join(lines)

func _current_event(sequencer: BattleSequencer) -> String:
	if sequencer != null and sequencer.current_command != null and is_instance_valid(sequencer.current_command):
		var event: Variant = sequencer.current_command.get("event")
		if event is BattleEvent:
			_last_event = "seq=%d type=%s" % [event.seq, String(event.type)]
	return _last_event if not _last_event.is_empty() else "seq=— type=—"

func _unit_line(unit: BattleUnitState) -> String:
	var statuses: Array[String] = []
	for status in unit.statuses:
		statuses.append("%s:%d" % [String(status.data.id), status.remaining])
	var status_text := "—" if statuses.is_empty() else ", ".join(statuses)
	return " %s  HP %d/%d  MP %d/%d  %s  [%s]" % [
		unit.data.display_name, unit.hp, unit.data.max_hp, unit.mp, unit.data.max_mp,
		"存活" if unit.is_alive() else "阵亡", status_text,
	]

func _items_text(state: BattleState) -> String:
	var keys: Array = state.item_uses.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	var parts: Array[String] = []
	for key in keys:
		parts.append("%s=%d" % [String(key), int(state.item_uses[key])])
	return "{" + ", ".join(parts) + "}"

func _outcome_name(outcome: int) -> String:
	match outcome:
		BattleTypes.Outcome.VICTORY:
			return "VICTORY"
		BattleTypes.Outcome.DEFEAT:
			return "DEFEAT"
		BattleTypes.Outcome.ESCAPED:
			return "ESCAPED"
		_:
			return "NONE"

func _build() -> void:
	_panel = PanelContainer.new()
	_panel.name = "OverlayPanel"
	_panel.position = Vector2(560, 24)
	_panel.custom_minimum_size = Vector2(780, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.035, 0.06, 0.84)
	style.border_color = Color(0.85, 0.7, 0.34, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	_label = RichTextLabel.new()
	_label.name = "OverlayText"
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.selection_enabled = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("normal_font", FontUtil.cjk_font())
	_label.add_theme_font_override("bold_font", FontUtil.cjk_font())
	_label.add_theme_font_size_override("normal_font_size", 16)
	_label.add_theme_font_size_override("bold_font_size", 16)
	_panel.add_child(_label)
