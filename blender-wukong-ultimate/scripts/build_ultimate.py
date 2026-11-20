"""齐天大圣 · 极意 — procedural hero-proportion character, rig, skin and clips.

Blender 3.4.1 / EEVEE Legacy. Original design: silver swept-back mane, bare
muscular torso, torn orange pants, blue sash / wrist guards / boots, monkey
face and tail, gold circlet.  No external models; all geometry is generated.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_ultimate.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_ultimate.py -- --preview 1
"""

import bpy
import math
import os
import random
import sys
from mathutils import Euler, Matrix, Vector, noise

PI = math.pi
TAU = PI * 2.0
FPS = 24
ROOT = "/Users/ks_128/Documents/modelfw_demo/blender-wukong-ultimate"
BLEND = ROOT + "/wukong_ultimate.blend"

random.seed(20261119)


# ── scene / material helpers ────────────────────────────────────────────────

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 16
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.06
    scene.eevee.bloom_threshold = 1.0
    scene.eevee.bloom_radius = 7.0
    scene.eevee.use_gtao = True
    scene.eevee.gtao_distance = 0.25
    scene.eevee.use_ssr = True
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = 48
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'Medium High Contrast'
    scene.view_settings.exposure = 0.15
    return scene


def set_input(node, names, value):
    for n in names:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


def mat(name, color, metallic=0.0, rough=0.5, emission=None, emit=0.0,
        alpha=1.0, specular=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    set_input(b, ['Base Color'], (*color, 1.0))
    set_input(b, ['Metallic'], metallic)
    set_input(b, ['Roughness'], rough)
    set_input(b, ['Specular'], specular)
    if emission is not None:
        set_input(b, ['Emission', 'Emission Color'], (*emission, 1.0))
        set_input(b, ['Emission Strength'], emit)
    if alpha < 1.0:
        set_input(b, ['Alpha'], alpha)
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
        m.show_transparent_back = False
    return m


def make_image(name, size, fn):
    """Procedural texture, packed into the .blend and embedded in the GLB."""
    img = bpy.data.images.new(name, width=size, height=size, alpha=False)
    px = [0.0] * (size * size * 4)
    for y in range(size):
        v = y / (size - 1)
        for x in range(size):
            u = x / (size - 1)
            r, g, b = fn(u, v)
            i = (y * size + x) * 4
            px[i] = r
            px[i + 1] = g
            px[i + 2] = b
            px[i + 3] = 1.0
    # NOTE: assigning colorspace after pixels clears the buffer in 3.4.
    os.makedirs(ROOT + '/textures', exist_ok=True)
    img.pixels = px
    img.update()
    img.filepath_raw = ROOT + '/textures/' + name + '.png'
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def mat_tex(name, img, metallic=0.0, rough=0.5, emission=None, emit=0.0,
            specular=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    links = m.node_tree.links
    b = nodes['Principled BSDF']
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.location = (-360, 240)
    links.new(tex.outputs['Color'], b.inputs['Base Color'])
    set_input(b, ['Metallic'], metallic)
    set_input(b, ['Roughness'], rough)
    set_input(b, ['Specular'], specular)
    if emission is not None:
        set_input(b, ['Emission', 'Emission Color'], (*emission, 1.0))
        set_input(b, ['Emission Strength'], emit)
    return m


def build_textures():
    def cloth_orange(u, v):
        grain = 0.5 + 0.5 * math.sin(u * 420.0) * math.sin(v * 420.0)
        patch = 0.5 + 0.5 * math.sin(u * 11.0 + math.sin(v * 17.0) * 2.0)
        wear = max(0.0, math.sin(v * 38.0 + u * 7.0) - 0.72) * 0.5
        fade = 0.86 + 0.14 * v
        r = (0.70 + 0.04 * grain - 0.06 * patch - wear) * fade
        g = (0.115 + 0.016 * grain - 0.02 * patch - wear * 0.5) * fade
        b = (0.018 + 0.006 * grain) * fade
        return (max(r, 0.02), max(g, 0.01), max(b, 0.005))

    def cloth_blue(u, v):
        grain = 0.5 + 0.5 * math.sin(u * 380.0 + 1.3) * math.sin(v * 380.0)
        patch = 0.5 + 0.5 * math.sin(u * 9.0 + v * 5.0)
        r = 0.048 + 0.010 * grain - 0.008 * patch
        g = 0.115 + 0.016 * grain - 0.008 * patch
        b = 0.305 + 0.025 * grain - 0.015 * patch
        return (r, g, b)

    def hair_silver(u, v):
        streak = 0.5 + 0.5 * math.sin(v * 46.0 + math.sin(u * 7.0) * 0.6)
        ridge = 0.5 + 0.5 * math.sin(v * 9.0 + 1.0)
        tip = 0.78 + 0.32 * u
        r = (0.70 + 0.18 * streak + 0.10 * ridge) * tip
        g = (0.74 + 0.17 * streak + 0.09 * ridge) * tip
        b = (0.82 + 0.15 * streak + 0.07 * ridge) * tip
        return (min(r, 1.0), min(g, 1.0), min(b, 1.0))

    def fur_silver(u, v):
        strand = 0.5 + 0.5 * math.sin(v * 70.0 + math.sin(u * 5.0) * 1.4)
        patch = 0.5 + 0.5 * math.sin(u * 13.0 + v * 9.0)
        base = 0.58 + 0.14 * strand + 0.05 * patch
        return (base * 1.00, base * 1.03, base * 1.10)

    def gold(u, v):
        scratch = 0.5 + 0.5 * math.sin(v * 90.0 + u * 3.0)
        grime = 0.5 + 0.5 * math.sin(u * 23.0 + v * 31.0)
        r = 0.86 - 0.12 * grime + 0.03 * scratch
        g = 0.56 - 0.13 * grime + 0.04 * scratch
        b = 0.16 - 0.05 * grime + 0.02 * scratch
        return (r, g, b)

    return {
        'orange': make_image('T_ClothOrange', 256, cloth_orange),
        'blue': make_image('T_ClothBlue', 256, cloth_blue),
        'hair': make_image('T_HairSilver', 256, hair_silver),
        'fur': make_image('T_FurSilver', 256, fur_silver),
        'gold': make_image('T_Gold', 128, gold),
    }


# ── mesh helpers ────────────────────────────────────────────────────────────

PARTS = []


def register(o):
    PARTS.append(o)
    return o


def link(o):
    bpy.context.collection.objects.link(o)
    return o


def mesh_obj(name, verts, faces, material, uvs=None, smooth=True):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate(clean_customdata=False)
    me.update()
    if uvs is not None:
        layer = me.uv_layers.new(name='UVMap')
        for li, loop in enumerate(me.loops):
            layer.data[li].uv = uvs[loop.vertex_index]
    o = bpy.data.objects.new(name, me)
    link(o)
    o.data.materials.append(material)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def sphere(name, loc, scale, material, seg=32, rings=20, rot=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    if rot:
        o.rotation_euler = rot
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cylinder(name, loc, radius, depth, material, rot=(0, 0, 0), verts=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius,
                                        depth=depth, location=loc,
                                        rotation=rot)
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cone(name, loc, r1, r2, depth, material, rot=(0, 0, 0), verts=12):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(name, loc, scale, material, rot=(0, 0, 0), bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel > 0.0:
        b = o.modifiers.new('bevel', 'BEVEL')
        b.width = bevel
        b.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def torus(name, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=40, minor_segments=10,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def segment(name, a, b, radius, material, verts=20):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    o = cylinder(name, (a + b) * 0.5, radius, d.length, material,
                 rot=d.to_track_quat('Z', 'Y').to_euler(), verts=verts)
    return o


def tube(name, points, radii, material, segments=24, cap_start=True,
         cap_end=True, ragged=0.0, slit=(None, 0.0)):
    """Closed ring tube through points with per-ring radius; ragged hem.

    slit = (angle_center, width) removes lower faces on one side for a tear.
    """
    verts = []
    uvs = []
    faces = []
    rings = []
    n = len(points)
    for ring_i, (p, r) in enumerate(zip(points, radii)):
        p = Vector(p)
        if ring_i == 0:
            tangent = Vector(points[1]) - p
        elif ring_i == n - 1:
            tangent = p - Vector(points[-2])
        else:
            tangent = Vector(points[ring_i + 1]) - Vector(points[ring_i - 1])
        q = tangent.to_track_quat('Z', 'Y')
        ring = []
        for i in range(segments):
            a = TAU * i / segments
            local = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
            v = p + q @ local
            if ring_i == n - 1 and ragged > 0.0:
                wave = abs(math.sin(a * (segments * 0.5)))
                v.z -= ragged * wave
                v.x += 0.006 * math.sin(a * 7.0)
            ring.append(v)
            verts.append(tuple(v))
            uvs.append((i / segments, ring_i / max(1, n - 1)))
        rings.append(ring)
    for ring_i in range(n - 1):
        start = ring_i * segments
        for i in range(segments):
            j = (i + 1) % segments
            if slit[0] is not None and ring_i >= n - 2:
                a = TAU * (i + 0.5) / segments
                diff = abs((a - slit[0] + PI) % TAU - PI)
                if diff < slit[1] * 0.5:
                    continue
            faces.append((start + i, start + j,
                          start + segments + j, start + segments + i))
    if cap_start:
        base = len(verts)
        verts.append(tuple(Vector(points[0])))
        uvs.append((0.5, 0.0))
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base, j, i))
    if cap_end:
        base = len(verts)
        verts.append(tuple(Vector(points[-1])))
        uvs.append((0.5, 1.0))
        off = (n - 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base, off + i, off + j))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def blade(name, base, direction, length, width, thickness, material,
          sections=6, bend=(0, 0, 0), twist=0.0, uv_flip=False):
    """Flat tapered hair / fur blade with a raised centre ridge."""
    base = Vector(base)
    d = Vector(direction).normalized()
    bend = Vector(bend)
    verts = []
    uvs = []
    faces = []
    ring_index = []
    old_side = None
    for i in range(sections):
        t = i / sections
        p = base + d * (length * t) + bend * (t * t)
        tangent = (d + bend * (2.0 * t)).normalized()
        side = tangent.cross(Vector((0, 0, 1)))
        if side.length < 1e-5:
            side = tangent.cross(Vector((0, 1, 0)))
        side.normalize()
        if old_side is not None and side.dot(old_side) < 0:
            side = -side
        old_side = side
        normal = side.cross(tangent).normalized()
        if normal.dot(Vector((1, 0, 0))) < 0:
            normal = -normal
        w = width * (1.0 - t ** 1.75)
        th = thickness * (1.0 - t ** 1.45)
        cs = [
            side * -w,
            side * (-w * 0.45) + normal * th,
            normal * (th * 1.35),
            side * (w * 0.45) + normal * th,
            side * w,
            side * (w * 0.2) + normal * (-th * 0.5),
        ]
        ring = []
        for k, off in enumerate(cs):
            verts.append(tuple(p + off))
            uvs.append(((t if not uv_flip else 1.0 - t),
                         k / len(cs)))
            ring.append(len(verts) - 1)
        ring_index.append(ring)
    tip = base + d * length + bend
    verts.append(tuple(tip))
    uvs.append(((1.0 if not uv_flip else 0.0), 0.5))
    tip_i = len(verts) - 1
    for i in range(sections - 1):
        a = ring_index[i]
        b = ring_index[i + 1]
        for k in range(len(a)):
            k2 = (k + 1) % len(a)
            faces.append((a[k], a[k2], b[k2], b[k]))
    a = ring_index[-1]
    for k in range(len(a)):
        k2 = (k + 1) % len(a)
        faces.append((a[k], a[k2], tip_i))
    base_ring = ring_index[0]
    faces.append((base_ring[0], base_ring[4], base_ring[3],
                  base_ring[2], base_ring[1]))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def ribbon(name, points, widths, material, sections=5):
    """Thin double-sided cloth strip through points, width along Y-ish."""
    verts = []
    uvs = []
    faces = []
    prev_side = None
    rings = []
    n = len(points)
    for i, (p, w) in enumerate(zip(points, widths)):
        p = Vector(p)
        tangent = (Vector(points[min(i + 1, n - 1)]) -
                   Vector(points[max(i - 1, 0)])).normalized()
        side = tangent.cross(Vector((0, 1, 0)))
        if side.length < 1e-5:
            side = Vector((0, 1, 0))
        side.normalize()
        if prev_side is not None and side.dot(prev_side) < 0:
            side = -side
        prev_side = side
        for k, off in enumerate((-1.0, 1.0)):
            verts.append(tuple(p + side * (w * off * 0.5)))
            uvs.append((0.5 + k * 0.5, i / max(1, n - 1)))
        rings.append((len(verts) - 2, len(verts) - 1))
    for i in range(n - 1):
        a0, a1 = rings[i]
        b0, b1 = rings[i + 1]
        faces.append((a0, a1, b1, b0))
    o = mesh_obj(name, verts, faces, material, uvs=uvs)
    o.data.materials[0].use_backface_culling = False
    return o


# ── rig ─────────────────────────────────────────────────────────────────────

BONES = {}
ARM = None


def build_armature():
    global ARM
    arm_data = bpy.data.armatures.new('WukongUltimateRig')
    ARM = link(bpy.data.objects.new('WukongUltimateRig', arm_data))
    bpy.context.view_layer.objects.active = ARM
    bpy.ops.object.mode_set(mode='EDIT')

    def bone(name, head, tail, parent=None, connect=False, deform=True):
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        b.use_deform = deform
        if parent:
            b.parent = arm_data.edit_bones[parent]
            b.use_connect = connect
        BONES[name] = (Vector(head), Vector(tail))
        return b

    bone('root', (0, 0, 0), (0, 0, 0.16), deform=False)
    bone('hips', (0, 0, 1.00), (0, 0, 1.14), 'root')
    bone('spine', (0, 0, 1.14), (0, 0, 1.30), 'hips', True)
    bone('chest', (0, 0, 1.30), (0, 0, 1.50), 'spine', True)
    bone('neck', (0, 0, 1.50), (0, 0, 1.61), 'chest', True)
    bone('head', (0, 0, 1.61), (0, 0, 1.98), 'neck', True)
    bone('jaw', (0.07, 0, 1.79), (0.17, 0, 1.715), 'head')
    for side, sy in (('L', 1.0), ('R', -1.0)):
        bone('shoulder.' + side, (0, sy * 0.05, 1.47),
             (0, sy * 0.23, 1.48), 'chest')
        bone('upper_arm.' + side, (0, sy * 0.23, 1.48),
             (0.02, sy * 0.39, 1.23), 'shoulder.' + side, True)
        bone('forearm.' + side, (0.02, sy * 0.39, 1.23),
             (0.02, sy * 0.51, 0.99), 'upper_arm.' + side, True)
        bone('hand.' + side, (0.02, sy * 0.51, 0.99),
             (0.04, sy * 0.56, 0.88), 'forearm.' + side, True)
        bone('thigh.' + side, (0, sy * 0.16, 1.00),
             (0.02, sy * 0.18, 0.58), 'hips')
        bone('shin.' + side, (0.02, sy * 0.18, 0.58),
             (0, sy * 0.18, 0.13), 'thigh.' + side, True)
        bone('foot.' + side, (0, sy * 0.18, 0.13),
             (0.19, sy * 0.18, 0.05), 'shin.' + side, True)
        bone('toe.' + side, (0.19, sy * 0.18, 0.05),
             (0.27, sy * 0.18, 0.045), 'foot.' + side, True)
        bone('sash.' + side, (0, sy * 0.17, 1.08),
             (0, sy * 0.20, 0.78), 'hips')
    tail_pts = [(-0.16, -0.01, 1.00), (-0.37, -0.12, 1.08),
                (-0.56, -0.22, 1.24), (-0.67, -0.27, 1.46),
                (-0.66, -0.28, 1.68)]
    for i in range(4):
        bone('tail%d' % (i + 1), tail_pts[i], tail_pts[i + 1],
             'hips' if i == 0 else 'tail%d' % i, i > 0)

    # Non-deform control bones.  IK + copy-rotation, baked away on export.
    ctrl = [
        ('ctrl_hand.L', (0.02, 0.51, 0.99), (0.02, 0.51, 1.09)),
        ('ctrl_hand.R', (0.02, -0.51, 0.99), (0.02, -0.51, 1.09)),
        ('ctrl_elbow.L', (-0.55, 0.75, 1.15), (-0.55, 0.75, 1.25)),
        ('ctrl_elbow.R', (-0.55, -0.75, 1.15), (-0.55, -0.75, 1.25)),
        ('ctrl_foot.L', (0.0, 0.18, 0.13), (0.0, 0.18, 0.23)),
        ('ctrl_foot.R', (0.0, -0.18, 0.13), (0.0, -0.18, 0.23)),
        ('ctrl_knee.L', (1.0, 0.20, 0.52), (1.0, 0.20, 0.62)),
        ('ctrl_knee.R', (1.0, -0.20, 0.52), (1.0, -0.20, 0.62)),
        ('ctrl_hand_aim.L', (0.02, 0.51, 0.99), (0.04, 0.56, 0.88)),
        ('ctrl_hand_aim.R', (0.02, -0.51, 0.99), (0.04, -0.56, 0.88)),
        ('ctrl_foot_aim.L', (0.0, 0.18, 0.13), (0.19, 0.18, 0.05)),
        ('ctrl_foot_aim.R', (0.0, -0.18, 0.13), (0.19, -0.18, 0.05)),
    ]
    for n, h, t in ctrl:
        bone(n, h, t, 'root', deform=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    return ARM


def build_constraints():
    for side in ('L', 'R'):
        pb = ARM.pose.bones['forearm.' + side]
        c = pb.constraints.new('IK')
        c.target = ARM
        c.subtarget = 'ctrl_hand.' + side
        c.pole_target = ARM
        c.pole_subtarget = 'ctrl_elbow.' + side
        c.chain_count = 2
        c.pole_angle = math.radians(-90)
        c.use_tail = True

        pb = ARM.pose.bones['shin.' + side]
        c = pb.constraints.new('IK')
        c.target = ARM
        c.subtarget = 'ctrl_foot.' + side
        c.pole_target = ARM
        c.pole_subtarget = 'ctrl_knee.' + side
        c.chain_count = 2
        c.pole_angle = math.radians(-90)
        c.use_tail = True

        for bone_name, ctrl_name in (('hand.' + side, 'ctrl_hand_aim.' + side),
                                     ('foot.' + side, 'ctrl_foot_aim.' + side)):
            pb = ARM.pose.bones[bone_name]
            c = pb.constraints.new('COPY_ROTATION')
            c.target = ARM
            c.subtarget = ctrl_name
            c.target_space = 'WORLD'
            c.owner_space = 'WORLD'
            c.mix_mode = 'REPLACE'


# ── weighting ───────────────────────────────────────────────────────────────

def _dist_to_segment(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-10 else max(
        0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def weight_nearest(o, bone_names, k=2, power=3.2, floor=1e-4):
    groups = {name: o.vertex_groups.new(name=name) for name in bone_names}
    weights = {name: [] for name in bone_names}
    for v in o.data.vertices:
        p = o.matrix_world @ v.co
        ds = sorted((_dist_to_segment(p, *BONES[name]), name)
                    for name in bone_names)[:k]
        vals = []
        total = 0.0
        for d, name in ds:
            w = 1.0 / ((d + floor) ** power)
            vals.append((name, w))
            total += w
        for name, w in vals:
            weights[name].append((v.index, w / total))
    for name, entries in weights.items():
        for idx, w in entries:
            groups[name].add([idx], w, 'REPLACE')
    return o


def weight_rigid(o, bone_name):
    vg = o.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    return o


def weight_mix(o, a, b, wa=0.5):
    o.vertex_groups.new(name=a).add(list(range(len(o.data.vertices))),
                                    wa, 'REPLACE')
    o.vertex_groups.new(name=b).add(list(range(len(o.data.vertices))),
                                    1.0 - wa, 'REPLACE')
    return o


def add_vertex_colors(o, base, dark_spots=(), noise_amp=0.035):
    """Soft baked shading: cavity-style darkening + low-frequency variation."""
    me = o.data
    attr = me.color_attributes.new(name='Col', type='FLOAT_COLOR', domain='POINT')
    for v in me.vertices:
        p = o.matrix_world @ v.co
        n = noise.noise(p * 7.3) * 0.5 + 0.5
        shade = 1.0 - noise_amp * (n - 0.5)
        for spot, radius, amount in dark_spots:
            d = (p - Vector(spot)).length
            if d < radius:
                shade *= 1.0 - amount * (1.0 - d / radius) ** 2
        # gentle cool tint in recesses, warm on top
        attr.data[v.index].color = (
            base[0] * shade, base[1] * shade, base[2] * shade, 1.0)


# ── character body ──────────────────────────────────────────────────────────

def build_skin_body(materials, target_tris=23500):
    parts = []

    def ball(loc, scale, seg=24, rings=16):
        o = sphere('sk', loc, scale, materials['skin'], seg=seg, rings=rings)
        parts.append(o)
        return o

    def limb(a, b, r1, r2, seg=20):
        a = Vector(a)
        b = Vector(b)
        d = b - a
        n = 8
        pts = [a + d * (i / (n - 1)) for i in range(n)]
        radii = [r1 + (r2 - r1) * (i / (n - 1)) for i in range(n)]
        o = tube('sk_limb', pts, radii, materials['skin'], segments=seg)
        parts.append(o)
        return o

    # torso core
    ball((0.00, 0, 1.36), (0.165, 0.215, 0.185))
    ball((0.00, 0, 1.20), (0.135, 0.145, 0.115))
    ball((0.00, 0, 1.045), (0.145, 0.17, 0.115))
    ball((-0.055, 0, 1.045), (0.10, 0.16, 0.10))
    ball((-0.005, 0, 1.475), (0.12, 0.115, 0.075))
    ball((0.00, 0, 1.545), (0.098, 0.098, 0.105))
    # pecs / lats / abs / obliques
    ball((0.095, 0.085, 1.405), (0.075, 0.105, 0.075))
    ball((0.095, -0.085, 1.405), (0.075, 0.105, 0.075))
    ball((-0.01, 0.17, 1.31), (0.115, 0.075, 0.14))
    ball((-0.01, -0.17, 1.31), (0.115, 0.075, 0.14))
    for z in (1.175, 1.245, 1.315):
        for sy in (1, -1):
            ball((0.112, sy * 0.036, z), (0.027, 0.037, 0.027), 16, 10)
    ball((0.045, 0.115, 1.16), (0.075, 0.05, 0.085))
    ball((0.105, 0, 1.385), (0.030, 0.045, 0.105))
    ball((0.045, -0.115, 1.16), (0.075, 0.05, 0.085))

    for side, sy in (('L', 1.0), ('R', -1.0)):
        # shoulder / arm mass
        ball((0.0, sy * 0.255, 1.465), (0.115, 0.12, 0.13))
        limb((0.0, sy * 0.235, 1.46), (0.025, sy * 0.385, 1.24),
             0.098, 0.075)
        ball((0.045, sy * 0.315, 1.36), (0.07, 0.065, 0.10), 20, 12)
        ball((-0.03, sy * 0.335, 1.35), (0.055, 0.06, 0.095), 20, 12)
        limb((0.02, sy * 0.39, 1.235), (0.02, sy * 0.505, 1.00),
             0.079, 0.058)
        ball((0.035, sy * 0.445, 1.13), (0.055, 0.06, 0.09), 20, 12)
        # legs (pants cover most; keep the silhouette)
        limb((0.0, sy * 0.16, 1.005), (0.02, sy * 0.18, 0.59),
             0.115, 0.082)
        ball((0.035, sy * 0.165, 0.83), (0.09, 0.095, 0.17))
        ball((0.025, sy * 0.18, 0.585), (0.065, 0.065, 0.06))
        limb((0.015, sy * 0.18, 0.58), (0.0, sy * 0.18, 0.15),
             0.073, 0.052)
        ball((-0.01, sy * 0.19, 0.43), (0.06, 0.055, 0.115))

    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'SkinBody'

    rem = body.modifiers.new('voxel', 'REMESH')
    rem.mode = 'VOXEL'
    rem.voxel_size = 0.009
    rem.use_smooth_shade = True
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=rem.name)

    sm = body.modifiers.new('smooth', 'SMOOTH')
    sm.factor = 0.62
    sm.iterations = 3
    bpy.ops.object.modifier_apply(modifier=sm.name)

    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    if tris > target_tris:
        dec = body.modifiers.new('dec', 'DECIMATE')
        dec.ratio = target_tris / float(tris)
        bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in body.data.polygons:
        p.use_smooth = True

    weight_nearest(body, [
        'hips', 'spine', 'chest', 'neck',
        'shoulder.L', 'shoulder.R', 'upper_arm.L', 'upper_arm.R',
        'forearm.L', 'forearm.R', 'thigh.L', 'thigh.R', 'shin.L', 'shin.R',
    ], k=2, power=3.4)
    add_vertex_colors(body, (1.0, 1.0, 1.0), dark_spots=[
        ((0.13, 0.0, 1.31), 0.055, 0.30),   # sternum groove
        ((0.14, 0.0, 1.17), 0.045, 0.26),   # linea alba
        ((0.0, 0.0, 1.045), 0.11, 0.18),    # hip crease
        ((0.02, 0.22, 1.46), 0.10, 0.14),   # armpit L
        ((0.02, -0.22, 1.46), 0.10, 0.14),  # armpit R
        ((0.0, 0.0, 1.58), 0.06, 0.22),     # neck shadow
    ])
    register(body)
    return body


def build_hand(sy, name, materials):
    p = Vector((0.03, sy * 0.535, 0.945))
    parts = [sphere(name + '_palm', p, (0.055, 0.062, 0.085),
                    materials['skin'], 20, 12)]
    # knuckles + curled fingers, chunky heroic read
    for i in range(4):
        y = sy * (0.535 + (i - 1.5) * 0.028)
        base = Vector((0.055, y, 0.915))
        a = base
        b = base + Vector((0.035, sy * (i - 1.5) * 0.004, -0.05))
        c = b + Vector((0.012, 0, -0.045))
        parts.append(sphere(name + '_kn_%d' % i, a, (0.025, 0.024, 0.03),
                            materials['skin'], 12, 8))
        parts.append(tube(name + '_fing_%d' % i, [a, b, c],
                          [0.021, 0.018, 0.012], materials['skin'],
                          segments=10, cap_start=False))
    thumb_a = Vector((0.045, sy * 0.49, 0.95))
    thumb_b = thumb_a + Vector((0.055, sy * 0.022, -0.035))
    parts.append(tube(name + '_thumb', [thumb_a, thumb_b],
                      [0.024, 0.016], materials['skin'], segments=10))
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    weight_rigid(o, 'hand.' + ('L' if sy > 0 else 'R'))
    register(o)
    return o


def build_face(materials):
    parts = []

    def sp(loc, scale, m, seg=24, rings=16, rot=None):
        o = sphere('face', loc, scale, m, seg, rings, rot=rot)
        parts.append(o)
        return o

    # skull (fur) + face mask + muzzle
    sp((0.0, 0, 1.825), (0.155, 0.148, 0.155), materials['fur'], 32, 20)
    sp((0.085, 0, 1.825), (0.095, 0.132, 0.14), materials['face_skin'], 32, 20)
    sp((0.140, 0, 1.777), (0.060, 0.100, 0.070), materials['face_light'],
       24, 16)
    sp((0.118, 0, 1.895), (0.045, 0.120, 0.034), materials['fur'], 24, 12)
    # nose bridge / cheek planes
    sp((0.152, 0, 1.845), (0.040, 0.030, 0.060), materials['face_skin'],
       16, 10)
    sp((0.128, 0.075, 1.822), (0.030, 0.035, 0.050), materials['face_skin'],
       16, 10)
    sp((0.128, -0.075, 1.822), (0.030, 0.035, 0.050), materials['face_skin'],
       16, 10)
    # nose + nostrils + stern mouth line
    sp((0.194, 0, 1.792), (0.024, 0.046, 0.020), materials['face_dark'], 16, 10)
    for sy in (1, -1):
        sp((0.209, sy * 0.017, 1.782), (0.006, 0.010, 0.007),
           materials['black'], 10, 6)
    mouth = box('mouth_line', (0.201, 0, 1.731), (0.010, 0.075, 0.006),
                materials['black'], rot=(0, 0, 0), bevel=0.003)
    parts.append(mouth)
    lip = box('upper_lip', (0.198, 0, 1.742), (0.012, 0.078, 0.008),
              materials['face_dark'], bevel=0.004)
    parts.append(lip)
    sp((0.196, 0, 1.718), (0.020, 0.055, 0.010),
       materials['face_light'], 16, 8)
    # inner mouth cavity (reads when the jaw opens in charge/cast)
    sp((0.170, 0, 1.729), (0.034, 0.050, 0.020),
       materials['face_dark'], 16, 10)
    # eyes: hard dark socket, narrow silver-blue iris, heavy angry brow
    for sy in (1, -1):
        rot = (-sy * 0.26, 0.0, sy * 0.10)
        sp((0.170, sy * 0.060, 1.869), (0.022, 0.050, 0.026),
           materials['face_dark'], 20, 12, rot=rot)
        sp((0.181, sy * 0.060, 1.868), (0.014, 0.040, 0.018),
           materials['black'], 20, 12, rot=rot)
        sp((0.187, sy * 0.060, 1.867), (0.009, 0.024, 0.013),
           materials['eye'], 16, 10, rot=rot)
        sp((0.194, sy * 0.058, 1.865), (0.0035, 0.008, 0.009),
           materials['black'], 10, 6, rot=rot)
        sp((0.195, sy * 0.053, 1.873), (0.003, 0.006, 0.004),
           materials['tooth'], 8, 6, rot=rot)
        # upper lid, angled toward the nose for a scowl
        sp((0.178, sy * 0.060, 1.883), (0.020, 0.052, 0.012),
           materials['face_skin'], 16, 8, rot=(sy * 0.24, 0, sy * 0.08))
        # heavy dark brow, inner end low
        sp((0.169, sy * 0.060, 1.900), (0.025, 0.086, 0.021),
           materials['face_dark'], 16, 10, rot=(sy * 0.34, 0, sy * 0.05))
        sp((0.160, sy * 0.060, 1.912), (0.022, 0.080, 0.018),
           materials['fur'], 16, 10, rot=(sy * 0.30, 0, sy * 0.05))
    # small fangs tucked into the mouth line
    for sy in (1, -1):
        cone('fang2', (0.204, sy * 0.026, 1.743), 0.004, 0.0, 0.009,
             materials['tooth'], rot=(0, PI, 0), verts=8)
        parts.append(bpy.context.object)
    # ears
    for sy in (1, -1):
        sp((0.0, sy * 0.155, 1.842), (0.036, 0.070, 0.088),
           materials['face_skin'], 20, 12)
        sp((0.012, sy * 0.172, 1.842), (0.018, 0.043, 0.058),
           materials['face_dark'], 16, 10)
    # gold circlet + front gem
    o = torus('circlet', (0.005, 0, 1.915), 0.158, 0.012,
              materials['gold'], scale=(1.0, 1.05, 1.0))
    parts.append(o)
    sp((0.162, 0, 1.938), (0.028, 0.036, 0.036), materials['gem'], 14, 10)
    # lower jaw / chin weighted to jaw
    jaw_parts = []
    jaw_parts.append(sphere('jaw_chin', (0.155, 0, 1.723),
                            (0.055, 0.078, 0.032),
                            materials['face_light'], 20, 12))
    jaw_parts.append(sphere('jaw_lip', (0.190, 0, 1.735),
                            (0.024, 0.05, 0.014),
                            materials['face_dark'], 14, 8))

    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    head = bpy.context.object
    head.name = 'Head'
    weight_rigid(head, 'head')
    register(head)

    bpy.ops.object.select_all(action='DESELECT')
    for o in jaw_parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = jaw_parts[0]
    bpy.ops.object.join()
    jaw = bpy.context.object
    jaw.name = 'Jaw'
    weight_rigid(jaw, 'jaw')
    register(jaw)

    # cheek tufts + sideburns (silver fur), swept back along the jaw
    base = Vector((0.065, 0, 1.80))
    for sy in (1, -1):
        for k in range(2):
            b = base + Vector((0.02 + 0.01 * k, sy * (0.115 + 0.015 * k),
                               0.055 - 0.02 * k))
            d = Vector((-0.30, sy * 0.65, -0.35)).normalized()
            tuft = blade('cheek_tuft', b, d, 0.10, 0.032, 0.014,
                         materials['fur'], sections=4, bend=(-0.01, 0, -0.01))
            weight_rigid(tuft, 'head')
            register(tuft)
        # short sideburn down the jaw
        b = Vector((0.075, sy * 0.125, 1.785))
        d = Vector((-0.25, sy * 0.35, -1.0)).normalized()
        tuft = blade('sideburn', b, d, 0.13, 0.034, 0.012,
                     materials['fur'], sections=4, bend=(0.01, 0, -0.02))
        weight_rigid(tuft, 'head')
        register(tuft)

    return head


def build_hair(materials):
    hair = materials['hair']
    cap = sphere('hair_cap', (-0.025, 0, 1.895), (0.158, 0.163, 0.145),
                 hair, 32, 20)
    weight_rigid(cap, 'head')
    register(cap)
    back = sphere('hair_back', (-0.075, 0, 1.815), (0.14, 0.15, 0.18),
                  hair, 32, 20)
    weight_rigid(back, 'head')
    register(back)

    specs = []
    # broad centre crest: three chunky blades, swept back
    for i, (y, ln, w) in enumerate([(0.0, 0.36, 0.105),
                                    (0.075, 0.32, 0.095),
                                    (-0.075, 0.32, 0.095)]):
        specs.append(((0.015 - 0.005 * i, y, 1.955),
                      (-0.55, y * 1.1, 1.0), ln, w,
                      (-0.14, y * 0.5, -0.01)))
    # large side blades, swept back over the ears
    for sy in (1, -1):
        for k in range(2):
            y = sy * (0.105 + 0.028 * k)
            specs.append(((0.015 - 0.02 * k, y, 1.93 - 0.025 * k),
                          (-0.50, sy * (0.62 + 0.20 * k), 0.92),
                          0.30 - 0.03 * k, 0.085 - 0.01 * k,
                          (-0.10, sy * 0.15, -0.005 - 0.02 * k)))
        # temple locks, flatter against the skull
        specs.append(((0.088, sy * 0.132, 1.88),
                      (-0.30, sy * 0.50, 0.70), 0.20, 0.052,
                      (-0.07, sy * 0.05, -0.02)))
        # nape mane, short and curved down
        for k in range(2):
            specs.append(((-0.115 - 0.015 * k, sy * (0.065 + 0.045 * k),
                           1.79 - 0.03 * k),
                          (-0.82, sy * 0.30, -0.30),
                          0.19 - 0.015 * k, 0.065,
                          (-0.04, sy * 0.03, -0.05)))
        # one asymmetric forelock each side, swept across rather than spiked up
        if sy > 0:
            specs.append(((0.112, 0.050, 1.950), (0.55, -0.45, -0.20),
                          0.18, 0.055, (-0.03, -0.02, -0.045)))
        else:
            specs.append(((0.105, -0.055, 1.945), (0.40, 0.55, -0.15),
                          0.15, 0.045, (-0.02, 0.02, -0.03)))

    for i, (base, d, ln, w, bend) in enumerate(specs):
        o = blade('hair_%02d' % i, base, d, ln, w, 0.032, hair, sections=5,
                  bend=bend, twist=0.0)
        weight_rigid(o, 'head')
        register(o)

    # a few short fur tufts along the nape
    for i in range(4):
        o = blade('nape_%d' % i,
                  (-0.135, (i - 1.5) * 0.045, 1.735 + 0.01 * i),
                  (-0.75, (i - 1.5) * 0.12, -0.60), 0.11, 0.040, 0.014,
                  materials['fur'], sections=4, bend=(-0.01, 0, -0.02))
        weight_rigid(o, 'head')
        register(o)
    # long silver mane locks draping over the neck and shoulders
    for i in range(5):
        y = (i - 2) * 0.048
        o = blade('mane_lock_%d' % i,
                  (-0.145, y, 1.715 + 0.008 * (2 - abs(i - 2))),
                  (-0.42, y * 0.9, -1.0), 0.20 - 0.02 * abs(i - 2),
                  0.055, 0.022, materials['hair'], sections=5,
                  bend=(-0.025, y * 0.2, -0.015))
        weight_rigid(o, 'head')
        register(o)


def build_costume(materials):
    orange = materials['orange']
    blue = materials['blue']
    gold = materials['gold']

    # shorts / seat
    shorts = tube('pants_shorts', [(0, 0, 1.105), (0, 0, 1.045),
                                   (0, 0, 0.975), (0, 0, 0.905)],
                  [0.190, 0.207, 0.220, 0.215], orange, segments=28,
                  ragged=0.02)
    shorts.scale = (1.0, 1.12, 1.0)
    bpy.context.view_layer.objects.active = shorts
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    weight_nearest(shorts, ['hips', 'thigh.L', 'thigh.R'], k=2, power=2.4)
    add_vertex_colors(shorts, (1.0, 1.0, 1.0), dark_spots=[
        ((0, 0, 0.91), 0.12, 0.25)])
    register(shorts)

    # torn trouser legs, outer-side slit
    for side, sy in (('L', 1.0), ('R', -1.0)):
        o = tube('pants_leg.' + side,
                 [(0.0, sy * 0.155, 1.005),
                  (0.015, sy * 0.18, 0.84),
                  (0.025, sy * 0.195, 0.64),
                  (0.015, sy * 0.20, 0.46)],
                 [0.155, 0.172, 0.150, 0.118], orange, segments=24,
                 ragged=0.072, slit=(sy * PI * 0.5, 0.55))
        weight_nearest(o, ['hips', 'thigh.' + side, 'shin.' + side],
                       k=2, power=2.6)
        add_vertex_colors(o, (1.0, 1.0, 1.0), dark_spots=[
            ((0.02, sy * 0.27, 0.62), 0.10, 0.3)])
        register(o)
        # hanging torn strip on the outside
        strip_pts = [(0.02, sy * 0.355, 0.61), (0.03, sy * 0.36, 0.46),
                     (0.02, sy * 0.33, 0.355)]
        strip = ribbon('pants_strip.' + side, strip_pts, [0.07, 0.05, 0.02],
                       orange)
        weight_nearest(strip, ['thigh.' + side, 'shin.' + side], k=2,
                       power=2.6)
        register(strip)

    # blue sash + gold buckle + knot, two hanging tails
    band = tube('sash_band', [(0, 0, 1.115), (0, 0, 1.075)],
                [0.20, 0.205], blue, segments=28)
    band.scale = (1.0, 1.10, 1.0)
    bpy.context.view_layer.objects.active = band
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    weight_rigid(band, 'hips')
    register(band)
    buckle = box('sash_buckle', (0.215, 0, 1.095), (0.032, 0.105, 0.08),
                 gold, bevel=0.012)
    weight_rigid(buckle, 'hips')
    register(buckle)
    gem = sphere('sash_gem', (0.237, 0, 1.095), (0.018, 0.038, 0.038),
                 materials['gem'], 16, 10)
    weight_rigid(gem, 'hips')
    register(gem)
    for side, sy in (('L', 1.0), ('R', -1.0)):
        knot = sphere('sash_knot.' + side, (0.02, sy * 0.20, 1.06),
                      (0.055, 0.05, 0.045), blue, 16, 10)
        weight_rigid(knot, 'hips')
        register(knot)
        pts = [(0.02, sy * 0.205, 1.03), (-0.03, sy * 0.24, 0.92),
               (-0.05, sy * 0.22, 0.80), (-0.03, sy * 0.25, 0.69)]
        tails = ribbon('sash_tail.' + side, pts, [0.085, 0.075, 0.055, 0.02],
                       blue)
        weight_nearest(tails, ['sash.' + side, 'hips'], k=2, power=2.2)
        register(tails)
    # torn blue back-cloth for silhouette
    back_pts = [(-0.16, 0.0, 1.07), (-0.20, 0.0, 0.9), (-0.205, 0.0, 0.74),
                (-0.19, 0.0, 0.61)]
    back_cloth = ribbon('back_cloth', back_pts, [0.30, 0.34, 0.28, 0.14], blue)
    weight_nearest(back_cloth, ['hips', 'sash.L', 'sash.R'], k=2, power=1.8)
    register(back_cloth)

    # wrist guards with gold trim + trailing ribbon
    for side, sy in (('L', 1.0), ('R', -1.0)):
        a = Vector((0.02, sy * 0.46, 1.08))
        b = Vector((0.02, sy * 0.51, 0.985))
        guard = tube('wrist_guard.' + side, [a, (a + b) * 0.5, b],
                     [0.088, 0.082, 0.075], blue, segments=18, ragged=0.02)
        weight_nearest(guard, ['forearm.' + side, 'hand.' + side], k=2,
                       power=6.0)
        register(guard)
        for t, r in ((0.0, 0.09), (1.0, 0.078)):
            p = a.lerp(b, t)
            d = (b - a)
            ring = torus('wrist_trim.' + side, p, r, 0.008, gold,
                         rot=d.to_track_quat('Z', 'Y').to_euler())
            weight_rigid(ring, 'forearm.' + side)
            register(ring)
        flap_pts = [(0.00, sy * 0.54, 0.97), (-0.06, sy * 0.57, 0.91),
                    (-0.11, sy * 0.55, 0.84)]
        flap = ribbon('wrist_flap.' + side, flap_pts, [0.055, 0.04, 0.015],
                      blue)
        weight_nearest(flap, ['hand.' + side, 'forearm.' + side], k=2,
                       power=2.5)
        register(flap)

    # boots: sole + foot + shaft + gold trim, blue leather
    for side, sy in (('L', 1.0), ('R', -1.0)):
        sole = box('boot_sole.' + side, (0.09, sy * 0.18, 0.025),
                   (0.30, 0.145, 0.05), materials['leather'],
                   bevel=0.018)
        weight_rigid(sole, 'foot.' + side)
        register(sole)
        foot = sphere('boot_foot.' + side, (0.085, sy * 0.18, 0.075),
                      (0.135, 0.068, 0.058), blue, 24, 14)
        weight_rigid(foot, 'foot.' + side)
        register(foot)
        toe = box('boot_toe.' + side, (0.19, sy * 0.18, 0.065),
                  (0.11, 0.12, 0.075), blue, bevel=0.03)
        weight_rigid(toe, 'toe.' + side)
        register(toe)
        cap = box('boot_cap.' + side, (0.235, sy * 0.18, 0.06),
                  (0.035, 0.13, 0.06), gold, bevel=0.015)
        weight_rigid(cap, 'toe.' + side)
        register(cap)
        shaft = tube('boot_shaft.' + side,
                     [(0.0, sy * 0.18, 0.335), (0.0, sy * 0.18, 0.20),
                      (0.005, sy * 0.18, 0.09)],
                     [0.096, 0.088, 0.105], blue, segments=20, ragged=0.03)
        weight_nearest(shaft, ['shin.' + side, 'foot.' + side], k=2,
                       power=4.0)
        register(shaft)
        trim = torus('boot_trim.' + side, (0.0, sy * 0.18, 0.325),
                     0.095, 0.012, gold)
        weight_rigid(trim, 'shin.' + side)
        register(trim)
        strap = torus('boot_strap.' + side, (0.0, sy * 0.18, 0.19),
                      0.096, 0.008, gold, rot=(0, 0, 0))
        weight_nearest(strap, ['shin.' + side, 'foot.' + side], k=2,
                       power=4.0)
        register(strap)
        # gold shin plate
        plate = box('shin_plate.' + side, (0.09, sy * 0.18, 0.255),
                    (0.055, 0.10, 0.10), gold, bevel=0.02)
        weight_nearest(plate, ['shin.' + side], k=1, power=4.0)
        register(plate)

    # shoulder fur mantle (short, draped; keeps the bare chest read)
    for sy in (1, -1):
        for k in range(3):
            b = Vector((-0.03 + 0.02 * k, sy * (0.205 + 0.025 * k), 1.515))
            d = Vector((-0.45 + 0.05 * k, sy * 0.65, -0.18)).normalized()
            tuft = blade('shoulder_fur', b, d, 0.075 - 0.006 * k, 0.060,
                         0.020, materials['fur'], sections=4,
                         bend=(-0.02, sy * 0.02, -0.01))
            weight_nearest(tuft, ['shoulder.' + ('L' if sy > 0 else 'R'),
                                  'chest'], k=2, power=2.2)
            register(tuft)
        # elbow fur, swept back
        for k in range(2):
            b = Vector((-0.045, sy * (0.43 + 0.018 * k), 1.19))
            d = Vector((-0.75, sy * 0.20, -0.35)).normalized()
            tuft = blade('elbow_fur', b, d, 0.065, 0.040, 0.016,
                         materials['fur'], sections=4)
            weight_nearest(tuft, ['forearm.' + ('L' if sy > 0 else 'R'),
                                  'upper_arm.' + ('L' if sy > 0 else 'R')],
                           k=2, power=3.0)
            register(tuft)
        # ankle fur above boot
        for k in range(2):
            b = Vector((0.0, sy * (0.155 + 0.025 * k), 0.40))
            d = Vector((-0.55, sy * 0.20, -0.45)).normalized()
            tuft = blade('ankle_fur', b, d, 0.060, 0.034, 0.014,
                         materials['fur'], sections=3)
            weight_nearest(tuft, ['shin.' + ('L' if sy > 0 else 'R')],
                           k=1, power=3.0)
            register(tuft)
    # short fur tufts at the nape base, continuing the mane onto the neck
    for i in range(3):
        b = Vector((-0.10, (i - 1) * 0.06, 1.585))
        d = Vector((-0.55, (i - 1) * 0.18, -0.75)).normalized()
        tuft = blade('nape_base_%d' % i, b, d, 0.075, 0.045, 0.018,
                     materials['fur'], sections=3)
        weight_nearest(tuft, ['neck', 'chest'], k=2, power=1.8)
        register(tuft)


def build_tail(materials):
    pts = [(-0.16, -0.01, 1.00), (-0.37, -0.12, 1.08),
           (-0.56, -0.22, 1.24), (-0.67, -0.27, 1.46),
           (-0.66, -0.28, 1.68)]
    tail = tube('tail', pts, [0.050, 0.043, 0.036, 0.028, 0.020],
                materials['fur'], segments=16, ragged=0.0)
    weight_nearest(tail, ['tail1', 'tail2', 'tail3', 'tail4', 'hips'],
                   k=2, power=3.0)
    register(tail)
    # fur clumps along the last half of the tail
    for j, (b, bone) in enumerate([
            ((-0.50, -0.19, 1.18), 'tail2'),
            ((-0.62, -0.25, 1.38), 'tail3'),
            ((-0.665, -0.27, 1.55), 'tail4')]):
        for k in range(3):
            a = (k - 1) * 0.55
            d = Vector((-0.55 + 0.15 * math.cos(a), -0.30 + 0.35 * math.sin(a),
                        0.55 + 0.10 * math.cos(a))).normalized()
            o = blade('tail_fur_%d_%d' % (j, k), Vector(b), d,
                      0.095, 0.035, 0.014, materials['fur'], sections=4)
            weight_rigid(o, bone)
            register(o)
    # fuller tip fan
    for i in range(6):
        ang = (i / 6.0 - 0.42) * PI * 1.15
        d = Vector((-0.55, math.sin(ang) * 0.65, 0.62 + math.cos(ang) * 0.18)).normalized()
        b = Vector((-0.66, -0.28, 1.68)) + d * 0.01
        o = blade('tail_tip_%d' % i, b, d, 0.135, 0.032, 0.013,
                  materials['fur'], sections=4, bend=(-0.02, 0, 0.012))
        weight_rigid(o, 'tail4')
        register(o)


def build_staff(materials):
    a = Vector((-0.42, -0.34, 0.40))
    b = Vector((-0.25, 0.30, 1.98))
    staff = segment('staff', a, b, 0.022, materials['wood'], verts=14)
    weight_rigid(staff, 'chest')
    register(staff)
    d = b - a
    rot = d.to_track_quat('Z', 'Y').to_euler()
    for t in (0.0, 0.04, 0.96, 1.0):
        p = a.lerp(b, t)
        r = 0.038 if t in (0.0, 1.0) else 0.030
        cap = cylinder('staff_cap', p, r, 0.10 if r > 0.03 else 0.035,
                       materials['gold'], rot=rot, verts=14)
        weight_rigid(cap, 'chest')
        register(cap)
    for t in (0.2, 0.5, 0.8):
        p = a.lerp(b, t)
        band = cylinder('staff_band', p, 0.027, 0.024, materials['gold'],
                        rot=rot, verts=14)
        weight_rigid(band, 'chest')
        register(band)


def join_body(arm):
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'WukongUltimate_Body'
    body.parent = arm
    mod = body.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_vertex_groups = True
    return body


# ── animation ───────────────────────────────────────────────────────────────

ACTIONS = []


def reset_pose():
    for pb in ARM.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    ARM.animation_data.action = act
    reset_pose()
    ACTIONS.append(act)
    return act


def k_ctrl_pos(name, frame, pos):
    pb = ARM.pose.bones[name]
    m = pb.bone.matrix_local
    pb.location = m.to_3x3().inverted() @ (Vector(pos) - m.translation)
    pb.keyframe_insert('location', frame=frame)


def k_ctrl_rot(name, frame, rot):
    pb = ARM.pose.bones[name]
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = rot
    pb.keyframe_insert('rotation_euler', frame=frame)


def k_rot(name, frame, rot):
    pb = ARM.pose.bones[name]
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = rot
    pb.keyframe_insert('rotation_euler', frame=frame)


def k_loc(name, frame, delta):
    pb = ARM.pose.bones[name]
    m = pb.bone.matrix_local
    pb.location = m.to_3x3().inverted() @ Vector(delta)
    pb.keyframe_insert('location', frame=frame)


def k_scale(name, frame, s):
    pb = ARM.pose.bones[name]
    pb.scale = s
    pb.keyframe_insert('scale', frame=frame)


def stance(hand_l, hand_r, foot_l, foot_r):
    """Set base IK control channels for both hands/feet."""
    k_ctrl_pos('ctrl_hand.L', 1, hand_l)
    k_ctrl_pos('ctrl_hand.R', 1, hand_r)
    k_ctrl_pos('ctrl_foot.L', 1, foot_l)
    k_ctrl_pos('ctrl_foot.R', 1, foot_r)


def animate_idle():
    new_action('Idle')
    for f, b, sway in ((1, 0.0, 1.0), (13, 0.012, 0.95), (25, 0.0, 1.0),
                       (37, 0.011, 1.05), (49, 0.0, 1.0)):
        k_loc('hips', f, (0, 0, -0.025 + b))
        k_ctrl_pos('ctrl_hand.L', f, (0.17, 0.36, 1.00 + b * 0.8))
        k_ctrl_pos('ctrl_hand.R', f, (0.17, -0.36, 1.00 + b * 0.8))
        k_ctrl_pos('ctrl_foot.L', f, (0.07, 0.205, 0.13))
        k_ctrl_pos('ctrl_foot.R', f, (0.07, -0.205, 0.13))
        k_rot('spine', f, (0.015, 0, 0.01 * sway))
        k_rot('chest', f, (0.01, 0, -0.012 * sway))
        k_rot('head', f, (-0.01, 0.03 * sway, 0.02 * sway))
        k_rot('jaw', f, (0.0, 0, 0))
        for i in range(4):
            k_rot('tail%d' % (i + 1), f,
                  (0.08 * math.sin(f * 0.12 + i * 0.8),
                   0.0, 0.16 * math.sin(f * 0.12 + i * 0.7) + 0.06))
        k_rot('shoulder.L', f, (0, 0, 0.02 * sway))
        k_rot('shoulder.R', f, (0, 0, -0.02 * sway))
    return 49


def animate_run():
    new_action('Run')
    # 16-frame loop at 24fps
    phases = [
        (1, (0.30, 0.205, 0.135), (-0.20, -0.20, 0.16),
         (0.44, -0.30, 1.10), (-0.02, 0.34, 1.00), 0.0),
        (5, (0.10, 0.205, 0.12), (0.04, -0.205, 0.30),
         (0.30, -0.38, 1.05), (0.10, 0.34, 1.05), 0.035),
        (9, (-0.20, 0.205, 0.16), (0.30, -0.205, 0.135),
         (-0.02, -0.34, 1.00), (0.44, 0.30, 1.10), 0.0),
        (13, (0.04, 0.205, 0.30), (0.10, -0.205, 0.12),
         (0.10, -0.34, 1.05), (0.30, 0.38, 1.05), 0.035),
        (17, (0.30, 0.205, 0.135), (-0.20, -0.20, 0.16),
         (0.44, -0.30, 1.10), (-0.02, 0.34, 1.00), 0.0),
    ]
    for f, fl, fr, hl, hr, bob in phases:
        k_loc('hips', f, (0.02, 0.0, -0.055 + bob))
        k_ctrl_pos('ctrl_foot.L', f, fl)
        k_ctrl_pos('ctrl_foot.R', f, fr)
        k_ctrl_pos('ctrl_hand.L', f, hl)
        k_ctrl_pos('ctrl_hand.R', f, hr)
        k_rot('spine', f, (0.20, 0.03, 0.04))
        k_rot('chest', f, (0.06, -0.03, -0.05))
        k_rot('head', f, (-0.18, 0, 0))
        k_rot('jaw', f, (0.05, 0, 0))
        k_rot('sash.L', f, (0.0, 0.0, 0.15))
        k_rot('sash.R', f, (0.0, 0.0, -0.15))
        for i in range(4):
            k_rot('tail%d' % (i + 1), f,
                  (0.12 * math.sin(f * 0.3 + i), 0, 0.10 + 0.04 * i))
    return 17


def animate_charge():
    new_action('Charge')
    # Both palms gather at the sternum (an original cast stance, not a hip-cocked
    # imitation).  The body coils, then the head lifts on the aura surge.
    for f, tremble, look, breath in ((1, 0.0, 0.0, 0.0),
                                     (9, 0.003, 0.05, 0.012),
                                     (17, 0.0, -0.14, 0.02),
                                     (25, 0.004, 0.02, 0.008),
                                     (33, 0.0, 0.0, 0.0)):
        k_loc('hips', f, (0.0, 0.0, -0.12 + tremble + breath))
        k_ctrl_pos('ctrl_foot.L', f, (0.03, 0.27, 0.13))
        k_ctrl_pos('ctrl_foot.R', f, (0.03, -0.27, 0.13))
        k_ctrl_pos('ctrl_hand.L', f, (0.34 + tremble, 0.105,
                                     1.155 + tremble))
        k_ctrl_pos('ctrl_hand.R', f, (0.35 + tremble, -0.105,
                                     1.155 + tremble))
        k_rot('spine', f, (0.20, 0.0, 0.0))
        k_rot('chest', f, (0.06, 0.0, 0.0))
        k_rot('neck', f, (-0.08, 0.0, 0))
        k_rot('head', f, (-0.10 + look, 0.0, 0.0))
        k_rot('jaw', f, (0.10 + 0.03 * math.sin(f), 0, 0))
        k_rot('shoulder.L', f, (0, -0.06, 0.10))
        k_rot('shoulder.R', f, (0, 0.06, -0.10))
        for i in range(4):
            k_rot('tail%d' % (i + 1), f,
                  (-0.10 - i * 0.04, 0, 0.06 * math.sin(f * 0.2 + i)))
    # wrists turn so the palms face the gathering orb
    for side in ('L', 'R'):
        k_ctrl_rot('ctrl_hand_aim.' + side, 1, (0.15, 0, 0))
        k_ctrl_rot('ctrl_hand_aim.' + side, 17, (0.55, 0, 0))
        k_ctrl_rot('ctrl_hand_aim.' + side, 33, (0.15, 0, 0))
    return 33


def animate_cast():
    new_action('Cast')
    keys = [
        (1, -0.10, (0.18, -0.20, 1.02), (0.30, -0.30, 1.10),
         (0.03, 0.24, 0.13), (0.10, 0.30, 0.10), 0.0),
        (5, -0.13, (0.10, -0.24, 1.00), (0.25, -0.32, 1.06),
         (0.02, 0.25, 0.13), (0.12, 0.31, 0.10), 0.06),
        (9, -0.06, (0.59, 0.14, 1.26), (0.61, -0.14, 1.26),
         (0.10, 0.24, 0.13), (0.22, 0.28, 0.11), -0.10),
        (14, -0.045, (0.60, 0.13, 1.27), (0.62, -0.13, 1.27),
         (0.10, 0.24, 0.13), (0.22, 0.28, 0.11), -0.12),
        (22, -0.07, (0.44, 0.22, 1.18), (0.46, -0.22, 1.18),
         (0.08, 0.23, 0.13), (0.18, 0.27, 0.11), -0.05),
        (30, -0.10, (0.20, 0.30, 1.05), (0.22, -0.30, 1.05),
         (0.05, 0.23, 0.13), (0.14, 0.28, 0.10), 0.0),
    ]
    for f, hipz, hl, hr, fl, fr, lean in keys:
        k_loc('hips', f, (0.03, 0.0, hipz))
        k_ctrl_pos('ctrl_hand.L', f, hl)
        k_ctrl_pos('ctrl_hand.R', f, hr)
        k_ctrl_pos('ctrl_foot.L', f, fl)
        k_ctrl_pos('ctrl_foot.R', f, fr)
        k_rot('spine', f, (0.06 + lean, -0.06, 0.0))
        k_rot('chest', f, (0.04 + lean * 0.6, -0.04, 0.0))
        k_rot('head', f, (-0.04 - lean * 0.5, 0, 0))
        k_rot('jaw', f, (0.18 if 7 < f < 24 else 0.02, 0, 0))
        for i in range(4):
            k_rot('tail%d' % (i + 1), f,
                  (0.06 + 0.2 * math.sin(f * 0.2 + i), 0, -0.12))
    # palms forward (wrist control)
    k_ctrl_rot('ctrl_hand_aim.L', 1, (0, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.L', 8, (0.9, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.L', 14, (1.05, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.L', 24, (0.2, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.L', 30, (0, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.R', 1, (0, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.R', 8, (0.9, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.R', 14, (1.05, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.R', 24, (0.2, 0, 0))
    k_ctrl_rot('ctrl_hand_aim.R', 30, (0, 0, 0))
    return 30


def animate_hit():
    new_action('Hit')
    keys = [(1, (0, 0, 0), (0, 0, 0), (0.15, 0.36, 1.0)),
            (4, (-0.10, 0, 0.01), (-0.20, 0.10, 0.10),
             (0.02, 0.42, 1.02)),
            (8, (-0.06, 0, 0.0), (-0.10, 0.04, 0.04),
             (0.11, 0.38, 1.0)),
            (14, (0, 0, 0), (0, 0, 0), (0.17, 0.36, 1.0))]
    for f, hip, spine, hl in keys:
        k_loc('hips', f, hip)
        k_rot('spine', f, (spine[0], 0, spine[1]))
        k_rot('chest', f, (spine[0] * 1.2, 0, spine[1]))
        k_rot('head', f, (-0.25 if f == 4 else -0.05, 0.18 if f == 4 else 0, 0))
        k_rot('jaw', f, (0.12 if f == 4 else 0, 0, 0))
        k_ctrl_pos('ctrl_hand.L', f, hl)
        k_ctrl_pos('ctrl_hand.R', f, (hl[0], -hl[1], hl[2]))
        k_ctrl_pos('ctrl_foot.L', f, (0.07, 0.205, 0.13))
        k_ctrl_pos('ctrl_foot.R', f, (0.07, -0.205, 0.13))
        for i in range(4):
            k_rot('tail%d' % (i + 1), f,
                  (-0.20 if f == 4 else 0.0, 0, 0.15 if f == 4 else 0.04))
    return 14


def animate_victory():
    new_action('Victory')
    keys = [
        (1, -0.03, (0.17, 0.36, 1.00), (0.17, -0.36, 1.00), 0, 0, 0),
        (7, -0.13, (0.12, 0.30, 0.98), (0.12, -0.30, 0.98), 0.16, -0.1, 0.05),
        (15, -0.02, (0.38, 0.36, 1.72), (0.16, -0.28, 1.02), -0.15, 0.0, 0.0),
        (23, 0.015, (0.14, 0.36, 2.10), (0.24, -0.30, 1.04), -0.25, 0.10, 0.0),
        (36, 0.01, (0.16, 0.36, 2.09), (0.24, -0.30, 1.04), -0.22, 0.08, 0.0),
        (49, 0.01, (0.16, 0.36, 2.09), (0.24, -0.30, 1.04), -0.22, 0.08, 0.0),
    ]
    for f, hipz, hl, hr, chest, twist, sway in keys:
        k_loc('hips', f, (0, 0, hipz))
        k_ctrl_pos('ctrl_hand.L', f, hl)
        k_ctrl_pos('ctrl_hand.R', f, hr)
        k_ctrl_pos('ctrl_foot.L', f, (0.06, 0.23, 0.13))
        k_ctrl_pos('ctrl_foot.R', f, (0.06, -0.23, 0.13))
        k_rot('spine', f, (chest * 0.5, twist, sway))
        k_rot('chest', f, (chest, twist, -sway))
        k_rot('head', f, (-chest * 0.7, -twist, 0.04 * math.sin(f * 0.2)))
        k_rot('jaw', f, (0.16 if 13 < f < 40 else 0.0, 0, 0))
        for i in range(4):
            curl = 0.15 if f > 12 else 0.02
            k_rot('tail%d' % (i + 1), f,
                  (curl, 0, 0.20 * math.sin(f * 0.15 + i * 0.8) + 0.06))
    return 49


def build_animations():
    if ARM.animation_data is None:
        ARM.animation_data_create()
    clips = {}
    for name, builder, end in (('Idle', animate_idle, 49),
                               ('Run', animate_run, 17),
                               ('Charge', animate_charge, 33),
                               ('Cast', animate_cast, 30),
                               ('Hit', animate_hit, 14),
                               ('Victory', animate_victory, 49)):
        end = builder()
        # ensure a clean loop for cyclic clips
        if name in ('Idle', 'Run', 'Charge'):
            for fc in ARM.animation_data.action.fcurves:
                if len(fc.keyframe_points) > 0:
                    first = fc.keyframe_points[0]
                    last = fc.keyframe_points[-1]
                    if abs(last.co.x - end) > 1e-4:
                        continue
                    fc.keyframe_points[-1].co.y = first.co.y
                    fc.keyframe_points[-1].handle_left.y = first.co.y
                    fc.keyframe_points[-1].handle_right.y = first.co.y
        clips[name] = ARM.animation_data.action
        for fc in ARM.animation_data.action.fcurves:
            for kp in fc.keyframe_points:
                kp.interpolation = 'BEZIER'
    ARM.animation_data.action = clips['Idle']
    bpy.context.scene.frame_end = 49
    bpy.context.scene.frame_set(1)
    return clips


# ── preview stage (kept in the .blend) ──────────────────────────────────────

def build_preview_stage(materials):
    scene = bpy.context.scene
    world = bpy.data.worlds.new('WukongUltimateWorld')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.015, 0.022, 0.045, 1)
    bg.inputs['Strength'].default_value = 0.55
    scene.world = world

    floor_mat = mat('stage_floor', (0.025, 0.030, 0.045), 0.2, 0.5)
    ring_mat = mat('stage_ring', (0.55, 0.32, 0.08), 1.0, 0.3)
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=3.2, depth=0.12,
                                        location=(0, 0, -0.06))
    plinth = bpy.context.object
    plinth.name = 'stage_plinth'
    plinth.data.materials.append(floor_mat)
    bevel = plinth.modifiers.new('bevel', 'BEVEL')
    bevel.width = 0.04
    bevel.segments = 3
    torus('stage_ring', (0, 0, 0.005), 2.7, 0.015, ring_mat)
    target = Vector((0, 0, 1.15))

    def area(name, loc, energy, size, color):
        l = bpy.data.lights.new(name, 'AREA')
        l.energy = energy
        l.shape = 'DISK'
        l.size = size
        l.color = color
        o = bpy.data.objects.new(name, l)
        o.location = loc
        link(o)
        o.rotation_euler = (target - o.location).to_track_quat(
            '-Z', 'Y').to_euler()
        return o

    area('key', (4.2, -4.4, 5.2), 900, 4.0, (1.0, 0.80, 0.58))
    area('fill', (-4.5, -2.5, 3.0), 380, 5.0, (0.45, 0.62, 1.0))
    area('rim', (-3.0, 4.0, 4.2), 850, 3.0, (0.55, 0.72, 1.0))
    area('top', (0, 0, 6.0), 180, 6.0, (1.0, 0.95, 0.85))

    cam_data = bpy.data.cameras.new('Camera')
    cam_data.lens = 62
    cam = bpy.data.objects.new('Camera', cam_data)
    link(cam)
    cam.location = (4.9, -3.1, 1.62)
    look = Vector((0, 0, 1.18))
    cam.rotation_euler = (look - cam.location).to_track_quat(
        '-Z', 'Y').to_euler()
    scene.camera = cam


# ── main ────────────────────────────────────────────────────────────────────

def main():
    scene = reset()
    textures = build_textures()

    materials = {
        'skin': mat('skin', (0.34, 0.165, 0.082), 0.0, 0.68, specular=0.32),
        'face_skin': mat('face_skin', (0.48, 0.28, 0.16), 0.0, 0.58),
        'face_light': mat('face_light', (0.65, 0.46, 0.32), 0.0, 0.55),
        'face_dark': mat('face_dark', (0.16, 0.075, 0.045), 0.0, 0.6),
        'black': mat('black', (0.006, 0.006, 0.008), 0.0, 0.92, specular=0.08),
        'tooth': mat('tooth', (0.85, 0.82, 0.72), 0.0, 0.35),
        'fur': mat_tex('fur_silver', textures['fur'], 0.0, 0.68),
        'hair': mat_tex('hair_silver', textures['hair'], 0.18, 0.30),
        'orange': mat_tex('cloth_orange', textures['orange'], 0.0, 0.86,
                          specular=0.25),
        'blue': mat_tex('cloth_blue', textures['blue'], 0.0, 0.74,
                        specular=0.32),
        'gold': mat_tex('gold', textures['gold'], 1.0, 0.24),
        'leather': mat('leather', (0.018, 0.020, 0.028), 0.0, 0.55),
        'wood': mat('staff_wood', (0.22, 0.055, 0.025), 0.0, 0.6),
        'paint': mat('war_paint', (0.015, 0.09, 0.30), 0.0, 0.7),
        'eye': mat('eye_silver', (0.65, 0.82, 1.0), 0.0, 0.25,
                   emission=(0.55, 0.82, 1.0), emit=2.2),
        'gem': mat('gold_gem', (0.10, 0.55, 1.0), 0.0, 0.2,
                   emission=(0.10, 0.55, 1.0), emit=2.5),
    }

    for m in (materials['hair'], materials['fur'], materials['orange'],
              materials['blue'], materials['paint']):
        m.use_backface_culling = False

    arm = build_armature()
    build_constraints()
    build_skin_body(materials)
    build_hand(1.0, 'Hand_L', materials)
    build_hand(-1.0, 'Hand_R', materials)
    build_face(materials)
    build_hair(materials)
    build_costume(materials)
    build_tail(materials)
    build_staff(materials)
    body = join_body(arm)
    build_animations()
    build_preview_stage(materials)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND)

    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    verts = len(body.data.vertices)
    print('ULT_BUILD_OK blend=%s tris=%d verts=%d bones=%d actions=%s' % (
        BLEND, tris, verts, len(arm.data.bones),
        ','.join(a.name for a in ACTIONS)))

    args = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    if '--preview' in args:
        frame = int(args[args.index('--preview') + 1])
        scene.frame_set(frame)
        if '--head' in args:
            cam = bpy.data.objects['Camera']
            cam.location = (2.2, -1.05, 1.86)
            look = Vector((0, 0, 1.83))
            cam.rotation_euler = (look - cam.location).to_track_quat(
                '-Z', 'Y').to_euler()
            cam.data.lens = 85
        scene.render.resolution_x = 720
        scene.render.resolution_y = 720
        scene.render.resolution_percentage = 100
        scene.eevee.taa_render_samples = 12
        scene.render.filepath = '/tmp/wukong_ult_preview_%03d%s.png' % (
            frame, '_head' if '--head' in args else '')
        bpy.ops.render.render(write_still=True)
        print('ULT_PREVIEW_OK', scene.render.filepath)


if __name__ == '__main__':
    main()
