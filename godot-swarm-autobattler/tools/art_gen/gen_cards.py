"""Generate 10 original card illustrations (512 src) and a 1024x768 atlas."""
from __future__ import annotations

import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

from artlib import (
    BRASS, BRASS_HI, CARD_NAMES, CARDS, CER_MID, ENERGY, NAVY_DEEP,
    add_painterly_finish, creature_plate, glow, illustration_bg, line, new_layer,
    solid_ellipse, solid_poly,
)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "cards")
SRC_DIR = os.path.join(OUT_DIR, "src")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")
SIZE = 512
SC = 7.0

ACCENT = {
    "spark_flea": (80, 230, 215), "rivet_grub": (200, 168, 110),
    "prism_gadfly": (115, 220, 255), "magwire_mantis": (170, 200, 255),
    "arc_ant": (130, 230, 255), "spore_ballista": (180, 230, 140),
    "weave_moth": (255, 170, 95), "molten_weaver": (255, 130, 60),
    "crown_colossus": (245, 190, 105), "tideheart_engine": (110, 245, 235),
}


def add_extras(img, card_id, seed):
    rng = random.Random(seed)
    d = ImageDraw.Draw(img)
    col = ACCENT[card_id]
    if card_id in ("spark_flea", "magwire_mantis", "arc_ant"):
        # speed streaks / electric arcs
        for i in range(5):
            y = rng.uniform(170, 390)
            x0 = rng.uniform(20, 90)
            x1 = x0 + rng.uniform(90, 190)
            d.line((x0, y, x1, y + rng.uniform(-8, 8)), fill=(*col, rng.randint(20, 60)),
                   width=rng.randint(1, 3))
        if card_id == "arc_ant":
            for i in range(3):
                pts = [(rng.uniform(120, 380), rng.uniform(140, 380)) for _ in range(5)]
                line(img, pts, (*col, 90), 1.5)
    elif card_id == "prism_gadfly":
        for i in range(4):
            x = rng.uniform(60, 450)
            y = rng.uniform(100, 330)
            r = rng.uniform(12, 32)
            solid_poly(img, [(x, y - r), (x + r * 0.8, y), (x, y + r), (x - r * 0.8, y)],
                       (*col, rng.randint(8, 22)))
        line(img, [(40, 400), (160, 300)], (*col, 60), 2)
    elif card_id in ("weave_moth", "molten_weaver"):
        # embers rising from the furnace floor
        for i in range(26):
            x = rng.uniform(60, 452)
            y = rng.uniform(210, 440)
            r = rng.uniform(1.0, 3.2)
            a = rng.randint(60, 160)
            solid_ellipse(img, (x - r, y - r, x + r, y + r), (*col, a))
        glow(img, (SIZE * 0.5, SIZE * 0.9), SIZE * 0.52, (255, 120, 50), 0.30)
    elif card_id == "spore_ballista":
        for i in range(7):
            x = rng.uniform(80, 440)
            y = rng.uniform(180, 430)
            r = rng.uniform(8, 24)
            solid_ellipse(img, (x - r, y - r * 0.7, x + r, y + r * 0.7), (*col, 16))
        for i in range(10):
            x = rng.uniform(60, 450)
            y = rng.uniform(200, 420)
            r = rng.uniform(1, 2.5)
            solid_ellipse(img, (x - r, y - r, x + r, y + r), (*col, rng.randint(70, 150)))
    elif card_id == "rivet_grub":
        for i in range(4):
            x = rng.uniform(30, 480)
            y = rng.uniform(150, 420)
            d.rectangle((x, y, x + rng.uniform(18, 46), y + rng.uniform(6, 14)),
                        outline=(*col, 20), width=1)
        glow(img, (SIZE * 0.22, SIZE * 0.72), SIZE * 0.32, (255, 150, 70), 0.15)
    elif card_id == "crown_colossus":
        # foundry arch silhouette
        arc_box = (SIZE * 0.14, SIZE * 0.06, SIZE * 0.86, SIZE * 0.92)
        d.arc(arc_box, 195, 345, fill=(*col, 40), width=10)
        d.arc(arc_box, 195, 345, fill=(240, 220, 180, 20), width=3)
        for i in range(18):
            x = rng.uniform(100, 420)
            y = rng.uniform(120, 430)
            r = rng.uniform(0.8, 2.2)
            solid_ellipse(img, (x - r, y - r, x + r, y + r), (*BRASS_HI, rng.randint(50, 130)))
    elif card_id == "tideheart_engine":
        for k in range(3):
            r = 130 + k * 28
            d.ellipse((SIZE / 2 - r, SIZE * 0.52 - r * 0.3, SIZE / 2 + r, SIZE * 0.52 + r * 0.3),
                      outline=(*col, 45 - k * 10), width=2)
        for i in range(14):
            x = rng.uniform(80, 430)
            y = rng.uniform(120, 420)
            r = rng.uniform(0.8, 2.4)
            solid_ellipse(img, (x - r, y - r, x + r, y + r), (*col, rng.randint(50, 140)))
    # foreground haze at the bottom (soft, not a hard band)
    haze = Image.new("L", (SIZE, SIZE), 0)
    hd = ImageDraw.Draw(haze)
    hd.rectangle((0, SIZE * 0.88, SIZE, SIZE), fill=70)
    haze = haze.filter(ImageFilter.GaussianBlur(SIZE * 0.06))
    layer = Image.new("RGBA", (SIZE, SIZE), (10, 18, 24, 0))
    layer.putalpha(haze)
    img.alpha_composite(layer)


def compose(card_id: str, index: int) -> Image.Image:
    img = illustration_bg(SIZE, card_id, seed=1000 + index)
    # accent glow behind the subject
    glow(img, (SIZE * 0.55, SIZE * 0.42), SIZE * 0.5, ACCENT[card_id], 0.14)
    # soft ground shadow (no hard pill): keep the creature anchored
    from artlib import contact_shadow
    contact_shadow(img, (SIZE * 0.5, SIZE * 0.86), SIZE * 0.29, SIZE * 0.05, 46)
    add_extras(img, card_id, seed=2000 + index)
    pose = {"dy": 0.0, "leg": 0.0, "ant": 0.5, "wing": 1.0}
    creature = creature_plate(card_id, pose, SC, SIZE, shadow=False)
    # shift art slightly up to leave a floor band
    img.alpha_composite(creature, (0, -int(SIZE * 0.035)))
    # coloured power core so each card has a readable accent identity
    glow(img, (SIZE * 0.52, SIZE * 0.50), SIZE * 0.16, ACCENT[card_id], 0.30)
    glow(img, (SIZE * 0.50, SIZE * 0.50), SIZE * 0.06, (255, 255, 255), 0.35)
    add_painterly_finish(img, seed=3000 + index)
    # inner black border keeps atlas cells separated
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, SIZE - 1, SIZE - 1), outline=(3, 7, 11, 255), width=6)
    return img


def main() -> None:
    os.makedirs(SRC_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    srcs = []
    for i, cid in enumerate(CARDS):
        img = compose(cid, i)
        p = os.path.join(SRC_DIR, f"{i:02d}_{cid}_512.png")
        img.save(p)
        srcs.append(img)
        print("CARD_SRC", p)

    atlas = Image.new("RGBA", (1024, 768), (*NAVY_DEEP, 255))
    for i, img in enumerate(srcs):
        cell = img.resize((256, 256), Image.LANCZOS)
        x = (i % 4) * 256
        y = (i // 4) * 256
        atlas.alpha_composite(cell, (x, y))
    path = os.path.join(OUT_DIR, "card_atlas_1024x768.png")
    atlas.save(path)
    print("CARD_ATLAS", path, atlas.size)

    # preview: 5 columns with card names
    preview = Image.new("RGBA", (5 * 300 + 20, 2 * 330 + 50), (12, 18, 24, 255))
    d = ImageDraw.Draw(preview)
    from PIL import ImageFont
    try:
        font = ImageFont.truetype("/System/Library/Fonts/PingFang.ttc", 15)
    except Exception:
        font = None
    d.text((12, 12), "CARD ILLUSTRATIONS · 10 original micro-foundry constructs (512 src / 256 atlas)", fill=(230, 240, 246, 255))
    for i, cid in enumerate(CARDS):
        x = 20 + (i % 5) * 300
        y = 46 + (i // 5) * 330
        preview.alpha_composite(srcs[i].resize((280, 280), Image.LANCZOS), (x, y))
        d.text((x, y + 288), f"{i}  {CARD_NAMES[cid]}", fill=(200, 235, 240, 255), font=font)
    pp = os.path.join(PREVIEW_DIR, "card_art_preview.png")
    preview.save(pp)
    print("CARD_PREVIEW", pp, preview.size)


if __name__ == "__main__":
    main()
