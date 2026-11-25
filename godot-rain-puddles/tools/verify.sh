#!/usr/bin/env bash
# 雨落青苔验收：
#   1) 编辑器导入（无解析错误）
#   2) headless smoke（雨丝/水洼/灯柱规则/涟漪/倒影/重置）
#   3) headless 600 帧启动，扫描 ERROR
#   4) 真实 GPU 600 帧启动，扫描 ERROR
#   5) 真实 GPU 1920×1080 截图矩阵
#   6) 720p 窗口 / 1080p 离屏 FPS 与 draw calls
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/tmp/rain_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/rain_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/rain_import.log >&2
  exit 1
fi

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_rain_puddles.gd

echo "== headless 600-frame boot =="
LOG=/tmp/rain_headless_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in headless boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "headless boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== real-GPU 600-frame boot =="
GPU_LOG=/tmp/rain_gpu_boot.log
godot --path . --resolution 1280x720 --quit-after 600 >"$GPU_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$GPU_LOG"; then
  echo "ERRORS in GPU boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$GPU_LOG" >&2
  exit 1
fi
echo "GPU boot clean ($(wc -l <"$GPU_LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots (1920x1080) =="
godot --path . -s tools/screenshot_rain_puddles.gd

echo "== 720p probe (native window) =="
godot --path . --resolution 1280x720 -s tools/probe_rain_puddles.gd

echo "== 1080p probe (offscreen 1920x1080) =="
godot --path . -s tools/probe_rain_puddles_1080.gd

echo "RAIN_PUDDLES_VERIFY_OK"
