"""20 px UI icon atlas (white line icons, 17 in a row -> 340x20)."""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "ui")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")
CELL = 20
SS = 10


def canvas():
    return Image.new("RGBA", (CELL * SS, CELL * SS), (0, 0, 0, 0))


def ln(d, pts, w=1.5, color=(255, 255, 255, 255)):
    d.line([(x * SS, y * SS) for x, y in pts], fill=color, width=max(1, int(w * SS)), joint="curve")


def circ(d, cx, cy, r, w=1.5, color=(255, 255, 255, 255)):
    d.ellipse(((cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS),
              outline=color, width=max(1, int(w * SS)))


def poly(d, pts, w=1.5, color=(255, 255, 255, 255), fill=False):
    pp = [(x * SS, y * SS) for x, y in pts]
    if fill:
        d.polygon(pp, fill=color)
    d.line(pp + [pp[0]], fill=color, width=max(1, int(w * SS)), joint="curve")


def icon_coin(d):
    circ(d, 10, 10, 7.4)
    poly(d, [(10, 5.2), (13.6, 10), (10, 14.8), (6.4, 10)], 1.4)


def icon_furnace(d):
    poly(d, [(10, 2.8), (16.2, 6.2), (16.2, 13.8), (10, 17.2), (3.8, 13.8), (3.8, 6.2)], 1.4)
    ln(d, [(10, 6.5), (10, 13.5)])
    ln(d, [(7, 9), (10, 6.5), (13, 9)])


def icon_star(d):
    pts = []
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        r = 8 if i % 2 == 0 else 3.2
        pts.append((10 + math.cos(a) * r, 10 + math.sin(a) * r))
    poly(d, pts, 1.2, fill=True)


def icon_hp(d):
    ln(d, [(10, 16.2), (3.4, 10.2), (2.8, 6.4), (5.0, 3.6), (8.2, 4.2), (10, 6.4),
           (11.8, 4.2), (15.0, 3.6), (17.2, 6.4), (16.6, 10.2), (10, 16.2)], 1.5)


def icon_atk(d):
    ln(d, [(4.2, 15.8), (14.4, 5.6)], 1.8)
    poly(d, [(14.4, 5.6), (16.8, 3.2), (16.2, 6.8), (13.2, 6.8)], 1.2, fill=True)
    ln(d, [(3.2, 12.4), (7.6, 16.8)], 1.7)


def icon_aspd(d):
    poly(d, [(11.6, 2.8), (5.4, 11.0), (9.4, 11.0), (8.2, 17.2), (14.8, 8.6), (10.6, 8.6)], 1.2, fill=True)


def icon_range(d):
    circ(d, 10, 10, 7.0)
    circ(d, 10, 10, 2.6)
    ln(d, [(10, 1.6), (10, 5.2)])
    ln(d, [(10, 14.8), (10, 18.4)])
    ln(d, [(1.6, 10), (5.2, 10)])
    ln(d, [(14.8, 10), (18.4, 10)])


def icon_refresh(d):
    d.arc((3.2 * SS, 3.2 * SS, 16.8 * SS, 16.8 * SS), 30, 300, fill=(255, 255, 255, 255),
          width=int(1.6 * SS))
    poly(d, [(15.4, 3.6), (17.2, 7.2), (13.2, 6.6)], 1.1, fill=True)


def icon_level(d):
    ln(d, [(4.2, 16.4), (10, 10.4), (15.8, 16.4)], 1.8)
    ln(d, [(4.2, 10.8), (10, 4.8), (15.8, 10.8)], 1.8)


def icon_greed(d):
    poly(d, [(10, 2.8), (16.8, 10), (10, 17.2), (3.2, 10)], 1.5)
    ln(d, [(10, 6.2), (10, 13.8)])
    ln(d, [(8.0, 10), (12.0, 10)])


def icon_flood(d):
    for y in (6.5, 10.5, 14.5):
        pts = [(2.4, y), (5.0, y - 1.8), (7.6, y), (10.2, y - 1.8), (12.8, y), (15.4, y - 1.8), (17.6, y)]
        ln(d, pts, 1.5)


def icon_code(d):
    ln(d, [(7.0, 4.2), (2.8, 10), (7.0, 15.8)], 1.6)
    ln(d, [(13.0, 4.2), (17.2, 10), (13.0, 15.8)], 1.6)
    ln(d, [(11.6, 3.4), (8.4, 16.6)], 1.4)


def icon_melee(d):
    ln(d, [(3.4, 16.6), (14.0, 6.0)], 1.7)
    poly(d, [(14.0, 6.0), (16.8, 3.2), (16.0, 7.4), (12.6, 8.0)], 1.1, fill=True)
    d.arc((1.6 * SS, 6.4 * SS, 13.6 * SS, 18.4 * SS), 300, 60, fill=(255, 255, 255, 190), width=int(1.2 * SS))


def icon_ranged(d):
    d.arc((3.2 * SS, 2.6 * SS, 16.8 * SS, 17.4 * SS), 300, 60, fill=(255, 255, 255, 255), width=int(1.5 * SS))
    ln(d, [(10.2, 2.6), (10.2, 17.4)])
    ln(d, [(10.2, 10), (17.6, 10)], 1.4)
    poly(d, [(17.6, 10), (14.8, 8.2), (14.8, 11.8)], 1.0, fill=True)


def icon_support(d):
    circ(d, 10, 10, 3.0)
    circ(d, 10, 10, 6.8, 1.2)
    ln(d, [(10, 2.0), (10, 4.2)])
    ln(d, [(10, 15.8), (10, 18.0)])
    ln(d, [(2.0, 10), (4.2, 10)])
    ln(d, [(15.8, 10), (18.0, 10)])


def icon_tank(d):
    poly(d, [(10, 2.6), (16.4, 5.4), (15.2, 13.6), (10, 17.6), (4.8, 13.6), (3.6, 5.4)], 1.5)
    ln(d, [(10, 6.2), (10, 13.2)])


def icon_splash(d):
    circ(d, 10, 10, 3.0, 1.4)
    for i in range(8):
        a = i * math.pi / 4
        ln(d, [(10 + math.cos(a) * 5.0, 10 + math.sin(a) * 5.0),
               (10 + math.cos(a) * 8.0, 10 + math.sin(a) * 8.0)], 1.3)


ICONS = [
    ("coin", icon_coin), ("furnace", icon_furnace), ("star", icon_star), ("hp", icon_hp),
    ("atk", icon_atk), ("aspd", icon_aspd), ("range", icon_range), ("refresh", icon_refresh),
    ("level", icon_level), ("greed", icon_greed), ("flood", icon_flood), ("code", icon_code),
    ("melee", icon_melee), ("ranged", icon_ranged), ("support", icon_support),
    ("tank", icon_tank), ("splash", icon_splash),
]


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * len(ICONS), CELL), (0, 0, 0, 0))
    for i, (name, fn) in enumerate(ICONS):
        big = canvas()
        d = ImageDraw.Draw(big)
        fn(d)
        atlas.alpha_composite(big.resize((CELL, CELL), Image.LANCZOS), (i * CELL, 0))
    path = os.path.join(OUT_DIR, "icons_20.png")
    atlas.save(path)
    print("ICONS", path, atlas.size)
    preview = Image.new("RGBA", (len(ICONS) * 80 + 20, 120), (10, 16, 22, 255))
    for i, (name, _fn) in enumerate(ICONS):
        cell = atlas.crop((i * CELL, 0, i * CELL + CELL, CELL)).resize((64, 64), Image.LANCZOS)
        preview.alpha_composite(cell, (12 + i * 80, 24))
        ImageDraw.Draw(preview).text((12 + i * 80, 94), name, fill=(180, 210, 220, 255))
    preview.save(os.path.join(PREVIEW_DIR, "icons_preview.png"))
    print("ICON_PREVIEW", os.path.join(PREVIEW_DIR, "icons_preview.png"))


if __name__ == "__main__":
    main()
