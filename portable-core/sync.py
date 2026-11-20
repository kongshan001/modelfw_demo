#!/usr/bin/env python3
"""Vendor the portable core into engine projects.

portable-core/ is the single source of truth. Engine projects get byte-identical
copies so they stay self-contained (res:// paths, no symlinks).

Usage:
    python3 portable-core/sync.py           # copy into targets
    python3 portable-core/sync.py --check   # fail if any target is stale
"""

import argparse
import filecmp
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(ROOT)

TARGETS = [
    ("impl/gdscript/portable_core.gd", "godot-iso-slice/src/core/portable_core.gd"),
    ("impl/python/portable_core.py", "godot-iso-slice/tools/core/portable_core.py"),
    ("spec/golden.json", "godot-iso-slice/tests/portable_golden.json"),
]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report drift only")
    args = parser.parse_args()

    stale = []
    for src_rel, dst_rel in TARGETS:
        src = os.path.join(ROOT, src_rel)
        dst = os.path.join(REPO, dst_rel)
        if args.check:
            if not os.path.exists(dst) or not filecmp.cmp(src, dst, shallow=False):
                stale.append(dst_rel)
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copyfile(src, dst)
        print(f"synced {dst_rel}")

    if args.check:
        if stale:
            for rel in stale:
                print(f"STALE: {rel} (run python3 portable-core/sync.py)", file=sys.stderr)
            return 1
        print("PORTABLE_SYNC_OK")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
