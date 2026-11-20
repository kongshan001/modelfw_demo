"""Mellis HB-7 Core — a 10s procedural product film.

Run with Blender 3.4.1 (EEVEE Legacy works on the Intel HD 6000; 4.2's
EEVEE Next crashes on this GPU):

    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_scene.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_scene.py -- --still 60

Everything is built from primitives; no external models, textures or HDRI.
"""

import bpy
import math
import random
import sys
from mathutils import Vector

TAU = math.pi * 2.0
FPS = 24
FRAMES = 240  # 10 seconds
OUT = "/tmp/hb7_blender"


# ── helpers ──────────────────────────────────────────────────────────────────

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 8
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.04
    scene.eevee.bloom_threshold = 1.1
    scene.eevee.bloom_radius = 6.5
    scene.eevee.use_ssr = True
    scene.eevee.use_ssr_refraction = True
    scene.eevee.use_gtao = True
    scene.eevee.gtao_distance = 0.25
    scene.eevee.use_motion_blur = True
    scene.eevee.motion_blur_shutter = 0.5
    scene.render.resolution_x = 960
    scene.render.resolution_y = 540
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = FRAMES
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'Medium High Contrast'
    scene.view_settings.exposure = 0.35
    return scene


def set_input(node, names, value):
    for name in names:
        if name in node.inputs:
            node.inputs[name].default_value = value
            return True
    return False


def material(name, base, metallic=0.0, rough=0.4, emission=None,
             emission_strength=0.0, alpha=1.0, transmission=0.0,
             clearcoat=0.0, ior=1.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    set_input(bsdf, ['Base Color'], (*base, 1.0))
    set_input(bsdf, ['Metallic'], metallic)
    set_input(bsdf, ['Roughness'], rough)
    set_input(bsdf, ['IOR'], ior)
    set_input(bsdf, ['Transmission', 'Transmission Weight'], transmission)
    set_input(bsdf, ['Clearcoat', 'Coat Weight'], clearcoat)
    set_input(bsdf, ['Clearcoat Roughness', 'Coat Roughness'], 0.12)
    if emission is not None:
        set_input(bsdf, ['Emission', 'Emission Color'], (*emission, 1.0))
        set_input(bsdf, ['Emission Strength'], emission_strength)
    if alpha < 1.0:
        set_input(bsdf, ['Alpha'], alpha)
        mat.blend_method = 'BLEND'
        mat.shadow_method = 'NONE'
        mat.show_transparent_back = False
    return mat


def link(obj):
    bpy.context.collection.objects.link(obj)
    return obj


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    link(o)
    if parent:
        o.parent = parent
    return o


def parent_keep(obj, parent):
    # Parts are authored in the root's local space; keep the local transform.
    obj.parent = parent
    return obj


def smooth(obj):
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True


def apply_scale(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)


def sphere(name, loc, scale, mat, parent=None, seg=48, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    apply_scale(o)
    o.data.materials.append(mat)
    smooth(o)
    if parent:
        parent_keep(o, parent)
    return o


def cylinder(name, loc, radius, depth, mat, rot=(0, 0, 0), parent=None,
             verts=48):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius,
                                        depth=depth, location=loc,
                                        rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    smooth(o)
    if parent:
        parent_keep(o, parent)
    return o


def torus(name, loc, major, minor, mat, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=64, minor_segments=16,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(mat)
    smooth(o)
    if parent:
        parent_keep(o, parent)
    return o


def cube(name, loc, scale, mat, rot=(0, 0, 0), parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    apply_scale(o)
    o.data.materials.append(mat)
    if parent:
        parent_keep(o, parent)
    return o


def segment(name, a, b, radius, mat, parent=None):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    mid = (a + b) * 0.5
    length = d.length
    rot = d.to_track_quat('Z', 'Y').to_euler()
    o = cylinder(name, mid, radius, length, mat, rot=rot, parent=None, verts=24)
    if parent:
        parent_keep(o, parent)
    return o


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat(
        '-Z', 'Y').to_euler()


def area_light(name, loc, target, energy, size, color):
    light = bpy.data.lights.new(name, 'AREA')
    light.energy = energy
    light.shape = 'DISK'
    light.size = size
    light.color = color
    obj = bpy.data.objects.new(name, light)
    obj.location = loc
    link(obj)
    aim(obj, target)
    return obj


# ── scene ────────────────────────────────────────────────────────────────────

def build():
    scene = reset()
    world = bpy.data.worlds.new('HB7World')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.012, 0.009, 0.007, 1)
    bg.inputs['Strength'].default_value = 0.45
    scene.world = world

    white = material('white_ceramic', (0.92, 0.89, 0.82), 0.05, 0.24,
                     clearcoat=0.5)
    white_hi = material('white_shell', (0.98, 0.96, 0.9), 0.02, 0.18,
                        clearcoat=0.6)
    black = material('black_metal', (0.012, 0.012, 0.011), 0.25, 0.45)
    optic_black = material('optic_black', (0.004, 0.004, 0.005), 0.0, 0.65,
                           ior=1.5)
    set_input(optic_black.node_tree.nodes['Principled BSDF'],
              ['Specular', 'Specular IOR Level'], 0.12)
    dark = material('dark_rubber', (0.03, 0.028, 0.025), 0.1, 0.55)
    red = material('red_enamel', (0.52, 0.025, 0.012), 0.25, 0.28,
                   clearcoat=0.6)
    brass = material('brass', (0.55, 0.34, 0.11), 1.0, 0.3)
    glow = material('red_glow', (0.2, 0.01, 0.005), 0.0, 0.3,
                    emission=(1.0, 0.06, 0.02), emission_strength=5.0)
    amber = material('amber_glow', (0.3, 0.08, 0.01), 0.0, 0.3,
                     emission=(1.0, 0.28, 0.04), emission_strength=3.0)
    glass = material('glass_capsule', (0.9, 0.95, 1.0), 0.0, 0.06,
                     alpha=0.04, ior=1.45)
    wing_mat = material('wing_membrane', (0.98, 0.95, 0.86), 0.0, 0.15,
                        alpha=0.7, clearcoat=0.25)
    vein_mat = material('wing_vein', (0.05, 0.04, 0.03), 0.2, 0.4)
    floor_mat = material('floor', (0.018, 0.014, 0.011), 0.25, 0.38)
    plinth_mat = material('plinth', (0.05, 0.045, 0.038), 0.35, 0.3)
    dust_mat = material('dust', (0.8, 0.5, 0.2), 0.0, 0.3,
                        emission=(1.0, 0.3, 0.06), emission_strength=1.2)

    root = empty('HB7_Root', (0, 0, 1.5))

    # ── thorax ──
    sphere('thorax_shell', (0, 0, 0), (0.88, 0.66, 0.66), white_hi, root)
    cylinder('thorax_core', (0, 0, 0), 0.26, 1.05, black,
             rot=(0, math.pi * 0.5, 0), parent=root)
    torus('thorax_red_a', (0.31, 0, 0), 0.63, 0.036, red,
          rot=(0, math.pi * 0.5, 0), parent=root)
    torus('thorax_red_b', (-0.3, 0, 0), 0.63, 0.036, red,
          rot=(0, math.pi * 0.5, 0), parent=root)
    torus('thorax_band', (0.02, 0, 0), 0.65, 0.05, dark,
          rot=(0, math.pi * 0.5, 0), parent=root)
    for i in range(8):
        a = TAU * i / 8.0
        sphere('bolt_%d' % i, (0.36, math.cos(a) * 0.63, math.sin(a) * 0.63),
               (0.03, 0.03, 0.03), brass, root, seg=16, rings=8)
    for i, (bx, by) in enumerate(((0.06, 0.12), (0.06, -0.12),
                                  (-0.16, 0.12), (-0.16, -0.12))):
        sphere('top_bolt_%d' % i, (bx, by, 0.61), (0.024,) * 3, brass, root,
               seg=12, rings=6)

    # clear canopy omitted: alpha spheres are expensive in EEVEE and add haze

    # ── head + optic ──
    cylinder('neck', (0.72, 0, 0), 0.23, 0.22, black,
             rot=(0, math.pi * 0.5, 0), parent=root)
    torus('neck_red', (0.73, 0, 0), 0.24, 0.022, red,
          rot=(0, math.pi * 0.5, 0), parent=root)
    torus('head_collar', (0.84, 0, 0.03), 0.4, 0.03, white_hi,
          rot=(0, math.pi * 0.5, 0), parent=root)
    sphere('head', (0.97, 0, 0.03), (0.44, 0.37, 0.37), white, root)
    torus('optic_rim', (1.16, 0, 0.03), 0.375, 0.035, dark,
          rot=(0, math.pi * 0.5, 0), parent=root)
    sphere('optic', (1.3, 0, 0.03), (0.32, 0.34, 0.34), optic_black, root,
           seg=48, rings=24)
    torus('optic_ring', (1.2, 0, 0.03), 0.345, 0.028, glow,
          rot=(0, math.pi * 0.5, 0), parent=root)
    sphere('optic_pupil', (1.53, 0, 0.03), (0.04, 0.12, 0.12), optic_black,
           root)
    for side in (-1, 1):
        a = (0.92, side * 0.12, 0.32)
        b = (1.2, side * 0.22, 0.6)
        segment('antenna_%d' % side, a, b, 0.014, black, root)
        sphere('antenna_tip_%d' % side, b, (0.04, 0.04, 0.04), red, root,
               seg=16, rings=8)

    # ── abdomen ──
    segs = [
        (-0.58, (0.42, 0.36, 0.36)),
        (-0.92, (0.4, 0.34, 0.34)),
        (-1.22, (0.36, 0.31, 0.31)),
        (-1.48, (0.32, 0.27, 0.27)),
    ]
    for i, (x, s) in enumerate(segs):
        sphere('abdomen_%d' % i, (x, 0, 0), s,
               white_hi if i % 2 == 0 else dark, root)
        torus('abdomen_band_%d' % i, (x + 0.11, 0, 0),
              s[1] * 1.01, 0.03, red if i % 2 == 0 else white_hi,
              rot=(0, math.pi * 0.5, 0), parent=root)
    torus('abdomen_red', (-1.06, 0, 0), 0.405, 0.02, red,
          rot=(0, math.pi * 0.5, 0), parent=root)

    # tail gear
    torus('tail_gear', (-1.78, 0, 0), 0.2, 0.04, brass,
          rot=(0, math.pi * 0.5, 0), parent=root)
    cylinder('tail_hub', (-1.78, 0, 0), 0.09, 0.1, red,
             rot=(0, math.pi * 0.5, 0), parent=root)
    for i in range(12):
        a = TAU * i / 12.0
        cube('tail_tooth_%d' % i,
             (-1.78, math.cos(a) * 0.24, math.sin(a) * 0.24),
             (0.045, 0.07, 0.045), brass, rot=(a, 0, 0), parent=root)

    # ── wings ──
    def wing(parent, side, x, phase, name):
        pivot = empty(name + '_pivot', (x, side * 0.46, 0.5), root)
        pivot.rotation_euler[2] = side * 0.35
        sphere(name + '_hinge', (x, side * 0.46, 0.5), (0.075,) * 3, black,
               root, seg=20, rings=10)
        sphere(name + '_hinge_red', (x, side * 0.46, 0.5), (0.035,) * 3, red,
               root, seg=12, rings=6)
        span = [(0.0, 0.0), (0.25, 0.15), (0.38, 0.55), (0.34, 0.95),
                (0.18, 1.35), (0.0, 1.45), (-0.2, 1.28), (-0.3, 0.9),
                (-0.25, 0.45), (-0.1, 0.12)]
        verts = [(x, side * z, 0.0) for x, z in span]
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(verts, [], [list(range(len(verts)))])
        mesh.update()
        obj = link(bpy.data.objects.new(name, mesh))
        obj.data.materials.append(wing_mat)
        mod = obj.modifiers.new('thin', 'SOLIDIFY')
        mod.thickness = 0.006
        obj.parent = pivot
        for k, xx in enumerate((0.14, 0.0, -0.16)):
            z_end = 1.32 if k == 0 else 1.0
            segment(name + '_vein_%d' % k, (xx, 0, 0.01),
                    (xx + 0.02, side * z_end, 0.01), 0.01, vein_mat, pivot)
        pivot['phase'] = phase
        pivot['side'] = side
        return pivot

    wing(root, 1, 0.12, 0.0, 'wing_lf')
    wing(root, 1, -0.28, 1.7, 'wing_lr')
    wing(root, -1, 0.12, 0.6, 'wing_rf')
    wing(root, -1, -0.28, 2.3, 'wing_rr')

    # ── legs ──
    for side in (-1, 1):
        for i, x in enumerate((0.38, 0.0, -0.38)):
            hip = (x, side * 0.42, -0.05)
            knee = (x + 0.04, side * 0.66, -0.38)
            ankle = (x + 0.16, side * 0.86, -0.68)
            toe = (x + 0.28, side * 0.98, -0.88)
            segment('leg_%d_%d_a' % (side, i), hip, knee, 0.04, black, root)
            segment('leg_%d_%d_b' % (side, i), knee, ankle, 0.033, black, root)
            segment('leg_%d_%d_c' % (side, i), ankle, toe, 0.027, black, root)
            sphere('leg_%d_%d_hip' % (side, i), hip, (0.07,) * 3, brass, root,
                   seg=16, rings=8)
            sphere('leg_%d_%d_knee' % (side, i), knee, (0.058,) * 3, black, root,
                   seg=16, rings=8)
            sphere('leg_%d_%d_knee_red' % (side, i), knee,
                   (0.032,) * 3, red, root, seg=12, rings=6)
            sphere('leg_%d_%d_toe' % (side, i), toe, (0.032,) * 3, red, root,
                   seg=12, rings=6)

    # ── floor / plinth ──
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = 'floor'
    floor.data.materials.append(floor_mat)
    cylinder('plinth', (0, 0, 0.06), 1.9, 0.12, plinth_mat, verts=96)
    bevel = bpy.context.object.modifiers.new('bevel', 'BEVEL')
    bevel.width = 0.035
    bevel.segments = 3
    torus('plinth_ring', (0, 0, 0.125), 1.62, 0.012, red, parent=None)

    # ── lights ──
    target = Vector((0, 0, 1.45))
    area_light('key', (4.5, -4.5, 5.0), target, 650, 4.5, (1.0, 0.82, 0.62))
    area_light('fill', (-4.8, -2.5, 3.0), target, 460, 5.0, (0.55, 0.72, 1.0))
    area_light('rim', (-2.5, 4.5, 4.2), target, 620, 3.0, (1.0, 0.16, 0.05))
    area_light('top', (0.0, 0.0, 6.5), target, 200, 6.0, (1.0, 0.95, 0.85))
    bpy.context.scene.view_settings.exposure = 0.05

    # ── dust motes ──
    random.seed(7)
    dust = empty('dust', (0, 0, 0), None)
    for i in range(18):
        a = random.uniform(0, TAU)
        r = random.uniform(1.6, 3.4)
        z = random.uniform(0.4, 3.2)
        p = (math.cos(a) * r, math.sin(a) * r, z)
        s = random.uniform(0.008, 0.018)
        m = sphere('dust_%d' % i, p, (s, s, s), dust_mat, dust, seg=8, rings=4)
    dust.rotation_euler[2] = 0
    dust.keyframe_insert('rotation_euler', frame=1)
    dust.rotation_euler[2] = 0.2
    dust.keyframe_insert('rotation_euler', frame=FRAMES)

    # ── camera rig ──
    cam_data = bpy.data.cameras.new('Camera')
    cam_data.lens = 52
    cam_data.dof.use_dof = True
    cam_data.dof.aperture_fstop = 2.8
    cam = link(bpy.data.objects.new('Camera', cam_data))
    orbit = empty('orbit', (0, 0, 1.55))
    focus = empty('focus', (0, 0, 1.55))
    cam.parent = orbit
    cam.location = (0.0, -7.2, 1.1)
    # look at the orbit centre; the parent then rotates the whole rig
    cam.rotation_euler = (-Vector(cam.location)).to_track_quat(
        '-Z', 'Y').to_euler()
    cam_data.dof.focus_object = focus
    scene.camera = cam

    # camera arc: start on the head side, reveal the tail
    orbit.rotation_euler[2] = math.radians(58)
    orbit.keyframe_insert('rotation_euler', index=2, frame=1)
    orbit.rotation_euler[2] = math.radians(-58)
    orbit.keyframe_insert('rotation_euler', index=2, frame=FRAMES)
    cam.location.y = -7.2
    cam.keyframe_insert('location', index=1, frame=1)
    cam.location.y = -6.55
    cam.keyframe_insert('location', index=1, frame=FRAMES)

    # root float
    for f, dz in ((1, 0.0), (60, 0.06), (120, 0.0), (180, -0.06),
                  (240, 0.0)):
        root.location = (0, 0, 1.5 + dz)
        root.keyframe_insert('location', index=2, frame=f)

    # wing flap: 3.6 Hz, baked every 2 frames, linear
    for o in bpy.data.objects:
        if o.name.endswith('_pivot'):
            side = int(o['side'])
            phase = float(o['phase'])
            for f in range(1, FRAMES + 1, 2):
                t = (f - 1) / FPS
                ang = 0.13 + 0.5 * math.sin(TAU * 3.6 * t + phase)
                o.rotation_euler[0] = side * ang
                o.keyframe_insert('rotation_euler', index=0, frame=f)
            for fc in o.animation_data.action.fcurves:
                for kp in fc.keyframe_points:
                    kp.interpolation = 'LINEAR'

    # optic ring pulse
    glow_bsdf = glow.node_tree.nodes.get('Principled BSDF')
    for f, strength in ((1, 3.0), (60, 6.0), (120, 3.0), (180, 6.0),
                        (240, 3.0)):
        glow_bsdf.inputs['Emission Strength'].default_value = strength
        glow_bsdf.inputs['Emission Strength'].keyframe_insert('default_value', frame=f)

    # bezier handles for smooth motion (wing curves stay linear)
    for action in bpy.data.actions:
        for fc in action.fcurves:
            for kp in fc.keyframe_points:
                if kp.interpolation != 'LINEAR':
                    kp.interpolation = 'BEZIER'

    # save + render
    bpy.ops.wm.save_as_mainfile(filepath='/Users/ks_128/Documents/modelfw_demo/blender-hb7/hb7_core.blend')

    still = None
    if '--' in sys.argv:
        args = sys.argv[sys.argv.index('--') + 1:]
        if '--still' in args:
            still = int(args[args.index('--still') + 1])

    if still is not None:
        scene.render.resolution_percentage = 60
        scene.frame_set(still)
        scene.render.filepath = '/tmp/hb7_still_%03d.png' % still
        bpy.ops.render.render(write_still=True)
        print('STILL_OK', scene.render.filepath)
    else:
        import os
        os.makedirs(OUT, exist_ok=True)
        scene.render.filepath = OUT + '/frame_'
        scene.render.use_file_extension = True
        bpy.ops.render.render(animation=True)
        print('ANIMATION_OK', OUT)


if __name__ == '__main__':
    build()
