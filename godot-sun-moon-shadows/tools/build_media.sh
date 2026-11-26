#!/usr/bin/env bash
# 把 /tmp/sms_frames 的 150 帧编码为 10s MP4（1280×720）与 GIF（640×360）。
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs
ffmpeg -y -loglevel error -framerate 15 -i /tmp/sms_frames/f_%03d.png \
	-c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -movflags +faststart \
	docs/sun_moon_shadows.mp4
ffmpeg -y -loglevel error -framerate 15 -i /tmp/sms_frames/f_%03d.png \
	-vf "fps=12,scale=640:360:flags=neighbor,split[a][b];[a]palettegen=max_colors=160[p];[b][p]paletteuse=dither=bayer" \
	docs/sun_moon_shadows.gif
ls -lh docs/sun_moon_shadows.mp4 docs/sun_moon_shadows.gif
