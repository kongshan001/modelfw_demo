#!/usr/bin/env python3
"""Generate the original pixel art, height maps and normal maps for
Lanternlight Workshop (godot-sprite-normal-light).

Pipeline
--------
1. Draw every sprite at 1 art pixel per texel with a small palette.
2. Paint a height field and a large-form normal bias while drawing.
3. Derive the tangent-space normal map with a central-difference Sobel:
       nx = -(hR - hL) * gain + bias_x          (screen x, right)
       ny = -(hD - hU) * gain + bias_y_screen   (screen y, down)
       n  = normalize(vec3(nx, ny, 1))
   Encode OpenGL/Godot green-up convention:
       R = nx * 0.5 + 0.5, G = -ny * 0.5 + 0.5, B = nz * 0.5 + 0.5
   Alpha stores a per-pixel roughness value (0 smooth / 255 rough), used by
   the custom CanvasItem shader (alpha is ignored by Godot's built-in normal
   mapping path).
4. Transparent neighbours are treated as height 0, which bevels every
   silhouette edge. Large rounded forms additionally get an analytic normal
   bias (sphere / cylinder), so the stone, wood and moss read as volumes
   instead of flat stickers.
5. Write albedo (`*.png`), height debug (`*_height.png`) and normal
   (`*_normal.png`) images.

Deterministic: fixed seeds, no external art. Run from anywhere:
    python3 tools/gen_assets.py
"""
from __future__ import annotations

import math
import os
import random
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites")

# ── palette ────────────────────────────────────────────────────────────────
INK = (14, 16, 22, 255)
STONE_OUT = (40, 43, 51, 255)
STONE_D = (61, 65, 74, 255)
STONE = (84, 89, 99, 255)
STONE_L = (111, 117, 128, 255)
STONE_HI = (141, 147, 158, 255)
PLASTER_D = (45, 46, 54, 255)
PLASTER = (60, 61, 71, 255)
PLASTER_L = (72, 73, 84, 255)
BRICK_D = (74, 66, 64, 255)
BRICK = (88, 78, 75, 255)
MORTAR = (48, 48, 55, 255)
OAK_OUT = (51, 34, 24, 255)
OAK_D = (73, 48, 31, 255)
OAK = (104, 71, 44, 255)
OAK_L = (133, 95, 58, 255)
OAK_HI = (160, 120, 75, 255)
IRON_D = (45, 47, 55, 255)
IRON = (82, 86, 97, 255)
IRON_L = (131, 137, 150, 255)
BRASS_D = (104, 77, 39, 255)
BRASS = (176, 136, 73, 255)
BRASS_L = (228, 192, 121, 255)
MOSS_OUT = (35, 49, 28, 255)
MOSS_D = (56, 76, 42, 255)
MOSS = (84, 112, 58, 255)
MOSS_L = (119, 149, 75, 255)
MOSS_HI = (163, 189, 101, 255)
GLASS = (69, 98, 126, 255)
GLASS_D = (47, 69, 94, 255)
STAR = (168, 196, 214, 255)
EYE = (21, 25, 30, 255)
GLINT = (151, 211, 202, 255)
MUSH = (176, 86, 58, 255)
MUSH_L = (218, 128, 86, 255)
CREAM = (214, 199, 160, 255)
FLOWER = (214, 190, 92, 255)


class Surface:
    """Tiny painter that tracks albedo, height, roughness and normal bias."""

    def __init__(self, w: int, h: int) -> None:
        self.w = w
        self.h = h
        self.rgba = [[(0, 0, 0, 0) for _ in range(w)] for _ in range(h)]
        self.height = [[0.0 for _ in range(w)] for _ in range(h)]
        self.rough = [[0.9 for _ in range(w)] for _ in range(h)]
        self.bias = [[(0.0, 0.0) for _ in range(w)] for _ in range(h)]

    def put(self, x: int, y: int, color, h: float | None = None,
            rough: float | None = None, bias: tuple[float, float] | None = None
            ) -> None:
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        if color[3] == 0:
            return
        self.rgba[y][x] = color
        if h is not None:
            self.height[y][x] = h
        if rough is not None:
            self.rough[y][x] = rough
        if bias is not None:
            self.bias[y][x] = bias

    def rect(self, x0: int, y0: int, x1: int, y1: int, color,
             h: float, rough: float) -> None:
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.put(x, y, color, h, rough)

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, color,
                h: float, rough: float, sphere: float = 0.0,
                cyl: float = 0.0) -> None:
        for y in range(int(math.floor(cy - ry)), int(math.ceil(cy + ry)) + 1):
            for x in range(int(math.floor(cx - rx)), int(math.ceil(cx + rx)) + 1):
                dx = (x + 0.5 - cx) / max(rx, 0.001)
                dy = (y + 0.5 - cy) / max(ry, 0.001)
                if dx * dx + dy * dy <= 1.0:
                    bx = dx * sphere + dx * cyl
                    by = dy * sphere
                    self.put(x, y, color, h, rough, (bx, by))

    def line(self, x0: int, y0: int, x1: int, y1: int, color,
             h: float | None = None, rough: float | None = None,
             thick: int = 1) -> None:
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        x, y = x0, y0
        while True:
            for oy in range(thick):
                for ox in range(thick):
                    self.put(x + ox, y + oy, color, h, rough)
            if x == x1 and y == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x += sx
            if e2 <= dx:
                err += dx
                y += sy

    def triangle(self, p0, p1, p2, color, h: float, rough: float,
                 bias_origin: tuple[float, float] | None = None,
                 bias_strength: float = 0.0) -> None:
        xs = [p0[0], p1[0], p2[0]]
        ys = [p0[1], p1[1], p2[1]]
        x0, x1 = max(0, min(xs)), min(self.w - 1, max(xs))
        y0, y1 = max(0, min(ys)), min(self.h - 1, max(ys))
        area = (p1[0] - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (p1[1] - p0[1])
        if abs(area) < 0.0001:
            return

        def edge(ax, ay, bx, by, px, py):
            return (bx - ax) * (py - ay) - (by - ay) * (px - ax)

        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                w0 = edge(p1[0], p1[1], p2[0], p2[1], x + 0.5, y + 0.5)
                w1 = edge(p2[0], p2[1], p0[0], p0[1], x + 0.5, y + 0.5)
                w2 = edge(p0[0], p0[1], p1[0], p1[1], x + 0.5, y + 0.5)
                if (w0 >= 0 and w1 >= 0 and w2 >= 0) or \
                        (w0 <= 0 and w1 <= 0 and w2 <= 0):
                    bias = None
                    if bias_origin is not None and bias_strength > 0.0:
                        dx = (x + 0.5 - bias_origin[0]) / 14.0
                        dy = (y + 0.5 - bias_origin[1]) / 14.0
                        bias = (dx * bias_strength, dy * bias_strength)
                    self.put(x, y, color, h, rough, bias)

    def outline_inside(self, color) -> None:
        """Darken opaque pixels touching transparency (keeps silhouettes 1px)."""
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.rgba[y][x][3] == 0:
                    continue
                for nx, ny in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + nx, y + ny
                    if xx < 0 or yy < 0 or xx >= self.w or yy >= self.h or \
                            self.rgba[yy][xx][3] == 0:
                        edge.append((x, y))
                        break
        for x, y in edge:
            self.rgba[y][x] = color

    def speckle(self, x0: int, y0: int, x1: int, y1: int, colors,
                rng: random.Random, chance: float, h_delta: float = 0.0) -> None:
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                if self.rgba[y][x][3] == 0:
                    continue
                if rng.random() < chance:
                    self.put(x, y, rng.choice(colors),
                             self.height[y][x] + h_delta, self.rough[y][x])

    def dim_rect(self, x0: int, y0: int, x1: int, y1: int, factor: float) -> None:
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                c = self.rgba[y][x]
                if c[3] == 0:
                    continue
                self.rgba[y][x] = (int(c[0] * factor), int(c[1] * factor),
                                   int(c[2] * factor), c[3])

    # ── export ────────────────────────────────────────────────────────────
    def albedo_image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                im.putpixel((x, y), self.rgba[y][x])
        return im

    def height_image(self) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.rgba[y][x]
                if c[3] == 0:
                    im.putpixel((x, y), (0, 0, 0, 0))
                else:
                    v = max(0, min(255, int(self.height[y][x] * 255)))
                    im.putpixel((x, y), (v, v, v, 255))
        return im

    def normal_image(self, gain: float = 3.6,
                     edge_height: float = 0.02) -> Image.Image:
        im = Image.new("RGBA", (self.w, self.h))
        for y in range(self.h):
            for x in range(self.w):
                c = self.rgba[y][x]
                if c[3] == 0:
                    im.putpixel((x, y), (128, 128, 255, 0))
                    continue
                hl = self.height[y][x - 1] if x > 0 and self.rgba[y][x - 1][3] else edge_height
                hr = self.height[y][x + 1] if x < self.w - 1 and self.rgba[y][x + 1][3] else edge_height
                hu = self.height[y - 1][x] if y > 0 and self.rgba[y - 1][x][3] else edge_height
                hd = self.height[y + 1][x] if y < self.h - 1 and self.rgba[y + 1][x][3] else edge_height
                bx, by = self.bias[y][x]
                nx = -(hr - hl) * gain + bx
                ny = -(hd - hu) * gain + by
                nz = 1.0
                ln = math.sqrt(nx * nx + ny * ny + nz * nz)
                nx, ny, nz = nx / ln, ny / ln, nz / ln
                r = int(round((nx * 0.5 + 0.5) * 255))
                g = int(round((-ny * 0.5 + 0.5) * 255))
                b = int(round((nz * 0.5 + 0.5) * 255))
                a = int(round(self.rough[y][x] * 255))
                im.putpixel((x, y), (r, g, b, a))
        return im


def save(surface: Surface, name: str, gain: float = 3.6) -> None:
    surface.albedo_image().save(os.path.join(OUT, name + ".png"))
    surface.height_image().save(os.path.join(OUT, name + "_height.png"))
    surface.normal_image(gain).save(os.path.join(OUT, name + "_normal.png"))
    print("wrote", name)


# ── room wall ─────────────────────────────────────────────────────────────
def build_wall() -> Surface:
    rng = random.Random(20261125)
    s = Surface(320, 116)
    s.rect(0, 0, 319, 115, PLASTER, 0.42, 0.94)
    # soft damp stains and plaster noise
    for _ in range(460):
        x, y = rng.randrange(320), rng.randrange(116)
        s.put(x, y, rng.choice([PLASTER_D, PLASTER_L]), 0.42, 0.94)
    for cx, cy, rx, ry in ((176, 92, 46, 16), (262, 100, 30, 10), (120, 58, 20, 9)):
        for y in range(cy - ry, cy + ry + 1):
            for x in range(cx - rx, cx + rx + 1):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    if rng.random() < 0.45:
                        s.put(x, y, PLASTER_D, 0.42, 0.95)

    # exposed brick band (behind the objects, low on the wall)
    s.rect(96, 68, 295, 105, MORTAR, 0.18, 0.96)
    for row, y in enumerate(range(70, 105, 9)):
        x = 96 - (row % 2) * 11
        while x < 296:
            bw = 21
            cols = [BRICK, BRICK_D,
                    (96, 85, 81, 255), (81, 72, 70, 255)]
            c = cols[rng.randrange(len(cols))]
            s.rect(max(97, x + 1), y + 1, min(294, x + bw - 1), y + 8,
                   c, 0.52, 0.93)
            s.rect(max(97, x + 1), y + 1, min(294, x + bw - 1), y + 2,
                   tuple(min(255, v + 12) for v in c[:3]) + (255,),
                   0.56, 0.92)
            x += bw

    # top beam
    s.rect(0, 0, 319, 9, OAK_D, 0.82, 0.82)
    s.rect(0, 0, 319, 2, OAK_L, 0.88, 0.8)
    s.rect(0, 9, 319, 10, INK, 0.5, 0.9)
    for y in range(3, 10):
        for x in range(0, 320, 17):
            if rng.random() < 0.6:
                s.put(x + rng.randrange(0, 6), y, OAK, 0.8, 0.82)

    # timber posts
    for x0 in (86, 296):
        s.rect(x0, 0, x0 + 9, 115, OAK_D, 0.78, 0.84)
        s.rect(x0, 0, x0 + 2, 115, OAK, 0.82, 0.82)
        s.rect(x0 + 7, 0, x0 + 9, 115, (56, 38, 26, 255), 0.72, 0.86)
        for y in range(14, 116, 19):
            s.put(x0 + 4 + rng.randrange(0, 3), y, OAK_L, 0.8, 0.82)

    # bottom skirting board
    s.rect(0, 106, 319, 115, OAK_D, 0.84, 0.84)
    s.rect(0, 106, 319, 107, OAK_L, 0.9, 0.8)
    s.rect(0, 114, 319, 115, INK, 0.5, 0.9)

    # small boarded window, cool glass for a second colour temperature
    s.rect(201, 25, 239, 65, OAK_D, 0.86, 0.8)
    s.rect(204, 28, 236, 62, GLASS_D, 0.30, 0.55)
    s.rect(206, 30, 234, 60, GLASS, 0.33, 0.5)
    for sx, sy in ((210, 34), (224, 39), (231, 33), (215, 52), (228, 55)):
        s.put(sx, sy, STAR, 0.34, 0.5)
    s.rect(218, 28, 220, 62, OAK, 0.72, 0.82)
    s.rect(204, 44, 236, 46, OAK, 0.72, 0.82)
    s.rect(201, 65, 239, 68, OAK_L, 0.9, 0.8)
    s.rect(199, 69, 241, 70, INK, 0.4, 0.9)

    # shelf + jars (above the statue)
    s.rect(104, 44, 166, 49, OAK, 0.8, 0.82)
    s.rect(104, 44, 166, 45, OAK_HI, 0.86, 0.78)
    s.rect(106, 50, 108, 56, OAK_D, 0.72, 0.86)
    s.rect(162, 50, 164, 56, OAK_D, 0.72, 0.86)
    for jx, cap in ((112, MOSS_L), (127, BRASS), (142, (150, 96, 88, 255))):
        s.rect(jx, 34, jx + 7, 43, (57, 67, 76, 255), 0.62, 0.3)
        s.rect(jx + 1, 36, jx + 6, 42, cap, 0.66, 0.28)
        s.put(jx + 2, 36, (222, 238, 230, 255), 0.7, 0.25)
        s.rect(jx + 2, 32, jx + 5, 34, OAK_D, 0.72, 0.7)

    # tool board on the right
    s.rect(247, 27, 291, 63, OAK_D, 0.62, 0.86)
    s.rect(249, 29, 289, 61, (92, 63, 41, 255), 0.66, 0.85)
    for x in range(250, 290, 7):
        s.put(x, 30, OAK, 0.68, 0.85)
    # hammer
    s.rect(255, 34, 263, 37, IRON, 0.82, 0.32)
    s.rect(255, 34, 256, 37, IRON_L, 0.86, 0.3)
    s.rect(258, 38, 260, 57, OAK_L, 0.78, 0.8)
    # tongs
    s.line(276, 37, 272, 58, IRON, 0.8, 0.3, 2)
    s.line(284, 37, 280, 58, IRON, 0.8, 0.3, 2)
    s.rect(275, 34, 285, 37, IRON_L, 0.84, 0.3)
    # hanging nails
    for x, y in ((252, 22), (288, 22), (184, 18), (180, 68), (244, 74)):
        s.put(x, y, IRON_L, 0.8, 0.3)
        s.put(x + 1, y, IRON_D, 0.75, 0.4)

    s.outline_inside((30, 31, 37, 255))
    return s


# ── room floor ────────────────────────────────────────────────────────────
def build_floor() -> Surface:
    rng = random.Random(9182)
    s = Surface(320, 64)
    # skirting at the top of the floor strip
    s.rect(0, 0, 319, 7, OAK_D, 0.8, 0.84)
    s.rect(0, 0, 319, 1, OAK_L, 0.88, 0.8)
    s.rect(0, 6, 319, 7, INK, 0.4, 0.9)
    # flagstones, three receding courses
    rows = [(8, 25), (26, 44), (45, 63)]
    for ri, (y0, y1) in enumerate(rows):
        s.rect(0, y0, 319, y1, MORTAR, 0.2, 0.96)
        x = -18 if ri % 2 else 0
        while x < 320:
            w = rng.choice([38, 44, 52])
            base = rng.choice([(70, 72, 80, 255), (76, 76, 84, 255),
                               (65, 67, 75, 255), (82, 81, 88, 255)])
            s.rect(max(0, x + 1), y0 + 1, min(319, x + w - 1), y1 - 1,
                   base, 0.58, 0.94)
            # bevel highlight on the upper edge, shade at the bottom
            s.rect(max(0, x + 1), y0 + 1, min(319, x + w - 1), y0 + 2,
                   tuple(min(255, v + 14) for v in base[:3]) + (255,), 0.62, 0.93)
            s.rect(max(0, x + 1), y1 - 2, min(319, x + w - 1), y1 - 1,
                   tuple(int(v * 0.82) for v in base[:3]) + (255,), 0.52, 0.95)
            # surface speckle + a couple of hairline cracks
            for _ in range(10):
                px = rng.randrange(max(0, x + 2), min(320, x + w - 2) + 1)
                py = rng.randrange(y0 + 3, y1 - 1)
                s.put(px, py, rng.choice([(60, 61, 69, 255), (90, 88, 95, 255)]),
                      0.58, 0.95)
            if rng.random() < 0.5:
                cx = rng.randrange(max(0, x + 5), min(319, x + w - 5))
                cy = rng.randrange(y0 + 4, y1 - 3)
                s.line(cx, cy, cx + 2, cy + 1, (51, 52, 60, 255), 0.5, 0.95)
                s.line(cx + 2, cy + 1, cx + 3, cy + 3, (51, 52, 60, 255), 0.5, 0.95)
            x += w
    # a drain grate for a focal detail
    s.rect(168, 50, 184, 62, (44, 45, 53, 255), 0.1, 0.8)
    for x in range(169, 184, 3):
        s.rect(x, 51, x + 1, 61, IRON_D, 0.45, 0.5)
    s.rect(167, 49, 185, 50, IRON, 0.6, 0.5)
    # loose nail + pebbles
    s.line(222, 34, 227, 35, IRON_L, 0.7, 0.35)
    s.put(227, 35, IRON, 0.66, 0.4)
    s.ellipse(126, 57, 3, 1.5, (58, 60, 68, 255), 0.6, 0.9, sphere=0.5)
    s.ellipse(292, 29, 2, 1.2, (92, 90, 97, 255), 0.6, 0.9, sphere=0.5)
    s.outline_inside((26, 27, 33, 255))
    return s


# ── stone fox guardian ────────────────────────────────────────────────────
def build_guardian() -> Surface:
    rng = random.Random(7713)
    s = Surface(64, 88)

    # plinth
    s.rect(2, 80, 61, 87, STONE_D, 0.52, 0.92)
    s.rect(2, 80, 61, 81, STONE, 0.6, 0.9)
    s.rect(8, 72, 55, 80, STONE, 0.66, 0.9)
    s.rect(9, 72, 54, 73, STONE_L, 0.72, 0.88)
    s.rect(11, 77, 52, 78, STONE_D, 0.56, 0.92)
    s.rect(14, 83, 49, 84, STONE_D, 0.5, 0.92)

    # curled tail (left side, behind the body)
    tail = [(16, 50), (11, 55), (8, 61), (8, 68), (11, 74), (16, 78)]
    for i in range(len(tail) - 1):
        x0, y0 = tail[i]
        x1, y1 = tail[i + 1]
        s.line(x0, y0, x1, y1, STONE_D, 0.56, 0.92, 4)
    s.ellipse(18, 79, 5, 4, STONE, 0.6, 0.9, sphere=0.4)
    # haunches + chest
    s.ellipse(24, 63, 10, 12, STONE_D, 0.6, 0.91, sphere=0.45)
    s.ellipse(40, 63, 10, 12, STONE_D, 0.6, 0.91, sphere=0.45)
    s.ellipse(32, 57, 14, 17, STONE, 0.64, 0.9, sphere=0.7)
    s.ellipse(32, 53, 9, 11, STONE_L, 0.72, 0.88, sphere=0.45)
    # front legs + paws
    s.rect(25, 62, 29, 79, STONE_D, 0.6, 0.91)
    s.rect(35, 62, 39, 79, STONE_D, 0.6, 0.91)
    s.ellipse(27, 79, 4, 2.5, STONE, 0.66, 0.9, sphere=0.5)
    s.ellipse(37, 79, 4, 2.5, STONE, 0.66, 0.9, sphere=0.5)
    for x in (26, 28, 36, 38):
        s.put(x, 80, STONE_D, 0.58, 0.92)
    # head + ears
    s.triangle((19, 27), (23, 9), (28, 26), STONE, 0.8, 0.9,
               bias_origin=(23, 18), bias_strength=0.55)
    s.triangle((36, 26), (41, 9), (45, 27), STONE, 0.8, 0.9,
               bias_origin=(41, 18), bias_strength=0.55)
    s.triangle((21, 24), (23, 13), (26, 24), STONE_D, 0.68, 0.94,
               bias_origin=(23, 19), bias_strength=0.35)
    s.triangle((38, 24), (41, 13), (43, 24), STONE_D, 0.68, 0.94,
               bias_origin=(41, 19), bias_strength=0.35)
    s.ellipse(32, 36, 13, 13, STONE, 0.7, 0.9, sphere=0.95)
    s.ellipse(32, 31, 10, 7, STONE_L, 0.74, 0.88, sphere=0.4)
    # muzzle, nose, mouth
    s.ellipse(32, 43, 7, 4.5, STONE_L, 0.68, 0.9, sphere=0.35)
    s.ellipse(32, 41, 2.5, 1.8, STONE_HI, 0.86, 0.82, sphere=0.3)
    s.put(32, 42, STONE_OUT, 0.82, 0.84)
    s.line(29, 45, 35, 45, STONE_D, 0.64, 0.92)
    # brow + eyes (slightly recessed, polished dark stone)
    s.line(24, 33, 29, 34, STONE_D, 0.62, 0.92)
    s.line(35, 34, 40, 33, STONE_D, 0.62, 0.92)
    s.rect(25, 35, 28, 38, EYE, 0.52, 0.34)
    s.rect(36, 35, 39, 38, EYE, 0.52, 0.34)
    s.put(26, 36, GLINT, 0.56, 0.3)
    s.put(37, 36, GLINT, 0.56, 0.3)
    # carved seam between legs and chest
    s.line(32, 50, 32, 59, STONE_D, 0.56, 0.94)
    # moss on plinth, shoulder and tail tip
    for cx, cy, rx, ry in ((14, 79, 10, 4), (53, 80, 8, 3), (19, 53, 5, 3),
                           (29, 25, 4, 2), (16, 79, 5, 2)):
        s.ellipse(cx, cy, rx, ry, MOSS, 0.74, 0.97, sphere=0.2)
    for _ in range(70):
        x = rng.randrange(6, 60)
        y = rng.randrange(24, 87)
        if s.rgba[y][x][3] == 0:
            continue
        if y > 74 or (18 < x < 24 and y < 60) or (25 < x < 34 and y < 28):
            s.put(x, y, rng.choice([MOSS_D, MOSS_L, MOSS_HI]), 0.76, 0.97)
    for x0, y0 in ((9, 75), (11, 74), (48, 76), (30, 22), (17, 55)):
        s.line(x0, y0, x0 - 1, y0 - 4, MOSS_L, 0.8, 0.97)
        s.put(x0 - 2, y0 - 4, MOSS_HI, 0.82, 0.97)
    # chisel cracks
    s.line(34, 49, 32, 55, STONE_D, 0.56, 0.94)
    s.line(32, 55, 35, 60, STONE_D, 0.56, 0.94)
    s.line(12, 75, 16, 76, STONE_D, 0.54, 0.94)
    s.line(44, 76, 48, 77, STONE_D, 0.54, 0.94)
    # chipped highlights (form, not a baked light direction)
    for x in range(24, 40):
        if rng.random() < 0.35:
            s.put(x, 29 + rng.randrange(0, 2), STONE_HI, 0.76, 0.88)
    s.outline_inside(STONE_OUT)
    return s


# ── oak barrel ────────────────────────────────────────────────────────────
def build_barrel() -> Surface:
    rng = random.Random(4410)
    s = Surface(44, 54)
    cy_top = 8.0
    for y in range(7, 51):
        t = (y - 7) / 43.0
        half = 15.0 + 3.0 * math.sin(math.pi * t)
        x0 = int(round(22 - half))
        x1 = int(round(22 + half)) - 1
        for x in range(x0, x1 + 1):
            band = (x - 22) / max(half, 1.0)
            base = OAK if int((band + 1.0) * 3.2) % 2 == 0 else OAK_D
            s.put(x, y, base, 0.58, 0.86,
                  (band * 0.42, 0.0))
    # stave seams
    for x in (11, 16, 22, 28, 33):
        for y in range(8, 51):
            if s.rgba[y][x][3] and s.rgba[y][x][0] in (OAK[0], OAK_D[0]):
                s.put(x, y, OAK_OUT, 0.46, 0.9)
    # grain dashes
    for _ in range(46):
        x = rng.randrange(8, 38)
        y = rng.randrange(10, 50)
        if s.rgba[y][x][3]:
            s.put(x, y, rng.choice([OAK_L, OAK_HI]), 0.6, 0.85)
    # top lid + rim
    s.ellipse(22, 8, 17, 5, OAK_D, 0.7, 0.85)
    s.ellipse(22, 8, 14, 3.4, OAK_L, 0.74, 0.83)
    for x in (14, 20, 26):
        s.line(x, 5, x, 11, OAK, 0.7, 0.85)
    s.ellipse(22, 8, 2, 1.2, IRON_D, 0.82, 0.35)
    for x in range(5, 40):
        for y in range(2, 15):
            dx = (x + 0.5 - 22) / 17.0
            dy = (y + 0.5 - 8) / 5.0
            r = dx * dx + dy * dy
            if 0.86 <= r <= 1.0:
                s.put(x, y, IRON, 0.84, 0.3)
            elif r < 0.86:
                pass
    # hoops with rivets
    for hy in (14, 28, 42):
        t = (hy + 1.5 - 7) / 43.0
        half = 15.0 + 3.0 * math.sin(math.pi * t)
        for x in range(int(20 - half), int(21 + half) + 1):
            s.put(x, hy, IRON, 0.8, 0.29)
            s.put(x, hy + 1, IRON_D, 0.78, 0.31)
            s.put(x, hy + 2, IRON, 0.79, 0.3)
        for x in range(int(21 - half) + 3, int(21 + half) - 2, 7):
            s.put(x, hy + 1, BRASS_L, 0.88, 0.22)
    # small chalk tally for character
    s.line(30, 22, 33, 23, (192, 184, 158, 255), 0.62, 0.92)
    s.line(30, 24, 32, 25, (192, 184, 158, 255), 0.62, 0.92)
    # worn lighter edge on the left
    for y in range(10, 50):
        x = 0
        while x < 44 and s.rgba[y][x][3] == 0:
            x += 1
        if x < 44:
            s.put(x, y, OAK_HI, 0.6, 0.86)
    s.outline_inside(OAK_OUT)
    return s


# ── moss golem ────────────────────────────────────────────────────────────
def build_golem() -> Surface:
    rng = random.Random(3091)
    s = Surface(36, 48)
    # feet
    s.ellipse(11, 44, 6, 3.2, MOSS_D, 0.6, 0.95, sphere=0.5)
    s.ellipse(25, 44, 6, 3.2, MOSS_D, 0.6, 0.95, sphere=0.5)
    # arms
    s.ellipse(5, 32, 4, 6, MOSS_D, 0.62, 0.95, sphere=0.55)
    s.ellipse(31, 32, 4, 6, MOSS_D, 0.62, 0.95, sphere=0.55)
    # body
    s.ellipse(18, 29, 13, 15, MOSS, 0.65, 0.95, sphere=0.95)
    s.ellipse(18, 34, 8, 8, MOSS_L, 0.7, 0.94, sphere=0.5)
    # mushroom on the left arm
    s.rect(6, 27, 7, 29, CREAM, 0.7, 0.6)
    s.ellipse(7, 26, 3.5, 2, MUSH, 0.8, 0.55, sphere=0.4)
    s.put(6, 25, MUSH_L, 0.82, 0.5)
    # eyes
    s.ellipse(12, 24, 4, 5, EYE, 0.5, 0.25, sphere=0.3)
    s.ellipse(24, 24, 4, 5, EYE, 0.5, 0.25, sphere=0.3)
    s.put(11, 22, GLINT, 0.54, 0.22)
    s.put(23, 22, GLINT, 0.54, 0.22)
    s.put(11, 23, (94, 148, 148, 255), 0.54, 0.23)
    s.put(23, 23, (94, 148, 148, 255), 0.54, 0.23)
    # mouth + cheeks
    s.line(16, 33, 20, 33, MOSS_OUT, 0.6, 0.96)
    for x in (9, 10, 26, 27):
        s.put(x, 31, MOSS_HI, 0.7, 0.94)
    # moss speckles
    for _ in range(70):
        x = rng.randrange(1, 35)
        y = rng.randrange(14, 47)
        if s.rgba[y][x][3] == 0 or s.rgba[y][x][:3] == EYE[:3]:
            continue
        s.put(x, y, rng.choice([MOSS_D, MOSS_L, MOSS_HI]),
              0.66, 0.95)
    # little flowers
    for x, y in ((28, 38), (7, 37)):
        s.put(x, y, FLOWER, 0.74, 0.9)
        s.put(x + 1, y, (232, 214, 126, 255), 0.74, 0.9)
    # leaf sprout
    s.line(18, 17, 18, 11, (95, 124, 62, 255), 0.7, 0.8)
    s.triangle((18, 13), (11, 9), (12, 5), MOSS_L, 0.82, 0.62,
               bias_origin=(14, 8), bias_strength=0.4)
    s.triangle((12, 5), (16, 10), (18, 13), MOSS, 0.8, 0.66,
               bias_origin=(14, 8), bias_strength=0.3)
    s.triangle((18, 12), (24, 10), (25, 5), MOSS_L, 0.83, 0.62,
               bias_origin=(22, 8), bias_strength=0.4)
    s.triangle((25, 5), (22, 10), (18, 12), MOSS, 0.81, 0.66,
               bias_origin=(22, 8), bias_strength=0.3)
    s.line(18, 12, 13, 7, MOSS_HI, 0.85, 0.58)
    s.line(18, 12, 23, 7, MOSS_HI, 0.85, 0.58)
    s.outline_inside(MOSS_OUT)
    return s


# ── shadows, glow, native light ──────────────────────────────────────────
def build_shadow(name: str, w: int, h: int, seed: int) -> None:
    rng = random.Random(seed)
    im = Image.new("RGBA", (w, h))
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h / 2) / (h / 2)
            r = dx * dx + dy * dy
            if r > 1.0:
                continue
            alpha = int(105 * (1.0 - r) ** 1.4)
            if (x + y) % 2 == 0:
                alpha = int(alpha * 0.72)
            if alpha > 0:
                im.putpixel((x, y), (7, 8, 12, alpha))
    im.save(os.path.join(OUT, name + ".png"))
    print("wrote", name)


def build_glow() -> None:
    # visible ember: warm core, soft pixel falloff, additive
    size = 64
    im = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - size / 2) / (size / 2)
            dy = (y + 0.5 - size / 2) / (size / 2)
            r = math.sqrt(dx * dx + dy * dy)
            if r > 1.0:
                continue
            core = max(0.0, 1.0 - r * 1.7)
            halo = max(0.0, 1.0 - r) ** 2.2
            a = min(1.0, core * 0.9 + halo * 0.55)
            if a < 1 / 255:
                continue
            rr = int(255 * min(1.0, 0.95 + core * 0.05))
            gg = int(232 * min(1.0, 0.72 + core * 0.35))
            bb = int(178 * min(1.0, 0.36 + core * 0.5))
            im.putpixel((x, y), (rr, gg, bb, int(a * 255)))
    im.save(os.path.join(OUT, "glow.png"))
    print("wrote glow")

    # native PointLight2D texture: both RGB and alpha fall off, so the
    # built-in light pass gets a soft, wide pool instead of a hard disk.
    size = 128
    im = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            dx = (x + 0.5 - size / 2) / (size / 2)
            dy = (y + 0.5 - size / 2) / (size / 2)
            r = math.sqrt(dx * dx + dy * dy)
            if r > 1.0:
                continue
            a = (1.0 - r) ** 1.4
            rr = int(255 * a)
            gg = int(232 * a)
            bb = int(196 * a)
            edge = min(1.0, (1.0 - r) * 8.0)
            im.putpixel((x, y), (rr, gg, bb, int(255 * edge)))
    im.save(os.path.join(OUT, "light_radial.png"))
    print("wrote light_radial")


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    save(build_wall(), "room_wall", gain=3.8)
    save(build_floor(), "room_floor", gain=3.8)
    save(build_guardian(), "guardian", gain=4.0)
    save(build_barrel(), "barrel", gain=4.2)
    save(build_golem(), "golem", gain=4.0)
    build_shadow("shadow_guardian", 78, 18, 11)
    build_shadow("shadow_barrel", 58, 15, 12)
    build_shadow("shadow_golem", 50, 13, 13)
    build_glow()
    print("ASSETS_OK out=" + OUT)


if __name__ == "__main__":
    main()
