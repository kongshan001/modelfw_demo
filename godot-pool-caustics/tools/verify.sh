#!/usr/bin/env bash
# 池底光网验收：
#   1) 编辑器导入（无解析错误）
#   2) headless smoke（六个参数/七视图/单格/熔岩/重置）
#   3) headless 600 帧启动，扫描 ERROR
#   4) 真实 GPU 600 帧启动，扫描 ERROR
#   5) 真实 GPU 1920×1080 截图矩阵（11 张）
#   6) 1280×720 实窗性能 + 1920×1080 离屏性能
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/tmp/pool_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/pool_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/pool_import.log >&2
  exit 1
fi

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_pool_caustics.gd

echo "== headless 600-frame boot =="
LOG=/tmp/pool_headless_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in headless boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "headless boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== real-GPU 600-frame boot =="
GPU_LOG=/tmp/pool_gpu_boot.log
godot --path . --resolution 1280x720 --quit-after 600 >"$GPU_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$GPU_LOG"; then
  echo "ERRORS in GPU boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$GPU_LOG" >&2
  exit 1
fi
echo "GPU boot clean ($(wc -l <"$GPU_LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots (1920×1080) =="
godot --path . -s tools/screenshot_pool_caustics.gd

echo "== 720p performance (native window) =="
godot --path . --resolution 1280x720 -s tools/probe_pool_caustics.gd

echo "== 1080p performance (offscreen) =="
godot --path . -s tools/probe_pool_caustics_1080.gd

test -s docs/pool_caustics_10s.mp4
test -s docs/pool_caustics_10s.gif
echo "media: mp4=$(du -h docs/pool_caustics_10s.mp4 | cut -f1) gif=$(du -h docs/pool_caustics_10s.gif | cut -f1)"
echo "POOL_CAUSTICS_VERIFY_OK"
