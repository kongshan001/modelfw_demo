# Action Forge 实测 · T-20261126-009

[Action Forge](https://actionforge.app/)（网页版，免费、免登录、文件不上传）对 **已有 Mixamo 动画 → KayKit Rogue 自有骨架 → Godot GLB** 链路的实测。含导出 GLB、Godot 4.6 预览工程、Blender/Godot 验证、操作录屏与截图。

**先说结论**：能用来做重定向和导出，**不是 Mixamo 的完全替代**。自动映射在 KayKit 这类非标准/chibi 骨架上只映射 17 根骨，导出物可播放、无骨骼拉伸，但行走明显屈膝前倾，需要手工修映射/rest pose。详细数据、许可与坑见 [`docs/action-forge-test.md`](docs/action-forge-test.md)。

## 目录

```
action-forge-test/
├── exports/                 Action Forge 导出（in-place / root-motion / 仅动画）
├── godot/                   Godot 4.6 预览工程（Rogue vs Michelle 源动画 + 骨骼调试）
├── recordings/              Action Forge 操作高亮 14s + Godot 预览 12s MP4/GIF + 会话导出
├── screenshots/             关键截图（映射/下载/Godot 对照/骨骼/1080p）
├── scripts/                 Playwright 操作脚本 + GLB 检查器
└── docs/action-forge-test.md
```

## 快速运行

```bash
# 预览（真实窗口；Intel HD 6000 实测 720p 平均 52 FPS）
godot --path action-forge-test/godot --resolution 1280x720

# headless 验收（无渲染，打印骨骼/时长/root motion/仅动画兼容性）
godot --headless --path action-forge-test/godot -s tools/smoke.gd   # → SMOKE_OK

# 性能（约 9 秒后打印）
godot --path action-forge-test/godot --resolution 1280x720 -- --bench

# 截图（可 1080p 离屏；--nohud 隐藏详细面板）
godot --path action-forge-test/godot --resolution 1280x720 -- \
  --shot=/tmp/shot.png --preset=2 --still --phase=0.25 --nohud --render-size=1920x1080

# 12 秒演示视频（Movie Maker，30fps）
godot --path action-forge-test/godot --resolution 1280x720 --write-movie /tmp/preview.avi \
  --fixed-fps 30 --quit-after 360 -- --demo
```

预览操作：`Space` 暂停 · `B` 骨骼 X-ray · `V` 切换 root-motion 导出 · `C` 自动环绕 · `H` HUD · `1–6` 机位 · 左键拖拽/滚轮。

## 关键数字

| 项 | 值 |
|---|---|
| Action Forge build | 20261125.274ae9a7（Beta，网页） |
| 账号 / 上传 | 无需登录；文件本地读取（官方 privacy/help） |
| 角色 | KayKit Rogue.glb：41 骨（应用显示 21），12 mesh / 5901 verts；自动缩放 0.803 → 1.76 m |
| 动作 | Michelle_Walk（Mixamo 65 骨，1.033 s，来自本仓库 animation-retarget-kit） |
| 自动映射 | 17 根（识别为 UE4 Mannequin）；“Two hands with fingers weren't found — map the arms by hand” |
| 导出 | 41 骨 / 12 mesh / 5901 verts；动画 `Michelle Walk_fit` 1.033 s；GLB 453,892 B（in-place） |
| in-place / root-motion | root XZ 位移 0.000 m / 0.0197 m（约 2.0 cm） |
| 髋部 Y 起伏 | AF 1.98 cm（本地轨道）/ 约 1.9 cm（世界采样）；源 5.81 cm（本地轨道）/ 约 7.7 cm（世界采样，0.01 根缩放 + 根旋转后） |
| Blender 验证 | max_bone_length_deviation = 1e-06（无骨长拉伸） |
| Godot | 41 骨可播放；原 Rogue 骨名 41/41 匹配；仅动画 GLB 无 Skeleton3D 且节点名 `upperarm_l` ≠ `upperarm.l` |
| 性能 | 1280×720 平均 52.4 FPS（min 17 瞬时 / max 75）；1440×762（1080p 请求被 1440×900 屏幕限制）平均 52.7 FPS；Intel HD 6000 / GL Compatibility |
| Console | headless 600 帧、Movie 360 帧、截图运行：0 个 SCRIPT/engine ERROR |

## 产物

- `exports/Rogue_MichelleWalk_AF_inplace.glb`：角色+骨架+动画，in-place（推荐先用这个）。
- `exports/Rogue_MichelleWalk_AF_rootmotion.glb`：同上，保留约 2 cm 的 root 位移。
- `exports/Rogue_MichelleWalk_AF_inplace_animonly.glb`：仅动画；Godot 中不能直接挂到 Rogue 骨架（见报告）。
- `recordings/af_operation.mp4`：14 s 实操高亮（Retarget 面板 → Animate → Download/In place/GLB）。
- `recordings/godot_preview.mp4` / `godot_preview_small.gif`：12 s Godot 对照预览（骨骼、root-motion 切换）。
- `recordings/af_operation_export.glb`：录屏会话中再次导出的文件（453,892 B，与 exports 一致）。

## 许可

Action Forge 代码 © CGstuff；库动画 CC0（Quaternius）；生成的 GLB 含 KayKit Rogue（CC0）和 Mixamo 样例动画（沿用仓库现有样例条款）。详见 [`CREDITS.md`](CREDITS.md)。UI 截图/录屏仅用于本次工具评测，不包含软件本体或库素材。

---

## T-013 深度复测（2026-11-26，follow-up of T-009）

> 参考视频 BV1LR4g68EmY（24:16，仅研究）；详细报告见 [`docs/action-forge-test.md`](docs/action-forge-test.md) 的 “T-013 深度复测”。

**结论**：

- “250+ 动画”**不成立**：当前 build UI 85 clips / manifest 89（含 3 个手指 pose + 1 个 FPS 测试）；分类/搜索/预览可用，抽样 16 个动作总体能用，但武器类没有道具。
- **分层可用**：base `Walk Loop` + upper-body `Idle Talking Loop`，自动 mask 到 Head/Neck/Spine/Clavicle/Arms/Hands；导出 GLB 里上半身差 0.40–1.26 rad、腿部差 ≤0.0008 rad；weight 0% 时与 base 等价。
- **限制**：layer 被裁到 base 长度（0.45 cycle）；拖 strip 会把 mask 重置为 Full body；composite root-motion 不烘焙；未保存的层重载会丢。
- **重定向**：内置 Walk Loop → Rogue 可播放；root 0.3371 m（标称 1.30 m 的 26%）、脚底 +3.03 cm、root-motion 支撑滑 0.417 m；仍是 17 骨自动映射的 chibi 步态。
- **Michelle 目标（重要 bug）**：应用识别 Mixamo、52/62 骨映射全对；但 1.8 m 的修正模型显示 **63 cm**，raw 导出 AABB **2.692 m**（源的 1.664 m 的 1.618×）；手动 0.618× 根缩放后 in-place 身高/姿态回到源水平（脚底 +1.1 cm、支撑滑 0.663 m ≈ 源 0.660 m），但 **rootmotion 导出异常**（hips Y 2.357 m）。raw + corrected 文件都在 exports；详见 docs §4。
- **导出**：GLB/FBX 均可用；Blender 骨长偏差 1e-06；Godot 4.6 GLB 21 轨 / FBX 28 轨；Unity 2022.3.49f1 headless FBX 导入成功（1.3333 s / 30 fps / Generic）。

**新增文件**：

```text
exports/
  Rogue_WalkLoop_AF_inplace.glb            base Walk，in-place
  Rogue_WalkLoop_AF_rootmotion.glb         base Walk，root 0.3371 m
  Rogue_Walk_IdleTalkLayer_AF_inplace.glb  base Walk + upper-body Idle Talking
  Rogue_Walk_IdleTalkLayer_AF.fbx          同上，FBX（Blender Units）
  Michelle_WalkLoop_AF_inplace.glb         raw（AABB 2.692 m，尺度 bug）
  Michelle_WalkLoop_AF_inplace_scaled.glb  0.618× 根缩放修正（AABB 1.664 m）
  Michelle_WalkLoop_AF_rootmotion.glb      raw root-motion（hips Y 2.357 m，不可用）
  Michelle_WalkLoop_AF.fbx                 65 骨 / 1 mesh / 650 fcurves
godot/
  layered.tscn + scripts/layered_preview.gd    base vs layered 预览；V 显示 base root-motion
  tools/smoke_layered.gd                       分层/root/脚滑/循环 smoke
  tools/smoke_base_walk.gd                     base smoke
  tools/inspect_fbx.gd                         FBX 直接导入检查
recordings/
  t013_af_layer_operation.mp4   61 s，真实 Action Forge 层权重/mask/导出段（2×）
  t013_godot_layered.mp4/.gif   12 s，Godot 4.6 base vs layered
screenshots/
  t013_library_85.png, t013_layers_mask.png, t013_export_panel.png,
  t013_godot_front_1280.png, t013_godot_front_1920.png,
  t013_michelle_retarget.png, t013_michelle_app_63cm.png
scripts/
  af_library_audit.py           拉 manifest/统计 85/89
  af_layer_export.py            分层导出 Playwright 参考流程（base + upper-body layer + GLB/FBX）
  af_character_retarget.py      Michelle 上传/识别/导出参考流程（含 0.618× 说明）
```

**分层预览**：

```bash
godot --path action-forge-test/godot --resolution 1280x720 res://layered.tscn
godot --headless --path action-forge-test/godot -s tools/smoke_layered.gd   # → SMOKE_LAYERED_OK
godot --path action-forge-test/godot --resolution 1280x720 \
  --write-movie /tmp/layered.avi --fixed-fps 30 --quit-after 360 res://layered.tscn -- --demo
```

注意：`t013_af_layer_operation.mp4` 的真实 session 段演示的是早期 **Full body** 层（含拖拽踩坑）；最终 upper-body 层在后续 session 重建，数据以 docs §2 和 `Rogue_Walk_IdleTalkLayer_AF_inplace.glb` 为准。

---

## T-023 走路朝向修复 + 原创偶像鸡舞（2026-11-26，follow-up of T-013）

> 详细诊断/参数：[`docs/WALK_FORWARD_CALIBRATION.md`](docs/WALK_FORWARD_CALIBRATION.md) · 报告：[`docs/action-forge-test.md`](docs/action-forge-test.md) 的 “T-023” 章节。

**结论**：

- **模型 forward = +Z**（KayKit Rogue rest：脚/趾 +Z、髋线 +Z、hips yaw 0°）。**不是** Godot 相机常用的 −Z。
- **Quaternius `Walk Loop` 是 +Z（0.1°）**，root 旋转 identity，root-motion **+Z 0.3371 m** → 方向本来就对。
- **Mixamo `Michelle Walk_fit` 带 180° hips yaw**（身体/靴子朝 −Z）→ 在 +Z 控制器上就是倒走。根因不是预览没转身，也不是模型朝错。
- **修复在 hips 层**：`scripts/glb_yaw_fix.py` 给 hips 旋转轨道左乘 180°，输出 `Rogue_MichelleWalk_AF_inplace_yawfix.glb`；不改 mesh/root，不只手转上半身。
- **8 方向验证**：FIXED 身体误差 1.2–6.4° / 靴子 0.5–9.5°；RAW 173.3–179.2° / 172.4–178.6°；QUAT 0.1–2.0° / 0.0–0.1°；位移方向点积 1.000。
- **原创偶像鸡舞**：8.000 s / 30 fps，4 小节（展翅+膝盖弹跳 / 摆胯+抖肩 / 比心+点头 / 360° 转圈+落心）；Godot 41 骨/12 mesh/27 轨；循环 seam 0.0010 rad（最终；早期采样 0.0164）；scale dev 0；Blender 骨长偏差 1e-06。**不使用任何艺人姓名/肖像/原曲/歌词/原编舞；视频无音乐**。
- **性能**：1280×720 平均 **78.3 FPS**（min 77 / max 80，Intel HD 6000）；walk/dance 各 600 帧 headless **0 ERROR**。

**新文件**：

```text
exports/
  Rogue_MichelleWalk_AF_inplace_yawfix.glb   180° hips 修正（before/after 用）
  Rogue_IdolChickenDance_original.glb        8 s 原创舞蹈（角色+动画）
source/
  Rogue_IdolChickenDance_original.blend      Blender 源
godot/
  walkmove.tscn + scripts/walkmove.gd         RAW/FIXED 双人、4/8 向、Dance 舞台
  tools/diag_facing.gd, diag_gait.gd          朝向/步态采样
  tools/smoke_walkmove.gd                     8 向 + 舞蹈循环 smoke
scripts/
  glb_yaw_fix.py                              通用 bone yaw 烘焙
  blender_idol_dance.py                       原创舞蹈生产（Blender 3.4.1）
recordings/
  t023_walk_direction.mp4/.gif                12 s RAW vs FIXED 4 向
  t023_idol_dance.mp4/.gif                    10 s 原创舞蹈
screenshots/
  t023_walk_data_1280.png, t023_walk_duo_1920.png, t023_walk_world_1920.png,
  t023_dance_contact.png, t023_dance_1280.png, t023_dance_1920.png
```

**运行**：

```bash
# 交互（WASD 8 向；3=舞蹈；5=RAW/FIXED；P=自动路径）
godot --path action-forge-test/godot --resolution 1280x720 res://walkmove.tscn

# 12 s RAW vs FIXED 4 向对照
godot --path action-forge-test/godot --resolution 1280x720 res://walkmove.tscn -- --demo=walk --speed=1.0

# 10 s 原创舞蹈
godot --path action-forge-test/godot --resolution 1280x720 res://walkmove.tscn -- --demo=dance

# 验收
godot --headless --path action-forge-test/godot -s tools/smoke_walkmove.gd   # → SMOKE_WALKMOVE_OK
godot --path action-forge-test/godot --resolution 1280x720 -- --bench --demo=walk --speed=1.0
```

**操作**：`WASD/方向键` 8 向移动 · `Shift` 加速 · `1` Idle · `2` Walk · `3` Dance · `4` Clip · `5` RAW/FIXED · `P` 自动路径 · `C` 相机 · `H` HUD · `R` Reset · `Space` 暂停。绿箭头=移动方向，红箭头=实测身体朝向，脚下红/绿环区分 RAW/FIXED。

**IP/许可**：舞蹈为本任务原创编排；不使用任何艺人的姓名、肖像、原曲、歌词、原编舞；无音轨。角色 KayKit Rogue CC0；`yawfix` 是 Mixamo 样例动画的衍生（沿用 `animation-retarget-kit` 的样例条款，内部评测）。详见 [`CREDITS.md`](CREDITS.md)。
