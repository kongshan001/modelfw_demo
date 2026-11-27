#!/usr/bin/env bash
# Fetch the upstream RGB MoCap demo sample used only as test input.
# It is stored under input/ (gitignored) and never redistributed.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/input"
if [ ! -s "$ROOT/input/walking-pad-locomotion.mp4" ]; then
  curl -L --fail -o "$ROOT/input/walking-pad-locomotion.mp4" \
    'https://raw.githubusercontent.com/toyxyz/toyxyz_RGBMocap/main/docs/samples/walking-pad-locomotion.mp4'
fi
ls -lh "$ROOT/input/walking-pad-locomotion.mp4"
