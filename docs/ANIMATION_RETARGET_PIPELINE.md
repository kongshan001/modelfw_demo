# 模型动作迁移通用流程（引擎无关）

> 适用：把骨架 A 的动作迁移到骨架 B；可用于离线烘焙，也可用于自研引擎 runtime。
> 结论：**动作迁移不是复制 Animation 轨道，而是骨骼映射 + rest 对齐 + 在模型空间传递“相对 rest 的变换增量” + 目标 rest/根运动/蒙皮分别处理。**

---

## 1. 先统一数据模型

### 1.1 骨架

每个骨骼至少需要：

| 数据 | 说明 |
|---|---|
| `parent` | 父骨骼索引；根为 -1 |
| `rest_local` | rest pose 下的局部变换（相对父骨骼） |
| `rest_global` | rest pose 下的模型空间变换（可预计算） |
| `inverse_bind` | 蒙皮用的绑定逆矩阵（注意：**bind pose 不一定等于 rest pose**） |
| `name` / `id` | 导入期用 name 映射；运行时只认 id |
| `length` | 骨骼长度（可选，用于校验） |

### 1.2 动画

每条轨道按**骨骼 id**索引（不要按名字）：

```text
Track {
  bone_id
  times[]
  rotations[]   // quaternion，局部旋转
  positions[]   // 局部平移（多数骨骼应保持 rest，根/hips 例外）
  scales[]      // 一般保持 rest，不跨角色复制
}
Clip {
  tracks[]
  sample_rate
  loop
  events[]
  root_track
}
```

### 1.3 约定先写死

- 左右手/上方向/前方向：源和目标是否一致？
- 单位：cm 还是 m？Mixamo 常是 cm，引擎常是 m。
- 矩阵约定：以下默认**列向量** `v' = M * v`、`world = parent_world * local`；行向量引擎请转置并调换乘法顺序。
- 旋转一律用四元数；不要在管线里用 Euler。
- 蒙皮矩阵：`skin = pose_global * inverse_bind * bind_shape`（bind_shape 视引擎而定）。

---

## 2. 端到端流程（8 步）

### Step 1：资产验收

- 有 Armature/Skeleton，骨骼数、父子关系正确；
- rest pose 是 T-pose 还是 A-pose；
- 模型朝向 +Z/-Z、上方向 Y/Z、单位、整体缩放；
- 网格与骨架绑定正常，材质/贴图完整；
- 动画轨道引用的骨骼是否都存在。

> 本项目的 `godot-mixamo-demo/tools/blender_inspect.py` 就是这一步的自动化门槛：骨架数、骨骼数、`mixamorig` 覆盖、尺寸、材质、T-pose hint。

### Step 2：统一坐标与单位

把源变换转换到目标模型空间：

```text
如果 target_model = C * source_model：
  D_target = C * D_source * C^-1
```

`C` 包含：上方向/前方向旋转、手性转换、单位缩放。手性转换是反射，会翻转三角形绕序与旋转方向，能避则避；必须处理时不要用负缩放糊过去。

### Step 3：rest / bind 对齐

- T-pose 与 A-pose 不同、骨骼 roll 不同、rest 轴不同，都会影响结果；
- 优先做 **Rest Fixer / BoneMap**（Blender、引擎导入器或自研工具）；
- **bind pose 与 rest pose 分开存**：retarget 改的是 pose；蒙皮仍应使用原始 bind 的 inverse bind。若 rest 被改写，要重新计算 inverse bind 或保留独立 bind 数据。

### Step 4：骨骼映射

- 人形：Root/Hips/Spine/Chest/Neck/Head、Shoulder/UpperArm/LowerArm/Hand、UpperLeg/LowerLeg/Foot/Toe；
- 按 **名字 + 父子层级 + 左右侧** 映射，不要只按名字；
- 源多出的骨骼（手指、尾巴）可以跳过；目标多出的骨骼保持 rest；
- 映射表单独存为 `RetargetProfile`，不要散落在代码里。

### Step 5：采样源动作到模型空间

动画通常是局部变换，先自底向上/自顶向下求出源模型的全局 pose：

```text
P_s_global[bone] = P_s_global[parent] * local_pose[bone]
```

同时准备源 rest 的全局变换 `R_s_global[bone]`（可预计算）。

### Step 6：计算目标 pose（核心）

对每个映射骨骼，按父先子后的顺序：

```text
D = P_s_global[src] * inverse(R_s_global[src])     // 源相对 rest 的模型空间增量
P_t_global[dst] = D * R_t_global[dst]              // 施加到目标 rest
P_t_local[dst] = inverse(P_t_global[parent]) * P_t_global[dst]
```

非映射骨骼：

```text
P_t_local[bone] = R_t_local[bone]                  // 保持目标 rest
```

要点：

- **只传旋转**时取 `D` 的旋转部分；平移/缩放不要跨比例复制；
- 目标骨骼长度由目标 rest 决定，天然保持，不会被源比例拉长；
- 根/hips 的平移单独处理（见 Step 7），否则会把源的单位/位移带进来；
- 四元数要处理符号连续性（相邻帧 `dot < 0` 时取反）并归一化；
- 目标父子顺序必须拓扑排序；父骨骼的 `P_t_global` 必须先算。

#### 不同 rest 轴/roll 的修正（重要）

上面的 `D * R_t` 在父子 rest 轴一致时成立；源/目标骨骼 roll 不同时（例如 Xbot/Michelle），直接套会出现整肢扭转、上举或拉伸。需要 **parent-rest basis 修正**（Godot `RetargetModifier3D` 同式）：

```text
R_t_world = inverse(ParentRest_t) * ParentRest_s * P_s
          * inverse(R_s) * inverse(ParentRest_s) * ParentRest_t * R_t
R_t_local_pose = inverse(P_t_parent * L_t) * R_t_world
```

- `ParentRest_s/t`：源/目标**父骨骼**的 rest 全局旋转（根为 identity）
- `P_s`：源骨骼 pose 全局旋转；`R_s`：源骨骼 rest 全局旋转
- `R_t`：目标骨骼 rest 全局旋转；`L_t`：目标骨骼相对父骨骼的 rest 局部旋转
- `P_t_parent`：目标父骨骼的 pose 全局旋转

只保留 `D * R_t` 在“同骨架、同 rest 轴”下才安全；跨角色请用上面的修正版。`animation-retarget-kit/tools/blender_retarget.py` 已按此实现，`blender_validate.py` 会用骨长漂移检测拉伸。

> 为什么不用“直接复制 local rotation”：local rotation 绑定在各自的 rest 轴/roll 上；源和目标 rest 不同时，同样的 local 四元数在目标上会扭成不同姿势。上面的全局增量法先把源动作转换到模型空间，再落到目标 rest 上，才是跨骨架可用的。

### Step 7：root motion

- 根骨骼/hips 的位移是角色位移，不是普通骨骼动作；
- 提取 `root_delta = P_s_root_global.translation - R_s_root_global.translation`；
- 做单位/轴转换后交给角色控制器；
- 原地动画（in-place）则忽略位移，只保留旋转；
- 不要把源根位移直接写进目标 hips 的 local position，除非你明确要 bake root motion。

### Step 8：蒙皮与验收

```text
skin_matrix[bone] = P_t_global[bone] * inverse_bind[bone]
```

- `inverse_bind` 来自 bind pose；如果改了 rest，确认 bind 数据仍一致；
- 逐骨骼校验目标骨长不变；
- 连续播放至少 2 个循环的 Idle/Walk/Run；
- 看脚底是否滑、root 轨迹是否连续、是否有整体倾斜/麻花；
- 用 gold pose/clip 做数值回归。

---

## 3. 三种迁移策略

| 场景 | 做法 |
|---|---|
| 同骨架、同 rest | 直接复用 clip（仍需处理坐标/单位/root） |
| 同骨架、不同 rest（T vs A、roll 不同） | Rest Fixer 统一 rest；或使用上面的全局增量法 |
| 不同骨架/比例 | 人形骨骼映射 + 全局增量 + 目标 rest 长度；root motion 单独处理 |
| 非人形/多足/翅膀 | 自定义 SkeletonProfile + 手工映射；不能套人形模板 |
| 需要动态混合/IK | runtime retargeter；否则优先离线 bake |

---

## 4. 自研引擎落地架构

### 4.1 离线 bake（推荐先做）

```text
源 clip → 采样每一帧源 pose
        → 逐帧 retarget 到目标骨架
        → 写目标 clip（目标 fps、四元数连续、关键帧压缩）
        → 目标引擎直接播放
```

优点：运行时零 retarget 成本、行为稳定、易回归。
缺点：换目标骨架/动态 clip 要重新 bake。

### 4.2 Runtime retarget（第二阶段）

```text
SkeletonAsset: bone[], parent[], rest_local[], rest_global[], inverse_bind[]
AnimationAsset: tracks[bone_id]
RetargetProfile: src_bone ↔ dst_bone, axis/unit conversion, root_bone, scale_ratio
Retargeter::apply(srcPose, profile, dstSkeleton) -> dstPose
```

实现建议：

- 骨骼用 id，运行时不查名字；
- 预计算 `rest_global_inverse`、父索引、拓扑顺序；
- 全局 pose 用扁平数组（SoA），避免每帧分配；
- 四元数统一归一化，处理符号连续；
- 多角色 retarget 可并行 job；蒙皮继续走 GPU；
- 调试可视化：骨架叠加、rest vs pose、骨骼轴、root 轨迹、脚底接触点。

### 4.3 关键数据结构

```cpp
struct Bone {
  int parent;
  Mat4 rest_local;
  Mat4 rest_global;
  Mat4 inverse_bind;
};

struct RetargetMap { int src; int dst; };

struct RetargetProfile {
  std::vector<RetargetMap> bones;
  Mat4 source_to_target; // 坐标/单位转换
  int src_root, dst_root;
  float unit_scale;
};
```

---

## 5. 常见坑与症状

| 症状 | 根因 | 修复 |
|---|---|---|
| 整体倾斜/倒向一侧 | 根/hips 的 rest 轴或父级坐标不一致 | 全局增量 + 根骨骼单独处理；Rest Fixer |
| 四肢麻花/翻转 | 骨骼 roll/rest frame 不同，四元数符号跳变 | 对齐 rest frame；四元数连续性；避免 Euler |
| 角色变大/变小 | 单位/缩放被复制 | 不复制 position/scale；root motion 单独乘单位比 |
| 脚底滑动 | in-place 动画与位移速度不匹配 | 匹配移动速度；root motion；脚部 IK |
| 网格炸开/拉丝 | bind 与 inverse bind 不一致、负缩放 | 用原始 bind；避免负缩放；检查蒙皮矩阵 |
| 手指/尾巴丢失 | 目标没有对应骨骼 | 映射表跳过；目标缺失骨骼保持 rest |
| 左右反了 | 手性转换/镜像 | 手性转换时同时处理绕序与旋转；不要只取反 X |
| 循环接缝 | 首尾关键帧/采样率不一致 | 首尾一致；循环 clip 处理最后一帧 |
| 动作幅度不对 | 源目标比例差异 | 只传旋转；用 IK/脚部修正处理接触 |
| 单帧正常、连续帧歪 | rest 轴不匹配的累积 | 连续 2 个循环验收；Rest Fixer |

> 本项目 Xbot 的案例：静帧看似正常，连续 Idle/Walk 会整体倾斜——它证明了“只看一帧”不够，rest 轴问题必须在连续播放中暴露。

---

## 6. 验收清单

- [ ] rest→rest：源 rest 输入，目标输出应等于目标 rest（误差 < eps）
- [ ] 目标骨骼长度逐帧不变
- [ ] 映射骨骼的全局旋转增量与源一致（数值校验）
- [ ] Idle/Walk/Run 连续 2 个循环：无倾斜、无麻花、无脚底滑
- [ ] root motion 位移连续、单位正确、循环无缝
- [ ] 蒙皮网格无爆炸、无拉丝、材质正常
- [ ] 每帧预算符合目标平台；retarget 不产生每帧堆分配
- [ ] gold pose/clip 回归：改代码后数值 diff 可解释

---

## 7. 参考实现（本项目）

- `godot-mixamo-demo/`：Godot 4.6 `RetargetModifier3D` 的全局增量实现；Michelle 由隐藏 Soldier 骨架驱动；Soldier/Xbot 原生动作；Space 跳舞；Tab 切换。
- `godot-mixamo-demo/tools/blender_inspect.py`：导入期骨架/骨骼/尺寸/材质/T-pose 验收。
- `docs/MIXAMO_RETARGET.md`：Mixamo → Godot 的实测与踩坑。
- `godot-mixamo-demo/docs/AI_3D_PIPELINE.md`：概念图 → 图生 3D → 绑定 → Godot 的资产管线。

Godot 的 `RetargetModifier3D` 源码注释里也给出了同一条模型空间公式：

```text
tgt_pose.basis = tgt_parent_global_rest.basis.inv
              * src_parent_global_rest.basis
              * src_pose.basis
              * src_rest.basis.inv
              * src_parent_global_rest.basis.inv
              * tgt_parent_global_rest.basis
              * tgt_rest.basis
```

它和本文的“全局增量 + 目标 rest”是同一件事的不同展开；自研引擎可以直接实现上面的矩阵形式。
