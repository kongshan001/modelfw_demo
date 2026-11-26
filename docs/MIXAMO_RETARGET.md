# Mixamo → Godot 重定向验证

> 日期：2026-11-10 · 引擎：Godot 4.6 stable（GL Compatibility） · 参考视频：[用 AI 复刻《仙剑奇侠传4》](https://b23.tv/IulfzRm)

## 结论

Godot 原生可行。`RetargetModifier3D` 可以把一套 Mixamo 骨架的动画重定向到另一套 Mixamo 骨架，且保留目标骨架的 rest pose（T-pose），不需要 Unity Humanoid。

直接拷贝 `Animation` 轨道（无论位置+旋转，还是只拷旋转）都会扭曲/塌陷；原因是各角色骨骼的 rest pose 不同，动画轨道存的是局部旋转，不能跨 rest 复用。

## 实测

| 角色 | 骨骼数 | 结果 |
|---|---|---|
| Soldier（源） | 49 | 原生 Idle 1.97s / Walk 1.03s / Run 0.70s 正常 |
| Xbot（目标） | 67 | 静帧看似正常；连续 Idle/Walk 会整体倾斜——rest 轴与源差异大，需 Rest Fixer/BoneMap 统一 |
| Michelle（目标） | 65 | rest=T-pose；连续播放 Soldier Walk 正常，多余骨骼保持 rest |

测试数据来自 Three.js 官方 Mixamo 样例（`Soldier.glb` / `Xbot.glb` / `Michelle.glb`），不是从 Mixamo 现下的。测试脚本：`/tmp/mixamo_verify/verify_rmod.gd`（临时目录，未入库）。

## 最小用法

```gdscript
# 1. 源骨架：正常播动画
source_ap.play("Walk")

# 2. 构建 profile：骨骼名 = 目标骨架的 mixamorig_* 名
var profile := SkeletonProfile.new()
profile.bone_size = target_skel.get_bone_count()
for i in target_skel.get_bone_count():
    profile.set_bone_name(i, target_skel.get_bone_name(i))
    var parent := target_skel.get_bone_parent(i)
    profile.set_bone_parent(i, &"" if parent < 0 else target_skel.get_bone_name(parent))
profile.root_bone = target_skel.get_bone_name(0)
profile.scale_base_bone = "mixamorig_Hips"

# 3. RetargetModifier3D 挂在源 Skeleton3D 下
var modifier := RetargetModifier3D.new()
source_skel.add_child(modifier)
modifier.profile = profile
modifier.set_position_enabled(false)
modifier.set_scale_enabled(false)
modifier.set_rotation_enabled(true)

# 4. 目标 Skeleton3D 必须是 modifier 的直接子节点
target_skel.reparent(modifier, true)

# 5. 网格留在原模型根下，重绑到移动后的 Skeleton3D
for mesh in target_meshes:
    mesh.skeleton = mesh.get_path_to(target_skel)
```

## 关键点

- `profile` 的骨骼名必须同时存在于源和目标骨架。Mixamo→Mixamo 同名（`mixamorig_*`）可直接用；非同名骨架需要 BoneMap/改名/自定义 profile。
- 目标 `Skeleton3D` 必须是 `RetargetModifier3D` 的直接子节点；挂错层级会静默不生效。
- 只开 rotation retarget，避免 position/scale 造成体型扭曲。需要 root motion 时再单独开 position；`use_global_pose=true` 要求骨骼长度完全一致。
- **Xbot 的导出 rest 轴与 Soldier 不同**：同一套 rotation-only 配置下，静帧看似正常，连续 Idle/Walk 会整体倾斜；Michelle 的 rest 轴与 Soldier 匹配，直接正常。生产上先用导入期 Rest Fixer/BoneMap 统一 rest 轴，再开 `RetargetModifier3D`，或为不同 rest 轴单独调 profile。
- 网格重绑是工程上最容易踩的坑：移动 skeleton 后要更新 `MeshInstance3D.skeleton` 路径。
- 生产环境也可走导入期 BoneMap + `SkeletonProfileHumanoid`；运行时 `RetargetModifier3D` 更适合动态混合/换装。

## 录制

- `/tmp/mixamo_gif/godot_retarget.gif`：1280×518，2 秒循环，30 帧 / 15fps；源 Soldier Walk（左）→ Michelle 重定向（右）。
- Xbot 的连续帧验证失败（rest 轴倾斜），未放入 GIF。

## 游戏 Demo

- 已落盘 `godot-mixamo-demo/`：可运行第三人称 demo，源 NPC（Soldier 原生 Idle）+ 玩家（Michelle 重定向），WASD 移动 / Shift 奔跑。
- 运行：`godot --path godot-mixamo-demo`。
- GIF：`godot-mixamo-demo/docs/demo.gif`（1280×720 / 4s / 15fps）与 `demo_960.gif`。
- 冒烟：`godot --headless --path godot-mixamo-demo -s tools/smoke_demo.gd` → `DEMO_SMOKE_OK`。

## 限制

- Mixamo 自动绑定仍需 Adobe ID；Adobe 官方 FAQ 明确**中国大陆国家/地区代码的账号不可用**。本验证只覆盖“已有 Mixamo 骨架 + 动画”的重定向，不覆盖上传 Tripo 模型自动绑定。
- 目标视频的 Unity 链路靠 Humanoid retarget；Godot 链路用本文件的 `RetargetModifier3D` 或导入期 BoneMap，效果等价。

## Action Forge 补充（2026-11-26）

实测报告：`action-forge-test/docs/action-forge-test.md`；可运行预览：`action-forge-test/godot/`。

- **结论**：Action Forge 网页版（免登录、文件本地读取）可以完成“Mixamo 样例动画 → KayKit Rogue 自有骨架 → GLB”的重定向与导出：41 骨 / 12 mesh，动画 1.0333 s，Godot 4.6 可播放，Blender 骨长偏差 1e-06。自动映射把 Rogue 识别成 UE4 Mannequin，只映射 17 骨；chibi 比例下行走明显屈膝/前倾，需要手工修映射或 rest pose，不能直接替代 Mixamo 的自动绑定质量。
- **in-place / root motion**：In place 勾选后 root XZ=0；不勾选约 2.0 cm。源片本身根位移很小，未覆盖大位移片段。
- **坑**：Adjust 的 Speed 1.5× 不烘焙（导出仍 1.0333 s）；仅动画 GLB 在 Godot 中节点名被清洗（`upperarm.l`→`upperarm_l`，无 Skeleton3D），不能直接挂到 Rogue 骨架；Michelle.glb 作为角色上传在无头环境卡在纹理缩放。
- **对比基线**：本文的 `RetargetModifier3D`（Michelle 正常 / Xbot 倾斜）仍是 Godot 运行时方案；Action Forge 的优势在免账号/无上传/一体化编辑导出，适合作为补充工具。

## Action Forge T-013 深度复测补充（2026-11-26）

> 报告：`action-forge-test/docs/action-forge-test.md` §T-013；预览：`action-forge-test/godot/layered.tscn`。

- **动画库**：当前 build UI 85 clips / manifest 89（3 个零时长手指 pose + 1 个 FPS 测试）；简介“250+”不成立于免费内置库。分类/搜索/预览可用，武器动作无道具。
- **分层**：base `Walk Loop` + upper-body `Idle Talking Loop` 自动 mask 到 Head/Neck/Spine/Clavicle/Arms/Hands；导出 GLB 上半身旋转差 0.40–1.26 rad，腿骨 ≤0.0008 rad；weight 0% 与 base 等价。限制：layer 被裁到 base 长度（0.45 cycle）、拖 strip 重置 mask 为 Full body、composite root-motion 不烘焙。
- **内置 Walk Loop → KayKit Rogue**（Quaternius 71 骨 → 41 骨；沿用 17 骨映射）：`walk_loop_fit` 1.3333 s / 43 glTF channels / 21 Godot 轨；root in-place 0.000 m、root-motion **0.3371 m**（库标称 1.30 m 的 26%）；脚底 **+3.03 cm**；root-motion 支撑脚世界滑移 **0.417 m**；loop seam 0.0000/0.0127 rad；Blender 骨长偏差 1e-06。视觉上仍偏低/屈膝，属 chibi + 自动映射的同类问题。
- **与本文基线对比**：T-009 的 Mixamo Michelle Walk → Rogue root 0.0197 m、脚底 +1.1–3.9 cm；T-013 的内置源有更大的 root 位移，但缩到 26% 且支撑滑 0.417 m。`RetargetModifier3D` 的 rotation-only 在 Michelle 上更干净（Xbot 仍需 rest 修正）。Action Forge 是“快速重定向/分层/导出”的补充，不是接触/步幅 IK 级方案。
- **FBX**：Godot 4.6 直接导入 41 骨 / 12 mesh / 28 轨；Unity 2022.3.49f1 headless FBX 导入 54 transforms / 6 SkinnedMeshRenderer / 1.3333 s / 30 fps / Generic（未配 Humanoid）；Blender 3.4.1 41 骨 / 410 fcurves / frame 1–41。
- **Michelle 目标实时测试**：识别 Mixamo，**52/62 骨映射全对**（10 根指尖骨未蒙皮被忽略），可导出 65 骨/1 mesh/17,342 verts/1.3333 s 的 GLB+FBX；但 **1.8 m 的目标在应用里显示 63 cm，raw 导出 AABB 2.692 m（源的 1.664 m 的 1.618×）**。手动 0.618× 根缩放后身高/姿态回到源水平（脚底 +1.1 cm、in-place 支撑滑 0.663 m ≈ 源 0.660 m），但 **rootmotion 导出不可用**（hips Y 范围 2.357 m，缩放后支撑滑 1.451 m）。结论：AF→Michelle 的骨骼映射可用，尺度/根运动需后处理，不能直接替代 Mixamo 的自动绑定链路。
