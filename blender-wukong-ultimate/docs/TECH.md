# Blender 资产技术说明

## 1. 环境

- Blender 3.4.1（EEVEE Legacy）。本机 Intel HD 6000；4.2 EEVEE Next 崩溃，不用于渲染。
- 纯 bpy 程序化，无外部模型/贴图/插件依赖。
- 导出 glTF 2.0 GLB。

## 2. 建模

### 肌体（单一连续皮肤）

1. 用缩放 UV 球/管拼接出：胸廓、胸肌、腹直肌（6 块）、腹外斜肌、背阔肌、斜方肌、三角肌、肱二/三头肌、前臂、臀、股四头、小腿等。
2. Join → **Remesh（Voxel 0.009，smooth shade）** 得到连续表面。
3. **Smooth**（factor 0.62，iterations 3）消除体素台阶。
4. **Decimate** 到目标面数（身体约 23.5k tris），总资产 56k tris。
5. 用最近 2 个骨段的距离权重（inverse distance^3.4）生成平滑蒙皮权重。
6. 顶点色写入轻微噪声 + 手工“腔体阴影”（胸骨沟、腹白线、腋下、颈下等），导出 COLOR_0。

### 服装 / 头发 / 配件

- `tube()`：沿折线生成环状截面管，支持椭圆截面、ragged 锯齿下摆、外侧 slit（破损裤腿）。
- `ribbon()`：双面布带，用于腰带尾/背布/腕带飘带。
- `blade()`：带中央脊线的扁平锥形发片，用于银发、鬃毛、尾巴绒毛。
- 结构：破损橙裤（短裤 + 两条裤腿 + 侧挂条）、蓝腰带 + 金扣 + 飘带、蓝护腕 + 金环 + 腕带、蓝靴 + 金饰/护胫、银发冠 + 后掠发片 + 长鬃、猴脸五官（眼眶/眉/鼻/獠牙/下颌 jaw 骨）、金箍、耳饰、尾巴、背棍。
- 材质：Principled PBR；程序化 256² PNG（橙布/蓝布/银发/银毛/金）嵌入 GLB；头发/毛/布双面。

## 3. 骨架与蒙皮

- 编辑骨：root、hips、spine、chest、neck、head、jaw；shoulder/upper_arm/forearm/hand ×2；thigh/shin/foot/toe ×2；tail1–4；sash.L/R。共 29 根导出骨（root 非变形）。
- 12 根非变形控制骨（不导出）：
  - `ctrl_hand.L/R` + pole `ctrl_elbow.L/R`：2 骨 IK；
  - `ctrl_foot.L/R` + pole `ctrl_knee.L/R`：2 骨 IK；
  - `ctrl_hand_aim.L/R`、`ctrl_foot_aim.L/R`：Copy Rotation（world）控制腕/踝朝向。
- 权重：身体最近 2 骨段；布料区域限制候选骨；发片/面饰/金饰 rigid；下颌 jaw；尾巴 4 段混合。
- **踩过的坑**：基元对象创建在各自位置，未 apply location 就 join，导致 join 后顶点局部坐标与骨骼世界坐标偏移 1.36 m；蒙皮权重按错误位置计算，裤腿缩进大腿根。修复：所有基元 apply location，`weight_nearest` 用 `o.matrix_world @ v.co`。
- 另一处：Blender 3.4 中先设置 `image.colorspace_settings` 再赋 `image.pixels` 会清空像素，导致所有贴图全黑。修复：先赋 pixels，`update()`，保存 PNG，再 `pack()`。

## 4. 动画与烘焙

- 6 个 Action：Idle/Run/Charge/Cast/Hit/Victory；24 fps。
- 关键帧驱动：IK 目标（手/脚位置）+ pole + 躯干/头/尾旋转 + 腕/踝 Copy Rotation + hips 位移。
- 循环 clip：首末帧一致；Bezier。
- 导出脚本逐 action：
  1. 重置 pose，指定 action；
  2. `bpy.ops.nla.bake(visual_keying=True, use_current_action=True, ...)` 逐帧采样约束结果；
  3. 所有 action 完成后删除约束与 12 根控制骨；
  4. 清理 `ctrl_*` fcurve，关键帧整体 −1 帧（clip 从 0 开始），线性插值；
  5. 每 clip 一条 NLA track；
  6. 选择 armature + body，导出 GLB（`export_nla_strips=True`、`export_force_sampling=True`、`export_yup=True`、`export_colors=True`）。
- GLB 校验：skins 1、joints 29、animations 6、56,072 tris、15 materials、5 images、COLOR_0/JOINTS_0/WEIGHTS_0/NORMAL/POSITION/TEXCOORD_0。
- 导出时长：Cast 1.208 / Charge 1.333 / Hit 0.542 / Idle 2.0 / Run 0.667 / Victory 2.0 s。

## 5. 1080p 定帧

- `render_stills.py` 打开 .blend，重建布景：石台、拱门、断柱、远山、星、月、浮石、程序化 aura/能量球/光束/石傀。
- 相机 3 台：
  - 正面 3/4：Idle 第 25 帧；
  - 蓄力：Charge 第 17 帧，orb + sparks；
  - 放波：Cast 第 14 帧，光束 + 目标 + 冲击。
- EEVEE Legacy，1920×1080，40 samples，Filmic High Contrast，bloom + GTAO + SSR。
- 输出：`docs/poster_front.png`、`poster_charge.png`、`poster_cast.png`。
- 对比：`docs/before_after.png` 使用首版海报 + 极意蓄力定帧（1920×540，两侧 960×540）。

## 6. 已知限制

- 程序化体素重构仍有局部块面感，极端特写不占优；手指为简化体块；无表情骨。
- 发片/鬃毛刚性绑定，头部大角度旋转时可能穿插。
- 布料无物理模拟；破损/飘带为静态建模 + 骨骼动画。
- .blend 保留 IK；GLB 为烘焙 FK，不含约束。
