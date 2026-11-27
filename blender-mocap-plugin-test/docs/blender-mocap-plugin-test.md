# 自制 Blender 动捕插件实测（T-20261127-004）

> 日期：2026-11-27 · 参考视频：[BV18fWM6MEMg](https://www.bilibili.com/video/BV18fWM6MEMg)（583 s，UP 黑黑猴blender） · 引擎：Godot 4.6 stable（GL Compatibility） · Blender 3.4.1 · 机器：macOS 12.7.6 / Intel HD Graphics 6000
> 角色：KayKit Rogue（CC0，`godot-garden/assets/models/kaykit/Rogue.glb`） · 输入：上游 RGB MoCap 示例（仅 `/tmp`/gitignored，未提交）
> 相关基线：[`docs/MIXAMO_RETARGET.md`](../../docs/MIXAMO_RETARGET.md)、[`action-forge-test/docs/action-forge-test.md`](../../action-forge-test/docs/action-forge-test.md)、`animation-retarget-kit/`

## 0. 结论（先看）

1. **视频里的插件本体是 Pose_AI（中文 Blender 插件），不是公开可下载的项目。** 安装目录 `Blender_Addons/Pose_AI`；演示用 **Blender 3.3.2**；快速模式用 MediaPipe，准确模式包 `RGBMocap_CN`（上游 `toyxyz/toyxyz_RGBMocap` + ExMR/SAM2/SMPL-X/MANO）。简介/评论区没有下载链接，作者走“三连 + 私信/进群”，评论区反馈未发；上游是 Windows 原生，macOS 仅 Apple Silicon（Intel 被 installer 拒绝）。**本机无法安装/运行插件本体**，详见 [`PLUGIN_AVAILABILITY.md`](PLUGIN_AVAILABILITY.md)。本报告没有伪造插件运行结果。
2. **按规格退化为“能力拆解 + 替代验证”：用与 Pose_AI 快速模式相同的 MediaPipe Pose/Hand 模型**（`pose_landmarker_heavy.task` + `hand_landmarker.task`）跑通“视频 → 姿态 → 重定向 → GLB → Godot”。输入为上游 RGB MoCap 的示例屏幕录制，裁出人物面板 680×1200 → 340×600，148 帧 / 4.93 s。
3. **快速模式在 CPU 上可用**：148/148 帧检测到姿势；视频推理 **0.104 s/帧**（p95 0.121 s，总计 17.3 s；模型初始化 0.78 s）；单张图片 **0.166 s**（warm，init 0.83 s）；手部 0.079 s，15 个抽样帧中 10 帧双手、5 帧单手、0 帧无手。宣传“最快 1 秒”对单图/首帧是成立的；对整段视频是约 10 fps 的逐帧推理，不是“1 秒出整段动作”。
4. **管线跑通，质量是“原型/previs 级”**：18 骨 Mixamo 命名源骨架 → `animation-retarget-kit` → KayKit Rogue（41 骨 / 12 mesh / 26 轨 / 4.9333 s）。root XZ 漂移 **1.7 mm**，脚底 **-0.84 cm**（轻微穿地），支撑脚世界滑移 **0.17–0.24 m**（不同采样），髋起伏 **4.8–5.0 cm**，骨长偏差 **~1e-7**，骨骼 scale 偏差 **0**。关键帧精简 **60,680 → 5,346（-91.19%）**，最大通道误差 **0.002**，时长不变。Godot 4.6 headless 600 帧 **0 SCRIPT ERROR / 0 ERROR**，`MOCAP_SMOKE_OK`。
5. **适用/不适用**：适合快速预演、独立/风格化角色、单人物全身动作、离线 CPU；不适合生产级主角、手指细节、脚部锁定、大根运动、多人/遮挡，以及需要商业授权的准确模式（ExMR/GVHMR 非商用；SMPL-X/MANO 受限）。**插件本体与准确模式未测**；所有数字属于“同款 fast-mode 模型 + 本仓库重定向管线”，不是 Pose_AI 的官方指标。
6. **T-012 follow-up 已修可见穿模**：手/前臂/护腕对躯干/头/披风的最大深度 **253.3 / 291.7 mm → 11.8 / 11.8 mm**（全 148 帧；≤12 mm 阈值，角色自带 Walking_A 参考 30 mm）；脚 mesh 最低 **-174.4 mm → +1.0 mm**（0 帧穿地；接触帧 L64/R96）；支撑滑 **0.2315 → 0.1696 m**（HUD 40 采样 0.213 m；仍存在，走步机原地输入）；髋起伏 **5.01→6.35 cm**；root XZ 1.7 mm 不变。修复版 41 骨 / 7 mesh / 4.9333 s；原始 raw 与输入未改。详见 §11。

## 1. 插件摸底与阻塞（摘要）

完整证据、命令、许可见 [`PLUGIN_AVAILABILITY.md`](PLUGIN_AVAILABILITY.md)。

| 项 | 实测/公开信息 |
|---|---|
| 名称 | **Pose_AI**（中文 N 面板“动作捕捉”；演示 .blend `动作捕捉_2026_v2.0_24帧_无素材_16s.blend`） |
| Blender | 演示 **3.3.2**；本机 3.4.1/4.2；插件本体未安装 |
| 快速模式 | Python 3.12 + MediaPipe；`pose_landmarker_*.task` 29 MB、`hand_landmarker.task` 7.5 MB；UP 评论“快速模式，不消耗显存” |
| 准确模式 | `RGBMocap_CN` = 上游 RGB MoCap + ExMR + SAM2 + HaMeR + ViTPose + SMPL-X + MANO + FFmpeg；约 **11 GB 显存**；模型需注册/自行下载 |
| 上游 | `toyxyz/toyxyz_RGBMocap`，代码 MIT，Windows 原生；macOS 仅实验性 Apple Silicon，**Intel Macs are refused by the installer** |
| 获取 | 简介/评论区无链接；三连+私信/进群；评论反馈未发；未登录/未私信/未绕过 |
| 许可 | Pose_AI 自身许可未公开；准确模式 ExMR/GVHMR 非商用、SMPL-X/MANO 不可再分发；快速模式 MediaPipe Apache-2.0 |

## 2. 替代验证方法

```text
上游示例 walking-pad-locomotion.mp4 (2712×1412, 30 fps, 4.93 s)
  └─ ffmpeg crop=680:1200:0:0, scale=340:600 → 148 PNG
       └─ MediaPipe PoseLandmarker Heavy (VIDEO, CPU) + HandLandmarker (抽样)
            └─ pose.json（33 world landmarks / 帧）
                 └─ build_motion.py：canonical 坐标（前 -Y、右 -X、上 +Z）
                    + 3 帧平滑 + 最低脚接地（root bounce 重建）
                      └─ 18 骨 Mixamo 命名源骨架（Damped Track 约束 → bake → GLB）
                           └─ animation-retarget-kit（显式 18 骨 map）→ KayKit Rogue
                                └─ simplify_action.py（逐通道 RDP ε=0.002）
                                     └─ GLB → Godot 4.6 / Blender 3.4.1 验证
```

- **为什么选快速模式**：它是视频插件中唯一不依赖 Windows/注册模型/11 GB 显存的分支；模型文件与视频安装文档一致（名字、大小、来源）。
- **没有照搬插件代码**：Pose_AI 本体不可得；源骨架、接地、重定向、精简均在本仓库实现，使用 `animation-retarget-kit` 与 Godot 4.6。
- **输入许可/限制**：Wikimedia Commons 等 CC0/公有领域视频源在当前网络下请求超时，未能在时限内取得合适单人视频；按规格改用**上游 RGB MoCap 的示例视频**（插件自带示例），仅测试输入，放 `input/`（gitignored），不提交、不再分发。它不是 CC0，商业使用前必须替换为自有/CC0 输入。派生动画仅作技术验证。
- **角色许可**：KayKit Rogue CC0；Rogue 自带武器 mesh 在预览中隐藏，导出 GLB 保留 12 mesh。

## 3. 实测数据

### 3.1 识别速度与跟踪

硬件：Intel HD Graphics 6000 / macOS 12.7.6；MediaPipe 0.10.9，XNNPACK CPU delegate；本机无独立显存，未测显存占用（UP 评论称 fast mode 不消耗显存）。

| 测试 | 模型/模式 | 结果 |
|---|---|---|
| 视频 148 帧 | PoseLandmarker Heavy / VIDEO | init **0.776 s**；推理总计 **15.38 s**；均值 **0.1039 s/帧**（**9.6 fps**）；p95 0.1208 s；总 wall 17.28 s |
| 单张图片 | PoseLandmarker Heavy / IMAGE | init 0.831 s；3 次 warm：0.119 / 0.166 / 0.183 s，中位 **0.166 s**；1 人 |
| 单张手部 | HandLandmarker / IMAGE | init 0.117 s；中位 **0.079 s**；2 只手 |
| 手部抽样 15 帧（每 10 帧） | HandLandmarker / IMAGE | 2 手 10 帧 / 1 手 5 帧 / 0 手 0 帧 |
| 检测覆盖 | PoseLandmarker | **148/148 帧**有 pose；脚踝 visibility 最低 0.48，其余关键点更高 |

“最快 1 秒”对照：单图 init+首次 detect 约 **1.0 s**（0.83+0.17）；视频不是 1 秒出整段，而是约 **0.1 s/帧**。分辨率只有 340×600（从屏幕录制裁出），更高分辨率会更慢。

抖动/遮挡：源 landmark 帧间平均位移（未平滑）约 **腕 2.6 cm、踝 3.6–3.9 cm、鼻 0.9 cm**；管线用 3 帧平滑。没有专门的遮挡场景；本样本 148/148 可见，脚踝 visibility 最低 0.48。未对最终 GLB 做频谱/抖动指标，脚滑与髋起伏是结果级指标。

### 3.2 源动作 / 重定向 / 导出

| 项 | 数值 |
|---|---|
| 源骨架 | 18 骨（Mixamo 命名），148 帧，30 fps，4.9333 s，180 fcurves |
| 目标 | KayKit Rogue 41 骨 / 12 mesh / 1 skin |
| 映射 | 18/18 显式 map（`source/map_mediapipe_rogue.json`）；目标不存在的 wrist/IK 辅助骨保持 rest |
| 动画 | 1 条 `Animation`，**4.9333 s / 26 Godot 轨**；根骨 `hips` |
| root XZ 漂移 | raw **0.0017 m**；simplified 0.0003 m |
| 脚底最低（Godot 骨 head） | raw **-0.0084 m**；simplified -0.0090 m（约 -0.8~-0.9 cm，轻度穿地） |
| 支撑脚世界滑移 | raw **0.2315 m**（90 采样；HUD 40 采样 0.218 m；600 帧运行 0.1983 m）；simplified 0.2360 m；原地跑步机输入，非脚锁定方案 |
| 髋部 Y 起伏 | raw **0.0501 m**；simplified 0.0497 m（由最低脚接地重建，插件 fast mode 未必有这一步） |
| 循环 seam（hips） | **0.000°**；只测 hips，不代表全身可无缝循环；这是 4.93 s take |
| 骨长偏差 / scale | Blender inspect **1.1e-7 / 1.7e-7**；Godot bone scale dev **0.000000** |
| GLB | raw 644 KB / simplified **413 KB**（-36%）；41 骨 / 12 mesh；6160/6166 verts（导出器拆分差异） |
| FBX（可选） | **857 KB**；41 骨 / 12 mesh / 5901 verts；Blender action `Rig\|Scene` frames **2–149 @30fps**（约 4.9 s）；Godot 4.6 直接导入 `Scene` **4.9000 s / 24 轨** |

源动作侧（canonical，接地/平滑后）：髋部 XZ 范围 **1.7 mm**、髋起伏 **5.06 cm**、左右步幅 **0.559 / 0.538 m**、源支撑滑 **0.304 / 0.394 m**。目标支撑滑低于源，是 chibi 腿长 + 18 骨旋转重定向的结果，不是“脚锁定成功”。

### 3.3 关键帧精简

`simplify_action.py` 对每条 fcurve 做逐通道 RDP（ε=0.002，保留首尾，线性插值）：

```text
SIMPLIFY_REPORT {"frames":[1,148],"orig_keys":60680,"new_keys":5346,
 "reduction_pct":91.19,"max_channel_error":0.0019989,
 "worst_channel":"pose.bones[\"hand.r\"].rotation_quaternion[1]"}
```

- Blender action：**-91.19% 关键帧**；时长仍 **4.9333 s**；脚底/滑移/髋起伏变化在 0.5 cm 内。
- 导出 GLB：**659,456 → 422,432 B（-36%）**；141→123 条动画通道；Godot 轨数 **26→24**（2 条恒定/冗余通道被优化掉）。
- 注意：Blender glTF exporter 默认会**逐帧采样**，会把精简后的 action 又采样回 148 帧（第一次简化输出与 raw 几乎同大小）。本脚本显式 `export_force_sampling=False` + `export_optimize_animation_size=True`；即便这样，导出器仍会对“各通道关键帧数不一致”的轨道做烘焙（日志：`Baking animation because the number of keyframes is not equal for all channel tracks`），所以最终不是每条通道都达到 91% 精简。报告以 Blender action 的 key 数和导出 GLB 体积/轨数分别说明。
- 这是本仓库的本地实现，不是 Pose_AI 的“精简动画”按钮的精确算法。

### 3.4 Blender / Godot 验证

Blender 3.4.1（30 fps 重新导入，`scripts/inspect_blender.py`）：

```text
BLENDER_INSPECT {"bones":41,"meshes":12,"vertices":6160,"action":"Animation_Rig",
 "frames":[1,148],"fps":30,"seconds":4.9,"max_bone_length_deviation":1.1e-07}
```

> 注：`animation-retarget-kit` 的 validator 默认 24 fps，会显示 `frames:[0,118]`（4.93 s × 24）；这是导入 fps 造成的显示值，不是动画变短。以 30 fps inspect 与 Godot 的 4.9333 s 为准。

Godot 4.6（`godot/tools/smoke.gd`）：

```text
SMOKE_FILE raw bones=41 meshes=12 clip=Animation len=4.9333 tracks=26 root_xz=0.0017
SMOKE_FOOT raw min_foot_y=-0.0084 longest=11 stance_slide=0.2315 hip_y_range=0.0501 scale_dev=0.000000 loop_seam=0.000deg
SMOKE_FILE simplified bones=41 meshes=12 clip=Animation len=4.9333 tracks=24 root_xz=0.0003
SMOKE_FOOT simplified min_foot_y=-0.0090 longest=11 stance_slide=0.2360 hip_y_range=0.0497 scale_dev=0.000000 loop_seam=0.000deg
MOCAP_SMOKE_OK
```

- FBX（可选）：Blender 3.4.1 导入 41 骨 / 12 mesh / 5901 verts，action `Rig|Scene` frames 2–149；Godot 4.6 直接导入 41 骨 / 12 mesh，动画 `Scene` 4.9000 s / 24 轨（比 GLB 少 1 帧，导入器差异）。主预览仍用 GLB。
- Blender 3.4.1 EEVEE 回放：导入 `Rogue_MediaPipe_walk_raw.glb`，渲染 frame 1/37/74/111/148（640×640，5 相位），见 `screenshots/blender_playback_phases.png`；动作连续、无爆炸/拉伸。Blender 渲染中武器 mesh 未隐藏。
- `godot --headless --path blender-mocap-plugin-test/godot --quit-after 600`：**0 SCRIPT ERROR / 0 ERROR**；最后一次打印 `PREVIEW_DATA min_foot_y=-0.0082 contact=24 stance_slide=0.1983 longest=6 hip_y_range=0.0468 scale_dev=0.000000`、`PREVIEW_BOOT ... foot_min=-0.0082 slide=0.1983`（40 采样；与 smoke 的 90 采样差异来自采样相位）。
- 真实 GPU（Movie Maker 1280×720 / 30 fps）：300 帧 10 s，录制约 14 s（71% 实时），CPU render 2.08 ms/帧，HUD 约 25 FPS。这不是游戏性能基准，只说明本机可录。
- 媒体：`recordings/godot_mediapipe_walk.mp4`（10 s）、`godot_mediapipe_walk_bones.mp4`（5 s 骨骼）、`godot_mediapipe_walk_small.gif`、`source_skeleton.gif`；截图见 `screenshots/`。

### 3.5 质量观察（关键）

- **可辨认的走路**：左脚/右脚交替、手臂随身摆动、髋部有约 5 cm 起伏；Godot 中 4.93 s 连续播放无爆炸/拉伸/骨骼缩放。
- **但明显前倾/屈膝**：源人物在走步机上本身前倾；目标 Rogue 是 chibi 比例（腿短、头大），18 骨旋转重定向放大了“蹲”的观感。与 Action Forge 的 17 骨 Rogue 结果同类（见下）。
- **脚部**：最低 -0.84 cm（骨 head；mesh 可能再多一点）；支撑滑 0.17–0.24 m（不同采样）是走步机原地输入的必然结果，不能当作“脚滑已修好”。没有 foot IK/contact correction。
- **手部**：MediaPipe 手部检测可用（10/15 帧双手），但 Rogue 没有手指骨；本管线把手骨沿前臂方向（近似握拳预设），未验证手指。Pose_AI 的“握拳预设兜底”在实际插件里是合理的。
- **朝向**：canonical 映射把人物前向对齐到 Blender -Y（Godot +Z）；Godot 相机预设 1/2 在 +Z 侧能看到正面。没有做逐 clip yaw 修复；本样本 yaw 变化仅 -18.5°~13.1°，未测大转身。
- **视觉迭代**：第一版把头骨瞄准鼻子，导致头低下 ~60°；改为瞄准头顶（skull up）后恢复正常。这是本仓库的坑，已记录在 `docs/迭代记录.md`。

## 4. 与 Mixamo / Action Forge 基线对比

> Mixamo/Action Forge 列来自 `docs/MIXAMO_RETARGET.md` 与 `action-forge-test/docs/action-forge-test.md`；本次未登录 Adobe/Mixamo，未重跑 Action Forge。

| 维度 | Mixamo + Godot `RetargetModifier3D` | Action Forge（T-009/T-013） | 本次（MediaPipe fast-mode 复现） |
|---|---|---|---|
| 输入 | 现成 Mixamo 动画 | 现成 clip/GLB 上传 | **视频 → 姿态**（MediaPipe） |
| 账号/上传 | Adobe ID；上传 | 免账号、本地读 | 无账号；本地 |
| 重定向 | rotation-only 运行时；Michelle 正常/Xbot 倾斜 | 自动 17 骨；Rogue 屈膝/前倾 | 显式 18 骨；Rogue 屈膝/前倾 |
| 片段 | 1.03 s / 1.33 s | 1.03 / 1.33 s | **4.9333 s**（148 帧） |
| root XZ | 未测 | 0.0197 m / 0.3371 m | **0.0017 m** |
| 脚底 | 未测 | +1.1~3.9 cm / +3.03 cm | **-0.84 cm** |
| 支撑滑 | 未测 | 0.417 / 0.663 m | **0.17–0.24 m**（不同采样；走步机原地，口径不同） |
| 速度 | 无（现成动画） | UI 分钟级 | **0.104 s/帧 CPU** + Blender ~20 s |
| 主要优势 | 动作库/自动绑定成熟 | 免账号、可编辑、分层 | **任意单人物视频、CPU、无账号** |
| 主要短板 | 账号/大陆限制 | 自动映射 chibi 差、根运动弱 | 准确度/脚部/手指/平台；插件本体不可得 |

**判断**：本次的 fast-mode 复现是“视频前端”的补充，不是 Mixamo/AF 的替代。若你已有 Mixamo 动画，继续用 Mixamo/AF 更快更稳；若你只有一段手机视频、且能接受手工重定向和脚滑，fast mode 可以出预演。Pose_AI 的准确模式（ExMR）理论上质量更好，但本次 **未测**，不能替作者背书。

## 5. 适用 / 不适用

适用：

- 独立游戏/风格化角色的快速预演、blocking、短视频素材；
- 单人物、全身可见、静态/轻移动相机、CPU 离线；
- 需要一个“视频→动作”的起点，再人工修脚/手/朝向；
- 学习/研究/非商用原型（注意模型许可）。

不适用：

- 生产级主角动作、写实角色、精细手指/面部；
- 需要脚锁定、接触修正、大根运动/位移的 locomotion；
- 多人、遮挡、镜头切换、低分辨率/远景人物；
- 商业项目直接使用准确模式（ExMR/GVHMR 非商用；SMPL-X/MANO 受限）；
- 期望“插件本体开箱即用”的交付（本体不可得）。

## 6. 商业与许可

| 组件 | 许可/结论 |
|---|---|
| Pose_AI 插件本体 | **许可未公开**；无法确认商用/再分发；本次未获取 |
| MediaPipe / fast mode | Apache-2.0；模型文件来自 Google（随 MediaPipe 分发）；商用相对友好，仍需保留 notices |
| ExMR / GVHMR / FootMR（准确模式） | 教育/研究/非营利；衍生修改需开源且非商用；**不能默认商用** |
| FlowHMR | 源码 Apache-2.0；模型权重另计 |
| SAM 2 | Apache-2.0 |
| SAM 3D Body / SAM License、HaMeR/ViTPose 等 | 各自模型/权重条款；需逐项核对 |
| SMPL-X / SMPL / MANO | 注册模型；**不可随插件分发**；商业需 Max Planck 许可 |
| 上游 RGB MoCap 代码 | MIT；第三方/模型保留各自许可 |
| 输入示例视频 | 上游仓库示例，仅测试输入，**未提交/未再分发**；派生动画仅技术验证 |
| KayKit Rogue | CC0；见 `CREDITS.md` |

**结论**：快速模式在许可上最可控；准确模式不要用于商业项目，除非你单独取得 ExMR/GVHMR 与 SMPL-X/MANO 的商用授权。不要把“免费分享”当成“可商用开源”。

## 7. 版本限制与坑

1. **插件本体不可得**：Pose_AI 无公开仓库/网盘；评论区私信/群分发；未登录/未绕过。上游 RGB MoCap 是 Windows 原生；macOS 仅 Apple Silicon，Intel 被拒绝。
2. **演示 Blender 3.3.2**；本机用 3.4.1 复现管线；4.2 未测（4.2 EEVEE 在 Intel 上不稳，但插件 UI/推理可能可用——本插件未安装，无法确认）。
3. **MediaPipe 0.10.9** 是最后带 macOS x86_64 轮子的版本之一；本机用 Blender 3.4.1 的 Python 3.10.2 + venv；只装 Tasks 需要的最小依赖，`cv2/matplotlib` 用空 stub（MediaPipe 顶层 import 会触及 drawing 辅助，推理不用）。换新版本/新 macOS 可能没有轮子。
4. **MediaPipe world landmarks 以髋为中心**：原始 hip 几乎不动；本管线用“最低脚接地”重建 root bounce（5 cm）。这是**我们加的**，不是 fast mode 的默认行为；直接照搬可能得到无起伏的滑步。
5. **头骨瞄准**：把 head 骨瞄准 nose 会让头前倾 ~60°；应瞄准 ears+up（skull up）。这是本管线第一版的真实 bug，已修。
6. **glTF 动作命名**：源 GLB 导入 Blender 后 action 名是 `Animation_MediaPipeSource`（不是 `MediaPipeTake`）；retarget 用实际名字/模糊匹配。目标 GLB 在 Blender 里会拆成多个 per-object actions（validator 显示 7 条），Godot 里只有 1 条 `Animation`。
7. **validator 24 fps**：kit validator 默认 24 fps，把 4.93 s 显示成 frames [0,118]；用 30 fps inspect 和 Godot 4.9333 s 为准。
7b. **glTF 默认逐帧采样**：Blender exporter 默认 `export_force_sampling=True`，会把精简 action 重新采样成每帧 148 key，导致“精简”在 GLB 里失效；需显式关闭。即便关闭，通道 key 数不一致时仍会触发烘焙。
8. **Movie Maker + 第 4 盏平行光**：在 GL Compatibility 8-bit 录制里会过曝/压暗；demo 模式不加第 4 盏 front 平行光（与 Action Forge T-013 同类坑）。
9. **HUD 的 `await _measure()`**：不 await 会导致指标行永远为空；已修。
10. **脚滑/穿地**：-0.84 cm 穿地、0.17–0.24 m 支撑滑（不同采样）；没有 foot IK。走步机原地输入本身就会让支撑脚相对世界后滑。
11. **循环**：4.93 s take 的 hips seam 为 0，但全身相位不保证无缝；游戏里需要裁剪/混合。
12. **未测**：Pose_AI 本体 UI/预设/精简按钮、准确模式（ExMR/SAM2/SMPL-X）、多人、遮挡、镜头切换、大根运动、1080p 推理、商业授权、Unity/UE 导出、Blender 4.2 兼容性。

## 8. 复现

### 8.1 一次性环境

```bash
cd blender-mocap-plugin-test
bash scripts/setup_env.sh          # 独立 .venv + MediaPipe 0.10.9 + 两个 .task 模型
bash scripts/download_input.sh     # 上游 RGB MoCap 示例 → input/（gitignored）
```

### 8.2 全流程

```bash
bash scripts/run_pipeline.sh
# 末行 MOCAP_SMOKE_OK；产物 exports/*.glb、source/source_full.glb
```

### 8.3 验证 / 媒体

```bash
bash scripts/validate.sh
godot --headless --path godot --quit-after 600
godot --path godot --resolution 1280x720 --write-movie /tmp/walk.avi \
  --fixed-fps 30 --quit-after 300 -- --demo
ffmpeg -y -i /tmp/walk.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart \
  recordings/godot_mediapipe_walk.mp4
```

### 8.4 单图速度

```bash
.venv/bin/python scripts/bench_image.py \
  --image .work/frames/0037.png \
  --pose-model models/pose_landmarker_heavy.task \
  --hand-model models/hand_landmarker.task
```

## 9. 相对父任务新增了什么

- 新增 **视频 → 动作** 前端：MediaPipe Pose/Hand 的实测速度、148/148 跟踪、手部检测率。
- 新增 **18 骨 Mixamo 源骨架 + 接地 + 显式 map** 到 `animation-retarget-kit`，目标 KayKit Rogue；与既有 Mixamo/AF 基线可直接对比。
- 新增 **RDP 关键帧精简** 的本地实现与误差/体积数据。
- 新增 **Pose_AI 插件可得性/许可/平台阻塞证据**，避免团队把“B 站插件”当成可复现的开源工具。
- 不改现有玩法/路线/工具语义；`godot-garden` 等既有项目未改。

## 10. 媒体

| 文件 | 内容 |
|---|---|
| `recordings/godot_mediapipe_walk.mp4` | 10 s，1280×720，30 fps，Rogue 4.93 s 循环 + 相机环绕；HUD 前 6 s |
| `recordings/godot_mediapipe_walk_small.gif` | 640 宽，12 fps |
| `recordings/godot_mediapipe_walk_bones.mp4` | 5 s，骨骼 X-ray |
| `recordings/source_skeleton.gif` | 148 帧 MediaPipe 2D 骨架可视化（无源视频） |
| `screenshots/godot_hud_1280.png` | HUD：4.933 s / 41 骨 / 12 mesh / 脚底 -0.7 cm / 滑移 0.218 m / 髋 4.8 cm |
| `screenshots/godot_walk_{threequarter,side,front}_1280.png` | 3/4、侧、正视图 |
| `screenshots/godot_walk_phases.png` | 4 相位 |
| `screenshots/godot_bones_1280.png` | 骨骼 + mesh |
| `screenshots/source_skeleton_phases.png` | 输入姿态 4 相位（2D 骨架） |
| `screenshots/plugin_blocker_evidence.png` | 插件可得性/平台/许可阻塞证据（公开文字汇编，不含视频画面） |
| `screenshots/blender_playback_phases.png` | Blender 3.4.1 EEVEE 回放 5 相位（1/37/74/111/148） |

附带 `exports/Rogue_MediaPipe_walk.fbx`（857 KB）与 `godot/tools/inspect_fbx.gd`，用于 Unity/UE/其他引擎的 FBX 路径；Godot 4.6 直接导入已验证（4.9000 s / 24 轨）。

> 参考视频与插件截图只在 `/tmp/mocap_ref`，未复制进仓库；媒体中的骨架可视化由 landmark 数据重绘，不含源视频画面。

## 11. T-20261127-012 穿模修复（follow-up）

> 任务：修 T-004 预览里用户指出的“这个穿模比较厉害”。不改源视频/源骨架/时间轴，保留走路方向和根运动；只做可见穿模清理、导出和证据。修复脚本 `scripts/fix_clipping.py` + `scripts/fix_clipping.sh`，诊断 `scripts/diagnose_clipping.py`。

### 11.1 结论

| 项 | 修复前（raw） | 修复后（fixed） |
|---|---|---|
| 手/前臂/护腕 vs 躯干/头/披风，有穿模帧 | **L 148/148，R 148/148** | L 36/148，R 34/148（>4 mm） |
| 最大穿模深度 | **L 253.3 mm（f111），R 291.7 mm（f131）** | **L 11.8 mm（f11），R 11.8 mm（f24）** |
| 单帧最多穿模顶点 | L 194，R 224 | L 6，R 6 |
| 穿模体积代理（Σ面积×深度，均值/峰值，cm³） | L 11,624 / 29,837，R 9,682 / 44,623 | L 5.3 / 59.5，R 6.7 / 44.7 |
| 手/前臂骨中心到躯干/头/披风的最小净距（8 采样） | **-146.7 mm** | **+123.3 mm** |
| 参考：角色自带 `Walking_A_Rig` 同类手/前臂最大深度 | L 29.6 mm，R 30.4 mm | — |
| 脚 **mesh** 最低点 | **L -174.4 mm，R -159.4 mm** | **L +1.0 mm，R +1.0 mm** |
| 脚 mesh < 0 的帧 | L 148/148，R 145/148 | **L 0，R 0** |
| 脚接触帧（距最低 5 mm 内）/ 最长连续 | L 1 / R 1（穿地时无法接触） | **L 64 / R 96；17 / 29** |
| 脚 hip lift / contact adjust | — | lift **max 65.5 mm / mean 23.8 mm**；接触下压 **max 26.1 mm** |
| 支撑滑（骨 head，Godot smoke 90 采样；HUD 40 采样） | 0.2315 m | **0.1696 m**（HUD 0.213 m；仍存在） |
| 髋起伏 / root XZ | 5.01 cm / 1.7 mm | **6.35 cm** / 1.7 mm（HUD 5.3 cm） |
| 披风/武器 | 披风内部 25.7 mm；5 件武器 127–148 帧、215–288 mm | 披风保留（内部 25.7 mm，隐藏）；武器从 clean locomotion GLB 移除 |
| 资产 | 12 mesh / 644 KB | **7 mesh / 321 KB GLB / 798 KB FBX / 24 Godot 轨**；FBX Godot 直接导入 41 骨 / 7 mesh / 4.9000 s / 24 轨 |

- **可见穿模已消除**：修复后残余 ≤11.8 mm = 角色身高 2.15 m 的 0.55%，且每帧最多 6 个顶点、均位于护腕/手套边缘；1280×720 实际 GPU 渲染无可见穿模。≤12 mm 作为本次验收阈值，低于角色自带走路动画的 30 mm。
- **脚**：旧报告“脚底 -0.84 cm”是 **骨 head** 口径；按 leg mesh 顶点，raw 实际穿地最多 174 mm（两脚分别 148/145 帧低于地面）。修复后 mesh 最低 +1.0 mm、0 帧穿地；接触帧 L 64 / R 96、最长 17 / 29；支撑滑未做脚锁，0.1696 m（HUD 40 采样 0.213 m）仍在（走步机原地输入，见 §11.5）。
- **武器**：源资产把 Knife/Offhand/Knife、1H/2H_Crossbow、Throwable 绑在 `handslot.l/r`（持械绑定），走路时会跟随手进入躯干（215–288 mm）。本次把 5 件道具从 **locomotion clean GLB/FBX** 移除——任务允许“隐藏”，且 Godot 预览原本就隐藏它们；raw 完整 GLB 保留未改。
- **披风**：保留并改为蒙皮到 `chest`（帧 1 误差 0.000 mm），避免再导出时 `matrix_parent_inverse` 丢失导致的 90°/1.39 m 错位；代价是丢掉原 object action 的约 1 cm 独立摆动。
- **不改**：源视频/输入、18 骨源骨架、walk 方向、hip XZ 根运动、角色材质/比例/骨架。
- **Godot 验收**：fixed 600 帧 headless **0 SCRIPT ERROR / 0 ERROR**、exit 0；`MOCAP_SMOKE_OK`。Movie Maker 5 s / 150 帧录制 6–9 s（55–83% realtime），CPU render **2.43–2.46 ms/帧**，HUD 截帧 **FPS 32**（录制环境，不是游戏性能基准）。

### 11.2 根因

1. **chibi 比例 + 角色设计宽度**：Rogue 高 2.15 m，腰带/裙摆处 body mesh x 约 **±0.48 m**，肩关节却在 x **±0.21 m**。MediaPipe 18 骨重定向后腕 x 只有 **0.0–0.33 m**，护腕/手套半径约 0.1 m，于是整段前臂/手套落在躯干内部。KayKit 自带 `Walking_A_Rig` 的腕 |x| ≈ **0.513 m**、手 |x| ≈ 0.55 m——角色本身就需要更宽的 arm corridor；这不是“手部旋转错”，是比例/碰撞问题。
2. **无手指骨 + 手沿前臂握拳**：Rogue 没有 finger 骨，手部只能作为整体跟着前臂；本修复不改骨架，残余手部朝向仍由前臂决定。
3. **脚**：源 foot/toe 的跖屈重定向到更大的 boot，raw foot pitch **50–74° toe-down**；mesh 最低 -174 mm。旧指标只测 `foot.*`/`toes.*` 骨 head，低估了 boot mesh。
4. **披风**：源 cape 是 bone-parent 到 `chest` 的刚性 mesh，自带 object action。Blender glTF 再导出不往返 `matrix_parent_inverse`：第一次重导出后披风旋转 ~90°、世界位置偏 1.388 m（实测 `FIX_CAPE_REBIND error_mm=1388.373`），必须转成 skinned mesh 才能稳定导出。
5. **武器**：5 件道具在源 GLB 里是 `BoneAttachment3D → handslot.l/r` 的持械绑定，不是腰带挂件；走路不持械时它们跟着手进入躯干。预览原本隐藏，但 raw GLB 本身仍会穿。

### 11.3 方法

**A. 碰撞感知手臂 IK（`scripts/fix_clipping.py`）**

- 保留源动作的腕 **y/z**（前后/上下摆动）和全部身体/腿/头关键帧；仅把腕的横向 |x| clamp 到 **0.55 m**（角色自带 Walking_A 0.513 + 手套余量）。
- 解析 2-bone IK（upperarm/lowerarm）解到新腕目标，肘极向 `(0.35·side, -0.9, +0.15)`（略外/前/上），保留原肘弯曲平面；每帧写回 upperarm/lowerarm 四元数，LINEAR。
- 残余 mesh push：手 `hand.*` + 距腕 0.16 m 内的 `lowerarm.*` 顶点对 body/head/cape 做 3-ray 多数“内部”测试；只有穿入 >12 mm 才继续外推（本次 0.55 corridor 下未触发，输出纯 clamp+IK，避免逐帧抖动）。
- 手/护腕未缩放、未加手指骨；手部朝向仍随前臂。

**B. 脚接地 clamp**

- 逐帧把 foot/toes 的**向下 pitch** 限制到 **20°**（源 50–74°），旋转轴为世界 X、枢轴为踝/趾关节。
- 评估 `Rogue_LegLeft/Right` 的 evaluated mesh 最低 z，把残留穿地量加到 **hips location.z**（1 帧膨胀 + 3 帧均值，且不低于原始需求）；本次 lift **max 65.5 mm / mean 23.8 mm**。
- 再做一次 **contact clamp**：逐帧下压 hips，使最低 boot mesh 距 Z=0 约 **1 mm**（本次下压 **0–26.1 mm**），避免膨胀/平滑造成悬空；最终接触帧 L64/R96、最长 17/29。
- **不动 hips X/Y、root 方向**；因此支撑滑没有被脚锁消除，只是从 0.2315 降到 0.1696 m（90 采样；HUD 40 采样 0.213 m，采样/姿态变化）。

**C. 披风**

- 取帧 1 的 evaluated cape 世界顶点，按 `P_pose·P_rest⁻¹` 逆变换写回 rest 空间，权重 1.0 到 `chest`，加 Armature modifier，删除原 object action/bone parent。
- 帧 1 重绑误差 **0.000 mm**；之后披风跟随 chest（包括 hips lift），不再出现重导出 90° 错位。原始刚性摆动约 1 cm 被丢弃。

**D. 武器 / 导出**

- clean GLB/FBX 不包含 5 件武器；raw GLB 保持 12 mesh 原样。clean 版 41 骨/7 mesh/4.9333 s；Godot 默认加载 clean。
- `scripts/fix_clipping.sh` 一条命令完成 fix → 复制到 Godot → import → smoke。

**E. 量化（`scripts/diagnose_clipping.py`）**

- 可见手区 = `hand.*` + 腕 0.16 m 内 `lowerarm.*` 的 mesh 顶点；3-ray 多数投票判内外（body 有 neck/armhole 小开口，单 ray 会误判），最近面距离为深度。
- 体积代理 = Σ(顶点面积 × 深度)，**不是 watertight boolean volume**，只用于前后相对比较；单位 cm³。
- 骨净距 = wrist/hand 骨中心到 body/head/cape 的最小 signed distance（内部为负）；脚 = evaluated leg mesh 最低顶点；8 个采样帧 1/19/37/56/74/92/111/130 + 全 148 帧汇总。

### 11.4 8 帧逐帧对比

格式：深度 mm / 内部顶点数 / 骨净距 mm；负净距=骨头在体内。脚为 mesh 最低 z（mm）。

| 帧 | Before L | Before R | After L | After R | 脚 Before L/R | 脚 After L/R |
|---|---|---|---|---|---|---|
| 1 | 162.2 / 85 / -37.4 | 182.4 / 129 / -32.2 | 7.8 / 2 / 140.3 | 5.7 / 2 / 144.4 | -100.6 / -107.8 | 52.4 / 1.0 |
| 19 | 195.9 / 138 / -83.3 | 240.7 / 180 / -81.3 | 0.0 / 0 / 180.5 | 11.0 / 4 / 143.9 | -33.5 / -20.3 | 1.6 / 56.7 |
| 37 | 127.8 / 78 / -2.3 | 140.2 / 94 / +5.4 | 6.8 / 2 / 123.3 | 0.0 / 0 / 167.2 | -98.0 / -105.1 | 43.5 / 1.0 |
| 56 | 222.9 / 159 / -83.7 | 168.8 / 118 / -25.4 | 0.0 / 0 / 219.0 | 0.0 / 0 / 159.0 | -48.1 / -20.9 | 25.0 / 1.0 |
| 74 | 106.4 / 80 / -17.5 | 69.6 / 29 / +124.1 | 0.0 / 0 / 225.2 | 0.0 / 0 / 214.8 | -41.8 / -50.1 | 22.3 / 1.3 |
| 92 | 174.7 / 131 / -77.4 | 98.1 / 58 / +15.4 | 0.0 / 0 / 159.6 | 0.0 / 0 / 180.8 | -73.4 / -5.5 | 51.1 / 1.0 |
| 111 | 253.3 / 193 / -120.3 | 90.6 / 54 / +62.7 | 0.0 / 0 / 197.5 | 0.0 / 0 / 224.2 | -59.8 / -66.0 | 1.0 / 15.0 |
| 130 | 174.9 / 148 / -37.1 | 291.2 / 220 / -146.7 | 0.0 / 0 / 213.5 | 7.5 / 4 / 141.5 | -86.3 / -45.5 | 86.6 / 1.0 |

- 全帧最坏：Before L 253.3 mm (f111) / R 291.7 mm (f131)；After L 11.8 mm (f11) / R 11.8 mm (f24)。After 的 36/34 帧仍有 1–6 个顶点 >4 mm，均 ≤11.8 mm。
- 脚：Before 两脚分别 148/145 帧 <0；After 0 帧 <0；接触帧（距最低点 5 mm 内）**L 64 / R 96，最长连续 17 / 29 帧**。修复后接触段明显变长，但支撑滑仍 0.1696 m（HUD 0.213 m）。

### 11.5 限制与未做

- **残余 11.8 mm**：不是零穿模；在 2.15 m 角色上不可见（1280×720 实测），但若放大 4×/特写仍可能在手套边缘看到极浅交叠。
- **手臂姿态变宽**：为了避开宽躯干，手臂被外推到接近角色自带 Walking_A 的宽度，视觉比 raw 更“张臂”；保留了源前后摆动，但没有手指/手腕二次修型。
- **支撑滑仍 0.1696 m（HUD 0.213 m）**：没有脚锁/contact IK，没有改根运动；这是走步机原地输入 + chibi 短腿的已知限制。若要生产级，需要 stance 脚锁 + root motion 策略。
- **脚 roll 被压平**：foot/toe 向下 pitch 限制 20°，丢掉一部分 toe-off/heel-strike 细节；hip lift 最高 65.5 mm（均值 23.8 mm），接触下压最多 26.1 mm，髋起伏 6.35 cm（HUD 5.3 cm）。
- **披风**：独立约 1 cm 摆动被去掉；披风-头内部重叠 25.7 mm（领口/头发内部，渲染不可见）仍在。
- **武器**：clean 版不含 5 件道具；如需展示持械，需要另做手部持械动作或把道具重绑到腰带/背部（当前 raw 保留完整 12 mesh）。
- **mesh 数变化**：12 → 7；依赖 12 mesh 的脚本/计数需更新（`smoke.gd` 已按 fixed=7 处理）。
- **HUD 口径**：Godot HUD 的 `foot bone min` 修复后约 **+9.3 cm**（40 采样；smoke 90 采样 +8.4 cm），这不是脚穿地；它测的是 **foot 骨 head**。真实 boot mesh 最低是 **+0.1 cm**（Blender 诊断），HUD 已加注 `mesh foot +0.1 cm`。
- **预览对比**：Godot 的 `--flat` / `--phase` 用于静止截图（`_measure()` 后会重新 seek）；两段独立录制的 Godot Movie Maker 前后片段受加载/measure 时序影响，相位和光照不齐，因此**最终 before/after 视频用 8 相位 Blender Workbench 同帧并排**，Godot 侧只交付 HUD/脚部静止证据。
- **真实复现**：修复/诊断均在本机 Blender 3.4.1 headless + Godot 4.6 实跑；不是 Pose_AI 插件本体，也没有改源视频/输入。

### 11.6 复现

```bash
cd blender-mocap-plugin-test

# 1) 修复 + 导出 + Godot import + smoke（末行 MOCAP_SMOKE_OK）
bash scripts/fix_clipping.sh

# 2) 诊断（全 148 帧 + 8 采样；输出 JSON）
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -noaudio \
  --python scripts/diagnose_clipping.py -- \
  --glb exports/Rogue_MediaPipe_walk_raw.glb --out .work/clipdiag/before_diag.json
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -noaudio \
  --python scripts/diagnose_clipping.py -- \
  --glb exports/Rogue_MediaPipe_walk_fixed.glb --out .work/clipdiag/after_diag.json

# 3) Godot 前后对比（同机位/同 flat 光照；150 帧 = 5 s）
godot --path godot --resolution 1280x720 --write-movie /abs/before.avi \
  --fixed-fps 30 --quit-after 150 -- \
  --nohud --still --flat --preset=2 --glb=res://assets/Rogue_MediaPipe_walk.glb
godot --path godot --resolution 1280x720 --write-movie /abs/after.avi \
  --fixed-fps 30 --quit-after 150 -- --nohud --still --flat --preset=2
# ffmpeg hstack + labels → /tmp/godot_compare.mp4（可选诊断；验收视频是 8 相位 Workbench slideshow）

# 4) 验收
godot --headless --path godot -s tools/smoke.gd
# SMOKE_FILE fixed bones=41 meshes=7 clip=Animation len=4.9333 tracks=24 root_xz=0.0017
# SMOKE_FOOT fixed min_foot_y=0.0840 longest=12 stance_slide=0.1696 hip_y_range=0.0635 scale_dev=0.000000 loop_seam=0.000deg
# MOCAP_SMOKE_OK
```

### 11.7 新增媒体

| 文件 | 内容 |
|---|---|
| `screenshots/clip_before_after_phases.png` | 8 帧（1/19/37/56/74/92/111/130）× before/after，Part-color Workbench，标出可见手区口径与最大深度 |
| `screenshots/clip_before_after_feet.png` | 脚部特写 before/after（注释 mesh 最低点/支撑滑）；`clip_before_feet_godot_1280.png` / `clip_after_feet_godot_1280.png` 为单张 |
| `screenshots/clip_after_hud_1280.png` | 修复版 HUD：7 mesh / foot 骨 min +9.3 cm（HUD 口径）/ mesh +0.1 cm / arm clip 11.8 mm / stance slide 0.213 m / hip 5.3 cm / FPS 32（录制环境） |
| `recordings/clip_before_after_phases.mp4` | 1200×726，8 s，8 相位 before/after 并排 + 标签（Blender Workbench，同光照/同帧） |
| `recordings/clip_before_after_phases.gif` | 960 宽，10 fps，8 s |
| `exports/Rogue_MediaPipe_walk_fixed.glb` / `.fbx` | 修复版 clean（7 mesh / 41 骨 / 4.9333 s / 24 Godot 轨） |
| `.work/clipdiag/before_diag.json` / `after_diag.json` | 全帧/8 帧量化原始数据（`.work` 默认不提交，可在本机复跑） |

> 修复版与原报告的其他数字口径：原 §3 的“脚底 -0.84 cm”是骨 head；本节的脚数据是 evaluated mesh 顶点。两者不要混用。
