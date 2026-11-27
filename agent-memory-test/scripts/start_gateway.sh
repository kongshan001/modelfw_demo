#!/usr/bin/env bash
# Start the official TencentDB Agent Memory standalone gateway (v0.3.6 source tree)
# against a local, OpenAI-compatible Ollama endpoint. No cloud credentials.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OFFICIAL="$ROOT/.work/official"
DATA_DIR="${TDAI_DATA_DIR:-$ROOT/data}"
PORT="${TDAI_GATEWAY_PORT:-18420}"

if [[ ! -d "$OFFICIAL/node_modules" ]]; then
  echo "ERROR: dependencies missing. Run scripts/setup_official.sh first." >&2
  exit 1
fi
EMBED_URL="${TDAI_EMBEDDING_BASE_URL:-http://127.0.0.1:11434/v1}"
if [[ "$EMBED_URL" == *"127.0.0.1:11434"* ]] && ! curl -fsS --max-time 5 "http://127.0.0.1:11434/api/tags" >/dev/null; then
  echo "ERROR: Ollama is not running on 127.0.0.1:11434 (needed for the default embedding config)." >&2
  exit 1
fi

mkdir -p "$DATA_DIR" "$ROOT/logs"
if [[ -f "$DATA_DIR/gateway.pid" ]] && kill -0 "$(cat "$DATA_DIR/gateway.pid")" 2>/dev/null; then
  echo "Gateway already running (pid $(cat "$DATA_DIR/gateway.pid"))."
  exit 0
fi

export TDAI_DATA_DIR="$DATA_DIR"
export TDAI_GATEWAY_PORT="$PORT"
export TDAI_GATEWAY_CONFIG="${TDAI_GATEWAY_CONFIG:-$ROOT/config/tdai-gateway.test.yaml}"
export TDAI_LLM_BASE_URL="${TDAI_LLM_BASE_URL:-http://127.0.0.1:11434/v1}"
export TDAI_LLM_API_KEY="${TDAI_LLM_API_KEY:-ollama-local}"
export TDAI_LLM_MODEL="${TDAI_LLM_MODEL:-llama3.2}"
export TDAI_EMBEDDING_BASE_URL="${TDAI_EMBEDDING_BASE_URL:-http://127.0.0.1:11434/v1}"
export TDAI_EMBEDDING_API_KEY="${TDAI_EMBEDDING_API_KEY:-ollama-local}"
export TDAI_EMBEDDING_MODEL="${TDAI_EMBEDDING_MODEL:-nomic-embed-text}"

cd "$OFFICIAL"
nohup node node_modules/tsx/dist/cli.mjs src/gateway/server.ts > "$ROOT/logs/gateway.log" 2>&1 &
echo $! > "$DATA_DIR/gateway.pid"
echo "Started gateway pid $(cat "$DATA_DIR/gateway.pid"), log: $ROOT/logs/gateway.log"

for _ in $(seq 1 30); do
  if curl -fsS --max-time 2 "http://127.0.0.1:$PORT/health" >/tmp/tdai-health.json 2>/dev/null; then
    echo "Health: $(cat /tmp/tdai-health.json)"
    exit 0
  fi
  sleep 1
done
echo "ERROR: gateway did not become healthy; last log lines:" >&2
tail -40 "$ROOT/logs/gateway.log" >&2 || true
exit 1
