extends RefCounted

# 2.5D 阵型表：3 我方 / 4 敌方，两排；位置唯一、行/深度/朝向正确、在屏内、
# 命中区 x 区间互不相交（>=10px），保证前后排与相邻单位不会互相抢点击。

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

	# 表驱动期望：行 / 深度 / 美术朝向。
	var expected_ally := [
		[1, 1.05, -1],
		[0, 0.92, -1],
		[0, 0.90, -1],
	]
	var expected_enemy := [
		[1, 1.05, 1],
		[0, 0.90, 1],
		[1, 1.05, -1],
		[0, 0.90, -1],
	]
	for index in allies.size():
		_check_slot(t, allies[index], expected_ally[index], "ally[%d]" % index)
	for index in enemies.size():
		_check_slot(t, enemies[index], expected_enemy[index], "enemy[%d]" % index)

	# 位置唯一、在屏内、脚底落在战场石台高度带。
	var seen := {}
	var screen := Rect2(0.0, 0.0, 1920.0, 1080.0)
	var half_width := UnitView.CLICK_SIZE.x * 0.5
	for slot in all:
		var pos: Vector2 = slot["pos"]
		t.ok(not seen.has(pos), "duplicate formation position %s" % str(pos))
		seen[pos] = true
		t.ok(screen.has_point(pos), "formation position %s is on screen" % str(pos))
		t.in_range(pos.x, half_width, 1920.0 - half_width, "feet x leaves room for hit rect")
		t.in_range(pos.y, 640.0, 960.0, "feet y inside arena band")

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

	# 两排都存在，且前排脚底 Y 大于后排（配合 World.y_sort_enabled 形成遮挡）。
	var front_y := INF
	var back_y := -INF
	for slot in all:
		if int(slot["row"]) == 1:
			front_y = minf(front_y, (slot["pos"] as Vector2).y)
		else:
			back_y = maxf(back_y, (slot["pos"] as Vector2).y)
	t.ok(front_y > back_y, "front row feet y (%.0f) is greater than back row feet y (%.0f)" % [front_y, back_y])

func _check_slot(t: TestContext, slot: Dictionary, expected: Array, label: String) -> void:
	var row := int(slot["row"])
	var depth := float(slot["depth"])
	var flip := int(slot["art_flip"])
	t.eq(row, int(expected[0]), "%s row" % label)
	t.near(depth, float(expected[1]), 0.0001, "%s depth" % label)
	t.eq(flip, int(expected[2]), "%s art_flip" % label)
	t.ok(flip == 1 or flip == -1, "%s art_flip is ±1" % label)
	t.in_range(depth, 0.85, 1.10, "%s depth within formation range" % label)
