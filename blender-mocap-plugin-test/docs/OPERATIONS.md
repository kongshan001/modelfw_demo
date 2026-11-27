# 操作与日志（可复现命令）

> 本次工作在 CLI/headless 下完成，没有屏幕录制；媒体是 Godot Movie Maker 的真实 GPU 渲染（预览/骨骼/截图）与 landmark 骨架重绘。以下命令均在本机实际执行。

## 环境

```bash
cd blender-mocap-plugin-test
bash scripts/setup_env.sh
bash scripts/download_input.sh
# MEDIAPIPE_OK 0.10.9
```

## 全流程（实际输出摘要）

```bash
bash scripts/run_pipeline.sh
```

```text
FRAMES 148
MOTION_REPORT {"n_frames":148,"fps":30.0,"seconds":4.933,"root_xz_range_m":0.0017,
 "hip_bounce_m":0.0506,"min_foot_z_m":-0.0267,"l_stride_m":0.5591,"r_stride_m":0.538,"smooth":3}
SOURCE_REPORT {"bones":18,"frames":[1,148],"fcurves":180,"fps":30,"seconds":4.9333}
RETARGET_REPORT {"clip":"Animation_MediaPipeSource","frames":[1,148],"target_bones":41,
 "mapped_bones":18,"root_bone":"hips"}
SIMPLIFY_REPORT {"frames":[1,148],"orig_keys":60680,"new_keys":5346,
 "reduction_pct":91.19,"max_channel_error":0.0019989}
SMOKE_FILE raw bones=41 meshes=12 clip=Animation len=4.9333 tracks=26 root_xz=0.0017
SMOKE_FOOT raw min_foot_y=-0.0084 longest=11 stance_slide=0.2315 hip_y_range=0.0501 scale_dev=0.000000 loop_seam=0.000deg
SMOKE_FILE simplified bones=41 meshes=12 clip=Animation len=4.9333 tracks=24 root_xz=0.0003
SMOKE_FOOT simplified min_foot_y=-0.0090 longest=11 stance_slide=0.2360 hip_y_range=0.0497 scale_dev=0.000000 loop_seam=0.000deg
MOCAP_SMOKE_OK
PIPELINE_DONE
```

## 速度

```bash
.venv/bin/python scripts/bench_image.py --image .work/frames/0037.png \
  --pose-model models/pose_landmarker_heavy.task --hand-model models/hand_landmarker.task
# pose init 0.831 s；detect [0.119,0.166,0.183] median 0.166
# hand init 0.117 s；detect [0.064,0.079,0.087] median 0.079；hands 2
```

视频：`extract_pose.py` 输出 `init_s=0.776, infer_mean_s=0.1039, infer_p95_s=0.1208, n_frames=148, n_with_pose=148`。

## 验证

```bash
bash scripts/validate.sh
# BLENDER_INSPECT 41 bones / 12 meshes / frames [1,148] @30fps / dev 1.1e-7
# VALIDATION_REPORT 41 bones / 12 meshes / dev 1e-6（validator 默认 24fps，frames [0,118]）
# FBX_INSPECT arms=1 meshes=12 verts=5901
# FBX_BONES 41 MESHES 12 / FBX_ANIM Scene len=4.9000 tracks=24
godot --headless --path godot --quit-after 600
# PREVIEW_DATA min_foot_y=-0.0082 contact=24 stance_slide=0.1983 longest=6 hip_y_range=0.0468
# 0 SCRIPT ERROR / 0 ERROR
```

## 媒体

```bash
godot --path godot --resolution 1280x720 --write-movie /tmp/walk.avi \
  --fixed-fps 30 --quit-after 300 -- --demo
ffmpeg -y -i /tmp/walk.avi -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart \
  recordings/godot_mediapipe_walk.mp4
# 300 frames / 30fps / 14s（71% real-time）；CPU render 2.08ms/frame
```


## Blender 回放渲染

```bash
mkdir -p /tmp/blender_phases
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -noaudio \
  --python scripts/render_blender_playback.py -- \
  --glb exports/Rogue_MediaPipe_walk_raw.glb --out-dir /tmp/blender_phases
# RENDER_DONE [1, 37, 74, 111, 148]；拼成 screenshots/blender_playback_phases.png
```
