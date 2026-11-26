#!/usr/bin/env python3
"""Audit the Action Forge built-in animation library (no browser needed).

Fetches the public library manifest the web app loads, prints actual counts,
per-category breakdown and root-motion flags, and optionally samples preview
videos into /tmp for visual review. The test report's "250+" claim is checked
against this manifest/UI count.

Usage:
    python3 action-forge-test/scripts/af_library_audit.py
    python3 action-forge-test/scripts/af_library_audit.py --previews walk_loop sword_regular_combo
"""
import argparse, collections, json, os, subprocess, urllib.request

BASE = "https://actionforge.app/assets/animation-library/"
MANIFEST = BASE + "manifests/library.json"

def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--previews", nargs="*", default=[], help="clip ids to download as webm previews")
    ap.add_argument("--out", default="/tmp/af_library_audit")
    ap.add_argument("--manifest", default=None, help="use a previously downloaded library.json (offline)")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    if args.manifest:
        raw = open(args.manifest, "rb").read()
    else:
        proc = subprocess.run(["curl", "-sL", "-m", "180", "--retry", "2", "-A", "Mozilla/5.0", MANIFEST],
                              capture_output=True)
        raw = proc.stdout
        if proc.returncode != 0 or len(raw) < 5000:
            raise SystemExit(f"manifest fetch failed rc={proc.returncode} bytes={len(raw)}; retry or pass --manifest")
    lib = json.loads(raw)
    clips = lib["clips"]
    print(f"manifest generatedAt={lib.get('generatedAt')} schema={lib.get('schemaVersion')}")
    print(f"clips_total={len(clips)} human_rig={sum(1 for c in clips.values() if c.get('rig') == 'human')} fps_rig={sum(1 for c in clips.values() if c.get('rig') == 'fps')}")
    cats = collections.Counter(c.get("category") or "(none)" for c in clips.values())
    print("categories=" + ", ".join(f"{k}:{v}" for k, v in sorted(cats.items(), key=lambda kv: -kv[1])))
    loops = collections.Counter(bool(c.get("loops")) for c in clips.values())
    root = [cid for cid, c in clips.items() if c.get("rootMotion")]
    print(f"loops_true={loops[True]} loops_false={loops[False]} root_motion_clips={len(root)}")
    print("root_motion=" + ", ".join(f"{cid}({clips[cid].get('rootDistance', 0):.2f}m)" for cid in root))
    zero = [cid for cid, c in clips.items() if not c.get("duration")]
    print("zero_duration_pose_clips=" + ", ".join(zero))
    for cid in args.previews:
        c = clips.get(cid)
        if not c:
            print("MISSING", cid)
            continue
        url = BASE + c["preview"]
        out = os.path.join(args.out, cid + ".webm")
        subprocess.run(["curl", "-sL", "-m", "60", url, "-o", out], check=False)
        print("PREVIEW", cid, c.get("category"), c.get("duration"), os.path.getsize(out))

if __name__ == "__main__":
    main()
