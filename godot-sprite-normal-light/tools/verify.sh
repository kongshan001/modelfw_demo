#!/usr/bin/env bash
# 一键验收：headless smoke + 1280 性能 + 1920 性能。
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== smoke (headless) =="
godot --headless --path . -s tools/smoke_sprite_normal_light.gd | tail -3

echo "== probe 1280x720 =="
godot --path . --resolution 1280x720 -s tools/probe_sprite_normal_light.gd | tail -8

echo "== probe 1920x1080 =="
godot --path . -s tools/probe_sprite_normal_light_1080.gd | tail -8
