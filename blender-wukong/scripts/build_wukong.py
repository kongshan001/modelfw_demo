"""齐天大圣 · 斗战形态 — procedural character + rig + ki-blast animation.

Blender 3.4.1 (EEVEE Legacy). Everything is primitive-based; no external assets.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_wukong.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_wukong.py -- --still 60
"""

import bpy
import math
import random
import sys
from mathutils import Vector, Euler

TAU = math.pi * 2.0
FPS = 24
FRAMES = 192  # 8 seconds
OUT = "/tmp/wukong_frames"
ROOT = "/Users/ks_128/Documents/modelfw_demo/blender-wukong"
PI = math.pi


# ── scene / helpers ─────────────────────────────────────────────────────────

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.eevee.taa_render_samples = 8
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.05
    scene.eevee.bloom_threshold = 1.0
    scene.eevee.bloom_radius = 7.0
    scene.eevee.use_ssr = True
    scene.eevee.use_ssr_refraction = True
    scene.eevee.use_gtao = True
    scene.eevee.gtao_distance = 0.25
    scene.eevee.use_motion_blur = True
    scene.eevee.motion_blur_shutter = 0.45
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
    scene.view_settings.exposure = 0.1
    return scene


def set_input(node, names, value):
    for n in names:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


def material(name, base, metallic=0.0, rough=0.5, emission=None,
             emission_strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    set_input(b, ['Base Color'], (*base, 1.0))
    set_input(b, ['Metallic'], metallic)
    set_input(b, ['Roughness'], rough)
    if emission is not None:
        set_input(b, ['Emission', 'Emission Color'], (*emission, 1.0))
        set_input(b, ['Emission Strength'], emission_strength)
    if alpha < 1.0:
        set_input(b, ['Alpha'], alpha)
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
        m.show_transparent_back = False
    return m


def link(o):
    bpy.context.collection.objects.link(o)
    return o


def empty(name, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    o.location = loc
    link(o)
    if parent:
        o.parent = parent
    return o


def apply_transform(o, rot=True, scale=True):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=rot, scale=scale)
    o.select_set(False)


def smooth(o):
    if o.type == 'MESH':
        for p in o.data.polygons:
            p.use_smooth = True


def sphere(name, loc, scale, mat, seg=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    apply_transform(o)
    o.data.materials.append(mat)
    smooth(o)
    return o


def cylinder(name, loc, radius, depth, mat, rot=(0, 0, 0), verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius,
                                        depth=depth, location=loc,
                                        rotation=rot)
    o = bpy.context.object
    o.name = name
    apply_transform(o)
    o.data.materials.append(mat)
    smooth(o)
    return o


def cone(name, loc, r1, r2, depth, mat, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2,
                                    depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    apply_transform(o)
    o.data.materials.append(mat)
    smooth(o)
    return o


def torus(name, loc, major, minor, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=48, minor_segments=12,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    apply_transform(o)
    o.data.materials.append(mat)
    smooth(o)
    return o


def box(name, loc, scale, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    apply_transform(o)
    o.data.materials.append(mat)
    return o


def segment(name, a, b, radius, mat, verts=20):
    a = Vector(a)
    b = Vector(b)
    d = b - a
    mid = (a + b) * 0.5
    o = cylinder(name, mid, radius, d.length, mat,
                 rot=d.to_track_quat('Z', 'Y').to_euler(), verts=verts)
    return o


# ── armature ────────────────────────────────────────────────────────────────

BONES = {}


def build_armature():
    arm_data = bpy.data.armatures.new('WukongRig')
    arm = link(bpy.data.objects.new('WukongRig', arm_data))
    bpy.context.view_layer.objects.active = arm
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

    bone('root', (0, 0, 0), (0, 0, 0.2), deform=False)
    bone('hips', (0, 0, 0.96), (0, 0, 1.12), 'root')
    bone('spine', (0, 0, 1.12), (0, 0, 1.32), 'hips', True)
    bone('chest', (0, 0, 1.32), (0, 0, 1.5), 'spine', True)
    bone('neck', (0, 0, 1.5), (0, 0, 1.6), 'chest', True)
    bone('head', (0, 0, 1.6), (0, 0, 2.02), 'neck', True)
    for side, sy in (('L', 1.0), ('R', -1.0)):
        bone('shoulder.' + side, (0, sy * 0.08, 1.45),
             (0, sy * 0.3, 1.45), 'chest')
        bone('upper_arm.' + side, (0, sy * 0.3, 1.45),
             (0, sy * 0.48, 1.22), 'shoulder.' + side, True)
        bone('forearm.' + side, (0, sy * 0.48, 1.22),
             (0, sy * 0.56, 0.98), 'upper_arm.' + side, True)
        bone('hand.' + side, (0, sy * 0.56, 0.98),
             (0, sy * 0.6, 0.85), 'forearm.' + side, True)
        bone('thigh.' + side, (0, sy * 0.17, 0.98),
             (0, sy * 0.2, 0.56), 'hips')
        bone('shin.' + side, (0, sy * 0.2, 0.56),
             (0, sy * 0.22, 0.14), 'thigh.' + side, True)
        bone('foot.' + side, (0, sy * 0.22, 0.14),
             (0.25, sy * 0.22, 0.04), 'shin.' + side, True)
    tail_pts = [(-0.2, 0, 0.98), (-0.42, 0, 1.1), (-0.62, 0, 1.28),
                (-0.76, 0, 1.48), (-0.84, 0, 1.72)]
    for i in range(4):
        bone('tail%d' % (i + 1), tail_pts[i], tail_pts[i + 1],
             'hips' if i == 0 else 'tail%d' % i, i > 0)

    bpy.ops.object.mode_set(mode='OBJECT')
    return arm


# ── weights + mesh assembly ────────────────────────────────────────────────

parts = []


def rigid(o, bone_name):
    vg = o.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    parts.append(o)
    return o


def blend(o, bone_a, bone_b, wa=0.5):
    vg = o.vertex_groups.new(name=bone_a)
    vg.add(list(range(len(o.data.vertices))), wa, 'REPLACE')
    vg2 = o.vertex_groups.new(name=bone_b)
    vg2.add(list(range(len(o.data.vertices))), 1.0 - wa, 'REPLACE')
    parts.append(o)
    return o


def distance_weights(o, bones):
    groups = {name: o.vertex_groups.new(name=name) for name in bones}
    raw = {name: [] for name in bones}
    for name in bones:
        head, tail = BONES[name]
        ab = tail - head
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            t = 0.0 if ab.length_squared == 0 else max(
                0.0, min(1.0, (p - head).dot(ab) / ab.length_squared))
            d = (p - (head + ab * t)).length
            raw[name].append(1.0 / ((d + 0.045) ** 4))
    for i in range(len(o.data.vertices)):
        total = sum(raw[name][i] for name in bones)
        if total <= 0:
            continue
        for name in bones:
            groups[name].add([i], raw[name][i] / total, 'REPLACE')
    parts.append(o)
    return o


def skin_body(arm):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    body = parts[0]
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = 'Wukong_Body'
    body.parent = arm
    mod = body.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_vertex_groups = True
    return body


# ── character ───────────────────────────────────────────────────────────────

def build_character(arm):
    fur = material('fur', (0.16, 0.075, 0.032), 0.0, 0.7)
    fur_light = material('fur_light', (0.52, 0.3, 0.15), 0.0, 0.7)
    hair = material('hair_gold', (0.95, 0.6, 0.06), 0.1, 0.35,
                    emission=(1.0, 0.56, 0.04), emission_strength=0.35)
    red = material('armor_red', (0.32, 0.018, 0.012), 0.35, 0.3)
    gold = material('armor_gold', (0.72, 0.42, 0.08), 1.0, 0.28)
    cloth = material('cloth', (0.11, 0.025, 0.02), 0.0, 0.8)
    boot = material('boot', (0.035, 0.025, 0.018), 0.2, 0.45)
    eye_white = material('eye_white', (0.95, 0.92, 0.85), 0.0, 0.25)
    eye_black = material('eye_black', (0.004, 0.004, 0.004), 0.0, 0.4)
    eye_amber = material('eye_amber', (0.95, 0.42, 0.02), 0.0, 0.3,
                         emission=(1.0, 0.35, 0.02), emission_strength=0.6)
    gold_gem = material('gold_gem', (0.75, 0.02, 0.01), 0.0, 0.25,
                        emission=(0.9, 0.02, 0.01), emission_strength=0.8)

    # pelvis / belt
    rigid(sphere('pelvis', (0, 0, 1.0), (0.24, 0.26, 0.2), cloth), 'hips')
    rigid(torus('belt', (0, 0, 1.06), 0.255, 0.035, gold), 'hips')
    rigid(box('belt_buckle', (0.24, 0, 1.06), (0.07, 0.1, 0.1), gold), 'hips')
    # torso: smooth-distance skinned to hips/spine/chest
    distance_weights(sphere('torso', (0, 0, 1.28), (0.31, 0.27, 0.3), cloth),
                     ['hips', 'spine', 'chest', 'neck'])
    rigid(sphere('chest_plate', (0.06, 0, 1.4), (0.24, 0.27, 0.16), red),
          'chest')
    rigid(torus('chest_trim', (0.06, 0, 1.4), 0.26, 0.018, gold,
                rot=(0, PI * 0.5, 0)), 'chest')
    rigid(cylinder('neck', (0, 0, 1.55), 0.1, 0.13, fur), 'neck')

    # head
    rigid(sphere('head', (0, 0, 1.82), (0.33, 0.31, 0.33), fur), 'head')
    rigid(sphere('muzzle', (0.27, 0, 1.77), (0.16, 0.17, 0.13), fur_light), 'head')
    rigid(sphere('nose', (0.41, 0, 1.78), (0.035, 0.05, 0.035), eye_black), 'head')
    rigid(box('mouth', (0.4, 0, 1.68), (0.02, 0.1, 0.012), eye_black), 'head')
    for sy in (-1, 1):
        rigid(sphere('ear_%d' % sy, (0, sy * 0.32, 1.86),
                     (0.055, 0.1, 0.13), fur), 'head')
        rigid(sphere('ear_in_%d' % sy, (0.02, sy * 0.34, 1.86),
                     (0.03, 0.06, 0.08), fur_light), 'head')
        rigid(sphere('eye_white_%d' % sy, (0.285, sy * 0.12, 1.87),
                     (0.05, 0.07, 0.085), eye_white), 'head')
        rigid(sphere('iris_%d' % sy, (0.33, sy * 0.12, 1.87),
                     (0.03, 0.045, 0.055), eye_amber), 'head')
        rigid(sphere('pupil_%d' % sy, (0.35, sy * 0.12, 1.87),
                     (0.016, 0.026, 0.034), eye_black), 'head')
        rigid(box('brow_%d' % sy, (0.3, sy * 0.12, 1.95),
                  (0.025, 0.09, 0.018), eye_black,
                  rot=(0, 0, sy * 0.18)), 'head')
    # golden fillet + gem
    rigid(torus('fillet', (0.1, 0, 1.87), 0.32, 0.022, gold,
                rot=(0, PI * 0.5, 0)), 'head')
    rigid(sphere('fillet_gem', (0.33, 0, 1.9), (0.045, 0.05, 0.05), gold_gem),
          'head')

    # hair: gold spikes, biased up/back
    rigid(sphere('hair_cap', (-0.04, 0, 1.92), (0.32, 0.3, 0.28), hair), 'head')
    random.seed(11)
    spike_specs = [
        (-0.1, 0.0, 0.45, 0.16), (-0.2, 0.12, 0.5, 0.14),
        (-0.2, -0.12, 0.5, 0.14), (-0.28, 0.22, 0.45, 0.12),
        (-0.28, -0.22, 0.45, 0.12), (-0.1, 0.24, 0.35, 0.12),
        (-0.1, -0.24, 0.35, 0.12), (0.02, 0.18, 0.3, 0.11),
        (0.02, -0.18, 0.3, 0.11), (-0.36, 0.0, 0.38, 0.13),
        (-0.3, 0.32, 0.3, 0.1), (-0.3, -0.32, 0.3, 0.1),
    ]
    head_c = Vector((0, 0, 1.82))
    for i, (dx, dy, length, rad) in enumerate(spike_specs):
        direction = Vector((dx, dy, 0.55)).normalized()
        base = head_c + Vector((dx * 0.8, dy * 0.8, 0.18))
        center = base + direction * (length * 0.5)
        rot = direction.to_track_quat('Z', 'Y').to_euler()
        rigid(cone('hair_spike_%d' % i, center, rad, 0.005, length, hair,
                   rot=rot, verts=10), 'head')

    # shoulders / arms
    for side, sy in (('L', 1.0), ('R', -1.0)):
        rigid(sphere('shoulder_pad.' + side, (0, sy * 0.33, 1.47),
                     (0.16, 0.14, 0.11), red), 'shoulder.' + side)
        rigid(torus('shoulder_trim.' + side, (0, sy * 0.33, 1.47),
                    0.15, 0.015, gold, rot=(PI * 0.5, 0, 0)),
              'shoulder.' + side)
        rigid(segment('upper_arm.' + side, (0, sy * 0.31, 1.43),
                      (0, sy * 0.47, 1.22), 0.085, fur), 'upper_arm.' + side)
        blend(sphere('elbow.' + side, (0, sy * 0.48, 1.22), (0.09,) * 3, fur),
              'upper_arm.' + side, 'forearm.' + side)
        rigid(segment('forearm.' + side, (0, sy * 0.48, 1.2),
                      (0, sy * 0.57, 0.98), 0.075, fur), 'forearm.' + side)
        rigid(cylinder('wrist_guard.' + side, (0, sy * 0.55, 1.03),
                       0.09, 0.08, gold,
                       rot=(0, PI * 0.5, 0)), 'forearm.' + side)
        rigid(sphere('hand.' + side, (0, sy * 0.6, 0.9),
                     (0.09, 0.08, 0.1), fur), 'hand.' + side)
        # mitten fingers
        for k in range(3):
            rigid(sphere('finger_%s_%d' % (side, k),
                         (0.04 + k * 0.035, sy * 0.6, 0.83),
                         (0.03, 0.028, 0.06), fur), 'hand.' + side)

    # legs
    for side, sy in (('L', 1.0), ('R', -1.0)):
        rigid(segment('thigh.' + side, (0, sy * 0.17, 0.98),
                      (0, sy * 0.2, 0.58), 0.11, cloth), 'thigh.' + side)
        blend(sphere('knee.' + side, (0, sy * 0.2, 0.58), (0.1,) * 3, cloth),
              'thigh.' + side, 'shin.' + side)
        rigid(sphere('knee_pad.' + side, (0.08, sy * 0.2, 0.6),
                     (0.06, 0.075, 0.075), gold), 'shin.' + side)
        rigid(segment('shin.' + side, (0, sy * 0.2, 0.56),
                      (0, sy * 0.22, 0.16), 0.09, fur), 'shin.' + side)
        rigid(box('boot.' + side, (0.1, sy * 0.22, 0.08),
                  (0.25, 0.16, 0.16), boot), 'foot.' + side)
        rigid(torus('boot_trim.' + side, (0.1, sy * 0.22, 0.16),
                    0.14, 0.015, gold, rot=(0, PI * 0.5, 0)),
              'foot.' + side)

    # tail (4 segments)
    tail_pts = [(-0.2, 0, 0.98), (-0.42, 0, 1.1), (-0.62, 0, 1.28),
                (-0.76, 0, 1.48), (-0.84, 0, 1.72)]
    for i in range(4):
        rigid(segment('tail_seg_%d' % i, tail_pts[i], tail_pts[i + 1],
                      0.05 - i * 0.006, fur), 'tail%d' % (i + 1))
        j = sphere('tail_joint_%d' % i, tail_pts[i + 1], (0.05,) * 3, fur)
        if i < 3:
            blend(j, 'tail%d' % (i + 1), 'tail%d' % (i + 2))
        else:
            rigid(j, 'tail4')
    rigid(sphere('tail_tip', (-0.86, 0, 1.76), (0.07, 0.06, 0.1), fur_light),
          'tail4')

    # back staff (rigid to chest)
    rigid(segment('staff', (-0.36, -0.24, 0.55), (-0.3, 0.24, 1.9),
                  0.025, gold), 'chest')
    rigid(cylinder('staff_cap_a', (-0.36, -0.24, 0.55), 0.045, 0.12, red,
                   rot=(0.5, 0.2, 0)), 'chest')
    rigid(cylinder('staff_cap_b', (-0.3, 0.24, 1.9), 0.045, 0.12, red,
                   rot=(0.5, 0.2, 0)), 'chest')

    body = skin_body(arm)
    return body


# ── IK ──────────────────────────────────────────────────────────────────────

def build_ik(arm):
    targets = {}
    for side in ('L', 'R'):
        hand_t = empty('ik_hand.' + side, (0.42, 0.3 if side == 'L' else -0.3, 1.05))
        elbow_t = empty('ik_elbow.' + side, (0.0, 1.0 if side == 'L' else -1.0, 1.1))
        pb = arm.pose.bones['forearm.' + side]
        c = pb.constraints.new('IK')
        c.target = hand_t
        c.pole_target = elbow_t
        c.chain_count = 2
        c.pole_angle = math.radians(-90)
        targets['hand_' + side] = hand_t
        targets['elbow_' + side] = elbow_t

        foot_t = empty('ik_foot.' + side, (0.08, 0.24 if side == 'L' else -0.24, 0.04))
        knee_t = empty('ik_knee.' + side, (0.7, 0.24 if side == 'L' else -0.24, 0.45))
        pb = arm.pose.bones['shin.' + side]
        c = pb.constraints.new('IK')
        c.target = foot_t
        c.pole_target = knee_t
        c.chain_count = 2
        c.pole_angle = math.radians(-90)
        targets['foot_' + side] = foot_t
        targets['knee_' + side] = knee_t
    return targets


# ── effects / set ───────────────────────────────────────────────────────────

def build_set():
    scene = bpy.context.scene
    world = bpy.data.worlds.new('WukongWorld')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (0.008, 0.005, 0.004, 1)
    bg.inputs['Strength'].default_value = 0.6
    scene.world = world

    floor_mat = material('floor', (0.018, 0.014, 0.012), 0.2, 0.45)
    plinth_mat = material('plinth', (0.055, 0.04, 0.03), 0.35, 0.35)
    bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
    floor = bpy.context.object
    floor.name = 'floor'
    floor.data.materials.append(floor_mat)
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=2.2, depth=0.12,
                                        location=(0, 0, 0.06))
    plinth = bpy.context.object
    plinth.name = 'plinth'
    plinth.data.materials.append(plinth_mat)
    bevel = plinth.modifiers.new('bevel', 'BEVEL')
    bevel.width = 0.03
    bevel.segments = 3
    gold = material('set_gold', (0.55, 0.32, 0.08), 1.0, 0.3)
    torus('plinth_ring', (0, 0, 0.125), 1.85, 0.012, gold)

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
        o.rotation_euler = (target - o.location).to_track_quat('-Z', 'Y').to_euler()
        return o
    area('key', (4.0, -4.0, 5.0), 800, 4.0, (1.0, 0.8, 0.55))
    area('fill', (-4.0, -3.0, 3.0), 420, 5.0, (0.5, 0.65, 1.0))
    area('rim', (-2.0, 4.0, 4.0), 750, 3.0, (1.0, 0.22, 0.06))
    area('top', (0.0, 0.0, 6.0), 240, 6.0, (1.0, 0.9, 0.7))

    # aura shells
    aura_mat = material('aura', (1.0, 0.35, 0.02), 0.0, 0.4,
                        emission=(1.0, 0.3, 0.02), emission_strength=0.25,
                        alpha=0.025)
    aura1 = sphere('aura1', (0, 0, 1.2), (0.7, 0.7, 1.0), aura_mat, seg=32,
                   rings=16)
    aura2 = sphere('aura2', (0, 0, 1.2), (0.82, 0.82, 1.12), aura_mat, seg=32,
                   rings=16)

    # ki sphere / beam
    ki_core_mat = material('ki_core', (1.0, 0.85, 0.4), 0.0, 0.2,
                           emission=(1.0, 0.85, 0.35), emission_strength=6.0)
    ki_glow_mat = material('ki_glow', (1.0, 0.4, 0.02), 0.0, 0.3,
                           emission=(1.0, 0.35, 0.02), emission_strength=3.0,
                           alpha=0.25)
    ki = sphere('ki_core', (0.5, 0, 1.2), (1.0,) * 3, ki_core_mat,
                seg=32, rings=16)
    ki_glow = sphere('ki_glow', (0.5, 0, 1.2), (1.0,) * 3, ki_glow_mat,
                     seg=32, rings=16)
    ki_light_data = bpy.data.lights.new('ki_light', 'POINT')
    ki_light_data.color = (1.0, 0.32, 0.05)
    ki_light_data.energy = 0.0
    ki_light_data.shadow_soft_size = 0.6
    ki_light = link(bpy.data.objects.new('ki_light', ki_light_data))
    ki_light.parent = ki
    beam_root = empty('beam_root', (0.5, 0, 1.3))
    beam_core = cylinder('beam_core', (4.0, 0, 0), 0.06, 8.0, ki_core_mat,
                         rot=(0, PI * 0.5, 0), verts=24)
    beam_core.parent = beam_root
    beam_glow = cylinder('beam_glow', (4.0, 0, 0), 0.15, 8.0, ki_glow_mat,
                         rot=(0, PI * 0.5, 0), verts=24)
    beam_glow.parent = beam_root
    beam_root.scale = (0.001, 0.001, 0.001)

    # sparks
    spark_mat = material('spark', (1.0, 0.5, 0.05), 0.0, 0.3,
                         emission=(1.0, 0.45, 0.03), emission_strength=3.0)
    sparks = empty('sparks', (0, 0, 1.1))
    random.seed(5)
    for i in range(26):
        a = random.uniform(0, TAU)
        r = random.uniform(0.55, 0.95)
        z = random.uniform(0.1, 1.6)
        s = random.uniform(0.008, 0.02)
        p = (math.cos(a) * r, math.sin(a) * r, z)
        sp = sphere('spark_%d' % i, p, (s,) * 3, spark_mat, seg=8, rings=4)
        sp.parent = sparks
    sparks.rotation_euler[2] = 0
    sparks.keyframe_insert('rotation_euler', index=2, frame=1)
    sparks.rotation_euler[2] = 0.9
    sparks.keyframe_insert('rotation_euler', index=2, frame=FRAMES)

    # camera rig
    cam_data = bpy.data.cameras.new('Camera')
    cam_data.lens = 50
    cam_data.dof.use_dof = True
    cam_data.dof.aperture_fstop = 2.8
    cam = link(bpy.data.objects.new('Camera', cam_data))
    orbit = empty('orbit', (0, 0, 1.15))
    focus = empty('focus', (0, 0, 1.15))
    cam.parent = orbit
    cam.location = (0.0, -6.2, 1.35)
    cam.rotation_euler = (-Vector(cam.location)).to_track_quat('-Z', 'Y').to_euler()
    cam_data.dof.focus_object = focus
    scene.camera = cam
    orbit.rotation_euler[2] = math.radians(55)
    orbit.keyframe_insert('rotation_euler', index=2, frame=1)
    orbit.rotation_euler[2] = math.radians(10)
    orbit.keyframe_insert('rotation_euler', index=2, frame=FRAMES)

    return {
        'ki': ki, 'ki_glow': ki_glow, 'ki_light': ki_light,
        'beam_root': beam_root,
        'beam_core': beam_core, 'beam_glow': beam_glow,
        'aura1': aura1, 'aura2': aura2, 'sparks': sparks,
        'cam': cam, 'orbit': orbit, 'focus': focus,
        'ki_core_mat': ki_core_mat, 'ki_glow_mat': ki_glow_mat,
        'aura_mat': aura_mat,
    }


# ── animation ───────────────────────────────────────────────────────────────

def key_loc(o, frame, loc):
    o.location = loc
    o.keyframe_insert('location', frame=frame)


def key_rot(pb, frame, euler):
    pb.rotation_mode = 'XYZ'
    pb.rotation_euler = euler
    pb.keyframe_insert('rotation_euler', frame=frame)


def animate(arm, targets, fx):
    scene = bpy.context.scene
    # hand IK targets: charge at right hip -> thrust forward
    L = targets['hand_L']
    R = targets['hand_R']
    for f, lpos, rpos in [
        (1, (0.3, 0.12, 1.14), (0.3, -0.12, 1.14)),
        (35, (0.29, 0.11, 1.13), (0.29, -0.11, 1.13)),
        (70, (0.28, 0.1, 1.12), (0.28, -0.1, 1.12)),
        (88, (0.2, 0.12, 1.08), (0.2, -0.12, 1.08)),
        (98, (0.42, 0.1, 1.3), (0.42, -0.08, 1.3)),
        (120, (0.44, 0.08, 1.31), (0.44, -0.06, 1.31)),
        (145, (0.42, 0.1, 1.3), (0.42, -0.08, 1.3)),
        (170, (0.25, 0.3, 1.05), (0.25, -0.3, 1.05)),
    ]:
        key_loc(L, f, lpos)
        key_loc(R, f, rpos)

    # feet stay planted; crouch via armature object Z
    key_loc(arm, 1, (0, 0, 0))
    key_loc(arm, 70, (0, 0, -0.1))
    key_loc(arm, 98, (0, 0, -0.02))
    key_loc(arm, 130, (0, 0, -0.04))
    key_loc(arm, 170, (0, 0, 0))

    # torso lean / twist
    key_rot(arm.pose.bones['spine'], 1, (0, 0, 0))
    key_rot(arm.pose.bones['spine'], 70, (0.12, -0.1, 0.15))
    key_rot(arm.pose.bones['spine'], 98, (-0.12, 0.0, -0.08))
    key_rot(arm.pose.bones['spine'], 145, (-0.08, 0.0, -0.06))
    key_rot(arm.pose.bones['spine'], 170, (0, 0, 0))
    key_rot(arm.pose.bones['chest'], 1, (0, 0, 0))
    key_rot(arm.pose.bones['chest'], 70, (0.08, -0.08, 0.12))
    key_rot(arm.pose.bones['chest'], 98, (-0.08, 0.0, -0.06))
    key_rot(arm.pose.bones['chest'], 145, (-0.06, 0.0, -0.04))
    key_rot(arm.pose.bones['chest'], 170, (0, 0, 0))
    key_rot(arm.pose.bones['head'], 1, (0, 0, 0))
    key_rot(arm.pose.bones['head'], 70, (0.04, 0.0, -0.04))
    key_rot(arm.pose.bones['head'], 98, (0.0, 0.0, 0.0))
    key_rot(arm.pose.bones['head'], 170, (0, 0, 0))

    # tail sway, offset to the character's right so it reads from the front 3/4
    tail_base = {'tail1': -0.55, 'tail2': -0.3, 'tail3': -0.12, 'tail4': 0.0}
    for i, name in enumerate(['tail1', 'tail2', 'tail3', 'tail4']):
        for f in range(1, FRAMES + 1, 24):
            t = (f - 1) / FPS
            key_rot(arm.pose.bones[name], f,
                    (0.12 * math.sin(t * 2.0 + i * 0.8), 0.0,
                     tail_base[name] + 0.18 * math.sin(t * 1.4 + i * 0.7)))

    # ki orb / aura
    ki = fx['ki']
    glow = fx['ki_glow']
    for f, s in ((1, 0.05), (35, 0.1), (70, 0.2), (90, 0.28),
                 (98, 0.3), (106, 0.0), (192, 0.0)):
        ki.scale = (s, s, s)
        ki.keyframe_insert('scale', frame=f)
        gs = s * 1.7
        glow.scale = (gs, gs, gs)
        glow.keyframe_insert('scale', frame=f)
    for f, loc in ((1, (0.52, 0.0, 1.22)), (70, (0.5, 0.0, 1.2)),
                   (90, (0.52, 0.0, 1.22)), (98, (0.5, 0.0, 1.3)),
                   (106, (0.52, 0.0, 1.3)), (192, (0.52, 0.0, 1.3))):
        ki.location = loc
        ki.keyframe_insert('location', frame=f)
        glow.location = loc
        glow.keyframe_insert('location', frame=f)
    for f, e in ((1, 0.0), (30, 25.0), (70, 80.0), (90, 160.0),
                 (98, 60.0), (130, 30.0), (160, 0.0), (192, 0.0)):
        fx['ki_light'].data.energy = e
        fx['ki_light'].data.keyframe_insert('energy', frame=f)

    # beam grows from the hands
    br = fx['beam_root']
    for f, sx in ((1, 0.001), (96, 0.001), (99, 0.08), (106, 0.9),
                  (140, 1.0), (160, 0.2), (175, 0.001)):
        br.scale = (sx, 0.5 + sx * 0.5, 0.5 + sx * 0.5)
        br.keyframe_insert('scale', frame=f)

    # aura pulse + fade
    for o in (fx['aura1'], fx['aura2']):
        for f, s in ((1, 0.8), (35, 0.9), (70, 1.0), (98, 1.15),
                     (130, 1.0), (170, 0.8), (192, 0.8)):
            o.scale = (s, s, s * 1.15)
            o.keyframe_insert('scale', frame=f)

    # camera shake on release, with clean anchors before/after
    cam = fx['cam']
    for f, x, z in ((1, 0.0, 1.35), (96, 0.0, 1.35), (121, 0.0, 1.35),
                    (192, 0.0, 1.35)):
        cam.location.x = x
        cam.location.z = z
        cam.keyframe_insert('location', index=0, frame=f)
        cam.keyframe_insert('location', index=2, frame=f)
    for f in range(98, 121):
        jitter = 0.035 * math.sin(f * 7.0)
        cam.location.x = jitter
        cam.location.z = 1.35 + 0.02 * math.sin(f * 9.0)
        cam.keyframe_insert('location', index=0, frame=f)
        cam.keyframe_insert('location', index=2, frame=f)

    # Bezier for smooth motion
    for action in bpy.data.actions:
        for fc in action.fcurves:
            for kp in fc.keyframe_points:
                if kp.interpolation != 'LINEAR':
                    kp.interpolation = 'BEZIER'

    # make wing/limb IK targets use bezier by default; fine


# ── render ──────────────────────────────────────────────────────────────────

def main():
    scene = reset()
    arm = build_armature()
    body = build_character(arm)
    targets = build_ik(arm)
    fx = build_set()
    animate(arm, targets, fx)

    bpy.ops.wm.save_as_mainfile(filepath=ROOT + '/wukong.blend')

    still = None
    if '--' in sys.argv:
        args = sys.argv[sys.argv.index('--') + 1:]
        if '--still' in args:
            still = int(args[args.index('--still') + 1])
    if still is not None:
        scene.frame_set(still)
        scene.render.resolution_percentage = 60
        scene.render.filepath = '/tmp/wukong_still_%03d.png' % still
        bpy.ops.render.render(write_still=True)
        print('WUKONG_STILL_OK', scene.render.filepath)
    else:
        import os
        os.makedirs(OUT, exist_ok=True)
        scene.render.filepath = OUT + '/frame_'
        bpy.ops.render.render(animation=True)
        print('WUKONG_ANIM_OK', OUT)


if __name__ == '__main__':
    main()
