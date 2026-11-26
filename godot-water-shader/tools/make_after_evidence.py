#!/usr/bin/env python3
"""T-20261126-005 视觉自检：从真实 GPU 1920×1080 截图生成
   - 1280×720（LANCZOS 等比缩放，注明方法）
   - 480×270 25% 缩略图 + contact sheet
   - 4× 最近邻局部（岸线/焦散/礁石）
   - metrics_after.json：关键区域中位色/L*/S、焦散高通 p95、白沫面积/纯白占比、UI 面积
不依赖 Godot；PIL only。
"""
import json, os, math
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "docs/shots/art-review/after")
OUT = SRC
SHOTS = [
    "01_wide_hero", "02_panel", "03_sea_caustics", "04_river_bridge",
    "05_lake_calm", "06_shallow_foam", "07_rain_puddles",
    "08_rain_closeup", "14_wavefront_islet", "15_hero_bridge", "16_hero_lake",
]

def srgb_to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def Lstar(rgb):
    r, g, b = (srgb_to_lin(float(v)) for v in rgb)
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    return 116.0 * (y ** (1.0 / 3.0)) - 16.0 if y > 0.008856 else 903.3 * y

def median_rgb(im, box):
    px = list(im.crop(box).getdata())
    n = len(px)
    r = sorted(p[0] for p in px)[n // 2]
    g = sorted(p[1] for p in px)[n // 2]
    b = sorted(p[2] for p in px)[n // 2]
    return (r, g, b)

def med_ls(im, box):
    rgb = median_rgb(im, box)
    r, g, b = [v / 255.0 for v in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    s = 0.0 if mx == 0 else (mx - mn) / mx
    return {"rgb": list(rgb), "hex": "#%02X%02X%02X" % tuple(rgb),
            "L": round(Lstar(rgb), 1), "S": round(s, 3)}

def highpass_p95(im, box):
    crop = im.crop(box).convert("RGB")
    med = crop.filter(ImageFilter.MedianFilter(size=9))
    a = list(crop.getdata())
    b = list(med.getdata())
    diffs = sorted(Lstar(p) - Lstar(q) for p, q in zip(a, b))
    n = len(diffs)
    return {
        "p95": round(diffs[int(n * 0.95)], 2),
        "p99": round(diffs[int(n * 0.99)], 2),
        "frac>2": round(sum(1 for d in diffs if d > 2.0) / n, 4),
        "median": round(diffs[n // 2], 2),
    }

def foam_metrics(im, box):
    px = im.crop(box).convert("RGB")
    w, h = px.size
    data = list(px.getdata())
    bright = total = pure = 0
    for (r, g, b) in data:
        mx, mn = max(r, g, b), min(r, g, b)
        s = 0.0 if mx == 0 else (mx - mn) / mx
        L = Lstar((r, g, b))
        if L > 88 and s < 0.22:
            bright += 1
        if r > 245 and g > 245 and b > 245:
            pure += 1
        total += 1
    return {"crop": list(box), "foam_frac_of_crop": round(bright / total, 4),
            "pure_white_frac": round(pure / total, 5)}

def main():
    os.makedirs(OUT, exist_ok=True)
    for name in SHOTS:
        path = os.path.join(SRC, name + ".png")
        if not os.path.exists(path):
            continue
        im = Image.open(path).convert("RGB")
        im.resize((1280, 720), Image.LANCZOS).save(os.path.join(SRC, name + "_1280.png"))
        im.resize((480, 270), Image.LANCZOS).save(os.path.join(SRC, name + "_25pct.png"))
    # 25% contact sheet 3×4
    thumbs = [Image.open(os.path.join(SRC, n + "_25pct.png")) for n in SHOTS
              if os.path.exists(os.path.join(SRC, n + "_25pct.png"))]
    cols, rows = 3, math.ceil(len(thumbs) / 3)
    sheet = Image.new("RGB", (cols * 480, rows * 270), (10, 16, 16))
    for i, t in enumerate(thumbs):
        sheet.paste(t, ((i % cols) * 480, (i // cols) * 270))
    sheet.save(os.path.join(SRC, "AFTER_25pct_sheet.png"))

    im03 = Image.open(os.path.join(SRC, "03_sea_caustics.png")).convert("RGB")
    im06 = Image.open(os.path.join(SRC, "06_shallow_foam.png")).convert("RGB")
    im14 = Image.open(os.path.join(SRC, "14_wavefront_islet.png")).convert("RGB")
    im01 = Image.open(os.path.join(SRC, "01_wide_hero.png")).convert("RGB")
    im04 = Image.open(os.path.join(SRC, "04_river_bridge.png")).convert("RGB")
    im05 = Image.open(os.path.join(SRC, "05_lake_calm.png")).convert("RGB")
    im07 = Image.open(os.path.join(SRC, "07_rain_puddles.png")).convert("RGB")

    # 4× 证据裁剪（NEAREST）
    def crop4(im, box, name):
        im.crop(box).resize(((box[2]-box[0])*4, (box[3]-box[1])*4), Image.NEAREST).save(
            os.path.join(SRC, name))
    crop4(im06, (760, 180, 960, 600), "AFTER_shore_4x.png")
    crop4(im03, (430, 170, 830, 570), "AFTER_caustics_4x.png")
    crop4(im14, (520, 180, 820, 460), "AFTER_islet_4x.png")
    crop4(im04, (1280, 380, 1680, 780), "AFTER_river_4x.png")

    m = {}
    m["03_sea_deep"] = med_ls(im03, (0, 160, 130, 700))
    m["03_sea_mid"] = med_ls(im03, (300, 250, 450, 800))
    m["03_sea_shallow"] = med_ls(im03, (600, 250, 720, 800))
    m["03_caustics_300"] = highpass_p95(im03, (600, 300, 900, 600))
    m["04_river_center"] = med_ls(im04, (1700, 600, 1800, 680))
    m["04_grass_bank"] = med_ls(im04, (720, 700, 940, 860))
    m["05_lake_center"] = med_ls(im05, (1300, 680, 1460, 820))
    m["05_lake_rim"] = med_ls(im05, (1360, 500, 1400, 540))
    m["05_lake_4x"] = highpass_p95(im05, (1250, 640, 1500, 860))
    m["06_water_mid"] = med_ls(im06, (400, 500, 560, 800))
    m["06_water_shallow"] = med_ls(im06, (720, 500, 820, 800))
    m["06_sand_dry"] = med_ls(im06, (900, 200, 980, 800))
    m["06_wet_band"] = med_ls(im06, (860, 300, 895, 800))
    m["06_foam_band"] = foam_metrics(im06, (780, 120, 900, 1000))
    m["06_caustics_4x"] = highpass_p95(im06, (300, 500, 600, 800))
    m["14_foam"] = foam_metrics(im14, (540, 180, 820, 440))
    m["01_shadow_house"] = med_ls(im01, (1160, 240, 1250, 330))
    m["01_grass_sun"] = med_ls(im01, (1400, 420, 1600, 560))
    m["07_puddle"] = med_ls(im07, (960, 860, 1140, 1000))
    m["07_grass_rain"] = med_ls(im07, (1300, 860, 1500, 1000))
    with open(os.path.join(SRC, "metrics_after.json"), "w") as f:
        json.dump(m, f, indent=2, ensure_ascii=False)
    print(json.dumps(m, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
