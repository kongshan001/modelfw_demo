#!/usr/bin/env bash
# Stop the test gateway and remove only this directory's generated artifacts.
# Keeps scripts/, config/, samples/, evidence/, docs/ and README.md.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/stop_gateway.sh" || true
if [[ "${1:-}" != "--yes" ]]; then
  printf 'Delete %s/{data,logs,.work}? [y/N] ' "$ROOT"
  read -r answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "aborted"; exit 1; }
fi
rm -rf "$ROOT/data" "$ROOT/logs" "$ROOT/.work"
echo "Removed generated data, logs and cloned dependencies."
