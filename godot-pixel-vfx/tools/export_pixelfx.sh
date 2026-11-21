#!/usr/bin/env bash
# Re-export the six PixelFX sprite sheets used by this project.
# Usage:
#   tools/export_pixelfx.sh /path/to/pixelfx-checkout
#   PIXELFX_DIR=/path/to/pixelfx-checkout tools/export_pixelfx.sh
#
# The checked-in assets were exported from commit
#   5294518ce7c72e48b6100a744596e0acf57f2826  (PixelFX 0.3.1, MIT)
# with Node v22.19.0. No part of the PixelFX repository besides the exported
# PNG/JSON files and LICENSE/NOTICE is vendored into this project.
set -euo pipefail

cd "$(dirname "$0")/.."
PROJECT_DIR="$(pwd)"
PIXELFX_DIR="${1:-${PIXELFX_DIR:-}}"
EXPECTED_COMMIT="5294518ce7c72e48b6100a744596e0acf57f2826"

if [ -z "$PIXELFX_DIR" ] || [ ! -f "$PIXELFX_DIR/tools/render.mjs" ]; then
	echo "usage: $0 /path/to/pixelfx-checkout" >&2
	exit 1
fi
if ! node --version | grep -Eq 'v(1[89]|[2-9][0-9])\.'; then
	echo "Node 18+ is required (found $(node --version))" >&2
	exit 1
fi
actual_commit="$(git -C "$PIXELFX_DIR" rev-parse HEAD 2>/dev/null || echo unknown)"
if [ "$actual_commit" != "$EXPECTED_COMMIT" ]; then
	echo "warning: checkout is $actual_commit, committed assets came from $EXPECTED_COMMIT" >&2
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

(
	cd "$PIXELFX_DIR"
	node tools/render.mjs \
		melee/double-slash fire/fireball explosions/small-explosion \
		ice/freeze pickups/coin-spin \
		--sheet --out "$TMP/records"
	node tools/render.mjs pickups/collect-burst --sheet \
		--opts '{"palette":["#1a1205","#3d2a08","#704a0c","#b07b12","#f5b92c","#ffde5e","#fff4bc","#ffffff"]}' \
		--out "$TMP/gold"
)

copy_pair() { # source-stem destination-dir
	local stem="$1" dest="$2"
	mkdir -p "$dest"
	cp "$stem.png" "$stem.json" "$dest/"
}

copy_pair "$TMP/records/melee/double-slash/double-slash" \
	"$PROJECT_DIR/assets/pixelfx/melee/double-slash"
copy_pair "$TMP/records/fire/fireball/fireball" \
	"$PROJECT_DIR/assets/pixelfx/fire/fireball"
copy_pair "$TMP/records/explosions/small-explosion/small-explosion" \
	"$PROJECT_DIR/assets/pixelfx/explosions/small-explosion"
copy_pair "$TMP/records/ice/freeze/freeze" \
	"$PROJECT_DIR/assets/pixelfx/ice/freeze"
copy_pair "$TMP/records/pickups/coin-spin/coin-spin" \
	"$PROJECT_DIR/assets/pixelfx/pickups/coin-spin"
copy_pair "$TMP/gold/pickups/collect-burst/collect-burst" \
	"$PROJECT_DIR/assets/pixelfx/pickups/collect-burst"

cp "$PIXELFX_DIR/LICENSE" "$PROJECT_DIR/assets/pixelfx/LICENSE"
cp "$PIXELFX_DIR/NOTICE.md" "$PROJECT_DIR/assets/pixelfx/NOTICE.md"

echo "exported 6 sheets from $actual_commit"
echo "next: refresh assets/pixelfx/MANIFEST.json hashes if the source commit changed,"
echo "      then re-import and run tools/smoke_pixel_vfx.gd"
