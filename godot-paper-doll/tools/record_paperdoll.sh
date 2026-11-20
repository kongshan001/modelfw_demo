#!/usr/bin/env bash
# 录制 6–10 秒的换装 / 8 向 / 4 动作演示，输出 docs/paperdoll.mp4 与 docs/paperdoll.gif。
# 依赖：godot（或设置 GODOT_BIN）、ffmpeg。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
GODOT_BIN="${GODOT_BIN:-godot}"

mkdir -p docs
"$GODOT_BIN" --path . --resolution 1280x720 --fixed-fps 30 \
	--write-movie docs/paperdoll.avi -s tools/demo_paperdoll.gd

ffmpeg -y -loglevel error -i docs/paperdoll.avi \
	-c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -movflags +faststart \
	docs/paperdoll.mp4
ffmpeg -y -loglevel error -i docs/paperdoll.avi \
	-vf "fps=18,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=192[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" \
	-loop 0 docs/paperdoll.gif

rm -f docs/paperdoll.avi
echo "PAPERDOLL_RECORD_OK $(du -h docs/paperdoll.mp4 | cut -f1) mp4 / $(du -h docs/paperdoll.gif | cut -f1) gif"
