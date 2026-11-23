"""Check original reference images before feeding Tripo.

  python3 tools/tripo/refs_check.py --front refs/front.png \
    --side refs/side.png --back refs/back.png \
    --origin original --out refs/refs_report.json

No image content is sent anywhere.  Originality is a human/team assertion;
this tool only records it and checks technical suitability.
"""

import argparse
import json
import os

from PIL import Image, ImageStat


def check_one(path):
    out = {'path': os.path.abspath(path), 'exists': os.path.exists(path)}
    if not out['exists']:
        out['ok'] = False
        out['error'] = 'missing'
        return out
    size = os.path.getsize(path)
    out['bytes'] = size
    out['ok'] = 64 < size <= 20 * 1024 * 1024
    try:
        with Image.open(path) as im:
            out['width'], out['height'] = im.size
            out['mode'] = im.mode
            out['format'] = im.format
            out['aspect'] = round(im.width / max(1, im.height), 3)
            if min(im.size) < 512:
                out['warning'] = 'min side < 512px; Tripo prefers 1024+'
            if im.mode in ('RGBA', 'LA'):
                alpha = im.getchannel('A')
                hist = alpha.histogram()
                transparent = sum(hist[:16]) / max(1, im.width * im.height)
                out['transparent_fraction'] = round(transparent, 3)
            rgb = im.convert('L')
            border = 8
            strips = [rgb.crop((0, 0, im.width, border)),
                      rgb.crop((0, im.height - border, im.width, im.height)),
                      rgb.crop((0, 0, border, im.height)),
                      rgb.crop((im.width - border, 0, im.width, im.height))]
            stds = [ImageStat.Stat(s).stddev[0] for s in strips]
            out['border_stddev'] = round(sum(stds) / len(stds), 2)
            if out['border_stddev'] > 22:
                out['warning_border'] = ('background is busy; use a clean '
                                         'solid/transparent background')
    except Exception as e:
        out['ok'] = False
        out['error'] = str(e)
    return out


def main():
    ap = argparse.ArgumentParser(prog='refs_check.py')
    ap.add_argument('--front', required=True)
    ap.add_argument('--side', default=None)
    ap.add_argument('--back', default=None)
    ap.add_argument('--origin', default='original',
                    help='original | licensed; must be truthful')
    ap.add_argument('--source-note', default='')
    ap.add_argument('--out', default=None)
    args = ap.parse_args()
    refs = {}
    for name in ('front', 'side', 'back'):
        p = getattr(args, name)
        if p:
            refs[name] = check_one(p)
    ok = all(v.get('ok') for v in refs.values()) and bool(refs)
    report = {'origin': args.origin, 'source_note': args.source_note,
              'views': refs, 'ok': ok,
              'note': 'Tripo input must be original or licensed; never use '
                      'a reference game/IP image.'}
    if args.out:
        os.makedirs(os.path.dirname(os.path.abspath(args.out)),
                    exist_ok=True)
        with open(args.out, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    print('REFS_OK' if ok else 'REFS_FAIL', json.dumps(
        {k: v.get('width') and [v['width'], v['height']] or v.get('error')
         for k, v in refs.items()}))
    for k, v in refs.items():
        for wk in ('warning', 'warning_border'):
            if wk in v:
                print('REFS_WARN', k, v[wk])
    return 0 if ok else 1


if __name__ == '__main__':
    raise SystemExit(main())
