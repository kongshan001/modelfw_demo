#!/usr/bin/env bash
# Record the 10 s demo at 1280x720@30 (Movie Maker) and encode MP4 + GIF.
# Requires Godot 4.6 and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

AVI=/tmp/magic_vfx_capture.avi
rm -f "$AVI"
godot --path . --write-movie "$AVI" --fixed-fps 30 -- --capture

ffmpeg -y -v error -i "$AVI" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart \
  docs/magic_vfx_demo.mp4

ffmpeg -y -v error -i "$AVI" \
  -filter_complex "fps=20,scale=960:540:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192:stats_mode=full[p];[s1][p]paletteuse=dither=bayer" \
  docs/magic_vfx_demo.gif

ls -lh docs/magic_vfx_demo.mp4 docs/magic_vfx_demo.gif
