#!/usr/bin/env bash
# 风格化海洋第二版验收：
#   1) 编辑器导入（脚本/资源解析）
#   2) headless smoke（69 项，STYLIZED_OCEAN_SMOKE_OK）
#   3) 600 帧无窗口启动，扫描 SCRIPT ERROR / ERROR
#   4) 真实 GPU 1920×1080 截图矩阵
#   5) 可选 --probe：真实 GPU 性能探针
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/dev/null 2>&1

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_stylized_ocean.gd

echo "== 600-frame boot =="
LOG=/tmp/stylized_ocean_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots 1920x1080 =="
godot --path . -s tools/screenshot_stylized_ocean.gd

if [[ "${1:-}" == "--probe" ]]; then
  echo "== GPU fps probe =="
  godot --path . -s tools/probe_stylized_ocean.gd
fi

echo "STYLIZED_OCEAN_VERIFY_OK"
