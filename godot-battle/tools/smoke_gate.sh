#!/usr/bin/env bash
# Smoke/probe gate for godot-battle.
# Runs a tools/ script and fails on engine/script errors even when the script exits 0.
# Usage: bash godot-battle/tools/smoke_gate.sh <script-under-tools> [godot args...]
# Example: bash godot-battle/tools/smoke_gate.sh smoke_presentation.gd --headless
set -uo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
project_dir="$(cd "$script_dir/.." && pwd)"

if [ "$#" -lt 1 ]; then
	echo "usage: bash $0 <script-under-tools> [godot args...]" >&2
	exit 2
fi

script_arg="$1"
shift

case "$script_arg" in
	/*) script_path="$script_arg" ;;
	tools/*) script_path="$project_dir/$script_arg" ;;
	*) script_path="$script_dir/$script_arg" ;;
esac

if [ ! -f "$script_path" ]; then
	echo "SMOKE_GATE_FAIL: script not found: $script_path" >&2
	exit 1
fi

rel_script="${script_path#"$project_dir"/}"
if [ "$rel_script" = "$script_path" ]; then
	echo "SMOKE_GATE_FAIL: script must live under $project_dir" >&2
	exit 1
fi

tmp="$(mktemp -t godot-smoke.XXXXXX)"
filtered="${tmp}.filtered"
trap 'rm -f "$tmp" "$filtered"' EXIT

run_with_timeout() {
	if command -v gtimeout >/dev/null 2>&1; then
		gtimeout 600 "$@"
	else
		perl -e 'alarm 600; exec @ARGV' -- "$@"
	fi
}

cd "$project_dir" || exit 1
run_with_timeout godot --path "$project_dir" "$@" -s "$rel_script" 2>&1 | tee "$tmp"
status="${PIPESTATUS[0]}"

if [ "$status" -eq 124 ] || [ "$status" -eq 142 ]; then
	echo "SMOKE_GATE_FAIL: timed out after 600s ($script_arg)" >&2
	exit 1
fi

# Godot 4.6 emits `ERROR: N resources still in use at exit` on shutdown for
# several otherwise-successful headless tools (documented known limitation).
# Ignore only that exact shutdown diagnostic; every other ERROR: stays fatal.
resource_leak_re='^ERROR: [0-9]+ resources still in use at exit'
if grep -qE "$resource_leak_re" "$tmp"; then
	echo "SMOKE_GATE_NOTE: ignoring known exit-time resource diagnostic" >&2
fi
grep -vE "$resource_leak_re" "$tmp" >"$filtered"
if grep -qE 'SCRIPT ERROR|Parse Error|ERROR:' "$filtered"; then
	echo "SMOKE_GATE_FAIL: engine/script errors detected in $script_arg" >&2
	grep -nE 'SCRIPT ERROR|Parse Error|ERROR:' "$filtered" >&2
	exit 1
fi

if [ "$status" -ne 0 ]; then
	echo "SMOKE_GATE_FAIL: godot exited $status ($script_arg)" >&2
	exit 1
fi

echo "SMOKE_OK $script_arg"
exit 0
