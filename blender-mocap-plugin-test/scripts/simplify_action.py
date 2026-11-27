#!/usr/bin/env python3
"""Reduce keyframes in the retargeted GLB with a per-channel RDP pass.

Run with Blender 3.4.1:
  Blender -b --factory-startup -noaudio --python scripts/simplify_action.py -- \
    --input exports/Rogue_MediaPipe_walk_raw.glb \
    --out exports/Rogue_MediaPipe_walk_simplified.glb --epsilon 0.002

This is the local analogue of the plugin's "精简动画" button. It keeps the
first/last keys and drops interior keys whose linear interpolation stays
within epsilon of the original value. The GLB still contains the character,
skin and one animation; no source video or model weights are involved.
"""
import bpy
import json
import math
import os
import sys

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def arg(name, default=None):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default

inp = arg('--input')
out = arg('--out')
eps = float(arg('--epsilon', '0.002'))
if not (inp and out):
    raise SystemExit('SIMPLIFY_ERROR: --input and --out are required')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=inp)
arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if arm is None or arm.animation_data is None or arm.animation_data.action is None:
    raise SystemExit('SIMPLIFY_ERROR: no armature action')
act = arm.animation_data.action

# Keep only the armature action (the glTF importer may add per-object actions).
for a in list(bpy.data.actions):
    if a != act:
        try:
            bpy.data.actions.remove(a)
        except Exception:
            pass
act.name = 'Animation'

def rdp(points, eps):
    if len(points) <= 2:
        return points
    first = points[0]
    last = points[-1]
    # Perpendicular distance to the chord in (frame, value) space.
    dx = last[0] - first[0]
    dy = last[1] - first[1]
    denom = math.hypot(dx, dy)
    best_d = -1.0
    best_i = -1
    for i in range(1, len(points) - 1):
        x, y = points[i]
        if denom < 1e-12:
            d = math.hypot(x - first[0], y - first[1])
        else:
            d = abs(dy * (x - first[0]) - dx * (y - first[1])) / denom
        if d > best_d:
            best_d = d
            best_i = i
    if best_d > eps:
        left = rdp(points[:best_i + 1], eps)
        right = rdp(points[best_i:], eps)
        return left[:-1] + right
    return [first, last]

orig_keys = 0
new_keys = 0
max_err = 0.0
worst = ''
for fc in act.fcurves:
    pts = [(kp.co[0], kp.co[1]) for kp in fc.keyframe_points]
    if len(pts) < 3:
        continue
    orig_keys += len(pts)
    # Store original sampled values at integer frames before editing.
    f0 = int(round(pts[0][0])); f1 = int(round(pts[-1][0]))
    samples = {f: fc.evaluate(f) for f in range(f0, f1 + 1)}
    keep = rdp(pts, eps)
    for kp in reversed(list(fc.keyframe_points)):
        fc.keyframe_points.remove(kp)
    for x, y in keep:
        kp = fc.keyframe_points.insert(x, y, options={'FAST'})
        kp.interpolation = 'LINEAR'
    fc.update()
    new_keys += len(keep)
    for f, v in samples.items():
        e = abs(fc.evaluate(f) - v)
        if e > max_err:
            max_err = e
            worst = fc.data_path + '[' + str(fc.array_index) + ']'

# Export all imported objects (character, meshes, armature) with the reduced action.
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = arm
os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out, export_format='GLB', use_selection=True,
    export_animations=True, export_nla_strips=False, export_frame_range=True,
    export_force_sampling=False, export_optimize_animation_size=True,
    export_yup=True, export_apply=False)

print('SIMPLIFY_REPORT ' + json.dumps({
    'input': inp, 'output': out, 'epsilon': eps,
    'frames': [int(act.frame_range[0]), int(act.frame_range[1])],
    'orig_keys': orig_keys, 'new_keys': new_keys,
    'reduction_pct': round(100.0 * (1.0 - new_keys / max(1, orig_keys)), 2),
    'max_channel_error': max_err, 'worst_channel': worst,
}, ensure_ascii=False))
