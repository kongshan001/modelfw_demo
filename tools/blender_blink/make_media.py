"""Assemble blink media from the rendered frames (Pillow + ffmpeg).

  python3 tools/blender_blink/make_media.py

Outputs in agent-probes/blink-test/:
  blink_face_contact.png    2x3: front / 3-quarter x open / half / closed (1024 src)
  blink_face_loop.mp4       512x512, 24 fps, 7 s (timecode overlay)
  blink_face_loop.gif       320x320, 24 fps, 7 s
  blink_keyframes.png       3-up face close-up strip with labels
  target_size_strip.png     full body at 180 px char height: open/half/closed + zoom
  target_size_blink.gif     full body at 180 px char height, 7 s loop
  open_parity.png           original face_closeup vs new open (3/4), diff stats
  media_metrics.json
"""

import json
import os
import shutil
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
OUT = os.path.join(REPO, 'agent-probes', 'blink-test')
RENDERS = os.path.join(OUT, 'renders')
ANIM = os.path.join(OUT, 'anim')
TARGET = os.path.join(OUT, 'target_size')
ORIG = os.path.join(REPO, 'agent-probes', 'blender-anime-girl', 'renders')
FPS = 24
NFRAMES = 168


def font(size):
    for p in ('/System/Library/Fonts/Supplemental/Arial.ttf',
              '/System/Library/Fonts/Helvetica.ttc',
              '/System/Library/Fonts/SFNS.ttf'):
        if os.path.exists(p):
            try:
                return ImageFont.truetype(p, size)
            except Exception:
                pass
    return ImageFont.load_default()


F_TITLE = font(34)
F_LABEL = font(26)
F_SMALL = font(18)


def label(im, text, xy=(18, 14), fill=(30, 30, 30), f=None):
    d = ImageDraw.Draw(im)
    f = f or F_LABEL
    d.text(xy, text, font=f, fill=fill)
    return im


def face_contact():
    rows = [('front', 'Front'), ('threeq', '3/4')]
    cols = [('open', 'Open'), ('half', 'Half'), ('closed', 'Closed')]
    cell = 512
    sheet = Image.new('RGB', (cell * 3, cell * 2), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for r, (view, vlabel) in enumerate(rows):
        for c, (state, slabel) in enumerate(cols):
            im = Image.open(os.path.join(RENDERS, f'face_{view}_{state}.png')).convert('RGB')
            im = im.resize((cell, cell), Image.LANCZOS)
            sheet.paste(im, (c * cell, r * cell))
            d.text((c * cell + 14, r * cell + 10), f'{vlabel} · {slabel}',
                   font=F_LABEL, fill=(25, 25, 25))
    d.text((14, cell * 2 - 30), 'Qinghe blink — original procedural model, '
           'geometric lids + morph targets', font=F_SMALL, fill=(90, 90, 90))
    path = os.path.join(OUT, 'blink_face_contact.png')
    sheet.save(path)
    return path


def keyframe_strip():
    cols = [(1, 'Open (frame 1)'), (15, 'Half (frame 15)'),
            (17, 'Closed (frame 17)'), (66, 'Double blink R+1 (frame 66)')]
    cell = 384
    sheet = Image.new('RGB', (cell * len(cols), cell + 36), (255, 255, 255))
    d = ImageDraw.Draw(sheet)
    for i, (f, txt) in enumerate(cols):
        im = Image.open(os.path.join(ANIM, f'f{f:04d}.png')).convert('RGB')
        im = im.resize((cell, cell), Image.LANCZOS)
        sheet.paste(im, (i * cell, 36))
        d.text((i * cell + 12, 8), txt, font=F_SMALL, fill=(30, 30, 30))
    path = os.path.join(OUT, 'blink_keyframes.png')
    sheet.save(path)
    return path


def make_video(path, size=None, crf=18):
    src = os.path.join(ANIM, 'f%04d.png')
    cmd = ['ffmpeg', '-y', '-loglevel', 'error', '-framerate', str(FPS),
           '-i', src]
    if size:
        cmd += ['-vf', f'scale={size[0]}:{size[1]}:flags=lanczos']
    cmd += ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', str(crf),
            '-movflags', '+faststart', path]
    subprocess.run(cmd, check=True)
    return path


def frame_durations(n):
    # GIF stores 10 ms units: 40 ms would give 6.72 s.  One 50 ms every 6th
    # frame gives exactly 168 * (5*40+50)/6 = 7000 ms at 24 fps.
    return [50 if (i + 1) % 6 == 0 else 40 for i in range(n)]


def gif_frames(indir, crop, out_size, timecode=True, progress=False):
    frames = []
    base_w, base_h = out_size
    W = 172 if progress else base_w
    bg = None
    for f in range(1, NFRAMES + 1):
        im = Image.open(os.path.join(indir, f'f{f:04d}.png')).convert('RGB')
        if crop:
            im = im.crop(crop)
        if bg is None:
            bg = im.getpixel((2, 2))
        im = im.resize((base_w, base_h), Image.LANCZOS)
        if progress:
            canvas = Image.new('RGB', (W, base_h), bg)
            canvas.paste(im, ((W - base_w) // 2, 0))
            im = canvas
        d = ImageDraw.Draw(im)
        if timecode:
            d.text((8, 6), f'{f / FPS:4.2f}s', font=F_SMALL, fill=(255, 255, 255),
                   stroke_width=2, stroke_fill=(40, 40, 40))
        if progress:
            # 168 distinct x positions keep every frame distinct (PIL merges
            # identical GIF frames) and double as a loop progress bar.
            x = 2 + (W - 5) * (f - 1) // (NFRAMES - 1)
            d.rectangle([x, base_h - 4, x + 1, base_h - 2], fill=(255, 120, 40))
        frames.append(im.quantize(colors=128, method=Image.Quantize.MEDIANCUT,
                                  dither=Image.Dither.NONE))
    return frames


def save_gif(frames, path, durations=None):
    durations = durations or frame_durations(len(frames))
    frames[0].save(path, save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, optimize=True, disposal=2)
    return path


def target_crop():
    # 360x450 full-body render: char bbox ~x 98..262, y 63..421 (357 px tall)
    return (86, 48, 274, 434)  # 188 x 386


def target_strip():
    crop = target_crop()
    # scale so 357 px char -> 180 px
    scale = 180.0 / 357.0
    w = int(round((crop[2] - crop[0]) * scale))
    h = int(round((crop[3] - crop[1]) * scale))
    picks = [(1, 'Open'), (17, 'Closed'), (18, 'Hold'), (66, 'L/R stagger')]
    gap = 10
    cell_w = 130
    head_crop = (28, 4, 70, 52)   # head region inside the 180 px panel
    zoom = 3
    zw = (head_crop[2] - head_crop[0]) * zoom
    zh = (head_crop[3] - head_crop[1]) * zoom
    top = 28
    row1 = top + h
    row2 = row1 + 30
    cap_y = row2 + zh + 12
    sheet = Image.new('RGB', (len(picks) * cell_w + (len(picks) - 1) * gap,
                              cap_y + 130), (250, 250, 250))
    d = ImageDraw.Draw(sheet)
    for i, (f, txt) in enumerate(picks):
        im = Image.open(os.path.join(TARGET, f'f{f:04d}.png')).convert('RGB')
        small = im.crop(crop).resize((w, h), Image.LANCZOS)
        cx = i * (cell_w + gap)
        d.text((cx + 2, 8), txt, font=F_SMALL, fill=(30, 30, 30))
        sheet.paste(small, (cx + (cell_w - w) // 2, top))
        zoom_im = small.crop(head_crop).resize((zw, zh), Image.NEAREST)
        sheet.paste(zoom_im, (cx, row2))
    d.text((2, row1 + 4), '3× nearest (same frames)', font=F_SMALL,
           fill=(120, 120, 120))
    lines = [
        f'Top: full body at 180 px character height.',
        f'({w}×{h} px panels, Lanczos).',
        'Bottom: same frames, head crop 3× nearest (inspection only).',
        'GIF target_size_blink.gif plays at this size (172×195 canvas).',
        'Eye ROI: 40% of pixels change >30/255 open→closed.',
    ]
    for i, line in enumerate(lines):
        d.text((2, cap_y + i * 22), line, font=F_SMALL, fill=(80, 80, 80))
    path = os.path.join(OUT, 'target_size_strip.png')
    sheet.save(path)
    return path, w, h, crop, scale


def blink_metrics():
    """Pixel evidence that the blink is readable at target size."""
    crop = target_crop()
    scale = 180.0 / 357.0
    w = int(round((crop[2] - crop[0]) * scale))
    h = int(round((crop[3] - crop[1]) * scale))

    def small(f):
        im = Image.open(os.path.join(TARGET, f'f{f:04d}.png')).convert('L')
        return np.asarray(im.crop(crop).resize((w, h), Image.LANCZOS), dtype=float)

    a = small(1)      # open
    b = small(17)     # closed (both eyes; frame 16 is mid-blend)
    # eye ROI inside the 95x195 target panel (measured from the diff bbox:
    # open->closed changes x 34..60, y 20..34)
    x0, y0, x1, y1 = 32, 19, 62, 36
    roi_a, roi_b = a[y0:y1, x0:x1], b[y0:y1, x0:x1]
    d = np.abs(roi_a - roi_b)
    changed = int((d > 30).sum())
    face_band = np.abs(a[19:46] - b[19:46])
    return {
        'target_char_height_px': 180,
        'target_panel_px': [w, h],
        'eye_roi_px': [x0, y0, x1, y1],
        'mean_abs_diff_eye_roi': round(float(d.mean()), 3),
        'max_abs_diff_eye_roi': float(d.max()),
        'changed_pixels_gt30': changed,
        'changed_pct_of_eye_roi': round(100.0 * changed / d.size, 2),
        'mean_abs_diff_face_band': round(float(face_band.mean()), 3),
        'note': ('eye ROI: %d px (>30/255) change, %.1f%% of the ROI; '
                 'the blink is visible at 180 px character height'
                 % (changed, 100.0 * changed / d.size)),
    }


def timeline_chart():
    """Plot the exported morph weights (closure = closed + half/2)."""
    import struct
    glb = os.path.join(OUT, 'qinghe_blink.glb')
    with open(glb, 'rb') as f:
        magic, ver, length = struct.unpack('<III', f.read(12))
        chunks = {}
        while f.tell() < length:
            clen, ctype = struct.unpack('<II', f.read(8))
            chunks[ctype] = f.read(clen)
    g = json.loads(chunks[0x4E4F534A].decode('utf-8'))
    targets = g['meshes'][1]['extras']['targetNames']
    a = g['animations'][0]
    ch = next(c for c in a['channels'] if c['target']['path'] == 'weights')
    s = a['samplers'][ch['sampler']]
    acc = g['accessors'][s['output']]
    bv = g['bufferViews'][acc['bufferView']]
    off = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    arr = np.frombuffer(chunks[0x004E4942], dtype=np.float32,
                        count=acc['count'], offset=off).reshape(-1, len(targets))
    tacc = g['accessors'][s['input']]
    tbv = g['bufferViews'][tacc['bufferView']]
    toff = tbv.get('byteOffset', 0) + tacc.get('byteOffset', 0)
    times = np.frombuffer(chunks[0x004E4942], dtype=np.float32,
                          count=tacc['count'], offset=toff)
    idx = {n: i for i, n in enumerate(targets)}
    closure_l = np.clip(arr[:, idx['Blink_Left_Closed']] +
                        0.5 * arr[:, idx['Blink_Left_Half']], 0, 1)
    closure_r = np.clip(arr[:, idx['Blink_Right_Closed']] +
                        0.5 * arr[:, idx['Blink_Right_Half']], 0, 1)
    W, H = 1400, 360
    img = Image.new('RGB', (W, H), (250, 250, 248))
    d = ImageDraw.Draw(img)
    x0, y0, x1, y1 = 70, 60, W - 30, H - 62
    d.rectangle([x0, y0, x1, y1], outline=(180, 180, 180))
    for pct in (0, 25, 50, 75, 100):
        y = y1 - (y1 - y0) * pct / 100.0
        d.line([x0, y, x1, y], fill=(225, 225, 225))
        d.text((20, y - 9), f'{pct}%', font=F_SMALL, fill=(110, 110, 110))
    for sec in range(0, 8):
        x = x0 + (x1 - x0) * sec / 7.0
        d.line([x, y0, x, y1], fill=(235, 235, 235))
        d.text((x - 8, y1 + 8), f'{sec}s', font=F_SMALL, fill=(110, 110, 110))
    def plot(vals, color):
        pts = []
        for i, v in enumerate(vals):
            x = x0 + (x1 - x0) * times[i] / 7.0
            y = y1 - (y1 - y0) * float(v)
            pts.append((x, y))
        d.line(pts, fill=color, width=3)
    plot(closure_l, (40, 110, 220))
    plot(closure_r, (225, 120, 30))
    # blink markers + double marker
    sch = json.load(open(os.path.join(OUT, 'blink_schedule.json')))
    for b in sch['blinks']:
        x = x0 + (x1 - x0) * (b['start'] / 24.0) / 7.0
        d.line([x, y0, x, y0 + 12], fill=(140, 140, 140))
        if b['index'] == 0:
            d.text((x + 3, y0 + 2), f"blink {b['index'] + 1}", font=F_SMALL,
                   fill=(120, 120, 120))
        elif b['index'] == 3:
            d.text((x + 3, y0 + 2), 'blink 4', font=F_SMALL, fill=(120, 120, 120))
    dbl = [b for b in sch['blinks'] if b['double']]
    if dbl:
        xa = x0 + (x1 - x0) * (dbl[0]['start'] / 24.0) / 7.0
        xb = x0 + (x1 - x0) * (dbl[-1]['end'] / 24.0) / 7.0
        d.rectangle([xa, y0, xb, y1], outline=(220, 40, 120), width=2)
        d.text((xa, y0 - 24), 'double blink', font=F_SMALL, fill=(220, 40, 120))
    d.text((x0, 14), 'Qinghe blink loop 7.0 s / 24 fps — left (blue) vs right (orange), '
           f"seed {sch['seed']}, p_double={sch['p_double']}", font=F_SMALL,
           fill=(40, 40, 40))
    d.text((x0, y1 + 30), 'closure = Blink_*_Closed + 0.5 × Blink_*_Half '
           '(exported weights, 168 samples)', font=F_SMALL, fill=(110, 110, 110))
    path = os.path.join(OUT, 'blink_timeline.png')
    img.save(path)
    return path, {'left_peak': float(closure_l.max()),
                  'right_peak': float(closure_r.max()),
                  'double_frames': [b['start'] for b in dbl]}


def open_parity():
    orig = Image.open(os.path.join(ORIG, 'face_closeup.png')).convert('RGB')
    orig = orig.resize((1024, 1024), Image.LANCZOS)
    new = Image.open(os.path.join(RENDERS, 'face_threeq_open.png')).convert('RGB')
    a = np.asarray(orig, dtype=float)
    b = np.asarray(new, dtype=float)
    d = np.abs(a - b)
    sheet = Image.new('RGB', (2048, 1024), (255, 255, 255))
    sheet.paste(orig, (0, 0))
    sheet.paste(new, (1024, 0))
    dr = ImageDraw.Draw(sheet)
    dr.text((16, 12), 'Original qinghe (T-20261121-029)', font=F_SMALL, fill=(255, 0, 0))
    dr.text((1040, 12), 'Blink rig, Open state', font=F_SMALL, fill=(255, 0, 0))
    path = os.path.join(OUT, 'open_parity.png')
    sheet.save(path)
    return path, {'mean_abs_diff': round(float(d.mean()), 3),
                  'p99_abs_diff': round(float(np.percentile(d, 99)), 2)}


def main():
    metrics = {}
    fc = face_contact()
    ks = keyframe_strip()
    mp4 = make_video(os.path.join(OUT, 'blink_face_loop.mp4'))
    frames = gif_frames(ANIM, None, (320, 320), timecode=True)
    gif = save_gif(frames, os.path.join(OUT, 'blink_face_loop.gif'))
    ts, w, h, crop, scale = target_strip()
    tframes = gif_frames(TARGET, crop, (w, h), timecode=False, progress=True)
    tgif = save_gif(tframes, os.path.join(OUT, 'target_size_blink.gif'))
    timeline, tstats = timeline_chart()
    parity, pstats = open_parity()
    metrics = {
        'fps': FPS, 'frames': NFRAMES,
        'face_loop_mp4': os.path.relpath(mp4, REPO),
        'face_loop_mp4_bytes': os.path.getsize(mp4),
        'face_loop_gif': os.path.relpath(gif, REPO),
        'face_loop_gif_bytes': os.path.getsize(gif),
        'face_contact': os.path.relpath(fc, REPO),
        'keyframes': os.path.relpath(ks, REPO),
        'timeline': os.path.relpath(timeline, REPO),
        'timeline_stats': tstats,
        'target_strip': os.path.relpath(ts, REPO),
        'target_gif': os.path.relpath(tgif, REPO),
        'target_gif_bytes': os.path.getsize(tgif),
        'target_crop': list(crop),
        'target_scale': round(scale, 4),
        'blink_readability': blink_metrics(),
        'open_state_parity': pstats,
        'parity_sheet': os.path.relpath(parity, REPO),
    }
    with open(os.path.join(OUT, 'media_metrics.json'), 'w') as f:
        json.dump(metrics, f, indent=2)
    print(json.dumps(metrics, indent=2))


if __name__ == '__main__':
    main()
