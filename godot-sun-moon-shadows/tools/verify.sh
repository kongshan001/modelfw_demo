#!/usr/bin/env bash
# 一条龙验收：导入 / headless smoke / headless & GPU 600 帧 / GPU 探针 / 1920 截图。
# WITH_MEDIA=1 时额外采集 150 帧并重建 MP4/GIF。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --import >/tmp/sms_import.log 2>&1
if grep -Eq "SCRIPT ERROR|Parse Error" /tmp/sms_import.log; then
  grep -nE "SCRIPT ERROR|Parse Error" /tmp/sms_import.log >&2; exit 1
fi

echo "== headless smoke =="
godot --headless --path . -s tools/smoke_sun_moon_shadows.gd

echo "== headless 600-frame boot =="
godot --headless --path . --quit-after 600 >/tmp/sms_headless600.log 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" /tmp/sms_headless600.log; then
  grep -nE "SCRIPT ERROR|ERROR:" /tmp/sms_headless600.log >&2; exit 1
fi
echo "headless boot clean"

echo "== real-GPU 600-frame boot =="
godot --path . --resolution 1280x720 --quit-after 600 >/tmp/sms_gpu600.log 2>&1 || true
if grep -Eq "SCRIPT ERROR|ERROR:" /tmp/sms_gpu600.log; then
  grep -nE "SCRIPT ERROR|ERROR:" /tmp/sms_gpu600.log >&2; exit 1
fi
echo "GPU boot clean"

echo "== GPU pixel/probe (1280 + 1920 FPS) =="
godot --path . --resolution 1280x720 -s tools/probe_sun_moon_shadows.gd

echo "== 1920x1080 screenshots =="
godot --path . -s tools/screenshot_sun_moon_shadows.gd

if [ "${WITH_MEDIA:-0}" = "1" ]; then
  echo "== capture 10s sequence =="
  godot --path . -s tools/capture_sequence.gd
  tools/build_media.sh
fi

echo "SUN_MOON_SHADOW_VERIFY_OK"
