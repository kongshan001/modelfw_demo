"""Decimate a Tripo GLB for the Intel HD target while keeping PBR maps.

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
      --python tools/blender/decimate_car.py -- \
      --input assets/ai/tripo/car/car.glb \
      --output /tmp/car_decimated.glb --target-tris 30000
"""

import argparse
import os
import sys

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True)
parser.add_argument("--output", required=True)
parser.add_argument("--target-tris", type=int, default=30000)
args = parser.parse_args(ARGS)

IN = os.path.abspath(args.input)
OUT = os.path.abspath(args.output)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)

meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
counts = []
for obj in meshes:
    obj.data.calc_loop_triangles()
    counts.append((obj, len(obj.data.loop_triangles)))
total = sum(c for _, c in counts)
print("IMPORTED tris=%d meshes=%d" % (total, len(meshes)))

ratio = min(1.0, float(args.target_tris) / float(total))
for obj, tri_count in counts:
    if tri_count <= 0:
        continue
    mod = obj.modifiers.new("Decimate", "DECIMATE")
    mod.decimate_type = "COLLAPSE"
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.calc_loop_triangles()
    print("MESH %s %d -> %d" % (obj.name, tri_count, len(obj.data.loop_triangles)))

bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_apply=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
    export_cameras=False,
    export_lights=False,
    export_yup=True,
)
print("EXPORTED", OUT, os.path.getsize(OUT))
