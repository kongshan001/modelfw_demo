#!/usr/bin/env bash
set -euo pipefail
BLENDER="${BLENDER:-/Applications/Blender.app/Contents/MacOS/Blender}"
exec "$BLENDER" -b -P "$(cd "$(dirname "$0")" && pwd)/blender_validate.py" -- "$@"
