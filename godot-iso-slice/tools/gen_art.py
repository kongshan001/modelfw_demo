#!/usr/bin/env python3
"""Procedural art generator for Iso Slice - Candlekeep.

Everything is drawn at 4x and downsampled with LANCZOS, so the result is
smooth vector-like cartoon art (never pixel art). No external assets.

Run:
    python3 tools/gen_art.py

Outputs:
    assets/tiles/iso_tiles.png      4x2 atlas, cell 128x160
    assets/sprites/hero.png         8x6 sheet, cell 112x160, feet at cell center
    assets/props/*.png              base at cell center
    assets/fx/light.png             radial light cookie
    assets/fx/shadow.png            soft blob shadow
    assets/fx/mote.png              dust mote
    assets/ui/vignette.png          640x360 screen vignette
"""

from PIL import Image, ImageDraw, ImageFilter
import math
import os
import random

SS = 4  # supersample factor
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── palette ────────────────────────────────────────────────────────────────
OUT = (44, 48, 60)
FLOOR_A = (108, 113, 132)
FLOOR_B = (119, 124, 145)
FLOOR_LIGHT = (141, 147, 168)
FLOOR_DARK = (83, 87, 104)
FLOOR_OUT = (46, 49, 62)
MOSS = (94, 124, 82)
MOSS_DARK = (70, 98, 62)

WALL_TOP = (127, 133, 154)
WALL_TOP_LIGHT = (151, 157, 178)
WALL_TOP_DARK = (103, 108, 128)
WALL_LEFT = (72, 78, 97)
WALL_RIGHT = (90, 96, 117)
WALL_OUT = (36, 39, 51)

RUG_BASE = (126, 60, 56)
RUG_BORDER = (198, 160, 96)
RUG_INNER = (152, 78, 66)

SKIN = (126, 180, 98)
SKIN_LIGHT = (158, 208, 124)
SKIN_DARK = (96, 146, 74)
EAR_IN = (196, 148, 130)
TUNIC = (62, 108, 98)
TUNIC_DARK = (46, 84, 76)
PANTS = (88, 80, 100)
PANTS_DARK = (66, 60, 78)
LEATHER = (152, 104, 62)
LEATHER_DARK = (112, 74, 42)
BRASS = (218, 180, 96)
EYE = (248, 246, 232)
PUPIL = (32, 32, 40)
MOUTH = (88, 54, 54)
HERO_OUT = (34, 42, 32)

TILE_W, TILE_H = 128, 64
CELL_W, CELL_H = 128, 160
BASE_Y = 128          # footprint diamond center inside a tile cell
HERO_CW, HERO_CH = 112, 160
HERO_FEET = (56, 80)  # feet at the cell center -> node origin == feet


# ── helpers ────────────────────────────────────────────────────────────────
def canvas(w, h):
    return Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))


def save(img, rel, supersampled=True):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = (img.resize((img.width // SS, img.height // SS), Image.LANCZOS)
           if supersampled else img)
    out.save(path)
    print("wrote", rel, out.width, "x", out.height)


def P(x, y):
    return (x * SS, y * SS)


def PL(points):
    return [P(x, y) for x, y in points]


def W(v):
    return max(1, int(round(v * SS)))


def diamond(cx, cy, hw=TILE_W / 2, hh=TILE_H / 2):
    return [(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)]


def inset_diamond(cx, cy, k):
    return diamond(cx, cy, TILE_W / 2 * k, TILE_H / 2 * k)


def poly_outline(d, pts, color, width):
    d.line(pts + [pts[0]], fill=color, width=width, joint="curve")


def rand_in_diamond(rng, cx, cy, k=0.8):
    """Random point inside an inset diamond, so no art bleeds into neighbors."""
    while True:
        u = rng.uniform(-1, 1)
        v = rng.uniform(-1, 1)
        if abs(u) + abs(v) <= 1:
            return cx + u * TILE_W / 2 * k, cy + v * TILE_H / 2 * k


# ── tiles ──────────────────────────────────────────────────────────────────
def draw_floor(seed, variant):
    img = canvas(CELL_W, CELL_H)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    cx, cy = CELL_W / 2, BASE_Y

    d.polygon(PL(diamond(cx, cy)), fill=FLOOR_A, outline=FLOOR_OUT, width=W(2.5))
    d.polygon(PL(inset_diamond(cx, cy, 0.93)), fill=FLOOR_B)

    # bevel: upper-left edges catch light, lower-right edges fall dark
    d.line(PL([(0, BASE_Y), (cx, BASE_Y - 32), (CELL_W, BASE_Y)]),
           fill=FLOOR_LIGHT, width=W(2), joint="curve")
    d.line(PL([(3, BASE_Y + 1), (cx, BASE_Y + 30), (CELL_W - 3, BASE_Y + 1)]),
           fill=FLOOR_DARK, width=W(2), joint="curve")

    # flagstone cracks and pebbles kept well inside the diamond
    for _ in range(3):
        x0, y0 = rand_in_diamond(rng, cx, cy, 0.55)
        pts = [(x0, y0)]
        for _ in range(2):
            x0 += rng.uniform(-10, 12)
            y0 += rng.uniform(-4, 6)
            pts.append((x0, y0))
        d.line(PL(pts), fill=FLOOR_DARK, width=W(1.6), joint="curve")
    for _ in range(3):
        px, py = rand_in_diamond(rng, cx, cy, 0.7)
        r = rng.uniform(1.2, 2.4)
        d.ellipse(PL([(px - r, py - r * 0.6), (px + r, py + r * 0.6)]),
                  fill=FLOOR_LIGHT if rng.random() < 0.5 else FLOOR_DARK)

    if variant == 2:
        for _ in range(4):
            mx, my = rand_in_diamond(rng, cx, cy, 0.62)
            mr = rng.uniform(4, 9)
            d.ellipse(PL([(mx - mr, my - mr * 0.5), (mx + mr, my + mr * 0.5)]),
                      fill=MOSS)
            d.ellipse(PL([(mx - mr * 0.4, my - mr * 0.3), (mx + mr * 0.5, my + mr * 0.2)]),
                      fill=MOSS_DARK)
    if variant == 1:
        # a chipped corner
        d.polygon(PL([(cx + 18, cy - 12), (cx + 34, cy - 2), (cx + 22, cy + 4)]),
                  fill=FLOOR_DARK)

    poly_outline(d, PL(diamond(cx, cy)), FLOOR_OUT, W(2))
    return img


def draw_wall(seed, variant):
    img = canvas(CELL_W, CELL_H)
    d = ImageDraw.Draw(img)
    rng = random.Random(seed)
    H = 72
    bx, by = CELL_W / 2, BASE_Y
    top = [(64, 24), (128, 56), (64, 88), (0, 56)]
    left = [(0, 56), (64, 88), (64, 160), (0, 128)]
    right = [(64, 88), (128, 56), (128, 128), (64, 160)]
    silhouette = [(0, 56), (64, 24), (128, 56), (128, 128), (64, 160), (0, 128)]

    # body
    d.polygon(PL(silhouette), fill=WALL_LEFT)
    d.polygon(PL(right), fill=WALL_RIGHT)
    d.polygon(PL(top), fill=WALL_TOP)

    # stone courses on both faces (left slopes down, right slopes up)
    for t in (22, 44):
        d.line(PL([(0, 56 + t), (64, 88 + t)]),
               fill=WALL_OUT, width=W(1.6))
        d.line(PL([(64, 88 + t), (128, 56 + t)]),
               fill=WALL_OUT, width=W(1.6))
    for joint_x in (22, 46, 82, 106):
        y_top = 56 + joint_x * 0.5 if joint_x < 64 else 120 - joint_x * 0.5
        d.line(PL([(joint_x, y_top), (joint_x, y_top + 72)]),
               fill=WALL_OUT, width=W(1.4))

    # top face details
    d.polygon(PL(inset_diamond(64, 56, 0.82)), fill=WALL_TOP_LIGHT)
    d.line(PL([(2, 56), (64, 25)]), fill=WALL_TOP_LIGHT, width=W(2))
    d.line(PL([(126, 56), (64, 25)]), fill=WALL_TOP_DARK, width=W(2))
    for _ in range(2):
        x0 = 64 + rng.uniform(-18, 18)
        y0 = 56 + rng.uniform(-8, 8)
        d.line(PL([(x0, y0), (x0 + rng.uniform(-10, 10), y0 + rng.uniform(-5, 5))]),
               fill=WALL_TOP_DARK, width=W(1.4))

    # moss creeping from the base, kept inside the visible faces
    blobs = 5 if variant == 1 else 2
    for _ in range(blobs):
        if rng.random() < 0.5:
            mx = rng.uniform(12, 30)
            y_top = 56 + mx * 0.5 + 8
            y_bot = 128 + mx * 0.5 - 8
        else:
            mx = rng.uniform(98, 116)
            y_top = 120 - mx * 0.5 + 8
            y_bot = 192 - mx * 0.5 - 8
        my = rng.uniform(y_top, max(y_top + 1, y_bot))
        mr = rng.uniform(4, 8)
        d.ellipse(PL([(mx - mr, my - mr * 0.45), (mx + mr, my + mr * 0.45)]),
                  fill=MOSS)
        d.ellipse(PL([(mx - mr * 0.4, my - mr * 0.25), (mx + mr * 0.4, my + mr * 0.2)]),
                  fill=MOSS_DARK)

    # outlines last so silhouettes stay crisp
    poly_outline(d, PL(silhouette), WALL_OUT, W(2.4))
    poly_outline(d, PL(top), WALL_OUT, W(2))
    return img


def draw_rug():
    img = canvas(CELL_W, CELL_H)
    d = ImageDraw.Draw(img)
    cx, cy = CELL_W / 2, BASE_Y
    d.polygon(PL(diamond(cx, cy)), fill=RUG_BASE, outline=(72, 36, 34), width=W(2))
    d.polygon(PL(inset_diamond(cx, cy, 0.86)), fill=RUG_INNER)
    d.polygon(PL(inset_diamond(cx, cy, 0.80)), outline=RUG_BORDER, width=W(2.4))
    d.polygon(PL(inset_diamond(cx, cy, 0.50)), outline=RUG_BORDER, width=W(2))
    d.line(PL([(cx, cy - 16), (cx + 24, cy), (cx, cy + 16), (cx - 24, cy)]),
           fill=RUG_BORDER, width=W(1.6), joint="curve")
    return img


# ── hero ───────────────────────────────────────────────────────────────────
DIRS = [
    (1, 0), (0.707, 0.707), (0, 1), (-0.707, 0.707),
    (-1, 0), (-0.707, -0.707), (0, -1), (0.707, -0.707),
]


def _capsule(d, a, b, radius, fill, outline=None, ow=0):
    ax, ay = a
    bx, by = b
    if outline is not None:
        d.line([P(ax, ay), P(bx, by)], fill=outline, width=W(radius * 2 + ow))
        for x, y in (a, b):
            r = radius + ow / 2
            d.ellipse(PL([(x - r, y - r), (x + r, y + r)]), fill=outline)
    d.line([P(ax, ay), P(bx, by)], fill=fill, width=W(radius * 2))
    for x, y in (a, b):
        d.ellipse(PL([(x - radius, y - radius), (x + radius, y + radius)]), fill=fill)


def draw_goblin(img, col, phase, walking):
    d = ImageDraw.Draw(img)
    dx, dy = DIRS[col]
    cx, feet = HERO_FEET
    side = dx
    depth = dy
    swing = math.sin(phase) if walking else 0.0
    bob = (abs(math.sin(phase)) * 2.5 if walking
           else math.sin(phase) * 1.2)
    hip_y = feet - 24
    body_top = feet - 46 + bob
    shoulder_y = feet - 38 + bob
    head_r = 18.5
    head_cx = cx + side * 4
    head_cy = feet - 58 + bob * 0.6

    # ── legs (back leg first) ──
    for i in (1, 0):
        ph = phase + (0 if i == 0 else math.pi)
        sw = math.sin(ph) if walking else 0.0
        lift = max(0.0, sw) * 6.0 if walking else 0.0
        lx = (cx + (7 if i == 0 else -7)
              + side * sw * 6.5
              + (0.0 if abs(side) > 0.5 else sw * 1.8 * (1 if i == 0 else -1)))
        ly = feet - lift
        col_leg = PANTS if i == 0 else PANTS_DARK
        _capsule(d, (lx, hip_y + bob * 0.3), (lx + side * sw * 3.5, ly - 4),
                 4.6, col_leg, HERO_OUT, 3)
        # foot
        fx = lx + side * sw * 3.5
        d.ellipse(PL([(fx - 6, ly - 7), (fx + 7 + side * 2, ly)]),
                  fill=LEATHER_DARK, outline=HERO_OUT, width=W(1.6))

    # ── torso ──
    d.rounded_rectangle(PL([(cx - 16, body_top), (cx + 16, feet - 18 + bob)]),
                        radius=W(9), fill=TUNIC, outline=HERO_OUT, width=W(2))
    d.rounded_rectangle(PL([(cx - 16, body_top + 20), (cx + 16, feet - 19 + bob)]),
                        radius=W(6), fill=TUNIC_DARK)
    d.rounded_rectangle(PL([(cx - 17, body_top), (cx + 17, body_top + 24)]),
                        radius=W(9), fill=TUNIC)

    # belt
    d.rectangle(PL([(cx - 16, feet - 30 + bob * 0.4), (cx + 16, feet - 25 + bob * 0.4)]),
                fill=LEATHER_DARK)
    d.rectangle(PL([(cx - 4, feet - 31 + bob * 0.4), (cx + 4, feet - 24 + bob * 0.4)]),
                fill=BRASS, outline=HERO_OUT, width=W(1.2))

    # backpack when facing away
    if depth < -0.3:
        d.rounded_rectangle(PL([(cx - 11, body_top + 4), (cx + 11, body_top + 26)]),
                            radius=W(6), fill=LEATHER, outline=HERO_OUT, width=W(1.8))
        d.line(PL([(cx - 9, body_top + 10), (cx + 9, body_top + 10)]),
               fill=LEATHER_DARK, width=W(1.6))

    # ── arms ──
    arms = [(1, TUNIC), (-1, TUNIC_DARK)]
    for i, (sgn, sleeve) in enumerate(arms):
        ph = phase + (0 if sgn > 0 else math.pi)
        sw = math.sin(ph) if walking else 0.0
        sx = cx + sgn * (13 + abs(side) * 2)
        sy = shoulder_y + 2
        hx = sx + sgn * 2 + side * sw * 7.5
        hy = sy + 15 - abs(sw) * 3.0
        _capsule(d, (sx, sy), (hx, hy), 4.2, sleeve, HERO_OUT, 3)
        d.ellipse(PL([(hx - 4.4, hy - 4.4), (hx + 4.4, hy + 4.4)]),
                  fill=SKIN, outline=HERO_OUT, width=W(1.4))

    # ── ears behind the head ──
    ear_visible = []
    if abs(side) > 0.8:
        ear_visible = [1 if side > 0 else -1]
    else:
        ear_visible = [-1, 1]
    for e in ear_visible:
        base_x = head_cx + e * 14
        tip_x = head_cx + e * (30 + (6 if abs(side) > 0.8 else 0))
        tip_y = head_cy - 12
        pts = [(base_x, head_cy - 4), (tip_x, tip_y),
               (base_x + e * 3, head_cy + 12)]
        d.polygon(PL(pts), fill=SKIN, outline=HERO_OUT, width=W(1.8))
        inner = [(base_x, head_cy - 1), (tip_x - e * 5, tip_y + 4),
                 (base_x + e * 1.5, head_cy + 7)]
        d.polygon(PL(inner), fill=EAR_IN)

    # ── head ──
    d.ellipse(PL([(head_cx - head_r, head_cy - head_r),
                  (head_cx + head_r, head_cy + head_r)]),
              fill=SKIN, outline=HERO_OUT, width=W(2.2))
    d.ellipse(PL([(head_cx - head_r * 0.62, head_cy - head_r * 0.82),
                  (head_cx + head_r * 0.18, head_cy - head_r * 0.18)]),
              fill=SKIN_LIGHT)
    # lower-face shading
    d.arc(PL([(head_cx - head_r * 0.8, head_cy + 2),
              (head_cx + head_r * 0.8, head_cy + head_r * 1.1)]),
          0, 180, fill=SKIN_DARK, width=W(1.4))

    if depth > -0.35:
        # eyes
        if abs(side) > 0.8:
            ex = head_cx + side * 9
            d.ellipse(PL([(ex - 4.6, head_cy - 4), (ex + 4.6, head_cy + 4)]),
                      fill=EYE, outline=HERO_OUT, width=W(1))
            px = ex + side * 1.6
            d.ellipse(PL([(px - 2.1, head_cy - 1.8), (px + 2.1, head_cy + 2.2)]),
                      fill=PUPIL)
            d.ellipse(PL([(px - 0.9, head_cy - 1.2), (px + 0.2, head_cy - 0.2)]),
                      fill=(255, 255, 255))
        else:
            spread = 7.5 - abs(side) * 2
            for e in (-1, 1):
                ex = head_cx + e * spread + side * 4
                r = 4.4 if e * side >= 0 else 3.9
                d.ellipse(PL([(ex - r, head_cy - 4.4), (ex + r, head_cy + 4.2)]),
                          fill=EYE, outline=HERO_OUT, width=W(1))
                px = ex + side * 1.6
                d.ellipse(PL([(px - 2.0, head_cy - 1.6), (px + 2.0, head_cy + 2.2)]),
                          fill=PUPIL)
                d.ellipse(PL([(px - 0.9, head_cy - 1.0), (px + 0.2, head_cy)]),
                          fill=(255, 255, 255))
        # nose
        nx = head_cx + side * 13
        d.polygon(PL([(nx, head_cy + 2), (nx + side * 4 - 1, head_cy + 5),
                      (nx, head_cy + 7)]), fill=SKIN_DARK)
        # smile
        mx = head_cx + side * 5
        d.arc(PL([(mx - 5, head_cy + 7), (mx + 5, head_cy + 13)]),
              15, 165, fill=MOUTH, width=W(1.4))
    else:
        # back of the head: darker patch + leaf tuft
        d.arc(PL([(head_cx - head_r * 0.85, head_cy - head_r * 0.2),
                  (head_cx + head_r * 0.85, head_cy + head_r * 1.1)]),
              0, 180, fill=SKIN_DARK, width=W(5))
        for k in (-1, 0, 1):
            d.line(PL([(head_cx + k * 6, head_cy - head_r + 2),
                       (head_cx + k * 9, head_cy - head_r - 5)]),
                   fill=SKIN_DARK, width=W(2), joint="curve")


def build_hero_sheet():
    sheet = canvas(HERO_CW * 8, HERO_CH * 6)
    idle_phases = [math.pi / 2, 3 * math.pi / 2]
    walk_phases = [0, math.pi / 2, math.pi, 3 * math.pi / 2]
    for col in range(8):
        for row, ph in enumerate(idle_phases):
            sub = canvas(HERO_CW, HERO_CH)
            draw_goblin(sub, col, ph, False)
            sheet.alpha_composite(sub, (col * HERO_CW * SS, row * HERO_CH * SS))
        for k, ph in enumerate(walk_phases):
            sub = canvas(HERO_CW, HERO_CH)
            draw_goblin(sub, col, ph, True)
            sheet.alpha_composite(sub, (col * HERO_CW * SS, (2 + k) * HERO_CH * SS))
    save(sheet, "assets/sprites/hero.png")


# ── props ──────────────────────────────────────────────────────────────────
def prop_canvas(w, h):
    return canvas(w, h)


def draw_barrel():
    w, h = 64, 96
    img = prop_canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, base = w / 2, h / 2
    top, bot = base - 40, base
    d.rounded_rectangle(PL([(cx - 18, top + 6), (cx + 18, bot - 2)]),
                        radius=W(12), fill=(154, 106, 62), outline=OUT, width=W(2.2))
    d.ellipse(PL([(cx - 18, top - 6), (cx + 18, top + 14)]),
              fill=(176, 126, 78), outline=OUT, width=W(2))
    d.ellipse(PL([(cx - 12, top - 1), (cx + 12, top + 9)]), fill=(122, 82, 50))
    for t in (12, 28, 40):
        d.arc(PL([(cx - 18, base - 8 - t), (cx + 18, base + 10 - t)]),
              0, 180, fill=(90, 66, 44), width=W(2))
    for x in (-10, 0, 10):
        d.line(PL([(cx + x, top + 8), (cx + x * 1.15, bot - 6)]),
               fill=(128, 86, 52), width=W(1.6))
    for y in (top + 12, base - 14):
        d.rectangle(PL([(cx - 18, y), (cx + 18, y + 5)]), fill=(96, 104, 112))
        d.rectangle(PL([(cx - 19, y), (cx + 19, y + 2)]), fill=(132, 140, 150))
    d.line(PL([(cx - 13, top + 18), (cx - 13, base - 16)]),
           fill=(198, 154, 102), width=W(1.4))
    return img


def draw_crate():
    w, h = 96, 96
    img = prop_canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, base = w / 2, h / 2
    top = [(cx, base - 46), (cx + 30, base - 31), (cx, base - 16), (cx - 30, base - 31)]
    left = [(cx - 30, base - 31), (cx, base - 16), (cx, base + 14), (cx - 30, base - 1)]
    right = [(cx, base - 16), (cx + 30, base - 31), (cx + 30, base - 1), (cx, base + 14)]
    d.polygon(PL(left), fill=(150, 102, 56))
    d.polygon(PL(right), fill=(170, 118, 66))
    d.polygon(PL(top), fill=(196, 146, 88))
    for face, x0, x1 in ((left, cx - 30, cx), (right, cx, cx + 30)):
        for k in (0.33, 0.66):
            px = x0 + (x1 - x0) * k
            if px < cx:
                y_top = base - 31 + (px - (cx - 30)) * 0.5
            else:
                y_top = base - 16 - (px - cx) * 0.5
            d.line(PL([(px, y_top), (px, y_top + 30)]),
                   fill=(112, 74, 40), width=W(1.6))
    d.line(PL([(cx - 30, base - 31), (cx + 30, base - 31)]),
           fill=(112, 74, 40), width=W(1.6))
    d.line(PL([(cx - 30, base - 8), (cx, base + 7), (cx + 30, base - 8)]),
           fill=(112, 74, 40), width=W(2), joint="curve")
    poly_outline(d, PL(top), OUT, W(2))
    poly_outline(d, PL(left), OUT, W(2))
    poly_outline(d, PL(right), OUT, W(2))
    # nails
    for x, y in ((cx - 22, base - 24), (cx + 22, base - 24),
                 (cx - 22, base - 6), (cx + 22, base - 6)):
        d.ellipse(PL([(x - 1.4, y - 1.4), (x + 1.4, y + 1.4)]), fill=(210, 210, 214))
    return img


def draw_vase():
    w, h = 48, 80
    img = prop_canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, base = w / 2, h / 2
    body = [(cx - 11, base - 30), (cx - 15, base - 22), (cx - 14, base - 8),
            (cx - 6, base - 1), (cx + 6, base - 1), (cx + 14, base - 8),
            (cx + 15, base - 22), (cx + 11, base - 30)]
    d.polygon(PL(body), fill=(168, 104, 78), outline=OUT, width=W(2))
    d.ellipse(PL([(cx - 11, base - 36), (cx + 11, base - 26)]),
              fill=(190, 126, 94), outline=OUT, width=W(1.8))
    d.ellipse(PL([(cx - 7, base - 33), (cx + 7, base - 28)]), fill=(94, 58, 46))
    d.arc(PL([(cx - 13, base - 26), (cx + 13, base - 4)]),
          20, 160, fill=(210, 150, 112), width=W(1.6))
    for e in (-1, 1):
        d.arc(PL([(cx + e * 10 - 7, base - 31), (cx + e * 10 + 7, base - 19)]),
              250 if e < 0 else 70, 110 if e < 0 else 290,
              fill=OUT, width=W(1.6))
    return img


def draw_candle_stand():
    w, h = 64, 192
    img = prop_canvas(w, h)
    d = ImageDraw.Draw(img)
    cx, base = w / 2, h / 2
    d.ellipse(PL([(cx - 16, base - 7), (cx + 16, base + 3)]),
              fill=(74, 78, 92), outline=OUT, width=W(1.8))
    d.ellipse(PL([(cx - 9, base - 5), (cx + 9, base + 1)]), fill=(98, 102, 118))
    d.line(PL([(cx, base - 4), (cx, base - 44)]), fill=(86, 90, 106), width=W(4))
    d.ellipse(PL([(cx - 8, base - 50), (cx + 8, base - 38)]),
              fill=(104, 108, 124), outline=OUT, width=W(1.6))
    d.rectangle(PL([(cx - 5, base - 66), (cx + 5, base - 48)]),
                fill=(236, 226, 196), outline=OUT, width=W(1.4))
    d.ellipse(PL([(cx - 5, base - 70), (cx + 5, base - 62)]), fill=(250, 242, 214))
    # flame
    flame = [(cx, base - 86), (cx + 5, base - 76), (cx, base - 68), (cx - 5, base - 76)]
    d.polygon(PL(flame), fill=(255, 148, 62), outline=(214, 92, 40), width=W(1))
    d.polygon(PL([(cx, base - 81), (cx + 2.4, base - 75),
                  (cx, base - 71), (cx - 2.4, base - 75)]), fill=(255, 226, 140))
    return img


# ── fx ─────────────────────────────────────────────────────────────────────
def radial(size, power=2.2, color=(255, 255, 255)):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            r = math.hypot(x - c, y - c) / (size / 2)
            a = max(0.0, 1.0 - r) ** power
            px[x, y] = (*color, int(a * 255))
    return img


def build_fx():
    save(radial(256, 2.4), "assets/fx/light.png", False)
    save(radial(64, 2.0, (255, 210, 150)), "assets/fx/flame_glow.png", False)

    shadow = Image.new("RGBA", (96 * SS, 32 * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(shadow)
    d.ellipse(PL([(8, 6), (88, 26)]), fill=(0, 0, 0, 255))
    shadow = shadow.filter(ImageFilter.GaussianBlur(6 * SS / 3))
    px = shadow.load()
    for y in range(shadow.height):
        for x in range(shadow.width):
            r, g, b, a = px[x, y]
            px[x, y] = (0, 0, 0, int(a * 0.55))
    save(shadow, "assets/fx/shadow.png")

    mote = radial(32, 1.6)
    save(mote, "assets/fx/mote.png", False)

    # vignette 640x360
    w, h = 640, 360
    v = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = v.load()
    for y in range(h):
        for x in range(w):
            nx = (x - w / 2) / (w / 2)
            ny = (y - h / 2) / (h / 2)
            r = math.hypot(nx, ny * 0.82)
            a = max(0.0, (r - 0.52) / 0.62) ** 1.5 * 205
            px[x, y] = (4, 5, 9, int(min(255, a)))
    save(v, "assets/ui/vignette.png", False)


# ── main ───────────────────────────────────────────────────────────────────
def main():
    atlas = canvas(CELL_W * 4, CELL_H * 2)
    tiles = [
        (0, 0, draw_floor(11, 0)),
        (1, 0, draw_floor(29, 1)),
        (2, 0, draw_floor(47, 2)),
        (3, 0, draw_rug()),
        (0, 1, draw_wall(5, 0)),
        (1, 1, draw_wall(23, 1)),
    ]
    for col, row, img in tiles:
        atlas.alpha_composite(img, (col * CELL_W * SS, row * CELL_H * SS))
    # empty cells stay transparent
    save(atlas, "assets/tiles/iso_tiles.png")

    build_hero_sheet()
    save(draw_barrel(), "assets/props/barrel.png")
    save(draw_crate(), "assets/props/crate.png")
    save(draw_vase(), "assets/props/vase.png")
    save(draw_candle_stand(), "assets/props/candle_stand.png")
    build_fx()


if __name__ == "__main__":
    main()
