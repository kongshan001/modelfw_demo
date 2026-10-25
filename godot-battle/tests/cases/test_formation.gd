extends RefCounted

# 2.5D 阵型表：3 我方 / 4 敌方，两排；位置唯一、行/深度/朝向/视图正确、在屏内、
# 命中区 x 区间互不相交（>=10px），保证前后排与相邻单位不会互相抢点击。
# 镜头在我方背后：我方 view=back（背影），敌方 view=front（正面）。
# 两侧阵型中心连线必须斜向（20°~40°）：敌方中心在左上，我方中心在右下。

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

	# 表驱动期望：行 / 深度 / 美术朝向 / 视图。
	var expected_ally := [
		[1, 0.98, -1, "back"],
		[0, 1.12, -1, "back"],
		[0, 1.08, -1, "back"],
	]
	var expected_enemy := [
		[1, 0.84, 1, "front"],
		[0, 0.74, 1, "front"],
		[1, 0.86, 1, "front"],
		[0, 0.74, 1, "front"],
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

	# 位置唯一、在屏内、脚底落在战场石台高度带（敌方后排最深 y≈520）。
	var seen := {}
	var screen := Rect2(0.0, 0.0, 1920.0, 1080.0)
	var half_width := UnitView.CLICK_SIZE.x * 0.5
	for slot in all:
		var pos: Vector2 = slot["pos"]
		t.ok(not seen.has(pos), "duplicate formation position %s" % str(pos))
		seen[pos] = true
		t.ok(screen.has_point(pos), "formation position %s is on screen" % str(pos))
		t.in_range(pos.x, half_width, 1920.0 - half_width, "feet x leaves room for hit rect")
		t.in_range(pos.y, 500.0, 960.0, "feet y inside arena band")

	# 命中区 x 区间互不相交，相邻间隙 >=10px。
	var sorted := all.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a["pos"] as Vector2).x < (b["pos"] as Vector2).x
	)
	var center_offset := UnitView.CLICK_CENTER.x
	var previous_end := -INF
	for slot in sorted:
		var x := (slot["pos"] as Vector2).x
		var left := x + center_offset - half_width
		var right := x + center_offset + half_width
		if previous_end > -INF:
			t.ok(left - previous_end >= 10.0, "hit rect x gap >=10px before x=%.0f (gap %.1f)" % [x, left - previous_end])
		previous_end = right

	# 战术前排在对手一侧：我方前排偏左上，敌方前排偏右下；同侧两排都存在。
	var ally_front_x := INF
	var ally_back_x := -INF
	var ally_front_y := INF
	var ally_back_y := -INF
	var enemy_front_x := -INF
	var enemy_back_x := INF
	var enemy_front_y := -INF
	var enemy_back_y := INF
	for slot in allies:
		if int(slot["row"]) == 1:
			ally_front_x = minf(ally_front_x, (slot["pos"] as Vector2).x)
			ally_front_y = minf(ally_front_y, (slot["pos"] as Vector2).y)
		else:
			ally_back_x = maxf(ally_back_x, (slot["pos"] as Vector2).x)
			ally_back_y = maxf(ally_back_y, (slot["pos"] as Vector2).y)
	for slot in enemies:
		if int(slot["row"]) == 1:
			enemy_front_x = maxf(enemy_front_x, (slot["pos"] as Vector2).x)
			enemy_front_y = maxf(enemy_front_y, (slot["pos"] as Vector2).y)
		else:
			enemy_back_x = minf(enemy_back_x, (slot["pos"] as Vector2).x)
			enemy_back_y = minf(enemy_back_y, (slot["pos"] as Vector2).y)
	t.ok(ally_front_x < ally_back_x, "ally front is toward the opponent (x %.0f < back x %.0f)" % [ally_front_x, ally_back_x])
	t.ok(ally_front_y < ally_back_y, "ally back row is nearer camera (y %.0f > front y %.0f)" % [ally_back_y, ally_front_y])
	t.ok(enemy_front_x > enemy_back_x, "enemy front is toward the opponent (x %.0f > back x %.0f)" % [enemy_front_x, enemy_back_x])
	t.ok(enemy_front_y > enemy_back_y, "enemy front row is nearer camera (y %.0f > back y %.0f)" % [enemy_front_y, enemy_back_y])

	# 镜头在我方背后：我方整体更近/更大/更低，敌方整体更远/更小/更高。
	var ally_depth_min := INF
	var enemy_depth_max := -INF
	for slot in allies:
		ally_depth_min = minf(ally_depth_min, float(slot["depth"]))
	for slot in enemies:
		enemy_depth_max = maxf(enemy_depth_max, float(slot["depth"]))
	t.ok(ally_depth_min > enemy_depth_max, "ally side is closer (min depth %.2f > enemy max %.2f)" % [ally_depth_min, enemy_depth_max])
	t.ok(ally_front_y > enemy_front_y, "ally side is lower/closer than enemy side (y %.0f > %.0f)" % [ally_front_y, enemy_front_y])

	# 两侧阵型中心连线必须斜向：敌方中心左上，我方中心右下，角度 20°~40°。
	var ally_center := _mean_position(allies)
	var enemy_center := _mean_position(enemies)
	var center_angle := rad_to_deg(atan2(ally_center.y - enemy_center.y, ally_center.x - enemy_center.x))
	t.in_range(center_angle, 20.0, 40.0, "formation center line is diagonal (%.1f° in [20, 40]); ally=%s enemy=%s" % [center_angle, str(ally_center), str(enemy_center)])

func _mean_position(slots: Array) -> Vector2:
	var sum := Vector2.ZERO
	for slot in slots:
		sum += slot["pos"] as Vector2
	return sum / float(slots.size())

func _check_slot(t: TestContext, slot: Dictionary, expected: Array, label: String) -> void:
	var row := int(slot["row"])
	var depth := float(slot["depth"])
	var flip := int(slot["art_flip"])
	var view := String(slot.get("view", ""))
	t.eq(row, int(expected[0]), "%s row" % label)
	t.near(depth, float(expected[1]), 0.0001, "%s depth" % label)
	t.eq(flip, int(expected[2]), "%s art_flip" % label)
	t.eq(view, String(expected[3]), "%s view" % label)
	t.ok(flip == 1 or flip == -1, "%s art_flip is ±1" % label)
	t.ok(view == "back" or view == "front", "%s view is back/front" % label)
	t.in_range(depth, 0.60, 1.15, "%s depth within formation range" % label)
