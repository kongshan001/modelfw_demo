extends SceneTree

# T-20261120-011 QA 步态探针：walk 支撑相的脚底水平漂移（防滑步，评审 §8 第 4 项）。
# 判定：支撑相（脚底 y 距最低点 ≤1.0 local）水平漂移 × 试衣镜 2.1× ≤ 2.0px。
# 输出 QA_WALK_SLIDE left_px=... right_px=... / QA_MOTION_OK/FAIL。
# 用法：godot --headless --path godot-paper-doll -s tools/qa_motion_probe.gd

const SCALE := 2.1
const SLIDE_PX := 2.0


func _initialize() -> void:
	var worst_l := 0.0
	var worst_r := 0.0
	var worst_info := ""
	for dir in [0, 6]:
		var fl: Array[Vector2] = []
		var fr: Array[Vector2] = []
		for i in 240:
			var t := 0.82 * float(i) / 240.0
			var pose := DollPose.compute(t, "walk", dir)
			fl.append(pose["foot_l"])
			fr.append(pose["foot_r"])
		var l := _contact_drift(fl)
		var r := _contact_drift(fr)
		print("QA_WALK dir=%d left_px=%.2f right_px=%.2f" % [dir, l * SCALE, r * SCALE])
		if l * SCALE > worst_l:
			worst_l = l * SCALE
			worst_info = "dir=%d foot=left" % dir
		if r * SCALE > worst_r:
			worst_r = r * SCALE
			worst_info = "dir=%d foot=right" % dir
	print("QA_WALK_SLIDE max_left_px=%.2f max_right_px=%.2f threshold_px=%.1f worst=%s"
			% [worst_l, worst_r, SLIDE_PX, worst_info])
	if maxf(worst_l, worst_r) <= SLIDE_PX:
		print("QA_MOTION_OK")
		quit(0)
	else:
		printerr("QA_MOTION_FAIL")
		quit(1)


func _contact_drift(points: Array[Vector2]) -> float:
	var ground := -1e9
	for p in points:
		ground = maxf(ground, p.y)
	var xs: Array[float] = []
	for p in points:
		if ground - p.y <= 1.0:
			xs.append(p.x)
	if xs.is_empty():
		return 0.0
	return xs.max() - xs.min()
