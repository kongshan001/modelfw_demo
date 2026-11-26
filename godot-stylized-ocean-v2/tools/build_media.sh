#!/usr/bin/env bash
# 重新生成 docs/ocean_v2.mp4 与 docs/ocean_v2.gif（10s，15fps 源帧）。
set -euo pipefail
cd "$(dirname "$0")/.."
godot --path . -s tools/capture_stylized_ocean.gd
mkdir -p docs
ffmpeg -y -framerate 15 -i /tmp/ocean_v2_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/ocean_v2.mp4
ffmpeg -y -framerate 15 -i /tmp/ocean_v2_frames/frame_%03d.png \
  -filter_complex "fps=10,scale=720:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=80:stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/ocean_v2.gif
ls -lh docs/ocean_v2.mp4 docs/ocean_v2.gif
