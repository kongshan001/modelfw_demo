# Godot 4.6 预览

## 运行

```bash
# 首次导入
godot --headless --path . --import

# 交互预览（真实 GPU）
godot --path . --resolution 1280x720

# 无头验收（末行 MOCAP_SMOKE_OK）
godot --headless --path . -s tools/smoke.gd

# 10 s 录制 → MP4
godot --path . --resolution 1280x720 --write-movie /tmp/walk.avi \
  --fixed-fps 30 --quit-after 300 -- --demo
ffmpeg -y -i /tmp/walk.avi -c:v libx264 -crf 20 -pix_fmt yuv420p \
  -movflags +faststart ../recordings/godot_mediapipe_walk.mp4
```

## 操作

- 鼠标拖拽环绕，滚轮缩放；`1–4` 机位，`C` 自动环绕，`Space` 暂停，`B` 骨骼 X-ray，`H` HUD，`R` 回到起点。
- `--demo`：自动环绕、6 s 后隐藏 HUD（会去掉第 4 盏 front 平行光）。
- `--glb=res://assets/Rogue_MediaPipe_walk.glb`：切回 raw（12 mesh，武器在预览中隐藏）。
- `--glb=res://assets/Rogue_MediaPipe_walk_simplified.glb`：RDP 精简版。
- `--still --preset=N --phase=S`：静止帧/相位（`_measure()` 后会重新 seek，保证截图相位）。
- `--flat`：关掉 key 阴影并提高 ambient，用于 before/after 同光照对比；正常预览不要用。
- `--nohud`：隐藏 HUD 录制。
- `--shot=/abs/path`：截 PNG；`--bench` 5 s FPS；`--bones` 骨骼 X-ray 启动。
- HUD：clip 时长、骨骼/mesh 数、foot 骨 head 最低、支撑滑移、髋起伏、FPS；T-012 修复版额外显示 `mesh foot +0.1 cm · visible arm clip max 11.8 mm · props hidden`（写死的验收摘要）。

## 资产

- `assets/Rogue_MediaPipe_walk_fixed.glb`：**默认**，T-012 修复版（41 骨 / 7 mesh / 4.9333 s / 24 轨；手/脚穿模清理；披风蒙皮到 chest；不含 5 件 handslot 武器）。
- `assets/Rogue_MediaPipe_walk.glb`：raw（12 mesh，原 T-004；保留作 before）。
- `assets/Rogue_MediaPipe_walk_simplified.glb`：RDP 精简版（未做 T-012 清理）。
- `assets/Rogue_MediaPipe_walk_fixed.fbx`：修复版 FBX（Godot 直接导入 **41 骨 / 7 mesh / 4.9000 s / 24 轨**；`tools/inspect_fbx.gd` 可复核）。
- `assets/Rogue_MediaPipe_walk.fbx`：原 FBX 变体。
- 角色 KayKit Rogue 为 CC0；动画为测试数据，见 `../CREDITS.md`。

## 注意

- Project 使用 GL Compatibility；Intel HD 6000 的 Movie Maker 不要加第 4 盏平行光（会压暗/裁切 8-bit 录制）。
- 无头 600 帧：`godot --headless --path . --quit-after 600`（0 SCRIPT ERROR / 0 ERROR）。
- `smoke.gd` 会同时测 raw（12 mesh）/ simplified（12）/ fixed（7）；T-012 的固定版末行 `MOCAP_SMOKE_OK`。
- 前后对比录制（5 s，`--flat` 同光照）与 hstack/ffmpeg 命令见 `../docs/OPERATIONS.md` 的“T-012 穿模修复”。
