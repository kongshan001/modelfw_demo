extends SceneTree

# headless 剧情探针：
# 1) DialogueBox 播放两行对白，点击推进 + 自动推进走完并隐藏；
# 2) VictoryPanel 二次 show_panel 仍只有一个面板，标题与奖励文本正确。
# 用法：godot --headless --path godot-battle -s tools/probe_story.gd

func _initialize() -> void:
	var dialogue := DialogueBox.new()
	root.add_child(dialogue)
	await process_frame
	if dialogue.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_fail("dialogue overlay should ignore mouse (got %d)" % dialogue.mouse_filter)
		return
	if dialogue._panel.mouse_filter != Control.MOUSE_FILTER_STOP:
		_fail("dialogue panel should stop mouse (got %d)" % dialogue._panel.mouse_filter)
		return

	dialogue.auto_advance_seconds = 0.3
	dialogue.play_lines(["第一行测试对白。", "第二行测试对白。"])
	if not dialogue.is_active():
		_fail("dialogue did not become active")
		return
	# 点击跳过首行打字，随后由自动推进进入第二行。
	dialogue.advance()
	if not await _wait_until(func() -> bool: return dialogue.current_line() == "第二行测试对白。", 5.0):
		_fail("dialogue did not advance to the second line (line=%s)" % dialogue.current_line())
		return
	dialogue.advance()
	if not await _wait_until(func() -> bool: return not dialogue.is_active(), 5.0):
		_fail("dialogue did not auto-complete after two lines")
		return
	if dialogue.visible or not dialogue.current_line().is_empty():
		_fail("dialogue was not hidden/cleared after completion")
		return
	print("STORY_PROBE: dialogue played and completed 2 lines")

	var panel := VictoryPanel.new()
	root.add_child(panel)
	await process_frame
	panel.show_panel(BattleTypes.Outcome.VICTORY, 1200, 350)
	if not panel.is_shown() or not panel.visible:
		_fail("victory panel did not show")
		return
	if _count_label(panel, "胜利！") != 1:
		_fail("victory title count != 1")
		return
	if not await _wait_until(func() -> bool: return _count_label(panel, "经验 +1200") == 1 and _count_label(panel, "金币 +350") == 1, 3.0):
		_fail("victory reward text missing (exp=%d gold=%d)" % [_count_label(panel, "经验 +1200"), _count_label(panel, "金币 +350")])
		return

	# 同一场第二次 show_panel 必须是无操作，不能换成战败标题或再造一个面板。
	panel.show_panel(BattleTypes.Outcome.DEFEAT, 0, 0)
	if not panel.is_shown() or not panel.visible:
		_fail("victory panel lost visibility after second show_panel")
		return
	if _count_label(panel, "胜利！") != 1:
		_fail("victory title count changed after second show_panel")
		return
	if _count_label(panel, "战败…") != 0:
		_fail("second show_panel replaced the title")
		return
	print("STORY_PROBE: victory panel single-shot with rewards 1200/350")
	print("STORY_PROBE_OK")
	quit(0)

func _count_label(node: Node, text: String) -> int:
	var count := 0
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is Label and String(current.text).strip_edges() == text:
			count += 1
		for child in current.get_children():
			stack.append(child)
	return count

func _wait_until(predicate: Callable, timeout: float) -> bool:
	var elapsed := 0.0
	while elapsed < timeout:
		if predicate.call():
			return true
		await create_timer(0.05).timeout
		elapsed += 0.05
	return false

func _fail(message: String) -> void:
	printerr("STORY_PROBE_FAIL: " + message)
	quit(1)
