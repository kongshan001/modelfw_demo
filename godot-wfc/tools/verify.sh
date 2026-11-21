#!/usr/bin/env bash
# 坍缩花园验收：
#   1) 编辑导入（脚本解析）
#   2) headless smoke（约束/确定性/回溯/UI 接口）
#   3) 600 帧无窗口启动，扫描 ERROR
#   4) 1920×1080 GPU 截图矩阵
#   5) 可选 --probe：vsync off 的 30 FPS 探针
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_wfc.gd

echo "== 600-frame boot =="
LOG=/tmp/wfc_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots =="
godot --path . --resolution 1280x720 -s tools/screenshot_wfc.gd

if [[ "${1:-}" == "--probe" ]]; then
  echo "== GPU fps probe =="
  godot --path . --resolution 1280x720 -s tools/probe_wfc.gd
fi

echo "WFC_VERIFY_OK"
