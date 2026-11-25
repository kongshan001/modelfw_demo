"""Compose the v0.1 character sheet, 25% thumb, silhouette, comparison and GIF.

Uses system Python + Pillow (not Blender's bundled Python).

  python3 tools/blender_anime/make_sheets.py \
    --dir agent-probes/blender-anime-v01 \
    --compare agent-probes/blender-anime-girl/renders
"""

import argparse
import json
import os

from PIL import Image, ImageDraw, ImageFont

BG = (246, 238, 228)
INK = (46, 40, 38)
MUTED = (112, 102, 96)
ACCENT = (185, 78, 89)
SAGE = (126, 156, 140)
CARD = (252, 247, 239)


def font(path, size):
    for p in (path, '/System/Library/Fonts/PingFang.ttc',
              '/System/Library/Fonts/HelveticaNeue.ttc',
              '/System/Library/Fonts/Supplemental/Arial.ttf'):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            continue
    return ImageFont.load_default()


F_CN = font('/System/Library/Fonts/PingFang.ttc', 46)
F_CN_S = font('/System/Library/Fonts/PingFang.ttc', 27)
F_EN = font('/System/Library/Fonts/HelveticaNeue.ttc', 24)
F_EN_S = font('/System/Library/Fonts/HelveticaNeue.ttc', 18)
F_LABEL = font('/System/Library/Fonts/PingFang.ttc', 24)


def load_json(path, default=None):
    try:
        return json.load(open(path, encoding='utf-8'))
    except Exception:
        return default or {}


def fit(img, size):
    return img.convert('RGB').resize(size, Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(prog='make_sheets.py')
    ap.add_argument('--dir', required=True)
    ap.add_argument('--compare', default=None,
                    help='T-029 renders dir (front/three_quarter)')
    ap.add_argument('--name', default=None)
    ap.add_argument('--title', default=None)
    ap.add_argument('--no-gif', action='store_true')
    args = ap.parse_args()
    root = os.path.abspath(args.dir)
    r = os.path.join(root, 'renders')
    manifest = load_json(os.path.join(root, 'manifest.json'))
    render = load_json(os.path.join(r, 'render.json'))
    name = args.name or manifest.get('id', 'character')
    title = args.title or manifest.get('character', name)
    palette = manifest.get('design', {}).get('palette', {})
    mesh = manifest.get('mesh', {})
    arm = manifest.get('armature', {})
    files = manifest.get('files', {})

    # ---- silhouette -------------------------------------------------------
    raw = Image.open(os.path.join(r, '_silhouette_raw.png')).convert('RGBA')
    alpha = raw.getchannel('A').point(lambda a: 255 if a > 127 else 0)
    sil = Image.new('RGB', raw.size, (255, 255, 255))
    sil.paste((0, 0, 0), (0, 0), alpha)
    sil.save(os.path.join(r, 'silhouette_front.png'), optimize=True)
    black = sum(1 for px in alpha.getdata() if px)
    coverage = black / (alpha.width * alpha.height)
    json.dump({'black_px': black, 'width': alpha.width, 'height': alpha.height,
               'coverage': round(coverage, 5)},
              open(os.path.join(r, 'silhouette_stats.json'), 'w'),
              indent=2)

    views = [('front', 'FRONT · 正面'), ('side', 'SIDE · 侧面'),
             ('back', 'BACK · 背面'),
             ('three_quarter', '3/4 · 四分之三')]
    cell = (720, 900)
    head = 150
    foot = 112
    sheet = Image.new('RGB', (cell[0] * 2, head + cell[1] * 2 + foot), BG)
    d = ImageDraw.Draw(sheet)
    d.text((48, 28), title, font=F_CN, fill=INK)
    subtitle = ('Original cute-anime toolkit sample · %s heads · %s tris · '
                '%s bones · %s · Blender %s' % (
                    manifest.get('proportions', {}).get('head_ratio', '?'),
                    mesh.get('tris', '?'), arm.get('bones', '?'),
                    manifest.get('route', 'blender-only'),
                    manifest.get('blender', {}).get('version', '?')))
    d.text((50, 88), subtitle, font=F_EN_S, fill=MUTED)
    d.line((48, head - 14, sheet.width - 48, head - 14), fill=ACCENT, width=2)
    for i, (key, label) in enumerate(views):
        p = os.path.join(r, key + '.png')
        if not os.path.exists(p):
            continue
        img = fit(Image.open(p), cell)
        x = (i % 2) * cell[0]
        y = head + (i // 2) * cell[1]
        sheet.paste(img, (x, y))
        box = d.textbbox((0, 0), label, font=F_LABEL)
        d.rounded_rectangle((x + 22, y + 22, x + 44 + box[2], y + 62),
                            radius=9, fill=(252, 247, 239))
        d.text((x + 32, y + 29), label, font=F_LABEL, fill=INK)
        d.line((x + cell[0] - 1, y, x + cell[0] - 1, y + cell[1]),
               fill=(227, 216, 203), width=2)
        d.line((x, y + cell[1] - 1, x + cell[0], y + cell[1] - 1),
               fill=(227, 216, 203), width=2)
    # footer palette + QA numbers
    fy = head + cell[1] * 2
    d.line((48, fy + 10, sheet.width - 48, fy + 10), fill=(221, 207, 191),
           width=1)
    d.text((48, fy + 24), 'PALETTE', font=F_EN_S, fill=MUTED)
    swatches = [('skin', palette.get('skin')), ('hair', palette.get('hair')),
                ('dress', palette.get('dress')),
                ('cream', palette.get('cream')),
                ('ribbon', palette.get('ribbon')),
                ('iris', palette.get('iris'))]
    x = 150
    for label, hexv in swatches:
        if not hexv:
            continue
        rgb = tuple(int(hexv.lstrip('#')[i:i + 2], 16) for i in (0, 2, 4))
        d.rounded_rectangle((x, fy + 18, x + 44, fy + 62), radius=8,
                            fill=rgb, outline=(200, 188, 176))
        d.text((x + 52, fy + 30), '%s %s' % (label, hexv), font=F_EN_S,
               fill=INK)
        x += 210
    qa = ('QA: non-manifold %s · UV %s · GLB %.2f MB · textures %s · '
          'silhouette %.2f%% · %s' % (
              mesh.get('non_manifold'), mesh.get('uv_layers'),
              files.get('glb_bytes', 0) / 1048576.0,
              len(manifest.get('textures', {})),
              coverage * 100, render.get('engine', 'EEVEE Legacy')))
    d.text((48, fy + 74), qa, font=F_EN_S, fill=MUTED)
    sheet.save(os.path.join(r, 'contact_sheet.png'), optimize=True)
    thumb = sheet.resize((sheet.width // 4, sheet.height // 4),
                         Image.LANCZOS)
    thumb.save(os.path.join(r, 'contact_sheet_25pct.png'), optimize=True)

    # ---- comparison vs the T-029 probe -----------------------------------
    if args.compare:
        cmp_dir = os.path.abspath(args.compare)
        old_mesh, old_arm = 103558, 22
        cmp_cell = (620, 775)
        cmp_head = 160
        cmp_foot = 112
        cmp_sheet = Image.new('RGB', (cmp_cell[0] * 2,
                                      cmp_head + cmp_cell[1] * 2 + cmp_foot),
                              BG)
        cd = ImageDraw.Draw(cmp_sheet)
        cd.text((44, 26), 'T-029 probe  →  T-031 v0.1 toolkit', font=F_CN,
                fill=INK)
        cd.text((46, 86),
                'Same 3/4 camera family; independent originals; no IP assets.',
                font=F_EN_S, fill=MUTED)
        cd.line((44, cmp_head - 14, cmp_sheet.width - 44, cmp_head - 14),
                fill=ACCENT, width=2)
        cols = [
            ('T-029 · Qinghe probe', cmp_dir, old_mesh, old_arm,
             'flat decal eyes · 22 bones · voxel body · 3 textures'),
            ('T-031 · Taoyao v0.1', r, mesh.get('tris', 0),
             arm.get('bones', 0),
             'eyeball+lid eyes · 50 bones · loft body · 4 textures'),
        ]
        for ci, (label, folder, tris, bones, note) in enumerate(cols):
            for ri, view in enumerate(('front', 'three_quarter')):
                p = os.path.join(folder, view + '.png')
                if not os.path.exists(p):
                    continue
                img = fit(Image.open(p), cmp_cell)
                x = ci * cmp_cell[0]
                y = cmp_head + ri * cmp_cell[1]
                cmp_sheet.paste(img, (x, y))
                cd.rounded_rectangle((x + 18, y + 18, x + 372, y + 58),
                                     radius=8, fill=(252, 247, 239))
                cd.text((x + 28, y + 25), '%s · %s' % (label, view),
                        font=F_LABEL, fill=INK)
                cd.line((x + cmp_cell[0] - 1, y, x + cmp_cell[0] - 1,
                         y + cmp_cell[1]), fill=(227, 216, 203), width=2)
                cd.line((x, y + cmp_cell[1] - 1, x + cmp_cell[0],
                         y + cmp_cell[1] - 1), fill=(227, 216, 203), width=2)
        footer_y = cmp_head + cmp_cell[1] * 2
        cd.line((44, footer_y + 8, cmp_sheet.width - 44, footer_y + 8),
                fill=(221, 207, 191), width=1)
        for ci, (label, _folder, tris, bones, note) in enumerate(cols):
            x = 44 + ci * (cmp_cell[0] + 20)
            cd.text((x, footer_y + 24), label, font=F_CN_S, fill=INK)
            cd.text((x, footer_y + 60),
                    '%s tris · %s bones · %s' % (tris, bones, note),
                    font=F_EN_S, fill=MUTED)
        cmp_sheet.save(os.path.join(r, 'compare_vs_T029.png'), optimize=True)
        print('COMPARE_OK', os.path.join(r, 'compare_vs_T029.png'))

    # ---- turntable GIF ----------------------------------------------------
    gif_path = os.path.join(r, 'turntable.gif')
    if not args.no_gif:
        tdir = os.path.join(r, 'turntable')
        frames = sorted(os.path.join(tdir, f) for f in os.listdir(tdir)
                        if f.endswith('.png')) if os.path.isdir(tdir) else []
        if frames:
            imgs = [fit(Image.open(p), (450, 562)) for p in frames]
            imgs[0].save(gif_path, save_all=True, append_images=imgs[1:],
                         duration=90, loop=0, optimize=True)
            print('GIF_OK', gif_path, len(imgs), 'frames')
    json.dump({'contact_sheet': 'renders/contact_sheet.png',
               'thumbnail': 'renders/contact_sheet_25pct.png',
               'silhouette': 'renders/silhouette_front.png',
               'coverage': round(coverage, 5),
               'compare': 'renders/compare_vs_T029.png'
               if args.compare else None,
               'gif': 'renders/turntable.gif'
               if os.path.exists(gif_path) else None},
              open(os.path.join(r, 'sheets.json'), 'w'), indent=2)
    print('SHEETS_OK contact=%s coverage=%.3f%% compare=%s' % (
        os.path.join(r, 'contact_sheet.png'), coverage * 100,
        bool(args.compare)))


if __name__ == '__main__':
    main()
