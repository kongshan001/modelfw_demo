class_name BattleEngine
extends RefCounted

var content: ContentDB
var encounter: EncounterData
var state: BattleState
var rng: BattleRng
var resolver: BattleResolver
var seed_value: int

func _init(p_encounter: EncounterData, p_content: ContentDB, p_seed: int) -> void:
	encounter = p_encounter
	content = p_content
	seed_value = p_seed
	rng = BattleRng.new(p_seed)
	state = BattleFactory.create(p_encounter, p_content)
	resolver = BattleResolver.new(state, rng, p_content)

func resolve_round(intents: Array[BattleIntent]) -> Array[BattleEvent]:
	if state.is_over():
		return []
	return resolver.resolve_round(intents)

func is_over() -> bool:
	return state.is_over()

func outcome() -> int:
	return state.outcome
