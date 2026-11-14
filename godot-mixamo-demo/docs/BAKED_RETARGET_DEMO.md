# 展示 Demo：SambaDance + Soldier Run → Michelle

这个 demo 有两个模式：

- **Dance（默认）**：Michelle 原生 `SambaDance`，固定正面机位，效果与 `dance_demo.gif` 一致；
- **Baked Run**：`animation-retarget-kit` 离线烘焙出的 Soldier Run，角色绕圈跑 + 前侧 3/4 跟随镜头。

按 `Space` 切换。Run 模式走 **animation-retarget-kit** 的离线流程：

```text
inspect 源/目标
  → retarget（Blender headless，Soldier Run → Michelle）
  → validate（骨长漂移 < 1%）
  → 目标 GLB 自带 baked clip
  → Godot 默认播放 SambaDance；Space 切 baked Run
```

## 1. 生成 baked 资产

在仓库根目录：

```bash
cd animation-retarget-kit

bash tools/blender_inspect.sh assets/source/Soldier.glb --require-armature
bash tools/blender_inspect.sh assets/target/Michelle.glb --require-armature

bash tools/blender_retarget.sh \
  --source assets/source/Soldier.glb \
  --target assets/target/Michelle.glb \
  --clip Run \
  --out /tmp/Michelle_Run.glb \
  --fps 30

bash tools/blender_validate.sh /tmp/Michelle_Run.glb

cp /tmp/Michelle_Run.glb ../godot-mixamo-demo/assets/characters/baked/Michelle_Run.glb
```

本次结果：

- 源 49 骨骼 / 目标 65 骨骼，映射 49；
- 目标多出的手指/脚趾末端保持 rest；
- `max_bone_length_deviation ≈ 2e-06`；
- 输出 1 条 baked clip（GLB 内动作名可能为 `Animation`）。

## 2. 运行 demo

```bash
godot --path godot-mixamo-demo scenes/baked_demo.tscn
```

场景内容：

**Dance（默认）**
- 直接播放 `assets/characters/Michelle.glb` 的原生 `SambaDance`（循环）；
- 固定正面机位 `(0, 2.2, 4.8)` → 看向 `(0, 1.2, 0)`，近景舞台与运行时 `demo.tscn` 一致。

**Baked Run（`Space` 切换）**
- 直接播放 `assets/characters/baked/Michelle_Run.glb` 的唯一动画；
- 角色沿半径 4.2m 的环跑（角速度 0.8 rad/s，约 3.4 m/s），朝向沿切线；地面有一圈细石环作为跑道参照；
- 相机在角色前方偏右（前向 1.8m、右向 3.3m、高 1.9m）跟随，始终看向角色胸口，展示正面跑姿。

HUD 状态行会显示 `Michelle · SambaDance (native)` 或 `Michelle · Run (baked)`；`Space` 随时切换。

## 3. 录制 GIF

```bash
# Dance（默认）
CAPTURE_OUT=/tmp/mixamo_dance_showcase_frames \
  godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_baked_demo.gd

# Baked Run
CAPTURE_OUT=/tmp/mixamo_baked_demo_frames \
  godot --path godot-mixamo-demo --resolution 1280x720 -s tools/capture_baked_demo.gd -- --run
# 输出：$CAPTURE_OUT/frame_000.png ... frame_059.png
```

GIF：`docs/dance_showcase.gif`（SambaDance）、`docs/baked_run_demo.gif`（baked Run），均 1280×720 / 4 秒 / 15fps。

## 4. 与运行时 demo 的区别

| | `demo.tscn` | `baked_demo.tscn` |
|---|---|---|
| 方式 | 运行时 `RetargetModifier3D` | 原生 SambaDance + 离线 Blender bake |
| 动画源 | 隐藏 Soldier 骨架实时驱动 Michelle | 原生 `SambaDance` / 目标 GLB 自带 baked clip |
| 输入 | WASD / Shift / Tab / Space | `Space`: Dance / Baked Run |
| 用途 | 验证运行时重定向 | 展示舞步 + 验证工具链产物可直接进引擎 |

## 5. 迭代记录：取景、姿态与舞步

- **问题 1（取景）**：旧版角色原地播放 Run、相机绕角色转，像“跑步机”；改成背后跟随后又只看到背面，石环横穿画面、镜头会擦到石柱。
- **问题 2（姿态）**：baked Run 的手肘被拉直，跑起来像滑行。对照运行时 `RetargetModifier3D` 发现 bake 工具把**全局 pose/rest** 代入了 Godot 的父级 rest 公式。
- **问题 3（舞步）**：用户要舞步；好看的 `SambaDance` 是 Michelle 原生动画，不是 kit 烘出的 Run。
- **改法**：
  - 取景：角色沿半径 4.2m 的环跑（0.8 rad/s），相机放在前方偏右（前向 1.8m、右向 3.3m、高 1.9m）跟随；石环收细为跑道路标；去掉与 HUD 冲突的头顶 `Label3D`。
  - 姿态：`blender_retarget.py` 改为 Godot 同式的**局部 pose/rest + 父级 rest 基变换**，重新 bake；手肘角度与源差 < 2°（修复前 90°→16°）。
  - 舞步：默认播放原生 `SambaDance`，固定正面机位；近景舞台复用运行时 demo 的柱子/石块，`Space` 切 baked Run。
- **效果对比**：修复前“背面 + 直臂滑行” → 修复后“正面 3/4 + 手肘弯曲跑姿”；另加默认 SambaDance。GIF：舞步 0.42MB、Run 0.88MB（均 4s / 15fps）。
- **验证**：`BAKED_DEMO_SMOKE_OK`（含两模式切换）；`max_bone_length_deviation=2e-06`；GIF 抽帧确认舞步正面观感与 Run 姿态。
- **限制**：舞步是 Michelle 原生，不经过 retarget；要把舞步重定向到 Soldier/Xbot，需要源舞蹈 clip + Rest Fixer。Run 位移由脚本驱动，没有从 baked clip 提取 root motion；脚底滑步未做 IK 修正。
