#!/usr/bin/env bash
# 把 showcase_paperdoll.gd 输出的 180 帧合成为 6s / 640×360 / 30fps GIF。
# 用法：bash tools/record_showcase.sh
set -euo pipefail
cd "$(dirname "$0")/.."

FRAMES="docs/shots/showcase/frames"
GIF="docs/shots/showcase/paperdoll_6s.gif"
PALETTE="$(mktemp -t paperdoll_palette).png"

if [ ! -f "$FRAMES/frame_000.png" ]; then
  echo "missing frames: run godot -s tools/showcase_paperdoll.gd first" >&2
  exit 1
fi

ffmpeg -y -loglevel error -framerate 30 -i "$FRAMES/frame_%03d.png" \
  -vf "scale=640:360:flags=lanczos,palettegen=max_colors=192:stats_mode=full" "$PALETTE"
ffmpeg -y -loglevel error -framerate 30 -i "$FRAMES/frame_%03d.png" -i "$PALETTE" \
  -lavfi "paletteuse=dither=bayer:bayer_scale=4" "$GIF"
rm -f "$PALETTE"

ls -lh "$GIF"
echo "PAPERDOLL_SHOWCASE_GIF_OK"
