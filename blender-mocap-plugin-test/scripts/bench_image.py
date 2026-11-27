#!/usr/bin/env python3
"""Benchmark the exact MediaPipe fast-mode models on one image."""
import argparse, json, statistics, time
import mediapipe as mp
from mediapipe.tasks.python import BaseOptions
from mediapipe.tasks.python import vision

ap = argparse.ArgumentParser()
ap.add_argument('--image', required=True)
ap.add_argument('--pose-model', required=True)
ap.add_argument('--hand-model', required=True)
ap.add_argument('--runs', type=int, default=3)
args = ap.parse_args()
img = mp.Image.create_from_file(args.image)
opts = vision.PoseLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=args.pose_model),
    running_mode=vision.RunningMode.IMAGE, num_poses=1,
    min_pose_detection_confidence=0.3, min_pose_presence_confidence=0.3,
    output_segmentation_masks=False)
t = time.time(); pose = vision.PoseLandmarker.create_from_options(opts); init = time.time() - t
pose.detect(img)
times = []
for _ in range(args.runs):
    t = time.time(); res = pose.detect(img); times.append(time.time() - t)
pose.close()
hopts = vision.HandLandmarkerOptions(
    base_options=BaseOptions(model_asset_path=args.hand_model),
    running_mode=vision.RunningMode.IMAGE, num_hands=2,
    min_hand_detection_confidence=0.3, min_hand_presence_confidence=0.3,
    min_tracking_confidence=0.3)
t = time.time(); hand = vision.HandLandmarker.create_from_options(hopts); hinit = time.time() - t
hres = hand.detect(img)
htimes = []
for _ in range(args.runs):
    t = time.time(); hres = hand.detect(img); htimes.append(time.time() - t)
hand.close()
print(json.dumps({
    'image': args.image,
    'pose_init_s': round(init, 3),
    'pose_detect_s': [round(x, 3) for x in times],
    'pose_median_s': round(statistics.median(times), 3),
    'poses': len(res.pose_landmarks),
    'hand_init_s': round(hinit, 3),
    'hand_detect_s': [round(x, 3) for x in htimes],
    'hand_median_s': round(statistics.median(htimes), 3),
    'hands': len(hres.hand_landmarks),
}, indent=2))
