"""Fail-closed validation for a blender_anime character package.

  /Applications/Blender.app/Contents/MacOS/Blender -b \
    -P tools/blender_anime/validate.py -- \
    --blend agent-probes/blender-anime-v01/taoyao.blend \
    --glb agent-probes/blender-anime-v01/taoyao.glb \
    --renders agent-probes/blender-anime-v01/renders \
    --manifest agent-probes/blender-anime-v01/manifest.json \
    --report agent-probes/blender-anime-v01/report.json

Last line is BLENDER_ANIME_OK (P0 all pass) or BLENDER_ANIME_FAIL.
--glb-only is safe on Blender 4.2 (no EEVEE render): used for engine probes.
"""

import argparse
import bmesh
import bpy
import json
import os
import re
import struct
import sys
import time

PNG_LIMITS = (1024, 1920)


def png_size(path):
    with open(path, 'rb') as f:
        head = f.read(33)
    if head[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    w, h = struct.unpack('>II', head[16:24])
    return w, h


def read_glb(path):
    data = open(path, 'rb').read()
    magic, version, length = struct.unpack_from('<III', data, 0)
    if magic != 0x46546C67:
        raise ValueError('not a GLB (magic)')
    out = None
    off = 12
    while off < len(data) and off + 8 <= len(data):
        clen, ctype = struct.unpack_from('<II', data, off)
        off += 8
        chunk = data[off:off + clen]
        off += clen
        if ctype == 0x4E4F534A:
            out = json.loads(chunk.decode('utf-8'))
    if out is None:
        raise ValueError('GLB has no JSON chunk')
    return out, length, version


def mesh_stats(o):
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    quads = sum(1 for p in o.data.polygons if len(p.vertices) == 4)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    non_manifold = sum(1 for e in bm.edges if not e.is_manifold)
    loose = sum(1 for v in bm.verts if not v.link_edges)
    bm.free()
    zero = bad = 0
    max_inf = 0
    for v in o.data.vertices:
        ws = [g.weight for g in v.groups if g.weight > 1e-5]
        s = sum(ws)
        if s < 1e-4:
            zero += 1
        elif abs(s - 1.0) > 0.02:
            bad += 1
        max_inf = max(max_inf, len(ws))
    return {
        'tris': tris, 'verts': len(o.data.vertices),
        'quad_ratio': round(quads / max(1, len(o.data.polygons)), 4),
        'non_manifold': non_manifold, 'loose_verts': loose,
        'zero_weight': zero, 'bad_weight_sum': bad,
        'max_influences': max_inf,
        'materials': len(o.data.materials),
        'uv_layers': [layer.name for layer in o.data.uv_layers],
        'dims': [round(v, 4) for v in o.dimensions],
    }


def image_material_stats(objects):
    imgs = {}
    for o in objects:
        for slot in o.material_slots:
            m = slot.material
            if not m or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                if n.type == 'TEX_IMAGE' and n.image:
                    imgs[n.image.name] = list(n.image.size)
    return imgs


def text_key_leak(root):
    patterns = [
        re.compile(r'TRIPO_API_KEY\s*[=:]\s*[^\s"\']+'),
        re.compile(r'Bearer\s+[A-Za-z0-9_\-]{20,}'),
    ]
    key = os.environ.get('TRIPO_API_KEY')
    hits = []
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            if not fn.endswith(('.json', '.md', '.txt', '.log', '.py',
                                '.yaml', '.yml')):
                continue
            p = os.path.join(dirpath, fn)
            try:
                if os.path.getsize(p) > 300000:
                    continue
                txt = open(p, 'r', encoding='utf-8', errors='ignore').read()
            except OSError:
                continue
            for pat in patterns:
                if pat.search(txt):
                    hits.append(os.path.relpath(p, root))
                    break
            if key and key in txt:
                hits.append(os.path.relpath(p, root))
    return sorted(set(hits))


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    ap = argparse.ArgumentParser(prog='validate.py')
    ap.add_argument('--blend', default=None)
    ap.add_argument('--glb', required=True)
    ap.add_argument('--renders', default=None)
    ap.add_argument('--manifest', default=None)
    ap.add_argument('--report', default=None)
    ap.add_argument('--glb-only', action='store_true')
    ap.add_argument('--engine-report', default=None,
                    help='optional JSON for a 4.2 GLB import probe')
    args = ap.parse_args(argv)
    t0 = time.time()
    checks = []

    def add(name, ok, value, threshold, level='P0', note=''):
        checks.append(dict(name=name, ok=bool(ok), value=value,
                           threshold=threshold, level=level, note=note))
        return ok

    def png_ok(path):
        if not path or not os.path.exists(path):
            return None
        w, h = png_size(path)
        return (PNG_LIMITS[0] <= w <= PNG_LIMITS[1] and
                PNG_LIMITS[0] <= h <= PNG_LIMITS[1]), (w, h)

    # ---- GLB JSON (always safe, even on 4.2) ------------------------------
    glb_json = None
    try:
        glb_json, glb_len, glb_ver = read_glb(args.glb)
        add('glb.exists', True, os.path.getsize(args.glb), '>100KB')
        add('glb.header', glb_ver == 2, glb_ver, '2')
        add('glb.meshes', len(glb_json.get('meshes', [])) >= 1,
            len(glb_json.get('meshes', [])), '>=1')
        add('glb.skins', len(glb_json.get('skins', [])) == 1,
            len(glb_json.get('skins', [])), '==1')
        joints = len(glb_json.get('skins', [{}])[0].get('joints', [])) \
            if glb_json.get('skins') else 0
        add('glb.joints', 25 <= joints <= 90, joints, '25..90')
        add('glb.images', len(glb_json.get('images', [])) >= 3,
            len(glb_json.get('images', [])), '>=3')
        prims = [p for m in glb_json.get('meshes', [])
                 for p in m.get('primitives', [])]
        skinned = sum(1 for p in prims
                      if 'JOINTS_0' in p.get('attributes', {}) and
                      'WEIGHTS_0' in p.get('attributes', {}))
        add('glb.skinned_primitives', skinned >= 1, skinned, '>=1')
        add('glb.uv_primitives',
            all('TEXCOORD_0' in p.get('attributes', {}) for p in prims),
            sum(1 for p in prims if 'TEXCOORD_0' in p.get('attributes', {})),
            'all')
        add('glb.images_embedded',
            all('bufferView' in i for i in glb_json.get('images', [])),
            sum(1 for i in glb_json.get('images', []) if 'bufferView' in i),
            'embedded', 'P1')
        add('glb.animations', len(glb_json.get('animations', [])) <= 2,
            len(glb_json.get('animations', [])), '<=2', 'P1')
    except Exception as e:
        add('glb.parse', False, str(e), 'valid GLB')
        glb_json = None

    if args.glb_only:
        # re-import and report
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.glb))
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
        imgs = [i for i in bpy.data.images if i.name != 'Render Result']
        print('GLB_ONLY blender=%s meshes=%d armatures=%d images=%d' % (
            bpy.app.version_string, len(meshes), len(arms), len(imgs)))
        for o in meshes:
            print('GLB_ONLY_MESH', o.name, mesh_stats(o))
        for a in arms:
            print('GLB_ONLY_ARMATURE', a.name, len(a.data.bones))
        ok = bool(glb_json) and all(c['ok'] for c in checks
                                    if c['level'] == 'P0')
        report = dict(mode='glb-only', blender=bpy.app.version_string,
                      checks=checks, ok=ok)
        if args.engine_report:
            with open(args.engine_report, 'w', encoding='utf-8') as f:
                json.dump(report, f, ensure_ascii=False, indent=2)
        print('BLENDER_ANIME_GLB_OK' if ok else 'BLENDER_ANIME_GLB_FAIL')
        if not ok:
            raise SystemExit(1)
        return

    # ---- full package ------------------------------------------------------
    if not args.blend or not args.manifest or not args.renders:
        raise SystemExit('VALIDATE_FAIL full mode needs --blend --manifest '
                         '--renders')
    manifest = json.load(open(args.manifest, 'r', encoding='utf-8'))
    preset = manifest.get('preset', {})
    q = preset.get('quality', {})
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(args.blend))
    char = next((o for o in bpy.context.scene.objects
                 if o.get('role') == 'character'), None)
    add('blend.character', char is not None, bool(char), 'role=character')
    stats = {}
    if char:
        stats = mesh_stats(char)
        add('mesh.tris', 8000 <= stats['tris'] <= 120000, stats['tris'],
            '8k..120k')
        add('mesh.tris_target',
            preset.get('mesh', {}).get('tris_target_min', 18000) <=
            stats['tris'] <= preset.get('mesh', {}).get('tris_target_max',
                                                        60000),
            stats['tris'], 'preset target', 'P1')
        add('mesh.quad_ratio', stats['quad_ratio'] >= 0.70,
            stats['quad_ratio'], '>=0.70')
        add('mesh.non_manifold', stats['non_manifold'] == 0,
            stats['non_manifold'], '==0')
        add('mesh.loose_verts', stats['loose_verts'] == 0,
            stats['loose_verts'], '==0', 'P1')
        add('mesh.uv_layers', len(stats['uv_layers']) >= 1,
            stats['uv_layers'], '>=1')
        add('mesh.weight_zero', stats['zero_weight'] == 0,
            stats['zero_weight'], '==0')
        add('mesh.weight_sum', stats['bad_weight_sum'] == 0,
            stats['bad_weight_sum'], '==0')
        add('mesh.max_influences', stats['max_influences'] <= 4,
            stats['max_influences'], '<=4')
        add('mesh.materials',
            q.get('materials_min', 8) <= stats['materials'] <=
            q.get('materials_max', 32),
            stats['materials'], '8..32')
        h = stats['dims'][2]
        add('size.height', q.get('height_min', 1.15) <= h <=
            q.get('height_max', 1.50), round(h, 3), '1.15..1.50')
        arm_mod = [m for m in char.modifiers
                   if m.type == 'ARMATURE' and m.object]
        add('rig.armature_modifier', bool(arm_mod), len(arm_mod), '>=1')
        imgs = image_material_stats([char])
        add('texture.material_images', len(imgs) >= 3, imgs, '>=3')
        add('texture.sizes', all(min(s) >= 512 for s in imgs.values()),
            imgs, '>=512', 'P1')
    arm = next((o for o in bpy.context.scene.objects
                if o.type == 'ARMATURE'), None)
    bone_count = len(arm.data.bones) if arm else None
    if arm:
        add('rig.bones', 30 <= len(arm.data.bones) <= 90,
            len(arm.data.bones), '30..90')
        deform = [b for b in arm.data.bones if b.use_deform]
        add('rig.deform_bones', 25 <= len(deform) <= 85, len(deform),
            '25..85')
        names = [b.name for b in arm.data.bones]
        add('rig.fingers', sum(1 for n in names if n.startswith('finger_'))
            >= 10, sum(1 for n in names if n.startswith('finger_')),
            '>=10', 'P1')
        add('rig.hair', sum(1 for n in names if 'hair' in n or
                            'ponytail' in n) >= 2,
            sum(1 for n in names if 'hair' in n or 'ponytail' in n),
            '>=2', 'P1')
        add('rig.skirt', sum(1 for n in names if n.startswith('skirt_'))
            >= 2, sum(1 for n in names if n.startswith('skirt_')),
            '>=2', 'P1')
    props = manifest.get('proportions', {})
    hr = props.get('head_ratio')
    el = props.get('eye_line_from_chin')
    add('proportion.head_ratio',
        hr is not None and q.get('head_ratio_min', 3.8) <= hr <=
        q.get('head_ratio_max', 5.6), hr, '3.8..5.6')
    add('proportion.eye_line',
        el is not None and q.get('eye_line_from_chin_min', 0.38) <= el <=
        q.get('eye_line_from_chin_max', 0.56), el, '0.38..0.56')
    hb, eb = props.get('head_bbox'), props.get('eye_bbox')
    if hb and eb:
        eye_depth = round(eb[3] - eb[2], 4)
        add('face.eye_volume', eye_depth >= 0.030, eye_depth, '>=0.030m')
        add('face.eye_inside_head',
            hb[0] <= eb[0] and eb[1] <= hb[1] and
            hb[4] <= eb[4] and eb[5] <= hb[5], [hb, eb],
            'eye bbox inside head bbox')
        clearance = round(min(hb[1] - eb[1], eb[0] - hb[0]), 4)
        add('face.side_clearance', clearance >= 0.020, clearance,
            '>=0.020m', note='fixes flat eye decals on profile')
    lic = manifest.get('licenses', {})
    add('license.original_references', lic.get('references') == 'original',
        lic.get('references'), 'original')
    add('license.no_external_assets', not lic.get('external_assets'),
        lic.get('external_assets'), 'none')
    credits = os.path.join(os.path.dirname(args.manifest), 'CREDITS.md')
    add('license.credits_file', os.path.exists(credits),
        os.path.basename(credits), 'exists', 'P1')
    # renders
    for name in ('front', 'side', 'back', 'three_quarter', 'face_closeup'):
        p = os.path.join(args.renders, name + '.png')
        r = png_ok(p)
        add('render.' + name, r is not None and r[0],
            r[1] if r else None, '1024..1920')
    raw = os.path.join(args.renders, '_silhouette_raw.png')
    add('render.silhouette_alpha', os.path.exists(raw), os.path.basename(raw),
        'exists')
    stats_file = os.path.join(args.renders, 'silhouette_stats.json')
    cov = None
    if os.path.exists(stats_file):
        cov = json.load(open(stats_file, encoding='utf-8')).get('coverage')
    add('render.silhouette_coverage',
        cov is not None and q.get('silhouette_min', 0.05) <= cov <=
        q.get('silhouette_max', 0.35), cov, '0.05..0.35')
    tt = os.path.join(args.renders, 'turntable')
    frames = sorted(f for f in os.listdir(tt)) if os.path.isdir(tt) else []
    add('render.turntable_frames', len(frames) >= 8, len(frames), '>=8',
        'P1')
    add('render.turntable_gif', os.path.exists(
        os.path.join(args.renders, 'turntable.gif')),
        'renders/turntable.gif', 'exists', 'P1')
    # key hygiene
    leaks = text_key_leak(os.path.dirname(os.path.abspath(args.manifest)))
    add('security.no_key_leak', not leaks, leaks, 'no key material')
    # re-import GLB
    reimport = {}
    try:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.glb))
        meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
        arms = [o for o in bpy.context.scene.objects if o.type == 'ARMATURE']
        imgs = [i for i in bpy.data.images if i.name != 'Render Result']
        reimport = dict(meshes=len(meshes), armatures=len(arms),
                        images=len(imgs),
                        joints=len(arms[0].data.bones) if arms else 0,
                        uv=all(len(o.data.uv_layers) for o in meshes))
        add('reimport.meshes', len(meshes) >= 2, len(meshes), '>=2')
        add('reimport.armature', len(arms) == 1, len(arms), '==1')
        add('reimport.images', len(imgs) >= 3, len(imgs), '>=3')
        add('reimport.uv', all(len(o.data.uv_layers) for o in meshes),
            reimport['uv'], 'all meshes')
    except Exception as e:
        add('reimport.ok', False, str(e), 'import success')
    failures = [c for c in checks if c['level'] == 'P0' and not c['ok']]
    warnings = [c for c in checks if c['level'] == 'P1' and not c['ok']]
    report = dict(
        mode='package', ok=not failures, blender=bpy.app.version_string,
        engine='3.4.1-eevee-legacy' if bpy.app.version[1] == 4 else
        bpy.app.version_string,
        character=manifest.get('character'), tier=manifest.get('tier'),
        checks=checks, failures=[c['name'] for c in failures],
        warnings=[c['name'] for c in warnings], mesh=stats,
        reimport=reimport, bones=bone_count, elapsed_s=round(time.time() - t0, 2),
    )
    if args.report:
        with open(args.report, 'w', encoding='utf-8') as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    print('VALIDATE_P0_PASS %d/%d P1_warn %d' % (
        len([c for c in checks if c['level'] == 'P0' and c['ok']]),
        len([c for c in checks if c['level'] == 'P0']), len(warnings)))
    for c in checks:
        mark = 'PASS' if c['ok'] else ('FAIL' if c['level'] == 'P0'
                                       else 'WARN')
        print('CHECK %-28s %-4s value=%-28s need=%s' % (
            c['name'], mark, str(c['value']), c['threshold']))
    if failures:
        print('BLENDER_ANIME_FAIL', ','.join(c['name'] for c in failures))
        raise SystemExit(1)
    print('BLENDER_ANIME_OK', 'tris=%d bones=%s images=%s' % (
        stats.get('tris'), bone_count, reimport.get('images')))


if __name__ == '__main__':
    main()
