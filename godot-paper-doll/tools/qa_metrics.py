#!/usr/bin/env python3
"""T-20261120-011 QA 独立指标复算（不 import 实现者的 measure_paperdoll.py）。

输入（必须由当前 build 的 tools/metric_rig.gd / screenshot_paperdoll.gd 重新生成）：
  docs/metrics/metric_doll.png, stage_only.png, slash.png,
  docs/metrics/sil_00..15.png, dir_00..07.png, random_outfits.json
  docs/shots/01..07.png, docs/shots/showcase/*.png

输出：
  ../docs/qa-review/evidence/metrics-qa.json
  ../docs/qa-review/evidence/{01_studio_25pct,05_lineup_25pct,
     silhouettes_16_black,directions_compass_black,01_face_4x_qa,
     cards_200pct_qa}.png

用法：
  python3 tools/qa_metrics.py
"""
import colorsys
import itertools
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METRICS = os.path.join(ROOT, "docs", "metrics")
SHOTS = os.path.join(ROOT, "docs", "shots")
SHOW = os.path.join(SHOTS, "showcase")
OUT = os.path.abspath(os.path.join(ROOT, "..", "docs", "qa-review", "evidence"))
os.makedirs(OUT, exist_ok=True)

INK = (0x3A, 0x2F, 0x43)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def rel_lum(c):
    r, g, b = lin(np.array(c, dtype=float))
    return float(0.2126 * r + 0.7152 * g + 0.0722 * b)


def wcag(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lstar(c):
    r, g, b = lin(np.array(c, dtype=float))
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    f = y
    fy = f ** (1.0 / 3.0) if f > 0.008856 else 7.787 * f + 16.0 / 116.0
    return 116.0 * fy - 16.0


def load_rgba(name):
    return np.array(Image.open(os.path.join(METRICS, name)).convert("RGBA"))


def mask_alpha(name, thr=128):
    return load_rgba(name)[:, :, 3] > thr


def iou(a, b):
    u = np.logical_or(a, b).sum()
    return float(np.logical_and(a, b).sum()) / float(u) if u else 0.0


def bbox_norm(mask, h=96, canvas_w=200):
    """等比缩放到高 96px（宽按比例、居中、不拉伸），保留宽高比差异。"""
    ys, xs = np.where(mask)
    if not len(xs):
        return np.zeros((h, canvas_w), bool)
    crop = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    ch, cw = crop.shape
    w = max(1, int(round(cw * h / float(ch))))
    r = np.array(Image.fromarray((crop * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR)) > 128
    out = np.zeros((h, canvas_w), bool)
    x0 = max(0, (canvas_w - w) // 2)
    out[:, x0:x0 + min(w, canvas_w)] = r[:, :min(w, canvas_w)]
    return out


def bbox(mask):
    ys, xs = np.where(mask)
    if not len(xs):
        return None
    return [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]


def sim_metrics(masks):
    raw = [iou(a, b) for a, b in itertools.combinations(masks, 2)]
    # 每次归一化都独立于对；实现者脚本也是这么做的。
    nm = []
    for a, b in itertools.combinations(masks, 2):
        nm.append(iou(bbox_norm(a), bbox_norm(b)))
    return {
        "pairs": len(raw),
        "aligned_mean": float(np.mean(raw)),
        "aligned_p90": float(np.percentile(raw, 90)),
        "aligned_max": float(np.max(raw)),
        "normalized_mean": float(np.mean(nm)),
        "normalized_p90": float(np.percentile(nm, 90)),
        "normalized_max": float(np.max(nm)),
    }


def analyse_doll():
    arr = load_rgba("metric_doll.png")
    alpha = arr[:, :, 3]
    opaque = alpha > 240
    op = arr[:, :, :3][opaque].astype(np.float32)
    d = np.sqrt(((op - np.array(INK, dtype=np.float32)) ** 2).sum(axis=1))
    ink = int((d < 40.0).sum())
    bb = bbox(alpha > 16)
    area = (bb[2] - bb[0] + 1) * (bb[3] - bb[1] + 1)
    q = np.round(op / 255.0 * 23.0).astype(np.int16)
    colors = len({tuple(row) for row in q})
    step = max(1, len(op) // 8000)
    char_l = float(np.median([lstar(tuple(p)) for p in op[::step]]))
    stage = np.array(Image.open(os.path.join(METRICS, "stage_only.png")).convert("RGB"))
    stage_med = np.median(stage.reshape(-1, 3), axis=0)
    stage_l = lstar(tuple(stage_med))
    return {
        "bbox": bb,
        "bbox_area": int(area),
        "opaque_px": int(opaque.sum()),
        "ink_pixels": ink,
        "ink_ratio_bbox": float(ink) / float(area),
        "ink_ratio_opaque": float(ink) / float(max(1, int(opaque.sum()))),
        "quantized_colors_24bin": colors,
        "character_median_Lstar": char_l,
        "stage_median_Lstar": stage_l,
        "delta_Lstar": abs(stage_l - char_l),
        "stage_median_hex": "#%02x%02x%02x" % tuple(int(v) for v in stage_med),
    }


def analyse_slash(data):
    arr = np.array(Image.open(os.path.join(METRICS, "slash.png")).convert("RGB"), dtype=np.float32)
    out = {}
    for h in ["#8f3030", "#b23c33", "#ffd27a"]:
        c = np.array(rgb(h), dtype=np.float32)
        count = int((np.sqrt(((arr - c) ** 2).sum(axis=2)) < 60).sum())
        out[h] = {
            "pixels_within_60": count,
            "contrast_vs_stage": round(wcag(rgb(h), rgb(data["stage_median_hex"])), 2),
        }
    return out


def analyse_random():
    samples = json.load(open(os.path.join(METRICS, "random_outfits.json")))
    large = ["shirt", "pants", "cape", "hat", "belt"]
    rows = []
    for outfit in samples:
        hues = []
        high = 0
        for slot in large:
            c = np.array(rgb("#" + outfit[slot]), dtype=np.float32) / 255.0
            mx, mn = float(c.max()), float(c.min())
            sat = 0.0 if mx == 0 else (mx - mn) / mx
            if sat > 0.35 and mx > 0.35:
                high += 1
                h, _, _ = colorsys.rgb_to_hsv(*c)
                hues.append(h * 360.0)
        hues.sort()
        clusters = []
        for h in hues:
            if clusters and h - clusters[-1][-1] < 20:
                clusters[-1].append(h)
            else:
                clusters.append([h])
        hat = np.array(rgb("#" + outfit["hat"]), float) / 255.0
        head = np.array(rgb("#" + outfit["head"]), float) / 255.0
        rows.append({
            "hue_clusters_large_slots": len(clusters),
            "high_sat_large_slots": high,
            "hat_head_l1": float(np.abs(hat - head).sum()),
        })
    return {
        "samples": rows,
        "all_10_hue_clusters_le3": all(r["hue_clusters_large_slots"] <= 3 for r in rows),
        "all_10_hue_clusters_le2": all(r["hue_clusters_large_slots"] <= 2 for r in rows),
        "min_hat_head_l1": min(r["hat_head_l1"] for r in rows),
    }


def make_evidence_images():
    # 25% (320×180)
    for src, dst in [("01_studio", "01_studio_25pct"), ("05_lineup", "05_lineup_25pct")]:
        im = Image.open(os.path.join(SHOTS, src + ".png")).convert("RGB")
        im.resize((320, 180), Image.LANCZOS).save(os.path.join(OUT, dst + ".png"))
    # 4× face crop（与评审同口径：试衣镜角色头部区域）
    studio = Image.open(os.path.join(SHOTS, "01_studio.png")).convert("RGB")
    face = studio.crop((160, 130, 290, 260))
    face.resize((face.width * 4, face.height * 4), Image.NEAREST).save(
        os.path.join(OUT, "01_face_4x_qa.png"))
    # 200% 卡片裁切（阵容右上 2×2 区域）
    cards = studio = Image.open(os.path.join(SHOTS, "05_lineup.png")).convert("RGB")
    crop = cards.crop((730, 88, 1014, 372))
    crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST).save(
        os.path.join(OUT, "cards_200pct_qa.png"))
    # 16 人纯黑剪影 4×4（白底）
    sheet = Image.new("RGB", (4 * 240, 4 * 240), (255, 255, 255))
    for i in range(16):
        sil = Image.open(os.path.join(METRICS, f"sil_{i:02d}.png")).convert("RGBA")
        black = Image.new("RGBA", sil.size, (0, 0, 0, 255))
        black.putalpha(sil.getchannel("A"))
        tile = Image.new("RGB", sil.size, (255, 255, 255))
        tile.paste(black, (0, 0), black)
        sheet.paste(tile, ((i % 4) * 240, (i // 4) * 240))
    sheet.save(os.path.join(OUT, "silhouettes_16_black.png"))
    # 8 向纯黑剪影 3×3 环（方向 3/4/5 上排 … 与罗盘一致）
    comp = Image.new("RGB", (3 * 240, 3 * 240), (255, 255, 255))
    order = [3, 4, 5, 2, None, 6, 1, 0, 7]
    for i, d in enumerate(order):
        if d is None:
            continue
        sil = Image.open(os.path.join(METRICS, f"dir_{d:02d}.png")).convert("RGBA")
        black = Image.new("RGBA", sil.size, (0, 0, 0, 255))
        black.putalpha(sil.getchannel("A"))
        tile = Image.new("RGB", sil.size, (255, 255, 255))
        tile.paste(black, (0, 0), black)
        comp.paste(tile, ((i % 3) * 240, (i // 3) * 240))
    comp.save(os.path.join(OUT, "directions_compass_black.png"))
    # 截图尺寸清单
    sizes = {}
    for name in ["01_studio", "02_wardrobe", "03_actions", "04_directions",
                 "05_lineup", "06_saved", "07_layer"]:
        with Image.open(os.path.join(SHOTS, name + ".png")) as im:
            sizes[name] = list(im.size)
    for name in ["hero", "compass", "poster_16", "hero_layers"]:
        p = os.path.join(SHOW, name + ".png")
        if os.path.exists(p):
            with Image.open(p) as im:
                sizes["showcase/" + name] = list(im.size)
    return sizes


def main():
    doll = analyse_doll()
    sil = sim_metrics([mask_alpha(f"sil_{i:02d}.png") for i in range(16)])
    dirs = [mask_alpha(f"dir_{i:02d}.png") for i in range(8)]
    adjacent = [iou(dirs[i], dirs[(i + 1) % 8]) for i in range(8)]
    adjacent_norm = [iou(bbox_norm(dirs[i]), bbox_norm(dirs[(i + 1) % 8])) for i in range(8)]
    direction = {
        "front_back_iou_aligned": iou(dirs[0], dirs[4]),
        "front_back_iou_normalized": iou(bbox_norm(dirs[0]), bbox_norm(dirs[4])),
        "adjacent_iou_mean_aligned": float(np.mean(adjacent)),
        "adjacent_iou_max_aligned": float(np.max(adjacent)),
        "adjacent_iou_mean_normalized": float(np.mean(adjacent_norm)),
        "adjacent_iou_max_normalized": float(np.max(adjacent_norm)),
        "sil_bbox_sizes": [bbox(dirs[i]) for i in range(8)],
    }
    ui_pairs = {
        "white_fdf7_on_coral_deep_b23c33": ("#fffdf7", "#b23c33"),
        "white_fdf7_on_teal_deep_2f7a6b": ("#fffdf7", "#2f7a6b"),
        "white_fdf7_on_plum_deep_6c5490": ("#fffdf7", "#6c5490"),
        "muted_5f5260_on_paper_f3e7d4": ("#5f5260", "#f3e7d4"),
        "muted_5f5260_on_cream_fff9ee": ("#5f5260", "#fff9ee"),
        "ink_3a2f43_on_paper_f3e7d4": ("#3a2f43", "#f3e7d4"),
        "coral_deep_b23c33_on_panel_fff3df": ("#b23c33", "#fff3df"),
    }
    ui = {k: round(wcag(rgb(a), rgb(b)), 2) for k, (a, b) in ui_pairs.items()}
    report = {
        "doll": doll,
        "lineup_silhouette": sil,
        "direction_silhouette": direction,
        "slash": analyse_slash(doll),
        "ui_contrast": ui,
        "random_color_discipline": analyse_random(),
        "screenshot_sizes": make_evidence_images(),
    }
    with open(os.path.join(OUT, "metrics-qa.json"), "w") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(json.dumps(report, ensure_ascii=False, indent=2))
    print("QA_METRICS_OK ->", os.path.join(OUT, "metrics-qa.json"))


if __name__ == "__main__":
    main()
