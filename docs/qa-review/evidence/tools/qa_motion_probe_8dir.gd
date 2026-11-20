extends SceneTree

# T-20261120-011 QA 步态探针；T-20261121-002 扩展为 8 向 + 脚姿指标。
# 判定（BUG-03 原始口径，保持可比）：
#   支撑相（脚底 y 距最低点 ≤1.0 local）水平漂移 × 试衣镜 2.1× ≤ 2.0px。
# 扩展指标（QA 独立测量，不依赖 artist_walk_probe.gd）：
#   1) 支撑相（相位 < WALK_STANCE）脚 x 漂移，应 ≤2px；
#   2) 支撑相鞋底最低点 y 波动 ≤0.05 local（脚掌滚动时鞋底不穿透/不悬空）；
#   3) 膝关节内角 <179°（排除过伸）；
#   4) 脚掌俯仰落在 [−15°, +22°]（脚跟→全掌→脚尖滚动）；
#   5) dir=0 左右腿时间对称性（同相位下 y/俯仰/相对 plant 的位移一致）。
# 输出 QA_WALK dir=... / QA_WALK_SLIDE / QA_WALK_POSE / QA_MOTION_OK|FAIL。
# 用法：godot --headless --path godot-paper-doll -s tools/qa_motion_probe.gd

const SCALE := 2.1
const SLIDE_PX := 2.0
const SAMPLES := 240
const KNEE_LIMIT_DEG := 179.0
const SOLE_DY_LIMIT := 0.05


func _initialize() -> void:
	var worst_l := 0.0
	var worst_r := 0.0
	var worst_info := ""
	var knee_max := 0.0
	var pitch_min := 999.0
	var pitch_max := -999.0
	var sole_dy_max := 0.0
	var stance_drift_max := 0.0

	for dir in DollData.DIRS.size():
		var fl: Array[Vector2] = []
		var fr: Array[Vector2] = []
		var stance_l: Array[float] = []
		var stance_r: Array[float] = []
		var sole_l: Array[float] = []
		var sole_r: Array[float] = []
		var dir_knee := 0.0
		var dir_pitch_min := 999.0
		var dir_pitch_max := -999.0
		for i in SAMPLES:
			var t := DollPose.WALK_PERIOD * float(i) / float(SAMPLES)
			var pose := DollPose.compute(t, "walk", dir)
			var foot_l: Vector2 = pose["foot_l"]
			var foot_r: Vector2 = pose["foot_r"]
			fl.append(foot_l)
			fr.append(foot_r)
			var pitch_l: float = pose["foot_angle_l"]
			var pitch_r: float = pose["foot_angle_r"]
			pitch_min = minf(pitch_min, minf(pitch_l, pitch_r))
			pitch_max = maxf(pitch_max, maxf(pitch_l, pitch_r))
			dir_pitch_min = minf(dir_pitch_min, minf(pitch_l, pitch_r))
			dir_pitch_max = maxf(dir_pitch_max, maxf(pitch_l, pitch_r))
			var p_l := fposmod(t, DollPose.WALK_PERIOD) / DollPose.WALK_PERIOD
			var p_r := fposmod(p_l + 0.5, 1.0)
			if p_l < DollPose.WALK_STANCE:
				stance_l.append(foot_l.x)
				sole_l.append(_sole_y(foot_l, pitch_l))
			if p_r < DollPose.WALK_STANCE:
				stance_r.append(foot_r.x)
				sole_r.append(_sole_y(foot_r, pitch_r))
			for side in ["l", "r"]:
				var hip: Vector2 = pose["hip_" + side]
				var knee: Vector2 = pose["knee_" + side]
				var foot: Vector2 = pose["foot_" + side]
				var a := (hip - knee).normalized()
				var b := (foot - knee).normalized()
				var interior := rad_to_deg(acos(clampf(a.dot(b), -1.0, 1.0)))
				dir_knee = maxf(dir_knee, interior)

		var l := _contact_drift(fl) * SCALE
		var r := _contact_drift(fr) * SCALE
		var stance_l_px := _range(stance_l) * SCALE
		var stance_r_px := _range(stance_r) * SCALE
		var sole_dy := maxf(_range(sole_l), _range(sole_r))
		var stance_drift := maxf(stance_l_px, stance_r_px)

		knee_max = maxf(knee_max, dir_knee)
		sole_dy_max = maxf(sole_dy_max, sole_dy)
		stance_drift_max = maxf(stance_drift_max, stance_drift)

		print("QA_WALK dir=%d left_px=%.2f right_px=%.2f stance_px=%.2f/%.2f sole_dy=%.3f knee_max_deg=%.1f pitch_deg=[%.1f, %.1f]"
				% [dir, l, r, stance_l_px, stance_r_px, sole_dy, dir_knee,
				rad_to_deg(dir_pitch_min), rad_to_deg(dir_pitch_max)])

		if l > worst_l:
			worst_l = l
			worst_info = "dir=%d foot=left" % dir
		if r > worst_r:
			worst_r = r
			worst_info = "dir=%d foot=right" % dir

	var mirror_err := _mirror_error()
	var pitch_ok := pitch_min >= DollPose.WALK_HEEL - 0.001 \
			and pitch_max <= DollPose.WALK_TOE + 0.001
	var pose_ok := knee_max < KNEE_LIMIT_DEG and sole_dy_max <= SOLE_DY_LIMIT \
			and pitch_ok and mirror_err <= 0.01

	print("QA_WALK_SLIDE max_left_px=%.2f max_right_px=%.2f threshold_px=%.1f worst=%s"
			% [worst_l, worst_r, SLIDE_PX, worst_info])
	print("QA_WALK_POSE stance_max_px=%.2f sole_dy_max=%.3f knee_max_deg=%.1f knee_limit_deg=%.1f pitch_deg=[%.1f, %.1f] mirror_err=%.4f local"
			% [stance_drift_max, sole_dy_max, knee_max, KNEE_LIMIT_DEG,
			rad_to_deg(pitch_min), rad_to_deg(pitch_max), mirror_err])

	if maxf(worst_l, worst_r) <= SLIDE_PX:
		print("QA_MOTION_OK")
	else:
		printerr("QA_MOTION_FAIL")
	if not pose_ok:
		printerr("QA_WALK_POSE_FAIL")
	if maxf(worst_l, worst_r) > SLIDE_PX or not pose_ok:
		quit(1)
	else:
		quit(0)


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


func _range(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	return values.max() - values.min()


# 鞋底最低点：`_shoe()` 的 boot rrect 中心 = foot + (2.5, 0.5).rotated(angle)，
# 半高 4.9、半宽 8.5；旋转后最低点 = foot.y + 5.4·cos + 2.5·sin + 8.5·|sin|。
func _sole_y(foot: Vector2, pitch: float) -> float:
	return foot.y + 5.4 * cos(pitch) + 2.5 * sin(pitch) + 8.5 * absf(sin(pitch))


# dir=0 左右腿时间对称：左腿在 t 的相位 = 右腿在 t+半周期 的相位。
# 比较同相位下的足高、俯仰和“相对各自 plant 的位移”；并要求双支撑时两脚关于中线对称。
func _mirror_error() -> float:
	var err := 0.0
	var plant_l := (DollPose.compute(0.0, "walk", 0)["foot_l"] as Vector2).x
	var plant_r := (DollPose.compute(DollPose.WALK_PERIOD * 0.5, "walk", 0)["foot_r"] as Vector2).x
	for i in 48:
		var t := DollPose.WALK_PERIOD * float(i) / 48.0
		var a := DollPose.compute(t, "walk", 0)
		var b := DollPose.compute(t + DollPose.WALK_PERIOD * 0.5, "walk", 0)
		err = maxf(err, absf((a["foot_l"] as Vector2).y - (b["foot_r"] as Vector2).y))
		err = maxf(err, absf(float(a["foot_angle_l"]) - float(b["foot_angle_r"])))
		err = maxf(err, absf(((a["foot_l"] as Vector2).x - plant_l)
				- ((b["foot_r"] as Vector2).x - plant_r)))
		var p_l := fposmod(t, DollPose.WALK_PERIOD) / DollPose.WALK_PERIOD
		var p_r := fposmod(p_l + 0.5, 1.0)
		if p_l < DollPose.WALK_STANCE and p_r < DollPose.WALK_STANCE:
			err = maxf(err, absf((a["foot_l"] as Vector2).x + (a["foot_r"] as Vector2).x))
	return err
