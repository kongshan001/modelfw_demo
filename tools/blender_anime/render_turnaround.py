"""Render front/side/back/3-4, face close-up, silhouette and turntable frames.

  /Applications/Blender.app/Contents/MacOS/Blender -b taoyao.blend \
    -P tools/blender_anime/render_turnaround.py -- \
    --out agent-probes/blender-anime-v01/renders --preview

Blender 3.4.1 / EEVEE Legacy.  4.2 EEVEE Next/Workbench is NOT used on this
machine (SIGSEGV in the draw manager).  Outputs PNG + renders/render.json.
"""

import argparse
import json
import math
import os
import sys
import time

import bpy
from mathutils import Vector


def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat(
        '-Z', 'Y').to_euler()


def parse_res(s):
    a, b = s.lower().split('x')
    return int(a), int(b)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ap = argparse.ArgumentParser(prog='render_turnaround.py')
    ap.add_argument('--blend', default=None,
                    help='blend path; omit if Blender was started with it')
    ap.add_argument('--out', required=True)
    ap.add_argument('--name', default='character')
    ap.add_argument('--res', default='1440x1800')
    ap.add_argument('--face-res', default='1440x1440')
    ap.add_argument('--samples', type=int, default=32)
    ap.add_argument('--turntable', type=int, default=8)
    ap.add_argument('--turntable-res', default='900x1125')
    ap.add_argument('--preview', action='store_true')
    ap.add_argument('--no-silhouette', action='store_true')
    args = ap.parse_args(argv)
    if args.blend:
        bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.blend))
    sc = bpy.context.scene
    cam = bpy.data.objects.get('Camera')
    if cam is None:
        raise SystemExit('RENDER_FAIL no Camera in blend')
    os.makedirs(args.out, exist_ok=True)
    if args.preview:
        args.samples = min(args.samples, 8)
        args.res = '720x900'
        args.face_res = '720x720'
        args.turntable_res = '540x675'
        if args.turntable == 8:
            args.turntable = 0
    sc.eevee.taa_render_samples = args.samples
    print('RENDER_ENGINE', sc.render.engine, 'samples', args.samples,
          'blender', bpy.app.version_string)

    char = next((o for o in sc.objects if o.get('role') == 'character'), None)
    target_z = 0.68
    if char:
        target_z = char.dimensions.z * 0.52
    target = (0.0, 0.0, target_z)
    total = 0.0
    shots = []

    def shot(name, loc, target, res, lens=70, transparent=False):
        nonlocal total
        cam.location = loc
        cam.data.lens = lens
        look_at(cam, target)
        sc.render.resolution_x, sc.render.resolution_y = res
        sc.render.resolution_percentage = 100
        sc.render.film_transparent = transparent
        sc.render.filepath = os.path.join(args.out, name + '.png')
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        dt = time.time() - t0
        total += dt
        shots.append(dict(name=name, seconds=round(dt, 2),
                          resolution=list(res), engine=sc.render.engine,
                          samples=args.samples))
        print('RENDER %s %.1fs %dx%d samples=%d engine=%s' % (
            name, dt, res[0], res[1], args.samples, sc.render.engine))
        return dt

    res = parse_res(args.res)
    face_res = parse_res(args.face_res)
    # camera views: +X side shows the profile without the ponytail blocking it
    shot('front', (0, -3.4, target_z + 0.08), target, res, 70)
    shot('side', (-3.4, 0, target_z + 0.08), target, res, 70)
    shot('back', (0, 3.4, target_z + 0.08), target, res, 70)
    shot('three_quarter', (-2.1, -2.7, target_z + 0.18), target, res, 70)
    shot('face_closeup', (-0.42, -1.02, target_z + 0.49),
         (0.0, 0.0, target_z + 0.46), face_res, 85)
    if args.turntable:
        tdir = os.path.join(args.out, 'turntable')
        os.makedirs(tdir, exist_ok=True)
        tres = parse_res(args.turntable_res)
        for i in range(args.turntable):
            a = -math.pi * 0.5 + TAU * i / args.turntable
            loc = (3.4 * math.cos(a), 3.4 * math.sin(a), target_z + 0.10)
            cam.location = loc
            cam.data.lens = 70
            look_at(cam, target)
            sc.render.resolution_x, sc.render.resolution_y = tres
            sc.render.film_transparent = False
            sc.render.filepath = os.path.join(tdir, 'frame_%03d.png' % i)
            t0 = time.time()
            bpy.ops.render.render(write_still=True)
            dt = time.time() - t0
            total += dt
            print('TURNTABLE frame %d %.1fs' % (i, dt))
    if not args.no_silhouette:
        hide = []
        for o in sc.objects:
            if o.get('role') == 'outline_shell' or o.name in (
                    'Cyclorama', 'Floor', 'StageRing', 'ContactShadow'):
                if not o.hide_render:
                    o.hide_render = True
                    hide.append(o)
        shot('_silhouette_raw', (0, -3.4, target_z + 0.08), target,
             (720, 900), 70, transparent=True)
        for o in hide:
            o.hide_render = False
        sc.render.film_transparent = False
    render_manifest = {
        'blender': bpy.app.version_string,
        'engine': sc.render.engine,
        'samples': args.samples,
        'resolution': list(res),
        'face_resolution': list(face_res),
        'total_seconds': round(total, 2),
        'shots': shots,
        'turntable_frames': args.turntable,
        'preview': args.preview,
    }
    with open(os.path.join(args.out, 'render.json'), 'w', encoding='utf-8') as f:
        json.dump(render_manifest, f, ensure_ascii=False, indent=2)
    print('RENDER_TOTAL %.1fs' % total)
    print('BLENDER_ANIME_RENDER_OK', args.out)


TAU = math.pi * 2.0

if __name__ == '__main__':
    main()
