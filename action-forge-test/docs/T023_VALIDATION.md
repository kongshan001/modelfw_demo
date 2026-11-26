# T-023 验收记录（可复现）

> 日期：2026-11-26 · Godot 4.6.stable.official.89cea1439 · Blender 3.4.1 · Intel HD Graphics 6000 / OpenGL 4.1 Compatibility
> 场景：`godot/walkmove.tscn` · 报告：[`action-forge-test.md`](action-forge-test.md) T-023 · 标定：[`WALK_FORWARD_CALIBRATION.md`](WALK_FORWARD_CALIBRATION.md)

## 1. 8 方向 + 舞蹈 smoke

```bash
godot --headless --path action-forge-test/godot -s tools/smoke_walkmove.gd
# → SMOKE_WALKMOVE_OK (exit 0)
```

| clip | 8 向 body_err | 8 向 boot_err | 位移点积 | 判定 |
|---|---:|---:|---:|---|
| FIXED（yawfix） | 1.2–6.4° | 0.5–9.5° | 1.000 | 8/8 forward |
| RAW（Michelle raw） | 173.3–179.2° | 172.4–178.6° | 1.000 | 8/8 backwards |
| QUAT（Quaternius） | 0.1–2.0° | 0.0–0.1° | 1.000 | 8/8 forward |

- 每方向 0.65 s、0.8 m/s，位移 0.52–0.54 m；方向点积 1.000（8/8）。
- 方法：actor yaw = `atan2(dir.x, dir.z)`；body = `up × (upperleg.r − upperleg.l)`；boot = foot 骨骼相对 rest 的旋转增量（local→actor yaw）。阈值：body > 150° 且 boot > 120° → BACK-WALK。
- 舞蹈：

```text
SMOKE_DANCE name=IdolChickenDance_original len=8.0000 tracks=27
SMOKE_DANCE_SEAM 0.00098 rad（同场景早期 0.01640 rad）
SMOKE_DANCE_SCALE_DEV 0.000000
```

## 2. 朝向/步态采样

```bash
godot --headless --path action-forge-test/godot -s tools/diag_facing.gd
godot --headless --path action-forge-test/godot -s tools/diag_gait.gd
```

关键结果（skeleton-local / world）：

| clip | hips yaw | 身体/靴子 | root rotation | root-motion |
|---|---:|---|---|---|
| Quat `walk_loop_fit` | 0.1° | +Z | identity | +Z 0.3371 m |
| Michelle raw | 178.0° | −Z | identity | in-place |
| Michelle yawfix | −2.0° | +Z | identity | in-place |
| Rogue original `Walking_A` | 0° | +Z | identity | in-place |

## 3. Console / 稳定性

```bash
godot --headless --path action-forge-test/godot --quit-after 600 res://walkmove.tscn -- --demo=walk --speed=1.0
godot --headless --path action-forge-test/godot --quit-after 600 res://walkmove.tscn -- --demo=dance
# 两个 demo：exit 0，SCRIPT ERROR / ERROR: 计数 = 0
```

Movie Maker 录制的两个视频日志也是 0 SCRIPT/engine ERROR。

## 4. 性能（真实 GPU）

```bash
godot --path action-forge-test/godot --resolution 1280x720 -- --bench --demo=walk --speed=1.0
# BENCH_FPS_AVG=78.3 BENCH_FPS_MIN=77 BENCH_FPS_MAX=80 SAMPLES=551
# RENDERER=Intel(R) HD Graphics 6000 WINDOW=1280x720
```

- 场景：2 个角色（12 mesh 各）+ 路径/舞台环 + HUD，1280×720。
- 首轮同场景为 76.2 FPS（min 71 / max 83）；最终代码 78.3（min 77 / max 80）。两者都 ≥30。
- 1080p 实时窗口未测（显示器限制）；1080p 静帧用 SubViewport 离屏渲染。

## 5. Blender 骨长/结构

```bash
bash animation-retarget-kit/tools/blender_validate.sh action-forge-test/exports/Rogue_IdolChickenDance_original.glb
bash animation-retarget-kit/tools/blender_validate.sh action-forge-test/exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb
```

```text
DANCE: armatures=1 bones=41 meshes=12 vertices=6181 materials=1
       max_bone_length_deviation=1e-06
YAWFIX: armatures=1 bones=41 meshes=12 vertices=5901 materials=1
       max_bone_length_deviation=1e-06
```

- 舞蹈 GLB 在 Godot 里是 **1 条 8.0 s / 27 轨**；Blender 导入器把每个物体拆成独立 action（8 条），这是导入器行为，不是 GLB 有多条 clip。
- 舞蹈 GLB 的 glTF：144 channels，time 0.0000–8.0000 s；`exports/Rogue_IdolChickenDance_original.glb` 885,276 B。

## 6. 视频/截图

```text
recordings/t023_walk_direction.mp4   1280x720 30/1 12.000 s ~2.1 MB（已去音轨）
recordings/t023_idol_dance.mp4       1280x720 30/1 10.000 s ~3.0 MB（已去音轨）
recordings/*.gif                     640 px, 12 fps
screenshots/t023_walk_data_1280.png    完整 HUD：RAW 177° BACK-WALK vs FIXED 3° OK
screenshots/t023_walk_duo_1920.png     1920x1080 干净双人
screenshots/t023_walk_world_1920.png    1920x1080 世界图（SubViewport 不含 HUD）
screenshots/t023_dance_contact.png     4x2 contact sheet
screenshots/t023_dance_1280.png / _1920.png
```

## 7. 复现命令（合并）

```bash
# 1) 修正 clip（已有产物，可重跑）
python3 action-forge-test/scripts/glb_yaw_fix.py \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace.glb \
  action-forge-test/exports/Rogue_MichelleWalk_AF_inplace_yawfix.glb \
  --bone hips --yaw 180 --anim "Michelle Walk_fit" --rename "Michelle Walk_fit_yawfix"

# 2) 重新生成舞蹈（Blender 3.4.1）
/Applications/Blender.app/Contents/MacOS/Blender -b --python action-forge-test/scripts/blender_idol_dance.py

# 3) smoke + 预览/录像
godot --headless --path action-forge-test/godot -s tools/smoke_walkmove.gd
godot --path action-forge-test/godot --resolution 1280x720 --write-movie /tmp/walk.avi \
  --fixed-fps 30 --quit-after 360 res://walkmove.tscn -- --demo=walk --speed=1.0
godot --path action-forge-test/godot --resolution 1280x720 --write-movie /tmp/dance.avi \
  --fixed-fps 30 --quit-after 300 res://walkmove.tscn -- --demo=dance
```

## 8. 未覆盖 / 已知限制

- 180° 修正是刚性 hips yaw；AF 17 骨映射的屈膝/步幅小/脚滑仍在（T-009/T-013）。
- 其他 Mixamo→Rogue clip 需要逐个测 `forward_yaw`，不能默认 180°。
- 舞蹈是 stylized 原创编排，不是专业舞蹈；无手指骨，“比心”为拳形按胸；无音乐。
- 预览隐藏武器 mesh；正式游戏保留武器时需检查舞蹈穿插。
- 未测 Unity/UE 朝向标定；未测 1080p 实时窗口 FPS。
