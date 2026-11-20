#!/usr/bin/env bash
# Import, then run the headless acceptance suite.
set -euo pipefail
cd "$(dirname "$0")/.."

godot --headless --path . --editor --quit
godot --headless --path . -s tools/smoke_mech.gd
