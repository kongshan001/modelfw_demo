#!/usr/bin/env bash
# One-shot acceptance check: headless smoke + required deliverables present.
set -euo pipefail
cd "$(dirname "$0")/.."

godot --headless --path . -s tools/smoke_magic_vfx.gd 2>&1 | tee /tmp/magic_vfx_smoke.log | tail -3
grep -q "MAGIC_VFX_SMOKE_OK" /tmp/magic_vfx_smoke.log
echo "SMOKE PASS"

missing=0
for f in docs/shots/01_overview.png docs/shots/02_charge_ember.png docs/shots/03_flight_ember.png \
         docs/shots/04_impact_ember.png docs/shots/06_impact_arcane.png docs/shots/07_impact_frost.png \
         docs/magic_vfx_demo.mp4 docs/magic_vfx_demo.gif; do
  if [ ! -s "$f" ]; then echo "MISSING $f"; missing=1; fi
done
[ "$missing" = "0" ] && echo "DELIVERABLES PASS"
exit "$missing"
