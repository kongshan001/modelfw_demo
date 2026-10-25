extends RefCounted

# 紧凑菱形/箭头阵型：每侧 1 个前排尖端（我方剑客 / 敌方妖将），其余为后排，
# 两尖端是全场最近的一对，并被中央石环托住；中心线约 36°。
# 镜头在我方背后：我方 view=back（背影），敌方 view=front（正面）。
# 命中区允许屏幕空间重叠（参考作亦然），不再断言 x 区间互不相交；
# 只要求尖端中心点击点不被其他命中区抢走，且所有命中区/信息带避开 HUD 面板。

# HUD 常驻/指令面板的近似占位（逻辑坐标 1920×1080）；用于证明阵型不压 HUD。
const HUD_ZONES := [
	Rect2(1368, 612, 552, 468), # CommandPanel + PartyFleeButton 一带
	Rect2(20, 820, 620, 260), # BattleLog
	Rect2(24, 164, 320, 110), # TurnOrderBar
	Rect2(1512, 24, 408, 90), # PlaybackControls
]

func run(t: TestContext) -> void:
	var layout := BattleFieldLayout.new()
	var allies := layout.ally_slots()
	var enemies := layout.enemy_slots()
	var all := layout.all_slots()
	t.eq(allies.size(), 3, "ally slot count")
	t.eq(enemies.size(), 4, "enemy slot count")
	t.eq(all.size(), 7, "total slot count")

	# slot(side, index) 与侧表一致；越界返回空表。
	for index in allies.size():
		t.eq(layout.slot(BattleTypes.Side.ALLY, index), allies[index], "ally slot(%d) matches table" % index)
	for index in enemies.size():
		t.eq(layout.slot(BattleTypes.Side.ENEMY, index), enemies[index], "enemy slot(%d) matches table" % index)
	t.eq(layout.slot(BattleTypes.Side.ALLY, 3), {}, "ally out-of-range slot is empty")
	t.eq(layout.slot(BattleTypes.Side.ENEMY, -1), {}, "enemy negative slot is empty")

	# 表驱动期望：脚底坐标 / 行 / 深度 / 美术朝向 / 视图。
	var expected_ally := [
		[Vector2(1000, 800), 1, 0.98, -1, "back"],
		[Vector2(1200, 880), 0, 1.06, -1, "back"],
		[Vector2(930, 900), 0, 1.10, -1, "back"],
	]
	var expected_enemy := [
		[Vector2(700, 640), 0, 0.90, 1, "front"],
		[Vector2(540, 600), 0, 0.88, 1, "front"],
		[Vector2(850, 700), 1, 0.94, 1, "front"],
		[Vector2(460, 540), 0, 0.86, 1, "front"],
	]
	for index in allies.size():
		_check_slot(t, allies[index], expected_ally[index], "ally[%d]" % index)
	for index in enemies.size():
		_check_slot(t, enemies[index], expected_enemy[index], "enemy[%d]" % index)
	# 两侧视图严格分离：我方全部背影、敌方全部正面。
	for index in allies.size():
		t.eq(String(allies[index].get("view", "")), "back", "ally[%d] view is back" % index)
	for index in enemies.size():
		t.eq(String(enemies[index].get("view", "")), "front", "enemy[%d] view is front" % index)

	# 每侧恰好一个 row=1 尖端：我方 slot0 剑客、敌方 slot2 妖将；其余都是后排。
	var ally_tips := _slots_with_row(allies, 1)
	var enemy_tips := _slots_with_row(enemies, 1)
	t.eq(ally_tips.size(), 1, "exactly one ally tip row")
	t.eq(enemy_tips.size(), 1, "exactly one enemy tip row")
	t.eq(allies.find(ally_tips[0]) if not ally_tips.is_empty() else -1, 0, "ally tip is swordsman slot 0")
	t.eq(enemies.find(enemy_tips[0]) if not enemy_tips.is_empty() else -1, 2, "enemy tip is brute slot 2")
	for index in allies.size():
		t.eq(int(allies[index]["row"]), 1 if index == 0 else 0, "ally[%d] row is tip/back" % index)
	for index in enemies.size():
		t.eq(int(enemies[index]["row"]), 1 if index == 2 else 0, "enemy[%d] row is tip/back" % index)

	# 位置唯一、在屏内，命中区完整留在屏幕内。
	var seen := {}
	var screen := Rect2(0.0, 0.0, 1920.0, 1080.0)
	for slot in all:
		var pos: Vector2 = slot["pos"]
		var hit := _hit_rect(pos)
		var info := _info_rect(pos)
		t.ok(not seen.has(pos), "duplicate formation position %s" % str(pos))
		seen[pos] = true
		t.ok(screen.has_point(pos), "formation position %s is on screen" % str(pos))
		t.ok(screen.encloses(hit), "hit rect %s stays on screen" % str(hit))
		t.ok(screen.encloses(info), "info band %s stays on screen" % str(info))
		# 命中区/信息带不得压住 HUD 面板（命中区彼此重叠是有意为之，不在此断言）。
		for zone: Rect2 in HUD_ZONES:
			t.ok(not hit.intersects(zone), "hit rect %s avoids HUD %s" % [str(hit), str(zone)])
			t.ok(not info.intersects(zone), "info band %s avoids HUD %s" % [str(info), str(zone)])

	# 尖端点击点（身体上部 120px）只落在自身命中区内，保证鼠标点尖端稳定。
	var ally_tip_pos: Vector2 = allies[0]["pos"]
	var enemy_tip_pos: Vector2 = enemies[2]["pos"]
	for pair in [[ally_tip_pos, allies + enemies], [enemy_tip_pos, allies + enemies]]:
		var tip_pos: Vector2 = pair[0]
		var click_point := tip_pos + Vector2(0, -120)
		var owner := _hit_rect(tip_pos)
		t.ok(owner.has_point(click_point), "tip click point %s is inside own hit rect" % str(click_point))
		for slot in pair[1]:
			var other_pos: Vector2 = slot["pos"]
			if other_pos == tip_pos:
				continue
			t.ok(not _hit_rect(other_pos).has_point(click_point), "tip click point %s not stolen by unit at %s" % [str(click_point), str(other_pos)])

	# 尖端是双方最近的一对，连线中点落在中央石环圆心。
	var tip_distance := ally_tip_pos.distance_to(enemy_tip_pos)
	var min_cross_distance := INF
	for ally in allies:
		for enemy in enemies:
			min_cross_distance = minf(min_cross_distance, (ally["pos"] as Vector2).distance_to(enemy["pos"] as Vector2))
	t.near(min_cross_distance, tip_distance, 0.01, "tips are the closest opposing pair (%.2f vs %.2f)" % [tip_distance, min_cross_distance])
	var tip_mid := (ally_tip_pos + enemy_tip_pos) * 0.5
	t.ok(tip_mid.distance_to(BackgroundView.RING_CENTER) <= 2.0, "tip midpoint %s sits on the central ring %s" % [str(tip_mid), str(BackgroundView.RING_CENTER)])

	# 两侧中心连线：敌方左上、我方右下，角度 20°~45°；尖端也沿同一斜轴。
	var ally_center := _mean_position(allies)
	var enemy_center := _mean_position(enemies)
	var center_angle := rad_to_deg(atan2(ally_center.y - enemy_center.y, ally_center.x - enemy_center.x))
	t.in_range(center_angle, 20.0, 45.0, "formation center line is diagonal (%.1f° in [20, 45]); ally=%s enemy=%s" % [center_angle, str(ally_center), str(enemy_center)])
	var tip_angle := rad_to_deg(atan2(ally_tip_pos.y - enemy_tip_pos.y, ally_tip_pos.x - enemy_tip_pos.x))
	t.in_range(tip_angle, 20.0, 45.0, "tip-to-tip line is diagonal (%.1f°)" % tip_angle)
	var axis_dir := (ally_center - enemy_center).normalized()
	var axis_distance := absf((tip_mid - enemy_center).cross(axis_dir))
	# 扇形后排会把阵型质心拉向两侧，尖端中点允许略偏离质心连线；仍要求在 45px 内。
	t.ok(axis_distance <= 45.0, "tips sit near the center axis (offset %.1fpx <= 45)" % axis_distance)

	# 镜头在我方背后：我方整体更近/更大/更低，敌方整体更远/更小/更高。
	var ally_depth_min := INF
	var enemy_depth_max := -INF
	for slot in allies:
		ally_depth_min = minf(ally_depth_min, float(slot["depth"]))
	for slot in enemies:
		enemy_depth_max = maxf(enemy_depth_max, float(slot["depth"]))
	t.ok(ally_depth_min > enemy_depth_max, "ally side is closer (min depth %.2f > enemy max %.2f)" % [ally_depth_min, enemy_depth_max])
	t.ok(ally_center.y > enemy_center.y, "ally side is lower/closer than enemy side (y %.0f > %.0f)" % [ally_center.y, enemy_center.y])
	t.ok(ally_tip_pos.y > enemy_tip_pos.y, "ally tip is nearer the camera than enemy tip (y %.0f > %.0f)" % [ally_tip_pos.y, enemy_tip_pos.y])

	# 敌方整体站在竹林空地上（最深的狐妖 y≈580 也高于空地远缘）。
	var enemy_rear := _lowest_slot(enemies)
	var rear_pos: Vector2 = enemy_rear["pos"]
	t.ok(rear_pos.y > BackgroundView._clearing_edge_y(rear_pos.x) + 8.0, "enemy rear %s stands on the clearing (edge y %.0f)" % [str(rear_pos), BackgroundView._clearing_edge_y(rear_pos.x)])
	for slot in enemies:
		var pos: Vector2 = slot["pos"]
		t.ok(pos.y > BackgroundView._clearing_edge_y(pos.x) + 8.0, "enemy at %s stands on the clearing" % str(pos))

func _slots_with_row(slots: Array, row: int) -> Array:
	var result: Array = []
	for slot in slots:
		if int(slot["row"]) == row:
			result.append(slot)
	return result

func _lowest_slot(slots: Array) -> Dictionary:
	var result: Dictionary = slots[0]
	for slot in slots:
		if (slot["pos"] as Vector2).y < (result["pos"] as Vector2).y:
			result = slot
	return result

func _hit_rect(pos: Vector2) -> Rect2:
	return Rect2(pos + UnitView.CLICK_CENTER - UnitView.CLICK_SIZE * 0.5, UnitView.CLICK_SIZE)

func _info_rect(pos: Vector2) -> Rect2:
	# 信息带宽度 200；锚点随剪影缩放上下浮动，这里用保守的高度带覆盖。
	return Rect2(pos + Vector2(-100.0, -300.0), Vector2(200.0, 110.0))

func _mean_position(slots: Array) -> Vector2:
	var sum := Vector2.ZERO
	for slot in slots:
		sum += slot["pos"] as Vector2
	return sum / float(slots.size())

func _check_slot(t: TestContext, slot: Dictionary, expected: Array, label: String) -> void:
	var pos: Vector2 = slot["pos"]
	var row := int(slot["row"])
	var depth := float(slot["depth"])
	var flip := int(slot["art_flip"])
	var view := String(slot.get("view", ""))
	t.eq(pos, expected[0], "%s pos" % label)
	t.eq(row, int(expected[1]), "%s row" % label)
	t.near(depth, float(expected[2]), 0.0001, "%s depth" % label)
	t.eq(flip, int(expected[3]), "%s art_flip" % label)
	t.eq(view, String(expected[4]), "%s view" % label)
	t.ok(flip == 1 or flip == -1, "%s art_flip is ±1" % label)
	t.ok(view == "back" or view == "front", "%s view is back/front" % label)
	t.in_range(depth, 0.85, 1.15, "%s depth within formation range" % label)
