import argparse, glob, json, os, time
import numpy as np
import mediapipe as mp
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python import vision

ap = argparse.ArgumentParser()
ap.add_argument('--frames', required=True)
ap.add_argument('--model', required=True)
ap.add_argument('--out', required=True)
ap.add_argument('--num-poses', type=int, default=1)
ap.add_argument('--fps', type=float, default=30.0)
args = ap.parse_args()

opts = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=args.model),
    running_mode=vision.RunningMode.VIDEO,
    num_poses=args.num_poses,
    min_pose_detection_confidence=0.3,
    min_pose_presence_confidence=0.3,
    min_tracking_confidence=0.3,
    output_segmentation_masks=False,
)
t0 = time.time()
landmarker = vision.PoseLandmarker.create_from_options(opts)
init_s = time.time() - t0
files = sorted(glob.glob(os.path.join(args.frames, '*.png')))
out = {'init_s': init_s, 'fps': args.fps, 'frames': []}
infer_times = []
for i, f in enumerate(files):
    img = mp.Image.create_from_file(f)
    ts = int(round(i * 1000.0 / args.fps))
    t = time.time()
    res = landmarker.detect_for_video(img, ts)
    dt = time.time() - t
    infer_times.append(dt)
    rec = {'i': i, 't': i / args.fps, 'detect_s': dt, 'poses': []}
    for p in range(len(res.pose_landmarks)):
        w = res.pose_world_landmarks[p]
        n = res.pose_landmarks[p]
        rec['poses'].append({
            'world': [[float(l.x), float(l.y), float(l.z)] for l in w],
            'image': [[float(l.x), float(l.y), float(l.z)] for l in n],
            'visibility': [float(l.visibility) for l in n],
            'presence': [float(l.presence) for l in n],
        })
    out['frames'].append(rec)
    if (i + 1) % 20 == 0:
        print('frame', i + 1, '/', len(files), 'last_s', round(dt, 3), flush=True)
landmarker.close()
out['total_s'] = time.time() - t0
out['infer_total_s'] = sum(infer_times)
out['infer_mean_s'] = float(np.mean(infer_times)) if infer_times else 0.0
out['infer_p95_s'] = float(np.percentile(infer_times, 95)) if infer_times else 0.0
out['n_frames'] = len(files)
out['n_with_pose'] = sum(1 for r in out['frames'] if r['poses'])
with open(args.out, 'w') as fh:
    json.dump(out, fh)
print(json.dumps({k: out[k] for k in ['init_s','total_s','infer_total_s','infer_mean_s','infer_p95_s','n_frames','n_with_pose']}, indent=2))
