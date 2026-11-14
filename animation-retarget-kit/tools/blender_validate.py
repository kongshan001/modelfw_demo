#!/usr/bin/env python3
"""Validate a baked character animation: skeleton, action, bone-length stability.

Usage:
  blender -b -P tools/blender_validate.py -- assets/.../Michelle_Walk.glb
Prints VALIDATION_REPORT JSON; exits 1 on missing armature/animation or
bone-length drift > 1%.
"""
import bpy, json, sys, os, math

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if not argv:
    print("VALIDATION_ERROR: path required")
    raise SystemExit(2)
path = argv[0]

bpy.ops.wm.read_factory_settings(use_empty=True)
ext = os.path.splitext(path)[1].lower()
if ext in (".glb", ".gltf"):
    bpy.ops.import_scene.gltf(filepath=path)
elif ext == ".fbx":
    try:
        bpy.ops.preferences.addon_enable(module="io_scene_fbx")
    except Exception:
        pass
    bpy.ops.import_scene.fbx(filepath=path)
else:
    print("VALIDATION_ERROR: unsupported extension")
    raise SystemExit(2)

arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
if not arms:
    print("VALIDATION_ERROR: no armature")
    raise SystemExit(1)
arm = arms[0]
acts = [a for a in bpy.data.actions if a.users > 0 or a.use_fake_user]
if not acts:
    print("VALIDATION_ERROR: no animation action")
    raise SystemExit(1)
act = acts[0]
arm.animation_data_create()
arm.animation_data.action = act
start, end = int(act.frame_range[0]), int(act.frame_range[1])
rest_len = {b.name: b.length for b in arm.data.bones if b.length > 1e-8}
max_dev = 0.0
worst = None
for f in range(start, end + 1):
    bpy.context.scene.frame_set(f)
    bpy.context.view_layer.update()
    for pb in arm.pose.bones:
        if pb.name not in rest_len:
            continue
        length = (pb.tail - pb.head).length
        dev = abs(length - rest_len[pb.name]) / rest_len[pb.name]
        if dev > max_dev:
            max_dev = dev
            worst = (pb.name, round(length, 4), round(rest_len[pb.name], 4), f)

report = {
    "path": path,
    "armatures": len(arms),
    "bones": len(arm.data.bones),
    "meshes": len(meshes),
    "vertices": sum(len(m.data.vertices) for m in meshes),
    "materials": sorted({s.material.name for m in meshes for s in m.material_slots if s.material}),
    "actions": [a.name for a in acts],
    "frames": [start, end],
    "max_bone_length_deviation": round(max_dev, 6),
    "worst_bone": worst,
}
print("VALIDATION_REPORT " + json.dumps(report, ensure_ascii=False))
if max_dev > 0.01:
    print(f"VALIDATION_ERROR: bone length drift {max_dev:.3%} at {worst}")
    raise SystemExit(1)
