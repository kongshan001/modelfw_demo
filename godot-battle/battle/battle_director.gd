class_name BattleDirector
extends RefCounted

var content: ContentDB
var registry := CommandRegistry.new()

func setup(p_content: ContentDB) -> void:
	content = p_content
	registry.content = p_content

func build(events: Array[BattleEvent]) -> Array[BattleCommand]:
	var commands: Array[BattleCommand] = []
	for event in events:
		commands.append(registry.create(event))
	return commands
