#!/usr/bin/env bash
# 重新生成 docs/hd2d_demo.mp4 与 docs/hd2d_demo.gif（10s / 30fps / 300 帧）。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --fixed-fps 30 -s tools/capture_hd2d.gd

ffmpeg -y -framerate 30 -i /tmp/hd2d_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/hd2d_demo.mp4

ffmpeg -y -framerate 30 -i /tmp/hd2d_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=800:-1:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/hd2d_demo.gif

ls -lh docs/hd2d_demo.mp4 docs/hd2d_demo.gif
