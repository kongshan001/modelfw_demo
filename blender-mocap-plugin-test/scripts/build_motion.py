#!/usr/bin/env python3
"""Convert MediaPipe Pose world landmarks into a canonical armature motion.

Input JSON is produced by extract_pose.py (world landmarks, 33 per frame,
metres, MediaPipe axes: x right, y down, z depth with smaller = closer).

Output: motion.json with per-frame joint targets in Blender armature space.
Canonical frame: character forward = -Y, right = -X, up = +Z (matches the
KayKit Rogue rest orientation used by animation-retarget-kit).
"""
import argparse
import json
import math
import numpy as np

ap = argparse.ArgumentParser()
ap.add_argument('--pose', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--fps', type=float, default=30.0)
ap.add_argument('--smooth', type=int, default=3, help='moving-average window (odd); 0 = off')
ap.add_argument('--ground', type=int, default=1, help='shift root per frame so the lowest foot touches z=0')
ap.add_argument('--ground-smooth', type=int, default=5, help='moving-average window for the ground correction')
ap.add_argument('--trim-start', type=int, default=0)
ap.add_argument('--trim-end', type=int, default=-1)
args = ap.parse_args()

data = json.load(open(args.pose))
frames = data['frames']
if args.trim_end < 0:
    args.trim_end = len(frames)
frames = frames[args.trim_start:args.trim_end]
if not frames:
    raise SystemExit('no frames selected')
if any(not f.get('poses') for f in frames):
    raise SystemExit('some selected frames have no pose')

P = np.array([[f['poses'][0]['world'][i] for i in range(33)] for f in frames], dtype=np.float64)
V = np.array([[f['poses'][0]['visibility'][i] for i in range(33)] for f in frames], dtype=np.float64)
N = len(P)

def smooth_positions(P, window):
    if window <= 1 or window % 2 == 0:
        return P
    r = window // 2
    out = P.copy()
    for i in range(N):
        a = max(0, i - r); b = min(N, i + r + 1)
        out[i] = P[a:b].mean(axis=0)
    return out

P_raw = P.copy()
P = smooth_positions(P, args.smooth)

# Body basis from the first frame (median of the first 5 reduces noise).
def norm(v):
    n = np.linalg.norm(v)
    return v / n if n > 1e-9 else v

hip0 = (P[0, 23] + P[0, 24]) / 2.0
sh0 = (P[0, 11] + P[0, 12]) / 2.0
up0 = norm(sh0 - hip0)
right0 = norm(P[0, 24] - P[0, 23])
fwd0 = norm(np.cross(up0, right0))
X = -right0
Y = -fwd0
Z = up0
# sanity: face should be toward -Y (nose has negative dot with +Y)
nose_h = P[0, 0] - (P[0, 7] + P[0, 8]) / 2.0
nose_h = nose_h - up0 * np.dot(nose_h, up0)
face_y = float(np.dot(norm(nose_h), Y))
print(f'BASIS up={up0.round(4).tolist()} right={right0.round(4).tolist()} fwd={fwd0.round(4).tolist()} face_dot_Y={face_y:.3f}')

def canon(p):
    q = p - hip0
    return np.stack([q @ X, q @ Y, q @ Z], axis=-1)

C = canon(P)
C_raw = canon(P_raw)

# Grounding. MediaPipe world landmarks are hip-centred, so the take has no
# root height/bounce. If --ground, shift the whole body per frame so the
# lowest foot point sits on z=0; this reconstructs the root bounce. The
# correction is lightly smoothed to reduce landmark jitter.
min_foot_z = float(min(C[:, 31, 2].min(), C[:, 32, 2].min()))
ground = -min_foot_z
C[..., 2] += ground
C_raw[..., 2] += ground
if args.ground:
    feet_idx_all = [27, 28, 31, 32]
    dz = -C[:, feet_idx_all, 2].min(axis=1)
    if args.ground_smooth > 1:
        dz = smooth_positions(dz.reshape(-1, 1), args.ground_smooth).reshape(-1)
    C[..., 2] += dz[:, None]
    C_raw[..., 2] += dz[:, None]
    ground += float(dz.mean())

# Rest proportions from frame 0.
def d(a, b):
    return float(np.linalg.norm(C[0, a] - C[0, b]))

hip_h = float((C[0, 23, 2] + C[0, 24, 2]) / 2.0)
chest_z = float((C[0, 11, 2] + C[0, 12, 2]) / 2.0)
neck_z = float((C[0, 7, 2] + C[0, 8, 2]) / 2.0)
head_top_z = float(max(C[0, 0, 2], neck_z + 0.08))
upperarm_len = (d(11, 13) + d(12, 14)) / 2.0
forearm_len = (d(13, 15) + d(14, 16)) / 2.0
thigh_len = (d(23, 25) + d(24, 26)) / 2.0
shin_len = (d(25, 27) + d(26, 28)) / 2.0
foot_len = (d(27, 31) + d(28, 32)) / 2.0
toe_len = 0.08
shoulder_x = (abs(C[0, 11, 0]) + abs(C[0, 12, 0])) / 2.0
hip_x = (abs(C[0, 23, 0]) + abs(C[0, 24, 0])) / 2.0
hips_len = max(0.10, (chest_z - hip_h) * 0.28)
spine_len = max(0.10, (chest_z - hip_h) - hips_len)
chest_len = max(0.05, neck_z - chest_z)
head_len = max(0.10, head_top_z - neck_z)
print(f'REST hip_h={hip_h:.3f} chest_z={chest_z:.3f} neck_z={neck_z:.3f} upperarm={upperarm_len:.3f} forearm={forearm_len:.3f} thigh={thigh_len:.3f} shin={shin_len:.3f} foot={foot_len:.3f}')

# Per-frame joint targets. Hand uses the forearm direction (fist-like preset:
# MediaPipe finger landmarks are noisy and Rogue has no finger bones).
def val(i, f):
    return C[f, i]

frames_out = []
for f in range(N):
    hip = (val(23, f) + val(24, f)) / 2.0
    sh = (val(11, f) + val(12, f)) / 2.0
    spine = hip + (sh - hip) * 0.5
    ears = (val(7, f) + val(8, f)) / 2.0
    # Head bone aims up (skull), not at the nose; nose-forward would pitch
    # the target head down by ~60 degrees.
    head_top = ears + np.array([0.0, 0.0, 0.18])
    joints = {
        'hips': hip,
        'spine': spine,
        'chest': sh,
        'neck': ears,
        'head_top': head_top,
        'l_shoulder': val(11, f),
        'l_elbow': val(13, f),
        'l_wrist': val(15, f),
        'l_hand': val(15, f) + norm(val(15, f) - val(13, f)) * 0.08,
        'r_shoulder': val(12, f),
        'r_elbow': val(14, f),
        'r_wrist': val(16, f),
        'r_hand': val(16, f) + norm(val(16, f) - val(14, f)) * 0.08,
        'l_hip': val(23, f),
        'l_knee': val(25, f),
        'l_ankle': val(27, f),
        'l_foot': val(31, f),
        'l_toe': val(31, f) + norm(val(31, f) - val(27, f)) * toe_len,
        'r_hip': val(24, f),
        'r_knee': val(26, f),
        'r_ankle': val(28, f),
        'r_foot': val(32, f),
        'r_toe': val(32, f) + norm(val(32, f) - val(28, f)) * toe_len,
    }
    frame = {'t': f / args.fps, 'joints': {k: [float(x) for x in v] for k, v in joints.items()}}
    frames_out.append(frame)

# Foot contact metrics (source canonical, after ground offset).
foot_idx = {'l': (27, 31), 'r': (28, 32)}
meta = {}
for side, (ank, toe) in foot_idx.items():
    z = np.minimum(C[:, ank, 2], C[:, toe, 2])
    contact = z <= (z.min() + 0.03)
    slides = []
    run = None
    for i, c in enumerate(contact):
        if c and run is None:
            run = i
        if (not c or i == N - 1) and run is not None:
            end = i - 1 if not c else i
            if end - run >= 2:
                a = C[run, ank]; b = C[end, ank]
                slides.append(float(math.hypot(b[0] - a[0], b[1] - a[1])))
            run = None
    meta[side] = {
        'min_z': float(z.min()),
        'contact_frames': int(contact.sum()),
        'stance_slide_m': max(slides) if slides else 0.0,
        'longest_contact': int(max((len(list(g)) for k, g in __import__('itertools').groupby(contact) if k), default=0)),
        'stride_y_m': float(C[:, toe, 1].max() - C[:, toe, 1].min()),
    }

hip_xyz = np.array([(C[i, 23] + C[i, 24]) / 2.0 for i in range(N)])
meta['root_xz_range_m'] = float(math.hypot(hip_xyz[:, 0].max() - hip_xyz[:, 0].min(), hip_xyz[:, 1].max() - hip_xyz[:, 1].min()))
meta['hip_bounce_m'] = float(hip_xyz[:, 2].max() - hip_xyz[:, 2].min())
meta['ground_offset_m'] = float(ground)
meta['min_foot_z_before_offset_m'] = float(min_foot_z)
meta['take_seconds'] = N / args.fps
meta['smooth_window'] = args.smooth

out = {
    'fps': args.fps,
    'n_frames': N,
    'source_pose_json': args.pose,
    'canonical': {'forward': [0, -1, 0], 'right': [-1, 0, 0], 'up': [0, 0, 1]},
    'rest': {
        'hip_h': hip_h, 'chest_z': chest_z, 'neck_z': neck_z, 'head_top_z': head_top_z,
        'hips_len': hips_len, 'spine_len': spine_len, 'chest_len': chest_len, 'head_len': head_len,
        'shoulder_x': shoulder_x, 'hip_x': hip_x,
        'upperarm_len': upperarm_len, 'forearm_len': forearm_len, 'hand_len': 0.08,
        'thigh_len': thigh_len, 'shin_len': shin_len, 'foot_len': foot_len, 'toe_len': toe_len,
    },
    'meta': meta,
    'frames': frames_out,
}
json.dump(out, open(args.out, 'w'), indent=1)
print('MOTION_REPORT ' + json.dumps({
    'n_frames': N, 'fps': args.fps, 'seconds': round(N / args.fps, 3),
    'root_xz_range_m': round(meta['root_xz_range_m'], 4),
    'hip_bounce_m': round(meta['hip_bounce_m'], 4),
    'min_foot_z_m': round(min_foot_z + ground, 4),
    'l_stance_slide_m': round(meta['l']['stance_slide_m'], 4),
    'r_stance_slide_m': round(meta['r']['stance_slide_m'], 4),
    'l_stride_m': round(meta['l']['stride_y_m'], 4),
    'r_stride_m': round(meta['r']['stride_y_m'], 4),
    'smooth': args.smooth,
}, ensure_ascii=False))
