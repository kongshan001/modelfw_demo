#!/usr/bin/env bash
# Two-session demo. Assumes the gateway is already running with LLM env set.
#   1. Session A teaches 6 facts (+ one neutral turn to flush the L1 queue).
#   2. Session B (new session_key) recalls them.
#   3. --with-restart also stops/starts the gateway and checks persistence.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

python3 scripts/capture_turns.py \
  --session-key session-A-teach \
  --turns-file samples/session_a_turns.json \
  --wait-records 6

python3 scripts/run_recall_checks.py \
  --query-set base --label B-new \
  --out evidence/session_b_recall.json --with-search

if [[ "${1:-}" == "--with-restart" ]]; then
  ./scripts/stop_gateway.sh
  ./scripts/start_gateway.sh
  python3 scripts/run_recall_checks.py \
    --query-set restart --label C-restart \
    --out evidence/session_c_restart.json --with-search
fi

echo "Two-session demo done. See evidence/session_b_recall.json${1:+ and evidence/session_c_restart.json}."
