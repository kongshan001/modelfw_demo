#!/usr/bin/env bash
# 重新生成 docs/sakura_sunlight.mp4 与 docs/sakura_sunlight.gif。
# 30fps 固定步长抓 300 帧（10s），UI 保留、实时 FPS 隐藏。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --fixed-fps 30 -s tools/capture_sakura_sunlight.gd

ffmpeg -y -framerate 30 -i /tmp/sakura_sunlight_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/sakura_sunlight.mp4

ffmpeg -y -framerate 30 -i /tmp/sakura_sunlight_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=800:-1:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/sakura_sunlight.gif

ls -lh docs/sakura_sunlight.mp4 docs/sakura_sunlight.gif
