#!/usr/bin/env bash
# One-shot import + headless acceptance for the Godot project.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --editor --quit
godot --headless --path . -s tools/smoke_ultimate.gd
echo "WUKONG_ULT_VERIFY_OK"
