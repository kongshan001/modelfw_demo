class_name BattleRng
extends RefCounted

var _rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func chance(probability: float) -> bool:
	return _rng.randf() < probability

func state() -> int:
	return _rng.state

func set_state(saved_state: int) -> void:
	_rng.state = saved_state
