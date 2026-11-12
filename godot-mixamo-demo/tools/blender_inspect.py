#!/usr/bin/env python3
"""Blender acceptance gate for AI-generated character assets.

Run headless:
  /Applications/Blender.app/Contents/MacOS/Blender -b -P tools/blender_inspect.py -- \
      model.glb [--require-armature] [--export-normalized out.glb]

Reports armature/bone count, mixamorig bone coverage, meshes, vertices,
materials, world bounds, root transforms, and a T-pose hint. Exits non-zero
when --require-armature is set and no armature is found.
"""

import bpy
import json
import math
import sys
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
paths = [a for a in argv if not a.startswith("--")]
flags = {a for a in argv if a.startswith("--")}
if not paths:
    print("usage: blender -b -P blender_inspect.py -- <model.glb|model.fbx> [--require-armature] [--export-normalized out.glb]")
    raise SystemExit(2)
src = paths[0]
require_armature = "--require-armature" in flags
export_path = None
if "--export-normalized" in argv:
    i = argv.index("--export-normalized")
    if i + 1 < len(argv):
        export_path = argv[i + 1]

bpy.ops.wm.read_factory_settings(use_empty=True)
if src.lower().endswith((".glb", ".gltf")):
    bpy.ops.import_scene.gltf(filepath=src)
elif src.lower().endswith(".fbx"):
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_fbx")
    except Exception:
        pass
    bpy.ops.import_scene.fbx(filepath=src)
else:
    bpy.ops.import_scene.gltf(filepath=src)

armatures = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bone_names = []
for arm in armatures:
    bone_names.extend(b.name for b in arm.data.bones)
mixamo_bones = [b for b in bone_names if "mixamorig" in b.lower()]

verts = sum(len(m.data.vertices) for m in meshes)
mats = sorted({slot.material.name for m in meshes for slot in m.material_slots if slot.material})
bbox = []
for m in meshes:
    for corner in m.bound_box:
        bbox.append(m.matrix_world @ Vector(corner))
if bbox:
    lo = Vector((min(v.x for v in bbox), min(v.y for v in bbox), min(v.z for v in bbox)))
    hi = Vector((max(v.x for v in bbox), max(v.y for v in bbox), max(v.z for v in bbox)))
    size = hi - lo
else:
    lo = hi = size = Vector((0.0, 0.0, 0.0))

# T-pose hint: Mixamo upper arms mostly horizontal in armature space.
tpose_hint = None
for arm in armatures:
    for name in ("mixamorig:LeftArm", "mixamorig_LeftArm", "LeftArm", "mixamorig:RightArm", "mixamorig_RightArm", "RightArm"):
        b = arm.data.bones.get(name)
        if b is not None:
            d = (b.tail_local - b.head_local)
            tpose_hint = abs(d.x) > abs(d.z) * 1.2
            break
    if tpose_hint is not None:
        break

report = {
    "source": src,
    "armatures": len(armatures),
    "bones": len(bone_names),
    "mixamo_bones": len(mixamo_bones),
    "bone_samples": bone_names[:12],
    "meshes": len(meshes),
    "vertices": verts,
    "materials": mats,
    "bounds_min": [round(v, 4) for v in lo],
    "bounds_max": [round(v, 4) for v in hi],
    "size": [round(v, 4) for v in size],
    "root_transforms": {
        o.name: {"location": [round(v, 4) for v in o.location], "scale": [round(v, 4) for v in o.scale]}
        for o in (armatures + meshes)[:8]
    },
    "tpose_hint": tpose_hint,
}

print("BLENDER_REPORT " + json.dumps(report, ensure_ascii=False))
print(f"[blender_inspect] armatures={len(armatures)} bones={len(bone_names)} mixamo={len(mixamo_bones)} meshes={len(meshes)} vertices={verts} size={tuple(round(v,3) for v in size)}")
if not armatures:
    print("[blender_inspect] STATIC_ONLY: no armature; rigging is required before RetargetModifier3D.")

if export_path:
    for o in bpy.context.view_layer.objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = bpy.context.view_layer.objects[0] if bpy.context.view_layer.objects else None
    bpy.ops.export_scene.gltf(filepath=export_path, export_format="GLB")
    print(f"[blender_inspect] exported {export_path}")

if require_armature and not armatures:
    raise SystemExit(1)
raise SystemExit(0)
