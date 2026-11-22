#!/usr/bin/env python3
"""复现 T-20261121-043 评审中的明度/对比度测量。

只读 godot-changan-action/docs/shots/*.png，不修改游戏工程。
用法：python3 docs/art-review/changan-action/measure_changan.py
输出：L* 分区直方图、角色/背景 L* 对比、UI 文本对比（CIE L* + WCAG 相对亮度）。
"""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
SHOTS = ROOT / "godot-changan-action" / "docs" / "shots"

def lstar(img):
    a = np.asarray(img.convert("RGB"), dtype=np.float32) / 255.0
    a = np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
    y = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    return np.where(y > 216 / 24389, 116 * np.cbrt(y) - 16, (24389 / 27) * y), y

def y_from_l(l):
    return ((l + 16) / 116) ** 3 if l > 8 else l / (24389 / 27)

def contrast(l1, l2):
    y1, y2 = y_from_l(l1), y_from_l(l2)
    return (max(y1, y2) + 0.05) / (min(y1, y2) + 0.05)

def region(im, box, label):
    crop = im.crop(box)
    l, _ = lstar(crop)
    print(f"  {label:28s} box={box} L*med={np.median(l):5.1f} p10={np.percentile(l,10):5.1f} p90={np.percentile(l,90):5.1f}")
    return float(np.median(l))

def text_contrast(im, box, label):
    arr = np.asarray(im.crop(box).convert("RGB")).reshape(-1, 3)
    l = np.array([lstar(Image.new("RGB", (1, 1), tuple(int(v) for v in px)))[0][0, 0] for px in arr])
    bg = float(np.median(l)); tx = float(np.percentile(l, 99))
    print(f"  {label:28s} box={box} L*bg={bg:5.1f} L*txt(p99)={tx:5.1f} contrast={contrast(tx, bg):.2f}:1")

def main():
    print(f"shots: {SHOTS}")
    print("\n[1] 逐像素 L* 直方图（% 像素）")
    bins = [0, 5, 10, 15, 20, 30, 40, 60, 100]
    for p in sorted(SHOTS.glob("*.png")):
        l, _ = lstar(Image.open(p))
        h, _ = np.histogram(l, bins=bins)
        pct = (h / l.size * 100).round(1)
        print(f"  {p.stem:18s} " + " ".join(f"L{bins[i]}-{bins[i+1]}={pct[i]:5.1f}" for i in range(len(h))))

    im = {p.stem: Image.open(p).convert("RGB") for p in SHOTS.glob("*.png")}
    print("\n[2] 角色 / 局部背景 L* 中位对比")
    pairs = [
        ("02 沈灯", "02_street_night", (1090, 720, 1210, 930), (1400, 900, 1650, 1000)),
        ("04 沈灯", "04_combat1", (1130, 620, 1250, 850), (760, 780, 1000, 860)),
        ("04 泼皮", "04_combat1", (470, 560, 580, 740), (760, 780, 1000, 860)),
        ("08 Boss", "08_boss_phase2", (860, 520, 1080, 820), (1300, 450, 1500, 700)),
        ("05 命中闪", "05_combo_finisher", (860, 500, 1000, 800), (300, 800, 700, 950)),
    ]
    for name, shot, fg, bg in pairs:
        print(f"  {name}")
        lf = region(im[shot], fg, "foreground")
        lb = region(im[shot], bg, "background")
        print(f"    -> L* contrast = {contrast(lf, lb):.2f}:1")

    print("\n[3] UI 文本对比（p99 文本 / 中位底）")
    text_contrast(im["01_title"], (850, 805, 1085, 860), "01 CTA 按任意键开始")
    text_contrast(im["01_title"], (700, 1045, 1220, 1075), "01 footer 法律脚注 12px")
    text_contrast(im["02_street_night"], (30, 990, 1370, 1040), "02 底部操作提示 12-13px")
    text_contrast(im["03_dialogue_ahe"], (680, 930, 1400, 990), "03 对话正文 15px")
    text_contrast(im["09_results"], (700, 430, 1240, 480), "09 结算正文 15px")

if __name__ == "__main__":
    main()
