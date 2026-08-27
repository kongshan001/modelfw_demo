---
name: video-digest
description: Use when the user shares a video link (bilibili / b23.tv short link / BV id, or any yt-dlp-supported URL) and wants it 解析/总结/截图/提取关键帧/OCR 内容 — including "处理这个视频"、"继续处理" with a link. Turns a video into scene-change key frames plus OCR text, so it works even when the session cannot view images.
---

# Video Digest

## Overview
Turn a shared video URL into: local mp4 + metadata + scene-change key frames + OCR text of every frame. Claude reads the OCR text (ground truth), picks frames, sends them via cc-connect, and summarizes. No vision capability required — macOS Vision (Swift) OCR substitutes for reading images.

## When to Use
- User shares a bilibili video (b23.tv short link / BV id / full URL) and asks to process, summarize, screenshot, or extract key frames
- Any video where frames carry information (slides, talking-head with text) needs content-level summary

## Quick Reference
| Step | Command |
|---|---|
| Run pipeline | `bash .claude/skills/video-digest/scripts/video_digest.sh <url>` |
| Flags | `--workdir DIR` · `--format FMT` · `--keep` (reuse video) · `--no-ocr` |
| Outputs | `video.mp4` · `metadata.json` · `scenes.raw` (float secs) · `key/k_MM_SS.jpg` · `ocr.txt` |

## Implementation
`scripts/video_digest.sh <url>`: resolve short link (curl -L) → metadata via api.bilibili.com → ensure yt-dlp (pip may be broken → direct wheel download) → download (yt-dlp best H.264 video-only: 30080→30064→30032→b; **auto-falls back to curl playurl API** if yt-dlp fails) → ffmpeg scene detection (threshold 0.15) → extract key frames → OCR via `scripts/ocr.swift` (Swift + Vision, zh-Hans + en-US, offline).

### Download fallback: python TLS block
Symptom: `curl` to bilibili works in 0.1s but `python3 -m yt_dlp` / `python-requests` hang with "Read timed out" — bilibili or the ISP middlebox blocks python's OpenSSL TLS fingerprint (can appear/disappear day to day; earlier runs succeed, later runs hang). curl (SecureTransport) passes. The script detects yt-dlp failure and falls back to `api.bilibili.com/x/player/playurl` (needs bvid+cid, `Referer: https://www.bilibili.com/`; qn=80→64) with curl. Trade-off: fallback caps at 480p (qn=64) / sometimes 1080p (qn=80) vs yt-dlp's 1080x1440.
`--impersonate chrome` would fix the fingerprint, but curl_cffi ≥0.16 wheels fail to dlopen on macOS 12 (`_SCDynamicStoreCopyProxies` symbol) — only worth it on macOS 13+.

## After the Script
1. Read `ocr.txt` + `metadata.json` — OCR text is the ground truth for frame content; never invent what a frame shows
2. Send chosen frames: `cc-connect send --image <abs path> --image ...` (repeat per frame), short message
3. Summarize with a per-frame table (timestamp → content)
4. If a shareable summary is asked, also give a ≤100字 one-liner version
5. If Read on a frame returns "Unsupported Image" — that's a vision-less session; rely on `ocr.txt`, don't retry reading images

## Common Mistakes
| Symptom | Fix |
|---|---|
| Scene detection prints nothing | `-v error` silences showinfo (info level) — use `-hide_banner` only |
| `for t in $TS` in zsh skips/merges frames | zsh doesn't word-split unquoted vars — use `while read` (script already does) |
| pip install yt-dlp: "No matching distribution found" | mirrors reachable but pip broken — curl the wheel from files.pythonhosted.org, keep exact wheel filename, `pip install --no-index --find-links` (script auto-falls-back) |
| yt-dlp "not a valid URL" for bare BV id | use full `https://www.bilibili.com/video/<BV>` (script handles) |
| "Requested format is not available" | story/vertical videos have no muxed formats — list `-F`, pick numeric H.264: 30016/30032/30064/30080 (script auto-falls-back) |
| WebFetch on b23.tv fails | use curl `-L` to resolve the short link (script handles) |
| Download crawls at ~80KB/s | normal on weak networks — let it finish, don't kill |
| yt-dlp hangs "Read timed out" while curl works | python TLS fingerprint blocked (bilibili/ISP) — script auto-falls back to curl playurl; see Implementation |
| pip install wheel: "not a valid wheel filename" | pip requires the exact wheel filename — never rename to short names (script handles) |

## Notes
- Vertical "story" videos: 30016 (360x480) → 30032 (480x640) → 30064 (720x960) → 30080 (1080x1440), all H.264
- Script is idempotent-ish: `--keep` reuses an existing `video.mp4` in the workdir
