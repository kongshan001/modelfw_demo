class_name FogResultScreen
extends Control
## 行动结算：撤离成功或阵亡/超时。显示带出/损失物资与仓库变化。

signal return_requested
signal retry_requested

const PANEL := Rect2(300, 112, 680, 504)

var success := false
var reason := ""
var summary: Dictionary = {}
var state: FogGameState = null
var _return_button: Button
var _retry_button: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func configure(is_success: bool, fail_reason: String, result_summary: Dictionary, game_state: FogGameState) -> void:
	success = is_success
	reason = fail_reason
	summary = result_summary
	state = game_state
	_return_button = FogUITheme.make_ghost_button("返回基地", Rect2(356, 538, 240, 50), 18)
	_return_button.pressed.connect(func(): return_requested.emit())
	add_child(_return_button)
	_retry_button = FogUITheme.make_button("再次部署", Rect2(626, 538, 240, 50), FogUITheme.AMBER, 18)
	_retry_button.pressed.connect(func(): retry_requested.emit())
	add_child(_retry_button)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.03, 0.04, 0.82), true)
	FogUITheme.draw_panel(self, PANEL, Color(0.035, 0.082, 0.1, 0.985), FogUITheme.BORDER)
	var accent := FogUITheme.TEAL if success else FogUITheme.RED
	draw_rect(Rect2(PANEL.position.x, PANEL.position.y, PANEL.size.x, 4), accent, true)
	# 顶部标记
	var badge := Vector2(PANEL.position.x + 64, PANEL.position.y + 74)
	draw_circle(badge, 30.0, Color(accent.r, accent.g, accent.b, 0.1), true)
	draw_arc(badge, 30.0, 0.0, TAU, 32, accent, 2.0)
	if success:
		draw_line(badge + Vector2(-12, 1), badge + Vector2(-3, 10), accent, 4.0)
		draw_line(badge + Vector2(-3, 10), badge + Vector2(14, -12), accent, 4.0)
	else:
		draw_line(badge + Vector2(-11, -11), badge + Vector2(11, 11), accent, 4.0)
		draw_line(badge + Vector2(11, -11), badge + Vector2(-11, 11), accent, 4.0)
	FogUITheme.draw_text(self, PANEL.position + Vector2(112, 68),
		"撤离成功" if success else "行动失败", 36, accent, true)
	FogUITheme.draw_text(self, PANEL.position + Vector2(114, 94),
		"FOGFALL · 物资已入库" if success else "FOGFALL · 信号中断", 11, FogUITheme.DIM)
	var reason_text := reason
	if success and reason == "撤离成功":
		reason_text = "东南栈桥 · 已脱离"
	elif not success and reason == "阵亡":
		reason_text = "信号中断 · 随身物资丢失"
	FogUITheme.draw_text_right(self, Rect2(PANEL.position.x + 340, PANEL.position.y + 54, 300, 30),
		reason_text, 14, FogUITheme.TEXT)
	draw_line(PANEL.position + Vector2(36, 136), PANEL.position + Vector2(644, 136), FogUITheme.BORDER_SOFT, 1.0)

	var lines := _summary_lines()
	var y := PANEL.position.y + 174
	for line in lines:
		var color := FogUITheme.DIM
		if String(line).begins_with("+"):
			color = FogUITheme.AMBER
		FogUITheme.draw_text(self, Vector2(PANEL.position.x + 48, y), String(line), 15, color)
		y += 28.0

	_draw_items_row()
	FogUITheme.draw_text(self, Vector2(PANEL.position.x + 48, PANEL.position.y + 354),
		"信用点 %d · 仓库 %d / %d 格 · 行动 %d / 撤离 %d" % [
			state.credits, state.warehouse_slots(), state.warehouse_capacity(),
			int(state.stats.get("runs", 0)), int(state.stats.get("extractions", 0)),
		], 12, FogUITheme.DIM)
	FogUITheme.draw_text(self, Vector2(PANEL.position.x + 48, PANEL.position.y + 374),
		"死亡只丢失随身物资；仓库、信用点与升级永久保留。", 11, FogUITheme.AMBER_DIM)


func _summary_lines() -> Array:
	if success:
		var lines: Array = []
		var count := int(summary.get("count", 0))
		lines.append("带出物资 %d 件 · 估值 %d 信用点" % [count, int(summary.get("total_value", 0))])
		lines.append("入库 %d 件 · 旧港币兑换 +%d" % [int(summary.get("stored", 0)), int(summary.get("currency_credits", 0))])
		if int(summary.get("overflow", 0)) > 0:
			lines.append("仓库已满，溢出 %d 件折现 +%d" % [int(summary.get("overflow", 0)), int(summary.get("overflow_credits", 0))])
		else:
			lines.append("仓库空间充足，没有物资溢出。")
		return lines
	var lines: Array = []
	lines.append("随身物资 %d 件全部丢失 · 估值 %d" % [int(summary.get("count", 0)), int(summary.get("value", 0))])
	lines.append("带出行动失败，未获得任何信用点。")
	lines.append("仓库物资、信用点与基地升级保持不变。")
	return lines


func _draw_items_row() -> void:
	var items: Array = summary.get("items", [])
	if items.is_empty():
		return
	FogUITheme.draw_text(self, Vector2(PANEL.position.x + 48, PANEL.position.y + 260), "当局物资", 12, FogUITheme.DIM)
	var x := PANEL.position.x + 48.0
	var shown := 0
	for raw in items:
		if shown >= 8:
			break
		var id := String(raw.get("id", ""))
		if id == "":
			continue
		var rect := Rect2(Vector2(x, PANEL.position.y + 274), Vector2(64, 64))
		draw_rect(rect, Color(0.03, 0.07, 0.08, 0.9), true)
		var rarity := int(FogItems.get_item(id).get("rarity", 0))
		draw_rect(rect, FogItems.rarity_color(rarity), false, 1.5)
		FogItemArt.draw_icon(self, rect.grow(-10), id)
		var count := int(raw.get("count", 1))
		if count > 1:
			FogUITheme.draw_text(self, rect.end - Vector2(18, 8), str(count), 12, FogUITheme.WHITE, true)
		x += 72.0
		shown += 1
