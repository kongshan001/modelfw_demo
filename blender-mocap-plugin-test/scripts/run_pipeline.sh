#!/usr/bin/env bash
# Full reproduction: sample video -> MediaPipe pose -> source rig -> Rogue GLB
# -> key reduction -> Godot import + smoke.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
GODOT="${GODOT:-godot}"
VENV="${VENV:-$ROOT/.venv}"
PY="$VENV/bin/python"
WORK="${WORK:-$ROOT/.work}"
INPUT="${INPUT:-$ROOT/input/walking-pad-locomotion.mp4}"
CROP="${CROP:-680:1200:0:0}"     # left video pane of the RGB MoCap screen recording
SCALE="${SCALE:-340:600}"
FPS="${FPS:-30}"

[ -x "$PY" ] || { echo "run scripts/setup_env.sh first" >&2; exit 1; }
[ -s "$INPUT" ] || { echo "missing input video: $INPUT (run scripts/download_input.sh or set INPUT)" >&2; exit 1; }
[ -f "$REPO/godot-garden/assets/models/kaykit/Rogue.glb" ] || { echo "missing KayKit Rogue.glb" >&2; exit 1; }

mkdir -p "$WORK/frames" "$ROOT/exports" "$ROOT/godot/assets"
rm -f "$WORK/frames"/*.png
ffmpeg -hide_banner -loglevel error -i "$INPUT" -vf "crop=$CROP,scale=$SCALE" -r "$FPS" "$WORK/frames/%04d.png"
N=$(find "$WORK/frames" -name '*.png' | wc -l | tr -d ' ')
echo "FRAMES $N"

"$PY" "$ROOT/scripts/extract_pose.py" --frames "$WORK/frames" \
  --model "$ROOT/models/pose_landmarker_heavy.task" --out "$WORK/pose.json" --fps "$FPS"

"$PY" "$ROOT/scripts/build_motion.py" --pose "$WORK/pose.json" \
  --out "$WORK/motion.json" --fps "$FPS" --smooth 3 --ground 1

"$BLENDER" -b --factory-startup -noaudio --python "$ROOT/scripts/build_source_rig.py" -- \
  --motion "$WORK/motion.json" --out "$ROOT/source/source_full.glb"

"$BLENDER" -b --factory-startup -noaudio \
  --python "$REPO/animation-retarget-kit/tools/blender_retarget.py" -- \
  --source "$ROOT/source/source_full.glb" \
  --target "$REPO/godot-garden/assets/models/kaykit/Rogue.glb" \
  --clip Animation_MediaPipeSource \
  --out "$ROOT/exports/Rogue_MediaPipe_walk_raw.glb" \
  --map "$ROOT/source/map_mediapipe_rogue.json" --fps 30

# Optional FBX variant (same source/target; useful for Unity/UE pipelines).
"$BLENDER" -b --factory-startup -noaudio \
  --python "$REPO/animation-retarget-kit/tools/blender_retarget.py" -- \
  --source "$ROOT/source/source_full.glb" \
  --target "$REPO/godot-garden/assets/models/kaykit/Rogue.glb" \
  --clip Animation_MediaPipeSource \
  --out "$ROOT/exports/Rogue_MediaPipe_walk.fbx" \
  --map "$ROOT/source/map_mediapipe_rogue.json" --fps 30

"$BLENDER" -b --factory-startup -noaudio --python "$ROOT/scripts/simplify_action.py" -- \
  --input "$ROOT/exports/Rogue_MediaPipe_walk_raw.glb" \
  --out "$ROOT/exports/Rogue_MediaPipe_walk_simplified.glb" --epsilon 0.002

cp "$ROOT/exports/Rogue_MediaPipe_walk_raw.glb" "$ROOT/godot/assets/Rogue_MediaPipe_walk.glb"
cp "$ROOT/exports/Rogue_MediaPipe_walk_simplified.glb" "$ROOT/godot/assets/Rogue_MediaPipe_walk_simplified.glb"
cp "$ROOT/exports/Rogue_MediaPipe_walk.fbx" "$ROOT/godot/assets/Rogue_MediaPipe_walk.fbx"
"$GODOT" --headless --path "$ROOT/godot" --import >/dev/null
"$GODOT" --headless --path "$ROOT/godot" -s tools/smoke.gd
echo "PIPELINE_DONE"
