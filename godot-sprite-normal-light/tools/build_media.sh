#!/usr/bin/env bash
# 重新生成 10s 演示视频（1920×1080 MP4 + 960×540 GIF）。
# 源帧由 1280×720 SubViewport 以固定 30fps 逐帧抓取；MP4 用最近邻放大到 1920。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --fixed-fps 30 -s tools/capture_sprite_normal_light.gd

ffmpeg -y -framerate 30 -i /tmp/sprite_normal_light_frames/frame_%03d.png \
  -vf "scale=1920:1080:flags=neighbor" \
  -c:v libx264 -pix_fmt yuv420p -crf 19 -preset medium -movflags +faststart \
  docs/sprite_normal_light.mp4

ffmpeg -y -framerate 30 -i /tmp/sprite_normal_light_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=960:-1:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/sprite_normal_light.gif

ls -lh docs/sprite_normal_light.mp4 docs/sprite_normal_light.gif
