#!/usr/bin/env bash
# 重建 10 秒演示视频（1280×720 Movie Maker → 1920×1080 MP4 + 640×360 GIF）。
# 运行前确保在仓库根目录，且能无头/有窗口启动 Godot 4.6。
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/fish_media"
mkdir -p "$OUT"

# 1) Movie Maker 录制电影模式（HUD 自动隐藏；10s 后 main 自行退出）
godot --path . --resolution 1280x720 --fixed-fps 30 \
  --write-movie "$OUT/movie.avi" -- --movie

# 2) 1920×1080 H.264（最近邻 1.5×；源世界内部仍为 640×360）
ffmpeg -y -v error -i "$OUT/movie.avi" \
  -vf "scale=1920:1080:flags=neighbor" -r 30 \
  -c:v libx264 -preset slow -crf 27 -pix_fmt yuv420p -movflags +faststart \
  "$OUT/water_fish_1920.mp4"

# 3) 640×360 GIF（12fps，64 色，无额外抖动，避免二次噪点）
ffmpeg -y -v error -i "$OUT/movie.avi" \
  -vf "fps=12,scale=640:360:flags=neighbor,palettegen=max_colors=64" \
  "$OUT/palette64.png"
ffmpeg -y -v error -i "$OUT/movie.avi" -i "$OUT/palette64.png" \
  -lavfi "fps=12,scale=640:360:flags=neighbor[x];[x][1:v]paletteuse=dither=none" \
  "$OUT/water_fish_640.gif"

cp "$OUT/water_fish_1920.mp4" docs/water_fish.mp4
cp "$OUT/water_fish_640.gif" docs/water_fish.gif
echo "wrote docs/water_fish.mp4 docs/water_fish.gif"
