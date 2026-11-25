#!/usr/bin/env bash
# 重新生成 docs/rain_puddles.mp4 与 docs/rain_puddles.gif。
# 30fps 固定步长抓 300 帧（10s），HUD 保留、实时 FPS 统计隐藏。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --fixed-fps 30 -s tools/capture_rain_puddles.gd

ffmpeg -y -framerate 30 -i /tmp/rain_puddles_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/rain_puddles.mp4

ffmpeg -y -framerate 30 -i /tmp/rain_puddles_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=96[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/rain_puddles.gif

ls -lh docs/rain_puddles.mp4 docs/rain_puddles.gif
