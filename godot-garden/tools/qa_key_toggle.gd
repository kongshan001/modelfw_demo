extends SceneTree

# QA 专用：验证真实键盘事件链路（KEY_5 游人开关 / F1 UI 开关）。
# 与 probe_patrol.gd 直接调用 toggle_feature 不同，本脚本经 Window.push_input 走
# GardenScene._unhandled_input，能覆盖键位绑定本身。只读检查，不改游戏状态（结束后复位）。

func _initialize() -> void:
	var scene = load("res://scenes/garden.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_autoplay(false)
	scene.set_ui_visible(true)
	await process_frame

	var patrols = scene._world.patrols
	var shown_before := _all_visible(patrols)
	_press(KEY_5)
	await process_frame
	await process_frame
	var hidden_after := _all_hidden(patrols)
	_press(KEY_5)
	await process_frame
	await process_frame
	var shown_after := _all_visible(patrols)

	var ui_before: bool = scene._ui.visible
	_press(KEY_F1)
	await process_frame
	var ui_hidden: bool = not scene._ui.visible
	_press(KEY_F1)
	await process_frame
	var ui_shown: bool = scene._ui.visible

	# UI「游人」按钮 -> GardenUI._on_toggle -> GardenScene.toggle_feature
	var patrol_button: Button = scene._ui._toggle_buttons["patrols"]
	patrol_button.button_pressed = false
	await process_frame
	await process_frame
	var ui_button_hidden := _all_hidden(patrols)
	patrol_button.button_pressed = true
	await process_frame
	await process_frame
	var ui_button_shown := _all_visible(patrols)

	var ok := shown_before and hidden_after and shown_after and ui_before and ui_hidden and ui_shown \
		and ui_button_hidden and ui_button_shown
	print("QA_KEY5 shown_before=%s hidden_after=%s shown_after=%s" % [shown_before, hidden_after, shown_after])
	print("QA_F1 ui_before=%s ui_hidden=%s ui_shown=%s" % [ui_before, ui_hidden, ui_shown])
	print("QA_UI_BUTTON hidden_after=%s shown_after=%s" % [ui_button_hidden, ui_button_shown])
	print("QA_KEY_TOGGLE_OK" if ok else "QA_KEY_TOGGLE_FAIL")
	scene.queue_free()
	await process_frame
	quit(0 if ok else 1)

func _press(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	root.push_input(event)

func _all_visible(nodes: Array) -> bool:
	for node in nodes:
		if not node.visible:
			return false
	return true

func _all_hidden(nodes: Array) -> bool:
	for node in nodes:
		if node.visible:
			return false
	return true
