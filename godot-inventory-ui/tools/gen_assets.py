#!/usr/bin/env python3
"""Original art generator for the inventory UI demo.

Everything in assets/ui and assets/bg is generated here from primitives
(gradients, bezier vines, silhouettes). No reference-game pixels are used.

Run: python3 tools/gen_assets.py
"""
from __future__ import annotations

import math
import random
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BG_DIR = ROOT / "assets" / "bg"
UI_DIR = ROOT / "assets" / "ui"
BG_DIR.mkdir(parents=True, exist_ok=True)
UI_DIR.mkdir(parents=True, exist_ok=True)

# ---------------------------------------------------------------- helpers


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def qbez(p0, p1, p2, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(
            (
                u * u * p0[0] + 2 * u * t * p1[0] + t * t * p2[0],
                u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1],
            )
        )
    return out


def cbez(p0, p1, p2, p3, n=56):
    out = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        out.append(
            (
                u**3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t**3 * p3[0],
                u**3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t**3 * p3[1],
            )
        )
    return out


def linear_gradient(size, c0, c1, angle_deg=90):
    """RGBA linear gradient, c0 -> c1 along angle (90 = top->bottom)."""
    w, h = size
    y = np.linspace(0, 1, h, dtype=np.float32)[:, None]
    x = np.linspace(0, 1, w, dtype=np.float32)[None, :]
    a = math.radians(angle_deg)
    t = x * math.cos(a) + y * math.sin(a)
    t = (t - t.min()) / max(1e-6, t.max() - t.min())
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for i in range(4):
        arr[..., i] = (c0[i] + (c1[i] - c0[i]) * t).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


def paste_round(base: Image.Image, img: Image.Image, radius: int):
    mask = rounded_mask(img.size, radius)
    base.alpha_composite(Image.composite(img, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))


def gold_layered_path(draw: ImageDraw.ImageDraw, pts, width, alpha=255, underline=True):
    """Metallic gold stroke: dark base, gold body, pale highlight offset up-left."""
    if underline:
        draw.line(pts, fill=(74, 47, 14, alpha), width=int(width * 1.75), joint="curve")
    draw.line(pts, fill=(176, 123, 44, alpha), width=int(width * 1.2), joint="curve")
    draw.line(pts, fill=(224, 178, 87, alpha), width=width, joint="curve")
    hl = [(x - width * 0.30, y - width * 0.38) for x, y in pts]
    draw.line(hl, fill=(255, 235, 168, int(alpha * 0.9)), width=max(1, int(width * 0.38)), joint="curve")


def soft_shadow(layer: Image.Image, radius=16, color=(0, 0, 0, 120)):
    return layer.filter(ImageFilter.GaussianBlur(radius))


def make_radial_glow(size=512, inner=(255, 255, 255, 255), outer=(255, 255, 255, 0), power=2.2):
    w = h = size
    yy, xx = np.mgrid[0:h, 0:w]
    cx = cy = (size - 1) / 2
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (size / 2)
    t = np.clip(d, 0, 1) ** power
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    for i in range(4):
        arr[..., i] = (inner[i] + (outer[i] - inner[i]) * t).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


# ---------------------------------------------------------------- background

def draw_pagoda(d: ImageDraw.ImageDraw, cx, base_y, base_w, tiers, col, rim, win_col, seed=0):
    """Stylised multi-tier Chinese roof silhouette (original geometry)."""
    rnd = random.Random(seed)
    y = base_y
    for i in range(tiers):
        tw = base_w * (1 - i * 0.155)
        th = 46 - i * 3
        body_h = 48 - i * 4
        # body wall
        d.rectangle([cx - tw * 0.32, y - body_h, cx + tw * 0.32, y], fill=col)
        # windows
        wn = max(1, 3 - i // 2)
        for k in range(wn):
            wx = cx - tw * 0.24 + k * (tw * 0.48 / max(1, wn - 1)) if wn > 1 else cx
            d.rounded_rectangle([wx - 5, y - body_h * 0.7, wx + 5, y - body_h * 0.28],
                                radius=2, fill=win_col)
        # curved roof: upturned eaves via cubic beziers
        top = y - body_h - th * 0.6
        left = cx - tw * 0.62
        right = cx + tw * 0.62
        ridge_l = cx - tw * 0.22
        ridge_r = cx + tw * 0.22
        pts_top = cbez((left, y - body_h - 2), (left + tw * 0.18, top - th * 0.25),
                       (ridge_l, top - th * 0.35), (ridge_l, top))
        pts_top += cbez((ridge_l, top), (cx, top - th * 0.15), (ridge_r, top),
                        (ridge_r, top))[1:]
        pts_top += cbez((ridge_r, top), (right - tw * 0.18, top - th * 0.25),
                        (right, y - body_h - 2), (right, y - body_h - 2))[1:]
        body = pts_top + [(right, y - body_h + 4), (left, y - body_h + 4)]
        d.polygon(body, fill=col)
        # gold rim along eaves
        d.line(pts_top, fill=rim, width=2)
        # eave tips
        d.ellipse([left - 5, y - body_h - 7, left + 5, y - body_h + 3], fill=rim)
        d.ellipse([right - 5, y - body_h - 7, right + 5, y - body_h + 3], fill=rim)
        # finial
        if i == tiers - 1:
            d.line([(cx, top), (cx, top - 26)], fill=rim, width=3)
            d.ellipse([cx - 6, top - 34, cx + 6, top - 22], fill=rim)
        y -= body_h + th * 0.9


def make_background():
    W, H = 2560, 1440
    rnd = random.Random(20261121)
    # --- sky
    sky = linear_gradient((W, H), (7, 22, 35, 255), (21, 66, 83, 255), 100)
    # horizon warmth + teal light
    arr = np.array(sky).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    t = np.clip((yy / H - 0.34) / 0.36, 0, 1)
    arr[..., 0] += (18 * t)[..., None][..., 0] * 0.4
    arr[..., 1] += (26 * t)[..., None][..., 0] * 0.4
    sky = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")

    # moon + halo
    moon_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    md = ImageDraw.Draw(moon_layer)
    mx, my = int(W * 0.755), int(H * 0.235)
    for r, a in [(420, 16), (300, 28), (210, 40), (150, 60)]:
        md.ellipse([mx - r, my - r, mx + r, my + r], fill=(160, 226, 242, a))
    moon_layer = moon_layer.filter(ImageFilter.GaussianBlur(60))
    sky.alpha_composite(moon_layer)
    disc = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dd = ImageDraw.Draw(disc)
    dd.ellipse([mx - 94, my - 94, mx + 94, my + 94], fill=(233, 250, 249, 245))
    dd.ellipse([mx - 68, my - 60, mx + 10, my + 18], fill=(245, 253, 252, 45))
    dd.ellipse([mx + 18, my + 30, mx + 52, my + 62], fill=(196, 225, 230, 24))
    dd.ellipse([mx - 58, my + 42, mx - 32, my + 66], fill=(196, 225, 230, 18))
    disc = disc.filter(ImageFilter.GaussianBlur(3))
    sky.alpha_composite(disc)

    # stars / motes
    st = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    for _ in range(260):
        x = rnd.randint(0, W - 1)
        y = rnd.randint(0, int(H * 0.62))
        r = rnd.choice([1, 1, 1, 2, 2, 3])
        a = rnd.randint(18, 90)
        sd.ellipse([x - r, y - r, x + r, y + r], fill=(205, 240, 250, a))
    sky.alpha_composite(st.filter(ImageFilter.GaussianBlur(0.6)))

    # wispy high clouds
    cl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cl)
    for i in range(14):
        cx, cy = rnd.randint(0, W), rnd.randint(60, int(H * 0.45))
        w_, h_ = rnd.randint(220, 620), rnd.randint(24, 60)
        col = (190, 232, 242, rnd.randint(10, 26))
        cd.ellipse([cx - w_, cy - h_, cx + w_, cy + h_], fill=col)
    cl = cl.filter(ImageFilter.GaussianBlur(38))
    sky.alpha_composite(cl)

    # --- mountain ridges
    def ridge(y_base, amp, color, seed, blur=0):
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        pts = []
        r2 = random.Random(seed)
        for x in range(0, W + 40, 40):
            y = y_base
            y += math.sin(x * 0.0017 + seed) * amp
            y += math.sin(x * 0.006 + seed * 2.1) * amp * 0.42
            y += r2.uniform(-amp * 0.16, amp * 0.16)
            pts.append((x, y))
        poly = pts + [(W, H), (0, H)]
        d.polygon(poly, fill=color)
        if blur:
            layer = layer.filter(ImageFilter.GaussianBlur(blur))
        return layer

    sky.alpha_composite(ridge(H * 0.56, 46, (26, 74, 90, 190), 3))
    # mist between ridges
    mist = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    md = ImageDraw.Draw(mist)
    for i in range(9):
        y = int(H * (0.47 + i * 0.035))
        md.ellipse([-300 + i * 120, y, W + 200, y + 90], fill=(180, 226, 236, rnd.randint(10, 24)))
    sky.alpha_composite(mist.filter(ImageFilter.GaussianBlur(32)))
    sky.alpha_composite(ridge(H * 0.66, 60, (17, 54, 68, 235), 8))
    sky.alpha_composite(ridge(H * 0.78, 80, (10, 38, 50, 255), 12))

    # cloud sea
    cloud = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cdd = ImageDraw.Draw(cloud)
    for i in range(24):
        cx = int(W * rnd.random())
        cy = int(H * (0.66 + 0.11 * rnd.random()))
        w_ = rnd.randint(180, 520)
        h_ = rnd.randint(26, 74)
        cdd.ellipse([cx - w_, cy - h_, cx + w_, cy + h_], fill=(160, 214, 226, rnd.randint(16, 38)))
    cloud = cloud.filter(ImageFilter.GaussianBlur(30))
    sky.alpha_composite(cloud)

    # --- side palaces (mostly edge visibility when backpack is open)
    palace = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(palace)
    far_col = (8, 27, 37, 255)
    rim = (214, 168, 92, 175)
    win = (255, 202, 118, 235)
    # left cliff palace
    draw_pagoda(pd, int(W * 0.115), int(H * 0.70), 520, 4, far_col, rim, win, seed=1)
    # right pavilion (partly visible behind side nav)
    draw_pagoda(pd, int(W * 0.905), int(H * 0.74), 560, 4, far_col, rim, win, seed=2)
    # distant central pagoda top (secret when panel is open)
    draw_pagoda(pd, int(W * 0.50), int(H * 0.60), 240, 3, (5, 18, 26, 255), (150, 118, 66, 110), (255, 190, 100, 120), seed=5)
    palace = palace.filter(ImageFilter.GaussianBlur(1.2))
    sky.alpha_composite(palace)

    # lanterns at the open edges
    lan = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lan)
    lanterns = [
        (W * 0.958, H * 0.34, 26),
        (W * 0.958, H * 0.55, 20),
        (W * 0.035, H * 0.42, 22),
        (W * 0.045, H * 0.77, 18),
        (W * 0.965, H * 0.82, 16),
    ]
    for lx, ly, r in lanterns:
        for rr, aa in [(r * 5, 14), (r * 3, 26), (r * 1.8, 44)]:
            ld.ellipse([lx - rr, ly - rr, lx + rr, ly + rr], fill=(255, 168, 84, aa))
        ld.line([(lx, ly - r * 6), (lx, ly - r * 1.2)], fill=(26, 18, 20, 200), width=3)
        ld.ellipse([lx - r, ly - r, lx + r, ly + r], fill=(255, 190, 104, 250))
        ld.ellipse([lx - r * 0.45, ly - r * 0.55, lx + r * 0.2, ly], fill=(255, 232, 174, 200))
        ld.rectangle([lx - r * 0.55, ly - r * 1.35, lx + r * 0.55, ly - r * 1.05], fill=(150, 46, 42, 240))
    lan = lan.filter(ImageFilter.GaussianBlur(1.2))
    sky.alpha_composite(lan)

    # moon bridge across the close-screen courtyard
    bridge = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bridge)
    x0, x1 = int(W * 0.26), int(W * 0.74)
    ydeck = int(H * 0.845)
    peak = int(H * 0.765)
    deck = cbez((x0, ydeck), (int(W * 0.37), peak), (int(W * 0.63), peak), (x1, ydeck), 90)
    bd.polygon(deck + [(x1, H), (x0, H)], fill=(6, 20, 27, 255))
    bd.line(deck, fill=(178, 136, 70, 170), width=4)
    # railing + lantern posts
    for i in range(9):
        t = i / 8
        idx = int(t * (len(deck) - 1))
        px, py = deck[idx]
        bd.line([(px, py), (px, py - 46)], fill=(7, 21, 28, 255), width=6)
        bd.ellipse([px - 4, py - 52, px + 4, py - 44], fill=(188, 145, 76, 200))
        if i in (1, 3, 5, 7):
            gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
            gld = ImageDraw.Draw(gl)
            for rr, aa in [(52, 20), (30, 36), (16, 60)]:
                gld.ellipse([px - rr, py - 70 - rr, px + rr, py - 70 + rr], fill=(255, 170, 86, aa))
            bridge.alpha_composite(gl.filter(ImageFilter.GaussianBlur(12)))
            bd.ellipse([px - 10, py - 80, px + 10, py - 60], fill=(255, 190, 104, 245))
            bd.ellipse([px - 4, py - 76, px + 3, py - 68], fill=(255, 236, 180, 210))
    # waterline + reflection
    bd.rectangle([0, int(H * 0.845), W, H], fill=(4, 14, 20, 90))
    for i in range(5):
        yy = int(H * 0.86) + i * 18
        bd.line([(x0 - 80, yy), (x1 + 80, yy)], fill=(255, 180, 110, max(0, 30 - i * 6)), width=2)
    bridge = bridge.filter(ImageFilter.GaussianBlur(0.8))
    sky.alpha_composite(bridge)

    # foreground railing / roof edge (only bottom sliver visible)
    fg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fg)
    fd.rectangle([0, int(H * 0.965), W, H], fill=(4, 12, 18, 255))
    for x in range(-80, W + 160, 220):
        fd.line([(x, int(H * 0.955)), (x + 50, H)], fill=(7, 19, 27, 255), width=18)
        fd.ellipse([x - 12, int(H * 0.945), x + 26, int(H * 0.972)], fill=(8, 22, 30, 255))
        fd.arc([x - 30, int(H * 0.94), x + 60, int(H * 1.01)], 190, 350, fill=(150, 112, 55, 120), width=2)
    sky.alpha_composite(fg)

    # drifting petals
    pet = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd2 = ImageDraw.Draw(pet)
    for _ in range(46):
        x = rnd.randint(0, W)
        y = rnd.randint(int(H * 0.2), int(H * 0.92))
        s = rnd.uniform(1.3, 3.4)
        a = rnd.randint(30, 110)
        col = rnd.choice([(255, 220, 230, a), (200, 245, 250, a), (255, 228, 170, a)])
        pd2.polygon([(x, y - s * 2), (x + s, y), (x, y + s * 2), (x - s, y)], fill=col)
    sky.alpha_composite(pet.filter(ImageFilter.GaussianBlur(0.5)))

    # vignette
    vg = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    vd = ImageDraw.Draw(vg)
    vd.rectangle([0, 0, W, H], fill=(3, 10, 16, 20))
    for i in range(14):
        a = 10 + i * 4
        m = 30 + i * 28
        vd.rounded_rectangle([m, m, W - m, H - m], radius=120, outline=(0, 0, 0, a), width=90)
    vg = vg.filter(ImageFilter.GaussianBlur(80))
    sky.alpha_composite(vg)

    sky = sky.convert("RGB")
    sky.save(BG_DIR / "night_palace.png", optimize=True)
    print("bg/night_palace.png", sky.size)


# ---------------------------------------------------------------- panel

def make_panel():
    """1193x659 ice-blue panel matching the reference's 1:1 proportion study.

    Palette sampled from the reference: top #9DC4EC -> bottom #6CA0D6,
    thin gold frame (dark base + gold + pale highlight), small corner cloud
    flourishes. Geometry and pixels are our own; the reference is not embedded.
    """
    LW, LH = 1193, 659
    k = 3  # draw scale, downsample to 2x
    W, H = LW * k, LH * k
    out_scale = 2
    OUT = (LW * out_scale, LH * out_scale)
    radius = 15 * k

    # base gradient, slightly brighter on the paper-doll (left) side
    base = linear_gradient((W, H), (158, 196, 236, 250), (105, 157, 208, 248), 100)
    arr = np.array(base).astype(np.float32)
    yy, xx = np.mgrid[0:H, 0:W]
    cxp, cyp = int(W * 0.25), int(H * 0.34)
    rad = np.sqrt(((xx - cxp) / (W * 0.46)) ** 2 + ((yy - cyp) / (H * 0.46)) ** 2)
    halo = np.clip(1 - rad, 0, 1) ** 1.6
    for i in range(3):
        arr[..., i] += halo * 20
    # vertical sheen: brighter top, deeper bottom (reference sampled 153/191/233 -> 112/160/209)
    yy01 = (yy / max(1, H - 1)).astype(np.float32)
    arr[..., 0] -= yy01 * 14
    arr[..., 1] -= yy01 * 8
    arr[..., 2] -= yy01 * 4
    base = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")
    base.putalpha(250)

    # clip everything to the panel silhouette
    silhouette = rounded_mask((W, H), radius)
    content = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    content.alpha_composite(base)

    # very faint cloud curls (original geometry)
    clouds = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(clouds)

    def cloud_curl(cx, cy, r, alpha):
        for i in range(3):
            rr = r * (1 - i * 0.28)
            cd.arc([cx - rr, cy - rr, cx + rr, cy + rr], 25 + i * 25, 300 + i * 20,
                   fill=(255, 255, 255, alpha - i * 4), width=int(2.2 * k))
        cd.arc([cx - r * 1.9, cy - r * 0.5, cx + r * 1.4, cy + r * 1.4], 200, 340,
               fill=(255, 255, 255, alpha - 6), width=int(1.6 * k))
    for cx, cy, r, a in [
        (W * 0.82, H * 0.16, 70 * k, 13),
        (W * 0.90, H * 0.62, 90 * k, 10),
        (W * 0.12, H * 0.86, 80 * k, 11),
        (W * 0.52, H * 0.94, 90 * k, 8),
    ]:
        cloud_curl(cx, cy, r, a)
    clouds = clouds.filter(ImageFilter.GaussianBlur(5 * k))
    content.alpha_composite(clouds)

    # thin gold frame (sampled: dark base, gold, pale highlight) — reference
    # border is ~2 px at 529 wide -> ~5 px at 1280.
    d = ImageDraw.Draw(content)
    d.rounded_rectangle([4 * k, 4 * k, W - 4 * k, H - 4 * k], radius=radius,
                        outline=(68, 47, 20, 255), width=int(4 * k))
    d.rounded_rectangle([7 * k, 7 * k, W - 7 * k, H - 7 * k], radius=13 * k,
                        outline=(168, 124, 58, 255), width=int(2.2 * k))
    d.rounded_rectangle([10 * k, 10 * k, W - 10 * k, H - 10 * k], radius=12 * k,
                        outline=(240, 214, 150, 235), width=max(1, int(1.2 * k)))
    d.rounded_rectangle([12 * k, 12 * k, W - 12 * k, H - 12 * k], radius=11 * k,
                        outline=(255, 255, 255, 55), width=max(1, int(0.8 * k)))

    # small corner cloud flourishes (16px logical), lower contrast than v1
    orn = Image.new("RGBA", (300 * k, 300 * k), (0, 0, 0, 0))
    od = ImageDraw.Draw(orn)
    vine_a = qbez((26 * k, 250 * k), (24 * k, 100 * k), (100 * k, 26 * k), 56) + \
        qbez((100 * k, 26 * k), (170 * k, 24 * k), (250 * k, 24 * k), 40)[1:]
    gold_layered_path(od, vine_a, width=int(3.0 * k), alpha=170)
    for i in range(3):
        rr = (30 - i * 8) * k
        od.arc([60 * k - rr, 60 * k - rr, 60 * k + rr, 60 * k + rr], 40 + i * 30, 330 + i * 20,
               fill=(238, 200, 126, 180), width=int(1.8 * k))
    cx, cy = 52 * k, 52 * k
    od.polygon([(cx, cy - 10 * k), (cx + 10 * k, cy), (cx, cy + 10 * k), (cx - 10 * k, cy)],
               fill=(206, 158, 74, 210), outline=(86, 56, 17, 220))
    od.polygon([(cx, cy - 5 * k), (cx + 5 * k, cy), (cx, cy + 5 * k), (cx - 5 * k, cy)],
               fill=(255, 235, 172, 230))
    orn = orn.filter(ImageFilter.GaussianBlur(0.35 * k))
    orn = orn.resize((int(300 * k * 0.17), int(300 * k * 0.17)), Image.LANCZOS)
    orn.putalpha(orn.getchannel("A").point(lambda a: int(a * 0.72)))
    ow, oh = orn.size
    positions = [
        (0, 0, 0),  # tl
        (W - ow, 0, Image.ROTATE_270),  # tr
        (0, H - oh, Image.ROTATE_90),  # bl
        (W - ow, H - oh, Image.ROTATE_180),  # br
    ]
    for x, y, rot in positions:
        o = orn.rotate(rot, expand=True) if rot else orn
        content.alpha_composite(o, (x, y))

    # keep the gold frame inside the silhouette
    content.putalpha(Image.composite(content.getchannel("A"), Image.new("L", (W, H), 0), silhouette))
    content = content.resize(OUT, Image.LANCZOS)
    content.save(UI_DIR / "panel.png", optimize=True)
    print("ui/panel.png", content.size)


def make_ribbon():
    LW, LH = 260, 90
    k = 6
    OUT = (LW * 2, LH * 2)
    W, H = LW * k, LH * k
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    def tail(x0, x1, flip=False):
        pts = [(x0, 22 * k), (x1, 14 * k), (x1 + 18 * k, 26 * k), (x1 + 4 * k, 45 * k),
               (x1 + 18 * k, 64 * k), (x1, 76 * k), (x0, 68 * k)]
        d.polygon(pts, fill=(118, 20, 30, 255), outline=(88, 12, 20, 255))

    tail(52 * k, 14 * k, True)
    tail(208 * k, 246 * k)
    # central plate
    d.rounded_rectangle([28 * k, 10 * k, 232 * k, 80 * k], radius=14 * k, fill=(126, 21, 30, 255))
    # red gradient inside
    grad = linear_gradient((int(204 * k), int(70 * k)), (179, 48, 52, 255), (113, 15, 25, 255), 90)
    mask = rounded_mask(grad.size, 13 * k)
    img.alpha_composite(Image.composite(grad, Image.new("RGBA", grad.size, (0, 0, 0, 0)), mask), (28 * k, 10 * k))
    # gold trims
    for inset, wd, col in [(0, 3.2, (94, 59, 17)), (1.6, 2.4, (219, 175, 92)), (4.0, 1.0, (255, 235, 170))]:
        d.rounded_rectangle([(28 + inset) * k, (10 + inset) * k, (232 - inset) * k, (80 - inset) * k],
                            radius=(14 - inset * 0.7) * k,
                            outline=(col[0], col[1], col[2], 240), width=int(wd * k))
    # tails trim
    for x0, x1 in [(52, 14), (208, 246)]:
        pts = [(x0 * k, 22 * k), (x1 * k, 14 * k), ((x1 + 18) * k, 26 * k), ((x1 + 4) * k, 45 * k),
               ((x1 + 18) * k, 64 * k), (x1 * k, 76 * k), (x0 * k, 68 * k)]
        d.line(pts + [pts[0]], fill=(219, 175, 92, 230), width=int(2.2 * k), joint="curve")
    # gold cloud ornament at top center
    for i, rr in enumerate([20, 13, 7]):
        d.arc([(130 - rr) * k, (30 - rr * 0.7) * k, (130 + rr) * k, (30 + rr * 1.3) * k],
              200, 340, fill=(255, 230, 160, 210), width=int(1.6 * k))
    # corner studs
    for x in (40, 220):
        for y in (24, 66):
            d.ellipse([(x - 2.4) * k, (y - 2.4) * k, (x + 2.4) * k, (y + 2.4) * k],
                      fill=(255, 233, 166, 240), outline=(92, 56, 16, 255))
    # hanging tassels
    for x in (62, 198):
        d.line([(x * k, 80 * k), (x * k, 84 * k)], fill=(188, 140, 60, 230), width=int(1.6 * k))
        d.ellipse([(x - 2.6) * k, (83 * k), (x + 2.6) * k, (88 * k)], fill=(188, 52, 52, 235))

    # soft drop shadow copy
    sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sh.alpha_composite(img)
    sh = sh.filter(ImageFilter.GaussianBlur(2.2 * k))
    sh.putalpha(sh.getchannel("A").point(lambda a: int(a * 0.45)))
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.alpha_composite(sh, (0, int(2 * k)))
    shadow.alpha_composite(img)
    shadow = shadow.resize(OUT, Image.LANCZOS)
    shadow.save(UI_DIR / "ribbon.png", optimize=True)
    print("ui/ribbon.png", shadow.size)


def make_close_button():
    LW = 58
    k = 8
    OUT = (LW * 4, LW * 4)
    W = LW * k
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    cx = cy = W // 2

    # halo
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for rr, aa in [(52, 22), (44, 38), (38, 52)]:
        gd.ellipse([cx - rr * k / 2, cy - rr * k / 2, cx + rr * k / 2, cy + rr * k / 2],
                   fill=(255, 214, 130, aa))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5 * k)))

    d = ImageDraw.Draw(img)
    # metallic ring
    radii = [(27.5, (84, 55, 19)), (26.0, (168, 113, 47)), (23.0, (236, 196, 113)),
             (21.0, (196, 143, 63)), (18.0, (111, 74, 26))]
    for r, col in radii:
        d.ellipse([cx - r * k, cy - r * k, cx + r * k, cy + r * k], fill=col)
    # inner bronze disc (reference close button: gold rim + bronze face)
    disc = Image.new("RGBA", (int(34 * k), int(34 * k)), (0, 0, 0, 0))
    grad = linear_gradient(disc.size, (128, 92, 54, 255), (62, 42, 24, 255), 90)
    mask = Image.new("L", disc.size, 0)
    ImageDraw.Draw(mask).ellipse([0, 0, disc.size[0] - 1, disc.size[1] - 1], fill=255)
    disc.alpha_composite(Image.composite(grad, Image.new("RGBA", disc.size, (0, 0, 0, 0)), mask))
    img.alpha_composite(disc, (int(cx - 17 * k), int(cy - 17 * k)))
    # inner rim
    for r, col in [(16.4, (255, 225, 160, 220)), (15.0, (90, 46, 24, 230))]:
        d.ellipse([cx - r * k, cy - r * k, cx + r * k, cy + r * k], outline=col, width=int(0.9 * k))
    # X glyph
    for ang in (45, -45):
        bar = Image.new("RGBA", (int(34 * k), int(34 * k)), (0, 0, 0, 0))
        bd = ImageDraw.Draw(bar)
        bd.rounded_rectangle([4 * k, 15.2 * k, 30 * k, 18.8 * k], radius=1.8 * k,
                             fill=(247, 211, 133, 255), outline=(83, 48, 17, 255), width=int(0.5 * k))
        bd.rounded_rectangle([5 * k, 15.9 * k, 29 * k, 17.2 * k], radius=0.6 * k,
                             fill=(255, 243, 200, 200))
        bar = bar.rotate(ang, resample=Image.BICUBIC, center=(17 * k, 17 * k))
        img.alpha_composite(bar, (int(cx - 17 * k), int(cy - 17 * k)))
    # 4 studs
    for a in range(4):
        ang = math.radians(a * 90 + 45)
        x = cx + math.cos(ang) * 22 * k
        y = cy + math.sin(ang) * 22 * k
        d.ellipse([x - 1.7 * k, y - 1.7 * k, x + 1.7 * k, y + 1.7 * k], fill=(255, 240, 188, 230))

    # shadow
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sh = img.filter(ImageFilter.GaussianBlur(2.4 * k))
    sh.putalpha(sh.getchannel("A").point(lambda a: int(a * 0.5)))
    shadow.alpha_composite(sh, (0, int(1.2 * k)))
    shadow.alpha_composite(img)
    shadow = shadow.resize(OUT, Image.LANCZOS)
    shadow.save(UI_DIR / "close.png", optimize=True)
    print("ui/close.png", shadow.size)


def make_glow():
    g = make_radial_glow(512, (255, 255, 255, 255), (255, 255, 255, 0), 2.1)
    g.save(UI_DIR / "glow.png", optimize=True)
    # small sparkle star
    s = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    sd = ImageDraw.Draw(s)
    cx = cy = 128
    for r, a in [(120, 30), (80, 50), (50, 80)]:
        sd.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(255, 240, 190, a))
    s = s.filter(ImageFilter.GaussianBlur(20))
    sd = ImageDraw.Draw(s)
    sd.polygon([(cx, 10), (cx + 10, cy), (cx, 246), (cx - 10, cy)], fill=(255, 250, 225, 235))
    sd.polygon([(10, cy), (cx, cy - 10), (246, cy), (cx, cy + 10)], fill=(255, 250, 225, 235))
    s = s.filter(ImageFilter.GaussianBlur(1.5))
    s.save(UI_DIR / "sparkle.png", optimize=True)
    print("ui/glow.png", g.size)


def make_rune_ring():
    W = 1280
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = W // 2
    col = (198, 240, 255, 120)
    col2 = (255, 255, 255, 90)
    # glow arcs
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for r, wd, a in [(475, 10, 26), (420, 14, 18), (330, 8, 22)]:
        gd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=(160, 235, 255, a), width=wd)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(12)))
    # dashed outer ring
    for a0 in range(0, 360, 12):
        d.arc([cx - 492, cy - 492, cx + 492, cy + 492], a0, a0 + 6,
              fill=(226, 250, 255, 150), width=5)
    d.ellipse([cx - 432, cy - 432, cx + 432, cy + 432], outline=(188, 235, 246, 80), width=2)
    d.ellipse([cx - 350, cy - 350, cx + 350, cy + 350], outline=(188, 235, 246, 55), width=2)
    # rune arcs
    for a0, span in [(-90, 64), (20, 50), (100, 70), (200, 44), (280, 58)]:
        d.arc([cx - 392, cy - 392, cx + 392, cy + 392], a0, a0 + span,
              fill=(210, 246, 255, 130), width=4)
        d.arc([cx - 380, cy - 380, cx + 380, cy + 380], a0, a0 + span,
              fill=(120, 200, 230, 55), width=10)
    # sigils: radial diamonds + tiny glyph strokes
    for i in range(16):
        ang = math.radians(i * 22.5)
        r = 456
        x = cx + math.cos(ang) * r
        y = cy + math.sin(ang) * r
        s = 9 if i % 2 == 0 else 5
        d.polygon([(x, y - s), (x + s, y), (x, y + s), (x - s, y)],
                  fill=(220, 248, 255, 145 if i % 2 == 0 else 90))
    for i in range(8):
        ang = math.radians(i * 45 + 22.5)
        r = 308
        x = cx + math.cos(ang) * r
        y = cy + math.sin(ang) * r
        d.line([(x - 7, y - 8), (x, y + 6)], fill=(200, 242, 255, 120), width=3)
        d.line([(x + 7, y - 8), (x, y + 6)], fill=(200, 242, 255, 120), width=3)
        d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(255, 255, 255, 150))
    # lotus petals at cardinal points
    for ang_deg in (0, 90, 180, 270):
        ang = math.radians(ang_deg)
        x = cx + math.cos(ang) * 392
        y = cy + math.sin(ang) * 392
        pet = [(x, y - 20), (x + 12, y), (x, y + 20), (x - 12, y)]
        d.polygon(pet, outline=(230, 250, 255, 170), width=3)
    img.save(UI_DIR / "rune_ring.png", optimize=True)
    print("ui/rune_ring.png", img.size)


def make_vignette():
    # radial border vignette overlay used on top of the background
    W, H = 1280, 720
    yy, xx = np.mgrid[0:H, 0:W]
    nx = (xx - W / 2) / (W / 2)
    ny = (yy - H / 2) / (H / 2)
    d = np.sqrt(nx ** 2 * 0.75 + ny ** 2)
    a = np.clip((d - 0.64) / 0.52, 0, 1) ** 1.45 * 135
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    arr[..., 0] = 3
    arr[..., 1] = 10
    arr[..., 2] = 16
    arr[..., 3] = a.astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(UI_DIR / "vignette.png", optimize=True)
    print("ui/vignette.png")


if __name__ == "__main__":
    make_background()
    make_panel()
    make_ribbon()
    make_close_button()
    make_glow()
    make_rune_ring()
    make_vignette()
    print("done")
