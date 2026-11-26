# 走路朝向标定（T-023）

> 场景：`godot/walkmove.tscn` · 工具：`godot/tools/diag_facing.gd`、`diag_gait.gd`、`smoke_walkmove.gd` · 修复：`scripts/glb_yaw_fix.py`

## 结论

| 层 | 实测 | 判定 |
|---|---|---|
| KayKit Rogue 模型 rest | 脚/趾方向 **+Z**，髋线正前 **+Z**，hips yaw 0° | **模型 forward = +Z**（不是 Godot 相机常用的 −Z） |
| Action Forge `Walk Loop`（Quaternius） | 身体/靴子 **+Z**，hips yaw **0.1°**，root 旋转 identity，root-motion **+Z 0.3371 m** | **0° 标定，可直接用** |
| Action Forge `Michelle Walk`（raw） | 身体/靴子 **−Z**，hips yaw **178°**，root 旋转 identity，in-place | **clip 自身带 180° yaw**，在 +Z 模型上就是倒走 |
| `Michelle Walk_fit_yawfix`（本次修复） | 身体/靴子 **−2°**，hips yaw **−2°**，root 不变 | **0° 标定（hips +180° 烘焙）** |
| 旧 `main.tscn` 预览 | 对整个 visual 根加 `AF_YAW=180°`，只做静态构图 | **全局转 mesh 会掩盖 clip 的 180°**；移动控制不要沿用它 |

**结论一句话**：不是模型朝错，也不是预览移动代码没转身；是 **Mixamo→Rogue 的 Michelle clip 保留了源骨架的 180° hips yaw**。修正层应该是 **hips（骨盆）yaw**，不是整体 mesh、不是 root、也不是只转上半身。

## 标定常量

```gdscript
const MODEL_FORWARD_DEG := 0.0        # KayKit Rogue rest forward = +Z
const CONTROLLER_YAW := atan2(dir.x, dir.z)  # +Z 模型：不要用 look_at 的 -Z 约定
const CLIP_FORWARD_YAW := {
    "quat": 0.0,                      # Quaternius Walk Loop，已验证
    "michelle_raw": 180.0,            # 源 clip 实际朝 -Z
    "michelle_fix": 0.0,              # hips +180° 烘焙后的版本
}
```

- **root 旋转**：三个 clip 的 `root` rotation track 都是 identity（T-023 实测），所以不是导出根旋转问题。
- **root-motion**：Quat 的 root 位移是 **+Z 0.3371 m / 1.3333 s**；把 actor 的 +Z 对到移动方向后，root-motion 与朝向一致。Michelle 的 in-place 版 root XZ=0，位移由代码驱动。
- **脚滑**：AF 17 骨自动映射的步幅与 root-motion 不完全匹配（T-013 的支撑脚 0.417 m 滑移仍在）；这是重定向质量限制，不是朝向 bug。

## 修复做法（为什么是 hips）

`scripts/glb_yaw_fix.py` 找到 `hips` 节点的 rotation 轨道，把每个四元数 **左乘** 一个 180° Y 旋转：

```text
q' = q_yaw(180°) * q
q_yaw(θ) = (0, sin(θ/2), 0, cos(θ/2))
```

- hips 是骨架的骨盆枢轴，旋转它会让 **躯干、手臂、腿、脚** 一起旋转，步态相位保持一致。
- 不转 root：Michelle 的 root XZ 为 0，root 在 z=+0.0501；转 root 会让身体绕前移 10 cm 的点转，不如 hips 居中。
- 不转 mesh：整体转 mesh 只能“看起来对”，换动作/换 clip 又会错，且会破坏 root-motion 方向。
- 不只手转上半身：只转 chest/spine 会让下肢继续朝 −Z，就是用户说的“侧走/脚朝错方向”。

输出：

```text
exports/Rogue_MichelleWalk_AF_inplace.glb        # 修复前（raw，−Z）
exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb # 修复后（hips +180°）
```

复现：

```bash
python3 action-forge-test/scripts/glb_yaw_fix.py \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace.glb \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb \
  --bone hips --yaw 180 --anim "Michelle Walk_fit" --rename "Michelle Walk_fit_yawfix"
```

## 8 方向实测（`smoke_walkmove.gd`，actor yaw = atan2(dir.x, dir.z)）

| clip | 身体朝向误差（8 向） | 靴子朝向误差 | 判定 |
|---|---:|---:|---|
| FIXED（yawfix） | 1.2–6.4° | 0.5–9.5° | 8/8 OK |
| RAW（Michelle raw） | 173.3–179.2° | 172.4–178.6° | 8/8 倒走 |
| QUAT（Quaternius） | 0.1–2.0° | 0.0–0.1° | 8/8 OK |

- 位移方向点积 1.000（0.52–0.54 m / 0.65 s @ 0.8 m/s）。
- 方法：身体朝向 = `up × (upperleg.r − upperleg.l)` 的世界方向；靴子朝向 = `foot` 骨骼相对 rest 的旋转增量（先在 skeleton-local 算，再乘 actor yaw）；每帧平滑。
- 判断阈值：`body_err > 150°` 且 `boot_err > 120°` → BACK-WALK；35–120° → SIDE-STEP。

## 在游戏里怎么接

1. 角色控制器用 **+Z 为模型正前**：`rotation.y = atan2(dir.x, dir.z)`；不要对 Rogue 直接 `look_at()`（Godot 的 `look_at` 让 −Z 朝向目标）。
2. 每个动画 clip 记录自己的 `forward_yaw`；加载时把 `forward_yaw` 烘焙进 hips（或运行时给 hips 乘一个修正四元数）。不要把修正加到 mesh/visual 根上。
3. 如果用 root-motion：Quat 的 root 轨道指向 +Z，和 0° 标定一致；Michelle 目前只有 in-place，位移由代码给。
4. 旧 `AF_YAW=180` 的静态预览不要再当移动标定；它只是让角色在构图里面向相机。

## 复现

```bash
# 朝向/靴子/root/hips 采样
godot --headless --path action-forge-test/godot -s tools/diag_facing.gd
godot --headless --path action-forge-test/godot -s tools/diag_gait.gd

# 8 方向 + 舞蹈循环验收
godot --headless --path action-forge-test/godot -s tools/smoke_walkmove.gd
#  → SMOKE_WALKMOVE_OK

# 预览
godot --path action-forge-test/godot --resolution 1280x720 res://walkmove.tscn
# RAW vs FIXED 双人 4 向路径：
godot --path action-forge-test/godot --resolution 1280x720 res://walkmove.tscn -- --demo=walk --speed=1.0
```

## 限制

- 180° 修正是刚性的 pelvis yaw，不做接触/步幅 IK；AF 自动 17 骨映射的屈膝/步幅小/脚滑仍在（T-009/T-013 已记录）。
- 修复只针对这份 `Michelle Walk_fit`；其他 Mixamo→Rogue clip 需要用同样的方法逐个测 `forward_yaw`，不要默认 180°。
- 舞蹈/走路视频无音频；舞蹈为原创动作，不是任何艺人的原编舞。
