#!/usr/bin/env python3
"""T-20261121-007 · G1 材质 / G5 舞台光照 / VFX 自测（before/after 同机位）。

输入（由 tools/material_vfx_rig.gd 生成）：
  docs/shots/material-vfx/{before,after}/<slug>_{studio_1280,hero_1920,transparent}.png
  docs/shots/material-vfx/{before,after}/stage_1280.png
  docs/shots/material-vfx/after/slash_impact_640.png + slash_meta.json
  docs/shots/material-vfx/after/slash_frames/frame_*.png

输出：
  docs/shots/material-vfx/metrics.json
  docs/shots/material-vfx/{before,after}/*_25pct.png
  docs/shots/material-vfx/compare_studio_*.png / compare_hero_*.png
  docs/shots/material-vfx/slash_before_after.png

口径：
  - 墨色族：alpha>240，RGB 到 #3a2f43 的 L1 距离 <40，除以 alpha>240 的 bbox 面积（R2 同口径）。
  - L* 分箱：CIELAB L*，2 L* 一箱，占比 >0.3% 计入（评审 §3 同口径）。
  - 舞台 ΔL*：角色 median L* vs stage_only median L*（QA 同口径）。
  - 斩击 ROI：核心色 #8f5f1f 的掩膜；对比度 = WCAG(核心, ROI 背景中位色)。
"""
import json
import os

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "shots", "material-vfx")
CHARS = [("moss_knight", "苔藓骑士"), ("ember_mage", "余烬法师"), ("cloud_baker", "云朵面包师")]
INK = np.array([0x3A, 0x2F, 0x43])
CORE = (0x8F, 0x5F, 0x1F)
EDGE = (0x8F, 0x30, 0x30)


def load(path, mode="RGB"):
    return np.array(Image.open(path).convert(mode))


def srgb_to_linear(c):
    c = np.asarray(c, dtype=float) / 255.0
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def lstar(rgb):
    lin = srgb_to_linear(rgb)
    y = lin[..., 0] * 0.2126729 + lin[..., 1] * 0.7151522 + lin[..., 2] * 0.0721750
    return 116.0 * np.where(y > 0.008856, np.cbrt(y), 7.787 * y + 16.0 / 116.0) - 16.0


def wcag(a, b):
    la = float(lstar(np.array(a, dtype=float)))
    lb = float(lstar(np.array(b, dtype=float)))
    ya = float(0.2126729 * srgb_to_linear([a[0]])[0] + 0.7151522 * srgb_to_linear([a[1]])[0]
               + 0.0721750 * srgb_to_linear([a[2]])[0])
    yb = float(0.2126729 * srgb_to_linear([b[0]])[0] + 0.7151522 * srgb_to_linear([b[1]])[0]
               + 0.0721750 * srgb_to_linear([b[2]])[0])
    hi, lo = max(ya, yb), min(ya, yb)
    return (hi + 0.05) / (lo + 0.05)


def rgb_hex(c):
    return "#%02x%02x%02x" % tuple(int(v) for v in c)


def ink_ratio(path):
    im = load(path, "RGBA")
    alpha = im[..., 3]
    mask = alpha > 240
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return {}
    bbox = (int(ys.max() - ys.min() + 1), int(xs.max() - xs.min() + 1))
    dist = np.abs(im[..., :3].astype(int) - INK).sum(axis=2)
    ink = (dist < 40) & mask
    return {
        "ink_px": int(ink.sum()),
        "opaque_px": int(mask.sum()),
        "bbox": [bbox[0], bbox[1]],
        "ink_ratio_bbox": round(float(ink.sum()) / float(bbox[0] * bbox[1]) * 100.0, 2),
        "ink_ratio_opaque": round(float(ink.sum()) / float(max(mask.sum(), 1)) * 100.0, 2),
    }


def char_meta(transparent_path):
    im = load(transparent_path, "RGBA")
    mask = im[..., 3] > 240
    ys, xs = np.where(mask)
    return {
        "bbox": [int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())],
        "median_L": round(float(np.median(lstar(im[..., :3][mask].astype(float)))), 1),
        "pixels": im[..., :3][mask],
    }


def l_bins(pixels, threshold=0.003):
    l = lstar(pixels.astype(float))
    h, _ = np.histogram(l, bins=np.arange(0, 102, 2))
    return {
        "bins": int((h / max(len(l), 1) > threshold).sum()),
        "span": round(float(np.percentile(l, 90) - np.percentile(l, 10)), 1),
        "median": round(float(np.median(l)), 1),
    }


def hue_of(pixels):
    rgb = pixels.astype(float) / 255.0
    mx = rgb.max(axis=1)
    mn = rgb.min(axis=1)
    d = mx - mn
    h = np.zeros(len(rgb))
    nz = d > 1e-6
    r, g, b = rgb[:, 0], rgb[:, 1], rgb[:, 2]
    idx = nz & (mx == r)
    h[idx] = (60.0 * ((g[idx] - b[idx]) / d[idx]) + 360.0) % 360.0
    idx = nz & (mx == g)
    h[idx] = 60.0 * ((b[idx] - r[idx]) / d[idx]) + 120.0
    idx = nz & (mx == b)
    h[idx] = 60.0 * ((r[idx] - g[idx]) / d[idx]) + 240.0
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return h, s


def shadow_hue(pixels):
    """绿/青布料的亮暗主簇色相差（按饱和度加权）。"""
    h, s = hue_of(pixels)
    l = lstar(pixels.astype(float))
    ok = (s > 0.18) & (h > 110.0) & (h < 210.0)
    if ok.sum() < 50:
        return None
    hh, ss, ll = h[ok], s[ok], l[ok]
    # 暗部主簇 = L* 最低 10%；亮部主簇 = L* 最高 10%（与评审“亮/暗主簇色相差”同口径）。
    lo = ll <= np.percentile(ll, 10)
    hi = ll >= np.percentile(ll, 90)
    def circ_mean(hs, ws):
        a = np.deg2rad(hs)
        z = np.arctan2((np.sin(a) * ws).sum(), (np.cos(a) * ws).sum())
        return float(np.rad2deg(z)) % 360.0
    light_h = circ_mean(hh[hi], ss[hi])
    dark_h = circ_mean(hh[lo], ss[lo])
    delta = (dark_h - light_h + 180.0) % 360.0 - 180.0
    return {
        "light_hue_p90": round(light_h, 1),
        "dark_hue_p10": round(dark_h, 1),
        "delta_deg": round(delta, 1),
        "samples": int(ok.sum()),
    }


def stage_metrics(phase, meta):
    stage = load(os.path.join(OUT, phase, "stage_1280.png"))
    stage_l = float(np.median(lstar(stage.astype(float))))
    char_l = meta["median_L"]
    # 纸纹理：左上空白区的 L* 高频标准差（1× 下可见性）。
    patch = lstar(stage[120:260, 700:1000].astype(float))
    dx = np.abs(np.diff(patch, axis=1))
    return {
        "stage_median_L": round(stage_l, 1),
        "char_median_L": char_l,
        "delta_L": round(abs(stage_l - char_l), 1),
        "paper_texture_std_L": round(float(np.std(dx)), 3),
    }


def edge_contrast(phase, slug, meta):
    studio = load(os.path.join(OUT, phase, "%s_hero_1920.png" % slug))
    trans = load(os.path.join(OUT, phase, "%s_transparent.png" % slug), "RGBA")
    mask = trans[..., 3] > 128
    # transparent(500×700, doll at 250,680) → hero_1920(3.15×, doll at 960,1058)：先归一化到 bbox。
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = xs.min(), ys.min(), xs.max(), ys.max()
    h = y1 - y0
    # hero bbox 由比例定位：透明图 2.1×，hero 3.15×，脚底对齐。
    scale = 3.15 / 2.1
    hx = 960.0
    hfoot = 1058.0
    results = []
    for frac in (0.35, 0.55, 0.72):
        sy = int(y0 + h * frac)
        row = np.where(mask[sy])[0]
        if len(row) == 0:
            continue
        sx = row.max()
        # 映射到 hero 坐标
        tx = hx + (sx - 250.0) * scale
        ty = hfoot + (sy - 680.0) * scale
        cx, cy = int(round(tx)), int(round(ty))
        if cy < 0 or cy >= studio.shape[0] or cx < 3 or cx >= studio.shape[1] - 6:
            continue
        bg_rgb = studio[cy, min(cx + 5, studio.shape[1] - 1)]
        edge_rgb = studio[cy, max(cx - 1, 0)]
        # 剪影暗边：从最外缘向内 1–4px 找最暗像素（ink L0 描边），报“轮廓边”对比。
        best = None
        for k in range(1, 9):
            c = studio[cy, max(cx - k, 0)]
            v = wcag(c, bg_rgb)
            if best is None or v > best[0]:
                best = (v, c)
        results.append({
            "y_frac": frac,
            "edge_rgb": rgb_hex(edge_rgb),
            "outline_rgb": rgb_hex(best[1]) if best else rgb_hex(edge_rgb),
            "bg_rgb": rgb_hex(bg_rgb),
            "contrast": round(wcag(edge_rgb, bg_rgb), 2),
            "outline_contrast": round(best[0], 2) if best else 0.0,
        })
    return results


def roi_bins(phase, slug, meta):
    studio = load(os.path.join(OUT, phase, "%s_studio_1280.png" % slug))
    trans = load(os.path.join(OUT, phase, "%s_transparent.png" % slug), "RGBA")
    mask = trans[..., 3] > 240
    ys, xs = np.where(mask)
    x0, y0, x1, y1 = xs.min() + 390, ys.min() + 22, xs.max() + 390, ys.max() + 22
    w, h = x1 - x0, y1 - y0
    rois = {
        "cloth": (0.34, 0.40, 0.66, 0.62),
        "face_skin": (0.38, 0.05, 0.62, 0.19),
        "leather": (0.36, 0.905, 0.64, 0.99),
        "prop_metal_wood": (0.60, 0.40, 0.80, 0.76),
        "hair": (0.28, 0.08, 0.44, 0.34),
    }
    out = {}
    for name, (ax, ay, bx, by) in rois.items():
        rx0 = max(0, int(x0 + w * ax)); rx1 = min(studio.shape[1], int(x0 + w * bx))
        ry0 = max(0, int(y0 + h * ay)); ry1 = min(studio.shape[0], int(y0 + h * by))
        crop = studio[ry0:ry1, rx0:rx1]
        if crop.size == 0:
            continue
        out[name] = l_bins(crop.reshape(-1, 3))
    # 绿/青布料暗部色相（苔藓骑士）
    if slug == "moss_knight":
        rx0 = int(x0 + w * 0.36); rx1 = int(x0 + w * 0.64)
        ry0 = int(y0 + h * 0.42); ry1 = int(y0 + h * 0.60)
        hh = shadow_hue(studio[ry0:ry1, rx0:rx1].reshape(-1, 3))
        if hh:
            out["cloth_shadow_hue"] = hh
    return out


def slash_metrics(phase):
    path = os.path.join(OUT, phase, "slash_impact_640.png")
    img = load(path)
    meta_path = os.path.join(OUT, phase, "slash_meta.json")
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    dist = np.sqrt(((img.astype(float) - np.array(CORE)) ** 2).sum(axis=2))
    mask = (dist < 55)
    ys, xs = np.where(mask)
    if len(xs) == 0:
        return {"error": "core mask empty"}
    # ROI：排除角色本体，只取画面右侧弧带
    roi = (xs > 380)
    xs, ys = xs[roi], ys[roi]
    if len(xs) == 0:
        return {"error": "core ROI empty"}
    x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
    # 核心宽度：在弧带最右列附近扫一列；以及用面积/弦长估计。
    col = x1 - 2
    col_rows = np.where(mask[:, col])[0]
    width_col = int(col_rows.max() - col_rows.min() + 1) if len(col_rows) else 0
    # 弧长：按 meta 的半径/角度在屏幕空间积分，核心宽度 = 面积 / 弧长。
    arc_px = 0.0
    if meta:
        origin = np.array(meta["origin"], dtype=float)
        hand = np.array(meta["hand_local"], dtype=float)
        hand[0] *= float(meta["xscale"])  # VFX 手部对齐：只压缩手位，弧本身不压缩
        scale = float(meta["scale"])
        arm = float(meta["arm_angle"]); r = float(meta["radius_local"]) + 0.35
        a0, a1 = arm - 2.15, arm - 0.25
        pts = []
        for t in np.linspace(a0, a1, 200):
            p = hand + np.array([np.cos(t), np.sin(t)]) * r
            pts.append([origin[0] + p[0] * scale, origin[1] + p[1] * scale])
        pts = np.array(pts)
        arc_px = float(np.linalg.norm(np.diff(pts, axis=0), axis=1).sum())
    width_area = round(len(xs) / arc_px, 2) if arc_px > 0 else 0.0
    # 背景：ROI 内排除斩击色与深边后的中位色。
    crop = img[y0:y1 + 1, x0:x1 + 1]
    flat = crop.reshape(-1, 3).astype(float)
    core_d = np.sqrt(((flat - np.array(CORE)) ** 2).sum(axis=1))
    edge_d = np.sqrt(((flat - np.array(EDGE)) ** 2).sum(axis=1))
    bg = flat[(core_d > 70) & (edge_d > 70)]
    bg_med = np.median(bg, axis=0) if len(bg) else np.array([245, 237, 222])
    # 径向扫描：用 meta 的手/半径/角度计算屏幕空间弧带厚度。
    radial = []
    if meta:
        origin = np.array(meta["origin"], dtype=float)
        hand = np.array(meta["hand_local"], dtype=float)
        hand[0] *= float(meta["xscale"])
        scale = float(meta["scale"])
        arm = float(meta["arm_angle"]); r = float(meta["radius_local"])
        for a in (arm - 1.65, arm - 1.15, arm - 0.65):
            d = np.array([np.cos(a), np.sin(a)])
            hits = []
            for t in np.arange(r - 12.0, r + 12.0, 0.2):
                p = hand + d * t
                sx = int(round(origin[0] + p[0] * scale))
                sy = int(round(origin[1] + p[1] * scale))
                if 0 <= sy < img.shape[0] and 0 <= sx < img.shape[1]:
                    if np.linalg.norm(img[sy, sx].astype(float) - np.array(CORE)) < 55:
                        hits.append(t)
            radial.append(round((max(hits) - min(hits)) * scale, 1) if len(hits) > 1 else 0.0)
    # 命中 hold：对 25–27 帧的角色区做逐帧 diff。
    frames_dir = os.path.join(OUT, phase, "slash_frames")
    diffs = []
    for i in range(22, 30):
        p0 = os.path.join(frames_dir, "frame_%03d.png" % i)
        p1 = os.path.join(frames_dir, "frame_%03d.png" % (i + 1))
        if os.path.exists(p0) and os.path.exists(p1):
            a = load(p0)[60:340, 120:520].astype(float)
            b = load(p1)[60:340, 120:520].astype(float)
            diffs.append({"pair": [i, i + 1], "mean_abs": round(float(np.abs(a - b).mean()), 2)})
    return {
        "core_px": int(len(xs)),
        "roi_bbox": [x0, y0, x1, y1],
        "core_width_col_px": width_col,
        "core_width_radial_px": radial,
        "core_width_area_over_arc_px": width_area,
        "arc_screen_len_px": round(arc_px, 1),
        "core_hex": rgb_hex(CORE),
        "edge_hex": rgb_hex(EDGE),
        "bg_median_hex": rgb_hex(bg_med),
        "core_contrast_vs_bg": round(wcag(CORE, tuple(bg_med)), 2),
        "edge_contrast_vs_bg": round(wcag(EDGE, tuple(bg_med)), 2),
        "frame_diffs_22_30": diffs,
    }


def make_derivatives():
    for phase in ("before", "after"):
        for slug, _ in CHARS:
            for src, suffix, size in [
                ("%s_studio_1280.png" % slug, "studio_1280", (1280, 720)),
                ("%s_hero_1920.png" % slug, "hero_1920", (1920, 1080)),
            ]:
                path = os.path.join(OUT, phase, src)
                if not os.path.exists(path):
                    continue
                im = Image.open(path).convert("RGB")
                small = im.resize((size[0] // 4, size[1] // 4), Image.LANCZOS)
                small.save(os.path.join(OUT, phase, "%s_%s_25pct.png" % (slug, suffix)))
    # before/after 同机位对比（100% + 25%）
    for slug, _ in CHARS:
        for suffix, size in [("studio_1280", (1280, 720)), ("hero_1920", (1920, 1080))]:
            b = Image.open(os.path.join(OUT, "before", "%s_%s.png" % (slug, suffix))).convert("RGB")
            a = Image.open(os.path.join(OUT, "after", "%s_%s.png" % (slug, suffix))).convert("RGB")
            b25 = b.resize((size[0] // 4, size[1] // 4), Image.LANCZOS)
            a25 = a.resize((size[0] // 4, size[1] // 4), Image.LANCZOS)
            W = size[0]
            sheet = Image.new("RGB", (W, size[1] * 2 + 12), (250, 246, 238))
            sheet.paste(b, (0, 0))
            sheet.paste(a, (0, size[1] + 12))
            sheet.save(os.path.join(OUT, "compare_%s_%s.png" % (slug, suffix)))
            sheet25 = Image.new("RGB", (W, size[1] // 2 + 10), (250, 246, 238))
            sheet25.paste(b25, (0, 0))
            sheet25.paste(a25, (0, size[1] // 4 + 10))
            sheet25.save(os.path.join(OUT, "compare_%s_%s_25pct.png" % (slug, suffix)))
    # 斩击 before/after
    b = Image.open(os.path.join(OUT, "before", "slash_impact_640.png")).convert("RGB")
    a = Image.open(os.path.join(OUT, "after", "slash_impact_640.png")).convert("RGB")
    sheet = Image.new("RGB", (b.width * 2 + 8, b.height), (250, 246, 238))
    sheet.paste(b, (0, 0)); sheet.paste(a, (b.width + 8, 0))
    sheet.save(os.path.join(OUT, "slash_before_after.png"))


def main():
    data = {"chars": {}, "phases": {}}
    for phase in ("before", "after"):
        phase_data = {"ink": {}, "roi": {}, "edge": {}}
        metas = {}
        for slug, name in CHARS:
            tp = os.path.join(OUT, phase, "%s_transparent.png" % slug)
            phase_data["ink"][slug] = ink_ratio(tp)
            metas[slug] = char_meta(tp)
            phase_data["roi"][slug] = roi_bins(phase, slug, metas[slug])
            phase_data["edge"][slug] = edge_contrast(phase, slug, metas[slug])
        # 舞台：用苔藓骑士的 median L* 代表角色
        phase_data["stage"] = stage_metrics(phase, metas["moss_knight"])
        phase_data["stage"]["edge_1x"] = phase_data["edge"]["moss_knight"]
        data["phases"][phase] = phase_data
    data["slash"] = {"after": slash_metrics("after"), "before": slash_metrics("before")}
    with open(os.path.join(OUT, "metrics.json"), "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    make_derivatives()
    print(json.dumps({
        "ink": {p: {s: data["phases"][p]["ink"][s].get("ink_ratio_bbox") for s in data["phases"][p]["ink"]}
                for p in data["phases"]},
        "stage": {p: {k: v for k, v in data["phases"][p]["stage"].items() if k != "edge_1x"} for p in data["phases"]},
        "slash_after": {k: v for k, v in data["slash"]["after"].items() if k != "frame_diffs_22_30"},
        "slash_before": {k: v for k, v in data["slash"]["before"].items() if k != "frame_diffs_22_30"},
    }, ensure_ascii=False, indent=2))
    print("MATERIAL_VFX_METRICS_OK")


if __name__ == "__main__":
    main()
