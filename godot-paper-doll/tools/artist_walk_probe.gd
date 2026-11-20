extends SceneTree

# T-20261121-001 美术自检探针（不替代 QA）：
#   1) 8 向 walk 支撑脚水平漂移，口径同 tools/qa_motion_probe.gd（≤2px @2.1×）；
#   2) 支撑/摆动全程膝关节内角 <179°，排除过伸；
#   3) 脚掌俯仰落在 [−15°, +22°] 区间，且左右脚在同一相位上镜像一致；
#   4) 支撑脚在触地段的 y 不超过地面 1 local（全掌/脚跟/脚尖接触）。
# 用法：godot --headless --path godot-paper-doll -s tools/artist_walk_probe.gd

const SCALE := 2.1
const SLIDE_PX := 2.0
const SAMPLES := 240


func _initialize() -> void:
	var fails: Array[String] = []
	var worst := 0.0
	var worst_info := ""
	for dir in DollData.DIRS.size():
		var fl: Array[Vector2] = []
		var fr: Array[Vector2] = []
		var pitch_min := 999.0
		var pitch_max := -999.0
		var max_knee_ext := 0.0
		for i in SAMPLES:
			var t := DollPose.WALK_PERIOD * float(i) / float(SAMPLES)
			var pose := DollPose.compute(t, "walk", dir)
			fl.append(pose["foot_l"])
			fr.append(pose["foot_r"])
			for key in ["foot_angle_l", "foot_angle_r"]:
				var a: float = pose[key]
				pitch_min = minf(pitch_min, a)
				pitch_max = maxf(pitch_max, a)
			for side in ["l", "r"]:
				var hip: Vector2 = pose["hip_" + side]
				var knee: Vector2 = pose["knee_" + side]
				var foot: Vector2 = pose["foot_" + side]
				var a := (hip - knee).normalized()
				var b := (foot - knee).normalized()
				var interior := rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))
				max_knee_ext = maxf(max_knee_ext, interior)
		var l := _contact_drift(fl) * SCALE
		var r := _contact_drift(fr) * SCALE
		if l > worst:
			worst = l
			worst_info = "dir=%d foot=left" % dir
		if r > worst:
			worst = r
			worst_info = "dir=%d foot=right" % dir
		print("ARTIST_WALK dir=%d left_px=%.2f right_px=%.2f pitch=[%.3f, %.3f] knee_max_deg=%.1f"
				% [dir, l, r, pitch_min, pitch_max, max_knee_ext])
		if l > SLIDE_PX or r > SLIDE_PX:
			fails.append("dir %d slide %.2f/%.2fpx" % [dir, l, r])
		if pitch_min < DollPose.WALK_HEEL - 0.02 or pitch_max > DollPose.WALK_TOE + 0.02:
			fails.append("dir %d foot pitch [%.3f, %.3f]" % [dir, pitch_min, pitch_max])
		if max_knee_ext > 179.0:
			fails.append("dir %d knee overextended %.1f°" % [dir, max_knee_ext])

	# 左右腿曲线一致性：同一相位下 left/right 相对髋的足目标、高度、俯仰必须相同
	# （两条腿用同一条曲线，仅错开半个周期；向前 reach 属于同一朝向，不做 x 取反）。
	var mirror_err := 0.0
	for i in 48:
		var t := DollPose.WALK_PERIOD * float(i) / 48.0
		var a := DollPose.compute(t, "walk", 0)
		var b := DollPose.compute(t + DollPose.WALK_PERIOD * 0.5, "walk", 0)
		# 同一腿相位下：左腿(a) 与右腿(b) 的高度/俯仰必须一致。
		mirror_err = maxf(mirror_err, absf((a["foot_l"] as Vector2).y - (b["foot_r"] as Vector2).y))
		mirror_err = maxf(mirror_err, absf(float(a["foot_angle_l"]) - float(b["foot_angle_r"])))
		# 支撑相：左右 plant 必须关于中线对称（+x 前探只发生在摆动相）。
		if fposmod(t / DollPose.WALK_PERIOD, 1.0) < DollPose.WALK_STANCE:
			mirror_err = maxf(mirror_err, absf((a["foot_l"] as Vector2).x + (b["foot_r"] as Vector2).x))
	print("ARTIST_WALK mirror_err=%.4f local" % mirror_err)
	if mirror_err > 0.01:
		fails.append("left/right mirror mismatch %.4f" % mirror_err)

	print("ARTIST_WALK_SLIDE max_px=%.2f threshold_px=%.1f worst=%s" % [worst, SLIDE_PX, worst_info])
	if fails.is_empty():
		print("ARTIST_WALK_OK dirs=8")
		quit(0)
	else:
		for f in fails:
			printerr("ARTIST_WALK_FAIL ", f)
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
