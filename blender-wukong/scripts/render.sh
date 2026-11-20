#!/usr/bin/env bash
# Build, render, encode MP4/GIF, bake+export GLB.
set -euo pipefail
cd "$(dirname "$0")/.."

BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT="${OUT:-/tmp/wukong_frames}"

rm -rf "$OUT"
mkdir -p "$OUT" docs

"$BLENDER" -b -P scripts/build_wukong.py

ffmpeg -y -v error -framerate 24 -i "$OUT/frame_%04d.png" \
  -c:v libx264 -pix_fmt yuv420p -crf 18 -movflags +faststart \
  docs/wukong_ki.mp4

ffmpeg -y -v error -framerate 24 -i "$OUT/frame_%04d.png" \
  -vf "fps=12,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
  -loop 0 docs/wukong_ki.gif

ffmpeg -y -v error -ss 3.33 -i docs/wukong_ki.mp4 -frames:v 1 docs/poster.png

"$BLENDER" -b -P scripts/export_glb.py

echo "WUKONG_ALL_OK"
