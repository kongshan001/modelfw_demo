class_name BackpackUI
extends Control

# 1:1 remap of the 529x356 reference onto 1280x720 (see docs/fidelity-1to1.md).
const PANEL_POS := Vector2(17, 47)
const PANEL_SIZE := Vector2(1193, 659)
const TABS_POS := Vector2(653, 59)
const GRID_POS := Vector2(653, 121)
const SPLIT_X := 653.0

var state: InventoryState
var panel_root: Control
var panel_art: TextureRect
var paper_doll: PaperDoll
var stats_panel: PlayerStatsPanel
var tabs: TabBarUI
var grid: InventoryGrid
var capacity_label: Label
var filter_button: UIButton
var coin_gold: CoinRow
var coin_silver: CoinRow
var sort_button: UIButton
var close_button: TextureButton
var side_nav: SideNav
var detail: DetailCard
var tooltip: ItemTooltip
var toast: Toast
var fx: FxLayer
var confirm: ConfirmDialog
var filter_popup: FilterPopup
var placeholder: PlaceholderOverlay
var reopen_root: Control
var align_overlay: AlignOverlay
var title_label: Label

var current_page := 1
var current_category := "全部"
var selected_item: Dictionary = {}
var selected_mode := "bag"
var selected_source_index := -1
var panel_open := false
var _panel_tween: Tween
var _close_tween: Tween
var _initialized := false
var _overlay_accum := 0.0


func _ready() -> void:
	state = InventoryState.new()
	state.load_from("res://data/items.json")
	_build()
	_wire()
	_initialized = true
	call_deferred("_initial_open")


func _initial_open() -> void:
	open_panel(true)
	_switch_page_internal(1, false)


func _process(delta: float) -> void:
	if align_overlay != null and align_overlay.visible:
		_overlay_accum += delta
		if _overlay_accum >= 0.20:
			_overlay_accum = 0.0
			_refresh_align_entries()


# ---------------------------------------------------------------- F1 alignment check

func set_align_overlay_visible(on: bool) -> void:
	if align_overlay == null:
		return
	align_overlay.visible = on and panel_open
	if align_overlay.visible:
		_refresh_align_entries()


func is_align_overlay_visible() -> bool:
	return align_overlay != null and align_overlay.visible


func align_report() -> Dictionary:
	if align_overlay == null:
		return {"rows": [], "max_dev_pct": 999.0, "count": 0}
	return align_overlay.report()


func _refresh_align_entries() -> void:
	if align_overlay == null:
		return
	var list: Array = []
	var rr := AlignOverlay.REF_RECTS
	list.append({"name": "面板", "target": AlignOverlay.ref_rect_to_target(rr["panel"]),
		"actual": Rect2(panel_art.position, panel_art.size)})
	list.append({"name": "标题", "target": AlignOverlay.ref_rect_to_target(rr["title"]),
		"actual": Rect2(title_label.position, title_label.size), "anchor": true})
	list.append({"name": "关闭钮", "target": AlignOverlay.ref_rect_to_target(rr["close"]),
		"actual": Rect2(close_button.position, close_button.size), "anchor": true})
	list.append({"name": "页签", "target": AlignOverlay.ref_rect_to_target(rr["tabs"]),
		"actual": Rect2(tabs.position, tabs.size)})
	list.append({"name": "网格", "target": AlignOverlay.ref_rect_to_target(rr["grid"]),
		"actual": Rect2(grid.position, Vector2(542, 449))})
	list.append({"name": "侧导航", "target": AlignOverlay.ref_rect_to_target(rr["nav"]),
		"actual": Rect2(side_nav.position + Vector2(-8, 0), Vector2(78, SideNav.TAB_H))})
	var bars := stats_panel.bar_rects()
	list.append({"name": "气血条", "target": AlignOverlay.ref_rect_to_target(rr["hp"]),
		"actual": bars["hp"]})
	list.append({"name": "魔法条", "target": AlignOverlay.ref_rect_to_target(rr["mp"]),
		"actual": bars["mp"], "label": false})
	list.append({"name": "铜币", "target": AlignOverlay.ref_rect_to_target(rr["coin_gold"]),
		"actual": coin_gold.pill_rect()})
	list.append({"name": "银两", "target": AlignOverlay.ref_rect_to_target(rr["coin_silver"]),
		"actual": coin_silver.pill_rect(), "label": false})
	list.append({"name": "整理", "target": AlignOverlay.ref_rect_to_target(rr["sort"]),
		"actual": Rect2(sort_button.position, sort_button.size)})
	var slot_names := ["法宝", "鞋履", "衣甲", "头冠", "项链", "戒指", "戒指", "武器"]
	for i in range(PaperDoll.SLOT_KEYS.size()):
		list.append({
			"name": "槽·" + slot_names[i],
			"target": AlignOverlay.ref_slot_target(i),
			"actual": paper_doll.slot_rect(PaperDoll.SLOT_KEYS[i]),
			"label": i == 0,
		})
	# Added controls (not in the reference): flagged magenta and excluded from max.
	var cap_rect := Rect2(capacity_label.position, capacity_label.size)
	var filter_rect := Rect2(filter_button.position, filter_button.size)
	list.append({"name": "容量(新增)", "target": cap_rect, "actual": cap_rect,
		"added": true, "counted": false})
	list.append({"name": "筛选(新增)", "target": filter_rect, "actual": filter_rect,
		"added": true, "counted": false, "label": false})
	align_overlay.set_entries(list)


func _build() -> void:
	theme = ThemeKit.make_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)

	panel_root = Control.new()
	panel_root.position = Vector2.ZERO
	panel_root.size = Vector2(1280, 720)
	panel_root.pivot_offset = Vector2(630, 379)
	panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.04, 0.06, 0.22)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(dim)

	panel_art = TextureRect.new()
	panel_art.texture = ThemeKit.ui_tex("panel")
	panel_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel_art.stretch_mode = TextureRect.STRETCH_SCALE
	panel_art.position = PANEL_POS
	panel_art.size = PANEL_SIZE
	panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_root.add_child(panel_art)

	paper_doll = PaperDoll.new()
	paper_doll.setup(state)
	paper_doll.position = Vector2(60, 47)
	panel_root.add_child(paper_doll)

	stats_panel = PlayerStatsPanel.new()
	stats_panel.setup(state)
	stats_panel.position = Vector2(60, 505)
	panel_root.add_child(stats_panel)

	tabs = TabBarUI.new()
	tabs.setup()
	tabs.position = TABS_POS
	panel_root.add_child(tabs)

	# The reference has no capacity bar above the grid; keep the functional
	# text + filter as a low-profile auxiliary strip at the bottom-left.
	capacity_label = ThemeKit.make_label(panel_root, "背包容量 35 / 216 · 第 1 / 5 页", 11, Color("2f5c86"),
		Vector2(653, 578), Vector2(340, 20), HORIZONTAL_ALIGNMENT_LEFT, ThemeKit.body_font(), 1,
		Color(1, 1, 1, 0.35))
	capacity_label.modulate = Color(1, 1, 1, 0.90)

	filter_button = UIButton.new()
	filter_button.setup("筛选 全部 ▾", UIButton.Kind.SLATE, Vector2(124, 20), 11)
	filter_button.position = Vector2(1066, 578)
	panel_root.add_child(filter_button)

	grid = InventoryGrid.new()
	grid.setup()
	grid.position = GRID_POS
	panel_root.add_child(grid)

	coin_gold = CoinRow.new()
	coin_gold.setup("gold", int(state.player["gold"]))
	coin_gold.position = Vector2(656, 604)
	panel_root.add_child(coin_gold)
	coin_silver = CoinRow.new()
	coin_silver.setup("silver", int(state.player["silver"]))
	coin_silver.position = Vector2(656, 656)
	panel_root.add_child(coin_silver)

	sort_button = UIButton.new()
	sort_button.setup("整 理", UIButton.Kind.GOLD, Vector2(182, 61), 28)
	sort_button.position = Vector2(994, 613)
	panel_root.add_child(sort_button)

	_build_title()
	_build_close()
	_build_side_nav()

	detail = DetailCard.new()
	detail.setup(state)
	panel_root.add_child(detail)

	align_overlay = AlignOverlay.new()
	align_overlay.setup()
	panel_root.add_child(align_overlay)

	_build_reopen()

	tooltip = ItemTooltip.new()
	tooltip.setup()
	add_child(tooltip)

	fx = FxLayer.new()
	fx.setup()
	add_child(fx)

	toast = Toast.new()
	toast.setup()
	add_child(toast)

	filter_popup = FilterPopup.new()
	filter_popup.setup(InventoryState.CATEGORIES)
	add_child(filter_popup)

	placeholder = PlaceholderOverlay.new()
	placeholder.setup()
	add_child(placeholder)

	confirm = ConfirmDialog.new()
	confirm.setup()
	add_child(confirm)

	_sync_labels()
	grid.refresh(state, current_page, current_category)
	panel_root.visible = true
	panel_root.modulate.a = 1.0


func _build_title() -> void:
	# Reference title: pale ice calligraphy directly over the scene, no plaque.
	var glow := ThemeKit.glow_texture_rect("glow", Color(0.60, 0.92, 1.0, 0.10))
	glow.position = Vector2(140, -22)
	glow.size = Vector2(170, 96)
	panel_root.add_child(glow)
	title_label = ThemeKit.make_label(panel_root, "物品", 38, Color("eaf8ff"),
		Vector2(160, -3), Vector2(104, 46), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.title_font(),
		5, Color("123a5a"))
	title_label.modulate = Color(1, 1, 1, 0.98)


func _build_close() -> void:
	var glow := ThemeKit.glow_texture_rect("glow", Color(1.0, 0.84, 0.5, 0.22))
	glow.position = Vector2(1186, -10)
	glow.size = Vector2(96, 96)
	panel_root.add_child(glow)
	close_button = TextureButton.new()
	close_button.texture_normal = ThemeKit.ui_tex("close")
	close_button.ignore_texture_size = true
	close_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close_button.position = Vector2(1198, 6)
	close_button.size = Vector2(72, 72)
	close_button.pivot_offset = Vector2(36, 36)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel_root.add_child(close_button)
	close_button.mouse_entered.connect(func() -> void:
		var tw := close_button.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_button, "scale", Vector2(1.08, 1.08), 0.12)
		tw.parallel().tween_property(glow, "modulate:a", 0.42, 0.12))
	close_button.mouse_exited.connect(func() -> void:
		var tw := close_button.create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(close_button, "scale", Vector2.ONE, 0.12)
		tw.parallel().tween_property(glow, "modulate:a", 0.22, 0.12))
	close_button.pressed.connect(close_panel)


func _build_side_nav() -> void:
	side_nav = SideNav.new()
	side_nav.setup()
	side_nav.position = Vector2(1198, 87)
	panel_root.add_child(side_nav)


func _build_reopen() -> void:
	reopen_root = Control.new()
	reopen_root.position = Vector2.ZERO
	reopen_root.size = Vector2(1280, 720)
	reopen_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reopen_root.visible = false
	add_child(reopen_root)
	var glow := ThemeKit.glow_texture_rect("glow", Color(0.55, 0.9, 1.0, 0.18))
	glow.position = Vector2(420, 190)
	glow.size = Vector2(440, 330)
	reopen_root.add_child(glow)
	var title := ThemeKit.make_label(reopen_root, "云 璃 背 包", 34, ThemeKit.GOLD_BRIGHT,
		Vector2(440, 252), Vector2(400, 52), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.title_font(),
		4, Color(0.03, 0.08, 0.12, 0.9))
	title.modulate.a = 0.95
	var sub := ThemeKit.make_label(reopen_root, "原 创 物 品 界 面", 12, Color(0.84, 0.93, 0.98, 0.7),
		Vector2(440, 298), Vector2(400, 24), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.body_font(), 2,
		Color(0.02, 0.06, 0.1, 0.8))
	var btn := UIButton.new()
	btn.setup("打 开 背 包", UIButton.Kind.GOLD, Vector2(220, 56), 20)
	btn.position = Vector2(530, 350)
	reopen_root.add_child(btn)
	btn.pressed.connect(func() -> void: open_panel(true))
	ThemeKit.make_label(reopen_root, "按 B / I 打开背包 · Esc 关闭", 12, Color(0.86, 0.94, 0.97, 0.62),
		Vector2(440, 422), Vector2(400, 22), HORIZONTAL_ALIGNMENT_CENTER, ThemeKit.body_font(), 2,
		Color(0.02, 0.06, 0.1, 0.7))


func _wire() -> void:
	tabs.page_changed.connect(func(i: int) -> void: _switch_page_internal(i + 1, true))
	grid.item_clicked.connect(_on_grid_clicked)
	grid.item_double_clicked.connect(_on_grid_double)
	grid.item_hovered.connect(_on_grid_hover)
	grid.item_unhovered.connect(func() -> void: tooltip.hide_tooltip())
	grid.selection_changed.connect(_on_grid_selection_changed)
	grid.page_step.connect(func(d: int) -> void: _switch_page_internal(current_page + d, true))
	grid.page_requested.connect(func(p: int) -> void: _switch_page_internal(p, true))
	paper_doll.slot_hovered.connect(func(data: Dictionary, pos: Vector2) -> void:
		tooltip.show_for(data, pos, true))
	paper_doll.slot_unhovered.connect(func() -> void: tooltip.hide_tooltip())
	paper_doll.slot_clicked.connect(_on_equip_clicked)
	paper_doll.codex_pressed.connect(func() -> void: placeholder.show_kind("compendium"))
	sort_button.pressed.connect(sort_current_page)
	filter_button.pressed.connect(_open_filter)
	filter_popup.category_selected.connect(func(cat: String) -> void:
		set_category(cat)
		toast.show_message("已筛选：%s" % cat, Color(0.78, 0.93, 1.0)))
	filter_popup.closed.connect(func() -> void: pass)
	coin_gold.plus_pressed.connect(func(kind: String) -> void:
		toast.show_message("钱庄入口为演示占位", Color(1.0, 0.84, 0.5)))
	coin_silver.plus_pressed.connect(func(kind: String) -> void:
		toast.show_message("钱庄入口为演示占位", Color(1.0, 0.84, 0.5)))
	side_nav.nav_selected.connect(_on_nav)
	placeholder.closed.connect(func() -> void: side_nav.set_active("bag"))
	detail.use_requested.connect(func(item: Dictionary) -> void: use_current())
	detail.discard_requested.connect(func(item: Dictionary) -> void: request_discard_current())
	detail.sell_requested.connect(func(item: Dictionary) -> void: sell_current())
	confirm.confirmed.connect(_perform_discard)
	confirm.cancelled.connect(func() -> void: pass)


# ---------------------------------------------------------------- open / close

func open_panel(animate: bool = true) -> void:
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	panel_open = true
	panel_root.visible = true
	reopen_root.visible = false
	reopen_root.modulate.a = 1.0
	if animate:
		panel_root.scale = Vector2(0.965, 0.965)
		panel_root.modulate.a = 0.0
		_panel_tween = create_tween().set_parallel(true)
		_panel_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_panel_tween.tween_property(panel_root, "scale", Vector2.ONE, 0.20)
		_panel_tween.tween_property(panel_root, "modulate:a", 1.0, 0.20)
	else:
		panel_root.scale = Vector2.ONE
		panel_root.modulate.a = 1.0


func close_panel() -> void:
	if not panel_open:
		return
	panel_open = false
	if align_overlay != null:
		align_overlay.visible = false
	tooltip.hide_tooltip()
	toast.clear()
	detail.close_card()
	filter_popup.hide_popup(false)
	if placeholder.is_open():
		placeholder.hide_overlay()
	if confirm.is_open():
		confirm.cancel()
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true)
	_panel_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(panel_root, "scale", Vector2(0.94, 0.94), 0.18)
	_panel_tween.tween_property(panel_root, "modulate:a", 0.0, 0.18)
	_panel_tween.chain().tween_callback(func() -> void:
		panel_root.visible = false
		reopen_root.visible = true
		reopen_root.modulate.a = 0.0
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(reopen_root, "modulate:a", 1.0, 0.16))


func is_panel_open() -> bool:
	return panel_open


# ---------------------------------------------------------------- pages / filters

func _switch_page_internal(page: int, animate_tab: bool) -> void:
	var p := ((page - 1) % InventoryState.PAGE_COUNT + InventoryState.PAGE_COUNT) % InventoryState.PAGE_COUNT + 1
	current_page = p
	tabs.set_active(p - 1, animate_tab)
	grid.refresh(state, current_page, current_category)
	detail.close_card()
	tooltip.hide_tooltip()
	selected_item = {}
	selected_source_index = -1
	selected_mode = "bag"
	_sync_labels()


func switch_page(page: int) -> void:
	_switch_page_internal(page, true)


func next_page(delta: int) -> void:
	_switch_page_internal(current_page + delta, true)


func set_category(cat: String) -> void:
	if not InventoryState.CATEGORIES.has(cat):
		return
	current_category = cat
	filter_button.set_text("筛选 " + cat + " ▾")
	grid.refresh(state, current_page, current_category)
	detail.close_card()
	tooltip.hide_tooltip()
	selected_item = {}
	selected_source_index = -1
	_sync_labels()


func _open_filter() -> void:
	if filter_popup.is_open():
		filter_popup.hide_popup(true)
	else:
		tooltip.hide_tooltip()
		detail.close_card()
		filter_popup.show_popup(current_category)


func _on_nav(key: String) -> void:
	match key:
		"bag":
			if placeholder.is_open():
				placeholder.hide_overlay()
		"alchemy":
			tooltip.hide_tooltip()
			detail.close_card()
			placeholder.show_kind("alchemy")
		"codex":
			tooltip.hide_tooltip()
			detail.close_card()
			placeholder.show_kind("codex")


# ---------------------------------------------------------------- selection

func _on_grid_clicked(item: Dictionary, index: int) -> void:
	_select_bag_item(item, index, true)


func _on_grid_double(item: Dictionary, index: int) -> void:
	_select_bag_item(item, index, true)
	use_current()


func _on_grid_selection_changed(index: int, item: Dictionary) -> void:
	selected_item = item
	selected_source_index = index
	selected_mode = "bag"
	if detail.is_showing():
		detail.show_for(item, "bag")


func _on_grid_hover(item: Dictionary, pos: Vector2) -> void:
	tooltip.show_for(item, pos, false)


func _on_equip_clicked(data: Dictionary) -> void:
	selected_item = data
	selected_mode = "equip"
	selected_source_index = -1
	grid.clear_selection()
	tooltip.hide_tooltip()
	detail.show_for(data, "equipped")


func _select_bag_item(item: Dictionary, index: int, open_detail: bool) -> void:
	selected_item = item
	selected_mode = "bag"
	selected_source_index = index
	tooltip.hide_tooltip()
	if open_detail:
		detail.show_for(item, "bag")
	elif detail.is_showing():
		detail.show_for(item, "bag")


func select_item_by_id(id: String, open_detail: bool = true) -> bool:
	var item := state.item_by_id(id)
	if item.is_empty():
		return false
	var page := int(item["page"])
	if current_category != "全部":
		set_category("全部")
	if current_page != page:
		_switch_page_internal(page, true)
	var items := grid.items_snapshot()
	var idx := -1
	for i in range(items.size()):
		if str(items[i]["id"]) == id:
			idx = i
			break
	if idx < 0:
		return false
	grid.set_selected_index(idx, false)
	_select_bag_item(item, idx, open_detail)
	return true


func select_index(index: int, open_detail: bool = true) -> bool:
	var items := grid.items_snapshot()
	if index < 0 or index >= items.size():
		return false
	grid.set_selected_index(index, false)
	_select_bag_item(items[index], index, open_detail)
	return true


func hover_index(index: int) -> void:
	grid.demo_hover(index)


func clear_hover() -> void:
	grid.demo_unhover()


# ---------------------------------------------------------------- actions

func use_current() -> void:
	if selected_mode != "bag" or selected_item.is_empty():
		toast.show_message("请先在背包中选中物品", Color(1.0, 0.84, 0.5))
		return
	var id := str(selected_item["id"])
	if not state.can_use(selected_item):
		toast.show_message("该物品不可直接使用", Color(1.0, 0.78, 0.68))
		return
	var cell := grid.cell_for_item_id(id)
	var center := cell.get_center_global() if cell != null else Vector2(800, 400)
	var result := state.use_item(id)
	if not bool(result.get("ok", false)):
		toast.show_message(str(result.get("reason", "无法使用")), Color(1.0, 0.78, 0.68))
		return
	fx.burst(center, Color(1.0, 0.92, 0.62), 28)
	if cell != null:
		cell.play_use_flash()
	stats_panel.update_values(true)
	_sync_labels()
	toast.show_message(str(result.get("message", "已使用")) + " · " + str(result.get("name", "")))
	if bool(result.get("removed", false)):
		detail.close_card()
		selected_item = {}
		selected_source_index = -1
		grid.clear_selection()
		grid.refresh(state, current_page, current_category)
	else:
		var updated := state.item_by_id(id)
		selected_item = updated
		if cell != null:
			cell.set_item(updated, cell.index)
		detail.show_for(updated, "bag")


func sell_current() -> void:
	if selected_mode != "bag" or selected_item.is_empty():
		toast.show_message("请先选中可出售的物品", Color(1.0, 0.84, 0.5))
		return
	var id := str(selected_item["id"])
	var cell := grid.cell_for_item_id(id)
	var center := cell.get_center_global() if cell != null else Vector2(800, 400)
	var result := state.sell_item(id)
	if not bool(result.get("ok", false)):
		toast.show_message(str(result.get("reason", "无法出售")), Color(1.0, 0.78, 0.68))
		return
	fx.burst(center, Color(0.98, 0.85, 0.45), 24)
	_sync_labels()
	detail.close_card()
	toast.show_message(str(result.get("message", "已出售")))
	selected_item = {}
	selected_source_index = -1
	grid.clear_selection()
	grid.refresh(state, current_page, current_category)


func request_discard_current() -> void:
	if selected_mode != "bag" or selected_item.is_empty():
		toast.show_message("请先选中物品", Color(1.0, 0.84, 0.5))
		return
	if not state.can_discard(selected_item):
		toast.show_message("任务物品不可丢弃", Color(1.0, 0.78, 0.68))
		return
	tooltip.hide_tooltip()
	filter_popup.hide_popup(false)
	confirm.show_for(selected_item)


func _perform_discard() -> void:
	var item := confirm.item()
	if item.is_empty():
		return
	var result := state.discard_item(str(item["id"]))
	if not bool(result.get("ok", false)):
		toast.show_message(str(result.get("reason", "无法丢弃")), Color(1.0, 0.78, 0.68))
		return
	_sync_labels()
	detail.close_card()
	selected_item = {}
	selected_source_index = -1
	grid.clear_selection()
	grid.refresh(state, current_page, current_category)
	toast.show_message(str(result.get("message", "已丢弃")))


func sort_current_page() -> void:
	var keep_id := str(selected_item.get("id", ""))
	var old_map := grid.get_position_map()
	state.sort_page(current_page)
	grid.refresh(state, current_page, current_category, keep_id, old_map)
	_sync_labels()
	toast.show_message("已按品质与类型整理", Color(0.8, 1.0, 0.9))
	if keep_id != "":
		var it := state.item_by_id(keep_id)
		if not it.is_empty():
			selected_item = it
			if detail.is_showing():
				detail.show_for(it, "bag")
	else:
		detail.close_card()


func _sync_labels() -> void:
	if capacity_label != null:
		capacity_label.text = "背包容量 %d / %d · 第 %d / %d 页" % [
			state.used_capacity(), state.total_capacity(), current_page, InventoryState.PAGE_COUNT]
	if coin_gold != null:
		coin_gold.set_value(int(state.player["gold"]))
	if coin_silver != null:
		coin_silver.set_value(int(state.player["silver"]))


# ---------------------------------------------------------------- keyboard

func handle_key(ev: InputEventKey) -> bool:
	if not ev.pressed or ev.echo:
		return false
	var key := ev.keycode
	if key == KEY_F1:
		set_align_overlay_visible(not is_align_overlay_visible())
		return true
	if confirm.is_open():
		if key == KEY_ESCAPE:
			confirm.cancel()
		elif key == KEY_ENTER or key == KEY_KP_ENTER:
			confirm.confirm()
		return true
	if placeholder.is_open():
		if key == KEY_ESCAPE:
			placeholder.hide_overlay()
			side_nav.set_active("bag")
		return true
	if filter_popup.is_open():
		if key == KEY_ESCAPE:
			filter_popup.hide_popup(true)
		return true
	if not panel_open:
		if key in [KEY_B, KEY_I, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			open_panel(true)
			return true
		return false
	match key:
		KEY_ESCAPE:
			close_panel()
			return true
		KEY_TAB:
			next_page(-1 if ev.shift_pressed else 1)
			return true
		KEY_LEFT:
			grid.move_selection(-1, 0)
			return true
		KEY_RIGHT:
			grid.move_selection(1, 0)
			return true
		KEY_UP:
			grid.move_selection(0, -1)
			return true
		KEY_DOWN:
			grid.move_selection(0, 1)
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if selected_item.is_empty():
				if grid.item_count() > 0:
					grid.set_selected_index(0)
				else:
					toast.show_message("此页没有可用物品", Color(1.0, 0.84, 0.5))
					return true
			use_current()
			return true
		KEY_SPACE:
			if not selected_item.is_empty():
				if detail.is_showing():
					detail.close_card()
				else:
					detail.show_for(selected_item, "bag" if selected_mode == "bag" else "equipped")
			return true
		KEY_1:
			_switch_page_internal(1, true)
			return true
		KEY_2:
			_switch_page_internal(2, true)
			return true
		KEY_3:
			_switch_page_internal(3, true)
			return true
		KEY_4:
			_switch_page_internal(4, true)
			return true
		KEY_5:
			_switch_page_internal(5, true)
			return true
		KEY_B, KEY_I:
			close_panel()
			return true
	return false


# ---------------------------------------------------------------- test accessors

func get_visible_item_count() -> int:
	return grid.item_count()


func get_page() -> int:
	return current_page


func get_category() -> String:
	return current_category


func get_capacity_text() -> String:
	return capacity_label.text


func get_selected_item() -> Dictionary:
	return selected_item


func is_detail_visible() -> bool:
	return detail.visible and detail.is_showing()


func is_tooltip_visible() -> bool:
	return tooltip.visible and tooltip.modulate.a > 0.01


func is_confirm_open() -> bool:
	return confirm.is_open()


func is_empty_state_visible() -> bool:
	return grid.is_empty_state_visible()


func is_filter_open() -> bool:
	return filter_popup.is_open()


func get_align_report() -> Dictionary:
	return align_report()
