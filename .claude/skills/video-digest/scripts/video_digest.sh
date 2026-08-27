#!/bin/bash
# video_digest.sh — video URL → metadata + scene-change key frames + OCR text
#
# Pipeline (all verified on bilibili story/vertical videos):
#   resolve short link → api.bilibili.com metadata → yt-dlp download
#   → ffmpeg scene detection → key frame extraction → Vision OCR
#
# Usage: video_digest.sh <url|b23.tv shortlink|BV id> [--workdir DIR] [--format FMT] [--keep] [--no-ocr]
# Outputs in <workdir> (default /tmp/video_digest/<BV>):
#   video.mp4  metadata.json  scenes.raw (float seconds)  key/k_MM_SS.jpg  ocr.txt
set -uo pipefail

URL="${1:-}"
if [ -z "$URL" ]; then
  echo "usage: $0 <url|shortlink|BVid> [--workdir DIR] [--format FMT] [--keep] [--no-ocr]"
  exit 1
fi
shift

WORKDIR="" FMT="" KEEP=0 OCR=1
while [ $# -gt 0 ]; do
  case "$1" in
    --workdir) WORKDIR="$2"; shift 2;;
    --format)  FMT="$2"; shift 2;;
    --keep)    KEEP=1; shift;;
    --no-ocr)  OCR=0; shift;;
    *) shift;;
  esac
done

UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

# ---- 1. resolve short link / normalize URL ----
case "$URL" in
  *b23.tv*) RESOLVED=$(curl -s -o /dev/null -w "%{url_effective}" -L --max-redirs 5 "$URL" -A "$UA") ;;
  *) RESOLVED="$URL" ;;
esac
BV=$(echo "$RESOLVED" | grep -oE "BV[0-9A-Za-z]+" | head -1)
[ -z "$BV" ] && { echo "ERROR: cannot extract BV id from $RESOLVED"; exit 1; }

[ -z "$WORKDIR" ] && WORKDIR="/tmp/video_digest/$BV"
mkdir -p "$WORKDIR/key"

# ---- 2. metadata ----
curl -s "https://api.bilibili.com/x/web-interface/view?bvid=$BV" -A "$UA" -H "Referer: https://www.bilibili.com/" > "$WORKDIR/metadata.json"
python3 - "$WORKDIR/metadata.json" <<'PYEOF'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("code") != 0:
    print(f"API ERROR {d['code']}: {d.get('message')}"); sys.exit(1)
v = d["data"]
print(f"TITLE: {v['title']}")
print(f"UP: {v['owner']['name']}  DURATION: {v['duration']}s  CID: {v['pages'][0]['cid']}")
PYEOF
[ $? -ne 0 ] && exit 1

# ---- 3. ensure yt-dlp (pip may be broken; fall back to direct wheel download) ----
if ! python3 -m yt_dlp --version >/dev/null 2>&1; then
  echo "[*] yt-dlp missing — downloading wheel directly (pip index may be broken)..."
  WHEEL_URL=$(curl -s --max-time 20 "https://pypi.org/simple/yt-dlp/" \
    | grep -oE 'href="[^"]*\.whl[^"]*"' \
    | grep -vE "dev0|arm|musllinux|win_|win-|macosx|manylinux.*i686|py2" \
    | tail -1 | sed -E 's/^href="([^"#]*).*/\1/')
  [ -z "$WHEEL_URL" ] && { echo "ERROR: cannot find yt-dlp wheel on pypi"; exit 1; }
  FN=$(basename "${WHEEL_URL%%#*}")
  curl -sL --max-time 120 -o "/tmp/$FN" "$WHEEL_URL"
  python3 -m pip install -q --no-index --find-links=/tmp "/tmp/$FN"
  python3 -m yt_dlp --version >/dev/null 2>&1 || { echo "ERROR: yt-dlp install failed"; exit 1; }
fi

# ---- 4. download ----
# Primary: yt-dlp (best quality). Fallback: curl direct playurl (works when
# python's TLS is blocked/middleboxed — python-requests hangs, curl succeeds).
VID="$WORKDIR/video.mp4"
if [ "$KEEP" = 1 ] && [ -f "$VID" ]; then
  echo "[*] reuse existing $VID"
else
  dl_ytdlp() { python3 -m yt_dlp -f "$1" --no-playlist --socket-timeout 60 --retries 3 -o "$VID" "https://www.bilibili.com/video/$BV" >/dev/null 2>&1; }
  OK=0
  rm -f "$VID"
  if [ -n "$FMT" ]; then
    echo "[*] yt-dlp format $FMT ..."; dl_ytdlp "$FMT" && OK=1
  else
    for f in 30080 30064 30032 b; do
      echo "[*] yt-dlp format $f ..."; dl_ytdlp "$f" && { OK=1; break; }
    done
  fi
  if [ "$OK" = 0 ]; then
    echo "[*] yt-dlp failed — falling back to curl playurl (480p-1080p)..."
    CID=$(python3 -c "import json;print(json.load(open('$WORKDIR/metadata.json'))['data']['pages'][0]['cid'])")
    for QN in 80 64; do
      STREAM=$(curl -s --max-time 20 "https://api.bilibili.com/x/player/playurl?bvid=$BV&cid=$CID&qn=$QN&type=mp4" -A "$UA" -H "Referer: https://www.bilibili.com/" \
        | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('durl',[{}])[0].get('url',''))")
      [ -z "$STREAM" ] && continue
      curl -sL --max-time 900 -o "$VID" "$STREAM" -A "$UA" -H "Referer: https://www.bilibili.com/" && [ -s "$VID" ] && { OK=1; echo "[*] curl fallback ok (qn=$QN)"; break; }
    done
  fi
  [ "$OK" = 1 ] || { echo "ERROR: download failed"; exit 1; }
fi

# ---- 5. scene detection (NOTE: never use -v error here — it silences showinfo) ----
ffmpeg -hide_banner -i "$VID" -vf "select='gt(scene,0.15)',showinfo" -vsync vfr -f null - 2>&1 \
  | grep -oE "pts_time:[0-9.]+" | cut -d: -f2 > "$WORKDIR/scenes.raw"
NSCENES=$(grep -c . "$WORKDIR/scenes.raw" || true)
echo "[*] $NSCENES scene changes detected"

# ---- 6. extract key frames (while-read: zsh/bash `for` does not word-split) ----
N=0
while read -r ts; do
  [ -z "$ts" ] && continue
  N=$((N+1))
  label=$(awk -v t="$ts" 'BEGIN{s=int(t); printf "%02d_%02d", s/60, s%60}')
  ffmpeg -y -v error -ss "$ts" -i "$VID" -frames:v 1 -q:v 3 "$WORKDIR/key/k_${label}.jpg"
done < "$WORKDIR/scenes.raw"
echo "[*] extracted $N key frames"

# ---- 7. OCR (macOS Vision, offline, zh-Hans + en-US) ----
if [ "$OCR" = 1 ] && [ -x /usr/bin/swift ]; then
  SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
  swift "$SCRIPT_DIR/ocr.swift" "$WORKDIR/key" "$WORKDIR/ocr.txt" 2>/dev/null
  echo "[*] OCR done -> $WORKDIR/ocr.txt"
fi

echo "=========================================="
echo "DONE. workdir: $WORKDIR"
echo "  metadata: $WORKDIR/metadata.json   scenes: $WORKDIR/scenes.raw"
echo "  frames:   $WORKDIR/key/   OCR text: $WORKDIR/ocr.txt"
