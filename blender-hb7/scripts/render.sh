#!/usr/bin/env bash
# Render the 240-frame HB-7 film and encode MP4 + GIF.
set -euo pipefail
cd "$(dirname "$0")/.."

BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT="${OUT:-/tmp/hb7_blender}"

rm -rf "$OUT"
mkdir -p "$OUT" docs

"$BLENDER" -b -P scripts/build_scene.py

ffmpeg -y -v error -framerate 24 -i "$OUT/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart \
  docs/hb7_core.mp4

ffmpeg -y -v error -framerate 24 -i "$OUT/frame_%04d.png" \
  -vf "fps=12,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 docs/hb7_core.gif

ffmpeg -y -v error -i docs/hb7_core.mp4 -vf "select=eq(n\,30)" \
  -frames:v 1 docs/poster.png

echo "HB7_FILM_OK"
