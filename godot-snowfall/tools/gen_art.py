#!/usr/bin/env python3
"""Procedural pixel assets for the 2D snow study.

1x pixel art, no anti-aliasing. Outputs ground/props/character/snow fx.
Run: python3 tools/gen_art.py
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

W, H = 640, 360
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WORLD = os.path.join(ROOT, "assets", "world")
PROPS = os.path.join(ROOT, "assets", "props")
CHAR = os.path.join(ROOT, "assets", "char")
FX = os.path.join(ROOT, "assets", "fx")

OUT = (26, 26, 34)
GRASS = (40, 58, 52)
GRASS2 = (32, 48, 44)
GRASS3 = (52, 72, 60)
PATH = (94, 96, 106)
PATH2 = (76, 80, 92)
PATH3 = (116, 118, 128)
PATH_OUT = (46, 48, 58)
WALL = (84, 86, 96)
WALL2 = (64, 66, 76)
WALL3 = (108, 110, 120)
SNOW = (214, 228, 248)
SNOW2 = (184, 202, 228)
SNOW_SH = (148, 168, 200)
PINE = (40, 82, 62)
PINE2 = (30, 66, 50)
PINE3 = (54, 100, 76)
BUSH = (44, 72, 54)
BUSH2 = (34, 58, 44)
TRUNK = (88, 68, 50)
TRUNK2 = (66, 50, 36)
GRAVE = (110, 112, 120)
GRAVE2 = (86, 88, 98)
LAMP = (60, 62, 74)
LAMP2 = (42, 44, 56)
FLAME = (255, 208, 124)
HAIR = (224, 226, 234)
HAIR2 = (196, 200, 212)
COAT = (50, 92, 112)
COAT2 = (38, 72, 90)
FUR = (210, 216, 222)
SKIN = (226, 174, 138)
SKIN2 = (194, 142, 110)
PANTS = (52, 60, 80)
BOOTS = (80, 58, 42)
LANTERN = (255, 200, 110)

R = random.Random(20261119)


def _h2(x, y):
    h = math.sin(x * 127.1 + y * 311.7) * 43758.5453123
    return h - math.floor(h)


def vn(x, y):
    xi, yi = math.floor(x), math.floor(y)
    xf, yf = x - xi, y - yi
    u = xf * xf * (3 - 2 * xf)
    v = yf * yf * (3 - 2 * yf)
    a, b = _h2(xi, yi), _h2(xi + 1, yi)
    c, d = _h2(xi, yi + 1), _h2(xi + 1, yi + 1)
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v


def fbm(x, y, oct=4):
    s = 0.0
    a = 0.5
    f = 1.0
    n = 0.0
    for _ in range(oct):
        s += a * vn(x * f, y * f)
        n += a
        f *= 2.03
        a *= 0.5
    return s / n


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def save(img, rel):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path)
    print("wrote", rel, img.size)


# ── ground ─────────────────────────────────────────────────────────────────
def build_ground():
    img = canvas(W, H)
    px = img.load()
    for y in range(H):
        for x in range(W):
            base = GRASS
            if _h2(x // 3, y // 3) > 0.76:
                base = GRASS2
            if _h2(x // 2 + 5, y // 2 - 2) > 0.94:
                base = GRASS3
            px[x, y] = (*base, 255)
    d = ImageDraw.Draw(img)
    # winding stone path, from the gate down to the bottom
    for y in range(92, H):
        cx = 320 + int(24 * math.sin((y - 92) / 58.0))
        hw = 42 + int(3 * math.sin(y * 0.11))
        d.rectangle([cx - hw - 4, y, cx + hw + 4, y], fill=PATH_OUT)
        d.rectangle([cx - hw, y, cx + hw, y], fill=PATH)
    for y in range(94, H, 9):
        cx = 320 + int(24 * math.sin((y - 92) / 58.0))
        for k in range(-4, 5):
            x = cx + k * 10 + (4 if (y // 9) % 2 else -2)
            d.ellipse([x - 4, y - 3, x + 4, y + 3], fill=PATH3 if R.random() > 0.4 else PATH2)
    for y in range(0, H, 7):
        cx = 320 + int(24 * math.sin((y - 92) / 58.0))
        d.point((cx - 46, y), fill=PATH3)
        d.point((cx + 46, y), fill=PATH3)
    # grass tufts, stones
    for _ in range(120):
        x, y = R.randrange(W), R.randrange(H)
        if abs(x - (320 + 24 * math.sin((y - 92) / 58.0))) < 48:
            continue
        if R.random() < 0.5:
            d.line([(x, y), (x - 1, y - 3)], fill=GRASS3)
        else:
            d.rectangle([x, y, x + 1, y], fill=PATH2)
    return img


# ── wall ───────────────────────────────────────────────────────────────────
def build_wall():
    w, h = W, 96
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 28, w, h], fill=WALL, outline=OUT)
    for y in range(32, h, 14):
        d.line([(0, y), (w, y)], fill=WALL2)
        off = 12 if (y // 14) % 2 else 0
        for x in range(off, w, 26):
            d.line([(x, y), (x, y + 14)], fill=WALL2)
    for x in range(0, w, 40):
        d.rectangle([x + 2, 20, x + 26, 30], fill=WALL3, outline=OUT)
    # gate
    d.rectangle([282, 40, 358, h], fill=(18, 20, 30), outline=OUT)
    d.arc([282, 4, 358, 92], 180, 360, fill=WALL3, width=6)
    return img


def make_cap(base, thickness=2, seed=0):
    w, h = base.size
    cap = canvas(w, h)
    bpx = base.load()
    cpx = cap.load()
    rr = random.Random(seed)
    for x in range(w):
        for y in range(h):
            if bpx[x, y][3] == 0:
                continue
            above = bpx[x, y - 1][3] if y > 0 else 0
            if above != 0:
                continue
            t = thickness + int(_h2(x * 0.7, seed) * 2)
            for k in range(t):
                yy = y + k
                if yy < h and bpx[x, yy][3] > 0:
                    cpx[x, yy] = (*SNOW, 255)
            yy = y + t
            if yy < h and bpx[x, yy][3] > 0:
                cpx[x, yy] = (*SNOW_SH, 255)
    return cap


# ── props ──────────────────────────────────────────────────────────────────
def pine(w, h, seed=0):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.rectangle([cx - 2, h - 18, cx + 2, h - 2], fill=TRUNK2, outline=OUT)
    tiers = 4
    for i in range(tiers):
        ty = int(10 + (h - 26) * i / tiers)
        half = int((w / 2 - 2) * (0.35 + 0.65 * (i + 1) / tiers))
        d.polygon([(cx, ty), (cx + half, ty + (h - 24) // tiers + 8),
                   (cx - half, ty + (h - 24) // tiers + 8)],
                  fill=PINE if i % 2 else PINE2, outline=OUT)
        for k in range(3):
            x = cx - half + 6 + k * (half - 6) // 3
            d.line([(x, ty + 6), (x + 3, ty + 10)], fill=PINE3)
    return img


def bush(w=44, h=28, seed=0):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    for k in range(4):
        x = 8 + k * 8
        d.ellipse([x - 7, 6 + (k % 2) * 3, x + 9, h - 2],
                  fill=BUSH if k % 2 else BUSH2, outline=OUT)
    return img


def grave(w=24, h=34):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([4, 8, w - 4, h - 2], radius=7,
                        fill=GRAVE, outline=OUT)
    d.rectangle([6, 2, w - 6, 12], fill=GRAVE)
    d.line([(w // 2, 12), (w // 2, h - 8)], fill=GRAVE2, width=1)
    d.line([(8, 26), (w - 8, 26)], fill=GRAVE2, width=1)
    return img


def cross(w=20, h=40):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    d.rectangle([8, 2, 12, h - 2], fill=GRAVE2, outline=OUT)
    d.rectangle([3, 10, 17, 15], fill=GRAVE, outline=OUT)
    return img


def bare(w=52, h=84, seed=0):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.line([(cx, h - 2), (cx, 26)], fill=TRUNK, width=4)
    for k in range(5):
        y = 20 + k * 10
        dx = (k % 2) * 2 - 1
        d.line([(cx, y), (cx + dx * 12, y - 8)], fill=TRUNK2, width=2)
        d.line([(cx + dx * 12, y - 8), (cx + dx * 16, y - 14)], fill=TRUNK2, width=1)
    return img


def lamp(w=26, h=82):
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    cx = w // 2
    d.rectangle([cx - 2, 30, cx + 2, h - 2], fill=LAMP2, outline=OUT)
    d.rectangle([cx - 9, h - 8, cx + 9, h - 3], fill=LAMP, outline=OUT)
    d.rectangle([cx - 9, 12, cx + 9, 34], fill=LAMP, outline=OUT)
    d.rectangle([cx - 6, 16, cx + 6, 30], fill=FLAME)
    d.polygon([(cx - 12, 12), (cx, 2), (cx + 12, 12)], fill=LAMP2, outline=OUT)
    return img


# ── hero ───────────────────────────────────────────────────────────────────
CW, CH = 32, 48


def hero_cell(direction, frame):
    img = canvas(CW, CH)
    d = ImageDraw.Draw(img)
    walk = frame >= 2
    ph = (frame - 2) if walk else 0
    bob = (0, -1, 0, -1)[ph] if walk else 0
    cx = 16
    feet = 46 + bob
    body = 26 + bob
    head = 14 + bob
    back = direction == 1
    profile = direction in (2, 3)
    leg = (0, 1, 0, -1)[ph] if walk else 0

    for sgn, off in ((-1, leg), (1, -leg)):
        lx = cx + sgn * 4
        d.rectangle([lx - 1, body + 10, lx + 1, feet - 4 + off],
                    fill=PANTS, outline=OUT)
        d.rectangle([lx - 2, feet - 5 + off, lx + 2, feet - 1 + off],
                    fill=BOOTS, outline=OUT)

    d.rectangle([cx - 7, body, cx + 7, body + 13], fill=COAT, outline=OUT)
    d.rectangle([cx - 7, body + 10, cx + 7, body + 13], fill=COAT2)
    d.rectangle([cx - 7, body - 2, cx + 7, body + 1], fill=FUR)
    d.rectangle([cx - 10, body + 2, cx - 8, body + 10], fill=COAT2, outline=OUT)
    d.rectangle([cx + 8, body + 2, cx + 10, body + 10], fill=COAT, outline=OUT)
    d.rectangle([cx - 10, body + 10, cx - 8, body + 12], fill=SKIN)
    d.rectangle([cx + 8, body + 10, cx + 10, body + 12], fill=SKIN)

    d.ellipse([cx - 8, head - 8, cx + 8, head + 8], fill=SKIN, outline=OUT)
    if back:
        d.ellipse([cx - 8, head - 9, cx + 8, head + 6], fill=HAIR, outline=OUT)
    else:
        d.ellipse([cx - 8, head - 9, cx + 8, head - 2], fill=HAIR, outline=OUT)
        d.arc([cx - 8, head - 6, cx + 8, head + 7], 200, 340, fill=HAIR, width=2)
    d.rectangle([cx - 6, head - 10, cx - 2, head - 7], fill=HAIR2)
    if not back:
        if profile:
            ex = cx - 4 if direction == 2 else cx + 4
            d.rectangle([ex - 1, head + 1, ex + 1, head + 3], fill=(24, 24, 34))
            d.point((ex, head + 1), fill=(240, 240, 230))
            d.point((cx + (-8 if direction == 2 else 8), head + 3), fill=SKIN2)
        else:
            d.rectangle([cx - 6, head + 1, cx - 4, head + 3], fill=(24, 24, 34))
            d.rectangle([cx + 4, head + 1, cx + 6, head + 3], fill=(24, 24, 34))
            d.point((cx - 5, head + 1), fill=(240, 240, 230))
            d.point((cx + 5, head + 1), fill=(240, 240, 230))
            d.line([(cx - 2, head + 6), (cx + 2, head + 6)], fill=(120, 60, 60))
    # little lantern in the right hand
    d.rectangle([cx + 10, body + 12, cx + 14, body + 18], fill=LANTERN, outline=OUT)
    d.point((cx + 12, body + 14), fill=(255, 245, 210))
    return img


def build_hero():
    sheet = canvas(CW * 6, CH * 4)
    for row, direction in enumerate((0, 1, 2, 3)):
        for col in range(6):
            cell = hero_cell(direction if direction != 3 else 2, col)
            if direction == 3:
                cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
            sheet.alpha_composite(cell, (col * CW, row * CH))
    return sheet


# ── fx ─────────────────────────────────────────────────────────────────────
def build_flakes():
    cell = 8
    sheet = canvas(cell * 8, cell * 3)
    for f in range(24):
        img = canvas(cell, cell)
        d = ImageDraw.Draw(img)
        a = f / 24.0 * math.pi
        for arm in range(3):
            ang = a + arm * math.pi / 3
            for k in range(1, 4):
                x = 4 + math.cos(ang) * k
                y = 4 + math.sin(ang) * k
                d.point((round(x), round(y)), fill=SNOW)
                x2 = 4 - math.cos(ang) * k
                y2 = 4 - math.sin(ang) * k
                d.point((round(x2), round(y2)), fill=SNOW)
        if f % 2 == 0:
            d.point((4, 4), fill=(255, 255, 255))
        sheet.alpha_composite(img, ((f % 8) * cell, (f // 8) * cell))
    return sheet


def build_foot():
    img = canvas(10, 8)
    d = ImageDraw.Draw(img)
    d.ellipse([1, 1, 8, 5], fill=(64, 78, 106))
    d.rectangle([2, 4, 7, 7], fill=(64, 78, 106))
    d.ellipse([2, 1, 7, 4], fill=(48, 60, 86))
    d.point((3, 2), fill=(36, 46, 68))
    return img


def radial(size, power=2.2, color=(255, 255, 255)):
    img = canvas(size, size)
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / (size / 2)
            a = max(0.0, 1.0 - r) ** power
            px[x, y] = (*color, int(a * 255))
    return img


def build_snow_mask():
    w, h = 320, 180
    img = Image.new("L", (w, h), 0)
    px = img.load()
    for y in range(h):
        for x in range(w):
            n = fbm(x * 0.05 + 3.0, y * 0.05 - 1.0, 4)
            n2 = fbm(x * 0.16 - 5.0, y * 0.16 + 4.0, 3)
            v = 0.5 * n + 0.5 * n2
            v = 0.56 + 0.7 * (v - 0.5)
            v = min(1.0, max(0.06, v))
            # less snow right on the winding path
            cx = 320 + 24 * math.sin((y * 2 - 92) / 58.0)
            if abs(x * 2 - cx) < 46:
                v *= 0.92
            px[x, y] = int(v * 255)
    return img


def preview(ground, wall, props_items, hero):
    img = ground.copy()
    wpx = img.load()
    mask = build_snow_mask().resize((W, H), Image.NEAREST)
    mpx = mask.load()
    for y in range(H):
        for x in range(W):
            m = mpx[x, y] / 255.0
            s = min(1.0, max(0.0, (m - 0.30) / 0.20))
            if s > 0:
                base = wpx[x, y]
                wpx[x, y] = (int(base[0] * (1 - s) + SNOW[0] * s),
                             int(base[1] * (1 - s) + SNOW[1] * s),
                             int(base[2] * (1 - s) + SNOW[2] * s), 255)
    img.alpha_composite(wall, (0, 0))
    for name, pos, base_img, cap_img in props_items:
        img.alpha_composite(base_img, (pos[0] - base_img.width // 2,
                                       pos[1] - base_img.height))
        img.alpha_composite(cap_img, (pos[0] - cap_img.width // 2,
                                      pos[1] - cap_img.height))
    img.alpha_composite(hero, (320 - 16, 330 - 46))
    return img


def main():
    for d in (WORLD, PROPS, CHAR, FX):
        os.makedirs(d, exist_ok=True)
    ground = build_ground()
    wall = build_wall()
    pines = [("pine_a", pine(60, 92, 1), 60, 92),
             ("pine_b", pine(44, 68, 2), 44, 68)]
    bush_img = bush()
    grave_img = grave()
    cross_img = cross()
    bare_img = bare()
    lamp_img = lamp()
    items = {}
    for name, img, w, h in pines:
        items[name] = (img, make_cap(img, 2, (7 if name == "pine_a" else 23)))
    items["bush"] = (bush_img, make_cap(bush_img, 2, 11))
    items["grave"] = (grave_img, make_cap(grave_img, 2, 12))
    items["cross"] = (cross_img, make_cap(cross_img, 2, 13))
    items["bare"] = (bare_img, make_cap(bare_img, 1, 14))
    items["lamp"] = (lamp_img, make_cap(lamp_img, 2, 15))
    items["wall"] = (wall, make_cap(wall, 3, 16))

    save(ground, "assets/world/ground.png")
    save(build_snow_mask(), "assets/world/snow_mask.png")
    save(build_hero(), "assets/char/hero.png")
    save(build_flakes(), "assets/fx/flake.png")
    save(build_foot(), "assets/fx/foot.png")
    save(radial(64, 2.0, (255, 206, 130)), "assets/fx/glow.png")
    save(radial(128, 2.4, (255, 255, 255)), "assets/fx/light.png")
    for name, (base, cap) in items.items():
        save(base, "assets/props/%s.png" % name)
        save(cap, "assets/props/%s_snow.png" % name)

    spots = [
        ("pine_a", (70, 150)), ("pine_b", (160, 214)),
        ("pine_a", (520, 150)), ("pine_b", (576, 236)),
        ("pine_b", (110, 300)), ("pine_a", (548, 320)),
        ("pine_b", (438, 122)), ("bush", (220, 250)),
        ("bush", (400, 270)), ("bush", (94, 340)),
        ("bush", (592, 350)), ("grave", (250, 178)),
        ("grave", (390, 196)), ("grave", (200, 306)),
        ("grave", (452, 312)), ("cross", (272, 150)),
        ("cross", (372, 168)), ("bare", (42, 210)),
        ("bare", (600, 252)), ("lamp", (268, 236)),
        ("lamp", (412, 232)), ("lamp", (318, 128)),
    ]
    pv_items = []
    for name, pos in spots:
        base, cap = items[name]
        pv_items.append((name, pos, base, cap))
    pv = preview(ground, wall, pv_items, build_hero().crop((0, 0, CW, CH)))
    save(pv, "/tmp/snow_preview.png")


if __name__ == "__main__":
    main()
