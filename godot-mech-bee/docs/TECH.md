# 技术拆解：Godot 里的机械蜂拆解模拟器

> 参考开源项目 [elvarofficial/teardown](https://github.com/elvarofficial/teardown)（MIT）
> 的 Mellis HB-7 示例思路，用 Godot 4.6 从零实现。没有使用原项目的代码、模型或贴图。

## 0. 一句话版本

一个**纯函数求解器**同时驱动翼摆、机身姿态、腿部微动和四周仪表；
程序化几何 + 假棚拍光照让它在 GL Compatibility 下也像一张工业设计图；
爆炸/隔离只是“每件零件一个位移方向 + 一个可见性开关”。

## 1. 单求解器：数字和动作同源

`src/mech_solver.gd` 只依赖 `sin/cos/lerp`，不碰节点：

| 输出 | 用途 |
| --- | --- |
| `beat_hz()`、`wing_angle(i)`、`wing_angle_at(i, offset)` | 四翼 + 残影的摆角 |
| `bob() / pitch_deg() / roll_deg() / yaw_drift()` | 机身漂浮与姿态 |
| `power_draw() / battery() / motor_temp()` | 左侧 POWER 卡片 |
| `servo_load(i)` | 六路腿部负载条 |
| `alt_agl() / vertical_speed()` | 右侧 FLIGHT 姿态仪与数值 |
| `subsystem_rows()` | 六行子系统状态与颜色 |

HUD 每帧读同一组函数，所以“仪表 83%”和“模型动作”不可能矛盾。换状态只是换
`state` 字符串；`beat_hz()` 等函数内部按状态返回不同参数。

**好处**：无头测试可以完全不渲染地断言遥测；改参数只改一处；以后把求解器搬去
Three.js / Unity 时，只要保持同样的函数契约（见 `portable-core` 的思路）。

## 2. 程序化机械蜂

`src/mech_model.gd` 用 Godot 原语拼出 17 个 `Part`：

- **身体**：胸（黑芯 + 白壳 + 红环 + 黄铜螺栓）、头（白壳 + 黑颈环 + 触角）、
  腹两段（白球段 + 黑箍 + 红环）、尾齿轮（环 + 12 齿）。
- **两对翅膀**：`QuadMesh` + GDScript 逐像素生成的翅膀纹理（膜 + 叶脉 + 前缘）。
- **六条腿**：髋/膝/踝/趾四段圆柱 + 关节点球；每条腿独立 pivot，可单独拆。
- **透明舱**：低 alpha 球壳 + 黄铜环，组装时几乎不可见，拆开时成为独立零件。

每个 `Part` 记录 `home`、`explode_dir`、`label_local`、`meshes`。爆炸就是
`node.position = home + explode_dir * amount`；隔离就是 `node.visible`。

### 2.1 翅膀纹理

`Image.create(256, 512)` 逐像素画：

- 形状：按 y 计算宽度，`sin(pi * t^0.75)` 的泪滴形；
- 膜 alpha ≈ 0.62，边缘 0.9；
- 中心叶脉 + 每 20px 一组斜向支脉 + 前缘深线；
- **透明区域的 RGB 也填成奶油色**，否则 mipmap/线性过滤会把 RGB 平均向黑色，
  翅膀会发黑（本轮真实踩坑）。

## 3. 爆炸 / 回装 / 隔离

`animate(solver, explode_t)` 里：

1. `explode_t` 由主场景 `move_toward` 逼近目标（0 或 1，速度 0.85/s）；
2. 按状态选 active 集合：
   - `TEARDOWN` / `REASSEMBLY` → 全部；
   - `WING OFF` → 四翼；
   - `ABDOMEN OPEN` → 腹部两段 + 尾 + 透明舱；
   - `THORAX OPEN` → 胸 + 透明舱；
3. 每件零件按 `smoothstep(index % 5 * 0.035, 1, explode_t)` 级联，避免同时弹出；
4. 相机距离随 `explode_t` 增加 2.6，保证拆开后仍在画面内；
5. 隔离时隐藏其他零件，相机目标/距离缓动到选中零件。

## 4. HUD 与标签

`src/mech_hud.gd` 全部用代码搭：

- 暖纸色 `StyleBoxFlat` 面板 + 细边框；
- 自绘 `Waveform`（翼频波形）与 `Attitude`（姿态仪）；
- 电池格、ProgressBar 负载条、状态 chip；
- 左侧 `WING BEAT / POWER / LEG SERVOS`，右侧 `FLIGHT / ASSEMBLIES / DISPLAY / SUBSYSTEMS`，
  顶部状态条，底部飞行日志；
- `ASSEMBLIES`/`DISPLAY` 按钮直接调用主场景的状态与选择接口。

`src/labels_overlay.gd` 把 3D 零件锚点投影到屏幕，标签固定在左右两条边栏：

- 每侧按 y 排序，`last_y + 15` 做简单防重叠；
- 引线是“锚点 → 折点 → 边栏”的两段折线；
- 选中零件额外画红色角标；
- 场地里再画几个红色十字标记，模拟工程图的定位点。

## 5. 自动巡览与接管

- 状态每 5.5s 轮换：HOVER → BANKING → WING OFF → ABDOMEN OPEN → THORAX OPEN →
  TEARDOWN → REASSEMBLY → DEPARTING；
- 零件高亮每 2.2s 轮换；
- 任何鼠标/键盘输入调用 `_take_over()`，停止自动巡览；静置 15s 恢复；
- 相机可拖拽/滚轮；转台开关控制持续环绕。

## 6. 本轮真实踩坑

| 现象 | 根因 | 修复 |
| --- | --- | --- |
| 翅膀全黑/像黑铁片 | 生成纹理后忘了 `set_shader_parameter("wing_tex", ...)`；透明区域 RGB=0 又被过滤平均 | 绑定纹理；透明区 RGB 填奶油；`filter_linear` |
| 翅膀像一排线、几乎没有面 | 相机在目标下方（pitch=-10°），水平翅膀几乎侧看 | 相机抬到 +8°，翅膀加 14° 上反角 |
| 拆开后零件飞出画面 | 爆炸位移按“教学夸张”写的 2–4 单位 | 位移缩到约 55%，相机随 `explode_t` 拉远 |
| 隔离后画面空 | 选中的光学镜头在爆炸状态、相机没跟随 | 隔离时相机目标/距离缓动到零件 |
| 截图黑块阴影 | 接触阴影是纯色 Quad | 生成径向 alpha 贴图 |
| 白色壳发灰 | unshaded 的“环境 + 漫反射”权重过低 | 提高环境项，白色材质拉到 #FFFFFF |
| 暂停仍走时间 | `solver.step()` 在 `solver.paused = paused` 之前 | 先设 state/paused，再 step |
| 标签被左右 HUD 盖住 | 标签水平位置按锚点算，落进面板区 | 标签固定在 x=272/1008 两条边栏 |

## 7. 验证

```bash
bash tools/verify.sh
# MECH_SMOKE_OK parts=17 moved=17
```

无头断言覆盖：

- 悬停翼频 > 0，翼角随时间变化；
- 零件数 17、HUD/标签存在；
- TEARDOWN 后 `explode_t ≥ 0.8`，至少 12 件离开原位，翼停；
- REASSEMBLY 后 `explode_t ≤ 0.05`；
- 隔离只显示选中件，释放后恢复；
- WING OFF 时翼频为 0 且翼位移；
- 暂停不推进求解器时间。

视觉验收：

- `tools/screenshot_mech.gd` → 5 张 1280×720 截图；
- `tools/capture_mech_gif.gd` → 180 帧 20fps，ffmpeg 输出 GIF/MP4。
