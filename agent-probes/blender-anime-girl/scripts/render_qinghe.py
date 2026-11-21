"""Render Qinghe turnaround / close-up / silhouette plates.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_qinghe.py
  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_qinghe.py -- --preview

Blender 3.4.1 / EEVEE Legacy on this machine (4.2 EEVEE Next is not used).
Outputs: renders/{front,side,back,three_quarter,face_closeup}.png
         renders/_silhouette_raw.png (transparent alpha plate for make_sheets.py)
"""

import os
import sys
import time

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, 'qinghe.blend')
OUT = os.path.join(ROOT, 'renders')
os.makedirs(OUT, exist_ok=True)

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PREVIEW = '--preview' in ARGS

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
cam = bpy.data.objects['Camera']
if PREVIEW:
    sc.eevee.taa_render_samples = 8
else:
    sc.eevee.taa_render_samples = 32


def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat(
        '-Z', 'Y').to_euler()


def shot(name, loc, target, res=(1440, 1800), lens=70):
    cam.location = loc
    cam.data.lens = lens
    look_at(cam, target)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.filepath = os.path.join(OUT, name + '.png')
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    dt = time.time() - t0
    print('QINGHE_RENDER %s %.1fs %dx%d samples=%d engine=%s' % (
        name, dt, res[0], res[1], sc.eevee.taa_render_samples,
        sc.render.engine))
    return dt


if PREVIEW:
    shot('preview_front', (0, -3.4, 0.76), (0, 0, 0.68),
         res=(640, 800), lens=70)
    shot('preview_3q', (-2.1, -2.7, 0.88), (0, 0, 0.68),
         res=(640, 800), lens=70)
    shot('preview_face', (-0.45, -0.98, 1.23), (0, 0, 1.15),
         res=(720, 720), lens=85)
    shot('preview_side', (3.4, 0, 0.76), (0, 0, 0.68),
         res=(640, 800), lens=70)
    shot('preview_back', (0, 3.4, 0.76), (0, 0, 0.68),
         res=(640, 800), lens=70)
    sys.exit(0)

total = 0.0
total += shot('front', (0, -3.4, 0.76), (0, 0, 0.68))
total += shot('side', (3.4, 0, 0.76), (0, 0, 0.68))
total += shot('back', (0, 3.4, 0.76), (0, 0, 0.68))
total += shot('three_quarter', (-2.1, -2.7, 0.88), (0, 0, 0.68))
total += shot('face_closeup', (-0.45, -0.98, 1.23), (0, 0, 1.15),
              res=(1440, 1440), lens=85)

# alpha plate for the pure-black silhouette check
sc.render.film_transparent = True
for n in ('Qinghe_Outline', 'Cyclorama', 'Floor', 'stage_ring',
          'ContactShadow'):
    o = bpy.data.objects.get(n)
    if o:
        o.hide_render = True
shot('_silhouette_raw', (0, -3.4, 0.76), (0, 0, 0.68),
     res=(720, 900), lens=70)
print('QINGHE_RENDER_TOTAL %.1fs' % total)
