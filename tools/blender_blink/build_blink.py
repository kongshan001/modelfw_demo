"""Build geometric blink lids + shape keys + blink animation for Qinghe.

Runs in Blender 3.4.1 headless (EEVEE Legacy pipeline used by the probe):

  /Applications/Blender.app/Contents/MacOS/Blender -b \
    -P tools/blender_blink/build_blink.py

What it does
------------
1. Opens `agent-probes/blender-anime-girl/qinghe.blend`.
2. The model has flat decal eyes (no eyelid geometry / bones).  Builds a new
   skinned mesh `Qinghe_BlinkLids` with, per eye:
     - an upper lid "curtain" (skin) whose lower edge carries a lash band,
     - a lower lid band.
   All geometry hugs the same analytic face ellipsoid used by the original
   decal builder (`face_patch` / `face_band` in build_qinghe.py).
3. Removes the static lash faces from the joined `Qinghe` mesh; the new lid
   lash band reproduces them exactly in the open state, then travels with
   the lid.
4. Adds shape keys: Blink_Open (basis), Blink_Half, Blink_Closed,
   Blink_Left, Blink_Right.
5. Adds a deterministic 24 fps, 7 s shape-key action `Blink_Loop_24fps`
   (schedule from blink_schedule.py; seed auto-picked for the demo policy).
6. Saves `agent-probes/blink-test/qinghe_blink.blend`.
7. Exports `agent-probes/blink-test/qinghe_blink.glb` with morph targets +
   shape-key animation (Principled material variants for the GLB only).
8. Writes `agent-probes/blink-test/blink_report.json` with all numbers.

Original assets only; no IP/reference assets are used.
"""

import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
sys.path.insert(0, TOOLS)
import blink_schedule  # noqa: E402

BLEND_IN = os.path.join(REPO, 'agent-probes', 'blender-anime-girl', 'qinghe.blend')
OUT_DIR = os.path.join(REPO, 'agent-probes', 'blink-test')
BLEND_OUT = os.path.join(OUT_DIR, 'qinghe_blink.blend')
GLB_OUT = os.path.join(OUT_DIR, 'qinghe_blink.glb')
REPORT_OUT = os.path.join(OUT_DIR, 'blink_report.json')
SCHEDULE_OUT = os.path.join(OUT_DIR, 'blink_schedule.json')

# ── face ellipsoid (same as build_qinghe.py) ────────────────────────────────
FACE_C = (0.0, 0.0, 1.145)
FACE_R = (0.141, 0.131, 0.138)


def face_y(x, z):
    t = 1.0 - (x / FACE_R[0]) ** 2 - ((z - FACE_C[2]) / FACE_R[2]) ** 2
    return -FACE_R[1] * math.sqrt(max(0.02, t))


# ── eye / lid design constants ──────────────────────────────────────────────
EYE_CX = 0.055          # eye centre x (left eye; right is mirrored)
EYE_CZ = 1.135          # eye centre z
LASH_RX = 0.0445        # original lash ellipse rx
LASH_RZ = 0.0555        # original lash ellipse rz
LASH_INNER = 0.86       # original face_band inner factor
LASH_W = 0.0095         # original face_band width
A0, A1 = 0.18, math.pi - 0.18
SEGS = 28               # same column count as original face_band

MEET_C = 1.0995         # closed lid line at eye centre
MEET_K = 0.0355         # closed lid line rises to the canthi (u^2 term)
TOP_CAP = 1.1920        # fixed top boundary (below brow bottom 1.1949)
UP_OFF = 0.0108         # upper lid float above face ellipsoid
LOW_OFF = 0.0105        # lower lid float (slightly behind upper at the meet)
SKIN_FRACS = (0.0, 0.30, 0.62, 1.0)   # rows between lid top and lash top
LOW_FRACS = (0.0, 0.35, 0.70, 1.0)    # rows between lower edge and bottom

# 80-90% / 10-20% check (centre column): eye top 1.1905, bottom 1.0795.
UPPER_COVER = (EYE_CZ + LASH_RZ - MEET_C) / (2 * LASH_RZ)
LOWER_COVER = (MEET_C - (EYE_CZ - LASH_RZ)) / (2 * LASH_RZ)


def lerp(a, b, t):
    return a + (b - a) * t


def build_lid_geometry():
    """Return verts/meta/states for both eyes (all coordinates in world)."""
    verts_open, verts_closed, meta = [], [], []
    for sy in (1, -1):
        for part in ('upper', 'lower'):
            n_rows = 5 if part == 'upper' else 4
            for i in range(SEGS + 1):
                a = A0 + (A1 - A0) * i / SEGS
                u, s = math.cos(a), math.sin(a)
                x_out = sy * (EYE_CX + u * LASH_RX)
                x_in = sy * (EYE_CX + u * LASH_RX * LASH_INNER)
                z_meet = MEET_C + MEET_K * u * u
                if part == 'upper':
                    z_top = min(EYE_CZ + s * LASH_RZ + 0.002, TOP_CAP)
                    z_lt_o = EYE_CZ + s * LASH_RZ
                    z_lb_o = EYE_CZ + s * LASH_RZ * LASH_INNER - LASH_W
                    thick = z_lt_o - z_lb_o
                    z_lt_c = z_meet + thick
                    z_lb_c = z_meet
                    rows_open, rows_closed, xs = [], [], []
                    for r, frac in enumerate(SKIN_FRACS):
                        rows_open.append(lerp(z_top, z_lt_o, frac))
                        rows_closed.append(lerp(z_top, z_lt_c, frac))
                        xs.append(x_out)
                    rows_open.append(z_lb_o)
                    rows_closed.append(z_lb_c)
                    # Open lash inner edge reproduces the original face_band
                    # exactly (x_in).  Closed spreads to x_out so the lid line
                    # meets the lower lid and covers the sclera corners.
                    xs.append((x_in, x_out))
                    off = UP_OFF
                else:
                    z_eye_bottom = EYE_CZ - s * LASH_RZ
                    z_edge_o = z_eye_bottom - 0.0004
                    z_edge_c = z_meet + 0.0008
                    z_bot = z_eye_bottom - 0.0012
                    rows_open, rows_closed, xs = [], [], []
                    for frac in LOW_FRACS:
                        rows_open.append(lerp(z_edge_o, z_bot, frac))
                        rows_closed.append(lerp(z_edge_c, z_bot, frac))
                        xs.append(x_out)
                    off = LOW_OFF
                for r in range(n_rows):
                    xr = xs[r]
                    xo, xc = xr if isinstance(xr, tuple) else (xr, xr)
                    zo, zc = rows_open[r], rows_closed[r]
                    verts_open.append(Vector((xo, face_y(xo, zo) - off, zo)))
                    verts_closed.append(Vector((xc, face_y(xc, zc) - off, zc)))
                    meta.append((sy, part, i, r, n_rows))
    return verts_open, verts_closed, meta


def make_lid_object(open_v, closed_v, meta, mats):
    me = bpy.data.meshes.new('QingheBlinkLidsMesh')
    # faces: quads between consecutive columns/rows inside each part
    faces, face_mats = [], []
    vmap = {}
    for idx, m in enumerate(meta):
        vmap[(m[0], m[1], m[2], m[3])] = idx
    for sy in (1, -1):
        for part in ('upper', 'lower'):
            n_rows = 5 if part == 'upper' else 4
            for i in range(SEGS):
                for r in range(n_rows - 1):
                    a = vmap[(sy, part, i, r)]
                    b = vmap[(sy, part, i + 1, r)]
                    c = vmap[(sy, part, i + 1, r + 1)]
                    d = vmap[(sy, part, i, r + 1)]
                    quad = (a, d, c, b)
                    # keep normals facing the camera (-Y) on both mirrored eyes
                    p0, p1, p2 = (open_v[quad[0]], open_v[quad[1]],
                                  open_v[quad[2]])
                    n = (p1 - p0).cross(p2 - p1)
                    if n.y > 0:
                        quad = tuple(reversed(quad))
                    faces.append(quad)
                    face_mats.append(1 if (part == 'upper' and r == 3) else 0)
    me.from_pydata([tuple(v) for v in open_v], [], faces)
    me.update()
    me.materials.append(mats['skin'])
    me.materials.append(mats['lash'])
    for p, mi in zip(me.polygons, face_mats):
        p.material_index = mi
    me.validate(clean_customdata=False)

    # UVs (simple per-column/row)
    uv = me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            vi = me.loops[li].vertex_index
            sy, part, i, r, n_rows = meta[vi]
            uv.data[li].uv = (i / SEGS, r / (n_rows - 1))

    obj = bpy.data.objects.new('Qinghe_BlinkLids', me)
    bpy.context.scene.collection.objects.link(obj)
    obj['role'] = 'blink_lids'
    obj['design'] = (
        'upper lid curtain + lash band, lower lid band; '
        'analytic face ellipsoid; no eyelid bones; morph targets only')

    # skin weights: fully rigid to head
    vg = obj.vertex_groups.new(name='head')
    vg.add(list(range(len(me.vertices))), 1.0, 'REPLACE')

    arm = bpy.data.objects['QingheRig']
    obj.parent = arm
    obj.matrix_parent_inverse.identity()
    mod = obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm
    mod.use_vertex_groups = True
    return obj, me


def project_half(open_v, closed_v, meta):
    """Half pose projected back onto the face ellipsoid at full offset.

    A naive midpoint of open/closed y coords sinks up to ~5 mm into the face
    (chord of the ellipsoid) and lets the 8.2 mm eye highlights poke through
    mid-blink.  Keeping the half key on the offset surface plus animating
    Open->Half->Closed bounds the sag to ~1.3 mm.
    """
    out = []
    for i, (o, c) in enumerate(zip(open_v, closed_v)):
        xm = (o.x + c.x) * 0.5
        zm = (o.z + c.z) * 0.5
        off = UP_OFF if meta[i][1] == 'upper' else LOW_OFF
        out.append(Vector((xm, face_y(xm, zm) - off, zm)))
    return out


def add_shape_keys(obj, me, open_v, closed_v, half_v, meta):
    def per_side(closed_pose, side):
        return [closed_pose[i] if meta[i][0] == side else open_v[i]
                for i in range(len(open_v))]

    variants = [
        ('Blink_Half', half_v),
        ('Blink_Closed', closed_v),
        ('Blink_Left_Half', per_side(half_v, 1)),
        ('Blink_Left_Closed', per_side(closed_v, 1)),
        ('Blink_Right_Half', per_side(half_v, -1)),
        ('Blink_Right_Closed', per_side(closed_v, -1)),
    ]
    basis = obj.shape_key_add(name='Blink_Open', from_mix=False)
    basis.interpolation = 'KEY_LINEAR'
    keys = {}
    for name, coords in variants:
        kb = obj.shape_key_add(name=name, from_mix=False)
        kb.interpolation = 'KEY_LINEAR'
        for i, co in enumerate(coords):
            kb.data[i].co = co
        keys[name] = kb
    return keys


def delete_lash_faces(char):
    me = char.data
    slots = [s.material.name if s.material else None for s in char.material_slots]
    if 'Lash' not in slots:
        return 0
    li = slots.index('Lash')
    bm = bmesh.new()
    bm.from_mesh(me)
    doomed = [f for f in bm.faces if f.material_index == li]
    n = len(doomed)
    bmesh.ops.delete(bm, geom=doomed, context='FACES')
    bm.to_mesh(me)
    bm.free()
    me.update()
    return n


def blink_profile(b, channel):
    """(frame, half_weight, closed_weight) through projected half poses.

    Open -> Half -> Closed keeps the lid within ~1.3 mm of the offset surface
    (a direct Open->Closed morph sags ~5 mm and lets highlights poke through).
    """
    off = b['left_off'] if channel == 'left' else b['right_off']
    s = b['start'] + off
    c, h, o = b['close'], b['hold'], b['open']
    f_half_close = s + max(1, c // 2)
    f_closed = s + c
    f_hold_end = s + c + h
    f_half_open = f_hold_end + max(1, o // 2)
    f_end = f_hold_end + o
    return [(s, 0.0, 0.0), (f_half_close, 1.0, 0.0), (f_closed, 0.0, 1.0),
            (f_hold_end, 0.0, 1.0), (f_half_open, 1.0, 0.0),
            (f_end, 0.0, 0.0)]


def build_action(me, schedule):
    sk = me.shape_keys
    sk.animation_data_create()
    act = bpy.data.actions.new('Blink_Loop_24fps')
    sk.animation_data.action = act

    tracks = {
        'Blink_Left_Half': {}, 'Blink_Left_Closed': {},
        'Blink_Right_Half': {}, 'Blink_Right_Closed': {},
    }
    for b in schedule['blinks']:
        for channel, prefix in (('left', 'Blink_Left'), ('right', 'Blink_Right')):
            for f, hv, cv in blink_profile(b, channel):
                tracks[prefix + '_Half'][f] = hv
                tracks[prefix + '_Closed'][f] = cv
    for name, keys in tracks.items():
        keys[1] = 0.0
        keys[schedule['frames']] = 0.0
        kb = sk.key_blocks[name]
        for f in sorted(keys):
            kb.value = keys[f]
            kb.keyframe_insert(data_path='value', frame=f, group=name)
        kb.value = 0.0

    for fc in act.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = 'BEZIER'
            kp.handle_left_type = 'AUTO_CLAMPED'
            kp.handle_right_type = 'AUTO_CLAMPED'
        fc.update()
    if hasattr(act, 'use_frame_range'):
        act.use_frame_range = True
        act.frame_start = 1
        act.frame_end = schedule['frames']
    # Store the schedule on the action for traceability.
    act['blink_seed'] = schedule['seed']
    act['blink_schedule'] = json.dumps(
        [{k: b[k] for k in ('index', 'start', 'end', 'close', 'hold',
                            'open', 'left_off', 'right_off', 'double')}
         for b in schedule['blinks']])
    return act, tracks


# ── GLB materials (Principled variants, EEVEE toon stays in the .blend) ─────

def _input_color(node, name='Color'):
    if node and name in node.inputs:
        v = node.inputs[name].default_value
        return tuple(v)
    return None


def find_base_color(src):
    if not src.use_nodes:
        return tuple(src.diffuse_color)
    nodes = src.node_tree.nodes
    # toon materials: MixRGB Color2 is the unlinked base tint.  Check it first:
    # the Emission node's Color socket is *linked*, so its default is white.
    mix = next((n for n in nodes if n.type == 'MIX_RGB'
                and n.blend_type == 'MULTIPLY'), None)
    if mix:
        c = _input_color(mix, 'Color2')
        if c:
            return c
    em = next((n for n in nodes if n.type == 'EMISSION'), None)
    if em and not em.inputs['Color'].is_linked:
        c = _input_color(em)
        if c:
            return c
    bsdf = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if bsdf:
        c = _input_color(bsdf, 'Base Color')
        if c:
            return c
    return tuple(src.diffuse_color)


def make_gltf_material(src):
    m = bpy.data.materials.new(src.name + '_blinkGLTF')
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    tex_img = None
    if src.use_nodes:
        tex = next((n for n in src.node_tree.nodes
                    if n.type == 'TEX_IMAGE' and n.image), None)
        if tex:
            tex_img = tex.image
    if tex_img:
        t = nt.nodes.new('ShaderNodeTexImage')
        t.image = tex_img
        t.location = (-320, 160)
        nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
    else:
        col = find_base_color(src)
        bsdf.inputs['Base Color'].default_value = (col[0], col[1], col[2], 1)
    bsdf.inputs['Roughness'].default_value = 0.82
    bsdf.inputs['Metallic'].default_value = 0.0
    m.use_backface_culling = src.use_backface_culling
    m.diffuse_color = tuple(src.diffuse_color)
    return m


def export_glb(meshes, arm):
    cache = {}
    originals = []
    for o in meshes:
        for slot in o.material_slots:
            src = slot.material
            if not src:
                continue
            if src.name not in cache:
                cache[src.name] = make_gltf_material(src)
            originals.append((slot, src))
            slot.material = cache[src.name]
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = 168
    sc.render.fps = 24
    bpy.ops.export_scene.gltf(
        filepath=GLB_OUT, export_format='GLB', use_selection=True,
        export_animations=True, export_nla_strips=False,
        export_nla_strips_merged_animation_name='Blink_Loop',
        export_morph=True, export_morph_normal=True,
        export_morph_tangent=False, export_apply=False, export_yup=True,
        export_texcoords=True, export_normals=True, export_materials='EXPORT',
        export_skins=True, export_frame_range=True, export_force_sampling=True,
        export_anim_single_armature=True)
    for slot, mat in originals:
        slot.material = mat
    return os.path.getsize(GLB_OUT)


def displacement_stats(me, base_coords, key):
    moved = 0
    dmax = 0.0
    bmin = [1e9, 1e9, 1e9]
    bmax = [-1e9, -1e9, -1e9]
    for i, v in enumerate(key.data):
        d = (Vector(v.co) - Vector(base_coords[i])).length
        if d > 1e-7:
            moved += 1
            dmax = max(dmax, d)
            for k in range(3):
                bmin[k] = min(bmin[k], v.co[k])
                bmax[k] = max(bmax[k], v.co[k])
    return {'moved_verts': moved, 'max_disp_m': round(dmax, 6),
            'bbox_min': [round(v, 4) for v in bmin],
            'bbox_max': [round(v, 4) for v in bmax]}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=BLEND_IN)
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = blink_schedule.FRAMES
    sc.render.fps = 24

    char = bpy.data.objects['Qinghe']
    arm = bpy.data.objects['QingheRig']
    mats = {'skin': bpy.data.materials['Skin'],
            'lash': bpy.data.materials['Lash']}

    # sanity: no eyelid-ish bones / no existing shape keys
    bones = [b.name for b in arm.data.bones]
    shape_keys_before = ([k.name for k in char.data.shape_keys.key_blocks]
                         if char.data.shape_keys else [])
    removed = delete_lash_faces(char)

    open_v, closed_v, meta = build_lid_geometry()
    half_v = project_half(open_v, closed_v, meta)
    obj, me = make_lid_object(open_v, closed_v, meta, mats)
    keys = add_shape_keys(obj, me, open_v, closed_v, half_v, meta)

    seed, schedule = blink_schedule.find_seed()
    act, tracks = build_action(me, schedule)
    with open(SCHEDULE_OUT, 'w') as f:
        json.dump(schedule, f, indent=2)

    # verification numbers
    stats = {}
    for name, kb in keys.items():
        stats[name] = displacement_stats(me, open_v, kb)

    def min_offset(points):
        return min(face_y(p.x, p.z) - p.y for p in points)

    blend_open_half = [(a + b) * 0.5 for a, b in zip(open_v, half_v)]
    blend_half_closed = [(a + b) * 0.5 for a, b in zip(half_v, closed_v)]
    offset_report = {
        'open_min_offset_m': round(min_offset(open_v), 6),
        'half_min_offset_m': round(min_offset(half_v), 6),
        'closed_min_offset_m': round(min_offset(closed_v), 6),
        # morph midpoints the engine will actually display between key poses
        'blend_open_half_min_offset_m': round(min_offset(blend_open_half), 6),
        'blend_half_closed_min_offset_m': round(min_offset(blend_half_closed), 6),
        'naive_open_closed_mid_sag_min_offset_m': round(min_offset(
            [(a + b) * 0.5 for a, b in zip(open_v, closed_v)]), 6),
        'highlight_offset_m': 0.0082,
        'eye_white_offset_m': 0.0045,
    }
    left_moved_on_right = sum(
        1 for i, m in enumerate(meta)
        if m[0] == -1 and
        (Vector(keys['Blink_Left_Closed'].data[i].co) - Vector(open_v[i])).length > 1e-7)
    right_moved_on_left = sum(
        1 for i, m in enumerate(meta)
        if m[0] == 1 and
        (Vector(keys['Blink_Right_Closed'].data[i].co) - Vector(open_v[i])).length > 1e-7)

    # normals sanity (front should point -Y)
    me.calc_normals()
    ny = sum(v.normal.y for v in me.vertices) / len(me.vertices)

    bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT, compress=True)

    glb_size = export_glb([char, bpy.data.objects['Qinghe_Outline'], obj], arm)

    # bounds of the closed lids vs eye decal (proof of coverage)
    report = {
        'blender': bpy.app.version_string,
        'source_blend': os.path.relpath(BLEND_IN, REPO),
        'output_blend': os.path.relpath(BLEND_OUT, REPO),
        'output_glb': os.path.relpath(GLB_OUT, REPO),
        'glb_bytes': glb_size,
        'rig_bones': len(bones),
        'has_eyelid_bones': [b for b in bones if 'lid' in b.lower() or
                             'eye' in b.lower() or 'blink' in b.lower()],
        'shape_keys_before': shape_keys_before,
        'lash_faces_removed': removed,
        'lid_object': obj.name,
        'lid_verts': len(me.vertices),
        'lid_faces': len(me.polygons),
        'lid_parts': {'upper_rows': 5, 'lower_rows': 4, 'columns': SEGS + 1,
                      'eyes': 2},
        'offsets_m': {'upper': UP_OFF, 'lower': LOW_OFF},
        'meet_line': {'centre_z': MEET_C, 'corner_rise_z': MEET_K,
                      'top_cap_z': TOP_CAP},
        'coverage_centre': {'upper_pct': round(UPPER_COVER * 100, 2),
                            'lower_pct': round(LOWER_COVER * 100, 2)},
        'shape_keys': [k.name for k in me.shape_keys.key_blocks],
        'targets': stats,
        'offset_surface_checks': offset_report,
        'left_key_moved_right_verts': left_moved_on_right,
        'right_key_moved_left_verts': right_moved_on_left,
        'normals_mean_y': round(ny, 4),
        'action': {'name': act.name,
                   'fcurves': [fc.data_path for fc in act.fcurves],
                   'frame_range': [1, schedule['frames']],
                   'fps': 24},
        'schedule': schedule,
        'material_slots_exported': [s.material.name for s in obj.material_slots],
    }
    with open(REPORT_OUT, 'w') as f:
        json.dump(report, f, indent=2)
    print('BLINK_BUILD_OK')
    print(json.dumps({k: report[k] for k in (
        'blender', 'glb_bytes', 'lash_faces_removed', 'lid_verts', 'lid_faces',
        'shape_keys', 'coverage_centre', 'offset_surface_checks',
        'left_key_moved_right_verts', 'normals_mean_y', 'action')}, indent=2))
    print('BLINK_BUILD_REPORT', REPORT_OUT)


if __name__ == '__main__':
    main()
