#!/usr/bin/env python3
"""纸偶工坊美术指标（评审 §8 验收表，可复现）。

输入：docs/metrics/*.png（由 tools/metric_rig.gd 真实 GPU 渲染）
输出：docs/metrics/summary.json + docs/art-review/after/*.png
"""
import itertools
import json
import os
import shutil

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
METRICS = os.path.join(ROOT, "docs", "metrics")
SHOTS = os.path.join(ROOT, "docs", "shots")
AFTER = os.path.abspath(os.path.join(ROOT, "..", "docs", "art-review", "after"))
BEFORE = os.path.abspath(os.path.join(ROOT, "..", "docs", "art-review", "before"))
os.makedirs(METRICS, exist_ok=True)
os.makedirs(AFTER, exist_ok=True)

INK = (0x3A, 0x2F, 0x43)


def rgb(hexstr):
    h = hexstr.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def srgb_to_linear(c):
    c = c / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def luminance(rgb_tuple):
    r, g, b = [float(v) for v in rgb_tuple]
    rl, gl, bl = srgb_to_linear(np.array([r, g, b]))
    return float(0.2126 * rl + 0.7152 * gl + 0.0722 * bl)


def wcag(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def lstar(rgb_tuple):
    r, g, b = [float(v) for v in rgb_tuple]
    rl, gl, bl = srgb_to_linear(np.array([r, g, b]))
    y = 0.2126 * rl + 0.7152 * gl + 0.0722 * bl
    yn = 1.0
    f = y / yn
    if f > 0.008856:
        fy = f ** (1.0 / 3.0)
    else:
        fy = 7.787 * f + 16.0 / 116.0
    return 116.0 * fy - 16.0


def load_rgba(path):
    return np.array(Image.open(path).convert("RGBA"))


def mask_of(path, threshold=128):
    arr = load_rgba(path)
    return arr[:, :, 3] > threshold


def iou(a, b):
    inter = np.logical_and(a, b).sum()
    union = np.logical_or(a, b).sum()
    return float(inter) / float(union) if union else 0.0


def norm_iou(a, b, size=96):
    """bbox 等比归一（高 96px，宽保持比例，居中）——保留宽/高比差异。"""
    def crop_resize(m):
        ys, xs = np.where(m)
        if len(xs) == 0:
            return np.zeros((size, 160), dtype=bool)
        crop = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        ch, cw = crop.shape
        nw = max(1, int(round(cw * size / float(ch))))
        img = Image.fromarray((crop * 255).astype(np.uint8)).resize((nw, size), Image.BILINEAR)
        r = np.array(img) > 128
        canvas = np.zeros((size, 160), dtype=bool)
        x0 = max(0, (160 - nw) // 2)
        canvas[:, x0:x0 + min(nw, 160)] = r[:, :min(nw, 160)]
        return canvas
    return iou(crop_resize(a), crop_resize(b))


def norm_iou_square(a, b, size=96):
    """bbox 拉伸到正方形（旧口径，保留作对照）。"""
    def crop_resize(m):
        ys, xs = np.where(m)
        if len(xs) == 0:
            return np.zeros((size, size), dtype=bool)
        crop = m[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        img = Image.fromarray((crop * 255).astype(np.uint8))
        img = img.resize((size, size), Image.BILINEAR)
        return np.array(img) > 128
    return iou(crop_resize(a), crop_resize(b))


def analyze_doll():
    arr = load_rgba(os.path.join(METRICS, "metric_doll.png"))
    alpha = arr[:, :, 3]
    opaque = alpha > 240
    ys, xs = np.where(alpha > 16)
    bbox = [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())]
    pix = arr[:, :, :3][opaque].astype(np.float32)
    d = np.sqrt(((pix - np.array(INK, dtype=np.float32)) ** 2).sum(axis=1))
    bbox_area = max((bbox[2] - bbox[0] + 1) * (bbox[3] - bbox[1] + 1), 1)
    ink_count = int((d < 40.0).sum())
    # 评审口径：墨色像素 / 角色包围盒面积（不是不透明像素数）。
    ink_ratio = float(ink_count) / float(bbox_area)
    q = np.round(pix / 255.0 * 23.0).astype(np.int16)
    colors = len({tuple(row) for row in q})
    # 中位 L*（角色）/ 舞台
    med_idx = len(pix) // 2
    lum = np.array([lstar(tuple(p)) for p in pix[:: max(1, len(pix) // 4000)]])
    char_l = float(np.median(lum))
    stage = np.array(Image.open(os.path.join(METRICS, "stage_only.png")).convert("RGB"))
    stage_med = np.median(stage.reshape(-1, 3), axis=0)
    stage_l = lstar(tuple(stage_med))
    return {
        "bbox": bbox,
        "opaque_px": int(opaque.sum()),
        "ink_family_ratio": ink_ratio,
        "ink_family_ratio_opaque": float(ink_count) / float(max(int(opaque.sum()), 1)),
        "ink_pixels": ink_count,
        "quantized_colors_24bin": colors,
        "character_median_Lstar": char_l,
        "stage_median_Lstar": stage_l,
        "delta_Lstar": abs(stage_l - char_l),
    }


def lineup_metric():
    masks = [mask_of(os.path.join(METRICS, f"sil_{i:02d}.png")) for i in range(16)]
    aligned, normalized, square = [], [], []
    for a, b in itertools.combinations(range(16), 2):
        aligned.append(iou(masks[a], masks[b]))
        normalized.append(norm_iou(masks[a], masks[b]))
        square.append(norm_iou_square(masks[a], masks[b]))
    return {
        "pairs": len(aligned),
        "aligned_mean": float(np.mean(aligned)),
        "aligned_p90": float(np.percentile(aligned, 90)),
        "normalized_mean": float(np.mean(normalized)),
        "normalized_p90": float(np.percentile(normalized, 90)),
        "normalized_max": float(np.max(normalized)),
        "square_normalized_mean": float(np.mean(square)),
        "square_normalized_p90": float(np.percentile(square, 90)),
    }


def direction_metric():
    masks = [mask_of(os.path.join(METRICS, f"dir_{i:02d}.png")) for i in range(8)]
    front_back = iou(masks[0], masks[4])
    front_back_norm = norm_iou(masks[0], masks[4])
    adjacent = [iou(masks[i], masks[(i + 1) % 8]) for i in range(8)]
    adjacent_norm = [norm_iou(masks[i], masks[(i + 1) % 8]) for i in range(8)]
    adjacent_square = [norm_iou_square(masks[i], masks[(i + 1) % 8]) for i in range(8)]
    pairs = {}
    for i in range(8):
        for j in range(i + 1, 8):
            pairs[f"{i}-{j}"] = round(norm_iou(masks[i], masks[j]), 3)
    return {
        "front_back_iou": front_back,
        "front_back_iou_normalized": front_back_norm,
        "adjacent_iou_mean": float(np.mean(adjacent)),
        "adjacent_iou_max": float(np.max(adjacent)),
        "adjacent_iou_normalized_mean": float(np.mean(adjacent_norm)),
        "adjacent_iou_normalized_max": float(np.max(adjacent_norm)),
        "adjacent_iou_square_mean": float(np.mean(adjacent_square)),
        "adjacent_iou_square_max": float(np.max(adjacent_square)),
        "front_back_iou_square": norm_iou_square(masks[0], masks[4]),
        "normalized_pairs": pairs,
    }


def slash_metric():
    arr = load_rgba(os.path.join(METRICS, "slash.png"))[:, :, :3].astype(np.float32)
    stage = np.array(Image.open(os.path.join(METRICS, "stage_only.png")).convert("RGB"))
    stage_med = tuple(int(v) for v in np.median(stage.reshape(-1, 3), axis=0))
    colors = ["#8f3030", "#b23c33", "#ffd27a"]
    counts = {}
    for hexc in colors:
        c = np.array(rgb(hexc), dtype=np.float32)
        d = np.sqrt(((arr - c) ** 2).sum(axis=2))
        counts[hexc] = int((d < 60).sum())
    contrasts = {hexc: round(wcag(rgb(hexc), stage_med), 2) for hexc in colors}
    return {
        "stage_median_hex": "#%02x%02x%02x" % stage_med,
        "pixel_counts_within_60": counts,
        "contrast_vs_stage": contrasts,
    }


def ui_contrast():
    pairs = {
        "white_on_coral_deep": ("#fffdf7", "#b23c33"),
        "white_on_teal_deep": ("#fffdf7", "#2f7a6b"),
        "white_on_plum_deep": ("#fffdf7", "#6c5490"),
        "muted_on_panel": ("#5f5260", "#f3e7d4"),
        "muted_on_cream": ("#5f5260", "#fff9ee"),
        "ink_on_paper": ("#3a2f43", "#f3e7d4"),
        "coral_deep_on_panel": ("#b23c33", "#fff3df"),
    }
    return {k: round(wcag(rgb(a), rgb(b)), 2) for k, (a, b) in pairs.items()}


def random_scheme_check():
    path = os.path.join(METRICS, "random_outfits.json")
    samples = json.load(open(path))
    large = ["shirt", "pants", "cape", "hat", "belt"]
    report = []
    for outfit in samples:
        hues = []
        high_sat = 0
        for slot in large:
            c = np.array(rgb("#" + outfit[slot]), dtype=np.float32) / 255.0
            mx, mn = c.max(), c.min()
            sat = 0.0 if mx == 0 else (mx - mn) / mx
            if sat > 0.35 and mx > 0.35:
                high_sat += 1
                import colorsys
                h, _, _ = colorsys.rgb_to_hsv(*c)
                hues.append(round(h * 360.0))
        # 色相簇（相邻 <20° 合并）
        clusters = []
        for h in sorted(hues):
            if clusters and h - clusters[-1][-1] < 20:
                clusters[-1].append(h)
            else:
                clusters.append([h])
        hat = np.array(rgb("#" + outfit["hat"]), dtype=np.float32) / 255.0
        skin = np.array(rgb("#" + outfit["head"]), dtype=np.float32) / 255.0
        hue_clusters = len(clusters)
        report.append({
            "chromatic_hue_clusters": hue_clusters,
            "high_sat_large_slots": high_sat,
            "hat_skin_distance": float(np.abs(hat - skin).sum()),
        })
    ok = all(r["chromatic_hue_clusters"] <= 3 for r in report)
    return {"samples": report, "all_10_within_3_hues": ok}


def make_after_images():
    # 01/02/03/04/05/06/07 复制到验收目录
    for name in ["01_studio", "02_wardrobe", "03_actions", "04_directions",
                 "05_lineup", "06_saved", "07_layer"]:
        src = os.path.join(SHOTS, name + ".png")
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(AFTER, name + ".png"))

    showcase = os.path.join(SHOTS, "showcase")
    for name, target in [
        ("hero", "showcase_hero"), ("hero_layers", "showcase_hero_layers"),
        ("compass", "showcase_compass"), ("poster_16", "showcase_poster_16"),
        ("paperdoll_6s.gif", "showcase_6s"),
    ]:
        src = os.path.join(showcase, name)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(AFTER, target + (".gif" if name.endswith(".gif") else ".png")))

    # 25% 缩略图（320×180）
    for src_name, out_name in [("05_lineup", "05_lineup_25pct"), ("01_studio", "01_studio_25pct")]:
        Image.open(os.path.join(SHOTS, src_name + ".png")).convert("RGB").resize(
            (320, 180), Image.LANCZOS).save(os.path.join(AFTER, out_name + ".png"))
    poster = Image.open(os.path.join(showcase, "poster_16.png")).convert("RGB")
    poster.resize((320, 180), Image.LANCZOS).save(os.path.join(AFTER, "showcase_poster_16_25pct.png"))

    # 4× 裁切（脸部 / 上半身 / 一张阵容卡）
    studio = Image.open(os.path.join(SHOTS, "01_studio.png")).convert("RGB")
    face = studio.crop((160, 130, 290, 260))
    face.resize((face.width * 4, face.height * 4), Image.NEAREST).save(
        os.path.join(AFTER, "01_face_4x.png"))
    body = studio.crop((85, 120, 300, 430))
    body.resize((body.width * 3, body.height * 3), Image.NEAREST).save(
        os.path.join(AFTER, "01_studio_3x.png"))
    card = studio.crop((730, 116, 856, 246))
    card.resize((card.width * 4, card.height * 4), Image.NEAREST).save(
        os.path.join(AFTER, "01_card_4x.png"))

    # 清理旧版中间产物
    for stale in ["showcase_6s.gif.gif", "01_studio_2x.png"]:
        stale_path = os.path.join(AFTER, stale)
        if os.path.exists(stale_path):
            os.remove(stale_path)

    # before / after 叠图（1280 宽，中间 6px 墨线）
    before_path = os.path.join(BEFORE, "01_studio.png")
    after_path = os.path.join(SHOTS, "01_studio.png")
    if os.path.exists(before_path):
        before = Image.open(before_path).convert("RGB")
        after = Image.open(after_path).convert("RGB")
        pair = Image.new("RGB", (1280, 720 * 2 + 6), (0x3a, 0x2f, 0x43))
        pair.paste(before, (0, 0))
        pair.paste(after, (0, 726))
        pair.save(os.path.join(AFTER, "01_before_after.png"))

    # 16 人纯黑剪影接触表（4×4）
    sheet = Image.new("RGB", (4 * 240, 4 * 240), (255, 255, 255))
    for i in range(16):
        sil = Image.open(os.path.join(METRICS, f"sil_{i:02d}.png")).convert("RGBA")
        black = Image.new("RGBA", sil.size, (0, 0, 0, 255))
        black.putalpha(sil.getchannel("A"))
        tile = Image.new("RGB", sil.size, (255, 255, 255))
        tile.paste(black, (0, 0), black)
        sheet.paste(tile, ((i % 4) * 240, (i // 4) * 240))
    sheet.save(os.path.join(AFTER, "silhouettes_16.png"))

    # 8 向剪影罗盘接触表（3×3 环）
    compass = Image.new("RGB", (3 * 240, 3 * 240), (255, 255, 255))
    order = [3, 4, 5, 2, None, 6, 1, 0, 7]
    for idx, d in enumerate(order):
        if d is None:
            continue
        sil = Image.open(os.path.join(METRICS, f"dir_{d:02d}.png")).convert("RGBA")
        black = Image.new("RGBA", sil.size, (0, 0, 0, 255))
        black.putalpha(sil.getchannel("A"))
        tile = Image.new("RGB", sil.size, (255, 255, 255))
        tile.paste(black, (0, 0), black)
        compass.paste(tile, ((idx % 3) * 240, (idx // 3) * 240))
    compass.save(os.path.join(AFTER, "directions_compass_silhouette.png"))
    sheet.resize((320, 320), Image.LANCZOS).save(
        os.path.join(AFTER, "silhouettes_16_25pct.png"))


def main():
    summary = {
        "doll": analyze_doll(),
        "lineup_silhouette": lineup_metric(),
        "direction_silhouette": direction_metric(),
        "slash": slash_metric(),
        "ui_contrast": ui_contrast(),
        "random_color_discipline": random_scheme_check(),
    }
    with open(os.path.join(METRICS, "summary.json"), "w") as f:
        json.dump(summary, f, ensure_ascii=False, indent=2)
    make_after_images()
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
