#!/usr/bin/env bash
# 录制 12 秒 1280×720 演示，输出 docs/card_tactics.mp4 与 docs/card_tactics.gif。
# 依赖：godot（或设置 GODOT_BIN）、ffmpeg。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"

mkdir -p docs
"$GODOT_BIN" --path . --resolution 1280x720 --fixed-fps 30 \
	--write-movie docs/card_tactics.avi -s tools/demo_card_tactics.gd

ffmpeg -y -loglevel error -i docs/card_tactics.avi \
	-c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
	docs/card_tactics.mp4
ffmpeg -y -loglevel error -i docs/card_tactics.avi \
	-vf "fps=18,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
	-loop 0 docs/card_tactics.gif

rm -f docs/card_tactics.avi
echo "CARD_TACTICS_RECORD_OK $(du -h docs/card_tactics.mp4 | cut -f1) mp4 / $(du -h docs/card_tactics.gif | cut -f1) gif"
