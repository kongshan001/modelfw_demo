"""Shared procedural art helpers for Swarmforge (original assets, no external IP).

All geometry is authored in a 64x64 design space ("units") and rendered at an
arbitrary pixel scale so the same silhouettes are reused for the battle atlas
(64 px cells) and the 512 px card illustrations.

No downloaded or traced reference art is used. Everything is generated from
primitives and gradients in this repository.
"""
from __future__ import annotations

import math
import random

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

# ---------------------------------------------------------------------------
# palette
# ---------------------------------------------------------------------------
OUTLINE = (5, 10, 14)
CER_TOP = (219, 236, 242)
CER_MID = (162, 185, 195)
CER_LOW = (104, 127, 138)
CER_DARK = (63, 82, 92)
STEEL = (96, 116, 126)
STEEL_DARK = (56, 72, 82)
BRASS = (197, 158, 97)
BRASS_HI = (240, 209, 152)
BRASS_LO = (118, 86, 44)
ENERGY = (223, 255, 250)
WHITE = (255, 255, 255)
NAVY = (8, 15, 23)
NAVY_DEEP = (4, 8, 13)

CARDS = [
    "spark_flea", "rivet_grub", "prism_gadfly", "magwire_mantis", "arc_ant",
    "spore_ballista", "weave_moth", "molten_weaver", "crown_colossus",
    "tideheart_engine",
]
CARD_NAMES = {
    "spark_flea": "火花蚤", "rivet_grub": "铆钉虫", "prism_gadfly": "棱镜虻",
    "magwire_mantis": "磁线螳", "arc_ant": "电弧蚁", "spore_ballista": "孢弩台",
    "weave_moth": "织焰蛾", "molten_weaver": "熔核蛛", "crown_colossus": "冠熔巨像",
    "tideheart_engine": "潮心机核",
}
FAMILY = {
    "spark_flea": "Skitter", "magwire_mantis": "Skitter", "rivet_grub": "Grub",
    "crown_colossus": "Grub", "prism_gadfly": "Flyer", "arc_ant": "Ant",
    "spore_ballista": "Ballista", "weave_moth": "Moth", "molten_weaver": "Spider",
    "tideheart_engine": "Core",
}


# ---------------------------------------------------------------------------
# low level drawing
# ---------------------------------------------------------------------------
def new_layer(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def _gradient_rgba(size, mask, c_top, c_bottom):
    w, h = size
    ys = np.linspace(0.0, 1.0, h, dtype=np.float32)[:, None]
    arr = np.zeros((h, w, 4), dtype=np.float32)
    for i in range(3):
        arr[..., i] = c_top[i] * (1.0 - ys) + c_bottom[i] * ys
    arr[..., 3] = np.asarray(mask, dtype=np.float32) * (255.0 / 255.0)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def _mask_poly(size, points):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    return m


def _mask_ellipse(size, box):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).ellipse(box, fill=255)
    return m


def grad_poly(img, points, c_top, c_bottom):
    mask = _mask_poly(img.size, points)
    img.alpha_composite(_gradient_rgba(img.size, mask, c_top, c_bottom))


def grad_ellipse(img, box, c_top, c_bottom):
    mask = _mask_ellipse(img.size, box)
    img.alpha_composite(_gradient_rgba(img.size, mask, c_top, c_bottom))


def grad_circle(img, center, radius, c_top, c_bottom):
    x, y = center
    grad_ellipse(img, (x - radius, y - radius, x + radius, y + radius), c_top, c_bottom)


def solid_poly(img, points, color):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon(points, fill=color)
    img.alpha_composite(layer)


def solid_ellipse(img, box, color):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).ellipse(box, fill=color)
    img.alpha_composite(layer)


def line(img, points, color, width):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.line(points, fill=color, width=max(1, int(round(width))), joint="curve")
    img.alpha_composite(layer)


def arc(img, box, start, end, color, width):
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).arc(box, start, end, fill=color, width=max(1, int(round(width))))
    img.alpha_composite(layer)


def glow(img, center, radius, color, strength=0.6):
    d = int(max(4, radius * 2))
    if d < 2:
        return
    grad = Image.radial_gradient("L").resize((d, d), Image.BILINEAR)
    arr = np.asarray(grad, dtype=np.float32) / 255.0
    alpha = np.clip((1.0 - arr) ** 2.2 * strength, 0.0, 1.0)
    rgba = np.zeros((d, d, 4), dtype=np.uint8)
    rgba[..., 0] = color[0]
    rgba[..., 1] = color[1]
    rgba[..., 2] = color[2]
    rgba[..., 3] = (alpha * 255).astype(np.uint8)
    layer = Image.fromarray(rgba, "RGBA")
    img.alpha_composite(layer, (int(center[0] - d / 2), int(center[1] - d / 2)))


def contact_shadow(img, center, rx, ry, alpha=70):
    d = (int(rx * 2), int(ry * 2))
    if d[0] < 2 or d[1] < 2:
        return
    mask = Image.new("L", d, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d[0] - 1, d[1] - 1), fill=alpha)
    mask = mask.filter(ImageFilter.GaussianBlur(max(1.0, d[1] * 0.35)))
    layer = Image.new("RGBA", d, (0, 0, 0, 0))
    layer.putalpha(mask)
    img.alpha_composite(layer, (int(center[0] - d[0] / 2), int(center[1] - d[1] / 2)))


def add_outline(img, radius_px, color=OUTLINE):
    alpha = img.getchannel("A").point(lambda v: 255 if v > 26 else 0)
    k = max(3, int(radius_px) * 2 + 1)
    grown = alpha.filter(ImageFilter.MaxFilter(k))
    out = Image.new("RGBA", img.size, (*color, 255))
    out.putalpha(grown)
    out.alpha_composite(img)
    return out


def rim_light(img, color=(228, 252, 255), radius=3, strength=0.55):
    radius = max(1, int(round(radius)))
    alpha = img.getchannel("A")
    shifted = ImageChops.offset(alpha, -radius, -int(radius * 0.8))
    edge = ImageChops.subtract(alpha, shifted)
    edge = edge.filter(ImageFilter.GaussianBlur(max(0.6, radius * 0.35)))
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    layer.putalpha(edge.point(lambda v: int(v * strength)))
    col = Image.new("RGBA", img.size, (*color, 0))
    col.putalpha(layer.getchannel("A"))
    img.alpha_composite(col)


def volume_shade(img, radius=3, strength=0.42):
    """Inner bottom-right occlusion + cool shadow grade, gives the flat vector
    shapes a ceramic/hard-surface volume without another texture."""
    radius = max(1, int(round(radius)))
    alpha = img.getchannel("A").point(lambda v: 255 if v > 20 else 0)
    shifted = ImageChops.offset(alpha, -radius, -int(radius * 0.9))
    inner = ImageChops.subtract(alpha, shifted)
    inner = inner.filter(ImageFilter.GaussianBlur(max(0.6, radius * 0.5)))
    dark = Image.new("RGBA", img.size, (6, 12, 16, 0))
    dark.putalpha(inner.point(lambda v: int(v * strength)))
    img.alpha_composite(dark)
    # cool the shadows / warm the low mid a little
    arr = np.asarray(img.convert("RGBA"), dtype=np.float32)
    lum = (arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114) / 255.0
    cool = np.clip(1.0 - lum * 1.4, 0.0, 1.0)[..., None]
    arr[..., 0:3] += np.array([-6.0, 2.0, 7.0])[None, None, :] * cool * 0.55
    arr[..., 0:3] = np.clip(arr[..., 0:3], 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def desaturate(img, amount=0.5):
    arr = np.asarray(img.convert("RGBA"), dtype=np.float32)
    lum = arr[..., 0] * 0.299 + arr[..., 1] * 0.587 + arr[..., 2] * 0.114
    for i in range(3):
        arr[..., i] = arr[..., i] * (1.0 - amount) + lum * amount
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def tint_white(img, amount=0.25):
    arr = np.asarray(img.convert("RGBA"), dtype=np.float32)
    alpha = arr[..., 3:4] / 255.0
    arr[..., :3] = arr[..., :3] * (1.0 - amount) + 255.0 * amount
    arr[..., 3:4] = arr[..., 3:4]
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def rotate_scale(img, angle, scale, center):
    # rotate about center, then scale about center; keeps canvas size
    if abs(angle) > 0.01:
        img = img.rotate(angle, resample=Image.BICUBIC, center=center)
    if abs(scale - 1.0) > 0.001:
        w, h = img.size
        scaled = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
        out = Image.new("RGBA", img.size, (0, 0, 0, 0))
        out.alpha_composite(scaled, (int(center[0] - scaled.width * center[0] / w),
                                     int(center[1] - scaled.height * center[1] / h)))
        img = out
    return img


# ---------------------------------------------------------------------------
# creature geometry
# ---------------------------------------------------------------------------
def _sc(v, sc):
    return v * sc


def _poly(img, pts, c_top, c_bottom, sc, dx=0.0, dy=0.0):
    p = [((x + dx) * sc, (y + dy) * sc) for x, y in pts]
    grad_poly(img, p, c_top, c_bottom)
    return p


def _ell(img, box, c_top, c_bottom, sc, dx=0.0, dy=0.0):
    b = tuple((v + (dx if i % 2 == 0 else dy)) * sc for i, v in enumerate(box))
    grad_ellipse(img, b, c_top, c_bottom)
    return b


def _out(img, pts, color, sc, w, closed=True, dx=0.0, dy=0.0):
    p = [((x + dx) * sc, (y + dy) * sc) for x, y in pts]
    if closed:
        p = p + [p[0]]
    line(img, p, color, w * sc)


def _leg(img, a, b, c, sc, color=CER_DARK, w=1.6, dx=0.0, dy=0.0):
    line(img, [((a[0] + dx) * sc, (a[1] + dy) * sc),
               ((b[0] + dx) * sc, (b[1] + dy) * sc),
               ((c[0] + dx) * sc, (c[1] + dy) * sc)], (*color, 255), w * sc)
    # foot
    solid_ellipse(img, ((c[0] + dx - 1.3) * sc, (c[1] + dy - 1.0) * sc,
                        (c[0] + dx + 1.3) * sc, (c[1] + dy + 1.0) * sc), (*OUTLINE, 255))
    solid_ellipse(img, ((c[0] + dx - 0.9) * sc, (c[1] + dy - 1.2) * sc,
                        (c[0] + dx + 0.9) * sc, (c[1] + dy - 0.1) * sc), (*BRASS, 255))


def _rivet(img, x, y, r, sc):
    solid_ellipse(img, ((x - r) * sc, (y - r) * sc, (x + r) * sc, (y + r) * sc), (*BRASS_LO, 255))
    solid_ellipse(img, ((x - r * 0.72) * sc, (y - r * 0.72) * sc,
                        (x + r * 0.72) * sc, (y + r * 0.72) * sc), (*BRASS_HI, 255))
    solid_ellipse(img, ((x - r * 0.3) * sc, (y - r * 0.35) * sc,
                        (x + r * 0.05) * sc, (y - r * 0.02) * sc), (255, 255, 255, 210))


def _eye(img, x, y, r, sc, glow_col=ENERGY):
    solid_ellipse(img, ((x - r) * sc, (y - r) * sc, (x + r) * sc, (y + r) * sc), (*OUTLINE, 255))
    solid_ellipse(img, ((x - r * 0.62) * sc, (y - r * 0.62) * sc,
                        (x + r * 0.62) * sc, (y + r * 0.62) * sc), (*glow_col, 255))
    solid_ellipse(img, ((x - r * 0.26) * sc, (y - r * 0.3) * sc,
                        (x + r * 0.06) * sc, (y - r * 0.08) * sc), (255, 255, 255, 255))


def _plate_lines(img, lines, sc, color=(90, 112, 122, 170), w=0.8):
    for pts in lines:
        p = [(x * sc, y * sc) for x, y in pts]
        line(img, p, color, w * sc)


def _pose_sway(pose, key, default=0.0):
    return float(pose.get(key, default))


def draw_spark_flea(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    ant = _pose_sway(pose, "ant")
    _leg(img, (22, 38), (14, 47), (9 + leg, 53), sc, dx=dx, dy=dy)
    _leg(img, (27, 40), (25, 49), (20 - leg, 53), sc, dx=dx, dy=dy)
    _leg(img, (40, 39), (45, 47), (48 + leg, 52), sc, dx=dx, dy=dy)
    _leg(img, (44, 36), (50, 43), (53, 49), sc, dx=dx, dy=dy)
    # tail spike
    _poly(img, [(19, 33), (7, 27), (17, 37)], CER_LOW, CER_DARK, sc, dx, dy)
    # abdomen + thorax shell
    _ell(img, (13, 27, 41, 44), CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (26, 25, 47, 39), (220, 233, 237), (136, 157, 166), sc, dx, dy)
    # carapace plates
    _plate_lines(img, [
        [(19, 31), (29, 28), (38, 30)],
        [(17, 36), (28, 34), (39, 36)],
    ], sc, (250, 255, 255, 120), 0.9)
    # head
    _ell(img, (41, 27, 53, 37), CER_TOP, CER_MID, sc, dx, dy)
    _poly(img, [(51, 31), (57, 33), (51, 35)], BRASS, BRASS_LO, sc, dx, dy)
    _eye(img, 48, 31, 1.5, sc, ENERGY)
    # antennae
    line(img, [((52 + dx) * sc, (28 + dy) * sc),
               ((57 + dx) * sc, (20 + dy - ant) * sc),
               ((59 + dx) * sc, (15 + dy - ant * 1.4) * sc)], (*CER_DARK, 255), 1.1 * sc)
    line(img, [((52 + dx) * sc, (30 + dy) * sc),
               ((58 + dx) * sc, (25 + dy - ant * 0.6) * sc),
               ((61 + dx) * sc, (21 + dy - ant) * sc)], (*CER_DARK, 255), 1.0 * sc)
    solid_ellipse(img, ((58.4 + dx) * sc, (13.8 + dy - ant * 1.4) * sc,
                        (60.4 + dx) * sc, (15.8 + dy - ant * 1.4) * sc), (*BRASS_HI, 255))
    # dorsal fin + brass gear
    _poly(img, [(25, 26), (29, 18), (34, 26)], BRASS, BRASS_LO, sc, dx, dy)
    _rivet(img, 31 + dx, 34 + dy, 2.6, sc)
    glow(img, ((37 + dx) * sc, (37 + dy) * sc), 4.6 * sc, (170, 255, 245), 0.5)
    solid_ellipse(img, ((35.6 + dx) * sc, (36.2 + dy) * sc,
                        (38.4 + dx) * sc, (38.4 + dy) * sc), (*ENERGY, 255))


def draw_rivet_grub(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    for i, x in enumerate((18, 25, 32, 39, 46)):
        _leg(img, (x, 42), (x + (leg if i % 2 == 0 else -leg) * 0.6, 48), (x + (leg if i % 2 == 0 else -leg), 53), sc, dx=dx, dy=dy)
    _ell(img, (10, 24, 50, 49), CER_TOP, CER_LOW, sc, dx, dy)
    # shell domes
    _ell(img, (13, 22, 31, 40), (225, 238, 241), (132, 153, 162), sc, dx, dy)
    _ell(img, (23, 19, 41, 38), (232, 243, 246), (140, 161, 170), sc, dx, dy)
    _ell(img, (33, 22, 49, 39), (220, 233, 237), (128, 149, 158), sc, dx, dy)
    for x, y, r in ((22, 30, 2.6), (32, 27, 3.0), (41, 30, 2.4)):
        _rivet(img, x + dx, y + dy, r, sc)
    # head
    _ell(img, (45, 33, 57, 44), CER_TOP, CER_MID, sc, dx, dy)
    _eye(img, 51, 38, 1.5, sc, ENERGY)
    _poly(img, [(56, 36), (62, 38), (56, 41)], BRASS, BRASS_LO, sc, dx, dy)
    # belly plate + brass trim
    _poly(img, [(15, 43), (44, 43), (40, 48), (19, 48)], STEEL_DARK, (40, 52, 60), sc, dx, dy)
    _out(img, [(12, 40), (30, 45), (48, 40)], (*BRASS, 210), sc, 0.9, False, dx, dy)
    # tail
    _poly(img, [(12, 38), (6, 34), (13, 43)], CER_LOW, CER_DARK, sc, dx, dy)
    glow(img, ((46 + dx) * sc, (42 + dy) * sc), 3.0 * sc, (255, 190, 120), 0.35)


def draw_prism_gadfly(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    wing = _pose_sway(pose, "wing")
    ant = _pose_sway(pose, "ant")
    lift = -1.0 + dy
    # upper wings
    wing_a = [(31, 27), (11, 9 + wing * 0.6), (15, 25), (28, 33)]
    wing_b = [(34, 27), (54, 7 + wing * 0.6), (50, 24), (37, 33)]
    for pts in (wing_a, wing_b):
        _poly(img, pts, (205, 240, 243), (98, 160, 170), sc, dx, lift)
    # lower wings
    for pts in ([(30, 33), (16, 25 + wing), (20, 36), (29, 38)],
                [(35, 33), (49, 23 + wing), (45, 35), (36, 38)]):
        _poly(img, pts, (188, 228, 232), (86, 142, 154), sc, dx, lift)
    # wing ribs
    for a, b in (((31, 27), (14, 12)), ((34, 27), (51, 10))):
        line(img, [((a[0] + dx) * sc, (a[1] + lift) * sc), ((b[0] + dx) * sc, (b[1] + lift) * sc)],
             (235, 252, 252, 200), 0.75 * sc)
    # abdomen + thorax
    _ell(img, (29, 30, 39, 47), CER_TOP, CER_LOW, sc, dx, lift)
    _ell(img, (28, 24, 40, 34), (230, 241, 244), (138, 158, 167), sc, dx, lift)
    # needle tail
    _poly(img, [(33, 46), (35, 57), (36.5, 46)], BRASS, BRASS_LO, sc, dx, lift)
    _eye(img, 36, 26.5, 1.9, sc, ENERGY)
    _eye(img, 31, 26.5, 1.5, sc, ENERGY)
    # antennae
    line(img, [((37 + dx) * sc, (23 + lift) * sc), ((44 + dx) * sc, (16 + lift - ant) * sc)],
         (*CER_DARK, 255), 0.9 * sc)
    # energy core
    glow(img, ((34 + dx) * sc, (36 + lift) * sc), 4.0 * sc, (180, 255, 248), 0.55)
    solid_ellipse(img, ((32.6 + dx) * sc, (34.8 + lift) * sc,
                        (35.4 + dx) * sc, (37.4 + lift) * sc), (*ENERGY, 255))


def draw_arc_ant(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    ant = _pose_sway(pose, "ant")
    # legs
    for i, (ax, ay, bx, by, cx, cy) in enumerate((
            (29, 30, 20, 42, 15 + leg, 52), (31, 32, 25, 46, 23 - leg, 54),
            (34, 31, 40, 45, 44 + leg, 53), (35, 29, 45, 39, 49 - leg, 50))):
        _leg(img, (ax, ay), (bx, by), (cx, cy), sc, dx=dx, dy=dy)
    # abdomen (tall) + coil
    _ell(img, (22, 36, 36, 54), CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (24, 32, 35, 42), (226, 238, 241), (128, 149, 158), sc, dx, dy)
    for yy in (34.5, 37.5, 40.5):
        arc(img, ((23 + dx) * sc, (yy + dy - 3.4) * sc, (37 + dx) * sc, (yy + dy + 1.0) * sc),
            190, 350, (*BRASS, 235), 0.9 * sc)
    # thorax
    _ell(img, (28, 22, 39, 36), (232, 243, 246), (140, 161, 170), sc, dx, dy)
    # head
    _ell(img, (29, 12, 41, 24), CER_TOP, CER_MID, sc, dx, dy)
    _eye(img, 37, 17, 2.0, sc, ENERGY)
    _poly(img, [(40, 19), (46, 22), (40, 23)], BRASS, BRASS_LO, sc, dx, dy)
    # antennae
    line(img, [((38 + dx) * sc, (13 + dy) * sc), ((45 + dx) * sc, (7 + dy - ant) * sc)],
         (*CER_DARK, 255), 1.0 * sc)
    line(img, [((35 + dx) * sc, (12 + dy) * sc), ((39 + dx) * sc, (5 + dy - ant * 1.2) * sc)],
         (*CER_DARK, 255), 1.0 * sc)
    # back coil ring
    arc(img, ((26 + dx) * sc, (19 + dy) * sc, (34 + dx) * sc, (30 + dy) * sc), 40, 320,
        (*BRASS_HI, 235), 1.4 * sc)
    glow(img, ((31 + dx) * sc, (29 + dy) * sc), 3.2 * sc, (150, 245, 255), 0.45)


def draw_spore_ballista(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    recoil = _pose_sway(pose, "ant") * -0.0
    # tripod
    for a, b, c in (((28, 42), (15, 51), (11, 57)), ((33, 42), (33, 53), (32, 58)),
                    ((38, 42), (48, 51), (52, 56))):
        _leg(img, (a[0], a[1]), (b[0], b[1]), (c[0], c[1]), sc, color=CER_DARK, w=2.1, dx=dx, dy=dy)
    _ell(img, (18, 40, 46, 50), (96, 116, 126), (54, 70, 78), sc, dx, dy)
    _ell(img, (22, 38, 42, 46), (210, 224, 229), (108, 128, 138), sc, dx, dy)
    # vertical pod
    _poly(img, [(25, 18), (38, 18), (40, 42), (23, 42)], CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (24, 14, 39, 24), (230, 241, 244), (132, 153, 162), sc, dx, dy)
    _out(img, [(23, 26), (40, 26)], (*BRASS, 230), sc, 1.1, False, dx, dy)
    _out(img, [(23, 34), (40, 34)], (*BRASS, 230), sc, 1.1, False, dx, dy)
    # barrel
    _poly(img, [(38, 27), (59, 23), (59, 29), (38, 34)], BRASS, BRASS_LO, sc, dx, dy)
    solid_ellipse(img, ((57 + dx) * sc, (22 + dy) * sc, (62 + dx) * sc, (30 + dy) * sc),
                  (*BRASS_HI, 255))
    solid_ellipse(img, ((58.5 + dx) * sc, (24 + dy) * sc, (61 + dx) * sc, (28 + dy) * sc),
                  (40, 28, 18, 255))
    # barrel vents + spore glow
    for i in range(3):
        solid_ellipse(img, ((44 + i * 4 + dx) * sc, (29 + dy) * sc,
                            (46 + i * 4 + dx) * sc, (31 + dy) * sc), (*BRASS_HI, 255))
    glow(img, ((33 + dx) * sc, (27 + dy) * sc), 4.2 * sc, (190, 255, 210), 0.5)
    solid_ellipse(img, ((31 + dx) * sc, (25 + dy) * sc, (35 + dx) * sc, (29 + dy) * sc),
                  (208, 255, 190, 255))
    # back counterweight + spikes
    _poly(img, [(22, 25), (16, 22), (22, 33)], STEEL_DARK, (30, 42, 50), sc, dx, dy)
    _rivet(img, 30 + dx, 39 + dy, 2.2, sc)


def draw_weave_moth(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    wing = _pose_sway(pose, "wing")
    # V wings
    left = [(30, 27), (4, 8 + wing), (8, 24), (22, 35), (30, 37)]
    right = [(35, 27), (60, 6 + wing), (56, 24), (41, 35), (35, 37)]
    for pts in (left, right):
        _poly(img, pts, (204, 238, 241), (92, 148, 160), sc, dx, 0.0)
    # lower wings
    for pts in ([(30, 36), (13, 30 + wing * 0.6), (18, 42), (29, 44)],
                [(35, 36), (51, 29 + wing * 0.6), (46, 42), (36, 44)]):
        _poly(img, pts, (188, 226, 231), (82, 134, 146), sc, dx, 0.0)
    # wing veins
    for a, b in (((30, 27), (9, 12)), ((35, 27), (56, 10)), ((30, 36), (16, 34)),
                 ((35, 36), (48, 33))):
        line(img, [((a[0] + dx) * sc, (a[1]) * sc), ((b[0] + dx) * sc, (b[1]) * sc)],
             (*BRASS_HI, 150), 0.7 * sc)
    # body
    _ell(img, (29, 29, 38, 48), CER_TOP, CER_LOW, sc, dx, 0.0)
    _ell(img, (28, 19, 39, 29), (232, 243, 246), (132, 153, 162), sc, dx, 0.0)
    # antennae
    for i in range(3):
        line(img, [((33 + dx) * sc, (20) * sc), ((40 + i * 2 + dx) * sc, (11 + i * 2) * sc)],
             (*CER_DARK, 255), 0.7 * sc)
    _eye(img, 34.5, 24, 1.6, sc, ENERGY)
    # core
    glow(img, ((33 + dx) * sc, (36) * sc), 6.0 * sc, (255, 215, 160), 0.55)
    solid_ellipse(img, ((31 + dx) * sc, (34) * sc, (36 + dx) * sc, (39) * sc), (*ENERGY, 255))
    arc(img, ((28 + dx) * sc, (31) * sc, (39 + dx) * sc, (42) * sc), 210, 330,
        (*BRASS, 200), 0.8 * sc)
    # tail fringe
    _poly(img, [(31, 47), (33, 55), (34, 47)], CER_LOW, CER_DARK, sc, dx, 0.0)


def draw_molten_weaver(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    for i, (ax, ay, bx, by, cx, cy) in enumerate((
            (25, 36, 14, 27, 5 + leg, 23), (22, 39, 9, 40, 3 - leg, 45),
            (24, 42, 14, 50, 9 + leg, 57), (38, 37, 46, 27, 54 - leg, 24),
            (40, 40, 50, 40, 58 + leg, 44), (38, 43, 46, 51, 51 - leg, 57))):
        _leg(img, (ax, ay), (bx, by), (cx, cy), sc, dx=dx, dy=dy)
    # abdomen
    _ell(img, (12, 27, 38, 49), CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (14, 29, 34, 45), (226, 238, 241), (120, 141, 151), sc, dx, dy)
    # molten cracks
    for pts in ([(19, 32), (23, 38), (20, 44)], [(27, 31), (30, 37), (27, 45)],
                [(16, 38), (21, 41), (18, 46)]):
        p = [((x + dx) * sc, (y + dy) * sc) for x, y in pts]
        line(img, p, (255, 168, 72, 255), 1.2 * sc)
        line(img, p, (255, 240, 200, 210), 0.45 * sc)
    glow(img, ((24 + dx) * sc, (38 + dy) * sc), 6.0 * sc, (255, 150, 60), 0.4)
    # head
    _ell(img, (34, 29, 46, 41), CER_TOP, CER_MID, sc, dx, dy)
    _eye(img, 40, 33, 1.7, sc, (255, 190, 110))
    _eye(img, 44, 35, 1.3, sc, (255, 190, 110))
    # fangs
    _poly(img, [(39, 40), (37, 46), (41, 41)], BRASS, BRASS_LO, sc, dx, dy)
    _poly(img, [(43, 40), (43, 46), (46, 41)], BRASS, BRASS_LO, sc, dx, dy)
    _rivet(img, 31 + dx, 33 + dy, 2.2, sc)
    # spinneret
    _poly(img, [(12, 36), (5, 34), (11, 41)], CER_LOW, CER_DARK, sc, dx, dy)


def draw_crown_colossus(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    # legs
    _leg(img, (17, 41), (12, 49), (9 + leg, 55), sc, color=CER_DARK, w=2.4, dx=dx, dy=dy)
    _leg(img, (28, 45), (25, 52), (22 - leg, 57), sc, color=CER_DARK, w=2.4, dx=dx, dy=dy)
    _leg(img, (40, 45), (44, 52), (47 + leg, 57), sc, color=CER_DARK, w=2.4, dx=dx, dy=dy)
    _leg(img, (48, 41), (52, 48), (56 - leg, 54), sc, color=CER_DARK, w=2.2, dx=dx, dy=dy)
    # body
    _ell(img, (8, 24, 52, 51), CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (12, 23, 38, 44), (230, 242, 245), (134, 155, 164), sc, dx, dy)
    _ell(img, (25, 20, 49, 43), (224, 237, 240), (128, 149, 158), sc, dx, dy)
    # crown horns
    for base_x, base_y, tip_x, tip_y, wdt in ((15, 26, 11, 8, 4.5), (28, 23, 28, 4, 5.5),
                                              (42, 25, 47, 9, 4.5)):
        _poly(img, [(base_x - wdt, base_y), (tip_x, tip_y), (base_x + wdt, base_y)],
              BRASS_HI, BRASS, sc, dx, dy)
        _poly(img, [(tip_x - 0.8, tip_y + 1.2), (tip_x, tip_y), (tip_x + 0.8, tip_y + 1.2)],
              (255, 250, 235), (255, 238, 200), sc, dx, dy)
    # gold trim + rivets
    _out(img, [(13, 38), (28, 43), (47, 38)], (*BRASS, 230), sc, 1.2, False, dx, dy)
    for x, y in ((18, 32), (33, 30), (43, 33)):
        _rivet(img, x + dx, y + dy, 2.4, sc)
    # head
    _ell(img, (46, 33, 58, 45), CER_TOP, CER_MID, sc, dx, dy)
    _eye(img, 52, 38, 1.8, sc, ENERGY)
    _poly(img, [(56, 35), (62, 37), (56, 42)], BRASS, BRASS_LO, sc, dx, dy)
    glow(img, ((28 + dx) * sc, (33 + dy) * sc), 4.0 * sc, (255, 200, 130), 0.32)


def draw_magwire_mantis(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    leg = _pose_sway(pose, "leg")
    ant = _pose_sway(pose, "ant")
    for i, (a, b, c) in enumerate((((26, 39), (19, 47), (15, 54)),
                                   ((30, 41), (26, 50), (23 - leg, 56)),
                                   ((36, 41), (39, 50), (43 + leg, 56)),
                                   ((40, 38), (46, 46), (50, 52)))):
        _leg(img, a, b, c, sc, dx=dx, dy=dy)
    # abdomen
    _ell(img, (14, 32, 32, 48), CER_TOP, CER_LOW, sc, dx, dy)
    # thorax
    _ell(img, (24, 26, 40, 40), (228, 240, 243), (136, 157, 166), sc, dx, dy)
    _plate_lines(img, [[(25, 32), (33, 29), (39, 33)]], sc, (250, 255, 255, 130), 0.8)
    # head
    _ell(img, (39, 21, 51, 33), CER_TOP, CER_MID, sc, dx, dy)
    _eye(img, 46, 25, 2.0, sc, ENERGY)
    _poly(img, [(50, 27), (57, 30), (50, 31)], BRASS, BRASS_LO, sc, dx, dy)
    # coil crown
    arc(img, ((41 + dx) * sc, (12 + dy) * sc, (51 + dx) * sc, (24 + dy) * sc),
        20, 340, (*BRASS_HI, 240), 1.5 * sc)
    arc(img, ((43 + dx) * sc, (15 + dy) * sc, (49 + dx) * sc, (21 + dy) * sc),
        200, 520, (*STEEL, 220), 0.8 * sc)
    glow(img, ((46 + dx) * sc, (18 + dy) * sc), 3.0 * sc, (170, 245, 255), 0.45)
    # scythe arms
    _poly(img, [(36, 32), (55, 34), (51, 39), (36, 37)], BRASS, BRASS_LO, sc, dx, dy)
    _poly(img, [(36, 38), (53, 44), (49, 49), (35, 42)], CER_MID, CER_LOW, sc, dx, dy)
    # tail + antennae
    _poly(img, [(15, 36), (7, 31), (14, 42)], CER_LOW, CER_DARK, sc, dx, dy)
    line(img, [((49 + dx) * sc, (21 + dy) * sc), ((56 + dx) * sc, (13 + dy - ant) * sc)],
         (*CER_DARK, 255), 0.9 * sc)
    line(img, [((47 + dx) * sc, (20 + dy) * sc), ((51 + dx) * sc, (10 + dy - ant * 1.2) * sc)],
         (*CER_DARK, 255), 0.9 * sc)
    _rivet(img, 30 + dx, 34 + dy, 2.2, sc)


def draw_tideheart_engine(img, pose, sc):
    dx = _pose_sway(pose, "dx")
    dy = _pose_sway(pose, "dy")
    spin = _pose_sway(pose, "wing")
    # orbit ring (behind)
    arc(img, ((14 + dx) * sc, (27 + dy) * sc, (58 + dx) * sc, (41 + dy) * sc), 0, 360,
        (*BRASS, 230), 1.8 * sc)
    # satellites
    for ang in (0.5 + spin * 0.15, 2.5 + spin * 0.15, 4.4 + spin * 0.15):
        sx = 36 + math.cos(ang) * 21
        sy = 34 + math.sin(ang) * 7
        _rivet(img, sx + dx, sy + dy, 2.6, sc)
    # orb
    _ell(img, (26, 18, 52, 46), CER_TOP, CER_LOW, sc, dx, dy)
    _ell(img, (29, 21, 47, 40), (228, 240, 243), (128, 149, 158), sc, dx, dy)
    # armor plates
    _poly(img, [(27, 24), (36, 20), (38, 31), (29, 34)], (240, 248, 250), (166, 186, 194), sc, dx, dy)
    _poly(img, [(45, 25), (51, 31), (46, 38), (40, 34)], (232, 244, 247), (150, 170, 180), sc, dx, dy)
    # core + ring highlight
    glow(img, ((37 + dx) * sc, (33 + dy) * sc), 8.0 * sc, (160, 250, 255), 0.6)
    solid_ellipse(img, ((34 + dx) * sc, (30 + dy) * sc, (40 + dx) * sc, (36 + dy) * sc),
                  (*ENERGY, 255))
    solid_ellipse(img, ((36 + dx) * sc, (31.5 + dy) * sc, (38 + dx) * sc, (33.5 + dy) * sc),
                  (255, 255, 255, 255))
    arc(img, ((18 + dx) * sc, (33 + dy) * sc, (54 + dx) * sc, (39 + dy) * sc), 20, 160,
        (*BRASS_HI, 245), 1.1 * sc)
    # hover cone
    _poly(img, [(31, 45), (36, 56), (41, 45)], (100, 220, 225), (30, 80, 90), sc, dx, dy)
    glow(img, ((36 + dx) * sc, (50 + dy) * sc), 5.0 * sc, (140, 245, 255), 0.5)
    # crown antenna
    _poly(img, [(35, 18), (36, 9), (38, 18)], BRASS, BRASS_LO, sc, dx, dy)
    solid_ellipse(img, ((34.4 + dx) * sc, (7.4 + dy) * sc, (37.6 + dx) * sc, (10.6 + dy) * sc),
                  (*BRASS_HI, 255))
    _eye(img, 36, 27, 1.4, sc, ENERGY)


DRAWERS = {
    "spark_flea": draw_spark_flea, "rivet_grub": draw_rivet_grub,
    "prism_gadfly": draw_prism_gadfly, "magwire_mantis": draw_magwire_mantis,
    "arc_ant": draw_arc_ant, "spore_ballista": draw_spore_ballista,
    "weave_moth": draw_weave_moth, "molten_weaver": draw_molten_weaver,
    "crown_colossus": draw_crown_colossus, "tideheart_engine": draw_tideheart_engine,
}


def render_creature(card_id, pose, sc, size_px):
    """Render one creature at `sc` px per 64-space unit into a size_px canvas."""
    layer = new_layer((size_px, size_px))
    DRAWERS[card_id](layer, pose, sc)
    death = pose.get("death")
    lean = float(pose.get("lean", 0.0))
    if death is not None:
        angles = (14.0, 34.0, 62.0)
        scales = (0.96, 0.8, 0.58)
        lean += angles[int(death)]
        scale = scales[int(death)]
    else:
        scale = float(pose.get("scale", 1.0))
    if abs(lean) > 0.01 or abs(scale - 1.0) > 0.001:
        center = (size_px * 0.5, size_px * 0.72)
        layer = rotate_scale(layer, -lean, scale, center)
    if pose.get("flash", 0):
        layer = tint_white(layer, 0.22)
    return layer


def creature_plate(card_id, pose, sc, size_px, shadow=True):
    """Full composed unit/illustration plate.

    Contact shadow and spawn ring live on a base layer **under** the outlined
    art. They must not go through add_outline(): a dilated soft shadow becomes
    an opaque black bar and the elite gold rim then traces that bar as a box.
    """
    layer = render_creature(card_id, pose, sc, size_px)
    if pose.get("elite"):
        ex, ey = size_px * 0.5, size_px * 0.17
        solid_poly(layer, [(ex - size_px * 0.032, ey + size_px * 0.062),
                           (ex, ey - size_px * 0.030),
                           (ex + size_px * 0.032, ey + size_px * 0.062)],
                   (*BRASS_HI, 235))
    base = new_layer((size_px, size_px))
    if shadow:
        contact_shadow(base, (size_px * 0.5, size_px * 0.835), size_px * 0.24, size_px * 0.05, 48)
    if pose.get("spawn"):
        ring_center = (size_px * 0.5, size_px * 0.72)
        rr = size_px * 0.36
        d = int(rr * 2)
        ring = Image.new("RGBA", (d, d), (0, 0, 0, 0))
        ImageDraw.Draw(ring).ellipse((2, 2, d - 3, d - 3), outline=(190, 255, 250, 210),
                                     width=max(1, int(size_px * 0.018)))
        base.alpha_composite(ring, (int(ring_center[0] - d / 2), int(ring_center[1] - d / 2)))
        for i in range(6):
            a = i * math.tau / 6.0 + 0.3
            px = ring_center[0] + math.cos(a) * rr
            py = ring_center[1] + math.sin(a) * rr * 0.42
            glow(base, (px, py), size_px * 0.035, (200, 255, 250), 0.8)
    volume_shade(layer, max(1.0, sc * 0.75), 0.40)
    rim_light(layer, (232, 255, 255), max(1.0, sc * 0.9), 0.52)
    art = new_layer((size_px, size_px))
    art.alpha_composite(layer)
    art = add_outline(art, max(1.0, sc * 0.74), OUTLINE)
    base.alpha_composite(art)
    out = base
    if pose.get("death") == 2:
        #碎片
        rng = random.Random(77 + int(card_id.__hash__() % 999))
        for i in range(9):
            a = rng.uniform(0, math.tau)
            r = rng.uniform(0.18, 0.42) * size_px
            px = size_px * 0.5 + math.cos(a) * r
            py = size_px * 0.55 + math.sin(a) * r * 0.7
            s = rng.uniform(0.012, 0.03) * size_px
            col = (CER_MID if i % 3 else BRASS)
            solid_poly(out, [(px - s, py), (px, py - s * 1.4), (px + s, py), (px, py + s)],
                       (*col, rng.randint(120, 210)))
    return out


# ---------------------------------------------------------------------------
# frame / pose table
# ---------------------------------------------------------------------------
POSES = {
    0: {"dy": 0.0, "leg": 0.0, "ant": 0.0, "wing": 0.0},
    1: {"dy": -0.9, "leg": -0.8, "ant": 0.9, "wing": 0.7},
    2: {"dx": 0.8, "dy": 0.0, "leg": 1.0, "ant": 0.5, "wing": -0.4},
    3: {"dx": 0.8, "dy": -0.7, "leg": -1.0, "ant": -0.4, "wing": 0.5},
    4: {"dx": -1.8, "dy": 0.0, "leg": -1.0, "ant": -0.9, "wing": -0.2, "lean": -7.0},
    5: {"dx": 2.0, "dy": -0.2, "leg": 1.0, "ant": 1.0, "wing": 0.8, "lean": 8.0, "flash": 1},
    6: {"dx": 0.4, "dy": 0.0, "leg": 0.6, "ant": 0.3, "wing": 0.2, "lean": 2.0},
    7: {"death": 0},
    8: {"death": 1},
    9: {"death": 2},
    10: {"spawn": 1, "scale": 0.72, "dy": 1.0},
    11: {"elite": 1, "dy": -0.3, "ant": 0.4, "wing": 0.3},
}


def frame_pose(card_id, frame):
    pose = dict(POSES[frame])
    # 不同卡的动作幅度略有差异，避免整场同帧同步
    if card_id in ("tideheart_engine", "weave_moth"):
        pose["wing"] = pose.get("wing", 0.0) * 1.8
    return pose


# ---------------------------------------------------------------------------
# card illustration background helpers
# ---------------------------------------------------------------------------
def illustration_bg(size, card_id, seed=0):
    """Foundry stage for a card portrait: arch, pipes, hex deck, light pools."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (size, size), (*NAVY_DEEP, 255))
    # vertical stage gradient
    top = (17, 31, 43)
    mid = (10, 19, 28)
    bottom = (4, 8, 12)
    grad = np.zeros((size, size, 4), dtype=np.uint8)
    ys = np.linspace(0.0, 1.0, size)[:, None]
    for i in range(3):
        a = np.float32(top[i]) * (1.0 - ys) + np.float32(mid[i]) * ys
        b = np.float32(mid[i]) * (1.0 - ys) + np.float32(bottom[i]) * ys
        grad[..., i] = np.where(ys < 0.55, a, b).astype(np.uint8)
    grad[..., 3] = 255
    img = Image.fromarray(grad, "RGBA")
    # cool key light from upper-left, warm furnace light at the deck
    glow(img, (size * 0.28, size * 0.18), size * 0.72, (48, 120, 132), 0.30)
    glow(img, (size * 0.62, size * 0.82), size * 0.55, (150, 74, 36), 0.24)
    # giant hex porthole behind the subject
    cx, cy = size * 0.5, size * 0.44
    r = size * 0.43
    hexp = [(cx + math.cos(math.pi / 3 * i - math.pi / 6) * r,
             cy + math.sin(math.pi / 3 * i - math.pi / 6) * r * 0.96) for i in range(6)]
    solid_poly(img, hexp, (8, 16, 24, 90))
    d = ImageDraw.Draw(img)
    d.line(hexp + [hexp[0]], fill=(110, 170, 180, 32), width=max(1, int(size * 0.006)))
    d.line([(hexp[i][0] * 0.92 + cx * 0.08, hexp[i][1] * 0.92 + cy * 0.08) for i in range(6)] + [hexp[0]],
           fill=(60, 110, 120, 20), width=max(1, int(size * 0.003)))
    # hanging cables / pipes
    for k, x in enumerate((size * 0.10, size * 0.16, size * 0.86, size * 0.92)):
        d.rectangle((x - size * 0.006, 0, x + size * 0.006, size * (0.30 + 0.06 * k)),
                    fill=(22, 38, 46, 255))
        d.rectangle((x - size * 0.012, size * 0.24, x + size * 0.012, size * 0.27),
                    fill=(52, 78, 88, 255))
        d.rectangle((x - size * 0.012, size * 0.08, x + size * 0.012, size * 0.10),
                    fill=(52, 78, 88, 255))
    # faint hex deck grid
    layer = new_layer((size, size))
    gd = ImageDraw.Draw(layer)
    step = size // 11
    for gy in range(-1, 11):
        for gx in range(-1, 10):
            hx = gx * step * 1.5 + (step * 0.75 if gy % 2 else 0)
            hy = gy * step * 0.87
            rr = step * 0.52
            pts = [(hx + math.cos(math.pi / 3 * i - math.pi / 6) * rr,
                    hy + math.sin(math.pi / 3 * i - math.pi / 6) * rr * 0.92) for i in range(6)]
            gd.line(pts + [pts[0]], fill=(80, 135, 146, 16), width=max(1, size // 512))
    img.alpha_composite(layer)
    # light shaft
    shaft = [(size * 0.10, 0), (size * 0.38, 0), (size * 0.56, size * 0.8), (size * 0.26, size * 0.8)]
    solid_poly(img, shaft, (120, 220, 220, 9))
    # deck platform (hex plate) + glowing seam
    px, py = size * 0.5, size * 0.845
    plate = [(px + math.cos(math.pi / 3 * i - math.pi / 6) * size * 0.32,
              py + math.sin(math.pi / 3 * i - math.pi / 6) * size * 0.085) for i in range(6)]
    solid_poly(img, plate, (20, 34, 41, 255))
    d.line(plate + [plate[0]], fill=(120, 190, 190, 70), width=max(1, int(size * 0.004)))
    inner = [(px + math.cos(math.pi / 3 * i - math.pi / 6) * size * 0.26,
              py + math.sin(math.pi / 3 * i - math.pi / 6) * size * 0.066) for i in range(6)]
    d.line(inner + [inner[0]], fill=(70, 140, 150, 46), width=max(1, int(size * 0.002)))
    for i in range(6):
        rx = px + math.cos(math.pi / 3 * i - math.pi / 6) * size * 0.29
        ry = py + math.sin(math.pi / 3 * i - math.pi / 6) * size * 0.076
        rr = max(1.4, size * 0.0055)
        solid_ellipse(img, (rx - rr, ry - rr, rx + rr, ry + rr), (*BRASS, 190))
    glow(img, (px, py), size * 0.30, (90, 200, 200), 0.10)
    # dust motes
    for i in range(rng.randint(34, 56)):
        x = rng.uniform(0, size)
        y = rng.uniform(0, size * 0.9)
        rr = rng.uniform(0.5, 2.1) * (size / 512.0)
        a = rng.randint(14, 70)
        solid_ellipse(img, (x - rr, y - rr, x + rr, y + rr), (170, 230, 235, a))
    # vignette
    yy, xx = np.mgrid[0:size, 0:size]
    nx = (xx - size / 2) / (size / 2)
    ny = (yy - size / 2) / (size / 2)
    arr = np.clip((np.sqrt(nx ** 2 + ny ** 2) - 0.5) * 1.35, 0, 1) * 170
    black = Image.new("RGBA", (size, size), (0, 0, 0, 255))
    black.putalpha(Image.fromarray(arr.astype(np.uint8), "L"))
    img.alpha_composite(black)
    return img


def add_painterly_finish(img, seed=0):
    """Extra rim highlights + soft glow + film grain for card art."""
    rng = random.Random(seed)
    rim_light(img, (235, 255, 255), max(2, img.width // 128), 0.38)
    # energy sparks around silhouette
    alpha = img.getchannel("A")
    for i in range(rng.randint(10, 18)):
        x = rng.uniform(img.width * 0.2, img.width * 0.8)
        y = rng.uniform(img.height * 0.2, img.height * 0.78)
        if alpha.getpixel((int(x), int(y))) < 20:
            glow(img, (x, y), rng.uniform(2, 5) * (img.width / 512.0),
                 (255, 230, 180) if i % 3 == 0 else (150, 255, 245), rng.uniform(0.2, 0.5))
    # grain
    arr = np.asarray(img.convert("RGBA"), dtype=np.int16)
    noise = np.random.default_rng(seed).normal(0, 3.2, (img.height, img.width, 1))
    arr[..., :3] = np.clip(arr[..., :3] + noise, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")
