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
- `--demo`：自动环绕、6 s 后隐藏 HUD。
- `--glb=res://assets/Rogue_MediaPipe_walk_simplified.glb`：切到精简版。
- HUD：clip 时长、骨骼/mesh 数、脚底最低、支撑滑移、髋起伏、FPS。
- 武器 mesh（Knife/Crossbow/Throwable）在预览中隐藏；GLB 仍保留 12 mesh。

## 资产

- `assets/Rogue_MediaPipe_walk.glb`：raw（默认）。
- `assets/Rogue_MediaPipe_walk_simplified.glb`：RDP 精简版。
- `assets/Rogue_MediaPipe_walk.fbx`：FBX 变体（Godot 直接导入 4.9000 s / 24 轨）；`tools/inspect_fbx.gd` 可复核。
- 角色 KayKit Rogue 为 CC0；动画为测试数据，见 `../CREDITS.md`。

## 注意

- Project 使用 GL Compatibility；Intel HD 6000 的 Movie Maker 不要加第 4 盏平行光（会压暗/裁切 8-bit 录制）。
- 无头 600 帧：`godot --headless --path . --quit-after 600`（0 SCRIPT ERROR / 0 ERROR）。
