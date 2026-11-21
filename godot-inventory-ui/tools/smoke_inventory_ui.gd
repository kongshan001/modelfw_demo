extends SceneTree

var ui: BackpackUI
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func check(cond: bool, msg: String) -> void:
	checks += 1
	if cond:
		print("  ok  ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)


func key_event(code: int, shift_pressed: bool = false) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.shift_pressed = shift_pressed
	return ev


func _run() -> void:
	print("== inventory UI smoke ==")
	var main_scene: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(main_scene)
	ui = main_scene.get("ui")
	await process_frame
	await process_frame
	await create_timer(0.4).timeout

	check(ui != null, "backpack UI exists")
	check(ui.is_panel_open(), "panel opens on boot")
	check(ui.get_page() == 1, "starts on page 1")
	check(ui.get_visible_item_count() == 25, "page 1 shows 25 item stacks")
	check(ui.get_capacity_text().contains("35 / 216"), "capacity reads 35 / 216")
	check(ui.get_capacity_text().contains("1 / 5"), "page indicator reads 1 / 5")
	check(ui.state.items.size() == 35, "data has 35 item stacks")
	check(ui.state.equipment.size() == 8, "eight equipment slots")

	# ---- pages
	ui.switch_page(2)
	await create_timer(0.2).timeout
	check(ui.get_visible_item_count() == 7, "page 2 shows 7 item stacks")
	ui.switch_page(3)
	await create_timer(0.2).timeout
	check(ui.get_visible_item_count() == 2, "page 3 shows 2 item stacks")
	ui.switch_page(4)
	await create_timer(0.25).timeout
	check(ui.get_visible_item_count() == 0, "page 4 is empty")
	check(ui.is_empty_state_visible(), "page 4 shows the empty state")
	ui.switch_page(5)
	await create_timer(0.2).timeout
	check(ui.get_visible_item_count() == 1, "page 5 (temporary) shows 1 item")

	# ---- categories
	ui.switch_page(1)
	await create_timer(0.2).timeout
	ui.set_category("装备")
	await create_timer(0.2).timeout
	check(ui.get_category() == "装备" and ui.get_visible_item_count() == 9, "category 装备 filters to 9 rows")
	ui.set_category("消耗")
	await create_timer(0.1).timeout
	check(ui.get_visible_item_count() == 5, "category 消耗 filters to 5 rows")
	ui.set_category("材料")
	await create_timer(0.1).timeout
	check(ui.get_visible_item_count() == 6, "category 材料 filters to 6 rows")
	ui.set_category("任务")
	await create_timer(0.1).timeout
	check(ui.get_visible_item_count() == 3, "category 任务 filters to 3 rows")
	ui.set_category("杂项")
	await create_timer(0.1).timeout
	check(ui.get_visible_item_count() == 2, "category 杂项 filters to 2 rows")
	ui.set_category("全部")
	await create_timer(0.15).timeout
	check(ui.get_visible_item_count() == 25, "category 全部 restores 25 rows")

	# ---- empty filter state
	ui.switch_page(4)
	ui.set_category("装备")
	await create_timer(0.25).timeout
	check(ui.is_empty_state_visible() and ui.get_visible_item_count() == 0, "empty page + filter shows empty state")
	ui.switch_page(1)
	ui.set_category("全部")
	await create_timer(0.2).timeout

	# ---- selection + tooltip
	check(ui.select_item_by_id("huichun_pill", true), "select 回春丹 by id")
	await create_timer(0.25).timeout
	check(ui.is_detail_visible(), "detail card opens on selection")
	check(str(ui.get_selected_item().get("name", "")) == "回春丹", "selected item is 回春丹")
	ui.hover_index(8)
	await create_timer(0.22).timeout
	check(ui.is_tooltip_visible(), "hover shows tooltip")
	check(ui.tooltip.current_name() == "回春丹", "tooltip carries the item name")
	ui.clear_hover()
	await create_timer(0.2).timeout
	check(not ui.is_tooltip_visible(), "tooltip hides after unhover")

	# ---- keyboard selection moves
	var ev := key_event(KEY_RIGHT)
	check(ui.handle_key(ev), "arrow key handled")
	await process_frame
	check(ui.get_selected_item().get("name", "") == "凝神露", "right arrow moves selection to 凝神露")
	ev = key_event(KEY_UP)
	ui.handle_key(ev)
	await process_frame
	check(ui.get_selected_item().get("name", "") == "碧玉戒", "up arrow moves selection to 碧玉戒")

	# ---- sort (non destructive)
	check(ui.select_item_by_id("huichun_pill", true), "reselect 回春丹")
	ui.sort_current_page()
	await create_timer(0.35).timeout
	var sorted_items: Array = ui.state.page_all_items(1)
	var sorted_ok := true
	for i in range(1, sorted_items.size()):
		if int(sorted_items[i - 1].get("quality", 0)) < int(sorted_items[i].get("quality", 0)):
			sorted_ok = false
	check(sorted_ok, "sort puts higher quality first")
	check(int(sorted_items[0].get("quality", -1)) == 3, "sort starts with 绝品 items")
	check(ui.get_visible_item_count() == 25, "sort preserves all 25 rows")

	# ---- use via the detail button
	check(ui.select_item_by_id("huichun_pill", true), "select 回春丹 for use")
	var hp_before := int(ui.state.player["hp"])
	var stack_before := int(ui.state.item_by_id("huichun_pill")["stack"])
	ui.detail._btn_use.click_for_test()
	await create_timer(0.35).timeout
	check(int(ui.state.item_by_id("huichun_pill")["stack"]) == stack_before - 1, "use decrements stack by one")
	check(int(ui.state.player["hp"]) == mini(int(ui.state.player["hp_max"]), hp_before + 500), "use applies the heal effect")
	check(ui.get_capacity_text().contains("35 / 216"), "capacity unchanged while stack > 1")
	check(ui.is_detail_visible(), "detail card remains after a stackable use")

	var stack_mid := int(ui.state.item_by_id("huichun_pill")["stack"])
	ui.detail._btn_use.click_for_test()
	await create_timer(0.3).timeout
	check(int(ui.state.item_by_id("huichun_pill")["stack"]) == stack_mid - 1, "second use decrements again")

	# ---- use a stack=1 item, item disappears
	check(ui.select_item_by_id("jiuzhuan_pill", true), "select 九转还魂丹 (stack 1)")
	await create_timer(0.15).timeout
	ui.detail._btn_use.click_for_test()
	await create_timer(0.35).timeout
	check(ui.state.item_by_id("jiuzhuan_pill").is_empty(), "using the last unit removes the item")
	check(ui.get_capacity_text().contains("34 / 216"), "capacity updates to 34 / 216")
	check(ui.get_visible_item_count() == 24, "page 1 now shows 24 rows")
	check(not ui.is_detail_visible(), "detail closes when the item is gone")

	# ---- discard: cancel then confirm
	check(ui.select_item_by_id("huichun_pill", true), "select 回春丹 for discard")
	await create_timer(0.2).timeout
	ui.request_discard_current()
	await create_timer(0.2).timeout
	check(ui.is_confirm_open(), "discard opens the confirmation dialog")
	ui.confirm.cancel()
	await create_timer(0.2).timeout
	check(not ui.is_confirm_open(), "cancel closes the confirmation")
	check(not ui.state.item_by_id("huichun_pill").is_empty(), "cancel keeps the item")
	ui.request_discard_current()
	await create_timer(0.2).timeout
	ui.confirm.confirm()
	await create_timer(0.35).timeout
	check(ui.state.item_by_id("huichun_pill").is_empty(), "confirm discards the item")
	check(ui.get_capacity_text().contains("33 / 216"), "capacity updates to 33 / 216 after discard")
	check(not ui.is_confirm_open(), "confirmation closes after discard")

	# ---- sell
	check(ui.select_item_by_id("xuantie_ore", true), "select 玄铁矿石 for sale")
	await create_timer(0.15).timeout
	var silver_before := int(ui.state.player["silver"])
	ui.detail._btn_sell.click_for_test()
	await create_timer(0.35).timeout
	check(ui.state.item_by_id("xuantie_ore").is_empty(), "sold item leaves the bag")
	check(int(ui.state.player["silver"]) == silver_before + 37 * 80, "sale credits 37 x 80 silver")
	check(ui.get_capacity_text().contains("32 / 216"), "capacity updates after sale")

	check(ui.select_item_by_id("qingfeng_sword", true), "select a bound sword")
	await create_timer(0.15).timeout
	var sword_present_before := not ui.state.item_by_id("qingfeng_sword").is_empty()
	ui.sell_current()
	await create_timer(0.2).timeout
	check(sword_present_before and not ui.state.item_by_id("qingfeng_sword").is_empty(), "bound equipment cannot be sold")

	# ---- quest discard guard
	check(ui.select_item_by_id("gujuan_scrap", true), "select quest item 古卷残页")
	await create_timer(0.15).timeout
	ui.request_discard_current()
	await create_timer(0.15).timeout
	check(not ui.is_confirm_open(), "quest items cannot be discarded")
	check(not ui.state.item_by_id("gujuan_scrap").is_empty(), "quest item remains in the bag")

	# ---- filter popup API
	ui.filter_popup.show_popup("全部")
	await create_timer(0.1).timeout
	check(ui.is_filter_open(), "filter popup opens")
	ui.filter_popup.category_selected.emit("任务")
	await create_timer(0.2).timeout
	check(ui.get_category() == "任务", "filter popup applies a category")
	check(ui.get_visible_item_count() >= 1, "filtered page has rows")
	ui.filter_popup.hide_popup(true)
	ui.set_category("全部")
	await create_timer(0.15).timeout

	# ---- mouse cell path (single and double)
	ui.grid.demo_unhover()
	var cell := ui.grid.cell_for_item_id("ningshen_dew")
	check(cell != null, "found a cell for mouse test")
	if cell != null:
		var dew_stack := int(ui.state.item_by_id("ningshen_dew")["stack"])
		cell.press_for_test(false)
		await create_timer(0.2).timeout
		check(ui.is_detail_visible(), "single click opens the detail card")
		check(str(ui.get_selected_item().get("id", "")) == "ningshen_dew", "single click selects the cell item")
		cell = ui.grid.cell_for_item_id("ningshen_dew")
		cell.press_for_test(true)
		await create_timer(0.35).timeout
		check(int(ui.state.item_by_id("ningshen_dew")["stack"]) == dew_stack - 1, "double click uses the item")

	# ---- tab/paging keyboard
	ui.switch_page(1)
	ui.set_category("全部")
	await create_timer(0.15).timeout
	check(ui.handle_key(key_event(KEY_TAB)), "Tab is handled")
	await create_timer(0.2).timeout
	check(ui.get_page() == 2, "Tab advances to page 2")
	check(ui.handle_key(key_event(KEY_TAB, true)), "Shift+Tab is handled")
	await create_timer(0.2).timeout
	check(ui.get_page() == 1, "Shift+Tab returns to page 1")
	ui.handle_key(key_event(KEY_5))
	await create_timer(0.2).timeout
	check(ui.get_page() == 5, "number key jumps to page 5")
	ui.handle_key(key_event(KEY_1))
	await create_timer(0.2).timeout
	check(ui.get_page() == 1, "number key returns to page 1")

	# ---- ESC close / B reopen
	check(ui.handle_key(key_event(KEY_ESCAPE)), "Esc is handled")
	await create_timer(0.4).timeout
	check(not ui.is_panel_open(), "Esc closes the panel")
	check(ui.handle_key(key_event(KEY_B)), "B is handled")
	await create_timer(0.4).timeout
	check(ui.is_panel_open(), "B reopens the panel")

	# ---- close button path
	ui.close_button.pressed.emit()
	await create_timer(0.35).timeout
	check(not ui.is_panel_open(), "close button closes the panel")
	ui.open_panel(true)
	await create_timer(0.3).timeout
	check(ui.is_panel_open(), "API opens the panel again")

	print("checks=%d failures=%d" % [checks, failures])
	if failures == 0:
		print("INVENTORY_UI_SMOKE_OK")
		quit(0)
	else:
		printerr("INVENTORY_UI_SMOKE_FAILED")
		quit(1)
