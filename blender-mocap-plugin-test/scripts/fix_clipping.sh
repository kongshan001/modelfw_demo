#!/usr/bin/env bash
# T-012 follow-up: collision-aware cleanup of the MediaPipe->Rogue walk.
# Produces exports/Rogue_MediaPipe_walk_fixed.glb and .fbx, copies the clean
# GLB into the Godot project, imports it, and runs the fixed smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
GODOT="${GODOT:-godot}"
RAW="$ROOT/exports/Rogue_MediaPipe_walk_raw.glb"
FIXED="$ROOT/exports/Rogue_MediaPipe_walk_fixed.glb"
FBX="$ROOT/exports/Rogue_MediaPipe_walk_fixed.fbx"
REPORT="$ROOT/.work/clipdiag/fix_report.json"

[ -s "$RAW" ] || { echo "missing $RAW (run scripts/run_pipeline.sh first)" >&2; exit 1; }
mkdir -p "$ROOT/.work/clipdiag"

"$BLENDER" -b --factory-startup -noaudio --python "$ROOT/scripts/fix_clipping.py" -- \
  --glb "$RAW" --out "$FIXED" --out-fbx "$FBX" --report "$REPORT"

cp "$FIXED" "$ROOT/godot/assets/Rogue_MediaPipe_walk_fixed.glb"
cp "$FBX" "$ROOT/godot/assets/Rogue_MediaPipe_walk_fixed.fbx"
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null
"$GODOT" --headless --path "$ROOT/godot" -s tools/smoke.gd
echo "FIX_CLIPPING_DONE"
