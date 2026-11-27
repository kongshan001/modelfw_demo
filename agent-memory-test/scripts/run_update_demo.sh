#!/usr/bin/env bash
# Update/conflict demo. Assumes the gateway is running with LLM env set.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 scripts/capture_turns.py \
  --session-key session-D-update \
  --turns-file samples/session_d_turns.json \
  --wait-records 9
python3 scripts/run_recall_checks.py \
  --query-set update --label E-update \
  --out evidence/session_e_update_recall.json --with-search
./scripts/stop_gateway.sh
