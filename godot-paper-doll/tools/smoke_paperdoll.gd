extends SceneTree

# Headless 验收：
#   17 槽位 / 全变体 / 独立染色 / 8 方向 / 4 动作骨长与运动 /
#   16 预设 / 随机 / z-order（正面↔背面） / JSON 存读 / 容器裁剪 / 对照弹层。
# 用法：godot --headless --path godot-paper-doll -s tools/smoke_paperdoll.gd

var _fails: Array[String] = []


func _initialize() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await create_timer(0.25).timeout

	var slot_ids: Array[String] = []
	var variant_total := 0
	var min_variants := 999
	for slot in DollData.SLOTS:
		slot_ids.append(slot["id"])
		variant_total += slot["variants"].size()
		min_variants = mini(min_variants, slot["variants"].size())
		_check(DollData.palette_for(slot["id"]).size() >= 6,
				"palette too small for " + str(slot["id"]))
		var seen := {}
		for variant in slot["variants"]:
			_check(not seen.has(variant["id"]),
					"duplicate variant %s/%s" % [slot["id"], variant["id"]])
			seen[variant["id"]] = true
			_check(not str(variant["label"]).is_empty(), "empty label in " + str(slot["id"]))
	_check(slot_ids.size() == 17, "expected 17 slots, got %d" % slot_ids.size())
	_check(min_variants >= 4, "a slot has fewer than 4 variants (%d)" % min_variants)
	_check(variant_total == 83, "expected 83 variants, got %d" % variant_total)
	var required := [
		"body", "head", "hair", "eyes", "hat", "shirt", "pants", "shoes", "weapon",
		"cape", "backpack", "gloves", "belt", "mask", "ear", "accessory", "aura",
	]
	for need in required:
		_check(need in slot_ids, "missing semantic slot " + str(need))

	var issues := PartPainter.validate()
	_check(issues.is_empty(), "painter gaps: " + str(issues))
	_check(PartPainter.PAINTED.size() == 17, "painter slot table must have 17 entries")
	_check(FileAccess.file_exists(DollData.PRESET_PATH), "preset file missing")

	_check(DollData.DIRS.size() == 8, "expected 8 directions")
	_check(DollData.ACTIONS.size() == 4, "expected 4 actions")
	_check(DollData.combination_count() > 1.0e15, "combination space too small")

	# ── UI 骨架 ─────────────────────────────────────────────────────────
	_check(scene.slot_buttons.size() == 17, "slot buttons %d != 17" % scene.slot_buttons.size())
	_check(scene.dir_buttons.size() == 8, "direction buttons %d != 8" % scene.dir_buttons.size())
	_check(scene.cards.size() == 16, "lineup cards %d != 16" % scene.cards.size())
	_check(scene.color_buttons.size() >= 6, "color swatches too few")
	_check(scene.preview_clip_ok(), "studio preview is not clipped")
	for card in scene.cards:
		_check(card.clip_ok(), "lineup card preview is not clipped")
	_check(scene.get_studio() != null, "studio renderer missing")
	_check(scene.name_label.text == scene.get_doll_name(), "name label out of sync")
	_check(not scene.status_label.text.is_empty(), "status label empty")
	_check(scene.get_preset_count() == 16, "preset count %d != 16" % scene.get_preset_count())

	# ── 全变体 + 染色 ───────────────────────────────────────────────────
	for slot in DollData.SLOTS:
		var slot_id: String = slot["id"]
		for variant in slot["variants"]:
			var variant_id: String = variant["id"]
			if not scene.set_slot_variant(slot_id, variant_id):
				_check(false, "set variant failed %s/%s" % [slot_id, variant_id])
				continue
			_check(str(scene.get_outfit()[slot_id]["variant"]) == variant_id,
					"variant not stored %s/%s" % [slot_id, variant_id])
		var palette := DollData.palette_for(slot_id)
		var color: Color = palette[slot_ids.find(slot_id) % palette.size()]
		_check(scene.set_slot_color(slot_id, color), "set color failed " + slot_id)
		_check((scene.get_outfit()[slot_id]["color"] as Color).is_equal_approx(color),
				"color not stored " + slot_id)

	scene.set_slot_color("shirt", Color("#e86a5c"))
	scene.set_slot_color("pants", Color("#5a7fb8"))
	_check((scene.get_outfit()["shirt"]["color"] as Color).is_equal_approx(Color("#e86a5c")),
			"shirt tint overwritten")
	_check((scene.get_outfit()["pants"]["color"] as Color).is_equal_approx(Color("#5a7fb8")),
			"pants tint not independent")

	var all_colors := DollData.palette_for("weapon")
	for i in all_colors.size():
		scene.set_slot_color("weapon", all_colors[i])
		_check((scene.get_outfit()["weapon"]["color"] as Color).is_equal_approx(all_colors[i]),
				"weapon color %d not applied" % i)

	# ── 8 方向 + 级联位移 ───────────────────────────────────────────────
	var front_head := Vector2.ZERO
	for d in DollData.DIRS.size():
		scene.set_direction(d)
		_check(scene.get_direction() == d, "direction %d not stored" % d)
		var pose := DollPose.compute(0.37, "walk", d)
		for key in [
			"hip", "chest", "neck", "head", "shoulder_l", "shoulder_r", "elbow_l", "elbow_r",
			"hand_l", "hand_r", "hip_l", "hip_r", "knee_l", "knee_r", "foot_l", "foot_r",
		]:
			_check(_finite_vec(pose[key]), "pose %s/%d has non-finite %s" % [key, d, key])
		if d == 0:
			front_head = pose["head"]
		if d == 6:
			_check(pose["head"].x - front_head.x > 1.5, "side head shift missing")
			_check(scene.get_studio().scale.x > 0.0, "right-facing studio should not be mirrored")
	scene.set_direction(2)
	_check(scene.get_studio().scale.x < 0.0, "left-facing studio should be mirrored")
	scene.set_direction(6)

	# ── 4 动作：骨长不变、关键关节确实在动 ─────────────────────────────
	for d in DollData.DIRS.size():
		for action in ["idle", "walk", "attack", "hit"]:
			for sample in [0.0, 0.17, 0.35, 0.62, 0.9]:
				var pose := DollPose.compute(sample, action, d)
				_check(absf((pose["elbow_l"] as Vector2).distance_to(pose["shoulder_l"]) - DollPose.UPPER_ARM) < 0.01,
						"upper arm length broken %s/%d" % [action, d])
				_check(absf((pose["hand_r"] as Vector2).distance_to(pose["elbow_r"]) - DollPose.FOREARM) < 0.01,
						"forearm length broken %s/%d" % [action, d])
				_check(absf((pose["knee_l"] as Vector2).distance_to(pose["hip_l"]) - DollPose.THIGH) < 0.01,
						"thigh length broken %s/%d" % [action, d])
				_check(absf((pose["foot_r"] as Vector2).distance_to(pose["knee_r"]) - DollPose.SHIN) < 0.01,
						"shin length broken %s/%d" % [action, d])

	var walk_a: Vector2 = DollPose.compute(0.10, "walk", 6)["foot_r"]
	var walk_b: Vector2 = DollPose.compute(0.30, "walk", 6)["foot_r"]
	_check(walk_a.distance_to(walk_b) > 1.0, "walk has no stride")
	# 评审 P0-4 后 attack 增加了 0.28–0.40 的蓄力停顿；采样点改为停顿末与挥砍中段。
	var atk_a: Vector2 = DollPose.compute(0.30, "attack", 6)["hand_r"]
	var atk_b: Vector2 = DollPose.compute(0.52, "attack", 6)["hand_r"]
	_check(atk_a.distance_to(atk_b) > 4.0, "attack arm does not travel")
	_check(float(DollPose.compute(0.52, "attack", 6)["slash"]) > 0.2, "attack slash FX missing")
	# 3 个 authored keys：预备 / 冲击 / 跟随的姿势必须互不相同。
	var k_a: Vector2 = DollPose.compute(0.21, "attack", 6)["hand_r"]
	var k_b: Vector2 = DollPose.compute(0.47, "attack", 6)["hand_r"]
	var k_c: Vector2 = DollPose.compute(0.78, "attack", 6)["hand_r"]
	_check(k_a.distance_to(k_b) > 3.0 and k_b.distance_to(k_c) > 3.0,
			"attack authored keys are not distinct")
	_check(float(DollPose.compute(0.01, "hit", 6)["hit"]) > 0.5, "hit impulse missing")
	var idle_a: float = DollPose.compute(0.0, "idle", 0)["hip"].y
	var idle_b: float = DollPose.compute(0.75, "idle", 0)["hip"].y
	_check(absf(idle_a - idle_b) > 0.15, "idle breathing missing")

	# ── z-order：17 层唯一、升序、正面/背面深度翻转 ────────────────────
	# 先固定披风为短披风：围巾按语义要压在衣领上，不属于“身后披风”这一层。
	scene.set_slot_variant("cape", "short")
	scene.set_direction(0)
	var front_order := DollData.draw_order(0, scene.get_outfit())
	var back_order := DollData.draw_order(4, scene.get_outfit())
	_check(front_order.size() == 17, "draw order size %d != 17" % front_order.size())
	_check(back_order.size() == 17, "back draw order size != 17")
	var seen_slots := {}
	var last_z := -9999
	for entry in front_order:
		_check(not seen_slots.has(entry["id"]), "duplicate layer " + str(entry["id"]))
		seen_slots[entry["id"]] = true
		_check(int(entry["z"]) >= last_z, "draw order not sorted")
		last_z = int(entry["z"])
	_check(_z(front_order, "weapon") > _z(front_order, "body"), "front weapon should be over body")
	_check(_z(front_order, "cape") < _z(front_order, "shirt"), "front cape should be behind shirt")
	_check(_z(front_order, "backpack") < _z(front_order, "body"), "front backpack should be behind body")
	_check(_z(back_order, "weapon") < _z(back_order, "body"), "back weapon should be behind body")
	_check(_z(back_order, "cape") > _z(back_order, "shirt"), "back cape should cover shirt")
	_check(_z(back_order, "backpack") > _z(back_order, "body"), "back backpack should be visible")
	scene.set_direction(4)
	_check(scene.get_effective_z("weapon") < scene.get_effective_z("body"),
			"effective z for back weapon wrong")
	scene.set_direction(0)
	_check(scene.get_effective_z("weapon") > scene.get_effective_z("body"),
			"effective z for front weapon wrong")

	# ── 预设 / 阵容 / 单卡随机 ──────────────────────────────────────────
	var lineup: Array = scene.get_lineup()
	_check(lineup.size() == 16, "lineup size %d != 16" % lineup.size())
	var names := {}
	for entry in lineup:
		_check(not names.has(entry["name"]), "duplicate preset name " + str(entry["name"]))
		names[entry["name"]] = true
		_check(int(entry["direction"]) >= 0 and int(entry["direction"]) < 8, "bad preset direction")
		_check(DollData.is_action(str(entry["action"])), "bad preset action")
		_check(_outfit_size(entry["outfit"]) == 17, "preset outfit incomplete")
	for card in scene.cards:
		_check(_outfit_size(card.entry["outfit"]) == 17, "card outfit incomplete")
		_check(card.doll.direction == int(card.entry["direction"]), "card direction mismatch")

	var signatures := {}
	for i in 8:
		scene.randomize_current()
		signatures[_sig(scene.get_outfit())] = true
		_check(_outfit_size(scene.get_outfit()) == 17, "random outfit incomplete")
	_check(signatures.size() >= 6, "randomizer produced too few unique outfits")

	var before_sigs: Array[String] = []
	for entry in lineup:
		before_sigs.append(_sig(entry["outfit"]))
	scene.randomize_lineup()
	var changed := 0
	for i in lineup.size():
		if _sig(lineup[i]["outfit"]) != before_sigs[i]:
			changed += 1
		_check(_outfit_size(lineup[i]["outfit"]) == 17, "random lineup outfit incomplete")
	_check(changed >= 12, "lineup randomize changed only %d/16" % changed)
	for card in scene.cards:
		_check(_sig(card.entry["outfit"]) == _sig(lineup[card.index]["outfit"]),
				"card entry not refreshed")

	scene.load_lineup_entry(4)
	_check(scene.name_label.text == str(lineup[4]["name"]), "load preset name mismatch")
	var old_card_sig := _sig(lineup[4]["outfit"])
	scene.randomize_card(4)
	_check(_sig(lineup[4]["outfit"]) != old_card_sig, "single-card reroll did not change outfit")
	_check(_sig(scene.get_outfit()) == _sig(lineup[4]["outfit"]),
			"selected card reroll did not sync studio")

	# ── 槽位选择 / 变体数量 / 对照弹层 ─────────────────────────────────
	scene.set_selected_slot("hair")
	_check(scene.variant_buttons.size() == 6, "hair should expose 6 variants")
	_check(scene.color_buttons.size() == 8, "hair palette should expose 8 swatches")
	scene.set_selected_slot("weapon")
	_check(scene.variant_buttons.size() == 6, "weapon should expose 6 variants")
	scene.set_selected_slot("shirt")
	_check(scene.variant_buttons.size() == 5, "shirt should expose 5 variants")

	scene.show_directions_sheet()
	await process_frame
	await process_frame
	var direction_dolls: Array = scene.get_overlay_dolls()
	_check(direction_dolls.size() == 8, "direction sheet should show 8 dolls")
	for i in direction_dolls.size():
		_check(direction_dolls[i].direction == i, "direction sheet doll mismatch")
		_check(direction_dolls[i].action == "walk", "direction sheet should pose walking")
	scene.close_sheet()
	_check(scene.get_overlay_dolls().is_empty(), "direction sheet did not close")

	scene.show_actions_sheet()
	await process_frame
	await process_frame
	var action_dolls: Array = scene.get_overlay_dolls()
	_check(action_dolls.size() == 4, "action sheet should show 4 dolls")
	var action_ids := ["idle", "walk", "attack", "hit"]
	for i in action_dolls.size():
		_check(action_dolls[i].action == action_ids[i], "action sheet mismatch at %d" % i)
	scene.close_sheet()
	_check(scene.get_overlay_dolls().is_empty(), "action sheet did not close")

	# ── 存档往返 ───────────────────────────────────────────────────────
	scene.set_selected_slot("shirt")
	scene.set_slot_variant("shirt", "armor")
	scene.set_slot_color("shirt", Color("#4fa58a"))
	scene.set_slot_variant("hair", "bun")
	scene.set_slot_color("hair", Color("#c95f5f"))
	scene.set_direction(6)
	scene.set_action("attack")
	var before_outfit: Dictionary = scene.get_outfit()
	var path := "user://paperdoll_smoke_save.json"
	_check(scene.save_current(path), "save_current failed")
	_check(FileAccess.file_exists(path), "save file missing")
	var loaded := DollData.load_doll(path)
	_check(not loaded.is_empty(), "load_doll returned empty")
	if not loaded.is_empty():
		_check(_sig(loaded["outfit"]) == _sig(before_outfit), "saved outfit mismatch")
		_check(int(loaded["direction"]) == 6, "saved direction mismatch")
		_check(str(loaded["action"]) == "attack", "saved action mismatch")
	scene.randomize_current()
	scene.set_direction(0)
	scene.set_action("idle")
	_check(scene.load_saved(path), "load_saved failed")
	_check(_sig(scene.get_outfit()) == _sig(before_outfit), "loaded outfit mismatch")
	_check(scene.get_direction() == 6, "loaded direction mismatch")
	_check(scene.get_action() == "attack", "loaded action mismatch")

	# ── 烘焙缓存：阵容卡只渲染一次，避免 16 个 SubViewport 持续重绘 ─────
	await create_timer(0.2).timeout
	var baked := 0
	for card in scene.cards:
		if card._thumb.is_baked():
			baked += 1
	_check(baked == scene.cards.size(), "only %d/%d card thumbnails baked" % [baked, scene.cards.size()])
	_check(baked == 16, "expected 16 baked lineup cards")

	# ── 输出 ────────────────────────────────────────────────────────────
	if _fails.is_empty():
		print("PAPERDOLL_SMOKE_OK slots=%d variants=%d dirs=%d actions=%d presets=%d cards=%d baked_cards=%d combos=%s procedural_art=true missing_textures=0"
				% [DollData.SLOTS.size(), variant_total, DollData.DIRS.size(),
				DollData.ACTIONS.size(), scene.get_preset_count(), scene.cards.size(), baked,
				DollData.combination_text()])
		quit(0)
	else:
		for failure in _fails:
			printerr("PAPERDOLL FAIL: ", failure)
		printerr("PAPERDOLL_SMOKE_FAILED failures=%d" % _fails.size())
		quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_fails.append(message)


func _finite_vec(value: Variant) -> bool:
	if not value is Vector2:
		return false
	var v: Vector2 = value
	return not (is_nan(v.x) or is_nan(v.y) or is_inf(v.x) or is_inf(v.y))


func _z(order: Array, slot_id: String) -> int:
	for entry in order:
		if entry["id"] == slot_id:
			return int(entry["z"])
	return -9999


func _outfit_size(outfit: Dictionary) -> int:
	var count := 0
	for slot in DollData.SLOTS:
		if outfit.has(slot["id"]):
			count += 1
	return count


func _sig(outfit: Dictionary) -> String:
	var parts: Array[String] = []
	for slot in DollData.SLOTS:
		var entry: Dictionary = outfit.get(slot["id"], {})
		var color: Color = entry.get("color", Color.WHITE)
		parts.append("%s:%s:%s" % [slot["id"], str(entry.get("variant", "")), color.to_html(false)])
	return "|".join(parts)
