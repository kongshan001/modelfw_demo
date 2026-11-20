#!/usr/bin/env bash
# Bake the sigil pipeline + mod fixtures, import assets, rebuild the TileSet,
# then run the dungeon smoke test, pipeline check and mod check.
set -euo pipefail
cd "$(dirname "$0")/.."

python3 ../portable-core/sync.py --check
python3 tools/bake_pipeline.py
python3 tools/make_mod_glb.py
godot --headless --path . --editor --quit
godot --headless --path . -s tools/build_tileset.gd
godot --headless --path . -s tools/portable_core_check.gd
godot --headless --path . -s tools/smoke_iso.gd
godot --headless --path . -s tools/pipeline_check.gd
godot --headless --path . -s tools/mod_check.gd
