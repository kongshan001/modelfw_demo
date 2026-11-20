"""Bake the IK-driven animation and export a game-ready GLB.

Run after build_wukong.py:
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/export_glb.py

The .blend keeps the IK rig; the GLB gets a per-frame baked pose (no constraints).
"""

import bpy
import json
import os
import struct

ROOT = "/Users/ks_128/Documents/modelfw_demo/blender-wukong"


def read_glb_json(path):
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<4sII', f.read(12))
        assert magic == b'glTF', magic
        chunk_len, chunk_type = struct.unpack('<II', f.read(8))
        data = f.read(chunk_len)
    return json.loads(data.decode('utf-8'))


def main():
    bpy.ops.wm.open_mainfile(filepath=ROOT + '/wukong.blend')
    scene = bpy.context.scene
    arm = bpy.data.objects['WukongRig']
    body = bpy.data.objects['Wukong_Body']

    # Bake the IK/pose animation to plain bone keyframes.
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.nla.bake(
        frame_start=1, frame_end=scene.frame_end, step=1,
        only_selected=True, visual_keying=True, clear_constraints=True,
        clear_parents=False, use_current_action=True, bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')

    # Export only the character + rig.
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm
    out = ROOT + '/wukong.glb'
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', use_selection=True,
        export_animations=True, export_frame_range=True,
        export_force_sampling=True, export_skins=True, export_yup=True,
        export_apply=False, export_cameras=False, export_lights=False)

    doc = read_glb_json(out)
    print('GLB_OK', out, os.path.getsize(out),
          'skins', len(doc.get('skins', [])),
          'animations', len(doc.get('animations', [])),
          'meshes', len(doc.get('meshes', [])),
          'nodes', len(doc.get('nodes', [])))


if __name__ == '__main__':
    main()
