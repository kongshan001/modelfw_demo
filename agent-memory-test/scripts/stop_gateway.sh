#!/usr/bin/env bash
# Stop the standalone gateway started by start_gateway.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$ROOT/data/gateway.pid"
if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE")"
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    for _ in $(seq 1 20); do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.5
    done
    kill -9 "$PID" 2>/dev/null || true
    echo "Stopped gateway pid $PID."
  else
    echo "Gateway pid $PID is not running."
  fi
  rm -f "$PIDFILE"
else
  echo "No pidfile at $PIDFILE."
fi
