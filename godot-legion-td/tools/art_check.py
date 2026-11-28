#!/usr/bin/env python3
"""Legionfall art acceptance measurements (T-20261127-020).

Reads the real-GPU screenshots in docs/shots/after and produces a JSON report:
  - overexposure (>245 any channel) per image; hero-Q near-white ratio
  - L* samples for ground / road / enemy / player + delta L*
  - silhouette connected-component pairwise IoU (player row, enemy row)
  - WCAG contrast for the UI palette
  - HUD area from the 1280x720 design rects
  - 25% and grayscale thumbnails for the readability proof

This tool never touches the game at runtime; QA can rerun it on new shots.

Usage:
  python3 tools/art_check.py --shots docs/shots/after --ui scripts/legion_ui.gd \
      --out docs/art_check_after.json
"""
from __future__ import annotations

import argparse
import json
import math
import re
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

# 1280x720 design rects from legion_ui.gd
HUD_AREA_DESIGN = 1280 * 720
HUD_RECTS = {
    "top": (1256, 58),
    "bottom": (1256, 92),
    "minimap": (180, 132),
    "selected": (264, 62),
}
UI_COLORS = {
    "text": "#EFE6D4",
    "muted": "#A9A092",
    "faint": "#8E8779",
    "teal": "#5FE0C0",
    "gold": "#FFC65A",
    "essence": "#C08BFF",
    "danger": "#FF5C74",
    "panel": "#0C1114",
}


def lstar(rgb) -> float:
    r, g, b = [float(c) / 255.0 for c in rgb]
    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    y = 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    return 116.0 * (y ** (1.0 / 3.0)) - 16.0 if y > 0.008856 else 903.3 * y


def hex_rgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def wcag(fg: str, bg: str) -> float:
    def rel(rgb):
        r, g, b = [c / 255.0 for c in rgb]
        def lin(c):
            return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    a, b = rel(hex_rgb(fg)), rel(hex_rgb(bg))
    hi, lo = max(a, b), min(a, b)
    return (hi + 0.05) / (lo + 0.05)


def region(arr: np.ndarray, x0: int, y0: int, x1: int, y1: int) -> np.ndarray:
    h, w = arr.shape[:2]
    x0, x1 = max(0, x0), min(w, x1)
    y0, y1 = max(0, y0), min(h, y1)
    return arr[y0:y1, x0:x1].reshape(-1, 3)


def median_lstar(px: np.ndarray):
    if px.size == 0:
        return None
    med = np.median(px, axis=0).astype(int)
    return {"rgb": med.tolist(), "L": round(lstar(med), 1)}


def overexposure(arr: np.ndarray) -> dict:
    any245 = np.any(arr > 245, axis=2).mean() * 100.0
    any235 = np.any(arr > 235, axis=2).mean() * 100.0
    return {"over245_pct": round(float(any245), 3), "over235_pct": round(float(any235), 3)}


def connected_components(mask: np.ndarray, min_area: int = 25):
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    blobs = []
    for y in range(h):
        for x in range(w):
            if not mask[y, x] or seen[y, x]:
                continue
            q = deque([(x, y)])
            seen[y, x] = True
            xs, ys = [], []
            while q:
                cx, cy = q.popleft()
                xs.append(cx)
                ys.append(cy)
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((nx, ny))
            if len(xs) >= min_area:
                blobs.append((min(xs), min(ys), max(xs) + 1, max(ys) + 1, len(xs)))
    return blobs


def normalized_mask(mask: np.ndarray, bbox, size: int = 64) -> np.ndarray:
    x0, y0, x1, y1, _ = bbox
    crop = mask[y0:y1, x0:x1].astype(np.uint8) * 255
    img = Image.fromarray(crop).resize((size, size), Image.NEAREST)
    return np.asarray(img) > 127


def silhouette_iou(path: Path) -> dict:
    if not path.exists():
        return {"available": False}
    g = np.asarray(Image.open(path).convert("L"))
    h, w = g.shape
    # work at half resolution for speed; the layout is two rows of four
    small = np.asarray(Image.fromarray((g < 70).astype(np.uint8) * 255).resize((w // 2, h // 2), Image.NEAREST)) > 127
    blobs = connected_components(small, min_area=35)
    # drop frame-wide noise
    blobs = [b for b in blobs if (b[2] - b[0]) > 8 and (b[3] - b[1]) > 8]
    blobs.sort(key=lambda b: ((b[1] + b[3]) / 2, (b[0] + b[2]) / 2))
    if len(blobs) < 8:
        return {"available": True, "blob_count": len(blobs), "note": "expected 8 blobs"}
    rows = [[], []]
    cy0 = (blobs[0][1] + blobs[0][3]) / 2
    for b in blobs:
        cy = (b[1] + b[3]) / 2
        rows[0 if abs(cy - cy0) < 40 else 1].append(b)
    result = {"available": True, "rows": []}
    for r_i, row in enumerate(rows):
        row.sort(key=lambda b: (b[0] + b[2]) / 2)
        masks = [normalized_mask(small, b) for b in row]
        pairs = []
        for i in range(len(masks)):
            for j in range(i + 1, len(masks)):
                inter = np.logical_and(masks[i], masks[j]).sum()
                union = np.logical_or(masks[i], masks[j]).sum()
                pairs.append({"a": i, "b": j, "iou": round(float(inter / max(1, union)), 3)})
        result["rows"].append({
            "label": "players" if r_i == 0 else "enemies",
            "count": len(row),
            "bboxes_halfres": [list(map(int, b[:4])) for b in row],
            "pairwise_iou": pairs,
            "max_iou": max([p["iou"] for p in pairs], default=None),
        })
    return result


def ui_font_scan(ui_path: Path) -> dict:
    if not ui_path.exists():
        return {}
    src = ui_path.read_text()
    sizes = []
    # size argument is followed by a color/font expression; this avoids matching coordinates
    for m in re.finditer(r"(?:_text|_text_c)\([^\n]*?,\s*(\d{1,2})\s*,\s*(?:INK|MUTED|FAINT|D\.|Color|col|accent|_font)", src):
        sizes.append(int(m.group(1)))
    for m in re.finditer(r"_res_chip\([^\n]*?", src):
        pass
    sizes += [22, 12]  # _res_chip value/label literals
    hist = {}
    for s in sizes:
        hist[str(s)] = hist.get(str(s), 0) + 1
    return {"size_histogram": dict(sorted(hist.items(), key=lambda kv: int(kv[0]))),
            "min_design_px": min(sizes) if sizes else None}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--shots", default="docs/shots/after")
    ap.add_argument("--ui", default="scripts/legion_ui.gd")
    ap.add_argument("--out", default="docs/art_check_after.json")
    args = ap.parse_args()
    shots = Path(args.shots)
    out = {"tool": "art_check.py", "task": "T-20261127-020", "shots_dir": str(shots)}
    out["overexposure"] = {}
    for p in sorted(shots.glob("*.png")):
        arr = np.asarray(Image.open(p).convert("RGB"))
        out["overexposure"][p.name] = overexposure(arr)

    # L* samples ----------------------------------------------------------
    samples = {}
    battle = shots / "02_battle_1920.png"
    if battle.exists():
        arr = np.asarray(Image.open(battle).convert("RGB"))
        ground = region(arr, 220, 520, 420, 660)
        road = region(arr, 940, 330, 1040, 430)
        samples["ground"] = median_lstar(ground)
        samples["road"] = median_lstar(road)
        # purple enemy pixels inside the play area (exclude HUD/minimap)
        h, w = arr.shape[:2]
        purple_mask = (arr[:, :, 0] > 80) & (arr[:, :, 0] < 235) & (arr[:, :, 1] < 125) & \
                      (arr[:, :, 2] > 100) & (arr[:, :, 2] > arr[:, :, 1] + 20)
        purple_mask[:140] = False
        purple_mask[560:] = False
        purple_mask[:, :560] = False
        purple_mask[:, 1320:] = False
        purple = arr[purple_mask]
        if purple.size:
            lum_p = np.array([lstar(c) for c in purple[:: max(1, purple.shape[0] // 4000)]])
            samples["enemy_body_purple_q75_L"] = round(float(np.percentile(lum_p, 75)), 1)
            samples["enemy_pixels"] = int(purple.shape[0])
        # full enemy bbox top-quartile (body + bone/acid highlights), as in the T-019 method
        small = purple_mask[::2, ::2]
        blobs = connected_components(small, min_area=20)
        blobs = [b for b in blobs if (b[2] - b[0]) > 6 and (b[3] - b[1]) > 6]
        blobs.sort(key=lambda b: -b[4])
        lit = []
        for b in blobs[:12]:
            x0, y0, x1, y1, _ = [v * 2 for v in b]
            pad = 8
            crop = arr[max(0, y0 - pad):min(h, y1 + pad), max(0, x0 - pad):min(w, x1 + pad)].reshape(-1, 3).astype(int)
            if crop.size == 0:
                continue
            bg = np.median(crop, axis=0)
            dist = np.sqrt(((crop - bg) ** 2).sum(axis=1))
            fg = crop[dist > 48]
            if len(fg):
                lit += [lstar(c) for c in fg[:: max(1, len(fg) // 800)]]
        if lit:
            samples["enemy_bbox_q75_L"] = round(float(np.percentile(lit, 75)), 1)
            samples["enemy_bbox_pixels"] = len(lit)
        if samples.get("road") and samples.get("ground"):
            samples["road_minus_ground"] = round(samples["road"]["L"] - samples["ground"]["L"], 1)
        if samples.get("road"):
            if "enemy_body_purple_q75_L" in samples:
                samples["enemy_body_minus_road"] = round(samples["enemy_body_purple_q75_L"] - samples["road"]["L"], 1)
            if "enemy_bbox_q75_L" in samples:
                samples["enemy_bbox_minus_road"] = round(samples["enemy_bbox_q75_L"] - samples["road"]["L"], 1)
        # brief metric: enemies vs ash terrain (not the light stone road)
        if samples.get("ground"):
            if "enemy_body_purple_q75_L" in samples:
                samples["enemy_body_minus_ground"] = round(samples["enemy_body_purple_q75_L"] - samples["ground"]["L"], 1)
            if "enemy_bbox_q75_L" in samples:
                samples["enemy_bbox_minus_ground"] = round(samples["enemy_bbox_q75_L"] - samples["ground"]["L"], 1)
    overview = shots / "01_overview_1920.png"
    if overview.exists():
        arr = np.asarray(Image.open(overview).convert("RGB"))
        bone = region(arr, 800, 380, 1030, 560)
        if bone.size:
            sel = bone[(bone[:, 0] > 120) & (bone[:, 1] > 110) & (bone[:, 2] > 85) &
                       (np.abs(bone[:, 0].astype(int) - bone[:, 2]) < 70)]
            if sel.size:
                lum = np.array([lstar(c) for c in sel[:: max(1, sel.shape[0] // 3000)]])
                samples["player_bone_median_L"] = round(float(np.median(lum)), 1)
        ground2 = region(arr, 300, 500, 450, 620)
        samples["overview_ground"] = median_lstar(ground2)
        if "player_bone_median_L" in samples and samples.get("overview_ground"):
            samples["player_minus_ground"] = round(
                samples["player_bone_median_L"] - samples["overview_ground"]["L"], 1)
    out["lstar"] = samples

    # hero skill near-white ------------------------------------------------
    q = shots / "03_hero_skill_1920.png"
    if q.exists():
        arr = np.asarray(Image.open(q).convert("RGB"))
        crop = arr[250:800, 600:1350]
        out["hero_skill"] = {
            "near_white_pct": round(float(np.any(crop > 235, axis=2).mean() * 100.0), 3),
            "over245_pct": round(float(np.any(crop > 245, axis=2).mean() * 100.0), 3),
        }

    # silhouette ------------------------------------------------------------
    out["silhouette"] = silhouette_iou(shots / "11_silhouette_1920.png")

    # UI --------------------------------------------------------------------
    out["ui"] = {
        "hud_area_pct": round(100.0 * sum(w * h for w, h in HUD_RECTS.values()) / HUD_AREA_DESIGN, 2),
        "hud_rects_design": HUD_RECTS,
        "contrast": {
            k: round(wcag(v, UI_COLORS["panel"]), 2) for k, v in UI_COLORS.items() if k != "panel"
        },
        "fonts": ui_font_scan(Path(args.ui)),
    }

    # 25% + grayscale proof ------------------------------------------------
    if battle.exists():
        img = Image.open(battle)
        thumb = img.resize((480, 270), Image.LANCZOS)
        thumb.save(shots / "14_25pct.png")
        thumb.convert("L").save(shots / "14_25pct_gray.png")
        out["thumbnails"] = ["14_25pct.png", "14_25pct_gray.png"]

    Path(args.out).write_text(json.dumps(out, ensure_ascii=False, indent=2))
    print(json.dumps(out, ensure_ascii=False, indent=2))
    print("ART_CHECK_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
