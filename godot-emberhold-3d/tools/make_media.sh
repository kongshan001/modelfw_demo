#!/usr/bin/env bash
# Render the 10s 30fps demo with Godot MovieWriter, then encode MP4 + GIF.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(pwd)"
godot --path "$ROOT" --resolution 1280x720 --fixed-fps 30 \
  --write-movie "$ROOT/captures/movie.avi" --quit-after 300 -- --movie
ffmpeg -y -v error -i "$ROOT/captures/movie.avi" \
  -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart -r 30 \
  "$ROOT/captures/emberhold3d-demo.mp4"
ffmpeg -y -v error -i "$ROOT/captures/movie.avi" \
  -vf "fps=15,scale=960:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 "$ROOT/captures/emberhold3d-demo.gif"
rm -f "$ROOT/captures/movie.avi"
ls -l "$ROOT/captures/emberhold3d-demo.mp4" "$ROOT/captures/emberhold3d-demo.gif"
