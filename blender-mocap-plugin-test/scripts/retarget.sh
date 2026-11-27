#!/usr/bin/env bash
# Retarget the generated Mixamo-named source rig to KayKit Rogue.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
SRC="${1:-$ROOT/source/source_full.glb}"
OUT="${2:-$ROOT/exports/Rogue_MediaPipe_walk_raw.glb}"
"$BLENDER" -b --factory-startup -noaudio \
  --python "$REPO/animation-retarget-kit/tools/blender_retarget.py" -- \
  --source "$SRC" \
  --target "$REPO/godot-garden/assets/models/kaykit/Rogue.glb" \
  --clip Animation_MediaPipeSource \
  --out "$OUT" \
  --map "$ROOT/source/map_mediapipe_rogue.json" \
  --fps 30
