#!/usr/bin/env bash
# 重新生成 10 秒演示：逐帧 1920×1080 / 30fps → H.264 MP4 + 轻量 GIF。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . -s tools/capture_pool_caustics.gd

ffmpeg -hide_banner -loglevel error -y \
  -framerate 30 -i /tmp/pool_caustics_frames/frame_%04d.png \
  -c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -movflags +faststart \
  docs/pool_caustics_10s.mp4

ffmpeg -hide_banner -loglevel error -y -i docs/pool_caustics_10s.mp4 \
  -vf "fps=12,scale=800:-1:flags=lanczos,palettegen=max_colors=160:stats_mode=diff" \
  /tmp/pool_caustics_palette.png
ffmpeg -hide_banner -loglevel error -y -i docs/pool_caustics_10s.mp4 \
  -i /tmp/pool_caustics_palette.png \
  -lavfi "fps=12,scale=800:-1:flags=lanczos [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle" \
  docs/pool_caustics_10s.gif

ls -lh docs/pool_caustics_10s.mp4 docs/pool_caustics_10s.gif
echo "POOL_CAUSTICS_MEDIA_OK"
