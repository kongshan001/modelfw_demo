#!/usr/bin/env python3
"""格间牌战 T-019 美术整改量化对比（before = T-018 评审证据，after = docs/shots）。

用法（项目根目录）：
    python3 tools/measure_artfix.py

依赖 Pillow。坐标基于 1920×1080：棋盘原点 (354,156)，格 132px（1280 设计 ×1.5）。
指标与 T-018 的 measure_gridbound.py 同源：WCAG 相对亮度、CIE L*、包围盒。
"""
from __future__ import annotations

import statistics
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
BEFORE = ROOT.parent / "docs/art-review/gridbound/support"
AFTER = ROOT / "docs/shots"

CELL = 132
OX, OY = 354, 156
CREAM = (246, 236, 210)


def srgb_lin(c: int) -> float:
    v = c / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lum(p) -> float:
    return 0.2126 * srgb_lin(p[0]) + 0.7152 * srgb_lin(p[1]) + 0.0722 * srgb_lin(p[2])


def lab_l(p) -> float:
    y = lum(p)
    return 116 * (y ** (1 / 3)) - 16 if y > 0.008856 else 903.3 * y


def contrast(a, b) -> float:
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def cell(im: Image.Image, col: int, row: int) -> Image.Image:
    x, y = OX + col * CELL, OY + row * CELL
    return im.crop((x, y, x + CELL, y + CELL))


def unit_values(im: Image.Image, col: int, row: int, ref) -> tuple[float, float]:
    a, b = cell(im, col, row), cell(im, *ref)
    pa, pb = a.load(), b.load()
    bg = pb[8, 8]
    vals = []
    for y in range(4, CELL - 4, 2):
        for x in range(4, CELL - 4, 2):
            p, q = pa[x, y], pb[x, y]
            if abs(p[0] - q[0]) + abs(p[1] - q[1]) + abs(p[2] - q[2]) > 45:
                vals.append(contrast(p, bg))
    vals.sort()
    if not vals:
        return 0.0, 100.0
    low = sum(1 for c in vals if c < 1.5) / len(vals) * 100
    return vals[len(vals) // 2], low


UNITS = [
    ("灯笼狐 (5,1)", 5, 1, (7, 1)),
    ("猛虎刺客 (3,2)", 3, 2, (7, 2)),
    ("日石骑士 (4,2)", 4, 2, (8, 2)),
    ("白银侍从 (3,3)", 3, 3, (7, 3)),
    ("玩家将军 (4,4)", 4, 4, (8, 4)),
    ("前阵弓手 (5,4)", 5, 4, (7, 4)),
    ("疗愈秘术师 (6,4)", 6, 4, (8, 4)),
    ("风刃指挥官 (2,4)", 2, 4, (0, 4)),
    ("敌方将军 (4,0)", 4, 0, (8, 0)),
    ("四方法师 (6,2)", 6, 2, (8, 2)),
    ("雀鹰 (3,0)", 3, 0, (0, 0)),
]

# before 的卡面 patch 与 T-018 相同；after 使用新名称带/规则区暗幕坐标。
TEXT_PATCHES = {
    "name": {
        "before": (457, 876, 539, 908),
        "after": (462, 826, 588, 858),
    },
    "desc": {
        "before": (441, 1028, 586, 1078),
        "after": (486, 986, 552, 1028),
    },
}


def is_text(p) -> bool:
    return abs(p[0] - CREAM[0]) + abs(p[1] - CREAM[1]) + abs(p[2] - CREAM[2]) < 120


def text_bg_stats(im: Image.Image, box) -> tuple[float, float, float]:
    px = list(im.crop(box).convert("RGB").get_flattened_data())
    # 只统计冷色（蓝/灰）背景像素：排除奶油色文字及其抗锯齿暖色边缘。
    bg = [p for p in px if not is_text(p) and p[2] >= p[0] - 4]
    ls = sorted(lab_l(p) for p in bg)
    p50 = ls[len(ls) // 2]
    p90 = ls[int(len(ls) * 0.9)]

    def l2y(l):
        return ((l + 16) / 116) ** 3 if l > 8 else l / 903.3

    return p50, p90, (lum(CREAM) + 0.05) / (l2y(p90) + 0.05)


def highlight_means(path: Path) -> dict[str, float]:
    im = Image.open(path).convert("RGB")
    out = {}
    for label, col, row in [
        ("empty (0,1)", 0, 1),
        ("move (4,1)", 4, 1),
        ("attack (3,2)", 3, 2),
        ("select (4,2)", 4, 2),
    ]:
        c = cell(im, col, row)
        px = [c.getpixel((x, y)) for y in range(6, CELL - 6, 4) for x in range(6, CELL - 6, 4)]
        med = tuple(int(statistics.median([p[i] for p in px])) for i in range(3))
        out[label] = lab_l(med)
    return out


def phoenix_bbox(base: Path, shot: Path) -> tuple[float, float] | None:
    a = Image.open(base).convert("RGB")
    b = Image.open(shot).convert("RGB")
    box = (760, 80, 1240, 420)
    a0, b0 = a.crop(box), b.crop(box)
    pts = []
    for y in range(a0.height):
        for x in range(a0.width):
            q, r = a0.getpixel((x, y)), b0.getpixel((x, y))
            if (r[0] > 235 and r[1] > 150 and r[2] < 140 and r[0] - r[2] > 110
                    and abs(r[0] - q[0]) + abs(r[1] - q[1]) + abs(r[2] - q[2]) > 100):
                pts.append((x, y))
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (max(xs) - min(xs)) / CELL, (max(ys) - min(ys)) / CELL


def slash_bbox(path: Path) -> tuple[float, float] | None:
    im = Image.open(path).convert("RGB").crop((740, 380, 1000, 620))
    pts = [(x, y) for y in range(im.height) for x in range(im.width)
           if (lambda c: c[1] > 200 and c[2] > 170 and c[1] - c[0] > 30)(im.getpixel((x, y)))]
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return (max(xs) - min(xs)) / CELL, (max(ys) - min(ys)) / CELL


def main() -> None:
    before_board = Image.open(BEFORE / "base_01_board.png").convert("RGB")
    after_board = Image.open(AFTER / "01_board.png").convert("RGB")

    print("== 单位 vs 格面：中位对比 / <1.5:1 像素占比 ==")
    med_ok_before = med_ok_after = 0
    low_ok_before = low_ok_after = 0
    for name, col, row, ref in UNITS:
        mb, lb = unit_values(before_board, col, row, ref)
        ma, la = unit_values(after_board, col, row, ref)
        med_ok_before += mb >= 3.0
        med_ok_after += ma >= 3.0
        low_ok_before += lb <= 10.0
        low_ok_after += la <= 10.0
        print(f"{name:20s} median {mb:4.2f} -> {ma:4.2f}:1   <1.5:1 {lb:5.1f}% -> {la:5.1f}%")
    print(f"达标：中位≥3:1  {med_ok_before}/11 -> {med_ok_after}/11；<1.5:1≤10%  {low_ok_before}/11 -> {low_ok_after}/11")

    print("\n== 卡面文字背景（排除奶油色文字像素）：L* p50 / p90 / 奶油对比 ==")
    for label, boxes in TEXT_PATCHES.items():
        b50, b90, bc = text_bg_stats(before_board, boxes["before"])
        a50, a90, ac = text_bg_stats(after_board, boxes["after"])
        print(f"{label:5s} before p50={b50:5.1f} p90={b90:5.1f} contrast={bc:4.2f}:1")
        print(f"{label:5s} after  p50={a50:5.1f} p90={a90:5.1f} contrast={ac:4.2f}:1")

    print("\n== 高亮态格面 L*（单位选中：青移动 / 红攻击 / 白选中） ==")
    hb = highlight_means(BEFORE / "ev_highlight_unit_1920.png")
    ha = highlight_means(AFTER / "07_highlight_unit.png")
    base = ha["empty (0,1)"]
    for label in ha:
        print(f"{label:16s} before {hb[label]:5.1f}  after {ha[label]:5.1f}  ΔL*(after-empty)={ha[label] - base:+5.1f}")

    print("\n== VFX 包围盒（格） ==")
    sb = slash_bbox(BEFORE / "base_03_attack.png")
    sa = slash_bbox(AFTER / "03_attack.png")
    if sb and sa:
        print(f"slash          before {sb[0]:.2f}x{sb[1]:.2f}  after {sa[0]:.2f}x{sa[1]:.2f}")
    pb = phoenix_bbox(BEFORE / "base_01_board.png", BEFORE / "base_04_spell.png")
    pa = phoenix_bbox(AFTER / "01_board.png", AFTER / "04_spell.png")
    if pb and pa:
        print(f"phoenix fire   before {pb[0]:.2f}x{pb[1]:.2f}  after {pa[0]:.2f}x{pa[1]:.2f}")

    print("\n== 配置时长（main.gd） ==")
    print("phoenix AI     38f @ 34.5fps = 1.10s（before 1.58s）")
    print("summon         26f @ 43.3fps = 0.60s（before 1.08s）")
    print("slash          12f @ 35.3fps = 0.34s + 0.12s fade（命中闪 0.03 白 + 0.10 红）")


if __name__ == "__main__":
    main()
