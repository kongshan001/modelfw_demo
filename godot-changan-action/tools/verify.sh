#!/usr/bin/env bash
# 灯下客 · 长安一夜 — 工程验收
#   bash tools/verify.sh
# 退出码：0 = core + perf 全过；2 = core 过 / perf 未过；1 = core 失败
set -u
cd "$(dirname "$0")/.."
core_fail=0
perf_fail=0

echo "== 1/4 headless boot (600 frames) =="
godot --headless --path . --quit-after 600 2>&1 | tee /tmp/changan_boot.log
if grep -qE "SCRIPT ERROR|Parse Error" /tmp/changan_boot.log; then core_fail=1; fi

echo "== 2/4 headless smoke =="
godot --headless --path . -s tools/smoke_changan_action.gd 2>&1 | tee /tmp/changan_smoke.log
if ! grep -q "CHANGAN_ACTION_SMOKE_OK" /tmp/changan_smoke.log; then core_fail=1; fi

echo "== 3/4 screenshots (1920x1080) =="
godot --path . --resolution 1920x1080 -s tools/screenshot_changan.gd 2>&1 | tee /tmp/changan_shots.log
if ! grep -q "CHANGAN_SCREENSHOTS_OK" /tmp/changan_shots.log; then core_fail=1; fi

echo "== 4/4 real-GPU FPS probe (1280x720, informational gate) =="
godot --path . --resolution 1280x720 -s tools/probe_fps.gd 2>&1 | tee /tmp/changan_fps.log
if ! grep -q "CHANGAN_FPS_OK" /tmp/changan_fps.log; then perf_fail=1; fi

if [ "$core_fail" -eq 0 ] && [ "$perf_fail" -eq 0 ]; then
  echo "CHANGAN_VERIFY_OK"
  exit 0
fi
if [ "$core_fail" -eq 0 ]; then
  echo "CHANGAN_VERIFY_CORE_OK"
  echo "CHANGAN_PERF_NOT_VERIFIED (min fps affected by host load; see docs/TECH.md §9)"
  exit 2
fi
echo "CHANGAN_VERIFY_FAIL"
exit 1
