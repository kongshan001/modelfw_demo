class_name DollPose
extends RefCounted

# 纸偶骨骼：一条脊柱 + 双臂双骨链 + 双腿双骨链。
# 所有槽位的绘制都只读取这里的关节与角度，因此换装、换向、换动作时天然对齐。
# 坐标原点 = 脚底中心，y 向上为负；美术朝向固定为“右”，左向由渲染节点镜像。
#
# 8 向（评审 P0-4）：yaw 正 0.0 / 斜 0.55 / 侧 1.0；肩宽收 36%，髋宽收 72%，
# 头部前探 5.2 local；远侧手臂 / 腿额外后移，避免正/背/侧剪影互相重叠。
# 4 动作：idle 1.4 local 呼吸；walk 8 keys + 脚跟着地→脚尖离地；
# attack 蓄力停顿 / 2 帧 smear / 收势；hit 后脚退 6 local + 头 17° 甩动。
# secondary = 披风/头发/帽尖的滞后量（local），由动作相位给出。
#
# T-20261121-001 walk 修复：
# 旧版在 hip/knee 上直接加角度，支撑相脚底随身体向后扫（dir6 45.26px 滑步）。
# 现在 walk 的腿改为 2 骨 IK：脚目标在支撑相锁定在 x=plant（原地踏步 gait），
# 摆动相抬起并收回；髋部只做上下/前后小幅摆动。脚掌直接按 −15°→0°→+22° 滚动，
# 踝点随脚掌俯仰抬离地面（绕脚跟/脚尖滚动），不再用 shin 角度推导脚掌。
const HIP_Y := -50.0
const CHEST_OFFSET := 36.0
const NECK_OFFSET := 52.0
const HEAD_OFFSET := 19.0
const HEAD_R := 18.0
const UPPER_ARM := 20.0
const FOREARM := 18.0
const THIGH := 25.0
const SHIN := 22.0
const SHOULDER_X := 14.5
const HIP_X := 8.5
const WALK_PERIOD := 0.82
const WALK_STANCE := 0.58
const WALK_GROUND := -3.0
const WALK_HEEL := -0.2618  # −15°：脚跟着地
const WALK_TOE := 0.3840     # +22°：脚尖离地
const WALK_FOOT_PIVOT := 8.5  # 鞋掌前后半径，脚掌俯仰时踝点抬高量
const WALK_SOLE_DROP := 5.4   # 靴中心偏移 0.5 + 半高 4.9：判断鞋底最低点


static func compute(time: float, action: String, dir_index: int) -> Dictionary:
	var dir: Dictionary = DollData.DIRS[clampi(dir_index, 0, 7)]
	var yaw: float = dir["yaw"]
	var back: bool = dir["back"]
	var flip: bool = dir["flip"]

	var gait := 0.0
	var bob := 0.0
	var lean := 0.0
	var head_tilt := 0.0
	var arm_l := -0.14
	var arm_r := 0.14
	var bend_l := 0.14
	var bend_r := 0.14
	var swing_l := 0.0
	var swing_r := 0.0
	var attack_k := 0.0
	var slash := 0.0
	var hit_k := 0.0
	var shake := Vector2.ZERO
	var stance := 1.0
	var secondary := 0.0
	var rear_step := 0.0
	var walk_ik := false
	var walk_phase := 0.0
	var hip_shift := 0.0

	match action:
		"walk":
			# 8 keys：contact / down / pass / up ×2。腿部不再用角度摆动，
			# 交给下方 2 骨 IK + 锁脚目标；这里只给相位、重心和上身。
			var ph := fposmod(time, WALK_PERIOD) / WALK_PERIOD
			var swing := ph * TAU
			walk_ik = true
			walk_phase = ph
			gait = sin(swing)
			# 双支撑（contact）最低、经过（pass）最高：每步一次，周期为半步。
			bob = 2.6 + 0.9 * cos(swing * 2.0)
			hip_shift = -gait * 0.9
			lean = 0.09
			head_tilt = -0.05 + sin(swing * 2.0) * 0.025
			# 手臂与“向前摆的那条腿”反相：右腿摆动时右臂向后、左臂向前。
			swing_l = gait * 0.52
			swing_r = -gait * 0.52
			bend_l = 0.16 + maxf(0.0, swing_l) * 0.70
			bend_r = 0.16 + maxf(0.0, swing_r) * 0.70
			# 披风/头发滞后 2 帧 @30fps（0.82s 周期内 0.51 rad），幅度 3.4 local
			# → 披风 sway = lag × 1.4 ≈ ±4.8 local。
			secondary = -sin(swing - TAU * (2.0 / 30.0) / WALK_PERIOD) * 3.4
		"attack":
			# 0.00–0.28 蓄力 / 0.28–0.40 停顿 / 0.40–0.52 挥砍 / 0.62–0.98 收势。
			var p := fposmod(time, 1.05) / 1.05
			var wind := smoothstep(0.0, 0.28, p)
			var swing := smoothstep(0.40, 0.52, p)
			var recover := smoothstep(0.62, 0.98, p)
			attack_k = wind * (1.0 - recover)
			var windup_angle := lerpf(0.14, -2.30, wind)
			arm_r = lerpf(windup_angle, 1.55, swing)
			arm_r = lerpf(arm_r, 0.20, recover)
			bend_r = lerpf(0.30, 0.02, swing)
			arm_l = lerpf(-0.14, -0.92, wind)
			arm_l = lerpf(arm_l, -0.36, swing)
			bend_l = 0.32
			lean = lerpf(0.03, -0.11, wind)
			lean = lerpf(lean, 0.22, swing)
			lean = lerpf(lean, 0.02, recover)
			head_tilt = -0.14 * swing + 0.04 * wind
			bob = -1.1 * wind + 1.2 * swing
			gait = 0.24 * swing
			stance = 1.08
			slash = sin(PI * clampf((p - 0.40) / 0.24, 0.0, 1.0))
			secondary = -2.6 * wind + 6.5 * swing * (1.0 - recover)
		"hit":
			var p := fposmod(time, 1.10) / 1.10
			hit_k = exp(-p * 5.5) * (1.0 - smoothstep(0.50, 0.95, p))
			shake = Vector2(sin(time * 79.0), cos(time * 61.0)) * 2.2 * hit_k
			lean = 0.02 - 0.26 * hit_k
			head_tilt = -0.30 * hit_k + sin(time * 38.0) * 0.05 * hit_k
			arm_r = 0.14 + 1.60 * hit_k
			arm_l = -0.14 - 1.60 * hit_k
			bend_r = 0.14 + 0.32 * hit_k
			bend_l = 0.14 + 0.32 * hit_k
			bob = -1.6 * hit_k
			gait = 0.12 * hit_k
			stance = 1.0 + 0.18 * hit_k
			rear_step = -6.0 * hit_k
			secondary = -5.2 * hit_k
		_:
			var ph := time * 2.1
			bob = sin(ph) * 1.4
			lean = sin(ph * 0.5) * 0.02
			head_tilt = sin(ph + 0.9) * 0.035
			swing_r = -sin(ph) * 0.05
			swing_l = sin(ph) * 0.05
			bend_r = 0.16
			bend_l = 0.16
			secondary = sin(ph - 0.9) * 1.3

	# 行走时脚底会略微离地，用轻微下沉把重心压回地面，避免“飘”。
	# walk 的 IK 自己负责脚接触，不再叠加 abs(gait) 下沉，避免把锁脚目标拉离可解范围。
	var hip := Vector2(shake.x + hip_shift,
			HIP_Y + bob + (0.0 if walk_ik else absf(gait) * 1.8) + shake.y)
	var narrow := 1.0 - 0.72 * yaw
	var chest := hip + Vector2(0.0, -CHEST_OFFSET).rotated(lean)
	var neck := hip + Vector2(0.0, -NECK_OFFSET).rotated(lean)
	# 3/4 与侧面时头部向朝向侧探出 5.2 local，配合鼻梁/远侧眼距强化方向。
	var head_shift := Vector2(yaw * 5.2, 0.0)
	var head := neck + Vector2(0.0, -HEAD_OFFSET).rotated(lean + head_tilt) + head_shift
	var head_angle := lean + head_tilt

	# 肩宽收窄 36%：侧身时双臂前后错开，读得出“侧”。
	var shoulder_narrow := 1.0 - 0.36 * yaw
	var shoulder_l := chest + Vector2(-SHOULDER_X * shoulder_narrow, 1.5).rotated(lean)
	var shoulder_r := chest + Vector2(SHOULDER_X * shoulder_narrow, 1.5).rotated(lean)
	# 远侧手臂整体后移 3.5 local（沿 -x），近侧手臂向前 3.8 local（侧向时露在身体前）。
	shoulder_l += Vector2(-3.5, 0.6) * yaw
	shoulder_r += Vector2(3.8, 0.0) * yaw

	var upper_l := arm_l + swing_l
	var upper_r := arm_r + swing_r
	var fore_l := upper_l + bend_l
	var fore_r := upper_r - bend_r
	var elbow_l := shoulder_l + _dir(upper_l) * UPPER_ARM
	var elbow_r := shoulder_r + _dir(upper_r) * UPPER_ARM
	var hand_l := elbow_l + _dir(fore_l) * FOREARM
	var hand_r := elbow_r + _dir(fore_r) * FOREARM

	var hip_l := hip + Vector2(-HIP_X * narrow * stance, 0.0).rotated(lean * 0.3)
	var hip_r := hip + Vector2(HIP_X * narrow * stance, 0.0).rotated(lean * 0.3)
	# 远侧腿后移 3 local；受击时后脚再退 6 local（重心后坐）。
	hip_l += Vector2(-3.0 * yaw + rear_step, 0.0)
	var leg_amp := lerpf(0.30, 0.58, yaw) * (1.0 + 0.12 * attack_k)
	var thigh_l := -gait * leg_amp - 0.06 * hit_k + rear_step * 0.012
	var thigh_r := gait * leg_amp + 0.06 * hit_k
	var shin_l := thigh_l + maxf(0.0, gait) * 0.78 + 0.03
	var shin_r := thigh_r + maxf(0.0, -gait) * 0.78 + 0.03
	var knee_l := hip_l + _dir(thigh_l) * THIGH
	var knee_r := hip_r + _dir(thigh_r) * THIGH
	var foot_l := knee_l + _dir(shin_l) * SHIN
	var foot_r := knee_r + _dir(shin_r) * SHIN
	var foot_angle_l := -shin_l * 0.35
	var foot_angle_r := -shin_r * 0.35

	if walk_ik:
		# 支撑相脚 x 锁定在 plant（不含 hip sway），仅允许 IK 可达误差；摆动相抬起收回。
		# 正面/背面：左右膝分别向外让位（对称），读作原地踏步而不是同向侧踢；
		# 3/4 与侧面：两膝都朝美术朝向（前）弯，避免反关节。
		var plant_l := -HIP_X * narrow * stance * cos(lean * 0.3) - 3.0 * yaw
		var plant_r := HIP_X * narrow * stance * cos(lean * 0.3)
		# 左脚在 ph=0 触地，右脚滞后半个周期（0.41s），和旧版触地相位一致。
		var p_l := walk_phase
		var p_r := fposmod(walk_phase + 0.5, 1.0)
		var bend_sign_l := -1.0 if yaw < 0.20 else 1.0
		var sol_l := _solve_leg(hip_l, _walk_foot_target(p_l, plant_l, yaw), bend_sign_l)
		var sol_r := _solve_leg(hip_r, _walk_foot_target(p_r, plant_r, yaw), 1.0)
		knee_l = sol_l["knee"]
		foot_l = sol_l["foot"]
		knee_r = sol_r["knee"]
		foot_r = sol_r["foot"]
		foot_angle_l = _walk_foot_pitch(p_l)
		foot_angle_r = _walk_foot_pitch(p_r)

	return {
		"time": time,
		"action": action,
		"direction": clampi(dir_index, 0, 7),
		"yaw": yaw,
		"back": back,
		"flip": flip,
		"side": yaw >= 0.85,
		"hip": hip,
		"chest": chest,
		"neck": neck,
		"head": head,
		"head_angle": head_angle,
		"head_r": HEAD_R,
		"torso_lean": lean,
		"shoulder_l": shoulder_l,
		"shoulder_r": shoulder_r,
		"elbow_l": elbow_l,
		"elbow_r": elbow_r,
		"hand_l": hand_l,
		"hand_r": hand_r,
		"arm_angle_l": upper_l,
		"arm_angle_r": upper_r,
		"forearm_angle_l": fore_l,
		"forearm_angle_r": fore_r,
		"hip_l": hip_l,
		"hip_r": hip_r,
		"knee_l": knee_l,
		"knee_r": knee_r,
		"foot_l": foot_l,
		"foot_r": foot_r,
		"foot_angle_l": foot_angle_l,
		"foot_angle_r": foot_angle_r,
		"weapon_angle": upper_r,
		"slash": slash,
		"hit": hit_k,
		"attack": attack_k,
		"bob": bob,
		"stride": gait,
		"secondary": secondary,
	}


static func _dir(angle: float) -> Vector2:
	# 角度 0 = 竖直向下，正角朝美术朝向（右）旋转。
	return Vector2(sin(angle), cos(angle))


static func _solve_leg(hip: Vector2, target: Vector2, bend_sign: float) -> Dictionary:
	# 2 骨 IK：膝落在以 hip/target 为圆心、半径 THIGH/SHIN 的两圆交点上。
	# bend_sign=+1 膝朝美术朝向（右）弯；−1 用于正面/背面的外侧让位。
	var delta := target - hip
	var raw := delta.length()
	var d := clampf(raw, 8.0, THIGH + SHIN - 0.35)
	var u := delta / raw if raw > 0.001 else Vector2(0, 1)
	var along := (THIGH * THIGH - SHIN * SHIN + d * d) / (2.0 * d)
	var h := sqrt(maxf(THIGH * THIGH - along * along, 0.0))
	var perp := Vector2(u.y, -u.x) * bend_sign
	return {
		"knee": hip + u * along + perp * h,
		"foot": hip + u * d,
	}


static func _walk_foot_target(phase: float, plant_x: float, yaw: float) -> Vector2:
	# 原地踏步 gait：支撑相 x/y 固定；摆动相沿 sin² 弧线抬起、sin³ 前探后收回。
	# sin³ 让脚在离地 <1 local 的两端几乎不横移，锁脚判定（≤2px）不受摆动端点影响。
	var p := fposmod(phase, 1.0)
	var pitch := _walk_foot_pitch(p)
	# 脚掌俯仰绕脚跟/脚尖滚动：踝点抬高，使鞋底最低点始终落在同一地面高度。
	var ankle_lift := WALK_SOLE_DROP * cos(pitch) \
			+ 2.5 * sin(pitch) + WALK_FOOT_PIVOT * absf(sin(pitch)) - WALK_SOLE_DROP
	if p < WALK_STANCE:
		return Vector2(plant_x, WALK_GROUND - ankle_lift)
	var s := (p - WALK_STANCE) / (1.0 - WALK_STANCE)
	var rise := sin(PI * s)
	var lift := (5.5 + 6.5 * yaw) * rise * rise
	var reach := (2.0 + 5.0 * yaw) * rise * rise * rise
	return Vector2(plant_x + reach, WALK_GROUND - lift - ankle_lift)


static func _walk_foot_pitch(phase: float) -> float:
	# −15° 脚跟着地 → 0° 全掌贴地 → +22° 脚尖离地 → 摆动回 −15°。
	# 只做矢状面俯仰，不叠加 shin 角度，避免脚踝外翻/扭曲。
	var p := fposmod(phase, 1.0)
	if p < 0.10:
		return lerpf(WALK_HEEL, 0.0, smoothstep(0.0, 0.10, p))
	if p < 0.36:
		return 0.0
	if p < WALK_STANCE:
		return lerpf(0.0, WALK_TOE, smoothstep(0.36, WALK_STANCE, p))
	var s := (p - WALK_STANCE) / (1.0 - WALK_STANCE)
	return clampf(lerpf(WALK_TOE, WALK_HEEL, smoothstep(0.0, 1.0, s))
			- 0.10 * sin(PI * s), WALK_HEEL, WALK_TOE)
