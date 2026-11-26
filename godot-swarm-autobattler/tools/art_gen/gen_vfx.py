"""VFX atlas: 3 frames x 6 effects, 32 px cells -> 96x192 (additive in-game)."""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

from artlib import BRASS_HI, glow, new_layer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "vfx")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")
CELL = 32
SS = 8


def canvas():
    return Image.new("RGBA", (CELL * SS, CELL * SS), (0, 0, 0, 0))


def star(d, cx, cy, r, points=4, color=(255, 240, 205, 255), width=5, rot=0.0):
    pts = []
    for i in range(points * 2):
        a = rot + i * math.pi / points
        rr = r if i % 2 == 0 else r * 0.36
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)


def ring(img, cx, cy, r, color, width, squash=1.0):
    d = ImageDraw.Draw(img)
    d.ellipse((cx - r, cy - r * squash, cx + r, cy + r * squash), outline=color,
              width=max(1, int(width)))


def melee(frame):
    img = canvas()
    c = CELL * SS / 2
    if frame == 0:
        glow(img, (c, c), CELL * SS * 0.16, (255, 230, 170), 0.9)
        d = ImageDraw.Draw(img)
        star(d, c, c, CELL * SS * 0.12, 4, (255, 248, 220, 255), 2, 0.2)
        star(d, c, c, CELL * SS * 0.055, 8, (255, 210, 130, 220), 1, 0.1)
    elif frame == 1:
        glow(img, (c, c), CELL * SS * 0.26, (255, 210, 130), 0.7)
        d = ImageDraw.Draw(img)
        star(d, c, c, CELL * SS * 0.19, 4, (255, 246, 210, 240), 2, 0.25)
        star(d, c, c, CELL * SS * 0.1, 8, (255, 190, 95, 200), 1, 0.1)
        ring(img, c, c, CELL * SS * 0.23, (255, 220, 150, 80), CELL * SS * 0.015)
    else:
        d = ImageDraw.Draw(img)
        ring(img, c, c, CELL * SS * 0.3, (255, 190, 110, 55), CELL * SS * 0.02)
        for i in range(6):
            a = i * math.tau / 6 + 0.3
            x = c + math.cos(a) * CELL * SS * 0.3
            y = c + math.sin(a) * CELL * SS * 0.3
            d.ellipse((x - 3, y - 3, x + 3, y + 3), fill=(255, 220, 150, 120))
    return img


def shot(frame):
    img = canvas()
    cy = CELL * SS / 2
    head_x = CELL * SS * 0.74
    if frame == 0:
        tail = CELL * SS * 0.36
        glow(img, (head_x, cy), CELL * SS * 0.13, (230, 255, 255), 1.0)
        d = ImageDraw.Draw(img)
        d.ellipse((head_x - 7, cy - 7, head_x + 7, cy + 7), fill=(255, 255, 255, 255))
        d.polygon([(tail, cy - 2.5), (head_x - 2, cy - 5), (head_x - 2, cy + 5), (tail, cy + 2.5)],
                  fill=(190, 250, 255, 170))
    elif frame == 1:
        tail = CELL * SS * 0.16
        glow(img, (head_x, cy), CELL * SS * 0.16, (220, 255, 255), 1.0)
        d = ImageDraw.Draw(img)
        d.ellipse((head_x - 5.5, cy - 5.5, head_x + 5.5, cy + 5.5), fill=(255, 255, 255, 255))
        d.polygon([(tail, cy - 1.5), (head_x - 2, cy - 5.5), (head_x - 2, cy + 5.5), (tail, cy + 1.5)],
                  fill=(170, 245, 255, 140))
    else:
        tail = CELL * SS * 0.02
        glow(img, (head_x, cy), CELL * SS * 0.12, (200, 245, 255), 0.6)
        d = ImageDraw.Draw(img)
        d.polygon([(tail, cy - 0.6), (head_x, cy - 3.5), (head_x, cy + 3.5), (tail, cy + 0.6)],
                  fill=(150, 230, 245, 80))
        d.ellipse((head_x - 2.5, cy - 2.5, head_x + 2.5, cy + 2.5), fill=(255, 255, 255, 160))
    return img


def splash(frame):
    img = canvas()
    c = CELL * SS / 2
    rr = (0.12, 0.24, 0.4)[frame]
    alpha = (210, 170, 90)[frame]
    glow(img, (c, c), CELL * SS * rr * 1.4, (255, 150, 70), 0.55 - frame * 0.12)
    ring(img, c, c, CELL * SS * rr, (255, 200, 140, alpha), CELL * SS * (0.035 - frame * 0.008), 1.0)
    d = ImageDraw.Draw(img)
    for i in range(4 + frame * 2):
        a = i * math.tau / (4 + frame * 2) + frame * 0.3
        x = c + math.cos(a) * CELL * SS * rr
        y = c + math.sin(a) * CELL * SS * rr
        r = 2.2 - frame * 0.5
        d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 235, 200, max(30, alpha - 40)))
    return img


def death(frame):
    img = canvas()
    c = CELL * SS / 2
    d = ImageDraw.Draw(img)
    if frame == 0:
        glow(img, (c, c), CELL * SS * 0.3, (140, 240, 230), 0.5)
        for i in range(10):
            a = i * math.tau / 10 + 0.2
            x = c + math.cos(a) * CELL * SS * 0.12
            y = c + math.sin(a) * CELL * SS * 0.12
            r = CELL * SS * 0.035
            d.ellipse((x - r, y - r, x + r, y + r), fill=(190, 255, 245, 200))
    elif frame == 1:
        for i in range(12):
            a = i * math.tau / 12 + 0.45
            x = c + math.cos(a) * CELL * SS * (0.18 + (i % 3) * 0.03)
            y = c + math.sin(a) * CELL * SS * (0.14 + (i % 2) * 0.04)
            r = CELL * SS * (0.022 + (i % 3) * 0.008)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(140, 235, 225, 140))
    else:
        for i in range(14):
            a = i * math.tau / 14 + 0.8
            x = c + math.cos(a) * CELL * SS * (0.26 + (i % 4) * 0.035)
            y = c + math.sin(a) * CELL * SS * (0.2 + (i % 3) * 0.05)
            r = CELL * SS * (0.012 + (i % 2) * 0.008)
            d.ellipse((x - r, y - r, x + r, y + r), fill=(110, 210, 205, 90))
    return img


def spawn(frame):
    img = canvas()
    c = CELL * SS / 2
    rr = (0.14, 0.27, 0.42)[frame]
    alpha = (230, 160, 70)[frame]
    glow(img, (c, c), CELL * SS * rr, (120, 240, 255), 0.55 - frame * 0.12)
    ring(img, c, c, CELL * SS * rr, (170, 255, 250, alpha), CELL * SS * (0.035 - frame * 0.01))
    d = ImageDraw.Draw(img)
    for i in range(6):
        a = i * math.tau / 6 + 0.4
        x = c + math.cos(a) * CELL * SS * rr
        y = c + math.sin(a) * CELL * SS * rr
        r = 3.0 - frame * 0.7
        d.ellipse((x - r, y - r, x + r, y + r), fill=(200, 255, 250, max(40, alpha - 30)))
    return img


def victory(frame):
    img = canvas()
    c = CELL * SS / 2
    if frame == 0:
        glow(img, (c, c), CELL * SS * 0.2, (255, 210, 120), 0.9)
        d = ImageDraw.Draw(img)
        star(d, c, c, CELL * SS * 0.16, 4, (255, 246, 210, 255), 1, 0.4)
    elif frame == 1:
        glow(img, (c, c), CELL * SS * 0.34, (255, 200, 100), 0.7)
        d = ImageDraw.Draw(img)
        star(d, c, c, CELL * SS * 0.25, 4, (255, 245, 205, 235), 1, 0.4)
        star(d, c, c, CELL * SS * 0.12, 8, (255, 255, 255, 220), 1, 0.2)
    else:
        d = ImageDraw.Draw(img)
        for i in range(10):
            a = i * math.tau / 10
            x = c + math.cos(a) * CELL * SS * 0.3
            y = c + math.sin(a) * CELL * SS * 0.3
            r = 2.6
            d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 220, 140, 130))
        ring(img, c, c, CELL * SS * 0.33, (255, 210, 120, 60), CELL * SS * 0.02)
    return img


ROWS = [melee, shot, splash, death, spawn, victory]
NAMES = ["melee_spark", "shot", "splash_ring", "death", "spawn_ring", "victory"]


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * 3, CELL * 6), (0, 0, 0, 0))
    for r, fn in enumerate(ROWS):
        for f in range(3):
            cell = fn(f).resize((CELL, CELL), Image.LANCZOS)
            atlas.alpha_composite(cell, (f * CELL, r * CELL))
    path = os.path.join(OUT_DIR, "vfx_atlas_96x192.png")
    atlas.save(path)
    print("VFX_ATLAS", path, atlas.size)
    preview = Image.new("RGBA", (3 * 160 + 180, 6 * 160 + 40), (8, 12, 16, 255))
    d = ImageDraw.Draw(preview)
    for r, name in enumerate(NAMES):
        row_fn = ROWS[r]
        for f in range(3):
            tile = row_fn(f).resize((150, 150), Image.LANCZOS)
            bg = Image.new("RGBA", (150, 150), (10, 16, 20, 255))
            bg.alpha_composite(tile, (0, 0))
            preview.alpha_composite(bg, (10 + f * 160, 20 + r * 160))
        d.text((10, 4 + r * 160), name, fill=(200, 230, 235, 255))
    preview = preview.resize((preview.width * 2, preview.height * 2), Image.NEAREST)
    pp = os.path.join(PREVIEW_DIR, "vfx_atlas_preview.png")
    preview.save(pp)
    print("VFX_PREVIEW", pp, preview.size)


if __name__ == "__main__":
    main()
