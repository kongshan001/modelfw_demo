"""青禾 / Qinghe — original cute-anime herbalist apprentice, procedural build.

Capability probe for the game-artist agent (T-20261121-029).
Blender 3.4.1 headless / EEVEE Legacy / toon Shader-to-RGB + inverted-hull outline.

  /Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/build_qinghe.py

All geometry, textures and the rig are generated here; no external assets.
Design: teal bob + twin side buns, big amber eyes, cream apron over a jade dress,
brown satchel with herbs, gold trim. ~4.8 heads, light chibi.

Outputs (project root): qinghe.blend, qinghe.glb, textures/*.png
"""

import math
import os

import bpy
import bmesh
import numpy as np
from mathutils import Vector

PI = math.pi
TAU = PI * 2.0
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, 'qinghe.blend')
GLB = os.path.join(ROOT, 'qinghe.glb')
TEX = os.path.join(ROOT, 'textures')
os.makedirs(TEX, exist_ok=True)

# ── palette (sRGB hex → linear for shader sockets) ─────────────────────────

def srgb(hexstr):
    h = hexstr.lstrip('#')
    rgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
                 for c in rgb)


PAL = {
    'skin': '#F7D6C3', 'skin_shadow': '#E3AF9A', 'blush': '#F2A49C',
    'hair': '#2F6157', 'jade': '#4F8272', 'jade_dark': '#386153',
    'cream': '#F6EDD9', 'gold': '#D8B563',
    'leather': '#6E4B37', 'leather_dark': '#4A3126', 'leaf': '#79A45E',
    'iris': '#D9A03F', 'mouth': '#B2545A', 'outline': '#2A1D18',
    'lash': '#3A2A24', 'brow': '#4A3A2E',
}

# ── scene / material helpers ────────────────────────────────────────────────

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_EEVEE'
    sc.eevee.taa_render_samples = 32
    sc.eevee.use_gtao = True
    sc.eevee.gtao_distance = 0.18
    sc.eevee.use_bloom = True
    sc.eevee.bloom_intensity = 0.025
    sc.eevee.bloom_threshold = 1.0
    sc.eevee.bloom_radius = 5.0
    sc.render.resolution_x = 1440
    sc.render.resolution_y = 1800
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


def set_in(node, names, value):
    for n in names:
        if n in node.inputs:
            node.inputs[n].default_value = value
            return True
    return False


EXPORT_SPEC = {}          # material name -> ('color', rgb) | ('tex', image)


def _base_out(nt):
    nodes, links = nt.nodes, nt.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    out.location = (420, 0)
    return nodes, links, out


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


def mat_flat(name, hexcol, rough=0.8, backface=False, blend=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes, links, out = _base_out(m.node_tree)
    b = nodes.new('ShaderNodeBsdfPrincipled')
    b.location = (200, 0)
    rgb = srgb(hexcol)
    set_in(b, ['Base Color'], (*rgb, 1))
    set_in(b, ['Roughness'], rough)
    set_in(b, ['Specular'], 0.2)
    links.new(b.outputs['BSDF'], out.inputs['Surface'])
    m.diffuse_color = (*rgb, 1)
    m.use_backface_culling = backface
    if blend:
        m.blend_method = 'BLEND'
        m.shadow_method = 'NONE'
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
    m.diffuse_color = (*srgb(PAL['iris']), 1)
    EXPORT_SPEC[name] = ('tex', img)
    return m


# ── procedural textures ─────────────────────────────────────────────────────

def make_image(name, size, fn, alpha=False):
    img = bpy.data.images.new(name, width=size, height=size, alpha=alpha)
    px = np.zeros((size, size, 4), dtype=np.float32)
    for y in range(size):
        v = y / (size - 1)
        for x in range(size):
            u = x / (size - 1)
            r, g, b, a = fn(u, v)
            px[y, x] = (r, g, b, a)
    img.pixels.foreach_set(px.ravel())
    img.update()
    img.filepath_raw = os.path.join(TEX, name + '.png')
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def hx(hexstr):
    h = hexstr.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def build_textures():
    hair = hx(PAL['hair'])
    hair_hi = hx('#5A9483')
    jade = hx(PAL['jade'])
    jade_dk = hx(PAL['jade_dark'])
    cream = hx(PAL['cream'])

    def tex_hair(u, v):
        strand = math.sin(u * 151.0 + math.sin(v * 9.0) * 1.6)
        strand2 = math.sin(u * 63.0 + math.sin(v * 4.0))
        strand3 = math.sin(u * 311.0 + v * 2.0)
        sheen = 0.5 + 0.5 * math.sin(v * 14.0 + 0.7)
        t = 0.5 + 0.5 * (0.48 * strand + 0.34 * strand2 + 0.18 * strand3)
        t = t * 0.93 + sheen * 0.07
        mix = 0.14 + 0.64 * t
        r = hair[0] * (1 - mix) + hair_hi[0] * mix
        g = hair[1] * (1 - mix) + hair_hi[1] * mix
        b = hair[2] * (1 - mix) + hair_hi[2] * mix
        return (r, g, b, 1.0)

    def tex_dress(u, v):
        weave = math.sin((u + v) * 190.0) * math.sin((u - v) * 190.0)
        shade = 0.94 + 0.06 * weave + 0.03 * math.sin(v * 23.0)
        seam = 1.0
        if abs(u - 0.5) < 0.025:
            seam = 1.07
        r = jade[0] * shade * seam
        g = jade[1] * shade * seam
        b = jade[2] * shade * seam
        return (min(r, 1), min(g, 1), min(b, 1), 1.0)

    def tex_apron(u, v):
        weave = (math.sin(u * 420.0) * math.sin(v * 420.0)) * 0.5 + 0.5
        shade = 0.95 + 0.05 * weave
        # little sage leaf sprig embroidery, front centre low
        du, dv = u - 0.5, v - 0.16
        leaf = 0.0
        for k, (ox, oz, ang) in enumerate(((-0.035, 0.0, 0.7), (0.0, 0.025, 1.5708),
                                           (0.035, 0.0, 2.4))):
            ca, sa = math.cos(ang), math.sin(ang)
            px_, pz_ = du - ox, dv - oz
            lx = px_ * ca + pz_ * sa
            lz = -px_ * sa + pz_ * ca
            if (lx / 0.026) ** 2 + (lz / 0.010) ** 2 < 1.0:
                leaf = 1.0
        if (du / 0.0045) ** 2 + ((dv + 0.04) / 0.055) ** 2 < 1.0:
            leaf = max(leaf, 0.85)
        r = cream[0] * shade
        g = cream[1] * shade
        b = cream[2] * shade
        if leaf > 0:
            r = r * (1 - 0.55 * leaf) + jade[0] * 0.55 * leaf
            g = g * (1 - 0.55 * leaf) + jade[1] * 0.55 * leaf
            b = b * (1 - 0.55 * leaf) + jade[2] * 0.55 * leaf
        return (min(r, 1), min(g, 1), min(b, 1), 1.0)

    def tex_iris(u, v):
        dx, dy = (u - 0.5) * 2.0, (v - 0.5) * 2.0
        r = min(1.0, math.hypot(dx, dy))
        ang = math.atan2(dy, dx)
        base = hx(PAL['iris'])
        deep = hx('#8A5A1E')
        light = hx('#F5D27A')
        t = max(0.0, min(1.0, (r - 0.22) / 0.72))
        rr = light[0] * (1 - t) + base[0] * t
        gg = light[1] * (1 - t) + base[1] * t
        bb = light[2] * (1 - t) + base[2] * t
        fiber = 0.5 + 0.5 * math.sin(ang * 26.0 + r * 15.0)
        rr = rr * (0.90 + 0.14 * fiber)
        gg = gg * (0.90 + 0.14 * fiber)
        bb = bb * (0.90 + 0.14 * fiber)
        if dy < -0.28 and 0.35 < r < 0.95:
            k = (-dy - 0.28) * 0.55
            rr = min(1, rr + k)
            gg = min(1, gg + k * 0.9)
        if r > 0.86:
            rr, gg, bb = deep
        # dark limbal ring + centre falloff (pupil disc covers the centre)
        if r < 0.30:
            rr, gg, bb = (rr * 0.4, gg * 0.35, bb * 0.3)
        if r > 0.99:
            rr, gg, bb = 0.02, 0.01, 0.01
        return (rr, gg, bb, 1.0)

    def tex_shadow(u, v):
        dx, dy = (u - 0.5) * 2.0, (v - 0.5) * 2.0
        d = min(1.0, math.hypot(dx, dy))
        a = max(0.0, 1.0 - d) ** 1.8
        return (0.06, 0.045, 0.035, a * 0.72)

    def tex_backdrop(u, v):
        top = hx('#DDD9EA')
        bottom = hx('#F3E6D2')
        t = v
        return (top[0] * t + bottom[0] * (1 - t),
                top[1] * t + bottom[1] * (1 - t),
                top[2] * t + bottom[2] * (1 - t), 1.0)

    return {
        'hair': make_image('T_Hair', 256, tex_hair),
        'dress': make_image('T_Dress', 256, tex_dress),
        'apron': make_image('T_Apron', 256, tex_apron),
        'iris': make_image('T_EyeIris', 256, tex_iris),
        'shadow': make_image('T_Shadow', 256, tex_shadow, alpha=True),
        'backdrop': make_image('T_Backdrop', 256, tex_backdrop),
    }


# ── mesh helpers ────────────────────────────────────────────────────────────

PARTS = []


def register(o):
    PARTS.append(o)
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
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=b.name)
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def torus(name, loc, major, minor, material, rot=(0, 0, 0), scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=32, minor_segments=8,
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
    """Closed ring tube through points with per-ring radius."""
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


def blade(name, base, direction, length, width, thickness, material,
          sections=5, bend=(0, 0, 0), uv_flip=False):
    """Flat tapered hair / cloth blade with a raised centre ridge."""
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
    faces.append((r0[0], r0[4], r0[3], r0[2], r0[1]))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def ribbon(name, points, widths, material, uv_v=True):
    verts, uvs, faces = [], [], []
    n = len(points)
    prev_side = None
    rings = []
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


# face is an ellipsoid: used to hug eye / brow / blush decals to the head
FACE_C = (0.0, 0.0, 1.145)
FACE_R = (0.141, 0.131, 0.138)


def face_y(x, z):
    t = 1.0 - (x / FACE_R[0]) ** 2 - ((z - FACE_C[2]) / FACE_R[2]) ** 2
    return -FACE_R[1] * math.sqrt(max(0.02, t))


def face_patch(name, cx, cz, rx, rz, material, offset=0.005, rings=4,
               segs=40):
    """Oval decal projected onto the head ellipsoid (curved, not a floating disc)."""
    verts, uvs, faces = [], [], []
    verts.append((cx, face_y(cx, cz) - offset, cz))
    uvs.append((0.5, 0.5))
    for ri in range(1, rings + 1):
        f = ri / rings
        for si in range(segs):
            a = TAU * si / segs
            dx = math.cos(a) * rx * f
            dz = math.sin(a) * rz * f
            x, z = cx + dx, cz + dz
            verts.append((x, face_y(x, z) - offset, z))
            uvs.append((0.5 + dx / (2 * rx), 0.5 + dz / (2 * rz)))
    for si in range(segs):
        j = (si + 1) % segs
        faces.append((0, 1 + si, 1 + j))
    for ri in range(1, rings):
        a = 1 + (ri - 1) * segs
        b = 1 + ri * segs
        for si in range(segs):
            j = (si + 1) % segs
            faces.append((a + si, b + si, b + j, a + j))
    return mesh_obj(name, verts, faces, material, uvs=uvs)


def face_band(name, cx, cz, rx, rz, a0, a1, width, material, offset=0.006,
              segs=24, inner=0.88):
    """Curved band over the face sphere — eyelash line / brow."""
    verts, uvs, faces = [], [], []
    for i in range(segs + 1):
        a = a0 + (a1 - a0) * i / segs
        for k, f in ((0, 1.0), (1, inner)):
            x = cx + math.cos(a) * rx * f
            z = cz + math.sin(a) * rz * f - (width if k else 0.0)
            verts.append((x, face_y(x, z) - offset, z))
            uvs.append((i / segs, k))
    for i in range(segs):
        a = i * 2
        faces.append((a, a + 1, a + 3, a + 2))
    o = mesh_obj(name, verts, faces, material, uvs=uvs)
    o.data.materials[0].use_backface_culling = False
    return o


# ── armature ────────────────────────────────────────────────────────────────

ARM = None
BONES = {}
DEFORM = ['hips', 'spine', 'chest', 'neck', 'head',
          'shoulder.L', 'upper_arm.L', 'forearm.L', 'hand.L',
          'shoulder.R', 'upper_arm.R', 'forearm.R', 'hand.R',
          'thigh.L', 'shin.L', 'foot.L', 'toe.L',
          'thigh.R', 'shin.R', 'foot.R', 'toe.R']


def build_armature():
    global ARM
    arm_data = bpy.data.armatures.new('QingheRig')
    ARM = link(bpy.data.objects.new('QingheRig', arm_data))
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

    bone('root', (0, 0, 0), (0, 0, 0.12), deform=False)
    bone('hips', (0, 0, 0.595), (0, 0, 0.675), 'root')
    bone('spine', (0, 0, 0.675), (0, 0, 0.775), 'hips', True)
    bone('chest', (0, 0, 0.775), (0, 0, 0.900), 'spine', True)
    bone('neck', (0, 0, 0.900), (0, 0, 0.985), 'chest', True)
    bone('head', (0, 0, 0.985), (0, 0, 1.285), 'neck', True)
    for s, sy in (('L', 1.0), ('R', -1.0)):
        bone('shoulder.' + s, (sy * 0.015, 0, 0.885),
             (sy * 0.105, 0, 0.885), 'chest')
        bone('upper_arm.' + s, (sy * 0.105, 0, 0.885),
             (sy * 0.192, -0.006, 0.812), 'shoulder.' + s, True)
        bone('forearm.' + s, (sy * 0.192, -0.006, 0.812),
             (sy * 0.262, -0.012, 0.742), 'upper_arm.' + s, True)
        bone('hand.' + s, (sy * 0.262, -0.012, 0.742),
             (sy * 0.318, -0.016, 0.698), 'forearm.' + s, True)
        bone('thigh.' + s, (sy * 0.075, 0, 0.620),
             (sy * 0.078, 0, 0.360), 'hips')
        bone('shin.' + s, (sy * 0.078, 0, 0.360),
             (sy * 0.080, 0, 0.095), 'thigh.' + s, True)
        bone('foot.' + s, (sy * 0.080, 0, 0.095),
             (sy * 0.080, -0.105, 0.035), 'shin.' + s, True)
        bone('toe.' + s, (sy * 0.080, -0.105, 0.035),
             (sy * 0.080, -0.155, 0.028), 'foot.' + s, True)
    bpy.ops.object.mode_set(mode='OBJECT')
    return ARM


# ── weighting ───────────────────────────────────────────────────────────────

def _dist(p, a, b):
    ab = b - a
    t = 0.0 if ab.length_squared < 1e-10 else max(
        0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def weight_nearest(o, names, k=2, power=4.0, floor=1e-4):
    groups = {n: o.vertex_groups.new(name=n) for n in names}
    acc = {n: [] for n in names}
    for v in o.data.vertices:
        p = v.co
        ds = sorted((_dist(p, *BONES[n]), n) for n in names)[:k]
        total = 0.0
        vals = []
        for d, n in ds:
            w = 1.0 / ((d + floor) ** power)
            vals.append((n, w))
            total += w
        for n, w in vals:
            acc[n].append((v.index, w / total))
    for n, entries in acc.items():
        for idx, w in entries:
            groups[n].add([idx], w, 'REPLACE')
    return o


def weight_rigid(o, bone_name):
    vg = o.vertex_groups.new(name=bone_name)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    return o


# ── head + face ─────────────────────────────────────────────────────────────

def join_union(parts, name, voxel=None, smooth=0.0, iters=2):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = name
    if voxel:
        rem = o.modifiers.new('voxel', 'REMESH')
        rem.mode = 'VOXEL'
        rem.voxel_size = voxel
        rem.use_smooth_shade = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=rem.name)
    if smooth > 0.0:
        sm = o.modifiers.new('smooth', 'SMOOTH')
        sm.factor = smooth
        sm.iterations = iters
        bpy.ops.object.modifier_apply(modifier=sm.name)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def face_tube(name, pts_xz, radius, material, offset=0.004, segs=8):
    pts = [(x, face_y(x, z) - offset, z) for x, z in pts_xz]
    return tube(name, pts, [radius] * len(pts), material, segments=segs)


def build_head(M):
    parts = [sphere('skull', (0, 0.008, 1.163), (0.139, 0.128, 0.128),
                    M['skin'], 32, 22),
             sphere('cheekL', (0.045, -0.018, 1.102), (0.086, 0.084, 0.076),
                    M['skin'], 24, 16),
             sphere('cheekR', (-0.045, -0.018, 1.102), (0.086, 0.084, 0.076),
                    M['skin'], 24, 16),
             sphere('chin', (0, -0.012, 1.072), (0.056, 0.062, 0.052),
                    M['skin'], 24, 16)]
    head = join_union(parts, 'Head', voxel=0.005, smooth=0.55, iters=2)
    head.data.materials.clear()
    head.data.materials.append(M['skin'])
    weight_rigid(head, 'head')
    register(head)

    for sy in (1, -1):
        ear = sphere('ear', (sy * 0.138, 0.004, 1.13),
                     (0.016, 0.026, 0.036), M['skin'], 16, 12)
        weight_rigid(ear, 'head')
        register(ear)

    # eyes — layered, curved decals hugging the head ellipsoid
    for sy in (1, -1):
        ex, ez = sy * 0.055, 1.135
        p = face_patch('eye_white', ex, ez, 0.0410, 0.0510, M['eye_white'],
                       offset=0.0045, rings=3)
        weight_rigid(p, 'head')
        register(p)
        p = face_patch('iris', ex, ez, 0.0295, 0.0295, M['iris'],
                       offset=0.0062, rings=3, segs=36)
        weight_rigid(p, 'head')
        register(p)
        p = face_patch('pupil', ex, ez, 0.0135, 0.0135, M['pupil'],
                       offset=0.0074, rings=2, segs=28)
        weight_rigid(p, 'head')
        register(p)
        p = face_patch('hi_big', ex - 0.0095, ez + 0.0125, 0.0086, 0.0086,
                       M['highlight'], offset=0.0082, rings=2, segs=20)
        weight_rigid(p, 'head')
        register(p)
        p = face_patch('hi_small', ex + 0.0105, ez - 0.0120, 0.0044, 0.0044,
                       M['highlight'], offset=0.0082, rings=2, segs=16)
        weight_rigid(p, 'head')
        register(p)
        lash = face_band('lash', ex, ez, 0.0445, 0.0555, 0.18, PI - 0.18,
                         0.0095, M['lash'], offset=0.0064, segs=28,
                         inner=0.86)
        weight_rigid(lash, 'head')
        register(lash)
        brow_pts = []
        for i in range(5):
            t = i / 4.0
            x = ex - 0.026 + 0.052 * t
            z = 1.197 + 0.005 * math.sin(PI * t)
            brow_pts.append((x, z))
        brow = face_tube('brow', brow_pts, 0.0022, M['brow'], offset=0.0045)
        weight_rigid(brow, 'head')
        register(brow)
        blush = face_patch('blush', sy * 0.083, 1.081, 0.025, 0.012,
                           M['blush'], offset=0.0028, rings=2, segs=24)
        weight_rigid(blush, 'head')
        register(blush)

    nose = face_patch('nose', 0.0, 1.098, 0.0065, 0.0045, M['skin_shadow'],
                      offset=0.0026, rings=2, segs=16)
    weight_rigid(nose, 'head')
    register(nose)
    smile = [(-0.024, 1.0695), (-0.014, 1.0640), (0, 1.0620),
             (0.014, 1.0640), (0.024, 1.0695)]
    mouth = face_tube('mouth', smile, 0.0026, M['mouth'], offset=0.0032,
                      segs=8)
    weight_rigid(mouth, 'head')
    register(mouth)


# ── hair ────────────────────────────────────────────────────────────────────

def build_hair(M):
    hair = M['hair']
    # cap pulled back so the face is not swallowed; fringe sits in front
    cap = sphere('hair_cap', (0, 0.035, 1.165), (0.146, 0.138, 0.146),
                 hair, 32, 22)
    weight_rigid(cap, 'head')
    register(cap)
    back = sphere('hair_back', (0, 0.075, 1.072), (0.133, 0.100, 0.180),
                  M['hair_dark'], 32, 22)
    weight_rigid(back, 'head')
    register(back)

    # fringe, tips end above the brows (centre slightly shorter)
    for i in range(7):
        x = -0.084 + 0.028 * i
        b = Vector((x, -0.088 + 0.006 * abs(i - 3), 1.270))
        d = Vector((x * 2.2, -0.40, -1.0)).normalized()
        ln = 0.058 + 0.008 * abs(i - 3) / 3.0
        o = blade('bang_%d' % i, b, d, ln, 0.030, 0.012, hair,
                  sections=4, bend=(x * 0.05, -0.012, -0.004))
        weight_rigid(o, 'head')
        register(o)
    # asymmetric sweeping lock over the fringe
    o = blade('bang_sweep', (0.012, -0.108, 1.274),
              (0.52, -0.26, -1.0), 0.088, 0.021, 0.008, hair,
              sections=5, bend=(0.028, -0.010, -0.006))
    weight_rigid(o, 'head')
    register(o)
    # long curtains framing the cheeks
    for sy in (1, -1):
        b = (sy * 0.095, -0.045, 1.262)
        d = (sy * 0.28, -0.25, -1.0)
        o = blade('side_bang', b, d, 0.170, 0.042, 0.016, hair,
                  sections=6, bend=(sy * 0.020, -0.020, -0.010))
        weight_rigid(o, 'head')
        register(o)
        b = (sy * 0.140, -0.035, 1.200)
        d = (sy * 0.04, -0.16, -1.0)
        o = blade('side_lock', b, d, 0.190, 0.032, 0.014, hair,
                  sections=6, bend=(sy * 0.008, -0.012, -0.006))
        weight_rigid(o, 'head')
        register(o)
        # twin side buns, outside the cap silhouette
        bun = sphere('bun', (sy * 0.152, 0.045, 1.255),
                     (0.046, 0.046, 0.046), hair, 24, 16)
        weight_rigid(bun, 'head')
        register(bun)
        band = torus('bun_band', (sy * 0.128, 0.045, 1.235), 0.030, 0.006,
                     M['gold'], rot=(0, PI / 2, 0))
        weight_rigid(band, 'head')
        register(band)
    # nape locks, outside the back volume
    for i in range(5):
        x = (i - 2) * 0.048
        b = (x, 0.172, 1.045 + 0.012 * (2 - abs(i - 2)))
        d = (x * 0.8, 0.18, -1.0)
        o = blade('nape_%d' % i, b, d, 0.100, 0.030, 0.012,
                  M['hair_dark'], sections=4, bend=(0, 0.01, -0.008))
        weight_rigid(o, 'head')
        register(o)
    # ahoge
    o = blade('ahoge', (0.012, 0.030, 1.300), (0.25, 0.18, 1.0),
              0.080, 0.011, 0.007, hair, sections=5,
              bend=(0.028, 0.018, 0.012))
    weight_rigid(o, 'head')
    register(o)
    # leaf hairpin on the left bun
    for k in range(3):
        ang = -0.5 + 0.5 * k
        b = (-0.158, 0.038 + 0.010 * k, 1.283)
        d = (math.sin(ang) * 0.55 - 0.25, 0.12, 0.95)
        leaf = blade('pin_leaf_%d' % k, b, d, 0.052, 0.012, 0.005,
                     M['leaf'], sections=4, bend=(0.004, 0.004, 0.008))
        weight_rigid(leaf, 'head')
        register(leaf)
    bead = sphere('pin_bead', (-0.154, 0.035, 1.276), (0.009, 0.009, 0.009),
                  M['gold'], 12, 8)
    weight_rigid(bead, 'head')
    register(bead)
    # small ribbon at the back
    for sy in (1, -1):
        b = (sy * 0.018, 0.172, 1.120)
        d = (sy * 0.55, 0.25, -0.8)
        o = blade('hair_ribbon', b, d, 0.075, 0.022, 0.007, M['jade_dark'],
                  sections=4, bend=(sy * 0.01, 0.01, -0.005))
        weight_rigid(o, 'head')
        register(o)
    knot = sphere('ribbon_knot', (0, 0.170, 1.126), (0.012, 0.012, 0.016),
                  M['jade_dark'], 12, 8)
    weight_rigid(knot, 'head')
    register(knot)


# ── skin body + hands ───────────────────────────────────────────────────────

def build_skin_body(M):
    skin = M['skin']
    parts = []
    torso = tube('torso', [(0, 0, 0.60), (0, 0, 0.66), (0, 0, 0.72),
                           (0, 0, 0.80), (0, 0, 0.865), (0, 0, 0.898)],
                 [0.112, 0.098, 0.086, 0.094, 0.098, 0.085], skin,
                 segments=24)
    torso.scale = (1.0, 0.72, 1.0)
    bpy.context.view_layer.objects.active = torso
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    parts.append(torso)
    parts.append(sphere('hip_vol', (0, 0, 0.618), (0.104, 0.080, 0.076),
                        skin, 24, 16))
    parts.append(tube('neck', [(0, 0, 0.955), (0, 0.004, 1.015),
                               (0, 0.006, 1.055)],
                      [0.033, 0.031, 0.036], skin, segments=20))
    for sy in (1, -1):
        parts.append(sphere('shoulder', (sy * 0.100, 0, 0.878),
                            (0.048, 0.044, 0.046), skin, 20, 14))
        parts.append(tube('upper_arm',
                          [(sy * 0.100, 0, 0.878),
                           (sy * 0.150, -0.003, 0.846),
                           (sy * 0.192, -0.006, 0.812)],
                          [0.034, 0.031, 0.029], skin, segments=18))
        parts.append(sphere('elbow', (sy * 0.192, -0.006, 0.812),
                            (0.030, 0.029, 0.031), skin, 18, 12))
        parts.append(tube('forearm',
                          [(sy * 0.192, -0.006, 0.812),
                           (sy * 0.228, -0.009, 0.778),
                           (sy * 0.262, -0.012, 0.742)],
                          [0.028, 0.026, 0.023], skin, segments=18))
        parts.append(sphere('thigh_top', (sy * 0.072, 0, 0.615),
                            (0.066, 0.062, 0.070), skin, 22, 14))
        parts.append(tube('thigh',
                          [(sy * 0.072, 0, 0.615),
                           (sy * 0.075, 0, 0.50),
                           (sy * 0.078, 0, 0.37)],
                          [0.061, 0.054, 0.046], skin, segments=20))
        parts.append(sphere('knee', (sy * 0.078, 0, 0.365),
                            (0.046, 0.045, 0.047), skin, 18, 12))
        parts.append(tube('shin',
                          [(sy * 0.078, 0, 0.365),
                           (sy * 0.079, 0, 0.24),
                           (sy * 0.080, 0, 0.125)],
                          [0.044, 0.038, 0.030], skin, segments=18))
    body = join_union(parts, 'SkinBody', voxel=0.006, smooth=0.50, iters=2)
    body.data.materials.clear()
    body.data.materials.append(skin)
    weight_nearest(body, ['hips', 'spine', 'chest', 'neck',
                          'shoulder.L', 'upper_arm.L', 'forearm.L',
                          'shoulder.R', 'upper_arm.R', 'forearm.R',
                          'thigh.L', 'shin.L', 'thigh.R', 'shin.R'],
                   k=2, power=4.5)
    register(body)


def build_hand(M, sy):
    skin = M['skin']
    s = 'L' if sy > 0 else 'R'
    wrist = Vector((sy * 0.262, -0.012, 0.742))
    d = Vector((sy * 0.068, -0.006, -0.070)).normalized()
    side = Vector((0, 1, 0))
    parts = []
    palm_c = wrist + d * 0.022
    rot_y = math.atan2(d.x, d.z)
    parts.append(sphere('palm', palm_c, (0.025, 0.021, 0.034), skin, 20, 14,
                        rot=(0, rot_y, 0)))
    for i in range(4):
        start = palm_c + d * 0.024 + side * ((i - 1.5) * 0.0098)
        mid = start + d * 0.016
        end = start + d * 0.031
        parts.append(tube('finger_%d' % i, [start, mid, end],
                          [0.0063, 0.0058, 0.0042], skin, segments=10))
    thumb_a = palm_c + Vector((0, -0.019, 0.004))
    thumb_b = thumb_a + Vector((sy * 0.010, -0.014, -0.012))
    parts.append(tube('thumb', [thumb_a, thumb_b], [0.0075, 0.0048], skin,
                      segments=10))
    hand = join_union(parts, 'Hand_' + s)
    weight_rigid(hand, 'hand.' + s)
    register(hand)


# ── outfit ──────────────────────────────────────────────────────────────────

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
    o.data.materials[0].use_backface_culling = False
    return o


def build_outfit(M):
    # dress
    dress = tube('dress',
                 [(0, 0, 0.898), (0, 0, 0.850), (0, 0, 0.780),
                  (0, 0, 0.720), (0, 0, 0.660), (0, 0, 0.605),
                  (0, 0, 0.572)],
                 [0.098, 0.112, 0.104, 0.090, 0.104, 0.148, 0.174],
                 M['dress'], segments=28)
    dress.scale = (1.0, 0.90, 1.0)
    bpy.context.view_layer.objects.active = dress
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    weight_nearest(dress, ['hips', 'spine', 'chest',
                           'thigh.L', 'thigh.R'], k=2, power=2.6)
    register(dress)
    # hem trim
    hem = torus('dress_hem', (0, 0, 0.573), 0.174, 0.0055, M['cream'],
                scale=(1.0, 0.90, 1.0))
    weight_rigid(hem, 'hips')
    register(hem)
    # collar
    collar = torus('collar', (0, 0, 0.904), 0.049, 0.009, M['cream'],
                   scale=(1.0, 0.92, 1.0))
    weight_rigid(collar, 'chest')
    register(collar)
    # high collar + neckerchief shorten the visible neck and add a silhouette break
    high = tube('high_collar',
                [(0, 0, 0.902), (0, 0, 0.932), (0, 0, 0.960)],
                [0.060, 0.051, 0.044], M['dress'], segments=24)
    high.scale = (1.0, 0.92, 1.0)
    bpy.context.view_layer.objects.active = high
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    weight_rigid(high, 'chest')
    register(high)
    trim = torus('high_collar_trim', (0, 0, 0.960), 0.044, 0.006,
                 M['cream'], scale=(1.0, 0.92, 1.0))
    weight_rigid(trim, 'neck')
    register(trim)
    neck_band = torus('neck_ribbon', (0, 0, 0.966), 0.042, 0.0075,
                      M['cream'], scale=(1.0, 0.90, 1.0))
    weight_rigid(neck_band, 'neck')
    register(neck_band)
    knot = sphere('neck_knot', (0, -0.043, 0.955), (0.012, 0.010, 0.012),
                  M['jade_dark'], 12, 8)
    weight_rigid(knot, 'neck')
    register(knot)
    for sy in (1, -1):
        o = blade('neck_bow', (sy * 0.008, -0.046, 0.953),
                  (sy * 0.55, -0.10, -0.9), 0.043, 0.016, 0.006,
                  M['jade_dark'], sections=4,
                  bend=(sy * 0.006, -0.004, -0.002))
        weight_rigid(o, 'neck')
        register(o)
    # puff sleeves + cuffs
    for sy in (1, -1):
        s = 'L' if sy > 0 else 'R'
        puff = sphere('sleeve.' + s, (sy * 0.108, 0, 0.866),
                      (0.055, 0.052, 0.058), M['dress'], 20, 14)
        weight_nearest(puff, ['chest', 'shoulder.' + s, 'upper_arm.' + s],
                       k=2, power=3.0)
        register(puff)
        d = Vector((sy * 0.068, -0.006, -0.070)).normalized()
        cuff = torus('cuff.' + s, (sy * 0.157, -0.003, 0.836), 0.031, 0.007,
                     M['cream'], rot=d.to_track_quat('Z', 'Y').to_euler())
        weight_rigid(cuff, 'upper_arm.' + s)
        register(cuff)
    # sash + buckle + back bow
    sash = tube('sash', [(0, 0, 0.738), (0, 0, 0.704)],
                [0.094, 0.094], M['jade_dark'], segments=28)
    sash.scale = (1.0, 0.90, 1.0)
    bpy.context.view_layer.objects.active = sash
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    weight_rigid(sash, 'spine')
    register(sash)
    buckle = box('buckle', (0, -0.088, 0.721), (0.048, 0.012, 0.030),
                 M['gold'], bevel=0.005)
    weight_rigid(buckle, 'spine')
    register(buckle)
    for sy in (1, -1):
        b = (sy * 0.016, 0.086, 0.712)
        d = (sy * 0.55, 0.35, -0.75)
        o = blade('sash_tail', b, d, 0.115, 0.026, 0.008, M['jade_dark'],
                  sections=4, bend=(sy * 0.012, 0.008, -0.006))
        weight_rigid(o, 'spine')
        register(o)
    # apron
    rows = [(0.858, 0.108, 0.90), (0.800, 0.113, 0.90),
            (0.740, 0.104, 0.90), (0.680, 0.112, 0.90),
            (0.620, 0.138, 0.90), (0.578, 0.178, 0.90)]
    angles = [-0.94 + 1.88 * i / 16 for i in range(17)]
    apron = apron_panel('apron', rows, angles, M['apron'])
    weight_nearest(apron, ['hips', 'spine', 'chest',
                           'thigh.L', 'thigh.R'], k=2, power=2.5)
    register(apron)
    hem_pts, hem_radii = [], []
    r0, ysc = 0.183, 0.90
    for i in range(17):
        th = angles[i]
        hem_pts.append((r0 * math.sin(th), -r0 * ysc * math.cos(th), 0.579))
        hem_radii.append(0.0042)
    trim = tube('apron_trim', hem_pts, hem_radii, M['gold'], segments=8)
    weight_nearest(trim, ['hips', 'thigh.L', 'thigh.R'], k=2, power=2.0)
    register(trim)
    # apron straps over the shoulders
    for sy in (1, -1):
        pts = [(sy * 0.072, -0.096, 0.856), (sy * 0.068, -0.070, 0.888),
               (sy * 0.056, -0.010, 0.902), (sy * 0.050, 0.055, 0.888),
               (sy * 0.048, 0.086, 0.860)]
        strap = tube('apron_strap', pts, [0.0065] * 5, M['cream'],
                     segments=8)
        weight_nearest(strap, ['chest', 'spine'], k=2, power=2.0)
        register(strap)
    # socks
    for sy in (1, -1):
        s = 'L' if sy > 0 else 'R'
        sock = tube('sock.' + s,
                    [(sy * 0.079, 0, 0.338), (sy * 0.079, 0, 0.250),
                     (sy * 0.080, 0, 0.168)],
                    [0.042, 0.039, 0.040], M['cream'], segments=20)
        weight_nearest(sock, ['shin.' + s, 'foot.' + s], k=2, power=3.0)
        register(sock)
        band = torus('sock_band.' + s, (sy * 0.079, 0, 0.336), 0.043, 0.006,
                     M['jade'])
        weight_nearest(band, ['shin.' + s], k=1, power=3.0)
        register(band)
    # boots
    for sy in (1, -1):
        s = 'L' if sy > 0 else 'R'
        shaft = tube('boot_shaft.' + s,
                     [(sy * 0.080, 0, 0.190), (sy * 0.080, 0, 0.120),
                      (sy * 0.080, 0, 0.070)],
                     [0.045, 0.043, 0.048], M['leather'], segments=20)
        weight_nearest(shaft, ['shin.' + s, 'foot.' + s], k=2, power=4.0)
        register(shaft)
        foot = sphere('boot_foot.' + s, (sy * 0.080, -0.038, 0.046),
                      (0.049, 0.083, 0.046), M['leather'], 20, 14)
        weight_rigid(foot, 'foot.' + s)
        register(foot)
        toe = sphere('boot_toe.' + s, (sy * 0.080, -0.108, 0.038),
                     (0.043, 0.038, 0.035), M['leather'], 18, 12)
        weight_rigid(toe, 'toe.' + s)
        register(toe)
        sole = box('boot_sole.' + s, (sy * 0.080, -0.040, 0.011),
                   (0.098, 0.165, 0.022), M['leather_dark'], bevel=0.012)
        weight_rigid(sole, 'foot.' + s)
        register(sole)
        top = torus('boot_top.' + s, (sy * 0.080, 0, 0.190), 0.046, 0.006,
                    M['cream'])
        weight_nearest(top, ['shin.' + s], k=1, power=3.0)
        register(top)
        strap = torus('boot_strap.' + s, (sy * 0.080, 0, 0.140), 0.046, 0.005,
                      M['gold'])
        weight_nearest(strap, ['shin.' + s, 'foot.' + s], k=2, power=4.0)
        register(strap)
        # gold wrist cuff
        d = Vector((sy * 0.068, -0.006, -0.070)).normalized()
        cuff = torus('wrist_cuff.' + s, (sy * 0.258, -0.011, 0.746),
                     0.025, 0.006, M['gold'],
                     rot=d.to_track_quat('Z', 'Y').to_euler())
        weight_rigid(cuff, 'hand.' + s)
        register(cuff)
    # satchel with herb sprigs
    bag = box('satchel', (0.138, -0.008, 0.662), (0.050, 0.036, 0.058),
              M['leather'], bevel=0.012)
    weight_rigid(bag, 'hips')
    register(bag)
    flap = box('satchel_flap', (0.138, -0.042, 0.688), (0.052, 0.014, 0.034),
               M['leather_dark'], bevel=0.007)
    weight_rigid(flap, 'hips')
    register(flap)
    clasp = sphere('satchel_clasp', (0.138, -0.051, 0.672),
                   (0.009, 0.005, 0.009), M['gold'], 12, 8)
    weight_rigid(clasp, 'hips')
    register(clasp)
    strap_pts = [(-0.060, -0.088, 0.884), (-0.020, -0.101, 0.842),
                 (0.040, -0.100, 0.786), (0.098, -0.083, 0.724),
                 (0.134, -0.052, 0.686)]
    strap = tube('satchel_strap', strap_pts, [0.0075] * 5, M['leather'],
                 segments=8)
    weight_nearest(strap, ['chest', 'spine', 'hips'], k=2, power=2.2)
    register(strap)
    for k in range(3):
        b = (0.138 + 0.012 * (k - 1), -0.016 + 0.004 * k, 0.690)
        d = (0.28 * (k - 1) + 0.05, -0.10, 1.0)
        leaf = blade('herb_%d' % k, b, d, 0.065 - 0.008 * abs(k - 1),
                     0.014, 0.005, M['leaf'], sections=4,
                     bend=(0.010 * (k - 1), 0.004, 0.012))
        weight_rigid(leaf, 'hips')
        register(leaf)


# ── character assembly + outline ────────────────────────────────────────────

def join_character(arm):
    bpy.ops.object.select_all(action='DESELECT')
    for o in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    char = bpy.context.object
    char.name = 'Qinghe'
    char.data.name = 'QingheMesh'
    char.parent = arm
    char.matrix_parent_inverse.identity()
    mod = char.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_vertex_groups = True
    return char


DECAL_MATS = {'EyeWhite', 'EyeIris', 'Pupil', 'EyeHighlight', 'Lash',
              'Brow', 'Blush', 'Mouth', 'SkinShadow'}


def add_outline(char, mat):
    out = char.copy()
    out.data = char.data.copy()
    out.name = 'Qinghe_Outline'
    link(out)
    normals = [v.normal.copy() for v in out.data.vertices]
    for v, n in zip(out.data.vertices, normals):
        v.co += n * 0.0038
    skip = {i for i, slot in enumerate(out.material_slots)
            if slot.material and slot.material.name.split('.')[0] in DECAL_MATS}
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


# ── stage / lights / camera ─────────────────────────────────────────────────

def look_at(o, target):
    o.rotation_euler = (Vector(target) - o.location).to_track_quat(
        '-Z', 'Y').to_euler()


def area_light(name, loc, energy, size, color, target=(0, 0, 0.72)):
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


def build_stage(M, tex):
    sc = bpy.context.scene
    world = bpy.data.worlds.new('QingheWorld')
    world.use_nodes = True
    bg = world.node_tree.nodes['Background']
    bg.inputs['Color'].default_value = (*srgb('#C9CFC2'), 1.0)
    bg.inputs['Strength'].default_value = 0.35
    sc.world = world

    # seamless studio cyclorama
    bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=4.2, depth=6.0,
                                        end_fill_type='NOTHING',
                                        location=(0, 0, 2.9))
    wall = bpy.context.object
    wall.name = 'Cyclorama'
    m = bpy.data.materials.new('Backdrop')
    m.use_nodes = True
    nodes, links = m.node_tree.nodes, m.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    tc = nodes.new('ShaderNodeTexCoord')
    sep = nodes.new('ShaderNodeSeparateXYZ')
    ramp = nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = (*srgb('#F4E8D5'), 1)
    ramp.color_ramp.elements[1].position = 0.55
    ramp.color_ramp.elements[1].color = (*srgb('#E9E6DD'), 1)
    e = ramp.color_ramp.elements.new(1.0)
    e.color = (*srgb('#DCD9E9'), 1)
    emit = nodes.new('ShaderNodeEmission')
    emit.inputs['Strength'].default_value = 0.95
    links.new(tc.outputs['Generated'], sep.inputs['Vector'])
    links.new(sep.outputs['Z'], ramp.inputs['Fac'])
    links.new(ramp.outputs['Color'], emit.inputs['Color'])
    links.new(emit.outputs['Emission'], out.inputs['Surface'])
    m.use_backface_culling = False
    wall.data.materials.append(m)
    for p in wall.data.polygons:
        p.use_smooth = True

    # floor
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
    femit.inputs['Color'].default_value = (*srgb('#F1E7D6'), 1)
    femit.inputs['Strength'].default_value = 0.92
    flinks.new(femit.outputs['Emission'], fout.inputs['Surface'])
    floor.data.materials.append(fm)

    # stage ring
    ring = torus('stage_ring', (0, 0, 0.003), 0.47, 0.006, M['jade'])
    ring.data.materials[0].use_backface_culling = False

    # painterly contact shadow
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0.004))
    sh = bpy.context.object
    sh.name = 'ContactShadow'
    sh.scale = (0.84, 0.52, 1.0)
    bpy.context.view_layer.objects.active = sh
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    sm = bpy.data.materials.new('ContactShadowMat')
    sm.use_nodes = True
    nodes, links = sm.node_tree.nodes, sm.node_tree.links
    nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial')
    t = nodes.new('ShaderNodeTexImage')
    t.image = tex['shadow']
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Roughness'].default_value = 1.0
    links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    links.new(t.outputs['Alpha'], bsdf.inputs['Alpha'])
    links.new(bsdf.outputs['BSDF'], out.inputs['Surface'])
    sm.blend_method = 'BLEND'
    sm.shadow_method = 'NONE'
    sm.use_backface_culling = False
    sh.data.materials.append(sm)

    # lights
    area_light('Key', (2.6, -3.2, 3.4), 750, 3.6, (0.98, 0.80, 0.62))
    area_light('Fill', (-2.9, -2.0, 1.8), 280, 3.0, (0.55, 0.70, 1.0))
    area_light('Rim', (0.4, 2.8, 2.9), 520, 2.6, (0.62, 1.0, 0.82))
    area_light('Top', (0, 0, 4.2), 160, 3.0, (0.98, 0.92, 0.82))

    # camera
    cam_d = bpy.data.cameras.new('Camera')
    cam_d.lens = 70
    cam_d.sensor_width = 36
    cam = bpy.data.objects.new('Camera', cam_d)
    link(cam)
    cam.location = (0, -3.4, 0.76)
    look_at(cam, (0, 0, 0.68))
    sc.camera = cam
    return cam


# ── GLB export with engine-friendly Principled variants ─────────────────────

def build_export_materials():
    cache = {}
    for name, (kind, val) in EXPORT_SPEC.items():
        m = bpy.data.materials.new(name + '_glTF')
        m.use_nodes = True
        nodes, links = m.node_tree.nodes, m.node_tree.links
        b = nodes.get('Principled BSDF')
        if kind == 'tex':
            tex = nodes.new('ShaderNodeTexImage')
            tex.image = val
            tex.location = (-320, 180)
            links.new(tex.outputs['Color'], b.inputs['Base Color'])
        else:
            set_in(b, ['Base Color'], (*val, 1))
        set_in(b, ['Roughness'], 0.8)
        set_in(b, ['Metallic'], 0.0)
        if name == 'OutlineMat':
            m.use_backface_culling = True
        m.diffuse_color = (*((val if kind == 'color' else srgb(PAL['skin']))), 1)
        cache[name] = m
    return cache


def export_glb(char, outline, arm):
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
    bpy.ops.export_scene.gltf(filepath=GLB, export_format='GLB',
                              use_selection=True,
                              export_animations=False,
                              export_apply=False,
                              export_yup=True,
                              export_texcoords=True,
                              export_normals=True,
                              export_materials='EXPORT')
    for slot, mat in originals:
        slot.material = mat
    print('QINGHE_GLB_OK', GLB, os.path.getsize(GLB))


# ── main ────────────────────────────────────────────────────────────────────

def build_materials(tex):
    M = {}
    M['skin'] = mat_toon('Skin', PAL['skin'], low=0.62, mid=0.86)
    M['skin_shadow'] = mat_toon('SkinShadow', PAL['skin_shadow'], low=0.7, mid=0.9)
    M['blush'] = mat_toon('Blush', PAL['blush'], low=0.80, mid=0.94)
    M['hair'] = mat_toon('Hair', PAL['hair'], low=0.50, mid=0.80)
    M['hair_dark'] = mat_toon('HairDark', '#244B43', low=0.55, mid=0.82)
    M['dress'] = mat_toon('Dress', img=tex['dress'], low=0.48, mid=0.78)
    M['apron'] = mat_toon('Apron', img=tex['apron'], low=0.62, mid=0.84)
    M['jade'] = mat_toon('Jade', PAL['jade'], low=0.48, mid=0.78)
    M['jade_dark'] = mat_toon('JadeDark', PAL['jade_dark'], low=0.55, mid=0.82)
    M['cream'] = mat_toon('Cream', PAL['cream'], low=0.60, mid=0.85)
    M['gold'] = mat_toon('Gold', PAL['gold'], low=0.42, mid=0.72)
    M['leaf'] = mat_toon('Leaf', PAL['leaf'], low=0.50, mid=0.80)
    M['leather'] = mat_toon('Leather', PAL['leather'], low=0.48, mid=0.78)
    M['leather_dark'] = mat_toon('LeatherDark', PAL['leather_dark'],
                                 low=0.55, mid=0.82)
    M['eye_white'] = mat_toon('EyeWhite', '#FDFBF4', low=0.82, mid=0.94)
    M['iris'] = mat_emit_tex('EyeIris', tex['iris'], 1.0)
    M['pupil'] = mat_emit('Pupil', '#1D120E', 1.0)
    M['highlight'] = mat_emit('EyeHighlight', '#FFFFFF', 1.35)
    M['lash'] = mat_emit('Lash', PAL['lash'], 1.0)
    M['brow'] = mat_emit('Brow', PAL['brow'], 1.0)
    M['mouth'] = mat_toon('Mouth', PAL['mouth'], low=0.7, mid=0.9)
    om = mat_flat('OutlineMat', PAL['outline'], rough=1.0, backface=True)
    om.shadow_method = 'NONE'
    M['outline'] = om
    return M


def main():
    reset()
    tex = build_textures()
    M = build_materials(tex)
    build_armature()
    build_head(M)
    build_hair(M)
    build_skin_body(M)
    build_hand(M, 1.0)
    build_hand(M, -1.0)
    build_outfit(M)
    char = join_character(ARM)
    outline = add_outline(char, M['outline'])
    build_stage(M, tex)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    export_glb(char, outline, ARM)
    tris = sum(len(p.vertices) - 2 for p in char.data.polygons)
    tris_out = sum(len(p.vertices) - 2 for p in outline.data.polygons)
    print('QINGHE_BUILD_OK blend=%s tris=%d tris_outline=%d verts=%d bones=%d '
          'mats=%d' % (BLEND, tris, tris_out, len(char.data.vertices),
                       len(ARM.data.bones), len(char.data.materials)))


if __name__ == '__main__':
    main()

