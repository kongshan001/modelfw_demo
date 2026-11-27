#!/usr/bin/env bash
# Isolated MediaPipe environment for the Pose_AI fast-mode reproduction.
# Tested on macOS 12.7.6 (Intel) with Blender 3.4.1's Python 3.10.2.
# Nothing is installed into Blender or the system Python.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BLENDER_PY="${BLENDER_PY:-/Applications/Blender.app/Contents/Resources/3.4/python/bin/python3.10}"
VENV="${VENV:-$ROOT/.venv}"
INDEX="${PIP_INDEX_URL:-https://pypi.tuna.tsinghua.edu.cn/simple}"
HOST="${INDEX#*://}"; HOST="${HOST%%/*}"
PIP_ARGS=(-i "$INDEX")
[ -n "$HOST" ] && PIP_ARGS+=(--trusted-host "$HOST")

if [ ! -x "$BLENDER_PY" ]; then
  echo "Blender's Python not found: $BLENDER_PY (set BLENDER_PY)" >&2
  exit 1
fi
if [ ! -x "$VENV/bin/python" ]; then
  "$BLENDER_PY" -m venv "$VENV"
fi
"$VENV/bin/python" -m pip install -q --upgrade pip

# MediaPipe 0.10.9 is the last release with macOS x86_64 wheels for Python
# 3.10/3.11. --no-deps avoids pulling jax/opencv/matplotlib; the Tasks API only
# needs the packages below. MediaPipe's top-level import also imports its
# drawing helpers, hence the tiny cv2/matplotlib stubs copied afterwards.
"$VENV/bin/python" -m pip install --no-deps \
  mediapipe==0.10.9 numpy==1.26.4 flatbuffers absl-py protobuf==4.25.3 attrs \
  "${PIP_ARGS[@]}"

SP="$VENV/lib/python3.10/site-packages"
cp "$ROOT/scripts/stubs/cv2.py" "$SP/cv2.py"
mkdir -p "$SP/matplotlib"
cp "$ROOT/scripts/stubs/matplotlib/__init__.py" "$SP/matplotlib/__init__.py"
cp "$ROOT/scripts/stubs/matplotlib/pyplot.py" "$SP/matplotlib/pyplot.py"

mkdir -p "$ROOT/models"
if [ ! -s "$ROOT/models/pose_landmarker_heavy.task" ]; then
  curl -L --fail -o "$ROOT/models/pose_landmarker_heavy.task" \
    'https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_heavy/float16/1/pose_landmarker_heavy.task'
fi
if [ ! -s "$ROOT/models/hand_landmarker.task" ]; then
  curl -L --fail -o "$ROOT/models/hand_landmarker.task" \
    'https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task'
fi

"$VENV/bin/python" - <<'PY'
import mediapipe as mp
from mediapipe.tasks.python import vision
print('MEDIAPIPE_OK', mp.__version__)
PY
ls -lh "$ROOT/models"
