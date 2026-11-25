"""Render the Qinghe blink test (face close-up stills, loop, target-size).

  Blender 3.4.1 / EEVEE Legacy:
    Blender -b -P tools/blender_blink/render_blink.py -- --mode preview
    Blender -b -P tools/blender_blink/render_blink.py -- --mode stills
    Blender -b -P tools/blender_blink/render_blink.py -- --mode anim
    Blender -b -P tools/blender_blink/render_blink.py -- --mode target

Modes
-----
preview : 640x640 open/half/closed, 8 samples       (~6 s each)
stills  : 1024x1024 open/half/closed + 3/4 states, 32 samples
anim    : 1..168 @ 24 fps, 512x512, 16 samples      (face close-up)
target  : 1..168 @ 24 fps, 360x450, 12 samples      (full body for 180 px test)

Stills are rendered with the shape-key action unassigned so weights can be
set manually; the animation modes restore it.
"""

import json
import os
import sys
import time

import bpy
from mathutils import Vector

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
sys.path.insert(0, TOOLS)
import blink_schedule  # noqa: E402

OUT_DIR = os.path.join(REPO, 'agent-probes', 'blink-test')
BLEND = os.path.join(OUT_DIR, 'qinghe_blink.blend')
RENDERS = os.path.join(OUT_DIR, 'renders')
ANIM = os.path.join(OUT_DIR, 'anim')
TARGET = os.path.join(OUT_DIR, 'target_size')
os.makedirs(RENDERS, exist_ok=True)
os.makedirs(ANIM, exist_ok=True)
os.makedirs(TARGET, exist_ok=True)

ARGS = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []


def arg(name, default=None):
    if name in ARGS:
        i = ARGS.index(name)
        return ARGS[i + 1] if i + 1 < len(ARGS) else True
    return default


MODE = arg('--mode', 'preview')
SKIP_EXISTING = '--skip-existing' in ARGS
ONLY = arg('--only')  # optional comma list: open,half,closed

bpy.ops.wm.open_mainfile(filepath=BLEND)
sc = bpy.context.scene
cam = bpy.data.objects['Camera']
lids = bpy.data.objects['Qinghe_BlinkLids']
sk = lids.data.shape_keys


def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat(
        '-Z', 'Y').to_euler()


def face_cam(frontal=True):
    if frontal:
        loc, tgt, lens = (0.0, -0.86, 1.155), (0.0, 0.0, 1.148), 85
    else:
        loc, tgt, lens = (-0.45, -0.98, 1.23), (0.0, 0.0, 1.15), 85
    cam.location = loc
    cam.data.lens = lens
    look_at(cam, tgt)
    sc.camera = cam


def set_state(state):
    """state: open | half | closed (both eyes); action must be unassigned."""
    vals = {'Blink_Open': 0.0, 'Blink_Half': 0.0, 'Blink_Closed': 0.0,
            'Blink_Left_Half': 0.0, 'Blink_Left_Closed': 0.0,
            'Blink_Right_Half': 0.0, 'Blink_Right_Closed': 0.0}
    if state == 'half':
        vals['Blink_Half'] = 1.0
    elif state == 'closed':
        vals['Blink_Closed'] = 1.0
    for k, v in vals.items():
        sk.key_blocks[k].value = v
    bpy.context.view_layer.update()


def render(path, res, samples=16):
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.eevee.taa_render_samples = samples
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = path
    t0 = time.time()
    bpy.ops.render.render(write_still=True)
    dt = time.time() - t0
    print('BLINK_RENDER %s %.1fs %dx%d samples=%d' % (
        os.path.basename(path), dt, res[0], res[1], samples))
    return dt


def unassign_action():
    if sk.animation_data:
        sk.animation_data.action = None


def assign_action():
    act = bpy.data.actions.get('Blink_Loop_24fps')
    if sk.animation_data is None:
        sk.animation_data_create()
    sk.animation_data.action = act


if MODE == 'preview':
    unassign_action()
    face_cam(True)
    for state in ('open', 'half', 'closed'):
        if ONLY and state not in ONLY.split(','):
            continue
        set_state(state)
        render(os.path.join(RENDERS, 'preview_face_%s.png' % state),
               (640, 640), 8)

elif MODE == 'stills':
    unassign_action()
    for view, frontal in (('front', True), ('threeq', False)):
        face_cam(frontal)
        for state in ('open', 'half', 'closed'):
            if ONLY and state not in ONLY.split(','):
                continue
            set_state(state)
            render(os.path.join(RENDERS, 'face_%s_%s.png' % (view, state)),
                   (1024, 1024), 32)

elif MODE in ('anim', 'target'):
    assign_action()
    sc.frame_start, sc.frame_end = 1, blink_schedule.FRAMES
    sc.render.fps = 24
    if MODE == 'anim':
        face_cam(True)
        res, samples = (512, 512), 16
        outdir = ANIM
    else:
        # same frontal full-body framing as the original turnaround
        cam.location = (0.0, -3.4, 0.76)
        cam.data.lens = 70
        look_at(cam, (0, 0, 0.68))
        sc.camera = cam
        res, samples = (360, 450), 12
        outdir = TARGET
    t_all = 0.0
    for f in range(1, blink_schedule.FRAMES + 1):
        path = os.path.join(outdir, 'f%04d.png' % f)
        if SKIP_EXISTING and os.path.exists(path):
            continue
        sc.frame_set(f)
        t_all += render(path, res, samples)
    print('BLINK_RENDER_TOTAL %.1fs' % t_all)
    with open(os.path.join(outdir, 'meta.json'), 'w') as fh:
        json.dump({'fps': 24, 'frames': blink_schedule.FRAMES,
                   'res': res, 'mode': MODE,
                   'blinks': [(b['start'], b['end']) for b in
                              blink_schedule.generate_schedule(
                                  blink_schedule.find_seed()[0])['blinks']]},
                  fh, indent=2)
else:
    raise SystemExit('unknown mode %s' % MODE)
