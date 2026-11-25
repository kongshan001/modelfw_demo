"""Import a Tripo GLB/FBX and run the Blender cleanup pass.

This is intentionally a *cleanup helper*, not an automatic retopo/sculpt
replacement.  It:
  1. imports GLB/FBX and inspects topology/UV/materials/bones;
  2. drops Tripo cameras/lights/old outline shells;
  3. joins meshes, optional decimate, optional Smart UV;
  4. normalizes height/feet (static input) and optionally rebuilds the
     anime_kit basic 50-bone rig;
  5. converts Principled materials to toon/cel + inverted-hull outline;
  6. saves .blend and exports a game-ready GLB.

  /Applications/Blender.app/Contents/MacOS/Blender -b \
    -P tools/blender_anime/import_tripo.py -- \
    --input tripo-out/models/model_00.glb \
    --out-blend agent-probes/tripo-clean/character.blend \
    --out-glb agent-probes/tripo-clean/character.glb \
    --height 1.30 --head-ratio 5.0 --decimate 30000 --rerig

No Tripo key is needed here; the file is already local.
"""

import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import anime_kit as kit  # noqa: E402


def linear_to_hex(rgb):
    def enc(c):
        c = max(0.0, min(1.0, c))
        c = 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055
        return int(round(c * 255))
    return '#%02X%02X%02X' % (enc(rgb[0]), enc(rgb[1]), enc(rgb[2]))


def base_material_info(mat):
    """Return (image, hex) for a Principled material."""
    img = None
    col = (0.8, 0.75, 0.72, 1.0)
    if mat and mat.use_nodes:
        bsdf = next((n for n in mat.node_tree.nodes
                     if n.type == 'BSDF_PRINCIPLED'), None)
        if bsdf:
            inp = bsdf.inputs.get('Base Color')
            if inp:
                if inp.is_linked:
                    node = inp.links[0].from_node
                    if node.type == 'TEX_IMAGE' and node.image:
                        img = node.image
                else:
                    col = tuple(inp.default_value)
    return img, linear_to_hex(col)


def inspect(obj, arm=None):
    if obj is None:
        return {}
    st = kit.measure_mesh(obj)
    st['materials'] = [m.name if m else None for m in obj.data.materials]
    st['images'] = [i.name for i in bpy.data.images
                    if i.name != 'Render Result']
    if arm:
        st['bones'] = len(arm.data.bones)
    return st


def join_meshes(meshes):
    bpy.ops.object.select_all(action='DESELECT')
    for o in meshes:
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.name = 'TripoCharacter'
    o.data.name = 'TripoCharacterMesh'
    return o


def smart_uv(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    try:
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.02)
    except TypeError:
        bpy.ops.uv.smart_project()
    bpy.ops.object.mode_set(mode='OBJECT')


def normalize_static(o, height):
    lo = [min((o.matrix_world @ Vector(c)).z for c in o.bound_box)]
    hi = [max((o.matrix_world @ Vector(c)).z for c in o.bound_box)]
    cur = hi[0] - lo[0]
    if cur <= 1e-6:
        return 1.0
    s = height / cur
    xs = [(o.matrix_world @ Vector(c)).x for c in o.bound_box]
    ys = [(o.matrix_world @ Vector(c)).y for c in o.bound_box]
    cx, cy = (min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5
    o.scale = (s, s, s)
    o.location = (-cx * s, -cy * s, -lo[0] * s)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return s


def toonify(mesh):
    """Create toon materials and replace slots. Returns count + mapping."""
    mapping = {}
    for slot in mesh.material_slots:
        old = slot.material
        if old is None:
            continue
        if old.name in mapping:
            slot.material = mapping[old.name]
            continue
        img, hexcol = base_material_info(old)
        new_name = 'Clean_' + old.name
        c = kit.EXPORT_SPEC.get(new_name)
        if c is None:
            new = kit.mat_toon(new_name, hexcol=hexcol, img=img,
                               low=0.55, mid=0.82)
        else:
            new = bpy.data.materials.get(new_name)
        mapping[old.name] = new
        slot.material = new
    return mapping


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ap = argparse.ArgumentParser(prog='import_tripo.py')
    ap.add_argument('--input', required=True)
    ap.add_argument('--out-blend', default=None)
    ap.add_argument('--out-glb', default=None)
    ap.add_argument('--height', type=float, default=1.30)
    ap.add_argument('--head-ratio', type=float, default=5.0)
    ap.add_argument('--decimate', type=int, default=0,
                    help='target triangles; 0 = no decimation')
    ap.add_argument('--rerig', action='store_true',
                    help='drop an existing armature and build the anime_kit rig')
    ap.add_argument('--keep-armature', action='store_true',
                    help='keep an imported armature (default if present)')
    ap.add_argument('--no-rig', action='store_true')
    ap.add_argument('--no-toon', action='store_true')
    ap.add_argument('--no-outline', action='store_true')
    ap.add_argument('--drop-outline', action='store_true',
                    help='remove imported OutlineMat shells (re-added later)')
    ap.add_argument('--report', default=None)
    ap.add_argument('--inspect-only', action='store_true')
    args = ap.parse_args(argv)
    kit.EXPORT_SPEC.clear()
    kit.BONES.clear()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    path = os.path.abspath(args.input)
    if not os.path.exists(path):
        raise SystemExit('TRIPO_CLEANUP_FAIL missing input: %s' % path)
    ext = os.path.splitext(path)[1].lower()
    if ext == '.fbx':
        bpy.ops.import_scene.fbx(filepath=path)
    else:
        bpy.ops.import_scene.gltf(filepath=path)
    for o in list(bpy.data.objects):
        if o.type in ('CAMERA', 'LIGHT'):
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
    if args.drop_outline:
        for o in list(meshes):
            mats = [m.name for m in o.data.materials if m]
            if any('Outline' in m for m in mats) or 'Outline' in o.name:
                bpy.data.objects.remove(o, do_unlink=True)
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    raw = dict(meshes=len(meshes), armatures=len(arms),
               stats=[inspect(o) for o in meshes])
    if not meshes:
        raise SystemExit('TRIPO_CLEANUP_FAIL no meshes imported')
    char = join_meshes(meshes)
    if not char.data.uv_layers:
        smart_uv(char)
    before = inspect(char)
    if args.decimate and before['tris'] > args.decimate:
        ratio = args.decimate / float(before['tris'])
        mod = char.modifiers.new('decimate', 'DECIMATE')
        mod.ratio = max(0.02, min(1.0, ratio))
        kit.apply_mod(char, mod)
    if args.inspect_only:
        rep = {'input': path, 'raw': raw, 'joined': inspect(char),
               'note': 'inspect-only; no files written'}
        print('TRIPO_CLEANUP_INSPECT', json.dumps(rep, ensure_ascii=False))
        return 0
    # armature policy
    arm = arms[0] if arms else None
    if args.rerig and arm:
        for a in arms:
            bpy.data.objects.remove(a, do_unlink=True)
        arm = None
    if args.no_rig:
        arm = arm if args.keep_armature else None
    if arm is None and not args.no_rig:
        if not args.keep_armature or args.rerig:
            normalize_static(char, args.height)
    elif arm is None:
        normalize_static(char, args.height)
    if arm is None and not args.no_rig:
        m = kit.metrics_from_preset({
            'height_m': args.height, 'head_ratio': args.head_ratio,
            'eye_line_from_chin': 0.46,
        })
        arm = kit.build_rig(m)
        char.vertex_groups.clear()
        names = [n for n in kit.BONES if n != 'root']
        kit.weight_nearest(char, names, k=2, power=4.0)
    if arm:
        if not any(mod.type == 'ARMATURE' and mod.object == arm
                   for mod in char.modifiers):
            mod = char.modifiers.new('Armature', 'ARMATURE')
            mod.object = arm
            mod.use_vertex_groups = True
        char.parent = arm
        char.matrix_parent_inverse.identity()
    mats = 0
    if not args.no_toon:
        mapping = toonify(char)
        mats = len(mapping)
    outline = None
    if not args.no_outline:
        om = kit.mat_flat('OutlineMat', '#2B1E1B', rough=1.0, backface=True)
        om.shadow_method = 'NONE'
        outline = kit.add_outline(char, om, thickness=0.0030)
    after = inspect(char, arm)
    blend = os.path.abspath(args.out_blend) if args.out_blend else None
    glb = os.path.abspath(args.out_glb) if args.out_glb else None
    if blend:
        os.makedirs(os.path.dirname(blend), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=blend)
    if glb:
        os.makedirs(os.path.dirname(glb), exist_ok=True)
        if args.no_toon:
            bpy.ops.object.select_all(action='DESELECT')
            char.select_set(True)
            if outline:
                outline.select_set(True)
            if arm:
                arm.select_set(True)
            bpy.context.view_layer.objects.active = arm or char
            bpy.ops.export_scene.gltf(filepath=glb, export_format='GLB',
                                      use_selection=True,
                                      export_animations=False,
                                      export_apply=False, export_yup=True)
        else:
            kit.export_glb(char, outline or char, arm, glb)
    report = {
        'input': path, 'raw': raw, 'before': before, 'after': after,
        'armature': {'kept': bool(arms) and not args.rerig,
                     'bones': len(arm.data.bones) if arm else 0},
        'toon_materials': mats, 'outline': bool(outline),
        'decimate_target': args.decimate or None,
        'height_target': args.height,
        'files': {'blend': blend, 'glb': glb},
        'limits': ['decimate is not retopo', 'generic rig weights are '
                   'nearest-bone approximations', 'base-color texture only '
                   'in toon conversion'],
    }
    if args.report:
        os.makedirs(os.path.dirname(os.path.abspath(args.report)),
                    exist_ok=True)
        with open(args.report, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    print('TRIPO_CLEANUP_OK in=%d tris out=%d tris bones=%d glb=%s' % (
        before['tris'], after['tris'],
        len(arm.data.bones) if arm else 0, glb))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
