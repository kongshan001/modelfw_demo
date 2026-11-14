#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/4] inspect source"
bash tools/blender_inspect.sh assets/source/Soldier.glb --require-armature

echo "[2/4] inspect target"
bash tools/blender_inspect.sh assets/target/Michelle.glb --require-armature

echo "[3/4] retarget Walk"
bash tools/blender_retarget.sh \
  --source assets/source/Soldier.glb \
  --target assets/target/Michelle.glb \
  --clip Walk \
  --out examples/soldier_to_michelle/Michelle_Walk.glb \
  --fps 30

echo "[4/4] validate"
bash tools/blender_validate.sh examples/soldier_to_michelle/Michelle_Walk.glb

echo "OK: examples/soldier_to_michelle/Michelle_Walk.glb"
