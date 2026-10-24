class_name BattleDirector
extends RefCounted

func build(events: Array[BattleEvent]) -> Array[BattleCommand]:
	var commands: Array[BattleCommand] = []
	for event in events:
		commands.append(SimpleEventCommand.new(event))
	return commands
