"""Arena environment: 1800x570 battle stage, 2 flag sheets, 2 fog layers."""
from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from artlib import BRASS, BRASS_HI, glow, new_layer, solid_ellipse, solid_poly

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "env")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")
W, H = 1800, 570
S = 1.5  # design px -> 1080p px


def px(v):
    return v * S


def make_arena() -> Image.Image:
    rng = random.Random(20261126)
    # base gradient
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    ys = np.linspace(0, 1, H)[:, None]
    top = np.array([7, 13, 19], np.float32)
    mid = np.array([11, 20, 27], np.float32)
    bot = np.array([6, 11, 16], np.float32)
    for i in range(3):
        col = np.where(ys < 0.5, top[i] * (1 - ys * 2) + mid[i] * ys * 2,
                       mid[i] * (1 - (ys - 0.5) * 2) + bot[i] * (ys - 0.5) * 2)
        arr[..., i] = col.astype(np.uint8)
    arr[..., 3] = 255
    img = Image.fromarray(arr, "RGBA")

    # team-side wash + furnace light pools
    glow(img, (px(300), H * 0.52), 620, (40, 150, 145), 0.15)
    glow(img, (W - px(300), H * 0.52), 620, (170, 72, 45), 0.13)
    glow(img, (W * 0.5, H * 0.55), 520, (40, 100, 110), 0.10)

    # --- hex deck floor -----------------------------------------------------
    layer = new_layer((W, H))
    d = ImageDraw.Draw(layer)
    R = 36.0
    dx = R * 1.5
    dy = math.sqrt(3) * R
    rows = int(H / dy) + 2
    cols = int(W / dx) + 2
    for gy in range(-1, rows):
        for gx in range(-1, cols):
            cx = gx * dx
            cy = gy * dy + (dy * 0.5 if gx % 2 else 0.0)
            pts = [(cx + math.cos(math.pi / 3 * i - math.pi / 6) * R * 0.985,
                    cy + math.sin(math.pi / 3 * i - math.pi / 6) * R * 0.985) for i in range(6)]
            v = rng.uniform(-5, 6)
            shade = (14 + v, 25 + v, 34 + v)
            d.polygon(pts, fill=(*[int(max(4, c)) for c in shade], 255),
                      outline=(40, 68, 80, 120))
            if rng.random() < 0.26:
                rx = cx + rng.uniform(-R * 0.5, R * 0.5)
                ry = cy + rng.uniform(-R * 0.4, R * 0.4)
                d.rectangle((rx - 4, ry - 2, rx + 4, ry + 2), fill=(7, 13, 18, 220))
                d.line((rx - 3, ry, rx + 3, ry), fill=(28, 46, 56, 220))
            if rng.random() < 0.18:
                for k in range(3):
                    a = math.pi / 3 * k
                    vx = cx + math.cos(a) * R * 0.9
                    vy = cy + math.sin(a) * R * 0.9
                    d.ellipse((vx - 1.6, vy - 1.6, vx + 1.6, vy + 1.6), fill=(54, 84, 94, 230))
    img.alpha_composite(layer)

    # --- central tide lane --------------------------------------------------
    lane = new_layer((W, H))
    ld = ImageDraw.Draw(lane)
    lx0, lx1 = px(432), px(768)  # design x 432..768? no: 600 center, 96 wide
    # 96 design wide centred at 600 -> 552..648 design
    lx0, lx1 = px(552), px(648)
    ld.rectangle((lx0, 0, lx1, H), fill=(12, 34, 42, 150))
    ld.rectangle((lx0, 0, lx0 + 3, H), fill=(74, 150, 160, 90))
    ld.rectangle((lx1 - 3, 0, lx1, H), fill=(74, 150, 160, 90))
    for y in range(20, int(H), 46):
        a = 26
        mid = (lx0 + lx1) / 2
        ld.line((mid, y, mid - 14, y + 12), fill=(110, 230, 230, a), width=2)
        ld.line((mid, y, mid + 14, y + 12), fill=(110, 230, 230, a), width=2)
    ld.rectangle((W / 2 - 1, 0, W / 2 + 1, H), fill=(120, 240, 240, 18))
    img.alpha_composite(lane)
    glow(img, (W / 2, H / 2), 220, (70, 190, 195), 0.18)

    # --- gates --------------------------------------------------------------
    def gate(cx, cy, team):
        col = (55, 224, 199) if team == 0 else (255, 98, 72)
        gw, gh = px(96), px(220)
        top = cy - gh / 2
        gl = new_layer((W, H))
        gd = ImageDraw.Draw(gl)
        # arch body
        gd.rounded_rectangle((cx - gw * 0.5, top, cx + gw * 0.5, top + gh), radius=gw * 0.42,
                             fill=(13, 24, 31, 235), outline=(40, 66, 78, 255), width=3)
        gd.rounded_rectangle((cx - gw * 0.34, top + 12, cx + gw * 0.34, top + gh - 6),
                             radius=gw * 0.3, fill=(6, 13, 18, 255),
                             outline=(24, 42, 52, 255), width=2)
        # inner spawn glow
        for k in range(3):
            gd.line((cx - gw * 0.26 + k * 10, top + gh * 0.34,
                     cx + gw * 0.26 - k * 10, top + gh * 0.34),
                    fill=(*col, 32), width=6)
        # pylons
        for sx in (-1, 1):
            gd.rectangle((cx + sx * gw * 0.54 - 8, top + gh * 0.12,
                          cx + sx * gw * 0.54 + 8, top + gh * 0.94),
                         fill=(20, 32, 40, 255), outline=(46, 74, 86, 255), width=2)
            for k in range(3):
                gd.ellipse((cx + sx * gw * 0.54 - 4, top + gh * (0.2 + k * 0.14) - 4,
                            cx + sx * gw * 0.54 + 4, top + gh * (0.2 + k * 0.14) + 4),
                           fill=(70, 110, 120, 220))
        # top cap + trim
        gd.polygon([(cx - gw * 0.56, top + 4), (cx, top - 18), (cx + gw * 0.56, top + 4),
                    (cx + gw * 0.46, top + 18), (cx, top - 2), (cx - gw * 0.46, top + 18)],
                   fill=(26, 42, 50, 255), outline=(90, 140, 150, 255))
        for k in range(4):
            yy = top + gh * (0.2 + k * 0.16)
            gd.line((cx - gw * 0.56, yy, cx - gw * 0.34, yy), fill=(*col, 225), width=4)
            gd.line((cx + gw * 0.34, yy, cx + gw * 0.56, yy), fill=(*col, 225), width=4)
        # spawn mouth: a bright inner threshold so the gate reads as an exit
        gd.line((cx - gw * 0.30, top + gh * 0.80, cx + gw * 0.30, top + gh * 0.80),
                fill=(*col, 190), width=5)
        glow(img, (cx, top + gh * 0.78), gw * 0.42, col, 0.22)
        grid = Image.new("L", (W, H), 0)
        ImageDraw.Draw(grid).rounded_rectangle((cx - gw * 0.3, top + 16, cx + gw * 0.3, top + gh - 10),
                                               radius=gw * 0.28, fill=70)
        grid = grid.filter(ImageFilter.GaussianBlur(10))
        colimg = Image.new("RGBA", (W, H), (*col, 0))
        colimg.putalpha(grid)
        img.alpha_composite(gl)
        img.alpha_composite(colimg)

    for cy in (px(70), px(240)):
        gate(px(48), cy, 0)
        gate(W - px(48), cy, 1)

    # --- central tide well --------------------------------------------------
    cx, cy = W / 2, H / 2
    well = new_layer((W, H))
    wd = ImageDraw.Draw(well)
    for r, a in ((px(64), 120), (px(56), 140), (px(40), 100)):
        wd.ellipse((cx - r, cy - r * 0.55, cx + r, cy + r * 0.55), outline=(90, 190, 195, a), width=3)
    wd.ellipse((cx - px(34), cy - px(20), cx + px(34), cy + px(20)), fill=(6, 18, 22, 235),
               outline=(120, 220, 220, 90), width=2)
    for i in range(3):
        a = math.tau * i / 3 - 0.5
        sx = cx + math.cos(a) * px(46)
        sy = cy + math.sin(a) * px(25)
        wd.ellipse((sx - 4, sy - 4, sx + 4, sy + 4), fill=(*BRASS, 220))
    img.alpha_composite(well)
    glow(img, (cx, cy), 150, (100, 240, 235), 0.25)

    # --- pipes / gantries ---------------------------------------------------
    pipe = new_layer((W, H))
    pd = ImageDraw.Draw(pipe)
    for y, hgt in ((0, 16), (H - 18, 18)):
        pd.rectangle((0, y, W, y + hgt), fill=(8, 15, 21, 255))
        pd.line((0, y + hgt - 1, W, y + hgt - 1), fill=(34, 56, 66, 255), width=2)
        for x in range(30, W, 90):
            pd.ellipse((x - 3, y + hgt * 0.35 - 3, x + 3, y + hgt * 0.35 + 3), fill=(52, 78, 88, 255))
    for x in (px(150), W - px(150)):
        pd.rectangle((x - 7, 0, x + 7, H), fill=(10, 18, 24, 120))
    img.alpha_composite(pipe)

    # corner brackets / small warning stripes
    d = ImageDraw.Draw(img)
    for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
        x = 18 if sx > 0 else W - 18
        y = 22 if sy > 0 else H - 22
        d.line((x, y, x + sx * 40, y), fill=(70, 120, 130, 80), width=2)
        d.line((x, y, x, y + sy * 40), fill=(70, 120, 130, 80), width=2)

    # vignette
    yy, xx = np.mgrid[0:H, 0:W]
    nx = (xx - W / 2) / (W / 2)
    ny = (yy - H / 2) / (H / 2)
    vig = np.clip((np.sqrt(nx ** 2 * 0.9 + ny ** 2) - 0.62) * 1.7, 0, 1) * 190
    black = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    black.putalpha(Image.fromarray(vig.astype(np.uint8), "L"))
    img.alpha_composite(black)
    return img


def make_flag(team: int) -> Image.Image:
    w, h = 96, 192
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    main = (55, 224, 199) if team == 0 else (255, 98, 72)
    dark = (10, 42, 40) if team == 0 else (58, 18, 14)
    light = (185, 255, 244) if team == 0 else (255, 214, 201)
    # pole
    d.rectangle((4, 6, 10, 188), fill=(70, 64, 54, 255))
    d.rectangle((4, 6, 7, 188), fill=(150, 128, 94, 255))
    d.ellipse((1, 2, 13, 14), fill=(*BRASS_HI, 255))
    d.ellipse((1, 182, 13, 192), fill=(*BRASS, 255))
    # banner with a wavy bottom edge
    top, bot = 14, 132
    pts = [(12, top)]
    for i in range(1, 17):
        x = 12 + (82) * i / 16
        y = top - 3 * math.sin(i * 0.9)
        pts.append((x, y))
    for i in range(16, -1, -1):
        x = 12 + 82 * i / 16
        y = bot + (8 * math.sin(i * 0.6 + 1.2) if i % 2 else -3)
        pts.append((x, y))
    d.polygon(pts, fill=(*main, 235), outline=(*light, 180))
    # inner shade + trim
    d.line([(14, top + 8), (88, top + 4), (88, bot - 8), (14, bot - 2)],
           fill=(*dark, 90), width=3)
    d.line([(12, top), (94, top - 3)], fill=(*light, 160), width=2)
    # emblem
    if team == 0:
        pts = [(60, 52), (76, 61), (76, 79), (60, 88), (44, 79), (44, 61)]
        d.polygon(pts, fill=(*dark, 200), outline=(*light, 230))
        d.ellipse((54, 64, 66, 76), fill=(*light, 220))
    else:
        d.polygon([(60, 50), (80, 76), (68, 76), (60, 64), (52, 76), (40, 76)],
                  fill=(*dark, 220), outline=(*light, 230))
        d.line((44, 84, 76, 84), fill=(*light, 190), width=3)
    # tattered holes
    for i in range(5):
        x = 18 + i * 16
        y = top + 30 + (i % 2) * 16
        d.ellipse((x, y, x + 5, y + 4), fill=(0, 0, 0, 0))
    return img


def make_fog(seed: int) -> Image.Image:
    rng = np.random.default_rng(seed)
    w, h = 512, 256
    base = rng.normal(0, 1, (h // 8, w // 8))
    layer = Image.fromarray(((base - base.min()) / (base.max() - base.min()) * 255).astype(np.uint8), "L")
    layer = layer.resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(6))
    arr = np.asarray(layer, np.float32) / 255.0
    arr = np.clip((arr - 0.25) * 1.5, 0, 1) ** 1.5
    alpha = (arr * 105).astype(np.uint8)
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(Image.fromarray(alpha, "L"))
    return img


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    arena = make_arena()
    p = os.path.join(OUT_DIR, "arena_1800x570.png")
    arena.save(p)
    print("ARENA", p, arena.size)
    for team, name in ((0, "flag_ally_96x192.png"), (1, "flag_enemy_96x192.png")):
        img = make_flag(team)
        pp = os.path.join(OUT_DIR, name)
        img.save(pp)
        print("FLAG", pp, img.size)
    for i, seed in enumerate((11, 23)):
        fog = make_fog(seed)
        pp = os.path.join(OUT_DIR, f"fog_{i}.png")
        fog.save(pp)
        print("FOG", pp, fog.size)
    # preview
    preview = Image.new("RGBA", (1920, 760), (8, 12, 16, 255))
    preview.alpha_composite(arena.resize((1800, 570), Image.LANCZOS), (60, 20))
    preview.alpha_composite(make_flag(0).resize((96, 192), Image.LANCZOS), (80, 610))
    preview.alpha_composite(make_flag(1).resize((96, 192), Image.LANCZOS), (190, 610))
    fog = make_fog(11).resize((900, 450), Image.LANCZOS)
    preview.alpha_composite(fog, (400, 620))
    preview.save(os.path.join(PREVIEW_DIR, "env_preview.png"))
    print("ENV_PREVIEW", os.path.join(PREVIEW_DIR, "env_preview.png"))


if __name__ == "__main__":
    main()
