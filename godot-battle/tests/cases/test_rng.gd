extends RefCounted

func run(t: TestContext) -> void:
	var a := BattleRng.new(42)
	var b := BattleRng.new(42)
	for i in 20:
		t.eq(a.randi_range(0, 999), b.randi_range(0, 999), "同种子产生相同序列")

	var c := BattleRng.new(7)
	c.randi_range(0, 10)
	c.randi_range(0, 10)
	var saved := c.state()
	var expected := c.randi_range(0, 1000)
	c.set_state(saved)
	t.eq(c.randi_range(0, 1000), expected, "state 可恢复随机流")

	t.ok(BattleRng.new(1).randi_range(0, 100000) != BattleRng.new(2).randi_range(0, 100000), "不同种子产生不同序列")
