#!/usr/bin/env bash
# Canonical test gate for godot-battle.
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"
cd "$project_dir" || exit 1

# A fresh clone has no .godot/global_script_class_cache.cfg; import first.
if ! godot --headless --path . --editor --quit >/dev/null 2>&1; then
	echo "TEST_HARNESS_FAIL: godot editor import failed" >&2
	exit 1
fi

tmp="$(mktemp -t godot-battle-tests.XXXXXX)"
trap 'rm -f "$tmp"' EXIT

run_with_timeout() {
	if command -v gtimeout >/dev/null 2>&1; then
		gtimeout 600 "$@"
	else
		perl -e 'alarm 600; exec @ARGV' -- "$@"
	fi
}

run_with_timeout godot --headless --path . -s tests/run_tests.gd 2>&1 | tee "$tmp"
status="${PIPESTATUS[0]}"

if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:|TEST_HARNESS_FAIL' "$tmp"; then
	echo "TEST_HARNESS_FAIL: engine/script errors detected" >&2
	exit 1
fi
if ! grep -qE '^RESULT: [0-9]+ assertions, 0 failures$' "$tmp"; then
	echo "TEST_HARNESS_FAIL: missing clean RESULT line" >&2
	exit 1
fi
if [ "$status" -ne 0 ]; then
	echo "TEST_HARNESS_FAIL: godot exited $status" >&2
	exit 1
fi
exit 0
