# 技术拆解：2D 雪天效果

参考 DEV LOG.05 的两条主线：**雪粒子** 与 **地面积雪**；本仓库在这两条上
补了雪帽、脚印、风、夜灯。下面是实际实现与踩坑。

## 0. 渲染结构

```
SubViewport 640×360（最近邻 2×）
World
├── Ground      Sprite2D + snow_ground.gdshader   ← 底图 + 雪蒙版覆盖
├── Wall        石墙
├── WallSnow    石墙雪帽（覆盖度控制 alpha）
├── SnowBack    GPUParticles2D（远景雪，World 后面）
├── World       y_sort_enabled
│   ├── Footprints  z_index=-1（脚印在道具/角色下面）
│   ├── 松树/墓碑/十字/枯树/灌木/路灯（每个都带 *_snow 雪帽）
│   └── Player      4 方向角色 + 提灯
├── SnowFront   GPUParticles2D（近景大雪片，角色前面）
├── Lights      PointLight2D + 加色 glow
└── CanvasModulate  夜晚整体压暗
```

## 1. 雪粒子：8×3 图集 + GPUParticles2D

- `assets/fx/flake.png` 是 **8×3 = 24 帧**的 8×8 雪花图集（程序化旋转/闪烁）。
- GPUParticles2D：
  - `texture = flake.png`
  - `CanvasItemMaterial.particles_animation = true`
  - `particles_anim_h_frames = 8`，`particles_anim_v_frames = 3`，
    `particles_anim_loop = true`
  - `ParticleProcessMaterial`：box 发射、向下、spread、初始速度、重力、
    scale、颜色。
- 两层：
  - 远景：amount≈170，scale 0.7，较小较慢；
  - 近景：amount≈55，scale 1.4，在角色之前。
- 风：直接改 `ParticleProcessMaterial.gravity.x`（`wind * 55`），
  每帧不用重建粒子。
- 雪量：`amount = base * snow_amount`，F2 控制 `emitting`。

**坑**：Godot 4.6 的 `CanvasItemMaterial` 没有 `particles_anim_speed` 属性；
第一版赋值直接报 “Invalid assignment …”，函数提前退出，`_snow_layers`
拿到空字典，后续 `layer["node"]` 全挂。删掉这行即可；动画速度交给粒子寿命
/`speed_scale`，或接受默认。

## 2. 地面积雪：噪声蒙版 + 覆盖度阈值

`assets/world/snow_mask.png` 是 320×180 的 fBm 噪声（路径上略降雪）：

```glsl
float t = 1.0 - coverage;
float s = smoothstep(t - 0.06, t + 0.06, m) * snow_on;
float edge = smoothstep(t - 0.14, t - 0.02, m)
          * (1.0 - smoothstep(t - 0.02, t + 0.08, m));
col = mix(base, snow_col, s);
col = mix(col, snow_shadow, edge * 0.32);
```

- `coverage` 滑杆 → 阈值；`snow_on` 是 F1 总开关。
- 雪沿蒙版等值线形成不规则边缘；`edge` 加一条冷色阴影，雪面不贴纸。
- **第一版**用低频 fBm（0.035）且把值拉满，地面成了大片“迷彩块”。
  改成 **0.05 + 0.16 双频**，并把分布整体偏向白（`0.56 + 0.7*(v-0.5)`），
  草地只在噪声低谷里露出小片；路径雪量再乘 0.92，避免整条路消失。
- F5 把 `debug_mask` 打开，全屏显示蒙版，便于教学。

## 3. 树面积雪：从精灵“向上边缘”生成雪帽

`make_cap()`（`tools/gen_art.py`）：

```python
for each pixel:
    if base alpha == 0: skip
    if pixel above is opaque: skip      # 只看向上暴露的边缘
    draw snow thickness 2–4px down, then a shadow line
```

- 不依赖手画：松树的每层枝叶、墓碑圆顶、十字横臂、石墙垛口的上沿都会自动
  被雪帽覆盖。
- 每个雪帽是独立 PNG，和底图同尺寸/同锚点；运行时叠在底图之上。
- 覆盖度控制 alpha：`clamp((coverage - threshold) / 0.32, 0, 1)`；不同道具
  的 `threshold` 不同，雪是“逐渐盖上去”的，不是一刀切。
- F3 总开关。

## 4. 脚印

- 角色移动时每 0.28s 生成一枚 `foot.png`（10×8）：左右脚交替，沿移动方向
  做少量垂直偏移和 ±0.12 弧度旋转。
- 脚印放在 `World/Footprints`（`z_index=-1`）：在雪地之上、树/角色之下。
- `Tween` 12s 把 alpha 降到 0 再 `queue_free`；F4 开关，R 清空。
- 只有 `coverage > 0.10` 才留脚印——雪化了就不该有。
- 截图/演示时注意：HUD 底栏会挡住屏幕下方 → 角色要走到画面中上段才看得到
  脚印。

## 5. 夜灯

- `CanvasModulate` 随夜晚滑杆从黄昏 `(0.58,0.62,0.76)` 压到午夜
  `(0.20,0.26,0.44)`。
- 每盏路灯：
  - `PointLight2D`（暖色 1.0/0.72/0.42，energy 1.1–1.8，轻微呼吸闪烁）；
  - 一个 **加色 glow Sprite2D**（64×64 径向贴图，`BLEND_MODE_ADD`）做地面
    光池。
- 角色提灯：一个小 PointLight2D + 呼吸闪烁。
- **注意**：地面用的是 `render_mode unshaded` 的自定义雪 shader，PointLight2D
  不会照亮它；光池靠加色 glow 完成。树/角色是普通 Sprite2D，会被 PointLight2D
  正常照亮。

## 6. HUD 与像素分辨率

- 世界 640×360，`SubViewportContainer` 2× 最近邻；HUD 独立 1280×720。
- 底部滑杆：雪量 / 积雪 / 风 / 夜晚；F1–F5、R。
- HUD 初始化时用 `set_value_no_signal(world.*)` 再回调：
  否则 HUD 默认值会覆盖世界里的 0.74，出现“画面雪很多、标签写 68%”的错位。

## 7. 其他踩坑

- `wall.png` 生成在 `assets/props/`，场景里第一版写成了 `assets/world/`，
  资源加载失败 → 整个 world.tscn 加载失败、主场景节点全空。
- 改程序化 PNG 后必须跑一次 `--editor --quit` 重新导入；否则游戏仍用旧图。
- 雪花图集的 GPUParticles2D 在 GL Compatibility 下正常；截图用真实 GPU。
- 雪蒙版的对比度/频率直接决定“雪地”还是“迷彩”；先调蒙版，再调 shader。

## 8. 验证

```bash
godot --headless --path godot-snowfall -s tools/smoke_snow.gd
godot --path godot-snowfall --resolution 1280x720 -s tools/screenshot_snow.gd
```

`SNOW_SMOKE_OK` 覆盖：雪帽数量、两层粒子、蒙版、覆盖度、风、夜晚、脚印
增删、角色动画/移动、各开关。截图输出 `/tmp/snow_shots/`。
