#!/usr/bin/env bash
# Import assets and run the headless acceptance test.
set -euo pipefail
cd "$(dirname "$0")/.."
godot --headless --path . --editor --quit
godot --headless --path . -s tools/smoke_snow.gd
