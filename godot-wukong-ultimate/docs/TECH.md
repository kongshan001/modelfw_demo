# 技术说明 — 齐天大圣 · 极意（Godot 4.6）

## 1. 总览

| 项 | 值 |
| --- | --- |
| 引擎 | Godot 4.6 stable（`89cea1439`），GL Compatibility |
| 窗口 | 1280×720，`canvas_items` 拉伸 |
| 3D 缩放 | `rendering/scaling_3d/scale=0.9` |
| 角色 | `assets/models/wukong_ultimate.glb`：1 蒙皮网格、15 材质分区、56,072 tris、29 关节、6 动画 |
| 输入 | WASD / 长按/松开空格 / 鼠标拖拽 / 滚轮 / R |
| 场景 | 单场地：浮空试炼场 + 石傀训练体 |
| 第三方运行时依赖 | 无 |

## 2. 资源导入与角色绑定

- Blender 3.4.1 构建（详见 `blender-wukong-ultimate/docs/TECH.md`）：英雄比例网格（union → voxel remesh → smooth → decimate）、自定义布料/发片/管状网格、显式距离权重蒙皮、2 骨 IK + bake。
- GLB 导出时逐 action 烘焙 IK 可视关键帧，删除 `ctrl_*` 非变形控制骨；时间轴整体减 1 帧使每个 clip 从 0 s 开始。
- Godot 导入结果：
  - `Skeleton3D` 29 骨；`AnimationPlayer` clips：`Cast / Charge / Hit / Idle / Run / Victory`；
  - `MeshInstance3D` 15 surfaces，全部材质 `vertex_color_use_as_albedo=true`；
  - 动画长度（s）：Idle 2.0、Run 0.667、Charge 1.333、Cast 1.208、Hit 0.542、Victory 2.0。
- 模型初始朝向：Blender +X → Godot +X；`player.gd` 将导入根节点绕 Y 旋转 −90°，使角色面向本地 +Z；玩家根节点朝向由 `atan2(dir.x, dir.z)` 驱动。
- 材质后处理（`player.gd::_style_materials`）：复制 surface override，设置 rim、粗糙度、金属度、眼部自发光、皮肤/面部暖色；金饰降低 metal 到 0.55 并加微弱 emission，避免 GL 兼容无反射时偏黑。

## 3. 场景与碰撞

- 场地：半径 9.0 圆柱平台，玩家 XZ 限制 8.2；地面 StaticBody3D 使用 CylinderShape3D（layer 1）。
- 玩家：CharacterBody3D，CapsuleShape3D r0.34/h1.85；collision layer 1，mask 1|2。
- 石傀：StaticBody3D，BoxShape3D 1.45×2.25×0.95；layer 2。
- 气功弹：每物理帧用 `intersect_ray(from, to, mask=1|2)`，排除玩家 RID；命中的 collider 若实现 `take_hit` 即造成伤害。
- 相机：非 SpringArm，直接计算轨道偏移；场地开阔，不做相机碰撞。

## 4. 玩家状态机与数值

状态：`idle / run / charge / cast / hit / victory / dead`。

| 参数 | 值 |
| --- | --- |
| 移动速度 | 4.6 m/s |
| 加速度 / 减速 | 24 / 20 |
| 蓄力时间 | 1.15 s（charge 0→1） |
| 蓄力时移动倍率 | 0.26 |
| 最小蓄力能量 | 12 |
| 放波伤害 | `30 + 90 × power`（最大 120） |
| 放波耗气 | `22 + 28 × power` |
| 气回复 | 12 / s（非蓄力） |
| 击退 | 视觉回弹 + 石傀受击 tween |
| 蓄力/放波动画 | Charge 循环；Cast 单次 |
| 受击动作 | Hit 单次，0.48 s 后回 locomotion |
| 胜利 | main 调 `play_victory()`，Victory 单次 |

- 移动方向以当前 Camera3D 的水平 basis 计算；无相机时回退世界 −Z。
- 放波朝向取玩家本地 +Z（`global_basis.z`），便于“角色面向 = 弹道方向”；演示工具会先 `aim_at(dummy)`。
- 蓄力/放波过程中的气功核心、能量刃、浮空碎石、地面环和灯光强度由 `_update_aura_visuals` 驱动；斗气体壳已移除，避免“玻璃罩”感。
- 受击后 0.55 s 无敌，避免脉冲/多段瞬间连扣。

## 5. 石傀

| 参数 | 值 |
| --- | --- |
| HP | 240 |
| 脉冲半径 / 伤害 | 3.4 m / 14 |
| 预警 | 1.15 s，红圈从 25% 扩到 100% |
| 冷却 | 6.6 s（进入 8 m 才启动） |
| 受击 | 后仰 + 0.22 m 视觉回弹；核心灯闪烁 |
| 崩塌 | 0.65 s 旋转/下沉/核心收缩，0.55 s 后发 `defeated` |
| 击退 | 视觉体 tween；静态碰撞不位移 |

脉冲实现：`_telegraphing` → 红圈放大 + 核心灯高频闪 → 到点检查玩家距离 → 造成伤害并生成扩散冲击环。

## 6. 相机与震屏

- 默认距离 4.9 m、俯角约 −13°；滚轮 3.2–8.6；拖拽 yaw/pitch。
- 相机子节点 `CameraKey` SpotLight3D（暖白，range 20，angle 52°，无阴影）随视角照亮角色。
- 震屏：`trauma` 0–1，按 `trauma²` 叠加多频 sin 位移与 roll，1.5/s 衰减；命中/脉冲/放波调用 `add_trauma()`。
- `set_cinematic_camera(pos, look, fov)` / `clear_cinematic_camera()` 供截图与录屏；电影机忽略震屏。

## 7. VFX / HUD

- **蓄力**：6 块小浮石 + 6 条能量刃（additive）+ 34 个能量尘粒子 + 地面环 + 胸前能量球 + 蓝色 OmniLight；能量球/环随 charge 缩放。
- **放波**：炮口小闪光 + KiBlast（白色核心球、蓝色辉光球、环、点光、世界空间拖尾粒子、火花粒子）。
- **命中**：橙色热闪球、地面冲击环、24 火花粒子、14 碎石粒子、点光闪、震屏、伤害数字。
- **伤害数字**：Label3D + SystemFont，billboard、无深度、缩放弹出 + 上浮淡出。
- **HUD**：`Control._draw()` 自绘倾斜血条/气条/蓄力条、石傀血条、连击环（2.4 s 圈）、教学条、脉冲警告、胜利/失败面板；字体用 SystemFont（PingFang SC / Hiragino / Noto Sans CJK / 微软雅黑）。
- **阴影**：为兼容 Intel 集显，关闭方向光实时阴影；玩家/石傀用低透明度圆形 blob 阴影接地。

## 8. 性能策略（实测 Intel HD 6000）

初版（真实光源 + 阴影 + glow + 8 灯）：**avg 23.8 / min 4.0**，不达标。

调整后：

| 改动 | 效果 |
| --- | --- |
| 关闭方向光阴影 | 主要开销 |
| 8 灯 → 月光 + 暖色方向光 + 2 Omni + 相机 Spot（5 盏常驻） | 降低每像素光照 |
| 关闭环境 glow | 兼容渲染器下不可靠且耗 |
| `scaling_3d/scale=0.9` | 填充率 |
| blob 阴影、暖色方向补光、曝光 1.6 | 补回可读性 |
| 入场 shader 预热（小闪光 + 蓄力 + 空放弹） | 消除首次命中长卡顿 |

最终：

```text
WUKONG_ULT_FPS avg=39.2 min=11.0 samples=24
WUKONG_ULT_FPS_OK
```

多轮采样 avg 39–43（最终 39.2）；`min` 11–22 为压力循环中命中爆发的短时低值，持续约 40。加光束尾前曾测得 avg 43.3/min 22。

## 9. 验收

```bash
bash tools/verify.sh
# WUKONG_ULT_SMOKE_OK / WUKONG_ULT_VERIFY_OK
```

Smoke 断言（`tools/smoke_ultimate.gd`）：

1. GLB：骨骼 ≥25、6 个 clip 存在、Idle 起始、track 数 >10；
2. 真实 InputMap：W 前进 >0.35 m，动画切 Run；松开回 Idle；
3. 蓄力：`begin_charge` → charge>0.35、Charge clip → `release_charge` → Cast clip；
4. 蓄力释放的弹命中石傀；再次脚本弹对 240 HP 石傀造成 120；
5. 石傀脉冲：近距离触发 → 玩家 HP 降、Hit clip；
6. 石傀血量归零 → victory、Victory clip；
7. reset：状态/血量/石傀全部恢复，回 Idle。

其它验收：

```bash
godot --headless --path . --quit-after 600   # exit 0，无 SCRIPT ERROR
godot --path . --resolution 1280x720 -s tools/screenshot_ultimate.gd
godot --path . --resolution 1280x720 -s tools/capture_ultimate_gif.gd
godot --path . --resolution 1280x720 -s tools/probe_fps.gd
```

## 10. 已知技术债 / 风险

- 程序化角色仍有局部块面感；手指简化，无面部骨骼/表情。
- VFX 每次命中新建节点/材质，压力采样里会出现短时掉帧；可做对象池。
- 无音频、触控、设置存档；单场地。
- 石傀为静态体；击退仅视觉。
- 中文 HUD 依赖系统中文字体。
- GIF 采集使用自适应 `Engine.time_scale` 保持 1/20 s 游戏时间/帧；不同机器上光照/帧率会略有差异。
