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
	var foot_roll_l := 0.0
	var foot_roll_r := 0.0
	var rear_step := 0.0

	match action:
		"walk":
			# 8 keys：contact / down / pass / up ×2。sin 采样与 8 关键帧等价，
			# 额外用脚掌滚动 + 重心下沉压住“滑步”。
			var ph := fposmod(time, 0.82) / 0.82
			var swing := ph * TAU
			gait = sin(swing)
			bob = -absf(cos(swing)) * 2.4
			lean = 0.09
			head_tilt = -0.05 + sin(swing * 2.0) * 0.025
			swing_r = -gait * 0.55
			swing_l = gait * 0.55
			bend_r = 0.18 + maxf(0.0, gait) * 0.32
			bend_l = 0.18 + maxf(0.0, -gait) * 0.32
			foot_roll_r = _foot_roll(ph)
			foot_roll_l = _foot_roll(fposmod(ph + 0.5, 1.0))
			secondary = -gait * 1.7
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
	var hip := Vector2(shake.x, HIP_Y + bob + absf(gait) * 1.8 + shake.y)
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
		"foot_angle_l": -shin_l * 0.35 + foot_roll_l,
		"foot_angle_r": -shin_r * 0.35 + foot_roll_r,
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


static func _foot_roll(phase: float) -> float:
	# 0 接触（脚跟先着地 -15°）→ 0.25 全掌 → 0.5 离地（脚尖 22°）→ 0.75 摆动（脚尖抬起）。
	var p := fposmod(phase, 1.0)
	if p < 0.5:
		return lerpf(-0.26, 0.38, smoothstep(0.12, 0.5, p))
	var t := smoothstep(0.5, 0.95, p)
	return lerpf(0.38, -0.26, t) * 0.55
