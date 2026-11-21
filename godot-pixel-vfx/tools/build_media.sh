#!/usr/bin/env bash
# Regenerate the 10 s demo video and GIF from a deterministic 30 fps capture.
# Requires Godot 4.6 and ffmpeg.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf /tmp/pixel_vfx_frames
mkdir -p /tmp/pixel_vfx_frames
godot --path . -s tools/capture_pixel_vfx.gd

ffmpeg -y -v error -framerate 30 -i /tmp/pixel_vfx_frames/frame_%03d.png \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -preset medium -movflags +faststart \
  docs/pixel_vfx_demo.mp4

ffmpeg -y -v error -framerate 30 -i /tmp/pixel_vfx_frames/frame_%03d.png \
  -filter_complex "fps=20,scale=960:540:flags=neighbor,split[s0][s1];[s0]palettegen=max_colors=192:stats_mode=full[p];[s1][p]paletteuse=dither=none" \
  docs/pixel_vfx_demo.gif

ls -lh docs/pixel_vfx_demo.mp4 docs/pixel_vfx_demo.gif
