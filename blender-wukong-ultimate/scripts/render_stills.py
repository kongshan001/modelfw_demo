"""Render 1080p key art for 齐天大圣 · 极意 with Blender 3.4.1 EEVEE.

    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_stills.py
    /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/render_stills.py -- --quick
"""

import bpy
import math
import random
import sys
from mathutils import Vector

ROOT = "/Users/ks_128/Documents/modelfw_demo/blender-wukong-ultimate"
BLEND = ROOT + "/wukong_ultimate.blend"
PI = math.pi
TAU = PI * 2.0
random.seed(7)


def link(o):
    bpy.context.collection.objects.link(o)
    return o


def node(mat, kind):
    return next(n for n in mat.node_tree.nodes if n.type == kind)


def set_in(node_, names, value):
    for n in names:
        if n in node_.inputs:
            node_.inputs[n].default_value = value
            return


def material(name, color, metallic=0.0, rough=0.5, emission=None, emit=0.0,
             alpha=1.0, additive=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = node(m, 'BSDF_PRINCIPLED')
    set_in(b, ['Base Color'], (*color, 1.0))
    set_in(b, ['Metallic'], metallic)
    set_in(b, ['Roughness'], rough)
    if emission is not None:
        set_in(b, ['Emission', 'Emission Color'], (*emission, 1.0))
        set_in(b, ['Emission Strength'], emit)
    if alpha < 1.0:
        set_in(b, ['Alpha'], alpha)
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
        m.show_transparent_back = False
    if additive:
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
    return m


def aura_material(name, color, strength, rim=0.55):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    mix = nt.nodes.new('ShaderNodeMixShader')
    trans = nt.nodes.new('ShaderNodeBsdfTransparent')
    emit = nt.nodes.new('ShaderNodeEmission')
    emit.inputs['Color'].default_value = (*color, 1.0)
    emit.inputs['Strength'].default_value = strength
    layer = nt.nodes.new('ShaderNodeLayerWeight')
    layer.inputs['Blend'].default_value = rim
    noise = nt.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = 6.0
    noise.inputs['Detail'].default_value = 4.0
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.28
    ramp.color_ramp.elements[0].color = (0.0, 0.0, 0.0, 1.0)
    ramp.color_ramp.elements[1].position = 0.92
    ramp.color_ramp.elements[1].color = (1.0, 1.0, 1.0, 1.0)
    mul = nt.nodes.new('ShaderNodeMath')
    mul.operation = 'MULTIPLY'
    nt.links.new(layer.outputs['Facing'], mul.inputs[0])
    nt.links.new(noise.outputs['Fac'], mul.inputs[1])
    nt.links.new(mul.outputs[0], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], mix.inputs['Fac'])
    nt.links.new(trans.outputs['BSDF'], mix.inputs[1])
    nt.links.new(emit.outputs['Emission'], mix.inputs[2])
    nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    m.blend_method = 'BLEND'
    m.shadow_method = 'NONE'
    return m


def rock(name, loc, scale, mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0,
                                          location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    o.rotation_euler = (random.uniform(0, TAU), random.uniform(0, TAU),
                        random.uniform(0, TAU))
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def sphere(name, loc, scale, mat, seg=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def glow_material(name, color, strength, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    emit = nt.nodes.new('ShaderNodeEmission')
    emit.inputs['Color'].default_value = (*color, 1.0)
    emit.inputs['Strength'].default_value = strength
    nt.links.new(emit.outputs['Emission'], out.inputs['Surface'])
    if alpha < 1.0:
        mix = nt.nodes.new('ShaderNodeMixShader')
        trans = nt.nodes.new('ShaderNodeBsdfTransparent')
        nt.links.new(trans.outputs['BSDF'], mix.inputs[1])
        nt.links.new(emit.outputs['Emission'], mix.inputs[2])
        mix.inputs['Fac'].default_value = alpha
        nt.links.new(mix.outputs['Shader'], out.inputs['Surface'])
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
    return m


def setup_render(scene, quick):
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1920 if not quick else 960
    scene.render.resolution_y = 1080 if not quick else 540
    scene.render.resolution_percentage = 100
    scene.eevee.taa_render_samples = 40 if not quick else 10
    scene.eevee.use_bloom = True
    scene.eevee.bloom_intensity = 0.05
    scene.eevee.bloom_threshold = 1.0
    scene.eevee.bloom_radius = 7.5
    scene.eevee.use_gtao = True
    scene.eevee.gtao_distance = 0.35
    scene.eevee.use_ssr = True
    scene.eevee.use_ssr_refraction = True
    scene.eevee.use_motion_blur = False
    scene.view_settings.view_transform = 'Filmic'
    scene.view_settings.look = 'High Contrast'
    scene.view_settings.exposure = -0.10
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False


def setup_world(scene):
    world = bpy.data.worlds.new('UltWorld')
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputWorld')
    bg = nt.nodes.new('ShaderNodeBackground')
    grad = nt.nodes.new('ShaderNodeTexGradient')
    grad.gradient_type = 'LINEAR'
    texco = nt.nodes.new('ShaderNodeTexCoord')
    mapping = nt.nodes.new('ShaderNodeMapping')
    mapping.inputs['Rotation'].default_value = (0, -PI * 0.5, 0)
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.30
    ramp.color_ramp.elements[0].color = (0.008, 0.012, 0.032, 1.0)
    ramp.color_ramp.elements[1].position = 0.85
    ramp.color_ramp.elements[1].color = (0.030, 0.055, 0.12, 1.0)
    nt.links.new(texco.outputs['Generated'], mapping.inputs['Vector'])
    nt.links.new(mapping.outputs['Vector'], grad.inputs['Vector'])
    nt.links.new(grad.outputs['Fac'], ramp.inputs['Fac'])
    nt.links.new(ramp.outputs['Color'], bg.inputs['Color'])
    bg.inputs['Strength'].default_value = 0.55
    nt.links.new(bg.outputs['Background'], out.inputs['Surface'])
    scene.world = world


def build_stage():
    stone = material('set_stone', (0.022, 0.025, 0.038), 0.15, 0.52)
    stone2 = material('set_stone_dark', (0.010, 0.012, 0.020), 0.2, 0.6)
    gold = material('set_gold', (0.72, 0.44, 0.10), 1.0, 0.28)
    rune = material('set_rune', (0.10, 0.35, 0.9), 0.0, 0.35,
                    emission=(0.18, 0.45, 1.0), emit=1.2)
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=3.1, depth=0.18,
                                        location=(0, 0, -0.09))
    plinth = bpy.context.object
    plinth.name = 'art_plinth'
    plinth.data.materials.append(stone)
    bevel = plinth.modifiers.new('bev', 'BEVEL')
    bevel.width = 0.035
    bevel.segments = 3
    for i, r in enumerate((2.55, 2.85)):
        bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=0.012,
                                         major_segments=96,
                                         minor_segments=8,
                                         location=(0, 0, 0.004))
        ring = bpy.context.object
        ring.name = 'art_ring_%d' % i
        ring.data.materials.append(gold if i == 0 else rune)
    # broken pillars around the platform
    for i, (ang, rad, h, tilt) in enumerate([
            (1.9, 10.0, 3.2, 0.05), (2.5, 12.0, 4.6, -0.04),
            (3.2, 9.4, 2.2, 0.07), (0.35, 11.5, 3.8, 0.03)]):
        p = Vector((math.cos(ang) * rad, math.sin(ang) * rad, h * 0.5 - 0.1))
        bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.38,
                                            depth=h, location=p)
        col = bpy.context.object
        col.name = 'art_pillar_%d' % i
        col.rotation_euler = (tilt, tilt * 0.6, ang)
        col.data.materials.append(stone2)
        bpy.ops.object.transform_apply(location=False, rotation=True,
                                       scale=True)
    # broken arch directly behind the hero (camera looks toward -X,+Y)
    for sx, sy, h in ((-4.6, 1.6, 3.7), (-3.4, 4.6, 3.2)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.28,
                                            depth=h,
                                            location=(sx, sy, h * 0.5 - 0.1))
        col = bpy.context.object
        col.data.materials.append(stone)
        col.rotation_euler = (0.04, -0.03, 0.2)
        bpy.ops.object.transform_apply(location=False, rotation=True,
                                       scale=True)
    lint = bpy.ops.mesh.primitive_cube_add(size=1.0,
                                           location=(-4.0, 3.1, 3.5))
    larch = bpy.context.object
    larch.scale = (3.2, 0.55, 0.42)
    larch.rotation_euler = (0.0, 0.10, -0.62)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    larch.data.materials.append(stone)
    for k in range(5):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.22,
                                              location=(-4.8 + 0.42 * k, 3.0,
                                                        3.35))
        r = bpy.context.object
        r.scale = (0.9, 0.9, 0.22)
        r.data.materials.append(rune)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(-4.0, 2.55, 3.72))
    strip = bpy.context.object
    strip.scale = (3.0, 0.035, 0.04)
    strip.rotation_euler = (0.0, 0.0, -0.62)
    strip.data.materials.append(rune)
    # distant mountains
    for i in range(9):
        ang = random.uniform(0, TAU)
        rad = random.uniform(12, 24)
        h = random.uniform(2.0, 7.0)
        bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=random.uniform(3, 6),
                                        radius2=0.0, depth=h,
                                        location=(math.cos(ang) * rad,
                                                  math.sin(ang) * rad,
                                                  h * 0.5 - 0.2))
        m = bpy.context.object
        m.data.materials.append(stone2)
    # moon
    glow = glow_material('moon_glow', (0.68, 0.80, 1.0), 1.0, alpha=0.22)
    sphere('art_moon', (-10.5, 5.2, 3.6), (1.0, 1.0, 1.0), glow, 32, 20)
    # stars
    star = glow_material('star', (0.75, 0.88, 1.0), 8.0)
    for i in range(36):
        a = random.uniform(0, TAU)
        r = random.uniform(11, 19)
        z = random.uniform(2.0, 8.5)
        s = random.uniform(0.012, 0.035)
        sphere('star_%d' % i, (math.cos(a) * r, math.sin(a) * r, z),
               (s, s, s), star, 8, 6)
    return {'stone': stone, 'gold': gold, 'rune': rune}


def build_lights():
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

    area('art_key', (3.0, -3.6, 4.4), 1050, 2.2, (1.0, 0.80, 0.58))
    area('art_fill', (-4.5, -3.2, 2.4), 160, 4.5, (0.38, 0.58, 1.0))
    area('art_rim', (-3.6, 4.2, 4.6), 3000, 2.0, (0.55, 0.80, 1.0))
    area('art_top', (0, 0, 6.5), 220, 5.0, (1.0, 0.92, 0.78))
    bounce = bpy.data.lights.new('art_bounce', 'POINT')
    bounce.energy = 140
    bounce.color = (1.0, 0.62, 0.34)
    bounce.shadow_soft_size = 1.0
    bl = link(bpy.data.objects.new('art_bounce', bounce))
    bl.location = (1.6, -0.6, 0.25)


def build_camera(name, loc, look, lens, dof=True):
    data = bpy.data.cameras.new(name)
    data.lens = lens
    cam = bpy.data.objects.new(name, data)
    link(cam)
    cam.location = loc
    cam.rotation_euler = (Vector(look) - Vector(loc)).to_track_quat(
        '-Z', 'Y').to_euler()
    if dof:
        data.dof.use_dof = True
        data.dof.aperture_fstop = 3.2
        focus = bpy.data.objects.new('focus_' + name, None)
        focus.location = look
        link(focus)
        data.dof.focus_object = focus
    return cam


def add_wisps(center=(0, 0, 1.1), count=26, radius=0.72, height=1.7,
              strength=3.5, length=0.14):
    m = glow_material('wisp_glow', (0.62, 0.82, 1.0), max(1.0, strength * 0.7))
    for i in range(count):
        a = random.uniform(0, TAU)
        r = radius * random.uniform(0.35, 1.05)
        z = center[2] + random.uniform(-height * 0.45, height * 0.5)
        s = random.uniform(0.006, 0.016)
        sphere('aura_mote_%d' % i,
               (center[0] + math.cos(a) * r,
                center[1] + math.sin(a) * r * 0.8, z),
               (s, s, s * random.uniform(1.0, 2.2)), m, 8, 6)
    data = bpy.data.lights.new('aura_light', 'POINT')
    data.energy = 70 if strength < 3 else 150
    data.color = (0.55, 0.78, 1.0)
    data.shadow_soft_size = 0.6
    l = link(bpy.data.objects.new('aura_light', data))
    l.location = (0.0, 0.0, 1.2)
    return m


def add_rocks(stone, count=11, radius=1.15, zmin=0.25, zmax=2.3,
              size=0.12, emissive=False):
    rocks = []
    for i in range(count):
        a = (i / count) * TAU + random.uniform(-0.2, 0.2)
        r = radius + random.uniform(-0.25, 0.35)
        z = random.uniform(zmin, zmax)
        s = random.uniform(size * 0.45, size)
        o = rock('float_rock_%d' % i,
                 (math.cos(a) * r * 0.75, math.sin(a) * r, z),
                 (s * random.uniform(0.7, 1.4), s, s * random.uniform(0.7, 1.3)),
                 stone)
        rocks.append(o)
    return rocks


def add_orb(center, size, warm=False):
    core = glow_material('orb_core', (1.0, 0.96, 0.86) if not warm else
                         (1.0, 0.82, 0.55), 4.0)
    glow = aura_material('orb_glow_mat', (0.55, 0.78, 1.0), 1.2, 0.62)
    a = sphere('orb_core_mesh', center, (size, size, size), core, 32, 20)
    b = sphere('orb_glow_mesh', center, (size * 1.8, size * 1.8, size * 1.8),
               glow, 32, 20)
    data = bpy.data.lights.new('orb_light', 'POINT')
    data.energy = 350
    data.color = (0.55, 0.78, 1.0)
    data.shadow_soft_size = 0.45
    l = link(bpy.data.objects.new('orb_light', data))
    l.location = center
    ring = aura_material('orb_ring_mat', (0.8, 0.92, 1.0), 0.8, 0.6)
    sphere('orb_ring', center, (size * 2.5, size * 2.5, size * 0.35), ring,
           32, 16)
    return a, b, l


def add_sparks(center, count=26, spread=0.8, size=0.02):
    m = glow_material('spark', (0.9, 0.96, 1.0), 5.0)
    for i in range(count):
        a = random.uniform(0, TAU)
        r = random.uniform(0.1, spread)
        z = random.uniform(-spread * 0.6, spread)
        s = random.uniform(size * 0.5, size)
        sphere('spark_%d' % i,
               (center[0] + math.cos(a) * r,
                center[1] + math.sin(a) * r * 0.8,
                center[2] + z),
               (s, s, s), m, 8, 6)


def add_beam(start, end, radius=0.05):
    a = Vector(start)
    b = Vector(end)
    d = b - a
    mid = (a + b) * 0.5
    rot = d.to_track_quat('Z', 'Y').to_euler()
    core = glow_material('beam_core', (1.0, 0.97, 0.88), 4.0)
    midm = aura_material('beam_glow_mat', (0.30, 0.62, 1.0), 0.75, 0.62)
    outer = aura_material('beam_outer_mat', (0.40, 0.72, 1.0), 0.18, 0.35)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=radius,
                                        depth=d.length, location=mid,
                                        rotation=rot)
    o = bpy.context.object
    o.name = 'art_beam_core'
    o.data.materials.append(core)
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=radius * 2.2,
                                    radius2=radius * 4.2, depth=d.length,
                                    location=mid, rotation=rot)
    g = bpy.context.object
    g.name = 'art_beam_glow'
    g.data.materials.append(midm)
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=radius * 4.2,
                                    radius2=radius * 8.0, depth=d.length,
                                    location=mid, rotation=rot)
    h = bpy.context.object
    h.name = 'art_beam_outer'
    h.data.materials.append(outer)
    data = bpy.data.lights.new('beam_light', 'POINT')
    data.energy = 260
    data.color = (0.55, 0.8, 1.0)
    data.shadow_soft_size = 0.5
    l = link(bpy.data.objects.new('beam_light', data))
    l.location = start
    sphere('muzzle_flare', start, (0.075, 0.075, 0.075), core, 16, 10)
    return o, g


def build_dummy(stone, x=2.8):
    base = Vector((x, 0.0, 0.0))
    dark = material('dummy_stone', (0.016, 0.018, 0.026), 0.3, 0.48)
    gold = material('dummy_gold', (0.58, 0.34, 0.07), 1.0, 0.3)
    crack = glow_material('dummy_core', (1.0, 0.42, 0.10), 2.5)

    def box(name, loc, scale, mat, rot=(0, 0, 0), bev=0.02):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
        o = bpy.context.object
        o.name = name
        o.scale = scale
        bpy.ops.object.transform_apply(location=True, rotation=True,
                                       scale=True)
        b = o.modifiers.new('bev', 'BEVEL')
        b.width = bev
        b.segments = 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
        o.data.materials.append(mat)
        return o

    # squat stone sentinel on a plinth
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.55, depth=0.16,
                                        location=base + Vector((0, 0, 0.08)))
    ped = bpy.context.object
    ped.data.materials.append(dark)
    torso = box('dummy_torso', base + Vector((0.0, 0, 1.02)),
                (0.62, 0.48, 0.74), dark, (0, 0.06, 0), 0.04)
    chest = box('dummy_chest', base + Vector((0.22, 0, 1.16)),
                (0.12, 0.42, 0.36), dark, (0, 0.1, 0), 0.03)
    head = box('dummy_head', base + Vector((0.02, 0, 1.58)),
               (0.36, 0.34, 0.30), dark, (0, 0.05, 0), 0.035)
    visor = box('dummy_visor', base + Vector((0.20, 0, 1.60)),
                (0.06, 0.26, 0.10), dark, (0, 0.1, 0), 0.02)
    eye = box('dummy_eye', base + Vector((0.245, 0, 1.61)),
              (0.02, 0.19, 0.035), crack, (0, 0.1, 0), 0.005)
    for sy in (1, -1):
        box('dummy_shoulder_%d' % sy, base + Vector((0.0, sy * 0.42, 1.28)),
            (0.30, 0.22, 0.22), dark, (0, 0.05, 0), 0.03)
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.11,
                                            depth=0.5,
                                            location=base + Vector((0.02, sy * 0.42, 0.94)))
        arm = bpy.context.object
        arm.rotation_euler = (0, 0.12, 0)
        arm.data.materials.append(dark)
        box('dummy_fist_%d' % sy, base + Vector((0.05, sy * 0.43, 0.66)),
            (0.22, 0.20, 0.22), dark, (0, 0.05, 0), 0.03)
    for k in range(2):
        bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.13,
                                            depth=0.6,
                                            location=base + Vector((0, (k - 0.5) * 0.28, 0.42)))
        leg = bpy.context.object
        leg.data.materials.append(dark)
    # gold band + chest rune
    bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.024,
                                     major_segments=32, minor_segments=8,
                                     location=base + Vector((0, 0, 1.37)))
    band = bpy.context.object
    band.rotation_euler = (PI * 0.5, 0, 0)
    band.scale = (1.0, 0.8, 1.0)
    band.data.materials.append(gold)
    for k in range(3):
        box('dummy_crack_%d' % k, base + Vector((0.33, (k - 1) * 0.10, 1.08 + k * 0.06)),
            (0.016, 0.03, 0.12 + 0.03 * k), crack, (0.2, 0.1, 0.3), 0.002)
    # impact flare at the chest
    impact = base + Vector((0.45, 0, 1.20))
    icore = glow_material('impact_core', (1.0, 0.85, 0.58), 4.0)
    sphere('impact_core', impact, (0.18, 0.18, 0.18), icore, 24, 16)
    halo = aura_material('impact_halo_mat', (1.0, 0.52, 0.16), 0.8, 0.55)
    sphere('impact_halo', impact, (0.52, 0.52, 0.52), halo, 32, 20)
    # orange shock rings
    ringm = glow_material('shock_ring', (1.0, 0.55, 0.18), 2.0)
    for rr in (0.38, 0.62):
        bpy.ops.mesh.primitive_torus_add(major_radius=rr, minor_radius=0.012,
                                         major_segments=48, minor_segments=8,
                                         location=impact,
                                         rotation=(0, PI * 0.05, 0))
        ring = bpy.context.object
        ring.data.materials.append(ringm)
    # debris chips
    for i in range(10):
        a = random.uniform(0, TAU)
        r = random.uniform(0.25, 0.8)
        s = random.uniform(0.02, 0.055)
        rock('impact_chip_%d' % i,
             (impact.x + math.cos(a) * r, impact.y + math.sin(a) * r,
              impact.z + random.uniform(-0.45, 0.3)),
             (s, s, s), dark)
    add_sparks(impact, count=18, spread=0.65, size=0.016)
    data = bpy.data.lights.new('impact_light', 'POINT')
    data.energy = 600
    data.color = (1.0, 0.55, 0.22)
    data.shadow_soft_size = 0.4
    l = link(bpy.data.objects.new('impact_light', data))
    l.location = impact
    return base


def set_action(arm, name, frame):
    arm.animation_data.action = bpy.data.actions[name]
    bpy.context.scene.frame_set(frame)


def clear_fx():
    for name in list(bpy.data.objects.keys()):
        if name.startswith(('aura', 'float_rock', 'orb_', 'spark_',
                            'beam', 'impact', 'dummy')) or name in (
                                'orb_light', 'beam_light', 'impact_light',
                                'aura_light'):
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)


def main():
    quick = '--quick' in sys.argv
    bpy.ops.wm.open_mainfile(filepath=BLEND)
    scene = bpy.context.scene
    setup_render(scene, quick)
    setup_world(scene)
    stage = build_stage()
    build_lights()
    arm = bpy.data.objects['WukongUltimateRig']
    # hide the preview stage pieces from the old file
    for name in ('stage_plinth', 'stage_ring'):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    for name in ('key', 'fill', 'rim', 'top'):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)

    shots = [
        ('poster_front', 'Idle', 25, (5.8, -2.2, 1.48),
         (0.0, 0, 1.06), 55, 0.8, 4, 0.045, False),
        ('poster_charge', 'Charge', 17, (4.4, -2.6, 1.02),
         (0.03, 0, 1.12), 52, 2.4, 8, 0.060, True),
        ('poster_cast', 'Cast', 14, (3.4, -5.2, 1.55),
         (1.25, 0, 1.12), 42, 1.2, 4, 0.050, True),
    ]
    if not quick:
        scene.eevee.taa_render_samples = 40

    for name, action, frame, cam_loc, look, lens, aura_s, rock_n, rock_size, cast in shots:
        clear_fx()
        set_action(arm, action, frame)
        add_wisps(center=(0, 0, 1.1), count=6 if action == 'Idle' else (26 if action == 'Charge' else 10),
                  radius=0.62, height=1.35, strength=aura_s, length=0.13)
        add_rocks(stage['stone'], count=rock_n, radius=1.15,
                  zmin=0.2, zmax=2.05, size=rock_size)
        if action == 'Charge':
            add_orb((0.34, 0.0, 1.16), 0.10)
            add_sparks((0.34, 0.0, 1.16), 20, 0.55, 0.018)
        if action == 'Cast':
            add_beam((0.62, 0.0, 1.27), (2.9, 0.0, 1.24), 0.045)
            base = build_dummy(stage['stone'], x=2.8)
        cam = build_camera('shot_cam', cam_loc, look, lens)
        if action == 'Cast':
            cam.data.dof.aperture_fstop = 6.0
        scene.camera = cam
        scene.render.filepath = ROOT + '/docs/%s%s.png' % (
            name, '_quick' if quick else '')
        bpy.ops.render.render(write_still=True)
        print('STILL_OK', scene.render.filepath)
        bpy.data.objects.remove(cam, do_unlink=True)

if __name__ == '__main__':
    main()
