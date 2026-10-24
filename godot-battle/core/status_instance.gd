class_name StatusInstance
extends RefCounted

var data: StatusData
var remaining: int
var applied_round: int

func _init(p_data: StatusData, p_round: int) -> void:
	data = p_data
	remaining = p_data.duration
	applied_round = p_round
