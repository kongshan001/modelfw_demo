#!/usr/bin/env bash
# 重新渲染 10 秒过程视频：Godot 以固定 30fps 录制 300 帧，再由 ffmpeg 编码。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --resolution 1280x720 -s tools/render_wfc_video.gd

ffmpeg -y -v error -framerate 30 -i /tmp/wfc_video_frames/frame_%04d.png \
  -c:v libx264 -preset veryfast -crf 19 -pix_fmt yuv420p -movflags +faststart \
  docs/wfc_garden.mp4

ffmpeg -y -v error -framerate 30 -i /tmp/wfc_video_frames/frame_%04d.png \
  -vf "fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 docs/wfc_garden.gif

echo "WFC_MEDIA_OK"
