#!/usr/bin/env bash
# Verify the portable core across all three languages + vendored copies.
set -euo pipefail
cd "$(dirname "$0")"

python3 sync.py --check
python3 tests/test_python.py
node tests/test_js.mjs
(cd ../godot-iso-slice && godot --headless --path . -s tools/portable_core_check.gd)

echo "PORTABLE_ALL_OK"
