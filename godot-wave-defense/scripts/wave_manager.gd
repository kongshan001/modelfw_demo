extends RefCounted
## 8 波状态机：准备倒计时 → 战斗生成 → 清场结算 → 下一波/胜利。
## 生成计划由 seed 决定（同 seed 完全一致），主循环无需物理/计时器节点。

const Data = preload("res://scripts/game_data.gd")

var phase := "idle"          # idle / prep / combat / cleared / victory
var wave_index := 0          # 当前（或即将开始）的波次，0-based
var wave_cleared := 0        # 已守住的波数
var prep_left := 0.0
var wave_time := 0.0
var seed_value := Data.DEFAULT_SEED

var spawn_plan: Array = []    # [{type, time, offset, order}]
var spawn_cursor := 0
var pending_spawns: Array = []
var spawned_count := 0


func start_run(seed: int) -> void:
	seed_value = seed
	wave_index = 0
	wave_cleared = 0
	phase = "prep"
	prep_left = float(Data.WAVES[0]["prep"])
	wave_time = 0.0
	spawn_plan.clear()
	pending_spawns.clear()
	spawn_cursor = 0
	spawned_count = 0


func start_wave_now() -> bool:
	if phase != "prep":
		return false
	phase = "combat"
	prep_left = 0.0
	wave_time = 0.0
	spawn_plan = build_spawn_plan(wave_index, seed_value)
	spawn_cursor = 0
	pending_spawns.clear()
	spawned_count = 0
	return true


func tick(delta: float, alive_count: int) -> String:
	if phase == "prep":
		prep_left = maxf(0.0, prep_left - delta)
		if prep_left <= 0.0:
			start_wave_now()
			return "started"
		return ""
	if phase != "combat":
		return ""
	wave_time += delta
	while spawn_cursor < spawn_plan.size() and float(spawn_plan[spawn_cursor]["time"]) <= wave_time:
		pending_spawns.append(spawn_plan[spawn_cursor])
		spawn_cursor += 1
	if spawn_cursor >= spawn_plan.size() and pending_spawns.is_empty() and spawned_count > 0 and alive_count <= 0:
		phase = "cleared"
		wave_cleared = wave_index + 1
		return "cleared"
	return ""


func take_spawns() -> Array:
	var out := pending_spawns
	pending_spawns = []
	spawned_count += out.size()
	return out


func spawns_finished() -> bool:
	return spawn_cursor >= spawn_plan.size() and pending_spawns.is_empty()


func advance_after_clear() -> bool:
	if wave_cleared >= Data.WAVES.size():
		phase = "victory"
		return true
	wave_index = wave_cleared
	phase = "prep"
	prep_left = float(Data.WAVES[wave_index]["prep"])
	wave_time = 0.0
	spawn_plan.clear()
	pending_spawns.clear()
	spawn_cursor = 0
	spawned_count = 0
	return false


func wave_total() -> int:
	if wave_index < 0 or wave_index >= Data.WAVES.size():
		return 0
	return Data.wave_enemy_total(wave_index)


func wave_reward() -> int:
	if wave_index < 0 or wave_index >= Data.WAVES.size():
		return 0
	return int(Data.WAVES[wave_index]["reward"])


func summary() -> String:
	return Data.wave_summary(wave_index)


func build_spawn_plan(index: int, seed: int) -> Array:
	var plan: Array = []
	if index < 0 or index >= Data.WAVES.size():
		return plan
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed) * 7919 + index * 104729 + 17
	var order := 0
	for group in Data.WAVES[index]["groups"]:
		var type_id := String(group["type"])
		var count := int(group["count"])
		var interval := float(group["interval"])
		var start := float(group["start"])
		for i in range(count):
			plan.append({
				"type": type_id,
				"time": start + interval * float(i),
				"offset": rng.randf_range(-15.0, 15.0),
				"order": order,
			})
			order += 1
	plan.sort_custom(func(a, b):
		var at := float(a["time"])
		var bt := float(b["time"])
		if is_equal_approx(at, bt):
			return int(a["order"]) < int(b["order"])
		return at < bt)
	return plan


## 截图/测试用：把状态直接放到指定波次的准备阶段。
func set_wave_for_demo(index: int, cleared: int) -> void:
	wave_index = clampi(index, 0, Data.WAVES.size() - 1)
	wave_cleared = clampi(cleared, 0, Data.WAVES.size())
	phase = "prep"
	prep_left = float(Data.WAVES[wave_index]["prep"])
	wave_time = 0.0
	spawn_plan.clear()
	pending_spawns.clear()
	spawn_cursor = 0
	spawned_count = 0
