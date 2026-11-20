#!/usr/bin/env python3
"""Procedural pixel-art assets for the Sea of Stars water study.

Everything is drawn at 1x with a small palette and nearest filtering: no
anti-aliasing, no external art. Outputs go to assets/{world,char}.

Run: python3 tools/gen_art.py
"""

from PIL import Image, ImageDraw, ImageFilter, ImageChops
from collections import deque
import math
import os
import random

W, H = 640, 360
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets", "world")
CHAR = os.path.join(ROOT, "assets", "char")

# ── palette ────────────────────────────────────────────────────────────────
OUT = (30, 26, 34)
SAND = (216, 194, 143)
SAND2 = (198, 174, 122)
SAND3 = (176, 150, 104)
WET = (150, 156, 126)
WET2 = (128, 136, 110)
GRASS = (88, 130, 70)
GRASS2 = (66, 106, 58)
GRASS3 = (108, 148, 80)
DIRT = (150, 120, 86)
DIRT2 = (120, 94, 68)
ROCK = (112, 98, 82)
ROCK2 = (88, 74, 62)
ROCK3 = (142, 122, 98)
ROCK_D = (66, 56, 50)
CORAL = (224, 104, 120)
CORAL2 = (190, 70, 98)
CORAL3 = (244, 150, 150)
SEAWEED = (60, 130, 96)
SEAWEED2 = (44, 104, 80)
TRUNK = (124, 88, 52)
TRUNK2 = (96, 66, 38)
FROND = (70, 132, 60)
FROND2 = (48, 100, 46)
SKIN = (232, 176, 136)
SKIN2 = (196, 140, 104)
HAIR = (46, 40, 64)
HAIR2 = (72, 64, 92)
TUNIC = (216, 122, 58)
TUNIC2 = (176, 88, 40)
SCARF = (238, 230, 210)
PANTS = (62, 82, 116)
BOOTS = (92, 64, 44)

POND = [
    (120, 112), (170, 88), (230, 76), (300, 80), (350, 96),
    (410, 78), (470, 72), (530, 88), (575, 120), (602, 160),
    (618, 210), (622, 262), (602, 310), (560, 334), (500, 342),
    (440, 330), (390, 344), (320, 338), (250, 346), (190, 330),
    (140, 300), (112, 258), (100, 210), (102, 158),
]

R = random.Random(20261118)


def _h2(x, y):
    h = math.sin(x * 127.1 + y * 311.7) * 43758.5453123
    return h - math.floor(h)


def vn(x, y):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u = xf * xf * (3 - 2 * xf)
    v = yf * yf * (3 - 2 * yf)
    a = _h2(xi, yi)
    b = _h2(xi + 1, yi)
    c = _h2(xi, yi + 1)
    d = _h2(xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def canvas():
    return Image.new("RGBA", (W, H), (0, 0, 0, 0))


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", rel, img.size)


def make_mask():
    m = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(m)
    d.polygon(POND, fill=255)
    return m


def depth_from_mask(mask):
    """Distance-to-land inside the pond, normalized and quantized."""
    mp = mask.load()
    dist = [[-1] * W for _ in range(H)]
    q = deque()
    for y in range(H):
        for x in range(W):
            if mp[x, y] == 0:
                dist[y][x] = 0
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and dist[ny][nx] < 0:
                dist[ny][nx] = dist[y][x] + 1
                q.append((nx, ny))
    depth = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if not mp[x, y]:
                continue
            d = min(dist[y][x] / 140.0, 1.0) * 0.82
            d += 0.18 * ((x - 90) / 540.0)
            d += 0.06 * max(0.0, (y - 180) / 180.0)
            d = max(0.0, min(1.0, d))
            depth[y][x] = int(round(d * 255.0))
    return depth


def clip(layer, mask):
    return Image.composite(layer, Image.new("RGBA", (W, H), (0, 0, 0, 0)), mask)


# ── scenery pieces ─────────────────────────────────────────────────────────
def rock(d, cx, cy, rx, ry, seed=0, under=False):
    rr = random.Random(seed)
    for k in range(3):
        ex = cx + rr.randint(-rx // 3, rx // 3)
        ey = cy + rr.randint(-ry // 4, ry // 4)
        erx = rr.randint(max(2, rx // 2), max(3, rx))
        ery = rr.randint(max(2, ry // 2), max(3, ry))
        fill = ROCK2 if under else ROCK
        d.ellipse([ex - erx, ey - ery, ex + erx, ey + ery],
                  fill=fill, outline=OUT)
    hl = ROCK3 if not under else SEAWEED2
    d.arc([cx - rx + 3, cy - ry + 3, cx + rx - 3, cy + ry - 3],
          180, 300, fill=hl, width=2)
    if under:
        d.ellipse([cx - rx // 2, cy + ry // 3, cx + rx // 3, cy + ry // 2],
                  fill=SEAWEED)


def coral(d, cx, cy, size, seed=0):
    rr = random.Random(seed)
    col = CORAL if rr.random() < 0.6 else CORAL2
    d.line([(cx, cy), (cx, cy - size)],
           fill=col, width=2)
    for k in range(4):
        t = 0.35 + k * 0.16
        bx = cx
        by = cy - int(size * t)
        dx = rr.choice([-1, 1]) * rr.randint(2, 5)
        d.line([(bx, by), (bx + dx, by - rr.randint(2, 5))],
               fill=col, width=1)
    d.line([(cx - 2, cy), (cx - 4, cy + 2)], fill=CORAL3, width=1)
    d.line([(cx + 2, cy), (cx + 4, cy + 2)], fill=CORAL3, width=1)


def seaweed(d, x, y, h, seed=0):
    rr = random.Random(seed)
    col = SEAWEED if rr.random() < 0.5 else SEAWEED2
    for k in range(3):
        px, py = x + k * 2 - 2, y
        for i in range(h):
            px += 1 if (i // 3) % 2 else -1
            d.point((px, py - i), fill=col)


def palm(d, x, y, h=54, seed=0):
    rr = random.Random(seed)
    bend = rr.choice([-1, 1])
    for i in range(h):
        tx = x + int(bend * 3 * math.sin(i / h * 2.2))
        ty = y - i
        d.rectangle([tx - 1, ty, tx + 1, ty],
                    fill=TRUNK if i % 4 else TRUNK2)
    topx = x + int(bend * 3 * math.sin(2.2))
    topy = y - h
    d.ellipse([topx - 3, topy - 2, topx + 3, topy + 3], fill=TRUNK2)
    for k in range(7):
        ang = -math.pi + k * (math.pi / 6) + rr.uniform(-0.08, 0.08)
        px, py = topx, topy
        for i in range(9):
            px += int(math.cos(ang) * 2)
            py += int(math.sin(ang) * 2) + (1 if i > 3 else 0)
            d.line([(px, py), (px + 1, py)], fill=FROND if i < 6 else FROND2)
    for k in range(3):
        d.point((topx + k - 1, topy + 2), fill=(190, 150, 90))


def stairs(d, x, y, steps=7, width=68):
    for i in range(steps):
        sx = x + i * 5
        sy = y - i * 8
        d.rectangle([sx, sy, sx + width, sy + 7],
                    fill=ROCK if i % 2 else ROCK3, outline=OUT)
        d.line([(sx + 2, sy + 1), (sx + width - 2, sy + 1)], fill=ROCK3)
        d.line([(sx + 2, sy + 6), (sx + width - 2, sy + 6)], fill=ROCK_D)


def tuft(d, x, y):
    for k, dx in enumerate((-2, 0, 2)):
        d.line([(x + dx, y), (x + dx + (1 if k % 2 else -1), y - 4)],
               fill=GRASS3 if k == 1 else GRASS)


def build_bottom(mask, depth):
    img = canvas()
    px = img.load()
    mp = mask.load()
    for y in range(H):
        for x in range(W):
            if not mp[x, y]:
                continue
            dd = depth[y][x] / 255
            base = SAND
            if _h2(x // 3, y // 3) > 0.78:
                base = SAND2
            if _h2(x // 2 + 4, y // 2 - 3) > 0.96:
                base = SAND3
            if dd < 0.06:
                base = WET if (x + y) % 5 else WET2
            elif dd > 0.55:
                k = (dd - 0.55) * 0.45
                base = (int(base[0] * (1 - k) + 128 * k),
                        int(base[1] * (1 - k) + 156 * k),
                        int(base[2] * (1 - k) + 146 * k))
            px[x, y] = (*base, 255)

    d = ImageDraw.Draw(img)
    # sand ripple marks
    for _ in range(90):
        x = R.randrange(110, 610)
        y = R.randrange(80, 345)
        if mp[x, y]:
            d.line([(x, y), (x + R.randint(3, 8), y)],
                   fill=SAND3 if R.random() < 0.6 else SAND2)
    # pebbles, shells
    for _ in range(60):
        x = R.randrange(110, 610)
        y = R.randrange(80, 345)
        if mp[x, y]:
            d.rectangle([x, y, x + R.randint(0, 1), y + R.randint(0, 1)],
                        fill=ROCK3 if R.random() < 0.5 else SAND3)
    for x, y, s in ((300, 270, 3), (470, 300, 2), (210, 200, 2)):
        if mp[x, y]:
            d.arc([x - s, y - s, x + s, y + s], 0, 180, fill=CORAL3)

    feat = canvas()
    fd = ImageDraw.Draw(feat)
    for i, (x, y, rx, ry) in enumerate([
            (260, 180, 28, 15), (380, 145, 22, 12), (470, 215, 30, 16),
            (545, 280, 24, 13), (330, 300, 20, 11), (200, 255, 20, 11),
            (575, 165, 17, 10)]):
        rock(fd, x, y, rx, ry, seed=10 + i, under=True)
    for i, (x, y, s) in enumerate([(505, 185, 15), (430, 305, 13),
                                   (275, 135, 12), (565, 250, 14), (355, 250, 10)]):
        coral(fd, x, y, s, seed=30 + i)
    for i, (x, y, h) in enumerate([(235, 305, 17), (500, 128, 15),
                                   (595, 230, 18), (360, 322, 14),
                                   (305, 225, 13), (450, 180, 12)]):
        seaweed(fd, x, y, h, seed=50 + i)
    img = Image.alpha_composite(img, clip(feat, mask))
    return img


def build_props(mask):
    img = canvas()
    mp = mask.load()
    px = img.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                continue
            if y > 300 or (x < 235 and y > 250):
                base = SAND
                if _h2(x // 3 + 2, y // 3 + 7) > 0.80:
                    base = SAND2
                if _h2(x // 2, y // 2) > 0.97:
                    base = SAND3
            elif x < 175 and y < 255:
                base = GRASS
                if _h2(x // 3 + 5, y // 3 - 2) > 0.72:
                    base = GRASS2
                if _h2(x // 2 - 1, y // 2 + 3) > 0.95:
                    base = GRASS3
            elif y < 95 and x < 235:
                base = ROCK2
                if _h2(x // 4, y // 4) > 0.72:
                    base = ROCK
                if _h2(x // 3 - 2, y // 3 + 1) > 0.86:
                    base = ROCK_D
            elif x > 555 and y < 130:
                base = ROCK2 if _h2(x // 4, y // 4) > 0.5 else ROCK
            elif y > 335:
                base = WET if _h2(x // 2, y // 2) > 0.45 else SAND3
            else:
                base = SAND
                if _h2(x // 3 + 1, y // 3 - 4) > 0.74:
                    base = SAND2
                if _h2(x // 2 + 7, y // 2 + 2) > 0.93:
                    base = DIRT
            px[x, y] = (*base, 255)

    # wet shoreline band just outside the pond
    dil = mask.filter(ImageFilter.MaxFilter(9))
    band = ImageChops.subtract(dil, mask)
    band_img = canvas()
    bd = ImageDraw.Draw(band_img)
    bp = band_img.load()
    for y in range(H):
        for x in range(W):
            if band.getpixel((x, y)):
                bp[x, y] = (*(WET if R.random() > 0.35 else WET2), 255)
    img = Image.alpha_composite(img, band_img)

    d = ImageDraw.Draw(img)
    # cliff at the top-left and the waterfall notch
    d.polygon([(88, 96), (96, 20), (150, 4), (210, 18), (222, 78),
               (200, 104), (150, 112), (108, 108)], fill=ROCK2, outline=OUT)
    for i in range(6):
        d.line([(96 + i * 20, 30), (104 + i * 20, 90)], fill=ROCK_D)
    d.line([(100, 34), (210, 42)], fill=ROCK)
    d.line([(102, 68), (212, 76)], fill=ROCK)
    d.rectangle([139, 56, 173, 118], fill=(60, 70, 78), outline=OUT)
    d.rectangle([145, 58, 167, 112], fill=(96, 150, 160))
    # splash at the waterfall base
    for _ in range(24):
        x = R.randrange(138, 176)
        y = R.randrange(112, 128)
        if mp[x, y]:
            d.point((x, y), fill=(220, 246, 240))

    # stone stairs down to the water on the left
    stairs(d, 52, 298, steps=7, width=66)

    # palms + rocks + grass on the shore
    palm(d, 36, 306, h=52, seed=3)
    palm(d, 606, 128, h=44, seed=9)
    for i, (x, y, rx, ry) in enumerate([
            (320, 82, 26, 14), (178, 150, 18, 10), (600, 196, 22, 12),
            (455, 336, 26, 14), (205, 310, 18, 10), (560, 120, 16, 9)]):
        rock(d, x, y, rx, ry, seed=70 + i)
    for x, y in ((60, 330), (120, 342), (240, 350), (300, 340),
                 (500, 352), (560, 340), (70, 220), (130, 200)):
        tuft(d, x, y)
    for x, y in ((46, 286), (90, 334), (310, 346), (520, 344)):
        d.point((x, y), fill=CORAL3)
        d.point((x + 1, y - 1), fill=(240, 210, 120))
    return img


# ── character ──────────────────────────────────────────────────────────────
CELL_W, CELL_H = 32, 48
COLS, ROWS = 6, 4


def hero_cell(direction, frame):
    img = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    walk = frame >= 2
    ph = (frame - 2) if walk else 0
    bob = 0
    if walk:
        bob = (0, -1, 0, -1)[ph]
    cx = 16
    feet = 46 + bob
    head_y = 13 + bob
    body_y = 25 + bob
    leg_l = 0
    leg_r = 0
    arm = 0
    if walk:
        leg_l = (0, 1, 0, -1)[ph]
        leg_r = -leg_l
        arm = (0, -1, 0, 1)[ph]

    back = direction == 1
    profile = direction in (2, 3)

    # legs and boots
    for sgn, off in ((-1, leg_l), (1, leg_r)):
        lx = cx + sgn * 4
        d.rectangle([lx - 1, body_y + 10, lx + 1, feet - 3 + off],
                    fill=PANTS, outline=OUT)
        d.rectangle([lx - 2, feet - 4 + off, lx + 2, feet - 1 + off],
                    fill=BOOTS, outline=OUT)

    # body
    d.rectangle([cx - 6, body_y, cx + 6, body_y + 12],
                fill=TUNIC, outline=OUT)
    d.rectangle([cx - 6, body_y + 9, cx + 6, body_y + 12], fill=TUNIC2)
    d.rectangle([cx - 6, body_y - 1, cx + 6, body_y + 2], fill=SCARF)

    # arms
    d.rectangle([cx - 9, body_y + 2 + arm, cx - 7, body_y + 9 + arm],
                fill=TUNIC2, outline=OUT)
    d.rectangle([cx + 7, body_y + 2 - arm, cx + 9, body_y + 9 - arm],
                fill=TUNIC, outline=OUT)
    d.rectangle([cx - 9, body_y + 9 + arm, cx - 7, body_y + 11 + arm],
                fill=SKIN)
    d.rectangle([cx + 7, body_y + 9 - arm, cx + 9, body_y + 11 - arm],
                fill=SKIN)

    # head
    d.ellipse([cx - 8, head_y - 7, cx + 8, head_y + 9],
              fill=SKIN, outline=OUT)
    # hair
    if back:
        d.ellipse([cx - 8, head_y - 8, cx + 8, head_y + 5],
                  fill=HAIR, outline=OUT)
    else:
        d.ellipse([cx - 8, head_y - 8, cx + 8, head_y - 1],
                  fill=HAIR, outline=OUT)
        d.arc([cx - 8, head_y - 6, cx + 8, head_y + 8],
              200, 340, fill=HAIR, width=2)
    d.point((cx - 6, head_y - 4), fill=HAIR2)

    if not back:
        if profile:
            ex = cx - 4 if direction == 2 else cx + 4
            d.rectangle([ex - 1, head_y + 1, ex + 1, head_y + 3],
                        fill=(26, 24, 34))
            d.point((ex, head_y + 1), fill=(240, 238, 230))
            nx = cx - 8 if direction == 2 else cx + 8
            d.point((nx, head_y + 2), fill=SKIN2)
            d.point((cx + (-2 if direction == 2 else 2), head_y + 6),
                    fill=(120, 60, 60))
        else:
            d.rectangle([cx - 6, head_y + 1, cx - 4, head_y + 3],
                        fill=(26, 24, 34))
            d.rectangle([cx + 4, head_y + 1, cx + 6, head_y + 3],
                        fill=(26, 24, 34))
            d.point((cx - 5, head_y + 1), fill=(240, 238, 230))
            d.point((cx + 5, head_y + 1), fill=(240, 238, 230))
            d.line([(cx - 2, head_y + 6), (cx + 2, head_y + 6)],
                   fill=(120, 60, 60))
        d.rectangle([cx - 4, head_y + 8, cx + 4, head_y + 9],
                    fill=SKIN2)
    return img


def build_hero_sheet():
    sheet = Image.new("RGBA", (CELL_W * COLS, CELL_H * ROWS), (0, 0, 0, 0))
    for row, direction in enumerate((0, 1, 2, 3)):
        for col in range(COLS):
            cell = hero_cell(direction if direction != 3 else 2, col)
            if direction == 3:
                cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.alpha_composite(cell, (col * CELL_W, row * CELL_H))
    return sheet


# ── fx textures ────────────────────────────────────────────────────────────
def waterfall_frames():
    fw, fh = 32, 80
    sheet = Image.new("RGBA", (fw * 4, fh), (0, 0, 0, 0))
    for f in range(4):
        img = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        for y in range(fh):
            for x in range(fw):
                edge = 1.0 - min(1.0, abs(x - 16) / 11.0)
                if edge <= 0.0:
                    continue
                v = math.sin((x * 1.7 + y * 0.8 + f * 5) * 0.6) * 0.5 + 0.5
                a = int(255 * edge * (0.45 + 0.55 * v))
                if a < 18:
                    continue
                if v > 0.72:
                    col = (232, 250, 246, a)
                elif v > 0.42:
                    col = (158, 218, 226, a)
                else:
                    col = (92, 176, 200, a)
                d.point((x, y), fill=col)
        for _ in range(16):
            x = R.randrange(8, 24)
            y = R.randrange(fh - 10, fh)
            d.point((x, y), fill=(235, 250, 246, 220))
        sheet.alpha_composite(img, (f * fw, 0))
    return sheet


def caustic_tex():
    n = 64
    pts = [(R.randrange(n), R.randrange(n)) for _ in range(9)]
    img = Image.new("RGBA", (n, n), (0, 0, 0, 255))
    px = img.load()
    for y in range(n):
        for x in range(n):
            ds = []
            for sx, sy in pts:
                dx = abs(x - sx)
                dy = abs(y - sy)
                dx = min(dx, n - dx)
                dy = min(dy, n - dy)
                ds.append(math.hypot(dx, dy))
            ds.sort()
            edge = ds[1] - ds[0]
            a = 1.0 - min(1.0, max(0.0, (edge - 0.45) / 1.35))
            a = a * a * a
            v = int(255 * a)
            if v > 4:
                px[x, y] = (int(v * 0.72), int(v * 0.96), int(v * 0.93), 255)
    return img


def foam_tex():
    n = 64
    img = Image.new("RGBA", (n, n), (0, 0, 0, 255))
    px = img.load()
    for _ in range(90):
        x, y = R.randrange(n), R.randrange(n)
        r = R.choice([0, 0, 0, 1])
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if R.random() < 0.65:
                    px[(x + dx) % n, (y + dy) % n] = (245, 252, 248, 255)
    return img


def preview(mask, depth, bottom, props):
    pv = Image.new("RGBA", (W, H), (18, 24, 30, 255))
    pv.alpha_composite(bottom)
    mp = mask.load()
    px = pv.load()
    for y in range(H):
        for x in range(W):
            if mp[x, y]:
                d = depth[y][x] / 255
                shallow = (92, 206, 196)
                deep = (24, 92, 128)
                a = 0.28 + d * 0.30
                col = pv.getpixel((x, y))
                px[x, y] = (int(col[0] * (1 - a) + (shallow[0] * (1 - d) + deep[0] * d) * a),
                            int(col[1] * (1 - a) + (shallow[1] * (1 - d) + deep[1] * d) * a),
                            int(col[2] * (1 - a) + (shallow[2] * (1 - d) + deep[2] * d) * a),
                            255)
    pv.alpha_composite(props)
    hero = hero_cell(0, 0)
    pv.alpha_composite(hero, (78 - 16, 300 - 46))
    return pv


def main():
    os.makedirs(WORLD, exist_ok=True)
    os.makedirs(CHAR, exist_ok=True)
    R.seed(20261118)
    mask = make_mask()
    depth = depth_from_mask(mask)
    depth_img = Image.new("L", (W, H), 0)
    dp = depth_img.load()
    for y in range(H):
        for x in range(W):
            dp[x, y] = depth[y][x]
    save(mask, "assets/world/water_mask.png")
    save(depth_img, "assets/world/water_depth.png")

    bottom = build_bottom(mask, depth)
    props = build_props(mask)
    save(bottom, "assets/world/bottom.png")
    save(props, "assets/world/props.png")
    save(build_hero_sheet(), "assets/char/hero.png")
    save(waterfall_frames(), "assets/world/waterfall.png")
    save(caustic_tex(), "assets/world/caustic.png")
    save(foam_tex(), "assets/world/foam.png")
    save(preview(mask, depth, bottom, props), "/tmp/sea_preview.png")


if __name__ == "__main__":
    main()
