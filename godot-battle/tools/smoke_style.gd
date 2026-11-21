extends SceneTree

# Headless 冒烟：验证画风后处理节点已挂载、层级正确、三种模式可切换。
# 用法：bash godot-battle/tools/smoke_gate.sh smoke_style.gd --headless

func _initialize() -> void:
	var scene: Node = load("res://scenes/battle_scene.tscn").instantiate()
	scene.start_auto_mode = true
	root.add_child(scene)
	await process_frame

	var fx: StylePostProcess = scene.get_node_or_null("StyleFX")
	if fx == null:
		_fail("StyleFX missing")
		return
	var ui_layer: CanvasLayer = scene.get_node_or_null("UILayer")
	if ui_layer == null:
		_fail("UILayer missing")
		return
	if fx.layer >= ui_layer.layer:
		_fail("StyleFX must render below UILayer")
		return

	if fx.current_style() != 0 or fx.style_name() != "原画":
		_fail("initial style is not 原画")
		return

	fx.set_style(1, false, false)
	if fx.current_style() != 1 or fx.style_name() != "卡通渲染":
		_fail("set_style(1) did not apply 卡通渲染")
		return

	fx.set_style(2, false, false)
	if fx.current_style() != 2 or fx.style_name() != "水墨":
		_fail("set_style(2) did not apply 水墨")
		return

	fx.cycle_style()
	if fx.current_style() != 0 or fx.style_name() != "原画":
		_fail("cycle_style did not wrap to 原画")
		return

	# F2 走真实输入链路，确认不会被 HUD/调试控制台吃掉。
	var event := InputEventKey.new()
	event.keycode = KEY_F2
	event.pressed = true
	scene.get_viewport().push_input(event)
	await process_frame
	if fx.current_style() != 1 or fx.style_name() != "卡通渲染":
		_fail("F2 did not switch to 卡通渲染")
		return

	print("STYLE_SMOKE_OK")
	scene.queue_free()
	await process_frame
	quit(0)

func _fail(message: String) -> void:
	printerr("STYLE_SMOKE_FAIL: " + message)
	quit(1)
