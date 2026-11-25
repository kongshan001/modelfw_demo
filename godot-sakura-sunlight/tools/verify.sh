#!/usr/bin/env bash
# 一条龙验收：
#   1) 编辑器导入；2) headless smoke；3) headless/GPU 600 帧扫描 ERROR；
#   4) 1920×1080 截图；5) 1280 GPU FPS/像素探针；6) 1920 离屏 FPS 探针。
# 可选：WITH_MEDIA=1 tools/verify.sh 会额外重建 MP4/GIF。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/tmp/sakura_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/sakura_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/sakura_import.log >&2
  exit 1
fi
echo "import clean"

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_sakura_sunlight.gd

echo "== headless 600-frame boot =="
HEADLESS_LOG=/tmp/sakura_headless600_verify.log
godot --headless --path . --quit-after 600 >"$HEADLESS_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$HEADLESS_LOG"; then
  echo "ERRORS in headless boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$HEADLESS_LOG" >&2
  exit 1
fi
echo "headless boot clean ($(wc -l <"$HEADLESS_LOG" | tr -d ' ') log lines)"

echo "== real-GPU 600-frame boot =="
GPU_LOG=/tmp/sakura_gpu600_verify.log
godot --path . --resolution 1280x720 --quit-after 600 >"$GPU_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$GPU_LOG"; then
  echo "ERRORS in GPU boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$GPU_LOG" >&2
  exit 1
fi
echo "GPU boot clean ($(wc -l <"$GPU_LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots (1920x1080) =="
godot --path . -s tools/screenshot_sakura_sunlight.gd

echo "== 1280x720 GPU probe =="
godot --path . --resolution 1280x720 -s tools/probe_sakura_sunlight.gd

echo "== 1920x1080 offscreen probe =="
godot --path . -s tools/probe_sakura_sunlight_1080.gd

if [ "${WITH_MEDIA:-0}" = "1" ]; then
  echo "== rebuild media =="
  tools/build_media.sh
fi

echo "SAKURA_SUNLIGHT_VERIFY_OK"
