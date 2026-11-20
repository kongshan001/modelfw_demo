class_name GardenQuest
extends RefCounted

signal changed
signal stage_changed(stage: String)
signal completed

const STAGE_ACCEPT := "accept"
const STAGE_FIGHT := "fight"
const STAGE_RETURN := "return"
const STAGE_COMPLETE := "complete"

var title := "石圈的妖灵"
var giver := "章鱼"
var total := 3
var current := 0
var stage := STAGE_ACCEPT

func accept() -> void:
	if stage != STAGE_ACCEPT:
		return
	stage = STAGE_FIGHT
	stage_changed.emit(stage)
	changed.emit()

func add_kill() -> void:
	if stage != STAGE_FIGHT:
		return
	current = mini(total, current + 1)
	if current >= total:
		stage = STAGE_RETURN
		stage_changed.emit(stage)
	changed.emit()

func turn_in() -> void:
	if stage != STAGE_RETURN:
		return
	stage = STAGE_COMPLETE
	stage_changed.emit(stage)
	changed.emit()
	completed.emit()

func objective_text() -> String:
	match stage:
		STAGE_ACCEPT:
			return "前往石像，向章鱼接取任务"
		STAGE_FIGHT:
			return "击败妖灵 %d / %d" % [current, total]
		STAGE_RETURN:
			return "回到石像，向章鱼复命"
		STAGE_COMPLETE:
			return "试炼完成"
		_:
			return ""
