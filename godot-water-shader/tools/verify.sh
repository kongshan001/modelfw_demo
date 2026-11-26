#!/usr/bin/env bash
# 潮汐花园验收：
#   1) 编辑器导入（无解析错误）
#   2) headless smoke（mask→depth→BFS / 三预设 / 单 shader / 桥 / 雨积水 / 重置）
#   3) headless 600 帧启动，扫描 ERROR
#   4) 真实 GPU 600 帧启动，扫描 ERROR
#   5) 真实 GPU 1920×1080 截图矩阵
#   6) 1280×720 窗口 / 1920×1080 离屏 FPS 与 draw calls
# 媒体生成见 tools/build_media.sh（耗时较长，不放进每次验收）。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/tmp/water_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/water_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/water_import.log >&2
  exit 1
fi

echo "== headless smoke =="
SMOKE_LOG=/tmp/water_smoke.log
godot --headless --path . -s tools/smoke_water_shader.gd | tee "$SMOKE_LOG"
grep -q "WATER_SHADER_SMOKE_OK" "$SMOKE_LOG"
if grep -Eq "SCRIPT ERROR|ERROR:" "$SMOKE_LOG"; then
  echo "ERRORS in smoke log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$SMOKE_LOG" >&2
  exit 1
fi

echo "== headless 600-frame boot =="
LOG=/tmp/water_headless_boot.log
godot --headless --path . --quit-after 600 >"$LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$LOG"; then
  echo "ERRORS in headless boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$LOG" >&2
  exit 1
fi
echo "headless boot clean ($(wc -l <"$LOG" | tr -d ' ') log lines)"

echo "== real-GPU 600-frame boot =="
GPU_LOG=/tmp/water_gpu_boot.log
godot --path . --resolution 1280x720 --quit-after 600 >"$GPU_LOG" 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" "$GPU_LOG"; then
  echo "ERRORS in GPU boot log:" >&2
  grep -nE "SCRIPT ERROR|ERROR:" "$GPU_LOG" >&2
  exit 1
fi
echo "GPU boot clean ($(wc -l <"$GPU_LOG" | tr -d ' ') log lines)"

echo "== GPU screenshots (1920x1080) =="
godot --path . -s tools/screenshot_water_shader.gd

echo "== 720p probe (native window) =="
godot --path . --resolution 1280x720 -s tools/probe_water_shader.gd

echo "== 1080p probe (offscreen) =="
godot --path . -s tools/probe_water_shader_1080.gd

echo "WATER_SHADER_VERIFY_OK"
