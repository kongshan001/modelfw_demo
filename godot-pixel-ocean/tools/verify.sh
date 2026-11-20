#!/usr/bin/env bash
# Pixel Ocean 验收：
#   1) 编辑导入（无解析错误）
#   2) headless smoke（网格/shader/5点/昼夜/倒影）
#   3) 600 帧无窗口启动，扫描 ERROR
#   4) GPU 截图矩阵（1280×720，Intel HD 6000 实测）
#   5) 可选 --probe：vsync off 的 FPS 探针
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_pixel_ocean.gd

echo "== 600-frame boot =="
LOG=/tmp/pixel_ocean_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots =="
godot --path . --resolution 1280x720 -s tools/screenshot_pixel_ocean.gd

if [[ "${1:-}" == "--probe" ]]; then
  echo "== GPU fps probe =="
  godot --path . --resolution 1280x720 -s tools/probe_pixel_ocean.gd
fi

echo "PIXEL_OCEAN_VERIFY_OK"
