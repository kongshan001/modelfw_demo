class_name FogRaidRules
extends RefCounted
## 单局规则：6 分钟行动时间；开局 2 分钟后或搜完 2 个箱子后撤离点激活；
## 在撤离圈内连续站 3 秒完成撤离；时间耗尽即行动失败。

const RAID_TIME := 360.0
const UNLOCK_TIME := 120.0
const UNLOCK_CHESTS := 2
const EXTRACT_HOLD := 3.0

var elapsed := 0.0
var chests_searched := 0
var active := false
var progress := 0.0
var finished := false
var success := false
var reason := ""


func reset() -> void:
	elapsed = 0.0
	chests_searched = 0
	active = false
	progress = 0.0
	finished = false
	success = false
	reason = ""


func tick(delta: float, in_zone: bool) -> Dictionary:
	## 返回事件 {activated, extracted, timeout}。finished 后不再推进。
	var events := {"activated": false, "extracted": false, "timeout": false}
	if finished:
		return events
	elapsed = minf(RAID_TIME, elapsed + maxf(0.0, delta))
	if not active and (elapsed >= UNLOCK_TIME or chests_searched >= UNLOCK_CHESTS):
		active = true
		events["activated"] = true
	if active and in_zone:
		progress = minf(EXTRACT_HOLD, progress + maxf(0.0, delta))
		if progress >= EXTRACT_HOLD:
			finished = true
			success = true
			reason = "extracted"
			events["extracted"] = true
			return events
	else:
		progress = 0.0
	if not finished and elapsed >= RAID_TIME:
		finished = true
		success = false
		reason = "timeout"
		events["timeout"] = true
	return events


func register_chest_search() -> bool:
	## 返回是否因此触发了撤离点激活。
	chests_searched += 1
	if chests_searched >= UNLOCK_CHESTS and not active:
		active = true
		return true
	return false


func time_left() -> float:
	return maxf(0.0, RAID_TIME - elapsed)


func unlock_in() -> float:
	if active or finished:
		return 0.0
	return maxf(0.0, UNLOCK_TIME - elapsed)


func progress_ratio() -> float:
	return clampf(progress / EXTRACT_HOLD, 0.0, 1.0)


func force_activate() -> void:
	active = true


func force_progress(seconds: float) -> void:
	progress = clampf(seconds, 0.0, EXTRACT_HOLD)


func finish_now(ok: bool, why: String) -> void:
	finished = true
	success = ok
	reason = why
