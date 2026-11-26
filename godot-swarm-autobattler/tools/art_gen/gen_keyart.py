"""Victory key art 1920x1080: tideheart core + two converging swarms."""
from __future__ import annotations

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from artlib import (
    BRASS_HI, CARD_NAMES, CARDS, creature_plate, glow, new_layer, solid_ellipse,
    solid_poly,
)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "keyart")
UNIT_ATLAS = os.path.join(ROOT, "assets", "art", "units", "unit_atlas_10x12_768x640.png")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")
W, H = 1920, 1080


def background() -> Image.Image:
    rng = random.Random(7)
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    ys = np.linspace(0, 1, H)[:, None]
    top = np.array([6, 11, 17], np.float32)
    mid = np.array([10, 20, 28], np.float32)
    bot = np.array([3, 6, 9], np.float32)
    for i in range(3):
        col = np.where(ys < 0.55, top[i] * (1 - ys / 0.55) + mid[i] * (ys / 0.55),
                       mid[i] * (1 - (ys - 0.55) / 0.45) + bot[i] * ((ys - 0.55) / 0.45))
        arr[..., i] = col.astype(np.uint8)
    arr[..., 3] = 255
    img = Image.fromarray(arr, "RGBA")
    # foundry hall silhouette
    d = ImageDraw.Draw(img)
    for k in range(5):
        x = 120 + k * 420
        d.rectangle((x, 0, x + 70, 720), fill=(6, 11, 15, 255))
        d.rectangle((x + 120, 0, x + 150, 620), fill=(6, 11, 15, 255))
    # big arch
    d.arc((W * 0.16, -H * 0.22, W * 0.84, H * 0.92), 180, 360, fill=(24, 42, 50, 255), width=60)
    d.arc((W * 0.16, -H * 0.22, W * 0.84, H * 0.92), 180, 360, fill=(60, 110, 120, 60), width=6)
    # gate pylons at the edges
    for side in (0, 1):
        x = 60 if side == 0 else W - 200
        col = (55, 224, 199) if side == 0 else (255, 98, 72)
        d.rounded_rectangle((x, 260, x + 140, 830), radius=60, fill=(9, 18, 24, 255),
                            outline=(40, 70, 80, 255), width=5)
        for k in range(4):
            yy = 340 + k * 120
            d.line((x + 18, yy, x + 122, yy), fill=(*col, 70), width=5)
    glow(img, (W / 2, H * 0.62), 650, (55, 190, 190), 0.25)
    glow(img, (W * 0.5, H * 0.9), 700, (150, 80, 40), 0.16)
    return img


def tint_sprite(sprite: Image.Image, color, bright=0.95):
    arr = np.asarray(sprite.convert("RGBA"), dtype=np.float32)
    arr[..., 0] *= color[0] * bright
    arr[..., 1] *= color[1] * bright
    arr[..., 2] *= color[2] * bright
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def swarm(img: Image.Image, atlas: Image.Image, team: int, rng: random.Random):
    col = (0.42, 1.0, 0.93) if team == 0 else (1.0, 0.48, 0.36)
    for i in range(240):
        card = rng.randrange(10)
        frame = 0 if rng.random() > 0.12 else 11
        cell = atlas.crop((frame * 64, card * 64, frame * 64 + 64, card * 64 + 64))
        cell = tint_sprite(cell, col, rng.uniform(0.7, 1.15))
        # converge toward the centre, biased to team side
        t = rng.random()
        if team == 0:
            x = rng.uniform(-40, 760) + t * 160
            y = H * 0.5 + rng.gauss(0, 190) + (t - 0.5) * 120
        else:
            x = W - (rng.uniform(-40, 760) + t * 160)
            y = H * 0.5 + rng.gauss(0, 190) + (t - 0.5) * 120
        size = rng.uniform(26, 76)
        cell = cell.resize((int(size), int(size)), Image.LANCZOS)
        if team == 1:
            cell = cell.transpose(Image.FLIP_LEFT_RIGHT)
        alpha = rng.uniform(0.35, 0.9)
        cell.putalpha(cell.getchannel("A").point(lambda v: int(v * alpha)))
        # motion trail
        trail = Image.new("RGBA", (int(size * 2.6), max(2, int(size * 0.18))), (0, 0, 0, 0))
        td = ImageDraw.Draw(trail)
        tc = (int(col[0] * 255), int(col[1] * 255), int(col[2] * 255), rng.randint(16, 42))
        td.line((0, trail.height // 2, trail.width, trail.height // 2), fill=tc, width=max(1, int(size * 0.1)))
        if team == 0:
            img.alpha_composite(trail, (int(x - trail.width + size * 0.36), int(y + size * 0.4)))
        else:
            img.alpha_composite(trail, (int(x + size * 0.64), int(y + size * 0.4)))
        img.alpha_composite(cell, (int(x - size / 2), int(y - size / 2)))


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    img = background()
    atlas = Image.open(UNIT_ATLAS).convert("RGBA")
    rng = random.Random(20261126)

    # giant tideheart core
    core_layer = Image.new("RGBA", (1400, 1400), (0, 0, 0, 0))
    core = creature_plate("tideheart_engine", {"dy": 0, "wing": 1.2, "ant": 0.5}, 14.0, 1400,
                          shadow=False)
    core = tint_sprite(core, (0.72, 1.0, 0.96), 1.0)
    core_layer.alpha_composite(core)
    img.alpha_composite(core_layer, (W // 2 - 700, 300 - 200))
    # orbit rings / energy arcs
    d = ImageDraw.Draw(img)
    for r, a in ((330, 55), (390, 30), (280, 40)):
        d.ellipse((W / 2 - r, H * 0.56 - r * 0.26, W / 2 + r, H * 0.56 + r * 0.26),
                  outline=(110, 245, 235, a), width=3)
    for i in range(8):
        a0 = i * 45
        d.arc((W / 2 - 420, H * 0.56 - 110, W / 2 + 420, H * 0.56 + 110),
              a0, a0 + 16, fill=(190, 255, 250, 80), width=4)
    glow(img, (W / 2, H * 0.55), 480, (110, 250, 245), 0.30)

    # swarms
    swarm(img, atlas, 0, rng)
    swarm(img, atlas, 1, rng)

    # foreground floor reflect + embers
    d = ImageDraw.Draw(img)
    for i in range(90):
        x = rng.uniform(0, W)
        y = rng.uniform(H * 0.55, H)
        r = rng.uniform(0.8, 3.2)
        col = (255, 210, 140) if i % 3 == 0 else (140, 255, 245)
        solid_ellipse(img, (x - r, y - r, x + r, y + r), (*col, rng.randint(40, 140)))
    # title / bottom safe gradients
    grad = np.zeros((H, W, 4), dtype=np.uint8)
    yy = np.linspace(0, 1, H)[:, None]
    topa = np.clip((0.28 - yy) * 3.2, 0, 1) * 220
    bota = np.clip((yy - 0.78) * 4.0, 0, 1) * 200
    grad[..., 3] = np.clip(topa + bota, 0, 230).astype(np.uint8)
    grad[..., 0:3] = 0
    img.alpha_composite(Image.fromarray(grad, "RGBA"))
    # vignette
    xx = np.linspace(0, 1, W)[None, :]
    vig = np.clip((np.abs(xx - 0.5) - 0.32) * 3.0, 0, 1) * 120
    arr = np.zeros((H, W, 4), dtype=np.uint8)
    arr[..., 3] = vig.astype(np.uint8)
    img.alpha_composite(Image.fromarray(arr, "RGBA"))

    path = os.path.join(OUT_DIR, "victory_1920x1080.png")
    img.save(path)
    print("KEYART", path, img.size)
    img.resize((960, 540), Image.LANCZOS).save(os.path.join(PREVIEW_DIR, "keyart_preview.png"))
    print("KEYART_PREVIEW", os.path.join(PREVIEW_DIR, "keyart_preview.png"))


if __name__ == "__main__":
    main()
