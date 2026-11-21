"""Re-import qinghe.glb into a clean scene and print a validation report.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/validate_glb.py
  /Applications/Blender-4.2.app/Contents/MacOS/Blender -b -P scripts/validate_glb.py
"""

import os

import bpy

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLB = os.path.join(ROOT, 'qinghe.glb')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

objs = list(bpy.context.scene.objects)
meshes = [o for o in objs if o.type == 'MESH']
arms = [o for o in objs if o.type == 'ARMATURE']
print('GLB_BLENDER_VERSION', bpy.app.version_string)
print('GLB_OBJECTS', [(o.name, o.type) for o in objs])
print('GLB_SIZE_BYTES', os.path.getsize(GLB))
for o in meshes:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    mats = [m.name if m else None for m in o.data.materials]
    uv = [l.name for l in o.data.uv_layers]
    groups = len(o.vertex_groups)
    arm_mods = [m.object.name for m in o.modifiers
                if m.type == 'ARMATURE' and m.object]
    print('GLB_MESH %s tris=%d verts=%d mats=%d uv=%s vgroups=%d '
          'armature=%s dims=%s' % (
              o.name, tris, len(o.data.vertices), len(mats), uv, groups,
              arm_mods, tuple(round(d, 3) for d in o.dimensions)))
for a in arms:
    print('GLB_ARMATURE %s bones=%d names=%s' % (
        a.name, len(a.data.bones), ','.join(b.name for b in a.data.bones)))
print('GLB_IMAGES', [(i.name, tuple(i.size), bool(i.packed_file))
                     for i in bpy.data.images if i.name != 'Render Result'])
print('GLB_ACTIONS', [a.name for a in bpy.data.actions])
print('GLB_VALIDATE_OK')
