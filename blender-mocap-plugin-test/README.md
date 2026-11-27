# Blender Mocap Plugin Test · Pose_AI 能力拆解 + MediaPipe fast-mode 复现

> 2026-11-27 · T-20261127-004 · Godot 4.6 / Blender 3.4.1 / macOS 12.7.6 Intel HD 6000

B 站《自制Blender动捕插件，免费分享》里的插件是 **Pose_AI**（中文 Blender 3.3.2 插件）。它没有公开下载（三连+私信/群，评论反馈未发），准确模式依赖 Windows RGB MoCap + ExMR/SAM2/SMPL-X（~11 GB 显存、模型需注册，ExMR/GVHMR 非商用），macOS 仅 Apple Silicon、Intel 被 installer 拒绝。**本机无法跑插件本体**；详见 [docs/PLUGIN_AVAILABILITY.md](docs/PLUGIN_AVAILABILITY.md)。

本仓库做的是规格允许的替代验证：用 **Pose_AI 快速模式同款 MediaPipe 模型**（PoseLandmarker Heavy + HandLandmarker）处理上游 RGB MoCap 示例视频，生成 18 骨源骨架，经 `animation-retarget-kit` 重定向到 **KayKit Rogue（CC0）**，导出 GLB，在 **Godot 4.6** 预览，并做 RDP 关键帧精简。

## 结论（TL;DR）

- 148/148 帧检测；CPU **0.104 s/帧**（约 9.6 fps），单图 **0.166 s**（init 0.83 s），手 **0.079 s**。
- Rogue GLB：41 骨 / 12 mesh / **26 轨** / **4.9333 s**（精简版 24 轨）；root XZ **1.7 mm**；脚底 **-0.84 cm**；支撑滑 **0.17–0.24 m**（不同采样）；髋起伏 **4.8–5.0 cm**；骨长偏差 ~1e-7。
- 关键帧 **60,680 → 5,346（-91.19%）**，最大通道误差 0.002；导出 GLB **644 KB → 413 KB（-36%）**，Godot 轨 26→24；另出 FBX 857 KB（Godot 导入 4.9000 s / 24 轨）。
- Godot 600 帧 headless **0 SCRIPT ERROR / 0 ERROR**；`MOCAP_SMOKE_OK`。
- 质量：可辨认的走路，但 chibi 比例下前倾/屈膝、无 foot IK、手指未映射 → **原型/previs 级，不是生产级**。
- 数字属于“同款 fast-mode 模型 + 本仓库重定向管线”，不是 Pose_AI 本体指标。

## 快速开始

```bash
cd blender-mocap-plugin-test
bash scripts/setup_env.sh       # 独立 .venv + MediaPipe + 两个 .task（约 38 MB）
bash scripts/download_input.sh  # 上游示例 → input/（gitignored）
bash scripts/run_pipeline.sh    # 末行 MOCAP_SMOKE_OK
# 其他视频：CROP / SCALE 可覆盖（示例是上游屏幕录制的左画面 680×1200）
# CROP=iw:ih:0:0 SCALE=iw:-2 bash scripts/run_pipeline.sh
bash scripts/validate.sh

godot --headless --path godot --quit-after 600
godot --path godot --resolution 1280x720 --write-movie /tmp/walk.avi \
  --fixed-fps 30 --quit-after 300 -- --demo
```

## 目录

```text
blender-mocap-plugin-test/
├─ docs/
│  ├─ blender-mocap-plugin-test.md   主报告（结论/数据/对比/许可/坑/复现）
│  ├─ PLUGIN_AVAILABILITY.md         插件不可得 + 平台/许可阻塞证据
│  └─ 迭代记录.md                     07:00–09:25 实验与修正
├─ scripts/                          setup / download / extract / build / retarget / simplify / validate / bench
├─ source/                           18 骨源 GLB + 骨骼 map + 姿态/动作 JSON（衍生测试数据）
├─ exports/                          Rogue_MediaPipe_walk_raw.glb / _simplified.glb / .fbx
├─ godot/                            Godot 4.6 预览 + smoke
├─ screenshots/                       HUD/3-4/侧/正/相位/骨骼/骨架
├─ recordings/                       10 s MP4、GIF、骨骼 MP4、骨架 GIF
├─ models/                           MediaPipe .task（gitignored）
├─ input/                            上游示例视频（gitignored）
└─ CREDITS.md                        来源/许可
```

## 媒体

- `recordings/godot_mediapipe_walk.mp4`（10 s / 1280×720 / 30 fps）
- `recordings/godot_mediapipe_walk_bones.mp4`（5 s 骨骼）
- `recordings/godot_mediapipe_walk_small.gif`
- `screenshots/godot_hud_1280.png`、`godot_walk_*.png`、`godot_bones_1280.png`、`source_skeleton_phases.png`、`plugin_blocker_evidence.png`、`blender_playback_phases.png`

## 许可

插件本体许可未公开；准确模式 ExMR/GVHMR 非商用、SMPL-X/MANO 受限；快速模式 MediaPipe Apache-2.0。输入示例仅测试、未再分发；导出动画仅技术验证。详见 [CREDITS.md](CREDITS.md)。
