#!/usr/bin/env bash
# One-shot headless verification: import, boot, smoke, structure.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== import =="
godot --headless --path . --editor --quit >/dev/null 2>&1

echo "== boot (600 frames) =="
BOOT_LOG="$(godot --headless --path . --quit-after 600 2>&1)"
if grep -Eq "SCRIPT ERROR|^ERROR:" <<<"$BOOT_LOG"; then
	echo "$BOOT_LOG"
	echo "BOOT_FAIL"
	exit 1
fi
echo "BOOT_OK"

echo "== smoke =="
SMOKE_LOG="$(godot --headless --path . -s tools/smoke_slot.gd 2>&1)"
echo "$SMOKE_LOG"
grep -q "SLOT_SMOKE_OK" <<<"$SMOKE_LOG"

echo "== structure =="
for f in \
	project.godot scenes/main.tscn \
	src/reel_game.gd src/reel_slot.gd src/reel_art.gd \
	tools/smoke_slot.gd tools/screenshot_slot.gd tools/capture_slot_gif.gd tools/playtest_slot.gd \
	tools/perf_slot.gd tools/art_sheet.gd \
	README.md docs/TECH.md docs/迭代记录.md assets/CREDITS.md; do
	if [ ! -f "$f" ]; then
		echo "MISSING $f"
		exit 1
	fi
done
if grep -REn 'res://assets/[^"]+\.(png|jpe?g|webp|wav|ogg|mp3)' src >/dev/null 2>&1; then
	echo "EXTERNAL_ASSET_REF"
	exit 1
fi
echo "VERIFY_OK"
