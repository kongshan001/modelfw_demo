"""Generate the battle unit atlas: 12 frames x 10 cards, 64 px cells -> 768x640."""
from __future__ import annotations

import os

from PIL import Image, ImageDraw

from artlib import CARD_NAMES, CARDS, POSES, creature_plate, frame_pose, new_layer

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "art", "units")
PREVIEW_DIR = os.path.join(ROOT, "docs", "shots", "art-impl")

CELL = 64
COLS = 12
ROWS = 10
SC = 3.72
MARGIN = 4


def render_cell(card_id: str, frame: int) -> Image.Image:
    canvas_px = int(CELL * 4)
    plate = creature_plate(card_id, frame_pose(card_id, frame), SC, canvas_px)
    if frame == 5:
        # hit spark at the front of the unit
        d = ImageDraw.Draw(plate)
        cx, cy = canvas_px * 0.80, canvas_px * 0.44
        r = canvas_px * 0.075
        for k in range(4):
            a = k * 3.14159 / 2 + 0.4
            d.line((cx, cy, cx + __import__("math").cos(a) * r * 1.9,
                    cy + __import__("math").sin(a) * r * 1.9),
                   fill=(255, 248, 220, 235), width=max(1, int(canvas_px * 0.012)))
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 255, 245, 245))
    cell = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    small = plate.resize((CELL, CELL), Image.LANCZOS)
    cell.alpha_composite(small)
    return cell


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * COLS, CELL * ROWS), (0, 0, 0, 0))
    for row, card_id in enumerate(CARDS):
        for frame in range(COLS):
            cell = render_cell(card_id, frame)
            atlas.alpha_composite(cell, (frame * CELL, row * CELL))
    path = os.path.join(OUT_DIR, "unit_atlas_10x12_768x640.png")
    atlas.save(path)
    print("UNIT_ATLAS", path, atlas.size)

    # 3x preview with labels for internal/AD review
    scale = 3
    preview = atlas.resize((atlas.width * scale, atlas.height * scale), Image.NEAREST)
    px = preview.load()
    # checkerboard behind so transparency is visible
    board = Image.new("RGBA", preview.size, (22, 26, 30, 255))
    bd = ImageDraw.Draw(board)
    for y in range(0, board.height, 24):
        for x in range(0, board.width, 24):
            if (x // 24 + y // 24) % 2 == 0:
                bd.rectangle((x, y, x + 23, y + 23), fill=(30, 35, 40, 255))
    board.alpha_composite(preview)
    out = Image.new("RGBA", (board.width + 190, board.height + 80), (12, 18, 24, 255))
    out.alpha_composite(board, (180, 60))
    d = ImageDraw.Draw(out)
    d.text((12, 18), "UNIT ATLAS · 10 cards x 12 frames · 64px cells", fill=(230, 240, 246, 255))
    d.text((12, 36), "0-1 idle / 2-3 move / 4-6 attack / 7-9 death / 10 spawn / 11 elite", fill=(150, 180, 192, 255))
    for row, card_id in enumerate(CARDS):
        d.text((10, 64 + row * CELL * scale + CELL * scale // 2 - 6),
               f"{row} {CARD_NAMES[card_id]}", fill=(200, 230, 235, 255))
    for frame in range(COLS):
        d.text((184 + frame * CELL * scale + 8, 40), str(frame), fill=(150, 200, 210, 255))
    preview_path = os.path.join(PREVIEW_DIR, "unit_atlas_preview.png")
    out.save(preview_path)
    print("UNIT_PREVIEW", preview_path, out.size)


if __name__ == "__main__":
    main()
