#!/usr/bin/env bash
# End-to-end check: static server -> real Chrome GPU -> 1280x720 shots -> MP4/GIF.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
PORT="${PORT:-8145}"
HTTP_LOG="${TMPDIR:-/tmp}/waterpro-verify-http.log"

command -v node >/dev/null || { echo "node is required"; exit 2; }
command -v python3 >/dev/null || { echo "python3 is required"; exit 2; }
command -v ffmpeg >/dev/null || { echo "ffmpeg is required"; exit 2; }
command -v ffprobe >/dev/null || { echo "ffprobe is required"; exit 2; }

if [ -z "${PLAYWRIGHT_MODULE:-}" ]; then
  for candidate in \
    "${HOME:-}/node_modules/playwright" \
    "$REPO/node_modules/playwright" \
    "$ROOT/node_modules/playwright"; do
    if [ -d "$candidate" ]; then export PLAYWRIGHT_MODULE="$candidate"; break; fi
  done
fi
if [ -z "${PLAYWRIGHT_MODULE:-}" ]; then
  echo "Playwright not found. Run: npm i playwright  (or set PLAYWRIGHT_MODULE)"
  exit 2
fi

SERVER_PID=""
cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

if curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then
  echo "Using existing server on port ${PORT}"
else
  python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$ROOT" >"$HTTP_LOG" 2>&1 &
  SERVER_PID=$!
  ready=0
  for _ in $(seq 1 80); do
    if curl -fsS "http://127.0.0.1:${PORT}/" >/dev/null 2>&1; then ready=1; break; fi
    sleep 0.1
  done
  if [ "$ready" != "1" ]; then
    echo "HTTP server did not start; see $HTTP_LOG"
    exit 3
  fi
fi

set +e
DEMO_URL="http://127.0.0.1:${PORT}/" node "$ROOT/tools/capture.cjs"
STATUS=$?
set -e

echo
echo "— artifact checks —"
python3 - "$REPO" <<'PY'
import json, subprocess, sys, os
repo = sys.argv[1]
report_path = os.path.join(repo, 'docs', 'waterpro-clouds-verification.json')
failures = []
try:
    report = json.load(open(report_path))
except Exception as exc:
    print('report missing:', exc)
    sys.exit(1)

for shot in report.get('screenshots', []):
    if shot.get('width') != 1280 or shot.get('height') != 720:
        failures.append(f"{shot.get('file')} is {shot.get('width')}x{shot.get('height')}")
expected = {'mp4': '1280,720', 'gif': '960,540'}
for key in ('mp4', 'gif'):
    info = report.get('video', {}).get(key)
    if not info:
        failures.append(f"{key} missing")
        continue
    path = os.path.join(repo, info['file'])
    if not os.path.exists(path) or os.path.getsize(path) < 10000:
        failures.append(f"{key} too small or missing")
    duration = info.get('duration') or 0
    if not (6 <= duration <= 10.5):
        failures.append(f"{key} duration {duration:.2f}s outside 6-10s")
    probe = subprocess.run(
        ['ffprobe', '-v', 'error', '-select_streams', 'v:0',
         '-show_entries', 'stream=width,height', '-of', 'csv=p=0', path],
        capture_output=True, text=True)
    dims = probe.stdout.strip()
    print(f"{key}: {dims} {duration:.2f}s {os.path.getsize(path)//1024} KiB")
    if dims != expected[key]:
        failures.append(f"{key} dimensions {dims} != {expected[key]}")

fps = [v.get('fps', 0) for v in report.get('presets', {}).values()]
print('fps:', fps)
if any(f < 30 for f in fps):
    failures.append(f"FPS below 30: {fps}")
print('console errors:', len(report.get('consoleErrors', [])))
print('page errors:', len(report.get('pageErrors', [])))
print('external requests:', len(report.get('externalRequests', [])))
print('gpu:', report.get('gpuProbe', {}).get('renderer'))
if report.get('gpuFallback'):
    print('gpu fallback:', report['gpuFallback'])
if report.get('consoleErrors') or report.get('pageErrors'):
    failures.append('console/page errors present')
if report.get('externalRequests'):
    failures.append('external requests present')
if report.get('failures'):
    failures.extend(report['failures'])
if failures:
    print('FAILURES:')
    for item in failures:
        print(' -', item)
    sys.exit(1)
print('ARTIFACTS OK')
PY
ARTIFACTS=$?
if [ "$STATUS" != "0" ] || [ "$ARTIFACTS" != "0" ]; then
  echo "VERIFY: FAIL"
  exit 1
fi
echo "VERIFY: PASS"
