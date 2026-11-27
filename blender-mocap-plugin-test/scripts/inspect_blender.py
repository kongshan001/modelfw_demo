#!/usr/bin/env python3
"""Inspect a retargeted GLB in Blender at 30 fps.

  Blender -b --factory-startup -noaudio --python scripts/inspect_blender.py -- \
    --glb exports/Rogue_MediaPipe_walk_raw.glb
"""
import bpy, json, sys
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
glb = argv[argv.index('--glb') + 1] if '--glb' in argv else None
if not glb:
    raise SystemExit('INSPECT_ERROR: --glb required')
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=glb)
arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
if arm is None:
    raise SystemExit('INSPECT_ERROR: no armature')
act = arm.animation_data.action if arm.animation_data else None
meshes = [o for o in bpy.data.objects if o.type == 'MESH']
verts = sum(len(o.data.vertices) for o in meshes)
start, end = (int(act.frame_range[0]), int(act.frame_range[1])) if act else (0, 0)
# Bone length deviation at 5 frames.
rest = {b.name: (b.tail_local - b.head_local).length for b in arm.data.bones}
worst = 0.0; worst_name = ''
for f in [start, start + (end - start) // 4, start + (end - start) // 2, start + 3 * (end - start) // 4, end]:
    bpy.context.scene.frame_set(f)
    bpy.context.view_layer.update()
    for b in arm.data.bones:
        pb = arm.pose.bones[b.name]
        tail = pb.matrix @ Vector((0, b.length, 0))
        length = (tail - pb.matrix.translation).length
        dev = abs(length - rest[b.name])
        if dev > worst:
            worst = dev; worst_name = b.name
print('BLENDER_INSPECT ' + json.dumps({
    'glb': glb, 'bones': len(arm.data.bones), 'meshes': len(meshes),
    'vertices': verts, 'action': act.name if act else None,
    'frames': [start, end], 'fps': 30,
    'seconds': round((end - start) / 30.0, 4) if act else 0,
    'max_bone_length_deviation': worst, 'worst_bone': worst_name,
}, ensure_ascii=False))
