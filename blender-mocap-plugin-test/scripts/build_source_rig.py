#!/usr/bin/env python3
"""Build a Mixamo-named source armature driven by MediaPipe joint targets.

Run with Blender 3.4.1 (headless):
  Blender -b --factory-startup -noaudio --python scripts/build_source_rig.py -- \
    --motion /tmp/mocap_work/motion.json --out /tmp/mocap_work/source_mediapipe.glb

The rig is a T-pose; per-frame empties are placed at the canonical joint
positions. Damped Track constraints aim each bone at the next joint; the
constrained pose is baked to an action named MediaPipeTake and exported as
GLB (armature only). animation-retarget-kit then bakes it to KayKit Rogue.
"""
import bpy
import json
import math
import os
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def arg(name, default=None):
    if name in argv:
        i = argv.index(name)
        if i + 1 < len(argv):
            return argv[i + 1]
    return default

motion_path = arg('--motion')
out_path = arg('--out')
max_frames = int(arg('--max-frames', '0'))
if not (motion_path and out_path):
    raise SystemExit('BUILD_ERROR: --motion and --out are required')

motion = json.load(open(motion_path))
frames = motion['frames']
if max_frames:
    frames = frames[:max_frames]
rest = motion['rest']
fps = motion['fps']
N = len(frames)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = int(round(fps))
scene.frame_start = 1
scene.frame_end = N

arm_data = bpy.data.armatures.new('MediaPipeSource')
arm_obj = bpy.data.objects.new('MediaPipeSource', arm_data)
bpy.context.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='EDIT')

H = rest['hip_h']
hips_len = rest['hips_len']
spine_len = rest['spine_len']
chest_len = rest['chest_len']
head_len = rest['head_len']
chest_z = rest['chest_z']
neck_z = rest['neck_z']
head_top_z = rest['head_top_z']
shoulder_x = max(0.12, rest['shoulder_x'])
hip_x = max(0.07, rest['hip_x'])
upperarm = rest['upperarm_len']
forearm = rest['forearm_len']
hand_len = rest.get('hand_len', 0.08)
thigh = rest['thigh_len']
shin = rest['shin_len']
foot_len = rest['foot_len']
toe_len = rest['toe_len']

def add(name, head, tail, parent=None, connect=False, roll_vec=(0, -1, 0)):
    b = arm_data.edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent:
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = connect
    b.align_roll(Vector(roll_vec))
    return b

# Torso chain (connected).
hips_tail_z = H + hips_len
spine_tail_z = hips_tail_z + spine_len
chest_tail_z = spine_tail_z + chest_len
head_tail_z = chest_tail_z + head_len
add('mixamorig:Hips', (0, 0, H), (0, 0, hips_tail_z), roll_vec=(0, -1, 0))
add('mixamorig:Spine', (0, 0, hips_tail_z), (0, 0, spine_tail_z), 'mixamorig:Hips', True)
add('mixamorig:Chest', (0, 0, spine_tail_z), (0, 0, chest_tail_z), 'mixamorig:Spine', True)
add('mixamorig:Head', (0, 0, chest_tail_z), (0, 0, head_tail_z), 'mixamorig:Chest', True)

arm_z = chest_z
for side, sx in (('Left', 1.0), ('Right', -1.0)):
    sh = (sx * shoulder_x, 0, arm_z)
    el = (sx * (shoulder_x + upperarm), 0, arm_z)
    wr = (sx * (shoulder_x + upperarm + forearm), 0, arm_z)
    hd = (sx * (shoulder_x + upperarm + forearm + hand_len), 0, arm_z)
    add(f'mixamorig:{side}Arm', sh, el, 'mixamorig:Chest', False, roll_vec=(0, 0, 1))
    add(f'mixamorig:{side}ForeArm', el, wr, f'mixamorig:{side}Arm', True, roll_vec=(0, 0, 1))
    add(f'mixamorig:{side}Hand', wr, hd, f'mixamorig:{side}ForeArm', True, roll_vec=(0, 0, 1))
    hp = (sx * hip_x, 0, H)
    kn = (sx * hip_x, 0, H - thigh)
    an = (sx * hip_x, 0, H - thigh - shin)
    ft = (sx * hip_x, -foot_len, max(0.0, an[2] - 0.02))
    toe = (sx * hip_x, -foot_len - toe_len, ft[2])
    add(f'mixamorig:{side}UpLeg', hp, kn, 'mixamorig:Hips', False, roll_vec=(0, -1, 0))
    add(f'mixamorig:{side}Leg', kn, an, f'mixamorig:{side}UpLeg', True, roll_vec=(0, -1, 0))
    add(f'mixamorig:{side}Foot', an, ft, f'mixamorig:{side}Leg', True, roll_vec=(0, 0, 1))
    add(f'mixamorig:{side}ToeBase', ft, toe, f'mixamorig:{side}Foot', True, roll_vec=(0, 0, 1))

bpy.ops.object.mode_set(mode='OBJECT')

# Joint empties (all joints from motion.json; only the used ones get constraints).
joint_names = list(frames[0]['joints'].keys())
empties = {}
for name in joint_names:
    e = bpy.data.objects.new('J_' + name, None)
    e.empty_display_type = 'PLAIN_AXES'
    e.empty_display_size = 0.03
    bpy.context.collection.objects.link(e)
    empties[name] = e
    for f, fr in enumerate(frames):
        e.location = Vector(fr['joints'][name])
        e.keyframe_insert('location', frame=f + 1)
    if e.animation_data and e.animation_data.action:
        for fc in e.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'LINEAR'

bpy.ops.object.mode_set(mode='POSE')
for pb in arm_obj.pose.bones:
    pb.rotation_mode = 'QUATERNION'

def damp(pb_name, target):
    pb = arm_obj.pose.bones[pb_name]
    c = pb.constraints.new('DAMPED_TRACK')
    c.target = empties[target]
    c.track_axis = 'TRACK_Y'
    return c

# Root: translation from hips empty; aim the pelvis up at the spine target.
pb = arm_obj.pose.bones['mixamorig:Hips']
cl = pb.constraints.new('COPY_LOCATION')
cl.target = empties['hips']
cl.target_space = 'WORLD'
cl.owner_space = 'WORLD'
damp('mixamorig:Hips', 'spine')
damp('mixamorig:Spine', 'chest')
damp('mixamorig:Chest', 'neck')
damp('mixamorig:Head', 'head_top')
for side in ('l', 'r'):
    s = 'Left' if side == 'l' else 'Right'
    damp(f'mixamorig:{s}Arm', f'{side}_elbow')
    damp(f'mixamorig:{s}ForeArm', f'{side}_wrist')
    damp(f'mixamorig:{s}Hand', f'{side}_hand')
    damp(f'mixamorig:{s}UpLeg', f'{side}_knee')
    damp(f'mixamorig:{s}Leg', f'{side}_ankle')
    damp(f'mixamorig:{s}Foot', f'{side}_foot')
    damp(f'mixamorig:{s}ToeBase', f'{side}_toe')

# Bake the constrained pose.
bpy.ops.pose.select_all(action='SELECT')
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.nla.bake(
    frame_start=1, frame_end=N, step=1, only_selected=True,
    visual_keying=True, clear_constraints=True, clear_parents=False,
    use_current_action=False, bake_types={'POSE'})

act = arm_obj.animation_data.action if arm_obj.animation_data else None
if act is None:
    raise SystemExit('BUILD_ERROR: bake produced no action')
act.name = 'MediaPipeTake'
act.use_fake_user = True
for fc in act.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'LINEAR'

# Remove empties (their animation is baked).
for e in empties.values():
    bpy.data.objects.remove(e, do_unlink=True)

# Export armature + baked action.
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=out_path, export_format='GLB', use_selection=True,
    export_animations=True, export_nla_strips=False, export_frame_range=True,
    export_yup=True, export_apply=False)

print('SOURCE_REPORT ' + json.dumps({
    'out': out_path,
    'bones': len(arm_obj.data.bones),
    'frames': [int(act.frame_range[0]), int(act.frame_range[1])],
    'fcurves': len(act.fcurves),
    'fps': int(round(fps)),
    'seconds': round(N / fps, 4),
    'rest_hip_h': round(H, 4),
}, ensure_ascii=False))
