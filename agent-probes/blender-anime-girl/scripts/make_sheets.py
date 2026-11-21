"""Compose the character-sheet contact sheet, 25% thumbnail and silhouette check.

Uses system Python + Pillow (not Blender's bundled Python).

  python3 scripts/make_sheets.py
"""

import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = os.path.join(ROOT, 'renders')

BG = (242, 234, 223)
INK = (44, 52, 48)
MUTED = (106, 111, 104)
JADE = (79, 130, 114)

VIEWS = [('front', 'FRONT  ·  正面'), ('side', 'SIDE  ·  侧面'),
         ('back', 'BACK  ·  背面'),
         ('three_quarter', '3/4  ·  四分之三')]

TITLE_H = 128
CELL_W, CELL_H = 720, 900
GAP = 0

font_cn = ImageFont.truetype('/System/Library/Fonts/PingFang.ttc', 46)
font_en = ImageFont.truetype('/System/Library/Fonts/HelveticaNeue.ttc', 25)
font_lbl = ImageFont.truetype('/System/Library/Fonts/PingFang.ttc', 26)
font_meta = ImageFont.truetype('/System/Library/Fonts/HelveticaNeue.ttc', 20)

sheet = Image.new('RGB', (CELL_W * 2 + GAP, TITLE_H + CELL_H * 2 + GAP), BG)
draw = ImageDraw.Draw(sheet)
draw.text((46, 26), 'QINGHE · 青禾', font=font_cn, fill=INK)
draw.text((48, 84),
          'Original herbalist apprentice  ·  light-chibi 4.8 heads  ·  '
          'Blender 3.4.1 EEVEE Legacy  ·  toon + inverted-hull outline',
          font=font_meta, fill=MUTED)
draw.line((46, TITLE_H - 12, sheet.width - 46, TITLE_H - 12), fill=JADE,
          width=2)

for i, (name, label) in enumerate(VIEWS):
    img = Image.open(os.path.join(R, name + '.png')).convert('RGB')
    img = img.resize((CELL_W, CELL_H), Image.LANCZOS)
    x = (i % 2) * (CELL_W + GAP)
    y = TITLE_H + (i // 2) * (CELL_H + GAP)
    sheet.paste(img, (x, y))
    box = draw.textbbox((0, 0), label, font=font_lbl)
    tw = box[2] - box[0]
    draw.rounded_rectangle((x + 22, y + 22, x + 44 + tw, y + 60), radius=8,
                           fill=(250, 246, 238))
    draw.text((x + 32, y + 28), label, font=font_lbl, fill=INK)
    if i % 2 == 0:
        draw.line((x + CELL_W - 1, y, x + CELL_W - 1, y + CELL_H),
                  fill=(226, 217, 204), width=2)
    if i // 2 == 0:
        draw.line((x, y + CELL_H - 1, x + CELL_W, y + CELL_H - 1),
                  fill=(226, 217, 204), width=2)

sheet.save(os.path.join(R, 'contact_sheet.png'), optimize=True)
thumb = sheet.resize((sheet.width // 4, sheet.height // 4), Image.LANCZOS)
thumb.save(os.path.join(R, 'contact_sheet_25pct.png'), optimize=True)

# pure-black silhouette check from the transparent alpha plate
raw = Image.open(os.path.join(R, '_silhouette_raw.png')).convert('RGBA')
alpha = raw.getchannel('A').point(lambda a: 255 if a > 127 else 0)
sil = Image.new('RGB', raw.size, (255, 255, 255))
sil.paste((0, 0, 0), (0, 0), alpha)
sil.save(os.path.join(R, 'silhouette_front.png'), optimize=True)
black = sum(1 for p in alpha.getdata() if p)
print('SHEETS_OK contact=%s thumb=%s silhouette=%s black_px=%.2f%%' % (
    os.path.join(R, 'contact_sheet.png'),
    os.path.join(R, 'contact_sheet_25pct.png'),
    os.path.join(R, 'silhouette_front.png'),
    100.0 * black / (alpha.width * alpha.height)))
