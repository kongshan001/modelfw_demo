#!/usr/bin/env python3
"""格间牌战 / Gridbound 美术评审量化脚本（T-20261121-018）。

用法（仓库根目录）：python3 docs/art-review/gridbound/support/capture/measure_gridbound.py
依赖：Pillow。输入是 docs/art-review/gridbound/support/ 下的自有截图；
不读取/不修改游戏代码或资产。

坐标基于 1920×1080 截图：棋盘原点 (354,156)，格 132px（1280 设计 ×1.5）。
对比度使用 WCAG 2.x 相对亮度；L* 使用 CIE Lab（D65）。
"""
from __future__ import annotations
import statistics
from PIL import Image

SUPPORT = "docs/art-review/gridbound/support/"


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


CELL = 132
OX, OY = 354, 156


def cell(im: Image.Image, col: int, row: int) -> Image.Image:
    x, y = OX + col * CELL, OY + row * CELL
    return im.crop((x, y, x + CELL, y + CELL))


def unit_contrast(name: str, col: int, row: int, ref: tuple[int, int]) -> None:
    im = Image.open(SUPPORT + "base_01_board.png").convert("RGB")
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
        print(f"{name}: no sprite pixels")
        return
    low = sum(1 for c in vals if c < 1.5) / len(vals) * 100
    print(f"{name:22s} median={vals[len(vals)//2]:.2f}:1  <1.5:1={low:5.1f}%  bgL*={lab_l(bg):5.1f}")


def text_patch(name: str, box) -> None:
    im = Image.open(SUPPORT + "base_01_board.png").convert("RGB")
    px = list(im.crop(box).get_flattened_data())
    ls = sorted(lab_l(p) for p in px)
    p50, p90 = ls[len(ls) // 2], ls[int(len(ls) * 0.9)]

    def l2y(l):
        return ((l + 16) / 116) ** 3 if l > 8 else l / 903.3

    cream = (246, 236, 210)  # #f6ecd2
    print(f"{name:22s} bg L* p50={p50:5.1f} p90={p90:5.1f}  contrast(cream,p90)={((lum(cream)+0.05)/(l2y(p90)+0.05)):.2f}:1")


def highlight_means() -> None:
    im = Image.open(SUPPORT + "ev_highlight_unit_1920.png").convert("RGB")
    for label, col, row in [("empty (0,1)", 0, 1), ("cyan move (4,1)", 4, 1), ("red attack (3,2)", 3, 2), ("gold select (4,2)", 4, 2)]:
        c = cell(im, col, row)
        px = [c.getpixel((x, y)) for y in range(6, CELL - 6, 4) for x in range(6, CELL - 6, 4)]
        med = tuple(int(statistics.median([p[i] for p in px])) for i in range(3))
        print(f"{label:18s} cell median={med}  L*={lab_l(med):5.1f}")


def bbox(name: str, im: Image.Image, box, cond) -> None:
    reg = im.crop(box)
    pts = [(x + box[0], y + box[1]) for y in range(reg.height) for x in range(reg.width) if cond(reg.getpixel((x, y)))]
    if not pts:
        print(f"{name}: none")
        return
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    print(f"{name:18s} bbox={min(xs)},{min(ys)}..{max(xs)},{max(ys)}  "
          f"{max(xs)-min(xs)}x{max(ys)-min(ys)}px = {round((max(xs)-min(xs))/CELL,2)}x{round((max(ys)-min(ys))/CELL,2)} cells")


def main() -> None:
    print("== 单位 vs 格面（01_board；中位对比与 <1.5:1 像素占比） ==")
    for t in [
        ("灯笼狐 (5,1)", 5, 1, (7, 1)), ("猛虎刺客 (3,2)", 3, 2, (7, 2)),
        ("日石骑士 (4,2)", 4, 2, (8, 2)), ("白银侍从 (3,3)", 3, 3, (7, 3)),
        ("玩家将军 (4,4)", 4, 4, (8, 4)), ("前阵弓手 (5,4)", 5, 4, (7, 4)),
        ("疗愈秘术师 (6,4)", 6, 4, (8, 4)), ("风刃指挥官 (2,4)", 2, 4, (0, 4)),
        ("敌方将军 (4,0)", 4, 0, (8, 0)), ("四方法师 (6,2)", 6, 2, (8, 2)),
        ("雀鹰 (3,0)", 3, 0, (0, 0)),
    ]:
        unit_contrast(*t)

    print("\n== 手牌文字背景（亮斑） ==")
    text_patch("名称带 (铁崖守卫)", (457, 876, 539, 908))
    text_patch("描述区 (铁崖守卫)", (441, 1028, 586, 1078))

    print("\n== 高亮态格面中位（补拍 1920） ==")
    highlight_means()

    print("\n== VFX 包围盒 ==")
    # 凤火：与 01_board 逐像素差分，排除邻近单位/徽章的静态亮色，只保留新出现的高饱和火焰像素。
    base = Image.open(SUPPORT + "base_01_board.png").convert("RGB")
    p = Image.open(SUPPORT + "base_04_spell.png").convert("RGB")
    box = (760, 80, 1240, 420)
    a0, b0 = base.crop(box), p.crop(box)
    pts = []
    for y in range(a0.height):
        for x in range(a0.width):
            q, r = a0.getpixel((x, y)), b0.getpixel((x, y))
            if (r[0] > 235 and r[1] > 150 and r[2] < 140 and r[0] - r[2] > 110
                    and abs(r[0]-q[0]) + abs(r[1]-q[1]) + abs(r[2]-q[2]) > 100):
                pts.append((x + box[0], y + box[1]))
    if pts:
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        print(f"{'phoenix(fire)':18s} bbox={min(xs)},{min(ys)}..{max(xs)},{max(ys)}  "
              f"{max(xs)-min(xs)}x{max(ys)-min(ys)}px = {round((max(xs)-min(xs))/CELL,2)}x{round((max(ys)-min(ys))/CELL,2)} cells")
    a = Image.open(SUPPORT + "base_03_attack.png").convert("RGB")
    bbox("slash", a, (740, 380, 980, 600), lambda c: c[1] > 200 and c[2] > 170 and c[1] - c[0] > 30)

    print("\n说明：phoenix 为核心高饱和火焰包围盒（含部分火星），不含邻近单位；"
          "图集帧 150px×0.95 ≈ 1.6 格。slash 为高饱和青色像素包围盒。")


if __name__ == "__main__":
    main()
