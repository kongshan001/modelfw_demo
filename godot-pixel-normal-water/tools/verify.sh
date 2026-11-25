#!/usr/bin/env bash
# 静水回廊验收：
#   1) 编辑器导入（无解析/脚本错误）
#   2) headless smoke（单相机/法线/倒影/量化/开关/暂停/HUD）
#   3) headless 600 帧启动，扫描 ERROR
#   4) 真实 GPU 600 帧启动，扫描 ERROR
#   5) 真实 GPU 1920×1080 截图矩阵（8 张）
#   6) 1280×720 与 1920×1080 真实 FPS / draw calls
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/tmp/normal_water_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/normal_water_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/normal_water_import.log >&2
  exit 1
fi

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_normal_water.gd

echo "== headless 600-frame boot =="
LOG=/tmp/normal_water_headless_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in headless boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "headless boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== real-GPU 600-frame boot =="
GPU_LOG=/tmp/normal_water_gpu_boot.log
godot --path . --resolution 1280x720 --quit-after 600 >"$GPU_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$GPU_LOG"; then
  echo "ERRORS in GPU boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$GPU_LOG" >&2
  exit 1
fi
echo "GPU boot clean ($(wc -l <"$GPU_LOG" | tr -d ' ') log lines)"

echo "== real-GPU 1920x1080 screenshots =="
godot --path . -s tools/screenshot_normal_water.gd

echo "== 1280x720 FPS probe =="
godot --path . --resolution 1280x720 -s tools/probe_normal_water.gd

echo "== 1920x1080 FPS probe (borderless root window) =="
godot --path . -s tools/probe_normal_water_1080.gd

echo "NORMAL_WATER_VERIFY_OK"
