#!/usr/bin/env bash
# 重新渲染 10 秒过程视频与 1920 截图；需要本机 Godot 4.6 + ffmpeg。
set -euo pipefail
cd "$(dirname "$0")/.."

godot --path . --resolution 1280x720 -s tools/render_proc_map_video.gd

ffmpeg -y -v error -framerate 30 -i /tmp/proc_map_frames/frame_%04d.png \
  -c:v libx264 -preset veryfast -crf 19 -pix_fmt yuv420p -movflags +faststart \
  docs/proc_map_demo.mp4

ffmpeg -y -v error -framerate 30 -i /tmp/proc_map_frames/frame_%04d.png \
  -vf "fps=15,scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" \
  -loop 0 docs/proc_map_demo.gif

echo "PROC_MAP_MEDIA_OK"
