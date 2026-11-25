"""Aggregate validation for the Qinghe blink test (pure Python, no bpy).

  python3 tools/blender_blink/validate_blink.py

Reads qinghe_blink.glb + the build/render/reimport/Godot reports and writes
agent-probes/blink-test/blink_validation.json with explicit PASS/FAIL checks.
"""

import json
import os
import struct
import sys

import numpy as np

TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(TOOLS))
OUT = os.path.join(REPO, 'agent-probes', 'blink-test')
GLB = os.path.join(OUT, 'qinghe_blink.glb')
sys.path.insert(0, TOOLS)
import blink_schedule  # noqa: E402


def read_glb(path):
    with open(path, 'rb') as f:
        magic, version, length = struct.unpack('<III', f.read(12))
        assert magic == 0x46546C67, 'not a GLB'
        chunks = {}
        while f.tell() < length:
            clen, ctype = struct.unpack('<II', f.read(8))
            chunks[ctype] = f.read(clen)
        return json.loads(chunks[0x4E4F534A].decode('utf-8')), chunks


def accessor_array(g, chunks, idx):
    acc = g['accessors'][idx]
    bv = g['bufferViews'][acc['bufferView']]
    off = bv.get('byteOffset', 0) + acc.get('byteOffset', 0)
    comps = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[acc['type']]
    dt = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}[acc['componentType']]
    return np.frombuffer(chunks[0x004E4942], dtype=dt,
                         count=acc['count'] * comps, offset=off).reshape(-1, comps if comps > 1 else 1)


def load(name, required=True):
    p = os.path.join(OUT, name)
    if not os.path.exists(p):
        if required:
            raise SystemExit('missing %s' % p)
        return None
    with open(p) as f:
        return json.load(f)


def main():
    g, chunks = read_glb(GLB)
    build = load('blink_report.json')
    schedule = load('blink_schedule.json')
    media = load('media_metrics.json')
    reimport = load('reimport_check.json')
    checks = []

    def check(name, ok, detail):
        checks.append({'check': name, 'pass': bool(ok), 'detail': detail})

    # ── GLB structure ──────────────────────────────────────────────────────
    lid_mesh = next((m for m in g['meshes'] if m.get('extras', {}).get('targetNames')), None)
    targets = lid_mesh['extras']['targetNames'] if lid_mesh else []
    expected = ['Blink_Half', 'Blink_Closed', 'Blink_Left_Half',
                'Blink_Left_Closed', 'Blink_Right_Half', 'Blink_Right_Closed']
    check('glb_morph_targets', targets == expected, targets)
    check('glb_skins', len(g.get('skins', [])) == 1 and
          len(g['skins'][0]['joints']) == 22,
          [(s.get('name'), len(s['joints'])) for s in g.get('skins', [])])
    check('glb_textures', len(g.get('images', [])) == 3,
          [i.get('name') or i.get('mimeType') for i in g.get('images', [])])
    mats = {m['name']: m for m in g['materials']}
    skin_col = mats['Skin_blinkGLTF']['pbrMetallicRoughness'].get('baseColorFactor', [1, 1, 1, 1])
    check('glb_skin_not_white', max(skin_col[:3]) < 0.99 and min(skin_col[:3]) > 0.1,
          [round(x, 3) for x in skin_col])

    # ── animation ──────────────────────────────────────────────────────────
    anim = g['animations'][0]
    ch = next(c for c in anim['channels'] if c['target']['path'] == 'weights')
    s = anim['samplers'][ch['sampler']]
    times = accessor_array(g, chunks, s['input']).ravel()
    w = accessor_array(g, chunks, s['output'])
    if w.shape[1] == 1 and w.size % len(targets) == 0:
        w = w.reshape(-1, len(targets))
    check('glb_animation_present', anim['name'] in ('Blink_Loop', 'Blink'), anim['name'])
    check('glb_animation_length', abs(times.max() - 7.0) < 1e-4 and
          abs(times.min() - 1 / 24) < 1e-3, [round(float(times.min()), 4), round(float(times.max()), 4)])
    check('glb_animation_samples', len(times) == 168 and w.shape == (168, 6),
          [len(times), list(w.shape)])
    check('glb_weights_range', float(w.min()) >= -1e-6 and float(w.max()) <= 1.0 + 1e-6,
          [round(float(w.min()), 4), round(float(w.max()), 4)])
    check('glb_weights_start_end_zero', float(np.abs(w[0]).max()) == 0.0 and
          float(np.abs(w[-1]).max()) == 0.0, [list(np.round(w[0], 3)), list(np.round(w[-1], 3))])

    idx = {n: i for i, n in enumerate(targets)}
    closure_l = np.clip(w[:, idx['Blink_Left_Closed']] + 0.5 * w[:, idx['Blink_Left_Half']], 0, 1)
    closure_r = np.clip(w[:, idx['Blink_Right_Closed']] + 0.5 * w[:, idx['Blink_Right_Half']], 0, 1)
    check('glb_blinks_reach_closed', closure_l.max() == 1.0 and closure_r.max() == 1.0,
          [float(closure_l.max()), float(closure_r.max())])

    # ── schedule ───────────────────────────────────────────────────────────
    ok, why = blink_schedule.is_valid(schedule)
    check('schedule_valid', ok, why)
    check('schedule_3_to_5_blinks', 3 <= len(schedule['blinks']) <= 5,
          len(schedule['blinks']))
    check('schedule_one_double', schedule['double_pairs'] == 1,
          [b['start'] for b in schedule['blinks'] if b['double']])
    check('schedule_holds_1_2_frames',
          all(1 <= b['hold'] <= 2 for b in schedule['blinks']),
          [b['hold'] for b in schedule['blinks']])
    check('schedule_lr_stagger', any(b['left_off'] or b['right_off'] for b in schedule['blinks']),
          [(b['left_off'], b['right_off']) for b in schedule['blinks']])
    stats = blink_schedule.stats(200)
    check('double_rate_5_10pct', 5.0 <= stats['pairs_per_100_blinks'] <= 10.0, stats)

    # L/R stagger visible in exported weights
    stagger_frames = [i + 1 for i in range(168) if abs(closure_l[i] - closure_r[i]) > 0.2]
    check('exported_lr_stagger_frames', len(stagger_frames) >= 4, stagger_frames)

    # ── lid design ─────────────────────────────────────────────────────────
    cov = build['coverage_centre']
    check('coverage_80_90_10_20', 80 <= cov['upper_pct'] <= 90 and
          10 <= cov['lower_pct'] <= 20, cov)
    off = build['offset_surface_checks']
    check('highlight_clearance', off['blend_open_half_min_offset_m'] > off['highlight_offset_m'] + 0.001 and
          off['blend_half_closed_min_offset_m'] > off['highlight_offset_m'] + 0.001,
          {'blend_min_m': min(off['blend_open_half_min_offset_m'], off['blend_half_closed_min_offset_m']),
           'highlight_m': off['highlight_offset_m'],
           'naive_sag_would_be_m': off['naive_open_closed_mid_sag_min_offset_m']})
    check('lash_faces_replaced', build['lash_faces_removed'] == 56,
          build['lash_faces_removed'])
    check('per_side_isolation', build['left_key_moved_right_verts'] == 0 and
          build['right_key_moved_left_verts'] == 0,
          [build['left_key_moved_right_verts'], build['right_key_moved_left_verts']])

    # ── re-import / Godot ──────────────────────────────────────────────────
    check('blender_reimport_targets', reimport['target_count'] == 6 and
          reimport['action_frame_range'] == [1.0, 168.0], reimport['target_count'])
    check('blender_reimport_morph_drives', reimport['morphs_drive_geometry'] and
          reimport['max_vertex_drift_frame1_to_17_m'] > 0.05,
          {'drift_m': reimport['max_vertex_drift_frame1_to_17_m'],
           'moved_over_1mm': reimport['moved_verts_over_1mm']})
    godot = open(os.path.join(OUT, 'godot_import_check.txt')).read() if os.path.exists(
        os.path.join(OUT, 'godot_import_check.txt')) else ''
    check('godot_import', 'GODOT_CHECK_OK' in godot and 'blend_shapes=6' in godot and
          'blend_shape_tracks=6' in godot and 'bones=22' in godot,
          {'blend_shapes': 'blend_shapes=6' in godot,
           'tracks': 'blend_shape_tracks=6' in godot,
           'bones': 'bones=22' in godot,
           'animation': [l.strip() for l in godot.splitlines() if l.startswith('ANIM ')][:1]})

    # ── media ──────────────────────────────────────────────────────────────
    mp4 = os.path.join(OUT, 'blink_face_loop.mp4')
    check('media_mp4', os.path.getsize(mp4) > 50000 and media['frames'] == 168,
          {'bytes': os.path.getsize(mp4), 'duration_s': 7.0})
    read = media['blink_readability']
    check('media_target_size', read['target_char_height_px'] == 180 and
          read['changed_pct_of_eye_roi'] > 15,
          {'char_px': read['target_char_height_px'],
           'changed_pct_eye_roi': read['changed_pct_of_eye_roi'],
           'mean_abs_diff_eye_roi': read['mean_abs_diff_eye_roi']})
    check('open_state_parity', media['open_state_parity']['mean_abs_diff'] < 5.0,
          media['open_state_parity'])

    passed = sum(1 for c in checks if c['pass'])
    result = {
        'asset': 'agent-probes/blink-test/qinghe_blink.glb',
        'generated': '2026-11-25',
        'checks': checks,
        'summary': {'passed': passed, 'total': len(checks),
                    'ok': passed == len(checks)},
        'numbers': {
            'blink_count': len(schedule['blinks']),
            'fps': schedule['fps'],
            'duration_s': schedule['duration_s'],
            'seed': schedule['seed'],
            'double_rate_pairs_per_100_blinks': stats['pairs_per_100_blinks'],
            'coverage': cov,
            'blend_clearance_m': {
                'min': min(off['blend_open_half_min_offset_m'],
                           off['blend_half_closed_min_offset_m']),
                'highlight': off['highlight_offset_m']},
            'target_size': read,
            'open_parity': media['open_state_parity'],
            'glb_bytes': os.path.getsize(GLB),
        },
    }
    path = os.path.join(OUT, 'blink_validation.json')
    with open(path, 'w') as f:
        json.dump(result, f, indent=2,
                  default=lambda o: o.item() if hasattr(o, 'item') else str(o))
    for c in checks:
        print(('PASS ' if c['pass'] else 'FAIL ') + c['check'], c['detail'])
    print('SUMMARY %d/%d' % (passed, len(checks)))
    print('WROTE', path)
    if passed != len(checks):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
