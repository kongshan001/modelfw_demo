"""blender_anime toolkit — reusable, original cute-anime character helpers.

Runs inside Blender 3.4.1 headless (EEVEE Legacy).  Design goals:
  * quad-friendly procedural geometry (no voxel-remesh as final topology);
  * eyes with real volume + surface-conformed iris (fixes T-029 side-view decal);
  * hair built from layered closed blade meshes + ponytail bone chain;
  * toon/cel Shader-to-RGB materials + inverted-hull outline;
  * fail-closed manifest for tools/blender_anime/validate.py.

Everything in this module is original: no external models, textures or IP art.
Only this module writes bpy data; build_character.py orchestrates it.
"""

import json
import math
import os
import time

import bpy
import bmesh
import numpy as np
from mathutils import Vector

TAU = math.pi * 2.0
PI = math.pi

# module state --------------------------------------------------------------
PARTS = []
BONES = {}
ARM = None
TEX = {}
EXPORT_SPEC = {}
DECAL_MATS = {
    'EyeWhite', 'EyeIris', 'Pupil', 'EyeHighlight', 'Lash', 'Brow', 'Blush',
    'Mouth', 'SkinShadow', 'NoseLine', 'SkinDecal',
    'TrimCream', 'TrimRibbon',
}


def srgb(hexstr):
    h = hexstr.lstrip('#')
    rgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                 for c in rgb)


def hx(hexstr):
    h = hexstr.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def clamp(v, a=0.0, b=1.0):
    return max(a, min(b, v))


def smoothstep(t):
    t = clamp(t)
    return t * t * (3.0 - 2.0 * t)


def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat(
        '-Z', 'Y').to_euler()


def reset_scene(preset):
    global PARTS, BONES, ARM, TEX, EXPORT_SPEC
    PARTS, BONES, TEX, EXPORT_SPEC = [], {}, {}, {}
    ARM = None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = preset.get('render', {}).get('engine', 'BLENDER_EEVEE')
    if sc.render.engine == 'BLENDER_EEVEE':
        sc.eevee.taa_render_samples = preset.get('render', {}).get(
            'samples', 32)
        sc.eevee.use_gtao = True
        sc.eevee.gtao_distance = 0.16
        sc.eevee.use_bloom = True
        sc.eevee.bloom_intensity = 0.018
        sc.eevee.bloom_threshold = 1.0
        sc.eevee.bloom_radius = 4.0
    res = preset.get('render', {}).get('resolution', [1440, 1800])
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = 'PNG'
    sc.render.film_transparent = False
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.view_settings.exposure = 0.0
    sc.render.fps = 24
    return sc


def link(o):
    bpy.context.collection.objects.link(o)
    return o


def register(o, role='part'):
    o['role'] = role
    PARTS.append(o)
    return o


def apply_mod(o, mod):
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def solidify(o, thickness):
    m = o.modifiers.new('solid', 'SOLIDIFY')
    m.thickness = thickness
    m.offset = 0.0
    m.use_rim = True
    apply_mod(o, m)
    return o


# --------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------

def _base_out(nt):
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (420, 0)
    return nodes, links, out


def _set(node, names, value):
    for n in names:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


def mat_toon(name, hexcol=None, img=None, low=0.56, mid=0.82,
             bands=(0.0, 0.34, 0.70), backface=False):
    """EEVEE cel material: Diffuse → Shader-to-RGB → 3-band ramp × base color."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links, out = _base_out(m.node_tree)
    diff = nodes.new('ShaderNodeBsdfDiffuse')
    diff.location = (-520, 260)
    diff.inputs['Color'].default_value = (1, 1, 1, 1)
    s2r = nodes.new('ShaderNodeShaderToRGB')
    s2r.location = (-330, 260)
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.location = (-140, 260)
    cr = ramp.color_ramp
    cr.interpolation = 'CONSTANT'
    cr.elements[0].position = bands[0]
    cr.elements[0].color = (low * 0.88, low * 0.94, low, 1)
    cr.elements[1].position = bands[1]
    cr.elements[1].color = (mid * 0.96, mid * 0.98, mid, 1)
    e = cr.elements.new(bands[2])
    e.color = (1, 1, 1, 1)
    mix = nodes.new('ShaderNodeMixRGB')
    mix.blend_type = 'MULTIPLY'
    mix.location = (100, 180)
    mix.inputs['Fac'].default_value = 1.0
    emit = nodes.new('ShaderNodeEmission')
    emit.location = (260, 120)
    emit.inputs['Strength'].default_value = 1.0
    links.new(diff.outputs['BSDF'], s2r.inputs['Shader'])
    links.new(s2r.outputs['Color'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], mix.inputs['Color1'])
    if img is not None:
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = img
        tex.location = (-330, -120)
        links.new(tex.outputs['Color'], mix.inputs['Color2'])
        EXPORT_SPEC[name] = ('tex', img)
    else:
        rgb = srgb(hexcol)
        mix.inputs['Color2'].default_value = (*rgb, 1)
        EXPORT_SPEC[name] = ('color', rgb)
    m.diffuse_color = (*srgb(hexcol or '#808080'), 1)
    links.new(mix.outputs['Color'], emit.inputs['Color'])
    links.new(emit.outputs['Emission'], out.inputs['Surface'])
    m.use_backface_culling = backface
    return m


def mat_flat(name, hexcol, rough=0.9, backface=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links, out = _base_out(m.node_tree)
    b = nodes.new('ShaderNodeBsdfPrincipled')
    b.location = (200, 0)
    rgb = srgb(hexcol)
    _set(b, ['Base Color'], (*rgb, 1))
    _set(b, ['Roughness'], rough)
    _set(b, ['Specular'], 0.15)
    links.new(b.outputs['BSDF'], out.inputs['Surface'])
    m.diffuse_color = (*rgb, 1)
    m.use_backface_culling = backface
    EXPORT_SPEC[name] = ('color', rgb)
    return m


def mat_emit(name, hexcol, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links, out = _base_out(m.node_tree)
    emit = nodes.new('ShaderNodeEmission')
    emit.location = (200, 0)
    emit.inputs['Color'].default_value = (*srgb(hexcol), 1)
    emit.inputs['Strength'].default_value = strength
    links.new(emit.outputs['Emission'], out.inputs['Surface'])
    m.diffuse_color = (*srgb(hexcol), 1)
    EXPORT_SPEC[name] = ('color', srgb(hexcol))
    return m


def mat_emit_tex(name, img, strength=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links, out = _base_out(m.node_tree)
    tex = nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.location = (-200, 0)
    emit = nodes.new('ShaderNodeEmission')
    emit.location = (120, 0)
    emit.inputs['Strength'].default_value = strength
    links.new(tex.outputs['Color'], emit.inputs['Color'])
    links.new(emit.outputs['Emission'], out.inputs['Surface'])
    m.diffuse_color = (0.8, 0.8, 0.8, 1)
    EXPORT_SPEC[name] = ('tex', img)
    return m


# --------------------------------------------------------------------------
# procedural textures (512²; embedded into GLB)
# --------------------------------------------------------------------------

def _save_image(name, rgba, out_dir, alpha=False):
    h, w = rgba.shape[:2]
    img = bpy.data.images.new(name, width=w, height=h, alpha=alpha)
    img.pixels.foreach_set(np.ascontiguousarray(rgba).ravel())
    img.update()
    path = os.path.join(out_dir, name + '.png')
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    img.pack()
    TEX[name] = img
    return img


def _uv_grid(size):
    u = (np.arange(size, dtype=np.float32) + 0.5) / size
    v = (np.arange(size, dtype=np.float32) + 0.5) / size
    return np.meshgrid(u, v)  # uu, vv each (size,size)


def build_textures(out_dir, palette, design, size=512):
    os.makedirs(out_dir, exist_ok=True)
    uu, vv = _uv_grid(size)
    hair = hx(palette['hair'])
    hair_hi = hx(palette.get('hair_light', palette['hair']))
    dress = hx(palette['dress'])
    dress_dk = hx(palette.get('dress_dark', palette['dress']))
    cream = hx(palette['cream'])
    ribbon = hx(palette['ribbon'])
    leaf = hx(palette['leaf'])
    iris = hx(palette['iris'])
    iris_dark = hx(palette.get('iris_dark', palette['iris']))
    iris_light = tuple(min(1.0, c * 1.28 + 0.08) for c in iris)

    # hair: fine longitudinal strands + soft sheen bands
    strand = 0.5 + 0.5 * np.sin(uu * 31.0 + vv * 149.0)
    strand2 = 0.5 + 0.5 * np.sin(uu * 73.0 - vv * 61.0 + 1.2)
    strand3 = 0.5 + 0.5 * np.sin(uu * 17.0 + vv * 271.0 + 2.1)
    sheen = 0.5 + 0.5 * np.sin(uu * 9.0 + 0.6)
    t = np.clip(0.42 * strand + 0.36 * strand2 + 0.22 * strand3, 0, 1)
    t = t * 0.86 + sheen * 0.14
    hair_rgb = np.zeros((size, size, 3), np.float32)
    for k in range(3):
        hair_rgb[..., k] = hair[k] * (1 - 0.20 * t) + hair_hi[k] * 0.20 * t
    # gingham / small peach lattice on the dress
    gx = (np.sin(uu * PI * 22.0) > 0.72).astype(np.float32)
    gy = (np.sin(vv * PI * 22.0) > 0.72).astype(np.float32)
    lattice = np.clip(gx + gy, 0, 1) * 0.35
    weave = 0.055 * np.sin(uu * 420.0) * np.sin(vv * 420.0)
    dress_rgb = np.zeros((size, size, 3), np.float32)
    for k in range(3):
        base = dress[k] * (1 - lattice * 0.55) + ribbon[k] * lattice * 0.55
        base = base * (0.96 + weave)
        dress_rgb[..., k] = np.clip(base, 0, 1)
    # cream apron with a little peach sprig embroidery (original motif)
    apron_rgb = np.zeros((size, size, 3), np.float32)
    apron_weave = 0.035 * np.sin(uu * 520.0) * np.sin(vv * 520.0)
    motif = np.zeros((size, size), np.float32)
    for cx, cy, r in ((0.5, 0.22, 0.085), (0.44, 0.30, 0.050),
                      (0.56, 0.30, 0.050), (0.50, 0.36, 0.042)):
        d = np.hypot(uu - cx, vv - cy)
        motif = np.maximum(motif, np.clip((r - d) / (r * 0.35), 0, 1))
    stem = (np.abs(uu - 0.5) < 0.006) & (vv > 0.34) & (vv < 0.55)
    leaf_mask = (np.hypot((uu - 0.44) / 0.03, (vv - 0.42) / 0.015) < 1) | \
                (np.hypot((uu - 0.56) / 0.03, (vv - 0.44) / 0.015) < 1)
    for k in range(3):
        apron_rgb[..., k] = cream[k] * (0.97 + apron_weave)
    for k in range(3):
        apron_rgb[..., k] = (apron_rgb[..., k] * (1 - 0.62 * motif)
                             + hx(palette.get('peach', palette['ribbon']))[k] * 0.62 * motif)
        apron_rgb[..., k] = np.where(stem, leaf[k] * 0.9,
                                     apron_rgb[..., k])
        apron_rgb[..., k] = np.where(leaf_mask,
                                     leaf[k] * 0.92,
                                     apron_rgb[..., k])
    # iris: layered radial fibres, limbal ring, lower light pool
    dx = (uu - 0.5) * 2.0
    dy = (vv - 0.5) * 2.0
    r = np.clip(np.hypot(dx, dy), 0, 1)
    ang = np.arctan2(dy, dx)
    fibre = 0.5 + 0.5 * np.sin(ang * 28.0 + r * 17.0)
    tt = np.clip((r - 0.16) / 0.82, 0, 1)
    iris_rgb = np.zeros((size, size, 3), np.float32)
    for k in range(3):
        iris_rgb[..., k] = iris_light[k] * (1 - tt) + iris[k] * tt
        iris_rgb[..., k] *= (0.88 + 0.20 * fibre)
        iris_rgb[..., k] += np.clip((-dy - 0.15) * 0.20, 0, 0.18) * \
            (0.6 + 0.4 * fibre)
        iris_rgb[..., k] = np.where(r > 0.84, iris_dark[k] * 0.8,
                                    iris_rgb[..., k])
        iris_rgb[..., k] = np.where(r < 0.26, iris_dark[k] * 0.55,
                                    iris_rgb[..., k])
        iris_rgb[..., k] = np.where(r > 0.985, 0.03, iris_rgb[..., k])
        iris_rgb[..., k] = np.clip(iris_rgb[..., k], 0, 1)
    # soft contact shadow (alpha)
    d2 = np.clip(np.hypot(dx, dy), 0, 1)
    alpha = np.clip(1.0 - d2, 0, 1) ** 1.8 * 0.68
    shadow = np.zeros((size, size, 4), np.float32)
    shadow[..., 0:3] = (0.07, 0.05, 0.045)
    shadow[..., 3] = alpha
    # backdrop vertical gradient
    top = hx('#E9E3F1')
    bottom = hx('#F7E8D6')
    backdrop = np.zeros((size, size, 4), np.float32)
    for k in range(3):
        backdrop[..., k] = top[k] * vv + bottom[k] * (1.0 - vv)
    backdrop[..., 3] = 1.0

    _save_image('T_Hair', np.dstack([hair_rgb, np.ones((size, size, 1),
                                                       np.float32)]),
                out_dir)
    _save_image('T_Dress', np.dstack([dress_rgb,
                                      np.ones((size, size, 1), np.float32)]),
                out_dir)
    _save_image('T_Apron', np.dstack([apron_rgb,
                                      np.ones((size, size, 1), np.float32)]),
                out_dir)
    _save_image('T_EyeIris', np.dstack([iris_rgb,
                                        np.ones((size, size, 1), np.float32)]),
                out_dir)
    _save_image('T_Shadow', shadow, out_dir, alpha=True)
    _save_image('T_Backdrop', backdrop, out_dir, alpha=True)
    return TEX


def build_materials(palette):
    M = {}
    M['skin'] = mat_toon('Skin', palette['skin'], low=0.66, mid=0.88)
    M['skin_shadow'] = mat_toon('SkinShadow', palette['skin_shadow'],
                                low=0.72, mid=0.90)
    M['skin_decal'] = mat_toon('SkinDecal', palette['skin'], low=0.66,
                               mid=0.88)
    M['blush'] = mat_toon('Blush', palette['blush'], low=0.82, mid=0.95)
    M['hair'] = mat_toon('Hair', img=TEX['T_Hair'], low=0.52, mid=0.82)
    M['hair_dark'] = mat_toon('HairDark', palette['hair_dark'],
                              low=0.55, mid=0.82)
    M['dress'] = mat_toon('Dress', img=TEX['T_Dress'], low=0.50, mid=0.79)
    M['dress_dark'] = mat_toon('DressDark', palette['dress_dark'],
                               low=0.55, mid=0.82)
    M['apron'] = mat_toon('Apron', img=TEX['T_Apron'], low=0.63, mid=0.85)
    M['cream'] = mat_toon('Cream', palette['cream'], low=0.64, mid=0.87)
    M['ribbon'] = mat_toon('Ribbon', palette['ribbon'], low=0.50, mid=0.80)
    M['ribbon_dark'] = mat_toon('RibbonDark', palette['ribbon_dark'],
                                low=0.55, mid=0.82)
    M['gold'] = mat_toon('Gold', palette['gold'], low=0.44, mid=0.74)
    M['peach'] = mat_toon('Peach', palette.get('peach', palette['ribbon']),
                          low=0.52, mid=0.82)
    M['trim_cream'] = mat_toon('TrimCream', palette['cream'], low=0.64,
                               mid=0.87)
    M['trim_ribbon'] = mat_toon('TrimRibbon', palette['ribbon'], low=0.52,
                                mid=0.82)
    M['leaf'] = mat_toon('Leaf', palette['leaf'], low=0.52, mid=0.82)
    M['leather'] = mat_toon('Leather', palette['leather'], low=0.50, mid=0.79)
    M['leather_dark'] = mat_toon('LeatherDark', palette['leather_dark'],
                                 low=0.57, mid=0.83)
    M['eye_white'] = mat_toon('EyeWhite', palette.get('white', '#FDF8EF'),
                              low=0.84, mid=0.95)
    M['iris'] = mat_emit_tex('EyeIris', TEX['T_EyeIris'], 1.0)
    M['pupil'] = mat_emit('Pupil', '#1C1310', 1.0)
    M['highlight'] = mat_emit('EyeHighlight', '#FFFFFF', 1.35)
    M['lash'] = mat_emit('Lash', palette['lash'], 1.0)
    M['brow'] = mat_emit('Brow', palette['brow'], 1.0)
    M['mouth'] = mat_toon('Mouth', palette['mouth'], low=0.72, mid=0.91)
    om = mat_flat('OutlineMat', palette['outline'], rough=1.0, backface=True)
    om.shadow_method = 'NONE'
    M['outline'] = om
    return M


# --------------------------------------------------------------------------
# mesh primitives
# --------------------------------------------------------------------------

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
    for p in o.data.polygons:
        p.use_smooth = smooth
    return o


def sphere(name, loc, scale, material, seg=28, rings=18, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings,
                                         radius=1.0, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
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
        apply_mod(o, b)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def torus(name, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1),
          seg=32, minor_seg=8):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=seg,
                                     minor_segments=minor_seg,
                                     location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def tube(name, points, radii, material, segments=24, cap_start=True,
         cap_end=True, uv_scale=1.0):
    """Closed quad-ring tube through points with per-ring radius."""
    verts, uvs, faces = [], [], []
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
        for i in range(segments):
            a = TAU * i / segments
            local = Vector((math.cos(a) * r, math.sin(a) * r, 0.0))
            verts.append(tuple(p + q @ local))
            uvs.append((i / segments * uv_scale, ring_i / max(1, n - 1)))
    for ring_i in range(n - 1):
        start = ring_i * segments
        for i in range(segments):
            j = (i + 1) % segments
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


def loft(name, rings, material, segments=32, cap=True, pleats=0,
         pleat_amp=0.0, smooth=True):
    """Closed loft: rings = [(z, rx, ry, cx, cy), ...] bottom→top.

    Radial pleat modulation is applied per ring (amp is per-ring tuple or
    scalar); keeps all-quad sides and fan caps.
    """
    verts, uvs, faces = [], [], []
    n = len(rings)
    for ri, ring in enumerate(rings):
        z, rx, ry = ring[0], ring[1], ring[2]
        cx = ring[3] if len(ring) > 3 else 0.0
        cy = ring[4] if len(ring) > 4 else 0.0
        amp = pleat_amp[ri] if isinstance(pleat_amp, (list, tuple)) \
            else pleat_amp
        for i in range(segments):
            a = TAU * i / segments
            mod = 1.0
            if pleats:
                mod = 1.0 + amp * math.sin(a * pleats + 0.5 * PI)
            verts.append((cx + rx * mod * math.cos(a),
                          cy + ry * mod * math.sin(a), z))
            uvs.append((i / segments, ri / max(1, n - 1)))
    for ri in range(n - 1):
        a = ri * segments
        b = (ri + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((a + i, a + j, b + j, b + i))
    if cap:
        bottom = len(verts)
        z0 = rings[0][0]
        verts.append((rings[0][3] if len(rings[0]) > 3 else 0.0,
                      rings[0][4] if len(rings[0]) > 4 else 0.0, z0))
        uvs.append((0.5, 0.0))
        top = len(verts)
        z1 = rings[-1][0]
        verts.append((rings[-1][3] if len(rings[-1]) > 3 else 0.0,
                      rings[-1][4] if len(rings[-1]) > 4 else 0.0, z1))
        uvs.append((0.5, 1.0))
        off = (n - 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((bottom, j, i))
            faces.append((top, off + i, off + j))
    return mesh_obj(name, verts, faces, material, uvs=uvs, smooth=smooth)


def blade(name, base, direction, length, width, thickness, material,
          sections=5, bend=(0, 0, 0), uv_flip=False):
    """Closed tapered hair/cloth blade with a raised centre ridge."""
    base = Vector(base)
    d = Vector(direction).normalized()
    bend = Vector(bend)
    verts, uvs, faces = [], [], []
    rings = []
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
        w = width * (1.0 - t ** 1.8)
        th = thickness * (1.0 - t ** 1.5)
        cs = [side * -w,
              side * (-w * 0.45) + normal * th,
              normal * (th * 1.45),
              side * (w * 0.45) + normal * th,
              side * w,
              side * (w * 0.2) + normal * (-th * 0.5)]
        ring = []
        for k, off in enumerate(cs):
            verts.append(tuple(p + off))
            uvs.append(((t if not uv_flip else 1.0 - t), k / len(cs)))
            ring.append(len(verts) - 1)
        rings.append(ring)
    tip = base + d * length + bend
    verts.append(tuple(tip))
    uvs.append(((1.0 if not uv_flip else 0.0), 0.5))
    tip_i = len(verts) - 1
    for i in range(sections - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(len(a)):
            k2 = (k + 1) % len(a)
            faces.append((a[k], a[k2], b[k2], b[k]))
    a = rings[-1]
    for k in range(len(a)):
        k2 = (k + 1) % len(a)
        faces.append((a[k], a[k2], tip_i))
    r0 = rings[0]
    faces.append((r0[0], r0[5], r0[4], r0[3], r0[2], r0[1]))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def eye_lens(name, center, radii, radius_scale, material, offset=1.012,
             rings=5, segs=36, thickness=0.0016):
    """Closed spherical-cap lens conformed to the eyeball front.

    center=(x,y,z), radii=(rx,ry,rz) of the eyeball, front is -Y.
    radius_scale = iris/pupil size as a fraction of the eyeball radii.
    """
    cx, cy, cz = center
    rx, ry, rz = radii
    irx, irz = rx * radius_scale, rz * radius_scale
    verts, uvs, faces = [], [], []
    # front cap
    verts.append((cx, cy - ry * offset, cz))
    uvs.append((0.5, 0.5))
    for ri in range(1, rings + 1):
        f = ri / rings
        for si in range(segs):
            a = TAU * si / segs
            lx = math.cos(a) * irx * f
            lz = math.sin(a) * irz * f
            nx = lx / rx
            nz = lz / rz
            q = max(0.0, 1.0 - nx * nx - nz * nz)
            verts.append((cx + lx, cy - ry * offset * math.sqrt(q),
                          cz + lz))
            uvs.append((0.5 + math.cos(a) * f * 0.5,
                        0.5 + math.sin(a) * f * 0.5))
    front_n = len(verts)
    for si in range(segs):
        j = (si + 1) % segs
        faces.append((0, 1 + si, 1 + j))
    for ri in range(1, rings):
        a = 1 + (ri - 1) * segs
        b = 1 + ri * segs
        for si in range(segs):
            j = (si + 1) % segs
            faces.append((a + si, b + si, b + j, a + j))
    # back cap (closes the lens; slightly inside)
    back_start = len(verts)
    back_off = offset - thickness / ry
    verts.append((cx, cy - ry * back_off, cz))
    uvs.append((0.5, 0.5))
    for ri in range(1, rings + 1):
        f = ri / rings
        for si in range(segs):
            a = TAU * si / segs
            lx = math.cos(a) * irx * f
            lz = math.sin(a) * irz * f
            nx, nz = lx / rx, lz / rz
            q = max(0.0, 1.0 - nx * nx - nz * nz)
            verts.append((cx + lx, cy - ry * back_off * math.sqrt(q),
                          cz + lz))
            uvs.append((0.5 + math.cos(a) * f * 0.5,
                        0.5 + math.sin(a) * f * 0.5))
    for si in range(segs):
        j = (si + 1) % segs
        faces.append((back_start, back_start + 1 + j,
                      back_start + 1 + si))
    for ri in range(1, rings):
        a = back_start + 1 + (ri - 1) * segs
        b = back_start + 1 + ri * segs
        for si in range(segs):
            j = (si + 1) % segs
            faces.append((a + si, a + j, b + j, b + si))
    # rim
    a = 1 + (rings - 1) * segs
    b = back_start + 1 + (rings - 1) * segs
    for si in range(segs):
        j = (si + 1) % segs
        faces.append((a + si, b + si, b + j, a + j))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def eye_band(name, center, radii, a0, a1, s_in, s_out, material,
             segs=32, thickness=0.0018):
    """Closed curved slab on the eyeball front (lash / eyelid), front is -Y."""
    cx, cy, cz = center
    rx, ry, rz = radii
    verts, uvs, faces = [], [], []

    def pt(a, s, off):
        lx = math.cos(a) * rx * s
        lz = math.sin(a) * rz * s
        q = max(0.0, 1.0 - (lx / rx) ** 2 - (lz / rz) ** 2)
        return (cx + lx, cy - ry * off * math.sqrt(q), cz + lz)

    rows = []
    for layer, off in ((0, 1.010), (1, 1.010 - thickness / ry)):
        for i in range(segs + 1):
            a = a0 + (a1 - a0) * i / segs
            for s in (s_in, s_out):
                verts.append(pt(a, s, off))
                uvs.append((i / segs, 0.0 if s == s_in else 1.0))
        rows.append(len(verts) - (segs + 1) * 2)
    # front/back surfaces
    for base in rows:
        for i in range(segs):
            a = base + i * 2
            faces.append((a, a + 1, a + 3, a + 2))
    # connect front and back along the two long edges + end caps
    f0, b0 = rows
    for i in range(segs):
        a0i = f0 + i * 2
        b0i = b0 + i * 2
        faces.append((a0i, a0i + 2, b0i + 2, b0i))       # inner edge
        faces.append((a0i + 1, b0i + 1, b0i + 3, a0i + 3))  # outer edge
    faces.append((f0, b0, b0 + 1, f0 + 1))
    last = f0 + segs * 2
    b_last = b0 + segs * 2
    faces.append((last, last + 1, b_last + 1, b_last))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def apron_shaped(name, rows, cols, material):
    """Curved pinafore panel; rows = [(z, r, ysc, half_angle), ...]."""
    verts, uvs, faces = [], [], []
    for ri, (z, r, ysc, half) in enumerate(rows):
        for ci in range(cols):
            t = ci / (cols - 1)
            th = -half + 2.0 * half * t
            x = r * math.sin(th)
            y = -r * ysc * math.cos(th)
            verts.append((x, y, z))
            uvs.append((t, ri / (len(rows) - 1)))
    for ri in range(len(rows) - 1):
        a = ri * cols
        b = (ri + 1) * cols
        for ci in range(cols - 1):
            faces.append((a + ci, a + ci + 1, b + ci + 1, b + ci))
    o = mesh_obj(name, verts, faces, material, uvs=uvs)
    solidify(o, 0.0038)
    return o


def apron_panel(name, rows, angles, material):
    """Curved front apron panel; UV u = across, v = bottom→top."""
    nang = len(angles)
    verts, uvs, faces = [], [], []
    for ri, (z, r, ysc) in enumerate(rows):
        for ai, th in enumerate(angles):
            x = r * math.sin(th)
            y = -r * ysc * math.cos(th)
            verts.append((x, y, z))
            uvs.append((ai / (nang - 1), 1.0 - ri / (len(rows) - 1)))
    for ri in range(len(rows) - 1):
        a = ri * nang
        b = (ri + 1) * nang
        for ai in range(nang - 1):
            faces.append((a + ai, a + ai + 1, b + ai + 1, b + ai))
    o = mesh_obj(name, verts, faces, material, uvs=uvs)
    solidify(o, 0.0035)
    return o


def recalc_normals(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    o.data.update()
    return o


def face_front(head, x, z, fallback=-0.11):
    """Ray-cast the head front (-Y) surface at world x,z."""
    ok, loc, _n, _i = head.ray_cast(Vector((x, -1.0, z)),
                                    Vector((0.0, 1.0, 0.0)))
    return loc.y if ok else fallback


def face_curve(name, head, pts_xz, radius, material, offset=0.003,
               segs=8):
    pts = []
    for x, z in pts_xz:
        pts.append((x, face_front(head, x, z) - offset, z))
    return tube(name, pts, [radius] * len(pts), material, segments=segs)


# --------------------------------------------------------------------------
# proportions, rig, hands
# --------------------------------------------------------------------------

def metrics_from_preset(p):
    h = float(p['height_m'])
    head_h = h / float(p['head_ratio'])
    chin = h - head_h
    head_top = h
    head_c = chin + head_h * 0.5
    head_hw = head_h * 0.5 * float(p.get('head_width_factor', 1.04))
    head_hd = head_h * 0.5 * float(p.get('head_depth_factor', 0.92))
    eye_z = chin + head_h * float(p.get('eye_line_from_chin', 0.46))
    shoulder_z = chin - head_h * 0.46
    waist_z = shoulder_z - h * 0.135
    hip_z = waist_z - h * 0.077
    knee_z = h * 0.26
    ankle_z = h * 0.072
    hem_z = h * 0.43
    m = dict(
        height=h, head_h=head_h, chin=chin, head_top=head_top,
        head_c=head_c, head_hw=head_hw, head_hd=head_hd, eye_z=eye_z,
        eye_line_from_chin=(eye_z - chin) / head_h,
        eye_line_from_top=(head_top - eye_z) / head_h,
        head_ratio=h / head_h,
        shoulder_z=shoulder_z, waist_z=waist_z, hip_z=hip_z,
        knee_z=knee_z, ankle_z=ankle_z, hem_z=hem_z,
        shoulder_x=h * 0.078, elbow_x=h * 0.150, wrist_x=h * 0.200,
        elbow_z=shoulder_z - h * 0.050, wrist_z=shoulder_z - h * 0.105,
        hip_x=h * 0.057, neck_x=0.0,
        neck_top=chin - head_h * 0.18, neck_base=shoulder_z + h * 0.045,
        chest_z=shoulder_z - h * 0.045,
        toe_z=h * 0.028,
    )
    m['ponytail'] = (
        (m['head_hw'] * 1.00, m['head_hd'] * 0.30, m['head_c'] + head_h * 0.10),
        (m['head_hw'] * 1.38, m['head_hd'] * 0.62, m['head_c'] - head_h * 0.36),
        (m['head_hw'] * 1.46, m['head_hd'] * 0.76, m['head_c'] - head_h * 0.82),
    )
    return m


def hand_layout(m):
    """Return per-side wrist/palm/finger 3-point chains (world space)."""
    out = {}
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        wrist = Vector((sy * m['wrist_x'], -0.012, m['wrist_z']))
        d = Vector((sy * 0.52, -0.03, -0.85)).normalized()
        side = Vector((sy, 0.0, 0.0)).normalized()
        palm_c = wrist + d * 0.022
        fingers = {}
        for name, off, length in (('index', -1.5, 0.052),
                                  ('middle', -0.5, 0.057),
                                  ('ring', 0.5, 0.053),
                                  ('pinky', 1.5, 0.045)):
            p0 = palm_c + d * 0.024 + side * (off * 0.0105)
            p1 = p0 + d * (length * 0.55) + side * (off * 0.0012)
            p2 = p1 + d * (length * 0.45) + side * (off * 0.0020)
            fingers[name] = (p0, p1, p2)
        tp0 = palm_c + Vector((-sy * 0.006, -0.019, 0.003))
        tp1 = tp0 + Vector((sy * 0.007, -0.013, -0.012))
        tp2 = tp1 + Vector((sy * 0.005, -0.009, -0.011))
        fingers['thumb'] = (tp0, tp1, tp2)
        out[s] = dict(wrist=wrist, palm=palm_c, d=d, side=side,
                      fingers=fingers)
    return out


def build_rig(m):
    global ARM
    arm_data = bpy.data.armatures.new('AnimeRig')
    ARM = link(bpy.data.objects.new('AnimeRig', arm_data))
    bpy.context.view_layer.objects.active = ARM
    bpy.ops.object.select_all(action='DESELECT')
    ARM.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None, connect=False, deform=True):
        b = eb.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        b.use_deform = deform
        if parent:
            b.parent = eb[parent]
            b.use_connect = connect
        BONES[name] = (Vector(head), Vector(tail))
        return b

    bone('root', (0, 0, 0), (0, 0, 0.10), deform=False)
    bone('hips', (0, 0, m['hip_z']), (0, 0, m['waist_z']), 'root')
    bone('spine', (0, 0, m['waist_z']), (0, 0, m['chest_z']), 'hips', True)
    bone('chest', (0, 0, m['chest_z']), (0, 0, m['neck_base']), 'spine', True)
    bone('neck', (0, 0, m['neck_base']), (0, 0, m['neck_top']), 'chest', True)
    bone('head', (0, 0, m['neck_top']), (0, 0, m['head_top']), 'neck', True)
    hands = hand_layout(m)
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        bone('shoulder.' + s, (0, 0, m['shoulder_z'] - 0.005),
             (sy * m['shoulder_x'], 0, m['shoulder_z']), 'chest')
        bone('upper_arm.' + s, (sy * m['shoulder_x'], 0, m['shoulder_z']),
             (sy * m['elbow_x'], -0.006, m['elbow_z']), 'shoulder.' + s,
             True)
        bone('forearm.' + s,
             (sy * m['elbow_x'], -0.006, m['elbow_z']),
             (sy * m['wrist_x'], -0.012, m['wrist_z']),
             'upper_arm.' + s, True)
        hd = hands[s]
        bone('hand.' + s, hd['wrist'], hd['palm'] + hd['d'] * 0.022,
             'forearm.' + s, True)
        for fname, (p0, p1, p2) in hd['fingers'].items():
            bone('finger_%s_01.%s' % (fname, s), p0, p1, 'hand.' + s)
            bone('finger_%s_02.%s' % (fname, s), p1, p2,
                 'finger_%s_01.%s' % (fname, s), True)
        bone('thigh.' + s, (sy * m['hip_x'], 0, m['hip_z']),
             (sy * m['hip_x'], 0, m['knee_z']), 'hips')
        bone('shin.' + s, (sy * m['hip_x'], 0, m['knee_z']),
             (sy * m['hip_x'], 0, m['ankle_z']), 'thigh.' + s, True)
        bone('foot.' + s, (sy * m['hip_x'], 0, m['ankle_z']),
             (sy * m['hip_x'], -0.095, 0.035), 'shin.' + s, True)
        bone('toe.' + s, (sy * m['hip_x'], -0.095, 0.035),
             (sy * m['hip_x'], -0.150, m['toe_z']), 'foot.' + s, True)
    # ponytail (character's +X side) and face-framing side hair
    p0, p1, p2 = m['ponytail']
    bone('ponytail_01', p0, p1, 'head')
    bone('ponytail_02', p1, p2, 'ponytail_01', True)
    bone('hair_side.L', (m['head_hw'] * 0.78, 0.01, m['head_c'] + 0.02),
         (m['head_hw'] * 0.92, -0.02, m['head_c'] - 0.16), 'head')
    bone('hair_side.R', (-m['head_hw'] * 0.78, 0.01, m['head_c'] + 0.02),
         (-m['head_hw'] * 0.92, -0.02, m['head_c'] - 0.16), 'head')
    # four skirt bones for hem swing
    for name, dx, dy in (('skirt_front', 0.0, -1.0),
                         ('skirt_back', 0.0, 1.0),
                         ('skirt_side.L', 1.0, 0.0),
                         ('skirt_side.R', -1.0, 0.0)):
        bone(name, (0, 0, m['waist_z']),
             (dx * m['height'] * 0.10, dy * m['height'] * 0.08,
              m['hem_z'] + 0.03), 'hips')
    bpy.ops.object.mode_set(mode='OBJECT')
    return ARM


def _dist_to_seg(p, a, b):
    ab = b - a
    denom = ab.length_squared
    t = 0.0 if denom < 1e-12 else clamp((p - a).dot(ab) / denom)
    return (p - (a + ab * t)).length


def weight_nearest(o, names, k=2, power=4.0, floor=1e-4):
    groups = {n: o.vertex_groups.new(name=n) for n in names}
    acc = {n: [] for n in names}
    for v in o.data.vertices:
        ds = sorted((_dist_to_seg(v.co, *BONES[n]), n) for n in names)[:k]
        vals, total = [], 0.0
        for d, n in ds:
            w = 1.0 / ((d + floor) ** power)
            vals.append((n, w))
            total += w
        for n, w in vals:
            acc[n].append((v.index, w / total))
    for n, entries in acc.items():
        for idx, w in entries:
            if w > 1e-5:
                groups[n].add([idx], w, 'REPLACE')
    return o


def weight_rigid(o, bone_name):
    vg = o.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    return o


def weight_two(o, p0, p1, p2, n1, n2, power=4.0):
    g1 = o.vertex_groups.new(name=n1)
    g2 = o.vertex_groups.new(name=n2)
    for v in o.data.vertices:
        d1 = _dist_to_seg(v.co, Vector(p0), Vector(p1))
        d2 = _dist_to_seg(v.co, Vector(p1), Vector(p2))
        w1 = 1.0 / ((d1 + 1e-4) ** power)
        w2 = 1.0 / ((d2 + 1e-4) ** power)
        tot = w1 + w2
        g1.add([v.index], w1 / tot, 'REPLACE')
        g2.add([v.index], w2 / tot, 'REPLACE')
    return o


def weight_skirt(o, m):
    hips = o.vertex_groups.new(name='hips')
    sectors = [
        ('skirt_front', 0.0), ('skirt_side.L', PI * 0.5),
        ('skirt_back', PI), ('skirt_side.R', PI * 1.5),
    ]
    groups = {n: o.vertex_groups.new(name=n) for n, _ in sectors}
    top, hem = m['waist_z'] - 0.01, m['hem_z']
    for v in o.data.vertices:
        p = v.co
        t = clamp((top - p.z) / max(1e-5, top - hem))
        swing = smoothstep(t) * 0.88
        ang = math.atan2(p.x, -p.y) % TAU
        ds = []
        for n, a in sectors:
            d = abs((ang - a + PI) % TAU - PI)
            ds.append((d, n))
        ds.sort()
        (d0, n0), (d1, n1) = ds[0], ds[1]
        w0 = 1.0
        w1 = 1.0 / (1.0 + math.exp((d1 - d0) * 2.2))
        w1 = min(w1, 0.5)
        hips.add([v.index], 1.0 - swing, 'REPLACE')
        groups[n0].add([v.index], swing * w0 / (w0 + w1), 'REPLACE')
        groups[n1].add([v.index], swing * w1 / (w0 + w1), 'REPLACE')
    return o


# --------------------------------------------------------------------------
# head + face
# --------------------------------------------------------------------------

HEAD = None


def head_loft(name, m, material):
    """Single closed quad-loft head with tapered jaw + chin + flattened face."""
    cx, cy, cz = 0.0, 0.0, m['head_c']
    hw, hd, hh = m['head_hw'], m['head_hd'], m['head_h'] * 0.5
    segs, rings = 48, 36
    verts, uvs, faces = [], [], []
    # top pole
    verts.append((cx, cy, cz + hh))
    uvs.append((0.5, 0.0))
    ring_start = []
    for i in range(1, rings):
        phi = PI * i / rings
        z = cz + hh * math.cos(phi)
        r = math.sin(phi)
        dz = z - cz
        t = clamp((-dz + hh * 0.10) / (hh * 1.10))
        jaw = 1.0 - 0.24 * (t ** 1.55)
        for j in range(segs):
            a = TAU * j / segs
            x0 = hw * r * jaw * math.cos(a)
            y0 = hd * r * math.sin(a)
            if y0 < 0:
                y0 *= 0.93
                # small forward chin point near the centre line
                y0 -= 0.010 * (t ** 1.7) * (max(0.0, -math.sin(a)) ** 2)
            verts.append((cx + x0, cy + y0, z))
            uvs.append((j / segs, i / rings))
        ring_start.append(len(verts) - segs)
    # bottom pole (chin)
    bottom_i = len(verts)
    verts.append((cx, cy - 0.008, cz - hh))
    uvs.append((0.5, 1.0))
    # top fan
    first = ring_start[0]
    for j in range(segs):
        k = (j + 1) % segs
        faces.append((0, first + j, first + k))
    # side quads
    for ri in range(rings - 2):
        a = ring_start[ri]
        b = ring_start[ri + 1]
        for j in range(segs):
            k = (j + 1) % segs
            faces.append((a + j, a + k, b + k, b + j))
    last = ring_start[-1]
    for j in range(segs):
        k = (j + 1) % segs
        faces.append((last + j, last + k, bottom_i))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def build_head(m, M, design):
    global HEAD
    HEAD = register(head_loft('Head', m, M['skin']), 'head')
    HEAD['part'] = 'head'
    recalc_normals(HEAD)
    weight_rigid(HEAD, 'head')
    hw, hd = m['head_hw'], m['head_hd']
    # ears are intentionally hidden by the hair cap in this design
    eye_x = hw * 0.44
    eye_z = m['eye_z']
    eye_rx, eye_ry, eye_rz = hw * 0.300, hd * 0.250, m['head_h'] * 0.188
    eye_meta = []
    for sy in (1, -1):
        ex = sy * eye_x
        eye_front = face_front(HEAD, ex, eye_z)
        ec = (ex, eye_front + 0.017, eye_z)
        radii = (eye_rx, eye_ry, eye_rz)
        eye = sphere('EyeWhite', ec, radii, M['eye_white'], 32, 20)
        weight_rigid(eye, 'head')
        register(eye, 'eye_white')
        # skin eyelid rim (outside the eyeball) + lash line (just inside)
        lid = eye_band('Eyelid', ec, radii, 0.10 * PI, 0.90 * PI,
                       0.99, 1.085, M['skin_decal'], segs=36, thickness=0.0028)
        weight_rigid(lid, 'head')
        register(lid, 'decal')
        lash = eye_band('Lash', ec, radii, 0.02 * PI, 0.98 * PI,
                        0.80, 0.995, M['lash'], segs=40, thickness=0.0032)
        weight_rigid(lash, 'head')
        register(lash, 'decal')
        # iris / pupil / highlights conformed to the eyeball sphere
        iris = eye_lens('EyeIris', ec, radii, 0.76, M['iris'],
                        offset=1.016, rings=5, segs=40)
        weight_rigid(iris, 'head')
        register(iris, 'decal')
        pupil = eye_lens('Pupil', ec, radii, 0.36, M['pupil'],
                         offset=1.030, rings=3, segs=30,
                         thickness=0.0012)
        weight_rigid(pupil, 'head')
        register(pupil, 'decal')
        for hi, (ox, oz, r) in enumerate(((-0.011, 0.018, 0.0070),
                                          (0.013, -0.013, 0.0036))):
            lx, lz = ox, oz
            q = max(0.02, 1.0 - (lx / eye_rx) ** 2 - (lz / eye_rz) ** 2)
            hy = ec[1] - eye_ry * 1.055 * math.sqrt(q)
            hs = sphere('EyeHighlight%d' % hi, (ec[0] + lx, hy, ec[2] + lz),
                        (r, r * 0.6, r), M['highlight'], 12, 8)
            weight_rigid(hs, 'head')
            register(hs, 'decal')
        # brow
        brow_pts = []
        for i in range(7):
            t = i / 6.0
            bx = ex - sy * eye_rx * 0.95 + sy * eye_rx * 1.9 * t
            bz = eye_z + m['head_h'] * 0.175 + 0.008 * math.sin(PI * t)
            brow_pts.append((bx, bz))
        brow = face_curve('Brow', HEAD, brow_pts, 0.0026, M['brow'],
                          offset=0.0035, segs=6)
        weight_rigid(brow, 'head')
        register(brow, 'decal')
        # blush
        bx = sy * hw * 0.63
        bz = eye_z - m['head_h'] * 0.18
        by = face_front(HEAD, bx, bz) + 0.001
        blush = sphere('Blush', (bx, by, bz), (0.026, 0.008, 0.012),
                       M['blush'], 20, 12)
        weight_rigid(blush, 'head')
        register(blush, 'decal')
        eye_meta.append(dict(x=ex, z=eye_z, center=ec, radii=radii))
    # nose bump
    nz = eye_z - m['head_h'] * 0.24
    ny = face_front(HEAD, 0.0, nz) + 0.001
    nose = sphere('Nose', (0.0, ny - 0.003, nz), (0.008, 0.010, 0.007),
                  M['skin_decal'], 16, 12)
    weight_rigid(nose, 'head')
    register(nose, 'decal')
    nose_line = face_curve(
        'NoseLine', HEAD,
        [(-0.006, nz - 0.003), (0.0, nz - 0.006), (0.006, nz - 0.003)],
        0.0010, M['skin_shadow'], offset=0.0030, segs=6)
    weight_rigid(nose_line, 'head')
    register(nose_line, 'decal')
    # smile
    mz = eye_z - m['head_h'] * 0.33
    mouth_pts = [(-0.020, mz + 0.004), (-0.010, mz - 0.001),
                 (0.0, mz - 0.003), (0.010, mz - 0.001),
                 (0.020, mz + 0.004)]
    mouth = face_curve('Mouth', HEAD, mouth_pts, 0.0022, M['mouth'],
                       offset=0.0028, segs=8)
    weight_rigid(mouth, 'head')
    register(mouth, 'decal')
    HEAD['eye_meta'] = json.dumps(eye_meta)
    return HEAD


# --------------------------------------------------------------------------
# hair
# --------------------------------------------------------------------------

def build_hair_cap(m, M):
    cap = sphere('HairCap', (0, 0.008, m['head_c'] + 0.010),
                 (m['head_hw'] * 1.09, m['head_hd'] * 1.17,
                  m['head_h'] * 0.545), M['hair'], 48, 32)
    hairline = m['eye_z'] + m['head_h'] * 0.14
    for v in cap.data.vertices:
        if v.co.y < 0.02 and v.co.z < hairline:
            t = smoothstep((hairline - v.co.z) / (m['head_h'] * 0.20))
            v.co.x *= (1.0 - 0.42 * t)
            v.co.y = 0.010 + (v.co.y - 0.010) * (1.0 - 0.62 * t)
    cap.data.update()
    recalc_normals(cap)
    return cap


def build_hair(m, M, design):
    style = design.get('hair_style', 'side_ponytail')
    hw, hd = m['head_hw'], m['head_hd']
    top = m['head_top']
    cap = build_hair_cap(m, M)
    weight_rigid(cap, 'head')
    register(cap)
    back = sphere('HairBack', (0, 0.078, m['head_c'] - 0.012),
                  (hw * 0.99, hd * 0.82, m['head_h'] * 0.47),
                  M['hair_dark'], 36, 24)
    weight_rigid(back, 'head')
    register(back)
    # fringe blades: centre part, tips break above the brows
    bangs = []
    hairline = m['eye_z'] + m['head_h'] * 0.19
    for i in range(13):
        t = (i - 6) / 6.0
        x = t * hw * 0.84
        z0 = hairline + m['head_h'] * (0.045 + 0.018 * abs(t)
                                      + 0.008 * math.sin(i * 2.1))
        # the root sits just inside the cap; the blade emerges through the
        # hairline, so the cap does not show a straight "headband" seam
        y0 = face_front(HEAD, x, z0) + 0.004
        direction = (x * 2.4 + 0.05 * t, -0.42, -1.0 + 0.10 * abs(t))
        length = m['head_h'] * (0.285 - 0.040 * abs(t))
        o = blade('Bang', (x, y0, z0), direction, length,
                  hw * 0.185, 0.011, M['hair'], sections=5,
                  bend=(x * 0.16, -0.016, -0.004))
        weight_rigid(o, 'head')
        register(o)
        bangs.append(o)
    # face-framing side locks -> hair_side bones
    for sy, s in ((1, 'L'), (-1, 'R')):
        base = (sy * hw * 0.80, face_front(HEAD, sy * hw * 0.80,
                                          m['head_c'] + 0.02) - 0.004,
                m['head_c'] + 0.03)
        o = blade('SideLock.' + s, base,
                  (sy * 0.22, -0.16, -1.0), m['head_h'] * 0.63,
                  hw * 0.19, 0.013, M['hair'], sections=6,
                  bend=(sy * 0.012, -0.016, -0.010))
        weight_nearest(o, ['head', 'hair_side.' + s], k=2, power=3.2)
        register(o)
        o = blade('SideStrand.' + s,
                  (sy * hw * 0.88, hd * 0.18, m['head_c'] + 0.02),
                  (sy * 0.02, -0.10, -1.0), m['head_h'] * 0.56,
                  hw * 0.12, 0.010, M['hair_dark'], sections=6,
                  bend=(sy * 0.004, -0.008, -0.006))
        weight_nearest(o, ['head', 'hair_side.' + s], k=2, power=3.0)
        register(o)
    # nape strands
    for i in range(5):
        x = (i - 2) * hw * 0.34
        o = blade('Nape', (x, hd * 0.95, m['head_c'] - m['head_h'] * 0.30),
                  (x * 0.8, 0.12, -1.0), m['head_h'] * 0.34,
                  hw * 0.12, 0.009, M['hair_dark'], sections=4,
                  bend=(0, 0.008, -0.005))
        weight_rigid(o, 'head')
        register(o)
    # ahoge
    ah = blade('Ahoge', (0.010, 0.006, top - 0.002),
               (0.28, 0.10, 1.0), m['head_h'] * 0.32,
               0.010, 0.006, M['hair'], sections=5,
               bend=(0.022, 0.014, 0.012))
    weight_rigid(ah, 'head')
    register(ah)
    if style == 'side_ponytail':
        build_ponytail(m, M)
    elif style == 'twin_buns':
        for sy in (1, -1):
            bun = sphere('Bun', (sy * hw * 1.02, 0.04, m['head_c'] + 0.06),
                         (hw * 0.34, hw * 0.34, hw * 0.34), M['hair'],
                         24, 16)
            weight_rigid(bun, 'head')
            register(bun)
    # peach hairpin (original motif, left fringe)
    px = -hw * 0.62
    pz = m['head_c'] + m['head_h'] * 0.32
    py = face_front(HEAD, px, pz) - 0.012
    peach = sphere('HairPinPeach', (px, py, pz), (0.017, 0.013, 0.016),
                   M['peach'], 18, 12)
    weight_rigid(peach, 'head')
    register(peach)
    cleft = box('HairPinCleft', (px - 0.008, py - 0.008, pz + 0.008),
                (0.004, 0.004, 0.012), M['ribbon_dark'],
                rot=(0, 0, 0.6), bevel=0.001)
    weight_rigid(cleft, 'head')
    register(cleft)
    for k in range(2):
        leaf = blade('HairPinLeaf%d' % k,
                     (px + 0.010, py + 0.002, pz + 0.002),
                     (0.55 - 0.3 * k, 0.15, 0.75),
                     0.028, 0.009, 0.004, M['leaf'], sections=4,
                     bend=(0.004, 0.002, 0.006))
        weight_rigid(leaf, 'head')
        register(leaf)


def build_ponytail(m, M):
    hw, hd = m['head_hw'], m['head_hd']
    base = Vector((hw * 0.99, hd * 0.31, m['head_c'] + m['head_h'] * 0.09))
    # rounded base tuft gives the ponytail volume instead of a flat card fan
    tuft = sphere('PonytailTuft', base + Vector((0.012, 0.010, -0.030)),
                  (0.056, 0.050, 0.082), M['hair'], 28, 18,
                  rot=(0.0, 0.35, 0.0))
    weight_rigid(tuft, 'ponytail_01')
    register(tuft)
    # main volume blades
    for i in range(6):
        t = (i - 2.5) / 2.5
        b = base + Vector((0.010 * t, 0.014 * t, 0.012 * abs(t)))
        direction = (0.30 + 0.08 * t, 0.12 + 0.04 * t, -1.0)
        length = m['head_h'] * (0.96 + 0.10 * (1.0 - abs(t)))
        o = blade('Ponytail', b, direction, length,
                  hw * (0.24 - 0.025 * abs(t)), 0.018, M['hair'],
                  sections=7,
                  bend=(0.055 + 0.012 * t, 0.025, -0.018))
        weight_nearest(o, ['head', 'ponytail_01', 'ponytail_02'],
                       k=2, power=3.0)
        register(o)
    # lighter fine strands
    for i in range(4):
        t = (i - 1.5) / 2.0
        b = base + Vector((0.012 * t, 0.024 + 0.006 * t, 0.006))
        o = blade('PonytailStrand', b,
                  (0.36 + 0.10 * t, 0.18, -1.0),
                  m['head_h'] * (0.82 + 0.10 * (1 - abs(t))),
                  hw * 0.080, 0.008, M['hair_dark'], sections=6,
                  bend=(0.06, 0.025, -0.012))
        weight_nearest(o, ['head', 'ponytail_01', 'ponytail_02'],
                       k=2, power=3.0)
        register(o)
    # ribbon bow at the tie
    knot = sphere('PonytailKnot', (hw * 1.04, -0.026,
                                   m['head_c'] + m['head_h'] * 0.15),
                  (0.023, 0.018, 0.025), M['ribbon'], 16, 10)
    weight_rigid(knot, 'ponytail_01')
    register(knot)
    for side in (1, -1):
        loop = torus('PonytailBow', (hw * 1.04 + side * 0.032, -0.036,
                                     m['head_c'] + m['head_h'] * 0.15),
                     0.026, 0.0075, M['ribbon'], rot=(PI * 0.5, 0, 0),
                     scale=(1.0, 1.0, 0.82), seg=24, minor_seg=8)
        weight_rigid(loop, 'ponytail_01')
        register(loop)
    front_knot = sphere('PonytailBowKnot', (hw * 1.04, -0.046,
                                           m['head_c'] + m['head_h'] * 0.15),
                        (0.020, 0.012, 0.022), M['ribbon_dark'], 16, 10)
    weight_rigid(front_knot, 'ponytail_01')
    register(front_knot)
    for k in range(2):
        tail = blade('PonytailBowTail',
                     (hw * 1.04, -0.040, m['head_c'] + m['head_h'] * 0.13),
                     (0.18 + 0.10 * k, -0.10, -1.0), 0.085, 0.011, 0.004,
                     M['ribbon_dark'], sections=4,
                     bend=(0.010, -0.006, -0.004))
        weight_rigid(tail, 'ponytail_01')
        register(tail)
    for k in range(2):
        o = blade('PonytailRibbonTail',
                  (hw * 0.84, hd * 0.47, m['head_c'] + m['head_h'] * 0.12),
                  (0.40 + 0.10 * k, 0.20, -1.0), 0.10, 0.010, 0.004,
                  M['ribbon_dark'], sections=4,
                  bend=(0.012, 0.006, -0.004))
        weight_rigid(o, 'ponytail_01')
        register(o)


# --------------------------------------------------------------------------
# body + hands
# --------------------------------------------------------------------------

def build_body(m, M):
    torso = loft('Torso', [
        (m['hip_z'] - 0.010, 0.085, 0.064),
        (m['hip_z'] + 0.025, 0.090, 0.070),
        (m['waist_z'], 0.078, 0.060),
        (m['chest_z'], 0.096, 0.071),
        (m['shoulder_z'] - 0.010, 0.101, 0.073),
        (m['neck_base'], 0.064, 0.056),
    ], M['skin'], segments=28)
    weight_nearest(torso, ['hips', 'spine', 'chest', 'neck'], k=2, power=4.0)
    register(torso)
    neck = tube('Neck', [(0, 0.002, m['neck_base'] - 0.01),
                         (0, 0.004, m['neck_base'] + 0.025),
                         (0, 0.004, m['neck_top'] + 0.01)],
                [0.034, 0.032, 0.035], M['skin'], segments=20)
    weight_nearest(neck, ['neck', 'chest', 'head'], k=2, power=3.0)
    register(neck)
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        sh = sphere('ShoulderSkin.' + s,
                    (sy * m['shoulder_x'] * 0.92, 0, m['shoulder_z']),
                    (0.047, 0.044, 0.045), M['skin'], 20, 14)
        weight_nearest(sh, ['chest', 'shoulder.' + s, 'upper_arm.' + s],
                       k=2, power=3.0)
        register(sh)
        ua = tube('UpperArm.' + s, [
            (sy * m['shoulder_x'], 0, m['shoulder_z']),
            (sy * (m['shoulder_x'] + m['elbow_x']) * 0.5, -0.003,
             (m['shoulder_z'] + m['elbow_z']) * 0.5),
            (sy * m['elbow_x'], -0.006, m['elbow_z']),
        ], [0.033, 0.030, 0.028], M['skin'], segments=18)
        weight_nearest(ua, ['shoulder.' + s, 'upper_arm.' + s,
                            'forearm.' + s], k=2, power=4.0)
        register(ua)
        elbow = sphere('Elbow.' + s,
                       (sy * m['elbow_x'], -0.006, m['elbow_z']),
                       (0.031, 0.030, 0.032), M['skin'], 16, 12)
        weight_nearest(elbow, ['upper_arm.' + s, 'forearm.' + s],
                       k=2, power=4.0)
        register(elbow)
        fa = tube('Forearm.' + s, [
            (sy * m['elbow_x'], -0.006, m['elbow_z']),
            (sy * (m['elbow_x'] + m['wrist_x']) * 0.5, -0.009,
             (m['elbow_z'] + m['wrist_z']) * 0.5),
            (sy * m['wrist_x'], -0.012, m['wrist_z']),
        ], [0.027, 0.024, 0.021], M['skin'], segments=18)
        weight_nearest(fa, ['upper_arm.' + s, 'forearm.' + s, 'hand.' + s],
                       k=2, power=4.0)
        register(fa)
        thigh_top = sphere('HipSkin.' + s,
                           (sy * m['hip_x'], 0, m['hip_z'] - 0.015),
                           (0.066, 0.062, 0.072), M['skin'], 20, 14)
        weight_nearest(thigh_top, ['hips', 'thigh.' + s], k=2, power=3.0)
        register(thigh_top)
        th = tube('Thigh.' + s, [
            (sy * m['hip_x'], 0, m['hip_z'] - 0.02),
            (sy * m['hip_x'], 0, (m['hip_z'] + m['knee_z']) * 0.5),
            (sy * m['hip_x'], 0, m['knee_z']),
        ], [0.058, 0.050, 0.042], M['skin'], segments=20)
        weight_nearest(th, ['hips', 'thigh.' + s, 'shin.' + s],
                       k=2, power=4.0)
        register(th)
        knee = sphere('Knee.' + s, (sy * m['hip_x'], 0, m['knee_z']),
                      (0.046, 0.046, 0.047), M['skin'], 16, 12)
        weight_nearest(knee, ['thigh.' + s, 'shin.' + s], k=2, power=4.0)
        register(knee)
        shin = tube('Shin.' + s, [
            (sy * m['hip_x'], 0, m['knee_z']),
            (sy * m['hip_x'], 0, (m['knee_z'] + m['ankle_z']) * 0.5),
            (sy * m['hip_x'], 0, m['ankle_z']),
        ], [0.040, 0.034, 0.026], M['skin'], segments=18)
        weight_nearest(shin, ['thigh.' + s, 'shin.' + s, 'foot.' + s],
                       k=2, power=4.0)
        register(shin)
        ankle = sphere('Ankle.' + s, (sy * m['hip_x'], 0, m['ankle_z']),
                       (0.026, 0.026, 0.026), M['skin'], 14, 10)
        weight_nearest(ankle, ['shin.' + s, 'foot.' + s], k=2, power=4.0)
        register(ankle)


def build_hands(m, M):
    hands = hand_layout(m)
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        hd = hands[s]
        d = hd['d']
        palm = sphere('Palm.' + s, hd['palm'],
                      (0.030, 0.024, 0.037), M['skin'], 18, 12,
                      rot=d.to_track_quat('Z', 'Y').to_euler())
        weight_rigid(palm, 'hand.' + s)
        register(palm)
        for fname, (p0, p1, p2) in hd['fingers'].items():
            o = tube('Finger_%s.%s' % (fname, s), [p0, p1, p2],
                     [0.0068, 0.0058, 0.0040], M['skin'], segments=8)
            weight_two(o, p0, p1, p2,
                       'finger_%s_01.%s' % (fname, s),
                       'finger_%s_02.%s' % (fname, s))
            register(o)


# --------------------------------------------------------------------------
# outfit
# --------------------------------------------------------------------------

def build_outfit(m, M):
    # bodice
    bodice = loft('Bodice', [
        (m['waist_z'] - 0.012, 0.087, 0.067),
        (m['waist_z'] + 0.030, 0.090, 0.069),
        (m['chest_z'], 0.103, 0.079),
        (m['shoulder_z'] - 0.020, 0.104, 0.078),
        (m['neck_base'] - 0.002, 0.066, 0.058),
    ], M['dress'], segments=28)
    weight_nearest(bodice, ['hips', 'spine', 'chest', 'neck'],
                   k=2, power=4.0)
    register(bodice)
    # flared pleated skirt
    hem = m['hem_z']
    waist = m['waist_z'] - 0.005
    skirt = loft('Skirt', [
        (hem, m['height'] * 0.162, m['height'] * 0.130),
        (hem + (waist - hem) * 0.34, m['height'] * 0.135,
         m['height'] * 0.106),
        (hem + (waist - hem) * 0.68, m['height'] * 0.098,
         m['height'] * 0.076),
        (waist, 0.087, 0.068),
    ], M['dress'], segments=48, cap=True, pleats=12,
        pleat_amp=(0.038, 0.024, 0.010, 0.0))
    weight_skirt(skirt, m)
    register(skirt)
    # hem trim follows the pleated edge
    hem_pts, hem_radii = [], []
    for i in range(97):
        a = TAU * i / 96.0
        mod = 1.0 + 0.038 * math.sin(a * 12.0 + 0.5 * PI)
        hem_pts.append((m['height'] * 0.162 * mod * math.cos(a),
                        m['height'] * 0.130 * mod * math.sin(a), hem + 0.002))
        hem_radii.append(0.0040)
    trim = tube('HemTrim', hem_pts, hem_radii, M['trim_cream'], segments=8,
                cap_start=True, cap_end=True)
    weight_nearest(trim, ['hips', 'skirt_front', 'skirt_back',
                          'skirt_side.L', 'skirt_side.R'], k=2, power=2.0)
    register(trim)
    frill = loft('PetticoatFrill', [
        (hem - 0.026, m['height'] * 0.150, m['height'] * 0.121),
        (hem - 0.006, m['height'] * 0.160, m['height'] * 0.129),
        (hem + 0.006, m['height'] * 0.166, m['height'] * 0.134),
    ], M['cream'], segments=48, cap=True, pleats=16,
        pleat_amp=(0.024, 0.028, 0.030))
    weight_skirt(frill, m)
    register(frill)
    # sash
    sash = loft('Sash', [(m['waist_z'] - 0.018, 0.090, 0.070),
                         (m['waist_z'] + 0.012, 0.089, 0.069)],
                M['ribbon'], segments=28)
    weight_nearest(sash, ['hips', 'spine'], k=2, power=3.0)
    register(sash)
    knot = sphere('SashKnot', (0.0, -0.075, m['waist_z'] - 0.003),
                  (0.020, 0.012, 0.016), M['ribbon_dark'], 16, 10)
    weight_rigid(knot, 'spine')
    register(knot)
    for sy in (1, -1):
        o = blade('SashTail', (0.010 * sy, -0.075, m['waist_z'] - 0.01),
                  (sy * 0.45, -0.10, -1.0), 0.085, 0.014, 0.004,
                  M['ribbon_dark'], sections=4,
                  bend=(sy * 0.004, -0.006, -0.003))
        weight_rigid(o, 'spine')
        register(o)
    # apron panel with straps
    a_top = m['chest_z'] + 0.005
    a_bot = hem + 0.030
    rows = []
    for i in range(8):
        t = i / 7.0
        z = a_top + (a_bot - a_top) * t
        r = m['height'] * (0.075 + 0.073 * (t ** 1.35))
        ysc = 0.84 + 0.08 * t
        half = 0.56 + 0.40 * (t ** 0.9)
        rows.append((z, r, ysc, half))
    apron = apron_shaped('Apron', rows, 23, M['apron'])
    weight_nearest(apron, ['hips', 'spine', 'chest'], k=2, power=2.6)
    register(apron)
    trim_pts = []
    last_z, last_r, last_ysc, last_half = rows[-1]
    for i in range(25):
        th = -last_half + 2.0 * last_half * i / 24.0
        trim_pts.append((last_r * math.sin(th),
                         -last_r * last_ysc * math.cos(th),
                         last_z + 0.002))
    apron_trim = tube('ApronTrim', trim_pts, [0.0040] * len(trim_pts),
                      M['trim_ribbon'], segments=8, cap_start=True,
                      cap_end=True)
    weight_nearest(apron_trim, ['hips', 'spine'], k=2, power=2.0)
    register(apron_trim)
    halter_pts = [
        (-0.045, -0.060, a_top - 0.002),
        (-0.048, -0.074, a_top + 0.010),
        (-0.042, -0.063, a_top + 0.046),
        (-0.034, -0.048, m['shoulder_z'] + 0.028),
        (-0.026, -0.026, m['shoulder_z'] + 0.056),
        (0.000, 0.020, m['shoulder_z'] + 0.064),
        (0.026, -0.026, m['shoulder_z'] + 0.056),
        (0.034, -0.048, m['shoulder_z'] + 0.028),
        (0.042, -0.063, a_top + 0.046),
        (0.048, -0.074, a_top + 0.010),
        (0.045, -0.060, a_top - 0.002),
    ]
    halter = tube('ApronHalter', halter_pts, [0.0060] * len(halter_pts),
                  M['trim_cream'], segments=8)
    weight_nearest(halter, ['chest', 'spine', 'neck'], k=2, power=2.0)
    register(halter)
    # collar + neck ribbon
    collar = torus('Collar', (0, 0, m['neck_base'] - 0.002), 0.050, 0.008,
                   M['cream'], scale=(1.0, 0.94, 1.0))
    weight_rigid(collar, 'chest')
    register(collar)
    band = torus('NeckRibbon', (0, 0, m['neck_base'] + 0.020), 0.040, 0.007,
                 M['ribbon'], scale=(1.0, 0.94, 1.0))
    weight_rigid(band, 'neck')
    register(band)
    ruff = torus('RuffCollar', (0, 0, m['neck_base'] + 0.007), 0.052, 0.010,
                 M['cream'], scale=(1.0, 0.92, 1.0))
    weight_rigid(ruff, 'neck')
    register(ruff)
    for sy in (1, -1):
        o = blade('ChestBow', (sy * 0.009, -0.062, m['neck_base'] + 0.004),
                  (sy * 0.72, -0.14, -0.48), 0.066, 0.025, 0.007,
                  M['ribbon'], sections=4,
                  bend=(sy * 0.008, -0.006, -0.002))
        weight_rigid(o, 'chest')
        register(o)
    chest_knot = sphere('ChestKnot', (0, -0.062, m['neck_base'] + 0.006),
                        (0.015, 0.011, 0.016), M['ribbon_dark'], 14, 10)
    weight_rigid(chest_knot, 'chest')
    register(chest_knot)
    # puff sleeves + cuffs
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        cuff_pos = Vector((sy * (m['shoulder_x'] + 0.055), -0.003,
                           m['shoulder_z'] - 0.048))
        puff = sphere('PuffSleeve.' + s,
                      (sy * m['shoulder_x'] * 1.02, 0,
                       m['shoulder_z'] - 0.002),
                      (0.058, 0.052, 0.060),
                      M['dress'], 22, 14)
        weight_nearest(puff, ['chest', 'shoulder.' + s, 'upper_arm.' + s],
                       k=2, power=3.0)
        register(puff)
        d = Vector((sy * 0.52, -0.03, -0.85)).normalized()
        cuff = torus('SleeveCuff.' + s, cuff_pos, 0.030, 0.0065,
                     M['cream'], rot=d.to_track_quat('Z', 'Y').to_euler())
        weight_rigid(cuff, 'upper_arm.' + s)
        register(cuff)
        wrist_pos = Vector((sy * m['wrist_x'], -0.012, m['wrist_z']))
        wc = torus('WristCuff.' + s, wrist_pos, 0.023, 0.0055,
                   M['gold'], rot=d.to_track_quat('Z', 'Y').to_euler())
        weight_rigid(wc, 'hand.' + s)
        register(wc)
    # socks + boots
    for sy, s in ((1.0, 'L'), (-1.0, 'R')):
        x = sy * m['hip_x']
        sock = tube('Sock.' + s, [
            (x, 0, m['knee_z'] - 0.020), (x, 0, m['knee_z'] - 0.090),
            (x, 0, m['ankle_z'] + 0.055)], [0.043, 0.041, 0.039],
            M['cream'], segments=18)
        weight_nearest(sock, ['shin.' + s, 'foot.' + s], k=2, power=3.0)
        register(sock)
        band = torus('SockBand.' + s, (x, 0, m['knee_z'] - 0.020),
                     0.043, 0.0055, M['trim_ribbon'])
        weight_rigid(band, 'shin.' + s)
        register(band)
        shaft = tube('BootShaft.' + s, [
            (x, 0, m['ankle_z'] + 0.075), (x, 0, m['ankle_z'] + 0.020),
            (x, 0, m['ankle_z'] - 0.020)], [0.045, 0.043, 0.047],
            M['leather'], segments=18)
        weight_nearest(shaft, ['shin.' + s, 'foot.' + s], k=2, power=4.0)
        register(shaft)
        foot = sphere('BootFoot.' + s, (x, -0.040, 0.050),
                      (0.052, 0.089, 0.049), M['leather'], 20, 14)
        weight_rigid(foot, 'foot.' + s)
        register(foot)
        toe = sphere('BootToe.' + s, (x, -0.110, 0.040),
                     (0.046, 0.041, 0.037), M['leather'], 18, 12)
        weight_rigid(toe, 'toe.' + s)
        register(toe)
        sole = box('BootSole.' + s, (x, -0.042, 0.012),
                   (0.104, 0.176, 0.024), M['leather_dark'], bevel=0.012)
        weight_rigid(sole, 'foot.' + s)
        register(sole)
        top = torus('BootTop.' + s, (x, 0, m['ankle_z'] + 0.075),
                    0.045, 0.006, M['trim_ribbon'])
        weight_nearest(top, ['shin.' + s], k=1, power=3.0)
        register(top)
        # tiny original boot bow
        knot = sphere('BootBowKnot.' + s, (x, -0.045, 0.095),
                      (0.009, 0.009, 0.008), M['ribbon'], 12, 8)
        weight_rigid(knot, 'foot.' + s)
        register(knot)
        for bx in (1, -1):
            o = blade('BootBow.' + s, (x + bx * 0.006, -0.045, 0.095),
                      (bx * 0.8, -0.35, 0.20), 0.026, 0.009, 0.003,
                      M['ribbon'], sections=3)
            weight_rigid(o, 'foot.' + s)
            register(o)
    # a small waist charm (original peach motif)
    charm = sphere('WaistCharm', (0.074, -0.062,
                                  m['waist_z'] - 0.065),
                   (0.012, 0.010, 0.012), M['gold'], 14, 10)
    weight_rigid(charm, 'hips')
    register(charm)


# --------------------------------------------------------------------------
# assembly + outline
# --------------------------------------------------------------------------

def join_character(arm, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    char = bpy.context.object
    char.name = name
    char.data.name = name + 'Mesh'
    recalc_normals(char)
    char.parent = arm
    char.matrix_parent_inverse.identity()
    mod = char.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_vertex_groups = True
    char['role'] = 'character'
    return char


def add_outline(char, mat, thickness=0.0032):
    out = char.copy()
    out.data = char.data.copy()
    out.name = char.name + '_Outline'
    link(out)
    normals = [v.normal.copy() for v in out.data.vertices]
    for v, n in zip(out.data.vertices, normals):
        v.co += n * thickness
    skip = {i for i, slot in enumerate(out.material_slots)
            if slot.material and slot.material.name.split('.')[0]
            in DECAL_MATS}
    bm = bmesh.new()
    bm.from_mesh(out.data)
    if skip:
        kill = [f for f in bm.faces if f.material_index in skip]
        bmesh.ops.delete(bm, geom=kill, context='FACES')
    bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(out.data)
    bm.free()
    out.data.materials.clear()
    out.data.materials.append(mat)
    for p in out.data.polygons:
        p.material_index = 0
    out['role'] = 'outline_shell'
    return out


def bbox_of(objs):
    pts = []
    for o in objs:
        if o.type != 'MESH':
            continue
        for c in o.bound_box:
            pts.append(o.matrix_world @ Vector(c))
    if not pts:
        return None
    xs = [p.x for p in pts]
    ys = [p.y for p in pts]
    zs = [p.z for p in pts]
    return [min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)]


def measure_mesh(o):
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    quads = sum(1 for p in o.data.polygons if len(p.vertices) == 4)
    ngons = sum(1 for p in o.data.polygons if len(p.vertices) > 4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    loose_verts = sum(1 for v in bm.verts if not v.link_edges)
    bm.free()
    zero = 0
    bad_sum = 0
    max_inf = 0
    for v in o.data.vertices:
        ws = [g.weight for g in v.groups if g.weight > 1e-5]
        s = sum(ws)
        if s < 1e-4:
            zero += 1
        elif abs(s - 1.0) > 0.02:
            bad_sum += 1
        max_inf = max(max_inf, len(ws))
    return dict(
        tris=tris, quads=quads, ngons=ngons,
        quad_ratio=quads / max(1, len(o.data.polygons)),
        verts=len(o.data.vertices), materials=len(o.data.materials),
        uv_layers=[l.name for l in o.data.uv_layers],
        non_manifold=non_manifold, loose_verts=loose_verts,
        zero_weight=zero, bad_weight_sum=bad_sum, max_influences=max_inf,
        dims=[round(v, 4) for v in o.dimensions],
        bbox=[round(v, 4) for v in bbox_of([o])],
    )


# --------------------------------------------------------------------------
# stage / lights / camera
# --------------------------------------------------------------------------

def build_stage(m, M):
    sc = bpy.context.scene
    pal = M['_palette']
    world = bpy.data.worlds.new('AnimeWorld')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (*srgb(pal['dress']), 1.0)
    bg.inputs['Strength'].default_value = 0.32
    sc.world = world
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=4.2, depth=6.0,
                                        end_fill_type='NOTHING',
                                        location=(0, 0, 2.9))
    wall = bpy.context.object
    wall.name = 'Cyclorama'
    wm = bpy.data.materials.new('Backdrop')
    wm.use_nodes = True
    nodes, links = wm.node_tree.nodes, wm.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    tc = nodes.new('ShaderNodeTexCoord')
    sep = nodes.new('ShaderNodeSeparateXYZ')
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*srgb('#F8EBDD'), 1)
    ramp.color_ramp.elements[1].position = 0.62
    ramp.color_ramp.elements[1].color = (*srgb('#E9E4EE'), 1)
    e = ramp.color_ramp.elements.new(1.0)
    e.color = (*srgb('#DCD8E7'), 1)
    emit = nodes.new('ShaderNodeEmission')
    emit.inputs['Strength'].default_value = 0.96
    links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], emit.inputs['Color'])
    links.new(emit.outputs['Emission'], out.inputs['Surface'])
    wm.use_backface_culling = False
    wall.data.materials.append(wm)
    for p in wall.data.polygons:
        p.use_smooth = True
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=4.2, depth=0.06,
                                        location=(0, 0, -0.032))
    floor = bpy.context.object
    floor.name = 'Floor'
    fm = bpy.data.materials.new('FloorMat')
    fm.use_nodes = True
    fnodes, flinks = fm.node_tree.nodes, fm.node_tree.links
    fnodes.clear()
    fout = fnodes.new('ShaderNodeOutputMaterial')
    femit = fnodes.new('ShaderNodeEmission')
    femit.inputs['Color'].default_value = (*srgb('#F8EFE2'), 1)
    femit.inputs['Strength'].default_value = 0.94
    flinks.new(femit.outputs['Emission'], fout.inputs['Surface'])
    floor.data.materials.append(fm)
    ring = torus('StageRing', (0, 0, 0.004), 0.46, 0.006, M['ribbon'],
                 seg=64, minor_seg=8)
    ring.data.materials[0].use_backface_culling = False
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0.005))
    sh = bpy.context.object
    sh.name = 'ContactShadow'
    sh.scale = (0.80, 0.54, 1.0)
    bpy.context.view_layer.objects.active = sh
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    sm = bpy.data.materials.new('ContactShadowMat')
    sm.use_nodes = True
    nodes, links = sm.node_tree.nodes, sm.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    t = nodes.new('ShaderNodeTexImage')
    t.image = TEX['T_Shadow']
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(t.outputs['Alpha'], bsdf.inputs['Alpha'])
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    sm.blend_method = 'BLEND'
    sm.shadow_method = 'NONE'
    sm.use_backface_culling = False
    sh.data.materials.append(sm)

    def area(name, loc, energy, size, color, target):
        l = bpy.data.lights.new(name, 'AREA')
        l.energy = energy
        l.shape = 'DISK'
        l.size = size
        l.color = color
        o = bpy.data.objects.new(name, l)
        link(o)
        o.location = loc
        look_at(o, target)
        return o

    target = (0, 0, m['height'] * 0.55)
    area('Key', (2.5, -3.1, 3.3), 760, 3.6, (1.0, 0.82, 0.66), target)
    area('Fill', (-2.9, -2.0, 1.8), 300, 3.0, (0.62, 0.74, 1.0), target)
    area('Rim', (0.5, 2.8, 2.9), 480, 2.6, (0.72, 1.0, 0.82), target)
    area('Top', (0, 0, 4.2), 150, 3.0, (1.0, 0.93, 0.84), target)
    cam_d = bpy.data.cameras.new('Camera')
    cam_d.lens = 70
    cam_d.sensor_width = 36
    cam = bpy.data.objects.new('Camera', cam_d)
    link(cam)
    cam.location = (0, -3.4, m['height'] * 0.58)
    look_at(cam, target)
    sc.camera = cam
    return cam


# --------------------------------------------------------------------------
# GLB export
# --------------------------------------------------------------------------

def build_export_materials():
    cache = {}
    for name, (kind, val) in EXPORT_SPEC.items():
        m = bpy.data.materials.new(name + '_glTF')
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        b = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if b is None:
            b = nodes.new('ShaderNodeBsdfPrincipled')
        if kind == 'tex':
            tex = nodes.new('ShaderNodeTexImage')
            tex.image = val
            tex.location = (-320, 180)
            links.new(tex.outputs['Color'], b.inputs['Base Color'])
        else:
            _set(b, ['Base Color'], (*val, 1))
        _set(b, ['Roughness'], 0.82)
        _set(b, ['Metallic'], 0.0)
        if name == 'OutlineMat':
            m.use_backface_culling = True
        cache[name] = m
    return cache


def export_glb(char, outline, arm, glb_path):
    export_mats = build_export_materials()
    originals = []
    for o in (char, outline):
        for slot in o.material_slots:
            if slot.material and slot.material.name in export_mats:
                originals.append((slot, slot.material))
                slot.material = export_mats[slot.material.name]
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    char.select_set(True)
    outline.select_set(True)
    bpy.context.view_layer.objects.active = arm
    t0 = time.time()
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB',
                              use_selection=True, export_animations=False,
                              export_apply=False, export_yup=True,
                              export_texcoords=True, export_normals=True,
                              export_materials='EXPORT')
    dt = time.time() - t0
    for slot, mat in originals:
        slot.material = mat
    return dt


# --------------------------------------------------------------------------
# build entry
# --------------------------------------------------------------------------

def load_json(path):
    with open(path, 'r', encoding='utf-8') as f:
        return json.load(f)


def write_json(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    return path


def build_character(preset, design, out_dir, char_name=None, outline=True,
                    tripo_status=None):
    global PARTS
    t_start = time.time()
    os.makedirs(out_dir, exist_ok=True)
    tex_dir = os.path.join(out_dir, 'textures')
    reset_scene(preset)
    tex = build_textures(tex_dir, design['palette'], design, size=512)
    M = build_materials(design['palette'])
    M['_palette'] = design['palette']
    m = metrics_from_preset(preset)
    build_rig(m)
    build_head(m, M, design)
    head_bbox = bbox_of([HEAD])
    eye_objs = [o for o in PARTS if o.get('role') == 'eye_white']
    eye_bbox = bbox_of(eye_objs)
    build_hair(m, M, design)
    build_body(m, M)
    build_hands(m, M)
    build_outfit(m, M)
    name = char_name or design.get('name', 'AnimeGirl')
    char = join_character(ARM, name)
    outline_obj = add_outline(char, M['outline']) if outline else None
    build_stage(m, M)
    blend_path = os.path.join(out_dir, name + '.blend')
    glb_path = os.path.join(out_dir, name + '.glb')
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    glb_sec = export_glb(char, outline_obj or char, ARM, glb_path)
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    metrics = measure_mesh(char)
    outline_metrics = measure_mesh(outline_obj) if outline_obj else None
    manifest = {
        'character': design.get('display_name', name),
        'id': name,
        'tier': preset.get('tier', 'L2'),
        'route': 'blender-only' if not tripo_status or
                 tripo_status.get('status') != 'success' else 'tripo+blender',
        'created': time.strftime('%Y-%m-%dT%H:%M:%S'),
        'blender': {
            'version': bpy.app.version_string,
            'engine': bpy.context.scene.render.engine,
            'view_transform': bpy.context.scene.view_settings.view_transform,
        },
        'preset': preset,
        'design': design,
        'proportions': {
            'height_m': round(m['height'], 4),
            'head_h_m': round(m['head_h'], 4),
            'head_ratio': round(m['head_ratio'], 3),
            'eye_line_from_chin': round(m['eye_line_from_chin'], 4),
            'eye_line_from_top': round(m['eye_line_from_top'], 4),
            'head_bbox': [round(x, 4) for x in head_bbox] if head_bbox else None,
            'eye_bbox': [round(x, 4) for x in eye_bbox] if eye_bbox else None,
        },
        'mesh': metrics,
        'outline': outline_metrics,
        'armature': {
            'bones': len(ARM.data.bones),
            'deform_bones': len([b for b in ARM.data.bones if b.use_deform]),
            'names': [b.name for b in ARM.data.bones],
        },
        'textures': {k: [int(v.size[0]), int(v.size[1])]
                     for k, v in TEX.items()},
        'files': {
            'blend': os.path.relpath(blend_path, out_dir),
            'glb': os.path.relpath(glb_path, out_dir),
            'glb_bytes': os.path.getsize(glb_path),
        },
        'render': preset.get('render', {}),
        'timings_s': {'build': round(time.time() - t_start, 2),
                      'glb_export': round(glb_sec, 2)},
        'licenses': {
            'references': 'original',
            'geometry': 'procedural (this toolkit)',
            'textures': ['procedural (this toolkit)'],
            'external_assets': [],
        },
        'tripo': tripo_status or {
            'status': 'skipped',
            'reason': 'TRIPO_API_KEY unset; Blender-only fallback',
        },
    }
    write_json(os.path.join(out_dir, 'manifest.json'), manifest)
    print('ANIME_BUILD_OK name=%s tris=%d tris_outline=%s verts=%d bones=%d '
          'deform=%d mats=%d glb_bytes=%d build_s=%.1f glb_s=%.1f' % (
              name, metrics['tris'],
              outline_metrics['tris'] if outline_metrics else 0,
              metrics['verts'], len(ARM.data.bones),
              len([b for b in ARM.data.bones if b.use_deform]),
              metrics['materials'], os.path.getsize(glb_path),
              manifest['timings_s']['build'], glb_sec))
    return manifest
