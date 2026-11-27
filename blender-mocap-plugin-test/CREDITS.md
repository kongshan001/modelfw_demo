# CREDITS / 来源与许可

> 本目录只做工具评测与替代验证。未提交插件源码、模型权重或源视频。

## 参考与上游

| 对象 | 来源 | 许可/使用 |
|---|---|---|
| 参考视频 | B 站 [BV18fWM6MEMg](https://www.bilibili.com/video/BV18fWM6MEMg)，UP 黑黑猴blender，2026-11-10，582.72 s | 仅研究/分析；下载到 `/tmp/mocap_ref`，**未复制视频/素材进仓库** |
| 视频插件 | **Pose_AI**（中文 Blender 3.3.2 插件；安装目录 `Blender_Addons/Pose_AI`） | **未公开下载**；许可未公开；未获取、未运行 |
| 上游应用 | [toyxyz/toyxyz_RGBMocap](https://github.com/toyxyz/toyxyz_RGBMocap) | 代码根许可 **MIT**；第三方/模型保留各自许可；本次只读代码/文档，未运行二进制 |
| 上游示例输入 | `docs/samples/walking-pad-locomotion.mp4`（2712×1412 / 30 fps / 4.933 s） | 仅测试输入，`input/`（gitignored），**未再分发**；派生动画仅技术验证 |
| 模型/库 | MediaPipe 0.10.9 + `pose_landmarker_heavy.task` / `hand_landmarker.task` | MediaPipe **Apache-2.0**；模型文件由 Google 分发；`models/`（gitignored），不入库 |
| 重定向工具 | 本仓库 `animation-retarget-kit/`（Blender headless） | 按仓库既有 `LICENSES/`；本次未修改 |
| 角色 | KayKit Rogue，`godot-garden/assets/models/kaykit/Rogue.glb` | **CC0**（KayKit）；12 mesh 含武器，预览中隐藏武器；T-012 clean 版移除 5 件 handslot 武器 → 7 mesh |
| 引擎 | Godot 4.6 stable / Blender 3.4.1 | MIT / GPL；仅作为工具 |
| 其他 | ffmpeg、yt-dlp、Python 3.10/3.13 | 各自许可；仅作为工具 |

## 准确模式的第三方条款（来自上游 `THIRD_PARTY_NOTICES.md`，未运行）

- **ExMR / GVHMR / FootMR**：教育、研究、非营利；衍生修改需开源且非商用。
- **FlowHMR**：源码 Apache-2.0；支持模型/权重另计。
- **SAM 2**：Apache-2.0；**SAM 3D Body / SAM**：SAM License；权重/MHR 另计。
- **SMPL / SMPL-X / SMPL-H / MANO**：注册模型，限制再分发；商业使用需 Max Planck 许可。
- **HaMeR / ViTPose** 等：源码 MIT/Apache-2.0 不等，权重/检查点另计。
- Pose_AI 插件自身的代码许可**未公开**；不要把“免费分享”当作开源/可商用。

## 本目录产物

- 脚本/文档/Godot 预览：本任务原创，随仓库既有规则提供；不提供任何担保。
- `exports/Rogue_MediaPipe_walk_{raw,simplified}.glb`、`exports/Rogue_MediaPipe_walk.fbx`、`source/*.glb/json`：基于上游示例输入 + MediaPipe + 本仓库管线生成的**测试数据**；商业使用前请自行确认输入素材与模型许可。
- `exports/Rogue_MediaPipe_walk_fixed.glb` / `.fbx`（T-012）：同一 CC0 角色的 clean locomotion 变体，41 骨 / 7 mesh；移除 5 件 handslot 武器；动画为衍生测试数据，不改变角色许可。
- `recordings/`、`screenshots/`：本任务实测/重绘；不含源视频画面（`source_skeleton.gif` 为 landmark 2D 重绘）。`plugin_blocker_evidence.png` 由公开页面/文档文字汇编，不含视频画面；`blender_playback_phases.png` 为本仓库 GLB 的 Blender EEVEE 渲染。
