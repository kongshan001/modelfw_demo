extends SceneTree

# T-20261120-011 QA 键盘探针（只读验收，不改游戏代码）：
#   1) 统计可交互控件与 FOCUS_ALL 覆盖；
#   2) 用 find_next_valid_focus 遍历焦点环；
#   3) 通过 Input.parse_input_event 实测 1-4 / ←→ / R / S / L / F11 / Esc 快捷键。
# 输出 QA_INPUT_OK 或 QA_INPUT_FAIL。
# 用法：godot --headless --path godot-paper-doll -s tools/qa_input_probe.gd

var _fails: Array[String] = []


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.35).timeout

	# ── 1) 控件与焦点模式 ─────────────────────────────────────────────
	var all_controls: Array[Control] = []
	_collect(scene, all_controls)
	var buttons := 0
	var focusable := 0
	var non_focus_buttons: Array[String] = []
	for c in all_controls:
		if c is Button:
			buttons += 1
			if c.focus_mode == Control.FOCUS_ALL and c.visible and not c.disabled:
				focusable += 1
			elif c.visible and not c.disabled:
				non_focus_buttons.append(str(c.name) + "(" + str(c.get_path()) + ")")
	# 可点击但不可聚焦的卡片（LineupCard 是 PanelContainer + _gui_input）
	var card_controls: Array[String] = []
	for c in all_controls:
		if c is LineupCard:
			card_controls.append(str(c.name) + " focus=" + str(c.focus_mode))
	print("QA_INPUT buttons=%d focusable_buttons=%d all_controls=%d lineup_cards=%d"
			% [buttons, focusable, all_controls.size(), card_controls.size()])
	if not non_focus_buttons.is_empty():
		print("QA_INPUT non_focus_buttons=", non_focus_buttons)
	if not card_controls.is_empty():
		print("QA_INPUT lineup_card_focus=", card_controls)
	_check(focusable >= 40, "too few focusable buttons: %d" % focusable)
	# 评审 P1-2：Tab 焦点要覆盖所有按钮；卡片本体也应可键盘载入。
	_check(non_focus_buttons.is_empty(), "visible buttons without FOCUS_ALL: %s" % str(non_focus_buttons))
	_check(card_controls.is_empty(), "lineup cards are clickable but not keyboard-focusable")

	# ── 2) 焦点环遍历 ─────────────────────────────────────────────────
	var start: Control = null
	for c in all_controls:
		if c is Button and c.focus_mode == Control.FOCUS_ALL and c.visible and not c.disabled:
			start = c
			break
	if start != null:
		start.grab_focus()
		var seen := {}
		var order: Array[String] = []
		var current: Control = root.gui_get_focus_owner()
		for i in 200:
			if current == null:
				break
			var path := str(current.get_path())
			if seen.has(path):
				break
			seen[path] = true
			order.append(path)
			current = current.find_next_valid_focus()
			if current == null:
				break
			current.grab_focus()
		print("QA_INPUT focus_cycle=%d first=%s last=%s" % [order.size(), order[0] if order.size() > 0 else "-", order[-1] if order.size() > 0 else "-"])
		_check(order.size() >= 40, "focus cycle visited only %d controls" % order.size())
	else:
		_check(false, "no focusable button found")

	# ── 3) 快捷键实测 ──────────────────────────────────────────────────
	# 先释放焦点：箭头键在有焦点按钮上会被 UI 焦点导航吃掉（下面单独记录）。
	root.gui_release_focus()
	await process_frame
	var dir0: int = scene.get_direction()
	await _key(scene, KEY_RIGHT)
	_check(scene.get_direction() == posmod(dir0 + 1, 8), "→ did not advance direction (no focus)")
	await _key(scene, KEY_LEFT)
	_check(scene.get_direction() == dir0, "← did not restore direction (no focus)")

	# 焦点在按钮上时按 →：记录方向是否变化、焦点是否移动。
	start.grab_focus()
	await process_frame
	var dir_focus: int = scene.get_direction()
	var focus_before: Control = root.gui_get_focus_owner()
	await _key(scene, KEY_RIGHT)
	var focus_after: Control = root.gui_get_focus_owner()
	print("QA_INPUT arrow_with_focus dir_changed=%s focus_moved=%s"
			% [str(scene.get_direction() != dir_focus), str(focus_before != focus_after)])
	root.gui_release_focus()
	await process_frame

	for pair in [[KEY_1, "idle"], [KEY_2, "walk"], [KEY_3, "attack"], [KEY_4, "hit"]]:
		await _key(scene, int(pair[0]))
		_check(scene.get_action() == str(pair[1]), "key %d did not set action %s" % [pair[0], pair[1]])
	await _key(scene, KEY_1)

	var sig0 := _sig(scene.get_outfit())
	await _key(scene, KEY_R)
	_check(_sig(scene.get_outfit()) != sig0, "R did not randomize")

	# S/L 往返（键盘触发保存/载入）
	scene.set_slot_variant("shirt", "armor")
	scene.set_slot_color("shirt", Color("#4fa58a"))
	var saved_sig := _sig(scene.get_outfit())
	await _key(scene, KEY_S)
	await create_timer(0.2).timeout
	await _key(scene, KEY_R)
	await _key(scene, KEY_L)
	_check(_sig(scene.get_outfit()) == saved_sig, "S/L keyboard round-trip mismatch")

	# F11 舞台模式 + Esc 退出
	await _key(scene, KEY_F11)
	_check(scene._show_mode, "F11 did not enter stage mode")
	await _key(scene, KEY_ESCAPE)
	_check(not scene._show_mode, "Esc did not leave stage mode")

	# 弹层 Esc
	scene.show_directions_sheet()
	await process_frame
	await _key(scene, KEY_ESCAPE)
	_check(scene._overlay == null, "Esc did not close direction sheet")

	if _fails.is_empty():
		print("QA_INPUT_OK")
		quit(0)
	else:
		for f in _fails:
			printerr("QA_INPUT FAIL: ", f)
		printerr("QA_INPUT_FAILED failures=%d" % _fails.size())
		quit(1)


func _key(scene, code: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await process_frame


func _collect(node: Node, out: Array[Control]) -> void:
	if node is Control:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _sig(outfit: Dictionary) -> String:
	var parts: Array[String] = []
	for slot in DollData.SLOTS:
		var e: Dictionary = outfit.get(slot["id"], {})
		var c: Color = e.get("color", Color.WHITE)
		parts.append("%s:%s:%s" % [slot["id"], str(e.get("variant", "")), c.to_html(false)])
	return "|".join(parts)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fails.append(message)
