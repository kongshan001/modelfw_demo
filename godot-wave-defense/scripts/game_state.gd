extends RefCounted
## 单局状态与本地最高分：金币、主城 HP、击杀、构筑修正、分数/等级。
## 存档只写 user:// JSON（最高分/最佳波次），不依赖第三方库。

const Data = preload("res://scripts/game_data.gd")

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://wave_defense_save.json"

var save_path := DEFAULT_SAVE_PATH

var seed_value := Data.DEFAULT_SEED
var gold := Data.START_GOLD
var castle_hp := Data.CASTLE_MAX_HP
var kills := 0
var wave_cleared := 0
var chosen_upgrades: Array[String] = []
var run_seconds := 0.0

var mods := {}
var run_finished := false
var victory := false
var score := 0
var grade := ""

var best_score := 0
var best_grade := ""
var best_wave := 0
var best_kills := 0
var runs := 0
var new_best := false


func _init(path := DEFAULT_SAVE_PATH) -> void:
	save_path = path
	reset_run(Data.DEFAULT_SEED)


func set_path(path: String) -> void:
	save_path = path


func reset_run(seed: int) -> void:
	seed_value = seed
	gold = Data.START_GOLD
	castle_hp = Data.CASTLE_MAX_HP
	kills = 0
	wave_cleared = 0
	chosen_upgrades.clear()
	run_seconds = 0.0
	run_finished = false
	victory = false
	score = 0
	grade = ""
	new_best = false
	mods = {
		"tower_range": 1.0,
		"tower_rate": 1.0,
		"tower_damage": 1.0,
		"cannon_damage": 1.0,
		"cannon_splash": 1.0,
		"lord_rate": 1.0,
		"lord_damage": 1.0,
		"skill_cd": float(Data.PLAYER["skill_cd"]),
		"gold_bonus": 0,
	}


func tick_time(delta: float) -> void:
	if not run_finished:
		run_seconds += delta


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)


func spend(amount: int) -> bool:
	if amount < 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	return true


func kill_reward(base_gold: int) -> int:
	var total := maxi(0, base_gold) + int(mods.get("gold_bonus", 0))
	gold += total
	kills += 1
	return total


func damage_castle(amount: float) -> void:
	if run_finished:
		return
	castle_hp = maxi(0, castle_hp - int(round(amount)))


func heal_castle(amount: int) -> int:
	var before := castle_hp
	castle_hp = mini(Data.CASTLE_MAX_HP, castle_hp + maxi(0, amount))
	return castle_hp - before


func apply_upgrade(id: String) -> bool:
	if not Data.UPGRADES.has(id):
		return false
	match id:
		"range":
			mods["tower_range"] = float(mods["tower_range"]) * 1.20
		"lord_rate":
			mods["lord_rate"] = float(mods["lord_rate"]) * 1.25
		"gold", "gold2":
			mods["gold_bonus"] = int(mods["gold_bonus"]) + 1
		"castle_heal":
			heal_castle(20)
		"cannon":
			mods["cannon_damage"] = float(mods["cannon_damage"]) * 1.25
			mods["cannon_splash"] = float(mods["cannon_splash"]) * 1.20
		"skill_cd":
			mods["skill_cd"] = maxf(4.0, float(mods["skill_cd"]) - 2.0)
		"tower_rate":
			mods["tower_rate"] = float(mods["tower_rate"]) * 1.20
		"lord_damage":
			mods["lord_damage"] = float(mods["lord_damage"]) * 1.30
		_:
			return false
	chosen_upgrades.append(id)
	return true


func compute_score() -> int:
	return wave_cleared * 100 + kills * 10 + castle_hp * 50 + gold


static func grade_for(total: int) -> String:
	if total >= 4200:
		return "S"
	if total >= 3200:
		return "A"
	if total >= 2200:
		return "B"
	if total >= 1200:
		return "C"
	return "D"


func finish_run(did_win: bool) -> Dictionary:
	if run_finished:
		return result_summary()
	run_finished = true
	victory = did_win
	score = compute_score()
	grade = grade_for(score)
	runs += 1
	new_best = score > best_score
	if new_best:
		best_score = score
		best_grade = grade
	best_wave = maxi(best_wave, wave_cleared)
	best_kills = maxi(best_kills, kills)
	save()
	return result_summary()


func result_summary() -> Dictionary:
	return {
		"victory": victory,
		"score": score,
		"grade": grade,
		"wave_cleared": wave_cleared,
		"kills": kills,
		"castle_hp": castle_hp,
		"gold": gold,
		"best_score": best_score,
		"best_grade": best_grade,
		"best_wave": best_wave,
		"runs": runs,
		"new_best": new_best,
	}


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"best_score": best_score,
		"best_grade": best_grade,
		"best_wave": best_wave,
		"best_kills": best_kills,
		"runs": runs,
		"new_best": new_best,
	}


func load_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = parsed
	best_score = maxi(0, int(data.get("best_score", 0)))
	best_grade = String(data.get("best_grade", ""))
	best_wave = clampi(int(data.get("best_wave", 0)), 0, Data.WAVES.size())
	best_kills = maxi(0, int(data.get("best_kills", 0)))
	runs = maxi(0, int(data.get("runs", 0)))
	return true


func save() -> bool:
	var dir := save_path.get_base_dir()
	if dir != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return true
