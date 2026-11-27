#!/usr/bin/env python3
"""Render 5 phases of the retargeted GLB in Blender 3.4.1 (EEVEE, CPU/GPU viewport)."""
import bpy, math, os, sys
from mathutils import Vector
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
glb = argv[argv.index('--glb') + 1] if '--glb' in argv else None
out_dir = argv[argv.index('--out-dir') + 1] if '--out-dir' in argv else None
if not glb or not out_dir:
    raise SystemExit('RENDER_ERROR: --glb and --out-dir required')
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = 30
bpy.ops.import_scene.gltf(filepath=glb)
arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
act = arm.animation_data.action if arm and arm.animation_data else None
if act:
    scene.frame_start = int(act.frame_range[0]); scene.frame_end = int(act.frame_range[1])
    act.name = 'Animation'
# world + lights + ground + camera
world = bpy.data.worlds.new('W'); scene.world = world; world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.03, 0.045, 0.07, 1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, 0))
plane = bpy.context.object; plane.name = 'Ground'
mat = bpy.data.materials.new('GroundMat'); mat.use_nodes = True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.06, 0.075, 0.10, 1)
mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.85
plane.data.materials.append(mat)
bpy.ops.object.light_add(type='SUN', location=(3, -4, 6))
sun = bpy.context.object; sun.data.energy = 3.0; sun.rotation_euler = (math.radians(45), 0, math.radians(25))
bpy.ops.object.light_add(type='AREA', location=(-2.5, -3.5, 2.8))
area = bpy.context.object; area.data.energy = 120; area.data.size = 4; area.rotation_euler = (math.radians(65), 0, math.radians(-30))
bpy.ops.object.camera_add(location=(2.2, -3.4, 1.45))
cam = bpy.context.object; cam.data.lens = 55
target = Vector((0, 0, 0.82)); direction = target - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
scene.camera = cam
scene.render.engine = 'BLENDER_EEVEE'
scene.render.resolution_x = 640; scene.render.resolution_y = 640
scene.render.film_transparent = False
os.makedirs(out_dir, exist_ok=True)
frames = [scene.frame_start, scene.frame_start + (scene.frame_end - scene.frame_start) // 4,
          scene.frame_start + (scene.frame_end - scene.frame_start) // 2,
          scene.frame_start + 3 * (scene.frame_end - scene.frame_start) // 4, scene.frame_end]
for f in frames:
    scene.frame_set(f)
    scene.render.filepath = os.path.join(out_dir, 'blender_%04d.png' % f)
    bpy.ops.render.render(write_still=True)
    print('RENDERED', f, scene.render.filepath)
print('RENDER_DONE', frames)
