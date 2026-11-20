#!/usr/bin/env bash
# 重新生成 docs/pixel_ocean.mp4 与 docs/pixel_ocean.gif。
# 需要 Godot 4.6 + ffmpeg；在项目内给出确定性 15fps 时间线。
set -euo pipefail
cd "$(dirname "$0")/.."
godot --path . --resolution 1280x720 -s tools/capture_pixel_ocean.gd
ffmpeg -y -framerate 15 -i /tmp/pixel_ocean_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
  docs/pixel_ocean.mp4
ffmpeg -y -framerate 15 -i /tmp/pixel_ocean_frames/frame_%03d.png \
  -filter_complex "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  docs/pixel_ocean.gif
ls -lh docs/pixel_ocean.mp4 docs/pixel_ocean.gif
