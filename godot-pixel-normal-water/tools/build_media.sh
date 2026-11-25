#!/usr/bin/env bash
# 重新生成 docs/normal_water.mp4 与 docs/normal_water.gif。
# Movie Maker 以 30fps 固定步长写 300 帧（10s）PNG 序列；HUD 隐藏，保留原创字幕。
# 源渲染 1280×720；ffmpeg 最近邻放大到 1920×1080（320×180 美术正好 6×）。
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf /tmp/normal_water_frames
mkdir -p /tmp/normal_water_frames
godot --path . --fixed-fps 30 --resolution 1280x720 \
  --write-movie /tmp/normal_water_frames/frame.png \
  -s tools/capture_normal_water.gd

ffmpeg -y -framerate 30 -t 10 -i /tmp/normal_water_frames/frame%08d.png \
  -vf "scale=1920:1080:flags=neighbor" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart \
  docs/normal_water.mp4

ffmpeg -y -framerate 30 -t 10 -i /tmp/normal_water_frames/frame%08d.png \
  -filter_complex "fps=15,scale=1920:1080:flags=neighbor,scale=960:540:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=160[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/normal_water.gif

ls -lh docs/normal_water.mp4 docs/normal_water.gif
