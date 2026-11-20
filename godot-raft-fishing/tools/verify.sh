#!/usr/bin/env bash
# 一键验收：导入、无头启动（0 SCRIPT ERROR）、smoke、产物检查。
# 可选：CAPTURE=1 重跑截图/GIF/MP4；PERF=1 跑真实 GPU 性能；INPUT=1 跑真实输入接线。
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v godot >/dev/null 2>&1; then
  echo "godot not found in PATH" >&2
  exit 1
fi

LOG_DIR="$(mktemp -d)"
trap 'rm -rf "$LOG_DIR"' EXIT

echo "== import =="
godot --headless --path . --editor --quit > "$LOG_DIR/import.log" 2>&1
if grep -qE "SCRIPT ERROR|Parse Error|ERROR:" "$LOG_DIR/import.log"; then
  cat "$LOG_DIR/import.log"
  echo "IMPORT_FAILED" >&2
  exit 1
fi

echo "== boot =="
godot --headless --path . --quit-after 400 > "$LOG_DIR/boot.log" 2>&1
if grep -qE "SCRIPT ERROR|ERROR:" "$LOG_DIR/boot.log"; then
  cat "$LOG_DIR/boot.log"
  echo "BOOT_FAILED" >&2
  exit 1
fi
tail -3 "$LOG_DIR/boot.log"

echo "== smoke =="
godot --headless --path . -s tools/smoke_raft.gd 2>&1 | tee "$LOG_DIR/smoke.log"
if ! grep -q "RAFT_SMOKE_OK" "$LOG_DIR/smoke.log"; then
  echo "SMOKE_FAILED" >&2
  exit 1
fi
if grep -q "SCRIPT ERROR" "$LOG_DIR/smoke.log"; then
  cat "$LOG_DIR/smoke.log"
  echo "SMOKE_SCRIPT_ERROR" >&2
  exit 1
fi

echo "== artifacts =="
python3 - <<'PY'
import glob, struct, sys
shots = sorted(glob.glob("docs/shots/*.png"))
if len(shots) < 5:
    sys.exit(f"need >=5 screenshots in docs/shots, found {len(shots)}")
for path in shots:
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n":
        sys.exit(f"not a PNG: {path}")
    w, h = struct.unpack(">II", head[16:24])
    if (w, h) != (1280, 720):
        sys.exit(f"{path} is {w}x{h}, expected 1280x720")
print(f"screenshots={len(shots)} all 1280x720")
PY
for f in docs/driftwood_cove.gif docs/driftwood_cove.mp4; do
  if [ ! -s "$f" ]; then
    echo "missing $f" >&2
    exit 1
  fi
done
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 docs/driftwood_cove.mp4 2>/dev/null || echo "?")
echo "gif=$(du -h docs/driftwood_cove.gif | cut -f1) mp4=$(du -h docs/driftwood_cove.mp4 | cut -f1) duration=${DUR}s"

if [ "${CAPTURE:-0}" = "1" ]; then
  echo "== capture (real GPU) =="
  godot --path . --resolution 1280x720 -s tools/screenshot_raft.gd
  rm -rf /tmp/driftwood_frames
  godot --path . --resolution 1280x720 -s tools/capture_raft_gif.gd
  ffmpeg -y -loglevel error -framerate 15 -i /tmp/driftwood_frames/frame_%03d.png \
    -vf "scale=640:360:flags=neighbor,split[a][b];[a]palettegen=max_colors=160:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3" \
    -loop 0 docs/driftwood_cove.gif
  ffmpeg -y -loglevel error -framerate 15 -i /tmp/driftwood_frames/frame_%03d.png \
    -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart \
    docs/driftwood_cove.mp4
fi

if [ "${PERF:-0}" = "1" ]; then
  echo "== perf (real GPU) =="
  godot --path . --resolution 1280x720 -s tools/perf_raft.gd
fi

if [ "${INPUT:-0}" = "1" ]; then
  echo "== input (window required) =="
  godot --path . --resolution 1280x720 -s tools/input_raft.gd
fi

echo "RAFT_VERIFY_OK"
