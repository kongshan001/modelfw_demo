#!/usr/bin/env bash
# One-command verification for a clean checkout:
#   1) import assets and build the global class cache (required on first run)
#   2) headless smoke (expects PIXEL_VFX_SMOKE_OK)
#   3) real-GPU FPS probe (writes docs/perf.json)
#   4) 1920x1080 screenshots
# Requires Godot 4.6 and a working GPU for steps 3-4.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --import

echo "== smoke =="
godot --headless --path . -s tools/smoke_pixel_vfx.gd

echo "== GPU fps probe =="
godot --path . -s tools/probe_pixel_vfx.gd

echo "== screenshots =="
godot --path . -s tools/screenshot_pixel_vfx.gd

echo "TOOLS_VERIFY_OK"
