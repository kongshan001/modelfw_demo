#!/usr/bin/env bash
# Reproduce the official v0.3.6 standalone gateway install used in this test.
#
# This installs the official source tree under .work/official (gitignored) with
# a minimal runtime-only package.json, because the upstream package.json also
# resolves a large devDependency tree (vitest/playwright) that this test does
# not need. It also repairs two artifacts that a slow/interrupted npm install
# can leave truncated. Nothing global is modified.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$ROOT/.work"
OFFICIAL="$WORK/official"
REF="${TDAI_OFFICIAL_REF:-main}"
REGISTRY="${NPM_REGISTRY:-https://registry.npmjs.org}"

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing $1" >&2; exit 1; }; }
need node
need npm
need curl
need python3

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
NODE_MINOR="$(node -p 'process.versions.node.split(".")[1]')"
if (( NODE_MAJOR < 22 || (NODE_MAJOR == 22 && NODE_MINOR < 16) )); then
  echo "ERROR: Node >= 22.16 is required (found $(node --version))." >&2
  exit 1
fi

mkdir -p "$WORK" "$ROOT/data" "$ROOT/logs"
if [[ ! -f "$OFFICIAL/src/gateway/server.ts" ]]; then
  echo "Fetching official source (${REF}) ..."
  curl -L --connect-timeout 30 --max-time 900 \
    -o "$WORK/official.tar.gz" \
    "https://codeload.github.com/TencentCloud/TencentDB-Agent-Memory/tar.gz/refs/heads/${REF}"
  mkdir -p "$OFFICIAL"
  tar -xzf "$WORK/official.tar.gz" -C "$OFFICIAL" --strip-components=1
fi

# Keep the upstream manifest for audit; install only runtime deps.
if [[ ! -f "$OFFICIAL/package.json.upstream" ]]; then
  cp "$OFFICIAL/package.json" "$OFFICIAL/package.json.upstream"
fi
cp "$ROOT/scripts/runtime-package.json" "$OFFICIAL/package.json"

echo "Installing runtime dependencies from $REGISTRY ..."
echo "NOTE: tcvdb-text is ~286 MB unpacked; this can take several minutes."
(
  cd "$OFFICIAL"
  npm_config_fetch_timeout=600000 npm_config_fetch_retries=5 \
    npm install --omit=dev --ignore-scripts --no-audit --no-fund --prefer-offline \
      --registry="$REGISTRY"
)

# Repair package metadata if an interrupted npm extract left dist/ but no package.json.
fix_pkg_metadata() {
  local dir="$1" name="$2" version="$3" json="$4"
  if [[ -d "$dir/dist" && ! -f "$dir/package.json" ]]; then
    echo "WARN: repairing missing package.json in $dir (interrupted install)"
    printf '%s\n' "$json" > "$dir/package.json"
  fi
}
fix_pkg_metadata "$OFFICIAL/node_modules/@tencentdb-agent-memory/tcvdb-text" \
  "@tencentdb-agent-memory/tcvdb-text" "0.1.1" \
  '{"name":"@tencentdb-agent-memory/tcvdb-text","version":"0.1.1","type":"module","main":"dist/index.js","exports":{".":"./dist/index.js"}}'
fix_pkg_metadata "$OFFICIAL/node_modules/js-tiktoken" \
  "js-tiktoken" "1.0.21" \
  '{"name":"js-tiktoken","version":"1.0.21","type":"module","main":"dist/index.cjs","module":"dist/index.js","exports":{".":{"import":"./dist/index.js","require":"./dist/index.cjs"}}}'

TCV="$OFFICIAL/node_modules/@tencentdb-agent-memory/tcvdb-text"
if [[ ! -s "$TCV/data/stopwords.txt" ]]; then
  echo "Fetching stopwords.txt (missing from the partial package) ..."
  curl -L --connect-timeout 30 --max-time 180 \
    -o "$TCV/data/stopwords.txt" \
    "https://unpkg.com/@tencentdb-agent-memory/tcvdb-text@0.1.1/data/stopwords.txt"
fi
if [[ ! -s "$TCV/data/bm25_en_default.json" ]]; then
  echo "ERROR: bm25_en_default.json is missing; reinstall @tencentdb-agent-memory/tcvdb-text." >&2
  exit 1
fi
python3 "$ROOT/scripts/repair_bm25.py" "$TCV/data/bm25_en_default.json"

echo "Verifying runtime imports ..."
(
  cd "$OFFICIAL"
  node --input-type=module -e "
    for (const m of ['ai','@ai-sdk/openai','zod','yaml','undici','js-tiktoken',
                     '@tencentdb-agent-memory/tcvdb-text','sqlite-vec','@node-rs/jieba']) {
      await import(m); console.log('OK', m);
    }"
)
[[ -f "$OFFICIAL/node_modules/tsx/dist/cli.mjs" ]] || { echo "ERROR: tsx missing" >&2; exit 1; }

if ! curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "WARN: Ollama is not running on 127.0.0.1:11434. The test config uses it for embeddings."
  echo "      Start Ollama and run: ollama pull nomic-embed-text"
fi

cat <<EOF

Setup complete.

Next:
  # Option A: existing DeepSeek/OpenAI-compatible LLM (what this test used)
  export TDAI_LLM_BASE_URL=https://api.deepseek.com/v1
  export TDAI_LLM_API_KEY="<your-key-from-env>"     # never commit this
  export TDAI_LLM_MODEL=deepseek-flash

  # Option B: fully local (works, but this Intel Mac is too slow for L1)
  # export TDAI_LLM_BASE_URL=http://127.0.0.1:11434/v1
  # export TDAI_LLM_API_KEY=ollama-local
  # export TDAI_LLM_MODEL=llama3.2

  ./scripts/start_gateway.sh
  python3 scripts/capture_turns.py --session-key session-A-teach \\
    --turns-file samples/session_a_turns.json --wait-records 6
  python3 scripts/run_recall_checks.py --query-set base --label B-new \\
    --out evidence/session_b_recall.json --with-search

Embeddings default to Ollama nomic-embed-text; override TDAI_EMBEDDING_* to change.
EOF
