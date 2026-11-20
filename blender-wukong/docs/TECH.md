# 技术拆解：程序化角色 + 骨架 + 蒙皮 + 气功波

> 目标不是做影视级雕刻，而是验证一条完整的 **建模 → 绑骨 → 蒙皮 → 动画 → 渲染/导出** 链路，
> 用 Blender 3.4.1 + Python (`bpy`) 全部程序化完成。

## 0. 一句话版本

用球/柱/锥/环拼出一个 chibi 猴王，把零件 join 成一个网格，**显式写顶点组**绑到 25 根骨骼，
用 2 骨 IK 摆姿势，关键帧做「蓄力 → 推掌 → 光束」，EEVEE 渲染 8 秒，GLB 烘焙导出。

## 1. 建模

### 1.1 比例

- 总高约 2.0（金发到 2.4），头径 0.66，chibi 头身比；
- 面向 +X，Z 向上；脚底在 z=0，髋 z≈0.98，胸 z≈1.4，头心 z≈1.82。

### 1.2 部件

| 部位 | 几何 |
| --- | --- |
| 头/脸 | 球体 + 凸出的猴嘴/鼻子/嘴线 + 眼白/琥珀虹膜/瞳孔 + 黑眉 |
| 耳朵 | 外侧球 + 内侧浅色球 |
| 金发 | 12 个圆锥沿头顶/后脑方向放射 + 发帽球体 |
| 金箍 | 环形 torus + 前方红宝石 |
| 躯干 | 布料球体；红色胸甲 + 金色 trim；腰带 + 方扣 |
| 四肢 | 圆柱段 + 关节球；肩甲、护腕、膝甲、靴子 |
| 尾巴 | 4 段圆柱 + 关节球 + 浅色尾尖 |
| 金箍棒 | 背后斜放的金色圆柱 + 红色端帽，刚性绑到 chest |

所有零件都 `apply_transform`（旋转/缩放）后记录，方便计算世界坐标权重。

## 2. 骨架

25 根骨骼：

```
root
└─ hips
   ├─ spine → chest → neck → head
   │           ├─ shoulder.L → upper_arm.L → forearm.L → hand.L
   │           └─ shoulder.R → upper_arm.R → forearm.R → hand.R
   ├─ thigh.L → shin.L → foot.L
   ├─ thigh.R → shin.R → foot.R
   └─ tail1 → tail2 → tail3 → tail4
```

- `root` 不参与变形，其余 `use_deform=True`。
- 手臂/腿的 IK：
  - `forearm.*` 挂 2 骨 IK，target=手部空物体，pole=肘部空物体；
  - `shin.*` 挂 2 骨 IK，target=脚部空物体，pole=膝部空物体；
  - pole_angle 先给 -90°，靠试渲调整。
- IK 目标不参与导出；GLB 导出前逐帧 bake 并清约束。

## 3. 蒙皮

**没有用 automatic weights**：程序化零件是很多互不相连的几何岛，热权重容易失败或串权重。
改为显式顶点组：

| 类型 | 做法 |
| --- | --- |
| 躯干 | 到 hips/spine/chest/neck 骨段的距离权重 `1/(d+0.045)^4`，逐顶点归一 |
| 关节球（肘/膝/尾节） | 父子骨骼各 0.5 |
| 护甲/头发/眼睛/金箍/棍 | 100% 到对应骨骼 |
| 四肢/尾巴 | 每段 100% 到对应骨骼 |

然后：

1. 所有零件 `join` 成 `Wukong_Body`（顶点组合并）；
2. `parent` 到 `WukongRig`；
3. `Armature` 修改器，使用顶点组。

这是风格化分段角色的稳妥方案；优点是可控、可解释、导出稳定，缺点是关节处靠球体遮缝，不是连续肌肉变形。

## 4. 动画

| 帧 | 事件 |
| --- | --- |
| 1–70 | 蓄力：双手在胸前/腰侧，能量球 0.05→0.2；斗气壳/火花；膝盖微屈 |
| 70–88 | 拉弓：手 IK 目标后收，身体后仰，能量球继续变大 |
| 88–98 | 推掌：双手 IK 目标从身侧快速前移；躯干前倾；能量球移到光束起点 |
| 98–106 | 放波：能量球消失，双层光束从 0.001 拉伸到 9；点光/相机抖动 |
| 106–150 | 光束维持，斗气/火花；尾巴摆动 |
| 150–192 | 回收：光束缩短/消失，斗气衰减，手回到自然位 |

- 手/脚 IK 目标用 Bezier 关键帧；
- 躯干/头用 pose bone 的 XYZ 旋转关键帧；
- 尾巴每 24 帧一组正弦摆动；
- 能量球/光束用空物体父级 + 缩放关键帧；
- 相机挂在 orbit 空物体上，116°→ 慢轨道；释放段相机位置做正弦抖动。

## 5. 特效

- **能量球**：白色核心 emission 6 + 橙色透明外壳 + 点光（照亮脸/手/甲）；
- **光束**：核心圆柱 + 外层透明圆柱，父级 `beam_root` 的 X 缩放控制长度；
- **斗气**：两层低 alpha 橙色椭球壳，随蓄力放大；
- **火花**：26 个小 emission 球，绕身体慢转；
- **地面**：深色圆台 + 金色环；Bloom 让能量发光；
- 相机 50mm，f/2.8 景深，主体对焦。

## 6. 本轮踩坑

| 现象 | 根因 | 修复 |
| --- | --- | --- |
| 能量球只有一个小白点 | `sphere()` 先把初始 scale 应用到网格，动画再乘一次 scale，尺寸被平方缩小 | 能量球基础网格半径设为 1，只用动画 scale |
| 手臂够不到前方目标 | IK 目标超出上臂+前臂长度（0.51），IK 拉直后手的视觉效果奇怪 | 手目标收到臂长范围内（胸前 x≈0.3，推出 x≈0.42） |
| 蓄力看不清 | 球在身体/手后，且没有实际照明 | 球前移到胸前 x≈0.5，放大、加橙色点光 |
| 相机看到背面 | orbit 符号/角度让相机在 -X 侧 | 反向轨道，从 +55° 开始，到 +10° |
| 放波时角色像背对镜头 | 躯干扭转 + 头部旋转叠加 | 释放阶段去掉 twist，头归零 |
| 斗气把角色包成一团 | 两层大 alpha 球 + 强 emission | alpha 0.025、emission 0.25，只保留两层薄壳 |
| IK 动画无法直接进 GLB | glTF 不导出 Blender IK 约束 | 导出前 `nla.bake(visual_keying=True, clear_constraints=True)` |
| 4.2 EEVEE 崩溃 | Intel HD 6000 + Metal GPUFamily 1 | 渲染用 3.4.1 EEVEE Legacy |

## 7. 渲染与导出

- Blender 3.4.1 / EEVEE Legacy，960×540，24fps，192 帧，8 samples；
- Bloom / SSR / GTAO / Motion Blur；Filmic；
- 参考耗时：960×540 约 5.3s/帧（约 17 分钟整片）；
- GLB：bake 后 `export_scene.gltf(use_selection=True, export_skins=True, export_animations=True, export_force_sampling=True)`。
  - 验证：`skins=1, animations=1`，文件约几 MB。

## 8. 验证

```bash
ls /tmp/wukong_frames/frame_*.png | wc -l    # 192
ffprobe -v error -show_entries stream=width,height,r_frame_rate,duration \
  -of default=noprint_wrappers=1 docs/wukong_ki.mp4
/Applications/Blender.app/Contents/MacOS/Blender -b -P scripts/export_glb.py
# GLB_OK ... skins 1 animations 1
```
