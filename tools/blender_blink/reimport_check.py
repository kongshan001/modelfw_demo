"""Re-import the exported GLB in Blender and prove the morphs still drive.

  /Applications/Blender.app/Contents/MacOS/Blender -b \
    -P tools/blender_blink/reimport_check.py

Writes agent-probes/blink-test/reimport_check.json
"""

import json
import os

import bpy

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
GLB = os.path.join(REPO, 'agent-probes', 'blink-test', 'qinghe_blink.glb')
OUT = os.path.join(REPO, 'agent-probes', 'blink-test', 'reimport_check.json')

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=GLB)

lids = [o for o in bpy.data.objects
        if o.type == 'MESH' and o.data.shape_keys]
if not lids:
    raise SystemExit('no shape-key mesh after re-import')
lid = lids[0]
sk = lid.data.shape_keys


def evaluated_verts():
    dg = bpy.context.evaluated_depsgraph_get()
    oe = lid.evaluated_get(dg)
    me = oe.to_mesh()
    verts = [v.co.copy() for v in me.vertices]
    oe.to_mesh_clear()
    return verts


sc = bpy.context.scene
sc.frame_start, sc.frame_end = 1, 168
sc.frame_set(1)
v_open = evaluated_verts()
open_vals = {k.name: k.value for k in sk.key_blocks}
sc.frame_set(17)  # both eyes closed in the authored action
v_closed = evaluated_verts()
closed_vals = {k.name: k.value for k in sk.key_blocks}
drift = max((a - b).length for a, b in zip(v_open, v_closed))
minz_open = min(v.z for v in v_open)
minz_closed = min(v.z for v in v_closed)

arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
action = (sk.animation_data.action
          if sk.animation_data and sk.animation_data.action else None)

report = {
    'glb': os.path.relpath(GLB, REPO),
    'objects': [o.name for o in bpy.data.objects],
    'lid_mesh': lid.name,
    'lid_verts': len(lid.data.vertices),
    'lid_polys': len(lid.data.polygons),
    'shape_keys': [k.name for k in sk.key_blocks],
    'target_count': len(sk.key_blocks) - 1,
    'action': action.name if action else None,
    'action_frame_range': list(action.frame_range) if action else None,
    'armature': arm.name if arm else None,
    'bones': len(arm.data.bones) if arm else 0,
    'vertex_groups': len(lid.vertex_groups),
    'modifiers': [m.type for m in lid.modifiers],
    'values_frame1': {k: round(v, 4) for k, v in open_vals.items()},
    'values_frame17': {k: round(v, 4) for k, v in closed_vals.items()},
    'max_vertex_drift_frame1_to_17_m': round(drift, 6),
    'moved_verts_over_1mm': sum(1 for a, b in zip(v_open, v_closed) if (a - b).length > 0.001),
    'lid_min_z_open_m': round(minz_open, 5),
    'lid_min_z_closed_m': round(minz_closed, 5),
    'lid_min_z_drop_m': round(minz_open - minz_closed, 5),
    'morphs_drive_geometry': drift > 0.03,
}
with open(OUT, 'w') as f:
    json.dump(report, f, indent=2)
print('REIMPORT_CHECK_OK')
print(json.dumps(report, indent=2))
