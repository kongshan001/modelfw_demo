#!/usr/bin/env bash
# Restart the test gateway with the same environment variables.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/scripts/stop_gateway.sh" || true
"$ROOT/scripts/start_gateway.sh"
