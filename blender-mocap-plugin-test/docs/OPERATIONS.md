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

## T-012 穿模修复（follow-up）

```bash
# 修复 + 导出 + 复制到 Godot + import + smoke
bash scripts/fix_clipping.sh
# FIX_ARM_START frames=1..148 clamp=0.550
# FIX_ARM_DONE
# FIX_FOOT_DONE max_lift_mm=65.5 mean_lift_mm=23.8 contact_adjust_min/max_mm=-26.1/0.0
# FIX_CAPE_REBIND error_mm=0.000
# FIX_EXPORT_GLB exports/Rogue_MediaPipe_walk_fixed.glb
# FIX_EXPORT_FBX exports/Rogue_MediaPipe_walk_fixed.fbx
# SMOKE_FILE fixed bones=41 meshes=7 clip=Animation len=4.9333 tracks=24 root_xz=0.0017
# SMOKE_FOOT fixed min_foot_y=0.0840 longest=12 stance_slide=0.1696 hip_y_range=0.0635
# MOCAP_SMOKE_OK / FIX_CLIPPING_DONE

# 诊断（全 148 帧汇总 + 8 帧采样；JSON 便于对比）
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -noaudio \
  --python scripts/diagnose_clipping.py -- \
  --glb exports/Rogue_MediaPipe_walk_raw.glb --out .work/clipdiag/before_diag.json
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -noaudio \
  --python scripts/diagnose_clipping.py -- \
  --glb exports/Rogue_MediaPipe_walk_fixed.glb --out .work/clipdiag/after_diag.json

# Godot 前后对比（同机位、--flat 去阴影；5 s = 150 帧；绝对路径）
godot --path godot --resolution 1280x720 --write-movie /abs/before.avi \
  --fixed-fps 30 --quit-after 150 -- \
  --nohud --still --flat --preset=2 --glb=res://assets/Rogue_MediaPipe_walk.glb
godot --path godot --resolution 1280x720 --write-movie /abs/after.avi \
  --fixed-fps 30 --quit-after 150 -- --nohud --still --flat --preset=2

# hstack + label overlay（label 用 PIL 生成 2560×720 透明 PNG）
ffmpeg -y -i /abs/before.avi -i /abs/after.avi -loop 1 -framerate 30 \
  -i .work/clipdiag/video_labels.png \
  -filter_complex "[0:v][1:v]hstack=inputs=2[bg];[bg][2:v]overlay=0:0:shortest=1,scale=1920:-2[out]" \
  -map "[out]" -t 5 -r 30 -c:v libx264 -crf 20 -pix_fmt yuv420p -movflags +faststart \
  /tmp/godot_compare.mp4
# 注意：两段独立 Godot 录制的相位/光照不齐，/tmp/godot_compare.mp4 仅作诊断；
# 验收视频用 8 相位 Blender Workbench 并排（clip_before_after_phases.mp4）。
```

关键输出：

```text
before arm L: 148/148 frames, max 253.25 mm (f111), max 194 verts/frame
before arm R: 148/148 frames, max 291.66 mm (f131), max 224 verts/frame
after  arm L: 36/148 frames >4 mm, max 11.78 mm (f11),  max 6 verts/frame
after  arm R: 34/148 frames >4 mm, max 11.75 mm (f24),  max 6 verts/frame
before foot mesh: L -174.36 mm (148 frames <0), R -159.43 mm (145 frames <0)
after  foot mesh: L +1.0 mm (0 <0), R +1.0 mm (0 <0)
stance slide: 0.2315 m → 0.1696 m (bone head 90-sample; HUD 40-sample 0.213; no foot lock)
hip range: 0.0501 m → 0.0635 m; root XZ: 0.0017 m (unchanged); contact L64/R96, longest 17/29
```

注意：

- `--flat` 只用于前后光照一致的对比证据；默认预览保留阴影。`--phase` 会在 `_measure()` 之后重新 seek（`preview.gd` 已修），否则静止截图会被测量 scrub 到片尾。
- 修复版 clean GLB 是 **7 mesh**（不含 5 件 handslot 武器），raw 仍是 12 mesh；`smoke.gd` 已按 fixed=7 检查。
- HUD 的 `foot bone min` 修复后约 +9.3 cm（40 采样；smoke +8.4 cm）是 foot 骨 head，不是 mesh 脚底；真实 mesh 最低 +0.1 cm（Blender 诊断），HUD 已加注。
- `recordings/godot_walk_before_flat.avi` / `godot_walk_after_flat.avi` 是对比视频的 1280×720 中间源，体积大，未提交；用上面的 `--write-movie` 命令可重新生成。
- 交付媒体是 `recordings/clip_before_after_phases.mp4`（1200×726，8 s，8 相位并排）与 `.gif`（960 宽，10 fps）；由 Blender Workbench 的 8 帧 before/after + PIL 标签 + ffmpeg 生成。
- 两段独立 Godot Movie Maker 前后录制受加载/`_measure` 时序影响，相位/光照不齐，未作为最终对比视频；Godot 侧证据是 `screenshots/clip_after_hud_1280.png` 和脚部静止图。

T-012 验收补充：

```text
godot --headless --path godot --quit-after 600 → exit 0，0 SCRIPT ERROR / 0 ERROR
Movie Maker fixed 5 s / 150 帧：6–9 s（55–83% realtime），CPU 2.43–2.46 ms/帧
HUD 截帧（screenshots/clip_after_hud_1280.png）：FPS 32、7 mesh、foot 骨 +9.3 cm / mesh +0.1 cm、arm clip 11.8 mm、stance 0.213 m / hip 5.3 cm
```

T-012 FBX 验证：

```text
godot --headless --path godot -s tools/inspect_fbx.gd
# FBX_BONES 41 MESHES 12 ... FILE res://assets/Rogue_MediaPipe_walk.fbx
# FBX_ANIM Scene len=4.9000 tracks=24
# FBX_BONES 41 MESHES 7 ... FILE res://assets/Rogue_MediaPipe_walk_fixed.fbx
# FBX_ANIM Scene len=4.9000 tracks=24
```
