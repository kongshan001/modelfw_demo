#!/usr/bin/env python3
"""Offline baker for the sigil rule.

rules.json is the single source of truth. This script executes the rule
offline; src/sigil_rules.gd executes the same rule at runtime. Both must
produce byte-identical RGBA data for the same seed.

Run:
    python3 tools/bake_pipeline.py

Outputs:
    assets/generated/sigil_<seed>.png
    assets/generated/manifest.json
"""

import hashlib
import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "generated")

# Deterministic hash comes from the shared portable core (synced by
# portable-core/sync.py); do not re-implement it here.
sys.path.insert(0, os.path.join(ROOT, "tools", "core"))
from portable_core import hash32 as h32  # noqa: E402


def load_rules():
    with open(os.path.join(ROOT, "rules.json"), encoding="utf-8") as f:
        return json.load(f)


def make_sigil(rules, seed):
    size = int(rules["size"])
    pal = {k: tuple(v) for k, v in rules["palette"].items()}
    dia = rules["diamond"]
    rx, ry, frame = int(dia["rx"]), int(dia["ry"]), int(dia["frame"])
    runes = rules["runes"]
    eye = rules["eye"]
    det = rules["details"]
    hw, hh = int(runes["half_w"]), int(runes["half_h"])
    jitter = int(runes["jitter"])
    min_edge = int(runes["min_edge"])
    min_center = int(runes["min_center"])

    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = size - 1
    half = size // 2
    k = 2 * rx * ry

    # rune bars: seeded jitter; skip if too close to the frame or the eye
    bars = []
    for i, off in enumerate(runes["offsets"]):
        ox, oy = int(off[0]), int(off[1])
        h = h32(i, 777, seed)
        bx = half + ox + (h % jitter) - 3
        by = half + oy + ((h >> 8) % jitter) - 3
        d = abs(2 * bx - c) * ry + abs(2 * by - c) * rx
        if k - d <= min_edge or d <= min_center:
            continue
        color = pal["gold"] if i % 2 == 0 else pal["gold_hi"]
        bars.append((bx - hw, by - hh, bx + hw, by + hh, color))

    for y in range(size):
        for x in range(size):
            dx = abs(2 * x - c)
            dy = abs(2 * y - c)
            d = dx * ry + dy * rx
            if d > k:
                continue

            edge = k - d
            h = h32(x, y, seed)

            if edge < 120:
                color = pal["void"]
            elif edge < frame:
                color = pal["gold"]
            elif edge < frame + 70:
                color = pal["gold_hi"]
            else:
                color = pal["stone"]
                if dx * dx + dy * dy > int(det["vignette"]):
                    color = pal["stone_dark"]
                if (h & int(det["dither_hi_mod"])) == 0:
                    color = pal["stone_hi"]
                elif (h & int(det["dither_dark_mod"])) == int(det["dither_dark_eq"]):
                    color = pal["stone_dark"]

            if edge < frame and (h & int(det["chip_mod"])) == 0:
                color = pal["void"]

            if d < int(eye["pupil"]):
                color = pal["void"]
            elif d < int(eye["iris"]):
                color = pal["ember"]
            elif d < int(eye["rim"]):
                color = pal["ember_hi"]
            elif d < int(eye["ring"]):
                color = pal["gold"]

            for x0, y0, x1, y1, rc in bars:
                if x0 <= x < x1 and y0 <= y < y1:
                    color = rc
                    break

            px[x, y] = (color[0], color[1], color[2], 255)

    return img


def main():
    rules = load_rules()
    os.makedirs(OUT, exist_ok=True)
    seeds = sorted(set(int(s) for s in rules["seeds"]) | {int(rules["baked_seed"])})

    assets = {}
    for seed in seeds:
        img = make_sigil(rules, seed)
        name = f"sigil_{seed}.png"
        img.save(os.path.join(OUT, name))
        data = img.tobytes()
        assets[str(seed)] = {
            "file": name,
            "seed": seed,
            "sha256_rgba": hashlib.sha256(data).hexdigest(),
            "bytes": len(data),
        }
        print(f"wrote {name} sha256_rgba={assets[str(seed)]['sha256_rgba'][:16]}…")

    manifest = {
        "rules_version": int(rules["version"]),
        "rule": rules["rule"],
        "size": int(rules["size"]),
        "baked_seed": int(rules["baked_seed"]),
        "seeds": seeds,
        "assets": assets,
    }
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2, sort_keys=True)
    print("wrote manifest.json")


if __name__ == "__main__":
    main()
