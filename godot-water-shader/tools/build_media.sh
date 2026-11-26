#!/usr/bin/env bash
# 重新生成 docs/water_shader.mp4 与 docs/water_shader.gif。
# 30fps 固定步长抓 300 帧（10s），1920×1080 离屏；HUD 收起，仅保留字幕。
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf /tmp/water_shader_frames
mkdir -p /tmp/water_shader_frames

godot --path . --fixed-fps 30 -s tools/capture_water_shader.gd

ffmpeg -y -framerate 30 -i /tmp/water_shader_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/water_shader.mp4

ffmpeg -y -framerate 30 -i /tmp/water_shader_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=112[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/water_shader.gif

ls -lh docs/water_shader.mp4 docs/water_shader.gif
